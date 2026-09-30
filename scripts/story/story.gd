class_name Story
extends RefCounted
## HISTÓRIA de Cindária: personagens com falas que mudam com o progresso e
## cenas roteirizadas (data/story.json). As marcas de progresso ("flags")
## ficam em Game.profile["flags"].
##
## Condições (campo "if", várias separadas por "&"):
##   flag            a marca existe          !flag   não existe
##   lamps>=N        lampiões acesos         boss:id chefe derrotado
##   ability:id      tem a habilidade        region:id  região visitada
##   here:id         está na região id

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/story.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


static func character(id: String) -> Dictionary:
	return data().get("characters", {}).get(id, {})


static func scene(id: String) -> Array:
	return data().get("scenes", {}).get(id, [])


static func flags() -> Dictionary:
	if not Game.profile.has("flags") or not (Game.profile["flags"] is Dictionary):
		Game.profile["flags"] = {}
	return Game.profile["flags"]


static func has_flag(f: String) -> bool:
	return flags().has(f)


static func set_flag(f: String, v: Variant = true) -> void:
	if f == "":
		return
	flags()[f] = v
	Events.story_event.emit(f)


static func lamps_lit() -> int:
	return Game.profile.get("lamps", []).size()


static func check(cond: String) -> bool:
	if cond.strip_edges() == "":
		return true
	for part in cond.split("&"):
		var c := part.strip_edges()
		if c == "":
			continue
		var neg := c.begins_with("!")
		if neg:
			c = c.substr(1)
		var ok := false
		if c.begins_with("lamps>="):
			ok = lamps_lit() >= int(c.substr(7))
		elif c.begins_with("boss:"):
			var b := c.substr(5)
			for k in Game.profile.get("bosses_defeated", []):
				if str(k).begins_with(b + ":"):
					ok = true
		elif c.begins_with("ability:"):
			ok = Game.has_ability(c.substr(8))
		elif c.begins_with("region:"):
			ok = bool(Game.world.get("regions", {}).get(c.substr(7), {}).get("visited", false))
		elif c.begins_with("here:"):
			ok = str(Game.profile.get("region", "")) == c.substr(5)
		else:
			ok = has_flag(c)
		if ok == neg:
			return false
	return true


## Próxima conversa do personagem: a primeira entrada cuja condição vale e
## que ainda não foi dita (entradas "once"); as de rotina ("idle") giram.
## Devolve {lines, set, after, id} ou {} se não houver o que dizer.
static func next_talk(char_id: String) -> Dictionary:
	var ch := character(char_id)
	var talk: Array = ch.get("talk", [])
	var idle: Array = []
	for i in talk.size():
		var t: Dictionary = talk[i]
		if not check(str(t.get("if", ""))):
			continue
		var key := "talk:%s:%d" % [char_id, i]
		if bool(t.get("idle", false)):
			idle.append(t)
			continue
		if has_flag(key):
			continue
		var out := t.duplicate()
		out["_key"] = key
		return out
	if idle.is_empty():
		return {}
	var n := int(flags().get("idle:" + char_id, 0))
	flags()["idle:" + char_id] = n + 1
	return idle[n % idle.size()]


## Marca a conversa como dita e aplica os efeitos ("set", "give", "money").
static func finish_talk(t: Dictionary) -> void:
	if t.has("_key"):
		set_flag(str(t["_key"]))
	for f in _as_list(t.get("set", [])):
		set_flag(str(f))
	for it in _as_list(t.get("give", [])):
		Events.toast.emit(Inventory.add(Game.profile, str(it)))
	if int(t.get("money", 0)) != 0:
		Game.profile["currency"] = int(Game.profile.get("currency", 0)) + int(t["money"])
		Events.toast.emit("+%d brasas" % int(t["money"]))
	if str(t.get("ability", "")) != "":
		Game.unlock_ability(str(t["ability"]))


static func _as_list(v: Variant) -> Array:
	if v is Array:
		return v
	if str(v) == "":
		return []
	return [str(v)]


## Objetivo da história na HUD (o primeiro cuja condição vale).
static func objective() -> String:
	for o in data().get("objectives", []):
		if check(str(o.get("if", ""))):
			return str(o.get("text", ""))
	return ""
