extends Node2D
## Menu principal: continuar, novo jogo (com seed), treino, opções, créditos.
## Fundo: a tela interna 320x180 com o parallax da floresta e o herói
## cochilando num banco.

class PanCam:
	extends Node
	var x := 0.0
	func render_center() -> Vector2:
		return Vector2(x, 90)

var _ui: Control
var _panel: Control
var _cam: PanCam
var _t: float = 0.0
var _pv: PixelView


func _ready() -> void:
	FX.clear_time_effects()
	get_tree().paused = false
	_pv = PixelView.new()
	add_child(_pv)
	_cam = PanCam.new()
	add_child(_cam)
	_pv.camera = _cam
	var bg := BackgroundLayer.new()
	bg.camera = _cam
	bg.level_height = 180.0
	bg.build("floresta")
	_pv.world.add_child(bg)
	_pv.set_grade({}, true)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = Control.new()
	UIKit.fit(_ui)
	_ui.theme = UIKit.theme()
	layer.add_child(_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.25)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(shade)
	_show_main()


func _process(delta: float) -> void:
	_t += delta
	_cam.x += delta * 12.0


func _set_panel(c: Control) -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = UIKit.centered(c)
	_ui.add_child(_panel)
	UIKit.focus_first(c)


func _show_main() -> void:
	var v := UIKit.vbox(5)
	var t := UIKit.title("NEWGAME", 48)
	t.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	v.add_child(t)
	v.add_child(UIKit.label("arcade de stages procedural — protótipo", 11, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
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
		"Arte: gerada por código (tools/pixel_art.py) — herói, criaturas, tiles e fundos",
		"Ícones de itens: Alex's Assets — 16x16 RPG Item Pack (CC0)",
		"Kenney — fontes e efeitos sonoros (CC0)",
	]:
		v.add_child(UIKit.label(line, 11))
	v.add_child(UIKit.button("Voltar", _show_main, 80))
	_set_panel(p)
