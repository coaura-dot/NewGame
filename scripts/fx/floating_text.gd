extends Node2D
## Texto curto flutuando no mundo (fonte pixel 1x, nítida em 320x180).

const FONT := preload("res://assets/fonts/kenney_mini.ttf")

var text: String = ""
var color: Color = Color(1, 1, 1)
var small: bool = false
var big: bool = false ## compatibilidade
var _t: float = 0.0
var _vel: Vector2 = Vector2(0, -26)


func _ready() -> void:
	z_index = 60
	_vel.x = randf_range(-6, 6) if small else 0.0


func _process(delta: float) -> void:
	_t += delta
	_vel.y += (60.0 if small else 20.0) * delta
	position += _vel * delta
	queue_redraw()
	if _t > (0.6 if small else 1.1):
		queue_free()


func _draw() -> void:
	var life := 0.6 if small else 1.1
	var a := 1.0 - smoothstep(life * 0.6, life, _t)
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var pos := Vector2(roundf(-w * 0.5), 0)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(FONT, pos + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.07, 0.05, 0.12, a))
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(color.r, color.g, color.b, a))
