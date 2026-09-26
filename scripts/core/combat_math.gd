class_name CombatMath
extends RefCounted
## Fórmulas de dano compartilhadas por jogador e inimigos.

## Multiplicador de fraqueza/resistência do alvo para um golpe.
static func weakness_multiplier(info: DamageInfo, profile: Dictionary) -> float:
	var weak: Dictionary = profile.get("weakness", {})
	var cls_weak: Dictionary = profile.get("class_weakness", {})
	var m := 1.0
	m *= float(weak.get(info.damage_type, 1.0))
	if info.school != "" and info.school != info.damage_type:
		m *= float(weak.get(info.school, 1.0))
	if info.weapon_class != "":
		m *= float(cls_weak.get(info.weapon_class, 1.0))
	return m


## Dano final após atributos do atacante, fraquezas, ponto fraco, crítico,
## defesa e marca. Não aplica aleatoriedade (o crítico já vem decidido).
static func resolve(info: DamageInfo, attacker: StatBlock, defender: StatBlock, profile: Dictionary, marked: bool = false) -> float:
	var dmg := info.amount
	if attacker:
		if info.is_spell:
			dmg *= 1.0 + attacker.get_stat("spell_power")
		elif not info.is_hazard:
			dmg *= 1.0 + attacker.get_stat("attack")
	dmg *= weakness_multiplier(info, profile)
	dmg *= info.weak_point_mult
	if info.is_crit and attacker:
		dmg *= attacker.get_stat("crit_mult")
	elif info.is_crit:
		dmg *= 1.5
	if defender and not info.unblockable:
		var reduction := clampf(defender.get_stat("defense") * 0.03, 0.0, 0.6)
		dmg *= 1.0 - reduction
	if marked:
		dmg *= 1.2
	return maxf(dmg, 0.0)


static func roll_crit(rng: RandomNumberGenerator, stats: StatBlock, forced: bool = false) -> bool:
	if forced:
		return true
	var chance := stats.get_stat("crit_chance") if stats else 0.05
	return rng.randf() < chance
