class_name DashCrystal
extends Area2D
## Cristal de dash (Celeste): recarrega o dash no ar e renasce depois.
## Cristal DUPLO (rosa): dá 2 dashes mesmo para quem só tem 1.

const RESPAWN := 2.5

var double: bool = false

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
	_glow = LightUtil.make_glow(Color(1.6, 0.6, 1.2, 0.45) if double else Color(0.4, 1.4, 1.4, 0.45), 8.0)
	add_child(_glow)
	z_index = 10


func _physics_process(delta: float) -> void:
	_t += delta
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			FX.burst(global_position, Color(1.0, 2.4, 2.4), 5, 40.0)
			for b in get_overlapping_bodies():
				_on_body(b)
	_glow.visible = _down <= 0.0
	queue_redraw()


func _on_body(b: Node) -> void:
	if _down > 0.0 or not (b is Player):
		return
	var want: int = maxi(b.max_dashes(), 2) if double else b.max_dashes()
	if b.dashes >= want and b.air_jumps >= b.max_air_jumps():
		return
	b.refill_dash()
	if double:
		b.grant_dashes(2)
	b.add_chain()
	_down = RESPAWN
	FX.burst(global_position, Color(1.0, 2.6, 2.6), 8, 90.0)
	FX.hitstop(0.03)
	Audio.play("crystal", 0.05, -5.0, 0.8 if double else 1.0)


func _draw() -> void:
	var ink := Color(0.106, 0.082, 0.157)
	if _down > 0.0:
		draw_rect(Rect2(-1, -4, 2, 1), Color(0.5, 0.9, 0.9, 0.5))
		draw_rect(Rect2(-1, 3, 2, 1), Color(0.5, 0.9, 0.9, 0.5))
		return
	var b := roundf(sin(_t * 3.0) * 1.5)
	var outer := PackedVector2Array([Vector2(0, -6 + b), Vector2(4, b), Vector2(0, 6 + b), Vector2(-4, b)])
	draw_colored_polygon(outer, ink)
	var mid := PackedVector2Array([Vector2(0, -5 + b), Vector2(3, b), Vector2(0, 5 + b), Vector2(-3, b)])
	draw_colored_polygon(mid, Color(1.6, 0.5, 1.1) if double else Color(0.45, 1.6, 1.6))
	draw_rect(Rect2(-1, -2 + b, 1, 3), Color(3.0, 2.2, 2.8) if double else Color(2.4, 3.0, 3.0))
	if double:
		draw_rect(Rect2(1, -1 + b, 1, 2), Color(3.0, 2.2, 2.8))
