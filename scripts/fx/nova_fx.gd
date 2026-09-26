class_name NovaFX
extends Node2D
## Anel que se expande (explosões, pulsos, clarões).

var radius: float = 60.0
var color: Color = Color(2, 2, 2)
var duration: float = 0.35
var _t: float = 0.0


func _ready() -> void:
	z_index = 30
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var l := LightUtil.make_light(Color(color.r, color.g, color.b).clamp(), 1.4, radius / 40.0)
	if l:
		add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "energy", 0.0, duration)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration:
		queue_free()


func _draw() -> void:
	var p := _t / duration
	var r := radius * ease(p, 0.35)
	var a := 1.0 - p
	draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.12 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color.r, color.g, color.b, a), 1.0 + (1.0 if a > 0.5 else 0.0))
