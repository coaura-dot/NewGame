class_name GameCamera
extends Camera2D
## Câmera que segue o jogador com antecipação (olha para onde ele vai),
## respeita os limites da fase e aplica o tremor de tela do FX.

var target: Node2D = null
var look_ahead: float = 36.0
var screen_velocity: Vector2 = Vector2.ZERO ## usado pelo motion blur
var _look: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _pos: Vector2 = Vector2.ZERO


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
		_pos = target.global_position + Vector2(0, -30)
		global_position = _pos
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var v: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
	var want_look := Vector2(clampf(v.x * 0.22, -look_ahead, look_ahead), clampf(v.y * 0.08, -20.0, 36.0))
	if "facing" in target and absf(v.x) < 30.0:
		want_look.x = target.facing * look_ahead * 0.35
	_look = _look.lerp(want_look, 1.0 - exp(-delta * 3.0))
	var desired: Vector2 = target.global_position + Vector2(0, -30) + _look
	_pos = _pos.lerp(desired, 1.0 - exp(-delta * 9.0))
	global_position = _pos
	offset = FX.shake_offset
	var screen := get_screen_center_position()
	screen_velocity = (screen - _last_pos) / maxf(delta, 0.0001)
	_last_pos = screen


func set_bounds(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)
