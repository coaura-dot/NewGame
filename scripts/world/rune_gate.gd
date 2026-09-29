class_name RuneGate
extends Node2D
## Portão rúnico numa estrada do mapa-múndi: só abre com a habilidade do
## chefe que guarda a próxima faixa do mundo. Fechado bloqueia a passagem e a
## runa pulsa na cor da habilidade; aberto vira escombros de lado.

var requires: String = ""
var color: Color = Color(2, 2, 2.4)
var open: bool = false
var sprite: Sprite2D
var cells: Array = [] ## células (Vector2i) bloqueadas enquanto fechado
var _t: float = 0.0


func _ready() -> void:
	if sprite:
		add_child(sprite)
		sprite.position = Vector2(0, 8)
		if open:
			sprite.modulate = Color(0.6, 0.6, 0.65, 0.55)
			sprite.scale = Vector2(1.0, 0.45)
	if not open:
		var body := StaticBody2D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		body.top_level = true
		for c in cells:
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(8, 8)
			cs.shape = r
			cs.position = Vector2(c.x * 8 + 4, c.y * 8 + 4)
			body.add_child(cs)
		add_child(body)
		body.global_position = Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if open:
		return
	var a := 0.6 + 0.4 * sin(_t * 3.0)
	var c := Color(color.r, color.g, color.b, a)
	# runa (losango com traço) no buraco do portão
	draw_rect(Rect2(-1, -4, 3, 1), c)
	draw_rect(Rect2(-2, -3, 5, 1), c)
	draw_rect(Rect2(-1, -2, 3, 1), c)
	draw_rect(Rect2(0, -6, 1, 7), Color(c.r, c.g, c.b, a * 0.8))
