class_name Checkpoint
extends Interactable
## Banco/fogueira: ao tocar vira o ponto de retorno; interagir descansa (cura).

var active: bool = false
var _t: float = 0.0
var _light: PointLight2D
var _glow: Node2D
## já foi aceso alguma vez (fica aceso para sempre, mesmo sem ser o atual)
var lit: bool = false


func _ready() -> void:
	prompt = "Descansar"
	size = Vector2(14, 16)
	super._ready()
	z_index = -1
	var key := _key()
	lit = key != "" and Game.profile.get("braziers", []).has(key)
	_glow = DecorSprite.glow_node(self, func(n: Node2D):
		if lit:
			DecorSprite.draw_glow(n, "brazier_lit", Vector2.ZERO, false, 0.85 + 0.15 * sin(_t * 9.0)))
	if lit:
		_make_light()


func _key() -> String:
	if level == null or not ("region_id" in level):
		return ""
	return "%s:%d,%d" % [level.region_id, int(global_position.x), int(global_position.y)]


func _make_light() -> void:
	if _light:
		return
	_light = LightUtil.make_light(Color(1.0, 0.72, 0.42), 1.0, 1.1)
	if _light:
		_light.position = Vector2(0, -12)
		add_child(_light)


func _on_player_near(_player: Node) -> void:
	if not active and level:
		active = true
		level.set_checkpoint(self)
		if not lit:
			# o Lume acende o braseiro com a própria brasa
			lit = true
			var key := _key()
			if key != "" and not Game.training:
				if not Game.profile.has("braziers"):
					Game.profile["braziers"] = []
				Game.profile["braziers"].append(key)
			FX.burst(global_position + Vector2(0, -12), Color(3.0, 1.8, 0.6), 18, 90.0)
			FX.shake(0.12)
			Audio.play("confirmation", 0.0, -4.0)
			Events.toast.emit("Braseiro aceso")
		_make_light()


func interact(player: Node) -> void:
	player.heal(player.max_hp())
	player.gain_focus(player.max_focus())
	if player.has_method("emote"):
		player.emote("z", 1.6)
	Game.save()


func deactivate() -> void:
	active = false


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if _light and lit:
		_light.energy = 0.72 + 0.06 * sin(_t * 8.0) + 0.04 * sin(_t * 19.0)
	if _glow:
		_glow.queue_redraw()


func _draw_body() -> void:
	DecorSprite.draw(self, "brazier_lit" if lit else "brazier_cold", Vector2.ZERO, false)
