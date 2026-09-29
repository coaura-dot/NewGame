class_name CreatureSprite
extends Node2D
## Criaturinhas minimalistas desenhadas em código, pixel a pixel (resolução
## interna 320x180). Expressivas: piscam, olham para onde vão, esticam e
## amassam (squash & stretch), balançam a capa, e mostram emoções com
## símbolos sobre a cabeça ( ! ? … ♥ ♪ zZ ).
##
## A aparência vem de um "spec" (Dictionary), o mesmo formato usado em
## data/enemies.json ("look"):
##   body [w,h]   head [w,h]   color [r,g,b] (corpo/capa)   shell [r,g,b] (cabeça)
##   eyes "hollow"|"dot"|"glow"   eye_color   legs n   horns bool   ears bool
##   wings bool   tail bool   float bool   flame bool   weapon bool   lantern bool

const OUTLINE := Color(0.09, 0.07, 0.12)
const EMOTES := {
	"!": ["X", "X", "X", ".", "X"],
	"?": ["XX.", "..X", ".X.", "...", ".X."],
	"...": ["....", "....", "....", "....", "X.X.X"],
	"heart": [".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."],
	"note": ["..XX", "..X.", "..X.", "XXX.", "XX.."],
	"z": ["XXX", "..X", ".X.", "X..", "XXX"],
	"drop": [".X.", ".X.", "XXX", "XXX", ".X."],
	"anger": ["X.X", ".X.", "X.X"],
}
const EMOTE_COLORS := {"!": Color(2.2, 1.9, 0.6), "?": Color(1.6, 1.8, 2.4), "...": Color(0.9, 0.9, 1.0),
	"heart": Color(2.4, 0.5, 0.8), "note": Color(1.8, 1.2, 2.6), "z": Color(0.8, 0.9, 1.6), "drop": Color(0.6, 1.2, 2.4),
	"anger": Color(2.4, 0.4, 0.3)}
## Formato da arma desenhada durante o golpe, por classe (data/weapon_classes.json).
## len = comprimento da lâmina em px; thick = 2 px; dual = segunda lâmina;
## staff = haste dos dois lados; fist = soco; shield = escudo na frente.
const BLADES := {
	"longsword": {"len": 9}, "fine_sword": {"len": 10}, "greatsword": {"len": 11, "thick": true},
	"katana": {"len": 9}, "daggers": {"len": 5, "dual": true}, "dual_katana": {"len": 7, "dual": true},
	"heavy_katana": {"len": 13}, "knife": {"len": 4}, "staff": {"len": 10, "staff": true, "color": [0.8, 0.6, 0.38]},
	"bleed_blade": {"len": 8, "color": [1.0, 0.62, 0.62], "serrated": true}, "sword_shield": {"len": 7, "shield": true},
	"gauntlets": {"len": 0, "fist": true},
}
## Ângulos do golpe (graus; 0 = à frente, -90 = para cima): preparação,
## fim do corte, repouso. Fases: 0..0.3 preparação, ..0.75 corte, ..1 volta.
const SWINGS := {
	"side": Vector3(-130, 40, 50), "side_rev": Vector3(55, -120, -110), "up": Vector3(70, -115, -100),
	"down": Vector3(-60, 100, 95), "dash": Vector3(-35, 20, 25), "spin": Vector3(-90, 270, 280),
	"thrust": Vector3(0, 0, 0), "thrust_up": Vector3(-90, -90, -90), "thrust_down": Vector3(90, 90, 90),
	"bash": Vector3(0, 0, 0),
}

var spec: Dictionary = {}
var flip_h: bool = false
var flip_v: bool = false
var speed_scale: float = 1.0
var animation: String = "idle"
var flash: float = 0.0
var status_color: Color = Color(0, 0, 0, 0)
var dissolve: float = 0.0
var velocity_hint: Vector2 = Vector2.ZERO ## usado para inclinar/olhar
var attack_pose: float = 0.0 ## 0..1 durante o golpe
var looking: Vector2 = Vector2.ZERO ## olhar extra (-1..1)
## Golpe em andamento: fase 0..1 (<0 = sem golpe), tipo (SWINGS) e classe da arma.
var swing: float = -1.0
var swing_kind: String = "side"
var weapon_class: String = ""

var _t: float = 0.0
var _blink: float = 0.0
var _next_blink: float = 2.0
var _squash: Vector2 = Vector2.ONE
var _emote: String = ""
var _emote_t: float = 0.0
var _last_anim: String = ""


func _ready() -> void:
	_t = randf() * 10.0
	_next_blink = randf_range(1.5, 4.0)


func play(anim: String, _restart: bool = false) -> void:
	var a := anim
	if a.contains("run") or a.contains("walk") or a.contains("gallop"):
		a = "run"
	elif a.contains("attack") or a.contains("shriek") or a.contains("breath"):
		a = "attack"
	elif a.contains("crouch"):
		a = "crouch"
	if a != animation:
		if a == "jump":
			_squash = Vector2(0.7, 1.35)
		elif animation == "fall" and (a == "idle" or a == "run"):
			_squash = Vector2(1.4, 0.65)
		elif a == "attack":
			_squash = Vector2(1.2, 0.85)
	animation = a


## Mostra um símbolo acima da cabeça por alguns segundos.
func emote(kind: String, duration: float = 1.2) -> void:
	_emote = kind
	_emote_t = duration


func squash(v: Vector2) -> void:
	_squash = v


func _process(delta: float) -> void:
	var d := delta * speed_scale
	_t += d
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-d * 14.0))
	_next_blink -= d
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(1.8, 4.5)
	_blink = maxf(_blink - d, 0.0)
	_emote_t = maxf(_emote_t - delta, 0.0)
	flash = maxf(flash - delta * 8.0, 0.0)
	queue_redraw()


func _col(a: Variant, fallback: Color) -> Color:
	if a is Array and a.size() >= 3:
		return Color(a[0], a[1], a[2])
	return fallback


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	var xx := x
	if flip_h:
		xx = -x - w
	draw_rect(Rect2(roundf(xx), roundf(y), w, h), c)


func _draw() -> void:
	if spec.is_empty():
		return
	var a := 1.0 - dissolve
	if a <= 0.0:
		return
	var body: Array = spec.get("body", [6, 5])
	var head: Array = spec.get("head", [6, 5])
	var bw: float = body[0]
	var bh: float = body[1]
	var hw: float = head[0]
	var hh: float = head[1]
	var floating: bool = spec.get("float", false)
	var cloak := _col(spec.get("color", null), Color(0.23, 0.21, 0.35))
	var shell := _col(spec.get("shell", null), Color(0.92, 0.89, 0.84))
	var eye_c := _col(spec.get("eye_color", null), OUTLINE)
	if flash > 0.01:
		var f := Color(3.0, 3.0, 3.0)
		cloak = cloak.lerp(f, flash)
		shell = shell.lerp(f, flash)
	cloak.a = a
	shell.a = a
	var out := OUTLINE
	if status_color.a > 0.0:
		out = status_color
	out.a = a

	# deformações de animação
	var bob := 0.0
	var lean := 0.0
	var leg_phase := 0.0
	match animation:
		"idle":
			bob = 1.0 if fmod(_t, 1.0) > 0.5 else 0.0
		"run":
			bob = 1.0 if fmod(_t * 8.0, 2.0) > 1.0 else 0.0
			leg_phase = 1.0 if fmod(_t * 10.0, 2.0) > 1.0 else -1.0
			lean = 1.0
		"attack":
			lean = 1.0 + attack_pose
			if swing >= 0.0:
				# antecipação (recua) -> golpe (avança) -> volta
				lean = -1.0 if swing < 0.3 else (2.0 if swing < 0.75 else 1.0)
		"crouch":
			bob = 1.0
		"hurt":
			lean = -1.0
	if floating:
		bob = roundf(sin(_t * 3.0) * 1.5)
	var base_y := 0.0 if not floating else bh * 0.5 + hh * 0.5
	var sq := _squash
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sq.x, sq.y * (-1.0 if flip_v else 1.0)))

	# pernas
	var legs: int = int(spec.get("legs", 2))
	if not floating and legs > 0:
		for i in legs:
			var lx := -bw * 0.5 + 1 + i * maxf((bw - 2) / maxf(legs - 1, 1), 1.0)
			var ly := -2.0
			var off := leg_phase * (1 if i % 2 == 0 else -1)
			_px(lx + off * 0.5, base_y + ly + (0 if off <= 0 else -0.0), 1, 2, out)
	# cauda
	if spec.get("tail", false):
		_px(-bw * 0.5 - 2, base_y - bh + 1 + bob, 2, 1, out)
		_px(-bw * 0.5 - 3, base_y - bh + bob, 1, 1, out)
	# corpo / capa
	var by := base_y - 2 - bh + bob
	if floating:
		by = base_y - bh + bob
	if bw > 0 and bh > 0:
		_px(-bw * 0.5 - 1 + lean * 0.5, by - 1, bw + 2, bh + 1, out)
		_px(-bw * 0.5 + lean * 0.5, by, bw, bh, cloak)
	if not floating:
		# barra da capa balançando
		var wave := 1.0 if fmod(_t * 4.0, 2.0) > 1.0 else 0.0
		_px(-bw * 0.5 - 1 + lean * 0.5 - wave, by + bh - 1, 1, 1, cloak)
	else:
		# base ondulada de fantasma
		for i in int(bw):
			if (i + int(_t * 6.0)) % 2 == 0:
				_px(-bw * 0.5 + i, by + bh, 1, 1, cloak)
	# asas
	if spec.get("wings", false):
		var flap := 2.0 if fmod(_t * 6.0, 2.0) > 1.0 else 0.0
		for s in [-1, 1]:
			var wx: float = (bw * 0.5 + 1) * s
			_px(wx if s > 0 else wx - 3, by - 2 - flap, 3, 2, out)
			_px(wx if s > 0 else wx - 3, by - 1 - flap, 3, 1, cloak.darkened(0.2))
	# cabeça
	var hx := -hw * 0.5 + lean
	var hy := by - hh + 1
	_px(hx - 1, hy - 1, hw + 2, hh + 1, out)
	_px(hx, hy, hw, hh, shell)
	_px(hx, hy, 1, 1, out) # cantos arredondados
	_px(hx + hw - 1, hy, 1, 1, out)
	# chifres / orelhas
	if spec.get("horns", false):
		_px(hx + 1, hy - 3, 1, 2, shell)
		_px(hx + hw - 2, hy - 3, 1, 2, shell)
		_px(hx, hy - 4, 1, 1, shell)
		_px(hx + hw - 1, hy - 4, 1, 1, shell)
	if spec.get("ears", false):
		_px(hx, hy - 2, 2, 2, shell)
		_px(hx + hw - 2, hy - 2, 2, 2, shell)
	# chama (crânio flamejante)
	if spec.get("flame", false):
		for i in 5:
			var fx := hx - 1 + i * (hw + 2) / 4.0
			var fh := 2.0 + (1.0 if fmod(_t * 10.0 + i, 2.0) > 1.0 else 0.0)
			_px(fx, hy - fh - 1, 1, fh, Color(2.6, 1.2, 0.3, a))
	# olhos
	var eyes: String = spec.get("eyes", "hollow")
	var look := clampf(velocity_hint.x * 0.02 + looking.x, -1.0, 1.0)
	var ex := hx + hw * 0.5 - 1 + roundf(look + 0.5)
	var ey := hy + hh * 0.45 + roundf(looking.y)
	var eh := 2.0 if _blink <= 0.0 else 1.0
	if animation == "hurt":
		eh = 1.0
	var ec := eye_c
	if eyes == "glow":
		ec = Color(eye_c.r * 2.5, eye_c.g * 2.5, eye_c.b * 2.5)
	ec.a = a
	match eyes:
		"dot":
			_px(ex - 1, ey + (2 - eh), 1, eh, ec)
			_px(ex + 2, ey + (2 - eh), 1, eh, ec)
		_:
			_px(ex - 1, ey + (2 - eh), 1, eh, ec)
			_px(ex + 1, ey + (2 - eh), 1, eh, ec)
	# arma: animada durante o golpe; fora dele, guardada nas costas
	var blade: Dictionary = BLADES.get(weapon_class, {})
	if swing >= 0.0 and not blade.is_empty():
		_draw_swing(blade, Vector2(bw * 0.5 + lean * 0.5, by + bh * 0.5), a)
	elif spec.get("weapon", false):
		_px(-bw * 0.5 - 2 + lean * 0.5, by - 1 + bob, 1, 5, Color(0.85, 0.85, 0.9, a))
	if blade.get("shield", false):
		var push := 3.0 if swing_kind == "bash" and swing >= 0.3 and swing < 0.75 else 0.0
		_px(bw * 0.5 + lean * 0.5 + push, by - 1, 2, 4, Color(0.55, 0.5, 0.6, a))
		_px(bw * 0.5 + lean * 0.5 + push + 1, by, 1, 2, Color(1.0, 0.85, 0.45, a))
	# lanterna
	if spec.get("lantern", false):
		_px(bw * 0.5 + 1, by + 1, 2, 3, Color(2.4, 1.8, 0.8, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# emoção
	if _emote_t > 0.0 and EMOTES.has(_emote):
		var rows: Array = EMOTES[_emote]
		var c: Color = EMOTE_COLORS.get(_emote, Color.WHITE)
		c.a = minf(_emote_t * 4.0, 1.0)
		var top := hy - 4 - rows.size() - (2 if spec.get("horns", false) else 0) + (0 if fmod(_t * 3.0, 2.0) > 1.0 else -1)
		var w: int = rows[0].length()
		for yy in rows.size():
			var r: String = rows[yy]
			for xx in r.length():
				if r[xx] == "X":
					draw_rect(Rect2(roundf(-w * 0.5) + xx, top + yy, 1, 1), c)


## Ângulo (graus) da lâmina na fase `p` do golpe atual.
func _swing_angle(p: float) -> float:
	var s: Vector3 = SWINGS.get(swing_kind, SWINGS["side"])
	if p < 0.3:
		return s.x
	if p < 0.75:
		return lerpf(s.x, s.y, ease((p - 0.3) / 0.45, 0.35))
	return lerpf(s.y, s.z, (p - 0.75) / 0.25)


## Quanto a arma avança (estocada/soco/escudo) na fase `p`.
func _swing_reach(p: float) -> float:
	if p < 0.3:
		return -2.0 * (p / 0.3)
	if p < 0.75:
		return lerpf(-2.0, 4.0, ease((p - 0.3) / 0.45, 0.3))
	return lerpf(4.0, 0.0, (p - 0.75) / 0.25)


## Linha de pixels de `from` na direção `dir` (1 px por passo).
func _pixel_line(from: Vector2, dir: Vector2, n0: int, n1: int, c: Color) -> void:
	for i in range(n0, n1 + 1):
		var q := from + dir * float(i)
		_px(roundf(q.x), roundf(q.y), 1, 1, c)


func _draw_swing(blade: Dictionary, hand: Vector2, a: float) -> void:
	var length: int = int(blade.get("len", 8))
	var bc := _col(blade.get("color", null), Color(0.88, 0.9, 1.0))
	var striking := swing >= 0.3 and swing < 0.75
	if striking:
		bc = bc.lerp(Color(1.9, 1.9, 2.3), 0.5) # brilho sutil no corte (bloom)
	bc.a = a
	var hilt := Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, a)
	var linear := swing_kind.begins_with("thrust") or swing_kind == "bash"
	var ang := _swing_angle(swing)
	var reach := _swing_reach(swing) if linear or blade.get("fist", false) else 0.0
	if blade.get("fist", false):
		# soco: reto na direção do golpe (frente, cima ou baixo)
		var fang := 0.0
		if swing_kind in ["up", "thrust_up"]:
			fang = -90.0
		elif swing_kind in ["down", "thrust_down"]:
			fang = 90.0
		var fdir := Vector2.from_angle(deg_to_rad(fang))
		var f := hand + fdir * (2.0 + reach)
		_px(roundf(f.x) - 1, roundf(f.y) - 1, 3, 3, hilt)
		_px(roundf(f.x), roundf(f.y), 2, 2, Color(0.75, 0.7, 0.8, a) if not striking else bc)
		return
	if swing_kind == "bash":
		return # o escudo é desenhado à parte
	var dir := Vector2.from_angle(deg_to_rad(ang))
	var base := hand + dir * reach
	# rastro (smear) só no corte: duas lâminas fantasmas atrás, só a ponta
	if striking and not linear:
		for k in [0.45, 0.75]:
			var ga := lerpf(_swing_angle(0.3), ang, k)
			var gd := Vector2.from_angle(deg_to_rad(ga))
			_pixel_line(hand, gd, int(length * 0.5), length, Color(bc.r, bc.g, bc.b, a * (0.25 if k < 0.6 else 0.45)))
	if blade.get("staff", false):
		_pixel_line(base, dir, -4, length, bc)
		_px(roundf(base.x + dir.x * length), roundf(base.y + dir.y * length), 1, 1, Color(1.6, 1.3, 2.2, a))
		return
	# guarda perpendicular + lâmina
	var perp := Vector2(-dir.y, dir.x)
	_px(roundf(base.x + perp.x), roundf(base.y + perp.y), 1, 1, hilt)
	_px(roundf(base.x - perp.x), roundf(base.y - perp.y), 1, 1, hilt)
	_pixel_line(base, dir, 1, length, bc)
	if blade.get("thick", false):
		_pixel_line(base + perp, dir, 2, length - 1, bc.darkened(0.15))
	if blade.get("serrated", false):
		for i in range(3, length, 2):
			var q := base + dir * float(i) - perp
			_px(roundf(q.x), roundf(q.y), 1, 1, bc.darkened(0.25))
	if blade.get("dual", false):
		# segunda lâmina um pouco atrás no tempo (golpes em sequência)
		var d2 := Vector2.from_angle(deg_to_rad(0.0 if linear else _swing_angle(maxf(swing - 0.12, 0.0)) + 25.0))
		_pixel_line(hand + Vector2(-2, 1), d2, 1, maxi(length - 1, 3), Color(bc.r, bc.g, bc.b, a * 0.85))


## Cópia fantasma (rastro do dash/teleporte).
func ghost(tint: Color, life: float = 0.25) -> Node2D:
	var g := GhostImage.new()
	g.spec = spec
	g.flip_h = flip_h
	g.flip_v = flip_v
	g.animation = animation
	g.tint = tint
	g.life = life
	g.global_position = global_position
	g.z_index = z_index - 1
	return g


class GhostImage extends Node2D:
	var spec: Dictionary
	var flip_h: bool
	var flip_v: bool
	var animation: String
	var tint: Color
	var life: float = 0.25
	var _t: float = 0.0

	func _ready() -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= life:
			queue_free()

	func _draw() -> void:
		var body: Array = spec.get("body", [6, 5])
		var head: Array = spec.get("head", [6, 5])
		var a := (1.0 - _t / life) * tint.a
		var c := Color(tint.r, tint.g, tint.b, a)
		var fl: bool = spec.get("float", false)
		var base := 0.0 if not fl else float(body[1]) * 0.5 + float(head[1]) * 0.5
		var sy := -1.0 if flip_v else 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, sy))
		var by := base - 2 - float(body[1])
		draw_rect(Rect2(-float(body[0]) * 0.5, by, body[0], body[1]), c)
		draw_rect(Rect2(-float(head[0]) * 0.5, by - float(head[1]) + 1, head[0], head[1]), c)
