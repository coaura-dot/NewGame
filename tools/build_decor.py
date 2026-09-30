#!/usr/bin/env python3
"""CENOGRAFIA dos mapas feitos à mão (estilo Hollow Knight), com o kit de
tools/spritekit.py: casas de Cinzal, poço, árvore morta, lápides, altar,
velas, estátua de Lampadeiro, sino, braseiro (santuário), lampiões apagado
e aceso, pilares, arcos, correntes, lâmpadas suspensas, ossos, fungos que
brilham, raízes, cipós, samambaias...

Saída: assets/art/decor/<id>.png (+ <id>_glow.png) e data/decor.json:
  origin   pés do sprite (px de arte; "hang" = ponto de pendurar, no topo)
  glow     tem camada de brilho       light  cor da luz própria [r, g, b]
  light_at posição da luz (px, relativa à origem)   sway  balanço (rad)
  flip     pode espelhar ao acaso

Coordenadas de desenho: 1 tile = 16 (o jogo tem 24 px por tile; RES 1.5).
Uso: python3 tools/build_decor.py [id ...]   (DECOR_PREVIEW=<pasta> prancha)
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from spritekit import RES, Canvas, Mat, hexc, save  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "art", "decor")
META = os.path.join(ROOT, "data", "decor.json")
PREVIEW = os.environ.get("DECOR_PREVIEW", "")

# ---------------------------------------------------------------------------
# Materiais
# ---------------------------------------------------------------------------
STONE = Mat(["#23222c", "#35343f", "#4a4955", "#62606c", "#7e7a84"], rim=0.45, rim_color="#9a96a4", outline="#0c0b10", wrap=0.4)
STONE_W = Mat(["#2a2622", "#3e3832", "#554c44", "#6e6358", "#8a7e70"], rim=0.45, rim_color="#a89888", outline="#0e0c0a", wrap=0.4)
STONE_B = Mat(["#1c2230", "#283042", "#374258", "#4a5670", "#62708c"], rim=0.5, rim_color="#8a9ab8", outline="#080a10", wrap=0.4)
PLASTER = Mat(["#4a4038", "#62564a", "#7a6c5c", "#948470", "#ac9c86"], rim=0.35, outline="#16110c", wrap=0.45)
WOOD = Mat(["#1e140e", "#2e2016", "#44301e", "#5c4228", "#765636"], rim=0.35, rim_color="#8a6a4a", outline="#0a0604", wrap=0.4)
WOOD_D = Mat(["#140e0a", "#201610", "#2e2016", "#3e2c1e", "#503a28"], rim=0.3, outline="#060403", wrap=0.4)
ROOF = Mat(["#1a1618", "#262024", "#342c30", "#463a3e", "#5a4a4c"], rim=0.5, rim_color="#7a6468", outline="#080607", wrap=0.4)
IRON = Mat(["#141214", "#221e20", "#34302e", "#4c4640", "#6a6258"], spec=0.8, rim=0.6, rim_color="#a08a70", outline="#050405", wrap=0.4)
BRONZE = Mat(["#2a1a0c", "#4a2e14", "#6e4a20", "#96702e", "#c29a48"], spec=1.0, rim=0.6, rim_color="#ffd890", outline="#100804", wrap=0.45)
CLOTH_R = Mat(["#2a0a0c", "#4a1216", "#6a1c1e", "#8a2a26", "#aa3e32"], rim=0.6, rim_color="#e07a5a", outline="#0c0304", wrap=0.35)
CLOTH_W = Mat(["#6a6258", "#8a8074", "#a89c8c", "#c4b8a4", "#dcd2c0"], rim=0.4, outline="#201c16", wrap=0.4)
BARK = Mat(["#141012", "#201a1a", "#2e2624", "#3e3430", "#50443c"], rim=0.55, rim_color="#8a6e5e", outline="#050404", wrap=0.35)
BONE = Mat(["#6a6252", "#8e8470", "#b0a68e", "#cec4aa", "#e8e0c8"], rim=0.4, outline="#201c14", wrap=0.45)
MOSS = Mat(["#12200e", "#1c3014", "#28441c", "#365a26", "#4a7432"], rim=0.5, rim_color="#8ab860", outline="#060a04", wrap=0.4)
ROOT = Mat(["#1a120e", "#2a1e16", "#3c2c20", "#50402e", "#66543c"], rim=0.5, rim_color="#8a7050", outline="#080504", wrap=0.35)
CANDLE = Mat(["#8a8070", "#aaa08c", "#c8bea8", "#e0d8c4"], rim=0.3, outline="#2a2418", wrap=0.5)
COAL = Mat(["#0e0a0a", "#1a1414", "#2a2020", "#3a2c28"], rim=0.2, outline="#040303")
GLASS_OFF = Mat(["#0e0c10", "#18141a", "#241e26", "#342c36", "#4a404c"], spec=1.0, rim=0.0, outline="#050406", wrap=0.6, ambient=0.4)
GLASS_ON = Mat(["#5a2410", "#8a3a14", "#c05e1c", "#ea8e30", "#ffc868"], spec=1.0, rim=0.0, outline="#1a0806", wrap=0.6, ambient=0.5, glow=(80, 34, 8, 255))
FUNGUS = Mat(["#0e3a3a", "#18585a", "#2a8080", "#50b0a8", "#90e0d0"], rim=0.4, outline="#041414", wrap=0.5, glow=(10, 60, 56, 255))
FUNGUS_STEM = Mat(["#3a4440", "#56625c", "#76827a", "#98a49a"], rim=0.3, outline="#101412")
CRYSTAL = Mat(["#18204a", "#243a7a", "#3a62b0", "#6aa0e8", "#b8e0ff"], spec=1.0, rim=0.3, outline="#060818", wrap=0.5, glow=(20, 40, 90, 255))

FIRE = [hexc("#c8401a"), hexc("#ff8a2a"), hexc("#ffd060"), hexc("#fff4d0")]
WINDOW = hexc("#ffb050")
WINDOW_HI = hexc("#ffe0a0")

DECOR = {}


def decor(name, w, h, ox=None, oy=None, **meta):
    """Registra um desenhista. w, h em coordenadas de desenho; origem
    padrão = pés (centro embaixo)."""
    def wrap(fn):
        DECOR[name] = (w, h, w / 2 if ox is None else ox, h - 2 if oy is None else oy, fn, meta)
        return fn
    return wrap


def rect_poly(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def glow_fill(c, mask, col):
    c.over[mask] = np.array(col, dtype=np.float64)
    c.over_glow[mask] = np.array(col, dtype=np.float64)


def window(c, x0, y0, x1, y1, lit=True, cross=True):
    """Janela: moldura de madeira e vidro aceso (brilho) com cruzeta."""
    c.poly(rect_poly(x0 - 1.5, y0 - 1.5, x1 + 1.5, y1 + 1.5), WOOD, z=2.0, bevel=1.0)
    m = (c.X >= x0) & (c.X <= x1) & (c.Y >= y0) & (c.Y <= y1)
    if lit:
        col = np.zeros(c.X.shape + (4,))
        t = np.clip((c.Y - y0) / max(y1 - y0, 1), 0, 1)
        for k in range(3):
            pass
        for k in range(3):
            col[..., k] = WINDOW[k] * (1 - t) * 0.4 + WINDOW_HI[k] * (1 - t) * 0.2 + WINDOW[k] * 0.6
        col[..., 3] = 255
        c.over[m] = col[m]
        c.over_glow[m] = col[m] * 0.8
    else:
        c.over[m] = np.array(hexc("#0c0a10"), dtype=np.float64)
    if cross:
        cx = (x0 + x1) / 2
        cy = (y0 + y1) / 2
        c.line(cx, y0, cx, y1, hexc("#2e2016"))
        c.line(x0, cy, x1, cy, hexc("#2e2016"))


def flame(c, x, y, w, h, t=0.3, lean=0.0):
    c.flame(x, y, w, h, lean=lean, t=t, palette=FIRE)


# ===========================================================================
# CINZAL — a vila
# ===========================================================================

def _house(c, w, h, roof_h, lit=True, sign=None, chimney=True, seed=0):
    x0, x1 = -w / 2, w / 2
    base_h = 18
    # base de pedra
    c.poly(rect_poly(x0, -base_h, x1, 0), STONE_W, z=0.0, bevel=2.0)
    rng = np.random.default_rng(seed)
    for row in range(3):
        y = -base_h + row * 6 + 1
        off = (row % 2) * 5
        for x in np.arange(x0 + off, x1, 10):
            c.line(x, y, x, y + 5, hexc("#1e1a16"))
        c.line(x0 + 1, y + 5.5, x1 - 1, y + 5.5, hexc("#1e1a16"))
    # parede de reboco com enxaimel
    c.poly(rect_poly(x0 + 2, -h, x1 - 2, -base_h), PLASTER, z=0.5, bevel=1.5)
    for x in np.linspace(x0 + 2, x1 - 2, 5):
        c.capsule(x, -h, x, -base_h, 1.1, 1.1, WOOD, z=1.0)
    c.capsule(x0 + 2, -h + 1, x1 - 2, -h + 1, 1.3, 1.3, WOOD, z=1.1)
    c.capsule(x0 + 2, -base_h - 1, x1 - 2, -base_h - 1, 1.2, 1.2, WOOD, z=1.1)
    c.capsule(x0 + 4, -base_h - 1, x0 + w * 0.3, -h + 2, 0.9, 0.9, WOOD, z=1.05)
    c.capsule(x1 - 4, -base_h - 1, x1 - w * 0.3, -h + 2, 0.9, 0.9, WOOD, z=1.05)
    # telhado
    c.poly([(x0 - 6, -h + 1), (0, -h - roof_h), (x1 + 6, -h + 1), (x1 + 4, -h + 4), (x0 - 4, -h + 4)], ROOF, z=2.0, bevel=3.0)
    for k in range(1, 5):
        y = -h - roof_h + roof_h * k / 5
        half = (w / 2 + 6) * k / 5
        c.line(-half + 1, y, half - 1, y, hexc("#141012"))
    if chimney:
        cx = x1 * 0.45
        c.poly(rect_poly(cx - 3, -h - roof_h * 0.85, cx + 3, -h - roof_h * 0.35), STONE_W, z=1.8, bevel=1.2)
    # porta
    dx = x0 + w * 0.22
    c.poly([(dx - 5, 0), (dx - 5, -13), (dx - 3, -16), (dx + 3, -16), (dx + 5, -13), (dx + 5, 0)], WOOD_D, z=1.5, bevel=1.5)
    c.dot(dx + 3, -7, hexc("#c89a48"))
    # janelas
    window(c, x1 - w * 0.36, -base_h - 12, x1 - w * 0.18, -base_h - 4, lit)
    window(c, x1 - w * 0.36, -11, x1 - w * 0.2, -4, lit and seed % 2 == 0)
    if sign == "map":
        # placa pendurada da cartógrafa (rosa dos ventos)
        sx = x0 - 4
        c.capsule(sx, -h + 6, sx + 10, -h + 6, 0.8, 0.8, IRON, z=3.0)
        c.poly(rect_poly(sx - 5, -h + 8, sx + 5, -h + 18), WOOD, z=3.0, bevel=1.2)
        c.line(sx, -h + 9, sx, -h + 17, hexc("#e8dcc0"))
        c.line(sx - 4, -h + 13, sx + 4, -h + 13, hexc("#e8dcc0"))
        c.dot(sx, -h + 10, hexc("#d04030"))


@decor("house", 104, 118, light=[1.9, 1.1, 0.5], light_at=[18, -48], light_energy=0.55, light_scale=0.55, glow=True)
def d_house(c):
    _house(c, 76, 52, 28, seed=0)


@decor("house_b", 96, 110, light=[1.9, 1.1, 0.5], light_at=[16, -44], light_energy=0.5, light_scale=0.5, glow=True)
def d_house_b(c):
    _house(c, 66, 46, 30, seed=1)


@decor("house_mira", 104, 118, light=[1.9, 1.1, 0.5], light_at=[18, -48], light_energy=0.55, light_scale=0.55, glow=True, flip=False)
def d_house_mira(c):
    _house(c, 76, 52, 28, sign="map", seed=2)


@decor("well", 84, 72, flip=False)
def d_well(c):
    # dois postes de madeira dos lados do buraco (o buraco é do terreno),
    # telhadinho, sarilho com corda e balde
    for x in (-30, 30):
        c.poly(rect_poly(x - 2.5, -46, x + 2.5, 0), WOOD, z=1.0, bevel=1.2)
        c.poly(rect_poly(x - 5, -6, x + 5, 0), STONE_W, z=1.5, bevel=1.5)
    c.poly([(-40, -44), (0, -64), (40, -44), (38, -41), (-38, -41)], ROOF, z=2.0, bevel=2.5)
    c.capsule(-28, -36, 28, -36, 1.6, 1.6, WOOD_D, z=2.2)
    c.capsule(28, -36, 32, -31, 0.9, 0.9, IRON, z=2.3)
    c.line(0, -35, 0, -12, hexc("#6a5a40"))
    c.poly([(-4, -12), (4, -12), (3, -5), (-3, -5)], WOOD, z=2.4, bevel=1.0)


@decor("dead_tree", 110, 150)
def d_dead_tree(c):
    rng = np.random.default_rng(7)
    c.poly([(-9, 0), (-7, -40), (-4, -70), (3, -72), (6, -40), (10, 0), (16, 2), (-16, 2)], BARK, z=0.0, bevel=5.0, folds=(0.0, 0.8, 0.0, 0.15))

    def branch(x, y, ang, ln, r, depth):
        if depth == 0 or ln < 4:
            return
        x2 = x + math.cos(ang) * ln
        y2 = y + math.sin(ang) * ln
        c.capsule(x, y, x2, y2, r, r * 0.6, BARK, z=0.5 - depth * 0.01)
        for s in (-1, 1):
            if rng.random() < 0.85:
                branch(x2, y2, ang + s * rng.uniform(0.3, 0.7), ln * rng.uniform(0.55, 0.75), r * 0.65, depth - 1)
    branch(-2, -62, -math.pi / 2 - 0.5, 34, 4.0, 4)
    branch(2, -64, -math.pi / 2 + 0.45, 30, 3.6, 4)
    branch(-5, -40, math.pi + 0.35, 22, 3.0, 3)
    branch(5, -34, -0.3, 20, 2.8, 3)


@decor("fence", 44, 30)
def d_fence(c):
    for x, h, a in [(-17, 22, -0.08), (-5, 18, 0.05), (7, 20, 0.12), (17, 13, -0.2)]:
        c.poly([(x - 2, 0), (x - 2 + math.sin(a) * h, -h + 2), (x + math.sin(a) * h, -h), (x + 2 + math.sin(a) * h, -h + 2), (x + 2, 0)], WOOD, z=1.0, bevel=1.2)
    c.capsule(-19, -14, 12, -12, 1.2, 1.2, WOOD_D, z=1.5)
    c.capsule(-19, -6, 19, -5, 1.2, 1.2, WOOD_D, z=1.5)


@decor("tombstone", 26, 30)
def d_tombstone(c):
    c.poly([(-8, 0), (-8, -16), (-6, -21), (-2, -24), (2, -24), (6, -21), (8, -16), (8, 0)], STONE, z=1.0, bevel=2.5)
    c.line(-3, -17, 2, -8, hexc("#14121a"))
    c.line(2, -8, 0, -3, hexc("#14121a"))
    c.line(-4, -19, 4, -19, hexc("#2a2832"))
    c.poly(rect_poly(-10, -3, 10, 0), MOSS, z=1.5, bevel=1.0)


@decor("altar", 46, 30, flip=False)
def d_altar(c):
    c.poly(rect_poly(-18, -16, 18, 0), STONE, z=0.5, bevel=2.0)
    c.poly(rect_poly(-21, -19, 21, -15), STONE, z=1.0, bevel=1.5)
    c.poly([(-15, -15), (15, -15), (13, -2), (5, -5), (-3, -2), (-13, -4)], CLOTH_R, z=1.5, bevel=1.5)
    c.line(-10, -12, -10, -6, hexc("#e8b050"))
    c.line(10, -12, 10, -6, hexc("#e8b050"))


@decor("candles", 24, 26, glow=True, light=[2.0, 1.2, 0.5], light_at=[0, -18], light_energy=0.6, light_scale=0.45)
def d_candles(c):
    for x, h in [(-6, 10), (0, 15), (6, 8)]:
        c.capsule(x, -1, x, -h, 1.8, 1.8, CANDLE, z=1.0)
        flame(c, x, -h - 1.5, 2.6, 5.0, t=(x + 6) / 13.0)
    c.poly([(-9, 0), (-8, -2), (8, -2), (9, 0)], CANDLE, z=1.2, bevel=0.8)


@decor("broken_statue", 56, 84)
def d_broken_statue(c):
    # um Lampadeiro de pedra (cabeça-lanterna), braço erguido quebrado
    c.poly(rect_poly(-14, -10, 14, 0), STONE, z=0.0, bevel=2.0)
    c.poly([(-11, -10), (11, -10), (8, -38), (-8, -38)], STONE, z=0.5, bevel=3.0)
    c.ellipse(0, -48, 11, 10, STONE, z=1.0)
    c.capsule(-9, -40, 9, -40, 1.5, 1.5, STONE, z=1.2)
    c.capsule(-9, -56, 9, -56, 1.5, 1.5, STONE, z=1.2)
    c.ellipse(0, -59, 6, 3, STONE, z=1.3)
    c.capsule(8, -34, 16, -46, 3.0, 2.6, STONE, z=1.4)
    c.poly([(14, -48), (19, -47), (17, -52)], STONE, z=1.5, bevel=1.0)
    # rachadura e pedaço caído
    c.line(-4, -52, 2, -44, hexc("#14121a"))
    c.poly([(18, -4), (26, -6), (24, 0), (16, 0)], STONE, z=0.8, bevel=1.5)
    c.poly(rect_poly(-16, -3, 16, 0), MOSS, z=1.6, bevel=1.0)


@decor("banner", 24, 60, ox=12, oy=2, hang=True, sway=0.035)
def d_banner(c):
    c.capsule(-11, 2, 11, 2, 1.2, 1.2, IRON, z=2.0)
    c.poly([(-9, 3), (9, 3), (9, 44), (4, 52), (1, 45), (-3, 55), (-9, 47)], CLOTH_R, z=1.0, bevel=2.0, folds=(1.0, 0.8, 0.0, 0.2))
    # emblema: a chama dos Lampadeiros
    c.poly([(0, 16), (4, 25), (2, 31), (0, 28), (-2, 31), (-4, 25)], Mat("#d8a040", n=4, rim=0.4, outline="#3a2008"), z=1.2, bevel=1.0)


@decor("bell", 56, 60, ox=28, oy=2, hang=True, sway=0.02, flip=False)
def d_bell(c):
    c.capsule(-24, 2, 24, 2, 2.2, 2.2, WOOD_D, z=0.5)
    c.capsule(0, 2, 0, 9, 2.0, 2.0, IRON, z=1.0)
    c.poly([(-6, 9), (6, 9), (11, 22), (15, 36), (18, 40), (-18, 40), (-15, 36), (-11, 22)], BRONZE, z=1.5, bevel=5.0)
    c.capsule(-18, 40, 18, 40, 2.0, 2.0, BRONZE, z=1.6)
    c.ellipse(0, 44, 3, 3, IRON, z=1.4)
    # cinza acumulada no ombro do sino
    c.poly([(-8, 11), (8, 11), (6, 14), (-6, 14)], Mat("#9a948c", n=3, rim=0.2, outline="#3a3630"), z=1.7, bevel=0.8)


@decor("bench", 44, 22)
def d_bench(c):
    c.poly(rect_poly(-19, -10, 19, -7), WOOD, z=1.0, bevel=1.0)
    for x in (-15, 15):
        c.poly(rect_poly(x - 2, -8, x + 2, 0), WOOD_D, z=0.8, bevel=1.0)
    c.poly(rect_poly(-19, -18, 19, -15), WOOD, z=0.6, bevel=1.0)
    c.capsule(-17, -15, -17, -9, 1.0, 1.0, WOOD_D, z=0.7)
    c.capsule(17, -15, 17, -9, 1.0, 1.0, WOOD_D, z=0.7)


@decor("crates", 44, 40)
def d_crates(c):
    c.poly(rect_poly(-18, -16, -2, 0), WOOD, z=1.0, bevel=1.5)
    c.poly(rect_poly(0, -12, 12, 0), WOOD, z=1.1, bevel=1.5)
    c.poly(rect_poly(-14, -30, 0, -16), WOOD, z=0.9, bevel=1.5)
    for (x0, y0, x1, y1) in [(-18, -16, -2, 0), (0, -12, 12, 0), (-14, -30, 0, -16)]:
        c.line(x0 + 1, y0 + 1, x1 - 1, y1 - 1, hexc("#1e140e"))
    c.ellipse(15, -8, 5, 8, WOOD_D, z=1.3)
    c.capsule(10.5, -12, 19.5, -12, 0.7, 0.7, IRON, z=1.4)
    c.capsule(10.5, -4, 19.5, -4, 0.7, 0.7, IRON, z=1.4)


@decor("rubble", 40, 20)
def d_rubble(c):
    for (x, y, rx, ry) in [(-10, -4, 7, 4.5), (2, -5, 8, 5.5), (12, -3, 5, 3.5), (-3, -9, 5, 4)]:
        c.ellipse(x, y, rx, ry, STONE, z=1.0 + y * -0.01)


@decor("lamppost_broken", 40, 72)
def d_lamppost_broken(c):
    c.poly(rect_poly(-5, -6, 5, 0), STONE, z=0.5, bevel=1.5)
    c.capsule(0, -6, 2, -38, 1.8, 1.6, IRON, z=1.0)
    c.capsule(2, -38, 14, -46, 1.5, 1.3, IRON, z=1.1)
    c.ellipse(15, -40, 4.5, 5, GLASS_OFF, z=1.2)
    c.line(12, -43, 17, -37, hexc("#6a6070"))


def _lamp(c, lit):
    # poste de ferro fundido com a lanterna no alto: a mesma família da
    # cabeça do Lume (argola, grade, vidro)
    c.poly(rect_poly(-6, -6, 6, 0), STONE, z=0.5, bevel=1.5)
    c.poly([(-3.5, -6), (3.5, -6), (2.4, -44), (-2.4, -44)], IRON, z=1.0, bevel=1.2)
    c.capsule(-4, -44, 4, -44, 1.3, 1.3, IRON, z=1.2)
    c.ellipse(0, -52, 6.4, 7.0, GLASS_ON if lit else GLASS_OFF, z=1.3)
    for x in (-6.2, 6.2):
        c.capsule(x * 0.9, -58, x, -52, 0.7, 0.7, IRON, z=1.5)
        c.capsule(x, -52, x * 0.9, -46, 0.7, 0.7, IRON, z=1.5)
    c.capsule(-5.4, -59, 5.4, -59, 1.1, 1.1, IRON, z=1.6)
    c.ellipse(0, -61, 4, 1.8, IRON, z=1.6)
    c.capsule(0, -62, 0, -64, 1.0, 0.8, IRON, z=1.6)
    # argola
    for k in range(10):
        a0, a1 = k / 10 * math.tau, (k + 1) / 10 * math.tau
        c.capsule(math.cos(a0) * 1.8, -66 + math.sin(a0) * 1.8, math.cos(a1) * 1.8, -66 + math.sin(a1) * 1.8, 0.5, 0.5, IRON, z=1.7)
    if lit:
        flame(c, 0, -48, 5.4, 9.0, t=0.4)


@decor("lamp_off", 24, 78, glow=False, flip=False)
def d_lamp_off(c):
    _lamp(c, False)


@decor("lamp_on", 24, 78, glow=True, flip=False)
def d_lamp_on(c):
    _lamp(c, True)


def _brazier(c, lit):
    c.poly([(-9, 0), (-6, -4), (6, -4), (9, 0)], STONE, z=0.5, bevel=1.5)
    c.poly([(-3, -4), (3, -4), (2.5, -14), (-2.5, -14)], STONE, z=0.6, bevel=1.2)
    for x in (-8, 8):
        c.capsule(x * 0.3, -12, x, -22, 0.9, 0.9, IRON, z=0.8)
    c.poly([(-13, -24), (13, -24), (10, -16), (-10, -16)], IRON, z=1.0, bevel=2.0)
    c.capsule(-13, -24, 13, -24, 1.2, 1.2, IRON, z=1.2)
    for (x, r) in [(-6, 3.4), (0, 3.8), (6, 3.2), (-3, 3.0), (3, 3.2)]:
        c.ellipse(x, -25.5, r, 2.2, COAL, z=1.1)
    if lit:
        flame(c, -3, -27, 7, 14, t=0.1, lean=-0.4)
        flame(c, 3, -27, 7, 17, t=0.6, lean=0.3)
        flame(c, 0, -27, 9, 22, t=0.35)
    else:
        for x in (-5, 1, 6):
            c.dot(x, -26, hexc("#6a2a14"))


@decor("brazier_cold", 34, 70, flip=False)
def d_brazier_cold(c):
    _brazier(c, False)


@decor("brazier_lit", 34, 70, glow=True, flip=False)
def d_brazier_lit(c):
    _brazier(c, True)


# ===========================================================================
# GALERIAS — pedra azulada dos Lampadeiros
# ===========================================================================

@decor("pillar", 44, 200)
def d_pillar(c):
    c.poly(rect_poly(-18, -10, 18, 0), STONE_B, z=0.5, bevel=2.5)
    c.poly(rect_poly(-14, -170, 14, -10), STONE_B, z=0.3, bevel=5.0, folds=(1.0, 0.9, 0.0, 0.25))
    c.poly(rect_poly(-18, -182, 18, -170), STONE_B, z=0.6, bevel=2.5)
    c.poly([(-20, -190), (20, -190), (18, -182), (-18, -182)], STONE_B, z=0.7, bevel=2.0)
    for y in range(-160, -12, 22):
        c.line(-13, y, 13, y, hexc("#141a26"))
    c.line(-6, -120, 3, -92, hexc("#0c1018"))
    c.line(3, -92, -2, -70, hexc("#0c1018"))


@decor("arch", 110, 120, flip=False)
def d_arch(c):
    for x in (-44, 44):
        c.poly(rect_poly(x - 8, -84, x + 8, 0), STONE_B, z=0.5, bevel=3.0)
    pts_o, pts_i = [], []
    for k in range(17):
        a = math.pi + k / 16 * math.pi
        pts_o.append((math.cos(a) * 52, -84 + math.sin(a) * 30))
        pts_i.append((math.cos(a) * 36, -84 + math.sin(a) * 20))
    c.poly(pts_o + pts_i[::-1], STONE_B, z=0.6, bevel=3.5)
    c.poly([(-6, -114), (6, -114), (4, -100), (-4, -100)], STONE_B, z=0.8, bevel=1.5)


@decor("chain", 12, 100, ox=6, oy=2, hang=True, sway=0.04)
def d_chain(c):
    for k in range(13):
        y = 3 + k * 6.5
        if k % 2 == 0:
            c.ellipse(0, y, 1.6, 3.4, IRON, z=1.0 + k * 0.01)
        else:
            c.ellipse(0, y, 0.9, 3.2, IRON, z=1.0 + k * 0.01)
    c.capsule(0, 88, 3, 94, 1.0, 1.0, IRON, z=1.5)
    c.capsule(3, 94, -1, 97, 1.0, 1.0, IRON, z=1.5)


def _hanging_lamp(c, lit):
    for k in range(6):
        c.ellipse(0, 3 + k * 6.5, 1.3 if k % 2 == 0 else 0.8, 3.0, IRON, z=1.0)
    c.ellipse(0, 46, 5.4, 6.2, GLASS_ON if lit else GLASS_OFF, z=1.3)
    c.capsule(-4.6, 40, 4.6, 40, 1.0, 1.0, IRON, z=1.5)
    c.capsule(-4.6, 52, 4.6, 52, 1.0, 1.0, IRON, z=1.5)
    for x in (-5.4, 5.4):
        c.capsule(x, 40, x * 1.05, 52, 0.6, 0.6, IRON, z=1.6)
    c.ellipse(0, 38, 3.4, 1.6, IRON, z=1.6)
    if lit:
        flame(c, 0, 50, 4.6, 7.0, t=0.2)


@decor("hanging_lamp", 20, 60, ox=10, oy=2, hang=True, sway=0.05, glow=True, light=[2.0, 1.1, 0.5], light_at=[0, 70], light_energy=0.75, light_scale=0.7)
def d_hanging_lamp(c):
    _hanging_lamp(c, True)


@decor("hanging_lamp_off", 20, 60, ox=10, oy=2, hang=True, sway=0.05)
def d_hanging_lamp_off(c):
    _hanging_lamp(c, False)


@decor("bones", 48, 26)
def d_bones(c):
    # um Lampadeiro que não voltou: a lanterna vazia caída entre os ossos
    c.capsule(-18, -3, -4, -2, 1.6, 1.4, BONE, z=1.0)
    c.capsule(4, -2, 16, -5, 1.4, 1.4, BONE, z=1.0)
    c.capsule(-10, -6, 0, -3, 1.2, 1.2, BONE, z=1.1)
    c.ellipse(-19, -3.5, 2.2, 2.0, BONE, z=1.2)
    c.ellipse(16.5, -5.5, 2.0, 1.8, BONE, z=1.2)
    c.ellipse(6, -8, 6.0, 6.4, GLASS_OFF, z=1.4, ang=0.5)
    for (a, b) in [((1, -13), (10, -3)), ((-0.5, -11), (5, -1.5))]:
        c.capsule(a[0], a[1], b[0], b[1], 0.7, 0.7, IRON, z=1.5)
    c.line(4, -12, 8, -6, hexc("#6a6070"))


@decor("statue", 90, 190, flip=False)
def d_statue(c):
    # o grande Lampadeiro de pedra: ergue a lanterna acima da cabeça
    c.poly(rect_poly(-30, -18, 30, 0), STONE_B, z=0.2, bevel=3.0)
    c.poly(rect_poly(-24, -26, 24, -18), STONE_B, z=0.3, bevel=2.0)
    c.poly([(-20, -26), (20, -26), (26, -90), (14, -110), (-14, -110), (-22, -90)], STONE_B, z=0.5, bevel=6.0, folds=(1.0, 0.5, 0.0, 0.2))
    c.ellipse(0, -128, 20, 18, STONE_B, z=1.0)
    c.capsule(-17, -113, 17, -113, 2.4, 2.4, STONE_B, z=1.2)
    c.capsule(-15, -142, 15, -142, 2.4, 2.4, STONE_B, z=1.2)
    c.ellipse(0, -147, 11, 5, STONE_B, z=1.3)
    # braço erguido com a lanterna
    c.capsule(18, -100, 30, -140, 5.0, 4.0, STONE_B, z=1.4)
    c.capsule(30, -140, 30, -156, 1.2, 1.2, IRON, z=1.5)
    c.ellipse(30, -164, 6, 7, GLASS_OFF, z=1.6)
    c.capsule(24.5, -170, 35.5, -170, 1.0, 1.0, IRON, z=1.7)
    c.capsule(24.5, -158, 35.5, -158, 1.0, 1.0, IRON, z=1.7)
    c.line(-10, -60, -2, -40, hexc("#0c1018"))
    c.line(6, -130, 12, -118, hexc("#0c1018"))


@decor("cage", 30, 70, ox=15, oy=2, hang=True, sway=0.04)
def d_cage(c):
    for k in range(4):
        c.ellipse(0, 3 + k * 6.5, 1.3 if k % 2 == 0 else 0.8, 3.0, IRON, z=1.0)
    c.ellipse(0, 30, 11, 3, IRON, z=1.2)
    for x in (-10, -5, 0, 5, 10):
        c.capsule(x * 0.9, 31, x, 60, 0.7, 0.7, IRON, z=1.3)
    c.ellipse(0, 61, 11, 2.5, IRON, z=1.4)
    c.ellipse(-3, 57, 4, 2, BONE, z=1.25)


@decor("stained_glass", 60, 110, glow=True, light=[1.4, 1.0, 0.7], light_at=[0, -55], light_energy=0.6, light_scale=0.9, flip=False)
def d_stained_glass(c):
    pts = [(-22, 0), (-22, -70), (-16, -88), (0, -98), (16, -88), (22, -70), (22, 0)]
    c.poly([(x * 1.15, y * 1.04 + 2) for (x, y) in pts], STONE_B, z=0.5, bevel=3.0)
    m = c._inside_poly(pts)
    col = np.zeros(c.X.shape + (4,))
    # vitral: chama dourada no centro sobre azul-escuro, faixas de chumbo
    r = np.hypot(c.X / 22.0, (c.Y + 50) / 50.0)
    base = np.array(hexc("#2a3a7a")[:3], dtype=float)
    gold = np.array(hexc("#ffb040")[:3], dtype=float)
    red = np.array(hexc("#c83a2a")[:3], dtype=float)
    t = np.clip(1.2 - r, 0, 1)[..., None]
    rgb = base * (1 - t) + gold * t
    flame_m = (np.abs(c.X) < (1 - np.clip((-c.Y - 30) / 45, 0, 1)) * 9) & (c.Y < -30) & (c.Y > -78)
    rgb[flame_m] = red * 0.5 + gold * 0.5
    col[..., :3] = rgb
    col[..., 3] = 255
    c.over[m] = col[m]
    c.over_glow[m] = col[m] * 0.55
    for x in (-11, 0, 11):
        c.line(x, -92, x, 0, hexc("#0c0e18"))
    for y in (-66, -40, -18):
        c.line(-21, y, 21, y, hexc("#0c0e18"))


# ===========================================================================
# BOSQUE — raízes, musgo e fungos que brilham
# ===========================================================================

@decor("roots", 60, 110, ox=30, oy=2, hang=True, sway=0.015)
def d_roots(c):
    rng = np.random.default_rng(3)
    for k in range(5):
        x = -20 + k * 10 + rng.uniform(-3, 3)
        ln = rng.uniform(50, 100)
        pts = [(x, 0)]
        for j in range(1, 6):
            pts.append((x + math.sin(j * 1.3 + k) * 5, ln * j / 5))
        c.ribbon(pts, [6 - k % 2, 5, 4, 3, 2, 1][:len(pts)], ROOT, z=1.0 + k * 0.1)


@decor("vines", 30, 100, ox=15, oy=2, hang=True, sway=0.05)
def d_vines(c):
    for k, x in enumerate((-6, 2, 8)):
        ln = 60 + k * 14
        pts = [(x + math.sin(j * 0.9 + k) * 3, ln * j / 8) for j in range(9)]
        c.ribbon(pts, [2.4] * 9, MOSS, z=1.0 + k * 0.1)
        for j in range(2, 9, 2):
            px, py = pts[j]
            c.ellipse(px + 2.5, py, 2.6, 1.4, MOSS, z=1.3, ang=0.5)


@decor("fungus", 36, 30, glow=True, light=[0.4, 1.4, 1.3], light_at=[0, -12], light_energy=0.45, light_scale=0.4)
def d_fungus(c):
    for (x, h, r) in [(-8, 8, 5), (1, 13, 7), (9, 6, 4)]:
        c.capsule(x, 0, x, -h, 1.4, 1.2, FUNGUS_STEM, z=1.0)
        c.ellipse(x, -h - 1.5, r, r * 0.55, FUNGUS, z=1.2)
        for d in (-0.4, 0.3):
            c.dot(x + r * d, -h - 2.4, hexc("#d0fff4"), glow=True)


@decor("big_mushroom", 70, 120, glow=True, light=[0.5, 1.2, 1.4], light_at=[0, -85], light_energy=0.7, light_scale=0.8)
def d_big_mushroom(c):
    c.poly([(-5, 0), (-4, -50), (-3, -80), (3, -80), (4, -50), (6, 0), (11, 2), (-10, 2)], FUNGUS_STEM, z=0.5, bevel=3.0)
    c.ellipse(0, -86, 30, 16, FUNGUS, z=1.0)
    c.poly([(-29, -84), (29, -84), (24, -78), (-24, -78)], Mat(["#0a2020", "#123030", "#1c4444"], rim=0.2, outline="#030a0a"), z=0.9, bevel=1.0)
    rng = np.random.default_rng(5)
    for k in range(9):
        a = rng.uniform(math.pi * 1.1, math.pi * 1.9)
        c.dot(math.cos(a) * rng.uniform(8, 25), -86 + math.sin(a) * rng.uniform(4, 12), hexc("#d8fff8"), glow=True)


@decor("grass", 40, 30)
def d_grass(c):
    rng = np.random.default_rng(11)
    for k in range(9):
        x = -16 + k * 4 + rng.uniform(-1, 1)
        h = rng.uniform(10, 24)
        lean = rng.uniform(-6, 6)
        c.ribbon([(x, 0), (x + lean * 0.4, -h * 0.5), (x + lean, -h)], [3.0, 2.0, 0.6], MOSS, z=1.0 + k * 0.01)


@decor("tree", 150, 260, flip=True)
def d_tree(c):
    # tronco gigante do Bosque (fundo): casca retorcida e raízes
    c.poly([(-22, 0), (-18, -120), (-24, -200), (-10, -250), (12, -250), (22, -200), (18, -120), (24, 0), (40, 4), (-42, 4)], BARK, z=0.0, bevel=10.0, folds=(0.0, 0.5, 0.0, 0.25))
    for (x0, x1, y) in [(-22, -60, 0), (20, 62, 2), (-18, -44, -10)]:
        c.capsule(x0, y - 10, x1, y, 7, 3, BARK, z=0.2)
    c.ellipse(-4, -150, 6, 10, Mat(["#040303", "#0a0706", "#120e0c"], rim=0.0, outline="#020202"), z=0.4)


@decor("root_cage", 44, 56, flip=False)
def d_root_cage(c):
    # gaiola de raízes da Rainha: raízes grossas curvadas em volta de alguém
    for k, x in enumerate((-16, -8, 0, 8, 16)):
        pts = [(x * 0.6, -48), (x * 0.95, -36), (x * 1.05, -20), (x, 0)]
        c.ribbon(pts, [2.4, 3.2, 3.4, 3.8], ROOT, z=2.0 + k * 0.01)
    c.ellipse(0, -48, 12, 4, ROOT, z=2.2)
    c.ribbon([(-18, -2), (0, 1), (18, -2)], [3, 4, 3], ROOT, z=2.3)
    for (x, y) in [(-10, -30), (6, -14), (12, -38)]:
        c.ellipse(x, y, 2.4, 1.4, MOSS, z=2.4, ang=0.6)


@decor("crystals", 40, 40, glow=True, light=[0.5, 0.8, 1.6], light_at=[0, -16], light_energy=0.5, light_scale=0.5)
def d_crystals(c):
    for (x, h, a) in [(-8, 18, -0.3), (0, 28, 0.05), (8, 14, 0.35)]:
        tip = (x + math.sin(a) * h, -h)
        c.poly([(x - 4, 0), (x - 3.5 + math.sin(a) * h * 0.8, -h * 0.8), tip, (x + 3.5 + math.sin(a) * h * 0.8, -h * 0.8), (x + 4, 0)], CRYSTAL, z=1.0 + x * 0.01, bevel=2.0)


# ===========================================================================
# Saída
# ===========================================================================

def render(name):
    w, h, ox, oy, fn, meta = DECOR[name]
    c = Canvas(w, h, ox, oy)
    fn(c)
    img, glow = c.render(contact=True)
    os.makedirs(OUT, exist_ok=True)
    save(img, os.path.join(OUT, name + ".png"))
    gpath = os.path.join(OUT, name + "_glow.png")
    has_glow = bool(glow[..., 3].any())
    if has_glow:
        save(glow, gpath)
    elif os.path.exists(gpath):
        os.remove(gpath)
    entry = {"size": [c.w, c.h], "origin": [c.ox, c.oy], "glow": has_glow}
    for k, v in meta.items():
        if k == "light_at":
            entry[k] = [round(v[0] * RES, 1), round(v[1] * RES, 1)]
        elif k == "glow":
            continue
        else:
            entry[k] = v
    return entry, img, glow


def main():
    only = sys.argv[1:]
    data = {}
    if os.path.exists(META):
        with open(META, encoding="utf-8") as f:
            data = json.load(f)
    data["_doc"] = "Gerado por tools/build_decor.py: cenografia (origin = pés ou ponto de pendurar, em px de arte)."
    sheet = []
    for name in DECOR:
        if only and name not in only:
            continue
        entry, img, glow = render(name)
        data[name] = entry
        sheet.append((name, img, glow))
        print("decor", name, entry["size"])
    with open(META, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    if PREVIEW and sheet:
        os.makedirs(PREVIEW, exist_ok=True)
        cols = 8
        cw = max(i.shape[1] for _, i, _ in sheet) + 8
        ch = max(i.shape[0] for _, i, _ in sheet) + 8
        rows = (len(sheet) + cols - 1) // cols
        P = Image.new("RGBA", (cols * cw, rows * ch), (26, 28, 36, 255))
        for k, (_, img, glow) in enumerate(sheet):
            x, y = (k % cols) * cw + 4, (k // cols) * ch + 4
            base = np.array(img).astype(float)
            g = glow.astype(float)
            base[..., :3] = np.clip(base[..., :3] + g[..., :3] * (g[..., 3:4] / 255.0) * 0.6, 0, 255)
            P.alpha_composite(Image.fromarray(base.astype(np.uint8), "RGBA"), (x, y))
        P = P.resize((P.width * 2, P.height * 2), Image.NEAREST)
        P.save(os.path.join(PREVIEW, "decor.png"))


if __name__ == "__main__":
    main()
