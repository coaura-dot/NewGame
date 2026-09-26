class_name DamageInfo
extends RefCounted
## Tudo que um golpe/magia carrega até o alvo.

enum Result { HIT, BLOCKED, PARRIED, PERFECT_PARRY, INVULNERABLE, DODGED, IGNORED, KILLED }

var amount: float = 0.0
var damage_type: String = "slash" ## slash/pierce/blunt ou elemento (fire, ice...)
var school: String = "" ## escola da magia, se houver
var weapon_class: String = ""
var weapon_id: String = ""
var spell_id: String = ""
var source: Node = null ## ator que causou
var team: int = 0
var knockback: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var stagger: float = 1.0
var status: Dictionary = {} ## status_id -> acúmulos
var is_crit: bool = false
var is_heavy: bool = false
var is_projectile: bool = false
var is_spell: bool = false
var is_dash_attack: bool = false
var is_hazard: bool = false
var parryable: bool = true
var unblockable: bool = false
var pogo: bool = false
var weak_point_mult: float = 1.0
var backstab: bool = false
var hit_position: Vector2 = Vector2.ZERO
var hitstop: float = 0.05
var tags: PackedStringArray = []
var final_amount: float = 0.0 ## preenchido por quem recebe


func duplicate_info() -> DamageInfo:
	var d := DamageInfo.new()
	for p in ["amount", "damage_type", "school", "weapon_class", "weapon_id", "spell_id", "source", "team",
			"knockback", "direction", "stagger", "is_crit", "is_heavy", "is_projectile", "is_spell",
			"is_dash_attack", "is_hazard", "parryable", "unblockable", "pogo", "weak_point_mult",
			"backstab", "hit_position", "hitstop"]:
		d.set(p, get(p))
	d.status = status.duplicate()
	d.tags = tags.duplicate()
	return d
