class_name LevelGenerator
extends RefCounted
## Gera a camada MICRO de uma região (estilo Dead Cells): um caminho crítico
## de salas numa grade, ramos opcionais (tesouro, segredo, desafio, puzzle),
## salas seladas (chave / habilidade) e salas secretas atrás de paredes
## quebráveis. Cada sala vem de um template ASCII ou do RoomSynth.
##
## Parâmetros (Dictionary):
##   seed, biome, tier, boss (id do inimigo ou ""), hub (tipo ou ""),
##   dimension, npcs (ids), abilities (do jogador), force_path (tipos),
##   path_length, quest_objective
## Saída: {width, height, rows, rooms, entities, spawn, exit, ...}

const DIRS := {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "U": Vector2i(0, -1), "D": Vector2i(0, 1)}
const OPP := {"R": "L", "L": "R", "U": "D", "D": "U"}
## Mistura frenética: muito parkour e combate, pouca pausa.
const PATH_WEIGHTS := {"combat": 4.0, "platforming": 4.0, "corridor": 1.5, "puzzle": 0.7, "shaft": 1.2}
const BRANCH_WEIGHTS := {"treasure": 3.0, "secret": 2.0, "challenge": 2.5, "puzzle": 0.8, "combat": 1.0}
## Chance de uma sala de plataforma do caminho virar "caçada" (fecha até matar todos).
const HUNT_CHANCE := 0.3
## Chance de uma sala L-R do caminho (plataforma/corredor) virar fuga.
const CHASE_CHANCE := 0.2


static func generate(params: Dictionary, library: ChunkLibrary, db: Node) -> Dictionary:
	var seed_value: int = int(params.get("seed", 1))
	var rng := RngUtil.make(seed_value, "level")
	var tier: int = int(params.get("tier", 1))
	var biome_id: String = params.get("biome", "castelo")
	var biome: Dictionary = db.biome(biome_id)
	var indoor: bool = biome.get("tags", []).has("indoor")

	# 1) caminho crítico
	var length: int = int(params.get("path_length", 6 + tier * 2 + rng.randi_range(-1, 1)))
	var forced: Array = params.get("force_path", [])
	if not forced.is_empty():
		length = forced.size()
	var path := _walk(rng, length)
	var rooms := {} # Vector2i -> room
	var connections: Array = [] # {a, b, kind, data}
	for i in path.size():
		rooms[path[i]] = _room(path[i], "combat", true, i)
	for i in range(1, path.size()):
		connections.append({"a": path[i - 1], "b": path[i], "kind": "open"})

	# tipos no caminho
	var types: Array = []
	if not forced.is_empty():
		types = forced.duplicate()
	else:
		types.append("entrance")
		var hub: String = params.get("hub", "")
		for i in range(1, length - 1):
			var t: String = RngUtil.weighted_key(rng, PATH_WEIGHTS)
			if i == 1 and hub != "":
				t = "hub"
			elif types.size() > 0 and types[-1] == t and t != "combat":
				t = "combat"
			types.append(t)
		types.append("exit")
		if params.get("boss", "") != "" and length >= 3:
			types[length - 2] = "boss"
		# parkour em sequência horizontal: continua o mesmo tipo (vira sala larga)
		for i in range(2, length - 2):
			if types[i - 1] in ["platforming", "challenge"] and types[i] != "boss" and path[i].y == path[i - 1].y and rng.randf() < 0.5:
				types[i] = types[i - 1]
	for i in path.size():
		rooms[path[i]]["type"] = types[i]
		# salas verticais de verdade viram "shaft" se o caminho sobe/desce
		if i > 0 and i < path.size() - 1 and types[i] in ["corridor", "combat"]:
			var up_down: bool = path[i - 1].y != path[i].y or path[i + 1].y != path[i].y
			if up_down and rng.randf() < 0.4:
				rooms[path[i]]["type"] = "shaft"

	# 2) ramos opcionais
	var branch_count := rng.randi_range(2, 3) + (1 if tier >= 2 else 0)
	var key_needed := false
	var owned: Array = params.get("abilities", [])
	var gate_candidates: Array = []
	for ab_id in db.abilities.keys():
		var ab: Dictionary = db.abilities[ab_id]
		if ab.get("implemented", false) and not ab.get("start", false) and ab_id != "dimension_shift":
			gate_candidates.append(ab_id)
	gate_candidates.sort()
	for b in branch_count:
		var anchor: Vector2i = path[rng.randi_range(1, maxi(1, path.size() - 2))]
		var dirs := DIRS.keys()
		RngUtil.shuffle(rng, dirs)
		for d in dirs:
			var n: Vector2i = anchor + DIRS[d]
			if rooms.has(n):
				continue
			var t: String = RngUtil.weighted_key(rng, BRANCH_WEIGHTS)
			var room := _room(n, t, false, -1)
			rooms[n] = room
			var conn := {"a": anchor, "b": n, "kind": "open", "data": {}}
			if t == "secret":
				conn["kind"] = "secret"
			elif t == "treasure" and rng.randf() < 0.45:
				conn["kind"] = "locked"
				conn["data"] = {"requires": "chave_ferro"}
				key_needed = true
			elif t in ["challenge", "treasure"] and rng.randf() < 0.35 and not gate_candidates.is_empty():
				conn["kind"] = "ability"
				conn["data"] = {"ability": RngUtil.pick(rng, gate_candidates)}
			connections.append(conn)
			# ramo de 2 salas às vezes
			if rng.randf() < 0.35:
				var n2: Vector2i = n + DIRS[d]
				if not rooms.has(n2):
					rooms[n2] = _room(n2, room["type"], false, -1)
					room["type"] = "corridor" if t != "secret" else "secret"
					connections.append({"a": n, "b": n2, "kind": "open", "data": {}})
			break

	# 3) portal para mundo paralelo em algumas regiões
	if params.get("rift", "") != "":
		var anchor2: Vector2i = path[path.size() / 2]
		for d in DIRS.keys():
			var n: Vector2i = anchor2 + DIRS[d]
			if not rooms.has(n):
				rooms[n] = _room(n, "treasure", false, -1)
				rooms[n]["rift"] = params["rift"]
				connections.append({"a": anchor2, "b": n, "kind": "ability", "data": {"ability": "dimension_shift"}})
				break

	# 4) saídas por sala
	for c in connections:
		var d := _dir(c["a"], c["b"])
		rooms[c["a"]]["exits"] += d
		rooms[c["b"]]["exits"] += OPP[d]

	# 5) carimbar tudo numa grade única
	var min_c := Vector2i(1 << 20, 1 << 20)
	var max_c := Vector2i(-(1 << 20), -(1 << 20))
	for cell in rooms.keys():
		min_c = Vector2i(mini(min_c.x, cell.x), mini(min_c.y, cell.y))
		max_c = Vector2i(maxi(max_c.x, cell.x), maxi(max_c.y, cell.y))
	var gw := (max_c.x - min_c.x + 1) * LevelConst.ROOM_W
	var gh := (max_c.y - min_c.y + 1) * LevelConst.ROOM_H
	var grid := []
	for y in gh:
		var row := []
		row.resize(gw)
		row.fill("#")
		grid.append(row)

	var entities: Array = []
	var room_list: Array = []
	var cells_sorted: Array = rooms.keys()
	cells_sorted.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var pool := _enemy_pool(params, db, biome)
	var npc_ids: Array = params.get("npcs", []).duplicate()
	var key_placed := false
	for cell in cells_sorted:
		var room: Dictionary = rooms[cell]
		var entry := _entry_dir(room, connections, rooms)
		var tpl := _choose_template(library, room["type"], room["exits"], biome_id, rng)
		var g: Array = []
		if not tpl.is_empty():
			g = RoomSynth.from_rows(tpl["rows"])
			for e in tpl["exits"]:
				if not room["exits"].contains(e):
					RoomSynth.seal_exit(g, e)
			# saída para cima sem escada no template? adiciona
			if room["exits"].contains("U") and not tpl["exits"].contains("U"):
				RoomSynth.ladder(g, rng)
			# template feito para a escala antiga: só vale se o herói atravessa
			var mode := "dash" if room["type"] in RoomSynth.DASH_TYPES else "jump"
			if room["exits"].length() >= 2 and RoomReach.check_room(g, room["exits"], mode) != "":
				g = []
			else:
				room["template"] = tpl["id"]
				room["tags"] = tpl["tags"]
		if g.is_empty():
			# caçada: sala de plataforma do caminho que fecha até matar todos
			var hunt: bool = room["type"] == "platforming" and room.get("on_path", false) and rng.randf() < HUNT_CHANCE
			# fuga: muralha de espinhos avança pela sala (só salas L-R do caminho)
			var chase: bool = not hunt and room["type"] in ["platforming", "corridor"] and room["exits"] == "LR" \
				and room.get("on_path", false) and rng.randf() < CHASE_CHANCE
			g = RoomSynth.from_rows(RoomSynth.synth(room["type"], room["exits"], rng,
				{"tier": tier, "entry": entry, "indoor": indoor, "hunt": hunt, "chase": chase}))
			room["template"] = "synth:" + room["type"]
			if room["type"] == "combat":
				room["tags"] = PackedStringArray(["lock"])
			elif hunt:
				room["tags"] = PackedStringArray(["lock", "hunt"])
			elif chase:
				room["tags"] = PackedStringArray(["chase"])
		# conexões especiais do lado desta sala (a sala-âncora do ramo)
		var gate_conns := {}
		for c in connections:
			if c["kind"] == "open" or c["a"] != cell:
				continue
			var d := _dir(c["a"], c["b"])
			match c["kind"]:
				"secret":
					_mark_exit(g, d, "B")
				"locked", "ability":
					_mark_gate(g, d, "V")
					gate_conns[d] = c
		var origin := Vector2i((cell.x - min_c.x) * LevelConst.ROOM_W, (cell.y - min_c.y) * LevelConst.ROOM_H)
		room["origin"] = [origin.x, origin.y]
		room["index"] = room_list.size()
		for y in LevelConst.ROOM_H:
			for x in LevelConst.ROOM_W:
				var ch: String = g[y][x]
				var wx := origin.x + x
				var wy := origin.y + y
				if LevelConst.ENTITY_CHARS.has(ch) or ch == "B" or ch == "Z":
					var ent := _make_entity(ch, wx, wy, room, rng, pool, db, params, tier)
					if ch == "V":
						var gate_conn: Dictionary = gate_conns.get(_dir_of_edge_cell(x, y), {})
						ent["data"] = gate_conn.get("data", {}).duplicate()
						ent["data"]["kind"] = gate_conn.get("kind", "locked")
					if ch == "N":
						if npc_ids.is_empty():
							ch = "."
							grid[wy][wx] = "."
							continue
						ent["data"]["npc"] = npc_ids.pop_front()
					if ch == "t":
						ent["data"]["dir"] = turret_dir(g, x, y)
						ent["data"]["phase"] = 0.5 * float((x / 3 + y / 3) % 2)
					if ch == "G":
						if room["type"] == "puzzle":
							ent["data"]["mode"] = "lever"
						elif room["tags"].has("lock") or room["type"] == "boss":
							ent["data"]["mode"] = "combat"
						else:
							ent["data"]["mode"] = "open"
					entities.append(ent)
					grid[wy][wx] = "."
				else:
					grid[wy][wx] = ch
		if room.has("rift"):
			entities.append({"type": "rift", "tile": [origin.x + 20, origin.y + 20], "room": room["index"], "data": {"region": room["rift"]}})
		room_list.append(room)

	# chave para salas trancadas: numa sala do caminho antes do fim
	if key_needed:
		for cell in path.slice(1, path.size() - 1):
			var r: Dictionary = rooms[cell]
			if r["type"] in ["combat", "corridor", "platforming", "puzzle"]:
				var o: Array = r["origin"]
				entities.append({"type": "key", "tile": [o[0] + 33, o[1] + 20], "room": r["index"], "data": {"item": "chave_ferro"}})
				key_placed = true
				break

	var spawn := Vector2i(-1, -1)
	var exit_tile := Vector2i(-1, -1)
	for e in entities:
		if e["type"] == "spawn" and spawn.x < 0:
			spawn = Vector2i(e["tile"][0], e["tile"][1])
		if e["type"] == "exit":
			exit_tile = Vector2i(e["tile"][0], e["tile"][1])
	if spawn.x < 0:
		var o0: Array = rooms[path[0]]["origin"]
		spawn = Vector2i(o0[0] + 6, o0[1] + LevelConst.FLOOR_ROW - 1)
		entities.append({"type": "spawn", "tile": [spawn.x, spawn.y], "room": 0, "data": {}})
	if exit_tile.x < 0:
		var o1: Array = rooms[path[-1]]["origin"]
		exit_tile = Vector2i(o1[0] + 28, o1[1] + LevelConst.FLOOR_ROW - 1)
		entities.append({"type": "exit", "tile": [exit_tile.x, exit_tile.y], "room": rooms[path[-1]]["index"], "data": {}})

	# 6) salas largas: funde pares vizinhos de parkour/corredor no caminho
	var groups := _merge_wide(rng, path, rooms, grid, min_c)

	var rows := PackedStringArray()
	for row in grid:
		rows.append("".join(row))
	var cells_out := []
	for cell in path:
		cells_out.append([cell.x - min_c.x, cell.y - min_c.y])
	return {
		"seed": seed_value,
		"biome": biome_id,
		"tier": tier,
		"width": gw,
		"height": gh,
		"rows": rows,
		"rooms": room_list,
		"path": cells_out,
		"entities": entities,
		"spawn": [spawn.x, spawn.y],
		"exit": [exit_tile.x, exit_tile.y],
		"key_placed": key_placed or not key_needed,
		"indoor": indoor,
		"groups": groups,
	}


## Tipos que podem virar uma sala larga (2 telas) quando vizinhos no caminho.
const WIDE_TYPES := ["platforming", "challenge", "corridor"]


## Abre a parede entre salas vizinhas de parkour (esquerda-direita) no caminho
## crítico: uma sequência de 2 telas com a câmera rolando. Costura o teto e o
## chão na emenda. Retorna [[índice_a, índice_b], ...].
static func _merge_wide(rng: RandomNumberGenerator, path: Array, rooms: Dictionary, grid: Array, min_c: Vector2i) -> Array:
	var groups := []
	var used := {}
	for i in range(0, path.size() - 1):
		var a: Vector2i = path[i]
		var b: Vector2i = path[i + 1]
		if absi(b.x - a.x) != 1 or b.y != a.y or used.has(a) or used.has(b):
			continue
		if not (rooms[a]["type"] in WIDE_TYPES and rooms[b]["type"] in WIDE_TYPES):
			continue
		var ta := PackedStringArray(rooms[a].get("tags", []))
		var tb := PackedStringArray(rooms[b].get("tags", []))
		if ta.has("lock") or tb.has("lock") or ta.has("chase") or tb.has("chase"):
			continue # caçada tem portões nas bordas; fuga é por sala
		if rng.randf() > 0.6:
			continue
		var left: Vector2i = a if a.x < b.x else b
		var right: Vector2i = b if a.x < b.x else a
		var lx := (left.x - min_c.x) * LevelConst.ROOM_W + LevelConst.ROOM_W - 2
		var ly := (left.y - min_c.y) * LevelConst.ROOM_H
		if not _edge_clear(grid, lx, ly) or not _edge_clear(grid, lx + 3, ly):
			continue # sala em andares (zigue-zague): a emenda abriria atalhos
		used[a] = true
		used[b] = true
		var ox := (left.x - min_c.x) * LevelConst.ROOM_W
		var oy := (left.y - min_c.y) * LevelConst.ROOM_H
		var sx := ox + LevelConst.ROOM_W - 1 # última coluna da esquerda; sx+1 = primeira da direita
		# teto: menor abertura entre as vizinhas da emenda
		var ceil_l := _first_open(grid, sx - 1, oy)
		var ceil_r := _first_open(grid, sx + 2, oy)
		var ceil_y := mini(ceil_l, ceil_r)
		# chão: se os dois lados da emenda são fosso, a emenda também vira fosso
		var pit: bool = grid[oy + LevelConst.FLOOR_ROW][sx - 1] != "#" and grid[oy + LevelConst.FLOOR_ROW][sx + 2] != "#"
		for x in [sx, sx + 1]:
			for y in range(oy + 1, oy + LevelConst.FLOOR_ROW):
				grid[y][x] = "#" if y - oy < ceil_y else "."
			if pit:
				grid[oy + LevelConst.FLOOR_ROW][x] = "."
				grid[oy + LevelConst.FLOOR_ROW + 1][x] = "^"
		rooms[left]["wide"] = true
		rooms[right]["wide"] = true
		groups.append([int(rooms[left]["index"]), int(rooms[right]["index"])])
	return groups


## A coluna x é um vão contínuo do teto até o chão (sem andares no meio)?
static func _edge_clear(grid: Array, x: int, oy: int) -> bool:
	var top := _first_open(grid, x, oy)
	for y in range(top, LevelConst.FLOOR_ROW):
		if grid[oy + y][x] == "#":
			return false
	return true


static func _first_open(grid: Array, x: int, oy: int) -> int:
	for y in range(1, LevelConst.FLOOR_ROW):
		if grid[oy + y][x] != "#":
			return y
	return LevelConst.FLOOR_ROW


static func _room(cell: Vector2i, t: String, on_path: bool, idx: int) -> Dictionary:
	return {"cell": [cell.x, cell.y], "type": t, "exits": "", "on_path": on_path, "path_index": idx, "tags": PackedStringArray()}


static func _walk(rng: RandomNumberGenerator, length: int) -> Array[Vector2i]:
	for attempt in 60:
		var path: Array[Vector2i] = [Vector2i.ZERO]
		var used := {Vector2i.ZERO: true}
		var ok := true
		while path.size() < length:
			var cur: Vector2i = path[-1]
			var weights := {"R": 6.0, "U": 1.6, "D": 1.8, "L": 0.6}
			# evita duas subidas/descidas seguidas longas
			var options := {}
			for d in weights.keys():
				var n: Vector2i = cur + DIRS[d]
				if not used.has(n) and absi(n.y) <= 3:
					options[d] = weights[d]
			if options.is_empty():
				ok = false
				break
			var d2: String = RngUtil.weighted_key(rng, options)
			var nxt: Vector2i = cur + DIRS[d2]
			path.append(nxt)
			used[nxt] = true
		if ok:
			return path
	# fallback: linha reta
	var line: Array[Vector2i] = []
	for i in length:
		line.append(Vector2i(i, 0))
	return line


static func _dir(a: Vector2i, b: Vector2i) -> String:
	var d := b - a
	for k in DIRS.keys():
		if DIRS[k] == d:
			return k
	return "R"


static func _entry_dir(room: Dictionary, connections: Array, rooms: Dictionary) -> String:
	var cell := Vector2i(room["cell"][0], room["cell"][1])
	for c in connections:
		if c["b"] == cell:
			return OPP[_dir(c["a"], c["b"])]
	return "L"


static func _dir_of_edge_cell(x: int, y: int) -> String:
	if x == 0:
		return "L"
	if x == LevelConst.ROOM_W - 1:
		return "R"
	if y == 0:
		return "U"
	return "D"


static func _choose_template(library: ChunkLibrary, t: String, exits: String, biome: String, rng: RandomNumberGenerator) -> Dictionary:
	if library == null:
		return {}
	var found := library.find(t, exits, biome)
	if found.is_empty():
		return {}
	# o sintetizador (escala 8 px) é o principal; templates entram às vezes
	if t in ["combat", "corridor", "platforming", "shaft", "challenge"] and rng.randf() < 0.7:
		return {}
	return RngUtil.weighted_item(rng, found)


static func _mark_exit(g: Array, d: String, ch: String) -> void:
	match d:
		"L":
			for y in LevelConst.EXIT_LR_ROWS:
				g[y][0] = ch
		"R":
			for y in LevelConst.EXIT_LR_ROWS:
				g[y][LevelConst.ROOM_W - 1] = ch
		"U":
			for x in LevelConst.EXIT_UD_COLS:
				g[0][x] = ch
		"D":
			for x in LevelConst.EXIT_UD_COLS:
				g[LevelConst.FLOOR_ROW][x] = ch


static func _mark_gate(g: Array, d: String, ch: String) -> void:
	match d:
		"L": g[LevelConst.EXIT_LR_ROWS[0]][0] = ch
		"R": g[LevelConst.EXIT_LR_ROWS[0]][LevelConst.ROOM_W - 1] = ch
		"U": g[0][LevelConst.EXIT_UD_COLS[0]] = ch
		"D": g[LevelConst.FLOOR_ROW][LevelConst.EXIT_UD_COLS[0]] = ch


static func _enemy_pool(params: Dictionary, db: Node, biome: Dictionary) -> Dictionary:
	var dim: Dictionary = db.dimension(params.get("dimension", "prima"))
	var src: Dictionary = dim.get("creatures", biome.get("enemies", {"skeleton": 1}))
	var ground := {}
	var flying := {}
	for id in src.keys():
		var e: Dictionary = db.enemy(id)
		if e.is_empty() or e.get("boss", false) or e.get("elite", false):
			continue
		if e.get("flying", false):
			flying[id] = src[id]
		else:
			ground[id] = src[id]
	if ground.is_empty():
		ground = {"skeleton": 1}
	if flying.is_empty():
		flying = {"wraith": 1}
	return {"ground": ground, "flying": flying}


## Torreta atira para o lado oposto da parede em que está presa.
static func turret_dir(g: Array, x: int, y: int) -> String:
	var solid := func(xx: int, yy: int) -> bool:
		if yy < 0 or yy >= g.size() or xx < 0 or xx >= g[yy].size():
			return true
		return g[yy][xx] == "#"
	if solid.call(x - 1, y) and not solid.call(x + 1, y):
		return "R"
	if solid.call(x + 1, y) and not solid.call(x - 1, y):
		return "L"
	if solid.call(x, y - 1):
		return "D"
	if solid.call(x, y + 1):
		return "U"
	return "L"


static func _make_entity(ch: String, x: int, y: int, room: Dictionary, rng: RandomNumberGenerator, pool: Dictionary, db: Node, params: Dictionary, tier: int) -> Dictionary:
	var t: String = LevelConst.ENTITY_CHARS.get(ch, "")
	if ch == "B":
		t = "breakable"
	elif ch == "Z":
		t = "cracked_floor"
	var e := {"type": t, "tile": [x, y], "room": room.get("index", 0), "data": {}}
	match ch:
		"E":
			e["data"]["enemy"] = RngUtil.weighted_key(rng, pool["ground"])
		"F":
			e["data"]["enemy"] = RngUtil.weighted_key(rng, pool["flying"])
		"M":
			e["data"]["enemy"] = params.get("boss", "nightmare") if params.get("boss", "") != "" else "nightmare"
		"C":
			e["data"]["loot"] = roll_loot(rng, db, tier, room.get("type", "") == "treasure")
		"R":
			e["data"]["loot"] = roll_loot(rng, db, tier + 1, true, true)
		"K":
			e["data"]["item"] = "chave_ferro"
		"s":
			e["data"]["travel"] = [0, -5] # serra que sobe e desce no vão
	return e


## Sorteia um item do pool compartilhado respeitando tier e raridade.
## Itens exclusivos de inimigos nunca aparecem em baús.
static func roll_loot(rng: RandomNumberGenerator, db: Node, tier: int, good: bool = false, relic: bool = false) -> String:
	var table := {}
	var rarity_w := {"common": 6.0, "rare": 2.5 if not good else 4.0, "epic": 0.6 if not good else 1.5, "legendary": 0.1}
	if relic:
		for id in db.buffs.keys():
			var b: Dictionary = db.buffs[id]
			if b.get("hidden", false) or int(b.get("tier", 1)) > tier:
				continue
			table[id] = rarity_w.get(b.get("rarity", "common"), 1.0)
		if not table.is_empty():
			return RngUtil.weighted_key(rng, table)
	for src in [db.weapons, db.spells, db.armor]:
		for id in src.keys():
			var it: Dictionary = src[id]
			if it.get("exclusive_to", "") != "" or int(it.get("tier", 1)) > tier:
				continue
			table[id] = rarity_w.get(it.get("rarity", "common"), 1.0) * (0.5 if src == db.armor else 1.0)
	for id in db.buffs.keys():
		var b: Dictionary = db.buffs[id]
		if not b.get("hidden", false) and int(b.get("tier", 1)) <= tier:
			table[id] = rarity_w.get(b.get("rarity", "common"), 1.0) * 0.8
	table["pocao_vida"] = 3.0
	table["fragmento_runico"] = 2.0
	return RngUtil.weighted_key(rng, table)
