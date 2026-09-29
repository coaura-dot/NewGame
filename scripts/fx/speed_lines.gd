extends Node2D
## Riscos de velocidade (dash, chute de parede): traços curtos que ficam para
## trás na direção oposta ao movimento e somem rápido.

var dir: Vector2 = Vector2.RIGHT
var color: Color = Color(2.0, 2.0, 2.4, 0.9)
var count: int = 5
var length: float = 10.0
var _lines: Array = [] ## [offset, len]
var _t: float = 0.0
const LIFE := 0.16


func _ready() -> void:
	z_index = 30
	var side := Vector2(-dir.y, dir.x)
	for i in count:
		var off := side * randf_range(-6.0, 6.0) - dir * randf_range(0.0, 8.0) + Vector2(0, -6)
		_lines.append([off, length * randf_range(0.5, 1.0)])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var k := 1.0 - _t / LIFE
	for l in _lines:
		var a: Vector2 = l[0] - dir * _t * 60.0
		var b: Vector2 = a - dir * float(l[1]) * k
		draw_line(a.round(), b.round(), Color(color.r, color.g, color.b, color.a * k), 1.0)
