class_name NPCEntity
extends Interactable
## NPC de hub. Visual placeholder: o herói recolorido pela cultura/papel.

const FRAMES := preload("res://assets/art/characters/hero/hero_frames.tres")
const ROLE_TINT := {
	"ferreira": Color(1.3, 0.8, 0.6), "mercador": Color(1.2, 1.1, 0.6), "curandeira": Color(0.8, 1.3, 0.9),
	"sabio": Color(0.8, 0.8, 1.4), "capita": Color(1.1, 1.1, 1.2), "receptador": Color(0.6, 0.6, 0.7),
	"bardo": Color(1.3, 0.8, 1.2), "anciao": Color(1.0, 1.0, 0.9), "crianca": Color(1.2, 1.2, 1.0),
}

var npc_id: String = ""
var npc: Dictionary = {}
var _spr: AnimatedSprite2D


func _ready() -> void:
	size = Vector2(26, 40)
	npc = Game.social.get("npcs", {}).get(npc_id, {})
	prompt = "Conversar" if not npc.is_empty() else ""
	super._ready()
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = FRAMES
	_spr.play("idle")
	_spr.offset = Vector2(0, -25)
	_spr.modulate = ROLE_TINT.get(npc.get("role", ""), Color.WHITE)
	_spr.flip_h = randf() < 0.5
	_spr.speed_scale = 0.6
	add_child(_spr)


func can_interact() -> bool:
	return not npc.is_empty() and npc.get("alive", true)


func interact(_player: Node) -> void:
	Events.dialogue_requested.emit(npc_id)


func _draw() -> void:
	super._draw()
	if npc.is_empty():
		return
	var label := "%s — %s" % [npc.get("name", "?"), npc.get("title", "")]
	var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var a := 0.4 + 0.6 * _prompt_a
	draw_string_outline(FONT, Vector2(-w * 0.5, -46), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, a))
	draw_string(FONT, Vector2(-w * 0.5, -46), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.9, 0.7, a))
	var hearts := SocialSystem.hearts(int(npc.get("affinity", 0)))
	for i in 10:
		var c := Color(2.4, 0.5, 0.7, a) if i < hearts else Color(0.3, 0.25, 0.3, a * 0.7)
		draw_rect(Rect2(-20 + i * 4, -42, 3, 3), c)
