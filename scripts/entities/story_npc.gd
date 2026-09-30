class_name StoryNPC
extends Interactable
## Personagem da HISTÓRIA (data/story.json -> characters): Vovó Borralha,
## Fuligem, Mira, Sir Gaspar... Tem nome, aparência (folha de sprites) e
## falas que mudam com o progresso (Story.next_talk). Pode só aparecer sob
## uma condição ("show_if") e oferecer serviços depois da conversa.

var npc_id: String = ""
var info: Dictionary = {}
var _spr: CreatureSprite
var _greeted: bool = false


func _ready() -> void:
	info = Story.character(npc_id)
	add_to_group("story_npcs")
	if info.is_empty() or not Story.check(str(info.get("show_if", ""))) or (str(info.get("hide_if", "")) != "" and Story.check(str(info["hide_if"]))):
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	size = Vector2(12, 14)
	prompt = str(info.get("prompt", "Conversar"))
	super._ready()
	var sheet := str(info.get("sprite", ""))
	var look := {"body": [5, 4], "head": [6, 5], "eyes": "hollow", "legs": 2}
	if sheet != "" and not CreatureSprite.load_sheet(sheet).is_empty():
		look["sprite"] = sheet
	_spr = CreatureSprite.new()
	_spr.spec = look
	_spr.flip_h = str(info.get("facing", "L")) == "L"
	add_child(_spr)
	if info.has("anim"):
		_spr.play(str(info["anim"]))


func _on_player_near(_player: Node) -> void:
	if _spr and not _greeted:
		_greeted = true
		_spr.emote(str(info.get("greet", "...")), 1.2)


func face_player() -> void:
	if _spr and level and level.player:
		_spr.flip_h = level.player.global_position.x < global_position.x


func face(dir: int) -> void:
	if _spr:
		_spr.flip_h = dir < 0


func emote(kind: String, t: float = 1.2) -> void:
	if _spr:
		_spr.emote(kind, t)


## Anda dx unidades (cenas).
func walk_by(dx: float, speed: float = 30.0) -> void:
	if _spr:
		_spr.flip_h = dx < 0
		_spr.play("move")
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + dx, absf(dx) / maxf(speed, 1.0))
	await tw.finished
	if _spr:
		_spr.play(str(info.get("anim", "idle")))


func interact(player: Node) -> void:
	if level == null or level.dialogue == null or level.dialogue.active:
		return
	face_player()
	if player.has_method("emote"):
		player.facing = 1 if global_position.x > player.global_position.x else -1
	var t := Story.next_talk(npc_id)
	if t.is_empty():
		return
	player.cutscene_lock = true
	await level.dialogue.run(str(info.get("name", npc_id)), t.get("lines", []))
	if is_instance_valid(player):
		player.cutscene_lock = false
	Story.finish_talk(t)
	# depois da conversa: cena, serviço (loja/mapa) ou nada
	if str(t.get("scene", "")) != "" and level.cutscene:
		level.cutscene.play(str(t["scene"]))
	var srv := str(t.get("after", info.get("service", "")))
	if srv != "" and level.hud and level.hud.has_method("open_story_service"):
		level.hud.open_story_service(npc_id, srv)
	Game.save()
