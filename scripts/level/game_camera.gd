class_name GameCamera
extends Camera2D
## Câmera no estilo Celeste: cada sala (40x24 tiles = 320x192 px) cabe numa
## tela, então a câmera fica TRAVADA na sala atual e só desliza até a
## próxima quando o jogador troca de sala. Dentro da sala ela segue o
## jogador no que sobra (12 px na vertical) com um leve olhar à frente.
## Também aplica o tremor de tela do FX.

const VIEW := Vector2(320.0, 180.0)
const FOLLOW_RATE := 9.0
const TRANSITION_RATE := 11.0
const TRANSITION_TIME := 0.35

var target: Node2D = null
var look_ahead: float = 16.0
var screen_velocity: Vector2 = Vector2.ZERO ## usado pelo motion blur
## Área em que a câmera pode andar (sala atual). Vazio = a fase inteira.
var room_rect: Rect2 = Rect2()
var transitioning: float = 0.0
var _look: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _pos: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()


func _ready() -> void:
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	FX.camera = self
	if target:
		_pos = target.global_position
		global_position = _pos
		_last_pos = _pos


func snap() -> void:
	if target:
		_look = Vector2.ZERO
		_pos = _clamp_view(target.global_position + Vector2(0, -8))
		global_position = _pos
		transitioning = 0.0
		reset_physics_interpolation()


## Troca a sala em que a câmera está presa. `instant` pula a transição.
func set_room(rect: Rect2, instant: bool = false) -> void:
	if rect == room_rect:
		return
	var had_room := room_rect.has_area()
	room_rect = rect
	if instant or not had_room:
		snap()
	else:
		transitioning = TRANSITION_TIME


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var v: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
	var want_look := Vector2(clampf(v.x * 0.2, -look_ahead, look_ahead), clampf(v.y * 0.06, -8.0, 16.0))
	if "facing" in target and absf(v.x) < 30.0:
		want_look.x = target.facing * look_ahead * 0.35
	_look = _look.lerp(want_look, 1.0 - exp(-delta * 3.0))
	var desired := _clamp_view(target.global_position + Vector2(0, -8) + _look)
	var rate := FOLLOW_RATE
	if transitioning > 0.0:
		transitioning -= delta
		rate = TRANSITION_RATE
	_pos = _pos.lerp(desired, 1.0 - exp(-delta * rate))
	global_position = _pos
	offset = FX.shake_offset
	var screen := get_screen_center_position()
	screen_velocity = (screen - _last_pos) / maxf(delta, 0.0001)
	_last_pos = screen


## Centro de câmera mais próximo de `p` que mantém a tela dentro da sala
## (ou da fase, se não houver sala). Sala menor que a tela = centraliza.
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
