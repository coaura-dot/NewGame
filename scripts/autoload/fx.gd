extends Node
## "Game feel": hitstop, câmera lenta, tremor de tela (trauma), faíscas de
## impacto, cortes e textos no mundo. Tudo na escala de 320x180 e contido —
## a tela deve continuar limpa. Respeita as opções de vídeo/assistência.

const SlashArc := preload("res://scripts/fx/slash_arc.gd")
const FloatingText := preload("res://scripts/fx/floating_text.gd")
const Burst := preload("res://scripts/fx/burst.gd")
const HitSpark := preload("res://scripts/fx/hit_spark.gd")
const RingFx := preload("res://scripts/fx/ring_fx.gd")
const SpeedLines := preload("res://scripts/fx/speed_lines.gd")
const CutFx := preload("res://scripts/fx/cut_fx.gd")
const FONT_SMALL := preload("res://assets/fonts/kenney_mini.ttf")

var camera: Node = null
var effects_root: Node = null ## onde efeitos de mundo são instanciados

var shake_offset: Vector2 = Vector2.ZERO
var trauma: float = 0.0
var flash_amount: float = 0.0 ## aberração cromática (golpes fortes)
var screen_flash: float = 0.0 ## clarão branco na tela (aparo perfeito, dano)
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
		ts = 0.0
	elif slowmo_active:
		ts *= _slowmo_scale
	Engine.time_scale = ts
	trauma = maxf(trauma - real_dt * 2.2, 0.0)
	var amt: float = trauma * trauma * float(Settings.video("screen_shake"))
	shake_offset = Vector2(_noise.get_noise_2d(_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _t * 60.0)) * 5.0 * amt
	flash_amount = maxf(flash_amount - real_dt * 5.0, 0.0)
	screen_flash = maxf(screen_flash - real_dt * 6.0, 0.0)


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


## Aberração cromática curta (se ligada). Mantido o nome por compatibilidade.
func flash(amount: float = 1.0) -> void:
	flash_amount = maxf(flash_amount, amount)


## Clarão branco na tela inteira (bem curto).
func white_flash(amount: float = 0.35) -> void:
	if Settings.video("screen_flash"):
		screen_flash = maxf(screen_flash, amount)


# ---------------------------------------------------------------------------
# Efeitos no mundo
# ---------------------------------------------------------------------------

func _root() -> Node:
	if is_instance_valid(effects_root):
		return effects_root
	if PixelView.current and is_instance_valid(PixelView.current):
		return PixelView.current.world
	return get_tree().current_scene


func damage_number(pos: Vector2, amount: float, crit: bool = false, color: Color = Color(1, 1, 1)) -> void:
	if not Settings.video("damage_numbers"):
		return
	var t := FloatingText.new()
	t.text = str(int(round(amount)))
	t.color = Color(1.0, 0.85, 0.35) if crit else color
	t.global_position = pos + Vector2(randf_range(-3, 3), -4)
	t.small = true
	_root().add_child(t)


func text(pos: Vector2, s: String, color: Color = Color(1, 1, 1)) -> void:
	var t := FloatingText.new()
	t.text = s
	t.color = color
	t.global_position = pos
	_root().add_child(t)


func slash(pos: Vector2, facing: int, arc_deg: float, radius: float, color: Color, rotation_offset: float = 0.0, thrust: bool = false, width: float = 3.0) -> void:
	var s := SlashArc.new()
	s.global_position = pos
	s.facing = facing
	s.arc_deg = arc_deg
	s.radius = radius
	s.color = color
	s.thrust = thrust
	s.width = width
	s.rotation = rotation_offset
	_root().add_child(s)


func burst(pos: Vector2, color: Color, amount: int = 6, speed: float = 80.0, dir: Vector2 = Vector2.ZERO, spread_deg: float = 180.0, lifetime: float = 0.3, size: float = 1.0) -> void:
	var q: int = int(Settings.video("particles"))
	amount = int(amount * [0.35, 0.7, 1.0][clampi(q, 0, 2)])
	if amount <= 0:
		return
	var b := Burst.new()
	b.global_position = pos
	b.setup(color, amount, speed, dir, spread_deg, lifetime, maxf(size, 1.0))
	_root().add_child(b)


## Poeira no chão (pulo, aterrissagem, virada).
func dust(pos: Vector2, dir: Vector2 = Vector2.UP, amount: int = 3) -> void:
	burst(pos, Color(0.92, 0.9, 0.86, 0.8), amount, 30.0, dir, 70.0, 0.25, 1.0)


## Faísca de impacto estilo Hollow Knight: um clarão em estrela + poucas lascas.
func hit_spark(pos: Vector2, dir: Vector2, color: Color = Color(2.2, 2.1, 1.9), big: bool = false) -> void:
	var s := HitSpark.new()
	s.global_position = pos
	s.dir = dir
	s.color = color
	s.big = big
	_root().add_child(s)


## Anel que se expande (dash, chute de parede, quique, estouro de magia).
func ring(pos: Vector2, color: Color, radius: float = 10.0, life: float = 0.22, squash: Vector2 = Vector2.ONE) -> void:
	var r := RingFx.new()
	r.global_position = pos
	r.color = color
	r.radius = radius
	r.life = life
	r.squash = squash
	_root().add_child(r)


## Riscos de velocidade deixados para trás (dir = direção do movimento).
func speed_lines(pos: Vector2, dir: Vector2, color: Color = Color(2.0, 2.0, 2.4, 0.9), count: int = 5, length: float = 10.0) -> void:
	if int(Settings.video("particles")) <= 0:
		count = mini(count, 2)
	var s := SpeedLines.new()
	s.global_position = pos
	s.dir = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	s.color = color
	s.count = count
	s.length = length
	_root().add_child(s)


## Marca de corte atravessando o alvo na direção do golpe.
func cut(pos: Vector2, dir: Vector2, color: Color = Color(3.0, 3.0, 3.0), length: float = 16.0, width: float = 2.0) -> void:
	var c := CutFx.new()
	c.global_position = pos
	c.dir = dir.rotated(randf_range(-0.45, 0.45)) if dir != Vector2.ZERO else Vector2.from_angle(randf_range(-0.6, 0.6))
	c.color = color
	c.length = length
	c.width = width
	_root().add_child(c)


## Pacote padrão de impacto: hitstop + tremor + corte + faísca + número (opcional).
func impact(pos: Vector2, dir: Vector2, amount: float, crit: bool, heavy: bool, color: Color = Color(2.2, 2.0, 1.8)) -> void:
	hitstop(0.075 if crit or heavy else 0.045)
	shake(0.28 if heavy else (0.2 if crit else 0.12))
	cut(pos, dir, Color(3.0, 3.0, 2.8), 22.0 if crit or heavy else 15.0, 3.0 if crit or heavy else 2.0)
	hit_spark(pos, dir, color, crit or heavy)
	if crit or heavy:
		ring(pos, color, 9.0, 0.16)
	burst(pos, Color(color.r * 0.6, color.g * 0.6, color.b * 0.6), 4 if not heavy else 7, 110.0, dir, 50.0, 0.22, 1.0)
	damage_number(pos + Vector2(0, -6), amount, crit)
	if crit or heavy:
		flash(0.5)
