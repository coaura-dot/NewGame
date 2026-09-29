class_name Scarf
extends Node2D
## Cachecol do herói (física de corda simples). A cor mostra os dashes
## disponíveis, como o cabelo da Madeline em Celeste:
##   vermelho = 1 dash, azul = sem dash, rosa = 2+ dashes.

const COUNT := 7
const SEG := 2.4
const COL_ONE := Color(0.88, 0.28, 0.3)
const COL_NONE := Color(0.31, 0.62, 0.92)
const COL_TWO := Color(0.94, 0.42, 0.85)

var host: Node2D = null ## Player
var color: Color = COL_ONE
var flash: float = 0.0
var _pts: Array[Vector2] = []
var _prev: Array[Vector2] = []
var _t: float = 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# top_level solta o z do pai: fixa o z absoluto logo atrás do herói
	# (senão o cachecol some atrás do cenário)
	z_as_relative = false
	z_index = _absolute_z(host) - 1


static func _absolute_z(n: Node) -> int:
	var z := 0
	while n is CanvasItem:
		var ci := n as CanvasItem
		z += ci.z_index
		if not ci.z_as_relative:
			break
		n = n.get_parent()
	return z


func reset_to(anchor: Vector2) -> void:
	_pts.clear()
	_prev.clear()
	for i in COUNT:
		var p := anchor + Vector2(-i * SEG, 0)
		_pts.append(p)
		_prev.append(p)


func _process(delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	global_position = Vector2.ZERO
	var anchor: Vector2 = host.scarf_anchor()
	if _pts.size() != COUNT or _pts[0].distance_to(anchor) > 40.0:
		reset_to(anchor)
	_t += delta
	var dt := clampf(delta, 0.001, 0.05)
	var facing: int = host.facing
	var vel: Vector2 = host.velocity
	# vento de trás para frente + gravidade leve + ondinha
	var force := Vector2(-facing * 170.0 - vel.x * 0.6, 70.0 - vel.y * 0.3 + sin(_t * 9.0) * 45.0)
	_pts[0] = anchor
	for i in range(1, COUNT):
		var cur := _pts[i]
		var v := (cur - _prev[i]) * 0.86
		_prev[i] = cur
		_pts[i] = cur + v + force * dt * dt
	for _k in 3:
		_pts[0] = anchor
		for i in range(1, COUNT):
			var d := _pts[i] - _pts[i - 1]
			var l := d.length()
			if l > SEG:
				_pts[i] = _pts[i - 1] + d / l * SEG
	flash = maxf(flash - delta * 5.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if _pts.size() < 2 or host == null or not host.visible or not host.scarf_visible():
		return
	var c := color.lerp(Color(2.0, 2.0, 2.0), flash)
	var dark := Color(c.r * 0.72, c.g * 0.72, c.b * 0.72)
	# 2 px de espessura (legível na tela 320x180), ponta afinando
	for i in range(COUNT - 1):
		var a := _pts[i].round()
		var b := _pts[i + 1].round()
		draw_line(a, b, c, 1.0)
		if i < COUNT - 2:
			draw_line(a + Vector2(0, 1), b + Vector2(0, 1), dark, 1.0)
	var tip := _pts[COUNT - 1].round()
	draw_rect(Rect2(tip, Vector2(1, 1)), dark)
