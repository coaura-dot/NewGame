extends "res://tests/test_case.gd"
## Save/load preserva o mundo (fixo por seed) e o perfil.


func test_roundtrip() -> void:
	var had := Game.has_game
	var old_slot := Game.slot
	var backup := Game.to_dict() if had else {}
	Game.new_game(31337, 9)
	Inventory.add(Game.profile, "katana_rubra")
	Game.profile["currency"] = 123
	Game.save()
	var world_json := JSON.stringify(Game.world)
	Game.world = {}
	check(Game.load_game(9), "carregou")
	eq(Game.seed_value, 31337, "seed")
	eq(int(Game.profile["currency"]), 123, "brasas")
	check(Game.profile["weapons"].has("katana_rubra"), "arma no perfil")
	eq(Game.world["regions"].size(), JSON.parse_string(world_json)["regions"].size(), "mundo preservado")
	check(WorldGenerator.is_completable(Game.world, ["dash", "wall_jump"]), "mundo carregado continua válido")
	SaveSystem.delete_save(9)
	if had:
		Game.from_dict(backup)
	Game.has_game = had
	Game.slot = old_slot
