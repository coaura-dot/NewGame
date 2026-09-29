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
##   moth     - mariposa: circula a chama do herói e mergulha (rouba foco)
##   shield   - guarda de escudo: bloqueia de frente, escudada + estocada
##   gust     - Sopro: inspira e sopra rajadas que empurram (rebatíveis)
##   shade    - Sombra: no escuro nada a atinge; espreita e dá o bote (amarelo);
##              depois do bote fica na luz da chama (castigue!); na luz de uma
##              lamparina fica atordoada; com a sala toda acesa, se desmancha
##
## DUELO (Dead Cells + Hollow Knight): troca de golpes, não spam.
##   - Telegrafia: antes de cada golpe o inimigo brilha AMARELO (dá para
##     aparar/rebater) ou VERMELHO (só esquivando), mostra "!"/"!!" e a arma
##     cintila no último instante. Cada cor tem um som.
##   - Combos de 1-3 golpes com pausas variadas; no tier 2+ o combo de 3
##     termina num golpe pesado vermelho.
##   - Janela de punição: depois do combo o inimigo fica exposto (golpes
##     quebram a postura bem mais rápido).
##   - Guarda: apanhar seguido fora da janela faz o inimigo erguer a guarda
##     (bloqueia golpes leves de frente) e contra-atacar. Golpe pesado quebra
##     a guarda; pogo e golpes pelas costas passam. Feras recuam e dão o bote.
##   - Aparo perfeito abre um CONTRA-GOLPE (próximo acerto crítico).

signal phase_changed(phase: int)

const TELE_YELLOW := Color(1.0, 0.78, 0.12)
const TELE_RED := Color(1.0, 0.12, 0.12)
const GLINT_YELLOW := Color(3.2, 2.6, 0.5)
const GLINT_RED := Color(3.4, 0.6, 0.5)
const PUNISH_POISE := 1.8 ## golpes na janela de punição quebram a postura mais rápido
const GUARD_WINDOW := 1.4 ## golpes dentro desse intervalo contam como "spam"
const GUARD_TIME := 0.6 ## quanto tempo segura a guarda antes do contra-ataque
const GUARD_BLOCKS := 2 ## golpes que a guarda aguenta antes de contra-atacar na hora
const COUNTER_WINDUP := 0.24
const RIPOSTE_TIME := 1.2 ## depois de um aparo perfeito: o próximo acerto é crítico
const RIPOSTE_MULT := 1.8

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
# duelo
var guard_threshold: int = 0 ## golpes seguidos (fora da janela) até erguer a guarda; 0 = nunca
var punish_t: float = 0.0 ## >0 = exposto depois de atacar
var riposte_t: float = 0.0 ## >0 = aparado em cheio: próximo acerto é contra-golpe
var guard_blocks: int = 0
var tele_red: bool = false ## o golpe telegrafado agora é vermelho (não dá para aparar)
var _attack_red: bool = false ## o golpe em andamento é vermelho
var _combo_red_finisher: bool = false
var _spam_hits: Array = [] ## tempos dos golpes recebidos fora da janela
var _glint_done: bool = true
var _pending_spell: String = "" ## magia escolhida no início da conjuração
var brain: GuardianBrain = null ## chefes guardiões (padrões por dados)


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
	var default_guard := 0
	match ai:
		"melee": default_guard = 3 if tier <= 1 else 2
		"lunger": default_guard = 2
		"charger": default_guard = 3
		"guardian": default_guard = 3
	guard_threshold = int(data.get("guard", default_guard))


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
	if moveset.is_empty() and data.has("damage"):
		moveset = {"damage": float(data["damage"])}
	if ai == "guardian":
		brain = GuardianBrain.new(self)
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
		if ai == "moth":
			contact_hitbox.hit.connect(_on_moth_hit)
		elif ai == "shade":
			contact_hitbox.hit.connect(_on_shade_hit)
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
	_duel_tick(d)
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
		"diver": _ai_diver(d)
		"moth": _ai_moth(d)
		"shield": _ai_shield(d)
		"gust": _ai_gust(d)
		"shade": _ai_shade(d)
		"guardian": brain.tick(d)
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


## Aviso antes do golpe: brilho do corpo, "!" (amarelo) ou "!!" (vermelho),
## som e, no último instante, a arma cintila (ver _duel_tick).
func _telegraph(unblockable: bool = false, duration: float = -1.0) -> void:
	var t := duration if duration > 0.0 else _windup_time()
	tele_red = unblockable
	_glint_done = false
	_flash = 0.0
	if _mat:
		_mat.set_shader_parameter("flash_color", TELE_RED if unblockable else TELE_YELLOW)
	var tw := create_tween()
	tw.tween_method(func(v): _flash = v, 0.0, 0.85, t * 0.8)
	if emote:
		emote.show_emote("danger" if unblockable else "warn", t + 0.1, true)
	Audio.play("telegraph_red" if unblockable else "telegraph", 0.04, -9.0 if not unblockable else -6.0)
	if unblockable and level and level.has_method("hint_once"):
		level.hint_once("red_attack")
	elif level and level.has_method("hint_once"):
		level.hint_once("yellow_attack")


func _duel_tick(d: float) -> void:
	punish_t = maxf(punish_t - d, 0.0)
	riposte_t = maxf(riposte_t - d, 0.0)
	# a arma cintila no último instante da preparação
	if not _glint_done and ai_state.ends_with("windup") and ai_t <= 0.14:
		_glint_done = true
		var at := body_center() + Vector2(facing * (float(data.get("body", [8, 12])[0]) * 0.5 + 3.0), -3.0)
		FX.glint(at, GLINT_RED if tele_red else GLINT_YELLOW)
	elif not ai_state.ends_with("windup"):
		_glint_done = true


## Janela de punição: o inimigo fica exposto por `t` segundos.
func _open_punish(t: float) -> void:
	punish_t = t
	_spam_hits.clear()
	if not flying and not boss:
		FX.burst(body_center() + Vector2(facing * 3, -4), Color(0.95, 0.95, 1.0, 0.7), 3, 20.0, Vector2(facing, -1), 40.0, 0.35)


## Guarda contra spam: registra o golpe e, se passar do limite, defende.
func _count_spam(info: DamageInfo) -> void:
	if guard_threshold <= 0 or boss or info.is_spell or info.is_hazard or info.pogo:
		return
	if punish_t > 0.0 or riposte_t > 0.0 or stagger_time > 0.0:
		return
	if not ai_state in ["idle", "patrol", "chase", "windup", "recover"]:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_spam_hits.append(now)
	_spam_hits = _spam_hits.filter(func(t): return now - t < GUARD_WINDOW)
	if _spam_hits.size() >= guard_threshold:
		_spam_hits.clear()
		if ai == "lunger":
			_start_evade()
		else:
			_start_guard()


func _start_guard() -> void:
	attack.cancel()
	ai_state = "guard"
	ai_t = GUARD_TIME
	guard_blocks = GUARD_BLOCKS
	velocity.x = 0.0
	_face_target()
	emote.show_emote("guard", GUARD_TIME + 0.2, true)
	Audio.play("guard", 0.05, -6.0)
	if _mat:
		_mat.set_shader_parameter("flash_color", Color(0.6, 0.8, 1.0))
	_flash = 0.6
	if level and level.has_method("hint_once"):
		level.hint_once("guard")


## Feras não bloqueiam: pulam para trás e dão o bote em seguida.
func _start_evade() -> void:
	attack.cancel()
	_face_target()
	velocity = Vector2(-facing * 120.0, -150.0)
	ai_state = "evade"
	ai_t = 0.3
	_anim("jump")
	FX.dust(global_position, Vector2(facing, -0.4), 3)


## Golpe de frente contra a guarda? (pogo e golpes pelas costas passam)
func _guard_blocks(info: DamageInfo) -> bool:
	if ai_state != "guard" or info.is_spell or info.is_hazard or info.pogo or info.unblockable:
		return false
	var from_front := info.direction.x == 0.0 or signf(info.direction.x) != float(facing)
	return from_front


func _before_hit(info: DamageInfo) -> int:
	if ai == "shield":
		return _shield_hit(info)
	if ai == "shade" and not info.is_hazard and not shade_lit():
		# no escuro o golpe atravessa a fumaça
		FX.burst(body_center(), Color(0.5, 0.45, 0.8, 0.6), 4, 30.0)
		if level and level.has_method("hint_once"):
			level.hint_once("shade")
		return DamageInfo.Result.INVULNERABLE
	if not _guard_blocks(info):
		return -1
	if info.is_heavy:
		# golpe pesado quebra a guarda: atordoa e abre a janela de punição
		ai_state = "recover"
		stagger_time = 0.9
		ai_t = 0.9
		_open_punish(1.2)
		emote.show_emote("dizzy", 0.9, true)
		FX.text(body_center() + Vector2(0, -14), "GUARDA QUEBRADA!", Color(1.0, 0.85, 0.35))
		FX.shake(0.2)
		return -1
	guard_blocks -= 1
	FX.hit_spark(body_center() + Vector2(facing * 5, -2), Vector2(-facing, 0), Color(2.2, 2.6, 3.2), true)
	Audio.play("guard", 0.08, -4.0)
	_flash = 0.7
	if guard_blocks <= 0:
		ai_t = 0.0 # contra-ataca já
	return DamageInfo.Result.BLOCKED


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


func _melee_attack(kind: String = "light", red: bool = false) -> void:
	if moveset.is_empty():
		return
	_attack_red = red
	if _mat:
		_mat.set_shader_parameter("flash_color", TELE_RED if red else Color(1, 1, 1))
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
				var chain_len := int(moveset.get("light", [1]).size())
				var max_combo := mini(1 + tier, chain_len)
				combo_left = rng.randi_range(0, max_combo - 1)
				combo_step = 0
				_combo_red_finisher = tier >= 2 and combo_left >= 2 and moveset.has("heavy")
				# às vezes (tier 2+) abre com um golpe pesado vermelho, mais lento
				var red_open := tier >= 2 and moveset.has("heavy") and combo_left == 0 and rng.randf() < 0.35
				ai_t = _windup_time() + (0.15 if red_open else 0.0)
				velocity.x = 0.0
				_telegraph(red_open, ai_t)
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
				_melee_attack("heavy" if tele_red else "light", tele_red)
				ai_state = "attack"
		"attack":
			var step := attack.step
			if attack.is_busy() and attack.phase != AttackRunner.Phase.RECOVERY:
				velocity.x = facing * float(step.get("lunge", 0.0)) * 0.6
			else:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			if not attack.is_busy():
				if combo_left > 0:
					# pausa curta e variada entre os golpes (não dá para decorar)
					combo_left -= 1
					ai_state = "combo_windup"
					var red := combo_left == 0 and _combo_red_finisher
					ai_t = rng.randf_range(0.16, 0.34) + (0.14 if red else 0.0)
					_face_target()
					_telegraph(red, ai_t)
				else:
					ai_state = "recover"
					ai_t = rng.randf_range(0.55, 0.95) * (0.7 if aggressive else 1.0)
					_open_punish(ai_t)
		"combo_windup":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("windup")
			if ai_t <= 0.0:
				_melee_attack("heavy" if tele_red else "light", tele_red)
				ai_state = "attack"
		"guard":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_face_target()
			_anim("windup")
			if ai_t <= 0.0:
				# contra-ataque rápido (amarelo: quem esperou pode aparar)
				ai_state = "windup"
				combo_left = 0
				combo_step = 0
				_combo_red_finisher = false
				ai_t = COUNTER_WINDUP
				_telegraph(false, ai_t)
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
				var heavy_bite := moveset.has("heavy") and rng.randf() < 0.35
				ai_t = _windup_time() * 0.8 + (0.12 if heavy_bite else 0.0)
				velocity.x = -facing * 20.0
				_telegraph(heavy_bite, ai_t)
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
				_melee_attack("heavy" if tele_red else "light", tele_red)
				ai_state = "attack"
				ai_t = 0.8
		"evade":
			# pulou para trás: ao pousar, prepara o bote na hora
			if is_on_floor() and velocity.y >= 0.0:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * d)
			if ai_t <= 0.0 and is_on_floor():
				_face_target()
				ai_state = "windup"
				ai_t = _windup_time() * 0.6
				_telegraph(false, ai_t)
				_anim("windup")
		"attack":
			if is_on_floor() and velocity.y >= 0.0 and ai_t < 0.6:
				velocity.x = move_toward(velocity.x, 0.0, 800.0 * d)
			if ai_t <= 0.0 or (not attack.is_busy() and is_on_floor()):
				attack.cancel()
				ai_state = "recover"
				ai_t = rng.randf_range(0.55, 1.0)
				_open_punish(ai_t)
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
				_pending_spell = RngUtil.pick(rng, spells)
				_telegraph(_spell_is_red(_pending_spell), ai_t)
				_anim("cast")
			elif valid and not moveset.is_empty() and body_center().distance_to(target.body_center()) < 20.0 and ai_t <= 0.0:
				_melee_attack()
				ai_t = 1.2
		"windup":
			velocity *= 0.9
			if ai_t <= 0.0:
				var sp: String = _pending_spell if _pending_spell != "" else RngUtil.pick(rng, spells)
				_pending_spell = ""
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
					_telegraph(false, ai_t)
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
				_telegraph(true, ai_t)
				velocity.x = -facing * 30.0
				_anim("idle")
				emote.show_emote("anger", 0.6)
			else:
				velocity.x = move_toward(velocity.x, facing * speed, 400.0 * d)
				_anim("move")
		"guard":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_face_target()
			_anim("idle")
			if ai_t <= 0.0:
				# contra-ataque: investida (vermelha — esquive!)
				ai_state = "windup"
				ai_t = _windup_time()
				_telegraph(true, ai_t)
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
				_open_punish(1.1 if stagger_time > 0.0 else 0.8)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"


## Mergulhador (estilo Vengefly): persegue pelo ar, telegrafa e dá um rasante
## em linha reta na direção do herói. Ótimo alvo de pogo no meio do parkour.
func _ai_diver(d: float) -> void:
	_bob += d * 3.0
	var valid := _target_valid()
	match ai_state:
		"spawn", "idle", "patrol":
			var hover := home + Vector2(sin(_bob * 0.5) * 10.0, sin(_bob) * 3.0)
			velocity = velocity.move_toward((hover - global_position).limit_length(1.0) * speed * 0.5, 200.0 * d)
			_anim("idle")
			if valid:
				ai_state = "chase"
		"chase":
			if not valid:
				ai_state = "patrol"
				return
			_face_target()
			var want: Vector2 = target.body_center() + Vector2(-facing * 18.0, -22.0 + sin(_bob) * 4.0)
			var to := want - global_position
			velocity = velocity.move_toward(to.limit_length(1.0) * speed * 1.4, 260.0 * d)
			if to.length() < 14.0 and ai_t <= 0.0:
				ai_state = "windup"
				ai_t = _windup_time() * 0.8
				_telegraph(false, ai_t)
		"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * d)
			# recua um pouquinho antes do bote
			global_position += Vector2(0, -8.0 * d)
			if ai_t <= 0.0:
				var dir: Vector2 = (target.body_center() - global_position).normalized() if target else Vector2(facing, 0.5)
				velocity = dir * 190.0
				ai_state = "dive"
				ai_t = 0.45
				Audio.play("dash", 0.1, -10.0, 1.3)
		"dive":
			if ai_t <= 0.0 or test_move(global_transform, velocity.normalized() * 2.0):
				ai_state = "recover"
				ai_t = rng.randf_range(0.6, 0.9)
		"recover":
			velocity = velocity.move_toward(Vector2(0, -30.0), 300.0 * d)
			if ai_t <= 0.0:
				ai_state = "chase"
				ai_t = rng.randf_range(0.2, 0.6)


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
					_telegraph(phase_idx >= 1, ai_t)
				else:
					ai_state = "cast_windup"
					ai_t = _windup_time() + 0.2
					var pool: Array = spells.slice(0, mini(spells.size(), phase_idx + 1))
					_pending_spell = RngUtil.pick(rng, pool) if not pool.is_empty() else ""
					_telegraph(phase_idx >= 2 or _spell_is_red(_pending_spell), ai_t)
					_anim("cast")
		"swoop_windup":
			velocity *= 0.92
			if ai_t <= 0.0:
				ai_state = "swoop"
				ai_t = 0.55
				velocity = (target.body_center() - global_position).normalized() * 210.0
				var chain: Array = moveset.get("light", [])
				_attack_red = tele_red
				if not chain.is_empty():
					attack.start(chain[mini(phase_idx, chain.size() - 1)], "light", facing)
				_anim("attack")
		"swoop":
			if ai_t <= 0.0:
				ai_state = "recover"
				ai_t = 0.9 - 0.2 * phase_idx
				_open_punish(ai_t)
		"cast_windup":
			velocity *= 0.9
			if ai_t <= 0.0:
				var pool: Array = spells.slice(0, mini(spells.size(), phase_idx + 1))
				var sp: String = _pending_spell if _pending_spell != "" else RngUtil.pick(rng, pool)
				_pending_spell = ""
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
	info.parryable = not _attack_red and not (ai == "charger" and kind == "heavy")
	info.unblockable = not info.parryable
	if not info.parryable:
		info.tags.append("red")
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
		riposte_t = RIPOSTE_TIME
	ai_state = "recover"
	ai_t = stagger_time
	_open_punish(stagger_time)


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


## Janela de punição e contra-golpe mexem no golpe antes do dano.
func _modify_incoming(info: DamageInfo, amount: float) -> float:
	if info.source is Player and not info.is_hazard:
		if riposte_t > 0.0 and not info.is_spell:
			riposte_t = 0.0
			amount *= RIPOSTE_MULT
			info.is_crit = true
			info.stagger *= 2.0
			info.tags.append("riposte")
			FX.text(body_center() + Vector2(0, -16), "CONTRA-GOLPE!", Color(1.0, 0.9, 0.4))
			FX.hitstop(0.1)
		elif punish_t > 0.0:
			info.stagger *= PUNISH_POISE
			info.tags.append("punish")
	return amount


func _on_damaged(info: DamageInfo, amount: float) -> void:
	_count_spam(info)
	if info.tags.has("punish"):
		FX.hit_spark(body_center(), info.direction, Color(3.0, 2.4, 0.8), false)
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


# ---------------------------------------------------------------------------
# Mariposa de Cinza: circula a chama e mergulha
# ---------------------------------------------------------------------------

var _orbit: float = 0.0


func _ai_moth(d: float) -> void:
	_bob += d * 5.0
	var valid := _target_valid()
	match ai_state:
		"spawn", "idle", "patrol":
			var hover := home + Vector2(sin(_bob * 0.4) * 14.0, sin(_bob * 0.9) * 5.0)
			velocity = velocity.move_toward((hover - global_position).limit_length(1.0) * speed * 0.5, 220.0 * d)
			_anim("idle")
			if valid:
				ai_state = "chase"
				ai_t = rng.randf_range(1.0, 1.8)
				_orbit = (global_position - target.body_center()).angle()
		"chase":
			if not valid:
				ai_state = "patrol"
				return
			# voa em volta da chama do herói (mariposa e luz)
			_orbit += d * 2.4
			var flame: Vector2 = target.body_center() + Vector2(0, -8)
			var want := flame + Vector2(cos(_orbit) * 26.0, sin(_orbit) * 14.0 - 6.0)
			velocity = velocity.move_toward((want - global_position).limit_length(1.0) * speed * 1.3, 360.0 * d)
			facing = 1 if velocity.x >= 0.0 else -1
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "windup"
				ai_t = _windup_time() * 0.9
				_telegraph(false, ai_t)
		"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * d)
			_face_target()
			_anim("windup")
			if ai_t <= 0.0 and target:
				var flame2: Vector2 = target.body_center() + Vector2(0, -8)
				velocity = (flame2 - global_position).normalized() * 175.0
				ai_state = "dive"
				ai_t = 0.42
				_anim("attack")
				Audio.play("dash", 0.1, -12.0, 1.5)
		"dive":
			if ai_t <= 0.0 or test_move(global_transform, velocity.normalized() * 2.0):
				_moth_daze()
		"recover":
			velocity = velocity.move_toward(Vector2(0, -12.0), 200.0 * d)
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "chase"
				ai_t = rng.randf_range(1.2, 2.2)


func _moth_daze() -> void:
	ai_state = "recover"
	ai_t = rng.randf_range(0.6, 0.85)
	_open_punish(ai_t)
	velocity *= 0.2


func _on_moth_hit(t: Node, _info: DamageInfo, result: int) -> void:
	if result != DamageInfo.Result.HIT or not (t is Player):
		return
	t.gain_focus(-12.0)
	t.rig.flame_blow(signf(t.global_position.x - global_position.x))
	FX.text(t.body_center() + Vector2(0, -16), "a mariposa bebeu sua chama!", Color(0.9, 0.8, 1.0))
	_moth_daze()


# ---------------------------------------------------------------------------
# Guarda de Cinzas: escudo sempre erguido; escudada (amarela) + estocada (vermelha)
# ---------------------------------------------------------------------------

var _shield_broken: float = 0.0


func _shield_up() -> bool:
	return _shield_broken <= 0.0 and stagger_time <= 0.0 and ai_state in ["idle", "patrol", "chase", "windup", "spawn"]


func _shield_hit(info: DamageInfo) -> int:
	if not _shield_up() or info.is_spell or info.is_hazard or info.pogo or info.unblockable:
		return -1
	var from_front := info.direction.x == 0.0 or signf(info.direction.x) != float(facing)
	if not from_front:
		return -1
	if info.is_heavy:
		_shield_broken = 1.6
		ai_state = "recover"
		ai_t = 1.4
		attack.cancel()
		_open_punish(1.4)
		stagger_time = 0.5
		_anim("tired")
		emote.show_emote("dizzy", 1.2, true)
		FX.text(body_center() + Vector2(0, -16), "ESCUDO QUEBRADO!", Color(1.0, 0.85, 0.35))
		FX.shake(0.25)
		Audio.play("hit_metal", 0.05, -2.0)
		return -1
	FX.hit_spark(body_center() + Vector2(facing * 6, -1), Vector2(-facing, 0), Color(2.6, 2.2, 1.4), true)
	Audio.play("guard", 0.08, -3.0)
	_flash = 0.6
	if level and level.has_method("hint_once"):
		level.hint_once("shield")
	return DamageInfo.Result.BLOCKED


func _attack_step(step: Dictionary, kind: String, red: bool) -> void:
	_attack_red = red
	if _mat:
		_mat.set_shader_parameter("flash_color", TELE_RED if red else Color(1, 1, 1))
	attack.start(step, kind, facing)


func _ai_shield(d: float) -> void:
	_shield_broken = maxf(_shield_broken - d, 0.0)
	match ai_state:
		"spawn", "idle", "patrol":
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
				ai_t = _windup_time() + 0.05
				velocity.x = 0.0
				_telegraph(false, ai_t)
			elif _ledge_ahead():
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
				_anim("idle")
			else:
				velocity.x = move_toward(velocity.x, facing * speed, 300.0 * d)
				_anim("move")
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("windup")
			if ai_t <= 0.0:
				# escudada (amarela: dá para aparar)
				_attack_step(moveset.get("heavy", {}), "heavy", false)
				velocity.x = facing * 90.0
				_anim("bash")
				ai_state = "bash"
		"bash":
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * d)
			if not attack.is_busy():
				# emenda a estocada vermelha se o herói ainda está na frente
				if target and absf(_dx()) < attack_range + 20.0 and signf(_dx()) == float(facing):
					ai_state = "combo_windup"
					ai_t = rng.randf_range(0.22, 0.34)
					_telegraph(true, ai_t)
				else:
					ai_state = "recover"
					ai_t = 0.6
					_open_punish(ai_t)
		"combo_windup":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("windup")
			if ai_t <= 0.0:
				var chain: Array = moveset.get("light", [])
				_attack_step(chain[chain.size() - 1] if not chain.is_empty() else {}, "light", true)
				velocity.x = facing * 150.0
				_anim("attack")
				ai_state = "thrust"
		"thrust":
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * d)
			if not attack.is_busy():
				# escudo abaixado: a grande janela de punição
				ai_state = "recover"
				ai_t = rng.randf_range(0.9, 1.2)
				_open_punish(ai_t)
				_anim("tired")
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
			_anim("tired")
			if ai_t <= 0.0:
				ai_state = "chase"


# ---------------------------------------------------------------------------
# Sopro Errante: inspira (amarelo) e sopra uma rajada que empurra
# ---------------------------------------------------------------------------

func _ai_gust(d: float) -> void:
	_bob += d * 2.0
	var valid := _target_valid()
	var desired := home + Vector2(sin(_bob * 0.5) * 12.0, sin(_bob) * 4.0)
	if valid:
		var side := signf(global_position.x - target.global_position.x)
		if side == 0.0:
			side = 1.0
		desired = target.body_center() + Vector2(side * attack_range * 0.8, -6.0 + sin(_bob) * 4.0)
		_face_target()
	var to := desired - global_position
	if ai_state in ["idle", "patrol", "chase", "spawn", "recover"]:
		velocity = velocity.move_toward(to.limit_length(1.0) * speed * minf(to.length() / 16.0, 1.0), 180.0 * d)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * d)
	match ai_state:
		"spawn", "idle", "patrol", "chase":
			_anim("idle")
			if valid and ai_t <= 0.0:
				ai_state = "windup"
				ai_t = _windup_time() + 0.25
				_telegraph(false, ai_t)
				_anim("windup")
		"windup":
			_anim("windup")
			if ai_t <= 0.0 and target:
				_blow()
				ai_state = "recover"
				ai_t = rng.randf_range(1.3, 2.0)
				_open_punish(0.7)
				_anim("attack")
		"recover":
			if ai_t <= 0.0:
				ai_state = "chase"


func _blow() -> void:
	var dir := Vector2(float(facing), 0.0)
	if target:
		dir = (target.body_center() - body_center()).normalized()
		dir.y = clampf(dir.y, -0.35, 0.35)
		dir = dir.normalized()
	var p := GustShot.new()
	p.team = team
	p.owner_actor = self
	var info := DamageInfo.new()
	info.amount = 3.0 + 2.0 * (tier - 1)
	info.damage_type = "wind"
	info.source = self
	info.team = team
	info.is_projectile = true
	info.status = {"chill": 1}
	info.tags.append("gust")
	info.parryable = true
	p.info = info
	p.velocity = dir * 105.0
	p.radius = 6.0
	p.lifetime = 1.8
	p.color = Color(1.6, 2.4, 2.8)
	p.global_position = body_center() + dir * 7.0
	get_parent().add_child(p)
	Audio.play("spell_pressure", 0.08, -6.0)
	FX.burst(body_center() + dir * 6.0, Color(1.8, 2.4, 2.8, 0.8), 5, 60.0, dir, 30.0, 0.3)


## Magias de área (nova, campos) não dá para rebater: telegrafia vermelha.
func _spell_is_red(spell_id: String) -> bool:
	if spell_id == "":
		return false
	var cast_mode: String = DB.spell(spell_id).get("cast", "projectile")
	return cast_mode in ["nova", "field", "time_field", "storm", "sigil"]


## Drops do loadout (mesmo pool do jogador). Retorna ids sorteados.
func roll_drops(luck: float = 0.0) -> Array:
	var out := []
	for dd in data.get("drops", []):
		if rng.randf() < float(dd.get("chance", 0.0)) * (1.0 + luck):
			out.append(dd["id"])
	return out



# ---------------------------------------------------------------------------
# Sombra: só pode ser ferida na luz (chama do herói de perto, lamparina acesa
# ou sala inteira iluminada). Espreita no escuro e dá o bote.
# ---------------------------------------------------------------------------

const SHADE_HERO_LIGHT := 34.0 ## a chama do Pavio alcança até aqui
const SHADE_LAMP_LIGHT := 46.0 ## a luz de uma lamparina acesa
const SHADE_LURK_DIST := 62.0 ## distância em que ela espreita
var _shade_alpha: float = 0.35


func shade_lit() -> bool:
	if level and level.has_method("room_light_factor"):
		var room := int(get_meta("room", -1))
		if room >= 0 and level.room_light_factor(room) >= 0.999:
			return true
	if target and is_instance_valid(target) and body_center().distance_to(target.body_center()) < SHADE_HERO_LIGHT:
		return true
	return _near_lit_lamp()


func _near_lit_lamp() -> bool:
	for l in get_tree().get_nodes_in_group("lamps_lit"):
		if (l as Node2D).global_position.distance_to(global_position) < SHADE_LAMP_LIGHT:
			return true
	return false


func _ai_shade(d: float) -> void:
	_bob += d * 4.0
	var lit := shade_lit()
	# visual: fumaça quase invisível no escuro, sólida na luz
	_shade_alpha = move_toward(_shade_alpha, 1.0 if lit else 0.32, d * 4.0)
	if sprite:
		sprite.modulate.a = _shade_alpha
	var valid := _target_valid()
	match ai_state:
		"spawn", "idle", "patrol":
			var hover := home + Vector2(sin(_bob * 0.5) * 16.0, sin(_bob * 0.8) * 6.0)
			velocity = velocity.move_toward((hover - global_position).limit_length(1.0) * speed * 0.5, 200.0 * d)
			_anim("idle")
			if valid:
				ai_state = "lurk"
				ai_t = rng.randf_range(1.0, 1.8)
				_orbit = (global_position - target.body_center()).angle()
		"lurk":
			if not valid:
				ai_state = "patrol"
				return
			if _near_lit_lamp() and level and level.has_method("room_light_factor") and level.room_light_factor(int(get_meta("room", -1))) < 0.999:
				_shade_stun()
				return
			# ronda a chama de longe, sempre fora do alcance da luz
			_orbit += d * 1.1
			var c: Vector2 = target.body_center() + Vector2(0, -10)
			var want := c + Vector2(cos(_orbit) * SHADE_LURK_DIST, sin(_orbit) * 20.0 - 12.0)
			velocity = velocity.move_toward((want - global_position).limit_length(1.0) * speed, 300.0 * d)
			facing = 1 if target.global_position.x > global_position.x else -1
			_anim("idle")
			if ai_t <= 0.0:
				ai_state = "windup"
				ai_t = maxf(_windup_time() + 0.12, 0.4)
				_telegraph(false, ai_t)
		"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * d)
			_face_target()
			_anim("windup")
			if ai_t <= 0.0 and target:
				velocity = (target.body_center() - body_center()).normalized() * 200.0
				ai_state = "dive"
				ai_t = 0.45
				_anim("attack")
				Audio.play("dash", 0.1, -12.0, 0.7)
		"dive":
			if ai_t <= 0.0 or test_move(global_transform, velocity.normalized() * 2.0):
				_shade_daze()
		"recover":
			# fica perto da chama (vulnerável) até recuperar
			if target:
				var near: Vector2 = target.body_center() + Vector2(-float(facing) * 14.0, -8.0)
				velocity = velocity.move_toward((near - global_position).limit_length(1.0) * 20.0, 120.0 * d)
			_anim("tired")
			if ai_t <= 0.0:
				ai_state = "lurk"
				ai_t = rng.randf_range(1.4, 2.4)
		"stunned":
			velocity = velocity.move_toward(Vector2(0, 6.0), 150.0 * d)
			_anim("tired")
			if ai_t <= 0.0:
				ai_state = "lurk"
				ai_t = rng.randf_range(1.0, 1.6)
				_orbit += PI


func _shade_daze() -> void:
	ai_state = "recover"
	ai_t = rng.randf_range(0.8, 1.0)
	_open_punish(ai_t)
	velocity *= 0.15


## Na luz de uma lamparina a Sombra se encolhe e fica atordoada.
func _shade_stun() -> void:
	ai_state = "stunned"
	ai_t = 1.3
	_open_punish(1.3)
	velocity = Vector2.ZERO
	emote.show_emote("dizzy", 1.2, true)
	FX.burst(body_center(), Color(0.7, 0.6, 1.4), 6, 40.0)
	Audio.play("guard", 0.1, -8.0, 0.6)


func _on_shade_hit(t: Node, _info: DamageInfo, result: int) -> void:
	if result != DamageInfo.Result.HIT or not (t is Player):
		return
	if ai_state == "dive":
		_shade_daze()
