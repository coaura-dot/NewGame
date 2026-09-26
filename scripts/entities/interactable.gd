class_name Interactable
extends Area2D
## Base para coisas com que o jogador interage (Cima/W/Enter perto delas).
## Mostra a dica de ação (fonte pixel pequena) quando o jogador está perto.

const FONT := preload("res://assets/fonts/kenney_mini.ttf")
const INK := Color(0.106, 0.082, 0.157)

var prompt: String = "Interagir"
var level: Node = null
var room_index: int = -1
var size: Vector2 = Vector2(12, 16)
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
	z_index = -2


func _on_body_entered(b: Node) -> void:
	if b is Player:
		_near = true
		_on_player_near(b)


func _on_body_exited(b: Node) -> void:
	if b is Player:
		_near = false


func _process(delta: float) -> void:
	_prompt_a = move_toward(_prompt_a, 1.0 if _near and can_interact() else 0.0, delta * 8.0)
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
	draw_prompt(prompt, Vector2(0, -size.y - 6.0 - roundf((1.0 - _prompt_a) * 3.0)), _prompt_a)


## Dica "[tecla] texto" com contorno, centralizada em pos.
func draw_prompt(text_in: String, pos: Vector2, a: float) -> void:
	var key := Settings.binding_label("interact")
	var text := "%s  %s" % [key, text_in]
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := Vector2(roundf(-w * 0.5), pos.y)
	var kw := FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_rect(Rect2(p + Vector2(-2, -6), Vector2(kw + 3, 8)), Color(0.96, 0.94, 0.9, a))
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(FONT, p + Vector2(kw + 4, 0) + o, text_in, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK.r, INK.g, INK.b, a))
	draw_string(FONT, p, key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK.r, INK.g, INK.b, a))
	draw_string(FONT, p + Vector2(kw + 4, 0), text_in, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.97, 0.9, a))


func _draw_body() -> void:
	pass
