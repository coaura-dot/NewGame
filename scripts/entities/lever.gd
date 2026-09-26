class_name Lever
extends Interactable
## Alavanca: abre os portões "lever" da mesma sala.

var pulled: bool = false


func _ready() -> void:
	prompt = "Puxar"
	size = Vector2(10, 10)
	super._ready()


func can_interact() -> bool:
	return not pulled


func interact(player: Node) -> void:
	if pulled:
		return
	pulled = true
	Audio.play("chest")
	FX.burst(global_position + Vector2(0, -5), Color(0.8, 1.6, 2.4), 6, 50.0)
	if player and "emote" in player:
		player.emote.show_emote("note", 0.6)
	if level:
		level.on_lever(room_index)


func _draw_body() -> void:
	var ink := Color(0.106, 0.082, 0.157)
	draw_rect(Rect2(-4, -3, 8, 3), ink)
	draw_rect(Rect2(-3, -2, 6, 2), Color(0.45, 0.42, 0.52))
	var tip := Vector2(3, -8) if pulled else Vector2(-3, -8)
	draw_line(Vector2(0, -3), tip, Color(0.55, 0.42, 0.3), 1.0)
	draw_rect(Rect2(tip - Vector2(1, 1), Vector2(2, 2)), Color(2.0, 0.6, 0.4) if not pulled else Color(0.6, 2.0, 0.8))
