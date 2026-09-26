class_name QuestBoard
extends Interactable
## Mural de missões: ofertas dependem da reputação (mercenário x oficial).


func _ready() -> void:
	prompt = "Mural de missões"
	size = Vector2(12, 12)
	super._ready()


func can_interact() -> bool:
	return not Game.social.is_empty()


func interact(_player: Node) -> void:
	if level and level.has_method("open_quest_board"):
		level.open_quest_board()


func _draw_body() -> void:
	draw_rect(Rect2(-6, -12, 12, 8), Color(0.35, 0.24, 0.16))
	for i in 3:
		draw_rect(Rect2(-5 + i * 4, -11 + (i % 2), 3, 4), Color(0.95, 0.9, 0.75))
	draw_rect(Rect2(-1, -4, 2, 4), Color(0.3, 0.2, 0.14))
