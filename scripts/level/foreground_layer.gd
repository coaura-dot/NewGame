class_name ForegroundLayer
extends Node2D
## PRIMEIRO PLANO (estilo Hollow Knight): silhuetas escuras NA FRENTE da
## ação — capim, samambaias, pedras, raízes e correntes penduradas,
## estalactites — com parallax maior que 1 (passam mais rápido que o
## cenário, como se estivessem perto da "câmera"). Dá profundidade e
## moldura às cenas. Poucas e nas bordas (embaixo e em cima da tela), para
## não esconder o combate.
##
## Estilos: "cave" (pedras, estalactites, raízes), "forest" (samambaias,
## capim alto, cipós), "village" (capim seco, cercas, galhos), "ruins".

const T := LevelConst.TILE

var camera: Camera2D = null
var style: String = "cave"
var tint: Color = Color(0.02, 0.022, 0.03)
var _items: Array = [] ## [tipo, pos, k (parallax), tamanho, semente]
var _t: float = 0.0


func build(rows: PackedStringArray, style_id: String, seed_v: int, color: Color) -> void:
	style = style_id
	tint = color
	z_index = 60
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h := rows.size()
	var w: int = rows[0].length() if h > 0 else 0
	var last_floor := -99
	var last_ceil := -99
	for x in range(1, w - 1):
		for y in range(3, h - 2):
			var c := rows[y].unicode_at(x)
			if c != 35:
				continue
			# chão (sólido com 3 de ar em cima): capim / pedras / samambaias
			if rows[y - 1].unicode_at(x) != 35 and rows[y - 2].unicode_at(x) != 35 and rows[y - 3].unicode_at(x) != 35:
				if x - last_floor > 5 and rng.randf() < 0.14:
					last_floor = x
					var kinds := _floor_kinds()
					var kind: String = kinds[rng.randi() % kinds.size()]
					_items.append([kind, Vector2(x * T + rng.randf_range(0, T), y * T + 2.0), rng.randf_range(1.22, 1.5), rng.randf_range(0.8, 1.4), rng.randi()])
			# teto (sólido com 4 de ar embaixo): pendurados
			if y + 4 < h and rows[y + 1].unicode_at(x) != 35 and rows[y + 2].unicode_at(x) != 35 and rows[y + 3].unicode_at(x) != 35 and rows[y + 4].unicode_at(x) != 35:
				if x - last_ceil > 7 and rng.randf() < 0.1:
					last_ceil = x
					var hk := _hang_kinds()
					if not hk.is_empty():
						var kind2: String = hk[rng.randi() % hk.size()]
						_items.append([kind2, Vector2(x * T + rng.randf_range(0, T), (y + 1) * T - 2.0), rng.randf_range(1.18, 1.4), rng.randf_range(0.8, 1.5), rng.randi()])


func _floor_kinds() -> Array:
	match style:
		"forest":
			return ["fern", "grass", "grass", "fern", "rock"]
		"village":
			return ["dry_grass", "dry_grass", "rock", "post"]
		"ruins":
			return ["rock", "grass", "rubble"]
	return ["rock", "rock", "rubble", "grass"]


func _hang_kinds() -> Array:
	match style:
		"forest":
			return ["roots", "vine", "vine"]
		"village":
			return []
		"ruins":
			return ["chain", "roots"]
	return ["stalactite", "stalactite", "roots", "chain"]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	var cam := camera.get_screen_center_position()
	var view := Rect2(cam - LevelConst.VIEW * 0.5 - Vector2(60, 60), LevelConst.VIEW + Vector2(120, 120))
	for it in _items:
		var k: float = it[2]
		var p: Vector2 = cam + (it[1] - cam) * k
		if not view.has_point(p):
			continue
		_draw_item(str(it[0]), p, float(it[3]) * k, int(it[4]))


func _draw_item(kind: String, p: Vector2, s: float, sd: int) -> void:
	var c := tint
	var r := RandomNumberGenerator.new()
	r.seed = sd
	match kind:
		"grass", "dry_grass":
			var n := r.randi_range(6, 10)
			for i in n:
				var bx := p.x + (i - n * 0.5) * 2.2 * s + r.randf_range(-1, 1)
				var hgt := r.randf_range(10.0, 24.0) * s
				var lean := r.randf_range(-6.0, 6.0) * s + sin(_t * 1.4 + i + sd) * 1.5
				draw_colored_polygon(PackedVector2Array([Vector2(bx - 1.3 * s, p.y), Vector2(bx + 1.3 * s, p.y), Vector2(bx + lean, p.y - hgt)]), c)
		"fern":
			for side in [-1.0, 1.0]:
				for i in 3:
					var ang: float = -PI * 0.5 + side * (0.45 + i * 0.32) + sin(_t * 1.1 + sd) * 0.04
					var ln := (22.0 - i * 4.0) * s
					var tip := p + Vector2(cos(ang), sin(ang)) * ln
					draw_line(p, tip, c, 1.4 * s)
					for j in 5:
						var q := p.lerp(tip, 0.2 + j * 0.16)
						var leaf := Vector2(cos(ang + side * 0.9), sin(ang + side * 0.9)) * (5.0 - j * 0.7) * s
						draw_colored_polygon(PackedVector2Array([q, q + leaf, q + leaf * 0.5 + Vector2(0, -1.2 * s)]), c)
		"rock", "rubble":
			var pts := PackedVector2Array()
			var rw := r.randf_range(12.0, 24.0) * s
			var rh := r.randf_range(7.0, 14.0) * s
			for i in 9:
				var a := PI + PI * i / 8.0
				var rr := 1.0 + r.randf_range(-0.12, 0.12)
				pts.append(p + Vector2(cos(a) * rw * 0.5 * rr, sin(a) * rh * rr))
			draw_colored_polygon(pts, c)
			if kind == "rubble":
				draw_circle(p + Vector2(rw * 0.55, -2.0 * s), 3.0 * s, c)
		"post":
			draw_rect(Rect2(p.x - 1.5 * s, p.y - 26.0 * s, 3.0 * s, 26.0 * s), c)
			draw_rect(Rect2(p.x - 9.0 * s, p.y - 18.0 * s, 18.0 * s, 2.2 * s), c)
		"stalactite":
			var ln2 := r.randf_range(18.0, 40.0) * s
			var wd := r.randf_range(6.0, 12.0) * s
			draw_colored_polygon(PackedVector2Array([p + Vector2(-wd * 0.5, 0), p + Vector2(wd * 0.5, 0), p + Vector2(r.randf_range(-2, 2), ln2)]), c)
			draw_colored_polygon(PackedVector2Array([p + Vector2(wd * 0.3, 0), p + Vector2(wd * 0.9, 0), p + Vector2(wd * 0.6, ln2 * 0.55)]), c)
		"roots", "vine":
			var strands := r.randi_range(2, 4)
			for i in strands:
				var x0 := p.x + (i - strands * 0.5) * 4.0 * s
				var ln3 := r.randf_range(24.0, 60.0) * s
				var pts2 := PackedVector2Array()
				for j in 9:
					var f := j / 8.0
					pts2.append(Vector2(x0 + sin(f * 5.0 + i + _t * 0.9 + sd) * 3.0 * s * f, p.y + f * ln3))
				draw_polyline(pts2, c, (2.4 if kind == "roots" else 1.4) * s)
				if kind == "vine":
					for j in range(2, 9, 2):
						draw_circle(pts2[j] + Vector2(2.0 * s, 0), 1.6 * s, c)
		"chain":
			var ln4 := r.randf_range(30.0, 70.0) * s
			var sw := sin(_t * 1.2 + sd) * 2.0
			var n2 := int(ln4 / (4.0 * s))
			for j in n2:
				var f2 := float(j) / maxf(n2, 1)
				var q2 := Vector2(p.x + sw * f2, p.y + j * 4.0 * s)
				if j % 2 == 0:
					draw_rect(Rect2(q2 - Vector2(1.2, 2.0) * s, Vector2(2.4, 4.0) * s), c, false, 1.0 * s)
				else:
					draw_rect(Rect2(q2 - Vector2(0.5, 2.0) * s, Vector2(1.0, 4.0) * s), c)
