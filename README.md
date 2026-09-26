# NEWGAME — protótipo (Godot 4.7)

Arcade de stages procedural em pixel art: movimento estilo **Celeste** + combate estilo **Katana Zero**,
mundo gerado por seed (estilo Dead Cells), metroidvania, NPCs com afinidade/casamento, reputação e o Cerco final.

## Como abrir e jogar
1. Baixe o projeto: no GitHub, repositório `coaura-dot/NewGame`, branch **`claude/arcade-stages-procedural-939gyg`** → botão **Code → Download ZIP** (ou `git clone -b claude/arcade-stages-procedural-939gyg <url>`).
2. Godot não precisa instalar: extraia o zip do Godot 4.7 (ou 4.4+) em `C:\Users\igo\Downloads\godot` e rode o `.exe`.
3. No Project Manager: **Import** → selecione o `project.godot` desta pasta → **Import & Edit** → aperte **F5**.
4. No menu: **Treino** (fase fixa com todas as habilidades/armas/magias liberadas) ou **Novo jogo** (mapa-múndi por seed).

## Controles (teclado)
| Ação | Tecla | Ação | Tecla |
|---|---|---|---|
| Mover | A/D ou setas | Pular | Espaço / C |
| Dash (8 direções) | Shift / X | Ataque leve | J / mouse esq. |
| Pesado (segure p/ carregar) | K / mouse dir. | Aparar/Bloquear | L / F |
| Esquiva | Ctrl / V | Magias | Q / E |
| Sigilo (segure e desenhe com o mouse) | R / mouse meio | Poção | H |
| Trocar arma | G | Interagir | W / ↑ / Enter |
| Pausa (equipamento/opções) | Esc | | |

Técnicas: baixo+ataque no ar = **pogo** (recarrega dash); pulo durante dash no chão = **super/hyper**; aparo perfeito = câmera lenta + crítico; baixo+pesado no ar = **Queda Esmagadora**.

## O que já existe (relatório da sessão 1)
- **Movimento** (`scripts/actors/player.gd`): aceleração/inércia, coyote time, buffer de pulo, pulo variável, meia gravidade no ápice, correção de quina, dash 8-dir com super/hyper, deslizar/saltar/escalar parede, pulo duplo, queda esmagadora, plataformas one-way, gravidade invertida (dimensão Espelho).
- **Combate** (compartilhado por jogador e inimigos): 11 classes de arma com frame data em `data/weapon_classes.json` (espada fina, longa, pesada, katana, adagas, katanas duplas, odachi, faca, bastão, lâmina de sangramento, espada+escudo, manoplas); combos, pesado carregado, ataque em dash, ataques aéreos, multi-hit, ritmo (Compasso), costas, ponto fraco, aparar (rebate projéteis), bloqueio, esquiva perfeita, hitstop, tremor, status (queimar, sangrar→hemorragia, frio→congelar, choque, molhado, cegueira, atordoar, marca).
- **Magias** (`data/spells.json`, 24): fogo, gelo, arcano, terra, água, raio em cadeia, poço gravitacional, buraco negro, cegueira, teleporte, luz, psíquico, parar/desacelerar o tempo, pressão, telecinese, eco quântico, retorno no tempo + **sigilos desenhados com o mouse** (dano escala com a precisão).
- **Balanceamento**: `scripts/core/power_budget.gd` pontua armas/magias/loadouts por tier; os testes falham se algo ficar desproporcional.
- **Relíquias combináveis** (`data/buffs.json`), **armaduras em conjuntos** com bônus 2/4/6 peças e afixos aleatórios (`data/armor.json`).
- **Inimigos** (`data/enemies.json`): esqueleto, cão infernal, gato, espectro, lampadário, crânio flamejante, besta, corcel do pesadelo (elite) e Arquidemônio (chefe com 3 fases, ponto fraco, drop exclusivo e reconjuração por item). Usam as mesmas armas/magias do jogador e dropam o que usam.
- **Mundo macro** (`scripts/world/world_generator.gd`): grafo por seed, 3 camadas (céu/superfície/subterrâneo), 15 biomas, hubs, gates de habilidade sempre resolvíveis, regiões opcionais, fendas para 5 dimensões paralelas com física/regras próprias (`data/dimensions.json`). Mapa 3D pixelado com viagem rápida.
- **Fases micro** (`scripts/level/`): salas de templates ASCII (`data/rooms/core.txt`, editáveis à mão) + sintetizador procedural para qualquer combinação de saídas; combate, plataforma, desafio "caminho da dor", puzzle com alavanca, tesouro, segredo atrás de parede quebrável, salas seladas por chave/habilidade, hub, arena de chefe.
- **Social** (`scripts/social/social_system.gd`): NPCs por hub (culturas, papéis, gostos), afinidade/corações, presentes, casamento, resgate em combate, reputação baixa (mercenário/assassino) x alta (missões do rei), e **o Cerco**: escolher uma região e perder todas as outras.
- **Visual**: luzes 2D com sombras, bloom HDR, raios de luz (janelas + screen-space), motion blur, aberração cromática, gradação por dimensão, rastros, partículas de clima — tudo desligável em Opções > Vídeo. Modo assistência (velocidade, dash infinito, invencível).
- **Assets**: placeholders CC0 (Gothicvania/ansimuz, Pixel Frog, Foozle, Kenney). Ver `assets/CREDITS.md`; regerar com `tools/build_assets.py`.

## Testes
`godot --headless --path . res://tests/test_runner.tscn` — 4400+ verificações (dados, balanceamento, mundo, fases, combate, sigilos, inventário, social, save, e um teste que joga a fase de treino com entradas simuladas).

## Pendências conhecidas (próxima sessão)
- Não foi possível testar com janela/controle real nesta sessão: ajustar o *feel* (números no topo de `player.gd`) jogando.
- No teste automático, o dash e a magia disparados por entrada simulada não foram detectados (provável questão de timing do teste — verificar jogando).
- Faltam: música, mais templates de sala por bioma, chefes de horda/puzzle/parkour, IA de mais inimigos, loja/forja (upgrade de itens), arte final (o herói placeholder é humano; trocar pelo "bonequinho").
