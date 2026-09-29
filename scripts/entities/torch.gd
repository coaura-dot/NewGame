class_name Torch
extends Node2D
## Tocha na parede: suporte + chaminha pixelada + brilho suave (bloom).

const TEX := preload("res://assets/art/props/torch.png")

var color: Color = Color(1.8, 0.9, 0.4)
var _light: PointLight2D
var _glow: Sprite2D
var _t: float = 0.0


func _ready() -> void:
	z_index = -5
	_t = randf() * 10.0
	_light = LightUtil.make_light(Color(color.r, color.g, color.b).clamp(), 0.7, 1.35, true)
	if _light:
		_light.position = Vector2(0, -3)
		add_child(_light)
	_glow = LightUtil.make_glow(Color(color.r * 0.6, color.g * 0.5, color.b * 0.4, 0.35), 9.0)
	_glow.position = Vector2(0, -3)
	add_child(_glow)


func _process(delta: float) -> void:
	_t += delta
	var f := 1.0 + 0.1 * sin(_t * 11.0) + 0.06 * sin(_t * 23.0)
	if _light:
		_light.energy = 0.6 * f
	_glow.scale = Vector2.ONE * (18.0 / 64.0) * f
	queue_redraw()


func _draw() -> void:
	draw_texture(TEX, Vector2(-3, -1))
	var k := int(_t * 10.0) % 3
	var hot := Color(minf(color.r * 1.3, 3.0), minf(color.g * 1.3, 3.0), minf(color.b * 1.2, 3.0))
	draw_rect(Rect2(-1, -3, 2, 2), color)
	draw_rect(Rect2(-1 + (1 if k == 1 else 0), -4 - (1 if k == 2 else 0), 1, 1), color)
	draw_rect(Rect2(0, -2, 1, 1), hot)
