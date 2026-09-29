class_name LoreTablet
extends Interactable
## Tábua de pedra com inscrições (lore) na entrada das fases: conta um pedaço
## da história de Candelária ligado ao bioma e ao guardião da região. As runas
## brilham na cor da região; ler abre o texto no HUD.

var title: String = "Inscrição"
var text: String = ""
var glow: Color = Color(2.4, 1.4, 0.6)
var _t: float = 0.0
var _read: bool = false


func _ready() -> void:
	size = Vector2(12, 14)
	prompt = "Ler"
	super._ready()
	z_index = -1


func interact(player: Node) -> void:
	_read = true
	Audio.play("ui_move", 0.0, -8.0)
	if player and "emote" in player:
		player.emote.show_emote("...", 0.8)
	if level and level.hud and level.hud.has_method("open_text"):
		level.hud.open_text(title, text)
	else:
		Events.toast.emit(text)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	var stone := Color(0.55, 0.53, 0.62)
	var dark := Color(0.36, 0.34, 0.44)
	var ink := Color(0.106, 0.082, 0.157)
	# base e tábua (arredondada em cima)
	draw_rect(Rect2(-6, -2, 12, 2), dark)
	draw_rect(Rect2(-5, -13, 10, 11), stone)
	draw_rect(Rect2(-4, -14, 8, 1), stone)
	draw_rect(Rect2(4, -13, 1, 11), dark)
	draw_rect(Rect2(-5, -13, 1, 1), ink)
	draw_rect(Rect2(4, -13, 1, 1), ink)
	# runas (pulsam; mais fracas depois de lidas)
	var a := (0.55 if _read else 0.85) + 0.15 * sin(_t * 3.0)
	var c := Color(glow.r, glow.g, glow.b, a)
	for row in 3:
		var y := -11 + row * 3
		draw_rect(Rect2(-3, y, 2, 1), c)
		draw_rect(Rect2(0, y, 3 - row % 2, 1), c)
