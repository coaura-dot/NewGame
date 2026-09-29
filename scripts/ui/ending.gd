extends Control
## Tela final: o que foi salvo e o que se perdeu no Cerco — e o destino da
## Grande Lareira.


func _ready() -> void:
	theme = UIKit.theme()
	UIKit.fit(self)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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
	var epi := UIKit.label("Enquanto houver uma chama acesa, Candelária lembra da luz.", 11, Color(1.0, 0.8, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(epi)
	v.add_child(UIKit.label("Obrigado por jogar este protótipo.", 10, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var c := CenterContainer.new()
	c.add_child(UIKit.button("Voltar ao menu", func(): Game.goto(Game.SCENE_MENU), 140))
	v.add_child(c)
	add_child(UIKit.centered(v))
	UIKit.focus_first(self)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 2.0)
