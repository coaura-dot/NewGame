class_name WorldGenerator
extends RefCounted
## Gera a camada MACRO (mapa-mundi) a partir da seed do save.
##
## Resultado é um Dictionary serializável (vai inteiro para o save e fica fixo
## durante toda a partida):
##   regions: {id: {...}}   edges: [{a, b, requires, kind}]   start, finale
##
## Garantias (testadas em tests/test_world_generator.gd):
##   * grafo conexo;
##   * progressão sempre resolvível: as regiões são divididas em "faixas" por
##     distância do início; arestas que entram na faixa k exigem a habilidade
##     k-1, que é concedida por um chefe numa faixa < k;
##   * ao menos um hub (o inicial) e um chefe final na região mais distante.

const LAYER_HEIGHT := {"sky": 16.0, "surface": 0.0, "underground": -14.0}
const LAYER_BIOMES := {
	"surface": {"cemiterio": 3, "castelo": 3, "cidade_gotica": 3, "templo_dourado": 2, "ruinas": 3, "floresta": 3,
		"deserto": 2, "pantano": 2, "cidade_magos": 2, "fortaleza_orc": 2, "acampamento_barbaro": 2},
	"sky": {"cidade_ceu": 5, "templo_dourado": 2, "ruinas": 2, "cidade_magos": 2, "castelo": 1},
	"underground": {"catacumbas": 4, "cidade_subterranea": 4, "toca_goblin": 3, "castelo": 2, "pantano": 1},
}
## GEOGRAFIA (mundo com nexo): a superfície é uma faixa contínua de oeste a
## leste em que cada bioma só faz fronteira com biomas que combinam com ele
## (floresta -> pântano/ruínas/cemitério..., cidade -> castelo...). Debaixo de
## cada região da superfície fica o subsolo que pertence a ela (sob a cidade,
## os esgotos; sob o castelo e o cemitério, as catacumbas; sob a floresta, as
## tocas entre as raízes); acima, a cidadela celeste (ou as torres dos magos
## e o templo, que sobem até as nuvens).
const SURFACE_LINKS := {
	"floresta": {"floresta": 1.5, "pantano": 3.0, "ruinas": 3.0, "cemiterio": 2.0, "acampamento_barbaro": 2.0},
	"pantano": {"pantano": 1.0, "floresta": 3.0, "cemiterio": 3.0, "ruinas": 1.0},
	"ruinas": {"ruinas": 1.0, "floresta": 2.0, "templo_dourado": 3.0, "deserto": 2.0, "cidade_gotica": 3.0, "cemiterio": 2.0},
	"cemiterio": {"floresta": 1.0, "pantano": 2.0, "cidade_gotica": 3.0, "castelo": 3.0, "ruinas": 1.0},
	"cidade_gotica": {"cidade_gotica": 1.0, "castelo": 4.0, "cemiterio": 2.0, "cidade_magos": 3.0, "ruinas": 2.0},
	"castelo": {"castelo": 1.0, "cidade_gotica": 3.0, "cemiterio": 2.0, "fortaleza_orc": 1.0},
	"templo_dourado": {"ruinas": 2.0, "deserto": 3.0, "cidade_magos": 2.0},
	"deserto": {"deserto": 1.5, "templo_dourado": 3.0, "acampamento_barbaro": 3.0, "fortaleza_orc": 2.0, "ruinas": 1.0},
	"fortaleza_orc": {"acampamento_barbaro": 3.0, "deserto": 2.0, "castelo": 1.0},
	"acampamento_barbaro": {"fortaleza_orc": 3.0, "floresta": 2.0, "deserto": 2.0},
	"cidade_magos": {"templo_dourado": 2.0, "cidade_gotica": 3.0},
}
const UNDER_OF := {"floresta": "toca_goblin", "pantano": "pantano", "ruinas": "catacumbas", "cemiterio": "catacumbas",
	"cidade_gotica": "cidade_subterranea", "castelo": "catacumbas", "templo_dourado": "catacumbas", "deserto": "toca_goblin",
	"fortaleza_orc": "toca_goblin", "acampamento_barbaro": "toca_goblin", "cidade_magos": "cidade_subterranea"}
const SKY_OF := {"cidade_magos": "cidade_magos", "templo_dourado": "templo_dourado"}
## Nomes próprios por bioma (cada região do mundo ganha um diferente).
const NAMES := {
	"floresta": ["Bosque Sussurrante", "Mata das Raízes Velhas", "Clareira dos Vaga-lumes", "Bosque de Cinzaverde", "Mata do Assobio"],
	"pantano": ["Brejo das Lamparinas", "Charco de Morn", "Lodaçal Pútrido", "Alagado dos Juncos"],
	"ruinas": ["Ruínas de Aldramar", "Pátios Caídos", "Velha Cindária", "Arcos Partidos"],
	"cemiterio": ["Campo dos Túmulos", "Colina das Lápides", "Cemitério dos Sem-Nome", "Jardim dos Ossos"],
	"cidade_gotica": ["Cidade de Vésper", "Burgo das Gárgulas", "Ruas de Ferro", "Bairro dos Sinos"],
	"castelo": ["Castelo Sombrio", "Bastião de Umbral", "Fortaleza Real", "Salões do Rei Cinza"],
	"templo_dourado": ["Templo do Sol Dourado", "Santuário de Âmbar", "Escadarias de Ouro"],
	"deserto": ["Dunas de Âmbar", "Ermo Escaldante", "Vale das Areias Rubras"],
	"fortaleza_orc": ["Paliçada de Grumm", "Fortaleza Rubra", "Muralha dos Chifres"],
	"acampamento_barbaro": ["Acampamento dos Lobos", "Terras Bárbaras", "Fogueiras do Norte"],
	"cidade_magos": ["Torres de Arcanum", "Cidade dos Magos", "Bibliotecas Suspensas"],
	"cidade_ceu": ["Cidadela Celeste", "Jardins das Nuvens", "Pináculo de Aeris", "Pontes do Vento"],
	"catacumbas": ["Catacumbas do Ossário", "Masmorras Esquecidas", "Criptas Profundas", "Galerias dos Mortos"],
	"cidade_subterranea": ["Esgotos de Vésper", "Cidade Afundada", "Cisternas Antigas"],
	"toca_goblin": ["Toca dos Goblins", "Túneis das Raízes", "Covis de Fuligem", "Formigueiro Rubro"],
}
const SYLLABLES := ["val", "mor", "ar", "eth", "dun", "kar", "lis", "ora", "thal", "vex", "bri", "sol", "nar", "gal", "ith", "rum", "ce", "zan", "lo", "mir"]


static func generate(seed_value: int, db: Node = null) -> Dictionary:
	var rng := RngUtil.make(seed_value, "world")
	var main_count := rng.randi_range(14, 18)
	var world := {
		"seed": seed_value,
		"regions": {},
		"edges": [],
		"start": "",
		"finale": "",
		"abilities_order": [],
	}

	# 1) MUNDO EM GRADE (corte lateral, explorável a pé): a superfície é uma
	# faixa de regiões lado a lado; cidades do céu ficam ACIMA de algumas
	# delas e regiões subterrâneas ABAIXO. Andando até a borda de uma região
	# você entra na vizinha (esquerda/direita/cima/baixo).
	var surf_n := rng.randi_range(9, 11)
	var grid: Array[Vector2i] = []
	for x in surf_n:
		grid.append(Vector2i(x, 0))
	var cols: Array = range(surf_n)
	RngUtil.shuffle(rng, cols)
	var sky_n := rng.randi_range(3, 4)
	for k in sky_n:
		grid.append(Vector2i(cols[k], -1))
	RngUtil.shuffle(rng, cols)
	var under_n := rng.randi_range(4, 5)
	for k in under_n:
		grid.append(Vector2i(cols[k], 1))
	var n := grid.size()
	var index_of := {}
	for i in n:
		index_of[grid[i]] = i

	# 2) arestas: vizinhos na grade. Superfície sempre ligada em fila; céu e
	# subsolo ligados à superfície; vizinhos no céu/subsolo às vezes (ciclos)
	var edges := {} # "i-j" -> true
	for i in n:
		var c := grid[i]
		if c.y == 0 and index_of.has(c + Vector2i(1, 0)):
			edges[_ekey(i, index_of[c + Vector2i(1, 0)])] = true
		if c.y != 0:
			edges[_ekey(i, index_of[Vector2i(c.x, 0)])] = true
			var right: Vector2i = c + Vector2i(1, 0)
			if index_of.has(right) and rng.randf() < (0.7 if c.y > 0 else 0.55):
				edges[_ekey(i, index_of[right])] = true
	var points: Array[Vector2] = []
	for c in grid:
		points.append(Vector2(c.x * 20.0 - surf_n * 10.0, c.y * -18.0))

	# 3) início = superfície do meio
	var start_idx := int(surf_n / 2)
	var adj := _adjacency(n, edges)
	var dist := _bfs(adj, start_idx)
	var max_dist := 0
	for d in dist:
		max_dist = maxi(max_dist, d)

	# 4) habilidades (gates) em ordem aleatória, só as implementadas
	var gate_abilities: Array = []
	var ab: Dictionary = db.abilities if db else {}
	for id in ab.keys():
		if ab[id].get("implemented", false) and not ab[id].get("start", false) and id != "dimension_shift":
			gate_abilities.append(id)
	gate_abilities.sort()
	RngUtil.shuffle(rng, gate_abilities)
	# faixas com pelo menos 2 níveis de distância (a faixa 0 nunca é só o início)
	var band_count := clampi(int((max_dist + 1) / 2), 1, gate_abilities.size() + 1)
	var leftover_abilities: Array = gate_abilities.slice(band_count - 1)
	gate_abilities = gate_abilities.slice(0, band_count - 1)
	world["abilities_order"] = gate_abilities
	var band_size := maxf(1.0, float(max_dist + 1) / band_count)

	# 5) regiões (biomas pela geografia: vizinhos que combinam)
	var biome_of := _geography(rng, grid, surf_n, start_idx)
	var used_names := {}
	var ids: Array[String] = []
	for i in n:
		var band := mini(int(dist[i] / band_size), band_count - 1)
		var layer := "surface" if grid[i].y == 0 else ("sky" if grid[i].y < 0 else "underground")
		var biome_id: String = biome_of.get(grid[i], RngUtil.weighted_key(rng, LAYER_BIOMES[layer]))
		var biome: Dictionary = db.biome(biome_id) if db else {}
		var id := "r%02d" % i
		ids.append(id)
		var region := {
			"id": id,
			"name": _proper_name(rng, biome_id, biome.get("name", biome_id), used_names),
			"biome": biome_id,
			"layer": layer,
			"pos": [points[i].x, LAYER_HEIGHT[layer] + rng.randf_range(-2.0, 2.0), points[i].y],
			"grid": [grid[i].x, grid[i].y],
			"band": band,
			"depth": dist[i],
			"tier": clampi(1 + int(float(dist[i]) / maxf(1.0, max_dist) * 2.99), 1, 3),
			"hub": "",
			"boss": "",
			"grants": "",
			"rewards": [],
			"optional": false,
			"dimension": "prima",
			"cleared": false,
			"destroyed": false,
			"visited": false,
			"level_seed": rng.randi(),
		}
		world["regions"][id] = region
	world["start"] = ids[start_idx]

	# hubs: o inicial sempre; outros ~40% (se o bioma suporta)
	for i in n:
		var r: Dictionary = world["regions"][ids[i]]
		var biome: Dictionary = db.biome(r["biome"]) if db else {}
		var hub_type: String = biome.get("hub", "vila")
		if i == start_idx:
			r["hub"] = hub_type if hub_type != "" else "vila"
		elif hub_type != "" and rng.randf() < 0.4:
			r["hub"] = hub_type

	# chefes que concedem habilidades: um por faixa (menos a última), cada
	# faixa com um chefe diferente (duelo, horda, colosso, corcel...)
	var boss_pool: Array = ["duelist", "brood_mother", "colossus", "nightmare"]
	RngUtil.shuffle(rng, boss_pool)
	for b in gate_abilities.size():
		var candidates: Array = []
		for i in n:
			var r: Dictionary = world["regions"][ids[i]]
			if r["band"] == b and i != start_idx and r["grants"] == "":
				candidates.append(i)
		if candidates.is_empty():
			candidates = [start_idx]
		# prefere a mais funda da faixa
		candidates.sort_custom(func(x, y): return dist[x] > dist[y])
		var gi: int = candidates[0]
		var gr: Dictionary = world["regions"][ids[gi]]
		gr["grants"] = gate_abilities[b]
		gr["boss"] = boss_pool[b % boss_pool.size()]

	# final: a região mais distante
	var finale_idx := 0
	for i in n:
		if dist[i] > dist[finale_idx]:
			finale_idx = i
	world["finale"] = ids[finale_idx]
	# o covil do Arquidemônio: castelo na superfície, catacumbas no subsolo,
	# cidadela no céu
	var fin: Dictionary = world["regions"][ids[finale_idx]]
	var fin_biome: String = {"surface": "castelo", "underground": "catacumbas", "sky": "cidade_ceu"}[fin["layer"]]
	if fin["biome"] != fin_biome:
		fin["biome"] = fin_biome
		fin["name"] = _proper_name(rng, fin_biome, db.biome(fin_biome).get("name", fin_biome) if db else fin_biome, used_names)
	world["regions"][ids[finale_idx]]["boss"] = "archdemon"
	world["regions"][ids[finale_idx]]["tier"] = 3

	# 6) arestas com requisitos
	for key in edges.keys():
		var pr: PackedStringArray = key.split("-")
		var a := int(pr[0])
		var b := int(pr[1])
		var ba: int = world["regions"][ids[a]]["band"]
		var bb: int = world["regions"][ids[b]]["band"]
		var req := ""
		var hi := maxi(ba, bb)
		if ba != bb and hi > 0:
			req = gate_abilities[hi - 1]
		var kind := "road"
		var la: String = world["regions"][ids[a]]["layer"]
		var lb: String = world["regions"][ids[b]]["layer"]
		if la == "sky" or lb == "sky":
			kind = "sky_bridge"
		elif la == "underground" or lb == "underground":
			kind = "tunnel"
		var dg := grid[b] - grid[a]
		var dir_a := "R" if dg.x > 0 else ("L" if dg.x < 0 else ("D" if dg.y > 0 else "U"))
		world["edges"].append({"a": ids[a], "b": ids[b], "requires": req, "kind": kind,
			"dir_a": dir_a, "dir_b": {"R": "L", "L": "R", "U": "D", "D": "U"}[dir_a]})

	# 7) regiões opcionais (folhas fora do caminho do final) e fendas dimensionais
	var finale_path := _path(adj, start_idx, finale_idx)
	for i in n:
		if adj[i].size() == 1 and not finale_path.has(i) and i != start_idx:
			world["regions"][ids[i]]["optional"] = true
	var dim_ids: Array = []
	if db:
		for d in db.dimensions.keys():
			if d != "prima":
				dim_ids.append(d)
	dim_ids.sort()
	RngUtil.shuffle(rng, dim_ids)
	var rift_count := mini(dim_ids.size(), rng.randi_range(2, 3))
	var anchors: Array = range(n)
	RngUtil.shuffle(rng, anchors)
	for k in rift_count:
		var anchor: int = anchors[k % anchors.size()]
		var ar: Dictionary = world["regions"][ids[anchor]]
		var dim_id: String = dim_ids[k]
		var dim: Dictionary = db.dimension(dim_id) if db else {}
		var id := "d%02d" % k
		var off := Vector2.from_angle(rng.randf() * TAU) * 9.0
		world["regions"][id] = {
			"id": id,
			"name": "%s — %s" % [dim.get("name", dim_id), ar["name"]],
			"biome": ar["biome"],
			"layer": ar["layer"],
			"pos": [ar["pos"][0] + off.x, ar["pos"][1] + 7.0, ar["pos"][2] + off.y],
			"band": ar["band"],
			"depth": ar["depth"] + 1,
			"tier": mini(int(ar["tier"]) + 1, 3),
			"hub": "",
			"boss": "",
			"grants": "",
			"rewards": [],
			"optional": true,
			"dimension": dim_id,
			"cleared": false,
			"destroyed": false,
			"visited": false,
			"level_seed": rng.randi(),
		}
		world["edges"].append({"a": ids[anchor], "b": id, "requires": "dimension_shift", "kind": "rift"})
	# recompensas extras: Chave Dimensional + habilidades que sobraram vão para
	# regiões opcionais (ou rasas) — sempre alcançáveis sem elas.
	var extra: Array = ["dimension_shift"] + leftover_abilities
	var holders: Array = []
	for i in n:
		var r: Dictionary = world["regions"][ids[i]]
		if r["optional"] and i != start_idx:
			holders.append(ids[i])
	for i in n:
		var r: Dictionary = world["regions"][ids[i]]
		if not r["optional"] and r["band"] == 0 and i != start_idx and not holders.has(ids[i]):
			holders.append(ids[i])
	if holders.is_empty():
		holders.append(ids[start_idx])
	for k in extra.size():
		var h: String = holders[k % holders.size()]
		world["regions"][h]["rewards"].append(extra[k])
	return world


static func _ekey(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


static func _adjacency(n: int, edges: Dictionary) -> Array:
	var adj := []
	for i in n:
		adj.append([])
	for key in edges.keys():
		var pr: PackedStringArray = key.split("-")
		adj[int(pr[0])].append(int(pr[1]))
		adj[int(pr[1])].append(int(pr[0]))
	return adj


static func _bfs(adj: Array, src: int) -> Array:
	var dist := []
	dist.resize(adj.size())
	dist.fill(-1)
	dist[src] = 0
	var q := [src]
	while not q.is_empty():
		var u: int = q.pop_front()
		for v in adj[u]:
			if dist[v] == -1:
				dist[v] = dist[u] + 1
				q.append(v)
	return dist


static func _path(adj: Array, a: int, b: int) -> Array:
	var prev := {a: -1}
	var q := [a]
	while not q.is_empty():
		var u: int = q.pop_front()
		if u == b:
			break
		for v in adj[u]:
			if not prev.has(v):
				prev[v] = u
				q.append(v)
	var path := []
	var cur := b
	while cur != -1 and prev.has(cur):
		path.append(cur)
		cur = prev[cur]
	return path


## Biomas de cada célula da grade: a superfície é sorteada a partir do início
## (floresta com a vila) para os dois lados seguindo SURFACE_LINKS; subsolo e
## céu herdam da superfície logo acima/abaixo.
static func _geography(rng: RandomNumberGenerator, grid: Array[Vector2i], surf_n: int, start_x: int) -> Dictionary:
	var out := {}
	out[Vector2i(start_x, 0)] = "floresta"
	for side in [1, -1]:
		var prev := "floresta"
		var run := 1
		var x: int = start_x + side
		while x >= 0 and x < surf_n:
			var opts: Dictionary = SURFACE_LINKS[prev].duplicate()
			if run >= 2:
				opts.erase(prev)
			var b: String = RngUtil.weighted_key(rng, opts)
			run = run + 1 if b == prev else 1
			prev = b
			out[Vector2i(x, 0)] = b
			x += side
	for c in grid:
		if c.y == 0:
			continue
		var above: String = out.get(Vector2i(c.x, 0), "floresta")
		out[c] = UNDER_OF.get(above, "catacumbas") if c.y > 0 else SKY_OF.get(above, "cidade_ceu")
	return out


static func _proper_name(rng: RandomNumberGenerator, biome_id: String, biome_name: String, used: Dictionary) -> String:
	var pool: Array = NAMES.get(biome_id, []).duplicate()
	RngUtil.shuffle(rng, pool)
	for nm in pool:
		if not used.has(nm):
			used[nm] = true
			return nm
	return _region_name(rng, biome_name)


static func _region_name(rng: RandomNumberGenerator, biome_name: String) -> String:
	var s := ""
	for i in rng.randi_range(2, 3):
		s += SYLLABLES[rng.randi_range(0, SYLLABLES.size() - 1)]
	return "%s de %s" % [biome_name, s.capitalize()]


# ---------------------------------------------------------------------------
# Consultas de progressão (usadas pelo mapa e pelos testes)
# ---------------------------------------------------------------------------

## Regiões alcançáveis a partir do início com um conjunto de habilidades.
static func reachable(world: Dictionary, abilities: Array) -> Dictionary:
	var seen := {world["start"]: true}
	var q: Array = [world["start"]]
	while not q.is_empty():
		var u: String = q.pop_front()
		for e in world["edges"]:
			var other := ""
			if e["a"] == u:
				other = e["b"]
			elif e["b"] == u:
				other = e["a"]
			else:
				continue
			if seen.has(other):
				continue
			if e["requires"] != "" and not abilities.has(e["requires"]):
				continue
			if world["regions"][other].get("destroyed", false):
				continue
			seen[other] = true
			q.append(other)
	return seen


## Simula um jogador que sempre derrota os chefes alcançáveis: retorna true se
## todas as regiões ficam acessíveis no fim.
static func is_completable(world: Dictionary, start_abilities: Array) -> bool:
	var have := start_abilities.duplicate()
	var changed := true
	while changed:
		changed = false
		var reach := reachable(world, have)
		for id in reach.keys():
			var gains: Array = world["regions"][id].get("rewards", []).duplicate()
			gains.append(world["regions"][id].get("grants", ""))
			for g in gains:
				if g != "" and not have.has(g):
					have.append(g)
					changed = true
	return reachable(world, have).size() == world["regions"].size()


static func neighbors(world: Dictionary, region_id: String) -> Array:
	var out := []
	for e in world["edges"]:
		if e["a"] == region_id:
			out.append({"id": e["b"], "requires": e["requires"], "kind": e["kind"], "dir": e.get("dir_a", "")})
		elif e["b"] == region_id:
			out.append({"id": e["a"], "requires": e["requires"], "kind": e["kind"], "dir": e.get("dir_b", "")})
	return out


## Portões físicos de uma região (bordas da fase): [{dir, to, requires}].
## Fendas dimensionais não entram (são portais dentro da fase).
static func ports(world: Dictionary, region_id: String) -> Array:
	var out := []
	for nb in neighbors(world, region_id):
		if nb["kind"] != "rift" and nb["dir"] != "":
			out.append({"dir": nb["dir"], "to": nb["id"], "requires": nb["requires"]})
	out.sort_custom(func(a, b): return "LRUD".find(a["dir"]) < "LRUD".find(b["dir"]))
	return out
