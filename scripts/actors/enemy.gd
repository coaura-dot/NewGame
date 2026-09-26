class_name Enemy
extends Actor
## Inimigo genérico dirigido por dados (data/enemies.json). Usa exatamente os
## mesmos sistemas do jogador: AttackRunner (arma do loadout), SpellCaster
## (magias do loadout), status, fraquezas e armaduras. Perfis de IA:
##   melee    - patrulha, persegue, telegrafa e golpeia (combos no tier 2+)
##   lunger   - corre e dá o bote
##   caster   - voa mantendo distância e conjura
##   turret   - fixo, cospe fogo
##   charger  - investe atravessando a sala
##   boss_demon - chefe voador com 3 fases

signal phase_changed(phase: int)

var enemy_id: String = ""
var data: Dictionary = {}
var ai: String = "melee"
var flying: bool = false
var boss: bool = false
var level: Node = null
var target: Node = null
var home: Vector2 = Vector2.ZERO
var moveset: Dictionary = {}
var spells: Array = []
var speed: float = 60.0
var aggro: float = 200.0
var attack_range: float = 40.0
var tier: int = 1
var phase_idx: int = 0
var ai_state: String = "idle"
var ai_t: float = 0.0
var combo_left: int = 0
var combo_step: int = 0
var charge_dist: float = 0.0
var gravity_mult: float = 1.0
var aggressive: bool = false
var contact_hitbox: Hitbox
var _weak_points: Array = [] ## [Hurtbox, Vector2 base]
var _bob: float = 0.0
var _wander_dir: int = 1
var recoil_t: float = 0.0 ## empurrado por um golpe (a IA espera)
var emote: EmoteBubble
var _aware: bool = false


func setup(id: String, enemy_tier: int, dimension_id: String = "prima") -> void:
	enemy_id = id
	data = DB.enemy(id)
	tier = enemy_tier
	profile = data
	ai = data.get("ai", "melee")
	flying = data.get("flying", false)
	boss = data.get("boss", false)
	speed = float(data.get("speed", 60))
	aggro = float(data.get("aggro", 200))
	attack_range = float(data.get("attack_range", 40))
	max_poise = float(data.get("poise", 3.0 + tier))
	var dim: Dictionary = DB.dimension(dimension_id)
	base_time = float(dim.get("physics", {}).get("enemy_time", 1.0))
	gravity_mult = float(dim.get("physics", {}).get("gravity", 1.0))
	aggressive = dim.get("rules", []).has("enemies_aggressive")


func _ready() -> void:
	team = Layers.Team.ENEMY
	super._ready()
	add_to_group("actors")
	add_to_group("enemies")
	var hp_scale := 1.0 + 0.35 * (tier - 1)
	stats = StatBlock.new({"max_hp": float(data.get("hp", 30)) * hp_scale, "defense": float(tier - 1), "crit_chance": 0.03, "attack": 0.1 * (tier - 1)})
	var lo: Dictionary = data.get("loadout", {})
	var armor_stats := {}
	for a in lo.get("armor", []):
		for st in DB.armor.get(a, {}).get("stats", {}).keys():
			armor_stats[st] = float(armor_stats.get(st, 0.0)) + float(DB.armor[a]["stats"][st])
	stats.set_source("armor", armor_stats)
	hp = max_hp()
	if lo.get("weapon", "") != "":
		moveset = DB.moveset(lo["weapon"])
	spells = lo.get("spells", [])
	var body: Array = data.get("body", [8, 12])
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body[0], body[1])
	cs.shape = rect
	cs.position = Vector2(0, 0 if flying else -float(body[1]) * 0.5)
	add_child(cs)
	if flying:
		collision_mask = Layers.WORLD
	setup_sprite(data.get("sprite", "skeleton"), float(data.get("scale", 1.0)))
	var hb := Hurtbox.make(self, Vector2(body[0], body[1]) + Vector2(2, 2), cs.position)
	add_child(hb)
	for wp in data.get("weak_points", []):
		var box: Array = wp["box"]
		var center := Vector2(float(box[0]) + float(box[2]) * 0.5, float(box[1]) + float(box[3]) * 0.5)
		var w := Hurtbox.make(self, Vector2(box[2], box[3]), center, float(wp.get("mult", 1.5)))
		w.label = wp.get("name", "")
		add_child(w)
		_weak_points.append([w, center])
	attack = AttackRunner.new(self)
	add_child(attack)
	caster = SpellCaster.new(self)
	add_child(caster)
	if float(data.get("contact_damage", 0)) > 0.0:
		contact_hitbox = Hitbox.new()
		contact_hitbox.owner_actor = self
		contact_hitbox.team = team
		contact_hitbox.reflects = false
		contact_hitbox.info_factory = _contact_info
		add_child(contact_hitbox)
		contact_hitbox.set_box([-float(body[0]) * 0.5, (-float(body[1]) * 0.5) if flying else -float(body[1]), float(body[0]), float(body[1])], 1)
		contact_hitbox.activate.call_deferred()
	var ld: Dictionary = data.get("light", {})
	if not ld.is_empty():
		var c: Array = ld.get("color", [1, 1, 1])
		var l := LightUtil.make_light(Color(c[0], c[1], c[2]).clamp(), float(ld.get("energy", 1.0)), float(ld.get("scale", 1.0)))
		if l:
			l.position = Vector2(0, 0 if flying else -float(body[1]) * 0.5)
			add_child(l)
	emote = EmoteBubble.new()
	emote.height = float(body[1]) * (0.5 if flying else 1.0) + 3.0
	add_child(emote)
	home = global_position
	facing = -1
	_wander_dir = -1
	_bob = rng.randf() * TAU
	var spawn_anim: String = data.get("anim", {}).get("spawn", "")
	if spawn_anim != "":
		ai_state = "spawn"
		ai_t = 0.8
		play_anim(spawn_anim, true)
	if boss:
		Events.toast.emit(data.get("name", "Chefe"))


func body_center() -> Vector2:
	if flying:
		return global_position
	return global_position + Vector2(0, -float(data.get("body", [8, 12])[1]) * 0.5)


func _anim(key: String) -> void:
	var name: String = data.get("anim", {}).get(key, key)
	play_anim(name)


func _actor_physics(d: float, raw: float) -> void:
	caster.tick(d)
	attack.tick(d)
	ai_t -= d
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
	for wp in _weak_points:
		wp[0].position = Vector2(wp[1].x * facing, wp[1].y)
	recoil_t -= d
	if status.disabled() or stagger_time > 0.0 or recoil_t > 0.0:
		if recoil_t <= 0.0:
			attack.cancel()
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * d)
		if flying:
			velocity.y = move_toward(velocity.y, 0.0, 300.0 * d)
		_gravity(d)
		_move(d, raw)
		_anim("idle")
		return
	_update_awareness()
	if boss:
		_check_phase()
	match ai:
		"melee": _ai_melee(d)
		"lunger": _ai_lunger(d)
		"caster": _ai_caster(d)
		"turret": _ai_turret(d)
		"charger": _ai_charger(d)
		"boss_demon": _ai_boss(d)
		_: _ai_melee(d)
	_gravity(d)
	_move(d, raw)


func _gravity(d: float) -> void:
	if flying:
		return
	velocity.y = move_toward(velocity.y, 200.0, 900.0 * gravity_mult * d)


func _move(d: float, raw: float) -> void:
	var total := velocity + external_velocity
	var scale := d / maxf(raw, 0.00001)
	var own := velocity
	velocity = total * scale
	move_and_slide()
	var post := velocity / maxf(scale, 0.00001)
	velocity = own
	if not is_equal_approx(post.x, total.x):
		velocity.x = post.x - external_velocity.x if absf(post.x) > 0.01 else 0.0
	if not is_equal_approx(post.y, total.y):
		velocity.y = post.y - external_velocity.y if absf(post.y) > 0.01 else 0.0


# ---------------------------------------------------------------------------
# Percepção
# ---------------------------------------------------------------------------

func _target_valid() -> bool:
	if target == null or not is_instance_valid(target) or target.dead:
		return false
	if status.has("blind"):
		return false
	var dist := body_center().distance_to(target.body_center())
	var range_mult := 1.3 if aggressive else 1.0
	if dist > aggro * range_mult:
		return false
	if not flying and absf(target.global_position.y - global_position.y) > 70.0:
		return false
	return _line_of_sight()


func _line_of_sight() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(body_center(), target.body_center(), Layers.WORLD)
	return space.intersect_ray(q).is_empty()


func _dx() -> float:
	return target.global_position.x - global_position.x


func _face_target() -> void:
	if target and absf(_dx()) > 2.0:
		facing = int(signf(_dx()))


func _ledge_ahead() -> bool:
	var w: float = float(data.get("body", [8, 12])[0]) * 0.5 + 2.0
	var tr := global_transform.translated(Vector2(facing * w, 0))
	return not test_move(tr, Vector2(0, 5))


func _wall_ahead() -> bool:
	return test_move(global_transform, Vector2(facing * 2, 0))


func _windup_time() -> float:
	var t := 0.42 - 0.06 * (tier - 1)
	if aggressive:
		t *= 0.75
	return maxf(t, 0.2)


func _telegraph(unblockable: bool = false) -> void:
	_flash = 0.0
	if _mat:
		_mat.set_shader_parameter("flash_color", Color(1.0, 0.2, 0.2) if unblockable else Color(1.0, 1.0, 1.0))
	var tw := create_tween()
	tw.tween_method(func(v): _flash = v, 0.0, 0.8, _windup_time() * 0.8)


# ---------------------------------------------------------------------------
# Perfis de IA
# ---------------------------------------------------------------------------

func _patrol(d: float) -> void:
	if _wall_ahead() or _ledge_ahead() or absf(global_position.x - home.x) > 45.0 and signf(global_position.x - home.x) == facing:
		facing = -facing
	velocity.x = move_toward(velocity.x, facing * speed * 0.5, 400.0 * d)
	_anim("move")


## "!" quando vê o jogador, "?" quando o perde de vista.
func _update_awareness() -> void:
	if ai == "boss_demon" or target == null or not is_instance_valid(target):
		return
	var sees := _target_valid()
	if sees and not _aware:
		_aware = true
		emote.show_emote("!", 0.7)
	elif not sees and _aware and ai_state in ["patrol", "idle"]:
		_aware = false
		emote.show_emote("?", 0.8)


func _melee_attack(kind: String = "light") -> void:
	if moveset.is_empty():
		return
	if _mat:
		_mat.set_shader_parameter("flash_color", Color(1, 1, 1))
	var step: Dictionary
	if kind == "heavy":
		step = moveset.get("heavy", {})
	else:
		var chain: Array = moveset.get("light", [])
		step = chain[clampi(combo_step, 0, chain.size() - 1)]
		combo_step += 1
	attack.start(step, kind, facing)
	_anim("attack")


func _ai_melee(d: float) -> void:
	match ai_state:
		"spawn":
			velocity.x = 0.0
			if ai_t <= 0.0:
				ai_state = "idle"
		"idle", "patrol":
			if _target_valid():
				ai_state = "chase"
			else:
				_patrol(d)
		"chase":
			if not _target_valid():
				ai_state = "patrol"
				return
			_face_target()
			if absf(_dx()) <= attack_range and is_on_floor():
				ai_state = "windup"
				ai_t = _windup_time()
				combo_left = mini(tier, int(moveset.get("light", [1]).size())) - 1
				combo_step = 0
				velocity.x = 0.0
				_telegraph()
			elif _ledge_ahead():
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
				_anim("idle")
			else:
				velocity.x = move_toward(velocity.x, facing * speed, 500.0 * d)
				_anim("move")
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("windup")
			if ai_t <= 0.0:
				_melee_attack()
				ai_state = "attack"
		"attack":
			var step := attack.step
			if attack.is_busy() and attack.phase != AttackRunner.Phase.RECOVERY:
				velocity.x = facing * float(step.get("lunge", 0.0)) * 0.6
			else:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			if not attack.is_busy():
				if combo_left > 0:
					combo_left -= 1
					_melee_attack()
				else:
					ai_state = "recover"
					ai_t = rng.randf_range(0.45, 0.9) * (0.7 if aggressive else 1.0)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"


func _ai_lunger(d: float) -> void:
	match ai_state:
		"idle", "patrol", "spawn":
			if _target_valid():
				ai_state = "chase"
			else:
				_patrol(d)
		"chase":
			if not _target_valid():
				ai_state = "patrol"
				return
			_face_target()
			var dist := absf(_dx())
			if dist <= attack_range and dist > 12.0 and is_on_floor():
				ai_state = "windup"
				ai_t = _windup_time() * 0.8
				velocity.x = -facing * 20.0
				_telegraph()
				_anim("windup")
			else:
				velocity.x = move_toward(velocity.x, facing * speed, 600.0 * d)
				_anim("move")
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * d)
			_anim("windup")
			if ai_t <= 0.0:
				velocity = Vector2(facing * speed * 1.6, -150.0)
				_anim("jump")
				combo_step = 0
				_melee_attack("heavy" if moveset.has("heavy") and rng.randf() < 0.4 else "light")
				ai_state = "attack"
				ai_t = 0.8
		"attack":
			if is_on_floor() and velocity.y >= 0.0 and ai_t < 0.6:
				velocity.x = move_toward(velocity.x, 0.0, 800.0 * d)
			if ai_t <= 0.0 or (not attack.is_busy() and is_on_floor()):
				attack.cancel()
				ai_state = "recover"
				ai_t = rng.randf_range(0.5, 1.0)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"


func _ai_caster(d: float) -> void:
	_bob += d * 2.2
	var valid := _target_valid()
	var desired := home + Vector2(sin(_bob * 0.5) * 15.0, sin(_bob) * 4.0)
	if valid:
		var away: Vector2 = body_center() - target.body_center()
		var want_dist := attack_range * 0.75
		desired = target.body_center() + away.normalized() * want_dist + Vector2(0, -16 + sin(_bob) * 5.0)
		_face_target()
	elif status.has("blind"):
		desired = global_position + Vector2(_wander_dir * 20.0, sin(_bob) * 10.0)
		if rng.randf() < 0.02:
			_wander_dir = -_wander_dir
	var to := desired - global_position
	velocity = velocity.move_toward(to.limit_length(1.0) * speed * minf(to.length() / 20.0, 1.0), 200.0 * d)
	match ai_state:
		"spawn":
			if ai_t <= 0.0:
				ai_state = "idle"
		"idle", "patrol", "chase":
			_anim("idle")
			if valid and ai_t <= 0.0 and not spells.is_empty():
				ai_state = "windup"
				ai_t = _windup_time() + 0.1
				_telegraph()
				_anim("cast")
			elif valid and not moveset.is_empty() and body_center().distance_to(target.body_center()) < 20.0 and ai_t <= 0.0:
				_melee_attack()
				ai_t = 1.2
		"windup":
			velocity *= 0.9
			if ai_t <= 0.0:
				var sp: String = RngUtil.pick(rng, spells)
				var aim: Vector2 = (target.body_center() - body_center()).normalized() if target else Vector2(facing, 0)
				caster.cooldowns.erase(sp)
				caster.cast(sp, maxi(tier - 1, 0), aim, target.body_center() if target else global_position)
				ai_state = "recover"
				ai_t = rng.randf_range(1.2, 2.2) * (0.7 if aggressive else 1.0)
		"recover":
			if ai_t <= 0.0:
				ai_state = "idle"
				ai_t = 0.0


func _ai_turret(d: float) -> void:
	velocity.x = 0.0
	match ai_state:
		"idle", "patrol", "chase", "spawn":
			_anim("idle")
			if _target_valid():
				_face_target()
				if ai_t <= 0.0:
					ai_state = "windup"
					ai_t = _windup_time() + 0.2
					_telegraph()
					_anim("cast")
		"windup":
			if ai_t <= 0.0:
				var sp: String = RngUtil.pick(rng, spells) if not spells.is_empty() else ""
				if sp != "":
					caster.cooldowns.erase(sp)
					var aim: Vector2 = (target.body_center() - body_center()).normalized() if target else Vector2(facing, 0)
					caster.cast(sp, maxi(tier - 1, 0), aim, target.body_center() if target else global_position)
				ai_state = "recover"
				ai_t = rng.randf_range(1.6, 2.6)
		"recover":
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "idle"


func _ai_charger(d: float) -> void:
	match ai_state:
		"idle", "patrol", "spawn":
			if _target_valid():
				ai_state = "chase"
			else:
				_patrol(d)
		"chase":
			if not _target_valid():
				ai_state = "patrol"
				return
			_face_target()
			if not spells.is_empty() and rng.randf() < 0.004:
				caster.cast(spells[0], 0, Vector2(facing, 0), target.body_center())
			if absf(_dx()) < attack_range and is_on_floor():
				ai_state = "windup"
				ai_t = _windup_time() + 0.25
				_telegraph(true)
				velocity.x = -facing * 30.0
				_anim("idle")
				emote.show_emote("anger", 0.6)
			else:
				velocity.x = move_toward(velocity.x, facing * speed, 400.0 * d)
				_anim("move")
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * d)
			if ai_t <= 0.0:
				ai_state = "charge"
				charge_dist = 0.0
				attack.start(moveset.get("heavy", {}), "heavy", facing)
				FX.shake(0.2)
		"charge":
			velocity.x = facing * 190.0
			charge_dist += 190.0 * d
			_anim("attack")
			if attack.phase == AttackRunner.Phase.RECOVERY:
				attack.t = 0.0 # mantém o golpe ativo durante a investida
				attack.phase = AttackRunner.Phase.ACTIVE
				attack.hitbox.activate()
			if _wall_ahead() or charge_dist > 150.0:
				attack.cancel()
				if _wall_ahead():
					FX.shake(0.35)
					stagger_time = 0.9
					emote.show_emote("dizzy", 0.9, true)
				ai_state = "recover"
				ai_t = 0.8
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"


func _check_phase() -> void:
	var phases: Array = data.get("phases", [1.0])
	var ratio := hp / maxf(max_hp(), 1.0)
	var idx := 0
	for i in phases.size():
		if ratio <= float(phases[i]):
			idx = i
	if idx != phase_idx:
		phase_idx = idx
		phase_changed.emit(idx)
		FX.shake(0.5)
		FX.flash(1.0)
		FX.white_flash(0.3)
		emote.show_emote("anger", 1.2, true)
		speed *= 1.15
		invuln_time = 0.8


func _ai_boss(d: float) -> void:
	_bob += d * 1.6
	if target == null or not is_instance_valid(target):
		return
	_face_target()
	var hover: Vector2 = target.body_center() + Vector2(-facing * 60.0, -40.0 + sin(_bob) * 8.0)
	match ai_state:
		"spawn", "idle", "patrol", "chase":
			var to: Vector2 = hover - global_position
			velocity = velocity.move_toward(to.limit_length(1.0) * speed * minf(to.length() / 25.0, 1.0), 180.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				var roll := rng.randf()
				if roll < 0.35:
					ai_state = "swoop_windup"
					ai_t = _windup_time() + 0.3
					_telegraph()
				else:
					ai_state = "cast_windup"
					ai_t = _windup_time() + 0.2
					_telegraph(phase_idx >= 2)
					_anim("cast")
		"swoop_windup":
			velocity *= 0.92
			if ai_t <= 0.0:
				ai_state = "swoop"
				ai_t = 0.55
				velocity = (target.body_center() - global_position).normalized() * 210.0
				var chain: Array = moveset.get("light", [])
				if not chain.is_empty():
					attack.start(chain[mini(phase_idx, chain.size() - 1)], "light", facing)
				_anim("attack")
		"swoop":
			if ai_t <= 0.0:
				ai_state = "recover"
				ai_t = 0.9 - 0.2 * phase_idx
		"cast_windup":
			velocity *= 0.9
			if ai_t <= 0.0:
				var pool: Array = spells.slice(0, mini(spells.size(), phase_idx + 1))
				var sp: String = RngUtil.pick(rng, pool)
				caster.cooldowns.erase(sp)
				var aim: Vector2 = (target.body_center() - global_position).normalized()
				caster.cast(sp, phase_idx, aim, target.body_center())
				if phase_idx >= 1 and sp == "chama":
					for k in 2:
						caster.cooldowns.erase(sp)
						caster.cast(sp, phase_idx, aim.rotated((k * 2 - 1) * 0.3), target.body_center())
				ai_state = "recover"
				ai_t = 1.3 - 0.25 * phase_idx
		"recover":
			velocity *= 0.95
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "idle"
				ai_t = rng.randf_range(0.3, 0.8)


# ---------------------------------------------------------------------------
# Combate
# ---------------------------------------------------------------------------

func build_attack_info(step: Dictionary, kind: String, charge: float, _target: Node) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = float(moveset.get("damage", 8.0)) * float(step.get("dmg", 1.0)) * charge * 0.8
	info.damage_type = moveset.get("damage_type", "slash")
	info.weapon_class = moveset.get("class", "")
	info.weapon_id = moveset.get("weapon_id", "")
	info.source = self
	info.team = team
	info.is_heavy = kind == "heavy"
	info.direction = Vector2(facing, 0)
	info.knockback = Vector2(facing * float(step.get("kb", 80.0)), -60.0)
	info.stagger = float(step.get("stagger", 1.0))
	var st: Dictionary = moveset.get("weapon_status", {}).duplicate()
	for s in step.get("status", {}).keys():
		st[s] = int(st.get(s, 0)) + int(step["status"][s])
	info.status = st
	info.parryable = not (ai == "charger" and kind == "heavy")
	info.unblockable = not info.parryable
	info.is_crit = CombatMath.roll_crit(rng, stats)
	return info


func _contact_info(_t: Node) -> DamageInfo:
	if dead or stagger_time > 0.0:
		return null
	var info := DamageInfo.new()
	info.amount = float(data.get("contact_damage", 5))
	info.damage_type = "blunt"
	info.source = self
	info.team = team
	info.direction = Vector2(signf(_t.global_position.x - global_position.x), 0)
	info.knockback = info.direction * 90.0 + Vector2(0, -70)
	info.parryable = true
	return info


func on_parried(_by: Node, perfect: bool) -> void:
	attack.cancel()
	poise = 0.0
	stagger_time = 1.5 if perfect else 0.8
	if boss:
		stagger_time *= 0.5
	velocity = Vector2(-facing * 90.0, -40.0 if not flying else 0.0)
	recoil_t = 0.15
	emote.show_emote("dizzy", stagger_time, true)
	if perfect:
		status.add("mark", 1)
	ai_state = "recover"
	ai_t = stagger_time


func _has_super_armor() -> bool:
	return boss or (moveset.get("super_armor", false) and attack.is_busy())


func _apply_knockback(info: DamageInfo) -> void:
	var k := 0.25 if boss or data.get("elite", false) else float(data.get("knockback_mult", 1.0))
	if info.knockback != Vector2.ZERO and k > 0.0:
		velocity = info.knockback * k
		if flying:
			velocity.y = info.knockback.y * k * 0.5
		# recuo curto (Hollow Knight): a IA "sente" o golpe
		recoil_t = maxf(recoil_t, 0.12 * k)


func _on_damaged(info: DamageInfo, amount: float) -> void:
	var heavy := info.is_heavy or info.weak_point_mult > 1.0
	var at: Vector2 = info.hit_position if info.hit_position != Vector2.ZERO else body_center()
	FX.impact(at.lerp(body_center(), 0.5), info.direction, amount, info.is_crit or info.weak_point_mult > 1.0, heavy)
	if info.weak_point_mult > 1.0:
		FX.text(body_center() + Vector2(0, -12), "PONTO FRACO", Color(1.0, 0.85, 0.3))
	var blood: Array = data.get("blood", [0.95, 0.9, 0.85])
	FX.burst(body_center(), Color(blood[0], blood[1], blood[2]), 3, 70.0, info.direction, 40.0, 0.3)
	if ai_state in ["idle", "patrol"]:
		ai_state = "chase"
		_face_target()
		if not _aware:
			_aware = true
			emote.show_emote("!", 0.6)


func _on_staggered(_info: DamageInfo) -> void:
	attack.cancel()
	ai_state = "recover"
	ai_t = 0.5
	emote.show_emote("dizzy", 0.6, true)


func _on_death(info: DamageInfo) -> void:
	attack.cancel()
	if contact_hitbox:
		contact_hitbox.deactivate()
	collision_layer = 0
	for c in get_children():
		if c is Hurtbox:
			c.queue_free()
	remove_from_group("actors")
	FX.hitstop(0.08 if not boss else 0.2)
	FX.shake(0.25 if not boss else 0.8)
	var blood: Array = data.get("blood", [0.95, 0.9, 0.85])
	FX.burst(body_center(), Color(blood[0], blood[1], blood[2]), 8 if not boss else 30, 100.0)
	FX.burst(body_center(), Color(2.2, 1.8, 1.2), 4 if not boss else 16, 60.0)
	if emote:
		emote.clear()
	Audio.play("enemy_death", 0.1, -4.0)
	Events.enemy_killed.emit(self, info)
	if level and level.has_method("on_enemy_killed"):
		level.on_enemy_killed(self)
	var death_anim: String = data.get("anim", {}).get("death", "")
	if death_anim != "":
		play_anim(death_anim, true)
	var tw := create_tween()
	tw.tween_method(set_dissolve, 0.0, 1.0, 0.6 if not boss else 2.0)
	tw.tween_callback(queue_free)


## Drops do loadout (mesmo pool do jogador). Retorna ids sorteados.
func roll_drops(luck: float = 0.0) -> Array:
	var out := []
	for dd in data.get("drops", []):
		if rng.randf() < float(dd.get("chance", 0.0)) * (1.0 + luck):
			out.append(dd["id"])
	return out
