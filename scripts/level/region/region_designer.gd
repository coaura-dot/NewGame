class_name RegionDesigner
extends RefCounted
## Regiões no estilo HOLLOW KNIGHT: cada região é um conjunto de LUGARES com
## nome, forma e propósito — não uma fila de salas iguais com plataformas.
##
##  * Um SANTUÁRIO (ou a VILA, nas regiões com hub) no centro: descanso,
##    viagem rápida, NPCs.
##  * O OBJETIVO no ponto mais distante: o COVIL do guardião (chefe) ou o
##    CORAÇÃO da região (um salão com a relíquia e o marco visual).
##  * PASSAGENS nas bordas levando às regiões vizinhas (estrada, túnel, poço,
##    árvore/torre que sobe até o céu), com placa dizendo para onde vão.
##  * O CAMINHO entre eles vira lugares de travessia com formas próprias:
##    trilhas com morros e buracos, galerias, poços verticais, salões com
##    saliências, abismos com plataformas, lagos com reflexo, ninhos.
##  * RAMOS opcionais: cofres atrás de paredes rachadas ou de portões de
##    habilidade (voltar depois = backtracking), mirantes no alto, provas
##    de agilidade, a fenda dimensional.
##  * ATALHOS: portões de mão única que só abrem por uma alavanca do outro
##    lado (fecham o ciclo de volta ao santuário).
##  * ECOSSISTEMA: cada lugar recebe as criaturas que fazem sentido nele
##    (patrulhas nos caminhos, voadores nos espaços abertos, atiradores nas
##    saliências altas, a espécie do ninho no ninho) e nenhuma no santuário.
##
## Geometria: a região é uma grade MACRO de células de CW x CH tiles; cada
## lugar ocupa um retângulo de células e é esculpido com forma orgânica
## (cavernas, bosques) ou arquitetônica (castelos, templos, catacumbas). Na
## superfície o chão é uma linha de relevo contínua sob o céu aberto, com
## cavernas embaixo e estruturas altas em cima. Tudo passa pelo ReachMap:
## se algum lugar importante não for alcançável nos dois sentidos, o
## gerador põe saliências até que seja.
##
## Saída: o mesmo formato do LevelGenerator (rows, rooms, entities, ports...)
## + "bg" (parede de fundo por tile), "water", "macro" (dono de cada célula),
## "objective" e nomes dos lugares.

const CW := 24
const CH := 16
const SOLID := 35 # '#'
const AIR := 46 # '.'
const ONE_WAY := 45 # '-'
const SPIKE := 94 # '^'
const BREAK := 66 # 'B'

## Tipo "legado" (para Level/HUD/mapa) de cada tipo de lugar.
const LEGACY := {
	"santuario": "shrine", "vila": "hub", "covil": "boss", "coracao": "treasure", "passagem": "passage",
	"trilha": "corridor", "galeria": "corridor", "gruta": "corridor", "poco": "shaft", "salao": "platforming",
	"abismo": "platforming", "lago": "corridor", "ninho": "arena", "cofre": "treasure", "mirante": "secret",
	"desafio": "challenge", "fenda": "treasure", "torre": "shaft",
}
const KIND_NOUNS := {
	"santuario": ["Santuário", "Refúgio", "Altar"], "vila": ["Vila", "Aldeia", "Povoado"],
	"covil": ["Covil", "Arena", "Trono"], "coracao": ["Coração", "Âmago", "Salão Antigo"],
	"passagem": ["Portão", "Estrada", "Passagem"], "trilha": ["Trilha", "Caminho", "Vereda"],
	"galeria": ["Galeria", "Túnel", "Corredor"], "gruta": ["Gruta", "Recanto", "Câmara"],
	"poco": ["Poço", "Garganta", "Fenda"], "salao": ["Salão", "Caverna", "Nave"],
	"abismo": ["Abismo", "Ravina", "Precipício"], "lago": ["Lago", "Espelho", "Poça"],
	"ninho": ["Ninho", "Toca", "Colmeia"], "cofre": ["Cofre", "Esconderijo", "Relicário"],
	"mirante": ["Mirante", "Pico", "Atalaia"], "desafio": ["Prova", "Desafio", "Travessia"],
	"fenda": ["Fenda", "Rasgo", "Portal"], "torre": ["Escalada", "Subida", "Torre"],
}
## Complementos por bioma (neutros em gênero: combinam com qualquer nome).
const BIOME_MODS := {
	"floresta": ["das Raízes", "dos Musgos", "dos Vaga-lumes", "Sussurrante", "das Folhas Velhas", "do Cervo Branco"],
	"pantano": ["do Lodo", "dos Juncos", "das Lamparinas", "Pútrido", "das Rãs", "da Névoa"],
	"ruinas": ["dos Arcos", "de Aldramar", "das Estátuas", "Esquecido", "dos Reis Antigos", "da Hera"],
	"cemiterio": ["dos Túmulos", "das Lápides", "dos Sem-Nome", "das Velas", "dos Corvos", "do Coveiro"],
	"cidade_gotica": ["dos Sinos", "das Gárgulas", "de Vésper", "dos Vitrais", "do Relojoeiro", "das Lanternas"],
	"castelo": ["do Rei", "das Armaduras", "das Correntes", "dos Estandartes", "da Guarda", "do Trono"],
	"templo_dourado": ["do Sol", "de Âmbar", "dos Hinos", "Dourado", "das Oferendas", "do Oráculo"],
	"deserto": ["das Dunas", "do Escorpião", "Escaldante", "dos Ossos Brancos", "da Miragem", "do Vento Quente"],
	"fortaleza_orc": ["de Grumm", "dos Chifres", "das Estacas", "dos Tambores", "de Ferro", "do Machado"],
	"acampamento_barbaro": ["dos Lobos", "das Fogueiras", "dos Totens", "do Clã", "das Peles", "do Uivo"],
	"cidade_magos": ["dos Magos", "das Runas", "dos Pergaminhos", "Arcano", "das Estrelas", "do Astrolábio"],
	"cidade_ceu": ["das Nuvens", "do Vento", "de Aeris", "Celeste", "das Asas", "do Horizonte"],
	"catacumbas": ["dos Ossos", "dos Mortos", "das Velas", "do Ossário", "das Criptas", "do Silêncio"],
	"cidade_subterranea": ["das Cisternas", "dos Canos", "da Cidade Afundada", "das Ratazanas", "do Eco", "das Comportas"],
	"toca_goblin": ["dos Goblins", "da Fuligem", "das Raízes Negras", "dos Túneis", "do Formigueiro", "das Minas"],
}

var params: Dictionary
var db: Node
var rng: RandomNumberGenerator
var biome_id: String = ""
var biome: Dictionary = {}
var mode: String = "surface" ## surface | enclosed | sky
var built: bool = false ## arquitetura (castelo, templo...) em vez de rocha orgânica
var gw: int = 10
var gh: int = 4
var gr: int = 1 ## linha macro da superfície
var w: int = 0
var h: int = 0
var ground_base: int = 0 ## linha (tile) média do chão na superfície
var g := PackedByteArray()
var bgm := PackedByteArray() ## 0 = céu/nada, 1 = parede de fundo, 2 = janela
var cell_owner := PackedInt32Array()
var places: Array = []
var conns: Array = []
var entities: Array = []
var surf := PackedInt32Array() ## linha do chão por coluna (superfície/céu)
var water: Array = [] ## [x0, x1, y_top, y_bottom] em tiles
var pool: Dictionary = {}
var gate_candidates: Array = []
var shrine_idx: int = -1
var objective_idx: int = -1
var anchors_extra: Array = [] ## tiles que precisam ser alcançáveis
var _used_names := {}
var _kind_count := {}
var _paths: Array = []


static func generate(p: Dictionary, database: Node) -> Dictionary:
	var d := RegionDesigner.new()
	return d.run(p, database)


func run(p: Dictionary, database: Node) -> Dictionary:
	params = p
	db = database
	var seed_value: int = int(params.get("seed", 1))
	for attempt in 12:
		rng = RngUtil.make(seed_value + attempt * 7919, "region")
		_reset()
		if _plan():
			break
	_place_doors()
	_carve()
	_carve_doors()
	_populate()
	_ensure_reach()
	_finish_entities()
	return _output(seed_value)


# ===========================================================================
# Preparação
# ===========================================================================

func _reset() -> void:
	biome_id = params.get("biome", "floresta")
	biome = db.biome(biome_id)
	var tags: Array = biome.get("tags", [])
	var layer: String = str(params.get("layer", ""))
	if layer == "":
		layer = "underground" if tags.has("underground") else ("sky" if tags.has("sky") else "surface")
	if layer == "underground" or (layer == "surface" and tags.has("indoor")):
		mode = "enclosed"
	elif layer == "sky":
		mode = "sky"
	else:
		mode = "surface"
	var ts: String = biome.get("tileset", "castle")
	built = ts in ["castle", "temple", "catacomb", "town", "arcane", "sky"]
	gw = 9 + rng.randi_range(0, 2)
	if str(params.get("hub", "")) != "":
		gw += 1
	if str(params.get("boss", "")) != "":
		gw += 1
	gh = 3 if mode == "sky" else 4
	gr = 1
	w = gw * CW
	h = gh * CH
	ground_base = gr * CH + 10
	g.resize(w * h)
	g.fill(SOLID)
	bgm.resize(w * h)
	bgm.fill(0)
	cell_owner.resize(gw * gh)
	cell_owner.fill(-1)
	surf.resize(w)
	surf.fill(-1)
	places.clear()
	conns.clear()
	entities.clear()
	water.clear()
	anchors_extra.clear()
	_used_names.clear()
	_kind_count.clear()
	_paths.clear()
	shrine_idx = -1
	objective_idx = -1
	pool = LevelGenerator._enemy_pool(params, db, biome)
	gate_candidates.clear()
	for ab_id in db.abilities.keys():
		var ab: Dictionary = db.abilities[ab_id]
		if ab.get("implemented", false) and not ab.get("start", false) and ab_id != "dimension_shift":
			gate_candidates.append(ab_id)
	gate_candidates.sort()


# ===========================================================================
# Grade de tiles
# ===========================================================================

func gget(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return SOLID
	return g[y * w + x]


func gset(x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		g[y * w + x] = c


func is_air(x: int, y: int) -> bool:
	return gget(x, y) != SOLID


func fill(x0: int, y0: int, x1: int, y1: int, c: int) -> void:
	for y in range(maxi(y0, 0), mini(y1, h - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, w - 1) + 1):
			g[y * w + x] = c


func set_bg(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		bgm[y * w + x] = v


## Ruído de valor 1D suave e determinístico (0..1).
func noise1(seed_v: int, x: float, scale: float) -> float:
	var xs := x / scale
	var i := floori(xs)
	var f := xs - i
	f = f * f * (3.0 - 2.0 * f)
	var a := _hash01(seed_v, i)
	var b := _hash01(seed_v, i + 1)
	return lerpf(a, b, f)


func _hash01(s: int, i: int) -> float:
	var v := (i * 374761393 + s * 668265263) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float(v % 10000) / 10000.0


# ===========================================================================
# Plano macro: lugares e ligações
# ===========================================================================

func own(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= gw or c.y >= gh:
		return -2
	return cell_owner[c.y * gw + c.x]


func _add_place(kind: String, r: Rect2i, extra: Dictionary = {}) -> int:
	var idx := places.size()
	var p := {
		"index": idx, "kind": kind, "type": LEGACY.get(kind, "corridor"),
		"cell": [r.position.x, r.position.y], "cells": [r.size.x, r.size.y],
		"rect": [r.position.x * CW, r.position.y * CH, r.size.x * CW, r.size.y * CH],
		"origin": [r.position.x * CW, r.position.y * CH],
		"exits": "", "on_path": true, "tags": PackedStringArray(), "doors": [], "name": "",
	}
	p.merge(extra, true)
	places.append(p)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			cell_owner[y * gw + x] = idx
	_kind_count[kind] = int(_kind_count.get(kind, 0)) + 1
	return idx


func prect(i: int) -> Rect2i:
	var r: Array = places[i]["rect"]
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


func pcell(i: int) -> Rect2i:
	var c: Array = places[i]["cell"]
	var s: Array = places[i]["cells"]
	return Rect2i(int(c[0]), int(c[1]), int(s[0]), int(s[1]))


func _plan() -> bool:
	var ports: Array = params.get("ports", [])
	var reserved := {}
	var anchor_of := {}
	for pt in ports:
		var d: String = pt["dir"]
		var c := Vector2i.ZERO
		match d:
			"L":
				c = Vector2i(0, gr if mode != "enclosed" else rng.randi_range(1, gh - 2))
			"R":
				c = Vector2i(gw - 1, gr if mode != "enclosed" else rng.randi_range(1, gh - 2))
			"U":
				c = Vector2i(rng.randi_range(2, gw - 3), 0)
			"D":
				c = Vector2i(rng.randi_range(2, gw - 3), gh - 1)
		anchor_of[d] = c
		reserved[c] = true
	# 1) santuário (ou vila) no meio
	var hub: String = str(params.get("hub", ""))
	var sy := gr if mode != "enclosed" else rng.randi_range(1, gh - 2)
	var sx := clampi(gw / 2 + rng.randi_range(-1, 1), 2, gw - 3)
	if hub != "":
		sx = clampi(sx, 2, gw - 4)
		var vr := Rect2i(sx - 1, sy, 3, 1)
		if _rect_free(vr, reserved):
			shrine_idx = _add_place("vila", vr)
	if shrine_idx < 0:
		if not _rect_free(Rect2i(sx, sy, 1, 1), reserved):
			return false
		shrine_idx = _add_place("santuario", Rect2i(sx, sy, 1, 1))
	var shrine_cell := Vector2i(sx, sy)
	# 2) objetivo no ponto mais distante
	var boss: String = str(params.get("boss", ""))
	if boss != "":
		var spot := _find_spot(Vector2i(2, 1), shrine_cell, reserved, true)
		if spot.size.x == 0:
			return false
		objective_idx = _add_place("covil", spot)
	else:
		var spot2 := _find_spot(Vector2i(2, 2), shrine_cell, reserved, false)
		if spot2.size.x == 0:
			spot2 = _find_spot(Vector2i(2, 1), shrine_cell, reserved, false)
		if spot2.size.x == 0:
			return false
		objective_idx = _add_place("coracao", spot2)
	# 3) passagens das bordas
	var port_place := {}
	for pt in ports:
		var c: Vector2i = anchor_of[pt["dir"]]
		if own(c) != -1:
			return false
		var kind := "torre" if pt["dir"] == "U" and mode != "enclosed" else "passagem"
		var pi := _add_place(kind, Rect2i(c, Vector2i.ONE), {"port": pt.duplicate()})
		port_place[pt["dir"]] = pi
	# 4) caminhos do santuário até cada objetivo/passagem
	var targets: Array = [objective_idx]
	for d in port_place.keys():
		targets.append(port_place[d])
	for t in targets:
		var path := _route(shrine_idx, int(t))
		if path.is_empty():
			return false
		_paths.append(path)
	_make_route_places()
	if mode != "enclosed":
		_fill_ground_row()
	_expand_halls()
	for path in _paths:
		for k in range(1, path.size()):
			var a := own(path[k - 1])
			var b := own(path[k])
			if a != b and a >= 0 and b >= 0:
				_connect(a, b, path[k - 1], path[k], "open")
	if mode != "enclosed":
		_connect_ground_row()
	_add_branches()
	_add_shortcuts()
	for p in places:
		p["name"] = _name_for(p)
	return true


func _rect_free(r: Rect2i, reserved: Dictionary) -> bool:
	if r.position.x < 0 or r.position.y < 0 or r.end.x > gw or r.end.y > gh:
		return false
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if own(c) != -1 or reserved.has(c):
				return false
	return true


## Lugar livre mais distante do santuário (com um pouco de sorte).
func _find_spot(size: Vector2i, from: Vector2i, reserved: Dictionary, lair: bool) -> Rect2i:
	var best := Rect2i()
	var best_score := -1e9
	for y in range(0, gh - size.y + 1):
		if mode != "enclosed" and y < gr:
			continue
		if mode == "sky" and y > gr and lair:
			continue
		for x in range(1, gw - size.x):
			var r := Rect2i(x, y, size.x, size.y)
			if not _rect_free(r, reserved):
				continue
			# não encosta nas âncoras das bordas (deixa passagem)
			var touches := false
			for c in reserved.keys():
				if Rect2i(r.position - Vector2i.ONE, r.size + Vector2i(2, 2)).has_point(c) and (c.y == r.position.y or c.x == r.position.x - 1 or c.x == r.end.x):
					touches = true
			if touches:
				continue
			var center := Vector2(r.position) + Vector2(r.size) * 0.5
			var score := absf(center.x - from.x) + absf(center.y - from.y) * 1.4 + rng.randf() * 2.5
			if mode == "surface" and y > gr:
				score += 1.5 # o coração/covil fica nas profundezas
			if score > best_score:
				best_score = score
				best = r
	return best


## Caminho de células (Dijkstra com custos aleatórios) entre dois lugares.
func _route(from_idx: int, to_idx: int) -> Array:
	var start_cells: Array = _cells_of(from_idx)
	var goal := {}
	for c in _cells_of(to_idx):
		goal[c] = true
	var noise := {}
	for y in gh:
		for x in gw:
			noise[Vector2i(x, y)] = rng.randf() * 0.7
	var used := {}
	for p in _paths:
		for c in p:
			used[c] = true
	var dist := {}
	var prev := {}
	var open: Array = []
	for c in start_cells:
		dist[c] = 0.0
		open.append(c)
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if dist[open[i]] < dist[open[bi]]:
				bi = i
		var u: Vector2i = open[bi]
		open.remove_at(bi)
		if goal.has(u):
			var path: Array = [u]
			while prev.has(path[0]):
				path.push_front(prev[path[0]])
			return path
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = u + d
			if v.x < 0 or v.y < 0 or v.x >= gw or v.y >= gh:
				continue
			var o := own(v)
			if o != -1 and not goal.has(v):
				continue
			# santuário, vila e covil só ganham portas laterais
			if d.y != 0 and (own(u) == from_idx or (goal.has(v) and places[to_idx]["kind"] in ["covil", "vila", "santuario"])):
				if places[from_idx]["kind"] in ["santuario", "vila"] or goal.has(v):
					continue
			var cost := 1.0 if d.y == 0 else 1.8
			cost += noise[v]
			if used.has(v):
				cost = 0.3
			if mode != "enclosed" and v.y < gr and not goal.has(v):
				cost += 6.0 # o céu só para quem vai subir
			if mode == "sky" and v.y > gr:
				cost += 1.5
			var nd: float = dist[u] + cost
			if not dist.has(v) or nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				if not open.has(v):
					open.append(v)
	return []


func _cells_of(i: int) -> Array:
	var out: Array = []
	var r := pcell(i)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


## Divide as células dos caminhos em lugares: trechos horizontais viram
## trilhas/galerias/abismos..., verticais viram poços.
func _make_route_places() -> void:
	for path in _paths:
		var i := 0
		while i < path.size():
			var c: Vector2i = path[i]
			if own(c) != -1:
				i += 1
				continue
			var run: Array = [c]
			var orient := ""
			var j := i + 1
			while j < path.size():
				var n: Vector2i = path[j]
				if own(n) != -1:
					break
				var d: Vector2i = n - path[j - 1]
				var o := "h" if d.y == 0 else "v"
				if orient == "":
					orient = o
				elif o != orient:
					break
				if run.size() >= 3:
					break
				run.append(n)
				j += 1
			var mn: Vector2i = run[0]
			var mx: Vector2i = run[0]
			for q in run:
				mn = Vector2i(mini(mn.x, q.x), mini(mn.y, q.y))
				mx = Vector2i(maxi(mx.x, q.x), maxi(mx.y, q.y))
			var r := Rect2i(mn, mx - mn + Vector2i.ONE)
			_add_place(_route_kind(r, orient), r)
			i = j


func _route_kind(r: Rect2i, orient: String) -> String:
	var ground: bool = mode != "enclosed" and r.position.y == gr
	if orient == "v" and r.size.y >= 2:
		return "poco"
	if ground:
		var opts := {"trilha": 4.0}
		if r.size.x >= 2 and int(_kind_count.get("abismo", 0)) < 2:
			opts["abismo"] = 2.0 if mode == "sky" else 1.4
		if r.size.x >= 2 and biome.get("water", false) and int(_kind_count.get("lago", 0)) < 1 and mode == "surface":
			opts["lago"] = 1.6
		return RngUtil.weighted_key(rng, opts)
	if r.size.x == 1:
		return "gruta"
	var opts2 := {"galeria": 3.0, "salao": 1.6}
	if int(_kind_count.get("ninho", 0)) < 1:
		opts2["ninho"] = 1.3
	if int(_kind_count.get("abismo", 0)) < 1 and r.size.x >= 2:
		opts2["abismo"] = 1.0
	return RngUtil.weighted_key(rng, opts2)


## Superfície/céu: a faixa do chão é contínua (sem células vazias).
func _fill_ground_row() -> void:
	var x := 0
	while x < gw:
		if own(Vector2i(x, gr)) != -1:
			x += 1
			continue
		var x0 := x
		while x < gw and own(Vector2i(x, gr)) == -1 and x - x0 < 3:
			x += 1
		var r := Rect2i(x0, gr, x - x0, 1)
		var kind := "trilha"
		if r.size.x >= 2 and rng.randf() < 0.3 and int(_kind_count.get("abismo", 0)) < 2:
			kind = "abismo"
		_add_place(kind, r, {"on_path": false})


## Salões pedem duas linhas de altura: cresce para baixo ou para cima.
func _expand_halls() -> void:
	for p in places:
		if p["kind"] != "salao" or int(p["cells"][1]) >= 2:
			continue
		var r := pcell(int(p["index"]))
		var grown := false
		for dy in [1, -1]:
			var band := Rect2i(r.position.x, r.position.y + (r.size.y if dy > 0 else -1), r.size.x, 1)
			if band.position.y < (gr + 1 if mode != "enclosed" else 0) or band.end.y > gh:
				continue
			if not _rect_free(band, {}):
				continue
			var nr := r.merge(band)
			_reshape(int(p["index"]), nr)
			grown = true
			break
		if not grown:
			p["kind"] = "galeria"
			p["type"] = LEGACY["galeria"]


func _reshape(i: int, r: Rect2i) -> void:
	var p: Dictionary = places[i]
	p["cell"] = [r.position.x, r.position.y]
	p["cells"] = [r.size.x, r.size.y]
	p["rect"] = [r.position.x * CW, r.position.y * CH, r.size.x * CW, r.size.y * CH]
	p["origin"] = [r.position.x * CW, r.position.y * CH]
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			cell_owner[y * gw + x] = i


func _connected(a: int, b: int) -> bool:
	for c in conns:
		if (c["a"] == a and c["b"] == b) or (c["a"] == b and c["b"] == a):
			return true
	return false


func _connect(a: int, b: int, ca: Vector2i, cb: Vector2i, kind: String, data: Dictionary = {}) -> Dictionary:
	if _connected(a, b):
		return {}
	var d := cb - ca
	var dir := "R" if d.x > 0 else ("L" if d.x < 0 else ("D" if d.y > 0 else "U"))
	var c := {"a": a, "b": b, "ca": ca, "cb": cb, "dir": dir, "kind": kind, "data": data}
	conns.append(c)
	return c


## Na superfície os lugares do chão vizinhos se ligam a céu aberto.
func _connect_ground_row() -> void:
	for x in range(0, gw - 1):
		var a := own(Vector2i(x, gr))
		var b := own(Vector2i(x + 1, gr))
		if a >= 0 and b >= 0 and a != b:
			_connect(a, b, Vector2i(x, gr), Vector2i(x + 1, gr), "open")


## Células livres vizinhas de um lugar (para ramos opcionais).
func _free_neighbors(i: int, horizontal_only: bool) -> Array:
	var out: Array = []
	var r := pcell(i)
	for y in range(r.position.y, r.end.y):
		for x in [r.position.x - 1, r.end.x]:
			var c := Vector2i(x, y)
			if own(c) == -1:
				out.append([c, Vector2i(x + (1 if x < r.position.x else -1), y)])
	if not horizontal_only:
		for x in range(r.position.x, r.end.x):
			for y in [r.position.y - 1, r.end.y]:
				var c := Vector2i(x, y)
				if own(c) == -1:
					out.append([c, Vector2i(x, y + (1 if y < r.position.y else -1))])
	return out


func _add_branches() -> void:
	var hosts: Array = []
	for p in places:
		if p["kind"] in ["trilha", "galeria", "gruta", "salao", "poco", "santuario", "vila", "abismo", "lago"]:
			hosts.append(int(p["index"]))
	RngUtil.shuffle(rng, hosts)
	# cofres (1-2): parede rachada, portão de habilidade ou aberto
	var want_vaults := rng.randi_range(1, 2)
	for hi in hosts:
		if want_vaults <= 0:
			break
		var opts := _free_neighbors(int(hi), true)
		RngUtil.shuffle(rng, opts)
		for o in opts:
			var c: Vector2i = o[0]
			if mode != "enclosed" and c.y < gr:
				continue
			var kind := "secret" if rng.randf() < 0.55 else "open"
			var data := {}
			if kind == "open" and not gate_candidates.is_empty() and rng.randf() < 0.6:
				kind = "ability"
				data = {"ability": RngUtil.pick(rng, gate_candidates)}
			var vi := _add_place("cofre", Rect2i(c, Vector2i.ONE), {"on_path": false})
			_connect(int(hi), vi, o[1], c, kind, data)
			want_vaults -= 1
			break
	# mirante no alto (superfície/céu)
	if mode != "enclosed":
		for hi in hosts:
			var r := pcell(int(hi))
			if r.position.y != gr or places[hi]["kind"] in ["vila", "abismo"]:
				continue
			var c := Vector2i(r.position.x + rng.randi_range(0, r.size.x - 1), gr - 1)
			if own(c) == -1:
				var mi := _add_place("mirante", Rect2i(c, Vector2i.ONE), {"on_path": false})
				_connect(int(hi), mi, Vector2i(c.x, gr), c, "open")
				break
	# prova de agilidade (0-1) com recompensa
	if rng.randf() < 0.6:
		for hi in hosts:
			var done := false
			for o in _free_neighbors(int(hi), true):
				var c: Vector2i = o[0]
				if mode != "enclosed" and c.y <= gr:
					continue
				var dx: int = c.x - int(o[1].x)
				var c2 := c + Vector2i(dx, 0)
				if own(c2) != -1:
					continue
				var r2 := Rect2i(Vector2i(mini(c.x, c2.x), c.y), Vector2i(2, 1))
				var di := _add_place("desafio", r2, {"on_path": false})
				_connect(int(hi), di, o[1], c, "open")
				done = true
				break
			if done:
				break
	# ninho extra
	if int(_kind_count.get("ninho", 0)) == 0:
		for hi in hosts:
			var done2 := false
			for o in _free_neighbors(int(hi), true):
				var c: Vector2i = o[0]
				if mode != "enclosed" and c.y <= gr:
					continue
				var ni := _add_place("ninho", Rect2i(c, Vector2i.ONE), {"on_path": false})
				_connect(int(hi), ni, o[1], c, "open")
				done2 = true
				break
			if done2:
				break
	# fenda dimensional
	var rift: String = str(params.get("rift", ""))
	if rift != "":
		for hi in hosts:
			var done3 := false
			for o in _free_neighbors(int(hi), true):
				var c: Vector2i = o[0]
				if mode != "enclosed" and c.y < gr:
					continue
				var fi := _add_place("fenda", Rect2i(c, Vector2i.ONE), {"on_path": false, "rift": rift})
				_connect(int(hi), fi, o[1], c, "ability", {"ability": "dimension_shift"})
				done3 = true
				break
			if done3:
				break


## Atalhos: lugares vizinhos sem ligação e longe um do outro no grafo ganham
## um portão que só abre pela alavanca do lado mais distante do santuário.
func _add_shortcuts() -> void:
	var dist := _graph_dist(shrine_idx)
	var made := 0
	var pairs: Array = []
	for y in gh:
		for x in gw:
			var c := Vector2i(x, y)
			var a := own(c)
			if a < 0:
				continue
			for d in [Vector2i(1, 0)]: # só na horizontal: o portão é vertical
				var n: Vector2i = c + d
				var b := own(n)
				if b < 0 or b == a or _connected(a, b):
					continue
				pairs.append([a, b, c, n])
	RngUtil.shuffle(rng, pairs)
	var ok_kinds := ["trilha", "galeria", "gruta", "salao", "poco", "santuario", "abismo", "lago"]
	for pr in pairs:
		if made >= 2:
			break
		var a: int = pr[0]
		var b: int = pr[1]
		if not (places[a]["kind"] in ok_kinds and places[b]["kind"] in ok_kinds):
			continue
		if not dist.has(a) or not dist.has(b) or absi(int(dist[a]) - int(dist[b])) < 3:
			continue
		if mode != "enclosed" and (Vector2i(pr[2]).y == gr and Vector2i(pr[3]).y == gr):
			continue
		var far := a if int(dist[a]) > int(dist[b]) else b
		_connect(a, b, pr[2], pr[3], "lever", {"lever_side": far})
		made += 1


func _graph_dist(src: int) -> Dictionary:
	var dist := {src: 0}
	var q: Array = [src]
	while not q.is_empty():
		var u: int = q.pop_front()
		for c in conns:
			var v := -1
			if c["a"] == u:
				v = c["b"]
			elif c["b"] == u:
				v = c["a"]
			if v >= 0 and not dist.has(v):
				dist[v] = int(dist[u]) + 1
				q.append(v)
	return dist


func _name_for(p: Dictionary) -> String:
	var kind: String = p["kind"]
	if kind == "covil":
		return "Covil do Guardião"
	if kind == "vila":
		return str(params.get("region_name", "Vila"))
	var nouns: Array = KIND_NOUNS.get(kind, ["Lugar"])
	var mods: Array = BIOME_MODS.get(biome_id, ["Antigo"])
	if kind == "ninho":
		var nest: String = _nest_species()
		var en: Dictionary = db.enemy(nest)
		if not en.is_empty():
			var nm := "%s de %s" % [nouns[rng.randi_range(0, nouns.size() - 1)], str(en.get("name", nest))]
			if not _used_names.has(nm):
				_used_names[nm] = true
				return nm
	for attempt in 12:
		var nm := "%s %s" % [nouns[rng.randi_range(0, nouns.size() - 1)], mods[rng.randi_range(0, mods.size() - 1)]]
		if not _used_names.has(nm):
			_used_names[nm] = true
			return nm
	return "%s %s" % [nouns[0], mods[0]]


## A espécie que faz ninho na região: a criatura terrestre mais comum.
func _nest_species() -> String:
	var best := "skeleton"
	var bw := -1.0
	var ground: Dictionary = pool.get("ground", {})
	for id in ground.keys():
		if float(ground[id]) > bw:
			bw = float(ground[id])
			best = id
	return best


# ===========================================================================
# Portas: posição de cada ligação na fronteira entre dois lugares
# ===========================================================================

func _place_doors() -> void:
	for ci in conns.size():
		var c: Dictionary = conns[ci]
		var dir: String = c["dir"]
		var a: int = c["a"]
		var b: int = c["b"]
		var ca: Vector2i = c["ca"]
		var cb: Vector2i = c["cb"]
		if dir == "L" or dir == "R":
			var left := a if dir == "R" else b
			var right := b if dir == "R" else a
			var rc := cb if dir == "R" else ca
			var xb := rc.x * CW
			var cy := rc.y
			var surface_row := mode != "enclosed" and cy == gr
			var fy := cy * CH + rng.randi_range(9, CH - 3)
			c["x"] = xb
			c["fy"] = fy
			c["surface"] = surface_row
			places[left]["doors"].append({"side": "R", "x": xb, "fy": fy, "conn": ci, "surface": surface_row})
			places[right]["doors"].append({"side": "L", "x": xb, "fy": fy, "conn": ci, "surface": surface_row})
		else:
			var upper := a if dir == "D" else b
			var lower := b if dir == "D" else a
			var lc := cb if dir == "D" else ca
			var yb := lc.y * CH
			var dx := lc.x * CW + rng.randi_range(6, CW - 10)
			var open_air: bool = mode != "enclosed" and lc.y == gr
			c["dx"] = dx
			c["yb"] = yb
			c["open_air"] = open_air
			places[upper]["doors"].append({"side": "D", "dx": dx, "yb": yb, "conn": ci, "open_air": open_air})
			places[lower]["doors"].append({"side": "U", "dx": dx, "yb": yb, "conn": ci, "open_air": open_air})


func _door(p: Dictionary, side: String) -> Dictionary:
	for d in p["doors"]:
		if d["side"] == side:
			return d
	return {}


# ===========================================================================
# Escultura
# ===========================================================================

func _carve() -> void:
	if mode == "sky":
		g.fill(AIR)
	if mode != "enclosed":
		_carve_surface()
	for p in places:
		var r := pcell(int(p["index"]))
		var ground_place: bool = mode != "enclosed" and r.position.y == gr
		if ground_place:
			# já esculpido na linha de superfície; poços descem dela
			if p["kind"] == "poco" and int(p["cells"][1]) > 1:
				_carve_shaft(p, true)
			continue
		if mode != "enclosed" and r.end.y <= gr:
			_carve_high(p)
			continue
		if mode == "sky":
			_carve_island(p)
			continue
		match str(p["kind"]):
			"poco", "torre":
				_carve_shaft(p)
			"salao", "coracao":
				_carve_hall(p)
			"covil":
				_carve_arena(p)
			"santuario", "vila", "fenda":
				_carve_chamber(p)
			"cofre":
				_carve_vault(p)
			"ninho":
				_carve_nest(p)
			"abismo":
				_carve_tunnel(p, true)
			"desafio":
				_carve_tunnel(p, false)
				_challenge(p)
			"passagem":
				if p["port"]["dir"] in ["U", "D"]:
					_carve_shaft(p)
				else:
					_carve_tunnel(p, false)
					_tunnel_to_edge(p)
			_:
				_carve_tunnel(p, false) if int(p["cells"][0]) >= 2 else _carve_chamber(p)
	_close_edges()


## Interior de um lugar (margem de 2 tiles => paredes de 4 entre lugares).
func _inner(p: Dictionary, m: int = 2) -> Rect2i:
	var r := prect(int(p["index"]))
	return Rect2i(r.position.x + m, r.position.y + m, r.size.x - 2 * m, r.size.y - 2 * m)


# ---------------------------------------------------------------------------
# Superfície (céu aberto): linha de relevo contínua de ponta a ponta
# ---------------------------------------------------------------------------

func _carve_surface() -> void:
	var ground: Array = []
	for p in places:
		var r := pcell(int(p["index"]))
		if r.position.y == gr:
			ground.append(p)
	ground.sort_custom(func(a, b): return int(a["cell"][0]) < int(b["cell"][0]))
	var hb: Array = []
	for i in ground.size() + 1:
		hb.append(ground_base + rng.randi_range(-2, 2))
	hb[0] = ground_base
	hb[ground.size()] = ground_base
	for i in ground.size():
		var k: String = ground[i]["kind"]
		if k in ["vila", "covil", "santuario", "passagem", "coracao"]:
			hb[i] = ground_base
			hb[i + 1] = ground_base
	var sky_top := 0
	for i in ground.size():
		var p: Dictionary = ground[i]
		var r := prect(int(p["index"]))
		var prof := _profile(p, r.position.x, r.size.x, int(hb[i]), int(hb[i + 1]))
		for k in r.size.x:
			var x := r.position.x + k
			surf[x] = prof[k]
	# terra/rocha abaixo da linha, ar acima
	var rock_bottom := (gr + 1) * CH - 1
	for x in w:
		var s: int = surf[x]
		for y in range(sky_top, h):
			if mode == "sky":
				continue
			if s < 0 or y < s:
				if y <= rock_bottom:
					gset(x, y, AIR)
			elif y <= rock_bottom:
				gset(x, y, SOLID)
	if mode == "sky":
		_sky_islands()
	# detalhes por lugar (abismo, lago, covil, santuário...)
	for p in ground:
		_surface_features(p)


## Perfil do chão (linha do primeiro tile sólido) de um lugar da superfície.
func _profile(p: Dictionary, x0: int, n: int, hl: int, hr: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(n)
	var kind: String = p["kind"]
	var lo := ground_base - 5
	var hi := ground_base + 3
	if kind in ["vila", "covil", "santuario", "passagem", "coracao"]:
		out.fill(ground_base)
		if kind == "santuario":
			# plataforma de pedra elevada no meio
			for k in range(n / 2 - 5, n / 2 + 5):
				out[k] = ground_base - 1
		return out
	if kind == "lago":
		var edge := rng.randi_range(4, 6)
		var basin_floor := ground_base + 3
		var k := 0
		while k < n:
			var y := hl
			if k < edge:
				y = hl
			elif k >= n - edge:
				y = hr
			else:
				var t := mini(k - edge, n - edge - 1 - k)
				y = mini(ground_base + mini(t, 2) * 1 + (1 if t >= 2 else 0), basin_floor)
				y = maxi(y, ground_base)
			out[k] = y
			k += 1
		p["basin"] = [x0 + edge, x0 + n - edge - 1]
		return out
	# trilha / abismo / genérico: platôs com degraus de 1-2
	var y := hl
	var k2 := 0
	while k2 < n:
		var run := rng.randi_range(4, 9)
		var remaining := n - k2
		if remaining <= run + 2:
			run = remaining
		for j in run:
			if k2 + j < n:
				out[k2 + j] = y
		k2 += run
		if k2 >= n:
			break
		# aproxima do alvo à direita no fim
		var target := hr if n - k2 < 10 else clampi(hl + rng.randi_range(-3, 3), lo, hi)
		var step := clampi(target - y, -2, 2)
		if step == 0 and rng.randf() < 0.5:
			step = 1 if rng.randf() < 0.5 else -1
		y = clampi(y + step, lo, hi)
	# último trecho encosta na altura da fronteira
	var k3 := n - 1
	while k3 >= 0 and absi(out[k3] - hr) > 0 and n - 1 - k3 < 3:
		out[k3] = hr
		k3 -= 1
	return out


func _surface_features(p: Dictionary) -> void:
	var r := prect(int(p["index"]))
	var kind: String = p["kind"]
	var x0 := r.position.x
	var x1 := r.end.x - 1
	match kind:
		"abismo":
			_ravine(p, x0, x1)
		"lago":
			var bs: Array = p.get("basin", [])
			if bs.size() == 2:
				var top := ground_base
				var bottom := ground_base
				for x in range(int(bs[0]), int(bs[1]) + 1):
					bottom = maxi(bottom, surf[x])
				if bottom > top:
					water.append([int(bs[0]), int(bs[1]), top, bottom - 1])
		"coracao":
			# marco ao fundo: estátua/árvore colossal no meio da clareira
			var cx := x0 + (x1 - x0) / 2
			for y in range(ground_base - 16, ground_base):
				for x in range(cx - 4, cx + 5):
					var dx := absi(x - cx)
					if dx <= 1 or y > ground_base - 3 or (y < ground_base - 11 and dx <= 4) or (y < ground_base - 8 and dx <= 2):
						set_bg(x, y, 1)
		"covil":
			# paredões dos dois lados até o topo: arena de cânion
			for x in [x0, x0 + 1, x1 - 1, x1]:
				for y in range(0, surf[x]):
					gset(x, y, SOLID)
		"trilha":
			# pedras e um buraquinho de vez em quando
			if rng.randf() < 0.45 and r.size.x >= 20:
				var bx := rng.randi_range(x0 + 6, x1 - 8)
				var ok := true
				for x in range(bx - 1, bx + 4):
					if surf[x] != surf[bx]:
						ok = false
				if ok:
					var depth := rng.randi_range(2, 3)
					for x in range(bx, bx + 3):
						for y in range(surf[x], surf[x] + depth):
							gset(x, y, AIR)
			if rng.randf() < 0.5:
				var rx := rng.randi_range(x0 + 3, x1 - 3)
				var hh := rng.randi_range(1, 2)
				for x in range(rx, rx + rng.randi_range(2, 3)):
					for y in range(surf[x] - hh, surf[x]):
						gset(x, y, SOLID)
	if mode == "surface" and built:
		_background_trees(p)


## Ravina: o chão some no meio e desce até a caverna de baixo (espinhos no
## fundo se não houver nada lá); pedras e plataformas para atravessar.
func _ravine(p: Dictionary, x0: int, x1: int) -> void:
	var n := x1 - x0 + 1
	var gap := clampi(int(n * 0.55), 8, 22)
	var gx0 := x0 + (n - gap) / 2
	var gx1 := gx0 + gap - 1
	var below := own(Vector2i(gx0 / CW, gr + 1))
	var bottom := (gr + 1) * CH + CH - 3 if below == -1 else (gr + 1) * CH - 2
	if mode == "sky":
		bottom = h + 4
	for x in range(gx0, gx1 + 1):
		for y in range(surf[x] - 1, mini(bottom + 1, h)):
			gset(x, y, AIR)
		surf[x] = -1
	if mode != "sky":
		for x in range(gx0, gx1 + 1):
			gset(x, bottom + 1, SOLID)
			gset(x, bottom + 2, SOLID)
			gset(x, bottom, SPIKE)
		# paredes da ravina (as colunas de fora descem até o fundo)
		for y in range(ground_base, bottom + 3):
			gset(gx0 - 1, y, SOLID)
			gset(gx1 + 1, y, SOLID)
	# travessia: pedras/plataformas a cada 3-4 tiles
	var x := gx0 + rng.randi_range(2, 3)
	var yl := ground_base
	while x < gx1 - 1:
		var style := rng.randi_range(0, 2)
		var py := clampi(yl + rng.randi_range(-2, 1), ground_base - 4, ground_base + 1)
		if style == 0 and mode != "sky":
			# pilar de pedra que sobe do fundo
			for y in range(py, bottom):
				gset(x, y, SOLID)
				gset(x + 1, y, SOLID)
		else:
			for k in 3:
				gset(x + k, py, ONE_WAY)
		yl = py
		x += rng.randi_range(4, 5)
	p["gap"] = [gx0, gx1]


func _sky_islands() -> void:
	# o chão de cada lugar vira ilha: rocha sob a superfície com fundo arredondado
	for x in w:
		var s: int = surf[x]
		if s < 0:
			continue
		var thick := 5 + int(noise1(71, x, 7.0) * 6.0)
		for y in range(s, mini(s + thick, h)):
			gset(x, y, SOLID)
	# bordas das ilhas arredondadas
	for x in w:
		if surf[x] < 0:
			continue
		var edge_d := 99
		for k in range(1, 5):
			if x - k < 0 or surf[x - k] < 0 or x + k >= w or surf[x + k] < 0:
				edge_d = k
				break
		if edge_d < 4:
			var s2: int = surf[x]
			for y in range(s2 + 1 + edge_d * 2, h):
				gset(x, y, AIR)


## Árvores/ruínas ao fundo (parede de fundo em forma de tronco e copa).
func _background_trees(p: Dictionary) -> void:
	var r := prect(int(p["index"]))
	var ts: String = biome.get("tileset", "")
	if not ts in ["town", "castle", "temple", "ruins"]:
		return
	var n := r.size.x / 12
	for i in n:
		if rng.randf() < 0.45:
			continue
		var cx := r.position.x + i * 12 + rng.randi_range(2, 9)
		if surf[cx] < 0:
			continue
		var top := surf[cx] - rng.randi_range(8, 14)
		if true:
			# coluna/arco partido (alvenaria ao fundo)
			for y in range(top, surf[cx]):
				set_bg(cx, y, 1)
				set_bg(cx + 1, y, 1)
			for x in range(cx, cx + rng.randi_range(4, 7)):
				set_bg(x, top, 1)
			continue
		for y in range(top + 3, surf[cx]):
			set_bg(cx, y, 1)
			if y > surf[cx] - 3:
				set_bg(cx - 1, y, 1)
				set_bg(cx + 1, y, 1)
		# copa
		var cr := rng.randi_range(3, 4)
		for dy in range(-cr, cr + 1):
			for dx in range(-cr - 1, cr + 2):
				if dx * dx * 0.7 + dy * dy <= cr * cr:
					set_bg(cx + dx, top + 2 + dy, 1)


## Estruturas no alto (linha de cima na superfície): mirante (pico/torre) e a
## torre/árvore que sobe até a região do céu.
func _carve_high(p: Dictionary) -> void:
	var r := prect(int(p["index"]))
	var kind: String = p["kind"]
	if kind == "mirante":
		var wdt := rng.randi_range(9, 12)
		var x0 := r.position.x + (r.size.x - wdt) / 2
		var top := r.position.y + rng.randi_range(5, 8)
		var base := 0
		for x in range(x0, x0 + wdt):
			base = maxi(base, surf[x] if surf[x] >= 0 else ground_base)
		for x in range(x0, x0 + wdt):
			var t := top + (1 if x == x0 or x == x0 + wdt - 1 else 0)
			for y in range(t, base + 1):
				gset(x, y, SOLID)
		# arco na base: o caminho do chão continua passando por baixo
		for x in range(x0, x0 + wdt):
			var sy: int = surf[x] if surf[x] >= 0 else ground_base
			var arch := 5 if absi(x - (x0 + wdt / 2)) < wdt / 2 - 1 else 4
			for y in range(sy - arch, sy):
				gset(x, y, AIR)
				set_bg(x, y, 1)
		# saliências dos dois lados a cada 3 tiles (degraus desencontrados)
		for side in [0, 1]:
			var y := base - 3
			var k2 := 0
			while y > top + 1:
				var off := 0 if k2 % 2 == 0 else 3
				var lx := x0 - 3 - off if side == 0 else x0 + wdt + off
				for k in 3:
					if gget(lx + k, y) == AIR:
						gset(lx + k, y, ONE_WAY)
				k2 += 1
				y -= 3
		p["top"] = [x0 + wdt / 2, top - 1]
		if built:
			for x in range(x0 + 1, x0 + wdt - 1):
				for yy in range(top - 6, top):
					set_bg(x, yy, 1)
	elif kind == "torre":
		# tronco/torre ao fundo + galhos de mão única alternados até o topo
		var cx := r.position.x + r.size.x / 2
		var base2 := surf[cx] if surf[cx] >= 0 else ground_base
		for y in range(0, base2):
			for x in range(cx - 2, cx + 2):
				set_bg(x, y, 1)
		var y2 := base2 - 3
		var side2 := 0
		while y2 > 1:
			var lx2 := cx - 6 if side2 == 0 else cx + 1
			for k in 5:
				gset(lx2 + k, y2, ONE_WAY)
			side2 = 1 - side2
			y2 -= 3
		for x in range(cx - 4, cx + 4):
			gset(x, 0, AIR)


# ---------------------------------------------------------------------------
# Subsolo / lugares fechados
# ---------------------------------------------------------------------------

func noise2(s: int, x: float, y: float, sc: float = 4.0) -> float:
	var xs := x / sc
	var ys := y / sc
	var ix := floori(xs)
	var iy := floori(ys)
	var fx := xs - ix
	var fy := ys - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash01(s, ix * 7919 + iy * 104729)
	var b := _hash01(s, (ix + 1) * 7919 + iy * 104729)
	var c := _hash01(s, ix * 7919 + (iy + 1) * 104729)
	var d := _hash01(s, (ix + 1) * 7919 + (iy + 1) * 104729)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func _carve_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	fill(x0, y0, x1, y1, AIR)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			set_bg(x, y, 1)


## Bolhas (metaballs) com borda irregular: cavernas orgânicas.
func _carve_blobs(ir: Rect2i, n: int, roughness: float = 0.35) -> void:
	var blobs: Array = []
	for i in n:
		var rx := rng.randf_range(5.0, maxf(6.0, ir.size.x * 0.42))
		var ry := rng.randf_range(3.5, maxf(4.0, ir.size.y * 0.5))
		var cx := rng.randf_range(ir.position.x + rx * 0.7, ir.end.x - rx * 0.7)
		var cy := rng.randf_range(ir.position.y + ry * 0.8, ir.end.y - ry * 0.7)
		blobs.append([cx, cy, rx, ry])
	var s := rng.randi() % 100000
	for y in range(ir.position.y, ir.end.y):
		for x in range(ir.position.x, ir.end.x):
			var f := -1.0
			for b in blobs:
				var dx: float = (x + 0.5 - float(b[0])) / float(b[2])
				var dy: float = (y + 0.5 - float(b[1])) / float(b[3])
				f = maxf(f, 1.0 - (dx * dx + dy * dy))
			if f + (noise2(s, x, y) - 0.5) * roughness > 0.08:
				gset(x, y, AIR)
				set_bg(x, y, 1)


## Chão em platôs: em cada faixa de colunas o chão desce até o mais fundo
## (só remove rocha: nunca fecha caminhos).
func _terrace(ir: Rect2i) -> void:
	var x := ir.position.x
	while x < ir.end.x:
		var run := rng.randi_range(3, 6)
		var deepest := -1
		for k in run:
			var xx := x + k
			if xx >= ir.end.x:
				break
			var fy := _floor_below(xx, ir)
			deepest = maxi(deepest, fy)
		if deepest > 0:
			for k in run:
				var xx2 := x + k
				if xx2 >= ir.end.x:
					break
				var fy2 := _floor_below(xx2, ir)
				if fy2 > 0 and fy2 < deepest and deepest - fy2 <= 3:
					for y in range(fy2, deepest):
						gset(xx2, y, AIR)
						set_bg(xx2, y, 1)
		x += run


## Linha do chão (primeiro sólido abaixo do ar) na coluna, dentro do retângulo.
func _floor_below(x: int, ir: Rect2i) -> int:
	for y in range(ir.end.y - 1, ir.position.y, -1):
		if gget(x, y) == SOLID and gget(x, y - 1) != SOLID:
			return y
	return -1


## Saliências de pedra presas às paredes, a cada ~3 tiles de altura.
func _wall_ledges(ir: Rect2i, every: int = 3) -> void:
	var y := ir.end.y - 1 - every
	var side := rng.randi_range(0, 1)
	while y > ir.position.y + 2:
		var xs := range(ir.position.x, ir.end.x) if side == 0 else range(ir.end.x - 1, ir.position.x - 1, -1)
		var wall_x := -1
		var inside := false
		for x in xs:
			if gget(x, y) != SOLID and gget(x, y - 1) != SOLID:
				inside = true
				wall_x = x
				break
		if inside:
			var ln := rng.randi_range(3, 5)
			var dirx := 1 if side == 0 else -1
			var ok := true
			for k in ln:
				var xx: int = wall_x + k * dirx
				for yy in range(y - 3, y):
					if gget(xx, yy) == SOLID:
						ok = false
			if ok:
				for k in ln:
					gset(wall_x + k * dirx, y, SOLID if not built else ONE_WAY)
		side = 1 - side
		y -= every + rng.randi_range(0, 1)


func _stalactites(ir: Rect2i, chance: float) -> void:
	for x in range(ir.position.x + 1, ir.end.x - 1):
		if rng.randf() > chance:
			continue
		for y in range(ir.position.y, ir.end.y):
			if gget(x, y) == SOLID and gget(x, y + 1) == AIR and gget(x, y + 2) == AIR and gget(x, y + 3) == AIR and gget(x, y + 4) == AIR:
				var ln := rng.randi_range(1, 2)
				for k in ln:
					gset(x, y + 1 + k - 1, SOLID)
				break


func _carve_hall(p: Dictionary) -> void:
	var ir := _inner(p, 2)
	if built:
		_carve_rect(ir.position.x, ir.position.y + 1, ir.end.x - 1, ir.end.y - 2)
		_arches(ir)
		_stairs_and_balconies(ir)
		_windows_in(ir)
	else:
		_carve_blobs(ir, 3 + int(p["cells"][0]) * int(p["cells"][1]), 0.4)
		_terrace(ir)
		_mesas(ir)
		_wall_ledges(ir, 3)
		_stalactites(ir, 0.18)
	# marco no centro do salão do coração: pilar/estátua ao fundo
	if p["kind"] == "coracao":
		var cx := ir.position.x + ir.size.x / 2
		var fy := _floor_below(cx, ir)
		if fy > 0:
			for y in range(fy - 12, fy):
				for x in range(cx - 3, cx + 4):
					if absi(x - cx) <= 1 or y > fy - 3 or (y < fy - 9 and absi(x - cx) <= 3):
						set_bg(x, y, 1)


## Salão de pedra: pilares com topo plano (mesas) subindo em degraus de até 3
## tiles, do chão para o alto — o caminho para as saídas de cima é a própria
## rocha, não tábuas flutuantes.
func _mesas(ir: Rect2i) -> void:
	var x := ir.position.x + rng.randi_range(4, 7)
	var level := 0
	while x < ir.end.x - 5:
		var fy := _floor_below(x + 1, ir)
		if fy < 0:
			x += 4
			continue
		level = clampi(level + rng.randi_range(-1, 2), 1, 5)
		var top := fy - level * 3
		var wdt := rng.randi_range(3, 5)
		var ok := top > ir.position.y + 4
		for xx in range(x, x + wdt):
			for yy in range(top - 3, top):
				if gget(xx, yy) == SOLID:
					ok = false
		if ok:
			for xx in range(x, x + wdt):
				var fb := _floor_below(xx, ir)
				if fb < 0:
					continue
				for yy in range(top, fb):
					gset(xx, yy, SOLID)
			# base mais larga (pé do pilar)
			for yy in range(fy - 2, fy):
				if gget(x - 1, yy) == AIR:
					gset(x - 1, yy, SOLID)
				if gget(x + wdt, yy) == AIR:
					gset(x + wdt, yy, SOLID)
		x += wdt + rng.randi_range(4, 7)


## Castelos/templos: sacadas (mão única) presas às paredes a cada ~6 tiles,
## alcançadas por escadarias de degraus sólidos.
func _stairs_and_balconies(ir: Rect2i) -> void:
	var fy := ir.end.y - 1
	var y := fy - 6
	var side := rng.randi_range(0, 1)
	var prev_y := fy
	while y > ir.position.y + 4:
		var ln := rng.randi_range(9, 14)
		var bx0 := ir.position.x if side == 0 else ir.end.x - ln
		for x in range(bx0, bx0 + ln):
			gset(x, y, ONE_WAY)
		# escadaria do nível de baixo até a ponta da sacada
		var sx := bx0 + ln if side == 0 else bx0 - 1
		var dirx := 1 if side == 0 else -1
		var sy := prev_y - 1
		var steps := 0
		while sy > y and steps < 10:
			var cx := sx + steps * 2 * dirx
			if cx < ir.position.x + 1 or cx > ir.end.x - 2:
				break
			for k in 2:
				for yy in range(sy, prev_y):
					if gget(cx + k * dirx, yy) == AIR:
						gset(cx + k * dirx, yy, SOLID)
			sy -= 1
			steps += 1
		prev_y = y
		side = 1 - side
		y -= 6


func _arches(ir: Rect2i) -> void:
	var x := ir.position.x + rng.randi_range(3, 6)
	while x < ir.end.x - 3:
		# nervura em arco pendurada do teto
		var top := ir.position.y + 1
		gset(x, top, SOLID)
		gset(x + 1, top, SOLID)
		gset(x - 1, top, SOLID)
		gset(x, top + 1, SOLID)
		x += rng.randi_range(8, 11)


func _windows_in(ir: Rect2i) -> void:
	if mode != "enclosed" or biome.get("tags", []).has("underground") or str(params.get("layer", "")) == "underground":
		return
	var x := ir.position.x + rng.randi_range(3, 6)
	while x < ir.end.x - 5:
		if rng.randf() < 0.6:
			var ww := rng.randi_range(3, 4)
			var wh := rng.randi_range(5, 7)
			var wy := ir.position.y + 2
			for y in range(wy, wy + wh):
				for xx in range(x, x + ww):
					if y == wy and (xx == x or xx == x + ww - 1):
						continue
					if gget(xx, y) == AIR:
						set_bg(xx, y, 2)
		x += rng.randi_range(9, 13)


func _carve_tunnel(p: Dictionary, chasm: bool) -> void:
	var ir := _inner(p, 2)
	var dl := _door(p, "L")
	var dr := _door(p, "R")
	var fl: int = int(dl["fy"]) if not dl.is_empty() else ir.end.y - rng.randi_range(1, 4)
	var frr: int = int(dr["fy"]) if not dr.is_empty() else ir.end.y - rng.randi_range(1, 4)
	var n := ir.size.x
	var floor_y := PackedInt32Array()
	floor_y.resize(n)
	var y := fl
	var k := 0
	while k < n:
		var run := rng.randi_range(4, 8)
		for j in run:
			if k + j < n:
				floor_y[k + j] = y
		k += run
		var target := frr if n - k < 12 else clampi(fl + rng.randi_range(-3, 3), ir.position.y + 6, ir.end.y)
		y = clampi(y + clampi(target - y, -2, 2), ir.position.y + 6, ir.end.y)
	for j in range(maxi(0, n - 3), n):
		floor_y[j] = frr
	var s := rng.randi() % 100000
	for j in n:
		var x := ir.position.x + j
		var fy: int = floor_y[j]
		var hgt := 5 + int(noise1(s, x, 9.0) * 5.0)
		var ceil_y := maxi(ir.position.y, fy - hgt)
		for yy in range(ceil_y, fy):
			gset(x, yy, AIR)
			set_bg(x, yy, 1)
	if built:
		_arches(Rect2i(ir.position.x, ir.position.y, ir.size.x, ir.size.y))
	else:
		_stalactites(ir, 0.12)
	if chasm:
		# poço de espinhos no meio + pedras para atravessar
		var gap := clampi(int(n * 0.5), 8, 20)
		var gx0 := ir.position.x + (n - gap) / 2
		var base := 0
		for x in range(gx0, gx0 + gap):
			base = maxi(base, floor_y[x - ir.position.x])
		var bottom := mini(ir.end.y + 1, base + 6)
		for x in range(gx0, gx0 + gap):
			for yy in range(floor_y[x - ir.position.x] - 1, bottom):
				gset(x, yy, AIR)
				set_bg(x, yy, 1)
			gset(x, bottom, SPIKE)
			gset(x, bottom + 1, SOLID)
		var x2 := gx0 + rng.randi_range(2, 3)
		while x2 < gx0 + gap - 2:
			var py := base - rng.randi_range(0, 2)
			if rng.randf() < 0.5:
				for yy in range(py, bottom):
					gset(x2, yy, SOLID)
					gset(x2 + 1, yy, SOLID)
			else:
				for kk in 3:
					gset(x2 + kk, py, ONE_WAY)
			x2 += rng.randi_range(4, 5)
		p["gap"] = [gx0, gx0 + gap - 1]
	elif not built and rng.randf() < 0.3 and n > 20:
		# fosso raso de espinhos (pulável)
		var px := ir.position.x + rng.randi_range(8, n - 12)
		var fy2: int = floor_y[px - ir.position.x]
		var same := true
		for x in range(px - 1, px + 4):
			if floor_y[x - ir.position.x] != fy2:
				same = false
		if same:
			for x in range(px, px + 3):
				gset(x, fy2, AIR)
				gset(x, fy2 + 1, SPIKE)
				gset(x, fy2 + 2, SOLID)


## Passagem lateral fechada: o túnel continua até a borda da região.
func _tunnel_to_edge(p: Dictionary) -> void:
	var ir := _inner(p, 2)
	var left: bool = str(p["port"]["dir"]) == "L"
	var ex := ir.position.x if left else ir.end.x - 1
	var fy := _floor_below(ex, Rect2i(ir.position.x, ir.position.y, ir.size.x, ir.size.y + 1))
	if fy < 0:
		fy = ir.end.y - 1
	var xs := range(0, ex + 1) if left else range(ex, w)
	for x in xs:
		for y in range(fy - 4, fy):
			gset(x, y, AIR)
			set_bg(x, y, 1)
		gset(x, fy, SOLID)


func _carve_shaft(p: Dictionary, from_surface: bool = false) -> void:
	var ir := _inner(p, 2)
	var wdt := rng.randi_range(9, 12)
	var cx := ir.position.x + ir.size.x / 2 + rng.randi_range(-3, 3)
	var x0 := clampi(cx - wdt / 2, ir.position.x, ir.end.x - wdt)
	var s := rng.randi() % 100000
	var y0 := ir.position.y
	var y1 := ir.end.y - 1
	if from_surface:
		# boca do poço no chão (alçapão de mão única por cima)
		y0 = ground_base
		for x in range(x0, x0 + wdt):
			if surf[x] >= 0:
				y0 = mini(y0, surf[x])
		for x in range(x0 - 2, x0 + wdt + 3):
			for y in range(y0, maxi(surf[clampi(x, 0, w - 1)], y0)):
				gset(x, y, SOLID)
	var port: Dictionary = p.get("port", {})
	if str(port.get("dir", "")) == "U":
		y0 = 0
	elif str(port.get("dir", "")) == "D":
		y1 = h - 1
	for y in range(y0, y1 + 1):
		var jl := int(noise1(s, y, 4.0) * 3.0)
		var jr := int(noise1(s + 17, y, 4.0) * 3.0)
		for x in range(x0 - jl, x0 + wdt + jr):
			gset(x, y, AIR)
			set_bg(x, y, 1)
	if from_surface:
		for x in range(x0 - 1, x0 + wdt + 1):
			gset(x, y0, ONE_WAY)
			set_bg(x, y0, 0)
	# saliências alternadas (pedra ou mão única) a cada 3 tiles
	var y2 := y1 - 3
	var side := 0
	while y2 > y0 + 2:
		var ln := rng.randi_range(4, 5)
		var lx := x0 - 2 if side == 0 else x0 + wdt - ln + 2
		for k in ln:
			gset(lx + k, y2, ONE_WAY if built or rng.randf() < 0.5 else SOLID)
		side = 1 - side
		y2 -= 3
	p["shaft"] = [x0, x0 + wdt - 1, y0, y1]


func _carve_arena(p: Dictionary) -> void:
	var ir := _inner(p, 2)
	var fy := ir.end.y - 1
	var top := maxi(ir.position.y, fy - 13)
	_carve_rect(ir.position.x, top, ir.end.x - 1, fy - 1)
	# plataformas laterais para esquivar
	for side in [0, 1]:
		var px := ir.position.x + 5 if side == 0 else ir.end.x - 11
		for x in range(px, px + 6):
			gset(x, fy - 5, ONE_WAY)
	var mid := ir.position.x + ir.size.x / 2
	for x in range(mid - 4, mid + 4):
		gset(x, fy - 9, ONE_WAY)
	if built:
		_arches(Rect2i(ir.position.x, top - 1, ir.size.x, 4))
		_windows_in(Rect2i(ir.position.x, top, ir.size.x, 8))
	p["floor"] = fy


func _carve_chamber(p: Dictionary) -> void:
	var ir := _inner(p, 2)
	var fy := ir.end.y - 1 - rng.randi_range(0, 2)
	var dl := _door(p, "L")
	var dr := _door(p, "R")
	if not dl.is_empty():
		fy = int(dl["fy"])
	elif not dr.is_empty():
		fy = int(dr["fy"])
	var hgt := rng.randi_range(8, 10)
	var top := maxi(ir.position.y, fy - hgt)
	var cx := ir.position.x + ir.size.x / 2
	var half := ir.size.x / 2
	for x in range(ir.position.x, ir.end.x):
		# teto em arco (abóbada)
		var t := absf(float(x - cx) / float(half))
		var dome := int((1.0 - sqrt(maxf(0.0, 1.0 - t * t))) * 4.0)
		for y in range(top + dome, fy):
			gset(x, y, AIR)
			set_bg(x, y, 1)
	for x in range(ir.position.x, ir.end.x):
		gset(x, fy, SOLID)
	if built:
		_windows_in(Rect2i(ir.position.x, top, ir.size.x, hgt))
	p["floor"] = fy


func _carve_vault(p: Dictionary) -> void:
	_carve_chamber(p)
	var ir := _inner(p, 2)
	var fy: int = int(p.get("floor", ir.end.y - 1))
	var cx := ir.position.x + ir.size.x / 2
	# pedestal
	for x in range(cx - 2, cx + 3):
		gset(x, fy - 1, SOLID)
	p["pedestal"] = [cx, fy - 2]


func _carve_nest(p: Dictionary) -> void:
	var ir := _inner(p, 2)
	if built:
		_carve_rect(ir.position.x, ir.position.y + 2, ir.end.x - 1, ir.end.y - 2)
		for li in [4, 8]:
			var y: int = ir.end.y - 2 - li
			var x := ir.position.x + rng.randi_range(2, 6)
			while x < ir.end.x - 6:
				for k in rng.randi_range(4, 6):
					gset(x + k, y, ONE_WAY)
				x += rng.randi_range(8, 11)
		return
	# favo: várias bolsas pequenas ligadas
	_carve_blobs(ir, 4 + int(p["cells"][0]) * 3, 0.55)
	_terrace(ir)
	_wall_ledges(ir, 3)
	_stalactites(ir, 0.25)


## Lugares abaixo do chão no céu: ilhas flutuantes.
func _carve_island(p: Dictionary) -> void:
	var r := prect(int(p["index"]))
	var top := r.position.y + rng.randi_range(6, 9)
	var x0 := r.position.x + rng.randi_range(3, 5)
	var x1 := r.end.x - rng.randi_range(4, 6)
	for x in range(x0, x1 + 1):
		var edge := mini(x - x0, x1 - x)
		var thick := clampi(2 + edge, 2, 6)
		for y in range(top, top + thick):
			gset(x, y, SOLID)
	p["floor"] = top


func _challenge(p: Dictionary) -> void:
	# chão de espinhos com plataformas por cima (recompensa no fim)
	var ir := _inner(p, 2)
	var x := ir.position.x + 5
	while x < ir.end.x - 6:
		var fy := _floor_below(x, ir)
		if fy > 0:
			for k in 3:
				if gget(x + k, fy - 1) == AIR and gget(x + k, fy) == SOLID:
					gset(x + k, fy - 1, SPIKE)
			var py := fy - 3
			for k in range(-1, 4):
				if gget(x + k, py) == AIR:
					gset(x + k, py, ONE_WAY)
		x += rng.randi_range(7, 9)


## Bordas da região: fechadas (menos nas passagens).
func _close_edges() -> void:
	var open_l := []
	var open_r := []
	for p in places:
		var pt: Dictionary = p.get("port", {})
		if pt.is_empty():
			continue
		var r := prect(int(p["index"]))
		match str(pt["dir"]):
			"L":
				open_l.append(r)
			"R":
				open_r.append(r)
	for y in h:
		var keep_l := false
		for r in open_l:
			if y >= r.position.y and y < r.end.y:
				keep_l = true
		var keep_r := false
		for r in open_r:
			if y >= r.position.y and y < r.end.y:
				keep_r = true
		if not keep_l:
			gset(0, y, SOLID)
			gset(1, y, SOLID)
		if not keep_r:
			gset(w - 1, y, SOLID)
			gset(w - 2, y, SOLID)
	if mode == "enclosed":
		for x in w:
			var up := false
			var dn := false
			for p in places:
				var pt: Dictionary = p.get("port", {})
				if pt.is_empty():
					continue
				var r := prect(int(p["index"]))
				if x >= r.position.x and x < r.end.x:
					up = up or str(pt["dir"]) == "U"
					dn = dn or str(pt["dir"]) == "D"
			if not up:
				gset(x, 0, SOLID)
			if not dn:
				gset(x, h - 1, SOLID)


# ===========================================================================
# Portas
# ===========================================================================

func _carve_doors() -> void:
	for ci in conns.size():
		var c: Dictionary = conns[ci]
		if c.has("x"):
			_carve_h_door(c)
		elif not c.get("open_air", false):
			_carve_v_door(c)


func _carve_h_door(c: Dictionary) -> void:
	var xb: int = c["x"]
	var fy: int = c["fy"]
	if c.get("surface", false):
		var sl: int = surf[xb - 1]
		var sr: int = surf[xb]
		if sl < 0 and sr < 0:
			c["fy"] = -1
			return
		fy = sl if sl >= 0 else sr
		if sl >= 0 and sr >= 0:
			fy = mini(sl, sr)
		c["fy"] = fy
		for x in range(xb - 3, xb + 3):
			for y in range(fy - 4, fy):
				if gget(x, y) == SOLID:
					gset(x, y, AIR)
		return
	# túnel para a esquerda e para a direita até achar o interior
	for dirx in [-1, 1]:
		var x: int = xb - 1 if dirx < 0 else xb
		for k in 16:
			var body_air := gget(x, fy - 1) != SOLID and gget(x, fy - 2) != SOLID
			if k >= 2 and body_air and gget(x, fy - 3) != SOLID:
				break
			for y in range(fy - 4, fy):
				gset(x, y, AIR)
				set_bg(x, y, 1)
			if gget(x, fy) != SOLID:
				gset(x, fy, SOLID)
			x += dirx


func _carve_v_door(c: Dictionary) -> void:
	var dx: int = c["dx"]
	var yb: int = c["yb"]
	# para cima até o interior do lugar de cima
	var y := yb - 1
	var top := yb
	for k in 18:
		var all_air := true
		for x in range(dx, dx + 4):
			if gget(x, y) == SOLID:
				all_air = false
		if all_air and k >= 1:
			break
		for x in range(dx, dx + 4):
			gset(x, y, AIR)
			set_bg(x, y, 1)
		top = y
		y -= 1
	# para baixo até o interior do lugar de baixo
	var y2 := yb
	var bottom := yb
	for k in 18:
		var all_air2 := true
		for x in range(dx, dx + 4):
			if gget(x, y2) == SOLID:
				all_air2 = false
		if all_air2 and k >= 1:
			break
		for x in range(dx, dx + 4):
			gset(x, y2, AIR)
			set_bg(x, y2, 1)
		bottom = y2
		y2 += 1
	# alçapão (mão única) no chão de cima e vigas alternadas descendo
	for x in range(dx, dx + 4):
		gset(x, top, ONE_WAY)
	c["top"] = top
	var yy := top + 3
	var half := 0
	var extra := 0
	while yy < h - 2 and extra < 6:
		var hx := dx if half == 0 else dx + 2
		if gget(hx, yy) == SOLID or gget(hx + 1, yy) == SOLID:
			break
		# chegou perto do chão do lugar de baixo: para
		if gget(hx, yy + 1) == SOLID or gget(hx, yy + 2) == SOLID:
			break
		gset(hx, yy, ONE_WAY)
		gset(hx + 1, yy, ONE_WAY)
		if yy > bottom:
			extra += 1
		half = 1 - half
		yy += 3


# ===========================================================================
# Conteúdo de cada lugar
# ===========================================================================

var _used := {}


func _ent(type: String, tile: Vector2i, room: int, data: Dictionary = {}, anchor: bool = false) -> Dictionary:
	var e := {"type": type, "tile": [tile.x, tile.y], "room": room, "data": data}
	if anchor:
		e["anchor"] = true
	entities.append(e)
	_used[tile] = true
	return e


func _standable(x: int, y: int) -> bool:
	var a := gget(x, y)
	var b := gget(x, y - 1)
	var f := gget(x, y + 1)
	return a == AIR and b == AIR and (f == SOLID or f == ONE_WAY)


## Tiles em pé dentro do lugar, longe das portas.
func _spots(p: Dictionary, door_clear: int = 5) -> Array:
	var r := prect(int(p["index"]))
	var out: Array = []
	var doors := _door_tiles(p)
	for y in range(maxi(r.position.y, 1), mini(r.end.y, h - 1)):
		for x in range(r.position.x + 1, r.end.x - 1):
			if not _standable(x, y) or _used.has(Vector2i(x, y)):
				continue
			var near := false
			for d in doors:
				if absi(d.x - x) + absi(d.y - y) < door_clear:
					near = true
					break
			if not near:
				out.append(Vector2i(x, y))
	return out


func _door_tiles(p: Dictionary) -> Array:
	var out: Array = []
	for d in p["doors"]:
		var c: Dictionary = conns[int(d["conn"])]
		if c.has("x"):
			if int(c.get("fy", -1)) < 0:
				continue
			var x: int = int(c["x"]) - 1 if d["side"] == "R" else int(c["x"])
			out.append(Vector2i(x, int(c["fy"]) - 1))
		elif c.has("top"):
			out.append(Vector2i(int(c["dx"]) + 1, int(c["top"]) - 1))
			out.append(Vector2i(int(c["dx"]) + 1, int(c["top"]) + 2))
	return out


func _center_spot(p: Dictionary, spots: Array) -> Vector2i:
	var r := prect(int(p["index"]))
	var cx := r.position.x + r.size.x / 2
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for s in spots:
		# chão firme e largo (nada de alçapão ou saliência estreita)
		if gget(s.x, s.y + 1) != SOLID or _floor_run(s) < 5:
			continue
		var d: int = absi(s.x - cx) * 2 + absi(s.y - (r.position.y + r.size.y * 2 / 3))
		if d < bd:
			bd = d
			best = s
	return best


func _floor_run(s: Vector2i) -> int:
	var n := 1
	for dirx in [-1, 1]:
		var x: int = s.x + dirx
		while _standable(x, s.y) and gget(x, s.y + 1) == SOLID and n < 12:
			n += 1
			x += dirx
	return n


func _near_spot(spots: Array, at: Vector2i, min_d: int = 0) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for s in spots:
		if _used.has(s):
			continue
		var d: int = absi(s.x - at.x) + absi(s.y - at.y) * 2
		if d >= min_d and d < bd:
			bd = d
			best = s
	return best


func _populate() -> void:
	_used.clear()
	var npc_ids: Array = params.get("npcs", []).duplicate()
	var port_names: Dictionary = params.get("port_names", {})
	for p in places:
		var i: int = int(p["index"])
		var kind: String = p["kind"]
		var spots := _spots(p, 4)
		match kind:
			"santuario", "vila":
				var c := _center_spot(p, spots)
				if c.x < 0:
					c = _force_floor(p)
				_ent("checkpoint", c, i, {}, true)
				_ent("spawn", c + Vector2i(2, 0), i)
				if built or mode == "enclosed" or pcell(i).position.y > gr:
					_shrine_arch(c)
				for side in [-1, 1]:
					var tx: int = c.x + side * 6
					if gget(tx, c.y - 2) == AIR:
						_ent("torch", Vector2i(tx, c.y - 2), i)
				if kind == "vila":
					var q := _near_spot(spots, c + Vector2i(5, 0), 3)
					if q.x >= 0:
						_ent("quest_board", q, i, {}, true)
				var k := 0
				while not npc_ids.is_empty() and (kind == "vila" or k < 2):
					var at := c + Vector2i((-4 - k * 4) if k % 2 == 0 else (5 + k * 3), 0)
					var ns := _near_spot(spots, at, 2)
					if ns.x < 0:
						break
					_ent("npc", ns, i, {"npc": npc_ids.pop_front()}, true)
					k += 1
				var ins := _near_spot(spots, c + Vector2i(-8, 0), 4)
				if ins.x >= 0:
					_ent("inscription", ins, i, {"biome": biome_id, "idx": 0})
			"covil":
				_lair(p, spots)
				_landmark(p)
			"coracao":
				var c2 := _center_spot(p, spots)
				_landmark(p, c2)
				if c2.x >= 0:
					_ent("relic", c2, i, {"loot": LevelGenerator.roll_loot(rng, db, int(params.get("tier", 1)) + 1, true, true)}, true)
					var ins2 := _near_spot(spots, c2 + Vector2i(-6, 0), 4)
					if ins2.x >= 0:
						_ent("inscription", ins2, i, {"biome": biome_id, "idx": 1})
			"cofre":
				var pd: Array = p.get("pedestal", [])
				var at2 := Vector2i(int(pd[0]), int(pd[1])) if pd.size() == 2 else _center_spot(p, spots)
				if at2.x >= 0 and _standable(at2.x, at2.y):
					if rng.randf() < 0.3:
						_ent("relic", at2, i, {"loot": LevelGenerator.roll_loot(rng, db, int(params.get("tier", 1)) + 1, true, true)}, true)
					else:
						_ent("chest", at2, i, {"loot": LevelGenerator.roll_loot(rng, db, int(params.get("tier", 1)), true)}, true)
			"mirante":
				var tp: Array = p.get("top", [])
				if tp.size() == 2:
					var at3 := Vector2i(int(tp[0]), int(tp[1]))
					if _standable(at3.x, at3.y):
						_ent("inscription", at3, i, {"biome": biome_id, "idx": 2}, true)
						if rng.randf() < 0.6 and _standable(at3.x + 3, at3.y):
							_ent("chest", at3 + Vector2i(3, 0), i, {"loot": LevelGenerator.roll_loot(rng, db, int(params.get("tier", 1)), true)})
			"desafio":
				var far := _far_spot(p, spots)
				if far.x >= 0:
					_ent("chest", far, i, {"loot": LevelGenerator.roll_loot(rng, db, int(params.get("tier", 1)) + 1, true)}, true)
			"fenda":
				var c3 := _center_spot(p, spots)
				if c3.x >= 0:
					_ent("rift", c3, i, {"region": str(p.get("rift", ""))}, true)
			"ninho":
				var far2 := _far_spot(p, spots)
				if far2.x >= 0:
					_ent("chest", far2, i, {"loot": LevelGenerator.roll_loot(rng, db, int(params.get("tier", 1)), false)})
			"passagem", "torre":
				var pt: Dictionary = p["port"]
				var sp := _port_spawn(p, spots)
				p["spawn"] = [sp.x, sp.y]
				if sp.x >= 0:
					anchors_extra.append(sp)
					var txt := str(port_names.get(pt["dir"], "Região vizinha"))
					var ss := _near_spot(spots, sp + Vector2i(3 if pt["dir"] == "L" else -3, 0), 2)
					if ss.x >= 0:
						_ent("sign", ss, i, {"text": txt, "dir": str(pt["dir"])})
				if str(pt.get("requires", "")) != "":
					_port_gate(p)
	# ligações especiais: paredes rachadas, portões de habilidade e alavancas
	for c in conns:
		match str(c["kind"]):
			"secret":
				_secret_wall(c)
			"ability":
				_gate_at(c, "ability_gate", {"kind": "ability", "ability": str(c["data"].get("ability", ""))}, int(c["b"]))
			"lever":
				_lever_shortcut(c)
	# placa no santuário apontando para o objetivo
	if shrine_idx >= 0 and objective_idx >= 0:
		var sp2 := _spots(places[shrine_idx], 3)
		var cp := Vector2i(-1, -1)
		for e in entities:
			if e["type"] == "checkpoint":
				cp = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
		if cp.x >= 0:
			var orr := prect(objective_idx)
			var right: bool = orr.get_center().x > cp.x * 1.0
			var at4 := _near_spot(sp2, cp + Vector2i(4 if right else -4, 0), 3)
			if at4.x >= 0:
				_ent("sign", at4, shrine_idx, {"text": str(places[objective_idx]["name"]), "dir": "R" if right else "L"})


## Marco visual do lugar (estátua, árvore ancestral ou cristal gigante),
## conforme o bioma, no chão largo mais perto do centro.
func _landmark(p: Dictionary, at: Vector2i = Vector2i(-1, -1)) -> void:
	var kind := "statue"
	if biome_id in ["floresta", "pantano", "acampamento_barbaro"]:
		kind = "tree"
	elif biome_id in ["toca_goblin", "cidade_magos", "cidade_ceu"]:
		kind = "crystal"
	if at.x < 0:
		at = _center_spot(p, _spots(p, 3))
	if at.x < 0:
		return
	# fica um pouco atrás do centro (não em cima do chefe/relíquia)
	entities.append({"type": "landmark", "tile": [at.x + (6 if rng.randf() < 0.5 else -6), at.y], "room": int(p["index"]), "data": {"kind": kind}})


func _far_spot(p: Dictionary, spots: Array) -> Vector2i:
	var doors := _door_tiles(p)
	var best := Vector2i(-1, -1)
	var bd := -1
	for s in spots:
		var d := 0
		for dt in doors:
			d += absi(dt.x - s.x) + absi(dt.y - s.y)
		if d > bd:
			bd = d
			best = s
	return best


## Garante um chão no meio do lugar (último recurso).
func _force_floor(p: Dictionary) -> Vector2i:
	var r := prect(int(p["index"]))
	var cx := r.position.x + r.size.x / 2
	var fy := r.end.y - 4
	for x in range(cx - 4, cx + 5):
		gset(x, fy, SOLID)
		for y in range(fy - 4, fy):
			gset(x, y, AIR)
			set_bg(x, y, 1)
	return Vector2i(cx, fy - 1)


## Arco de pedra ao fundo do santuário (parede de fundo em forma de arco).
func _shrine_arch(c: Vector2i) -> void:
	for side in [-1, 1]:
		var px: int = c.x + side * 4
		for y in range(c.y - 6, c.y + 1):
			set_bg(px, y, 1)
	for x in range(c.x - 4, c.x + 5):
		var dy := int(absf(x - c.x) * 0.5)
		set_bg(x, c.y - 7 + dy, 1)
		set_bg(x, c.y - 8 + dy, 1)


func _lair(p: Dictionary, spots: Array) -> void:
	var i: int = int(p["index"])
	var c := _center_spot(p, spots)
	if c.x < 0:
		c = _force_floor(p)
	var boss: String = str(params.get("boss", ""))
	_ent("boss", c, i, {"enemy": boss}, true)
	for d in p["doors"]:
		var cn: Dictionary = conns[int(d["conn"])]
		if not cn.has("x") or int(cn.get("fy", -1)) < 0:
			continue
		var r := prect(i)
		var gx: int = r.position.x + 1 if d["side"] == "L" else r.end.x - 2
		if mode != "enclosed":
			gx = r.position.x + 1 if d["side"] == "L" else r.end.x - 2
		var fy: int = int(cn["fy"])
		_ent("gate", Vector2i(gx, fy - 4), i, {"mode": "combat"})
		var alt := _near_spot(spots, Vector2i(gx + (5 if d["side"] == "L" else -5), fy - 1), 2)
		if alt.x >= 0 and not _has_type_in("altar", i):
			_ent("altar", alt, i)


func _has_type_in(t: String, room: int) -> bool:
	for e in entities:
		if e["type"] == t and int(e["room"]) == room:
			return true
	return false


func _port_spawn(p: Dictionary, spots: Array) -> Vector2i:
	var pt: Dictionary = p["port"]
	var r := prect(int(p["index"]))
	var best := Vector2i(-1, -1)
	var bs := -1e9
	for s in _spots(p, 0):
		var score := 0.0
		match str(pt["dir"]):
			"L": score = -s.x
			"R": score = s.x
			"U": score = -s.y * 3.0 - absf(s.x - r.get_center().x)
			"D": score = s.y * 3.0 - absf(s.x - r.get_center().x)
		if (pt["dir"] == "L" and s.x < 3) or (pt["dir"] == "R" and s.x > w - 4):
			continue
		if score > bs:
			bs = score
			best = s
	return best


func _port_gate(p: Dictionary) -> void:
	var pt: Dictionary = p["port"]
	var r := prect(int(p["index"]))
	var data := {"kind": "ability", "ability": str(pt["requires"])}
	match str(pt["dir"]):
		"L", "R":
			var x := 3 if pt["dir"] == "L" else w - 4
			var fy := -1
			for y in range(r.position.y, r.end.y):
				if _standable(x, y):
					fy = y + 1
					break
			if fy > 0:
				_ent("ability_gate", Vector2i(x, fy - 4), int(p["index"]), data)
		_:
			pass # portões verticais: a própria Level bloqueia pela habilidade


func _gate_at(c: Dictionary, type: String, data: Dictionary, room: int) -> void:
	if not c.has("x") or int(c.get("fy", -1)) < 0:
		return
	var xb: int = c["x"]
	var fy: int = c["fy"]
	var gx := xb if prect(room).position.x == xb else xb - 1
	_ent(type, Vector2i(gx, fy - 4), room, data)


func _secret_wall(c: Dictionary) -> void:
	if not c.has("x") or int(c.get("fy", -1)) < 0:
		return
	var xb: int = c["x"]
	var fy: int = c["fy"]
	for x in [xb - 1, xb]:
		for y in range(fy - 4, fy):
			if gget(x, y) == AIR:
				_ent("breakable", Vector2i(x, y), int(c["b"]))


func _lever_shortcut(c: Dictionary) -> void:
	if not c.has("x") or int(c.get("fy", -1)) < 0:
		return
	var far: int = int(c["data"].get("lever_side", c["b"]))
	var xb: int = c["x"]
	var fy: int = c["fy"]
	var in_far_left: bool = prect(far).position.x < xb
	var gx := xb - 1 if in_far_left else xb
	_ent("gate", Vector2i(gx, fy - 4), far, {"mode": "lever"})
	var spots := _spots(places[far], 1)
	var lv := _near_spot(spots, Vector2i(gx + (-3 if in_far_left else 3), fy - 1), 2)
	if lv.x >= 0:
		_ent("lever", lv, far, {}, true)


# ===========================================================================
# Alcance garantido (ReachMap) — saliências onde faltar
# ===========================================================================

func _rows() -> PackedStringArray:
	var out := PackedStringArray()
	for y in h:
		out.append(g.slice(y * w, y * w + w).get_string_from_ascii())
	return out


func _anchor_tiles() -> Array:
	var out: Array = []
	for p in places:
		for d in _door_tiles(p):
			out.append(d)
	for e in entities:
		if e.get("anchor", false):
			out.append(Vector2i(int(e["tile"][0]), int(e["tile"][1])))
	for a in anchors_extra:
		out.append(a)
	return out


func _ensure_reach() -> void:
	var root_tile := Vector2i(-1, -1)
	for e in entities:
		if e["type"] == "checkpoint":
			root_tile = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
	if root_tile.x < 0:
		return
	var anchors := _anchor_tiles()
	# o chão debaixo de santuário, baús, NPCs... nunca é escavado
	_protected.clear()
	for e in entities:
		if (e.get("anchor", false) or e["type"] in ["spawn", "lever", "sign"]) and not e["type"] in ["gate", "ability_gate", "breakable"]:
			var t := Vector2i(int(e["tile"][0]), int(e["tile"][1]))
			for dx in range(-2, 3):
				_protected[t + Vector2i(dx, 1)] = true
	var rm := ReachMap.new(_rows())
	var tried := {}
	var banned := {}
	var hard := false
	for it in 32:
		rm.build()
		var root := rm.seg_at(root_tile.x, root_tile.y)
		if root < 0:
			return
		var fwd := rm.reach_from(root)
		var bwd := rm.reach_from(root, true)
		var fixes := 0
		var busy: Array = [] ## áreas já mexidas nesta rodada
		for a in anchors:
			if fixes >= 6:
				break
			var s := rm.seg_at(a.x, a.y)
			if s < 0:
				_floor_under(rm, a)
				fixes += 1
				continue
			if fwd[s] == 1 and bwd[s] == 1:
				continue
			if hard:
				# último recurso: liga direto ao trecho alcançado mais perto
				var from_set := fwd if fwd[s] == 0 else rm.reach_from(s)
				var to_set := PackedByteArray()
				to_set.resize(rm.segs.size())
				if fwd[s] == 0:
					to_set[s] = 1
				else:
					to_set = bwd
				var near := _nearest_pair(rm, from_set, to_set)
				if not near.is_empty():
					_bridge(rm, int(near[0]), int(near[1]), 2, true)
					fixes += 1
				continue
			var pair: Array = []
			if fwd[s] == 0:
				pair = rm.best_bridge(fwd, rm.reach_from(s, true), banned)
			elif bwd[s] == 0:
				pair = rm.best_bridge(rm.reach_from(s), bwd, banned)
			if pair.is_empty():
				continue
			var sa: Array = rm.segs[int(pair[0])]
			var key := rm.pair_key(int(pair[0]), int(pair[1]))
			var n_try: int = int(tried.get(key, 0))
			tried[key] = n_try + 1
			if n_try >= 3:
				banned[key] = true # essa ponte não resolve: tenta outro par
				continue
			var mid := Vector2(int(sa[0]), int(sa[2]))
			var clash := false
			for bz in busy:
				if (bz as Vector2).distance_to(mid) < 10.0:
					clash = true
			if clash:
				continue
			busy.append(mid)
			_bridge(rm, int(pair[0]), int(pair[1]), 1 + mini(n_try, 2), n_try >= 2)
			fixes += 1
		if fixes == 0:
			if hard:
				return
			hard = true


## Par (a em `from_set`, b em `to_set`) de trechos mais próximos em linha reta.
func _nearest_pair(rm: ReachMap, from_set: PackedByteArray, to_set: PackedByteArray) -> Array:
	var best: Array = []
	var bd := 1e9
	for i in rm.segs.size():
		if from_set[i] == 0:
			continue
		var a: Array = rm.segs[i]
		for j in rm.segs.size():
			if to_set[j] == 0 or j == i:
				continue
			var b: Array = rm.segs[j]
			var dx := 0.0
			if int(b[0]) > int(a[1]):
				dx = int(b[0]) - int(a[1])
			elif int(a[0]) > int(b[1]):
				dx = int(a[0]) - int(b[1])
			var dy := float(int(a[2]) - int(b[2]))
			var d := dx * dx + dy * dy * (1.5 if dy > 0 else 0.6)
			if d < bd:
				bd = d
				best = [i, j]
	return best


var _protected := {}


func _put(rm: ReachMap, x: int, y: int, c: int) -> void:
	if x < 2 or x >= w - 2 or y < 1 or y >= h - 1:
		return
	if _protected.has(Vector2i(x, y)) and c == AIR:
		return
	gset(x, y, c)
	rm.set_cell(x, y, ReachMap.code(c))
	if c == AIR and bgm[y * w + x] == 0 and mode == "enclosed":
		set_bg(x, y, 1)


func _floor_under(rm: ReachMap, a: Vector2i) -> void:
	for x in range(a.x - 1, a.x + 2):
		if gget(x, a.y + 1) == AIR:
			_put(rm, x, a.y + 1, ONE_WAY)
		for y in [a.y, a.y - 1]:
			if gget(x, y) == SOLID:
				_put(rm, x, y, AIR)


## Liga o trecho `sa` (alcançado) ao `sb` com saliências a cada <=3 tiles de
## subida / <=4 de distância, abrindo espaço (rocha vira ar) no corredor
## entre um ponto e o próximo — inclusive o chão, se o alvo estiver embaixo.
func _bridge(rm: ReachMap, sa: int, sb: int, wide: int = 1, safe: bool = false) -> void:
	var a: Array = rm.segs[sa]
	var b: Array = rm.segs[sb]
	var bcx: int = (int(b[0]) + int(b[1])) / 2
	var pa := Vector2i(clampi(bcx, int(a[0]), int(a[1])), int(a[2]))
	var pb := Vector2i(clampi(pa.x, int(b[0]), int(b[1])), int(b[2]))
	var rise := pa.y - pb.y
	var gap := absi(pb.x - pa.x)
	var n := maxi(maxi(ceili(float(rise) / 3.0), ceili(float(gap) / 4.0)), 1)
	var pts: Array = []
	for i in range(0, n + 1):
		var t := float(i) / float(n)
		pts.append(Vector2i(int(roundf(lerpf(pa.x, pb.x, t))), int(roundf(lerpf(pa.y, pb.y, t)))))
	for i in range(0, n):
		var p0: Vector2i = pts[i]
		var p1: Vector2i = pts[i + 1]
		var top := mini(p0.y, p1.y) - 3
		var bot := maxi(p0.y, p1.y)
		for yy in range(top, bot + 1):
			for xx in range(mini(p0.x, p1.x) - wide, maxi(p0.x, p1.x) + wide + 1):
				var c := gget(xx, yy)
				if c == SOLID or c == SPIKE:
					_put(rm, xx, yy, AIR)
	var vertical := gap < rise and not safe
	for i in range(1, n):
		var q: Vector2i = pts[i]
		if vertical:
			q.x += -2 if i % 2 == 0 else 2 # zigue-zague: um degrau não tapa o outro
			for yy in range(q.y - 3, q.y + 1):
				for xx in range(q.x - 1, q.x + 2):
					if gget(xx, yy) == SOLID:
						_put(rm, xx, yy, AIR)
		var mat := ONE_WAY if built or not vertical else SOLID
		for xx in range(q.x - 1, q.x + 2):
			if gget(xx, q.y + 1) != SOLID:
				_put(rm, xx, q.y + 1, mat)
	# o destino precisa de chão firme (a limpeza pode ter aberto)
	for xx in range(pb.x - 1, pb.x + 2):
		if gget(xx, pb.y + 1) == AIR:
			_put(rm, xx, pb.y + 1, ONE_WAY)


# ===========================================================================
# Ecossistema: criaturas por lugar + luzes e detalhes
# ===========================================================================

func _finish_entities() -> void:
	var tier: int = int(params.get("tier", 1))
	for p in places:
		var i: int = int(p["index"])
		var kind: String = p["kind"]
		var spots := _spots(p, 7)
		var n_ground := 0
		var n_fly := 0
		var n_ranged := 0
		var nest := false
		match kind:
			"trilha", "galeria":
				n_ground = int(p["cells"][0]) / 2 + (1 if tier >= 2 else 0) + rng.randi_range(0, 1)
				n_fly = 1 if rng.randf() < 0.3 else 0
			"gruta":
				n_ground = rng.randi_range(0, 1)
			"poco", "torre":
				n_fly = rng.randi_range(1, 2)
			"salao":
				n_ground = rng.randi_range(1, 2)
				n_ranged = 1
				n_fly = rng.randi_range(0, 1)
			"coracao":
				n_ground = 2
				n_fly = 1
				n_ranged = 1 if tier >= 2 else 0
			"abismo":
				n_fly = rng.randi_range(1, 2)
			"lago":
				n_ground = 1
				n_fly = rng.randi_range(0, 1)
			"ninho":
				nest = true
				n_ground = 3 + (1 if tier >= 2 else 0) + int(p["cells"][0]) - 1
				n_fly = 1 if tier >= 2 else 0
			"cofre":
				n_ground = 1 if rng.randf() < 0.35 else 0
			"passagem":
				n_ground = 1 if rng.randf() < 0.4 else 0
		RngUtil.shuffle(rng, spots)
		# patrulhas: espalhadas (longe umas das outras)
		var placed: Array = []
		for k in n_ground:
			var id: String = _nest_species() if nest and k < 3 else RngUtil.weighted_key(rng, pool["ground"])
			var s := _spread_spot(spots, placed, 7)
			if s.x < 0:
				break
			_ent("enemy", s, i, {"enemy": id})
			placed.append(s)
		# atiradores: no ponto mais alto
		for k in n_ranged:
			var hi := Vector2i(-1, -1)
			for s2 in spots:
				if _used.has(s2):
					continue
				if hi.x < 0 or s2.y < hi.y:
					hi = s2
			if hi.x >= 0:
				_ent("enemy", hi, i, {"enemy": RngUtil.weighted_key(rng, pool["ranged"])})
				placed.append(hi)
		# voadores: no ar aberto
		for k in n_fly:
			var a := _air_spot(p, placed)
			if a.x >= 0:
				_ent("flyer", a, i, {"enemy": RngUtil.weighted_key(rng, pool["flying"])})
				placed.append(a)
		# ninho trancado (portas só laterais) vira arena com ondas
		if nest:
			var only_lr := true
			for d in p["doors"]:
				if not conns[int(d["conn"])].has("x"):
					only_lr = false
			if only_lr and p["doors"].size() <= 2:
				p["type"] = "arena"
				for d in p["doors"]:
					var cn: Dictionary = conns[int(d["conn"])]
					if int(cn.get("fy", -1)) < 0:
						continue
					var r := prect(i)
					var gx: int = r.position.x + 1 if d["side"] == "L" else r.end.x - 2
					# o túnel atravessa a margem: portão logo na borda interna
					if gget(gx, int(cn["fy"]) - 1) != AIR:
						gx = int(cn["x"]) if d["side"] == "L" else int(cn["x"]) - 1
					_ent("gate", Vector2i(gx, int(cn["fy"]) - 4), i, {"mode": "combat"})
			else:
				p["type"] = "combat"
		# lanternas de Ímpeto nos espaços verticais / abismos
		if kind in ["poco", "torre", "abismo"]:
			var cnt := 0
			for k2 in 4:
				var a2 := _air_spot(p, placed)
				if a2.x >= 0 and cnt < 2:
					_ent("impeto_orb", a2, i)
					placed.append(a2)
					cnt += 1
		# tochas nos lugares fechados (luz para as pedras refletirem)
		if (mode == "enclosed" or pcell(i).position.y > gr) and not kind in ["santuario", "vila"]:
			var tn := int(p["cells"][0]) * int(p["cells"][1]) + 1
			for k3 in tn:
				var s3 := _wall_spot(p)
				if s3.x >= 0:
					_ent("torch", s3, i)
	# luz do céu entrando nas cavernas logo abaixo da superfície
	if mode == "surface":
		for c in conns:
			if c.has("top") and int(c.get("top", 0)) <= ground_base + 4:
				_ent("light_shaft", Vector2i(int(c["dx"]) + 1, int(c["top"]) + 1), int(c["b"]))


func _spread_spot(spots: Array, placed: Array, min_d: int) -> Vector2i:
	for s in spots:
		if _used.has(s):
			continue
		var ok := true
		for q in placed:
			if absi(q.x - s.x) + absi(q.y - s.y) < min_d:
				ok = false
				break
		if ok:
			return s
	return Vector2i(-1, -1)


func _air_spot(p: Dictionary, placed: Array) -> Vector2i:
	var r := prect(int(p["index"]))
	var doors := _door_tiles(p)
	for attempt in 40:
		var x := rng.randi_range(r.position.x + 3, r.end.x - 4)
		var y := rng.randi_range(maxi(r.position.y + 2, 2), r.end.y - 4)
		var ok := true
		for yy in range(y - 1, y + 2):
			for xx in range(x - 1, x + 2):
				if gget(xx, yy) != AIR:
					ok = false
		if not ok or _used.has(Vector2i(x, y)):
			continue
		for d in doors:
			if absi(d.x - x) + absi(d.y - y) < 7:
				ok = false
		for q in placed:
			if absi(q.x - x) + absi(q.y - y) < 5:
				ok = false
		if ok:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## Tile de ar encostado numa parede, na altura da cabeça (tochas).
func _wall_spot(p: Dictionary) -> Vector2i:
	var r := prect(int(p["index"]))
	for attempt in 30:
		var x := rng.randi_range(r.position.x + 2, r.end.x - 3)
		var y := rng.randi_range(r.position.y + 2, r.end.y - 3)
		if gget(x, y) != AIR or _used.has(Vector2i(x, y)):
			continue
		var wall := gget(x - 1, y) == SOLID or gget(x + 1, y) == SOLID
		var floor_near := gget(x, y + 2) == SOLID or gget(x, y + 3) == SOLID or gget(x, y + 4) == SOLID
		if wall and floor_near and gget(x, y + 1) == AIR:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


# ===========================================================================
# Saída
# ===========================================================================

func _output(seed_value: int) -> Dictionary:
	var rows := _rows()
	var bg_rows := PackedStringArray()
	for y in h:
		var line := PackedByteArray()
		line.resize(w)
		for x in w:
			line[x] = 48 + bgm[y * w + x]
		bg_rows.append(line.get_string_from_ascii())
	var spawn := Vector2i(-1, -1)
	for e in entities:
		if e["type"] == "spawn":
			spawn = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
	var ports_out: Array = []
	for p in places:
		var pt: Dictionary = p.get("port", {})
		if pt.is_empty():
			continue
		ports_out.append({"dir": pt["dir"], "to": pt["to"], "requires": pt.get("requires", ""),
			"room": p["index"], "origin": p["origin"], "spawn": p.get("spawn", [-1, -1])})
	# dono de cada célula macro (o céu acima do chão pertence ao lugar de baixo)
	var owner_out: Array = []
	for y in gh:
		for x in gw:
			var o := cell_owner[y * gw + x]
			if o < 0 and mode != "enclosed" and y < gr:
				o = cell_owner[gr * gw + x]
			owner_out.append(o)
	var rooms: Array = []
	for p in places:
		var q: Dictionary = p.duplicate()
		q.erase("doors")
		q["template"] = "region:" + str(p["kind"])
		rooms.append(q)
	var boss: String = str(params.get("boss", ""))
	var obj := {}
	if objective_idx >= 0:
		var on: String = places[objective_idx]["name"]
		if boss != "":
			obj = {"kind": "boss", "room": objective_idx, "text": "Derrote %s no %s" % [str(db.enemy(boss).get("name", "guardião")), on]}
		else:
			obj = {"kind": "heart", "room": objective_idx, "text": "Encontre a relíquia do %s" % on}
	return {
		"seed": seed_value,
		"biome": biome_id,
		"tier": int(params.get("tier", 1)),
		"width": w,
		"height": h,
		"rows": rows,
		"bg": bg_rows,
		"rooms": rooms,
		"path": [],
		"entities": entities,
		"spawn": [spawn.x, spawn.y],
		"exit": [spawn.x, spawn.y],
		"key_placed": true,
		"indoor": mode == "enclosed",
		"sky_rooms": [],
		"ports": ports_out,
		"water": water,
		"macro": {"cw": CW, "ch": CH, "gw": gw, "gh": gh, "owner": owner_out},
		"objective": obj,
		"mode": mode,
	}
