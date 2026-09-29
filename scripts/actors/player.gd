class_name Player
extends Actor
## O herói — Pavio, uma velinha viva de ~11 px (mais a chama) numa tela de 320x180.
##
## MOVIMENTO no estilo Celeste, com os números do próprio Celeste (px/s na
## escala de tiles de 8 px): aceleração/inércia, coyote time, buffer de pulo,
## pulo variável, meia gravidade no ápice, correção de quina, deslizar/saltar/
## escalar parede, dash em 8 direções com super/hyper/wallbounce. O corpo anda
## em PIXELS INTEIROS (resto subpixel acumulado), igual ao Celeste — colisão
## exata, nada de "escorregar" em quinas.
##
## COMBATE no estilo Hollow Knight: golpear NÃO trava o movimento (corre,
## pula e dá dash batendo), golpes direcionais (lado / cima / baixo no ar =
## pogo), recuo ao acertar, faísca + hitstop curto, dano no jogador com
## congelamento e invencibilidade. Por cima: combos, pesado carregável (arte
## da lâmina), ataque em dash, aparar, esquiva, magias, sigilos e foco (cura).
##
## Tudo que é "número de feel" está nas constantes abaixo.

signal focus_changed(current: float, maximum: float)
signal state_changed(state: int)

enum State { NORMAL, DASH, CLIMB, ATTACK, DODGE, HURT, DEAD, SIGIL, POUND, RESPAWN, HEAL, REST }

# --- Corrida (Celeste) ---
const MAX_RUN := 90.0
const RUN_ACCEL := 1000.0
const RUN_REDUCE := 400.0 ## acima da velocidade máxima (preserva o embalo)
const AIR_MULT := 0.65
const AIR_REDUCE := 140.0 ## no ar, acima da velocidade máxima, segurando para frente: embalo dura
const AIR_DRAG_FAST := 200.0 ## no ar, acima da máxima, sem segurar nada: perde embalo devagar
const LAND_GRACE := 0.1 ## logo depois de pousar o embalo não cai (pular em seguida mantém tudo)
const DUCK_FRICTION := 500.0
# --- Gravidade / pulo (Celeste) ---
const GRAVITY := 900.0
const MAX_FALL := 160.0
const FAST_MAX_FALL := 240.0
const FAST_MAX_ACCEL := 300.0
const HALF_GRAV_THRESHOLD := 40.0
const JUMP_SPEED := 105.0
const JUMP_H_BOOST := 40.0
const VAR_JUMP_TIME := 0.2
const DOUBLE_JUMP_SPEED := 100.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.1
const UPWARD_CORNER := 4
# --- Parede (Celeste) ---
const WALL_JUMP_H := MAX_RUN + JUMP_H_BOOST
const WALL_JUMP_FORCE_TIME := 0.16
const WALL_JUMP_CHECK := 3
const WALL_SLIDE_START := 20.0
const WALL_SLIDE_TIME := 1.2
const CLIMB_UP := 45.0
const CLIMB_DOWN := 80.0
const CLIMB_STAMINA := 110.0
const CLIMB_UP_COST := 45.45
const CLIMB_STILL_COST := 10.0
const CLIMB_JUMP_COST := 27.5
const CLIMB_HOP_Y := 120.0
const CLIMB_HOP_X := 100.0
# --- Dash (Celeste) ---
const DASH_SPEED := 240.0
const DASH_END_SPEED := 160.0
const DASH_END_UP_MULT := 0.75
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.2
const DASH_REFILL_COOLDOWN := 0.1
const DASH_CORNER := 4
const DASH_FREEZE := 0.03
const SUPER_H := 260.0
const HYPER_X_MULT := 1.25
const HYPER_Y_MULT := 0.5
const SUPER_WALL_JUMP_SPEED := 160.0
const SUPER_WALL_JUMP_H := MAX_RUN + JUMP_H_BOOST * 2.0
const SUPER_WALL_JUMP_VAR := 0.25
const WALL_KICK_H := 190.0 ## dash + pulo encostado na parede: chute forte para longe dela
const WALL_KICK_JUMP := 1.1
# --- Combate (Hollow Knight) ---
const POGO_SPEED := 150.0
const RECOIL_X := 120.0
const RECOIL_TIME := 0.08
const RECOIL_UP := 40.0
const HURT_TIME := 0.18
const HURT_IFRAMES := 1.1
const HURT_FREEZE := 0.1
const HURT_KNOCK_X := 110.0
const HURT_KNOCK_Y := 110.0
const DODGE_SPEED := 170.0
const DODGE_TIME := 0.2
const DODGE_IFRAMES := 0.18
const DODGE_COOLDOWN := 0.35
const PERFECT_DODGE_WINDOW := 0.1
const PARRY_WINDOW := 0.17
const PERFECT_PARRY := 0.075
const PARRY_COOLDOWN := 0.3
const POUND_SPEED := 320.0
const ATTACK_BUFFER := 0.12
const COMBO_TIMEOUT := 1.2
const AIR_STALL := 35.0 ## golpe acertado no ar segura a queda (combos aéreos)
const AIR_STALL_MAX := 3 ## quantas vezes por salto
const KILL_POP := 100.0 ## abater no ar dá um quique (continua a cadeia)
const CHAIN_MIN := 3 ## cadeia aérea mínima que dá recompensa ao pousar
const FOCUS_MAX_BASE := 100.0
const HEAL_HOLD := 0.2 ## segurar para focar; toque rápido = poção
const HEAL_TIME := 0.85
const HEAL_COST := 33.0
const HEAL_AMOUNT := 20.0 ## uma velinha de vida no HUD
# --- Corpo ---
const LIGHT_ENERGY := 0.4 ## luz da chama do Pavio
const BODY := Vector2(8, 11)
const DUCK_BODY := Vector2(8, 6)
const HURT_SIZE := Vector2(6, 9)

var state: int = State.NORMAL
var level: Node = null ## a fase (Level) — define respawn, checkpoints etc.

# física por dimensão
var phys: Dictionary = {}
var rules: Array = []
var g_dir: float = 1.0

# movimento
var on_ground := false
var was_on_floor := false
var coyote_t := 0.0
var jump_buffer_t := 0.0
var var_jump_t := 0.0
var var_jump_speed := 0.0
var auto_jump_t := 0.0 ## quiques (orbe, pogo): age como se o pulo estivesse segurado
var land_grace_t := 0.0
var air_chain := 0 ## ações encadeadas sem tocar o chão
var bonus_jumps := 0 ## pulo extra de Pena/Sino (some ao pousar)
var _wall_refill_ready := true ## parede recarrega o dash uma vez por toque
var _step_t := 0.0
var _fx_tween: Tween = null ## morte/renascer (cancelado ao reviver)
var best_chain := 0
var force_move_x := 0
var force_move_t := 0.0
var wall_dir := 0 ## parede encostada (-1/1) segurando na direção dela
var wall_slide_t := 0.0
var stamina := CLIMB_STAMINA
var air_jumps := 0
var dashes := 1
var dash_cd := 0.0
var dash_refill_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector2.RIGHT
var dash_on_ground := false
var max_fall := MAX_FALL
var ducking := false
var drop_t := 0.0
var input_x := 0.0
var input_y := 0.0
var recoil_t := 0.0
var recoil_x := 0.0
var air_stalls := 0
var _rem := Vector2.ZERO
var _after_t := 0.0
var _prev_pos := Vector2.ZERO
var _fall_start_y := 0.0
var _land_speed := 0.0

# combate
var moveset: Dictionary = {}
var weapon_id := ""
var combo_index := 0
var combo_count := 0
var combo_timer := 0.0
var attack_buffer_t := 0.0
var attack_dir := "side" ## side | up | down
var heavy_charging := false
var heavy_t := 0.0
var rhythm_stacks := 0
var parry_t := 0.0
var parry_cd := 0.0
var blocking := false
var dodge_t := 0.0
var dodge_cd := 0.0
var hurt_t := 0.0
var heal_hold_t := 0.0
var heal_t := 0.0
var focus := 0.0
var buffs: BuffSystem
var echo_charges := 0
var echo_mult := 0.6
var echo_time := 0.0
var sigil_points: PackedVector2Array = []
var last_safe_pos := Vector2.ZERO
## Em salas de desafio a fase define isto: tocar espinho volta ao início da sala.
var hazard_spawn_override := Vector2.ZERO
var _safe_t := 0.0
var _history: Array = [] ## [pos, hp]
var _history_t := 0.0
var _spell_refund: Dictionary = {}
var _using_mouse := false
var _dash_through_hit: Dictionary = {}
var _recent_hits: Array = [] ## tempos dos últimos danos (para o emote de raiva)
var _idle_t := 0.0
var _cast_pose_t := 0.0

# nós
var interact_area: Area2D
var light: PointLight2D
var rig: HeroRig
var scarf: Scarf
var emote: EmoteBubble
var body_shape: CollisionShape2D
var hurtbox: Hurtbox


func _ready() -> void:
	team = Layers.Team.PLAYER
	super._ready()
	add_to_group("actors")
	add_to_group("player")
	safe_margin = 0.01
	body_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY
	body_shape.shape = rect
	body_shape.position = Vector2(0, -BODY.y * 0.5)
	add_child(body_shape)
	rig = HeroRig.new()
	rig.name = "Rig"
	add_child(rig)
	_mat = rig.mat
	scarf = Scarf.new()
	scarf.host = self
	add_child(scarf)
	emote = EmoteBubble.new()
	emote.height = 14.0
	add_child(emote)
	hurtbox = Hurtbox.make(self, HURT_SIZE, Vector2(0, -HURT_SIZE.y * 0.5 - 1.0))
	add_child(hurtbox)
	interact_area = Area2D.new()
	interact_area.collision_layer = 0
	interact_area.collision_mask = Layers.INTERACT
	var ic := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 10.0
	ic.shape = circ
	ic.position = Vector2(0, -6)
	interact_area.add_child(ic)
	add_child(interact_area)
	attack = AttackRunner.new(self)
	add_child(attack)
	attack.landed.connect(_on_attack_landed)
	attack.activated.connect(_on_attack_activated)
	# pogo em espinhos e serras (Hollow Knight): golpe para baixo quica neles
	attack.hitbox.pogo_surface.connect(func(_at: Vector2):
		if not on_ground:
			_pogo()
			FX.hit_spark(global_position + Vector2(0, 6), Vector2.UP, Color(2.4, 2.4, 2.8)))
	attack.hitbox.projectile_reflected.connect(_on_reflect)
	caster = SpellCaster.new(self)
	add_child(caster)
	buffs = BuffSystem.new(self)
	light = LightUtil.make_light(Color(1.0, 0.82, 0.58), LIGHT_ENERGY, 0.85)
	if light:
		light.position = Vector2(0, -14)
		add_child(light)
	apply_profile()
	hp = max_hp()
	focus = 30.0
	global_position = global_position.round()
	_prev_pos = global_position
	last_safe_pos = global_position
	Events.player_spawned.emit(self)
	Events.settings_changed.connect(_on_settings_changed)
	_update_scarf_color()


## Relê equipamento, atributos, buffs e física da dimensão a partir do perfil.
func apply_profile() -> void:
	var p: Dictionary = Game.profile
	stats = StatBlock.new({"max_hp": float(p.get("max_hp", 100.0)), "focus_max": FOCUS_MAX_BASE})
	var armor := Inventory.armor_bonus(p)
	stats.set_source("armor", armor["stats"])
	equip_weapon(p.get("weapon", "katana_andarilho"))
	var all_buffs: Array = p.get("buffs", []).duplicate()
	all_buffs.append_array(armor["buffs"])
	buffs.set_buffs(all_buffs)
	var dim: Dictionary = DB.dimension(p.get("dimension", "prima"))
	phys = dim.get("physics", {})
	rules = dim.get("rules", [])
	g_dir = float(phys.get("gravity_dir", 1))
	up_direction = Vector2(0, -g_dir)
	if rig:
		rig.flip_v = g_dir < 0
	dashes = max_dashes()


func equip_weapon(id: String) -> void:
	weapon_id = id
	moveset = DB.moveset(id)
	var w: Dictionary = DB.weapon(id)
	stats.set_source("weapon", w.get("stats", {}))
	combo_index = 0
	Events.player_equipment_changed.emit()


func swap_weapon() -> void:
	var p: Dictionary = Game.profile
	var alt: String = p.get("weapon_alt", "")
	if alt == "" or attack.is_busy():
		return
	p["weapon_alt"] = p["weapon"]
	p["weapon"] = alt
	equip_weapon(alt)
	Audio.play("draw_blade")
	Events.toast.emit(DB.display_name(alt))


func has_rule(r: String) -> bool:
	return rules.has(r)


func max_dashes() -> int:
	var n := 1 + int(stats.get_stat("dash_count")) + int(phys.get("dash_bonus", 0))
	if Game.has_ability("dash_2"):
		n += 1
	return n


func max_air_jumps() -> int:
	return 1 if Game.has_ability("double_jump") else 0


func max_focus() -> float:
	return stats.get_stat("focus_max")


func gain_focus(v: float) -> void:
	focus = clampf(focus + v, 0.0, max_focus())
	focus_changed.emit(focus, max_focus())
	Events.player_focus_changed.emit(focus, max_focus())


func refill_dash() -> void:
	var had := dashes
	dashes = maxi(dashes, max_dashes()) # o extra do cristal duplo fica até usar
	air_jumps = max_air_jumps()
	if dashes > had and scarf:
		scarf.flash = 1.0
	_update_scarf_color()
	Events.player_dash_changed.emit(dashes, max_dashes())


## Cristal duplo: dashes acima do máximo até usar.
func grant_dashes(n: int) -> void:
	var had := dashes
	dashes = maxi(dashes, n)
	if dashes > had and scarf:
		scarf.flash = 1.0
	_update_scarf_color()
	Events.player_dash_changed.emit(dashes, max_dashes())


## Pena/Sino: um pulo extra no ar (vale mesmo sem o pulo duplo).
func grant_bonus_jump() -> void:
	bonus_jumps = 1
	if scarf:
		scarf.flash = 1.0


func grounded() -> bool:
	return on_ground


func _set_state(s: int) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)


func _update_scarf_color() -> void:
	if scarf == null:
		return
	if dashes <= 0 and not Settings.gameplay("infinite_dash"):
		scarf.color = Scarf.COL_NONE
	elif dashes >= 2:
		scarf.color = Scarf.COL_TWO
	else:
		scarf.color = Scarf.COL_ONE


## Âncora do cachecol (pescoço) na posição INTERPOLADA de exibição.
func scarf_anchor() -> Vector2:
	var f := Engine.get_physics_interpolation_fraction()
	var base := _prev_pos.lerp(global_position, f) if is_physics_interpolated_and_enabled() else global_position
	return base + rig.anchor("neck")


func scarf_visible() -> bool:
	return rig.visible and state != State.DEAD and rig.anim != "dead"


func body_center() -> Vector2:
	return global_position + Vector2(0, -6 * g_dir if not ducking else -3 * g_dir)


# ---------------------------------------------------------------------------
# Loop principal
# ---------------------------------------------------------------------------

func _actor_physics(d: float, raw: float) -> void:
	_prev_pos = global_position
	_read_input()
	_timers(d)
	caster.tick(d)
	buffs.update(d)
	attack.speed_mult = 1.0
	attack.tick(d)
	_record_history(d)
	match state:
		State.NORMAL, State.ATTACK: _st_normal(d)
		State.DASH: _st_dash(d)
		State.CLIMB: _st_climb(d)
		State.DODGE: _st_dodge(d)
		State.HURT: _st_hurt(d)
		State.SIGIL: _st_sigil(d, raw)
		State.POUND: _st_pound(d)
		State.HEAL: _st_heal(d)
		State.REST: _st_rest(d)
		State.RESPAWN, State.DEAD:
			velocity = Vector2.ZERO
	if state != State.RESPAWN and state != State.DEAD:
		_ride_platform()
		_move(d)
		_after_move(d)
	_animate(d)
	_speed_trail(d)


## Rastro quando o herói está muito rápido (super, hyper, quiques) — mostra o embalo.
func _speed_trail(d: float) -> void:
	if state == State.DASH or state == State.DODGE:
		return
	if absf(velocity.x) > MAX_RUN * 1.6 or _vy() < -JUMP_SPEED * 1.4:
		_after_t -= d
		if _after_t <= 0.0:
			_after_t = 0.05
			_ghost(Color(1.2, 1.2, 1.8, 0.45), 0.16)


func _read_input() -> void:
	input_x = Input.get_axis("move_left", "move_right")
	input_y = Input.get_axis("move_up", "move_down")
	input_x = signf(input_x) if absf(input_x) > 0.3 else 0.0
	input_y = signf(input_y) if absf(input_y) > 0.45 else 0.0
	if has_rule("mirrored_controls"):
		input_x = -input_x
	if Input.is_action_just_pressed("jump"):
		jump_buffer_t = JUMP_BUFFER
	if Input.is_action_just_pressed("attack"):
		attack_buffer_t = ATTACK_BUFFER
	if input_x != 0.0 or input_y != 0.0 or not Input.get_vector("move_left", "move_right", "move_up", "move_down").is_zero_approx():
		_idle_t = 0.0


func _input(event: InputEvent) -> void:
	# mira com o mouse enquanto ele estiver em uso; controle volta à mira analógica
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_mouse = true
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_using_mouse = false
	if event.is_pressed() and not event.is_echo():
		_idle_t = 0.0


func _timers(d: float) -> void:
	coyote_t -= d
	jump_buffer_t -= d
	var_jump_t -= d
	auto_jump_t -= d
	land_grace_t -= d
	force_move_t -= d
	dash_cd -= d
	dash_refill_cd -= d
	drop_t -= d
	parry_t -= d
	parry_cd -= d
	dodge_cd -= d
	attack_buffer_t -= d
	combo_timer -= d
	recoil_t -= d
	_cast_pose_t -= d
	if combo_timer <= 0.0 and combo_count > 0:
		combo_count = 0
		Events.combo_changed.emit(0)
	if echo_time > 0.0:
		echo_time -= d
		if echo_time <= 0.0:
			echo_charges = 0
	if drop_t <= 0.0:
		collision_mask |= Layers.ONE_WAY
	if Settings.gameplay("infinite_dash"):
		dashes = max_dashes()


func _max_run() -> float:
	return MAX_RUN * float(phys.get("speed", 1.0)) * (1.0 + stats.get_stat("move_speed")) * status.speed_mult()


func _vy() -> float:
	return velocity.y * g_dir


func _set_vy(v: float) -> void:
	velocity.y = v * g_dir


# ---------------------------------------------------------------------------
# Colisão em pixels inteiros (estilo Celeste)
# ---------------------------------------------------------------------------

func _collides(offset: Vector2) -> bool:
	return test_move(global_transform, offset)


func _wall_at(dir: int, dist: int = 1) -> bool:
	return _collides(Vector2(dir * dist, 0))


## Em cima de uma plataforma móvel? Anda junto com ela (em pixels inteiros).
func _ride_platform() -> void:
	if not on_ground:
		return
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(BODY.x - 2.0, 2.0)
	q.shape = r
	q.transform = Transform2D(0.0, global_position + Vector2(0, g_dir))
	q.collision_mask = Layers.ONE_WAY
	for hit in space.intersect_shape(q, 4):
		var c: Object = hit["collider"]
		if c is MovingPlatform and c.delta_pos != Vector2.ZERO:
			var saved := _rem
			_rem = Vector2.ZERO
			_move_h(c.delta_pos.x)
			_move_v(c.delta_pos.y)
			_rem = saved
			return


func _move(d: float) -> void:
	var total := velocity + external_velocity
	_move_h(total.x * d)
	_move_v(total.y * d)


func _move_h(amount: float) -> void:
	_rem.x += amount
	var mv := int(roundf(_rem.x))
	if mv == 0:
		return
	_rem.x -= mv
	var s := signi(mv)
	while mv != 0:
		if _collides(Vector2(s, 0)):
			# correção de quina no dash horizontal: sobe/desce até 4 px
			if state == State.DASH and absf(dash_dir.x) > 0.5 and _dash_corner(s):
				continue
			_rem.x = 0.0
			_on_collide_h()
			return
		global_position.x += s
		mv -= s


func _dash_corner(s: int) -> bool:
	var dirs := [-g_dir] if dash_dir.y * g_dir <= 0.0 else [g_dir]
	if absf(dash_dir.y) < 0.1:
		dirs = [-g_dir, g_dir]
	for i in range(1, DASH_CORNER + 1):
		for dy in dirs:
			var off := Vector2(0, dy * i)
			if not _collides(off) and not test_move(global_transform.translated(off), Vector2(s, 0)):
				global_position += off + Vector2(s, 0)
				return true
	return false


func _move_v(amount: float) -> void:
	_rem.y += amount
	var mv := int(roundf(_rem.y))
	if mv == 0:
		return
	_rem.y -= mv
	var s := signi(mv)
	while mv != 0:
		if _collides(Vector2(0, s)):
			# correção de quina ao subir (4 px para o lado livre)
			if s * g_dir < 0 and state != State.CLIMB and _up_corner(s):
				continue
			_rem.y = 0.0
			_on_collide_v(s)
			return
		global_position.y += s
		mv -= s


func _up_corner(s: int) -> bool:
	var order := [-1, 1] if velocity.x <= 0.0 else [1, -1]
	for i in range(1, UPWARD_CORNER + 1):
		for dx in order:
			var off := Vector2(dx * i, 0)
			if not _collides(off) and not test_move(global_transform.translated(off), Vector2(0, s)):
				global_position += off + Vector2(0, s)
				return true
	return false


func _on_collide_h() -> void:
	if state == State.DASH:
		FX.dust(global_position + Vector2(signf(velocity.x) * 4.0, -6), Vector2(-signf(velocity.x), 0), 3)
	velocity.x = 0.0


func _on_collide_v(s: int) -> void:
	if s * g_dir > 0:
		_land_speed = _vy()
	else:
		var_jump_t = 0.0
	velocity.y = 0.0


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _run(d: float, accel_mult: float = 1.0) -> void:
	var max_run := _max_run()
	var mult := (1.0 if on_ground else AIR_MULT * float(phys.get("air_control", 1.0))) * accel_mult
	var move := input_x
	if force_move_t > 0.0:
		move = force_move_x
	var fast := absf(velocity.x) > max_run
	if ducking and on_ground:
		velocity.x = move_toward(velocity.x, 0.0, DUCK_FRICTION * d)
	elif fast and signf(velocity.x) == move:
		# embalo (super, hyper, quiques): no ar dura bem mais; no chão, logo
		# após pousar, não cai nada (bunny hop)
		if not on_ground:
			velocity.x = move_toward(velocity.x, max_run * move, AIR_REDUCE * d)
		elif land_grace_t <= 0.0:
			velocity.x = move_toward(velocity.x, max_run * move, RUN_REDUCE * mult * d)
	elif fast and move == 0.0 and not on_ground:
		velocity.x = move_toward(velocity.x, signf(velocity.x) * max_run, AIR_DRAG_FAST * d)
	else:
		var friction := float(phys.get("friction", 1.0)) if move == 0.0 else 1.0
		velocity.x = move_toward(velocity.x, max_run * move, RUN_ACCEL * mult * friction * d)
	if recoil_t > 0.0:
		velocity.x = recoil_x
	if move != 0.0 and not _attack_locks_facing():
		facing = int(move)


func _attack_locks_facing() -> bool:
	return attack.is_busy() and attack.phase != AttackRunner.Phase.RECOVERY


func _gravity_step(d: float) -> void:
	var g := GRAVITY * float(phys.get("gravity", 1.0))
	var vy := _vy()
	# meia gravidade no ápice segurando pulo (feel de Celeste)
	var holding := Input.is_action_pressed("jump") or auto_jump_t > 0.0
	var mult := 0.5 if absf(vy) < HALF_GRAV_THRESHOLD and holding else 1.0
	# queda rápida segurando baixo
	if input_y * g_dir > 0.0 and vy >= max_fall:
		max_fall = move_toward(max_fall, FAST_MAX_FALL, FAST_MAX_ACCEL * d)
	else:
		max_fall = move_toward(max_fall, MAX_FALL, FAST_MAX_ACCEL * d)
	var mf := max_fall
	# deslizar na parede (começa devagar e acelera, como em Celeste)
	if wall_dir != 0 and input_x == wall_dir and vy > 0.0 and not on_ground and state == State.NORMAL:
		wall_slide_t = minf(wall_slide_t + d, WALL_SLIDE_TIME)
		mf = lerpf(WALL_SLIDE_START, MAX_FALL, wall_slide_t / WALL_SLIDE_TIME)
		if rng.randf() < d * 14.0:
			FX.dust(global_position + Vector2(wall_dir * 4, -9), Vector2.DOWN, 1)
	else:
		wall_slide_t = maxf(wall_slide_t - d * 3.0, 0.0)
	vy = move_toward(vy, mf, g * mult * d)
	if var_jump_t > 0.0:
		if holding:
			vy = minf(vy, -var_jump_speed)
		else:
			var_jump_t = 0.0
	_set_vy(vy)


func _try_jump() -> bool:
	if jump_buffer_t <= 0.0:
		return false
	var jmult := float(phys.get("jump", 1.0))
	# soltar de plataforma one-way (baixo + pulo)
	if on_ground and input_y * g_dir > 0 and _standing_on_one_way():
		jump_buffer_t = 0.0
		drop_t = 0.2
		collision_mask &= ~Layers.ONE_WAY
		global_position.y += 1 * g_dir
		return true
	if on_ground or coyote_t > 0.0:
		_jump(JUMP_SPEED * jmult)
		velocity.x += JUMP_H_BOOST * input_x
		return true
	# salto de parede: basta estar a até 3 px de uma parede (Celeste)
	var wd := 0
	if _wall_at(1, WALL_JUMP_CHECK):
		wd = 1
	elif _wall_at(-1, WALL_JUMP_CHECK):
		wd = -1
	if wd != 0 and Game.has_ability("wall_jump"):
		_wall_jump(wd, jmult)
		return true
	if bonus_jumps > 0:
		bonus_jumps -= 1
		_jump(DOUBLE_JUMP_SPEED * jmult, "djump")
		if input_x != 0.0:
			velocity.x = maxf(absf(velocity.x), MAX_RUN) * input_x
		FX.burst(global_position, Color(1.0, 2.4, 1.0, 0.9), 6, 60.0, Vector2.DOWN, 60.0)
		_ghost(Color(0.9, 1.8, 0.9, 0.7))
		rig.bump(Vector2(0.75, 1.3))
		return true
	if air_jumps > 0:
		air_jumps -= 1
		_jump(DOUBLE_JUMP_SPEED * jmult, "djump")
		if input_x != 0.0:
			velocity.x = maxf(absf(velocity.x), MAX_RUN) * input_x
		FX.burst(global_position, Color(1.8, 1.7, 2.2, 0.9), 6, 60.0, Vector2.DOWN, 60.0)
		_ghost(Color(1.2, 1.2, 1.8, 0.7))
		rig.bump(Vector2(0.75, 1.3))
		return true
	return false


func _wall_jump(wd: int, jmult: float) -> void:
	# pular "subindo" encostado segurando na parede e sem empurrar para fora = climb jump
	if state == State.CLIMB and input_x != -wd and Game.has_ability("wall_climb"):
		stamina -= CLIMB_JUMP_COST
		_jump(JUMP_SPEED * jmult)
		velocity.x = 0.0
		_set_state(State.NORMAL)
		return
	_jump(JUMP_SPEED * jmult, "walljump")
	velocity.x = -wd * WALL_JUMP_H
	add_chain()
	force_move_x = -wd
	force_move_t = WALL_JUMP_FORCE_TIME
	facing = -wd
	_set_state(State.NORMAL)
	FX.dust(global_position + Vector2(wd * 4, -4), Vector2(-wd, -0.4), 4)
	rig.bump(Vector2(0.8, 1.2))


func _jump(speed: float, snd: String = "jump") -> void:
	jump_buffer_t = 0.0
	coyote_t = 0.0
	_set_vy(-speed)
	var_jump_t = VAR_JUMP_TIME
	var_jump_speed = speed
	on_ground = false
	if snd != "":
		Audio.play(snd, 0.1, -8.0)
	FX.dust(global_position, Vector2.UP, 3)
	rig.bump(Vector2(0.7, 1.35))


func _standing_on_one_way() -> bool:
	var saved := collision_mask
	collision_mask = Layers.WORLD
	var solid_below := _collides(Vector2(0, g_dir))
	collision_mask = saved
	return not solid_below


func _set_duck(v: bool) -> void:
	if v == ducking:
		return
	if not v and not _can_stand():
		return
	ducking = v
	var size := DUCK_BODY if v else BODY
	(body_shape.shape as RectangleShape2D).size = size
	body_shape.position = Vector2(0, -size.y * 0.5 * g_dir)
	if v:
		rig.bump(Vector2(1.2, 0.85))


func _can_stand() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = BODY - Vector2(0.2, 0.2)
	q.shape = r
	q.transform = Transform2D(0.0, global_position + Vector2(0, -BODY.y * 0.5 * g_dir))
	q.collision_mask = Layers.WORLD
	return space.intersect_shape(q, 1).is_empty()


func _st_normal(d: float) -> void:
	# agachar (só parado no chão, sem atacar)
	_set_duck(on_ground and input_y * g_dir > 0 and not attack.is_busy() and not heavy_charging)
	var charge_mult := 0.45 if heavy_charging else 1.0
	var atk_mult: float = float(moveset.get("move_mult", 1.0)) if attack.is_busy() and attack.phase != AttackRunner.Phase.RECOVERY else 1.0
	_run(d, charge_mult * atk_mult)
	if heavy_charging:
		velocity.x = clampf(velocity.x, -MAX_RUN * 0.45, MAX_RUN * 0.45)
	_lunge()
	_gravity_step(d)
	_try_jump()
	# escalar parede (segurando cima encostado)
	if Game.has_ability("wall_climb") and not on_ground and input_y * g_dir < 0 and stamina > 0.0 and (_wall_at(facing) or wall_dir != 0) and not attack.is_busy():
		_set_state(State.CLIMB)
		return
	_common_actions(d)


## Avanço (lunge) de golpes no chão (finalizadores e pesados).
func _lunge() -> void:
	if not attack.is_busy() or attack.phase == AttackRunner.Phase.RECOVERY:
		return
	var lunge := float(attack.step.get("lunge", 0.0))
	if lunge == 0.0 or attack.kind in ["air", "down_air", "up_air", "dash"]:
		return
	if on_ground or attack.kind == "heavy":
		var want := attack._facing * lunge * (1.0 - attack.progress() * 0.5)
		if absf(want) > absf(velocity.x) or signf(want) != signf(velocity.x):
			velocity.x = want


## Ações que podem começar a partir do estado normal.
func _common_actions(d: float) -> void:
	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash()
		return
	if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0 and not attack.is_busy():
		_start_dodge()
		return
	if Input.is_action_just_pressed("parry"):
		_start_parry()
	if moveset.has("block"):
		blocking = Input.is_action_pressed("parry") and parry_t <= 0.0 and on_ground
	# ataque leve: não trava o corpo; pode encadear no fim do golpe anterior
	if attack_buffer_t > 0.0 and not heavy_charging and (not attack.is_busy() or attack.can_chain()):
		_start_light()
	# pesado: segurar carrega (arte da lâmina), soltar golpeia
	if Input.is_action_just_pressed("heavy") and not heavy_charging and not attack.is_busy():
		if not on_ground and input_y * g_dir > 0 and Game.has_ability("ground_pound"):
			_start_pound()
			return
		heavy_charging = true
		heavy_t = 0.0
	if heavy_charging:
		_tick_heavy_charge(d)
	if Input.is_action_just_pressed("spell_1"):
		_cast_slot(0)
	elif Input.is_action_just_pressed("spell_2"):
		_cast_slot(1)
	if Input.is_action_just_pressed("sigil"):
		_start_sigil()
		return
	if Input.is_action_just_pressed("interact") and on_ground and input_x == 0 and not attack.is_busy():
		_interact()
	_tick_heal_input(d)
	if Input.is_action_just_pressed("swap_weapon"):
		swap_weapon()


func _tick_heavy_charge(d: float) -> void:
	heavy_t += d
	var h: Dictionary = moveset.get("heavy", {})
	var need := float(h.get("charge", 0.4))
	if heavy_t >= need and heavy_t - d < need:
		FX.burst(body_center(), Color(2.4, 2.2, 1.6), 6, 50.0)
		Audio.play("draw_blade", 0.05, -6.0)
		rig.set_expression("angry", 0.4)
		if scarf:
			scarf.flash = 0.8
	if heavy_t > need and fmod(heavy_t, 0.16) < d:
		FX.burst(body_center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), Color(2.4, 2.0, 1.4), 1, 20.0)
	if not Input.is_action_pressed("heavy"):
		heavy_charging = false
		var charged := heavy_t >= need
		var mult := float(h.get("charged_mult", 1.5)) if charged else 1.0
		if input_x != 0.0:
			facing = int(input_x)
		attack.cancel()
		attack.start(h, "heavy", facing, mult)
		attack_dir = "side"
		rig.play("slash", true)
		if charged:
			FX.flash(0.4)
			FX.shake(0.15)


func _tick_heal_input(d: float) -> void:
	if Input.is_action_pressed("heal") and on_ground:
		heal_hold_t += d
		if heal_hold_t >= HEAL_HOLD and focus >= HEAL_COST and hp < max_hp() and not attack.is_busy():
			heal_t = 0.0
			_set_state(State.HEAL)
			Audio.play("spell", 0.05, -8.0, 0.7)
	else:
		if heal_hold_t > 0.0 and heal_hold_t < HEAL_HOLD:
			_use_potion()
		heal_hold_t = 0.0


func _can_dash() -> bool:
	return dash_cd <= 0.0 and (dashes > 0 or Settings.gameplay("infinite_dash"))


func _start_dash() -> void:
	var dir := Vector2(input_x, input_y)
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0)
	dash_dir = dir.normalized()
	if dash_dir.x != 0.0:
		facing = int(signf(dash_dir.x))
	# cor do dash GASTO (a do cachecol antes de gastar): anel, riscos e fita
	var dash_col := Color(2.6, 0.75, 0.85)
	if dashes >= 2:
		dash_col = Color(2.8, 1.0, 2.5)
	if not Settings.gameplay("infinite_dash"):
		dashes -= 1
	_update_scarf_color()
	dash_t = DASH_TIME
	dash_cd = DASH_COOLDOWN
	dash_refill_cd = DASH_REFILL_COOLDOWN
	dash_on_ground = on_ground
	_set_duck(false)
	heavy_charging = false
	velocity = dash_dir * DASH_SPEED
	var_jump_t = 0.0
	_after_t = 0.0
	_dash_through_hit.clear()
	_set_state(State.DASH)
	FX.hitstop(DASH_FREEZE)
	FX.shake(0.06)
	Audio.play("dash", 0.1, -4.0)
	Events.player_dash_changed.emit(dashes, max_dashes())
	buffs.trigger("dash")
	rig.bump(Vector2(1.35, 0.7) if absf(dash_dir.x) > absf(dash_dir.y) else Vector2(0.7, 1.35))
	if on_ground and dash_dir.y >= 0.0:
		FX.dust(global_position, Vector2(-facing, -0.3), 3)
	# efeitos do dash: anel achatado na direção, riscos de velocidade e a fita
	var perp := Vector2(absf(dash_dir.y), absf(dash_dir.x))
	FX.ring(body_center(), dash_col, 9.0, 0.18, Vector2(0.55, 0.55) + perp * 0.45)
	FX.speed_lines(body_center() + Vector2(0, 6), dash_dir, Color(dash_col.r * 0.8 + 0.4, dash_col.g * 0.8 + 0.4, dash_col.b * 0.8 + 0.4, 0.9), 5, 10.0)
	DashTrail.spawn(get_parent(), self, dash_col, func(): return is_instance_valid(self) and state == State.DASH)


func _st_dash(d: float) -> void:
	dash_t -= d
	velocity = dash_dir * DASH_SPEED
	_after_t -= d
	if _after_t <= 0.0:
		# fantasmas mais espaçados e leves: a fita colorida faz o rastro
		_after_t = 0.05
		_ghost(Color(0.9, 1.6, 2.4, 0.5) if dashes <= 0 else Color(2.2, 0.9, 1.0, 0.5), 0.16)
	# ataque em dash (corta tudo pelo caminho)
	if attack_buffer_t > 0.0 and not attack.is_busy() and moveset.has("dash"):
		attack_buffer_t = 0.0
		attack.start(moveset["dash"], "dash", facing)
		attack_dir = "side"
		_slash_fx(moveset["dash"], "dash")
	# super / hyper (pulo durante dash no chão) e wallbounce (pulo em dash para cima encostado)
	if jump_buffer_t > 0.0:
		var jmult := float(phys.get("jump", 1.0))
		if (on_ground or coyote_t > 0.0) and dash_on_ground and absf(dash_dir.x) > 0.1:
			var hyper := dash_dir.y * g_dir > 0.1
			_jump(JUMP_SPEED * jmult * (HYPER_Y_MULT if hyper else 1.0))
			velocity.x = signf(dash_dir.x) * SUPER_H * (HYPER_X_MULT if hyper else 1.0)
			_set_state(State.NORMAL)
			refill_dash()
			FX.shake(0.1)
			FX.dust(global_position, Vector2(-facing, -0.2), 5)
			return
		var wd := 1 if _wall_at(1, WALL_JUMP_CHECK) else (-1 if _wall_at(-1, WALL_JUMP_CHECK) else 0)
		if wd != 0 and Game.has_ability("wall_jump"):
			if dash_dir.y * g_dir < -0.5 and absf(dash_dir.x) < 0.3:
				# wallbounce (dash para cima + pulo encostado): sobe muito
				_jump(SUPER_WALL_JUMP_SPEED * jmult, "")
				var_jump_t = SUPER_WALL_JUMP_VAR
				velocity.x = -wd * SUPER_WALL_JUMP_H
				force_move_t = 0.2
			else:
				# chute de parede (dash + pulo encostado): sai longe com embalo
				_jump(JUMP_SPEED * WALL_KICK_JUMP * jmult, "")
				velocity.x = -wd * WALL_KICK_H
				force_move_t = 0.12
			force_move_x = -wd
			facing = -wd
			_set_state(State.NORMAL)
			refill_dash() # encostou na parede
			_wall_refill_ready = false
			add_chain()
			FX.shake(0.12)
			FX.ring(global_position + Vector2(wd * 4, -6), Color(2.4, 1.6, 1.2), 10.0)
			FX.dust(global_position + Vector2(wd * 4, -6), Vector2(-wd, -0.3), 5)
			Audio.play("wall_kick", 0.05, -4.0)
			rig.bump(Vector2(0.7, 1.35))
			return
	_dash_through_check()
	if dash_t <= 0.0:
		velocity = dash_dir * DASH_END_SPEED
		if dash_dir.y * g_dir < 0.0:
			velocity.y *= DASH_END_UP_MULT
		_set_state(State.NORMAL)
		buffs.trigger("dash_end")


func _dash_through_check() -> void:
	# relíquias "ao atravessar inimigos com dash"
	for a in get_tree().get_nodes_in_group("actors"):
		if a == self or a.team == team or a.dead:
			continue
		if a.body_center().distance_to(body_center()) < 10.0 and not _dash_through_hit.has(a):
			_dash_through_hit[a] = true
			buffs.trigger("dash_through", {"target": a})


func _st_climb(d: float) -> void:
	var wd := 0
	if _wall_at(facing):
		wd = facing
	elif _wall_at(-facing):
		wd = -facing
	if wd == 0 or on_ground or stamina <= 0.0 or not Game.has_ability("wall_climb"):
		if wd == 0 and stamina > 0.0 and input_y * g_dir < 0:
			# topo da parede: pulinho para subir na borda (climb hop)
			_set_vy(-CLIMB_HOP_Y)
			velocity.x = facing * CLIMB_HOP_X * 0.6
			force_move_x = facing
			force_move_t = 0.12
		_set_state(State.NORMAL)
		return
	if input_y == 0.0 and input_x != wd:
		# soltou: volta a deslizar
		_set_state(State.NORMAL)
		return
	facing = wd
	velocity.x = 0.0
	var climb := 0.0
	if input_y * g_dir < 0:
		climb = -CLIMB_UP
		stamina -= CLIMB_UP_COST * d
	elif input_y * g_dir > 0:
		climb = CLIMB_DOWN
	else:
		stamina -= CLIMB_STILL_COST * d
	_set_vy(move_toward(_vy(), climb, 900.0 * d))
	if stamina < 20.0:
		emote.show_emote("sweat", 0.4)
		if fmod(stamina, 4.0) < 1.0:
			rig.bump(Vector2(1.05, 0.95))
	if jump_buffer_t > 0.0:
		_try_jump()
		return
	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash()


# ---------------------------------------------------------------------------
# Ataques (Hollow Knight: lado / cima / baixo, sem travar o corpo)
# ---------------------------------------------------------------------------

func _start_light() -> void:
	attack_buffer_t = 0.0
	if moveset.is_empty():
		return
	var kind := "light"
	var step: Dictionary
	var up := input_y * g_dir < 0
	var down := input_y * g_dir > 0
	if down and not on_ground:
		kind = "down_air"
		attack_dir = "down"
		step = moveset["down_air"]
	elif up:
		kind = "up_air"
		attack_dir = "up"
		step = moveset["up_air"]
	elif not on_ground:
		kind = "air"
		attack_dir = "side"
		step = moveset["air"]
	else:
		attack_dir = "side"
		var chain: Array = moveset["light"]
		if combo_timer <= 0.0 or combo_index >= chain.size():
			combo_index = 0
		step = chain[combo_index]
		# ritmo: acertar o tempo do golpe anterior acumula Compasso
		if moveset.get("rhythm", false) and attack.is_busy():
			var beat := float(attack.step.get("beat", 0.07))
			if absf(attack.time_to_end()) <= beat * 1.6:
				rhythm_stacks = mini(rhythm_stacks + 1, 5)
				emote.show_emote("note", 0.4)
			else:
				rhythm_stacks = 0
		combo_index += 1
	if input_x != 0.0:
		facing = int(input_x)
	# deslizando na parede: o golpe sai para longe dela (Hollow Knight)
	if wall_dir != 0 and not on_ground and kind in ["air", "light"]:
		facing = -wall_dir
	attack.cancel()
	attack.start(step, kind, facing)
	combo_timer = COMBO_TIMEOUT
	_ducking_off()
	match attack_dir:
		"up": rig.play("slash_up", true)
		"down": rig.play("slash_down", true)
		_: rig.play("slash", true)


func _ducking_off() -> void:
	if ducking:
		_set_duck(false)


func _slash_fx(step: Dictionary, kind: String) -> void:
	var box: Array = step.get("box", [0, -12, 16, 12])
	var c := Color(1.9, 1.95, 2.3)
	if not moveset.get("weapon_status", {}).is_empty() or step.has("status"):
		c = Color(2.4, 0.9, 1.0)
	var arc: Array = step.get("arc", [150, 12])
	var radius := float(arc[1]) if arc.size() > 1 else 12.0
	var width := clampf(radius * 0.28, 2.0, 5.0)
	var center := body_center()
	if step.get("thrust", false):
		var dir := Vector2(facing, 0)
		var rot := 0.0
		if kind == "up_air":
			rot = -PI * 0.5 * facing
		elif kind == "down_air":
			rot = PI * 0.5 * facing
		FX.slash(center + dir.rotated(rot * facing) * 2.0, facing, 0.0, float(box[2]), c, rot, true, width)
	else:
		var rot := 0.0
		if kind == "up_air":
			rot = -PI * 0.5 * facing
		elif kind == "down_air":
			rot = PI * 0.5 * facing
		FX.slash(center, facing, float(arc[0]), radius, c, rot, false, width)
	var blade_dir := Vector2(1, 0)
	if kind == "up_air":
		blade_dir = Vector2(0.3, -1).normalized()
	elif kind == "down_air":
		blade_dir = Vector2(0.3, 1).normalized()
	rig.blade = {"len": clampf(radius * 0.5, 4.0, 10.0), "dir": blade_dir, "color": Color(0.92, 0.94, 1.0), "t": 0.08}
	Audio.play("swing_heavy" if step.get("dmg", 1.0) > 1.3 else "swing", 0.12, -5.0)


func _on_attack_activated(step: Dictionary, kind: String) -> void:
	if kind != "dash":
		_slash_fx(step, kind)
	if step.has("projectile"):
		_throw(step)
	if step.get("shockwave", false) and on_ground:
		FX.shake(0.25)
		var ring := NovaFX.new()
		ring.radius = 30
		ring.color = Color(2.0, 1.6, 1.0)
		ring.global_position = global_position
		get_parent().add_child(ring)
	if echo_charges > 0:
		echo_charges -= 1
		EchoStrike.spawn(self, step, kind, echo_mult)


func _throw(step: Dictionary) -> void:
	var p := Projectile.new()
	p.team = team
	p.owner_actor = self
	var info := build_attack_info(step, "heavy", attack.charge_mult, null)
	p.info = info
	p.velocity = aim_direction() * 220.0
	p.radius = 2.0
	p.color = Color(2.2, 2.2, 2.6)
	p.lifetime = 0.8
	p.light_enabled = false
	p.global_position = body_center() + Vector2(facing * 5, 0)
	get_parent().add_child(p)


## Monta o DamageInfo de um golpe (chamado pelo Hitbox ao acertar).
func build_attack_info(step: Dictionary, kind: String, charge: float, target: Node) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = float(moveset.get("damage", 10.0)) * float(step.get("dmg", 1.0)) * charge
	info.damage_type = moveset.get("damage_type", "slash")
	info.weapon_class = moveset.get("class", "")
	info.weapon_id = weapon_id
	info.source = self
	info.team = team
	info.is_heavy = kind == "heavy"
	info.is_dash_attack = kind == "dash"
	info.stagger = float(step.get("stagger", 1.0)) * charge
	info.pogo = step.get("pogo", false)
	var dir := Vector2(facing, 0)
	if kind == "down_air":
		dir = Vector2(0, g_dir)
	elif kind == "up_air":
		dir = Vector2(0, -g_dir)
	info.direction = dir
	info.knockback = dir * float(step.get("kb", 80.0)) + Vector2(0, -30.0 * g_dir if kind != "down_air" else 0.0)
	var st: Dictionary = moveset.get("weapon_status", {}).duplicate()
	for s in step.get("status", {}).keys():
		st[s] = int(st.get(s, 0)) + int(step["status"][s])
	info.status = st
	info.is_crit = CombatMath.roll_crit(rng, stats, buffs.consume_crit())
	# multiplicadores do jogador: combo, ritmo, costas, ponto fraco da classe, buffs
	var mult := 1.0 + minf(combo_count, 20) * 0.015
	if moveset.get("rhythm", false):
		mult *= 1.0 + rhythm_stacks * 0.06
	if target and is_instance_valid(target) and target is Actor:
		var behind: bool = signf(target.global_position.x - global_position.x) == float(target.facing)
		if behind and moveset.has("backstab_bonus"):
			mult *= 1.0 + float(moveset["backstab_bonus"])
			info.backstab = true
		info.amount *= buffs.damage_mult(info, target)
	if moveset.has("weak_point_bonus"):
		info.tags.append("weak_bonus")
	# golpe em alta velocidade (super, rasante, quique): mais forte — vale manter o embalo
	if velocity.length() > MAX_RUN * 1.5:
		mult *= 1.25
		info.tags.append("speed")
	info.amount *= mult
	if slowmo_bonus():
		info.amount *= 1.15
	return info


func slowmo_bonus() -> bool:
	return FX.slowmo_active


func _on_attack_landed(target: Node, info: DamageInfo, result: int) -> void:
	if result == DamageInfo.Result.IGNORED or result == DamageInfo.Result.INVULNERABLE:
		return
	if target is ImpulseOrb:
		return
	# recuo (Hollow Knight): bater empurra o herói um pouco para trás
	_recoil(info)
	if not (target is Actor):
		FX.hitstop(0.03)
		if info.pogo:
			_pogo()
		return
	if result == DamageInfo.Result.BLOCKED or result == DamageInfo.Result.PARRIED:
		FX.hitstop(0.05)
		FX.hit_spark(info.hit_position, info.direction, Color(2.4, 2.4, 2.0), true)
		Audio.play("hit_metal")
		recoil_x = -facing * RECOIL_X * 1.3
		recoil_t = RECOIL_TIME * 1.5
		return
	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	Events.combo_changed.emit(combo_count)
	gain_focus(float(moveset.get("focus_gain", 5)) * (1.0 + stats.get_stat("focus_gain")))
	var ctx := {"target": target, "info": info, "combo": combo_count}
	buffs.trigger("hit", ctx)
	if info.is_crit:
		buffs.trigger("crit", ctx)
	buffs.trigger("combo", ctx)
	if info.pogo:
		_pogo()
	elif not on_ground and air_stalls < AIR_STALL_MAX and state != State.DASH:
		# combo aéreo: cada acerto segura a queda um instante
		air_stalls += 1
		if _vy() > -AIR_STALL:
			_set_vy(-AIR_STALL)
			var_jump_t = 0.0
	if info.is_dash_attack:
		dash_t = maxf(dash_t, 0.04)
	if info.tags.has("speed"):
		FX.hit_spark(info.hit_position, info.direction, Color(2.8, 2.4, 1.4), true)
	Audio.play("hit_heavy" if info.is_heavy or info.is_crit or info.tags.has("speed") else "hit", 0.1, -3.0)
	if result == DamageInfo.Result.KILLED:
		Game.profile["kills"] = int(Game.profile.get("kills", 0)) + 1
		refill_dash()
		if not on_ground:
			add_chain()
			if not info.pogo and state != State.DASH and _vy() > -KILL_POP:
				_set_vy(-KILL_POP) # quique do abate: segue no ar
				var_jump_t = 0.0
		buffs.trigger("kill", ctx)
		if rng.randf() < 0.35:
			rig.set_expression("happy", 0.5)


## Cadeia aérea: orbe, pogo, abate, rebate, salto de parede e cristal sem
## tocar o chão. Ao pousar, 3+ dão brasas e foco (mais para cadeias longas).
func add_chain() -> void:
	if on_ground:
		return
	air_chain += 1
	best_chain = maxi(best_chain, air_chain)
	Events.air_chain_changed.emit(air_chain)
	if air_chain >= CHAIN_MIN:
		# nota sobe a cada elo (escala pentatônica)
		var steps := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
		var st_i: int = steps[mini(air_chain - CHAIN_MIN, steps.size() - 1)]
		Audio.play("chain", 0.0, -8.0, pow(2.0, st_i / 12.0))


func end_chain(reward: bool) -> void:
	if air_chain <= 0:
		return
	var n := air_chain
	air_chain = 0
	Events.air_chain_changed.emit(0)
	if n < CHAIN_MIN:
		return
	if not reward:
		FX.text(body_center() + Vector2(0, -12), "cadeia perdida", Color(0.8, 0.7, 0.9))
		return
	var gain := n + (4 if n >= 6 else 0) + (10 if n >= 10 else 0)
	if level and level.has_method("spawn_currency"):
		level.spawn_currency(gain, body_center())
	gain_focus(n * 3.0)
	FX.text(body_center() + Vector2(0, -14), "CADEIA x%d!" % n, Color(2.4, 2.0, 0.9) if n >= 6 else Color(1.9, 1.9, 2.2))
	FX.burst(body_center(), Color(2.2, 1.8, 0.8), mini(4 + n, 14), 90.0)
	rig.flame_pop(0.4 + minf(n, 10) * 0.06)
	Audio.play("chain_end", 0.0, -6.0, 1.0 + minf(n, 12) * 0.02)
	if n >= 6:
		emote.show_emote("spark", 0.8, true)
		rig.set_expression("happy", 0.8)


## Rebater uma bala (Katana Zero): recarrega o dash e, no ar, segura a queda
## (ou quica, se foi o golpe para baixo) — dá para "pisar" em balas.
func _on_reflect(_p: Node) -> void:
	refill_dash()
	add_chain()
	gain_focus(4.0)
	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	Events.combo_changed.emit(combo_count)
	if on_ground:
		return
	if attack.kind == "down_air":
		_pogo()
	elif _vy() > -AIR_STALL * 1.5:
		_set_vy(-AIR_STALL * 1.5)
		var_jump_t = 0.0
	if rng.randf() < 0.4:
		emote.show_emote("spark", 0.5, true)


func _recoil(info: DamageInfo) -> void:
	if info.is_dash_attack or state == State.DASH:
		return
	# correndo rápido na direção do golpe: atravessa sem perder o embalo
	if absf(velocity.x) > MAX_RUN * 1.2 and signf(velocity.x) == signf(info.direction.x):
		return
	if info.direction.y * g_dir < -0.5:
		# golpe para cima: leve empurrão para baixo no ar
		if not on_ground and _vy() < RECOIL_UP:
			_set_vy(RECOIL_UP)
			var_jump_t = 0.0
	elif absf(info.direction.x) > 0.5:
		recoil_x = -signf(info.direction.x) * RECOIL_X * (1.2 if info.is_heavy else 1.0)
		recoil_t = RECOIL_TIME


func _pogo() -> void:
	_set_vy(-POGO_SPEED * float(phys.get("jump", 1.0)))
	var_jump_t = 0.12
	auto_jump_t = 0.1
	var_jump_speed = POGO_SPEED * float(phys.get("jump", 1.0))
	refill_dash()
	add_chain()
	Audio.play("pogo", 0.08, -6.0)
	buffs.trigger("pogo")
	FX.burst(global_position + Vector2(0, 3), Color(2.2, 2.2, 2.6), 4, 60.0, Vector2.UP, 60.0)
	rig.bump(Vector2(0.8, 1.25))
	if attack.kind == "down_air":
		attack.cancel()


func _start_pound() -> void:
	_set_state(State.POUND)
	velocity = Vector2(0, POUND_SPEED * g_dir)
	var_jump_t = 0.0
	invuln_time = maxf(invuln_time, 0.2)
	FX.hitstop(0.05)
	rig.bump(Vector2(0.7, 1.3))


func _st_pound(_d: float) -> void:
	velocity = Vector2(0, POUND_SPEED * g_dir)
	if on_ground:
		_pound_impact()


func _pound_impact() -> void:
	_set_state(State.NORMAL)
	FX.shake(0.4)
	Audio.play("break")
	rig.bump(Vector2(1.5, 0.6))
	var ring := NovaFX.new()
	ring.radius = 30
	ring.color = Color(2.0, 1.6, 1.1)
	ring.global_position = global_position
	get_parent().add_child(ring)
	FX.dust(global_position, Vector2.UP, 8)
	for a in get_tree().get_nodes_in_group("actors"):
		if a.team != team and not a.dead and a.global_position.distance_to(global_position) < 30.0:
			var info := DamageInfo.new()
			info.amount = float(moveset.get("damage", 10.0)) * 1.4
			info.damage_type = "blunt"
			info.team = team
			info.source = self
			info.knockback = Vector2(signf(a.global_position.x - global_position.x) * 100.0, -120.0)
			info.stagger = 4.0
			for hb in a.get_children():
				if hb is Hurtbox:
					hb.receive(info)
					break
	for b in get_tree().get_nodes_in_group("cracked_floor"):
		if b.global_position.distance_to(global_position) < 20.0:
			b.shatter()


# ---------------------------------------------------------------------------
# Defesa
# ---------------------------------------------------------------------------

func _start_parry() -> void:
	if parry_cd > 0.0:
		return
	parry_t = PARRY_WINDOW + float(moveset.get("parry_bonus", 0.0))
	parry_cd = PARRY_COOLDOWN
	rig.play("cast", true)
	_cast_pose_t = 0.12
	FX.burst(body_center() + Vector2(facing * 6, 0), Color(2.2, 2.2, 2.8), 3, 40.0)
	# área curta que rebate projéteis
	var hb := attack.hitbox
	if not attack.is_busy():
		hb.set_box([-2, -14, 14, 14], facing)
		hb.pogo = false
		hb.info_factory = func(_t): return null
		hb.activate()
		get_tree().create_timer(parry_t, false, true).timeout.connect(func():
			if not attack.is_active():
				hb.deactivate()
			hb.info_factory = attack._make_info)


func _start_dodge() -> void:
	dodge_t = DODGE_TIME
	dodge_cd = DODGE_COOLDOWN
	invuln_time = maxf(invuln_time, DODGE_IFRAMES)
	var dir := input_x if input_x != 0.0 else float(facing)
	facing = int(dir)
	velocity.x = dir * DODGE_SPEED * (1.0 if on_ground else 0.75)
	_set_state(State.DODGE)
	Audio.play("dash", 0.15, -9.0)
	rig.bump(Vector2(1.25, 0.8))


func _st_dodge(d: float) -> void:
	dodge_t -= d
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * d)
	_gravity_step(d)
	if fmod(dodge_t, 0.05) < d:
		_ghost(Color(1.0, 1.0, 1.4, 0.5), 0.16)
	if dodge_t <= 0.0:
		_set_state(State.NORMAL)


func _before_hit(info: DamageInfo) -> int:
	if Settings.gameplay("invincible") and not info.is_hazard:
		return DamageInfo.Result.INVULNERABLE
	# esquiva perfeita: golpe chegou no começo da esquiva
	if state == State.DODGE and DODGE_TIME - dodge_t <= PERFECT_DODGE_WINDOW and not info.is_hazard:
		FX.slowmo(0.3, 0.5 * (1.0 + stats.get_stat("perfect_dodge_time")))
		emote.show_emote("sweat", 0.8)
		rig.set_expression("wide", 0.5)
		gain_focus(12.0)
		buffs.trigger("perfect_dodge")
		Events.perfect_dodge.emit(self)
		return DamageInfo.Result.DODGED
	# aparar
	if parry_t > 0.0 and info.parryable and not info.is_hazard:
		var elapsed := PARRY_WINDOW + float(moveset.get("parry_bonus", 0.0)) - parry_t
		var perfect := elapsed <= PERFECT_PARRY + float(moveset.get("parry_bonus", 0.0))
		parry_t = 0.0
		parry_cd = 0.0
		var attacker: Node = info.source
		if attacker and is_instance_valid(attacker) and attacker.has_method("on_parried"):
			attacker.on_parried(self, perfect)
		FX.hitstop(0.12 if perfect else 0.06)
		FX.shake(0.25 if perfect else 0.12)
		FX.hit_spark(body_center() + Vector2(facing * 6, 0), Vector2(facing, 0), Color(3.0, 2.8, 2.0), true)
		Audio.play("parry_perfect" if perfect else "parry")
		gain_focus(22.0 if perfect else 10.0)
		recoil_x = -facing * RECOIL_X
		recoil_t = RECOIL_TIME
		if perfect:
			FX.slowmo(0.35, 0.35)
			FX.white_flash(0.25)
			emote.show_emote("!", 0.6, true)
			rig.set_expression("angry", 0.6)
			refill_dash()
			buffs.trigger("perfect_parry")
		buffs.trigger("parry")
		Events.parry.emit(self, attacker, perfect)
		return DamageInfo.Result.PERFECT_PARRY if perfect else DamageInfo.Result.PARRIED
	# bloqueio com escudo (frontal)
	if blocking and not info.unblockable and not info.is_hazard:
		var from_front := signf(info.direction.x) != float(facing) or info.direction.x == 0.0
		if from_front:
			info.amount *= 1.0 - float(moveset.get("block", 0.8))
			Audio.play("block")
			FX.hit_spark(body_center() + Vector2(facing * 5, 0), Vector2(facing, 0), Color(2.0, 2.0, 2.4))
			recoil_x = -facing * 90.0
			recoil_t = RECOIL_TIME
			if info.amount < 1.0:
				return DamageInfo.Result.BLOCKED
	return -1


func _modify_incoming(info: DamageInfo, amount: float) -> float:
	if has_rule("one_hit"):
		return max_hp() * 10.0
	return amount


func _on_damaged(info: DamageInfo, amount: float) -> void:
	# dano no herói (Hollow Knight): congela, treme, pisca e empurra
	FX.hitstop(HURT_FREEZE)
	FX.shake(0.35)
	FX.white_flash(0.15)
	FX.hit_spark(body_center(), info.direction, Color(2.6, 0.6, 0.6), true)
	FX.flash(0.6)
	Audio.play("hurt")
	combo_count = 0
	rhythm_stacks = 0
	Events.combo_changed.emit(0)
	Events.player_health_changed.emit(hp, max_hp())
	buffs.trigger("hurt", {"info": info})
	var now := Time.get_ticks_msec() / 1000.0
	_recent_hits.append(now)
	_recent_hits = _recent_hits.filter(func(t): return now - t < 6.0)
	if dead:
		return
	attack.cancel()
	heavy_charging = false
	invuln_time = HURT_IFRAMES
	_set_duck(false)
	rig.set_expression("closed", 0.35)
	rig.flame_blow(info.direction.x)
	if _recent_hits.size() >= 3:
		emote.show_emote("anger", 1.0)
		_recent_hits.clear()
	elif hp / maxf(max_hp(), 1.0) < 0.3:
		emote.show_emote("sweat", 1.2)
	end_chain(false)
	if info.is_hazard:
		_hazard_respawn()
		return
	hurt_t = HURT_TIME
	var kb_dir := signf(info.direction.x) if info.direction.x != 0.0 else -float(facing)
	velocity = Vector2(kb_dir * HURT_KNOCK_X, -HURT_KNOCK_Y * g_dir)
	facing = -int(kb_dir) if kb_dir != 0.0 else facing
	_set_state(State.HURT)


func _apply_knockback(_info: DamageInfo) -> void:
	pass


func _st_hurt(d: float) -> void:
	hurt_t -= d
	_gravity_step(d)
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * d)
	if hurt_t <= 0.0:
		_set_state(State.NORMAL)


func _hazard_respawn() -> void:
	end_chain(false)
	Audio.play("respawn", 0.05, -8.0)
	_set_state(State.RESPAWN)
	velocity = Vector2.ZERO
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	var tw := create_tween()
	_fx_tween = tw
	tw.tween_property(rig, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		rig.lit = 0.0
		var back := hazard_spawn_override if hazard_spawn_override != Vector2.ZERO else last_safe_pos
		global_position = back.round()
		_prev_pos = global_position
		_rem = Vector2.ZERO
		reset_physics_interpolation()
		refill_dash()
		if scarf:
			scarf.reset_to(scarf_anchor()))
	tw.tween_callback(rig.relight)
	tw.tween_property(rig, "modulate:a", 1.0, 0.12)
	tw.tween_callback(func():
		_set_state(State.NORMAL)
		emote.show_emote("dizzy", 0.8))


func _die(info: DamageInfo) -> void:
	# alguém querido pode te salvar
	var savior := SocialSystem.rescue_candidate(Game.social, Game.profile.get("region", ""))
	if savior != "" and not Game.social.is_empty():
		var npc: Dictionary = Game.social["npcs"][savior]
		npc["rescues"] = int(npc["rescues"]) + 1
		hp = max_hp() * 0.35
		invuln_time = 2.0
		FX.slowmo(0.2, 0.8)
		FX.white_flash(0.4)
		emote.show_emote("heart", 1.5, true)
		Events.toast.emit("%s (%s) chegou a tempo e te salvou." % [npc["name"], npc["title"]])
		Events.player_health_changed.emit(hp, max_hp())
		return
	super._die(info)


func _on_death(_info: DamageInfo) -> void:
	_set_state(State.DEAD)
	Game.profile["deaths"] = int(Game.profile.get("deaths", 0)) + 1
	FX.slowmo(0.25, 1.0)
	FX.shake(0.5)
	Audio.play("death")
	rig.set_expression("dead")
	rig.play("dead")
	rig.extinguish()
	emote.show_emote("skull", 1.5, true)
	FX.burst(body_center(), Color(0.95, 0.93, 0.9), 12, 90.0)
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween()
	_fx_tween.tween_interval(0.35)
	_fx_tween.tween_method(set_dissolve, 0.0, 1.0, 0.4)
	Events.player_died.emit(self)


func revive(at: Vector2) -> void:
	# o tween da morte (dissolver) não pode continuar depois de renascer
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = null
	rig.modulate.a = 1.0
	rig.visible = true
	dead = false
	hp = max_hp()
	global_position = at.round()
	_prev_pos = global_position
	_rem = Vector2.ZERO
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	set_dissolve(0.0)
	status.clear()
	invuln_time = 1.0
	refill_dash()
	rig.set_expression("normal")
	rig.play("idle", true)
	rig.relight()
	FX.burst(rig.flame_tip_global(), Color(2.6, 1.6, 0.5), 6, 40.0, Vector2.UP, 50.0, 0.35)
	_set_state(State.NORMAL)
	if scarf:
		scarf.reset_to(scarf_anchor())
	Events.player_health_changed.emit(hp, max_hp())


# ---------------------------------------------------------------------------
# Cura (foco, estilo Hollow Knight) e descanso
# ---------------------------------------------------------------------------

func _st_heal(d: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, RUN_ACCEL * d)
	_gravity_step(d)
	heal_t += d
	if fmod(heal_t, 0.12) < d:
		SchoolFX.trail(get_parent(), "heal", body_center() + Vector2(randf_range(-6, 6), 2), Vector2(0, 30), Color(1.4, 2.6, 1.6))
	if not Input.is_action_pressed("heal") or not on_ground or focus < HEAL_COST:
		heal_hold_t = 0.0
		_set_state(State.NORMAL)
		return
	if heal_t >= HEAL_TIME:
		heal_t = 0.0
		gain_focus(-HEAL_COST)
		heal(HEAL_AMOUNT)
		Events.player_health_changed.emit(hp, max_hp())
		FX.burst(body_center(), Color(2.2, 2.4, 2.8), 6, 70.0)
		SchoolFX.impact(get_parent(), "heal", body_center(), Vector2.UP, Color(1.4, 2.8, 1.6))
		rig.bump(Vector2(0.85, 1.2))
		rig.set_expression("happy", 0.5)
		rig.flame_pop(0.8)
		Audio.play("pickup", 0.05, -6.0, 1.2)
		if hp >= max_hp() or focus < HEAL_COST:
			heal_hold_t = 0.0
			_set_state(State.NORMAL)


## Sentar no banco de descanso (checkpoint).
func rest() -> void:
	_set_state(State.REST)
	velocity = Vector2.ZERO
	rig.play("sit")
	rig.set_expression("closed", 1.0)
	rig.relight()
	rig.flame_pop(0.6)


func _st_rest(d: float) -> void:
	_gravity_step(d)
	velocity.x = 0.0
	if input_x != 0.0 or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack"):
		jump_buffer_t = 0.0
		_set_state(State.NORMAL)


# ---------------------------------------------------------------------------
# Magias / sigilos / itens
# ---------------------------------------------------------------------------

func aim_direction() -> Vector2:
	if _using_mouse and PixelView.current:
		var to := PixelView.current.mouse_world() - body_center()
		if to.length() > 3.0:
			return to.normalized()
	var v := Vector2(input_x, input_y)
	if v == Vector2.ZERO:
		v = Vector2(facing, 0)
	return v.normalized()


func aim_target() -> Vector2:
	if _using_mouse and PixelView.current:
		return PixelView.current.mouse_world()
	return body_center() + aim_direction() * 55.0


func _cast_slot(i: int) -> void:
	var slots: Array = Game.profile.get("spell_slots", [])
	if i >= slots.size():
		return
	cast_spell(slots[i], 1.0)


func cast_spell(spell_id: String, power: float) -> bool:
	if has_rule("no_spells"):
		emote.show_emote("?", 0.8)
		return false
	var lvl := Inventory.spell_level(Game.profile, spell_id)
	var cost := caster.cost_of(spell_id, lvl)
	if focus < cost:
		emote.show_emote("...", 0.6)
		Audio.play("ui_error", 0.0, -8.0)
		return false
	if not caster.is_ready(spell_id):
		return false
	if caster.cast(spell_id, lvl, aim_direction(), aim_target(), power):
		_spell_refund = {"id": spell_id, "cost": cost}
		gain_focus(-cost)
		buffs.trigger("spell_cast", {"spell": spell_id})
		rig.play("cast", true)
		_cast_pose_t = 0.18
		rig.bump(Vector2(1.15, 0.9))
		return true
	return false


func refund_last_spell() -> void:
	if _spell_refund.has("cost"):
		gain_focus(float(_spell_refund["cost"]))
		emote.show_emote("spark", 0.6)


func _start_sigil() -> void:
	if Game.profile.get("sigils", {}).is_empty():
		return
	sigil_points = PackedVector2Array()
	_set_state(State.SIGIL)
	rig.set_expression("closed", 0.2)
	if Settings.gameplay("sigil_slowmo"):
		FX.slowmo(0.2, 3.0)


func _screen_mouse() -> Vector2:
	return get_tree().root.get_mouse_position()


func _st_sigil(d: float, _raw: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, RUN_ACCEL * d)
	_gravity_step(d)
	var p := _screen_mouse()
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.4:
		var last := sigil_points[-1] if not sigil_points.is_empty() else Vector2(160, 90)
		p = last + stick * 3.0
	if sigil_points.is_empty() or sigil_points[-1].distance_to(p) > 1.0:
		sigil_points.append(p)
	if not Input.is_action_pressed("sigil"):
		_finish_sigil()


func _finish_sigil() -> void:
	FX.clear_time_effects()
	_set_state(State.NORMAL)
	var res := SigilRecognizer.recognize(sigil_points)
	sigil_points = PackedVector2Array()
	if res["name"] == "":
		emote.show_emote("?", 0.8)
		FX.text(body_center() + Vector2(0, -14), "%d%%" % int(res["accuracy"] * 100), Color(1.0, 0.6, 0.6))
		return
	for sid in Game.profile.get("sigils", {}).keys():
		if DB.spell(sid).get("sigil", "") == res["name"]:
			var power := SigilRecognizer.power_from_accuracy(res["accuracy"])
			if cast_spell(sid, power):
				FX.text(body_center() + Vector2(0, -16), "%s %d%%" % [DB.display_name(sid), int(res["accuracy"] * 100)], Color(1.4, 1.2, 2.0))
			return
	emote.show_emote("?", 0.8)


func start_echo(count: int, mult: float, duration: float) -> void:
	echo_charges = count
	echo_mult = mult
	echo_time = duration
	FX.burst(body_center(), Color(0.6, 2.4, 2.2), 10, 70.0)


func _record_history(d: float) -> void:
	_history_t -= d
	if _history_t <= 0.0:
		_history_t = 0.05
		_history.push_back([global_position, hp])
		if _history.size() > 80:
			_history.pop_front()


func rewind(duration: float, heal_ratio: float) -> void:
	var steps := clampi(int(duration / 0.05), 1, _history.size())
	if _history.is_empty():
		return
	var idx := maxi(_history.size() - steps, 0)
	var entry: Array = _history[idx]
	for i in range(idx, _history.size(), 4):
		var ghost := AfterImage.from_sprite(rig, Color(1.4, 2.2, 1.3, 0.6), 0.45)
		if ghost:
			ghost.global_position = _history[i][0]
			get_parent().add_child(ghost)
	global_position = entry[0]
	_prev_pos = global_position
	_rem = Vector2.ZERO
	reset_physics_interpolation()
	var lost := float(entry[1]) - hp
	if lost > 0.0:
		heal(lost * heal_ratio)
	_history.clear()
	FX.white_flash(0.25)


func _use_potion() -> void:
	if hp >= max_hp():
		return
	if Inventory.use_item(Game.profile, "pocao_vida"):
		heal(float(DB.items["pocao_vida"].get("heal", 30)))
		Events.player_health_changed.emit(hp, max_hp())
		Audio.play("pickup")
		rig.set_expression("happy", 0.6)


func _interact() -> void:
	var best: Node = null
	var best_d := INF
	for a in interact_area.get_overlapping_areas():
		if a.has_method("interact") and (not a.has_method("can_interact") or a.can_interact()):
			var d: float = a.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = a
	if best:
		best.interact(self)


func nearest_interactable() -> Node:
	for a in interact_area.get_overlapping_areas():
		if a.has_method("interact"):
			return a
	return null


func _ghost(tint: Color, life: float = 0.22) -> void:
	var ai := AfterImage.from_sprite(rig, tint, life)
	if ai:
		get_parent().add_child(ai)


# ---------------------------------------------------------------------------
# Pós-movimento: chão, parede, pouso, ponto seguro
# ---------------------------------------------------------------------------

func _after_move(d: float) -> void:
	on_ground = _collides(Vector2(0, g_dir)) and _vy() >= 0.0
	if on_ground:
		coyote_t = COYOTE
		stamina = CLIMB_STAMINA
		air_stalls = 0
		air_jumps = max_air_jumps()
		if dash_refill_cd <= 0.0 and state != State.DASH and dashes < max_dashes():
			refill_dash()
		if not was_on_floor:
			_on_land()
		# passinhos correndo
		if absf(velocity.x) > 40.0 and state == State.NORMAL:
			_step_t -= d * absf(velocity.x) / MAX_RUN
			if _step_t <= 0.0:
				_step_t = 0.2
				Audio.play("step", 0.2, -12.0)
		_safe_t += d
		if _safe_t > 0.15 and velocity.length() < 200.0 and not _near_hazard():
			last_safe_pos = global_position
	else:
		_safe_t = 0.0
		if was_on_floor:
			_fall_start_y = global_position.y
	was_on_floor = on_ground
	# parede recarrega o dash (e o pulo duplo) — uma vez por toque: é preciso
	# sair da parede (ou pousar) para recarregar de novo nela
	if on_ground:
		_wall_refill_ready = true
	else:
		var touch := 1 if _wall_at(1) else (-1 if _wall_at(-1) else 0)
		if touch == 0:
			_wall_refill_ready = true
		elif _wall_refill_ready and state != State.DASH and dash_refill_cd <= 0.0 and state != State.RESPAWN:
			_wall_refill_ready = false
			if dashes < max_dashes() or air_jumps < max_air_jumps():
				refill_dash()
				FX.hit_spark(global_position + Vector2(touch * 4, -6), Vector2(-touch, 0), Color(2.2, 1.2, 1.4), false)
				Audio.play("wall_refill", 0.05, -8.0)
	# parede: encostado E segurando na direção dela
	wall_dir = 0
	if not on_ground:
		if input_x > 0 and _wall_at(1):
			wall_dir = 1
		elif input_x < 0 and _wall_at(-1):
			wall_dir = -1


func _on_land() -> void:
	land_grace_t = LAND_GRACE
	bonus_jumps = 0
	end_chain(true)
	var impact := clampf(_land_speed / MAX_FALL, 0.0, 1.5)
	rig.bump(Vector2(1.0 + 0.35 * impact, 1.0 - 0.3 * impact))
	if impact > 0.4:
		FX.dust(global_position, Vector2.UP, 2 + int(impact * 3.0))
		Audio.play("land", 0.1, -12.0)
	if state == State.POUND:
		_pound_impact()
	if global_position.y - _fall_start_y > 100.0:
		rig.set_expression("wide", 0.4)
	_land_speed = 0.0


func _near_hazard() -> bool:
	# não marca como "seguro" um chão colado em espinhos
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 14)
	q.shape = r
	q.transform = Transform2D(0.0, global_position + Vector2(0, -5))
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Layers.HITBOX
	for hit in space.intersect_shape(q, 4):
		if hit["collider"] is Hazard:
			return true
	return false


# ---------------------------------------------------------------------------
# Animação e expressão
# ---------------------------------------------------------------------------

func _animate(d: float) -> void:
	if rig == null:
		return
	rig.facing = facing
	var a := rig.anim
	match state:
		State.DEAD:
			a = "dead"
		State.HURT:
			a = "hurt"
		State.DASH, State.DODGE, State.POUND:
			a = "dash" if state != State.POUND else "slash_down"
		State.CLIMB:
			a = "climb"
			if _vy() == 0.0:
				rig.anim_t = 0.0
		State.HEAL:
			a = "focus"
		State.SIGIL:
			a = "cast"
		State.REST:
			a = "sit"
		_:
			if _cast_pose_t > 0.0:
				a = "cast"
			elif attack.is_busy() and attack.phase != AttackRunner.Phase.RECOVERY or (attack.is_busy() and attack.t < 0.05):
				match attack_dir:
					"up": a = "slash_up"
					"down": a = "slash_down"
					_: a = "slash"
			elif heavy_charging:
				a = "duck" if on_ground else "fall"
			elif wall_dir != 0 and not on_ground:
				a = "wall"
				rig.facing = -wall_dir
			elif not on_ground:
				a = "jump" if _vy() < -20.0 else "fall"
			elif ducking:
				a = "duck"
			elif absf(velocity.x) > 12.0 and (input_x != 0.0 or absf(velocity.x) > 60.0):
				a = "run"
			else:
				a = "idle"
	rig.play(a)
	rig.motion = velocity
	rig.vitality = hp / maxf(max_hp(), 1.0)
	if scarf:
		rig.scarf_color = scarf.color.lerp(Color(2.0, 2.0, 2.0), scarf.flash)
	if light:
		# a luz do herói É a chama: acompanha a posição e tremula junto
		light.position = rig.anchor("flame") + Vector2(0, -2)
		light.energy = LIGHT_ENERGY * rig.lit * (0.85 + 0.15 * sin(Time.get_ticks_msec() / 60.0)) * (0.7 + 0.3 * rig.vitality)
	# expressão base
	var ratio := hp / maxf(max_hp(), 1.0)
	var base := "normal"
	if state == State.DEAD:
		base = "dead"
	elif state == State.HEAL or heavy_charging or state == State.REST:
		base = "closed"
	elif ratio < 0.3:
		base = "tired"
	elif combo_count >= 3 or _enemies_near():
		base = "angry"
	elif on_ground and input_y * g_dir < 0 and absf(velocity.x) < 5.0:
		base = "look_up"
	elif on_ground and ducking:
		base = "look_down"
	elif not on_ground and _vy() > MAX_FALL * 0.95:
		base = "wide"
	rig.set_expression(base)
	# ficar parado: "..." e depois cochilo
	if state == State.NORMAL and on_ground and absf(velocity.x) < 1.0 and not attack.is_busy():
		_idle_t += d
		if _idle_t > 6.0 and _idle_t - d <= 6.0:
			emote.show_emote("...", 1.4)
		if _idle_t > 12.0:
			rig.play("sit")
			rig.set_expression("closed")
			if emote.kind != "zzz":
				emote.show_emote("zzz", 999.0)
	elif emote.kind == "zzz":
		emote.clear()
	# piscar durante a invencibilidade
	if invuln_time > 0.25 and state != State.DASH and state != State.DODGE and state != State.DEAD:
		rig.visible = fmod(Time.get_ticks_msec() / 70.0, 2.0) > 0.7
	else:
		rig.visible = true


func _enemies_near() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and e.global_position.distance_to(global_position) < 70.0:
			return true
	return false


func _update_visuals(delta: float) -> void:
	_flash = maxf(_flash - delta * 9.0, 0.0)
	if _mat:
		_mat.set_shader_parameter("flash", _flash)
		var tint := status.tint()
		_mat.set_shader_parameter("status_color", tint)
		_mat.set_shader_parameter("status_strength", 1.0 if tint.a > 0.0 else 0.0)


func _on_settings_changed() -> void:
	if light:
		light.shadow_enabled = bool(Settings.video("shadows"))
		light.visible = bool(Settings.video("dynamic_lights"))
