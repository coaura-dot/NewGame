class_name Turret
extends Node2D
## Torreta rítmica presa na parede/teto: atira numa direção FIXA, sempre no
## mesmo compasso (padrão aprendível — perfeccionismo). A bala pode ser
## REBATIDA com um golpe (estilo Katana Zero): rebater no ar recarrega o dash
## e segura a queda; a bala rebatida volta e destrói a torreta. Golpes comuns
## só fazem "clang" (mas o golpe para baixo quica nela, como pogo).

const INK := Color(0.106, 0.082, 0.157)
const WINDUP := 0.4
const BULLET_SPEED := 95.0

var dir: Vector2 = Vector2.RIGHT
var period: float = 1.6
var phase: float = 0.0 ## 0..1 do período (torretas da mesma sala se alternam)
var damage: float = 12.0
var level: Node = null
var room_index: int = -1

var team: int = Layers.Team.ENEMY
var dead: bool = false
var facing: int = 1
var _t: float = 0.0
var _flash: float = 0.0
var _broken: bool = false


func _ready() -> void:
	add_to_group("turrets")
	facing = 1 if dir.x >= 0.0 else -1
	var hb := Hurtbox.new()
	hb.actor = self
	hb.team = team
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, 8)
	cs.shape = r
	hb.add_child(cs)
	add_child(hb)
	_t = phase * period - 0.6 # respiro ao entrar na sala
	z_index = 6


func body_center() -> Vector2:
	return global_position


func _active() -> bool:
	if level == null or not is_instance_valid(level) or room_index < 0:
		return true
	return int(level.get("_current_room")) == room_index


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta * 5.0, 0.0)
	if _broken:
		return
	if not _active():
		_t = phase * period - 0.6
		return
	_t += delta
	if _t >= period:
		_t -= period
		_fire()
	queue_redraw()


func _fire() -> void:
	var p := Projectile.new()
	p.team = Layers.Team.ENEMY
	p.owner_actor = self
	var info := DamageInfo.new()
	info.amount = damage
	info.damage_type = "pierce"
	info.team = Layers.Team.ENEMY
	info.source = self
	info.knockback = dir * 60.0 + Vector2(0, -40)
	p.info = info
	p.velocity = dir * BULLET_SPEED
	p.radius = 2.0
	p.lifetime = 4.0
	p.color = Color(2.6, 1.1, 0.5)
	p.light_enabled = false
	p.global_position = global_position + dir * 5.0
	get_parent().add_child(p)
	_flash = 1.0
	Audio.play("spell", 0.1, -14.0, 1.7)


## Golpe comum: "clang". Bala rebatida: quebra.
func take_hit(info: DamageInfo) -> int:
	if _broken or info.team == team or info.is_hazard:
		return DamageInfo.Result.IGNORED
	if info.tags.has("reflected"):
		_break()
		return DamageInfo.Result.KILLED
	FX.hit_spark(global_position, info.direction, Color(2.4, 2.4, 2.0), false)
	Audio.play("hit_metal", 0.1, -6.0)
	_flash = 0.6
	return DamageInfo.Result.BLOCKED


func _break() -> void:
	_broken = true
	FX.shake(0.2)
	FX.hitstop(0.05)
	FX.burst(global_position, Color(2.4, 1.3, 0.6), 12, 90.0)
	FX.hit_spark(global_position, -dir, Color(3, 2.4, 1.6), true)
	Audio.play("explosion", 0.1, -6.0)
	if level and level.has_method("spawn_currency"):
		level.spawn_currency(3, global_position)
	queue_redraw()


func _draw() -> void:
	# base presa na parede atrás (oposta ao tiro) + cano apontando
	var back := -dir
	var side := Vector2(-dir.y, dir.x)
	var body := Color(0.42, 0.4, 0.5) if not _broken else Color(0.3, 0.28, 0.34)
	var plate_c := back * 3.0
	_rect_centered(plate_c, (side.abs() * 8.0 + back.abs() * 2.0), INK)
	_rect_centered(plate_c, (side.abs() * 6.0 + back.abs() * 2.0), body.darkened(0.2))
	_rect_centered(Vector2.ZERO, Vector2(6, 6), INK)
	_rect_centered(Vector2.ZERO, Vector2(4, 4), body)
	if _broken:
		_rect_centered(dir * 1.0, Vector2(2, 2), INK)
		return
	# cano
	_rect_centered(dir * 3.5, side.abs() * 4.0 + dir.abs() * 3.0, INK)
	_rect_centered(dir * 3.5, side.abs() * 2.0 + dir.abs() * 3.0, body.lightened(0.15))
	# olho: acende no aviso antes do tiro
	var warn := clampf((_t - (period - WINDUP)) / WINDUP, 0.0, 1.0) if _t > 0.0 else 0.0
	var eye := Color(0.9, 0.35, 0.25).lerp(Color(3.0, 1.6, 0.8), maxf(warn, _flash))
	_rect_centered(Vector2.ZERO, Vector2(2, 2), eye)
	if warn > 0.5 and int(_t * 20.0) % 2 == 0:
		_rect_centered(dir * 7.0, Vector2(1, 1), Color(3.0, 1.8, 1.0, 0.8))


func _rect_centered(c: Vector2, size: Vector2, col: Color) -> void:
	draw_rect(Rect2((c - size * 0.5).round(), size.round()), col)
