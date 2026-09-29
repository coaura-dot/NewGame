class_name ChaseWall
extends Node2D
## Sala de fuga: uma muralha de espinhos avança pela sala a partir da porta
## de entrada — não dá para parar. Se o herói se machucar (ou cair), volta
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
	_hz.damage = 20.0
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
	# desenha em coordenadas do mundo (o nó fica na origem)
	var x0 := minf(_back(), front)
	var x1 := maxf(_back(), front)
	var top := rect.position.y
	var h := rect.size.y
	var mass := Color(0.16, 0.1, 0.22)
	draw_rect(Rect2(Vector2(x0, top).round(), Vector2(x1 - x0, h).round()), mass)
	# dentes na borda da frente, balançando
	var fx := roundf(front)
	var y := 0.0
	var k := 0
	while y < h:
		var wob := roundf(2.0 * sin(_t * 9.0 + k * 1.3))
		var p0 := Vector2(fx, top + y)
		var tip := Vector2(fx + dir * (5.0 + wob), top + y + 3.0)
		var p1 := Vector2(fx, top + y + 6.0)
		draw_colored_polygon(PackedVector2Array([p0, tip, p1]), mass)
		draw_line(p0, tip, Color(1.8, 0.5, 1.2), 1.0)
		y += 6.0
		k += 1
	# brilho da borda (HDR = bloom)
	draw_line(Vector2(fx - dir, top), Vector2(fx - dir, top + h), Color(2.2, 0.7, 1.6, 0.8), 1.0)
