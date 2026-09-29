"""Arte do MAPA-MÚNDI explorável (visão de cima 3/4, estilo Stardew Valley).

    python3 tools/overworld_art.py [--preview DIR]

Saídas (assets/art/overworld/):
  ground.png  atlas de tiles 8x8 (8 colunas). Cada material ocupa uma linha
              com 8 variações (0-3 lisas, 4-7 com detalhes). Linhas especiais:
              estrada de terra e margem de água têm 16 variações pela máscara
              de vizinhos (bit 1=cima, 2=direita, 4=baixo, 8=esquerda).
  ground.json {"materials": {nome: linha}, "masked": {nome: linha}, ...}
  objects.png + objects.json   objetos com âncora nos pés e caixa de colisão.

Tudo é desenhado com primitivas + contorno automático (tools/px.py).
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from px import Canvas, hexc, preview  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "art", "overworld")
T = 8
OUTLINE = hexc("1b1528")


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dark(c, k=0.8):
    return (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)


def light(c, k=0.2):
    return mix(c, (255, 255, 255, 255), k)


# ---------------------------------------------------------------------------
# Chão
# ---------------------------------------------------------------------------
# nome: (base, escuro, claro, detalhe, estilo)
GROUNDS = {
    "grass": ("6aa84f", "578f40", "86c464", "f2e27a", "grass"),
    "grass_dark": ("4f6b4a", "425a3f", "65825c", "b8a8d8", "grass"),
    "sand": ("e6c98a", "d4b477", "f4dea6", "c49a62", "sand"),
    "gold_sand": ("e8c46a", "d0a852", "f6dc8e", "fff0b0", "sand"),
    "cobble": ("7d7f92", "5f6174", "9799ab", "6a8a5a", "cobble"),
    "ruin": ("8a8a76", "6e6e5e", "a4a48e", "6f9a4e", "slab"),
    "swamp": ("56663f", "46552f", "6d7d4f", "7fa0a0", "grass"),
    "red_dirt": ("a0643e", "86502e", "b87a50", "d8b070", "dirt"),
    "snow": ("e8eef4", "cfd8e4", "ffffff", "a8c0d8", "snow"),
    "cloud": ("dfe8fa", "c4d2f0", "f8fbff", "f0d27a", "cloud"),
    "cave": ("4d4a5c", "3e3b4c", "625f72", "7ad8e8", "cave"),
    "arcane": ("5e7a8e", "4d6478", "7896aa", "d08af0", "grass"),
    "moss_cave": ("4a5a3c", "3c4a30", "5e704a", "c8e070", "cave"),
    "plaza": ("b4ab9a", "968e7e", "cfc6b4", "8a7a66", "pavers"),
    "forest_floor": ("3d5a34", "31492a", "4a6a40", "2a3a24", "grass"),
    "bridge_h": ("9a6a40", "7a5030", "b8845a", "5a3a24", "planks_h"),
    "bridge_v": ("9a6a40", "7a5030", "b8845a", "5a3a24", "planks_v"),
    "deep_water": ("2f5f9a", "284f84", "3c72b0", "5a90c8", "water"),
    "sky_road": ("bcd8ff", "9cc0f4", "eaf4ff", "fff4c0", "light"),
    "tunnel": ("5a5048", "46403a", "6e6258", "8a7a6a", "rails"),
    "rift": ("5a3a8a", "46306e", "7a52b0", "d8a8ff", "crystal"),
    "rock_wall": ("6e6878", "4e4a58", "8e889a", "3a3644", "boulders"),
    "sky_void": ("7aa8e8", "6a98dc", "a8c8f4", "ffffff", "void"),
}
MASKED = {"road": ("b08a5a", "94704a", "c8a270", "7a5a3a"), "water": ("3f7fc0", "356fb0", "5a98d4", "d8ecff")}


def ground_tile(name, variant, rng):
    spec = GROUNDS[name]
    base, dk, lt, det = [hexc(x) for x in spec[:4]]
    style = spec[4]
    c = Canvas(T, T)
    c.rect(0, 0, T, T, base)
    deco = variant >= 4
    if style == "grass":
        for _ in range(5):
            x, y = rng.randrange(T), rng.randrange(1, T)
            c.set(x, y, dk)
            c.set(x, y - 1, dk if rng.random() < 0.5 else base)
        for _ in range(2):
            c.set(rng.randrange(T), rng.randrange(T), lt)
        if deco:
            # flores (2-3 pétalas) ou tufo
            if variant % 2 == 0:
                x, y = rng.randrange(1, T - 1), rng.randrange(1, T - 1)
                c.set(x, y, det)
                c.set(x + 1, y, det)
                c.set(x, y + 1, light(det, 0.3))
                c.set(x + 1, y + 1, dark(det, 0.8))
            else:
                x = rng.randrange(1, T - 2)
                c.vline(x, 3, 6, dk)
                c.vline(x + 2, 4, 6, dk)
                c.set(x + 1, 2, lt)
                c.vline(x + 1, 3, 6, dark(dk, 0.85))
    elif style == "sand":
        for _ in range(4):
            c.set(rng.randrange(T), rng.randrange(T), dk)
        for _ in range(3):
            c.set(rng.randrange(T), rng.randrange(T), lt)
        if deco:
            x, y = rng.randrange(1, T - 2), rng.randrange(2, T - 1)
            # ondinha de duna ou pedrinha
            if variant % 2 == 0:
                c.hline(x, x + 2, y, dk)
                c.set(x + 1, y - 1, lt)
            else:
                c.set(x, y, det)
                c.set(x + 1, y, dark(det))
    elif style == "cobble":
        c.rect(0, 0, T, T, dk)
        for (x0, y0, w, h) in ((0, 0, 4, 3), (4, 0, 4, 3), (1, 4, 3, 4), (5, 4, 3, 4)) if variant % 2 == 0 else ((0, 0, 3, 4), (3, 0, 5, 3), (0, 5, 4, 3), (4, 4, 4, 4)):
            c.rect(x0, y0, w - 1, h - 1, base)
            c.hline(x0, x0 + w - 2, y0, lt)
        if deco:
            c.set(rng.randrange(T), rng.randrange(T), det)
            c.set(rng.randrange(T), rng.randrange(T), det)
    elif style == "slab":
        c.rect(0, 0, T, T, base)
        c.hline(0, 7, 3 + variant % 2, dk)
        c.vline(3 + variant % 3, 0, 3 + variant % 2, dk)
        c.set(rng.randrange(T), rng.randrange(T), lt)
        if deco:
            for _ in range(3):
                c.set(rng.randrange(T), rng.randrange(T), det)
    elif style == "dirt":
        for _ in range(6):
            c.set(rng.randrange(T), rng.randrange(T), dk)
        for _ in range(2):
            c.set(rng.randrange(T), rng.randrange(T), lt)
        if deco:
            x, y = rng.randrange(1, T - 2), rng.randrange(1, T - 2)
            c.set(x, y, det)
            c.set(x + 1, y + 1, dark(det))
    elif style == "snow":
        for _ in range(3):
            c.set(rng.randrange(T), rng.randrange(T), dk)
        if deco:
            x, y = rng.randrange(1, T - 2), rng.randrange(2, T - 1)
            c.hline(x, x + 2, y, dk)
            c.set(x + 1, y - 1, det)
    elif style == "cloud":
        for _ in range(3):
            x, y = rng.randrange(T), rng.randrange(T)
            c.set(x, y, lt)
            c.set((x + 1) % T, y, lt)
        c.set(rng.randrange(T), rng.randrange(T), dk)
        if deco:
            x, y = rng.randrange(1, T - 1), rng.randrange(1, T - 1)
            c.set(x, y, det)
    elif style == "cave":
        for _ in range(5):
            c.set(rng.randrange(T), rng.randrange(T), dk)
        for _ in range(2):
            c.set(rng.randrange(T), rng.randrange(T), lt)
        if deco:
            x, y = rng.randrange(1, T - 1), rng.randrange(2, T - 1)
            c.set(x, y, det)
            c.set(x, y - 1, light(det, 0.4))
    elif style == "pavers":
        c.rect(0, 0, T, T, dk)
        c.rect(0, 0, 3, 3, base)
        c.rect(4, 0, 3, 3, base)
        c.rect(0, 4, 3, 3, base)
        c.rect(4, 4, 3, 3, base)
        c.set(0, 0, lt)
        c.set(4, 4, lt)
        if deco:
            c.set(rng.randrange(T), rng.randrange(T), det)
    elif style in ("planks_h", "planks_v"):
        for i in range(T):
            if i % 3 == 2:
                if style == "planks_h":
                    c.hline(0, 7, i, dk)
                else:
                    c.vline(i, 0, 7, dk)
        if style == "planks_h":
            c.set(variant % 4 * 2, 1, det)
            c.set((variant % 4 * 2 + 4) % 8, 4, det)
        else:
            c.set(1, variant % 4 * 2, det)
            c.set(4, (variant % 4 * 2 + 4) % 8, det)
    elif style == "water":
        for _ in range(2):
            x, y = rng.randrange(T - 2), rng.randrange(T)
            c.hline(x, x + 2, y, lt if variant % 2 == 0 else dk)
    elif style == "light":
        c.rect(0, 0, T, T, base)
        for i in range(T):
            if (i + variant) % 4 == 0:
                c.vline(i, 0, 7, lt)
        if deco:
            c.set(rng.randrange(T), rng.randrange(T), det)
    elif style == "rails":
        c.rect(0, 0, T, T, base)
        for _ in range(4):
            c.set(rng.randrange(T), rng.randrange(T), dk)
        c.hline(0, 7, 1, det)
        c.hline(0, 7, 6, det)
        c.vline(2 + variant % 2 * 3, 1, 6, dark(det, 0.7))
    elif style == "crystal":
        for _ in range(4):
            c.set(rng.randrange(T), rng.randrange(T), dk)
        x, y = rng.randrange(1, T - 2), rng.randrange(2, T - 1)
        c.set(x, y, det)
        c.set(x, y - 1, light(det, 0.5))
        if deco:
            c.set(rng.randrange(T), rng.randrange(T), lt)
    elif style == "boulders":
        c.rect(0, 0, T, T, det)
        rr = random.Random(variant * 17 + 3)
        for _ in range(2):
            cx, cy = rr.randrange(1, 7), rr.randrange(1, 7)
            rx, ry = rr.choice([2.6, 3.2, 3.6]), rr.choice([2.2, 2.8])
            c.ellipse(cx + 0.5, cy + 0.5, rx, ry, dk)
            c.ellipse(cx + 0.2, cy, rx - 0.8, ry - 0.8, base)
            c.set(cx - 1, cy - 1, lt)
    elif style == "void":
        for _ in range(2):
            c.set(rng.randrange(T), rng.randrange(T), lt)
        if deco:
            x, y = rng.randrange(0, T - 3), rng.randrange(1, T - 2)
            c.hline(x, x + 3, y, det)
            c.hline(x + 1, x + 2, y - 1, det)
    return c


def masked_tile(name, mask, rng):
    """Estrada/água: borda irregular do lado dos vizinhos que NÃO são do mesmo material."""
    base, dk, lt, det = [hexc(x) for x in MASKED[name]]
    c = Canvas(T, T)
    c.rect(0, 0, T, T, base)
    if name == "road":
        for _ in range(4):
            c.set(rng.randrange(T), rng.randrange(T), dk)
        c.set(rng.randrange(T), rng.randrange(T), lt)
        # borda: sombra de 1 px com falhas + pedrinhas
        up, right, down, left = mask & 1, mask & 2, mask & 4, mask & 8
        for i in range(T):
            if not up and rng.random() < 0.8:
                c.set(i, 0, det)
            if not down and rng.random() < 0.8:
                c.set(i, T - 1, dk)
            if not left and rng.random() < 0.8:
                c.set(0, i, dk)
            if not right and rng.random() < 0.8:
                c.set(T - 1, i, dk)
    else:
        for _ in range(2):
            x, y = rng.randrange(T - 2), rng.randrange(1, T - 1)
            c.hline(x, x + 2, y, lt)
        up, right, down, left = mask & 1, mask & 2, mask & 4, mask & 8
        # espuma clara onde encosta na terra
        for i in range(T):
            if not up:
                c.set(i, 0, det)
                if (i + mask) % 3 == 0:
                    c.set(i, 1, lt)
            if not down:
                c.set(i, T - 1, dk)
            if not left:
                c.set(0, i, det)
            if not right:
                c.set(T - 1, i, det)
    return c


def build_ground():
    names = list(GROUNDS.keys())
    rows = len(names) + 4  # + estrada (2 linhas) + água (2 linhas)
    atlas = Image.new("RGBA", (8 * T, rows * T), (0, 0, 0, 0))
    meta = {"tile": T, "cols": 8, "materials": {}, "masked": {}, "solid": ["deep_water", "rock_wall", "sky_void", "forest_floor"]}
    for row, n in enumerate(names):
        meta["materials"][n] = row
        for v in range(8):
            rng = random.Random("%s:%d" % (n, v))
            atlas.paste(ground_tile(n, v, rng).im, (v * T, row * T))
    row = len(names)
    for n in ("road", "water"):
        meta["masked"][n] = row
        for m in range(16):
            rng = random.Random(m * 31 + (7 if n == "road" else 11))
            atlas.paste(masked_tile(n, m, rng).im, ((m % 8) * T, (row + m // 8) * T))
        row += 2
    meta["solid"].append("water")
    return atlas, meta


# ---------------------------------------------------------------------------
# Objetos
# ---------------------------------------------------------------------------

def outlined(c):
    c.outline(OUTLINE)
    return c


def tree_round(leaf="4f9a3e", leaf_dk="3b7a30", leaf_lt="7ac25a", trunk="7a5234", fruit=None):
    c = Canvas(20, 27)
    L, LD, LL, TR = hexc(leaf), hexc(leaf_dk), hexc(leaf_lt), hexc(trunk)
    c.rect(8, 16, 4, 9, TR)
    c.vline(8, 16, 24, dark(TR))
    c.set(7, 24, TR)
    c.set(12, 24, TR)
    c.ellipse(10, 10, 8.6, 7.8, LD)
    c.ellipse(9.4, 8.8, 7.6, 6.6, L)
    c.ellipse(7.2, 6.4, 3.6, 2.8, LL)
    for (x, y) in ((13, 5), (15, 10), (5, 12), (11, 13)):
        c.set(x, y, LD)
    c.set(6, 5, light(LL, 0.4))
    if fruit:
        for (x, y) in ((12, 8), (6, 11), (14, 13)):
            c.set(x, y, hexc(fruit))
    return outlined(c)


def tree_pine(leaf="3f6e58", leaf_dk="2f5646", leaf_lt="5a8f74", snow=False):
    c = Canvas(15, 27)
    L, LD, LL = hexc(leaf), hexc(leaf_dk), hexc(leaf_lt)
    c.rect(6, 21, 3, 5, hexc("6a4a32"))
    for i, (y, w) in enumerate(((2, 3), (5, 5), (8, 7), (11, 9), (14, 11), (17, 13))):
        x0 = 7 - w // 2
        c.hline(x0, x0 + w - 1, y, LL if i < 2 else L)
        c.hline(x0, x0 + w - 1, y + 1, L)
        c.hline(x0 + 1, x0 + w - 2, y + 2, LD)
        if snow:
            c.hline(x0 + 1, x0 + w - 2, y, hexc("f4f8ff"))
    c.set(7, 1, LL)
    return outlined(c)


def tree_dead(wood="6a5a58", wood_dk="4a3e3e"):
    c = Canvas(17, 23)
    W, WD = hexc(wood), hexc(wood_dk)
    c.rect(7, 9, 3, 13, W)
    c.vline(7, 9, 21, WD)
    c.line(8, 12, 3, 6, W)
    c.line(8, 11, 2, 7, W)
    c.line(9, 10, 14, 4, W)
    c.line(9, 9, 13, 3, W)
    c.line(4, 7, 3, 3, W)
    c.line(13, 5, 15, 2, W)
    c.line(8, 9, 8, 2, W)
    c.set(6, 21, W)
    c.set(10, 21, W)
    return outlined(c)


def tree_palm():
    c = Canvas(19, 25)
    TR, L, LD = hexc("a07a4a"), hexc("5aa04a"), hexc("3f7a38")
    for i in range(12):
        c.set(9 + (1 if i < 4 else 0), 12 + i, TR if i % 2 else dark(TR))
        c.set(10 + (1 if i < 4 else 0), 12 + i, TR)
    for dx, dy in ((-8, 3), (8, 3), (-6, -4), (6, -4), (0, -6)):
        c.line(10, 8, 10 + dx, 8 + dy, L)
        c.line(10, 9, 10 + dx, 9 + dy, LD)
    c.ellipse(10, 9, 2.2, 1.6, hexc("7a5a2a"))
    return outlined(c)


def tree_crystal():
    c = Canvas(13, 21)
    C1, C2, C3 = hexc("9a6ad8"), hexc("c8a0ff"), hexc("6a44a8")
    c.rect(5, 12, 3, 8, hexc("5a4a6a"))
    for (x, y, h) in ((6, 2, 11), (2, 6, 7), (10, 5, 7)):
        c.vline(x, y, y + h, C1)
        c.vline(x + 1, y + 1, y + h, C3)
        c.set(x, y - 1, C2)
        c.vline(x - 1, y + 1, y + h - 2, C2)
    return outlined(c)


def mushroom_big(cap="c0504a", dots="f4e8d8"):
    c = Canvas(15, 15)
    c.rect(5, 7, 5, 7, hexc("e8dcc8"))
    c.vline(5, 7, 13, hexc("c8b8a0"))
    c.ellipse(7.5, 5.5, 7.0, 4.6, dark(hexc(cap)))
    c.ellipse(7.2, 5.0, 6.4, 3.8, hexc(cap))
    for (x, y) in ((4, 4), (9, 3), (11, 6), (6, 7)):
        c.set(x, y, hexc(dots))
    return outlined(c)


def stalagmite():
    c = Canvas(9, 15)
    R, RD, RL = hexc("6e6878"), hexc("4e4a58"), hexc("8e889a")
    for i in range(13):
        w = 1 + i // 3
        c.hline(4 - w // 2, 4 + (w - 1) // 2, 1 + i, R)
        c.set(4 - w // 2, 1 + i, RL)
        c.set(4 + (w - 1) // 2, 1 + i, RD)
    return outlined(c)


def cactus():
    c = Canvas(11, 15)
    G, GD, GL = hexc("5a9a4a"), hexc("3f7a38"), hexc("7aba62")
    c.rect(4, 1, 3, 13, G)
    c.vline(4, 1, 13, GL)
    c.rect(1, 5, 2, 4, G)
    c.hline(1, 3, 8, G)
    c.rect(8, 3, 2, 5, G)
    c.hline(7, 9, 7, G)
    c.vline(6, 2, 13, GD)
    c.set(5, 0, hexc("f0a0c0"))
    return outlined(c)


def bush(leaf="5a9a4a", berry=None):
    c = Canvas(13, 10)
    L, LD, LL = hexc(leaf), dark(hexc(leaf), 0.78), light(hexc(leaf), 0.25)
    c.ellipse(6.5, 5.5, 6.0, 4.0, LD)
    c.ellipse(6.0, 4.8, 5.2, 3.2, L)
    c.ellipse(4.5, 3.6, 2.2, 1.4, LL)
    if berry:
        for (x, y) in ((8, 4), (4, 6), (10, 6)):
            c.set(x, y, hexc(berry))
    return outlined(c)


def rock(big=True, col="8e889a"):
    w, h = (15, 11) if big else (9, 7)
    c = Canvas(w, h)
    R = hexc(col)
    c.ellipse(w / 2, h / 2 + 0.5, w / 2 - 0.5, h / 2 - 0.5, dark(R, 0.72))
    c.ellipse(w / 2 - 0.4, h / 2, w / 2 - 1.3, h / 2 - 1.2, R)
    c.set(int(w / 2) - 2, 2, light(R, 0.4))
    c.set(int(w / 2) - 1, 2, light(R, 0.25))
    return outlined(c)


def gravestone(cross=False):
    c = Canvas(8, 11)
    S, SD, SL = hexc("9a98aa"), hexc("6e6c80"), hexc("bcbacc")
    if cross:
        c.rect(3, 1, 2, 9, S)
        c.rect(1, 3, 6, 2, S)
        c.set(3, 1, SL)
    else:
        c.rect(1, 2, 6, 8, S)
        c.hline(2, 5, 1, S)
        c.vline(6, 2, 9, SD)
        c.hline(2, 4, 4, SD)
        c.hline(2, 4, 6, SD)
        c.set(2, 2, SL)
    c.hline(0, 7, 10, hexc("4f6b4a"))
    return outlined(c)


def column(broken=True, col="c8c0a8"):
    c = Canvas(9, 17)
    S, SD, SL = hexc(col), dark(hexc(col), 0.78), light(hexc(col), 0.3)
    top = 5 if broken else 1
    c.rect(1, 14, 7, 2, S)
    c.rect(2, top, 5, 14 - top, S)
    c.vline(2, top, 13, SL)
    c.vline(6, top, 13, SD)
    c.vline(4, top + 1, 13, SD)
    if broken:
        c.set(2, top - 1, S)
        c.set(3, top - 2, S)
        c.set(5, top - 1, S)
    else:
        c.rect(1, 0, 7, 2, S)
    return outlined(c)


def palisade():
    c = Canvas(9, 15)
    W, WD = hexc("8a5a36"), hexc("6a4226")
    for x in (1, 4, 7):
        c.vline(x, 3, 14, W)
        c.set(x, 2, light(W, 0.3))
        c.vline(x + 1 if x < 7 else x, 4, 14, WD)
    c.hline(0, 8, 8, WD)
    return outlined(c)


def tent(col="b8864a"):
    c = Canvas(23, 17)
    Cl, D, L = hexc(col), dark(hexc(col), 0.72), light(hexc(col), 0.25)
    for i in range(13):
        w = 3 + i * 3 // 2
        c.hline(11 - w // 2, 11 + w // 2, 2 + i, Cl)
        c.set(11 - w // 2, 2 + i, L)
    c.line(11, 2, 11, 15, D)
    c.rect(9, 9, 5, 6, hexc("2a2030"))
    c.vline(11, 0, 2, hexc("6a4a32"))
    c.set(12, 0, hexc("d04a3a"))
    return outlined(c)


def reeds():
    c = Canvas(9, 10)
    G, B = hexc("6a8a4a"), hexc("7a5a3a")
    for x, h in ((1, 7), (3, 9), (5, 6), (7, 8)):
        c.vline(x, 10 - h, 9, G)
    c.vline(3, 1, 2, B)
    c.vline(7, 2, 3, B)
    return c


def flowers(col="f2a0c0"):
    c = Canvas(9, 7)
    for (x, y) in ((1, 3), (4, 1), (6, 4), (3, 5)):
        c.set(x, y, hexc(col))
        c.set(x + 1, y, light(hexc(col), 0.4))
        c.set(x, y + 1, hexc("4f8a3e"))
    return c


def cloud_puff():
    c = Canvas(17, 9)
    W, S = hexc("ffffff"), hexc("d8e4fa")
    c.ellipse(5, 5, 4.4, 3.2, S)
    c.ellipse(10, 4.5, 5.4, 3.8, S)
    c.ellipse(5, 4.4, 3.8, 2.6, W)
    c.ellipse(10, 3.8, 4.8, 3.0, W)
    return c


def lamp_post():
    c = Canvas(7, 17)
    M, L = hexc("3a3448"), hexc("ffe08a")
    c.vline(3, 4, 15, M)
    c.hline(2, 4, 16, M)
    c.rect(1, 1, 5, 4, M)
    c.rect(2, 2, 3, 2, L)
    c.set(3, 0, M)
    return outlined(c)


def well():
    c = Canvas(15, 17)
    S, SD, R, W = hexc("9a98aa"), hexc("6e6c80"), hexc("a04a3a"), hexc("7a5234")
    c.rect(1, 9, 13, 7, S)
    c.hline(1, 13, 9, light(S, 0.3))
    c.hline(2, 12, 11, SD)
    c.rect(3, 12, 9, 2, hexc("2f5f9a"))
    c.vline(2, 3, 9, W)
    c.vline(12, 3, 9, W)
    for i in range(5):
        c.hline(1 + i, 13 - i, 3 - (i + 1) // 2, R)
    c.hline(0, 14, 3, dark(R))
    return outlined(c)


def house(style):
    """Casinha 3/4: telhado grande em cima, parede com porta e janela."""
    pal = {
        "wood": ("c46a4a", "a0503a", "e08a64", "d8b88a", "a88a64", "6a4a32"),
        "stone": ("5a6a9a", "465580", "7a8ab8", "b8b4a8", "908c80", "5a4a3a"),
        "sand": ("d8a060", "b88048", "f0c080", "e8d0a0", "c8aa7a", "7a5a3a"),
        "dark": ("6a4a7a", "553a62", "8a6a9a", "8a8698", "6a6678", "3a2e3a"),
    }[style]
    roof, roof_dk, roof_lt, wall, wall_dk, door = [hexc(x) for x in pal]
    c = Canvas(33, 31)
    # parede
    c.rect(4, 15, 25, 14, wall)
    c.hline(4, 28, 28, wall_dk)
    c.vline(28, 15, 28, wall_dk)
    # porta e janela
    c.rect(14, 20, 5, 9, door)
    c.set(17, 24, hexc("e8c060"))
    c.rect(7, 19, 4, 4, hexc("ffe8a0"))
    c.rect(22, 19, 4, 4, hexc("ffe8a0"))
    c.hline(7, 10, 21, wall_dk)
    c.hline(22, 25, 21, wall_dk)
    c.vline(8, 19, 22, wall_dk)
    c.vline(23, 19, 22, wall_dk)
    # telhado (trapézio) com telhas
    for i in range(14):
        x0 = 1 + max(0, 6 - i)
        x1 = 31 - max(0, 6 - i)
        c.hline(x0, x1, 2 + i, roof)
        if i % 3 == 2:
            c.hline(x0, x1, 2 + i, roof_dk)
    c.hline(7, 25, 2, roof_lt)
    c.hline(1, 31, 15, dark(roof_dk, 0.85))
    # chaminé
    c.rect(24, 0, 3, 4, wall_dk)
    return outlined(c)


def signpost():
    c = Canvas(11, 12)
    W, WD = hexc("a07a4a"), hexc("7a5a32")
    c.vline(5, 3, 11, WD)
    c.rect(1, 1, 9, 4, W)
    c.hline(2, 8, 2, hexc("5a3a24"))
    c.hline(1, 9, 4, WD)
    return outlined(c)


def entrance_gate():
    c = Canvas(29, 29)
    S, SD, SL = hexc("8a8698"), hexc("5e5a6e"), hexc("aca8ba")
    c.rect(2, 6, 25, 22, S)
    c.hline(2, 26, 6, SL)
    # blocos
    for y in range(8, 28, 4):
        c.hline(2, 26, y, SD)
        off = 0 if (y // 4) % 2 else 3
        for x in range(2 + off, 27, 6):
            c.vline(x, y - 3, y - 1, SD)
    # arco escuro
    c.ellipse(14.5, 17, 7.0, 7.0, hexc("120c1a"))
    c.rect(8, 17, 13, 11, hexc("120c1a"))
    c.ellipse(14.5, 17, 5.6, 5.6, hexc("1f1630"))
    # ameias
    for x in range(2, 27, 4):
        c.rect(x, 3, 2, 3, S)
    # tochas (o fogo é desenhado no jogo)
    c.rect(3, 12, 2, 4, hexc("6a4a32"))
    c.rect(24, 12, 2, 4, hexc("6a4a32"))
    return outlined(c)


def entrance_cave():
    c = Canvas(31, 23)
    R, RD, RL = hexc("7a7488"), hexc("56526a"), hexc("9a96aa")
    c.ellipse(15.5, 13, 15, 10, RD)
    c.ellipse(15, 12, 14, 9.2, R)
    c.ellipse(10, 7, 5, 3, RL)
    c.ellipse(22, 9, 4, 2.5, RL)
    c.ellipse(15.5, 17, 7.2, 6.2, hexc("120c1a"))
    c.rect(8, 17, 16, 6, hexc("120c1a"))
    c.ellipse(15.5, 18, 5.4, 4.6, hexc("1f1630"))
    # vigas de madeira da mina
    W = hexc("8a5a36")
    c.vline(7, 12, 22, W)
    c.vline(24, 12, 22, W)
    c.hline(7, 24, 11, W)
    return outlined(c)


def entrance_sky():
    c = Canvas(25, 15)
    S, SD, G = hexc("e8e4f4"), hexc("b8b4d4"), hexc("f0d27a")
    c.ellipse(12.5, 8, 11.8, 6.4, SD)
    c.ellipse(12.5, 7, 11.2, 5.6, S)
    c.ellipse(12.5, 7, 7.0, 3.4, G)
    c.ellipse(12.5, 7, 5.6, 2.4, light(G, 0.5))
    for x in (2, 22):
        c.rect(x, 2, 2, 6, S)
        c.set(x, 1, G)
    return outlined(c)


def entrance_rift_base():
    c = Canvas(21, 9)
    S, SD = hexc("6a5a8a"), hexc("4a3e66")
    c.ellipse(10.5, 5, 10, 3.6, SD)
    c.ellipse(10.5, 4.4, 9.2, 2.8, S)
    c.ellipse(10.5, 4.4, 6, 1.6, hexc("2a1a4a"))
    return outlined(c)


def hearth():
    """A Grande Lareira: braseiro de pedra enorme na praça da vila inicial."""
    c = Canvas(41, 29)
    S, SD, SL = hexc("9a8e86"), hexc("6e645e"), hexc("bcb0a6")
    c.ellipse(20.5, 20, 19.5, 8.5, SD)
    c.ellipse(20.5, 18.8, 18.6, 7.6, S)
    c.ellipse(20.5, 18.5, 14.5, 5.2, SD)
    c.ellipse(20.5, 18.2, 13.6, 4.4, hexc("2a2226"))
    # brasas apagadas / cinzas
    for (x, y) in ((14, 18), (18, 19), (23, 17), (26, 19), (20, 20), (16, 16)):
        c.set(x, y, hexc("5a4a46"))
        c.set(x + 1, y, hexc("463a38"))
    # pilares com runas
    for x in (4, 34):
        c.rect(x, 4, 4, 15, S)
        c.vline(x, 4, 18, SL)
        c.vline(x + 3, 4, 18, SD)
        c.rect(x - 1, 2, 6, 3, SL)
        c.set(x + 1, 9, hexc("e8a040"))
        c.set(x + 2, 12, hexc("e8a040"))
    for x in range(6, 36, 4):
        c.set(x, 25, SL)
    return outlined(c)


def waystone():
    c = Canvas(11, 17)
    S, SD, SL = hexc("7a8aa0"), hexc("56647a"), hexc("9aaac0")
    c.rect(2, 3, 7, 12, S)
    c.hline(3, 7, 2, S)
    c.vline(2, 3, 14, SL)
    c.vline(8, 3, 14, SD)
    c.rect(0, 14, 11, 2, SD)
    for (x, y) in ((5, 5), (4, 7), (6, 7), (5, 9), (5, 11)):
        c.set(x, y, hexc("3a4a6a"))
    return outlined(c)


def gate_barrier():
    c = Canvas(25, 17)
    S, SD, SL = hexc("6e6878"), hexc("4e4a58"), hexc("8e889a")
    c.rect(1, 3, 23, 13, S)
    c.hline(1, 23, 3, SL)
    for y in (7, 11):
        c.hline(1, 23, y, SD)
    for x in (6, 12, 18):
        c.vline(x, 4, 6, SD)
        c.vline(x - 3, 8, 10, SD)
        c.vline(x + 3, 12, 15, SD)
    c.rect(9, 5, 7, 7, hexc("2a2436"))
    return outlined(c)


def banner(col="c03a3a", mark="skull"):
    c = Canvas(9, 15)
    C = hexc(col)
    c.vline(1, 0, 14, hexc("6a4a32"))
    c.rect(2, 1, 6, 7, C)
    c.set(2, 8, C)
    c.set(4, 8, C)
    c.set(6, 8, C)
    W = hexc("f4efe6")
    if mark == "skull":
        c.rect(4, 2, 3, 3, W)
        c.set(4, 5, W)
        c.set(6, 5, W)
        c.set(4, 3, hexc("1b1528"))
        c.set(6, 3, hexc("1b1528"))
    else:
        c.set(5, 2, W)
        c.hline(4, 6, 3, W)
        c.set(5, 4, W)
        c.set(4, 5, W)
        c.set(6, 5, W)
    return outlined(c)


def fence_h():
    c = Canvas(9, 8)
    W, WD = hexc("a07a4a"), hexc("7a5a32")
    c.vline(1, 1, 7, W)
    c.vline(7, 1, 7, W)
    c.hline(0, 8, 3, W)
    c.hline(0, 8, 5, WD)
    return outlined(c)


# nome: (função, pés (x, y) no sprite, colisão [x, y, w, h] relativa aos pés, extra)
OBJECTS = {
    "tree_oak": (lambda: tree_round(), (10, 25), [-3, -3, 6, 3]),
    "tree_oak_fruit": (lambda: tree_round(fruit="e04a4a"), (10, 25), [-3, -3, 6, 3]),
    "tree_oak_autumn": (lambda: tree_round("d08a3a", "a86a2a", "f0b060"), (10, 25), [-3, -3, 6, 3]),
    "tree_dark": (lambda: tree_round("3f5a4a", "2f463a", "56766a", "5a4238"), (10, 25), [-3, -3, 6, 3]),
    "tree_swamp": (lambda: tree_round("5a6a3a", "46552c", "74864e", "5a4a38"), (10, 25), [-3, -3, 6, 3]),
    "tree_pine": (lambda: tree_pine(), (7, 25), [-2, -3, 5, 3]),
    "tree_pine_snow": (lambda: tree_pine(snow=True), (7, 25), [-2, -3, 5, 3]),
    "tree_dead": (lambda: tree_dead(), (8, 21), [-2, -2, 5, 2]),
    "tree_palm": (lambda: tree_palm(), (10, 23), [-2, -2, 5, 2]),
    "tree_crystal": (lambda: tree_crystal(), (6, 19), [-2, -2, 5, 2]),
    "tree_gold": (lambda: tree_round("e0b040", "b88a2a", "f8d878", "8a6a4a"), (10, 25), [-3, -3, 6, 3]),
    "mushroom_red": (lambda: mushroom_big(), (7, 13), [-3, -3, 6, 3]),
    "mushroom_blue": (lambda: mushroom_big("4a7ac0", "d8f0ff"), (7, 13), [-3, -3, 6, 3]),
    "stalagmite": (lambda: stalagmite(), (4, 14), [-2, -2, 5, 2]),
    "cactus": (lambda: cactus(), (5, 14), [-2, -2, 5, 2]),
    "bush": (lambda: bush(), (6, 9), [-5, -3, 11, 3]),
    "bush_berry": (lambda: bush(berry="c04a8a"), (6, 9), [-5, -3, 11, 3]),
    "bush_dry": (lambda: bush("9a8a4a"), (6, 9), [-5, -3, 11, 3]),
    "rock_big": (lambda: rock(True), (7, 10), [-6, -4, 13, 4]),
    "rock_small": (lambda: rock(False), (4, 6), [-3, -2, 7, 2]),
    "rock_sand": (lambda: rock(True, "c8a070"), (7, 10), [-6, -4, 13, 4]),
    "rock_snow": (lambda: rock(True, "b8c4d4"), (7, 10), [-6, -4, 13, 4]),
    "gravestone": (lambda: gravestone(), (4, 10), [-3, -2, 7, 2]),
    "grave_cross": (lambda: gravestone(True), (4, 10), [-3, -2, 7, 2]),
    "column_broken": (lambda: column(True), (4, 16), [-3, -2, 7, 2]),
    "column_gold": (lambda: column(False, "e8c46a"), (4, 16), [-3, -2, 7, 2]),
    "column_ruin": (lambda: column(True, "a4a48e"), (4, 16), [-3, -2, 7, 2]),
    "palisade": (lambda: palisade(), (4, 14), [-4, -2, 9, 2]),
    "tent": (lambda: tent(), (11, 16), [-9, -6, 19, 6]),
    "tent_red": (lambda: tent("b8504a"), (11, 16), [-9, -6, 19, 6]),
    "reeds": (lambda: reeds(), (4, 9), None),
    "flowers_pink": (lambda: flowers(), (4, 6), None),
    "flowers_yellow": (lambda: flowers("f4d04a"), (4, 6), None),
    "flowers_blue": (lambda: flowers("7ab0f0"), (4, 6), None),
    "cloud_puff": (lambda: cloud_puff(), (8, 8), None),
    "lamp_post": (lambda: lamp_post(), (3, 16), [-1, -2, 3, 2]),
    "well": (lambda: well(), (7, 16), [-6, -5, 13, 5]),
    "house_wood": (lambda: house("wood"), (16, 29), [-12, -12, 25, 12]),
    "house_stone": (lambda: house("stone"), (16, 29), [-12, -12, 25, 12]),
    "house_sand": (lambda: house("sand"), (16, 29), [-12, -12, 25, 12]),
    "house_dark": (lambda: house("dark"), (16, 29), [-12, -12, 25, 12]),
    "signpost": (lambda: signpost(), (5, 11), [-1, -2, 3, 2]),
    "entrance_gate": (lambda: entrance_gate(), (14, 28), [-12, -10, 25, 7]),
    "entrance_cave": (lambda: entrance_cave(), (15, 22), [-14, -10, 29, 7]),
    "entrance_sky": (lambda: entrance_sky(), (12, 13), None),
    "entrance_rift": (lambda: entrance_rift_base(), (10, 7), None),
    "hearth": (lambda: hearth(), (20, 27), [-18, -12, 37, 10]),
    "waystone": (lambda: waystone(), (5, 16), [-4, -3, 9, 3]),
    "gate_barrier": (lambda: gate_barrier(), (12, 16), None),
    "banner_boss": (lambda: banner(), (1, 14), None),
    "banner_clear": (lambda: banner("4aa05a", "star"), (1, 14), None),
    "fence_h": (lambda: fence_h(), (4, 7), [-4, -2, 9, 2]),
}


def build_objects():
    sprites = []
    for name, spec in OBJECTS.items():
        fn, feet, col = spec
        sprites.append((name, fn(), feet, col))
    # empacotamento em prateleiras (largura 256)
    W = 256
    x = y = shelf = 0
    rects = {}
    for name, c, feet, col in sorted(sprites, key=lambda s: -s[1].h):
        if x + c.w > W:
            x = 0
            y += shelf + 1
            shelf = 0
        rects[name] = (x, y, c, feet, col)
        x += c.w + 1
        shelf = max(shelf, c.h)
    H = y + shelf
    atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    meta = {}
    for name, (rx, ry, c, feet, col) in rects.items():
        atlas.paste(c.im, (rx, ry))
        meta[name] = {"rect": [rx, ry, c.w, c.h], "feet": list(feet), "collision": col}
    return atlas, meta


def main():
    os.makedirs(OUT, exist_ok=True)
    g, gm = build_ground()
    g.save(os.path.join(OUT, "ground.png"))
    with open(os.path.join(OUT, "ground.json"), "w") as f:
        json.dump(gm, f, indent=1)
    o, om = build_objects()
    o.save(os.path.join(OUT, "objects.png"))
    with open(os.path.join(OUT, "objects.json"), "w") as f:
        json.dump(om, f, indent=1)
    if "--preview" in sys.argv:
        pd = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(pd, exist_ok=True)
        preview(g, 6).save(os.path.join(pd, "ow_ground.png"))
        preview(o, 4).save(os.path.join(pd, "ow_objects.png"))
    print("mapa-múndi: arte gerada em", OUT)


if __name__ == "__main__":
    main()
