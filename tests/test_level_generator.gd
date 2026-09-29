extends "res://tests/test_case.gd"
## Fases: templates válidos, layout consistente, spawn/saída conectados.

var lib := ChunkLibrary.new()


func test_templates_validos() -> void:
	check(lib.errors.is_empty(), "templates com erro: " + ", ".join(lib.errors))
	check(lib.templates.size() >= 10, "poucos templates")


func _flood(layout: Dictionary, from: Vector2i) -> Dictionary:
	var rows: PackedStringArray = layout["rows"]
	var seen := {from: true}
	var st := [from]
	var w: int = layout["width"]
	var h: int = layout["height"]
	while not st.is_empty():
		var p: Vector2i = st.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
				continue
			if rows[n.y][n.x] == "#" or rows[n.y][n.x] == "^":
				continue
			seen[n] = true
			st.append(n)
	return seen


func test_layouts() -> void:
	var biomes := DB.biomes.keys()
	for i in 40:
		var params := {"seed": 1000 + i, "biome": biomes[i % biomes.size()], "tier": 1 + i % 3,
			"boss": "nightmare" if i % 4 == 0 else "", "hub": "vila" if i % 3 == 0 else "", "npcs": ["a", "b"], "abilities": ["dash"]}
		var L := LevelGenerator.generate(params, lib, DB)
		eq(L["rows"].size(), L["height"], "altura")
		for r in L["rows"]:
			if r.length() != L["width"]:
				check(false, "largura inconsistente")
				break
		var spawn := Vector2i(L["spawn"][0], L["spawn"][1])
		var exit := Vector2i(L["exit"][0], L["exit"][1])
		check(spawn.x >= 0 and exit.x >= 0, "spawn/saída")
		var reach := _flood(L, spawn)
		check(reach.has(exit), "seed %d: saída inalcançável a partir do spawn" % (1000 + i))
		for e in L["entities"]:
			var t: Array = e["tile"]
			check(t[0] >= 0 and t[1] >= 0 and t[0] < L["width"] and t[1] < L["height"], "entidade fora do mapa")
		check(L["key_placed"], "chave colocada quando necessária")
		var types := {}
		for r in L["rooms"]:
			types[r["type"]] = true
		check(types.has("entrance") and types.has("exit"), "entrada e saída")


func test_deterministico() -> void:
	var p := {"seed": 42, "biome": "castelo", "tier": 2}
	var a := LevelGenerator.generate(p, lib, DB)
	var b := LevelGenerator.generate(p, lib, DB)
	eq("\n".join(a["rows"]) == "\n".join(b["rows"]), true, "mesma seed, mesma fase")


func test_sintetizador_cobre_todas_saidas() -> void:
	var rng := RngUtil.make(5, "synth")
	var combos := ["L", "R", "U", "D", "LR", "LU", "LD", "RU", "RD", "UD", "LRU", "LRD", "LUD", "RUD", "LRUD"]
	for t in ["combat", "platforming", "challenge", "corridor", "puzzle", "treasure", "secret", "boss", "hub", "shaft"]:
		for ex in combos:
			var rows := RoomSynth.synth(t, ex, rng, {"tier": 2})
			eq(rows.size(), LevelConst.ROOM_H, "synth %s %s altura" % [t, ex])
			for e in ex:
				match e:
					"L": check(rows[18][0] != "#", "synth %s %s saída L" % [t, ex])
					"R": check(rows[18][LevelConst.ROOM_W - 1] != "#", "synth %s %s saída R" % [t, ex])
					"U": check(rows[0][19] != "#", "synth %s %s saída U" % [t, ex])
					"D": check(rows[22][19] != "#", "synth %s %s saída D" % [t, ex])


func test_salas_atravessaveis() -> void:
	# toda sala gerada deve ser atravessável com o pulo/dash reais do herói
	var rng := RngUtil.make(11, "reach")
	var combos := ["LR", "LU", "LD", "RU", "RD", "UD", "LRU", "LRD", "LUD", "RUD", "LRUD"]
	for t in ["combat", "platforming", "challenge", "corridor", "puzzle", "treasure", "entrance", "exit", "hub", "boss", "shaft"]:
		for ex in combos:
			for k in 2:
				var rows := RoomSynth.synth(t, ex, rng, {"tier": 2})
				var mode := "dash" if t in RoomSynth.DASH_TYPES else "jump"
				var err := RoomReach.check_rows(rows, ex, mode)
				check(err == "", "synth %s %s: %s" % [t, ex, err])


func test_fases_atravessaveis() -> void:
	# cada sala de fases completas liga todas as suas saídas
	var biomes := DB.biomes.keys()
	for i in 12:
		var params := {"seed": 500 + i * 7, "biome": biomes[i % biomes.size()], "tier": 1 + i % 3,
			"boss": "nightmare" if i % 3 == 0 else "", "hub": "vila" if i % 4 == 0 else "", "npcs": ["a"], "abilities": ["dash"]}
		var L := LevelGenerator.generate(params, lib, DB)
		var rows: PackedStringArray = L["rows"]
		var marks := {}
		for e in L["entities"]:
			var ch: String = {"impulse_orb": "I", "dash_crystal": "D", "jump_pad": "J", "falling_platform": "O", "moving_platform": "U"}.get(e["type"], "")
			if ch != "":
				marks[Vector2i(int(e["tile"][0]), int(e["tile"][1]))] = ch
		for r in L["rooms"]:
			var o: Array = r["origin"]
			var g := []
			for y in LevelConst.ROOM_H:
				var row := []
				for x in LevelConst.ROOM_W:
					var wp := Vector2i(int(o[0]) + x, int(o[1]) + y)
					var c: String = marks.get(wp, rows[wp.y][wp.x])
					row.append("." if c == "B" else c) # parede secreta conta como passagem
				g.append(row)
			var mode := "dash" if r["type"] in RoomSynth.DASH_TYPES else "jump"
			var err := RoomReach.check_room(g, r["exits"], mode)
			check(err == "", "seed %d sala %d (%s, %s): %s" % [params["seed"], r["index"], r["type"], r.get("template", "?"), err])


func test_validador_reconhece_sala_impossivel() -> void:
	# parede de 8 tiles no meio: só com pulo não passa
	var g := RoomSynth.blank()
	RoomSynth.frame(g, "LR")
	RoomSynth.fill(g, 19, 12, 20, LevelConst.FLOOR_ROW - 1, "#")
	check(RoomReach.check_room(g, "LR", "jump") != "", "parede alta bloqueia")
	var g2 := RoomSynth.blank()
	RoomSynth.frame(g2, "LR")
	RoomSynth.fill(g2, 19, LevelConst.FLOOR_ROW - 2, 20, LevelConst.FLOOR_ROW - 1, "#")
	check(RoomReach.check_room(g2, "LR", "jump") == "", "degrau de 2 tiles passa")
	# fosso largo de espinhos: impossível só pulando, possível quicando em orbes
	var g3 := RoomSynth.blank()
	RoomSynth.frame(g3, "LR")
	for x in range(6, 34):
		g3[LevelConst.FLOOR_ROW][x] = "^"
	check(RoomReach.check_room(g3, "LR", "jump") != "", "fosso de 28 tiles bloqueia")
	for ox in [10, 16, 22, 28]:
		g3[LevelConst.FLOOR_ROW - 4][ox] = "I"
	check(RoomReach.check_room(g3, "LR", "jump") == "", "orbes em cadeia atravessam o fosso")


func test_nota_da_fase() -> void:
	eq(Level.rank_for({"time": 60.0, "deaths": 0, "hits": 0}, 10), "S", "rápido e sem erro = S")
	eq(Level.rank_for({"time": 150.0, "deaths": 1, "hits": 2}, 10), "A", "uma morte = A")
	eq(Level.rank_for({"time": 400.0, "deaths": 3, "hits": 10}, 10), "C", "lento e morrendo = C")
	eq(Level.format_time(75.5), "1:15.50", "formato do tempo")


func test_espinhos_de_pogo_no_validador() -> void:
	# fosso largo demais para pular; só dá para cruzar quicando nos espinhos
	var g := RoomSynth.blank()
	RoomSynth.frame(g, "LR")
	for x in range(4, 36):
		RoomSynth.fill(g, x, 21, x, 22, ".")
		RoomSynth.put(g, x, 22, "^")
	var ok_before := RoomReach.check_room(g, "LR", "jump")
	check(ok_before != "", "fosso de 32 tiles é intransponível sem ajuda")
	for x in [7, 12, 17, 22, 27, 32]:
		RoomSynth.put(g, x, 19, "^")
		RoomSynth.put(g, x, 20, "#")
	var ok_after := RoomReach.check_room(g, "LR", "jump")
	check(ok_after == "", "espinhos flutuantes viram apoio de pogo (%s)" % ok_after)


func test_zigue_zague_atravessavel() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 20:
		rng.seed = 900 + i
		var g := RoomSynth.blank()
		RoomSynth.frame(g, "LR")
		RoomSynth._switchback(g, rng, "LR", i % 2 == 0, 2, i % 3 == 0)
		var r := RoomReach.check_room(g, "LR", "dash")
		check(r == "", "zigue-zague %d atravessável (%s)" % [i, r])
