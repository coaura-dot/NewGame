class_name AmbientLife
extends Node2D
## Vida no mapa-múndi, desenhada num nó só (sem um nó por partícula) e só em
## volta da tela: brilho na água, fumaça das chaminés e, conforme o bioma
## embaixo da câmera e a hora, borboletas e pássaros de dia, vaga-lumes à
## noite, folhas caindo, neve, areia ao vento, bolhas no pântano e cintilar
## nas nuvens.
##
## Dois modos: "world" (afetado pela noite — borboletas, pássaros, folhas,
## fumaça, água) e "glow" (numa CanvasLayer fora do escurecimento — vaga-lumes
## e cintilar, que precisam brilhar no escuro).

const T := 8
const MAX := 90

var overworld: Node = null
var glow: bool = false
var _p: Array = [] ## [kind, pos, vel, life, max_life, seed]
var _t: float = 0.0
var _spawn_acc: Dictionary = {}
var _houses: Array = [] ## Vector2 (chaminé)


func _ready() -> void:
	z_index = 45 if glow else 30
	if overworld:
		for o in overworld.data["objects"]:
			if o.get("kind", "") == "house":
				_houses.append(Overworld.feet_px(o["cell"]) + Vector2(8, -30))


func _view() -> Rect2:
	var c: Vector2 = overworld.camera.center if overworld and overworld.camera else Vector2.ZERO
	return Rect2(c - Vector2(172, 100), Vector2(344, 200))


func _biome_here() -> String:
	var c: Vector2 = overworld.camera.center / T
	var w: int = overworld.data["w"]
	var h: int = overworld.data["h"]
	var x := clampi(int(c.x), 0, w - 1)
	var y := clampi(int(c.y), 0, h - 1)
	var o: int = overworld.data["owner"][y * w + x]
	if o < 0:
		return "mar"
	var id: String = overworld.data["region_ids"][o]
	if not overworld.known.has(id):
		return ""
	var r: Dictionary = Game.world["regions"][id]
	if r.get("dimension", "prima") != "prima":
		return "fenda"
	if r.get("layer", "") == "sky":
		return "ceu"
	return str(r.get("biome", ""))


func _ground_at(p: Vector2) -> String:
	var w: int = overworld.data["w"]
	var h: int = overworld.data["h"]
	var x := int(p.x / T)
	var y := int(p.y / T)
	if x < 0 or y < 0 or x >= w or y >= h:
		return ""
	return OverworldGen.MATS[overworld.data["ground"][y * w + x]]


func _rate(kind: String, per_s: float, delta: float, view: Rect2, where: Callable) -> void:
	_spawn_acc[kind] = float(_spawn_acc.get(kind, 0.0)) + per_s * delta
	while _spawn_acc[kind] >= 1.0 and _p.size() < MAX:
		_spawn_acc[kind] -= 1.0
		var pos := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
		var got: Variant = where.call(pos, view)
		if got is Vector2:
			_spawn(kind, got)
	_spawn_acc[kind] = minf(_spawn_acc[kind], 3.0)


func _spawn(kind: String, pos: Vector2) -> void:
	var vel := Vector2.ZERO
	var life := 3.0
	match kind:
		"firefly":
			vel = Vector2(randf_range(-6, 6), randf_range(-4, 4))
			life = randf_range(3.0, 6.0)
		"butterfly":
			vel = Vector2(randf_range(-14, 14), randf_range(-5, 5))
			life = randf_range(4.0, 7.0)
		"bird":
			vel = Vector2(70.0 if randf() < 0.5 else -70.0, randf_range(-8, 8))
			life = 6.0
		"leaf":
			vel = Vector2(randf_range(4, 12), randf_range(10, 16))
			life = randf_range(3.0, 5.0)
		"snow":
			vel = Vector2(randf_range(-4, 4), randf_range(14, 22))
			life = randf_range(4.0, 7.0)
		"sand":
			vel = Vector2(randf_range(40, 70), randf_range(-3, 3))
			life = randf_range(1.5, 3.0)
		"bubble":
			vel = Vector2(0, -4)
			life = randf_range(0.8, 1.6)
		"sparkle":
			life = randf_range(0.5, 1.0)
		"shimmer":
			life = randf_range(0.4, 0.9)
		"smoke":
			vel = Vector2(randf_range(-2, 3), -9)
			life = randf_range(2.0, 3.0)
	_p.append([kind, pos, vel, life, life, randf() * 100.0])


func _process(delta: float) -> void:
	if overworld == null or overworld.camera == null:
		return
	_t += delta
	var view := _view()
	var night: float = overworld.night
	var biome := _biome_here()
	var on_land := func(pos: Vector2, _v: Rect2):
		var g := _ground_at(pos)
		return pos if g in ["grass", "grass_dark", "swamp", "arcane", "ruin", "forest_floor", "red_dirt", "cobble", "plaza"] else null
	if glow:
		if night > 0.45 and biome in ["floresta", "pantano", "cemiterio", "ruinas", "cidade_magos", "cidade_gotica", "castelo"]:
			_rate("firefly", 5.0 * night, delta, view, on_land)
		if biome in ["ceu", "fenda", "cidade_ceu"]:
			_rate("sparkle", 6.0, delta, view, func(pos, _v): return pos)
	else:
		var water := func(pos: Vector2, _v: Rect2):
			return pos if _ground_at(pos) in ["water", "deep_water"] else null
		_rate("shimmer", 24.0, delta, view, water)
		if night < 0.5:
			if biome in ["floresta", "ruinas", "cidade_gotica", "cidade_magos"]:
				_rate("butterfly", 0.8, delta, view, on_land)
			if biome != "" and biome not in ["catacumbas", "cidade_subterranea", "toca_goblin", "mar"] and randf() < delta * 0.08:
				var y := randf_range(view.position.y + 20, view.end.y - 40)
				_spawn("bird", Vector2(view.position.x - 8 if randf() < 0.5 else view.end.x + 8, y))
				var b: Array = _p[-1]
				b[2].x = 70.0 if b[1].x < view.get_center().x else -70.0
		match biome:
			"floresta", "ruinas":
				_rate("leaf", 1.5, delta, view, func(pos, _v): return Vector2(pos.x, view.position.y - 4))
			"acampamento_barbaro":
				_rate("snow", 14.0, delta, view, func(pos, _v): return Vector2(pos.x, view.position.y - 4))
			"deserto", "templo_dourado":
				_rate("sand", 5.0, delta, view, func(pos, _v): return Vector2(view.position.x - 4, pos.y))
			"pantano":
				_rate("bubble", 3.0, delta, view, water)
		# fumaça das chaminés visíveis
		for hpos in _houses:
			if view.grow(20).has_point(hpos) and randf() < delta * 1.6:
				_spawn("smoke", hpos + Vector2(randf_range(-1, 1), 0))
	# atualiza
	for p in _p:
		p[3] -= delta
		var k: String = p[0]
		match k:
			"firefly":
				p[2] += Vector2(sin(_t * 1.3 + p[5]), cos(_t * 1.1 + p[5] * 2.0)) * 6.0 * delta
				p[2] = p[2].limit_length(9.0)
			"butterfly":
				p[2].y += sin(_t * 9.0 + p[5]) * 40.0 * delta
				p[2] = p[2].limit_length(18.0)
			"leaf":
				p[2].x = 8.0 + sin(_t * 2.0 + p[5]) * 10.0
			"smoke":
				p[2].x += sin(_t + p[5]) * 2.0 * delta
		p[1] += p[2] * delta
	_p = _p.filter(func(p): return p[3] > 0.0 and view.grow(40).has_point(p[1]))
	queue_redraw()


func _px(at: Vector2, c: Color, s: float = 1.0) -> void:
	draw_rect(Rect2(at.round(), Vector2(s, s)), c)


func _draw() -> void:
	for p in _p:
		var k: String = p[0]
		var pos: Vector2 = p[1]
		var f: float = clampf(p[3] / float(p[4]), 0.0, 1.0) ## 1 = nasceu
		var fade := minf(f * 3.0, minf((1.0 - f) * 4.0, 1.0))
		match k:
			"firefly":
				var blink := 0.5 + 0.5 * sin(_t * 4.0 + float(p[5]) * 3.0)
				_px(pos, Color(1.8, 2.4, 0.6, fade * blink))
				_px(pos - Vector2(1, 0), Color(0.9, 1.4, 0.3, fade * blink * 0.4))
			"sparkle":
				var a := sin((1.0 - f) * PI)
				_px(pos, Color(2.6, 2.6, 2.0, a))
				if a > 0.6:
					_px(pos + Vector2(1, 0), Color(2.0, 2.0, 1.6, a * 0.5))
					_px(pos - Vector2(1, 0), Color(2.0, 2.0, 1.6, a * 0.5))
					_px(pos + Vector2(0, 1), Color(2.0, 2.0, 1.6, a * 0.5))
					_px(pos - Vector2(0, 1), Color(2.0, 2.0, 1.6, a * 0.5))
			"butterfly":
				var cols := [Color(1.0, 0.85, 0.3), Color(0.95, 0.5, 0.75), Color(0.6, 0.8, 1.0), Color(1.0, 1.0, 0.95)]
				var c: Color = cols[int(p[5]) % cols.size()]
				c.a = fade
				var open := sin(_t * 18.0 + float(p[5])) > 0.0
				_px(pos, Color(0.2, 0.15, 0.2, fade))
				if open:
					_px(pos + Vector2(-1, -1), c)
					_px(pos + Vector2(1, -1), c)
				else:
					_px(pos + Vector2(0, -1), c)
			"bird":
				var flap := int(_t * 8.0 + float(p[5])) % 2 == 0
				var dx := signf(p[2].x)
				var c2 := Color(0.15, 0.12, 0.2, fade)
				_px(pos, c2)
				_px(pos + Vector2(-1, -1 if flap else 0), c2)
				_px(pos + Vector2(1, -1 if flap else 0), c2)
				# sombra no chão, bem abaixo
				_px(pos + Vector2(-dx * 2, 26), Color(0, 0, 0, 0.18 * fade))
				_px(pos + Vector2(-dx * 2 + 1, 26), Color(0, 0, 0, 0.18 * fade))
			"leaf":
				var lc := [Color(0.85, 0.55, 0.2), Color(0.75, 0.35, 0.2), Color(0.5, 0.7, 0.3)]
				var l: Color = lc[int(p[5]) % lc.size()]
				l.a = fade
				_px(pos, l)
				if int(_t * 5.0 + float(p[5])) % 2 == 0:
					_px(pos + Vector2(1, 0), l)
			"snow":
				_px(pos, Color(1.0, 1.0, 1.0, fade * 0.9))
			"sand":
				_px(pos, Color(1.0, 0.9, 0.7, fade * 0.6))
			"bubble":
				var r := 1.0 + (1.0 - f) * 1.5
				draw_arc(pos.round(), r, 0.0, TAU, 6, Color(0.8, 0.95, 0.8, fade * 0.7), 1.0)
			"shimmer":
				var a2 := sin((1.0 - f) * PI) * 0.8
				_px(pos, Color(0.85, 0.95, 1.0, a2))
				_px(pos + Vector2(1, 0), Color(0.85, 0.95, 1.0, a2 * 0.6))
			"smoke":
				var s := 1.0 + (1.0 - f) * 2.0
				draw_rect(Rect2(pos.round(), Vector2(s, s)), Color(0.72, 0.7, 0.75, fade * 0.5))
