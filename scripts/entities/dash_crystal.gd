class_name DashCrystal
extends Area2D
## Cristal de dash (Celeste): recarrega o dash no ar e renasce depois.

const RESPAWN := 2.5

var _t: float = 0.0
var _down: float = 0.0
var _light: PointLight2D


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
	_light = LightUtil.make_light(Color(0.5, 1.0, 1.0), 0.7, 0.4)
	if _light:
		add_child(_light)
	z_index = 10


func _physics_process(delta: float) -> void:
	_t += delta
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			FX.burst(global_position, Color(1.0, 2.6, 2.6), 8, 60.0)
			for b in get_overlapping_bodies():
				_on_body(b)
	if _light:
		_light.energy = 0.0 if _down > 0.0 else 0.6 + 0.15 * sin(_t * 5.0)
	queue_redraw()


func _on_body(b: Node) -> void:
	if _down > 0.0 or not (b is Player):
		return
	if b.dashes >= b.max_dashes() and b.air_jumps >= b.max_air_jumps():
		return
	b.refill_dash()
	_down = RESPAWN
	FX.burst(global_position, Color(1.0, 2.8, 2.8), 10, 180.0)
	FX.hitstop(0.03)
	Audio.play("pickup", 0.05, -4.0, 1.4)


func _draw() -> void:
	if _down > 0.0:
		draw_arc(Vector2.ZERO, 3.0, 0.0, TAU, 8, Color(0.6, 1.2, 1.2, 0.3), 1.0)
		return
	var b := roundf(sin(_t * 3.0))
	var pts := PackedVector2Array([Vector2(0, -4 + b), Vector2(3, b), Vector2(0, 4 + b), Vector2(-3, b)])
	draw_colored_polygon(pts, Color(0.6, 2.4, 2.4))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -2 + b), Vector2(1, b), Vector2(0, 2 + b), Vector2(-1, b)]), Color(2.8, 3.2, 3.2))
