class_name RelicPedestal
extends Interactable
## Pedestal com relíquia/item raro (recompensa de desafio ou sala secreta).

const TEX := preload("res://assets/art/props/pedestal.png")

var loot: String = ""
var taken: bool = false
var _t: float = 0.0
var _tex: Texture2D
var _region: Rect2
var _glow: Sprite2D


func _ready() -> void:
	prompt = "Pegar"
	size = Vector2(12, 18)
	super._ready()
	_tex = SpriteLib.tex("res://assets/art/items/items.png")
	var rar: String = DB.get_entry(loot).get("rarity", "rare")
	var kind := DB.kind_of(loot)
	_region = SpriteLib.item_region(kind if kind != "" else "buff", rar)
	var col := DB.rarity_color(rar)
	_glow = LightUtil.make_glow(Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.45), 10.0)
	_glow.position = Vector2(0, -14)
	add_child(_glow)


func can_interact() -> bool:
	return not taken and loot != ""


func interact(player: Node) -> void:
	if taken:
		return
	taken = true
	_glow.visible = false
	Events.toast.emit(Inventory.add(Game.profile, loot))
	if DB.kind_of(loot) == "buff":
		player.buffs.set_buffs(Game.profile["buffs"] + Inventory.armor_bonus(Game.profile)["buffs"])
	Audio.play("pickup")
	FX.burst(global_position + Vector2(0, -14), Color(2.4, 2.0, 1.0), 12, 80.0)
	FX.white_flash(0.2)
	player.emote.show_emote("spark", 1.2, true)
	player.rig.set_expression("happy", 1.0)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta


func _draw_body() -> void:
	draw_texture(TEX, Vector2(-5, -8))
	if not taken and _tex:
		var b := roundf(sin(_t * 2.5) * 1.5)
		draw_texture_rect_region(_tex, Rect2(Vector2(-4, -19 + b), Vector2(9, 9)), _region)
