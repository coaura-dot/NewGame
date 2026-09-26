class_name BackgroundLayer
extends CanvasLayer
## Fundo em parallax por bioma (camadas fixas na tela que rolam com a câmera
## em velocidades diferentes). Arquivos em assets/art/backgrounds/<set>/.

const DIR := "res://assets/art/backgrounds/%s/"
const FACTORS := {
	"town": {"0_sky": 0.0, "1_mountains": 0.04, "2_mountains-lights": 0.04, "3_clouds": 0.08, "4_far-buildings": 0.16, "5_forest": 0.3, "6_town": 0.42},
	"cemetery": {"0_sky": 0.0, "1_mountains": 0.08, "2_graveyard": 0.25},
	"castle": {"0_hall": 0.12},
	"temple": {"1_clouds": 0.03, "0_hall": 0.12},
}
const ORDER := {"temple": ["1_clouds", "0_hall"]}
const AUTOSCROLL := {"3_clouds": 6.0, "1_clouds": 4.0}

var camera: Camera2D = null
var bg_set: String = "town"
var tint: Color = Color.WHITE
var _layers: Array = [] ## [TextureRect, factor, tex_w, autoscroll]
var _scale: float = 1.0
var _t: float = 0.0


func build(set_id: String, color: Color) -> void:
	bg_set = set_id
	tint = color
	layer = -10
	var dir := DIR % set_id
	var files: Array = []
	for f in ResourceLoader.list_directory(dir):
		if str(f).ends_with(".png"):
			files.append(str(f).get_basename())
	files.sort()
	if ORDER.has(set_id):
		files = ORDER[set_id].filter(func(f): return files.has(f))
	var factors: Dictionary = FACTORS.get(set_id, {})
	files = files.filter(func(f): return factors.has(f))
	var vp := Vector2(480, 270)
	var max_h := 0
	var texs := {}
	for f in files:
		var t: Texture2D = load(dir + f + ".png")
		texs[f] = t
		max_h = maxi(max_h, t.get_height())
	_scale = 2.0 if max_h * 2 <= 560 and max_h < 270 else 1.0
	# cor de fundo = pixel do topo da primeira camada
	var fill := ColorRect.new()
	fill.size = vp + Vector2(64, 64)
	fill.position = Vector2(-32, -32)
	fill.color = Color(0.05, 0.05, 0.1)
	if not files.is_empty():
		var img: Image = texs[files[0]].get_image()
		if img:
			fill.color = img.get_pixel(img.get_width() / 2, 1) * tint
	add_child(fill)
	for f in files:
		var t: Texture2D = texs[f]
		var tr := TextureRect.new()
		tr.texture = t
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tr.scale = Vector2(_scale, _scale)
		tr.size = Vector2(vp.x / _scale + t.get_width() * 2, t.get_height())
		tr.position = Vector2(0, vp.y - t.get_height() * _scale)
		tr.modulate = tint
		if f.contains("lights"):
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			tr.material = m
			tr.modulate = Color(1.6, 1.4, 1.0)
		add_child(tr)
		_layers.append([tr, float(factors[f]), float(t.get_width()), float(AUTOSCROLL.get(f, 0.0))])


func _process(delta: float) -> void:
	_t += delta
	var cx := 0.0
	var cy := 0.0
	if camera:
		cx = camera.get_screen_center_position().x
		cy = camera.get_screen_center_position().y
	for l in _layers:
		var tr: TextureRect = l[0]
		var w: float = l[2] * _scale
		var x: float = -(cx * l[1] + _t * l[3])
		tr.position.x = fposmod(x, w) - w
		tr.position.y = 270.0 - tr.texture.get_height() * _scale + clampf(-cy * l[1] * 0.15, -20.0, 20.0)
