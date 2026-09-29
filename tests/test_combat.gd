extends "res://tests/test_case.gd"
## Fórmulas, status e sigilos.


func test_fraquezas() -> void:
	var info := DamageInfo.new()
	info.amount = 10.0
	info.damage_type = "blunt"
	var prof: Dictionary = DB.enemy("skeleton")
	near(CombatMath.resolve(info, null, null, prof), 16.0, 0.01, "esqueleto fraco contra impacto")
	info.damage_type = "pierce"
	near(CombatMath.resolve(info, null, null, prof), 6.0, 0.01, "esqueleto resiste a perfuração")
	info.damage_type = "slash"
	info.weapon_class = "greatsword"
	near(CombatMath.resolve(info, null, null, prof), 13.0, 0.01, "fraqueza por classe de arma")
	info.weapon_class = ""
	info.damage_type = "fire"
	info.school = "fire"
	info.is_spell = true
	near(CombatMath.resolve(info, null, null, DB.enemy("fire_skull")), 0.0, 0.01, "crânio imune a fogo")


func test_defesa_e_marca() -> void:
	var info := DamageInfo.new()
	info.amount = 100.0
	var def := StatBlock.new({"defense": 10})
	near(CombatMath.resolve(info, null, def, {}), 70.0, 0.01, "defesa 10 = -30%")
	near(CombatMath.resolve(info, null, null, {}, true), 120.0, 0.01, "marca +20%")


func test_status_congela_e_hemorragia() -> void:
	var sc := StatusController.new(null)
	for i in 5:
		sc.add("chill", 1)
	check(sc.has("frozen"), "5 acúmulos de frio congelam")
	check(sc.disabled(), "congelado fica paralisado")
	var sc2 := StatusController.new(null)
	sc2.add("bleed", 9)
	check(sc2.has("bleed"), "9 sangramentos ainda acumulam")
	sc2.add("bleed", 1)
	check(not sc2.has("bleed"), "10 acúmulos => hemorragia consome os acúmulos")


func _shape(name: String, noise: float, rng: RandomNumberGenerator, scale: float = 80.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in SigilRecognizer.templates()[name]:
		out.append(Vector2(200, 130) + p * scale + Vector2(rng.randf_range(-noise, noise), rng.randf_range(-noise, noise)))
	return out


func test_sigilos() -> void:
	var rng := RngUtil.make(3, "sigil")
	for name in SigilRecognizer.templates().keys():
		var r := SigilRecognizer.recognize(_shape(name, 0.0, rng))
		eq(r["name"], name, "sigilo perfeito: " + name)
		check(r["accuracy"] > 0.95, "precisão alta para %s perfeito (%.2f)" % [name, r["accuracy"]])
		var noisy := SigilRecognizer.recognize(_shape(name, 7.0, rng))
		eq(noisy["name"], name, "sigilo tremido ainda reconhecido: " + name)
		check(noisy["accuracy"] < r["accuracy"], "tremido tem precisão menor: " + name)
	var scribble := PackedVector2Array()
	for i in 40:
		scribble.append(Vector2(rng.randf_range(0, 200), rng.randf_range(0, 200)))
	var bad := SigilRecognizer.recognize(scribble)
	check(bad["accuracy"] < 0.8, "rabisco aleatório tem precisão baixa (%.2f)" % bad["accuracy"])
	check(SigilRecognizer.power_from_accuracy(1.0) > SigilRecognizer.power_from_accuracy(0.6), "dano escala com precisão")


## Cada escola tem partículas próprias que aparecem e somem sozinhas.
func test_efeitos_por_escola() -> void:
	var root := Node2D.new()
	tree.root.add_child(root)
	var schools := ["fire", "ice", "lightning", "void", "gravity", "light", "heal", "earth", "water", "arcane", "time"]
	var styles := {}
	for sc in schools:
		SchoolFX.impact(root, sc, Vector2.ZERO, Vector2.UP, Color(2, 2, 2), 1.0)
		SchoolFX.trail(root, sc, Vector2.ZERO, Vector2.RIGHT * 100.0, Color(2, 2, 2))
		SchoolFX.cast(root, sc, Vector2.ZERO, Vector2.RIGHT, Color(2, 2, 2))
		styles[SchoolFX.style_of(sc)] = true
	check(styles.size() >= 9, "escolas com estilos diferentes (%d)" % styles.size())
	eq(SchoolFX.style_of("fire"), "ember", "fogo = brasas")
	eq(SchoolFX.style_of("ice"), "shard", "gelo = estilhaços")
	eq(SchoolFX.style_of("lightning"), "zig", "raio = zigue-zague")
	eq(SchoolFX.style_of("void"), "spiral", "sombra = espiral")
	eq(SchoolFX.style_of("heal"), "cross", "cura = cruzes")
	eq(SchoolFX.style_of("earth"), "rock", "terra = pedras")
	await tree.process_frame
	check(root.get_child_count() >= schools.size(), "partículas criadas (%d lotes)" % root.get_child_count())
	for i in 90:
		await tree.process_frame
	# os lotes duram < 1 s; dá margem ao tempo real do teste
	var t0 := Time.get_ticks_msec()
	while root.get_child_count() > 0 and Time.get_ticks_msec() - t0 < 2000:
		await tree.process_frame
	eq(root.get_child_count(), 0, "partículas somem sozinhas")
	root.queue_free()


## Guardiões: cada um roda o próprio padrão (prepara com telegrafia, ataca,
## fica exposto) sem travar, e a arena de quem anda não tem chão de espinhos.
func test_guardioes_duelam() -> void:
	for gid in ["raven_guardian", "spider_guardian", "hare_guardian", "golem_guardian", "mirror_guardian", "archdemon"]:
		check(not DB.enemy(gid).is_empty(), "guardião %s existe" % gid)
		var root := Node2D.new()
		tree.root.add_child(root)
		var floor_body := StaticBody2D.new()
		floor_body.collision_layer = Layers.WORLD
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(800, 16)
		cs.shape = r
		cs.position = Vector2(0, 8)
		floor_body.add_child(cs)
		root.add_child(floor_body)
		FX.effects_root = root
		var p := Player.new()
		p.position = Vector2(-40, 0)
		root.add_child(p)
		p.invuln_time = 999.0
		var en := Enemy.new()
		en.setup(gid, 2)
		en.position = Vector2(40, -30 if DB.enemy(gid).get("flying", false) else 0)
		root.add_child(en)
		var states := {}
		var moves := {}
		for i in 900:
			await tree.physics_frame
			p.invuln_time = 999.0
			states[en.ai_state] = true
			if en.brain and en.brain.last_id != "":
				moves[en.brain.last_id] = true
			if i == 450:
				en.hp = en.max_hp() * 0.4 # força a 2ª fase
		check(states.has("windup") and states.has("attack") and states.has("recover"), "%s prepara, ataca e se expõe (%s)" % [gid, str(states.keys())])
		check(moves.size() >= 2, "%s usa golpes variados (%s)" % [gid, str(moves.keys())])
		check(en.phase_idx >= 1, "%s entra na 2ª fase" % gid)
		root.queue_free()
		await tree.physics_frame
		await tree.physics_frame
		FX.clear_time_effects()


func test_guardiao_por_dom() -> void:
	for ab in WorldGenerator.GUARDIAN_OF.keys():
		var gid: String = WorldGenerator.GUARDIAN_OF[ab]
		check(not DB.enemy(gid).is_empty(), "guardião de %s existe" % ab)
		check(DB.enemy(gid).get("ai", "") == "guardian", "%s usa o motor de guardião" % gid)
	var rng := RandomNumberGenerator.new()
	for i in 20:
		rng.seed = 40 + i
		var g := RoomSynth.blank()
		RoomSynth.frame(g, "LR")
		RoomSynth._boss(g, rng, "LR", false)
		var spikes := 0
		for x in range(4, 36):
			if g[22][x] == "^":
				spikes += 1
		check(spikes == 0, "arena de chefe que anda não tem fosso de espinhos")
