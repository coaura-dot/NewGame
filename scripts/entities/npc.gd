class_name NPCEntity
extends Interactable
## NPC de hub: criaturinha minimalista colorida pelo papel/cultura.

const ROLE_LOOK := {
	"ferreira": {"color": [0.55, 0.3, 0.2], "shell": [0.85, 0.6, 0.45], "horns": true},
	"mercador": {"color": [0.6, 0.5, 0.2], "shell": [0.95, 0.85, 0.6], "ears": true},
	"curandeira": {"color": [0.3, 0.55, 0.4], "shell": [0.9, 0.95, 0.85]},
	"sabio": {"color": [0.3, 0.3, 0.6], "shell": [0.85, 0.85, 1.0], "horns": true},
	"capita": {"color": [0.5, 0.5, 0.58], "shell": [0.9, 0.9, 0.95]},
	"receptador": {"color": [0.2, 0.2, 0.25], "shell": [0.55, 0.55, 0.6], "ears": true},
	"bardo": {"color": [0.6, 0.3, 0.55], "shell": [0.95, 0.8, 0.9]},
	"anciao": {"color": [0.45, 0.42, 0.38], "shell": [0.8, 0.78, 0.72], "horns": true},
	"crianca": {"color": [0.7, 0.55, 0.3], "shell": [1.0, 0.95, 0.8]},
}

var npc_id: String = ""
var npc: Dictionary = {}
var _spr: CreatureSprite


func _ready() -> void:
	size = Vector2(10, 12)
	npc = Game.social.get("npcs", {}).get(npc_id, {})
	prompt = "Conversar" if not npc.is_empty() else ""
	super._ready()
	var look := {"body": [5, 4], "head": [6, 5], "eyes": "hollow", "legs": 2}
	look.merge(ROLE_LOOK.get(npc.get("role", ""), {}), true)
	# arte nova: aldeão de cinza pelo ofício (tools/build_sprites.py)
	var sheet_id := "villager_" + str(npc.get("role", ""))
	if not CreatureSprite.load_sheet(sheet_id).is_empty():
		look["sprite"] = sheet_id
	_spr = CreatureSprite.new()
	_spr.spec = look
	_spr.flip_h = randf() < 0.5
	add_child(_spr)


func _on_player_near(_player: Node) -> void:
	if _spr and not npc.is_empty():
		_spr.emote("heart" if int(npc.get("affinity", 0)) >= 60 else "...", 1.2)


func can_interact() -> bool:
	return not npc.is_empty() and npc.get("alive", true)


func interact(player: Node) -> void:
	if _spr:
		_spr.flip_h = player.global_position.x < global_position.x
	Events.dialogue_requested.emit(npc_id)
