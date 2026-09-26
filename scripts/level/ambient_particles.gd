class_name AmbientParticles
extends Node2D
## Clima/atmosfera por bioma: vaga-lumes, poeira, chuva, brasas, esporos,
## areia, névoa arcana. Desenhado ao redor da câmera, cores HDR (bloom).

const STYLES := {
	"fireflies": {"count": 26, "color": Color(1.6, 2.2, 0.6), "size": 1.5, "vel": Vector2(0, -4), "wander": 14.0, "blink": true},
	"dust": {"count": 40, "color": Color(0.9, 0.85, 0.8, 0.5), "size": 1.0, "vel": Vector2(4, 2), "wander": 6.0},
	"rain": {"count": 120, "color": Color(0.6, 0.7, 1.0, 0.45), "size": 1.0, "vel": Vector2(-60, 420), "streak": true},
	"embers": {"count": 36, "color": Color(2.6, 1.0, 0.3), "size": 1.2, "vel": Vector2(6, -30), "wander": 18.0, "blink": true},
	"spores": {"count": 34, "color": Color(0.9, 1.8, 0.8, 0.8), "size": 1.3, "vel": Vector2(3, -6), "wander": 10.0},
	"sand": {"count": 90, "color": Color(1.3, 1.1, 0.7, 0.5), "size": 1.0, "vel": Vector2(160, 10), "wander": 20.0},
	"clouds": {"count": 30, "color": Color(1.2, 1.3, 1.5, 0.35), "size": 2.0, "vel": Vector2(12, 0), "wander": 4.0},
	"arcane": {"count": 30, "color": Color(1.6, 0.8, 2.6), "size": 1.3, "vel": Vector2(0, -10), "wander": 16.0, "blink": true},
}

var style: Dictionary = {}
var camera: Camera2D
var _p: Array = [] ## [pos, phase]
var _t: float = 0.0


func setup(style_name: String, cam: Camera2D) -> void:
	style = STYLES.get(style_name, STYLES["dust"])
	camera = cam
	var q: int = int(Settings.video("particles"))
	var n := int(style["count"] * [0.3, 0.6, 1.0][clampi(q, 0, 2)])
	for i in n:
		_p.append([Vector2(randf() * 520.0, randf() * 310.0), randf() * TAU])
	z_index = 40
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _process(delta: float) -> void:
	_t += delta
	var vel: Vector2 = style.get("vel", Vector2.ZERO)
	var wander: float = style.get("wander", 0.0)
	for p in _p:
		p[0] += (vel + Vector2(sin(_t * 0.7 + p[1]), cos(_t * 0.9 + p[1] * 1.3)) * wander) * delta
		p[0].x = fposmod(p[0].x, 520.0)
		p[0].y = fposmod(p[0].y, 310.0)
	if camera:
		global_position = camera.get_screen_center_position() - Vector2(260, 155)
	queue_redraw()


func _draw() -> void:
	var c: Color = style.get("color", Color.WHITE)
	var s: float = style.get("size", 1.0)
	var cam_off := Vector2.ZERO
	if camera:
		cam_off = Vector2(fposmod(camera.get_screen_center_position().x * 0.3, 520.0), fposmod(camera.get_screen_center_position().y * 0.3, 310.0))
	for p in _p:
		var pos: Vector2 = Vector2(fposmod(p[0].x - cam_off.x, 520.0), fposmod(p[0].y - cam_off.y, 310.0))
		var a := c.a
		if style.get("blink", false):
			a *= 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 3.0 + p[1] * 5.0))
		if style.get("streak", false):
			draw_line(pos, pos + Vector2(-2, 8), Color(c.r, c.g, c.b, a), 1.0)
		else:
			draw_rect(Rect2(pos, Vector2(s, s)), Color(c.r, c.g, c.b, a))
