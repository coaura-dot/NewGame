class_name ImpetoOrb
extends Node2D
## Lanterna de Ímpeto: orbe flutuante que, ao ser GOLPEADA (qualquer ataque
## ou o Corte-Relâmpago), recarrega o dash e o pulo no ar. Golpe para baixo
## quica (pogo). Apaga por um instante e reacende. É a peça-chave do parkour
## com combate: dash → corta a lanterna → dash → corta → ...

const RESPAWN := 1.2

var _t: float = 0.0
var _down: float = 0.0
var _pop: float = 0.0
var _light: PointLight2D
var _hurt: Hurtbox
## interface mínima de "ator" (magias, relíquias e correntes de raio tratam
## qualquer dono de Hurtbox como ator: centro, time, morto, direção)
var team: int = -99
var dead: bool = false
var facing: int = 1


func _ready() -> void:
	z_index = 9
	add_to_group("impeto_orbs")
	_t = randf() * TAU
	_hurt = Hurtbox.new()
	_hurt.actor = self
	_hurt.team = -99 # neutra: qualquer lado pode golpear
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 6.0
	cs.shape = c
	_hurt.add_child(cs)
	add_child(_hurt)
	_light = LightUtil.make_light(Color(1.0, 0.8, 0.45), 0.8, 0.45)
	if _light:
		add_child(_light)


func body_center() -> Vector2:
	return global_position


## Chamado pelo Hurtbox quando um golpe acerta.
func take_hit(info: DamageInfo) -> int:
	if _down > 0.0:
		return DamageInfo.Result.IGNORED
	var p = info.source
	if not (p is Player):
		return DamageInfo.Result.IGNORED
	_down = RESPAWN
	_pop = 1.0
	p.refill_dash()
	p.dash_cd = 0.0 # (o pogo do golpe para baixo é feito pelo próprio jogador)
	FX.hitstop(0.05)
	FX.kick(info.direction, 2.0)
	FX.burst(global_position, Color(2.8, 2.0, 0.9), 8, 160.0)
	HitSparkFX.spawn(get_parent(), global_position, info.direction, Color(2.6, 1.9, 0.8), 0.3)
	Audio.play("orb", 0.05, -2.0)
	return DamageInfo.Result.HIT


func _physics_process(delta: float) -> void:
	_t += delta
	_pop = maxf(_pop - delta * 5.0, 0.0)
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			FX.burst(global_position, Color(2.4, 1.8, 0.8), 6, 50.0)
	if _light:
		_light.energy = 0.05 if _down > 0.0 else 0.7 + 0.15 * sin(_t * 4.0)
	queue_redraw()


func _draw() -> void:
	var bob := roundf(sin(_t * 2.5) * 1.0)
	var o := Vector2(0, bob)
	var out := Color(0.09, 0.07, 0.12)
	if _down > 0.0:
		# apagada: só a moldura
		draw_rect(Rect2(o + Vector2(-3, -3), Vector2(6, 6)), Color(0.35, 0.3, 0.3, 0.7), false, 1.0)
		return
	var glow := Color(2.6, 1.9, 0.8)
	var r := 3.0 + _pop * 2.0
	# losango (lanterna) com contorno e brilho no centro
	var pts := PackedVector2Array([o + Vector2(0, -r - 1), o + Vector2(r + 1, 0), o + Vector2(0, r + 1), o + Vector2(-r - 1, 0)])
	draw_colored_polygon(pts, out)
	var inner := PackedVector2Array([o + Vector2(0, -r), o + Vector2(r, 0), o + Vector2(0, r), o + Vector2(-r, 0)])
	draw_colored_polygon(inner, Color(1.6, 1.1, 0.5))
	draw_rect(Rect2(o + Vector2(-1, -1), Vector2(2, 2)), glow)
	# alça
	draw_line(o + Vector2(0, -r - 1), o + Vector2(0, -r - 3), out, 1.0)
