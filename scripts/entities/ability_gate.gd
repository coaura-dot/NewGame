class_name AbilityGate
extends StaticBody2D
## Barreira de sala selada: por chave (consome) ou por habilidade (metroidvania).

const FONT := preload("res://assets/fonts/kenney_mini.ttf")

var requires_item: String = ""
var requires_ability: String = ""
var opened: bool = false
var _t: float = 0.0
var _shape: CollisionShape2D
var _near: float = 0.0


func _ready() -> void:
	collision_layer = Layers.WORLD
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, 32)
	_shape.shape = r
	_shape.position = Vector2(4, 16)
	add_child(_shape)
	z_index = 3


func _physics_process(delta: float) -> void:
	_t += delta
	if opened:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var close: bool = p.global_position.distance_to(global_position + Vector2(4, 24)) < 20.0
	_near = move_toward(_near, 1.0 if close else 0.0, delta * 5.0)
	if close:
		if requires_ability != "" and Game.has_ability(requires_ability):
			_open()
		elif requires_item != "" and int(Game.profile.get("items", {}).get(requires_item, 0)) > 0:
			Inventory.use_item(Game.profile, requires_item)
			_open()
	queue_redraw()


func _open() -> void:
	opened = true
	_shape.set_deferred("disabled", true)
	FX.burst(global_position + Vector2(4, 16), Color(1.4, 1.0, 2.6), 14, 180.0)
	Audio.play("door")
	Events.toast.emit("Passagem aberta")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)


func _draw() -> void:
	var c := Color(1.4, 0.8, 2.6, 0.6 + 0.2 * sin(_t * 4.0)) if requires_ability != "" else Color(2.2, 1.6, 0.6, 0.8)
	draw_rect(Rect2(1, 0, 6, 32), Color(c.r * 0.25, c.g * 0.25, c.b * 0.3, 0.8))
	for i in 4:
		var y := roundf(fmod(_t * 12.0 + i * 8.0, 32.0))
		draw_rect(Rect2(1, y, 6, 1), c)
	if _near > 0.01:
		var label := ""
		if requires_ability != "":
			label = "Requer: " + str(DB.abilities.get(requires_ability, {}).get("name", requires_ability))
		else:
			label = "Requer: " + DB.display_name(requires_item)
		var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(FONT, Vector2(roundf(4 - w * 0.5), -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 0.8, _near))
