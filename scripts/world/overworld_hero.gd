class_name OverworldHero
extends CharacterBody2D
## O Pavio andando pelo mapa-múndi (visão de cima): 8 direções, correr com o
## botão de dash, quadros de frente/costas/lado e a mesma chama/olhos/gola do
## herói de plataforma (HeroRig com a folha pavio_ow). À noite a chama ilumina.

const WALK := 56.0
const RUN := 92.0
const ACCEL := 700.0
const OW_ANIMS := {
	"down": {"frames": ["down0", "down1", "down2", "down3"], "fps": 7.0},
	"up": {"frames": ["up0", "up1", "up2", "up3"], "fps": 7.0},
	"side": {"frames": ["side0", "side1", "side2", "side3"], "fps": 8.0},
	"idle_down": {"frames": ["down0"], "fps": 1.0},
	"idle_up": {"frames": ["up0"], "fps": 1.0},
	"idle_side": {"frames": ["side0"], "fps": 1.0},
}

var rig: HeroRig
var emote: EmoteBubble
var facing: int = 1
var dir_name: String = "down"
var light: PointLight2D
var _glow: Sprite2D
var _step_t: float = 0.0
var _dust_t: float = 0.0


func _ready() -> void:
	add_to_group("ow_hero")
	collision_layer = 0
	collision_mask = Layers.WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(6, 4)
	cs.shape = r
	cs.position = Vector2(0, -2)
	add_child(cs)
	rig = HeroRig.new()
	rig.tex = preload("res://assets/art/hero/pavio_ow.png")
	rig.meta_path = "res://assets/art/hero/pavio_ow.json"
	rig.anims = OW_ANIMS.duplicate(true)
	rig.anim = "idle_down"
	add_child(rig)
	emote = EmoteBubble.new()
	emote.height = 16.0
	add_child(emote)
	# brilho da chama à noite (aditivo, sempre barato)
	_glow = Sprite2D.new()
	_glow.texture = LightUtil.soft()
	_glow.scale = Vector2(0.9, 0.9)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.position = Vector2(0, -14)
	_glow.modulate = Color(1.0, 0.6, 0.25, 0.0)
	_glow.z_index = 50
	add_child(_glow)
	light = LightUtil.make_light(Color(1.0, 0.75, 0.45), 0.0, 1.1)
	if light:
		light.position = Vector2(0, -14)
		add_child(light)


func set_night(n: float) -> void:
	var c := _glow.modulate
	c.a = n * 0.55 * (0.9 + 0.1 * sin(Time.get_ticks_msec() / 70.0))
	_glow.modulate = c
	if light:
		light.energy = n * 0.9


func _physics_process(delta: float) -> void:
	var inp := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if inp.length() < 0.25:
		inp = Vector2.ZERO
	var running := Input.is_action_pressed("dash")
	var want := inp.normalized() * (RUN if running else WALK)
	velocity = velocity.move_toward(want, ACCEL * delta)
	move_and_slide()
	# direção dos quadros
	if inp != Vector2.ZERO:
		if absf(inp.x) > absf(inp.y) * 1.1:
			dir_name = "side"
			facing = int(signf(inp.x))
		else:
			dir_name = "down" if inp.y > 0.0 else "up"
	var moving := velocity.length() > 8.0
	rig.facing = facing if dir_name == "side" else 1
	rig.play(dir_name if moving else "idle_" + dir_name)
	if moving:
		rig.anims[dir_name]["fps"] = 7.0 * velocity.length() / WALK
	rig.motion = velocity * 1.4
	rig.vitality = 1.0
	# passos e poeira
	if moving:
		_step_t -= delta * velocity.length() / WALK
		if _step_t <= 0.0:
			_step_t = 0.3
			Audio.play("step", 0.15, -14.0)
		if running:
			_dust_t -= delta
			if _dust_t <= 0.0:
				_dust_t = 0.12
				FX.dust(global_position, -velocity.normalized() * 0.5 + Vector2(0, -0.4), 1)
