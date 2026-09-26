class_name ChunkLibrary
extends RefCounted
## Lê os templates de sala de res://data/rooms/*.txt (formato ASCII editável à
## mão) e oferece busca por tipo/saídas/bioma.

const DIR := "res://data/rooms/"

var templates: Array[Dictionary] = []
var errors: PackedStringArray = []


func _init() -> void:
	load_all()


func load_all() -> void:
	templates.clear()
	errors.clear()
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".txt"):
			_parse(DIR + f)


func _parse(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("não abriu " + path)
		return
	var cur: Dictionary = {}
	for raw in file.get_as_text().split("\n"):
		var line := raw.strip_edges(false, true)
		if cur.is_empty():
			if line.begins_with("@room"):
				cur = {"id": line.substr(6).strip_edges(), "type": "combat", "exits": "", "weight": 1.0,
					"tags": PackedStringArray(), "biomes": "*", "rows": PackedStringArray(), "source": path}
			continue
		if line.begins_with("@end"):
			_finish(cur)
			cur = {}
			continue
		if cur["rows"].is_empty() and line.contains(":") and not (line.begins_with("#") or line.begins_with(".")):
			var kv := line.split(":", true, 1)
			var k := kv[0].strip_edges()
			var v := kv[1].strip_edges()
			match k:
				"type": cur["type"] = v
				"exits": cur["exits"] = v
				"weight": cur["weight"] = float(v)
				"tags": cur["tags"] = v.split(" ", false)
				"biomes": cur["biomes"] = v
			continue
		if line == "" and cur["rows"].is_empty():
			continue
		cur["rows"].append(line)


func _finish(t: Dictionary) -> void:
	var rows: PackedStringArray = t["rows"]
	if rows.size() != LevelConst.ROOM_H:
		errors.append("%s: %d linhas" % [t["id"], rows.size()])
		return
	for i in rows.size():
		if rows[i].length() != LevelConst.ROOM_W:
			errors.append("%s: linha %d com %d colunas" % [t["id"], i, rows[i].length()])
			return
	templates.append(t)


## Templates que suportam TODAS as saídas pedidas.
func find(room_type: String, needed_exits: String, biome: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in templates:
		if t["type"] != room_type:
			continue
		if t["biomes"] != "*" and biome != "" and not t["biomes"].contains(biome):
			continue
		var ok := true
		for e in needed_exits:
			if not t["exits"].contains(e):
				ok = false
				break
		if ok:
			out.append(t)
	return out


func get_template(id: String) -> Dictionary:
	for t in templates:
		if t["id"] == id:
			return t
	return {}
