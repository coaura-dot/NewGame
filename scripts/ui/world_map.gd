extends Control
## Mapa-múndi (camada MACRO) em pseudo-3D: ilhas de região em três camadas
## (céu / superfície / subterrâneo), rotas coloridas por tipo de gate,
## névoa de guerra, viagem rápida para regiões limpas e o Cerco final.
## Renderizado num SubViewport de baixa resolução => visual pixelado.

const LAYER_COLOR := {"sky": Color(0.75, 0.85, 1.0), "surface": Color(0.55, 0.7, 0.45), "underground": Color(0.45, 0.38, 0.5)}
const EDGE_COLOR := {"road": Color(0.9, 0.8, 0.6), "sky_bridge": Color(0.7, 0.9, 1.2), "tunnel": Color(0.55, 0.45, 0.4), "rift": Color(1.2, 0.5, 2.0)}
const SCALE := 0.42

var _vp: SubViewport
var _cam_pivot: Node3D
var _cam: Camera3D
var _nodes: Dictionary = {} ## region_id -> Node3D
var _selected: String = ""
var _yaw: float = 0.6
var _pitch: float = -0.75
var _dist: float = 44.0
var _info: VBoxContainer
var _ui_panel: Control
var _siege_mode: bool = false
var _marker: MeshInstance3D
var _t: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	Audio.music("noite", 2.0)
	theme = UIKit.theme()
	UIKit.fit(self)
	FX.clear_time_effects()
	if not Game.has_game:
		Game.new_game()
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(svc)
	_vp = SubViewport.new()
	_vp.size = Vector2i(320, 180)
	_vp.own_world_3d = true
	_vp.use_hdr_2d = true
	svc.add_child(_vp)
	_build_3d()
	_build_ui()
	_selected = Game.profile.get("region", Game.world["start"])
	_refresh_info()


# ---------------------------------------------------------------------------
# Cena 3D
# ---------------------------------------------------------------------------

func _mat(c: Color, emission: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	m.roughness = 0.9
	return m


func _build_3d() -> void:
	var root := Node3D.new()
	_vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.32, 0.5)
	env.ambient_light_energy = 0.7
	env.glow_enabled = bool(Settings.video("bloom"))
	env.glow_intensity = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.08, 0.2)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_color = Color(1.0, 0.9, 0.8)
	sun.light_energy = 1.1
	root.add_child(sun)
	_cam_pivot = Node3D.new()
	root.add_child(_cam_pivot)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam_pivot.add_child(_cam)
	# plano da superfície (névoa/terra)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 46)
	ground.mesh = pm
	ground.position.y = -1.2
	ground.material_override = _mat(Color(0.12, 0.1, 0.16), 0.0, 0.55)
	root.add_child(ground)
	# estrelas
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.seed_value
	for i in 120:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		s.mesh = sm
		s.material_override = _mat(Color(1.4, 1.3, 1.8), 2.0)
		s.position = Vector3(rng.randf_range(-70, 70), rng.randf_range(12, 40), rng.randf_range(-70, 70))
		root.add_child(s)
	var known := _known_regions()
	for e in Game.world["edges"]:
		if known.has(e["a"]) or known.has(e["b"]):
			_edge(root, e)
	for id in Game.world["regions"].keys():
		_region(root, id, known.has(id))
	_marker = MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(0.9, 1.2, 0.9)
	_marker.mesh = pr
	_marker.rotation_degrees.z = 180
	_marker.material_override = _mat(Color(2.4, 1.8, 0.6), 3.0)
	root.add_child(_marker)


func _pos(r: Dictionary) -> Vector3:
	var p: Array = r["pos"]
	return Vector3(float(p[0]), float(p[1]), float(p[2])) * SCALE


func _known_regions() -> Dictionary:
	var known := {}
	for id in Game.world["regions"].keys():
		if Game.world["regions"][id].get("visited", false):
			known[id] = true
			for n in WorldGenerator.neighbors(Game.world, id):
				known[n["id"]] = true
	return known


func _region(root: Node3D, id: String, known: bool) -> void:
	var r: Dictionary = Game.world["regions"][id]
	var n := Node3D.new()
	n.position = _pos(r)
	root.add_child(n)
	_nodes[id] = n
	var biome: Dictionary = DB.biome(r["biome"])
	var tint: Array = biome.get("tint", [1, 1, 1])
	var base_c: Color = LAYER_COLOR.get(r["layer"], Color.WHITE) * Color(tint[0], tint[1], tint[2])
	if r.get("destroyed", false):
		base_c = Color(0.15, 0.12, 0.12)
	elif not known:
		base_c = Color(0.18, 0.16, 0.24)
	var island := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.5
	cm.bottom_radius = 0.9 if r["layer"] != "sky" else 0.2
	cm.height = 0.8 if r["layer"] != "sky" else 1.6
	cm.radial_segments = 7
	island.mesh = cm
	var dim_region: bool = r.get("dimension", "prima") != "prima"
	island.material_override = _mat(base_c if not dim_region else Color(0.6, 0.3, 1.0), 0.6 if dim_region else 0.0, 0.75 if dim_region else 1.0)
	n.add_child(island)
	if known and not r.get("destroyed", false):
		if r.get("hub", "") != "":
			var tower := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 1.2, 0.5)
			tower.mesh = bm
			tower.position = Vector3(0.4, 0.9, 0.2)
			tower.material_override = _mat(Color(0.8, 0.7, 0.55))
			n.add_child(tower)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.7, 0.4)
			l.light_energy = 1.5
			l.omni_range = 3.5
			l.position = Vector3(0.4, 1.8, 0.2)
			n.add_child(l)
		if r.get("boss", "") != "" and not r.get("cleared", false):
			var spike := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.5, 0.9, 0.5)
			spike.mesh = pm
			spike.position = Vector3(-0.5, 0.85, 0.0)
			spike.material_override = _mat(Color(2.2, 0.4, 0.3), 2.0)
			n.add_child(spike)
		if r.get("cleared", false):
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 1.6
			tm.outer_radius = 1.8
			ring.mesh = tm
			ring.material_override = _mat(Color(0.5, 2.0, 1.0), 2.0)
			n.add_child(ring)
	var label := Label3D.new()
	label.text = r["name"] if known else "???"
	label.font = UIKit.FONT
	label.font_size = 42
	label.pixel_size = 0.012
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.9, 0)
	label.modulate = Color(1, 0.9, 0.75) if known else Color(0.5, 0.5, 0.6)
	label.no_depth_test = true
	n.add_child(label)


func _edge(root: Node3D, e: Dictionary) -> void:
	var a := _pos(Game.world["regions"][e["a"]])
	var b := _pos(Game.world["regions"][e["b"]])
	var mid := (a + b) * 0.5
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = a.distance_to(b)
	cm.radial_segments = 4
	mi.mesh = cm
	var c: Color = EDGE_COLOR.get(e["kind"], Color.WHITE)
	var locked: bool = e["requires"] != "" and not Game.has_ability(e["requires"])
	if locked:
		c = Color(1.6, 0.3, 0.3) if e["kind"] != "rift" else Color(0.6, 0.2, 0.8)
	mi.material_override = _mat(c, 1.2 if not locked else 0.8)
	root.add_child(mi)
	mi.look_at_from_position(mid, b, Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _process(delta: float) -> void:
	_t += delta
	var target := Vector3.ZERO
	if _nodes.has(_selected):
		target = _nodes[_selected].position
	_cam_pivot.position = _cam_pivot.position.lerp(target, 1.0 - exp(-delta * 4.0))
	_cam_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_cam.position = Vector3(0, 0, _dist * 0.5)
	var cur: String = Game.profile.get("region", "")
	if _nodes.has(cur):
		_marker.position = _nodes[cur].position + Vector3(0, 3.0 + sin(_t * 3.0) * 0.3, 0)
		_marker.rotation.y = _t * 2.0
	for id in _nodes.keys():
		var s := 1.0 + (0.18 + 0.05 * sin(_t * 5.0) if id == _selected else 0.0)
		_nodes[id].scale = Vector3(s, s, s)
	if Input.is_action_pressed("move_left"):
		_yaw -= delta * 1.2
	if Input.is_action_pressed("move_right"):
		_yaw += delta * 1.2


func _unhandled_input(event: InputEvent) -> void:
	if _ui_panel and is_instance_valid(_ui_panel):
		if event.is_action_pressed("pause"):
			_close_panel()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist - 3.0, 18.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist + 3.0, 80.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_pick(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch - event.relative.y * 0.01, -1.4, -0.2)
	elif event.is_action_pressed("move_up"):
		_cycle(1)
	elif event.is_action_pressed("move_down"):
		_cycle(-1)
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_try_enter(_selected)
	elif event.is_action_pressed("pause") or event.is_action_pressed("map"):
		Game.save()
		Game.goto(Game.SCENE_MAP)


func _pick(screen_pos: Vector2) -> void:
	var local := screen_pos / Vector2(320, 180) * Vector2(_vp.size)
	var best := ""
	var best_d := 26.0
	for id in _nodes.keys():
		var p := _cam.unproject_position(_nodes[id].global_position)
		var d := p.distance_to(local)
		if d < best_d and not _cam.is_position_behind(_nodes[id].global_position):
			best_d = d
			best = id
	if best != "":
		if best == _selected:
			_try_enter(best)
		else:
			_selected = best
			Audio.play("ui_move", 0.0, -10.0)
			_refresh_info()


func _cycle(dir: int) -> void:
	var known := _known_regions().keys()
	known.sort()
	if known.is_empty():
		return
	var i := known.find(_selected)
	_selected = known[(i + dir + known.size()) % known.size()]
	Audio.play("ui_move", 0.0, -10.0)
	_refresh_info()


# ---------------------------------------------------------------------------
# Regras de viagem
# ---------------------------------------------------------------------------

func _travel_block(id: String) -> String:
	var r: Dictionary = Game.world["regions"][id]
	if r.get("destroyed", false):
		return "Esta região foi dizimada."
	var cur: String = Game.profile.get("region", "")
	if id == cur:
		return ""
	var reach := WorldGenerator.reachable(Game.world, Game.profile["abilities"])
	if not reach.has(id):
		for n in WorldGenerator.neighbors(Game.world, id):
			if n["requires"] != "" and not Game.has_ability(n["requires"]):
				return "Bloqueado: requer %s (%s)" % [DB.abilities.get(n["requires"], {}).get("name", n["requires"]), DB.abilities.get(n["requires"], {}).get("gate_label", "")]
		return "Inalcançável por enquanto."
	var adjacent := false
	for n in WorldGenerator.neighbors(Game.world, cur):
		if n["id"] == id:
			adjacent = n["requires"] == "" or Game.has_ability(n["requires"])
	if adjacent or r.get("cleared", false) or r.get("visited", false):
		return ""
	return "Longe demais: avance por regiões vizinhas."


func _try_enter(id: String) -> void:
	if _siege_mode:
		_confirm_siege(id)
		return
	var why := _travel_block(id)
	if why != "":
		Audio.play("ui_error", 0.0, -6.0)
		_flash_info(why)
		return
	Audio.play("ui_confirm")
	Game.enter_region(id)


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var p := UIKit.panel(Vector2(170, 0))
	p.position = Vector2(302, 8)
	add_child(p)
	_info = UIKit.vbox(2)
	p.add_child(_info)
	var help := UIKit.label("Clique/W-S: escolher  •  Espaço/Enter: viajar  •  A-D/botão dir.: girar  •  roda: zoom  •  Esc/M: voltar a andar", 9, UIKit.DIM)
	help.position = Vector2(8, 256)
	add_child(help)
	var top := UIKit.hbox(6)
	top.position = Vector2(8, 8)
	add_child(top)
	top.add_child(UIKit.label("Seed %d" % Game.seed_value, 10, UIKit.DIM))
	top.add_child(UIKit.label("Reputação %d (%s)" % [SocialSystem.reputation(Game.social), SocialSystem.reputation_band(SocialSystem.reputation(Game.social), DB)], 10, UIKit.GOLD))
	var btns := UIKit.vbox(3)
	btns.position = Vector2(8, 24)
	add_child(btns)
	if Game.is_siege_ready() and not Game.social.get("siege", {}).get("started", false):
		btns.add_child(UIKit.button("⚠ O CERCO COMEÇOU", _start_siege_choice, 130))
	if OS.is_debug_build():
		btns.add_child(UIKit.button("(debug) forçar o Cerco", _start_siege_choice, 130))


func _flash_info(text: String) -> void:
	_refresh_info()
	var l := UIKit.label(text, 10, Color(1.6, 0.6, 0.5))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(160, 0)
	_info.add_child(l)


func _refresh_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	if _selected == "" or not Game.world["regions"].has(_selected):
		return
	var r: Dictionary = Game.world["regions"][_selected]
	var known := _known_regions().has(_selected)
	var name_l := UIKit.label(r["name"] if known else "Região desconhecida", 12, UIKit.GOLD)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_l.custom_minimum_size = Vector2(160, 0)
	_info.add_child(name_l)
	if not known:
		_info.add_child(UIKit.label("Explore regiões vizinhas.", 10, UIKit.DIM))
		return
	var layer_name := {"sky": "Céu", "surface": "Superfície", "underground": "Subterrâneo"}
	_info.add_child(UIKit.label("%s • %s • Tier %d" % [DB.biome(r["biome"]).get("name", r["biome"]), layer_name.get(r["layer"], ""), int(r["tier"])], 10))
	if Level.region_theme(r) == "frenesi":
		_info.add_child(UIKit.label("FRENESI: zigue-zague sobre espinhos, sem chão", 10, Color(0.75, 0.3, 0.1)))
	if r.get("dimension", "prima") != "prima":
		var d := DB.dimension(r["dimension"])
		var dl := UIKit.label("Mundo paralelo: %s — %s" % [d.get("name", ""), d.get("desc", "")], 10, Color(1.4, 0.8, 2.2))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dl.custom_minimum_size = Vector2(160, 0)
		_info.add_child(dl)
	if r.get("hub", "") != "":
		var names := []
		for npc in Game.social.get("npcs", {}).values():
			if npc["region"] == _selected:
				names.append("%s (%s)" % [npc["name"].split(" ")[0], "♥".repeat(SocialSystem.hearts(int(npc["affinity"])))])
		var hl := UIKit.label("Hub: %s — %s" % [r["hub"], ", ".join(names)], 10, Color(1.0, 0.8, 0.6))
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hl.custom_minimum_size = Vector2(160, 0)
		_info.add_child(hl)
	if r.get("boss", "") != "":
		_info.add_child(UIKit.label("Chefe: %s%s" % [DB.enemy(r["boss"]).get("name", ""), " (derrotado)" if r.get("cleared", false) else ""], 10, Color(1.5, 0.6, 0.5)))
	var gains: Array = r.get("rewards", []).duplicate()
	if r.get("grants", "") != "":
		gains.append(r["grants"])
	if not gains.is_empty() and not r.get("cleared", false):
		_info.add_child(UIKit.label("Recompensa: " + ", ".join(gains.map(func(g): return DB.abilities.get(g, {}).get("name", g))), 10, Color(0.7, 1.5, 2.0)))
	if r.get("optional", false):
		_info.add_child(UIKit.label("Opcional", 10, UIKit.DIM))
	var status := "Limpa (viagem rápida)" if r.get("cleared", false) else ("Visitada" if r.get("visited", false) else "Inexplorada")
	if r.get("destroyed", false):
		status = "Dizimada"
	_info.add_child(UIKit.label(status, 10, UIKit.DIM))
	var why := _travel_block(_selected)
	if why == "":
		_info.add_child(UIKit.button("Entrar", func(): _try_enter(_selected), 120))
	else:
		var wl := UIKit.label(why, 10, Color(1.5, 0.7, 0.5))
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD
		wl.custom_minimum_size = Vector2(160, 0)
		_info.add_child(wl)


func _close_panel() -> void:
	if _ui_panel and is_instance_valid(_ui_panel):
		_ui_panel.queue_free()
	_ui_panel = null
	_siege_mode = false


func _start_siege_choice() -> void:
	_siege_mode = true
	var p := UIKit.panel(Vector2(300, 0))
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.title("O Cerco", 22))
	var l := UIKit.label("Todas as regiões estão sendo atacadas ao mesmo tempo. Você só pode estar em um lugar. Escolha a região que vai defender: todas as outras — com seus povos, amigos, amores e a reputação que você construiu — serão dizimadas.", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(280, 0)
	v.add_child(l)
	v.add_child(UIKit.label("Selecione a região no mapa e confirme.", 10, UIKit.DIM))
	v.add_child(UIKit.button("Cancelar", _close_panel, 80))
	_ui_panel = p
	p.position = Vector2(8, 150)
	add_child(p)


func _confirm_siege(id: String) -> void:
	var r: Dictionary = Game.world["regions"][id]
	if r.get("destroyed", false) or r.get("dimension", "prima") != "prima":
		_flash_info("Escolha uma região do mundo principal.")
		return
	var c := SocialSystem.siege_consequences(Game.world, Game.social, id)
	if _ui_panel:
		_ui_panel.queue_free()
	var p := UIKit.panel(Vector2(320, 0))
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.title("Defender %s?" % r["name"], 16))
	v.add_child(UIKit.label("Regiões perdidas: %d" % c["lost_regions"].size(), 11, Color(1.5, 0.6, 0.5)))
	var names := []
	for n in c["lost_npcs"].slice(0, 6):
		names.append("%s %s" % [n["name"], "♥".repeat(SocialSystem.hearts(int(n["affinity"])))])
	if not names.is_empty():
		var nl := UIKit.label("Quem você perde: " + ", ".join(names) + ("…" if c["lost_npcs"].size() > 6 else ""), 10)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD
		nl.custom_minimum_size = Vector2(300, 0)
		v.add_child(nl)
	if c["spouse_lost"]:
		v.add_child(UIKit.label("Seu cônjuge não está nesta região.", 11, Color(2.0, 0.5, 0.6)))
	var row := UIKit.hbox(6)
	row.add_child(UIKit.button("Defender esta região", func():
		SocialSystem.apply_siege(Game.world, Game.social, id)
		Game.profile["region"] = id
		Game.save()
		Game.pending = {"region": id, "siege": true}
		Game.goto(Game.SCENE_LEVEL), 150))
	row.add_child(UIKit.button("Voltar", _close_panel, 70))
	v.add_child(row)
	_ui_panel = p
	p.position = Vector2(80, 60)
	add_child(p)
	UIKit.focus_first(p)
