class_name CutscenePlayer
extends CanvasLayer
## Toca as CENAS da história (data/story.json -> scenes): uma lista de
## passos executados em ordem. O Lume fica sem controle (cutscene_lock) e
## aparecem as barras de cinema. Passos ("do"):
##   wait t | say who lines | bars on | camera to=[x,y]|npc:id|player t
##   walk dx (tiles) | face dir | sleep | wake | ignite | emote who kind
##   flag set | title text sub | fade to t | shake t | sound id | music id
##   npc_walk id dx | npc_face id dir | npc_hide id | toast text | lock | unlock

signal scene_finished(id: String)

var level: Node = null
var playing: bool = false
var _bars: float = 0.0
var _bars_on: bool = false
var _draw: Control
var _anchor: Node2D


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw = Control.new()
	_draw.size = Vector2(480, 270)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)


func _process(delta: float) -> void:
	_bars = move_toward(_bars, 1.0 if _bars_on else 0.0, delta * 2.5)
	_draw.queue_redraw()


func _on_draw() -> void:
	if _bars <= 0.001:
		return
	var h := 26.0 * _bars
	_draw.draw_rect(Rect2(0, 0, 480, h), Color(0, 0, 0, 1))
	_draw.draw_rect(Rect2(0, 270 - h, 480, h), Color(0, 0, 0, 1))


## Toca a cena `id` (se existir). Pode ser aguardada.
func play(id: String) -> void:
	var steps := Story.scene(id)
	if steps.is_empty() or playing:
		return
	playing = true
	var p: Node = level.player if level else null
	if p:
		p.cutscene_lock = true
		p.script_move = 0.0
	Events.story_event.emit("scene_start:" + id)
	for st in steps:
		if not is_inside_tree():
			return
		await _step(st)
	_bars_on = false
	if level and level.camera:
		level.camera.cine_active = false
	if p and is_instance_valid(p):
		p.cutscene_lock = false
		p.script_move = 0.0
	playing = false
	Story.set_flag("scene:" + id)
	scene_finished.emit(id)


func _tile_pos(v: Variant) -> Vector2:
	var T := LevelConst.TILE
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]) * T + T * 0.5, float(v[1]) * T)
	return Vector2.ZERO


func _npc(id: String) -> Node2D:
	if level == null:
		return null
	for n in level.get_tree().get_nodes_in_group("story_npcs"):
		if str(n.npc_id) == id:
			return n
	return null


func _step(st: Dictionary) -> void:
	var p: Node = level.player if level else null
	var what := str(st.get("do", ""))
	match what:
		"wait":
			await get_tree().create_timer(float(st.get("t", 0.5)), true, false, true).timeout
		"bars":
			_bars_on = bool(st.get("on", true))
		"lock":
			if p:
				p.cutscene_lock = true
		"unlock":
			if p:
				p.cutscene_lock = false
		"say":
			var who := str(st.get("who", ""))
			var ch := Story.character(who)
			var name := str(ch.get("name", who))
			var n := _npc(who)
			if n and n.has_method("face_player"):
				n.face_player()
			if level and level.dialogue:
				await level.dialogue.run(name, st.get("lines", []))
		"camera":
			var cam: GameCamera = level.camera if level else null
			if cam == null:
				return
			var to = st.get("to", "player")
			if str(to) == "player":
				cam.cine_active = false
			else:
				var pt := Vector2.ZERO
				if to is Array:
					pt = _tile_pos(to)
				elif str(to).begins_with("npc:"):
					var n := _npc(str(to).substr(4))
					if n:
						pt = n.global_position + Vector2(0, -16)
				cam.cine_point = pt
				cam.cine_rate = float(st.get("rate", 2.4))
				cam.cine_active = true
			var t := float(st.get("t", 0.0))
			if t > 0.0:
				await get_tree().create_timer(t, true, false, true).timeout
		"walk":
			if p:
				var target_x: float = p.global_position.x + float(st.get("dx", 0)) * LevelConst.TILE
				p.script_move = signf(target_x - p.global_position.x)
				var guard := 0.0
				while absf(p.global_position.x - target_x) > 2.0 and guard < 6.0:
					await get_tree().physics_frame
					guard += get_physics_process_delta_time()
					if signf(target_x - p.global_position.x) != p.script_move:
						break
				p.script_move = 0.0
		"face":
			if p:
				p.facing = int(st.get("dir", 1))
		"sleep":
			# apagado: a lanterna do Lume sem chama
			if p:
				p.force_anim = "off"
				if p.light:
					p.light.energy = 0.0
		"wake":
			if p:
				p.force_anim = ""
				p._idle_t = 0.0
		"ignite":
			# a brasa acende dentro da lanterna do Lume
			if p:
				p.force_anim = "sleep"
				FX.burst(p.body_center() + Vector2(0, -8), Color(3.0, 1.9, 0.7), 22, 90.0)
				FX.shake(0.15)
				Audio.play("confirmation", 0.0, -2.0)
				if p.light:
					p.light.energy = 2.4
					create_tween().tween_property(p.light, "energy", 0.68, 1.4)
		"emote":
			var who2 := str(st.get("who", "player"))
			var kind := str(st.get("kind", "!"))
			if who2 == "player" and p:
				p.emote(kind, float(st.get("t", 1.2)))
			else:
				var n2 := _npc(who2)
				if n2 and n2.has_method("emote"):
					n2.emote(kind, float(st.get("t", 1.2)))
		"flag":
			Story.set_flag(str(st.get("set", "")))
		"title":
			if level and level.hud and level.hud.has_method("show_title"):
				level.hud.show_title(str(st.get("text", "")), str(st.get("sub", "")), float(st.get("t", 4.0)))
		"fade":
			if level and level.postfx:
				var tw := create_tween()
				tw.set_ignore_time_scale(true)
				tw.tween_property(level.postfx, "fade", float(st.get("to", 1.0)), float(st.get("t", 0.5)))
				await tw.finished
		"shake":
			FX.shake(float(st.get("t", 0.3)))
		"sound":
			Audio.play(str(st.get("id", "")), 0.0, float(st.get("db", -2.0)))
		"music":
			Music.play(str(st.get("id", "")), float(st.get("t", 1.5)))
		"toast":
			Events.toast.emit(str(st.get("text", "")))
		"npc_walk":
			var n3 := _npc(str(st.get("id", "")))
			if n3 and n3.has_method("walk_by"):
				await n3.walk_by(float(st.get("dx", 0)) * LevelConst.TILE, float(st.get("speed", 30.0)))
		"npc_face":
			var n4 := _npc(str(st.get("id", "")))
			if n4 and n4.has_method("face"):
				n4.face(int(st.get("dir", 1)))
		"npc_hide":
			var n5 := _npc(str(st.get("id", "")))
			if n5:
				n5.visible = false
				n5.process_mode = Node.PROCESS_MODE_DISABLED
