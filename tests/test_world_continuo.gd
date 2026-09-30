extends "res://tests/test_case.gd"
## Mundo contínuo: regiões em grade (céu/superfície/subsolo), portões nas
## bordas das fases na direção certa e chegada no portão de onde se veio.


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func test_portoes_nas_bordas() -> void:
	for s in [11, 22, 33]:
		var w := WorldGenerator.generate(s, DB)
		for id in w["regions"].keys():
			var r: Dictionary = w["regions"][id]
			var ports := WorldGenerator.ports(w, id)
			if r.get("dimension", "prima") == "prima":
				check(ports.size() >= 1, "seed %d %s: sem portões" % [s, id])
			var params := {"seed": int(r["level_seed"]), "biome": r["biome"], "tier": int(r["tier"]), "boss": r.get("boss", ""),
				"hub": r.get("hub", ""), "dimension": r.get("dimension", "prima"), "npcs": [], "abilities": [], "ports": ports,
				"layer": r.get("layer", "")}
			var lay := RegionDesigner.generate(params, DB)
			eq(lay["ports"].size(), ports.size(), "seed %d %s: todos os portões na fase" % [s, id])
			var rows: PackedStringArray = lay["rows"]
			for pt in lay["ports"]:
				var rr: Array = lay["rooms"][int(pt["room"])]["rect"]
				var x0: int = int(rr[0])
				var y0: int = int(rr[1])
				var x1: int = x0 + int(rr[2]) - 1
				var y1: int = y0 + int(rr[3]) - 1
				var edge_ok := false
				var open := false
				match str(pt["dir"]):
					"L":
						edge_ok = x0 == 0
						for y in range(y0, y1 + 1):
							open = open or rows[y][0] != "#"
					"R":
						edge_ok = x1 == int(lay["width"]) - 1
						for y in range(y0, y1 + 1):
							open = open or rows[y][x1] != "#"
					"U":
						edge_ok = y0 == 0
						for x in range(x0, x1 + 1):
							open = open or rows[0][x] != "#"
					"D":
						edge_ok = y1 == int(lay["height"]) - 1
						for x in range(x0, x1 + 1):
							open = open or rows[y1][x] != "#"
				check(edge_ok, "seed %d %s: portão %s na borda" % [s, id, pt["dir"]])
				check(open, "seed %d %s: abertura do portão %s" % [s, id, pt["dir"]])
			# sem porta de saída no mundo contínuo
			var exits := 0
			for e in lay["entities"]:
				if e["type"] == "exit":
					exits += 1
			eq(exits, 0, "seed %d %s: sem porta de saída" % [s, id])


func test_chega_pelo_portao_certo() -> void:
	Game.new_game(4321, 8)
	var start: String = Game.world["start"]
	var ports := WorldGenerator.ports(Game.world, start)
	var right: Dictionary = {}
	for pt in ports:
		if pt["dir"] == "R":
			right = pt
	check(not right.is_empty(), "região inicial tem vizinha à direita")
	Game.pending = {"region": start}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(level)
	await _frames(10)
	check(level.world_mode, "modo mundo contínuo")
	eq(level._ports.size(), ports.size(), "gatilhos dos portões")
	check(level.map_screen != null, "mapa disponível")
	check(Game.profile.get("maps", {}).has(start), "mapa da região registrado")
	level.queue_free()
	await _frames(3)
	Game.pending = {"region": right["to"], "from": start}
	var level2: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(level2)
	await _frames(10)
	var back: Dictionary = {}
	for pt in level2._ports:
		if pt["to"] == start:
			back = pt
	eq(str(back.get("dir", "")), "L", "vizinha da direita volta pela esquerda")
	var inside: bool = (back["room_rect"] as Rect2).grow(8).has_point(level2.player.global_position)
	check(inside, "nasce no portão de onde veio")
	level2.queue_free()
	await _frames(3)
	SaveSystem.delete_save(8)
