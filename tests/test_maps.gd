extends "res://tests/test_case.gd"
## Mapas FEITOS À MÃO (data/maps/*.txt) e o capítulo 1 da história:
## cada mapa carrega sem erro, tem uma sala de saída para cada vizinho do
## mundo fixo, nomes nos lugares, e tudo o que importa (santuários, baús,
## personagens, placas, lampiões, chegadas) é alcançável a partir do
## santuário/início NOS DOIS SENTIDOS (ReachMap), ignorando as salas que
## exigem uma habilidade (requires=). Também toca o despertar do Lume.


func _params(w: Dictionary, id: String) -> Dictionary:
	var r: Dictionary = w["regions"][id]
	return {"seed": int(r["level_seed"]), "biome": r["biome"], "tier": int(r["tier"]), "boss": r.get("boss", ""),
		"hub": r.get("hub", ""), "dimension": "prima", "npcs": ["a", "b", "c"], "abilities": [],
		"ports": WorldGenerator.ports(w, id), "layer": r.get("layer", ""), "region_name": r["name"], "map": r.get("map", "")}


func test_mundo_fixo() -> void:
	var w := WorldGenerator.fixed(DB)
	eq(str(w["start"]), "cinzal", "começa em Cinzal")
	check(WorldGenerator.is_completable(w, ["dash", "wall_jump"]), "mundo fixo completável")
	for id in w["regions"].keys():
		var r: Dictionary = w["regions"][id]
		if str(r.get("map", "")) != "":
			check(MapLoader.exists(str(r["map"])), "mapa existe: " + str(r["map"]))


func test_mapas_feitos_a_mao() -> void:
	var w := WorldGenerator.fixed(DB)
	for id in w["regions"].keys():
		var r: Dictionary = w["regions"][id]
		if str(r.get("map", "")) == "":
			continue
		var params := _params(w, id)
		var lay := MapLoader.load_map(str(r["map"]), params, DB)
		var tag: String = str(r["map"])
		check(lay.get("errors", ["?"]).is_empty(), tag + ": sem erros " + str(lay.get("errors", [])))
		var rows: PackedStringArray = lay["rows"]
		eq(rows.size(), int(lay["height"]), tag + ": altura")
		eq(rows[0].length(), int(lay["width"]), tag + ": largura")
		eq(lay["ports"].size(), params["ports"].size(), tag + ": uma saída por vizinho")
		for room in lay["rooms"]:
			check(str(room.get("name", "")) != "", tag + ": lugar com nome (" + str(room.get("id", "")) + ")")
		_check_reach(lay, tag)


func _check_reach(lay: Dictionary, tag: String) -> void:
	var rows: PackedStringArray = (lay["rows"] as PackedStringArray).duplicate()
	var w: int = int(lay["width"])
	# salas que exigem habilidade viram rocha; portões de habilidade também
	var blocked := {}
	for room in lay["rooms"]:
		if str(room.get("requires", "")) != "":
			blocked[int(room["index"])] = true
			var rr: Array = room["rect"]
			for y in range(int(rr[1]), int(rr[1]) + int(rr[3])):
				if y < 0 or y >= rows.size():
					continue
				var line: String = rows[y]
				for x in range(maxi(int(rr[0]), 0), mini(int(rr[0]) + int(rr[2]), w)):
					line[x] = "#"
				rows[y] = line
	for e in lay["entities"]:
		if e["type"] == "ability_gate":
			for k in 4:
				var yy: int = int(e["tile"][1]) + k
				if yy < rows.size():
					var l2: String = rows[yy]
					l2[int(e["tile"][0])] = "#"
					rows[yy] = l2
	var rm := ReachMap.new(rows)
	if lay.get("abilities", []).has("double_jump"):
		rm.with_double_jump()
	rm.build()
	var root := Vector2i(-1, -1)
	for e in lay["entities"]:
		if e["type"] == "start":
			root = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
	if root.x < 0:
		for e in lay["entities"]:
			if e["type"] == "checkpoint":
				root = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
				break
	check(root.x >= 0, tag + ": tem início/santuário")
	var rs := rm.seg_at(root.x, root.y)
	check(rs >= 0, tag + ": início com chão")
	if rs < 0:
		return
	var fwd := rm.reach_from(rs)
	var back := rm.reach_from(rs, true)
	var important := ["checkpoint", "chest", "relic", "npc", "story_npc", "lever", "arrival", "boss", "inscription", "sign", "start", "lamp"]
	for e in lay["entities"]:
		if not important.has(str(e["type"])) or blocked.has(int(e["room"])):
			continue
		var s := rm.seg_at(int(e["tile"][0]), int(e["tile"][1]))
		var what := "%s: %s em %s" % [tag, e["type"], str(e["tile"])]
		if check(s >= 0, what + " tem chão"):
			check(fwd[s] == 1, what + " alcançável")
			check(back[s] == 1, what + " tem volta")


func test_despertar() -> void:
	# novo jogo -> Cinzal: a cena do despertar toca sozinha e termina
	Game.new_game(777, 8)
	DialogueBox.auto_advance = true
	Game.pending = {"region": "cinzal"}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(level)
	var t := 0.0
	while t < 20.0 and not Story.has_flag("despertou"):
		await tree.process_frame
		t += 1.0 / 60.0
	check(Story.has_flag("despertou"), "o despertar do Lume terminou")
	check(level.player != null and not level.player.cutscene_lock, "o Lume volta a ser controlável")
	eq(level.layout.get("mode", ""), "handmade", "Cinzal é feita à mão")
	check(Story.objective() != "", "objetivo da história na HUD")
	DialogueBox.auto_advance = false
	level.queue_free()
	await tree.process_frame
	SaveSystem.delete_save(8)
