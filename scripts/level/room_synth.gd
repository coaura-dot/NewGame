class_name RoomSynth
extends RefCounted
## Gera salas proceduralmente para QUALQUER combinação de saídas. Complementa
## os templates feitos à mão: se não houver template para o tipo e as saídas
## pedidas, o gerador usa isto — nunca falha.
##
## Tudo é pensado para o herói de ~12 px com a física de Celeste (pulo ~3,9
## tiles, ~6 tiles de alcance horizontal num pulo que sobe 3):
##  * o chão é um PERFIL de alturas por coluna: degraus de no máximo 3 tiles
##    entre colunas vizinhas (dá para subir E voltar sem dash);
##  * fossos têm no máximo 4 tiles de largura (5+ só em salas de desafio, que
##    podem exigir dash — com cristal de dash no caminho);
##  * plataformas one-way sobem em degraus de até 3 linhas;
##  * a saída de cima tem uma escada de plataformas até a linha 4 (de lá o
##    pulo + impulso de transição alcança a sala de cima).
## tests/test_room_reach.gd valida isso SIMULANDO a física (RoomReach).

const W := LevelConst.ROOM_W
const H := LevelConst.ROOM_H
const FL := LevelConst.FLOOR_ROW
const MAX_STEP := 3 ## maior degrau (em tiles) entre colunas vizinhas

## Estilo de relevo por tipo de sala: variação de altura, fossos, teto.
const STYLES := {
	"combat": {"var": [3.0, 2.0, 1.0, 0.3], "seg": [4, 8], "min_row": 16, "pits": 0.25, "spikes": false, "ceil": 0.4},
	"platforming": {"var": [1.0, 1.5, 1.6, 1.2], "seg": [2, 5], "min_row": 13, "pits": 0.8, "spikes": true, "ceil": 0.3},
	"corridor": {"var": [3.0, 2.0, 0.8, 0.2], "seg": [3, 7], "min_row": 16, "pits": 0.2, "spikes": false, "ceil": 0.9},
	"shaft": {"var": [3.0, 1.0, 0.5, 0.0], "seg": [4, 8], "min_row": 18, "pits": 0.0, "spikes": false, "ceil": 0.0},
	"puzzle": {"var": [4.0, 1.0, 0.5, 0.0], "seg": [4, 8], "min_row": 18, "pits": 0.0, "spikes": false, "ceil": 0.2},
	"flat": {"var": [1.0, 0.0, 0.0, 0.0], "seg": [6, 10], "min_row": 21, "pits": 0.0, "spikes": false, "ceil": 0.0},
	"terraced": {"var": [4.0, 1.5, 0.6, 0.0], "seg": [5, 9], "min_row": 18, "pits": 0.0, "spikes": false, "ceil": 0.3},
	"arena": {"var": [6.0, 1.0, 0.0, 0.0], "seg": [6, 10], "min_row": 19, "pits": 0.0, "spikes": false, "ceil": 0.0},
}


static func synth(room_type: String, exits: String, rng: RandomNumberGenerator, opts: Dictionary = {}) -> PackedStringArray:
	var g := blank()
	frame(g, exits)
	var style := "flat"
	# arena precisa de portões: com saída vertical vira combate aberto
	if room_type == "arena" and (exits.contains("U") or exits.contains("D")):
		room_type = "combat"
	match room_type:
		"combat", "platforming", "corridor", "shaft", "puzzle", "arena":
			style = room_type
		"entrance", "exit", "treasure", "passage":
			style = "terraced"
	var fl := _terrain(g, rng, exits, STYLES[style], opts)
	if STYLES[style]["ceil"] > 0.0 and rng.randf() < float(STYLES[style]["ceil"]):
		_ceiling(g, rng, exits, fl, room_type == "corridor")
	match room_type:
		"arena": _arena(g, rng, exits, fl, opts)
		"combat": _combat(g, rng, exits, fl, opts)
		"platforming": _platforming(g, rng, exits, fl)
		"challenge": _gauntlet(g, rng, exits)
		"corridor": _corridor(g, rng, exits, fl)
		"puzzle": _puzzle(g, rng, exits, fl, opts)
		"treasure": _treasure(g, rng, exits, fl)
		"secret": _secret(g, rng, exits)
		"entrance": _entrance(g, exits, fl)
		"exit": _exit(g, exits, fl)
		"hub": _hub(g)
		"passage": _passage(g, rng, exits, fl)
		"boss": _boss(g)
		"shaft": _shaft(g, rng, exits, fl)
	if exits.contains("U"):
		ladder(g, rng)
	_decorate(g, rng, opts)
	return to_rows(g)


# ---------------------------------------------------------------------------
# Tokens aleatórios dos templates (tools/build_rooms.py)
# ---------------------------------------------------------------------------

## Tokens "seguros" (não mudam o caminho): chance e o que viram.
const SAFE_TOKENS := {
	"e": [0.6, "E"], "f": [0.5, "F"], "u": [0.55, "U"], "i": [0.65, "I"], "s": [0.45, "S"],
	"c": [0.3, "C"], "d": [0.6, "D"], "j": [0.5, "J"], "+": [0.5, "-"],
}
## Grupos (todo o grupo decide junto): 1 2 3 = bloco sólido, 4 5 = espinho.
const GROUP_TOKENS := {"1": "#", "2": "#", "3": "#", "4": "^", "5": "^"}


## Resolve os tokens de um template. `groups` (opcional) força a decisão de
## cada grupo ({"1": true, ...}); `strip_entities` troca os tokens seguros
## por vazio (usado pelo validador, que não enxerga entidades).
static func resolve_tokens(g: Array, rng: RandomNumberGenerator, groups: Dictionary = {}, strip_entities: bool = false) -> void:
	var decided := groups.duplicate()
	for y in H:
		for x in W:
			var c: String = g[y][x]
			if GROUP_TOKENS.has(c):
				if not decided.has(c):
					decided[c] = rng.randf() < 0.5 if rng else false
				g[y][x] = GROUP_TOKENS[c] if decided[c] else "."
			elif SAFE_TOKENS.has(c):
				if strip_entities:
					g[y][x] = "-" if c == "o" else "."
				else:
					var spec: Array = SAFE_TOKENS[c]
					g[y][x] = spec[1] if rng.randf() < float(spec[0]) else "."
			elif c == "o":
				g[y][x] = "-" if strip_entities else ("O" if rng.randf() < 0.6 else "-")


## Grupos usados num template (para os testes enumerarem as combinações).
static func token_groups(rows: PackedStringArray) -> Array:
	var out: Array = []
	for r in rows:
		for c in GROUP_TOKENS.keys():
			if r.contains(c) and not out.has(c):
				out.append(c)
	out.sort()
	return out


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


## Preenche só células vazias ("."), sem apagar nada.
static func fill_empty(g: Array, x0: int, y0: int, x1: int, y1: int, c: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if at(g, x, y) == ".":
				put(g, x, y, c)


static func frame(g: Array, exits: String) -> void:
	fill(g, 0, 0, W - 1, 0, "#")
	fill(g, 0, FL, W - 1, H - 1, "#")
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
					for y in range(FL, H):
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
				for y in range(FL, H):
					put(g, x, y, "#")


## Linha do topo do chão na coluna x (primeiro sólido de cima para baixo a
## partir da linha 2); H se não houver.
static func floor_row(g: Array, x: int, from_y: int = 2) -> int:
	for y in range(from_y, H):
		if at(g, x, y) == "#" or at(g, x, y) == "-":
			return y
	return H


# ---------------------------------------------------------------------------
# Relevo
# ---------------------------------------------------------------------------

## Perfil do chão: linha do topo por coluna, com degraus <= MAX_STEP e as
## zonas das saídas no nível padrão (linha 21). Escreve o chão na grade e
## devolve o perfil (Array[int] de W posições).
static func _terrain(g: Array, rng: RandomNumberGenerator, exits: String, st: Dictionary, opts: Dictionary) -> Array:
	var fl: Array = []
	fl.resize(W)
	fl.fill(FL)
	var locked := {}
	for x in range(0, 4):
		locked[x] = true
	for x in range(W - 4, W):
		locked[x] = true
	if exits.contains("D") or exits.contains("U"):
		for x in range(15, 25):
			locked[x] = true
	var weights: Array = st["var"]
	var seg: Array = st["seg"]
	var min_row: int = int(st["min_row"])
	var cur := FL
	var x := 4
	while x < W - 4:
		var n := rng.randi_range(int(seg[0]), int(seg[1]))
		var dh := 0
		var roll := rng.randf() * (float(weights[0]) + float(weights[1]) + float(weights[2]) + float(weights[3]))
		if roll >= float(weights[0]):
			roll -= float(weights[0])
			dh = 1
			if roll >= float(weights[1]):
				roll -= float(weights[1])
				dh = 2
				if roll >= float(weights[2]):
					dh = 3
		# sobe mais do que desce (o chão base é a linha 21)
		var sign_ := -1 if cur >= FL or rng.randf() < 0.55 else 1
		cur = clampi(cur + dh * sign_, min_row, FL)
		for i in n:
			if x + i < W - 4 and not locked.has(x + i):
				fl[x + i] = cur
		x += n
	# suaviza: degraus <= MAX_STEP nos dois sentidos (zonas travadas ficam)
	for pass_ in 3:
		for i in range(1, W):
			if not locked.has(i):
				fl[i] = clampi(fl[i], fl[i - 1] - MAX_STEP, fl[i - 1] + MAX_STEP)
		for i in range(W - 2, -1, -1):
			if not locked.has(i):
				fl[i] = clampi(fl[i], fl[i + 1] - MAX_STEP, fl[i + 1] + MAX_STEP)
	for i in range(1, W - 1):
		if fl[i] < FL:
			fill(g, i, fl[i], i, FL - 1, "#")
	# fossos (só em trechos planos no nível 21, largura 2..4)
	if rng.randf() < float(st["pits"]):
		var tries := 0
		var made := 0
		var want := 1 + (1 if rng.randf() < float(st["pits"]) * 0.6 else 0)
		while made < want and tries < 30:
			tries += 1
			var pw := rng.randi_range(2, 4)
			var px := rng.randi_range(6, W - 7 - pw)
			var ok := true
			for i in range(px - 1, px + pw + 1):
				if locked.has(i) or fl[i] != FL or at(g, i, FL - 1) != ".":
					ok = false
					break
			if not ok:
				continue
			for i in range(px, px + pw):
				put(g, i, FL, ".")
				put(g, i, FL + 1, "^" if st["spikes"] else ".")
				fl[i] = FL + 2 if not st["spikes"] else H
			made += 1
	return fl


## Teto irregular: blocos pendurados, sempre com >= 7 tiles livres acima do
## chão (corredor: teto mais baixo, mas >= 5).
static func _ceiling(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array, low: bool) -> void:
	var x := 2
	while x < W - 2:
		var n := rng.randi_range(3, 7)
		var depth := rng.randi_range(2, 5) if not low else rng.randi_range(4, 9)
		if rng.randf() < 0.4 and not low:
			depth = 0
		for i in range(x, mini(x + n, W - 1)):
			if exits.contains("U") and i >= 14 and i <= 25:
				continue
			var clear := 5 if low else 7
			var bottom := mini(depth, int(fl[i]) - clear - 1)
			if bottom >= 1:
				fill(g, i, 1, i, bottom, "#")
		x += n


## Uma plataforma one-way (só em células vazias).
static func plat(g: Array, x0: int, x1: int, y: int) -> void:
	fill_empty(g, maxi(x0, 1), y, mini(x1, W - 2), y, "-")


## Plataformas em camadas sobre um trecho: cada uma até 3 linhas acima do
## apoio de baixo (chão ou plataforma anterior), sobrepostas na horizontal.
static func _tiers(g: Array, rng: RandomNumberGenerator, fl: Array, x0: int, x1: int, count: int) -> void:
	var cx := rng.randi_range(x0, x1)
	var base := FL
	for i in range(cx - 3, cx + 4):
		base = mini(base, int(fl[clampi(i, 0, W - 1)]))
	var y := base - 3
	for i in count:
		if y < 5:
			break
		var w := rng.randi_range(4, 7)
		var a := clampi(cx - w / 2, 2, W - 3 - w)
		plat(g, a, a + w - 1, y)
		cx = clampi(cx + rng.randi_range(-5, 5), x0, x1)
		y -= 3


# ---------------------------------------------------------------------------
# Tipos de sala
# ---------------------------------------------------------------------------

## Escada de plataformas one-way do chão até a saída de cima: zigue-zague
## perto do centro e plataforma larga na linha 4, sob a abertura. De lá o
## pulo cruza o topo da sala e o impulso de transição (Player.transition_boost)
## leva o jogador até a sala de cima.
static func ladder(g: Array, rng: RandomNumberGenerator) -> void:
	var base := FL
	for x in range(16, 24):
		base = mini(base, floor_row(g, x))
	var left := rng.randf() < 0.5
	chain(g, 16 if left else 23, 23 if left else 16, base, 4, 5)
	plat(g, 16, 23, 4)


## Cadeia de plataformas one-way de `from_row` (chão) até `to_row`, em
## degraus de no máximo 3 linhas, alternando os centros xa/xb. A última fica
## exatamente em `to_row`.
static func chain(g: Array, xa: int, xb: int, from_row: int, to_row: int, width: int) -> void:
	var span := from_row - to_row
	if span <= 0:
		return
	var n := int(ceil(span / 3.0))
	for k in range(1, n + 1):
		var y := from_row - int(roundf(k * span / float(n)))
		var cx := xa if k % 2 == 1 else xb
		plat(g, cx - width / 2, cx - width / 2 + width - 1, y)


static func _free_floor_x(rng: RandomNumberGenerator, exits: String) -> int:
	for i in 20:
		var x := rng.randi_range(5, W - 6)
		if exits.contains("D") and x >= 16 and x <= 23:
			continue
		return x
	return 8


## Coluna com chão firme e 3 tiles livres acima (para inimigos, baús, NPCs).
static func _ground_spot(g: Array, rng: RandomNumberGenerator, x0: int, x1: int, avoid: Array = []) -> Vector2i:
	for i in 30:
		var x := rng.randi_range(x0, x1)
		if avoid.has(x):
			continue
		var y := floor_row(g, x)
		if y >= H or at(g, x, y) != "#":
			continue
		if at(g, x, y - 1) == "." and at(g, x, y - 2) == "." and at(g, x, y - 3) == ".":
			return Vector2i(x, y - 1)
	return Vector2i(-1, -1)


static func _combat(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array, opts: Dictionary) -> void:
	var tier := int(opts.get("tier", 1))
	var entry: String = opts.get("entry", "L")
	var lo := 10 if entry == "L" else 5
	var hi := W - 11 if entry == "R" else W - 6
	var used := []
	# bastião: bloco sólido saindo do chão (degraus <= 3) com inimigos em cima
	if rng.randf() < 0.55:
		var bx := rng.randi_range(12, W - 20)
		var bw := rng.randi_range(5, 8)
		var ok := true
		for x in range(bx - 1, bx + bw + 1):
			if int(fl[x]) != FL or at(g, x, FL - 1) != "." or at(g, x, FL - 5) != "." or ((exits.contains("D") or exits.contains("U")) and x >= 14 and x <= 25):
				ok = false
				break
		if ok:
			var bh := rng.randi_range(2, 3)
			fill(g, bx, FL - bh, bx + bw - 1, FL - 1, "#")
			for x in range(bx, bx + bw):
				fl[x] = FL - bh
			put(g, bx + bw / 2, FL - bh - 1, "E")
			used.append_array([bx + bw / 2 - 1, bx + bw / 2, bx + bw / 2 + 1])
	# atirador numa plataforma alta (alcançável: 3 linhas acima do chão local)
	if rng.randf() < 0.5 + 0.1 * tier:
		var sx := rng.randi_range(6, W - 12) if entry != "R" else rng.randi_range(12, W - 7)
		var base := FL
		for i in range(sx - 1, sx + 6):
			base = mini(base, int(fl[clampi(i, 0, W - 1)]))
		var py := base - 3
		if py > 6 and at(g, sx + 2, py) == "." and at(g, sx + 2, py - 1) == "." and at(g, sx + 2, py - 2) == ".":
			plat(g, sx, sx + 5, py)
			put(g, sx + 2, py - 1, "U")
	# uma camada de plataformas para brigar no alto
	if rng.randf() < 0.6:
		var cx := rng.randi_range(8, W - 9)
		_tiers(g, rng, fl, cx - 2, cx + 2, 1)
	# lanterna de Ímpeto no ar (encadear dash e golpes)
	if rng.randf() < 0.55:
		var ox := rng.randi_range(10, W - 11)
		var oy := int(fl[ox]) - rng.randi_range(6, 8)
		if oy > 3 and at(g, ox, oy) == "." and at(g, ox, oy + 1) == ".":
			put(g, ox, oy, "I")
	# cobertura baixa (pula por cima)
	if rng.randf() < 0.35:
		var x := _free_floor_x(rng, exits)
		var y := int(fl[x])
		if y == FL and at(g, x, y - 1) == "." and at(g, x + 1, y - 1) == ".":
			fill(g, x, y - rng.randi_range(1, 2), x + 1, y - 1, "#")
	# serra patrulhando no alto
	if tier >= 2 and rng.randf() < 0.35:
		var sx2 := rng.randi_range(10, W - 11)
		if at(g, sx2, 7) == ".":
			put(g, sx2, 7, "S")
	for i in rng.randi_range(2, 3) + (tier - 1):
		var s := _ground_spot(g, rng, lo, hi, used)
		if s.x >= 0:
			put(g, s.x, s.y, "E")
			used.append_array([s.x - 1, s.x, s.x + 1])
	for i in rng.randi_range(0, 1 + tier / 2):
		var fx := rng.randi_range(8, W - 9)
		var fy := rng.randi_range(6, 10)
		if at(g, fx, fy) == ".":
			put(g, fx, fy, "F")


## Arena trancada (Dead Cells/Katana Zero): portões fecham, inimigos vêm em
## ondas (o Level divide em 2-3 ondas), atiradores nas laterais, lanternas
## de Ímpeto no alto para lutar no ar. Nota S/A/B/C ao limpar.
static func _arena(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array, opts: Dictionary) -> void:
	var tier := int(opts.get("tier", 1))
	var sym := rng.randf() < 0.6
	# pilares baixos de cobertura (2 tiles: dá para subir)
	var px := rng.randi_range(8, 11)
	for x in ([px, W - 2 - px] if sym else [px]):
		if int(fl[x]) == FL and int(fl[x + 1]) == FL:
			fill(g, x, FL - 2, x + 1, FL - 1, "#")
			fl[x] = FL - 2
			fl[x + 1] = FL - 2
	# plataformas laterais (3 acima do chão) com atiradores e central mais alta
	plat(g, 3, 8, FL - 3)
	plat(g, W - 9, W - 4, FL - 3)
	plat(g, 13, 18, FL - 6)
	plat(g, W - 19, W - 14, FL - 6)
	if rng.randf() < 0.6:
		plat(g, 17, 22, FL - 9)
	put(g, 5, FL - 4, "U")
	if tier >= 2 or rng.randf() < 0.5:
		put(g, W - 6, FL - 4, "U")
	# lanternas
	put(g, 10, FL - 9, "I")
	put(g, W - 11, FL - 9, "I")
	# inimigos: chão + voadores (divididos em ondas pelo Level)
	var used := [5, W - 6]
	for i in 4 + tier:
		var s := _ground_spot(g, rng, 6, W - 7, used)
		if s.x >= 0:
			put(g, s.x, s.y, "E")
			used.append_array([s.x - 1, s.x, s.x + 1])
	for i in 1 + tier:
		var fx := rng.randi_range(8, W - 9)
		var fy := rng.randi_range(5, 9)
		if at(g, fx, fy) == ".":
			put(g, fx, fy, "F")
	# portões nas saídas laterais
	if exits.contains("L"):
		put(g, 0, 17, "G")
	if exits.contains("R"):
		put(g, W - 1, 17, "G")


## Plataforma estilo Celeste: relevo acidentado, fossos com espinhos,
## blocos flutuantes e plataformas sobre os vãos.
static func _platforming(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array) -> void:
	# pedras sólidas sobre os fossos de espinho (ninguém passa por baixo)
	for x in range(2, W - 2):
		if at(g, x, FL + 1) == "^" and at(g, x - 1, FL + 1) != "^":
			var w := 0
			while at(g, x + w, FL + 1) == "^":
				w += 1
			if w >= 3 and rng.randf() < 0.7:
				var sx := x + w / 2 - (1 if w >= 4 else 0)
				if rng.randf() < 0.5:
					fill(g, sx, FL - 1, sx + (1 if w >= 4 else 0), FL - 1, "#")
				else:
					plat(g, sx - 1, sx + 1, FL - 2)
	# pilares baixos no chão (obstáculos para pular por cima)
	for i in rng.randi_range(0, 2):
		var x := rng.randi_range(6, W - 8)
		var y := int(fl[x])
		if y == int(fl[x + 1]) and y <= FL and at(g, x, y - 1) == "." and at(g, x + 1, y - 1) == "." and at(g, x, y - 4) == ".":
			fill(g, x, y - rng.randi_range(1, 3), x + rng.randi_range(0, 1), y - 1, "#")
	# rotas por cima: plataformas one-way em camadas (atravessáveis por baixo)
	for i in rng.randi_range(1, 2):
		_tiers(g, rng, fl, 6 + i * 12, 10 + i * 12, rng.randi_range(1, 3))
	# lanternas de Ímpeto sobre os fossos (atalho aéreo: dash → golpe → dash)
	for x in range(3, W - 3):
		if at(g, x, FL + 1) == "^" and at(g, x - 1, FL + 1) != "^":
			var pw := 0
			while at(g, x + pw, FL + 1) == "^":
				pw += 1
			var ox := x + pw / 2
			if pw >= 3 and at(g, ox, FL - 5) == "." and rng.randf() < 0.75:
				put(g, ox, FL - 5, "I")
	# mola para uma rota alta
	if rng.randf() < 0.35:
		var sp := _ground_spot(g, rng, 6, W - 7)
		if sp.x >= 0 and at(g, sp.x, sp.y - 4) == ".":
			put(g, sp.x, sp.y, "J")
	if rng.randf() < 0.6:
		var s := _ground_spot(g, rng, 8, W - 9)
		if s.x >= 0:
			put(g, s.x, s.y, "E")
	for i in rng.randi_range(0, 2):
		var fx := rng.randi_range(8, W - 9)
		var fy := rng.randi_range(6, 11)
		if at(g, fx, fy) == ".":
			put(g, fx, fy, "F")


## "Caminho da dor": chão todo de espinhos, pilares e blocos com vãos maiores
## (pode exigir dash; há cristais de dash nos vãos grandes) e serras.
static func _gauntlet(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	# chão seguro: bordas (saídas) e, com saída de baixo, o centro
	var mid := exits.contains("D") or exits.contains("U")
	for x in range(4, W - 4):
		if mid and x >= 14 and x <= 25:
			continue
		put(g, x, FL, "^")
	if mid:
		_pillars(g, rng, 4, 13)
		_pillars(g, rng, 26, W - 5)
	else:
		_pillars(g, rng, 4, W - 5)
	put(g, W - 3, FL - 1, "R")


## Pilares/blocos sobre o fosso de espinhos entre o chão seguro em x_from-1 e
## x_to+1. Vãos de 3..5 (6 com cristal de dash); serras no alto às vezes.
static func _pillars(g: Array, rng: RandomNumberGenerator, x_from: int, x_to: int) -> void:
	var x := x_from
	var top := FL
	for guard in 12:
		var remaining := x_to + 1 - x
		if remaining <= 5:
			break
		var gap := rng.randi_range(3, mini(6, remaining - 3))
		var nx := x + gap
		var width := clampi(rng.randi_range(2, 3), 1, maxi(x_to - 1 - nx, 1))
		var ny := clampi(top + rng.randi_range(-2, 2), 15, FL - 1)
		if rng.randf() < 0.6:
			fill(g, nx, ny, nx + width - 1, FL, "#") # pilar
		else:
			fill(g, nx, ny, nx + width - 1, ny, "#") # bloco flutuante
		if gap >= 5:
			put(g, x + gap / 2, mini(ny, top) - 3, "D")
		elif gap >= 4 and rng.randf() < 0.5:
			put(g, x + gap / 2, mini(ny, top) - 4, "I")
		elif rng.randf() < 0.4:
			put(g, x + gap / 2, mini(ny, top) - 6, "S")
		x = nx + width
		top = ny


static func _corridor(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array) -> void:
	var used := []
	for i in rng.randi_range(0, 2):
		var s := _ground_spot(g, rng, 9, W - 10, used)
		if s.x >= 0:
			put(g, s.x, s.y, "E")
			used.append(s.x)
	if rng.randf() < 0.3:
		var c := _ground_spot(g, rng, 6, W - 7, used)
		if c.x >= 0:
			put(g, c.x, c.y, "C")
	if rng.randf() < 0.5:
		_tiers(g, rng, fl, 10, W - 11, 1)
	# emboscada: voadores esperando perto do teto
	if rng.randf() < 0.5:
		var fx := rng.randi_range(12, W - 13)
		if at(g, fx, 8) == ".":
			put(g, fx, 8, "F")


## Alavanca no alto (plataformas em escada até ela), portões nas outras
## saídas e, às vezes, parede quebrável escondendo um baú.
static func _puzzle(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array, opts: Dictionary) -> void:
	var entry: String = opts.get("entry", "L")
	var right := entry != "R"
	var lx := W - 9 if right else 8
	# escada de plataformas até a alavanca (linha 8), longe da entrada
	var other := lx + (-6 if right else 6)
	chain(g, other, lx, int(fl[lx]), 11, 5)
	plat(g, lx - 3, lx + 3, 8)
	put(g, lx, 7, "T")
	# portões nas outras saídas
	for e in exits:
		if e == entry:
			continue
		match e:
			"L": put(g, 0, 17, "G")
			"R": put(g, W - 1, 17, "G")
	# bloco quebrável escondendo baú
	if rng.randf() < 0.5 and not exits.contains("D"):
		var bx := 18
		if int(fl[bx]) == FL and int(fl[bx + 3]) == FL:
			fill_empty(g, bx, FL - 3, bx + 3, FL - 1, "B")
			put(g, bx + 1, FL - 1, "C")


static func _treasure(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array) -> void:
	# pedestal de 2 tiles sobre chão plano (longe do centro se há saída U/D)
	var mid := not (exits.contains("D") or exits.contains("U"))
	var x := -1
	for i in 30:
		var cx := 17 + rng.randi_range(0, 3) if mid else (7 + rng.randi_range(0, 3) if rng.randf() < 0.5 else 29 + rng.randi_range(0, 3))
		var flat := true
		for j in range(cx - 2, cx + 4):
			if int(fl[j]) != int(fl[cx]) or at(g, j, int(fl[cx]) - 1) != ".":
				flat = false
				break
		if flat:
			x = cx
			break
	if x < 0:
		var s := _ground_spot(g, rng, 6, W - 7)
		if s.x >= 0:
			put(g, s.x, s.y, "C")
		return
	var base := int(fl[x])
	var top := maxi(base - 2, 12)
	fill(g, x - 2, top, x + 3, base - 1, "#")
	put(g, x, top - 1, "C")
	if at(g, x, 1) == "." and at(g, x, 2) == ".":
		put(g, x, 1, "W")


## Gruta secreta: teto baixo e pesado, relíquia ou baú num altar.
static func _secret(g: Array, rng: RandomNumberGenerator, exits: String) -> void:
	for x in range(1, W - 1):
		if exits.contains("U") and x >= 14 and x <= 25:
			continue
		fill(g, x, 1, x, 6, "#")
	var px := 19 if not (exits.contains("D") or exits.contains("U")) else 8
	fill(g, px - 1, 19, px + 2, 20, "#")
	put(g, px, 18, "R" if rng.randf() < 0.5 else "C")


static func _entrance(g: Array, exits: String, fl: Array) -> void:
	var x := 8 if not exits.contains("L") else 30
	var sx := x
	# área plana ao redor do ponto de nascimento (espaço para respirar)
	for cx in range(maxi(1, sx - 3), mini(W - 1, sx + 12)):
		if int(fl[cx]) < FL:
			fill(g, cx, int(fl[cx]), cx, FL - 1, ".")
			fl[cx] = FL
	put(g, sx, FL - 1, "P")
	var hx := 20 if not exits.contains("D") else 26
	put(g, hx, int(fl[hx]) - 1, "H")


static func _exit(g: Array, exits: String, fl: Array) -> void:
	var x := 28
	while x > 4 and at(g, x, int(fl[x]) - 1) != ".":
		x -= 1
	put(g, x, int(fl[x]) - 1, "X")


## Sala de passagem entre regiões: portal de pedra na saída e um santuário
## (descanso) no meio — ponto seguro antes de mudar de região.
static func _passage(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array) -> void:
	var hx := 20 if not (exits.contains("D") or exits.contains("U")) else 9
	if int(fl[hx]) == FL and at(g, hx, FL - 1) == ".":
		put(g, hx, FL - 1, "H")
	if rng.randf() < 0.5:
		var lx := 6 if hx != 6 else 30
		if at(g, lx, 3) == ".":
			put(g, lx, 3, "L")


static func _hub(g: Array) -> void:
	for x in [6, 12, 27, 33]:
		put(g, x, FL - 1, "N")
	put(g, 20, FL - 1, "Q")
	put(g, 16, FL - 1, "H")


static func _boss(g: Array) -> void:
	plat(g, 6, 12, 18)
	plat(g, 27, 33, 18)
	plat(g, 16, 23, 15)
	put(g, 24, 18, "M")
	put(g, 0, 17, "G")
	put(g, W - 1, 17, "G")
	put(g, 10, FL - 1, "A")


## Poço vertical: plataformas alternadas nas paredes e ressaltos sólidos.
static func _shaft(g: Array, rng: RandomNumberGenerator, exits: String, fl: Array) -> void:
	for side in [0, 1]:
		var y: int = FL - 5 - side * 2
		while y > 6:
			var x0 := 2 if side == 0 else W - 7
			if rng.randf() < 0.5:
				fill_empty(g, x0 if side == 0 else W - 4, y, (x0 + 2) if side == 0 else W - 2, y, "#")
			else:
				plat(g, x0, x0 + 4, y)
			y -= rng.randi_range(4, 6)
	# lanternas no meio do poço (subir encadeando golpes) e morcegos
	var oy := FL - 6
	while oy > 5:
		var ox := rng.randi_range(12, W - 13)
		if at(g, ox, oy) == "." and at(g, ox, oy - 1) == "." and at(g, ox, oy + 1) == "." and rng.randf() < 0.6:
			put(g, ox, oy, "I")
		oy -= rng.randi_range(5, 7)
	for i in rng.randi_range(1, 2):
		var fx := rng.randi_range(10, W - 11)
		var fy := rng.randi_range(6, 12)
		if at(g, fx, fy) == ".":
			put(g, fx, fy, "F")


static func _decorate(g: Array, rng: RandomNumberGenerator, opts: Dictionary) -> void:
	for i in rng.randi_range(1, 3):
		var x := rng.randi_range(3, W - 4)
		var y := rng.randi_range(3, 8)
		if at(g, x, y) == "." and at(g, x, y + 1) == ".":
			put(g, x, y, "L")
	if opts.get("indoor", false) and rng.randf() < 0.5:
		var x := rng.randi_range(6, W - 7)
		if at(g, x, 1) == "." and at(g, x, 2) == ".":
			put(g, x, 1, "W")
