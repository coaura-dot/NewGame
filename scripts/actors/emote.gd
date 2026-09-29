class_name EmoteBubble
extends Node2D
## Balãozinho de expressão acima da cabeça (herói e NPCs): "!", "?", "!?",
## "...", coração, nota musical, "zzz", raiva, gota de suor, brilho, tontura.
## Em combate: "warn" (! amarelo = dá para aparar), "danger" (!! vermelho =
## só esquivando) e "guard" (escudo = o inimigo está defendendo).
## Tudo em pixel art 1x desenhada em código (5x5 dentro de um balão 9x9).

const ICONS := {
	"!": [".....", "..#..", "..#..", "..#..", ".....", "..#.."],
	"?": [".###.", "#...#", "...#.", "..#..", ".....", "..#.."],
	"!?": ["#.###", "#...#", "#..#.", "#.#..", ".....", "#.#.."],
	"...": [".....", ".....", ".....", ".....", ".....", "#.#.#"],
	"heart": [".....", ".#.#.", "#####", "#####", ".###.", "..#.."],
	"note": ["..##.", "..#.#", "..#..", "..#..", "###..", "##..."],
	"zzz": [".....", "####.", "..#..", ".#...", "####.", "....."],
	"anger": [".....", ".#.#.", "#...#", ".....", "#...#", ".#.#."],
	"spark": ["..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"dizzy": [".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	"skull": [".###.", "#####", "#.#.#", "#####", ".#.#.", "....."],
	"warn": [".....", "..#..", "..#..", "..#..", ".....", "..#.."],
	"danger": [".....", ".#.#.", ".#.#.", ".#.#.", ".....", ".#.#."],
	"guard": [".....", "#####", "#.#.#", "#####", ".###.", "..#.."],
}
const COLORS := {
	"!": Color(0.88, 0.25, 0.3), "?": Color(0.3, 0.45, 0.9), "!?": Color(0.88, 0.35, 0.6),
	"...": Color(0.2, 0.18, 0.28), "heart": Color(0.95, 0.35, 0.5), "note": Color(0.35, 0.55, 0.95),
	"zzz": Color(0.35, 0.4, 0.75), "anger": Color(0.9, 0.2, 0.2), "spark": Color(0.95, 0.72, 0.2),
	"dizzy": Color(0.55, 0.4, 0.8), "skull": Color(0.2, 0.18, 0.28),
	"warn": Color(0.92, 0.66, 0.08), "danger": Color(0.9, 0.12, 0.16), "guard": Color(0.36, 0.52, 0.8),
}
const BUBBLE := Color(0.96, 0.94, 0.9)
const INK := Color(0.106, 0.082, 0.157)
const SWEAT := Color(0.45, 0.75, 1.0)

var kind: String = ""
var time_left: float = 0.0
var height: float = 20.0 ## altura acima dos pés
var _t: float = 0.0
var _sweat_t: float = 0.0
var _sweat_side: int = 1


func _ready() -> void:
	z_index = 70


## Mostra um emote. Não interrompe um emote mais importante (prioridade).
func show_emote(k: String, duration: float = 1.1, force: bool = false) -> void:
	if not force and kind != "" and time_left > 0.25 and _priority(kind) > _priority(k):
		return
	if k == "sweat":
		_sweat_t = duration
		_sweat_side = 1 if randf() < 0.5 else -1
		return
	if kind != k or time_left <= 0.0:
		_t = 0.0
	kind = k
	time_left = duration


func clear() -> void:
	kind = ""
	time_left = 0.0


static func _priority(k: String) -> int:
	match k:
		"skull", "!", "!?", "warn", "danger", "guard": return 3
		"heart", "spark", "anger": return 2
		"?", "note", "dizzy": return 1
	return 0


func _process(delta: float) -> void:
	_t += delta
	if time_left > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			kind = ""
	_sweat_t = maxf(_sweat_t - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _sweat_t > 0.0:
		var sy := -height + 8.0 + fmod(_t * 10.0, 4.0)
		var sx := 6.0 * _sweat_side
		draw_rect(Rect2(sx, sy, 1, 1), SWEAT)
		draw_rect(Rect2(sx - 1, sy + 1, 3, 2), SWEAT)
		draw_rect(Rect2(sx, sy + 1, 1, 1), Color(0.85, 0.95, 1.0))
	if kind == "" or not ICONS.has(kind):
		return
	var rows: Array = ICONS[kind]
	var pop := minf(_t / 0.1, 1.0)
	var y0 := -height - 9.0 + roundf((1.0 - pop) * 3.0)
	if kind == "zzz":
		y0 += roundf(sin(_t * 3.0))
	var w := 9.0
	var h := 10.0
	var x0 := -4.0
	# balão com cantos arredondados e contorno
	draw_rect(Rect2(x0 + 1, y0, w - 2, h), INK)
	draw_rect(Rect2(x0, y0 + 1, w, h - 2), INK)
	draw_rect(Rect2(x0 + 1, y0 + 1, w - 2, h - 2), BUBBLE)
	# rabinho
	draw_rect(Rect2(x0 + 3, y0 + h, 3, 1), INK)
	draw_rect(Rect2(x0 + 4, y0 + h - 1, 1, 1), BUBBLE)
	draw_rect(Rect2(x0 + 4, y0 + h + 1, 1, 1), INK)
	var col: Color = COLORS.get(kind, INK)
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			if row[i] == "#":
				draw_rect(Rect2(x0 + 2 + i, y0 + 2 + j - 1, 1, 1), col)
