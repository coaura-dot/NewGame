extends Node
## SFX por evento. Cada evento sorteia uma variação e um pitch leve para não
## soar repetitivo. "g_*" = efeitos sintetizados para o jogo (tools/sfx_gen.py,
## estilo chiptune limpo); o resto são arquivos CC0 (Kenney) para UI e objetos.

const DIRS := ["res://assets/audio/sfx/", "res://assets/audio/gen/"]
const EVENTS := {
	# movimento
	"jump": ["g_jump"],
	"djump": ["g_djump"],
	"walljump": ["g_walljump"],
	"wall_kick": ["g_wallkick"],
	"wall_refill": ["g_wallrefill"],
	"dash": ["g_dash"],
	"land": ["g_land"],
	"step": ["g_step"],
	"spring": ["g_spring"],
	"crumble": ["g_crumble"],
	"respawn": ["g_respawn"],
	# parkour
	"orb": ["g_orb"],
	"bell": ["g_bell"],
	"feather": ["g_feather"],
	"crystal": ["g_crystal"],
	"lamp": ["g_lamp"],
	"room_lit": ["g_roomlit"],
	"pogo": ["g_pogo"],
	"chain": ["g_chain"],
	"chain_end": ["g_chainend"],
	"rumble": ["g_rumble"],
	"turret_shot": ["g_turretshot"],
	"turret_break": ["g_turretbreak"],
	# combate
	"swing": ["g_slash"],
	"swing_heavy": ["g_slashheavy"],
	"hit": ["g_hit"],
	"hit_heavy": ["g_hitheavy"],
	"kill": ["g_kill"],
	"reflect": ["g_reflect"],
	"hit_metal": ["swordMetal", "impactMetal_light"],
	"parry": ["g_reflect", "swordMetal"],
	"parry_perfect": ["g_parry"],
	"telegraph": ["g_warn"],
	"telegraph_red": ["g_danger"],
	"guard": ["g_guard"],
	"block": ["impactMetal_light"],
	"hurt": ["g_hurt"],
	"death": ["g_death"],
	"enemy_death": ["g_kill"],
	# magias (por escola)
	"spell": ["g_arcane"],
	"spell_heavy": ["g_arcane", "g_void"],
	"spell_fire": ["g_fire"],
	"spell_ice": ["g_ice"],
	"spell_water": ["g_wind", "g_ice"],
	"spell_lightning": ["g_bolt"],
	"spell_void": ["g_void"],
	"spell_gravity": ["g_void"],
	"spell_earth": ["g_earth"],
	"spell_light": ["g_arcane", "g_heal"],
	"spell_psychic": ["g_arcane"],
	"spell_time": ["g_ice", "g_arcane"],
	"spell_arcane": ["g_arcane"],
	"spell_teleport": ["g_arcane"],
	"spell_quantum": ["g_arcane"],
	"spell_pressure": ["g_wind"],
	"heal": ["g_heal"],
	"explosion": ["g_earth", "explosionCrunch"],
	# mundo / UI
	"gate": ["g_gate"],
	"clear": ["g_clear"],
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
## Volume base por evento (dB). Os sintetizados passam por saturação macia e
## ficam uns 2 dB abaixo da versão antiga; o pulo foi refeito mais redondo.
const VOL := {
	"jump": -0.5, "djump": -2.0, "step": -3.0, "turret_shot": -2.0, "hurt": -1.0, "death": -2.0,
}

const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_DB := -7.0 ## a trilha fica abaixo dos efeitos

var _streams: Dictionary = {} ## prefixo -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
# música: dois tocadores que se cruzam (crossfade)
var _music: Array[AudioStreamPlayer] = []
var _music_cur: int = 0
var music_track: String = ""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.volume_db = -80.0
		add_child(mp)
		_music.append(mp)
	_index_files()


func _index_files() -> void:
	for dir in DIRS:
		for f in ResourceLoader.list_directory(dir):
			var name := str(f)
			if not (name.ends_with(".ogg") or name.ends_with(".wav")):
				continue
			var base := name.get_basename()
			var prefix := base.rstrip("0123456789").trim_suffix("_")
			if not _streams.has(prefix):
				_streams[prefix] = []
			var path: String = dir + name
			if ResourceLoader.exists(path) and not _streams[prefix].has(path):
				_streams[prefix].append(path)


## O evento tem algum som carregado? (testes)
func has_event(event: String) -> bool:
	for prefix in EVENTS.get(event, [event]):
		if not _streams.get(prefix, []).is_empty():
			return true
	return false


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
	p.volume_db = volume_db + float(VOL.get(event, 0.0))
	p.play()


## Troca a música com crossfade (trilha em assets/audio/music, gerada por
## tools/music_gen.py). "" = silêncio. Chamar de novo com a mesma faixa não
## reinicia.
func music(track: String, fade: float = 1.5) -> void:
	if track == music_track:
		return
	music_track = track
	var old := _music[_music_cur]
	_music_cur = 1 - _music_cur
	var cur := _music[_music_cur]
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	if track != "":
		var path := MUSIC_DIR + track + ".ogg"
		if ResourceLoader.exists(path):
			var st: AudioStream = load(path)
			if st is AudioStreamOggVorbis:
				(st as AudioStreamOggVorbis).loop = true
			cur.stream = st
			cur.volume_db = -40.0
			cur.play()
			_music_tween.tween_property(cur, "volume_db", MUSIC_DB, fade).set_trans(Tween.TRANS_SINE)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", -60.0, fade)
		_music_tween.chain().tween_callback(old.stop)
