class_name FallingPlatform
extends AnimatableBody2D
## Plataforma que treme e cai quando pisada; volta depois.

const TEX := preload("res://assets/art/props/traps/falling_platform.png")

var _origin: Vector2
var _state: String = "idle"
var _t: float = 0.0
var _vy: float = 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = Layers.ONE_WAY
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 6)
	_shape.shape = r
	_shape.position = Vector2(0, 3)
	_shape.one_way_collision = true
	add_child(_shape)
	_origin = position
	sync_to_physics = false


func _physics_process(delta: float) -> void:
	_t += delta
	match _state:
		"idle":
			var p := get_tree().get_first_node_in_group("player")
			if p and p.is_on_floor() and absf(p.global_position.x - global_position.x) < 20.0 and absf(p.global_position.y - global_position.y) < 4.0:
				_state = "shaking"
				_t = 0.0
		"shaking":
			position = _origin + Vector2(randf_range(-1, 1), 0)
			if _t > 0.45:
				_state = "falling"
				_vy = 0.0
		"falling":
			_vy += 900.0 * delta
			position.y += _vy * delta
			if _t > 2.0:
				_state = "gone"
				_shape.set_deferred("disabled", true)
				visible = false
		"gone":
			if _t > 3.5:
				position = _origin
				_shape.set_deferred("disabled", false)
				visible = true
				_state = "idle"
				FX.burst(global_position, Color(1.2, 1.2, 1.2), 6, 60.0)


func _draw() -> void:
	var frame := int(_t * 12.0) % 4 if _state != "idle" else 0
	draw_texture_rect_region(TEX, Rect2(-16, 0, 32, 10), Rect2(frame * 32, 0, 32, 10))
