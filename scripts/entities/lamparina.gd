class_name Lamparina
extends Area2D
## Lamparina apagada: o Pavio acende só de passar raspando (ou de golpear).
## Acesa, ilumina a área de vez, solta brasas e conta para a fase
## ("Lamparinas acesas 7/9" no resumo; todas = bônus de Lumeeiro).
## Em SALA SOMBRIA cada lamparina acesa devolve um pouco da luz da sala.

signal lit_up(lamp: Lamparina)

const REWARD := 2 ## brasas por lamparina
const INK := Color(0.07, 0.05, 0.1)
const IRON := Color(0.3, 0.27, 0.36)
const IRON_HI := Color(0.5, 0.46, 0.58)
const FLAME := Color(2.6, 1.5, 0.5)
const FLAME_CORE := Color(3.0, 2.6, 1.6)

var lit: bool = false
var room_index: int = -1
var _t: float = 0.0
var _pop: float = 0.0
var _light: PointLight2D
var _glow: Sprite2D
var _ember: Sprite2D


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS | Layers.HITBOX
	monitoring = true
	monitorable = true


func _ready() -> void:
	z_index = -2
	_t = randf() * 10.0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 9.0
	cs.shape = c
	cs.position = Vector2(0, -6)
	add_child(cs)
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)
	# apagada: só uma brasinha fraca pulsando dentro da gaiola
	_ember = LightUtil.make_glow(Color(1.0, 0.45, 0.2, 0.25), 4.0)
	_ember.position = Vector2(0, -7)
	add_child(_ember)


func _on_body(b: Node) -> void:
	if b is Player:
		light_up()


## Golpe do herói também acende (hitbox do jogador).
func _on_area(a: Area2D) -> void:
	if a is Hitbox and (a as Hitbox).owner_actor is Player:
		light_up()


func light_up() -> void:
	if lit:
		return
	lit = true
	add_to_group("lamps_lit")
	_pop = 1.0
	_ember.visible = false
	_glow = LightUtil.make_glow(Color(1.0, 0.6, 0.25, 0.4), 14.0)
	_glow.position = Vector2(0, -7)
	add_child(_glow)
	_light = LightUtil.make_light(Color(1.0, 0.75, 0.45), 0.75, 1.25)
	if _light:
		_light.position = Vector2(0, -8)
		add_child(_light)
	FX.burst(global_position + Vector2(0, -7), Color(2.4, 1.3, 0.5), 10, 55.0)
	FX.ring(global_position + Vector2(0, -7), Color(2.0, 1.2, 0.5), 18.0)
	Audio.play("lamp", 0.06, -4.0)
	Game.profile["currency"] = int(Game.profile.get("currency", 0)) + REWARD
	lit_up.emit(self)


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(_pop - delta * 2.5, 0.0)
	if lit:
		var f := 1.0 + 0.1 * sin(_t * 11.0) + 0.06 * sin(_t * 23.0)
		if _light:
			_light.energy = 0.75 * f + _pop * 0.8
		if _glow:
			_glow.scale = Vector2.ONE * (28.0 / 64.0) * (f + _pop * 0.6)
	else:
		_ember.modulate.a = 0.15 + 0.12 * (0.5 + 0.5 * sin(_t * 2.2))
	queue_redraw()


func _draw() -> void:
	# poste de ferro + gaiola 5x6 (origem = pé)
	draw_rect(Rect2(-1, -3, 2, 3), INK)
	draw_rect(Rect2(-2, -1, 4, 1), INK)
	draw_rect(Rect2(-3, -11, 7, 8), INK)
	draw_rect(Rect2(-2, -10, 5, 6), IRON if not lit else Color(0.34, 0.24, 0.2))
	draw_rect(Rect2(-2, -10, 5, 1), IRON_HI)
	draw_rect(Rect2(-1, -12, 3, 1), INK)
	draw_rect(Rect2(0, -13, 1, 1), IRON_HI)
	# vidro: escuro apagada, chama viva acesa
	if lit:
		var k := int(_t * 9.0) % 3
		draw_rect(Rect2(-1, -9, 3, 4), Color(0.9, 0.45, 0.15))
		draw_rect(Rect2(0, -8 - (1 if k == 1 else 0), 1, 3), FLAME)
		draw_rect(Rect2(0, -7, 1, 1), FLAME_CORE)
		if _pop > 0.0:
			draw_rect(Rect2(-1, -10 - int(_pop * 3.0), 3, 1), Color(FLAME.r, FLAME.g, FLAME.b, _pop))
	else:
		draw_rect(Rect2(-1, -9, 3, 4), Color(0.1, 0.08, 0.14))
		draw_rect(Rect2(0, -6, 1, 1), Color(0.8, 0.35, 0.15, 0.5 + 0.4 * sin(_t * 2.2)))
