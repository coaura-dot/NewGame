class_name SpellCaster
extends Node
## Conjura qualquer magia do banco. O MESMO código roda para jogador e
## inimigos — só muda quem mira. O efeito é definido por "cast" no JSON.

signal cast_done(spell_id: String)

var actor: Node = null
var cooldowns: Dictionary = {}
var last_spell: String = ""


func _init(owner_actor: Node = null) -> void:
	actor = owner_actor


func tick(delta: float) -> void:
	for k in cooldowns.keys():
		cooldowns[k] = float(cooldowns[k]) - delta
		if cooldowns[k] <= 0.0:
			cooldowns.erase(k)


func cooldown_left(spell_id: String) -> float:
	return float(cooldowns.get(spell_id, 0.0))


func is_ready(spell_id: String) -> bool:
	return cooldown_left(spell_id) <= 0.0


func cost_of(spell_id: String, level: int = 0) -> float:
	var s: Dictionary = DB.spell(spell_id)
	var mult: float = 1.0 + actor.stats.get_stat("spell_cost")
	if s.get("school", "") == "time":
		mult += actor.stats.get_stat("time_spell_cost")
		if actor.has_method("has_rule") and actor.has_rule("cheap_time_spells"):
			mult *= 0.5
	return maxf(DB.spell_value(spell_id, "cost", level) * maxf(mult, 0.2), 0.0)


## Conjura. aim = direção normalizada; target = ponto alvo no mundo.
## power multiplica o dano (ex.: precisão do sigilo).
func cast(spell_id: String, level: int, aim: Vector2, target: Vector2, power: float = 1.0) -> bool:
	var s: Dictionary = DB.spell(spell_id)
	if s.is_empty() or not is_ready(spell_id):
		return false
	var cd: float = float(s.get("cooldown", 0.5)) * maxf(1.0 + actor.stats.get_stat("cooldown"), 0.3)
	cooldowns[spell_id] = cd
	last_spell = spell_id
	var mode: String = s.get("cast", "projectile")
	if mode == "sigil":
		mode = s.get("effect", "nova")
	if aim == Vector2.ZERO:
		aim = Vector2(actor.facing, 0)
	aim = aim.normalized()
	match mode:
		"projectile": _projectile(spell_id, s, level, aim, power)
		"beam": _beam(spell_id, s, level, aim, power)
		"eruption": _eruption(spell_id, s, level, aim, power)
		"nova": _nova(spell_id, s, level, actor.body_center(), power)
		"smite": _smite(spell_id, s, level, aim, target, power)
		"storm": _storm(spell_id, s, level, power)
		"field": _field(spell_id, s, level, aim, target, "pull", power)
		"time_field": _field(spell_id, s, level, aim, target, "time", power)
		"blink": _blink(s, level, aim)
		"grab": _grab(spell_id, s, level, aim, power)
		"echo":
			if actor.has_method("start_echo"):
				actor.start_echo(int(DB.spell_value(spell_id, "count", level)), DB.spell_value(spell_id, "echo_mult", level), DB.spell_value(spell_id, "duration", level))
		"rewind":
			if actor.has_method("rewind"):
				actor.rewind(DB.spell_value(spell_id, "duration", level), DB.spell_value(spell_id, "heal_ratio", level))
		"ward":
			actor.ward_charges = int(DB.spell_value(spell_id, "count", level))
			actor.ward_time = DB.spell_value(spell_id, "duration", level)
			FX.burst(actor.body_center(), _color(s), 12, 70.0)
	if mode in ["projectile", "beam", "eruption", "smite", "grab"]:
		SchoolFX.cast(_world(), str(s.get("school", "arcane")), actor.body_center() + aim * 6.0, aim, _color(s))
	var school_snd: String = "spell_" + str(s.get("school", "arcane"))
	if Audio.has_event(school_snd):
		Audio.play(school_snd, 0.08, -4.0 if int(s.get("tier", 1)) >= 2 else -6.0)
	else:
		Audio.play("spell_heavy" if int(s.get("tier", 1)) >= 2 else "spell")
	Events.spell_cast.emit(actor, spell_id)
	cast_done.emit(spell_id)
	return true


func _color(s: Dictionary) -> Color:
	var c: Array = s.get("color", [2, 2, 2])
	return Color(c[0], c[1], c[2])


func _info(spell_id: String, s: Dictionary, level: int, power: float, dmg_key: String = "damage") -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = DB.spell_value(spell_id, dmg_key, level) * power
	info.school = s.get("school", "arcane")
	info.damage_type = info.school
	info.is_spell = true
	info.spell_id = spell_id
	info.team = actor.team
	info.source = actor
	info.status = s.get("status", {}).duplicate()
	info.stagger = 1.0
	info.parryable = true
	info.is_crit = actor.rng.randf() < actor.stats.get_stat("crit_chance") * 0.5
	return info


func _world() -> Node:
	return actor.get_parent()


func _projectile(spell_id: String, s: Dictionary, level: int, aim: Vector2, power: float) -> void:
	var count := maxi(1, int(round(DB.spell_value(spell_id, "count", level))))
	var spread := deg_to_rad(float(s.get("spread", 0.0)))
	for i in count:
		var p := Projectile.new()
		var off := 0.0 if count == 1 else lerpf(-spread, spread, float(i) / (count - 1))
		var dir := aim.rotated(off)
		p.team = actor.team
		p.owner_actor = actor
		p.info = _info(spell_id, s, level, power)
		if s.has("knockback"):
			p.info.knockback = dir * float(s["knockback"])
		p.velocity = dir * float(s.get("speed", 140))
		p.radius = DB.spell_value(spell_id, "radius", level) if s.has("radius") else 2.5
		p.pierce = s.get("pierce", false)
		p.homing = float(s.get("homing", 0.0))
		p.lifetime = float(s.get("lifetime", 2.2))
		p.color = _color(s)
		p.light_enabled = s.get("light", false)
		p.global_position = actor.body_center() + dir * 6.0
		_world().add_child(p)


func _hurtboxes_in(center: Vector2, radius: float) -> Array:
	var space: PhysicsDirectSpaceState2D = actor.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	q.shape = c
	q.transform = Transform2D(0.0, center)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Layers.HURTBOX
	var out := []
	var seen := {}
	for r in space.intersect_shape(q, 32):
		var hb = r["collider"]
		if hb is Hurtbox and hb.team != actor.team and hb.actor and not seen.has(hb.actor):
			seen[hb.actor] = true
			out.append(hb)
	return out


func _raycast(from: Vector2, to: Vector2) -> Vector2:
	var space: PhysicsDirectSpaceState2D = actor.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, Layers.WORLD)
	var r := space.intersect_ray(q)
	return r["position"] if not r.is_empty() else to


func _beam(spell_id: String, s: Dictionary, level: int, aim: Vector2, power: float) -> void:
	var from: Vector2 = actor.body_center()
	var end := _raycast(from, from + aim * float(s.get("range", 100)))
	var col := _color(s)
	var lightning: bool = s.get("school", "") == "lightning"
	LightningFX.spawn(_world(), from, end, col, 2.0, lightning)
	var school: String = s.get("school", "arcane")
	var along := int(from.distance_to(end) / 24.0)
	for i in along:
		SchoolFX.trail(_world(), school, from.lerp(end, (i + 0.5) / float(along)), end - from, col)
	SchoolFX.impact(_world(), school, end, end - from, col, 0.8)
	# alvos ao longo do feixe
	var hits := []
	var steps := int(from.distance_to(end) / 6.0) + 1
	var seen := {}
	for i in steps:
		var p := from.lerp(end, float(i) / steps)
		for hb in _hurtboxes_in(p, 5.0):
			if not seen.has(hb.actor):
				seen[hb.actor] = true
				hits.append(hb)
	if not s.get("pierce", false) and hits.size() > 1:
		hits = [hits[0]]
	for hb in hits:
		hb.receive(_info(spell_id, s, level, power))
	# corrente
	var chain := int(round(DB.spell_value(spell_id, "chain", level)))
	if chain > 0 and not hits.is_empty():
		var last: Node = hits[-1].actor
		for i in chain:
			var nxt: Hurtbox = null
			var best := 60.0
			for hb in _hurtboxes_in(last.body_center(), 60.0):
				if not seen.has(hb.actor) and hb.actor.body_center().distance_to(last.body_center()) < best:
					best = hb.actor.body_center().distance_to(last.body_center())
					nxt = hb
			if nxt == null:
				break
			seen[nxt.actor] = true
			LightningFX.spawn(_world(), last.body_center(), nxt.actor.body_center(), col)
			var ci := _info(spell_id, s, level, power * 0.7)
			nxt.receive(ci)
			last = nxt.actor
	FX.shake(0.15)


func _eruption(spell_id: String, s: Dictionary, level: int, aim: Vector2, power: float) -> void:
	var dx := signf(aim.x) if aim.x != 0.0 else float(actor.facing)
	var from: Vector2 = actor.global_position + Vector2(dx * float(s.get("range", 40)), -4)
	var ground := _raycast(from, from + Vector2(0, 60))
	var r := DB.spell_value(spell_id, "radius", level)
	for hb in _hurtboxes_in(ground + Vector2(0, -r), r):
		var info := _info(spell_id, s, level, power)
		info.knockback = Vector2(dx * 30.0, -float(s.get("knockup", 150)))
		info.stagger = 3.0
		hb.receive(info)
	FX.burst(ground, _color(s), 6, 110.0, Vector2.UP, 35.0, 0.45, 2.0)
	SchoolFX.impact(_world(), str(s.get("school", "earth")), ground, Vector2.UP, _color(s), 1.4)
	FX.shake(0.2)


func _nova(spell_id: String, s: Dictionary, level: int, center: Vector2, power: float) -> void:
	var r := DB.spell_value(spell_id, "radius", level)
	for hb in _hurtboxes_in(center, r):
		var info := _info(spell_id, s, level, power)
		var dir: Vector2 = (hb.actor.body_center() - center).normalized()
		info.knockback = dir * float(s.get("knockback", 70.0)) + Vector2(0, -40)
		info.parryable = false
		hb.receive(info)
	var ring := NovaFX.new()
	ring.radius = r
	ring.color = _color(s)
	ring.global_position = center
	_world().add_child(ring)
	var school: String = s.get("school", "arcane")
	SchoolFX.impact(_world(), school, center, Vector2.UP, _color(s), 1.3)
	for i in 6:
		var at := center + Vector2.from_angle(TAU * i / 6.0) * r * 0.7
		SchoolFX.trail(_world(), school, at, at - center, _color(s))
	FX.shake(0.2)


func _smite(spell_id: String, s: Dictionary, level: int, aim: Vector2, target: Vector2, power: float) -> void:
	var rng_r := float(s.get("range", 90))
	var best: Node = null
	var best_score := INF
	for a in actor.get_tree().get_nodes_in_group("actors"):
		if a.team == actor.team or a.dead:
			continue
		var to: Vector2 = a.body_center() - actor.body_center()
		if to.length() > rng_r:
			continue
		var score := to.length() * (1.5 - aim.dot(to.normalized()))
		if score < best_score:
			best_score = score
			best = a
	var point: Vector2 = best.body_center() if best else target
	for hb in _hurtboxes_in(point, DB.spell_value(spell_id, "radius", level)):
		hb.receive(_info(spell_id, s, level, power))
	LightningFX.spawn(_world(), point + Vector2(0, -60), point, _color(s), 2.0, false)
	FX.burst(point, _color(s), 4, 90.0)
	SchoolFX.impact(_world(), str(s.get("school", "psychic")), point, Vector2.DOWN, _color(s), 1.2)


func _storm(spell_id: String, s: Dictionary, level: int, power: float) -> void:
	var targets := []
	for a in actor.get_tree().get_nodes_in_group("actors"):
		if a.team != actor.team and not a.dead and a.body_center().distance_to(actor.body_center()) < float(s.get("range", 100)):
			targets.append(a)
	targets.sort_custom(func(x, y): return x.body_center().distance_to(actor.body_center()) < y.body_center().distance_to(actor.body_center()))
	var bolts := int(round(DB.spell_value(spell_id, "count", level)))
	for i in bolts:
		if targets.is_empty():
			break
		var a: Node = targets[i % targets.size()]
		LightningFX.spawn(_world(), a.body_center() + Vector2(randf_range(-10, 10), -80), a.body_center(), _color(s), 2.0)
		SchoolFX.impact(_world(), str(s.get("school", "lightning")), a.body_center(), Vector2.DOWN, _color(s), 0.9)
		for hb in a.get_children():
			if hb is Hurtbox:
				hb.receive(_info(spell_id, s, level, power))
				break
	FX.shake(0.3)


func _field(spell_id: String, s: Dictionary, level: int, aim: Vector2, target: Vector2, kind: String, power: float) -> void:
	var f := SpellField.new()
	f.kind = kind
	f.team = actor.team
	f.source = actor
	f.spell_id = spell_id
	f.school = s.get("school", "gravity")
	f.radius = DB.spell_value(spell_id, "radius", level)
	f.duration = DB.spell_value(spell_id, "duration", level)
	f.pull = float(s.get("pull", 0.0))
	f.tick = float(s.get("tick", 0.25))
	f.damage = DB.spell_value(spell_id, "damage", level) * power
	f.implode = DB.spell_value(spell_id, "implode", level) * power
	f.time_scale = float(s.get("time_scale", 1.0))
	f.color = _color(s)
	if kind == "time":
		f.global_position = actor.body_center()
	else:
		var dist := float(s.get("range", 55))
		var desired: Vector2 = target if target != Vector2.ZERO and target.distance_to(actor.body_center()) < dist * 1.5 else actor.body_center() + aim * dist
		f.global_position = _raycast(actor.body_center(), desired)
	_world().add_child(f)


func _blink(s: Dictionary, level: int, aim: Vector2) -> void:
	var from: Vector2 = actor.global_position
	var dist := DB.spell_value("passo_etereo", "range", level) if s.has("range") else 55.0
	var desired := from + aim * dist
	# para antes de paredes (testa o corpo em passos)
	var best := from
	var steps := 12
	for i in range(1, steps + 1):
		var p := from.lerp(desired, float(i) / steps)
		var tr: Transform2D = actor.global_transform
		tr.origin = p
		if actor.test_move(tr, Vector2.ZERO):
			break
		best = p
	var ghost := AfterImage.from_sprite(actor.rig if "rig" in actor and actor.rig else actor.sprite, Color(1.4, 1.0, 3.0, 0.8))
	if ghost:
		_world().add_child(ghost)
	actor.global_position = best.round()
	if "_prev_pos" in actor:
		actor._prev_pos = actor.global_position
	actor.reset_physics_interpolation()
	actor.invuln_time = maxf(actor.invuln_time, 0.2)
	LightningFX.spawn(_world(), from + Vector2(0, -6), best + Vector2(0, -6), _color(s), 1.0, false)
	FX.burst(best + Vector2(0, -6), _color(s), 4, 80.0)
	SchoolFX.impact(_world(), str(s.get("school", "teleport")), from + Vector2(0, -6), Vector2.UP, _color(s), 0.7)
	SchoolFX.impact(_world(), str(s.get("school", "teleport")), best + Vector2(0, -6), Vector2.UP, _color(s), 1.0)


func _grab(spell_id: String, s: Dictionary, level: int, aim: Vector2, power: float) -> void:
	var rng_r := DB.spell_value(spell_id, "range", level)
	var best: Node = null
	var best_d := rng_r
	for p in actor.get_tree().get_nodes_in_group("projectiles"):
		if p.team != actor.team and p.global_position.distance_to(actor.body_center()) < best_d:
			best_d = p.global_position.distance_to(actor.body_center())
			best = p
	if best:
		best.reflect(actor)
		LightningFX.spawn(_world(), actor.body_center(), best.global_position, _color(s), 1.5, false)
		return
	for a in actor.get_tree().get_nodes_in_group("actors"):
		if a.team == actor.team or a.dead:
			continue
		var d: float = a.body_center().distance_to(actor.body_center())
		if d < best_d:
			best_d = d
			best = a
	if best:
		var front: Vector2 = actor.global_position + Vector2(actor.facing * 16, 0)
		LightningFX.spawn(_world(), actor.body_center(), best.body_center(), _color(s), 1.5, false)
		if not best.profile.get("boss", false):
			best.global_position = actor._raycast_safe(best.global_position, front) if actor.has_method("_raycast_safe") else front
			best.reset_physics_interpolation()
		for hb in best.get_children():
			if hb is Hurtbox:
				hb.receive(_info(spell_id, s, level, power))
				break
