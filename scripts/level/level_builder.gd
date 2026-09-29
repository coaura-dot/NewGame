class_name LevelBuilder
extends RefCounted
## Converte o layout ASCII do LevelGenerator em TileMapLayers (autotile pela
## máscara de vizinhos, cantos internos, plataformas, espinhos, decoração)
## + perigos (espinhos).
## Estética escura: a rocha escurece com a distância do ar (borda -> funda ->
## muito funda, quase preta) e os pixels que emitem luz vão para uma camada
## aditiva com cor HDR ("Glow") => bloom. Salas fechadas mostram o fundo em
## parallax (salões, arcos, cavernas) em vez de uma parede chapada.

const T := LevelConst.TILE
const GLOW_HDR := Color(1.7, 1.7, 1.7) ## intensidade da camada de brilho
const BIG_GLOW_CHANCE := 11 ## 1 em N decorações de chão vira uma decoração grande que ilumina


static func build(root: Node2D, layout: Dictionary, biome: Dictionary, biome_id: String = "") -> Dictionary:
	var bid := biome_id if biome_id != "" else str(biome.get("art", "castelo"))
	var ts := TileSetBuilder.build(bid)

	var bg := _layer("BackWall", ts, -20)
	var solid := _layer("Terrain", ts, 0)
	var corners := _layer("Corners", ts, 1)
	var deco := _layer("Deco", ts, -1)
	for l in [bg, corners, deco]:
		l.collision_enabled = false
		l.occlusion_enabled = false
	for l in [bg, deco, solid, corners]:
		root.add_child(l)
	var glow_ts := TileSetBuilder.build_glow(bid)
	var glow: TileMapLayer = null
	if glow_ts:
		glow = TileMapLayer.new()
		glow.name = "Glow"
		glow.tile_set = glow_ts
		glow.z_index = 2
		glow.collision_enabled = false
		glow.occlusion_enabled = false
		glow.modulate = GLOW_HDR
		var gm := CanvasItemMaterial.new()
		gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		gm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		glow.material = gm
		root.add_child(glow)
	var glow_cells := TileSetBuilder.glow_cells(bid)
	var lamps: Array = [] ## [posição, índice] das decorações grandes (viram luzes)

	var rows: PackedStringArray = layout["rows"]
	var w: int = layout["width"]
	var h: int = layout["height"]
	var spikes: Array[Vector2i] = []
	for y in h:
		var row: String = rows[y]
		for x in w:
			var c := row[x]
			var cell := Vector2i(x, y)
			if c == "#":
				_place_solid(solid, corners, rows, x, y, w, h)
				continue
			if c == "-":
				var l := _ch(rows, x - 1, y, w, h) == "-"
				var r := _ch(rows, x + 1, y, w, h) == "-"
				var coord := TileSetBuilder.PLAT_M
				if not l and not r:
					coord = TileSetBuilder.PLAT_ONE
				elif not l:
					coord = TileSetBuilder.PLAT_L
				elif not r:
					coord = TileSetBuilder.PLAT_R
				solid.set_cell(cell, TileSetBuilder.SOURCE, coord)
			elif c == "^":
				spikes.append(cell)
				solid.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.SPIKES, _spike_alt(rows, x, y, w, h))
			elif c == ".":
				# decoração: no chão (tile de baixo sólido) ou pendurada (tile de cima sólido)
				if _is_solid(rows, x, y + 1, w, h) and TileSetBuilder.variant(x * 3, y * 7, 9) < 3:
					if TileSetBuilder.variant(x * 13, y * 5, BIG_GLOW_CHANCE) == 0:
						var k := TileSetBuilder.variant(x, y * 3, 4)
						deco.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.BIG_GLOW[k])
						lamps.append([Vector2(x * T + T * 0.5, y * T + T * 0.5), k])
					else:
						deco.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.DECO[TileSetBuilder.variant(x, y, 5)])
				elif _is_solid(rows, x, y - 1, w, h) and TileSetBuilder.variant(x * 5, y * 11, 10) < 3:
					deco.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.HANG[TileSetBuilder.variant(x, y, 4)])

	# perigo: um Hazard com retângulos por espinho (caixa um pouco menor que o tile)
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
	if glow:
		for l: TileMapLayer in [deco, solid, corners]:
			for cell: Vector2i in l.get_used_cells():
				var ac: Vector2i = l.get_cell_atlas_coords(cell)
				if glow_cells.has(ac):
					glow.set_cell(cell, TileSetBuilder.SOURCE, ac, l.get_cell_alternative_tile(cell) if ac == TileSetBuilder.SPIKES else 0)
	return {"terrain": solid, "background": bg, "hazard": hazard, "spikes": spikes, "glow": glow, "lamps": lamps}


static func _layer(n: String, ts: TileSet, z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = n
	l.tile_set = ts
	l.z_index = z
	return l


static func _ch(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return "#"
	return rows[y][x]


static func _is_solid(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> bool:
	return _ch(rows, x, y, w, h) == "#"


static func _place_solid(solid: TileMapLayer, corners: TileMapLayer, rows: PackedStringArray, x: int, y: int, w: int, h: int) -> void:
	var up := _is_solid(rows, x, y - 1, w, h)
	var right := _is_solid(rows, x + 1, y, w, h)
	var down := _is_solid(rows, x, y + 1, w, h)
	var left := _is_solid(rows, x - 1, y, w, h)
	var mask := (1 if up else 0) | (2 if right else 0) | (4 if down else 0) | (8 if left else 0)
	var cell := Vector2i(x, y)
	# distância (em tiles) até o ar: 1 = encosta no ar (8 vizinhos), 2, 3+
	var dist := _air_dist(rows, x, y, w, h)
	var alt := TileSetBuilder.NO_COLLISION if dist > 1 else 0
	if mask == 15 and dist >= 3:
		solid.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.DEEPER[TileSetBuilder.variant(x, y, 2)], 0)
	elif mask == 15 and dist == 2:
		solid.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.DEEP[TileSetBuilder.variant(x, y, 2)], 0)
	elif mask == 15:
		solid.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.FILL[TileSetBuilder.variant(x, y, 4)], alt)
		# cantos internos (diagonal vazia com os dois lados sólidos)
		var diag := [[-1, -1, 0], [1, -1, 1], [-1, 1, 2], [1, 1, 3]]
		for dd in diag:
			if not _is_solid(rows, x + dd[0], y + dd[1], w, h):
				corners.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.CORNER[dd[2]])
	else:
		solid.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.mask_tile(mask), alt)


## Distância de Chebyshev até a célula não sólida mais próxima (máx. 3).
static func _air_dist(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> int:
	for r in [1, 2]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var xx: int = x + dx
				var yy: int = y + dy
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				if rows[yy][xx] != "#":
					return r
	return 3


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
