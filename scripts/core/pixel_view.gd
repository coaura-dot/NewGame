class_name PixelView
extends Node
## Renderiza o mundo numa tela interna de 320x180 (como Celeste) e exibe
## ampliada em escala inteira. A câmera anda em pixels inteiros dentro da
## tela interna; a fração que sobra vira um deslocamento da imagem ampliada,
## então a rolagem fica suave sem "tremer" a pixel art.
##
## Também aplica o pós-processamento (bloom HDR em meia resolução, raios de
## luz, borrão de movimento, gradação de cor da dimensão, flash e fade).
## Tudo que é do mundo deve ser filho de `world`.

const W := 320
const H := 180
const MARGIN := 2
const SHADER := preload("res://shaders/display.gdshader")
const BLOOM := preload("res://shaders/bloom.gdshader")

static var current: PixelView = null

var viewport: SubViewport
var world: Node2D
var camera: Node = null ## GameCamera (ou qualquer nó com render_center())
var display: TextureRect
var layer: CanvasLayer
var mat: ShaderMaterial
var fade: float = 0.0
var grade: Dictionary = {}
var outdoor: bool = true
var ray_origin: Vector2 = Vector2(0.8, -0.3)
var _bloom_vp: SubViewport
var _bloom_rect: ColorRect
var _cam_int: Vector2 = Vector2.ZERO
var _last_center: Vector2 = Vector2.ZERO
var _blur: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "PixelView"


func _ready() -> void:
	current = self
	process_priority = 1000 ## depois de todo mundo mexer na câmera
	viewport = SubViewport.new()
	viewport.name = "World"
	viewport.size = Vector2i(W + MARGIN * 2, H + MARGIN * 2)
	viewport.use_hdr_2d = true
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.physics_object_picking = false
	viewport.audio_listener_enable_2d = true
	add_child(viewport)
	world = Node2D.new()
	world.name = "WorldRoot"
	viewport.add_child(world)
	# bloom em meia resolução
	_bloom_vp = SubViewport.new()
	_bloom_vp.name = "Bloom"
	_bloom_vp.size = Vector2i((W + MARGIN * 2) / 2, (H + MARGIN * 2) / 2)
	_bloom_vp.use_hdr_2d = true
	_bloom_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bloom_vp.transparent_bg = false
	add_child(_bloom_vp)
	_bloom_rect = ColorRect.new()
	_bloom_rect.size = Vector2(_bloom_vp.size)
	var bm := ShaderMaterial.new()
	bm.shader = BLOOM
	bm.set_shader_parameter("src", viewport.get_texture())
	_bloom_rect.material = bm
	_bloom_vp.add_child(_bloom_rect)
	# exibição
	layer = CanvasLayer.new()
	layer.layer = -1
	layer.name = "Display"
	add_child(layer)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.size = Vector2(W + MARGIN * 2, H + MARGIN * 2)
	display.position = -Vector2(MARGIN, MARGIN)
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("world_lin", viewport.get_texture())
	mat.set_shader_parameter("bloom_tex", _bloom_vp.get_texture())
	display.material = mat
	layer.add_child(display)
	apply_settings()
	Events.settings_changed.connect(apply_settings)


func _exit_tree() -> void:
	if current == self:
		current = null


func set_grade(g: Dictionary, is_outdoor: bool) -> void:
	grade = g
	outdoor = is_outdoor
	apply_settings()


func apply_settings() -> void:
	if mat == null:
		return
	var bloom_on := bool(Settings.video("bloom"))
	mat.set_shader_parameter("bloom_amount", float(Settings.video("bloom_intensity")) if bloom_on else 0.0)
	_bloom_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if bloom_on else SubViewport.UPDATE_DISABLED
	mat.set_shader_parameter("motion_blur_on", bool(Settings.video("motion_blur")))
	mat.set_shader_parameter("rays_on", bool(Settings.video("god_rays")) and bloom_on)
	mat.set_shader_parameter("ray_strength", 0.3 if outdoor else 0.15)
	mat.set_shader_parameter("ray_origin", ray_origin)
	mat.set_shader_parameter("vignette_on", bool(Settings.video("vignette")))
	var tint: Array = grade.get("tint", [1, 1, 1])
	mat.set_shader_parameter("grade_tint", Vector3(tint[0], tint[1], tint[2]))
	mat.set_shader_parameter("saturation", float(grade.get("saturation", 1.0)))
	mat.set_shader_parameter("contrast", float(grade.get("contrast", 1.0)))
	mat.set_shader_parameter("hue_shift", float(grade.get("hue_shift", 0.0)))


func _process(delta: float) -> void:
	var center := Vector2(W, H) * 0.5
	if camera and is_instance_valid(camera):
		center = camera.render_center()
	var tl := center - Vector2(W, H) * 0.5
	var ti := tl.floor()
	var frac := tl - ti
	if not bool(Settings.video("smooth_camera")):
		ti = tl.round()
		frac = Vector2.ZERO
	_cam_int = ti
	viewport.canvas_transform = Transform2D(0.0, -ti + Vector2(MARGIN, MARGIN))
	display.position = -Vector2(MARGIN, MARGIN) - frac
	# borrão de movimento pela velocidade da câmera (em UV da textura)
	var vel := (center - _last_center) / maxf(delta, 0.0001)
	_last_center = center
	var want := Vector2.ZERO
	if Settings.video("motion_blur") and vel.length() > 120.0:
		want = (vel / Vector2(W + MARGIN * 2, H + MARGIN * 2)) * 0.012 * float(Settings.video("motion_blur_strength"))
	_blur = _blur.lerp(want.limit_length(0.012), 1.0 - exp(-delta * 20.0))
	mat.set_shader_parameter("blur_vec", _blur)
	mat.set_shader_parameter("chroma", FX.flash_amount * 0.6 if Settings.video("chromatic_aberration") else 0.0)
	mat.set_shader_parameter("flash", FX.screen_flash)
	mat.set_shader_parameter("fade", fade)


## Canto superior esquerdo (inteiro) da tela interna em coordenadas de mundo.
func view_origin() -> Vector2:
	return _cam_int


## Posição do mouse em coordenadas de mundo.
func mouse_world() -> Vector2:
	var m := get_viewport().get_mouse_position()
	var off := display.position + Vector2(MARGIN, MARGIN)
	return _cam_int + (m - off)


## Converte ponto do mundo para a tela (coordenadas lógicas 320x180).
func world_to_screen(p: Vector2) -> Vector2:
	return p - _cam_int + display.position + Vector2(MARGIN, MARGIN)
