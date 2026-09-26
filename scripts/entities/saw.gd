class_name Saw
extends Hazard
## Serra giratória (pixel art procedural). Pode oscilar entre dois pontos.

var travel: Vector2 = Vector2.ZERO
var period: float = 2.5
var _origin: Vector2
var _t: float = 0.0
const R := 6.0


func _ready() -> void:
	damage = 20.0
	pogoable = true
	add_circle(Vector2.ZERO, R - 1.0)
	_origin = position
	_t = randf() * period
	z_index = 4


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_t += delta
	if travel != Vector2.ZERO:
		position = (_origin + travel * (0.5 - 0.5 * cos(_t / period * TAU))).round()
	queue_redraw()


func _draw() -> void:
	if travel != Vector2.ZERO:
		var a := (_origin - position).round()
		var b := (_origin + travel - position).round()
		draw_line(a, b, Color(0.25, 0.22, 0.32, 0.8), 1.0)
	var ink := Color(0.106, 0.082, 0.157)
	draw_circle(Vector2.ZERO, R + 1.0, ink)
	draw_circle(Vector2.ZERO, R, Color(0.78, 0.8, 0.86))
	var rot := _t * 14.0
	for i in 8:
		var ang := rot + i * TAU / 8.0
		var tip := Vector2.from_angle(ang) * (R + 2.0)
		draw_line(Vector2.from_angle(ang) * (R - 1.0), tip, ink if i % 2 else Color(0.9, 0.92, 0.98), 1.0)
	draw_circle(Vector2.ZERO, 2.0, Color(0.45, 0.45, 0.52))
	draw_rect(Rect2(-1, -1, 2, 2), ink)
