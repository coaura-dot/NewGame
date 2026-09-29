extends Node
## Música: trilhas em loop (assets/audio/music/<id>.ogg, geradas por
## tools/build_music.py) com crossfade entre elas, no bus "Music".
## Em câmera lenta (aparo perfeito, esquiva) o tom desce um pouco, como em
## Katana Zero.

const DIR := "res://assets/audio/music/"
const FADE := 1.2

var current: String = ""
var ambience: String = ""
var _players: Array[AudioStreamPlayer] = []
## Ambiente (natureza, vento, chuva, caverna...): 2 players com crossfade
var _amb: Array[AudioStreamPlayer] = []
var _amb_active := 0
var _amb_tween: Tween
var _gain: Array[float] = [0.0, 0.0]
var _active := 0
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	for i in 2:
		var a := AudioStreamPlayer.new()
		a.bus = "Ambience"
		a.volume_db = -80.0
		add_child(a)
		_amb.append(a)


func has_track(id: String) -> bool:
	return id != "" and ResourceLoader.exists(DIR + id + ".ogg")


## Toca a trilha `id` (crossfade). A mesma trilha não reinicia.
func play(id: String, fade: float = FADE) -> void:
	if id == current:
		return
	if not has_track(id):
		stop(fade)
		return
	current = id
	var stream: AudioStream = load(DIR + id + ".ogg")
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var old := _active
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	_set_gain(_active, 0.0)
	p.play()
	_fade_to(_active, 1.0, old, 0.0, fade)


## Som de ambiente em loop (assets/audio/ambience/<id>.ogg). "" = silêncio.
func play_ambience(id: String, fade: float = 2.0) -> void:
	if id == ambience:
		return
	ambience = id
	var path := "res://assets/audio/ambience/%s.ogg" % id
	var old := _amb[_amb_active]
	if _amb_tween:
		_amb_tween.kill()
	_amb_tween = create_tween().set_parallel(true)
	_amb_tween.set_ignore_time_scale(true)
	_amb_tween.tween_property(old, "volume_db", -80.0, fade)
	if id == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_amb_active = 1 - _amb_active
	var p := _amb[_amb_active]
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	_amb_tween.tween_property(p, "volume_db", 0.0, fade)


func stop(fade: float = FADE) -> void:
	current = ""
	_fade_to(_active, 0.0, 1 - _active, 0.0, fade)


func _fade_to(a: int, ga: float, b: int, gb: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_ignore_time_scale(true)
	_tween.tween_method(func(v): _set_gain(a, v), _gain[a], ga, maxf(time, 0.01))
	_tween.tween_method(func(v): _set_gain(b, v), _gain[b], gb, maxf(time, 0.01))
	_tween.chain().tween_callback(func():
		for i in 2:
			if _gain[i] <= 0.001 and _players[i].playing:
				_players[i].stop())


func _set_gain(i: int, v: float) -> void:
	_gain[i] = v
	_players[i].volume_db = linear_to_db(maxf(v, 0.0001))


func _process(_delta: float) -> void:
	var pitch := clampf(lerpf(1.0, Engine.time_scale, 0.5), 0.75, 1.0)
	for p in _players:
		p.pitch_scale = pitch
