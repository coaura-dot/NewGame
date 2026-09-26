class_name RoomSynth
extends RefCounted
## Gera salas proceduralmente para QUALQUER combinação de saídas, montando
## "módulos" (escada de plataformas, pilares, fosso de espinhos, arena...).
## Complementa os templates feitos à mão: se não houver template para o tipo e
## as saídas pedidas, o gerador usa isto — nunca falha.

const W := LevelConst.ROOM_W
const H := LevelConst.ROOM_H


static func synth(room_type: String, exits: String, rng: RandomNumberGenerator, opts: Dictionary = {}) -> PackedStringArray:
	var g := blank()
	frame(g, exits)
	match room_type:
		"combat": _combat(g, rng, exits, opts)
		"platforming": _gauntlet(g, rng, exits, false)
		"challenge": _gauntlet(g, rng, exits, true)
		"corridor": _corridor(g, rng, exits)
		"puzzle": _puzzle(g, rng, exits, opts)
		"treasure": _treasure(g, rng)
		"secret": _secret(g, rng)
		"entrance": _entrance(g, exits)
		"exit": _exit(g)
		"hub": _hub(g)
		"boss": _boss(g)
		"shaft": pass
	if exits.contains("U"):
		ladder(g, rng)
	_decorate(g, rng, opts)
	return to_rows(g)


static func blank() -> Array:
	var g := []
	for y in H:
		var row := []
		row.resize(W)
		row.fill(".")
		g.append(row)
	return g


static func to_rows(g: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for row in g:
		out.append("".join(row))
	return out


static func from_rows(rows: PackedStringArray) -> Array:
	var g := []
	for r in rows:
		var row := []
		for i in r.length():
			row.append(r[i])
		g.append(row)
	return g


static func put(g: Array, x: int, y: int, c: String) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		g[y][x] = c


static func fill(g: Array, x0: int, y0: int, x1: int, y1: int, c: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			put(g, x, y, c)


static func frame(g: Array, exits: String) -> void:
	fill(g, 0, 0, W - 1, 0, "#")
	fill(g, 0, LevelConst.FLOOR_ROW, W - 1, H - 1, "#")
	fill(g, 0, 0, 0, H - 1, "#")
	fill(g, W - 1, 0, W - 1, H - 1, "#")
	open_exits(g, exits)


static func open_exits(g: Array, exits: String) -> void:
	for e in exits:
		match e:
			"L":
				for y in LevelConst.EXIT_LR_ROWS:
					put(g, 0, y, ".")
			"R":
				for y in LevelConst.EXIT_LR_ROWS:
					put(g, W - 1, y, ".")
			"U":
				for x in LevelConst.EXIT_UD_COLS:
					put(g, x, 0, ".")
			"D":
				for x in LevelConst.EXIT_UD_COLS:
					for y in range(LevelConst.FLOOR_ROW, H):
						put(g, x, y, ".")
					put(g, x, H - 1, "-")


## Sela uma saída (usado pelo gerador para saídas que o template suporta mas a
## fase não usa).
static func seal_exit(g: Array, e: String) -> void:
	match e:
		"L":
			for y in LevelConst.EXIT_LR_ROWS:
				put(g, 0, y, "#")
		"R":
			for y in LevelConst.EXIT_LR_ROWS:
				put(g, W - 1, y, "#")
		"U":
			for x in LevelConst.EXIT_UD_COLS:
				put(g, x, 0, "#")
		"D":
			for x in LevelConst.EXIT_UD_COLS:
				for y in range(LevelConst.FLOOR_ROW, H):
					put(g, x, y, "#")


## Escada de plataformas one-way do chão até a saída de cima.
static func ladder(g: Array, rng: RandomNumberGenerator) -> void:
	var rows := [18, 15, 12, 9, 6]
	var left := rng.randf() < 0.5
	for y in rows:
		var x0 := (11 if left else 23) + rng.randi_range(-2, 2)
		for x in range(x0, x0 + 6):
			if g[y][x] == ".":
				g[y][x] = "-"
		left = not left
	for x in range(16, 24):
		if g[2][x] == ".":
			g[2][x] = "-"


static func _free_floor_x(rng: RandomNumberGenerator, exits: String) -> int:
	for i in 20:
		var x := rng.randi_range(5, W - 6)
		if exits.contains("D") and x >= 16 and x <= 23:
			continue
		return x
	return 8


static func _combat(g: Array, rng: RandomNumberGenerator, exits: String, opts: Dictionary) -> void:
	var tier := int(opts.get("tier", 1))
	# pilares/obstáculos
	for i in rng.randi_range(0, 2):
		var x := _free_floor_x(rng, exits)
		var h := rng.randi_range(1, 3)
		fill(g, x, LevelConst.FLOOR_ROW - h, x + 1, LevelConst.FLOOR_ROW - 1, "#")
	# plataformas
	for i in rng.randi_range(1, 3):
		var y := rng.randi_range(11, 16)
		var x := rng.randi_range(4, W - 12)
		for xx in range(x, x + rng.randi_range(4, 8)):
			if g[y][xx] == ".":
				g[y][xx] = "-"
	var ground := rng.randi_range(2, 3) + (tier - 1)
	for i in ground:
		var x := _free_floor_x(rng, exits)
		if g[LevelConst.FLOOR_ROW - 1][x] == ".":
			g[LevelConst.FLOOR_ROW - 1][x] = "E"
	for i in rng.randi_range(0, 1 + tier / 2):
		put(g, rng.randi_range(6, W - 7), rng.randi_range(6, 10), "F")


## Fosso de espinhos com pilares/plataformas (plataforma = Celeste; challenge =
## "caminho da dor").
static func _gauntlet(g: Array, rng: RandomNumberGenerator, exits: String, hard: bool) -> void:
	var fl := LevelConst.FLOOR_ROW
	for x in range(4, W - 4):
		if exits.contains("D") and x >= 18 and x <= 21:
			continue
		g[fl][x] = "^"
	var x := 4
	var y_top := fl - 3
	var guard := 0
	while x < W - 9 and guard < 20:
		guard += 1
		var gap := rng.randi_range(4, 7) if hard else rng.randi_range(3, 5)
		var nx := x + gap
		if nx > W - 7:
			break
		var ny := clampi(y_top + rng.randi_range(-3, 3), 13, fl - 2)
		var width := rng.randi_range(2, 3) if hard else rng.randi_range(2, 4)
		if rng.randf() < 0.55:
			fill(g, nx, ny, nx + width - 1, fl, "#") # pilar
		else:
			fill(g, nx, ny, nx + width - 1, ny, "#") # bloco flutuante
		if gap >= 5:
			put(g, x + gap / 2 + 1, mini(ny, y_top) - 3, "D")
		if hard and rng.randf() < 0.5:
			put(g, x + gap / 2 + 1, mini(ny, y_top) - 6, "S")
		x = nx + width
		y_top = ny
	if hard:
		put(g, W - 3, fl - 1, "R")


static func _corridor(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	if not exits.contains("U") and rng.randf() < 0.6:
		# teto baixo com vão central
		var depth := rng.randi_range(6, 10)
		fill(g, 1, 1, W - 2, depth, "#")
		fill(g, 14, depth - 3, 25, depth, ".")
	for i in rng.randi_range(0, 2):
		var x := _free_floor_x(rng, exits)
		put(g, x, LevelConst.FLOOR_ROW - 1, "E")
	if rng.randf() < 0.3:
		put(g, _free_floor_x(rng, exits), LevelConst.FLOOR_ROW - 1, "C")


static func _puzzle(g: Array, rng: RandomNumberGenerator, exits: String, opts: Dictionary) -> void:
	var entry: String = opts.get("entry", "L")
	# alavanca no alto, alcançável por plataformas
	var lx := 6 if entry == "R" else W - 8
	fill(g, lx - 2, 8, lx + 2, 8, "-")
	put(g, lx, 7, "T")
	for i in 3:
		var py := 17 - i * 3
		var px := lx + (6 if entry == "R" else -6) * (1 if i % 2 == 0 else 2) - 2
		px = clampi(px, 2, W - 8)
		fill(g, px, py, px + 4, py, "-")
	# portões nas outras saídas
	for e in exits:
		if e == entry:
			continue
		match e:
			"L": put(g, 0, 17, "G")
			"R": put(g, W - 1, 17, "G")
	# bloco quebrável escondendo baú
	if rng.randf() < 0.5:
		fill(g, 18, 18, 21, 20, "B")
		put(g, 19, 20, "C")


static func _treasure(g: Array, rng: RandomNumberGenerator) -> void:
	fill(g, 17, 19, 22, 20, "#")
	put(g, 19 + rng.randi_range(0, 1), 18, "C")
	put(g, 19, 2, "W")


static func _secret(g: Array, rng: RandomNumberGenerator) -> void:
	fill(g, 1, 1, W - 2, 6, "#")
	fill(g, 18, 19, 21, 20, "#")
	put(g, 19, 18, "R" if rng.randf() < 0.5 else "C")


static func _entrance(g: Array, exits: String) -> void:
	var x := 8 if not exits.contains("L") else 30
	put(g, x, LevelConst.FLOOR_ROW - 1, "P")
	put(g, 20 if not exits.contains("D") else 26, LevelConst.FLOOR_ROW - 1, "H")


static func _exit(g: Array) -> void:
	put(g, 28, LevelConst.FLOOR_ROW - 1, "X")


static func _hub(g: Array) -> void:
	for x in [6, 12, 27, 33]:
		put(g, x, LevelConst.FLOOR_ROW - 1, "N")
	put(g, 20, LevelConst.FLOOR_ROW - 1, "Q")
	put(g, 16, LevelConst.FLOOR_ROW - 1, "H")


static func _boss(g: Array) -> void:
	fill(g, 6, 12, 12, 12, "-")
	fill(g, 27, 12, 33, 12, "-")
	put(g, 24, 18, "M")
	put(g, 0, 17, "G")
	put(g, W - 1, 17, "G")
	put(g, 10, LevelConst.FLOOR_ROW - 1, "A")


static func _decorate(g: Array, rng: RandomNumberGenerator, opts: Dictionary) -> void:
	for i in rng.randi_range(1, 3):
		var x := rng.randi_range(3, W - 4)
		var y := rng.randi_range(3, 8)
		if g[y][x] == ".":
			g[y][x] = "L"
	if opts.get("indoor", false) and rng.randf() < 0.5:
		var x := rng.randi_range(6, W - 7)
		if g[1][x] == ".":
			g[1][x] = "W"
