class_name ResetBell
extends Node2D
## Sino de Recarga: GOLPEIE para recarregar o dash e ganhar um pulo extra —
## sem quicar (a trajetória continua). Golpe para baixo = pogo. Encadear
## sinos no ar é zigue-zague puro: golpe, pulo, dash, golpe...

const COOLDOWN := 1.0
const INK := Color(0.106, 0.082, 0.157)

var team: int = Layers.Team.NEUTRAL
var dead: bool = false
var facing: int = 1
var _down: float = 0.0
var _t: float = 0.0
var _swing: float = 0.0
var _glow: Sprite2D


func _ready() -> void:
	var hb := Hurtbox.new()
	hb.actor = self
	hb.team = team
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 6.0
	cs.shape = c
	hb.add_child(cs)
	add_child(hb)
	_glow = LightUtil.make_glow(Color(1.5, 0.8, 1.6, 0.45), 8.0)
	add_child(_glow)
	_t = randf() * 3.0
	z_index = 8


func body_center() -> Vector2:
	return global_position


func take_hit(info: DamageInfo) -> int:
	if _down > 0.0 or info.team != Layers.Team.PLAYER or info.is_hazard:
		return DamageInfo.Result.IGNORED
	var p: Node = info.source
	if p == null or not is_instance_valid(p) or not (p is Player):
		return DamageInfo.Result.IGNORED
	p.refill_dash()
	p.grant_bonus_jump()
	p.add_chain()
	if not p.grounded() and p._vy() > -Player.AIR_STALL:
		p._set_vy(-Player.AIR_STALL) # segura a queda um instante
		p.var_jump_t = 0.0
	_down = COOLDOWN
	_swing = 1.0 * signf(info.direction.x if info.direction.x != 0.0 else 1.0)
	FX.hitstop(0.04)
	FX.hit_spark(global_position, info.direction, Color(2.4, 1.6, 2.6), true)
	FX.burst(global_position, Color(2.0, 1.2, 2.2), 6, 70.0)
	Audio.play("bell", 0.04, -5.0)
	return DamageInfo.Result.HIT


func _physics_process(delta: float) -> void:
	_t += delta
	_swing = move_toward(_swing, 0.0, delta * 1.5)
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			FX.burst(global_position, Color(1.8, 1.2, 2.0), 4, 30.0)
	_glow.visible = _down <= 0.0
	queue_redraw()


func _draw() -> void:
	var sw := roundf(sin(_t * 18.0) * 2.0 * _swing)
	var body := Color(0.95, 0.55, 1.0) if _down <= 0.0 else Color(0.45, 0.35, 0.5)
	# alça
	draw_rect(Rect2(-1, -7, 2, 2), INK)
	# sino (trapézio) balançando
	var pts := PackedVector2Array([Vector2(-2 + sw, -5), Vector2(2 + sw, -5), Vector2(4 + sw, 2), Vector2(-4 + sw, 2)])
	draw_colored_polygon(PackedVector2Array([Vector2(-3 + sw, -6), Vector2(3 + sw, -6), Vector2(5 + sw, 3), Vector2(-5 + sw, 3)]), INK)
	draw_colored_polygon(pts, body)
	if _down <= 0.0:
		draw_rect(Rect2(-1 + sw, -4, 1, 4), Color(2.4, 1.8, 2.6))
	# badalo
	draw_rect(Rect2(-1 + sw * 1.5, 3, 2, 2), INK)
