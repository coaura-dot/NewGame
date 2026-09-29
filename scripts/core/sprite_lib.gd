class_name SpriteLib
extends RefCounted
## Carrega as folhas geradas por tools/pixel_art.py (PNG + JSON) e monta
## SpriteFrames / regiões em tempo de execução (com cache).

const ENEMY_DIR := "res://assets/art/enemies/"
const NPC_DIR := "res://assets/art/npcs/"

static var _frames: Dictionary = {}
static var _meta: Dictionary = {}
static var _tex: Dictionary = {}


static func json(path: String) -> Dictionary:
	if _meta.has(path):
		return _meta[path]
	var d: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			d = parsed
	_meta[path] = d
	return d


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## SpriteFrames da camada de brilho do inimigo (<id>_glow.png: olhos,
## brasas), com as mesmas animações. null se ele não tem nada que brilhe.
static func enemy_glow(id: String) -> SpriteFrames:
	if _frames.has("glow:" + id):
		return _frames["glow:" + id]
	var out: SpriteFrames = null
	if ResourceLoader.exists(ENEMY_DIR + id + "_glow.png"):
		out = _build_frames(json(ENEMY_DIR + id + ".json"), tex(ENEMY_DIR + id + "_glow.png"))
	_frames["glow:" + id] = out
	return out


## SpriteFrames de um inimigo (anims do JSON) + meta {size, feet}.
static func enemy(id: String) -> Array:
	if _frames.has("enemy:" + id):
		return _frames["enemy:" + id]
	var meta := json(ENEMY_DIR + id + ".json")
	var t := tex(ENEMY_DIR + id + ".png")
	var out := [_build_frames(meta, t), meta]
	_frames["enemy:" + id] = out
	return out


static func _build_frames(meta: Dictionary, t: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	if t and not meta.is_empty():
		var size := Vector2(meta["size"][0], meta["size"][1])
		var cols := int(meta.get("cols", 1))
		for anim in meta["anims"].keys():
			var a: Dictionary = meta["anims"][anim]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, float(a.get("fps", 8)))
			sf.set_animation_loop(anim, not anim in ["rise", "attack", "windup", "appear", "vanish", "jump"])
			for i in int(a["count"]):
				var idx := int(a["start"]) + i
				var at := AtlasTexture.new()
				at.atlas = t
				at.region = Rect2(Vector2(idx % cols, idx / cols) * size, size)
				sf.add_frame(anim, at)
	return sf


## Região (Rect2) do quadro de um NPC: espécie, papel, quadro 0-2.
static func npc_region(role: String, frame: int) -> Rect2:
	var meta := json(NPC_DIR + "npcs.json")
	var roles: Array = meta.get("roles", [])
	var r := maxi(roles.find(role), 0)
	return Rect2(frame * 16, r * 16, 16, 16)


static func npc_texture(species: String) -> Texture2D:
	var t := tex(NPC_DIR + species + ".png")
	return t if t else tex(NPC_DIR + "humano.png")


## Ícone 9x9 de item no mundo (categoria x raridade).
static func item_region(kind: String, rarity: String) -> Rect2:
	var meta := json("res://assets/art/items/items.json")
	var kinds: Array = meta.get("kinds", [])
	var rars: Array = meta.get("rarities", [])
	var k := maxi(kinds.find(kind), 0)
	var r := maxi(rars.find(rarity), 0)
	return Rect2(r * 9, k * 9, 9, 9)
