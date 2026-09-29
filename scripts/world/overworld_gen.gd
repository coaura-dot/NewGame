class_name OverworldGen
extends RefCounted
## Gera o MAPA-MÚNDI explorável (visão de cima, tiles de 8 px) a partir do
## grafo de regiões de Game.world — sempre o mesmo mapa para o mesmo save.
##
## Cada região vira um TERRITÓRIO (Voronoi com ruído em volta da posição da
## região) com o chão do seu bioma. Entre territórios há uma divisa
## intransponível (mata fechada, rochedo ou o vazio do céu) e as ESTRADAS do
## grafo cortam essas divisas: estrada de terra, ponte de luz (céu), trilho
## de túnel (subterrâneo) ou cristais (fenda dimensional). Estradas que
## exigem habilidade ganham um PORTÃO rúnico na divisa.
##
## No centro de cada território fica a ENTRADA da fase (portão de pedra,
## caverna, plataforma celeste ou fenda); regiões com hub ganham uma vila
## (praça, casas, poço, postes, NPCs) e a vila inicial tem a Grande Lareira.
## Em volta do mapa: mar com praia.
##
## Resultado (Dictionary):
##   w, h                  tamanho em células
##   ground                PackedByteArray: índice em MATS por célula
##   owner                 PackedInt32Array: índice da região dona (-1 = nenhuma)
##   region_ids            Array[String] (índice -> id)
##   sites                 {id: Vector2i} centro de cada território
##   entrances             {id: Vector2i} célula dos pés da entrada da fase
##   objects               Array de {"name", "cell", "off"(Vector2 px), "region"}
##   gates                 Array de {"cell", "requires", "a", "b", "cells"}
##   signs                 Array de {"cell", "text", "region"}
##   villages              {id: {"center", "npc_cells"}}
##   spawn                 Vector2i (vila inicial)

const UNIT := 2.5 ## células por unidade do mapa-mundi
const MARGIN := 18 ## células de mar em volta
const ISLAND_R := 44.0 ## raio (células) da terra em volta de cada região
const BORDER := 3.4 ## espessura da divisa entre territórios (diferença de distância)
const SKY_BORDER := 5.6
const ROAD_LAMP_GAP := 13 ## distância mínima (células) entre lamparinas de estrada

const MATS := [
	"grass", "grass_dark", "sand", "gold_sand", "cobble", "ruin", "swamp", "red_dirt", "snow", "cloud",
	"cave", "arcane", "moss_cave", "plaza", "forest_floor", "bridge_h", "bridge_v", "deep_water",
	"sky_road", "tunnel", "rift", "rock_wall", "sky_void", "road", "water",
]
const SOLID := ["deep_water", "rock_wall", "sky_void", "forest_floor", "water"]

## bioma -> [chão de fora, chão do centro]
const BIOME_GROUND := {
	"cemiterio": ["grass_dark", "grass_dark"], "castelo": ["grass_dark", "cobble"], "catacumbas": ["cave", "cave"],
	"cidade_gotica": ["grass", "cobble"], "templo_dourado": ["sand", "gold_sand"], "ruinas": ["grass", "ruin"],
	"floresta": ["grass", "grass"], "deserto": ["sand", "sand"], "pantano": ["swamp", "swamp"],
	"cidade_ceu": ["cloud", "cloud"], "cidade_subterranea": ["cave", "cave"], "cidade_magos": ["arcane", "arcane"],
	"fortaleza_orc": ["red_dirt", "red_dirt"], "acampamento_barbaro": ["snow", "snow"], "toca_goblin": ["moss_cave", "moss_cave"],
}
## bioma -> objetos espalhados [nome, peso] e densidade
const BIOME_PROPS := {
	"floresta": [[["tree_oak", 6], ["tree_oak_fruit", 1], ["tree_oak_autumn", 1], ["bush", 2], ["bush_berry", 1], ["rock_small", 1], ["flowers_pink", 2], ["flowers_yellow", 2]], 0.07],
	"cemiterio": [[["tree_dead", 3], ["tree_dark", 2], ["gravestone", 3], ["grave_cross", 2], ["rock_small", 1]], 0.05],
	"castelo": [[["tree_dark", 3], ["rock_big", 1], ["column_broken", 1], ["bush", 2]], 0.04],
	"catacumbas": [[["stalagmite", 3], ["rock_big", 2], ["gravestone", 1], ["mushroom_blue", 1]], 0.04],
	"cidade_gotica": [[["tree_dark", 3], ["bush", 2], ["rock_small", 1], ["flowers_blue", 1]], 0.04],
	"templo_dourado": [[["column_gold", 2], ["tree_palm", 2], ["cactus", 1], ["rock_sand", 1]], 0.035],
	"ruinas": [[["column_ruin", 3], ["tree_oak", 3], ["bush", 2], ["rock_big", 1], ["flowers_yellow", 1]], 0.05],
	"deserto": [[["cactus", 3], ["tree_palm", 1], ["rock_sand", 2], ["bush_dry", 1]], 0.03],
	"pantano": [[["tree_swamp", 4], ["tree_dead", 1], ["reeds", 4], ["mushroom_red", 1]], 0.06],
	"cidade_ceu": [[["cloud_puff", 4], ["column_gold", 1], ["tree_gold", 1]], 0.03],
	"cidade_subterranea": [[["stalagmite", 2], ["mushroom_blue", 2], ["tree_crystal", 1], ["rock_big", 1]], 0.045],
	"cidade_magos": [[["tree_crystal", 3], ["tree_dark", 1], ["flowers_blue", 2], ["rock_small", 1]], 0.05],
	"fortaleza_orc": [[["palisade", 2], ["rock_big", 2], ["tree_dead", 1], ["tent_red", 1]], 0.035],
	"acampamento_barbaro": [[["tree_pine_snow", 5], ["rock_snow", 2], ["tent", 1]], 0.06],
	"toca_goblin": [[["mushroom_red", 2], ["mushroom_blue", 1], ["stalagmite", 2], ["rock_big", 1]], 0.05],
}
## árvore da mata fechada da divisa (superfície); "" = rochedo
const BORDER_TREE := {
	"floresta": ["tree_oak", "tree_dark"], "cemiterio": ["tree_dead", "tree_dark"], "castelo": ["tree_dark"],
	"cidade_gotica": ["tree_dark", "tree_oak"], "ruinas": ["tree_oak", "tree_dark"], "pantano": ["tree_swamp", "tree_dead"],
	"cidade_magos": ["tree_crystal", "tree_dark"], "acampamento_barbaro": ["tree_pine_snow"],
}
const HOUSE_BY_HUB := {"vila": "house_wood", "cidade": "house_stone", "templo": "house_sand"}

static var _cache: Dictionary = {}


static func mat(name: String) -> int:
	return MATS.find(name)


## Mapa para o mundo atual (cacheado por seed + forma do mundo).
static func for_world(world: Dictionary) -> Dictionary:
	var key := "%s:%d" % [str(world.get("seed", 0)), world.get("regions", {}).size()]
	if not _cache.has(key):
		_cache.clear()
		_cache[key] = generate(world)
	return _cache[key]


static func generate(world: Dictionary) -> Dictionary:
	var seed_value := int(world.get("seed", 0))
	var rng := RngUtil.make(seed_value, "overworld")
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var noise2 := FastNoiseLite.new()
	noise2.seed = seed_value + 77
	noise2.frequency = 0.09
	var regions: Dictionary = world["regions"]
	var ids: Array = regions.keys()
	ids.sort()
	# --- 1) posições em células ---
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for id in ids:
		var p := _wpos(regions[id])
		minp = minp.min(p)
		maxp = maxp.max(p)
	var off := -minp * UNIT + Vector2(MARGIN + ISLAND_R * 0.75, MARGIN + ISLAND_R * 0.75)
	var w := int(ceil((maxp.x - minp.x) * UNIT + (MARGIN + ISLAND_R * 0.75) * 2.0))
	var h := int(ceil((maxp.y - minp.y) * UNIT + (MARGIN + ISLAND_R * 0.75) * 2.0))
	var sites := {}
	var site_list: Array = [] ## [Vector2 célula, índice, peso]
	for i in ids.size():
		var id: String = ids[i]
		var c := (_wpos(regions[id]) * UNIT + off).round()
		sites[id] = Vector2i(c)
		var weight := 2.3 if str(regions[id].get("dimension", "prima")) != "prima" else 1.0
		site_list.append([c, i, weight])
	# --- 2) territórios (Voronoi com ruído) ---
	var n := w * h
	var owner := PackedInt32Array()
	owner.resize(n)
	var border := PackedFloat32Array() ## diferença 2º - 1º mais perto (pequena = divisa)
	border.resize(n)
	var dist1 := PackedFloat32Array()
	dist1.resize(n)
	for y in h:
		for x in w:
			# o ruído some perto dos centros: todo centro fica dentro da própria
			# região (fendas dimensionais têm território pequeno)
			var raw := INF
			for s in site_list:
				raw = minf(raw, Vector2(x, y).distance_to(s[0]) * float(s[2]))
			var amp := 9.0 * clampf((raw - 5.0) / 16.0, 0.0, 1.0)
			var jx := noise.get_noise_2d(x, y) * amp
			var jy := noise.get_noise_2d(x + 500, y + 500) * amp
			var q := Vector2(x + jx, y + jy)
			var b1 := INF
			var b2 := INF
			var bi := -1
			for s in site_list:
				var d: float = q.distance_to(s[0]) * float(s[2])
				if d < b1:
					b2 = b1
					b1 = d
					bi = int(s[1])
				elif d < b2:
					b2 = d
			var k := y * w + x
			var reach := ISLAND_R + noise2.get_noise_2d(x, y) * 10.0
			owner[k] = bi if b1 <= reach else -1
			border[k] = b2 - b1
			dist1[k] = b1
	# --- 3) chão ---
	var ground := PackedByteArray()
	ground.resize(n)
	var m_sand := mat("sand")
	var m_deep := mat("deep_water")
	for k in n:
		var oi := owner[k]
		if oi < 0:
			ground[k] = m_deep
			continue
		var r: Dictionary = regions[ids[oi]]
		var gpair: Array = BIOME_GROUND.get(r["biome"], ["grass", "grass"])
		var inner := dist1[k] < 12.0
		var gname: String = gpair[1] if inner else gpair[0]
		if str(r.get("dimension", "prima")) != "prima":
			gname = "rift" if dist1[k] < 7.0 else gpair[0]
		ground[k] = mat(gname)
	# praia: terra de superfície encostada no mar
	for y in h:
		for x in w:
			var k := y * w + x
			if ground[k] == m_deep or owner[k] < 0:
				continue
			var layer: String = regions[ids[owner[k]]]["layer"]
			if layer != "surface":
				continue
			if _near_mat(ground, w, h, x, y, m_deep, 2):
				ground[k] = m_sand
	# divisas entre territórios
	var region_border_mat := {}
	for i in ids.size():
		var r: Dictionary = regions[ids[i]]
		if r["layer"] == "sky":
			region_border_mat[i] = "sky_void"
		elif r["layer"] == "underground" or not BORDER_TREE.has(r["biome"]):
			region_border_mat[i] = "rock_wall"
		else:
			region_border_mat[i] = "forest_floor"
	var border_cells: Array = []
	for y in h:
		for x in w:
			var k := y * w + x
			var oi := owner[k]
			if oi < 0:
				continue
			var thick := BORDER
			var mat_name: String = region_border_mat[oi]
			# céu tem vão largo; o vizinho decide se é céu
			if mat_name == "sky_void":
				thick = SKY_BORDER
			if border[k] < thick:
				ground[k] = mat(mat_name)
				border_cells.append(Vector2i(x, y))
			# a borda do mar em regiões do céu é vazio (ilha flutuante)
			elif regions[ids[oi]]["layer"] == "sky" and _near_owner(owner, w, h, x, y, -1, 3):
				ground[k] = mat("sky_void")
	# selagem: nenhuma célula andável encosta (em cruz) numa andável de outra
	# região — sem vão diagonal na divisa
	var solid_ids := {}
	for sn in SOLID:
		solid_ids[mat(sn)] = true
	var seal: Array = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var k := y * w + x
			var oi := owner[k]
			if oi < 0 or solid_ids.has(int(ground[k])):
				continue
			for dk in [-1, 1, -w, w]:
				var o2 := owner[k + dk]
				if o2 >= 0 and o2 != oi and not solid_ids.has(int(ground[k + dk])):
					seal.append(k)
					break
	for k in seal:
		ground[k] = mat(region_border_mat[owner[k]])
		border_cells.append(Vector2i(k % w, k / w))
	var is_border := PackedByteArray()
	is_border.resize(n)
	for c in border_cells:
		is_border[c.y * w + c.x] = 1
	# --- 4) lagoinhas no pântano ---
	var m_water := mat("water")
	for y in h:
		for x in w:
			var k := y * w + x
			if owner[k] < 0 or regions[ids[owner[k]]]["biome"] != "pantano":
				continue
			if dist1[k] > 10.0 and border[k] > BORDER + 3.0 and noise2.get_noise_2d(x * 1.7, y * 1.7) > 0.35:
				ground[k] = m_water
	# --- 5) vilas: praça no centro ---
	var villages := {}
	var start_id: String = world.get("start", "")
	for id in ids:
		var r: Dictionary = regions[id]
		if str(r.get("hub", "")) == "":
			continue
		var c: Vector2i = sites[id]
		var own: int = owner[c.y * w + c.x]
		for dy in range(-6, 7):
			for dx in range(-7, 8):
				var px := c.x + dx
				var py := c.y + dy
				if px < 0 or py < 0 or px >= w or py >= h:
					continue
				var pk := py * w + px
				if owner[pk] != own or is_border[pk] == 1 or solid_ids.has(int(ground[pk])):
					continue
				if Vector2(dx, dy * 1.15).length() <= 6.2 + noise2.get_noise_2d(px, py) * 1.2:
					ground[pk] = mat("plaza")
		villages[id] = {"center": c, "npc_cells": []}
	# --- 6) estradas ---
	var road_cells := {} ## Vector2i -> tipo
	var road_use := {} ## Vector2i -> {requisito: true} (quais estradas passam ali)
	var gates: Array = []
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	var idx_of := {}
	for i in ids.size():
		idx_of[ids[i]] = i
	var edges: Array = world["edges"].duplicate()
	edges.sort_custom(func(a, b): return str(a["a"]) + str(a["b"]) < str(b["a"]) + str(b["b"]))
	for e in edges:
		var ia: int = idx_of[e["a"]]
		var ib: int = idx_of[e["b"]]
		var from: Vector2i = sites[e["a"]]
		var to: Vector2i = sites[e["b"]]
		var box := Rect2i(from, Vector2i.ONE).expand(to + Vector2i.ONE).grow(16).intersection(Rect2i(0, 0, w, h))
		# o A* fica preso na caixa da aresta (fora dela não há pesos)
		astar.region = box
		astar.update()
		var path: Array = []
		for attempt in 2:
			if attempt == 1:
				astar.update()
			for y in range(box.position.y, box.end.y):
				for x in range(box.position.x, box.end.x):
					var k := y * w + x
					var oi := owner[k]
					var wgt := 1.0 + (noise.get_noise_2d(x * 2.0, y * 2.0) + 1.0) * 1.5
					if oi != ia and oi != ib:
						# 1ª tentativa: só pelas duas regiões; 2ª: evita as outras
						if attempt == 0 or oi < 0:
							astar.set_point_solid(Vector2i(x, y), true)
							continue
						wgt = 40.0
					elif is_border[k] == 1:
						wgt = 9.0 # atravessa a divisa reto (portão cobre tudo)
					elif road_cells.has(Vector2i(x, y)):
						wgt = 0.6
					astar.set_point_weight_scale(Vector2i(x, y), wgt)
			path = astar.get_id_path(from, to)
			if not path.is_empty():
				break
		if path.is_empty():
			continue
		var kind: String = e["kind"]
		for pc in path:
			for t in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var uc: Vector2i = pc + t
				if uc.x < 0 or uc.y < 0 or uc.x >= w or uc.y >= h:
					continue
				if t != Vector2i.ZERO and owner[uc.y * w + uc.x] != ia and owner[uc.y * w + uc.x] != ib:
					continue
				if not road_use.has(uc):
					road_use[uc] = {}
				road_use[uc][str(e["requires"])] = true
		var gate_done := false
		var prev_owner := ia
		for pi in path.size():
			var cell: Vector2i = path[pi]
			var k := cell.y * w + cell.x
			# portão rúnico: onde a estrada atravessa a divisa para o outro território
			if e["requires"] != "" and not gate_done and owner[k] != prev_owner and owner[k] >= 0 and prev_owner >= 0:
				gate_done = true
				gates.append({"cell": cell, "requires": e["requires"], "a": e["a"], "b": e["b"], "cells": [], "kind": kind, "path": path})
			if owner[k] >= 0:
				prev_owner = owner[k]
			for t in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var cc: Vector2i = cell + t
				if cc.x < 0 or cc.y < 0 or cc.x >= w or cc.y >= h:
					continue
				# a largura extra nunca invade região de fora da aresta
				var oc := owner[cc.y * w + cc.x]
				if t != Vector2i.ZERO and oc != ia and oc != ib:
					continue
				if not road_cells.has(cc):
					road_cells[cc] = kind
	# células bloqueadas pelos portões: toda estrada desta aresta que passa na
	# divisa (e vizinhas), mais o miolo em volta do cruzamento
	for g in gates:
		var gset := {}
		for pc in g["path"]:
			for t in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var cc: Vector2i = pc + t
				if cc.x < 1 or cc.y < 1 or cc.x >= w - 1 or cc.y >= h - 1:
					continue
				var near_band := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if is_border[(cc.y + dy) * w + cc.x + dx] == 1:
							near_band = true
				# não fecha trecho usado por estrada livre (ou de outro requisito)
				var uses: Dictionary = road_use.get(cc, {})
				if uses.size() > 1 or not uses.has(str(g["requires"])):
					continue
				if near_band or Vector2(cc - g["cell"]).length() <= 2.5:
					gset[cc] = true
		g["cells"] = gset.keys()
		g.erase("path")
	# pinta as estradas
	for cell in road_cells.keys():
		var k: int = cell.y * w + cell.x
		var kind: String = road_cells[cell]
		var cur := MATS[ground[k]] as String
		if cur == "plaza":
			continue
		var over_water := cur in ["water", "deep_water"]
		match kind:
			"sky_bridge":
				ground[k] = mat("sky_road") if cur in ["sky_void", "deep_water", "water"] or regions[ids[maxi(owner[k], 0)]]["layer"] == "sky" else mat("road")
			"tunnel":
				ground[k] = mat("tunnel") if cur in ["rock_wall", "cave", "moss_cave"] or regions[ids[maxi(owner[k], 0)]]["layer"] == "underground" else mat("road")
			"rift":
				ground[k] = mat("rift")
			_:
				ground[k] = mat("road")
		if over_water and kind in ["road", "tunnel"]:
			# ponte na direção da estrada
			var horiz := road_cells.has(cell + Vector2i(1, 0)) and road_cells.has(cell + Vector2i(-1, 0))
			ground[k] = mat("bridge_h" if horiz else "bridge_v")
	# 2ª selagem: estrada que corre colada numa divisa não pode encostar em chão
	# andável de outra região (fecha o lado que não é estrada)
	for cell in road_cells.keys():
		var ok := owner[cell.y * w + cell.x]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = cell + d
			if nc.x < 0 or nc.y < 0 or nc.x >= w or nc.y >= h or road_cells.has(nc):
				continue
			var nk := nc.y * w + nc.x
			var on := owner[nk]
			if on >= 0 and on != ok and ok >= 0 and not solid_ids.has(int(ground[nk])):
				ground[nk] = mat(region_border_mat[on])
	# --- 7) objetos ---
	var occ := {} ## células ocupadas por objetos
	var objects: Array = []
	var signs: Array = []
	var entrances := {}
	for id in ids:
		var r: Dictionary = regions[id]
		var c: Vector2i = sites[id]
		var hub := str(r.get("hub", "")) != ""
		var ent_cell := c + Vector2i(0, -9 if hub else -3)
		var ent_name := "entrance_gate"
		if str(r.get("dimension", "prima")) != "prima":
			ent_name = "entrance_rift"
		elif r["layer"] == "underground":
			ent_name = "entrance_cave"
		elif r["layer"] == "sky":
			ent_name = "entrance_sky"
		entrances[id] = ent_cell + Vector2i(0, 1)
		objects.append({"name": ent_name, "cell": ent_cell, "region": id, "kind": "entrance"})
		_occupy(occ, ent_cell, 4, 4)
		# caminho da entrada até o centro
		var own_r: int = owner[c.y * w + c.x]
		for yy in range(ent_cell.y, c.y + 1):
			for xx in [c.x, c.x + 1]:
				var k: int = yy * w + xx
				if owner[k] != own_r or is_border[k] == 1:
					continue
				if MATS[ground[k]] != "plaza":
					ground[k] = mat("road") if r["layer"] != "sky" else mat("sky_road")
		# pedra de viagem ao lado da entrada
		objects.append({"name": "waystone", "cell": ent_cell + Vector2i(4, 1), "region": id, "kind": "waystone"})
		_occupy(occ, ent_cell + Vector2i(4, 1), 1, 1)
		if r.get("boss", "") != "":
			objects.append({"name": "banner_boss", "cell": ent_cell + Vector2i(-4, 1), "region": id, "kind": "banner"})
			_occupy(occ, ent_cell + Vector2i(-4, 1), 1, 1)
		if hub:
			_village(objects, occ, ground, w, h, rng, id, r, c, road_cells, villages, id == start_id)
		# placa na estrada de saída para cada vizinho
		for nb in WorldGenerator.neighbors(world, id):
			var target: Vector2i = sites[nb["id"]]
			var dir := Vector2(target - c).normalized()
			var at := Vector2i((Vector2(c) + dir * (11.0 if hub else 7.0)).round())
			var best := at
			for tries in 12:
				var cand := at + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
				if _free(occ, road_cells, ground, w, h, cand) and _near_road(road_cells, cand, 2):
					best = cand
					break
			if _free(occ, road_cells, ground, w, h, best):
				signs.append({"cell": best, "region": id, "to": nb["id"]})
				objects.append({"name": "signpost", "cell": best, "region": id, "kind": "sign", "to": nb["id"]})
				_occupy(occ, best, 1, 1)
	# lamparinas dos Veladores ao longo das estradas (o Pavio acende ao passar;
	# ficam acesas para sempre). Sem RNG: posição fixa pela própria estrada.
	var road_lamps: Array = []
	var lamp_cells: Array = []
	var road_keys: Array = road_cells.keys()
	road_keys.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for rc in road_keys:
		if str(road_cells[rc]) != "road" or (rc.x * 7 + rc.y * 13) % 5 != 0:
			continue
		var too_close := false
		for lc in lamp_cells:
			if (lc as Vector2i).distance_squared_to(rc) < ROAD_LAMP_GAP * ROAD_LAMP_GAP:
				too_close = true
				break
		if too_close:
			continue
		for vid in villages.keys():
			if Vector2(villages[vid]["center"]).distance_to(Vector2(rc)) < 12.0:
				too_close = true
		if too_close:
			continue
		for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var lc2: Vector2i = rc + side
			if lc2.x < 2 or lc2.y < 2 or lc2.x >= w - 2 or lc2.y >= h - 2:
				continue
			var gk := lc2.y * w + lc2.x
			var gn := MATS[ground[gk]] as String
			if road_cells.has(lc2) or occ.has(lc2) or gn in SOLID or gn in ["water", "deep_water", "bridge_h", "bridge_v", "sky_void"] or owner[gk] < 0:
				continue
			var lid := "rl_%d_%d" % [lc2.x, lc2.y]
			objects.append({"name": "lamp_post", "cell": lc2, "region": ids[owner[gk]], "kind": "road_lamp", "id": lid, "solid": false})
			_occupy(occ, lc2, 1, 1)
			lamp_cells.append(rc)
			road_lamps.append(lid)
			break
	# mata fechada nas divisas de superfície
	for cell in border_cells:
		var k: int = cell.y * w + cell.x
		if MATS[ground[k]] != "forest_floor":
			continue
		if (cell.x + cell.y * 3) % 2 == 0 and rng.randf() < 0.75:
			var trees: Array = BORDER_TREE.get(regions[ids[owner[k]]]["biome"], ["tree_dark"])
			objects.append({"name": trees[rng.randi_range(0, trees.size() - 1)], "cell": cell, "region": ids[owner[k]], "kind": "deco", "solid": false})
	# objetos do bioma
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			var k := y * w + x
			var oi := owner[k]
			if oi < 0:
				continue
			var r: Dictionary = regions[ids[oi]]
			var spec: Array = BIOME_PROPS.get(r["biome"], BIOME_PROPS["floresta"])
			var dens: float = spec[1]
			# bosques: densidade maior onde o ruído é alto
			var cluster := (noise.get_noise_2d(x * 1.3 + 99, y * 1.3) + 1.0) * 0.5
			if rng.randf() > dens * (0.3 + cluster * 1.6):
				continue
			var cell := Vector2i(x, y)
			if dist1[k] < 9.0 or not _free(occ, road_cells, ground, w, h, cell) or _near_road(road_cells, cell, 2):
				continue
			var gname := MATS[ground[k]] as String
			if gname in SOLID or gname in ["plaza", "road", "sky_road", "tunnel", "rift"]:
				continue
			var pick: String = _weighted(rng, spec[0])
			objects.append({"name": pick, "cell": cell, "region": ids[oi], "kind": "deco"})
			_occupy(occ, cell, 1, 1)
	# chão final: estradas e vilas não ficam em cima de divisa sem passagem
	var spawn: Vector2i = villages.get(start_id, {}).get("center", sites.get(start_id, Vector2i(w / 2, h / 2)))
	return {
		"w": w, "h": h, "ground": ground, "owner": owner, "region_ids": ids, "sites": sites,
		"entrances": entrances, "objects": objects, "gates": gates, "signs": signs,
		"villages": villages, "spawn": spawn + Vector2i(0, 3), "roads": road_cells, "road_lamps": road_lamps,
	}


static func _wpos(r: Dictionary) -> Vector2:
	var p: Array = r["pos"]
	return Vector2(float(p[0]), float(p[2]))


static func _put(ground: PackedByteArray, w: int, h: int, x: int, y: int, m: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		ground[y * w + x] = m


static func _near_mat(ground: PackedByteArray, w: int, h: int, x: int, y: int, m: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var xx := x + dx
			var yy := y + dy
			if xx >= 0 and yy >= 0 and xx < w and yy < h and ground[yy * w + xx] == m:
				return true
	return false


static func _near_owner(owner: PackedInt32Array, w: int, h: int, x: int, y: int, o: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var xx := x + dx
			var yy := y + dy
			if xx >= 0 and yy >= 0 and xx < w and yy < h and owner[yy * w + xx] == o:
				return true
	return false


static func _occupy(occ: Dictionary, c: Vector2i, rx: int, ry: int) -> void:
	for dy in range(-ry, 1):
		for dx in range(-rx, rx + 1):
			occ[c + Vector2i(dx, dy)] = true


static func _free(occ: Dictionary, roads: Dictionary, ground: PackedByteArray, w: int, h: int, c: Vector2i) -> bool:
	if c.x < 1 or c.y < 1 or c.x >= w - 1 or c.y >= h - 1:
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cc := c + Vector2i(dx, dy)
			if occ.has(cc) or roads.has(cc):
				return false
	var g := MATS[ground[c.y * w + c.x]] as String
	return not g in SOLID


static func _near_road(roads: Dictionary, c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if roads.has(c + Vector2i(dx, dy)):
				return true
	return false


static func _weighted(rng: RandomNumberGenerator, items: Array) -> String:
	var total := 0.0
	for it in items:
		total += float(it[1])
	var roll := rng.randf() * total
	for it in items:
		roll -= float(it[1])
		if roll <= 0.0:
			return it[0]
	return items[0][0]


## Vila: casas em volta da praça, poço (ou a Grande Lareira), postes e
## lugares para os NPCs passearem.
static func _village(objects: Array, occ: Dictionary, ground: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator, id: String, r: Dictionary, c: Vector2i, roads: Dictionary, villages: Dictionary, is_start: bool) -> void:
	var house: String = HOUSE_BY_HUB.get(str(r.get("hub", "vila")), "house_wood")
	if r["biome"] in ["deserto", "templo_dourado"]:
		house = "house_sand"
	elif r["biome"] in ["cemiterio", "cidade_magos", "cidade_subterranea", "catacumbas"]:
		house = "house_dark"
	elif r["biome"] in ["acampamento_barbaro", "fortaleza_orc"]:
		house = "tent" if r["biome"] == "acampamento_barbaro" else "tent_red"
	var center_obj := "hearth" if is_start else "well"
	objects.append({"name": center_obj, "cell": c + Vector2i(0, 2), "region": id, "kind": "hearth" if is_start else "deco"})
	_occupy(occ, c + Vector2i(0, 2), 3 if is_start else 1, 2)
	# casas num anel em volta da praça, fora das estradas
	var slots := [Vector2i(-11, -3), Vector2i(11, -3), Vector2i(-12, 6), Vector2i(12, 6), Vector2i(-5, 12), Vector2i(6, 12), Vector2i(-6, -10), Vector2i(7, -10)]
	RngUtil.shuffle(rng, slots)
	var placed := 0
	for s in slots:
		if placed >= 5:
			break
		var hc: Vector2i = c + s
		var ok := true
		for dy in range(-4, 1):
			for dx in range(-2, 3):
				if roads.has(hc + Vector2i(dx, dy)) or occ.has(hc + Vector2i(dx, dy)):
					ok = false
		if hc.x < 4 or hc.y < 5 or hc.x >= w - 4 or hc.y >= h - 2:
			ok = false
		if not ok:
			continue
		objects.append({"name": house, "cell": hc, "region": id, "kind": "house"})
		_occupy(occ, hc, 2, 4)
		placed += 1
	# postes nos cantos da praça
	for lp in [Vector2i(-5, -4), Vector2i(5, -4), Vector2i(-5, 5), Vector2i(5, 5)]:
		var lc: Vector2i = c + lp
		if not occ.has(lc) and not roads.has(lc):
			objects.append({"name": "lamp_post", "cell": lc, "region": id, "kind": "lamp"})
			_occupy(occ, lc, 0, 0)
	# pontos de passeio na praça, longe do poço/Lareira (que fica logo abaixo do centro)
	var npc_cells: Array = []
	for i in 10:
		var a := TAU * i / 10.0
		var p := c + Vector2i((Vector2.from_angle(a) * Vector2(5.5, 4.5)).round())
		if absi(p.x - c.x) <= (4 if is_start else 2) and p.y >= c.y - 1 and p.y <= c.y + 3:
			continue
		npc_cells.append(p)
	villages[id]["npc_cells"] = npc_cells
