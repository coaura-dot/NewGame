extends Node
## Carrega e valida todo o conteúdo em res://data/*.json.
## Jogador e inimigos consultam o MESMO banco: qualquer arma/magia/armadura
## usada por um inimigo é um item válido para o jogador (e vice-versa).

const ICON_PATH := "res://assets/art/icons/items/item__%02d.png"

var weapon_classes: Dictionary = {}
var weapons: Dictionary = {}
var spells: Dictionary = {}
var armor_slots: Dictionary = {}
var armor_affixes: Dictionary = {}
var armor_sets: Dictionary = {}
var armor: Dictionary = {} ## peças geradas (<set>_<slot>) + berloques
var buffs: Dictionary = {}
var enemies: Dictionary = {}
## História e lore (data/lore.json): abertura, inscrições, títulos, códice
var lore: Dictionary = {}
var items: Dictionary = {}
var biomes: Dictionary = {}
var dimensions: Dictionary = {}
var abilities: Dictionary = {}
var npc_data: Dictionary = {}
var quest_data: Dictionary = {}

var errors: PackedStringArray = []
var _icon_cache: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	errors.clear()
	weapon_classes = _load("weapon_classes")
	weapons = _load("weapons")
	spells = _load("spells")
	var armor_raw := _load("armor")
	armor_slots = armor_raw.get("slots", {})
	armor_affixes = armor_raw.get("affixes", {})
	armor_sets = armor_raw.get("sets", {})
	buffs = _load("buffs")
	enemies = _load("enemies")
	items = _load("items")
	biomes = _load("biomes")
	dimensions = _load("dimensions")
	abilities = _load("abilities")
	npc_data = _load("npcs")
	quest_data = _load("quests")
	lore = _load("lore")
	_build_armor(armor_raw.get("trinkets", {}))
	_validate()
	for e in errors:
		push_error("[DB] " + e)


func _load(file_name: String) -> Dictionary:
	var path := "res://data/%s.json" % file_name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("não abriu " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("JSON inválido em " + path)
		return {}
	var d: Dictionary = parsed
	for k in d.keys():
		if str(k).begins_with("_"):
			d.erase(k)
	return d


func _build_armor(trinkets: Dictionary) -> void:
	armor.clear()
	for set_id in armor_sets.keys():
		var s: Dictionary = armor_sets[set_id]
		for slot_id in armor_slots.keys():
			var slot: Dictionary = armor_slots[slot_id]
			var stats := {}
			for stat in s.get("base", {}).keys():
				stats[stat] = float(s["base"][stat]) * float(slot.get("weight", 1.0))
			armor["%s_%s" % [set_id, slot_id]] = {
				"name": "%s do %s" % [slot["name"], s["name"]],
				"slot": slot_id,
				"set": set_id,
				"tier": s.get("tier", 1),
				"rarity": "rare" if int(s.get("tier", 1)) >= 2 else "common",
				"icon": slot.get("icon", 44),
				"stats": stats,
			}
	for t_id in trinkets.keys():
		var t: Dictionary = trinkets[t_id].duplicate(true)
		t["slot"] = "trinket"
		armor[t_id] = t


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

## Tipo do item: weapon, spell, armor, buff, item ou "" se não existir.
func kind_of(id: String) -> String:
	if weapons.has(id):
		return "weapon"
	if spells.has(id):
		return "spell"
	if armor.has(id):
		return "armor"
	if buffs.has(id):
		return "buff"
	if items.has(id):
		return "item"
	return ""


func get_entry(id: String) -> Dictionary:
	match kind_of(id):
		"weapon": return weapons[id]
		"spell": return spells[id]
		"armor": return armor[id]
		"buff": return buffs[id]
		"item": return items[id]
	return {}


func display_name(id: String) -> String:
	return str(get_entry(id).get("name", id))


func icon(id_or_index: Variant) -> Texture2D:
	var idx := 0
	if typeof(id_or_index) == TYPE_INT:
		idx = id_or_index
	else:
		idx = int(get_entry(str(id_or_index)).get("icon", 0))
	if not _icon_cache.has(idx):
		var p := ICON_PATH % idx
		_icon_cache[idx] = load(p) if ResourceLoader.exists(p) else null
	return _icon_cache[idx]


func weapon(id: String) -> Dictionary:
	return weapons.get(id, {})


## Moveset (classe) da arma, já com o dano base e status da arma embutidos.
func moveset(weapon_id: String) -> Dictionary:
	var w: Dictionary = weapons.get(weapon_id, {})
	if w.is_empty():
		return {}
	var cls: Dictionary = weapon_classes.get(w.get("class", ""), {})
	var m := cls.duplicate(true)
	m["weapon_id"] = weapon_id
	m["class"] = w.get("class", "")
	m["damage"] = float(w.get("damage", 10))
	m["weapon_status"] = w.get("status", {})
	return m


func spell(id: String) -> Dictionary:
	return spells.get(id, {})


## Valor de um campo da magia já escalado pelo nível de upgrade.
func spell_value(id: String, key: String, level: int = 0) -> float:
	var s: Dictionary = spells.get(id, {})
	var base := float(s.get(key, 0.0))
	var per: float = float(s.get("upgrade", {}).get(key, 0.0))
	return base * (1.0 + per * max(level, 0))


func enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


func biome(id: String) -> Dictionary:
	return biomes.get(id, {})


func dimension(id: String) -> Dictionary:
	return dimensions.get(id, dimensions.get("prima", {}))


func rarity_color(rarity: String) -> Color:
	match rarity:
		"rare": return Color(0.45, 0.7, 1.0)
		"epic": return Color(0.8, 0.45, 1.0)
		"legendary": return Color(1.0, 0.72, 0.25)
		"set": return Color(0.5, 1.0, 0.6)
	return Color(0.85, 0.85, 0.85)


# ---------------------------------------------------------------------------
# Validação cruzada (também usada pelos testes)
# ---------------------------------------------------------------------------

func _validate() -> void:
	for id in weapons.keys():
		var cls: String = weapons[id].get("class", "")
		if not weapon_classes.has(cls):
			errors.append("arma %s usa classe inexistente %s" % [id, cls])
	for cls_id in weapon_classes.keys():
		var c: Dictionary = weapon_classes[cls_id]
		for key in ["light", "heavy", "dash", "air", "down_air", "up_air"]:
			if not c.has(key):
				errors.append("classe %s sem golpe %s" % [cls_id, key])
	for id in spells.keys():
		if not spells[id].has("cast"):
			errors.append("magia %s sem cast" % id)
	for id in enemies.keys():
		var e: Dictionary = enemies[id]
		var lo: Dictionary = e.get("loadout", {})
		var w: String = lo.get("weapon", "")
		if w != "" and not weapons.has(w):
			errors.append("inimigo %s usa arma inexistente %s" % [id, w])
		for s in lo.get("spells", []):
			if not spells.has(s):
				errors.append("inimigo %s usa magia inexistente %s" % [id, s])
		for a in lo.get("armor", []):
			if not armor.has(a):
				errors.append("inimigo %s usa armadura inexistente %s" % [id, a])
		for d in e.get("drops", []):
			if kind_of(d.get("id", "")) == "":
				errors.append("inimigo %s dropa item inexistente %s" % [id, d.get("id", "")])
		for m in e.get("minions", {}).keys():
			if not enemies.has(m):
				errors.append("inimigo %s invoca inimigo inexistente %s" % [id, m])
		var refight: Dictionary = e.get("refight", {})
		if refight.has("requires_item") and kind_of(refight["requires_item"]) == "":
			errors.append("inimigo %s exige item inexistente %s" % [id, refight["requires_item"]])
	for id in biomes.keys():
		for en in biomes[id].get("enemies", {}).keys():
			if not enemies.has(en):
				errors.append("bioma %s referencia inimigo %s" % [id, en])
	for id in dimensions.keys():
		for en in dimensions[id].get("creatures", {}).keys():
			if not enemies.has(en):
				errors.append("dimensão %s referencia inimigo %s" % [id, en])
	for set_id in armor_sets.keys():
		for n in armor_sets[set_id].get("bonuses", {}).keys():
			var b: Dictionary = armor_sets[set_id]["bonuses"][n]
			if b.has("buff") and not buffs.has(b["buff"]):
				errors.append("bônus %s/%s usa buff inexistente %s" % [set_id, n, b["buff"]])
	for id in weapons.keys():
		var ex: String = weapons[id].get("exclusive_to", "")
		if ex != "" and not enemies.has(ex):
			errors.append("arma %s exclusiva de inimigo inexistente %s" % [id, ex])
