class_name BreakableWall
extends StaticBody2D
## Parede/bloco rachado que esconde segredos. Quebra com golpes (ou só com
## Queda Esmagadora, se for piso rachado).

var hits_left: int = 3
var pound_only: bool = false
var tile_tex: Texture2D
## bloco rachado do atlas de 16 px (tools/build_tiles.py, índice 59)
var region: Rect2 = Rect2(48, 112, 16, 16)
var tint: Color = Color.WHITE
var team: int = Layers.Team.NEUTRAL
var dead: bool = false
var facing: int = 1


func _ready() -> void:
	collision_layer = Layers.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, 8)
	cs.shape = r
	cs.position = Vector2(4, 4)
	add_child(cs)
	add_to_group("secrets")
	if pound_only:
		add_to_group("cracked_floor")
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


func take_hit(info: DamageInfo) -> int:
	if dead or info.is_hazard or info.team == Layers.Team.ENEMY:
		return DamageInfo.Result.IGNORED
	hits_left -= 1
	FX.burst(global_position + Vector2(4, 4), Color(0.8, 0.75, 0.7), 4, 100.0)
	Audio.play("break", 0.1, -6.0)
	if hits_left <= 0:
		shatter()
	return DamageInfo.Result.HIT


func shatter() -> void:
	if dead:
		return
	dead = true
	FX.burst(global_position + Vector2(4, 4), Color(0.9, 0.85, 0.8), 10, 180.0)
	FX.shake(0.15)
	Audio.play("break")
	queue_free()


func body_center() -> Vector2:
	return global_position + Vector2(4, 4)


func _draw() -> void:
	if tile_tex:
		draw_texture_rect_region(tile_tex, Rect2(0, 0, 8, 8), region, tint)
	else:
		draw_rect(Rect2(0, 0, 8, 8), Color(0.3, 0.28, 0.3))
	if hits_left < 3:
		# rachaduras novas a cada golpe (em meio pixel = 1 px de arte)
		var c := Color(0, 0, 0, 0.85)
		draw_rect(Rect2(3.0, 1.5, 0.5, 2.5), c)
		draw_rect(Rect2(3.5, 4.0, 0.5, 2.0), c)
		if hits_left < 2:
			draw_rect(Rect2(5.0, 3.0, 2.0, 0.5), c)
			draw_rect(Rect2(1.5, 5.5, 1.5, 0.5), c)
