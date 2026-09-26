class_name Chest
extends Interactable
## Baú com item do pool compartilhado.

var loot: String = ""
var opened: bool = false
var _open_t: float = 0.0


func _ready() -> void:
	prompt = "Abrir"
	size = Vector2(12, 8)
	super._ready()


func can_interact() -> bool:
	return not opened


func interact(player: Node) -> void:
	if opened:
		return
	opened = true
	Audio.play("chest")
	FX.burst(global_position + Vector2(0, -6), Color(2.6, 2.0, 0.8), 10, 160.0, Vector2.UP, 60.0)
	if player.has_method("emote"):
		player.emote("!", 0.8)
	if level and loot != "":
		level.spawn_pickup(loot, global_position + Vector2(0, -8), Vector2(player.facing * -20.0, -80.0))
	if level:
		level.spawn_currency(randi_range(8, 20), global_position + Vector2(0, -6))


func _process(delta: float) -> void:
	super._process(delta)
	if opened:
		_open_t = minf(_open_t + delta * 8.0, 1.0)


func _draw_body() -> void:
	var o := Color(0.09, 0.07, 0.12)
	draw_rect(Rect2(-5, -6, 10, 6), o)
	draw_rect(Rect2(-4, -5, 8, 5), Color(0.62, 0.38, 0.2))
	draw_rect(Rect2(-4, -3, 8, 1), Color(0.95, 0.75, 0.3))
	var lid := -8.0 - _open_t * 3.0
	draw_rect(Rect2(-5, lid, 10, 3), o)
	draw_rect(Rect2(-4, lid + 1, 8, 1), Color(0.75, 0.48, 0.26))
	if not opened:
		draw_rect(Rect2(-1, -4, 2, 2), Color(1.8, 1.5, 0.6))
