class_name RiftPortal
extends Interactable
## Fenda para um mundo paralelo (exige a Chave Dimensional).

var target_region: String = ""
var _t: float = 0.0


func _ready() -> void:
	size = Vector2(30, 48)
	super._ready()
	var dim_id: String = Game.world.get("regions", {}).get(target_region, {}).get("dimension", "umbra")
	prompt = "Atravessar: " + str(DB.dimension(dim_id).get("name", "?"))
	var l := LightUtil.make_light(Color(0.8, 0.4, 1.0), 1.2, 0.8)
	if l:
		l.position = Vector2(0, -26)
		add_child(l)


func interact(_player: Node) -> void:
	if not Game.has_ability("dimension_shift"):
		FX.text(global_position + Vector2(0, -60), "A fenda está selada", Color(1.6, 1.0, 2.0))
		return
	if target_region != "" and Game.world.get("regions", {}).has(target_region):
		Audio.play("spell_heavy")
		FX.flash(1.0)
		Game.enter_region(target_region)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	for i in 5:
		var k := float(i) / 5.0
		var r := Vector2(10.0 + 4.0 * sin(_t * 3.0 + i), 22.0 + 3.0 * cos(_t * 2.0 + i)) * (1.0 - k * 0.6)
		var pts := PackedVector2Array()
		for a in 24:
			var ang := a / 24.0 * TAU + _t * (1.0 + k)
			pts.append(Vector2(cos(ang) * r.x, sin(ang) * r.y - 26))
		pts.append(pts[0])
		draw_polyline(pts, Color(1.2 + k, 0.4, 2.4 + k, 0.8 - k * 0.5), 1.5)
	draw_circle(Vector2(0, -26), 4.0, Color(0.02, 0.0, 0.05))
