class_name Saw
extends Hazard
## Serra giratória. Pode oscilar entre dois pontos.

var travel: Vector2 = Vector2.ZERO
var period: float = 2.5
var _origin: Vector2
var _t: float = 0.0


func _ready() -> void:
	damage = 20.0
	pogoable = true
	add_circle(Vector2.ZERO, 5.0)
	_origin = position
	_t = randf() * period
	z_index = 4


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_t += delta
	if travel != Vector2.ZERO:
		position = _origin + travel * (0.5 - 0.5 * cos(_t / period * TAU))
	queue_redraw()


func _draw() -> void:
	if travel != Vector2.ZERO:
		draw_line(_origin - position, _origin + travel - position, Color(0.3, 0.3, 0.35, 0.6), 1.0)
	var rot := _t * 14.0
	for i in 8:
		var a := rot + i * TAU / 8.0
		draw_rect(Rect2(Vector2.from_angle(a) * 5.0 - Vector2(0.5, 0.5), Vector2(2, 2)), Color(0.85, 0.85, 0.9))
	draw_circle(Vector2.ZERO, 4.0, Color(0.55, 0.55, 0.62))
	draw_circle(Vector2.ZERO, 1.5, Color(0.2, 0.2, 0.25))
