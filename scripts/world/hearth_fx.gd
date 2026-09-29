class_name HearthFX
extends Node2D
## A Grande Lareira: cinzas frias com uma brasinha teimosa no começo; cada
## chefe derrotado devolve brasas e o fogo cresce até ela reacender por inteiro.

var embers: float = 0.0 ## 0..1
var _t: float = 0.0
var _sparks: Array = []


func _ready() -> void:
	z_index = 41


func _process(delta: float) -> void:
	_t += delta
	if randf() < delta * (2.0 + embers * 18.0):
		_sparks.append([Vector2(randf_range(-10, 10) * (0.3 + embers), 0), randf_range(0.6, 1.4)])
	for s in _sparks:
		s[0] += Vector2(sin(_t * 4.0 + s[1] * 9.0) * 6.0, -16.0 - embers * 14.0) * delta
		s[1] -= delta
	_sparks = _sparks.filter(func(s): return s[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	# brasas no fundo da bacia
	var n := 2 + int(embers * 10.0)
	for i in n:
		var x := -12.0 + 24.0 * float(i) / maxf(n - 1, 1)
		var c := Color(2.2, 0.6, 0.15) if int(_t * 3.0 + i) % 3 else Color(2.8, 1.4, 0.3)
		draw_rect(Rect2(roundf(x * (0.3 + embers * 0.7)), roundf(sin(i * 1.7) * 1.5), 2, 1), c)
	# chamas (crescem com o poder)
	var flames := int(embers * 7.0)
	for i in flames:
		var fx := roundf((float(i) - flames * 0.5) * 3.0)
		var h := int(round(4.0 + embers * 8.0 + sin(_t * 11.0 + i * 2.0) * 2.0))
		for k in h:
			var t := float(k) / maxf(h - 1, 1)
			var c := Color(3.0, 2.6, 1.4) if t < 0.3 else (Color(2.8, 1.6, 0.4) if t < 0.7 else Color(2.2, 0.6, 0.2))
			var w := 3 if t < 0.5 else 1
			draw_rect(Rect2(fx - (w - 1) / 2 + roundf(sin(_t * 7.0 + i + t * 3.0) * t * 1.5), -k, w, 1), c)
	for s in _sparks:
		draw_rect(Rect2((s[0] as Vector2).round(), Vector2(1, 1)), Color(2.8, 1.5, 0.4, clampf(s[1], 0.0, 1.0)))
