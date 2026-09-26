extends Node
## Ponto de entrada: vai para o menu principal. Argumentos úteis (depois de --):
##   --training    abre direto o treino
##   --map         abre o mapa-múndi (cria jogo se preciso)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--training"):
		Game.start_training()
	elif args.has("--map"):
		if not Game.load_game(0):
			Game.new_game()
		Game.goto(Game.SCENE_MAP)
	else:
		Game.goto(Game.SCENE_MENU)
