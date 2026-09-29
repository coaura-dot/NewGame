class_name BackgroundLayer
extends CanvasLayer
## Fundo em parallax por bioma (assets/art/bg/<bioma>/: 0_sky, 1_far, 2_mid,
## 3_near + um "_glow" de cada, gerados por tools/pixel_art.py --world).
## Fica DENTRO da tela interna 320x180 e anda em pixels inteiros junto com a
## câmera, em velocidades diferentes.
## Estética escura: longe = névoa clara e sem contraste, perto = quase preto.
## As camadas "_glow" são somadas com cor HDR (bloom): lua, estrelas, janelas,
## cristais, espíritos da floresta. Entre as camadas passa uma névoa animada.

const DIR := "res://assets/art/bg/%s/"
const LAYERS := ["0_sky", "1_far", "2_mid", "3_near"]
const FACTORS := {"0_sky": 0.0, "1_far": 0.1, "2_mid": 0.24, "3_near": 0.45}
const VFACTORS := {"0_sky": 0.0, "1_far": 0.03, "2_mid": 0.07, "3_near": 0.12}
const GLOW_HDR := Color(1.6, 1.6, 1.6)
const FOG := preload("res://shaders/fog.gdshader")
## névoa: [depois da camada, densidade, começo da faixa, escala, velocidade, parallax]
const FOGS := [["1_far", 0.42, 0.3, 1.3, 0.012, 0.16], ["2_mid", 0.3, 0.5, 0.8, 0.02, 0.34]]

var camera: Node = null
var level_height: float = 192.0
var fog_color: Color = Color(0.3, 0.35, 0.5)
var _layers: Array = [] ## [TextureRect, factor, vfactor, tex_w]
var _fogs: Array = [] ## [ColorRect, factor]
var _fill: ColorRect
var _root: Control ## tudo fica aqui dentro: dá para escurecer o fundo de uma vez
var _dim_tween: Tween


func build(biome_id: String) -> void:
	layer = -10
	follow_viewport_enabled = false
	var dir := DIR % biome_id
	if not ResourceLoader.exists(dir + "0_sky.png"):
		dir = DIR % "castelo"
	var vp := Vector2(PixelView.W + PixelView.MARGIN * 2, PixelView.H + PixelView.MARGIN * 2)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_fill = ColorRect.new()
	_fill.size = vp + Vector2(8, 8)
	_fill.position = Vector2(-4, -4)
	_root.add_child(_fill)
	for f in LAYERS:
		if not ResourceLoader.exists(dir + f + ".png"):
			continue
		var t: Texture2D = load(dir + f + ".png")
		if t == null:
			continue
		var img := t.get_image()
		if f == "0_sky" and img:
			_fill.color = img.get_pixel(1, 1)
			# névoa = cor do horizonte, um pouco mais clara
			fog_color = img.get_pixel(img.get_width() / 2, img.get_height() - 2).lightened(0.12)
		var tr := _tiled(t, vp)
		_root.add_child(tr)
		# faixa sólida abaixo das silhuetas (evita buraco com o parallax vertical)
		if f != "0_sky" and img:
			var under := ColorRect.new()
			under.mouse_filter = Control.MOUSE_FILTER_IGNORE
			under.color = img.get_pixel(0, img.get_height() - 1)
			if under.color.a < 0.5:
				under.color = Color(0, 0, 0, 0)
			under.size = Vector2(tr.size.x, 40)
			under.position = Vector2(0, t.get_height())
			tr.add_child(under)
		var gp: String = dir + f + "_glow.png"
		if ResourceLoader.exists(gp):
			var gt: Texture2D = load(gp)
			var gr := _tiled(gt, vp)
			gr.modulate = GLOW_HDR
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			gr.material = m
			tr.add_child(gr)
		_layers.append([tr, float(FACTORS[f]), float(VFACTORS[f]), float(t.get_width())])
		for fd in FOGS:
			if fd[0] == f:
				_add_fog(vp, float(fd[1]), float(fd[2]), float(fd[3]), float(fd[4]), float(fd[5]))


func _tiled(t: Texture2D, vp: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tr.size = Vector2(vp.x + t.get_width() * 2, t.get_height())
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _add_fog(vp: Vector2, density: float, top: float, scale: float, speed: float, factor: float) -> void:
	if not bool(Settings.video("ambient_particles")):
		return
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = vp
	var m := ShaderMaterial.new()
	m.shader = FOG
	m.set_shader_parameter("fog_color", Color(fog_color.r, fog_color.g, fog_color.b, 1.0))
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("band_top", top)
	m.set_shader_parameter("scale", scale)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("px_size", vp)
	r.material = m
	_root.add_child(r)
	_fogs.append([r, factor])


## Escurece o fundo (salas sombrias). k = 1 normal.
func set_dim(k: float, dur: float = 0.7) -> void:
	if _root == null:
		return
	var target := Color(k, k, minf(k * 1.1, 1.0), 1.0)
	if _dim_tween and _dim_tween.is_valid():
		_dim_tween.kill()
	if dur <= 0.0:
		_root.modulate = target
		return
	_dim_tween = create_tween()
	_dim_tween.tween_property(_root, "modulate", target, dur).set_trans(Tween.TRANS_SINE)


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
		var lim: float = 10.0 + 20.0 * float(l[2])
		var dy: float = clampf(-(c.y - level_height * 0.5) * float(l[2]), -lim, lim)
		tr.position = Vector2(roundf(x), roundf(dy + frac.y) + PixelView.MARGIN)
	for f in _fogs:
		var r: ColorRect = f[0]
		var m: ShaderMaterial = r.material
		m.set_shader_parameter("scroll", (c * float(f[1])).round())
