class_name Hitbox
extends Area2D
## Área de ataque ativa durante a janela "active" de um golpe. Registra quem
## já foi atingido (um acerto por alvo por ativação; multi-hit rearma).
## Também rebate projéteis inimigos (estilo Katana Zero) e detecta espinhos
## para o quique (pogo) do ataque para baixo.

signal hit(target: Node, info: DamageInfo, result: int)
signal pogo_surface(position: Vector2)
signal projectile_reflected(projectile: Node)

var owner_actor: Node = null
var team: int = Layers.Team.PLAYER
var active: bool = false
var pogo: bool = false
var reflects: bool = true
var info_factory: Callable ## func(target) -> DamageInfo
var _registry: Dictionary = {}
var _shape: CollisionShape2D


func _init() -> void:
	collision_layer = Layers.HITBOX
	collision_mask = Layers.HURTBOX | Layers.PROJECTILE | Layers.HITBOX
	monitorable = true
	monitoring = true
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_shape.disabled = true
	add_child(_shape)


## box = [x, y, w, h] relativo aos pés olhando para a direita.
func set_box(box: Array, facing: int) -> void:
	var w := float(box[2])
	var h := float(box[3])
	(_shape.shape as RectangleShape2D).size = Vector2(w, h)
	_shape.position = Vector2((float(box[0]) + w * 0.5) * facing, float(box[1]) + h * 0.5)


func activate() -> void:
	active = true
	_registry.clear()
	_shape.set_deferred("disabled", false)


func rearm() -> void:
	_registry.clear()


func deactivate() -> void:
	active = false
	_shape.set_deferred("disabled", true)


func _physics_process(_delta: float) -> void:
	if active:
		scan()


func scan() -> void:
	var hurtboxes: Array = []
	for a in get_overlapping_areas():
		if a is Hurtbox:
			hurtboxes.append(a)
		elif a is Projectile:
			_try_projectile(a)
		elif a is Hazard and pogo and a.pogoable:
			if not _registry.has(a.get_instance_id()):
				_registry[a.get_instance_id()] = true
				pogo_surface.emit(a.global_position)
	# pontos fracos primeiro
	hurtboxes.sort_custom(func(x, y): return x.weak_point_mult > y.weak_point_mult)
	for hb in hurtboxes:
		_try_hurtbox(hb)


func _try_hurtbox(hb: Hurtbox) -> void:
	if hb.team == team or hb.actor == null or hb.actor == owner_actor:
		return
	var key: int = hb.actor.get_instance_id()
	if _registry.has(key):
		return
	_registry[key] = true
	if not info_factory.is_valid():
		return
	var info: DamageInfo = info_factory.call(hb.actor)
	if info == null:
		return
	info.hit_position = hb.global_position
	var result: int = hb.receive(info)
	hit.emit(hb.actor, info, result)


func _try_projectile(p: Node) -> void:
	if not reflects or p.team == team or not p.reflectable:
		return
	var key := p.get_instance_id()
	if _registry.has(key):
		return
	_registry[key] = true
	p.reflect(owner_actor)
	projectile_reflected.emit(p)
