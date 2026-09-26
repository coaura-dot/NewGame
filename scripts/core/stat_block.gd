class_name StatBlock
extends RefCounted
## Atributos com modificadores por fonte (arma, armadura, conjunto, buff
## temporário, dimensão...). Modelo aditivo: percentuais são frações somadas.

signal changed

const DEFAULTS := {
	"max_hp": 100.0,
	"attack": 0.0, ## +% dano físico
	"spell_power": 0.0, ## +% dano mágico
	"defense": 0.0,
	"crit_chance": 0.05,
	"crit_mult": 1.75,
	"focus_max": 100.0,
	"focus_gain": 0.0, ## +% ganho de foco
	"move_speed": 0.0, ## +% velocidade
	"dash_count": 0.0, ## cargas extras
	"bleed_power": 0.0,
	"burn_power": 0.0,
	"cooldown": 0.0, ## -% recarga (negativo = mais rápido)
	"spell_cost": 0.0,
	"time_spell_cost": 0.0,
	"hemorrhage_threshold": 0.0,
	"burn_immune": 0.0,
	"perfect_dodge_time": 0.0,
	"lifesteal": 0.0,
}

var base: Dictionary = {}
var _sources: Dictionary = {} ## source_id -> {stat: valor}


func _init(base_values: Dictionary = {}) -> void:
	base = DEFAULTS.duplicate()
	for k in base_values.keys():
		base[k] = float(base_values[k])


func set_source(source_id: String, stats: Dictionary) -> void:
	if stats.is_empty():
		_sources.erase(source_id)
	else:
		_sources[source_id] = stats.duplicate()
	changed.emit()


func remove_source(source_id: String) -> void:
	if _sources.erase(source_id):
		changed.emit()


func has_source(source_id: String) -> bool:
	return _sources.has(source_id)


func get_stat(stat: String) -> float:
	var v: float = float(base.get(stat, 0.0))
	for src in _sources.values():
		v += float(src.get(stat, 0.0))
	return v


func sources() -> Dictionary:
	return _sources
