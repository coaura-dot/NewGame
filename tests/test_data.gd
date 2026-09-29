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


## Trilha sonora: toda faixa usada pelo jogo existe, é OGG e toca em loop.
func test_trilha_sonora() -> void:
	for t in ["candelaria", "noite", "estrada", "frenesi", "guardiao", "lareira"]:
		var path := "res://assets/audio/music/%s.ogg" % t
		check(ResourceLoader.exists(path), "faixa %s existe" % t)
		var st = load(path)
		check(st is AudioStreamOggVorbis and st.get_length() > 15.0, "faixa %s é OGG com mais de 15 s" % t)
	Audio.music("estrada", 0.01)
	eq(Audio.music_track, "estrada", "Audio.music troca a faixa")
	var mp: AudioStreamPlayer = Audio._music[Audio._music_cur]
	check(mp.stream is AudioStreamOggVorbis and mp.stream.loop, "a faixa toca em loop")
	Audio.music("", 0.01)
	eq(Audio.music_track, "", "silêncio")


## História: todo inimigo tem uma página no Bestiário; todo guardião (e o
## Arquidemônio) tem as últimas palavras do zelador; 10 Lembranças.
func test_lore_das_criaturas() -> void:
	for id in DB.enemies.keys():
		if str(id).begins_with("_"):
			continue
		var e: Dictionary = DB.enemies[id]
		check(str(e.get("lore", "")).length() > 30, "%s tem história no bestiário" % id)
		if e.get("boss", false):
			check(Lore.KEEPER_WORDS.has(str(id)), "%s tem últimas palavras" % id)
	for gid in WorldGenerator.GUARDIAN_OF.values():
		check(Lore.KEEPER_WORDS.has(str(gid)), "guardião %s fala ao cair" % gid)
	check(Lore.MEMORIES.size() == 10, "10 Lembranças da Veladora")
	check(Lore.memory_title(2).begins_with("Lembrança III"), "título em romano")
	var prof := {}
	check(Lore.next_memory(prof) == 0, "primeira lembrança é a 0")
	prof["memories"] = [0, 1]
	check(Lore.next_memory(prof) == 2, "segue em ordem")


func test_bestiario() -> void:
	var prof := {}
	check(Bestiary.entries(prof, DB).is_empty(), "começa vazio")
	Bestiary.record(prof, "skeleton")
	var e: Array = Bestiary.entries(prof, DB)
	check(e.size() == 1 and e[0]["id"] == "skeleton", "1 abate registra a criatura")
	check(e[0]["lore"] != "" and e[0]["tip"] == "", "história já aparece; a dica ainda não")
	Bestiary.record(prof, "skeleton")
	Bestiary.record(prof, "skeleton")
	e = Bestiary.entries(prof, DB)
	check(int(e[0]["kills"]) == 3 and e[0]["tip"] != "" or str(DB.enemies["skeleton"].get("desc", "")) == "", "com 3 abates libera a anotação")
	check(Bestiary.total(DB) >= 20, "20+ criaturas para registrar")


func test_epilogo_pelas_lembrancas() -> void:
	var E = load("res://scripts/ui/ending.gd")
	check(E.epilogue(10, 10).contains("passa adiante"), "todas as lembranças: final verdadeiro")
	check(E.epilogue(5, 10).contains("lembranças esperando"), "metade: pista de que faltam")
	check(E.epilogue(0, 10).contains("Candelária"), "nenhuma: epílogo simples")
