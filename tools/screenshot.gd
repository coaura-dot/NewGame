extends SceneTree
## Tira prints do jogo rodando (renderizador real). Uso:
##   godot --path . --script tools/screenshot.gd -- <saida_prefixo> [treino|menu]
## Salva <prefixo>_N.png em alguns momentos (anda, pula, ataca).

var _out := "user://shot"
var _mode := "treino"
var _n := 0
var _level: Node = null
var _shots := [40, 110, 150, 200]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_mode = args[1]


func _process(_d: float) -> bool:
	_n += 1
	if _n == 2:
		if _mode == "menu":
			change_scene_to_file("res://scenes/main_menu.tscn")
		else:
			root.get_node("Game").pending = {"training": true}
			_level = load("res://scenes/level.tscn").instantiate()
			root.add_child(_level)
	if _mode != "menu":
		if _n == 60:
			Input.action_press("move_right")
		if _n == 100:
			Input.action_press("jump")
		if _n == 112:
			Input.action_release("jump")
		if _n == 140:
			Input.action_press("attack")
		if _n == 143:
			Input.action_release("attack")
		if _n == 190:
			Input.action_release("move_right")
	if _n in _shots:
		var img := root.get_texture().get_image()
		img.save_png("%s_%d.png" % [_out, _shots.find(_n)])
	if _n > _shots[-1]:
		quit()
	return false
