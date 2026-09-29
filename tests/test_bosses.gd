extends "res://tests/test_case.gd"
## Chefes novos: cada um entra na sala com o jogador, age por alguns segundos
## (as mecânicas próprias precisam acontecer) e morre limpando a sala.


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _run_boss(id: String, frames: int) -> Dictionary:
	Game.pending = {"training": true}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(level)
	await _frames(20)
	Settings.data["gameplay"]["invincible"] = true
	var p: Player = level.player
	var room: int = level._current_room
	var boss: Enemy = level._make_enemy(id, 2, p.global_position + Vector2(60, -2), room)
	level.entities.add_child(boss)
	level.boss_node = boss
	var states := {}
	var seen := {"minions": 0, "shielded": false, "projectiles": 0, "attacked": false, "guard": false, "lowered": false}
	for i in frames:
		await _frames(1)
		if not is_instance_valid(boss):
			break
		states[boss.ai_state] = true
		seen["minions"] = maxi(seen["minions"], boss._minions.size())
		seen["shielded"] = seen["shielded"] or boss.shielded
		seen["projectiles"] = maxi(seen["projectiles"], tree.get_nodes_in_group("projectiles").size())
		seen["attacked"] = seen["attacked"] or boss.attack.is_busy()
		seen["guard"] = seen["guard"] or boss.ai_state == "guard"
		seen["lowered"] = seen["lowered"] or boss.lowered
		# ajuda o combate a andar: mata a ninhada de tempos em tempos
		if id == "brood_mother" and i % 150 == 149:
			for m in boss._minions:
				if is_instance_valid(m) and not m.dead:
					m.take_status_damage(9999.0, "fall")
	seen["states"] = states.keys()
	var minions: Array = boss._minions.duplicate() if is_instance_valid(boss) else []
	if is_instance_valid(boss):
		boss.take_status_damage(99999.0, "fall")
	await _frames(5)
	seen["boss_dead"] = not is_instance_valid(boss) or boss.dead
	var alive := 0
	for m in minions:
		if is_instance_valid(m) and not m.dead:
			alive += 1
	seen["minions_alive_after"] = alive
	Settings.data["gameplay"]["invincible"] = false
	level.queue_free()
	await _frames(2)
	Game.end_training()
	FX.clear_time_effects()
	return seen


func test_duelista() -> void:
	var s: Dictionary = await _run_boss("duelist", 420)
	check(s["states"].size() >= 3, "duelista varia de ação: %s" % str(s["states"]))
	check(s["attacked"], "duelista ataca")
	check(s["boss_dead"], "duelista morre")


func test_mae_da_ninhada() -> void:
	var s: Dictionary = await _run_boss("brood_mother", 420)
	check(s["minions"] >= 2, "invoca a ninhada (%d)" % s["minions"])
	check(s["shielded"], "fica protegida pelo escudo")
	check(s["states"].has("exposed"), "abre a guarda quando a onda cai: %s" % str(s["states"]))
	check(s["boss_dead"], "mãe morre")
	eq(s["minions_alive_after"], 0, "lacaios morrem junto com a mãe")


func test_colosso() -> void:
	var s: Dictionary = await _run_boss("colossus", 480)
	check(s["projectiles"] > 0, "pisão/pedras criam projéteis")
	check(s["states"].size() >= 3, "colosso varia de ação: %s" % str(s["states"]))
	check(s["boss_dead"], "colosso morre")


func test_mundo_distribui_chefes() -> void:
	var bosses := {}
	for sd in [3, 7, 11, 19, 23]:
		var w := WorldGenerator.generate(sd, DB)
		for r in w["regions"].values():
			if r.get("boss", "") != "":
				bosses[r["boss"]] = true
	for b in ["duelist", "brood_mother", "colossus"]:
		check(bosses.has(b), "chefe %s aparece no mundo" % b)


func test_arena_de_chefes() -> void:
	for id in ["colossus", "archdemon"]:
		Game.pending = {"training": true, "arena": id}
		var level: Node = load("res://scenes/level.tscn").instantiate()
		tree.root.add_child(level)
		await _frames(10)
		eq(level.layout["rooms"].size(), 3, "arena: entrada, chefe, saída")
		check(level.boss_node != null and level.boss_node.enemy_id == id, "arena gera o chefe escolhido: " + id)
		level.queue_free()
		await _frames(2)
		Game.end_training()
