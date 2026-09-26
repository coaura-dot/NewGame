class_name Checkpoint
extends Interactable
## Banco/fogueira: ao tocar vira o ponto de retorno; interagir descansa (cura).

var active: bool = false
var _t: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	prompt = "Descansar"
	size = Vector2(12, 12)
	super._ready()


func _on_player_near(_player: Node) -> void:
	if not active and level:
		active = true
		level.set_checkpoint(self)
		FX.burst(global_position + Vector2(0, -6), Color(2.0, 1.6, 0.6), 8, 80.0)
		Audio.play("confirmation", 0.0, -6.0)
		_light = LightUtil.make_light(Color(1.0, 0.75, 0.45), 0.9, 0.9)
		if _light:
			_light.position = Vector2(0, -6)
			add_child(_light)


func interact(player: Node) -> void:
	player.heal(player.max_hp())
	player.gain_focus(player.max_focus())
	if player.has_method("emote"):
		player.emote("z", 1.6)
	Game.save()


func deactivate() -> void:
	active = false
	if _light:
		_light.queue_free()
		_light = null


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	draw_rect(Rect2(-5, -2, 10, 2), Color(0.35, 0.3, 0.3))
	draw_rect(Rect2(-3, -3, 2, 1), Color(0.5, 0.35, 0.25))
	draw_rect(Rect2(1, -3, 2, 1), Color(0.5, 0.35, 0.25))
	if active:
		var h := 3.0 + (1.0 if fmod(_t * 8.0, 2.0) > 1.0 else 0.0)
		draw_rect(Rect2(-1, -3 - h, 2, h), Color(2.6, 1.4, 0.4))
		draw_rect(Rect2(-2, -5, 4, 2), Color(2.4, 1.0, 0.3))
