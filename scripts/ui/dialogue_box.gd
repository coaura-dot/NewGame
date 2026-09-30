class_name DialogueBox
extends CanvasLayer
## Caixa de diálogo da história (estilo Hollow Knight): faixa escura com
## filetes dourados, nome de quem fala, texto que vai sendo "escrito" e uma
## setinha pulsando quando dá para seguir. Interagir/pular/atacar completa a
## linha ou avança. O mundo continua vivo; o Lume fica parado (cutscene_lock).
##   await dialogue.run("Vovó Borralha", ["linha 1", "linha 2"])

signal finished

const FONT := preload("res://assets/fonts/kenney_pixel.ttf")
const BOX := Rect2(64, 34, 352, 60)
const CPS := 42.0 ## letras por segundo
const GOLD := Color(0.95, 0.8, 0.5)
const INK := Color(0.95, 0.93, 0.88)

var active: bool = false
## testes automáticos: as falas avançam sozinhas
static var auto_advance: bool = false
var _speaker: String = ""
var _lines: Array = []
var _i: int = 0
var _shown: float = 0.0
var _a: float = 0.0
var _t: float = 0.0
var _draw: Control
var _blip: float = 0.0
var _hold: float = 0.0


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw = Control.new()
	_draw.size = Vector2(480, 270)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)


## Mostra as falas e espera terminar. Cada linha pode ser texto ou
## {"who": "Nome", "text": "..."} (troca quem fala no meio).
func run(speaker: String, lines: Array) -> void:
	if lines.is_empty():
		return
	_speaker = speaker
	_lines = lines
	_i = 0
	_shown = 0.0
	_hold = 0.15
	active = true
	await finished


func _cur_text() -> String:
	if _i >= _lines.size():
		return ""
	var l = _lines[_i]
	if l is Dictionary:
		return str(l.get("text", ""))
	return str(l)


func _cur_speaker() -> String:
	if _i < _lines.size() and _lines[_i] is Dictionary and _lines[_i].has("who"):
		return str(_lines[_i]["who"])
	return _speaker


func _process(delta: float) -> void:
	_t += delta
	_a = move_toward(_a, 1.0 if active else 0.0, delta * 6.0)
	_draw.visible = _a > 0.01
	if not active:
		_draw.queue_redraw()
		return
	var text := _cur_text()
	var before := int(_shown)
	_shown = minf(_shown + delta * CPS, float(text.length()))
	if int(_shown) != before and int(_shown) % 3 == 0 and text.substr(int(_shown) - 1, 1) != " ":
		Audio.play("ui_move", 0.15, -22.0)
	_hold = maxf(_hold - delta, 0.0)
	if auto_advance and _hold <= 0.0:
		_shown = float(text.length())
		_i += 1
		_shown = 0.0
		_hold = 0.05
		if _i >= _lines.size():
			active = false
			finished.emit()
		_draw.queue_redraw()
		return
	if _hold <= 0.0 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_accept")):
		if _shown < text.length():
			_shown = float(text.length())
		else:
			_i += 1
			_shown = 0.0
			_hold = 0.08
			if _i >= _lines.size():
				active = false
				finished.emit()
	_draw.queue_redraw()


func _on_draw() -> void:
	var d := _draw
	var a := _a
	var r := BOX
	# faixa escura com cantos cortados
	var bg := Color(0.025, 0.022, 0.035, 0.9 * a)
	d.draw_rect(Rect2(r.position + Vector2(3, 0), r.size - Vector2(6, 0)), bg)
	d.draw_rect(Rect2(r.position + Vector2(0, 3), r.size - Vector2(0, 6)), bg)
	# filetes dourados em cima e embaixo, com losangos nas pontas
	var g := Color(GOLD.r, GOLD.g, GOLD.b, 0.75 * a)
	for y in [r.position.y + 1, r.end.y - 2]:
		d.draw_line(Vector2(r.position.x + 10, y), Vector2(r.end.x - 10, y), g, 1.0)
		for x in [r.position.x + 7, r.end.x - 7]:
			d.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 2), Vector2(x + 2, y), Vector2(x, y + 2), Vector2(x - 2, y)]), g)
	# ornamento central no topo
	var cx := r.get_center().x
	d.draw_colored_polygon(PackedVector2Array([Vector2(cx, r.position.y - 2), Vector2(cx + 4, r.position.y + 1), Vector2(cx, r.position.y + 4), Vector2(cx - 4, r.position.y + 1)]), g)
	if _i >= _lines.size() and not active:
		return
	# nome de quem fala
	var who := _cur_speaker()
	if who != "":
		var nw := FONT.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		d.draw_rect(Rect2(r.position.x + 10, r.position.y - 9, nw + 10, 12), Color(0.025, 0.022, 0.035, 0.92 * a))
		d.draw_string(FONT, Vector2(r.position.x + 15, r.position.y + 1), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GOLD.r, GOLD.g, GOLD.b, a))
	# texto (quebra de linha por palavra)
	var text := _cur_text().substr(0, int(_shown))
	var lines := _wrap(_cur_text(), r.size.x - 28, 12)
	var y := r.position.y + 18
	var left := text.length()
	for l in lines:
		var part: String = l.substr(0, maxi(0, left))
		left -= l.length() + 1
		d.draw_string(FONT, Vector2(r.position.x + 14, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK.r, INK.g, INK.b, a))
		y += 13
		if left <= 0:
			break
	# setinha: pode seguir
	if active and _shown >= _cur_text().length():
		var bob := sin(_t * 6.0) * 1.5
		var p := Vector2(r.end.x - 14, r.end.y - 10 + bob)
		d.draw_colored_polygon(PackedVector2Array([p, p + Vector2(6, 0), p + Vector2(3, 4)]), Color(GOLD.r, GOLD.g, GOLD.b, a))


func _wrap(text: String, width: float, size: int) -> Array:
	var out: Array = []
	var cur := ""
	for word in text.split(" "):
		var trial := word if cur == "" else cur + " " + word
		if FONT.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out
