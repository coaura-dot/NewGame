class_name DecorSprite
extends RefCounted
## Desenha um sprite de cenografia (assets/art/decor, data/decor.json) em
## qualquer CanvasItem, com os pés em `pos` e escala da arte (1/ART).
## O brilho é desenhado por cima (cor HDR) — para bloom, sem material ADD.


static func draw(ci: CanvasItem, id: String, pos: Vector2, flip: bool, mod: Color = Color.WHITE) -> void:
	var t := DecorLayer.tex(id)
	if t == null:
		return
	var info: Dictionary = DecorLayer.meta().get(id, {})
	var o: Array = info.get("origin", [t.get_width() / 2, t.get_height()])
	var k := LevelConst.ART_SCALE
	ci.draw_set_transform(pos, 0.0, Vector2(-k if flip else k, k))
	ci.draw_texture(t, -Vector2(float(o[0]), float(o[1])), mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_glow(ci: CanvasItem, id: String, pos: Vector2, flip: bool, strength: float = 1.0) -> void:
	var g := DecorLayer.tex(id + "_glow")
	if g == null:
		return
	var info: Dictionary = DecorLayer.meta().get(id, {})
	var t := DecorLayer.tex(id)
	var o: Array = info.get("origin", [t.get_width() / 2 if t else 0, t.get_height() if t else 0])
	var k := LevelConst.ART_SCALE
	ci.draw_set_transform(pos, 0.0, Vector2(-k if flip else k, k))
	ci.draw_texture(g, -Vector2(float(o[0]), float(o[1])), Color(strength, strength, strength, 1.0))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Nó filho que desenha brilho SEM ser escurecido pelo ambiente
## (CanvasModulate) nem pelas luzes, somando a cor (ADD) para o bloom.
static func glow_node(parent: Node2D, cb: Callable) -> Node2D:
	var n := Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	n.material = mat
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.draw.connect(func(): cb.call(n))
	parent.add_child(n)
	return n
