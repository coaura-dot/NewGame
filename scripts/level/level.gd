class_name Level
extends Node2D
## Fase jogável de uma região: gera (LevelGenerator), constrói (LevelBuilder),
## popula entidades, controla salas trancadas, checkpoints, chefes, drops,
## morte/renascimento e a conclusão da região.

const T := LevelConst.TILE

var region_id: String = ""
var region: Dictionary = {}
var params: Dictionary = {}
var layout: Dictionary = {}
var biome: Dictionary = {}
var dimension: Dictionary = {}
var training: bool = false
var siege: bool = false
## Mundo contínuo: a fase tem portões nas bordas que levam às vizinhas
var world_mode: bool = false
var came_from: String = ""
var arrive_at: String = ""
var _ports: Array = [] ## [{dir, to, requires, rect (gatilho), room_rect}]
var _leaving: bool = false
var _entry_boost: bool = false
var map_screen: Node = null

var player: Player
var camera: GameCamera
var entities: Node2D
var hud: Node
var pause_menu: Node
var postfx: PostFX
var checkpoint: Node = null
var spawn_pos: Vector2 = Vector2.ZERO
var boss_defeated: bool = false
var boss_node: Node = null
var result: Dictionary = {"completed": false, "boss_killed": false, "puzzles": 0, "kills": 0}

var _room_index_by_cell: Dictionary = {}
var _room_enemies: Dictionary = {} ## room -> Array[Enemy]
var _room_gates: Dictionary = {} ## room -> Array[Gate]
var _room_levers_pulled: Dictionary = {}
var _current_room: int = -1
var _cleared: Dictionary = {}
## Encontro trancado em andamento (para a nota S/A/B/C): sala, início, vida, inimigos
var _encounter: Dictionary = {}
## Arenas: ondas ainda não invocadas. sala -> Array[Array[entidade]]
var _waves: Dictionary = {}
var _wave_total: Dictionary = {}
var _completed: bool = false
var rng := RandomNumberGenerator.new()
## O mundo é renderizado aqui dentro (256x144, pixel perfeito) e escalado
## para a janela; HUD e menus ficam fora, nítidos.
var world_vp: SubViewport
var world: Node2D
## Exibição do mundo na janela (o zoom de impacto escala isto pelo centro)
var world_display: SubViewportContainer


func _ready() -> void:
	_resolve_params()
	var lib := ChunkLibrary.new()
	layout = LevelGenerator.generate(params, lib, DB)
	biome = DB.biome(params["biome"])
	dimension = DB.dimension(params.get("dimension", "prima"))
	rng.seed = int(params.get("seed", 1)) + 99
	_make_viewport()
	_build_world()
	_spawn_entities()
	_setup_ports()
	_spawn_player()
	if _entry_boost:
		player.velocity.y = -Player.JUMP_SPEED * 1.2
	if world_mode:
		Game.record_map(region_id, layout)
	_build_layers()
	Events.player_died.connect(_on_player_died)
	Music.play_ambience(str(biome.get("ambience", "")))
	Audio.set_space(str(biome.get("space", "open")))
	Events.room_entered.emit({"index": 0})
	if not training:
		Events.toast.emit(region.get("name", ""))


func _resolve_params() -> void:
	var pending: Dictionary = Game.pending
	Game.pending = {}
	training = pending.get("training", false)
	siege = pending.get("siege", false)
	if not Game.has_game and not training:
		Game.new_game(4242)
	if training:
		Game.setup_training_profile()
		params = {
			"seed": 20260926, "biome": "castelo", "tier": 1, "boss": "duelist", "hub": "",
			"dimension": "prima", "npcs": [], "abilities": Game.profile["abilities"],
			"force_path": ["entrance", "corridor", "platforming", "combat", "shaft", "puzzle", "challenge", "combat", "boss", "exit"],
		}
		region = {"name": "Salão de Treino", "biome": "castelo", "tier": 1}
		var arena: String = pending.get("arena", "")
		if arena != "":
			params["boss"] = arena
			params["tier"] = 2
			params["force_path"] = ["entrance", "boss", "exit"]
			params["no_branches"] = true
			region = {"name": "Arena: " + str(DB.enemy(arena).get("name", arena)), "biome": "castelo", "tier": 2}
		return
	region_id = pending.get("region", Game.profile.get("region", Game.world.get("start", "")))
	region = Game.world["regions"].get(region_id, {})
	var npc_ids: Array = []
	for npc in Game.social.get("npcs", {}).values():
		if npc["region"] == region_id and npc["alive"]:
			npc_ids.append(npc["id"])
	npc_ids.sort()
	var rift := ""
	for e in Game.world.get("edges", []):
		if e["kind"] == "rift" and e["a"] == region_id:
			rift = e["b"]
		elif e["kind"] == "rift" and e["b"] == region_id:
			rift = e["a"] # mundo paralelo: fenda de volta
	world_mode = true
	came_from = str(pending.get("from", ""))
	arrive_at = str(pending.get("at", ""))
	params = {
		"ports": WorldGenerator.ports(Game.world, region_id),
		"seed": int(region.get("level_seed", 1)),
		"biome": region.get("biome", "castelo"),
		"tier": int(region.get("tier", 1)) + (1 if siege else 0),
		"boss": region.get("boss", "") if not region.get("cleared", false) or siege else "",
		"hub": region.get("hub", ""),
		"dimension": region.get("dimension", "prima"),
		"npcs": npc_ids,
		"abilities": Game.profile.get("abilities", []),
		"rift": rift,
	}
	if siege:
		params["boss"] = "archdemon"


func _make_viewport() -> void:
	var holder := CanvasLayer.new()
	holder.layer = 0
	add_child(holder)
	var svc := SubViewportContainer.new()
	svc.stretch = false
	svc.size = LevelConst.VIEW
	svc.pivot_offset = LevelConst.VIEW * 0.5
	svc.position = LevelConst.VIEW * (LevelConst.VIEW_SCALE - 1.0) * 0.5
	svc.scale = Vector2.ONE * LevelConst.VIEW_SCALE
	world_display = svc
	# filtro linear + shader "pixel nítido": pixels quadrados em qualquer escala
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var conv := ShaderMaterial.new()
	conv.shader = preload("res://shaders/linear_to_srgb.gdshader")
	svc.material = conv
	holder.add_child(svc)
	world_vp = SubViewport.new()
	world_vp.size = Vector2i(LevelConst.VIEW)
	world_vp.use_hdr_2d = true
	world_vp.snap_2d_transforms_to_pixel = true
	world_vp.snap_2d_vertices_to_pixel = true
	world_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_vp.handle_input_locally = false
	svc.add_child(world_vp)
	world = Node2D.new()
	world.name = "World"
	world_vp.add_child(world)


func _build_world() -> void:
	var ambient_a: Array = biome.get("ambient", [0.5, 0.5, 0.6])
	# visual limpo: ambiente claro, luzes só realçam
	var ambient := Color(ambient_a[0], ambient_a[1], ambient_a[2]).lerp(Color.WHITE, 0.7)
	if dimension.get("rules", []).has("low_light"):
		ambient *= 0.75
	var cm := CanvasModulate.new()
	cm.color = ambient
	world.add_child(cm)
	var built := LevelBuilder.build(world, layout, biome)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.z_index = 5
	world.add_child(entities)
	FX.effects_root = entities
	for r in layout["rooms"]:
		var o: Array = r["origin"]
		_room_index_by_cell[Vector2i(int(o[0]) / LevelConst.ROOM_W, int(o[1]) / LevelConst.ROOM_H)] = int(r["index"])


func _tile_feet(tile: Array) -> Vector2:
	return Vector2(int(tile[0]) * T + T * 0.5, (int(tile[1]) + 1) * T)


func _tile_center(tile: Array) -> Vector2:
	return Vector2(int(tile[0]) * T + T * 0.5, int(tile[1]) * T + T * 0.5)


func _tile_corner(tile: Array) -> Vector2:
	return Vector2(int(tile[0]) * T, int(tile[1]) * T)


func _spawn_entities() -> void:
	var tier: int = int(params.get("tier", 1))
	var torch_a: Array = biome.get("torch", [1.8, 0.9, 0.4])
	var torch_color := Color(torch_a[0], torch_a[1], torch_a[2])
	var tex: Texture2D = load("res://assets/art/tilesets/%s.png" % biome.get("tileset", "castle"))
	var tint_a: Array = biome.get("tint", [1, 1, 1])
	var arena_ents: Dictionary = {}
	for e in layout["entities"]:
		var room: int = int(e.get("room", 0))
		var data: Dictionary = e.get("data", {})
		var node: Node2D = null
		if e["type"] in ["enemy", "flyer"] and _room_type(room) == "arena":
			if not arena_ents.has(room):
				arena_ents[room] = []
			arena_ents[room].append(e)
			continue
		match e["type"]:
			"spawn":
				spawn_pos = _tile_feet(e["tile"])
			"exit":
				var d := ExitDoor.new()
				node = d
				d.position = _tile_feet(e["tile"])
			"enemy", "flyer", "boss":
				var id: String = data.get("enemy", "skeleton")
				node = _make_enemy(id, tier, _tile_feet(e["tile"]) if e["type"] == "enemy" else _tile_center(e["tile"]), room)
				if e["type"] == "boss":
					boss_node = node
			"chest":
				var c := Chest.new()
				c.loot = data.get("loot", "")
				c.position = _tile_feet(e["tile"])
				node = c
			"key":
				var p := Pickup.new()
				p.item_id = data.get("item", "chave_ferro")
				p.position = _tile_center(e["tile"])
				node = p
			"dash_crystal":
				var dc := DashCrystal.new()
				dc.position = _tile_center(e["tile"])
				node = dc
			"jump_pad":
				var jp := JumpPad.new()
				jp.position = _tile_feet(e["tile"])
				node = jp
			"saw":
				var s := Saw.new()
				s.position = _tile_center(e["tile"])
				if rng.randf() < 0.5:
					s.travel = Vector2(rng.randf_range(-48, 48), rng.randf_range(-24, 24))
				node = s
			"torch":
				var t := Torch.new()
				t.color = torch_color
				t.position = _tile_center(e["tile"])
				node = t
			"light_shaft":
				var ls := LightShaft.new()
				var pos := _tile_corner(e["tile"]) + Vector2(T * 0.5, 0)
				ls.position = pos
				ls.setup(Color(1.3, 1.25, 1.1), _shaft_height(e["tile"]), 26.0)
				entities.add_child(ls)
			"gate":
				var g := Gate.new()
				g.mode = data.get("mode", "combat")
				g.room_index = room
				g.position = _tile_corner(e["tile"])
				node = g
				if not _room_gates.has(room):
					_room_gates[room] = []
				_room_gates[room].append(g)
			"lever":
				var lv := Lever.new()
				lv.room_index = room
				lv.position = _tile_feet(e["tile"])
				node = lv
			"npc":
				var n := NPCEntity.new()
				n.npc_id = data.get("npc", "")
				n.position = _tile_feet(e["tile"])
				node = n
			"checkpoint":
				var cp := Checkpoint.new()
				cp.position = _tile_feet(e["tile"])
				node = cp
			"falling_platform":
				var fp := FallingPlatform.new()
				fp.position = _tile_corner(e["tile"]) + Vector2(T * 0.5, 0)
				node = fp
			"relic":
				var rp := RelicPedestal.new()
				rp.loot = data.get("loot", "centelha")
				rp.position = _tile_feet(e["tile"])
				node = rp
			"quest_board":
				var qb := QuestBoard.new()
				qb.position = _tile_feet(e["tile"])
				node = qb
			"rift":
				var rf := RiftPortal.new()
				rf.target_region = data.get("region", "")
				rf.position = _tile_feet(e["tile"])
				node = rf
			"altar":
				var al := BossAltar.new()
				al.boss_id = params.get("boss", "") if params.get("boss", "") != "" else region.get("boss", "")
				al.position = _tile_feet(e["tile"])
				node = al
			"impeto_orb":
				var orb := ImpetoOrb.new()
				orb.position = _tile_center(e["tile"])
				node = orb
			"ability_gate":
				var ag := AbilityGate.new()
				ag.requires_item = data.get("requires", "") if data.get("kind", "") == "locked" else ""
				ag.requires_ability = data.get("ability", "") if data.get("kind", "") == "ability" else ""
				if ag.requires_item == "" and ag.requires_ability == "":
					ag.requires_item = "chave_ferro"
				ag.position = _tile_corner(e["tile"])
				node = ag
			"breakable", "cracked_floor":
				var b := BreakableWall.new()
				b.pound_only = e["type"] == "cracked_floor"
				b.tile_tex = tex
				b.tint = Color(tint_a[0], tint_a[1], tint_a[2])
				b.position = _tile_corner(e["tile"])
				node = b
		if node:
			if "level" in node:
				node.level = self
			if "room_index" in node:
				node.room_index = room
			entities.add_child(node)
	# arenas: 1ª onda já está lá; as outras entram quando a anterior cair
	for room in arena_ents.keys():
		var list: Array = arena_ents[room]
		var n := list.size()
		var count := 1 if n <= 3 else (2 if n <= 6 else 3)
		var waves: Array = []
		for w in count:
			waves.append([])
		for i in n:
			waves[mini(i * count / n, count - 1)].append(list[i])
		for e in waves.pop_front():
			entities.add_child(_enemy_from_entity(e, tier))
		_waves[room] = waves
		_wave_total[room] = count


func _room_type(idx: int) -> String:
	if idx < 0 or idx >= layout["rooms"].size():
		return ""
	return str(layout["rooms"][idx].get("type", ""))


func _enemy_from_entity(e: Dictionary, tier: int) -> Enemy:
	var id: String = e.get("data", {}).get("enemy", "skeleton")
	var pos := _tile_feet(e["tile"]) if e["type"] == "enemy" else _tile_center(e["tile"])
	return _make_enemy(id, tier, pos, int(e.get("room", 0)))


## Invoca a próxima onda da arena (portais primeiro, inimigos logo depois).
func _next_wave(room: int) -> void:
	var wave: Array = _waves[room].pop_front()
	var total: int = int(_wave_total.get(room, 1))
	var num: int = total - _waves[room].size()
	Events.wave_started.emit(num, total)
	Audio.play("wave", 0.0, -2.0)
	var tier: int = int(params.get("tier", 1))
	for e in wave:
		var en := _enemy_from_entity(e, tier)
		var portal := SpawnPortal.new()
		portal.position = en.position
		entities.add_child(portal)
		en.visible = false
		en.process_mode = Node.PROCESS_MODE_DISABLED
		entities.add_child(en)
		var tw := create_tween()
		tw.tween_interval(0.35)
		tw.tween_callback(func():
			if is_instance_valid(en):
				en.visible = true
				en.process_mode = Node.PROCESS_MODE_INHERIT
				en.ai_state = "spawn"
				en.ai_t = 0.35
				en.invuln_time = 0.35
				FX.burst(en.body_center(), Color(2.4, 0.8, 1.8), 8, 90.0))


## Gatilhos dos portões (fora da borda da sala de passagem) e ponto de
## chegada: vindo da região X, nasce no portão que leva a X.
func _setup_ports() -> void:
	for pt in layout.get("ports", []):
		var r := room_rect(int(pt["room"]))
		var trig := Rect2()
		match str(pt["dir"]):
			"L": trig = Rect2(r.position.x - 400.0, r.position.y, 400.0 + 1.0, r.size.y)
			"R": trig = Rect2(r.end.x - 1.0, r.position.y, 400.0, r.size.y)
			"U": trig = Rect2(r.position.x, r.position.y - 400.0, r.size.x, 400.0 + 4.0)
			"D": trig = Rect2(r.position.x, r.end.y + 2.0, r.size.x, 400.0)
		_ports.append({"dir": pt["dir"], "to": pt["to"], "requires": pt.get("requires", ""), "rect": trig, "room_rect": r})
		if came_from != "" and pt["to"] == came_from:
			spawn_pos = _port_spawn(str(pt["dir"]), r)
			_entry_boost = str(pt["dir"]) == "D"
	if came_from == "" and arrive_at == "shrine":
		# santuário preferido: entrada > vila > passagem > qualquer um
		var best := -1
		var best_rank := 99
		for e in layout["entities"]:
			if e["type"] == "checkpoint":
				var rank := ["entrance", "hub", "passage"].find(_room_type(int(e.get("room", 0))))
				rank = 50 if rank < 0 else rank
				if rank < best_rank:
					best_rank = rank
					best = layout["entities"].find(e)
		if best >= 0:
			spawn_pos = _tile_feet(layout["entities"][best]["tile"]) + Vector2(10, 0)
	elif came_from == "" and arrive_at == "rift":
		for e in layout["entities"]:
			if e["type"] == "rift":
				spawn_pos = _tile_feet(e["tile"]) + Vector2(14, 0)
				break


func _port_spawn(dir: String, r: Rect2) -> Vector2:
	match dir:
		"L": return Vector2(r.position.x + 3 * T, r.position.y + LevelConst.FLOOR_ROW * T)
		"R": return Vector2(r.end.x - 3 * T, r.position.y + LevelConst.FLOOR_ROW * T)
		"U": return Vector2(r.position.x + 20 * T, r.position.y + 4 * T)
		"D": return Vector2(r.position.x + 20 * T, r.position.y + 23 * T)
	return spawn_pos


## Saiu por um portão: escurece e carrega a região vizinha.
func _leave_by(pt: Dictionary) -> void:
	if _leaving:
		return
	_leaving = true
	player.set_physics_process(false)
	# região sem chefe fica concluída ao ser atravessada
	if not region.get("cleared", false) and str(region.get("boss", "")) == "" and pt["to"] != came_from:
		complete_level()
	Game.save()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(postfx, "fade", 1.0, 0.25)
	tw.tween_callback(func(): Game.travel(str(pt["to"]), region_id))


func _shaft_height(tile: Array) -> float:
	var x := int(tile[0])
	var y := int(tile[1]) + 1
	var rows: PackedStringArray = layout["rows"]
	var n := 0
	while y < rows.size() and n < 18 and rows[y][x] != "#":
		y += 1
		n += 1
	return maxf(n * T, 48.0)


func _make_enemy(id: String, tier: int, pos: Vector2, room: int) -> Enemy:
	var en := Enemy.new()
	en.setup(id, tier, params.get("dimension", "prima"))
	en.position = pos
	en.level = self
	en.set_meta("room", room)
	if not _room_enemies.has(room):
		_room_enemies[room] = []
	_room_enemies[room].append(en)
	return en


func _spawn_player() -> void:
	player = Player.new()
	player.level = self
	player.position = spawn_pos
	entities.add_child(player)
	camera = GameCamera.new()
	camera.target = player
	world.add_child(camera)
	camera.set_bounds(Rect2(0, 0, layout["width"] * T, layout["height"] * T))
	_focus_camera_on_player()
	camera.make_current()
	var amb := AmbientParticles.new()
	amb.setup(biome.get("particles", "dust"), camera)
	world.add_child(amb)


func _build_layers() -> void:
	var bg := BackgroundLayer.new()
	var ambient_a: Array = biome.get("ambient", [0.5, 0.5, 0.6])
	var tint_a: Array = biome.get("tint", [1, 1, 1])
	var bg_tint := Color(tint_a[0], tint_a[1], tint_a[2]) * Color(ambient_a[0] * 1.5, ambient_a[1] * 1.5, ambient_a[2] * 1.5)
	bg.camera = camera
	bg.build(str(biome.get("scenery", "forest")), Color.WHITE, 0.0)
	world.add_child(bg)
	postfx = PostFX.new()
	postfx.camera = camera
	postfx.player = player
	postfx.build(world, dimension, biome.get("tags", []).has("outdoor"))
	world.add_child(postfx)
	hud = load("res://scripts/ui/hud.gd").new()
	hud.level = self
	add_child(hud)
	pause_menu = load("res://scripts/ui/pause_menu.gd").new()
	pause_menu.level = self
	add_child(pause_menu)
	if world_mode:
		map_screen = load("res://scripts/ui/map_screen.gd").new()
		map_screen.level = self
		add_child(map_screen)


# ---------------------------------------------------------------------------
# Loop: salas, trancas, chefe
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if world_display:
		world_display.scale = Vector2.ONE * LevelConst.VIEW_SCALE * (1.0 + FX.zoom)


func _physics_process(_delta: float) -> void:
	if player == null or player.dead:
		return
	if world_mode and not _leaving:
		var pp: Vector2 = player.global_position
		for pt in _ports:
			if (pt["rect"] as Rect2).has_point(pp):
				_leave_by(pt)
				return
	var idx := room_at(player.global_position)
	if idx != _current_room and idx >= 0:
		var prev := _current_room
		_current_room = idx
		# subiu pela saída de cima: renova o pulo para pousar na sala nova
		if prev >= 0 and room_rect(idx).position.y < room_rect(prev).position.y:
			player.transition_boost()
		_on_room_entered(idx)
	if player.global_position.y > layout["height"] * T + 32:
		player.take_status_damage(10.0, "fall")
		if not player.dead:
			player._hazard_respawn()


func _on_room_entered(idx: int) -> void:
	var room: Dictionary = layout["rooms"][idx]
	if world_mode:
		Game.mark_explored(region_id, idx)
	Events.room_entered.emit(room)
	Music.play(_music_for_room(room))
	if _cleared.has(idx):
		return
	var alive := _alive_enemies(idx)
	if alive > 0:
		var locked := false
		for g in _room_gates.get(idx, []):
			if g.mode == "combat":
				g.set_closed(true)
				locked = true
		if locked and player:
			player.emote("!", 0.8)
			camera.lock_room(room_rect(idx))
			var total := alive
			for w in _waves.get(idx, []):
				total += w.size()
			_encounter = {"room": idx, "t0": Time.get_ticks_msec(), "hp": player.hp, "count": total}
		if room.get("type", "") == "boss" and boss_node and is_instance_valid(boss_node):
			if hud and hud.has_method("show_boss"):
				hud.show_boss(boss_node)
	else:
		_mark_cleared(idx)


## Retângulo (em pixels) da sala `idx`.
func room_rect(idx: int) -> Rect2:
	var o: Array = layout["rooms"][idx]["origin"]
	return Rect2(int(o[0]) * T, int(o[1]) * T, LevelConst.ROOM_W * T, LevelConst.ROOM_H * T)


func room_at(pos: Vector2) -> int:
	var cell := Vector2i(int(pos.x) / (LevelConst.ROOM_W * T), int(pos.y - Player.TRANSITION_PROBE) / (LevelConst.ROOM_H * T))
	return _room_index_by_cell.get(cell, -1)


## Centraliza a câmera no jogador, sem transição (nascer/renascer/teleporte).
## Se ele estiver numa arena trancada, a câmera fica presa nela.
func _focus_camera_on_player() -> void:
	var idx := room_at(player.global_position)
	if idx >= 0 and _room_locked(idx):
		camera.lock_room(room_rect(idx), true)
	else:
		camera.room_rect = Rect2()
	camera.snap()


## Sala trancada agora (portas de combate fechadas / chefe vivo)?
func _room_locked(idx: int) -> bool:
	if _cleared.has(idx):
		return false
	for g in _room_gates.get(idx, []):
		if g.mode == "combat" and g.closed:
			return true
	return false


## Último inimigo vivo de um encontro trancado (arena/chefe)? Câmera lenta.
func is_last_enemy(en: Node) -> bool:
	var room: int = int(en.get_meta("room", -1))
	if room < 0 or not _room_locked(room) or not _waves.get(room, []).is_empty():
		return false
	for other in _room_enemies.get(room, []):
		if other != en and is_instance_valid(other) and not other.dead:
			return false
	return true


## Trilha da sala: chefe vivo > Cerco > vila (hub) > mundo paralelo > bioma.
func _music_for_room(room: Dictionary) -> String:
	if room.get("type", "") == "boss" and boss_node and is_instance_valid(boss_node) and not boss_node.dead:
		return "chefe"
	if siege:
		return "cerco"
	if room.get("type", "") == "hub":
		return "vila"
	if params.get("dimension", "prima") != "prima":
		return "dimensao"
	return str(biome.get("music", "castelo"))


func _alive_enemies(idx: int) -> int:
	var n := 0
	for en in _room_enemies.get(idx, []):
		if is_instance_valid(en) and not en.dead:
			n += 1
	return n


func _mark_cleared(idx: int) -> void:
	if _cleared.has(idx):
		return
	_cleared[idx] = true
	for g in _room_gates.get(idx, []):
		if g.mode == "combat":
			g.set_closed(false)
	if camera and player and room_at(player.global_position) == idx:
		camera.unlock_room()
	if int(_encounter.get("room", -1)) == idx:
		_rank_encounter()
	Events.room_cleared.emit(layout["rooms"][idx])


## Nota do encontro trancado: rápido e sem apanhar = S. Dá brasas de bônus.
func _rank_encounter() -> void:
	var secs := (Time.get_ticks_msec() - int(_encounter["t0"])) / 1000.0
	var par := 2.0 + 2.2 * float(_encounter["count"])
	var hurt: bool = player and player.hp < float(_encounter["hp"]) - 0.5
	var score := secs / par
	var rank := "C"
	if score <= 0.65 and not hurt:
		rank = "S"
	elif score <= 0.95:
		rank = "A"
	elif score <= 1.5:
		rank = "B"
	var bonus := int({"S": 30, "A": 15, "B": 6, "C": 0}[rank] * (1.0 + 0.5 * (int(params.get("tier", 1)) - 1)))
	_encounter = {}
	if bonus > 0 and player:
		spawn_currency(bonus, player.body_center() + Vector2(0, -10))
	result["ranks"] = result.get("ranks", []) + [rank]
	Events.encounter_ranked.emit(rank, secs, bonus)
	Audio.play("rank_" + rank.to_lower(), 0.0, -1.0)


func on_enemy_killed(en: Node) -> void:
	result["kills"] = int(result["kills"]) + 1
	var pos: Vector2 = en.body_center()
	if en.get_meta("minion", false):
		spawn_currency(rng.randi_range(1, 2), pos)
	else:
		for id in en.roll_drops():
			spawn_pickup(id, pos, Vector2(rng.randf_range(-60, 60), -180))
		var cur: Array = en.data.get("currency", [2, 5])
		spawn_currency(rng.randi_range(int(cur[0]), int(cur[1])), pos)
		if rng.randf() < 0.06:
			spawn_pickup("pocao_vida", pos, Vector2(0, -150))
	if en == boss_node:
		boss_defeated = true
		result["boss_killed"] = true
		if world_mode and not training:
			get_tree().create_timer(2.0, true, false, true).timeout.connect(complete_level)
		FX.slowmo(0.2, 1.5)
		Events.toast.emit("%s derrotado!" % en.data.get("name", "Chefe"))
		Music.play(_music_for_room(layout["rooms"][maxi(_current_room, 0)]), 3.0)
		if hud and hud.has_method("hide_boss"):
			hud.hide_boss()
	var room: int = int(en.get_meta("room", -1))
	if room >= 0 and _alive_enemies(room) == 0 and not _waves.get(room, []).is_empty():
		_next_wave(room)
		return
	if room >= 0 and _alive_enemies(room) == 0 and room == _current_room:
		_mark_cleared(room)
	elif room >= 0 and _alive_enemies(room) == 0:
		_cleared.erase(room)
		_mark_cleared(room)


func respawn_boss(id: String, pos: Vector2) -> void:
	var room := _current_room
	_cleared.erase(room)
	boss_defeated = false
	var en := _make_enemy(id, int(params.get("tier", 1)) + 1, pos, room)
	boss_node = en
	entities.add_child(en)
	_on_room_entered(room)


func on_lever(room: int) -> void:
	_room_levers_pulled[room] = true
	result["puzzles"] = int(result["puzzles"]) + 1
	for g in _room_gates.get(room, []):
		if g.mode == "lever":
			g.set_closed(false)
	Events.toast.emit("Mecanismo ativado")


func set_checkpoint(cp: Node) -> void:
	if checkpoint and is_instance_valid(checkpoint) and checkpoint != cp:
		checkpoint.deactivate()
	checkpoint = cp
	Events.checkpoint_reached.emit(cp.global_position)
	if world_mode:
		Game.add_shrine(region_id)


# ---------------------------------------------------------------------------
# Drops
# ---------------------------------------------------------------------------

## Invocado por chefes de horda: entra na sala atual (as portas só abrem
## quando chefe e lacaios morrem). Lacaios dão poucas brasas e nenhum item.
func spawn_minion(id: String, tier: int, pos: Vector2) -> Enemy:
	var en := _make_enemy(id, tier, pos, _current_room)
	en.set_meta("minion", true)
	entities.add_child(en)
	return en


func spawn_pickup(id: String, pos: Vector2, vel: Vector2 = Vector2(0, -150)) -> void:
	var p := Pickup.new()
	p.item_id = id
	p.position = pos
	p.velocity = vel
	entities.call_deferred("add_child", p)


func spawn_currency(amount: int, pos: Vector2) -> void:
	var left := amount
	while left > 0:
		var chunk := mini(left, rng.randi_range(3, 10))
		left -= chunk
		var p := Pickup.new()
		p.currency = chunk
		p.position = pos
		p.velocity = Vector2(rng.randf_range(-90, 90), rng.randf_range(-220, -120))
		entities.call_deferred("add_child", p)


# ---------------------------------------------------------------------------
# Morte / conclusão
# ---------------------------------------------------------------------------

func _on_player_died(_p: Node) -> void:
	await get_tree().create_timer(1.6, true, false, true).timeout
	if not is_inside_tree():
		return
	var lost := int(int(Game.profile.get("currency", 0)) * 0.25)
	Game.profile["currency"] = int(Game.profile.get("currency", 0)) - lost
	if lost > 0:
		Events.toast.emit("Você perdeu %d brasas" % lost)
	var at := spawn_pos
	if checkpoint and is_instance_valid(checkpoint):
		at = checkpoint.global_position
	player.revive(at)
	_focus_camera_on_player()
	FX.clear_time_effects()


func complete_level() -> void:
	if _completed:
		return
	_completed = true
	result["completed"] = true
	var quests_done: Array = []
	if not training:
		Game.complete_region(region_id)
		quests_done = SocialSystem.resolve_quests_for_region(Game.social, region_id, Game.profile, result)
		Game.save()
	if world_mode and not siege:
		# mundo contínuo: continua jogando (sem sair da fase)
		if hud and hud.has_method("show_summary"):
			hud.show_summary(result, quests_done, false)
		return
	if hud and hud.has_method("show_summary"):
		hud.show_summary(result, quests_done)
	else:
		leave_level()


func leave_level() -> void:
	if training:
		Game.end_training()
		Game.goto(Game.SCENE_MENU)
	elif siege:
		Game.goto("res://scenes/ending.tscn")
	else:
		Game.enter_region(region_id)


func open_quest_board() -> void:
	if hud and hud.has_method("open_quests"):
		hud.open_quests(region_id)
