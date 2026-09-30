extends Node
## Estado da partida: seed, mundo (grafo macro fixo por save), perfil do
## jogador, estado social e navegação entre cenas.

const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_MAP := "res://scenes/world_map.tscn"
const SCENE_LEVEL := "res://scenes/level.tscn"

const START_PROFILE := {
	"max_hp": 100.0,
	"currency": 0,
	"abilities": ["dash", "wall_jump"],
	"weapons": ["katana_andarilho", "montante_ferro", "presas_infernais"],
	"weapon": "katana_andarilho",
	"weapon_alt": "montante_ferro",
	"spells": {"chama": 0, "passo_etereo": 0, "seta_arcana": 0},
	"spell_slots": ["chama", "passo_etereo"],
	"sigils": {"sigilo_chama": 0, "sigilo_tempestade": 0},
	"armor": [], ## [{uid, id, level, affixes}]
	"equipped_armor": {}, ## slot -> uid (berloques: trinket_1, trinket_2)
	"buffs": [],
	"items": {"pocao_vida": 2},
	"upgrade_levels": {}, ## weapon_id -> nível
	"dimension": "prima",
	"region": "",
	"deaths": 0,
	"kills": 0,
	"bosses_defeated": [],
	"flags": {},
	"next_uid": 1,
}

var seed_value: int = 0
var world: Dictionary = {}
var profile: Dictionary = {}
var social: Dictionary = {}
var slot: int = 0
var has_game: bool = false

## Parâmetros para a próxima cena (ex.: qual região gerar).
var pending: Dictionary = {}
## Modo treino: perfil temporário com tudo liberado, nunca salvo.
var training: bool = false
var _stash: Dictionary = {}
var _stash_had_game: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = START_PROFILE.duplicate(true)


# ---------------------------------------------------------------------------
# Ciclo da partida
# ---------------------------------------------------------------------------

func new_game(seed_in: int = -1, save_slot: int = 0) -> void:
	seed_value = seed_in if seed_in >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	slot = save_slot
	world = WorldGenerator.generate(seed_value, DB)
	profile = START_PROFILE.duplicate(true)
	profile["region"] = world["start"]
	social = SocialSystem.create(world, seed_value, DB)
	world["regions"][world["start"]]["visited"] = true
	has_game = true
	save()


## Partida de treino: fase fixa para testar movimento/combate com tudo liberado.
## Com `arena_boss`, vira a Arena de chefes (entrada -> chefe -> saída).
func start_training(arena_boss: String = "") -> void:
	pending = {"training": true, "arena": arena_boss}
	goto(SCENE_LEVEL)


func setup_training_profile() -> void:
	if training:
		return
	training = true
	_stash_had_game = has_game
	_stash = to_dict() if has_game else {}
	seed_value = 20260926
	world = WorldGenerator.generate(seed_value, DB)
	social = SocialSystem.create(world, seed_value, DB)
	profile = START_PROFILE.duplicate(true)
	for ab in DB.abilities.keys():
		if DB.abilities[ab].get("implemented", false) and not profile["abilities"].has(ab):
			profile["abilities"].append(ab)
	for w in DB.weapons.keys():
		if DB.weapons[w].get("exclusive_to", "") == "" and not profile["weapons"].has(w):
			profile["weapons"].append(w)
	for sp in ["chama", "passo_etereo", "corrente_raios", "poco_gravitacional", "campo_lento", "retorno", "dobra_quantica", "telecinese"]:
		profile["spells"][sp] = 0
	for sg in ["sigilo_chama", "sigilo_tempestade", "sigilo_vazio", "sigilo_egide"]:
		profile["sigils"][sg] = 0
	profile["buffs"] = ["centelha", "acrobata", "mestre_riposta"]
	profile["items"] = {"pocao_vida": 5, "chave_ferro": 1}
	profile["currency"] = 500
	has_game = true


func end_training() -> void:
	if not training:
		return
	training = false
	if _stash_had_game and not _stash.is_empty():
		from_dict(_stash)
		has_game = true
	else:
		has_game = false
		profile = START_PROFILE.duplicate(true)
		world = {}
		social = {}
	_stash = {}


func save() -> void:
	if has_game and not training:
		SaveSystem.save_game(slot, to_dict())


func load_game(save_slot: int = 0) -> bool:
	var d := SaveSystem.load_game(save_slot)
	if d.is_empty():
		return false
	from_dict(d)
	slot = save_slot
	has_game = true
	return true


func to_dict() -> Dictionary:
	return {"version": SaveSystem.VERSION, "seed": seed_value, "world": world, "profile": profile, "social": social}


func from_dict(d: Dictionary) -> void:
	seed_value = int(d.get("seed", 0))
	world = d.get("world", {})
	profile = START_PROFILE.duplicate(true)
	profile.merge(d.get("profile", {}), true)
	social = d.get("social", {})


func goto(scene_path: String) -> void:
	FX.clear_time_effects()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", scene_path)


func enter_region(region_id: String) -> void:
	travel(region_id, "", "shrine")


## DEBUG: mundo livre para explorar — todas as habilidades, todas as regiões
## reveladas e viagem rápida para qualquer uma (save no slot 7, não mexe no
## save normal). Abre o mapa ao chegar.
func start_debug_explore() -> void:
	new_game(-1, 7)
	for ab in DB.abilities.keys():
		if DB.abilities[ab].get("implemented", false):
			unlock_ability(ab)
	profile["shrines"] = []
	for id in world["regions"].keys():
		world["regions"][id]["visited"] = true
		profile["shrines"].append(id)
	profile["debug_travel"] = true
	profile["region"] = world["start"]
	save()
	travel(str(world["start"]))
	pending["open_map"] = true


## Começo da jornada (depois de Novo jogo): a abertura (história) e então a
## região inicial.
func start_new_journey() -> void:
	if ResourceLoader.exists("res://scenes/intro.tscn"):
		goto("res://scenes/intro.tscn")
	else:
		travel(str(world.get("start", "")))


## Mundo contínuo: atravessou o portão para a região `to` vindo de `from`.
## `at` = "shrine" (viagem rápida: nasce no santuário da região).
func travel(to: String, from: String = "", at: String = "") -> void:
	if not world.get("regions", {}).has(to):
		return
	profile["region"] = to
	var r: Dictionary = world["regions"][to]
	r["visited"] = true
	profile["dimension"] = r.get("dimension", "prima")
	pending = {"region": to, "from": from, "at": at}
	save()
	goto(SCENE_LEVEL)


## Guarda um resumo da fase (salas e portões) para o mapa.
func record_map(region_id: String, layout: Dictionary) -> void:
	if training or region_id == "":
		return
	if not profile.has("maps"):
		profile["maps"] = {}
	var rooms: Array = []
	var cw: int = LevelConst.ROOM_W
	var ch: int = LevelConst.ROOM_H
	if layout.has("macro"):
		cw = int(layout["macro"]["cw"])
		ch = int(layout["macro"]["ch"])
	for r in layout.get("rooms", []):
		var o: Array = r["origin"]
		var sz: Array = r.get("cells", [1, 1])
		# [x, y, tipo, largura, altura, nome, tipo do lugar] em células
		rooms.append([int(o[0]) / cw, int(o[1]) / ch, str(r.get("type", "")), int(sz[0]), int(sz[1]), str(r.get("name", "")), str(r.get("kind", ""))])
	var ports: Array = []
	for p in layout.get("ports", []):
		var o: Array = p["origin"]
		ports.append([int(o[0]) / cw, int(o[1]) / ch, p["dir"], p["to"]])
	profile["maps"][region_id] = {"w": int(layout["width"]) / cw, "h": int(layout["height"]) / ch,
		"rooms": rooms, "ports": ports, "objective": layout.get("objective", {})}


func mark_explored(region_id: String, room_index: int) -> void:
	if training or region_id == "":
		return
	if not profile.has("explored"):
		profile["explored"] = {}
	var list: Array = profile["explored"].get(region_id, [])
	if not list.has(room_index):
		list.append(room_index)
	profile["explored"][region_id] = list


func add_shrine(region_id: String) -> void:
	if training or region_id == "":
		return
	if not profile.has("shrines"):
		profile["shrines"] = []
	if not profile["shrines"].has(region_id):
		profile["shrines"].append(region_id)
		Events.toast.emit("Santuário encontrado: viagem rápida liberada")


func current_region() -> Dictionary:
	return world.get("regions", {}).get(profile.get("region", ""), {})


func complete_region(region_id: String) -> void:
	var r: Dictionary = world["regions"].get(region_id, {})
	if r.is_empty():
		return
	r["cleared"] = true
	var gained: Array = r.get("rewards", []).duplicate()
	if r.get("grants", "") != "":
		gained.append(r["grants"])
	for ab in gained:
		unlock_ability(ab)
	if r.get("boss", "") != "" and not profile["bosses_defeated"].has(r["boss"] + ":" + region_id):
		profile["bosses_defeated"].append(r["boss"] + ":" + region_id)
	SocialSystem.on_region_cleared(social, region_id)
	Events.level_completed.emit(region_id)
	save()


func unlock_ability(ability_id: String) -> void:
	if not profile["abilities"].has(ability_id):
		profile["abilities"].append(ability_id)
		Events.player_ability_unlocked.emit(ability_id)
		Events.toast.emit("Habilidade: " + str(DB.abilities.get(ability_id, {}).get("name", ability_id)))
		var sp: String = DB.abilities.get(ability_id, {}).get("spell", "")
		if sp != "":
			Inventory.add(profile, sp)


func has_ability(ability_id: String) -> bool:
	return profile.get("abilities", []).has(ability_id)


func is_siege_ready() -> bool:
	## O Cerco começa quando o jogador derrota chefes suficientes.
	return profile.get("bosses_defeated", []).size() >= maxi(2, world.get("abilities_order", []).size())
