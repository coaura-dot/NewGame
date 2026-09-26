class_name Saw
extends Hazard
## Serra giratória. Pode oscilar entre dois pontos.

const TEX := preload("res://assets/art/props/traps/saw_on.png")

var travel: Vector2 = Vector2.ZERO
var period: float = 2.5
var _origin: Vector2
var _t: float = 0.0


func _ready() -> void:
	damage = 20.0
	pogoable = true
	add_circle(Vector2.ZERO, 15.0)
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
		draw_line(_origin - position, _origin + travel - position, Color(0.3, 0.3, 0.35, 0.8), 2.0)
	var frame := int(_t * 20.0) % 8
	draw_texture_rect_region(TEX, Rect2(-19, -19, 38, 38), Rect2(frame * 38, 0, 38, 38))
