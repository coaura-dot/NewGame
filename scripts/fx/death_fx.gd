class_name DeathFX
extends Node2D
## Morte estilo Katana Zero: a criatura é CORTADA em duas metades ao longo do
## golpe. As metades voam, giram, quicam no chão e somem; alguns pedacinhos
## de "tinta" (cor do corpo) espirram e um respingo fica na parede de trás.
## Visual limpo: poucas peças, cores chapadas, nada de sangue realista.

const GRAVITY := 620.0
const MAX_SPLATS := 48

static var _splats: Array = []


## `sprite` = CreatureSprite do inimigo (copiamos o spec), `dir` = direção do
## golpe que matou, `weight` 0..1 (força do golpe).
static func spawn(parent: Node, sprite: CreatureSprite, dir: Vector2, weight: float) -> void:
	if parent == null or sprite == null or not is_instance_valid(sprite):
		return
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	var spec: Dictionary = sprite.spec
	var body_c := _color(spec.get("color"), Color(0.4, 0.3, 0.5))
	var shell_c := _color(spec.get("shell"), Color(0.9, 0.9, 0.85))
	var origin := sprite.global_position
	var center := origin + Vector2(0, -6)
	var speed := 90.0 + weight * 110.0
	# linha do corte = direção do golpe (corte lateral separa cima/baixo)
	var cut := d.angle() + randf_range(-0.25, 0.25)
	for side in [-1, 1]:
		var h := Half.new()
		h.global_position = origin
		h.cut_angle = cut
		h.side = side
		var n: Vector2 = Vector2.from_angle(cut + PI * 0.5) * float(side)
		h.velocity = d * speed * (1.0 if side < 0 else 0.55) + n * 55.0 + Vector2(0, -70.0 if side < 0 else -20.0)
		h.spin = randf_range(4.0, 9.0) * (1.0 if d.x >= 0.0 else -1.0) * (1.0 if side < 0 else 0.4)
		var cs := CreatureSprite.new()
		cs.spec = spec
		cs.flip_h = sprite.flip_h
		cs.flash = 1.0
		h.add_child(cs)
		cs.play("hurt")
		parent.add_child(h)
	# pedacinhos
	var bits := Bits.new()
	bits.global_position = center
	bits.setup(d, [body_c, shell_c, body_c.lightened(0.2)], 6 + int(weight * 5.0), speed * 1.3)
	parent.add_child(bits)
	# respingo na parede de trás
	var sp := Splat.new()
	sp.global_position = center + d * 6.0
	sp.setup(d, body_c.darkened(0.25), 1.0 + weight * 0.6)
	parent.add_child(sp)
	_splats.append(sp)
	while _splats.size() > MAX_SPLATS:
		var old = _splats.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func _color(a: Variant, fallback: Color) -> Color:
	if a is Array and a.size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback


static func _floor_y(node: Node2D, from: Vector2, to: Vector2) -> Variant:
	var space := node.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, Layers.WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit


## Uma metade do corpo: nó que desenha a máscara (semiplano) e recorta o
## CreatureSprite filho (clip_children).
class Half extends Node2D:
	var cut_angle: float = 0.0
	var side: int = 1
	var velocity: Vector2 = Vector2.ZERO
	var spin: float = 0.0
	var life: float = 1.6
	var resting: bool = false

	func _ready() -> void:
		z_index = 6
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY

	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		if life < 0.4:
			modulate.a = life / 0.4
		for c in get_children():
			if c is CreatureSprite:
				c.flash = maxf(c.flash - delta * 5.0, 0.0)
		if resting:
			return
		velocity.y += DeathFX.GRAVITY * delta
		var step := velocity * delta
		var hit = DeathFX._floor_y(self, global_position + Vector2(0, -4), global_position + step + Vector2(0, 1))
		if hit != null:
			var nrm: Vector2 = hit["normal"]
			global_position = Vector2(hit["position"]) - Vector2(0, 1) if nrm.y < -0.5 else global_position
			velocity = velocity.bounce(nrm) * 0.35
			spin *= 0.5
			if velocity.length() < 30.0 and nrm.y < -0.5:
				resting = true
				rotation = snappedf(rotation, PI * 0.5)
			return
		global_position += step
		rotation += spin * delta

	func _draw() -> void:
		# semiplano do lado `side` da linha de corte (que passa no centro do corpo)
		var c := Vector2(0, -6)
		var u := Vector2.from_angle(cut_angle)
		var n := Vector2(-u.y, u.x) * side
		draw_colored_polygon(PackedVector2Array([c - u * 40.0, c + u * 40.0, c + u * 40.0 + n * 40.0, c - u * 40.0 + n * 40.0]), Color.WHITE)


## Pedacinhos quadrados que espirram na direção do golpe e quicam.
class Bits extends Node2D:
	var _p: Array = [] ## [pos, vel, cor, tamanho, vida]

	func setup(d: Vector2, colors: Array, n: int, speed: float) -> void:
		for i in n:
			var a := d.angle() + randf_range(-0.7, 0.7)
			var v := Vector2.from_angle(a) * speed * randf_range(0.4, 1.1) + Vector2(0, -60)
			_p.append([Vector2.ZERO, v, colors[i % colors.size()], float([1, 1, 2][i % 3]), randf_range(0.5, 0.9)])

	func _ready() -> void:
		z_index = 7

	func _physics_process(delta: float) -> void:
		var alive := false
		for p in _p:
			if p[4] <= 0.0:
				continue
			alive = true
			p[4] -= delta
			p[1].y += DeathFX.GRAVITY * delta
			p[1] *= 1.0 - 1.5 * delta
			p[0] += p[1] * delta
		queue_redraw()
		if not alive:
			queue_free()

	func _draw() -> void:
		for p in _p:
			if p[4] > 0.0:
				var c: Color = p[2]
				c.a = clampf(p[4] * 3.0, 0.0, 1.0)
				draw_rect(Rect2(p[0].round(), Vector2(p[3], p[3])), c)


## Respingo chapado na parede de trás (fica um tempo e some devagar).
class Splat extends Node2D:
	var _blobs: Array = [] ## [pos, raio]
	var _color: Color = Color.BLACK
	var _life: float = 25.0

	func setup(d: Vector2, c: Color, size: float) -> void:
		_color = Color(c.r, c.g, c.b, 0.85)
		_blobs.append([Vector2.ZERO, 3.0 * size])
		for i in 7:
			var t := randf_range(0.2, 1.0)
			var p := d * t * 18.0 * size + Vector2(randf_range(-3, 3), randf_range(-3, 3))
			_blobs.append([p, maxf(1.0, (1.0 - t) * 3.0 * size + randf_range(0.0, 1.0))])
		for i in 4:
			_blobs.append([d.rotated(randf_range(-1.2, 1.2)) * randf_range(4.0, 12.0) * size, 1.0])

	func _ready() -> void:
		z_index = -10

	func _process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
		elif _life < 3.0:
			modulate.a = _life / 3.0

	func _draw() -> void:
		for b in _blobs:
			var r: float = b[1]
			var p: Vector2 = Vector2(b[0]).round()
			if r <= 1.2:
				draw_rect(Rect2(p, Vector2.ONE), _color)
			else:
				draw_circle(p, r, _color)
