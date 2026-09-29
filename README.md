# NEWGAME — protótipo (Godot 4.7)

Arcade de stages procedural em pixel art **320x180**: movimento de **Celeste** + combate de **Hollow Knight**
(com toques de Katana Zero), mundo gerado por seed (estilo Dead Cells), metroidvania, NPCs com afinidade/casamento,
reputação e o Cerco final.

## Como abrir e jogar
1. Baixe o ZIP direto: https://github.com/coaura-dot/NewGame/archive/refs/heads/claude/awesome-cannon-s9w4t8.zip e extraia numa pasta NOVA (não por cima da antiga).
2. Godot 4.7 (4.4+ funciona): extraia o zip do Godot em `C:\Users\igo\Downloads\godot` e rode o `.exe` (não precisa instalar).
3. No Project Manager: **Import** → `project.godot` da pasta nova → **Import & Edit** → **F5**. O projeto certo aparece como **"NewGame 320 (v0.2)"** e o menu mostra "v0.2 (320x180)". Se aparecer só "NewGame", é a versão antiga.
4. No menu: **Treino** (fase fixa com tudo liberado) ou **Novo jogo** (mapa-múndi por seed).

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
- **Herói novo**: criaturinha de ~13 px (máscara clara, orelhas pontudas, manto) com **expressões**: olhos procedurais
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

## Testes
`godot --headless --path . res://tests/test_runner.tscn` — 5500+ verificações (dados, balanceamento, mundo, fases,
combate, sigilos, inventário, social, save e um teste que joga o treino: anda, pula, dash, ataca, magia, aparo).
Prints do jogo rodando: `godot --path . --script tools/screenshot.gd -- <prefixo> [treino|menu]`.

## Pendências (próxima sessão)
- Ajustar o *feel* jogando (números no topo de `scripts/actors/player.gd`; golpes em `data/weapon_classes.json`).
- Os templates de sala (`data/rooms/core.txt`) são da escala antiga: funcionam, mas vale redesenhá-los para 8 px
  (salas mais densas, desafios de precisão estilo Celeste) e criar salas maiores que a tela para combate.
- Menus/diálogos ainda são diagramados em 480x270 e reduzidos (legíveis, mas não pixel-perfeitos) — refazer em 320x180.
- Arte: mais quadros de animação para inimigos, efeitos de magia específicos, variações de tiles; música.
- Chefes de horda/puzzle/parkour, IA de mais inimigos, loja/forja.
