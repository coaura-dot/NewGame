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
	check(p.grounded(), "jogador nasce no chão")
	var x0 := p.global_position.x
	Input.action_press("move_right")
	await _frames(90)
	Input.action_release("move_right")
	check(p.global_position.x > x0 + 8.0, "anda para a direita (%.1f -> %.1f)" % [x0, p.global_position.x])
	await _frames(30)
	var y0 := p.global_position.y
	Input.action_press("jump")
	await _frames(14)
	check(p.global_position.y < y0 - 8.0, "pula (%.1f -> %.1f)" % [y0, p.global_position.y])
	Input.action_release("jump")
	await _frames(90)
	check(p.grounded(), "aterrissa")
	Input.action_press("dash")
	var dashed := false
	for k in 6:
		await _frames(1)
		if p.state == Player.State.DASH or p.dash_cd > 0.0:
			dashed = true
	Input.action_release("dash")
	check(dashed, "dash")
	await _frames(60)
	# combate: esqueleto logo à frente
	p.facing = 1
	var en: Enemy = level._make_enemy("skeleton", 1, p.global_position + Vector2(14, 0), -1)
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
	await _tap("spell_1", 2)
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
	proj.velocity = Vector2(-100, 0)
	proj.global_position = p.body_center() + Vector2(30, 0)
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


func test_ondas_da_arena() -> void:
	Game.pending = {"training": true}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(level)
	await _frames(10)
	check(not level._room_waves.is_empty(), "treino tem arena com ondas")
	if level._room_waves.is_empty():
		level.queue_free()
		await _frames(2)
		Game.end_training()
		return
	var room: int = level._room_waves.keys()[0]
	var waves_before: int = level._room_waves[room].size()
	level.player.invuln_time = 99.0
	for en in level._room_enemies[room]:
		if is_instance_valid(en) and en.is_inside_tree() and not en.dead:
			var info := DamageInfo.new()
			en.hp = 0.0
			en._die(info)
	await _frames(240)
	var alive := 0
	for en in level._room_enemies[room]:
		if is_instance_valid(en) and en.is_inside_tree() and not en.dead:
			alive += 1
	check(alive > 0, "a próxima onda entra quando a anterior cai")
	check(level._room_waves.get(room, []).size() < waves_before, "consumiu uma onda")
	level.queue_free()
	await _frames(2)
	Game.end_training()
	FX.clear_time_effects()


## Treino: o poço é sala sombria. Entrar escurece; encostar numa lamparina
## acende, dá brasas e devolve parte da luz.
func test_lamparinas_no_treino() -> void:
	Game.pending = {"training": true}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	tree.root.add_child(level)
	await _frames(10)
	var p: Player = level.player
	var dark_idx := -1
	for r in level.layout["rooms"]:
		if r.get("dark", false):
			dark_idx = int(r["index"])
	check(dark_idx >= 0, "treino tem sala sombria")
	var lamps: Array = []
	for n in level.entities.get_children():
		if n is Lamparina and n.room_index == dark_idx:
			lamps.append(n)
	check(lamps.size() >= 2, "sala sombria tem lamparinas (%d)" % lamps.size())
	check(int(level.result["lamps_total"]) >= lamps.size(), "fase conta as lamparinas")
	if dark_idx < 0 or lamps.is_empty() or p == null:
		level.queue_free()
		await _frames(2)
		return
	var base: Color = level._ambient_base
	var lamp: Lamparina = lamps[0]
	p.global_position = lamp.global_position + Vector2(-30, 0)
	p._prev_pos = p.global_position
	p.velocity = Vector2.ZERO
	await _frames(70)
	check(level._current_room == dark_idx, "herói entrou na sala sombria")
	var dim: Color = level._ambient.color
	check(dim.r < base.r * 0.6, "sala sombria escurece a penumbra (%.2f < %.2f)" % [dim.r, base.r])
	check(p.dark_boost > 0.5, "a chama do Pavio alcança mais longe no escuro")
	var money := int(Game.profile.get("currency", 0))
	p.global_position = lamp.global_position
	p._prev_pos = p.global_position
	await _frames(6)
	check(lamp.lit, "encostar acende a lamparina")
	check(int(level.result["lamps"]) == 1, "fase conta a lamparina acesa")
	check(int(Game.profile.get("currency", 0)) == money + Lamparina.REWARD, "lamparina dá brasas")
	await _frames(90)
	check(level._ambient.color.r > dim.r + 0.02, "a sala clareia um pouco (%.2f > %.2f)" % [level._ambient.color.r, dim.r])
	# acender todas devolve a luz inteira
	for l in lamps:
		l.light_up()
	await _frames(100)
	check(absf(level._ambient.color.r - base.r) < 0.03, "todas acesas: luz da sala volta ao normal")
	# sala iluminada solta uma Lembrança da Veladora
	var wisp: MemoryWisp = null
	for n in level.entities.get_children():
		if n is MemoryWisp:
			wisp = n
	check(wisp != null, "sala iluminada solta uma Lembrança")
	if wisp:
		var before: int = Game.profile.get("memories", []).size()
		var expect := Lore.next_memory(Game.profile)
		p.global_position = wisp.global_position + Vector2(0, 6)
		p._prev_pos = p.global_position
		await _frames(4)
		check(Game.profile.get("memories", []).size() == before + 1, "encostar guarda a lembrança")
		check(expect < 0 or Game.profile["memories"].has(expect), "guarda a próxima lembrança em ordem")
		level.hud.close_panel()
	level.queue_free()
	await _frames(2)
	FX.clear_time_effects()
