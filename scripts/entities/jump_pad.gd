class_name JumpPad
extends Area2D
## Trampolim: lança o jogador (e restaura dash).

const IDLE := preload("res://assets/art/props/traps/trampoline_idle.png")
const JUMP := preload("res://assets/art/props/traps/trampoline_jump.png")
const FORCE := 520.0

var _anim: float = -1.0


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(22, 8)
	cs.shape = r
	cs.position = Vector2(0, -6)
	add_child(cs)
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if b is Player and b.velocity.y * b.g_dir >= -10.0:
		b._set_vy(-FORCE)
		b.var_jump_t = 0.0
		b.refill_dash()
		if b.state == Player.State.DASH:
			b._set_state(Player.State.NORMAL)
		_anim = 0.0
		Audio.play("jump", 0.05, 0.0, 0.7)
		FX.burst(global_position, Color(1.6, 1.6, 1.2), 8, 120.0, Vector2.UP, 40.0)


func _process(delta: float) -> void:
	if _anim >= 0.0:
		_anim += delta * 20.0
		if _anim >= 8.0:
			_anim = -1.0
	queue_redraw()


func _draw() -> void:
	if _anim >= 0.0:
		draw_texture_rect_region(JUMP, Rect2(-14, -28, 28, 28), Rect2(int(_anim) * 28, 0, 28, 28))
	else:
		draw_texture(IDLE, Vector2(-14, -28))
