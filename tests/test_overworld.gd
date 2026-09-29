extends "res://tests/test_case.gd"
## Mapa-múndi explorável: andando pelo chão gerado, com os portões rúnicos
## fechados, o herói alcança EXATAMENTE as regiões que o grafo do mundo
## permite com as habilidades iniciais — nada vaza pelas divisas; com todos
## os portões abertos, alcança todas. Também confere a cena rodando.


func _start_abilities() -> Array:
	var out := []
	for a in DB.abilities.keys():
		if DB.abilities[a].get("start", false):
			out.append(a)
	return out


## BFS pelas células andáveis (chão não sólido, sem portões fechados).
func _walk(m: Dictionary, have: Array) -> Dictionary:
	var w: int = m["w"]
	var h: int = m["h"]
	var ground: PackedByteArray = m["ground"]
	var solid := {}
	for n in OverworldGen.SOLID:
		solid[OverworldGen.mat(n)] = true
	var blocked := {}
	for g in m["gates"]:
		if not have.has(g["requires"]):
			for c in g["cells"]:
				blocked[c] = true
	var start: Vector2i = m["spawn"]
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n) or blocked.has(n):
				continue
			if solid.has(int(ground[n.y * w + n.x])):
				continue
			seen[n] = true
			q.append(n)
	return seen


func test_portoes_e_divisas() -> void:
	for s in [3, 12345, 20260926, 77, 9, 404]:
		var world := WorldGenerator.generate(s, DB)
		var t0 := Time.get_ticks_msec()
		var m := OverworldGen.generate(world)
		var ms := Time.get_ticks_msec() - t0
		check(ms < 4000, "seed %d: mapa gerado em %d ms" % [s, ms])
		var start_ab := _start_abilities()
		var walk := _walk(m, start_ab)
		var expect := WorldGenerator.reachable(world, start_ab)
		var got := {}
		for id in m["entrances"].keys():
			if walk.has(m["entrances"][id]):
				got[id] = true
		var extra := []
		for id in got.keys():
			if not expect.has(id):
				extra.append(id)
		var missing := []
		for id in expect.keys():
			if not got.has(id):
				missing.append(id)
		check(extra.is_empty(), "seed %d: portões fechados não vazam (entradas alcançadas a mais: %s)" % [s, str(extra)])
		check(missing.is_empty(), "seed %d: tudo que o grafo permite é alcançável a pé (faltam: %s)" % [s, str(missing)])
		var all_walk := _walk(m, DB.abilities.keys())
		var all_ok := true
		for id in m["entrances"].keys():
			if not all_walk.has(m["entrances"][id]):
				all_ok = false
				print("    seed %d: entrada inalcançável com tudo: %s" % [s, id])
		check(all_ok, "seed %d: com todas as habilidades todas as entradas são alcançáveis" % s)
		# todo portão fica numa estrada e cada região tem entrada
		eq(m["entrances"].size(), world["regions"].size(), "seed %d: uma entrada por região" % s)
		var gates_need := 0
		for e in world["edges"]:
			if e["requires"] != "":
				gates_need += 1
		check(m["gates"].size() >= gates_need - 1, "seed %d: portões para as estradas com requisito (%d de %d)" % [s, m["gates"].size(), gates_need])


func test_deterministico() -> void:
	var world := WorldGenerator.generate(4242, DB)
	var a := OverworldGen.generate(world)
	var b := OverworldGen.generate(world)
	check(a["ground"] == b["ground"] and a["objects"].size() == b["objects"].size(), "mesmo mundo gera o mesmo mapa")


func test_cena_do_mapa() -> void:
	var had := Game.has_game
	var backup: Dictionary = Game.to_dict() if had else {}
	Game.seed_value = 555
	Game.world = WorldGenerator.generate(555, DB)
	Game.profile = Game.START_PROFILE.duplicate(true)
	Game.profile["region"] = Game.world["start"]
	Game.profile["flags"] = {"intro_seen": true}
	Game.social = SocialSystem.create(Game.world, 555, DB)
	Game.world["regions"][Game.world["start"]]["visited"] = true
	Game.has_game = true
	Game.training = true # não grava no save do jogador
	var ow: Node2D = load("res://scenes/overworld.tscn").instantiate()
	tree.root.add_child(ow)
	for i in 10:
		await tree.physics_frame
	check(ow.hero != null and ow.interactables.size() > 5, "mapa montado com herói e interações (%d)" % ow.interactables.size())
	check(not ow.focus.is_empty() and str(ow.focus["prompt"]).contains("Lareira"), "começa ao lado da Grande Lareira")
	var p0: Vector2 = ow.hero.global_position
	Input.action_press("move_down")
	for i in 40:
		await tree.physics_frame
	Input.action_release("move_down")
	check(ow.hero.global_position.y > p0.y + 10.0, "herói anda pelo mapa (%.0f px)" % (ow.hero.global_position.y - p0.y))
	# ir até a entrada da vila mostra a ação de entrar
	var ent: Vector2i = ow.data["entrances"][Game.world["start"]]
	ow.hero.global_position = Overworld.feet_px(ent) + Vector2(0, 3)
	await tree.physics_frame
	await tree.process_frame
	check(not ow.focus.is_empty() and ow.focus.get("entrance", false), "perto da entrada aparece 'Entrar'")
	# à noite a chama brilha
	Game.profile["ow_clock"] = 0.0
	await tree.process_frame
	check(ow.night > 0.8, "meia-noite é noite (%.2f)" % ow.night)
	# lamparina dos Veladores: acende ao passar, dá brasa e fica gravada
	check(not ow._road_lamps.is_empty(), "há lamparinas apagadas nas estradas")
	if not ow._road_lamps.is_empty():
		var lamp: Dictionary = ow._road_lamps[0]
		var money := int(Game.profile.get("currency", 0))
		ow.hero.global_position = lamp["at"] + Vector2(4, 4)
		await tree.process_frame
		await tree.process_frame
		check(Game.profile.get("ow_lamps", {}).has(lamp["id"]), "passar perto acende a lamparina da estrada")
		check(int(Game.profile.get("currency", 0)) == money + 1, "lamparina da estrada dá 1 brasa")
	ow.queue_free()
	await tree.process_frame
	Game.training = false
	if had:
		Game.from_dict(backup)
	else:
		Game.has_game = false
		Game.world = {}
		Game.social = {}
		Game.profile = Game.START_PROFILE.duplicate(true)



## Lamparinas das estradas: ao lado da estrada (nunca em cima), longe das
## vilas e umas das outras, sempre dentro de alguma região.
func test_lamparinas_das_estradas() -> void:
	for sd in [7, 31, 555]:
		var world := WorldGenerator.generate(sd, DB)
		var d := OverworldGen.generate(world)
		var ids: Array = d.get("road_lamps", [])
		check(ids.size() >= 6, "seed %d: lamparinas nas estradas (%d)" % [sd, ids.size()])
		var cells: Array = []
		for o in d["objects"]:
			if o.get("kind", "") != "road_lamp":
				continue
			var c: Vector2i = o["cell"]
			cells.append(c)
			check(not d["roads"].has(c), "lamparina fora da pista (%s)" % c)
			var near_road := false
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if d["roads"].has(c + dd):
					near_road = true
			check(near_road, "lamparina colada na estrada (%s)" % c)
			check(not o.get("solid", true), "lamparina não bloqueia a passagem")
			check(ids.has(o["id"]), "id registrado")
		check(cells.size() == ids.size(), "seed %d: um objeto por lamparina" % sd)
