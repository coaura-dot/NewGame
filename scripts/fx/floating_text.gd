extends Node2D
## Número de dano / texto flutuante.

const FONT := preload("res://assets/fonts/kenney_mini.ttf")

var text: String = ""
var color: Color = Color(1, 1, 1)
var big: bool = false
var _t: float = 0.0
var _vel: Vector2 = Vector2(0, -35)


func _ready() -> void:
	z_index = 60
	_vel.x = randf_range(-10, 10)


func _process(delta: float) -> void:
	_t += delta
	_vel.y += 70.0 * delta
	position += _vel * delta
	queue_redraw()
	if _t > 0.75:
		queue_free()


func _draw() -> void:
	var size := 8
	var a := 1.0 - smoothstep(0.45, 0.75, _t)
	var s := 1.0 + (0.4 if big else 0.2) * (1.0 - minf(_t * 8.0, 1.0))
	# letras de 8 px ampliadas 2x na TELA (independe do zoom do mundo)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s) * (2.0 / LevelConst.ART))
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-w * 0.5, 0)
	draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0.05, 0.02, 0.08, a))
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.r, color.g, color.b, a))
