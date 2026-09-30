#!/usr/bin/env python3
"""Cenários de fundo em pixel art de alta resolução (tela 480x270), em
camadas com parallax, por estilo.

Inspiração: Kingdom Two Crowns (camadas, céu luminoso, perspectiva
atmosférica, reflexo na água), Hollow Knight e Blasphemous (silhuetas contra
a luz com BORDA ILUMINADA, janelas acesas, névoa) e Dead Cells (cor).

Como funciona: cada objeto é desenhado como silhueta chapada numa camada e
depois um passo de "luz" pinta a borda do lado do sol/lua (rim light), um
degradê vertical (mais claro em cima, mais escuro embaixo) e uma textura
pontilhada sutil. As camadas mais distantes são misturadas com a cor da
névoa (perspectiva atmosférica). Tudo emenda sem costura na horizontal.

Saída por estilo em assets/art/scenery/<estilo>/:
  sky.png           480x270  céu fixo (degradê em faixas, sol/lua, estrelas)
  l0.png .. lN.png  960x270  camadas do fundo (longe -> perto)
  cloud0..3.png              nuvens que andam
e data/scenery.json (paleta, parallax de cada camada, névoa, evento).

Uso: python3 tools/build_scenery.py [estilo ...]      (requer numpy, pillow)
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "art", "scenery")
DATA = os.path.join(ROOT, "data", "scenery.json")
W = 960
H = 270
SKY_W, SKY_H = 480, 270

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(int(a[i]) + (int(b[i]) - int(a[i])) * t)) for i in range(3))


def lighten(c, t):
    return mix(c, (255, 255, 255), t)


def darken(c, t):
    return mix(c, (0, 0, 0), t)


def hexs(c):
    return "#%02x%02x%02x" % tuple(c)


# ---------------------------------------------------------------------------
# Ruído periódico (emenda em W)
# ---------------------------------------------------------------------------

def pnoise(n, cells, seed, octaves=4, persistence=0.5):
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


def noise2(w, h, cells, seed):
    """Ruído 2D suave, periódico em x."""
    rng = np.random.default_rng(seed)
    cy = max(2, int(cells * h / w) + 1)
    g = rng.random((cy + 1, cells))
    x = np.arange(w) / w * cells
    y = np.arange(h) / h * cy
    xi = np.floor(x).astype(int)
    yi = np.floor(y).astype(int)
    xf = x - xi
    yf = y - yi
    xf = xf * xf * (3 - 2 * xf)
    yf = yf * yf * (3 - 2 * yf)
    a = g[np.ix_(yi, xi % cells)]
    b = g[np.ix_(yi, (xi + 1) % cells)]
    c = g[np.ix_(np.minimum(yi + 1, cy), xi % cells)]
    d = g[np.ix_(np.minimum(yi + 1, cy), (xi + 1) % cells)]
    return (a * (1 - xf) + b * xf) * (1 - yf[:, None]) + (c * (1 - xf) + d * xf) * yf[:, None]


# ---------------------------------------------------------------------------
# Camada: desenho de silhuetas com emenda horizontal
# ---------------------------------------------------------------------------

class Layer:
    def __init__(self, h=H):
        self.img = Image.new("RGBA", (W, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.h = h
        # "emissivos" (janelas, cristais): pintados depois da luz
        self.glow = Image.new("RGBA", (W, h), (0, 0, 0, 0))
        self.g = ImageDraw.Draw(self.glow)

    def rect(self, x, y, w, h, c, glow=False):
        d = self.g if glow else self.d
        c = tuple(c) + (255,) if len(c) == 3 else c
        for ox in (-W, 0, W):
            d.rectangle([x + ox, y, x + ox + w - 1, y + h - 1], fill=c)

    def poly(self, pts, c, glow=False):
        d = self.g if glow else self.d
        c = tuple(c) + (255,) if len(c) == 3 else c
        for ox in (-W, 0, W):
            d.polygon([(p[0] + ox, p[1]) for p in pts], fill=c)

    def ellipse(self, x0, y0, x1, y1, c, glow=False):
        d = self.g if glow else self.d
        c = tuple(c) + (255,) if len(c) == 3 else c
        for ox in (-W, 0, W):
            d.ellipse([x0 + ox, y0, x1 + ox, y1], fill=c)

    def line(self, pts, c, width=1, glow=False):
        d = self.g if glow else self.d
        c = tuple(c) + (255,) if len(c) == 3 else c
        for ox in (-W, 0, W):
            d.line([(p[0] + ox, p[1]) for p in pts], fill=c, width=width)

    def fill_below(self, tops, c):
        a = np.array(self.img)
        for x in range(W):
            t = int(max(0, tops[x]))
            a[t:, x, :3] = c
            a[t:, x, 3] = 255
        self.img = Image.fromarray(a, "RGBA")
        self.d = ImageDraw.Draw(self.img)

    def array(self):
        return np.array(self.img).astype(np.float64)

    def set_array(self, a):
        self.img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
        self.d = ImageDraw.Draw(self.img)


def light_pass(L, base, rim, sun_dir=-1, top_light=0.14, bottom_dark=0.26, rim_w=2, tex=0.06, seed=0, y0=None, y1=None, radius=5.0, bump=0.22):
    """Atalho: volume + borda iluminada com tons derivados da cor base."""
    base = tuple(int(v) for v in base)
    volume_pass(L, base, mix(base, rim, 0.3), darken(base, 0.28), rim, sun_dir=sun_dir, radius=radius, bump=bump,
                bump_cells=28, seed=seed, levels=4, rim_w=rim_w, top_light=top_light, bottom_dark=bottom_dark)


def volume_pass(L, base, light, shadow, rim, sun_dir=-1, radius=6.0, bump=0.0, bump_cells=40, seed=0, levels=4, rim_w=2, top_light=0.12, bottom_dark=0.25):
    """Dá VOLUME às silhuetas: relevo = distância até a borda (perfil
    arredondado) + ruído opcional (folhagem, rocha); normal do relevo ->
    luz do lado do sol em faixas (sombra, base, luz, brilho) + borda
    iluminada (rim light) + degradê vertical."""
    a = L.array()
    A = a[..., 3] > 0
    h = L.h
    if not A.any():
        return
    d = ndimage.distance_transform_edt(np.pad(A, ((0, 0), (W, W)), mode="wrap"))[:, W:2 * W]
    k = np.clip(d / radius, 0, 1)
    hgt = np.sqrt(np.clip(1 - (1 - k) ** 2, 0, 1)) * radius
    if bump > 0:
        hgt = hgt + (noise2(W, h, bump_cells, seed) - 0.5) * bump * radius
        hgt = hgt + (noise2(W, h, bump_cells * 3, seed + 1) - 0.5) * bump * radius * 0.5
    gx = (np.roll(hgt, -1, axis=1) - np.roll(hgt, 1, axis=1)) * 0.5
    gy = np.zeros_like(hgt)
    gy[1:-1] = (hgt[2:] - hgt[:-2]) * 0.5
    n = np.stack([-gx, -gy, np.ones_like(hgt) * 0.9], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    Ld = np.array([sun_dir * -0.62, -0.62, 0.48])
    Ld = Ld / np.linalg.norm(Ld)
    lum = np.clip(n @ Ld, -1, 1)
    lum = (lum + 0.35) / 1.35
    ys = np.arange(h)
    lum = lum + (top_light * (1 - ys / h) - bottom_dark * (ys / h))[:, None]
    ramp = [np.array(shadow, float), np.array(base, float), np.array(light, float), np.array(light, float) * 0.6 + np.array(rim, float) * 0.4]
    ramp = ramp[:levels]
    idx = np.clip((lum * len(ramp)).astype(int), 0, len(ramp) - 1)
    col = np.array(ramp)[idx]
    # textura pontilhada leve
    bay = np.tile(BAYER, (h // 4 + 1, W // 4 + 1))[:h, :W]
    nz = noise2(W, h, 70, seed + 9)
    col[(nz > 0.66) & (bay < 0.3)] *= 0.9
    # borda do lado do sol + topo
    rimc = np.array(rim, float)
    edge_sun = np.zeros_like(A)
    edge_top = np.zeros_like(A)
    for k2 in range(1, rim_w + 1):
        edge_sun |= A & ~np.roll(A, -sun_dir * k2, axis=1)
        up = np.zeros_like(A)
        up[k2:] = A[:-k2]
        edge_top |= A & ~up
    col[edge_top & (lum > 0.3)] = col[edge_top & (lum > 0.3)] * 0.4 + rimc * 0.6
    col[edge_sun] = col[edge_sun] * 0.25 + rimc * 0.75
    a[..., :3] = np.where(A[..., None], col, a[..., :3])
    L.set_array(a)


def haze(L, fog, t0, t1, y0=0, y1=None):
    """Perspectiva atmosférica: mistura com a névoa (mais embaixo = mais)."""
    a = L.array()
    fog = np.array(fog, dtype=np.float64)
    h = L.h
    y1 = y1 if y1 is not None else h
    ys = np.arange(h)
    k = np.clip((ys - y0) / max(1, y1 - y0), 0, 1)
    t = (t0 + (t1 - t0) * k)
    t = np.round(t * 8) / 8
    alpha = a[..., 3] > 0
    mixd = a[..., :3] * (1 - t[:, None, None]) + fog * t[:, None, None]
    a[..., :3] = np.where(alpha[..., None], mixd, a[..., :3])
    L.set_array(a)


def finish(L):
    """Junta os emissivos por cima."""
    L.img.alpha_composite(L.glow)
    return L.img


def reflect(L, water_y, water, alpha=0.5):
    """Água com reflexo (Kingdom Two Crowns)."""
    a = L.array()
    water = np.array(water, dtype=np.float64)
    h = L.h
    for y in range(water_y, h):
        src = water_y - (y - water_y) - 1
        shift = int(round(math.sin(y * 0.7) * 2))
        row = np.zeros((W, 4))
        row[:, :3] = water
        row[:, 3] = 255
        if src >= 0 and (y - water_y) % 4 != 3:
            s = np.roll(a[src], shift, axis=0)
            m = s[:, 3] > 0
            f = alpha * (1 - (y - water_y) / (h - water_y + 10))
            row[m, :3] = water * (1 - f) + s[m, :3] * f
        a[y] = row
    # brilhos na superfície
    for x in range(W):
        if (x // 5) % 5 == 0:
            a[water_y, x, :3] = np.minimum(water * 1.5 + 20, 255)
    L.set_array(a)


def ridge(L, base, amp, cells, seed, color, octaves=4, sharp=False):
    nz = pnoise(W, cells, seed, octaves)
    if sharp:
        nz = 1 - np.abs(nz * 2 - 1)
    tops = (base - nz * amp).astype(int)
    L.fill_below(tops, color)
    return tops


def snow_caps(L, tops, base, amp, color, rim):
    a = L.array()
    line = base - amp * 0.62
    for x in range(W):
        t = tops[x]
        if t < line:
            depth = int((line - t) * 0.5) + 3 + (x * 7 % 4)
            for y in range(max(0, t), min(L.h, t + depth)):
                a[y, x, :3] = color if (x + y) % 7 else rim
    L.set_array(a)


# ---------------------------------------------------------------------------
# Objetos
# ---------------------------------------------------------------------------

def pine(L, x, gy, hgt, c):
    w = max(5, hgt // 3)
    L.rect(x - 1, gy - hgt // 5, 3, hgt // 5 + 2, darken(c, 0.25))
    tiers = 3 if hgt < 40 else 4
    for i in range(tiers):
        ty = gy - hgt + i * hgt // (tiers + 1)
        bw = w * (i + 2) // (tiers + 1) + 2
        L.poly([(x, ty), (x + bw, ty + hgt // 3 + 2), (x + bw // 3, ty + hgt // 3), (x - bw // 3, ty + hgt // 3), (x - bw, ty + hgt // 3 + 2)], c)


def round_tree(L, x, gy, hgt, c, rng):
    L.rect(x - 1, gy - hgt // 2, 3, hgt // 2 + 2, darken(c, 0.25))
    r = hgt // 3
    for _ in range(6):
        ox = int(rng.integers(-r, r + 1))
        oy = int(rng.integers(-r // 2, r // 2 + 1))
        rr = int(rng.integers(r // 2 + 2, r + 3))
        cy = gy - hgt + r + oy
        L.ellipse(x + ox - rr, cy - rr, x + ox + rr, cy + rr, c)


def dead_tree(L, x, gy, hgt, c, rng, thick=3):
    L.poly([(x - thick, gy), (x + thick, gy), (x + 1, gy - hgt), (x - 1, gy - hgt)], c)

    def branch(bx, by, ang, ln, th):
        if ln < 4 or th < 1:
            return
        ex = bx + math.cos(ang) * ln
        ey = by + math.sin(ang) * ln
        L.line([(bx, by), (ex, ey)], c, width=max(1, int(th)))
        for s in (-1, 1):
            if rng.random() < 0.8:
                branch(ex, ey, ang + s * rng.uniform(0.3, 0.7), ln * rng.uniform(0.5, 0.75), th - 1)

    for k in range(int(rng.integers(2, 5))):
        by = gy - hgt * rng.uniform(0.45, 0.95)
        s = -1 if k % 2 else 1
        branch(x, by, -math.pi / 2 + s * rng.uniform(0.4, 1.0), hgt * rng.uniform(0.25, 0.45), thick - 1)


def house(L, x, gy, w, h, c, win, rng, roof="peak"):
    L.rect(x, gy - h, w, h, c)
    if roof == "peak":
        rh = w // 2 + 3
        L.poly([(x - 2, gy - h), (x + w // 2, gy - h - rh), (x + w + 1, gy - h)], c)
        if rng.random() < 0.5:
            L.rect(x + w - 5, gy - h - rh + 2, 3, rh, c)  # chaminé
    elif roof == "spire":
        L.poly([(x - 1, gy - h), (x + w // 2, gy - h - w * 2), (x + w, gy - h)], c)
    if win:
        for wy in range(gy - h + 4, gy - 4, 7):
            for wx in range(x + 2, x + w - 2, 5):
                if rng.random() < 0.45:
                    L.rect(wx, wy, 2, 3, win, glow=True)


def tower(L, x, gy, w, h, c, win=None, cone=True, flag=None, rng=None):
    L.rect(x, gy - h, w, h, c)
    if cone:
        L.poly([(x - 2, gy - h), (x + w // 2, gy - h - w - 6), (x + w + 1, gy - h)], c)
        if flag:
            fx = x + w // 2
            L.rect(fx, gy - h - w - 16, 1, 11, c)
            L.poly([(fx + 1, gy - h - w - 16), (fx + 9, gy - h - w - 13), (fx + 1, gy - h - w - 10)], flag)
    else:
        for bx in range(x - 1, x + w + 1, 4):
            L.rect(bx, gy - h - 4, 2, 4, c)
    if win:
        for wy in range(gy - h + 6, gy - 8, 14):
            L.rect(x + w // 2 - 1, wy, 2, 5, win, glow=True)


def column(L, x, gy, h, c, broken=False, w=6):
    L.rect(x, gy - h, w, h, c)
    L.rect(x - 2, gy - 4, w + 4, 4, c)
    if not broken:
        L.rect(x - 2, gy - h - 3, w + 4, 3, c)
    else:
        L.poly([(x, gy - h), (x + w, gy - h - 4), (x + w, gy - h + 3), (x, gy - h + 5)], c)


def arch(L, x, gy, w, h, c, thick=5):
    L.rect(x, gy - h, thick, h, c)
    L.rect(x + w - thick, gy - h, thick, h, c)
    for i in range(w):
        t = i / max(1, w - 1)
        y = gy - h - int(math.sin(t * math.pi) * w * 0.45)
        L.rect(x + i, y - thick, 1, thick + 2, c)


def battlement(L, y, c, win, rng, h):
    L.rect(0, y, W, h - y, c)
    for bx in range(0, W, 12):
        L.rect(bx, y - 6, 7, 6, c)
    for bx in range(24, W, 96):
        tower(L, bx, y + 2, 20, 42 + int(rng.integers(0, 20)), c, win, cone=False)


def cloud_img(w, h, rng, col, shade, hi):
    """Nuvem fofa em 3 tons (para as nuvens que andam)."""
    L = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    blobs = []
    for i in range(7):
        r = int(rng.integers(h // 4, h // 2))
        cx = int(rng.integers(r, w - r))
        cy = h - r - int(rng.integers(0, max(1, h // 3)))
        blobs.append((cx, cy, r))
    for cx, cy, r in blobs:
        d.ellipse([cx - r, cy - r + 2, cx + r, cy + r + 2], fill=shade + (235,))
    for cx, cy, r in blobs:
        d.ellipse([cx - r, cy - r, cx + r, cy + r - 1], fill=col + (240,))
    for cx, cy, r in blobs:
        d.ellipse([cx - r + 2, cy - r, cx + r - 4, cy - r // 3], fill=hi + (245,))
    d.rectangle([4, h - 3, w - 5, h - 1], fill=shade + (230,))
    return L


# ---------------------------------------------------------------------------
# Céu
# ---------------------------------------------------------------------------

def sky(style):
    s = style["sky"]
    stops = [rgb(c) for c in s["colors"]]
    bands = []
    for i in range(len(stops) - 1):
        for k in range(8):
            bands.append(mix(stops[i], stops[i + 1], k / 8))
    bands.append(stops[-1])
    a = np.zeros((SKY_H, SKY_W, 3))
    nb = len(bands)
    band_h = SKY_H / nb
    for y in range(SKY_H):
        b = min(int(y / band_h), nb - 1)
        into = y - b * band_h
        row = np.array(bands[b], dtype=np.float64)
        a[y, :] = row
        if b + 1 < nb and into > band_h - 4:
            f = (into - (band_h - 4)) / 4.0
            m = f > BAYER[y % 4, np.arange(SKY_W) % 4]
            a[y, m] = bands[b + 1]
    rng = np.random.default_rng(style["seed"])
    for _ in range(s.get("stars", 0)):
        x, y = int(rng.integers(0, SKY_W)), int(rng.integers(0, int(SKY_H * 0.6)))
        b = int(rng.integers(130, 256))
        a[y, x] = (b, b, min(255, b + 25))
        if rng.random() < 0.07 and 1 < x < SKY_W - 2 and 1 < y < SKY_H - 2:
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                a[y + dy, x + dx] = a[y + dy, x + dx] * 0.4 + np.array([b, b, 255]) * 0.6
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    if "sun" in s:
        sx, sy, r = int(s["sun"]["pos"][0] * 1.875), int(s["sun"]["pos"][1] * 1.875), int(s["sun"]["r"] * 1.875)
        core = rgb(s["sun"]["color"])
        halo = rgb(s["sun"].get("halo", s["sun"]["color"]))
        glow = s["sun"].get("glow", 0.35)
        px = np.array(img).astype(np.float64)
        yy, xx = np.mgrid[0:SKY_H, 0:SKY_W]
        dist = np.hypot(xx - sx, yy - sy)
        for ring, al in [(r * 3.2, glow * 0.22), (r * 2.2, glow * 0.38), (r * 1.5, glow * 0.6)]:
            m = dist <= ring
            px[m, :3] = px[m, :3] * (1 - al) + np.array(halo) * al
        img = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")
        d = ImageDraw.Draw(img)
        d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=core + (255,))
        if s["sun"].get("moon"):
            for cx, cy, cr in [(-6, -4, 4), (4, 6, 3), (7, -6, 2), (-2, 8, 2)]:
                d.ellipse([sx + cx - cr, sy + cy - cr, sx + cx + cr, sy + cy + cr], fill=darken(core, 0.1) + (255,))
            # sombra do lado oposto à luz
            d.ellipse([sx - r + 3, sy - r - 2, sx + r + 5, sy + r - 2], outline=None)
        else:
            d.ellipse([sx - r + 2, sy - r + 2, sx + r // 3, sy + r // 3], fill=lighten(core, 0.4) + (255,))
    for band in s.get("bands", []):
        y0, col, amt = band
        y0 = int(y0 * 1.875)
        col = rgb(col)
        nz = pnoise(SKY_W, 10, style["seed"] + y0, 3)
        px = np.array(img)
        for x in range(SKY_W):
            hh = int(nz[x] * 9)
            for yy in range(y0 - hh, y0 + 1):
                if 0 <= yy < SKY_H and amt > BAYER[yy % 4, x % 4]:
                    px[yy, x, :3] = np.array(mix(px[yy, x, :3], col, 0.55))
        img = Image.fromarray(px, "RGBA")
    return img


# ---------------------------------------------------------------------------
# Estilos (cada painter devolve a lista de camadas, longe -> perto)
# ---------------------------------------------------------------------------

def paint_forest(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    rim = rgb(p["far_rim"])
    out = []
    # 0: montanhas distantes com neve
    L = Layer()
    t = ridge(L, 176, 92, 4, st["seed"], rgb(p["far"]), sharp=True)
    snow_caps(L, t, 176, 92, lighten(rgb(p["far"]), 0.4), lighten(rgb(p["far"]), 0.65))
    c = rgb(p["far"])
    volume_pass(L, c, lighten(c, 0.16), darken(c, 0.1), rim, sun_dir=1, radius=12, bump=0.35, bump_cells=18, seed=1, levels=3)
    haze(L, fog, 0.3, 0.62, 80, 270)
    out.append(finish(L))
    # 1: colinas com floresta distante
    L = Layer()
    c1 = mix(rgb(p["far"]), rgb(p["mid"]), 0.45)
    t = ridge(L, 200, 30, 6, st["seed"] + 3, c1, octaves=3)
    x = 0
    while x < W:
        pine(L, x, int(t[x % W]) + 3, int(rng.integers(16, 30)), c1)
        x += int(rng.integers(3, 8))
    volume_pass(L, c1, lighten(c1, 0.18), darken(c1, 0.12), lighten(c1, 0.45), sun_dir=1, radius=4, bump=0.2, seed=2, levels=3)
    haze(L, fog, 0.2, 0.42, 150, 270)
    out.append(finish(L))
    # 2: floresta média (pinheiros e copas)
    L = Layer()
    c2 = mix(rgb(p["mid"]), rgb(p["far"]), 0.25)
    t = ridge(L, 220, 16, 6, st["seed"] + 1, c2, octaves=3)
    x = 0
    while x < W:
        gy = int(t[x % W]) + 4
        if rng.random() < 0.55:
            pine(L, x, gy, int(rng.integers(40, 72)), c2)
        else:
            round_tree(L, x, gy, int(rng.integers(36, 60)), c2, rng)
        x += int(rng.integers(8, 18))
    volume_pass(L, c2, lighten(c2, 0.2), darken(c2, 0.18), rgb(p["mid_hi"]), sun_dir=1, radius=6, bump=0.3, bump_cells=40, seed=3)
    haze(L, fog, 0.14, 0.34, 160, 270)
    out.append(finish(L))
    # 3: floresta perto (mais escura, mais detalhe)
    L = Layer()
    c3 = darken(rgb(p["mid"]), 0.25)
    t = ridge(L, 240, 12, 5, st["seed"] + 4, c3, octaves=2)
    x = 0
    while x < W:
        gy = int(t[x % W]) + 4
        if rng.random() < 0.5:
            pine(L, x, gy, int(rng.integers(70, 120)), c3)
        else:
            round_tree(L, x, gy, int(rng.integers(60, 100)), c3, rng)
        x += int(rng.integers(26, 60))
    volume_pass(L, c3, mix(c3, rgb(p["mid_hi"]), 0.3), darken(c3, 0.3), rgb(p["mid_hi"]), sun_dir=1, radius=8, bump=0.3, bump_cells=50, seed=4)
    out.append(finish(L))
    # 4: primeiro plano: capim alto e troncos (bem escuro, parallax forte)
    L = Layer()
    c4 = rgb(p["near"])
    t = ridge(L, 258, 8, 5, st["seed"] + 2, c4, octaves=2)
    for x in range(0, W, 2):
        if rng.random() < 0.5:
            hh = int(rng.integers(4, 16))
            L.rect(x, int(t[x]) - hh, 1, hh, c4)
    volume_pass(L, c4, lighten(c4, 0.15), darken(c4, 0.3), mix(c4, rgb(p["mid_hi"]), 0.5), sun_dir=1, radius=5, bump=0.5, seed=5, levels=3, rim_w=1)
    out.append(finish(L))
    return out


def paint_castle(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    L = Layer()
    t = ridge(L, 186, 90, 3, st["seed"], rgb(p["far"]), sharp=True)
    snow_caps(L, t, 186, 90, lighten(rgb(p["far"]), 0.3), rgb(p["far_rim"]))
    light_pass(L, rgb(p["far"]), rgb(p["far_rim"]), sun_dir=-1, tex=0.02, seed=1)
    haze(L, fog, 0.2, 0.55, 100, 270)
    out.append(finish(L))
    # castelo principal (média distância)
    L = Layer()
    c = rgb(p["mid"])
    win = rgb(p["window"])
    ridge(L, 230, 10, 4, st["seed"] + 1, c, octaves=2)
    for k in range(2):
        cx = int(rng.integers(60, 400)) + k * 480
        L.rect(cx, 150, 200, 82, c)
        for bx in range(cx, cx + 200, 8):
            L.rect(bx, 144, 5, 6, c)
        for i, (tx, th) in enumerate([(cx - 14, 120), (cx + 50, 160), (cx + 120, 110), (cx + 186, 134)]):
            tower(L, tx, 232, 22, th, c, win, cone=i % 2 == 0, flag=rgb(p["flag"]), rng=rng)
        L.poly([(cx + 80, 150), (cx + 100, 124), (cx + 120, 150)], c)
        for wx in range(cx + 12, cx + 190, 18):
            if rng.random() < 0.6:
                L.rect(wx, 170, 3, 6, win, glow=True)
    for i in range(6):
        tower(L, int(rng.integers(0, W)), 232, 14, int(rng.integers(50, 90)), c, win, cone=rng.random() < 0.6, rng=rng)
    light_pass(L, c, rgb(p["far_rim"]), sun_dir=-1, tex=0.04, seed=2)
    haze(L, fog, 0.05, 0.25, 140, 270)
    out.append(finish(L))
    # muralha perto
    L = Layer()
    c = rgb(p["near"])
    battlement(L, 236, c, win, rng, H)
    for bx in range(100, W, 240):
        L.rect(bx, 190, 2, 46, c)
        L.poly([(bx + 2, 190), (bx + 18, 190), (bx + 18, 214), (bx + 10, 206), (bx + 2, 214)], rgb(p["flag"]))
    light_pass(L, c, mix(c, rgb(p["far_rim"]), 0.5), sun_dir=-1, rim_w=1, tex=0.05, seed=3)
    out.append(finish(L))
    return out


def paint_gothic(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    win = rgb(p["window"])
    out = []
    L = Layer()
    fc = rgb(p["far"])
    t = ridge(L, 210, 14, 4, st["seed"], fc, octaves=2)
    for x in range(0, W, 14):
        house(L, x, int(t[x % W]) + 2, int(rng.integers(12, 22)), int(rng.integers(30, 90)), fc, None, rng, roof="peak" if rng.random() < 0.7 else "spire")
    for i in range(4):
        tower(L, int(rng.integers(0, W)), 212, 10, int(rng.integers(110, 150)), fc, cone=True, rng=rng)
    light_pass(L, fc, lighten(fc, 0.35), sun_dir=1, tex=0.02, seed=1)
    haze(L, fog, 0.15, 0.5, 60, 270)
    out.append(finish(L))
    L = Layer()
    mc = rgb(p["mid"])
    ridge(L, 234, 6, 4, st["seed"] + 1, mc, octaves=1)
    x = 0
    while x < W:
        w = int(rng.integers(22, 40))
        house(L, x, 236, w, int(rng.integers(50, 110)), mc, win, rng, roof="peak" if rng.random() < 0.7 else "spire")
        x += w + int(rng.integers(0, 5))
    cx = int(rng.integers(200, 600))
    tower(L, cx, 236, 26, 180, mc, win, rng=rng)
    tower(L, cx + 76, 236, 26, 180, mc, win, rng=rng)
    L.rect(cx, 110, 102, 126, mc)
    L.ellipse(cx + 36, 130, cx + 64, 158, win, glow=True)
    light_pass(L, mc, lighten(mc, 0.4), sun_dir=1, tex=0.04, seed=2)
    haze(L, fog, 0.0, 0.2, 160, 270)
    out.append(finish(L))
    L = Layer()
    nc = rgb(p["near"])
    ridge(L, 254, 3, 4, st["seed"] + 2, nc, octaves=1)
    for x in range(0, W, 90):
        L.rect(x + 20, 190, 3, 64, nc)
        L.ellipse(x + 14, 180, x + 28, 194, nc)
        L.rect(x + 18, 185, 7, 6, win, glow=True)
    light_pass(L, nc, lighten(nc, 0.3), sun_dir=1, rim_w=1, tex=0.04, seed=3)
    out.append(finish(L))
    return out


def paint_ruins(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    L = Layer()
    ridge(L, 188, 64, 3, st["seed"], rgb(p["far"]))
    light_pass(L, rgb(p["far"]), rgb(p["far_rim"]), sun_dir=-1, tex=0.02, seed=1)
    haze(L, fog, 0.2, 0.55, 100, 270)
    out.append(finish(L))
    L = Layer()
    c = rgb(p["mid"])
    t = ridge(L, 226, 18, 5, st["seed"] + 1, c, octaves=3)
    x = 10
    while x < W:
        gy = int(t[x % W]) + 3
        r = rng.random()
        if r < 0.35:
            arch(L, x, gy, int(rng.integers(34, 56)), int(rng.integers(40, 70)), c)
            x += 64
        elif r < 0.7:
            column(L, x, gy, int(rng.integers(28, 76)), c, broken=True)
            x += int(rng.integers(18, 36))
        else:
            round_tree(L, x, gy, int(rng.integers(40, 66)), c, rng)
            x += 30
    light_pass(L, c, rgb(p["far_rim"]), sun_dir=-1, tex=0.04, seed=2)
    haze(L, fog, 0.05, 0.3, 160, 270)
    out.append(finish(L))
    L = Layer()
    c = rgb(p["near"])
    t = ridge(L, 252, 8, 4, st["seed"] + 2, c, octaves=2)
    for x in range(0, W, 180):
        ox = x + int(rng.integers(0, 60))
        column(L, ox, int(t[ox % W]) + 3, int(rng.integers(110, 190)), c, broken=True, w=13)
    light_pass(L, c, mix(c, rgb(p["far_rim"]), 0.5), sun_dir=-1, rim_w=1, tex=0.05, seed=3)
    out.append(finish(L))
    return out


def paint_desert(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    L = Layer()
    c = rgb(p["far"])
    ridge(L, 176, 34, 3, st["seed"], c, octaves=2)
    for k in range(3):
        px = int(rng.integers(0, W))
        pw = int(rng.integers(60, 110))
        L.poly([(px - pw, 180), (px, 180 - pw * 0.8), (px + pw, 180)], lighten(c, 0.08))
        # face na sombra
        L.poly([(px, 180 - pw * 0.8), (px + pw, 180), (px + pw * 0.2, 180)], darken(c, 0.14))
    light_pass(L, c, rgb(p["far_rim"]), sun_dir=-1, tex=0.02, seed=1)
    haze(L, fog, 0.25, 0.55, 110, 270)
    out.append(finish(L))
    L = Layer()
    c = rgb(p["mid"])
    t = ridge(L, 204, 30, 5, st["seed"] + 1, c, octaves=3)
    for x in range(0, W, 60):
        if rng.random() < 0.4:
            gx = x + int(rng.integers(0, 40))
            gy = int(t[gx % W]) + 2
            L.rect(gx, gy - 30, 3, 30, darken(c, 0.2))
            for ang in range(5):
                a = -math.pi / 2 + (ang - 2) * 0.55
                L.line([(gx + 1, gy - 30), (gx + 1 + math.cos(a) * 14, gy - 30 + math.sin(a) * 9 + 5)], darken(c, 0.2), 2)
    light_pass(L, c, rgb(p["mid_hi"]), sun_dir=-1, tex=0.04, seed=2)
    # ondulações da areia
    a = L.array()
    for y in range(0, H, 5):
        for x in range(W):
            if a[y, x, 3] > 0 and (x + y * 3) % 9 < 5:
                a[y, x, :3] *= 0.92
    L.set_array(a)
    haze(L, fog, 0.05, 0.2, 170, 270)
    out.append(finish(L))
    L = Layer()
    c = rgb(p["near"])
    ridge(L, 232, 16, 4, st["seed"] + 2, c, octaves=2)
    light_pass(L, c, rgb(p["near_hi"]), sun_dir=-1, rim_w=2, tex=0.05, seed=3)
    out.append(finish(L))
    return out


def paint_sky(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    # mar de nuvens distante
    L = Layer()
    c = rgb(p["cloud"])
    nz = pnoise(W, 14, st["seed"], 4)
    tops = (170 - nz * 26).astype(int)
    L.fill_below(tops, c)
    for x in range(0, W, 3):
        r = int(rng.integers(6, 16))
        L.ellipse(x - r, tops[x] - r // 2, x + r, tops[x] + r, c)
    light_pass(L, c, rgb(p["cloud_hi"]), sun_dir=1, top_light=0.12, bottom_dark=0.1, tex=0.02, seed=1)
    haze(L, fog, 0.15, 0.35, 150, 270)
    out.append(finish(L))
    # ilhas flutuantes com torres
    L = Layer()
    c = rgb(p["mid"])
    for k in range(4):
        ix = int(rng.integers(0, W))
        iy = int(rng.integers(90, 170))
        iw = int(rng.integers(50, 100))
        L.poly([(ix - iw // 2, iy), (ix + iw // 2, iy), (ix + iw // 6, iy + iw * 0.7), (ix, iy + iw * 0.9), (ix - iw // 5, iy + iw * 0.6)], c)
        L.rect(ix - iw // 2, iy - 3, iw, 4, rgb(p["mid_hi"]))
        tower(L, ix - 8, iy - 2, 12, int(rng.integers(30, 60)), lighten(c, 0.15), rgb(p["window"]), cone=True, rng=rng)
        # cascata
        L.rect(ix + iw // 4, iy, 2, int(iw * 0.9), lighten(rgb(p["cloud_hi"]), 0.0))
    light_pass(L, c, lighten(rgb(p["cloud_hi"]), 0.0), sun_dir=1, tex=0.03, seed=2)
    haze(L, fog, 0.1, 0.25, 60, 270)
    out.append(finish(L))
    # nuvens perto (primeiro plano)
    L = Layer()
    c = rgb(p["near"])
    nz = pnoise(W, 8, st["seed"] + 5, 3)
    tops = (224 - nz * 20).astype(int)
    L.fill_below(tops, c)
    for x in range(0, W, 5):
        r = int(rng.integers(10, 24))
        L.ellipse(x - r, tops[x] - r // 2, x + r, tops[x] + r, c)
    light_pass(L, c, rgb(p["near_hi"]), sun_dir=1, top_light=0.1, bottom_dark=0.12, tex=0.02, seed=3)
    out.append(finish(L))
    return out


def paint_cave(st, rng):
    p = st["pal"]
    out = []
    L = Layer()
    fc = rgb(p["far"])
    L.rect(0, 0, W, H, fc)
    for i in range(16):
        x = int(rng.integers(0, W))
        y = int(rng.integers(30, 220))
        L.ellipse(x - 34, y - 20, x + 34, y + 20, rgb(p["far_hi"]))
    for i in range(40):
        x = int(rng.integers(0, W))
        y = int(rng.integers(20, 250))
        cc = rgb(p["crystal"])
        sz = int(rng.integers(2, 6))
        L.poly([(x, y - sz * 2), (x + sz, y), (x, y + sz), (x - sz, y)], cc, glow=True)
    light_pass(L, fc, rgb(p["far_hi"]), sun_dir=1, top_light=0.0, bottom_dark=0.0, rim_w=1, tex=0.05, seed=1)
    out.append(finish(L))
    L = Layer()
    mc = rgb(p["mid"])
    nz = pnoise(W, 12, st["seed"] + 1, 3)
    nz2 = pnoise(W, 10, st["seed"] + 2, 3)
    for x in range(W):
        top = int(18 + nz[x] * 44)
        bot = int(252 - nz2[x] * 50)
        L.rect(x, 0, 1, top, mc)
        L.rect(x, bot, 1, H - bot, mc)
    for i in range(30):
        x = int(rng.integers(0, W))
        ln = int(rng.integers(16, 54))
        L.poly([(x - 6, 30), (x + 6, 30), (x, 30 + ln)], mc)
        x2 = int(rng.integers(0, W))
        L.poly([(x2 - 6, 236), (x2 + 6, 236), (x2, 236 - ln // 2)], mc)
    for i in range(10):
        x = int(rng.integers(0, W))
        cc = rgb(p["crystal"])
        for k in range(3):
            h2 = int(rng.integers(8, 20))
            ox = x + k * 5 - 5
            L.poly([(ox - 2, 238), (ox + 2, 238), (ox + (k - 1) * 3, 238 - h2)], cc, glow=True)
    light_pass(L, mc, lighten(mc, 0.5), sun_dir=1, top_light=0.0, bottom_dark=0.0, rim_w=1, tex=0.04, seed=2)
    out.append(finish(L))
    L = Layer()
    nc = rgb(p["near"])
    for i in range(12):
        x = int(rng.integers(0, W))
        ln = int(rng.integers(60, 120))
        L.poly([(x - 12, 0), (x + 12, 0), (x, ln)], nc)
    nz = pnoise(W, 6, st["seed"] + 3, 2)
    for x in range(W):
        bot = int(258 - nz[x] * 22)
        L.rect(x, bot, 1, H - bot, nc)
    light_pass(L, nc, lighten(nc, 0.4), sun_dir=1, top_light=0.0, bottom_dark=0.0, rim_w=1, tex=0.04, seed=3)
    out.append(finish(L))
    return out


def paint_war(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    L = Layer()
    ridge(L, 196, 76, 3, st["seed"], rgb(p["far"]), sharp=True)
    light_pass(L, rgb(p["far"]), rgb(p["far_rim"]), sun_dir=-1, tex=0.02, seed=1)
    haze(L, fog, 0.1, 0.45, 100, 270)
    out.append(finish(L))
    L = Layer()
    mc = rgb(p["mid"])
    t = ridge(L, 232, 10, 4, st["seed"] + 1, mc, octaves=2)
    x = 0
    while x < W:
        r = rng.random()
        gy = int(t[x % W]) + 2
        if r < 0.3:
            # tenda
            w = int(rng.integers(30, 50))
            L.poly([(x, gy), (x + w // 2, gy - w // 2 - 6), (x + w, gy)], mc)
            L.rect(x + w // 2 - 1, gy - w // 2 - 14, 2, 10, mc)
            x += w + 10
        elif r < 0.55:
            # paliçada
            for k in range(8):
                hh = int(rng.integers(20, 30))
                L.poly([(x + k * 5, gy), (x + k * 5 + 4, gy), (x + k * 5 + 4, gy - hh), (x + k * 5 + 2, gy - hh - 4), (x + k * 5, gy - hh)], mc)
            x += 50
        elif r < 0.7:
            # torre de vigia com fogueira
            L.rect(x, gy - 60, 4, 60, mc)
            L.rect(x + 16, gy - 60, 4, 60, mc)
            L.rect(x - 4, gy - 66, 28, 8, mc)
            L.rect(x + 7, gy - 72, 6, 5, rgb(p["window"]), glow=True)
            x += 40
        else:
            x += int(rng.integers(10, 30))
    light_pass(L, mc, rgb(p["far_rim"]), sun_dir=-1, tex=0.04, seed=2)
    haze(L, fog, 0.0, 0.2, 170, 270)
    out.append(finish(L))
    L = Layer()
    nc = rgb(p["near"])
    t = ridge(L, 254, 6, 4, st["seed"] + 2, nc, octaves=2)
    for x in range(0, W, 7):
        if rng.random() < 0.5:
            hh = int(rng.integers(14, 34))
            L.poly([(x, t[x] + 2), (x + 3, t[x] + 2), (x + 1, t[x] - hh)], nc)
    for x in range(40, W, 200):
        L.rect(x, 186, 2, 70, nc)
        L.poly([(x + 2, 186), (x + 22, 190), (x + 2, 200)], rgb(p["flag"]))
    light_pass(L, nc, mix(nc, rgb(p["far_rim"]), 0.5), sun_dir=-1, rim_w=1, tex=0.05, seed=3)
    out.append(finish(L))
    return out


def paint_graveyard(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    L = Layer()
    fc = rgb(p["far"])
    t = ridge(L, 214, 30, 3, st["seed"], fc, octaves=3)
    cx = int(rng.integers(100, 700))
    L.rect(cx, 150, 60, 66, fc)
    L.poly([(cx - 4, 150), (cx + 30, 120), (cx + 64, 150)], fc)
    L.rect(cx + 40, 100, 14, 60, fc)
    L.poly([(cx + 38, 100), (cx + 47, 70), (cx + 56, 100)], fc)
    L.rect(cx + 46, 58, 2, 14, fc)
    L.rect(cx + 42, 62, 10, 2, fc)
    L.rect(cx + 24, 170, 8, 14, rgb(p["window"]), glow=True)
    light_pass(L, fc, rgb(p["far_rim"]), sun_dir=1, tex=0.03, seed=1)
    haze(L, fog, 0.15, 0.45, 110, 270)
    out.append(finish(L))
    L = Layer()
    mc = rgb(p["mid"])
    t = ridge(L, 236, 10, 4, st["seed"] + 1, mc, octaves=2)
    x = 0
    while x < W:
        gy = int(t[x % W]) + 2
        r = rng.random()
        if r < 0.25:
            dead_tree(L, x, gy, int(rng.integers(50, 90)), mc, rng, 4)
            x += 40
        elif r < 0.6:
            L.rect(x, gy - 14, 8, 14, mc)
            L.ellipse(x, gy - 18, x + 8, gy - 10, mc)
            x += 16
        else:
            L.rect(x + 3, gy - 20, 3, 20, mc)
            L.rect(x, gy - 15, 9, 3, mc)
            x += 18
    light_pass(L, mc, rgb(p["far_rim"]), sun_dir=1, tex=0.04, seed=2)
    haze(L, fog, 0.05, 0.3, 170, 270)
    out.append(finish(L))
    L = Layer()
    nc = rgb(p["near"])
    t = ridge(L, 256, 4, 4, st["seed"] + 2, nc, octaves=2)
    for x in range(30, W, 150):
        dead_tree(L, x, int(t[x % W]) + 3, int(rng.integers(120, 180)), nc, rng, 6)
    light_pass(L, nc, mix(nc, rgb(p["far_rim"]), 0.45), sun_dir=1, rim_w=1, tex=0.04, seed=3)
    out.append(finish(L))
    return out


def paint_swamp(st, rng):
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    L = Layer()
    ridge(L, 200, 32, 3, st["seed"], rgb(p["far"]), octaves=3)
    light_pass(L, rgb(p["far"]), lighten(rgb(p["far"]), 0.3), sun_dir=1, tex=0.02, seed=1)
    haze(L, fog, 0.3, 0.6, 120, 270)
    out.append(finish(L))
    L = Layer()
    mc = rgb(p["mid"])
    t = ridge(L, 218, 8, 4, st["seed"] + 1, mc, octaves=2)
    for x in range(0, W, 48):
        ox = x + int(rng.integers(0, 22))
        hh = int(rng.integers(56, 100))
        gy = int(t[ox % W]) + 3
        dead_tree(L, ox, gy, hh, mc, rng, 5)
        for k in range(5):
            L.rect(ox + int(rng.integers(-12, 13)), gy - hh + 12 + k * 9, 1, int(rng.integers(8, 20)), mc)
    light_pass(L, mc, lighten(mc, 0.4), sun_dir=1, tex=0.04, seed=2)
    haze(L, fog, 0.05, 0.3, 150, 240)
    reflect(L, 222, rgb(p["water"]), 0.5)
    out.append(finish(L))
    L = Layer()
    nc = rgb(p["near"])
    t = ridge(L, 250, 6, 5, st["seed"] + 2, nc, octaves=2)
    for x in range(0, W, 2):
        if rng.random() < 0.55:
            hh = int(rng.integers(5, 22))
            L.rect(x, int(t[x]) - hh, 1, hh, nc)
    light_pass(L, nc, lighten(nc, 0.35), sun_dir=1, rim_w=1, tex=0.04, seed=3)
    out.append(finish(L))
    return out



# ---------------------------------------------------------------------------
# Áreas feitas à mão (direção de arte estilo Hollow Knight: escuro, névoa,
# silhuetas em camadas e poucas luzes quentes)
# ---------------------------------------------------------------------------

def paint_galerias(st, rng):
    """Galerias Apagadas: arcadas dos Lampadeiros sumindo na névoa azul,
    algumas lâmpadas ainda acesas lá longe, colunas e estalactites."""
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    # l0: galeria distante — arcos em fileira e lampiões minúsculos
    L = Layer()
    fc = rgb(p["far"])
    L.rect(0, 0, W, 40, fc)
    L.rect(0, 200, W, 70, fc)
    x = 0
    while x < W:
        w = int(rng.integers(46, 70))
        arch(L, x, 200, w, int(rng.integers(90, 120)), fc, thick=6)
        if rng.random() < 0.55:
            ly = 200 - int(rng.integers(40, 70))
            L.rect(x + w // 2, 40, 1, ly - 40, fc)
            L.rect(x + w // 2 - 1, ly, 3, 4, rgb(p["lamp"]), glow=True)
        x += w
    light_pass(L, fc, rgb(p["far_rim"]), sun_dir=1, top_light=0.0, bottom_dark=0.0, rim_w=1, tex=0.03, seed=1)
    haze(L, fog, 0.35, 0.55, 0, 270)
    out.append(finish(L))
    # l1: colunas e estalactites grandes
    L = Layer()
    mc = rgb(p["mid"])
    nz = pnoise(W, 10, st["seed"] + 1, 3)
    for x in range(W):
        L.rect(x, 0, 1, int(14 + nz[x] * 30), mc)
        L.rect(x, int(236 - nz[(x * 3) % W] * 24), 1, 40, mc)
    for i in range(22):
        x = int(rng.integers(0, W))
        ln = int(rng.integers(20, 70))
        wd = int(rng.integers(5, 12))
        L.poly([(x - wd, 30), (x + wd, 30), (x, 30 + ln)], mc)
    for x in range(40, W, 160):
        cx = x + int(rng.integers(-20, 20))
        column(L, cx, 240, int(rng.integers(150, 200)), mc, broken=rng.random() < 0.4, w=int(rng.integers(12, 18)))
    for i in range(6):
        x = int(rng.integers(0, W))
        L.rect(x, 30, 1, int(rng.integers(40, 90)), mc)
    light_pass(L, mc, rgb(p["mid_rim"]), sun_dir=1, top_light=0.0, bottom_dark=0.1, rim_w=1, tex=0.04, seed=2)
    haze(L, fog, 0.12, 0.3, 0, 270)
    out.append(finish(L))
    # l2: rocha escura perto (moldura)
    L = Layer()
    nc = rgb(p["near"])
    nz = pnoise(W, 6, st["seed"] + 3, 3)
    for x in range(W):
        L.rect(x, 0, 1, int(6 + nz[x] * 26), nc)
        L.rect(x, int(250 - nz[(x * 2) % W] * 26), 1, 30, nc)
    for i in range(10):
        x = int(rng.integers(0, W))
        ln = int(rng.integers(40, 100))
        L.poly([(x - 10, 0), (x + 10, 0), (x + int(rng.integers(-3, 4)), ln)], nc)
    light_pass(L, nc, mix(nc, rgb(p["mid_rim"]), 0.5), sun_dir=1, top_light=0.0, bottom_dark=0.0, rim_w=1, tex=0.03, seed=3)
    out.append(finish(L))
    return out


def paint_bosque(st, rng):
    """Bosque Sussurrante: troncos gigantes e raízes descendo do teto,
    cogumelos que brilham, samambaias, névoa verde."""
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    # l0: troncos distantes e raízes penduradas
    L = Layer()
    fc = rgb(p["far"])
    L.rect(0, 0, W, 30, fc)
    ridge(L, 214, 16, 4, st["seed"], fc, octaves=3)
    for x in range(20, W, 90):
        tx = x + int(rng.integers(-20, 20))
        tw = int(rng.integers(16, 30))
        L.poly([(tx - tw, 230), (tx - tw * 0.6, 120), (tx - tw * 0.8, 0), (tx + tw * 0.8, 0), (tx + tw * 0.6, 120), (tx + tw, 230)], fc)
    for i in range(40):
        x = int(rng.integers(0, W))
        ln = int(rng.integers(30, 120))
        pts = [(x + math.sin(k * 0.7 + i) * 4, 30 + ln * k / 8) for k in range(9)]
        L.line(pts, fc, width=2)
    for i in range(30):
        x = int(rng.integers(0, W))
        y = int(rng.integers(150, 220))
        L.rect(x, y, 2, 2, rgb(p["glow"]), glow=True)
    light_pass(L, fc, rgb(p["far_rim"]), sun_dir=1, top_light=0.0, bottom_dark=0.0, rim_w=1, tex=0.03, seed=1)
    haze(L, fog, 0.3, 0.55, 0, 270)
    out.append(finish(L))
    # l1: cogumelos gigantes, raízes grossas, samambaias
    L = Layer()
    mc = rgb(p["mid"])
    t = ridge(L, 232, 12, 4, st["seed"] + 1, mc, octaves=2)
    L.rect(0, 0, W, 16, mc)
    for x in range(30, W, 120):
        mx = x + int(rng.integers(-30, 30))
        gy = int(t[mx % W]) + 2
        hh = int(rng.integers(50, 90))
        L.rect(mx - 2, gy - hh, 5, hh, mc)
        rr = int(rng.integers(18, 30))
        L.ellipse(mx - rr, gy - hh - rr // 2, mx + rr, gy - hh + rr // 3, mc)
        for k in range(5):
            L.rect(mx - rr + 6 + k * (rr // 3), gy - hh - 1, 2, 2, rgb(p["glow"]), glow=True)
    for i in range(16):
        x = int(rng.integers(0, W))
        ln = int(rng.integers(40, 110))
        pts = [(x + math.sin(k * 0.9 + i) * 6, 12 + ln * k / 8) for k in range(9)]
        L.line(pts, mc, width=4)
    for x in range(0, W, 3):
        if rng.random() < 0.35:
            hh = int(rng.integers(6, 18))
            gy = int(t[x % W])
            L.line([(x, gy), (x + int(rng.integers(-4, 5)), gy - hh)], mc, width=1)
    light_pass(L, mc, rgb(p["mid_rim"]), sun_dir=1, top_light=0.0, bottom_dark=0.1, rim_w=1, tex=0.04, seed=2)
    haze(L, fog, 0.1, 0.28, 0, 270)
    out.append(finish(L))
    # l2: raízes e galhos pretos perto
    L = Layer()
    nc = rgb(p["near"])
    t = ridge(L, 252, 8, 5, st["seed"] + 2, nc, octaves=2)
    for x in range(0, W, 140):
        rx = x + int(rng.integers(0, 60))
        pts = [(rx + math.sin(k * 0.5) * 12, k * 14) for k in range(10)]
        L.line(pts, nc, width=7)
    for x in range(0, W, 2):
        if rng.random() < 0.5:
            hh = int(rng.integers(6, 24))
            L.line([(x, int(t[x])), (x + int(rng.integers(-5, 6)), int(t[x]) - hh)], nc, width=1)
    light_pass(L, nc, mix(nc, rgb(p["mid_rim"]), 0.5), sun_dir=1, rim_w=1, tex=0.03, seed=3)
    out.append(finish(L))
    return out


def paint_cinzal(st, rng):
    """Cinzal ao crepúsculo eterno: serras escuras contra o céu cor de
    brasa, o grande Farol de Ignara apagado ao longe, a floresta morta."""
    p = st["pal"]
    fog = rgb(st["fog"])
    out = []
    # l0: serras e o farol
    L = Layer()
    fc = rgb(p["far"])
    t = ridge(L, 190, 40, 3, st["seed"], fc, octaves=4)
    fx = int(rng.integers(300, 500))
    gy = int(t[fx]) + 4
    L.poly([(fx - 12, gy), (fx - 7, gy - 100), (fx + 7, gy - 100), (fx + 12, gy)], fc)
    L.rect(fx - 10, gy - 108, 20, 8, fc)
    L.poly([(fx - 8, gy - 108), (fx - 6, gy - 124), (fx + 1, gy - 121), (fx + 4, gy - 128), (fx + 8, gy - 108)], fc)
    L.rect(fx - 1, gy - 116, 3, 3, rgb(p["ember"]), glow=True)
    for x in range(0, W, 70):
        tx = x + int(rng.integers(0, 40))
        tower(L, tx, int(t[tx % W]) + 6, int(rng.integers(8, 14)), int(rng.integers(20, 50)), fc, None, cone=rng.random() < 0.5)
    light_pass(L, fc, rgb(p["far_rim"]), sun_dir=-1, tex=0.03, seed=1)
    haze(L, fog, 0.25, 0.5, 100, 270)
    out.append(finish(L))
    # l1: floresta morta e casas em ruína
    L = Layer()
    mc = rgb(p["mid"])
    t = ridge(L, 224, 12, 4, st["seed"] + 1, mc, octaves=2)
    x = 0
    while x < W:
        gy = int(t[x % W]) + 2
        r = rng.random()
        if r < 0.45:
            dead_tree(L, x, gy, int(rng.integers(50, 100)), mc, rng, 4)
            x += int(rng.integers(26, 50))
        elif r < 0.6:
            house(L, x, gy, int(rng.integers(18, 28)), int(rng.integers(14, 22)), mc, rgb(p["window"]) if rng.random() < 0.3 else None, rng)
            x += 40
        else:
            x += int(rng.integers(10, 30))
    light_pass(L, mc, rgb(p["far_rim"]), sun_dir=-1, tex=0.04, seed=2)
    haze(L, fog, 0.08, 0.3, 150, 270)
    out.append(finish(L))
    # l2: colinas escuras com capim seco
    L = Layer()
    nc = rgb(p["near"])
    t = ridge(L, 250, 8, 4, st["seed"] + 2, nc, octaves=2)
    for x in range(0, W, 2):
        if rng.random() < 0.5:
            hh = int(rng.integers(4, 16))
            L.line([(x, int(t[x])), (x + int(rng.integers(-3, 4)), int(t[x]) - hh)], nc, width=1)
    for x in range(60, W, 220):
        dead_tree(L, x, int(t[x % W]) + 3, int(rng.integers(110, 160)), nc, rng, 6)
    light_pass(L, nc, mix(nc, rgb(p["far_rim"]), 0.4), sun_dir=-1, rim_w=1, tex=0.04, seed=3)
    out.append(finish(L))
    return out


PAINTERS = {
    "forest": paint_forest, "castle": paint_castle, "gothic": paint_gothic, "ruins": paint_ruins,
    "desert": paint_desert, "sky": paint_sky, "cave": paint_cave, "war": paint_war,
    "graveyard": paint_graveyard, "swamp": paint_swamp,
    "galerias": paint_galerias, "bosque": paint_bosque, "cinzal": paint_cinzal,
}

# Cada estilo: céu, paleta das camadas, névoa, parallax e o evento animado
# (desenhado pelo jogo por cima das camadas). Posições do sol/lua e das
# faixas de nuvem estão em coordenadas da tela antiga (256x144) e são
# convertidas (x1.875).
STYLES = {
    "galerias": {
        "seed": 131, "painter": "galerias",
        "sky": {"colors": ["#05060b", "#0b0f1a", "#121a2a", "#0c111c"]},
        "pal": {"far": "#1a2336", "far_rim": "#3a4c6e", "mid": "#101626", "mid_rim": "#2e3a58", "near": "#06080e", "lamp": "#ffc070"},
        "fog": "#2a3858", "fog_alpha": 0.12, "event": "eyes", "underground": True,
        "parallax": [0.08, 0.22, 0.45],
    },
    "bosque": {
        "seed": 137, "painter": "bosque",
        "sky": {"colors": ["#030604", "#08120c", "#0e1e14", "#08100a"]},
        "pal": {"far": "#132218", "far_rim": "#2e4c38", "mid": "#0b1610", "mid_rim": "#24402c", "near": "#040906", "glow": "#7af0d0"},
        "fog": "#1e3a2c", "fog_alpha": 0.14, "event": "wisps", "underground": True,
        "parallax": [0.08, 0.22, 0.45],
    },
    "cinzal": {
        "seed": 139, "painter": "cinzal",
        "sky": {"colors": ["#120e1c", "#2a1a2e", "#5a2a34", "#a8502e", "#3a1e22"], "sun": {"pos": [150, 92], "r": 13, "color": "#ffc080", "halo": "#ff7040", "glow": 0.5},
                "stars": 40, "bands": [[80, "#7a3a38", 0.35], [96, "#c0603a", 0.3]]},
        "pal": {"far": "#3a2432", "far_rim": "#e0784a", "mid": "#1e141c", "near": "#0c080c", "window": "#ffb050", "ember": "#ff9040"},
        "fog": "#7a3e44", "fog_alpha": 0.16, "event": "bats", "cloud": "#5a3440",
        "parallax": [0.05, 0.18, 0.4],
    },
    "forest": {
        "seed": 11, "painter": "forest",
        "sky": {"colors": ["#5f9fd8", "#9fd0ee", "#dff0e2", "#fff0c4"], "sun": {"pos": [196, 34], "r": 7, "color": "#fff8dc", "halo": "#fff2b0", "glow": 0.45},
                "bands": [[62, "#ffffff", 0.35], [88, "#fff6e0", 0.25]]},
        "pal": {"far": "#86aeb4", "far_rim": "#d8ecd8", "mid": "#3f7058", "mid_hi": "#8cc07a", "near": "#1a3326"},
        "fog": "#e4f2e4", "fog_alpha": 0.16, "event": "birds", "birds": True, "rays": True, "cloud": "#ffffff",
        "parallax": [0.03, 0.08, 0.16, 0.3, 0.62],
    },
    "castle": {
        "seed": 23, "painter": "castle",
        "sky": {"colors": ["#171a36", "#343766", "#86698c", "#e6a486"], "sun": {"pos": [60, 40], "r": 9, "color": "#f8e8d0", "halo": "#f0c0a0", "glow": 0.3, "moon": True},
                "stars": 80, "bands": [[70, "#c09ab0", 0.3]]},
        "pal": {"far": "#565075", "far_rim": "#b09ab8", "mid": "#2a2744", "near": "#141226", "window": "#ffc860", "flag": "#b83a3a"},
        "fog": "#9a8ab8", "fog_alpha": 0.12, "event": "storm",
        "parallax": [0.05, 0.16, 0.4],
    },
    "gothic": {
        "seed": 31, "painter": "gothic",
        "sky": {"colors": ["#11152a", "#232946", "#46466a", "#766678"], "sun": {"pos": [206, 30], "r": 11, "color": "#e8e8f0", "halo": "#a0a8c8", "glow": 0.35, "moon": True},
                "stars": 60, "bands": [[56, "#50506a", 0.4]]},
        "pal": {"far": "#363854", "mid": "#1d1f36", "near": "#0e0e1c", "window": "#ffd070"},
        "fog": "#6a6a90", "fog_alpha": 0.2, "event": "titan", "weather": "rain",
        "parallax": [0.06, 0.2, 0.42],
    },
    "ruins": {
        "seed": 47, "painter": "ruins",
        "sky": {"colors": ["#5474b4", "#dc9ca0", "#f6c68e", "#ffe6ae"], "sun": {"pos": [70, 78], "r": 12, "color": "#fff0c0", "halo": "#ffc890", "glow": 0.55},
                "bands": [[50, "#f8d0c0", 0.35], [66, "#ffe0c0", 0.3]]},
        "pal": {"far": "#aa86a0", "far_rim": "#ffd8bc", "mid": "#644a5e", "mid_hi": "#907080", "near": "#301f34"},
        "fog": "#ffd8b8", "fog_alpha": 0.18, "event": "birds", "birds": True, "rays": True, "cloud": "#ffe8d8",
        "parallax": [0.05, 0.18, 0.4],
    },
    "desert": {
        "seed": 53, "painter": "desert",
        "sky": {"colors": ["#4284cc", "#84bce6", "#eedcae", "#ffd690"], "sun": {"pos": [128, 22], "r": 8, "color": "#ffffff", "halo": "#fff0c0", "glow": 0.6}},
        "pal": {"far": "#d4ac86", "far_rim": "#fff0cc", "mid": "#bc8456", "mid_hi": "#f4c08a", "near": "#84563a", "near_hi": "#c48a58"},
        "fog": "#f8e0b0", "fog_alpha": 0.18, "event": "sandworm", "weather": "heat",
        "parallax": [0.05, 0.18, 0.4],
    },
    "sky": {
        "seed": 61, "painter": "sky",
        "sky": {"colors": ["#3272d4", "#72acee", "#c4e2ff", "#ffffff"], "sun": {"pos": [40, 26], "r": 8, "color": "#ffffff", "halo": "#fff8e0", "glow": 0.5},
                "bands": [[44, "#ffffff", 0.3]]},
        "pal": {"far": "#96b0d4", "cloud": "#dfe9fb", "cloud_hi": "#ffffff", "mid": "#64749e", "mid_hi": "#a8e070", "near": "#e6eefa", "near_hi": "#ffffff", "window": "#fff0a0"},
        "fog": "#ffffff", "fog_alpha": 0.18, "event": "whale", "birds": True, "cloud": "#ffffff",
        "parallax": [0.04, 0.16, 0.45],
    },
    "cave": {
        "seed": 71, "painter": "cave",
        "sky": {"colors": ["#0a0a14", "#121222", "#1a1a2e", "#12121e"]},
        "pal": {"far": "#1c1e32", "far_hi": "#262a46", "crystal": "#70e0f0", "mid": "#11121e", "near": "#07070e"},
        "fog": "#3a4870", "fog_alpha": 0.1, "event": "eyes", "underground": True,
        "parallax": [0.06, 0.2, 0.42],
    },
    "war": {
        "seed": 83, "painter": "war",
        "sky": {"colors": ["#361826", "#862e2e", "#de5e3e", "#f6ae5e"], "sun": {"pos": [180, 70], "r": 14, "color": "#ffd8a0", "halo": "#ff8050", "glow": 0.5},
                "bands": [[58, "#40202a", 0.5], [74, "#6a3030", 0.4]]},
        "pal": {"far": "#663240", "far_rim": "#ff8a60", "mid": "#2e1822", "near": "#160a10", "window": "#ffb050", "flag": "#e0c050"},
        "fog": "#c06050", "fog_alpha": 0.16, "event": "catapults", "weather": "embers", "cloud": "#5a3036",
        "parallax": [0.05, 0.18, 0.4],
    },
    "graveyard": {
        "seed": 97, "painter": "graveyard",
        "sky": {"colors": ["#0e1628", "#202c4a", "#3a4a6a", "#667490"], "sun": {"pos": [170, 36], "r": 16, "color": "#f0f0e0", "halo": "#b8c8e0", "glow": 0.45, "moon": True},
                "stars": 110},
        "pal": {"far": "#323e58", "far_rim": "#9aacc8", "mid": "#1c2234", "near": "#0c101c", "window": "#d8f0a0"},
        "fog": "#8898b8", "fog_alpha": 0.22, "event": "bats",
        "parallax": [0.05, 0.18, 0.4],
    },
    "swamp": {
        "seed": 101, "painter": "swamp",
        "sky": {"colors": ["#364c44", "#66866c", "#a4b48c", "#ccd4a4"], "sun": {"pos": [150, 50], "r": 9, "color": "#f0f0c8", "halo": "#d8e0a8", "glow": 0.35},
                "bands": [[64, "#c0c8a0", 0.45], [84, "#d0d8b0", 0.4]]},
        "pal": {"far": "#667c64", "mid": "#364634", "near": "#182014", "water": "#4d6456"},
        "fog": "#c8d8b0", "fog_alpha": 0.26, "event": "wisps", "birds": True, "water": True,
        "parallax": [0.05, 0.18, 0.4],
    },
}


def build(name):
    st = STYLES[name]
    out = os.path.join(OUT, name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png") and (f.startswith("l") or f in ("far.png", "mid.png", "near.png")):
            os.remove(os.path.join(out, f))
            imp = os.path.join(out, f + ".import")
            if os.path.exists(imp):
                os.remove(imp)
    rng = np.random.default_rng(st["seed"])
    sky(st).save(os.path.join(out, "sky.png"))
    layers = PAINTERS[st["painter"]](st, rng)
    for i, img in enumerate(layers):
        img.save(os.path.join(out, "l%d.png" % i))
    # nuvens que andam (3 tons)
    cc = rgb(st.get("cloud", st["fog"]))
    for k in range(4):
        cloud_img(int(rng.integers(60, 110)), int(rng.integers(22, 34)), rng, cc, darken(cc, 0.12), lighten(cc, 0.3)).save(os.path.join(out, "cloud%d.png" % k))
    st["_n"] = len(layers)
    st["_fills"] = [hexs(np.array(img)[-1, :, :3].mean(axis=0).astype(int)) if np.array(img)[-1, :, 3].max() > 0 else "#000000" for img in layers]
    print("ok", name, len(layers), "camadas")


def meta(name):
    st = STYLES[name]
    n = st.get("_n", 3)
    par = st.get("parallax", [0.05, 0.18, 0.4])
    par = (par + [par[-1]] * n)[:n]
    fills = st.get("_fills", ["#000000"] * n)
    return {
        "layers": [{"file": "l%d" % i, "par": par[i], "vpar": round(0.015 + par[i] * 0.18, 3), "fill": fills[i]} for i in range(n)],
        "fog": st["fog"], "fog_alpha": st["fog_alpha"], "event": st.get("event", ""),
        "birds": st.get("birds", False), "rays": st.get("rays", False),
        "weather": st.get("weather", ""), "underground": st.get("underground", False),
        "water": st.get("water", False), "cloud": st.get("cloud", st["fog"]),
    }


def main():
    names = sys.argv[1:] or list(STYLES.keys())
    data = {"_doc": "Gerado por tools/build_scenery.py. Estilos de cenário de fundo (camadas em assets/art/scenery/<estilo>/)."}
    if os.path.exists(DATA):
        with open(DATA) as f:
            data.update(json.load(f))
    for n in names:
        build(n)
        data[n] = meta(n)
    with open(DATA, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
