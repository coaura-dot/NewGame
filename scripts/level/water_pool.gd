class_name WaterPool
extends Node2D
## Poça/lago raso com reflexo (shaders/water.gdshader). Só visual: o fundo é
## chão firme. Espirra quando algo entra.

const SHADER := preload("res://shaders/water.gdshader")

var size: Vector2 = Vector2(16, 8)
var color: Color = Color(0.22, 0.36, 0.46, 0.78)
var _rect: ColorRect
var _mat: ShaderMaterial
var _inside: Dictionary = {}


func _ready() -> void:
	z_index = 7
	add_to_group("water")
	_rect = ColorRect.new()
	_rect.size = size
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("water_color", color)
	_rect.material = _mat
	add_child(_rect)


func _process(_delta: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var h: float = vp.get_visible_rect().size.y
	var top: Vector2 = get_global_transform_with_canvas() * Vector2.ZERO
	_rect.visible = top.y < h + 4.0 and top.y + size.y > -4.0
	if not _rect.visible:
		return
	_mat.set_shader_parameter("surface_y", top.y / h)
	_mat.set_shader_parameter("px_h", 1.0 / h)


func _physics_process(_delta: float) -> void:
	var r := Rect2(global_position, size)
	for a in get_tree().get_nodes_in_group("actors"):
		var inside: bool = r.has_point(a.global_position + Vector2(0, -1))
		var key: int = a.get_instance_id()
		if inside and not _inside.has(key):
			_inside[key] = true
			if absf(a.velocity.y) > 40.0 or absf(a.velocity.x) > 60.0:
				_splash(Vector2(a.global_position.x, global_position.y), absf(a.velocity.y) > 120.0)
		elif not inside:
			_inside.erase(key)


func _splash(at: Vector2, big: bool) -> void:
	FX.burst(at, Color(0.8, 1.2, 1.6), 10 if big else 5, 140.0 if big else 90.0, Vector2.UP, 50.0, 0.4, 1.0)
	Audio.play("splash", 0.1, -6.0 if big else -10.0)
