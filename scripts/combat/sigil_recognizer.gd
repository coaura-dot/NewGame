class_name SigilRecognizer
extends RefCounted
## Reconhecedor de sigilos desenhados com o mouse (variação do "$1 Unistroke
## Recognizer"). Retorna o nome do sigilo e a PRECISÃO (0..1), que escala o
## dano da magia. Sensível à orientação (um raio em zigue-zague deitado não
## vale), mas aceita desenhar em qualquer sentido.

const N := 64
const SIZE := 250.0
const MIN_ACCURACY := 0.55

static var _templates: Dictionary = {}


static func templates() -> Dictionary:
	if _templates.is_empty():
		_templates = {
			"circle": _circle(),
			"triangle": _poly([Vector2(0, -1), Vector2(0.9, 0.7), Vector2(-0.9, 0.7), Vector2(0, -1)]),
			"zigzag": _poly([Vector2(-0.5, -1), Vector2(0.5, -0.35), Vector2(-0.5, 0.3), Vector2(0.5, 1)]),
			"spiral": _spiral(),
			"v": _poly([Vector2(-0.8, -1), Vector2(0, 1), Vector2(0.8, -1)]),
		}
	return _templates


## Pontos de referência (normalizados) para desenhar a dica na tela.
static func guide_points(name: String) -> PackedVector2Array:
	return templates().get(name, PackedVector2Array())


static func recognize(points: PackedVector2Array) -> Dictionary:
	if points.size() < 8:
		return {"name": "", "accuracy": 0.0}
	var candidate := normalize(points)
	var best := ""
	var best_d := INF
	for name in templates().keys():
		var t: PackedVector2Array = normalize(templates()[name])
		var d := minf(_path_distance(candidate, t), _path_distance(candidate, _reversed(t)))
		if d < best_d:
			best_d = d
			best = name
	var half_diag := 0.5 * sqrt(2.0 * SIZE * SIZE)
	var accuracy := clampf(1.0 - best_d / (half_diag * 0.55), 0.0, 1.0)
	return {"name": best if accuracy >= MIN_ACCURACY else "", "raw": best, "accuracy": accuracy}


## Multiplicador de dano a partir da precisão (0.55 -> 0.75x, 1.0 -> 1.5x).
static func power_from_accuracy(acc: float) -> float:
	return lerpf(0.75, 1.5, clampf((acc - MIN_ACCURACY) / (1.0 - MIN_ACCURACY), 0.0, 1.0))


static func normalize(points: PackedVector2Array) -> PackedVector2Array:
	var pts := _resample(points, N)
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	var s := maxf(box.size.x, box.size.y)
	if s <= 0.0001:
		s = 1.0
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var out := PackedVector2Array()
	for p in pts:
		out.append((p - c) * (SIZE / s))
	return out


static func _resample(points: PackedVector2Array, n: int) -> PackedVector2Array:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var interval := total / (n - 1)
	if interval <= 0.0:
		var same := PackedVector2Array()
		for i in n:
			same.append(points[0])
		return same
	var src := points.duplicate()
	var out := PackedVector2Array([src[0]])
	var acc := 0.0
	var i := 1
	while i < src.size():
		var d := src[i - 1].distance_to(src[i])
		if acc + d >= interval and d > 0.0:
			var q := src[i - 1] + (src[i] - src[i - 1]) * ((interval - acc) / d)
			out.append(q)
			src.insert(i, q)
			acc = 0.0
		else:
			acc += d
		i += 1
	while out.size() < n:
		out.append(src[src.size() - 1])
	return out


static func _path_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var d := 0.0
	for i in mini(a.size(), b.size()):
		d += a[i].distance_to(b[i])
	return d / mini(a.size(), b.size())


static func _reversed(p: PackedVector2Array) -> PackedVector2Array:
	var r := p.duplicate()
	r.reverse()
	return r


static func _circle() -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 33:
		p.append(Vector2.from_angle(-PI * 0.5 + TAU * i / 32.0))
	return p


static func _spiral() -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 49:
		var t := float(i) / 48.0
		p.append(Vector2.from_angle(t * TAU * 2.0) * (0.15 + 0.85 * t))
	return p


static func _poly(verts: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in range(verts.size() - 1):
		for k in 16:
			p.append(verts[i].lerp(verts[i + 1], k / 16.0))
	p.append(verts[-1])
	return p
