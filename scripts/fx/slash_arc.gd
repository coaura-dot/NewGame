extends Node2D
## Arco de corte procedural (cores HDR > 1 geram bloom). Também desenha
## estocadas (thrust). Criado por FX.slash().

const DURATION := 0.12

var facing: int = 1
var arc_deg: float = 150.0 ## sinal = sentido do corte
var radius: float = 40.0
var color: Color = Color(2.2, 2.2, 2.6)
var thrust: bool = false
var _t: float = 0.0


func _ready() -> void:
	scale.x = facing
	z_index = 30
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var p := clampf(_t / DURATION, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.3, 1.0, p)
	var c := Color(color.r, color.g, color.b, alpha)
	if thrust:
		var length := radius * (0.55 + 0.45 * minf(p * 4.0, 1.0))
		var w := 1.5 * (1.0 - p)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, 0), Vector2(0, -w), Vector2(length, 0), Vector2(0, w)]), c)
		draw_line(Vector2(0, 0), Vector2(length * 1.1, 0), Color(c.r, c.g, c.b, alpha * 0.5), 1.0)
		return
	var sweep := deg_to_rad(absf(arc_deg))
	var dir := signf(arc_deg) if arc_deg != 0.0 else 1.0
	var a0 := -sweep * 0.5 * dir
	var head_p := ease(minf(p * 2.6, 1.0), 0.4)
	var a_head := a0 + sweep * dir * head_p
	var tail_p := clampf((p - 0.25) * 1.6, 0.0, 1.0)
	var a_tail := a0 + sweep * dir * tail_p * head_p
	var n := 14
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var max_w := clampf(radius * 0.3, 1.5, 5.0) * (1.0 - p * 0.6)
	for i in range(n + 1):
		var f := float(i) / n
		var a := lerpf(a_tail, a_head, f)
		var w := max_w * pow(f, 0.8)
		outer.append(Vector2.from_angle(a) * radius)
		inner.append(Vector2.from_angle(a) * (radius - w))
	inner.reverse()
	var poly := outer + inner
	if poly.size() >= 3:
		draw_colored_polygon(poly, c)
	# fio brilhante na borda
	if outer.size() >= 2:
		draw_polyline(outer, Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, alpha), 1.0)
