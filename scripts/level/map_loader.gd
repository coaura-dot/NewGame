class_name MapLoader
extends RefCounted
## Regiões FEITAS À MÃO (data/maps/<id>.txt), no estilo Hollow Knight: cada
## sala (lugar) é desenhada em ASCII com nome, tipo e propósito, e colada
## numa tela de rocha. Saída: o mesmo formato do RegionDesigner (rows, bg,
## rooms, entities, ports, water, macro, objective) + "decor" (cenografia).
##
## Formato do arquivo (linhas "//" são comentários):
##   @map galerias
##   @size 180 100          tamanho em tiles
##   @default #             o que não for desenhado ('#' rocha, '.' ar)
##   @bg wall               fundo padrão das salas: wall | open | sky
##   @room <id> "<Nome>" kind=<tipo> at=<x>,<y> [bg=..] [port=L|R|U|D]
##         [enemies=a,b] [flyers=a] [npcs=..] [loot=..] [requires=habilidade]
##         [gate=combat|lever] [music=..] [hidden]
##   1 = inscription "texto"          entidades próprias da sala (dígitos)
##   2 = sign L "Cinzal"
##   3 = npc borralha
##   ...ASCII da sala...
##   @end
##
## Legenda do ASCII:
##   #  rocha        .  ar            (espaço) não mexe no que já existe
##   -  plataforma   ^  espinhos      ~  água (lago)
##   B  parede que quebra com golpes  Z  piso rachado (Queda Esmagadora)
##   Maiúsculas = entidades (LevelConst.ENTITY_CHARS): E inimigo, F voador,
##   U atirador, M chefe, H santuário, C baú, R relíquia, G portão (topo de
##   uma porta de 4), V portão de habilidade, T alavanca, L tocha, W feixe de
##   luz, I Lanterna de Ímpeto, N aldeão, P ponto de chegada, O plataforma
##   que cai, J mola, S serra, D cristal de dash, K chave, Y fenda, A altar.
##   Minúsculas = cenografia (DECOR): l poste de lampião, p pilar, a arco,
##   r raízes, c corrente, b ossos, m fungos, g capim, s estátua, h casa,
##   t árvore, k cristais, v cipós, e braseiro, f cerca, q gaiola, n
##   estandarte, o lâmpada suspensa, w poço, d porta, x caixotes, u banco,
##   y lápide, z cogumelo grande, j vitral.
##   Dígitos = entidades da própria sala (definidas no cabeçalho).

const T := LevelConst.TILE
const CELL := 4 ## célula da grade de "dono" (room_at / mapa), em tiles

const DECOR := {
	"l": "lamppost", "p": "pillar", "a": "arch", "r": "roots", "c": "chain", "b": "bones",
	"m": "fungus", "g": "grass", "s": "statue", "h": "house", "t": "tree", "k": "crystals",
	"v": "vines", "e": "brazier", "f": "fence", "q": "cage", "n": "banner", "o": "hanging_lamp",
	"w": "well", "d": "door", "x": "crates", "u": "bench", "y": "tombstone", "z": "big_mushroom",
	"j": "stained_glass", "i": "rubble",
}
const LEGACY := {
	"santuario": "shrine", "vila": "hub", "covil": "boss", "coracao": "treasure", "passagem": "passage",
	"trilha": "corridor", "galeria": "corridor", "gruta": "corridor", "poco": "shaft", "salao": "platforming",
	"abismo": "platforming", "lago": "corridor", "ninho": "arena", "cofre": "treasure", "mirante": "secret",
	"desafio": "challenge", "fenda": "treasure", "torre": "shaft", "capela": "shrine",
}

var params: Dictionary = {}
var db: Node = null
var map_id: String = ""
var w: int = 0
var h: int = 0
var default_char: int = 35
var default_bg: String = "wall"
var grid := PackedByteArray()
var bgm := PackedByteArray() ## 0 = céu/cenário, 1 = parede de fundo
var rooms: Array = []
var entities: Array = []
var decor: Array = []
var water_cells := {}
var errors: Array = []
## habilidades que o jogador certamente tem ao chegar (ex.: double_jump):
## o teste de alcance usa o pulo correspondente
var abilities: Array = []
var _npc_cursor: int = 0


static func path_for(id: String) -> String:
	return "res://data/maps/%s.txt" % id


static func exists(id: String) -> bool:
	return id != "" and FileAccess.file_exists(path_for(id))


static func load_map(id: String, p: Dictionary, database: Node) -> Dictionary:
	var m := MapLoader.new()
	return m.run(id, p, database)


func run(id: String, p: Dictionary, database: Node) -> Dictionary:
	map_id = id
	params = p
	db = database
	var f := FileAccess.open(path_for(id), FileAccess.READ)
	if f == null:
		errors.append("mapa não encontrado: " + id)
		return {}
	var text := f.get_as_text()
	_parse(text)
	return _output()


# ---------------------------------------------------------------------------
# Leitura
# ---------------------------------------------------------------------------

func _parse(text: String) -> void:
	var lines := text.split("\n")
	var i := 0
	## salas e diretivas de terreno, na ordem do arquivo
	var pending_rooms: Array = []
	while i < lines.size():
		var line: String = lines[i].trim_suffix("\r")
		i += 1
		if line.begins_with("//") or line.strip_edges() == "":
			continue
		if not line.begins_with("@"):
			continue
		var toks := _tokens(line.substr(1))
		if toks.is_empty():
			continue
		var cmd: String = toks[0]
		match cmd:
			"map":
				pass
			"size":
				w = int(toks[1])
				h = int(toks[2])
			"default":
				default_char = str(toks[1]).unicode_at(0)
			"bg":
				default_bg = str(toks[1])
			"abilities":
				abilities = toks.slice(1)
			"fill", "ground", "ent":
				pending_rooms.append({"directive": cmd, "toks": toks})
			"room":
				var room := _room_header(toks)
				var ascii: Array = []
				var custom := {}
				while i < lines.size():
					var l2: String = lines[i].trim_suffix("\r")
					i += 1
					if l2.begins_with("@end"):
						break
					if l2.begins_with("//"):
						continue
					if l2.length() >= 2 and l2.unicode_at(0) >= 48 and l2.unicode_at(0) <= 57 and l2.strip_edges().substr(1).strip_edges().begins_with("="):
						var digit := l2.substr(0, 1)
						custom[digit] = _tokens(l2.strip_edges().substr(1).strip_edges().substr(1))
						continue
					ascii.append(l2)
				room["ascii"] = ascii
				room["custom"] = custom
				pending_rooms.append(room)
	if w <= 0 or h <= 0:
		# tamanho a partir das salas
		for r in pending_rooms:
			if r.has("directive"):
				continue
			var at: Vector2i = r["at"]
			var aw := 0
			for l in r["ascii"]:
				aw = maxi(aw, str(l).length())
			w = maxi(w, at.x + aw)
			h = maxi(h, at.y + r["ascii"].size())
	grid.resize(w * h)
	grid.fill(default_char)
	bgm.resize(w * h)
	bgm.fill(1)
	var late_ents: Array = []
	for r in pending_rooms:
		if r.has("directive"):
			if r["directive"] == "ent":
				late_ents.append(r["toks"])
			else:
				_directive(r["directive"], r["toks"])
		else:
			_paint_room(r)
	for toks in late_ents:
		var xy := str(toks[1]).split(",")
		var x := int(xy[0])
		var y := int(xy[1])
		_custom(toks.slice(2), x, y, _owner_room(x, y), {"id": "@ent", "custom": {}})
	# ar fora das salas (céu aberto do mapa) mostra o cenário
	for y in h:
		for x in w:
			var gc := grid[y * w + x]
			if gc != 35 and _owner_room(x, y) < 0:
				bgm[y * w + x] = 0


## @fill x0,y0,x1,y1 <c>   retângulo (inclusivo) com o caractere
## @ground a-b:y c-d:y ...   chão: rocha da linha y até o fundo, por faixa
func _directive(cmd: String, toks: Array) -> void:
	if cmd == "fill":
		var r := str(toks[1]).split(",")
		var c := str(toks[2]).unicode_at(0) if toks.size() > 2 else 35
		for y in range(maxi(int(r[1]), 0), mini(int(r[3]) + 1, h)):
			for x in range(maxi(int(r[0]), 0), mini(int(r[2]) + 1, w)):
				grid[y * w + x] = c
	elif cmd == "ground":
		for span in toks.slice(1):
			var parts := str(span).split(":")
			var xs := parts[0].split("-")
			var x0 := int(xs[0])
			var x1 := int(xs[1]) if xs.size() > 1 else x0
			var gy := int(parts[1])
			for x in range(maxi(x0, 0), mini(x1 + 1, w)):
				for y in range(maxi(gy, 0), h):
					grid[y * w + x] = 35


func _tokens(s: String) -> Array:
	var out: Array = []
	var cur := ""
	var q := false
	var had := false
	for k in s.length():
		var ch := s[k]
		if ch == "\"":
			q = not q
			had = true
			continue
		if (ch == " " or ch == "\t") and not q:
			if cur != "" or had:
				out.append(cur)
			cur = ""
			had = false
			continue
		cur += ch
	if cur != "" or had:
		out.append(cur)
	return out


func _kv(toks: Array) -> Dictionary:
	var d := {}
	for t in toks:
		var s := str(t)
		var eq := s.find("=")
		if eq > 0:
			d[s.substr(0, eq)] = s.substr(eq + 1)
	return d


func _room_header(toks: Array) -> Dictionary:
	var kv := _kv(toks)
	var room := {
		"id": str(toks[1]) if toks.size() > 1 else "sala",
		"name": str(toks[2]) if toks.size() > 2 and str(toks[2]).find("=") < 0 else "",
		"kind": str(kv.get("kind", "galeria")),
		"at": Vector2i.ZERO,
		"bg": str(kv.get("bg", default_bg)),
		"kv": kv,
		"hidden": toks.has("hidden"),
	}
	var at := str(kv.get("at", "0,0")).split(",")
	room["at"] = Vector2i(int(at[0]), int(at[1]) if at.size() > 1 else 0)
	return room


func _list(kv: Dictionary, key: String) -> Array:
	var s := str(kv.get(key, ""))
	if s == "":
		return []
	return Array(s.split(","))


# ---------------------------------------------------------------------------
# Salas
# ---------------------------------------------------------------------------

func _paint_room(r: Dictionary) -> void:
	var at: Vector2i = r["at"]
	var ascii: Array = r["ascii"]
	var aw := 0
	for l in ascii:
		aw = maxi(aw, str(l).length())
	var kind: String = r["kind"]
	var kv: Dictionary = r["kv"]
	if r.get("hidden", false):
		# bloco só de pintura (não vira lugar): o dono é resolvido no fim
		_paint_ascii(r, -1, kv, 1 if str(r["bg"]) == "wall" else 0)
		return
	var idx := rooms.size()
	var rect := Rect2i(at.x, at.y, aw, ascii.size())
	if kv.has("rect"):
		var rr := str(kv["rect"]).split(",")
		rect = Rect2i(int(rr[0]), int(rr[1]), int(rr[2]), int(rr[3]))
	var room := {
		"index": idx, "kind": kind, "type": str(kv.get("type", LEGACY.get(kind, "corridor"))),
		"name": r["name"], "id": r["id"],
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"origin": [rect.position.x, rect.position.y],
		"cells": [maxi(1, rect.size.x / CELL), maxi(1, rect.size.y / CELL)],
		"template": "map:" + map_id,
	}
	if kv.has("requires"):
		room["requires"] = str(kv["requires"])
	if kv.has("music"):
		room["music"] = str(kv["music"])
	if r.get("hidden", false):
		room["hidden"] = true
	if kv.has("port"):
		room["port_dir"] = str(kv["port"])
	rooms.append(room)
	if ascii.is_empty():
		# sala só-retângulo: nomeia um lugar sobre o terreno já desenhado
		var fc := str(kv.get("fill", "")).unicode_at(0) if str(kv.get("fill", "")) != "" else -1
		var bv := -1
		if kv.has("bg"):
			bv = 0 if str(kv["bg"]) in ["open", "sky"] else 1
		for y in range(maxi(rect.position.y, 0), mini(rect.end.y, h)):
			for x in range(maxi(rect.position.x, 0), mini(rect.end.x, w)):
				if fc >= 0:
					grid[y * w + x] = fc
				if bv >= 0:
					bgm[y * w + x] = bv
		return
	_paint_ascii(r, idx, kv, 0 if str(r["bg"]) in ["open", "sky"] else 1)


func _paint_ascii(r: Dictionary, idx: int, kv: Dictionary, bgv: int) -> void:
	var at: Vector2i = r["at"]
	var ascii: Array = r["ascii"]
	var enemies := _list(kv, "enemies")
	var flyers := _list(kv, "flyers")
	var snipers := _list(kv, "snipers")
	var npcs := _list(kv, "npcs")
	var counters := {"E": 0, "F": 0, "U": 0, "N": 0}
	for yy in ascii.size():
		var line: String = ascii[yy]
		for xx in line.length():
			var ch := line[xx]
			if ch == " ":
				continue
			var x := at.x + xx
			var y := at.y + yy
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			var i := y * w + x
			if idx >= 0 or str(r["bg"]) != "":
				bgm[i] = bgv
			match ch:
				"#":
					grid[i] = 35
				".":
					grid[i] = 46
				"-":
					grid[i] = 45
				"^":
					grid[i] = 94
				"~":
					grid[i] = 46
					water_cells[Vector2i(x, y)] = true
				"B":
					grid[i] = 46
					_ent("breakable", x, y, idx)
				"Z":
					grid[i] = 90
					_ent("cracked_floor", x, y, idx)
				_:
					grid[i] = 46
					if DECOR.has(ch):
						decor.append({"id": DECOR[ch], "tile": [x, y], "room": idx})
					elif ch.unicode_at(0) >= 48 and ch.unicode_at(0) <= 57:
						_custom(r["custom"].get(ch, []), x, y, idx, r)
					elif LevelConst.ENTITY_CHARS.has(ch):
						_char_entity(ch, x, y, idx, kv, enemies, flyers, snipers, npcs, counters)
					else:
						errors.append("%s: caractere desconhecido '%s' em %d,%d" % [r["id"], ch, x, y])


func _pick(list: Array, counters: Dictionary, key: String, fallback: String) -> String:
	if list.is_empty():
		return fallback
	var n: int = counters[key]
	counters[key] = n + 1
	return str(list[n % list.size()])


func _char_entity(ch: String, x: int, y: int, room: int, kv: Dictionary, enemies: Array, flyers: Array, snipers: Array, npcs: Array, counters: Dictionary) -> void:
	match ch:
		"E":
			_ent("enemy", x, y, room, {"enemy": _pick(enemies, counters, "E", _default_enemy("ground"))})
		"F":
			_ent("flyer", x, y, room, {"enemy": _pick(flyers if not flyers.is_empty() else [], counters, "F", _default_enemy("flying"))})
		"U":
			_ent("enemy", x, y, room, {"enemy": _pick(snipers, counters, "U", "sniper")})
		"M":
			var boss := str(params.get("boss", ""))
			if kv.has("boss") and boss != "":
				boss = str(kv["boss"])
			if boss != "":
				_ent("boss", x, y, room, {"enemy": boss})
		"N":
			var ids: Array = params.get("npcs", [])
			if not npcs.is_empty():
				_ent("story_npc", x, y, room, {"npc": _pick(npcs, counters, "N", "")})
			elif _npc_cursor < ids.size():
				_ent("npc", x, y, room, {"npc": str(ids[_npc_cursor])})
				_npc_cursor += 1
		"G":
			_ent("gate", x, y, room, {"mode": str(kv.get("gate", "combat"))})
		"V":
			var ab := str(kv.get("requires", ""))
			if ab != "":
				_ent("ability_gate", x, y, room, {"kind": "ability", "ability": ab})
			else:
				_ent("ability_gate", x, y, room, {"kind": "locked", "requires": str(kv.get("key", "chave_ferro"))})
		"C":
			_ent("chest", x, y, room, {"loot": str(kv.get("loot", ""))})
		"R":
			_ent("relic", x, y, room, {"loot": str(kv.get("relic", kv.get("loot", "centelha")))})
		"K":
			_ent("key", x, y, room, {"item": str(kv.get("key", "chave_ferro"))})
		"Y":
			if str(params.get("rift", "")) != "":
				_ent("rift", x, y, room, {"region": str(params["rift"])})
		"A":
			_ent("altar", x, y, room)
		"P":
			# ponto de chegada de quem entra pelo portão desta sala
			_ent("arrival", x, y, room)
		_:
			_ent(str(LevelConst.ENTITY_CHARS[ch]), x, y, room)


## Entidade própria da sala: "<tipo> [args] [chave=valor] ["texto"]".
func _custom(toks: Array, x: int, y: int, room: int, r: Dictionary) -> void:
	if toks.is_empty():
		errors.append("%s: dígito sem definição em %d,%d" % [r["id"], x, y])
		return
	var type: String = toks[0]
	var kv := _kv(toks.slice(1))
	var args: Array = []
	for t in toks.slice(1):
		if str(t).find("=") < 0:
			args.append(str(t))
	match type:
		"inscription":
			_ent("inscription", x, y, room, {"text": args[0] if args.size() > 0 else "", "title": str(kv.get("title", ""))})
		"sign":
			_ent("sign", x, y, room, {"dir": args[0] if args.size() > 0 else "R", "text": args[1] if args.size() > 1 else ""})
		"npc":
			_ent("story_npc", x, y, room, {"npc": args[0] if args.size() > 0 else ""})
		"decor":
			decor.append({"id": args[0] if args.size() > 0 else "rubble", "tile": [x, y], "room": room, "data": kv})
		"chest":
			_ent("chest", x, y, room, {"loot": str(kv.get("loot", ""))})
		"relic":
			_ent("relic", x, y, room, {"loot": str(kv.get("loot", "centelha"))})
		"ability_gate":
			_ent("ability_gate", x, y, room, {"kind": "ability", "ability": str(kv.get("ability", args[0] if args.size() > 0 else ""))})
		"enemy", "flyer":
			_ent(type, x, y, room, {"enemy": args[0] if args.size() > 0 else _default_enemy("ground"), "behavior": str(kv.get("behavior", ""))})
		"trigger":
			# gatilho de cena (cutscene): área de w x h tiles a partir daqui
			_ent("trigger", x, y, room, {"scene": args[0] if args.size() > 0 else "", "w": int(kv.get("w", 3)), "h": int(kv.get("h", 4)), "once": str(kv.get("once", "1")) == "1"})
		"lamp":
			# poste de lampião que o Lume acende (luz + marco)
			_ent("lamp", x, y, room, {"lit": str(kv.get("lit", "0")) == "1"})
		_:
			var d := kv.duplicate()
			if args.size() > 0:
				d["arg"] = args[0]
			_ent(type, x, y, room, d)


func _ent(type: String, x: int, y: int, room: int, data: Dictionary = {}) -> void:
	entities.append({"type": type, "tile": [x, y], "room": room, "data": data})


## Espécie mais comum do bioma para o tipo (ground | flying | ranged).
func _default_enemy(kind: String) -> String:
	if db == null:
		return "skeleton" if kind != "flying" else "diver"
	var pool := LevelGenerator._enemy_pool(params, db, db.biome(str(params.get("biome", ""))))
	var d: Dictionary = pool.get(kind, {})
	var best := ""
	var bw := -1.0
	for id in d.keys():
		if float(d[id]) > bw:
			bw = float(d[id])
			best = str(id)
	return best if best != "" else "skeleton"


func _owner_room(x: int, y: int) -> int:
	var best := -1
	var best_area := 1 << 30
	for r in rooms:
		var rr: Array = r["rect"]
		if x >= int(rr[0]) and y >= int(rr[1]) and x < int(rr[0]) + int(rr[2]) and y < int(rr[1]) + int(rr[3]):
			var a := int(rr[2]) * int(rr[3])
			if a < best_area:
				best_area = a
				best = int(r["index"])
	return best


# ---------------------------------------------------------------------------
# Saída
# ---------------------------------------------------------------------------

func _output() -> Dictionary:
	# dono de cada entidade = a MENOR sala que contém o tile (uma sala só de
	# retângulo dentro de um bloco maior, como um portão, fica com o que é seu)
	for e in entities:
		var o := _owner_room(int(e["tile"][0]), int(e["tile"][1]))
		if o >= 0:
			e["room"] = o
		elif int(e["room"]) < 0:
			e["room"] = 0
	for d in decor:
		var o2 := _owner_room(int(d["tile"][0]), int(d["tile"][1]))
		if o2 >= 0:
			d["room"] = o2
		elif int(d["room"]) < 0:
			d["room"] = 0
	var rows := PackedStringArray()
	var bg_rows := PackedStringArray()
	for y in h:
		rows.append(grid.slice(y * w, y * w + w).get_string_from_ascii())
		var line := PackedByteArray()
		line.resize(w)
		for x in w:
			line[x] = 48 + bgm[y * w + x]
		bg_rows.append(line.get_string_from_ascii())
	# portões: salas marcadas com port=<dir> + arestas do mundo
	var ports_out: Array = []
	for pt in params.get("ports", []):
		var dir := str(pt["dir"])
		var room := -1
		for r in rooms:
			if str(r.get("port_dir", "")) == dir:
				room = int(r["index"])
				break
		if room < 0:
			errors.append("%s: sem sala de saída para %s" % [map_id, dir])
			continue
		var spawn := [-1, -1]
		for e in entities:
			if e["type"] == "arrival" and int(e["room"]) == room and str(e["data"].get("port", "")) == "":
				spawn = e["tile"]
		for e in entities:
			if e["type"] == "arrival" and str(e["data"].get("port", "")) == dir:
				spawn = e["tile"]
		rooms[room]["port"] = {"dir": dir, "to": pt["to"], "requires": pt.get("requires", "")}
		ports_out.append({"dir": dir, "to": pt["to"], "requires": pt.get("requires", ""), "room": room,
			"origin": rooms[room]["origin"], "spawn": spawn})
	# grade de donos (room_at e mapa)
	var gw := int(ceil(float(w) / CELL))
	var gh := int(ceil(float(h) / CELL))
	var owner: Array = []
	for cy in gh:
		for cx in gw:
			owner.append(_owner_room(mini(cx * CELL + CELL / 2, w - 1), mini(cy * CELL + CELL / 2, h - 1)))
	# lagos: faixas contínuas de água
	var water: Array = []
	var done := {}
	for c in water_cells.keys():
		if done.has(c):
			continue
		var cell: Vector2i = c
		# topo-esquerda da faixa
		var x0 := cell.x
		while water_cells.has(Vector2i(x0 - 1, cell.y)):
			x0 -= 1
		var x1 := cell.x
		while water_cells.has(Vector2i(x1 + 1, cell.y)):
			x1 += 1
		var top := cell.y
		while water_cells.has(Vector2i(x0, top - 1)):
			top -= 1
		var bot := cell.y
		while water_cells.has(Vector2i(x0, bot + 1)):
			bot += 1
		for yy in range(top, bot + 1):
			for xx in range(x0, x1 + 1):
				done[Vector2i(xx, yy)] = true
		water.append([x0, x1, top, bot])
	# objetivo
	var obj := {}
	var boss := str(params.get("boss", ""))
	for r in rooms:
		if r["kind"] == "covil" and boss != "":
			obj = {"kind": "boss", "room": r["index"], "text": "Derrote %s no %s" % [str(db.enemy(boss).get("name", "guardião")) if db else boss, r["name"]]}
			break
	if obj.is_empty():
		for r in rooms:
			if r["kind"] == "coracao":
				obj = {"kind": "heart", "room": r["index"], "text": "Encontre a relíquia do %s" % r["name"]}
				break
	var spawn_t := Vector2i(-1, -1)
	for e in entities:
		if e["type"] == "start":
			spawn_t = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
	for e in entities:
		if spawn_t.x >= 0:
			break
		if e["type"] == "checkpoint":
			spawn_t = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
			break
	if spawn_t.x < 0:
		for e in entities:
			if e["type"] == "arrival":
				spawn_t = Vector2i(int(e["tile"][0]), int(e["tile"][1]))
				break
	if spawn_t.x >= 0:
		entities.append({"type": "spawn", "tile": [spawn_t.x, spawn_t.y], "room": _owner_room(spawn_t.x, spawn_t.y), "data": {"default": true}})
	for e in errors:
		push_warning("MapLoader: " + str(e))
	return {
		"seed": int(params.get("seed", 1)),
		"biome": str(params.get("biome", "")),
		"tier": int(params.get("tier", 1)),
		"width": w,
		"height": h,
		"rows": rows,
		"bg": bg_rows,
		"rooms": rooms,
		"path": [],
		"entities": entities,
		"decor": decor,
		"spawn": [spawn_t.x, spawn_t.y],
		"exit": [spawn_t.x, spawn_t.y],
		"key_placed": true,
		"indoor": default_bg == "wall",
		"sky_rooms": [],
		"ports": ports_out,
		"water": water,
		"macro": {"cw": CELL, "ch": CELL, "gw": gw, "gh": gh, "owner": owner},
		"objective": obj,
		"mode": "handmade",
		"map": map_id,
		"abilities": abilities,
		"errors": errors,
	}
