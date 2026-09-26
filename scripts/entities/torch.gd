class_name Torch
extends Node2D
## Tocha/lanterna: chama procedural + luz com cintilação (sombras opcionais).

var color: Color = Color(1.8, 0.9, 0.4)
var _light: PointLight2D
var _t: float = 0.0
var _flames: Array = []


func _ready() -> void:
	z_index = -5
	_t = randf() * 10.0
	_light = LightUtil.make_light(Color(color.r, color.g, color.b).clamp(), 0.9, 1.0, true)
	if _light:
		add_child(_light)
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _process(delta: float) -> void:
	_t += delta
	if _light:
		_light.energy = 1.0 + 0.12 * sin(_t * 11.0) + 0.08 * sin(_t * 23.0)

	for f in _flames:
		f[2] += delta
		f[0].y -= 22.0 * delta
		f[0].x += sin(_t * 8.0 + f[1] * 10.0) * 6.0 * delta
	_flames = _flames.filter(func(f): return f[2] < f[1])
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-1, 0, 2, 3), Color(0.35, 0.25, 0.18))
	var h := 2.0 + (1.0 if fmod(_t * 9.0, 2.0) > 1.0 else 0.0)
	draw_rect(Rect2(-1, -h, 2, h), Color(color.r, color.g, color.b))
	draw_rect(Rect2(0, -h - 1, 1, 1), Color(3.0, 2.6, 1.6))
