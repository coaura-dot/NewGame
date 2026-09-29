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


func _wall(x: float, y_top: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, h)
	cs.shape = r
	cs.position = Vector2(x + 8, y_top + h * 0.5)
	body.add_child(cs)
	_root.add_child(body)


func test_parede_recarrega_dash() -> void:
	var p := await _setup()
	var wx := p.global_position.x + 20.0
	_wall(wx, -200.0, 200.0)
	await _frames(4)
	# no ar, sem dash, encostando na parede => recarrega
	p.global_position = Vector2(wx - 4.0, -150.0)
	p._prev_pos = p.global_position
	p.velocity = Vector2.ZERO
	p.dashes = 0
	p.dash_refill_cd = 0.0
	Input.action_press("move_right")
	await _frames(4)
	check(not p.grounded(), "no ar encostado na parede")
	check(p.dashes >= 1, "encostar na parede recarrega o dash")
	# gasta o dash ainda grudado: não recarrega de novo sem sair da parede
	p.dashes = 0
	await _frames(6)
	check(p.dashes == 0, "só recarrega uma vez por toque")
	# salto de parede (sai) e volta: recarrega de novo
	p.coyote_t = 0.0
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(24)
	var recharged := false
	for i in 60:
		await _frames(1)
		if p.dashes >= 1:
			recharged = true
			break
		if p.grounded():
			break
	Input.action_release("move_right")
	check(recharged, "saiu e voltou para a parede: recarrega de novo")
	await _teardown()


func test_chute_de_parede() -> void:
	var p := await _setup()
	var wx := p.global_position.x + 30.0
	_wall(wx, -200.0, 200.0)
	await _frames(4)
	p.global_position = Vector2(wx - 20.0, -60.0)
	p._prev_pos = p.global_position
	p.velocity = Vector2.ZERO
	p.dashes = 1
	p.facing = 1
	Input.action_press("move_right")
	await _frames(1)
	Input.action_press("dash")
	for i in 30:
		await _frames(1)
		if p._wall_at(1, 2):
			break
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("move_right")
	var vx := p.velocity.x
	print("    chute de parede: vx %.0f, vy %.0f, dashes %d" % [vx, p.velocity.y, p.dashes])
	check(vx <= -150.0, "dash + pulo na parede chuta para longe (%.0f)" % vx)
	check(p.velocity.y < -80.0, "chute de parede sobe")
	check(p.dashes >= 1, "chute de parede recarrega o dash")
	await _frames(60)
	await _teardown()


func test_renasce_visivel() -> void:
	var p := await _setup()
	await _frames(5)
	var at := p.global_position
	p.invuln_time = 0.0
	p.take_status_damage(9999.0, "teste")
	await _frames(40)
	check(p.dead, "herói morreu")
	p.revive(at)
	for i in 200:
		await _frames(1)
	var dis: float = float(p._mat.get_shader_parameter("dissolve")) if p._mat else 0.0
	check(not p.dead and p.rig.modulate.a > 0.99 and dis < 0.01, "depois de renascer o herói aparece (alpha %.2f, dissolve %.2f)" % [p.rig.modulate.a, dis])
	await _teardown()


## Pavio: a chama apaga na morte, reacende ao renascer, encolhe com pouca
## vida e deita contra o movimento; todo quadro tem as âncoras novas.
func test_chama_do_pavio() -> void:
	var p := await _setup()
	await _frames(5)
	var meta: Dictionary = HeroRig._meta
	for fname in meta.get("frames", {}).keys():
		var m: Dictionary = meta["frames"][fname]
		check(m.has("flame") and m.has("cheeks") and m.has("collar"), "quadro %s tem chama, bochechas e gola" % fname)
		if fname != "dead":
			eq(m["cheeks"].size(), 2, "quadro %s tem as duas bochechas" % fname)
	var full := p.rig._flame_height()
	p.hp = p.max_hp() * 0.1
	await _frames(3)
	check(p.rig._flame_height() < full - 1.0, "chama menor com pouca vida (%.1f < %.1f)" % [p.rig._flame_height(), full])
	p.hp = p.max_hp()
	p.velocity = Vector2(200, 0)
	p.rig.motion = Vector2(200, 0)
	for i in 20:
		await tree.process_frame
	check(p.rig._flame_lean * p.facing < -1.0, "chama deita para trás correndo (lean %.1f)" % p.rig._flame_lean)
	var at := p.global_position
	p.invuln_time = 0.0
	p.take_status_damage(9999.0, "teste")
	await _frames(30)
	check(p.dead and p.rig.lit == 0.0 and p.rig._flame_height() == 0.0, "chama apaga na morte")
	p.revive(at)
	await _frames(3)
	check(p.rig.lit == 1.0 and p.rig._flame_height() > 2.0, "chama reacende ao renascer")
	await _teardown()


## Duelo: telegrafia amarela antes do golpe, janela de punição depois,
## guarda contra spam (bloqueia leve, pesado quebra) e contra-golpe do aparo.
func test_duelo_esqueleto() -> void:
	var p := await _setup()
	p.invuln_time = 99.0
	var en := Enemy.new()
	en.setup("skeleton", 2)
	en.position = p.global_position + Vector2(40, -2)
	_root.add_child(en)
	await _frames(2)
	en.stats.set_source("teste", {"max_hp": 5000.0})
	en.hp = en.max_hp()
	var saw_warn := false
	var saw_punish := false
	var saw_red_or_combo := false
	var states := {}
	for i in 900:
		await _frames(1)
		states[en.ai_state] = true
		if en.ai_state.ends_with("windup") and en.emote.kind in ["warn", "danger"]:
			saw_warn = true
		if en.ai_state == "combo_windup" or en.tele_red:
			saw_red_or_combo = true
		if en.punish_t > 0.0:
			saw_punish = true
		if saw_warn and saw_punish and saw_red_or_combo:
			break
	print("    estados do esqueleto: %s" % str(states.keys()))
	check(saw_warn, "esqueleto telegrafa (! amarelo ou !! vermelho) antes de golpear")
	check(saw_punish, "depois do golpe abre a janela de punição")
	check(saw_red_or_combo, "tier 2 faz combos / golpe vermelho")
	# guarda: 2 golpes leves seguidos fora da janela
	en.ai_state = "chase"
	en.punish_t = 0.0
	en.riposte_t = 0.0
	en.stagger_time = 0.0
	en.attack.cancel()
	en.facing = -1
	var light := DamageInfo.new()
	light.amount = 1.0
	light.source = p
	light.team = p.team
	light.direction = Vector2(1, 0)
	for k in en.guard_threshold:
		en.invuln_time = 0.0
		en.take_hit(light.duplicate_info())
	eq(en.ai_state, "guard", "apanhar seguido faz erguer a guarda")
	en.invuln_time = 0.0
	eq(en.take_hit(light.duplicate_info()), DamageInfo.Result.BLOCKED, "guarda bloqueia golpe leve de frente")
	var back := light.duplicate_info()
	back.direction = Vector2(-1, 0)
	en.invuln_time = 0.0
	check(en.take_hit(back) != DamageInfo.Result.BLOCKED, "golpe pelas costas passa pela guarda")
	en.ai_state = "guard"
	var heavy := light.duplicate_info()
	heavy.is_heavy = true
	en.invuln_time = 0.0
	var hp0 := en.hp
	en.take_hit(heavy)
	check(en.hp < hp0 and en.punish_t > 0.0 and en.ai_state != "guard", "golpe pesado quebra a guarda e abre a janela")
	# aparo perfeito -> contra-golpe crítico
	en.on_parried(p, true)
	check(en.riposte_t > 0.0, "aparo perfeito libera o contra-golpe")
	var riposte := light.duplicate_info()
	riposte.amount = 10.0
	en.invuln_time = 0.0
	hp0 = en.hp
	en.take_hit(riposte)
	check(riposte.is_crit and hp0 - en.hp > 10.0 * 1.2 and en.riposte_t == 0.0, "contra-golpe é crítico e mais forte (%.1f)" % (hp0 - en.hp))
	await _teardown()


## Fim do combo no chão: um respiro antes de recomeçar (sem spam infinito).
func test_respiro_do_combo() -> void:
	var p := await _setup()
	var starts := [0] # array: lambdas capturam variáveis locais por valor
	p.attack.started.connect(func(_s, _k): starts[0] += 1)
	# segura o golpe pressionando a cada 2 quadros por 0,6 s
	for i in 72:
		if i % 2 == 0:
			Input.action_press("attack")
		else:
			Input.action_release("attack")
		await _frames(1)
	Input.action_release("attack")
	print("    golpes em 0,6 s martelando: %d" % starts[0])
	check(starts[0] >= 3 and starts[0] <= 5, "combo de 3 + respiro (golpes: %d)" % starts[0])
	await _teardown()


## Inimigos novos: mariposa circula e mergulha; Guarda bloqueia de frente e
## o pesado quebra o escudo; Sopro sopra uma rajada que empurra o herói.
func test_inimigos_novos() -> void:
	var p := await _setup()
	p.invuln_time = 0.0
	# --- mariposa ---
	var m := Enemy.new()
	m.setup("moth", 1)
	m.position = p.global_position + Vector2(40, -30)
	_root.add_child(m)
	var states := {}
	for i in 600:
		await _frames(1)
		p.invuln_time = 99.0
		states[m.ai_state] = true
		if states.has("dive") and states.has("recover"):
			break
	print("    mariposa: %s" % str(states.keys()))
	check(states.has("chase") and states.has("windup") and states.has("dive"), "mariposa circula, avisa e mergulha")
	m.queue_free()
	# --- Guarda de Cinzas ---
	var k := Enemy.new()
	k.setup("ash_knight", 2)
	k.position = p.global_position + Vector2(60, -2)
	_root.add_child(k)
	await _frames(3)
	k.stats.set_source("teste", {"max_hp": 5000.0})
	k.hp = k.max_hp()
	k.ai_state = "chase"
	k.facing = -1
	var light := DamageInfo.new()
	light.amount = 5.0
	light.source = p
	light.team = p.team
	light.direction = Vector2(1, 0)
	k.invuln_time = 0.0
	eq(k.take_hit(light.duplicate_info()), DamageInfo.Result.BLOCKED, "Guarda bloqueia golpe leve de frente")
	var pogo := light.duplicate_info()
	pogo.pogo = true
	pogo.direction = Vector2(0, 1)
	k.invuln_time = 0.0
	check(k.take_hit(pogo) != DamageInfo.Result.BLOCKED, "pogo por cima passa pelo escudo")
	k.ai_state = "chase"
	k.stagger_time = 0.0
	var heavy := light.duplicate_info()
	heavy.is_heavy = true
	k.invuln_time = 0.0
	var hp0 := k.hp
	k.take_hit(heavy)
	check(k.hp < hp0 and k._shield_broken > 0.0 and k.punish_t > 0.0, "golpe pesado quebra o escudo e abre a janela")
	# ataca: escudada e estocada
	k._shield_broken = 0.0
	k.ai_state = "chase"
	k.stagger_time = 0.0
	k.punish_t = 0.0
	var kst := {}
	for i in 600:
		await _frames(1)
		p.invuln_time = 99.0
		kst[k.ai_state] = true
		if kst.has("thrust"):
			break
	print("    guarda: %s" % str(kst.keys()))
	check(kst.has("bash") and kst.has("thrust"), "Guarda faz escudada e emenda a estocada")
	k.queue_free()
	# --- Sopro ---
	await _frames(2)
	p.invuln_time = 0.0
	p.hp = p.max_hp()
	var g := Enemy.new()
	g.setup("gust", 2)
	g.position = p.global_position + Vector2(60, -10)
	_root.add_child(g)
	var x0 := p.global_position.x
	var shots := 0
	var pushed := false
	for i in 900:
		await _frames(1)
		for c in _root.get_children():
			if c is GustShot:
				shots = maxi(shots, 1)
		if p.hp < p.max_hp() and x0 - p.global_position.x > 12.0:
			pushed = true
			break
	check(shots > 0, "Sopro sopra uma rajada")
	check(pushed, "rajada acerta e empurra o herói para longe (%.0f px)" % (x0 - p.global_position.x))
	g.queue_free()
	await _teardown()
