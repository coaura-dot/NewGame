class_name LevelBuilder
extends RefCounted
## Converte o layout ASCII do LevelGenerator em TileMapLayers (autotile por
## vizinhança: topo gramado/musgoso, sub-superfície, preenchimento, bordas,
## teto, decoração e parede de fundo) + perigos (espinhos).

const T := LevelConst.TILE


static func build(root: Node2D, layout: Dictionary, biome: Dictionary) -> Dictionary:
	var ts := TileSetBuilder.build(biome.get("tileset", "castle"))
	var tint_a: Array = biome.get("tint", [1, 1, 1])
	var tint := Color(tint_a[0], tint_a[1], tint_a[2])
	var indoor: bool = layout.get("indoor", false)

	var bg := _layer("BackWall", ts, -20, tint)
	var solid := _layer("Terrain", ts, 0, tint)
	var trim := _layer("Trim", ts, 1, tint)
	var ceil := _layer("Ceiling", ts, 1, tint)
	var deco := _layer("Deco", ts, 2, tint)
	bg.collision_enabled = false
	bg.occlusion_enabled = false
	trim.collision_enabled = false
	trim.occlusion_enabled = false
	ceil.collision_enabled = false
	ceil.occlusion_enabled = false
	deco.collision_enabled = false
	deco.occlusion_enabled = false
	for l in [bg, solid, trim, ceil, deco]:
		root.add_child(l)

	var rows: PackedStringArray = layout["rows"]
	var w: int = layout["width"]
	var h: int = layout["height"]
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
				_place_solid(solid, trim, ceil, deco, rows, x, y, w, h)
			else:
				var rc := Vector2i(x / LevelConst.ROOM_W, y / LevelConst.ROOM_H)
				if room_mask.has(rc) and (indoor or not open_sky.has(rc)):
					bg.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.BG[TileSetBuilder.variant(x, y, 4)])
				if c == "-":
					var l := _ch(rows, x - 1, y, w, h) == "-"
					var r := _ch(rows, x + 1, y, w, h) == "-"
					var coord := TileSetBuilder.PLAT_M
					if not l:
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
	return {"terrain": solid, "background": bg, "hazard": hazard, "spikes": spikes}


static func _layer(n: String, ts: TileSet, z: int, tint: Color) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = n
	l.tile_set = ts
	l.z_index = z
	l.modulate = tint
	return l


static func _ch(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return "#"
	return rows[y][x]


static func _is_solid(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> bool:
	return _ch(rows, x, y, w, h) == "#"


static func _place_solid(solid: TileMapLayer, trim: TileMapLayer, ceil: TileMapLayer, deco: TileMapLayer, rows: PackedStringArray, x: int, y: int, w: int, h: int) -> void:
	var up := _is_solid(rows, x, y - 1, w, h)
	var up2 := _is_solid(rows, x, y - 2, w, h)
	var down := _is_solid(rows, x, y + 1, w, h)
	var left := _is_solid(rows, x - 1, y, w, h)
	var right := _is_solid(rows, x + 1, y, w, h)
	var cell := Vector2i(x, y)
	# rocha profunda: nenhum vizinho (8) vazio => sem colisão/oclusão
	var deep := true
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if not _is_solid(rows, x + dx, y + dy, w, h):
				deep = false
	var coord: Vector2i
	if not up:
		if not left and not right:
			coord = TileSetBuilder.TOP_SINGLE
		elif not left:
			coord = TileSetBuilder.TOP_L
		elif not right:
			coord = TileSetBuilder.TOP_R
		else:
			coord = TileSetBuilder.TOP[TileSetBuilder.variant(x, y, 4)]
		# decoração acima da superfície
		var above := _ch(rows, x, y - 1, w, h)
		if above == "." and TileSetBuilder.variant(x * 3, y * 7, 10) < 4:
			deco.set_cell(Vector2i(x, y - 1), TileSetBuilder.SOURCE, TileSetBuilder.DECO[TileSetBuilder.variant(x, y, 4)])
	elif not up2:
		coord = TileSetBuilder.SUB[TileSetBuilder.variant(x, y, 4)]
	else:
		coord = TileSetBuilder.FILL[TileSetBuilder.variant(x, y, 4)]
	solid.set_cell(cell, TileSetBuilder.SOURCE, coord, TileSetBuilder.NO_COLLISION if deep else 0)
	if up:
		if not left:
			trim.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.EDGE_L)
		elif not right:
			trim.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.EDGE_R)
	if not down:
		ceil.set_cell(cell, TileSetBuilder.SOURCE, TileSetBuilder.CEIL)


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
