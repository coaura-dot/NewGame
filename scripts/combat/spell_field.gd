class_name SpellField
extends Node2D
## Campo persistente: gravidade (puxa + dano por tique + implosão final) ou
## tempo (desacelera/para atores e projéteis do outro time).

var kind: String = "pull" ## pull | time
var team: int = Layers.Team.PLAYER
var source: Node = null
var radius: float = 30.0
var duration: float = 2.5
var pull: float = 190.0
var tick: float = 0.25
var damage: float = 2.0
var implode: float = 0.0
var time_scale: float = 0.35
var school: String = "gravity"
var color: Color = Color(1.0, 0.6, 2.0)
var spell_id: String = ""

var _t: float = 0.0
var _tick_t: float = 0.0
var _fx_t: float = 0.0


func _ready() -> void:
	z_index = 5
	var l := LightUtil.make_light(Color(color.r, color.g, color.b).clamp(), 0.6, radius / 40.0)
	if l:
		add_child(l)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_t -= delta
	var do_tick := _tick_t <= 0.0
	if do_tick:
		_tick_t = tick
	for a in get_tree().get_nodes_in_group("actors"):
		if a.team == team or a.dead:
			continue
		var to_center: Vector2 = global_position - a.body_center()
		var dist := to_center.length()
		if dist > radius:
			continue
		if kind == "pull":
			var falloff := 1.0 - dist / radius * 0.5
			a.apply_pull(to_center.normalized() * pull * falloff)
			if do_tick and damage > 0.0:
				_hit(a, damage)
		else:
			a.set_time_field(time_scale, get_instance_id())
	if kind == "time":
		for p in get_tree().get_nodes_in_group("projectiles"):
			if p.team != team and p.global_position.distance_to(global_position) < radius:
				p.time_scale = minf(p.time_scale, maxf(time_scale, 0.0))
	# partículas da escola: espiral entrando (vazio/gravidade), tiques (tempo)
	_fx_t -= delta
	if _fx_t <= 0.0 and _t < duration - 0.2:
		_fx_t = 0.07
		var at := global_position + Vector2.from_angle(randf() * TAU) * radius * randf_range(0.5, 0.9)
		SchoolFX.trail(get_parent(), school, at, global_position - at, color)
	queue_redraw()
	if _t >= duration:
		if implode > 0.0:
			for a in get_tree().get_nodes_in_group("actors"):
				if a.team != team and not a.dead and a.body_center().distance_to(global_position) <= radius * 0.8:
					_hit(a, implode, true)
			FX.burst(global_position, color * 1.6, 10, 130.0)
			SchoolFX.impact(get_parent(), school, global_position, Vector2.UP, color * 1.6, 1.6)
			FX.shake(0.35)
			Audio.play("explosion")
		queue_free()


func _hit(a: Node, amount: float, big: bool = false) -> void:
	var info := DamageInfo.new()
	info.amount = amount
	info.damage_type = school
	info.school = school
	info.is_spell = true
	info.team = team
	info.source = source if is_instance_valid(source) else null
	info.spell_id = spell_id
	info.parryable = false
	info.stagger = 2.0 if big else 0.1
	info.hitstop = 0.0
	for hb in a.get_children():
		if hb is Hurtbox:
			hb.receive(info)
			break


func _draw() -> void:
	var life := clampf(1.0 - _t / duration, 0.0, 1.0)
	var fade := minf(_t * 6.0, 1.0) * minf(life * 4.0, 1.0)
	if kind == "pull":
		draw_circle(Vector2.ZERO, radius * 0.18, Color(0.02, 0.0, 0.05, 0.95 * fade))
		for i in 4:
			var r := fmod(radius * (1.0 - fmod(_t * 0.8 + i * 0.25, 1.0)), radius)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.5 * fade * (r / radius)), 1.0)
		for i in 6:
			var a := _t * 4.0 + i * TAU / 6.0
			draw_arc(Vector2.ZERO, radius * 0.3, a, a + 1.2, 8, Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.8 * fade), 1.0)
	else:
		draw_circle(Vector2.ZERO, radius, Color(color.r * 0.2, color.g * 0.2, color.b * 0.3, 0.12 * fade))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.6 * fade), 1.0)
		var hand := _t * (0.5 if time_scale > 0.0 else 0.05) * TAU
		draw_line(Vector2.ZERO, Vector2.from_angle(hand - PI * 0.5) * radius * 0.6, Color(color.r, color.g, color.b, 0.7 * fade), 1.0)
		draw_line(Vector2.ZERO, Vector2.from_angle(hand * 0.08 - PI * 0.5) * radius * 0.4, Color(color.r, color.g, color.b, 0.7 * fade), 1.0)
