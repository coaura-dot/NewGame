class_name Lever
extends Interactable
## Alavanca: abre os portões "lever" da mesma sala.

var pulled: bool = false


func _ready() -> void:
	prompt = "Puxar"
	size = Vector2(8, 10)
	super._ready()


func can_interact() -> bool:
	return not pulled


func interact(_player: Node) -> void:
	if pulled:
		return
	pulled = true
	Audio.play("chest")
	FX.burst(global_position + Vector2(0, -5), Color(0.8, 1.6, 2.4), 6, 100.0)
	if level:
		level.on_lever(room_index)


func _draw_body() -> void:
	draw_rect(Rect2(-3, -2, 6, 2), Color(0.3, 0.28, 0.35))
	var tip := Vector2(3, -7) if pulled else Vector2(-3, -7)
	draw_line(Vector2(0, -2), tip, Color(0.6, 0.5, 0.4), 1.0)
	draw_rect(Rect2(tip - Vector2(1, 1), Vector2(2, 2)), Color(2.0, 0.6, 0.4) if not pulled else Color(0.6, 2.0, 0.8))
