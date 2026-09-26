# NEWGAME — protótipo (Godot 4.7)

Arcade de stages procedural em pixel art **320x180**: movimento de **Celeste** + combate de **Hollow Knight**
(com toques de Katana Zero), mundo gerado por seed (estilo Dead Cells), metroidvania, NPCs com afinidade/casamento,
reputação e o Cerco final.

## Como abrir e jogar
1. Baixe o projeto: no GitHub, repositório `coaura-dot/NewGame`, branch **`claude/awesome-cannon-s9w4t8`** → **Code → Download ZIP**.
2. Godot 4.7 (4.4+ funciona): extraia o zip do Godot em `C:\Users\igo\Downloads\godot` e rode o `.exe` (não precisa instalar).
3. No Project Manager: **Import** → `project.godot` desta pasta → **Import & Edit** → **F5**.
4. No menu: **Treino** (fase fixa com tudo liberado) ou **Novo jogo** (mapa-múndi por seed).

## Controles (teclado)
| Ação | Tecla | Ação | Tecla |
|---|---|---|---|
| Mover | A/D ou setas | Pular (segure = mais alto) | Espaço / C |
| Dash (8 direções) | Shift / X | Golpe (↑ = pra cima, ↓ no ar = pogo) | J / mouse esq. |
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

## Testes
`godot --headless --path . res://tests/test_runner.tscn` — 4416 verificações (dados, balanceamento, mundo, fases,
combate, sigilos, inventário, social, save e um teste que joga o treino: anda, pula, dash, ataca, magia, aparo).
Prints do jogo rodando: `godot --path . --script tools/screenshot.gd -- <prefixo> [treino|menu]`.

## Pendências (próxima sessão)
- Ajustar o *feel* jogando (números no topo de `scripts/actors/player.gd`; golpes em `data/weapon_classes.json`).
- Os templates de sala (`data/rooms/core.txt`) são da escala antiga: funcionam, mas vale redesenhá-los para 8 px
  (salas mais densas, desafios de precisão estilo Celeste) e criar salas maiores que a tela para combate.
- Menus/diálogos ainda são diagramados em 480x270 e reduzidos (legíveis, mas não pixel-perfeitos) — refazer em 320x180.
- Arte: mais quadros de animação para inimigos, efeitos de magia específicos, variações de tiles; música.
- Chefes de horda/puzzle/parkour, IA de mais inimigos, loja/forja.
