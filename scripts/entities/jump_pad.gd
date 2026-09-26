class_name JumpPad
extends Area2D
## Mola: lança o jogador (e restaura o dash).

const TEX := preload("res://assets/art/props/spring.png")
const FORCE := 280.0

var _anim: float = -1.0


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 4)
	cs.shape = r
	cs.position = Vector2(0, -3)
	add_child(cs)
	body_entered.connect(_on_body)
	z_index = -1


func _on_body(b: Node) -> void:
	if b is Player and b.velocity.y * b.g_dir >= -10.0:
		b._set_vy(-FORCE)
		b.var_jump_t = 0.0
		b.on_ground = false
		b.refill_dash()
		if b.state == Player.State.DASH:
			b._set_state(Player.State.NORMAL)
		b.rig.bump(Vector2(0.7, 1.4))
		_anim = 0.0
		Audio.play("jump", 0.05, 0.0, 0.7)
		FX.burst(global_position + Vector2(0, -4), Color(1.4, 1.4, 1.2), 4, 60.0, Vector2.UP, 40.0)


func _process(delta: float) -> void:
	if _anim >= 0.0:
		_anim += delta * 18.0
		if _anim >= 4.0:
			_anim = -1.0
	queue_redraw()


func _draw() -> void:
	var f: int = [1, 2, 3, 0][int(_anim)] if _anim >= 0.0 else 0
	draw_texture_rect_region(TEX, Rect2(-6, -8, 12, 8), Rect2(f * 12, 0, 12, 8))
