class_name FallingPlatform
extends AnimatableBody2D
## Plataforma que treme e cai quando pisada; volta depois.

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
	r.size = Vector2(16, 3)
	_shape.shape = r
	_shape.position = Vector2(0, 1.5)
	_shape.one_way_collision = true
	add_child(_shape)
	_origin = position
	sync_to_physics = false


func _physics_process(delta: float) -> void:
	_t += delta
	match _state:
		"idle":
			var p := get_tree().get_first_node_in_group("player")
			if p and p.is_on_floor() and absf(p.global_position.x - global_position.x) < 10.0 and absf(p.global_position.y - global_position.y) < 3.0:
				_state = "shaking"
				_t = 0.0
		"shaking":
			position = _origin + Vector2(randf_range(-1, 1), 0)
			if _t > 0.45:
				_state = "falling"
				_vy = 0.0
		"falling":
			_vy += 450.0 * delta
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
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-8, 0, 16, 3), Color(0.09, 0.07, 0.12))
	draw_rect(Rect2(-7, 0, 14, 2), Color(0.8, 0.62, 0.4) if _state == "idle" else Color(1.0, 0.55, 0.4))
