class_name HeroRig
extends Node2D
## Desenha o herói: quadro do corpo (assets/art/hero/hero.png, gerado por
## tools/pixel_art.py) + OLHOS procedurais (expressões) + lâmina durante os
## golpes + squash & stretch. A origem é o meio dos pés.

const TEX := preload("res://assets/art/hero/hero.png")
const META_PATH := "res://assets/art/hero/hero.json"
const EYE := Color(0.106, 0.082, 0.157)
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
var mat: ShaderMaterial
var _blink_t: float = 2.0
var _blinking: float = 0.0


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
	_draw_eyes()
	if not blade.is_empty():
		_draw_blade()


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
			draw_rect(Rect2(ex, ey, 1, 1), EYE)
			draw_rect(Rect2(ex + 3, ey, 1, 1), EYE)
			draw_rect(Rect2(ex - 1, ey + 1, 1, 1), EYE)
			draw_rect(Rect2(ex + 4, ey + 1, 1, 1), EYE)
		"wide":
			draw_rect(Rect2(ex, ey - 1, 1, 3), EYE)
			draw_rect(Rect2(ex + 3, ey - 1, 1, 3), EYE)
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
