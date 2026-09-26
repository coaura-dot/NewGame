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
