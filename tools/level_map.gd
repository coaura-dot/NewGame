extends SceneTree
## Salva uma imagem do layout gerado de uma fase (1 tile = 2x2 px), para
## revisar o desenho das salas. Uso:
##   godot --headless --path . --script tools/level_map.gd -- <saida.png> [treino|seed:<n>:<bioma>]

const COLORS := {
	"#": Color(0.25, 0.24, 0.3), ".": Color(0.85, 0.87, 0.92), "-": Color(0.55, 0.4, 0.25),
	"^": Color(0.9, 0.2, 0.2), "B": Color(0.6, 0.5, 0.4), "Z": Color(0.6, 0.45, 0.3),
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://map.png"
	var mode: String = args[1] if args.size() > 1 else "treino"
	var db: Node = root.get_node("DB")
	var params := {}
	if mode == "treino":
		params = {"seed": 20260926, "biome": "castelo", "tier": 1, "boss": "nightmare", "hub": "", "dimension": "prima", "npcs": [],
			"abilities": ["dash", "wall_jump", "double_jump", "wall_climb"],
			"force_path": ["entrance", "platforming", "combat", "platforming", "shaft", "combat", "challenge", "corridor", "boss", "exit"]}
	else:
		var p := mode.split(":")
		params = {"seed": int(p[1]), "biome": p[2] if p.size() > 2 else "castelo", "tier": 2, "boss": "nightmare", "hub": "vila", "npcs": ["a"], "abilities": ["dash", "wall_jump"]}
	var lib := ChunkLibrary.new()
	var L: Dictionary = LevelGenerator.generate(params, lib, db)
	var S := 3
	var img := Image.create(L["width"] * S, L["height"] * S, false, Image.FORMAT_RGBA8)
	var rows: PackedStringArray = L["rows"]
	for y in L["height"]:
		for x in L["width"]:
			var c: Color = COLORS.get(rows[y][x], Color(0.85, 0.87, 0.92))
			img.fill_rect(Rect2i(x * S, y * S, S, S), c)
	for e in L["entities"]:
		var t: Array = e["tile"]
		var col := Color(0.2, 0.6, 1.0)
		match e["type"]:
			"enemy", "flyer", "boss": col = Color(1.0, 0.3, 0.6)
			"spawn": col = Color(0.1, 0.9, 0.3)
			"exit": col = Color(1.0, 0.85, 0.1)
			"chest", "relic", "key": col = Color(1.0, 0.7, 0.2)
			"torch", "light_shaft": continue
		img.fill_rect(Rect2i(int(t[0]) * S, int(t[1]) * S, S, S), col)
	# grade das salas
	for r in L["rooms"]:
		var o: Array = r["origin"]
		var rx: int = int(o[0]) * S
		var ry: int = int(o[1]) * S
		for i in LevelConst.ROOM_W * S:
			img.set_pixel(rx + i, ry, Color(0.2, 0.9, 0.9, 1))
		for j in LevelConst.ROOM_H * S:
			img.set_pixel(rx, ry + j, Color(0.2, 0.9, 0.9, 1))
		print("sala %d (%s) tipo=%s template=%s exits=%s" % [r["index"], str(o), r["type"], r.get("template", "?"), r.get("exits", "")])
	img.save_png(out)
	quit()
