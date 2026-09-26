class_name TileSetBuilder
extends RefCounted
## Monta um TileSet em código a partir do atlas de papéis gerado por
## tools/build_assets.py (8x4 tiles de 16 px):
##   linha 0: TOPO 0-3 | TOPO_E | TOPO_D | TOPO_ÚNICO | QUEBRÁVEL
##   linha 1: SUB 0-3  | PLAT_E | PLAT_M | PLAT_D | ESPINHOS
##   linha 2: FILL 0-3 | BORDA_E | BORDA_D | TETO | PONTO
##   linha 3: DECO 0-3 | FUNDO 0-3
## Alternativa 1 dos tiles sólidos = sem colisão/oclusão (rocha profunda,
## economiza física e sombras).

const DIR := "res://assets/art/tilesets/"
const T := 16
const SOURCE := 0

const TOP := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const TOP_L := Vector2i(4, 0)
const TOP_R := Vector2i(5, 0)
const TOP_SINGLE := Vector2i(6, 0)
const BREAKABLE := Vector2i(7, 0)
const SUB := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
const PLAT_L := Vector2i(4, 1)
const PLAT_M := Vector2i(5, 1)
const PLAT_R := Vector2i(6, 1)
const SPIKES := Vector2i(7, 1)
const FILL := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
const EDGE_L := Vector2i(4, 2)
const EDGE_R := Vector2i(5, 2)
const CEIL := Vector2i(6, 2)
const DECO := [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
const BG := [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3)]

## Alternativas dos espinhos (orientação)
const SPIKE_UP := 0
const SPIKE_DOWN := 1
const SPIKE_LEFT := 2
const SPIKE_RIGHT := 3
const NO_COLLISION := 1

static var _cache: Dictionary = {}


static func build(tileset_name: String) -> TileSet:
	if _cache.has(tileset_name):
		return _cache[tileset_name]
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
	var path := DIR + tileset_name + ".png"
	src.texture = load(path) if ResourceLoader.exists(path) else load(DIR + "castle.png")
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, SOURCE)
	for y in 4:
		for x in 8:
			src.create_tile(Vector2i(x, y))
	var solid: Array = TOP + SUB + FILL + [TOP_L, TOP_R, TOP_SINGLE, BREAKABLE]
	for c in solid:
		_solid(src.get_tile_data(c, 0))
		var alt := src.create_alternative_tile(c, NO_COLLISION)
		src.get_tile_data(c, alt) # sem colisão
	for c in [PLAT_L, PLAT_M, PLAT_R]:
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(1)
		td.set_collision_polygon_points(1, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)]))
		td.set_collision_polygon_one_way(1, 0, true)
	# espinhos: 4 orientações via alternativas (sem colisão sólida — o dano vem do Hazard)
	var down := src.create_alternative_tile(SPIKES, SPIKE_DOWN)
	src.get_tile_data(SPIKES, down).flip_v = true
	var left := src.create_alternative_tile(SPIKES, SPIKE_LEFT)
	var tdl := src.get_tile_data(SPIKES, left)
	tdl.transpose = true
	var right := src.create_alternative_tile(SPIKES, SPIKE_RIGHT)
	var tdr := src.get_tile_data(SPIKES, right)
	tdr.transpose = true
	tdr.flip_h = true
	_cache[tileset_name] = ts
	return ts


static func _solid(td: TileData) -> void:
	var square := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
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
