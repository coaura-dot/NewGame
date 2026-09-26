class_name AfterImage
extends Sprite2D
## Cópia fantasma do quadro atual do sprite (rastro do dash/teleporte).
## Cor HDR => brilha com bloom.

var life: float = 0.28
var _t: float = 0.0


static func from_sprite(src: Node2D, tint: Color, lifetime: float = 0.28) -> Node2D:
	if src == null or not Settings.video("afterimages"):
		return null
	if src is CreatureSprite:
		return src.ghost(tint, lifetime)
	if not (src is AnimatedSprite2D) or src.sprite_frames == null:
		return null
	var tex: Texture2D = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	if tex == null:
		return null
	var a := AfterImage.new()
	a.texture = tex
	a.global_position = src.global_position
	a.offset = src.offset
	a.flip_h = src.flip_h
	a.scale = src.global_scale
	a.modulate = tint
	a.life = lifetime
	a.z_index = src.z_index - 1
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	a.material = m
	return a


func _process(delta: float) -> void:
	_t += delta
	modulate.a = (1.0 - _t / life) * 0.7
	if _t >= life:
		queue_free()
