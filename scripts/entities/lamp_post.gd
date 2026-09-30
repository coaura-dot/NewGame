class_name LampPost
extends Interactable
## Poste de lampião apagado que o Lume pode ACENDER com a própria brasa (é o
## ofício dele: um Lampadeiro). Aceso, ilumina o lugar para sempre (fica
## salvo), dá algumas brasas e conta para a "luz" da região — o povo nota.
## Arte: sprites lamp_off / lamp_on de tools/build_decor.py.

var lamp_key: String = ""
var color: Color = Color(1.9, 1.0, 0.5)
var lit: bool = false
var _light: PointLight2D
var _t: float = 0.0
var _flare: float = 0.0
var _glow: Node2D


func _ready() -> void:
	size = Vector2(12, 24)
	lit = Game.profile.get("lamps", []).has(lamp_key)
	prompt = "" if lit else "Acender"
	super._ready()
	z_index = -1
	_t = randf() * 10.0
	_glow = DecorSprite.glow_node(self, func(n: Node2D):
		if lit:
			DecorSprite.draw_glow(n, "lamp_on", Vector2.ZERO, false, 0.8 + 0.12 * sin(_t * 7.0) + _flare))
	if lit:
		_make_light(false)


func can_interact() -> bool:
	return not lit


func interact(player: Node) -> void:
	if lit:
		return
	lit = true
	prompt = ""
	_flare = 1.0
	if not Game.training:
		if not Game.profile.has("lamps"):
			Game.profile["lamps"] = []
		Game.profile["lamps"].append(lamp_key)
		Game.profile["currency"] = int(Game.profile.get("currency", 0)) + 3
	_make_light(true)
	FX.burst(global_position + Vector2(0, -21), Color(2.8, 1.8, 0.7), 14, 70.0)
	Audio.play("confirmation", 0.05, -4.0)
	if player.has_method("emote"):
		player.emote("note", 1.0)
	Events.toast.emit("Lampião aceso  +3 brasas")
	Events.lamp_lit.emit(lamp_key)


func _make_light(fade: bool) -> void:
	_light = LightUtil.make_light(color * 0.55, 0.9, 0.95, false)
	if _light:
		_light.position = Vector2(0, -21)
		add_child(_light)
		if fade:
			var e := _light.energy
			_light.energy = 0.0
			create_tween().tween_property(_light, "energy", e, 0.6)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_flare = maxf(_flare - delta * 1.5, 0.0)
	if _light and lit:
		_light.energy = (0.62 + 0.05 * sin(_t * 9.0) + 0.03 * sin(_t * 23.0)) * (1.0 + _flare)
	if _glow:
		_glow.queue_redraw()


func _draw_body() -> void:
	var id := "lamp_on" if lit else "lamp_off"
	DecorSprite.draw(self, id, Vector2.ZERO, false)
