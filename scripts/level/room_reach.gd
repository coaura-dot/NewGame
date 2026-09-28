class_name RoomReach
extends RefCounted
## Validador de travessia de uma sala (grade 40x24 de caracteres), usando as
## capacidades REAIS do herói na escala de 8 px (Celeste): pulo de ~3 tiles,
## alcance horizontal do pulo, queda com deriva e, opcionalmente, dash.
## O herói ocupa 1 tile de largura e 2 de altura.
##
## Usado pelo RoomSynth (refaz a sala se falhar), pelo LevelGenerator (troca
## templates que não passam) e pelos testes.

const W := LevelConst.ROOM_W
const H := LevelConst.ROOM_H
const SOLID := "#Z" ## "B" (quebrável) conta como vazio: nunca pode ser degrau obrigatório
const PLATFORM := "-"
const HAZARD := "^"

## Capacidades (em tiles). "jump": só pulo; "dash": pulo + 1 dash.
const CAPS := {
	"jump": {"up": 3, "reach": [6, 6, 5, 4], "drift": 4},
	"dash": {"up": 6, "reach": [10, 9, 8, 7, 6, 5, 4], "drift": 7},
}


static func _ch(g: Array, x: int, y: int) -> String:
	if x < 0 or x >= W:
		return "#"
	if y < 0:
		return "."
	if y >= H:
		return "#"
	return g[y][x]


static func blocked(g: Array, x: int, y: int) -> bool:
	var c := _ch(g, x, y)
	return SOLID.contains(c) or c == HAZARD


static func support(g: Array, x: int, y: int) -> bool:
	var c := _ch(g, x, y)
	return SOLID.contains(c) or c == PLATFORM


## Pés em (x, y): a célula e a de cima livres, e algo firme embaixo.
static func standable(g: Array, x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	if blocked(g, x, y) or blocked(g, x, y - 1) or not support(g, x, y + 1):
		return false
	# dentro de uma plataforma fina só se ela estiver apoiada em sólido (o
	# corpo atravessa a plataforma e pisa no bloco de baixo)
	return _ch(g, x, y) != PLATFORM or SOLID.contains(_ch(g, x, y + 1))


## Onde cai quem está em (x, y) (desce até achar apoio). -1 se cair em espinho
## ou sair da sala por baixo.
static func fall_from(g: Array, x: int, y: int) -> int:
	var yy := y
	while yy < H:
		if blocked(g, x, yy) or blocked(g, x, yy - 1):
			return -1
		if support(g, x, yy + 1):
			return yy
		yy += 1
	return -1


static func _clear_col(g: Array, x: int, y_from: int, y_to: int) -> bool:
	for y in range(mini(y_from, y_to), maxi(y_from, y_to) + 1):
		if blocked(g, x, y) or blocked(g, x, y - 1):
			return false
	return true


static func _clear_row(g: Array, x_from: int, x_to: int, y: int) -> bool:
	for x in range(mini(x_from, x_to), maxi(x_from, x_to) + 1):
		if blocked(g, x, y) or blocked(g, x, y - 1):
			return false
	return true


## Grades pré-calculadas (rápido): free2 = corpo de 2 tiles cabe em (x,y);
## stand = dá para ficar em pé; land = onde cai quem está em (x,y) (-1 = morre).
class Grid:
	var free2 := PackedByteArray()
	var stand := PackedByteArray()
	var land := PackedInt32Array()

	func _init(g: Array) -> void:
		free2.resize(W * H)
		stand.resize(W * H)
		land.resize(W * H)
		for y in H:
			for x in W:
				var i := y * W + x
				free2[i] = 1 if not RoomReach.blocked(g, x, y) and not RoomReach.blocked(g, x, y - 1) else 0
				stand[i] = 1 if RoomReach.standable(g, x, y) else 0
		for x in W:
			var below := -1
			for y in range(H - 1, -1, -1):
				var i := y * W + x
				if free2[i] == 0:
					below = -1
				elif stand[i] == 1:
					below = y
				land[i] = below
				# célula livre mas o que está abaixo é espinho/buraco => -1 fica

	func f(x: int, y: int) -> bool:
		if x < 0 or x >= W or y < 0 or y >= H:
			return false
		return free2[y * W + x] == 1

	func s(x: int, y: int) -> bool:
		if x < 0 or x >= W or y < 0 or y >= H:
			return false
		return stand[y * W + x] == 1

	func l(x: int, y: int) -> int:
		if x < 0 or x >= W or y < 0 or y >= H:
			return -1
		return land[y * W + x]

	func col(x: int, y0: int, y1: int) -> bool:
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			if not f(x, y):
				return false
		return true

	func row(x0: int, x1: int, y: int) -> bool:
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if not f(x, y):
				return false
		return true


## Vizinhos alcançáveis a partir de (x, y) em pé.
static func moves(gr: Grid, x: int, y: int, cap: Dictionary) -> Array:
	var out := []
	var up: int = cap["up"]
	var reach: Array = cap["reach"]
	# andar / cair da borda (com deriva no ar)
	for d in [-1, 1]:
		var nx: int = x + d
		if not gr.f(nx, y):
			continue
		if gr.s(nx, y):
			out.append(Vector2i(nx, y))
		else:
			for drift in range(0, int(cap["drift"]) + 1):
				var fx: int = nx + d * drift
				if not gr.f(fx, y):
					break
				var ly := gr.l(fx, y)
				if ly >= 0:
					out.append(Vector2i(fx, ly))
	# pulos: sobe até "up" tiles e cruza até "reach[dy]" tiles
	for dy in range(0, up + 1):
		var ty: int = y - dy
		if ty < 0:
			break
		if not gr.f(x, ty):
			break # bateu a cabeça: não sobe mais
		var r: int = reach[mini(dy, reach.size() - 1)]
		for d in [-1, 1]:
			for k in range(1, r + 1):
				var tx: int = x + d * k
				if not gr.f(tx, ty):
					break # parede no caminho do arco nesta altura
				if gr.s(tx, ty):
					out.append(Vector2i(tx, ty))
				elif dy == 0 or true:
					var ly := gr.l(tx, ty)
					if ly > ty:
						out.append(Vector2i(tx, ly))
	return out


static func reachable_from(g: Array, start: Vector2i, cap: Dictionary, gr: Grid = null) -> Dictionary:
	var seen := {}
	if start.x < 0:
		return seen
	if gr == null:
		gr = Grid.new(g)
	var st := [start]
	seen[start] = true
	while not st.is_empty():
		var p: Vector2i = st.pop_back()
		for n in moves(gr, p.x, p.y, cap):
			if not seen.has(n):
				seen[n] = true
				st.append(n)
	return seen


## Ponto em pé onde o herói aparece ao entrar pela saída e.
static func entry_point(g: Array, e: String) -> Vector2i:
	match e:
		"L":
			for x in range(0, 4):
				var y := fall_from(g, x, LevelConst.EXIT_LR_ROWS[-1])
				if y >= 0 and standable(g, x, y):
					return Vector2i(x, y)
		"R":
			for x in range(W - 1, W - 5, -1):
				var y := fall_from(g, x, LevelConst.EXIT_LR_ROWS[-1])
				if y >= 0 and standable(g, x, y):
					return Vector2i(x, y)
		"U":
			for x in LevelConst.EXIT_UD_COLS:
				var y := fall_from(g, x, 1)
				if y >= 0 and standable(g, x, y):
					return Vector2i(x, y)
		"D":
			for x in LevelConst.EXIT_UD_COLS:
				var y := fall_from(g, x, LevelConst.FLOOR_ROW)
				if y >= 0 and standable(g, x, y):
					return Vector2i(x, y)
	return Vector2i(-1, -1)


## A saída e é alcançada a partir do conjunto "seen"?
static func exit_reached(g: Array, e: String, seen: Dictionary, cap: Dictionary) -> bool:
	for p in seen.keys():
		match e:
			"L":
				if p.x <= 1 and p.y >= LevelConst.EXIT_LR_ROWS[0] and p.y <= LevelConst.EXIT_LR_ROWS[-1]:
					return true
			"R":
				if p.x >= W - 2 and p.y >= LevelConst.EXIT_LR_ROWS[0] and p.y <= LevelConst.EXIT_LR_ROWS[-1]:
					return true
			"U":
				if p.x >= LevelConst.EXIT_UD_COLS[0] - 1 and p.x <= LevelConst.EXIT_UD_COLS[-1] + 1 and p.y <= int(cap["up"]) and _clear_col(g, clampi(p.x, LevelConst.EXIT_UD_COLS[0], LevelConst.EXIT_UD_COLS[-1]), 0, p.y):
					return true
			"D":
				if p.x >= LevelConst.EXIT_UD_COLS[0] and p.x <= LevelConst.EXIT_UD_COLS[-1] and p.y >= LevelConst.FLOOR_ROW:
					return true
	return false


## Todas as saídas se conectam entre si (a partir de cada entrada)?
## Retorna "" se ok, ou a descrição do problema.
static func check_room(g: Array, exits: String, mode: String = "jump") -> String:
	var cap: Dictionary = CAPS.get(mode, CAPS["jump"])
	var gr := Grid.new(g)
	if exits.length() == 1:
		# beco sem saída: precisa dar para entrar E voltar pela mesma saída
		var st := entry_point(g, exits)
		if st.x < 0:
			return "entrada %s sem chão" % exits
		if not exit_reached(g, exits, reachable_from(g, st, cap, gr), cap):
			return "não volta por %s (%s)" % [exits, mode]
		return ""
	for a in exits:
		var start := entry_point(g, a)
		if start.x < 0:
			return "entrada %s sem chão" % a
		var seen := reachable_from(g, start, cap, gr)
		for b in exits:
			if b == a:
				continue
			if not exit_reached(g, b, seen, cap):
				return "%s -> %s inalcançável (%s)" % [a, b, mode]
	return ""


## Conveniência para linhas de texto.
static func check_rows(rows: PackedStringArray, exits: String, mode: String = "jump") -> String:
	var g := []
	for r in rows:
		var row := []
		for i in r.length():
			row.append(r[i])
		g.append(row)
	return check_room(g, exits, mode)
