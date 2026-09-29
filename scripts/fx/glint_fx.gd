extends Node2D
## Brilho na arma logo antes do golpe (telegrafia estilo Dead Cells): estrela
## de 4 pontas que cresce e some. Amarelo = dá para aparar; vermelho = esquive.

var color: Color = Color(3.0, 2.6, 0.6)
var _t: float = 0.0
const LIFE := 0.18


func _ready() -> void:
	z_index = 47


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var k := _t / LIFE
	var arm := roundf(6.0 * sin(k * PI))
	var c := Color(color.r, color.g, color.b, 1.0 - k * 0.5)
	var hot := Color(3.2, 3.2, 3.0, c.a)
	draw_rect(Rect2(-arm, 0, arm * 2.0 + 1.0, 1), c)
	draw_rect(Rect2(0, -arm, 1, arm * 2.0 + 1.0), c)
	if arm >= 3.0:
		draw_rect(Rect2(-1, -1, 3, 3), Color(c.r, c.g, c.b, c.a * 0.6))
	draw_rect(Rect2(0, 0, 1, 1), hot)
