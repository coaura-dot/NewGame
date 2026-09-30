class_name LevelBuilder
extends RefCounted
## Converte o layout ASCII do LevelGenerator em TileMapLayers (autotile por
## vizinhança: topo gramado/musgoso, sub-superfície, preenchimento, bordas,
## teto, decoração e parede de fundo) + perigos (espinhos).

const T := LevelConst.TILE


static func build(root: Node2D, layout: Dictionary, biome: Dictionary) -> Dictionary:
	var tsname := str(biome.get("tileset", "castle"))
	var ts := TileSetBuilder.build(tsname)
	var tint_a: Array = biome.get("tint", [1, 1, 1])
	var tint := Color(tint_a[0], tint_a[1], tint_a[2])
	var indoor: bool = layout.get("indoor", false)
	var rows: PackedStringArray = layout["rows"]
	var w: int = layout["width"]
	var h: int = layout["height"]

	var bg := _layer("BackWall", ts, -20, tint * Color(0.62, 0.62, 0.7))
	var solid := _layer("Terrain", ts, 0, tint)
	var trim := _layer("Fringe", ts, 1, tint)
	var ceil := _layer("Hang", ts, 1, tint)
	var deco := _layer("Deco", ts, 2, tint)
	for l in [bg, trim, ceil, deco]:
		l.collision_enabled = false
		l.occlusion_enabled = false
	for l in [bg, solid, trim, ceil, deco]:
		root.add_child(l)
	# profundidade: distância de cada célula sólida até o ar (0 = borda)
	var depth := _depth_texture(rows, w, h)
	solid.material = TileSetBuilder.terrain_material(tsname, depth, Vector2(w, h))
	bg.material = TileSetBuilder.terrain_material(tsname, null, Vector2(w, h), true)
	var grassy := _has_fringe(tsname)

	# regiões novas (RegionDesigner) trazem a parede de fundo pronta, tile a
	# tile: '1' = parede, '2' = janela (o cenário aparece), '0' = céu/nada
	var bg_rows: PackedStringArray = layout.get("bg", PackedStringArray())
	var windows := _windows(layout, biome) if bg_rows.is_empty() else {}
	var room_mask := _room_mask(layout)
	# fora (céu aberto) só as salas mais altas; as de baixo são subterrâneas
	# e ganham parede de rocha ao fundo
	var open_sky := {}
	for c in layout.get("sky_rooms", []):
		open_sky[Vector2i(int(c[0]), int(c[1]))] = true
	var spikes: Array[Vector2i] = []
	for y in h:
		var row: String = rows[y]
		for x in w:
			var c := row[x]
			var cell := Vector2i(x, y)
			if c == "#":
				_place_solid(solid, trim, ceil, deco, rows, x, y, w, h, grassy)
			else:
				if not bg_rows.is_empty():
					if bg_rows[y].unicode_at(x) == 49: # '1'
						bg.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.BG_TILE)
				else:
					var rc := Vector2i(x / LevelConst.ROOM_W, y / LevelConst.ROOM_H)
					if room_mask.has(rc) and (indoor or not open_sky.has(rc)) and not windows.has(cell):
						bg.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.BG_TILE)
				if c == "-":
					var l := _ch(rows, x - 1, y, w, h) == "-"
					var r := _ch(rows, x + 1, y, w, h) == "-"
					var coord := TileSetBuilder.PLAT_M
					if not l and not r:
						coord = TileSetBuilder.PLAT_S
					elif not l:
						coord = TileSetBuilder.PLAT_L
					elif not r:
						coord = TileSetBuilder.PLAT_R
					solid.set_cell(cell, TileSetBuilder.SOURCE, coord)
				elif c == "^":
					spikes.append(cell)
					solid.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.SPIKES, _spike_alt(rows, x, y, w, h))

	# perigo: um Hazard com retângulos por sequência de espinhos
	var hazard := Hazard.new()
	hazard.name = "Spikes"
	hazard.damage = 15.0
	for cell in spikes:
		var alt := _spike_alt(rows, cell.x, cell.y, w, h)
		var r := Rect2(cell.x * T, cell.y * T, T, T)
		match alt:
			TileSetBuilder.SPIKE_UP: r = Rect2(r.position.x + 1, r.position.y + 4, T - 2, 4)
			TileSetBuilder.SPIKE_DOWN: r = Rect2(r.position.x + 1, r.position.y, T - 2, 4)
			TileSetBuilder.SPIKE_LEFT: r = Rect2(r.position.x + 4, r.position.y + 1, 4, T - 2)
			TileSetBuilder.SPIKE_RIGHT: r = Rect2(r.position.x, r.position.y + 1, 4, T - 2)
		hazard.add_rect(r)
	root.add_child(hazard)
	var pools := 0
	if layout.has("water"):
		pools = _water_rects(root, layout["water"], biome)
	if biome.get("water", false):
		pools += _water(root, rows, w, h, biome)
	return {"terrain": solid, "background": bg, "hazard": hazard, "spikes": spikes, "pools": pools}


## Textura (1 pixel por célula) com a profundidade da rocha: 0 na borda,
## subindo até 1 a ~5 tiles do ar. O shader filtra linear => degradê suave.
static func _depth_texture(rows: PackedStringArray, w: int, h: int) -> ImageTexture:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	var queue: Array[int] = []
	for y in h:
		var row: String = rows[y]
		for x in w:
			var i := y * w + x
			if row[x] == "#":
				dist[i] = 99
			else:
				dist[i] = 0
				queue.append(i)
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x := i % w
		var y := i / w
		var d := dist[i] + 1
		if d > 6:
			continue
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var xx: int = x + o.x
			var yy: int = y + o.y
			if xx < 0 or yy < 0 or xx >= w or yy >= h:
				continue
			var j := yy * w + xx
			if dist[j] > d:
				dist[j] = d
				queue.append(j)
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var d := dist[y * w + x]
			# 1ª linha sólida (d=1) fica clara; escurece a partir da 2ª
			var v := clampf((float(d) - 1.25) / 2.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


static func _has_fringe(tsname: String) -> bool:
	return tsname in ["castle", "ruins", "forest", "graveyard", "swamp", "cave", "desert", "war"]


## Lagos desenhados pelo RegionDesigner: [x0, x1, y_topo, y_fundo] em tiles.
static func _water_rects(root: Node2D, list: Array, biome: Dictionary) -> int:
	var wc: Array = biome.get("water_color", [0.22, 0.36, 0.46, 0.78])
	for s in list:
		var pool := WaterPool.new()
		pool.position = Vector2(int(s[0]) * T, int(s[2]) * T + 3)
		pool.size = Vector2((int(s[1]) - int(s[0]) + 1) * T, (int(s[3]) - int(s[2]) + 1) * T - 3)
		pool.color = Color(wc[0], wc[1], wc[2], wc[3])
		root.add_child(pool)
	return list.size()


## Poças rasas (até 2 tiles) nos buracos do terreno cercados de chão dos
## dois lados. Só decoração (o fundo continua firme).
static func _water(root: Node2D, rows: PackedStringArray, w: int, h: int, biome: Dictionary) -> int:
	var water := {}
	var surfaces: Array = [] ## [x0, x1, y]
	for y in range(h - 2, 0, -1):
		var x := 1
		while x < w - 1:
			if rows[y][x] != "." or not (rows[y + 1][x] == "#" or water.has(Vector2i(x, y + 1))):
				x += 1
				continue
			var x0 := x
			var ok := true
			while x < w - 1 and rows[y][x] == ".":
				if not (rows[y + 1][x] == "#" or water.has(Vector2i(x, y + 1))):
					ok = false
				x += 1
			var x1 := x - 1
			if not ok or rows[y][x0 - 1] != "#" or rows[y][x1 + 1] != "#" or x1 - x0 + 1 < 2 or x1 - x0 + 1 > 18:
				continue
			# no máximo 2 de profundidade
			var depth := 0
			var yy := y + 1
			while water.has(Vector2i(x0, yy)):
				depth += 1
				yy += 1
			if depth >= 2:
				continue
			for xx in range(x0, x1 + 1):
				water[Vector2i(xx, y)] = true
			surfaces.append([x0, x1, y])
	# uma poça por superfície (a linha mais alta de cada bacia)
	var n := 0
	var wc: Array = biome.get("water_color", [0.22, 0.36, 0.46, 0.78])
	for s in surfaces:
		if water.has(Vector2i(int(s[0]), int(s[2]) - 1)):
			continue
		var bottom := int(s[2])
		while water.has(Vector2i(int(s[0]), bottom + 1)):
			bottom += 1
		var pool := WaterPool.new()
		pool.position = Vector2(int(s[0]) * T, int(s[2]) * T + 3)
		pool.size = Vector2((int(s[1]) - int(s[0]) + 1) * T, (bottom - int(s[2]) + 1) * T - 3)
		pool.color = Color(wc[0], wc[1], wc[2], wc[3])
		root.add_child(pool)
		n += 1
	return n


## Janelas em arco na parede de fundo (castelos, templos, salões): o
## cenário pintado aparece por elas (Blasphemous). Só em biomas "indoor".
static func _windows(layout: Dictionary, biome: Dictionary) -> Dictionary:
	var out := {}
	if not layout.get("indoor", false) or biome.get("tags", []).has("underground"):
		return out
	var rows: PackedStringArray = layout["rows"]
	for r in layout.get("rooms", []):
		var o: Array = r.get("origin", [0, 0])
		var ox: int = int(o[0])
		var oy: int = int(o[1])
		var seed_v: int = absi(hash([ox, oy, "janela"]))
		if seed_v % 10 < 4 or str(r.get("type", "")) in ["secret", "boss"]:
			continue
		var n := 1 + seed_v % 3
		for k in n:
			var ww := 3 + (seed_v >> (k + 2)) % 3
			var wh := 6 + (seed_v >> (k + 4)) % 4
			var wx := ox + 6 + k * (28 / n) + (seed_v >> k) % 4
			var wy := oy + 3 + (seed_v >> (k + 1)) % 3
			for y in range(wy, wy + wh):
				for x in range(wx, wx + ww):
					# topo em arco: corta os cantos das 2 primeiras linhas
					var dy := y - wy
					if dy == 0 and (x == wx or x == wx + ww - 1) and ww > 3:
						continue
					if y < rows.size() and x < rows[y].length() and rows[y][x] != "#":
						out[Vector2i(x, y)] = true
	return out


static func _layer(n: String, ts: TileSet, z: int, tint: Color) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = n
	l.tile_set = ts
	l.z_index = z
	l.modulate = tint
	# tiles de 24 px de arte em células de 8 unidades
	l.scale = Vector2.ONE * LevelConst.ART_SCALE
	return l


static func _ch(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return "#"
	return rows[y][x]


static func _is_solid(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> bool:
	return _ch(rows, x, y, w, h) == "#"


static func _place_solid(solid: TileMapLayer, trim: TileMapLayer, ceil: TileMapLayer, deco: TileMapLayer, rows: PackedStringArray, x: int, y: int, w: int, h: int, grassy: bool) -> void:
	var mask := 0
	var deep := true
	var bit := 1
	for o in [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]:
		if _is_solid(rows, x + o.x, y + o.y, w, h):
			mask |= bit
		else:
			deep = false
		bit <<= 1
	var m := BlobTable.canon(mask)
	var idx: int = BlobTable.INDEX.get(m, 0)
	if BlobTable.VARIANTS.has(m):
		var v := TileSetBuilder.variant(x, y, 4)
		if v > 0:
			idx = BlobTable.VARIANTS[m][v - 1]
	var cell := Vector2i(x, y)
	# rocha profunda: nenhum vizinho (8) vazio => sem colisão/oclusão
	solid.set_cell(cell, TileSetBuilder.SOURCE, BlobTable.coord(idx), TileSetBuilder.NO_COLLISION if deep else 0)
	var above := _ch(rows, x, y - 1, w, h)
	if above == "." or above == "^":
		if grassy and above == ".":
			trim.set_cell(Vector2i(x, y - 1), TileSetBuilder.SOURCE, TileSetBuilder.FRINGE[TileSetBuilder.variant(x, y, 4)])
		# decoração acima da superfície (não em cima de espinhos/saídas)
		if above == "." and TileSetBuilder.variant(x * 3, y * 7, 10) < 3:
			deco.set_cell(Vector2i(x, y - 1), TileSetBuilder.SOURCE, TileSetBuilder.DECO[TileSetBuilder.variant(x * 5, y, 8)])
	if _ch(rows, x, y + 1, w, h) == "." and TileSetBuilder.variant(x * 11, y * 5, 10) < 4:
		ceil.set_cell(Vector2i(x, y + 1), TileSetBuilder.SOURCE, TileSetBuilder.HANG[TileSetBuilder.variant(x, y * 3, 4)])


static func _spike_alt(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> int:
	if _is_solid(rows, x, y + 1, w, h):
		return TileSetBuilder.SPIKE_UP
	if _is_solid(rows, x, y - 1, w, h):
		return TileSetBuilder.SPIKE_DOWN
	if _is_solid(rows, x + 1, y, w, h):
		return TileSetBuilder.SPIKE_LEFT
	if _is_solid(rows, x - 1, y, w, h):
		return TileSetBuilder.SPIKE_RIGHT
	return TileSetBuilder.SPIKE_UP


static func _room_mask(layout: Dictionary) -> Dictionary:
	var m := {}
	for r in layout.get("rooms", []):
		var o: Array = r.get("origin", [0, 0])
		m[Vector2i(int(o[0]) / LevelConst.ROOM_W, int(o[1]) / LevelConst.ROOM_H)] = true
	return m
