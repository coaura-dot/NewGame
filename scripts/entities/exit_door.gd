class_name ExitDoor
extends Interactable
## Porta de saída da fase: completa a região.

const TEX := preload("res://assets/art/props/door.png")


func _ready() -> void:
	prompt = "Sair da região"
	size = Vector2(12, 20)
	super._ready()
	var l := LightUtil.make_light(Color(1.0, 0.85, 0.6), 0.5, 0.6)
	if l:
		l.position = Vector2(0, -12)
		add_child(l)


func interact(_player: Node) -> void:
	if level and level.has_method("complete_level"):
		Audio.play("door")
		level.complete_level()


func _draw_body() -> void:
	draw_texture(TEX, Vector2(-7, -20))
