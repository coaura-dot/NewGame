extends Node2D
## Ilusão do Espelho Etéreo: uma cópia translúcida aparece, brilha e dispara
## um estilhaço (amarelo: dá para rebater) e some. Só a de verdade sangra.

var owner_actor: Node = null
var damage: float = 5.0
var delay: float = 0.6
var _t: float = 0.0
var _fired: bool = false
var _tex: Texture2D = null
var _region: Rect2 = Rect2()
var _off: Vector2 = Vector2.ZERO


func setup(owner: Node, pos: Vector2, wait: float, dmg: float) -> void:
	owner_actor = owner
	global_position = pos
	delay = wait
	damage = dmg
	var spr: Node = owner.get("sprite")
	if spr and spr is AnimatedSprite2D and spr.sprite_frames:
		_tex = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)


func _ready() -> void:
	z_index = 7


func _process(delta: float) -> void:
	_t += delta
	if not _fired and _t >= delay:
		_fired = true
		_shoot()
	if _t > delay + 0.45:
		queue_free()
	queue_redraw()


func _shoot() -> void:
	var tgt: Node = get_tree().get_first_node_in_group("player")
	if tgt == null or not owner_actor or not is_instance_valid(owner_actor):
		return
	var dir: Vector2 = (tgt.body_center() - global_position).normalized()
	var p := Projectile.new()
	p.team = owner_actor.team
	p.owner_actor = owner_actor
	var inf := DamageInfo.new()
	inf.amount = damage
	inf.damage_type = "pierce"
	inf.source = owner_actor
	inf.team = p.team
	inf.is_projectile = true
	p.info = inf
	p.velocity = dir * 130.0
	p.radius = 2.5
	p.lifetime = 2.0
	p.color = Color(2.6, 1.2, 2.6)
	p.light_enabled = false
	p.global_position = global_position
	get_parent().add_child(p)
	FX.burst(global_position, Color(2.2, 1.6, 2.8), 6, 60.0)
	Audio.play("reflect", 0.1, -10.0, 1.4)


func _draw() -> void:
	var fade_in := clampf(_t / 0.2, 0.0, 1.0)
	var fade_out := 1.0 - clampf((_t - delay) / 0.45, 0.0, 1.0)
	var a := 0.55 * fade_in * fade_out
	var glow := 1.0 + (1.2 if _t > delay - 0.18 and not _fired else 0.0)
	if _tex:
		var sz := _tex.get_size()
		draw_texture(_tex, -sz * 0.5, Color(0.8 * glow, 0.9 * glow, 1.3 * glow, a))
	else:
		draw_rect(Rect2(-5, -7, 10, 14), Color(0.8, 0.9, 1.3, a))
