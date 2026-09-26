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
var _hp_ghost: float = 1.0
var _panel: Control = null
var _region_title_t: float = 0.0
var _region_title: String = ""


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
	_toasts.position = Vector2(140, 44)
	_toasts.size = Vector2(200, 100)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	Events.toast.connect(toast)
	Events.combo_changed.connect(func(c):
		if c > _combo:
			_combo_pop = 1.0
		_combo = c)
	Events.dialogue_requested.connect(open_dialogue)
	Events.player_spawned.connect(func(p): player = p)
	if level:
		player = level.player
		_region_title = level.region.get("name", "")
		_region_title_t = 3.5


func _process(delta: float) -> void:
	if player == null and level:
		player = level.player
	_combo_pop = maxf(_combo_pop - delta * 4.0, 0.0)
	_region_title_t = maxf(_region_title_t - delta, 0.0)
	if player:
		var ratio: float = player.hp / maxf(player.max_hp(), 1.0)
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 0.5) if _hp_ghost > ratio else ratio
	_draw_node.queue_redraw()


func toast(text: String) -> void:
	if text == "":
		return
	var l := UIKit.label(text, 12, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(200, 0)
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
const MASK := Color(0.96, 0.94, 0.9)
const MASK_EMPTY := Color(0.3, 0.27, 0.36)
const HP_PER_MASK := 20.0


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


## Máscara de vida (7x8): cheia, parcial ou vazia.
func _mask(pos: Vector2, fill: float) -> void:
	var d := _draw_node
	var rows := [[1, 5], [0, 7], [0, 7], [0, 7], [1, 5], [2, 3]]
	for j in rows.size():
		d.draw_rect(Rect2(pos + Vector2(rows[j][0] - 1, j), Vector2(rows[j][1] + 2, 1)), INK)
	d.draw_rect(Rect2(pos + Vector2(0, -1), Vector2(7, 1)), INK)
	d.draw_rect(Rect2(pos + Vector2(2, 6), Vector2(3, 1)), INK)
	for j in rows.size():
		var c := MASK_EMPTY
		var level_y := 6.0 * (1.0 - fill)
		if fill >= 0.999 or float(j) >= level_y:
			c = MASK
		d.draw_rect(Rect2(pos + Vector2(rows[j][0], j), Vector2(rows[j][1], 1)), c)
	# olhinhos
	d.draw_rect(Rect2(pos + Vector2(2, 2), Vector2(1, 2)), INK)
	d.draw_rect(Rect2(pos + Vector2(4, 2), Vector2(1, 2)), INK)


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
	# máscaras de vida
	var masks := int(ceil(player.max_hp() / HP_PER_MASK))
	for i in masks:
		var v: float = clampf((player.hp - i * HP_PER_MASK) / HP_PER_MASK, 0.0, 1.0)
		_mask(Vector2(24 + i * 9, 5), v)
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
	# status ativos
	var sx := 24.0
	for id in player.status.active.keys():
		var sc: Color = StatusController.DEFS[id]["color"]
		d.draw_rect(Rect2(sx - 1, 21, 5, 5), INK)
		d.draw_rect(Rect2(sx, 22, 3, 3), sc)
		sx += 6.0
	if player.ward_charges > 0:
		_text(Vector2(sx + 2, 26), "Égide x%d" % player.ward_charges, 8, Color(1.0, 0.9, 0.6))
	# brasas (canto superior direito)
	var cur := str(int(Game.profile.get("currency", 0)))
	var cw := SMALL.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	d.draw_rect(Rect2(308 - cw - 8, 6, 5, 5), INK)
	d.draw_rect(Rect2(308 - cw - 7, 7, 3, 3), Color(1.9, 1.3, 0.35))
	_text(Vector2(310 - cw, 11), cur, 8, Color(1.0, 0.85, 0.5))
	# arma e magias (canto inferior esquerdo)
	var slots: Array = Game.profile.get("spell_slots", [])
	var keys := [Settings.binding_label("spell_1"), Settings.binding_label("spell_2")]
	for i in slots.size():
		var sid: String = slots[i]
		var x := 6.0 + i * 20.0
		d.draw_rect(Rect2(x - 1, 157, 18, 18), INK)
		d.draw_rect(Rect2(x, 158, 16, 16), Color(0.16, 0.14, 0.24))
		var ic := DB.icon(sid)
		if ic:
			d.draw_texture(ic, Vector2(x, 158))
		var cd: float = player.caster.cooldown_left(sid)
		var total: float = float(DB.spell(sid).get("cooldown", 1.0))
		if cd > 0.0:
			var k := cd / maxf(total, 0.01)
			d.draw_rect(Rect2(x, 158 + roundf(16 * (1.0 - k)), 16, roundf(16 * k)), Color(0, 0, 0, 0.6))
		var lvl := Inventory.spell_level(Game.profile, sid)
		if player.focus < player.caster.cost_of(sid, lvl):
			d.draw_rect(Rect2(x, 158, 16, 16), Color(0.1, 0.1, 0.35, 0.5))
		_text(Vector2(x + 11, 156), keys[i] if i < keys.size() else "", 8, Color(1.0, 0.85, 0.5))
	var info_x := 8.0 + slots.size() * 20.0
	_text(Vector2(info_x, 166), DB.display_name(player.weapon_id), 8, Color(0.85, 0.82, 0.9))
	var potions := int(Game.profile.get("items", {}).get("pocao_vida", 0))
	if potions > 0:
		_text(Vector2(info_x, 175), "%s poção x%d" % [Settings.binding_label("heal"), potions], 8, Color(1.0, 0.6, 0.7))
	# combo
	if _combo >= 3:
		var col := Color(1.0, 0.85, 0.35) if _combo >= 10 else Color(0.96, 0.94, 0.9)
		_text(Vector2(292, 30 - roundf(_combo_pop * 2.0)), "x%d" % _combo, 8, col)
		if player.rhythm_stacks > 0:
			_text(Vector2(292, 40), "♪%d" % player.rhythm_stacks, 8, Color(0.8, 0.6, 1.0))
	# chefe
	if boss and is_instance_valid(boss) and not boss.dead:
		var br: float = boss.hp / maxf(boss.max_hp(), 1.0)
		var bn: String = boss.data.get("name", "Chefe")
		var bw := SMALL.get_string_size(bn, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(Vector2(160 - roundf(bw * 0.5), 164), bn, 8, Color(1.0, 0.7, 0.55))
		_bar(Rect2(90, 168, 140, 3), br, Color(0.9, 0.3, 0.25))
	# título da região
	if _region_title_t > 0.0 and _region_title != "":
		var a := minf(_region_title_t, 1.0) * minf((3.5 - _region_title_t) * 2.0, 1.0)
		var w := SMALL.get_string_size(_region_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var pos := Vector2(roundf(160 - w * 0.5), 44)
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
	if _panel and event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()


func open_dialogue(npc_id: String) -> void:
	var npc: Dictionary = Game.social.get("npcs", {}).get(npc_id, {})
	if npc.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var line := SocialSystem.talk(Game.social, npc_id, DB, rng)
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
