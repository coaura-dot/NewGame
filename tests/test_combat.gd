extends TestCase
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
