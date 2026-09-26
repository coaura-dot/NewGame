class_name BuffSystem
extends RefCounted
## Motor de relíquias/buffs combináveis (Dead Cells). Cada buff reage a
## eventos com condições e efeitos (data/buffs.json). As sinergias surgem
## porque buffs, armas e magias compartilham status (queimando, sangrando,
## molhado, puxado, desacelerado...).

var actor: Node = null
var ids: Array = []
var crit_next: bool = false
var _counters: Dictionary = {}
var _temp: Array = [] ## [{source, until}]
var _clock: float = 0.0


func _init(owner_actor: Node = null) -> void:
	actor = owner_actor


func set_buffs(list: Array) -> void:
	ids = list.duplicate()
	var passive := {}
	for id in ids:
		var b: Dictionary = DB.buffs.get(id, {})
		for st in b.get("passive", {}).get("stats", {}).keys():
			passive[st] = float(passive.get(st, 0.0)) + float(b["passive"]["stats"][st])
	actor.stats.set_source("buffs", passive)


func update(delta: float) -> void:
	_clock += delta
	for t in _temp.duplicate():
		if _clock >= float(t["until"]):
			actor.stats.remove_source(t["source"])
			_temp.erase(t)


func trigger(event: String, ctx: Dictionary = {}) -> void:
	for id in ids:
		var b: Dictionary = DB.buffs.get(id, {})
		for trig in b.get("triggers", []):
			if trig.get("on", "") != event:
				continue
			var key := "%s:%s" % [id, event]
			_counters[key] = int(_counters.get(key, 0)) + 1
			if not _check(trig.get("if", {}), ctx, key):
				continue
			for eff in trig.get("do", []):
				_apply(eff, ctx, id)


## Multiplicador condicional de dano (damage_mods de todos os buffs).
func damage_mult(info: DamageInfo, target: Node) -> float:
	var m := 1.0
	for id in ids:
		for mod in DB.buffs.get(id, {}).get("damage_mods", []):
			var ctx := {"target": target, "info": info}
			if not _check(mod.get("if", {}), ctx, ""):
				continue
			if mod.has("mult"):
				m *= float(mod["mult"])
			if mod.has("per_speed"):
				var over: float = actor.velocity.length() - float(mod["if"].get("speed_min", 0))
				m *= 1.0 + maxf(over, 0.0) * float(mod["per_speed"])
	return m


func consume_crit() -> bool:
	if crit_next:
		crit_next = false
		return true
	return false


func _check(cond: Dictionary, ctx: Dictionary, counter_key: String) -> bool:
	var target: Node = ctx.get("target", null)
	for k in cond.keys():
		var v: Variant = cond[k]
		match k:
			"chance":
				if actor.rng.randf() >= float(v):
					return false
			"every":
				if counter_key == "" or int(_counters.get(counter_key, 0)) % int(v) != 0:
					return false
			"target_has":
				if target == null or not is_instance_valid(target) or not target.status.has(str(v)):
					return false
			"target_status_min":
				if target == null or not is_instance_valid(target):
					return false
				for s in v.keys():
					if target.status.stacks(s) < int(v[s]):
						return false
			"airborne":
				if actor.is_on_floor() == bool(v):
					return false
			"speed_min":
				if actor.velocity.length() < float(v):
					return false
			"hp_below":
				if actor.hp / maxf(actor.max_hp(), 1.0) >= float(v):
					return false
			"heavy":
				var info: DamageInfo = ctx.get("info", null)
				if info == null or info.is_heavy != bool(v):
					return false
			"combo_min":
				if int(ctx.get("combo", 0)) < int(v):
					return false
	return true


func _apply(eff: Dictionary, ctx: Dictionary, buff_id: String) -> void:
	var target: Node = ctx.get("target", null)
	var valid_target: bool = target != null and is_instance_valid(target) and not target.dead
	for k in eff.keys():
		var v: Variant = eff[k]
		match k:
			"apply_status":
				if valid_target:
					for s in v.keys():
						target.status.add(s, int(v[s]), actor.stats)
			"heal":
				actor.heal(float(v))
			"focus":
				if actor.has_method("gain_focus"):
					actor.gain_focus(float(v))
			"refill_dash":
				if actor.has_method("refill_dash"):
					actor.refill_dash()
			"crit_next":
				crit_next = true
			"temp_buff":
				var src := "temp:%s:%d" % [buff_id, Time.get_ticks_msec()]
				actor.stats.set_source(src, v.get("stats", {}))
				_temp.append({"source": src, "until": _clock + float(v.get("duration", 3.0))})
			"explode":
				if valid_target:
					var center: Vector2 = target.body_center()
					if v.has("consume"):
						target.status.remove(str(v["consume"]))
					for a in actor.get_tree().get_nodes_in_group("actors"):
						if a.team != actor.team and not a.dead and a.body_center().distance_to(center) <= float(v.get("radius", 48)):
							_direct_damage(a, float(v.get("damage", 10)), "fire")
					var ring := NovaFX.new()
					ring.radius = float(v.get("radius", 48))
					ring.color = Color(3.0, 1.2, 0.4)
					ring.global_position = center
					actor.get_parent().add_child(ring)
					FX.shake(0.25)
			"spread_status":
				if target != null and is_instance_valid(target):
					var st: String = v.get("status", "bleed")
					var stacks: int = maxi(target.status.stacks(st), 1)
					for a in actor.get_tree().get_nodes_in_group("actors"):
						if a != target and a.team != actor.team and not a.dead and a.body_center().distance_to(target.body_center()) <= float(v.get("radius", 80)):
							a.status.add(st, stacks, actor.stats)
							LightningFX.spawn(actor.get_parent(), target.body_center(), a.body_center(), StatusController.DEFS[st]["color"], 1.0)
			"spawn_spell":
				if actor.caster:
					var aim: Vector2 = actor.aim_direction() if actor.has_method("aim_direction") else Vector2(actor.facing, 0)
					actor.caster.cooldowns.erase(v.get("spell", ""))
					actor.caster.cast(v.get("spell", ""), 0, aim, target.body_center() if valid_target else Vector2.ZERO, 0.8)
			"bonus_damage":
				if valid_target:
					_direct_damage(target, float(v), "slash")
			"refund_spell":
				if actor.has_method("refund_last_spell"):
					actor.refund_last_spell()


func _direct_damage(a: Node, amount: float, dtype: String) -> void:
	var info := DamageInfo.new()
	info.amount = amount
	info.damage_type = dtype
	info.team = actor.team
	info.source = actor
	info.parryable = false
	info.stagger = 0.5
	for hb in a.get_children():
		if hb is Hurtbox:
			hb.receive(info)
			return
