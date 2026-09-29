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

	# 1) posições (amostragem com distância mínima)
	var points: Array[Vector2] = []
	var tries := 0
	while points.size() < main_count and tries < 5000:
		tries += 1
		var p := Vector2(rng.randf_range(-48, 48), rng.randf_range(-34, 34))
		var ok := true
		for q in points:
			if q.distance_to(p) < 15.0:
				ok = false
				break
		if ok:
			points.append(p)
	var n := points.size()

	# 2) arestas: árvore geradora mínima (Prim) + alguns atalhos para ciclos
	var edges := {} # "i-j" -> true
	var in_tree := {0: true}
	while in_tree.size() < n:
		var best := Vector3i(-1, -1, 0)
		var best_d := INF
		for i in in_tree.keys():
			for j in n:
				if in_tree.has(j):
					continue
				var d := points[i].distance_to(points[j])
				if d < best_d:
					best_d = d
					best = Vector3i(i, j, 0)
		in_tree[best.y] = true
		edges[_ekey(best.x, best.y)] = true
	for i in n:
		var nearest := []
		for j in n:
			if j != i:
				nearest.append([points[i].distance_to(points[j]), j])
		nearest.sort()
		for k in 2:
			if rng.randf() < 0.3 and nearest[k][0] < 40.0:
				edges[_ekey(i, nearest[k][1])] = true

	# 3) início = o mais próximo do centro
	var start_idx := 0
	for i in n:
		if points[i].length() < points[start_idx].length():
			start_idx = i
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

	# 5) regiões
	var ids: Array[String] = []
	for i in n:
		var band := mini(int(dist[i] / band_size), band_count - 1)
		var layer := "surface"
		var lr := rng.randf()
		if i != start_idx:
			if lr < 0.2:
				layer = "sky"
			elif lr < 0.4:
				layer = "underground"
		var biome_id: String = RngUtil.weighted_key(rng, LAYER_BIOMES[layer])
		var biome: Dictionary = db.biome(biome_id) if db else {}
		var id := "r%02d" % i
		ids.append(id)
		var region := {
			"id": id,
			"name": _region_name(rng, biome.get("name", biome_id)),
			"biome": biome_id,
			"layer": layer,
			"pos": [points[i].x, LAYER_HEIGHT[layer] + rng.randf_range(-2.0, 2.0), points[i].y],
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
		world["edges"].append({"a": ids[a], "b": ids[b], "requires": req, "kind": kind})

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
			out.append({"id": e["b"], "requires": e["requires"], "kind": e["kind"]})
		elif e["b"] == region_id:
			out.append({"id": e["a"], "requires": e["requires"], "kind": e["kind"]})
	return out
