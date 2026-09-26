class_name Actor
extends CharacterBody2D
## Base comum de jogador e inimigos: vida, atributos, status, fraquezas,
## tempo local (campos de lentidão/parar o tempo), empurrões, postura
## (stagger), proteção (ward) e reação a golpes.

signal died(info: DamageInfo)
signal damaged(info: DamageInfo, amount: float)
signal health_changed(current: float, maximum: float)


var team: int = Layers.Team.ENEMY
var stats: StatBlock = StatBlock.new()
var hp: float = 100.0
var facing: int = 1
var profile: Dictionary = {} ## weakness / class_weakness
var status: StatusController
var dead: bool = false
var local_time: float = 1.0
var base_time: float = 1.0 ## multiplicador fixo (dimensão)
var external_velocity: Vector2 = Vector2.ZERO ## puxões de gravidade (zerado todo frame)
var poise: float = 0.0
var max_poise: float = 3.0
var stagger_time: float = 0.0
var invuln_time: float = 0.0
var ward_charges: int = 0
var ward_time: float = 0.0
var sprite: CreatureSprite
var sprite_faces: int = 1
var attack: AttackRunner
var caster: SpellCaster
var rng := RandomNumberGenerator.new()

var _time_fields: Dictionary = {}
var _flash: float = 0.0


func _ready() -> void:
	rng.randomize()
	status = StatusController.new(self)
	collision_layer = Layers.ACTORS
	collision_mask = Layers.WORLD | Layers.ONE_WAY
	floor_snap_length = 6.0
	safe_margin = 0.05


## Cria o visual procedural (criaturinha minimalista) a partir de um spec.
func setup_creature(look: Dictionary) -> void:
	sprite = CreatureSprite.new()
	sprite.name = "Sprite"
	sprite.spec = look
	add_child(sprite)


func play_anim(anim: String, _restart: bool = false) -> void:
	if sprite:
		sprite.play(anim)


func emote(kind: String, duration: float = 1.2) -> void:
	if sprite:
		sprite.emote(kind, duration)


func max_hp() -> float:
	return stats.get_stat("max_hp")


func _physics_process(delta: float) -> void:
	local_time = _compute_local_time()
	var d := delta * local_time
	status.update(d)
	invuln_time = maxf(invuln_time - d, 0.0)
	stagger_time = maxf(stagger_time - d, 0.0)
	if ward_time > 0.0:
		ward_time -= d
		if ward_time <= 0.0:
			ward_charges = 0
	poise = maxf(poise - d * max_poise * 0.35, 0.0)
	if not dead:
		_actor_physics(d, delta)
	external_velocity = Vector2.ZERO
	_update_visuals(delta)


## Implementado por Player/Enemy. d = delta já escalado pelo tempo local.
func _actor_physics(_d: float, _raw_delta: float) -> void:
	pass


func _compute_local_time() -> float:
	var t := base_time
	for v in _time_fields.values():
		t = minf(t, float(v))
	if not _time_fields.is_empty():
		status.active["slowed"] = {"stacks": 1, "time": 0.2, "tick": 1.0, "power": 1.0}
	_time_fields.clear()
	return t


## Chamado a cada frame por campos de tempo que cobrem este ator.
func set_time_field(scale: float, field_id: int) -> void:
	_time_fields[field_id] = scale


func apply_pull(v: Vector2) -> void:
	external_velocity += v
	status.active["pulled"] = {"stacks": 1, "time": 0.3, "tick": 1.0, "power": 1.0}


func _update_visuals(delta: float) -> void:
	_flash = maxf(_flash - delta * 7.0, 0.0)
	if sprite:
		sprite.flash = maxf(sprite.flash, _flash)
		sprite.status_color = status.tint()
		sprite.flip_h = facing < 0
		sprite.speed_scale = local_time
		sprite.velocity_hint = velocity


func set_dissolve(v: float) -> void:
	if sprite:
		sprite.dissolve = v


func is_invulnerable() -> bool:
	return invuln_time > 0.0 or dead


# ---------------------------------------------------------------------------
# Receber dano
# ---------------------------------------------------------------------------

func take_hit(info: DamageInfo) -> int:
	if dead:
		return DamageInfo.Result.IGNORED
	if info.team == team and not info.is_hazard:
		return DamageInfo.Result.IGNORED
	var pre := _before_hit(info)
	if pre >= 0:
		return pre
	if is_invulnerable():
		return DamageInfo.Result.INVULNERABLE
	if ward_charges > 0 and not info.is_hazard:
		ward_charges -= 1
		FX.burst(body_center(), Color(3.0, 2.8, 1.6), 8, 80.0)
		Audio.play("block")
		invuln_time = 0.2
		return DamageInfo.Result.BLOCKED
	var atk_stats: StatBlock = info.source.stats if info.source is Actor and is_instance_valid(info.source) else null
	var amount := CombatMath.resolve(info, atk_stats, stats, profile, status.has("mark"))
	if status.has("wet") and info.damage_type == "lightning":
		amount *= 1.5
	if status.has("shock") and not info.is_hazard and info.damage_type != "lightning":
		_shock_chain(info)
	amount = _modify_incoming(info, amount)
	info.final_amount = amount
	hp -= amount
	for s in info.status.keys():
		status.add(s, int(info.status[s]), atk_stats)
	_apply_knockback(info)
	poise += info.stagger
	if poise >= max_poise and not _has_super_armor():
		poise = 0.0
		stagger_time = 0.45
		_on_staggered(info)
	_flash = 1.0
	Events.damage_dealt.emit(info, self, DamageInfo.Result.HIT)
	damaged.emit(info, amount)
	_on_damaged(info, amount)
	health_changed.emit(hp, max_hp())
	if hp <= 0.0:
		hp = 0.0
		_die(info)
		return DamageInfo.Result.KILLED
	return DamageInfo.Result.HIT


## Retorne >= 0 para interceptar (aparar/bloquear/esquivar), -1 para seguir.
func _before_hit(_info: DamageInfo) -> int:
	return -1


func _modify_incoming(_info: DamageInfo, amount: float) -> float:
	return amount


func _has_super_armor() -> bool:
	return false


func _apply_knockback(info: DamageInfo) -> void:
	if info.knockback != Vector2.ZERO:
		velocity = info.knockback


func _on_staggered(_info: DamageInfo) -> void:
	pass


func _on_damaged(_info: DamageInfo, _amount: float) -> void:
	pass


func take_status_damage(amount: float, id: String) -> void:
	if dead:
		return
	hp -= amount
	var c: Color = StatusController.DEFS.get(id, {}).get("color", Color.WHITE)
	FX.damage_number(global_position + Vector2(0, -12), amount, false, Color(c.r * 0.6, c.g * 0.6, c.b * 0.6))
	health_changed.emit(hp, max_hp())
	if hp <= 0.0:
		hp = 0.0
		var info := DamageInfo.new()
		info.damage_type = id
		_die(info)


func on_hemorrhage(power: float) -> void:
	var dmg := (max_hp() * 0.1 + 8.0) * power
	FX.burst(body_center(), Color(2.6, 0.2, 0.3), 12, 110.0)
	FX.text(global_position + Vector2(0, -18), "HEMORRAGIA", Color(2.4, 0.4, 0.5))
	FX.shake(0.25)
	take_status_damage(dmg, "bleed")


func on_status_added(id: String, stacks: int) -> void:
	Events.status_applied.emit(self, id, stacks)


func status_immune(id: String) -> bool:
	if id == "burn" and stats.get_stat("burn_immune") > 0.0:
		return true
	return float(profile.get("weakness", {}).get(id, 1.0)) == 0.0


func _shock_chain(info: DamageInfo) -> void:
	var stacks := status.stacks("shock")
	status.remove("shock")
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = 40.0
	q.shape = c
	q.transform = Transform2D(0.0, global_position)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Layers.HURTBOX
	var done := {}
	for r in space.intersect_shape(q, 12):
		var hb = r["collider"]
		if hb is Hurtbox and hb.actor != self and hb.team == team and not done.has(hb.actor):
			done[hb.actor] = true
			var chain := DamageInfo.new()
			chain.amount = 4.0 * stacks + info.amount * 0.3
			chain.damage_type = "lightning"
			chain.team = info.team
			chain.source = info.source
			chain.is_spell = true
			LightningFX.spawn(get_parent(), body_center(), hb.global_position)
			hb.receive(chain)


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(hp + amount, max_hp())
	FX.text(global_position + Vector2(0, -16), "+%d" % int(amount), Color(0.6, 2.4, 0.8))
	health_changed.emit(hp, max_hp())


func _die(info: DamageInfo) -> void:
	if dead:
		return
	dead = true
	died.emit(info)
	_on_death(info)


func _on_death(_info: DamageInfo) -> void:
	pass


## Centro aproximado do corpo (para mirar, efeitos, etc).
func body_center() -> Vector2:
	return global_position + Vector2(0, -6)
