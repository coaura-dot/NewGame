class_name Lore
extends RefCounted
## A história de Candelária.
##
## Em Candelária todo lar mantinha uma chama acesa na GRANDE LAREIRA, o
## braseiro de pedra no coração da vila mais antiga. Enquanto ela ardia, a
## Noite Longa ficava nas bordas do mundo.
##
## Numa noite sem lua, o SOPRO do Arquidemônio apagou a Lareira. O fogo se
## partiu em brasas que voaram para todas as regiões: as pequenas foram
## engolidas por monstros; as grandes — as BRASAS-MESTRAS — viraram o coração
## de pesadelos que agora guardam as estradas (cada uma devolve um dom:
## Asas de Cinza, Garras, Coração do Vendaval...).
##
## Do pavio do candelabro da Lareira pingou uma última gota de cera ainda
## quente. Ela abriu os olhos: é o PAVIO, a última chama. Ele junta brasas,
## vence os guardiões e leva as Brasas-Mestras de volta para reacender a
## Lareira — até o Cerco final, quando o Arquidemônio ataca todas as regiões
## de uma vez.

const WORLD_NAME := "Candelária"

## LEMBRANÇAS DA VELADORA — a origem do Pavio, em ordem. Cada sala sombria
## iluminada por inteiro solta a próxima (uma luz que flutua).
## Os Veladores acendiam as lamparinas das estradas com o fogo da Lareira.
## Ilma, a última Veladora, torceu o próprio pavio na última gota de cera:
## o Pavio é a chama dela, passada adiante. As lamparinas guardam o que ela
## lembrava. Os Apagados (inimigos de cera e fuligem) eram gente cuja chama
## o Sopro levou; os guardiões eram os zeladores da Lareira que engoliram as
## Brasas-Mestras para salvá-las — e a escuridão os entortou.
const MEMORIES := [
	["O primeiro fósforo", "Eu tinha seis anos quando a vó me deu o primeiro fósforo. \"Uma chama não se guarda\", ela disse, \"se passa adiante.\" Queimei o dedo. Ela riu e acendeu a lamparina da porta com a minha."],
	["Os Veladores", "Ao entardecer saíamos da Grande Lareira em fila, cada um com a sua vela, e andávamos as estradas acendendo lamparina por lamparina. Quem via a luz no caminho sabia: alguém passou aqui pensando em você."],
	["A canção das lamparinas", "Cantávamos baixinho enquanto acendíamos, para os viajantes saberem que a estrada estava cuidada. \"Pavio curto, noite longa; pavio aceso, casa perto.\" As crianças cantavam junto das janelas."],
	["O mar sem luz", "Naquele outono, as lamparinas da beira do mar começaram a apagar sozinhas. Uma por noite. Nós as acendíamos de novo, e de manhã estavam frias. Ninguém sentia vento nenhum."],
	["Os Apagados", "Quando a chama de alguém se apaga, a pessoa não morre. Fica oca, feito cera sem pavio, andando no escuro atrás de um calor que não lembra mais. Não odeie os Apagados. Eles só esqueceram."],
	["Os zeladores", "O Corvo, a Tecelã, a Lebre, o Golem e o Espelho cuidavam da Lareira desde antes da vila ter nome. Na noite do Sopro, cada um engoliu uma Brasa-Mestra para que ela não apagasse. A escuridão entrou junto."],
	["A noite do Sopro", "Não foi vento. Foi um fôlego — longo, frio, cansado. Todas as chamas da vila deitaram para o mesmo lado e se apagaram. A Lareira resistiu um instante... e então só sobrou uma gota de cera morna no candelabro."],
	["O pavio", "Eu não tinha mais fogo para dar à Lareira. Tinha o meu. Torci o pavio da minha vela dentro daquela gota e soprei devagar, do jeito que a vó ensinou. \"Você vai acordar sozinho. Desculpa. Seja corajoso.\""],
	["Quem sopra", "O Sopro é de alguém que já foi chama. O primeiro que se apagou, há muito tempo, e nunca perdoou os que continuaram acesos. Ele não quer o fogo. Quer que ninguém mais tenha."],
	["Passe adiante", "Se você está lendo as minhas lembranças, é porque acendeu as minhas lamparinas. Obrigada, pequeno. Quando a Lareira voltar a arder, lembre: uma chama não se guarda. Se passa adiante."],
]

const INTRO := [
	"Em Candelária, todo lar guardava uma chama acesa na Grande Lareira.\nEnquanto ela ardia, a Noite Longa não passava das bordas do mundo.",
	"Numa noite sem lua, o Sopro do Arquidemônio apagou a Lareira.\nO fogo se partiu em brasas e voou para todas as regiões.",
	"As brasas pequenas foram engolidas por monstros.\nAs grandes — as Brasas-Mestras — viraram o coração de pesadelos que guardam as estradas.",
	"Do candelabro da Lareira pingou uma última gota de cera, ainda quente...\n...e ela abriu os olhos.",
	"Você é Pavio, a última chama.\nJunte as brasas, vença os guardiões e reacenda a Grande Lareira\nantes que a noite seja eterna.",
]

const BIOME_LINE := {
	"floresta": "As árvores ainda guardam o calor do último verão.",
	"cemiterio": "Aqui as velas dos mortos foram as primeiras a apagar.",
	"castelo": "Os salões esfriaram; os lustres pendem apagados.",
	"catacumbas": "Nem os ossos lembram mais como era a luz.",
	"cidade_gotica": "Lampiões mortos em cada esquina. Alguém sussurra nas janelas.",
	"templo_dourado": "O ouro não brilha sem um fogo que o reflita.",
	"ruinas": "Estas pedras contam da primeira fogueira de Candelária.",
	"deserto": "Sem sol, a areia guarda só um morno de lembrança.",
	"pantano": "Fogos-fátuos imitam brasas para enganar os perdidos.",
	"cidade_ceu": "Tão perto das estrelas — e ainda assim tão escuro.",
	"cidade_subterranea": "Cogumelos brilham onde a Lareira nunca chegou.",
	"cidade_magos": "Os magos tentam acender a noite com fórmulas frias.",
	"fortaleza_orc": "Os orcs juraram guardar as brasas — e guardaram para si.",
	"acampamento_barbaro": "A neve apagou as fogueiras de guerra.",
	"toca_goblin": "Goblins colecionam brasas roubadas como tesouro.",
}

## Falas extras dos moradores (a Lareira, o Sopro, o Pavio).
const TOWN_LORE := [
	"Minha avó acendia o fogão com uma brasa da Lareira. Nunca mais esquentou igual.",
	"Na noite do Sopro, as chamas de todas as casas deitaram para o mesmo lado... e apagaram.",
	"Você é a velinha de que o ancião falou? A última chama da Lareira?",
	"Se as Brasas-Mestras voltarem para a Lareira, dizem que a Noite Longa recua.",
	"Os pesadelos que guardam as estradas têm uma brasa no peito. Dá para ver brilhando.",
	"Não chegue perto do mar à noite. O Sopro vem de lá.",
	"Cuidado com a sua chama, pequeno. Vento, água e medo: é assim que se apaga uma vela.",
	"As pedras de viagem só acordam onde a escuridão foi espantada.",
	"Um portão rúnico só abre para quem carrega o dom certo. Os guardiões levaram todos.",
	"Quando o Arquidemônio perceber que a Lareira volta a arder, ele vem com tudo.",
]


static func region_line(r: Dictionary) -> String:
	if str(r.get("dimension", "prima")) != "prima":
		return "Um reflexo errado do mundo, onde a chama queima ao contrário."
	if r.get("cleared", false):
		return "A escuridão recuou daqui. Suas brasas voltaram a brilhar."
	return BIOME_LINE.get(str(r.get("biome", "")), "")


static func hearth_line(power: float) -> String:
	if power <= 0.0:
		return "Cinzas frias. Lá no fundo, uma brasa teimosa pisca quando você chega perto — como se te reconhecesse.\n\nOs guardiões das estradas levaram as Brasas-Mestras. Traga-as de volta e a Grande Lareira volta a arder."
	if power < 0.34:
		return "Uma chama pequena dança sobre as cinzas. O ar da vila já não parece tão gelado.\n\nAinda faltam Brasas-Mestras. Os portões rúnicos mostram onde os guardiões se escondem."
	if power < 0.67:
		return "O fogo cresce e as casas acendem as janelas de novo. Crianças sentam em volta para ouvir histórias.\n\nLá longe, o Arquidemônio deve estar sentindo o calor."
	if power < 1.0:
		return "Falta pouco. A Lareira ruge e a noite recua até a beira do mar.\n\nMais um guardião, e a chama estará inteira."
	return "A Grande Lareira arde por inteiro, como nos tempos antigos.\n\nMas o Sopro já se ergue no horizonte: o Cerco começou. Escolha que lar defender."


## Boato de morador que aponta para um guardião ainda de pé (dica de rota).
const GIFT_OF := {
	"double_jump": "das Asas de Cinza", "wall_climb": "das Garras", "dash_2": "do Coração do Vendaval",
	"ground_pound": "da Queda Esmagadora", "blink": "do Passo Etéreo", "dimension_shift": "da Chave Dimensional",
}


## Boato de morador que aponta para um guardião ainda de pé (dica de rota).
static func rumor(world: Dictionary, rng: RandomNumberGenerator) -> String:
	var guards: Array = []
	for id in world.get("regions", {}).keys():
		var r: Dictionary = world["regions"][id]
		if r.get("grants", "") != "" and not r.get("cleared", false):
			guards.append(r)
	if guards.is_empty():
		return RngUtil.pick(rng, TOWN_LORE)
	var g: Dictionary = RngUtil.pick(rng, guards)
	return "Dizem que o guardião de %s tem no peito a Brasa-Mestra %s." % [g["name"], GIFT_OF.get(str(g["grants"]), "de um dom antigo")]


## Inscrições nas tábuas de pedra da entrada de cada fase (por bioma).
const TABLETS := {
	"floresta": [
		"Plantamos estas árvores em volta da primeira brasa. Enquanto o fogo morar no bosque, o bosque morará no fogo.",
		"Quem se perder entre as árvores, siga o calor: a Lareira sempre esteve a leste do coração.",
	],
	"cemiterio": [
		"Aqui acendíamos uma vela para cada nome. Na noite do Sopro, todas se apagaram de uma vez — e os nomes começaram a andar.",
		"Os mortos não odeiam a luz. Só esqueceram como ela era.",
	],
	"castelo": [
		"O rei mandou trancar a última brasa no salão mais alto. O Sopro entrou pela janela que ninguém lembrou de fechar.",
		"Lustres apagados, armaduras vazias. Mesmo assim, algo ainda faz a ronda à meia-noite.",
	],
	"catacumbas": [
		"Descemos com tochas para enterrar a escuridão. Ela é que nos enterrou.",
		"Contam que uma brasa rolou por estes túneis e acendeu cada osso por onde passou.",
	],
	"cidade_gotica": [
		"Lei da cidade: nenhuma janela sem vela. Desde o Sopro, a lei é cumprida pelos fantasmas.",
		"Os sinos ainda tocam as horas. Quem toca, ninguém sabe.",
	],
	"templo_dourado": [
		"O ouro deste templo foi feito para refletir a Lareira. Sem ela, reflete só o que tememos.",
		"Os sacerdotes guardavam o fogo em urnas. As urnas agora guardam outra coisa.",
	],
	"ruinas": [
		"Antes da Lareira havia a Fogueira. Antes da Fogueira, uma faísca. Antes da faísca — o Sopro, esperando.",
		"Estas pedras viram a primeira noite de Candelária. Viram também a última?",
	],
	"deserto": [
		"O sol era irmão da Lareira. Quando ela apagou, ele se escondeu de vergonha.",
		"Na areia, as brasas não morrem: dormem. Cave com cuidado.",
	],
	"pantano": [
		"Não siga as luzinhas sobre a água. Brasa de verdade não pisca para você.",
		"O pântano bebeu três fogueiras e ainda tem sede.",
	],
	"cidade_ceu": [
		"Subimos até as nuvens para ficar perto das estrelas. Descobrimos que elas também estão com frio.",
		"Daqui de cima dava para ver todas as chamas de Candelária. Hoje, só uma se move lá embaixo — a sua.",
	],
	"cidade_subterranea": [
		"A Lareira nunca chegou aqui embaixo. Aprendemos a amar a luz dos cogumelos — e a desconfiar de quem desce com fogo.",
		"Quem cava fundo demais ouve o Sopro respirando debaixo do mundo.",
	],
	"cidade_magos": [
		"Fórmula para acender a noite: chama, vontade e alguém que não desista. Faltava o terceiro ingrediente.",
		"Estudamos o Sopro por cem anos. Ele estudou a gente por mil.",
	],
	"fortaleza_orc": [
		"Juramos guardar as brasas da Lareira. Guardamos. Só não juramos devolver.",
		"Força não acende fogo. Mas protege quem acende.",
	],
	"acampamento_barbaro": [
		"Nossas fogueiras de guerra ardiam três dias. A neve do Sopro apagou todas numa noite.",
		"Um guerreiro sem fogo é só um homem com frio.",
	],
	"toca_goblin": [
		"PROPRIEDADE DOS GOBLINS. Brasas roubadas: 1.203. Brasas devolvidas: 0.",
		"Se a chama for pequena e brilhante, é tesouro. Se for pequena e andar, é problema.",
	],
}


static func tablet_text(r: Dictionary, rng: RandomNumberGenerator) -> String:
	var lines: Array = TABLETS.get(str(r.get("biome", "")), TABLETS["ruinas"])
	var t: String = RngUtil.pick(rng, lines)
	var grants := str(r.get("grants", ""))
	if grants != "" and not r.get("cleared", false):
		t += "\n\nMais adiante, um guardião carrega no peito a Brasa-Mestra %s. Sem ela, o portão rúnico da próxima estrada não abre." % GIFT_OF.get(grants, "de um dom antigo")
	elif str(r.get("boss", "")) == "archdemon":
		t += "\n\nO Sopro nasce aqui. Quem trouxer a chama até o fim desta estrada vai encarar o próprio Arquidemônio."
	return t


## Fala quando um guardião aparece / cai.
static func boss_wake(boss_name: String, is_final: bool) -> String:
	if is_final:
		return "%s! O Sopro nasce da boca dele." % boss_name
	return "O guardião desperta: %s. Uma Brasa-Mestra pulsa em seu peito!" % boss_name


static func boss_fall(boss_name: String, grants: String, is_final: bool) -> String:
	if is_final:
		return "%s caiu. O Sopro se desfaz em fumaça fria." % boss_name
	if grants != "":
		return "%s caiu! A Brasa-Mestra %s é sua — leve-a à Grande Lareira." % [boss_name, GIFT_OF.get(grants, "")]
	return "%s caiu!" % boss_name


## Próxima lembrança ainda não vista (índice) ou -1 se já viu todas.
static func next_memory(profile: Dictionary) -> int:
	var seen: Array = profile.get("memories", [])
	for i in MEMORIES.size():
		if not seen.has(i):
			return i
	return -1


## Título em algarismos romanos ("Lembrança III — ...").
static func memory_title(i: int) -> String:
	var roman := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
	return "Lembrança %s — %s" % [roman[clampi(i, 0, roman.size() - 1)], MEMORIES[i][0]]
