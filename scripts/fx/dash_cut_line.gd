class_name DashCutLine
extends Node2D
## Rastro do Corte-Relâmpago: uma linha branca fina do início ao fim do dash
## que brilha e se fecha rápido (tipo corte de iaido). Mais grossa quando o
## corte acertou alguém.

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var hits: int = 0
var _start: int = -1
var _life: float = 0.22


func _ready() -> void:
	z_index = 44
	if hits > 0:
		_life = 0.3


func _process(_delta: float) -> void:
	if _start < 0:
		_start = Time.get_ticks_msec()
	var t := (Time.get_ticks_msec() - _start) / 1000.0
	if t >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := (Time.get_ticks_msec() - maxi(_start, 0)) / 1000.0
	var k := clampf(t / _life, 0.0, 1.0)
	# a linha "fecha" do começo para o fim
	var a := from.lerp(to, k * k)
	var w := 2.0 if hits > 0 else 1.0
	var c := Color(3.0, 3.0, 3.2, 1.0 - k * 0.5)
	draw_line(a, to, c, w)
	if hits > 0 and k < 0.5:
		# brilho extra: segunda linha paralela ciano
		var n := (to - from).normalized().orthogonal()
		draw_line(a + n, to + n, Color(1.0, 2.6, 3.0, 0.6 - k), 1.0)
