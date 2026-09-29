extends Node2D
## Marca de corte no alvo (estilo Hollow Knight): um risco branco e fino que
## atravessa o ponto de impacto na direção do golpe e afina até sumir.

var dir: Vector2 = Vector2.RIGHT
var color: Color = Color(3.0, 3.0, 3.0)
var length: float = 16.0
var width: float = 2.0
var _t: float = 0.0
const LIFE := 0.1


func _ready() -> void:
	z_index = 46


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var k := 1.0 - _t / LIFE
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	# cresce rápido nos primeiros quadros e depois só afina
	var grow := minf(_t / (LIFE * 0.3), 1.0)
	var half := length * 0.5 * (0.5 + 0.5 * grow)
	var a := (-d * half).round()
	var b := (d * half).round()
	var w := maxf(roundf(width * k), 1.0)
	draw_line(a, b, Color(color.r * 0.7, color.g * 0.7, color.b * 0.8, k * 0.6), w + 2.0)
	draw_line(a, b, Color(color.r, color.g, color.b, k), w)
