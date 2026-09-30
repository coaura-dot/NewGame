class_name Signpost
extends Node2D
## Placa de madeira na beira do caminho: mostra para onde a trilha leva
## (seta pintada na tábua + "Mata das Raízes Velhas"). O texto aparece
## quando a Faísca se aproxima. Desenhada na densidade da arte (px de 1/ART).

const FONT := preload("res://assets/fonts/kenney_mini.ttf")
const WOOD := Color(0.42, 0.28, 0.17)
const WOOD_L := Color(0.58, 0.4, 0.24)
const WOOD_D := Color(0.24, 0.15, 0.1)
const LINE := Color(0.09, 0.06, 0.05)

var text: String = ""
## "L"/"R"/"U"/"D": para onde a placa aponta
var dir: String = "R"
var level: Node = null
var _a: float = 0.0


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	var near := false
	if level and is_instance_valid(level) and level.player:
		near = level.player.global_position.distance_to(global_position) < 44.0
	_a = move_toward(_a, 1.0 if near else 0.0, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var k := float(LevelConst.ART)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / k)
	# poste
	draw_rect(Rect2(-3, -30, 6, 30), LINE)
	draw_rect(Rect2(-2, -30, 4, 30), WOOD)
	draw_rect(Rect2(-2, -30, 1, 30), WOOD_L)
	# tábua em seta
	var right := dir != "L"
	var pts := PackedVector2Array()
	if right:
		pts = PackedVector2Array([Vector2(-16, -34), Vector2(12, -34), Vector2(18, -27), Vector2(12, -20), Vector2(-16, -20)])
	else:
		pts = PackedVector2Array([Vector2(16, -34), Vector2(-12, -34), Vector2(-18, -27), Vector2(-12, -20), Vector2(16, -20)])
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(p + (p - Vector2(0, -27)).normalized() * 1.2)
	draw_colored_polygon(outline, LINE)
	draw_colored_polygon(pts, WOOD)
	draw_line(Vector2(-14 if right else -10, -32), Vector2(10 if right else 14, -32), WOOD_L, 1.0)
	draw_line(Vector2(-14 if right else -10, -22), Vector2(10 if right else 14, -22), WOOD_D, 1.0)
	if _a > 0.01 and text != "":
		var fw := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var pos := Vector2(roundf(-fw * 0.5), -44.0 - (1.0 - _a) * 4.0)
		draw_rect(Rect2(pos + Vector2(-4, -9), Vector2(fw + 8, 12)), Color(0.05, 0.03, 0.1, 0.72 * _a))
		draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.92, 0.72, _a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
