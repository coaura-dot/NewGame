extends Node2D
## Abertura: 6 quadros da história de Cindária (data/lore.json -> intro),
## ilustrados em pixel art desenhada em código (320x180, animada) com texto
## datilografado. Qualquer botão avança; Esc pula tudo.

const FONT := preload("res://assets/fonts/kenney_pixel.ttf")
const W := 320.0
const H := 180.0
const TYPE_SPEED := 38.0 ## letras por segundo

var _panels: Array = []
var _i: int = 0
var _t: float = 0.0
var _chars: float = 0.0
var _fade: float = 1.0
var _leaving: bool = false
var _rng := RandomNumberGenerator.new()
var _embers: Array = [] ## [pos, vel, vida]
var _hero: CreatureSprite
var _ui: CanvasLayer
var _label: Label
var _hint: Label


func _ready() -> void:
	_rng.seed = 1234
	_panels = DB.lore.get("intro", [])
	if _panels.is_empty():
		_finish()
		return
	Music.play("menu", 2.0)
	Music.play_ambience("vento")
	_hero = CreatureSprite.new()
	_hero.spec = {"body": [5, 4], "head": [6, 5], "color": [0.24, 0.22, 0.38], "shell": [0.93, 0.9, 0.84], "eyes": "hollow", "legs": 2, "horns": true, "weapon": true}
	_hero.visible = false
	_hero.scale = Vector2(2, 2)
	add_child(_hero)
	_ui = CanvasLayer.new()
	_ui.scale = Vector2(2.0 / 3.0, 2.0 / 3.0)
	add_child(_ui)
	var root := Control.new()
	root.size = Vector2(480, 270)
	root.theme = UIKit.theme()
	_ui.add_child(root)
	_label = UIKit.label("", 13, UIKit.INK)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.position = Vector2(40, 206)
	_label.size = Vector2(400, 60)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_label)
	_hint = UIKit.label("[qualquer botão] continuar     [Esc] pular", 9, UIKit.DIM)
	_hint.position = Vector2(150, 258)
	root.add_child(_hint)
	_show(0)


func _show(i: int) -> void:
	_i = i
	_t = 0.0
	_chars = 0.0
	_fade = 1.0
	_embers.clear()
	_label.text = ""
	var art: String = _panels[i].get("art", "")
	_hero.visible = art in ["spark", "tide_rising"]
	if art == "spark":
		_hero.position = Vector2(W * 0.5, 128)
		_hero.play("idle")
	elif art == "tide_rising":
		_hero.position = Vector2(92, 104)
		_hero.flip_h = false
		_hero.play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) or not event.is_pressed():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_finish()
		return
	var text: String = _panels[_i]["text"]
	if _chars < text.length():
		_chars = text.length()
	elif _i + 1 < _panels.size():
		_show(_i + 1)
	else:
		_finish()
	get_viewport().set_input_as_handled()


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	Game.travel(str(Game.world.get("start", "")))


func _process(delta: float) -> void:
	if _panels.is_empty():
		return
	_t += delta
	_fade = maxf(_fade - delta * 1.5, 0.0)
	var text: String = _panels[_i]["text"]
	_chars = minf(_chars + delta * TYPE_SPEED, text.length())
	_label.text = text.substr(0, int(_chars))
	# brasas subindo (comum a vários quadros)
	var art: String = _panels[_i].get("art", "")
	if art in ["flame", "guardian", "embers", "spark"] and _rng.randf() < 0.5:
		var origin := Vector2(W * 0.5 + _rng.randf_range(-30, 30), 110)
		if art == "embers":
			origin = Vector2(_rng.randf_range(0, W), _rng.randf_range(60, 160))
		_embers.append([origin, Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-30, -12)), _rng.randf_range(1.0, 2.6)])
	for e in _embers:
		e[0] += e[1] * delta
		e[2] -= delta
	_embers = _embers.filter(func(e): return e[2] > 0.0)
	if art == "spark" and _t > 2.2 and _t - delta <= 2.2:
		_hero.emote("!", 1.4)
	queue_redraw()


# ---------------------------------------------------------------------------
# Ilustrações
# ---------------------------------------------------------------------------

func _draw() -> void:
	var art: String = _panels[_i].get("art", "") if not _panels.is_empty() else ""
	match art:
		"flame": _art_flame()
		"tide": _art_tide()
		"guardian": _art_guardian()
		"embers": _art_embers()
		"spark": _art_spark()
		"tide_rising": _art_tide_rising()
	for e in _embers:
		var a: float = clampf(float(e[2]), 0.0, 1.0)
		draw_rect(Rect2(Vector2(e[0]).round(), Vector2.ONE), Color(2.2, 1.2, 0.4, a))
	# moldura de cinema e fade entre quadros
	draw_rect(Rect2(0, 0, W, 14), Color(0.02, 0.01, 0.04))
	draw_rect(Rect2(0, 132, W, 48), Color(0.02, 0.01, 0.04))
	if _fade > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.01, 0.04, _fade))


func _gradient(top: Color, bottom: Color) -> void:
	var bands := 10
	for i in bands:
		draw_rect(Rect2(0, 14 + i * 12, W, 13), top.lerp(bottom, float(i) / (bands - 1)))


func _flame(center: Vector2, size: float, t: float) -> void:
	var layers := [[1.0, Color(2.6, 0.9, 0.3)], [0.72, Color(3.0, 1.7, 0.5)], [0.42, Color(3.2, 2.9, 1.8)]]
	for L in layers:
		var s: float = size * float(L[0])
		var sway := sin(t * 5.0 + s) * s * 0.12
		var pts := PackedVector2Array([
			center + Vector2(-s * 0.55, 0), center + Vector2(-s * 0.35, -s * 0.8),
			center + Vector2(sway, -s * 1.7), center + Vector2(s * 0.35, -s * 0.8),
			center + Vector2(s * 0.55, 0), center + Vector2(0, s * 0.35)])
		draw_colored_polygon(pts, L[1])


func _art_flame() -> void:
	_gradient(Color(0.06, 0.04, 0.1), Color(0.22, 0.1, 0.12))
	# santuário: pilares e altar
	var stone := Color(0.1, 0.08, 0.14)
	for x in [96, 116, 204, 224]:
		draw_rect(Rect2(x, 60, 8, 72), stone)
		draw_rect(Rect2(x - 2, 58, 12, 4), stone)
	draw_rect(Rect2(128, 112, 64, 20), stone)
	draw_rect(Rect2(120, 108, 80, 6), stone)
	draw_circle(Vector2(160, 92), 42.0 + sin(_t * 3.0) * 2.0, Color(1.0, 0.45, 0.2, 0.12))
	_flame(Vector2(160, 108), 26.0, _t)


func _art_tide() -> void:
	_gradient(Color(0.05, 0.03, 0.08), Color(0.12, 0.06, 0.16))
	# silhuetas de criaturas e casas sendo engolidas
	var sil := Color(0.18, 0.14, 0.24)
	for i in 7:
		var x := 20.0 + i * 44.0
		draw_rect(Rect2(x, 86, 18, 30), sil)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, 86), Vector2(x + 9, 76), Vector2(x + 20, 86)]), sil)
	var rise := minf(_t * 4.0, 34.0)
	for k in 3:
		var base := 132.0 - rise * (1.0 - k * 0.25) + k * 6.0
		var pts := PackedVector2Array()
		pts.append(Vector2(0, 132))
		var x2 := 0.0
		while x2 <= W:
			pts.append(Vector2(x2, base + sin(x2 * 0.05 + _t * (1.2 + k * 0.4) + k) * 4.0))
			x2 += 8.0
		pts.append(Vector2(W, 132))
		draw_colored_polygon(pts, [Color(0.2, 0.05, 0.25), Color(0.12, 0.03, 0.16), Color(0.05, 0.01, 0.07)][k])
	for i in 6:
		var ex := 30.0 + i * 50.0 + sin(i * 3.1) * 10.0
		var ey := 120.0 - rise * 0.5 + sin(_t + i) * 2.0
		if fmod(_t + i * 0.7, 3.0) > 0.2:
			draw_rect(Rect2(ex, ey, 1, 1), Color(2.4, 0.4, 0.8))
			draw_rect(Rect2(ex + 3, ey, 1, 1), Color(2.4, 0.4, 0.8))


func _art_guardian() -> void:
	_gradient(Color(0.08, 0.05, 0.12), Color(0.3, 0.16, 0.14))
	var sil := Color(0.06, 0.04, 0.08)
	# Ignara: figura alta e esguia com manto, braços erguidos
	var cx := 160.0
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 18, 132), Vector2(cx - 6, 60), Vector2(cx + 6, 60), Vector2(cx + 18, 132)]), sil)
	draw_circle(Vector2(cx, 54), 7.0, sil)
	draw_line(Vector2(cx - 5, 64), Vector2(cx - 16, 34), sil, 3.0)
	draw_line(Vector2(cx + 5, 64), Vector2(cx + 16, 34), sil, 3.0)
	var burst := clampf((_t - 1.2) * 0.8, 0.0, 1.0)
	if burst <= 0.0:
		_flame(Vector2(cx, 34), 14.0, _t)
	else:
		for i in 24:
			var a := i * TAU / 24.0 + _t * 0.2
			var d := burst * (40.0 + (i % 5) * 18.0)
			var p := Vector2(cx, 26) + Vector2.from_angle(a) * d
			draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(3.0, 1.6, 0.5, 1.0 - burst * 0.3))
		draw_circle(Vector2(cx, 26), 10.0 * (1.0 - burst), Color(3.0, 2.6, 1.6))


func _art_embers() -> void:
	_gradient(Color(0.03, 0.03, 0.07), Color(0.1, 0.08, 0.14))
	var ground := Color(0.07, 0.06, 0.1)
	var pts := PackedVector2Array([Vector2(0, 132)])
	var x := 0.0
	while x <= W:
		pts.append(Vector2(x, 112 + sin(x * 0.03) * 6.0 + sin(x * 0.11) * 3.0))
		x += 6.0
	pts.append(Vector2(W, 132))
	draw_colored_polygon(pts, ground)
	# brasas nos corações dos Ocos, apagando uma a uma
	for i in 14:
		var bx := 16.0 + i * 22.0
		var by := 104.0 + sin(i * 2.3) * 6.0
		draw_rect(Rect2(bx - 2, by - 8, 5, 8), Color(0.12, 0.1, 0.16))
		var alive := _t < 1.0 + i * 0.35
		if alive:
			draw_rect(Rect2(bx, by - 5, 1, 1), Color(2.6, 1.2, 0.4))


func _art_spark() -> void:
	_gradient(Color(0.05, 0.04, 0.09), Color(0.16, 0.12, 0.16))
	var stone := Color(0.12, 0.1, 0.16)
	for p in [[40, 70, 10, 62], [70, 90, 8, 42], [236, 64, 10, 68], [270, 96, 8, 36]]:
		draw_rect(Rect2(p[0], p[1], p[2], p[3]), stone)
	draw_rect(Rect2(0, 128, W, 4), Color(0.14, 0.12, 0.18))
	var glow := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(Vector2(160, 118), 26.0 + glow * 4.0, Color(1.0, 0.5, 0.2, 0.08 + glow * 0.04))
	draw_rect(Rect2(159, 113, 2, 2), Color(3.0, 1.8, 0.6))


func _art_tide_rising() -> void:
	_gradient(Color(0.1, 0.05, 0.12), Color(0.6, 0.22, 0.2))
	# sol vermelho baixo
	draw_circle(Vector2(236, 92), 18.0, Color(1.6, 0.6, 0.35))
	# a Maré no horizonte
	var tide_y := 96.0 - minf(_t * 1.5, 10.0)
	var pts := PackedVector2Array([Vector2(120, 132)])
	var x := 120.0
	while x <= W:
		pts.append(Vector2(x, tide_y + sin(x * 0.06 + _t) * 3.0))
		x += 6.0
	pts.append(Vector2(W, 132))
	draw_colored_polygon(pts, Color(0.1, 0.02, 0.12))
	# penhasco onde a Faísca está
	var cliff := Color(0.05, 0.03, 0.06)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 104), Vector2(110, 104), Vector2(128, 132), Vector2(0, 132)]), cliff)
