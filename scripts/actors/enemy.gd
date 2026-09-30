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
##   boss_duelist  - espadachim 1v1: combos, iai, postura de contra-ataque,
##                   salto com estocada para baixo, teleporte (fase 3)
##   boss_horde    - invoca ondas; protegida por escudo até a onda cair
##   boss_colossus - gigante: pisão com ondas de choque, varrida, chuva de
##                   pedras; o núcleo (ponto fraco) abaixa após o pisão
##   gunner   - atirador (Katana Zero): mira laser que trava e dispara um
##              tiro rápido; rebata o tiro de volta e ele morre
##   leaper   - saltador: pula em arcos e dá o bote pelo ar
##   assassin - lâmina sombria: pisca e atravessa você num dash cortante
##   shield   - escudeiro: bloqueia golpes de frente (pule por cima, ataque
##              pelas costas, golpe pesado ou Corte-Relâmpago)
##   diver    - enxame: voador que paira e mergulha (ótimo para pogo)

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
# chefes
var shielded: bool = false ## Mãe da Ninhada: imune enquanto a ninhada vive
var lowered: bool = false ## Colosso: abaixado após o pisão (núcleo acessível)
var _minions: Array = []
var _wave: int = 0
# atirador / assassino
var _aim_dir: Vector2 = Vector2.RIGHT
var _laser: float = 0.0 ## 0..1 intensidade da mira laser
var _laser_locked: bool = false
var _dash_dir: Vector2 = Vector2.ZERO
var _sight: Node2D = null


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
	var body: Array = data.get("body", [18, 36])
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body[0], body[1])
	cs.shape = rect
	cs.position = Vector2(0, 0 if flying else -float(body[1]) * 0.5)
	add_child(cs)
	if flying:
		collision_mask = Layers.WORLD
	var look: Dictionary = data.get("look", {}).duplicate()
	if not CreatureSprite.load_sheet(enemy_id).is_empty():
		look["sprite"] = enemy_id # arte detalhada (tools/build_sprites.py)
	setup_creature(look)
	var hb := Hurtbox.make(self, Vector2(body[0], body[1]) * 1.1, cs.position)
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
			l.position = Vector2(0, 0 if flying else -5)
			add_child(l)
	home = global_position
	facing = -1
	_wander_dir = -1
	_bob = rng.randf() * TAU
	var spawn_anim: String = data.get("anim", {}).get("spawn", "")
	if spawn_anim != "":
		ai_state = "spawn"
		ai_t = 0.8
		play_anim(spawn_anim, true)
	pass # chefes: cartão de título na HUD (show_boss)


func body_center() -> Vector2:
	if flying:
		return global_position
	return global_position + Vector2(0, -float(data.get("body", [18, 36])[1]) * 0.5)


func _anim(key: String) -> void:
	# com folha de sprite, as chaves (idle/move/attack/cast/hurt...) já são
	# os nomes das animações; sem folha, usa o mapa antigo de data/enemies.json
	if sprite and sprite.has_sheet():
		play_anim(key)
		return
	var name: String = data.get("anim", {}).get(key, key)
	play_anim(name)


## Comportamento de lugar (mapas feitos à mão): "sleep" = dorme até o Lume
## chegar perto ou golpeá-lo.
var _asleep: int = -1
var _snore_t: float = 0.0


func _actor_physics(d: float, raw: float) -> void:
	caster.tick(d)
	attack.tick(d)
	ai_t -= d
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
	# cenas da história: ninguém ataca enquanto a câmera conta a história
	var still: bool = level != null and is_instance_valid(level) and level.cutscene != null and level.cutscene.playing
	if _asleep < 0:
		_asleep = 1 if str(get_meta("behavior", "")) == "sleep" else 0
	if _asleep == 1:
		if hp < max_hp() or (target and global_position.distance_to(target.global_position) < 44.0):
			_asleep = 0
			emote("!", 0.8)
		else:
			still = true
			_snore_t -= d
			if _snore_t <= 0.0:
				_snore_t = 2.4
				emote("z", 1.6)
	if still:
		attack.cancel()
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * d)
		if flying:
			velocity.y = move_toward(velocity.y, 0.0, 400.0 * d)
		_gravity(d)
		_move(d, raw)
		_anim("idle")
		return
	for wp in _weak_points:
		wp[0].position = Vector2(wp[1].x * facing, wp[1].y + (12.0 if lowered else 0.0))
	if status.disabled() or stagger_time > 0.0:
		attack.cancel()
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * d)
		if flying:
			velocity.y = move_toward(velocity.y, 0.0, 400.0 * d)
		_gravity(d)
		_move(d, raw)
		_anim("idle")
		return
	if boss:
		_check_phase()
	match ai:
		"melee": _ai_melee(d)
		"lunger": _ai_lunger(d)
		"caster": _ai_caster(d)
		"turret": _ai_turret(d)
		"charger": _ai_charger(d)
		"boss_demon": _ai_boss(d)
		"boss_duelist": _ai_duelist(d)
		"boss_horde": _ai_horde(d)
		"boss_colossus": _ai_colossus(d)
		"gunner": _ai_gunner(d)
		"leaper": _ai_leaper(d)
		"assassin": _ai_assassin(d)
		"shield": _ai_melee(d)
		"diver": _ai_diver(d)
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
	if boss:
		return true # na arena o chefe sempre sabe onde você está
	if status.has("blind"):
		return false
	var dist := body_center().distance_to(target.body_center())
	var range_mult := 1.3 if aggressive else 1.0
	if dist > aggro * range_mult:
		return false
	if not flying and absf(target.global_position.y - global_position.y) > float(data.get("vertical_sight", 50.0)):
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
	var tr := global_transform.translated(Vector2(facing * 6, 0))
	return not test_move(tr, Vector2(0, 4))


func _wall_ahead() -> bool:
	return test_move(global_transform, Vector2(facing * 2, 0))


func _windup_time() -> float:
	var t := 0.42 - 0.06 * (tier - 1)
	if aggressive:
		t *= 0.75
	return maxf(t, 0.2)


func _telegraph(unblockable: bool = false) -> void:
	_flash = 0.0
	emote("anger" if unblockable else "!", _windup_time())
	var tw := create_tween()
	tw.tween_method(func(v): _flash = v, 0.0, 0.8, _windup_time() * 0.8)


# ---------------------------------------------------------------------------
# Perfis de IA
# ---------------------------------------------------------------------------

func _patrol(d: float) -> void:
	if _wall_ahead() or _ledge_ahead() or absf(global_position.x - home.x) > 40.0 and signf(global_position.x - home.x) == facing:
		facing = -facing
	velocity.x = move_toward(velocity.x, facing * speed * 0.5, 600.0 * d)
	_anim("move")


func _melee_attack(kind: String = "light") -> void:
	if moveset.is_empty():
		return
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
				velocity.x = move_toward(velocity.x, 0.0, 800.0 * d)
				_anim("idle")
			else:
				velocity.x = move_toward(velocity.x, facing * speed, 700.0 * d)
				_anim("move")
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * d)
			if ai_t <= 0.0:
				_melee_attack()
				ai_state = "attack"
		"attack":
			var step := attack.step
			if attack.is_busy() and attack.phase != AttackRunner.Phase.RECOVERY:
				velocity.x = facing * float(step.get("lunge", 0.0)) * 0.6
			else:
				velocity.x = move_toward(velocity.x, 0.0, 800.0 * d)
			if not attack.is_busy():
				if combo_left > 0:
					combo_left -= 1
					_melee_attack()
				else:
					ai_state = "recover"
					ai_t = rng.randf_range(0.45, 0.9) * (0.7 if aggressive else 1.0)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * d)
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
			if dist <= attack_range and dist > 10.0 and is_on_floor():
				ai_state = "windup"
				ai_t = _windup_time() * 0.8
				velocity.x = -facing * 20.0
				_telegraph()
				_anim("idle")
			else:
				velocity.x = move_toward(velocity.x, facing * speed, 900.0 * d)
				_anim("move")
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			if ai_t <= 0.0:
				velocity = Vector2(facing * speed * 1.8, -150.0)
				combo_step = 0
				_melee_attack("heavy" if moveset.has("heavy") and rng.randf() < 0.4 else "light")
				ai_state = "attack"
				ai_t = 0.8
		"attack":
			if is_on_floor() and velocity.y >= 0.0 and ai_t < 0.6:
				velocity.x = move_toward(velocity.x, 0.0, 1200.0 * d)
			if ai_t <= 0.0 or (not attack.is_busy() and is_on_floor()):
				attack.cancel()
				ai_state = "recover"
				ai_t = rng.randf_range(0.5, 1.0)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"


func _ai_caster(d: float) -> void:
	_bob += d * 2.2
	var valid := _target_valid()
	var desired := home + Vector2(sin(_bob * 0.5) * 14.0, sin(_bob) * 4.0)
	if valid:
		var away: Vector2 = body_center() - target.body_center()
		var want_dist := attack_range * 0.75
		desired = target.body_center() + away.normalized() * want_dist + Vector2(0, -14 + sin(_bob) * 5.0)
		_face_target()
	elif status.has("blind"):
		desired = global_position + Vector2(_wander_dir * 20.0, sin(_bob) * 10.0)
		if rng.randf() < 0.02:
			_wander_dir = -_wander_dir
	var to := desired - global_position
	velocity = velocity.move_toward(to.limit_length(1.0) * speed * minf(to.length() / 20.0, 1.0), 150.0 * d)
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
			elif valid and not moveset.is_empty() and body_center().distance_to(target.body_center()) < 16.0 and ai_t <= 0.0:
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
			else:
				velocity.x = move_toward(velocity.x, facing * speed, 600.0 * d)
				_anim("move")
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * d)
			if ai_t <= 0.0:
				ai_state = "charge"
				charge_dist = 0.0
				attack.start(moveset.get("heavy", {}), "heavy", facing)
				FX.shake(0.2)
		"charge":
			velocity.x = facing * 180.0
			charge_dist += 180.0 * d
			_anim("attack")
			if attack.phase == AttackRunner.Phase.RECOVERY:
				attack.t = 0.0 # mantém o golpe ativo durante a investida
				attack.phase = AttackRunner.Phase.ACTIVE
				attack.hitbox.activate()
			if _wall_ahead() or charge_dist > 140.0:
				attack.cancel()
				if _wall_ahead():
					FX.shake(0.4)
					stagger_time = 0.9
					emote("?", 0.9)
				ai_state = "recover"
				ai_t = 0.8
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"


# ---------------------------------------------------------------------------
# Inimigos rápidos (sessão 4)
# ---------------------------------------------------------------------------

func _muzzle() -> Vector2:
	return body_center() + Vector2(facing * 4.0, -1.0)


## Atirador: mira (laser acompanha o alvo), trava nos últimos instantes e
## dispara um tiro rápido e rebatível.
func _ai_gunner(d: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
	if _sight == null:
		_sight = LaserSight.new()
		_sight.enemy = self
		add_child(_sight)
	match ai_state:
		"spawn":
			if ai_t <= 0.0:
				ai_state = "idle"
		"idle", "patrol", "chase":
			_laser = maxf(_laser - d * 6.0, 0.0)
			_anim("idle")
			if _target_valid():
				_face_target()
				if ai_t <= 0.0:
					ai_state = "aim"
					ai_t = maxf(0.75 - 0.08 * (tier - 1), 0.45) * (0.8 if aggressive else 1.0)
					_laser_locked = false
					emote("!", ai_t)
					Audio.play("aim", 0.05, -6.0)
		"aim":
			if not _target_valid() and not _laser_locked:
				ai_state = "idle"
				ai_t = 0.4
				return
			_laser = minf(_laser + d * 3.0, 1.0)
			if ai_t > 0.2:
				_face_target()
				_aim_dir = (target.body_center() - _muzzle()).normalized()
			elif not _laser_locked:
				_laser_locked = true
				_flash = 0.8
			if ai_t <= 0.0:
				_fire_bolt()
				_laser = 0.0
				ai_state = "recover"
				ai_t = rng.randf_range(0.9, 1.5) * (0.7 if aggressive else 1.0)
		"recover":
			if ai_t <= 0.0:
				ai_state = "idle"


func _fire_bolt() -> void:
	var p := Projectile.new()
	p.team = team
	p.owner_actor = self
	var info := DamageInfo.new()
	info.amount = float(data.get("shot_damage", 14.0)) * (1.0 + 0.3 * (tier - 1))
	info.damage_type = "pierce"
	info.source = self
	info.team = team
	info.is_projectile = true
	info.parryable = true
	info.knockback = _aim_dir * 90.0 + Vector2(0, -40)
	p.info = info
	p.velocity = _aim_dir * float(data.get("shot_speed", 340.0))
	p.radius = 2.0
	p.style = "bolt"
	p.color = Color(2.8, 0.8, 0.5)
	p.lifetime = 1.4
	p.light_enabled = false
	p.global_position = _muzzle()
	get_parent().add_child(p)
	FX.burst(_muzzle(), Color(2.8, 1.4, 0.6), 4, 120.0, _aim_dir, 30.0)
	Audio.play("shot", 0.08, -3.0)


## Saltador: pulinhos rápidos na direção do alvo; perto, bote pelo ar.
func _ai_leaper(d: float) -> void:
	match ai_state:
		"spawn":
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
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
				if ai_t <= 0.0:
					if absf(_dx()) <= attack_range:
						ai_state = "windup"
						ai_t = _windup_time() * 0.7
						_telegraph()
						sprite.squash(Vector2(1.3, 0.7))
					else:
						velocity = Vector2(facing * speed, -150.0)
						ai_t = rng.randf_range(0.25, 0.45)
			_anim("move" if not is_on_floor() else "idle")
		"windup":
			velocity.x = 0.0
			if ai_t <= 0.0:
				var dx := clampf(_dx(), -attack_range * 1.3, attack_range * 1.3)
				velocity = Vector2(dx / 0.42, -215.0)
				_melee_attack("light")
				ai_state = "leap"
				ai_t = 0.9
				Audio.play("dash", 0.1, -8.0, 1.3)
		"leap":
			if attack.phase == AttackRunner.Phase.RECOVERY and not is_on_floor():
				attack.t = 0.0
				attack.phase = AttackRunner.Phase.ACTIVE
				attack.hitbox.activate()
			if (is_on_floor() and velocity.y >= 0.0 and ai_t < 0.75) or ai_t <= 0.0:
				attack.cancel()
				ai_state = "recover"
				ai_t = rng.randf_range(0.35, 0.6)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"


## Lâmina Sombria: aproxima rápido; perto, pisca e atravessa num dash.
func _ai_assassin(d: float) -> void:
	match ai_state:
		"spawn":
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
			var dist := absf(_dx())
			if dist <= attack_range and ai_t <= 0.0 and is_on_floor():
				ai_state = "windup"
				ai_t = _windup_time() * 0.85
				velocity.x = 0.0
				_telegraph(true)
				Audio.play("draw_blade", 0.05, -4.0)
			elif _ledge_ahead() and dist > 20.0:
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
			else:
				velocity.x = move_toward(velocity.x, facing * speed * (1.0 if dist > 40.0 else 0.4), 900.0 * d)
				_anim("move")
		"windup":
			velocity.x = 0.0
			_face_target()
			if ai_t <= 0.0:
				_dash_dir = Vector2(facing, 0)
				ai_state = "dash"
				ai_t = 0.24
				charge_dist = 0.0
				_melee_attack("light")
				invuln_time = 0.1
		"dash":
			velocity = _dash_dir * 300.0
			charge_dist += 300.0 * d
			if attack.phase == AttackRunner.Phase.RECOVERY:
				attack.t = 0.0
				attack.phase = AttackRunner.Phase.ACTIVE
				attack.hitbox.activate()
			var ai_img := AfterImage.from_sprite(sprite, Color(1.6, 0.4, 0.8, 0.8), 0.18)
			if ai_img:
				get_parent().add_child(ai_img)
			if ai_t <= 0.0 or _wall_ahead() or charge_dist > 90.0:
				attack.cancel()
				velocity.x = _dash_dir.x * 60.0
				ai_state = "recover"
				ai_t = rng.randf_range(0.6, 0.9)
				emote("...", ai_t)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"
				ai_t = rng.randf_range(0.2, 0.6)


## Enxame: paira acima do alvo e mergulha em linha reta.
func _ai_diver(d: float) -> void:
	_bob += d * 3.0
	var valid := _target_valid()
	match ai_state:
		"spawn":
			if ai_t <= 0.0:
				ai_state = "idle"
		"idle", "patrol", "chase":
			var want := home + Vector2(sin(_bob * 0.6) * 18.0, sin(_bob) * 5.0)
			if valid:
				want = target.body_center() + Vector2(sin(_bob * 0.8) * 26.0, -38.0)
				_face_target()
			var to := want - global_position
			velocity = velocity.move_toward(to.limit_length(1.0) * speed * minf(to.length() / 16.0, 1.0), 400.0 * d)
			if valid and ai_t <= 0.0 and absf(_dx()) < 50.0:
				ai_state = "windup"
				ai_t = _windup_time() * 0.7
				_telegraph()
		"windup":
			velocity *= 0.85
			if ai_t <= 0.0:
				_dash_dir = (target.body_center() - global_position).normalized() if target else Vector2.DOWN
				ai_state = "dive"
				ai_t = 0.5
				Audio.play("dash", 0.1, -10.0, 1.5)
		"dive":
			velocity = _dash_dir * 230.0
			if ai_t <= 0.0 or is_on_floor() or is_on_wall():
				ai_state = "recover"
				ai_t = rng.randf_range(0.7, 1.2)
		"recover":
			velocity = velocity.move_toward(Vector2(0, -60.0), 500.0 * d)
			if ai_t <= 0.0:
				ai_state = "idle"
				ai_t = rng.randf_range(0.4, 0.9)


## Escudeiro: bloqueia golpes que vêm pela frente. Pesado, Corte-Relâmpago
## e golpes de cima passam; pogo no escudo quica.
func _shield_blocks(info: DamageInfo) -> bool:
	if ai != "shield" or info.is_hazard or info.is_spell or stagger_time > 0.0:
		return false
	if info.is_heavy or info.is_dash_attack or info.direction.y > 0.5:
		return false
	var src = info.source
	if src == null or not is_instance_valid(src) or not (src is Node2D):
		return false
	var from_front := signf(src.global_position.x - global_position.x) == float(facing)
	return from_front


## Linha da mira do atirador (desenhada em coordenadas do mundo).
class LaserSight extends Node2D:
	var enemy: Node = null

	func _ready() -> void:
		z_index = 30
		top_level = true

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if enemy == null or not is_instance_valid(enemy) or enemy.dead or enemy._laser <= 0.01:
			return
		var from: Vector2 = enemy._muzzle()
		var dir: Vector2 = enemy._aim_dir
		var space: PhysicsDirectSpaceState2D = enemy.get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(from, from + dir * 260.0, Layers.WORLD)
		var hit := space.intersect_ray(q)
		var to: Vector2 = hit["position"] if not hit.is_empty() else from + dir * 260.0
		var locked: bool = enemy._laser_locked
		var blink := locked and int(Time.get_ticks_msec() / 50) % 2 == 0
		var a: float = enemy._laser * (1.0 if not locked else (1.0 if blink else 0.5))
		var c := Color(2.6, 0.3, 0.25, a * 0.8) if not locked else Color(3.0, 2.6, 2.4, a)
		draw_line(from, to, c, 1.0)
		draw_rect(Rect2(to - Vector2(1, 1), Vector2(2, 2)), c)


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
		FX.shake(0.6)
		FX.flash(1.0)
		emote("anger", 1.5)
		speed *= 1.15
		invuln_time = 0.8


func _ai_boss(d: float) -> void:
	_bob += d * 1.6
	if target == null or not is_instance_valid(target):
		return
	_face_target()
	var hover: Vector2 = target.body_center() + Vector2(-facing * 50.0, -32.0 + sin(_bob) * 8.0)
	match ai_state:
		"spawn", "idle", "patrol", "chase":
			var to: Vector2 = hover - global_position
			velocity = velocity.move_toward(to.limit_length(1.0) * speed * minf(to.length() / 24.0, 1.0), 130.0 * d)
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
				velocity = (target.body_center() - global_position).normalized() * 200.0
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
# Chefes novos
# ---------------------------------------------------------------------------

## Retângulo da arena (sala do chefe) em pixels.
func _arena() -> Rect2:
	var room := int(get_meta("room", -1))
	if level and level.has_method("room_rect") and room >= 0:
		return level.room_rect(room)
	return Rect2(home - Vector2(160, 150), Vector2(320, 192))


## y dos pés no chão principal da arena (linha 21 da sala).
func _arena_floor() -> float:
	var a := _arena()
	return a.position.y + LevelConst.FLOOR_ROW * LevelConst.TILE


func _clamp_to_arena(x: float, margin: float = 16.0) -> float:
	var a := _arena()
	return clampf(x, a.position.x + margin, a.end.x - margin)


# --- Duelista Sombrio -------------------------------------------------------

func _ai_duelist(d: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dist := absf(_dx())
	match ai_state:
		"spawn", "idle", "patrol", "chase", "stalk":
			_face_target()
			var want := 26.0
			if dist > want + 8.0:
				velocity.x = move_toward(velocity.x, facing * speed, 700.0 * d)
			elif dist < want - 10.0:
				velocity.x = move_toward(velocity.x, -facing * speed * 0.7, 700.0 * d)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * d)
			_anim("move" if absf(velocity.x) > 10.0 else "idle")
			if ai_t <= 0.0 and is_on_floor():
				_duelist_choose(dist)
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
			if ai_t <= 0.0:
				combo_step = 0
				combo_left = 1 + phase_idx
				_melee_attack()
				ai_state = "attack"
		"attack":
			var step := attack.step
			if attack.is_busy() and attack.phase != AttackRunner.Phase.RECOVERY:
				velocity.x = facing * float(step.get("lunge", 0.0)) * 0.7
			else:
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
			if not attack.is_busy():
				if combo_left > 0:
					combo_left -= 1
					_face_target()
					_melee_attack()
				else:
					ai_state = "recover"
					ai_t = 0.55 - 0.1 * phase_idx
		"iai_windup":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
			_anim("crouch")
			if ai_t <= 0.0:
				attack.start(moveset.get("heavy", {}), "heavy", facing)
				ai_state = "iai"
				ai_t = 0.3
				Audio.play("draw_blade")
		"iai":
			velocity.x = facing * 300.0
			_anim("attack")
			var a := _arena()
			var near_wall := (facing > 0 and global_position.x > a.end.x - 14.0) or (facing < 0 and global_position.x < a.position.x + 14.0)
			if ai_t <= 0.0 or _wall_ahead() or near_wall:
				attack.cancel()
				velocity.x = 0.0
				ai_state = "recover"
				ai_t = 0.75 - 0.15 * phase_idx
		"guard":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
			_face_target()
			_anim("crouch")
			if ai_t <= 0.0:
				ai_state = "stalk"
				ai_t = 0.25
		"riposte":
			velocity.x = 0.0
			if ai_t <= 0.0:
				combo_step = 2
				combo_left = 0
				_face_target()
				_melee_attack()
				ai_state = "attack"
		"leap":
			_anim("attack" if attack.is_busy() else "jump")
			if not attack.is_busy() and velocity.y > -40.0 and absf(_dx()) < 14.0:
				attack.start(moveset.get("down_air", {}), "down_air", facing)
				velocity = Vector2(0, 260.0)
			if is_on_floor() and ai_t < 0.5:
				attack.cancel()
				FX.shake(0.25)
				var ring := NovaFX.new()
				ring.radius = 30
				ring.color = Color(1.6, 0.5, 0.6)
				ring.global_position = global_position
				get_parent().add_child(ring)
				ai_state = "recover"
				ai_t = 0.7
		"blink_windup":
			velocity.x = 0.0
			if ai_t <= 0.0:
				var behind: float = target.global_position.x - float(target.facing) * 18.0
				FX.burst(body_center(), Color(1.4, 0.3, 0.5), 10, 90.0)
				global_position.x = _clamp_to_arena(behind)
				reset_physics_interpolation()
				FX.burst(body_center(), Color(1.4, 0.3, 0.5), 10, 90.0)
				_face_target()
				combo_step = 1
				combo_left = 1
				_melee_attack()
				ai_state = "attack"
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "stalk"
				ai_t = rng.randf_range(0.2, 0.6) - 0.1 * phase_idx


func _duelist_choose(dist: float) -> void:
	var r := rng.randf()
	if dist < 32.0 and r < 0.45:
		ai_state = "windup"
		ai_t = _windup_time()
		_telegraph()
	elif dist > 44.0 and r < 0.6:
		ai_state = "iai_windup"
		ai_t = 0.55 - 0.08 * phase_idx
		_telegraph(true)
	elif r < 0.72 - 0.1 * phase_idx:
		# postura de contra-ataque (azul): quem golpear leva o troco
		ai_state = "guard"
		ai_t = 1.1
		emote("...", 1.1)
	elif phase_idx >= 1 and r < 0.9:
		ai_state = "leap"
		ai_t = 1.2
		velocity = Vector2(signf(_dx()) * minf(dist * 1.8, 150.0), -250.0)
		_telegraph()
	elif phase_idx >= 2:
		ai_state = "blink_windup"
		ai_t = 0.35
		emote("anger", 0.35)
	else:
		ai_state = "windup"
		ai_t = _windup_time()
		_telegraph()


# --- Mãe da Ninhada (chefe de horda) ----------------------------------------

func _alive_minions() -> int:
	var n := 0
	for m in _minions:
		if is_instance_valid(m) and not m.dead:
			n += 1
	return n


func _summon_wave() -> void:
	_wave += 1
	var pool: Dictionary = data.get("minions", {"skeleton": 1})
	var count := 2 + mini(_wave, 3) + phase_idx
	var a := _arena()
	var y := _arena_floor()
	for i in count:
		var id: String = RngUtil.weighted_key(rng, pool)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := a.get_center().x + side * rng.randf_range(80.0, 130.0)
		var pos := Vector2(_clamp_to_arena(x, 24.0), y)
		FX.burst(pos + Vector2(0, -6), Color(1.2, 0.5, 0.9), 10, 80.0, Vector2.UP, 60.0)
		if level and level.has_method("spawn_minion"):
			var m: Node = level.spawn_minion(id, maxi(tier - 1, 1), pos)
			if m:
				_minions.append(m)
	shielded = true
	Audio.play("spell_heavy")


func _ai_horde(d: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
	_face_target()
	match ai_state:
		"spawn", "idle", "patrol", "chase":
			shielded = true
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "summon_windup"
				ai_t = 0.9
				_telegraph(true)
		"summon_windup":
			_anim("cast")
			if ai_t <= 0.0:
				_summon_wave()
				ai_state = "guard"
				ai_t = 2.2
		"guard":
			_anim("idle")
			if _alive_minions() == 0:
				shielded = false
				ai_state = "exposed"
				ai_t = 4.0
				FX.shake(0.3)
				emote("drop", 3.5)
				Audio.play("break")
			elif ai_t <= 0.0 and not spells.is_empty():
				var sp: String = spells[0] if phase_idx == 0 else RngUtil.pick(rng, spells)
				caster.cooldowns.erase(sp)
				var aim: Vector2 = (target.body_center() - body_center()).normalized()
				caster.cast(sp, phase_idx, aim, target.body_center())
				ai_t = 3.0 - 0.9 * phase_idx
		"exposed":
			_anim("hurt")
			if ai_t <= 0.0:
				ai_state = "summon_windup"
				ai_t = 0.9
				_telegraph(true)


# --- Colosso de Pedra -------------------------------------------------------

func _ai_colossus(d: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dist := absf(_dx())
	match ai_state:
		"spawn", "idle", "patrol", "chase":
			lowered = false
			_face_target()
			velocity.x = move_toward(velocity.x, facing * speed * (1.0 + 0.3 * phase_idx), 300.0 * d)
			_anim("move")
			if ai_t <= 0.0 and is_on_floor():
				var r := rng.randf()
				if dist < 48.0 and r < 0.55:
					ai_state = "slam_windup"
					ai_t = 0.8 - 0.15 * phase_idx
					_telegraph(true)
					if sprite:
						sprite.squash(Vector2(0.85, 1.2))
				elif dist < 34.0:
					ai_state = "sweep_windup"
					ai_t = 0.6
					_telegraph()
				elif r < 0.55 + 0.2 * phase_idx:
					ai_state = "rocks_windup"
					ai_t = 0.7
					emote("anger", 0.7)
				else:
					ai_t = 0.6
		"slam_windup":
			velocity.x = 0.0
			_anim("idle")
			if ai_t <= 0.0:
				_slam()
				ai_state = "slam_recover"
				ai_t = 1.5 - 0.3 * phase_idx
				lowered = true
		"slam_recover":
			velocity.x = 0.0
			_anim("crouch")
			if ai_t <= 0.0:
				lowered = false
				ai_state = "recover"
				ai_t = 0.3
		"sweep_windup":
			velocity.x = 0.0
			if ai_t <= 0.0:
				attack.start(moveset.get("heavy", {}), "heavy", facing)
				_anim("attack")
				ai_state = "attack"
		"attack":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			if not attack.is_busy():
				ai_state = "recover"
				ai_t = 0.8
		"rocks_windup":
			velocity.x = 0.0
			_anim("cast")
			if ai_t <= 0.0:
				_rocks(4 + 2 * phase_idx)
				ai_state = "recover"
				ai_t = 1.0
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"
				ai_t = rng.randf_range(0.3, 0.8)


## Pisão: tremor + ondas de choque rasteiras para os dois lados (pule!).
func _slam() -> void:
	FX.shake(0.7)
	Audio.play("explosion")
	var ring := NovaFX.new()
	ring.radius = 44
	ring.color = Color(1.4, 1.2, 0.9)
	ring.global_position = global_position
	get_parent().add_child(ring)
	var waves := 1 + phase_idx
	for k in waves:
		for side in [-1.0, 1.0]:
			var p := Projectile.new()
			p.team = team
			p.owner_actor = self
			var info := DamageInfo.new()
			info.amount = 12.0
			info.damage_type = "blunt"
			info.team = team
			info.source = self
			info.parryable = false
			info.unblockable = true
			info.knockback = Vector2(side * 120.0, -120.0)
			p.info = info
			p.radius = 3.0
			p.style = "rock"
			p.color = Color(0.72, 0.64, 0.52)
			p.velocity = Vector2(side * (130.0 + 40.0 * k), 0.0)
			p.lifetime = 1.6
			p.reflectable = false
			p.light_enabled = false
			p.global_position = global_position + Vector2(side * 14.0, -5.0)
			get_parent().add_child(p)


## Chuva de pedras: poeira avisa onde cada pedra vai cair.
func _rocks(n: int) -> void:
	FX.shake(0.3)
	var a := _arena()
	for i in n:
		var x := _clamp_to_arena(target.global_position.x + rng.randf_range(-70.0, 70.0), 12.0)
		var top := Vector2(x, a.position.y + 14.0)
		FX.burst(top, Color(0.8, 0.7, 0.6), 5, 40.0, Vector2.DOWN, 30.0, 0.5, 1.0)
		var delay := 0.55 + i * 0.12
		get_tree().create_timer(delay, false).timeout.connect(func():
			if dead or not is_inside_tree():
				return
			var p := Projectile.new()
			p.team = team
			p.owner_actor = self
			var info := DamageInfo.new()
			info.amount = 10.0
			info.damage_type = "blunt"
			info.team = team
			info.source = self
			p.info = info
			p.radius = 3.0
			p.style = "rock"
			p.color = Color(0.58, 0.55, 0.5)
			p.velocity = Vector2(0, 30.0)
			p.gravity_y = 520.0
			p.lifetime = 2.0
			p.light_enabled = false
			p.global_position = top
			get_parent().add_child(p))


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
	info.knockback = Vector2(facing * float(step.get("kb", 150.0)), -60.0)
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
	info.knockback = info.direction * 80.0 + Vector2(0, -60)
	info.parryable = true
	return info


## Duelista em postura: contra-ataca. Mãe da Ninhada com escudo: bloqueia.
func _before_hit(info: DamageInfo) -> int:
	if info.is_hazard:
		return -1
	if _shield_blocks(info):
		FX.burst(body_center() + Vector2(facing * 4, 0), Color(2.4, 2.2, 1.6), 6, 120.0)
		FX.hitstop(0.04)
		Audio.play("hit_metal", 0.1, -3.0)
		sprite.squash(Vector2(0.85, 1.1))
		if info.pogo and info.source and info.source.has_method("_pogo"):
			info.source._pogo()
		return DamageInfo.Result.BLOCKED
	if shielded:
		FX.burst(body_center(), Color(0.6, 1.6, 2.4), 8, 90.0)
		Audio.play("block", 0.1, -4.0)
		return DamageInfo.Result.BLOCKED
	if ai == "boss_duelist" and ai_state == "guard" and not info.is_spell and info.source != self:
		ai_state = "riposte"
		ai_t = 0.12
		_face_target()
		FX.burst(body_center(), Color(2.4, 2.4, 3.0), 10, 120.0)
		FX.hitstop(0.08)
		Audio.play("parry")
		emote("!", 0.4)
		return DamageInfo.Result.PARRIED
	return -1


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	if sprite == null:
		return
	if shielded:
		sprite.status_color = Color(0.5, 1.4, 2.2) # escudo da ninhada
	elif ai == "boss_duelist" and ai_state == "guard":
		sprite.status_color = Color(0.4, 0.8, 2.4) # postura: não golpeie!


func on_parried(_by: Node, perfect: bool) -> void:
	attack.cancel()
	poise = 0.0
	stagger_time = 1.5 if perfect else 0.8
	if boss:
		stagger_time *= 0.5
	velocity = Vector2(-facing * 80.0, -30.0 if not flying else 0.0)
	if perfect:
		status.add("mark", 1)
	ai_state = "recover"
	ai_t = stagger_time


func _has_super_armor() -> bool:
	return boss or (moveset.get("super_armor", false) and attack.is_busy())


func _apply_knockback(info: DamageInfo) -> void:
	var k := 0.25 if boss or data.get("elite", false) else 1.0
	if info.knockback != Vector2.ZERO:
		velocity = info.knockback * k


func _on_damaged(info: DamageInfo, amount: float) -> void:
	var heavy := info.is_heavy or info.weak_point_mult > 1.0
	var w := info.weight
	if info.weak_point_mult > 1.0 and w >= 0.0:
		w = minf(w + 0.2, 1.0)
	var by_player: bool = info.source != null and is_instance_valid(info.source) and info.source is Player
	if hp > 0.0 and by_player:
		FX.impact(body_center(), info.direction, amount, info.is_crit or info.weak_point_mult > 1.0, heavy, Color(2.0, 1.8, 1.4), w)
	else:
		FX.damage_number(body_center(), amount, info.is_crit)
	if info.weak_point_mult > 1.0:
		emote("!", 0.4)
	if ai_state in ["idle", "patrol"]:
		ai_state = "chase"
		_face_target()


func _on_staggered(_info: DamageInfo) -> void:
	attack.cancel()
	ai_state = "recover"
	ai_t = 0.5
	emote("?", 0.6)


func _on_death(info: DamageInfo) -> void:
	attack.cancel()
	shielded = false
	for m in _minions:
		if is_instance_valid(m) and not m.dead:
			m.take_status_damage(99999.0, "fall")
	_minions.clear()
	if contact_hitbox:
		contact_hitbox.deactivate()
	collision_layer = 0
	for c in get_children():
		if c is Hurtbox:
			c.queue_free()
	remove_from_group("actors")
	remove_from_group("enemies")
	var dir := info.direction if info.direction != Vector2.ZERO else Vector2(-facing, 0)
	var w := clampf(info.weight if info.weight >= 0.0 else 0.3, 0.0, 1.0)
	var last: bool = level != null and level.has_method("is_last_enemy") and level.is_last_enemy(self)
	var by_player: bool = info.source != null and is_instance_valid(info.source) and info.source is Player
	if by_player or boss:
		FX.kill_impact(body_center(), dir, 1.0 if boss else w, last or boss)
	Audio.play("enemy_death", 0.1, -4.0)
	Events.enemy_killed.emit(self, info)
	if level and level.has_method("on_enemy_killed"):
		level.on_enemy_killed(self)
	if boss:
		FX.shake(0.9)
		FX.burst(body_center(), Color(2.8, 1.4, 0.6), 40, 110.0)
		var tw := create_tween()
		tw.tween_method(set_dissolve, 0.0, 1.0, 2.0)
		tw.tween_callback(queue_free)
		return
	# Katana Zero: cortado em dois na direção do golpe
	DeathFX.spawn(get_parent(), sprite, dir, w)
	if sprite:
		sprite.visible = false
	var tw2 := create_tween()
	tw2.tween_interval(0.2)
	tw2.tween_callback(queue_free)


## Drops do loadout (mesmo pool do jogador). Retorna ids sorteados.
func roll_drops(luck: float = 0.0) -> Array:
	var out := []
	for dd in data.get("drops", []):
		if rng.randf() < float(dd.get("chance", 0.0)) * (1.0 + luck):
			out.append(dd["id"])
	return out
