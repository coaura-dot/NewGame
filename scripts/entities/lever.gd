class_name Lever
extends Interactable
## Alavanca: abre os portões "lever" da mesma sala.

var pulled: bool = false


func _ready() -> void:
	prompt = "Puxar"
	size = Vector2(16, 20)
	super._ready()


func can_interact() -> bool:
	return not pulled


func interact(_player: Node) -> void:
	if pulled:
		return
	pulled = true
	Audio.play("chest")
	FX.burst(global_position + Vector2(0, -10), Color(0.8, 1.6, 2.4), 10, 100.0)
	if level:
		level.on_lever(room_index)


func _draw_body() -> void:
	draw_rect(Rect2(-6, -4, 12, 4), Color(0.3, 0.28, 0.35))
	var tip := Vector2(6, -14) if pulled else Vector2(-6, -14)
	draw_line(Vector2(0, -3), tip, Color(0.55, 0.45, 0.35), 2.0)
	draw_circle(tip, 2.5, Color(2.0, 0.6, 0.4) if not pulled else Color(0.6, 2.0, 0.8))
