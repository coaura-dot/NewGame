class_name LightShaft
extends ColorRect
## Raio de luz de janela/claraboia (shader). Desligável em Vídeo > Raios de luz.

const SHADER := preload("res://shaders/light_shaft.gdshader")


func setup(tint: Color, height: float = 150.0, width: float = 70.0) -> void:
	size = Vector2(width, height)
	position -= Vector2(width * 0.5, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("color", tint)
	m.set_shader_parameter("seed", randf() * 100.0)
	m.set_shader_parameter("skew", randf_range(-0.25, 0.25))
	material = m
	z_index = 8
	visible = bool(Settings.video("god_rays"))
	Events.settings_changed.connect(func(): visible = bool(Settings.video("god_rays")))
