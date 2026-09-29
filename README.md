# NEWGAME — protótipo (Godot 4.7)

**Pavio, a última chama.** Arcade de stages procedural em pixel art **320x180**: movimento de **Celeste** + combate de
**Hollow Knight/Dead Cells** (com toques de Katana Zero), um **mapa-múndi explorável** estilo Stardew Valley gerado por
seed, metroidvania, NPCs com afinidade/casamento, reputação e o Cerco final.

> Em Candelária, todo lar guardava uma chama acesa na **Grande Lareira**. O Sopro do Arquidemônio a apagou e o fogo se
> partiu em brasas — as maiores, as **Brasas-Mestras**, viraram o coração dos guardiões das estradas. Você é o **Pavio**,
> uma velinha nascida da última gota de cera quente do candelabro: junte as brasas, vença os guardiões e reacenda a Lareira.

## Como abrir e jogar
1. Baixe o ZIP direto: https://github.com/coaura-dot/NewGame/archive/refs/heads/claude/awesome-cannon-s9w4t8.zip e extraia numa pasta NOVA (não por cima da antiga).
2. Godot 4.7 (4.4+ funciona): extraia o zip do Godot em `C:\Users\igo\Downloads\godot` e rode o `.exe` (não precisa instalar).
3. No Project Manager: **Import** → `project.godot` da pasta nova → **Import & Edit** → **F5**. O projeto certo aparece como **"NewGame 320 (v0.2)"** e o menu mostra "v0.2 (320x180)". Se aparecer só "NewGame", é a versão antiga.
4. No menu: **Treino** (fase fixa com tudo liberado) ou **Novo jogo** (introdução + mapa-múndi explorável por seed).

## Controles no mapa-múndi
| Ação | Tecla | Ação | Tecla |
|---|---|---|---|
| Andar (8 direções) | WASD / setas | Correr | Shift / X |
| Falar / entrar / ler placa | Espaço / Enter / J | Mapa 3D (viagem rápida, Cerco) | M / Tab |
| Pausa (equipamento/opções) | Esc | | |

## Controles (teclado)
| Ação | Tecla | Ação | Tecla |
|---|---|---|---|
| Mover | A/D ou setas | Pular (segure = mais alto) | Espaço / C |
| Dash (8 direções) | Shift / X | Golpe (↑ = pra cima, ↓ no ar = pogo) | J / Z / mouse esq. |
| Pesado (segure = arte da lâmina) | K / mouse dir. | Aparar/Bloquear | L / F |
| Esquiva (invencível) | Ctrl / V | Magias | Q / E |
| Sigilo (segure e desenhe com o mouse) | R / mouse meio | Foco: segure = cura / toque = poção | H |
| Trocar arma | G | Interagir / sentar no banco | W / ↑ / Enter |
| Pausa (equipamento/opções) | Esc | | |

Técnicas: ↓+golpe no ar em inimigo/espinho = **pogo** (recarrega dash e pulo); pular durante dash no chão = **super**
(dash diagonal para baixo + pulo = **hyper**); dash para cima + pulo encostado na parede = **wallbounce**;
↓+pesado no ar = **Queda Esmagadora**; aparo perfeito = câmera lenta + crítico.

## O que mudou nesta sessão (sessão 2)
- **Resolução interna 320x180** (como Celeste), ampliada em escala inteira. O mundo é renderizado numa tela interna;
  a câmera anda em pixels inteiros e a fração vira deslocamento da imagem ampliada (rolagem suave sem tremer a pixel art).
  Câmera presa à sala atual, deslizando para a próxima ao atravessar (estilo Celeste). Renderizador GL Compatibility.
- **Herói novo** (substituído pelo Pavio na sessão 6): criaturinha de ~13 px (máscara clara, orelhas pontudas, manto) com **expressões**: olhos procedurais
  (piscar, feliz, bravo, cansado, olhar pra cima/baixo, susto, morto), **balões de emoção** (! ? !? … ♥ ♪ zzz raiva,
  suor, brilho, tontura), squash & stretch e **cachecol** com física cuja cor mostra os dashes (vermelho/azul/rosa).
  Parado muito tempo, ele senta e cochila.
- **Física do Celeste** com os números originais (tiles de 8 px) e movimento em **pixels inteiros**; correção de quina,
  coyote, buffer, meia gravidade no ápice, queda rápida, deslize de parede que acelera, escalada com estamina.
- **Combate estilo Hollow Knight**: golpes **não travam** o corpo, direcionais, recuo ao acertar, pogo, faísca de
  impacto + hitstop curto, inimigos recuam ao apanhar; dano no herói congela, treme e pisca. Foco (orbe) cura uma máscara.
  Armas pesadas só reduzem a velocidade durante o golpe.
- **Arte toda nova e limpa**, gerada por código (`tools/pixel_art.py`): criaturas no lugar de humanos (inimigos e NPCs:
  povo-camundongo, javalis, diabretes, corujas magas, ursinhos bárbaros, passarinhos celestes), tiles 8x8 com autotile por
  bioma (15 biomas), fundos parallax chapados e claros. Tela sem escurecer, poucas partículas.
- **Efeitos opcionais** (Opções > Vídeo): bloom HDR, raios de luz, borrão de movimento, luzes/sombras, vinheta, aberração,
  números de dano (desligado por padrão), partículas de ambiente, câmera suave, escala inteira.
- HUD em pixel art: máscaras de vida, orbe de foco, dashes, brasas, magias, barra de chefe.

## Sessão 3 — parkour frenético + combate no meio do parkour
- **Salas geradas por "batidas" de parkour** (`scripts/level/room_synth.gd`): pulinhos entre pilares, salto longo
  correndo, cadeia de **Orbes de Impulso**, vão de **cristal de dash**, **plataformas que desabam**, **plataforma móvel**,
  corredor de **serra**, **chaminé** de salto de parede, **escalada** e **mergulho** — seguindo um perfil de altura
  (morro, vale, subida, descida, zigue-zague) com teto de caverna acompanhando o caminho. Inimigos ficam nas ilhas
  do percurso e voadores sobre os fossos (alvos de pogo).
- **Arenas**: suspensa sobre espinhos (ilhas + orbes), torre de andares e chão; salas de combate fecham e mandam
  **ondas** de inimigos.
- **Validador de travessia** (`scripts/level/room_reach.gd`): toda sala é conferida com o pulo/dash REAIS do herói
  (medidos no motor por `tests/test_movimento.gd`: pulo 28 px, 8 tiles correndo, super a 260 px/s), entendendo orbes,
  cristais, molas, chaminés e plataformas móveis. Sala que não passa é refeita.
- **Mecânicas**: Orbe de Impulso (golpeie para quicar ~4 tiles e recarregar dash/pulo; dash atravessando recarrega),
  **pogo em espinhos e serras**, **hit-stall** (acertar no ar segura a queda, até 3x por salto — combos aéreos),
  golpe deslizando na parede sai para fora dela, **crânio mergulhador** que persegue e dá rasantes.
- **Perfeccionismo**: morrer volta para a entrada da sala em <1 s; nas salas de desafio, qualquer espinho volta ao
  começo da sala; cada fase mede **tempo, mortes e golpes sofridos** e dá **nota S/A/B/C**; cronômetro opcional
  (Opções > Jogabilidade).
- Ferramentas: `tools/room_sheet.gd` (prancha de salas geradas), `tools/level_map.gd` (mapa da fase),
  `tools/screenshot.gd -- <prefixo> salas` (print de cada sala do treino).

## Sessão 4 — salas complexas, combate rítmico e fugas
- **Sala em zigue-zague de 3 andares** (usa a tela inteira): entra embaixo, sobe no fim do andar, volta pelo do
  meio, sobe de novo e desce pelo poço da saída. Cada andar tem seu desafio (fossos, espinhos no piso e no teto,
  tábuas que desabam sobre o andar de baixo, serras, torretas e inimigos).
- **Novas batidas de parkour**: **espinhos de pogo** sobre o fosso (↓+golpe em cada um para atravessar),
  **serra que sobe e desce** no meio do vão (pule no compasso) e **túnel de dash** (teto de espinhos + buraco:
  só passa de dash). Percursos seguem perfis mais altos (morro, platô, subida, dois morros, zigue-zague) e o
  teto da caverna fica mais perto — salas mais densas.
- **Torreta rítmica**: presa em paredes/tetos, atira sempre no mesmo compasso (o olho acende antes do tiro).
  **Golpeie a bala para rebatê-la**: rebater recarrega o dash, segura a queda no ar (↓+golpe quica) e a bala
  volta sozinha para a torreta e a destrói. Vale para magias inimigas também.
- **Caçada**: parte das salas de plataforma fecha as portas até você derrotar todos os inimigos espalhados
  pelo percurso — combate obrigatório no meio do parkour.
- **Fuga**: em algumas salas uma **muralha de espinhos** avança a partir da porta de entrada. Não pare! Se se
  machucar, volta ao começo da sala e a muralha recomeça.
- **Golpe em velocidade**: acertar enquanto se move muito rápido (super, rasante, quique) causa +25% de dano
  com faísca dourada — manter o embalo compensa.
- **Sala Zigue-zague** (nova): o chão INTEIRO é espinho. Atravesse encadeando nós que alternam alto/baixo —
  orbes, espinhos de pogo, sinos, penas, cristais — com estalactites/estalagmites fechando o canal e voadores
  no meio (abater no ar recarrega o dash e dá um quique). Pode ser caçada (fecha até matar todos).
- **Fases FRENESI** (~40% das regiões, aparece no mapa-múndi e no título da fase): o caminho é dominado por
  salas zigue-zague, com arenas suspensas sobre espinhos intercaladas. O Treino tem 2 salas zigue-zague.
- **Resets de pulo e dash**: **Pena verde** (encoste no ar: +1 pulo, mesmo sem pulo duplo), **Sino** (golpeie:
  recarrega o dash e dá um pulo sem mudar a trajetória; ↓+golpe = pogo), **Cristal rosa** (2 dashes), além do
  Orbe dourado (quique) e do Cristal azul. O HUD mostra dash extra (rosa) e pulo extra (verde).
- **Inércia**: acima da velocidade máxima o embalo dura bem mais no ar (segurando ou soltando a direção),
  pousar e pular logo em seguida mantém a velocidade (bunny hop), golpear correndo rápido não te freia.
- **CADEIA aérea**: cada orbe, pogo, sino, pena, cristal, abate, rebate ou salto de parede sem tocar o chão
  soma na cadeia (mostrada no topo da tela). Ao pousar, cadeias de 3+ dão brasas e foco (bônus em 6 e 10);
  se machucar, perde. A maior cadeia aparece no resumo da fase.
- **Torre de escalada**: poços com saída para cima viram escaladas com degraus alternados, orbes/sinos/penas,
  espinhos de pogo, tábuas, paredes irregulares com espinhos e torretas atravessando o poço.
- Validador entende espinhos de pogo; salas em andares/caçada/fuga não viram salas largas.
- `tools/screenshot.gd -- <prefixo> salas <seed> <bioma> <tier>` tira print de cada sala com outra seed/bioma;
  `tools/room_sheet.gd -- <png> <tipo> LR <tier> 8` gera prancha ampliada.

## Sessão 5 — parede e sons
- **Parede recarrega o dash** (e o pulo) ao encostar no ar — uma vez por toque (saia e volte para recarregar).
- **Chute de parede**: dash + pulo encostado numa parede = impulso forte para longe, com embalo.
- Salas adaptadas: paredes suspensas para quicar, chaminés largas no desafio, espinhos nas faces de pilares
  e da torre para manter a dificuldade; o validador entende a recarga na parede.
- **Sons próprios** (sintetizados por `tools/sfx_gen.py`) para pulo, dash, parede, orbe, sino, pena, cristal,
  pogo, cadeia (nota sobe a cada elo), golpes, abates, torreta, muralha, magias por escola etc.
- Pendente: efeitos visuais novos em magias/golpes e personagens novos com seleção.

## Sessão 6 — Pavio, mapa-múndi explorável, duelos e a história
- **Herói novo: Pavio**, uma velinha de cera com poncho e cachecol. A **chama na cabeça** é procedural e mostra o humor:
  tremula, deita contra o movimento (no dash fica quase na horizontal), cresce feliz/focando/na cadeia, encolhe ferido ou
  com pouca vida, vira fumaça na morte e reacende ao renascer. Bochechas, boquinha, **gola na cor dos dashes** e a luz do
  herói presa à chama. A vida no HUD virou **velinhas**. O cachecol voltou a aparecer (ficava atrás do cenário).
- **Mapa-múndi explorável** (visão de cima): a ilha é gerada do grafo do mundo — territórios por bioma separados por mata
  fechada, rochedos ou o vazio do céu; **estradas** (terra, ponte de luz, trilho de túnel, cristais de fenda) com pontes;
  **portões rúnicos** que só abrem com o dom de um guardião; **vilas** com praça, casas, poço, postes e moradores que
  passeiam e conversam; **entradas das fases** (portão de pedra, caverna, plataforma celeste, fenda); placas; pedras de
  viagem; névoa no desconhecido; minimapa; **dia e noite** (postes, janelas e a chama do Pavio iluminam). Entrar numa fase
  corta para ela; ao terminar você volta ao mesmo ponto.
- **Combate de duelo** (Dead Cells + Hollow Knight): antes de cada golpe o inimigo brilha **amarelo** (dá para aparar) ou
  **vermelho** (esquive), com "!"/"!!", som e a arma cintilando. Combos de 1-3 golpes com pausas variadas; depois do golpe
  ele fica **exposto** (janela de punição). Bater sem parar faz o inimigo **erguer a guarda** e contra-atacar — golpe
  **pesado quebra a guarda**, pogo e golpes pelas costas passam; feras recuam e dão o bote. **Aparo perfeito** = contra-golpe
  crítico; **esquiva perfeita** = contra-ataque crítico. O combo do herói tem um respiro curto no fim.
- **Efeitos**: dash com anel, riscos e **fita colorida**; cortes com gradiente e faíscas; **marca de corte** no alvo;
  magias com partículas por escola (fogo = brasas, gelo = estilhaços, raio = zigue-zague, sombra = espiral, cura = cruzes,
  terra = pedras, água = gotas, arcano = estrelas); status visíveis (queimando, congelado, eletrizado).
- **Sons**: dash novo ("fwip" curto e brilhante, sem grave); golpes, dano e passos mais suaves, sem chiado; sons de
  telegrafia (amarelo/vermelho) e de guarda.
- **História**: introdução em cartões, a Grande Lareira reacende conforme os guardiões caem, frases por região, tábuas de
  pedra com inscrições na entrada das fases, falas novas dos moradores (com pistas de onde estão os guardiões) e o final
  "A Última Chama".
- **Fontes** com acentos minúsculos corretos (antes "CandelÁria").
- Ferramentas: `tools/overworld_art.py` (arte do mapa), `tools/fix_font_accents.py`, novos modos em
  `tools/screenshot.gd` (`heroi`, `efeitos`, `duelo`, `mapa`, `intro`, `regiao`).

## Sessão 7 — guardiões, inimigos de duelo, trilha sonora e comércio nas vilas
- **Cinco guardiões únicos**, um por Brasa-Mestra, cada um com um duelo próprio (antes todos eram o Corcel):
  - **Corvo das Cinzas** (Asas de Cinza): rasantes e leques de penas (rebata!); na 2ª fase mergulha no chão e solta ondas.
  - **Tecelã das Frestas** (Garras): mordidas em dupla, teias que deixam lento, bote vermelho; chama filhotes e derruba
    casulos do teto.
  - **Lebre do Vendaval** (Coração do Vendaval): três investidas seguidas (a 3ª é vermelha) e depois fica tonta.
  - **Golem de Pedra-Pomes** (Queda Esmagadora): pancada amarela, tremor com ondas de choque (pule!), chuva de pedras
    com aviso no chão; a **brasa nas costas** é o ponto fraco.
  - **Espelho Etéreo** (Passo Etéreo): some e reaparece pelas suas costas; ilusões atiram estilhaços; anel vermelho.
  Todos seguem o duelo (amarelo = apare, vermelho = esquive, janela de punição depois de cada golpe) e mudam de fase na
  metade da vida. Guardiões que andam lutam em arenas sem fosso de espinhos.
- **Arquidemônio de Cinzas** refeito no mesmo motor de duelo, com **três fases** (vida 100% / 66% / 33%): garra
  (amarela), chamas em leque que crescem a cada fase (rebata!), sopro infernal e poço gravitacional (vermelhos),
  mergulho com ondas de choque, chuva de meteoros, servos de fogo e o passo que reaparece pelas suas costas. Chefes
  voadores trocam de lado entre um golpe e outro e não saem da sala.
- **Inimigos comuns no motor de duelo** (aparecem nas fases de cada bioma):
  - **Lanceiro de Cera**: alcance comprido; estocada e estocada dupla amarelas (apare), **varrida baixa vermelha** (pule).
    Entre por dentro da lança. Ergue a guarda se você martelar.
  - **Arqueira de Fuligem**: mantém distância; flecha e trio de flechas amarelos (rebata de volta!) e **chuva de flechas
    vermelha** com aviso no chão (saia de baixo).
  - **Bruto de Carvão**: pesado e lento; pancada amarela (apare para quebrar a postura), **salto vermelho** que solta
    ondas de choque (pule) e um empurrão que joga você longe. Fraco a água e gelo, quase imune a fogo.
  Sem ver o herói, eles patrulham em vez de ficar parados.
- **Bichos novos**: **Mariposa de Cinza** (circula a chama, mergulha nela e bebe foco), **Guarda de Cinzas** (escudo
  sempre erguido; golpe pesado quebra, pogo e costas passam) e **Sopro Errante** (sopra uma rajada que empurra e
  esfria — golpeie para rebater).
- **Trilha sonora**: 6 faixas compostas e sintetizadas por código (`tools/music_gen.py`) com crossfade por contexto —
  Candelária (mapa de dia), Noite, Estrada (fases), Frenesi (fugas), Guardião (chefes e Cerco) e Lareira (vilas, menu e
  final).
- **Vida no mapa-múndi**: água brilhando, fumaça nas chaminés, borboletas e pássaros de dia, vaga-lumes à noite, clima
  por bioma (folhas, neve, areia, bolhas, cintilar) e moradores que vão para casa quando anoitece.
- **Comércio nas vilas** (as brasas agora servem para algo): **Loja** do Mercador (estoque da região que muda a cada fase
  concluída), **Poções** da Curandeira, **Forja** da Ferreira (+10% de dano por nível da arma, até +5; do 3º nível em
  diante pede Fragmento Rúnico; reforço de armaduras), **Estudar** com o Sábio (sobe o nível das magias), **Vender** ao
  Receptador (armas e armaduras sobrando), **Canção da Coragem** do Bardo (+15% de dano na próxima fase) e **Histórias**
  do Ancião/Sábio. Painéis com fundo escurecido.
- Ferramentas: `tools/guardian_art.py` (arte dos guardiões), `tools/foe_art.py` (arte dos inimigos comuns novos),
  `screenshot.gd` modos `chefe <id>` (qualquer inimigo; nasce num trecho de chão plano da sala) e `loja`.

## Testes
`godot --headless --path . res://tests/test_runner.tscn` — 6200+ verificações (dados, balanceamento, mundo, fases,
combate, sigilos, inventário, social, save e um teste que joga o treino: anda, pula, dash, ataca, magia, aparo).
Prints do jogo rodando: `godot --path . --script tools/screenshot.gd -- <prefixo> [treino|menu]`.

## Pendências (próxima sessão)
- Ajustar o *feel* jogando (números no topo de `scripts/actors/player.gd`; golpes em `data/weapon_classes.json`).
- Os templates de sala (`data/rooms/core.txt`) são da escala antiga: funcionam, mas vale redesenhá-los para 8 px
  (salas mais densas, desafios de precisão estilo Celeste) e criar salas maiores que a tela para combate.
- Menus/diálogos ainda são diagramados em 480x270 e reduzidos (legíveis, mas não pixel-perfeitos) — refazer em 320x180.
- Arte: mais quadros de animação para inimigos, efeitos de magia específicos, variações de tiles; música.
- Chefes de horda/puzzle/parkour, mais inimigos comuns; casas com interior no mapa-múndi.
