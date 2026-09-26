class_name AmbientParticles
extends Node2D
## Clima/atmosfera por bioma — discreto (tela limpa): poucos pontinhos de
## 1 px. Vaga-lumes e brasas brilham (cor HDR => bloom). Desligável em
## Opções > Vídeo > Partículas de ambiente.

const STYLES := {
	"fireflies": {"count": 10, "color": Color(1.5, 1.8, 0.7), "vel": Vector2(0, -2), "wander": 6.0, "blink": true},
	"dust": {"count": 12, "color": Color(1.0, 0.95, 0.9, 0.35), "vel": Vector2(2, 1), "wander": 3.0},
	"rain": {"count": 40, "color": Color(0.75, 0.82, 1.0, 0.4), "vel": Vector2(-30, 200), "streak": true},
	"embers": {"count": 12, "color": Color(1.8, 0.9, 0.35), "vel": Vector2(3, -14), "wander": 8.0, "blink": true},
	"spores": {"count": 12, "color": Color(0.8, 1.2, 0.7, 0.7), "vel": Vector2(1, -3), "wander": 5.0},
	"sand": {"count": 26, "color": Color(1.0, 0.9, 0.7, 0.45), "vel": Vector2(80, 5), "wander": 10.0},
	"clouds": {"count": 8, "color": Color(1.0, 1.0, 1.0, 0.3), "vel": Vector2(6, 0), "wander": 2.0},
	"arcane": {"count": 10, "color": Color(1.4, 0.9, 2.0), "vel": Vector2(0, -5), "wander": 7.0, "blink": true},
}
const W := 340.0
const H := 200.0

var style: Dictionary = {}
var _p: Array = [] ## [pos, phase]
var _t: float = 0.0


func setup(style_name: String) -> void:
	style = STYLES.get(style_name, STYLES["dust"])
	var q: int = int(Settings.video("particles"))
	var n := int(style["count"] * [0.5, 1.0, 1.6][clampi(q, 0, 2)])
	for i in n:
		_p.append([Vector2(randf() * W, randf() * H), randf() * TAU])
	z_index = 40
	top_level = true


func _process(delta: float) -> void:
	_t += delta
	var vel: Vector2 = style.get("vel", Vector2.ZERO)
	var wander: float = style.get("wander", 0.0)
	for p in _p:
		p[0] += (vel + Vector2(sin(_t * 0.7 + p[1]), cos(_t * 0.9 + p[1] * 1.3)) * wander) * delta
		p[0].x = fposmod(p[0].x, W)
		p[0].y = fposmod(p[0].y, H)
	if PixelView.current:
		global_position = PixelView.current.view_origin() - Vector2(10, 10)
	queue_redraw()


func _draw() -> void:
	var c: Color = style.get("color", Color.WHITE)
	var origin := global_position
	for p in _p:
		# parallax leve: as partículas "flutuam" um pouco atrás da câmera
		var pos: Vector2 = Vector2(fposmod(p[0].x - origin.x * 0.2, W), fposmod(p[0].y - origin.y * 0.2, H)).floor()
		var a := c.a
		if style.get("blink", false):
			a *= 0.3 + 0.7 * (0.5 + 0.5 * sin(_t * 3.0 + p[1] * 5.0))
		if style.get("streak", false):
			draw_line(pos, pos + Vector2(-1, 4), Color(c.r, c.g, c.b, a), 1.0)
		else:
			draw_rect(Rect2(pos, Vector2.ONE), Color(c.r, c.g, c.b, a))
