class_name BossAltar
extends Interactable
## Altar de reconjuração: refazer a luta contra o chefe desta região para
## tentar o drop de novo, se possuir o item exigido.

const TEX := preload("res://assets/art/props/altar.png")

var boss_id: String = ""
var _t: float = 0.0


func _ready() -> void:
	size = Vector2(14, 12)
	var req: String = DB.enemy(boss_id).get("refight", {}).get("requires_item", "")
	prompt = "Reconjurar (%s)" % DB.display_name(req) if req != "" else ""
	super._ready()


func can_interact() -> bool:
	return boss_id != "" and level != null and level.boss_defeated


func interact(player: Node) -> void:
	var req: String = DB.enemy(boss_id).get("refight", {}).get("requires_item", "")
	if req != "" and not Inventory.use_item(Game.profile, req):
		player.emote.show_emote("?", 0.8)
		Events.toast.emit("Requer: " + DB.display_name(req))
		return
	FX.white_flash(0.4)
	Audio.play("spell_heavy")
	player.emote.show_emote("!", 0.8)
	level.respawn_boss(boss_id, global_position + Vector2(70, -30))


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	draw_texture(TEX, Vector2(-7, -10))
	var f := 1.0 + roundf(sin(_t * 8.0))
	draw_rect(Rect2(-1, -13 - f, 2, 2 + f), Color(2.6, 1.0, 0.4))
