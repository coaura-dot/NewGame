class_name Pickup
extends Area2D
## Item/brasas soltos no mundo (ícones 9x9 por categoria e raridade).
## Coletado ao encostar — o herói comemora.

var item_id: String = ""
var currency: int = 0
var velocity: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _grounded: bool = false
var _tex: Texture2D
var _region: Rect2
var _glow: Sprite2D
var _rarity: String = "common"


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 6.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	z_index = 20
	if item_id != "":
		_tex = SpriteLib.tex("res://assets/art/items/items.png")
		_rarity = DB.get_entry(item_id).get("rarity", "common")
		var kind := DB.kind_of(item_id)
		if item_id.begins_with("chave"):
			kind = "key"
		elif item_id.begins_with("pocao"):
			kind = "potion"
		elif kind == "item":
			kind = "item"
		_region = SpriteLib.item_region(kind, _rarity)
		var col := DB.rarity_color(_rarity)
		_glow = LightUtil.make_glow(Color(col.r, col.g, col.b, 0.35), 7.0)
		add_child(_glow)


func _physics_process(delta: float) -> void:
	_t += delta
	# brasas voam até o herói quando ele passa perto (não quebra o ritmo)
	if currency > 0 and _t > 0.35:
		var p := get_tree().get_first_node_in_group("player")
		if p and not p.dead:
			var to: Vector2 = p.body_center() - global_position
			if to.length() < 44.0:
				velocity = velocity.lerp(to.normalized() * 220.0, 1.0 - exp(-delta * 10.0))
				global_position += velocity * delta
				_grounded = true
				queue_redraw()
				return
	if not _grounded:
		velocity.y += 420.0 * delta
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + velocity * delta + Vector2(0, 4), Layers.WORLD | Layers.ONE_WAY)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and velocity.y > 0.0:
			global_position = (hit["position"] - Vector2(0, 4)).round()
			_grounded = true
		else:
			global_position += velocity * delta
			velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta)
	queue_redraw()


func _on_body(b: Node) -> void:
	if not (b is Player) or _t < 0.3:
		return
	if currency > 0:
		Game.profile["currency"] = int(Game.profile.get("currency", 0)) + currency
		Events.currency_changed.emit(Game.profile["currency"])
		Audio.play("coins", 0.1, -8.0)
		FX.burst(global_position, Color(2.2, 1.6, 0.5), 3, 40.0)
	if item_id != "":
		var msg := Inventory.add(Game.profile, item_id)
		Events.item_picked.emit(item_id, DB.kind_of(item_id))
		Events.toast.emit(msg)
		Audio.play("pickup")
		if b.has_method("apply_profile") and DB.kind_of(item_id) in ["buff"]:
			b.buffs.set_buffs(Game.profile["buffs"])
		var col := DB.rarity_color(_rarity)
		FX.burst(global_position, col * 1.8, 8, 60.0)
		b.emote.show_emote("spark" if _rarity in ["epic", "legendary", "set"] else "note", 1.0)
		b.rig.set_expression("happy", 0.8)
	queue_free()


func _draw() -> void:
	var bob := roundf(sin(_t * 4.0) * 1.5)
	if currency > 0:
		var big := currency >= 8
		var ink := Color(0.106, 0.082, 0.157)
		var r := 2 if big else 1
		draw_rect(Rect2(-r - 1, bob - r - 1, r * 2 + 2, r * 2 + 2), ink)
		draw_rect(Rect2(-r, bob - r, r * 2, r * 2), Color(1.9, 1.3, 0.35))
		draw_rect(Rect2(-r, bob - r, 1, 1), Color(2.6, 2.2, 1.2))
		return
	if _tex:
		draw_texture_rect_region(_tex, Rect2(Vector2(-4, -5 + bob), Vector2(9, 9)), _region)
