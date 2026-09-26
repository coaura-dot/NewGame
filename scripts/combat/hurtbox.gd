class_name Hurtbox
extends Area2D
## Área que recebe golpes. Um ator pode ter vários (ex.: ponto fraco com
## multiplicador maior — acertar a cabeça do chefe).

var actor: Node = null
var team: int = Layers.Team.ENEMY
var weak_point_mult: float = 1.0
var label: String = ""


func _init() -> void:
	collision_layer = Layers.HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true


static func make(owner_actor: Node, size: Vector2, offset: Vector2, mult: float = 1.0) -> Hurtbox:
	var h := Hurtbox.new()
	h.actor = owner_actor
	h.team = owner_actor.team
	h.weak_point_mult = mult
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = offset
	h.add_child(cs)
	return h


func receive(info: DamageInfo) -> int:
	if actor == null or not is_instance_valid(actor):
		return DamageInfo.Result.IGNORED
	info.weak_point_mult = maxf(info.weak_point_mult, weak_point_mult)
	return actor.take_hit(info)
