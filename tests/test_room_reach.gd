extends "res://tests/test_case.gd"
## Salas atravessáveis com a física REAL do jogador (RoomReach simula pulos).
## Templates feitos à mão e salas do sintetizador: toda saída precisa levar a
## toda outra saída (ida e volta), sem depender de dash — exceto salas de
## desafio, que podem exigir dash.

var lib := ChunkLibrary.new()


func _report_room(label: String, rows: PackedStringArray, exits: String, dash: bool) -> PackedStringArray:
	var rr := RoomReach.new(rows, dash)
	var fails := rr.check_all(exits)
	if not fails.is_empty() and OS.get_environment("REACH_VERBOSE") != "":
		print("    %s [%s] falhou: %s" % [label, exits, ", ".join(fails)])
		for y in rows.size():
			print("      " + rows[y])
	return fails


## Toda estrutura, em TODAS as combinações dos grupos aleatórios (1 2 3 =
## bloco, 4 5 = espinho). Espelhos não precisam (a física é simétrica).
func test_templates_atravessaveis() -> void:
	var t0 := Time.get_ticks_msec()
	var n := 0
	for t in lib.templates:
		if t.has("mirror_of"):
			continue
		var dash: bool = t["type"] == "challenge"
		var groups: Array = RoomSynth.token_groups(t["rows"])
		for mask in 1 << groups.size():
			var decided := {}
			for gi in groups.size():
				decided[groups[gi]] = (mask >> gi) & 1 == 1
			var g := RoomSynth.from_rows(t["rows"])
			RoomSynth.resolve_tokens(g, null, decided, true)
			var rows := RoomSynth.to_rows(g)
			var label := "%s%s" % [t["id"], (" " + str(decided)) if not decided.is_empty() else ""]
			var fails := _report_room(label, rows, t["exits"], dash)
			check(fails.is_empty(), "template %s: %s" % [label, ", ".join(fails)])
			n += 1
	print("    %d variações de estruturas: %d ms" % [n, Time.get_ticks_msec() - t0])


func test_estruturas_espelhadas_e_tokens() -> void:
	var mirrored := 0
	for t in lib.templates:
		if t.has("mirror_of"):
			mirrored += 1
			var src: Dictionary = lib.get_template(t["mirror_of"])
			eq(t["rows"][10], src["rows"][10].reverse(), "espelho de %s" % t["mirror_of"])
	check(mirrored >= 20, "estruturas espelhadas (%d)" % mirrored)
	check(lib.errors.is_empty(), "biblioteca sem erros: %s" % ", ".join(lib.errors))
	var rng := RngUtil.make(3, "tok")
	var g := RoomSynth.from_rows(lib.get_template("patio_pilares")["rows"])
	RoomSynth.resolve_tokens(g, rng)
	var rows := RoomSynth.to_rows(g)
	for r in rows:
		for c in ["e", "f", "u", "i", "1", "+"]:
			check(not r.contains(c), "token %s resolvido" % c)


func test_sintetizador_atravessavel() -> void:
	var t0 := Time.get_ticks_msec()
	var rng := RngUtil.make(77, "reach")
	var combos := ["LR", "LU", "RD", "LRU", "LRUD"]
	var types := ["combat", "platforming", "corridor", "puzzle", "treasure", "entrance", "exit", "hub", "boss", "shaft", "challenge", "secret"]
	var n := 0
	for t in types:
		for ci in combos.size():
			var ex: String = combos[ci]
			var i := ci % 3
			var rows := RoomSynth.synth(t, ex, rng, {"tier": 1 + i, "entry": ex[0], "indoor": ci % 2 == 0})
			var fails := _report_room("synth:%s" % t, rows, ex, t == "challenge")
			check(fails.is_empty(), "synth %s [%s] #%d: %s" % [t, ex, i, ", ".join(fails)])
			n += 1
	print("    %d salas sintetizadas: %d ms" % [n, Time.get_ticks_msec() - t0])


## "Boa de jogar": cada estrutura precisa de ação (inimigos/perigos),
## elemento aéreo (lanterna, cristal, mola, voador, plataforma que cai),
## verticalidade, e inimigos de chão em lugares alcançáveis.
func test_estruturas_divertidas() -> void:
	var weak: PackedStringArray = []
	for t in lib.templates:
		if t.has("mirror_of") or not t["id"].begins_with("f_") and not t["source"].ends_with("estruturas.txt"):
			continue
		var rows: PackedStringArray = t["rows"]
		var txt := "".join(rows)
		var enemies := 0
		for c in ["E", "e", "U", "u", "F", "f"]:
			enemies += txt.count(c)
		var air := 0
		for c in ["I", "i", "D", "d", "J", "j", "F", "f", "O", "o"]:
			air += txt.count(c)
		var hazards := txt.count("^") + txt.count("S") + txt.count("s")
		var plat_rows := {}
		for y in rows.size():
			if rows[y].contains("-") or rows[y].contains("+") or rows[y].contains("o"):
				plat_rows[y] = true
		var raised := 0
		for y in range(3, LevelConst.FLOOR_ROW):
			for x in range(4, LevelConst.ROOM_W - 4):
				if rows[y][x] == "#" and rows[y - 1][x] != "#" and rows[y + 1][x] == "#":
					raised += 1
		var vertical := plat_rows.size() + (1 if raised > 0 else 0)
		match t["type"]:
			"combat", "arena", "corridor":
				check(enemies >= 4, "%s: ação (%d inimigos)" % [t["id"], enemies])
				check(air >= 1 or hazards >= 2, "%s: elemento aéreo ou perigo" % t["id"])
			"platforming", "challenge":
				check(hazards >= 1, "%s: perigos" % t["id"])
				check(air >= 1, "%s: elemento aéreo" % t["id"])
			"shaft":
				check(plat_rows.size() >= 4, "%s: poço com andares (%d)" % [t["id"], plat_rows.size()])
		check(vertical >= 1, "%s: verticalidade" % t["id"])
		# inimigos de chão alcançáveis (todos os grupos desligados)
		var g := RoomSynth.from_rows(rows)
		var spots: Array[Vector2i] = []
		for y in g.size():
			for x in g[y].size():
				if g[y][x] in ["E", "e", "U", "u"]:
					spots.append(Vector2i(x, y))
		RoomSynth.resolve_tokens(g, null, {"1": false, "2": false, "3": false, "4": false, "5": false}, true)
		var rr := RoomReach.new(RoomSynth.to_rows(g), t["type"] == "challenge")
		rr.search(t["exits"][0])
		for sp in spots:
			var ok := false
			for n in rr.reached.keys():
				if absi(n.x - sp.x) <= 2 and absi(n.y - sp.y) <= 1:
					ok = true
					break
			if not ok:
				weak.append("%s@%s" % [t["id"], sp])
	check(weak.is_empty(), "inimigos em lugar inalcançável: %s" % ", ".join(weak))
