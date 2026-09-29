class_name BackgroundLayer
extends CanvasLayer
## Fundo limpo e procedural: gradiente de céu + 2 camadas de silhuetas em
## parallax (colinas, torres, árvores conforme o bioma). Poucas cores, sem
## ruído visual — o foco fica no primeiro plano.

const W := LevelConst.VIEW.x
const H := LevelConst.VIEW.y
const PALETTES := {
	"cemetery": [Color(0.42, 0.52, 0.66), Color(0.74, 0.8, 0.82), Color(0.33, 0.4, 0.5), Color(0.25, 0.3, 0.38)],
	"castle": [Color(0.3, 0.33, 0.45), Color(0.52, 0.55, 0.66), Color(0.24, 0.26, 0.36), Color(0.19, 0.2, 0.29)],
	"town": [Color(0.46, 0.4, 0.62), Color(0.94, 0.72, 0.6), Color(0.36, 0.3, 0.46), Color(0.27, 0.22, 0.34)],
	"temple": [Color(0.55, 0.62, 0.8), Color(0.98, 0.88, 0.7), Color(0.66, 0.55, 0.5), Color(0.52, 0.42, 0.4)],
}

var camera: Camera2D = null
var bg_set: String = "town"
var tint: Color = Color.WHITE
var _pal: Array = []
var _far: PackedFloat32Array
var _near: PackedFloat32Array
var _draw: Control
var _t: float = 0.0


func build(set_id: String, color: Color) -> void:
	bg_set = set_id
	tint = color
	layer = -10
	_pal = PALETTES.get(set_id, PALETTES["castle"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(set_id)
	_far = _heights(rng, 64, 30.0, 70.0, set_id in ["castle", "town"])
	_near = _heights(rng, 64, 12.0, 42.0, set_id == "town")
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)


func _heights(rng: RandomNumberGenerator, n: int, lo: float, hi: float, towers: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var h := (lo + hi) * 0.5
	for i in n:
		h = clampf(h + rng.randf_range(-6, 6), lo, hi)
		if towers and rng.randf() < 0.12:
			out.append(h + rng.randf_range(20, 36))
		else:
			out.append(h)
	return out


func _process(delta: float) -> void:
	_t += delta
	if _draw:
		_draw.queue_redraw()


func _on_draw() -> void:
	var top: Color = _pal[0] * tint
	var bottom: Color = _pal[1] * tint
	var bands := 12
	for i in bands:
		var c := top.lerp(bottom, float(i) / (bands - 1))
		_draw.draw_rect(Rect2(0, H * i / bands, W, H / bands + 1), c)
	var cx := 0.0
	if camera:
		cx = camera.get_screen_center_position().x
	_layer(_far, cx * 0.1, 16.0, _pal[2] * tint, 40.0)
	_layer(_near, cx * 0.25, 12.0, _pal[3] * tint, 10.0)


func _layer(heights: PackedFloat32Array, scroll: float, step: float, c: Color, base: float) -> void:
	var n := heights.size()
	var total := n * step
	var off := fposmod(scroll, total)
	var x := -off
	var i := 0
	while x < W + step:
		var h: float = heights[i % n]
		_draw.draw_rect(Rect2(roundf(x), roundf(H - base - h), step, h + base), c)
		x += step
		i += 1
