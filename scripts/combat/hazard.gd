class_name Hazard
extends Area2D
## Perigo do cenário (espinhos, serras, fogo). Machuca qualquer time —
## empurre inimigos para os espinhos! O jogador volta ao último chão seguro.

@export var damage: float = 15.0
@export var pogoable: bool = true
var _cooldown: Dictionary = {}


func _init() -> void:
	collision_layer = Layers.HITBOX
	collision_mask = Layers.HURTBOX
	monitoring = true
	monitorable = true


func add_rect(rect: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	add_child(cs)


func add_circle(center: Vector2, radius: float) -> void:
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	cs.position = center
	add_child(cs)


func _physics_process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for a in get_overlapping_areas():
		if not (a is Hurtbox) or a.actor == null:
			continue
		var key: int = a.actor.get_instance_id()
		if _cooldown.get(key, 0) > now:
			continue
		_cooldown[key] = now + 500
		var info := DamageInfo.new()
		info.amount = damage
		info.damage_type = "pierce"
		info.team = Layers.Team.NEUTRAL
		info.is_hazard = true
		info.parryable = false
		info.unblockable = true
		info.direction = (a.global_position - global_position).normalized()
		info.knockback = Vector2(0, -220)
		info.hit_position = a.global_position
		a.receive(info)
