class_name Commerce
extends RefCounted
## Loja, forja e estudo (serviços dos NPCs em data/npcs.json):
##   shop / shop_potions  -> comprar (estoque do dia, determinístico por seed)
##   fence / shop         -> vender (receptador paga mais)
##   upgrade_weapon       -> forjar armas (+12% de dano por nível, até 3)
##   upgrade_armor        -> reforçar armaduras (até Inventory.MAX_ARMOR_LEVEL)
##   upgrade_spell        -> estudar magias/sigilos (até Inventory.MAX_SPELL_LEVEL)
##   heal                 -> curar por brasas
## Upgrades custam brasas + Fragmentos Rúnicos (baús). Amigos dão desconto.
## Estado: Game.social["shops"][npc_id] = {"day": d, "sold": [ids]}.

const MAX_WEAPON_LEVEL := 3
const WEAPON_UPGRADE := 0.12 ## dano extra por nível de forja
const FRAGMENT := "fragmento_runico"
const RARITY_MULT := {"common": 1.0, "rare": 1.8, "epic": 3.0, "legendary": 5.0}
const KIND_BASE := {"weapon": 110, "spell": 95, "armor": 70, "buff": 130}
const ITEM_PRICE := {"pocao_vida": 30, "pocao_foco": 35, "chave_ferro": 60, "fragmento_runico": 55,
	"maca": 12, "queijo": 18, "ovo": 10, "torta": 22, "vela": 15, "calice": 40, "pergaminho": 30}
const SELL_RATE := 0.35
const FENCE_RATE := 0.5


# ---------------------------------------------------------------------------
# Preços
# ---------------------------------------------------------------------------

static func base_price(id: String) -> int:
	var kind := DB.kind_of(id)
	if kind == "item":
		return int(ITEM_PRICE.get(id, 20))
	var e := DB.get_entry(id)
	var tier := int(e.get("tier", 1))
	var mult: float = RARITY_MULT.get(e.get("rarity", "common"), 1.0)
	return int(roundf(float(KIND_BASE.get(kind, 80)) * mult * (0.7 + 0.3 * tier) / 5.0) * 5)


## Desconto por amizade: 2% por coração, até 20%.
static func discount(npc: Dictionary) -> float:
	return minf(SocialSystem.hearts(int(npc.get("affinity", 0))) * 0.02, 0.2)


static func buy_price(id: String, npc: Dictionary) -> int:
	return maxi(int(roundf(base_price(id) * (1.0 - discount(npc)))), 1)


static func sell_price(id: String, npc: Dictionary) -> int:
	var rate := FENCE_RATE if npc.get("services", []).has("fence") else SELL_RATE
	return maxi(int(base_price(id) * rate), 1)


static func can_sell(npc: Dictionary) -> bool:
	var s: Array = npc.get("services", [])
	return s.has("fence") or s.has("shop")


static func can_buy(npc: Dictionary) -> bool:
	var s: Array = npc.get("services", [])
	return s.has("shop") or s.has("shop_potions") or s.has("fence")


# ---------------------------------------------------------------------------
# Estoque
# ---------------------------------------------------------------------------

## Estoque do dia (mesma seed + mesmo dia = mesmos itens), sem o já vendido.
static func stock(social: Dictionary, world: Dictionary, npc_id: String, seed_value: int) -> Array:
	var npc: Dictionary = social.get("npcs", {}).get(npc_id, {})
	if npc.is_empty():
		return []
	var day := int(social.get("day", 0))
	var region: Dictionary = world.get("regions", {}).get(npc.get("region", ""), {})
	var tier := int(region.get("tier", 1))
	var rng := RngUtil.make(seed_value, "shop:%s:%d" % [npc_id, day])
	var out: Array = []
	var s: Array = npc.get("services", [])
	if s.has("shop_potions"):
		out.append_array(["pocao_vida", "pocao_foco"])
		out.append(RngUtil.pick(rng, ["maca", "vela", "torta"]))
	if s.has("shop"):
		out.append("pocao_vida")
		out.append(RngUtil.pick(rng, ["maca", "queijo", "torta", "vela", "calice", "pergaminho"]))
		if rng.randf() < 0.5:
			out.append(FRAGMENT)
		var guard := 0
		while out.size() < 6 and guard < 30:
			guard += 1
			var id := LevelGenerator.roll_loot(rng, DB, tier, true)
			if not out.has(id) and DB.kind_of(id) != "item":
				out.append(id)
	if s.has("fence"):
		out.append("chave_ferro")
		out.append(FRAGMENT)
		var shady := LevelGenerator.roll_loot(rng, DB, tier + 1, true, true)
		if not out.has(shady):
			out.append(shady)
	var sold: Array = _shop_state(social, npc_id).get("sold", [])
	var result: Array = []
	for id in out:
		# consumíveis nunca esgotam; o resto sai do estoque ao ser comprado
		if DB.kind_of(id) == "item" or not sold.has(id):
			result.append(id)
	return result


static func _shop_state(social: Dictionary, npc_id: String) -> Dictionary:
	if not social.has("shops"):
		social["shops"] = {}
	var st: Dictionary = social["shops"].get(npc_id, {})
	if int(st.get("day", -1)) != int(social.get("day", 0)):
		st = {"day": int(social.get("day", 0)), "sold": []}
		social["shops"][npc_id] = st
	return st


## Já possui (não faz sentido comprar de novo)?
static func owns(profile: Dictionary, id: String) -> bool:
	match DB.kind_of(id):
		"weapon":
			return profile.get("weapons", []).has(id)
		"buff":
			return profile.get("buffs", []).has(id)
		"spell":
			return profile.get("spells", {}).has(id) or profile.get("sigils", {}).has(id)
	return false


## Compra. Devolve "" se deu certo ou o motivo da recusa.
static func buy(profile: Dictionary, social: Dictionary, npc_id: String, id: String) -> String:
	var npc: Dictionary = social.get("npcs", {}).get(npc_id, {})
	var price := buy_price(id, npc)
	if owns(profile, id):
		return "Você já tem isso."
	if int(profile.get("currency", 0)) < price:
		return "Brasas insuficientes."
	profile["currency"] = int(profile.get("currency", 0)) - price
	Inventory.add(profile, id)
	if DB.kind_of(id) != "item":
		_shop_state(social, npc_id)["sold"].append(id)
	return ""


## Itens que o jogador pode vender (nada equipado, nada de chave/missão).
static func sellables(profile: Dictionary) -> Array:
	var out: Array = []
	for w in profile.get("weapons", []):
		if w != profile.get("weapon", "") and w != profile.get("weapon_alt", ""):
			out.append(w)
	for it in profile.get("items", {}).keys():
		var k: String = DB.items.get(it, {}).get("kind", "")
		if k in ["gift", "consumable", "upgrade"]:
			out.append(it)
	return out


static func sell(profile: Dictionary, social: Dictionary, npc_id: String, id: String) -> String:
	var npc: Dictionary = social.get("npcs", {}).get(npc_id, {})
	if not sellables(profile).has(id):
		return "Não dá para vender isso."
	match DB.kind_of(id):
		"weapon":
			profile["weapons"].erase(id)
			profile.get("upgrade_levels", {}).erase(id)
		"item":
			Inventory.use_item(profile, id)
	profile["currency"] = int(profile.get("currency", 0)) + sell_price(id, npc)
	return ""


# ---------------------------------------------------------------------------
# Forja / estudo
# ---------------------------------------------------------------------------

static func weapon_level(profile: Dictionary, id: String) -> int:
	return int(profile.get("upgrade_levels", {}).get(id, 0))


## Multiplicador de dano de uma arma forjada.
static func weapon_mult(level: int) -> float:
	return 1.0 + WEAPON_UPGRADE * level


## Custo do próximo nível: {"currency", "fragments"} ou {} se no máximo.
static func weapon_cost(profile: Dictionary, id: String) -> Dictionary:
	var lvl := weapon_level(profile, id)
	if lvl >= MAX_WEAPON_LEVEL:
		return {}
	var tier := int(DB.weapon(id).get("tier", 1))
	return {"currency": 60 * (lvl + 1) * tier + 40, "fragments": lvl + 1}


static func spell_cost(profile: Dictionary, sid: String) -> Dictionary:
	var lvl := Inventory.spell_level(profile, sid)
	if lvl >= Inventory.MAX_SPELL_LEVEL:
		return {}
	var tier := int(DB.spell(sid).get("tier", 1))
	return {"currency": 45 * (lvl + 1) * tier + 30, "fragments": 1 + lvl / 2}


static func armor_cost(profile: Dictionary, uid: int) -> Dictionary:
	var piece := Inventory.find_piece(profile, uid)
	if piece.is_empty():
		return {}
	var lvl := int(piece.get("level", 0))
	if lvl >= Inventory.MAX_ARMOR_LEVEL:
		return {}
	var tier := int(DB.armor.get(piece["id"], {}).get("tier", 1))
	return {"currency": 35 * (lvl + 1) * tier + 25, "fragments": 1 if lvl < 2 else 2}


static func can_pay(profile: Dictionary, cost: Dictionary, npc: Dictionary = {}) -> bool:
	if cost.is_empty():
		return false
	var price := int(roundf(int(cost["currency"]) * (1.0 - discount(npc))))
	return int(profile.get("currency", 0)) >= price and int(profile.get("items", {}).get(FRAGMENT, 0)) >= int(cost["fragments"])


static func _pay(profile: Dictionary, cost: Dictionary, npc: Dictionary) -> void:
	profile["currency"] = int(profile.get("currency", 0)) - int(roundf(int(cost["currency"]) * (1.0 - discount(npc))))
	for i in int(cost["fragments"]):
		Inventory.use_item(profile, FRAGMENT)


static func upgrade_weapon(profile: Dictionary, id: String, npc: Dictionary = {}) -> String:
	var cost := weapon_cost(profile, id)
	if cost.is_empty():
		return "Já está no nível máximo."
	if not can_pay(profile, cost, npc):
		return "Faltam brasas ou fragmentos."
	_pay(profile, cost, npc)
	if not profile.has("upgrade_levels"):
		profile["upgrade_levels"] = {}
	profile["upgrade_levels"][id] = weapon_level(profile, id) + 1
	return ""


static func upgrade_spell(profile: Dictionary, sid: String, npc: Dictionary = {}) -> String:
	var cost := spell_cost(profile, sid)
	if cost.is_empty():
		return "Já está no nível máximo."
	if not can_pay(profile, cost, npc):
		return "Faltam brasas ou fragmentos."
	_pay(profile, cost, npc)
	var book: Dictionary = profile["spells"] if profile.get("spells", {}).has(sid) else profile["sigils"]
	book[sid] = int(book[sid]) + 1
	return ""


static func upgrade_armor(profile: Dictionary, uid: int, npc: Dictionary = {}) -> String:
	var cost := armor_cost(profile, uid)
	if cost.is_empty():
		return "Já está no nível máximo."
	if not can_pay(profile, cost, npc):
		return "Faltam brasas ou fragmentos."
	_pay(profile, cost, npc)
	var piece := Inventory.find_piece(profile, uid)
	piece["level"] = int(piece.get("level", 0)) + 1
	return ""


## Cura: 1 brasa por ponto de vida faltando (amigos pagam menos).
static func heal_cost(missing_hp: float, npc: Dictionary) -> int:
	return int(ceil(maxf(missing_hp, 0.0) * 0.6 * (1.0 - discount(npc))))
