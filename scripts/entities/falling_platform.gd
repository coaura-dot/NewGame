class_name FallingPlatform
extends AnimatableBody2D
## Plataforma que treme e cai quando pisada; volta depois.

var _origin: Vector2
var _state: String = "idle"
var _t: float = 0.0
var _vy: float = 0.0
var _shape: CollisionShape2D
const W := 16.0


func _ready() -> void:
	collision_layer = Layers.ONE_WAY
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(W, 3)
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
			if p and p.grounded() and absf(p.global_position.x - global_position.x) < W * 0.5 + 4.0 and absf(p.global_position.y - global_position.y) < 2.0:
				_state = "shaking"
				_t = 0.0
				if "emote" in p:
					p.emote.show_emote("!?", 0.5)
		"shaking":
			position = _origin + Vector2(randi_range(-1, 1), 0)
			if _t > 0.45:
				_state = "falling"
				position = _origin
				_vy = 0.0
		"falling":
			_vy += 500.0 * delta
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
				FX.burst(global_position, Color(1.2, 1.2, 1.2), 4, 30.0)
	queue_redraw()


func _draw() -> void:
	var ink := Color(0.106, 0.082, 0.157)
	var wood := Color(0.62, 0.42, 0.28)
	draw_rect(Rect2(-W * 0.5, 0, W, 4), ink)
	draw_rect(Rect2(-W * 0.5 + 1, 0, W - 2, 2), wood)
	draw_rect(Rect2(-W * 0.5 + 1, 0, W - 2, 1), Color(0.78, 0.58, 0.4))
	if _state == "shaking":
		draw_rect(Rect2(-2, 1, 1, 1), ink)
		draw_rect(Rect2(3, 1, 1, 1), ink)
