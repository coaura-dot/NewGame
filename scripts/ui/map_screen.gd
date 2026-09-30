extends CanvasLayer
## Mapa do mundo contínuo (estilo Hollow Knight), aberto com M durante a
## fase: corte lateral com o céu, a superfície e o subsolo; cada região
## visitada é desenhada com as salas que você explorou, portões e ligações
## (cadeado = precisa de habilidade), ícones de vila/chefe/santuário e a sua
## posição. Viagem rápida entre santuários e a escolha do Cerco final.

const FONT := preload("res://assets/fonts/kenney_pixel.ttf")
const CW := 74.0 ## largura de uma região no mapa (unidades de UI 480x270)
const CH := 58.0 ## altura de uma faixa (céu / superfície / subsolo)
const ROW := {-1: 0, 0: 1, 1: 2}
const LAYER_NAMES := ["CÉU", "SUPERFÍCIE", "SUBSOLO"]

var level: Node = null
var is_open: bool = false
var _root: Control
var _draw: Control
var _pan: Vector2 = Vector2.ZERO
var _sel: String = ""
var _t: float = 0.0
var _panel: Control = null
var _siege_mode: bool = false
var _dragging: bool = false
## "region" = mapa detalhado da região atual (terreno explorado, lugares,
## objetivo, saídas); "world" = mapa do mundo (viagem rápida). Tab alterna.
var _view: String = "region"
var _rtex: ImageTexture = null
var _rzoom: float = 1.0
var _rpan: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.size = Vector2(480, 270)
	_root.theme = UIKit.theme()
	add_child(_root)
	_draw = Control.new()
	_draw.size = Vector2(480, 270)
	_draw.mouse_filter = Control.MOUSE_FILTER_STOP
	_draw.draw.connect(_on_draw)
	_draw.gui_input.connect(_on_gui_input)
	_root.add_child(_draw)


func open() -> void:
	if Game.world.is_empty() or Game.training:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	_sel = str(Game.profile.get("region", ""))
	_center_on(_sel)
	_view = "region" if _has_region_map() else "world"
	if _view == "region":
		_build_region_texture()
		_rzoom = 1.0
		_rpan = Vector2.ZERO
	Audio.play("ui_confirm", 0.0, -6.0)


func close() -> void:
	is_open = false
	visible = false
	_close_panel()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if Game.world.is_empty() or Game.training:
		return
	if event.is_action_pressed("map"):
		if is_open:
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _panel:
			_close_panel()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif _panel == null and event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if _has_region_map():
			_view = "world" if _view == "region" else "region"
			if _view == "region":
				_build_region_texture()
			Audio.play("ui_move", 0.0, -8.0)
		get_viewport().set_input_as_handled()
	elif _panel == null and _view == "region":
		for pair in [["move_left", Vector2(1, 0)], ["move_right", Vector2(-1, 0)], ["move_up", Vector2(0, 1)], ["move_down", Vector2(0, -1)]]:
			if event.is_action_pressed(pair[0]):
				_rpan += pair[1] * 40.0
				get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			_rzoom = minf(_rzoom * 1.5, 4.0)
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_rzoom = maxf(_rzoom / 1.5, 1.0)
			if _rzoom <= 1.0:
				_rpan = Vector2.ZERO
	elif _panel == null:
		for pair in [["move_left", Vector2i(-1, 0)], ["move_right", Vector2i(1, 0)], ["move_up", Vector2i(0, -1)], ["move_down", Vector2i(0, 1)]]:
			if event.is_action_pressed(pair[0]):
				_move_sel(pair[1])
				get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
			_activate(_sel)
			get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if _view == "region":
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_rzoom = minf(_rzoom * 1.25, 4.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_rzoom = maxf(_rzoom / 1.25, 1.0)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event is InputEventMouseMotion and _dragging:
			_rpan += event.relative
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				var id := _region_at(event.position)
				if id != "":
					if id == _sel and event.double_click:
						_activate(id)
					_sel = id
	elif event is InputEventMouseMotion and _dragging:
		_pan += event.relative


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	_draw.queue_redraw()


# ---------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------

func _grid(id: String) -> Vector2i:
	var g: Array = Game.world["regions"][id].get("grid", [0, 0])
	return Vector2i(int(g[0]), int(g[1]))


func _box(id: String) -> Rect2:
	var g := _grid(id)
	return Rect2(Vector2(g.x * CW, 22.0 + ROW.get(g.y, 1) * CH) + _pan, Vector2(CW - 10.0, CH - 16.0))


func _center_on(id: String) -> void:
	if not Game.world["regions"].has(id):
		return
	var g := _grid(id)
	_pan = Vector2(240.0 - g.x * CW - (CW - 10.0) * 0.5, 0.0)


func _known(id: String) -> bool:
	var r: Dictionary = Game.world["regions"][id]
	if r.get("visited", false):
		return true
	for nb in WorldGenerator.neighbors(Game.world, id):
		if nb["kind"] != "rift" and Game.world["regions"][nb["id"]].get("visited", false):
			return true
	return false


func _region_at(pos: Vector2) -> String:
	for id in Game.world["regions"].keys():
		if Game.world["regions"][id].get("dimension", "prima") != "prima":
			continue
		if _known(id) and _box(id).grow(3).has_point(pos):
			return id
	return ""


func _move_sel(d: Vector2i) -> void:
	if _sel == "" or not Game.world["regions"].has(_sel):
		_sel = str(Game.profile.get("region", ""))
		return
	var g := _grid(_sel)
	var best := ""
	var best_d := INF
	for id in Game.world["regions"].keys():
		if id == _sel or not _known(id) or Game.world["regions"][id].get("dimension", "prima") != "prima":
			continue
		var o := _grid(id) - g
		if (d.x != 0 and signi(o.x) != d.x) or (d.y != 0 and signi(o.y) != d.y):
			continue
		var dd := absf(o.x) + absf(o.y) * 1.5 + (absf(o.y) * 3.0 if d.x != 0 else absf(o.x) * 3.0)
		if dd < best_d:
			best_d = dd
			best = id
	if best != "":
		_sel = best
		Audio.play("ui_move", 0.0, -10.0)
		var b := _box(best)
		if b.position.x < 10 or b.end.x > 470:
			_center_on(best)


# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------

func _activate(id: String) -> void:
	if id == "":
		return
	if _siege_mode:
		_confirm_siege(id)
		return
	var shrines: Array = Game.profile.get("shrines", [])
	if id == str(Game.profile.get("region", "")):
		_flash("Você está aqui.")
	elif not shrines.has(id):
		_flash("Sem santuário descoberto nesta região.")
	else:
		close()
		Game.travel(id, "", "shrine")


func _flash(text: String) -> void:
	Events.toast.emit(text)
	Audio.play("ui_error", 0.0, -8.0)


func _close_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_siege_mode = false


func _start_siege_choice() -> void:
	_close_panel()
	_siege_mode = true
	var p := UIKit.panel(Vector2(300, 0))
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.title("O Cerco", 22))
	var l := UIKit.label("A Maré ataca todas as regiões ao mesmo tempo. Você só pode estar em um lugar. Escolha a região que vai defender: todas as outras — com seus povos, amigos, amores e a reputação que você construiu — serão engolidas.", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(280, 0)
	v.add_child(l)
	v.add_child(UIKit.label("Selecione a região no mapa e confirme (Enter).", 10, UIKit.DIM))
	v.add_child(UIKit.button("Cancelar", _close_panel, 80))
	_panel = p
	p.position = Vector2(8, 176)
	_root.add_child(p)


func _confirm_siege(id: String) -> void:
	var r: Dictionary = Game.world["regions"][id]
	if r.get("destroyed", false) or r.get("dimension", "prima") != "prima":
		_flash("Escolha uma região do mundo principal.")
		return
	var c := SocialSystem.siege_consequences(Game.world, Game.social, id)
	_close_panel()
	_siege_mode = true
	var p := UIKit.panel(Vector2(320, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.title("Defender %s?" % r["name"], 16))
	v.add_child(UIKit.label("Regiões perdidas: %d" % c["lost_regions"].size(), 11, Color(1.5, 0.6, 0.5)))
	var names := []
	for n in c["lost_npcs"].slice(0, 6):
		names.append("%s %s" % [n["name"], "♥".repeat(SocialSystem.hearts(int(n["affinity"])))])
	if not names.is_empty():
		var nl := UIKit.label("Quem você perde: " + ", ".join(names) + ("…" if c["lost_npcs"].size() > 6 else ""), 10)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD
		nl.custom_minimum_size = Vector2(300, 0)
		v.add_child(nl)
	if c["spouse_lost"]:
		v.add_child(UIKit.label("Seu cônjuge não está nesta região.", 11, Color(2.0, 0.5, 0.6)))
	var row := UIKit.hbox(6)
	row.add_child(UIKit.button("Defender esta região", func():
		SocialSystem.apply_siege(Game.world, Game.social, id)
		Game.profile["region"] = id
		Game.save()
		close()
		Game.pending = {"region": id, "siege": true}
		Game.goto(Game.SCENE_LEVEL), 150))
	row.add_child(UIKit.button("Voltar", _close_panel, 70))
	v.add_child(row)
	_panel = p
	p.position = Vector2(80, 60)
	_root.add_child(p)
	UIKit.focus_first(p)


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _text(pos: Vector2, s: String, size: int, color: Color) -> void:
	_draw.draw_string_outline(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.03, 0.02, 0.06, color.a))
	_draw.draw_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _biome_color(r: Dictionary) -> Color:
	var b: Dictionary = DB.biome(r.get("biome", ""))
	var t: Array = b.get("tint", [1, 1, 1])
	var a: Array = b.get("ambient", [0.5, 0.5, 0.6])
	return Color(t[0] * a[0] * 1.4, t[1] * a[1] * 1.4, t[2] * a[2] * 1.4).clamp()


func _on_draw() -> void:
	if _view == "region":
		_draw_region()
		return
	var d := _draw
	# fundo: céu, superfície, subsolo (corte lateral)
	d.draw_rect(Rect2(0, 0, 480, 270), Color(0.04, 0.035, 0.07, 0.96))
	var bands := [Color(0.16, 0.22, 0.38, 0.55), Color(0.2, 0.26, 0.2, 0.5), Color(0.17, 0.12, 0.1, 0.6)]
	for i in 3:
		var y := 22.0 + i * CH - 4.0
		d.draw_rect(Rect2(0, y, 480, CH), bands[i])
		_text(Vector2(4, y + 10), LAYER_NAMES[i], 9, Color(0.8, 0.8, 0.9, 0.45))
	d.draw_line(Vector2(0, 22.0 + CH * 2 - 4), Vector2(480, 22.0 + CH * 2 - 4), Color(0.55, 0.45, 0.3, 0.6), 1.0)
	var regions: Dictionary = Game.world["regions"]
	var have: Array = Game.profile.get("abilities", [])
	# ligações
	for e in Game.world.get("edges", []):
		if e["kind"] == "rift":
			continue
		if not (_known(e["a"]) and _known(e["b"])):
			continue
		if not (regions[e["a"]].get("visited", false) or regions[e["b"]].get("visited", false)):
			continue
		var a := _box(e["a"]).get_center()
		var b := _box(e["b"]).get_center()
		var locked: bool = e["requires"] != "" and not have.has(e["requires"])
		var col := Color(1.4, 0.5, 0.4, 0.8) if locked else Color(0.9, 0.85, 0.7, 0.55)
		d.draw_line(a, b, col, 2.0 if not locked else 1.0)
		if locked:
			var m := (a + b) * 0.5
			d.draw_rect(Rect2(m - Vector2(3, 2), Vector2(6, 5)), Color(1.4, 0.5, 0.4))
			d.draw_arc(m + Vector2(0, -2), 2.0, PI, TAU, 6, Color(1.4, 0.5, 0.4), 1.0)
	var cur := str(Game.profile.get("region", ""))
	var shrines: Array = Game.profile.get("shrines", [])
	for id in regions.keys():
		var r: Dictionary = regions[id]
		if r.get("dimension", "prima") != "prima" or not _known(id):
			continue
		var box := _box(id)
		if box.end.x < -20 or box.position.x > 500:
			continue
		var visited: bool = r.get("visited", false)
		if not visited:
			d.draw_rect(box, Color(0.1, 0.09, 0.14, 0.9))
			d.draw_rect(box, Color(0.5, 0.45, 0.6, 0.5), false, 1.0)
			_text(box.get_center() + Vector2(-3, 4), "?", 14, Color(0.7, 0.65, 0.8, 0.8))
			continue
		var bc := _biome_color(r)
		d.draw_rect(box, Color(bc.r * 0.35, bc.g * 0.35, bc.b * 0.35, 0.95))
		if r.get("destroyed", false):
			d.draw_rect(box, Color(0.3, 0.05, 0.05, 0.7))
		_draw_rooms(id, box, bc, id == cur)
		var border := Color(1.0, 0.85, 0.5) if id == _sel else Color(bc.r, bc.g, bc.b, 0.8)
		if id == cur and fmod(_t, 1.0) < 0.5:
			border = Color(2.0, 1.8, 1.0)
		d.draw_rect(box, border, false, 2.0 if id == _sel else 1.0)
		# ícones
		var ix := box.position.x + 3.0
		var iy := box.position.y + 3.0
		if r.get("hub", "") != "":
			_icon_house(Vector2(ix, iy), UIKit.GOLD)
			ix += 9.0
		if r.get("boss", "") != "":
			_icon_skull(Vector2(ix, iy), Color(0.6, 0.6, 0.6) if r.get("cleared", false) else Color(1.6, 0.5, 0.4), r.get("cleared", false))
			ix += 9.0
		if shrines.has(id):
			d.draw_rect(Rect2(box.end.x - 6, box.position.y + 2, 3, 4), Color(2.0, 1.4, 0.5))
	# nome e dicas
	if _sel != "" and regions.has(_sel):
		var r: Dictionary = regions[_sel]
		var nm: String = r["name"] if r.get("visited", false) else "Região desconhecida"
		_text(Vector2(8, 14), nm, 14, UIKit.GOLD)
		var info := ""
		if r.get("visited", false):
			info = "Nível %d" % int(r.get("tier", 1))
			if r.get("cleared", false):
				info += " • concluída"
			if shrines.has(_sel):
				info += " • santuário (Enter: viajar)"
		_text(Vector2(8, 206), info, 10, UIKit.INK)
	_text(Vector2(8, 262), "Setas/arrastar: mover • Enter: viajar • Tab: mapa da região • M/Esc: fechar", 9, UIKit.DIM)
	if Game.is_siege_ready() and not Game.social.get("siege", {}).get("started", false) and _panel == null:
		_text(Vector2(330, 262), "[C] O CERCO COMEÇOU", 10, Color(2.0, 0.6, 0.4))


func _icon_house(p: Vector2, c: Color) -> void:
	_draw.draw_colored_polygon(PackedVector2Array([p + Vector2(0, 3), p + Vector2(3.5, 0), p + Vector2(7, 3)]), c)
	_draw.draw_rect(Rect2(p + Vector2(1, 3), Vector2(5, 4)), c)
	_draw.draw_rect(Rect2(p + Vector2(3, 5), Vector2(1, 2)), Color(0.1, 0.08, 0.12))


func _icon_skull(p: Vector2, c: Color, crossed: bool) -> void:
	_draw.draw_rect(Rect2(p + Vector2(1, 0), Vector2(5, 4)), c)
	_draw.draw_rect(Rect2(p + Vector2(2, 4), Vector2(3, 2)), c)
	_draw.draw_rect(Rect2(p + Vector2(2, 1), Vector2(1, 1)), Color(0.1, 0.08, 0.12))
	_draw.draw_rect(Rect2(p + Vector2(4, 1), Vector2(1, 1)), Color(0.1, 0.08, 0.12))
	if crossed:
		_draw.draw_line(p + Vector2(0, 0), p + Vector2(7, 7), Color(1.4, 1.3, 1.0), 1.0)


## Salas exploradas da região (resumo salvo por Game.record_map).
func _draw_rooms(id: String, box: Rect2, bc: Color, here: bool) -> void:
	var m: Dictionary = Game.profile.get("maps", {}).get(id, {})
	if m.is_empty():
		return
	var explored: Array = Game.profile.get("explored", {}).get(id, [])
	var w: int = maxi(int(m["w"]), 1)
	var h: int = maxi(int(m["h"]), 1)
	var inner := box.grow(-3)
	inner.position.y += 6
	inner.size.y -= 6
	var cs := minf(inner.size.x / w, inner.size.y / h)
	var off := inner.position + (inner.size - Vector2(w, h) * cs) * 0.5
	var rooms: Array = m["rooms"]
	for i in rooms.size():
		var rr: Array = rooms[i]
		var seen: bool = explored.has(i)
		var sz := Vector2(int(rr[3]), int(rr[4])) if rr.size() > 4 else Vector2.ONE
		var rect := Rect2(off + Vector2(int(rr[0]), int(rr[1])) * cs, sz * cs).grow(-0.5)
		if seen:
			var col := Color(bc.r * 1.1, bc.g * 1.1, bc.b * 1.1)
			match str(rr[2]):
				"boss": col = Color(1.4, 0.5, 0.4)
				"hub": col = Color(1.4, 1.2, 0.6)
				"passage": col = Color(0.8, 1.0, 1.3)
				"treasure", "secret": col = Color(1.3, 1.1, 0.5)
			_draw.draw_rect(rect, col)
		else:
			_draw.draw_rect(rect, Color(bc.r, bc.g, bc.b, 0.12))
	if here and level and is_instance_valid(level) and level.player:
		var p: Vector2 = level.player.global_position / level._cell_px
		var dot := off + p * cs
		if fmod(_t, 0.6) < 0.4:
			_draw.draw_rect(Rect2(dot - Vector2(1.5, 1.5), Vector2(3, 3)), Color(3, 3, 3))


func _input(event: InputEvent) -> void:
	if is_open and _panel == null and event is InputEventKey and event.pressed and event.keycode == KEY_C:
		if Game.is_siege_ready() and not Game.social.get("siege", {}).get("started", false):
			_start_siege_choice()


# ---------------------------------------------------------------------------
# Mapa da região atual (estilo Hollow Knight)
# ---------------------------------------------------------------------------

func _has_region_map() -> bool:
	return level != null and is_instance_valid(level) and level.world_mode and level.layout.has("macro")


func _explored() -> Array:
	return Game.profile.get("explored", {}).get(level.region_id, [])


## Terreno dos lugares já visitados, 1 pixel por tile: bordas da rocha em
## tom de pergaminho, espaço aberto escuro, plataformas finas.
func _build_region_texture() -> void:
	var lay: Dictionary = level.layout
	var rows: PackedStringArray = lay["rows"]
	var w: int = int(lay["width"])
	var h: int = int(lay["height"])
	var m: Dictionary = lay["macro"]
	var owners: Array = m["owner"]
	var cw: int = int(m["cw"])
	var ch: int = int(m["ch"])
	var gw: int = int(m["gw"])
	var seen := {}
	for i in _explored():
		seen[int(i)] = true
	var bg: PackedStringArray = lay.get("bg", PackedStringArray())
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var edge := Color(0.93, 0.85, 0.66)
	var open := Color(0.16, 0.14, 0.2, 0.92)
	var plat := Color(0.75, 0.66, 0.5)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var o: int = int(owners[(y / ch) * gw + (x / cw)])
			if o < 0 or not seen.has(o):
				continue
			var c := row.unicode_at(x)
			if c == 35:
				var border := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx: int = x + d.x
					var yy: int = y + d.y
					if xx >= 0 and yy >= 0 and xx < w and yy < h and rows[yy].unicode_at(xx) != 35:
						border = true
				if border:
					img.set_pixel(x, y, edge)
			elif c == 45:
				img.set_pixel(x, y, plat)
			elif bg.is_empty() or bg[y].unicode_at(x) != 48:
				img.set_pixel(x, y, open)
	_rtex = ImageTexture.create_from_image(img)


func _region_xf() -> Array:
	var lay: Dictionary = level.layout
	var w := float(lay["width"])
	var h := float(lay["height"])
	var area := Rect2(10, 34, 460, 206)
	var sc := minf(area.size.x / w, area.size.y / h) * _rzoom
	var size := Vector2(w, h) * sc
	var off := area.position + (area.size - size) * 0.5 + _rpan
	return [off, sc]


func _draw_region() -> void:
	var d := _draw
	d.draw_rect(Rect2(0, 0, 480, 270), Color(0.05, 0.04, 0.07, 0.97))
	var lay: Dictionary = level.layout
	var xf := _region_xf()
	var off: Vector2 = xf[0]
	var sc: float = xf[1]
	d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _rtex:
		d.draw_texture_rect(_rtex, Rect2(off, Vector2(float(lay["width"]), float(lay["height"])) * sc), false)
	var T := LevelConst.TILE
	var seen := {}
	for i in _explored():
		seen[int(i)] = true
	var rooms: Array = lay["rooms"]
	# ícones das coisas importantes nos lugares visitados
	for e in lay["entities"]:
		var room := int(e.get("room", -1))
		if not seen.has(room):
			continue
		var p := off + (Vector2(int(e["tile"][0]), int(e["tile"][1])) + Vector2(0.5, 0.0)) * sc
		match str(e["type"]):
			"checkpoint":
				_icon_flame(p)
			"boss":
				var alive: bool = level.boss_node != null and is_instance_valid(level.boss_node) and not level.boss_node.dead
				_icon_skull(p - Vector2(3.5, 6), Color(1.6, 0.5, 0.4) if alive else Color(0.6, 0.6, 0.6), not alive)
			"chest", "relic":
				d.draw_rect(Rect2(p - Vector2(2, 4), Vector2(4, 4)), Color(2.0, 1.6, 0.5))
			"npc", "quest_board":
				d.draw_circle(p - Vector2(0, 3), 2.0, Color(0.7, 1.4, 1.0))
			"rift":
				d.draw_circle(p - Vector2(0, 3), 3.0, Color(1.4, 0.7, 2.4))
	# nomes dos lugares visitados
	for r in rooms:
		if not seen.has(int(r["index"])):
			continue
		var rr: Array = r["rect"]
		var rect := Rect2(off + Vector2(int(rr[0]), int(rr[1])) * sc, Vector2(int(rr[2]), int(rr[3])) * sc)
		var nm := str(r.get("name", ""))
		var fw := FONT.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		if fw < rect.size.x * 1.6 or _rzoom > 1.4:
			var nx := clampf(rect.get_center().x - fw * 0.5, 4.0, 476.0 - fw)
			_text(Vector2(nx, rect.position.y + 10), nm, 9, Color(0.95, 0.9, 0.75, 0.85))
	# saídas: seta + região vizinha (se o lugar da saída foi visitado)
	for pt in lay.get("ports", []):
		if not seen.has(int(pt["room"])):
			continue
		var rr2: Array = rooms[int(pt["room"])]["rect"]
		var rect2 := Rect2(off + Vector2(int(rr2[0]), int(rr2[1])) * sc, Vector2(int(rr2[2]), int(rr2[3])) * sc)
		var to_name := str(Game.world["regions"].get(pt["to"], {}).get("name", "?"))
		var label := to_name
		var lw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 9.0
		var lp := rect2.get_center()
		match str(pt["dir"]):
			"L": lp = Vector2(rect2.position.x + 2, rect2.get_center().y + 12)
			"R": lp = Vector2(rect2.end.x - lw - 2, rect2.get_center().y + 12)
			"U": lp = Vector2(rect2.get_center().x - lw * 0.5, rect2.position.y + 20)
			"D": lp = Vector2(rect2.get_center().x - lw * 0.5, rect2.end.y - 4)
		var locked: bool = str(pt.get("requires", "")) != "" and not Game.profile.get("abilities", []).has(str(pt["requires"]))
		var pc := Color(1.4, 0.6, 0.5) if locked else Color(0.7, 1.1, 1.5)
		lp.x = clampf(lp.x, 4.0, 476.0 - lw)
		_arrow(lp + Vector2(3, -3), str(pt["dir"]), pc)
		_text(lp + Vector2(9, 0), label, 9, pc)
	# objetivo (sempre marcado: é o rumo da região)
	var obj: Dictionary = lay.get("objective", {})
	if not obj.is_empty() and int(obj.get("room", -1)) >= 0:
		var rr3: Array = rooms[int(obj["room"])]["rect"]
		var c := off + (Vector2(int(rr3[0]), int(rr3[1])) + Vector2(int(rr3[2]), int(rr3[3])) * 0.5) * sc
		var pulse := 3.0 + sin(_t * 5.0) * 1.0
		var oc := Color(2.4, 1.3, 0.5) if not level.region.get("cleared", false) else Color(0.7, 0.7, 0.7)
		d.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -pulse - 2), c + Vector2(pulse + 2, 0), c + Vector2(0, pulse + 2), c + Vector2(-pulse - 2, 0)]), Color(0.05, 0.03, 0.02, 0.8))
		d.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -pulse), c + Vector2(pulse, 0), c + Vector2(0, pulse), c + Vector2(-pulse, 0)]), oc)
	# você está aqui
	if level.player:
		var pp: Vector2 = off + level.player.global_position / T * sc
		if fmod(_t, 0.6) < 0.42:
			d.draw_circle(pp - Vector2(0, 3), 3.0, Color(0.1, 0.05, 0.02))
			d.draw_circle(pp - Vector2(0, 3), 2.0, Color(3.0, 2.0, 0.8))
	# cabeçalho e rodapé
	_text(Vector2(8, 14), str(level.region.get("name", "")), 14, UIKit.GOLD)
	var room_i: int = level.room_at(level.player.global_position) if level.player else -1
	if room_i >= 0:
		_text(Vector2(8, 27), str(rooms[room_i].get("name", "")), 10, UIKit.INK)
	if not obj.is_empty():
		var ot := ("Concluído: " if level.region.get("cleared", false) else "Objetivo: ") + str(obj.get("text", ""))
		var ow := FONT.get_string_size(ot, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_text(Vector2(472 - ow, 14), ot, 10, Color(2.0, 1.3, 0.6))
	_legend(Vector2(8, 250))
	_text(Vector2(8, 264), "Setas/arrastar: mover • +/-/roda: zoom • Tab: mapa do mundo (viagem rápida) • M/Esc: fechar", 9, UIKit.DIM)


func _legend(p: Vector2) -> void:
	var x := p.x
	_icon_flame(Vector2(x + 3, p.y + 1))
	_text(Vector2(x + 8, p.y), "Santuário", 9, UIKit.DIM)
	x += 58
	_icon_skull(Vector2(x, p.y - 7), Color(1.6, 0.5, 0.4), false)
	_text(Vector2(x + 10, p.y), "Guardião", 9, UIKit.DIM)
	x += 54
	_draw.draw_rect(Rect2(x, p.y - 5, 4, 4), Color(2.0, 1.6, 0.5))
	_text(Vector2(x + 7, p.y), "Tesouro", 9, UIKit.DIM)
	x += 50
	_draw.draw_circle(Vector2(x + 2, p.y - 3), 2.0, Color(0.7, 1.4, 1.0))
	_text(Vector2(x + 7, p.y), "Pessoas", 9, UIKit.DIM)
	x += 50
	_draw.draw_colored_polygon(PackedVector2Array([Vector2(x + 3, p.y - 7), Vector2(x + 6, p.y - 4), Vector2(x + 3, p.y - 1), Vector2(x, p.y - 4)]), Color(2.4, 1.3, 0.5))
	_text(Vector2(x + 9, p.y), "Objetivo", 9, UIKit.DIM)


func _icon_flame(p: Vector2) -> void:
	_draw.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(3, -2), p + Vector2(0, 0), p + Vector2(-3, -2)]), Color(2.4, 1.2, 0.4))
	_draw.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(1.5, -1.5), p + Vector2(0, -0.5), p + Vector2(-1.5, -1.5)]), Color(3.0, 2.4, 1.2))


func _arrow(p: Vector2, dir: String, c: Color) -> void:
	var pts := PackedVector2Array()
	match dir:
		"L": pts = PackedVector2Array([p + Vector2(-3, 0), p + Vector2(2, -3), p + Vector2(2, 3)])
		"R": pts = PackedVector2Array([p + Vector2(3, 0), p + Vector2(-2, -3), p + Vector2(-2, 3)])
		"U": pts = PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 2), p + Vector2(-3, 2)])
		_: pts = PackedVector2Array([p + Vector2(0, 3), p + Vector2(3, -2), p + Vector2(-3, -2)])
	_draw.draw_colored_polygon(pts, c)
