class_name StageMap
extends Control
## Mapa da fase (M / Tab), estilo Hollow Knight: só as salas visitadas
## aparecem desenhadas; as vizinhas ainda não visitadas ficam como contorno.
## Marca o Pavio (piscando), a saída, o chefe, os bancos, as lamparinas
## (acesas/apagadas) e as salas sombrias ainda escuras. Desenhado direto na
## tela 320x180 (pixels nítidos).

const SMALL := preload("res://assets/fonts/kenney_mini.ttf")
const BG := Color(0.03, 0.025, 0.06, 0.94)
const PAPER := Color(0.1, 0.09, 0.15)
const WALL := Color(0.62, 0.58, 0.72)
const WALL_DIM := Color(0.3, 0.28, 0.38)
const SPIKE := Color(0.85, 0.35, 0.4)
const PLAT := Color(0.5, 0.44, 0.36)
const DARK_ROOM := Color(0.2, 0.12, 0.32)
const OUTLINE := Color(0.32, 0.3, 0.42)
const WARM := Color(1.0, 0.72, 0.35)
const INK := Color(0.93, 0.9, 0.84)
const AREA := Rect2(10, 22, 300, 136) ## onde o mapa cabe na tela

var level: Node = null
var _tex: ImageTexture
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(320, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	rebuild()


## Monta a imagem (1 px por tile) só com as salas visitadas.
func rebuild() -> void:
	if level == null:
		return
	var layout: Dictionary = level.layout
	var w: int = int(layout["width"])
	var h: int = int(layout["height"])
	var rows: PackedStringArray = layout["rows"]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var visited: Dictionary = level.visited_rooms
	for r in layout["rooms"]:
		var idx := int(r["index"])
		if not visited.has(idx):
			continue
		var o: Array = r["origin"]
		var dark: bool = bool(r.get("dark", false)) and float(level.room_light_factor(idx)) < 0.999
		for y in range(int(o[1]), mini(int(o[1]) + LevelConst.ROOM_H, h)):
			for x in range(int(o[0]), mini(int(o[0]) + LevelConst.ROOM_W, w)):
				var c: String = rows[y][x]
				var col := DARK_ROOM if dark else PAPER
				if c == "#":
					col = WALL if _touches_air(rows, x, y, w, h) else Color(0, 0, 0, 0)
				elif c == "-":
					col = PLAT
				elif c == "^":
					col = SPIKE
				img.set_pixel(x, y, col)
	_tex = ImageTexture.create_from_image(img)
	_scale = minf(AREA.size.x / float(w), AREA.size.y / float(h))
	_scale = maxf(_scale, 0.25)
	if _scale >= 1.0:
		_scale = floorf(_scale) # escala inteira: pixels nítidos
	var drawn := Vector2(w, h) * _scale
	_origin = (AREA.position + (AREA.size - drawn) * 0.5).round()
	queue_redraw()


static func _touches_air(rows: PackedStringArray, x: int, y: int, w: int, h: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var xx: int = x + d.x
		var yy: int = y + d.y
		if xx < 0 or yy < 0 or xx >= w or yy >= h:
			continue
		if rows[yy][xx] != "#":
			return true
	return false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	return (_origin + p / float(LevelConst.TILE) * _scale).round()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_text(Vector2(10, 14), "Mapa — " + str(level.region.get("name", "Fase")) if level else "Mapa", WARM)
	if level == null or _tex == null:
		return
	var layout: Dictionary = level.layout
	# contorno das salas vizinhas ainda não visitadas
	var visited: Dictionary = level.visited_rooms
	for r in layout["rooms"]:
		var idx := int(r["index"])
		var o: Array = r["origin"]
		var rr := Rect2(_origin + Vector2(float(o[0]), float(o[1])) * _scale, Vector2(LevelConst.ROOM_W, LevelConst.ROOM_H) * _scale)
		if visited.has(idx):
			draw_rect(rr, OUTLINE, false, 1.0)
		elif _next_to_visited(r, visited):
			draw_rect(rr.grow(-1), Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.5), false, 1.0)
			_text(rr.get_center() - Vector2(2, -3), "?", Color(0.5, 0.48, 0.6))
	draw_texture_rect(_tex, Rect2(_origin, Vector2(_tex.get_width(), _tex.get_height()) * _scale), false)
	# marcadores (só em salas visitadas)
	for e in layout["entities"]:
		var room := int(e.get("room", -1))
		if not visited.has(room):
			continue
		var tile: Array = e["tile"]
		var at := _to_map(Vector2(float(tile[0]) + 0.5, float(tile[1]) + 0.5) * LevelConst.TILE)
		match str(e["type"]):
			"exit":
				draw_rect(Rect2(at + Vector2(-1, -3), Vector2(3, 4)), Color(0.55, 1.0, 0.7))
				draw_rect(Rect2(at + Vector2(0, -2), Vector2(1, 2)), BG)
			"boss":
				draw_rect(Rect2(at + Vector2(-1, -1), Vector2(3, 3)), Color(1.0, 0.3, 0.35))
				draw_rect(Rect2(at, Vector2(1, 1)), BG)
			"checkpoint":
				draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), Color(0.75, 0.6, 1.0))
				draw_rect(Rect2(at + Vector2(-1, -1), Vector2(1, 1)), Color(0.75, 0.6, 1.0))
	for n in level.entities.get_children():
		if n is Lamparina and visited.has((n as Lamparina).room_index):
			var lp := _to_map(n.global_position + Vector2(0, -6))
			if n.lit:
				draw_rect(Rect2(lp - Vector2(1, 1), Vector2(3, 3)), Color(WARM.r, WARM.g, WARM.b, 0.35))
				draw_rect(Rect2(lp, Vector2(1, 1)), WARM)
			else:
				draw_rect(Rect2(lp, Vector2(1, 1)), Color(0.45, 0.42, 0.5))
	# o Pavio (pisca)
	if level.player:
		var hp := _to_map(level.player.global_position + Vector2(0, -6))
		var on := fmod(_t, 0.8) < 0.55
		draw_rect(Rect2(hp - Vector2(2, 2), Vector2(5, 5)), Color(1.0, 0.6, 0.25, 0.3 if on else 0.15))
		draw_rect(Rect2(hp - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.95, 0.8) if on else WARM)
	# legenda
	var y := 170.0
	var x := 10.0
	x = _legend(x, y, Color(1.0, 0.95, 0.8), "você")
	x = _legend(x, y, Color(0.55, 1.0, 0.7), "saída")
	x = _legend(x, y, Color(1.0, 0.3, 0.35), "chefe")
	x = _legend(x, y, Color(0.75, 0.6, 1.0), "banco")
	x = _legend(x, y, WARM, "lamparina")
	x = _legend(x, y, DARK_ROOM.lightened(0.3), "sala sombria")
	var lamps := "Lamparinas %d/%d" % [int(level.result.get("lamps", 0)), int(level.result.get("lamps_total", 0))]
	_text(Vector2(310 - SMALL.get_string_size(lamps, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 14), lamps, WARM)


func _legend(x: float, y: float, c: Color, label: String) -> float:
	draw_rect(Rect2(Vector2(x, y - 4), Vector2(3, 3)), c)
	_text(Vector2(x + 5, y), label, Color(0.75, 0.72, 0.8))
	return x + 9.0 + SMALL.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x


func _text(p: Vector2, s: String, c: Color) -> void:
	draw_string(SMALL, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.8))
	draw_string(SMALL, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)


func _next_to_visited(r: Dictionary, visited: Dictionary) -> bool:
	var c: Array = r.get("cell", [])
	if c.is_empty():
		return false
	for other in level.layout["rooms"]:
		if not visited.has(int(other["index"])):
			continue
		var oc: Array = other.get("cell", [])
		if oc.is_empty():
			continue
		if absi(int(oc[0]) - int(c[0])) + absi(int(oc[1]) - int(c[1])) == 1:
			return true
	return false
