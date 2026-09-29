#!/usr/bin/env python3
"""Atlas de tiles 8x8 por MATERIAL (um por tipo de lugar), com relevo:
tijolos chanfrados (luz em cima/esquerda, sombra embaixo/direita), rocha
rachada, terra com raízes, paralelepípedos, madeira, mármore com veios e
dourado, toras, pedra rúnica, ossos. Superfícies próprias (grama que
transborda a borda, musgo, areia, grama seca, friso dourado), plataformas,
espinhos e decorações no tema de cada lugar.

Mesmo layout de papéis do TileSetBuilder (8 colunas x 4 linhas):
  linha 0: TOPO 0-3 | TOPO_E | TOPO_D | TOPO_ÚNICO | QUEBRÁVEL
  linha 1: SUB 0-3  | PLAT_E | PLAT_M | PLAT_D | ESPINHOS
  linha 2: FILL 0-3 | BORDA_E | BORDA_D | TETO | PONTO
  linha 3: DECO 0-3 | FUNDO 0-3
Uso: python3 tools/build_tiles.py
"""
import os
import random

from PIL import Image

T = 8
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "tilesets")


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def lit(c, t):
    return mix(c, (255, 255, 255, 255), t)


def dim(c, t):
    return mix(c, (0, 0, 0, 255), t)


# Cada conjunto: material do corpo, superfície, plataforma, espinhos, deco,
# fundo e paleta (base, escuro, claro, contorno, superfície clara/escura,
# acento, fundo).
SETS = {
    "castle": {"body": "bricks", "top": "moss", "plat": "stone", "spike": "iron", "deco": "grass_moss", "bg": "bricks",
               "pal": {"base": "#6c7288", "dark": "#4c5166", "light": "#9aa1b8", "line": "#1a1a26", "top": "#6e9a5e", "top_d": "#4d7446", "acc": "#c7a66a", "bg": "#34384a"}},
    "graveyard": {"body": "earth", "top": "deadgrass", "plat": "wood", "spike": "iron", "deco": "graves", "bg": "rock",
                  "pal": {"base": "#4e4250", "dark": "#372e3a", "light": "#6b5d6c", "line": "#140f18", "top": "#7d8a6a", "top_d": "#56604a", "acc": "#b8c0a0", "bg": "#2a2432"}},
    "forest": {"body": "earth", "top": "grass", "plat": "wood", "spike": "thorn", "deco": "flowers", "bg": "rock",
               "pal": {"base": "#6d4c34", "dark": "#4f3624", "light": "#8f6a48", "line": "#1e140e", "top": "#6cbf4a", "top_d": "#3f8a35", "acc": "#f0d060", "bg": "#2c3a2a"}},
    "town": {"body": "cobble", "top": "cap", "plat": "wood", "spike": "iron", "deco": "town", "bg": "planks",
             "pal": {"base": "#7a6a66", "dark": "#574a48", "light": "#a39390", "line": "#1d1618", "top": "#b8a8a0", "top_d": "#8a7a74", "acc": "#e0b060", "bg": "#3e3236"}},
    "temple": {"body": "sandstone", "top": "carved", "plat": "stone", "spike": "gold", "deco": "candles", "bg": "sandstone",
               "pal": {"base": "#c49258", "dark": "#9a6e40", "light": "#e8bc7c", "line": "#3a2616", "top": "#f0cc88", "top_d": "#c8a060", "acc": "#fff0a0", "bg": "#4e3626"}},
    "desert": {"body": "sandstone", "top": "sand", "plat": "wood", "spike": "bone", "deco": "desert", "bg": "sandstone",
               "pal": {"base": "#c8955e", "dark": "#a0704a", "light": "#e6b882", "line": "#3a2616", "top": "#f2d49a", "top_d": "#dab478", "acc": "#6a9a4a", "bg": "#523a28"}},
    "cave": {"body": "rock", "top": "moss", "plat": "stone", "spike": "crystal", "deco": "mushrooms", "bg": "rock",
             "pal": {"base": "#4a4a5e", "dark": "#34344a", "light": "#6a6a82", "line": "#101018", "top": "#5a7a6a", "top_d": "#3e5a4e", "acc": "#70e0f0", "bg": "#23232f"}},
    "sky": {"body": "marble", "top": "goldtrim", "plat": "marble", "spike": "gold", "deco": "sky", "bg": "marble",
            "pal": {"base": "#d8dce8", "dark": "#b0b6c8", "light": "#f4f6fb", "line": "#4a4e66", "top": "#f0d070", "top_d": "#c8a040", "acc": "#90d0ff", "bg": "#6a7090"}},
    "swamp": {"body": "earth", "top": "mud", "plat": "wood", "spike": "thorn", "deco": "reeds", "bg": "rock",
              "pal": {"base": "#4e5238", "dark": "#383b28", "light": "#6a6e4c", "line": "#161810", "top": "#6a8a3e", "top_d": "#4a6a2e", "acc": "#c0e070", "bg": "#262a1e"}},
    "war": {"body": "logs", "top": "deadgrass", "plat": "wood", "spike": "stakes", "deco": "war", "bg": "planks",
            "pal": {"base": "#6e4a32", "dark": "#4e3222", "light": "#8e6646", "line": "#1c120c", "top": "#8a7a50", "top_d": "#62563a", "acc": "#c05030", "bg": "#35251c"}},
    "arcane": {"body": "runes", "top": "cap", "plat": "stone", "spike": "crystal", "deco": "arcane", "bg": "bricks",
               "pal": {"base": "#5a4a7a", "dark": "#40345a", "light": "#7e6aa4", "line": "#140e22", "top": "#8a78b8", "top_d": "#6a5a94", "acc": "#c080ff", "bg": "#2c2440"}},
    "catacomb": {"body": "bones", "top": "cap", "plat": "bone", "spike": "bone", "deco": "graves", "bg": "bricks",
                 "pal": {"base": "#5e5448", "dark": "#443c34", "light": "#7e7262", "line": "#16120e", "top": "#8a7e6a", "top_d": "#6a604e", "acc": "#e8e0c8", "bg": "#2e2822"}},
    "ruins": {"body": "bricks", "top": "grass", "plat": "stone", "spike": "iron", "deco": "grass_moss", "bg": "bricks",
              "pal": {"base": "#8a7c78", "dark": "#665a58", "light": "#b0a29c", "line": "#221a1c", "top": "#7eac5a", "top_d": "#5a8440", "acc": "#e0b0a0", "bg": "#4a3e40"}},
}


def new():
    return Image.new("RGBA", (T, T), (0, 0, 0, 0))


# ---------------------------------------------------------------------------
# Texturas de corpo (preenchem o tile inteiro)
# ---------------------------------------------------------------------------

def body(px, kind, P, v, rnd, deep=False):
    base, dark, light, line = P["base"], P["dark"], P["light"], P["line"]
    if deep:
        # miolo da rocha: escuro e calmo (detalhe só perto da superfície)
        deep_c = dim(mix(base, dark, 0.5), 0.42)
        for y in range(T):
            for x in range(T):
                px[x, y] = deep_c
        for i in range(2):
            px[rnd.randrange(T), rnd.randrange(T)] = dim(deep_c, 0.18)
        px[rnd.randrange(T), rnd.randrange(T)] = lit(deep_c, 0.06)
        return
    for y in range(T):
        for x in range(T):
            px[x, y] = base
    if kind in ("bricks", "runes"):
        # tijolos 4 de altura, juntas desencontradas por linha, com chanfro
        for row in (0, 4):
            off = (2 + v * 3) % T if row == 0 else (6 + v) % T
            for x in range(T):
                px[x, row + 3] = dark
            for (x0, x1) in ((off - T, off), (off, off + T)):
                for y in range(row, row + 3):
                    xa = x0 % T
                    px[xa, y] = dark
                for x in range(x0 + 1, x1):
                    if 0 <= x < T:
                        px[x, row] = light
        if kind == "runes" and v % 2 == 0 and not deep:
            acc = P["acc"]
            px[3, 1] = acc
            px[4, 2] = acc
            px[3, 5] = acc
            px[5, 5] = acc
    elif kind == "rock":
        for i in range(6):
            x, y = rnd.randrange(T), rnd.randrange(T)
            px[x, y] = dark if i % 2 else light
        # rachadura
        x = rnd.randrange(1, T - 1)
        for y in range(rnd.randrange(0, 3), rnd.randrange(4, T)):
            px[x, y] = dark
            if rnd.random() < 0.4:
                x = max(0, min(T - 1, x + rnd.choice((-1, 1))))
    elif kind == "earth":
        for i in range(5):
            x, y = rnd.randrange(T), rnd.randrange(T)
            px[x, y] = dark
        for i in range(2):
            x, y = rnd.randrange(T - 1), rnd.randrange(T - 1)
            px[x, y] = light
            px[x + 1, y] = light
            px[x, y + 1] = dark
        if v == 1:
            # raiz
            y = rnd.randrange(2, T - 1)
            for x in range(1, T - 1):
                px[x, y] = dim(P["dark"], 0.1)
                if rnd.random() < 0.3:
                    y = max(1, min(T - 2, y + rnd.choice((-1, 1))))
    elif kind == "cobble":
        stones = [(0, 0, 4, 4), (4, 0, 4, 3), (4, 3, 4, 5), (0, 4, 4, 4)] if v % 2 == 0 else [(0, 0, 3, 4), (3, 0, 5, 4), (0, 4, 5, 4), (5, 4, 3, 4)]
        for (x0, y0, w, h) in stones:
            for y in range(y0, y0 + h):
                for x in range(x0, x0 + w):
                    edge = x == x0 or y == y0 or x == x0 + w - 1 or y == y0 + h - 1
                    corner = (x in (x0, x0 + w - 1)) and (y in (y0, y0 + h - 1))
                    px[x % T, y % T] = line if corner else (dark if edge and (x == x0 + w - 1 or y == y0 + h - 1) else (light if edge else base))
    elif kind == "planks":
        for x in range(T):
            for y in range(T):
                px[x, y] = base if (x // 4 + v) % 2 == 0 else dark
        for y in range(T):
            px[(3 + v) % T, y] = line
        px[1, (2 + v) % T] = dark
        px[6, (5 + v) % T] = light
    elif kind == "sandstone":
        for y in (3, 7):
            for x in range(T):
                px[x, y] = dark
        for x in range(T):
            px[x, 0] = light
            px[x, 4] = light
        px[(1 + 2 * v) % T, 1] = dark
        px[(5 + v) % T, 5] = dark
        if v == 2:
            px[2, 5] = px[3, 5] = px[4, 5] = dark
    elif kind == "marble":
        for i in range(3):
            x = rnd.randrange(T)
            for y in range(T):
                if rnd.random() < 0.55:
                    px[x, y] = dark
                x = max(0, min(T - 1, x + rnd.choice((-1, 0, 1))))
        for x in range(T):
            px[x, 0] = light
    elif kind == "logs":
        for x in range(T):
            col = light if x % 4 == 0 else (dark if x % 4 == 3 else base)
            for y in range(T):
                px[x, y] = col
        px[(1 + v) % 4 + 1, 3] = dark
        px[(1 + v) % 4 + 5 if (1 + v) % 4 + 5 < T else 5, 5] = dark
    elif kind == "bones":
        for i in range(4):
            x, y = rnd.randrange(T), rnd.randrange(T)
            px[x, y] = dark
        if v in (0, 2):
            bone = P["acc"]
            y = 3 + (v // 2)
            for x in range(2, 6):
                px[x, y] = bone
            px[1, y - 1] = px[1, y + 1] = bone
            px[6, y - 1] = px[6, y + 1] = bone
        elif v == 1:
            sk = P["acc"]
            for (x, y) in [(3, 2), (4, 2), (2, 3), (3, 3), (4, 3), (5, 3), (2, 4), (5, 4), (3, 5), (4, 5)]:
                px[x, y] = sk
            px[3, 4] = px[4, 4] = line


# ---------------------------------------------------------------------------
# Superfícies (sobre o topo do tile)
# ---------------------------------------------------------------------------

def surface(px, kind, P, v, rnd, left=False, right=False):
    top, top_d, line = P["top"], P["top_d"], P["line"]
    if kind == "grass":
        for x in range(T):
            px[x, 0] = lit(top, 0.25)
            px[x, 1] = top
            px[x, 2] = top_d if (x + v) % 3 else top
            if (x + v) % 4 == 1:
                px[x, 3] = top_d
    elif kind == "moss":
        for x in range(T):
            px[x, 0] = top
            px[x, 1] = top_d if (x + v) % 2 else top
            if (x * 3 + v) % 5 == 0:
                px[x, 2] = top_d
    elif kind == "deadgrass":
        for x in range(T):
            px[x, 0] = top
            px[x, 1] = top_d
            if (x + v) % 3 == 0:
                px[x, 2] = top_d
    elif kind == "sand":
        for x in range(T):
            px[x, 0] = lit(top, 0.3)
            px[x, 1] = top
            px[x, 2] = top_d
        px[(2 + v * 2) % T, 1] = top_d
    elif kind == "mud":
        for x in range(T):
            px[x, 0] = top
            px[x, 1] = top_d
            px[x, 2] = dim(top_d, 0.2)
        px[(1 + v * 3) % T, 3] = top_d
    elif kind == "goldtrim":
        for x in range(T):
            px[x, 0] = lit(P["light"], 0.3)
            px[x, 1] = top
            px[x, 2] = top_d
    elif kind == "carved":
        for x in range(T):
            px[x, 0] = lit(top, 0.2)
            px[x, 1] = top
            px[x, 2] = top_d if x % 4 in (0, 3) else top
            px[x, 3] = P["dark"]
    else:  # cap: pedra mais clara em cima
        for x in range(T):
            px[x, 0] = lit(top, 0.2)
            px[x, 1] = top
            px[x, 2] = top_d
    if left:
        for y in range(T):
            px[0, y] = line
    if right:
        for y in range(T):
            px[T - 1, y] = line


def platform(kind, P, part):
    im = new()
    px = im.load()
    if kind == "wood":
        c, d, l = hexc("#9a6a42"), hexc("#6e4a2c"), hexc("#c08a58")
    elif kind == "marble":
        c, d, l = P["base"], P["dark"], P["light"]
    elif kind == "bone":
        c, d, l = P["acc"], dim(P["acc"], 0.35), lit(P["acc"], 0.3)
    else:
        c, d, l = P["light"], P["dark"], lit(P["light"], 0.25)
    for x in range(T):
        px[x, 0] = l
        px[x, 1] = c
        px[x, 2] = d
    if kind == "wood":
        px[3, 1] = d
        if part == "M":
            px[7, 1] = d
    if part == "L":
        px[0, 0] = px[0, 1] = px[0, 2] = P["line"]
        px[1, 3] = d
    if part == "R":
        px[T - 1, 0] = px[T - 1, 1] = px[T - 1, 2] = P["line"]
        px[T - 2, 3] = d
    return im


def spikes(kind, P):
    im = new()
    px = im.load()
    cols = {"iron": ("#e8e8f0", "#9898ac"), "gold": ("#fff0a0", "#c8a040"), "bone": ("#f0e8d0", "#b8ac90"),
            "crystal": ("#c0f8ff", "#50b8d8"), "thorn": ("#9a8a5a", "#5a4a2a"), "stakes": ("#c89a6a", "#7a5434")}
    light, dark = hexc(cols[kind][0]), hexc(cols[kind][1])
    rows = [".#..", ".##.", "###.", "####"] if kind != "thorn" else ["#..#", ".##.", "#.##", "####"]
    for x0 in (0, 4):
        for yi, row in enumerate(rows):
            for xi, ch in enumerate(row):
                if ch == "#":
                    px[x0 + xi, 4 + yi] = light if xi < 2 else dark
    return im


def deco(kind, P, v):
    """Decoração pousada sobre a superfície (desenhada no tile de cima)."""
    im = new()
    px = im.load()
    rnd = random.Random(hash((kind, v)))
    g, gd, acc = P["top"], P["top_d"], P["acc"]
    if kind in ("flowers", "grass_moss"):
        for x in [1 + v % 2, 3, 5, 6 - v % 2]:
            h = 1 + (x + v) % 3
            for y in range(T - h, T):
                px[x, y] = g if y > T - h else lit(g, 0.2)
        if kind == "flowers" and v in (1, 3):
            fx = 3 if v == 1 else 5
            px[fx, T - 4] = acc if v == 1 else hexc("#e070a0")
            px[fx, T - 3] = gd
    elif kind == "graves":
        if v == 0:
            for y in range(3, 8):
                for x in range(2, 6):
                    px[x, y] = P["light"]
            px[2, 3] = px[5, 3] = (0, 0, 0, 0)
            px[3, 5] = px[4, 5] = P["dark"]
        elif v == 1:
            for y in range(2, 8):
                px[4, y] = P["light"]
            for x in range(2, 7):
                px[x, 3] = P["light"]
        else:
            for x in [2, 5]:
                px[x, 7] = gd
                px[x, 6] = g
    elif kind == "mushrooms":
        if v % 2 == 0:
            px[3, 7] = px[3, 6] = hexc("#e0d8c0")
            for x in range(2, 5):
                px[x, 5] = acc if v == 0 else hexc("#e05050")
            px[3, 4] = acc if v == 0 else hexc("#e05050")
        else:
            px[4, 7] = px[5, 6] = acc
            px[5, 7] = dim(acc, 0.3)
    elif kind == "candles":
        if v < 2:
            px[3 + v, 7] = px[3 + v, 6] = px[3 + v, 5] = hexc("#f0e8d0")
            px[3 + v, 4] = hexc("#ffd060")
        else:
            px[2, 7] = px[5, 7] = P["light"]
    elif kind == "desert":
        if v == 0:
            for y in range(3, 8):
                px[4, y] = acc
            px[3, 4] = px[5, 5] = acc
        else:
            px[3 + v % 2, 7] = P["dark"]
    elif kind == "town":
        if v == 0:
            px[2, 7] = px[5, 7] = hexc("#6e4a2c")
            for x in range(2, 6):
                px[x, 6] = hexc("#9a6a42")
        elif v == 1:
            px[4, 7] = px[4, 6] = P["dark"]
            px[4, 5] = acc
        else:
            px[3, 7] = g
    elif kind == "reeds":
        for x in [2, 4, 5]:
            h = 3 + (x + v) % 4
            for y in range(T - h, T):
                px[x, y] = g if (y + x) % 2 else gd
        if v == 2:
            px[4, T - 7] = hexc("#6a4a2a")
    elif kind == "war":
        if v == 0:
            for y in range(1, 8):
                px[3, y] = hexc("#6e4a2c")
            for y in range(1, 4):
                for x in range(4, 7):
                    px[x, y] = acc
        else:
            px[3, 7] = px[4, 7] = P["dark"]
    elif kind == "arcane":
        if v % 2 == 0:
            px[4, 5] = px[3, 6] = px[4, 6] = px[5, 6] = acc
            px[4, 7] = dim(acc, 0.3)
        else:
            px[3, 7] = P["light"]
    elif kind == "sky":
        if v == 0:
            for x in range(1, 7):
                px[x, 7] = hexc("#ffffff")
            for x in range(2, 5):
                px[x, 6] = hexc("#ffffff")
        else:
            px[4, 7] = px[4, 6] = g
    return im


def bgtile(kind, P, v, rnd):
    im = new()
    px = im.load()
    bgc = dim(P["bg"], 0.12)
    PB = dict(P)
    PB["base"], PB["dark"], PB["light"], PB["line"] = bgc, dim(bgc, 0.18), lit(bgc, 0.06), dim(bgc, 0.3)
    PB["acc"] = bgc
    body(px, kind if kind != "runes" else "bricks", PB, v, rnd)
    return im


def edge(side, P):
    im = new()
    px = im.load()
    line = P["line"]
    for i in range(T):
        if side == "L":
            px[0, i] = line
        elif side == "R":
            px[T - 1, i] = line
        elif side == "B":
            px[i, T - 1] = line
            if i % 3 == 1:
                px[i, T - 2] = P["dark"]
    if side == "DOT":
        px[0, 0] = line
    return im


def build(name, S):
    P = {k: hexc(v) for k, v in S["pal"].items()}
    atlas = Image.new("RGBA", (8 * T, 4 * T), (0, 0, 0, 0))
    rnd = random.Random(name)

    def put(im, cx, cy):
        atlas.paste(im, (cx * T, cy * T))

    for i in range(4):
        # topo
        im = new()
        body(im.load(), S["body"], P, i, random.Random(name + "t%d" % i))
        surface(im.load(), S["top"], P, i, rnd)
        put(im, i, 0)
        # sub-superfície e preenchimento (mais escuro = fundo da rocha)
        im = new()
        body(im.load(), S["body"], P, i, random.Random(name + "s%d" % i))
        put(im, i, 1)
        im = new()
        body(im.load(), S["body"], P, i, random.Random(name + "f%d" % i), deep=True)
        put(im, i, 2)
        put(deco(S["deco"], P, i), i, 3)
        put(bgtile(S["bg"], P, i, random.Random(name + "b%d" % i)), 4 + i, 3)
    for (cx, l, r) in ((4, True, False), (5, False, True), (6, True, True)):
        im = new()
        body(im.load(), S["body"], P, cx % 4, random.Random(name + "e%d" % cx))
        surface(im.load(), S["top"], P, cx % 4, rnd, left=l, right=r)
        put(im, cx, 0)
    # quebrável: corpo com rachaduras marcadas
    im = new()
    body(im.load(), S["body"], P, 1, random.Random(name + "br"))
    bpx = im.load()
    for (x, y) in [(2, 1), (3, 2), (3, 3), (4, 4), (5, 5), (2, 5), (1, 6), (6, 2)]:
        bpx[x, y] = P["line"]
    put(im, 7, 0)
    put(platform(S["plat"], P, "L"), 4, 1)
    put(platform(S["plat"], P, "M"), 5, 1)
    put(platform(S["plat"], P, "R"), 6, 1)
    put(spikes(S["spike"], P), 7, 1)
    put(edge("L", P), 4, 2)
    put(edge("R", P), 5, 2)
    put(edge("B", P), 6, 2)
    put(edge("DOT", P), 7, 2)
    atlas.save(os.path.join(OUT, name + ".png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n, S in SETS.items():
        build(n, S)
    print("%d tilesets gerados" % len(SETS))
