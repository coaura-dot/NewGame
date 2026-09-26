class_name AttackRunner
extends Node
## Executa um golpe a partir dos dados da classe de arma (startup → active →
## recovery), com multi-hit, avanço (lunge), janela de encadeamento e golpe
## carregado. Usado igualzinho por jogador e inimigos.

signal started(step: Dictionary, kind: String)
signal activated(step: Dictionary, kind: String)
signal finished(step: Dictionary, kind: String)
signal landed(target: Node, info: DamageInfo, result: int)

enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }

## Os movesets em data/ foram escritos para um herói grande; aqui eles são
## convertidos para o mundo 320x180 (herói ~12 px) e para golpes rápidos
## estilo Hollow Knight.
const BOX_SCALE := 0.33
const LUNGE_SCALE := 0.35
const KB_SCALE := 0.5
const STARTUP_SCALE := 0.6
const ACTIVE_SCALE := 0.9
const RECOVERY_SCALE := 0.8


static func scaled(step: Dictionary) -> Dictionary:
	if step.get("_scaled", false):
		return step
	var s := step.duplicate(true)
	var box: Array = step.get("box", [0, -30, 40, 30])
	s["box"] = [float(box[0]) * BOX_SCALE, float(box[1]) * BOX_SCALE, float(box[2]) * BOX_SCALE, float(box[3]) * BOX_SCALE]
	s["lunge"] = float(step.get("lunge", 0.0)) * LUNGE_SCALE
	s["kb"] = float(step.get("kb", 150.0)) * KB_SCALE
	s["startup"] = float(step.get("startup", 0.05)) * STARTUP_SCALE
	s["active"] = float(step.get("active", 0.08)) * ACTIVE_SCALE
	s["recovery"] = float(step.get("recovery", 0.15)) * RECOVERY_SCALE
	s["_scaled"] = true
	return s

var actor: Node = null
var hitbox: Hitbox
var phase: int = Phase.IDLE
var step: Dictionary = {}
var kind: String = ""
var combo_index: int = 0
var charge_mult: float = 1.0
var speed_mult: float = 1.0 ## multiplicador de velocidade de ataque
var t: float = 0.0
var _hits_done: int = 0
var _facing: int = 1


func _init(owner_actor: Node = null) -> void:
	actor = owner_actor


func _ready() -> void:
	hitbox = Hitbox.new()
	hitbox.owner_actor = actor
	hitbox.team = actor.team
	hitbox.info_factory = _make_info
	hitbox.hit.connect(func(target, info, result): landed.emit(target, info, result))
	actor.add_child.call_deferred(hitbox)


func is_busy() -> bool:
	return phase != Phase.IDLE


func is_active() -> bool:
	return phase == Phase.ACTIVE


func start(new_step: Dictionary, new_kind: String, facing: int, charge: float = 1.0) -> void:
	step = scaled(new_step)
	kind = new_kind
	charge_mult = charge
	_facing = facing
	phase = Phase.STARTUP
	t = 0.0
	_hits_done = 0
	hitbox.team = actor.team
	hitbox.info_factory = _make_info
	hitbox.set_box(step.get("box", [0, -30, 40, 30]), facing)
	hitbox.pogo = step.get("pogo", false)
	started.emit(step, kind)


func cancel() -> void:
	if phase == Phase.ACTIVE:
		hitbox.deactivate()
	phase = Phase.IDLE
	step = {}


func tick(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	t += delta * speed_mult
	match phase:
		Phase.STARTUP:
			if t >= float(step.get("startup", 0.05)):
				t = 0.0
				phase = Phase.ACTIVE
				_hits_done = 1
				hitbox.activate()
				activated.emit(step, kind)
		Phase.ACTIVE:
			var active := float(step.get("active", 0.08))
			var hits := int(step.get("hits", 1))
			if hits > 1 and _hits_done < hits and t >= active * float(_hits_done) / hits:
				_hits_done += 1
				hitbox.rearm()
			if t >= active:
				t = 0.0
				phase = Phase.RECOVERY
				hitbox.deactivate()
		Phase.RECOVERY:
			if t >= float(step.get("recovery", 0.15)):
				var done_step := step
				var done_kind := kind
				phase = Phase.IDLE
				step = {}
				finished.emit(done_step, done_kind)


## Pode encadear o próximo golpe do combo agora?
func can_chain() -> bool:
	if phase != Phase.RECOVERY:
		return false
	return t >= float(step.get("recovery", 0.15)) * float(step.get("chain_at", 0.3))


## Tempo até o fim da recuperação (para o sistema de ritmo).
func time_to_end() -> float:
	if phase != Phase.RECOVERY:
		return INF
	return float(step.get("recovery", 0.15)) - t


func progress() -> float:
	match phase:
		Phase.STARTUP:
			return 0.0
		Phase.ACTIVE:
			return t / maxf(float(step.get("active", 0.08)), 0.001)
		Phase.RECOVERY:
			return 1.0
	return 0.0


func _make_info(target: Node) -> DamageInfo:
	if actor.has_method("build_attack_info"):
		return actor.build_attack_info(step, kind, charge_mult, target)
	return null
