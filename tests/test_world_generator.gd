extends "res://tests/test_case.gd"
## Mapa-múndi: conexo, completável, determinístico.


func test_varias_seeds() -> void:
	for s in range(1, 41):
		var w := WorldGenerator.generate(s, DB)
		check(w["regions"].size() >= 14, "seed %d: poucas regiões" % s)
		var all_ab: Array = DB.abilities.keys()
		eq(WorldGenerator.reachable(w, all_ab).size(), w["regions"].size(), "seed %d: grafo conexo" % s)
		var start_ab := []
		for a in DB.abilities.keys():
			if DB.abilities[a].get("start", false):
				start_ab.append(a)
		check(WorldGenerator.is_completable(w, start_ab), "seed %d: progressão impossível" % s)
		check(w["regions"][w["start"]]["hub"] != "", "seed %d: início sem hub" % s)
		eq(w["regions"][w["finale"]]["boss"], "archdemon", "seed %d: chefe final" % s)
		var dims := 0
		for r in w["regions"].values():
			if r["dimension"] != "prima":
				dims += 1
		check(dims >= 2, "seed %d: mundos paralelos" % s)
		# no começo o jogador não alcança tudo (há gates)
		check(WorldGenerator.reachable(w, start_ab).size() < w["regions"].size(), "seed %d: nenhum gate" % s)


func test_deterministico() -> void:
	var a := JSON.stringify(WorldGenerator.generate(777, DB))
	var b := JSON.stringify(WorldGenerator.generate(777, DB))
	eq(a == b, true, "mesma seed gera o mesmo mundo")
	var c := JSON.stringify(WorldGenerator.generate(778, DB))
	check(a != c, "seeds diferentes geram mundos diferentes")
