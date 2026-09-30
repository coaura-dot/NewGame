extends "res://tests/test_case.gd"
## Regiões por LUGARES (RegionDesigner): todas as regiões de alguns mundos
## são geradas; conferimos santuário, objetivo, portões nas bordas certas,
## nomes, ecossistema (sem inimigos no santuário) e o alcance (ReachMap) de
## todo lugar importante a partir do santuário, nos dois sentidos.
## REGION_DUMP=<pasta> salva o desenho ASCII de cada região.


func _params(w: Dictionary, id: String) -> Dictionary:
	var r: Dictionary = w["regions"][id]
	var ports := WorldGenerator.ports(w, id)
	var names := {}
	for pt in ports:
		names[pt["dir"]] = str(w["regions"][pt["to"]]["name"])
	return {"seed": int(r["level_seed"]), "biome": r["biome"], "tier": int(r["tier"]), "boss": r.get("boss", ""),
		"hub": r.get("hub", ""), "dimension": r.get("dimension", "prima"), "npcs": ["a", "b"], "abilities": [],
		"ports": ports, "port_names": names, "layer": r.get("layer", ""), "region_name": r["name"]}


func test_regioes() -> void:
	var dump := OS.get_environment("REGION_DUMP")
	var only := OS.get_environment("REGION_ONLY") # "11:r05"
	var total_ms := 0
	var count := 0
	var seeds: Array = [11, 22, 33]
	if OS.get_environment("REGION_SEEDS") != "":
		seeds = Array(OS.get_environment("REGION_SEEDS").split(",")).map(func(x): return int(x))
	for s in seeds:
		var w := WorldGenerator.generate(s, DB)
		for id in w["regions"].keys():
			if only != "" and only != "%d:%s" % [s, id]:
				continue
			var r: Dictionary = w["regions"][id]
			var params := _params(w, id)
			var t0 := Time.get_ticks_msec()
			var lay := RegionDesigner.generate(params, DB)
			total_ms += Time.get_ticks_msec() - t0
			count += 1
			var tag := "seed %d %s (%s)" % [s, id, r["biome"]]
			_check_layout(lay, params, tag)
			if dump != "":
				_dump(lay, dump.path_join("%d_%s_%s.txt" % [s, id, r["biome"]]))
	print("  regiões: %d, média %.0f ms" % [count, float(total_ms) / maxf(1.0, count)])
	check(float(total_ms) / maxf(1.0, count) < 2500.0, "geração rápida o bastante")


func _check_layout(lay: Dictionary, params: Dictionary, tag: String) -> void:
	var rows: PackedStringArray = lay["rows"]
	eq(rows.size(), int(lay["height"]), tag + ": altura")
	eq(rows[0].length(), int(lay["width"]), tag + ": largura")
	eq(lay["ports"].size(), params["ports"].size(), tag + ": todos os portões")
	var kinds := {}
	for room in lay["rooms"]:
		kinds[room["kind"]] = true
		check(str(room.get("name", "")) != "", tag + ": lugar com nome")
	check(kinds.has("santuario") or kinds.has("vila"), tag + ": tem santuário/vila")
	check(kinds.has("covil") if str(params["boss"]) != "" else kinds.has("coracao"), tag + ": tem objetivo")
	check(not lay.get("objective", {}).is_empty(), tag + ": objetivo definido")
	var cp := Vector2i(-1, -1)
	var shrine_room := -1
	var bosses := 0
	for e in lay["entities"]:
		if e["type"] == "checkpoint":
			cp = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
			shrine_room = int(e["room"])
		if e["type"] == "boss":
			bosses += 1
	check(cp.x >= 0, tag + ": santuário com checkpoint")
	eq(bosses, 1 if str(params["boss"]) != "" else 0, tag + ": chefe")
	for e in lay["entities"]:
		if e["type"] in ["enemy", "flyer"]:
			check(int(e["room"]) != shrine_room, tag + ": nenhum inimigo no santuário")
	# portões nas bordas certas + ponto de chegada
	for pt in lay["ports"]:
		var room: Dictionary = lay["rooms"][int(pt["room"])]
		var rr: Array = room["rect"]
		var ok := false
		match str(pt["dir"]):
			"L": ok = int(rr[0]) == 0
			"R": ok = int(rr[0]) + int(rr[2]) == int(lay["width"])
			"U": ok = int(rr[1]) == 0
			"D": ok = int(rr[1]) + int(rr[3]) == int(lay["height"])
		check(ok, tag + ": portão %s na borda" % pt["dir"])
		check(int(pt["spawn"][0]) >= 0, tag + ": chegada do portão %s" % pt["dir"])
	# alcance nos dois sentidos (modelo conservador)
	var rm := ReachMap.new(rows)
	rm.build()
	var root := rm.seg_at(cp.x, cp.y)
	check(root >= 0, tag + ": santuário em pé")
	if root < 0:
		return
	var fwd := rm.reach_from(root)
	var bwd := rm.reach_from(root, true)
	var bad := 0
	var targets: Array = []
	for e in lay["entities"]:
		if e.get("anchor", false):
			targets.append([Vector2i(int(e["tile"][0]), int(e["tile"][1])), e["type"]])
	for pt in lay["ports"]:
		targets.append([Vector2i(int(pt["spawn"][0]), int(pt["spawn"][1])), "portão " + str(pt["dir"])])
	for t in targets:
		var s := rm.seg_at(t[0].x, t[0].y)
		if s < 0 or fwd[s] == 0 or bwd[s] == 0:
			bad += 1
			if bad <= 3:
				print("    %s: %s em %s não alcançável (seg %d)" % [tag, t[1], str(t[0]), s])
	eq(bad, 0, tag + ": tudo alcançável do santuário e de volta")


func _dump(lay: Dictionary, path: String) -> void:
	var rows: PackedStringArray = lay["rows"].duplicate()
	var marks := {"checkpoint": "H", "boss": "M", "enemy": "E", "flyer": "F", "chest": "C", "relic": "R", "npc": "N",
		"sign": "s", "gate": "G", "lever": "T", "ability_gate": "V", "breakable": "B", "torch": "L", "impeto_orb": "I",
		"inscription": "i", "quest_board": "Q", "rift": "Y", "altar": "A", "spawn": "P"}
	for e in lay["entities"]:
		var x := int(e["tile"][0])
		var y := int(e["tile"][1])
		var ch: String = marks.get(e["type"], "?")
		var line: String = rows[y]
		rows[y] = line.substr(0, x) + ch + line.substr(x + 1)
	var f := FileAccess.open(path, FileAccess.WRITE)
	for room in lay["rooms"]:
		f.store_line("%d %s %s %s %s" % [int(room["index"]), room["kind"], room["name"], str(room["rect"]), room["type"]])
	f.store_line(str(lay.get("objective", {})))
	for r in rows:
		f.store_line(r)
