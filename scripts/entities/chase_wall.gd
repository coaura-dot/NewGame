class_name ChaseWall
extends Node2D
## Sala de fuga: A ESCURIDÃO (muralha de fumaça com olhos) avança pela sala a
## partir da porta de entrada — não dá para parar. Se o herói se machucar (ou cair), volta
## ao começo da sala e a muralha recomeça atrás dele. Se ele abrir muita
## vantagem, a muralha acelera um pouco (pressão constante).

const SPEED := 48.0
const CATCH_UP := 1.6
const DELAY := 1.0
const INK := Color(0.106, 0.082, 0.157)

var rect: Rect2 ## sala (mundo)
var dir: int = 1 ## +1 avança para a direita
var player: Node = null
var front: float = 0.0
var _wait: float = DELAY
var _hz: Hazard
var _shape: RectangleShape2D
var _t: float = 0.0
var _was_down: bool = false


func _ready() -> void:
	z_index = 20
	global_position = Vector2.ZERO
	_hz = Hazard.new()
	_hz.damage = 10.0
	_hz.pogoable = false
	var cs := CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(1, 1)
	cs.shape = _shape
	_hz.add_child(cs)
	add_child(_hz)
	reset()


func reset() -> void:
	front = rect.position.x - 10.0 if dir > 0 else rect.end.x + 10.0
	_wait = DELAY
	_update_shape()


func _down() -> bool:
	return player == null or not is_instance_valid(player) or player.dead or player.state == Player.State.RESPAWN


func _physics_process(delta: float) -> void:
	_t += delta
	if _down():
		_was_down = true
		return
	if _was_down:
		_was_down = false
		reset()
	if _wait > 0.0:
		_wait -= delta
	else:
		var sp := SPEED
		var lead: float = (player.global_position.x - front) * dir
		if lead > 150.0:
			sp *= CATCH_UP
		front += dir * sp * delta
		front = clampf(front, rect.position.x - 10.0, rect.end.x + 10.0)
	_update_shape()
	queue_redraw()


func _back() -> float:
	return rect.position.x - 40.0 if dir > 0 else rect.end.x + 40.0


func _update_shape() -> void:
	var x0 := minf(_back(), front)
	var x1 := maxf(_back(), front)
	# a caixa de dano fica 3 px atrás da borda desenhada (contato justo)
	_shape.size = Vector2(maxf(x1 - x0 - 3.0, 1.0), rect.size.y)
	_hz.global_position = Vector2((x0 + x1) * 0.5 - dir * 1.5, rect.get_center().y)


func _draw() -> void:
	# A ESCURIDÃO: massa de fumaça quase preta com a borda em tentáculos que
	# ondulam, um fio de luz violeta na ponta (é perigo!) e olhos piscando lá
	# dentro. Desenha em coordenadas do mundo (o nó fica na origem).
	var x0 := minf(_back(), front)
	var x1 := maxf(_back(), front)
	var top := rect.position.y
	var h := rect.size.y
	var mass := Color(0.035, 0.025, 0.065)
	var edge := Color(1.3, 0.45, 1.8, 0.75)
	draw_rect(Rect2(Vector2(x0, top).round(), Vector2(x1 - x0, h).round()), mass)
	var fx := roundf(front)
	var i := 0
	while float(i) * 2.0 < h:
		var yy := top + float(i) * 2.0
		var reach := roundf(3.0 + 2.5 * sin(_t * 5.0 + i * 0.7) + 2.0 * sin(_t * 2.3 + i * 0.23))
		var x_from := fx if dir > 0 else fx - reach
		draw_rect(Rect2(Vector2(x_from, yy), Vector2(reach, 2)), mass)
		var tip_x := fx + dir * reach - (0.0 if dir > 0 else 1.0)
		draw_rect(Rect2(Vector2(tip_x, yy), Vector2(1, 2)), edge)
		i += 1
	# fumaça solta na frente
	for k in 6:
		var py := top + fposmod(k * 29.0 + _t * 14.0, h)
		var px := fx + dir * (6.0 + fposmod(k * 7.0 + _t * 20.0, 10.0))
		draw_rect(Rect2(Vector2(px, py).round(), Vector2(2, 1)), Color(0.12, 0.08, 0.2, 0.7))
	# olhos lá dentro (piscam de vez em quando)
	for k in 8:
		if fposmod(_t * 0.7 + k * 0.37, 3.0) < 0.12:
			continue
		var ey := top + 6.0 + fposmod(k * 37.0, maxf(h - 12.0, 1.0))
		var ex := front - dir * (9.0 + fposmod(k * 23.0, 70.0))
		if (ex - x0) < 2.0 or (x1 - ex) < 2.0:
			continue
		var c := Color(0.6, 2.0, 2.2) if k % 3 else Color(2.0, 0.6, 1.4)
		draw_rect(Rect2(Vector2(ex, ey).round(), Vector2.ONE), c)
		draw_rect(Rect2(Vector2(ex + 3.0, ey).round(), Vector2.ONE), c)
