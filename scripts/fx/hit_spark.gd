extends Node2D
## Clarão de impacto: estrela de 4 pontas + risco na direção do golpe.
## Dura poucos quadros, cor HDR (brilha com bloom). Criado por FX.hit_spark().

var dir: Vector2 = Vector2.RIGHT
var color: Color = Color(2.2, 2.1, 1.9)
var big: bool = false
var _t: float = 0.0
const LIFE := 0.12


func _ready() -> void:
	z_index = 45
	rotation = randf_range(-0.3, 0.3)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var k := 1.0 - _t / LIFE
	var r := (6.0 if big else 4.0) * (0.6 + 0.8 * (1.0 - k))
	var c := Color(color.r, color.g, color.b, k)
	var w := 1.0 + (1.0 if big and k > 0.5 else 0.0)
	draw_line(Vector2(-r, 0), Vector2(r, 0), c, w)
	draw_line(Vector2(0, -r), Vector2(0, r), c, w)
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	draw_line(-d * r * 1.6, d * r * 2.2, Color(c.r, c.g, c.b, k * 0.8), 1.0)
	draw_rect(Rect2(-1, -1, 2, 2), Color(3, 3, 3, k))
