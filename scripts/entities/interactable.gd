class_name Interactable
extends Area2D
## Base para coisas com que o jogador interage (Cima/W/Enter perto delas).
## Mostra o texto de ação quando o jogador está perto.

const FONT := preload("res://assets/fonts/kenney_mini.ttf")

var prompt: String = "Interagir"
var level: Node = null
var room_index: int = -1
var size: Vector2 = Vector2(10, 12)
var _near: bool = false
var _prompt_a: float = 0.0


func _init() -> void:
	collision_layer = Layers.INTERACT
	collision_mask = Layers.ACTORS
	monitoring = true
	monitorable = true


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = Vector2(0, -size.y * 0.5)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	z_index = 3


func _on_body_entered(b: Node) -> void:
	if b is Player:
		_near = true
		_on_player_near(b)


func _on_body_exited(b: Node) -> void:
	if b is Player:
		_near = false


func _process(delta: float) -> void:
	_prompt_a = move_toward(_prompt_a, 1.0 if _near and can_interact() else 0.0, delta * 6.0)
	queue_redraw()


func can_interact() -> bool:
	return true


func interact(_player: Node) -> void:
	pass


func _on_player_near(_player: Node) -> void:
	pass


func _draw() -> void:
	_draw_body()
	if _prompt_a <= 0.01 or prompt == "":
		return
	var key := Settings.binding_label("interact")
	var text := "[%s] %s" % [key, prompt]
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var pos := Vector2(roundf(-w * 0.5), roundf(-size.y - 6 - (1.0 - _prompt_a) * 3.0))
	draw_rect(Rect2(pos + Vector2(-2, -7), Vector2(w + 4, 9)), Color(0.05, 0.03, 0.1, 0.7 * _prompt_a))
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.95, 0.8, _prompt_a))


func _draw_body() -> void:
	pass
