class_name BackgroundLayer
extends CanvasLayer
## Cenário de fundo em camadas (pixel art gerada por tools/build_scenery.py,
## resolução 480x270): céu fixo + N camadas com parallax (longe -> perto,
## data/scenery.json -> layers) e VIDA por cima —
## nuvens, névoa que anda, raios de sol, pássaros em bando e um "evento" por
## estilo (relâmpagos no castelo, um titã caminhando atrás da cidade gótica,
## verme gigante nas dunas, baleia do céu, olhos na caverna, catapultas na
## guerra, morcegos cruzando a lua, fogos-fátuos no pântano).
## Inspiração: Kingdom Two Crowns, Blasphemous, Dead Cells.

const DIR := "res://assets/art/scenery/"
const LAYER_W := 960.0
## A "vida" (pássaros, névoa, eventos) é desenhada numa tela virtual de
## metade da resolução com escala 2 (pixels de 2x2, como os antigos).
const LIFE := 2.0

static var _meta: Dictionary = {}

var camera: Camera2D = null
## Tamanho da tela onde o cenário é desenhado (480x270)
var W: float = LevelConst.VIEW_PX.x
var H: float = LevelConst.VIEW_PX.y
## Tela virtual da vida (W/2 x H/2)
var VW: float = 240.0
var VH: float = 135.0
var _cloud_tex: Array = []
var style_id: String = "forest"
var tint: Color = Color.WHITE
## Linha de referência (y do mundo) em que as camadas ficam na posição de
## descanso; mais fundo que isso as camadas sobem (vê-se a base delas).
var ref_y: float = 0.0
var meta: Dictionary = {}
var _sky: Texture2D
var _sky_top: Color = Color.BLACK
var _sky_bottom: Color = Color.BLACK
var _layers: Array = [] ## [Texture2D, parallax, vparallax, Color fill]
var _draw: Control
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
# vida
var _clouds: Array = [] ## [x, y, raio, velocidade, profundidade]
var _flocks: Array = [] ## [x, y, vx, n, fase, escala]
var _next_flock: float = 3.0
var _event_t: float = 0.0
var _event: Dictionary = {}
var _flash: float = 0.0
var _bolts: Array = [] ## relâmpagos: [pontos, vida]
var _wisps: Array = []
var _eyes: Array = []


static func load_meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open("res://data/scenery.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_meta = d
	return _meta


func build(set_id: String, color: Color, level_top: float = 0.0) -> void:
	style_id = set_id if load_meta().has(set_id) else "forest"
	meta = load_meta().get(style_id, {})
	tint = color
	ref_y = level_top + H * 0.8
	VW = W / LIFE
	VH = H / LIFE
	layer = -10
	_rng.seed = hash(style_id)
	_sky = _tex("sky")
	if _sky:
		var img := _sky.get_image()
		_sky_top = img.get_pixel(0, 0)
		_sky_bottom = img.get_pixel(0, img.get_height() - 1)
	for L in meta.get("layers", []):
		var tex := _tex(str(L.get("file", "")))
		if tex:
			_layers.append([tex, float(L.get("par", 0.1)), float(L.get("vpar", 0.03)), Color(str(L.get("fill", "#000000")))])
	for k in 4:
		var ct := _tex("cloud%d" % k)
		if ct:
			_cloud_tex.append(ct)
	_draw = Control.new()
	_draw.size = Vector2(W, H)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)
	_setup_life()


func _tex(n: String) -> Texture2D:
	var path := DIR + style_id + "/" + n + ".png"
	return load(path) if ResourceLoader.exists(path) else null


func _setup_life() -> void:
	var outdoor: bool = not meta.get("underground", false)
	if outdoor and style_id in ["forest", "ruins", "sky", "desert", "swamp", "war"]:
		for i in (9 if style_id == "sky" else 5):
			_clouds.append([_rng.randf() * LAYER_W, _rng.randf_range(12, 110), _rng.randi_range(0, 3), _rng.randf_range(3, 10), _rng.randf_range(0.03, 0.12)])
	match str(meta.get("event", "")):
		"wisps":
			for i in 7:
				_wisps.append([_rng.randf() * LAYER_W * 0.5, _rng.randf_range(70, 118), _rng.randf() * TAU])
		"eyes":
			for i in 6:
				_eyes.append([_rng.randf() * LAYER_W * 0.5, _rng.randf_range(30, 110), _rng.randf_range(0, 6), _rng.randf() < 0.5])
	_event_t = _rng.randf_range(4.0, 10.0)


# ---------------------------------------------------------------------------
# Atualização
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	for c in _clouds:
		c[0] = fposmod(c[0] + c[3] * delta, LAYER_W)
	# pássaros
	if meta.get("birds", false) or str(meta.get("event", "")) == "birds":
		_next_flock -= delta
		if _next_flock <= 0.0:
			_next_flock = _rng.randf_range(7.0, 16.0)
			var dir := 1.0 if _rng.randf() < 0.5 else -1.0
			var scale := _rng.randf_range(0.8, 1.6)
			_flocks.append([-20.0 if dir > 0 else VW + 20.0, _rng.randf_range(16, 60), dir * _rng.randf_range(14, 26) * scale, _rng.randi_range(3, 7), _rng.randf() * TAU, scale])
			if _rng.randf() < 0.6:
				Audio.play("birds", 0.1, -14.0)
	for f in _flocks:
		f[0] += f[2] * delta
		f[4] += delta * 10.0
	_flocks = _flocks.filter(func(f): return f[0] > -60.0 and f[0] < VW + 60.0)
	for b in _bolts:
		b[1] -= delta
	_bolts = _bolts.filter(func(b): return b[1] > 0.0)
	_update_event(delta)
	if _draw:
		_draw.queue_redraw()


func _update_event(delta: float) -> void:
	var ev := str(meta.get("event", ""))
	_event_t -= delta
	match ev:
		"storm":
			if _event_t <= 0.0:
				_event_t = _rng.randf_range(5.0, 12.0)
				_flash = 1.0
				var pts := PackedVector2Array()
				var x := _rng.randf_range(20, VW - 20)
				var y := 0.0
				while y < 90.0:
					pts.append(Vector2(x, y))
					x += _rng.randf_range(-7, 7)
					y += _rng.randf_range(6, 12)
				_bolts.append([pts, 0.18])
				get_tree().create_timer(_rng.randf_range(0.4, 1.2), false).timeout.connect(func(): Audio.play("thunder", 0.1, -8.0))
		"titan", "whale", "sandworm", "catapults", "bats":
			if _event.is_empty() and _event_t <= 0.0:
				_start_event(ev)
			elif not _event.is_empty():
				_event["t"] = float(_event["t"]) + delta
				if float(_event["t"]) >= float(_event["life"]):
					_event = {}
					_event_t = _rng.randf_range(8.0, 20.0) if ev != "titan" else _rng.randf_range(20.0, 40.0)


func _start_event(ev: String) -> void:
	match ev:
		"titan":
			_event = {"t": 0.0, "life": 70.0, "dir": 1.0 if _rng.randf() < 0.5 else -1.0}
		"whale":
			_event = {"t": 0.0, "life": 45.0, "dir": 1.0 if _rng.randf() < 0.5 else -1.0, "y": _rng.randf_range(24, 50)}
		"sandworm":
			_event = {"t": 0.0, "life": 3.2, "x": _rng.randf_range(40, VW - 40)}
			Audio.play("rumble", 0.1, -10.0)
		"catapults":
			_event = {"t": 0.0, "life": 2.4, "x0": _rng.randf_range(-20, VW * 0.4), "x1": _rng.randf_range(VW * 0.5, VW + 20), "h": _rng.randf_range(40, 80)}
		"bats":
			_event = {"t": 0.0, "life": 7.0, "dir": 1.0 if _rng.randf() < 0.5 else -1.0, "y": _rng.randf_range(20, 50)}


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _cam() -> Vector2:
	return camera.get_screen_center_position() if camera else Vector2.ZERO


## Deslocamento vertical (px da tela) de uma camada com parallax vertical `vpar`.
func _vy(vpar: float) -> float:
	return roundf(clampf((_cam().y - ref_y) * vpar * LevelConst.ART, -46.0, 68.0))


## O mesmo, na tela virtual da vida.
func _lvy(vpar: float) -> float:
	return roundf(_vy(vpar) / LIFE)


func _on_draw() -> void:
	var cam := _cam() * LevelConst.ART # posição da câmera em px de tela
	var lcam := cam / LIFE
	var sky_off := _vy(0.015)
	var flash_mod := Color(1, 1, 1).lerp(Color(1.6, 1.6, 1.9), _flash)
	if _sky:
		_draw.draw_texture_rect(_sky, Rect2(0, -sky_off, maxf(W, _sky.get_width()), _sky.get_height()), false, tint * flash_mod)
		if sky_off < 0.0:
			_draw.draw_rect(Rect2(0, 0, W, -sky_off + 1), _sky_top * tint * flash_mod)
		elif sky_off > 0.0:
			_draw.draw_rect(Rect2(0, H - sky_off - 1, W, sky_off + 1), _sky_bottom * tint * flash_mod)
	# evento bem ao fundo (atrás de tudo)
	_life(true)
	_draw_event_far(lcam)
	for b in _bolts:
		_draw.draw_polyline(b[0], Color(3, 3, 3.4, clampf(b[1] * 8.0, 0.0, 1.0)), 1.0)
	_life(false)
	var n := _layers.size()
	for i in n:
		var L: Array = _layers[i]
		if i == 1:
			_draw_clouds(cam)
			_life(true)
			_draw_fog(0, lcam)
			_life(false)
		if i == maxi(n - 2, 1):
			_life(true)
			_draw_wisps(lcam)
			_draw_flocks()
			_draw_rays()
			_life(false)
		_draw_layer(L[0], cam.x * float(L[1]), _vy(float(L[2])), L[3], flash_mod)
	_life(true)
	_draw_fog(1, lcam)
	_life(false)


## Liga/desliga a escala da tela virtual da vida.
func _life(on: bool) -> void:
	if on:
		_draw.draw_set_transform(Vector2.ZERO, 0.0, Vector2(LIFE, LIFE))
	else:
		_draw.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_layer(tex: Texture2D, scroll: float, dy: float, fill: Color, mod: Color) -> void:
	var off := fposmod(roundf(scroll), LAYER_W)
	var x := -off
	var y := -dy
	while x < W:
		_draw.draw_texture(tex, Vector2(x, y), tint * mod)
		x += LAYER_W
	var bottom := y + tex.get_height()
	if bottom < H:
		_draw.draw_rect(Rect2(0, bottom - 1, W, H - bottom + 1), fill * tint * mod)


func _draw_clouds(cam: Vector2) -> void:
	if _cloud_tex.is_empty():
		return
	for c in _clouds:
		var tex: Texture2D = _cloud_tex[int(c[2]) % _cloud_tex.size()]
		var x: float = fposmod(float(c[0]) - cam.x * float(c[4]), LAYER_W) - tex.get_width()
		if x > W:
			continue
		var y: float = float(c[1]) - _vy(0.02)
		_draw.draw_texture(tex, Vector2(roundf(x), roundf(y)), tint)


func _draw_fog(band: int, cam: Vector2) -> void:
	var a: float = float(meta.get("fog_alpha", 0.15)) * (1.0 if band == 0 else 0.6)
	if a <= 0.0:
		return
	var c := Color(str(meta.get("fog", "#ffffff")))
	c.a = a
	var base := 104.0 if band == 0 else 128.0
	base -= _lvy(0.1 if band == 0 else 0.2)
	var speed := 4.0 if band == 0 else 9.0
	var sx := _t * speed + cam.x * (0.25 if band == 0 else 0.5)
	var x := 0.0
	while x < VW:
		var wave := sin((x + sx) * 0.05) * 3.0 + sin((x + sx) * 0.013 + 1.7) * 5.0
		var top := roundf(base + wave)
		_draw.draw_rect(Rect2(x, top, 4, VH - top), c)
		x += 4.0


func _draw_rays() -> void:
	if not meta.get("rays", false):
		return
	for i in 3:
		var a := 0.05 + 0.03 * sin(_t * 0.6 + i * 2.0)
		var x0 := 120.0 + i * 46.0 + sin(_t * 0.2 + i) * 6.0
		var pts := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 14, 0), Vector2(x0 - 40, VH), Vector2(x0 - 70, VH)])
		_draw.draw_colored_polygon(pts, Color(1.0, 0.97, 0.85, a))


func _draw_flocks() -> void:
	for f in _flocks:
		var sc: float = f[5]
		for i in int(f[3]):
			var bx: float = float(f[0]) - signf(float(f[2])) * (i * 7.0 * sc) + sin(i * 1.7) * 3.0
			var by: float = float(f[1]) + absf(i - float(f[3]) * 0.5) * 3.0 * sc + sin(float(f[4]) * 0.2 + i) * 1.5
			var up := sin(float(f[4]) + i * 0.8) > 0.0
			var c := Color(0.12, 0.12, 0.18, 0.85)
			var w := roundf(2.0 * sc)
			var p := Vector2(roundf(bx), roundf(by))
			if up:
				_draw.draw_line(p + Vector2(-w, -1), p, c, 1.0)
				_draw.draw_line(p, p + Vector2(w, -1), c, 1.0)
			else:
				_draw.draw_line(p + Vector2(-w, 1), p, c, 1.0)
				_draw.draw_line(p, p + Vector2(w, 1), c, 1.0)


func _draw_wisps(cam: Vector2) -> void:
	for w in _wisps:
		var x: float = fposmod(float(w[0]) - cam.x * 0.25 + sin(_t * 0.4 + float(w[2])) * 10.0, LAYER_W * 0.5)
		if x > VW:
			continue
		var y: float = float(w[1]) + sin(_t * 1.3 + float(w[2])) * 4.0 - _lvy(0.1)
		var a := 0.6 + 0.4 * sin(_t * 3.0 + float(w[2]) * 3.0)
		_draw.draw_circle(Vector2(x, y), 3.0, Color(0.6, 1.4, 1.0, 0.18 * a))
		_draw.draw_rect(Rect2(roundf(x), roundf(y), 1, 1), Color(1.4, 2.6, 1.8, a))


func _draw_event_far(cam: Vector2) -> void:
	var ev := str(meta.get("event", ""))
	var dy := _lvy(0.04)
	if ev == "eyes":
		for e in _eyes:
			var x: float = fposmod(float(e[0]) - cam.x * 0.1, LAYER_W * 0.5)
			if x > VW:
				continue
			var blink := fposmod(_t + float(e[2]), 6.0)
			if blink < 0.15 or (blink > 3.0 and blink < 3.12):
				continue
			var y: float = float(e[1]) - dy
			var c := Color(2.4, 0.6, 0.3) if e[3] else Color(1.4, 2.2, 0.6)
			_draw.draw_rect(Rect2(roundf(x), roundf(y), 1, 1), c)
			_draw.draw_rect(Rect2(roundf(x) + 3, roundf(y), 1, 1), c)
		return
	if _event.is_empty():
		return
	var t: float = _event["t"]
	match ev:
		"titan":
			# gigante magro caminhando devagar atrás da cidade (olhos acesos)
			var k := t / float(_event["life"])
			var dir: float = _event["dir"]
			var x := lerpf(-60.0, VW + 60.0, k) if dir > 0 else lerpf(VW + 60.0, -60.0, k)
			var step := sin(t * 1.2)
			var base := 118.0 - dy
			var c := Color(0.16, 0.16, 0.26, 0.9) * tint
			var hx := roundf(x)
			_draw.draw_rect(Rect2(hx - 6, base - 88, 12, 40), c) # tronco
			_draw.draw_rect(Rect2(hx - 4, base - 100, 8, 12), c) # cabeça
			_draw.draw_rect(Rect2(hx - 3 + step * 5.0, base - 48, 3, 48), c) # pernas
			_draw.draw_rect(Rect2(hx + 1 - step * 5.0, base - 48, 3, 48), c)
			_draw.draw_rect(Rect2(hx - 9 - step * 3.0, base - 86, 3, 36), c) # braços
			_draw.draw_rect(Rect2(hx + 6 + step * 3.0, base - 86, 3, 36), c)
			var eye := Color(2.6, 1.6, 0.6, 0.9)
			_draw.draw_rect(Rect2(hx - 2 + dir, base - 96, 1, 1), eye)
			_draw.draw_rect(Rect2(hx + 1 + dir, base - 96, 1, 1), eye)
		"whale":
			var k2 := t / float(_event["life"])
			var dir2: float = _event["dir"]
			var x2 := lerpf(-80.0, VW + 80.0, k2) if dir2 > 0 else lerpf(VW + 80.0, -80.0, k2)
			var y2: float = float(_event["y"]) + sin(t * 0.5) * 4.0 - dy
			var c2 := Color(0.45, 0.55, 0.78, 0.75) * tint
			var p := Vector2(roundf(x2), roundf(y2))
			_draw.draw_circle(p, 9.0, c2)
			var body_x := p.x - 26.0 if dir2 > 0 else p.x
			_draw.draw_rect(Rect2(body_x, p.y - 5, 26, 10), c2)
			var tail := p + Vector2(-30 * dir2, sin(t * 1.5) * 3.0)
			_draw.draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(-8 * dir2, -6), tail + Vector2(-8 * dir2, 6)]), c2)
			var fin := p + Vector2(-8 * dir2, 6)
			_draw.draw_colored_polygon(PackedVector2Array([fin, fin + Vector2(-6 * dir2, 6 + sin(t * 2.0) * 2.0), fin + Vector2(-10 * dir2, 0)]), c2)
			_draw.draw_rect(Rect2(p.x + 4 * dir2, p.y - 2, 1, 1), Color(1.6, 1.8, 2.0))
		"sandworm":
			var k3: float = t / float(_event["life"])
			var cx: float = _event["x"] - cam.x * 0.0
			var c3 := Color(0.62, 0.42, 0.3, 0.95) * tint
			var ground := 108.0 - dy
			for i in 14:
				var s := k3 * 1.8 - i * 0.06
				if s < 0.0 or s > 1.0:
					continue
				var px := cx - 40.0 + s * 80.0
				var py := ground - sin(s * PI) * 46.0
				_draw.draw_circle(Vector2(roundf(px), roundf(py)), 5.0 - i * 0.2, c3)
			if k3 < 0.2 or (k3 > 0.55 and k3 < 0.75):
				for i in 6:
					var dx := _rng.randf_range(-12, 12)
					_draw.draw_rect(Rect2(roundf(cx - 40 + (0.0 if k3 < 0.3 else 80.0) + dx), roundf(ground - _rng.randf_range(0, 8)), 2, 2), Color(0.9, 0.75, 0.55, 0.8))
		"catapults":
			var k4: float = t / float(_event["life"])
			var x0: float = _event["x0"]
			var x1: float = _event["x1"]
			var hgt: float = _event["h"]
			var base4 := 100.0 - dy
			if k4 < 0.85:
				var q := k4 / 0.85
				var p4 := Vector2(lerpf(x0, x1, q), base4 - sin(q * PI) * hgt)
				for j in 5:
					var qq := maxf(q - j * 0.02, 0.0)
					var tp := Vector2(lerpf(x0, x1, qq), base4 - sin(qq * PI) * hgt)
					_draw.draw_rect(Rect2(roundf(tp.x), roundf(tp.y), 1, 1), Color(0.5, 0.35, 0.35, 0.6 - j * 0.1))
				_draw.draw_circle(p4.round(), 2.0, Color(3.0, 1.6, 0.5))
			else:
				var e := (k4 - 0.85) / 0.15
				_draw.draw_circle(Vector2(roundf(x1), roundf(base4)), 3.0 + e * 8.0, Color(3.0, 1.4, 0.4, 1.0 - e))
				if e < 0.1 and not _event.get("boom", false):
					_event["boom"] = true
					Audio.play("rumble", 0.2, -14.0)
		"bats":
			var k5: float = t / float(_event["life"])
			var dir5: float = _event["dir"]
			for i in 14:
				var bx := lerpf(-30.0, VW + 30.0, k5) if dir5 > 0 else lerpf(VW + 30.0, -30.0, k5)
				bx += sin(i * 2.3) * 18.0 - dir5 * i * 3.0
				var by: float = float(_event["y"]) + cos(i * 1.7) * 10.0 + sin(t * 8.0 + i) * 2.0 - dy
				var up := sin(t * 20.0 + i) > 0.0
				var c5 := Color(0.06, 0.05, 0.1, 0.9)
				_draw.draw_rect(Rect2(roundf(bx), roundf(by), 1, 1), c5)
				_draw.draw_rect(Rect2(roundf(bx) - 2, roundf(by) + (-1 if up else 1), 2, 1), c5)
				_draw.draw_rect(Rect2(roundf(bx) + 1, roundf(by) + (-1 if up else 1), 2, 1), c5)
