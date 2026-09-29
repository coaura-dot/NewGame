extends Node2D
## Anel que se expande e some (dash, chute de parede, quique, explosões).
## Desenhado em pixels (círculo de pontos), cor HDR = brilha com bloom.

var color: Color = Color(2.2, 2.0, 1.8)
var radius: float = 10.0
var life: float = 0.22
var width: float = 1.0
var squash: Vector2 = Vector2.ONE ## elipse (ex.: anel achatado no chão)
var _t: float = 0.0


func _ready() -> void:
	z_index = 44


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= life:
		queue_free()


func _draw() -> void:
	var k := _t / life
	var r := radius * (0.25 + 0.75 * (1.0 - pow(1.0 - k, 3.0)))
	var a := 1.0 - k
	var c := Color(color.r, color.g, color.b, color.a * a)
	var n := int(clampf(r * 1.6, 8.0, 48.0))
	for i in n:
		var ang := TAU * i / n
		var p := Vector2(cos(ang) * r * squash.x, sin(ang) * r * squash.y).round()
		draw_rect(Rect2(p, Vector2(width, width)), c)
