#!/usr/bin/env python3
"""Sprites dos personagens em pixel art detalhada (densidade 2x: 16 px por
tile), gerados com o kit de tools/spritekit.py.

Saída, para cada personagem <id>:
  assets/art/sprites/<id>/<anim>.png       quadros lado a lado
  assets/art/sprites/<id>/<anim>_glow.png  camada de brilho (se houver)
  data/sprites.json                        metadados: tamanho do quadro,
      origem (pés), fps, loop, e por quadro o ponto da MÃO (onde a arma é
      desenhada) e da CABEÇA (emoções, luz da chama).

Os PNGs são simples (uma tira por animação) para facilitar editar à mão
depois: basta manter o tamanho do quadro. Rode:
    python3 tools/build_sprites.py            (tudo)
    python3 tools/build_sprites.py hero       (só um)
e depois  godot --headless --path . --import
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from spritekit import RES, Canvas, Mat, hexc, preview, save, strip  # noqa: E402
import sprites_enemies as EN  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "art", "sprites")
META = os.path.join(ROOT, "data", "sprites.json")
PREVIEW = os.environ.get("SPRITE_PREVIEW", "")


def lerp(a, b, t):
    return a + (b - a) * t


def ease(t):
    return t * t * (3 - 2 * t)


def wave(t, k=1.0, ph=0.0):
    return math.sin((t * k + ph) * math.tau)


# ===========================================================================
# A FAÍSCA (protagonista)
# Pequena criatura de cinza clara com uma brasa acesa por dentro: cabeça
# redonda de cinza com rachaduras que brilham, olhos de brasa, uma chama
# viva no topo da cabeça (que ilumina o caminho), manto curto esfarrapado e
# um cachecol cor de brasa que esvoaça atrás.
# ===========================================================================

HERO_W, HERO_H, HERO_OX, HERO_OY = 56, 52, 28, 48

M_ASH = Mat(["#6a6272", "#948c98", "#bbb3ae", "#dcd5c9", "#f2ecdf"], rim=0.55, rim_color="#fbf5ea", outline="#231a2a", wrap=0.55, ambient=0.3)
M_CLOAK = Mat(["#15111c", "#1f1a29", "#2b2437", "#3b3249", "#51466a"], rim=0.75, rim_color="#7a6e9a", outline="#0b0810", wrap=0.35)
M_CLOAK_IN = Mat("#7a2c2a", n=4, spread=0.6, rim=0.0, outline="#140a10", wrap=0.2)
M_SCARF = Mat("#b5372a", n=5, spread=0.6, rim=0.75, rim_color="#ff9d66", outline="#260a0c", wrap=0.35)
M_LEG = Mat("#27212f", n=4, spread=0.55, rim=0.6, rim_color="#625a7c", outline="#0c0a10")
M_BOOT = Mat("#1a151f", n=4, spread=0.5, rim=0.55, rim_color="#554c6a", outline="#08060c")
M_GOLD = Mat(["#6a4a22", "#b88a3a", "#f0cc6a", "#fff2b0"], rim=0.0, spec=1.0, outline="#2a1a0a")
M_SOCKET = Mat(["#140c18", "#1c1222", "#241830"], flat=True, rim=0.0, outline="#140c18")

EYE = hexc("#ffc45a")
EYE_CORE = hexc("#fff6d6")
EYE_EDGE = hexc("#ff7a2a")
CRACK = hexc("#ff9a48")
CRACK_DIM = hexc("#b8482a")


def hero_pose(anim, t, i, n):
    """Parâmetros do corpo para a animação `anim` no tempo t (0..1)."""
    p = {
        "bob": 0.0, "lean": 0.0, "head_dx": 0.0, "head_dy": 0.0, "tilt": 0.0,
        "legs": [(-2.5, 0.0, 0.0), (2.5, 0.0, 0.0)],  # (x do pé, y do pé, dobra)
        "hem": 0.0, "flare": 0.0, "scarf_ang": 150.0, "scarf_amp": 1.2, "scarf_ph": t,
        "scarf_len": 15.0, "blink": 0.0, "look": 0.0, "flame_lean": 0.0, "flame_ph": t,
        "flame_h": 9.0, "crouch": 0.0, "eyes": "open", "open": 0.0, "hand": (7.0, -12.0),
        "cloak_up": 0.0, "stretch": 0.0,
    }
    if anim == "idle":
        br = (wave(t) + 1) * 0.5
        p["bob"] = -round(br)
        p["scarf_ang"] = 118 + wave(t) * 6
        p["scarf_amp"] = 0.8
        p["scarf_len"] = 14
        p["blink"] = 1.0 if i == n - 2 else 0.0
        p["flame_h"] = 9 + wave(t, 2) * 1.0
        p["hem"] = wave(t) * 0.5
    elif anim == "run":
        ph = t * math.tau
        s = math.sin(ph)
        c = math.cos(ph)
        p["bob"] = -abs(c) * 1.6 + 0.6
        p["lean"] = 1.5
        p["legs"] = [(-1.0 - s * 4.6, -max(0.0, c) * 2.8, 0.6), (1.5 + s * 4.6, -max(0.0, -c) * 2.8, 0.6)]
        p["hem"] = -2.0 - abs(s) * 0.8
        p["scarf_ang"] = 172 + s * 6
        p["scarf_amp"] = 2.0
        p["scarf_ph"] = t * 2
        p["scarf_len"] = 17
        p["flame_lean"] = -1.2
        p["flame_h"] = 8 + abs(s) * 1.5
    elif anim == "jump":
        p["bob"] = -1.0
        p["legs"] = [(-3.0, -3.0, 1.0), (2.0, -1.0, 0.4)]
        p["hem"] = 1.0
        p["flare"] = -0.5
        p["scarf_ang"] = 205 + i * 8
        p["scarf_amp"] = 1.4
        p["scarf_len"] = 16
        p["flame_lean"] = -0.4
        p["flame_h"] = 7 - i
        p["stretch"] = 1.0
    elif anim == "fall":
        p["legs"] = [(-3.5, -1.0, 0.3), (3.0, -2.0, 0.6)]
        p["hem"] = -0.5
        p["flare"] = 1.4
        p["cloak_up"] = 1.5
        p["scarf_ang"] = 118 - wave(t) * 10
        p["scarf_amp"] = 2.2
        p["scarf_ph"] = t * 2
        p["scarf_len"] = 16
        p["flame_lean"] = 0.3
        p["flame_h"] = 11 + wave(t, 2) * 1.2
    elif anim == "dash":
        p["bob"] = 3.0
        p["lean"] = 4.0
        p["legs"] = [(-6.0, -2.0, 0.8), (1.0, -3.0, 0.9)]
        p["hem"] = -4.0
        p["flare"] = -1.0
        p["scarf_ang"] = 180
        p["scarf_amp"] = 0.8 + i * 0.4
        p["scarf_ph"] = t * 2
        p["scarf_len"] = 19
        p["flame_lean"] = -2.0
        p["flame_h"] = 6
        p["crouch"] = 2.0
        p["eyes"] = "narrow"
    elif anim == "crouch":
        p["bob"] = 3.0 + i * 0.5
        p["legs"] = [(-3.5, 0.0, 1.0), (3.5, 0.0, 1.0)]
        p["crouch"] = 3.0
        p["flare"] = 1.2
        p["scarf_ang"] = 130
        p["scarf_amp"] = 0.6
        p["flame_h"] = 8
    elif anim == "wall":
        p["lean"] = -1.0
        p["legs"] = [(-1.0, -3.0, 0.8), (3.0, -1.0, 0.5)]
        p["hem"] = 1.0
        p["cloak_up"] = 1.0
        p["scarf_ang"] = 95 + wave(t) * 6
        p["scarf_amp"] = 1.4
        p["scarf_ph"] = t * 2
        p["scarf_len"] = 15
        p["flame_lean"] = 0.8
        p["flame_h"] = 10
        p["look"] = -1.0
    elif anim == "climb":
        s = math.sin(t * math.tau)
        p["bob"] = s * 1.2
        p["legs"] = [(-1.0, -2.0 - max(0, s) * 3, 0.9), (2.5, -2.0 - max(0, -s) * 3, 0.9)]
        p["scarf_ang"] = 110
        p["scarf_amp"] = 1.0
        p["flame_h"] = 9
    elif anim == "attack":
        # 0 preparação, 1 golpe, 2 volta
        if i == 0:
            p["lean"] = -1.5
            p["bob"] = 1.0
            p["legs"] = [(-3.5, 0.0, 0.6), (3.0, 0.0, 0.5)]
            p["hem"] = 1.2
            p["scarf_ang"] = 140
            p["hand"] = (-2.0, -16.0)
        elif i == 1:
            p["lean"] = 3.0
            p["bob"] = 1.0
            p["legs"] = [(-4.5, 0.0, 0.7), (4.5, 0.0, 0.8)]
            p["hem"] = -2.5
            p["flare"] = 0.8
            p["scarf_ang"] = 178
            p["scarf_amp"] = 1.8
            p["scarf_len"] = 17
            p["flame_lean"] = -1.5
            p["eyes"] = "narrow"
            p["open"] = 1.0
            p["hand"] = (8.0, -12.0)
        else:
            p["lean"] = 1.5
            p["legs"] = [(-4.0, 0.0, 0.6), (4.0, 0.0, 0.6)]
            p["hem"] = -1.0
            p["scarf_ang"] = 160
            p["scarf_amp"] = 1.3
            p["hand"] = (6.0, -11.0)
    elif anim == "cast":
        p["bob"] = -1.0 if i else 0.0
        p["legs"] = [(-3.5, 0.0, 0.5), (3.5, 0.0, 0.5)]
        p["flare"] = 1.5 + i * 0.4
        p["open"] = 0.6 + i * 0.2
        p["scarf_ang"] = 100 + i * 10
        p["scarf_amp"] = 1.8
        p["flame_h"] = 12 + i * 2
        p["eyes"] = "wide"
    elif anim == "hurt":
        p["lean"] = -3.0
        p["bob"] = 0.0
        p["head_dx"] = -1.0
        p["tilt"] = -0.25
        p["legs"] = [(-4.0, -1.0, 0.5), (2.0, 0.0, 0.4)]
        p["hem"] = 2.5
        p["scarf_ang"] = 60 + i * 20
        p["scarf_amp"] = 2.2
        p["flame_h"] = 6
        p["flame_lean"] = 2.0
        p["eyes"] = "hurt"
    elif anim == "death":
        k = t
        p["bob"] = k * 6
        p["lean"] = -2.0
        p["tilt"] = -0.5 * k
        p["legs"] = [(-4.0, 0.0, 1.0), (3.5, 0.0, 1.0)]
        p["crouch"] = 4.0 * k
        p["flare"] = 2.0 * k
        p["scarf_ang"] = 100 - 60 * k
        p["scarf_amp"] = 0.5
        p["scarf_len"] = 15 - 4 * k
        p["flame_h"] = max(0.0, 9 * (1 - k * 1.2))
        p["eyes"] = "hurt" if k < 0.5 else "closed"
    elif anim == "sleep":
        p["bob"] = 4.0
        p["crouch"] = 4.0
        p["legs"] = [(-3.5, 0.0, 1.0), (3.5, 0.0, 1.0)]
        p["flare"] = 2.0
        p["scarf_ang"] = 95
        p["scarf_amp"] = 0.3
        p["flame_h"] = 5 + wave(t) * 1.0
        p["eyes"] = "closed"
    return p


HERO_PAL = {"ash": None, "cloak": None, "cloak_in": None, "scarf": None, "leg": None, "boot": None, "gold": None,
            "eye": None, "eye_core": None, "eye_edge": None, "crack": None, "crack_dim": None, "flame": None}


def draw_hero(c, p, frame_t, pal=None):
    """Desenha a Faísca; `pal` troca materiais/cores (o Duelista Sombrio é
    o reflexo dela)."""
    pal = pal or {}
    M_ASH_ = pal.get("ash", M_ASH)
    M_CLOAK_ = pal.get("cloak", M_CLOAK)
    M_CLOAK_IN_ = pal.get("cloak_in", M_CLOAK_IN)
    M_SCARF_ = pal.get("scarf", M_SCARF)
    M_LEG_ = pal.get("leg", M_LEG)
    M_BOOT_ = pal.get("boot", M_BOOT)
    M_GOLD_ = pal.get("gold", M_GOLD)
    EYE_ = pal.get("eye", EYE)
    EYE_CORE_ = pal.get("eye_core", EYE_CORE)
    EYE_EDGE_ = pal.get("eye_edge", EYE_EDGE)
    CRACK_ = pal.get("crack", CRACK)
    CRACK_DIM_ = pal.get("crack_dim", CRACK_DIM)
    FLAME_ = pal.get("flame", None)
    bob = p["bob"]
    lean = p["lean"]
    cr = p["crouch"]
    hip_y = -8.0 + bob * 0.5 + cr * 0.5
    # --- pernas (atrás do manto) ---
    for k, (fx, fy, bend) in enumerate(p["legs"]):
        hx = (-1.6 if k == 0 else 1.6) + lean * 0.3
        knee = ((hx + fx) * 0.5 + bend * 1.5, (hip_y + fy) * 0.5 - bend * 0.8)
        z = -1.0 if k == 0 else 1.0
        mat = M_LEG_
        c.limb([(hx, hip_y), knee, (fx, fy - 1.2)], [1.7, 1.4, 1.3], mat, z=z)
        # bota
        c.ellipse(fx + 0.7, fy - 1.0, 2.2, 1.3, M_BOOT_, z=z + 0.2)
    # --- corpo / manto ---
    top_y = -15.0 + bob + cr
    hem_y = -5.2 + bob * 0.3 + cr * 0.4 - p["cloak_up"]
    fl = p["flare"]
    hem = p["hem"]
    sh = lean * 0.8
    # manto em sino, esfarrapado na barra (as pontas de trás mais longas)
    xs = [-8.2 - fl + hem, -6.4 - fl * 0.7 + hem, -4.4 - fl * 0.4 + hem, -2.0 + hem * 0.9, 0.4 + hem * 0.8,
          2.8 + hem * 0.6, 4.8 + fl * 0.4 + hem * 0.4, 6.6 + fl * 0.8 + hem * 0.2]
    drop = [2.2, 0.2, 1.6, -0.2, 1.2, -0.4, 0.8, -0.6]
    hem_pts = [(x, hem_y + drop[j]) for j, x in enumerate(xs)]
    cloak = [(-3.4 + sh, top_y - 0.5), (3.4 + sh, top_y - 0.5), (5.0 + sh * 0.7, top_y + 3.5)] + hem_pts[::-1] + [(-6.2 + sh * 0.6, top_y + 3.2)]
    c.poly(cloak, M_CLOAK_, z=2.0, bevel=3.2, folds=(1.0, 0.95, frame_t * 2.0, 0.16))
    # forro vermelho aparecendo quando o manto abre (golpe/magia)
    if p["open"] > 0.2:
        o = p["open"]
        c.poly([(1.0 + sh, top_y + 4), (4.5 + sh * 0.6 + o, top_y + 5), (6.0 + fl + hem * 0.2, hem_y + 1.0), (1.5 + hem * 0.7, hem_y + 1.2)], M_CLOAK_IN_, z=2.2, bevel=1.5)
    # --- cachecol: a cauda sai da nuca e esvoaça ---
    neck = (-2.5 + lean, top_y - 0.5)
    ang = math.radians(p["scarf_ang"])
    seg = p["scarf_len"] / 7.0
    pts = [neck]
    for j in range(1, 8):
        k = j / 7.0
        ox = math.cos(ang) * seg * j
        oy = math.sin(ang) * seg * j
        px, py = -math.sin(ang), math.cos(ang)
        w = math.sin((p["scarf_ph"] - k * 0.9) * math.tau) * p["scarf_amp"] * k * 1.6
        pts.append((neck[0] + ox + px * w, neck[1] + oy + py * w))
    widths = [4.8, 4.5, 4.1, 3.7, 3.3, 2.9, 2.4, 1.8]
    c.ribbon(pts, widths, M_SCARF_, z=1.5, twist=p["scarf_ph"] * math.tau)
    # ponta rasgada do cachecol
    ex, ey = pts[-1]
    c.ellipse(ex, ey, 1.4, 1.0, M_SCARF_, z=1.5)
    # volta do cachecol no pescoço (na frente do manto)
    c.ellipse(0.6 + lean, top_y + 0.4, 5.6, 2.3, M_SCARF_, z=3.0, bulge=0.8)
    # broche dourado prendendo o cachecol
    c.circle(3.4 + lean, top_y + 1.2, 1.1, M_GOLD_, z=3.2)
    # --- cabeça de cinza ---
    hx = 0.8 + lean + p["head_dx"]
    hy = top_y - 6.2 + p["head_dy"]
    if p["stretch"]:
        hy -= 0.5
    c.ellipse(hx, hy, 7.0, 6.4, M_ASH_, z=4.0, ang=p["tilt"])
    # rachaduras de brasa (atrás/topo)
    tl = p["tilt"]

    def rot(x, y):
        ca, sa = math.cos(tl), math.sin(tl)
        return hx + x * ca - y * sa, hy + x * sa + y * ca

    for (a, b) in [((-5.2, -2.6), (-4.0, -1.2)), ((-4.0, -1.2), (-4.6, 0.6))]:
        x0, y0 = rot(*a)
        x1, y1 = rot(*b)
        c.line(x0, y0, x1, y1, CRACK_DIM_, glow=True)
    x0, y0 = rot(-4.0, -1.2)
    c.dot(x0, y0, CRACK_, glow=True)
    # olhos: órbitas escuras com uma pupila de brasa (lê bem de longe)
    look = p["look"]
    eyes = p["eyes"]
    blink = p["blink"] > 0.5
    for k, (dx, rw) in enumerate([(3.9, 1.5), (-0.1, 1.2)]):
        x = hx + dx + look * 0.7
        y = hy + 0.6
        if eyes == "closed" or blink:
            c.line(x - rw + 0.3, y + 1.2, x + rw - 0.3, y + 1.2, hexc("#231a2a"))
            continue
        if eyes == "hurt":
            c.line(x - rw + 0.2, y - 0.6, x + rw - 0.2, y + 0.6, hexc("#231a2a"))
            c.line(x - rw + 0.2, y + 1.8, x + rw - 0.2, y + 0.6, hexc("#231a2a"))
            continue
        ry = {"narrow": 1.6, "wide": 3.0}.get(eyes, 2.6)
        yy = y + (0.8 if eyes == "narrow" else 0.0)
        c.ellipse(x, yy, rw, ry, M_SOCKET, z=4.5, no_outline=True)
        # pupila de brasa (brilha no escuro)
        px = x + 0.3 + look * 0.4
        py = yy - ry * 0.35
        c.dot(px, py, EYE_CORE_ if k == 0 else EYE_, glow=True)
        c.dot(px, py + 1.0, EYE_ if k == 0 else EYE_EDGE_, glow=True)
        if k == 0 and eyes == "wide":
            c.dot(px - 1.0, py, EYE_, glow=True)
    # --- chama no topo da cabeça ---
    if p["flame_h"] > 0.5:
        fx, fy = rot(-1.4, -5.4)
        c.flame(fx, fy + 0.4, 4.6, p["flame_h"] * 0.78, lean=p["flame_lean"] - 0.8, t=p["flame_ph"], palette=FLAME_)
        # faísca solta de vez em quando
        if int(p["flame_ph"] * 8) % 5 == 2:
            c.dot(fx - 1 + p["flame_lean"], fy - p["flame_h"] - 2.5, hexc("#ffd070"), glow=True)
    return {"hand": [p["hand"][0] + lean * 0.5, p["hand"][1] + bob * 0.5], "head": [hx, hy - 7.0]}


HERO_ANIMS = {
    # nome: (quadros, fps, loop)
    "idle": (8, 7, True), "run": (8, 14, True), "jump": (2, 10, False), "fall": (4, 10, True),
    "dash": (3, 18, False), "crouch": (2, 8, False), "wall": (4, 8, True), "climb": (4, 10, True),
    "attack": (3, 12, False), "cast": (3, 10, False), "hurt": (2, 10, False), "death": (7, 10, False),
    "sleep": (6, 4, True),
}


# ===========================================================================
# ARMAS (desenhadas por cima do corpo durante o golpe, giradas no punho)
# Cada arma aponta para a DIREITA; o pivô (punho) fica em "pivot".
# ===========================================================================

M_STEEL = Mat(["#3a3f52", "#6d7690", "#a9b3c8", "#dde4f0", "#ffffff"], spec=1.0, rim=0.5, rim_color="#e8f0ff", outline="#10121c", wrap=0.5)
M_STEEL_D = Mat(["#2a2c3a", "#4c5066", "#7a8098", "#aab0c4"], spec=0.8, rim=0.4, outline="#0c0d14")
M_GRIP = Mat(["#2a1810", "#4a2c1c", "#6e4630", "#8e603e"], rim=0.3, outline="#140a06")
M_WOOD = Mat(["#3a2414", "#5e3c22", "#86583a", "#a8784e"], rim=0.4, outline="#180e08")
M_RED_STEEL = Mat(["#3a1418", "#7a2a30", "#b8505a", "#e8909a", "#fff0f0"], spec=0.9, rim=0.5, outline="#1a0608")
M_CRYSTAL = Mat(["#2a2a6a", "#4a5ac8", "#7aa0ff", "#c8e0ff"], spec=1.0, rim=0.6, outline="#10103a", glow=None)


def _blade(c, x0, x1, w0, w1, mat, curve=0.0, tip=4.0, z=1.0):
    """Lâmina de x0 (base) a x1 (ponta), largura w0 -> w1, com curva."""
    n = 10
    top, bot = [], []
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - tip - x0) * t
        yc = -curve * (t * t)
        w = w0 + (w1 - w0) * t
        top.append((x, yc - w * 0.5))
        bot.append((x, yc + w * 0.5))
    tipp = (x1, -curve * 1.05)
    c.poly(top + [tipp] + bot[::-1], mat, z=z, bevel=1.4, tilt=(0.0, -0.35))
    # fio: linha clara ao longo do gume de cima
    for i in range(n):
        t = i / n
        x = x0 + 1 + (x1 - tip - x0 - 1) * t
        yc = -curve * (t * t) - (w0 + (w1 - w0) * t) * 0.5 + 0.6
        c.dot(x, yc, (240, 246, 255, 255))


def draw_weapon(c, cls):
    if cls == "longsword":
        _blade(c, 3, 24, 3.2, 2.6, M_STEEL, tip=4)
        c.capsule(3, -3.4, 3, 3.4, 1.1, 1.1, M_GOLD, z=2)
        c.capsule(-3, 0, 2, 0, 1.2, 1.2, M_GRIP, z=1.5)
        c.circle(-3.8, 0, 1.4, M_GOLD, z=2)
    elif cls == "fine_sword":
        _blade(c, 3, 25, 2.2, 1.6, M_STEEL, tip=5)
        c.capsule(3, -2.6, 3, 2.6, 0.9, 0.9, M_GOLD, z=2)
        c.ellipse(1.5, 1.2, 2.2, 1.6, M_GOLD, z=2)  # guarda em concha
        c.capsule(-3, 0, 2, 0, 1.0, 1.0, M_GRIP, z=1.5)
        c.circle(-3.6, 0, 1.2, M_GOLD, z=2)
    elif cls == "greatsword":
        _blade(c, 4, 29, 5.4, 4.6, M_STEEL, tip=5)
        c.capsule(4, -5.0, 4, 5.0, 1.4, 1.4, M_STEEL_D, z=2)
        c.capsule(-5, 0, 3, 0, 1.5, 1.5, M_GRIP, z=1.5)
        c.circle(-5.8, 0, 1.8, M_STEEL_D, z=2)
    elif cls in ("katana", "heavy_katana", "dual_katana"):
        ln = {"katana": 24, "heavy_katana": 30, "dual_katana": 19}[cls]
        _blade(c, 3, ln, 2.6, 2.2, M_STEEL, curve=2.0, tip=3)
        c.ellipse(2.6, 0, 1.0, 2.4, M_GOLD, z=2)  # tsuba
        c.capsule(-4, 0, 2, 0, 1.2, 1.2, M_GRIP, z=1.5)
        for x in (-3, -1, 1):
            c.dot(x, 0, (180, 140, 100, 255))
    elif cls in ("daggers", "knife"):
        ln = 13 if cls == "daggers" else 11
        _blade(c, 2, ln, 2.8, 1.6, M_STEEL, tip=3)
        c.capsule(2, -2.2, 2, 2.2, 0.9, 0.9, M_STEEL_D, z=2)
        c.capsule(-3, 0, 1.5, 0, 1.1, 1.1, M_GRIP, z=1.5)
    elif cls == "staff":
        c.capsule(-9, 0, 22, 0, 1.3, 1.3, M_WOOD, z=1)
        c.capsule(-9, 0, -7, 0, 1.6, 1.6, M_GOLD, z=1.5)
        c.ellipse(24.5, 0, 3.0, 2.2, M_CRYSTAL, z=2)
        c.capsule(20, -2.4, 22, -1, 0.7, 0.7, M_GOLD, z=2.2)
        c.capsule(20, 2.4, 22, 1, 0.7, 0.7, M_GOLD, z=2.2)
    elif cls == "bleed_blade":
        _blade(c, 3, 22, 3.4, 2.4, M_RED_STEEL, tip=4)
        for x in range(6, 18, 3):
            c.poly([(x, 1.2), (x + 1.5, 3.2), (x + 2.5, 1.2)], M_RED_STEEL, z=1.2, bevel=0.8)
        c.capsule(3, -3.0, 3, 3.0, 1.0, 1.0, M_STEEL_D, z=2)
        c.capsule(-3, 0, 2, 0, 1.2, 1.2, M_GRIP, z=1.5)
    elif cls == "sword_shield":
        _blade(c, 3, 18, 3.0, 2.4, M_STEEL, tip=4)
        c.capsule(3, -3.0, 3, 3.0, 1.0, 1.0, M_GOLD, z=2)
        c.capsule(-3, 0, 2, 0, 1.2, 1.2, M_GRIP, z=1.5)
    elif cls == "gauntlets":
        c.ellipse(2, 0, 4.2, 3.4, M_STEEL, z=1)
        for k in range(3):
            c.capsule(3.6, -2.0 + k * 1.9, 5.4, -2.0 + k * 1.9, 0.9, 0.9, M_STEEL, z=1.5)
        c.capsule(-3, 0, 0, 0, 2.6, 2.8, M_STEEL_D, z=0.5)
    elif cls == "shield":
        c.poly([(-4, -7), (4, -7), (4.5, 1), (0, 8), (-4.5, 1)], M_STEEL_D, z=1, bevel=2.0)
        c.poly([(-2.5, -5.5), (2.5, -5.5), (2.8, 0.6), (0, 5.5), (-2.8, 0.6)], M_SCARF, z=1.5, bevel=1.2)
        c.circle(0, -1, 1.3, M_GOLD, z=2)


WEAPONS = ["longsword", "fine_sword", "greatsword", "katana", "heavy_katana", "dual_katana", "daggers",
           "knife", "staff", "bleed_blade", "sword_shield", "gauntlets", "shield"]


def build_weapons(meta):
    d = os.path.join(OUT, "weapons")
    os.makedirs(d, exist_ok=True)
    w, h, ox, oy = 48, 20, 12, 10
    info = {}
    frames = []
    for cls in WEAPONS:
        c = Canvas(w, h, ox, oy)
        draw_weapon(c, cls)
        img, _ = c.render(contact=False)
        save(img, os.path.join(d, cls + ".png"))
        info[cls] = {"size": [c.w, c.h], "pivot": [c.ox, c.oy]}
        frames.append(img)
    meta["_weapons"] = info
    if PREVIEW:
        preview([("w", frames)], os.path.join(PREVIEW, "weapons.png"))
    print(f"armas: {len(WEAPONS)}")


# ===========================================================================
# Infra: renderizar animações de um personagem
# ===========================================================================

def render_character(cid, size, anims, pose_fn, draw_fn, meta):
    w, h, ox, oy = size
    d = os.path.join(OUT, cid)
    os.makedirs(d, exist_ok=True)
    probe = Canvas(w, h, ox, oy)
    entry = {"frame": [probe.w, probe.h], "origin": [probe.ox, probe.oy], "anims": {}}
    sheets = []
    for anim, (n, fps, loop) in anims.items():
        frames, glows, points = [], [], []
        for i in range(n):
            t = i / n
            c = Canvas(w, h, ox, oy)
            p = pose_fn(anim, t, i, n)
            info = draw_fn(c, p, t) or {}
            img, glow = c.render()
            frames.append(img)
            glows.append(glow)
            points.append({k: [round(v[0] * RES, 1), round(v[1] * RES, 1)] for k, v in info.items()})
        save(strip(frames), os.path.join(d, anim + ".png"))
        has_glow = any(g[..., 3].any() for g in glows)
        gpath = os.path.join(d, anim + "_glow.png")
        if has_glow:
            save(strip(glows), gpath)
        elif os.path.exists(gpath):
            os.remove(gpath)
        entry["anims"][anim] = {"frames": n, "fps": fps, "loop": loop, "glow": has_glow, "points": points}
        sheets.append((anim, frames))
    meta[cid] = entry
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        preview(sheets, os.path.join(PREVIEW, cid + ".png"))
    print(f"{cid}: {len(anims)} animações")


# O Duelista Sombrio: "um reflexo seu que aprendeu a lutar sozinho" — a
# Faísca em negativo (cabeça de cinza escura, chama azul, olhos vermelhos).
DUELIST_PAL = {
    "ash": Mat(["#141019", "#221b2a", "#322838", "#443650", "#584a66"], rim=0.8, rim_color="#8ab8ff", outline="#050308", wrap=0.5, ambient=0.3),
    "cloak": Mat(["#060408", "#0c0910", "#140f1a", "#1e1726", "#2a2034"], rim=0.8, rim_color="#5a7ab8", outline="#020103"),
    "cloak_in": Mat("#1a2a5a", n=4, spread=0.6, rim=0.0, outline="#04060e"),
    "scarf": Mat(["#12030a", "#260612", "#3e0c1c", "#5a1426", "#781c30"], rim=0.8, rim_color="#ff4a6a", outline="#080104"),
    "leg": Mat(["#08060a", "#110d14", "#1a1520", "#241d2c"], rim=0.6, rim_color="#4a5a8a", outline="#030204"),
    "boot": Mat(["#060408", "#0e0a10", "#16111a", "#201824"], rim=0.5, outline="#020103"),
    "gold": Mat(["#1a2a4a", "#3a5a8a", "#6a9ad0", "#b0d8ff"], rim=0.0, spec=1.0, outline="#060a14"),
    "eye": hexc("#ff4a5a"), "eye_core": hexc("#ffd0d8"), "eye_edge": hexc("#a0101e"),
    "crack": hexc("#6ab8ff"), "crack_dim": hexc("#2a5aa8"),
    "flame": [hexc("#1a2a8a"), hexc("#2a6ae0"), hexc("#7ac8ff"), hexc("#eaf6ff")],
}


def draw_duelist(c, p, t):
    return draw_hero(c, p, t, DUELIST_PAL)


DUELIST_ANIMS = {"idle": (8, 7, True), "move": (8, 14, True), "attack": (3, 12, False), "cast": (3, 10, False),
                 "hurt": (2, 10, False), "jump": (2, 10, False), "fall": (4, 10, True), "dash": (3, 18, False), "crouch": (2, 8, False)}


def duelist_pose(anim, t, i, n):
    return hero_pose("run" if anim == "move" else anim, t, i, n)


# ===========================================================================
# ALDEÕES: o povo de cinza de Cindária. Mesma família da Faísca, mas SEM
# chama (só ela guarda a última brasa) — olhos de brasa fraca, mantos e
# acessórios pelo ofício.
# ===========================================================================

def _vpal(cloak, lining, scarf, ash="#d9d2c6", eye="#e8a860"):
    return {
        "ash": Mat(ash, n=5, spread=0.55, rim=0.7, rim_color="#fff6e8", outline="#2a2230", wrap=0.5, ambient=0.3),
        "cloak": Mat(cloak, n=5, spread=0.6, rim=0.6, outline="#0c0a10"),
        "cloak_in": Mat(lining, n=4, spread=0.6, rim=0.0, outline="#0c0a10"),
        "scarf": Mat(scarf, n=5, spread=0.6, rim=0.6, outline="#140a0a"),
        "eye": hexc(eye), "eye_core": hexc("#fff0d0"), "eye_edge": hexc("#a05a2a"),
        "crack": hexc("#7a6a60"), "crack_dim": hexc("#5a4c48"),
    }


VILLAGERS = {
    "ferreira": (_vpal("#4a3226", "#8a4a2a", "#6a4a30", ash="#c8b8a8"), "apron"),
    "mercador": (_vpal("#3e5a3a", "#c8a050", "#c89a40"), "hat"),
    "curandeira": (_vpal("#e0dcd0", "#7ab08a", "#5a9a6a"), "hood"),
    "sabio": (_vpal("#2e2a5a", "#6a5ab0", "#8a7ad0", eye="#a8c8ff"), "hood"),
    "capita": (_vpal("#5a5e6e", "#a02a2a", "#8a2a2a"), "helm"),
    "receptador": (_vpal("#1c1a22", "#4a2a5a", "#2a2432", ash="#9a948c"), "hood"),
    "bardo": (_vpal("#7a2e5a", "#e0b040", "#d0a040"), "hat"),
    "anciao": (_vpal("#5e564c", "#8a7a60", "#8a7a60", ash="#b8b0a8"), "beard"),
    "crianca": (_vpal("#b07a3a", "#e0c070", "#c05a3a"), "none"),
}
M_HAT = Mat("#3a2a1e", n=4, spread=0.6, rim=0.5, outline="#100a06")
M_HELM = Mat(["#3a3f52", "#6d7690", "#a9b3c8", "#dde4f0"], spec=0.8, rim=0.5, outline="#10121c")
M_APRON = Mat("#6a4a30", n=4, spread=0.6, rim=0.4, outline="#1a100a")
M_BEARD = Mat("#e8e2d8", n=4, spread=0.4, rim=0.6, outline="#4a4440")


def draw_villager(role):
    pal, acc = VILLAGERS[role]
    small = role == "crianca"

    def draw(c, p, t):
        p = dict(p)
        p["flame_h"] = 0.0  # sem chama
        info = draw_hero(c, p, t, pal)
        hx, hy = info["head"]
        hy += 7.0  # centro da cabeça
        if acc == "hat":
            c.ellipse(hx, hy - 5.0, 9.5, 1.6, M_HAT, z=6.0)
            c.ellipse(hx, hy - 7.5, 5.0, 3.2, M_HAT, z=6.1)
        elif acc == "hood":
            c.poly([(hx - 7.6, hy + 1.0), (hx - 6.0, hy - 6.0), (hx - 1.0, hy - 9.5), (hx + 4.0, hy - 8.0),
                    (hx + 7.0, hy - 3.0), (hx + 6.2, hy - 1.5), (hx + 2.0, hy - 6.0), (hx - 4.8, hy - 3.0), (hx - 5.2, hy + 2.0)],
                   pal["cloak"], z=6.0, bevel=2.0)
        elif acc == "helm":
            c.ellipse(hx, hy - 3.0, 7.4, 4.6, M_HELM, z=6.0)
            c.poly([(hx - 1.0, hy - 7.0), (hx + 1.0, hy - 7.0), (hx + 0.5, hy - 11.0), (hx - 0.5, hy - 11.0)], pal["scarf"], z=6.1, bevel=0.8)
        elif acc == "apron":
            c.poly([(hx - 3.0, hy + 9.0), (hx + 4.0, hy + 9.0), (hx + 5.0, hy + 17.0), (hx - 3.5, hy + 17.0)], M_APRON, z=5.0, bevel=1.5)
        elif acc == "beard":
            c.poly([(hx - 1.0, hy + 3.0), (hx + 6.0, hy + 3.0), (hx + 4.0, hy + 9.5), (hx + 1.5, hy + 11.0)], M_BEARD, z=6.0, bevel=1.5)
        return info
    return draw


def villager_pose(anim, t, i, n):
    p = hero_pose("run" if anim == "move" else "idle", t, i, n)
    return p


VILLAGER_ANIMS = {"idle": (8, 6, True), "move": (8, 12, True)}


CHARACTERS = {
    "weapons": build_weapons,
    "duelist": lambda meta: render_character("duelist", (HERO_W, HERO_H, HERO_OX, HERO_OY), DUELIST_ANIMS, duelist_pose, draw_duelist, meta),
    "hero": lambda meta: render_character("hero", (HERO_W, HERO_H, HERO_OX, HERO_OY), HERO_ANIMS, hero_pose, draw_hero, meta),
}


for _role in VILLAGERS:
    CHARACTERS["villager_" + _role] = (lambda r: (lambda meta: render_character("villager_" + r, (HERO_W, HERO_H, HERO_OX, HERO_OY), VILLAGER_ANIMS, villager_pose, draw_villager(r), meta)))(_role)

for _eid, (_size, _anims, _pose, _draw) in EN.ENEMIES.items():
    CHARACTERS[_eid] = (lambda eid, size, anims, pose, draw: (lambda meta: render_character(eid, size, anims, pose, draw, meta)))(_eid, _size, _anims, _pose, _draw)


def main():
    only = sys.argv[1:]
    meta = {}
    if os.path.exists(META):
        with open(META, encoding="utf-8") as f:
            meta = json.load(f)
    meta["_doc"] = ("Gerado por tools/build_sprites.py. frame = tamanho do quadro (px de arte), origin = pés; "
                    "points por quadro: hand (arma) e head (emoções/chama), relativos à origem, em px de arte.")
    for cid, fn in CHARACTERS.items():
        if only and cid not in only:
            continue
        fn(meta)
    with open(META, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
