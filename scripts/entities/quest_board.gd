class_name QuestBoard
extends Interactable
## Mural de missões: ofertas dependem da reputação (mercenário x oficial).


func _ready() -> void:
	prompt = "Mural de missões"
	size = Vector2(30, 30)
	super._ready()


func can_interact() -> bool:
	return not Game.social.is_empty()


func interact(_player: Node) -> void:
	if level and level.has_method("open_quest_board"):
		level.open_quest_board()


func _draw_body() -> void:
	draw_rect(Rect2(-14, -30, 28, 20), Color(0.35, 0.24, 0.16))
	draw_rect(Rect2(-12, -28, 24, 16), Color(0.52, 0.38, 0.24))
	for i in 3:
		draw_rect(Rect2(-10 + i * 7, -26 + (i % 2) * 2, 6, 8), Color(0.9, 0.85, 0.7))
	draw_rect(Rect2(-2, -10, 4, 10), Color(0.3, 0.2, 0.14))
