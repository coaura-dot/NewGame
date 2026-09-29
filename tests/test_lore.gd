extends "res://tests/test_case.gd"
## História: abertura, inscrições por bioma, títulos de chefes, códice.


func test_lore_completa() -> void:
	var lore: Dictionary = DB.lore
	check(lore.get("intro", []).size() >= 5, "abertura com quadros")
	for b in DB.biomes.keys():
		check(lore.get("biomes", {}).get(b, []).size() >= 3, "inscrições do bioma %s" % b)
	for id in DB.enemies.keys():
		if DB.enemy(id).get("boss", false) or id == "nightmare":
			check(lore.get("bosses", {}).has(id), "título do chefe %s" % id)
	for d in DB.dimensions.keys():
		if d != "prima":
			check(lore.get("dimensions", {}).has(d), "lore do Reflexo %s" % d)


func test_inscricoes_nas_fases() -> void:
	var lib := ChunkLibrary.new()
	var total := 0
	for s in [3, 4, 5]:
		var lay := LevelGenerator.generate({"seed": s, "biome": "floresta", "tier": 1, "ports": [{"dir": "R", "to": "x", "requires": ""}]}, lib, DB)
		for e in lay["entities"]:
			if e["type"] == "inscription":
				total += 1
				check(e["data"].get("biome", "") == "floresta", "inscrição do bioma certo")
	check(total >= 3, "inscrições espalhadas (%d)" % total)
