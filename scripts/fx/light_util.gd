class_name LightUtil
extends RefCounted
## Texturas de luz compartilhadas e criação de PointLight2D respeitando as
## opções de vídeo (luzes dinâmicas / sombras).

## Camadas de luz dos CanvasItems: o herói fica na 2 para que a luz da
## própria chama não o pinte de laranja (ela só ilumina o mundo, camada 1).
const LIT_WORLD := 1
const LIT_ACTORS := 2

static var _radial: GradientTexture2D
static var _soft: GradientTexture2D


static func radial() -> GradientTexture2D:
	if _radial == null:
		_radial = _make(256, [0.0, 0.35, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	return _radial


static func soft() -> GradientTexture2D:
	if _soft == null:
		_soft = _make(128, [0.0, 1.0], [Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
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
static func make_light(color: Color, energy: float = 1.0, scale: float = 1.0, shadows: bool = false) -> PointLight2D:
	if not Settings.video("dynamic_lights"):
		return null
	var l := PointLight2D.new()
	l.texture = radial()
	l.color = color
	l.energy = energy * 0.7
	l.texture_scale = scale * 0.4
	l.shadow_enabled = shadows and bool(Settings.video("shadows"))
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_filter_smooth = 2.0
	# altura da luz (unidades): com os mapas de normais do terreno, a luz bate
	# de lado nas pedras e realça o relevo (reflexo nas bordas dos blocos)
	l.height = 26.0
	# ilumina o cenário (camada 1) e os personagens (camada 2)
	l.range_item_cull_mask = LIT_WORLD | LIT_ACTORS
	return l
