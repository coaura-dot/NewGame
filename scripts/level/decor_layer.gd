class_name DecorLayer
extends Node2D
## CENOGRAFIA dos mapas feitos à mão (estilo Hollow Knight): casas, árvores
## mortas, poços, estátuas, pilares, arcos, lápides, velas, raízes, fungos
## que brilham... Cada peça é um sprite de tools/build_decor.py
## (assets/art/decor/<id>.png, camada de brilho <id>_glow.png e metadados em
## data/decor.json: origem nos pés, balanço, luz). Fica ATRÁS do terreno e
## dos personagens (o capim da borda passa na frente da base das casas).
## Peças com luz ganham uma PointLight2D; o brilho vai por cima sem ser
## escurecido pelo ambiente (bloom).

const DIR := "res://assets/art/decor/"

static var _meta: Dictionary = {}
static var _tex_cache: Dictionary = {}

var camera: Camera2D = null
var style: String = ""
var _items: Array = [] ## [Texture2D, Texture2D glow|null, pos (pés), origin px, flip, sway, fase]
var _glow_node: Node2D
var _front_node: Node2D
var _t: float = 0.0


static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open("res://data/decor.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_meta = d
	return _meta


static func tex(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := DIR + id + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[id] = t
	return t


## Resolve a variante do estilo: "<id>_<estilo>" se existir, senão "<id>".
static func resolve(id: String, style_id: String) -> String:
	var m := meta()
	if style_id != "" and m.has(id + "_" + style_id):
		return id + "_" + style_id
	return id


func build(layout: Dictionary, biome_id: String, biome: Dictionary) -> void:
	style = str(biome.get("decor_style", biome_id))
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow_node = Node2D.new()
	_glow_node.z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow_node.material = mat
	_glow_node.draw.connect(_draw_glow)
	add_child(_glow_node)
	var torch_a: Array = biome.get("torch", [1.8, 0.9, 0.4])
	var T := LevelConst.TILE
	for d in layout.get("decor", []):
		var id := resolve(str(d["id"]), style)
		var info: Dictionary = meta().get(id, {})
		var t := tex(id)
		if t == null:
			continue
		var g: Texture2D = tex(id + "_glow") if bool(info.get("glow", false)) else null
		var tile: Array = d["tile"]
		var pos := Vector2(int(tile[0]) * T + T * 0.5, (int(tile[1]) + 1) * T)
		if bool(info.get("hang", false)):
			pos.y = int(tile[1]) * T # pendurado no teto (topo do tile)
		var dd: Dictionary = d.get("data", {})
		pos += Vector2(float(dd.get("ox", 0)), float(dd.get("oy", 0)))
		var o: Array = info.get("origin", [t.get_width() / 2, t.get_height()])
		var flip := (absi(hash([tile[0], tile[1]])) % 2 == 0) and bool(info.get("flip", true))
		var data: Dictionary = d.get("data", {})
		if data.has("flip"):
			flip = str(data["flip"]) == "1"
		_items.append([t, g, pos, Vector2(float(o[0]), float(o[1])), flip, float(info.get("sway", 0.0)), randf() * TAU])
		# luz própria (velas, lamparinas, fungos, cristais, vitrais)
		var lc: Array = info.get("light", [])
		if lc.size() >= 3:
			var col := Color(float(lc[0]), float(lc[1]), float(lc[2]))
			if info.get("torch_color", false):
				col = Color(torch_a[0], torch_a[1], torch_a[2])
			var l := LightUtil.make_light(col, float(info.get("light_energy", 0.8)), float(info.get("light_scale", 0.7)))
			if l:
				var lo: Array = info.get("light_at", [0, -float(o[1]) * 0.5])
				l.position = pos + Vector2(float(lo[0]) * (-1.0 if flip else 1.0), float(lo[1])) * LevelConst.ART_SCALE
				add_child(l)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_glow_node.queue_redraw()


func _view() -> Rect2:
	if camera == null:
		return Rect2(-99999, -99999, 199999, 199999)
	var c := camera.get_screen_center_position()
	return Rect2(c - LevelConst.VIEW * 0.5 - Vector2(80, 80), LevelConst.VIEW + Vector2(160, 160))


func _draw_item(it: Array, glow: bool) -> void:
	var t: Texture2D = it[1] if glow else it[0]
	if t == null:
		return
	var pos: Vector2 = it[2]
	var o: Vector2 = it[3]
	var flip: bool = it[4]
	var sway: float = it[5]
	var k := LevelConst.ART_SCALE
	var sx := -k if flip else k
	var rot := 0.0
	if sway > 0.0:
		rot = sin(_t * 1.3 + float(it[6])) * sway
	var node: CanvasItem = _glow_node if glow else self
	node.draw_set_transform(pos, rot, Vector2(sx, k))
	node.draw_texture(t, -o)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	var v := _view()
	for it in _items:
		if v.has_point(it[2]):
			_draw_item(it, false)


func _draw_glow() -> void:
	var v := _view()
	for it in _items:
		if it[1] != null and v.has_point(it[2]):
			_draw_item(it, true)
