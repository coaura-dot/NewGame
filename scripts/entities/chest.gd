class_name Chest
extends Interactable
## Baú com item do pool compartilhado. Abre com animação e solta o item.

const IDLE := preload("res://assets/art/props/chest_idle.png")
const OPEN := preload("res://assets/art/props/chest_open.png")

var loot: String = ""
var opened: bool = false
var _frame: float = 0.0


func _ready() -> void:
	prompt = "Abrir"
	size = Vector2(28, 24)
	super._ready()
	var l := LightUtil.make_light(Color(1.0, 0.8, 0.4), 0.5, 0.35)
	if l:
		l.position = Vector2(0, -12)
		add_child(l)


func can_interact() -> bool:
	return not opened


func interact(player: Node) -> void:
	if opened:
		return
	opened = true
	Audio.play("chest")
	FX.burst(global_position + Vector2(0, -16), Color(2.6, 2.0, 0.8), 16, 160.0, Vector2.UP, 60.0)
	if level and loot != "":
		level.spawn_pickup(loot, global_position + Vector2(0, -24), Vector2(player.facing * -40.0, -160.0))
	if level:
		level.spawn_currency(randi_range(8, 20), global_position + Vector2(0, -20))


func _process(delta: float) -> void:
	super._process(delta)
	if opened and _frame < 7.0:
		_frame = minf(_frame + delta * 16.0, 7.0)


func _draw_body() -> void:
	if opened:
		draw_texture_rect_region(OPEN, Rect2(-16, -32, 32, 32), Rect2(int(_frame) * 32, 0, 32, 32))
	else:
		draw_texture(IDLE, Vector2(-16, -32))
