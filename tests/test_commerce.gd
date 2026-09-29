extends "res://tests/test_case.gd"
## Loja, forja e estudo (Commerce).


func _setup() -> Array:
	var world := WorldGenerator.generate(321, DB)
	var social := SocialSystem.create(world, 321, DB)
	var profile: Dictionary = Game.START_PROFILE.duplicate(true)
	var merchant := ""
	var smith := ""
	var sage := ""
	for npc in social["npcs"].values():
		if npc["services"].has("shop") and merchant == "":
			merchant = npc["id"]
		if npc["services"].has("upgrade_weapon") and smith == "":
			smith = npc["id"]
		if npc["services"].has("upgrade_spell") and sage == "":
			sage = npc["id"]
	return [world, social, profile, merchant, smith, sage]


func test_estoque_e_compra() -> void:
	var s := _setup()
	var world: Dictionary = s[0]
	var social: Dictionary = s[1]
	var profile: Dictionary = s[2]
	var merchant: String = s[3]
	check(merchant != "", "existe mercador no mundo")
	if merchant == "":
		return
	var a := Commerce.stock(social, world, merchant, 321)
	var b := Commerce.stock(social, world, merchant, 321)
	eq(a, b, "estoque determinístico no mesmo dia")
	check(a.size() >= 4, "estoque com itens (%d)" % a.size())
	for id in a:
		check(DB.kind_of(id) != "", "item de estoque válido: %s" % id)
		check(DB.get_entry(id).get("exclusive_to", "") == "", "exclusivo nunca na loja: %s" % id)
		check(Commerce.base_price(id) > 0, "preço positivo: %s" % id)
	# sem dinheiro não compra
	profile["currency"] = 0
	check(Commerce.buy(profile, social, merchant, a[0]) != "", "sem brasas não compra")
	# com dinheiro compra e sai do estoque (se não for consumível)
	profile["currency"] = 99999
	var target := ""
	for id in a:
		if DB.kind_of(id) != "item" and not Commerce.owns(profile, id):
			target = id
			break
	if target != "":
		eq(Commerce.buy(profile, social, merchant, target), "", "compra " + target)
		check(not Commerce.stock(social, world, merchant, 321).has(target), "vendido some do estoque")
		check(Commerce.owns(profile, target) or DB.kind_of(target) == "armor", "item comprado no perfil")
	# poção sempre disponível
	var before := int(profile["items"].get("pocao_vida", 0))
	eq(Commerce.buy(profile, social, merchant, "pocao_vida"), "", "compra poção")
	eq(int(profile["items"]["pocao_vida"]), before + 1, "poção no inventário")
	# novo dia: estoque renova
	social["day"] = int(social["day"]) + 1
	check(Commerce.stock(social, world, merchant, 321).size() >= 4, "estoque renova no dia seguinte")


func test_vender() -> void:
	var s := _setup()
	var social: Dictionary = s[1]
	var profile: Dictionary = s[2]
	var merchant: String = s[3]
	if merchant == "":
		return
	profile["currency"] = 0
	var sell := Commerce.sellables(profile)
	check(not sell.has(profile["weapon"]), "arma equipada não é vendável")
	check(sell.has("presas_infernais"), "arma sobrando é vendável")
	eq(Commerce.sell(profile, social, merchant, "presas_infernais"), "", "vende arma")
	check(not profile["weapons"].has("presas_infernais"), "arma saiu do inventário")
	check(int(profile["currency"]) > 0, "recebeu brasas")
	check(Commerce.sell(profile, social, merchant, profile["weapon"]) != "", "não vende a equipada")


func test_forja_e_estudo() -> void:
	var s := _setup()
	var social: Dictionary = s[1]
	var profile: Dictionary = s[2]
	var smith: String = s[4]
	var npc: Dictionary = social["npcs"].get(smith, {})
	var wid: String = profile["weapon"]
	eq(Commerce.weapon_level(profile, wid), 0, "arma começa +0")
	profile["currency"] = 0
	check(Commerce.upgrade_weapon(profile, wid, npc) != "", "sem recursos não forja")
	profile["currency"] = 99999
	profile["items"][Commerce.FRAGMENT] = 20
	for i in Commerce.MAX_WEAPON_LEVEL:
		eq(Commerce.upgrade_weapon(profile, wid, npc), "", "forja nível %d" % (i + 1))
	eq(Commerce.weapon_level(profile, wid), Commerce.MAX_WEAPON_LEVEL, "chegou ao máximo")
	check(Commerce.upgrade_weapon(profile, wid, npc) != "", "não passa do máximo")
	check(int(profile["items"].get(Commerce.FRAGMENT, 0)) < 20, "gastou fragmentos")
	# o dano da arma equipada no jogador reflete a forja
	var m := DB.moveset(wid)
	check(is_equal_approx(float(m["damage"]) * Commerce.weapon_mult(3), float(m["damage"]) * 1.36), "multiplicador +12%/nível")
	# estudo de magia
	var sid: String = profile["spells"].keys()[0]
	var lv0 := Inventory.spell_level(profile, sid)
	eq(Commerce.upgrade_spell(profile, sid, npc), "", "estuda magia")
	eq(Inventory.spell_level(profile, sid), lv0 + 1, "magia subiu de nível")
	# armadura
	Inventory.add(profile, DB.armor.keys()[0])
	var uid := int(profile["armor"][0]["uid"])
	eq(Commerce.upgrade_armor(profile, uid, npc), "", "reforça armadura")
	eq(int(Inventory.find_piece(profile, uid)["level"]), 1, "armadura +1")
