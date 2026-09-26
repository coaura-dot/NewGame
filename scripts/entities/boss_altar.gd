class_name BossAltar
extends Interactable
## Altar de reconjuração: refazer a luta contra o chefe desta região para
## tentar o drop de novo, se possuir o item exigido.

var boss_id: String = ""
var _t: float = 0.0


func _ready() -> void:
	size = Vector2(10, 10)
	var req: String = DB.enemy(boss_id).get("refight", {}).get("requires_item", "")
	prompt = "Reconjurar (%s)" % DB.display_name(req) if req != "" else ""
	super._ready()


func can_interact() -> bool:
	return boss_id != "" and level != null and level.boss_defeated


func interact(_player: Node) -> void:
	var req: String = DB.enemy(boss_id).get("refight", {}).get("requires_item", "")
	if req != "" and not Inventory.use_item(Game.profile, req):
		FX.text(global_position + Vector2(0, -40), "Requer: " + DB.display_name(req), Color(2.0, 1.0, 0.8))
		return
	FX.flash(1.0)
	Audio.play("spell_heavy")
	level.respawn_boss(boss_id, global_position + Vector2(140, -60))


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	draw_rect(Rect2(-4, -5, 8, 5), Color(0.25, 0.2, 0.28))
	draw_rect(Rect2(-5, -6, 10, 1), Color(0.45, 0.38, 0.5))
	draw_rect(Rect2(-1, -9, 2, 3), Color(3.0, 1.0, 0.4, 0.9))
