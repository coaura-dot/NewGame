class_name JumpPad
extends Area2D
## Mola: lança o jogador e recarrega o dash.

const FORCE := 250.0

var _anim: float = 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, 3)
	cs.shape = r
	cs.position = Vector2(0, -2)
	add_child(cs)
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if b is Player and b.velocity.y * b.g_dir >= -10.0:
		b._set_vy(-FORCE)
		b.var_jump_t = 0.0
		b.refill_dash()
		if b.state == Player.State.DASH:
			b._set_state(Player.State.NORMAL)
		_anim = 1.0
		Audio.play("jump", 0.05, 0.0, 0.7)


func _process(delta: float) -> void:
	_anim = maxf(_anim - delta * 5.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var h := 2.0 + _anim * 3.0
	draw_rect(Rect2(-4, -1, 8, 1), Color(0.35, 0.3, 0.4))
	draw_rect(Rect2(-1, -1 - h, 2, h), Color(0.7, 0.7, 0.75))
	draw_rect(Rect2(-4, -2 - h, 8, 2), Color(1.0, 0.45, 0.35))
