class_name Overworld
extends Node2D
## MAPA-MÚNDI explorável (visão de cima, estilo Stardew Valley): o Pavio anda
## pela ilha gerada de Game.world (OverworldGen), entre vilas, estradas,
## portões rúnicos e as ENTRADAS das fases. Entrar corta para a fase 2D; ao
## terminar, o jogo volta para o mesmo ponto do mapa.
##
## Também: névoa nas regiões desconhecidas, placas nas estradas, pedras de
## viagem (abrem o mapa 3D para viagem rápida), NPCs passeando nas vilas
## (conversa = mesmo diálogo das fases), a Grande Lareira na vila inicial e
## um ciclo de dia e noite (a chama do Pavio e os postes iluminam a noite).

const T := 8
const GROUND_TEX := preload("res://assets/art/overworld/ground.png")
const OBJ_TEX := preload("res://assets/art/overworld/objects.png")
const GROUND_META := "res://assets/art/overworld/ground.json"
const OBJ_META := "res://assets/art/overworld/objects.json"
const SCENE_WORLD_VIEW := "res://scenes/world_map.tscn"
const DAY_LENGTH := 360.0 ## segundos de um dia inteiro no mapa
const INTERACT_R := 16.0
const RUNE_COLOR := {
	"double_jump": Color(2.6, 1.3, 0.4), "wall_climb": Color(1.6, 1.1, 0.6), "dash_2": Color(0.6, 2.2, 2.8),
	"ground_pound": Color(2.8, 0.6, 0.5), "blink": Color(1.6, 0.9, 2.8), "dimension_shift": Color(2.6, 0.6, 2.4),
}
const MINI_COLORS := {
	"grass": Color8(106, 168, 79), "grass_dark": Color8(79, 107, 74), "sand": Color8(230, 201, 138), "gold_sand": Color8(232, 196, 106),
	"cobble": Color8(125, 127, 146), "ruin": Color8(138, 138, 118), "swamp": Color8(86, 102, 63), "red_dirt": Color8(160, 100, 62),
	"snow": Color8(232, 238, 244), "cloud": Color8(223, 232, 250), "cave": Color8(77, 74, 92), "arcane": Color8(94, 122, 142),
	"moss_cave": Color8(74, 90, 60), "plaza": Color8(200, 190, 170), "forest_floor": Color8(40, 70, 40), "bridge_h": Color8(154, 106, 64),
	"bridge_v": Color8(154, 106, 64), "deep_water": Color8(47, 95, 154), "sky_road": Color8(210, 230, 255), "tunnel": Color8(110, 98, 88),
	"rift": Color8(120, 78, 170), "rock_wall": Color8(60, 56, 70), "sky_void": Color8(122, 168, 232), "road": Color8(196, 158, 104),
	"water": Color8(63, 127, 192),
}

static var _gmeta: Dictionary = {}
static var _ometa: Dictionary = {}

var data: Dictionary = {}
var pixel_view: PixelView
var world_root: Node2D
var ysort: Node2D
var hero: OverworldHero
var camera: GameCamera
var hud: CanvasLayer
var ui: OverworldUI
var known: Dictionary = {}
var interactables: Array = [] ## {pos, prompt, action: Callable, region, node}
var focus: Dictionary = {}
var night: float = 0.0 ## 0 = dia, 1 = noite fechada
var _region_here: String = ""
var _fog_img: Image
var _fog_tex: ImageTexture
var _fog_sprite: Sprite2D
var _modulate: CanvasModulate
var _glows: Array = [] ## Sprite2D de brilho noturno (postes, janelas, entradas)
var _glow_layer: CanvasLayer ## fora do CanvasModulate: a noite não apaga o brilho
var _cur_region: String = "" ## região do objeto sendo montado (para a névoa)
var _region_nodes: Dictionary = {} ## região -> [nós] (escondidos na névoa)
var _step_t: float = 0.0
var _save_t: float = 0.0


func _ready() -> void:
	FX.clear_time_effects()
	if not Game.has_game:
		Game.new_game()
	if _gmeta.is_empty():
		_gmeta = SpriteLib.json(GROUND_META)
		_ometa = SpriteLib.json(OBJ_META)
	data = OverworldGen.for_world(Game.world)
	known = _known_regions()
	pixel_view = PixelView.new()
	add_child(pixel_view)
	world_root = pixel_view.world
	_modulate = CanvasModulate.new()
	world_root.add_child(_modulate)
	_glow_layer = CanvasLayer.new()
	_glow_layer.layer = 1
	_glow_layer.follow_viewport_enabled = true
	world_root.add_child(_glow_layer)
	_build_ground()
	ysort = Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	world_root.add_child(ysort)
	FX.effects_root = world_root
	_build_objects()
	_build_gates()
	_build_npcs()
	_build_fog()
	var life := AmbientLife.new()
	life.overworld = self
	world_root.add_child(life)
	var life_glow := AmbientLife.new()
	life_glow.overworld = self
	life_glow.glow = true
	_glow_layer.add_child(life_glow)
	_spawn_hero()
	camera = GameCamera.new()
	camera.target = hero
	camera.room_lock = false
	camera.follow_rate = 6.0
	camera.look_ahead = 10.0
	camera.set_bounds(Rect2(0, 0, data["w"] * T, data["h"] * T))
	world_root.add_child(camera)
	camera.snap()
	pixel_view.camera = camera
	pixel_view.set_grade({}, true)
	hud = load("res://scripts/ui/hud.gd").new()
	add_child(hud)
	ui = OverworldUI.new()
	ui.overworld = self
	add_child(ui)
	var pause_menu: CanvasLayer = load("res://scripts/ui/pause_menu.gd").new()
	add_child(pause_menu)
	_update_region(true)
	if not Game.profile.get("flags", {}).get("intro_seen", false):
		ui.play_intro()
	if Game.is_siege_ready() and not Game.social.get("siege", {}).get("started", false):
		Events.toast.emit("O CERCO COMEÇOU! Abra o mapa (M) e escolha que região defender.")
	Game.save()


# ---------------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------------

func _tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Layers.WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = GROUND_TEX
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var rows := GROUND_TEX.get_height() / T
	for y in rows:
		for x in 8:
			src.create_tile(Vector2i(x, y))
	var solid_rows: Array = []
	for n in _gmeta.get("solid", []):
		if _gmeta["materials"].has(n):
			solid_rows.append(int(_gmeta["materials"][n]))
	var wr := int(_gmeta["masked"]["water"])
	solid_rows.append(wr)
	solid_rows.append(wr + 1)
	var sq := PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	for y in solid_rows:
		for x in 8:
			var td := src.get_tile_data(Vector2i(x, y), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, sq)
	return ts


func _build_ground() -> void:
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = _tileset()
	layer.z_index = -10
	world_root.add_child(layer)
	var w: int = data["w"]
	var h: int = data["h"]
	var ground: PackedByteArray = data["ground"]
	var mats: Dictionary = _gmeta["materials"]
	var road_row := int(_gmeta["masked"]["road"])
	var water_row := int(_gmeta["masked"]["water"])
	var m_road := OverworldGen.mat("road")
	var m_water := OverworldGen.mat("water")
	var m_deep := OverworldGen.mat("deep_water")
	var road_like := [m_road, OverworldGen.mat("plaza"), OverworldGen.mat("bridge_h"), OverworldGen.mat("bridge_v"), OverworldGen.mat("sky_road"), OverworldGen.mat("tunnel"), OverworldGen.mat("rift")]
	var water_like := [m_water, m_deep, OverworldGen.mat("bridge_h"), OverworldGen.mat("bridge_v")]
	for y in h:
		for x in w:
			var m: int = ground[y * w + x]
			var hsh := absi((x * 73856093) ^ (y * 19349663)) % 1000
			var coord := Vector2i(hsh % 4, 0)
			if m == m_road:
				var mask := _mask(ground, w, h, x, y, road_like)
				coord = Vector2i(mask % 8, road_row + mask / 8)
			elif m == m_water or (m == m_deep and _touches_land(ground, w, h, x, y, water_like)):
				var mask := _mask(ground, w, h, x, y, water_like)
				coord = Vector2i(mask % 8, water_row + mask / 8)
			else:
				var name: String = OverworldGen.MATS[m]
				var v := hsh % 4
				if hsh % 9 == 0:
					v = 4 + (hsh / 9) % 4
				coord = Vector2i(v, int(mats.get(name, 0)))
			layer.set_cell(Vector2i(x, y), 0, coord)


func _mask(ground: PackedByteArray, w: int, h: int, x: int, y: int, same: Array) -> int:
	var m := 0
	if y <= 0 or same.has(int(ground[(y - 1) * w + x])):
		m |= 1
	if x >= w - 1 or same.has(int(ground[y * w + x + 1])):
		m |= 2
	if y >= h - 1 or same.has(int(ground[(y + 1) * w + x])):
		m |= 4
	if x <= 0 or same.has(int(ground[y * w + x - 1])):
		m |= 8
	return m


func _touches_land(ground: PackedByteArray, w: int, h: int, x: int, y: int, water_like: Array) -> bool:
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var xx: int = x + d.x
		var yy: int = y + d.y
		if xx >= 0 and yy >= 0 and xx < w and yy < h and not water_like.has(int(ground[yy * w + xx])):
			return true
	return false


static func feet_px(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * T + 4, cell.y * T + 7)


func _sprite(name: String, at: Vector2, flip: bool = false) -> Sprite2D:
	var m: Dictionary = _ometa.get(name, {})
	if m.is_empty():
		return null
	var r: Array = m["rect"]
	var feet: Array = m["feet"]
	var s := Sprite2D.new()
	s.texture = OBJ_TEX
	s.region_enabled = true
	s.region_rect = Rect2(r[0], r[1], r[2], r[3])
	s.centered = false
	s.flip_h = flip
	s.offset = Vector2(-(float(r[2]) - float(feet[0])) if flip else -float(feet[0]), -float(feet[1]))
	s.position = at
	return s


func _build_objects() -> void:
	var body := StaticBody2D.new()
	body.name = "Colliders"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	world_root.add_child(body)
	for o in data["objects"]:
		var name: String = o["name"]
		var cell: Vector2i = o["cell"]
		var at := feet_px(cell)
		var hsh := absi((cell.x * 92821) ^ (cell.y * 68917))
		var flip: bool = name.begins_with("tree") or name.begins_with("rock") or name.begins_with("bush")
		flip = flip and hsh % 2 == 0
		var region: String = o.get("region", "")
		_cur_region = region
		var kind: String = o.get("kind", "deco")
		if kind == "banner" and Game.world["regions"].get(region, {}).get("cleared", false):
			name = "banner_clear"
		var s := _sprite(name, at, flip)
		if s == null:
			continue
		ysort.add_child(s)
		_track(region, s)
		var m: Dictionary = _ometa[name]
		var col = m.get("collision")
		if col is Array and o.get("solid", true):
			var cs := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = Vector2(col[2], col[3])
			cs.shape = rs
			cs.position = at + Vector2(float(col[0]) + float(col[2]) * 0.5, float(col[1]) + float(col[3]) * 0.5)
			body.add_child(cs)
		match kind:
			"entrance":
				_setup_entrance(name, region, at, s)
			"waystone":
				_setup_waystone(region, at, s)
			"sign":
				var to: String = o.get("to", "")
				interactables.append({"pos": at, "prompt": "Ler a placa", "action": func(): _read_sign(region, to), "region": region})
			"hearth":
				_setup_hearth(region, at, s)
			"lamp":
				_glow(at + Vector2(0, -14), Color(1.0, 0.8, 0.45), 1.0)
			"house":
				_glow(at + Vector2(-8, -8), Color(1.0, 0.7, 0.35), 0.15)
				_glow(at + Vector2(8, -8), Color(1.0, 0.7, 0.35), 0.15)


func _track(region: String, n: Node) -> void:
	if region == "":
		return
	if not _region_nodes.has(region):
		_region_nodes[region] = []
	_region_nodes[region].append(n)


func _setup_entrance(name: String, region: String, at: Vector2, s: Sprite2D) -> void:
	var r: Dictionary = Game.world["regions"][region]
	var fx := EntranceFX.new()
	fx.kind = name
	fx.position = at
	fx.color = _region_color(r)
	fx.cleared = r.get("cleared", false)
	world_root.add_child(fx)
	_track(region, fx)
	if name == "entrance_gate":
		_glow(at + Vector2(-11, -14), Color(1.0, 0.6, 0.25), 0.8)
		_glow(at + Vector2(10, -14), Color(1.0, 0.6, 0.25), 0.8)
	interactables.append({"pos": at + Vector2(0, 2), "prompt": "Entrar: %s" % r["name"], "action": func(): _enter(region, at + Vector2(0, 10)), "region": region, "entrance": true})


func _setup_waystone(region: String, at: Vector2, s: Sprite2D) -> void:
	var cleared: bool = Game.world["regions"][region].get("cleared", false)
	if cleared:
		s.modulate = Color(1.3, 1.5, 1.9)
		_glow(at + Vector2(0, -8), Color(0.5, 0.8, 1.0), 0.7, true)
	interactables.append({"pos": at, "prompt": "Pedra de viagem" if cleared else "Pedra de viagem (apagada)", "action": func(): _use_waystone(region), "region": region})


func _setup_hearth(region: String, at: Vector2, s: Sprite2D) -> void:
	var fx := HearthFX.new()
	fx.position = at + Vector2(0, -7)
	fx.embers = _hearth_power()
	world_root.add_child(fx)
	_glow(at + Vector2(0, -14), Color(1.0, 0.55, 0.2), 0.4 + fx.embers * 1.2, true)
	interactables.append({"pos": at + Vector2(0, 2), "prompt": "A Grande Lareira", "action": _talk_hearth, "region": region})


## Brilho aditivo (noite): postes, janelas, tochas e runas.
func _glow(at: Vector2, c: Color, strength: float, always: bool = false) -> void:
	var g := Sprite2D.new()
	g.texture = LightUtil.soft()
	g.position = at
	g.scale = Vector2.ONE * (0.55 + strength * 0.35)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.modulate = Color(c.r, c.g, c.b, 0.0)
	g.set_meta("strength", strength)
	g.set_meta("always", always)
	_glow_layer.add_child(g)
	_glows.append(g)
	_track(_cur_region, g)


func _build_gates() -> void:
	for g in data["gates"]:
		var req: String = g["requires"]
		var cell: Vector2i = g["cell"]
		var at := Vector2(cell.x * T + 8, cell.y * T + 8)
		var gate := RuneGate.new()
		gate.requires = req
		gate.color = RUNE_COLOR.get(req, Color(2.0, 2.0, 2.4))
		gate.position = at
		gate.open = Game.has_ability(req)
		gate.cells = g["cells"]
		gate.sprite = _sprite("gate_barrier", Vector2.ZERO)
		ysort.add_child(gate)
		_track(g["a"], gate)
		if not gate.open:
			var ab: Dictionary = DB.abilities.get(req, {})
			interactables.append({"pos": at + Vector2(0, 6), "prompt": "Portão rúnico", "action": func():
				Audio.play("ui_error", 0.0, -6.0)
				Events.toast.emit("O portão rúnico só abre com: %s (%s). Derrote o chefe que guarda essa habilidade." % [ab.get("name", req), ab.get("gate_label", "")]), "region": g["a"]})


func _build_npcs() -> void:
	var doors := {} ## região -> [portas das casas]
	for o in data["objects"]:
		if o.get("kind", "") == "house":
			if not doors.has(o["region"]):
				doors[o["region"]] = []
			doors[o["region"]].append(feet_px(o["cell"]) + Vector2(1, 1))
	for id in data["villages"].keys():
		var v: Dictionary = data["villages"][id]
		var cells: Array = v["npc_cells"]
		var houses: Array = doors.get(id, [])
		var i := 0
		for npc in Game.social.get("npcs", {}).values():
			if npc["region"] != id or not npc.get("alive", true):
				continue
			var n := OverworldNPC.new()
			n.npc_id = npc["id"]
			n.spots = cells.map(func(c): return feet_px(c))
			n.position = feet_px(cells[i % cells.size()])
			n.overworld = self
			if not houses.is_empty():
				n.home = houses[i % houses.size()]
			ysort.add_child(n)
			_track(id, n)
			var npc_id: String = npc["id"]
			interactables.append({"pos": Vector2.ZERO, "node": n, "prompt": "Conversar: %s" % npc["name"], "action": func():
				n.greet(hero)
				Events.dialogue_requested.emit(npc_id), "region": id})
			i += 1


func _known_regions() -> Dictionary:
	var k := {}
	for id in Game.world["regions"].keys():
		if Game.world["regions"][id].get("visited", false):
			k[id] = true
			for nb in WorldGenerator.neighbors(Game.world, id):
				k[nb["id"]] = true
	return k


func _build_fog() -> void:
	var w: int = data["w"]
	var h: int = data["h"]
	_fog_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	_fog_sprite = Sprite2D.new()
	_fog_sprite.texture = _fog_tex
	_fog_sprite.centered = false
	_fog_sprite.scale = Vector2(T, T)
	_fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fog_sprite.z_index = 60
	world_root.add_child(_fog_sprite)
	_refresh_fog()


func _refresh_fog() -> void:
	var w: int = data["w"]
	var h: int = data["h"]
	var owner: PackedInt32Array = data["owner"]
	var ids: Array = data["region_ids"]
	var fog := Color(0.1, 0.09, 0.16, 0.94)
	for y in h:
		for x in w:
			var o := owner[y * w + x]
			var hidden := o >= 0 and not known.has(ids[o])
			_fog_img.set_pixel(x, y, fog if hidden else Color(0, 0, 0, 0))
	_fog_tex.update(_fog_img)
	if ui:
		ui.mark_minimap_dirty()
	for id in _region_nodes.keys():
		var vis := known.has(id)
		for n in _region_nodes[id]:
			if is_instance_valid(n):
				n.visible = vis


func _spawn_hero() -> void:
	hero = OverworldHero.new()
	var at := feet_px(data["spawn"])
	var saved = Game.profile.get("ow_pos", null)
	var flags: Dictionary = Game.profile.get("flags", {})
	if not flags.get("ow_started", false):
		# começo do jogo: na praça, ao lado da Grande Lareira
		flags["ow_started"] = true
		Game.profile["flags"] = flags
	elif saved is Array and saved.size() == 2:
		at = Vector2(float(saved[0]), float(saved[1]))
	elif Game.profile.get("region", "") != "" and data["entrances"].has(Game.profile["region"]):
		at = feet_px(data["entrances"][Game.profile["region"]]) + Vector2(0, 10)
	hero.position = at
	ysort.add_child(hero)


# ---------------------------------------------------------------------------
# Laço
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_daylight(delta)
	_update_music()
	_update_focus()
	_region_check()
	_save_t += delta
	if _save_t > 20.0:
		_save_t = 0.0
		_store_position()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("map"):
		_store_position()
		Game.save()
		Game.goto(SCENE_WORLD_VIEW)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		if not focus.is_empty():
			get_viewport().set_input_as_handled()
			var act: Callable = focus["action"]
			act.call()


func _update_focus() -> void:
	var best: Dictionary = {}
	var best_d := INTERACT_R
	var hp := hero.global_position
	for it in interactables:
		var region: String = it.get("region", "")
		if region != "" and not known.has(region):
			continue
		var p: Vector2 = it["pos"]
		if it.has("node"):
			var nd: Node2D = it["node"]
			if not is_instance_valid(nd) or not nd.visible:
				continue
			p = nd.global_position
		var d := hp.distance_to(p)
		if d < best_d:
			best_d = d
			best = it
	focus = best


func _update_daylight(delta: float) -> void:
	var clock: float = fmod(float(Game.profile.get("ow_clock", 0.3)) + delta / DAY_LENGTH, 1.0)
	Game.profile["ow_clock"] = clock
	# 0 = meia-noite, 0.5 = meio-dia
	var sun := 0.5 - 0.5 * cos(clock * TAU)
	night = clampf(1.0 - sun * 1.6, 0.0, 1.0)
	var day_c := Color(1, 1, 1)
	var dusk_c := Color(1.0, 0.82, 0.72)
	var night_c := Color(0.42, 0.46, 0.72)
	var c := day_c.lerp(dusk_c, clampf(night * 2.0, 0.0, 1.0)).lerp(night_c, clampf(night * 2.0 - 1.0, 0.0, 1.0))
	_modulate.color = c
	for g in _glows:
		if not is_instance_valid(g):
			continue
		var always: bool = g.get_meta("always", false)
		var a := night if not always else maxf(night, 0.35)
		a *= 0.75 + 0.25 * float(g.get_meta("strength", 1.0))
		var col: Color = g.modulate
		col.a = a * 0.8 * (0.9 + 0.1 * sin(Time.get_ticks_msec() / 90.0 + g.position.x))
		g.modulate = col
	if hero:
		hero.set_night(night)


## Trilha do mapa: valsa da Lareira nas vilas, Candelária de dia, Noite à noite.
func _update_music() -> void:
	var track := "candelaria"
	var cur := Audio.music_track
	var night_on := night > 0.62 or (cur == "noite" and night > 0.45)
	if night_on:
		track = "noite"
	var cell := hero.global_position / T
	for id in data["villages"].keys():
		var c: Vector2i = data["villages"][id]["center"]
		var near := 14.0 if cur == "lareira" else 11.0
		if known.has(id) and cell.distance_to(Vector2(c)) < near:
			track = "lareira" if not night_on else "noite"
	Audio.music(track, 2.5)


func _region_check() -> void:
	var cell := Vector2i((hero.global_position / T).floor())
	var w: int = data["w"]
	var h: int = data["h"]
	if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
		return
	var o: int = data["owner"][cell.y * w + cell.x]
	if o < 0:
		return
	var id: String = data["region_ids"][o]
	if id != _region_here:
		_region_here = id
		_update_region(false)


func _update_region(first: bool) -> void:
	if _region_here == "":
		var cell := Vector2i((hero.global_position / T).floor())
		var o: int = data["owner"][clampi(cell.y, 0, data["h"] - 1) * data["w"] + clampi(cell.x, 0, data["w"] - 1)]
		if o >= 0:
			_region_here = data["region_ids"][o]
	if _region_here == "":
		return
	var r: Dictionary = Game.world["regions"][_region_here]
	if not r.get("visited", false):
		r["visited"] = true
		known = _known_regions()
		_refresh_fog()
		Game.save()
	ui.show_region(r, first)


# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------

func _store_position() -> void:
	if hero:
		Game.profile["ow_pos"] = [hero.global_position.x, hero.global_position.y]


func _enter(region: String, stand_at: Vector2) -> void:
	Audio.play("ui_confirm")
	Game.profile["ow_pos"] = [stand_at.x, stand_at.y]
	hero.set_physics_process(false)
	ui.fade_out(func(): Game.enter_region(region, true))


func _use_waystone(region: String) -> void:
	if not Game.world["regions"][region].get("cleared", false):
		Audio.play("ui_error", 0.0, -6.0)
		Events.toast.emit("A pedra de viagem desperta quando esta região for limpa.")
		return
	Audio.play("crystal", 0.0, -6.0)
	_store_position()
	Game.save()
	Game.goto(SCENE_WORLD_VIEW)


func _read_sign(region: String, to: String) -> void:
	var r: Dictionary = Game.world["regions"].get(to, {})
	if r.is_empty():
		return
	Audio.play("ui_move", 0.0, -8.0)
	if not known.has(to):
		Events.toast.emit("→ ??? (a estrada some na névoa)")
		return
	var extra := ""
	if r.get("cleared", false):
		extra = " — limpa"
	elif r.get("boss", "") != "":
		extra = " — perigo!"
	Events.toast.emit("→ %s  (%s, tier %d)%s" % [r["name"], DB.biome(r["biome"]).get("name", r["biome"]), int(r["tier"]), extra])


func _hearth_power() -> float:
	var total := maxi(Game.world.get("abilities_order", []).size() + 1, 1)
	return clampf(float(Game.profile.get("bosses_defeated", []).size()) / float(total), 0.0, 1.0)


func _talk_hearth() -> void:
	var p := _hearth_power()
	var text := Lore.hearth_line(p)
	Audio.play("ui_move", 0.0, -6.0)
	ui.show_story("A Grande Lareira", text)


func region_color(id: String) -> Color:
	return _region_color(Game.world["regions"].get(id, {}))


func _region_color(r: Dictionary) -> Color:
	if r.get("dimension", "prima") != "prima":
		return Color(2.2, 0.8, 2.6)
	match r.get("layer", "surface"):
		"sky": return Color(2.4, 2.2, 1.2)
		"underground": return Color(0.9, 1.6, 2.2)
	return Color(2.4, 1.4, 0.6)


## Cor do minimapa por célula.
func mini_color(x: int, y: int) -> Color:
	var w: int = data["w"]
	var k := y * w + x
	var o: int = data["owner"][k]
	if o >= 0 and not known.has(data["region_ids"][o]):
		return Color(0.12, 0.1, 0.18)
	return MINI_COLORS.get(OverworldGen.MATS[data["ground"][k]], Color.MAGENTA)
