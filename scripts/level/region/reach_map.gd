class_name ReachMap
extends RefCounted
## Alcance APROXIMADO (e conservador) numa grade de tiles, rápido o bastante
## para rodar durante a geração de uma região inteira. Usado pelo
## RegionDesigner para garantir que todo lugar importante (portas, santuário,
## baús, alavancas) seja alcançável nos dois sentidos — e, se não for, para
## saber onde pôr saliências (ReachMap.repair).
##
## Modelo: o jogador ocupa 1 x 2 tiles. "Trecho" = sequência horizontal de
## tiles onde dá para ficar em pé (andando de um para o outro). Entre trechos:
##   * pulo: sobe até 3 tiles, até 5 de distância (4 se subir 2-3), com
##     espaço livre para o arco (subida, travessia 2 tiles acima do ponto mais
##     alto, descida);
##   * queda: sai pela ponta do trecho e cai em linha reta (ou desce pulando
##     até 7 tiles para o lado);
##   * atravessar para baixo uma plataforma de mão única.
## O pulo real vai a ~3,9 tiles e ~8 de distância; o modelo fica abaixo disso
## de propósito (o teste com a física de verdade é o RoomReach).

const AIR := 0
const SOLID := 1
const ONE_WAY := 2
const SPIKE := 3

const MAX_RISE := 3
const MAX_DX_FLAT := 5
const MAX_DX_RISE := 4
const MAX_DX_DOWN := 7

## Limites do pulo (instância): com o pulo duplo, sobe e alcança mais
## (mapas de áreas que só se visitam com as Asas de Cinza).
var max_rise: int = MAX_RISE
var max_dx_flat: int = MAX_DX_FLAT
var max_dx_rise: int = MAX_DX_RISE
var w: int = 0
var h: int = 0
var cells := PackedByteArray()
## trechos: [x0, x1, y] (y = linha em que o corpo está; o chão é y + 1)
var segs: Array = []
## id do trecho de cada tile em pé (-1 = nenhum)
var seg_of := PackedInt32Array()
var out_edges: Array = [] ## id -> Array[int]
var in_edges: Array = []


## Pulo duplo: sobe até 6 tiles e cruza vãos de até 8.
func with_double_jump() -> ReachMap:
	max_rise = 6
	max_dx_flat = 8
	max_dx_rise = 6
	return self


func _init(rows: PackedStringArray) -> void:
	h = rows.size()
	w = rows[0].length() if h > 0 else 0
	cells.resize(w * h)
	for y in h:
		var r: String = rows[y]
		for x in w:
			cells[y * w + x] = code(r.unicode_at(x))


static func code(c: int) -> int:
	match c:
		35, 90: # '#', 'Z'
			return SOLID
		45, 79: # '-', 'O' (plataforma que cai conta como mão única)
			return ONE_WAY
		94: # '^'
			return SPIKE
	return AIR # '.', 'B' (quebra), entidades


func at(x: int, y: int) -> int:
	if x < 0 or x >= w or y >= h:
		return SOLID
	if y < 0:
		return AIR
	return cells[y * w + x]


func set_cell(x: int, y: int, c: int) -> void:
	if x >= 0 and x < w and y >= 0 and y < h:
		cells[y * w + x] = c


## Corpo cabe no tile (x, y) e no de cima (sem sólido nem espinho).
func body_free(x: int, y: int) -> bool:
	var a := at(x, y)
	var b := at(x, y - 1)
	return (a == AIR or a == ONE_WAY) and (b == AIR or b == ONE_WAY)


func standable(x: int, y: int) -> bool:
	if not body_free(x, y):
		return false
	var f := at(x, y + 1)
	return f == SOLID or f == ONE_WAY


# ---------------------------------------------------------------------------
# Grafo de trechos
# ---------------------------------------------------------------------------

func build() -> void:
	segs.clear()
	seg_of.resize(w * h)
	seg_of.fill(-1)
	for y in h:
		var x := 0
		while x < w:
			if not standable(x, y):
				x += 1
				continue
			var x0 := x
			while x < w and standable(x, y):
				seg_of[y * w + x] = segs.size()
				x += 1
			segs.append([x0, x - 1, y])
	out_edges.clear()
	in_edges.clear()
	for i in segs.size():
		out_edges.append([])
		in_edges.append([])
	# índice espacial simples: trechos por linha
	var by_row := {}
	for i in segs.size():
		var y: int = segs[i][2]
		if not by_row.has(y):
			by_row[y] = []
		by_row[y].append(i)
	for i in segs.size():
		var s: Array = segs[i]
		var sy: int = s[2]
		for dy in range(-max_rise, 14):
			var ty: int = sy + dy
			if not by_row.has(ty):
				continue
			for j in by_row[ty]:
				if j == i:
					continue
				if _link(s, segs[j]):
					_add(i, j)
		# quedas pelas pontas e através de mão única
		for x in [s[0] - 1, s[1] + 1]:
			var land := _fall_from(x, sy)
			if land >= 0 and land != i:
				_add(i, land)
		if at(s[0], sy + 1) == ONE_WAY:
			for x in [s[0], (s[0] + s[1]) / 2, s[1]]:
				if at(x, sy + 1) == ONE_WAY:
					var land2 := _fall_from(x, sy + 1)
					if land2 >= 0 and land2 != i:
						_add(i, land2)


func _add(a: int, b: int) -> void:
	if not out_edges[a].has(b):
		out_edges[a].append(b)
		in_edges[b].append(a)


## Cai em linha reta a partir de (x, y) (tile onde o corpo está): devolve o
## trecho onde pousa (ou -1: espinho/fora da grade).
func _fall_from(x: int, y: int) -> int:
	if x < 0 or x >= w:
		return -1
	if not body_free(x, y):
		return -1
	var yy := y
	while yy < h - 1:
		var below := at(x, yy + 1)
		if below == SOLID or below == ONE_WAY:
			return seg_of[yy * w + x]
		if below == SPIKE:
			return -1
		yy += 1
	return -1


## Existe um pulo de algum ponto de `a` para algum ponto de `b`?
func _link(a: Array, b: Array) -> bool:
	var ay: int = a[2]
	var by: int = b[2]
	var rise: int = ay - by
	if rise > max_rise:
		return false
	var max_dx: int = max_dx_flat
	if rise >= 2:
		max_dx = max_dx_rise
	elif rise < 0:
		max_dx = mini(MAX_DX_DOWN + (max_dx_flat - MAX_DX_FLAT), max_dx_flat + (-rise) / 2)
	# distância horizontal entre os trechos
	var gap := 0
	if b[0] > a[1]:
		gap = b[0] - a[1]
	elif a[0] > b[1]:
		gap = a[0] - b[1]
	if gap > max_dx:
		return false
	# pares de pontos: pontas mais próximas + sobreposição
	var cands: Array = []
	if gap > 0:
		if b[0] > a[1]:
			cands.append([a[1], b[0]])
			cands.append([a[1], mini(b[0] + 1, b[1])])
			cands.append([maxi(a[1] - 1, a[0]), b[0]])
		else:
			cands.append([a[0], b[1]])
			cands.append([a[0], maxi(b[1] - 1, b[0])])
			cands.append([mini(a[0] + 1, a[1]), b[1]])
	else:
		var lo := maxi(a[0], b[0])
		var hi := mini(a[1], b[1])
		cands.append([lo, lo])
		cands.append([hi, hi])
		cands.append([(lo + hi) / 2, (lo + hi) / 2])
		if lo - 1 >= a[0]:
			cands.append([lo - 1, lo])
		if hi + 1 <= a[1]:
			cands.append([hi + 1, hi])
	for c in cands:
		if _arc_clear(int(c[0]), ay, int(c[1]), by):
			return true
	return false


## Espaço livre para o arco: sobe em x0 até o ápice, atravessa no ápice,
## desce em x1. Ápice = 1 tile acima do ponto mais alto (2 se for plano).
func _arc_clear(x0: int, y0: int, x1: int, y1: int) -> bool:
	var top := mini(y0, y1) - (1 if y0 != y1 else 2)
	if y1 < y0:
		top = y1 - 1
	for y in range(y0, top - 1, -1):
		if not body_free(x0, y):
			return false
	var step := 1 if x1 >= x0 else -1
	var x := x0
	while x != x1:
		x += step
		if not body_free(x, top):
			return false
	for y in range(top, y1 + 1):
		if not body_free(x1, y):
			return false
	return true


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func seg_at(x: int, y: int) -> int:
	if x < 0 or x >= w or y < 0 or y >= h:
		return -1
	var s := seg_of[y * w + x]
	if s >= 0:
		return s
	# tolera 1-2 tiles: procura em volta (chão logo abaixo, etc.)
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 2), Vector2i(1, 1), Vector2i(-1, 1)]:
		var xx: int = x + d.x
		var yy: int = y + d.y
		if xx >= 0 and xx < w and yy >= 0 and yy < h and seg_of[yy * w + xx] >= 0:
			return seg_of[yy * w + xx]
	return -1


func reach_from(start: int, reverse: bool = false) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(segs.size())
	if start < 0:
		return seen
	seen[start] = 1
	var q: Array[int] = [start]
	var head := 0
	var edges: Array = in_edges if reverse else out_edges
	while head < q.size():
		var u: int = q[head]
		head += 1
		for v in edges[u]:
			if seen[v] == 0:
				seen[v] = 1
				q.append(v)
	return seen


## Par (trecho alcançado, trecho que leva ao alvo) mais barato de ligar com
## saliências: custo = distância, subir pesa mais que descer.
func best_bridge(reached: PackedByteArray, target_side: PackedByteArray, banned: Dictionary = {}) -> Array:
	var best: Array = []
	var best_cost := 1e9
	for i in segs.size():
		if reached[i] == 0:
			continue
		var a: Array = segs[i]
		for j in segs.size():
			if target_side[j] == 0 or reached[j] == 1:
				continue
			if not banned.is_empty() and banned.has(pair_key(i, j)):
				continue
			var b: Array = segs[j]
			var dx := 0
			if b[0] > a[1]:
				dx = b[0] - a[1]
			elif a[0] > b[1]:
				dx = a[0] - b[1]
			var rise: int = int(a[2]) - int(b[2])
			var cost := float(dx) + (float(rise) * 1.6 if rise > 0 else float(-rise) * 0.4)
			if cost < best_cost:
				best_cost = cost
				best = [i, j]
	return best


## Chave estável (independe do índice) de um par de trechos.
func pair_key(i: int, j: int) -> String:
	return "%s>%s" % [str(segs[i]), str(segs[j])]
