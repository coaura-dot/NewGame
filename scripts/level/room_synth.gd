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

## Estatística (ferramentas/testes): quantas salas saíram "ricas" x reserva.
static var stats := {"ok": 0, "fallback": 0, "tries": 0}

## Tipos que podem exigir dash para atravessar (plataforma/desafio).
const DASH_TYPES := ["platforming", "challenge"]


static func synth(room_type: String, exits: String, rng: RandomNumberGenerator, opts: Dictionary = {}) -> PackedStringArray:
	var mode := "dash" if room_type in DASH_TYPES else "jump"
	for attempt in TRIES:
		var g := _build(room_type, exits, rng, opts)
		stats["tries"] += 1
		if RoomReach.check_room(g, exits, mode) == "":
			stats["ok"] += 1
			return to_rows(g)
	stats["fallback"] += 1
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
		"platforming": _parkour(g, rng, exits, false, int(opts.get("tier", 1)))
		"challenge": _parkour(g, rng, exits, true, int(opts.get("tier", 1)))
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
	var roll := rng.randf()
	if roll < 0.4:
		_arena_suspensa(g, rng, exits, tier)
	elif roll < 0.65:
		_arena_torre(g, rng, exits, tier)
	else:
		_arena_chao(g, rng, exits, tier)
	# portões: a sala fecha até limpar
	for e in exits:
		if e == "L":
			put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
		elif e == "R":
			put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")


## Arena clássica no chão, com relevo, ledges e orbes para lutar no ar.
static func _arena_chao(g: Array, rng: RandomNumberGenerator, exits: String, tier: int) -> void:
	_terrain(g, rng, exits, 3, 0.5)
	_ceiling(g, rng, exits, 7, 9)
	for i in rng.randi_range(1, 3):
		var x := rng.randi_range(4, W - 12)
		var top := floor_top(g, x + 2)
		_ledge(g, x, top - rng.randi_range(3, 4), rng.randi_range(4, 7), rng.randf() < 0.35)
	for i in rng.randi_range(1, 2):
		put(g, rng.randi_range(8, W - 9), rng.randi_range(9, 13), "I")
	_spawn_enemies(g, rng, 2 + tier, rng.randi_range(0, 1 + tier / 2))


## Arena suspensa: chão de espinhos, ilhas, orbes entre elas e inimigos nas
## ilhas — lutar e pular ao mesmo tempo.
static func _arena_suspensa(g: Array, rng: RandomNumberGenerator, exits: String, tier: int) -> void:
	var res := _reserved(exits)
	_pit(g, res, 4, W - 5)
	var x := 4
	var top := FLOOR
	while x < W - 7:
		var gap := rng.randi_range(2, 4)
		var w := rng.randi_range(4, 8)
		var nx := x + gap
		if nx + w > W - 4:
			break
		if _hits(res, nx, nx + w - 1):
			x = nx + w
			continue
		var ntop := clampi(top + rng.randi_range(-3, 2), FLOOR - 7, FLOOR - 1)
		if rng.randf() < 0.5:
			fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#") # ilha-pilar
		else:
			fill(g, nx, ntop, nx + w - 1, ntop + 1, "#") # ilha flutuante
		if gap >= 3 and rng.randf() < 0.6:
			put(g, x + gap / 2 + 1, mini(top, ntop) - 4, "I")
		x = nx + w
		top = ntop
	_ceiling(g, rng, exits, 4, 11)
	_spawn_enemies(g, rng, 2 + tier, 1 + tier / 2)


## Torre: dois ou três andares de ledges longos, inimigos em cada andar.
static func _arena_torre(g: Array, rng: RandomNumberGenerator, exits: String, tier: int) -> void:
	_terrain(g, rng, exits, 1, 0.7)
	var y := FLOOR - 5
	var floors := 0
	while y > 5 and floors < 3:
		var from_left := rng.randf() < 0.5
		var w := rng.randi_range(16, 26)
		var x0 := 3 if from_left else W - 3 - w
		for xx in range(x0, x0 + w):
			if xx in [LevelConst.EXIT_UD_COLS[0], LevelConst.EXIT_UD_COLS[1]] and exits.contains("U"):
				continue
			if at(g, xx, y) == ".":
				g[y][xx] = "-" if rng.randf() < 0.75 else "#"
		# orbe no vão para subir de andar pelo ar
		var gx := x0 + w + 2 if from_left else x0 - 3
		if gx > 2 and gx < W - 3:
			put(g, gx, y - 2, "I")
		y -= 5
		floors += 1
	_spawn_enemies(g, rng, 2 + tier, rng.randi_range(0, 1 + tier / 2))


## Coloca inimigos de chão em pontos firmes (preferindo ilhas/andares) e
## voadores no ar.
static func _spawn_enemies(g: Array, rng: RandomNumberGenerator, ground: int, flyers: int) -> void:
	var spots: Array = []
	for y in range(3, FLOOR):
		for x in range(5, W - 5):
			if at(g, x, y) == "." and at(g, x, y - 1) == "." and (at(g, x, y + 1) == "#" or at(g, x, y + 1) == "-"):
				spots.append(Vector2i(x, y))
	RngUtil.shuffle(rng, spots)
	var placed: Array = []
	for sp in spots:
		if placed.size() >= ground:
			break
		var ok := true
		for p in placed:
			if absi(p.x - sp.x) < 5 and absi(p.y - sp.y) < 3:
				ok = false
		if ok:
			put(g, sp.x, sp.y, "E")
			placed.append(sp)
	for i in flyers:
		for t in 10:
			var fx := rng.randi_range(7, W - 8)
			var fy := rng.randi_range(5, 12)
			if at(g, fx, fy) == "." and at(g, fx, fy + 1) == ".":
				put(g, fx, fy, "F")
				break


## Fosso de espinhos entre as colunas x0 e x1 (menos as reservadas).
static func _pit(g: Array, res: Dictionary, x0: int, x1: int) -> void:
	for x in range(x0, x1 + 1):
		if res.has(x):
			continue
		fill(g, x, FLOOR, x, FLOOR + 1, ".")
		put(g, x, FLOOR + 1, "^")


static func _hits(res: Dictionary, x0: int, x1: int) -> bool:
	for x in range(x0, x1 + 1):
		if res.has(x):
			return true
	return false


# ---------------------------------------------------------------------------
# Parkour em "batidas" (plataforma / desafio)
# ---------------------------------------------------------------------------

const BEATS_EASY := {"hop": 4.0, "leap": 2.0, "orb": 2.5, "crumble": 1.5, "mover": 1.2, "crystal": 1.5, "chimney": 1.0}
const BEATS_HARD := {"hop": 1.5, "leap": 2.0, "orb": 3.0, "crumble": 2.0, "mover": 1.0, "crystal": 2.5, "chimney": 1.5, "saw": 2.0, "orbchain": 2.0}


## Plataforma/desafio: sequência de batidas da esquerda para a direita sobre
## um fosso de espinhos. hard = "caminho da dor" (vãos maiores, serras,
## cadeias de orbes, inimigos no meio do percurso e relíquia no fim).
static func _parkour(g: Array, rng: RandomNumberGenerator, exits: String, hard: bool, tier: int) -> void:
	var res := _reserved(exits)
	_pit(g, res, 4, W - 5)
	# perfil do percurso: morro, vale, subida, descida ou zigue-zague
	var shape: String = ["hill", "valley", "rise", "fall", "zigzag"][rng.randi() % 5]
	var amp := rng.randi_range(8, 12)
	var x := 3
	var top := FLOOR
	var guard := 0
	var islands: Array = []
	var path := {} ## coluna -> topo do apoio (para esculpir o teto)
	for xx in range(0, 4):
		path[xx] = FLOOR
	var table: Dictionary = BEATS_HARD if hard else BEATS_EASY
	while x < W - 9 and guard < 16:
		guard += 1
		var want := _profile(shape, float(x + 6) / W, amp)
		# o perfil pede subir/descer: favorece batidas verticais
		var t2 := table.duplicate()
		var diff := top - want
		if diff >= 3:
			t2["climb"] = 5.0
			t2["chimney"] = float(t2.get("chimney", 1.0)) * 2.0
			t2["orb"] = float(t2.get("orb", 1.0)) * 1.5
		elif diff <= -3:
			t2["drop"] = 4.0
		var kind: String = RngUtil.weighted_key(rng, t2)
		var r := _beat(g, rng, kind, x, top, hard, res, want)
		if r.is_empty():
			continue
		var nx := int(r["x"])
		var ntop := int(r["top"])
		for xx in range(x + 1, nx + 1):
			path[xx] = mini(top, ntop)
		x = nx
		top = ntop
		if r.has("island"):
			islands.append(r["island"])
	for xx in range(x + 1, W):
		path[xx] = mini(top, FLOOR)
	# ilha final encostada na saída direita (ou no fim do fosso)
	if not exits.contains("R") and x < W - 5:
		fill(g, W - 5, clampi(top, FLOOR - 4, FLOOR), W - 2, FLOOR + 1, "#")
	# teto de caverna acompanhando o percurso (enquadra o parkour)
	var clear := 10 + rng.randi_range(0, 1)
	for xx in range(1, W - 1):
		if exits.contains("U") and xx >= LevelConst.EXIT_UD_COLS[0] - 6 and xx <= LevelConst.EXIT_UD_COLS[-1] + 6:
			continue
		var t: int = path.get(xx, FLOOR)
		var bottom := t - clear - (1 if (xx / 3) % 2 == 0 else 0)
		if bottom >= 1:
			fill_empty(g, xx, 1, xx, bottom, "#")
	# inimigos no meio do percurso: nas ilhas largas e voadores sobre os fossos
	var n_ground := (1 if not hard else 2) + (tier - 1)
	RngUtil.shuffle(rng, islands)
	for isl in islands:
		if n_ground <= 0:
			break
		var ix: int = isl[0]
		var iw: int = isl[1]
		var it: int = isl[2]
		if iw >= 3 and at(g, ix + iw / 2, it - 1) == "." and at(g, ix + iw / 2, it - 2) == ".":
			put(g, ix + iw / 2, it - 1, "E")
			n_ground -= 1
	for i in rng.randi_range(1, 2 + (1 if hard else 0)):
		for t in 8:
			var fx := rng.randi_range(8, W - 9)
			var fy := clampi(int(path.get(fx, FLOOR)) - rng.randi_range(4, 7), 3, FLOOR - 3)
			if at(g, fx, fy) == "." and at(g, fx, fy + 1) == "." and at(g, fx, fy - 1) == ".":
				put(g, fx, fy, "F")
				break
	if hard:
		_put_on_floor(g, W - 3, "R")


## Altura-alvo (linha do topo do apoio) do percurso em t = 0..1.
static func _profile(shape: String, t: float, amp: int) -> int:
	var k := 0.0
	match shape:
		"hill": k = sin(t * PI)
		"valley": k = 1.0 - sin(t * PI)
		"rise": k = t
		"fall": k = 1.0 - t
		"zigzag": k = 0.5 + 0.5 * sin(t * TAU * 1.5)
	return clampi(FLOOR - int(round(k * amp)), 8, FLOOR)


## Uma batida: parte do chão em (x, top) e termina num novo apoio.
## Retorna {x, top, island=[x0, w, top]} ou {} se não couber.
static func _beat(g: Array, rng: RandomNumberGenerator, kind: String, x: int, top: int, hard: bool, res: Dictionary, want: int = -1) -> Dictionary:
	var h := 1 if hard else 0
	if want < 0:
		want = top
	## passo de altura rumo ao perfil (subir no máximo "up" tiles por batida)
	var toward := func(up: int, down: int) -> int:
		var d := clampi(want - top, -up, down)
		return clampi(top + d + rng.randi_range(-1, 0), 8, FLOOR)
	match kind:
		"hop", "leap":
			var gap := rng.randi_range(2, 4) + h if kind == "hop" else rng.randi_range(5, 6) + h
			var w := rng.randi_range(2, 4) if not hard else rng.randi_range(1, 3)
			var nx := x + gap + 1
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop: int = toward.call(3, 3) if kind == "hop" else toward.call(1, 2)
			if rng.randf() < 0.5:
				fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#")
			else:
				fill(g, nx, ntop, nx + w - 1, ntop + rng.randi_range(0, 1), "#")
			if hard and w >= 2 and rng.randf() < 0.3:
				put(g, nx + w - 1, ntop - 1, "^") # espinho na borda: pouse certinho
			return {"x": nx + w - 1, "top": ntop, "island": [nx, w, ntop]}
		"climb":
			# escadinha rápida: 2-3 degraus subindo 3 tiles cada
			var steps := rng.randi_range(2, 3)
			var cx := x
			var ct := top
			var last := {}
			for k in steps:
				var gap := rng.randi_range(1, 2) + h
				var w := rng.randi_range(2, 3)
				var sx := cx + gap + 1
				var st := clampi(ct - 3, 8, FLOOR)
				if st == ct or sx + w > W - 4 or _hits(res, sx, sx + w - 1):
					break
				fill(g, sx, st, sx + w - 1, st + (0 if hard else 1), "#")
				cx = sx + w - 1
				ct = st
				last = {"x": cx, "top": ct, "island": [sx, w, st]}
			return last
		"drop":
			# mergulho: desce 3-6 tiles até um pilar, com espinho na parede
			var gap := rng.randi_range(2, 4)
			var nx := x + gap + 1
			var w := rng.randi_range(3, 5)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop := clampi(top + rng.randi_range(3, 6), 8, FLOOR)
			fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#")
			return {"x": nx + w - 1, "top": ntop, "island": [nx, w, ntop]}
		"orb", "orbchain":
			var n := 1 if kind == "orb" else rng.randi_range(2, 3)
			var span := 4 + n * 5 + h * 2
			var nx := x + span
			var w := rng.randi_range(2, 4)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop: int = toward.call(4, 4)
			fill(g, nx, ntop, nx + w - 1, ntop + 1, "#")
			for k in n:
				var ox := x + (k + 1) * span / (n + 1)
				var oy := clampi(mini(top, ntop) - 4 - rng.randi_range(0, 1), 4, FLOOR - 2)
				put(g, ox, oy, "I")
			return {"x": nx + w - 1, "top": ntop, "island": [nx, w, ntop]}
		"crystal":
			var gap := rng.randi_range(8, 10) + h
			var nx := x + gap
			var w := rng.randi_range(2, 3)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop: int = toward.call(2, 3)
			fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#")
			put(g, x + gap / 2, mini(top, ntop) - 3, "D")
			return {"x": nx + w - 1, "top": ntop, "island": [nx, w, ntop]}
		"crumble":
			var n := rng.randi_range(2, 3) + h
			var cx := x
			for k in n:
				cx += rng.randi_range(3, 4)
				if cx > W - 6 or res.has(cx) or res.has(cx + 1):
					return {} if k == 0 else {"x": cx - 3, "top": top}
				put(g, cx, top, "O")
			var nx := cx + rng.randi_range(3, 4)
			var w := rng.randi_range(2, 4)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {"x": cx, "top": top}
			fill(g, nx, top, nx + w - 1, FLOOR + 1, "#")
			return {"x": nx + w - 1, "top": top, "island": [nx, w, top]}
		"mover":
			var mx := x + 2
			var nx := mx + RoomReach.MOVER_REACH + 1
			var w := rng.randi_range(2, 4)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1) or _hits(res, mx, mx + RoomReach.MOVER_REACH):
				return {}
			put(g, mx, top, "U")
			fill(g, nx, top, nx + w - 1, FLOOR + 1, "#")
			return {"x": nx + w - 1, "top": top, "island": [nx, w, top]}
		"saw":
			# corredor baixo com serra: passe no ritmo
			var w := rng.randi_range(7, 10)
			var nx := x + 2
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1) or top - 6 < 2:
				return {}
			fill(g, nx, top, nx + w - 1, FLOOR + 1, "#")
			fill(g, nx, 1, nx + w - 1, top - 6, "#")
			put(g, nx + w / 2, top - 3, "S")
			return {"x": nx + w - 1, "top": top}
		"chimney":
			# torre: sobe por salto de parede numa chaminé de 3 tiles
			var height := rng.randi_range(5, 7)
			var ntop := top - height
			var nx := x + 2
			if ntop < 7 or nx + 9 > W - 4 or _hits(res, nx, nx + 9):
				return {}
			fill(g, nx, top, nx + 3, FLOOR + 1, "#") # chão da chaminé
			fill(g, nx + 4, ntop, nx + 5, FLOOR + 1, "#") # parede da direita (vira o topo)
			fill(g, nx, ntop + 3, nx, top - 1, "#") # parede da esquerda
			return {"x": nx + 5, "top": ntop, "island": [nx + 4, 2, ntop]}
	return {}


static func _corridor(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	_terrain(g, rng, exits, 3, 0.35)
	if not exits.contains("U"):
		_ceiling(g, rng, exits, 12, 5)
	else:
		_ceiling(g, rng, exits, 6, 7)
	# poços curtos de espinhos no caminho (pule correndo, sem parar)
	var res := _reserved(exits)
	for i in rng.randi_range(1, 2):
		var px := rng.randi_range(6, W - 10)
		var pw := rng.randi_range(2, 4)
		if _hits(res, px - 1, px + pw):
			continue
		var t := floor_top(g, px)
		if t >= FLOOR - 1:
			for xx in range(px, px + pw):
				fill(g, xx, t, xx, FLOOR, ".")
				put(g, xx, FLOOR + 1, "^")
				fill(g, xx, FLOOR, xx, FLOOR, ".")
	for i in rng.randi_range(1, 2):
		_put_on_floor(g, rng.randi_range(6, W - 7), "E")
	if rng.randf() < 0.5:
		put(g, rng.randi_range(10, W - 11), rng.randi_range(8, 12), "I")
	if rng.randf() < 0.3:
		_put_on_floor(g, rng.randi_range(6, W - 7), "C")
	if rng.randf() < 0.35:
		# bloco quebrável escondendo algo no chão
		var bx := rng.randi_range(8, W - 10)
		if not res.has(bx):
			var top := floor_top(g, bx)
			fill(g, bx, top - 2, bx + 1, top - 1, "B")


## Poço vertical: paredes grossas, chaminés, ledges e orbes; voadores.
static func _shaft(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	var res := _reserved(exits)
	var inset := rng.randi_range(4, 8)
	for yy in range(1, FLOOR):
		for xx in range(1, inset):
			if not res.has(xx):
				put(g, xx, yy, "#")
		for xx in range(W - inset, W - 1):
			if not res.has(xx):
				put(g, xx, yy, "#")
	for e in exits:
		if e == "L":
			fill(g, 1, LevelConst.EXIT_LR_ROWS[0], inset + 1, LevelConst.EXIT_LR_ROWS[-1], ".")
		elif e == "R":
			fill(g, W - inset - 2, LevelConst.EXIT_LR_ROWS[0], W - 2, LevelConst.EXIT_LR_ROWS[-1], ".")
	var y := FLOOR - 3
	var left := rng.randf() < 0.5
	while y > 4:
		var w := rng.randi_range(3, 6)
		if left:
			_ledge(g, inset, y, w, rng.randf() < 0.5)
		else:
			_ledge(g, W - inset - w, y, w, rng.randf() < 0.5)
		if rng.randf() < 0.3:
			put(g, W / 2 + rng.randi_range(-3, 3), y - 2, "I")
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


static func _boss(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	var roll := rng.randf()
	if roll < 0.4:
		# chefe de parkour: arena sobre espinhos, ilhas largas e orbes para
		# alcançar o chefe no ar
		var res := _reserved(exits)
		_pit(g, res, 5, W - 6)
		var xs := [5, 15, 25]
		for i in xs.size():
			var x0: int = xs[i]
			var top := FLOOR - (2 if i % 2 == 0 else 5)
			if not _hits(res, x0, x0 + 6):
				fill(g, x0, top, x0 + 6, top + 1, "#")
		for ox in [12, 22, 32]:
			put(g, ox, FLOOR - 9, "I")
	elif roll < 0.7:
		# torre: andares para lutar em vários níveis
		_ledge(g, 4, FLOOR - 5, 10, false)
		_ledge(g, W - 14, FLOOR - 5, 10, false)
		if not exits.contains("U"):
			_ledge(g, 14, FLOOR - 10, 12, false)
		put(g, 8, FLOOR - 12, "I")
		put(g, W - 9, FLOOR - 12, "I")
	else:
		# chão clássico com duas plataformas
		_ledge(g, 6, FLOOR - 5, 6, false)
		_ledge(g, W - 12, FLOOR - 5, 6, false)
		if not exits.contains("U"):
			_ledge(g, 16, FLOOR - 10, 8, false)
	put(g, 26, FLOOR - 6, "M")
	put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
	put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")
	if not _put_on_floor(g, 3, "A"):
		_put_on_floor(g, W - 4, "A")


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
