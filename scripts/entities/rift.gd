class_name RiftPortal
extends Interactable
## Fenda para um mundo paralelo (exige a Chave Dimensional).

var target_region: String = ""
var _t: float = 0.0


func _ready() -> void:
	size = Vector2(14, 22)
	super._ready()
	var dim_id: String = Game.world.get("regions", {}).get(target_region, {}).get("dimension", "umbra")
	prompt = "Atravessar: " + str(DB.dimension(dim_id).get("name", "?"))
	var g := LightUtil.make_glow(Color(1.0, 0.4, 1.6, 0.5), 14.0)
	g.position = Vector2(0, -11)
	add_child(g)


func interact(player: Node) -> void:
	if not Game.has_ability("dimension_shift"):
		player.emote.show_emote("?", 0.8)
		Events.toast.emit("A fenda está selada (precisa da Chave Dimensional)")
		return
	if target_region != "" and Game.world.get("regions", {}).has(target_region):
		Audio.play("spell_heavy")
		FX.white_flash(0.5)
		Game.enter_region(target_region)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	for i in 3:
		var k := float(i) / 3.0
		var r := Vector2(5.0 + 1.5 * sin(_t * 3.0 + i), 10.0 + 1.0 * cos(_t * 2.0 + i)) * (1.0 - k * 0.5)
		var pts := PackedVector2Array()
		for a in 16:
			var ang := a / 16.0 * TAU + _t * (1.0 + k)
			pts.append((Vector2(cos(ang) * r.x, sin(ang) * r.y - 11)).round())
		pts.append(pts[0])
		draw_polyline(pts, Color(1.2 + k, 0.4, 2.2 + k, 0.9 - k * 0.4), 1.0)
	draw_rect(Rect2(-1, -12, 2, 2), Color(0.05, 0.0, 0.08))
