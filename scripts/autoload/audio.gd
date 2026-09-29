extends Node
## SFX por evento. Cada evento sorteia uma variação e um pitch leve para não
## soar repetitivo. Os arquivos são placeholders CC0 (Kenney).

const DIR := "res://assets/audio/sfx/"
const EVENTS := {
	"swing": ["g_slash"],
	"swing_heavy": ["g_slash", "swordSlide"],
	"hit": ["g_hit"],
	"hit_heavy": ["g_hitheavy"],
	"hit_metal": ["g_clang"],
	"parry": ["g_parry"],
	"parry_perfect": ["g_parry"],
	"kill": ["g_kill"],
	"birds": ["g_birds"],
	"splash": ["g_splash"],
	"thunder": ["g_thunder"],
	"rumble": ["g_rumble"],
	"aim": ["g_aim"],
	"shot": ["g_shot"],
	"orb": ["g_orb"],
	"wave": ["g_wave"],
	"dash_strike": ["g_dashstrike"],
	"frenzy": ["g_frenzy"],
	"rank_s": ["g_rank_s"],
	"rank_a": ["g_rank_a"],
	"rank_b": ["g_rank_b"],
	"rank_c": ["g_rank_c"],
	"block": ["g_clang"],
	"jump": ["g_jump"],
	"dash": ["g_dash"],
	"land": ["g_land"],
	"step": ["g_land"],
	"hurt": ["g_hurt"],
	"death": ["g_death"],
	"enemy_death": ["g_poof"],
	"spell": ["g_spell"],
	"spell_heavy": ["g_spellheavy"],
	"explosion": ["g_explosion"],
	"pickup": ["g_pickup"],
	"coins": ["g_coin"],
	"chest": ["g_chest"],
	"door": ["g_door"],
	"break": ["g_crumble"],
	"ui_move": ["g_uitick"],
	"ui_confirm": ["g_uiconfirm"],
	"confirmation": ["g_uiconfirm"],
	"ui_back": ["g_uiback"],
	"ui_error": ["g_uierror"],
	"draw_blade": ["g_drawblade"],
}

var _streams: Dictionary = {} ## prefixo -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_index_files()


func _index_files() -> void:
	for f in ResourceLoader.list_directory(DIR):
		var name := str(f)
		if not name.ends_with(".ogg"):
			continue
		var base := name.get_basename()
		var prefix := base.rstrip("0123456789").trim_suffix("_")
		if not _streams.has(prefix):
			_streams[prefix] = []
		var path := DIR + name
		if ResourceLoader.exists(path) and not _streams[prefix].has(path):
			_streams[prefix].append(path)


## Acústica do lugar: "open" (sem eco), "hall" (salão/castelo), "cave"
## (caverna/catacumba: eco longo). Reverb no bus de efeitos.
func set_space(kind: String) -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0 or AudioServer.get_bus_effect_count(idx) == 0:
		return
	var rv := AudioServer.get_bus_effect(idx, 0) as AudioEffectReverb
	match kind:
		"cave":
			rv.room_size = 0.85
			rv.damping = 0.35
			rv.wet = 0.32
			rv.predelay_msec = 60.0
			AudioServer.set_bus_effect_enabled(idx, 0, true)
		"hall":
			rv.room_size = 0.6
			rv.damping = 0.6
			rv.wet = 0.18
			rv.predelay_msec = 30.0
			AudioServer.set_bus_effect_enabled(idx, 0, true)
		_:
			AudioServer.set_bus_effect_enabled(idx, 0, false)


func play(event: String, pitch_var: float = 0.08, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var prefixes: Array = EVENTS.get(event, [event])
	var prefix: String = prefixes[randi() % prefixes.size()]
	var list: Array = _streams.get(prefix, [])
	if list.is_empty():
		return
	var stream: AudioStream = load(list[randi() % list.size()])
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-pitch_var, pitch_var)) * clampf(Engine.time_scale, 0.5, 1.0))
	p.volume_db = volume_db
	p.play()
