class_name GameCamera
extends Node2D
## Câmera estilo Celeste: fica presa à sala atual (e desliza até a próxima
## quando o jogador atravessa), segue o jogador com uma leve antecipação e
## aplica o tremor de tela. Não é uma Camera2D: o PixelView lê
## render_center() e posiciona o mundo em pixels inteiros + fração suave.

const VIEW := Vector2(320, 180)

var target: Node2D = null
var bounds: Rect2 = Rect2() ## limites da fase inteira
var room_rect: Rect2 = Rect2() ## sala atual (trava da câmera)
var room_lock: bool = true
var center: Vector2 = Vector2.ZERO
var screen_velocity: Vector2 = Vector2.ZERO
var follow_rate: float = 9.0
var look_ahead: float = 24.0
var _prev: Vector2 = Vector2.ZERO
var _look: Vector2 = Vector2.ZERO
var _room_changed_t: float = 0.0


func _ready() -> void:
	process_physics_priority = 50 ## depois do jogador se mover
	FX.camera = self
	if target:
		snap()


func set_bounds(rect: Rect2) -> void:
	bounds = rect


func set_room(rect: Rect2) -> void:
	if rect == room_rect:
		return
	room_rect = rect
	_room_changed_t = 0.45


func snap() -> void:
	_look = Vector2.ZERO
	center = _desired()
	_prev = center


func _desired() -> Vector2:
	var p: Vector2 = target.global_position + Vector2(0, -10) + _look if target and is_instance_valid(target) else center
	var r := room_rect if room_lock and room_rect.size != Vector2.ZERO else bounds
	if r.size != Vector2.ZERO:
		p = _clamp_to(p, r)
	if bounds.size != Vector2.ZERO:
		p = _clamp_to(p, bounds)
	return p


static func _clamp_to(p: Vector2, r: Rect2) -> Vector2:
	var half := VIEW * 0.5
	if r.size.x <= VIEW.x:
		p.x = r.get_center().x
	else:
		p.x = clampf(p.x, r.position.x + half.x, r.end.x - half.x)
	if r.size.y <= VIEW.y:
		p.y = r.get_center().y
	else:
		p.y = clampf(p.y, r.position.y + half.y, r.end.y - half.y)
	return p


func _physics_process(delta: float) -> void:
	_prev = center
	if target and is_instance_valid(target):
		var v: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
		var want := Vector2(clampf(v.x * 0.18, -look_ahead, look_ahead), clampf(v.y * 0.06, -12.0, 18.0))
		_look = _look.lerp(want, 1.0 - exp(-delta * 2.5))
	var rate := follow_rate
	_room_changed_t = maxf(_room_changed_t - delta, 0.0)
	if _room_changed_t > 0.0:
		rate = 7.0
	center = center.lerp(_desired(), 1.0 - exp(-delta * rate))
	screen_velocity = (center - _prev) / maxf(delta, 0.0001)


## Centro da tela para este quadro (interpolado entre tiques de física).
func render_center() -> Vector2:
	var f := Engine.get_physics_interpolation_fraction()
	return _prev.lerp(center, f) + FX.shake_offset


## Compatível com o antigo uso de Camera2D.
func get_screen_center_position() -> Vector2:
	return render_center()


func in_transition() -> bool:
	return _room_changed_t > 0.0
