class_name StatusController
extends RefCounted
## Status acumuláveis compartilhados por jogador e inimigos.
##   burn    - dano contínuo; acúmulos somam
##   bleed   - dano contínuo leve; ao atingir o limite: HEMORRAGIA (explode)
##   chill   - lentidão 12%/acúmulo; 5 acúmulos => frozen
##   frozen  - paralisado; golpes pesados "estilhaçam" (ver relíquia)
##   shock   - o próximo golpe recebido salta para inimigos próximos
##   wet     - raio causa +50%; gelo congela mais rápido
##   blind   - IA perde o alvo / erra mais
##   stun    - paralisado
##   mark    - recebe +20% de dano
##   pulled / slowed - marcadores de campos (gravidade / tempo)

const DEFS := {
	"burn": {"max": 5, "duration": 3.0, "dps": 2.4, "color": Color(2.4, 0.9, 0.3)},
	"bleed": {"max": 10, "duration": 6.0, "dps": 0.9, "color": Color(2.0, 0.2, 0.3)},
	"chill": {"max": 5, "duration": 3.5, "color": Color(0.6, 1.4, 2.4)},
	"frozen": {"max": 1, "duration": 1.6, "color": Color(0.7, 1.6, 2.8)},
	"shock": {"max": 3, "duration": 4.0, "color": Color(2.4, 2.4, 3.6)},
	"wet": {"max": 3, "duration": 5.0, "color": Color(0.4, 1.0, 2.2)},
	"blind": {"max": 1, "duration": 3.0, "color": Color(1.6, 1.6, 1.2)},
	"stun": {"max": 1, "duration": 1.1, "color": Color(2.4, 2.2, 0.6)},
	"mark": {"max": 1, "duration": 5.0, "color": Color(2.6, 0.6, 1.8)},
	"pulled": {"max": 1, "duration": 0.35, "color": Color(1.0, 0.5, 2.0)},
	"slowed": {"max": 1, "duration": 0.35, "color": Color(1.2, 1.6, 2.0)},
}
const TICK := 0.5

var actor: Node = null
var active: Dictionary = {} ## id -> {stacks, time, tick}


func _init(owner_actor: Node = null) -> void:
	actor = owner_actor


func has(id: String) -> bool:
	return active.has(id)


func stacks(id: String) -> int:
	return int(active.get(id, {}).get("stacks", 0))


func add(id: String, amount: int = 1, source_stats: StatBlock = null) -> void:
	if not DEFS.has(id) or amount <= 0:
		return
	if actor and actor.has_method("status_immune") and actor.status_immune(id):
		return
	var d: Dictionary = DEFS[id]
	var s: Dictionary = active.get(id, {"stacks": 0, "time": 0.0, "tick": TICK, "power": 1.0})
	s["stacks"] = mini(int(s["stacks"]) + amount, int(d["max"]))
	s["time"] = float(d["duration"])
	if source_stats:
		s["power"] = 1.0 + source_stats.get_stat(id + "_power")
	active[id] = s
	# interações
	if id == "chill":
		if has("wet"):
			s["stacks"] = mini(int(s["stacks"]) + 1, int(d["max"]))
		if int(s["stacks"]) >= int(d["max"]):
			active.erase("chill")
			add("frozen", 1)
	if id == "bleed":
		var threshold := int(d["max"])
		if source_stats:
			threshold += int(source_stats.get_stat("hemorrhage_threshold"))
		if int(s["stacks"]) >= threshold:
			active.erase("bleed")
			if actor and actor.has_method("on_hemorrhage"):
				actor.on_hemorrhage(float(s["power"]))
	if actor and actor.has_method("on_status_added"):
		actor.on_status_added(id, int(active.get(id, {}).get("stacks", 0)))


func remove(id: String) -> void:
	active.erase(id)


func clear() -> void:
	active.clear()


func update(delta: float) -> void:
	for id in active.keys():
		var s: Dictionary = active[id]
		s["time"] -= delta
		var d: Dictionary = DEFS[id]
		if d.has("dps"):
			s["tick"] -= delta
			if s["tick"] <= 0.0:
				s["tick"] += TICK
				var dmg: float = float(d["dps"]) * TICK * int(s["stacks"]) * float(s.get("power", 1.0))
				if actor and actor.has_method("take_status_damage"):
					actor.take_status_damage(dmg, id)
		if s["time"] <= 0.0:
			active.erase(id)


## Multiplicador de velocidade por status (lentidão/paralisia).
func speed_mult() -> float:
	if has("frozen") or has("stun"):
		return 0.0
	return 1.0 - 0.12 * stacks("chill")


func disabled() -> bool:
	return has("frozen") or has("stun")


## Cor dominante para o brilho do sprite.
func tint() -> Color:
	for id in ["frozen", "burn", "bleed", "shock", "chill", "mark", "stun"]:
		if has(id):
			return DEFS[id]["color"]
	return Color(0, 0, 0, 0)
