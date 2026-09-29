class_name TileSetBuilder
extends RefCounted
## Monta um TileSet (tiles de 8 px) a partir do atlas gerado por
## tools/pixel_art.py (ver tools/world_art.py):
##   linhas 0-1: 16 tiles de borda pela máscara de vizinhos sólidos
##               (bit 1=cima, 2=direita, 4=baixo, 8=esquerda)
##   linha 2:    4 preenchimentos | 4 cantos internos (sobreposição)
##   linha 3:    plataforma E/M/D/única | espinhos | quebrável | piso rachado | fundo 0
##   linha 4:    fundos 1-3 | 5 decorações de chão
##   linha 5:    4 decorações penduradas | 4 paredes de fundo especiais
##   linha 6:    2 rochas fundas | 2 muito fundas | 4 decorações grandes que brilham
## Alternativa 1 dos tiles sólidos = sem colisão/oclusão (rocha profunda).
## <bioma>_glow.png tem o mesmo leiaute, só com os pixels que emitem luz:
## vira uma camada aditiva com cor HDR por cima (bloom).

const DIR := "res://assets/art/tiles/"
const T := 8
const SOURCE := 0

const FILL := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
const CORNER := [Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2)] ## TL, TR, BL, BR
const PLAT_L := Vector2i(0, 3)
const PLAT_M := Vector2i(1, 3)
const PLAT_R := Vector2i(2, 3)
const PLAT_ONE := Vector2i(3, 3)
const SPIKES := Vector2i(4, 3)
const BREAKABLE := Vector2i(5, 3)
const CRACKED := Vector2i(6, 3)
const BG := [Vector2i(7, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]
const DECO := [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)]
const HANG := [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)]
const BG_SPECIAL := [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)] ## janela, runa, nicho, fenda
const DEEP := [Vector2i(0, 6), Vector2i(1, 6)] ## rocha a 2 tiles do ar
const DEEPER := [Vector2i(2, 6), Vector2i(3, 6)] ## rocha a 3+ tiles do ar (quase preto)
const BIG_GLOW := [Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6)] ## lanterna, cristal, cogumelo, flor-lume
const ROWS := 8

## Alternativas dos espinhos (orientação)
const SPIKE_UP := 0
const SPIKE_DOWN := 1
const SPIKE_LEFT := 2
const SPIKE_RIGHT := 3
const NO_COLLISION := 1

static var _cache: Dictionary = {}
static var _glow_cache: Dictionary = {}
static var _glow_cells: Dictionary = {} ## bioma -> {Vector2i: true} tiles com brilho


static func mask_tile(mask: int) -> Vector2i:
	return Vector2i(mask % 8, mask / 8)


static func texture_for(biome_id: String) -> Texture2D:
	var path := DIR + biome_id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return load(DIR + "castelo.png")


static func build(biome_id: String) -> TileSet:
	if _cache.has(biome_id):
		return _cache[biome_id]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Layers.WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, Layers.ONE_WAY)
	ts.set_physics_layer_collision_mask(1, 0)
	ts.add_occlusion_layer()
	var src := TileSetAtlasSource.new()
	src.texture = texture_for(biome_id)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, SOURCE)
	var rows := mini(ROWS, src.texture.get_height() / T)
	for y in rows:
		for x in 8:
			src.create_tile(Vector2i(x, y))
	var solid: Array = FILL.duplicate()
	for m in 16:
		solid.append(mask_tile(m))
	for c in solid:
		_solid(src.get_tile_data(c, 0))
		src.create_alternative_tile(c, NO_COLLISION)
	for c in [PLAT_L, PLAT_M, PLAT_R, PLAT_ONE]:
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(1)
		td.set_collision_polygon_points(1, 0, PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, -1), Vector2(-4, -1)]))
		td.set_collision_polygon_one_way(1, 0, true)
		td.set_collision_polygon_one_way_margin(1, 0, 2.0)
	# espinhos: 4 orientações via alternativas (sem colisão — o dano vem do Hazard)
	var down := src.create_alternative_tile(SPIKES, SPIKE_DOWN)
	src.get_tile_data(SPIKES, down).flip_v = true
	var left := src.create_alternative_tile(SPIKES, SPIKE_LEFT)
	src.get_tile_data(SPIKES, left).transpose = true
	var right := src.create_alternative_tile(SPIKES, SPIKE_RIGHT)
	var tdr := src.get_tile_data(SPIKES, right)
	tdr.transpose = true
	tdr.flip_h = true
	_cache[biome_id] = ts
	return ts


static func glow_texture_for(biome_id: String) -> Texture2D:
	var path := DIR + biome_id + "_glow.png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


## TileSet da camada de brilho (sem física). null se o bioma não tem _glow.
static func build_glow(biome_id: String) -> TileSet:
	if _glow_cache.has(biome_id):
		return _glow_cache[biome_id]
	var tex := glow_texture_for(biome_id)
	if tex == null:
		return null
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, SOURCE)
	var rows := mini(ROWS, tex.get_height() / T)
	for y in rows:
		for x in 8:
			src.create_tile(Vector2i(x, y))
	var down := src.create_alternative_tile(SPIKES, SPIKE_DOWN)
	src.get_tile_data(SPIKES, down).flip_v = true
	var left := src.create_alternative_tile(SPIKES, SPIKE_LEFT)
	src.get_tile_data(SPIKES, left).transpose = true
	var right := src.create_alternative_tile(SPIKES, SPIKE_RIGHT)
	var tdr := src.get_tile_data(SPIKES, right)
	tdr.transpose = true
	tdr.flip_h = true
	_glow_cache[biome_id] = ts
	return ts


## Cor média (pesada pelo alfa) dos pixels de brilho de um tile do atlas.
static func glow_color(biome_id: String, coord: Vector2i) -> Color:
	var tex := glow_texture_for(biome_id)
	if tex == null:
		return Color(1.0, 0.8, 0.5)
	var img := tex.get_image()
	if img == null:
		return Color(1.0, 0.8, 0.5)
	if img.is_compressed():
		img.decompress()
	var acc := Color(0, 0, 0, 0)
	var w := 0.0
	for py in T:
		for px in T:
			var c := img.get_pixel(coord.x * T + px, coord.y * T + py)
			if c.a > 0.02:
				acc += Color(c.r, c.g, c.b) * c.a
				w += c.a
	if w <= 0.0:
		return Color(1.0, 0.8, 0.5)
	var out := acc / w
	out.a = 1.0
	return out


## Tiles do atlas que têm algum pixel de brilho.
static func glow_cells(biome_id: String) -> Dictionary:
	if _glow_cells.has(biome_id):
		return _glow_cells[biome_id]
	var out := {}
	var tex := glow_texture_for(biome_id)
	if tex:
		var img := tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			for ty in img.get_height() / T:
				for tx in 8:
					var found := false
					for py in T:
						for px in T:
							if img.get_pixel(tx * T + px, ty * T + py).a > 0.02:
								found = true
								break
						if found:
							break
					if found:
						out[Vector2i(tx, ty)] = true
	_glow_cells[biome_id] = out
	return out


static func _solid(td: TileData) -> void:
	var square := PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, square)
	var occ := OccluderPolygon2D.new()
	occ.polygon = square
	td.set_occluder_polygons_count(0, 1)
	td.set_occluder_polygon(0, 0, occ)


## Variação determinística por posição (sem RNG global).
static func variant(x: int, y: int, n: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663)
	return absi(h) % n
