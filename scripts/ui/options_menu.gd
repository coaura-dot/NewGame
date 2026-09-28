class_name OptionsMenu
extends PanelContainer
## Opções: Vídeo (todos os efeitos de luz/blur podem ser desligados), Áudio,
## Jogabilidade/Assistência (inspirado em Celeste) e Controles.

signal closed

var _tabs: TabContainer


func _ready() -> void:
	theme = UIKit.theme()
	custom_minimum_size = Vector2(360, 230)
	var root := UIKit.vbox(6)
	add_child(root)
	root.add_child(UIKit.title("Opções", 22))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(340, 170)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_tabs.add_child(_video_tab())
	_tabs.add_child(_audio_tab())
	_tabs.add_child(_gameplay_tab())
	_tabs.add_child(_controls_tab())
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UIKit.button("Padrões", func():
		Settings.reset_to_defaults()
		_rebuild(), 90))
	row.add_child(UIKit.button("Voltar", func(): closed.emit(), 90))
	root.add_child(row)
	UIKit.focus_first(self)


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_ready.call_deferred()


func _scroll(tab_name: String) -> Array:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return [sc, v]


func _video_tab() -> Control:
	var pair := _scroll("Vídeo")
	var v: VBoxContainer = pair[1]
	var toggles := [
		["fullscreen", "Tela cheia"], ["vsync", "VSync"], ["integer_scaling", "Escala inteira (pixel perfeito)"],
		["bloom", "Bloom (brilho)"], ["god_rays", "Raios de luz"], ["motion_blur", "Motion blur"],
		["dynamic_lights", "Luzes dinâmicas"], ["shadows", "Sombras"], ["chromatic_aberration", "Aberração cromática"],
		["vignette", "Vinheta"], ["smooth_camera", "Câmera suave (subpixel)"], ["afterimages", "Rastros (afterimages)"],
		["screen_flash", "Clarões de tela"], ["ambient_particles", "Partículas de ambiente"],
		["hitstop", "Congelamento no impacto (hitstop)"], ["damage_numbers", "Números de dano"],
	]
	for t in toggles:
		var key: String = t[0]
		v.add_child(UIKit.check(t[1], bool(Settings.video(key)), func(val): Settings.set_value("video", key, val)))
	v.add_child(UIKit.slider("Intensidade do bloom", float(Settings.video("bloom_intensity")), 0.0, 2.0, 0.05, func(val): Settings.set_value("video", "bloom_intensity", val)))
	v.add_child(UIKit.slider("Força do motion blur", float(Settings.video("motion_blur_strength")), 0.0, 1.5, 0.05, func(val): Settings.set_value("video", "motion_blur_strength", val)))
	v.add_child(UIKit.slider("Tremor de tela", float(Settings.video("screen_shake")), 0.0, 1.5, 0.05, func(val): Settings.set_value("video", "screen_shake", val)))
	var ph := UIKit.hbox()
	ph.add_child(UIKit.label("Partículas"))
	var ob := OptionButton.new()
	for n in ["Mínimo", "Médio", "Alto"]:
		ob.add_item(n)
	ob.selected = int(Settings.video("particles"))
	ob.item_selected.connect(func(i): Settings.set_value("video", "particles", i))
	ph.add_child(ob)
	v.add_child(ph)
	return pair[0]


func _audio_tab() -> Control:
	var pair := _scroll("Áudio")
	var v: VBoxContainer = pair[1]
	for k in [["master", "Geral"], ["sfx", "Efeitos"], ["music", "Música"]]:
		var key: String = k[0]
		v.add_child(UIKit.slider(k[1], float(Settings.get_value("audio", key)), 0.0, 1.0, 0.05, func(val): Settings.set_value("audio", key, val)))
	return pair[0]


func _gameplay_tab() -> Control:
	var pair := _scroll("Jogabilidade")
	var v: VBoxContainer = pair[1]
	v.add_child(UIKit.label("Modo assistência (não bloqueia nada, jogue como quiser)", 10, UIKit.DIM))
	v.add_child(UIKit.slider("Velocidade do jogo", float(Settings.gameplay("game_speed")), 0.5, 1.0, 0.05, func(val): Settings.set_value("gameplay", "game_speed", val)))
	v.add_child(UIKit.check("Dash infinito", bool(Settings.gameplay("infinite_dash")), func(val): Settings.set_value("gameplay", "infinite_dash", val)))
	v.add_child(UIKit.check("Invencível", bool(Settings.gameplay("invincible")), func(val): Settings.set_value("gameplay", "invincible", val)))
	v.add_child(UIKit.check("Câmera lenta ao desenhar sigilos", bool(Settings.gameplay("sigil_slowmo")), func(val): Settings.set_value("gameplay", "sigil_slowmo", val)))
	v.add_child(UIKit.check("Cronômetro na tela (speedrun)", bool(Settings.gameplay("speedrun_timer")), func(val): Settings.set_value("gameplay", "speedrun_timer", val)))
	return pair[0]


func _controls_tab() -> Control:
	var pair := _scroll("Controles")
	var v: VBoxContainer = pair[1]
	var names := {
		"move_left": "Esquerda", "move_right": "Direita", "move_up": "Cima / Interagir", "move_down": "Baixo",
		"jump": "Pular", "dash": "Dash", "attack": "Ataque leve", "heavy": "Ataque pesado (segure)",
		"parry": "Aparar / Bloquear", "dodge": "Esquiva", "spell_1": "Magia 1", "spell_2": "Magia 2",
		"sigil": "Sigilo (segure e desenhe)", "heal": "Poção", "swap_weapon": "Trocar arma", "pause": "Pausa", "map": "Mapa",
	}
	for action in names.keys():
		var row := UIKit.hbox()
		var l := UIKit.label(names[action])
		l.custom_minimum_size = Vector2(150, 0)
		row.add_child(l)
		var keys := []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				keys.append(OS.get_keycode_string(ev.physical_keycode))
			elif ev is InputEventMouseButton:
				keys.append(["", "Mouse E", "Mouse D", "Mouse M"][clampi(ev.button_index, 0, 3)])
		row.add_child(UIKit.label(" / ".join(keys), 12, UIKit.GOLD))
		v.add_child(row)
	v.add_child(UIKit.label("Controle: A pula, B dash, X ataque, Y pesado, LB aparar, RB esquiva, LT/RT magias, R3 sigilo.", 10, UIKit.DIM))
	return pair[0]
