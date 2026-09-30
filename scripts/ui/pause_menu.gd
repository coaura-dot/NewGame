extends CanvasLayer
## Menu de pausa: continuar, equipamento (armas, magias, armaduras com bônus
## de conjunto, relíquias), opções, voltar ao mapa, menu principal.

var level: Node = null
var _root: Control
var _content: Control = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(480, 270)
	_root.theme = UIKit.theme()
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.7)
	dim.size = Vector2(480, 270)
	_root.add_child(dim)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _root.visible:
			if _content and _content.name != "Main":
				_show_main()
			else:
				close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_root.visible = true
	get_tree().paused = true
	Events.pause_toggled.emit(true)
	_show_main()


func close() -> void:
	_root.visible = false
	get_tree().paused = false
	Events.pause_toggled.emit(false)
	if level and level.player:
		level.player.apply_profile()


func _set_content(c: Control, id: String) -> void:
	if _content and is_instance_valid(_content):
		_content.queue_free()
	_content = UIKit.centered(c)
	_content.name = id
	_root.add_child(_content)
	UIKit.focus_first(c)


func _show_main() -> void:
	var p := UIKit.panel(Vector2(180, 0))
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(UIKit.title("Pausa", 24))
	v.add_child(UIKit.button("Continuar", close))
	v.add_child(UIKit.button("Equipamento", _show_equipment))
	v.add_child(UIKit.button("Códice", _show_codex))
	v.add_child(UIKit.button("Opções", _show_options))
	if level and not level.training and level.map_screen:
		v.add_child(UIKit.button("Mapa (M)", func():
			close()
			level.map_screen.call_deferred("open")))
	v.add_child(UIKit.button("Menu principal", func():
		get_tree().paused = false
		if level and level.training:
			Game.end_training()
		else:
			Game.save()
		Game.goto(Game.SCENE_MENU)))
	_set_content(p, "Main")


func _show_options() -> void:
	var o := OptionsMenu.new()
	o.closed.connect(_show_main)
	_set_content(o, "Options")


func _show_equipment() -> void:
	var prof: Dictionary = Game.profile
	var p := UIKit.panel(Vector2(440, 240))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(430, 220)
	p.add_child(tabs)
	# armas
	var wv := _tab(tabs, "Armas")
	wv.add_child(UIKit.label("Principal: %s   |   Secundária: %s" % [DB.display_name(prof["weapon"]), DB.display_name(prof.get("weapon_alt", ""))], 11, UIKit.GOLD))
	for w in prof.get("weapons", []):
		var wid: String = w
		var data: Dictionary = DB.weapon(wid)
		var row := UIKit.hbox(4)
		var ic := TextureRect.new()
		ic.texture = DB.icon(wid)
		row.add_child(ic)
		var lbl := UIKit.label("%s  [%s]  dano %d  T%d" % [data.get("name", wid), DB.weapon_classes.get(data.get("class", ""), {}).get("name", ""), int(data.get("damage", 0)), int(data.get("tier", 1))], 11, DB.rarity_color(data.get("rarity", "common")))
		lbl.custom_minimum_size = Vector2(250, 0)
		row.add_child(lbl)
		row.add_child(UIKit.button("Principal", func():
			if prof.get("weapon_alt", "") == wid:
				prof["weapon_alt"] = prof["weapon"]
			prof["weapon"] = wid
			_show_equipment(), 56))
		row.add_child(UIKit.button("Secund.", func():
			if prof["weapon"] != wid:
				prof["weapon_alt"] = wid
			_show_equipment(), 50))
		wv.add_child(row)
	# magias
	var sv := _tab(tabs, "Magias")
	sv.add_child(UIKit.label("Espaços: 1) %s   2) %s" % [DB.display_name(prof["spell_slots"][0]) if prof["spell_slots"].size() > 0 else "-", DB.display_name(prof["spell_slots"][1]) if prof["spell_slots"].size() > 1 else "-"], 11, UIKit.GOLD))
	for s in prof.get("spells", {}).keys():
		var sid: String = s
		var sd: Dictionary = DB.spell(sid)
		var row := UIKit.hbox(4)
		var ic := TextureRect.new()
		ic.texture = DB.icon(sid)
		row.add_child(ic)
		var lbl := UIKit.label("%s  (%s) nv.%d  custo %d" % [sd.get("name", sid), sd.get("school", ""), int(prof["spells"][sid]) + 1, int(sd.get("cost", 0))], 11, DB.rarity_color(sd.get("rarity", "common")))
		lbl.custom_minimum_size = Vector2(250, 0)
		row.add_child(lbl)
		row.add_child(UIKit.button("Espaço 1", func(): _assign_spell(0, sid), 56))
		row.add_child(UIKit.button("Espaço 2", func(): _assign_spell(1, sid), 56))
		sv.add_child(row)
	for s in prof.get("sigils", {}).keys():
		sv.add_child(UIKit.label("Sigilo: %s — desenhe um(a) %s" % [DB.display_name(s), DB.spell(s).get("sigil", "?")], 11, Color(1.4, 1.1, 2.0)))
	# armaduras
	var av := _tab(tabs, "Armadura")
	var counts := Inventory.set_counts(prof)
	var bonus_txt := []
	for set_id in counts.keys():
		bonus_txt.append("%s %d/6" % [DB.armor_sets[set_id]["name"], counts[set_id]])
	av.add_child(UIKit.label("Conjuntos: " + (", ".join(bonus_txt) if not bonus_txt.is_empty() else "nenhum"), 11, UIKit.GOLD))
	for set_id in counts.keys():
		for need in DB.armor_sets[set_id]["bonuses"].keys():
			var active: bool = counts[set_id] >= int(need)
			av.add_child(UIKit.label("  (%s) %s" % [need, DB.armor_sets[set_id]["bonuses"][need]["desc"]], 10, Color(0.6, 1.6, 0.8) if active else UIKit.DIM))
	if prof.get("armor", []).is_empty():
		av.add_child(UIKit.label("Nenhuma peça ainda. Inimigos dropam as armaduras que vestem.", 10, UIKit.DIM))
	for piece in prof.get("armor", []):
		var pc: Dictionary = piece
		var a: Dictionary = DB.armor.get(pc["id"], {})
		var equipped: bool = prof["equipped_armor"].values().has(pc["uid"])
		var af := []
		for st in pc.get("affixes", {}).keys():
			af.append("%s %+.2f" % [st, pc["affixes"][st]])
		var row := UIKit.hbox(4)
		var ic := TextureRect.new()
		ic.texture = DB.icon(pc["id"])
		row.add_child(ic)
		var lbl := UIKit.label("%s +%d  %s" % [a.get("name", pc["id"]), int(pc.get("level", 0)), " ".join(af)], 10, Color(0.6, 1.6, 0.8) if equipped else UIKit.INK)
		lbl.custom_minimum_size = Vector2(300, 0)
		row.add_child(lbl)
		row.add_child(UIKit.button("Equipar", func():
			Inventory.equip_armor(prof, int(pc["uid"]))
			_show_equipment(), 56))
		av.add_child(row)
	# relíquias
	var rv := _tab(tabs, "Relíquias")
	if prof.get("buffs", []).is_empty():
		rv.add_child(UIKit.label("Nenhuma relíquia. Elas combinam entre si — procure sinergias!", 10, UIKit.DIM))
	for b in prof.get("buffs", []):
		var bd: Dictionary = DB.buffs.get(b, {})
		var l := UIKit.label("%s — %s" % [bd.get("name", b), bd.get("desc", "")], 10, DB.rarity_color(bd.get("rarity", "common")))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(400, 0)
		rv.add_child(l)
	# habilidades
	var hv := _tab(tabs, "Habilidades")
	for ab in DB.abilities.keys():
		var has: bool = Game.has_ability(ab)
		hv.add_child(UIKit.label("%s %s — %s" % ["✔" if has else "✖", DB.abilities[ab]["name"], DB.abilities[ab]["desc"]], 10, UIKit.INK if has else UIKit.DIM))
	var back := UIKit.button("Voltar", _show_main, 80)
	var wrap := UIKit.vbox(4)
	wrap.add_child(p)
	wrap.add_child(back)
	_set_content(wrap, "Equipment")


## Códice: a história de Cindária, os Dons obtidos, os Reflexos visitados e
## as inscrições lidas (por bioma).
func _show_codex() -> void:
	var lore: Dictionary = DB.lore
	var p := UIKit.panel(Vector2(440, 240))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(430, 220)
	p.add_child(tabs)
	var hv := _tab(tabs, "História")
	for e in lore.get("codex", []):
		hv.add_child(UIKit.label(str(e["title"]), 12, UIKit.GOLD))
		hv.add_child(_wrap(str(e["text"])))
	for panel in lore.get("intro", []):
		hv.add_child(_wrap("• " + str(panel["text"]), UIKit.DIM))
	var av := _tab(tabs, "Dons")
	var any_ab := false
	for ab in Game.profile.get("abilities", []):
		var t: String = lore.get("abilities", {}).get(ab, "")
		if t != "":
			av.add_child(_wrap(t))
			any_ab = true
	if not any_ab:
		av.add_child(UIKit.label("Derrote guardiões para recuperar os Dons de Ignara.", 11, UIKit.DIM))
	var dv := _tab(tabs, "Reflexos")
	var any_dim := false
	for r in Game.world.get("regions", {}).values():
		if r.get("dimension", "prima") != "prima" and r.get("visited", false):
			dv.add_child(_wrap(str(lore.get("dimensions", {}).get(r["dimension"], r["name"]))))
			any_dim = true
	if not any_dim:
		dv.add_child(UIKit.label("Nenhum Reflexo visitado ainda. (Chave Dimensional + fendas)", 11, UIKit.DIM))
	var iv := _tab(tabs, "Inscrições")
	var read: Array = Game.profile.get("codex", [])
	var by_biome := {}
	for id in read:
		var parts: PackedStringArray = str(id).split(":")
		if parts.size() == 2:
			if not by_biome.has(parts[0]):
				by_biome[parts[0]] = []
			by_biome[parts[0]].append(int(parts[1]))
	if by_biome.is_empty():
		iv.add_child(UIKit.label("Leia as inscrições de pedra espalhadas pelas regiões.", 11, UIKit.DIM))
	for b in by_biome.keys():
		iv.add_child(UIKit.label(str(DB.biome(b).get("name", b)), 12, UIKit.GOLD))
		var lines: Array = lore.get("biomes", {}).get(b, [])
		for i in by_biome[b]:
			if not lines.is_empty():
				iv.add_child(_wrap("“" + str(lines[i % lines.size()]) + "”"))
	var back := UIKit.button("Voltar", _show_main, 80)
	var v := UIKit.vbox(4)
	v.add_child(p)
	v.add_child(back)
	_set_content(v, "Codex")


func _wrap(text: String, color: Color = UIKit.INK) -> Label:
	var l := UIKit.label(text, 11, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(400, 0)
	return l


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	tabs.add_child(sc)
	return v


func _assign_spell(slot: int, sid: String) -> void:
	var slots: Array = Game.profile["spell_slots"]
	while slots.size() <= slot:
		slots.append(sid)
	var other := 1 - slot
	if other < slots.size() and slots[other] == sid:
		slots[other] = slots[slot]
	slots[slot] = sid
	_show_equipment()
