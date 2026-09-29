class_name GustShot
extends Projectile
## Rajada do Sopro: um redemoinho de vento frio que anda devagar, EMPURRA o
## herói forte (cuidado com espinhos) e esfria. Golpear rebate de volta no
## Sopro, como as balas das torretas.

func _ready() -> void:
	super._ready()
	light_enabled = false


func _draw() -> void:
	var t := _anim_t
	var inv := get_global_transform().affine_inverse()
	for i in _trail.size():
		var f := 1.0 - float(i) / _trail.size()
		var p: Vector2 = (inv * _trail[i]).round()
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(color.r, color.g, color.b, 0.25 * f))
	# três arcos girando (redemoinho) + miolo claro
	for k in 3:
		var r := radius * (0.5 + 0.25 * k)
		var n := 8
		for j in n:
			var a := TAU * j / n + t * (9.0 - k * 2.0) + k
			if j % 2 == 0:
				continue
			draw_rect(Rect2((Vector2(cos(a), sin(a) * 0.7) * r).round(), Vector2(1, 1)), Color(color.r, color.g, color.b, 0.85 - k * 0.2))
	draw_rect(Rect2(-1, -1, 2, 2), Color(2.4, 2.8, 3.0, 0.9))
