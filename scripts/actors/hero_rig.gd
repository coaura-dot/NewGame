class_name HeroRig
extends Node2D
## Desenha o Pavio, a velinha viva: quadro do corpo (assets/art/hero/hero.png,
## gerado por tools/pavio_art.py) + OLHOS e BOCHECHAS procedurais (expressões)
## + a CHAMA na cabeça + lâmina durante os golpes + squash & stretch.
## A origem é o meio dos pés.
##
## A chama é o "humor" do Pavio: tremula sempre, deita contra o movimento
## (no dash fica quase na horizontal), cresce quando ele está feliz ou
## focando, encolhe quando se machuca ou está com pouca vida, vira fumaça
## na morte e reacende com um estalo ao renascer. Cores HDR (brilham com o
## bloom).

const TEX := preload("res://assets/art/hero/hero.png")
const META_PATH := "res://assets/art/hero/hero.json"
const EYE := Color(0.106, 0.082, 0.157)
const BLUSH := Color(0.94, 0.54, 0.63)
const MOUTH := Color(0.55, 0.2, 0.26)
const FLAME_OUT := Color(2.2, 0.72, 0.2)
const FLAME_MID := Color(2.8, 1.9, 0.55)
const FLAME_CORE := Color(3.2, 3.0, 2.2)
const FLAME_TIP := Color(1.7, 0.45, 0.18)
const FLAME_H := 5.0 ## altura normal da chama (px)
const SMOKE := Color(0.62, 0.6, 0.66)
const SPRITE_FX := preload("res://shaders/sprite_fx.gdshader")

const ANIMS := {
	"idle": {"frames": ["idle0", "idle1"], "fps": 2.2},
	"run": {"frames": ["run0", "run1", "run2", "run3", "run4", "run5"], "fps": 13.0},
	"jump": {"frames": ["jump"], "fps": 1.0},
	"fall": {"frames": ["fall0", "fall1"], "fps": 9.0},
	"dash": {"frames": ["dash"], "fps": 1.0},
	"wall": {"frames": ["wall"], "fps": 1.0},
	"climb": {"frames": ["climb0", "climb1"], "fps": 7.0},
	"duck": {"frames": ["duck"], "fps": 1.0},
	"slash": {"frames": ["slash0", "slash1"], "fps": 22.0, "once": true},
	"slash_up": {"frames": ["slash_up"], "fps": 1.0},
	"slash_down": {"frames": ["slash_down"], "fps": 1.0},
	"cast": {"frames": ["cast"], "fps": 1.0},
	"focus": {"frames": ["focus"], "fps": 1.0},
	"hurt": {"frames": ["hurt"], "fps": 1.0},
	"dead": {"frames": ["dead"], "fps": 1.0},
	"sit": {"frames": ["sit"], "fps": 1.0},
}

static var _meta: Dictionary = {}

var anim: String = "idle"
var anim_t: float = 0.0
var frame_name: String = "idle0"
var facing: int = 1
var flip_v: bool = false
var squash: Vector2 = Vector2.ONE
## normal, blink, happy, wide, closed, angry, look_up, look_down, tired, dead
var expression: String = "normal"
var expression_t: float = 0.0 ## >0 = expressão temporária
var base_expression: String = "normal"
var blade: Dictionary = {} ## {len, color, dir (Vector2), t}
var cloak_tint: Color = Color.WHITE
var scarf_color: Color = Color(0.88, 0.28, 0.3) ## volta do cachecol na gola (cor = dashes)
var mat: ShaderMaterial
var _blink_t: float = 2.0
var _blinking: float = 0.0
# --- chama ---
var motion: Vector2 = Vector2.ZERO ## velocidade do herói (o jogador atualiza)
var vitality: float = 1.0 ## 0..1 (vida): chama menor com pouca vida
var lit: float = 1.0 ## 0 = apagada (morto), 1 = acesa
var flame_boost: float = 0.0 ## >0 cresce (feliz, foco, cadeia); decai sozinho
var _flame_hit: float = 0.0 ## >0 = chama "soprada" por um golpe
var _flame_t: float = 0.0
var _flame_lean: float = 0.0
var _flame_lean_v: float = 0.0
var _smoke: Array = [] ## [pos local, vel, vida]
var _smoke_t: float = 0.0


func _ready() -> void:
	if _meta.is_empty():
		var f := FileAccess.open(META_PATH, FileAccess.READ)
		if f:
			_meta = JSON.parse_string(f.get_as_text())
	mat = ShaderMaterial.new()
	mat.shader = SPRITE_FX
	material = mat


func play(a: String, restart: bool = false) -> void:
	if not ANIMS.has(a):
		return
	if a != anim or restart:
		anim = a
		anim_t = 0.0


func set_expression(e: String, duration: float = 0.0) -> void:
	if duration > 0.0:
		expression = e
		expression_t = duration
	else:
		base_expression = e


func bump(sq: Vector2) -> void:
	squash = sq


## Chama cresce por um instante (feliz, cura, cadeia...).
func flame_pop(amount: float = 0.5) -> void:
	flame_boost = maxf(flame_boost, amount)


## Golpe sofrido: a chama se abaixa, é soprada para o lado e solta fumaça.
func flame_blow(dir_x: float) -> void:
	_flame_hit = 0.45
	_flame_lean_v += -dir_x * facing * 40.0
	_puff_smoke(2)


## Apaga a chama (morte): vira fumaça.
func extinguish() -> void:
	lit = 0.0
	_puff_smoke(4)


## Reacende com um estalo (renascer / sentar no banco).
func relight() -> void:
	if lit < 1.0:
		lit = 1.0
		flame_boost = 0.9
		_flame_hit = 0.0


## Ponta da chama em coordenadas globais (para faíscas e brasas).
func flame_tip_global() -> Vector2:
	var b := _flame_base()
	return to_global(b + Vector2(0, -_flame_height()))


func _process(delta: float) -> void:
	var a: Dictionary = ANIMS[anim]
	anim_t += delta
	var frames: Array = a["frames"]
	var i := int(anim_t * float(a["fps"]))
	if a.get("once", false):
		i = mini(i, frames.size() - 1)
	else:
		i = i % frames.size()
	frame_name = frames[i]
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-delta * 14.0))
	if expression_t > 0.0:
		expression_t -= delta
		if expression_t <= 0.0:
			expression = base_expression
	else:
		expression = base_expression
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blinking = 0.12
		_blink_t = randf_range(2.2, 4.5)
	_blinking = maxf(_blinking - delta, 0.0)
	if blade.has("t"):
		blade["t"] = float(blade["t"]) - delta
		if blade["t"] <= 0.0:
			blade = {}
	_update_flame(delta)
	scale = Vector2(facing * squash.x, squash.y * (-1.0 if flip_v else 1.0))
	queue_redraw()


func frame_meta() -> Dictionary:
	return _meta.get("frames", {}).get(frame_name, {"index": 0, "eye": [7, 7], "neck": [5, 10], "hand": [11, 11]})


func frame_region() -> Rect2:
	var idx := int(frame_meta()["index"])
	var cols := int(_meta.get("cols", 8))
	return Rect2((idx % cols) * 16, (idx / cols) * 16, 16, 16)


## Âncora do quadro atual em coordenadas locais do jogador (sem espelhar).
func anchor(key: String) -> Vector2:
	var m := frame_meta()
	var p: Array = m.get(key, [8, 8])
	var local := Vector2(float(p[0]) - 8.0 + 0.5, float(p[1]) - 16.0 + 0.5)
	return Vector2(local.x * facing * squash.x, local.y * squash.y * (-1.0 if flip_v else 1.0))


func ghost_data() -> Dictionary:
	return {"texture": TEX, "region": frame_region(), "offset": Vector2(-8, -16), "flip_h": facing < 0, "flip_v": flip_v, "scale": Vector2(squash.x, squash.y)}


func _draw() -> void:
	draw_texture_rect_region(TEX, Rect2(-8, -16, 16, 16), frame_region(), cloak_tint)
	_draw_collar()
	_draw_cheeks()
	_draw_eyes()
	_draw_flame()
	_draw_smoke()
	if not blade.is_empty():
		_draw_blade()


# ---------------------------------------------------------------------------
# Chama
# ---------------------------------------------------------------------------

func _update_flame(delta: float) -> void:
	_flame_t += delta
	flame_boost = maxf(flame_boost - delta * 1.2, 0.0)
	_flame_hit = maxf(_flame_hit - delta, 0.0)
	match expression:
		"happy":
			flame_boost = maxf(flame_boost, 0.3)
		"angry":
			flame_boost = maxf(flame_boost, 0.15)
	if anim == "focus":
		flame_boost = maxf(flame_boost, 0.25 + 0.15 * sin(_flame_t * 8.0))
	# deita contra o movimento (mola: balança um pouco ao parar)
	var target := clampf(-motion.x / 55.0, -4.0, 4.0) * facing
	if anim == "dash":
		target = -4.0 if absf(motion.x) > 20.0 else target
	_flame_lean_v += (target - _flame_lean) * 160.0 * delta
	_flame_lean_v *= exp(-delta * 9.0)
	_flame_lean += _flame_lean_v * delta
	# fumaça
	if lit <= 0.0 and anim == "dead":
		_smoke_t -= delta
		if _smoke_t <= 0.0 and _smoke.size() < 10:
			_smoke_t = randf_range(0.12, 0.25)
			_puff_smoke(1)
	for s in _smoke:
		s[0] += s[1] * delta
		s[1].x += sin(_flame_t * 5.0 + s[2] * 7.0) * 12.0 * delta
		s[2] -= delta
	_smoke = _smoke.filter(func(s): return s[2] > 0.0)


func _flame_base() -> Vector2:
	var p: Array = frame_meta().get("flame", [8, 4])
	return Vector2(float(p[0]) - 8.0, float(p[1]) - 16.0)


func _flame_height() -> float:
	if lit <= 0.0:
		return 0.0
	var size := (0.55 + 0.45 * clampf(vitality, 0.0, 1.0)) * (1.0 + flame_boost)
	if _flame_hit > 0.0:
		size *= 0.45
	if anim == "hurt":
		size *= 0.6
	# vento vertical: subindo achata, caindo estica
	size *= 1.0 + clampf(motion.y / 240.0, -0.35, 0.45)
	var flicker := sin(_flame_t * 17.0) * 0.45 + sin(_flame_t * 29.0 + 1.3) * 0.35 + sin(_flame_t * 7.0) * 0.3
	return maxf(FLAME_H * size + flicker, 2.0)


func _draw_flame() -> void:
	var h := int(round(_flame_height()))
	if h <= 0:
		return
	var base := _flame_base()
	var big := h >= 7
	var sway := sin(_flame_t * 11.0) * 0.6 + sin(_flame_t * 23.0) * 0.4
	for i in h:
		var t := float(i) / float(maxi(h - 1, 1))
		var dx := roundf(_flame_lean * t * t + sway * t)
		var y := base.y - i
		var x := base.x + dx
		var w := 1
		if i > 0 and t < 0.62:
			w = 3
		if big and t > 0.18 and t < 0.45:
			w = 5
		var half := w / 2
		for k in range(-half, half + 1):
			var c := FLAME_OUT
			if absi(k) < half or w == 1:
				c = FLAME_MID
			if k == 0 and t > 0.12 and t < 0.5:
				c = FLAME_CORE
			if i == h - 1:
				c = FLAME_TIP
			elif i == 0:
				c = FLAME_OUT
			draw_rect(Rect2(x + k, y, 1, 1), c)
	# faísca solta de vez em quando, acima da ponta
	if fmod(_flame_t, 0.9) < 0.12 and h >= 4:
		draw_rect(Rect2(base.x + roundf(_flame_lean), base.y - h - 1, 1, 1), FLAME_MID)


func _puff_smoke(n: int) -> void:
	var b := _flame_base()
	for _i in n:
		_smoke.append([b + Vector2(randf_range(-0.5, 0.5), 0), Vector2(randf_range(-6, 6), randf_range(-22, -12)), randf_range(0.6, 1.1)])


func _draw_smoke() -> void:
	for s in _smoke:
		var life: float = s[2]
		var c := SMOKE
		c.a = clampf(life, 0.0, 0.8)
		var sz := 1.0 if life < 0.5 else 2.0
		draw_rect(Rect2(s[0].round(), Vector2(sz, sz)), c)


func _draw_collar() -> void:
	var col: Array = frame_meta().get("collar", [])
	if col.size() < 3:
		return
	var x0 := float(col[0]) - 8.0
	var x1 := float(col[1]) - 8.0
	var y := float(col[2]) - 16.0
	draw_rect(Rect2(x0, y, x1 - x0 + 1.0, 1), scarf_color)
	# nó do cachecol na frente
	draw_rect(Rect2(x1, y + 1, 1, 1), Color(scarf_color.r * 0.75, scarf_color.g * 0.75, scarf_color.b * 0.75))


func _draw_cheeks() -> void:
	if expression == "dead" or anim == "dead":
		return
	var cheeks: Array = frame_meta().get("cheeks", [])
	var c := BLUSH
	if expression == "happy":
		c = Color(1.0, 0.45, 0.55)
	for p in cheeks:
		draw_rect(Rect2(float(p[0]) - 8.0, float(p[1]) - 16.0, 1, 1), c)


func _draw_eyes() -> void:
	var m := frame_meta()
	var ex := float(m["eye"][0]) - 8.0
	var ey := float(m["eye"][1]) - 16.0
	var e := expression
	if _blinking > 0.0 and e in ["normal", "angry", "look_up", "look_down", "wide"]:
		e = "blink"
	match e:
		"blink", "closed", "tired":
			draw_rect(Rect2(ex, ey + 1, 1, 1), EYE)
			draw_rect(Rect2(ex + 3, ey + 1, 1, 1), EYE)
			if e == "tired":
				draw_rect(Rect2(ex - 1, ey + 1, 1, 1), EYE)
				draw_rect(Rect2(ex + 2, ey + 1, 1, 1), EYE)
		"happy":
			# olhinhos em arco (^ ^) e boquinha
			draw_rect(Rect2(ex, ey, 1, 1), EYE)
			draw_rect(Rect2(ex + 3, ey, 1, 1), EYE)
			draw_rect(Rect2(ex - 1, ey + 1, 1, 1), EYE)
			draw_rect(Rect2(ex + 4, ey + 1, 1, 1), EYE)
			draw_rect(Rect2(ex + 1, ey + 2, 2, 1), MOUTH)
		"wide":
			draw_rect(Rect2(ex, ey - 1, 1, 3), EYE)
			draw_rect(Rect2(ex + 3, ey - 1, 1, 3), EYE)
			draw_rect(Rect2(ex + 2, ey + 2, 1, 1), MOUTH)
		"angry":
			draw_rect(Rect2(ex, ey, 1, 2), EYE)
			draw_rect(Rect2(ex + 3, ey, 1, 2), EYE)
			draw_rect(Rect2(ex + 1, ey - 1, 2, 1), EYE)
		"look_up":
			draw_rect(Rect2(ex, ey - 1, 1, 2), EYE)
			draw_rect(Rect2(ex + 3, ey - 1, 1, 2), EYE)
		"look_down":
			draw_rect(Rect2(ex, ey + 1, 1, 2), EYE)
			draw_rect(Rect2(ex + 3, ey + 1, 1, 2), EYE)
		"dead":
			draw_rect(Rect2(ex - 1, ey, 1, 1), EYE)
			draw_rect(Rect2(ex + 1, ey + 1, 1, 1), EYE)
			draw_rect(Rect2(ex + 2, ey, 1, 1), EYE)
			draw_rect(Rect2(ex + 4, ey + 1, 1, 1), EYE)
		_:
			draw_rect(Rect2(ex, ey, 1, 2), EYE)
			draw_rect(Rect2(ex + 3, ey, 1, 2), EYE)


func _draw_blade() -> void:
	var m := frame_meta()
	var hand := Vector2(float(m["hand"][0]) - 8.0, float(m["hand"][1]) - 16.0)
	var d: Vector2 = blade.get("dir", Vector2.RIGHT)
	var l: float = blade.get("len", 7.0)
	var c: Color = blade.get("color", Color(0.9, 0.92, 1.0))
	var tip := (hand + d * l).round()
	draw_line(hand, tip, c, 1.0)
	draw_rect(Rect2(hand.round() - d.round() * 1.0, Vector2(1, 1)), Color(0.45, 0.32, 0.22))
