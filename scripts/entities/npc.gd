class_name NPCEntity
extends Interactable
## NPC de hub: criaturinha da cultura da região (povo-camundongo, javalis,
## diabretes, corujas magas, ursinhos bárbaros, passarinhos celestes) com o
## acessório do seu papel. Reage ao herói com balõezinhos de emoção.

var npc_id: String = ""
var npc: Dictionary = {}
var _tex: Texture2D
var _t: float = 0.0
var _blink: float = 0.0
var _face: int = 1
var _greeted: bool = false
var emote: EmoteBubble


func _ready() -> void:
	size = Vector2(14, 14)
	npc = Game.social.get("npcs", {}).get(npc_id, {})
	prompt = "Conversar" if not npc.is_empty() else ""
	super._ready()
	_tex = SpriteLib.npc_texture(str(npc.get("culture", "humano")))
	_t = randf() * 3.0
	_face = -1 if randf() < 0.5 else 1
	emote = EmoteBubble.new()
	emote.height = 15.0
	add_child(emote)


func can_interact() -> bool:
	return not npc.is_empty() and npc.get("alive", true)


func interact(player: Node) -> void:
	var aff := int(npc.get("affinity", 0))
	emote.show_emote("heart" if aff >= 60 else "note", 1.0)
	if player and "emote" in player:
		player.emote.show_emote("...", 0.6)
	Events.dialogue_requested.emit(npc_id)


func _on_player_near(player: Node) -> void:
	if _greeted or npc.is_empty():
		return
	_greeted = true
	var aff := int(npc.get("affinity", 0))
	if npc.get("married", false):
		emote.show_emote("heart", 1.4)
	elif aff >= 35:
		emote.show_emote("note", 1.0)
	else:
		emote.show_emote("!", 0.8)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_blink -= delta
	if _blink < -3.0 - randf():
		_blink = 0.15
	var p := get_tree().get_first_node_in_group("player")
	if p and _near:
		_face = 1 if p.global_position.x > global_position.x else -1


func _draw_body() -> void:
	if _tex == null:
		return
	var frame := 2 if _blink > 0.0 else (int(_t * 1.6) % 2)
	var region := SpriteLib.npc_region(str(npc.get("role", "anciao")), frame)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_face, 1))
	draw_texture_rect_region(_tex, Rect2(-8, -16, 16, 16), region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	_draw_body()
	if npc.is_empty() or _prompt_a <= 0.01:
		return
	var label := "%s" % npc.get("name", "?")
	var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var pos := Vector2(roundf(-w * 0.5), -27)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(FONT, pos + o, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK.r, INK.g, INK.b, _prompt_a))
	draw_string(FONT, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.9, 0.7, _prompt_a))
	var hearts := SocialSystem.hearts(int(npc.get("affinity", 0)))
	for i in 10:
		var c := Color(0.95, 0.35, 0.5, _prompt_a) if i < hearts else Color(0.3, 0.26, 0.34, _prompt_a * 0.7)
		draw_rect(Rect2(-10 + i * 2, -24, 1, 1), c)
	draw_prompt(prompt, Vector2(0, -34), _prompt_a)
