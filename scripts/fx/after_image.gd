class_name AfterImage
extends Node2D
## Cópia fantasma do quadro atual (rastro do dash/teleporte/esquiva).
## Funciona com AnimatedSprite2D, Sprite2D ou qualquer nó que tenha
## ghost_data() -> {texture, region, offset, flip_h, flip_v, scale}.
## Cor HDR => brilha com bloom.

var life: float = 0.22
var tex: Texture2D
var region: Rect2
var offset: Vector2
var flip_h: bool = false
var flip_v: bool = false
var tint: Color = Color.WHITE
var _t: float = 0.0


static func from_sprite(src: Node, tint_color: Color, lifetime: float = 0.22) -> AfterImage:
	if src == null or not is_instance_valid(src) or not Settings.video("afterimages"):
		return null
	var a := AfterImage.new()
	if src.has_method("ghost_data"):
		var g: Dictionary = src.ghost_data()
		if g.is_empty():
			return null
		a.tex = g["texture"]
		a.region = g["region"]
		a.offset = g["offset"]
		a.flip_h = g.get("flip_h", false)
		a.flip_v = g.get("flip_v", false)
		a.scale = g.get("scale", Vector2.ONE)
	elif src is AnimatedSprite2D:
		if src.sprite_frames == null:
			return null
		var t: Texture2D = src.sprite_frames.get_frame_texture(src.animation, src.frame)
		if t == null:
			return null
		a.tex = t
		a.region = Rect2(Vector2.ZERO, t.get_size())
		if t is AtlasTexture:
			a.tex = t.atlas
			a.region = t.region
		a.offset = src.offset - a.region.size * 0.5 if src.centered else src.offset
		a.flip_h = src.flip_h
		a.flip_v = src.flip_v
		a.scale = src.scale
	else:
		return null
	a.global_position = src.global_position
	a.tint = tint_color
	a.life = lifetime
	a.z_index = 4
	return a


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= life:
		queue_free()


func _draw() -> void:
	if tex == null:
		return
	var k := 1.0 - _t / life
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0))
	draw_texture_rect_region(tex, Rect2(offset, region.size), region, Color(tint.r, tint.g, tint.b, tint.a * k))
