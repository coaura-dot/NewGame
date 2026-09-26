extends Node2D
## Punhado de partículas de 1 px (faíscas, poeira, lascas). Leve e sem GPU.

var _p: Array = [] ## [pos, vel, life, max_life, size]
var _color: Color = Color.WHITE
var _gravity: float = 200.0


func setup(color: Color, amount: int, speed: float, dir: Vector2, spread_deg: float, lifetime: float, size: float, gravity: float = 200.0) -> void:
	_color = color
	_gravity = gravity
	var base_angle := dir.angle() if dir != Vector2.ZERO else 0.0
	var spread := deg_to_rad(spread_deg)
	for i in amount:
		var a := base_angle + randf_range(-spread, spread) if dir != Vector2.ZERO else randf() * TAU
		var v := Vector2.from_angle(a) * speed * randf_range(0.4, 1.0)
		var life := lifetime * randf_range(0.6, 1.0)
		_p.append([Vector2.ZERO, v, life, life, size])


func _ready() -> void:
	z_index = 40


func _process(delta: float) -> void:
	var alive := false
	for p in _p:
		if p[2] <= 0.0:
			continue
		alive = true
		p[1].y += _gravity * delta
		p[1] *= 1.0 - 3.0 * delta
		p[0] += p[1] * delta
		p[2] -= delta
	queue_redraw()
	if not alive:
		queue_free()


func _draw() -> void:
	for p in _p:
		if p[2] <= 0.0:
			continue
		var f: float = p[2] / p[3]
		var s: float = p[4] if f > 0.4 else 1.0
		draw_rect(Rect2(p[0].round(), Vector2(s, s)), Color(_color.r, _color.g, _color.b, _color.a * (0.5 + 0.5 * f)))
