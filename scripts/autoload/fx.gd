extends Node
## "Game feel": hitstop, câmera lenta, tremor de tela (trauma), números de
## dano, faíscas e cortes. Todos respeitam as opções de vídeo/assistência.

const SlashArc := preload("res://scripts/fx/slash_arc.gd")
const FloatingText := preload("res://scripts/fx/floating_text.gd")
const Burst := preload("res://scripts/fx/burst.gd")

var camera: Camera2D = null
var effects_root: Node = null ## onde efeitos de mundo são instanciados

var shake_offset: Vector2 = Vector2.ZERO
var trauma: float = 0.0
var flash_amount: float = 0.0 ## lido pelo post-process (aberração cromática)
var slowmo_active: bool = false

var _hitstop_until: float = 0.0
var _slowmo_until: float = 0.0
var _slowmo_scale: float = 1.0
var _noise := FastNoiseLite.new()
var _t: float = 0.0
var _last_real: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.frequency = 18.0
	_noise.seed = 7


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	var now := _now()
	var real_dt := clampf(now - _last_real, 0.0, 0.1)
	_last_real = now
	_t += real_dt
	var ts: float = float(Settings.gameplay("game_speed"))
	slowmo_active = now < _slowmo_until
	if get_tree().paused:
		ts = 1.0
	elif now < _hitstop_until:
		ts *= 0.0
	elif slowmo_active:
		ts *= _slowmo_scale
	Engine.time_scale = ts
	# tremor por trauma (quadrático)
	trauma = maxf(trauma - real_dt * 1.6, 0.0)
	var amt: float = trauma * trauma * float(Settings.video("screen_shake"))
	shake_offset = Vector2(_noise.get_noise_2d(_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _t * 60.0)) * 14.0 * amt
	flash_amount = maxf(flash_amount - real_dt * 4.0, 0.0)


# ---------------------------------------------------------------------------
# Tempo
# ---------------------------------------------------------------------------

func hitstop(duration: float) -> void:
	if not Settings.video("hitstop") or duration <= 0.0:
		return
	_hitstop_until = maxf(_hitstop_until, _now() + minf(duration, 0.25))


func slowmo(scale: float, duration: float) -> void:
	_slowmo_scale = minf(scale, _slowmo_scale) if slowmo_active else scale
	_slowmo_until = maxf(_slowmo_until, _now() + duration)


func clear_time_effects() -> void:
	_hitstop_until = 0.0
	_slowmo_until = 0.0
	_slowmo_scale = 1.0
	Engine.time_scale = float(Settings.gameplay("game_speed"))


# ---------------------------------------------------------------------------
# Tela
# ---------------------------------------------------------------------------

func shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func flash(amount: float = 1.0) -> void:
	flash_amount = maxf(flash_amount, amount)


# ---------------------------------------------------------------------------
# Efeitos no mundo
# ---------------------------------------------------------------------------

func _root() -> Node:
	if is_instance_valid(effects_root):
		return effects_root
	return get_tree().current_scene


func damage_number(pos: Vector2, amount: float, crit: bool = false, color: Color = Color(1, 1, 1)) -> void:
	if not Settings.video("damage_numbers"):
		return
	var t := FloatingText.new()
	t.text = str(int(round(amount)))
	t.color = Color(2.2, 1.6, 0.4) if crit else color
	t.big = crit
	t.global_position = pos + Vector2(randf_range(-6, 6), -10)
	_root().add_child(t)


func text(pos: Vector2, s: String, color: Color = Color(1, 1, 1)) -> void:
	var t := FloatingText.new()
	t.text = s
	t.color = color
	t.global_position = pos
	_root().add_child(t)


func slash(pos: Vector2, facing: int, arc_deg: float, radius: float, color: Color, rotation_offset: float = 0.0, thrust: bool = false) -> void:
	var s := SlashArc.new()
	s.global_position = pos
	s.facing = facing
	s.arc_deg = arc_deg
	s.radius = radius
	s.color = color
	s.thrust = thrust
	s.rotation = rotation_offset
	_root().add_child(s)


func burst(pos: Vector2, color: Color, amount: int = 10, speed: float = 160.0, dir: Vector2 = Vector2.ZERO, spread_deg: float = 180.0, lifetime: float = 0.35, size: float = 2.0) -> void:
	var q: int = int(Settings.video("particles"))
	if q == 0:
		amount = int(amount * 0.35)
	elif q == 1:
		amount = int(amount * 0.65)
	if amount <= 0:
		return
	var b := Burst.new()
	b.global_position = pos
	b.setup(color, amount, speed, dir, spread_deg, lifetime, size)
	_root().add_child(b)


## Pacote padrão de impacto: hitstop + tremor + faíscas + número.
func impact(pos: Vector2, dir: Vector2, amount: float, crit: bool, heavy: bool, color: Color = Color(2.0, 1.8, 1.4)) -> void:
	hitstop(0.09 if crit or heavy else 0.05)
	shake(0.35 if heavy else (0.25 if crit else 0.14))
	burst(pos, color, 14 if crit else 9, 220.0, dir, 70.0, 0.28, 2.0)
	damage_number(pos, amount, crit)
	if crit or heavy:
		flash(0.6)
