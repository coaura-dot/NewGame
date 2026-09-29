extends Node
## Barramento global de sinais. Sistemas se comunicam por aqui para não
## dependerem uns dos outros diretamente (HUD, áudio, buffs, missões...).

# Jogador
signal player_spawned(player: Node)
signal player_died(player: Node)
signal player_health_changed(current: float, maximum: float)
signal player_focus_changed(current: float, maximum: float)
signal player_dash_changed(current: int, maximum: int)
signal player_equipment_changed
signal player_ability_unlocked(ability_id: String)

# Combate
signal damage_dealt(info: DamageInfo, target: Node, result: int)
signal enemy_killed(enemy: Node, info: DamageInfo)
signal combo_changed(count: int)
signal air_chain_changed(count: int)
signal parry(defender: Node, attacker: Node, perfect: bool)
signal perfect_dodge(actor: Node)
signal spell_cast(caster: Node, spell_id: String)
signal status_applied(target: Node, status_id: String, stacks: int)

# Mundo / fase
signal room_entered(room: Dictionary)
signal room_cleared(room: Dictionary)
signal level_completed(region_id: String)
signal item_picked(item_id: String, kind: String)
signal currency_changed(amount: int)
signal checkpoint_reached(position: Vector2)
signal dimension_changed(dimension_id: String)

# Social
signal reputation_changed(region_id: String, value: int)
signal affinity_changed(npc_id: String, value: int)
signal quest_updated(quest_id: String)
signal dialogue_requested(npc_id: String)

# UI / sistema
signal settings_changed
signal toast(text: String)
signal pause_toggled(paused: bool)
