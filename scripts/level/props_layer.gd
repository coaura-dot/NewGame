class_name PropsLayer
extends Node2D
## Decoração viva por bioma, espalhada pelo terreno na construção da fase e
## desenhada só perto da câmera: cipós e raízes que balançam, correntes com
## lanternas, estandartes que tremulam, estalactites, cristais que brilham,
## velas, ossos, capim alto, juncos e cogumelos. Nada disso colide.

const T := LevelConst.TILE

var camera: Camera2D = null
var style: String = ""
var _items: Array = [] ## [tipo, pos, tamanho, fase]
var _t: float = 0.0


func build(rows: PackedStringArray, style_id: String, seed_v: int) -> void:
	style = style_id
	z_index = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h := rows.size()
	var w: int = rows[0].length() if h > 0 else 0
	var hang := {"forest": "vine", "swamp": "vine", "ruins": "vine", "cave": "stalactite", "castle": "chain", "catacomb": "chain",
		"war": "chain", "town": "lantern", "graveyard": "root", "arcane": "crystal_hang", "temple": "chain", "sky": "", "desert": ""}
	var ground := {"forest": ["grass", "grass", "flower"], "swamp": ["reed", "reed", "grass"], "ruins": ["grass", "vine_up"],
		"cave": ["crystal", "mushroom"], "arcane": ["crystal"], "catacomb": ["candle", "bone"], "graveyard": ["bone", "grass"],
		"temple": ["candle"], "castle": ["grass"], "war": ["stake", "grass"], "town": ["grass"], "desert": ["bone"], "sky": ["grass"]}
	var hang_kind: String = hang.get(style, "")
	var ground_kinds: Array = ground.get(style, [])
	for y in range(1, h - 2):
		var row: String = rows[y]
		for x in range(1, w - 1):
			if row[x] != "#":
				continue
			# teto: pendurados
			if hang_kind != "" and rows[y + 1][x] == "." and rows[y + 2][x] == ".":
				var chance := 0.14 if hang_kind in ["vine", "stalactite", "root"] else 0.05
				if rng.randf() < chance:
					var ln := rng.randi_range(3, 12) if hang_kind != "stalactite" else rng.randi_range(3, 7)
					if hang_kind == "chain" or hang_kind == "lantern":
						ln = rng.randi_range(6, 22)
					_items.append([hang_kind, Vector2(x * T + rng.randi_range(1, 6), (y + 1) * T), ln, rng.randf() * TAU])
			# chão: de pé
			if not ground_kinds.is_empty() and rows[y - 1][x] == "." and rows[y - 2][x] == ".":
				if rng.randf() < 0.1:
					var kind: String = ground_kinds[rng.randi_range(0, ground_kinds.size() - 1)]
					_items.append([kind, Vector2(x * T + rng.randi_range(1, 6), y * T), rng.randi_range(3, 7), rng.randf() * TAU])
			# parede virada para dentro: estandartes
			if style in ["castle", "war", "town", "temple"] and rng.randf() < 0.012:
				for side in [-1, 1]:
					if rows[y][x + side] == "." and rows[y + 1][x + side] == "." and rows[y + 2][x + side] == ".":
						_items.append(["banner", Vector2(x * T + (T if side > 0 else 0), y * T + 1), rng.randi_range(8, 14), float(side)])
						break


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var view := Rect2(-9999, -9999, 99999, 99999)
	if camera:
		var c := camera.get_screen_center_position()
		view = Rect2(c - LevelConst.VIEW * 0.5 - Vector2(32, 32), LevelConst.VIEW + Vector2(64, 64))
	for it in _items:
		var p: Vector2 = it[1]
		if not view.has_point(p):
			continue
		var n: int = int(it[2])
		var ph: float = float(it[3])
		match str(it[0]):
			"vine", "root":
				var col := Color(0.28, 0.5, 0.26) if it[0] == "vine" else Color(0.32, 0.24, 0.2)
				var x := p.x
				for i in n:
					var sway := sin(_t * 1.6 + ph + i * 0.35) * (i * 0.12)
					draw_rect(Rect2(roundf(x + sway), p.y + i, 1, 1), col if i % 3 else col.lightened(0.15))
				if it[0] == "vine" and n > 6:
					draw_rect(Rect2(roundf(x + sin(_t * 1.6 + ph + n * 0.35) * n * 0.12) - 1, p.y + n - 1, 3, 2), Color(0.36, 0.6, 0.3))
			"stalactite":
				var c := Color(0.28, 0.28, 0.36)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 0), p + Vector2(2, 0), p + Vector2(0, n)]), c)
				draw_rect(Rect2(p.x - 1, p.y, 1, n * 0.6), c.lightened(0.12))
				if fmod(_t + ph, 4.0) < 0.3:
					draw_rect(Rect2(p.x, p.y + n + fmod(_t + ph, 4.0) * 60.0, 1, 2), Color(0.6, 0.8, 1.2, 0.8))
			"chain", "lantern":
				var cc := Color(0.35, 0.33, 0.38)
				var swing := sin(_t * 1.2 + ph) * 0.6
				for i in n:
					if i % 2 == 0:
						draw_rect(Rect2(roundf(p.x + swing * i / n), p.y + i, 1, 1), cc)
				if it[0] == "lantern" or n > 14:
					var lp := Vector2(roundf(p.x + swing), p.y + n)
					draw_rect(Rect2(lp.x - 2, lp.y, 5, 5), Color(0.12, 0.1, 0.12))
					draw_rect(Rect2(lp.x - 1, lp.y + 1, 3, 3), Color(2.6, 1.7, 0.6))
			"crystal_hang":
				draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 0), p + Vector2(2, 0), p + Vector2(0, 6)]), Color(1.4, 0.8, 2.4))
			"grass", "reed":
				var gcol := Color(0.4, 0.66, 0.32) if it[0] == "grass" else Color(0.46, 0.56, 0.3)
				var blades := 3 if it[0] == "grass" else 2
				for b in blades:
					var bx := p.x + b * 2 - blades
					var hgt := n - b % 2 + (2 if it[0] == "reed" else 0)
					for i in hgt:
						var sway := sin(_t * 2.2 + ph + b) * (i * 0.25)
						draw_rect(Rect2(roundf(bx + sway), p.y - 1 - i, 1, 1), gcol if i < hgt - 1 else gcol.lightened(0.2))
				if it[0] == "reed":
					draw_rect(Rect2(roundf(p.x + sin(_t * 2.2 + ph) * n * 0.3), p.y - n - 3, 1, 3), Color(0.42, 0.28, 0.16))
			"flower":
				draw_rect(Rect2(p.x, p.y - 3, 1, 3), Color(0.36, 0.6, 0.3))
				var fc: Color = [Color(2.0, 1.6, 0.5), Color(2.0, 0.7, 1.0), Color(0.8, 1.2, 2.2)][int(ph * 10.0) % 3]
				draw_rect(Rect2(p.x - 1, p.y - 4, 3, 1), fc)
				draw_rect(Rect2(p.x, p.y - 5, 1, 1), fc)
			"vine_up":
				for i in n + 3:
					draw_rect(Rect2(p.x + (1 if i % 4 < 2 else 0), p.y - 1 - i, 1, 1), Color(0.32, 0.54, 0.28))
			"crystal":
				var glow := 0.75 + 0.25 * sin(_t * 2.0 + ph)
				var cc2 := Color(0.6, 2.2, 2.6) * glow if style == "cave" else Color(1.8, 0.9, 2.6) * glow
				draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 0), p + Vector2(0, -n), p + Vector2(2, 0)]), cc2)
				draw_colored_polygon(PackedVector2Array([p + Vector2(1, 0), p + Vector2(3, -n * 0.6), p + Vector2(4, 0)]), cc2 * 0.8)
			"mushroom":
				draw_rect(Rect2(p.x, p.y - 3, 1, 3), Color(0.85, 0.8, 0.7))
				draw_rect(Rect2(p.x - 2, p.y - 5, 5, 2), Color(1.6, 0.5, 0.6) if int(ph * 10.0) % 2 else Color(0.6, 1.6, 1.4))
			"candle":
				draw_rect(Rect2(p.x, p.y - 4, 1, 4), Color(0.95, 0.9, 0.8))
				var fl := 0.8 + 0.2 * sin(_t * 12.0 + ph * 5.0)
				draw_rect(Rect2(p.x, p.y - 6, 1, 2), Color(3.0 * fl, 1.9 * fl, 0.6))
			"bone":
				draw_rect(Rect2(p.x - 2, p.y - 1, 5, 1), Color(0.9, 0.86, 0.76))
				draw_rect(Rect2(p.x - 2, p.y - 2, 1, 1), Color(0.9, 0.86, 0.76))
				draw_rect(Rect2(p.x + 2, p.y - 2, 1, 1), Color(0.9, 0.86, 0.76))
			"stake":
				draw_colored_polygon(PackedVector2Array([p + Vector2(-1, 0), p + Vector2(0, -n - 2), p + Vector2(1, 0)]), Color(0.6, 0.42, 0.28))
			"banner":
				var side: float = ph
				var bx2 := p.x + (1.0 if side > 0 else -6.0)
				var cloth := Color(0.62, 0.16, 0.18) if style != "temple" else Color(0.9, 0.7, 0.3)
				for i in n:
					var wave := sin(_t * 2.5 + i * 0.4) * (i * 0.08)
					draw_rect(Rect2(roundf(bx2 + wave), p.y + i, 5, 1), cloth if i != n / 2 else Color(1.6, 1.3, 0.6))
				draw_rect(Rect2(bx2 - 1, p.y - 1, 7, 1), Color(0.3, 0.26, 0.24))
