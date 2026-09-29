extends Node
## Tira várias screenshots de uma vez (precisa de renderizador, não headless):
##   godot --path . res://tests/shots.tscn -- <pasta_saida> [cenario]
## Cenários: rooms (cada sala do treino), region (cada sala de uma região
## real), menu, pause, map, all (padrão).

var out_dir := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scenario := args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if scenario in ["menu", "all"]:
		await _shot_scene("res://scenes/main_menu.tscn", "menu", 20)
	if scenario in ["rooms", "all"]:
		Game.pending = {"training": true}
		await _shot_rooms("treino")
	if scenario in ["pause", "all"]:
		Game.pending = {"training": true}
		await _shot_pause()
	if scenario in ["region", "all"]:
		Game.new_game(1234, 9)
		var start: String = Game.world["start"]
		Game.pending = {"region": start}
		await _shot_rooms("regiao")
		SaveSystem.delete_save(9)
	if scenario in ["map", "all"]:
		if not Game.has_game:
			Game.new_game(1234, 9)
		await _shot_scene("res://scenes/world_map.tscn", "mapa", 40)
		SaveSystem.delete_save(9)
	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot_scene(path: String, name: String, wait: int) -> void:
	var node: Node = load(path).instantiate()
	add_child(node)
	await _frames(wait)
	await _save(name)
	node.queue_free()
	await _frames(2)


func _shot_pause() -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(30)
	if level.pause_menu and level.pause_menu.has_method("open"):
		level.pause_menu.open()
	await _frames(10)
	await _save("pausa")
	get_tree().paused = false
	level.queue_free()
	await _frames(2)
	Game.end_training()


## Coloca o jogador em pé no meio de cada sala e fotografa.
func _shot_rooms(prefix: String) -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _frames(30)
	var p: Player = level.player
	var rows: PackedStringArray = level.layout["rows"]
	for room in level.layout["rooms"]:
		var o: Array = room["origin"]
		var spot := _stand_spot(rows, int(o[0]), int(o[1]))
		p.global_position = spot
		p.velocity = Vector2.ZERO
		p.reset_physics_interpolation()
		level._focus_camera_on_player()
		await _frames(12)
		await _save("%s_%02d_%s" % [prefix, int(room["index"]), room["type"]])
	level.queue_free()
	await _frames(2)
	if Game.training:
		Game.end_training()


func _stand_spot(rows: PackedStringArray, ox: int, oy: int) -> Vector2:
	var T := LevelConst.TILE
	for dx in [20, 16, 24, 12, 28, 8, 32, 5, 35]:
		for y in range(LevelConst.ROOM_H - 2, 1, -1):
			var x: int = ox + dx
			var yy: int = oy + y
			if rows[yy][x] != "#" and rows[yy - 1][x] != "#" and rows[yy + 1][x] in ["#", "-"]:
				return Vector2(x * T + T * 0.5, (yy + 1) * T)
	return Vector2((ox + 20) * T, (oy + 12) * T)
