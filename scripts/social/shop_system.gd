class_name ShopSystem
extends RefCounted
## Comércio nas vilas (dados puros, testável). As BRASAS finalmente têm uso:
##   Mercador   — loja: estoque da região (muda a cada fase concluída)
##   Curandeira — poções
##   Ferreira   — forja: arma equipada (+10% de dano por nível) e armaduras
##   Sábio      — estudo: sobe o nível das magias
##   Receptador — compra suas armas/armaduras sobrando
##   Bardo      — Canção da Coragem: +15% de dano na próxima fase
## Nada aqui mexe na HUD: tudo devolve mensagens.

const MAX_WEAPON_LEVEL := 5
const WEAPON_COST := [60, 110, 180, 260, 360] ## brasas para ir ao nível i+1
const FRAGMENT_FROM := 2 ## a partir do 3º nível pede um Fragmento Rúnico
const ARMOR_COST := [45, 80, 130, 190, 260]
const SPELL_COST := [70, 120, 190, 270, 360]
const SONG_COST := 40
const SONG_MULT := 1.15
const RARITY_PRICE := {"common": 60, "rare": 125, "epic": 230, "legendary": 420}
const FIXED_PRICES := {"pocao_vida": 30, "pocao_foco": 30, "fragmento_runico": 70, "chave_ferro": 45}


## Preço de compra de um item (brasas).
static func price(id: String, db: Node) -> int:
	if FIXED_PRICES.has(id):
		return int(FIXED_PRICES[id])
	var kind: String = db.kind_of(id)
	var data: Dictionary = {}
	match kind:
		"weapon": data = db.weapons.get(id, {})
		"spell": data = db.spells.get(id, {})
		"armor": data = db.armor.get(id, {})
		"buff": data = db.buffs.get(id, {})
		"item": data = db.items.get(id, {})
	if kind == "item":
		return 12 if data.get("kind", "") == "gift" else 40
	var base := int(RARITY_PRICE.get(data.get("rarity", "common"), 60))
	var tier := int(data.get("tier", 1))
	var mult := {"weapon": 1.0, "spell": 1.0, "armor": 0.8, "buff": 1.2}.get(kind, 1.0) as float
	return int(round(base * (1.0 + 0.3 * (tier - 1)) * mult / 5.0)) * 5


## Quanto o Receptador paga (um terço, arredondado).
static func sell_price(id: String, db: Node) -> int:
	return maxi(5, int(price(id, db) / 3.0 / 5.0) * 5)


## Estoque do Mercador da região: poções fixas + 4 itens sorteados (sem o que
## o herói já tem). Muda a cada fase concluída ("runs").
static func stock(region_id: String, tier: int, runs: int, world_seed: int, db: Node, profile: Dictionary) -> Array:
	var rng := RngUtil.make(world_seed, "shop:%s:%d" % [region_id, runs])
	var out: Array = [{"id": "pocao_vida", "price": price("pocao_vida", db)}, {"id": "fragmento_runico", "price": price("fragmento_runico", db)}]
	var seen := {"pocao_vida": true, "fragmento_runico": true}
	var guard := 0
	while out.size() < 6 and guard < 60:
		guard += 1
		var id: String = LevelGenerator.roll_loot(rng, db, clampi(tier + 1, 1, 3), true)
		if seen.has(id) or owned(profile, id, db):
			continue
		seen[id] = true
		out.append({"id": id, "price": price(id, db)})
	return out


## Estoque da Curandeira.
static func potion_stock(db: Node) -> Array:
	return [{"id": "pocao_vida", "price": price("pocao_vida", db)}, {"id": "pocao_foco", "price": price("pocao_foco", db)}]


static func owned(profile: Dictionary, id: String, db: Node) -> bool:
	match db.kind_of(id):
		"weapon": return profile.get("weapons", []).has(id)
		"buff": return profile.get("buffs", []).has(id)
		"spell": return profile.get("spells", {}).has(id) or profile.get("sigils", {}).has(id)
	return false


## Compra: desconta as brasas e entrega o item. Devolve a mensagem ("" = não deu).
static func buy(profile: Dictionary, id: String, cost: int) -> String:
	if int(profile.get("currency", 0)) < cost:
		return ""
	profile["currency"] = int(profile.get("currency", 0)) - cost
	return Inventory.add(profile, id)


# ---------------------------------------------------------------------------
# Forja
# ---------------------------------------------------------------------------

static func weapon_level(profile: Dictionary, weapon_id: String) -> int:
	return int(profile.get("upgrade_levels", {}).get(weapon_id, 0))


## Multiplicador de dano da arma pelo nível da forja.
static func weapon_mult(profile: Dictionary, weapon_id: String) -> float:
	return 1.0 + 0.1 * weapon_level(profile, weapon_id)


## "" se pode forjar; senão o motivo.
static func weapon_block(profile: Dictionary, weapon_id: String) -> String:
	var lvl := weapon_level(profile, weapon_id)
	if lvl >= MAX_WEAPON_LEVEL:
		return "Já está no nível máximo."
	if int(profile.get("currency", 0)) < int(WEAPON_COST[lvl]):
		return "Faltam brasas (%d)." % int(WEAPON_COST[lvl])
	if lvl >= FRAGMENT_FROM and int(profile.get("items", {}).get("fragmento_runico", 0)) <= 0:
		return "Precisa de um Fragmento Rúnico."
	return ""


static func upgrade_weapon(profile: Dictionary, weapon_id: String) -> bool:
	if weapon_block(profile, weapon_id) != "":
		return false
	var lvl := weapon_level(profile, weapon_id)
	profile["currency"] = int(profile["currency"]) - int(WEAPON_COST[lvl])
	if lvl >= FRAGMENT_FROM:
		Inventory.use_item(profile, "fragmento_runico")
	if not profile.has("upgrade_levels"):
		profile["upgrade_levels"] = {}
	profile["upgrade_levels"][weapon_id] = lvl + 1
	return true


static func armor_block(profile: Dictionary, uid: int) -> String:
	var p := Inventory.find_piece(profile, uid)
	if p.is_empty():
		return "Peça não encontrada."
	var lvl := int(p.get("level", 0))
	if lvl >= Inventory.MAX_ARMOR_LEVEL:
		return "Já está no nível máximo."
	if int(profile.get("currency", 0)) < int(ARMOR_COST[lvl]):
		return "Faltam brasas (%d)." % int(ARMOR_COST[lvl])
	return ""


static func upgrade_armor(profile: Dictionary, uid: int) -> bool:
	if armor_block(profile, uid) != "":
		return false
	var p := Inventory.find_piece(profile, uid)
	var lvl := int(p.get("level", 0))
	profile["currency"] = int(profile["currency"]) - int(ARMOR_COST[lvl])
	p["level"] = lvl + 1
	return true


static func spell_block(profile: Dictionary, spell_id: String) -> String:
	var lvl := Inventory.spell_level(profile, spell_id)
	if lvl >= Inventory.MAX_SPELL_LEVEL:
		return "Já domina essa magia."
	if int(profile.get("currency", 0)) < int(SPELL_COST[lvl]):
		return "Faltam brasas (%d)." % int(SPELL_COST[lvl])
	return ""


static func upgrade_spell(profile: Dictionary, spell_id: String) -> bool:
	if spell_block(profile, spell_id) != "":
		return false
	var lvl := Inventory.spell_level(profile, spell_id)
	profile["currency"] = int(profile["currency"]) - int(SPELL_COST[lvl])
	var key := "spells" if profile.get("spells", {}).has(spell_id) else "sigils"
	profile[key][spell_id] = lvl + 1
	return true


# ---------------------------------------------------------------------------
# Receptador e Bardo
# ---------------------------------------------------------------------------

## Armas que dá para vender (nem a equipada nem a reserva).
static func sellable_weapons(profile: Dictionary) -> Array:
	var out: Array = []
	for w in profile.get("weapons", []):
		if w != profile.get("weapon", "") and w != profile.get("weapon_alt", ""):
			out.append(w)
	return out


static func sellable_armor(profile: Dictionary) -> Array:
	var eq: Array = profile.get("equipped_armor", {}).values().map(func(v): return int(v))
	var out: Array = []
	for p in profile.get("armor", []):
		if not eq.has(int(p["uid"])):
			out.append(p)
	return out


static func sell_weapon(profile: Dictionary, weapon_id: String, db: Node) -> int:
	if not sellable_weapons(profile).has(weapon_id):
		return 0
	profile["weapons"].erase(weapon_id)
	profile.get("upgrade_levels", {}).erase(weapon_id)
	var v := sell_price(weapon_id, db)
	profile["currency"] = int(profile.get("currency", 0)) + v
	return v


static func sell_armor(profile: Dictionary, uid: int, db: Node) -> int:
	for p in sellable_armor(profile):
		if int(p["uid"]) == uid:
			profile["armor"].erase(p)
			var v := sell_price(str(p["id"]), db) + 10 * int(p.get("level", 0))
			profile["currency"] = int(profile.get("currency", 0)) + v
			return v
	return 0


static func buy_song(profile: Dictionary) -> bool:
	if int(profile.get("currency", 0)) < SONG_COST or profile.get("flags", {}).get("song", false):
		return false
	profile["currency"] = int(profile["currency"]) - SONG_COST
	if not profile.has("flags"):
		profile["flags"] = {}
	profile["flags"]["song"] = true
	return true
