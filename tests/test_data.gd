extends "res://tests/test_case.gd"
## Dados: validação cruzada e orçamento de poder (balanceamento).


func test_db_sem_erros() -> void:
	check(DB.errors.is_empty(), "DB com erros: " + ", ".join(DB.errors))
	check(DB.weapons.size() >= 10, "poucas armas")
	check(DB.spells.size() >= 15, "poucas magias")
	check(DB.armor.size() >= 30, "armaduras geradas")


func test_armas_no_orcamento() -> void:
	var lines := []
	for id in DB.weapons.keys():
		var sc := PowerBudget.weapon_score(id, DB)
		lines.append("%s=%.1f(T%d)" % [id, sc, int(DB.weapon(id).get("tier", 1))])
		check(PowerBudget.weapon_in_budget(id, DB), "arma fora do orçamento: %s %.1f" % [id, sc])
	print("    armas: " + ", ".join(lines))


func test_magias_no_orcamento() -> void:
	var lines := []
	for id in DB.spells.keys():
		var sc := PowerBudget.spell_score(id, DB)
		lines.append("%s=%.1f(T%d)" % [id, sc, int(DB.spell(id).get("tier", 1))])
		check(PowerBudget.spell_in_budget(id, DB), "magia fora do orçamento: %s %.1f" % [id, sc])
	print("    magias: " + ", ".join(lines))


func test_upgrade_nao_quebra_tier_acima() -> void:
	# magia no nível máximo não pode passar do teto do tier seguinte
	for id in DB.spells.keys():
		var tier := int(DB.spell(id).get("tier", 1))
		var cap: Vector2 = PowerBudget.SPELL_BUDGET.get(mini(tier + 1, 3), Vector2(0, 999))
		var sc := PowerBudget.spell_score(id, DB, Inventory.MAX_SPELL_LEVEL)
		check(sc <= cap.y * 1.35, "magia %s no nível máximo forte demais: %.1f" % [id, sc])


func test_trilhas_de_musica() -> void:
	for id in DB.biomes.keys():
		var track: String = DB.biome(id).get("music", "")
		check(Music.has_track(track), "bioma %s sem trilha (%s)" % [id, track])
	for t in ["menu", "vila", "chefe", "dimensao", "cerco"]:
		check(Music.has_track(t), "trilha %s existe" % t)


func test_forja_nao_quebra_tier_acima() -> void:
	# arma forjada no nível máximo não pode passar do teto do tier seguinte
	for id in DB.weapons.keys():
		var tier := int(DB.weapon(id).get("tier", 1))
		var cap: Vector2 = PowerBudget.WEAPON_BUDGET.get(mini(tier + 1, 3), Vector2(0, 999))
		var sc := PowerBudget.weapon_score(id, DB) * Commerce.weapon_mult(Commerce.MAX_WEAPON_LEVEL)
		check(sc <= cap.y * 1.35, "arma %s forjada no máximo forte demais: %.1f" % [id, sc])


func test_inimigos_usam_pool_do_jogador() -> void:
	for id in DB.enemies.keys():
		var lo: Dictionary = DB.enemy(id).get("loadout", {})
		if lo.get("weapon", "") != "":
			eq(DB.kind_of(lo["weapon"]), "weapon", "arma de %s" % id)
		for s in lo.get("spells", []):
			eq(DB.kind_of(s), "spell", "magia de %s" % id)
		var score := PowerBudget.loadout_score(id, DB)
		var tier := int(DB.enemy(id).get("tier", 1))
		check(score <= 60.0 + tier * 30.0, "loadout de %s forte demais (%.1f)" % [id, score])


func test_drops_exclusivos() -> void:
	var ex: String = DB.weapon("cutelo_arquidemonio").get("exclusive_to", "")
	eq(ex, "archdemon", "cutelo exclusivo do arquidemônio")
	var rng := RngUtil.make(1, "loot")
	for i in 400:
		check(LevelGenerator.roll_loot(rng, DB, 3, true) != "cutelo_arquidemonio", "item exclusivo apareceu em baú")
