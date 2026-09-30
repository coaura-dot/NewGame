class_name Landmark
extends Node2D
## Marco visual do coração de uma região (e do covil do guardião): uma peça
## grande do cenário, logo atrás do caminho, que dá identidade ao lugar e se
## reconhece de longe — no estilo das estátuas e árvores do Hollow Knight.
##   statue  — estátua colossal de um cavaleiro encapuzado apoiado na espada,
##             com uma tigela de brasas acesa aos pés
##   tree    — árvore ancestral de raízes enormes, com vaga-lumes
##   crystal — aglomerado de cristais gigantes que brilham
## Desenhado na densidade da arte (1/ART de unidade por pixel), escuro como
## silhueta, iluminado pela própria luz (PointLight2D).

var kind: String = "statue"
var tint: Color = Color(1, 1, 1)
var _t: float = 0.0
var _light: PointLight2D
var _base_energy: float = 1.0


func _ready() -> void:
	z_index = -15
	var col := Color(1.0, 0.62, 0.3)
	var at := Vector2(0, -8)
	var energy := 0.8
	var sc := 4.0
	match kind:
		"tree":
			col = Color(0.7, 1.0, 0.55)
			at = Vector2(0, -50)
			energy = 0.8
			sc = 7.0
		"crystal":
			col = Color(0.55, 0.9, 1.3)
			at = Vector2(0, -26)
			energy = 1.5
			sc = 6.0
	_base_energy = energy
	_light = LightUtil.make_light(col, energy, sc)
	if _light:
		_light.position = at
		add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	if _light:
		_light.energy = _base_energy * 0.7 * (0.92 + 0.08 * sin(_t * 3.1) + 0.04 * sin(_t * 7.3))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / float(LevelConst.ART))
	match kind:
		"tree":
			_draw_tree()
		"crystal":
			_draw_crystal()
		_:
			_draw_statue()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _poly(pts: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), c * tint)


# ---------------------------------------------------------------------------

func _draw_statue() -> void:
	var dark := Color(0.2, 0.19, 0.24)
	var mid := Color(0.3, 0.28, 0.34)
	var lit := Color(0.46, 0.42, 0.46)
	# pedestal em degraus
	_poly([Vector2(-46, 0), Vector2(46, 0), Vector2(46, -10), Vector2(-46, -10)], dark)
	_poly([Vector2(-38, -10), Vector2(38, -10), Vector2(38, -20), Vector2(-38, -20)], mid)
	draw_line(Vector2(-38, -20), Vector2(38, -20), lit * tint, 1.0)
	# manto (corpo)
	_poly([Vector2(-26, -20), Vector2(26, -20), Vector2(20, -80), Vector2(14, -118), Vector2(-14, -118), Vector2(-20, -80)], dark)
	# dobras do manto (faixas de luz do lado da chama)
	_poly([Vector2(-8, -20), Vector2(2, -20), Vector2(0, -100), Vector2(-6, -100)], mid)
	_poly([Vector2(12, -20), Vector2(20, -20), Vector2(15, -82), Vector2(10, -82)], mid)
	# ombros e capuz
	_poly([Vector2(-24, -110), Vector2(24, -110), Vector2(16, -126), Vector2(-16, -126)], mid)
	_poly([Vector2(-14, -122), Vector2(14, -122), Vector2(11, -146), Vector2(0, -156), Vector2(-11, -146)], dark)
	_poly([Vector2(-7, -130), Vector2(7, -130), Vector2(5, -144), Vector2(-5, -144)], Color(0.06, 0.05, 0.08))
	# olhos (brasas quase apagadas)
	var eye := Color(1.6, 0.8, 0.3) * (0.7 + 0.3 * sin(_t * 1.3))
	draw_rect(Rect2(-4, -138, 2, 1), eye)
	draw_rect(Rect2(2, -138, 2, 1), eye)
	# espada cravada à frente (mãos no punho)
	_poly([Vector2(-2, -104), Vector2(2, -104), Vector2(2, -26), Vector2(0, -20), Vector2(-2, -26)], lit)
	_poly([Vector2(-12, -104), Vector2(12, -104), Vector2(12, -100), Vector2(-12, -100)], mid)
	_poly([Vector2(-6, -112), Vector2(6, -112), Vector2(6, -104), Vector2(-6, -104)], dark)
	# tigela de brasas no pedestal
	_poly([Vector2(-10, -20), Vector2(10, -20), Vector2(7, -26), Vector2(-7, -26)], Color(0.14, 0.1, 0.1))
	for i in 5:
		var fx := -6.0 + i * 3.0
		var fh := 5.0 + 3.0 * sin(_t * 6.0 + i * 1.7)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 2, -26), Vector2(fx + 2, -26), Vector2(fx, -26 - fh)]), Color(1.5, 0.75, 0.28))
	# brasas subindo
	for i in 4:
		var ph := fmod(_t * 0.6 + i * 0.25, 1.0)
		draw_rect(Rect2(-4 + i * 3 + sin(ph * 9.0 + i) * 3.0, -30 - ph * 40.0, 1, 1), Color(1.5, 0.8, 0.3, 1.0 - ph))


func _draw_tree() -> void:
	var bark := Color(0.2, 0.15, 0.13)
	var bark_l := Color(0.3, 0.23, 0.18)
	var leaf := Color(0.1, 0.17, 0.12)
	var leaf_l := Color(0.16, 0.26, 0.16)
	# raízes
	for side in [-1, 1]:
		_poly([Vector2(side * 10, 0), Vector2(side * 56, 0), Vector2(side * 30, -8), Vector2(side * 14, -30)], bark)
		_poly([Vector2(side * 6, 0), Vector2(side * 30, 0), Vector2(side * 12, -16)], bark_l)
	# tronco torto
	_poly([Vector2(-18, 0), Vector2(18, 0), Vector2(14, -60), Vector2(20, -110), Vector2(8, -150), Vector2(-10, -150), Vector2(-16, -100), Vector2(-12, -60)], bark)
	_poly([Vector2(-8, 0), Vector2(0, 0), Vector2(-2, -60), Vector2(2, -120), Vector2(-4, -140), Vector2(-8, -100)], bark_l)
	# galhos
	_poly([Vector2(8, -120), Vector2(50, -150), Vector2(52, -145), Vector2(12, -112)], bark)
	_poly([Vector2(-8, -110), Vector2(-54, -135), Vector2(-56, -130), Vector2(-10, -104)], bark)
	# copa (camadas de folhas)
	for c in [[Vector2(0, -170), 46.0], [Vector2(-44, -150), 30.0], [Vector2(46, -158), 32.0], [Vector2(-18, -196), 30.0], [Vector2(24, -194), 28.0]]:
		draw_circle(c[0], c[1], leaf * tint)
	for c in [[Vector2(-8, -184), 22.0], [Vector2(30, -170), 16.0], [Vector2(-40, -158), 14.0]]:
		draw_circle(c[0], c[1], leaf_l * tint)
	# vaga-lumes
	for i in 9:
		var ph := _t * 0.5 + i * 0.7
		var p := Vector2(sin(ph * 1.3 + i) * 50.0, -60.0 - fmod(i * 23.0 + _t * 6.0, 140.0))
		var a := 0.5 + 0.5 * sin(_t * 3.0 + i * 2.0)
		draw_rect(Rect2(p, Vector2(1, 1)), Color(1.8, 2.4, 0.8, a))


func _draw_crystal() -> void:
	var shards := [[-26, 60, -0.28, 12], [0, 96, 0.0, 16], [24, 70, 0.22, 12], [-44, 36, -0.5, 9], [44, 40, 0.5, 9], [-12, 44, -0.12, 8], [14, 50, 0.1, 8]]
	var pulse := 0.85 + 0.15 * sin(_t * 2.2)
	for sh in shards:
		var bx: float = sh[0]
		var hgt: float = sh[1]
		var ang: float = sh[2]
		var wd: float = sh[3]
		var up := Vector2(sin(ang), -cos(ang))
		var side := Vector2(cos(ang), sin(ang))
		var base := Vector2(bx, 0)
		var tip := base + up * hgt
		var l0 := base - side * wd * 0.5
		var r0 := base + side * wd * 0.5
		var l1 := l0 + up * hgt * 0.82
		var r1 := r0 + up * hgt * 0.82
		draw_colored_polygon(PackedVector2Array([l0, r0, r1, tip, l1]), Color(0.2, 0.45, 0.7) * pulse * tint)
		draw_colored_polygon(PackedVector2Array([l0, base, base + up * hgt * 0.82, tip, l1]), Color(0.45, 0.85, 1.3) * pulse * tint)
		draw_line(base + up * 4.0, tip - up * 3.0, Color(1.6, 2.4, 2.8) * pulse, 1.0)
	# brilhos subindo
	for i in 6:
		var ph := fmod(_t * 0.4 + i * 0.17, 1.0)
		draw_rect(Rect2(-30 + i * 12 + sin(ph * 8.0 + i) * 4.0, -10 - ph * 90.0, 1, 1), Color(1.2, 2.2, 2.8, 1.0 - ph))
