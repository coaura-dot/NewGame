extends Node
## Saves em JSON legível em user://saves/slot_<n>.json.

const VERSION := 1
const DIR := "user://saves"


func _path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]


func save_game(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Não foi possível salvar em " + _path(slot))
		return false
	data["saved_at"] = Time.get_datetime_string_from_system()
	f.store_string(JSON.stringify(data, "  "))
	return true


func load_game(slot: int) -> Dictionary:
	if not FileAccess.file_exists(_path(slot)):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _fix_types(parsed)


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_path(slot))


## JSON converte inteiros em float; normaliza campos que precisam ser int.
func _fix_types(d: Dictionary) -> Dictionary:
	d["seed"] = int(d.get("seed", 0))
	var p: Dictionary = d.get("profile", {})
	for k in ["currency", "deaths", "kills", "next_uid"]:
		if p.has(k):
			p[k] = int(p[k])
	for sp in p.get("spells", {}).keys():
		p["spells"][sp] = int(p["spells"][sp])
	for sp in p.get("sigils", {}).keys():
		p["sigils"][sp] = int(p["sigils"][sp])
	for it in p.get("items", {}).keys():
		p["items"][it] = int(p["items"][it])
	var w: Dictionary = d.get("world", {})
	for r in w.get("regions", {}).values():
		for k in ["band", "depth", "tier", "level_seed"]:
			if r.has(k):
				r[k] = int(r[k])
	return d
