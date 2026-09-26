class_name AbilityGate
extends StaticBody2D
## Barreira de sala selada: por chave (consome) ou por habilidade (metroidvania).

const FONT := preload("res://assets/fonts/kenney_mini.ttf")
const H := 32.0

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
	r.size = Vector2(8, H)
	_shape.shape = r
	_shape.position = Vector2(4, H * 0.5)
	add_child(_shape)
	z_index = 3


func _physics_process(delta: float) -> void:
	_t += delta
	if opened:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var close: bool = p.global_position.distance_to(global_position + Vector2(4, H * 0.75)) < 22.0
	if close and _near <= 0.0 and "emote" in p:
		p.emote.show_emote("?", 0.8)
	_near = move_toward(_near, 1.0 if close else 0.0, delta * 6.0)
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
	FX.burst(global_position + Vector2(4, H * 0.5), Color(1.4, 1.0, 2.4), 12, 90.0)
	Audio.play("door")
	Events.toast.emit("Passagem aberta")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)


func _draw() -> void:
	var magic := requires_ability != ""
	var c := Color(1.2, 0.8, 2.2, 0.8) if magic else Color(1.8, 1.4, 0.6, 0.9)
	draw_rect(Rect2(1, 0, 6, H), Color(c.r * 0.3, c.g * 0.3, c.b * 0.35, 0.85))
	for i in 4:
		var y := roundf(fposmod(_t * 12.0 + i * 8.0, H))
		draw_rect(Rect2(1, y, 6, 1), c)
	if not magic:
		draw_rect(Rect2(3, H * 0.5 - 2, 2, 3), Color(0.106, 0.082, 0.157))
	if _near > 0.01:
		var label := "Requer: " + (str(DB.abilities.get(requires_ability, {}).get("name", requires_ability)) if magic else DB.display_name(requires_item))
		var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var pos := Vector2(roundf(4 - w * 0.5), -4)
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(FONT, pos + o, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.106, 0.082, 0.157, _near))
		draw_string(FONT, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.95, 0.85, _near))
