extends Node
## Tira screenshots da fase de treino (precisa de renderizador, não headless):
##   godot --path . res://tests/screenshot.tscn -- <saida.png>


func _ready() -> void:
	var out := "user://shot.png"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	Game.pending = {"training": true}
	var level: Node = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	for i in 50:
		await get_tree().process_frame
	var p: Player = level.player
	Input.action_press("move_right")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")
	p.emote("!", 3.0)
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
