class_name LightUtil
extends RefCounted
## Luzes do mundo. Na tela limpa de 320x180 as luzes são sutis: um brilho
## aditivo pequeno (sempre barato) e, opcionalmente, PointLight2D com sombra
## (Opções > Vídeo > Luzes dinâmicas / Sombras).

static var _radial: GradientTexture2D
static var _soft: GradientTexture2D


static func radial() -> GradientTexture2D:
	if _radial == null:
		_radial = _make(128, [0.0, 0.3, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	return _radial


static func soft() -> GradientTexture2D:
	if _soft == null:
		_soft = _make(64, [0.0, 1.0], [Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	return _soft


static func _make(size: int, offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


## Cria uma luz (ou null se luzes dinâmicas estiverem desligadas).
## scale ~1.0 => raio de ~40 px na tela interna.
static func make_light(color: Color, energy: float = 1.0, scale: float = 1.0, shadows: bool = false) -> PointLight2D:
	if not Settings.video("dynamic_lights"):
		return null
	var l := PointLight2D.new()
	l.texture = radial()
	l.color = color
	l.energy = energy * 0.6
	l.texture_scale = scale * 0.65
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.shadow_enabled = shadows and bool(Settings.video("shadows"))
	l.shadow_filter = Light2D.SHADOW_FILTER_NONE
	return l


## Brilho aditivo simples (um sprite radial), usado para halos de lanternas,
## cristais e magias. Cores HDR geram bloom.
static func make_glow(color: Color, radius: float = 12.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = soft()
	s.scale = Vector2.ONE * (radius * 2.0 / 64.0)
	s.modulate = color
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return s
