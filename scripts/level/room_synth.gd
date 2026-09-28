class_name RoomSynth
extends RefCounted
## Gera salas proceduralmente para QUALQUER combinação de saídas, na escala de
## 8 px (sala 40x24 = uma tela, como em Celeste). Monta relevo de chão em
## degraus, tetos com saliências, fossos com espinhos, blocos flutuantes,
## escaladas em zigue-zague e os elementos de cada tipo de sala. Toda sala
## gerada passa pelo RoomReach (travessia com o pulo/dash reais do herói);
## se falhar, tenta de novo e, no limite, usa um layout simples garantido.

const W := LevelConst.ROOM_W
const H := LevelConst.ROOM_H
const FLOOR := LevelConst.FLOOR_ROW
const TRIES := 16

## Tipos que podem exigir dash para atravessar (plataforma/desafio).
const DASH_TYPES := ["platforming", "challenge"]


static func synth(room_type: String, exits: String, rng: RandomNumberGenerator, opts: Dictionary = {}) -> PackedStringArray:
	var mode := "dash" if room_type in DASH_TYPES else "jump"
	for attempt in TRIES:
		var g := _build(room_type, exits, rng, opts)
		if RoomReach.check_room(g, exits, mode) == "":
			return to_rows(g)
	for attempt in 6:
		var s := _safe(room_type, exits, rng, opts)
		if RoomReach.check_room(s, exits, mode) == "":
			return to_rows(s)
	# último recurso: só a moldura e a escada
	var g2 := blank()
	frame(g2, exits)
	if exits.contains("U"):
		ladder(g2, rng)
	return to_rows(g2)


static func _build(room_type: String, exits: String, rng: RandomNumberGenerator, opts: Dictionary) -> Array:
	var g := blank()
	frame(g, exits)
	match room_type:
		"combat": _combat(g, rng, exits, opts)
		"platforming": _gauntlet(g, rng, exits, false)
		"challenge": _gauntlet(g, rng, exits, true)
		"corridor": _corridor(g, rng, exits)
		"shaft": _shaft(g, rng, exits)
		"puzzle": _puzzle(g, rng, exits, opts)
		"treasure": _treasure(g, rng, exits)
		"secret": _secret(g, rng, exits)
		"entrance": _entrance(g, rng, exits)
		"exit": _exit(g, rng, exits)
		"hub": _hub(g, rng, exits)
		"boss": _boss(g, rng, exits)
	if exits.contains("U"):
		ladder(g, rng)
	_decorate(g, rng, opts)
	return g


## Layout simples e sempre atravessável (chão reto + escada para cima).
static func _safe(room_type: String, exits: String, rng: RandomNumberGenerator, opts: Dictionary) -> Array:
	var g := blank()
	frame(g, exits)
	match room_type:
		"entrance": _put_on_floor(g, 8 if not exits.contains("L") else 30, "P")
		"exit": _put_on_floor(g, 28, "X")
		"hub": _hub(g, rng, exits)
		"boss": _boss(g, rng, exits)
		"treasure": _put_on_floor(g, 12, "C")
		"secret": _put_on_floor(g, 12, "R")
		"challenge": _put_on_floor(g, 12, "R")
		"combat", "corridor":
			_put_on_floor(g, 12, "E")
			_put_on_floor(g, 27, "E")
	if exits.contains("U"):
		ladder(g, rng)
	_decorate(g, rng, opts)
	return g


# ---------------------------------------------------------------------------
# Grade
# ---------------------------------------------------------------------------

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


static func at(g: Array, x: int, y: int) -> String:
	if x < 0 or x >= W or y < 0 or y >= H:
		return "#"
	return g[y][x]


static func fill(g: Array, x0: int, y0: int, x1: int, y1: int, c: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			put(g, x, y, c)


## Preenche só células vazias.
static func fill_empty(g: Array, x0: int, y0: int, x1: int, y1: int, c: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if at(g, x, y) == ".":
				put(g, x, y, c)


static func frame(g: Array, exits: String) -> void:
	fill(g, 0, 0, W - 1, 0, "#")
	fill(g, 0, FLOOR, W - 1, H - 1, "#")
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
					for y in range(FLOOR, H):
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
				for y in range(FLOOR, H):
					put(g, x, y, "#")


## Colunas que precisam ficar livres (portas e poços das saídas).
static func _reserved(exits: String) -> Dictionary:
	var r := {}
	if exits.contains("L"):
		for x in range(1, 4):
			r[x] = true
	if exits.contains("R"):
		for x in range(W - 4, W - 1):
			r[x] = true
	if exits.contains("D"):
		for x in range(LevelConst.EXIT_UD_COLS[0] - 2, LevelConst.EXIT_UD_COLS[-1] + 3):
			r[x] = true
	return r


## Topo do chão na coluna x (primeira célula sólida de cima para baixo a partir de y0).
static func floor_top(g: Array, x: int, y0: int = 2) -> int:
	for y in range(y0, H):
		var c := at(g, x, y)
		if c == "#" or c == "-" or c == "^":
			return y
	return H


## Coloca uma entidade em pé no chão da coluna x.
static func _put_on_floor(g: Array, x: int, ch: String) -> bool:
	var top := floor_top(g, x)
	if top <= 2 or top >= H or at(g, x, top) == "^":
		return false
	if at(g, x, top - 1) != "." or at(g, x, top - 2) != ".":
		return false
	put(g, x, top - 1, ch)
	return true


## Escada de plataformas one-way do chão até a saída de cima (degraus de 3
## tiles, alternando lados perto do centro — alcançável só com pulo).
static func ladder(g: Array, rng: RandomNumberGenerator) -> void:
	var cx := 19
	var left := rng.randf() < 0.5
	var y := FLOOR - 3
	# se o chão embaixo do poço estiver mais alto, começa dele
	var base := floor_top(g, cx, 3)
	if base < FLOOR:
		y = base - 3
	while y >= 3:
		# degraus alternados perto do centro: vão máximo de 4 tiles ao subir 3
		var x0 := (cx - 4 + rng.randi_range(-1, 0)) if left else (cx + 2 + rng.randi_range(0, 1))
		# degraus variados: plataforma fina ou bloco sólido
		var ch := "-" if rng.randf() < 0.5 or y <= 4 else "#"
		var w := 5 if ch == "-" else rng.randi_range(3, 5)
		if ch == "#" and left:
			x0 += 5 - w # bloco encostado no lado de dentro
		for x in range(x0, x0 + w):
			if at(g, x, y) == "." and at(g, x, y - 1) != "#" and at(g, x, y + 1) != "#":
				g[y][x] = ch
		left = not left
		y -= 3
	for x in range(LevelConst.EXIT_UD_COLS[0] - 2, LevelConst.EXIT_UD_COLS[-1] + 3):
		if at(g, x, 3) == ".":
			g[3][x] = "-"


# ---------------------------------------------------------------------------
# Relevo
# ---------------------------------------------------------------------------

## Chão em degraus: blocos de 3-8 colunas subindo/descendo até "max_rise".
static func _terrain(g: Array, rng: RandomNumberGenerator, exits: String, max_rise: int = 3, flat_chance: float = 0.4) -> void:
	var res := _reserved(exits)
	var x := 1
	var level := 0
	while x < W - 1:
		var w := rng.randi_range(3, 8)
		var next := level
		if rng.randf() > flat_chance:
			next = clampi(level + rng.randi_range(-2, 2), 0, max_rise)
		for xx in range(x, mini(x + w, W - 1)):
			var lv := 0 if res.has(xx) else next
			if lv > 0:
				fill(g, xx, FLOOR - lv, xx, FLOOR - 1, "#")
		level = next
		x += w


## Saliências no teto (deixando no mínimo "clear" tiles livres sobre o chão).
static func _ceiling(g: Array, rng: RandomNumberGenerator, exits: String, max_depth: int = 6, clear: int = 7) -> void:
	var x := 1
	while x < W - 1:
		var w := rng.randi_range(3, 9)
		var depth := rng.randi_range(1, max_depth) if rng.randf() < 0.75 else 0
		for xx in range(x, mini(x + w, W - 1)):
			if exits.contains("U") and xx >= LevelConst.EXIT_UD_COLS[0] - 7 and xx <= LevelConst.EXIT_UD_COLS[-1] + 7:
				continue
			var top := floor_top(g, xx, 1)
			var d := mini(depth, top - clear - 1)
			if d > 0:
				fill(g, xx, 1, xx, d, "#")
		x += w


## Bloco/plataforma flutuante (sólido ou one-way).
static func _ledge(g: Array, x: int, y: int, w: int, solid: bool) -> void:
	for xx in range(x, x + w):
		if at(g, xx, y) == "." and at(g, xx, y + 1) != "#":
			g[y][xx] = "#" if solid else "-"


# ---------------------------------------------------------------------------
# Tipos de sala
# ---------------------------------------------------------------------------

static func _combat(g: Array, rng: RandomNumberGenerator, exits: String, opts: Dictionary) -> void:
	var tier := int(opts.get("tier", 1))
	_terrain(g, rng, exits, 3, 0.5)
	_ceiling(g, rng, exits, 7, 9)
	# 1-3 ledges para lutar em altura
	for i in rng.randi_range(1, 3):
		var x := rng.randi_range(4, W - 12)
		var top := floor_top(g, x + 2)
		var y := top - rng.randi_range(3, 4)
		_ledge(g, x, y, rng.randi_range(4, 7), rng.randf() < 0.35)
	# pilar baixo para se proteger/pular
	if rng.randf() < 0.5:
		var px := rng.randi_range(8, W - 10)
		if not _reserved(exits).has(px):
			var top2 := floor_top(g, px)
			fill(g, px, top2 - 2, px + 1, top2 - 1, "#")
	var n := rng.randi_range(2, 3) + (tier - 1)
	var placed := 0
	for i in 30:
		if placed >= n:
			break
		if _put_on_floor(g, rng.randi_range(6, W - 7), "E"):
			placed += 1
	for i in rng.randi_range(0, 1 + tier / 2):
		put(g, rng.randi_range(8, W - 9), rng.randi_range(5, 9), "F")
	if opts.get("lock", false) or rng.randf() < 0.5:
		for e in exits:
			if e == "L":
				put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
			elif e == "R":
				put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")


## Plataforma (Celeste): fossos com espinhos, blocos e pilares espaçados,
## cristais de dash nos vãos grandes. challenge = "caminho da dor".
static func _gauntlet(g: Array, rng: RandomNumberGenerator, exits: String, hard: bool) -> void:
	var res := _reserved(exits)
	# fosso de espinhos quase de ponta a ponta
	for x in range(4, W - 4):
		if res.has(x):
			continue
		fill(g, x, FLOOR, x, FLOOR + 1, ".")
		put(g, x, FLOOR + 1, "^")
	# pisos de apoio nas pontas
	var x := 4
	var y := FLOOR - 1
	var guard := 0
	while x < W - 6 and guard < 24:
		guard += 1
		var gap := rng.randi_range(3, 5) if not hard else rng.randi_range(4, 8)
		var nx := x + gap
		if nx > W - 6:
			break
		var ny := clampi(y + rng.randi_range(-3, 2), 8, FLOOR)
		var w := rng.randi_range(2, 4) if not hard else rng.randi_range(1, 3)
		var hits_reserved := false
		for xx in range(nx, nx + w):
			if res.has(xx):
				hits_reserved = true
		if hits_reserved:
			x = nx + w
			continue
		var kind := rng.randf()
		if kind < 0.45:
			fill(g, nx, ny, nx + w - 1, FLOOR + 1, "#") # pilar
		elif kind < 0.85:
			fill(g, nx, ny, nx + w - 1, ny + (1 if rng.randf() < 0.5 else 0), "#") # bloco
		else:
			fill(g, nx, ny, nx + w - 1, ny, "-") # plataforma fina
		# espinhos no teto de blocos ou em cima de pilares no modo difícil
		if hard and kind < 0.85 and rng.randf() < 0.3 and w >= 2:
			put(g, nx + w - 1, ny - 1, "^")
		if gap >= 6:
			put(g, x + gap / 2, mini(ny, y) - 2, "D")
		if hard and rng.randf() < 0.45:
			put(g, x + gap / 2, mini(ny, y) - 4, "S")
		if not hard and rng.randf() < 0.15 and at(g, nx, ny - 1) == ".":
			put(g, nx, ny - 1, "J")
		x = nx + w
		y = ny
	if hard:
		_put_on_floor(g, W - 3, "R")
	elif rng.randf() < 0.4:
		put(g, rng.randi_range(10, W - 10), rng.randi_range(4, 7), "F")


static func _corridor(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	_terrain(g, rng, exits, 3, 0.35)
	if not exits.contains("U"):
		_ceiling(g, rng, exits, 12, 5)
	else:
		_ceiling(g, rng, exits, 6, 7)
	for i in rng.randi_range(1, 2):
		_put_on_floor(g, rng.randi_range(6, W - 7), "E")
	if rng.randf() < 0.3:
		_put_on_floor(g, rng.randi_range(6, W - 7), "C")
	if rng.randf() < 0.35:
		# bloco quebrável escondendo algo no chão
		var bx := rng.randi_range(8, W - 10)
		if not _reserved(exits).has(bx):
			var top := floor_top(g, bx)
			fill(g, bx, top - 2, bx + 1, top - 1, "B")


## Poço vertical: paredes grossas, zigue-zague de ledges e inimigos voadores.
static func _shaft(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	var res := _reserved(exits)
	# engrossa as paredes (deixa as portas livres)
	var inset := rng.randi_range(4, 8)
	for yy in range(1, FLOOR):
		for xx in range(1, inset):
			if not res.has(xx):
				put(g, xx, yy, "#")
		for xx in range(W - inset, W - 1):
			if not res.has(xx):
				put(g, xx, yy, "#")
	# abre as portas laterais de novo com corredor curto
	for e in exits:
		if e == "L":
			fill(g, 1, LevelConst.EXIT_LR_ROWS[0], inset + 1, LevelConst.EXIT_LR_ROWS[-1], ".")
		elif e == "R":
			fill(g, W - inset - 2, LevelConst.EXIT_LR_ROWS[0], W - 2, LevelConst.EXIT_LR_ROWS[-1], ".")
	# ledges saindo das paredes
	var y := FLOOR - 3
	var left := rng.randf() < 0.5
	while y > 4:
		var w := rng.randi_range(3, 6)
		if left:
			_ledge(g, inset, y, w, rng.randf() < 0.5)
		else:
			_ledge(g, W - inset - w, y, w, rng.randf() < 0.5)
		left = not left
		y -= 3
	for i in rng.randi_range(1, 2):
		put(g, rng.randi_range(inset + 3, W - inset - 4), rng.randi_range(5, 15), "F")
	if rng.randf() < 0.5:
		put(g, W / 2, rng.randi_range(8, 14), "D")


static func _puzzle(g: Array, rng: RandomNumberGenerator, exits: String, opts: Dictionary) -> void:
	var entry: String = opts.get("entry", "L")
	_terrain(g, rng, exits, 2, 0.6)
	# alavanca num ledge alto, alcançável por uma escadinha de ledges
	var lx := 7 if entry == "R" else W - 9
	var top := floor_top(g, lx)
	var ly := top - 9
	fill(g, lx - 2, ly, lx + 2, ly, "#")
	put(g, lx, ly - 1, "T")
	var sx := lx + (5 if entry == "R" else -9)
	for i in range(1, 3):
		_ledge(g, clampi(sx + (i % 2) * (3 if entry == "R" else -3), 2, W - 7), top - i * 3, 4, false)
	for e in exits:
		if e == entry:
			continue
		match e:
			"L": put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
			"R": put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")
	if rng.randf() < 0.5:
		var bx := W / 2 - 2
		var bt := floor_top(g, bx)
		fill(g, bx, bt - 3, bx + 3, bt - 1, "B")
		put(g, bx + 1, bt - 1, "C")


static func _treasure(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	_ceiling(g, rng, exits, 4, 10)
	var cx := W / 2 + rng.randi_range(-4, 4)
	if exits.contains("D") or exits.contains("U"):
		cx = 9 if rng.randf() < 0.5 else W - 10
	fill(g, cx - 3, FLOOR - 2, cx + 3, FLOOR - 1, "#")
	put(g, cx, FLOOR - 3, "C")
	if at(g, cx, 1) == ".":
		put(g, cx, 1, "W")
	put(g, cx - 5, 6, "L")
	put(g, cx + 5, 6, "L")


static func _secret(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	# sala pequena e aconchegante: paredes grossas (sem tapar a saída de cima)
	fill(g, 1, 1, W - 2, 8, "#")
	if exits.contains("U"):
		fill(g, LevelConst.EXIT_UD_COLS[0] - 2, 1, LevelConst.EXIT_UD_COLS[-1] + 2, 8, ".")
	var cx := W / 2
	if exits.contains("D") or exits.contains("U"):
		cx = 9 if rng.randf() < 0.5 else W - 10
	fill(g, cx - 2, FLOOR - 1, cx + 2, FLOOR - 1, "#")
	put(g, cx, FLOOR - 2, "R" if rng.randf() < 0.6 else "C")
	put(g, cx - 6, 11, "L")
	put(g, cx + 6, 11, "L")


static func _entrance(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	_ceiling(g, rng, exits, 4, 10)
	var px := 8 if not exits.contains("L") else 30
	_put_on_floor(g, px, "P")
	_put_on_floor(g, 20 if not exits.contains("D") else 26, "H")
	# uns degraus de boas-vindas (ensina o pulo)
	var sx := 12 if px < 20 else 22
	if not _reserved(exits).has(sx) and not _reserved(exits).has(sx + 4):
		fill(g, sx, FLOOR - 1, sx + 5, FLOOR - 1, "#")
		fill(g, sx + 2, FLOOR - 2, sx + 3, FLOOR - 2, "#")


static func _exit(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	_ceiling(g, rng, exits, 4, 10)
	var x := 28 if not exits.contains("R") else 12
	fill(g, x - 3, FLOOR - 1, x + 3, FLOOR - 1, "#")
	put(g, x, FLOOR - 2, "X")
	put(g, x - 4, 12, "L")
	put(g, x + 4, 12, "L")


static func _hub(g: Array, _rng: RandomNumberGenerator, exits: String) -> void:
	# praça: chão plano, telhadinhos (one-way) e os moradores
	for x in [5, 11, 28, 34]:
		_put_on_floor(g, x, "N")
	_put_on_floor(g, 20 if not exits.contains("D") else 25, "Q")
	_put_on_floor(g, 15, "H")
	_ledge(g, 3, FLOOR - 7, 7, false)
	_ledge(g, W - 10, FLOOR - 7, 7, false)
	put(g, 8, 8, "L")
	put(g, W - 9, 8, "L")


static func _boss(g: Array, _rng: RandomNumberGenerator, exits: String) -> void:
	_ledge(g, 6, FLOOR - 5, 6, false)
	_ledge(g, W - 12, FLOOR - 5, 6, false)
	if not exits.contains("U"):
		_ledge(g, 16, FLOOR - 10, 8, false)
	put(g, 26, FLOOR - 4, "M")
	put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
	put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")
	_put_on_floor(g, 10, "A")


# ---------------------------------------------------------------------------
# Decoração
# ---------------------------------------------------------------------------

static func _decorate(g: Array, rng: RandomNumberGenerator, opts: Dictionary) -> void:
	# tochas presas em paredes/pilares (célula vazia colada a um sólido)
	var torches := 0
	for i in 40:
		if torches >= rng.randi_range(1, 3):
			break
		var x := rng.randi_range(2, W - 3)
		var y := rng.randi_range(4, 15)
		if g[y][x] != ".":
			continue
		if at(g, x - 1, y) == "#" or at(g, x + 1, y) == "#" or rng.randf() < 0.15:
			g[y][x] = "L"
			torches += 1
	if opts.get("indoor", false) and rng.randf() < 0.5:
		var x := rng.randi_range(6, W - 7)
		if g[1][x] == "." and at(g, x, 2) == ".":
			g[1][x] = "W"
