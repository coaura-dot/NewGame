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
var _sparks: Array = [] ## faíscas que escapam da ponta: [fração do arco, velocidade, atraso]


func _ready() -> void:
	scale.x = facing
	z_index = 30
	if not thrust:
		for i in 3:
			_sparks.append([randf_range(0.55, 1.0), randf_range(45.0, 90.0), randf_range(0.0, 0.035)])


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
		draw_line(Vector2(length - 3.0, 0), Vector2(length + 2.0, 0), Color(3.0, 3.0, 3.0, alpha), 1.0)
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
	# corpo em gradiente: cauda transparente e tingida, ponta cheia e clara
	var white := Color(minf(c.r * 1.25 + 0.4, 4.0), minf(c.g * 1.25 + 0.4, 4.0), minf(c.b * 1.25 + 0.4, 4.0))
	for i in range(n):
		var f := (float(i) + 0.5) / n
		var seg := Color(c.r, c.g, c.b).lerp(white, f * f)
		seg.a = alpha * (0.2 + 0.8 * f)
		# draw_primitive não triangula: quads degenerados (início do golpe) não dão erro
		draw_primitive(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), PackedColorArray([seg, seg, seg, seg]), PackedVector2Array())
	# fio da lâmina (borda de fora) e o contorno de dentro, mais fraco
	draw_polyline(outer, Color(white.r, white.g, white.b, alpha), 1.0)
	var inner_line := PackedVector2Array(inner)
	draw_polyline(inner_line, Color(c.r, c.g, c.b, alpha * 0.35), 1.0)
	# faíscas que escapam pela tangente da ponta
	for sp in _sparks:
		var st: float = _t - float(sp[2])
		if st <= 0.0 or head_p < float(sp[0]):
			continue
		var a := a0 + sweep * dir * float(sp[0])
		var tangent := Vector2.from_angle(a + PI * 0.5 * dir)
		var at := Vector2.from_angle(a) * (radius + 1.0) + tangent * float(sp[1]) * st
		var k := clampf(1.0 - st / (DURATION * 0.9), 0.0, 1.0)
		draw_rect(Rect2(at.round(), Vector2(1, 1)), Color(white.r, white.g, white.b, k))
