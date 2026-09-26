class_name LightningFX
extends Node2D
## Raio/feixe desenhado (zigue-zague para raios, reto para feixes de luz).

var from: Vector2
var to: Vector2
var color: Color = Color(2.4, 2.6, 4.0)
var width: float = 2.0
var jagged: bool = true
var duration: float = 0.22
var _t: float = 0.0
var _points: PackedVector2Array


static func spawn(parent: Node, a: Vector2, b: Vector2, c: Color = Color(2.4, 2.6, 4.0), w: float = 2.0, zig: bool = true) -> LightningFX:
	var fx := LightningFX.new()
	fx.from = a
	fx.to = b
	fx.color = c
	fx.width = w
	fx.jagged = zig
	if parent:
		parent.add_child(fx)
	return fx


func _ready() -> void:
	z_index = 35
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rebuild()


func _rebuild() -> void:
	_points = PackedVector2Array()
	var seg := maxi(2, int(from.distance_to(to) / 12.0))
	var n := (to - from).orthogonal().normalized()
	for i in seg + 1:
		var f := float(i) / seg
		var p := from.lerp(to, f)
		if jagged and i > 0 and i < seg:
			p += n * randf_range(-7.0, 7.0)
		_points.append(p)


func _process(delta: float) -> void:
	_t += delta
	if jagged and fmod(_t, 0.05) < delta:
		_rebuild()
	queue_redraw()
	if _t >= duration:
		queue_free()


func _draw() -> void:
	var a := 1.0 - _t / duration
	draw_polyline(_points, Color(color.r * 0.4, color.g * 0.4, color.b * 0.6, a * 0.5), width * 3.0)
	draw_polyline(_points, Color(color.r, color.g, color.b, a), width)
