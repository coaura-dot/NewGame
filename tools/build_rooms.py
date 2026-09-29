#!/usr/bin/env python3
"""Estruturas de sala desenhadas à mão (em código, para ter precisão) →
data/rooms/estruturas.txt. Cada sala tem 40x24 tiles e usa a legenda de
scripts/level/level_const.gd, mais TOKENS ALEATÓRIOS resolvidos na geração
(estilo Spelunky/Dead Cells: a mesma estrutura nunca sai igual):

  Seguros (não mudam o caminho; sorteados livremente):
    e  inimigo de chão (60%)      f  voador (50%)       u  atirador (55%)
    i  lanterna de Ímpeto (65%)   s  serra (45%)        c  baú (30%)
    d  cristal de dash (60%)      j  mola (50%)         +  plataforma fina (50%)
    o  plataforma que cai (60%, senão fina)
  Em GRUPO (mudam o caminho; os testes validam TODAS as combinações):
    1 2 3  bloco sólido opcional (todo o grupo junto: sólido ou vazio)
    4 5    espinho opcional (grupo)

Toda sala também pode sair ESPELHADA (L<->R). As regras de física (pulo
~4 tiles, ~6 de alcance subindo 3) estão em scripts/level/room_synth.gd;
tests/test_room_reach.gd simula tudo com a física real (RoomReach).

Uso: python3 tools/build_rooms.py
"""
import os

W, H = 40, 24
FL = 21
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "data", "rooms", "estruturas.txt")
ROOMS = []


class Room:
    def __init__(self, rid, rtype, exits, weight=1.0, tags="", biomes="*"):
        self.id, self.type, self.exits = rid, rtype, exits
        self.weight, self.tags, self.biomes = weight, tags, biomes
        self.g = [["." for _ in range(W)] for _ in range(H)]
        self.fill(0, 0, W - 1, 0, "#")
        self.fill(0, FL, W - 1, H - 1, "#")
        self.fill(0, 0, 0, H - 1, "#")
        self.fill(W - 1, 0, W - 1, H - 1, "#")
        if "L" in exits:
            self.fill(0, 17, 0, 20, ".")
        if "R" in exits:
            self.fill(W - 1, 17, W - 1, 20, ".")
        if "U" in exits:
            self.fill(18, 0, 21, 0, ".")
        if "D" in exits:
            self.fill(18, FL, 21, H - 1, ".")
            self.fill(18, H - 1, 21, H - 1, "-")
        ROOMS.append(self)

    def put(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.g[y][x] = c

    def fill(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def plat(self, x0, x1, y, c="-"):
        for x in range(x0, x1 + 1):
            if self.g[y][x] == ".":
                self.g[y][x] = c

    def block(self, x0, top, x1, bottom=FL - 1, c="#"):
        """Bloco sólido de `top` até `bottom` (padrão: até o chão)."""
        self.fill(x0, top, x1, bottom, c)

    def pit(self, x0, x1, spikes=True, depth=2):
        """Fosso no chão (linhas 21..21+depth-1 vazias; espinhos no fundo)."""
        self.fill(x0, FL, x1, FL + depth - 1, ".")
        if spikes:
            self.fill(x0, FL + depth - 1, x1, FL + depth - 1, "^")

    def up_route(self, side="L"):
        """Escada de plataformas até a saída de cima (linha 4, cols 16..23)."""
        xa, xb = (15, 24) if side == "L" else (24, 15)
        for k, y in enumerate([18, 15, 12, 9, 6]):
            cx = xa if k % 2 == 0 else xb
            self.plat(cx - 2, cx + 2, y)
        self.plat(16, 23, 4)

    def stamp(self, x, y, art):
        for dy, line in enumerate(art):
            for dx, ch in enumerate(line):
                if ch != " ":
                    self.put(x + dx, y + dy, ch)

    def rows(self):
        return ["".join(r) for r in self.g]


# ===========================================================================
# COMBATE (lutas abertas, fluxo)
# ===========================================================================

r = Room("patio_pilares", "combat", "LRU", 2.0)
for x, top in [(9, 19), (19, 18), (29, 19)]:
    r.block(x, top, x + 1)
r.plat(3, 8, 16)
r.plat(31, 36, 16)
r.put(5, 15, "u")
r.put(33, 15, "u")
r.put(10, 12, "i")
r.put(29, 12, "i")
for x in (6, 14, 24, 34):
    r.put(x, 20, "e")
r.put(20, 10, "f")
r.fill(14, 19, 15, 20, "1")
r.fill(24, 19, 25, 20, "1")
r.up_route("L")

r = Room("ponte_espinhos", "combat", "LR", 2.0)
r.pit(12, 27, spikes=True, depth=3)
r.plat(12, 18, 18)
r.plat(21, 27, 18)
r.put(15, 17, "e")
r.put(24, 17, "e")
r.put(19, 12, "i")
r.put(20, 12, "i")
r.block(5, 18, 7)
r.block(32, 18, 34)
r.plat(4, 8, 15)
r.plat(31, 35, 15)
r.put(6, 14, "u")
r.put(33, 14, "u")
r.put(9, 20, "e")
r.put(30, 20, "e")
r.put(12, 9, "f")
r.put(27, 9, "f")

r = Room("fosso_lanternas", "combat", "LR", 1.6)
r.pit(10, 29, spikes=True, depth=3)
r.block(14, 20, 16, H - 2)
r.block(22, 20, 24, H - 2)
r.put(15, 19, "e")
r.put(23, 19, "e")
r.put(12, 14, "i")
r.put(19, 13, "i")
r.put(27, 14, "i")
r.put(6, 20, "e")
r.put(33, 20, "e")
r.put(19, 8, "f")
r.plat(17, 21, 16, "+")

r = Room("torre_central", "combat", "LR", 1.8)
r.block(17, 12, 22, 18)
r.plat(12, 15, 15)
r.plat(13, 16, 18)
r.plat(24, 27, 15)
r.plat(23, 26, 18)
r.put(19, 11, "u")
r.put(21, 11, "e")
r.put(19, 20, "e")
r.put(6, 20, "e")
r.put(33, 20, "e")
r.put(10, 11, "i")
r.put(29, 11, "i")
r.put(19, 6, "f")

r = Room("zigurate", "combat", "LR", 1.6)
for i, (x0, x1) in enumerate([(6, 33), (9, 30), (12, 27), (15, 24)]):
    r.block(x0, 19 - i * 2, x1, 20 - i * 2 if i else 20)
r.put(19, 12, "u")
r.put(11, 16, "e")
r.put(28, 16, "e")
r.put(3, 20, "e")
r.put(36, 20, "e")
r.put(7, 11, "i")
r.put(32, 11, "i")
r.put(19, 6, "s")

r = Room("patamares", "combat", "LRD", 1.5)
r.block(4, 18, 13)
r.block(26, 18, 35)
r.plat(10, 29, 15)
r.fill(18, 15, 21, 15, ".")
r.put(8, 17, "e")
r.put(31, 17, "e")
r.put(14, 14, "u")
r.put(25, 14, "e")
r.put(19, 9, "i")
r.put(8, 9, "f")
r.put(31, 9, "f")
r.fill(15, 19, 16, 20, "2")
r.fill(23, 19, 24, 20, "2")

r = Room("salao_colunas", "combat", "LRU", 1.5)
for x in (7, 15, 24, 32):
    r.plat(x - 2, x + 2, 16)
    r.put(x, 17, ".")
r.plat(10, 14, 12)
r.plat(25, 29, 12)
r.put(12, 11, "u")
r.put(27, 11, "u")
for x in (4, 11, 19, 28, 35):
    r.put(x, 20, "e")
r.put(20, 7, "i")
r.put(8, 7, "f")
r.put(31, 7, "f")
r.up_route("R")

r = Room("trincheiras", "combat", "LR", 1.4)
for x0 in (10, 20, 30):
    r.pit(x0, x0 + 2, spikes=False, depth=2)
for x in (8, 18, 28):
    r.block(x, 19, x)
r.block(4, 18, 6)
r.block(33, 18, 35)
r.put(5, 17, "u")
r.put(34, 17, "u")
r.put(14, 20, "e")
r.put(25, 20, "e")
r.put(19, 12, "i")
r.put(13, 9, "f")
r.put(26, 9, "f")
r.fill(15, 18, 15, 20, "1")
r.fill(24, 18, 24, 20, "1")

r = Room("caverna_vigias", "combat", "LR", 1.3)
r.fill(1, 1, 38, 4, "#")
for x0, x1, d in [(5, 8, 7), (13, 15, 6), (24, 27, 8), (32, 34, 6)]:
    r.fill(x0, 5, x1, d, "#")
    r.fill(x0, d + 1, x1, d + 1, "^")
r.block(9, 18, 12)
r.block(27, 18, 30)
r.plat(10, 11, 15)
r.plat(28, 29, 15)
r.put(10, 17, "u")
r.put(29, 17, "u")
r.put(19, 20, "e")
r.put(5, 20, "e")
r.put(35, 20, "e")
r.put(19, 13, "i")
r.fill(18, 19, 21, 20, "3")

r = Room("barricada", "combat", "LRU", 1.4)
r.block(13, 17, 14)
r.block(25, 17, 26)
r.plat(9, 12, 18)
r.plat(27, 30, 18)
r.plat(15, 24, 17, "+")
r.put(16, 20, "e")
r.put(19, 20, "e")
r.put(22, 20, "e")
r.put(13, 16, "u")
r.put(26, 16, "u")
r.put(6, 20, "e")
r.put(33, 20, "e")
r.put(19, 12, "i")
r.up_route("L")

r = Room("jardim_suspenso", "combat", "LR", 1.2)
for x0, x1, y in [(3, 9, 18), (12, 17, 15), (22, 27, 15), (30, 36, 18), (15, 24, 12)]:
    r.plat(x0, x1, y)
r.put(6, 17, "e")
r.put(33, 17, "e")
r.put(14, 14, "e")
r.put(25, 14, "e")
r.put(19, 11, "u")
r.put(19, 20, "e")
r.put(10, 11, "i")
r.put(29, 11, "i")
r.put(19, 5, "f")

# ===========================================================================
# ARENAS (portões + ondas)
# ===========================================================================

r = Room("arena_coliseu", "arena", "LR", 2.0, "lock")
r.block(4, 18, 7)
r.block(32, 18, 35)
r.plat(2, 9, 15)
r.plat(30, 37, 15)
r.plat(11, 14, 18)
r.plat(25, 28, 18)
r.plat(16, 23, 15)
r.plat(17, 22, 12)
r.put(4, 14, "U")
r.put(35, 14, "U")
r.put(10, 10, "I")
r.put(29, 10, "I")
for x in (9, 13, 17, 21, 26, 30):
    r.put(x, 20, "E")
r.put(19, 11, "e")
r.put(14, 7, "F")
r.put(25, 7, "F")
r.put(0, 17, "G")
r.put(39, 17, "G")

r = Room("arena_espinhos", "arena", "LR", 1.5, "lock")
r.pit(16, 23, spikes=True, depth=2)
r.plat(15, 24, 18)
r.block(6, 18, 8)
r.block(31, 18, 33)
r.plat(5, 9, 15)
r.plat(30, 34, 15)
r.put(7, 14, "U")
r.put(32, 14, "U")
r.put(19, 12, "I")
r.put(11, 11, "I")
r.put(28, 11, "I")
for x in (3, 11, 13, 26, 28, 36):
    r.put(x, 20, "E")
r.put(19, 17, "E")
r.put(10, 6, "F")
r.put(29, 6, "F")
r.put(0, 17, "G")
r.put(39, 17, "G")

r = Room("arena_torres", "arena", "LR", 1.5, "lock")
r.block(6, 15, 9)
r.block(30, 15, 33)
r.plat(2, 5, 18)
r.plat(10, 12, 18)
r.plat(27, 29, 18)
r.plat(34, 37, 18)
r.put(7, 14, "U")
r.put(32, 14, "U")
r.plat(15, 24, 16)
r.plat(17, 22, 13)
r.put(19, 10, "I")
for x in (13, 16, 19, 23, 26):
    r.put(x, 20, "E")
r.put(19, 15, "E")
r.put(13, 6, "F")
r.put(26, 6, "F")
r.put(0, 17, "G")
r.put(39, 17, "G")

r = Room("arena_andares", "arena", "LR", 1.3, "lock")
for y, gaps in [(18, [(9, 11), (28, 30)]), (15, [(18, 21)]), (12, [(6, 8), (31, 33)])]:
    r.plat(2, 37, y)
    for g0, g1 in gaps:
        r.fill(g0, y, g1, y, ".")
r.put(5, 17, "E")
r.put(34, 17, "E")
r.put(14, 14, "E")
r.put(25, 14, "E")
r.put(12, 11, "U")
r.put(27, 11, "U")
for x in (8, 19, 31):
    r.put(x, 20, "E")
r.put(19, 6, "F")
r.put(10, 8, "I")
r.put(29, 8, "I")
r.put(0, 17, "G")
r.put(39, 17, "G")

# ===========================================================================
# PARKOUR (dash, recargas, espinhos)
# ===========================================================================

r = Room("corrida_lanternas", "platforming", "LR", 2.0)
r.pit(5, 34, spikes=True, depth=2)
for x0 in (8, 15, 22, 29):
    r.block(x0, 19, x0 + 1, H - 2)
for x in (11, 18, 25, 32):
    r.put(x, 14, "i")
r.put(19, 8, "s")
r.put(12, 9, "f")
r.put(27, 9, "f")
r.plat(13, 14, 18, "+")
r.plat(26, 27, 18, "+")

r = Room("plataformas_que_caem", "platforming", "LR", 1.6)
r.pit(4, 35, spikes=True, depth=2)
for x0 in (6, 13, 20, 27):
    r.plat(x0, x0 + 3, 19, "o")
r.block(11, 19, 11, H - 2)
r.block(18, 18, 18, H - 2)
r.block(25, 19, 25, H - 2)
r.block(32, 19, 33, H - 2)
r.put(15, 13, "i")
r.put(29, 13, "i")
r.put(22, 9, "f")

r = Room("molas_e_mirantes", "platforming", "LRU", 1.4)
r.block(10, 15, 13)
r.block(26, 15, 29)
r.plat(15, 24, 11)
r.put(8, 20, "J")
r.put(31, 20, "J")
r.pit(15, 24, spikes=True, depth=2)
r.plat(14, 25, 18, "o")
r.put(19, 10, "c")
r.put(12, 14, "e")
r.put(27, 14, "e")
r.put(19, 6, "i")
r.plat(8, 9, 18)
r.plat(30, 31, 18)
r.up_route("R")

r = Room("serras_do_corredor", "platforming", "LR", 1.5)
r.fill(1, 1, 38, 9, "#")
r.block(8, 18, 10)
r.block(17, 17, 19)
r.block(26, 18, 28)
r.put(13, 14, "S")
r.put(22, 14, "S")
r.put(31, 13, "s")
r.put(5, 20, "e")
r.put(34, 20, "e")
r.put(14, 20, "e")
r.plat(11, 16, 15, "+")
r.plat(20, 25, 15, "+")
r.fill(12, 19, 15, 20, "4")
r.put(19, 11, "i")

r = Room("degraus_do_abismo", "platforming", "LR", 1.4)
r.pit(3, 36, spikes=True, depth=3)
for i, x0 in enumerate([5, 10, 15, 20, 25, 30]):
    top = [19, 17, 15, 15, 17, 19][i]
    r.block(x0, top, x0 + 2, H - 2)
for x in (8, 13, 23, 28):
    r.put(x, 12, "i")
r.put(19, 9, "f")
r.put(16, 14, "e")
r.put(21, 14, "e")

r = Room("ruina_pendurada", "platforming", "LRU", 1.3)
r.pit(8, 31, spikes=True, depth=2)
r.plat(9, 13, 18)
r.plat(16, 23, 16)
r.plat(26, 30, 18)
r.fill(12, 8, 14, 9, "#")
r.fill(25, 8, 27, 9, "#")
r.fill(12, 10, 14, 10, "^")
r.fill(25, 10, 27, 10, "^")
r.put(19, 12, "i")
r.put(11, 17, "e")
r.put(28, 17, "e")
r.put(5, 12, "f")
r.put(34, 12, "f")
r.plat(3, 7, 18)
r.plat(32, 36, 18)
r.plat(4, 8, 15)
r.plat(31, 35, 15)
r.plat(7, 11, 12)
r.plat(28, 32, 12)
r.plat(10, 14, 6)
r.plat(8, 11, 9)
r.plat(28, 31, 9)
r.plat(25, 29, 6)
r.plat(15, 18, 4)
r.plat(21, 24, 4)
r.plat(16, 23, 4)

# ===========================================================================
# DESAFIOS (exigem dash; recompensa no fim)
# ===========================================================================

r = Room("abismo_de_cristais", "challenge", "LR", 1.6, "pain")
r.pit(3, 36, spikes=True, depth=3)
r.block(3, 19, 4, H - 2)
r.block(35, 19, 36, H - 2)
for x0, top in [(11, 17), (20, 15), (28, 17)]:
    r.block(x0, top, x0 + 1, H - 2)
r.put(8, 14, "D")
r.put(16, 12, "D")
r.put(24, 12, "D")
r.put(32, 14, "D")
r.put(19, 8, "i")
r.put(36, 18, "R")

r = Room("serras_giratorias", "challenge", "LR", 1.4, "pain")
r.pit(4, 35, spikes=True, depth=2)
for x0 in (8, 16, 24, 31):
    r.block(x0, 18, x0 + 1, H - 2)
for x in (12, 20, 28):
    r.put(x, 15, "S")
r.put(12, 10, "i")
r.put(20, 9, "i")
r.put(28, 10, "i")
r.put(19, 5, "d")
r.put(37, 20, "R")

r = Room("teto_de_espinhos", "challenge", "LR", 1.2, "pain")
r.fill(1, 1, 38, 11, "#")
r.fill(1, 12, 38, 12, "^")
r.pit(5, 34, spikes=True, depth=2)
for x0 in (9, 17, 25):
    r.block(x0, 19, x0 + 1, H - 2)
r.put(13, 16, "D")
r.put(21, 16, "D")
r.put(29, 16, "D")
r.put(37, 20, "R")

# ===========================================================================
# POÇOS (vertical)
# ===========================================================================

r = Room("poco_lanternas", "shaft", "LRUD", 1.8)
for y, left in [(18, True), (15, False), (12, True), (9, False), (6, True)]:
    if left:
        r.block(1, y, 6, y)
        r.plat(7, 12, y)
    else:
        r.block(33, y, 38, y)
        r.plat(27, 32, y)
r.plat(14, 17, 16)
r.plat(22, 25, 13)
r.plat(14, 17, 10)
r.plat(22, 25, 7)
r.plat(16, 23, 4)
r.put(19, 11, "i")
r.put(19, 17, "i")
r.put(10, 8, "f")
r.put(29, 14, "f")
r.put(4, 17, "e")

r = Room("poco_andaimes", "shaft", "LRUD", 1.5)
for k, y in enumerate((18, 15, 12, 9, 6)):
    r.plat(3, 36, y)
    gap = 7 if k % 2 else 30
    r.fill(gap, y, gap + 2, y, ".")
r.plat(16, 23, 4)
r.put(12, 14, "e")
r.put(27, 17, "e")
r.put(12, 5, "u")
r.put(30, 8, "u")
r.put(19, 13, "i")
r.put(19, 7, "i")
r.put(6, 10, "f")

r = Room("chamine", "shaft", "UD", 1.2)
r.fill(1, 1, 12, 20, "#")
r.fill(27, 1, 38, 20, "#")
for y, side in [(18, 0), (15, 1), (12, 0), (9, 1), (6, 0)]:
    if side == 0:
        r.plat(13, 17, y)
    else:
        r.plat(22, 26, y)
r.plat(16, 23, 4)
r.put(19, 13, "i")
r.put(19, 8, "f")
r.fill(13, FL, 17, FL, "#")

# ===========================================================================
# CORREDORES
# ===========================================================================

r = Room("corredor_emboscada", "corridor", "LR", 1.5)
r.fill(1, 1, 38, 12, "#")
for x0 in (8, 19, 30):
    r.fill(x0, 10, x0 + 3, 12, ".")
    r.put(x0 + 1, 11, "f")
r.block(34, 18, 35)
r.put(36, 20, "u")
r.put(14, 20, "e")
r.put(25, 20, "e")
r.plat(12, 16, 17, "+")
r.plat(23, 27, 17, "+")

r = Room("corredor_escudos", "corridor", "LR", 1.3)
r.fill(1, 1, 38, 8, "#")
r.plat(6, 33, 16)
r.fill(12, 16, 13, 16, ".")
r.fill(26, 16, 27, 16, ".")
for x in (10, 19, 28):
    r.put(x, 20, "e")
r.put(19, 15, "e")
r.put(8, 12, "i")
r.put(31, 12, "i")
r.plat(3, 5, 18)
r.plat(34, 36, 18)

r = Room("corredor_serra_trilho", "corridor", "LR", 1.2)
r.fill(1, 1, 38, 10, "#")
r.block(13, 18, 14)
r.block(25, 18, 26)
r.put(19, 15, "S")
r.put(8, 20, "e")
r.put(31, 20, "e")
r.put(19, 20, "c")
r.fill(19, 19, 20, 20, "1")
r.put(4, 20, "e")
r.put(35, 20, "e")
r.put(10, 15, "i")
r.put(29, 15, "i")
r.put(19, 12, "f")

# ===========================================================================
# TESOURO / SEGREDO
# ===========================================================================

r = Room("cofre_das_lanternas", "treasure", "LR", 1.5)
r.pit(12, 27, spikes=True, depth=2)
r.block(18, 15, 21, H - 2)
r.plat(12, 14, 18)
r.plat(15, 17, 16)
r.plat(25, 27, 18)
r.plat(22, 24, 16)
r.put(19, 14, "C")
r.put(20, 14, "c")
r.put(14, 11, "I")
r.put(25, 11, "I")
r.plat(6, 9, 18)
r.plat(30, 33, 18)
r.put(8, 17, "e")

r = Room("altar_suspenso", "treasure", "LRU", 1.2)
r.plat(15, 24, 10)
r.put(19, 9, "C")
r.plat(6, 10, 18)
r.plat(10, 14, 15)
r.plat(12, 16, 12)
r.plat(29, 33, 18)
r.plat(25, 29, 15)
r.plat(23, 27, 12)
r.plat(17, 22, 7)
r.plat(16, 23, 4)
r.put(19, 20, "e")
r.put(8, 9, "f")


# ===========================================================================
# FAMÍLIAS PARAMETRIZADAS — várias variações de cada ideia de jogo. Regras:
#  * colunas 1..3 livres no chão perto das saídas L/R (linhas 17..20);
#  * degrau/plataforma: no máximo 3 linhas acima de onde se pisa (do chão,
#    a 1ª camada fica na linha 18); vãos no mesmo nível <= 5 tiles;
#  * blocos saindo do chão com no máximo 3 de altura (topo >= linha 18),
#    ou mais altos só com degraus/plataformas dos dois lados.
# ===========================================================================
import random


def fam_ponte(v, pit, gaps, towers, orbs, air):
    r = Room("f_ponte_%d" % v, "combat", "LR", 1.0)
    x0, x1 = pit
    r.pit(x0, x1, spikes=True, depth=3)
    r.plat(x0, x1, 18)
    for g in gaps:
        r.fill(g, 18, g + 1, 18, ".")
    for x in range(x0 + 2, x1 - 1, 5):
        if r.g[18][x] == "-":
            r.put(x, 17, "e")
    if towers:
        r.block(5, 18, 7)
        r.block(32, 18, 34)
        r.plat(4, 8, 15)
        r.plat(31, 35, 15)
        r.put(6, 14, "u")
        r.put(33, 14, "u")
    for g in gaps:
        if orbs:
            r.put(g, 13, "i")
    for k in range(air):
        r.put(10 + k * 9, 9, "f")
    r.put(4 if not towers else 9, 20, "e")


def fam_pilares(v, xs, heights, balcony, groupcover):
    center_free = all(not (17 <= x <= 22 or 17 <= x + 1 <= 22) for x in xs)
    r = Room("f_pilares_%d" % v, "combat", "LR" + ("U" if v % 3 == 0 else "") + ("D" if center_free and v % 3 != 0 else ""), 1.0)
    for x, hgt in zip(xs, heights):
        r.block(x, FL - hgt, x + 1)
        r.put(x, FL - hgt - 5, "i" if hgt == 3 else ".")
    if balcony:
        r.plat(4, 9, 16 if False else 18)
        r.plat(3, 7, 15)
        r.plat(30, 35, 18)
        r.plat(32, 36, 15)
        r.put(5, 14, "u")
        r.put(34, 14, "u")
    for x in range(6, 36, 7):
        if r.g[20][x] == ".":
            r.put(x, 20, "e")
    if groupcover:
        for x in (12, 26):
            if r.g[20][x] == ".":
                r.fill(x, 19, x, 20, "1")
    r.put(19, 8, "f")
    if "U" in r.exits:
        r.up_route("L" if v % 2 else "R")


def fam_torre(v, width, height, tunnel, sniper_top):
    r = Room("f_torre_%d" % v, "combat", "LR", 1.0)
    x0 = 20 - width // 2
    x1 = x0 + width - 1
    top = FL - height
    r.block(x0, top, x1, 18 if tunnel else FL - 1)
    # degraus dos dois lados até o topo (de 3 em 3)
    y = 18
    k = 0
    while y > top:
        r.plat(x0 - 4 - (k % 2), x0 - 1, y)
        r.plat(x1 + 1, x1 + 4 + (k % 2), y)
        y -= 3
        k += 1
    if sniper_top:
        r.put(20, top - 1, "u")
    r.put(x0 + 1, top - 1, "e")
    if tunnel:
        r.put(20, 20, "e")
    r.put(6, 20, "e")
    r.put(33, 20, "e")
    r.put(x0 - 6, top - 3, "i")
    r.put(x1 + 6, top - 3, "i")
    r.put(20, top - 7, "f")


def fam_zigurate(v, step_w, steps, saw, peak):
    r = Room("f_zigurate_%d" % v, "combat", "LR", 1.0)
    for i in range(steps):
        a = 5 + i * step_w
        b = 34 - i * step_w
        if a >= b:
            break
        r.block(a, FL - 2 * (i + 1), b, FL - 1)
    top = FL - 2 * steps
    r.put(19, top - 1, peak)
    r.put(5 + step_w, FL - 3, "e")
    r.put(34 - step_w, FL - 3, "e")
    r.put(3, 20, "e")
    r.put(36, 20, "e")
    r.put(8, top - 3, "i")
    r.put(31, top - 3, "i")
    if saw:
        r.put(19, top - 6, "s")


def fam_penhasco(v, cliff_x, cliff_top, ledges, divers):
    """Mesa: planalto alto com atiradores; sobe e desce por plataformas dos
    dois lados (saídas continuam no chão, no padrão)."""
    r = Room("f_penhasco_%d" % v, "combat", "LR", 1.0)
    right = 34
    r.block(cliff_x, cliff_top, right, FL - 1)
    for side, edge in ((-1, cliff_x - 1), (1, right + 1)):
        y = 18
        k = 0
        while y > cliff_top:
            x = edge - 3 if side < 0 else edge
            if k % 2:
                x += -2 if side < 0 else 1
            r.plat(max(4, x), min(x + 3, 37), y)
            y -= 3
            k += 1
    r.plat(cliff_x - 3, cliff_x - 1, cliff_top)
    r.plat(right + 1, right + 3, cliff_top)
    for i in range(ledges):
        r.put(cliff_x + 2 + i * 5, cliff_top - 1, "u" if i % 2 == 0 else "e")
    for i in range(divers):
        r.put(8 + i * 8, 8, "f")
    r.put(6, 20, "e")
    r.put(cliff_x - 6, 20, "e")
    r.put(cliff_x - 4, cliff_top - 5, "i")


def fam_dois_andares(v, holes, snipers, orb_row):
    r = Room("f_andares_%d" % v, "combat", "LRD", 1.0)
    r.plat(4, 35, 15)
    for h in holes:
        r.fill(h, 15, h + 2, 15, ".")
    r.plat(4, 8, 18)
    r.plat(31, 35, 18)
    r.plat(14, 17, 18)
    r.plat(22, 25, 18)
    for x in (10, 20, 29):
        r.put(x, 20, "e")
    for x in (7, 19, 32):
        if r.g[15][x] == "-":
            r.put(x, 14, "u" if snipers else "e")
    r.put(12, orb_row, "i")
    r.put(27, orb_row, "i")
    r.put(19, 7, "f")


def fam_abismo_morcegos(v, width, islands):
    r = Room("f_abismo_%d" % v, "combat", "LR", 0.9)
    x0 = 20 - width // 2
    r.pit(x0, x0 + width - 1, spikes=True, depth=3)
    step = width // (islands + 1)
    for k in range(islands):
        ix = x0 + step * (k + 1) - 1
        r.block(ix, 19, ix + 2, H - 2)
        r.put(ix + 1, 18, "e")
        r.put(ix + 1, 12, "i")
    for k in range(3):
        r.put(x0 + 3 + k * (width // 3), 8 + (k % 2) * 3, "f")
    r.put(5, 20, "e")
    r.put(34, 20, "e")


def fam_arena_afundada(v, depth_rows, ledge_w):
    r = Room("f_arena_funda_%d" % v, "arena", "LR", 1.0, "lock")
    r.pit(8, 31, spikes=False, depth=2)
    r.fill(8, H - 1, 31, H - 1, "#")
    r.plat(3, 3 + ledge_w, 18)
    r.plat(36 - ledge_w, 36, 18)
    r.plat(4, 8, 15)
    r.plat(31, 35, 15)
    r.plat(12, 16, 19)
    r.plat(23, 27, 19)
    r.plat(16, 23, 16)
    r.plat(18, 21, 13)
    for x in (10, 14, 18, 21, 25, 29):
        r.put(x, 22, "E")
    r.put(6, 14, "U")
    r.put(33, 14, "U")
    r.put(19, 9, "I")
    r.put(12, 9, "F")
    r.put(27, 9, "F")
    r.put(0, 17, "G")
    r.put(39, 17, "G")


def fam_arena_coliseu(v, balcony_row, center_rows, spikes):
    r = Room("f_coliseu_%d" % v, "arena", "LR", 1.0, "lock")
    r.block(4, 18, 7)
    r.block(32, 18, 35)
    r.plat(2, 9, balcony_row)
    r.plat(30, 37, balcony_row)
    r.plat(11, 14, 18)
    r.plat(25, 28, 18)
    for k, y in enumerate(center_rows):
        w = 4 - k
        r.plat(19 - w, 20 + w, y)
    if spikes:
        r.pit(17, 22, spikes=True, depth=2)
    r.put(4, balcony_row - 1, "U")
    r.put(35, balcony_row - 1, "U")
    r.put(10, 10, "I")
    r.put(29, 10, "I")
    for x in (9, 13, 26, 30, 15, 24):
        r.put(x, 20, "E")
    r.put(19, center_rows[-1] - 1, "e")
    r.put(14, 7, "F")
    r.put(25, 7, "F")
    r.put(0, 17, "G")
    r.put(39, 17, "G")


def fam_corrida(v, pillars, gap, orb_row, saws):
    r = Room("f_corrida_%d" % v, "platforming", "LR", 1.0)
    r.pit(5, 34, spikes=True, depth=2)
    x = 5 + gap
    k = 0
    while x + 1 < 34:
        r.block(x, 19 - (k % 2 if pillars == "alt" else 0), x + 1, H - 2)
        if x + 2 + gap // 2 < 34:
            r.put(x + 2 + gap // 2, orb_row - (k % 2) * 2, "i")
        last = x + 1
        x += gap + 2
        k += 1
    if 34 - last > 4:
        r.block(last + 1 + (34 - last) // 2 - 1, 19, last + 1 + (34 - last) // 2, H - 2)
    for k in range(saws):
        r.put(10 + k * 12, 10, "s")
    r.put(19, 7, "f")


def fam_caem(v, n, width, rests):
    r = Room("f_caem_%d" % v, "platforming", "LR", 1.0)
    r.pit(4, 35, spikes=True, depth=2)
    first, last = 7, 33 - width
    for k in range(n):
        x0 = first + round(k * (last - first) / max(n - 1, 1))
        r.plat(x0, x0 + width - 1, 19, "o")
        if rests and k % 2 == 1:
            r.block(x0 + width, 19, x0 + width, H - 2)
        if k < n - 1:
            r.put(x0 + width + 1, 13, "i")
    r.put(19, 8, "f")


def fam_escalada(v, wall_x, wall_top, orbs):
    """Muro alto no meio: sobe por ressaltos (e pula de parede, se quiser)."""
    r = Room("f_escalada_%d" % v, "platforming", "LR", 1.0)
    r.block(wall_x, wall_top, wall_x + 3)
    y = 18
    side = 0
    while y > wall_top:
        if side == 0:
            r.plat(wall_x - 5, wall_x - 1, y)
        else:
            r.plat(wall_x - 5, wall_x - 1, y)
            r.plat(wall_x + 4, wall_x + 8, y)
        y -= 3
        side = 1 - side
    y = 18
    while y > wall_top:
        r.plat(wall_x + 4, wall_x + 8, y)
        y -= 3
    for k in range(orbs):
        r.put(wall_x - 3 + k * 10, wall_top - 3 - k, "i")
    r.put(wall_x + 1, wall_top - 1, "u")
    r.put(wall_x + 1, wall_top - 5, "s")
    r.put(8, 20, "e")
    r.put(33, 20, "e")
    r.put(wall_x - 8, 9, "f")


def fam_cascata(v, high_row, crystals):
    """Rota alta com cristais de dash (rápida) + rota de baixo com inimigos."""
    r = Room("f_cascata_%d" % v, "platforming", "LR", 1.0)
    r.plat(3, 7, 18)
    r.plat(5, 9, 15)
    r.plat(8, 12, high_row)
    r.plat(27, 31, high_row)
    r.plat(30, 34, 15)
    r.plat(32, 36, 18)
    for k in range(crystals):
        r.put(14 + k * (12 // max(crystals - 1, 1)), high_row - 2, "d")
    r.plat(16, 23, high_row + 1, "+")
    for x in (10, 16, 22, 28):
        r.put(x, 20, "e")
    r.pit(14, 16, spikes=True, depth=2)
    r.pit(23, 25, spikes=True, depth=2)
    r.put(19, 8, "f")


def fam_desafio_cristais(v, gaps, crystal_row):
    r = Room("f_cristais_%d" % v, "challenge", "LR", 1.0, "pain")
    r.pit(3, 36, spikes=True, depth=3)
    r.block(3, 19, 4, H - 2)
    r.block(35, 19, 36, H - 2)
    x = 5
    k = 0
    for gp in gaps:
        x += gp
        if x + 1 >= 35:
            break
        r.block(x, 17 + (k % 2), x + 1, H - 2)
        r.put(x - gp // 2, crystal_row + (k % 2) * 2, "D")
        x += 2
        k += 1
    r.put(19, 7, "i")
    r.put(36, 18, "R")


def fam_poco(v, spacing, orbs, divers):
    r = Room("f_poco_%d" % v, "shaft", "LRUD", 1.0)
    y = 18
    left = True
    while y > 4:
        if left:
            r.block(1, y, 5, y)
            r.plat(6, 11, y)
        else:
            r.block(34, y, 38, y)
            r.plat(28, 33, y)
        mid = 14 if left else 22
        r.plat(mid, mid + 3, y - 1 if y - 1 > 4 else y)
        y -= spacing
        left = not left
    r.plat(16, 23, 4)
    for k in range(orbs):
        r.put(19, 16 - k * 5, "i")
    for k in range(divers):
        r.put(9 + k * 20, 10, "f")
    r.put(4, 17, "e")


def fam_espiral(v, col_w):
    """Poço com paredes de espinhos: sobe em zigue-zague pelo meio."""
    r = Room("f_espiral_%d" % v, "shaft", "UD", 1.0)
    r.fill(1, 1, 8, 20, "#")
    r.fill(31, 1, 38, 20, "#")
    r.fill(9, 3, 9, 19, "^")
    r.fill(30, 3, 30, 19, "^")
    for k, y in enumerate((18, 15, 12, 9, 6)):
        if k % 2 == 0:
            r.plat(12 - col_w // 2, 18, y)
        else:
            r.plat(21, 27 + col_w // 2, y)
    r.plat(16, 23, 4)
    r.put(19, 10, "i")
    r.put(19, 16, "i")
    r.put(14, 8, "f")
    r.put(25, 13, "f")


def fam_corredor(v, ceiling, pockets, cover, shield_line):
    r = Room("f_corredor_%d" % v, "corridor", "LR", 1.0)
    r.fill(1, 1, 38, ceiling, "#")
    for k, px in enumerate(pockets):
        r.fill(px, ceiling - 1, px + 3, ceiling, ".")
        r.put(px + 1, ceiling, "f")
    for cx in cover:
        r.block(cx, 19, cx)
    if shield_line:
        r.plat(8, 31, ceiling + 5)
        for x in (12, 19, 26):
            r.put(x, 20, "e")
    else:
        r.put(14, 20, "e")
        r.put(25, 20, "e")
    r.block(34, 19, 35)
    r.put(36, 20, "u")
    r.put(19, ceiling + 3, "i")


def fam_cofre(v, pit_w, pillar_top):
    r = Room("f_cofre_%d" % v, "treasure", "LR", 1.0)
    x0 = 20 - pit_w // 2
    r.pit(x0, x0 + pit_w - 1, spikes=True, depth=2)
    r.block(18, pillar_top, 21, H - 2)
    y = 18
    lx, rx = x0, x0 + pit_w - 1
    while y > pillar_top:
        r.plat(lx, min(lx + 2, 17), y)
        r.plat(max(rx - 2, 22), rx, y)
        y -= 2
        lx = min(lx + 2, 15)
        rx = max(rx - 2, 24)
    r.put(19, pillar_top - 1, "C")
    r.put(20, pillar_top - 1, "c")
    r.put(x0 + 1, pillar_top - 3, "I")
    r.put(x0 + pit_w - 2, pillar_top - 3, "I")
    r.put(8, 20, "e")
    r.put(31, 20, "e")


# variações de cada família (parâmetros escolhidos à mão para cobrir o espaço)
for v, args in enumerate([((12, 27), [19], True, True, 2), ((10, 29), [15, 23], True, True, 1), ((14, 25), [19], False, True, 3),
                          ((9, 30), [14, 20, 25], True, False, 2), ((11, 28), [16, 22], False, True, 2)]):
    fam_ponte(v, *args)
for v, args in enumerate([([10, 19, 28], [2, 3, 2], True, True), ([8, 14, 24, 30], [3, 2, 2, 3], False, True),
                          ([12, 26], [3, 3], True, False), ([9, 16, 22, 29], [2, 3, 3, 2], True, True),
                          ([11, 19, 27], [3, 2, 3], False, False), ([7, 13, 25, 31], [2, 2, 2, 2], True, True)]):
    fam_pilares(v, *args)
for v, args in enumerate([(6, 9, True, True), (8, 8, False, True), (4, 11, True, False), (10, 6, False, False), (6, 12, True, True)]):
    fam_torre(v, *args)
for v, args in enumerate([(3, 4, True, "u"), (4, 3, False, "u"), (2, 5, True, "e"), (3, 3, True, "i")]):
    fam_zigurate(v, *args)
for v, args in enumerate([(22, 15, 3, 2), (20, 12, 2, 1), (24, 15, 2, 3), (18, 12, 3, 2)]):
    fam_penhasco(v, *args)
for v, args in enumerate([([11, 26], True, 10), ([18], False, 11), ([8, 19, 29], True, 9), ([14, 24], True, 11)]):
    fam_dois_andares(v, *args)
for v, args in enumerate([(20, 2), (24, 3), (16, 2), (22, 2)]):
    fam_abismo_morcegos(v, *args)
for v, args in enumerate([(3, 3), (3, 4), (3, 2)]):
    fam_arena_afundada(v, *args)
for v, args in enumerate([(15, [15, 12], False), (15, [15], True), (15, [15, 12, 9], False), (15, [15, 12], True)]):
    fam_arena_coliseu(v, *args)
for v, args in enumerate([(None, 4, 14, 0), ("alt", 4, 14, 1), (None, 5, 13, 1), ("alt", 3, 15, 2), (None, 3, 14, 0)]):
    fam_corrida(v, *args)
for v, args in enumerate([(4, 3, True), (5, 3, False), (3, 4, True), (6, 2, True)]):
    fam_caem(v, *args)
for v, args in enumerate([(18, 12, 2), (16, 9, 2), (20, 12, 1), (14, 9, 2)]):
    fam_escalada(v, *args)
for v, args in enumerate([(12, 3), (12, 2), (12, 4)]):
    fam_cascata(v, *args)
for v, args in enumerate([([5, 5, 5, 5], 14), ([6, 5, 6], 13), ([4, 6, 4, 6], 14), ([6, 6, 6], 12)]):
    fam_desafio_cristais(v, *args)
for v, args in enumerate([(3, 2, 2), (3, 3, 1), (3, 1, 2)]):
    fam_poco(v, *args)
for v, args in enumerate([(4,), (6,), (2,)]):
    fam_espiral(v, *args)
for v, args in enumerate([(11, [8, 19, 30], [16], False), (8, [12, 25], [10, 28], True), (12, [6, 16, 26], [20], False), (9, [20], [12, 27], True)]):
    fam_corredor(v, *args)
for v, args in enumerate([(12, 15), (16, 14), (10, 16)]):
    fam_cofre(v, *args)



# ---------------------------------------------------------------------------
# Mais famílias (saídas verticais e ideias novas)
# ---------------------------------------------------------------------------

def center_up(r, from_row):
    """Pilha de plataformas no centro de `from_row` até a linha 4 (saída U)."""
    y = from_row - 3
    k = 0
    while y > 4:
        cx = 17 if k % 2 == 0 else 22
        r.plat(cx - 3, cx + 2, y)
        y -= 3
        k += 1
    r.plat(16, 23, 4)


def fam_salao_vertical(v, tiers, orbs):
    r = Room("f_salao_%d" % v, "combat", "LRU", 1.0)
    for k in range(tiers):
        y = 18 - k * 3
        r.plat(2, 7 + k, y)
        r.plat(32 - k, 37, y)
        r.put(4 + k, y - 1, "e" if k % 2 == 0 else "u")
        r.put(35 - k, y - 1, "u" if k % 2 == 0 else "e")
    r.plat(8, 12, 18)
    r.plat(27, 31, 18)
    center_up(r, 21)
    for k in range(orbs):
        r.put(11 + k * 17, 10, "i")
    r.put(12, 20, "e")
    r.put(27, 20, "e")
    r.put(19, 7, "f")


def fam_queda(v, ring, snipers):
    r = Room("f_queda_%d" % v, "combat", "LRD", 1.0)
    r.fill(16, FL, 17, FL + 1, ".")
    r.fill(22, FL, 23, FL + 1, ".")
    r.fill(16, H - 1, 17, H - 1, "^")
    r.fill(22, H - 1, 23, H - 1, "^")
    r.plat(14 - ring, 17, 18)
    r.plat(22, 25 + ring, 18)
    r.plat(11, 15, 15)
    r.plat(24, 28, 15)
    r.put(12, 14, "u" if snipers else "e")
    r.put(27, 14, "u" if snipers else "e")
    for x in (5, 10, 29, 34):
        r.put(x, 20, "e")
    r.put(19, 12, "i")
    r.put(8, 9, "f")
    r.put(31, 9, "f")


def fam_torres_gemeas(v, gap, tower_top):
    r = Room("f_gemeas_%d" % v, "combat", "LR", 1.0)
    lx = 20 - gap // 2 - 4
    rx = 20 + gap // 2 + (gap % 2)
    r.block(lx, tower_top, lx + 3)
    r.block(rx, tower_top, rx + 3)
    r.plat(lx + 4, rx - 1, tower_top)
    for x0, x1 in ((lx - 4, lx - 1), (rx + 4, rx + 7)):
        y = 18
        k = 0
        while y > tower_top:
            r.plat(x0 - (k % 2), x1 - (k % 2), y)
            y -= 3
            k += 1
    r.put(lx + 1, tower_top - 1, "u")
    r.put(rx + 2, tower_top - 1, "u")
    r.put(20, tower_top - 1, "e")
    r.put(20, 20, "e")
    r.put(4, 20, "e")
    r.put(35, 20, "e")
    r.put(20, tower_top - 6, "i")
    r.put(9, 8, "f")
    r.put(30, 8, "f")


def fam_elevador(v, orb_x):
    r = Room("f_elevador_%d" % v, "platforming", "LRU", 1.0)
    r.pit(10, 29, spikes=True, depth=2)
    r.plat(10, 13, 18)
    r.plat(26, 29, 18)
    center_up(r, 19)
    for k, y in enumerate((16, 12, 8)):
        r.put(orb_x + (k % 2) * (38 - 2 * orb_x), y, "i")
    r.put(5, 20, "e")
    r.put(34, 20, "e")
    r.put(19, 20, "s")


def fam_galeria(v, arches, hang):
    r = Room("f_galeria_%d" % v, "combat", "LR", 1.0)
    r.fill(1, 1, 38, 3, "#")
    step = 36 // arches
    for k in range(arches):
        x = 2 + k * step
        r.fill(x, 4, x + 1, 4 + hang, "#")
        r.fill(x + 2, 4, x + step - 1, 4, "#")
        if k % 2 == 0:
            r.plat(x + 2, x + step - 1, 12)
    for x in range(6, 36, 6):
        r.put(x, 20, "e")
    r.put(13, 14, "u")
    r.put(25, 14, "u")
    r.put(19, 15, "i")
    r.put(19, 8, "f")
    r.plat(8, 12, 18)
    r.plat(26, 30, 18)
    r.plat(11, 15, 15)
    r.plat(23, 27, 15)


def fam_fosso_serras(v, saws, pillar_gap):
    r = Room("f_serras_%d" % v, "challenge", "LR", 1.0, "pain")
    r.pit(3, 36, spikes=True, depth=2)
    x = 3 + pillar_gap
    while x + 1 < 35:
        r.block(x, 18, x + 1, H - 2)
        x += pillar_gap + 2
    for k in range(saws):
        r.put(8 + k * (26 // max(saws - 1, 1)), 14 - (k % 2) * 3, "S")
    r.put(19, 8, "D")
    r.put(12, 10, "i")
    r.put(27, 10, "i")
    r.put(37, 20, "R")


def fam_poco_alcovas(v, depth):
    r = Room("f_alcovas_%d" % v, "shaft", "LRUD", 1.0)
    for k, y in enumerate((18, 15, 12, 9, 6)):
        left = k % 2 == 0
        if left:
            r.fill(1, y - 3, 1 + depth, y - 3, "#")
            r.plat(2, 13, y)
            r.put(3, y - 1, "e" if k < 4 else "c")
        else:
            r.fill(38 - depth, y - 3, 38, y - 3, "#")
            r.plat(26, 37, y)
            r.put(36, y - 1, "e" if k < 4 else "c")
        r.plat(15 if left else 20, 19 if left else 24, y - 1 if y > 6 else y)
    r.plat(16, 23, 4)
    r.put(19, 13, "i")
    r.put(10, 11, "f")
    r.put(29, 14, "f")


def fam_ninho(v, nest_top, legs):
    r = Room("f_ninho_%d" % v, "arena", "LR", 1.0, "lock")
    r.fill(12, nest_top, 27, nest_top, "#")
    for x in legs:
        r.fill(x, nest_top + 1, x, FL - 3, "#")
    y = 18
    k = 0
    while y > nest_top:
        r.plat(7 - (k % 2), 11, y)
        r.plat(28, 32 + (k % 2), y)
        y -= 3
        k += 1
    r.put(15, nest_top - 1, "U")
    r.put(24, nest_top - 1, "U")
    r.put(19, nest_top - 1, "E")
    for x in (4, 9, 15, 24, 30, 35):
        if r.g[20][x] == ".":
            r.put(x, 20, "E")
    r.put(12, 6, "F")
    r.put(27, 6, "F")
    r.put(19, nest_top - 5, "I")
    r.put(0, 17, "G")
    r.put(39, 17, "G")


def fam_criptas(v, tombs, secret):
    r = Room("f_criptas_%d" % v, "combat", "LR", 1.0)
    step = 30 // tombs
    for k in range(tombs):
        x = 6 + k * step
        r.block(x, 19, x + 2)
        r.put(x + 1, 18, "e" if k % 2 == 0 else ".")
    r.plat(9, 14, 16)
    r.plat(25, 30, 16)
    r.put(11, 15, "u")
    r.put(28, 15, "u")
    r.put(19, 11, "i")
    r.put(19, 20, "e")
    r.put(12, 8, "f")
    if secret:
        r.fill(1, 12, 5, 14, "#")
        r.fill(2, 13, 4, 13, ".")
        r.put(3, 13, "C")
        r.put(5, 13, "B")
        r.plat(2, 6, 15)


for v, args in enumerate([(3, 2), (2, 2), (4, 1)]):
    fam_salao_vertical(v, *args)
for v, args in enumerate([(2, True), (1, False), (3, True)]):
    fam_queda(v, *args)
for v, args in enumerate([(8, 15), (10, 12), (6, 15), (12, 15)]):
    fam_torres_gemeas(v, *args)
for v, args in enumerate([(8,), (6,), (10,)]):
    fam_elevador(v, *args)
for v, args in enumerate([(4, 3), (6, 2), (3, 4)]):
    fam_galeria(v, *args)
for v, args in enumerate([(3, 4), (4, 3), (2, 5)]):
    fam_fosso_serras(v, *args)
for v, args in enumerate([(3,), (4,)]):
    fam_poco_alcovas(v, *args)
for v, args in enumerate([(12, [14, 25]), (15, [13, 19, 26]), (12, [16, 23])]):
    fam_ninho(v, *args)
for v, args in enumerate([(4, True), (5, False), (3, True)]):
    fam_criptas(v, *args)


def validate():
    for r in ROOMS:
        rows = r.rows()
        assert len(rows) == H, r.id
        for i, row in enumerate(rows):
            assert len(row) == W, (r.id, i, len(row))


def write():
    validate()
    lines = [
        "# GERADO por tools/build_rooms.py — edite lá (ou copie para outro .txt e edite à mão).",
        "# Tokens aleatórios: e f u i s c d j + o (seguros) e grupos 1 2 3 (bloco) 4 5 (espinho).",
        "",
    ]
    for r in ROOMS:
        lines.append("@room " + r.id)
        lines.append("type: " + r.type)
        lines.append("exits: " + r.exits)
        lines.append("weight: %.1f" % r.weight)
        lines.append("tags: " + r.tags)
        if r.biomes != "*":
            lines.append("biomes: " + r.biomes)
        lines.extend(r.rows())
        lines.append("@end")
        lines.append("")
    with open(OUT, "w") as f:
        f.write("\n".join(lines))
    print("%d estruturas -> %s" % (len(ROOMS), OUT))


if __name__ == "__main__":
    write()
