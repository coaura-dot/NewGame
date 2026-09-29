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
	for t in ["combat", "platforming", "challenge", "corridor", "puzzle", "treasure", "secret", "boss", "hub", "shaft", "zigzag"]:
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
	for t in ["combat", "platforming", "challenge", "corridor", "puzzle", "treasure", "entrance", "exit", "hub", "boss", "shaft", "zigzag"]:
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
			var ch: String = {"impulse_orb": "I", "dash_crystal": "D", "jump_pad": "J", "falling_platform": "O", "moving_platform": "U",
				"reset_bell": "b", "jump_feather": "j", "double_crystal": "d"}.get(e["type"], "")
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


## Estética escura: rocha escurece com a distância do ar, pixels que emitem
## luz vão para a camada "Glow" (aditiva, HDR) e cada bioma tem os 4 fundos.
func test_estetica_escura() -> void:
	var biomes: Dictionary = DB.biomes
	for bid in biomes.keys():
		var art: String = str(bid)
		if art.begins_with("_"):
			continue
		check(ResourceLoader.exists("res://assets/art/tiles/%s_glow.png" % art), "%s: atlas de brilho" % art)
		for layer in ["0_sky", "1_far", "2_mid", "3_near"]:
			check(ResourceLoader.exists("res://assets/art/bg/%s/%s.png" % [art, layer]), "%s: fundo %s" % [art, layer])
		check(biomes[bid].has("shade"), "%s: penumbra definida" % art)
	# fase montada: rocha funda sem colisão, brilho só onde o atlas tem luz
	var rows := PackedStringArray([
		"##########",
		"#........#",
		"#........#",
		"#...-----#",
		"#........#",
		"##########",
		"##########",
		"##########",
		"##########",
	])
	var root := Node2D.new()
	var built: Dictionary = LevelBuilder.build(root, {"rows": rows, "width": 10, "height": 9, "rooms": []}, {"art": "floresta"}, "floresta")
	var terrain: TileMapLayer = built["terrain"]
	check(terrain.get_cell_atlas_coords(Vector2i(4, 7)) in TileSetBuilder.DEEPER, "rocha a 3 tiles do ar é quase preta")
	check(terrain.get_cell_atlas_coords(Vector2i(4, 6)) in TileSetBuilder.DEEP, "rocha a 2 tiles do ar é funda")
	check(terrain.get_cell_atlas_coords(Vector2i(4, 5)) == TileSetBuilder.mask_tile(2 | 4 | 8), "chão exposto usa tile de borda")
	var glow: TileMapLayer = built["glow"]
	check(glow != null, "camada de brilho existe")
	if glow:
		check(glow.material is CanvasItemMaterial and (glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "brilho é aditivo")
		check(glow.modulate.r > 1.0, "brilho em HDR (vira bloom)")
		var cells := TileSetBuilder.glow_cells("floresta")
		var ok := true
		for c in glow.get_used_cells():
			if not cells.has(glow.get_cell_atlas_coords(c)):
				ok = false
		check(ok, "só tiles com pixels de luz entram no brilho")
	root.free()
	# penumbra: mais escura com pouca luz; mais leve sem luzes dinâmicas
	var base := Level.ambient_color({"shade": [0.7, 0.7, 0.8]}, {})
	var low := Level.ambient_color({"shade": [0.7, 0.7, 0.8]}, {"rules": ["low_light"]})
	check(low.r < base.r and base.r < 1.0, "regra low_light escurece a fase")


## O mapa-múndi vive em crepúsculo; cada Brasa devolvida clareia o dia.
func test_crepusculo_da_lareira() -> void:
	var OW = load("res://scripts/world/overworld.gd")
	var apagada: Color = OW.daylight_color(0.0, 0.0)
	var acesa: Color = OW.daylight_color(0.0, 1.0)
	var noite: Color = OW.daylight_color(1.0, 0.0)
	check(apagada.r < 0.8 and apagada.b > apagada.r, "Lareira apagada: dia azulado e escuro")
	check(acesa.r > apagada.r + 0.2, "com as Brasas o dia esquenta e clareia")
	check(noite.r < apagada.r, "a noite é mais escura que o crepúsculo")


## Salas sombrias têm lamparinas em pé, em lugar livre (ninguém fica sem luz),
## e as lamparinas não mudam o sorteio das salas (RNG próprio).
func test_salas_sombrias_e_lamparinas() -> void:
	var biomes := ["catacumbas", "cidade_subterranea", "toca_goblin", "cemiterio", "castelo", "floresta"]
	var dark_rooms := 0
	var lamps := 0
	for i in 18:
		var params := {"seed": 900 + i * 13, "biome": biomes[i % biomes.size()], "tier": 1 + i % 3, "boss": "", "hub": "",
			"npcs": [], "abilities": ["dash"]}
		var L := LevelGenerator.generate(params, lib, DB)
		var rows: PackedStringArray = L["rows"]
		var per_room := {}
		for e in L["entities"]:
			if e["type"] != "lamp":
				continue
			lamps += 1
			var t := Vector2i(int(e["tile"][0]), int(e["tile"][1]))
			per_room[int(e["room"])] = int(per_room.get(int(e["room"]), 0)) + 1
			check(rows[t.y][t.x] == "." and rows[t.y - 1][t.x] == ".", "lamparina em lugar livre (%s)" % t)
			var below: String = rows[t.y + 1][t.x]
			check(below == "#" or below == "-", "lamparina em pé sobre chão/plataforma (%s: '%s')" % [t, below])
		for r in L["rooms"]:
			if r.get("dark", false):
				dark_rooms += 1
				check(PackedStringArray(r.get("tags", [])).has("dark"), "sala sombria marcada")
				check(r["type"] in LevelGenerator.DARK_TYPES, "tipo que pode ser sombrio (%s)" % r["type"])
				check(int(per_room.get(int(r["index"]), 0)) >= 2, "sala sombria %d tem lamparinas (%d)" % [r["index"], int(per_room.get(int(r["index"]), 0))])
	check(dark_rooms >= 6, "fases escuras têm salas sombrias (%d)" % dark_rooms)
	check(lamps >= 30, "lamparinas espalhadas pelas fases (%d)" % lamps)
	# o treino força o poço (índice 4 do caminho) a ser sombrio
	var tp := {"seed": 20260926, "biome": "castelo", "tier": 1, "boss": "nightmare", "hub": "", "npcs": [], "abilities": ["dash"],
		"force_path": ["entrance", "platforming", "combat", "zigzag", "shaft", "combat", "challenge", "zigzag", "boss", "exit"],
		"training": true, "force_dark": [4]}
	var TL := LevelGenerator.generate(tp, lib, DB)
	var darks := []
	for r in TL["rooms"]:
		if r.get("dark", false):
			darks.append(r["type"])
	check(darks == ["shaft"], "treino: só o poço é sombrio (%s)" % [darks])
	# chance de sala sombria: biomas escuros > comuns; sobe com o tier
	check(LevelGenerator.dark_chance({"tags": ["underground"]}, 1, {}) > LevelGenerator.dark_chance({"tags": ["outdoor"]}, 1, {}), "subterrâneo é mais sombrio")
	check(LevelGenerator.dark_chance({"tags": []}, 3, {}) > LevelGenerator.dark_chance({"tags": []}, 1, {}), "tier maior, mais salas sombrias")
