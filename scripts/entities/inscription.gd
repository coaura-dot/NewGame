class_name Inscription
extends Interactable
## Inscrição de pedra com um trecho da história de Cindária (data/lore.json).
## Ler registra no Códice (pausa > Códice).

var biome_id: String = ""
var index: int = 0
var _t: float = 0.0


func _ready() -> void:
	prompt = "Ler"
	size = Vector2(12, 14)
	super._ready()
	_t = randf() * 5.0


func lore_id() -> String:
	return "%s:%d" % [biome_id, index]


func text() -> String:
	var lines: Array = DB.lore.get("biomes", {}).get(biome_id, [])
	if lines.is_empty():
		return "As letras estão gastas demais para ler."
	return str(lines[index % lines.size()])


func interact(player: Node) -> void:
	var read_before: bool = Game.profile.get("codex", []).has(lore_id())
	if not Game.training:
		if not Game.profile.has("codex"):
			Game.profile["codex"] = []
		if not read_before:
			Game.profile["codex"].append(lore_id())
	if level and level.hud and level.hud.has_method("show_lore"):
		level.hud.show_lore(DB.biome(biome_id).get("name", "Inscrição"), text(), not read_before)
	if player.has_method("emote"):
		player.emote("...", 1.2)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	# lápide com runas que brilham de leve
	var stone := Color(0.42, 0.4, 0.48)
	var dark := Color(0.09, 0.07, 0.12)
	draw_rect(Rect2(-5, -12, 10, 12), dark)
	draw_rect(Rect2(-4, -11, 8, 11), stone)
	draw_rect(Rect2(-4, -11, 8, 1), stone.lightened(0.25))
	var glow := 0.6 + 0.4 * sin(_t * 2.0)
	var rune := Color(1.2 * glow + 0.4, 0.9 * glow + 0.3, 0.4, 1.0)
	for i in 3:
		draw_rect(Rect2(-2 + (i % 2), -9 + i * 3, 3 - (i % 2), 1), rune)
