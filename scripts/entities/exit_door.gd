class_name ExitDoor
extends Interactable
## Porta de saída da fase: completa a região.

var _tex: Texture2D = preload("res://assets/art/props/door.png")


func _ready() -> void:
	prompt = "Sair da região"
	size = Vector2(28, 48)
	super._ready()
	var l := LightUtil.make_light(Color(1.0, 0.8, 0.5), 0.9, 0.6)
	if l:
		l.position = Vector2(0, -30)
		add_child(l)


func interact(_player: Node) -> void:
	if level and level.has_method("complete_level"):
		Audio.play("door")
		level.complete_level()


func _draw_body() -> void:
	draw_texture(_tex, Vector2(-_tex.get_width() * 0.5, -_tex.get_height()))
