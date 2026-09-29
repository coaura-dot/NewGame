class_name JumpFeather
extends Area2D
## Pena de Pulo: encoste no ar para ganhar um PULO extra (vale mesmo sem o
## pulo duplo). Renasce depois de um instante. O pulo guardado some ao pousar.

const RESPAWN := 2.0
const INK := Color(0.106, 0.082, 0.157)

var _t: float = 0.0
var _down: float = 0.0
var _glow: Sprite2D


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	_glow = LightUtil.make_glow(Color(0.6, 1.6, 0.6, 0.45), 8.0)
	add_child(_glow)
	_t = randf() * 3.0
	z_index = 10


func _physics_process(delta: float) -> void:
	_t += delta
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			FX.burst(global_position, Color(1.0, 2.4, 1.0), 5, 40.0)
			for b in get_overlapping_bodies():
				_on_body(b)
	_glow.visible = _down <= 0.0
	queue_redraw()


func _on_body(b: Node) -> void:
	if _down > 0.0 or not (b is Player) or b.grounded() or b.bonus_jumps > 0:
		return
	b.grant_bonus_jump()
	b.add_chain()
	_down = RESPAWN
	FX.burst(global_position, Color(1.2, 2.6, 1.2), 8, 90.0)
	FX.hitstop(0.02)
	Audio.play("pickup", 0.05, -4.0, 1.7)


func _draw() -> void:
	if _down > 0.0:
		draw_rect(Rect2(-1, -1, 2, 2), Color(0.5, 0.9, 0.5, 0.45))
		return
	var b := roundf(sin(_t * 2.6) * 1.5)
	var sway := roundf(sin(_t * 1.7))
	# pena: haste + barbas em "V", verde brilhante
	var pts := PackedVector2Array([Vector2(sway, -6 + b), Vector2(3 + sway, -2 + b), Vector2(2, 3 + b), Vector2(0, 6 + b), Vector2(-2, 3 + b), Vector2(-3 + sway, -2 + b)])
	var inner := PackedVector2Array([Vector2(sway, -5 + b), Vector2(2 + sway, -2 + b), Vector2(1, 2 + b), Vector2(0, 4 + b), Vector2(-1, 2 + b), Vector2(-2 + sway, -2 + b)])
	draw_colored_polygon(pts, INK)
	draw_colored_polygon(inner, Color(0.45, 1.5, 0.55))
	draw_line(Vector2(sway, -4 + b), Vector2(0, 5 + b), Color(2.0, 2.8, 1.8), 1.0)
