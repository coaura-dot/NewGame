class_name RelicPedestal
extends Interactable
## Pedestal com relíquia/item raro (recompensa de desafio ou sala secreta).

var loot: String = ""
var taken: bool = false
var _t: float = 0.0
var _icon: Texture2D


func _ready() -> void:
	prompt = "Pegar"
	size = Vector2(10, 14)
	super._ready()
	_icon = DB.icon(loot)
	var l := LightUtil.make_light(DB.rarity_color(DB.get_entry(loot).get("rarity", "rare")), 1.0, 0.5)
	if l:
		l.position = Vector2(0, -10)
		add_child(l)


func can_interact() -> bool:
	return not taken and loot != ""


func interact(player: Node) -> void:
	if taken:
		return
	taken = true
	Events.toast.emit(Inventory.add(Game.profile, loot))
	if DB.kind_of(loot) == "buff":
		player.buffs.set_buffs(Game.profile["buffs"] + Inventory.armor_bonus(Game.profile)["buffs"])
	Audio.play("pickup")
	FX.burst(global_position + Vector2(0, -10), Color(2.6, 2.2, 1.0), 14, 160.0)
	FX.flash(0.4)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	draw_rect(Rect2(-3, -5, 6, 5), Color(0.3, 0.26, 0.34))
	draw_rect(Rect2(-4, -6, 8, 1), Color(0.5, 0.44, 0.52))
	if not taken:
		var b := roundf(sin(_t * 2.5))
		var c := DB.rarity_color(DB.get_entry(loot).get("rarity", "rare")) * 1.8
		draw_rect(Rect2(-2, -12 + b, 4, 4), c)
		draw_rect(Rect2(-1, -13 + b, 2, 6), Color(c.r, c.g, c.b, 0.5))
