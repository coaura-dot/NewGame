extends Node2D
## Pedra que cai do teto: primeiro um aviso piscando no chão (onde vai cair),
## depois a pedra despenca. Vermelha: saia de baixo.

var owner_actor: Node = null
var damage: float = 8.0
var delay: float = 0.75
var _t: float = 0.0
var _fired: bool = false


func setup(owner: Node, floor_pos: Vector2, wait: float, dmg: float) -> void:
	owner_actor = owner
	global_position = floor_pos
	delay = wait
	damage = dmg


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	_t += delta
	if not _fired and _t >= delay:
		_fired = true
		_drop()
	if _fired and _t > delay + 0.1:
		queue_free()
	queue_redraw()


func _drop() -> void:
	var p := Projectile.new()
	p.team = owner_actor.team if owner_actor and is_instance_valid(owner_actor) else Layers.Team.ENEMY
	p.owner_actor = owner_actor
	var inf := DamageInfo.new()
	inf.amount = damage
	inf.damage_type = "blunt"
	inf.source = owner_actor
	inf.team = p.team
	inf.is_projectile = true
	inf.parryable = false
	inf.unblockable = true
	p.info = inf
	p.reflectable = false
	p.velocity = Vector2(0, 300.0)
	p.radius = 4.0
	p.lifetime = 1.2
	p.color = Color(0.75, 0.68, 0.6)
	p.light_enabled = false
	p.global_position = global_position + Vector2(0, -120.0)
	get_parent().add_child(p)


func _draw() -> void:
	if _fired:
		return
	# aviso: traço vermelho no chão piscando cada vez mais rápido + poeira caindo
	var k := _t / maxf(delay, 0.01)
	var on := fmod(_t * (6.0 + 14.0 * k), 1.0) < 0.6
	if on:
		draw_rect(Rect2(-5, -1, 10, 1), Color(3.0, 0.6, 0.4, 0.9))
		draw_rect(Rect2(-3, -2, 6, 1), Color(3.0, 0.9, 0.5, 0.6))
	var dy := -110.0 + fmod(_t * 160.0, 100.0)
	draw_rect(Rect2(Vector2(-1, dy), Vector2(1, 1)), Color(0.9, 0.85, 0.8, 0.7))
	draw_rect(Rect2(Vector2(2, dy + 30.0), Vector2(1, 1)), Color(0.9, 0.85, 0.8, 0.5))
