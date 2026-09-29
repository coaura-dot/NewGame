class_name OverworldUI
extends CanvasLayer
## Interface do mapa-múndi, desenhada direto na tela 320x180: faixa com o
## nome da região ao entrar nela, dica de ação ("Espaço: Entrar..."),
## minimapa com névoa, contador de brasas/chefes, ajuda dos controles e o
## painel de história (Grande Lareira, placas). Também o escurecer ao entrar
## numa fase.

const FONT := preload("res://assets/fonts/kenney_pixel.ttf")
const FONT_MINI := preload("res://assets/fonts/kenney_mini.ttf")
const INK := Color(0.106, 0.082, 0.157)
const MINI := Vector2i(72, 46)

var overworld: Overworld = null
var _draw_node: Control
var _root: Control
var _panel: Control = null
var _banner: Dictionary = {}
var _banner_t: float = 0.0
var _help_t: float = 12.0
var _fade: ColorRect
var _mini_img: Image
var _mini_tex: ImageTexture
var _mini_dirty: bool = true
var _t: float = 0.0
var _intro_i: int = -1 ## cartão da introdução (-1 = sem introdução)
var _intro_t: float = 0.0
const HERO_TEX := preload("res://assets/art/hero/hero.png")
const OBJ_TEX := preload("res://assets/art/overworld/objects.png")


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Control.new()
	_draw_node.size = Vector2(320, 180)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_draw_ui)
	add_child(_draw_node)
	_root = Control.new()
	UIKit.fit(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.01, 0.05, 1.0)
	_fade.size = Vector2(320, 180)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


## Introdução do novo jogo: cartões com a história da Grande Lareira.
func play_intro() -> void:
	_intro_i = 0
	_intro_t = 0.0
	get_tree().paused = true


func _next_intro() -> void:
	if _intro_t < 0.4:
		return
	_intro_i += 1
	_intro_t = 0.0
	Audio.play("ui_move", 0.0, -10.0)
	if _intro_i >= Lore.INTRO.size():
		_intro_i = -1
		get_tree().paused = false
		var flags: Dictionary = Game.profile.get("flags", {})
		flags["intro_seen"] = true
		Game.profile["flags"] = flags
		Game.save()
		_banner_t = 5.5


func _process(delta: float) -> void:
	_t += delta
	if _intro_i >= 0:
		_intro_t += delta
	_banner_t = maxf(_banner_t - delta, 0.0)
	_help_t = maxf(_help_t - delta, 0.0)
	_draw_node.queue_redraw()


func mark_minimap_dirty() -> void:
	_mini_dirty = true


func show_region(r: Dictionary, first: bool) -> void:
	var biome: String = DB.biome(r["biome"]).get("name", r["biome"])
	var layer_name: String = {"sky": "céu", "surface": "superfície", "underground": "subterrâneo"}.get(r["layer"], "")
	var status := "inexplorada"
	var status_color := Color(0.75, 0.72, 0.85)
	if r.get("cleared", false):
		status = "limpa — a luz voltou"
		status_color = Color(0.55, 1.0, 0.6)
	elif str(r.get("boss", "")) != "":
		status = "guardião: %s" % str(DB.enemy(r["boss"]).get("name", ""))
		status_color = Color(1.0, 0.5, 0.45)
	elif r.get("visited", false) and not first:
		status = "visitada"
	_banner = {"name": r["name"], "sub": "%s · %s · tier %d" % [biome, layer_name, int(r["tier"])], "status": status, "status_color": status_color, "lore": Lore.region_line(r)}
	_banner_t = 4.5 if not first else 5.5
	_mini_dirty = true


func fade_out(then: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(then)


func show_story(title_text: String, text: String) -> void:
	close_panel()
	var p := UIKit.panel(Vector2(300, 0))
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(UIKit.title(title_text, 20))
	var l := UIKit.label(text, 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(280, 0)
	v.add_child(l)
	v.add_child(UIKit.button("Fechar", close_panel, 80))
	_panel = UIKit.centered(p)
	_root.add_child(_panel)
	get_tree().paused = true
	UIKit.focus_first(p)


func close_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _intro_i >= 0:
		if event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
			_next_intro()
			get_viewport().set_input_as_handled()
		return
	if _panel and (event.is_action_pressed("pause") or event.is_action_pressed("jump")):
		close_panel()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _text(pos: Vector2, s: String, size: int, color: Color, font: Font = FONT, center: bool = false) -> void:
	var d := _draw_node
	var x := pos.x
	if center:
		x = roundf(pos.x - font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		d.draw_string(font, Vector2(x, pos.y) + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK.r, INK.g, INK.b, color.a))
	d.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_ui() -> void:
	if _intro_i >= 0:
		_draw_intro()
		return
	if overworld == null or overworld.hero == null:
		return
	_draw_minimap()
	_draw_status()
	# faixa da região: nome, bioma/tier, situação e uma frase de lore
	if _banner_t > 0.0 and not _banner.is_empty():
		var a := clampf(minf(_banner_t, 5.5 - _banner_t + 0.01) * 2.5, 0.0, 1.0)
		var d := _draw_node
		var bx := 66.0
		var bw := 172.0
		d.draw_rect(Rect2(bx, 8, bw, 38), Color(0.05, 0.04, 0.09, 0.74 * a))
		d.draw_rect(Rect2(bx, 8, bw, 1), Color(1.0, 0.8, 0.45, 0.8 * a))
		d.draw_rect(Rect2(bx, 45, bw, 1), Color(1.0, 0.8, 0.45, 0.8 * a))
		_text(Vector2(152, 21), _banner["name"], 16, Color(1.0, 0.85, 0.5, a), FONT, true)
		_text(Vector2(152, 31), _banner["sub"], 8, Color(0.85, 0.82, 0.95, a), FONT_MINI, true)
		_text(Vector2(152, 41), _banner["status"], 8, Color(_banner["status_color"].r, _banner["status_color"].g, _banner["status_color"].b, a), FONT_MINI, true)
		if str(_banner.get("lore", "")) != "":
			_text(Vector2(160, 58), _banner["lore"], 8, Color(0.95, 0.92, 0.85, a * 0.9), FONT_MINI, true)
	# dica de ação
	var f: Dictionary = overworld.focus
	if not f.is_empty() and _panel == null:
		var s := "Espaço: %s" % f["prompt"]
		var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var y := 158.0 + sin(_t * 4.0)
		_draw_node.draw_rect(Rect2(160 - w * 0.5 - 5, y - 11, w + 10, 15), Color(0.05, 0.04, 0.09, 0.75))
		_text(Vector2(160, y), s, 16, Color(1.0, 0.92, 0.75), FONT, true)
	# ajuda
	if _help_t > 0.0:
		var a2 := clampf(_help_t, 0.0, 1.0)
		_text(Vector2(160, 176), "WASD andar · Shift correr · Espaço falar/entrar · M mapa · Esc pausa", 8, Color(0.85, 0.82, 0.95, a2), FONT_MINI, true)


func _draw_status() -> void:
	var embers := int(Game.profile.get("currency", 0))
	var bosses: int = Game.profile.get("bosses_defeated", []).size()
	var total: int = Game.world.get("abilities_order", []).size() + 1
	var d := _draw_node
	# brasa (losango laranja) + número
	d.draw_rect(Rect2(6, 7, 3, 1), Color(1.0, 0.6, 0.2))
	d.draw_rect(Rect2(5, 8, 5, 2), Color(1.0, 0.75, 0.3))
	d.draw_rect(Rect2(6, 10, 3, 1), Color(0.9, 0.4, 0.15))
	_text(Vector2(13, 12), "%d" % embers, 8, Color(1.0, 0.9, 0.7), FONT_MINI)
	_text(Vector2(5, 22), "Chefes %d/%d" % [bosses, total], 8, Color(0.95, 0.75, 0.7), FONT_MINI)
	var clock: float = float(Game.profile.get("ow_clock", 0.3))
	var hour := int(clock * 24.0)
	_text(Vector2(5, 32), "%02d:00 %s" % [hour, "☾" if overworld.night > 0.5 else ""], 8, Color(0.8, 0.85, 1.0), FONT_MINI)


func _draw_minimap() -> void:
	var ow := overworld
	var w: int = ow.data["w"]
	var h: int = ow.data["h"]
	if _mini_dirty or _mini_img == null:
		_mini_dirty = false
		_mini_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				_mini_img.set_pixel(x, y, ow.mini_color(x, y))
		if _mini_tex == null:
			_mini_tex = ImageTexture.create_from_image(_mini_img)
		else:
			_mini_tex.update(_mini_img)
	var d := _draw_node
	var origin := Vector2(320 - MINI.x - 5, 5)
	var hc := (ow.hero.global_position / Overworld.T).floor()
	var src := Rect2(hc - Vector2(MINI) * 0.5, Vector2(MINI))
	src.position = src.position.clamp(Vector2.ZERO, Vector2(w, h) - Vector2(MINI))
	d.draw_rect(Rect2(origin - Vector2(2, 2), Vector2(MINI) + Vector2(4, 4)), INK)
	d.draw_rect(Rect2(origin - Vector2(1, 1), Vector2(MINI) + Vector2(2, 2)), Color(0.85, 0.72, 0.45))
	d.draw_texture_rect_region(_mini_tex, Rect2(origin, Vector2(MINI)), src)
	# entradas conhecidas
	for id in ow.data["entrances"].keys():
		if not ow.known.has(id):
			continue
		var c: Vector2 = Vector2(ow.data["entrances"][id]) - src.position
		if c.x < 0 or c.y < 0 or c.x >= MINI.x or c.y >= MINI.y:
			continue
		var cleared: bool = Game.world["regions"][id].get("cleared", false)
		var col := Color(0.4, 1.0, 0.5) if cleared else Color(1.0, 0.35, 0.3)
		d.draw_rect(Rect2(origin + c - Vector2(1, 1), Vector2(3, 3)), INK)
		d.draw_rect(Rect2(origin + c, Vector2(1, 1)), col)
	# herói (pisca)
	var hp := hc - src.position
	if int(_t * 4.0) % 2 == 0:
		d.draw_rect(Rect2(origin + hp - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.95, 0.6))
	d.draw_rect(Rect2(origin + hp, Vector2(1, 1)), Color(0.9, 0.3, 0.2))


func _draw_intro() -> void:
	var d := _draw_node
	d.draw_rect(Rect2(0, 0, 320, 180), Color(0.03, 0.02, 0.06))
	var a := clampf(_intro_t * 1.6, 0.0, 1.0)
	var i := _intro_i
	# ilustração
	var c := Vector2(160, 70)
	if i <= 1:
		# a Grande Lareira (acesa no 1º cartão, apagada no 2º)
		var m: Dictionary = Overworld._ometa.get("hearth", {})
		if not m.is_empty():
			var r: Array = m["rect"]
			d.draw_texture_rect_region(OBJ_TEX, Rect2(c - Vector2(r[2], r[3] + 4), Vector2(r[2], r[3]) * 2.0), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, a))
		if i == 0:
			for k in 5:
				var fx := c.x - 20.0 + k * 10.0
				var fh := 12.0 + sin(_t * 9.0 + k * 1.7) * 3.0 + (8.0 if k == 2 else 0.0)
				_flame_shape(Vector2(fx, c.y - 6), fh, 7.0, a)
		else:
			for k in 5:
				var y := c.y - 8.0 - fmod(_t * 14.0 + k * 9.0, 40.0)
				d.draw_rect(Rect2(c.x - 6 + k * 3 + sin(_t * 2.0 + k) * 3.0, y, 2, 2), Color(0.55, 0.52, 0.6, a * 0.7))
	elif i == 2:
		# brasas voando para longe
		for k in 12:
			var ang := k * 0.52 + _t * 0.3
			var r2 := 20.0 + fmod(_t * 18.0 + k * 11.0, 70.0)
			var p := c + Vector2(cos(ang), sin(ang) * 0.6) * r2
			d.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(2.6, 1.0, 0.25, a * (1.0 - r2 / 90.0)))
	else:
		# a gota de cera que vira o Pavio
		var s := 3.0
		if i == 3:
			var drop := minf(_intro_t * 30.0, 30.0)
			d.draw_rect(Rect2(c.x - 2, c.y - 40 + drop, 4, 5), Color(0.97, 0.91, 0.8, a))
			d.draw_rect(Rect2(c.x - 1, c.y - 42 + drop, 2, 2), Color(0.97, 0.91, 0.8, a))
			if _intro_t > 1.2:
				var eye_a := clampf((_intro_t - 1.2) * 3.0, 0.0, 1.0)
				d.draw_rect(Rect2(c.x - 1, c.y - 8, 1, 2), Color(INK.r, INK.g, INK.b, eye_a))
				d.draw_rect(Rect2(c.x + 1, c.y - 8, 1, 2), Color(INK.r, INK.g, INK.b, eye_a))
		else:
			d.draw_texture_rect_region(HERO_TEX, Rect2(c - Vector2(8, 16) * s, Vector2(16, 16) * s), Rect2(0, 0, 16, 16), Color(1, 1, 1, a))
			# olhos e chama por cima (âncoras do quadro idle0: olho 7,8; chama 8,4)
			var o := c - Vector2(8, 16) * s
			d.draw_rect(Rect2(o + Vector2(7, 8) * s, Vector2(1, 2) * s), Color(INK.r, INK.g, INK.b, a))
			d.draw_rect(Rect2(o + Vector2(10, 8) * s, Vector2(1, 2) * s), Color(INK.r, INK.g, INK.b, a))
			d.draw_rect(Rect2(o + Vector2(6, 10) * s, Vector2(1, 1) * s), Color(0.94, 0.54, 0.63, a))
			d.draw_rect(Rect2(o + Vector2(11, 10) * s, Vector2(1, 1) * s), Color(0.94, 0.54, 0.63, a))
			_flame_shape(o + Vector2(8.5, 5) * s, (5.0 + sin(_t * 12.0)) * s, 3.0 * s, a)
	# texto do cartão (quebrado pela largura da tela)
	var lines: PackedStringArray = []
	for para in str(Lore.INTRO[i]).split("\n"):
		lines.append_array(_wrap(para, 16, 300.0))
	var y0 := 118.0 - maxf(lines.size() - 3, 0) * 6.0
	for k in lines.size():
		_text(Vector2(160, y0 + k * 12), lines[k], 16, Color(0.95, 0.9, 0.8, a), FONT, true)
	if _intro_t > 0.8:
		_text(Vector2(160, 174), "Espaço: continuar", 8, Color(0.7, 0.65, 0.8, 0.5 + 0.5 * sin(_t * 4.0)), FONT_MINI, true)


## Quebra um parágrafo em linhas que cabem em max_w pixels.
func _wrap(text: String, size: int, max_w: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var line := ""
	for word in text.split(" "):
		var cand := word if line == "" else line + " " + word
		if FONT.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and line != "":
			out.append(line)
			line = word
		else:
			line = cand
	if line != "":
		out.append(line)
	return out


## Chama em gota (base larga, ponta fina), do laranja ao miolo claro. HDR.
func _flame_shape(base: Vector2, h: float, w: float, a: float) -> void:
	var d := _draw_node
	var rows := int(h)
	for k in rows:
		var t := float(k) / maxf(rows - 1, 1)
		var ww := w * (1.0 - t * t) * (0.7 + 0.3 * sin(t * PI))
		var sway := sin(_t * 8.0 + base.x * 0.3 + t * 3.0) * t * 1.5
		var col := Color(2.4, 0.8, 0.2, a) if t > 0.55 else Color(2.8, 1.5, 0.35, a)
		d.draw_rect(Rect2(roundf(base.x - ww * 0.5 + sway), base.y - k, maxf(roundf(ww), 1.0), 1), col)
		if t < 0.5 and ww > 2.0:
			d.draw_rect(Rect2(roundf(base.x - ww * 0.2 + sway), base.y - k, maxf(roundf(ww * 0.4), 1.0), 1), Color(3.0, 2.7, 1.6, a))
