class_name MemoryWisp
extends Area2D
## Lembrança da Veladora: uma luz branca-dourada que flutua onde uma sala
## sombria foi iluminada por inteiro. Encostar guarda a próxima lembrança
## (Lore.MEMORIES, em ordem) e mostra o texto. Depois de todas, vira brasas.

const CORE := Color(3.0, 2.7, 2.0)
const WARM := Color(2.2, 1.5, 0.7)
const BRASAS_WHEN_DONE := 15

var level: Node = null
var _t: float = 0.0
var _taken: bool = false
var _glow: Sprite2D
var _light: PointLight2D
var _base: Vector2


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true


func _ready() -> void:
	z_index = 12
	_base = position
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 8.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	_glow = LightUtil.make_glow(Color(1.0, 0.85, 0.6, 0.55), 16.0)
	add_child(_glow)
	_light = LightUtil.make_light(Color(1.0, 0.9, 0.7), 0.8, 1.0)
	if _light:
		add_child(_light)
	FX.ring(global_position, WARM, 26.0, 0.5)
	FX.burst(global_position, CORE, 12, 50.0)


func _on_body(b: Node) -> void:
	if _taken or not (b is Player):
		return
	_taken = true
	var i := Lore.next_memory(Game.profile)
	Audio.play("room_lit", 0.0, -2.0, 1.25)
	FX.burst(global_position, CORE, 18, 90.0)
	FX.ring(global_position, WARM, 34.0, 0.5)
	FX.hitstop(0.05)
	if b.emote:
		b.emote.show_emote("heart", 1.2)
	if i < 0:
		Game.profile["currency"] = int(Game.profile.get("currency", 0)) + BRASAS_WHEN_DONE
		Events.toast.emit("Um calor conhecido... (+%d brasas)" % BRASAS_WHEN_DONE)
	else:
		var seen: Array = Game.profile.get("memories", [])
		seen.append(i)
		Game.profile["memories"] = seen
		if level and level.hud and level.hud.has_method("open_text"):
			level.hud.open_text(Lore.memory_title(i), str(Lore.MEMORIES[i][1]))
		else:
			Events.toast.emit(Lore.memory_title(i))
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	position = _base + Vector2(sin(_t * 1.3) * 3.0, sin(_t * 2.1) * 2.5)
	if _glow:
		_glow.modulate.a = 0.45 + 0.15 * sin(_t * 4.0)
	queue_redraw()


func _draw() -> void:
	# núcleo de 3x3 + faíscas girando em volta
	draw_rect(Rect2(-1, -1, 3, 3), WARM)
	draw_rect(Rect2(0, -2, 1, 5), CORE)
	draw_rect(Rect2(-2, 0, 5, 1), CORE)
	for k in 4:
		var a := _t * 2.2 + k * TAU / 4.0
		var p := Vector2(cos(a) * 6.0, sin(a) * 4.0).round()
		draw_rect(Rect2(p, Vector2.ONE), Color(WARM.r, WARM.g, WARM.b, 0.6 + 0.4 * sin(_t * 5.0 + k)))
