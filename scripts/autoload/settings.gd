extends Node
## Configurações do jogador (vídeo, áudio, jogabilidade/assistência, controles).
## Persistidas em user://settings.cfg. Todo efeito pesado (bloom, raios de luz,
## motion blur, sombras...) pode ser desligado aqui.

const PATH := "user://settings.cfg"
const VERSION := 3 ## mudou o visual padrão => reseta as opções de vídeo antigas

const DEFAULTS := {
	"video": {
		"fullscreen": false,
		"vsync": true,
		"integer_scaling": false,
		"bloom": true,
		"bloom_intensity": 0.8,
		"god_rays": false, # raios em tela: sutis, mas deixam rastro em luzes pontuais
		"motion_blur": true,
		"motion_blur_strength": 0.35,
		"dynamic_lights": true,
		"shadows": true,
		"chromatic_aberration": false,
		"vignette": false,
		"film_grain": false,
		"afterimages": true,
		"particles": 0, # 0 = mínimo, 1 = médio, 2 = alto
		"screen_shake": 1.0,
		"hitstop": true,
		"impact_frames": true, # quadro de impacto em 2 tons ao matar (desligue se incomodar)
		"damage_numbers": false,
	},
	"audio": {
		"master": 0.8,
		"sfx": 0.9,
		"music": 0.7,
		"ambience": 0.8,
	},
	"gameplay": {
		# Modo assistência inspirado em Celeste
		"game_speed": 1.0,
		"infinite_dash": false,
		"invincible": false,
		"aim_assist": true,
		"sigil_slowmo": true,
	},
}

## Ação -> lista de eventos padrão. Formato: "k:<keycode>", "m:<mouse button>",
## "jb:<joy button>", "ja:<axis>:<sign>".
const DEFAULT_BINDINGS := {
	"move_left": ["k:A", "k:Left", "ja:0:-1", "jb:13"],
	"move_right": ["k:D", "k:Right", "ja:0:1", "jb:14"],
	"move_up": ["k:W", "k:Up", "ja:1:-1", "jb:11"],
	"move_down": ["k:S", "k:Down", "ja:1:1", "jb:12"],
	"jump": ["k:Space", "k:C", "jb:0"],
	"dash": ["k:Shift", "k:X", "jb:1"],
	"attack": ["k:J", "m:1", "jb:2"],
	"heavy": ["k:K", "m:2", "jb:3"],
	"parry": ["k:L", "k:F", "jb:9"],
	"dodge": ["k:Ctrl", "k:V", "jb:10"],
	"spell_1": ["k:Q", "ja:4:1"],
	"spell_2": ["k:E", "ja:5:1"],
	"sigil": ["k:R", "m:3", "jb:8"],
	"interact": ["k:W", "k:Up", "k:Enter", "jb:11"],
	"pause": ["k:Escape", "jb:6"],
	"map": ["k:M", "k:Tab", "jb:4"],
	"heal": ["k:H", "jb:7"],
	"swap_weapon": ["k:G", "jb:5"],
	"debug_menu": ["k:F1"],
}

var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = DEFAULTS.duplicate(true)
	_load()
	_ensure_audio_buses()
	setup_input_map()
	apply()


func _ensure_audio_buses() -> void:
	for bus_name in ["SFX", "Music", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# eco de caverna/salão: reverb no bus de efeitos (ligado por Audio.set_space)
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.7
		rv.damping = 0.6
		rv.wet = 0.25
		rv.dry = 1.0
		rv.spread = 0.8
		AudioServer.add_bus_effect(sfx, rv)
		AudioServer.set_bus_effect_enabled(sfx, 0, false)


func get_value(section: String, key: String) -> Variant:
	if data.has(section) and data[section].has(key):
		return data[section][key]
	return DEFAULTS.get(section, {}).get(key)


func set_value(section: String, key: String, value: Variant) -> void:
	if not data.has(section):
		data[section] = {}
	data[section][key] = value
	apply()
	save()
	Events.settings_changed.emit()


func video(key: String) -> Variant:
	return get_value("video", key)


func gameplay(key: String) -> Variant:
	return get_value("gameplay", key)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var old: bool = int(cfg.get_value("meta", "version", 1)) < VERSION
	for section in DEFAULTS.keys():
		if old and section == "video":
			continue
		for key in DEFAULTS[section].keys():
			if cfg.has_section_key(section, key):
				data[section][key] = cfg.get_value(section, key)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for section in data.keys():
		for key in data[section].keys():
			cfg.set_value(section, key, data[section][key])
	cfg.save(PATH)


func reset_to_defaults() -> void:
	data = DEFAULTS.duplicate(true)
	apply()
	save()
	Events.settings_changed.emit()


func apply() -> void:
	if DisplayServer.get_name() == "headless":
		_apply_audio()
		return
	var win := get_window()
	if video("fullscreen"):
		win.mode = Window.MODE_FULLSCREEN
	elif win.mode == Window.MODE_FULLSCREEN:
		win.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if video("vsync") else DisplayServer.VSYNC_DISABLED)
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if video("integer_scaling") else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	_apply_audio()


func _apply_audio() -> void:
	_set_bus_volume("Master", get_value("audio", "master"))
	_set_bus_volume("SFX", get_value("audio", "sfx"))
	_set_bus_volume("Music", get_value("audio", "music"))
	_set_bus_volume("Ambience", get_value("audio", "ambience"))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


# ---------------------------------------------------------------------------
# Controles
# ---------------------------------------------------------------------------

func setup_input_map() -> void:
	for action in DEFAULT_BINDINGS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)
		InputMap.action_erase_events(action)
		for spec in DEFAULT_BINDINGS[action]:
			var ev := _event_from_spec(spec)
			if ev:
				InputMap.action_add_event(action, ev)


func _event_from_spec(spec: String) -> InputEvent:
	var parts := spec.split(":")
	match parts[0]:
		"k":
			var ev := InputEventKey.new()
			ev.physical_keycode = OS.find_keycode_from_string(parts[1])
			return ev
		"m":
			var ev := InputEventMouseButton.new()
			ev.button_index = int(parts[1]) as MouseButton
			return ev
		"jb":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(parts[1]) as JoyButton
			return ev
		"ja":
			var ev := InputEventJoypadMotion.new()
			ev.axis = int(parts[1]) as JoyAxis
			ev.axis_value = float(parts[2])
			return ev
	return null


## Texto amigável da primeira tecla de uma ação (para dicas na HUD).
func binding_label(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
		if ev is InputEventMouseButton:
			return ["", "Mouse E", "Mouse D", "Mouse M"][clampi(ev.button_index, 0, 3)]
	return action
