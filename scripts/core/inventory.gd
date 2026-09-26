class_name Inventory
extends RefCounted
## Operações sobre o perfil do jogador (Game.profile): adicionar itens,
## equipar armaduras e agregar atributos de equipamento + bônus de conjunto.

const MAX_SPELL_LEVEL := 5
const MAX_ARMOR_LEVEL := 5


## Adiciona um item qualquer ao perfil. Retorna uma mensagem para a HUD.
static func add(profile: Dictionary, id: String, rng: RandomNumberGenerator = null) -> String:
	var name := DB.display_name(id)
	match DB.kind_of(id):
		"weapon":
			if not profile["weapons"].has(id):
				profile["weapons"].append(id)
				return "Nova arma: " + name
			profile["currency"] = int(profile.get("currency", 0)) + 25
			return name + " (repetida: +25 brasas)"
		"spell":
			var key := "sigils" if DB.spell(id).get("cast", "") == "sigil" else "spells"
			var book: Dictionary = profile[key]
			if book.has(id):
				book[id] = mini(int(book[id]) + 1, MAX_SPELL_LEVEL)
				return "%s nível %d" % [name, book[id] + 1]
			book[id] = 0
			return "Nova magia: " + name
		"armor":
			var piece := {
				"uid": int(profile.get("next_uid", 1)),
				"id": id,
				"level": 0,
				"affixes": roll_affixes(id, rng),
			}
			profile["next_uid"] = piece["uid"] + 1
			profile["armor"].append(piece)
			return "Armadura: " + name
		"buff":
			if not profile["buffs"].has(id):
				profile["buffs"].append(id)
				return "Relíquia: " + name
			return name + " (já possui)"
		"item":
			profile["items"][id] = int(profile["items"].get(id, 0)) + 1
			return name
	return ""


static func roll_affixes(armor_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var a: Dictionary = DB.armor.get(armor_id, {})
	if a.get("slot", "") == "trinket":
		return {}
	var count := clampi(int(a.get("tier", 1)) + rng.randi_range(-1, 1), 0, 3)
	var keys: Array = DB.armor_affixes.keys()
	keys.sort()
	RngUtil.shuffle(rng, keys)
	var out := {}
	for i in mini(count, keys.size()):
		var af: Dictionary = DB.armor_affixes[keys[i]]
		var v := rng.randf_range(float(af["min"]), float(af["max"]))
		out[af["stat"]] = snappedf(v, 0.01)
	return out


static func find_piece(profile: Dictionary, uid: int) -> Dictionary:
	for p in profile.get("armor", []):
		if int(p["uid"]) == uid:
			return p
	return {}


static func equip_armor(profile: Dictionary, uid: int) -> void:
	var piece := find_piece(profile, uid)
	if piece.is_empty():
		return
	var slot: String = DB.armor.get(piece["id"], {}).get("slot", "")
	if slot == "trinket":
		var eq: Dictionary = profile["equipped_armor"]
		if not eq.has("trinket_1") or int(eq["trinket_1"]) == uid:
			slot = "trinket_1"
		else:
			slot = "trinket_2"
	profile["equipped_armor"][slot] = uid


static func unequip(profile: Dictionary, slot: String) -> void:
	profile["equipped_armor"].erase(slot)


static func equipped_pieces(profile: Dictionary) -> Array:
	var out := []
	for slot in profile.get("equipped_armor", {}).keys():
		var p := find_piece(profile, int(profile["equipped_armor"][slot]))
		if not p.is_empty():
			out.append(p)
	return out


static func set_counts(profile: Dictionary) -> Dictionary:
	var counts := {}
	for p in equipped_pieces(profile):
		var s: String = DB.armor.get(p["id"], {}).get("set", "")
		if s != "":
			counts[s] = int(counts.get(s, 0)) + 1
	return counts


## Atributos somados de armaduras equipadas (+nível, afixos, bônus de conjunto)
## e lista de buffs concedidos por conjuntos.
static func armor_bonus(profile: Dictionary) -> Dictionary:
	var stats := {}
	var buffs := []
	for p in equipped_pieces(profile):
		var a: Dictionary = DB.armor.get(p["id"], {})
		var lvl_mult := 1.0 + 0.15 * int(p.get("level", 0))
		for st in a.get("stats", {}).keys():
			stats[st] = float(stats.get(st, 0.0)) + float(a["stats"][st]) * lvl_mult
		for st in p.get("affixes", {}).keys():
			stats[st] = float(stats.get(st, 0.0)) + float(p["affixes"][st])
	var counts := set_counts(profile)
	for set_id in counts.keys():
		var bonuses: Dictionary = DB.armor_sets.get(set_id, {}).get("bonuses", {})
		for need in bonuses.keys():
			if counts[set_id] >= int(need):
				var b: Dictionary = bonuses[need]
				for st in b.get("stats", {}).keys():
					stats[st] = float(stats.get(st, 0.0)) + float(b["stats"][st])
				if b.has("buff"):
					buffs.append(b["buff"])
	return {"stats": stats, "buffs": buffs}


static func spell_level(profile: Dictionary, spell_id: String) -> int:
	if profile.get("spells", {}).has(spell_id):
		return int(profile["spells"][spell_id])
	return int(profile.get("sigils", {}).get(spell_id, 0))


static func use_item(profile: Dictionary, item_id: String) -> bool:
	var n := int(profile.get("items", {}).get(item_id, 0))
	if n <= 0:
		return false
	profile["items"][item_id] = n - 1
	if profile["items"][item_id] <= 0:
		profile["items"].erase(item_id)
	return true
