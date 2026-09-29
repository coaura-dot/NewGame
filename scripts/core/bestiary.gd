class_name Bestiary
extends RefCounted
## Bestiário (o diário de criaturas do Pavio, estilo Diário do Caçador):
## cada inimigo derrotado ganha uma entrada com a história ("lore" em
## data/enemies.json); com TIP_KILLS abates aparece a dica de combate ("desc").
## Tudo em profile["bestiary"] = {id: abates}. Dados puros, testável.

const TIP_KILLS := 3


static func record(profile: Dictionary, enemy_id: String) -> void:
	if enemy_id == "":
		return
	var b: Dictionary = profile.get("bestiary", {})
	b[enemy_id] = int(b.get(enemy_id, 0)) + 1
	profile["bestiary"] = b


static func kills(profile: Dictionary, enemy_id: String) -> int:
	return int(profile.get("bestiary", {}).get(enemy_id, 0))


## Entradas conhecidas, na ordem do arquivo de dados:
## [{id, name, kills, lore, tip ("" se ainda não liberou), boss}]
static func entries(profile: Dictionary, db: Node) -> Array:
	var out: Array = []
	for id in db.enemies.keys():
		var sid := str(id)
		if sid.begins_with("_"):
			continue
		var k := kills(profile, sid)
		if k <= 0:
			continue
		var e: Dictionary = db.enemies[id]
		out.append({
			"id": sid, "name": str(e.get("name", sid)), "kills": k, "boss": bool(e.get("boss", false)),
			"lore": str(e.get("lore", "")), "tip": str(e.get("desc", "")) if k >= TIP_KILLS else "",
		})
	return out


## Quantas criaturas existem para registrar (para o "x/y").
static func total(db: Node) -> int:
	var n := 0
	for id in db.enemies.keys():
		if not str(id).begins_with("_"):
			n += 1
	return n
