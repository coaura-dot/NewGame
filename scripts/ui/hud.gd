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
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_draw_hud)
	_root.add_child(_draw_node)
	_toasts = UIKit.vbox(2)
	_toasts.position = Vector2(140, 34)
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
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	if _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()


func show_boss(b: Node) -> void:
	boss = b


func hide_boss() -> void:
	boss = null


# ---------------------------------------------------------------------------
# Desenho da HUD
# ---------------------------------------------------------------------------

func _text(pos: Vector2, s: String, size: int, color: Color, outline: bool = true) -> void:
	if outline:
		_draw_node.draw_string_outline(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.04, 0.02, 0.07, color.a))
	_draw_node.draw_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _bar(rect: Rect2, ratio: float, color: Color, ghost: float = -1.0) -> void:
	var d := _draw_node
	d.draw_rect(rect.grow(1), Color(0.02, 0.01, 0.04, 0.9))
	d.draw_rect(rect, Color(0.12, 0.1, 0.16))
	if ghost > ratio:
		d.draw_rect(Rect2(rect.position, Vector2(rect.size.x * ghost, rect.size.y)), Color(1.0, 0.9, 0.8, 0.6))
	d.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), rect.size.y)), color)
	d.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), 1)), Color(color.r * 1.4, color.g * 1.4, color.b * 1.4))


func _draw_hud() -> void:
	var d := _draw_node
	if player == null or not is_instance_valid(player):
		return
	# vida / foco
	var ratio: float = player.hp / maxf(player.max_hp(), 1.0)
	var hp_col := Color(0.85, 0.18, 0.25) if ratio > 0.3 else Color(1.6 + 0.6 * sin(Time.get_ticks_msec() / 120.0), 0.2, 0.3)
	_bar(Rect2(10, 10, 110, 7), ratio, hp_col, _hp_ghost)
	_text(Vector2(124, 17), "%d/%d" % [int(player.hp), int(player.max_hp())], 10, UIKit.INK)
	_bar(Rect2(10, 20, 80, 4), player.focus / maxf(player.max_focus(), 1.0), Color(0.35, 0.6, 1.4))
	# dashes
	var md: int = player.max_dashes()
	for i in md:
		var c := Color(0.5, 2.0, 2.2) if i < player.dashes else Color(0.2, 0.25, 0.3)
		var x := 12.0 + i * 9.0
		d.draw_colored_polygon(PackedVector2Array([Vector2(x, 28), Vector2(x + 3, 31), Vector2(x, 34), Vector2(x - 3, 31)]), c)
	if player.max_air_jumps() > 0:
		var aj := Color(1.6, 1.4, 2.4) if player.air_jumps > 0 else Color(0.25, 0.22, 0.3)
		d.draw_circle(Vector2(12.0 + md * 9.0 + 4.0, 31), 2.5, aj)
	# status ativos
	var sx := 10.0
	for id in player.status.active.keys():
		var sc: Color = StatusController.DEFS[id]["color"]
		d.draw_rect(Rect2(sx, 38, 6, 6), sc)
		sx += 8.0
	if player.ward_charges > 0:
		_text(Vector2(sx + 2, 44), "Égide x%d" % player.ward_charges, 9, Color(2.0, 1.8, 1.0))
	# brasas
	var cur := int(Game.profile.get("currency", 0))
	d.draw_circle(Vector2(452, 13), 3.0, Color(2.4, 1.4, 0.4))
	_text(Vector2(458, 17), str(cur), 12, Color(1.0, 0.8, 0.45))
	# arma + magias (canto inferior esquerdo)
	var wid: String = player.weapon_id
	var wicon := DB.icon(wid)
	d.draw_rect(Rect2(8, 244, 20, 20), Color(0.05, 0.04, 0.08, 0.85))
	if wicon:
		d.draw_texture(wicon, Vector2(10, 246))
	_text(Vector2(8, 240), DB.display_name(wid), 10, UIKit.DIM)
	var slots: Array = Game.profile.get("spell_slots", [])
	var keys := [Settings.binding_label("spell_1"), Settings.binding_label("spell_2")]
	for i in slots.size():
		var sid: String = slots[i]
		var x := 34.0 + i * 24.0
		d.draw_rect(Rect2(x, 244, 20, 20), Color(0.05, 0.04, 0.08, 0.85))
		var ic := DB.icon(sid)
		if ic:
			d.draw_texture(ic, Vector2(x + 2, 246))
		var cd: float = player.caster.cooldown_left(sid)
		var total: float = float(DB.spell(sid).get("cooldown", 1.0))
		if cd > 0.0:
			d.draw_rect(Rect2(x, 244 + 20 * (1.0 - cd / maxf(total, 0.01)), 20, 20 * cd / maxf(total, 0.01)), Color(0, 0, 0, 0.6))
		var level_ := Inventory.spell_level(Game.profile, sid)
		var cost: float = player.caster.cost_of(sid, level_)
		if player.focus < cost:
			d.draw_rect(Rect2(x, 244, 20, 20), Color(0.1, 0.1, 0.4, 0.45))
		_text(Vector2(x + 13, 262), keys[i] if i < keys.size() else "", 9, UIKit.GOLD)
	if not Game.profile.get("sigils", {}).is_empty():
		_text(Vector2(84, 262), "[%s] Sigilo" % Settings.binding_label("sigil"), 9, UIKit.DIM)
	var potions := int(Game.profile.get("items", {}).get("pocao_vida", 0))
	if potions > 0:
		_text(Vector2(84, 252), "[%s] Poção x%d" % [Settings.binding_label("heal"), potions], 9, Color(1.4, 0.6, 0.7))
	# combo
	if _combo >= 2:
		var s := 18 + int(_combo_pop * 8.0)
		var col := Color(2.2, 1.6, 0.6) if _combo >= 10 else UIKit.GOLD
		_text(Vector2(400, 120), str(_combo), s, col)
		_text(Vector2(402, 132), "COMBO", 10, UIKit.DIM)
		if player.rhythm_stacks > 0:
			_text(Vector2(402, 142), "♪ x%d" % player.rhythm_stacks, 10, Color(2.0, 1.4, 2.6))
	# chefe
	if boss and is_instance_valid(boss) and not boss.dead:
		var br: float = boss.hp / maxf(boss.max_hp(), 1.0)
		_text(Vector2(140, 246), boss.data.get("name", "Chefe"), 12, Color(1.6, 0.7, 0.5))
		_bar(Rect2(140, 250, 200, 6), br, Color(1.4, 0.35, 0.2))
	# título da região
	if _region_title_t > 0.0 and _region_title != "":
		var a := minf(_region_title_t, 1.0) * minf((3.5 - _region_title_t) * 2.0, 1.0)
		var w := FONT.get_string_size(_region_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_text(Vector2(240 - w * 0.5, 80), _region_title, 20, Color(1.0, 0.85, 0.55, a))
	# sobreposição do sigilo
	if player.state == Player.State.SIGIL:
		d.draw_rect(Rect2(0, 0, 480, 270), Color(0.05, 0.0, 0.12, 0.35))
		var guides := []
		for sid in Game.profile.get("sigils", {}).keys():
			guides.append(DB.spell(sid).get("sigil", ""))
		for i in guides.size():
			var gp := SigilRecognizer.guide_points(guides[i])
			var origin := Vector2(30 + i * 44, 60)
			var pts := PackedVector2Array()
			for p in gp:
				pts.append(origin + p * 14.0)
			if pts.size() > 1:
				d.draw_polyline(pts, Color(1.4, 1.2, 2.4, 0.6), 1.0)
		_text(Vector2(14, 38), "Desenhe um sigilo e solte", 10, UIKit.INK)
		var sp: PackedVector2Array = player.sigil_points
		if sp.size() > 1:
			d.draw_polyline(sp, Color(1.0, 0.6, 2.6, 0.5), 5.0)
			d.draw_polyline(sp, Color(2.6, 2.2, 3.6), 1.5)


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
