class_name GameCamera
extends Camera2D
## Câmera livre estilo Dead Cells: segue o jogador pela fase inteira (presa
## só aos limites da fase), olha à frente na direção do movimento e só sobe/
## desce quando o jogador pousa num nível novo ou sai da zona morta vertical
## (não balança a cada pulo). Em arenas trancadas e chefes ela fica presa à
## sala (`lock_room`). Soma tremor (FX.shake_offset) e "coice" direcional
## (FX.kick_offset) — o zoom de impacto é aplicado na exibição (Level).

const VIEW := LevelConst.VIEW
const LOOK_AHEAD := 30.0 ## unidades à frente na direção do movimento
const DEAD_UP := 18.0 ## zona morta vertical (acima/abaixo do ponto de apoio)
const DEAD_DOWN := 10.0
const FOLLOW_X := 7.0
const FOLLOW_Y := 5.5
const TRANSITION_RATE := 9.0
const TRANSITION_TIME := 0.3

var target: Node2D = null
var screen_velocity: Vector2 = Vector2.ZERO ## usado pelo motion blur
## Sala em que a câmera está presa (arena/chefe). Vazio = livre na fase.
var room_rect: Rect2 = Rect2()
var transitioning: float = 0.0
var _look_x: float = 0.0
var _anchor_y: float = 0.0
var _fall_look: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _pos: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()


func _ready() -> void:
	position_smoothing_enabled = false
	zoom = Vector2.ONE * LevelConst.ART
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	FX.camera = self
	if target:
		snap()


func snap() -> void:
	if target == null:
		return
	_look_x = 0.0
	_fall_look = 0.0
	_anchor_y = target.global_position.y
	_pos = _clamp_view(_focus())
	global_position = _pos
	_last_pos = _pos
	transitioning = 0.0
	reset_physics_interpolation()


## Prende a câmera numa sala (arena/chefe). `instant` pula a transição.
func lock_room(rect: Rect2, instant: bool = false) -> void:
	if rect == room_rect:
		return
	room_rect = rect
	if instant:
		snap()
	else:
		transitioning = TRANSITION_TIME


## Solta a câmera (volta a seguir livre pela fase).
func unlock_room() -> void:
	if not room_rect.has_area():
		return
	room_rect = Rect2()
	transitioning = TRANSITION_TIME


## Compatibilidade: antes a câmera era sempre presa à sala.
func set_room(rect: Rect2, instant: bool = false) -> void:
	lock_room(rect, instant)


func _focus() -> Vector2:
	return Vector2(target.global_position.x + _look_x, _anchor_y - 18.0 + _fall_look)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var v: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
	var on_floor: bool = target.is_on_floor() if target is CharacterBody2D else true
	# olhar à frente: pela velocidade, ou pelo lado para onde está virado
	var dir := signf(v.x) if absf(v.x) > 20.0 else float(target.get("facing") if "facing" in target else 1)
	var speed_k := clampf(absf(v.x) / 90.0, 0.35, 1.25)
	_look_x = lerpf(_look_x, dir * LOOK_AHEAD * speed_k, 1.0 - exp(-delta * 2.2))
	# vertical: ponto de apoio = altura do chão onde pousou
	var ty: float = target.global_position.y
	if on_floor:
		_anchor_y = lerpf(_anchor_y, ty, 1.0 - exp(-delta * 8.0))
	elif ty < _anchor_y - DEAD_UP:
		_anchor_y = ty + DEAD_UP
	elif ty > _anchor_y + DEAD_DOWN:
		_anchor_y = ty - DEAD_DOWN
	# caindo rápido: mostra mais do que vem embaixo
	var want_fall := clampf((v.y - 120.0) * 0.35, 0.0, 40.0) if not on_floor else 0.0
	_fall_look = lerpf(_fall_look, want_fall, 1.0 - exp(-delta * 4.0))
	var desired := _clamp_view(_focus())
	var rx := FOLLOW_X
	var ry := FOLLOW_Y + (4.0 if v.y > 150.0 else 0.0)
	if transitioning > 0.0:
		transitioning -= delta
		rx = TRANSITION_RATE
		ry = TRANSITION_RATE
	_pos.x = lerpf(_pos.x, desired.x, 1.0 - exp(-delta * rx))
	_pos.y = lerpf(_pos.y, desired.y, 1.0 - exp(-delta * ry))
	global_position = _pos
	offset = FX.shake_offset + FX.kick_offset
	var screen := get_screen_center_position()
	screen_velocity = (screen - _last_pos) / maxf(delta, 0.0001)
	_last_pos = screen


## Centro de câmera mais próximo de `p` que mantém a tela dentro da sala
## presa (ou da fase). Área menor que a tela = centraliza.
func _clamp_view(p: Vector2) -> Vector2:
	var r := room_rect if room_rect.has_area() else _bounds
	if not r.has_area():
		return p
	var half := VIEW * 0.5
	var out := p
	for axis in 2:
		var lo: float = r.position[axis] + half[axis]
		var hi: float = r.end[axis] - half[axis]
		out[axis] = (lo + hi) * 0.5 if lo > hi else clampf(p[axis], lo, hi)
	return out


func set_bounds(rect: Rect2) -> void:
	_bounds = rect
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)
