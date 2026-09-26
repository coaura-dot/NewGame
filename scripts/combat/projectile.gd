class_name Projectile
extends Area2D
## Projétil genérico (magias, facas arremessadas, sopro de fogo). Pode ser
## rebatido por um ataque no momento certo (vira do time de quem rebateu).

var team: int = Layers.Team.ENEMY
var owner_actor: Node = null
var info: DamageInfo
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 2.0
var pierce: bool = false
var homing: float = 0.0
var radius: float = 3.0
var color: Color = Color(2.4, 1.2, 0.4)
var gravity_y: float = 0.0
var reflectable: bool = true
var texture: Texture2D = null
var hframes: int = 1
var time_scale: float = 1.0 ## campos de tempo alteram isso a cada frame
var light_enabled: bool = true

var _hit: Dictionary = {}
var _trail: Array[Vector2] = []
var _anim_t: float = 0.0
var _dead: bool = false


func _init() -> void:
	collision_layer = Layers.PROJECTILE
	collision_mask = Layers.HURTBOX | Layers.WORLD
	monitoring = true
	monitorable = true


func _ready() -> void:
	add_to_group("projectiles")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	z_index = 25
	if light_enabled:
		var l := LightUtil.make_light(Color(color.r, color.g, color.b).clamp(), 0.7, 0.3 + radius * 0.04)
		if l:
			add_child(l)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var d := delta * time_scale
	time_scale = 1.0
	_anim_t += d
	if homing > 0.0:
		var target := _nearest_enemy()
		if target:
			var want: Vector2 = (target.body_center() - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(homing * d, 0.0, 1.0))
	velocity.y += gravity_y * d
	global_position += velocity * d
	rotation = velocity.angle() if texture else 0.0
	_trail.push_front(global_position)
	if _trail.size() > 5:
		_trail.pop_back()
	lifetime -= d
	if lifetime <= 0.0:
		_explode(false)
		return
	for a in get_overlapping_areas():
		if a is Hurtbox and a.team != team and a.actor and not _hit.has(a.actor.get_instance_id()):
			_hit[a.actor.get_instance_id()] = true
			var hi := info.duplicate_info()
			hi.direction = velocity.normalized()
			if hi.knockback == Vector2.ZERO:
				hi.knockback = velocity.normalized() * 60.0 + Vector2(0, -30)
			hi.hit_position = global_position
			a.receive(hi)
			if not pierce:
				_explode(true)
				return
	queue_redraw()


func _nearest_enemy() -> Node:
	var best: Node = null
	var best_d := 130.0
	for a in get_tree().get_nodes_in_group("actors"):
		if a.team == team or a.dead:
			continue
		var dd: float = a.body_center().distance_to(global_position)
		if dd < best_d:
			best_d = dd
			best = a
	return best


func _on_body(_body: Node) -> void:
	_explode(true)


func _explode(impact: bool) -> void:
	if _dead:
		return
	_dead = true
	if impact:
		FX.burst(global_position, color, 5, 70.0)
	queue_free()


func reflect(new_owner: Node) -> void:
	team = new_owner.team
	owner_actor = new_owner
	info.team = team
	info.source = new_owner
	info.amount *= 1.5
	info.parryable = false
	var aim := Vector2(new_owner.facing, 0)
	if new_owner.has_method("aim_direction"):
		aim = new_owner.aim_direction()
	velocity = aim.normalized() * maxf(velocity.length() * 1.35, 130.0)
	lifetime = maxf(lifetime, 1.2)
	_hit.clear()
	color = Color(color.b, color.g, color.r) * 1.2
	FX.hitstop(0.06)
	FX.hit_spark(global_position, velocity.normalized(), Color(3, 3, 3), true)
	Audio.play("parry")


func _draw() -> void:
	var inv := get_global_transform().affine_inverse()
	for i in _trail.size():
		var f := 1.0 - float(i) / _trail.size()
		var r := maxf(radius * 0.6 * f, 0.5)
		draw_rect(Rect2((inv * _trail[i]).round() - Vector2(r, r), Vector2(r, r) * 2.0), Color(color.r, color.g, color.b, 0.3 * f))
	if texture:
		var fw := texture.get_width() / hframes
		var frame := int(_anim_t * 12.0) % hframes
		var src := Rect2(frame * fw, 0, fw, texture.get_height())
		draw_texture_rect_region(texture, Rect2(Vector2(-fw * 0.5, -texture.get_height() * 0.5), Vector2(fw, texture.get_height())), src)
	else:
		var r := maxf(radius, 1.0)
		draw_rect(Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), color)
		draw_rect(Rect2(Vector2(-r * 0.5, -r * 0.5).round(), Vector2(maxf(r, 1.0), maxf(r, 1.0))), Color(3.0, 3.0, 3.0))
