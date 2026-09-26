class_name QuestBoard
extends Interactable
## Mural de missões: ofertas dependem da reputação (mercenário x oficial).

const TEX := preload("res://assets/art/props/board.png")


func _ready() -> void:
	prompt = "Missões"
	size = Vector2(14, 14)
	super._ready()


func can_interact() -> bool:
	return not Game.social.is_empty()


func interact(_player: Node) -> void:
	if level and level.has_method("open_quest_board"):
		level.open_quest_board()


func _draw_body() -> void:
	draw_texture(TEX, Vector2(-7, -14))
