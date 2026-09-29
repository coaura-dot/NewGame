extends Node2D
## Tela de título: "PAVIO — a última chama".
## Uma clareira escura da Floresta Sussurrante (fundo em parallax, névoa,
## vaga-lumes) e o Pavio sentado numa pedra: a única chama acesa, que
## ilumina o chão em volta. O menu fica por cima, em painéis escuros.

class StillCam:
	extends Node
	func render_center() -> Vector2:
		return Vector2(160, 90)

const T := 8
## clareira: chão embaixo e uma pedra à esquerda onde o Pavio se senta
const GROUND := [
	[17, 5, 10], [18, 3, 12], [19, 2, 14],
]

var _ui: Control
var _panel: Control
var _cam: StillCam
var _t: float = 0.0
var _pv: PixelView
var _rig: HeroRig
var _halo: Sprite2D


func _ready() -> void:
	Audio.music("lareira", 1.0)
	FX.clear_time_effects()
	get_tree().paused = false
	_pv = PixelView.new()
	add_child(_pv)
	_cam = StillCam.new()
	add_child(_cam)
	_pv.camera = _cam
	var bg := BackgroundLayer.new()
	bg.camera = _cam
	bg.level_height = 180.0
	bg.build("floresta")
	_pv.world.add_child(bg)
	_pv.set_grade({}, true)
	_build_clearing()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = Control.new()
	UIKit.fit(_ui)
	_ui.theme = UIKit.theme()
	layer.add_child(_ui)
	_show_main()


## Monta a clareira com os tiles da floresta, o Pavio sentado e as luzes.
func _build_clearing() -> void:
	var biome: Dictionary = DB.biomes.get("floresta", {})
	var cm := CanvasModulate.new()
	cm.color = Level.ambient_color(biome, {})
	_pv.world.add_child(cm)
	var w := 44
	var h := 30
	var top := 4 ## linhas extras acima da tela (senão o teto invisível ganha enfeites pendurados)
	var rows := PackedStringArray()
	for y in h:
		var row := ""
		for x in w:
			var solid := y >= 20 + top
			for g in GROUND:
				if y == int(g[0]) + top and x >= int(g[1]) and x <= int(g[2]):
					solid = true
			row += "#" if solid else "."
		rows.append(row)
	var holder := Node2D.new()
	holder.position = Vector2(0, -top * T)
	_pv.world.add_child(holder)
	var built: Dictionary = LevelBuilder.build(holder, {"rows": rows, "width": w, "height": h, "rooms": []}, biome, "floresta")
	for l in built.get("lamps", []):
		var lt := LightUtil.make_light(Color(0.5, 0.9, 1.0), 0.4, 0.55)
		if lt:
			lt.position = l[0] - Vector2(0, top * T)
			_pv.world.add_child(lt)
	# raio de luar caindo na pedra
	var shaft := LightShaft.new()
	shaft.position = Vector2(64, 0)
	shaft.setup(Color(0.7, 0.9, 1.2), 136.0, 44.0)
	_pv.world.add_child(shaft)
	# o Pavio: a última chama
	_rig = HeroRig.new()
	_rig.position = Vector2(64, 136)
	_rig.z_index = 5
	_pv.world.add_child(_rig)
	_rig.play("sit")
	_rig.base_expression = "normal"
	var light := LightUtil.make_light(Color(1.0, 0.8, 0.55), 0.9, 1.7)
	if light:
		light.position = Vector2(64, 124)
		_pv.world.add_child(light)
	_halo = LightUtil.make_glow(Color(1.0, 0.62, 0.3, 0.26), 50.0)
	_halo.position = Vector2(64, 124)
	_halo.z_index = 4
	_pv.world.add_child(_halo)
	if Settings.video("ambient_particles"):
		var amb := AmbientParticles.new()
		amb.setup("fireflies")
		_pv.world.add_child(amb)


func _process(delta: float) -> void:
	_t += delta
	if _rig:
		# a chama respira devagar; às vezes ele pisca e olha para cima
		_rig.flame_boost = 0.15 + 0.1 * sin(_t * 0.9)
		if fmod(_t, 9.0) < delta:
			_rig.set_expression("look_up", 1.6)
	if _halo:
		var k := 0.9 + 0.1 * sin(_t * 7.0) * sin(_t * 3.1)
		_halo.modulate.a = 0.26 * k


func _set_panel(c: Control) -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = UIKit.centered(c)
	_ui.add_child(_panel)
	UIKit.focus_first(c)


func _show_main() -> void:
	var v := UIKit.vbox(2)
	# título com um brilho quente atrás (a chama)
	var head := Control.new()
	head.custom_minimum_size = Vector2(300, 64)
	var glow := TextureRect.new()
	glow.texture = LightUtil.soft()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.size = Vector2(300, 110)
	glow.position = Vector2(0, -24)
	glow.modulate = Color(1.0, 0.55, 0.2, 0.32)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	head.add_child(glow)
	var t := UIKit.title("PAVIO", 56)
	t.add_theme_color_override("font_color", Color(1.0, 0.87, 0.62))
	t.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02))
	t.size = Vector2(300, 64)
	head.add_child(t)
	v.add_child(head)
	v.add_child(UIKit.label("a última chama", 14, Color(0.95, 0.72, 0.5), HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 22)
	v.add_child(sp)
	var box := UIKit.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	if SaveSystem.has_save(0):
		box.add_child(UIKit.button("Continuar", _continue, 120))
	box.add_child(UIKit.button("Novo jogo", _show_new_game, 120))
	box.add_child(UIKit.button("Treino", func(): Game.start_training(), 120))
	box.add_child(UIKit.button("Opções", _show_options, 120))
	box.add_child(UIKit.button("Créditos", _show_credits, 120))
	box.add_child(UIKit.button("Sair", func(): get_tree().quit(), 120))
	for b in box.get_children():
		(b as Control).modulate = Color(1, 1, 1, 0.9)
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
		"Pavio, a última chama — um jogo de plataforma e duelos à luz de vela",
		"Arte: gerada por código (tools/pixel_art.py) — herói, criaturas, tiles e fundos",
		"Ícones de itens: Alex's Assets — 16x16 RPG Item Pack (CC0)",
		"Kenney — fontes e efeitos sonoros (CC0)",
	]:
		v.add_child(UIKit.label(line, 11))
	v.add_child(UIKit.button("Voltar", _show_main, 80))
	_set_panel(p)
