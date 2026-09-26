class_name Gate
extends StaticBody2D
## Portão/grade de 1x4 tiles. Modos:
##   combat - fecha quando o jogador entra na sala com inimigos; abre ao limpar
##   lever  - fechado até uma alavanca da sala ser puxada
##   open   - decorativo, aberto

var mode: String = "combat"
var room_index: int = -1
var closed: bool = false
var _amount: float = 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 64)
	_shape.shape = r
	_shape.position = Vector2(8, 32)
	add_child(_shape)
	add_to_group("gates")
	set_closed(mode == "lever", true)
	z_index = 3


func set_closed(v: bool, instant: bool = false) -> void:
	if closed == v and not instant:
		return
	closed = v
	_shape.set_deferred("disabled", not v)
	if instant:
		_amount = 1.0 if v else 0.0
	else:
		Audio.play("door", 0.1, -6.0, 0.8 if v else 1.1)
		FX.shake(0.1)


func _process(delta: float) -> void:
	_amount = move_toward(_amount, 1.0 if closed else 0.0, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	if _amount <= 0.01:
		return
	var h := 64.0 * _amount
	for i in 3:
		var x := 3.0 + i * 5.0
		draw_rect(Rect2(x, 0, 3, h), Color(0.35, 0.3, 0.4))
		draw_rect(Rect2(x + 1, 0, 1, h), Color(0.6, 0.55, 0.7))
	draw_rect(Rect2(1, h - 4, 14, 4), Color(0.3, 0.25, 0.35))
	var glow := Color(2.0, 0.6, 0.4, 0.8) if mode == "combat" else Color(0.6, 1.2, 2.4, 0.8)
	draw_circle(Vector2(8, h * 0.5), 2.5, glow)
