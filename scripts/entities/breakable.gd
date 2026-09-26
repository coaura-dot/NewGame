class_name BreakableWall
extends StaticBody2D
## Bloco rachado que esconde segredos. Quebra com golpes (ou só com Queda
## Esmagadora, se for piso rachado). O herói desconfia quando passa perto.

var hits_left: int = 3
var pound_only: bool = false
var tile_tex: Texture2D
var region: Rect2 = Rect2(40, 24, 8, 8)
var tint: Color = Color.WHITE
var team: int = Layers.Team.NEUTRAL
var dead: bool = false
var facing: int = 1
var _noticed: bool = false


func _ready() -> void:
	collision_layer = Layers.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, 8)
	cs.shape = r
	cs.position = Vector2(4, 4)
	add_child(cs)
	if pound_only:
		add_to_group("cracked_floor")
		region = Rect2(48, 24, 8, 8)
	else:
		var hb := Hurtbox.new()
		hb.actor = self
		hb.team = team
		var hs := CollisionShape2D.new()
		var hr := RectangleShape2D.new()
		hr.size = Vector2(10, 10)
		hs.shape = hr
		hs.position = Vector2(4, 4)
		hb.add_child(hs)
		add_child(hb)
	z_index = 1


func _physics_process(_delta: float) -> void:
	if _noticed:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p and p.global_position.distance_to(global_position + Vector2(4, 4)) < 22.0:
		_noticed = true
		if "emote" in p:
			p.emote.show_emote("?", 1.0)


func take_hit(info: DamageInfo) -> int:
	if dead or info.is_hazard or info.team == Layers.Team.ENEMY:
		return DamageInfo.Result.IGNORED
	hits_left -= 1
	FX.burst(global_position + Vector2(4, 4), Color(0.85, 0.8, 0.75), 4, 60.0)
	Audio.play("break", 0.1, -6.0)
	queue_redraw()
	if hits_left <= 0:
		shatter()
	return DamageInfo.Result.HIT


func shatter() -> void:
	if dead:
		return
	dead = true
	FX.burst(global_position + Vector2(4, 4), Color(0.9, 0.85, 0.8), 10, 90.0)
	FX.shake(0.12)
	Audio.play("break")
	var p := get_tree().get_first_node_in_group("player")
	if p and "emote" in p:
		p.emote.show_emote("spark", 0.8)
	queue_free()


func body_center() -> Vector2:
	return global_position + Vector2(4, 4)


func _draw() -> void:
	if tile_tex:
		draw_texture_rect_region(tile_tex, Rect2(0, 0, 8, 8), region)
	else:
		draw_rect(Rect2(0, 0, 8, 8), Color(0.3, 0.28, 0.3))
	if hits_left < 3:
		draw_line(Vector2(1, 1), Vector2(4, 5), Color(0, 0, 0, 0.7), 1.0)
		draw_line(Vector2(4, 5), Vector2(6, 3), Color(0, 0, 0, 0.7), 1.0)
