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
static var dbg: Array = []

## Tipos que podem exigir dash para atravessar (plataforma/desafio).
const DASH_TYPES := ["platforming", "challenge", "zigzag"]


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
		"platforming", "challenge":
			var hard: bool = room_type == "challenge"
			var tier := int(opts.get("tier", 1))
			var hunt := bool(opts.get("hunt", false))
			if exits == "LR" and not opts.get("chase", false) and rng.randf() < SWITCHBACK_CHANCE:
				_switchback(g, rng, exits, hard, tier, hunt)
			else:
				_parkour(g, rng, exits, hard, tier, hunt)
		"zigzag": _zigzag(g, rng, exits, int(opts.get("tier", 1)), bool(opts.get("hunt", false)))
		"corridor": _corridor(g, rng, exits)
		"shaft":
			if exits.contains("U") and rng.randf() < TOWER_CHANCE:
				_tower(g, rng, exits, int(opts.get("tier", 1)))
				_decorate(g, rng, opts)
				return g # a torre tem a própria subida (sem escada no meio)
			_shaft(g, rng, exits)
		"puzzle": _puzzle(g, rng, exits, opts)
		"treasure": _treasure(g, rng, exits)
		"secret": _secret(g, rng, exits)
		"entrance": _entrance(g, rng, exits)
		"exit": _exit(g, rng, exits)
		"hub": _hub(g, rng, exits)
		"boss": _boss(g, rng, exits, bool(opts.get("boss_flying", true)))
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
		"boss": _boss(g, rng, exits, bool(opts.get("boss_flying", true)))
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


## Coloca uma entidade em pé no primeiro apoio abaixo de (x, y0).
static func _put_standing(g: Array, x: int, y0: int, ch: String) -> bool:
	for y in range(y0, H - 1):
		var c := at(g, x, y + 1)
		if c == "#" or c == "-":
			if at(g, x, y) == "." and at(g, x, y - 1) == ".":
				put(g, x, y, ch)
				return true
			return false
		if c == "^":
			return false
	return false


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
	if opts.get("theme", "") == "frenesi":
		roll *= 0.5 # fase Frenesi: arenas quase sempre suspensas sobre espinhos
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

const BEATS_EASY := {"hop": 4.0, "leap": 2.0, "orb": 2.5, "crumble": 1.5, "mover": 1.2, "crystal": 1.5, "chimney": 1.0,
	"thorns": 1.0, "sawgap": 1.0, "needle": 0.8, "bells": 1.2, "kickwalls": 1.2}
## Chance de um poço com saída para cima virar torre de escalada.
const TOWER_CHANCE := 0.75

## Chance de uma sala LR de plataforma/desafio virar zigue-zague de 3 andares.
const SWITCHBACK_CHANCE := 0.35

## Batidas que mantêm a altura (evitadas quando o perfil pede subir).
const FLAT_BEATS := ["needle", "saw", "crumble", "mover", "sawgap", "leap"]
const BEATS_HARD := {"hop": 1.5, "leap": 2.0, "orb": 3.0, "crumble": 2.0, "mover": 1.0, "crystal": 2.5, "chimney": 1.5, "saw": 2.0, "orbchain": 2.0,
	"thorns": 2.5, "sawgap": 1.5, "needle": 1.5, "bells": 2.0, "kickwalls": 2.2}


## Plataforma/desafio: sequência de batidas da esquerda para a direita sobre
## um fosso de espinhos. hard = "caminho da dor" (vãos maiores, serras,
## cadeias de orbes, inimigos no meio do percurso e relíquia no fim).
static func _parkour(g: Array, rng: RandomNumberGenerator, exits: String, hard: bool, tier: int, hunt: bool = false) -> void:
	var res := _reserved(exits)
	if exits.contains("U"):
		res["U"] = true # marca (não é coluna): batidas com teto evitam a saída de cima
	_pit(g, res, 4, W - 5)
	# perfil do percurso: morro, vale, subida, descida ou zigue-zague
	var shape: String = ["hill", "plateau", "rise", "twin", "zigzag"][rng.randi() % 5]
	var amp := rng.randi_range(9, 13)
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
		if diff >= 2:
			# precisa subir: escadinhas, chaminés, orbes e espinhos de pogo
			t2["climb"] = 6.0
			t2["chimney"] = float(t2.get("chimney", 1.0)) * 2.5
			t2["orb"] = float(t2.get("orb", 1.0)) * 1.5
			for k in FLAT_BEATS:
				if t2.has(k):
					t2[k] = float(t2[k]) * 0.25
		elif diff <= -2:
			t2["drop"] = 4.0
			t2.erase("chimney")
		var kind: String = RngUtil.weighted_key(rng, t2)
		var r := _beat(g, rng, kind, x, top, hard, res, want)
		dbg.append("%s@%d,%d->%d%s" % [kind, x, top, want, "" if not r.is_empty() else "X"])
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
	var clear := 8 + rng.randi_range(0, 1)
	for xx in range(1, W - 1):
		if exits.contains("U") and xx >= LevelConst.EXIT_UD_COLS[0] - 6 and xx <= LevelConst.EXIT_UD_COLS[-1] + 6:
			continue
		var t: int = path.get(xx, FLOOR)
		var bottom := t - clear - (1 if (xx / 3) % 2 == 0 else 0)
		if bottom >= 1:
			fill_empty(g, xx, 1, xx, bottom, "#")
	# inimigos no meio do percurso: nas ilhas largas e voadores sobre os fossos
	var n_ground := (1 if not hard else 2) + (tier - 1) + (2 if hunt else 0)
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
	var n_tur := (1 if tier >= 2 else 0) + (1 if hard else 0) + (1 if rng.randf() < 0.35 else 0)
	_turrets(g, rng, mini(n_tur, 2), path, res)
	if hunt:
		# caçada: a sala fecha até derrotar todos (inimigos extras no percurso)
		for i in 2:
			for t in 10:
				var fx := rng.randi_range(8, W - 9)
				var fy := clampi(int(path.get(fx, FLOOR)) - rng.randi_range(3, 6), 3, FLOOR - 3)
				if at(g, fx, fy) == "." and at(g, fx, fy + 1) == "." and at(g, fx, fy - 1) == ".":
					put(g, fx, fy, "F")
					break
		for e in exits:
			if e == "L":
				put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
			elif e == "R":
				put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")
	if hard:
		_put_on_floor(g, W - 3, "R")


## Altura-alvo (linha do topo do apoio) do percurso em t = 0..1.
static func _profile(shape: String, t: float, amp: int) -> int:
	var k := 0.0
	match shape:
		"hill": k = sin(t * PI)
		"plateau": k = clampf(minf(t, 1.0 - t) * 4.0, 0.0, 1.0) # sobe rápido, fica no alto, desce no fim
		"rise": k = minf(t * 1.4, 1.0)
		"twin": k = absf(sin(t * TAU)) # dois morros
		"zigzag": k = 0.5 + 0.5 * sin(t * TAU * 1.5 - PI * 0.5)
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
			if kind == "leap" and (hard or rng.randf() < 0.35):
				# face do pilar com espinhos: nada de encostar para recarregar o dash
				for yy in range(ntop + 1, mini(ntop + 4, FLOOR)):
					if at(g, nx - 1, yy) == "." and at(g, nx - 1, yy + 1) != "#":
						put(g, nx - 1, yy, "^")
			return {"x": nx + w - 1, "top": ntop, "island": [nx, w, ntop]}
		"kickwalls":
			# paredes suspensas sobre o fosso: encoste (recarrega o dash) e passe
			# por cima de dash; topo com espinho (não dá para pousar) e a face de
			# trás às vezes com espinhos
			var n := rng.randi_range(2, 3)
			var step := rng.randi_range(6, 7) + h
			while n > 1 and x + step * (n + 1) + 2 > W - 4:
				n -= 1
			var cx := x
			for k in n:
				cx += step
				if _hits(res, cx - 1, cx + 1):
					return {}
				var wh := rng.randi_range(4, 6)
				var wtop := clampi(mini(top, want) - rng.randi_range(4, 6), 6, FLOOR - wh - 2)
				fill(g, cx, wtop, cx, wtop + wh - 1, "#")
				if rng.randf() < 0.65:
					put(g, cx, wtop - 1, "^")
				if hard or rng.randf() < 0.4:
					for yy in range(wtop, wtop + wh):
						if at(g, cx + 1, yy) == ".":
							put(g, cx + 1, yy, "^")
			var nx := cx + step - 1
			var w := rng.randi_range(2, 4)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop: int = toward.call(3, 3)
			fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#")
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
			var span := 3 + n * 4 + h * 2
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
			var gap := rng.randi_range(7, 9) + h
			var nx := x + gap
			var w := rng.randi_range(2, 3)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop: int = toward.call(2, 3)
			fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#")
			var cr := rng.randf()
			var item := "D" if cr < 0.55 else ("j" if cr < 0.8 or not hard else "d")
			put(g, x + gap / 2, mini(top, ntop) - 3, item)
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
			# torre: sobe por salto de parede numa chaminé (no desafio, larga: só
			# com chute de parede, dash + pulo, de um lado para o outro)
			var height := rng.randi_range(5, 7) + h * 2
			var cw := 3 if not hard else rng.randi_range(5, 6)
			var ntop := top - height
			var nx := x + 2
			if ntop < 7 or nx + cw + 6 > W - 4 or _hits(res, nx, nx + cw + 6):
				return {}
			fill(g, nx, top, nx + cw, FLOOR + 1, "#") # chão da chaminé
			fill(g, nx + cw + 1, ntop, nx + cw + 2, FLOOR + 1, "#") # parede da direita (vira o topo)
			fill(g, nx, ntop + 3, nx, top - 1, "#") # parede da esquerda
			return {"x": nx + cw + 2, "top": ntop, "island": [nx + cw + 1, 2, ntop]}
		"thorns":
			# espinhos de pogo sobre o fosso: golpe para baixo em cada um (HK)
			var n := rng.randi_range(2, 3) if hard else rng.randi_range(1, 2)
			var step := rng.randi_range(4, 5)
			while n > 1 and x + step * (n + 1) + 2 > W - 4:
				n -= 1
			var bw := 1 if hard or rng.randf() < 0.4 else 2
			var sy := clampi(top + rng.randi_range(-1, 1) + (1 if want > top else 0), 9, FLOOR - 1)
			var cx := x
			for k in n:
				cx += step
				if _hits(res, cx, cx + bw - 1):
					return {}
				for b in bw:
					put(g, cx + b, sy, "^")
					put(g, cx + b, sy + 1, "#")
				# cada quique sobe até 2 tiles (ou desce) rumo ao perfil
				sy = clampi(sy + clampi(want - sy, -1, 1) * rng.randi_range(1, 2), 9, FLOOR - 1)
			var nx := cx + step
			var w := rng.randi_range(2, 4)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop := clampi(sy - rng.randi_range(0, 2), 8, FLOOR)
			fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#")
			return {"x": nx + w - 1, "top": ntop, "island": [nx, w, ntop]}
		"bells":
			# fila de sinos sobre o fosso: golpe, pulo, dash, golpe... sem pousar
			var n := rng.randi_range(2, 3)
			var step := rng.randi_range(5, 6) + h
			while n > 1 and x + step * (n + 1) + 2 > W - 4:
				n -= 1
			var by := clampi(top - 3 - rng.randi_range(0, 1), 5, FLOOR - 3)
			var cx := x
			for k in n:
				cx += step
				if res.has(cx):
					return {}
				put(g, cx, by + rng.randi_range(-1, 1), "b")
			var nx := cx + step - 1
			var w := rng.randi_range(2, 4)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop: int = toward.call(2, 3)
			fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#")
			return {"x": nx + w - 1, "top": ntop, "island": [nx, w, ntop]}
		"sawgap":
			# vão com serra subindo e descendo no meio: pule no compasso
			var gap := rng.randi_range(4, 5) + h
			var nx := x + gap + 1
			var w := rng.randi_range(2, 4)
			if nx + w > W - 4 or _hits(res, nx, nx + w - 1):
				return {}
			var ntop: int = toward.call(2, 2)
			fill(g, nx, ntop, nx + w - 1, FLOOR + 1, "#")
			put(g, x + 1 + gap / 2, mini(maxi(top, ntop) + 1, FLOOR - 1), "s")
			return {"x": nx + w - 1, "top": ntop, "island": [nx, w, ntop]}
		"needle":
			# túnel baixo com espinhos no teto e buraco no chão: só passa de DASH
			var ln := rng.randi_range(9, 12)
			var nx := x + 1
			if top < 9 or nx + ln > W - 4 or _hits(res, nx, nx + ln - 1):
				return {}
			if res.has("U") and nx <= LevelConst.EXIT_UD_COLS[-1] + 6 and nx + ln - 1 >= LevelConst.EXIT_UD_COLS[0] - 6:
				return {}
			var gw := rng.randi_range(2, 3) + h
			var gx := nx + rng.randi_range(3, ln - gw - 3)
			fill(g, nx, top, nx + ln - 1, FLOOR + 1, "#")
			for xx in range(gx, gx + gw):
				fill(g, xx, top, xx, FLOOR, ".")
				put(g, xx, FLOOR + 1, "^")
			fill(g, nx + 1, 1, nx + ln - 2, top - 4, "#")
			for xx in range(nx + 1, nx + ln - 1):
				put(g, xx, top - 3, "^")
			return {"x": nx + ln - 1, "top": top}
	return {}


## Zigue-zague em 3 andares (usa a tela inteira): entra embaixo pela
## esquerda, sobe no fim do andar de baixo, volta pelo do meio, sobe na
## esquerda, cruza o de cima e desce pelo poço da direita até a saída. Cada
## andar tem 5 tiles de altura (pulo cheio cabe) e o seu desafio: fossos,
## espinhos no piso, tábuas que desabam, serras, torretas e inimigos.
static func _switchback(g: Array, rng: RandomNumberGenerator, exits: String, hard: bool, tier: int, hunt: bool) -> void:
	var s1 := 15 ## prateleira entre o andar de baixo e o do meio
	var s2 := 9 ## prateleira entre o do meio e o de cima
	var wx := W - 8 ## parede dupla (wx, wx+1) que separa o poço da saída
	fill(g, 1, 1, W - 2, 3, "#")
	fill(g, 1, s1, wx - 1, s1, "#")
	fill(g, 1, s2, wx - 1, s2, "#")
	fill(g, wx, s2, wx + 1, FLOOR - 1, "#")
	# aberturas + degrau embaixo de cada uma
	var o1 := rng.randi_range(wx - 7, wx - 4)
	fill(g, o1, s1, o1 + 2, s1, ".")
	fill(g, o1, s1 + 3, o1 + 2, FLOOR - 1, "#")
	var o2 := rng.randi_range(3, 6)
	fill(g, o2, s2, o2 + 2, s2, ".")
	fill(g, o2, s2 + 3, o2 + 2, s1 - 1, "#")
	# poço da direita: degraus one-way alternados até a saída
	var left := true
	for y in [FLOOR - 3, FLOOR - 6, FLOOR - 9]:
		var x0 := wx + 2 if left else W - 4
		fill(g, x0, y, x0 + 2, y, "-")
		left = not left
	var h := 1 if hard else 0
	# --- andar de baixo (indo para a direita): fossos de espinho ---
	var x := 5
	while x < o1 - 6:
		var pw := rng.randi_range(2, 3) + h
		if x + pw >= o1 - 2:
			break
		for xx in range(x, x + pw):
			fill(g, xx, FLOOR, xx, FLOOR, ".")
			put(g, xx, FLOOR + 1, "^")
		x += pw + rng.randi_range(3, 6)
	_put_standing(g, rng.randi_range(8, o1 - 3), s1 + 1, "E")
	if rng.randf() < 0.6 or hard:
		put(g, o1 - 1, FLOOR - 2, "t") # na face do degrau, atira no corredor
	# --- andar do meio (indo para a esquerda): espinhos no piso e tábuas ---
	var mid_top := s1 - 1
	x = o1 - 3
	while x > o2 + 6:
		var kind := rng.randi_range(0, 2 if not hard else 3)
		var w := rng.randi_range(2, 3)
		var xl := x - w
		if xl <= o2 + 4:
			break
		match kind:
			0, 3: # espinhos no piso: pule por cima (teto baixo!)
				fill(g, xl, mid_top, x - 1, mid_top, "^")
			1: # tábuas que desabam sobre um buraco (cair = voltar ao andar de baixo)
				for xx in range(xl - 1, x + 1):
					put(g, xx, s1, "O" if (xx - xl) % 2 == 0 else ".")
			2: # serra no meio do corredor
				put(g, x - 1, s1 - 3, "S")
		x = xl - rng.randi_range(3, 5)
	if rng.randf() < 0.5:
		put(g, 1, s1 - 2, "t") # parede da esquerda atira no corredor do meio
	_put_standing(g, rng.randi_range(o2 + 6, o1 - 4), s2 + 1, "E")
	if tier >= 2 or hunt:
		_put_standing(g, rng.randi_range(o2 + 4, wx - 3), 4, "E")
	# --- andar de cima (indo para a direita): espinhos pendurados e voadores ---
	x = o2 + 5
	while x < wx - 5:
		var w := rng.randi_range(2, 4)
		if rng.randf() < 0.5:
			fill(g, x, 4, x + w - 1, 4, "^") # pendurados: pulo baixo
		else:
			fill(g, x, s2 - 1, x + w - 1, s2 - 1, "^") # no piso: pule por cima
		x += w + rng.randi_range(3, 5)
	for i in rng.randi_range(1, 2) + (1 if hunt else 0):
		for t in 10:
			var fx := rng.randi_range(8, wx - 4)
			var fy: int = [6, 12, 18][rng.randi() % 3]
			if at(g, fx, fy) == "." and at(g, fx, fy - 1) == "." and at(g, fx, fy + 1) == ".":
				put(g, fx, fy, "F")
				break
	if tier >= 2 or hard:
		for t in 10:
			var tx := rng.randi_range(o2 + 4, wx - 3)
			if at(g, tx, 4) == "." and at(g, tx, 3) == "#":
				put(g, tx, 4, "t") # no teto do andar de cima, atira para baixo
				break
	if hunt:
		put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
		put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")
	if hard:
		_put_on_floor(g, W - 3, "R")


## Zigue-zague: o chão INTEIRO é espinho. Não dá para pousar — só encadear
## nós aéreos alternando alto e baixo: orbes (golpeie), cristais de dash,
## espinhos de pogo (↓+golpe) e inimigos voadores no meio (abater no ar
## recarrega o dash). Estalactites com ponta de espinho sobre os nós baixos e
## estalagmites sob os altos fecham o "canal" do zigue-zague.
static func _zigzag(g: Array, rng: RandomNumberGenerator, exits: String, tier: int, hunt: bool) -> void:
	var res := _reserved(exits)
	_pit(g, res, 4, W - 5)
	var ceil_y := rng.randi_range(3, 5)
	for x in range(1, W - 1):
		if exits.contains("U") and x >= LevelConst.EXIT_UD_COLS[0] - 3 and x <= LevelConst.EXIT_UD_COLS[-1] + 3:
			continue
		var d := ceil_y - (1 if (x / 4) % 2 == 0 else 0)
		fill(g, x, 1, x, d, "#")
	var lo_y := FLOOR - 4
	var hi_y := lo_y - 5 ## amplitude do zigue-zague: 5 tiles (quique + dash)
	var x := 3
	var hi := false ## começa baixo (saindo do chão da porta)
	var nodes: Array = []
	while true:
		x += rng.randi_range(3, 5)
		if x > W - 7:
			break
		if res.has(x):
			continue
		var y := (hi_y if hi else lo_y) + rng.randi_range(-1, 0)
		var roll := rng.randf()
		if roll < 0.16 and x + 1 < W - 5:
			# parede flutuante: encoste (recarrega o dash) e saia de dash/chute;
			# às vezes uma face tem espinhos (só dá para usar a outra)
			fill(g, x, y - 2, x, y + 1, "#")
			if rng.randf() < 0.45:
				var sx := x + 1 if rng.randf() < 0.6 else x - 1
				for yy in range(y - 2, y + 2):
					if at(g, sx, yy) == ".":
						put(g, sx, yy, "^")
			nodes.append(Vector2i(x, y))
			hi = not hi
			continue
		roll = rng.randf()
		if hi:
			if roll < 0.42:
				put(g, x, y, "I")
			elif roll < 0.62:
				put(g, x, y + 1, "^") # espinho de pogo no alto: caia nele com ↓+golpe
				put(g, x, y + 2, "#")
			elif roll < 0.78:
				put(g, x, y, "b") # sino: golpeie (recarrega dash + pulo, sem quicar)
			elif roll < 0.9:
				put(g, x, y, "D")
			else:
				put(g, x, y, "d") # cristal duplo
			# estalagmite com espinho embaixo do nó alto (não caia!)
			if rng.randf() < 0.45:
				var top := y + 6
				if top <= FLOOR - 1:
					fill(g, x, top + 1, x, FLOOR + 1, "#")
					put(g, x, top, "^")
					if rng.randf() < 0.6:
						_spike_sides(g, x, top + 1, mini(top + 4, FLOOR))
		else:
			var node_y := y + 1
			if roll < 0.35:
				put(g, x, y, "I")
			elif roll < 0.65:
				put(g, x, y + 1, "^") # espinho de pogo flutuando sobre o fosso
				put(g, x, y + 2, "#")
				node_y = y
			elif roll < 0.8:
				put(g, x, y, "b")
			elif roll < 0.9:
				put(g, x, y, "j") # pena: encoste para ganhar um pulo
			else:
				put(g, x, y, "D")
			# estalactite com ponta de espinho sobre o nó baixo (fecha o canal por
			# cima; o quique cabe embaixo dela)
			if rng.randf() < 0.45:
				var tip := node_y - 8
				if tip > ceil_y + 1:
					fill(g, x, 1, x, tip - 1, "#")
					put(g, x, tip, "^")
					if rng.randf() < 0.6:
						_spike_sides(g, x, maxi(tip - 3, ceil_y + 1), tip - 1)
		nodes.append(Vector2i(x, y))
		hi = not hi
	# último nó baixo perto da porta da direita (entrar/sair por ela)
	if nodes.is_empty() or nodes[-1].y < lo_y - 1 or nodes[-1].x < W - 9:
		var lx := W - 6
		if at(g, lx, lo_y) == "." and not res.has(lx):
			put(g, lx, lo_y, "I")
	# inimigos voadores entre os nós (combate no meio do zigue-zague)
	var n_fly := 1 + tier / 2 + (2 if hunt else 0)
	for i in n_fly:
		for t in 10:
			var fx := rng.randi_range(8, W - 9)
			var fy := rng.randi_range(hi_y, lo_y - 1)
			if at(g, fx, fy) == "." and at(g, fx, fy - 1) == "." and at(g, fx, fy + 1) == ".":
				put(g, fx, fy, "F")
				break
	if tier >= 2 and rng.randf() < 0.6:
		for t in 10:
			var tx := rng.randi_range(8, W - 9)
			var ty := floor_top(g, tx, 1)
			# teto: primeira célula vazia abaixo do teto
			var cy := 1
			while cy < H and at(g, tx, cy) == "#":
				cy += 1
			if at(g, tx, cy) == "." and at(g, tx, cy + 1) == "." and ty > cy + 6:
				put(g, tx, cy, "t")
				break
	if hunt:
		for e in exits:
			if e == "L":
				put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
			elif e == "R":
				put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")


## Espinhos nas duas faces de uma coluna (x) entre as linhas y0..y1: a parede
## ali não serve para recarregar o dash (mantém a dificuldade).
static func _spike_sides(g: Array, x: int, y0: int, y1: int) -> void:
	for yy in range(y0, y1 + 1):
		for sx in [x - 1, x + 1]:
			if at(g, sx, yy) == "." and at(g, sx, yy + 1) != "#":
				put(g, sx, yy, "^")


## Torretas rítmicas no percurso: no teto atirando para baixo (cortina de
## balas no meio do pulo) ou na lateral de pilares atirando através do vão.
static func _turrets(g: Array, rng: RandomNumberGenerator, n: int, path: Dictionary, res: Dictionary) -> void:
	if n <= 0:
		return
	var spots: Array = []
	for x in range(7, W - 7):
		if res.has(x):
			continue
		var pt: int = path.get(x, FLOOR)
		for y in range(2, FLOOR - 1):
			if at(g, x, y) != ".":
				continue
			# teto: atira para baixo, cruzando a altura do percurso
			if at(g, x, y - 1) == "#" and at(g, x, y + 1) == "." and at(g, x, y + 2) == "." and pt - y >= 5:
				spots.append(Vector2i(x, y))
			# lateral de pilar, na altura do corpo acima do percurso
			elif y >= pt - 4 and y <= pt - 2 and at(g, x, y + 1) != "^":
				if at(g, x - 1, y) == "#" and at(g, x + 1, y) == "." and at(g, x + 2, y) == "." and at(g, x + 3, y) == ".":
					spots.append(Vector2i(x, y))
				elif at(g, x + 1, y) == "#" and at(g, x - 1, y) == "." and at(g, x - 2, y) == "." and at(g, x - 3, y) == ".":
					spots.append(Vector2i(x, y))
	RngUtil.shuffle(rng, spots)
	var placed: Array = []
	for sp in spots:
		if placed.size() >= n:
			break
		var ok := true
		for q in placed:
			if absi(q.x - sp.x) < 8:
				ok = false
		if ok:
			put(g, sp.x, sp.y, "t")
			placed.append(sp)


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
## Torre de escalada (poço com saída para cima): paredes grossas e
## irregulares, subida em degraus alternados com orbes, espinhos de pogo e
## tábuas que desabam; espinhos nas paredes (cuidado no salto de parede) e
## torretas atirando de um lado ao outro do poço. Sem escada fácil no meio.
static func _tower(g: Array, rng: RandomNumberGenerator, exits: String, tier: int) -> void:
	var inset := rng.randi_range(9, 11)
	var xl := inset ## primeira coluna livre
	var xr := W - 1 - inset ## última coluna livre
	for y in range(1, FLOOR):
		fill(g, 1, y, xl - 1, y, "#")
		fill(g, xr + 1, y, W - 2, y, "#")
	for e in exits:
		if e == "L":
			fill(g, 1, LevelConst.EXIT_LR_ROWS[0], xl, LevelConst.EXIT_LR_ROWS[-1], ".")
		elif e == "R":
			fill(g, xr, LevelConst.EXIT_LR_ROWS[0], W - 2, LevelConst.EXIT_LR_ROWS[-1], ".")
	# a subida: apoio atual [ax0, ax1] com os pés na linha cy; cada degrau sobe
	# 3-6 tiles, com a borda do próximo a 1-3 tiles da borda deste (alcance
	# real do pulo) e alternando os lados
	var ax0 := W / 2 - 1
	var ax1 := W / 2
	var cy := FLOOR - 1
	var side := -1 if rng.randf() < 0.5 else 1
	var ledges: Array = [] ## [x0, x1, y_apoio]
	var climb_cols: Array = [] ## [x, y_topo, y_base]: colunas por onde o herói sobe
	var guard := 0
	while cy > 6 and guard < 40:
		guard += 1
		var edge := ax1 if side > 0 else ax0
		var roll := rng.randf()
		var kind := "ledge"
		if roll < 0.22:
			kind = "orb"
		elif roll < 0.4:
			kind = "thorn"
		elif roll < 0.52:
			kind = "crumble"
		var ny := cy - 3
		var from := edge ## de onde sai o salto para o próximo degrau
		var el := Vector2i(-1, -1) ## orbe/espinho de pogo no meio do degrau
		match kind:
			"orb":
				from = edge + side * rng.randi_range(1, 2)
				el = Vector2i(from, cy - 4)
				ny = cy - 6
			"thorn":
				from = edge + side * rng.randi_range(2, 3)
				el = Vector2i(from, cy - 1)
				ny = cy - 5
		if ny < 5 or (el.x >= 0 and (el.x <= xl or el.x >= xr)):
			if kind == "ledge":
				ny = maxi(ny, 5)
			else:
				side = -side
				continue
		var w := rng.randi_range(3, 5)
		var near := from + side * rng.randi_range(1, 3)
		var x0 := near if side > 0 else near - w + 1
		if x0 < xl or x0 + w - 1 > xr:
			side = -side # sem espaço deste lado: vira e tenta de novo
			continue
		# nada novo pode tapar a coluna de subida de um degrau anterior
		var cells: Array = []
		for xx in range(x0, x0 + w):
			cells.append(Vector2i(xx, ny + 1))
		if el.x >= 0:
			cells.append(el)
			if kind == "thorn":
				cells.append(el + Vector2i(0, 1))
		var clash := false
		for c in cells:
			for col in climb_cols:
				if absi(c.x - int(col[0])) <= 1 and c.y >= int(col[1]) and c.y <= int(col[2]):
					clash = true
		if clash:
			side = -side
			continue
		climb_cols.append([from, ny - 1, cy])
		if kind == "orb":
			var rr := rng.randf()
			put(g, el.x, el.y, "I" if rr < 0.5 else ("b" if rr < 0.8 else "j"))
		elif kind == "thorn":
			put(g, el.x, el.y, "^")
			put(g, el.x, el.y + 1, "#")
		# encostado na parede se sobrar pouco espaço (prateleira)
		if x0 - xl <= 1:
			w += x0 - xl
			x0 = xl
		elif xr - (x0 + w - 1) <= 1:
			w = xr - x0 + 1
		var ch := "#" if rng.randf() < 0.6 else "-"
		if kind == "crumble":
			ch = "O"
		for xx in range(x0, x0 + w):
			if at(g, xx, ny + 1) == ".":
				put(g, xx, ny + 1, ch)
		ledges.append([x0, x0 + w - 1, ny + 1])
		ax0 = x0
		ax1 = x0 + w - 1
		cy = ny
		side = -side
		# perto do topo: puxa para o centro (saída de cima)
		if cy <= 11 and absi((ax0 + ax1) / 2 - W / 2) > 3:
			side = 1 if (ax0 + ax1) / 2 < W / 2 else -1
	# topo: plataforma one-way sob a saída de cima, estendida até o último degrau
	var t0 := mini(LevelConst.EXIT_UD_COLS[0] - 3, ax1 + 1)
	var t1 := maxi(LevelConst.EXIT_UD_COLS[-1] + 3, ax0 - 1)
	for x in range(maxi(t0, xl + 1), mini(t1, xr - 1) + 1):
		if at(g, x, 4) == "." and at(g, x, 5) == ".":
			put(g, x, 4, "-")
	# paredes irregulares (saliências) e espinhos nas faces, longe dos degraus
	# encostados naquele lado
	for i in rng.randi_range(4, 7):
		var sy := rng.randi_range(5, FLOOR - 6)
		var left := rng.randf() < 0.5
		var near := false
		for l in ledges:
			var touches: bool = int(l[0]) <= xl + 3 if left else int(l[1]) >= xr - 3
			if touches and absi(int(l[2]) - sy) <= 4:
				near = true
		if near:
			continue
		var fx := xl if left else xr
		var dx := 1 if left else -1
		var hh := rng.randi_range(2, 4)
		if rng.randf() < 0.5:
			# saliência de 1-2 tiles
			var depth := rng.randi_range(1, 2)
			for yy in range(sy, sy + hh):
				for k in depth:
					if at(g, fx + dx * k, yy) == ".":
						put(g, fx + dx * k, yy, "#")
		else:
			for yy in range(sy, sy + hh):
				if at(g, fx, yy) == "." and at(g, fx, yy + 1) != "#" and at(g, fx, yy - 1) != "-":
					put(g, fx, yy, "^")
	# a parede recarrega o dash: para a torre não virar "escalar a parede",
	# a maior parte das faces laterais fica coberta de espinhos (sobram trechos
	# de apoio perto dos degraus e alguns no meio)
	for wside in [-1, 1]:
		var fx := xl if wside < 0 else xr
		var yy := 6
		while yy < FLOOR - 2:
			var seg := rng.randi_range(3, 5)
			var near := false
			for l in ledges:
				var touches: bool = int(l[0]) <= xl + 2 if wside < 0 else int(l[1]) >= xr - 2
				if touches and int(l[2]) - (yy + seg) <= 3 and yy - int(l[2]) <= 3:
					near = true
			if not near and rng.randf() < 0.7:
				for k in range(yy, mini(yy + seg, FLOOR - 2)):
					if at(g, fx, k) == "." and at(g, fx, k + 1) != "#" and at(g, fx, k - 1) != "-" and at(g, fx - wside, k) == "#":
						put(g, fx, k, "^")
			yy += seg + rng.randi_range(0, 2)
	# torretas na parede atirando através do poço
	var nt := (1 if tier >= 2 else 0) + (1 if rng.randf() < 0.5 else 0)
	for i in nt:
		for t in 10:
			var ty := rng.randi_range(6, FLOOR - 5)
			var left := rng.randf() < 0.5
			var tx := xl if left else xr
			if at(g, tx, ty) == "." and at(g, tx + (1 if left else -1), ty) == "." and at(g, tx, ty + 1) == "." and at(g, tx, ty - 1) == ".":
				put(g, tx, ty, "t")
				break
	for i in rng.randi_range(1, 2):
		for t in 8:
			var fx := rng.randi_range(xl + 2, xr - 2)
			var fy := rng.randi_range(6, FLOOR - 6)
			if at(g, fx, fy) == "." and at(g, fx, fy + 1) == "." and at(g, fx, fy - 1) == ".":
				put(g, fx, fy, "F")
				break


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


static func _boss(g: Array, rng: RandomNumberGenerator, exits: String, flying: bool = true) -> void:
	var roll := rng.randf()
	if not flying:
		roll = 0.4 + roll * 0.6 # chefe que anda: nada de arena sobre espinhos
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
	# chefe de horda: lacaios vêm em ondas antes do chefe entrar
	if rng.randf() < 0.35:
		_spawn_enemies(g, rng, rng.randi_range(3, 5), rng.randi_range(1, 2))
	put(g, 0, LevelConst.EXIT_LR_ROWS[0], "G")
	put(g, W - 1, LevelConst.EXIT_LR_ROWS[0], "G")
	if not _put_on_floor(g, 3, "A"):
		_put_on_floor(g, W - 4, "A")


# ---------------------------------------------------------------------------
# Decoração
# ---------------------------------------------------------------------------

## Lamparinas apagadas ("l") em pé no chão ou em saliências, espalhadas pela
## sala (uma por faixa horizontal). Não bloqueiam nada: o Pavio acende ao
## passar. Devolve quantas couberam.
static func place_lamps(g: Array, rng: RandomNumberGenerator, n: int) -> int:
	if n <= 0:
		return 0
	var placed := 0
	var band := float(W - 6) / float(n)
	for k in n:
		for attempt in 24:
			var x := 3 + int(band * k) + rng.randi_range(0, maxi(int(band) - 1, 0))
			x = clampi(x, 2, W - 3)
			var y0 := rng.randi_range(3, H - 4)
			if at(g, x - 1, y0) == "l" or at(g, x + 1, y0) == "l":
				continue
			var before := _count(g, "l")
			if _put_standing(g, x, y0, "l") and _count(g, "l") > before:
				placed += 1
				break
	return placed


static func _count(g: Array, ch: String) -> int:
	var n := 0
	for row in g:
		for c in row:
			if c == ch:
				n += 1
	return n


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
