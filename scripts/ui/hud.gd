extends CanvasLayer
## HUD da fase + painéis de diálogo (NPC), mural de missões e resumo.

const FONT := preload("res://assets/fonts/kenney_pixel.ttf")

var level: Node = null
var player: Node = null
var boss: Node = null
var _root: Control
var _draw_node: Control
var _toasts: VBoxContainer
var _combo: int = 0
var _combo_pop: float = 0.0
var _chain: int = 0
var _chain_pop: float = 0.0
var _hp_ghost: float = 1.0
var _panel: Control = null
var _region_title_t: float = 0.0
var _region_title: String = ""
var _weapon_t: float = 4.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	# HUD em pixel art, direto na tela 320x180
	_draw_node = Control.new()
	_draw_node.position = Vector2.ZERO
	_draw_node.size = Vector2(320, 180)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_draw_hud)
	add_child(_draw_node)
	# painéis e avisos: diagramados em 480x270 e reduzidos
	_root = Control.new()
	UIKit.fit(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	_toasts = UIKit.vbox(2)
	_toasts.position = Vector2(90, 44)
	_toasts.size = Vector2(300, 100)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	Events.toast.connect(toast)
	Events.air_chain_changed.connect(func(c):
		if c > _chain:
			_chain_pop = 1.0
		_chain = c)
	Events.combo_changed.connect(func(c):
		if c > _combo:
			_combo_pop = 1.0
		_combo = c)
	Events.dialogue_requested.connect(open_dialogue)
	Events.player_spawned.connect(func(p): player = p)
	Events.player_equipment_changed.connect(func(): _weapon_t = 3.0)
	if level:
		player = level.player
		_region_title = level.region.get("name", "")
		if str(level.params.get("theme", "")) == "frenesi":
			_region_title += " · FRENESI"
		_region_title_t = 3.5


func _process(delta: float) -> void:
	if player == null and level:
		player = level.player
	_combo_pop = maxf(_combo_pop - delta * 4.0, 0.0)
	_chain_pop = maxf(_chain_pop - delta * 5.0, 0.0)
	_region_title_t = maxf(_region_title_t - delta, 0.0)
	_weapon_t = maxf(_weapon_t - delta, 0.0)
	if player:
		var ratio: float = player.hp / maxf(player.max_hp(), 1.0)
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 0.5) if _hp_ghost > ratio else ratio
	_draw_node.queue_redraw()


func toast(text: String) -> void:
	if text == "":
		return
	var l := UIKit.label(text, 12, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(300, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	if _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()


func show_boss(b: Node) -> void:
	boss = b


func hide_boss() -> void:
	boss = null


# ---------------------------------------------------------------------------
# Desenho da HUD (pixel art 1x)
# ---------------------------------------------------------------------------

const SMALL := preload("res://assets/fonts/kenney_mini.ttf")
const INK := Color(0.106, 0.082, 0.157)
const WAX := Color(0.96, 0.91, 0.78)
const WAX_EMPTY := Color(0.3, 0.27, 0.36)
const HP_PER_CANDLE := 20.0 ## cada velinha do HUD vale 20 de vida


func _text(pos: Vector2, s: String, _size: int = 8, color: Color = Color(1, 1, 1), outline: bool = true) -> void:
	var d := _draw_node
	pos = pos.round()
	if outline:
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			d.draw_string(SMALL, pos + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK.r, INK.g, INK.b, color.a))
	d.draw_string(SMALL, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


func _bar(rect: Rect2, ratio: float, color: Color, ghost: float = -1.0) -> void:
	var d := _draw_node
	d.draw_rect(rect.grow(1), INK)
	d.draw_rect(rect, Color(0.18, 0.15, 0.24))
	if ghost > ratio:
		d.draw_rect(Rect2(rect.position, Vector2(roundf(rect.size.x * ghost), rect.size.y)), Color(1.0, 0.95, 0.85, 0.7))
	d.draw_rect(Rect2(rect.position, Vector2(roundf(rect.size.x * clampf(ratio, 0, 1)), rect.size.y)), color)


## Velinha de vida (um mini Pavio, 7x7 + chama): cheia, parcial ou vazia.
## A cera "derrete" de cima para baixo; apagada, fecha os olhos.
func _life_candle(pos: Vector2, fill: float, t: float) -> void:
	var d := _draw_node
	d.draw_rect(Rect2(pos + Vector2(0, -1), Vector2(7, 8)), INK)
	var level_y := 6.0 * (1.0 - fill)
	for j in 6:
		var c := WAX_EMPTY
		if fill >= 0.999 or float(j) >= level_y:
			c = WAX
		d.draw_rect(Rect2(pos + Vector2(1, j), Vector2(5, 1)), c)
	if fill >= 0.999:
		d.draw_rect(Rect2(pos + Vector2(2, 0), Vector2(3, 1)), Color(1.0, 0.98, 0.93))
	if fill > 0.0:
		# pavio + chama (tremula; menor se a velinha está pela metade)
		d.draw_rect(Rect2(pos + Vector2(3, -2), Vector2(1, 1)), INK)
		var tall := fill >= 0.999
		var sway := 1.0 if sin(t * 9.0 + pos.x) > 0.6 else 0.0
		if tall:
			d.draw_rect(Rect2(pos + Vector2(2, -4), Vector2(3, 2)), Color(1.0, 0.55, 0.15))
			d.draw_rect(Rect2(pos + Vector2(3, -4), Vector2(1, 2)), Color(1.0, 0.9, 0.45))
			d.draw_rect(Rect2(pos + Vector2(3 + sway, -5), Vector2(1, 1)), Color(1.0, 0.55, 0.15))
		else:
			d.draw_rect(Rect2(pos + Vector2(3, -3), Vector2(1, 1)), Color(1.0, 0.7, 0.25))
		d.draw_rect(Rect2(pos + Vector2(2, 2), Vector2(1, 2)), INK)
		d.draw_rect(Rect2(pos + Vector2(4, 2), Vector2(1, 2)), INK)
	else:
		d.draw_rect(Rect2(pos + Vector2(3, -2), Vector2(1, 1)), Color(0.45, 0.42, 0.5))
		d.draw_rect(Rect2(pos + Vector2(2, 3), Vector2(1, 1)), INK)
		d.draw_rect(Rect2(pos + Vector2(4, 3), Vector2(1, 1)), INK)


func _draw_hud() -> void:
	var d := _draw_node
	if player == null or not is_instance_valid(player):
		return
	# orbe de foco (alma) — enche de baixo para cima
	var fr: float = player.focus / maxf(player.max_focus(), 1.0)
	var oc := Vector2(12, 12)
	d.draw_circle(oc, 9.0, INK)
	d.draw_circle(oc, 8.0, Color(0.16, 0.14, 0.24))
	var fill_h := int(roundf(16.0 * fr))
	for y in range(16 - fill_h, 16):
		var yy := float(y) - 8.0 + 0.5
		var half := sqrt(maxf(64.0 - yy * yy, 0.0))
		d.draw_rect(Rect2(oc.x - half, oc.y - 8 + y, half * 2.0, 1), Color(0.85, 0.9, 1.0) if fr >= Player.HEAL_COST / player.max_focus() else Color(0.55, 0.62, 0.85))
	if fr > 0.02:
		d.draw_rect(Rect2(oc.x - 3, oc.y - 8 + 16 - fill_h, 2, 1), Color(1.6, 1.7, 2.0))
	# velinhas de vida
	var candles := int(ceil(player.max_hp() / HP_PER_CANDLE))
	var now := Time.get_ticks_msec() / 1000.0
	for i in candles:
		var v: float = clampf((player.hp - i * HP_PER_CANDLE) / HP_PER_CANDLE, 0.0, 1.0)
		_life_candle(Vector2(24 + i * 9, 6), v, now)
	# dashes (losangos) e pulo duplo
	var md: int = player.max_dashes()
	for i in md:
		var c := Color(0.88, 0.28, 0.3) if i < player.dashes else Color(0.3, 0.27, 0.36)
		var x := 25.0 + i * 6.0
		d.draw_rect(Rect2(x, 15, 3, 1), INK)
		d.draw_rect(Rect2(x - 1, 16, 5, 1), INK)
		d.draw_rect(Rect2(x, 17, 3, 1), INK)
		d.draw_rect(Rect2(x + 1, 16, 1, 1), c)
		d.draw_rect(Rect2(x, 16, 1, 1), c)
		d.draw_rect(Rect2(x + 2, 16, 1, 1), c)
	# dash extra (cristal duplo) e pulo extra (pena/sino)
	var ex := 25.0 + md * 6.0
	for i in maxi(player.dashes - md, 0):
		d.draw_rect(Rect2(ex - 1, 15, 5, 3), INK)
		d.draw_rect(Rect2(ex, 16, 3, 1), Color(1.0, 0.45, 0.85))
		ex += 6.0
	if player.bonus_jumps > 0:
		d.draw_rect(Rect2(ex - 1, 14, 5, 5), INK)
		d.draw_rect(Rect2(ex, 15, 3, 3), Color(0.5, 1.0, 0.5))
	# status ativos
	var sx := 24.0
	for id in player.status.active.keys():
		var sc: Color = StatusController.DEFS[id]["color"]
		d.draw_rect(Rect2(sx - 1, 21, 5, 5), INK)
		d.draw_rect(Rect2(sx, 22, 3, 3), sc)
		sx += 6.0
	if player.ward_charges > 0:
		_text(Vector2(sx + 2, 26), "Égide x%d" % player.ward_charges, 8, Color(1.0, 0.9, 0.6))
	# poções: número pequeno junto do orbe
	var potions := int(Game.profile.get("items", {}).get("pocao_vida", 0))
	if potions > 0:
		d.draw_rect(Rect2(3, 22, 3, 4), INK)
		d.draw_rect(Rect2(4, 23, 1, 2), Color(0.95, 0.35, 0.5))
		_text(Vector2(8, 27), "%d" % potions, 8, Color(1.0, 0.7, 0.8))
	# canto superior direito: brasas e, embaixo, as magias (nada cobre o chão)
	var cur := str(int(Game.profile.get("currency", 0)))
	var cw := SMALL.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	d.draw_rect(Rect2(308 - cw - 8, 5, 5, 5), INK)
	d.draw_rect(Rect2(308 - cw - 7, 6, 3, 3), Color(1.9, 1.3, 0.35))
	_text(Vector2(310 - cw, 10), cur, 8, Color(1.0, 0.85, 0.5))
	var slots: Array = Game.profile.get("spell_slots", [])
	var keys := [Settings.binding_label("spell_1"), Settings.binding_label("spell_2")]
	for i in slots.size():
		var sid: String = slots[i]
		var x := 314.0 - (slots.size() - i) * 19.0
		var y := 14.0
		d.draw_rect(Rect2(x - 1, y - 1, 18, 18), INK)
		d.draw_rect(Rect2(x, y, 16, 16), Color(0.16, 0.14, 0.24))
		var ic := DB.icon(sid)
		if ic:
			d.draw_texture(ic, Vector2(x, y))
		var cd: float = player.caster.cooldown_left(sid)
		var total: float = float(DB.spell(sid).get("cooldown", 1.0))
		if cd > 0.0:
			var k := cd / maxf(total, 0.01)
			d.draw_rect(Rect2(x, y + roundf(16 * (1.0 - k)), 16, roundf(16 * k)), Color(0, 0, 0, 0.6))
		var lvl := Inventory.spell_level(Game.profile, sid)
		if player.focus < player.caster.cost_of(sid, lvl):
			d.draw_rect(Rect2(x, y, 16, 16), Color(0.1, 0.1, 0.35, 0.5))
		_text(Vector2(x + 1, y + 23), keys[i] if i < keys.size() else "", 8, Color(1.0, 0.85, 0.5))
	# nome da arma: aparece só por alguns segundos ao trocar/entrar
	if _weapon_t > 0.0:
		var wn := DB.display_name(player.weapon_id)
		var ww := SMALL.get_string_size(wn, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(Vector2(314 - ww, 46), wn, 8, Color(0.9, 0.88, 0.95, minf(_weapon_t, 1.0)))
	# combo
	if _combo >= 3:
		var col := Color(1.0, 0.85, 0.35) if _combo >= 10 else Color(0.96, 0.94, 0.9)
		_text(Vector2(24, 36 - roundf(_combo_pop * 2.0)), "x%d" % _combo, 8, col)
		if player.rhythm_stacks > 0:
			_text(Vector2(40, 36), "♪%d" % player.rhythm_stacks, 8, Color(0.8, 0.6, 1.0))
	# cadeia aérea (orbe, pogo, abate, rebate, sino... sem tocar o chão)
	if _chain >= 2:
		var ctext := "CADEIA x%d" % _chain
		var cwid := SMALL.get_string_size(ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var cyy := 40.0 if (boss and is_instance_valid(boss) and not boss.dead) else 24.0
		var hot := clampf((_chain - 2) / 8.0, 0.0, 1.0)
		var ccol := Color(0.9, 0.95, 1.0).lerp(Color(1.0, 0.8, 0.3), hot)
		_text(Vector2(160 - cwid * 0.5, cyy - roundf(_chain_pop * 3.0)), ctext, 8, ccol)
	# chefe: nome e barra no topo central
	if boss and is_instance_valid(boss) and not boss.dead:
		var br: float = boss.hp / maxf(boss.max_hp(), 1.0)
		var bn: String = boss.data.get("name", "Chefe")
		var bw := SMALL.get_string_size(bn, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(Vector2(160 - roundf(bw * 0.5), 10), bn, 8, Color(1.0, 0.7, 0.55))
		_bar(Rect2(100, 13, 120, 2), br, Color(0.9, 0.3, 0.25))
	# cronômetro (opcional, para speedrun)
	if Settings.gameplay("speedrun_timer") and level:
		var ts := Level.format_time(float(level.result.get("time", 0.0)))
		var tw := SMALL.get_string_size(ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(Vector2(160 - roundf(tw * 0.5), 26 if boss else 10), ts, 8, Color(0.95, 0.95, 1.0))
		var dth := int(level.result.get("deaths", 0))
		if dth > 0:
			_text(Vector2(160 + roundf(tw * 0.5) + 4, 26 if boss else 10), "†%d" % dth, 8, Color(1.0, 0.6, 0.6))
	# título da região
	if _region_title_t > 0.0 and _region_title != "":
		var a := minf(_region_title_t, 1.0) * minf((3.5 - _region_title_t) * 2.0, 1.0)
		var w := SMALL.get_string_size(_region_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var pos := Vector2(roundf(160 - w * 0.5), 62)
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(0, 2)]:
			d.draw_string(SMALL, pos + o, _region_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(INK.r, INK.g, INK.b, a))
		d.draw_string(SMALL, pos, _region_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.93, 0.8, a))
	# sobreposição do sigilo
	if player.state == Player.State.SIGIL:
		d.draw_rect(Rect2(0, 0, 320, 180), Color(0.05, 0.0, 0.12, 0.3))
		var guides := []
		for sid in Game.profile.get("sigils", {}).keys():
			guides.append(DB.spell(sid).get("sigil", ""))
		for i in guides.size():
			var gp := SigilRecognizer.guide_points(guides[i])
			var origin := Vector2(20 + i * 30, 40)
			var pts := PackedVector2Array()
			for p in gp:
				pts.append(origin + p * 9.0)
			if pts.size() > 1:
				d.draw_polyline(pts, Color(1.4, 1.2, 2.4, 0.6), 1.0)
		_text(Vector2(10, 28), "Desenhe um sigilo e solte", 8, Color(0.96, 0.94, 0.9))
		var sp: PackedVector2Array = player.sigil_points
		if sp.size() > 1:
			d.draw_polyline(sp, Color(1.0, 0.6, 2.6, 0.5), 3.0)
			d.draw_polyline(sp, Color(2.6, 2.2, 3.6), 1.0)


# ---------------------------------------------------------------------------
# Painéis (pausam o jogo)
# ---------------------------------------------------------------------------

func _open_panel(p: Control) -> void:
	close_panel()
	# fundo escurecido + painel centralizado: legível sobre o mapa/fase
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dim)
	holder.add_child(UIKit.centered(p))
	_panel = holder
	_root.add_child(_panel)
	get_tree().paused = true
	UIKit.focus_first(p)


func close_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _panel and event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()


## Painel de leitura (tábuas de pedra, inscrições).
func open_text(title_text: String, body: String) -> void:
	var p := UIKit.panel(Vector2(300, 0))
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(UIKit.label(title_text, 14, UIKit.GOLD))
	var l := UIKit.label(body, 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(280, 0)
	v.add_child(l)
	v.add_child(UIKit.button("Fechar", close_panel, 80))
	_open_panel(p)


func open_dialogue(npc_id: String) -> void:
	var npc: Dictionary = Game.social.get("npcs", {}).get(npc_id, {})
	if npc.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var line := SocialSystem.talk(Game.social, npc_id, DB, rng, Game.world)
	var p := UIKit.panel(Vector2(320, 0))
	var v := UIKit.vbox(4)
	p.add_child(v)
	var head := UIKit.hbox(6)
	head.add_child(UIKit.label("%s — %s" % [npc["name"], npc["title"]], 14, UIKit.GOLD))
	v.add_child(head)
	var stage := SocialSystem.stage_name(int(npc["affinity"]), DB)
	var hearts := SocialSystem.hearts(int(npc["affinity"]))
	var info := "%s   %s%s   (%s, %s)" % [stage, "♥".repeat(hearts), "·".repeat(10 - hearts), npc["personality"], npc["culture"]]
	if npc.get("married", false):
		info += "   ♦ Cônjuge"
	v.add_child(UIKit.label(info, 10, UIKit.DIM))
	var said := UIKit.label("“%s”" % line, 12)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD
	said.custom_minimum_size = Vector2(300, 0)
	v.add_child(said)
	var rep := SocialSystem.reputation(Game.social, npc["region"])
	v.add_child(UIKit.label("Sua reputação aqui: %d (%s)" % [rep, SocialSystem.reputation_band(rep, DB)], 10, UIKit.DIM))
	# serviços do morador (loja, forja, estudo...)
	var srow := UIKit.hbox(4)
	for sv in npc.get("services", []):
		var b := _service_button(str(sv), npc_id)
		if b:
			srow.add_child(b)
	if srow.get_child_count() > 0:
		v.add_child(srow)
	var row := UIKit.hbox(4)
	row.add_child(UIKit.button("Presentear", func(): _gift_menu(npc_id), 70))
	row.add_child(UIKit.button("Missões", func(): open_quests(npc["region"], npc_id), 60))
	if npc.get("romanceable", false) and not npc.get("married", false):
		row.add_child(UIKit.button("Pedir em casamento", func():
			var why := SocialSystem.marriage_block_reason(Game.social, npc_id, Game.profile)
			if why == "":
				SocialSystem.marry(Game.social, npc_id, Game.profile)
				toast("Você e %s se casaram! ♥" % npc["name"])
				Game.save()
				close_panel()
			else:
				toast(why), 110))
	row.add_child(UIKit.button("Sair", close_panel, 40))
	v.add_child(row)
	_open_panel(p)


# ---------------------------------------------------------------------------
# Serviços das vilas (loja, forja, estudo, receptador, bardo, histórias)
# ---------------------------------------------------------------------------

func _service_button(sv: String, npc_id: String) -> Button:
	match sv:
		"shop": return UIKit.button("Loja", func(): open_shop(npc_id, false), 50)
		"shop_potions": return UIKit.button("Poções", func(): open_shop(npc_id, true), 55)
		"upgrade_weapon": return UIKit.button("Forja", func(): open_forge(npc_id), 50)
		"upgrade_spell": return UIKit.button("Estudar", func(): open_study(npc_id), 55)
		"fence": return UIKit.button("Vender", func(): open_sell(npc_id), 55)
		"buff_song": return UIKit.button("Canção (%d)" % ShopSystem.SONG_COST, func():
			if ShopSystem.buy_song(Game.profile):
				Audio.play("clear", 0.0, -4.0)
				toast("O bardo canta a Canção da Coragem: +15% de dano na próxima fase!")
				Game.save()
			else:
				toast("Faltam brasas (ou a canção já está com você)."), 80)
		"lore": return UIKit.button("Histórias", func():
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var body: String = Lore.TOWN_LORE[rng.randi() % Lore.TOWN_LORE.size()]
			open_text("Histórias de %s" % Lore.WORLD_NAME, body + "\n\n" + Lore.rumor(Game.world, rng)), 70)
	return null


func _brasas_label() -> Label:
	return UIKit.label("Suas brasas: %d" % int(Game.profile.get("currency", 0)), 11, UIKit.GOLD)


func _item_line(id: String, price: int, on_buy: Callable, verb: String = "Comprar") -> HBoxContainer:
	var row := UIKit.hbox(4)
	var data: Dictionary = DB.get_entry(id)
	var col: Color = DB.rarity_color(str(data.get("rarity", "common"))) if data.has("rarity") else UIKit.INK
	var name_l := UIKit.label(DB.display_name(id), 11, col)
	name_l.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_l)
	var price_l := UIKit.label("%d" % price, 11, UIKit.GOLD)
	price_l.custom_minimum_size = Vector2(36, 0)
	row.add_child(price_l)
	var b := UIKit.button(verb, on_buy, 60)
	b.disabled = verb == "Comprar" and int(Game.profile.get("currency", 0)) < price
	row.add_child(b)
	return row


func open_shop(npc_id: String, potions_only: bool) -> void:
	var npc: Dictionary = Game.social["npcs"][npc_id]
	var region: Dictionary = Game.world.get("regions", {}).get(npc["region"], {})
	var items: Array = ShopSystem.potion_stock(DB) if potions_only else ShopSystem.stock(str(npc["region"]), int(region.get("tier", 1)), int(Game.profile.get("runs", 0)), Game.seed_value, DB, Game.profile)
	var p := UIKit.panel(Vector2(300, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label(("Poções de %s" if potions_only else "Loja de %s") % npc["name"], 14, UIKit.GOLD))
	v.add_child(_brasas_label())
	for it in items:
		var id: String = it["id"]
		var cost: int = int(it["price"])
		if not potions_only and ShopSystem.owned(Game.profile, id, DB):
			continue
		v.add_child(_item_line(id, cost, func():
			var msg := ShopSystem.buy(Game.profile, id, cost)
			if msg == "":
				toast("Faltam brasas.")
				return
			Audio.play("coins", 0.1, -4.0)
			toast(msg)
			Game.save()
			open_shop(npc_id, potions_only)))
	if not potions_only:
		v.add_child(UIKit.label("O estoque muda a cada fase concluída.", 10, UIKit.DIM))
	v.add_child(UIKit.button("Voltar", func(): open_dialogue(npc_id), 80))
	_open_panel(p)


func open_forge(npc_id: String) -> void:
	var p := UIKit.panel(Vector2(300, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label("Forja", 14, UIKit.GOLD))
	v.add_child(_brasas_label())
	var frags := int(Game.profile.get("items", {}).get("fragmento_runico", 0))
	v.add_child(UIKit.label("Fragmentos Rúnicos: %d  (a partir do nível 3)" % frags, 10, UIKit.DIM))
	for wid in [str(Game.profile.get("weapon", "")), str(Game.profile.get("weapon_alt", ""))]:
		if wid == "":
			continue
		var lvl := ShopSystem.weapon_level(Game.profile, wid)
		var why := ShopSystem.weapon_block(Game.profile, wid)
		var row := UIKit.hbox(4)
		var l := UIKit.label("%s +%d  (dano x%.1f)" % [DB.display_name(wid), lvl, ShopSystem.weapon_mult(Game.profile, wid)], 11)
		l.custom_minimum_size = Vector2(170, 0)
		row.add_child(l)
		var cost_txt := "%d" % int(ShopSystem.WEAPON_COST[lvl]) if lvl < ShopSystem.MAX_WEAPON_LEVEL else "máx."
		var b := UIKit.button("Forjar (%s)" % cost_txt, func():
			if ShopSystem.upgrade_weapon(Game.profile, wid):
				Audio.play("hit_metal", 0.05, -2.0)
				FX.shake(0.1)
				toast("%s agora é +%d!" % [DB.display_name(wid), ShopSystem.weapon_level(Game.profile, wid)])
				Game.save()
			else:
				toast(ShopSystem.weapon_block(Game.profile, wid))
			open_forge(npc_id), 90)
		b.disabled = why != ""
		row.add_child(b)
		v.add_child(row)
	var shown := 0
	for piece in Inventory.equipped_pieces(Game.profile):
		if shown >= 4:
			break
		shown += 1
		var uid := int(piece["uid"])
		var alvl := int(piece.get("level", 0))
		var arow := UIKit.hbox(4)
		var al := UIKit.label("%s +%d" % [DB.display_name(str(piece["id"])), alvl], 11)
		al.custom_minimum_size = Vector2(170, 0)
		arow.add_child(al)
		var acost := "%d" % int(ShopSystem.ARMOR_COST[alvl]) if alvl < Inventory.MAX_ARMOR_LEVEL else "máx."
		var ab := UIKit.button("Reforçar (%s)" % acost, func():
			if ShopSystem.upgrade_armor(Game.profile, uid):
				Audio.play("hit_metal", 0.05, -4.0, 0.8)
				toast("Armadura reforçada!")
				Game.save()
			else:
				toast(ShopSystem.armor_block(Game.profile, uid))
			open_forge(npc_id), 90)
		ab.disabled = ShopSystem.armor_block(Game.profile, uid) != ""
		arow.add_child(ab)
		v.add_child(arow)
	v.add_child(UIKit.button("Voltar", func(): open_dialogue(npc_id), 80))
	_open_panel(p)


func open_study(npc_id: String) -> void:
	var p := UIKit.panel(Vector2(300, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label("Estudar magias", 14, UIKit.GOLD))
	v.add_child(_brasas_label())
	var ids: Array = Game.profile.get("spells", {}).keys() + Game.profile.get("sigils", {}).keys()
	for sid in ids:
		var spell_id: String = sid
		var lvl := Inventory.spell_level(Game.profile, spell_id)
		var row := UIKit.hbox(4)
		var l := UIKit.label("%s  nv. %d" % [DB.display_name(spell_id), lvl + 1], 11)
		l.custom_minimum_size = Vector2(170, 0)
		row.add_child(l)
		var cost_txt := "%d" % int(ShopSystem.SPELL_COST[lvl]) if lvl < Inventory.MAX_SPELL_LEVEL else "máx."
		var b := UIKit.button("Estudar (%s)" % cost_txt, func():
			if ShopSystem.upgrade_spell(Game.profile, spell_id):
				Audio.play("spell_arcane", 0.05, -4.0)
				toast("%s subiu de nível!" % DB.display_name(spell_id))
				Game.save()
			else:
				toast(ShopSystem.spell_block(Game.profile, spell_id))
			open_study(npc_id), 90)
		b.disabled = ShopSystem.spell_block(Game.profile, spell_id) != ""
		row.add_child(b)
		v.add_child(row)
	v.add_child(UIKit.button("Voltar", func(): open_dialogue(npc_id), 80))
	_open_panel(p)


func open_sell(npc_id: String) -> void:
	var p := UIKit.panel(Vector2(300, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label("Vender ao Receptador", 14, UIKit.GOLD))
	v.add_child(_brasas_label())
	var any := false
	for w in ShopSystem.sellable_weapons(Game.profile):
		any = true
		var wid: String = w
		v.add_child(_item_line(wid, ShopSystem.sell_price(wid, DB), func():
			var got := ShopSystem.sell_weapon(Game.profile, wid, DB)
			if got > 0:
				Audio.play("coins", 0.1, -4.0)
				toast("+%d brasas" % got)
				Game.save()
			open_sell(npc_id), "Vender"))
	for piece in ShopSystem.sellable_armor(Game.profile):
		any = true
		var uid := int(piece["uid"])
		v.add_child(_item_line(str(piece["id"]), ShopSystem.sell_price(str(piece["id"]), DB) + 10 * int(piece.get("level", 0)), func():
			var got := ShopSystem.sell_armor(Game.profile, uid, DB)
			if got > 0:
				Audio.play("coins", 0.1, -4.0)
				toast("+%d brasas" % got)
				Game.save()
			open_sell(npc_id), "Vender"))
	if not any:
		v.add_child(UIKit.label("Nada sobrando para vender (a arma equipada e a reserva ficam com você).", 10, UIKit.DIM))
	v.add_child(UIKit.button("Voltar", func(): open_dialogue(npc_id), 80))
	_open_panel(p)


func _gift_menu(npc_id: String) -> void:
	var npc: Dictionary = Game.social["npcs"][npc_id]
	var p := UIKit.panel(Vector2(240, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label("Presentear %s" % npc["name"], 14, UIKit.GOLD))
	var any := false
	for it in Game.profile.get("items", {}).keys():
		if DB.items.get(it, {}).get("kind", "") != "gift":
			continue
		any = true
		var item_id: String = it
		v.add_child(UIKit.button("%s x%d" % [DB.display_name(item_id), int(Game.profile["items"][item_id])], func():
			var delta := SocialSystem.give_gift(Game.social, npc_id, item_id)
			if delta == 0:
				toast("Já presenteou hoje.")
			else:
				Inventory.use_item(Game.profile, item_id)
				toast("%s: %s" % [npc["name"], "adorou!" if delta >= 10 else ("não gostou..." if delta < 0 else "agradeceu.")])
			open_dialogue(npc_id), 200))
	if not any:
		v.add_child(UIKit.label("Você não tem presentes. Procure comida, velas, cálices...", 10, UIKit.DIM))
	v.add_child(UIKit.button("Voltar", func(): open_dialogue(npc_id), 80))
	_open_panel(p)


func open_quests(region_id: String, only_npc: String = "") -> void:
	var p := UIKit.panel(Vector2(340, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	var rep := SocialSystem.reputation(Game.social, region_id)
	v.add_child(UIKit.label("Missões — reputação %d (%s)" % [rep, SocialSystem.reputation_band(rep, DB)], 14, UIKit.GOLD))
	var offers: Array = []
	for npc in Game.social.get("npcs", {}).values():
		if npc["region"] != region_id or not npc["alive"]:
			continue
		if only_npc != "" and npc["id"] != only_npc:
			continue
		offers.append_array(SocialSystem.quest_offers(Game.social, Game.world, npc["id"], DB, Game.seed_value))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(330, 150)
	var list := UIKit.vbox(4)
	sc.add_child(list)
	v.add_child(sc)
	if offers.is_empty():
		list.add_child(UIKit.label("Ninguém aqui tem trabalho para alguém com a sua fama.", 11, UIKit.DIM))
	for q in offers.slice(0, 8):
		var quest: Dictionary = q
		var box := UIKit.vbox(1)
		box.add_child(UIKit.label("%s  (+%d brasas, rep %+d)" % [quest["title"], quest["reward"], quest["rep"]], 12, Color(1.0, 0.8, 0.5) if quest["rep"] < 0 else Color(0.7, 0.9, 1.0)))
		var t := UIKit.label(quest["text"], 10, UIKit.INK)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD
		t.custom_minimum_size = Vector2(310, 0)
		box.add_child(t)
		box.add_child(UIKit.button("Aceitar", func():
			SocialSystem.accept_quest(Game.social, quest)
			toast("Missão aceita: " + quest["title"]), 70))
		list.add_child(box)
	var active: Array = Game.social.get("quests", {}).get("active", [])
	if not active.is_empty():
		v.add_child(UIKit.label("Ativas: " + ", ".join(active.map(func(a): return a["title"])), 10, UIKit.DIM))
	v.add_child(UIKit.button("Fechar", close_panel, 80))
	_open_panel(p)


func show_summary(result: Dictionary, quests_done: Array) -> void:
	var p := UIKit.panel(Vector2(280, 0))
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.title("Região concluída", 22))
	var rank: String = result.get("rank", "B")
	var rank_col: Color = {"S": Color(1.0, 0.85, 0.3), "A": Color(0.6, 0.9, 1.0), "B": Color(0.8, 0.8, 0.9), "C": Color(0.8, 0.6, 0.6)}.get(rank, UIKit.INK)
	v.add_child(UIKit.label("Nota  %s" % rank, 20, rank_col, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Tempo %s   Mortes %d   Golpes sofridos %d" % [Level.format_time(float(result.get("time", 0.0))), int(result.get("deaths", 0)), int(result.get("hits", 0))], 12, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if int(result.get("best_chain", 0)) >= 3:
		v.add_child(UIKit.label("Maior cadeia aérea  x%d" % int(result.get("best_chain", 0)), 12, Color(0.75, 0.55, 0.1), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Inimigos derrotados: %d" % int(result.get("kills", 0))))
	if result.get("boss_killed", false):
		v.add_child(UIKit.label("Chefe derrotado!", 12, Color(1.4, 0.8, 0.5)))
	for q in quests_done:
		if not q.is_empty():
			v.add_child(UIKit.label("Missão cumprida: %s (+%d)" % [q["title"], q["reward"]], 11, UIKit.GOLD))
	var region: Dictionary = level.region if level else {}
	var gained: Array = region.get("rewards", []).duplicate()
	if region.get("grants", "") != "":
		gained.append(region["grants"])
	for g in gained:
		v.add_child(UIKit.label("Habilidade: " + str(DB.abilities.get(g, {}).get("name", g)), 12, Color(0.8, 1.6, 2.0)))
	v.add_child(UIKit.label("Esta região agora é ponto de viagem rápida.", 10, UIKit.DIM))
	v.add_child(UIKit.button("Continuar", func():
		close_panel()
		level.leave_level(), 120))
	_open_panel(p)
