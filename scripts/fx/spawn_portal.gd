class_name SpawnPortal
extends Node2D
## Portal de invocação das ondas: uma fenda vertical que abre, brilha e fecha
## (≈0,6 s). Avisa onde o próximo inimigo vai aparecer.

var height: float = 14.0
var color: Color = Color(2.4, 0.7, 1.6)
var _t: float = 0.0
const LIFE := 0.7


func _ready() -> void:
	z_index = 20
	var l := LightUtil.make_light(Color(1.0, 0.4, 0.8), 0.9, 0.35)
	if l:
		l.position = Vector2(0, -height * 0.5)
		add_child(l)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var open := sin(k * PI)
	var w := roundf(1.0 + open * 5.0)
	var h := height * (0.4 + open * 0.8)
	var c := Color(color.r, color.g, color.b, 0.9)
	draw_rect(Rect2(-w * 0.5, -h, w, h), Color(0.08, 0.02, 0.1, 0.9))
	draw_rect(Rect2(-w * 0.5, -h, w, h), c, false, 1.0)
	draw_line(Vector2(0, -h - 2), Vector2(0, 1), Color(3, 3, 3, open), 1.0)
