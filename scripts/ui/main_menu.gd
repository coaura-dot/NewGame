extends Node2D
## Menu principal: continuar, novo jogo (com seed), treino, opções, créditos.

var _ui: Control
var _panel: Control
var _cam: Camera2D
var _t: float = 0.0


func _ready() -> void:
	FX.clear_time_effects()
	get_tree().paused = false
	Music.play("menu")
	_cam = Camera2D.new()
	_cam.position = Vector2(160, 90)
	add_child(_cam)
	_cam.make_current()
	var bg := BackgroundLayer.new()
	bg.camera = _cam
	bg.build("town", Color(1.0, 1.0, 1.0))
	add_child(bg)
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = bool(Settings.video("bloom"))
	env.glow_intensity = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var amb := AmbientParticles.new()
	amb.setup("fireflies", _cam)
	add_child(amb)
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.scale = Vector2(2.0 / 3.0, 2.0 / 3.0)
	add_child(layer)
	_ui = Control.new()
	_ui.size = Vector2(480, 270)
	_ui.theme = UIKit.theme()
	layer.add_child(_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.2)
	shade.size = Vector2(480, 270)
	_ui.add_child(shade)
	_show_main()


func _process(delta: float) -> void:
	_t += delta
	_cam.position.x += delta * 14.0


func _set_panel(c: Control) -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = UIKit.centered(c)
	_ui.add_child(_panel)
	UIKit.focus_first(c)


func _show_main() -> void:
	var v := UIKit.vbox(5)
	var t := UIKit.title("NEWGAME", 48)
	t.add_theme_color_override("font_color", Color(1.8, 1.3, 0.7))
	v.add_child(t)
	v.add_child(UIKit.label("arcade de stages procedural — protótipo", 11, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	v.add_child(sp)
	var box := UIKit.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	if SaveSystem.has_save(0):
		box.add_child(UIKit.button("Continuar", _continue))
	box.add_child(UIKit.button("Novo jogo", _show_new_game))
	box.add_child(UIKit.button("Treino (movimento e combate)", func(): Game.start_training(), 180))
	box.add_child(UIKit.button("Opções", _show_options))
	box.add_child(UIKit.button("Créditos", _show_credits))
	box.add_child(UIKit.button("Sair", func(): get_tree().quit()))
	var c := CenterContainer.new()
	c.add_child(box)
	v.add_child(c)
	_set_panel(v)


func _continue() -> void:
	if Game.load_game(0):
		Game.goto(Game.SCENE_MAP)


func _show_new_game() -> void:
	var p := UIKit.panel(Vector2(260, 0))
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(UIKit.title("Novo jogo", 22))
	var l := UIKit.label("O mapa-múndi é gerado pela seed e fica fixo durante toda a partida. Deixe vazio para aleatória.", 10, UIKit.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(240, 0)
	v.add_child(l)
	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = "seed (número)"
	seed_edit.custom_minimum_size = Vector2(200, 18)
	v.add_child(seed_edit)
	if SaveSystem.has_save(0):
		v.add_child(UIKit.label("Atenção: substitui o save atual.", 10, Color(1.4, 0.6, 0.5)))
	var row := UIKit.hbox(6)
	row.add_child(UIKit.button("Começar", func():
		var s := -1
		if seed_edit.text.strip_edges().is_valid_int():
			s = int(seed_edit.text.strip_edges())
		Game.new_game(s)
		Game.goto(Game.SCENE_MAP), 90))
	row.add_child(UIKit.button("Voltar", _show_main, 70))
	v.add_child(row)
	_set_panel(p)


func _show_options() -> void:
	var o := OptionsMenu.new()
	o.closed.connect(_show_main)
	_set_panel(o)


func _show_credits() -> void:
	var p := UIKit.panel(Vector2(320, 0))
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.title("Créditos", 22))
	for line in [
		"Arte placeholder (CC0): Luis Zuno @ansimuz — Gothicvania",
		"Pixel Frog — Pixel Adventure, Treasure Hunters",
		"Foozle / Baldur — Lucifer Effects",
		"Alex's Assets — 16x16 RPG Item Pack",
		"Kenney — fontes e efeitos sonoros",
		"Tudo será substituído pela arte final.",
	]:
		v.add_child(UIKit.label(line, 11))
	v.add_child(UIKit.button("Voltar", _show_main, 80))
	_set_panel(p)
