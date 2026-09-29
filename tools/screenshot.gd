extends SceneTree
## Tira prints do jogo rodando (renderizador real). Uso:
##   godot --path . --script tools/screenshot.gd -- <prefixo> [treino|menu|salas|heroi] [seed] [bioma] [tier]
## treino: anda, pula e ataca; menu: menu principal; salas: um print por sala
## do treino (teleporta o herói para cada sala); heroi: closes do Pavio em
## várias poses (parado, correndo, pulando, dash, golpe, feliz, ferido, morto);
## efeitos: dash, golpe e os efeitos de cada escola de magia;
## duelo: esqueleto telegrafando (amarelo/vermelho), guarda e janela de punição;
## mapa [seed]: mapa-múndi explorável (vila inicial, entradas, noite);
## intro: os cartões da introdução do novo jogo;
## regiao [seed]: fase da região inicial (tábua de pedra com a inscrição);
## bichos: os inimigos novos (mariposa, Guarda de Cinzas, Sopro) em ação.
## sombria [seed] [bioma]: a sala sombria do treino apagada e depois acesa.
## chefe <id>: um guardião duelando com o herói (vários quadros).
## loja [seed]: diálogo e painéis de loja/forja/estudo/venda na vila inicial.

var _out := "user://shot"
var _mode := "treino"
var _n := 0
var _level: Node = null
var _shots := [40, 110, 150, 200]
var _room := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_mode = args[1]


func _save(tag: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s_%s.png" % [_out, tag])


func _process(_d: float) -> bool:
	_n += 1
	if _mode in ["mapa", "intro", "loja"]:
		return _mapa()
	if _mode == "regiao":
		return _regiao()
	if _n == 2:
		if _mode == "menu":
			change_scene_to_file("res://scenes/main_menu.tscn")
		else:
			var pend := {"training": true}
			var args := OS.get_cmdline_user_args()
			if args.size() > 2:
				pend["seed"] = int(args[2])
			if args.size() > 3:
				pend["biome"] = args[3]
			if args.size() > 4:
				pend["tier"] = int(args[4])
			if args.size() > 5:
				_room = int(args[5])
			root.get_node("Game").pending = pend
			_level = load("res://scenes/level.tscn").instantiate()
			root.add_child(_level)
	if _mode == "salas":
		return _salas()
	if _mode == "sala":
		return _sala_unica()
	if _mode == "heroi":
		return _heroi()
	if _mode == "efeitos":
		return _efeitos()
	if _mode == "duelo":
		return _duelo()
	if _mode == "bichos":
		return _bichos()
	if _mode == "chefe":
		return _chefe()
	if _mode == "sombria":
		return _sombria()
	if _mode != "menu":
		if _n == 60:
			Input.action_press("move_right")
		if _n == 100:
			Input.action_press("jump")
		if _n == 112:
			Input.action_release("jump")
		if _n == 140:
			Input.action_press("attack")
		if _n == 143:
			Input.action_release("attack")
		if _n == 190:
			Input.action_release("move_right")
	if _n in _shots:
		_save(str(_shots.find(_n)))
	if _n > _shots[-1]:
		quit()
	return false


func _salas() -> bool:
	if _n < 30:
		return false
	var rooms: Array = _level.layout["rooms"]
	if _room >= rooms.size():
		quit()
		return false
	var k := (_n - 30) % 40
	if k == 0:
		var r: Rect2 = _level.room_rect(_room)
		# acha um chão livre perto do meio da sala
		var p = _level.player
		var best := r.get_center()
		var rows: PackedStringArray = _level.layout["rows"]
		var T := 8
		for dx in [0, -3, 3, -6, 6, -9, 9, -12, 12]:
			var tx: int = int(r.get_center().x / T) + int(dx)
			for ty in range(int(r.position.y / T) + 3, int(r.end.y / T) - 1):
				if rows[ty][tx] != "#" and rows[ty - 1][tx] != "#" and (rows[ty + 1][tx] == "#" or rows[ty + 1][tx] == "-"):
					best = Vector2(tx * T + 4, (ty + 1) * T)
					break
			if best != r.get_center():
				break
		p.global_position = best
		p._prev_pos = best
		p.reset_physics_interpolation()
		p.invuln_time = 99.0
		_level.camera.set_room(_level.camera_rect(_room))
		_level.camera.snap()
	if k == 30:
		_save("sala%02d_%s" % [_room, _level.layout["rooms"][_room]["type"]])
		_room += 1
	return false


## Uma sala só: entra pela esquerda e fica parado (mostra fuga/torretas agindo).
func _sala_unica() -> bool:
	if _n == 30:
		var r: Rect2 = _level.room_rect(_room)
		var rows: PackedStringArray = _level.layout["rows"]
		var tx := int(r.position.x / 8) + 2
		var p = _level.player
		for ty in range(int(r.position.y / 8) + 12, int(r.end.y / 8)):
			if rows[ty + 1][tx] == "#":
				p.global_position = Vector2(tx * 8 + 4, (ty + 1) * 8)
				break
		p._prev_pos = p.global_position
		p.reset_physics_interpolation()
	if _n in [60, 160, 260, 330]:
		_save("f%d" % _n)
	if _n > 340:
		quit()
	return false


## Closes do herói: cada pose vira um recorte ampliado em volta dele.
var _poses := [
	[40, "parado"], [75, "correndo"], [100, "pulando"], [118, "caindo"], [150, "dash"],
	[190, "golpe"], [230, "feliz"], [265, "ferido"], [300, "vida_baixa"], [345, "morto"],
]


func _heroi() -> bool:
	var p = _level.player if _level else null
	if p == null:
		return false
	match _n:
		60:
			Input.action_press("move_right")
		80:
			Input.action_press("jump")
		95:
			Input.action_release("jump")
		110:
			Input.action_release("move_right")
		145:
			Input.action_press("dash")
		148:
			Input.action_release("dash")
		186:
			Input.action_press("attack")
		189:
			Input.action_release("attack")
		220:
			p.rig.set_expression("happy", 2.0)
			p.rig.flame_pop(0.8)
		255:
			p.rig.play("hurt", true)
			p.rig.flame_blow(1.0)
			p.rig.set_expression("closed", 1.0)
		280:
			p.hp = p.max_hp() * 0.15
		320:
			p.state = p.State.DEAD
			p.rig.set_expression("dead")
			p.rig.extinguish()
	for pose in _poses:
		if _n == int(pose[0]):
			_crop(p, str(pose[1]))
	if _n > 350:
		quit()
	return false


func _crop(p: Node, tag: String) -> void:
	var img := root.get_texture().get_image()
	var sc := float(img.get_width()) / 320.0
	var at: Vector2 = _level.pixel_view.world_to_screen(p.global_position + Vector2(0, -9)) * sc
	var sz := Vector2(56, 40) * sc
	var r := Rect2i(Vector2i((at - sz * 0.5).round()), Vector2i(sz.round()))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png("%s_%s.png" % [_out, tag])


## Efeitos: dash no meio, golpe no meio e as escolas de magia lado a lado.
func _efeitos() -> bool:
	var p = _level.player if _level else null
	if p == null:
		return false
	match _n:
		40:
			Input.action_press("dash")
		42:
			Input.action_release("dash")
		80:
			Input.action_press("attack")
		82:
			Input.action_release("attack")
		120, 150:
			var schools := ["fire", "ice", "lightning", "void", "heal", "earth", "water", "arcane"]
			var cols := [Color(3.2, 1.2, 0.3), Color(0.8, 1.8, 3.0), Color(2.4, 2.6, 4.0), Color(1.0, 0.4, 2.0), Color(1.4, 2.8, 1.6), Color(1.3, 0.9, 0.5), Color(0.4, 1.4, 2.6), Color(2.2, 0.8, 3.0)]
			var fx_cls = load("res://scripts/fx/school_fx.gd")
			for i in schools.size():
				var at: Vector2 = p.global_position + Vector2(-84 + i * 24, -40)
				fx_cls.impact(p.get_parent(), schools[i], at, Vector2.UP, cols[i], 1.3)
				for k in 4:
					fx_cls.trail(p.get_parent(), schools[i], at + Vector2(0, 16 + k * 4), Vector2(0, -60), cols[i])
	if _n == 44:
		_crop(p, "dash")
	if _n == 46:
		_crop(p, "dash2")
	if _n in [83, 85, 87, 89]:
		_crop(p, "golpe%d" % _n)
	if _n == 127:
		_save("escolas_a")
	if _n == 162:
		_save("escolas_b")
	if _n > 165:
		quit()
	return false


var _en: Node = null
var _shot_tags := {}


func _duelo() -> bool:
	var p = _level.player if _level else null
	if p == null:
		return false
	if _n == 30:
		p.invuln_time = 999.0
		_en = load("res://scripts/actors/enemy.gd").new()
		_en.setup("skeleton", 2)
		_en.position = p.global_position + Vector2(36, -2)
		_en.level = _level
		p.get_parent().add_child(_en)
	if _en and is_instance_valid(_en) and _n > 32:
		_en.hp = _en.max_hp()
		p._idle_t = 0.0
		var st: String = _en.ai_state
		var late: bool = _en.ai_t < 0.16
		if st.ends_with("windup") and late and not _en.tele_red and not _shot_tags.has("amarelo"):
			_shot_tags["amarelo"] = true
			_crop2(p, "amarelo")
		elif st.ends_with("windup") and late and _en.tele_red and not _shot_tags.has("vermelho"):
			_shot_tags["vermelho"] = true
			_crop2(p, "vermelho")
		elif _en.punish_t > 0.0 and not _shot_tags.has("punicao"):
			_shot_tags["punicao"] = true
			_crop2(p, "punicao")
		if _shot_tags.has("amarelo") and _shot_tags.has("punicao") and not _shot_tags.has("guarda"):
			_shot_tags["guarda"] = true
			_en._start_guard()
		elif st == "guard" and not _shot_tags.has("guarda_shot"):
			_shot_tags["guarda_shot"] = true
			_crop2(p, "guarda")
	if _n > 1500 or _shot_tags.size() >= 5:
		quit()
	return false


func _crop2(p: Node, tag: String) -> void:
	var img := root.get_texture().get_image()
	var sc := float(img.get_width()) / 320.0
	var at: Vector2 = _level.pixel_view.world_to_screen(p.global_position + Vector2(18, -12)) * sc
	var sz := Vector2(80, 48) * sc
	var r := Rect2i(Vector2i((at - sz * 0.5).round()), Vector2i(sz.round()))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png("%s_%s.png" % [_out, tag])


var _ow: Node = null
var _visit: Array = []


func _mapa() -> bool:
	var game = root.get_node("Game")
	if _n == 2:
		var args := OS.get_cmdline_user_args()
		game.new_game(int(args[2]) if args.size() > 2 else 12345)
		if _mode in ["mapa", "loja"]:
			game.profile["flags"] = {"intro_seen": true}
		game.profile["ow_clock"] = 0.45
		change_scene_to_file("res://scenes/overworld.tscn")
		return false
	if _ow == null:
		_ow = current_scene if current_scene and current_scene.name == "Overworld" else null
		return false
	if _mode == "intro":
		if _n in [30, 60, 90, 120, 150]:
			_save("intro%d" % (_n / 30))
			var ev := InputEventAction.new()
			ev.action = "jump"
			ev.pressed = true
			Input.parse_input_event(ev)
		if _n > 160:
			quit()
		return false
	if _mode == "loja":
		return _loja(game)
	if _n == 40:
		_save("vila")
	if _n == 41:
		for id in _ow.data["entrances"].keys():
			_visit.append(id)
		_visit.sort()
	var k := _n - 50
	if k >= 0 and k % 25 == 0:
		var i := k / 25
		if i < mini(_visit.size(), 6):
			var id: String = _visit[i * 3 % _visit.size()]
			game.world["regions"][id]["visited"] = true
			_ow.known = _ow._known_regions()
			_ow._refresh_fog()
			_ow.hero.global_position = _ow.feet_px(_ow.data["entrances"][id]) + Vector2(0, 16)
			_ow.camera.snap()
		elif i == 6:
			game.profile["ow_clock"] = 0.02
		elif i == 7:
			var gl: Array = _ow._glows
			print("glows ", gl.size(), " night ", _ow.night)
			for g in gl.slice(0, 4):
				print("  ", g.global_position, " mod ", g.modulate, " vis ", g.is_visible_in_tree(), " tex ", g.texture.get_size())
			_save("noite")
			quit()
	if k >= 0 and k % 25 == 20 and k / 25 < 6:
		_save("regiao%d" % (k / 25))
	return false


func _regiao() -> bool:
	var game = root.get_node("Game")
	if _n == 2:
		var args := OS.get_cmdline_user_args()
		game.new_game(int(args[2]) if args.size() > 2 else 12345)
		game.pending = {"region": game.world["start"]}
		_level = load("res://scenes/level.tscn").instantiate()
		root.add_child(_level)
		return false
	if _n == 40:
		_save("entrada")
	if _n == 45:
		for n in _level.entities.get_children():
			if n.get_script() and str(n.get_script().resource_path).ends_with("lore_tablet.gd"):
				n.interact(_level.player)
	if _n == 60:
		_save("tabua")
		quit()
	return false


var _bichos_list: Array = []


func _bichos() -> bool:
	var p = _level.player if _level else null
	if p == null:
		return false
	if _n == 30:
		p.invuln_time = 999.0
		var ens := [["moth", Vector2(-40, -26)], ["ash_knight", Vector2(40, -2)], ["gust", Vector2(90, -20)]]
		for e in ens:
			var en = load("res://scripts/actors/enemy.gd").new()
			en.setup(e[0], 2)
			en.position = p.global_position + e[1]
			en.level = _level
			p.get_parent().add_child(en)
			_bichos_list.append(en)
	if _n > 30:
		p._idle_t = 0.0
		for en in _bichos_list:
			if is_instance_valid(en):
				en.hp = en.max_hp()
	if _n in [70, 110, 150, 190, 230, 270]:
		var img := root.get_texture().get_image()
		var sc := float(img.get_width()) / 320.0
		var at: Vector2 = _level.pixel_view.world_to_screen(p.global_position + Vector2(20, -14)) * sc
		var sz := Vector2(200, 90) * sc
		var r := Rect2i(Vector2i((at - sz * 0.5).round()), Vector2i(sz.round())).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(r).save_png("%s_b%d.png" % [_out, _n])
	if _n > 275:
		quit()
	return false


var _boss_en: Node = null


func _chefe() -> bool:
	var p = _level.player if _level else null
	if p == null:
		return false
	var args := OS.get_cmdline_user_args()
	var gid: String = args[2] if args.size() > 2 else "golem_guardian"
	if _n == 30:
		p.invuln_time = 999.0
		# o maior trecho de chão plano da sala: o degrau do treino tapava a
		# linha de visão e o inimigo ficava em "patrol"
		var spot := _flat_floor(p.global_position)
		p.global_position = spot
		p._prev_pos = spot
		p.velocity = Vector2.ZERO
		p.reset_physics_interpolation()
		var en = load("res://scripts/actors/enemy.gd").new()
		en.setup(gid, 2)
		en.position = spot + Vector2(60, -40 if DB_flying(gid) else -4)
		en.level = _level
		en.set_meta("room", _level._room_at(p.global_position))
		p.get_parent().add_child(en)
		_boss_en = en
	if _n > 30:
		p.invuln_time = 999.0
		p._idle_t = 0.0
		if _boss_en and is_instance_valid(_boss_en):
			_boss_en.hp = maxf(_boss_en.hp, _boss_en.max_hp() * 0.45)
	if _n > 30 and _n % 25 == 0 and _n <= 330:
		_save("c%03d_%s" % [_n, _boss_en.ai_state if _boss_en and is_instance_valid(_boss_en) else "?"])
	if _n > 335:
		quit()
	return false


## Começo (com folga de 3 tiles) do maior trecho de chão plano e livre da sala
## em que o herói está; o inimigo nasce 60 px à direita, no mesmo nível.
func _flat_floor(from: Vector2) -> Vector2:
	var T := 8
	var rows: PackedStringArray = _level.layout["rows"]
	var r: Rect2 = _level.room_rect(_level._room_at(from))
	var best := from
	var best_len := 0
	for ty in range(int(r.position.y / T) + 3, int(r.end.y / T) - 1):
		var run := 0
		for tx in range(int(r.position.x / T) + 1, int(r.end.x / T) - 1):
			var free: bool = rows[ty][tx] != "#" and rows[ty - 1][tx] != "#" and rows[ty - 2][tx] != "#"
			if free and rows[ty + 1][tx] == "#":
				run += 1
				if run > best_len:
					best_len = run
					best = Vector2((tx - run + 1 + 3) * T + 4, (ty + 1) * T)
			else:
				run = 0
	return best


func DB_flying(gid: String) -> bool:
	return bool(root.get_node("DB").enemy(gid).get("flying", false))


func _loja(game: Node) -> bool:
	var hud: Node = _ow.hud
	if _n == 30:
		game.profile["currency"] = 480
		game.profile["items"]["fragmento_runico"] = 1
	var by_service := {}
	for npc in game.social.get("npcs", {}).values():
		for sv in npc.get("services", []):
			if not by_service.has(sv):
				by_service[sv] = npc["id"]
	var steps := [[40, "dialogo", "shop"], [55, "loja", "shop"], [70, "forja", "upgrade_weapon"], [85, "estudo", "upgrade_spell"], [100, "venda", "fence"]]
	for st in steps:
		if _n == st[0]:
			var id: String = by_service.get(st[2], "")
			if id == "":
				continue
			match st[1]:
				"dialogo": hud.open_dialogue(id)
				"loja": hud.open_shop(id, false)
				"forja": hud.open_forge(id)
				"estudo": hud.open_study(id)
				"venda": hud.open_sell(id)
		if _n == st[0] + 8:
			_save(st[1])
	if _n > 112:
		quit()
	return false


var _dark_lamps: Array = []


func _sombria() -> bool:
	var p = _level.player if _level else null
	if p == null:
		return false
	if _n == 20:
		var idx := -1
		for r in _level.layout["rooms"]:
			if r.get("dark", false):
				idx = int(r["index"])
		for n in _level.entities.get_children():
			if n.get_script() and str(n.get_script().resource_path).ends_with("lamparina.gd") and n.room_index == idx:
				_dark_lamps.append(n)
		if _dark_lamps.is_empty():
			quit()
			return false
		p.invuln_time = 999.0
		p.global_position = _dark_lamps[0].global_position + Vector2(-40, 0)
		p._prev_pos = p.global_position
		p.reset_physics_interpolation()
	if _n == 110:
		_save("0_apagada")
	if _n == 120:
		p.global_position = _dark_lamps[0].global_position
		p._prev_pos = p.global_position
		p.reset_physics_interpolation()
	if _n == 200:
		_save("1_uma_acesa")
	if _n == 210:
		for l in _dark_lamps:
			l.light_up()
	if _n == 320:
		_save("2_todas_acesas")
		quit()
	return false
