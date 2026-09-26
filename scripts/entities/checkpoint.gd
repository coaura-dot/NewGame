class_name Checkpoint
extends Interactable
## Banco de descanso: ao passar vira o ponto de retorno; ao interagir o herói
## senta, descansa (cura, recupera foco) e o jogo salva.

const TEX := preload("res://assets/art/props/bench.png")

var active: bool = false
var _t: float = 0.0
var _glow: Sprite2D


func _ready() -> void:
	prompt = "Descansar"
	size = Vector2(16, 14)
	super._ready()


func _on_player_near(player: Node) -> void:
	if not active and level:
		active = true
		level.set_checkpoint(self)
		FX.burst(global_position + Vector2(6, -13), Color(2.2, 1.8, 0.8), 8, 50.0)
		Audio.play("confirmation", 0.0, -6.0)
		_glow = LightUtil.make_glow(Color(1.6, 1.2, 0.5, 0.5), 10.0)
		_glow.position = Vector2(6, -13)
		add_child(_glow)
		var l := LightUtil.make_light(Color(1.0, 0.8, 0.5), 0.6, 0.8)
		if l:
			l.position = Vector2(6, -13)
			add_child(l)
		if player.has_method("rest"):
			player.emote.show_emote("spark", 0.8)


func interact(player: Node) -> void:
	player.heal(player.max_hp())
	player.gain_focus(player.max_focus())
	Events.player_health_changed.emit(player.hp, player.max_hp())
	if player.has_method("rest"):
		player.global_position.x = global_position.x - 2.0
		player.rest()
		player.emote.show_emote("heart", 1.0)
	Game.save()


func deactivate() -> void:
	active = false


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if _glow:
		_glow.modulate.a = 0.4 + 0.1 * sin(_t * 3.0)


func _draw_body() -> void:
	draw_texture_rect_region(TEX, Rect2(-8, -16, 16, 16), Rect2(16 if active else 0, 0, 16, 16))
