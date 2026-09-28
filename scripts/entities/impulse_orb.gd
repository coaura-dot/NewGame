class_name ImpulseOrb
extends Area2D
## Orbe de Impulso: GOLPEIE (qualquer ataque) para quicar — recarrega o dash
## e o pulo duplo. Golpe para baixo (pogo) quica mais alto. Atravessar com
## dash também recarrega. Some por um instante e volta. Encadear orbes,
## inimigos e espinhos sem tocar no chão é o coração do parkour-combate.

const COOLDOWN := 0.8
const BOUNCE := 160.0
const INK := Color(0.106, 0.082, 0.157)

var team: int = Layers.Team.NEUTRAL
var dead: bool = false
var facing: int = 1
var _down: float = 0.0
var _t: float = 0.0
var _pop_t: float = 0.0
var _glow: Sprite2D


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true
	add_to_group("impulse_orbs")


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	var hb := Hurtbox.new()
	hb.actor = self
	hb.team = team
	var hs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = 6.0
	hs.shape = hc
	hb.add_child(hs)
	add_child(hb)
	_glow = LightUtil.make_glow(Color(1.6, 1.1, 0.4, 0.5), 9.0)
	add_child(_glow)
	_t = randf() * 3.0
	z_index = 8


func body_center() -> Vector2:
	return global_position


func take_hit(info: DamageInfo) -> int:
	if _down > 0.0 or info.team != Layers.Team.PLAYER or info.is_hazard:
		return DamageInfo.Result.IGNORED
	var p: Node = info.source
	if p == null or not is_instance_valid(p) or not (p is Player):
		return DamageInfo.Result.IGNORED
	bounce(p, info.pogo or info.direction.y * p.g_dir > 0.5)
	return DamageInfo.Result.HIT


## Quica o herói (para cima; mais forte no pogo) e recarrega tudo.
func bounce(p: Player, strong: bool) -> void:
	var jm := float(p.phys.get("jump", 1.0))
	var speed := BOUNCE * (1.12 if strong else 1.0) * jm
	p._set_vy(-speed)
	p.var_jump_t = 0.12
	p.auto_jump_t = 0.12
	p.var_jump_speed = speed
	p.on_ground = false
	p.recoil_t = 0.0
	p.refill_dash()
	if p.state == Player.State.DASH:
		p._set_state(Player.State.NORMAL)
	if p.attack.kind == "down_air":
		p.attack.cancel()
	p.rig.bump(Vector2(0.75, 1.3))
	p.buffs.trigger("pogo")
	_pop()


func _pop() -> void:
	_down = COOLDOWN
	_pop_t = 1.0
	FX.hitstop(0.04)
	FX.shake(0.08)
	FX.hit_spark(global_position, Vector2.UP, Color(2.6, 2.0, 1.0), true)
	FX.burst(global_position, Color(2.2, 1.6, 0.6), 6, 70.0)
	Audio.play("pickup", 0.05, -6.0, 1.6)


func _on_body(b: Node) -> void:
	# atravessar com dash: recarrega sem quebrar o embalo
	if _down > 0.0 or not (b is Player) or b.state != Player.State.DASH:
		return
	b.refill_dash()
	_pop()


func _physics_process(delta: float) -> void:
	_t += delta
	_pop_t = maxf(_pop_t - delta * 6.0, 0.0)
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			FX.burst(global_position, Color(2.0, 1.6, 0.8), 4, 30.0)
	_glow.visible = _down <= 0.0
	queue_redraw()


func _draw() -> void:
	var b := roundf(sin(_t * 3.0))
	if _down > 0.0:
		# casca apagada esperando voltar
		draw_rect(Rect2(-2, -2 + b, 4, 4), Color(0.5, 0.45, 0.4, 0.5))
		return
	var r := 4 + int(_pop_t * 2.0)
	# anel escuro + núcleo dourado (cores HDR brilham com bloom)
	draw_rect(Rect2(-r + 1, -r + b, r * 2 - 2, r * 2), INK)
	draw_rect(Rect2(-r, -r + 1 + b, r * 2, r * 2 - 2), INK)
	draw_rect(Rect2(-r + 1, -r + 1 + b, r * 2 - 2, r * 2 - 2), Color(1.0, 0.72, 0.3))
	draw_rect(Rect2(-r + 2, -r + 2 + b, r * 2 - 4, r * 2 - 4), Color(1.9, 1.5, 0.7))
	draw_rect(Rect2(-1, -r + 2 + b, 2, 2), Color(3.0, 2.8, 2.2))
	# setinhas indicando "golpeie"
	var k := int(_t * 3.0) % 2
	draw_rect(Rect2(-1, -r - 3 - k + b, 2, 1), Color(1.0, 0.9, 0.6, 0.7))
