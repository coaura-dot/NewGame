class_name TileSetBuilder
extends RefCounted
## Monta o TileSet (tiles de 24 px de arte = 8 unidades do mundo; as camadas
## usam escala 0.5) a partir do atlas gerado por tools/build_tiles.py:
##   0..46   autotile "blob" (índice por máscara de vizinhos: BlobTable)
##   47..58  variações dos formatos comuns (chão, teto, paredes)
##   59      bloco rachado          61  parede de fundo (miolo)
##   64..67  plataforma E/M/D/única  68  espinhos
##   72..75  franja da superfície   76..79  pendentes do teto
##   80..87  decorações
## Alternativa 1 dos tiles sólidos = sem colisão/oclusão (rocha profunda,
## economiza física e sombras). O miolo e a profundidade são do shader
## (shaders/terrain.gdshader).

const DIR := "res://assets/art/tilesets/"
const T := LevelConst.TILE_PX ## tamanho do tile na arte (px)
const SOURCE := 0
const H := T * 0.5
const COLS := 8
const ROWS := 11

const PLAT_L := Vector2i(0, 8)
const PLAT_M := Vector2i(1, 8)
const PLAT_R := Vector2i(2, 8)
const PLAT_S := Vector2i(3, 8)
const SPIKES := Vector2i(4, 8)
const FRINGE := [Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9), Vector2i(3, 9)]
const HANG := [Vector2i(4, 9), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9)]
const DECO := [Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10), Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10)]
const BG_TILE := Vector2i(5, 7)
const BREAKABLE := Vector2i(3, 7)

## Alternativas dos espinhos (orientação)
const SPIKE_UP := 0
const SPIKE_DOWN := 1
const SPIKE_LEFT := 2
const SPIKE_RIGHT := 3
const NO_COLLISION := 1

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func tileset_name(n: String) -> String:
	return n if ResourceLoader.exists(DIR + n + ".png") else "castle"


static func texture(n: String, suffix: String = "") -> Texture2D:
	var key := n + suffix
	if not _tex_cache.has(key):
		var path := DIR + tileset_name(n) + suffix + ".png"
		_tex_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[key]


static func build(tileset_name_in: String) -> TileSet:
	var nm := tileset_name(tileset_name_in)
	if _cache.has(nm):
		return _cache[nm]
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
	src.texture = texture(nm)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, SOURCE)
	for y in ROWS:
		for x in COLS:
			src.create_tile(Vector2i(x, y))
	# sólidos: blob 0..58 + quebrável
	for i in 60:
		var c := BlobTable.coord(i)
		_solid(src.get_tile_data(c, 0))
		src.create_alternative_tile(c, NO_COLLISION) # sem colisão
	for c in [PLAT_L, PLAT_M, PLAT_R, PLAT_S]:
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(1)
		td.set_collision_polygon_points(1, 0, PackedVector2Array([Vector2(-H, -H), Vector2(H, -H), Vector2(H, -H * 0.25), Vector2(-H, -H * 0.25)]))
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
	_cache[nm] = ts
	return ts


static func _solid(td: TileData) -> void:
	var square := PackedVector2Array([Vector2(-H, -H), Vector2(H, -H), Vector2(H, H), Vector2(-H, H)])
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, square)
	var occ := OccluderPolygon2D.new()
	occ.polygon = square
	td.set_occluder_polygons_count(0, 1)
	td.set_occluder_polygon(0, 0, occ)


## Material do terreno (miolo no mundo + profundidade + normais).
static func terrain_material(nm: String, depth: Texture2D, cells: Vector2, bg: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/terrain.gdshader")
	var n := tileset_name(nm)
	m.set_shader_parameter("fill_tex", texture(n, "_bg" if bg else "_fill"))
	m.set_shader_parameter("fill_normal", texture(n, "_bg_n" if bg else "_fill_n"))
	m.set_shader_parameter("edge_normal", texture(n, "_n"))
	m.set_shader_parameter("cell", float(LevelConst.TILE))
	m.set_shader_parameter("art", float(LevelConst.ART))
	if bg or depth == null:
		m.set_shader_parameter("depth_strength", 0.0)
	else:
		m.set_shader_parameter("depth_tex", depth)
		m.set_shader_parameter("depth_size", cells)
	return m


## Variação determinística por posição (sem RNG global).
static func variant(x: int, y: int, n: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663)
	return absi(h) % n
