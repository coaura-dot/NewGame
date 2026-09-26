class_name Checkpoint
extends Interactable
## Ponto de retorno: ao tocar vira o respawn; ao interagir descansa (cura).

const TEX := preload("res://assets/art/props/checkpoint_idle.png")

var active: bool = false
var _t: float = 0.0


func _ready() -> void:
	prompt = "Descansar"
	size = Vector2(24, 40)
	super._ready()


func _on_player_near(player: Node) -> void:
	if not active and level:
		active = true
		level.set_checkpoint(self)
		FX.burst(global_position + Vector2(0, -30), Color(2.0, 1.6, 0.6), 14, 120.0)
		Audio.play("confirmation", 0.0, -6.0)
		var l := LightUtil.make_light(Color(1.0, 0.8, 0.5), 0.9, 0.7)
		if l:
			l.position = Vector2(0, -34)
			add_child(l)


func interact(player: Node) -> void:
	player.heal(player.max_hp())
	player.gain_focus(player.max_focus())
	FX.text(global_position + Vector2(0, -60), "Descansou", Color(2.0, 1.8, 1.2))
	Game.save()


func deactivate() -> void:
	active = false


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	if active:
		var frame := int(_t * 12.0) % 10
		draw_texture_rect_region(TEX, Rect2(-32, -64, 64, 64), Rect2(frame * 64, 0, 64, 64))
	else:
		draw_texture_rect_region(TEX, Rect2(-32, -64, 64, 64), Rect2(0, 0, 64, 64), Color(0.5, 0.5, 0.6))
