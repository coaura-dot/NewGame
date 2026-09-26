extends Node2D
## Arco de corte (estilo Hollow Knight): uma meia-lua que varre rápido e some.
## Cor HDR (> 1) => brilha com bloom. Também desenha estocadas (thrust).

const DURATION := 0.12

var facing: int = 1
var arc_deg: float = 150.0 ## sinal = sentido do corte
var radius: float = 14.0
var width: float = 3.0
var color: Color = Color(2.0, 2.0, 2.3)
var thrust: bool = false
var _t: float = 0.0


func _ready() -> void:
	scale.x = facing
	z_index = 30


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var p := clampf(_t / DURATION, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.45, 1.0, p)
	var c := Color(color.r, color.g, color.b, alpha)
	if thrust:
		var length := radius * (0.5 + 0.5 * minf(p * 5.0, 1.0))
		var w := maxf(width * 0.6 * (1.0 - p), 0.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, 0), Vector2(1, -w), Vector2(length, 0), Vector2(1, w)]), c)
		return
	var sweep := deg_to_rad(absf(arc_deg))
	var dir := signf(arc_deg) if arc_deg != 0.0 else 1.0
	var a0 := -sweep * 0.5 * dir
	var head_p := ease(minf(p * 3.2, 1.0), 0.35)
	var a_head := a0 + sweep * dir * head_p
	var tail_p := clampf((p - 0.2) * 1.8, 0.0, 1.0)
	var a_tail := a0 + sweep * dir * tail_p * head_p
	var n := 12
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var max_w := width * (1.0 - p * 0.5)
	for i in range(n + 1):
		var f := float(i) / n
		var a := lerpf(a_tail, a_head, f)
		var w := max_w * sin(f * PI * 0.5 + 0.35)
		outer.append(Vector2.from_angle(a) * radius)
		inner.append(Vector2.from_angle(a) * maxf(radius - w, 1.0))
	inner.reverse()
	var poly := outer + inner
	if poly.size() >= 3:
		draw_colored_polygon(poly, c)
	if outer.size() >= 2:
		draw_polyline(outer, Color(minf(c.r * 1.3, 4.0), minf(c.g * 1.3, 4.0), minf(c.b * 1.3, 4.0), alpha), 1.0)
