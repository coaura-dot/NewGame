class_name PowerBudget
extends RefCounted
## Estima o "poder" de armas, magias e loadouts de inimigos para manter o
## balanceamento: cada tier tem uma faixa aceitável. Os testes falham se algo
## sair da faixa — assim ninguém (jogador ou inimigo) tem arma/magia
## desproporcional. Ajuste as faixas aqui ao rebalancear o jogo inteiro.

const WEAPON_BUDGET := {1: Vector2(24, 50), 2: Vector2(32, 60), 3: Vector2(45, 80)}
const SPELL_BUDGET := {1: Vector2(10, 32), 2: Vector2(14, 42), 3: Vector2(20, 56)}

const STATUS_VALUE := {
	"burn": 0.12, "bleed": 0.12, "chill": 0.1, "shock": 0.1, "wet": 0.05,
	"blind": 0.25, "stun": 0.35, "mark": 0.15,
}
const STAT_VALUE := {
	"crit_chance": 1.5, "spell_power": 0.3, "defense": 0.02, "move_speed": 0.5,
	"focus_gain": 0.3, "attack": 1.0, "max_hp": 0.004,
}


static func weapon_score(weapon_id: String, db: Node) -> float:
	var m: Dictionary = db.moveset(weapon_id)
	if m.is_empty():
		return 0.0
	var total_dmg := 0.0
	var total_time := 0.0
	var reach := 0.0
	var status_bonus := 0.0
	var steps: Array = m.get("light", [])
	for step in steps:
		var hits := int(step.get("hits", 1))
		total_dmg += float(step.get("dmg", 1.0)) * hits
		total_time += float(step.get("startup", 0.05)) + float(step.get("active", 0.08)) + float(step.get("recovery", 0.15))
		var box: Array = step.get("box", [0, 0, 40, 30])
		reach += float(box[0]) + float(box[2])
		for s in step.get("status", {}).keys():
			status_bonus += STATUS_VALUE.get(s, 0.1) * float(step["status"][s]) / max(steps.size(), 1)
	if steps.is_empty() or total_time <= 0.0:
		return 0.0
	reach /= steps.size()
	var dps := total_dmg * float(m.get("damage", 10)) / total_time
	var score := dps * (0.7 + 0.3 * reach / 48.0)
	for s in m.get("weapon_status", {}).keys():
		status_bonus += STATUS_VALUE.get(s, 0.1) * float(m["weapon_status"][s])
	var util := 0.0
	if m.get("super_armor", false):
		util += 0.1
	if m.get("rhythm", false):
		util += 0.15
	if m.has("block"):
		util += 0.15
	var w: Dictionary = db.weapon(weapon_id)
	for st in w.get("stats", {}).keys():
		util += STAT_VALUE.get(st, 0.1) * float(w["stats"][st])
	return score * (1.0 + status_bonus) * (1.0 + util)


static func spell_score(spell_id: String, db: Node, level: int = 0) -> float:
	var s: Dictionary = db.spell(spell_id)
	if s.is_empty():
		return 0.0
	var cast: String = s.get("cast", "")
	if cast == "sigil":
		cast = s.get("effect", "nova")
	var dmg: float = db.spell_value(spell_id, "damage", level)
	var count := maxf(db.spell_value(spell_id, "count", level), 1.0)
	var radius: float = db.spell_value(spell_id, "radius", level)
	var total := 0.0
	var aoe := 1.0
	var control := 0.0
	match cast:
		"projectile":
			total = dmg * count
			if s.get("pierce", false):
				aoe = 1.4
			if s.has("homing"):
				control += 0.2
		"beam":
			total = dmg
			aoe = 1.0 + 0.5 * db.spell_value(spell_id, "chain", level) + (0.5 if s.get("pierce", false) else 0.0)
		"nova", "eruption", "smite":
			total = dmg
			aoe = maxf(1.0, radius / 40.0)
		"storm":
			total = dmg * count
		"field":
			var ticks: float = db.spell_value(spell_id, "duration", level) / maxf(float(s.get("tick", 0.25)), 0.05)
			total = dmg * ticks + db.spell_value(spell_id, "implode", level)
			aoe = maxf(1.0, radius / 40.0)
			control += 0.4 * db.spell_value(spell_id, "duration", level)
		"time_field":
			control += (1.0 - float(s.get("time_scale", 1.0))) * db.spell_value(spell_id, "duration", level) * maxf(1.0, radius / 60.0) * 0.9
		"blink":
			control += 0.8
		"rewind":
			control += 1.2 + db.spell_value(spell_id, "heal_ratio", level)
		"echo":
			control += 0.8 * db.spell_value(spell_id, "echo_mult", level) * count
		"ward":
			control += 0.5 * count
		"grab":
			total = dmg
			control += 0.6
	for st in s.get("status", {}).keys():
		control += STATUS_VALUE.get(st, 0.1) * float(s["status"][st]) * 2.0
	if s.has("knockback"):
		control += float(s["knockback"]) / 1000.0
	var cost := maxf(float(s.get("cost", 20)), 1.0)
	var value := total * aoe + control * 20.0
	# valor por foco gasto, normalizado para custo de referência 20
	var per_focus := value / (cost / 20.0)
	# recargas longas limitam o uso, mas pouco
	return per_focus / (1.0 + float(s.get("cooldown", 0.5)) * 0.03)


## Poder total de um loadout de inimigo (arma + melhor magia).
static func loadout_score(enemy_id: String, db: Node) -> float:
	var e: Dictionary = db.enemy(enemy_id)
	var lo: Dictionary = e.get("loadout", {})
	var best_spell := 0.0
	for sp in lo.get("spells", []):
		best_spell = maxf(best_spell, spell_score(sp, db))
	return weapon_score(lo.get("weapon", ""), db) + best_spell


static func weapon_in_budget(weapon_id: String, db: Node) -> bool:
	var tier := int(db.weapon(weapon_id).get("tier", 1))
	var b: Vector2 = WEAPON_BUDGET.get(tier, Vector2(0, 999))
	var sc := weapon_score(weapon_id, db)
	return sc >= b.x and sc <= b.y


static func spell_in_budget(spell_id: String, db: Node) -> bool:
	var tier := int(db.spell(spell_id).get("tier", 1))
	var b: Vector2 = SPELL_BUDGET.get(tier, Vector2(0, 999))
	var sc := spell_score(spell_id, db)
	return sc >= b.x and sc <= b.y
