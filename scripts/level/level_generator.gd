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
##   path_length, quest_objective, no_branches (arena: só o caminho)
## Saída: {width, height, rows, rooms, entities, spawn, exit, ...}

const DIRS := {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "U": Vector2i(0, -1), "D": Vector2i(0, 1)}
const OPP := {"R": "L", "L": "R", "U": "D", "D": "U"}
const PATH_WEIGHTS := {"combat": 4.0, "arena": 1.6, "platforming": 3.0, "corridor": 1.6, "puzzle": 1.0, "shaft": 0.8, "challenge": 0.8}
const BRANCH_WEIGHTS := {"treasure": 3.0, "secret": 2.0, "challenge": 1.5, "puzzle": 1.0, "combat": 1.0}


static func generate(params: Dictionary, library: ChunkLibrary, db: Node) -> Dictionary:
	var seed_value: int = int(params.get("seed", 1))
	var rng := RngUtil.make(seed_value, "level")
	var tier: int = int(params.get("tier", 1))
	var biome_id: String = params.get("biome", "castelo")
	var biome: Dictionary = db.biome(biome_id)
	var indoor: bool = biome.get("tags", []).has("indoor")

	# 1) caminho crítico
	var length: int = int(params.get("path_length", 8 + tier * 2 + rng.randi_range(-1, 2)))
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
	for i in path.size():
		rooms[path[i]]["type"] = types[i]
		# salas verticais de verdade viram "shaft" se o caminho sobe/desce
		if i > 0 and i < path.size() - 1 and types[i] in ["corridor", "combat"]:
			var up_down: bool = path[i - 1].y != path[i].y or path[i + 1].y != path[i].y
			if up_down and rng.randf() < 0.4:
				rooms[path[i]]["type"] = "shaft"

	# 2) ramos opcionais
	var branch_count := rng.randi_range(2, 4) + (1 if tier >= 2 else 0)
	if params.get("no_branches", false):
		branch_count = 0
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
	# biomas externos: uma faixa de céu acima da fase
	if not indoor:
		min_c.y -= 1
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
		var g: Array
		if tpl.is_empty():
			g = RoomSynth.from_rows(RoomSynth.synth(room["type"], room["exits"], rng,
				{"tier": tier, "entry": entry, "indoor": indoor}))
			room["template"] = "synth:" + room["type"]
		else:
			g = RoomSynth.from_rows(tpl["rows"])
			RoomSynth.resolve_tokens(g, rng)
			room["template"] = tpl["id"]
			room["tags"] = tpl["tags"]
			for e in tpl["exits"]:
				if not room["exits"].contains(e):
					RoomSynth.seal_exit(g, e)
		# saída para cima sem escada no template? adiciona
		if room["exits"].contains("U") and tpl.is_empty() == false and not tpl["exits"].contains("U"):
			RoomSynth.ladder(g, rng)
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
					if ch == "G":
						if room["type"] == "puzzle":
							ent["data"]["mode"] = "lever"
						elif room["tags"].has("lock") or room["type"] in ["boss", "arena"]:
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

	# fase contínua (Dead Cells): salões abertos entre salas e céu aberto
	var sky_rooms := _open_up(grid, rooms, connections, min_c, indoor, rng)

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
		"sky_rooms": sky_rooms,
	}


## Salas que nunca têm paredes derrubadas (trancas, alavancas, segredos).
const CLOSED_TYPES := ["boss", "puzzle", "secret"]


static func _can_open(room: Dictionary) -> bool:
	if room["type"] in CLOSED_TYPES or room.has("rift"):
		return false
	return not (room["tags"].has("lock") or room["tags"].has("boss"))


static func _solid(ch: String) -> bool:
	return ch == "#"


## Deixa a fase contínua, estilo Dead Cells: derruba a parede entre salas
## vizinhas lado a lado (conectadas por passagem aberta, ou às vezes sem
## conexão = atalhos/ciclos) onde os dois lados estão livres, formando
## salões. Em biomas externos abre o teto das salas mais altas para o céu e
## as laterais que dão para o céu. Só REMOVE sólidos cujas duas vizinhas
## internas estão livres, então nenhum caminho validado (RoomReach) quebra.
static func _open_up(grid: Array, rooms: Dictionary, connections: Array, min_c: Vector2i, indoor: bool, rng: RandomNumberGenerator) -> Array:
	var W := LevelConst.ROOM_W
	var H := LevelConst.ROOM_H
	var conn_kind := {}
	for c in connections:
		conn_kind[[c["a"], c["b"]]] = c["kind"]
		conn_kind[[c["b"], c["a"]]] = c["kind"]
	var gh := grid.size()
	var gw: int = grid[0].size()
	for cell in rooms.keys():
		var right: Vector2i = cell + Vector2i(1, 0)
		if not rooms.has(right):
			continue
		var a: Dictionary = rooms[cell]
		var b: Dictionary = rooms[right]
		if not _can_open(a) or not _can_open(b):
			continue
		var kind: String = conn_kind.get([cell, right], "none")
		if kind != "open" and not (kind == "none" and rng.randf() < 0.45):
			continue
		var ox: int = (cell.x - min_c.x) * W
		var oy: int = (cell.y - min_c.y) * H
		var gx: int = ox + W - 1
		_dissolve_column_pair(grid, gx, oy + 1, oy + H - 2)
	var sky_rooms: Array = []
	if indoor:
		return sky_rooms
	# céu: acima da sala mais alta de cada coluna tudo vira ar
	var top_of := {}
	for cell in rooms.keys():
		if not top_of.has(cell.x) or cell.y < top_of[cell.x]:
			top_of[cell.x] = cell.y
	for cx in top_of.keys():
		var ox: int = (cx - min_c.x) * W
		var top_cell_y: int = top_of[cx]
		var oy_top: int = (top_cell_y - min_c.y) * H
		for y in range(0, oy_top):
			for x in range(ox, ox + W):
				grid[y][x] = "."
		# teto da sala mais alta aberto onde a linha de baixo está livre
		var room: Dictionary = rooms[Vector2i(cx, top_cell_y)]
		sky_rooms.append([cx - min_c.x, top_cell_y - min_c.y])
		if room["type"] in CLOSED_TYPES:
			continue
		for x in range(ox + 1, ox + W - 1):
			if grid[oy_top + 1][x] != "#":
				grid[oy_top][x] = "."
		# laterais que dão para o céu (vizinho sem sala mais alto)
		for side in [-1, 1]:
			var ncx: int = cx + side
			var neighbor_top: int = top_of.get(ncx, 1 << 20)
			if neighbor_top <= top_cell_y:
				continue
			var gx: int = ox if side < 0 else ox + W - 1
			var inner: int = gx - side
			var outer: int = gx + side
			if outer < 0 or outer >= gw:
				continue
			for y in range(oy_top + 1, mini(oy_top + H - 2, gh)):
				if (neighbor_top - min_c.y) * H <= y:
					break
				if grid[y][inner] != "#" and grid[y][outer] != "#":
					grid[y][gx] = "."
	return sky_rooms


## Derruba a parede dupla (colunas gx e gx+1) entre duas salas nas linhas em
## que as duas vizinhas internas (gx-1 e gx+2) estão livres. Ignora trechos
## de só 1 linha (evita buraquinhos).
static func _dissolve_column_pair(grid: Array, gx: int, y0: int, y1: int) -> void:
	var rows_ok: Array = []
	for y in range(y0, y1 + 1):
		var free_l: bool = not _solid(grid[y][gx - 1])
		var free_r: bool = not _solid(grid[y][gx + 2])
		rows_ok.append(free_l and free_r)
	var i := 0
	while i < rows_ok.size():
		if not rows_ok[i]:
			i += 1
			continue
		var j := i
		while j < rows_ok.size() and rows_ok[j]:
			j += 1
		if j - i >= 2:
			for k in range(i, j):
				grid[y0 + k][gx] = "."
				grid[y0 + k][gx + 1] = "."
		i = j


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
	# partes aleatórias (Dead Cells): às vezes o sintetizador mesmo havendo
	# estrutura pronta
	if t in ["combat", "corridor", "platforming", "shaft"] and rng.randf() < 0.25:
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
	var ranged := {}
	for id in src.keys():
		var e: Dictionary = db.enemy(id)
		if e.is_empty() or e.get("boss", false) or e.get("elite", false):
			continue
		if e.get("flying", false):
			flying[id] = src[id]
		else:
			ground[id] = src[id]
			if e.get("ai", "") in ["gunner", "turret"]:
				ranged[id] = src[id]
	if ground.is_empty():
		ground = {"skeleton": 1}
	if flying.is_empty():
		flying = {"wraith": 1}
	if ranged.is_empty():
		ranged = {"gunner": 1}
	return {"ground": ground, "flying": flying, "ranged": ranged}


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
		"U":
			e["type"] = "enemy"
			e["data"]["enemy"] = RngUtil.weighted_key(rng, pool["ranged"])
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
