extends Node
## Executa todos os tests/test_*.gd. Uso:
##   godot --headless --path . res://tests/test_runner.tscn
## Sai com código 1 se algum teste falhar.

var passes := 0
var failures := 0
var current := ""
var failed_msgs: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame
	_check_scripts("res://scripts/")
	var files := DirAccess.get_files_at("res://tests/")
	var names := []
	for f in files:
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd" and f != "test_case.gd":
			names.append(f)
	names.sort()
	var only := OS.get_environment("TEST_ONLY")
	for f in names:
		if only != "" and not f.contains(only):
			continue
		var script: GDScript = load("res://tests/" + f)
		var inst = script.new()
		inst.runner = self
		inst.tree = get_tree()
		for m in inst.get_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			current = "%s::%s" % [f, mname]
			var before := failures
			await inst.call(mname)
			print(("  ok   " if failures == before else "  FAIL ") + current)
	print("")
	print("==== %d verificações OK, %d falhas ====" % [passes, failures])
	for m in failed_msgs:
		print("  - " + m)
	get_tree().quit(1 if failures > 0 else 0)


func report(ok: bool, msg: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		failed_msgs.append("%s: %s" % [current, msg])


func _check_scripts(dir: String) -> void:
	current = "carregar scripts"
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var s: GDScript = load(dir + f)
			report(s != null and s.can_instantiate(), "script não compila: " + dir + f)
	for d in DirAccess.get_directories_at(dir):
		_check_scripts(dir + d + "/")
