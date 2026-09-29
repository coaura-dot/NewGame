class_name SocialSystem
extends RefCounted
## NPCs, afinidade, casamento, reputação, missões e o Cerco final.
## Estado vive em Game.social (Dictionary serializável).

const MAX_AFFINITY := 100
const MARRIAGE_AFFINITY := 80
const RESCUE_AFFINITY := 60
const PERSONALITIES := ["gentil", "sarcástico", "tímido", "orgulhoso", "alegre", "melancólico", "curioso", "desconfiado"]


static func create(world: Dictionary, seed_value: int, db: Node) -> Dictionary:
	var rng := RngUtil.make(seed_value, "social")
	var social := {
		"reputation": {"global": 0, "regions": {}},
		"npcs": {},
		"spouse": "",
		"quests": {"active": [], "done": []},
		"siege": {"started": false, "chosen": "", "summary": {}},
		"day": 0,
	}
	var npc_data: Dictionary = db.npc_data
	var region_ids: Array = world["regions"].keys()
	region_ids.sort()
	for rid in region_ids:
		var r: Dictionary = world["regions"][rid]
		social["reputation"]["regions"][rid] = 0
		var hub_type: String = r.get("hub", "")
		if hub_type == "":
			continue
		var hub: Dictionary = npc_data["hubs"].get(hub_type, npc_data["hubs"]["vila"])
		var culture_id: String = npc_data.get("biome_culture", {}).get(r["biome"], "humano")
		var culture: Dictionary = npc_data["cultures"].get(culture_id, npc_data["cultures"]["humano"])
		var roles: Array = hub["roles"].duplicate()
		RngUtil.shuffle(rng, roles)
		var count := rng.randi_range(int(hub["count"][0]), int(hub["count"][1]))
		for i in mini(count, roles.size()):
			var role: String = roles[i]
			var arch: Dictionary = npc_data["archetypes"][role]
			var npc_id := "%s_n%d" % [rid, i]
			social["npcs"][npc_id] = {
				"id": npc_id,
				"name": "%s %s" % [RngUtil.pick(rng, culture["first"]), RngUtil.pick(rng, culture["last"])],
				"role": role,
				"title": arch["title"],
				"region": rid,
				"culture": culture_id,
				"personality": RngUtil.pick(rng, PERSONALITIES),
				"affinity": rng.randi_range(0, 10),
				"romanceable": arch.get("romanceable", false),
				"likes": arch.get("likes", []),
				"dislikes": arch.get("dislikes", []),
				"services": arch.get("services", []),
				"assist": arch.get("assist", "none"),
				"met": false,
				"alive": true,
				"married": false,
				"last_gift_day": -1,
				"rescues": 0,
			}
	return social


# ---------------------------------------------------------------------------
# Reputação
# ---------------------------------------------------------------------------

static func reputation(social: Dictionary, region_id: String = "") -> int:
	var g := int(social["reputation"]["global"])
	if region_id == "":
		return g
	var r := int(social["reputation"]["regions"].get(region_id, 0))
	return int(round(g * 0.6 + r * 0.4))


static func change_reputation(social: Dictionary, region_id: String, delta: int) -> void:
	var rep: Dictionary = social["reputation"]
	rep["global"] = clampi(int(rep["global"]) + delta, -100, 100)
	if region_id != "":
		rep["regions"][region_id] = clampi(int(rep["regions"].get(region_id, 0)) + delta * 2, -100, 100)
	Events.reputation_changed.emit(region_id, reputation(social, region_id))


static func reputation_band(value: int, db: Node) -> String:
	var name := ""
	for b in db.quest_data.get("reputation_bands", []):
		if value >= int(b["min"]):
			name = b["name"]
	return name


# ---------------------------------------------------------------------------
# Relações
# ---------------------------------------------------------------------------

static func stage_name(affinity: int, db: Node) -> String:
	var name := ""
	for s in db.npc_data.get("relationship_stages", []):
		if affinity >= int(s["min"]):
			name = s["name"]
	return name


static func hearts(affinity: int) -> int:
	return clampi(affinity / 10, 0, 10)


static func change_affinity(social: Dictionary, npc_id: String, delta: int) -> void:
	var npc: Dictionary = social["npcs"].get(npc_id, {})
	if npc.is_empty() or not npc["alive"]:
		return
	npc["affinity"] = clampi(int(npc["affinity"]) + delta, 0, MAX_AFFINITY)
	Events.affinity_changed.emit(npc_id, npc["affinity"])


static func talk(social: Dictionary, npc_id: String, db: Node, rng: RandomNumberGenerator, world: Dictionary = {}) -> String:
	var npc: Dictionary = social["npcs"][npc_id]
	# às vezes o morador fala da Lareira ou dá uma pista de onde está um guardião
	if npc["met"] and rng.randf() < 0.35:
		return Lore.rumor(world, rng) if not world.is_empty() and rng.randf() < 0.5 else RngUtil.pick(rng, Lore.TOWN_LORE)
	var arch: Dictionary = db.npc_data["archetypes"][npc["role"]]
	var lines: Dictionary = arch.get("lines", {})
	var key := "greet"
	if int(npc["affinity"]) >= 80 and lines.has("love"):
		key = "love"
	elif int(npc["affinity"]) >= 35 and lines.has("friend"):
		key = "friend"
	if not npc["met"]:
		npc["met"] = true
		change_affinity(social, npc_id, 2)
	return RngUtil.pick(rng, lines.get(key, ["..."]))


## Dar presente (1 por dia). Retorna a variação de afinidade.
static func give_gift(social: Dictionary, npc_id: String, item_id: String) -> int:
	var npc: Dictionary = social["npcs"][npc_id]
	if int(npc["last_gift_day"]) == int(social.get("day", 0)):
		return 0
	npc["last_gift_day"] = int(social.get("day", 0))
	var delta := 3
	if npc["likes"].has(item_id):
		delta = 10
	elif npc["dislikes"].has(item_id):
		delta = -6
	change_affinity(social, npc_id, delta)
	return delta


static func marriage_block_reason(social: Dictionary, npc_id: String, profile: Dictionary) -> String:
	var npc: Dictionary = social["npcs"].get(npc_id, {})
	if npc.is_empty() or not npc["alive"]:
		return "Não está mais entre nós."
	if not npc["romanceable"]:
		return "Essa relação não é desse tipo."
	if social["spouse"] != "":
		return "Você já é casado(a)."
	if int(npc["affinity"]) < MARRIAGE_AFFINITY:
		return "Ainda não há intimidade suficiente."
	var has_ring := false
	for p in profile.get("armor", []):
		if p["id"] == "anel_compromisso":
			has_ring = true
	if not has_ring:
		return "Falta o Anel de Compromisso."
	return ""


static func marry(social: Dictionary, npc_id: String, profile: Dictionary) -> bool:
	if marriage_block_reason(social, npc_id, profile) != "":
		return false
	social["spouse"] = npc_id
	social["npcs"][npc_id]["married"] = true
	change_affinity(social, npc_id, 10)
	return true


## NPC que pode te salvar da morte nesta região (cônjuge vale em qualquer lugar).
static func rescue_candidate(social: Dictionary, region_id: String) -> String:
	if not social.has("npcs"):
		return "" # treino / sem mundo carregado
	var spouse: String = social.get("spouse", "")
	if spouse != "" and social["npcs"].has(spouse):
		var s: Dictionary = social["npcs"][spouse]
		if s["alive"] and int(s["rescues"]) < 3:
			return spouse
	for npc in social["npcs"].values():
		if npc["region"] == region_id and npc["alive"] and int(npc["affinity"]) >= RESCUE_AFFINITY and npc["assist"] != "none" and int(npc["rescues"]) < 1:
			return npc["id"]
	return ""


static func on_region_cleared(social: Dictionary, region_id: String) -> void:
	change_reputation(social, region_id, 3)
	for npc in social["npcs"].values():
		if npc["region"] == region_id:
			change_affinity(social, npc["id"], 4)
	social["day"] = int(social.get("day", 0)) + 1


# ---------------------------------------------------------------------------
# Missões
# ---------------------------------------------------------------------------

static func quest_offers(social: Dictionary, world: Dictionary, npc_id: String, db: Node, seed_value: int) -> Array:
	var npc: Dictionary = social["npcs"][npc_id]
	var rep := reputation(social, npc["region"])
	var rng := RngUtil.make(seed_value, "quests:%s:%d" % [npc_id, int(social.get("day", 0))])
	var out := []
	var targets: Array = world["regions"].keys()
	targets.sort()
	for tid in db.quest_data["templates"].keys():
		var t: Dictionary = db.quest_data["templates"][tid]
		if rep < int(t["band"][0]) or rep > int(t["band"][1]):
			continue
		var giver: String = t["giver"]
		if giver != "any" and not npc["services"].has(giver):
			continue
		var target_region: String = RngUtil.pick(rng, targets)
		if world["regions"][target_region].get("destroyed", false):
			continue
		var target_name: String = RngUtil.pick(rng, ["o coletor de impostos", "um cavaleiro corrupto", "a bruxa do pântano", "um mercador rival", "o carcereiro"])
		out.append({
			"id": "%s:%s:%d" % [tid, npc_id, int(social.get("day", 0))],
			"template": tid,
			"giver": npc_id,
			"region": target_region,
			"title": t["title"],
			"text": t["text"].format({"npc": npc["name"], "region": world["regions"][target_region]["name"], "target": target_name}),
			"objective": t["objective"],
			"reward": int(t["reward"]),
			"rep": int(t["rep"]),
			"affinity": int(t["affinity"]),
		})
	return out


static func accept_quest(social: Dictionary, quest: Dictionary) -> void:
	for q in social["quests"]["active"]:
		if q["id"] == quest["id"]:
			return
	social["quests"]["active"].append(quest)
	Events.quest_updated.emit(quest["id"])


static func complete_quest(social: Dictionary, quest_id: String, profile: Dictionary) -> Dictionary:
	var active: Array = social["quests"]["active"]
	for i in active.size():
		var q: Dictionary = active[i]
		if q["id"] == quest_id:
			active.remove_at(i)
			social["quests"]["done"].append(quest_id)
			profile["currency"] = int(profile.get("currency", 0)) + int(q["reward"])
			change_reputation(social, q["region"], int(q["rep"]))
			change_affinity(social, q["giver"], int(q["affinity"]))
			Events.quest_updated.emit(quest_id)
			return q
	return {}


## Chamado ao terminar uma fase: completa missões cujo objetivo foi cumprido.
static func resolve_quests_for_region(social: Dictionary, region_id: String, profile: Dictionary, result: Dictionary) -> Array:
	var done := []
	for q in social["quests"]["active"].duplicate():
		if q["region"] != region_id:
			continue
		var ok := false
		match q["objective"]:
			"clear_rooms", "reach_exit", "deliver", "fetch_item", "destroy_objects", "kill_target":
				ok = result.get("completed", false)
			"kill_boss":
				ok = result.get("boss_killed", false)
			"solve_puzzles":
				ok = int(result.get("puzzles", 0)) > 0 or result.get("completed", false)
		if ok:
			done.append(complete_quest(social, q["id"], profile))
	return done


# ---------------------------------------------------------------------------
# O Cerco (final): só a região escolhida sobrevive
# ---------------------------------------------------------------------------

static func siege_consequences(world: Dictionary, social: Dictionary, chosen: String) -> Dictionary:
	var lost_regions := []
	var lost_npcs := []
	var spouse_lost := false
	for rid in world["regions"].keys():
		if rid == chosen or world["regions"][rid].get("destroyed", false):
			continue
		lost_regions.append(world["regions"][rid]["name"])
	for npc in social["npcs"].values():
		if npc["region"] != chosen and npc["alive"]:
			lost_npcs.append({"name": npc["name"], "title": npc["title"], "affinity": npc["affinity"], "married": npc["married"]})
			if npc["married"]:
				spouse_lost = true
	lost_npcs.sort_custom(func(a, b): return int(a["affinity"]) > int(b["affinity"]))
	var rep_lost := 0
	for rid in social["reputation"]["regions"].keys():
		if rid != chosen:
			rep_lost += absi(int(social["reputation"]["regions"][rid]))
	return {
		"chosen": chosen,
		"chosen_name": world["regions"][chosen]["name"],
		"lost_regions": lost_regions,
		"lost_npcs": lost_npcs,
		"spouse_lost": spouse_lost,
		"reputation_lost": rep_lost,
	}


static func apply_siege(world: Dictionary, social: Dictionary, chosen: String) -> Dictionary:
	var summary := siege_consequences(world, social, chosen)
	for rid in world["regions"].keys():
		if rid != chosen:
			world["regions"][rid]["destroyed"] = true
			social["reputation"]["regions"][rid] = 0
	for npc in social["npcs"].values():
		if npc["region"] != chosen:
			npc["alive"] = false
			if npc["married"]:
				social["spouse"] = ""
				npc["married"] = false
	social["siege"] = {"started": true, "chosen": chosen, "summary": summary}
	return summary
