extends SceneTree
## Prancha de salas geradas (para revisar o level design). Uso:
##   godot --headless --path . --script tools/room_sheet.gd -- <saida.png> <tipo> [saídas] [tier]
## Cores: sólido escuro, espinho vermelho, plataforma marrom, orbe dourado,
## cristal ciano, inimigo rosa, voador roxo, plataforma que cai laranja,
## plataforma móvel azul, serra branca, mola verde.

const COL := {
	"#": Color(0.22, 0.21, 0.28), ".": Color(0.86, 0.88, 0.93), "-": Color(0.55, 0.4, 0.25),
	"^": Color(0.9, 0.2, 0.2), "I": Color(1.0, 0.75, 0.15), "D": Color(0.2, 0.9, 0.95),
	"E": Color(1.0, 0.3, 0.6), "F": Color(0.6, 0.3, 0.9), "O": Color(1.0, 0.5, 0.1),
	"U": Color(0.25, 0.45, 1.0), "S": Color(1, 1, 1), "J": Color(0.2, 0.8, 0.3),
	"R": Color(1.0, 0.9, 0.2), "C": Color(1.0, 0.8, 0.3), "B": Color(0.6, 0.5, 0.4),
	"G": Color(0.4, 0.4, 0.4), "L": Color(0.95, 0.8, 0.6),
	"s": Color(0.75, 0.75, 0.75), "t": Color(0.1, 0.9, 0.4),
	"j": Color(0.4, 1.0, 0.4), "b": Color(0.9, 0.5, 1.0), "d": Color(1.0, 0.4, 0.8),
}
var n := 0


func _process(_d: float) -> bool:
	n += 1
	if n < 3:
		return false
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var t: String = args[1] if args.size() > 1 else "platforming"
	var ex: String = args[2] if args.size() > 2 else "LR"
	var tier := int(args[3]) if args.size() > 3 else 2
	var S := int(args[4]) if args.size() > 4 else 4
	var cols := 3 if S <= 4 else 2
	var count := 9 if S <= 4 else 4
	var img := Image.create(cols * (40 * S + 4), (count / cols) * (24 * S + 4), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.12))
	var rng := RandomNumberGenerator.new()
	for i in count:
		rng.seed = (int(args[5]) if args.size() > 5 else 100) + i * 31
		var rows := RoomSynth.synth(t, ex, rng, {"tier": tier})
		var ox := (i % cols) * (40 * S + 4)
		var oy := (i / cols) * (24 * S + 4)
		for y in 24:
			for x in 40:
				var c: String = rows[y][x]
				img.fill_rect(Rect2i(ox + x * S, oy + y * S, S, S), COL.get(c, Color(0.86, 0.88, 0.93)))
	img.save_png(out)
	quit()
	return false
