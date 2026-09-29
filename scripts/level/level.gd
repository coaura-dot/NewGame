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

var player: Player
var camera: GameCamera
var pixel_view: PixelView
var world: Node2D ## raiz do mundo (dentro da tela interna 320x180)
var entities: Node2D
var hud: Node
var pause_menu: Node
var checkpoint: Node = null
var spawn_pos: Vector2 = Vector2.ZERO
var boss_defeated: bool = false
var boss_node: Node = null
var result: Dictionary = {"completed": false, "boss_killed": false, "puzzles": 0, "kills": 0, "time": 0.0, "deaths": 0, "hits": 0}
## Renascimento rápido (estilo Celeste): morrer volta para a entrada da sala.
var room_spawn: Vector2 = Vector2.ZERO
var timer_running: bool = true

var _room_index_by_cell: Dictionary = {}
var _room_enemies: Dictionary = {} ## room -> Array[Enemy]
## Ondas das arenas: room -> Array[Array[Enemy]] (ainda fora da árvore)
var _room_waves: Dictionary = {}
var _room_gates: Dictionary = {} ## room -> Array[Gate]
var _room_levers_pulled: Dictionary = {}
var _current_room: int = -1
var _cleared: Dictionary = {}
var _completed: bool = false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	_resolve_params()
	var lib := ChunkLibrary.new()
	layout = LevelGenerator.generate(params, lib, DB)
	biome = DB.biome(params["biome"])
	dimension = DB.dimension(params.get("dimension", "prima"))
	rng.seed = int(params.get("seed", 1)) + 99
	pixel_view = PixelView.new()
	add_child(pixel_view)
	world = pixel_view.world
	_build_world()
	_spawn_entities()
	_setup_waves()
	_spawn_player()
	_build_layers()
	Events.player_died.connect(_on_player_died)
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
			"seed": int(pending.get("seed", 20260926)), "biome": str(pending.get("biome", "castelo")),
			"tier": int(pending.get("tier", 1)), "boss": "nightmare", "hub": "",
			"dimension": "prima", "npcs": [], "abilities": Game.profile["abilities"],
			"force_path": ["entrance", "platforming", "combat", "zigzag", "shaft", "combat", "challenge", "zigzag", "boss", "exit"],
			"theme": str(pending.get("theme", "")),
		}
		region = {"name": "Salão de Treino", "biome": params["biome"], "tier": params["tier"]}
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
	params = {
		"theme": region_theme(region),
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


## Tema da fase (derivado da seed da região): ~40% das fases são "Frenesi"
## (zigue-zague sobre espinhos com combate intercalado).
static func region_theme(r: Dictionary) -> String:
	if r.has("theme"):
		return str(r["theme"])
	if r.get("hub", "") != "":
		return ""
	return "frenesi" if int(r.get("level_seed", 0)) % 5 in [1, 3] else ""


func _build_world() -> void:
	# tela limpa: nada de escurecer a cena inteira. Só um leve tom em biomas
	# escuros / regra de pouca luz (as luzes então aparecem de leve).
	var dim_k := 1.0
	if biome.get("tags", []).has("dark"):
		dim_k = 0.9
	if dimension.get("rules", []).has("low_light"):
		dim_k *= 0.72
	if dim_k < 0.999:
		var cm := CanvasModulate.new()
		cm.color = Color(dim_k, dim_k, dim_k * 1.04)
		world.add_child(cm)
	LevelBuilder.build(world, layout, biome, params["biome"])
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
	var tex: Texture2D = TileSetBuilder.texture_for(params["biome"])
	for e in layout["entities"]:
		var room: int = int(e.get("room", 0))
		var data: Dictionary = e.get("data", {})
		var node: Node2D = null
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
				if data.has("travel"):
					var tv: Array = data["travel"]
					s.travel = Vector2(float(tv[0]) * T, float(tv[1]) * T)
					s.period = 1.4
				elif rng.randf() < 0.5:
					s.travel = Vector2(rng.randf_range(-24, 24), rng.randf_range(-12, 12)).round()
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
				ls.setup(Color(torch_color.r * 0.8, torch_color.g * 0.85, torch_color.b * 1.2 + 0.3), _shaft_height(e["tile"]), 28.0)
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
			"impulse_orb":
				var orb := ImpulseOrb.new()
				orb.position = _tile_center(e["tile"])
				node = orb
			"jump_feather":
				var jf := JumpFeather.new()
				jf.position = _tile_center(e["tile"])
				node = jf
			"reset_bell":
				var rb := ResetBell.new()
				rb.position = _tile_center(e["tile"])
				node = rb
			"double_crystal":
				var dc2 := DashCrystal.new()
				dc2.double = true
				dc2.position = _tile_center(e["tile"])
				node = dc2
			"turret":
				var tu := Turret.new()
				tu.dir = {"L": Vector2.LEFT, "R": Vector2.RIGHT, "U": Vector2.UP, "D": Vector2.DOWN}.get(data.get("dir", "L"), Vector2.LEFT)
				tu.phase = float(data.get("phase", 0.0))
				tu.period = 1.6 if tier <= 2 else 1.3
				tu.position = _tile_center(e["tile"])
				node = tu
			"moving_platform":
				var mp := MovingPlatform.new()
				var tr: Array = data.get("travel", [6, 0])
				mp.travel = Vector2(float(tr[0]) * T, float(tr[1]) * T)
				mp.width = float(data.get("width", 3)) * T
				mp.position = _tile_corner(e["tile"])
				node = mp
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
				b.position = _tile_corner(e["tile"])
				node = b
		if node:
			if "level" in node:
				node.level = self
			if "room_index" in node:
				node.room_index = room
			entities.add_child(node)


func _shaft_height(tile: Array) -> float:
	var x := int(tile[0])
	var y := int(tile[1]) + 1
	var rows: PackedStringArray = layout["rows"]
	var n := 0
	while y < rows.size() and n < 18 and rows[y][x] != "#":
		y += 1
		n += 1
	return maxf(n * T, 24.0)


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
	player.damaged.connect(func(_i, _a): result["hits"] = int(result["hits"]) + 1)
	camera = GameCamera.new()
	camera.target = player
	world.add_child(camera)
	camera.set_bounds(Rect2(0, 0, layout["width"] * T, layout["height"] * T))
	var idx := _room_at(player.global_position)
	if idx >= 0:
		camera.set_room(camera_rect(idx))
	camera.snap()
	pixel_view.camera = camera
	if Settings.video("ambient_particles"):
		var amb := AmbientParticles.new()
		amb.setup(biome.get("particles", "dust"))
		world.add_child(amb)


## Retângulo (em px) da sala de índice idx.
func room_rect(idx: int) -> Rect2:
	var o: Array = layout["rooms"][idx]["origin"]
	return Rect2(int(o[0]) * T, int(o[1]) * T, LevelConst.ROOM_W * T, LevelConst.ROOM_H * T)


## Área da câmera: a sala, ou o par inteiro se for uma sala larga (2 telas).
func camera_rect(idx: int) -> Rect2:
	var r := room_rect(idx)
	for gr in layout.get("groups", []):
		if gr.has(idx):
			for other in gr:
				r = r.merge(room_rect(int(other)))
	return r


func _room_at(pos: Vector2) -> int:
	var cell := Vector2i(int(floor(pos.x / (LevelConst.ROOM_W * T))), int(floor((pos.y - 4.0) / (LevelConst.ROOM_H * T))))
	return _room_index_by_cell.get(cell, -1)


func _build_layers() -> void:
	var bg := BackgroundLayer.new()
	bg.camera = camera
	bg.level_height = layout["height"] * T
	bg.build(params["biome"])
	world.add_child(bg)
	pixel_view.set_grade(dimension.get("grade", {}), biome.get("tags", []).has("outdoor"))
	hud = load("res://scripts/ui/hud.gd").new()
	hud.level = self
	add_child(hud)
	pause_menu = load("res://scripts/ui/pause_menu.gd").new()
	pause_menu.level = self
	add_child(pause_menu)


# ---------------------------------------------------------------------------
# Loop: salas, trancas, chefe
# ---------------------------------------------------------------------------

var _last_ms: int = 0


func _process(_delta: float) -> void:
	# tempo real (o que um speedrun mede), sem contar pausas
	var now := Time.get_ticks_msec()
	if _last_ms > 0 and timer_running and not _completed and not get_tree().paused:
		result["time"] = float(result["time"]) + float(now - _last_ms) / 1000.0
	_last_ms = now


func _physics_process(_delta: float) -> void:
	if player == null or player.dead:
		return
	var idx := _room_at(player.global_position)
	if idx != _current_room and idx >= 0:
		_current_room = idx
		camera.set_room(camera_rect(idx))
		_on_room_entered(idx)
	if player.global_position.y > layout["height"] * T + 32:
		player.take_status_damage(10.0, "fall")
		player._hazard_respawn()


func _on_room_entered(idx: int) -> void:
	var room: Dictionary = layout["rooms"][idx]
	Events.room_entered.emit(room)
	_update_room_spawn(idx)
	# desafio (caminho da dor): qualquer espinho volta ao começo da sala
	if player:
		player.hazard_spawn_override = room_spawn if room.get("type", "") == "challenge" else Vector2.ZERO
	_hints_for_room(idx)
	if room.get("type", "") != "boss" and hud and hud.has_method("hide_boss"):
		hud.hide_boss()
	_stop_chase()
	if PackedStringArray(room.get("tags", [])).has("chase") and not _chase_done.has(idx) and player:
		_start_chase(idx)
	if _cleared.has(idx):
		return
	var alive := _alive_enemies(idx)
	if alive > 0:
		for g in _room_gates.get(idx, []):
			if g.mode == "combat":
				g.set_closed(true)
		if room.get("type", "") == "boss" and boss_node and is_instance_valid(boss_node) and boss_node.is_inside_tree():
			if hud and hud.has_method("show_boss"):
				hud.show_boss(boss_node)
		if player and player.emote:
			player.emote.show_emote("!", 0.8)
	else:
		_mark_cleared(idx)


var _chase: ChaseWall = null
var _chase_room: int = -1
var _chase_done: Dictionary = {}


## Sala de fuga: a muralha nasce atrás da porta por onde o herói entrou.
func _start_chase(idx: int) -> void:
	var r := room_rect(idx)
	_chase = ChaseWall.new()
	_chase.rect = r
	_chase.dir = 1 if room_spawn.x < r.get_center().x else -1
	_chase.player = player
	entities.add_child(_chase)
	_chase_room = idx
	player.hazard_spawn_override = room_spawn
	player.emote.show_emote("!", 0.9, true)
	FX.shake(0.25)
	Audio.play("explosion", 0.1, -10.0, 0.6)


func _stop_chase() -> void:
	if _chase and is_instance_valid(_chase):
		_chase.queue_free()
		if player and not player.dead:
			_chase_done[_chase_room] = true
	_chase = null
	_chase_room = -1


const HINTS := {
	"impulse_orb": "Golpeie o ORBE DOURADO para quicar — recarrega dash e pulo!",
	"dash_crystal": "Toque no CRISTAL no ar para recuperar o dash.",
	"falling_platform": "Tábuas frágeis desabam: não pare em cima delas!",
	"moving_platform": "Suba na plataforma móvel — ela te leva junto.",
	"challenge": "Caminho da dor: tocar em espinho volta ao começo da sala.",
	"pogo": "Golpe para baixo no ar QUICA em espinhos e inimigos.",
	"waves": "Arena fechada: derrote todas as ondas para abrir.",
	"hunt": "Caçada: a sala só abre quando todos os inimigos caírem!",
	"chase": "FUJA! A muralha de espinhos avança — não pare de correr!",
	"zigzag": "Chão de espinhos! Encadeie orbes, pogos e inimigos sem pousar.",
	"jump_feather": "PENA VERDE: encoste no ar e ganhe mais um pulo!",
	"reset_bell": "SINO: golpeie para recarregar o dash e ganhar um pulo, sem perder a trajetória.",
	"double_crystal": "CRISTAL ROSA: dois dashes seguidos!",
	"turret": "Torretas atiram no ritmo. GOLPEIE a bala para rebater: recarrega o dash e a devolve!",
}


## Dicas de primeira vez (salvas no perfil: aparecem uma vez só).
func _hints_for_room(idx: int) -> void:
	var flags: Dictionary = Game.profile.get("flags", {})
	var seen: Dictionary = flags.get("hints", {})
	var room: Dictionary = layout["rooms"][idx]
	var want: Array = []
	for e in layout["entities"]:
		if int(e.get("room", -1)) == idx and HINTS.has(e["type"]):
			want.append(e["type"])
	if room.get("type", "") == "challenge":
		want.append("challenge")
		want.append("pogo")
	if _room_waves.has(idx):
		want.append("waves")
	if PackedStringArray(room.get("tags", [])).has("hunt"):
		want.push_front("hunt")
	if PackedStringArray(room.get("tags", [])).has("chase"):
		want.push_front("chase")
	if room.get("type", "") == "zigzag":
		want.push_front("zigzag")
	for k in want:
		if not seen.has(k):
			seen[k] = true
			Events.toast.emit(HINTS[k])
			break
	flags["hints"] = seen
	Game.profile["flags"] = flags


## Acha um chão firme perto da porta por onde o herói entrou na sala.
func _update_room_spawn(idx: int) -> void:
	if player == null:
		return
	var r := room_rect(idx)
	var p := player.global_position
	var d := {"L": p.x - r.position.x, "R": r.end.x - p.x, "U": p.y - r.position.y, "D": r.end.y - p.y}
	var best := "L"
	for k in d.keys():
		if float(d[k]) < float(d[best]):
			best = k
	var o: Array = layout["rooms"][idx]["origin"]
	var g := []
	for y in LevelConst.ROOM_H:
		var row := []
		var line: String = layout["rows"][int(o[1]) + y]
		for x in LevelConst.ROOM_W:
			row.append(line[int(o[0]) + x])
		g.append(row)
	var e := RoomReach.entry_point(g, best)
	if e.x < 0:
		room_spawn = player.last_safe_pos
		return
	# entra um pouco para dentro da sala (longe da borda)
	var dirx := 1 if best == "L" else (-1 if best == "R" else 0)
	for k in range(3, 0, -1):
		if dirx != 0 and RoomReach.standable(g, e.x + dirx * k, e.y):
			e.x += dirx * k
			break
	room_spawn = Vector2((int(o[0]) + e.x) * T + T * 0.5, (int(o[1]) + e.y + 1) * T)


func _exit_tree() -> void:
	# inimigos de ondas que nunca entraram na árvore
	for waves in _room_waves.values():
		for wave in waves:
			for en in wave:
				if is_instance_valid(en) and not en.is_inside_tree():
					en.free()
	_room_waves.clear()


func _alive_enemies(idx: int) -> int:
	var n := 0
	for en in _room_enemies.get(idx, []):
		if is_instance_valid(en) and not en.dead and en.is_inside_tree():
			n += 1
	return n


func _mark_cleared(idx: int) -> void:
	if _cleared.has(idx):
		return
	_cleared[idx] = true
	var had_fight := false
	for g in _room_gates.get(idx, []):
		if g.mode == "combat":
			if g.closed:
				had_fight = true
			g.set_closed(false)
	Events.room_cleared.emit(layout["rooms"][idx])
	# sala limpa: respiro em câmera lenta, recompensa pequena e comemoração
	if had_fight and player and not player.dead:
		FX.slowmo(0.35, 0.45)
		player.gain_focus(15.0)
		player.refill_dash()
		player.emote.show_emote("spark", 0.9, true)
		player.rig.set_expression("happy", 0.9)
		Audio.play("confirmation", 0.0, -6.0)


func on_enemy_killed(en: Node) -> void:
	result["kills"] = int(result["kills"]) + 1
	var pos: Vector2 = en.body_center()
	for id in en.roll_drops():
		spawn_pickup(id, pos, Vector2(rng.randf_range(-30, 30), -110))
	var cur: Array = en.data.get("currency", [2, 5])
	spawn_currency(rng.randi_range(int(cur[0]), int(cur[1])), pos)
	if rng.randf() < 0.06:
		spawn_pickup("pocao_vida", pos, Vector2(0, -90))
	if en == boss_node:
		boss_defeated = true
		result["boss_killed"] = true
		FX.slowmo(0.2, 1.5)
		Events.toast.emit("%s derrotado!" % en.data.get("name", "Chefe"))
		if hud and hud.has_method("hide_boss"):
			hud.hide_boss()
	var room: int = int(en.get_meta("room", -1))
	if room >= 0 and _alive_enemies(room) == 0 and not _room_waves.get(room, []).is_empty():
		_next_wave(room)
		return
	if room >= 0 and _alive_enemies(room) == 0 and room == _current_room:
		_mark_cleared(room)
	elif room >= 0 and _alive_enemies(room) == 0:
		_cleared.erase(room)
		_mark_cleared(room)


## Arenas que fecham: os inimigos vêm em ondas (2 no tier 1, até 3 depois).
func _setup_waves() -> void:
	var tier: int = int(params.get("tier", 1))
	for r in layout["rooms"]:
		var idx: int = int(r["index"])
		if r.get("type", "") == "boss":
			_setup_horde(idx)
			continue
		if r.get("type", "") != "combat" or not PackedStringArray(r.get("tags", [])).has("lock"):
			continue
		var list: Array = _room_enemies.get(idx, []).filter(func(e): return is_instance_valid(e) and e != boss_node)
		if list.size() < 3:
			continue
		var n_waves := mini(1 + tier, 3) if list.size() >= 5 else 2
		var per := int(ceil(float(list.size()) / n_waves))
		var waves: Array = []
		for w in range(1, n_waves):
			var wave: Array = list.slice(w * per, (w + 1) * per)
			if wave.is_empty():
				continue
			for en in wave:
				en.get_parent().remove_child(en)
			waves.append(wave)
		if not waves.is_empty():
			_room_waves[idx] = waves


## Chefe de horda: se a arena do chefe tem lacaios, eles vêm em ondas e o
## chefe entra sozinho na última.
func _setup_horde(idx: int) -> void:
	if boss_node == null or not is_instance_valid(boss_node):
		return
	var minions: Array = _room_enemies.get(idx, []).filter(func(e): return is_instance_valid(e) and e != boss_node)
	if minions.size() < 3:
		return
	var waves: Array = []
	var half := int(ceil(minions.size() / 2.0))
	var second: Array = minions.slice(half)
	for en in second:
		en.get_parent().remove_child(en)
	if not second.is_empty():
		waves.append(second)
	boss_node.get_parent().remove_child(boss_node)
	waves.append([boss_node])
	_room_waves[idx] = waves


func _next_wave(room: int) -> void:
	var wave: Array = _room_waves[room].pop_front()
	if _room_waves[room].is_empty():
		_room_waves.erase(room)
	Events.toast.emit("Mais inimigos!")
	FX.shake(0.15)
	if player and player.emote:
		player.emote.show_emote("!", 0.6, true)
	var delay := 0.0
	for en in wave:
		delay += 0.18
		var e: Enemy = en
		get_tree().create_timer(0.35 + delay, false).timeout.connect(func():
			if not is_inside_tree() or not is_instance_valid(e):
				return
			FX.burst(e.global_position + Vector2(0, -6), Color(2.0, 1.2, 2.4), 10, 70.0)
			FX.hit_spark(e.global_position + Vector2(0, -6), Vector2.UP, Color(2.2, 1.4, 2.6), true)
			entities.add_child(e)
			e.invuln_time = 0.4
			e.emote.show_emote("!", 0.6)
			if e == boss_node:
				FX.shake(0.5)
				FX.white_flash(0.3)
				Events.toast.emit(e.data.get("name", "Chefe"))
				if hud and hud.has_method("show_boss"):
					hud.show_boss(e))


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


# ---------------------------------------------------------------------------
# Drops
# ---------------------------------------------------------------------------

func spawn_pickup(id: String, pos: Vector2, vel: Vector2 = Vector2(0, -90)) -> void:
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
		p.velocity = Vector2(rng.randf_range(-45, 45), rng.randf_range(-130, -70))
		entities.call_deferred("add_child", p)


# ---------------------------------------------------------------------------
# Morte / conclusão
# ---------------------------------------------------------------------------

func _on_player_died(_p: Node) -> void:
	result["deaths"] = int(result["deaths"]) + 1
	await get_tree().create_timer(0.85, true, false, true).timeout
	if not is_inside_tree():
		return
	var lost := int(int(Game.profile.get("currency", 0)) * 0.1)
	Game.profile["currency"] = int(Game.profile.get("currency", 0)) - lost
	if lost > 0:
		Events.toast.emit("-%d brasas" % lost)
	var at := room_spawn if room_spawn != Vector2.ZERO else spawn_pos
	if at == Vector2.ZERO and checkpoint and is_instance_valid(checkpoint):
		at = checkpoint.global_position
	# chefe se recompõe quando o herói cai
	if boss_node and is_instance_valid(boss_node) and not boss_node.dead:
		boss_node.hp = boss_node.max_hp()
		boss_node.health_changed.emit(boss_node.hp, boss_node.max_hp())
	player.revive(at)
	var idx := _room_at(at)
	if idx >= 0:
		_current_room = idx
		camera.set_room(camera_rect(idx))
	camera.snap()
	FX.clear_time_effects()


func complete_level() -> void:
	if _completed:
		return
	_completed = true
	result["completed"] = true
	if player:
		result["best_chain"] = player.best_chain
	result["rank"] = rank_for(result, layout["rooms"].size())
	var quests_done: Array = []
	if not training:
		Game.complete_region(region_id)
		quests_done = SocialSystem.resolve_quests_for_region(Game.social, region_id, Game.profile, result)
		Game.save()
	if hud and hud.has_method("show_summary"):
		hud.show_summary(result, quests_done)
	else:
		leave_level()


## Nota da fase (perfeccionismo): tempo, mortes e dano sofrido.
static func rank_for(res: Dictionary, rooms: int) -> String:
	var par := float(rooms) * 18.0
	var score := 100.0
	score -= float(res.get("deaths", 0)) * 15.0
	score -= float(res.get("hits", 0)) * 3.0
	score -= maxf(float(res.get("time", 0.0)) - par, 0.0) * 0.4
	if score >= 90.0:
		return "S"
	if score >= 75.0:
		return "A"
	if score >= 55.0:
		return "B"
	return "C"


## Tempo no formato m:ss.cc
static func format_time(t: float) -> String:
	var m := int(t / 60.0)
	var sec := t - m * 60.0
	return "%d:%05.2f" % [m, sec]


func leave_level() -> void:
	if training:
		Game.end_training()
		Game.goto(Game.SCENE_MENU)
	elif siege:
		Game.goto("res://scenes/ending.tscn")
	else:
		Game.goto(Game.SCENE_MAP)


func open_quest_board() -> void:
	if hud and hud.has_method("open_quests"):
		hud.open_quests(region_id)
