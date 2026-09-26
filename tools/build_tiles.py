#!/usr/bin/env python3
"""Gera atlas de tiles 8x8 limpos e minimalistas (paleta chapada por bioma).
Mesmo layout de papéis do TileSetBuilder (8 colunas x 4 linhas):
  linha 0: TOPO 0-3 | TOPO_E | TOPO_D | TOPO_ÚNICO | QUEBRÁVEL
  linha 1: SUB 0-3  | PLAT_E | PLAT_M | PLAT_D | ESPINHOS
  linha 2: FILL 0-3 | BORDA_E | BORDA_D | TETO | PONTO
  linha 3: DECO 0-3 | FUNDO 0-3
Uso: python3 tools/build_tiles.py
"""
import os
from PIL import Image

T = 8
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "tilesets")

PALETTES = {
    # top_hi, top, body, body_dark, fill, outline, bg, bg_line, deco
    "cemetery": ["#a8d86e", "#6aa84f", "#6b5a4e", "#584a41", "#2f2826", "#1b1620", "#5a5560", "#625d69", "#8cc152"],
    "castle": ["#d6dde8", "#a3aec2", "#6f7a92", "#5e6880", "#2b3142", "#161824", "#4d556b", "#566078", "#8fb3a0"],
    "town": ["#f0c9a0", "#d9955f", "#a4583a", "#8e4a31", "#442822", "#1d1418", "#6a5154", "#74595c", "#7fa65a"],
    "temple": ["#fff1b8", "#e8c16e", "#c48e4c", "#ab7a3f", "#5a3f27", "#1f1510", "#7a624c", "#846b54", "#e8d890"],
}


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def tile():
    return Image.new("RGBA", (T, T), (0, 0, 0, 0))


def body(p, variant, dark_rows=False):
    im = tile()
    px = im.load()
    base = hexc(p[4] if dark_rows else p[2])
    alt = hexc(p[3] if not dark_rows else p[4])
    for y in range(T):
        for x in range(T):
            px[x, y] = base
    # padrão simples: juntas de tijolo/pedra
    if not dark_rows:
        for x in range(T):
            px[x, 3] = alt
            px[x, 7] = alt
        off = [1, 5, 3, 6][variant]
        px[off, 0] = px[off, 1] = px[off, 2] = alt
        px[(off + 4) % T, 4] = px[(off + 4) % T, 5] = px[(off + 4) % T, 6] = alt
    else:
        px[(1 + variant * 2) % T, (2 + variant) % T] = hexc(p[3])
    return im


def top(p, variant, left=False, right=False):
    im = body(p, variant)
    px = im.load()
    for x in range(T):
        px[x, 0] = hexc(p[0])
        px[x, 1] = hexc(p[1])
        px[x, 2] = hexc(p[1]) if (x + variant) % 3 else hexc(p[2])
    if left:
        for y in range(T):
            px[0, y] = hexc(p[5])
    if right:
        for y in range(T):
            px[T - 1, y] = hexc(p[5])
    return im


def edge(side, p):
    im = tile()
    px = im.load()
    for i in range(T):
        if side == "L":
            px[0, i] = hexc(p[5])
        elif side == "R":
            px[T - 1, i] = hexc(p[5])
        elif side == "B":
            px[i, T - 1] = hexc(p[5])
            if i % 3 == 1:
                px[i, T - 2] = hexc(p[3])
    if side == "DOT":
        im = tile()
        im.load()[0, 0] = hexc(p[5])
    return im


def plat(p, part):
    im = tile()
    px = im.load()
    for x in range(T):
        px[x, 0] = hexc(p[0])
        px[x, 1] = hexc(p[1])
        px[x, 2] = hexc(p[3])
    if part == "L":
        px[0, 1] = px[0, 2] = hexc(p[5])
    if part == "R":
        px[T - 1, 1] = px[T - 1, 2] = hexc(p[5])
    return im


def spikes(p):
    im = tile()
    px = im.load()
    light = (235, 235, 245, 255)
    dark = (150, 150, 170, 255)
    rows = [".#..", ".##.", "###.", "####"]
    for x0 in (0, 4):
        for yi, row in enumerate(rows):
            for xi, ch in enumerate(row):
                if ch == "#":
                    px[x0 + xi, 4 + yi] = light if xi < 2 else dark
    return im


def deco(p, variant):
    im = tile()
    px = im.load()
    c = hexc(p[8])
    if variant in (0, 1):
        for x in [1 + variant, 4, 6 - variant]:
            px[x, 7] = c
            px[x, 6] = c
        px[4, 5] = c
    elif variant == 2:
        px[3, 7] = px[3, 6] = c
        px[3, 5] = (240, 220, 120, 255)
    else:
        px[5, 7] = px[5, 6] = c
        px[5, 5] = (220, 120, 160, 255)
    return im


def bg(p, variant):
    im = tile()
    px = im.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = hexc(p[6])
    line = hexc(p[7])
    for x in range(T):
        px[x, 7] = line
    px[[2, 6, 4, 0][variant], 3] = line
    px[[2, 6, 4, 0][variant], 4] = line
    return im


def build(name, p):
    atlas = Image.new("RGBA", (8 * T, 4 * T), (0, 0, 0, 0))
    put = lambda im, cx, cy: atlas.paste(im, (cx * T, cy * T))
    for i in range(4):
        put(top(p, i), i, 0)
        put(body(p, i), i, 1)
        put(body(p, i, True), i, 2)
        put(deco(p, i), i, 3)
        put(bg(p, i), 4 + i, 3)
    put(top(p, 0, left=True), 4, 0)
    put(top(p, 1, right=True), 5, 0)
    put(top(p, 2, left=True, right=True), 6, 0)
    br = body(p, 1)
    bpx = br.load()
    for (x, y) in [(2, 1), (3, 2), (3, 3), (4, 4), (5, 5), (2, 5), (1, 6)]:
        bpx[x, y] = hexc(p[5])
    put(br, 7, 0)
    put(plat(p, "L"), 4, 1)
    put(plat(p, "M"), 5, 1)
    put(plat(p, "R"), 6, 1)
    put(spikes(p), 7, 1)
    put(edge("L", p), 4, 2)
    put(edge("R", p), 5, 2)
    put(edge("B", p), 6, 2)
    put(edge("DOT", p), 7, 2)
    atlas.save(os.path.join(OUT, name + ".png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n, p in PALETTES.items():
        build(n, p)
    print("tiles 8x8 gerados")
