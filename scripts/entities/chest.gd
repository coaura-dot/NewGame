class_name Chest
extends Interactable
## Baú com item do pool compartilhado. Abre com animação e solta o item.

const TEX := preload("res://assets/art/props/chest.png")

var loot: String = ""
var opened: bool = false
var _t: float = 0.0


func _ready() -> void:
	prompt = "Abrir"
	size = Vector2(14, 12)
	super._ready()
	var l := LightUtil.make_light(Color(1.0, 0.85, 0.5), 0.4, 0.5)
	if l:
		l.position = Vector2(0, -6)
		add_child(l)


func can_interact() -> bool:
	return not opened


func interact(player: Node) -> void:
	if opened:
		return
	opened = true
	_t = 0.0
	Audio.play("chest")
	FX.burst(global_position + Vector2(0, -8), Color(2.2, 1.8, 0.8), 8, 70.0, Vector2.UP, 50.0)
	if player.has_node("Rig"):
		player.emote.show_emote("!", 0.6)
	if level and loot != "":
		level.spawn_pickup(loot, global_position + Vector2(0, -10), Vector2(player.facing * -20.0, -100.0))
	if level:
		level.spawn_currency(randi_range(8, 20), global_position + Vector2(0, -8))


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	var frame := 0
	if opened:
		frame = 1 if _t < 0.06 else 2
	draw_texture_rect_region(TEX, Rect2(-6, -10, 12, 10), Rect2(frame * 12, 0, 12, 10))
