extends Projectile
## Onda de choque que corre rente ao chão depois de um salto/pancada de
## chefe. Vermelha: não dá para aparar nem rebater — PULE por cima.

var _t: float = 0.0


func setup(owner: Node, pos: Vector2, dir: int, damage: float, spd: float) -> void:
	team = owner.team
	owner_actor = owner
	var inf := DamageInfo.new()
	inf.amount = damage
	inf.damage_type = "blunt"
	inf.source = owner
	inf.team = owner.team
	inf.is_projectile = true
	inf.parryable = false
	inf.unblockable = true
	inf.knockback = Vector2(dir * 80.0, -120.0)
	info = inf
	reflectable = false
	velocity = Vector2(dir * spd, 0.0)
	radius = 3.0
	lifetime = 1.8
	color = Color(2.6, 1.4, 0.6)
	light_enabled = false
	global_position = pos + Vector2(0, -4)


func _physics_process(delta: float) -> void:
	_t += delta
	super._physics_process(delta)


func _draw() -> void:
	# crista de energia em forma de "onda" (3 px de altura, oscila)
	var dir := signf(velocity.x)
	var h := 6.0 + roundf(sin(_t * 30.0))
	var a := clampf(lifetime * 2.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-2, 4 - h), Vector2(4, h)), Color(color.r, color.g, color.b, a))
	draw_rect(Rect2(Vector2(-dir * 4 - 1, 1), Vector2(3, 3)), Color(1.6, 0.8, 0.4, a * 0.7))
	draw_rect(Rect2(Vector2(-1, 4 - h - 1), Vector2(2, 2)), Color(3.0, 2.6, 2.0, a))
