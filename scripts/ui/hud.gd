extends CanvasLayer
## HUD da fase + painéis de diálogo (NPC), mural de missões e resumo.

const FONT := preload("res://assets/fonts/kenney_pixel.ttf")

var level: Node = null
var player: Node = null
var boss: Node = null
var _root: Control
var _draw_node: Control
var _left_node: Control ## vida/foco/dash (translúcido se o jogador passa por baixo)
var _right_node: Control ## brasas/arma/magias/poção
var _cv: Control ## onde os helpers desenham agora
var _toasts: VBoxContainer
var _combo: int = 0
var _combo_pop: float = 0.0
var _hp_ghost: float = 1.0
var _panel: Control = null
var _region_title_t: float = 0.0
var _region_title: String = ""


func _ready() -> void:
	layer = 10
	scale = Vector2(2.0 / 3.0, 2.0 / 3.0) ## layout em 480x270, tela base 320x180
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(480, 270)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	_draw_node = Control.new()
	_draw_node.size = Vector2(480, 270)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_draw_hud)
	_root.add_child(_draw_node)
	_left_node = _layer_node(_draw_left)
	_right_node = _layer_node(_draw_right)
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
	_left_node.queue_redraw()
	_right_node.queue_redraw()
	var k := 1.0 - exp(-delta * 10.0)
	_left_node.modulate.a = lerpf(_left_node.modulate.a, _cluster_alpha(Rect2(0, 0, 150, 50)), k)
	_right_node.modulate.a = lerpf(_right_node.modulate.a, _cluster_alpha(Rect2(370, 0, 110, 48)), k)


func _layer_node(cb: Callable) -> Control:
	var c := Control.new()
	c.size = Vector2(480, 270)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		_cv = c
		cb.call())
	_root.add_child(c)
	return c


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
		_cv.draw_string_outline(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.04, 0.02, 0.07, color.a))
	_cv.draw_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _bar(rect: Rect2, ratio: float, color: Color, ghost: float = -1.0) -> void:
	var d := _cv
	d.draw_rect(rect.grow(1), Color(0.02, 0.01, 0.04, 0.9))
	d.draw_rect(rect, Color(0.12, 0.1, 0.16))
	if ghost > ratio:
		d.draw_rect(Rect2(rect.position, Vector2(rect.size.x * ghost, rect.size.y)), Color(1.0, 0.9, 0.8, 0.6))
	d.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), rect.size.y)), color)
	d.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), 1)), Color(color.r * 1.4, color.g * 1.4, color.b * 1.4))


## Caixinha de ícone 18x18 da HUD.
func _slot(pos: Vector2, icon: Texture2D) -> void:
	_cv.draw_rect(Rect2(pos, Vector2(18, 18)), Color(0.05, 0.04, 0.08, 0.8))
	_cv.draw_rect(Rect2(pos, Vector2(18, 18)), Color(0.4, 0.35, 0.55, 0.6), false, 1.0)
	if icon:
		_cv.draw_texture_rect(icon, Rect2(pos + Vector2(1, 1), Vector2(16, 16)), false)


## A HUD fica translúcida quando o jogador (ou a ação) passa por baixo dela.
func _cluster_alpha(rect: Rect2) -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	var sp: Vector2 = player.get_global_transform_with_canvas().origin * 1.5
	return 0.3 if rect.grow(10).has_point(sp) or rect.grow(10).has_point(sp - Vector2(0, 18)) else 1.0


func _draw_left() -> void:
	var d := _cv
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


func _draw_right() -> void:
	var d := _cv
	if player == null or not is_instance_valid(player):
		return
	# brasas + equipamento (canto superior direito, compacto)
	var cur := int(Game.profile.get("currency", 0))
	var cur_s := str(cur)
	var cw := FONT.get_string_size(cur_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	d.draw_circle(Vector2(462 - cw, 13), 3.0, Color(2.4, 1.4, 0.4))
	_text(Vector2(468 - cw, 17), cur_s, 12, Color(1.0, 0.8, 0.45))
	var slots: Array = Game.profile.get("spell_slots", [])
	var keys := [Settings.binding_label("spell_1"), Settings.binding_label("spell_2")]
	var potions := int(Game.profile.get("items", {}).get("pocao_vida", 0))
	var x0 := 470.0 - 20.0 * (1 + slots.size() + (1 if potions > 0 else 0))
	_slot(Vector2(x0, 22), DB.icon(player.weapon_id))
	for i in slots.size():
		var sid: String = slots[i]
		var x := x0 + 20.0 * (i + 1)
		_slot(Vector2(x, 22), DB.icon(sid))
		var cd: float = player.caster.cooldown_left(sid)
		var total: float = maxf(float(DB.spell(sid).get("cooldown", 1.0)), 0.01)
		if cd > 0.0:
			d.draw_rect(Rect2(x, 22 + 18 * (1.0 - cd / total), 18, 18 * cd / total), Color(0, 0, 0, 0.6))
		var cost: float = player.caster.cost_of(sid, Inventory.spell_level(Game.profile, sid))
		if player.focus < cost:
			d.draw_rect(Rect2(x, 22, 18, 18), Color(0.1, 0.1, 0.4, 0.45))
		_text(Vector2(x + 12, 42), keys[i] if i < keys.size() else "", 8, UIKit.GOLD)
	if potions > 0:
		var px := x0 + 20.0 * (slots.size() + 1)
		_slot(Vector2(px, 22), DB.icon("pocao_vida"))
		_text(Vector2(px + 1, 42), Settings.binding_label("heal"), 8, UIKit.GOLD)
		_text(Vector2(px + 11, 38), str(potions), 9, Color(1.4, 0.7, 0.8))


func _draw_hud() -> void:
	_cv = _draw_node
	var d := _draw_node
	if player == null or not is_instance_valid(player):
		return
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
		var sp := PackedVector2Array()
		for q in player.sigil_points:
			sp.append(q * 1.5)
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
	# serviços: loja, forja, estudo, cura
	var srv := UIKit.hbox(4)
	var services: Array = npc.get("services", [])
	if Commerce.can_buy(npc):
		srv.add_child(UIKit.button("Comprar", func(): open_shop(npc_id, false), 60))
	if Commerce.can_sell(npc):
		srv.add_child(UIKit.button("Vender", func(): open_shop(npc_id, true), 50))
	if services.has("upgrade_weapon") or services.has("upgrade_armor"):
		srv.add_child(UIKit.button("Forja", func(): open_forge(npc_id), 50))
	if services.has("upgrade_spell"):
		srv.add_child(UIKit.button("Estudar magias", func(): open_study(npc_id), 90))
	if services.has("heal") and player and player.hp < player.max_hp():
		var cost := Commerce.heal_cost(player.max_hp() - player.hp, npc)
		srv.add_child(UIKit.button("Curar (%d brasas)" % cost, func():
			if int(Game.profile.get("currency", 0)) < cost:
				toast("Brasas insuficientes.")
				return
			Game.profile["currency"] = int(Game.profile["currency"]) - cost
			player.heal(player.max_hp() - player.hp)
			Audio.play("pickup")
			open_dialogue(npc_id), 100))
	if srv.get_child_count() > 0:
		v.add_child(srv)
	_open_panel(p)


# ---------------------------------------------------------------------------
# Loja / forja / estudo (lógica em Commerce)
# ---------------------------------------------------------------------------

func _wallet_label(npc: Dictionary) -> Label:
	var frag := int(Game.profile.get("items", {}).get(Commerce.FRAGMENT, 0))
	var txt := "Brasas: %d    Fragmentos Rúnicos: %d" % [int(Game.profile.get("currency", 0)), frag]
	var d := Commerce.discount(npc)
	if d > 0.0:
		txt += "    (amizade: -%d%%)" % int(roundf(d * 100.0))
	return UIKit.label(txt, 10, UIKit.GOLD)


## Linha de loja: ícone, nome (+ descrição), preço e botão.
func _shop_row(id: String, price_text: String, action: String, enabled: bool, cb: Callable) -> Control:
	var box := UIKit.vbox(0)
	var row := UIKit.hbox(4)
	var ic := TextureRect.new()
	ic.texture = DB.icon(id)
	ic.custom_minimum_size = Vector2(16, 16)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(ic)
	var e := DB.get_entry(id)
	var name_l := UIKit.label(DB.display_name(id), 11, DB.rarity_color(e.get("rarity", "common")))
	name_l.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_l)
	var pl := UIKit.label(price_text, 10, UIKit.GOLD)
	pl.custom_minimum_size = Vector2(62, 0)
	row.add_child(pl)
	var b := UIKit.button(action, cb, 56)
	b.disabled = not enabled
	row.add_child(b)
	box.add_child(row)
	var desc: String = e.get("desc", "")
	if desc != "":
		var dl := UIKit.label("   " + desc, 9, UIKit.DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dl.custom_minimum_size = Vector2(310, 0)
		box.add_child(dl)
	return box


func _list_panel(title: String, npc: Dictionary) -> Array:
	var p := UIKit.panel(Vector2(350, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.label(title, 14, UIKit.GOLD))
	v.add_child(_wallet_label(npc))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(340, 160)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UIKit.vbox(3)
	sc.add_child(list)
	v.add_child(sc)
	return [p, v, list]


func open_shop(npc_id: String, selling: bool) -> void:
	var npc: Dictionary = Game.social["npcs"][npc_id]
	var parts := _list_panel("%s — %s" % [npc["name"], "vender" if selling else "loja"], npc)
	var p: Control = parts[0]
	var v: VBoxContainer = parts[1]
	var list: VBoxContainer = parts[2]
	var prof: Dictionary = Game.profile
	var ids: Array = Commerce.sellables(prof) if selling else Commerce.stock(Game.social, Game.world, npc_id, Game.seed_value)
	if ids.is_empty():
		list.add_child(UIKit.label("Nada por aqui." if not selling else "Você não tem nada que eu compre.", 11, UIKit.DIM))
	for i in ids:
		var id: String = i
		if selling:
			var n := int(prof.get("items", {}).get(id, 1))
			var price := Commerce.sell_price(id, npc)
			list.add_child(_shop_row(id, "+%d%s" % [price, (" (x%d)" % n) if n > 1 else ""], "Vender", true, func():
				var why := Commerce.sell(prof, Game.social, npc_id, id)
				if why != "":
					toast(why)
				else:
					Audio.play("coins")
					Game.save()
				open_shop(npc_id, true)))
		else:
			var price := Commerce.buy_price(id, npc)
			var owned := Commerce.owns(prof, id)
			var ok := not owned and int(prof.get("currency", 0)) >= price
			list.add_child(_shop_row(id, "já tem" if owned else "%d brasas" % price, "Comprar", ok, func():
				var why := Commerce.buy(prof, Game.social, npc_id, id)
				if why != "":
					toast(why)
					Audio.play("ui_error", 0.0, -6.0)
				else:
					toast("Comprou: " + DB.display_name(id))
					Audio.play("coins")
					if player:
						player.apply_profile()
					Game.save()
				open_shop(npc_id, false)))
	v.add_child(UIKit.button("Voltar", func(): open_dialogue(npc_id), 80))
	_open_panel(p)


func _cost_text(cost: Dictionary, npc: Dictionary) -> String:
	if cost.is_empty():
		return "máximo"
	return "%d + %d frag." % [int(roundf(int(cost["currency"]) * (1.0 - Commerce.discount(npc)))), int(cost["fragments"])]


func open_forge(npc_id: String) -> void:
	var npc: Dictionary = Game.social["npcs"][npc_id]
	var parts := _list_panel("%s — forja" % npc["name"], npc)
	var p: Control = parts[0]
	var v: VBoxContainer = parts[1]
	var list: VBoxContainer = parts[2]
	var prof: Dictionary = Game.profile
	var services: Array = npc.get("services", [])
	if services.has("upgrade_weapon"):
		list.add_child(UIKit.label("Armas (+%d%% de dano por nível)" % int(Commerce.WEAPON_UPGRADE * 100), 10, UIKit.DIM))
		for w in prof.get("weapons", []):
			var wid: String = w
			var lvl := Commerce.weapon_level(prof, wid)
			var cost := Commerce.weapon_cost(prof, wid)
			var row := _shop_row(wid, _cost_text(cost, npc), "Forjar", Commerce.can_pay(prof, cost, npc), func():
				var why := Commerce.upgrade_weapon(prof, wid, npc)
				if why != "":
					toast(why)
				else:
					toast("%s agora +%d" % [DB.display_name(wid), Commerce.weapon_level(prof, wid)])
					Audio.play("hit_metal")
					if player:
						player.apply_profile()
					Game.save()
				open_forge(npc_id))
			var nl: Label = row.get_child(0).get_child(1)
			nl.text += "  +%d" % lvl if lvl > 0 else ""
			list.add_child(row)
	if services.has("upgrade_armor"):
		list.add_child(UIKit.label("Armaduras (+15% dos atributos por nível)", 10, UIKit.DIM))
		if prof.get("armor", []).is_empty():
			list.add_child(UIKit.label("   Nenhuma peça.", 10, UIKit.DIM))
		for piece in prof.get("armor", []):
			var uid := int(piece["uid"])
			var cost := Commerce.armor_cost(prof, uid)
			var row := _shop_row(piece["id"], _cost_text(cost, npc), "Reforçar", Commerce.can_pay(prof, cost, npc), func():
				var why := Commerce.upgrade_armor(prof, uid, npc)
				if why != "":
					toast(why)
				else:
					Audio.play("hit_metal")
					if player:
						player.apply_profile()
					Game.save()
				open_forge(npc_id))
			var nl: Label = row.get_child(0).get_child(1)
			if int(piece.get("level", 0)) > 0:
				nl.text += "  +%d" % int(piece["level"])
			list.add_child(row)
	v.add_child(UIKit.button("Voltar", func(): open_dialogue(npc_id), 80))
	_open_panel(p)


func open_study(npc_id: String) -> void:
	var npc: Dictionary = Game.social["npcs"][npc_id]
	var parts := _list_panel("%s — estudar magias" % npc["name"], npc)
	var p: Control = parts[0]
	var v: VBoxContainer = parts[1]
	var list: VBoxContainer = parts[2]
	var prof: Dictionary = Game.profile
	var all: Array = prof.get("spells", {}).keys() + prof.get("sigils", {}).keys()
	if all.is_empty():
		list.add_child(UIKit.label("Você ainda não conhece magias.", 10, UIKit.DIM))
	for s in all:
		var sid: String = s
		var cost := Commerce.spell_cost(prof, sid)
		var row := _shop_row(sid, _cost_text(cost, npc), "Estudar", Commerce.can_pay(prof, cost, npc), func():
			var why := Commerce.upgrade_spell(prof, sid, npc)
			if why != "":
				toast(why)
			else:
				toast("%s nível %d" % [DB.display_name(sid), Inventory.spell_level(prof, sid) + 1])
				Audio.play("spell")
				Game.save()
			open_study(npc_id))
		var nl: Label = row.get_child(0).get_child(1)
		nl.text += "  nv.%d" % (Inventory.spell_level(prof, sid) + 1)
		list.add_child(row)
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
