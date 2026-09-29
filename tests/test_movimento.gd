extends "res://tests/test_case.gd"
## Mede o movimento REAL do herói no motor (pulo, alcance, dash) numa sala de
## teste com chão plano, e confere que o validador de salas (RoomReach) usa
## números que o herói de fato alcança — nada de sala "impossível".

var _root: Node2D


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "attack"]:
		Input.action_release(a)


func _setup() -> Player:
	_root = Node2D.new()
	tree.root.add_child(_root)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = Layers.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(4000, 16)
	cs.shape = r
	cs.position = Vector2(0, 8)
	floor_body.add_child(cs)
	_root.add_child(floor_body)
	FX.effects_root = _root
	var p := Player.new()
	p.position = Vector2(-1500, 0)
	_root.add_child(p)
	await _frames(6)
	return p


func _teardown() -> void:
	_release_all()
	_root.queue_free()
	await _frames(2)
	FX.clear_time_effects()


func test_pulo_e_alcance() -> void:
	var p := await _setup()
	check(p.grounded(), "herói no chão da sala de teste")
	# altura máxima segurando o pulo
	var y0 := p.global_position.y
	Input.action_press("jump")
	var min_y := y0
	for i in 90:
		await _frames(1)
		min_y = minf(min_y, p.global_position.y)
	Input.action_release("jump")
	await _frames(40)
	var height := y0 - min_y
	print("    pulo: %.1f px (%.2f tiles)" % [height, height / 8.0])
	check(height >= 26.0, "pulo alcança pelo menos 3.25 tiles (%.1f px)" % height)
	check(height <= 40.0, "pulo não exagerado (%.1f px)" % height)
	# alcance horizontal: correndo no máximo, pula e mede até voltar à altura inicial
	Input.action_press("move_right")
	await _frames(60)
	var x0 := p.global_position.x
	Input.action_press("jump")
	var landed_x := x0
	var airborne := false
	for i in 150:
		await _frames(1)
		if not p.grounded():
			airborne = true
		elif airborne:
			landed_x = p.global_position.x
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	var reach := landed_x - x0
	print("    alcance do pulo correndo: %.1f px (%.2f tiles)" % [reach, reach / 8.0])
	check(reach >= 56.0, "pulo correndo cruza pelo menos 7 tiles (%.1f px)" % reach)
	await _teardown()


func test_dash_e_super() -> void:
	var p := await _setup()
	await _frames(20)
	# dash horizontal parado
	var x0 := p.global_position.x
	Input.action_press("move_right")
	await _frames(1)
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	await _frames(30)
	Input.action_release("move_right")
	var dist := p.global_position.x - x0
	print("    dash + corrida (0.25 s): %.1f px" % dist)
	check(dist >= 48.0, "dash cobre boa distância (%.1f px)" % dist)
	await _frames(40)
	# super: dash no chão + pulo durante o dash => muito embalo
	Input.action_press("move_right")
	await _frames(1)
	Input.action_press("dash")
	await _frames(3)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("dash")
	var vx := p.velocity.x
	print("    velocidade após super: %.1f px/s" % vx)
	check(vx >= 200.0, "super mantém o embalo (%.1f px/s)" % vx)
	await _frames(60)
	await _teardown()


func test_validador_usa_numeros_reais() -> void:
	# o validador (em tiles) não pode exigir mais do que o herói faz
	var cap: Dictionary = RoomReach.CAPS["jump"]
	check(int(cap["up"]) * 8 <= 26, "subida exigida pelo validador <= pulo real")
	check(int(cap["reach"][0]) * 8 <= 56, "alcance exigido pelo validador <= pulo real")


func test_orbe_de_impulso() -> void:
	var p := await _setup()
	await _frames(10)
	p.facing = 1
	p.dashes = 0
	var orb := ImpulseOrb.new()
	orb.position = p.global_position + Vector2(10, -6)
	_root.add_child(orb)
	await _frames(4)
	var y0 := p.global_position.y
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	var min_y := y0
	for i in 40:
		await _frames(1)
		min_y = minf(min_y, p.global_position.y)
	print("    quique no orbe: %.1f px" % (y0 - min_y))
	check(y0 - min_y >= 28.0, "golpear o orbe quica ~4 tiles (%.1f px)" % (y0 - min_y))
	check(p.dashes >= 1, "orbe recarrega o dash")
	await _teardown()


func test_plataforma_movel_carrega() -> void:
	var p := await _setup()
	var mp := MovingPlatform.new()
	mp.travel = Vector2(40, 0)
	mp.period = 2.0
	mp.position = Vector2(-1452, -40)
	_root.add_child(mp)
	p.global_position = Vector2(-1440, -40)
	p._prev_pos = p.global_position
	p.velocity = Vector2.ZERO
	await _frames(3)
	var x0 := p.global_position.x
	var px0 := mp.position.x
	await _frames(60)
	var moved := p.global_position.x - x0
	var pm := mp.position.x - px0
	print("    plataforma andou %.0f px, herói andou %.0f px" % [pm, moved])
	check(p.grounded(), "herói continua em cima da plataforma")
	check(absf(moved - pm) <= 1.0 and pm > 10.0, "herói anda junto com a plataforma")
	await _teardown()


func test_mergulhador_da_rasante() -> void:
	var p := await _setup()
	p.invuln_time = 99.0
	var en := Enemy.new()
	en.setup("fire_skull", 1)
	en.position = p.global_position + Vector2(50, -30)
	_root.add_child(en)
	var states := {}
	for i in 360:
		await _frames(1)
		states[en.ai_state] = true
	print("    estados do mergulhador: %s" % str(states.keys()))
	check(states.has("chase"), "mergulhador persegue")
	check(states.has("dive"), "mergulhador dá o rasante")
	await _teardown()


func test_pogo_nos_espinhos() -> void:
	var p := await _setup()
	var hz := Hazard.new()
	hz.add_rect(Rect2(-8, -5, 16, 5))
	hz.position = p.global_position
	_root.add_child(hz)
	p.invuln_time = 99.0
	p.global_position += Vector2(0, -24)
	p._prev_pos = p.global_position
	p.on_ground = false
	p.dashes = 0
	Input.action_press("move_down")
	var bounced := false
	for i in 60:
		await _frames(1)
		if i == 8:
			Input.action_press("attack")
		if i == 10:
			Input.action_release("attack")
		if p.velocity.y < -100.0:
			bounced = true
			break
	Input.action_release("move_down")
	check(bounced, "golpe para baixo quica nos espinhos")
	check(p.dashes >= 1, "pogo recarrega o dash")
	await _teardown()


func test_torreta_rebater() -> void:
	var p := await _setup()
	p.invuln_time = 99.0
	await _frames(10)
	p.facing = 1
	var tu := Turret.new()
	tu.dir = Vector2.LEFT
	tu.period = 0.5
	tu.phase = 0.9
	tu.position = p.global_position + Vector2(60, -6)
	_root.add_child(tu)
	var count := [0]
	p.attack.hitbox.projectile_reflected.connect(func(_pr): count[0] += 1)
	# golpeia quando a bala chega perto
	for i in 240:
		await _frames(1)
		var near := false
		for n in _root.get_children():
			if n is Projectile and n.team != p.team and n.global_position.x - p.global_position.x < 30.0:
				near = true
		if near:
			Input.action_press("attack")
			await _frames(2)
			Input.action_release("attack")
			await _frames(10)
			break
	check(count[0] >= 1, "golpe rebate a bala da torreta")
	for i in 90:
		await _frames(1)
		if tu._broken:
			break
	check(tu._broken, "bala rebatida volta e quebra a torreta")
	await _teardown()


func test_muralha_da_fuga() -> void:
	var p := await _setup()
	await _frames(10)
	var start := p.global_position
	p.hazard_spawn_override = start
	var wall := ChaseWall.new()
	wall.rect = Rect2(start.x - 60.0, start.y - 150.0, 320.0, 180.0)
	wall.dir = 1
	wall.player = p
	_root.add_child(wall)
	var hp0: float = p.hp
	var caught := false
	for i in 480:
		await _frames(1)
		if p.state == Player.State.RESPAWN or p.hp < hp0:
			caught = true
			break
	check(caught, "muralha alcança quem fica parado")
	await _frames(60)
	check(wall.front < start.x - 40.0, "muralha recomeça atrás do herói depois do tombo (%.0f)" % (wall.front - start.x))
	# correndo, o herói escapa
	wall.reset()
	Input.action_press("move_right")
	var hp1: float = p.hp
	for i in 360:
		await _frames(1)
	Input.action_release("move_right")
	check(p.hp >= hp1, "correndo sem parar, a muralha não alcança")
	await _teardown()


func test_resets_no_ar() -> void:
	var p := await _setup()
	await _frames(10)
	# pena: encostar no ar dá um pulo extra (mesmo sem pulo duplo)
	p.global_position += Vector2(0, -40)
	p._prev_pos = p.global_position
	p.on_ground = false
	var jf := JumpFeather.new()
	jf.position = p.global_position + Vector2(0, -6)
	_root.add_child(jf)
	await _frames(3)
	check(p.bonus_jumps == 1, "pena dá um pulo extra")
	p.coyote_t = 0.0
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	check(p.velocity.y < -60.0 and p.bonus_jumps == 0, "pulo extra usado no ar")
	await _frames(90)
	# cristal duplo: 2 dashes
	p.global_position += Vector2(0, -40)
	p._prev_pos = p.global_position
	p.on_ground = false
	p.dashes = 0
	var dc := DashCrystal.new()
	dc.double = true
	dc.position = p.global_position + Vector2(0, -6)
	_root.add_child(dc)
	await _frames(3)
	check(p.dashes == 2, "cristal duplo dá 2 dashes (%d)" % p.dashes)
	await _frames(90)
	# sino: golpear recarrega dash e dá pulo, e conta na cadeia
	p.dashes = 0
	p.global_position += Vector2(0, -30)
	p._prev_pos = p.global_position
	p.on_ground = false
	p.facing = 1
	var bell := ResetBell.new()
	bell.position = p.global_position + Vector2(10, -6)
	_root.add_child(bell)
	await _frames(2)
	var chain0: int = p.air_chain
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	await _frames(4)
	check(p.dashes >= 1 and p.bonus_jumps == 1, "sino recarrega dash e dá pulo extra")
	check(p.air_chain > chain0, "sino soma na cadeia aérea")
	await _teardown()


func test_embalo_no_ar() -> void:
	var p := await _setup()
	await _frames(20)
	# super e solta tudo: no ar o embalo deve durar (inércia)
	Input.action_press("move_right")
	await _frames(1)
	Input.action_press("dash")
	await _frames(3)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("dash")
	Input.action_release("move_right")
	await _frames(20)
	var vx := p.velocity.x
	Input.action_release("jump")
	print("    embalo 0,17 s depois do super, sem segurar nada: %.0f px/s" % vx)
	check(not p.grounded(), "ainda no ar")
	check(vx >= 180.0, "embalo no ar se mantém (%.0f px/s)" % vx)
	await _frames(80)
	await _teardown()
