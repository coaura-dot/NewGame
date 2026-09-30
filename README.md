# NEWGAME — protótipo (Godot 4.7) · *Cindária — a última brasa*

Ação 2D em pixel art com **movimento de Celeste** e **combate frenético** (Katana Zero + Hollow Knight + Dead Cells):
dash → corte → dash, mundo **contínuo e explorável** gerado por seed (céu, superfície e subsolo), fases grandes
estilo Dead Cells montadas com uma biblioteca de estruturas feitas à mão, história, NPCs, reputação e o Cerco final.

## Como abrir e jogar
1. Baixe o projeto: no GitHub, repositório `coaura-dot/NewGame`, branch **`claude/arcade-stages-procedural-939gyg`** → botão **Code → Download ZIP** (ou `git clone -b claude/arcade-stages-procedural-939gyg <url>`).
2. Godot não precisa instalar: extraia o zip do Godot 4.7 (ou 4.4+) em `C:\Users\igo\Downloads\godot` e rode o `.exe`.
3. No Project Manager: **Import** → selecione o `project.godot` desta pasta → **Import & Edit** → aperte **F5**.
4. No menu: **Novo jogo** (abertura + mundo gerado pela seed), **Treino** (tudo liberado), **Arena de chefes** ou **Explorar mundo (debug)** (tudo liberado, viagem rápida para qualquer região).

## Controles (teclado)
| Ação | Tecla | Ação | Tecla |
|---|---|---|---|
| Mover | A/D ou setas | Pular | Espaço / C |
| Dash (8 direções) | Shift / X | Ataque leve | J / mouse esq. |
| Pesado (segure p/ carregar) | K / mouse dir. | Aparar/Bloquear | L / F |
| Esquiva | Ctrl / V | Magias | Q / E |
| Sigilo (segure e desenhe com o mouse) | R / mouse meio | Poção | H |
| Trocar arma | G | Interagir / Ler | W / ↑ / Enter |
| Pausa (equipamento/Códice/opções) | Esc | **Mapa** (viagem rápida) | M / Tab |

Técnicas: **atacar durante o dash = Corte-Relâmpago** (atravessa cortando, em qualquer direção); **todo acerto recarrega o dash e o pulo** (dash → corte → dash...); golpear **Lanternas de Ímpeto** também recarrega; baixo+ataque no ar = **pogo**; pulo durante dash no chão = **super/hyper**; aparo perfeito = câmera lenta + crítico (e rebate o tiro do Atirador de volta, fatal); baixo+pesado no ar = **Queda Esmagadora**.

## Sessão 8 — Lume, o capítulo 1 feito à mão e a ambientação estilo Hollow Knight
![personagens](docs/lume.png)
- **Novo protagonista: Lume, o Lampadeiro.** A cabeça é uma lanterna de ferro e vidro; dentro dela vive a última brasa de Cindária, um espírito de chama com dois olhos — é o rosto do Lume (expressões de determinação, susto, dor, sono). Argola no topo com fitas carmim, poncho azul-petróleo. O vidro racha quando ele apanha, a luz da lanterna enfraquece com a vida baixa e apaga na morte. **Umbral**, o chefe-duelista, é o reflexo dele: vidro negro e chama azul-fria.
- **Mundo fixo de Cindária** (`data/world.json`): 13 regiões com vizinhos, chefes e habilidades pensados à mão (como no Hollow Knight), com um caminho de história: Cinzal → Galerias Apagadas → Bosque Sussurrante (pulo duplo) → Vésper...
- **Capítulo 1 feito à mão** (`data/maps/*.txt`, editáveis): **Cinzal** (capela do despertar, praça do braseiro, poço, torre do sino, adega secreta), **Mata do Assobio**, **Galerias Apagadas** (encruzilhada dos lampiões, galeria dos vitrais, poço dos ecos, salão das estátuas, cofre secreto, covil do Colosso, ponte partida...) e **Bosque Sussurrante** (Árvore-Mãe, lagoa dos vaga-lumes, clareira dos fungos, ninho da Rainha). Cada lugar tem nome, forma e propósito; tudo é testado para ser alcançável nos dois sentidos.
![capítulo 1](docs/capitulo1.jpg)
- **Ambientação estilo Hollow Knight**: terrenos escuros por área com borda viva, fundos pintados novos (arcadas dos Lampadeiros na névoa azul, troncos e cogumelos luminosos, crepúsculo cor de brasa com o farol de Ignara apagado), **silhuetas em primeiro plano** com parallax, cinza caindo, vinheta e cor por área, e **cenografia** (casas, poço, estátuas, vitrais acesos, velas, sino, raízes, fungos, gaiolas...).
- **Lampiões e braseiros**: o Lume é um Lampadeiro — ele **acende os lampiões apagados** (luz para sempre, brasas, o povo nota) e os **braseiros** que viram santuários.
- **História com personagens e cenas**: Vovó Borralha, Fuligem (e o pai dele, Tordo, preso na gaiola da Rainha), Mira a cartógrafa (vende o mapa completo das regiões), Sir Gaspar, o Pavio Apagado, o misterioso Assobiador e Umbral. Falas que mudam com o progresso, caixa de diálogo, **cenas** com barras de cinema e câmera (o despertar do Lume, Umbral do outro lado do abismo, o despertar do Colosso e da Rainha) e objetivo da história na HUD.
![história](docs/historia.jpg)
- **Inimigos nativos**: Oco (aldeão esvaziado pela Maré), Rastejante (casca de pedra), Traça-Cinza (atraída pela luz do Lume), Musgoso (fica de tocaia) e Vaga-lume Ferrão. Inimigos podem dormir ou esperar de tocaia e param durante as cenas.
- Correção: o jogo fechava com "Nonexistent function 'body_center' in base ImpetoOrb" (magias/relíquias acertando a Lanterna de Ímpeto).

## Sessão 7 — escala 50% maior e regiões estilo Hollow Knight
![regiões](docs/regioes.jpg)
- **Tudo 50% maior** na tela: arte agora em densidade 3x (tiles de 24 px, personagens com ~45 px), mesma física.
- **Regiões feitas de LUGARES com propósito**, não mais salas quadradas com plataformas: santuário (ou vila) no centro, **covil do guardião** ou **coração da região** no ponto mais distante, passagens para as regiões vizinhas com placa do destino, e no caminho trilhas com relevo sob o céu, galerias, poços verticais, salões com mesas de pedra ou escadarias e sacadas, ravinas, lagos, ninhos da espécie local, **cofres atrás de paredes rachadas ou portões de habilidade**, mirantes, provas e **atalhos que só abrem por uma alavanca do outro lado**. Cada lugar tem nome ("Poço dos Vaga-lumes", "Colmeia de Gato do Abismo"...).
- **Ecossistema**: patrulhas nos caminhos, voadores nos espaços abertos, atiradores nas saliências altas, a espécie do ninho no ninho, nenhum inimigo no santuário. **Marcos visuais** (estátua colossal, árvore ancestral, cristais gigantes) no coração de cada região.
- **Mundo com nexo**: biomas vizinhos combinam (floresta → pântano/ruínas, cidade → castelo...), o subsolo pertence à região de cima (esgotos sob a cidade, catacumbas sob o castelo), nomes próprios para cada região.
- **Direção**: objetivo da região na HUD, nome do lugar ao entrar, e o **mapa da região** (M) desenha o terreno explorado com nomes, ícones, saídas e o objetivo (Tab = mapa do mundo com viagem rápida).
![mapa da região](docs/mapa_regiao.png)
- Aldeões redesenhados: o povo de cinza, sem chama (só a Faísca guarda a última brasa), com traje por ofício.
- Garantia de travessia: todo lugar importante é alcançável do santuário e de volta (teste com todas as regiões de vários mundos).

## Sessão 6 — fim do visual "8 bit": pixel art moderna em 480x270
![biomas](docs/biomas.jpg)
- **Resolução nova**: o mundo agora é desenhado em **480x270** (4x exato em 1080p) com toda a arte no **dobro da densidade** — tiles de 16 px e personagens com ~30 px de altura (antes 12-14 px). A física e as salas não mudaram.
- **A Faísca redesenhada**: pequena criatura de cinza clara com rachaduras de brasa, olhos escuros com pupila acesa, **uma chama viva na cabeça que ilumina o caminho**, cachecol cor de brasa que esvoaça e manto esfarrapado. 13 animações (correr, pular, cair, dash, parede, escalar, golpe, magia, dano, morte, dormir...).
- **Inimigos com identidade** (16, todos animados, com olhos que brilham no escuro): Oco Errante de elmo rachado, Cão Infernal de costelas à mostra e cauda em brasa, Gato do Abismo, Saltador Espinhoso, Espectro encapuzado, Lampadário com sua lanterna, Crânio Flamejante, Morcego-Brasa, Besta do Inferno, Corcel do Pesadelo de crina azul, Atirador com olho-lanterna, Lâmina Sombria, Escudeiro de Ferro, Mãe da Ninhada, Colosso com núcleo brilhante, Arquidemônio alado — e o **Duelista Sombrio, reflexo negro da Faísca**. 13 armas desenhadas girando no golpe.
- **Terreno novo**: autotile completo (47 formatos de borda) por material, grama sobre as bordas, cipós e estalactites no teto, decorações temáticas, texturas grandes sem repetição (blocos, terra com raízes, mármore, runas, ossos...) e **rocha que escurece com a profundidade** como no Hollow Knight. As pedras têm relevo: **a luz da chama e das tochas reflete nelas**.
- **Cenários de fundo refeitos** em 480x270: 3-5 camadas com volume, borda iluminada pelo sol/lua, névoa atmosférica, janelas acesas e nuvens pintadas.
- **Clima escuro** nos lugares fechados e subterrâneos (a luz vem das chamas); bloom só no que brilha de verdade.
- Ferramentas: `tools/spritekit.py` (mini renderizador de pixel art), `tools/build_sprites.py`, `tools/sprites_enemies.py`, `tools/build_tiles.py`, `tools/build_scenery.py` — tudo gera PNGs simples, fáceis de editar à mão.

## Sessão 4 — gameplay frenética, fases grandes, mundo contínuo, arte e história
![biomas](docs/biomas.jpg)
- **Escala maior**: o mundo renderiza em 256x144 (tudo 25% maior) com um filtro de pixel nítido para qualquer resolução. **Câmera livre estilo Dead Cells** (olha à frente, zona morta vertical) que só trava em arenas e chefes.
- **Combate com impacto**: hitstop, tremor, coice e zoom de câmera proporcionais ao peso do golpe; **quadro de impacto** em dois tons nas mortes fortes (desligável); câmera lenta no último inimigo da arena; **morte estilo Katana Zero** (o inimigo é cortado em dois, as metades voam e quicam, respingo de tinta na parede). **Frenesi**: contador de golpes com níveis e bônus. **Nota S/A/B/C** ao limpar uma arena.
- **5 inimigos novos e rápidos**: Atirador (mira laser; rebata o tiro), Saltador, Lâmina Sombria (dash cortante), Escudeiro (bloqueia de frente) e Morcego-Brasa (mergulha). Os antigos ficaram mais rápidos e morrem em 2–3 golpes.
- **Salas**: biblioteca de **131 estruturas desenhadas à mão (262 com espelho)** em `tools/build_rooms.py` — pontes sobre espinhos, torres com túnel, zigurates, mesas com atiradores, arenas com **ondas** (portões fecham, inimigos entram por portais), corridas de lanternas, plataformas que caem, molas, serras, escaladas, desafios com cristais, poços, criptas... com **partes aleatórias** (tokens e grupos) e 25% de salas procedurais. Os testes simulam a física real em todas as combinações e exigem que cada estrutura tenha ação, elemento aéreo, verticalidade e inimigos alcançáveis.
- **Fases contínuas**: paredes entre salas vizinhas viram salões; biomas externos têm céu aberto; salas subterrâneas ganham parede de rocha.
- **Mundo contínuo explorável** (sem ilhas flutuantes): regiões em grade — superfície em fila, cidades do céu acima, subterrâneo abaixo. Ande até a borda e você entra na região vizinha. **Mapa estilo Hollow Knight** (M) com as salas exploradas, portões com cadeado, santuários para **viagem rápida** e a escolha do Cerco.
![mapa](docs/mapa.png)
- **Arte**: 10 **cenários pintados** em camadas (`tools/build_scenery.py`) com vida — nuvens, névoa, raios de sol, pássaros e um evento épico por lugar (titã atrás da cidade gótica, verme nas dunas, baleia do céu, catapultas na guerra, relâmpagos no castelo, olhos na caverna...). **13 tilesets** por material (`tools/build_tiles.py`), **água com reflexo** estilo Kingdom Two Crowns, **janelas** nos castelos mostrando o cenário, **adereços vivos** (cipós, correntes, estandartes, cristais, velas, capim).
- **Som**: todos os efeitos refeitos por síntese (`tools/build_sfx.py`), **ambiente** por bioma (pássaros, vento, chuva com sino, caverna com gotas, pântano, noite com grilos e coruja, guerra) em `tools/build_ambience.py`, e **eco** (reverb) em cavernas e salões.
- **História de Cindária** (`data/lore.json`): abertura ilustrada, **inscrições** espalhadas pelas fases, **cartões de título** de região e de chefe e o **Códice** na pausa.
![abertura](docs/abertura.jpg)
- Correção: o personagem ficava invisível depois de morrer.

## Sessão 3 — câmera, salas, golpes, música, loja e chefes
- **Câmera por sala (Celeste)**: cada sala tem o tamanho da tela; a câmera fica travada nela e desliza ao trocar de sala. Ao subir pela saída de cima o pulo é renovado (impulso de transição, como no Celeste).
- **HUD compacto no topo** (vida/foco/dash à esquerda; brasas, arma, magias e poção à direita), que fica translúcido quando o personagem passa por baixo.
- **Salas recalibradas** para o herói de 12 px: relevo com degraus de até 3 tiles, fossos, tetos irregulares, plataformas em camadas. Um validador (`scripts/level/room_reach.gd`) **simula a física real do jogador** e os testes garantem que toda saída leva a toda outra.
- **Golpes animados**: a arma aparece e gira (preparação → corte → volta) com formato por classe; inimigos também, o que telegrafa os ataques. Arco de corte limpo, sem halo. Squash no alvo atingido.
- **Música**: 11 trilhas chiptune geradas por código (`tools/build_music.py`), com crossfade por bioma, vila, chefe, mundo paralelo e Cerco.
- **Loja, forja e estudo**: fale com mercador/ferreira/sábio/curandeira nos hubs — comprar (estoque do dia), vender, forjar armas (+12% por nível) e armaduras, estudar magias, curar. Upgrades custam brasas + Fragmentos Rúnicos (baús).
- **3 chefes novos**: Duelista Sombrio (1v1, postura azul de contra-ataque), Mãe da Ninhada (horda com escudo) e Colosso de Pedra (gigante com ondas de choque e chuva de pedras). Cada faixa do mundo recebe um chefe diferente.
- **Arena de chefes** no menu principal para lutar direto contra qualquer chefe.
- Correções: mapa-múndi aparecia vazio; fonte mostrava "ReputaÇÃo" (`tools/fix_font_accents.py`); raios de luz pontilhados (agora desligados por padrão); golpe para cima e estocadas verticais desenhados de lado; NPCs com nomes repetidos.

## Sessão 2 — novo visual e feel
- **Resolução interna 320×180** (igual Celeste): o mundo é renderizado num SubViewport pixel-perfeito e escalado para a janela; HUD e menus ficam nítidos por cima.
- **Tiles de 8 px** limpos e chapados (`tools/build_tiles.py`), fundo procedural simples, pouca partícula, sem granulação/vinheta/aberração por padrão.
- **Personagem ~12 px**: criaturinha minimalista desenhada em código (`scripts/fx/creature_sprite.gd`) — pisca, olha para onde vai, estica/amassa ao pular/cair, capa balança e mostra emoções sobre a cabeça: `!` (perigo/aparo perfeito), `?` (segredo perto), `…` (parado), gota (pouca vida), `♥` (NPC querido), `♪` (ritmo), `zZ` (descansando). Inimigos e NPCs usam o mesmo estilo (aparência em `data/enemies.json` → `look`).
- **Física de Celeste** com os números nativos (corrida 90, pulo 115, dash 240/0.15s...).
- **Combate estilo Hollow Knight**: golpes curtos e rápidos (lado/cima/baixo com pogo), recuo ao acertar; escalas em `AttackRunner` (BOX/LUNGE/KB/tempos).

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
- **Assets**: personagens/tiles agora procedurais; ícones, fontes e sons são placeholders CC0 (ver `assets/CREDITS.md`).

## Testes
`godot --headless --path . res://tests/test_runner.tscn` — ~6700 verificações (dados, balanceamento, mundo, fases, **alcançabilidade das salas com a física do jogador**, combate, sigilos, inventário, social, loja/forja, chefes, save, e um teste que joga a fase de treino com entradas simuladas).
Screenshots de vários cenários: `godot --path . res://tests/shots.tscn -- <pasta> [all|rooms|region|menu|pause|map|combat|shop|bosses|juice|overview|biomes|intro]`.

## Pendências conhecidas (próxima sessão)
Veja `CONTEXTO_SESSAO_9.txt`: próximas regiões feitas à mão (Vésper com o duelo contra Umbral, Esgotos, Catacumbas...), estado do mundo salvo (paredes, baús, alavancas), arte nova para baús/portões/alavancas/pickups e o epílogo do capítulo 1.
