class_name RoomReach
extends RefCounted
## Validador de alcançabilidade de salas (40x24) SIMULANDO a física do
## jogador (mesmos números de player.gd): pulo variável, meia gravidade no
## ápice, controle aéreo, plataformas one-way, espinhos e, opcionalmente,
## dash em 8 direções. Usado pelos testes para garantir que toda sala gerada
## é atravessável — e útil para conferir templates feitos à mão.
##
## Nós = lugares onde o jogador fica em pé (tile x, linha y do corpo).
## Arestas = andar para o lado + dezenas de pulos/quedas simulados.

const T := 8.0
const DT := 1.0 / 60.0
const HALF_W := 3.0 ## corpo 6x10 (Player.BODY)
const BODY_H := 10.0
const SOLID := "#BZ"
const ONE_WAY := "-O"

var rows: PackedStringArray
var use_dash: bool = false
var w: int = LevelConst.ROOM_W
var h: int = LevelConst.ROOM_H
## Resultado da última busca
var reached: Dictionary = {} ## Vector2i nó -> true
var exits_reached: Dictionary = {} ## "L"/"R"/"U"/"D" -> true
var sims: int = 0
var _edges_cache: Dictionary = {}
var _exit_cache: Dictionary = {} ## nó -> saídas alcançadas direto dele
## Grade pré-calculada (bits): 1 sólido, 2 one-way, 4 espinho
var _flags := PackedByteArray()
var _has_spikes := false


func _init(room_rows: PackedStringArray, dash: bool = false) -> void:
	rows = room_rows
	use_dash = dash
	w = rows[0].length()
	h = rows.size()
	_flags.resize(w * h)
	for y in h:
		var r: String = rows[y]
		for x in w:
			var c := r[x]
			var f := 0
			if SOLID.contains(c):
				f = 1
			elif ONE_WAY.contains(c):
				f = 2
			elif c == "^":
				f = 4
				_has_spikes = true
			_flags[y * w + x] = f


# ---------------------------------------------------------------------------
# Grade
# ---------------------------------------------------------------------------

func cell(x: int, y: int) -> String:
	if x < 0 or x >= w:
		return "." if y >= 0 and y < h else "#"
	if y < 0 or y >= h:
		return "."
	return rows[y][x]


func is_solid(x: int, y: int) -> bool:
	if y < 0 or y >= h:
		return false
	if x < 0 or x >= w:
		# fora da sala nas laterais: aberto só na faixa das saídas L/R
		return _flags[y * w + clampi(x, 0, w - 1)] & 1 != 0 or rows[y][clampi(x, 0, w - 1)] == "#"
	return _flags[y * w + x] & 1 != 0


func is_one_way(x: int, y: int) -> bool:
	return x >= 0 and x < w and y >= 0 and y < h and _flags[y * w + x] & 2 != 0


func is_spike(x: int, y: int) -> bool:
	return x >= 0 and x < w and y >= 0 and y < h and _flags[y * w + x] & 4 != 0


## Dá para ficar em pé no tile (x, y)? (pés no topo da linha y+1)
func standable(x: int, y: int) -> bool:
	if x < 0 or x >= w or y < 0 or y >= h - 1:
		return false
	if is_solid(x, y) or is_solid(x, y - 1) or is_spike(x, y):
		return false
	return is_solid(x, y + 1) or is_one_way(x, y + 1)


# ---------------------------------------------------------------------------
# Busca
# ---------------------------------------------------------------------------

## Nós iniciais para quem entra pela saída `e`.
func entry_nodes(e: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match e:
		"L":
			out.append(Vector2i(1, LevelConst.FLOOR_ROW - 1))
		"R":
			out.append(Vector2i(w - 2, LevelConst.FLOOR_ROW - 1))
		"D":
			for x in LevelConst.EXIT_UD_COLS:
				if standable(x, h - 2):
					out.append(Vector2i(x, h - 2))
		"U":
			for dir in [-1, 0, 1]:
				var r := _simulate(Vector2(20 * T, 2.0), Vector2(0, 40), {"dir": dir, "jump": 0, "release": 12})
				if r.has("node"):
					out.append(r["node"])
	var valid: Array[Vector2i] = []
	for n in out:
		if standable(n.x, n.y) and not valid.has(n):
			valid.append(n)
	return valid


## BFS a partir da saída `from`. Preenche `reached` e `exits_reached`.
## Com `stop_when`, para assim que todas essas saídas forem alcançadas.
func search(from: String, stop_when: String = "") -> Dictionary:
	reached.clear()
	exits_reached.clear()
	var queue: Array[Vector2i] = entry_nodes(from)
	for n in queue:
		reached[n] = true
	var i := 0
	while i < queue.size():
		var n: Vector2i = queue[i]
		i += 1
		_check_exit_node(n)
		for m in _edges(n):
			if not reached.has(m):
				reached[m] = true
				queue.append(m)
		for e in _exit_cache.get(n, []):
			exits_reached[e] = true
		if stop_when != "" and _all_reached(stop_when, from):
			break
	return exits_reached


func _all_reached(exits: String, except: String) -> bool:
	for e in exits:
		if e != except and not exits_reached.has(e):
			return false
	return true


## Todas as saídas de `exits` alcançáveis a partir de cada uma das outras?
## Devolve a lista de pares que falharam ("L>R").
func check_all(exits: String) -> PackedStringArray:
	var fails := PackedStringArray()
	for a in exits:
		var got := search(a, exits)
		for b in exits:
			if a != b and not got.has(b):
				fails.append("%s>%s" % [a, b])
	return fails


## Algum dos tiles `targets` (lugares em pé) é alcançável a partir de `from`?
func can_reach_tile(from: String, target: Vector2i, radius: int = 1) -> bool:
	search(from)
	for n in reached.keys():
		if absi(n.x - target.x) <= radius and absi(n.y - target.y) <= radius:
			return true
	return false


func _check_exit_node(n: Vector2i) -> void:
	if n.x <= 1 and n.y in LevelConst.EXIT_LR_ROWS:
		exits_reached["L"] = true
	if n.x >= w - 2 and n.y in LevelConst.EXIT_LR_ROWS:
		exits_reached["R"] = true
	if n.y >= h - 2 and n.x in LevelConst.EXIT_UD_COLS:
		exits_reached["D"] = true


func _edges(n: Vector2i) -> Array[Vector2i]:
	if _edges_cache.has(n):
		return _edges_cache[n]
	var out: Array[Vector2i] = []
	var exits: Array = []
	var run_end := false
	for dx in [-1, 1]:
		if standable(n.x + dx, n.y):
			out.append(Vector2i(n.x + dx, n.y))
		else:
			run_end = true
	# no meio de um chão contínuo, pular de 1 em 1 tile é redundante: simula
	# nas pontas e em tiles alternados (mais rápido, mesmo resultado prático)
	if run_end or n.x % 2 == 0 or _something_above(n):
		var start := Vector2(n.x * T + T * 0.5, (n.y + 1) * T)
		for plan in _plans(is_one_way(n.x, n.y + 1)):
			var r := _simulate(start, Vector2.ZERO, plan)
			if r.has("exit") and not exits.has(r["exit"]):
				exits.append(r["exit"])
			if r.has("node") and r["node"] != n and not out.has(r["node"]):
				out.append(r["node"])
	_edges_cache[n] = out
	_exit_cache[n] = exits
	return out


## Há plataforma/bloco logo acima (onde um pulo pode pousar)?
func _something_above(n: Vector2i) -> bool:
	for y in range(n.y - 5, n.y - 1):
		for x in range(n.x - 1, n.x + 2):
			if y >= 0 and (is_solid(x, y) or is_one_way(x, y)):
				return true
	return false


## Planos de entrada simulados a partir de cada lugar em pé.
func _plans(on_one_way: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for dir in [-1, 1]:
		out.append({"dir": dir, "jump": 0, "release": 999}) # sair andando da borda
		out.append({"dir": dir, "jump": 0, "release": 5})
		out.append({"dir": dir, "jump": 4, "release": 999}) # pulinho
		for rel in [999, 10, 22]:
			out.append({"dir": dir, "jump": 45, "release": rel}) # pulo cheio
		for late in [8, 16]:
			out.append({"dir": dir, "jump": 45, "release": 999, "late": late}) # sobe e depois desvia
	out.append({"dir": 0, "jump": 45, "release": 999})
	if on_one_way:
		for dir in [-1, 0, 1]:
			out.append({"dir": dir, "jump": 0, "release": 999, "drop": true}) # baixo + pulo
	if use_dash:
		for dir in [-1, 1]:
			for dd in [Vector2(dir, 0), Vector2(dir, -1), Vector2(0, -1), Vector2(dir, 1)]:
				for at in [4, 14, 24]:
					out.append({"dir": dir, "jump": 30, "release": 999, "dash": dd, "dash_at": at})
			out.append({"dir": dir, "jump": 0, "release": 999, "dash": Vector2(dir, 0), "dash_at": 1})
	return out


# ---------------------------------------------------------------------------
# Física (espelha player.gd)
# ---------------------------------------------------------------------------

func _simulate(pos: Vector2, vel: Vector2, plan: Dictionary) -> Dictionary:
	sims += 1
	var p := pos
	var v := vel
	var dir: float = plan["dir"]
	var hold: int = plan["jump"]
	var release: int = plan["release"]
	var late: int = plan.get("late", 0)
	var dash_at: int = plan.get("dash_at", -1)
	var dash_dir: Vector2 = plan.get("dash", Vector2.ZERO).normalized()
	var var_t := 0.0
	var dash_t := 0.0
	var on_ground := vel == Vector2.ZERO
	var was_air := not on_ground
	var drop_t := 0.0
	var boosted := false
	if plan.get("drop", false) and on_ground:
		# baixo + pulo numa one-way: atravessa para baixo
		drop_t = 0.25
		p.y += 2.0
		on_ground = false
	elif hold > 0 and on_ground:
		v.y = -Player.JUMP_SPEED
		var_t = Player.VAR_JUMP_TIME
		v.x += Player.JUMP_H_BOOST * (dir if late == 0 else 0.0)
		on_ground = false
	for f in 150:
		drop_t -= DT
		var input_x := dir
		if f >= release or (late > 0 and f < late):
			input_x = 0.0
		var holding := f < hold
		if dash_at == f and dash_dir != Vector2.ZERO:
			dash_t = Player.DASH_TIME
			var_t = 0.0
		if dash_t > 0.0:
			dash_t -= DT
			v = dash_dir * Player.DASH_SPEED
			if dash_t <= 0.0:
				v = dash_dir * Player.DASH_END_SPEED
				if dash_dir.y < 0.0:
					v.y *= 0.75
		else:
			# corrida / controle aéreo
			var mult := 1.0 if on_ground else Player.AIR_MULT
			var max_run := Player.MAX_RUN
			if absf(v.x) > max_run and signf(v.x) == input_x:
				v.x = move_toward(v.x, max_run * input_x, Player.RUN_REDUCE * mult * DT)
			elif input_x != 0.0:
				v.x = move_toward(v.x, max_run * input_x, Player.RUN_ACCEL * mult * DT)
			else:
				v.x = move_toward(v.x, 0.0, Player.RUN_DECEL * mult * DT)
			# gravidade + pulo variável
			var g := Player.GRAVITY
			if absf(v.y) < Player.HALF_GRAV_THRESHOLD and holding:
				g *= 0.5
			v.y = move_toward(v.y, Player.MAX_FALL, g * DT)
			if var_t > 0.0:
				var_t -= DT
				if holding:
					v.y = minf(v.y, -Player.JUMP_SPEED)
				else:
					var_t = 0.0
		# move X
		var nx := p.x + v.x * DT
		if _box_hits(nx, p.y):
			nx = _snap_x(p.x, nx, p.y)
			v.x = 0.0
		p.x = nx
		# move Y
		var ny := p.y + v.y * DT
		on_ground = false
		if v.y > 0.0:
			var land := _landing(p.x, p.y, ny, drop_t > 0.0)
			if land < INF:
				ny = land
				v.y = 0.0
				on_ground = true
		elif v.y < 0.0 and _box_hits(p.x, ny):
			ny = floorf((ny - BODY_H) / T + 1.0) * T + BODY_H
			v.y = 0.0
			var_t = 0.0
		# impulso de transição (Level/Player): o centro do corpo cruzou o topo
		# da sala subindo -> ganha de novo o pulo inteiro
		if not boosted and v.y < 0.0 and p.y - Player.TRANSITION_PROBE >= 0.0 and ny - Player.TRANSITION_PROBE < 0.0:
			boosted = true
			v.y = minf(v.y, -Player.JUMP_SPEED)
			var_t = Player.VAR_JUMP_TIME
		p.y = ny
		# saídas (U: passou do topo da one-way no fundo da sala de cima)
		if p.y < -T - 1.0 and p.x > LevelConst.EXIT_UD_COLS[0] * T and p.x < (LevelConst.EXIT_UD_COLS[-1] + 1) * T:
			return {"exit": "U"}
		if p.x < -1.0:
			return {"exit": "L"} if int(p.y / T) - 1 in LevelConst.EXIT_LR_ROWS or int(p.y / T) in LevelConst.EXIT_LR_ROWS else {}
		if p.x > w * T + 1.0:
			return {"exit": "R"} if int(p.y / T) - 1 in LevelConst.EXIT_LR_ROWS or int(p.y / T) in LevelConst.EXIT_LR_ROWS else {}
		if p.y > h * T + BODY_H:
			return {"exit": "D"}
		# espinhos matam
		if _touches_spike(p.x, p.y):
			return {}
		if on_ground and dash_t <= 0.0:
			if was_air:
				return _land_node(p)
			if f > 40:
				return {} # nunca saiu do chão (andar é aresta à parte)
		elif not on_ground:
			was_air = true
	return {}


## Nó onde o jogador pousou (se o centro ficou sobre o vazio, o tile vizinho
## que o sustenta).
func _land_node(p: Vector2) -> Dictionary:
	var tx := int(floorf(p.x / T))
	var ty := int(roundf(p.y / T)) - 1
	if standable(tx, ty):
		return {"node": Vector2i(tx, ty)}
	var frac := p.x / T - tx
	for dx in ([-1, 1] if frac < 0.5 else [1, -1]):
		if standable(tx + dx, ty):
			return {"node": Vector2i(tx + dx, ty)}
	return {}


func _box_hits(x: float, feet: float) -> bool:
	var x0 := int(floorf((x - HALF_W + 0.01) / T))
	var x1 := int(floorf((x + HALF_W - 0.01) / T))
	var y0 := int(floorf((feet - BODY_H + 0.01) / T))
	var y1 := int(floorf((feet - 0.01) / T))
	for yy in range(y0, y1 + 1):
		for xx in range(x0, x1 + 1):
			if is_solid(xx, yy):
				return true
	return false


func _snap_x(old_x: float, new_x: float, feet: float) -> float:
	# encosta na parede (passo de 1 px)
	var step := signf(new_x - old_x)
	var x := old_x
	for i in 16:
		if _box_hits(x + step, feet):
			break
		x += step
		if (step > 0 and x >= new_x) or (step < 0 and x <= new_x):
			break
	return x


## Pés descendo de `from_y` até `to_y`: y do chão/one-way onde pousa, ou INF.
func _landing(x: float, from_y: float, to_y: float, dropping: bool = false) -> float:
	var x0 := int(floorf((x - HALF_W + 0.01) / T))
	var x1 := int(floorf((x + HALF_W - 0.01) / T))
	var r0 := int(floorf(from_y / T))
	var r1 := int(floorf((to_y - 0.001) / T))
	for r in range(r0, r1 + 1):
		var top := r * T
		if top < from_y - 0.001 or top > to_y:
			continue
		for xx in range(x0, x1 + 1):
			if is_solid(xx, r) or (is_one_way(xx, r) and not dropping):
				return top
	if _box_hits(x, to_y):
		return floorf(to_y / T) * T
	return INF


func _touches_spike(x: float, feet: float) -> bool:
	if not _has_spikes:
		return false
	var x0 := int(floorf((x - HALF_W + 1.0) / T))
	var x1 := int(floorf((x + HALF_W - 1.0) / T))
	var y0 := int(floorf((feet - BODY_H + 2.0) / T))
	var y1 := int(floorf((feet + 0.5) / T))
	for yy in range(y0, y1 + 1):
		for xx in range(x0, x1 + 1):
			if is_spike(xx, yy):
				return true
	return false
