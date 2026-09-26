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
	# arma (ferrão) nas costas
	if spec.get("weapon", false) and animation != "attack":
		_px(-bw * 0.5 - 2 + lean * 0.5, by - 1 + bob, 1, 5, Color(0.85, 0.85, 0.9, a))
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
