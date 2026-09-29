class_name GuardianBrain
extends RefCounted
## Chefes guardiões das Brasas-Mestras: padrões de DUELO dirigidos por dados
## (data "moves" em data/enemies.json). Cada movimento:
##   id, kind, red (vermelho = não dá para aparar: esquive/pule), windup,
##   recover (janela de punição), weight, phase (fase mínima), range [min, max]
##   e parâmetros do tipo.
## Ciclo: aproximar -> escolher -> preparar (telegrafia amarela/vermelha +
## cintilar) -> executar -> recuperar (exposto: castigue!).
## Usa os campos do Enemy (ai_state/ai_t) para conversar com o sistema de
## duelo (brilho, guarda, aparo, punição).
##
## Tipos: lunge, swoop, combo, volley, slam, rockfall, teleport, dash_chain,
## summon, decoys, cast (magia de spells.json pelo SpellCaster).

const ShockwaveFx := preload("res://scripts/combat/shockwave.gd")
const RockFx := preload("res://scripts/combat/falling_rock.gd")
const DecoyFx := preload("res://scripts/actors/mirror_decoy.gd")

var e: Node ## Enemy
var move: Dictionary = {}
var last_id: String = ""
var sub: String = "" ## etapa dentro do movimento (salto: "air", mergulho: "rise"...)
var step_i: int = 0
var _dir: Vector2 = Vector2.ZERO
var _left: float = 0.0 ## tempo restante da etapa ativa
var _land_ok: bool = false
var _follow: Dictionary = {}
var hover_side: int = 1 ## voadores: de que lado do herói pairam (+1 = à direita)


func _room_rect() -> Rect2:
	var lvl: Node = e.level
	if lvl == null or not is_instance_valid(lvl) or not lvl.has_method("room_rect"):
		return Rect2()
	var idx := int(e.get_meta("room", -1))
	if idx < 0:
		return Rect2()
	return lvl.camera_rect(idx) if lvl.has_method("camera_rect") else lvl.room_rect(idx)


func _init(enemy: Node) -> void:
	e = enemy


func _tgt() -> Node:
	var t: Node = e.target
	if t == null or not is_instance_valid(t) or t.dead:
		return null
	return t


func tick(d: float) -> void:
	var tgt := _tgt()
	if tgt == null:
		e.velocity.x = move_toward(e.velocity.x, 0.0, 300.0 * d)
		if e.flying:
			e.velocity.y = move_toward(e.velocity.y, 0.0, 300.0 * d)
		e._anim("idle")
		return
	match e.ai_state:
		"spawn", "idle", "patrol", "chase", "approach":
			e.ai_state = "approach"
			_approach(d, tgt)
			if e.ai_t <= 0.0:
				_choose(tgt)
		"windup":
			_damp(d, 0.88)
			if move.get("kind", "") != "teleport":
				e._face_target()
			if e.ai_t <= 0.0:
				_start(tgt)
		"attack":
			_act(d, tgt)
		"recover":
			_damp(d, 0.9)
			e._anim(str(e.data.get("anim", {}).get("tired", "")) if sub == "dizzy" else "idle")
			if e.ai_t <= 0.0:
				sub = ""
				e.ai_state = "approach"
				if e.rng.randf() < 0.5:
					hover_side = -hover_side # voadores trocam de lado entre os golpes
				e.ai_t = e.rng.randf_range(0.3, 0.7) * (1.0 - 0.15 * e.phase_idx)
		_:
			e.ai_state = "approach"


func _damp(d: float, k: float) -> void:
	e.velocity.x *= pow(k, d * 60.0)
	if e.flying:
		e.velocity.y *= pow(k, d * 60.0)


# ---------------------------------------------------------------------------
# Aproximar / escolher
# ---------------------------------------------------------------------------

func _approach(d: float, tgt: Node) -> void:
	e._face_target()
	var pref := float(e.data.get("pref_range", 48.0))
	if e.flying:
		var bob: float = sin(e._bob) * 8.0
		e._bob += d * 1.8
		var hover: Vector2 = tgt.body_center() + Vector2(hover_side * pref, -36.0 + bob)
		# fica dentro da sala: se o lado escolhido não cabe, vai para o outro
		var room: Rect2 = _room_rect()
		if room.size.x > 0.0:
			var margin := 22.0
			if hover.x < room.position.x + margin or hover.x > room.end.x - margin:
				hover_side = -hover_side
				hover.x = tgt.body_center().x + hover_side * pref
			hover.x = clampf(hover.x, room.position.x + margin, room.end.x - margin)
			hover.y = clampf(hover.y, room.position.y + margin, room.end.y - 30.0)
		var to: Vector2 = hover - e.global_position
		e.velocity = e.velocity.move_toward(to.limit_length(1.0) * e.speed * minf(to.length() / 20.0, 1.0), 260.0 * d)
		e._anim("idle")
		return
	var dx: float = e._dx()
	var want := 0.0
	if absf(dx) > pref + 12.0:
		want = signf(dx)
	elif absf(dx) < pref - 18.0:
		want = -signf(dx) * 0.6 # recua um passo (espaço para o duelo)
	if want != 0.0 and (e._wall_ahead() or e._ledge_ahead()) and signf(want) == float(e.facing):
		want = 0.0
	e.velocity.x = move_toward(e.velocity.x, want * e.speed, 500.0 * d)
	e._anim("move" if absf(e.velocity.x) > 5.0 else "idle")


func _choose(tgt: Node) -> void:
	var moves: Array = e.data.get("moves", [])
	var dist: float = e.body_center().distance_to(tgt.body_center())
	var table := {}
	for i in moves.size():
		var m: Dictionary = moves[i]
		if int(m.get("phase", 0)) > e.phase_idx:
			continue
		var rg: Array = m.get("range", [0, 999])
		if dist < float(rg[0]) or dist > float(rg[1]):
			continue
		var w := float(m.get("weight", 1.0))
		if str(m.get("id", "")) == last_id:
			w *= 0.25 # evita repetir o mesmo golpe
		table[i] = w
	if table.is_empty():
		e.ai_t = 0.2
		return
	var idx: int = RngUtil.weighted_key(e.rng, table)
	move = moves[idx]
	last_id = str(move.get("id", ""))
	step_i = 0
	sub = ""
	_windup(move)


func _windup(m: Dictionary) -> void:
	e.ai_state = "windup"
	var w: float = float(m.get("windup", 0.45)) * (1.0 - 0.08 * e.phase_idx)
	e.ai_t = maxf(w, 0.2)
	e._telegraph(bool(m.get("red", false)), e.ai_t)
	e._anim("windup")
	if m.has("say") and e.emote:
		pass


# ---------------------------------------------------------------------------
# Executar
# ---------------------------------------------------------------------------

func _start(tgt: Node) -> void:
	e.ai_state = "attack"
	var k: String = move.get("kind", "lunge")
	var red := bool(move.get("red", false))
	match k:
		"lunge":
			e._face_target()
			_left = float(move.get("time", 0.35))
			e.velocity.x = e.facing * float(move.get("speed", 220.0))
			_hit(move.get("box", [0, -14, 20, 14]), red, float(move.get("dmg", 1.0)), _left)
			e._anim("attack")
			Audio.play("dash", 0.1, -8.0, 0.8)
		"swoop":
			_dir = (tgt.body_center() - e.global_position).normalized()
			_left = float(move.get("time", 0.5))
			e.velocity = _dir * float(move.get("speed", 210.0))
			e.facing = 1 if _dir.x >= 0.0 else -1
			_hit(move.get("box", [-6, -6, 18, 12]), red, float(move.get("dmg", 1.0)), _left)
			e._anim("attack")
			Audio.play("dash", 0.1, -8.0, 0.7)
		"combo":
			step_i = 0
			_combo_hit()
		"volley":
			step_i = 0
			_volley(tgt)
			_left = float(move.get("interval", 0.25))
		"slam":
			_slam_start(tgt)
		"rockfall":
			_rockfall(tgt)
			_left = float(move.get("time", 0.9))
			e._anim("cast")
		"teleport":
			_teleport_out()
		"dash_chain":
			_left = float(move.get("time", 0.4))
			e._face_target()
			e.velocity.x = e.facing * float(move.get("speed", 260.0))
			var last: bool = step_i >= int(move.get("count", 3)) - 1
			_hit(move.get("box", [0, -14, 18, 14]), last and bool(move.get("red_last", true)) or red, float(move.get("dmg", 1.0)), _left)
			e._anim("attack")
			Audio.play("dash", 0.1, -6.0, 1.1)
		"summon":
			_summon()
			_left = 0.5
			e._anim("cast")
		"decoys":
			_decoys(tgt)
			_left = 0.6
			e._anim("cast")
		"cast":
			_cast(tgt)
			_left = float(move.get("time", 0.45))
			e._anim("cast")
		_:
			_left = 0.1


func _act(d: float, tgt: Node) -> void:
	var k: String = move.get("kind", "lunge")
	_left -= d
	match k:
		"lunge":
			if e._wall_ahead():
				_left = 0.0
			if _left <= 0.0:
				_recover()
		"swoop":
			if _left <= 0.0:
				_recover()
		"combo":
			if _left <= 0.0:
				step_i += 1
				var hits: Array = move.get("hits", [])
				if step_i >= hits.size():
					_recover()
				else:
					_combo_hit()
		"volley":
			if _left <= 0.0:
				step_i += 1
				if step_i >= int(move.get("bursts", 1)):
					_recover()
				else:
					_volley(tgt)
					_left = float(move.get("interval", 0.25))
		"slam":
			_slam_tick(d, tgt)
		"rockfall", "summon", "decoys", "cast":
			_damp(d, 0.85)
			if _left <= 0.0:
				_recover()
		"teleport":
			_teleport_tick(tgt)
		"dash_chain":
			if e._wall_ahead():
				_left = 0.0
			if _left <= 0.0:
				e.attack.cancel()
				step_i += 1
				if step_i >= int(move.get("count", 3)):
					sub = "dizzy"
					_recover()
				else:
					# próxima investida: preparo curto (a última é vermelha)
					var last: bool = step_i >= int(move.get("count", 3)) - 1
					e.ai_state = "windup"
					e.ai_t = float(move.get("chain_windup", 0.3))
					e._telegraph(last and bool(move.get("red_last", true)), e.ai_t)
					e._anim("windup")
		_:
			_recover()


func _recover() -> void:
	e.attack.cancel()
	e.ai_state = "recover"
	var r: float = float(move.get("recover", 0.8)) * (1.0 - 0.12 * e.phase_idx)
	e.ai_t = maxf(r, 0.35)
	e._open_punish(e.ai_t)
	if sub == "dizzy" and e.emote:
		e.emote.show_emote("dizzy", e.ai_t, true)


## Golpe com caixa [x, y, w, h] (relativa aos pés olhando para a direita).
func _hit(box: Array, red: bool, dmg: float, active: float) -> void:
	var step := {"box": box, "startup": 0.0, "active": maxf(active, 0.05), "recovery": 0.02, "dmg": dmg, "kb": float(move.get("kb", 120.0)), "stagger": 1.5}
	e._attack_step(step, "heavy" if dmg >= 1.4 else "light", red)


# --- combo ---

func _combo_hit() -> void:
	var hits: Array = move.get("hits", [])
	var h: Dictionary = hits[step_i]
	e._face_target()
	var red := bool(h.get("red", false))
	if step_i > 0 and red != e.tele_red:
		e._telegraph(red, 0.15)
	_left = float(h.get("time", 0.3))
	e.velocity.x = e.facing * float(h.get("lunge", 60.0))
	_hit(h.get("box", [0, -16, 22, 16]), red, float(h.get("dmg", 1.0)), float(h.get("active", 0.12)))
	e._anim("attack")
	Audio.play("swing_heavy" if float(h.get("dmg", 1.0)) >= 1.4 else "swing", 0.1, -5.0, 0.8)


# --- projéteis ---

func _volley(tgt: Node) -> void:
	var n: int = int(move.get("count", 3)) + (int(move.get("count_phase", 0)) * e.phase_idx)
	var spread := deg_to_rad(float(move.get("spread", 30.0)))
	var base: Vector2 = (tgt.body_center() - e.body_center()).normalized()
	if move.get("aim", "target") == "down":
		base = Vector2(0, 1)
	var red := bool(move.get("red", false))
	var c: Array = move.get("color", [2.4, 1.4, 0.6])
	for i in n:
		var off := 0.0 if n == 1 else lerpf(-spread, spread, float(i) / (n - 1))
		var dir := base.rotated(off)
		var p := Projectile.new()
		p.team = e.team
		p.owner_actor = e
		var info := DamageInfo.new()
		info.amount = float(e.moveset.get("damage", 10.0)) * float(move.get("dmg", 0.6)) * 0.8
		info.damage_type = str(move.get("damage_type", "pierce"))
		info.source = e
		info.team = e.team
		info.is_projectile = true
		info.parryable = not red
		info.unblockable = red
		info.status = move.get("status", {}).duplicate()
		p.info = info
		p.reflectable = not red
		p.velocity = dir * float(move.get("speed", 120.0))
		p.radius = float(move.get("radius", 3.0))
		p.lifetime = float(move.get("lifetime", 2.5))
		p.color = Color(c[0], c[1], c[2])
		p.light_enabled = false
		p.global_position = e.body_center() + dir * 8.0
		e.get_parent().add_child(p)
	e._anim("cast")
	Audio.play(str(move.get("sfx", "turret_shot")), 0.08, -6.0)


# --- salto / mergulho com ondas de choque ---

func _slam_start(tgt: Node) -> void:
	_land_ok = false
	if e.flying:
		# sobe acima do herói e despenca
		sub = "rise"
		_left = 0.45
		_dir = Vector2(tgt.global_position.x, tgt.global_position.y - 90.0)
		e._anim("windup")
	else:
		sub = "air"
		var dx: float = clampf(tgt.global_position.x - e.global_position.x, -150.0, 150.0)
		var air := float(move.get("air", 0.6))
		e.velocity = Vector2(dx / air, -float(move.get("jump", 240.0)))
		_left = air + 0.6
		e._anim("attack")
		Audio.play("jump", 0.05, -4.0, 0.6)


func _slam_tick(d: float, _tgt: Node) -> void:
	match sub:
		"rise":
			var to: Vector2 = _dir - e.global_position
			e.velocity = to.limit_length(1.0) * 220.0
			if _left <= 0.0 or to.length() < 6.0:
				sub = "drop"
				_left = 1.2
				e.velocity = Vector2(0, 330.0)
				_hit(move.get("box", [-10, -8, 20, 16]), bool(move.get("red", true)), float(move.get("dmg", 1.4)), 1.2)
				e._anim("attack")
		"drop":
			e.velocity = Vector2(0, 330.0)
			if e.is_on_floor() or e.test_move(e.global_transform, Vector2(0, 3)) or _left <= 0.0:
				_land()
		"air":
			if _left < float(move.get("air", 0.6)) and e.is_on_floor():
				_land()
			elif _left <= 0.0:
				_land()
		_:
			_recover()


func _land() -> void:
	if _land_ok:
		return
	_land_ok = true
	e.velocity = Vector2.ZERO
	FX.shake(0.45)
	FX.ring(e.global_position, Color(2.4, 1.6, 1.0), 26.0, 0.3, Vector2(1.0, 0.35))
	FX.dust(e.global_position + Vector2(-6, 0), Vector2(-1, -0.3), 5)
	FX.dust(e.global_position + Vector2(6, 0), Vector2(1, -0.3), 5)
	Audio.play("explosion", 0.05, -4.0, 0.8)
	_hit([-16, -10, 32, 10], bool(move.get("red", true)), float(move.get("dmg", 1.4)), 0.1)
	if move.get("waves", false):
		var y: float = _floor_y(e.global_position)
		for s in [-1, 1]:
			var w := ShockwaveFx.new()
			w.setup(e, Vector2(e.global_position.x + s * 10.0, y), s, float(e.moveset.get("damage", 10.0)) * 0.7, float(move.get("wave_speed", 120.0)))
			e.get_parent().add_child(w)
	sub = "dizzy" if move.get("dizzy", false) else ""
	_recover()


func _floor_y(from: Vector2) -> float:
	var space: PhysicsDirectSpaceState2D = e.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from + Vector2(0, -4), from + Vector2(0, 200), Layers.WORLD)
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else from.y


# --- chuva de pedras ---

func _rockfall(tgt: Node) -> void:
	var n: int = int(move.get("count", 4)) + e.phase_idx
	var gap := float(move.get("gap", 26.0))
	var base_x: float = tgt.global_position.x
	var start: float = -(n - 1) * 0.5 * gap + e.rng.randf_range(-6.0, 6.0)
	for i in n:
		var x := base_x + start + i * gap
		var fy: float = _floor_y(Vector2(x, tgt.global_position.y - 20.0))
		var r := RockFx.new()
		r.setup(e, Vector2(x, fy), float(move.get("delay", 0.75)) + i * 0.06, float(e.moveset.get("damage", 10.0)) * 0.8)
		e.get_parent().add_child(r)
	Audio.play("rumble", 0.05, -8.0, 1.2)
	FX.shake(0.2)


# --- teleporte + golpe pelas costas ---

func _teleport_out() -> void:
	sub = "out"
	_left = 0.28
	FX.burst(e.body_center(), Color(1.6, 1.8, 2.6), 10, 70.0)
	Audio.play("spell_teleport", 0.05, -6.0)
	e.visible = false


func _teleport_tick(tgt: Node) -> void:
	if sub == "out" and _left <= 0.0:
		var side: int = -1 if tgt.facing > 0 else 1
		var p: Vector2 = tgt.global_position + Vector2(side * 26.0, -10.0 if e.flying else 0.0)
		e.global_position = p
		e.visible = true
		FX.burst(e.body_center(), Color(1.6, 1.8, 2.6), 10, 70.0)
		e._face_target()
		# golpe rápido depois de reaparecer (preparo curto e amarelo)
		_follow = move.get("follow", {"kind": "lunge", "windup": 0.32, "time": 0.22, "speed": 170, "box": [0, -10, 18, 14], "recover": 0.8})
		move = _follow
		_windup(move)


# --- magia do próprio chefe (usa o SpellCaster e os dados de spells.json) ---

func _cast(tgt: Node) -> void:
	var sp: String = str(move.get("spell", "chama"))
	var aim: Vector2 = (tgt.body_center() - e.body_center()).normalized()
	var fan: int = int(move.get("fan", 0)) + (int(move.get("fan_phase", 0)) * e.phase_idx)
	e.caster.cooldowns.erase(sp)
	e.caster.cast(sp, e.phase_idx, aim, tgt.body_center())
	for k in fan:
		var side := 1 if k % 2 == 0 else -1
		var ang := side * 0.28 * float(k / 2 + 1)
		e.caster.cooldowns.erase(sp)
		e.caster.cast(sp, e.phase_idx, aim.rotated(ang), tgt.body_center())


# --- invocação e ilusões ---

func _summon() -> void:
	var lvl: Node = e.level
	if lvl == null or not lvl.has_method("_make_enemy"):
		return
	var alive := 0
	for n in e.get_tree().get_nodes_in_group("enemies"):
		if n != e and not n.dead and n.get_meta("summoned_by", null) == e:
			alive += 1
	var want: int = int(move.get("count", 2)) - alive
	for i in maxi(want, 0):
		var pos: Vector2 = e.global_position + Vector2((i * 2 - 1) * 24.0, -6.0)
		var m: Node = lvl._make_enemy(str(move.get("enemy", "hellcat")), maxi(e.tier - 1, 1), pos, int(e.get_meta("room", -1)))
		m.set_meta("summoned_by", e)
		lvl.entities.add_child(m)
		FX.burst(pos, Color(2.0, 1.2, 2.4), 8, 60.0)
	Audio.play("spell_void", 0.05, -6.0)


func _decoys(tgt: Node) -> void:
	var n: int = int(move.get("count", 2)) + (1 if e.phase_idx >= 1 else 0)
	for i in n:
		var ang: float = TAU * (float(i) + 0.5) / n + e.rng.randf_range(-0.3, 0.3)
		var pos: Vector2 = tgt.body_center() + Vector2(cos(ang), sin(ang) * 0.5 - 0.4) * 56.0
		var dcy := DecoyFx.new()
		dcy.setup(e, pos, 0.55 + i * 0.15, float(e.moveset.get("damage", 10.0)) * 0.5)
		e.get_parent().add_child(dcy)
	Audio.play("spell_quantum", 0.05, -6.0)
