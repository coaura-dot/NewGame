extends "res://tests/test_case.gd"
## Fumaça: carrega a fase de treino e joga com entradas simuladas.


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _tap(action: String, hold: int = 1) -> void:
	Input.action_press(action)
	await _frames(hold)
	Input.action_release(action)


func test_treino() -> void:
	Game.pending = {"training": true}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(level)
	await _frames(20)
	var p: Player = level.player
	check(p != null, "jogador existe")
	if p == null:
		return
	check(level.layout["rooms"].size() >= 8, "fase de treino gerada")
	check(p.is_on_floor(), "jogador nasce no chão")
	var x0 := p.global_position.x
	Input.action_press("move_right")
	await _frames(90)
	Input.action_release("move_right")
	check(p.global_position.x > x0 + 40.0, "anda para a direita (%.1f -> %.1f)" % [x0, p.global_position.x])
	await _frames(30)
	var y0 := p.global_position.y
	Input.action_press("jump")
	await _frames(14)
	check(p.global_position.y < y0 - 20.0, "pula (%.1f -> %.1f)" % [y0, p.global_position.y])
	Input.action_release("jump")
	await _frames(90)
	check(p.is_on_floor(), "aterrissa")
	Input.action_press("dash")
	var dashed := false
	for i in 4:
		await _frames(1)
		dashed = dashed or p.state == Player.State.DASH or p.dash_cd > 0.0
	Input.action_release("dash")
	check(dashed, "dash")
	await _frames(60)
	# combate: esqueleto logo à frente
	p.facing = 1
	var en: Enemy = level._make_enemy("skeleton", 1, p.global_position + Vector2(28, 0), -1)
	level.entities.add_child(en)
	await _frames(10)
	var hp0 := en.hp
	for i in 3:
		await _tap("attack")
		await _frames(24)
	check(en.hp < hp0 or en.dead, "ataque leve causa dano (%.1f -> %.1f)" % [hp0, en.hp])
	check(p.combo_count > 0 or en.dead, "combo conta acertos")
	# magia
	p.focus = p.max_focus()
	var before := tree.get_nodes_in_group("projectiles").size()
	Game.profile["spell_slots"] = ["chama", "passo_etereo"]
	await _tap("spell_1")
	await _frames(2)
	check(tree.get_nodes_in_group("projectiles").size() > before or p.focus < p.max_focus(), "Chama conjurada")
	# aparar um projétil inimigo
	await _frames(40)
	var hp_before := p.hp
	var proj := Projectile.new()
	proj.team = Layers.Team.ENEMY
	var info := DamageInfo.new()
	info.amount = 10.0
	info.team = Layers.Team.ENEMY
	proj.info = info
	proj.velocity = Vector2(-200, 0)
	proj.global_position = p.body_center() + Vector2(60, 0)
	level.entities.add_child(proj)
	await _frames(20)
	await _tap("parry")
	await _frames(30)
	check(p.hp >= hp_before, "aparar anulou o dano do projétil")
	# desenha um sigilo (círculo) e verifica o reconhecimento
	var pts := PackedVector2Array()
	for k in 33:
		pts.append(Vector2(240, 135) + Vector2.from_angle(-PI * 0.5 + TAU * k / 32.0) * 50.0)
	eq(SigilRecognizer.recognize(pts)["name"], "circle", "sigilo desenhado")
	level.queue_free()
	await _frames(2)
	Game.end_training()
	FX.clear_time_effects()


func test_regiao_real() -> void:
	var had := Game.has_game
	var backup := Game.to_dict() if had else {}
	var old_slot := Game.slot
	Game.new_game(99, 8)
	Game.pending = {"region": Game.world["start"]}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(level)
	await _frames(30)
	check(level.player != null and not level.player.dead, "região inicial carrega")
	var npcs := 0
	for n in level.entities.get_children():
		if n is NPCEntity:
			npcs += 1
	check(npcs > 0, "hub inicial tem NPCs")
	level.queue_free()
	await _frames(2)
	SaveSystem.delete_save(8)
	if had:
		Game.from_dict(backup)
	Game.has_game = had
	Game.slot = old_slot
	FX.clear_time_effects()
