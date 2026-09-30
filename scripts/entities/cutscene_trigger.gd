class_name CutsceneTrigger
extends Area2D
## Área invisível: quando o Lume entra, toca uma cena da história (uma vez,
## a menos que once = false). A cena pode ter condição em data/story.json
## ("triggers": {cena: condição}).

var scene_id: String = ""
var once: bool = true
var size: Vector2 = Vector2(24, 32)
var level: Node = null
var room_index: int = -1


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.ACTORS
	monitoring = true


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = size * 0.5
	add_child(cs)
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if not (b is Player) or level == null or level.cutscene == null:
		return
	if once and Story.has_flag("scene:" + scene_id):
		return
	var cond := str(Story.data().get("triggers", {}).get(scene_id, ""))
	if not Story.check(cond):
		return
	level.cutscene.play(scene_id)
