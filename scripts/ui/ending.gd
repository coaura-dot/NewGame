extends Control
## Tela final: o que foi salvo e o que se perdeu no Cerco — e o destino da
## Grande Lareira.


func _ready() -> void:
	Audio.music("lareira", 3.0)
	theme = UIKit.theme()
	UIKit.fit(self)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# a Lareira acesa lá embaixo: um brilho quente no escuro
	var glow := TextureRect.new()
	glow.texture = LightUtil.soft()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.size = Vector2(420, 220)
	glow.position = Vector2(30, 170)
	glow.modulate = Color(1.0, 0.5, 0.18, 0.4)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	add_child(glow)
	var summary: Dictionary = Game.social.get("siege", {}).get("summary", {})
	var v := UIKit.vbox(5)
	v.add_child(UIKit.title("A Última Chama", 32))
	v.add_child(UIKit.label("Você defendeu %s. Lá, a Grande Lareira ainda arde." % summary.get("chosen_name", "a região"), 14, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var lost: Array = summary.get("lost_regions", [])
	var t := UIKit.label("%d regiões caíram na Noite Longa. Suas ruas agora são cinzas frias." % lost.size(), 12, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(t)
	for n in summary.get("lost_npcs", []).slice(0, 8):
		var line := "%s, %s" % [n["name"], n["title"]]
		if n.get("married", false):
			line += " — seu amor"
		elif int(n["affinity"]) >= 60:
			line += " — confiava em você"
		v.add_child(UIKit.label(line, 10, Color(0.8, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	# lamparinas das estradas que o Pavio acendeu pelo caminho
	var lit: int = Game.profile.get("ow_lamps", {}).size()
	var total := 0
	if not Game.world.is_empty():
		total = OverworldGen.for_world(Game.world).get("road_lamps", []).size()
	if total > 0:
		v.add_child(UIKit.label("Lamparinas das estradas acesas: %d/%d" % [lit, total], 11, Color(1.0, 0.75, 0.45), HORIZONTAL_ALIGNMENT_CENTER))
	var epi := UIKit.label(epilogue(Game.profile.get("memories", []).size(), Lore.MEMORIES.size()), 11, Color(1.0, 0.8, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	epi.autowrap_mode = TextServer.AUTOWRAP_WORD
	epi.custom_minimum_size = Vector2(420, 0)
	v.add_child(epi)
	v.add_child(UIKit.label("Obrigado por jogar este protótipo.", 10, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var c := CenterContainer.new()
	c.add_child(UIKit.button("Voltar ao menu", func(): Game.goto(Game.SCENE_MENU), 140))
	v.add_child(c)
	add_child(UIKit.centered(v))
	UIKit.focus_first(self)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 2.0)



## Epílogo pelas Lembranças da Veladora encontradas (todas = final verdadeiro).
static func epilogue(found: int, total: int) -> String:
	if found >= total:
		return "Na manhã seguinte, uma chama pequena se separa da Lareira e sai pela estrada, acendendo lamparina por lamparina. Ilma teria sorrido: uma chama não se guarda — se passa adiante."
	if found >= total / 2:
		return "Às vezes, perto das lamparinas acesas, você ouve alguém cantar baixinho: \"pavio aceso, casa perto\". Ainda há lembranças esperando no escuro."
	return "Enquanto houver uma chama acesa, Candelária lembra da luz."
