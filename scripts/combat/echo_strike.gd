class_name EchoStrike
extends Node2D
## Eco quântico: repete o golpe do jogador um instante depois, do lugar onde
## ele estava, com dano reduzido (magia Dobra Quântica).

const DELAY := 0.22

var owner_actor: Node = null
var step: Dictionary = {}
var kind: String = ""
var mult: float = 0.6
var facing: int = 1
var _t: float = 0.0
var _hitbox: Hitbox
var _fired: bool = false
var _ghost: AfterImage


static func spawn(p: Node, s: Dictionary, k: String, m: float) -> void:
	var e := EchoStrike.new()
	e.owner_actor = p
	e.step = s
	e.kind = k
	e.mult = m
	e.facing = p.facing
	e.global_position = p.global_position
	p.get_parent().add_child(e)
	var g := AfterImage.from_sprite(p.sprite, Color(0.6, 2.6, 2.4, 0.8), DELAY + 0.2)
	if g:
		p.get_parent().add_child(g)


func _ready() -> void:
	_hitbox = Hitbox.new()
	_hitbox.owner_actor = owner_actor
	_hitbox.team = owner_actor.team
	_hitbox.reflects = false
	_hitbox.info_factory = func(target):
		var info: DamageInfo = owner_actor.build_attack_info(step, kind, 1.0, target)
		info.amount *= mult
		info.tags.append("echo")
		return info
	add_child(_hitbox)
	_hitbox.set_box(step.get("box", [0, -30, 40, 30]), facing)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _fired and _t >= DELAY:
		_fired = true
		_hitbox.activate()
		var arc: Array = step.get("arc", [150, 40])
		FX.slash(global_position + Vector2(0, -6), facing, float(arc[0]), float(arc[1]) * AttackRunner.BOX_SCALE, Color(0.5, 1.6, 1.5))
	if _t >= DELAY + float(step.get("active", 0.08)) + 0.02:
		queue_free()
