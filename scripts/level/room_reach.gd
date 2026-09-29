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
const PLATFORM := "-O" ## O = plataforma que desaba (dá para usar se for rápido)
const MOVER_REACH := 9 ## plataforma móvel: 3 de largura + 6 de trilho
const HAZARD := "^"

## Capacidades (em tiles). "jump": só pulo; "dash": pulo + 1 dash.
const CAPS := {
	"jump": {"up": 3, "reach": [6, 6, 5, 4], "drift": 4},
	"dash": {"up": 6, "reach": [10, 9, 8, 7, 6, 5, 4], "drift": 7},
	## mola: lançamento de ~5 tiles
	"spring": {"up": 5, "reach": [5, 5, 5, 4, 4, 3], "drift": 5},
}

## Elementos que viram "nós aéreos" (dá para quicar/recarregar no ar):
##   I = Orbe de Impulso (golpear quica ~4 tiles), D = cristal de dash (só no
##   modo dash: recarrega o dash), J = mola (no chão; lança ~5 tiles),
##   ^ acima do fosso = espinho de pogo (golpe para baixo quica ~4 tiles),
##   b = sino (golpear: recarrega dash + pulo extra), j = pena (encostar: pulo
##   extra), d = cristal duplo (modo dash).


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
	return SOLID.contains(c) or PLATFORM.contains(c) or c == "U"


## Pés em (x, y): a célula e a de cima livres, e algo firme embaixo.
static func standable(g: Array, x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	if blocked(g, x, y) or blocked(g, x, y - 1) or not support(g, x, y + 1):
		return false
	# dentro de uma plataforma fina só se ela estiver apoiada em sólido (o
	# corpo atravessa a plataforma e pisa no bloco de baixo)
	return not PLATFORM.contains(_ch(g, x, y)) or SOLID.contains(_ch(g, x, y + 1))


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
	var wall := PackedByteArray()

	func _init(g_in: Array) -> void:
		var g := RoomReach.expand_movers(g_in)
		free2.resize(W * H)
		stand.resize(W * H)
		land.resize(W * H)
		wall.resize(W * H)
		for y in H:
			for x in W:
				var i := y * W + x
				wall[i] = 1 if RoomReach.SOLID.contains(RoomReach._ch(g, x, y)) else 0
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

	func w(x: int, y: int) -> bool:
		if x < 0 or x >= W:
			return true
		if y < 0 or y >= H:
			return false
		return wall[y * W + x] == 1

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


static func specials(g: Array, dash_mode: bool) -> Dictionary:
	var orbs: Array = []
	var touch: Array = []
	var springs := {}
	var thorns: Array = []
	for y in H:
		for x in W:
			var c: String = g[y][x]
			if c == "I" or c == "b":
				orbs.append(Vector2i(x, y)) # golpear: alcance do golpe conta
			elif c == "j" or ((c == "D" or c == "d") and dash_mode):
				touch.append(Vector2i(x, y)) # encostar: só o corpo
			elif c == "J":
				springs[Vector2i(x, y)] = true
			elif c == HAZARD and y < LevelConst.FLOOR_ROW and y >= 3 and _ch(g, x, y - 1) == "." and _ch(g, x, y - 2) == ".":
				# espinho "de pé" acima do fosso: dá para quicar nele (pogo)
				thorns.append(Vector2i(x, y))
	return {"orbs": orbs, "touch": touch, "springs": springs, "thorns": thorns}


## Dá para cair em cima do espinho s (golpe para baixo = pogo) a partir de p?
static func _can_reach_pogo(gr: Grid, p: Vector2i, s: Vector2i, cap: Dictionary) -> bool:
	var n := Vector2i(s.x, s.y - 1) # pés no instante do quique
	if not gr.f(n.x, n.y):
		return false
	var up: int = cap["up"]
	var reach: Array = cap["reach"]
	var rise := p.y - n.y + 1 # precisa passar 1 tile acima do espinho
	if rise > up:
		return false
	var r: int
	if rise >= 0:
		r = int(reach[clampi(rise, 0, reach.size() - 1)]) + 1
	else:
		r = int(reach[0]) + mini(-rise / 2, 3)
	if absi(n.x - p.x) > r:
		return false
	# algum caminho "sobe/anda/desce" livre, passando pelo menos 1 tile acima do espinho
	var hi := maxi(p.y - up, 0)
	for apex in range(mini(n.y - 1, p.y), hi - 1, -1):
		if gr.col(p.x, apex, p.y) and gr.row(p.x, n.x, apex) and gr.col(n.x, apex, n.y):
			return true
	return false


## Dá para golpear/tocar o orbe o a partir de p (pés em p)?
static func _can_reach_orb(gr: Grid, p: Vector2i, o: Vector2i, cap: Dictionary, bonus: int = 2) -> bool:
	var feet := Vector2i(o.x, o.y + 1)
	if not gr.f(feet.x, feet.y):
		return false
	var dy := p.y - o.y # quantos tiles o orbe está acima dos pés
	var up: int = cap["up"]
	if dy > up + 2 or dy < -6:
		return false
	var reach: Array = cap["reach"]
	var r: int = int(reach[clampi(dy, 0, reach.size() - 1)]) + bonus # + alcance do golpe (~2,5 tiles) ou do corpo
	if absi(o.x - p.x) > r:
		return false
	if dy >= 0:
		var apex := maxi(feet.y, p.y - up)
		return gr.col(p.x, apex, p.y) and gr.row(p.x, o.x, apex)
	return gr.row(p.x, o.x, p.y) and gr.col(o.x, p.y, feet.y)


## Plataforma móvel 'U' (anda 6 tiles para a direita, 3 de largura): para o
## validador vira uma ponte contínua no trilho.
static func expand_movers(g: Array) -> Array:
	var has := false
	for row in g:
		if row.has("U"):
			has = true
			break
	if not has:
		return g
	var out := []
	for row in g:
		out.append(row.duplicate())
	for y in H:
		for x in W:
			if g[y][x] == "U":
				for k in MOVER_REACH:
					if x + k < W and out[y][x + k] == ".":
						out[y][x + k] = "-"
				out[y][x] = "-"
	return out


## Subida por salto de parede numa chaminé (paredes dos dois lados, vão de até
## 5 tiles): devolve os pontos "no ar" alcançáveis subindo pela coluna x.
static func chimney(gr: Grid, x: int, y: int) -> Array:
	var out := []
	var yy := y - 1
	var guard := 0
	while yy > 0 and guard < H:
		guard += 1
		if not gr.f(x, yy):
			break
		var lw := -1
		var rw := -1
		for k in range(1, 6):
			if gr.w(x - k, yy) or gr.w(x - k, yy - 1):
				lw = k
				break
		for k in range(1, 6):
			if gr.w(x + k, yy) or gr.w(x + k, yy - 1):
				rw = k
				break
		if lw < 0 or rw < 0 or lw + rw - 1 > 5:
			break
		out.append(Vector2i(x, yy))
		yy -= 1
	return out


static func reachable_from(g: Array, start: Vector2i, cap: Dictionary, gr: Grid = null, sp: Dictionary = {}, wall_jump: bool = true) -> Dictionary:
	var seen := {}
	if start.x < 0:
		return seen
	if gr == null:
		gr = Grid.new(g)
	if sp.is_empty():
		sp = specials(g, int(cap["up"]) >= int(CAPS["dash"]["up"]))
	var orbs: Array = sp["orbs"]
	var springs: Dictionary = sp["springs"]
	var thorns: Array = sp.get("thorns", [])
	var touch: Array = sp.get("touch", [])
	var st := [start]
	seen[start] = true
	while not st.is_empty():
		var p: Vector2i = st.pop_back()
		var c := cap
		if springs.has(p):
			c = CAPS["spring"] if int(CAPS["spring"]["up"]) > int(cap["up"]) else cap
		for n in moves(gr, p.x, p.y, c):
			if not seen.has(n):
				seen[n] = true
				st.append(n)
		if wall_jump:
			for n in chimney(gr, p.x, p.y):
				if not seen.has(n):
					seen[n] = true
					st.append(n)
		for o in orbs:
			var node := Vector2i(o.x, o.y + 1)
			if not seen.has(node) and _can_reach_orb(gr, p, o, cap):
				seen[node] = true
				st.append(node)
		for o in touch:
			var tnode := Vector2i(o.x, o.y + 1)
			if not seen.has(tnode) and _can_reach_orb(gr, p, o, cap, 1):
				seen[tnode] = true
				st.append(tnode)
		for t in thorns:
			var tn := Vector2i(t.x, t.y - 1)
			if not seen.has(tn) and _can_reach_pogo(gr, p, t, cap):
				seen[tn] = true
				st.append(tn)
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
	var sp := specials(g, mode == "dash")
	if exits.length() == 1:
		# beco sem saída: precisa dar para entrar E voltar pela mesma saída
		var st := entry_point(g, exits)
		if st.x < 0:
			return "entrada %s sem chão" % exits
		if not exit_reached(g, exits, reachable_from(g, st, cap, gr, sp), cap):
			return "não volta por %s (%s)" % [exits, mode]
		return ""
	for a in exits:
		var start := entry_point(g, a)
		if start.x < 0:
			return "entrada %s sem chão" % a
		var seen := reachable_from(g, start, cap, gr, sp)
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
