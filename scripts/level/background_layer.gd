class_name BackgroundLayer
extends CanvasLayer
## Fundo em parallax por bioma (assets/art/bg/<bioma>/: 0_sky, 1_far, 2_mid,
## gerados por tools/pixel_art.py). Fica DENTRO da tela interna 320x180 e
## anda em pixels inteiros junto com a câmera, em velocidades diferentes.

const DIR := "res://assets/art/bg/%s/"
const FACTORS := {"0_sky": 0.0, "1_far": 0.12, "2_mid": 0.3}
const VFACTORS := {"0_sky": 0.0, "1_far": 0.04, "2_mid": 0.08}

var camera: Node = null
var level_height: float = 192.0
var _layers: Array = [] ## [TextureRect, factor, vfactor, tex_w, fill]
var _fill: ColorRect


func build(biome_id: String) -> void:
	layer = -10
	follow_viewport_enabled = false
	var dir := DIR % biome_id
	if not ResourceLoader.exists(dir + "0_sky.png"):
		dir = DIR % "castelo"
	var vp := Vector2(PixelView.W + PixelView.MARGIN * 2, PixelView.H + PixelView.MARGIN * 2)
	_fill = ColorRect.new()
	_fill.size = vp + Vector2(8, 8)
	_fill.position = Vector2(-4, -4)
	add_child(_fill)
	for f in ["0_sky", "1_far", "2_mid"]:
		var t: Texture2D = load(dir + f + ".png")
		if t == null:
			continue
		if f == "0_sky":
			var img := t.get_image()
			if img:
				_fill.color = img.get_pixel(1, 1)
		var tr := TextureRect.new()
		tr.texture = t
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tr.size = Vector2(vp.x + t.get_width() * 2, t.get_height())
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		# faixa sólida abaixo das silhuetas (evita buraco com o parallax vertical)
		var under := ColorRect.new()
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if f != "0_sky":
			var img2 := t.get_image()
			if img2:
				under.color = img2.get_pixel(0, img2.get_height() - 1)
			under.size = Vector2(tr.size.x, 40)
			under.position = Vector2(0, t.get_height())
			tr.add_child(under)
		_layers.append([tr, float(FACTORS[f]), float(VFACTORS[f]), float(t.get_width())])


func _process(_delta: float) -> void:
	var c := Vector2(PixelView.W, PixelView.H) * 0.5
	var frac := Vector2.ZERO
	if camera and is_instance_valid(camera):
		c = camera.render_center()
	if PixelView.current:
		var tl := c - Vector2(PixelView.W, PixelView.H) * 0.5
		frac = tl - PixelView.current.view_origin()
	for l in _layers:
		var tr: TextureRect = l[0]
		var w: float = l[3]
		# posição ideal = -câmera * fator; compensa a fração que a tela
		# interna já desloca, e arredonda (pixel art sem tremer)
		var x: float = fposmod(-c.x * float(l[1]) + frac.x, w) - w
		var dy: float = clampf(-(c.y - level_height * 0.5) * float(l[2]), -10.0, 10.0)
		tr.position = Vector2(roundf(x), roundf(dy + frac.y) + PixelView.MARGIN)
