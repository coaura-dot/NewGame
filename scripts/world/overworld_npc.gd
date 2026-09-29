class_name OverworldNPC
extends Node2D
## Morador da vila no mapa-múndi: passeia entre pontos da praça, para para
## olhar o Pavio quando ele chega perto e fala com balõezinhos.

var npc_id: String = ""
var npc: Dictionary = {}
var spots: Array = [] ## Vector2 (pés)
var emote: EmoteBubble
var _tex: Texture2D
var _target: Vector2
var _wait: float = 0.0
var _t: float = 0.0
var _face: int = 1
var _blink: float = 0.0
var _greeted: bool = false
var _moving: bool = false


func _ready() -> void:
	npc = Game.social.get("npcs", {}).get(npc_id, {})
	_tex = SpriteLib.npc_texture(str(npc.get("culture", "humano")))
	_target = position
	_wait = randf_range(0.5, 3.0)
	_t = randf() * 3.0
	emote = EmoteBubble.new()
	emote.height = 16.0
	add_child(emote)


func greet(_hero: Node) -> void:
	var aff := int(npc.get("affinity", 0))
	emote.show_emote("heart" if aff >= 60 else "note", 1.0)


func _process(delta: float) -> void:
	_t += delta
	_blink -= delta
	if _blink < -3.0 - randf():
		_blink = 0.15
	var hero: Node2D = get_tree().get_first_node_in_group("ow_hero")
	var near := hero != null and hero.global_position.distance_to(global_position) < 22.0
	if near:
		_face = 1 if hero.global_position.x > global_position.x else -1
		_moving = false
		if not _greeted:
			_greeted = true
			var aff := int(npc.get("affinity", 0))
			emote.show_emote("heart" if npc.get("married", false) else ("note" if aff >= 35 else "!"), 0.9)
	else:
		_greeted = false if hero and hero.global_position.distance_to(global_position) > 60.0 else _greeted
		if _wait > 0.0:
			_wait -= delta
			_moving = false
			if _wait <= 0.0 and not spots.is_empty():
				_target = spots[randi() % spots.size()] + Vector2(randf_range(-6, 6), randf_range(-4, 4))
		else:
			var to := _target - position
			if to.length() < 1.0:
				_wait = randf_range(1.5, 5.0)
			else:
				_moving = true
				position += to.normalized() * minf(18.0 * delta, to.length())
				if absf(to.x) > 0.5:
					_face = int(signf(to.x))
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var frame := 2 if _blink > 0.0 else (int(_t * (6.0 if _moving else 1.6)) % 2)
	var region := SpriteLib.npc_region(str(npc.get("role", "anciao")), frame)
	# sombrinha no chão
	draw_rect(Rect2(-4, -1, 8, 2), Color(0, 0, 0, 0.18))
	var bob := -1.0 if _moving and int(_t * 6.0) % 2 == 0 else 0.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(_face, 1))
	draw_texture_rect_region(_tex, Rect2(-8, -16, 16, 16), region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
