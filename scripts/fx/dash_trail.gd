class_name DashTrail
extends Node2D
## Rastro colorido do dash: uma fita de pixels que segue o centro do herói
## enquanto o dash dura, afina e some da ponta mais velha para a mais nova.
## Cor = a do dash gasto (vermelho, rosa ou azul), em HDR (brilha no bloom).

const LIFE := 0.2 ## quanto cada ponto da fita dura
const MAX_TIME := 0.4

var host: Node2D = null
var alive_check: Callable ## true enquanto o dash está ativo
var color: Color = Color(2.4, 0.8, 0.9)
var width: float = 3.0
var _pts: Array = [] ## [pos, idade]
var _t: float = 0.0
var _following := true


static func spawn(parent: Node, who: Node2D, col: Color, check: Callable) -> DashTrail:
	if parent == null or not bool(Settings.video("afterimages")):
		return null
	var tr := DashTrail.new()
	tr.host = who
	tr.color = col
	tr.alive_check = check
	parent.add_child(tr)
	return tr


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 3
	_sample()


func _sample() -> void:
	if host == null or not is_instance_valid(host):
		_following = false
		return
	var at: Vector2 = host.body_center() if host.has_method("body_center") else host.global_position
	if _pts.is_empty() or (_pts[-1][0] as Vector2).distance_to(at) >= 1.0:
		_pts.append([at, 0.0])


func _process(delta: float) -> void:
	_t += delta
	if _following:
		if _t > MAX_TIME or not alive_check.is_valid() or not alive_check.call():
			_following = false
		else:
			_sample()
	for p in _pts:
		p[1] += delta
	_pts = _pts.filter(func(p): return p[1] < LIFE)
	queue_redraw()
	if not _following and _pts.is_empty():
		queue_free()


func _draw() -> void:
	var n := _pts.size()
	if n < 2:
		return
	for i in range(n - 1):
		var a: Vector2 = _pts[i][0]
		var b: Vector2 = _pts[i + 1][0]
		var age: float = _pts[i][1]
		var k := 1.0 - age / LIFE ## 1 = novo
		var w := maxf(1.0, roundf(width * k))
		var c := Color(color.r, color.g, color.b, clampf(k * 1.2, 0.0, 1.0))
		var core := Color(minf(color.r * 1.3 + 0.6, 4.0), minf(color.g * 1.3 + 0.6, 4.0), minf(color.b * 1.3 + 0.6, 4.0), c.a)
		var steps := maxi(1, int(a.distance_to(b)))
		for s in steps:
			var q := a.lerp(b, float(s) / steps).round()
			draw_rect(Rect2(q - Vector2(floorf(w * 0.5), floorf(w * 0.5)), Vector2(w, w)), c)
			if w >= 3.0:
				draw_rect(Rect2(q, Vector2(1, 1)), core)
