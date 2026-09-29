class_name Gate
extends StaticBody2D
## Portão/grade de 1x4 tiles (8x32). Modos:
##   combat - fecha quando o jogador entra na sala com inimigos; abre ao limpar
##   lever  - fechado até uma alavanca da sala ser puxada
##   open   - decorativo, aberto

const H := 32.0

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
	r.size = Vector2(6, H)
	_shape.shape = r
	_shape.position = Vector2(4, H * 0.5)
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
		if v:
			Audio.play("gate", 0.05, -5.0)
		else:
			Audio.play("door", 0.1, -6.0, 1.1)
		FX.shake(0.08)


func _process(delta: float) -> void:
	_amount = move_toward(_amount, 1.0 if closed else 0.0, delta * 7.0)
	queue_redraw()


func _draw() -> void:
	if _amount <= 0.01:
		return
	var h := roundf(H * _amount)
	var ink := Color(0.106, 0.082, 0.157)
	var bar := Color(0.5, 0.48, 0.58)
	draw_rect(Rect2(1, 0, 6, h), ink)
	for x in [2, 5]:
		draw_rect(Rect2(x, 0, 1, h - 1), bar)
	draw_rect(Rect2(1, h - 3, 6, 3), ink)
	draw_rect(Rect2(2, h - 2, 4, 1), bar)
	var glow := Color(2.0, 0.6, 0.4) if mode == "combat" else Color(0.6, 1.2, 2.2)
	draw_rect(Rect2(3, roundf(h * 0.5) - 1, 2, 2), glow)
