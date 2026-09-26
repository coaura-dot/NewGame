class_name PostFX
extends CanvasLayer
## Controla o pós-processamento (shader post_fx) e o bloom (WorldEnvironment),
## aplicando as opções de vídeo em tempo real.

const SHADER := preload("res://shaders/post_fx.gdshader")

var camera: GameCamera = null
var player: Node2D = null
var env: Environment
var world_env: WorldEnvironment
var rect: ColorRect
var mat: ShaderMaterial
var grade: Dictionary = {}
var outdoor: bool = true
var fade: float = 0.0
var _dash_blur: float = 0.0


func build(parent: Node, dimension: Dictionary, is_outdoor: bool) -> void:
	layer = 5
	outdoor = is_outdoor
	grade = dimension.get("grade", {})
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	for i in 7:
		env.set_glow_level(i, [0.0, 1.0, 0.8, 1.0, 0.6, 0.3, 0.0][i])
	world_env = WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)
	apply_settings()
	Events.settings_changed.connect(apply_settings)
	Events.player_dash_changed.connect(func(_c, _m): _dash_blur = 1.0)


func apply_settings() -> void:
	env.glow_enabled = bool(Settings.video("bloom"))
	env.glow_intensity = float(Settings.video("bloom_intensity"))
	mat.set_shader_parameter("motion_blur_on", bool(Settings.video("motion_blur")))
	mat.set_shader_parameter("rays_on", bool(Settings.video("god_rays")))
	mat.set_shader_parameter("ray_strength", 0.35 if outdoor else 0.18)
	mat.set_shader_parameter("vignette_on", bool(Settings.video("vignette")))
	mat.set_shader_parameter("grain_on", bool(Settings.video("film_grain")))
	var tint: Array = grade.get("tint", [1, 1, 1])
	mat.set_shader_parameter("grade_tint", Vector3(tint[0], tint[1], tint[2]))
	mat.set_shader_parameter("saturation", float(grade.get("saturation", 1.0)))
	mat.set_shader_parameter("contrast", float(grade.get("contrast", 1.0)))
	mat.set_shader_parameter("hue_shift", float(grade.get("hue_shift", 0.0)))


func _process(delta: float) -> void:
	if mat == null:
		return
	var strength: float = float(Settings.video("motion_blur_strength"))
	if camera and Settings.video("motion_blur"):
		var v := camera.screen_velocity / Vector2(480.0, 270.0)
		mat.set_shader_parameter("blur_vec", (v * 0.012 * strength).limit_length(0.02))
	else:
		mat.set_shader_parameter("blur_vec", Vector2.ZERO)
	_dash_blur = maxf(_dash_blur - delta * 6.0, 0.0)
	mat.set_shader_parameter("dash_blur", _dash_blur * strength)
	if player and camera:
		var screen: Vector2 = player.get_global_transform_with_canvas().origin
		mat.set_shader_parameter("dash_center", screen / Vector2(480.0, 270.0))
	var chroma := FX.flash_amount if Settings.video("chromatic_aberration") else 0.0
	mat.set_shader_parameter("chroma", chroma)
	mat.set_shader_parameter("fade", fade)
