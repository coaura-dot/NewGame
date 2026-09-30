#!/usr/bin/env python3
"""Terreno em pixel art de 24 px por MATERIAL (um por tipo de lugar).

Três peças por material (assets/art/tilesets/):
  <nome>.png         atlas 192x264 (8 colunas x 11 linhas de 24 px):
      0..46   AUTOTILE "blob" de 47 formatos: bordas, quinas externas e
              internas, superfície (grama/musgo/areia/friso), teto, laterais;
      47..58  variações dos 4 formatos mais comuns (chão, teto, paredes);
      59      bloco rachado (quebrável)       61  parede de fundo (tudo miolo)
      linha 8:  plataforma E/M/D/única, espinhos
      linha 9:  franja da superfície x4 (fica no tile de CIMA), pendentes x4
                (raízes, cipós, estalactites... no tile de BAIXO do teto)
      linha 10: decorações x8 (pousadas sobre o chão)
    Os pixels MAGENTA (255, g, 255) são "miolo": o shader do terreno
    (shaders/terrain.gdshader) troca pela textura grande do material,
    amostrada na posição do MUNDO (sem repetição a cada tile). g codifica o
    brilho: g=50 normal, menor = sombra, maior = luz (chanfro nas bordas).
  <nome>_fill.png    textura grande (192x192, contínua nas bordas) do miolo
  <nome>_fill_n.png  mapa de normais do miolo (a luz das tochas e da chama da
                     Faísca "reflete" no relevo das pedras)
  <nome>_n.png       normais do atlas (chanfro das bordas)
  <nome>_bg.png      textura da parede do fundo (e _bg_n.png)
Uso: python3 tools/build_tiles.py [material ...]
"""
import math
import os
import sys
import zlib

import numpy as np
from PIL import Image

# Tile de 24 px = 8 unidades do mundo na densidade 3 (LevelConst.ART = 3).
# K = escala em relação ao desenho original de 16 px: tamanhos de formas
# (tijolos, pedras, raízes, espinhos...) crescem K vezes; detalhes de 1 px
# (contornos, juntas) continuam com 1 px => mais resolução, mesmo desenho.
T = 24
K = T / 16.0
FILL = int(128 * K)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "tilesets")
MARK_G_NORMAL = 50  # g do magenta = brilho 1.0


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], dtype=np.float64)


def mixc(a, b, t):
    return a + (b - a) * t


# ===========================================================================
# Blob autotile (47): máscara de 8 vizinhos -> índice
# bits: N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128 (1 = vizinho SÓLIDO)
# ===========================================================================

def canon(mask):
    n, e, s, w = mask & 1, mask & 4, mask & 16, mask & 64
    m = mask
    if not (n and e):
        m &= ~2
    if not (s and e):
        m &= ~8
    if not (s and w):
        m &= ~32
    if not (n and w):
        m &= ~128
    return m


BLOB = sorted({canon(m) for m in range(256)})
assert len(BLOB) == 47
BLOB_INDEX = {m: i for i, m in enumerate(BLOB)}
# formatos comuns com variações (índice base -> índices extras)
M_TOP = canon(255 & ~1 & ~2 & ~128)      # só o de cima vazio
M_BOTTOM = canon(255 & ~16 & ~8 & ~32)   # só o de baixo vazio
M_LEFT = canon(255 & ~64 & ~32 & ~128)   # só o da esquerda vazio
M_RIGHT = canon(255 & ~4 & ~2 & ~8)      # só o da direita vazio
VARIANTS = {M_TOP: [47, 48, 49], M_BOTTOM: [50, 51, 52], M_LEFT: [53, 54, 55], M_RIGHT: [56, 57, 58]}
IDX_BREAK = 59
IDX_BG = 61


# ===========================================================================
# Ruído e utilidades (tudo contínuo nas bordas: toroidal)
# ===========================================================================

def rng_for(name, salt=0):
    # hash estável (o hash() do Python muda a cada execução)
    return np.random.default_rng(zlib.crc32(f"{name}:{salt}".encode()))


def value_noise(size, cells, rng):
    """Ruído suave toroidal (interpolação cúbica de uma grade aleatória)."""
    g = rng.random((cells, cells))
    x = np.arange(size) * cells / size
    xi = np.floor(x).astype(int)
    xf = x - xi
    xf = xf * xf * (3 - 2 * xf)
    a = g[np.ix_(xi % cells, xi % cells)]
    b = g[np.ix_(xi % cells, (xi + 1) % cells)]
    c = g[np.ix_((xi + 1) % cells, xi % cells)]
    d = g[np.ix_((xi + 1) % cells, (xi + 1) % cells)]
    fy = xf[:, None]
    fx = xf[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, rng, octaves=((4, 1.0), (8, 0.5), (16, 0.25), (32, 0.12))):
    out = np.zeros((size, size))
    tot = 0.0
    for cells, amp in octaves:
        out += value_noise(size, cells, rng) * amp
        tot += amp
    return out / tot


def voronoi(size, pts):
    """Distâncias toroidais: (d1, d2, índice da célula mais próxima)."""
    yy, xx = np.mgrid[0:size, 0:size] + 0.5
    d1 = np.full((size, size), 1e9)
    d2 = np.full((size, size), 1e9)
    idx = np.zeros((size, size), dtype=int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, size - dx)
        dy = np.minimum(dy, size - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    return d1, d2, idx


def normals_from_height(h, strength=2.0):
    """Normais (OpenGL, Y para cima) de um mapa de altura toroidal."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = dy * strength  # y da imagem cresce para baixo; normal Y+ = para cima
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def shade(ramp, v):
    """Escolhe um tom da rampa (lista de cores) para v em 0..1 (faixas)."""
    r = np.array(ramp)
    i = np.clip((v * len(ramp)).astype(int), 0, len(ramp) - 1)
    return r[i]


def ramp_from(base, dark, light, n=6):
    """Rampa com desvio de matiz: base no meio, dark embaixo, light em cima."""
    out = []
    for k in range(n):
        t = k / (n - 1)
        if t < 0.5:
            out.append(mixc(dark * 0.72, base, t / 0.5))
        else:
            out.append(mixc(base, light, (t - 0.5) / 0.5))
    return out


# ===========================================================================
# Texturas de MIOLO (128x128): altura + cor
# ===========================================================================

def light_term(h, strength=2.2):
    """Iluminação embutida suave (luz de cima-esquerda) a partir da altura."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    return np.clip(0.5 + (-dx * 0.6 - dy * 0.9) * strength, 0.0, 1.0)


def fill_blocks(P, rng, rows_h=(12, 14), widths=(18, 34), mortar=1, chip=0.25, cracks=0.3, moss=0.0, bone=0.0, runes=0.0, marble=False):
    """Blocos de pedra em fiadas desencontradas, com chanfro, lascas,
    rachaduras e (opcional) musgo, ossos, runas ou veios de mármore."""
    S = FILL
    rows_h = (int(round(rows_h[0] * K)), int(round(rows_h[1] * K)))
    widths = (int(round(widths[0] * K)), int(round(widths[1] * K)))
    h = np.zeros((S, S))
    tone = np.zeros((S, S))
    edge = np.zeros((S, S))
    y = 0
    heights = []
    while y < S:
        hh = int(rng.integers(rows_h[0], rows_h[1] + 1))
        if y + hh > S - rows_h[0]:
            hh = S - y
        heights.append((y, hh))
        y += hh
    noise = fbm(S, rng)
    fine = fbm(S, rng, ((16, 1.0), (32, 0.7), (64, 0.5)))
    for (y0, hh) in heights:
        x = int(rng.integers(0, S))
        start = x
        while True:
            w = int(rng.integers(widths[0], widths[1] + 1))
            if (x - start) + w > S - widths[0]:
                w = S - (x - start)
            t = rng.random() * 0.5 - 0.25
            for yy in range(y0, y0 + hh):
                for xx in range(x, x + w):
                    px = xx % S
                    dy = min(yy - y0, y0 + hh - 1 - yy)
                    dx = min(xx - x, x + w - 1 - xx)
                    d = min(dx, dy)
                    tone[yy, px] = t
                    edge[yy, px] = d
                    b = 1.0 - max(0.0, 2.2 * K - d) / (2.2 * K)
                    h[yy, px] = 0.55 + 0.45 * b
            x += w
            if x - start >= S:
                break
    # juntas
    mort = edge < mortar
    h[mort] = 0.12
    # lascas nas bordas dos blocos
    chips = (edge < 2.5 * K) & (fine > 1.0 - chip * 0.55)
    h[chips] -= 0.3
    # rachaduras (linhas finas escuras)
    if cracks > 0:
        crack = np.abs(noise - 0.5) < 0.012 * cracks * 2 + 0.004
        h[crack & ~mort] -= 0.35
    h += (fine - 0.5) * 0.18
    base, dark, light = hexc(P["base"]), hexc(P["dark"]), hexc(P["light"])
    rampc = ramp_from(base, dark, light)
    lit = light_term(h)
    v = np.clip(lit * 0.75 + h * 0.35 + tone * 0.35 - 0.12, 0, 1)
    col = shade(rampc, v)
    col[mort] = hexc(P["line"]) * 0.9 + dark * 0.1
    if marble:
        vein = np.abs(np.sin((noise * 9.0 + fine * 2.0) * math.pi)) < 0.06
        col[vein & ~mort] = mixc(col[vein & ~mort], hexc(P["dark"]), 0.5)
    if moss > 0:
        mm = (noise > 1.0 - moss) & (fine > 0.35)
        mramp = ramp_from(hexc(P["top"]), hexc(P["top_d"]), hexc(P["top"]) * 1.15, 4)
        col[mm] = shade(mramp, np.clip(lit[mm] * 0.8 + fine[mm] * 0.3, 0, 1))
        h[mm] += 0.1
    if bone > 0:
        _embed_bones(col, h, rng, bone, P)
    if runes > 0:
        _runes(col, h, rng, P, heights)
    return col, h


def _embed_bones(col, h, rng, amount, P):
    S = FILL
    bonec = [hexc("#e8dcc0"), hexc("#c8b898"), hexc("#9a8a6e"), hexc("#5e5242")]
    n = int(10 * amount)
    for _ in range(n):
        cx, cy = rng.integers(0, S, 2)
        if rng.random() < 0.4:
            # crânio: círculo + olhos
            r = int(round(4 * K))
            for yy in range(-r, r + 2):
                for xx in range(-r, r + 1):
                    if xx * xx + yy * yy <= r * r or (yy > 1 and abs(xx) <= 2):
                        px, py = (cx + xx) % S, (cy + yy) % S
                        k = 0 if yy < -1 and xx < 1 else (1 if yy < 2 else 2)
                        col[py, px] = bonec[k]
                        h[py, px] = 0.9 - k * 0.1
            for ex in (-2, 1):
                for yy in (0, 1):
                    col[(cy + yy) % S, (cx + ex) % S] = bonec[3]
                    col[(cy + yy) % S, (cx + ex + 1) % S] = bonec[3]
        else:
            ang = rng.random() * math.pi
            ln = int(rng.integers(6, 11) * K)
            for i in range(-ln // 2, ln // 2 + 1):
                px = int(cx + math.cos(ang) * i) % S
                py = int(cy + math.sin(ang) * i) % S
                for o in (0, 1):
                    q = (py + o) % S
                    col[q, px] = bonec[1 if o else 0]
                    h[q, px] = 0.85
            for s in (-1, 1):
                px = int(cx + math.cos(ang) * s * ln / 2) % S
                py = int(cy + math.sin(ang) * s * ln / 2) % S
                for dy in (-1, 0, 1, 2):
                    for dx in (-1, 0, 1):
                        col[(py + dy) % S, (px + dx) % S] = bonec[1]


def _runes(col, h, rng, P, rows):
    S = FILL
    acc = hexc(P["acc"])
    for (y0, hh) in rows:
        for _ in range(2):
            x0 = int(rng.integers(0, S - 8))
            yc = y0 + hh // 2 - 3
            glyph = rng.integers(0, 2, (6, 5))
            glyph[:, 2] = 1
            for gy in range(6):
                for gx in range(5):
                    if glyph[gy, gx] and rng.random() < 0.8:
                        px, py = (x0 + gx) % S, (yc + gy) % S
                        col[py, px] = acc * 0.85
                        h[py, px] -= 0.2


def fill_voronoi(P, rng, n=28, round_=True, gap=1.4, pebbles=False):
    """Pedras arredondadas (paralelepípedos / rocha rachada)."""
    S = FILL
    pts = rng.random((n, 2)) * S
    d1, d2, idx = voronoi(S, pts)
    edge = d2 - d1
    fine = fbm(S, rng, ((16, 1.0), (32, 0.6), (64, 0.4)))
    tone = rng.random(n)[idx] * 0.4 - 0.2
    if round_:
        h = np.clip(edge / (5.0 * K), 0, 1) ** 0.6
    else:
        h = np.clip(edge / (2.5 * K), 0, 1) * 0.6 + tone * 0.5 + 0.3
    h += (fine - 0.5) * 0.2
    gapm = edge < gap
    h[gapm] = 0.05
    base, dark, light = hexc(P["base"]), hexc(P["dark"]), hexc(P["light"])
    rampc = ramp_from(base, dark, light)
    lit = light_term(h, 3.0)
    v = np.clip(lit * 0.7 + h * 0.3 + tone * 0.5 - 0.05, 0, 1)
    col = shade(rampc, v)
    col[gapm] = hexc(P["line"])
    return col, h


def fill_earth(P, rng, roots=True, stones=0.5, strata=0.3, bones=0.0):
    """Terra com camadas, pedrinhas e raízes."""
    S = FILL
    n1 = fbm(S, rng)
    fine = fbm(S, rng, ((16, 1.0), (32, 0.8), (64, 0.6)))
    yy = np.arange(S)[:, None] * np.ones((1, S))
    layers = np.sin((yy / S * 6 + n1 * 1.5) * math.tau) * strata
    h = 0.45 + (fine - 0.5) * 0.5 + layers * 0.2
    base, dark, light = hexc(P["base"]), hexc(P["dark"]), hexc(P["light"])
    rampc = ramp_from(base, dark, light)
    v = np.clip(light_term(h, 2.0) * 0.5 + h * 0.4 + layers * 0.35 + 0.05, 0, 1)
    col = shade(rampc, v)
    # pedrinhas
    k = int(26 * stones)
    stone_r = ramp_from(hexc(P["base"]) * 0.8 + hexc("#707080") * 0.4, hexc(P["dark"]), hexc(P["light"]) * 1.1, 4)
    for _ in range(k):
        cx, cy = rng.random(2) * S
        rx, ry = rng.uniform(2, 5) * K, rng.uniform(1.5, 3.5) * K
        Y, X = np.mgrid[0:S, 0:S] + 0.5
        dx = np.minimum(np.abs(X - cx), S - np.abs(X - cx)) / rx
        dy = np.minimum(np.abs(Y - cy), S - np.abs(Y - cy)) / ry
        sgn_y = np.where(((Y - cy) % S) < S / 2, 1.0, -1.0)
        d = dx * dx + dy * dy
        m = d <= 1.0
        hv = np.sqrt(np.clip(1 - d, 0, 1))
        h[m] = 0.6 + hv[m] * 0.4
        vv = np.clip(0.35 + hv * 0.3 - sgn_y * dy * 0.25, 0, 1)
        col[m] = shade(stone_r, vv[m])
        # contorno escuro embaixo
        ring = (d > 1.0) & (d < 1.5) & (sgn_y > 0)
        col[ring] = col[ring] * 0.7
    if roots:
        rc = [hexc("#3a2616"), hexc("#5a3c22"), hexc("#7a5634")]
        for _ in range(7):
            x = rng.random() * S
            y = rng.random() * S
            ang = rng.uniform(0.3, 1.2) * (1 if rng.random() < 0.5 else -1) + math.pi / 2
            for i in range(int(rng.integers(18, 40) * K)):
                ang += rng.normal(0, 0.25)
                x += math.cos(ang) * 1.0
                y += abs(math.sin(ang)) * 1.0
                px, py = int(x) % S, int(y) % S
                col[py, px] = rc[1]
                col[py, (px + 1) % S] = rc[0]
                col[(py - 1) % S, px] = rc[2]
                h[py, px] = 0.8
    if bones > 0:
        _embed_bones(col, h, rng, bones, P)
    return col, h


def fill_sandstone(P, rng, carved=False, strata=True):
    S = FILL
    if carved:
        col, h = fill_blocks(P, rng, rows_h=(16, 16), widths=(28, 40), mortar=1, chip=0.1, cracks=0.1)
        # frisos entalhados: linha de losangos no meio de algumas fiadas
        acc = hexc(P["light"])
        for y0 in range(0, S, int(32 * K)):
            yc = y0 + int(8 * K)
            for x in range(0, S, int(8 * K)):
                for k in range(-2, 3):
                    for j in range(-(2 - abs(k)), 3 - abs(k)):
                        px, py = (x + int(4 * K) + j) % S, (yc + k) % S
                        col[py, px] = hexc(P["dark"]) if abs(k) + abs(j) == 2 else acc
                        h[py, px] -= 0.15
        return col, h
    n1 = fbm(S, rng)
    fine = fbm(S, rng, ((16, 1.0), (32, 0.8), (64, 0.5)))
    yy = np.arange(S)[:, None] * np.ones((1, S))
    strat = (np.sin((yy / S * 10 + n1 * 2.0) * math.tau) * 0.5 + 0.5)
    h = strat * 0.5 + fine * 0.4
    base, dark, light = hexc(P["base"]), hexc(P["dark"]), hexc(P["light"])
    rampc = ramp_from(base, dark, light)
    v = np.clip(strat * 0.55 + light_term(h, 2.4) * 0.4 + (fine - 0.5) * 0.3, 0, 1)
    col = shade(rampc, v)
    # buracos de erosão
    holes = fine < 0.18
    col[holes] = dark * 0.8
    h[holes] = 0.1
    return col, h


def fill_logs(P, rng):
    """Toras empilhadas na horizontal (paliçada/fortaleza)."""
    S = FILL
    h = np.zeros((S, S))
    col = np.zeros((S, S, 3))
    base, dark, light = hexc(P["base"]), hexc(P["dark"]), hexc(P["light"])
    rampc = ramp_from(base, dark, light)
    fine = fbm(S, rng, ((8, 0.6), (32, 1.0), (64, 0.6)))
    y = 0
    while y < S:
        r = int(round(7 * K))
        cyl = np.zeros((S, S))
        for yy in range(y, min(y + 2 * r, S)):
            k = (yy - y - r + 0.5) / r
            cyl[yy, :] = math.sqrt(max(0.0, 1 - k * k))
            v = np.clip(0.25 + 0.6 * math.sqrt(max(0.0, 1 - k * k)) - k * 0.25 + (fine[yy] - 0.5) * 0.35, 0, 1)
            col[yy] = shade(rampc, v)
            h[yy] = cyl[yy]
        # veios da casca
        for yy in range(y + 2, min(y + 2 * r - 1, S), 3):
            xs = (np.arange(S) + int(rng.integers(0, S))) % S
            m = fine[yy, xs] > 0.55
            col[yy, m] = col[yy, m] * 0.78
        # pontas de toras (anéis) de vez em quando
        for _ in range(2):
            ex = int(rng.integers(0, S))
            for yy in range(y, min(y + 2 * r, S)):
                for xx in range(-r, r + 1):
                    dd = math.hypot(xx, yy - y - r + 0.5)
                    if dd <= r - 0.5:
                        px = (ex + xx) % S
                        ringv = (math.sin(dd * 1.7) * 0.5 + 0.5)
                        col[yy, px] = mixc(hexc(P["light"]), hexc(P["dark"]), ringv * 0.6)
                        h[yy, px] = 0.8
        y += 2 * r
        if y < S:
            col[y - 1] = hexc(P["line"])
    return col, h


FILLS = {
    "castle": lambda P, r: fill_blocks(P, r, rows_h=(12, 14), widths=(18, 32), moss=0.18, cracks=0.4),
    "ruins": lambda P, r: fill_blocks(P, r, rows_h=(10, 16), widths=(14, 30), moss=0.35, cracks=0.8, chip=0.5),
    "arcane": lambda P, r: fill_blocks(P, r, rows_h=(14, 16), widths=(22, 34), runes=1.0, cracks=0.2),
    "catacomb": lambda P, r: fill_blocks(P, r, rows_h=(10, 12), widths=(14, 24), bone=1.4, cracks=0.5, chip=0.4),
    "sky": lambda P, r: fill_blocks(P, r, rows_h=(16, 16), widths=(28, 44), marble=True, cracks=0.1, chip=0.05),
    "temple": lambda P, r: fill_sandstone(P, r, carved=True),
    "desert": lambda P, r: fill_sandstone(P, r),
    "town": lambda P, r: fill_voronoi(P, r, n=72),
    "cave": lambda P, r: fill_voronoi(P, r, n=44, round_=False, gap=1.0),
    "forest": lambda P, r: fill_earth(P, r, stones=0.6),
    "graveyard": lambda P, r: fill_earth(P, r, stones=0.5, bones=0.6),
    "swamp": lambda P, r: fill_earth(P, r, stones=0.25, strata=0.6),
    "war": lambda P, r: fill_logs(P, r),
    # regiões feitas à mão (estilo Hollow Knight: massas escuras, borda viva)
    "galeria": lambda P, r: fill_voronoi(P, r, n=26, round_=True, gap=1.8, pebbles=True),
    "bosque": lambda P, r: fill_earth(P, r, roots=True, stones=0.35, strata=0.2),
    "cinzal": lambda P, r: fill_earth(P, r, roots=False, stones=0.8, strata=0.4, bones=0.2),
}

# fundo (parede atrás): mais simples, escura e fria
BGS = {
    "castle": "blocks", "ruins": "blocks", "arcane": "blocks", "catacomb": "blocks", "sky": "blocks",
    "temple": "blocks", "desert": "strata", "town": "planks", "cave": "rock", "forest": "rock",
    "graveyard": "rock", "swamp": "rock", "war": "planks",
    "galeria": "blocks", "bosque": "rock", "cinzal": "blocks",
}


def bg_fill(name, P, rng):
    kind = BGS[name]
    Q = dict(P)
    base = hexc(P["bg"])
    Q["base"] = "#%02x%02x%02x" % tuple(int(c) for c in base)
    Q["dark"] = "#%02x%02x%02x" % tuple(int(c) for c in base * 0.6)
    Q["light"] = "#%02x%02x%02x" % tuple(int(min(255, c)) for c in base * 1.35)
    if kind == "blocks":
        return fill_blocks(Q, rng, rows_h=(16, 16), widths=(24, 40), cracks=0.3, chip=0.2)
    if kind == "strata":
        return fill_sandstone(Q, rng)
    if kind == "rock":
        return fill_voronoi(Q, rng, n=12, round_=False, gap=0.8)
    # tábuas verticais
    S = FILL
    col = np.zeros((S, S, 3))
    h = np.zeros((S, S))
    rampc = ramp_from(base, base * 0.6, base * 1.3)
    fine = fbm(S, rng, ((8, 0.5), (32, 1.0), (64, 0.5)))
    x = 0
    while x < S:
        w = int(rng.integers(10, 15) * K)
        t = rng.random() * 0.3
        for xx in range(x, min(x + w, S)):
            k = (xx - x) / max(w - 1, 1)
            v = np.clip(0.35 + t + (fine[:, xx] - 0.5) * 0.5 - abs(k - 0.4) * 0.3, 0, 1)
            col[:, xx] = shade(rampc, v)
            h[:, xx] = 0.7 - abs(k - 0.5) * 0.6
        if x + w - 1 < S:
            col[:, x + w - 1] = hexc(P["line"])
        x += w
    for y in range(0, S, int(32 * K)):
        col[y:y + 2, :] = hexc(P["line"]) * 1.4
    return col, h


# ===========================================================================
# Superfícies (topo), tetos e laterais — desenhadas por tile
# ===========================================================================

def surface_style(name):
    return {
        "castle": "moss", "ruins": "grass", "forest": "grass", "graveyard": "deadgrass", "swamp": "mud",
        "town": "cap", "arcane": "cap", "catacomb": "cap", "temple": "carved", "sky": "goldtrim",
        "desert": "sand", "cave": "moss", "war": "deadgrass",
        "galeria": "cap", "bosque": "moss", "cinzal": "deadgrass",
    }[name]


def marker(g):
    return np.array([255.0, float(g), 255.0])


class Tile:
    def __init__(self):
        self.rgb = np.zeros((T, T, 3))
        self.a = np.zeros((T, T), dtype=bool)
        self.n = np.zeros((T, T, 3))
        self.n[..., 2] = 1.0

    def set(self, x, y, c, nrm=None):
        if 0 <= x < T and 0 <= y < T:
            self.rgb[y, x] = c
            self.a[y, x] = True
            if nrm is not None:
                self.n[y, x] = nrm

    def image(self):
        out = np.zeros((T, T, 4), dtype=np.uint8)
        out[..., :3] = np.clip(self.rgb, 0, 255).astype(np.uint8)
        out[..., 3] = np.where(self.a, 255, 0)
        return out

    def nimage(self):
        n = self.n / np.maximum(np.linalg.norm(self.n, axis=-1, keepdims=True), 1e-6)
        out = np.zeros((T, T, 4), dtype=np.uint8)
        out[..., :3] = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
        out[..., 3] = 255
        return out


def blob_tile(mask, name, P, var, rng):
    """Um tile do autotile: miolo (magenta) + bordas desenhadas."""
    t = Tile()
    N = bool(mask & 1)
    E = bool(mask & 4)
    S_ = bool(mask & 16)
    W = bool(mask & 64)
    NE = bool(mask & 2)
    SE = bool(mask & 8)
    SW = bool(mask & 32)
    NW = bool(mask & 128)
    line = hexc(P["line"])
    style = surface_style(name)
    top, top_d = hexc(P["top"]), hexc(P["top_d"])
    dark = hexc(P["dark"])
    # irregularidade das bordas (1 px), determinística por variação
    r = np.random.default_rng(mask * 31 + var * 977 + zlib.crc32(name.encode()) % 1000)
    bump_top = r.integers(0, 2, T) if not N else np.zeros(T, int)
    bump_bot = r.integers(0, 2, T) if not S_ else np.zeros(T, int)
    bump_l = r.integers(0, 2, T) if not W else np.zeros(T, int)
    bump_r = r.integers(0, 2, T) if not E else np.zeros(T, int)
    # suaviza (sem dentes isolados)
    for b in (bump_top, bump_bot, bump_l, bump_r):
        for i in range(1, T - 1):
            if b[i - 1] == b[i + 1] != b[i]:
                b[i] = b[i - 1]
    R = 4.0 * K  # raio das quinas externas
    for y in range(T):
        for x in range(T):
            # dentro da forma?
            inside = True
            if not N and y < bump_top[x]:
                inside = False
            if not S_ and y > T - 1 - bump_bot[x]:
                inside = False
            if not W and x < bump_l[y]:
                inside = False
            if not E and x > T - 1 - bump_r[y]:
                inside = False
            # quinas externas arredondadas
            for (cx, cy, ok) in ((R, R, not N and not W), (T - R, R, not N and not E), (R, T - R, not S_ and not W), (T - R, T - R, not S_ and not E)):
                if ok:
                    dx = (x + 0.5) - cx
                    dy = (y + 0.5) - cy
                    if ((dx < 0) == (cx < T / 2)) and ((dy < 0) == (cy < T / 2)) and dx * dx + dy * dy > R * R:
                        inside = False
            if not inside:
                continue
            # distâncias às bordas expostas
            dt = (y - bump_top[x]) if not N else 99
            db = (T - 1 - bump_bot[x] - y) if not S_ else 99
            dl = (x - bump_l[y]) if not W else 99
            dr = (T - 1 - bump_r[y] - x) if not E else 99
            # quinas internas (vizinhos ortogonais sólidos, diagonal vazia)
            dci = 99
            for (cx, cy, ok) in ((0, 0, N and W and not NW), (T, 0, N and E and not NE), (0, T, S_ and W and not SW), (T, T, S_ and E and not SE)):
                if ok:
                    dci = min(dci, math.hypot(x + 0.5 - cx, y + 0.5 - cy) - 0.5)
            if dci < 0.9:
                continue  # buraquinho da quina interna (fica vazio -> contorno)
            dmin = min(dt, db, dl, dr, dci)
            # normal do chanfro
            nx = ny = 0.0
            bv = 3 * K
            if dl < bv:
                nx -= (bv - dl) / bv
            if dr < bv:
                nx += (bv - dr) / bv
            if dt < bv:
                ny += (bv - dt) / bv
            if db < bv:
                ny -= (bv - db) / bv
            nrm = np.array([nx, ny, 1.0])
            # --- cores ---
            if dmin < 1:
                c = line  # contorno
            elif dt < 99 and dt < 6 * K and style != "none":
                # superfície desenhada na escala do desenho (16 px): cada
                # "pixel de desenho" vira 1-2 px => faixa proporcional ao tile
                dd = 1 + int((dt - 1) / K)
                c = _surface_px(style, x, y, dd, P, r, var)
                if c is None:
                    c = marker(MARK_G_NORMAL + 22 if dd < 3 else MARK_G_NORMAL + 10)
            elif db < 3 * K:
                # teto: sombra do lado de baixo
                c = marker(MARK_G_NORMAL - 26 + int(db / K) * 6)
            elif dl < 3 * K:
                c = marker(MARK_G_NORMAL + 12 - int(dl / K) * 4)  # lado esquerdo pega luz
            elif dr < 3 * K:
                c = marker(MARK_G_NORMAL - 14 + int(dr / K) * 4)  # direito na sombra
            elif dci < 2.5 * K:
                c = marker(MARK_G_NORMAL - 12)
            else:
                c = marker(MARK_G_NORMAL)
            t.set(x, y, c, nrm)
    # contorno das quinas internas (anel de 1 px)
    for (cx, cy, ok) in ((0, 0, N and W and not NW), (T, 0, N and E and not NE), (0, T, S_ and W and not SW), (T, T, S_ and E and not SE)):
        if not ok:
            continue
        for y in range(T):
            for x in range(T):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) - 0.5
                if 0.9 <= d < 1.9:
                    if cy == 0 and style != "none" and (N and W or N and E):
                        # quina interna do topo: a superfície continua
                        t.set(x, y, line)
                    else:
                        t.set(x, y, line)
    return t


def _surface_px(style, x, y, dt, P, r, var):
    """Pixel da superfície de cima (None = miolo)."""
    top, top_d = hexc(P["top"]), hexc(P["top_d"])
    acc = hexc(P["acc"])
    hl = np.minimum(top * 1.25 + 12, 255)
    if style in ("grass", "moss", "deadgrass", "mud"):
        # grama: 2-3 px densos + fios que descem irregulares
        seed = (x * 7 + var * 13) % 5
        depth = {"grass": 3, "moss": 2, "deadgrass": 3, "mud": 2}[style] + (1 if seed in (1, 3) else 0) + (1 if seed == 2 and style == "grass" else 0)
        if dt == 1:
            return hl if (x + var) % 3 else top
        if dt < depth:
            return top if (x + dt + var) % 4 else top_d
        if dt == depth:
            return top_d * 0.8 if seed != 4 else None
        if style == "mud" and dt < 5:
            return None
        return None
    if style == "sand":
        if dt == 1:
            return hl
        if dt < 4:
            return top if (x * 3 + dt + var) % 5 else top_d
        if dt == 4 and (x + var) % 3 == 0:
            return top_d
        return None
    if style == "cap":
        # pedra de coroamento: faixa clara chanfrada
        if dt == 1:
            return np.minimum(hexc(P["light"]) * 1.1, 255)
        if dt < 4:
            return hexc(P["light"]) if (x + var * 5) % 11 else hexc(P["base"])
        if dt == 4:
            return hexc(P["dark"])
        return None
    if style == "carved":
        if dt == 1:
            return np.minimum(top * 1.15, 255)
        if dt < 4:
            return top if (x % 4) else top_d
        if dt == 4:
            return hexc(P["dark"])
        return None
    if style == "goldtrim":
        if dt == 1:
            return np.minimum(acc * 0.4 + top * 0.8, 255)
        if dt < 3:
            return top
        if dt == 3:
            return top_d
        if dt == 4:
            return hexc(P["light"])
        return None
    return None


def breakable_tile(name, P, fill_col):
    """Bloco rachado bem visível (cor explícita, não usa o miolo)."""
    t = Tile()
    base, dark, light, line = hexc(P["base"]), hexc(P["dark"]), hexc(P["light"]), hexc(P["line"])
    for y in range(T):
        for x in range(T):
            c = fill_col[(y + 40) % FILL, (x + 40) % FILL] * 1.08
            if x == 0 or y == 0 or x == T - 1 or y == T - 1:
                c = line
            elif x == 1 or y == 1:
                c = light
            elif x == T - 2 or y == T - 2:
                c = dark
            t.set(x, y, c, np.array([0.0, 0.0, 1.0]))
    # rachaduras
    for (x0, y0, x1, y1) in [tuple(int(round(v * K)) for v in seg) for seg in ((3, 2, 8, 8), (8, 8, 6, 13), (8, 8, 13, 10), (11, 3, 9, 6))]:
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            t.set(x, y, line)
            t.set(x + 1, y, dark)
    return t


def bg_tile():
    t = Tile()
    for y in range(T):
        for x in range(T):
            t.set(x, y, marker(MARK_G_NORMAL))
    return t


# ===========================================================================
# Plataformas, espinhos, franja, pendentes e decorações (cores explícitas)
# ===========================================================================

def platform_tile(name, P, part):
    t = Tile()
    kind = {"forest": "wood", "graveyard": "wood", "town": "wood", "desert": "wood", "swamp": "wood",
            "war": "wood", "catacomb": "bone", "sky": "marble"}.get(name, "stone")
    line = hexc(P["line"])
    if kind == "wood":
        a, b, c = hexc("#a87a4e"), hexc("#7e5634"), hexc("#553a22")
    elif kind == "bone":
        a, b, c = hexc("#e8dcc0"), hexc("#bcae8e"), hexc("#7e7058")
    elif kind == "marble":
        a, b, c = hexc(P["light"]), hexc(P["base"]), hexc(P["dark"])
    else:
        a, b, c = hexc(P["light"]), hexc(P["base"]), hexc(P["dark"])
    left = part in ("L", "S")
    right = part in ("R", "S")
    for x in range(T):
        x0 = 1 if left else 0
        x1 = T - 2 if right else T - 1
        if x < x0 or x > x1:
            continue
        edge = (left and x == x0) or (right and x == x1)
        th = int(round(6 * K))  # espessura (linha de baixo)
        for y in range(0, th + 1):
            if y == 0 or y == th or edge:
                col = line
            elif y == 1:
                col = a
            elif y < th - 1:
                col = b if kind != "wood" or (x + y * 3) % 9 else c
            else:
                col = c
            t.set(x, y, col, np.array([0.0, 0.6 if y < 2 else (-0.5 if y > th - 2 else 0.0), 1.0]))
        if kind == "wood" and x in (int(4 * K), int(11 * K)):
            t.set(x, th // 2, c)  # pregos/veios
    # suportes (mão-francesa) nas pontas
    if left or right:
        sx = int(3 * K) if left else T - 1 - int(3 * K)
        for y in range(int(7 * K), int(12 * K)):
            t.set(sx, y, line)
            t.set(sx + (1 if left else -1), y, c if kind == "wood" else hexc(P["dark"]))
    return t


def spikes_tile(name, P):
    t = Tile()
    kind = {"forest": "thorn", "swamp": "thorn", "temple": "gold", "sky": "gold", "desert": "bone",
            "catacomb": "bone", "cave": "crystal", "arcane": "crystal", "war": "stakes"}.get(name, "iron")
    pal = {"iron": ("#dfe4ee", "#9aa2b8", "#5a6078"), "gold": ("#fff0a0", "#e0b040", "#8a6420"),
           "bone": ("#f4ecd8", "#c8b894", "#7e7058"), "crystal": ("#d0f8ff", "#70c8f0", "#306890"),
           "thorn": ("#9ac070", "#5a8a3a", "#2e4a20"), "stakes": ("#c8a070", "#8a6040", "#4a3020")}[kind]
    a, b, c = hexc(pal[0]), hexc(pal[1]), hexc(pal[2])
    line = hexc(P["line"])
    for k in range(4):
        cx = (2 + k * 4) * K
        hgt = int(round((9 if k % 2 == 0 else 7) * K))
        for y in range(T - hgt, T):
            half = ((y - (T - hgt)) * 1.8 / hgt + 0.2) * K
            for x in range(T):
                dx = x + 0.5 - cx
                if abs(dx) <= half + 0.5:
                    if abs(dx) > half - 0.5:
                        col = line
                    elif dx < 0:
                        col = a
                    else:
                        col = b if y < T - 3 else c
                    t.set(x, y, col, np.array([np.sign(dx) * 0.6, 0.0, 1.0]))
    for x in range(T):
        t.set(x, T - 1, line)
        t.set(x, T - 2, c)
    return t


def fringe_tile(name, P, var):
    """Pontas da grama/musgo acima da superfície (fica no tile de cima,
    encostado embaixo)."""
    t = Tile()
    style = surface_style(name)
    top, top_d = hexc(P["top"]), hexc(P["top_d"])
    hl = np.minimum(top * 1.25 + 12, 255)
    r = np.random.default_rng(var * 101 + len(name) * 7)
    if style in ("grass", "moss", "deadgrass", "mud"):
        maxh = int({"grass": 6, "moss": 3, "deadgrass": 5, "mud": 2}[style] * K)
        x = 0
        while x < T:
            hgt = int(r.integers(1, maxh + 1))
            lean = int(r.integers(-1, 2))
            for k in range(hgt):
                xx = x + (lean if k > hgt // 2 else 0)
                t.set(xx, T - 1 - k, hl if k == hgt - 1 else (top if k > 0 else top_d))
            x += int(r.integers(1, 3))
        if style == "grass" and var % 2 == 0:
            fx = int(r.integers(2, T - 2))
            flower = hexc(P["acc"])
            for (dx, dy) in ((0, -7), (-1, -6), (1, -6), (0, -5)):
                t.set(fx + dx, T + dy, flower)
            t.set(fx, T - 6, np.array([255, 250, 220]))
            for k in range(1, 5):
                t.set(fx, T - k, top_d)
    elif style == "sand":
        for x in range(T):
            if r.random() < 0.3:
                t.set(x, T - 1, top)
    elif style in ("cap", "carved", "goldtrim"):
        pass  # sem franja
    return t


def hang_tile(name, P, var):
    """Pendentes sob o teto: raízes, cipós, musgo, estalactites, correntes,
    teias (fica no tile de baixo do teto, encostado em cima)."""
    t = Tile()
    kind = {"forest": "vines", "swamp": "vines", "ruins": "vines", "castle": "chains", "graveyard": "roots",
            "cave": "stalactite", "catacomb": "web", "arcane": "chains", "town": "roots", "temple": "banner",
            "sky": "none", "desert": "roots", "war": "roots", "galeria": "stalactite", "bosque": "vines", "cinzal": "roots"}[name]
    r = np.random.default_rng(var * 57 + len(name))
    top, top_d = hexc(P["top"]), hexc(P["top_d"])
    line = hexc(P["line"])
    if kind == "vines":
        for _ in range(2):
            x = int(r.integers(1, T - 1))
            ln = int(r.integers(5, 14) * K)
            for y in range(ln):
                xx = x + (1 if (y // 3) % 2 else 0)
                t.set(xx, y, top_d if y % 3 else top)
                if y % 4 == 2:
                    t.set(xx + 1, y, top)
    elif kind == "roots":
        rc = [hexc("#2e1e12"), hexc("#4e3420"), hexc("#6e4c30")]
        x = int(r.integers(2, T - 2))
        for y in range(int(r.integers(4, 11) * K)):
            x += int(r.integers(-1, 2)) if y > 1 else 0
            x = max(0, min(T - 2, x))
            t.set(x, y, rc[1])
            t.set(x + 1, y, rc[0])
    elif kind == "stalactite":
        acc = hexc(P["acc"])
        base, dark, light = hexc(P["base"]), hexc(P["dark"]), hexc(P["light"])
        cx = int(r.integers(4, 12) * K)
        ln = int(r.integers(6, 13) * K)
        for y in range(ln):
            half = max(0.0, 3.0 * K * (1 - y / ln))
            for x in range(T):
                dx = x + 0.5 - cx
                if abs(dx) <= half:
                    col = line if abs(dx) > half - 1 else (light if dx < 0 else dark)
                    t.set(x, y, col)
        if var % 2 == 0:
            t.set(cx, ln + 1, acc)  # gota brilhando
    elif kind == "chains":
        steel = [hexc("#8a90a8"), hexc("#50566c")]
        x = int(r.integers(3, 13) * K)
        for y in range(int(r.integers(6, 15) * K)):
            if y % 3 == 0:
                t.set(x - 1, y, steel[1])
                t.set(x + 1, y, steel[1])
            else:
                t.set(x, y, steel[0] if y % 3 == 1 else steel[1])
    elif kind == "web":
        wc = np.array([200.0, 200.0, 210.0])
        for i in range(T):
            if i % 2 == 0:
                t.set(i, i // 2, wc * 0.8)
                t.set(T - 1 - i // 2, i, wc * 0.7)
        for x in range(0, T, 3):
            t.set(x, 0, wc)
    elif kind == "banner":
        if var % 2 == 0:
            red = [hexc("#a02828"), hexc("#701a1e")]
            gold = hexc(P["acc"])
            x0, x1, yl = int(4 * K), int(12 * K), int(12 * K)
            mid = (x0 + x1 - 1) / 2.0
            for y in range(yl):
                for x in range(x0, x1):
                    if y > yl - 3 and abs(x - mid) > (yl - 1 - y) * 2:
                        continue
                    t.set(x, y, red[0] if abs(x - mid) < (x1 - x0) * 0.2 else red[1])
            for x in range(x0, x1):
                t.set(x, 1, gold)
    return t


def deco_tile(name, P, var):
    """Decoração pousada sobre o chão (tile de cima, encostada embaixo)."""
    t = Tile()
    r = np.random.default_rng(var * 91 + len(name) * 3)
    line = hexc(P["line"])
    acc = hexc(P["acc"])
    top, top_d = hexc(P["top"]), hexc(P["top_d"])
    stone = [hexc(P["light"]), hexc(P["base"]), hexc(P["dark"])]
    theme = {"forest": ["tuft", "flower", "mushroom", "rock", "tuft", "fern", "flower", "stump"],
             "graveyard": ["grave", "skull", "tuft", "cross", "candle", "rock", "grave", "bones"],
             "castle": ["tuft", "rock", "candle", "skull", "tuft", "banner_pole", "rock", "urn"],
             "ruins": ["tuft", "flower", "rock", "column", "tuft", "fern", "rock", "urn"],
             "cave": ["mushroom", "crystal", "rock", "mushroom", "crystal", "rock", "tuft", "bones"],
             "catacomb": ["skull", "bones", "candle", "urn", "skull", "rock", "candle", "bones"],
             "town": ["barrel", "crate", "rock", "lamp", "tuft", "urn", "crate", "rock"],
             "temple": ["candle", "urn", "candle", "rock", "idol", "urn", "candle", "rock"],
             "desert": ["cactus", "rock", "bones", "tuft", "cactus", "rock", "skull", "tuft"],
             "swamp": ["reed", "mushroom", "reed", "rock", "reed", "fern", "mushroom", "rock"],
             "sky": ["urn", "crystal", "rock", "lamp", "urn", "crystal", "rock", "tuft"],
             "arcane": ["crystal", "candle", "urn", "crystal", "rock", "idol", "candle", "rock"],
             "war": ["stake", "crate", "skull", "rock", "barrel", "tuft", "stake", "bones"],
             "galeria": ["rock", "bones", "candle", "skull", "rock", "urn", "rock", "candle"],
             "bosque": ["fern", "mushroom", "tuft", "rock", "fern", "mushroom", "tuft", "stump"],
             "cinzal": ["tuft", "rock", "grave", "tuft", "rock", "candle", "tuft", "bones"]}[name]
    kind = theme[var % len(theme)]
    B = T - 1  # linha do chão (embaixo)

    off = (T - 16) // 2  # decorações mantêm o desenho de 16 px, centradas

    def px(x, y, c):
        t.set(x + off, y, c)

    if kind == "tuft":
        for k in range(5):
            x = 4 + k * 2
            h = 3 + (k * 7 + var) % 4
            for y in range(h):
                px(x + (1 if y > h // 2 and k % 2 else 0), B - y, top if y < h - 1 else np.minimum(top * 1.3, 255))
    elif kind == "fern":
        for s in (-1, 1):
            for i in range(7):
                px(8 + s * i // 2, B - i, top_d if i % 2 else top)
                px(8 + s * (i // 2 + 1), B - i, top)
    elif kind == "flower":
        for k, fx in enumerate((4, 9, 12)):
            h = 4 + k
            for y in range(h):
                px(fx, B - y, top_d)
            c = acc if k != 1 else np.array([240.0, 120.0, 150.0])
            for (dx, dy) in ((0, 0), (-1, 1), (1, 1), (0, 2)):
                px(fx + dx, B - h - 1 + dy, c)
            px(fx, B - h, np.array([255.0, 240.0, 200.0]))
    elif kind == "mushroom":
        cap = np.array([200.0, 70.0, 60.0]) if name != "cave" else acc * 0.9
        for y in range(3):
            px(7, B - y, np.array([230.0, 220.0, 200.0]))
            px(8, B - y, np.array([190.0, 180.0, 160.0]))
        for x in range(4, 12):
            for y in range(3):
                if abs(x - 7.5) <= 3.5 - y * 0.8:
                    px(x, B - 3 - y, cap if (x + y) % 3 else np.minimum(cap * 1.4, 255))
        for x in range(4, 12):
            px(x, B - 3, line)
    elif kind == "rock":
        w = 5 + var % 3
        for y in range(4):
            for x in range(8 - w // 2, 8 + w // 2 + 1):
                if abs(x - 8) <= w / 2 - y * 0.6:
                    c = stone[0] if y == 3 or x < 8 - w // 2 + 2 else (stone[1] if y > 0 else stone[2])
                    px(x, B - y, c)
    elif kind == "crystal":
        for (cx, h, lean) in ((6, 8, -1), (9, 11, 0), (11, 6, 1)):
            for y in range(h):
                half = max(0, 1.5 - y * 0.05) if y < h - 2 else 0.5
                for x in range(T):
                    dx = x + 0.5 - (cx + lean * y / h)
                    if abs(dx) <= half + 0.5:
                        px(x, B - y, np.minimum(acc * (1.3 if dx < 0 else 0.9), 255))
    elif kind == "skull":
        bone = [hexc("#efe6d0"), hexc("#c8b898"), hexc("#7a6c56")]
        for y in range(5):
            for x in range(5, 11):
                if (x - 7.5) ** 2 + (y - 2.5) ** 2 <= 9:
                    px(x, B - 1 - y, bone[0] if y > 2 else bone[1])
        px(6, B - 3, line)
        px(9, B - 3, line)
        px(7, B - 1, bone[2])
        px(8, B - 1, bone[2])
    elif kind == "bones":
        bone = [hexc("#efe6d0"), hexc("#c8b898")]
        for x in range(3, 13):
            px(x, B - (1 if x < 8 else 2), bone[0])
            px(x, B, bone[1])
        for x in range(5, 10):
            px(x, B - 3, bone[1])
    elif kind == "grave":
        for y in range(10):
            for x in range(4, 12):
                if y > 7 and abs(x - 7.5) > 11 - y:
                    continue
                c = stone[0] if x < 6 else (stone[1] if x < 10 else stone[2])
                if y == 9 or x in (4, 11) and y < 8:
                    c = line
                px(x, B - y, c)
        for y in range(3, 7):
            px(7, B - y, stone[2])
        px(6, B - 5, stone[2])
        px(8, B - 5, stone[2])
    elif kind == "cross":
        wood = [hexc("#7a5a3a"), hexc("#4e3622")]
        for y in range(11):
            px(8, B - y, wood[0])
            px(9, B - y, wood[1])
        for x in range(5, 13):
            px(x, B - 7, wood[0])
            px(x, B - 6, wood[1])
    elif kind == "candle":
        for k, cx in enumerate((5, 9, 12)):
            h = 3 + (k + var) % 3
            for y in range(h):
                px(cx, B - y, np.array([236.0, 226.0, 200.0]))
                px(cx + 1, B - y, np.array([196.0, 186.0, 160.0]))
            px(cx, B - h, np.array([255.0, 220.0, 120.0]))
            px(cx, B - h - 1, np.array([255.0, 160.0, 60.0]))
    elif kind in ("urn", "idol"):
        c0, c1, c2 = (hexc("#c89a58"), hexc("#9a7040"), hexc("#5a3e22")) if kind == "urn" else (acc, acc * 0.7, acc * 0.4)
        for y in range(9):
            w = [2, 3, 3.5, 3.5, 3, 2.5, 2, 1.5, 2.5][y]
            for x in range(T):
                dx = x + 0.5 - 8
                if abs(dx) <= w:
                    px(x, B - y, line if abs(dx) > w - 1 else (c0 if dx < 0 else (c1 if dx < 2 else c2)))
    elif kind == "column":
        for y in range(12):
            for x in range(5, 11):
                c = stone[0] if x < 7 else (stone[1] if x < 9 else stone[2])
                if x in (5, 10) or y in (0, 11):
                    c = line
                px(x, B - y, c)
        for x in range(4, 12):
            px(x, B - 11, stone[0])
    elif kind in ("barrel", "crate"):
        wood = [hexc("#a87a4e"), hexc("#7e5634"), hexc("#553a22")]
        for y in range(9):
            for x in range(4, 13):
                c = wood[0] if x < 7 else (wood[1] if x < 11 else wood[2])
                if x in (4, 12) or y in (0, 8):
                    c = line
                elif kind == "barrel" and y in (2, 6):
                    c = hexc("#5a5a66")
                elif kind == "crate" and (x - 4 == y or x + y == 12 + 4):
                    c = wood[2]
                px(x, B - y, c)
    elif kind == "lamp":
        for y in range(12):
            px(8, B - y, line)
        for y in range(12, 15):
            for x in range(6, 11):
                px(x, B - y, np.array([255.0, 210.0, 120.0]) if 6 < x < 10 else line)
    elif kind == "cactus":
        g = [hexc("#6a9a4a"), hexc("#4a7a34"), hexc("#2e5222")]
        for y in range(12):
            px(7, B - y, g[0])
            px(8, B - y, g[1])
            px(9, B - y, g[2])
        for y in range(5, 9):
            px(4, B - y, g[1])
            px(12, B - y - 2, g[1])
        px(5, B - 5, g[1])
        px(6, B - 5, g[1])
        px(10, B - 7, g[1])
        px(11, B - 7, g[1])
    elif kind == "reed":
        for k, x in enumerate((5, 8, 11)):
            h = 8 + (k * 3 + var) % 5
            for y in range(h):
                px(x, B - y, top_d if y < h - 3 else hexc("#6a4a2a"))
    elif kind == "stump":
        wood = [hexc("#8a6440"), hexc("#5e4028"), hexc("#3a2616")]
        for y in range(5):
            for x in range(4, 13):
                px(x, B - y, wood[0] if x < 7 else (wood[1] if x < 11 else wood[2]))
        for x in range(4, 13):
            px(x, B - 5, hexc("#c89a6a"))
    elif kind == "stake":
        wood = [hexc("#b08050"), hexc("#7a5434")]
        for k, x in enumerate((5, 9, 12)):
            h = 7 + k * 2
            for y in range(h):
                px(x, B - y, wood[0] if y < h - 1 else line)
                px(x + 1, B - y, wood[1])
    elif kind == "banner_pole":
        for y in range(14):
            px(5, B - y, line)
        red = hexc("#a02828")
        for y in range(8, 14):
            for x in range(6, 12):
                px(x, B - y, red if (x + y) % 5 else hexc("#701a1e"))
    return t


# ===========================================================================
# Montagem
# ===========================================================================

SETS = {
    "castle": {"base": "#5a6078", "dark": "#3a3e52", "light": "#8a92ac", "line": "#12121c", "top": "#5e8a52", "top_d": "#3e6438", "acc": "#c7a66a", "bg": "#262a3a"},
    "graveyard": {"base": "#4a3e4c", "dark": "#302834", "light": "#6e6070", "line": "#100c14", "top": "#6e7a5e", "top_d": "#4a5440", "acc": "#b8c0a0", "bg": "#1e1a26"},
    "forest": {"base": "#5e4230", "dark": "#3e2a1e", "light": "#86644a", "line": "#1a100a", "top": "#5aa84a", "top_d": "#347a32", "acc": "#f0d060", "bg": "#1e2a20"},
    "town": {"base": "#6e6060", "dark": "#4a3e40", "light": "#9a8a88", "line": "#181214", "top": "#b0a098", "top_d": "#847470", "acc": "#e0b060", "bg": "#2e2428"},
    "temple": {"base": "#b88650", "dark": "#8a6038", "light": "#e0b478", "line": "#301e10", "top": "#f0cc88", "top_d": "#c49c5c", "acc": "#fff0a0", "bg": "#3e2a1c"},
    "desert": {"base": "#c08c56", "dark": "#946642", "light": "#e2b27c", "line": "#301e10", "top": "#f2d49a", "top_d": "#d6ae72", "acc": "#6a9a4a", "bg": "#44301e"},
    "cave": {"base": "#42425a", "dark": "#2a2a3e", "light": "#62627e", "line": "#0c0c14", "top": "#4e7466", "top_d": "#34544a", "acc": "#70e0f0", "bg": "#18182a"},
    "sky": {"base": "#cfd4e2", "dark": "#9aa2ba", "light": "#f2f4fa", "line": "#3e4260", "top": "#f0d070", "top_d": "#c8a040", "acc": "#90d0ff", "bg": "#5a6284"},
    "swamp": {"base": "#464a32", "dark": "#2e3222", "light": "#646a48", "line": "#12140c", "top": "#628a3a", "top_d": "#42682a", "acc": "#c0e070", "bg": "#1c2016"},
    "war": {"base": "#6a4630", "dark": "#482e1e", "light": "#8e6444", "line": "#1a100a", "top": "#84764c", "top_d": "#5c5236", "acc": "#c05030", "bg": "#2a1c14"},
    "arcane": {"base": "#52446e", "dark": "#382e50", "light": "#7a66a0", "line": "#120c20", "top": "#8474b4", "top_d": "#64548e", "acc": "#c890ff", "bg": "#221c36"},
    "catacomb": {"base": "#564c42", "dark": "#3a322c", "light": "#7a6e5e", "line": "#14100c", "top": "#86796a", "top_d": "#665c4e", "acc": "#e8e0c8", "bg": "#241e1a"},
    "ruins": {"base": "#7e706e", "dark": "#5a4e4e", "light": "#a8988e", "line": "#1e1618", "top": "#72a656", "top_d": "#4e7e3e", "acc": "#e0b0a0", "bg": "#3a3032"},
    "galeria": {"base": "#343c50", "dark": "#222838", "light": "#56627a", "line": "#07090e", "top": "#7e8ca6", "top_d": "#4c586e", "acc": "#e8c880", "bg": "#151924"},
    "bosque": {"base": "#2a3426", "dark": "#1a2016", "light": "#44543a", "line": "#050805", "top": "#4a8a3a", "top_d": "#2a5424", "acc": "#a0f0d0", "bg": "#0e150f"},
    "cinzal": {"base": "#3a3430", "dark": "#26211d", "light": "#58504a", "line": "#0a0807", "top": "#8e887c", "top_d": "#5c564c", "acc": "#d8b070", "bg": "#1b1716"},
}


def build(name, P):
    rng = rng_for(name)
    fill_col, fill_h = FILLS[name](P, rng)
    fill_n = normals_from_height(fill_h, 2.4)
    bgc, bgh = bg_fill(name, P, rng_for(name, 7))
    bg_n = normals_from_height(bgh, 1.6)
    save_rgb(fill_col, os.path.join(OUT, name + "_fill.png"))
    save_raw(fill_n, os.path.join(OUT, name + "_fill_n.png"))
    save_rgb(bgc, os.path.join(OUT, name + "_bg.png"))
    save_raw(bg_n, os.path.join(OUT, name + "_bg_n.png"))
    cols, rows = 8, 11
    atlas = np.zeros((rows * T, cols * T, 4), dtype=np.uint8)
    natlas = np.zeros((rows * T, cols * T, 4), dtype=np.uint8)
    natlas[..., 0] = 128
    natlas[..., 1] = 128
    natlas[..., 2] = 255
    natlas[..., 3] = 255

    def put(i, tile):
        x, y = (i % cols) * T, (i // cols) * T
        atlas[y:y + T, x:x + T] = tile.image()
        natlas[y:y + T, x:x + T] = tile.nimage()

    for i, m in enumerate(BLOB):
        put(i, blob_tile(m, name, P, 0, rng))
    for m, extra in VARIANTS.items():
        for k, idx in enumerate(extra):
            put(idx, blob_tile(m, name, P, k + 1, rng))
    put(IDX_BREAK, breakable_tile(name, P, fill_col))
    put(IDX_BG, bg_tile())
    for k, part in enumerate(["L", "M", "R", "S"]):
        put(64 + k, platform_tile(name, P, part))
    put(68, spikes_tile(name, P))
    for k in range(4):
        put(72 + k, fringe_tile(name, P, k))
        put(76 + k, hang_tile(name, P, k))
    for k in range(8):
        put(80 + k, deco_tile(name, P, k))
    Image.fromarray(atlas, "RGBA").save(os.path.join(OUT, name + ".png"))
    Image.fromarray(natlas, "RGBA").save(os.path.join(OUT, name + "_n.png"))
    print(name, "ok")


def save_rgb(col, path):
    img = np.zeros((col.shape[0], col.shape[1], 4), dtype=np.uint8)
    img[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    img[..., 3] = 255
    Image.fromarray(img, "RGBA").save(path)


def save_raw(n, path):
    img = np.zeros((n.shape[0], n.shape[1], 4), dtype=np.uint8)
    img[..., :3] = n
    img[..., 3] = 255
    Image.fromarray(img, "RGBA").save(path)


def write_blob_table():
    """Tabela máscara->índice para o GDScript (scripts/level/blob_table.gd)."""
    path = os.path.join(os.path.dirname(__file__), "..", "scripts", "level", "blob_table.gd")
    lines = ["class_name BlobTable", "extends RefCounted",
             "## GERADO por tools/build_tiles.py: máscara canônica de 8 vizinhos",
             "## (N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128; 1 = sólido) -> índice",
             "## do tile no atlas; VARIANTS = índices extras dos formatos comuns.", ""]
    lines.append("const INDEX := {" + ", ".join(f"{m}: {i}" for m, i in BLOB_INDEX.items()) + "}")
    lines.append("const VARIANTS := {" + ", ".join(f"{m}: {v}" for m, v in VARIANTS.items()) + "}")
    lines.append(f"const BREAKABLE := {IDX_BREAK}")
    lines.append(f"const BG := {IDX_BG}")
    lines.append("const COLS := 8")
    lines.append("")
    lines.append("")
    lines.append("static func canon(mask: int) -> int:")
    lines.append("\tvar m := mask")
    lines.append("\tif not (mask & 1 and mask & 4):")
    lines.append("\t\tm &= ~2")
    lines.append("\tif not (mask & 16 and mask & 4):")
    lines.append("\t\tm &= ~8")
    lines.append("\tif not (mask & 16 and mask & 64):")
    lines.append("\t\tm &= ~32")
    lines.append("\tif not (mask & 1 and mask & 64):")
    lines.append("\t\tm &= ~128")
    lines.append("\treturn m")
    lines.append("")
    lines.append("")
    lines.append("static func coord(i: int) -> Vector2i:")
    lines.append("\treturn Vector2i(i % COLS, i / COLS)")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


PREVIEW_MAP = [
    "##############################################",
    "#............................................#",
    "#............................................#",
    "#..................#####.....................#",
    "#.................#######..........---.......#",
    "#.........---......#####.....................#",
    "#............................................#",
    "#...........................######...........#",
    "#.......####...............########..........#",
    "#......######.............##########.........#",
    "#.....########.......^^^^############........#",
    "#####################################.....####",
    "###################################.......####",
    "###################################...########",
    "##############################################",
    "##############################################",
]


def preview(name, path):
    """Compõe um pedaço de fase com o autotile + miolo + profundidade,
    do jeito que o shader faz, para conferir sem abrir o Godot."""
    atlas = np.array(Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")).astype(np.float64)
    fill = np.array(Image.open(os.path.join(OUT, name + "_fill.png")).convert("RGB")).astype(np.float64)
    bg = np.array(Image.open(os.path.join(OUT, name + "_bg.png")).convert("RGB")).astype(np.float64)
    rows = PREVIEW_MAP
    h, w = len(rows), len(rows[0])
    img = np.zeros((h * T, w * T, 3))
    img[:] = np.array([40, 44, 62])

    def solid(x, y):
        return x < 0 or y < 0 or x >= w or y >= h or rows[y][x] == "#"

    # profundidade (distância até o ar)
    dist = np.full((h, w), 99)
    for y in range(h):
        for x in range(w):
            if not solid(x, y):
                dist[y, x] = 0
    for _ in range(6):
        for y in range(h):
            for x in range(w):
                if solid(x, y):
                    best = dist[y, x]
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < w and 0 <= yy < h:
                            best = min(best, dist[yy, xx] + 1)
                    dist[y, x] = best
    deep = np.array([12, 10, 16], dtype=np.float64)

    def blit(idx, x, y, fill_tex, dval=0.0):
        ax, ay = (idx % 8) * T, (idx // 8) * T
        tile = atlas[ay:ay + T, ax:ax + T]
        for yy in range(T):
            for xx in range(T):
                c = tile[yy, xx]
                if c[3] < 128:
                    continue
                px, py = x * T + xx, y * T + yy
                rgb = c[:3]
                if c[0] > 250 and c[2] > 250 and c[1] < 115:
                    k = 0.5 + c[1] / 100.0
                    rgb = fill_tex[py % FILL, px % FILL] * k
                img[py, px] = rgb * (1 - dval) + deep * dval

    for y in range(h):
        for x in range(w):
            ch = rows[y][x]
            if ch == "#":
                m = 0
                for bit, (dx, dy) in ((1, (0, -1)), (2, (1, -1)), (4, (1, 0)), (8, (1, 1)), (16, (0, 1)), (32, (-1, 1)), (64, (-1, 0)), (128, (-1, -1))):
                    if solid(x + dx, y + dy):
                        m |= bit
                m = canon(m)
                idx = BLOB_INDEX[m]
                if m in VARIANTS and (x * 7 + y * 3) % 4:
                    idx = VARIANTS[m][(x * 7 + y * 3) % 3]
                d = max(0, dist[y, x] - 1)
                blit(idx, x, y, fill, min(0.92, d * 0.3))
                if not solid(x, y - 1):
                    blit(72 + (x * 5) % 4, x, y - 1, fill)
                    if (x * 13 + y) % 5 == 0:
                        blit(80 + (x * 3) % 8, x, y - 1, fill)
                if not solid(x, y + 1) and (x * 11) % 4 == 0:
                    blit(76 + x % 4, x, y + 1, fill)
            elif ch == "-":
                l = rows[y][x - 1] == "-"
                r = rows[y][x + 1] == "-"
                blit(64 + (1 if l and r else (0 if not l else 2)), x, y, fill)
            elif ch == "^":
                blit(68, x, y, fill)
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    out.resize((out.width * 2, out.height * 2), Image.NEAREST).save(path)


if __name__ == "__main__":
    if os.environ.get("TILE_PREVIEW"):
        for n in sys.argv[1:] or list(SETS.keys()):
            preview(n, os.path.join(os.environ["TILE_PREVIEW"], "tp_" + n + ".png"))
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]
    for n, P in SETS.items():
        if only and n not in only:
            continue
        build(n, P)
    write_blob_table()
