class_name Pickup
extends Area2D
## Item/brasas soltos no mundo. Coletado ao encostar.

const FONT := preload("res://assets/fonts/kenney_pixel.ttf")

var item_id: String = ""
var currency: int = 0
var velocity: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _grounded: bool = false
var _icon: Texture2D


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	z_index = 20
	if item_id != "":
		_icon = DB.icon(item_id)
		var rar: String = DB.get_entry(item_id).get("rarity", "common")
		var col := DB.rarity_color(rar)
		var l := LightUtil.make_light(col, 0.6, 0.3)
		if l:
			add_child(l)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _grounded:
		velocity.y += 700.0 * delta
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + velocity * delta + Vector2(0, 8), Layers.WORLD | Layers.ONE_WAY)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and velocity.y > 0.0:
			global_position = hit["position"] - Vector2(0, 8)
			_grounded = true
		else:
			global_position += velocity * delta
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
	queue_redraw()


func _on_body(b: Node) -> void:
	if not (b is Player) or _t < 0.3:
		return
	if currency > 0:
		Game.profile["currency"] = int(Game.profile.get("currency", 0)) + currency
		Events.currency_changed.emit(Game.profile["currency"])
		Audio.play("coins", 0.1, -6.0)
	if item_id != "":
		var msg := Inventory.add(Game.profile, item_id)
		Events.item_picked.emit(item_id, DB.kind_of(item_id))
		Events.toast.emit(msg)
		Audio.play("pickup")
		if b.has_method("apply_profile") and DB.kind_of(item_id) in ["buff"]:
			b.buffs.set_buffs(Game.profile["buffs"])
		FX.burst(global_position, DB.rarity_color(DB.get_entry(item_id).get("rarity", "common")) * 2.0, 14, 120.0)
	queue_free()


func _draw() -> void:
	var bob := sin(_t * 4.0) * 2.0
	if currency > 0:
		var r := 3.0 + minf(currency / 10.0, 3.0)
		draw_circle(Vector2(0, bob), r + 2.0, Color(2.0, 1.2, 0.3, 0.3))
		draw_circle(Vector2(0, bob), r, Color(2.4, 1.6, 0.4))
		return
	if _icon:
		var rar: String = DB.get_entry(item_id).get("rarity", "common")
		var col := DB.rarity_color(rar)
		draw_circle(Vector2(0, bob), 11.0, Color(col.r, col.g, col.b, 0.18 + 0.08 * sin(_t * 3.0)))
		draw_texture(_icon, Vector2(-8, -8 + bob))
