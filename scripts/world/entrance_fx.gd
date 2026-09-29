class_name EntranceFX
extends Node2D
## Efeitos das entradas de fase no mapa-múndi: tochas acesas no portão de
## pedra, feixe de luz subindo da plataforma celeste, redemoinho da fenda
## dimensional e uma estrelinha pulsando quando a região ainda não foi limpa.

var kind: String = "entrance_gate"
var color: Color = Color(2.4, 1.4, 0.6)
var cleared: bool = false
var _t: float = 0.0


func _ready() -> void:
	z_index = 40
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _flame(at: Vector2, s: float) -> void:
	var h := int(round(3.0 * s + sin(_t * 17.0 + at.x) * 0.8))
	for i in h:
		var k := float(i) / maxf(h - 1, 1)
		var c := Color(2.8, 1.9, 0.55) if k < 0.5 else Color(2.2, 0.72, 0.2)
		var dx := roundf(sin(_t * 9.0 + at.x) * k)
		draw_rect(Rect2(at.x + dx - (1 if i == 1 else 0), at.y - i, 1 + (2 if i == 1 else 0), 1), c)


func _draw() -> void:
	match kind:
		"entrance_gate":
			_flame(Vector2(-11, -17), 1.0)
			_flame(Vector2(10, -17), 1.0)
		"entrance_sky":
			# feixe de luz subindo
			for i in 18:
				var a := 0.28 * (1.0 - i / 18.0) * (0.8 + 0.2 * sin(_t * 3.0 + i * 0.5))
				draw_rect(Rect2(-3, -8 - i * 3, 7, 3), Color(2.4, 2.2, 1.4, a))
				draw_rect(Rect2(-1, -8 - i * 3, 3, 3), Color(3.0, 2.8, 2.0, a * 1.4))
			for i in 4:
				var y := -8.0 - fmod(_t * 18.0 + i * 13.0, 50.0)
				draw_rect(Rect2(roundf(sin(_t * 2.0 + i) * 3.0), y, 1, 1), Color(3.0, 2.8, 2.0, 0.8))
		"entrance_rift":
			# redemoinho: elipses girando
			for i in 3:
				var r := 5.0 + i * 2.0
				var n := 14
				for k in n:
					var ang := TAU * k / n + _t * (2.0 - i * 0.5)
					var p := Vector2(cos(ang) * r, sin(ang) * r * 1.6) + Vector2(0, -12)
					draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(2.2, 0.8, 2.8, 0.9 - i * 0.2))
			draw_rect(Rect2(-1, -14, 3, 4), Color(0.1, 0.02, 0.2, 0.9))
		"entrance_cave":
			pass
	if not cleared:
		# marcador: estrela sobre a entrada (pulsa)
		var y := -34.0 + sin(_t * 3.0) * 2.0
		if kind == "entrance_cave":
			y = -28.0 + sin(_t * 3.0) * 2.0
		elif kind == "entrance_sky":
			y = -20.0 + sin(_t * 3.0) * 2.0
		var arm := 2.0 + (1.0 if sin(_t * 6.0) > 0.0 else 0.0)
		var c := color
		draw_rect(Rect2(-arm, y, arm * 2.0 + 1.0, 1), c)
		draw_rect(Rect2(0, y - arm, 1, arm * 2.0 + 1.0), c)
		draw_rect(Rect2(0, y, 1, 1), Color(3, 3, 3))
