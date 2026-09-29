class_name SchoolFX
extends Node2D
## Partículas próprias de cada ESCOLA de magia (e da cura), em pixels:
##   fogo      = brasas que sobem, amarelo -> laranja -> vermelho
##   gelo      = estilhaços que voam e caem + brilho de geada
##   raio      = zigue-zagues que estalam
##   sombra    = espiral que se fecha no centro (vazio, gravidade)
##   cura/luz  = cruzes que sobem
##   terra     = pedrinhas com gravidade
##   água      = gotas que respingam
##   arcano    = estrelinhas que cintilam (psíquico, teleporte, quântico)
##   tempo     = anéis de "tique" que se expandem (pressão também)
## Cada chamada cria um lote pequeno que se apaga sozinho. Cores HDR brilham
## com o bloom. Uso: SchoolFX.impact(pai, "fire", pos, dir, cor).

const STYLE := {
	"fire": "ember", "ice": "shard", "lightning": "zig", "void": "spiral", "gravity": "spiral",
	"shadow": "spiral", "light": "cross", "heal": "cross", "earth": "rock", "water": "drop",
	"arcane": "star", "psychic": "star", "teleport": "star", "quantum": "star",
	"time": "tick", "pressure": "tick",
}
const EMBER_YOUNG := Color(3.0, 2.4, 0.9)
const EMBER_MID := Color(2.6, 1.1, 0.25)
const EMBER_OLD := Color(1.2, 0.25, 0.15)
const ICE := Color(2.2, 2.8, 3.2)
const ICE_DEEP := Color(0.8, 1.6, 2.8)
const ROCK := Color(0.62, 0.48, 0.36)
const ROCK_DARK := Color(0.36, 0.26, 0.22)
const ROCK_LIGHT := Color(0.86, 0.72, 0.55)

var style: String = "star"
var color: Color = Color(2, 2, 2)
var gravity: float = 0.0
var drag: float = 2.0
var center: Vector2 = Vector2.ZERO ## espiral: ponto para onde as partículas convergem
var _p: Array = [] ## [pos, vel, vida, vida_max, semente, tamanho]
var _t: float = 0.0


static func style_of(school: String) -> String:
	return STYLE.get(school, "star")


static func _quality() -> float:
	return [0.4, 0.7, 1.0][clampi(int(Settings.video("particles")), 0, 2)]


static func _make(parent: Node, school: String, pos: Vector2, col: Color) -> SchoolFX:
	var fx := SchoolFX.new()
	fx.style = style_of(school)
	fx.color = col
	fx.global_position = pos
	match fx.style:
		"shard":
			fx.gravity = 220.0
			fx.drag = 1.5
		"rock":
			fx.gravity = 380.0
			fx.drag = 0.6
		"drop":
			fx.gravity = 300.0
			fx.drag = 1.0
		"ember":
			fx.gravity = -40.0
			fx.drag = 3.0
		"cross":
			fx.gravity = -10.0
			fx.drag = 3.0
	if parent:
		parent.add_child(fx)
	return fx


## Rastro de um projétil: 1 partícula da escola atrás dele.
static func trail(parent: Node, school: String, pos: Vector2, vel: Vector2, col: Color) -> void:
	if randf() > _quality():
		return
	var fx := _make(parent, school, pos, col)
	var back := -vel.normalized() if vel != Vector2.ZERO else Vector2.ZERO
	match fx.style:
		"ember":
			fx.add(Vector2(randf_range(-1, 1), randf_range(-1, 1)), back * 20.0 + Vector2(randf_range(-8, 8), -20), randf_range(0.25, 0.45))
		"shard":
			fx.style = "star"
			fx.gravity = 0.0
			fx.add(Vector2(randf_range(-2, 2), randf_range(-2, 2)), back * 10.0, randf_range(0.15, 0.3))
		"zig":
			fx.add(Vector2.ZERO, back.rotated(randf_range(-1.2, 1.2)) * 6.0, 0.08)
		"spiral":
			fx.center = Vector2.ZERO
			fx.add(Vector2(randf_range(5, 8), randf() * TAU), Vector2(-24, 9), 0.3)
		"cross":
			fx.add(Vector2(randf_range(-2, 2), randf_range(-2, 2)), Vector2(0, -12), 0.35)
		"rock":
			fx.add(Vector2(randf_range(-1, 1), 0), back * 20.0 + Vector2(0, 10), 0.35, 1)
		"drop":
			fx.add(Vector2(randf_range(-1, 1), 0), back * 15.0 + Vector2(0, 10), 0.3)
		"tick":
			fx.add(Vector2.ZERO, Vector2.ZERO, 0.25)
		_:
			fx.add(Vector2(randf_range(-2, 2), randf_range(-2, 2)), back * 8.0, randf_range(0.15, 0.3))


## Estouro no impacto (ou em volta de uma explosão). power ~1 = projétil comum.
static func impact(parent: Node, school: String, pos: Vector2, dir: Vector2, col: Color, power: float = 1.0) -> void:
	var fx := _make(parent, school, pos, col)
	var n := maxi(2, int(round(8.0 * power * _quality())))
	match fx.style:
		"ember":
			for i in n + 2:
				var a := -PI * 0.5 + randf_range(-1.3, 1.3)
				fx.add(Vector2(randf_range(-2, 2), randf_range(-2, 2)), Vector2.from_angle(a) * randf_range(30, 80) * power, randf_range(0.35, 0.7))
		"shard":
			for i in n:
				var a := TAU * i / n + randf_range(-0.3, 0.3)
				fx.add(Vector2.ZERO, Vector2.from_angle(a) * randf_range(70, 130) * power, randf_range(0.25, 0.45), 2 + int(randf() < 0.4))
			var sparkle := _make(parent, "arcane", pos, ICE)
			for i in 3:
				sparkle.add(Vector2(randf_range(-6, 6), randf_range(-6, 6)), Vector2.ZERO, randf_range(0.2, 0.4))
		"zig":
			for i in maxi(3, n / 2):
				var a := TAU * i / maxi(3, n / 2) + randf_range(-0.4, 0.4)
				fx.add(Vector2.ZERO, Vector2.from_angle(a) * randf_range(6, 10) * maxf(power, 0.8), randf_range(0.1, 0.16))
		"spiral":
			fx.center = Vector2.ZERO
			for i in n + 4:
				fx.add(Vector2(randf_range(9, 15) * maxf(power, 0.7), randf() * TAU), Vector2(-randf_range(22, 34), randf_range(7, 11)), randf_range(0.35, 0.5))
		"cross":
			for i in maxi(3, n / 2 + 1):
				fx.add(Vector2(randf_range(-7, 7), randf_range(-4, 4)), Vector2(randf_range(-6, 6), -randf_range(18, 32)), randf_range(0.45, 0.7))
		"rock":
			for i in n:
				var a := -PI * 0.5 + randf_range(-1.1, 1.1)
				fx.add(Vector2(randf_range(-3, 3), 0), Vector2.from_angle(a) * randf_range(60, 130) * power, randf_range(0.45, 0.7), 2 + int(randf() < 0.35))
			FX.dust(pos, Vector2.UP, 3)
		"drop":
			for i in n:
				var a := -PI * 0.5 + randf_range(-1.2, 1.2)
				fx.add(Vector2.ZERO, Vector2.from_angle(a) * randf_range(50, 100) * power, randf_range(0.3, 0.5))
			FX.ring(pos, col, 6.0 * power, 0.22, Vector2(1.0, 0.5))
		"tick":
			for i in 3:
				fx.add(Vector2(randf_range(-4, 4), randf_range(-4, 4)), Vector2(i, 0), 0.3 + i * 0.08)
		_:
			for i in n:
				var a := TAU * i / n + randf_range(-0.2, 0.2)
				fx.add(Vector2.ZERO, Vector2.from_angle(a) * randf_range(40, 80) * power, randf_range(0.25, 0.45))


## Clarão pequeno na mão ao conjurar (na direção da mira).
static func cast(parent: Node, school: String, pos: Vector2, dir: Vector2, col: Color) -> void:
	var fx := _make(parent, school, pos, col)
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	for i in 4:
		var v := d.rotated(randf_range(-0.8, 0.8)) * randf_range(20, 45)
		match fx.style:
			"spiral":
				fx.center = Vector2.ZERO
				fx.add(Vector2(randf_range(5, 8), randf() * TAU), Vector2(-26, 10), 0.25)
			"zig":
				fx.add(Vector2.ZERO, v.normalized() * 6.0, 0.08)
			"tick":
				fx.add(Vector2.ZERO, Vector2(i, 0), 0.2 + i * 0.05)
			_:
				fx.add(Vector2.ZERO, v, randf_range(0.18, 0.3))


func add(pos: Vector2, vel: Vector2, life: float, size: int = 1) -> void:
	_p.append([pos, vel, life, life, randf() * 100.0, size])


func _ready() -> void:
	z_index = 42


func _process(delta: float) -> void:
	_t += delta
	var alive := false
	for p in _p:
		if p[2] <= 0.0:
			continue
		alive = true
		p[2] -= delta
		if style == "spiral":
			# pos = (raio, ângulo); vel = (quanto o raio encolhe/s, giro rad/s)
			p[0].x = maxf(p[0].x + p[1].x * delta, 0.0)
			p[0].y += p[1].y * delta
			continue
		if style == "zig" or style == "tick":
			continue
		p[1].y += gravity * delta
		p[1] *= 1.0 - minf(drag * delta, 0.9)
		if style == "ember":
			p[1].x += sin(_t * 9.0 + float(p[4])) * 30.0 * delta
		p[0] += p[1] * delta
	queue_redraw()
	if not alive:
		queue_free()


func _draw() -> void:
	for p in _p:
		var life: float = p[2]
		if life <= 0.0:
			continue
		var f: float = life / float(p[3]) ## 1 = nasceu agora, 0 = some
		match style:
			"ember": _draw_ember(p, f)
			"shard": _draw_shard(p, f)
			"zig": _draw_zig(p, f)
			"spiral": _draw_spiral(p, f)
			"cross": _draw_cross(p, f)
			"rock": _draw_rock(p, f)
			"drop": _draw_drop(p, f)
			"tick": _draw_tick(p, f)
			_: _draw_star(p, f)


func _px(at: Vector2, c: Color, s: float = 1.0) -> void:
	draw_rect(Rect2(at.round(), Vector2(s, s)), c)


func _draw_ember(p: Array, f: float) -> void:
	var c := EMBER_OLD.lerp(EMBER_MID, clampf(f * 2.0, 0.0, 1.0)).lerp(EMBER_YOUNG, clampf(f * 2.0 - 1.0, 0.0, 1.0))
	# cintila
	c.a = 0.55 + 0.45 * absf(sin(_t * 30.0 + float(p[4])))
	_px(p[0], c, 2.0 if f > 0.7 else 1.0)


func _draw_shard(p: Array, f: float) -> void:
	var v: Vector2 = p[1]
	var d := v.normalized() if v.length() > 1.0 else Vector2.RIGHT
	var l := float(p[5]) + 1.0
	var c := ICE_DEEP.lerp(ICE, f)
	c.a = minf(f * 2.0, 1.0)
	var a: Vector2 = p[0]
	for i in int(l):
		_px(a - d * i, c if i == 0 else Color(c.r * 0.7, c.g * 0.8, c.b, c.a))


func _draw_zig(p: Array, f: float) -> void:
	var dir: Vector2 = p[1]
	var d := dir.normalized()
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	var steps := 3
	var seg_len := dir.length()
	for i in steps + 1:
		var q: Vector2 = p[0] + d * seg_len * float(i) / steps
		if i > 0 and i < steps:
			q += n * randf_range(-2.0, 2.0)
		pts.append(q.round())
	var c := Color(color.r, color.g, color.b, f)
	draw_polyline(pts, Color(c.r * 0.5, c.g * 0.5, c.b * 0.8, f * 0.5), 2.0)
	draw_polyline(pts, Color(minf(c.r * 1.3, 4.0), minf(c.g * 1.3, 4.0), minf(c.b * 1.3, 4.0), f), 1.0)


func _draw_spiral(p: Array, f: float) -> void:
	var at := center + Vector2.from_angle(float(p[0].y)) * float(p[0].x)
	var prev := center + Vector2.from_angle(float(p[0].y) - 0.35) * (float(p[0].x) + 1.5)
	var c := Color(color.r, color.g, color.b, f)
	_px(prev, Color(c.r * 0.4, c.g * 0.3, c.b * 0.6, f * 0.6))
	_px(at, Color(c.r * 1.6 + 0.3, c.g * 1.4 + 0.1, c.b * 1.6 + 0.4, f))


func _draw_cross(p: Array, f: float) -> void:
	var c := Color(color.r, color.g, color.b, minf(f * 2.0, 1.0))
	var at: Vector2 = (p[0] as Vector2).round()
	var big := f > 0.35
	_px(at, Color(3.0, 3.0, 2.8, c.a))
	_px(at + Vector2(-1, 0), c)
	_px(at + Vector2(1, 0), c)
	_px(at + Vector2(0, -1), c)
	_px(at + Vector2(0, 1), c)
	if big:
		_px(at + Vector2(0, -2), Color(c.r, c.g, c.b, c.a * 0.6))


func _draw_rock(p: Array, f: float) -> void:
	var s := float(p[5])
	var at: Vector2 = (p[0] as Vector2).round()
	var a := minf(f * 3.0, 1.0)
	draw_rect(Rect2(at, Vector2(s, s)), Color(ROCK.r, ROCK.g, ROCK.b, a))
	draw_rect(Rect2(at + Vector2(0, s - 1), Vector2(s, 1)), Color(ROCK_DARK.r, ROCK_DARK.g, ROCK_DARK.b, a))
	draw_rect(Rect2(at, Vector2(1, 1)), Color(ROCK_LIGHT.r, ROCK_LIGHT.g, ROCK_LIGHT.b, a))


func _draw_drop(p: Array, f: float) -> void:
	var c := Color(color.r, color.g, color.b, minf(f * 2.0, 1.0))
	var at: Vector2 = (p[0] as Vector2).round()
	_px(at, Color(minf(c.r * 1.5, 3.0), minf(c.g * 1.5, 3.0), minf(c.b * 1.3, 3.5), c.a))
	_px(at + Vector2(0, -1), Color(c.r, c.g, c.b, c.a * 0.6))


func _draw_tick(p: Array, f: float) -> void:
	var r := 1.0 + (1.0 - f) * (5.0 + float(p[1].x) * 2.0)
	var c := Color(color.r, color.g, color.b, f)
	var n := int(clampf(r * 2.5, 6.0, 20.0))
	for i in n:
		var a := TAU * i / n + _t * 3.0
		_px(p[0] + Vector2.from_angle(a) * r, c)


func _draw_star(p: Array, f: float) -> void:
	var c := Color(color.r, color.g, color.b, minf(f * 2.0, 1.0))
	var at: Vector2 = (p[0] as Vector2).round()
	var twinkle := sin(_t * 25.0 + float(p[4])) > -0.2
	_px(at, Color(minf(c.r * 1.4 + 0.4, 4.0), minf(c.g * 1.4 + 0.4, 4.0), minf(c.b * 1.4 + 0.4, 4.0), c.a))
	if twinkle and f > 0.3:
		_px(at + Vector2(-1, 0), Color(c.r, c.g, c.b, c.a * 0.7))
		_px(at + Vector2(1, 0), Color(c.r, c.g, c.b, c.a * 0.7))
		_px(at + Vector2(0, -1), Color(c.r, c.g, c.b, c.a * 0.7))
		_px(at + Vector2(0, 1), Color(c.r, c.g, c.b, c.a * 0.7))
