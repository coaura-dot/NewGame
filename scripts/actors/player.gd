class_name Player
extends Actor
## Jogador. Movimento no estilo Celeste (aceleração, inércia, coyote time,
## buffer de pulo, pulo variável, correção de quina, dash em 8 direções com
## super/hyper, deslizar/saltar/escalar parede) + combate no estilo Katana
## Zero (combos, pesado carregado, ataque em dash, pogo, aparar que rebate
## projéteis, esquiva com câmera lenta, ritmo, magias e sigilos desenhados).
##
## Tudo que é "número de feel" está nas constantes abaixo — ajuste à vontade.

signal focus_changed(current: float, maximum: float)
signal state_changed(state: int)

enum State { NORMAL, DASH, CLIMB, ATTACK, DODGE, HURT, DEAD, SIGIL, POUND, RESPAWN }

# --- Corrida / ar ---
const MAX_RUN := 90.0
const RUN_ACCEL := 1000.0
const RUN_DECEL := 1000.0
const RUN_REDUCE := 400.0 ## acima da velocidade máxima (preserva o embalo)
const AIR_MULT := 0.65
# --- Gravidade / pulo ---
const GRAVITY := 900.0
const MAX_FALL := 160.0
const FAST_FALL := 240.0
const HALF_GRAV_THRESHOLD := 40.0
const JUMP_SPEED := 115.0
const JUMP_H_BOOST := 40.0
const VAR_JUMP_TIME := 0.2
const DOUBLE_JUMP_SPEED := 105.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
# --- Parede ---
const WALL_SLIDE_MAX := 40.0
const WALL_JUMP_H := 130.0
const WALL_JUMP_FORCE_TIME := 0.16
const WALL_COYOTE := 0.08
const CLIMB_SPEED := 45.0
const CLIMB_STAMINA := 1.4
# --- Dash ---
const DASH_SPEED := 240.0
const DASH_TIME := 0.15
const DASH_END_SPEED := 160.0
const DASH_COOLDOWN := 0.16
const DASH_IFRAMES := 0.06
const SUPER_H := 260.0
const HYPER_H := 325.0
# --- Defesa ---
const DODGE_SPEED := 150.0
const DODGE_TIME := 0.3
const DODGE_IFRAMES := 0.24
const DODGE_COOLDOWN := 0.35
const PERFECT_DODGE_WINDOW := 0.12
const PARRY_WINDOW := 0.17
const PERFECT_PARRY := 0.075
const PARRY_COOLDOWN := 0.3
const HURT_TIME := 0.24
const HURT_IFRAMES := 0.9
# --- Outros ---
const POGO_SPEED := 150.0
const POUND_SPEED := 300.0
const CORNER_CORRECTION := 4
const BODY := Vector2(6, 12)
const COMBO_TIMEOUT := 2.4 ## Frenesi: janela para manter a sequência de acertos
## Corte-Relâmpago (atacar durante o dash): dash mais longo que atravessa e
## corta tudo no caminho, em qualquer direção. Acertar recarrega o dash.
const STRIKE_SPEED := 290.0
const STRIKE_TIME := 0.17
const STRIKE_BOX := [-9, -15, 18, 17]
## Níveis do Frenesi (acertos seguidos): nome e bônus de dano
const FRENZY_TIERS := [[10, "BOM!"], [25, "FRENÉTICO!"], [50, "IMPARÁVEL!"], [100, "LENDÁRIO!"]]
const FOCUS_MAX_BASE := 100.0
const ATTACK_BUFFER := 0.16
## Impulso de transição (como no Celeste): quando o centro do corpo (pés - 8)
## cruza o topo da sala subindo, o pulo é renovado para pousar na sala nova.
const TRANSITION_PROBE := 8.0

var state: int = State.NORMAL
var level: Node = null ## a fase (Level) — define respawn, checkpoints etc.

# física por dimensão
var phys: Dictionary = {}
var rules: Array = []
var g_dir: float = 1.0

# timers e flags de movimento
var coyote_t := 0.0
var jump_buffer_t := 0.0
var var_jump_t := 0.0
var var_jump_speed := 0.0
var force_move_x := 0
var force_move_t := 0.0
var wall_dir := 0
var wall_coyote_t := 0.0
var last_wall_dir := 0
var stamina := CLIMB_STAMINA
var air_jumps := 0
var dashes := 1
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector2.RIGHT
var dash_on_ground := false
var dash_grace := 0.0
var _after_t := 0.0
var drop_t := 0.0
var was_on_floor := false
var input_x := 0.0
var input_y := 0.0

# combate
var moveset: Dictionary = {}
var weapon_id := ""
var combo_index := 0
var combo_count := 0
var combo_timer := 0.0
var attack_buffer_t := 0.0
var heavy_charging := false
var heavy_t := 0.0
var rhythm_stacks := 0
var parry_t := 0.0
var parry_cd := 0.0
var blocking := false
var dodge_t := 0.0
var dodge_cd := 0.0
var hurt_t := 0.0
var focus := 0.0
var buffs: BuffSystem
var echo_charges := 0
var echo_mult := 0.6
var echo_time := 0.0
var sigil_points: PackedVector2Array = []
var last_safe_pos := Vector2.ZERO
var _safe_t := 0.0
var _history: Array = [] ## [pos, hp]
var _history_t := 0.0
var _spell_refund: Dictionary = {}
var _using_mouse := false
var interact_area: Area2D
var light: PointLight2D


func _ready() -> void:
	team = Layers.Team.PLAYER
	super._ready()
	add_to_group("actors")
	add_to_group("player")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY
	cs.shape = rect
	cs.position = Vector2(0, -BODY.y * 0.5)
	add_child(cs)
	setup_creature({"sprite": "hero", "body": [5, 4], "head": [6, 5], "color": [0.24, 0.22, 0.38], "shell": [0.93, 0.9, 0.84], "eyes": "hollow", "legs": 2, "horns": true, "weapon": true})
	var hb := Hurtbox.make(self, Vector2(6, 11), Vector2(0, -6))
	add_child(hb)
	interact_area = Area2D.new()
	interact_area.collision_layer = 0
	interact_area.collision_mask = Layers.INTERACT
	var ic := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8.0
	ic.shape = circ
	ic.position = Vector2(0, -7)
	interact_area.add_child(ic)
	add_child(interact_area)
	attack = AttackRunner.new(self)
	add_child(attack)
	attack.landed.connect(_on_attack_landed)
	attack.activated.connect(_on_attack_activated)
	strike_blade = Hitbox.new()
	strike_blade.owner_actor = self
	strike_blade.team = team
	strike_blade.info_factory = func(target): return build_attack_info(moveset.get("dash", {}), "dash", 1.0, target)
	strike_blade.hit.connect(_on_attack_landed)
	add_child(strike_blade)
	caster = SpellCaster.new(self)
	add_child(caster)
	buffs = BuffSystem.new(self)
	# a brasa na lanterna do Lume ilumina o caminho (e reflete nas pedras)
	light = LightUtil.make_light(Color(1.0, 0.66, 0.36), 0.95, 1.05, true)
	if light:
		light.position = Vector2(0, -16)
		light.range_item_cull_mask = LightUtil.LIT_WORLD
		add_child(light)
	if sprite:
		sprite.light_mask = LightUtil.LIT_ACTORS
	apply_profile()
	hp = max_hp()
	focus = 30.0
	last_safe_pos = global_position
	Events.player_spawned.emit(self)
	Events.settings_changed.connect(_on_settings_changed)


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
	if sprite:
		sprite.flip_v = g_dir < 0
	dashes = max_dashes()


func equip_weapon(id: String) -> void:
	weapon_id = id
	moveset = DB.moveset(id)
	# forja: +12% de dano por nível (Commerce)
	var lvl := Commerce.weapon_level(Game.profile, id)
	if lvl > 0 and moveset.has("damage"):
		moveset["damage"] = float(moveset["damage"]) * Commerce.weapon_mult(lvl)
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
	dashes = max_dashes()
	air_jumps = max_air_jumps()
	Events.player_dash_changed.emit(dashes, max_dashes())


func _set_state(s: int) -> void:
	if state == s:
		return
	if state == State.DASH and dash_strike:
		_end_dash_strike()
	state = s
	state_changed.emit(s)


# ---------------------------------------------------------------------------
# Loop principal
# ---------------------------------------------------------------------------

func _actor_physics(d: float, raw: float) -> void:
	_read_input()
	_timers(d)
	caster.tick(d)
	buffs.update(d)
	attack.speed_mult = 1.0
	attack.tick(d)
	_record_history(d)
	if cutscene_lock and state in [State.NORMAL, State.ATTACK, State.DODGE, State.SIGIL]:
		# em cena: só anda (se o roteiro mandar) e cai
		if state != State.NORMAL:
			attack.cancel()
			_set_state(State.NORMAL)
		_run(d)
		_fall(d)
		_move(d)
		_after_move(d)
		_animate()
		return
	match state:
		State.NORMAL: _st_normal(d)
		State.DASH: _st_dash(d)
		State.CLIMB: _st_climb(d)
		State.ATTACK: _st_attack(d)
		State.DODGE: _st_dodge(d)
		State.HURT: _st_hurt(d)
		State.SIGIL: _st_sigil(d, raw)
		State.POUND: _st_pound(d)
		State.RESPAWN, State.DEAD:
			velocity = Vector2.ZERO
	if state != State.RESPAWN and state != State.DEAD:
		_move(d)
		_after_move(d)
	_animate()


## Cena/diálogo em andamento: o jogador não controla o Lume (a cena pode
## fazê-lo andar com script_move = -1/0/1).
var cutscene_lock: bool = false
var script_move: float = 0.0


func _read_input() -> void:
	if cutscene_lock:
		input_x = script_move
		input_y = 0.0
		return
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


func _input(event: InputEvent) -> void:
	# mira com o mouse enquanto ele estiver em uso; controle volta à mira analógica
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_mouse = true
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_using_mouse = false


func _timers(d: float) -> void:
	coyote_t -= d
	jump_buffer_t -= d
	var_jump_t -= d
	force_move_t -= d
	wall_coyote_t -= d
	dash_cd -= d
	dash_grace -= d
	drop_t -= d
	parry_t -= d
	parry_cd -= d
	dodge_cd -= d
	attack_buffer_t -= d
	combo_timer -= d
	if combo_timer <= 0.0 and combo_count > 0:
		_end_frenzy()
	if echo_time > 0.0:
		echo_time -= d
		if echo_time <= 0.0:
			echo_charges = 0
	if drop_t <= 0.0:
		collision_mask |= Layers.ONE_WAY
	if Settings.gameplay("infinite_dash"):
		dashes = max_dashes()


func _gravity() -> float:
	return GRAVITY * float(phys.get("gravity", 1.0)) * g_dir


func _max_run() -> float:
	return MAX_RUN * float(phys.get("speed", 1.0)) * (1.0 + stats.get_stat("move_speed")) * status.speed_mult()


func _vy() -> float:
	return velocity.y * g_dir


func _set_vy(v: float) -> void:
	velocity.y = v * g_dir


func _on_ground() -> bool:
	return is_on_floor()


func _probe_wall() -> int:
	for dir in [1, -1]:
		if test_move(global_transform, Vector2(dir * 2, 0)):
			return dir
	return 0


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _run(d: float, accel_mult: float = 1.0) -> void:
	var max_run := _max_run()
	var mult := (1.0 if _on_ground() else AIR_MULT * float(phys.get("air_control", 1.0))) * accel_mult
	var move := input_x
	if force_move_t > 0.0:
		move = force_move_x
	if absf(velocity.x) > max_run and signf(velocity.x) == move:
		velocity.x = move_toward(velocity.x, max_run * move, RUN_REDUCE * mult * d)
	elif move != 0.0:
		velocity.x = move_toward(velocity.x, max_run * move, RUN_ACCEL * mult * d)
	else:
		velocity.x = move_toward(velocity.x, 0.0, RUN_DECEL * mult * float(phys.get("friction", 1.0)) * d)
	if move != 0.0 and state != State.ATTACK:
		facing = int(move)


func _fall(d: float) -> void:
	var g := GRAVITY * float(phys.get("gravity", 1.0))
	var vy := _vy()
	# meia gravidade no ápice segurando pulo (feel de Celeste)
	if absf(vy) < HALF_GRAV_THRESHOLD and Input.is_action_pressed("jump"):
		g *= 0.5
	var max_fall := FAST_FALL if input_y > 0 else MAX_FALL
	# deslizar na parede
	if wall_dir != 0 and input_x == wall_dir and vy > 0.0 and not _on_ground():
		max_fall = WALL_SLIDE_MAX
		if rng.randf() < 0.3:
			FX.burst(global_position + Vector2(wall_dir * 3, -8), Color(0.9, 0.9, 1.0, 0.5), 1, 15.0, Vector2.DOWN, 20.0, 0.25, 1.0)
	vy = move_toward(vy, max_fall, g * d)
	if var_jump_t > 0.0:
		if Input.is_action_pressed("jump"):
			vy = minf(vy, -var_jump_speed)
		else:
			var_jump_t = 0.0
	_set_vy(vy)


func _try_jump() -> bool:
	if jump_buffer_t <= 0.0:
		return false
	var jmult := float(phys.get("jump", 1.0))
	# soltar de plataforma one-way (baixo + pulo)
	if _on_ground() and input_y > 0 and _standing_on_one_way():
		jump_buffer_t = 0.0
		drop_t = 0.25
		collision_mask &= ~Layers.ONE_WAY
		global_position.y += 2 * g_dir
		return true
	if _on_ground() or coyote_t > 0.0:
		_jump(JUMP_SPEED * jmult)
		velocity.x += JUMP_H_BOOST * input_x
		return true
	if wall_dir != 0 or wall_coyote_t > 0.0:
		var wd := wall_dir if wall_dir != 0 else last_wall_dir
		_jump(JUMP_SPEED * jmult)
		velocity.x = -wd * WALL_JUMP_H
		force_move_x = -wd
		force_move_t = WALL_JUMP_FORCE_TIME
		facing = -wd
		FX.burst(global_position + Vector2(wd * 3, -4), Color(0.9, 0.9, 1.0, 0.7), 4, 45.0, Vector2(-wd, -0.3), 40.0, 0.25, 1.0)
		return true
	if air_jumps > 0:
		air_jumps -= 1
		_jump(DOUBLE_JUMP_SPEED * jmult)
		velocity.x = MAX_RUN * input_x if input_x != 0 else velocity.x
		FX.burst(global_position, Color(1.8, 1.6, 2.4, 0.8), 10, 110.0, Vector2.DOWN, 60.0)
		var ai := AfterImage.from_sprite(sprite, Color(1.4, 1.2, 2.2, 0.6))
		if ai:
			get_parent().add_child(ai)
		return true
	return false


func _jump(speed: float) -> void:
	jump_buffer_t = 0.0
	coyote_t = 0.0
	wall_coyote_t = 0.0
	_set_vy(-speed)
	var_jump_t = VAR_JUMP_TIME
	var_jump_speed = speed
	Audio.play("jump", 0.1, -6.0)
	FX.burst(global_position, Color(0.85, 0.85, 0.95, 0.6), 5, 70.0, Vector2.UP, 70.0, 0.3, 2.0)


func _standing_on_one_way() -> bool:
	var saved := collision_mask
	collision_mask = Layers.WORLD
	var solid_below := test_move(global_transform, Vector2(0, 2 * g_dir))
	collision_mask = saved
	return not solid_below


func _st_normal(d: float) -> void:
	_run(d)
	_fall(d)
	if _try_jump():
		pass
	# escalar parede
	if Game.has_ability("wall_climb") and wall_dir != 0 and not _on_ground() and input_y < 0 and stamina > 0.0:
		_set_state(State.CLIMB)
		return
	_common_actions(d)


## Ações que podem começar a partir do estado normal.
func _common_actions(d: float) -> void:
	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash()
		return
	if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0:
		_start_dodge()
		return
	if Input.is_action_just_pressed("parry"):
		_start_parry()
	if moveset.has("block"):
		blocking = Input.is_action_pressed("parry") and parry_t <= 0.0 and _on_ground()
	if attack_buffer_t > 0.0 and (not attack.is_busy() or attack.can_chain()):
		_start_light()
		return
	if Input.is_action_just_pressed("heavy"):
		if not _on_ground() and input_y > 0 and Game.has_ability("ground_pound"):
			_start_pound()
			return
		heavy_charging = true
		heavy_t = 0.0
		_set_state(State.ATTACK)
		return
	if Input.is_action_just_pressed("spell_1"):
		_cast_slot(0)
	elif Input.is_action_just_pressed("spell_2"):
		_cast_slot(1)
	if Input.is_action_just_pressed("sigil"):
		_start_sigil()
		return
	if Input.is_action_just_pressed("interact") and _on_ground() and input_x == 0:
		_interact()
	if Input.is_action_just_pressed("heal"):
		_use_potion()
	if Input.is_action_just_pressed("swap_weapon"):
		swap_weapon()


func _can_dash() -> bool:
	return dash_cd <= 0.0 and (dashes > 0 or Settings.gameplay("infinite_dash"))


func _start_dash() -> void:
	var dir := Vector2(input_x, input_y)
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0)
	dash_dir = dir.normalized()
	if dash_dir.x != 0.0:
		facing = int(signf(dash_dir.x))
	if not Settings.gameplay("infinite_dash"):
		dashes -= 1
	dash_t = DASH_TIME
	dash_cd = DASH_COOLDOWN
	dash_on_ground = _on_ground()
	invuln_time = maxf(invuln_time, DASH_IFRAMES)
	velocity = dash_dir * DASH_SPEED
	var_jump_t = 0.0
	_after_t = 0.0
	_set_state(State.DASH)
	FX.hitstop(0.035)
	FX.shake(0.08)
	Audio.play("dash", 0.1, -3.0)
	Events.player_dash_changed.emit(dashes, max_dashes())
	buffs.trigger("dash")


func _st_dash(d: float) -> void:
	dash_t -= d
	velocity = dash_dir * DASH_SPEED
	_after_t -= d
	if _after_t <= 0.0:
		_after_t = 0.025
		var ai := AfterImage.from_sprite(sprite, Color(0.6, 1.4, 2.6, 0.9), 0.22)
		if ai:
			get_parent().add_child(ai)
	# Corte-Relâmpago: atacar durante o dash atravessa cortando tudo
	if attack_buffer_t > 0.0 and not dash_strike and not attack.is_busy() and moveset.has("dash"):
		attack_buffer_t = 0.0
		_start_dash_strike()
	if dash_strike:
		velocity = dash_dir * STRIKE_SPEED
	# super / hyper (pulo durante dash no chão)
	if jump_buffer_t > 0.0 and (_on_ground() or coyote_t > 0.0) and dash_on_ground:
		if dash_strike:
			_end_dash_strike()
		var jmult := float(phys.get("jump", 1.0))
		if dash_dir.y > 0.1 and absf(dash_dir.x) > 0.1:
			_jump(JUMP_SPEED * 0.55 * jmult)
			velocity.x = signf(dash_dir.x) * HYPER_H
		else:
			_jump(JUMP_SPEED * jmult)
			velocity.x = signf(dash_dir.x if dash_dir.x != 0.0 else facing) * SUPER_H
		_set_state(State.NORMAL)
		refill_dash()
		FX.shake(0.12)
		return
	_dash_through_check()
	if dash_t <= 0.0:
		if dash_strike:
			_end_dash_strike()
		velocity = dash_dir * DASH_END_SPEED
		if dash_dir.y * g_dir < 0.0:
			velocity.y *= 0.75
		dash_grace = 0.08
		_set_state(State.NORMAL)
		buffs.trigger("dash_end")


var _dash_through_hit: Dictionary = {}
var dash_strike: bool = false
var strike_blade: Hitbox
var _strike_from: Vector2 = Vector2.ZERO
var _strike_hits: int = 0
var frenzy_tier: int = 0


func _start_dash_strike() -> void:
	dash_strike = true
	_strike_from = global_position
	_strike_hits = 0
	dash_t = STRIKE_TIME
	velocity = dash_dir * STRIKE_SPEED
	invuln_time = maxf(invuln_time, STRIKE_TIME + 0.05)
	strike_blade.team = team
	strike_blade.set_box(STRIKE_BOX, 1)
	strike_blade.activate()
	FX.kick(dash_dir, 3.0)
	FX.zoom_punch(0.02)
	Audio.play("dash_strike", 0.08, -1.0)
	play_anim("attack", true)
	if sprite:
		sprite.squash(Vector2(1.35, 0.7))


func _end_dash_strike() -> void:
	if not dash_strike:
		return
	dash_strike = false
	strike_blade.deactivate()
	var line := DashCutLine.new()
	line.from = _strike_from + Vector2(0, -6)
	line.to = global_position + Vector2(0, -6)
	line.hits = _strike_hits
	get_parent().add_child(line)


func _dash_through_check() -> void:
	# relíquias "ao atravessar inimigos com dash"
	for a in get_tree().get_nodes_in_group("actors"):
		if a == self or a.team == team or a.dead:
			continue
		if a.body_center().distance_to(body_center()) < 8.0 and not _dash_through_hit.has(a):
			_dash_through_hit[a] = true
			buffs.trigger("dash_through", {"target": a})
	if dash_t <= 0.0:
		_dash_through_hit.clear()


func _st_climb(d: float) -> void:
	var holding := input_y != 0.0
	if wall_dir == 0 or _on_ground() or stamina <= 0.0 or not holding:
		if wall_dir == 0 and stamina > 0.0 and input_y < 0:
			# topo da parede: pulinho para subir na borda
			_set_vy(-JUMP_SPEED * 0.7)
			velocity.x = last_wall_dir * 60.0
		_set_state(State.NORMAL)
		return
	velocity.x = wall_dir * 10.0
	var climb := 0.0
	if input_y < 0:
		climb = -CLIMB_SPEED
		stamina -= d
	else:
		climb = CLIMB_SPEED * 1.5
		stamina -= d * 0.35
	_set_vy(climb)
	facing = wall_dir
	if jump_buffer_t > 0.0:
		_try_jump()
		_set_state(State.NORMAL)
		return
	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash()


# ---------------------------------------------------------------------------
# Ataques
# ---------------------------------------------------------------------------

func _start_light() -> void:
	attack_buffer_t = 0.0
	if moveset.is_empty():
		return
	var kind := "light"
	var step: Dictionary
	if not _on_ground():
		if input_y > 0:
			kind = "down_air"
		elif input_y < 0:
			kind = "up_air"
		else:
			kind = "air"
		step = moveset[kind]
	elif input_y < 0:
		kind = "up_air"
		step = moveset["up_air"]
	else:
		var chain: Array = moveset["light"]
		if combo_timer <= 0.0 or combo_index >= chain.size():
			combo_index = 0
		step = chain[combo_index]
		# ritmo: acertar o tempo do golpe anterior acumula Compasso
		if moveset.get("rhythm", false) and attack.is_busy():
			var beat := float(attack.step.get("beat", 0.07))
			if absf(attack.time_to_end()) <= beat * 1.6:
				rhythm_stacks = mini(rhythm_stacks + 1, 5)
				emote("note", 0.5)
			else:
				rhythm_stacks = 0
		combo_index += 1
	if input_x != 0.0:
		facing = int(input_x)
	attack.cancel()
	attack.start(step, kind, facing)
	combo_timer = COMBO_TIMEOUT
	_set_state(State.ATTACK)
	play_anim("attack", true)


func _slash_fx(raw_step: Dictionary) -> void:
	var step := AttackRunner.scaled(raw_step)
	var box: Array = step.get("box", [0, -30, 40, 30])
	var center := Vector2((float(box[0]) + float(box[2]) * 0.5) * facing, float(box[1]) + float(box[3]) * 0.5)
	# arco claro com brilho leve (bloom só na borda): legível sem ofuscar
	var c := Color(1.3, 1.35, 1.55)
	if not moveset.get("weapon_status", {}).is_empty() or step.has("status"):
		c = Color(1.6, 0.55, 0.6)
	if step.get("thrust", false):
		if attack.kind == "up_air":
			FX.slash(global_position + Vector2(0, float(box[1]) + float(box[3])), facing, 0.0, float(box[3]), c, -PI * 0.5 * facing, true)
		elif attack.kind == "down_air":
			FX.slash(global_position + Vector2(0, float(box[1])), facing, 0.0, float(box[3]), c, PI * 0.5 * facing, true)
		else:
			FX.slash(global_position + Vector2(float(box[0]) * facing, center.y), facing, 0.0, float(box[2]), c, 0.0, true)
	elif step.has("arc"):
		var arc: Array = step["arc"]
		var rot := 0.0
		if attack.kind == "down_air":
			rot = PI * 0.5 * facing
		elif attack.kind == "up_air":
			rot = -PI * 0.5 * facing
		FX.slash(body_center(), facing, float(arc[0]), float(arc[1]) * AttackRunner.BOX_SCALE, c, rot)
	Audio.play("swing_heavy" if step.get("dmg", 1.0) > 1.3 else "swing", 0.12, -4.0)


func _on_attack_activated(step: Dictionary, kind: String) -> void:
	if kind != "dash":
		_slash_fx(step)
	if step.has("projectile"):
		_throw(step)
	if step.get("shockwave", false) and _on_ground():
		FX.shake(0.35)
		var ring := NovaFX.new()
		ring.radius = 70
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
	p.velocity = aim_direction() * 420.0
	p.radius = 4.0
	p.color = Color(2.4, 2.4, 2.8)
	p.lifetime = 0.9
	p.light_enabled = false
	p.global_position = body_center() + Vector2(facing * 4, 0)
	get_parent().add_child(p)


func _st_attack(d: float) -> void:
	# carregando o pesado
	if heavy_charging:
		heavy_t += d
		velocity.x = move_toward(velocity.x, 0.0, RUN_DECEL * d)
		_fall(d)
		if heavy_t > float(moveset.get("heavy", {}).get("charge", 0.4)) and fmod(heavy_t, 0.12) < d:
			FX.burst(body_center(), Color(2.6, 2.0, 1.0), 3, 60.0)
		if not Input.is_action_pressed("heavy"):
			heavy_charging = false
			var h: Dictionary = moveset.get("heavy", {})
			var charged := heavy_t >= float(h.get("charge", 0.4))
			var mult := float(h.get("charged_mult", 1.5)) if charged else 1.0
			if input_x != 0.0:
				facing = int(input_x)
			attack.cancel()
			attack.start(h, "heavy", facing, mult)
			if charged:
				FX.flash(0.4)
				Audio.play("draw_blade")
			play_anim("attack", true)
		return
	var step := attack.step
	# avanço (lunge) durante startup/ativo
	if attack.is_busy() and attack.phase != AttackRunner.Phase.RECOVERY:
		var lunge := float(step.get("lunge", 0.0))
		if _on_ground() or attack.kind == "heavy":
			velocity.x = facing * lunge * (1.0 - attack.progress() * 0.5)
		else:
			_run(d, 0.6)
	else:
		if _on_ground():
			velocity.x = move_toward(velocity.x, 0.0, RUN_DECEL * 1.5 * d)
		else:
			_run(d, 0.6)
	_fall(d)
	# cancelamentos: dash/esquiva/aparar podem cancelar a recuperação
	if attack.phase == AttackRunner.Phase.RECOVERY or not attack.is_busy():
		if Input.is_action_just_pressed("dash") and _can_dash():
			attack.cancel()
			_start_dash()
			return
		if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0:
			attack.cancel()
			_start_dodge()
			return
		if Input.is_action_just_pressed("parry"):
			attack.cancel()
			_start_parry()
		if jump_buffer_t > 0.0 and (_on_ground() or coyote_t > 0.0 or air_jumps > 0):
			attack.cancel()
			_set_state(State.NORMAL)
			_try_jump()
			return
		if attack_buffer_t > 0.0 and attack.can_chain():
			_start_light()
			return
	if not attack.is_busy():
		_set_state(State.NORMAL)


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
	info.weight = _attack_weight(step, kind, charge)
	info.stagger = float(step.get("stagger", 1.0)) * charge
	info.pogo = step.get("pogo", false)
	var dir := Vector2(facing, 0)
	if kind == "down_air":
		dir = Vector2(0, 1)
	elif kind == "up_air":
		dir = Vector2(0, -1)
	info.direction = dir
	info.knockback = dir * float(step.get("kb", 150.0)) + Vector2(0, -30.0 if kind != "down_air" else 0.0)
	var st: Dictionary = moveset.get("weapon_status", {}).duplicate()
	for s in step.get("status", {}).keys():
		st[s] = int(st.get(s, 0)) + int(step["status"][s])
	info.status = st
	info.is_crit = CombatMath.roll_crit(rng, stats, buffs.consume_crit())
	# multiplicadores do jogador: combo, ritmo, costas, ponto fraco da classe, buffs
	var mult := frenzy_mult()
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
	info.amount *= mult
	if slowmo_bonus():
		info.amount *= 1.15
	return info


## Peso do golpe (0 leve .. 1 pesado carregado): escala hitstop, tremor,
## coice de câmera e efeitos. Finalizador do combo e Corte-Relâmpago pesam mais.
func _attack_weight(step: Dictionary, kind: String, charge: float) -> float:
	var w := 0.15
	match kind:
		"heavy":
			w = 0.6 if charge <= 1.0 else 0.95
		"dash":
			w = 0.4
		"down_air", "up_air", "air":
			w = 0.2
		_:
			var chain: Array = moveset.get("light", [])
			if chain.size() > 1 and combo_index >= chain.size():
				w = 0.4 # último golpe do combo
	return clampf(w + (float(step.get("dmg", 1.0)) - 1.0) * 0.2, 0.1, 1.0)


func _check_frenzy_tier() -> void:
	var tier := 0
	for i in FRENZY_TIERS.size():
		if combo_count >= int(FRENZY_TIERS[i][0]):
			tier = i + 1
	if tier > frenzy_tier:
		frenzy_tier = tier
		Events.frenzy_tier.emit(tier, str(FRENZY_TIERS[tier - 1][1]))
		Audio.play("frenzy", 0.0, -2.0)
		emote("!", 0.5)


## Fim da sequência: brasas de bônus pelo tamanho do Frenesi.
func _end_frenzy() -> void:
	var n := combo_count
	combo_count = 0
	frenzy_tier = 0
	Events.combo_changed.emit(0)
	if n >= 8:
		var bonus := int(n * 0.5)
		Game.profile["currency"] = int(Game.profile.get("currency", 0)) + bonus
		Events.frenzy_ended.emit(n, bonus)


## Bônus de dano do Frenesi atual (5% por nível).
func frenzy_mult() -> float:
	return 1.0 + frenzy_tier * 0.05


func slowmo_bonus() -> bool:
	return FX.slowmo_active


func _on_attack_landed(target: Node, info: DamageInfo, result: int) -> void:
	if result == DamageInfo.Result.IGNORED or result == DamageInfo.Result.INVULNERABLE:
		return
	if not (target is Actor):
		FX.hitstop(0.03)
		if info.pogo:
			_pogo()
		return
	if result == DamageInfo.Result.BLOCKED or result == DamageInfo.Result.PARRIED:
		FX.hitstop(0.05)
		Audio.play("hit_metal")
		velocity.x = -facing * 60.0
		return
	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	Events.combo_changed.emit(combo_count)
	_check_frenzy_tier()
	# Ímpeto: todo acerto recarrega o dash (dash → corte → dash → corte...)
	refill_dash()
	dash_cd = 0.0
	if info.is_dash_attack:
		_strike_hits += 1
	gain_focus(float(moveset.get("focus_gain", 5)) * (1.0 + stats.get_stat("focus_gain")))
	var ctx := {"target": target, "info": info, "combo": combo_count}
	buffs.trigger("hit", ctx)
	if info.is_crit:
		buffs.trigger("crit", ctx)
	buffs.trigger("combo", ctx)
	if info.pogo:
		_pogo()
	elif not info.is_dash_attack and attack.kind != "up_air":
		# recuo ao acertar (Hollow Knight)
		velocity.x = -facing * 55.0
	if info.is_dash_attack:
		dash_t = maxf(dash_t, 0.05)
	Audio.play("hit_heavy" if info.is_heavy or info.is_crit or info.weight >= 0.5 else "hit", 0.1, -2.0)
	if result == DamageInfo.Result.KILLED:
		Game.profile["kills"] = int(Game.profile.get("kills", 0)) + 1
		refill_dash()
		combo_count += 2
		combo_timer = COMBO_TIMEOUT
		Events.combo_changed.emit(combo_count)
		_check_frenzy_tier()
		Audio.play("kill", 0.06, -1.0)
		buffs.trigger("kill", ctx)


func _pogo() -> void:
	_set_vy(-POGO_SPEED * float(phys.get("jump", 1.0)))
	var_jump_t = 0.0
	refill_dash()
	buffs.trigger("pogo")
	FX.burst(global_position + Vector2(0, 6), Color(2.4, 2.4, 2.8), 8, 120.0, Vector2.UP, 60.0)
	if state == State.ATTACK and attack.kind == "down_air":
		attack.cancel()
		_set_state(State.NORMAL)


func _start_pound() -> void:
	_set_state(State.POUND)
	velocity = Vector2(0, POUND_SPEED * g_dir)
	var_jump_t = 0.0
	invuln_time = maxf(invuln_time, 0.2)
	FX.hitstop(0.05)


func _st_pound(_d: float) -> void:
	velocity = Vector2(0, POUND_SPEED * g_dir)
	if _on_ground() or is_on_floor():
		_pound_impact()


func _pound_impact() -> void:
	_set_state(State.NORMAL)
	FX.shake(0.55)
	Audio.play("break")
	var ring := NovaFX.new()
	ring.radius = 64
	ring.color = Color(2.0, 1.6, 1.1)
	ring.global_position = global_position
	get_parent().add_child(ring)
	for a in get_tree().get_nodes_in_group("actors"):
		if a.team != team and not a.dead and a.global_position.distance_to(global_position) < 26.0:
			var info := DamageInfo.new()
			info.amount = float(moveset.get("damage", 10.0)) * 1.4
			info.damage_type = "blunt"
			info.team = team
			info.source = self
			info.knockback = Vector2(signf(a.global_position.x - global_position.x) * 200.0, -240.0)
			info.stagger = 4.0
			for hb in a.get_children():
				if hb is Hurtbox:
					hb.receive(info)
					break
	for b in get_tree().get_nodes_in_group("cracked_floor"):
		if b.global_position.distance_to(global_position) < 16.0:
			b.shatter()


# ---------------------------------------------------------------------------
# Defesa
# ---------------------------------------------------------------------------

func _start_parry() -> void:
	if parry_cd > 0.0:
		return
	parry_t = PARRY_WINDOW + float(moveset.get("parry_bonus", 0.0))
	parry_cd = PARRY_COOLDOWN
	FX.burst(body_center() + Vector2(facing * 4, 0), Color(2.4, 2.4, 3.0), 3, 30.0, Vector2.ZERO, 180.0, 0.2, 1.0)
	# área curta que rebate projéteis
	var hb := attack.hitbox
	if not attack.is_busy():
		hb.set_box([-2, -12, 12, 12], facing)
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
	velocity.x = dir * DODGE_SPEED * (1.0 if _on_ground() else 0.7)
	_set_state(State.DODGE)
	Audio.play("dash", 0.15, -8.0)


func _st_dodge(d: float) -> void:
	dodge_t -= d
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * d)
	_fall(d)
	if fmod(dodge_t, 0.05) < d:
		var ai := AfterImage.from_sprite(sprite, Color(1.0, 1.0, 1.6, 0.5), 0.2)
		if ai:
			get_parent().add_child(ai)
	if dodge_t <= 0.0:
		_set_state(State.NORMAL)


func _before_hit(info: DamageInfo) -> int:
	if Settings.gameplay("invincible") and not info.is_hazard:
		return DamageInfo.Result.INVULNERABLE
	# esquiva perfeita: golpe chegou no começo da esquiva
	if state == State.DODGE and DODGE_TIME - dodge_t <= PERFECT_DODGE_WINDOW and not info.is_hazard:
		FX.slowmo(0.3, 0.55 * (1.0 + stats.get_stat("perfect_dodge_time")))
		emote("!", 0.6)
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
		FX.hitstop(0.14 if perfect else 0.07)
		FX.flash(1.0 if perfect else 0.5)
		FX.shake(0.3 if perfect else 0.15)
		FX.burst(body_center() + Vector2(facing * 5, 0), Color(3.2, 3.0, 2.2), 12 if perfect else 6, 120.0, Vector2.ZERO, 180.0, 0.25, 1.0)
		Audio.play("parry_perfect" if perfect else "parry")
		gain_focus(22.0 if perfect else 10.0)
		if perfect:
			FX.slowmo(0.35, 0.35)
			emote("!", 0.6)
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
			FX.burst(body_center() + Vector2(facing * 4, 0), Color(2.0, 2.0, 2.4), 5, 70.0, Vector2.ZERO, 180.0, 0.2, 1.0)
			velocity.x = -facing * 70.0
			if info.amount < 1.0:
				return DamageInfo.Result.BLOCKED
	return -1


func _modify_incoming(info: DamageInfo, amount: float) -> float:
	if has_rule("one_hit"):
		return max_hp() * 10.0
	return amount


func _on_damaged(info: DamageInfo, amount: float) -> void:
	FX.impact(body_center(), info.direction, amount, false, true, Color(2.6, 0.4, 0.4))
	FX.flash(0.8)
	Audio.play("hurt")
	combo_count = 0
	frenzy_tier = 0
	rhythm_stacks = 0
	Events.combo_changed.emit(0)
	Events.player_health_changed.emit(hp, max_hp())
	buffs.trigger("hurt", {"info": info})
	if dead:
		return
	attack.cancel()
	heavy_charging = false
	invuln_time = HURT_IFRAMES
	if info.is_hazard:
		_hazard_respawn()
		return
	hurt_t = HURT_TIME
	var kb_dir := signf(info.direction.x) if info.direction.x != 0.0 else -float(facing)
	velocity = Vector2(kb_dir * 100.0, -120.0 * g_dir)
	_set_state(State.HURT)


func _apply_knockback(_info: DamageInfo) -> void:
	pass


func _st_hurt(d: float) -> void:
	hurt_t -= d
	_fall(d)
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * d)
	if hurt_t <= 0.0:
		_set_state(State.NORMAL)


func _hazard_respawn() -> void:
	if dead:
		return
	_set_state(State.RESPAWN)
	velocity = Vector2.ZERO
	_kill_visual_tween()
	var tw := create_tween()
	_visual_tween = tw
	tw.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		global_position = last_safe_pos
		reset_physics_interpolation()
		refill_dash())
	tw.tween_property(sprite, "modulate:a", 1.0, 0.15)
	tw.tween_callback(func(): _set_state(State.NORMAL))


func _die(info: DamageInfo) -> void:
	# alguém querido pode te salvar
	var savior := SocialSystem.rescue_candidate(Game.social, Game.profile.get("region", ""))
	if savior != "" and not Game.social.is_empty():
		var npc: Dictionary = Game.social["npcs"][savior]
		npc["rescues"] = int(npc["rescues"]) + 1
		hp = max_hp() * 0.35
		invuln_time = 2.0
		FX.slowmo(0.2, 0.8)
		FX.flash(1.0)
		emote("heart", 2.0)
		Events.toast.emit("%s (%s) chegou a tempo e te salvou." % [npc["name"], npc["title"]])
		Events.player_health_changed.emit(hp, max_hp())
		return
	super._die(info)


func _on_death(_info: DamageInfo) -> void:
	_set_state(State.DEAD)
	Game.profile["deaths"] = int(Game.profile.get("deaths", 0)) + 1
	FX.slowmo(0.25, 1.0)
	FX.shake(0.6)
	Audio.play("death")
	_kill_visual_tween()
	var tw := create_tween()
	_visual_tween = tw
	tw.tween_method(set_dissolve, 0.0, 1.0, 0.9)
	Events.player_died.emit(self)


## Animação visual em andamento (sumir na morte / piscar no buraco). Precisa
## ser cancelada ao renascer, senão ela termina depois e deixa o jogador
## invisível (a morte roda em câmera lenta e dura mais que a espera do Level).
var _visual_tween: Tween = null


func _kill_visual_tween() -> void:
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
	_visual_tween = null


func revive(at: Vector2) -> void:
	dead = false
	hp = max_hp()
	global_position = at
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	_kill_visual_tween()
	set_dissolve(0.0)
	if sprite:
		sprite.modulate.a = 1.0
		sprite.visible = true
	status.clear()
	invuln_time = 1.0
	refill_dash()
	_set_state(State.NORMAL)
	Events.player_health_changed.emit(hp, max_hp())


# ---------------------------------------------------------------------------
# Magias / sigilos / itens
# ---------------------------------------------------------------------------

func aim_direction() -> Vector2:
	if _using_mouse:
		var to := get_global_mouse_position() - body_center()
		if to.length() > 4.0:
			return to.normalized()
	var v := Vector2(input_x, input_y)
	if v == Vector2.ZERO:
		v = Vector2(facing, 0)
	return v.normalized()


func aim_target() -> Vector2:
	if _using_mouse:
		return get_global_mouse_position()
	return body_center() + aim_direction() * 50.0


func _cast_slot(i: int) -> void:
	var slots: Array = Game.profile.get("spell_slots", [])
	if i >= slots.size():
		return
	cast_spell(slots[i], 1.0)


func cast_spell(spell_id: String, power: float) -> bool:
	if has_rule("no_spells"):
		emote("?", 0.8)
		return false
	var level := Inventory.spell_level(Game.profile, spell_id)
	var cost := caster.cost_of(spell_id, level)
	if focus < cost:
		emote("drop", 0.8)
		Audio.play("ui_error", 0.0, -8.0)
		return false
	if not caster.is_ready(spell_id):
		return false
	if caster.cast(spell_id, level, aim_direction(), aim_target(), power):
		_spell_refund = {"id": spell_id, "cost": cost}
		gain_focus(-cost)
		buffs.trigger("spell_cast", {"spell": spell_id})
		return true
	return false


func refund_last_spell() -> void:
	if _spell_refund.has("cost"):
		gain_focus(float(_spell_refund["cost"]))
		emote("note", 0.6)


func _start_sigil() -> void:
	if Game.profile.get("sigils", {}).is_empty():
		return
	sigil_points = PackedVector2Array()
	_set_state(State.SIGIL)
	if Settings.gameplay("sigil_slowmo"):
		FX.slowmo(0.2, 3.0)


func _st_sigil(d: float, _raw: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, RUN_DECEL * d)
	_fall(d)
	var p := get_viewport().get_mouse_position()
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.4:
		var last := sigil_points[-1] if not sigil_points.is_empty() else LevelConst.VIEW_PX * 0.5
		p = last + stick * 6.0
	if sigil_points.is_empty() or sigil_points[-1].distance_to(p) > 2.0:
		sigil_points.append(p)
	if not Input.is_action_pressed("sigil"):
		_finish_sigil()


func _finish_sigil() -> void:
	FX.clear_time_effects()
	_set_state(State.NORMAL)
	var res := SigilRecognizer.recognize(sigil_points)
	sigil_points = PackedVector2Array()
	if res["name"] == "":
		emote("?", 0.8)
		return
	for sid in Game.profile.get("sigils", {}).keys():
		if DB.spell(sid).get("sigil", "") == res["name"]:
			var power := SigilRecognizer.power_from_accuracy(res["accuracy"])
			if cast_spell(sid, power):
				Events.toast.emit("%s  %d%%" % [DB.display_name(sid), int(res["accuracy"] * 100)])
			return
	emote("?", 0.8)


func start_echo(count: int, mult: float, duration: float) -> void:
	echo_charges = count
	echo_mult = mult
	echo_time = duration
	FX.burst(body_center(), Color(0.6, 2.8, 2.6), 20, 150.0)


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
		var ghost := AfterImage.from_sprite(sprite, Color(1.6, 2.6, 1.4, 0.6), 0.5)
		if ghost:
			ghost.global_position = _history[i][0]
			get_parent().add_child(ghost)
	global_position = entry[0]
	reset_physics_interpolation()
	var lost := float(entry[1]) - hp
	if lost > 0.0:
		heal(lost * heal_ratio)
	_history.clear()
	FX.flash(0.6)


func _use_potion() -> void:
	if hp >= max_hp():
		return
	if Inventory.use_item(Game.profile, "pocao_vida"):
		heal(float(DB.items["pocao_vida"].get("heal", 30)))
		Audio.play("pickup")


func _interact() -> void:
	var best: Node = null
	var best_d := INF
	for a in interact_area.get_overlapping_areas():
		if a.has_method("interact"):
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


# ---------------------------------------------------------------------------
# Movimento físico
# ---------------------------------------------------------------------------

func _move(d: float) -> void:
	var own := velocity
	var total := own + external_velocity
	velocity = total
	# correção de quina ao subir (Celeste)
	if _vy() < 0.0 and state != State.CLIMB:
		var motion := Vector2(0, velocity.y * d)
		if test_move(global_transform, motion):
			for off in range(1, CORNER_CORRECTION + 1):
				var found := false
				for sgn in [-1, 1]:
					if not test_move(global_transform.translated(Vector2(off * sgn, 0)), motion):
						global_position.x += off * sgn
						found = true
						break
				if found:
					break
	# correção no dash horizontal (sobe em bordinhas)
	if state == State.DASH and absf(dash_dir.y) < 0.1:
		var mx := Vector2(velocity.x * d, 0)
		if test_move(global_transform, mx):
			for off in range(1, CORNER_CORRECTION + 1):
				if not test_move(global_transform.translated(Vector2(0, -off * g_dir)), mx):
					global_position.y -= off * g_dir
					break
	# move_and_slide usa o delta de física bruto; compensa o tempo local
	var scale := d / maxf(get_physics_process_delta_time(), 0.00001)
	velocity = total * scale
	move_and_slide()
	var post := velocity / maxf(scale, 0.00001)
	# preserva a velocidade própria; só aplica o que a colisão cortou
	velocity = own
	if not is_equal_approx(post.x, total.x):
		velocity.x = post.x - external_velocity.x if absf(post.x) > 0.01 else 0.0
	if not is_equal_approx(post.y, total.y):
		velocity.y = post.y - external_velocity.y if absf(post.y) > 0.01 else 0.0


func _after_move(d: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		coyote_t = COYOTE
		stamina = CLIMB_STAMINA
		air_jumps = max_air_jumps()
		if dash_t <= 0.0 and state != State.DASH and dashes < max_dashes():
			dashes = max_dashes()
			Events.player_dash_changed.emit(dashes, max_dashes())
		if not was_on_floor:
			FX.burst(global_position, Color(0.85, 0.85, 0.95, 0.6), 6, 80.0, Vector2.UP, 80.0, 0.3, 2.0)
			Audio.play("land", 0.1, -10.0)
			if state == State.POUND:
				_pound_impact()
		_safe_t += d
		if _safe_t > 0.15 and velocity.length() < 400.0:
			last_safe_pos = global_position
	else:
		_safe_t = 0.0
	was_on_floor = on_floor
	wall_dir = 0 if on_floor else _probe_wall()
	if wall_dir != 0:
		wall_coyote_t = WALL_COYOTE
		last_wall_dir = wall_dir


var _idle_t: float = 0.0
var _mood_t: float = 0.0


## Reações sem fala: "…" parado, gota de suor com pouca vida, "?" perto de
## segredos. (Level chama emote("!") ao trancar uma sala de combate.)
func _moods(d: float) -> void:
	_mood_t -= d
	if state == State.NORMAL and is_on_floor() and absf(velocity.x) < 5.0 and input_x == 0.0:
		_idle_t += d
		if _idle_t > 6.0:
			_idle_t = -4.0
			emote("...", 2.0)
	else:
		_idle_t = 0.0
	if _mood_t <= 0.0:
		_mood_t = 3.0
		if hp / maxf(max_hp(), 1.0) < 0.3:
			emote("drop", 1.2)
		else:
			for b in get_tree().get_nodes_in_group("secrets"):
				if b.global_position.distance_to(global_position) < 20.0:
					emote("?", 1.2)
					break


func _charge_pose() -> bool:
	return heavy_charging


## Chamado pela fase ao subir para a sala de cima (ver TRANSITION_PROBE).
func transition_boost() -> void:
	if dead or g_dir < 0.0 or _vy() >= 0.0:
		return
	_set_vy(minf(_vy(), -JUMP_SPEED))
	var_jump_t = VAR_JUMP_TIME
	var_jump_speed = JUMP_SPEED


## Animação imposta por uma cena (ex.: "sleep" no despertar). Vazio = normal.
var force_anim: String = ""


func _animate() -> void:
	if sprite == null:
		return
	_moods(get_physics_process_delta_time())
	sprite.attack_pose = attack.progress() if attack.is_busy() else 0.0
	if force_anim != "":
		play_anim(force_anim)
		if light and sprite.has_sheet():
			light.position = sprite.point("core")
		return
	match state:
		State.DASH, State.DODGE:
			play_anim("dash")
		State.POUND:
			play_anim("crouch")
		State.ATTACK:
			if heavy_charging:
				play_anim("crouch")
			elif attack.is_busy():
				play_anim("attack")
			else:
				play_anim("idle")
		State.HURT:
			play_anim("hurt")
		State.DEAD:
			play_anim("death")
		State.CLIMB:
			play_anim("climb" if absf(velocity.y) > 4.0 else "wall")
		State.SIGIL:
			play_anim("cast")
		_:
			if is_on_floor():
				if absf(velocity.x) > 25.0:
					play_anim("run")
				elif input_y > 0:
					play_anim("crouch")
				elif _idle_t > 4.0 or _idle_t < -2.0:
					play_anim("sleep")
				else:
					play_anim("idle")
			elif wall_dir != 0 and input_x == wall_dir and _vy() > 0.0:
				play_anim("wall")
			else:
				play_anim("jump" if _vy() < 0.0 else "fall")
	# a luz sai do vidro da lanterna (a brasa do Lume): tremula e enfraquece
	# com a vida baixa
	if light and sprite.has_sheet():
		light.position = sprite.point("core")
		var life := clampf(hp / maxf(max_hp(), 1.0), 0.0, 1.0)
		var t := Time.get_ticks_msec() / 1000.0
		var flick := 1.0 + 0.05 * sin(t * 13.0) + 0.03 * sin(t * 31.0 + 1.3)
		light.energy = 0.68 * (0.62 + 0.38 * life) * flick
		light.texture_scale = 0.44 * (0.82 + 0.18 * life)
	if state == State.HURT or (invuln_time > 0.3 and state != State.DASH and state != State.DODGE):
		sprite.visible = fmod(Time.get_ticks_msec() / 60.0, 2.0) > 0.6
	else:
		sprite.visible = true


func _on_settings_changed() -> void:
	if light:
		light.shadow_enabled = bool(Settings.video("shadows"))
		light.visible = bool(Settings.video("dynamic_lights"))
