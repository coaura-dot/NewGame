extends "res://tests/test_case.gd"
## Inventário, conjuntos de armadura, NPCs, reputação, casamento e o Cerco.


func _profile() -> Dictionary:
	return Game.START_PROFILE.duplicate(true)


func test_inventario() -> void:
	var p := _profile()
	Inventory.add(p, "katana_rubra")
	check(p["weapons"].has("katana_rubra"), "arma adicionada")
	Inventory.add(p, "chama")
	eq(int(p["spells"]["chama"]), 1, "magia repetida sobe de nível")
	Inventory.add(p, "sigilo_vazio")
	check(p["sigils"].has("sigilo_vazio"), "sigilo vai para o grimório de sigilos")
	Inventory.add(p, "centelha")
	check(p["buffs"].has("centelha"), "relíquia adicionada")
	var rng := RngUtil.make(9, "aff")
	Inventory.add(p, "vigia_noturno_head", rng)
	Inventory.add(p, "vigia_noturno_chest", rng)
	eq(p["armor"].size(), 2, "duas peças")
	Inventory.equip_armor(p, int(p["armor"][0]["uid"]))
	Inventory.equip_armor(p, int(p["armor"][1]["uid"]))
	var bonus := Inventory.armor_bonus(p)
	check(float(bonus["stats"].get("max_hp", 0.0)) >= 15.0, "bônus de 2 peças do conjunto (+15 vida)")
	eq(int(Inventory.set_counts(p)["vigia_noturno"]), 2, "contagem do conjunto")


func test_social() -> void:
	var w := WorldGenerator.generate(55, DB)
	var soc := SocialSystem.create(w, 55, DB)
	check(soc["npcs"].size() >= 2, "NPCs gerados nos hubs")
	var npc_id: String = soc["npcs"].keys()[0]
	var npc: Dictionary = soc["npcs"][npc_id]
	var liked: String = npc["likes"][0]
	var before := int(npc["affinity"])
	eq(SocialSystem.give_gift(soc, npc_id, liked), 10, "presente favorito")
	eq(SocialSystem.give_gift(soc, npc_id, liked), 0, "um presente por dia")
	eq(int(npc["affinity"]), before + 10, "afinidade subiu")
	# missões por reputação
	var region: String = npc["region"]
	soc["reputation"]["global"] = -80
	soc["reputation"]["regions"][region] = -80
	for q in SocialSystem.quest_offers(soc, w, npc_id, DB, 55):
		check(int(q["rep"]) <= 3, "reputação baixa => só trabalhos sujos/favores (%s)" % q["template"])
	soc["reputation"]["global"] = 80
	soc["reputation"]["regions"][region] = 80
	for q in SocialSystem.quest_offers(soc, w, npc_id, DB, 55):
		check(int(q["rep"]) >= 0, "reputação alta => missões oficiais (%s)" % q["template"])


func test_casamento_e_cerco() -> void:
	var w := WorldGenerator.generate(56, DB)
	var soc := SocialSystem.create(w, 56, DB)
	var p := _profile()
	var target := ""
	for n in soc["npcs"].values():
		if n["romanceable"]:
			target = n["id"]
			break
	check(target != "", "há NPC romanceável")
	check(SocialSystem.marriage_block_reason(soc, target, p) != "", "sem afinidade não casa")
	soc["npcs"][target]["affinity"] = 90
	check(SocialSystem.marriage_block_reason(soc, target, p) != "", "sem anel não casa")
	Inventory.add(p, "anel_compromisso")
	eq(SocialSystem.marriage_block_reason(soc, target, p), "", "pode casar")
	check(SocialSystem.marry(soc, target, p), "casou")
	eq(SocialSystem.rescue_candidate(soc, "qualquer"), target, "cônjuge salva em qualquer lugar")
	# escolhe defender uma região que NÃO é a do cônjuge
	var spouse_region: String = soc["npcs"][target]["region"]
	var chosen := ""
	for rid in w["regions"].keys():
		if rid != spouse_region and w["regions"][rid]["dimension"] == "prima":
			chosen = rid
			break
	var summary := SocialSystem.apply_siege(w, soc, chosen)
	check(summary["spouse_lost"], "cônjuge perdido no Cerco")
	eq(soc["spouse"], "", "casamento desfeito")
	for rid in w["regions"].keys():
		eq(w["regions"][rid]["destroyed"], rid != chosen, "só a escolhida sobrevive: " + rid)
	for n in soc["npcs"].values():
		eq(n["alive"], n["region"] == chosen, "NPC %s" % n["name"])
