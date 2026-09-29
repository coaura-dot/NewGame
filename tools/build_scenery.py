#!/usr/bin/env python3
"""Pinta os cenários de fundo em pixel art (camadas com parallax) por estilo.

Inspiração: Kingdom Two Crowns (silhuetas em camadas, céu luminoso,
perspectiva atmosférica), Blasphemous (arquitetura gótica contra a luz) e
Dead Cells (cores saturadas, borda iluminada). Tudo é gerado por código
(ruído periódico, formas simples, pontilhado ordenado nos degradês) e as
camadas emendam sem costura na horizontal.

Saída por estilo em assets/art/scenery/<estilo>/:
  sky.png   256x144  céu fixo (degradê pontilhado, sol/lua, estrelas)
  far.png   512xH    montanhas/horizonte (mais claro, "longe")
  mid.png   512xH    silhuetas do bioma (castelo, árvores, dunas, ilhas...)
  near.png  512xH    primeiro plano de fundo (mais escuro, mais perto)
e data/scenery.json com cores, fatores de parallax e o "evento" animado de
cada estilo (pássaros, titã ao fundo, catapultas, baleia do céu...).

Uso: python3 tools/build_scenery.py [estilo ...]      (requer numpy, pillow)
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "art", "scenery")
DATA = os.path.join(ROOT, "data", "scenery.json")
W = 512
SKY_W, SKY_H = 256, 144

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def lighten(c, t):
    return mix(c, (255, 255, 255), t)


def darken(c, t):
    return mix(c, (0, 0, 0), t)


# ---------------------------------------------------------------------------
# Ruído periódico (emenda em W)
# ---------------------------------------------------------------------------

def pnoise(n, cells, seed, octaves=4, persistence=0.5):
    """Ruído de valor 1D periódico de comprimento n. Retorna array 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    amp = 1.0
    total = 0.0
    c = cells
    for _ in range(octaves):
        lattice = rng.random(c)
        x = np.arange(n) / n * c
        i0 = np.floor(x).astype(int) % c
        i1 = (i0 + 1) % c
        f = x - np.floor(x)
        f = (1 - np.cos(f * math.pi)) * 0.5
        out += amp * (lattice[i0] * (1 - f) + lattice[i1] * f)
        total += amp
        amp *= persistence
        c *= 2
    return out / total


# ---------------------------------------------------------------------------
# Céu
# ---------------------------------------------------------------------------

def sky(style):
    s = style["sky"]
    stops = [rgb(c) for c in s["colors"]]
    # expande as paradas em faixas (8 por segmento): pixel art em faixas, com
    # pontilhado só nas 3 linhas de transição entre uma faixa e a próxima
    bands = []
    for i in range(len(stops) - 1):
        for k in range(6):
            bands.append(mix(stops[i], stops[i + 1], k / 6))
    bands.append(stops[-1])
    img = Image.new("RGB", (SKY_W, SKY_H))
    px = img.load()
    nb = len(bands)
    band_h = SKY_H / nb
    for y in range(SKY_H):
        b = min(int(y / band_h), nb - 1)
        into = y - b * band_h
        for x in range(SKY_W):
            c = bands[b]
            if b + 1 < nb and into > band_h - 3:
                f = (into - (band_h - 3)) / 3.0
                if f > BAYER[y % 4, x % 4]:
                    c = bands[b + 1]
            px[x, y] = c
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(style["seed"])
    for _ in range(s.get("stars", 0)):
        x, y = int(rng.integers(0, SKY_W)), int(rng.integers(0, int(SKY_H * 0.6)))
        b = int(rng.integers(150, 256))
        px[x, y] = (b, b, min(255, b + 20))
        if rng.random() < 0.08 and 0 < x < SKY_W - 1 and 0 < y < SKY_H - 1:
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                px[x + dx, y + dy] = mix(px[x + dx, y + dy], (b, b, 255), 0.5)
    if "sun" in s:
        sx, sy, r = s["sun"]["pos"][0], s["sun"]["pos"][1], s["sun"]["r"]
        core = rgb(s["sun"]["color"])
        halo = rgb(s["sun"].get("halo", s["sun"]["color"]))
        # halo: dois anéis lisos cada vez mais transparentes
        glow = s["sun"].get("glow", 0.35)
        for ring, a in [(int(r * 2.4), glow * 0.35), (int(r * 1.6), glow * 0.7)]:
            for yy in range(sy - ring, sy + ring + 1):
                for xx in range(sx - ring, sx + ring + 1):
                    if 0 <= xx < SKY_W and 0 <= yy < SKY_H and math.hypot(xx - sx, yy - sy) <= ring:
                        px[xx, yy] = mix(px[xx, yy], halo, a)
        d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=core)
        if s["sun"].get("moon"):
            # crateras e sombra da lua
            for cx, cy, cr in [(-3, -2, 2), (2, 3, 1), (4, -3, 1)]:
                d.ellipse([sx + cx - cr, sy + cy - cr, sx + cx + cr, sy + cy + cr], fill=darken(core, 0.12))
    # faixas de nuvem distantes (estáticas, bem sutis)
    for band in s.get("bands", []):
        y0, col, amt = band
        col = rgb(col)
        nz = pnoise(SKY_W, 8, style["seed"] + y0, 3)
        for x in range(SKY_W):
            h = int(nz[x] * 5)
            for yy in range(y0 - h, y0 + 1):
                if 0 <= yy < SKY_H and amt > BAYER[yy % 4, x % 4]:
                    px[x, yy] = mix(px[x, yy], col, 0.6)
    return img


# ---------------------------------------------------------------------------
# Primitivas das camadas (RGBA, fundo transparente)
# ---------------------------------------------------------------------------

def layer(h=144):
    return Image.new("RGBA", (W, h), (0, 0, 0, 0))


def haze(img, fog, y0, y1, t0, t1, steps=6):
    """Desbota os pixels opacos para a cor da névoa de cima (y0, t0) para
    baixo (y1, t1) em faixas lisas de 2 linhas (perspectiva atmosférica)."""
    px = img.load()
    fog = rgb(fog)
    for y in range(max(0, y0), img.height):
        k = min(max(((y // 2) * 2 - y0) / max(1, (y1 - y0)), 0.0), 1.0)
        t = round((t0 + (t1 - t0) * k) * steps) / steps
        for x in range(img.width):
            c = px[x, y]
            if c[3] == 0:
                continue
            px[x, y] = mix(c[:3], fog, t) + (c[3],)


def reflect(img, water_y, water, alpha=0.55):
    """Água com reflexo (Kingdom Two Crowns): espelha o que está acima da
    linha d'água, escurece/tinge e quebra em linhas horizontais (ondas)."""
    px = img.load()
    water = rgb(water)
    h = img.height
    for y in range(water_y, h):
        src = water_y - (y - water_y) - 1
        shift = int(round(math.sin(y * 0.9) * 1.5))
        for x in range(img.width):
            base = water
            if src >= 0:
                c = px[(x + shift) % img.width, src]
                if c[3] > 0 and (y - water_y) % 3 != 2:
                    base = mix(water, c[:3], alpha * (1 - (y - water_y) / (h - water_y + 8)))
            px[x, y] = base + (255,)
    for x in range(img.width):
        if (x // 3) % 4 != 0:
            px[x, water_y] = lighten(water, 0.35) + (255,)


def ridge(img, base, amp, cells, seed, color, rim=None, sun_dir=1, snow=None, octaves=4, sharp=False):
    """Serra de montanhas/colinas preenchida até o fundo. Retorna alturas."""
    h = img.height
    nz = pnoise(W, cells, seed, octaves)
    if sharp:
        nz = 1 - np.abs(nz * 2 - 1)
    tops = (base - nz * amp).astype(int)
    px = img.load()
    c = color + (255,)
    for x in range(W):
        for y in range(max(0, tops[x]), h):
            px[x, y] = c
    if rim:
        rc = rim + (255,)
        for x in range(W):
            prev = tops[(x - sun_dir) % W]
            if tops[x] <= prev and 0 <= tops[x] < h:
                px[x, tops[x]] = rc
                if tops[x] < prev - 1 and tops[x] + 1 < h:
                    px[x, tops[x] + 1] = rc
    if snow:
        sc = snow + (255,)
        line = base - amp * 0.72
        for x in range(W):
            if tops[x] < line:
                for y in range(tops[x], min(h, int(line + (tops[x] % 3)))):
                    if y - tops[x] < 4 + (x * 7 % 5):
                        px[x, y] = sc
    return tops


def rect(d, x, y, w, h, c):
    for ox in (-W, 0, W):
        d.rectangle([x + ox, y, x + ox + w - 1, y + h - 1], fill=c)


def poly(d, pts, c):
    for ox in (-W, 0, W):
        d.polygon([(p[0] + ox, p[1]) for p in pts], fill=c)


def ellipse(d, x0, y0, x1, y1, c):
    for ox in (-W, 0, W):
        d.ellipse([x0 + ox, y0, x1 + ox, y1], fill=c)


def pine(d, x, gy, hgt, c, hi=None):
    w = max(3, hgt // 3)
    rect(d, x - 1, gy - hgt // 5, 2, hgt // 5, c)
    tiers = 3 if hgt > 18 else 2
    for i in range(tiers):
        ty = gy - hgt + i * hgt // (tiers + 1)
        bw = w * (i + 2) // (tiers + 1) + 2
        poly(d, [(x, ty), (x - bw, ty + hgt // 2), (x + bw, ty + hgt // 2)], c)
        if hi:
            poly(d, [(x, ty + 1), (x - bw // 2, ty + hgt // 4), (x, ty + hgt // 4)], hi)


def round_tree(d, x, gy, hgt, c, hi=None, rng=None):
    rect(d, x - 1, gy - hgt // 2, 3, hgt // 2, c)
    r = hgt // 3 + 2
    ellipse(d, x - r, gy - hgt, x + r, gy - hgt + r * 2, c)
    ellipse(d, x - r - 3, gy - hgt + r // 2, x + r - 3, gy - hgt + r * 2, c)
    ellipse(d, x - r + 4, gy - hgt + r // 2, x + r + 3, gy - hgt + r * 2 + 1, c)
    if hi:
        ellipse(d, x - r + 2, gy - hgt + 1, x + 1, gy - hgt + r // 2 + 2, hi)


def dead_tree(d, x, gy, hgt, c, rng, thick=2):
    rect(d, x - thick // 2, gy - hgt, thick, hgt, c)
    rect(d, x - thick, gy - 2, thick * 2 + 1, 2, c)
    for i in range(5):
        by = gy - hgt + i * hgt // 6 + 2
        side = 1 if i % 2 else -1
        ln = int(rng.integers(4, 4 + hgt // 5))
        for k in range(ln):
            rect(d, x + side * (k + 1), by - k // 2, 1, 1, c)
            if k == ln // 2 and rng.random() < 0.6:
                for j in range(3):
                    rect(d, x + side * (k + 1) + side * j, by - k // 2 - j - 1, 1, 1, c)


def building(d, x, gy, w, h, c, win=None, rng=None, roof="peak"):
    rect(d, x, gy - h, w, h, c)
    if roof == "peak":
        poly(d, [(x - 1, gy - h), (x + w // 2, gy - h - w // 2 - 1), (x + w, gy - h)], c)
    elif roof == "flat":
        rect(d, x - 1, gy - h - 1, w + 2, 1, c)
    elif roof == "dome":
        ellipse(d, x, gy - h - w // 2, x + w - 1, gy - h + w // 2, c)
    if win and rng is not None:
        for wy in range(gy - h + 3, gy - 3, 4):
            for wx in range(x + 2, x + w - 2, 3):
                if rng.random() < 0.35:
                    rect(d, wx, wy, 1, 2, win)


def tower(d, x, gy, w, h, c, win=None, cone=True, flag=None):
    rect(d, x, gy - h, w, h, c)
    if cone:
        poly(d, [(x - 1, gy - h), (x + w // 2, gy - h - w - 3), (x + w, gy - h)], c)
        if flag:
            rect(d, x + w // 2, gy - h - w - 7, 1, 4, c)
            rect(d, x + w // 2 + 1, gy - h - w - 7, 3, 2, flag)
    else:
        for bx in range(x, x + w, 2):
            rect(d, bx, gy - h - 2, 1, 2, c)
    if win:
        rect(d, x + w // 2, gy - h + 4, 1, 2, win)
        if h > 20:
            rect(d, x + w // 2, gy - h + 12, 1, 2, win)


def column(d, x, gy, h, c, broken=False, w=4):
    rect(d, x, gy - h, w, h, c)
    rect(d, x - 1, gy - h, w + 2, 2, c)
    rect(d, x - 1, gy - 2, w + 2, 2, c)
    if broken:
        poly(d, [(x - 1, gy - h), (x + w + 1, gy - h), (x + w + 1, gy - h - 3), (x + w // 2, gy - h - 1)], c)


def arch(d, x, gy, w, h, c, thick=3):
    rect(d, x, gy - h, thick, h, c)
    rect(d, x + w - thick, gy - h, thick, h, c)
    for i in range(w):
        t = i / (w - 1)
        yy = int(gy - h - math.sin(t * math.pi) * (w / 2.2))
        rect(d, x + i, yy, 1, thick, c)


def tent(d, x, gy, w, c, stripe=None):
    poly(d, [(x, gy), (x + w // 2, gy - w * 2 // 3), (x + w, gy)], c)
    if stripe:
        poly(d, [(x + w // 2, gy - w * 2 // 3), (x + w // 2 - 2, gy), (x + w // 2 + 2, gy)], stripe)


def battlement(d, y, c, win=None, rng=None):
    """Muralha de castelo em primeiro plano: ameias, seteiras e estandartes."""
    rect(d, 0, y, W, 144 - y, c)
    for bx in range(0, W, 8):
        rect(d, bx, y - 4, 5, 4, c)
    for bx in range(24, W, 64):
        rect(d, bx, y - 30, 14, 30, c)
        for k in range(0, 14, 4):
            rect(d, bx + k, y - 34, 3, 4, c)
        if win:
            rect(d, bx + 6, y - 22, 2, 5, win)


# ---------------------------------------------------------------------------
# Estilos (todas as camadas têm 144 px de altura = coordenadas da tela)
# ---------------------------------------------------------------------------

def paint_forest(st, rng):
    p = st["pal"]
    far = layer()
    ridge(far, 96, 42, 4, st["seed"], rgb(p["far"]), rim=rgb(p["far_rim"]), sun_dir=-1)
    ridge(far, 108, 18, 6, st["seed"] + 9, mix(rgb(p["far"]), rgb(p["mid"]), 0.35), octaves=3)
    haze(far, st["fog"], 60, 144, 0.1, 0.55)
    mid = layer()
    tops = ridge(mid, 118, 12, 6, st["seed"] + 1, rgb(p["mid"]), octaves=3)
    d = ImageDraw.Draw(mid)
    x = 0
    while x < W:
        gy = int(tops[x % W]) + 2
        hgt = int(rng.integers(26, 52))
        if rng.random() < 0.6:
            pine(d, x, gy, hgt, rgb(p["mid"]), rgb(p["mid_hi"]))
        else:
            round_tree(d, x, gy, hgt, rgb(p["mid"]), rgb(p["mid_hi"]))
        x += int(rng.integers(6, 14))
    haze(mid, st["fog"], 100, 144, 0.0, 0.35)
    near = layer()
    tops = ridge(near, 132, 6, 5, st["seed"] + 2, rgb(p["near"]), octaves=2)
    d = ImageDraw.Draw(near)
    x = 0
    while x < W:
        gy = int(tops[x % W]) + 2
        hgt = int(rng.integers(50, 96))
        if rng.random() < 0.5:
            pine(d, x, gy, hgt, rgb(p["near"]))
        else:
            round_tree(d, x, gy, hgt, rgb(p["near"]))
        x += int(rng.integers(34, 70))
    return far, mid, near


def paint_castle(st, rng):
    p = st["pal"]
    far = layer()
    ridge(far, 100, 44, 3, st["seed"], rgb(p["far"]), rim=rgb(p["far_rim"]), sharp=True, snow=rgb(p["far_rim"]))
    haze(far, st["fog"], 60, 144, 0.05, 0.5)
    mid = layer()
    ridge(mid, 122, 6, 4, st["seed"] + 1, rgb(p["mid"]), octaves=2)
    d = ImageDraw.Draw(mid)
    win = rgb(p["window"]) + (255,)
    c = rgb(p["mid"])
    cx = int(rng.integers(40, 200))
    rect(d, cx, 84, 110, 40, c)
    for bx in range(cx, cx + 110, 4):
        rect(d, bx, 81, 2, 3, c)
    for i, (tx, th) in enumerate([(cx - 8, 64), (cx + 30, 86), (cx + 70, 58), (cx + 104, 70)]):
        tower(d, tx, 122, 12, th, c, win, cone=i % 2 == 0, flag=rgb(p["flag"]))
    for i in range(5):
        tx = int(rng.integers(0, W))
        tower(d, tx, 122, 8, int(rng.integers(26, 48)), c, win, cone=rng.random() < 0.6)
    haze(mid, st["fog"], 90, 144, 0.0, 0.3)
    near = layer()
    d = ImageDraw.Draw(near)
    battlement(d, 128, rgb(p["near"]), win, rng)
    for bx in range(56, W, 128):
        rect(d, bx, 104, 1, 24, rgb(p["near"]))
        poly(d, [(bx + 1, 104), (bx + 9, 104), (bx + 9, 116), (bx + 5, 112), (bx + 1, 116)], rgb(p["flag"]))
    return far, mid, near


def paint_gothic(st, rng):
    p = st["pal"]
    far = layer()
    d = ImageDraw.Draw(far)
    fc = rgb(p["far"])
    ridge(far, 112, 8, 4, st["seed"], fc, octaves=2)
    for x in range(0, W, 9):
        h = int(rng.integers(20, 55))
        building(d, x, 112, int(rng.integers(8, 14)), h, fc, roof="peak")
    for i in range(3):
        tower(d, int(rng.integers(0, W)), 112, 6, int(rng.integers(60, 85)), fc)
    haze(far, st["fog"], 50, 144, 0.1, 0.5)
    mid = layer()
    d = ImageDraw.Draw(mid)
    mc = rgb(p["mid"])
    win = rgb(p["window"]) + (255,)
    ridge(mid, 126, 3, 4, st["seed"] + 1, mc, octaves=1)
    x = 0
    while x < W:
        w = int(rng.integers(12, 22))
        h = int(rng.integers(26, 60))
        building(d, x, 126, w, h, mc, win, rng, roof="peak" if rng.random() < 0.7 else "flat")
        x += w + int(rng.integers(0, 3))
    cx = int(rng.integers(100, 300))
    tower(d, cx, 126, 14, 96, mc, win)
    tower(d, cx + 40, 126, 14, 96, mc, win)
    rect(d, cx, 60, 54, 66, mc)
    ellipse(d, cx + 20, 72, cx + 33, 85, win)
    haze(mid, st["fog"], 90, 144, 0.0, 0.25)
    near = layer()
    d = ImageDraw.Draw(near)
    nc = rgb(p["near"])
    ridge(near, 136, 2, 4, st["seed"] + 2, nc, octaves=1)
    for x in range(0, W, 48):
        rect(d, x + 10, 104, 2, 32, nc)
        ellipse(d, x + 7, 98, x + 14, 105, nc)
        rect(d, x + 9, 101, 4, 3, win)
    return far, mid, near


def paint_ruins(st, rng):
    p = st["pal"]
    far = layer()
    ridge(far, 100, 34, 3, st["seed"], rgb(p["far"]), rim=rgb(p["far_rim"]), sun_dir=1)
    haze(far, st["fog"], 60, 144, 0.1, 0.55)
    mid = layer()
    tops = ridge(mid, 120, 10, 5, st["seed"] + 1, rgb(p["mid"]), octaves=3)
    d = ImageDraw.Draw(mid)
    c = rgb(p["mid"])
    x = 10
    while x < W:
        gy = int(tops[x % W]) + 2
        r = rng.random()
        if r < 0.4:
            arch(d, x, gy, int(rng.integers(18, 30)), int(rng.integers(20, 36)), c)
            x += 36
        elif r < 0.75:
            column(d, x, gy, int(rng.integers(14, 40)), c, broken=True)
            x += int(rng.integers(10, 20))
        else:
            round_tree(d, x, gy, int(rng.integers(20, 34)), c, rgb(p["mid_hi"]))
            x += 16
    haze(mid, st["fog"], 90, 144, 0.0, 0.3)
    near = layer()
    tops = ridge(near, 134, 5, 4, st["seed"] + 2, rgb(p["near"]), octaves=2)
    d = ImageDraw.Draw(near)
    for x in range(0, W, 96):
        ox = x + int(rng.integers(0, 30))
        column(d, ox, int(tops[ox % W]) + 2, int(rng.integers(60, 100)), rgb(p["near"]), broken=True, w=7)
    return far, mid, near


def paint_desert(st, rng):
    p = st["pal"]
    far = layer()
    d = ImageDraw.Draw(far)
    fc = rgb(p["far"])
    for i in range(3):
        px_ = int(rng.integers(0, W))
        s = int(rng.integers(26, 46))
        poly(d, [(px_ - s, 104), (px_, 104 - s), (px_ + s, 104)], fc)
        poly(d, [(px_, 104 - s), (px_ + s, 104), (px_ + 2, 104)], darken(fc, 0.1))
    ridge(far, 108, 12, 3, st["seed"], fc, rim=rgb(p["far_rim"]), octaves=2)
    haze(far, st["fog"], 56, 144, 0.15, 0.5)
    mid = layer()
    ridge(mid, 122, 16, 3, st["seed"] + 1, rgb(p["mid"]), rim=rgb(p["mid_hi"]), sun_dir=-1, octaves=2)
    d = ImageDraw.Draw(mid)
    for i in range(6):
        x = int(rng.integers(0, W))
        rect(d, x, 96, 2, 24, rgb(p["mid"]))
        for k in range(5):
            a = -1.2 + k * 0.6
            poly(d, [(x + 1, 96), (x + 1 + int(math.cos(a) * 9), 96 + int(math.sin(a) * 5) + 3), (x + 1 + int(math.cos(a) * 9), 96 + int(math.sin(a) * 5) + 5)], rgb(p["mid"]))
    near = layer()
    ridge(near, 138, 12, 2, st["seed"] + 2, rgb(p["near"]), rim=rgb(p["near_hi"]), sun_dir=-1, octaves=2)
    return far, mid, near


def paint_sky(st, rng):
    p = st["pal"]
    far = layer()
    d = ImageDraw.Draw(far)
    for i in range(5):
        x = int(rng.integers(0, W))
        y = int(rng.integers(36, 76))
        s = int(rng.integers(6, 12))
        ellipse(d, x - s, y - 2, x + s, y + 3, rgb(p["far"]))
        poly(d, [(x - s + 1, y + 1), (x + s - 1, y + 1), (x, y + s * 2)], rgb(p["far"]))
    nz = pnoise(W, 10, st["seed"], 3)
    for x in range(W):
        top = int(104 - nz[x] * 10)
        for y in range(top, 144):
            far.putpixel((x, y), rgb(p["cloud"]) + (255,) if y > top + 1 else rgb(p["cloud_hi"]) + (255,))
    haze(far, st["fog"], 30, 100, 0.2, 0.5)
    mid = layer()
    d = ImageDraw.Draw(mid)
    mc = rgb(p["mid"])
    win = rgb(p["window"]) + (255,)
    for i in range(4):
        x = int(rng.integers(0, W))
        y = int(rng.integers(64, 104))
        s = int(rng.integers(16, 30))
        ellipse(d, x - s, y - 3, x + s, y + 4, mc)
        poly(d, [(x - s + 2, y + 2), (x + s - 2, y + 2), (x + int(rng.integers(-4, 4)), y + s + 10)], mc)
        rect(d, x - s + 2, y - 4, s * 2 - 4, 2, rgb(p["mid_hi"]))
        for k in range(int(rng.integers(1, 4))):
            tower(d, x - s // 2 + k * 8, y - 3, 5, int(rng.integers(10, 26)), mc, win)
        if rng.random() < 0.6:
            rect(d, x + s // 3, y + 2, 1, 30, rgb(p["cloud_hi"]))
    near = layer()
    nz = pnoise(W, 6, st["seed"] + 5, 3)
    for x in range(W):
        top = int(134 - nz[x] * 16)
        for y in range(top, 144):
            near.putpixel((x, y), rgb(p["near"]) + (255,) if y > top + 1 else rgb(p["near_hi"]) + (255,))
    return far, mid, near


def paint_cave(st, rng):
    p = st["pal"]
    far = layer()
    d = ImageDraw.Draw(far)
    fc = rgb(p["far"])
    rect(d, 0, 0, W, 144, fc + (255,))
    for i in range(10):
        x = int(rng.integers(0, W))
        y = int(rng.integers(20, 110))
        ellipse(d, x - 16, y - 10, x + 16, y + 10, rgb(p["far_hi"]))
    for i in range(24):
        x = int(rng.integers(0, W))
        y = int(rng.integers(10, 130))
        cc = rgb(p["crystal"])
        poly(d, [(x, y - 4), (x + 2, y), (x, y + 2), (x - 2, y)], cc)
    mid = layer()
    d = ImageDraw.Draw(mid)
    mc = rgb(p["mid"])
    nz = pnoise(W, 12, st["seed"] + 1, 3)
    nz2 = pnoise(W, 10, st["seed"] + 2, 3)
    for x in range(W):
        top = int(10 + nz[x] * 22)
        bot = int(134 - nz2[x] * 26)
        rect(d, x, 0, 1, top, mc)
        rect(d, x, bot, 1, 144 - bot, mc)
    for i in range(22):
        x = int(rng.integers(0, W))
        ln = int(rng.integers(8, 26))
        poly(d, [(x - 3, 20), (x + 3, 20), (x, 20 + ln)], mc)
        x2 = int(rng.integers(0, W))
        poly(d, [(x2 - 3, 124), (x2 + 3, 124), (x2, 124 - ln // 2)], mc)
    near = layer()
    d = ImageDraw.Draw(near)
    nc = rgb(p["near"])
    for i in range(8):
        x = int(rng.integers(0, W))
        ln = int(rng.integers(30, 60))
        poly(d, [(x - 6, 0), (x + 6, 0), (x, ln)], nc)
    nz = pnoise(W, 6, st["seed"] + 3, 2)
    for x in range(W):
        bot = int(138 - nz[x] * 12)
        rect(d, x, bot, 1, 144 - bot, nc)
    return far, mid, near


def paint_war(st, rng):
    p = st["pal"]
    far = layer()
    ridge(far, 104, 40, 3, st["seed"], rgb(p["far"]), rim=rgb(p["far_rim"]), sharp=True)
    haze(far, st["fog"], 60, 144, 0.05, 0.45)
    mid = layer()
    ridge(mid, 124, 6, 4, st["seed"] + 1, rgb(p["mid"]), octaves=2)
    d = ImageDraw.Draw(mid)
    mc = rgb(p["mid"])
    x = 0
    while x < W:
        r = rng.random()
        if r < 0.45:
            for k in range(int(rng.integers(6, 14))):
                h = int(rng.integers(16, 22))
                rect(d, x + k * 3, 124 - h, 2, h, mc)
                poly(d, [(x + k * 3, 124 - h), (x + k * 3 + 1, 124 - h - 3), (x + k * 3 + 2, 124 - h)], mc)
            x += 44
        elif r < 0.8:
            tent(d, x, 124, int(rng.integers(12, 20)), mc, rgb(p["flag"]))
            x += 22
        else:
            tower(d, x, 124, 8, int(rng.integers(24, 36)), mc, rgb(p["window"]) + (255,), cone=False)
            rect(d, x + 3, 124 - 44, 1, 8, mc)
            rect(d, x + 4, 124 - 44, 4, 3, rgb(p["flag"]))
            x += 16
    haze(mid, st["fog"], 100, 144, 0.0, 0.25)
    near = layer()
    tops = ridge(near, 136, 6, 4, st["seed"] + 2, rgb(p["near"]), octaves=2)
    d = ImageDraw.Draw(near)
    for x in range(0, W, 90):
        ox = x + int(rng.integers(0, 40))
        dead_tree(d, ox, int(tops[ox % W]) + 2, int(rng.integers(34, 56)), rgb(p["near"]), rng, 3)
    return far, mid, near


def paint_graveyard(st, rng):
    p = st["pal"]
    far = layer()
    ridge(far, 100, 26, 3, st["seed"], rgb(p["far"]), rim=rgb(p["far_rim"]), octaves=3)
    haze(far, st["fog"], 70, 144, 0.1, 0.5)
    mid = layer()
    tops = ridge(mid, 120, 8, 4, st["seed"] + 1, rgb(p["mid"]), octaves=2)
    d = ImageDraw.Draw(mid)
    mc = rgb(p["mid"])
    cx = int(rng.integers(60, 400))
    gy = int(tops[cx % W]) + 2
    building(d, cx, gy, 26, 22, mc, roof="peak")
    tower(d, cx + 26, gy, 8, 46, mc, rgb(p["window"]) + (255,))
    rect(d, cx + 29, gy - 60, 1, 6, mc)
    rect(d, cx + 27, gy - 58, 5, 1, mc)
    for x in range(0, W, 7):
        gy = int(tops[x % W]) + 2
        r = rng.random()
        if r < 0.35:
            rect(d, x, gy - 5, 3, 5, mc)
            rect(d, x, gy - 6, 3, 1, mc)
        elif r < 0.55:
            rect(d, x + 1, gy - 8, 1, 8, mc)
            rect(d, x - 1, gy - 6, 5, 1, mc)
        elif r < 0.62:
            dead_tree(d, x, gy, int(rng.integers(18, 32)), mc, rng)
    haze(mid, st["fog"], 100, 144, 0.0, 0.3)
    near = layer()
    tops = ridge(near, 136, 5, 4, st["seed"] + 2, rgb(p["near"]), octaves=2)
    d = ImageDraw.Draw(near)
    for x in range(0, W, 80):
        ox = x + int(rng.integers(0, 30))
        dead_tree(d, ox, int(tops[ox % W]) + 2, int(rng.integers(44, 70)), rgb(p["near"]), rng, 3)
    for x in range(0, W, 3):
        rect(d, x, int(tops[x]) - 3, 1, 3, rgb(p["near"]))
        if x % 12 == 0:
            rect(d, x - 1, int(tops[x]) - 2, 3, 1, rgb(p["near"]))
    return far, mid, near


def paint_swamp(st, rng):
    p = st["pal"]
    far = layer()
    ridge(far, 104, 16, 3, st["seed"], rgb(p["far"]), octaves=3)
    haze(far, st["fog"], 70, 144, 0.2, 0.6)
    mid = layer()
    tops = ridge(mid, 116, 4, 4, st["seed"] + 1, rgb(p["mid"]), octaves=2)
    d = ImageDraw.Draw(mid)
    mc = rgb(p["mid"])
    for x in range(0, W, 26):
        ox = x + int(rng.integers(0, 12))
        h = int(rng.integers(28, 54))
        dead_tree(d, ox, int(tops[ox % W]) + 2, h, mc, rng, 3)
        for k in range(4):
            rect(d, ox + int(rng.integers(-6, 7)), int(tops[ox % W]) - h + 6 + k * 5, 1, int(rng.integers(4, 10)), mc)
    haze(mid, st["fog"], 80, 130, 0.05, 0.35)
    reflect(mid, 118, p["water"], 0.5)
    near = layer()
    tops = ridge(near, 132, 3, 5, st["seed"] + 2, rgb(p["near"]), octaves=2)
    d = ImageDraw.Draw(near)
    for x in range(0, W, 2):
        if rng.random() < 0.6:
            h = int(rng.integers(3, 12))
            rect(d, x, int(tops[x]) - h, 1, h, rgb(p["near"]))
    return far, mid, near


PAINTERS = {
    "forest": paint_forest, "castle": paint_castle, "gothic": paint_gothic, "ruins": paint_ruins,
    "desert": paint_desert, "sky": paint_sky, "cave": paint_cave, "war": paint_war,
    "graveyard": paint_graveyard, "swamp": paint_swamp,
}

# Cada estilo: céu, paleta das camadas, névoa, luz ambiente sugerida,
# partículas e o evento animado (desenhado pelo jogo por cima das camadas).
STYLES = {
    "forest": {
        "seed": 11, "painter": "forest",
        "sky": {"colors": ["#6fb0e0", "#a8d8f0", "#e6f4e0", "#fff2c8"], "sun": {"pos": [196, 34], "r": 7, "color": "#fff8dc", "halo": "#fff2b0", "glow": 0.45},
                "bands": [[62, "#ffffff", 0.35], [88, "#fff6e0", 0.25]]},
        "pal": {"far": "#8fb8b8", "far_rim": "#c8e0d0", "mid": "#4d7f63", "mid_hi": "#78a870", "near": "#23402f"},
        "fog": "#e8f4e8", "fog_alpha": 0.18, "event": "birds", "birds": True, "rays": True, "cloud": "#ffffff",
    },
    "castle": {
        "seed": 23, "painter": "castle",
        "sky": {"colors": ["#1d2140", "#3a3d6a", "#8a6d8e", "#e8a888"], "sun": {"pos": [60, 40], "r": 9, "color": "#f8e8d0", "halo": "#f0c0a0", "glow": 0.3, "moon": True},
                "stars": 40, "bands": [[70, "#c09ab0", 0.3]]},
        "pal": {"far": "#5a5478", "far_rim": "#9a88a8", "mid": "#2e2b48", "near": "#17152a", "window": "#ffc860", "flag": "#b83a3a"},
        "fog": "#9a8ab8", "fog_alpha": 0.14, "event": "storm",
    },
    "gothic": {
        "seed": 31, "painter": "gothic",
        "sky": {"colors": ["#141828", "#262c48", "#4a4a6a", "#7a6a7a"], "sun": {"pos": [206, 30], "r": 11, "color": "#e8e8f0", "halo": "#a0a8c8", "glow": 0.35, "moon": True},
                "stars": 30, "bands": [[56, "#50506a", 0.4]]},
        "pal": {"far": "#3a3c58", "mid": "#20223a", "near": "#101020", "window": "#ffd070"},
        "fog": "#6a6a90", "fog_alpha": 0.22, "event": "titan", "weather": "rain",
    },
    "ruins": {
        "seed": 47, "painter": "ruins",
        "sky": {"colors": ["#5a7ab8", "#e0a0a0", "#f8c890", "#ffe8b0"], "sun": {"pos": [70, 78], "r": 12, "color": "#fff0c0", "halo": "#ffc890", "glow": 0.55},
                "bands": [[50, "#f8d0c0", 0.35], [66, "#ffe0c0", 0.3]]},
        "pal": {"far": "#b08aa0", "far_rim": "#f0c8b0", "mid": "#6a4f62", "mid_hi": "#907080", "near": "#35263a"},
        "fog": "#ffd8b8", "fog_alpha": 0.2, "event": "birds", "birds": True, "rays": True, "cloud": "#ffe8d8",
    },
    "desert": {
        "seed": 53, "painter": "desert",
        "sky": {"colors": ["#4a8ad0", "#88c0e8", "#f0e0b0", "#ffd890"], "sun": {"pos": [128, 22], "r": 8, "color": "#ffffff", "halo": "#fff0c0", "glow": 0.6}},
        "pal": {"far": "#d8b088", "far_rim": "#f8e0b8", "mid": "#c08858", "mid_hi": "#e8b078", "near": "#8a5a38", "near_hi": "#b07848"},
        "fog": "#f8e0b0", "fog_alpha": 0.2, "event": "sandworm", "weather": "heat",
    },
    "sky": {
        "seed": 61, "painter": "sky",
        "sky": {"colors": ["#3a78d8", "#78b0f0", "#c8e4ff", "#ffffff"], "sun": {"pos": [40, 26], "r": 8, "color": "#ffffff", "halo": "#fff8e0", "glow": 0.5},
                "bands": [[44, "#ffffff", 0.3]]},
        "pal": {"far": "#9ab4d8", "cloud": "#e8f0ff", "cloud_hi": "#ffffff", "mid": "#6a7aa8", "mid_hi": "#a8e070", "near": "#dfe8f8", "near_hi": "#ffffff", "window": "#fff0a0"},
        "fog": "#ffffff", "fog_alpha": 0.2, "event": "whale", "birds": True, "cloud": "#ffffff",
    },
    "cave": {
        "seed": 71, "painter": "cave",
        "sky": {"colors": ["#0c0c16", "#141424", "#1c1c30", "#141420"]},
        "pal": {"far": "#1e2034", "far_hi": "#262a44", "crystal": "#70e0f0", "mid": "#12131f", "near": "#08080f"},
        "fog": "#3a4870", "fog_alpha": 0.12, "event": "eyes", "underground": True,
    },
    "war": {
        "seed": 83, "painter": "war",
        "sky": {"colors": ["#3a1a28", "#8a3030", "#e06040", "#f8b060"], "sun": {"pos": [180, 70], "r": 14, "color": "#ffd8a0", "halo": "#ff8050", "glow": 0.5},
                "bands": [[58, "#40202a", 0.5], [74, "#6a3030", 0.4]]},
        "pal": {"far": "#6a3440", "far_rim": "#c06050", "mid": "#321a24", "near": "#180c12", "window": "#ffb050", "flag": "#e0c050"},
        "fog": "#c06050", "fog_alpha": 0.18, "event": "catapults", "weather": "embers", "cloud": "#5a3036",
    },
    "graveyard": {
        "seed": 97, "painter": "graveyard",
        "sky": {"colors": ["#10182a", "#23304e", "#3e4e6e", "#6a7894"], "sun": {"pos": [170, 36], "r": 16, "color": "#f0f0e0", "halo": "#b8c8e0", "glow": 0.45, "moon": True},
                "stars": 55},
        "pal": {"far": "#34405a", "far_rim": "#6a7a98", "mid": "#1e2436", "near": "#0e1220", "window": "#d8f0a0"},
        "fog": "#8898b8", "fog_alpha": 0.24, "event": "bats",
    },
    "swamp": {
        "seed": 101, "painter": "swamp",
        "sky": {"colors": ["#3a5048", "#6a8a70", "#a8b890", "#d0d8a8"], "sun": {"pos": [150, 50], "r": 9, "color": "#f0f0c8", "halo": "#d8e0a8", "glow": 0.35},
                "bands": [[64, "#c0c8a0", 0.45], [84, "#d0d8b0", 0.4]]},
        "pal": {"far": "#6a8068", "mid": "#3a4a38", "near": "#1c2418", "water": "#51685a"},
        "fog": "#c8d8b0", "fog_alpha": 0.3, "event": "wisps", "birds": True, "water": True,
    },
}


def build(name):
    st = STYLES[name]
    out = os.path.join(OUT, name)
    os.makedirs(out, exist_ok=True)
    rng = np.random.default_rng(st["seed"])
    sky(st).save(os.path.join(out, "sky.png"))
    far, mid, near = PAINTERS[st["painter"]](st, rng)
    far.save(os.path.join(out, "far.png"))
    mid.save(os.path.join(out, "mid.png"))
    near.save(os.path.join(out, "near.png"))
    print("ok", name)


def meta(name):
    st = STYLES[name]
    p = st["pal"]
    # cor que continua abaixo de cada camada (a base da silhueta)
    return {
        "far_fill": p["far"], "mid_fill": p["mid"], "near_fill": p["near"],
        "fog": st["fog"], "fog_alpha": st["fog_alpha"], "event": st.get("event", ""),
        "birds": st.get("birds", False), "rays": st.get("rays", False),
        "weather": st.get("weather", ""), "underground": st.get("underground", False),
        "water": st.get("water", False),
        "parallax": [0.08, 0.2, 0.4], "vparallax": [0.02, 0.04, 0.07],
        "cloud": st.get("cloud", st["fog"]),
    }


def main():
    names = sys.argv[1:] or list(STYLES.keys())
    for n in names:
        build(n)
    data = {"_doc": "Gerado por tools/build_scenery.py. Estilos de cenário de fundo (camadas em assets/art/scenery/<estilo>/)."}
    if os.path.exists(DATA):
        with open(DATA) as f:
            data.update(json.load(f))
    for n in STYLES:
        data[n] = meta(n)
    with open(DATA, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
