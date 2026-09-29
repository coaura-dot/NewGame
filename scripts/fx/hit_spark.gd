extends Node2D
## Faísca de impacto limpa e legível (Katana Zero / Hollow Knight): um clarão
## branco que encolhe, uma LINHA DE CORTE atravessando o alvo e poucos riscos
## na direção do golpe. Dura ~0.15 s; sem partículas sobrando na tela.

var dir: Vector2 = Vector2.RIGHT
var color: Color = Color(2.0, 1.8, 1.4)
var weight: float = 0.2
var crit: bool = false
var _t: float = 0.0
var _life: float = 0.16
var _streaks: Array = [] ## [ângulo, comprimento, velocidade]
var _cut_angle: float = 0.0
var _start: int = -1


static func spawn(parent: Node, pos: Vector2, hit_dir: Vector2, c: Color, w: float, is_crit: bool = false) -> Node2D:
	if parent == null:
		return null
	var s := new()
	s.global_position = pos
	s.dir = hit_dir.normalized() if hit_dir != Vector2.ZERO else Vector2.RIGHT
	s.color = c
	s.weight = w
	s.crit = is_crit
	parent.add_child(s)
	return s


func _ready() -> void:
	z_index = 45
	_life = 0.14 + weight * 0.08
	# linha de corte perpendicular-ish ao golpe, com leve variação
	_cut_angle = dir.angle() + PI * 0.5 + randf_range(-0.5, 0.5)
	var n := 3 + int(weight * 3.0) + (2 if crit else 0)
	for i in n:
		_streaks.append([dir.angle() + randf_range(-0.6, 0.6), randf_range(4.0, 9.0) * (1.0 + weight), randf_range(140.0, 260.0)])


func _process(_delta: float) -> void:
	# anda em tempo REAL: aparece durante o hitstop (tela congelada)
	if _start < 0:
		_start = Time.get_ticks_msec()
	_t = (Time.get_ticks_msec() - _start) / 1000.0
	if _t >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / _life
	var white := Color(3.0, 3.0, 3.0)
	# clarão: círculo cheio nos 2 primeiros quadros, depois anel que abre
	var r := (4.0 + weight * 5.0) * (1.0 + k * 0.8)
	if k < 0.25:
		draw_circle(Vector2.ZERO, r * 0.8, white)
	else:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(color.r, color.g, color.b, 1.0 - k), 1.0)
	# linha de corte
	var cut_len := (14.0 + weight * 16.0) * minf(k * 4.0, 1.0)
	var cd := Vector2.from_angle(_cut_angle)
	var a := 1.0 - k
	draw_line(-cd * cut_len, cd * cut_len, Color(white.r, white.g, white.b, a), 1.0 + (1.0 if weight > 0.5 else 0.0))
	# riscos na direção do golpe
	for s in _streaks:
		var sd := Vector2.from_angle(float(s[0]))
		var start := sd * float(s[2]) * _t * 0.35
		draw_line(start, start + sd * float(s[1]) * (1.0 - k), Color(color.r, color.g, color.b, a), 1.0)
