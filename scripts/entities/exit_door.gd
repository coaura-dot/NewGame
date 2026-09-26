class_name ExitDoor
extends Interactable
## Porta de saída da fase: completa a região.

var _t: float = 0.0


func _ready() -> void:
	prompt = "Sair"
	size = Vector2(10, 16)
	super._ready()
	var l := LightUtil.make_light(Color(1.0, 0.85, 0.6), 0.8, 0.6)
	if l:
		l.position = Vector2(0, -8)
		add_child(l)


func interact(_player: Node) -> void:
	if level and level.has_method("complete_level"):
		Audio.play("door")
		level.complete_level()


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	var o := Color(0.09, 0.07, 0.12)
	draw_rect(Rect2(-6, -16, 12, 16), o)
	draw_rect(Rect2(-5, -15, 10, 15), Color(0.35, 0.3, 0.42))
	draw_rect(Rect2(-3, -12, 6, 12), Color(1.6, 1.3, 0.8, 0.7 + 0.2 * sin(_t * 2.0)))
	draw_rect(Rect2(-4, -14, 8, 1), Color(0.55, 0.5, 0.6))
