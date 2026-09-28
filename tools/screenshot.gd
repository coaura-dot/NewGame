extends SceneTree
## Tira prints do jogo rodando (renderizador real). Uso:
##   godot --path . --script tools/screenshot.gd -- <prefixo> [treino|menu|salas]
## treino: anda, pula e ataca; menu: menu principal; salas: um print por sala
## do treino (teleporta o herói para cada sala).

var _out := "user://shot"
var _mode := "treino"
var _n := 0
var _level: Node = null
var _shots := [40, 110, 150, 200]
var _room := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_mode = args[1]


func _save(tag: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s_%s.png" % [_out, tag])


func _process(_d: float) -> bool:
	_n += 1
	if _n == 2:
		if _mode == "menu":
			change_scene_to_file("res://scenes/main_menu.tscn")
		else:
			root.get_node("Game").pending = {"training": true}
			_level = load("res://scenes/level.tscn").instantiate()
			root.add_child(_level)
	if _mode == "salas":
		return _salas()
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
		_save(str(_shots.find(_n)))
	if _n > _shots[-1]:
		quit()
	return false


func _salas() -> bool:
	if _n < 30:
		return false
	var rooms: Array = _level.layout["rooms"]
	if _room >= rooms.size():
		quit()
		return false
	var k := (_n - 30) % 40
	if k == 0:
		var r: Rect2 = _level.room_rect(_room)
		# acha um chão livre perto do meio da sala
		var p = _level.player
		var best := r.get_center()
		var rows: PackedStringArray = _level.layout["rows"]
		var T := 8
		for dx in [0, -3, 3, -6, 6, -9, 9, -12, 12]:
			var tx: int = int(r.get_center().x / T) + int(dx)
			for ty in range(int(r.position.y / T) + 3, int(r.end.y / T) - 1):
				if rows[ty][tx] != "#" and rows[ty - 1][tx] != "#" and (rows[ty + 1][tx] == "#" or rows[ty + 1][tx] == "-"):
					best = Vector2(tx * T + 4, (ty + 1) * T)
					break
			if best != r.get_center():
				break
		p.global_position = best
		p._prev_pos = best
		p.reset_physics_interpolation()
		p.invuln_time = 99.0
		_level.camera.set_room(_level.camera_rect(_room))
		_level.camera.snap()
	if k == 30:
		_save("sala%02d_%s" % [_room, _level.layout["rooms"][_room]["type"]])
		_room += 1
	return false
