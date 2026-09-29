extends Node
## SFX por evento. Cada evento sorteia uma variação e um pitch leve para não
## soar repetitivo. Os arquivos são placeholders CC0 (Kenney).

const DIR := "res://assets/audio/sfx/"
const EVENTS := {
	"swing": ["g_slash"],
	"swing_heavy": ["g_slash", "swordSlide"],
	"hit": ["g_hit"],
	"hit_heavy": ["g_hitheavy"],
	"hit_metal": ["swordMetal", "impactMetal_light"],
	"parry": ["g_parry", "swordMetal"],
	"parry_perfect": ["g_parry"],
	"kill": ["g_kill"],
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
	"block": ["impactMetal_light"],
	"jump": ["jump"],
	"dash": ["g_dash"],
	"land": ["footstep_concrete"],
	"step": ["footstep_concrete"],
	"hurt": ["impactSoft_medium"],
	"death": ["lowFrequency_explosion"],
	"enemy_death": ["explosionCrunch"],
	"spell": ["laserSmall", "forceField"],
	"spell_heavy": ["laserRetro", "forceField"],
	"explosion": ["explosionCrunch", "lowFrequency_explosion"],
	"pickup": ["pickup"],
	"coins": ["handleCoins"],
	"chest": ["metalLatch", "doorOpen"],
	"door": ["doorOpen"],
	"break": ["rockHit", "stoneHit"],
	"ui_move": ["click"],
	"ui_confirm": ["confirmation"],
	"ui_back": ["back"],
	"ui_error": ["error"],
	"draw_blade": ["drawKnife"],
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
