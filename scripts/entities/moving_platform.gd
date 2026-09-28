class_name MovingPlatform
extends AnimatableBody2D
## Plataforma móvel (atravessável por baixo). Anda de ida e volta em pixels
## inteiros; o herói em cima é carregado exatamente o mesmo tanto.

const INK := Color(0.106, 0.082, 0.157)

var travel: Vector2 = Vector2(48, 0)
var period: float = 3.2
var width: float = 24.0
var delta_pos: Vector2 = Vector2.ZERO
var _origin: Vector2
var _t: float = 0.0


func _ready() -> void:
	collision_layer = Layers.ONE_WAY
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 3)
	cs.shape = r
	cs.position = Vector2(width * 0.5, 1.5)
	cs.one_way_collision = true
	add_child(cs)
	sync_to_physics = false
	process_physics_priority = -20 ## antes do herói (que lê delta_pos)
	add_to_group("moving_platform")
	_origin = position.round()
	position = _origin
	z_index = 2


func _physics_process(delta: float) -> void:
	_t += delta
	var np := (_origin + travel * (0.5 - 0.5 * cos(_t / period * TAU))).round()
	delta_pos = np - position
	position = np
	queue_redraw()


func _draw() -> void:
	# trilho pontilhado
	var a := _origin - position
	var b := _origin + travel - position
	var n := int(a.distance_to(b) / 4.0)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1)).round() + Vector2(width * 0.5, 1)
		draw_rect(Rect2(p, Vector2.ONE), Color(0.3, 0.28, 0.38, 0.6))
	draw_rect(Rect2(0, 0, width, 4), INK)
	draw_rect(Rect2(1, 0, width - 2, 2), Color(0.55, 0.62, 0.78))
	draw_rect(Rect2(1, 0, width - 2, 1), Color(0.8, 0.86, 0.98))
	draw_rect(Rect2(width * 0.5 - 1, 2, 2, 1), Color(1.6, 1.2, 0.5))
