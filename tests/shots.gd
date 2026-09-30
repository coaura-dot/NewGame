extends Node
## Tira várias screenshots de uma vez (precisa de renderizador, não headless):
##   godot --path . res://tests/shots.tscn -- <pasta_saida> [cenario]
## Cenários: rooms (cada sala do treino), region (cada sala de uma região
## real), menu, pause, map, all (padrão).

var out_dir := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scenario := args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if scenario in ["menu", "all"]:
		await _shot_scene("res://scenes/main_menu.tscn", "menu", 20)
	if scenario in ["rooms", "all"]:
		Game.pending = {"training": true}
		await _shot_rooms("treino")
	if scenario in ["pause", "all"]:
		Game.pending = {"training": true}
		await _shot_pause()
	if scenario in ["region", "all"]:
		Game.new_game(1234, 9)
		var start: String = Game.world["start"]
		Game.pending = {"region": start}
		await _shot_rooms("regiao")
		SaveSystem.delete_save(9)
	if scenario in ["bosses", "all"]:
		for b in ["duelist", "brood_mother", "colossus"]:
			Game.pending = {"training": true}
			await _shot_boss(b)
	if scenario in ["shop", "all"]:
		await _shot_shop()
	if scenario in ["combat", "all"]:
		Game.pending = {"training": true}
		await _shot_combat()
	if scenario in ["overview", "all"]:
		for biome in ["castelo", "floresta"]:
			Game.new_game(1234, 9)
			var rid := ""
			for r in Game.world["regions"].keys():
				if Game.world["regions"][r]["biome"] == biome:
					rid = r
					break
			if rid == "":
				rid = Game.world["start"]
			Game.pending = {"region": rid}
			await _shot_overview("fase_" + biome)
			SaveSystem.delete_save(9)
	if scenario in ["modos"]:
		await _shot_modes()
	if scenario in ["biomes", "all"]:
		await _shot_biomes()
	if scenario in ["intro", "all"]:
		await _shot_intro()
	if scenario in ["juice", "all"]:
		Game.pending = {"training": true}
		await _shot_juice()
	if scenario in ["map", "all"]:
		await _shot_map()
	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot_scene(path: String, name: String, wait: int) -> void:
	var node: Node = load(path).instantiate()
	add_child(node)
	await _frames(wait)
	await _save(name)
	node.queue_free()
	await _frames(2)


func _shot_pause() -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(30)
	if level.pause_menu and level.pause_menu.has_method("open"):
		level.pause_menu.open()
	await _frames(10)
	await _save("pausa")
	get_tree().paused = false
	level.queue_free()
	await _frames(2)
	Game.end_training()


## Luta contra um chefe: 8 quadros espaçados (jogador parado, invencível).
func _shot_boss(id: String) -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(30)
	Settings.data["gameplay"]["invincible"] = true
	var p: Player = level.player
	var boss: Enemy = level._make_enemy(id, 2, p.global_position + Vector2(70, -2), level._current_room)
	level.entities.add_child(boss)
	level.boss_node = boss
	level.hud.show_boss(boss)
	var frames: Array[Image] = []
	for i in 8:
		await _physics(40)
		if id == "brood_mother" and i == 4:
			for m in boss._minions:
				if is_instance_valid(m) and not m.dead:
					m.take_status_damage(9999.0, "fall")
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
		frames.append(img)
	var sheet := Image.create(640 * 4, 360 * 2, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var f := frames[i]
		f.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(f, Rect2i(0, 0, 640, 360), Vector2i((i % 4) * 640, (i / 4) * 360))
	sheet.save_png(out_dir.path_join("chefe_%s.png" % id))
	Settings.data["gameplay"]["invincible"] = false
	level.queue_free()
	await _frames(2)
	Game.end_training()


## Painéis de diálogo, loja, forja e estudo com NPCs de uma vila.
func _shot_shop() -> void:
	Game.new_game(1234, 9)
	var hub := ""
	for rid in Game.world["regions"].keys():
		if Game.world["regions"][rid].get("hub", "") != "":
			hub = rid
			break
	Game.pending = {"region": hub}
	Game.profile["currency"] = 600
	Game.profile["items"][Commerce.FRAGMENT] = 3
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(30)
	var ids := {}
	for npc in Game.social["npcs"].values():
		for s in npc["services"]:
			ids[s] = npc["id"]
	# garante um de cada serviço para a foto
	var any: String = Game.social["npcs"].keys()[0]
	var npc0: Dictionary = Game.social["npcs"][any]
	npc0["services"] = ["shop", "upgrade_weapon", "upgrade_armor", "upgrade_spell", "heal"]
	level.hud.open_dialogue(any)
	await _frames(6)
	await _save("npc_dialogo")
	level.hud.open_shop(any, false)
	await _frames(6)
	await _save("npc_loja")
	level.hud.open_forge(any)
	await _frames(6)
	await _save("npc_forja")
	level.hud.open_study(any)
	await _frames(6)
	await _save("npc_estudo")
	level.hud.close_panel()
	level.queue_free()
	await _frames(2)
	SaveSystem.delete_save(9)


## Sequência de quadros de golpes (leve, pesado carregado, para cima, no ar)
## com várias armas, recortada e ampliada ao redor do jogador.
func _shot_combat() -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(30)
	var p: Player = level.player
	var frames: Array[Image] = []
	var labels: Array[String] = []
	# 1 passo de física por quadro desenhado: cada foto = 1/60 s de jogo
	var old_steps := Engine.max_physics_steps_per_frame
	Engine.max_physics_steps_per_frame = 1
	for wid in ["katana_andarilho", "montante_ferro", "estoque_duelista", "bastao_carvalho", "guarda_cidadela", "manoplas_pesadelo"]:
		if not DB.weapons.has(wid):
			continue
		p.equip_weapon(wid)
		for action in ["attack", "attack_up"]:
			p.velocity = Vector2.ZERO
			p.facing = 1
			await _physics(20)
			if action == "attack_up":
				Input.action_press("move_up")
			Input.action_press("attack")
			await _physics(1)
			Input.action_release("attack")
			for i in 7:
				await _physics(1 if i < 5 else 2)
				await RenderingServer.frame_post_draw
				frames.append(_crop_player(level, p))
				labels.append("%s %s %d" % [wid, action, i])
			Input.action_release("move_up")
			await _physics(30)
	Engine.max_physics_steps_per_frame = old_steps
	# folha: 7 quadros por linha
	var cw := frames[0].get_width()
	var ch := frames[0].get_height()
	var rows := int(ceil(frames.size() / 7.0))
	var sheet := Image.create(cw * 7, ch * rows, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, cw, ch), Vector2i((i % 7) * cw, (i / 7) * ch))
	sheet.save_png(out_dir.path_join("golpes.png"))
	level.queue_free()
	await _frames(2)
	Game.end_training()


## Corte-Relâmpago atravessando 3 inimigos: folha com 12 quadros da tela
## inteira (hitstop, faíscas, quadro de impacto, corpos cortados).
func _shot_juice() -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(30)
	Settings.data["gameplay"]["invincible"] = true
	var p: Player = level.player
	p.equip_weapon("katana_andarilho")
	for i in 3:
		var en: Enemy = level._make_enemy("skeleton", 1, p.global_position + Vector2(26 + i * 16, 0), level._current_room)
		en.hp = 1.0
		level.entities.add_child(en)
	await _physics(10)
	for en in get_tree().get_nodes_in_group("enemies"):
		en.hp = 1.0
		en.ai_state = "recover"
		en.ai_t = 5.0
	var frames: Array[Image] = []
	Input.action_press("move_right")
	Input.action_press("dash")
	await _physics(2)
	Input.action_press("attack")
	await _physics(1)
	Input.action_release("dash")
	Input.action_release("attack")
	for i in 12:
		await _frames(2)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
		img.convert(Image.FORMAT_RGBA8)
		frames.append(img)
	Input.action_release("move_right")
	var sheet := Image.create(640 * 4, 360 * 3, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, 640, 360), Vector2i((i % 4) * 640, (i / 4) * 360))
	sheet.save_png(out_dir.path_join("impacto.png"))
	Settings.data["gameplay"]["invincible"] = false
	level.queue_free()
	await _frames(2)
	Game.end_training()


## Um quadro por bioma (treino no bioma): tiles, fundo, água, adereços.
func _shot_biomes() -> void:
	var list := ["floresta", "pantano", "castelo", "cidade_gotica", "deserto", "cidade_ceu", "toca_goblin", "fortaleza_orc", "catacumbas", "cemiterio", "cidade_magos", "ruinas"]
	var frames: Array[Image] = []
	for b in list:
		Game.pending = {"training": true, "biome": b}
		var level: Node = load("res://scenes/level.tscn").instantiate()
		add_child(level)
		await _frames(20)
		var p: Player = level.player
		var rows: PackedStringArray = level.layout["rows"]
		# prefere a sala 1 ou 2 (combate/parkour)
		var room: Dictionary = level.layout["rooms"][mini(1, level.layout["rooms"].size() - 1)]
		var o: Array = room["origin"]
		p.global_position = _stand_spot(rows, int(o[0]), int(o[1]))
		p.velocity = Vector2.ZERO
		p.reset_physics_interpolation()
		level._focus_camera_on_player()
		await _frames(40)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
		img.convert(Image.FORMAT_RGBA8)
		frames.append(img)
		level.queue_free()
		await _frames(3)
		Game.end_training()
	var sheet := Image.create(640 * 3, 360 * 4, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, 640, 360), Vector2i((i % 3) * 640, (i / 3) * 360))
	sheet.save_png(out_dir.path_join("biomas.png"))


## Os 6 quadros da abertura numa folha.
func _shot_intro() -> void:
	Game.new_game(1234, 9)
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	add_child(intro)
	var frames: Array[Image] = []
	for i in intro._panels.size():
		intro._show(i)
		await _frames(150)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
		img.convert(Image.FORMAT_RGBA8)
		frames.append(img)
	var sheet := Image.create(640 * 3, 360 * 2, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, 640, 360), Vector2i((i % 3) * 640, (i / 3) * 360))
	sheet.save_png(out_dir.path_join("abertura.png"))
	intro._leaving = true
	intro.queue_free()
	await _frames(2)
	SaveSystem.delete_save(9)


## Mapa do mundo contínuo: visita a região inicial e as vizinhas (resumo
## registrado como se tivessem sido exploradas) e abre o mapa.
func _shot_map() -> void:
	Game.new_game(1234, 9)
	var start: String = Game.world["start"]
	var lib := ChunkLibrary.new()
	var ids: Array = [start]
	for nb in WorldGenerator.neighbors(Game.world, start):
		ids.append(nb["id"])
	for id in ids:
		var r: Dictionary = Game.world["regions"][id]
		if r.get("dimension", "prima") != "prima":
			continue
		r["visited"] = true
		var params := {"seed": int(r["level_seed"]), "biome": r["biome"], "tier": int(r["tier"]), "boss": r.get("boss", ""),
			"hub": r.get("hub", ""), "npcs": [], "abilities": [], "ports": WorldGenerator.ports(Game.world, id), "layer": r.get("layer", "")}
		var lay := RegionDesigner.generate(params, DB)
		Game.record_map(id, lay)
		for i in lay["rooms"].size():
			if i % 3 != 2 or id == start:
				Game.mark_explored(id, i)
		Game.add_shrine(id)
	Game.pending = {"region": start}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(20)
	level.map_screen.open()
	await _frames(10)
	await _save("mapa")
	level.map_screen._view = "world"
	await _frames(4)
	await _save("mapa_mundo")
	level.map_screen.close()
	# HUD: objetivo e nome de lugar
	for room in level.layout["rooms"]:
		if room["kind"] in ["trilha", "salao", "poco", "galeria"]:
			level.player.global_position = _place_spot(level.layout["rows"], room["rect"])
			level.player.reset_physics_interpolation()
			level._focus_camera_on_player()
			break
	await _frames(40)
	await _save("hud_lugar")
	level.queue_free()
	await _frames(2)
	SaveSystem.delete_save(9)


## A fase inteira numa imagem só (mapa do layout renderizado de verdade).
func _shot_overview(name: String) -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(20)
	var size := Vector2i(int(level.layout["width"]) * LevelConst.TILE, int(level.layout["height"]) * LevelConst.TILE)
	size = size.min(Vector2i(8192, 8192))
	level.world_vp.size = size
	level.camera.enabled = false
	level.world_vp.canvas_transform = Transform2D.IDENTITY
	for c in level.world.get_children():
		if c is CanvasLayer:
			c.visible = false
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img: Image = level.world_vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.linear_to_srgb()
	img.save_png(out_dir.path_join(name + ".png"))
	level.queue_free()
	await _frames(2)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _crop_player(level: Node, p: Node2D) -> Image:
	var img: Image = level.world_vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.linear_to_srgb() # o viewport do mundo é HDR linear
	var sp: Vector2 = p.get_global_transform_with_canvas().origin
	var r := Rect2i(int(sp.x) - 24, int(sp.y) - 30, 48, 36)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(r)
	c.resize(c.get_width() * 4, c.get_height() * 4, Image.INTERPOLATE_NEAREST)
	return c


## Coloca o jogador em pé no meio de cada sala e fotografa.
func _shot_rooms(prefix: String) -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(30)
	var p: Player = level.player
	var rows: PackedStringArray = level.layout["rows"]
	for room in level.layout["rooms"]:
		var o: Array = room["origin"]
		var spot := _place_spot(rows, room["rect"]) if room.has("rect") else _stand_spot(rows, int(o[0]), int(o[1]))
		p.global_position = spot
		p.velocity = Vector2.ZERO
		p.reset_physics_interpolation()
		level._focus_camera_on_player()
		await _frames(12)
		await _save("%s_%02d_%s" % [prefix, int(room["index"]), str(room.get("kind", room["type"]))])
	level.queue_free()
	await _frames(2)
	if Game.training:
		Game.end_training()


## Ponto em pé mais perto do centro de um lugar (RegionDesigner).
func _place_spot(rows: PackedStringArray, rect: Array) -> Vector2:
	var T := LevelConst.TILE
	var cx: int = int(rect[0]) + int(rect[2]) / 2
	var cy: int = int(rect[1]) + int(rect[3]) / 2
	var best := Vector2(cx * T, cy * T)
	var bd := 1 << 30
	for y in range(int(rect[1]) + 1, int(rect[1]) + int(rect[3]) - 1):
		for x in range(int(rect[0]) + 1, int(rect[0]) + int(rect[2]) - 1):
			if y + 1 >= rows.size():
				continue
			if rows[y][x] != "#" and rows[y - 1][x] != "#" and rows[y + 1][x] in ["#", "-"]:
				var d: int = absi(x - cx) + absi(y - cy) * 2
				if d < bd:
					bd = d
					best = Vector2(x * T + T * 0.5, (y + 1) * T)
	return best


func _stand_spot(rows: PackedStringArray, ox: int, oy: int) -> Vector2:
	var T := LevelConst.TILE
	for dx in [20, 16, 24, 12, 28, 8, 32, 5, 35]:
		for y in range(LevelConst.ROOM_H - 2, 1, -1):
			var x: int = ox + dx
			var yy: int = oy + y
			if rows[yy][x] != "#" and rows[yy - 1][x] != "#" and rows[yy + 1][x] in ["#", "-"]:
				return Vector2(x * T + T * 0.5, (yy + 1) * T)
	return Vector2((ox + 20) * T, (oy + 12) * T)


## Regiões de cada tipo (castelo, caverna, céu, cidade...): alguns lugares de
## cada uma numa folha (modos.png).
func _shot_modes() -> void:
	var want := ["castelo", "toca_goblin", "cidade_ceu", "cidade_gotica", "catacumbas", "pantano"]
	var frames: Array[Image] = []
	for b in want:
		var found := ""
		for s in [1234, 77, 99, 4321, 555]:
			Game.new_game(s, 9)
			for id in Game.world["regions"].keys():
				if Game.world["regions"][id]["biome"] == b and Game.world["regions"][id].get("dimension", "prima") == "prima":
					found = id
					break
			if found != "":
				break
		if found == "":
			continue
		Game.pending = {"region": found}
		var level: Node = load("res://scenes/level.tscn").instantiate()
		add_child(level)
		await _frames(20)
		var p: Player = level.player
		var rows: PackedStringArray = level.layout["rows"]
		var picks: Array = []
		for room in level.layout["rooms"]:
			if room["kind"] in ["santuario", "vila", "covil", "coracao", "salao", "poco", "abismo", "galeria", "ninho"] and picks.size() < 4:
				var dup := false
				for q in picks:
					if q["kind"] == room["kind"]:
						dup = true
				if not dup:
					picks.append(room)
		for room in picks:
			p.global_position = _place_spot(rows, room["rect"])
			p.velocity = Vector2.ZERO
			p.reset_physics_interpolation()
			level._focus_camera_on_player()
			await _frames(14)
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			img.convert(Image.FORMAT_RGBA8)
			frames.append(img)
		level.queue_free()
		await _frames(3)
		SaveSystem.delete_save(9)
	var cols := 4
	var nrows := (frames.size() + cols - 1) / cols
	var sheet := Image.create(480 * cols, 270 * maxi(nrows, 1), false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, 480, 270), Vector2i((i % cols) * 480, (i / cols) * 270))
	sheet.save_png(out_dir.path_join("modos.png"))
