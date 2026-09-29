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


func test_templates_atravessaveis() -> void:
	var t0 := Time.get_ticks_msec()
	for t in lib.templates:
		var dash: bool = t["type"] == "challenge"
		var fails := _report_room(t["id"], t["rows"], t["exits"], dash)
		check(fails.is_empty(), "template %s: %s" % [t["id"], ", ".join(fails)])
	print("    templates: %d ms" % (Time.get_ticks_msec() - t0))


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
