#!/usr/bin/env python3
"""Inimigos e chefes em pixel art detalhada (usado por build_sprites.py).

Cada criatura tem identidade própria (silhueta, cores, olhos que brilham no
escuro) e animações: idle, move, attack (preparação/golpe/volta), cast,
hurt e, quando faz sentido, jump/fall. As armas das criaturas armadas são
desenhadas pelo jogo por cima (girando no ponto "hand"); as feras atacam
com o corpo (mordida, patada, investida).

Coordenadas: origem nos pés (voadores: no centro do corpo), x para a
frente, y para baixo, em pixels de arte (2 px = 1 unidade do mundo).
"""
import math

from spritekit import Mat, hexc

# ---------------------------------------------------------------------------
# utilidades de pose
# ---------------------------------------------------------------------------


def wave(t, k=1.0, ph=0.0):
    return math.sin((t * k + ph) * math.tau)


def walk_legs(t, stride=4.0, lift=2.4, spread=2.2):
    s = math.sin(t * math.tau)
    c = math.cos(t * math.tau)
    return [(-spread * 0.4 - s * stride, -max(0.0, c) * lift, 0.6), (spread * 0.6 + s * stride, -max(0.0, -c) * lift, 0.6)]


def base_pose(anim, t, i, n):
    """Pose genérica de bípede/flutuante."""
    p = {"bob": 0.0, "lean": 0.0, "legs": [(-2.5, 0.0, 0.2), (2.5, 0.0, 0.2)], "arm": 0.0, "arm2": 0.0,
         "open": 0.0, "blink": False, "hurt": False, "t": t, "i": i, "anim": anim, "cast": 0.0, "hand": (6.0, -12.0),
         "flap": wave(t), "jaw": 0.0}
    if anim == "idle":
        p["bob"] = -round((wave(t) + 1) * 0.5)
        p["blink"] = i == n - 1
    elif anim == "move":
        p["legs"] = walk_legs(t)
        p["bob"] = -abs(math.cos(t * math.tau)) * 1.2 + 0.4
        p["lean"] = 1.0
        p["arm"] = math.sin(t * math.tau) * 0.5
    elif anim == "attack":
        if i == 0:
            p["lean"] = -2.0
            p["arm"] = -1.0
            p["legs"] = [(-3.5, 0.0, 0.5), (3.0, 0.0, 0.4)]
            p["hand"] = (-3.0, -16.0)
        elif i == 1:
            p["lean"] = 3.0
            p["arm"] = 1.0
            p["legs"] = [(-4.5, 0.0, 0.6), (4.5, 0.0, 0.7)]
            p["open"] = 1.0
            p["jaw"] = 1.0
            p["hand"] = (8.0, -12.0)
        else:
            p["lean"] = 1.2
            p["arm"] = 0.4
            p["legs"] = [(-4.0, 0.0, 0.5), (4.0, 0.0, 0.5)]
            p["hand"] = (6.0, -11.0)
    elif anim == "cast":
        p["bob"] = -1.0 if i % 2 else 0.0
        p["cast"] = 1.0
        p["arm"] = -1.5
        p["open"] = 0.6 + 0.2 * i
        p["legs"] = [(-3.0, 0.0, 0.4), (3.0, 0.0, 0.4)]
    elif anim == "hurt":
        p["lean"] = -3.0
        p["hurt"] = True
        p["legs"] = [(-4.0, -1.0, 0.5), (2.0, 0.0, 0.4)]
    elif anim == "jump":
        p["legs"] = [(-3.0, -3.0, 1.0), (2.5, -1.5, 0.6)]
        p["bob"] = -1.0
    elif anim == "fall":
        p["legs"] = [(-3.5, -1.0, 0.3), (3.0, -2.0, 0.6)]
    return p


def legs(c, p, hip_y, mat, boot, r=1.6, lean=0.0, hip_w=1.8, boot_r=(2.2, 1.3)):
    for k, (fx, fy, bend) in enumerate(p["legs"]):
        hx = (-hip_w if k == 0 else hip_w) + lean * 0.3
        knee = ((hx + fx) * 0.5 + bend * 1.5, (hip_y + fy) * 0.5 - bend * 0.8)
        z = -1.0 if k == 0 else 1.0
        c.limb([(hx, hip_y), knee, (fx, fy - 1.1)], [r, r * 0.85, r * 0.8], mat, z=z)
        if boot is not None:
            c.ellipse(fx + 0.7, fy - 1.0, boot_r[0], boot_r[1], boot, z=z + 0.2)


def glow_eye(c, x, y, col, core=None, h=2):
    for k in range(h):
        c.dot(x, y + k, core if (core is not None and k == 0) else col, glow=True)


# ===========================================================================
# OCO ERRANTE (skeleton) — soldado esvaziado pela Maré: armadura enferrujada,
# elmo rachado com dois pontos de luz azul no visor, tabardo rasgado.
# ===========================================================================

M_IRON = Mat(["#1e1c26", "#3a3844", "#5e5a66", "#8a8490", "#b8b2b8"], spec=0.6, rim=0.6, rim_color="#a8b8d8", outline="#0c0a10")
M_RUST = Mat(["#2e1810", "#5a2e1a", "#8a4a26", "#b0703a"], rim=0.4, outline="#140a06")
M_BONE = Mat(["#5e5446", "#8e826c", "#bcb096", "#e2d8c0"], rim=0.5, rim_color="#f0ead8", outline="#1e1a14")
M_TABARD = Mat(["#2a0e12", "#4a1a20", "#6e2a2e", "#8e3c3a"], rim=0.5, rim_color="#c06a5a", outline="#12060a")
M_DARK = Mat(["#0e0c12", "#18141e", "#221c2a", "#2e2638"], rim=0.5, rim_color="#5a5070", outline="#060508")
SOCK = Mat(["#08060a", "#0e0a12", "#140e18"], flat=True, rim=0.0, outline="#08060a")


def draw_skeleton(c, p, t):
    bob, lean = p["bob"], p["lean"]
    hip = -9.0 + bob * 0.5
    legs(c, p, hip, M_BONE, M_IRON, r=1.3, lean=lean)
    top = -20.0 + bob
    sh = lean * 0.7
    # braço de trás
    c.limb([(-3.5 + sh, top + 2), (-4.5 + sh - p["arm"], top + 7), (-3.8 + sh - p["arm"] * 1.5, top + 11)], [1.3, 1.1, 1.0], M_BONE, z=0.0)
    # couraça + tabardo
    c.poly([(-5.2 + sh, top), (5.0 + sh, top), (4.2 + sh * 0.6, hip + 1), (-4.6 + sh * 0.6, hip + 1)], M_IRON, z=2.0, bevel=2.5)
    c.poly([(-2.0 + sh * 0.6, hip - 3), (3.0 + sh * 0.6, hip - 3), (3.6 + sh * 0.3 - lean * 0.4, hip + 6.5), (1.0, hip + 5.0), (-1.4 + sh * 0.3 - lean * 0.4, hip + 6.8)], M_TABARD, z=2.5, bevel=1.4, folds=(1.0, 1.4, t * 2, 0.25))
    # ombreiras
    c.ellipse(-4.2 + sh, top + 1.2, 2.8, 2.0, M_RUST, z=2.6)
    c.ellipse(4.2 + sh, top + 1.2, 2.8, 2.0, M_RUST, z=3.2)
    # elmo
    hx, hy = 0.8 + lean, top - 5.2
    c.poly([(hx - 5, hy + 4.5), (hx - 5.2, hy - 2.5), (hx - 3, hy - 5.5), (hx + 3, hy - 5.5), (hx + 5.2, hy - 2.5), (hx + 5, hy + 4.5)], M_IRON, z=4.0, bevel=2.4)
    # visor escuro e olhos
    c.poly([(hx - 1.5, hy - 0.6), (hx + 5.2, hy - 0.6), (hx + 5.2, hy + 1.3), (hx - 1.5, hy + 1.3)], SOCK, z=4.4, no_outline=True, bevel=0.1)
    if not p["blink"]:
        eye = hexc("#8ad8ff")
        c.dot(hx + 1.5, hy + 0.2, eye, glow=True)
        c.dot(hx + 4.0, hy + 0.2, eye, glow=True)
        c.dot(hx + 1.5, hy + 0.8, hexc("#3a8ac8"), glow=True)
        c.dot(hx + 4.0, hy + 0.8, hexc("#3a8ac8"), glow=True)
    # rachadura e crista quebrada
    c.line(hx - 2.5, hy - 5.0, hx - 1.0, hy - 2.5, hexc("#141018"))
    c.poly([(hx - 1, hy - 5.5), (hx + 1.5, hy - 5.5), (hx - 2.5, hy - 9.5), (hx - 3.5, hy - 8.0)], M_TABARD, z=3.8, bevel=1.0)
    # braço da frente (segura a arma)
    hdx, hdy = p["hand"]
    c.limb([(3.8 + sh, top + 2), ((3.8 + hdx) * 0.5 + sh, (top + 2 + hdy + bob) * 0.5 + 1), (hdx + lean * 0.5, hdy + bob * 0.5)], [1.3, 1.1, 1.2], M_BONE, z=5.0)
    return {"hand": [p["hand"][0] + lean * 0.5, p["hand"][1] + bob * 0.5], "head": [hx, hy - 7]}


# ===========================================================================
# QUADRÚPEDES: CÃO INFERNAL (hound), GATO DO ABISMO (hellcat)
# ===========================================================================

def quad_pose(anim, t, i, n):
    p = {"bob": 0.0, "lean": 0.0, "legs": [0.0, 0.5, 0.25, 0.75], "gait": 0.0, "head": 0.0, "jaw": 0.0,
         "tail": wave(t), "blink": False, "hurt": False, "crouch": 0.0, "t": t, "i": i, "anim": anim, "stretch": 0.0}
    if anim == "idle":
        p["bob"] = -round((wave(t) + 1) * 0.5) * 0.8
        p["blink"] = i == n - 1
        p["head"] = wave(t) * 0.5
    elif anim == "move":
        p["gait"] = 1.0
        p["bob"] = -abs(math.sin(t * math.tau)) * 1.6
        p["tail"] = wave(t, 2)
    elif anim in ("attack", "jump"):
        if i == 0:
            p["crouch"] = 2.5
            p["head"] = -1.0
        elif i == 1:
            p["stretch"] = 1.0
            p["jaw"] = 1.0
            p["head"] = 1.0
            p["bob"] = -2.0
        else:
            p["jaw"] = 0.4
            p["bob"] = -0.5
    elif anim == "hurt":
        p["hurt"] = True
        p["crouch"] = 1.0
        p["head"] = -1.5
    elif anim == "fall":
        p["stretch"] = 0.5
    return p


def draw_quadruped(c, p, t, spec):
    L = spec["len"]
    Hh = spec["height"]
    body_m, belly_m, accent = spec["body"], spec.get("belly", spec["body"]), spec.get("accent", M_BONE)
    bob, cr, st = p["bob"], p["crouch"], p["stretch"]
    by = -Hh + bob + cr
    bx0, bx1 = -L * 0.45 - st * 1.5, L * 0.35 + st * 2.0
    # pernas (trás, depois frente)
    gait = p["gait"]
    for k, (px, ph) in enumerate([(bx0 + 2.5, 0.0), (bx1 - 2.0, 0.5), (bx0 + 4.5, 0.25), (bx1, 0.75)]):
        z = -1.0 if k < 2 else 1.5
        s = math.sin((t + ph) * math.tau) * gait
        cc = math.cos((t + ph) * math.tau) * gait
        if st > 0.5:
            fx = px + (-3.0 if k % 2 == 0 else 4.0)
            fy = -2.0
        else:
            fx = px + s * spec.get("stride", 3.5)
            fy = -max(0.0, cc) * 2.5
        top = (px, by + 3.0)
        knee = (px + (fx - px) * 0.5 + (1.2 if k % 2 == 0 else -0.8), (by + 3.0 + fy) * 0.5 + 1.0)
        c.limb([top, knee, (fx, fy - 0.8)], [spec.get("leg_r", 1.8), 1.3, 1.1], body_m, z=z)
        c.ellipse(fx + 0.6, fy - 0.6, 1.6, 1.0, spec.get("paw", body_m), z=z + 0.1)
    # cauda
    tl = spec.get("tail_len", 9.0)
    pts = []
    for j in range(6):
        k = j / 5
        pts.append((bx0 - k * tl, by + 1.0 - k * tl * 0.5 + math.sin((p["tail"] * 0.3 + k) * 3.0) * 2.0 * k))
    c.ribbon(pts, [2.6, 2.3, 2.0, 1.7, 1.4, 1.2], body_m, z=0.5)
    if spec.get("tail_glow"):
        c.flame(pts[-1][0], pts[-1][1] + 1.0, 3.0, 5.0, lean=-1.0, t=t, palette=spec["tail_glow"])
    # corpo
    c.ellipse((bx0 + bx1) * 0.5, by + 1.0, (bx1 - bx0) * 0.5 + 1.0, spec.get("girth", 4.5), body_m, z=1.0)
    c.ellipse((bx0 + bx1) * 0.5 + 1.0, by + 3.0, (bx1 - bx0) * 0.4, 2.2, belly_m, z=1.1)
    if spec.get("ribs"):
        for k in range(3):
            x = bx1 - 5 - k * 2.5
            c.line(x, by - 1.0, x - 0.8, by + 3.0, spec["ribs"])
    if spec.get("spikes"):
        for k in range(5):
            x = bx0 + 2 + k * (bx1 - bx0 - 4) / 4
            c.poly([(x - 1.2, by - 3.0), (x + 1.2, by - 3.0), (x - 1.5, by - 6.5 - (k % 2))], accent, z=0.9, bevel=0.8)
    # cabeça
    hx = bx1 + 3.5 + st * 1.5
    hy = by - 2.5 + p["head"] * 1.2 - cr * 0.3
    c.ellipse(hx, hy, spec.get("head_r", 3.6), spec.get("head_r", 3.6) * 0.85, spec.get("head_m", body_m), z=2.0)
    # focinho + mandíbula
    sn = spec.get("snout", 4.0)
    c.capsule(hx + 1.0, hy + 0.5, hx + 1.0 + sn, hy + 1.0, 2.0, 1.5, spec.get("head_m", body_m), z=2.1)
    if p["jaw"] > 0.3:
        c.capsule(hx + 0.5, hy + 2.2, hx + sn, hy + 3.2 + p["jaw"] * 1.6, 1.2, 1.0, spec.get("head_m", body_m), z=1.9)
        c.line(hx + 1.5, hy + 2.0, hx + sn, hy + 2.3 + p["jaw"], hexc("#f0e8d8"))
    # orelhas / chifres
    for k, dx in enumerate([-1.5, 0.5]):
        z = 1.8 if k == 0 else 2.2
        if spec.get("ears") == "pointy":
            c.poly([(hx + dx - 1.2, hy - 2.2), (hx + dx + 1.0, hy - 2.2), (hx + dx - 1.0, hy - 6.5)], spec.get("head_m", body_m), z=z, bevel=0.8)
        elif spec.get("ears") == "horns":
            c.capsule(hx + dx, hy - 2.0, hx + dx - 3.0, hy - 5.5, 1.0, 0.5, accent, z=z)
    # olho
    if not p["blink"]:
        ex, ey = hx + 1.2, hy - 0.8
        col = spec["eye"]
        if p["hurt"]:
            c.line(ex - 0.5, ey, ex + 1.0, ey, col, glow=True)
        else:
            c.dot(ex, ey, spec.get("eye_core", col), glow=True)
            c.dot(ex + 1.0, ey, col, glow=True)
    return {"hand": [hx + sn, hy + 1.5], "head": [hx, hy - 6.0]}


M_HOUND = Mat(["#140a0e", "#2a1418", "#44222a", "#633238"], rim=0.7, rim_color="#e05a3a", outline="#080406")
M_HOUND_B = Mat(["#241012", "#3e1c20", "#5a2a2c"], rim=0.3, outline="#080406")
M_CAT = Mat(["#140e22", "#241a3a", "#382a56", "#4e3c74"], rim=0.75, rim_color="#b08aff", outline="#07050e")
M_CAT_B = Mat(["#1e1630", "#30244a", "#44365e"], rim=0.3, outline="#07050e")
M_FROG = Mat(["#1a2a12", "#2e4a1e", "#4a6e2e", "#6e9440", "#9ab85a"], rim=0.6, rim_color="#d8f090", outline="#0a1206")
M_FROG_B = Mat(["#6a6a3a", "#9a9a5a", "#c8c47e"], rim=0.2, outline="#0a1206")
M_SPINE = Mat(["#6a5a3a", "#a89060", "#e0cc98", "#fff0c8"], rim=0.4, outline="#1a1206")


HOUND = {"len": 22.0, "height": 13.0, "body": M_HOUND, "belly": M_HOUND_B, "accent": M_BONE, "ribs": hexc("#6a3a3a"),
         "spikes": True, "ears": "horns", "eye": hexc("#ff5a3a"), "eye_core": hexc("#ffd0a0"), "snout": 5.0, "tail_len": 8.0,
         "tail_glow": [hexc("#8a1e10"), hexc("#e04a1a"), hexc("#ff9a3a"), hexc("#ffe0a0")], "girth": 4.8}
CAT = {"len": 20.0, "height": 11.0, "body": M_CAT, "belly": M_CAT_B, "ears": "pointy", "eye": hexc("#ffe048"), "eye_core": hexc("#fffbe0"),
       "snout": 2.5, "tail_len": 13.0, "girth": 3.8, "head_r": 3.4, "stride": 4.0, "leg_r": 1.5,
       "tail_glow": [hexc("#4a1a8a"), hexc("#8a4ae0"), hexc("#c89aff"), hexc("#f0e0ff")]}


def draw_hound(c, p, t):
    return draw_quadruped(c, p, t, HOUND)


def draw_hellcat(c, p, t):
    return draw_quadruped(c, p, t, CAT)


# ===========================================================================
# SALTADOR ESPINHOSO (leaper) — sapo-grilo com espinhos, pernas de mola
# ===========================================================================

def draw_leaper(c, p, t):
    bob, cr, st = p["bob"], p["crouch"], p["stretch"]
    by = -6.5 + bob + cr * 0.8 - st * 3.0
    # pernas traseiras (dobradas / esticadas)
    for k in range(2):
        z = -1.0 if k == 0 else 1.5
        hx = -4.0 + k * 1.0
        if st > 0.5:
            pts = [(hx, by + 1), (hx - 5, by + 4), (hx - 9, by + 7)]
        else:
            pts = [(hx, by + 1), (hx - 4.5, by - 2.5 + cr), (hx - 2.0, -1.0)]
        c.limb(pts, [2.2, 1.6, 1.2], M_FROG, z=z)
        c.ellipse(pts[-1][0] + 0.5, pts[-1][1] - 0.3, 2.2, 1.0, M_FROG, z=z + 0.1)
    # braços da frente
    for k in range(2):
        z = -0.5 if k == 0 else 1.6
        fx = 4.0 + k * 1.5 + st * 3.0
        c.limb([(3.0 + k, by + 2), (fx, -1.0 - st * 2.0)], [1.4, 1.1], M_FROG, z=z)
    # corpo
    c.ellipse(0.0, by, 7.0, 5.0, M_FROG, z=1.0)
    c.ellipse(1.5, by + 2.2, 5.0, 2.4, M_FROG_B, z=1.1)
    # espinhos nas costas
    for k in range(5):
        x = -5.0 + k * 2.3
        c.poly([(x - 1.0, by - 3.5 + abs(k - 2) * 0.4), (x + 1.2, by - 3.8 + abs(k - 2) * 0.4), (x - 1.8, by - 9.0 + abs(k - 2))], M_SPINE, z=0.8, bevel=0.8)
    # cabeça (larga, olhos saltados)
    hx, hy = 6.0 + st * 2.0, by - 1.5
    c.ellipse(hx, hy, 4.2, 3.2, M_FROG, z=2.0)
    for k, dx in enumerate([-1.5, 1.2]):
        c.circle(hx + dx, hy - 2.8, 1.8, M_FROG_B, z=2.2 + k * 0.1)
        if not p["blink"]:
            c.dot(hx + dx + 0.3, hy - 3.0, hexc("#1a0a06"))
            c.dot(hx + dx + 0.3, hy - 3.6, hexc("#fff4a0"), glow=True)
    if p["jaw"] > 0.3:
        c.line(hx + 0.5, hy + 1.5, hx + 4.0, hy + 1.2, hexc("#3a0a10"))
        c.capsule(hx + 3.0, hy + 1.6, hx + 7.5, hy + 1.2, 0.6, 0.5, Mat(["#8a2a3a", "#c84a5a", "#f07a8a"], rim=0.0, outline="#3a0a10"), z=2.4)
    return {"hand": [hx + 4, hy + 1], "head": [hx, hy - 6]}


# ===========================================================================
# FLUTUANTES: ESPECTRO (ghost), LAMPADÁRIO (wraith), CRÂNIO (fire_skull),
# MORCEGO-BRASA (diver)
# ===========================================================================

M_SPECTER = Mat(["#0c0c1c", "#161830", "#22264a", "#303a66", "#44568a"], rim=0.8, rim_color="#7ad8ff", outline="#05050e")
M_SPECTER_IN = Mat(["#04040a", "#08080f", "#0c0c16"], flat=True, rim=0.0, outline="#04040a")
M_LAMP_ROBE = Mat(["#1c1628", "#2e2442", "#44365e", "#5e4c80"], rim=0.7, rim_color="#c0a8ff", outline="#0a0612")
M_MASK = Mat(["#6e665e", "#a0968a", "#cfc4b2", "#efe6d4"], rim=0.5, outline="#1a1614")
M_POLE = Mat(["#1e140c", "#3a2616", "#5a3c22", "#7a5634"], rim=0.3, outline="#0a0604")
M_LANTERN = Mat(["#1a1a22", "#3a3a4a", "#6a6a80"], spec=0.5, rim=0.4, outline="#08080c")
M_SKULL = Mat(["#6a5e4c", "#9c907a", "#c8bca2", "#ece2cc", "#fffaec"], rim=0.6, rim_color="#ffd8a0", outline="#1e160e")
M_BAT = Mat(["#1a0c0c", "#301616", "#4a2220", "#6a3228"], rim=0.7, rim_color="#ff8a4a", outline="#0a0404")
M_WING = Mat(["#240e0e", "#3e1a18", "#5a2a24"], rim=0.6, rim_color="#ff9a4a", outline="#0a0404", wrap=0.2)


def float_pose(anim, t, i, n):
    p = base_pose(anim, t, i, n)
    p["bob"] = wave(t) * 1.5 if anim in ("idle", "move") else p["bob"]
    p["flap"] = wave(t, 2 if anim == "move" else 1)
    return p


def draw_ghost(c, p, t):
    bob = p["bob"]
    lean = p["lean"] * 0.6
    cy = bob
    # manto em gota que termina em fiapos ondulantes
    pts = [(-5.5 + lean, cy - 6)]
    for k in range(7):
        x = -6.5 + k * 2.2
        y = cy + 9 + wave(t, 1, k * 0.35) * 1.8 + (2.5 if k % 2 == 0 else 0)
        pts.append((x - lean * 0.5, y))
    pts += [(6.0 + lean, cy - 6), (3.0 + lean, cy - 12), (-3.0 + lean, cy - 12)]
    c.poly(pts, M_SPECTER, z=1.0, bevel=3.0, folds=(1.0, 1.2, t * 2, 0.22))
    # capuz
    hx, hy = 1.0 + lean * 1.5, cy - 10.0
    c.ellipse(hx, hy, 5.4, 5.6, M_SPECTER, z=2.0)
    c.ellipse(hx + 1.6, hy + 1.0, 3.2, 3.6, M_SPECTER_IN, z=2.2, no_outline=True)
    if not p["blink"]:
        col = hexc("#6ae8ff")
        c.dot(hx + 1.0, hy + 0.5, col, glow=True)
        c.dot(hx + 3.2, hy + 0.5, col, glow=True)
        c.dot(hx + 1.0, hy + 1.3, hexc("#2a8ac8"), glow=True)
        c.dot(hx + 3.2, hy + 1.3, hexc("#2a8ac8"), glow=True)
    # mãos que brilham
    for k, (dx, dy) in enumerate([(5.5, -2.0 + p["arm"] * 2), (-4.0, 0.0)]):
        col = hexc("#9af0ff") if p["cast"] > 0.5 else hexc("#5ab8e0")
        c.circle(dx + lean, cy + dy, 1.4, Mat(["#1a4a6a", "#3a8ac0", "#7ad0f0"], rim=0.0, glow=None), z=3.0 if k == 0 else 0.5)
        if p["cast"] > 0.5 and k == 0:
            c.dot(dx + lean, cy + dy - 2.0, col, glow=True)
    return {"hand": [5.5 + lean, cy - 2.0], "head": [hx, hy - 7]}


def draw_wraith(c, p, t):
    bob = p["bob"]
    lean = p["lean"] * 0.5
    cy = bob
    # vara com lanterna (atrás/na frente)
    lx, ly = 9.0 + lean, cy - 13.0
    c.capsule(3.0 + lean, cy + 6, lx - 0.5, ly - 1.0, 0.9, 0.8, M_POLE, z=0.5)
    c.capsule(lx - 0.5, ly - 1.0, lx + 2.5, ly - 1.5, 0.8, 0.6, M_POLE, z=0.5)
    sway = wave(t) * 0.8
    c.line(lx + 2.5, ly - 1.5, lx + 2.5 + sway, ly + 1.5, hexc("#3a3a44"))
    # lanterna: gaiola + chama azul
    gx, gy = lx + 2.5 + sway, ly + 4.0
    c.poly([(gx - 2.2, gy - 2.5), (gx + 2.2, gy - 2.5), (gx + 2.6, gy + 2.5), (gx - 2.6, gy + 2.5)], M_LANTERN, z=4.0, bevel=0.8)
    for yy in range(-1, 2):
        for xx in range(-1, 2):
            if abs(xx) + abs(yy) < 2:
                c.dot(gx + xx, gy + yy, hexc("#fff4d8") if xx == 0 and yy == 0 else hexc("#9ad8ff"), glow=True)
    # manto encurvado
    pts = [(-4.0 + lean, cy - 9)]
    for k in range(6):
        x = -6.0 + k * 2.4
        y = cy + 9 + wave(t, 1, k * 0.3) * 1.4 + (2 if k % 2 else 0)
        pts.append((x, y))
    pts += [(6.5 + lean, cy - 2), (4.0 + lean, cy - 10)]
    c.poly(pts, M_LAMP_ROBE, z=1.0, bevel=3.0, folds=(1.0, 1.1, t * 2, 0.2))
    # capuz alto + máscara de bico
    hx, hy = 2.0 + lean * 1.5, cy - 11.0
    c.poly([(hx - 4.5, hy + 3), (hx - 3.5, hy - 5), (hx - 1.0, hy - 8), (hx + 3.5, hy - 3), (hx + 4.5, hy + 3)], M_LAMP_ROBE, z=2.0, bevel=2.0)
    c.poly([(hx - 0.5, hy - 2.5), (hx + 2.8, hy - 2.5), (hx + 7.5, hy + 1.2), (hx + 2.0, hy + 2.2), (hx - 0.5, hy + 1.8)], M_MASK, z=2.5, bevel=1.4)
    if not p["blink"]:
        c.dot(hx + 1.5, hy - 1.2, hexc("#8ad0ff"), glow=True)
    # mão na vara
    c.circle(3.5 + lean, cy + 3.5, 1.3, M_MASK, z=3.0)
    return {"hand": [gx, gy], "head": [hx, hy - 9], "lantern": [gx, gy]}


def draw_fire_skull(c, p, t):
    bob = p["bob"]
    cx, cy = 0.0, bob + 1.0
    # chamas por trás (subindo)
    c.flame(cx - 2.0, cy - 3.0, 9.0, 10.0, lean=-1.4, t=t)
    c.flame(cx + 2.5, cy - 4.0, 5.0, 6.5, lean=-0.8, t=t + 0.37)
    # crânio
    c.ellipse(cx, cy - 1.0, 6.6, 6.0, M_SKULL, z=5.0)
    c.poly([(cx - 1.5, cy + 2.5), (cx + 5.0, cy + 2.5), (cx + 4.2, cy + 6.0 + p["jaw"] * 1.5), (cx - 0.5, cy + 6.0 + p["jaw"] * 1.5)], M_SKULL, z=5.1, bevel=1.2)
    # órbitas
    for dx in (0.5, 3.6):
        c.ellipse(cx + dx, cy - 0.8, 1.4, 1.6, SOCK, z=5.5, no_outline=True)
        if not p["blink"]:
            c.dot(cx + dx, cy - 0.8, hexc("#ffb040"), glow=True)
    c.line(cx + 2.0, cy + 1.2, cx + 2.4, cy + 2.2, hexc("#2a1e14"))
    # dentes
    for k in range(4):
        c.dot(cx + 0.2 + k * 1.2, cy + 4.0, hexc("#2a1e14"))
    return {"hand": [cx + 5, cy], "head": [cx, cy - 12]}


def draw_diver(c, p, t):
    bob = p["bob"]
    cy = bob
    f = p["flap"]
    # asas: membrana em leque, pontas descem/sobem
    for k, s in enumerate([-1, 1]):
        z = 0.5 if s < 0 else 3.0
        up = f * 6.0
        root = (s * 1.5, cy - 1.0)
        tip1 = (s * 11.0, cy - 5.0 - up)
        tip2 = (s * 9.0, cy + 3.0 - up * 0.6)
        tip3 = (s * 5.0, cy + 4.5 - up * 0.3)
        c.poly([root, (s * 5.0, cy - 5.0 - up * 0.7), tip1, (s * 9.5, cy - 0.5 - up * 0.8), tip2, (s * 6.5, cy + 2.5 - up * 0.5), tip3, (s * 2.0, cy + 2.0)], M_WING, z=z, bevel=1.4)
        # veias que brilham como brasa
        c.line(root[0], root[1], tip1[0], tip1[1], hexc("#c8501e"), glow=True)
        c.line(s * 5.0, cy - 3.0 - up * 0.5, tip2[0], tip2[1], hexc("#8a3014"), glow=True)
    # corpo
    c.ellipse(0.0, cy, 3.2, 3.8, M_BAT, z=2.0)
    c.ellipse(0.8, cy - 3.6, 2.8, 2.4, M_BAT, z=2.2)
    c.poly([(-1.2, cy - 5.0), (0.2, cy - 5.0), (-1.0, cy - 8.0)], M_BAT, z=2.1, bevel=0.6)
    c.poly([(1.2, cy - 5.0), (2.6, cy - 5.0), (2.0, cy - 8.0)], M_BAT, z=2.3, bevel=0.6)
    if not p["blink"]:
        c.dot(1.0, cy - 3.8, hexc("#ffd060"), glow=True)
        c.dot(2.6, cy - 3.8, hexc("#ffd060"), glow=True)
    # brasa no peito
    c.dot(0.6, cy + 0.5, hexc("#ff8a3a"), glow=True)
    c.dot(0.6, cy + 1.5, hexc("#c8401a"), glow=True)
    return {"hand": [2, cy + 2], "head": [1, cy - 9]}


def bat_pose(anim, t, i, n):
    p = float_pose(anim, t, i, n)
    p["flap"] = wave(t, 1)
    if anim == "attack":
        p["flap"] = [0.8, -0.6, 0.2][min(i, 2)]
    return p


# ===========================================================================
# BESTA DO INFERNO (hell_beast) — demônio atarracado que cospe fogo
# ===========================================================================

M_BEAST = Mat(["#1e0a08", "#3e1410", "#62221a", "#8a3424", "#b04a30"], rim=0.7, rim_color="#ffa050", outline="#0a0402")
M_HORN = Mat(["#3a2e24", "#6a5a48", "#a0907a", "#d0c4ae"], rim=0.5, outline="#140e08")


def draw_hell_beast(c, p, t):
    bob, lean = p["bob"], p["lean"] * 0.6
    hip = -8.0 + bob * 0.5
    legs(c, p, hip, M_BEAST, M_BEAST, r=2.4, lean=lean, hip_w=3.0, boot_r=(3.0, 1.6))
    top = -22.0 + bob
    # corpo curvado, peito de lava rachado
    c.ellipse(0.5 + lean, top + 7.0, 8.0, 8.5, M_BEAST, z=2.0)
    for (a, b) in [((-2, top + 5), (1, top + 8)), ((1, top + 8), (0, top + 11)), ((1, top + 8), (4, top + 9))]:
        c.line(a[0] + lean, a[1], b[0] + lean, b[1], hexc("#ff7a2a"), glow=True)
    # braços pesados
    for k, dx in enumerate([-6.5, 6.5]):
        z = 1.0 if k == 0 else 3.0
        c.limb([(dx + lean, top + 3), (dx * 1.15 + lean, top + 10), (dx * 1.05 + lean + p["arm"] * 2, top + 16)], [2.6, 2.3, 2.6], M_BEAST, z=z)
    # cabeça baixa com chifres grandes
    hx, hy = 3.5 + lean * 1.5, top - 1.0
    c.ellipse(hx, hy, 5.0, 4.4, M_BEAST, z=4.0)
    c.limb([(hx - 2, hy - 3), (hx - 6, hy - 7), (hx - 4, hy - 11)], [1.6, 1.2, 0.6], M_HORN, z=3.8)
    c.limb([(hx + 2, hy - 3), (hx + 5, hy - 8), (hx + 3, hy - 12)], [1.6, 1.2, 0.6], M_HORN, z=4.2)
    # boca (abre no ataque, brilho de fogo)
    mo = p["open"]
    c.poly([(hx + 1, hy + 1.0), (hx + 5.5, hy + 0.5), (hx + 5.5, hy + 2.0 + mo * 2.5), (hx + 1, hy + 2.2 + mo * 1.5)], SOCK, z=4.4, no_outline=True, bevel=0.1)
    if mo > 0.3:
        for xx in range(2, 5):
            c.dot(hx + xx, hy + 2.0, hexc("#ffc050"), glow=True)
            c.dot(hx + xx, hy + 3.0, hexc("#ff6a1a"), glow=True)
    if not p["blink"]:
        c.dot(hx + 1.5, hy - 1.5, hexc("#ffd040"), glow=True)
        c.dot(hx + 3.8, hy - 1.5, hexc("#ffd040"), glow=True)
    return {"hand": [hx + 6, hy + 2], "head": [hx, hy - 12], "mouth": [hx + 5, hy + 2]}


# ===========================================================================
# CORCEL DO PESADELO (nightmare) — cavalo negro de ossos com crina de chamas
# ===========================================================================

M_STEED = Mat(["#07060c", "#100e1a", "#1c1a2c", "#2a2842", "#3a3a5c"], rim=0.8, rim_color="#6ae0ff", outline="#030306")
NIGHT_FIRE = [hexc("#1a3a8a"), hexc("#2a7ae0"), hexc("#7ad8ff"), hexc("#e8fbff")]


def draw_nightmare(c, p, t):
    bob, cr, st = p["bob"], p["crouch"], p["stretch"]
    by = -18.0 + bob + cr
    bx0, bx1 = -13.0, 11.0
    gait = p["gait"]
    for k, (px, ph) in enumerate([(bx0 + 3, 0.0), (bx1 - 2, 0.5), (bx0 + 6, 0.25), (bx1 + 1, 0.75)]):
        z = -1.0 if k < 2 else 1.5
        s = math.sin((t + ph) * math.tau) * gait
        cc = math.cos((t + ph) * math.tau) * gait
        fx = px + s * 5.0 + (st * (4 if k % 2 else -4))
        fy = -max(0.0, cc) * 3.5
        knee = (px + (fx - px) * 0.5 + (1.5 if k % 2 == 0 else -1.0), (by + 4 + fy) * 0.5 + 2.0)
        c.limb([(px, by + 4), knee, (fx, fy - 1.2)], [2.4, 1.6, 1.4], M_STEED, z=z)
        # casco em chamas
        c.flame(fx + 0.5, fy - 0.5, 3.0, 3.5, lean=-1.0, t=t + k * 0.2, palette=NIGHT_FIRE)
    # corpo
    c.ellipse((bx0 + bx1) * 0.5, by + 1.5, 13.5, 6.5, M_STEED, z=1.0)
    for k in range(4):
        x = bx1 - 4 - k * 3
        c.line(x, by - 1.5, x - 1.0, by + 4.0, hexc("#3a3a5a"))
    # cauda de fogo
    c.flame(bx0 - 2.0, by + 1.0, 5.0, 10.0, lean=-3.0, t=t, palette=NIGHT_FIRE)
    # pescoço e cabeça
    nx, ny = bx1 + 1.0, by - 2.0
    hx, hy = bx1 + 7.0 + st * 2.0, by - 10.0 + p["head"] * 1.5
    c.capsule(nx, ny, hx - 1.0, hy + 1.0, 4.0, 3.0, M_STEED, z=1.5)
    c.poly([(hx - 3.0, hy - 3.0), (hx + 2.0, hy - 3.0), (hx + 7.5, hy + 2.0), (hx + 6.5, hy + 4.0), (hx - 1.0, hy + 3.5)], M_STEED, z=2.0, bevel=1.6)
    # crina de chamas azuis
    for k in range(4):
        mx = nx + (hx - nx) * (k / 4.0)
        my = ny + (hy - ny) * (k / 4.0) - 3.5
        c.flame(mx - 1.0, my + 1.0, 4.0, 7.0 + (k % 2) * 2, lean=-2.5, t=t + k * 0.13, palette=NIGHT_FIRE)
    c.poly([(hx - 1.5, hy - 3.0), (hx + 0.5, hy - 3.0), (hx - 1.0, hy - 7.0)], M_STEED, z=2.1, bevel=0.6)
    if not p["blink"]:
        c.dot(hx + 2.0, hy - 0.8, hexc("#8af0ff"), glow=True)
        c.dot(hx + 3.0, hy - 0.8, hexc("#e8fbff"), glow=True)
    return {"hand": [hx + 7, hy + 3], "head": [hx, hy - 8]}


# ===========================================================================
# ATIRADOR DE FERROLHO (gunner) — goblin encapuzado com besta e olho-lanterna
# ===========================================================================

M_LEATHER = Mat(["#1a120c", "#302016", "#4a3222", "#684830", "#886040"], rim=0.6, rim_color="#e0a060", outline="#0a0604")
M_HOODG = Mat(["#141216", "#242028", "#36303c", "#4a4252"], rim=0.6, rim_color="#8a7a9a", outline="#060508")
M_WOODB = Mat(["#2a1a0e", "#4a2e18", "#6e4626", "#946236"], rim=0.4, outline="#0e0804")


def draw_gunner(c, p, t):
    bob, lean = p["bob"], p["lean"] * 0.5
    hip = -7.0 + bob * 0.5
    legs(c, p, hip, M_LEATHER, M_HOODG, r=1.4, lean=lean)
    top = -17.0 + bob
    c.poly([(-4.5 + lean, top), (4.0 + lean, top), (5.0, hip + 2.5), (-5.5, hip + 2.5)], M_LEATHER, z=2.0, bevel=2.2, folds=(1.0, 1.2, t, 0.18))
    # capuz
    hx, hy = 1.0 + lean * 1.5, top - 4.0
    c.poly([(hx - 5, hy + 4), (hx - 4.5, hy - 2), (hx - 1, hy - 5.5), (hx + 3.0, hy - 3.5), (hx + 5.5, hy + 1), (hx + 4.5, hy + 4)], M_HOODG, z=3.0, bevel=2.0)
    c.ellipse(hx + 2.0, hy + 1.0, 2.8, 2.6, SOCK, z=3.2, no_outline=True)
    # olho-lanterna (mira laser sai daqui)
    c.circle(hx + 2.6, hy + 0.8, 1.3, Mat(["#5a0a0a", "#c8201a", "#ff6a4a"], rim=0.0, outline="#1a0404"), z=3.4)
    c.dot(hx + 2.6, hy + 0.2, hexc("#ffe0c0"), glow=True)
    c.dot(hx + 3.2, hy + 0.8, hexc("#ff4a2a"), glow=True)
    # besta apoiada
    aim = p["open"]
    bx, byy = 6.0 + lean, top + 5.0 - aim
    c.capsule(bx - 5.0, byy + 1.0, bx + 6.0, byy, 1.1, 1.0, M_WOODB, z=4.0)
    c.limb([(bx + 3.5, byy - 5.0), (bx + 5.0, byy), (bx + 3.5, byy + 5.0)], [0.8, 1.0, 0.8], M_IRON, z=3.9)
    c.line(bx + 3.2, byy - 4.5, bx - 1.5, byy, hexc("#c8c0b0"))
    c.line(bx - 1.5, byy, bx + 3.2, byy + 4.5, hexc("#c8c0b0"))
    c.circle(bx - 2.5, byy + 1.5, 1.2, M_LEATHER, z=4.2)
    return {"hand": [bx + 6, byy], "head": [hx, hy - 7], "eye": [hx + 2.6, hy + 0.5]}


# ===========================================================================
# LÂMINA SOMBRIA (assassin) — figura esguia mascarada, cachecol violeta
# ===========================================================================

M_SHADOW = Mat(["#07060c", "#0e0c16", "#171424", "#221e34", "#302a48"], rim=0.85, rim_color="#d06aff", outline="#030206")
M_SCARF_V = Mat(["#2a0a2a", "#4a1448", "#6e2268", "#943488"], rim=0.7, rim_color="#ff8aff", outline="#10040e")
M_MASK2 = Mat(["#3a3848", "#6a6680", "#a8a4bc", "#dcd8ec"], rim=0.4, outline="#0e0c14")


def draw_assassin(c, p, t):
    bob, lean = p["bob"], p["lean"] * 0.8
    hip = -9.5 + bob * 0.5
    legs(c, p, hip, M_SHADOW, M_SHADOW, r=1.3, lean=lean)
    top = -21.0 + bob
    sh = lean * 0.8
    # cachecol longo
    neck = (-2.0 + sh, top + 0.5)
    pts = [neck]
    ang = math.radians(160 + (15 if p["anim"] == "move" else 0))
    for j in range(1, 7):
        k = j / 6.0
        w = math.sin((t * 2 - k * 0.9) * math.tau) * 1.8 * k
        pts.append((neck[0] + math.cos(ang) * 2.4 * j, neck[1] + math.sin(ang) * 2.4 * j + w + j * 0.8))
    c.ribbon(pts, [3.6, 3.4, 3.0, 2.6, 2.2, 1.8, 1.4], M_SCARF_V, z=1.0, twist=t * math.tau)
    # corpo esguio
    c.poly([(-3.6 + sh, top), (3.6 + sh, top), (3.0 + sh * 0.5, hip + 1), (-3.2 + sh * 0.5, hip + 1)], M_SHADOW, z=2.0, bevel=2.0)
    c.ellipse(0.5 + sh, top + 0.6, 4.2, 1.8, M_SCARF_V, z=2.6)
    # cabeça: capuz pontudo + máscara
    hx, hy = 0.8 + lean, top - 4.8
    c.poly([(hx - 4.2, hy + 4), (hx - 4.0, hy - 1.5), (hx - 2.0, hy - 6.5), (hx + 2.5, hy - 4.5), (hx + 4.5, hy), (hx + 4.0, hy + 4)], M_SHADOW, z=3.0, bevel=2.0)
    c.poly([(hx - 0.5, hy - 1.5), (hx + 4.2, hy - 1.5), (hx + 4.0, hy + 2.8), (hx + 1.0, hy + 3.0)], M_MASK2, z=3.4, bevel=1.2)
    if not p["blink"]:
        col = hexc("#ff6ae8")
        c.line(hx + 1.2, hy - 0.2, hx + 2.2, hy + 0.3, col, glow=True)
        c.line(hx + 3.0, hy + 0.3, hx + 3.8, hy - 0.2, col, glow=True)
    hdx, hdy = p["hand"]
    c.limb([(3.0 + sh, top + 2), (hdx + lean * 0.5, hdy + bob * 0.5)], [1.2, 1.1], M_SHADOW, z=4.0)
    return {"hand": [hdx + lean * 0.5, hdy + bob * 0.5], "head": [hx, hy - 8]}


# ===========================================================================
# ESCUDEIRO DE FERRO (shieldbearer) — cavaleiro pesado de armadura e pluma
# ===========================================================================

M_PLATE = Mat(["#1a1c26", "#343848", "#5a6074", "#8a92a8", "#c0c8dc"], spec=0.9, rim=0.6, rim_color="#e0ecff", outline="#08090e")
M_PLUME = Mat(["#3a0a0e", "#6a141a", "#9a2228", "#c83a3a"], rim=0.6, rim_color="#ff8a7a", outline="#140406")


def draw_shieldbearer(c, p, t):
    bob, lean = p["bob"], p["lean"] * 0.5
    hip = -9.0 + bob * 0.5
    legs(c, p, hip, M_PLATE, M_PLATE, r=2.0, lean=lean, hip_w=2.4, boot_r=(2.8, 1.6))
    top = -22.0 + bob
    sh = lean * 0.6
    c.poly([(-6.0 + sh, top), (6.0 + sh, top), (5.0 + sh * 0.5, hip + 1.5), (-5.4 + sh * 0.5, hip + 1.5)], M_PLATE, z=2.0, bevel=3.0)
    c.poly([(-4.8, hip - 1.5), (4.6, hip - 1.5), (5.2, hip + 3.5), (-5.2, hip + 3.5)], M_TABARD, z=2.2, bevel=1.4)
    c.ellipse(-5.5 + sh, top + 1.5, 3.4, 2.6, M_PLATE, z=2.4)
    c.ellipse(5.5 + sh, top + 1.5, 3.4, 2.6, M_PLATE, z=3.4)
    # elmo fechado com fenda e pluma
    hx, hy = 0.8 + lean, top - 5.4
    c.poly([(hx - 5.0, hy + 5), (hx - 5.0, hy - 3), (hx - 2.5, hy - 6), (hx + 3.0, hy - 6), (hx + 5.3, hy - 3), (hx + 5.3, hy + 5)], M_PLATE, z=4.0, bevel=2.6)
    c.poly([(hx + 0.5, hy - 0.4), (hx + 5.4, hy - 0.4), (hx + 5.4, hy + 0.8), (hx + 0.5, hy + 0.8)], SOCK, z=4.3, no_outline=True, bevel=0.1)
    if not p["blink"]:
        c.dot(hx + 2.5, hy + 0.2, hexc("#ffe08a"), glow=True)
        c.dot(hx + 4.5, hy + 0.2, hexc("#ffe08a"), glow=True)
    pl = [(hx - 1.0, hy - 5.5)]
    for j in range(1, 6):
        pl.append((hx - 1.0 - j * 1.8, hy - 6.5 - math.sin(j * 0.6) * 2.0 + wave(t, 1, j * 0.2) * 0.6 + j * 0.6))
    c.ribbon(pl, [2.6, 3.0, 2.8, 2.4, 1.8, 1.2], M_PLUME, z=3.9)
    return {"hand": [p["hand"][0] + lean * 0.5 + 1, p["hand"][1] + bob * 0.5 + 1], "head": [hx, hy - 9]}


# ===========================================================================
# CHEFES
# ===========================================================================

M_BROOD = Mat(["#1a0c14", "#301622", "#4c2434", "#6c3648", "#8c4c5c"], rim=0.7, rim_color="#ffb070", outline="#0a0408")
M_BROOD_SHELL = Mat(["#2a1a1e", "#4e3236", "#7a5250", "#a87a70", "#d0a898"], spec=0.4, rim=0.6, rim_color="#ffd0a0", outline="#0e0808")
M_EGG = Mat(["#6a5a2a", "#a89040", "#e0c860", "#fff0a0"], rim=0.0, outline="#2a2008")


def draw_brood_mother(c, p, t):
    bob = p["bob"]
    by = -16.0 + bob
    # patas segmentadas (6)
    for k in range(6):
        side = -1 if k < 3 else 1
        z = -1.0 if side < 0 else 2.5
        px = -12.0 + (k % 3) * 11.0
        s = math.sin((t + k * 0.17) * math.tau) * (1.0 if p["anim"] == "move" else 0.25)
        c.limb([(px, by + 3), (px + 4 + s * 2, by - 4), (px + 8 + s * 3, -1.0)], [2.0, 1.6, 1.0], M_BROOD_SHELL, z=z)
    # abdômen com ovos brilhantes
    c.ellipse(-12.0, by - 1.0, 13.0, 10.0, M_BROOD, z=1.0)
    for k, (ex, ey) in enumerate([(-18, -4), (-12, -8), (-7, -3), (-15, 3), (-9, 3)]):
        c.circle(ex, by + ey, 2.4, M_EGG, z=1.5)
        c.dot(ex - 0.5, by + ey - 0.8, hexc("#fff8c0"), glow=True)
    # tórax blindado
    c.ellipse(4.0, by - 2.0, 9.0, 7.5, M_BROOD_SHELL, z=2.0)
    for k in range(3):
        c.line(-1.0 + k * 3.5, by - 8.5, 0.5 + k * 3.5, by + 3.0, hexc("#2a1818"))
    # cabeça com chifres e um olho grande
    hx, hy = 13.0, by - 5.0
    c.ellipse(hx, hy, 6.0, 5.2, M_BROOD, z=3.0)
    c.limb([(hx - 2, hy - 4), (hx - 1, hy - 10), (hx - 5, hy - 14)], [1.8, 1.2, 0.6], M_HORN, z=2.8)
    c.limb([(hx + 2, hy - 4), (hx + 5, hy - 9), (hx + 3, hy - 14)], [1.8, 1.2, 0.6], M_HORN, z=3.2)
    c.circle(hx + 2.0, hy + 0.5, 2.6, Mat(["#5a3a0a", "#c88a1a", "#ffd040", "#fff0a0"], rim=0.0, outline="#1a0e02"), z=3.4)
    c.dot(hx + 2.0, hy + 0.5, hexc("#1a0a02"))
    c.dot(hx + 1.0, hy - 0.8, hexc("#fffbe0"), glow=True)
    # mandíbulas
    jaw = p["jaw"]
    c.capsule(hx + 4, hy + 3, hx + 9, hy + 4 + jaw * 2, 1.2, 0.6, M_HORN, z=3.3)
    c.capsule(hx + 4, hy + 4, hx + 8, hy + 7 + jaw * 2, 1.2, 0.6, M_HORN, z=2.9)
    return {"hand": [hx + 8, hy + 4], "head": [hx, hy - 15]}


M_STONE = Mat(["#1e1e24", "#34343c", "#50505a", "#72727c", "#9a9aa2"], rim=0.6, rim_color="#c8d8e0", outline="#0a0a0e", wrap=0.3)
M_MOSS = Mat(["#1e2e16", "#34502a", "#4e7040", "#709a56"], rim=0.4, outline="#0a1006")
CORE_GLOW = hexc("#6affd8")


def draw_colossus(c, p, t):
    bob, lean = p["bob"], p["lean"] * 0.5
    hip = -16.0 + bob
    # pernas-pilar
    for k, fx in enumerate(p["legs"]):
        x, fy, _ = fx
        z = -1.0 if k == 0 else 1.5
        x = x * 2.2
        c.poly([(x - 5.5, hip), (x + 5.0, hip), (x + 6.0, fy - 1), (x - 6.5, fy - 1)], M_STONE, z=z, bevel=2.5)
    top = -50.0 + bob + (24.0 if p.get("lowered") else 0.0)
    if p.get("lowered"):
        hip = top + 34.0
    # tronco de rocha
    c.poly([(-15 + lean, top + 4), (-6 + lean, top - 2), (10 + lean, top - 1), (17 + lean, top + 6), (13, hip + 2), (-12, hip + 2)], M_STONE, z=2.0, bevel=4.0)
    # musgo nos ombros
    c.ellipse(-10 + lean, top + 1, 6.0, 2.4, M_MOSS, z=2.2)
    c.ellipse(12 + lean, top + 2, 5.0, 2.0, M_MOSS, z=2.2)
    # núcleo que brilha (ponto fraco) — abaixa no pisão
    cx, cy = 0.5 + lean, top + 14
    c.circle(cx, cy, 4.0, SOCK, z=2.6, no_outline=True)
    for r in range(3):
        for a in range(0, 360, 45):
            x = cx + math.cos(math.radians(a + t * 90)) * r
            y = cy + math.sin(math.radians(a + t * 90)) * r
            c.dot(x, y, CORE_GLOW if r < 2 else hexc("#2a9a8a"), glow=True)
    # rachaduras que brilham
    for (a, b) in [((cx - 3, cy - 3), (cx - 8, cy - 9)), ((cx + 3, cy - 2), (cx + 9, cy - 7)), ((cx, cy + 4), (cx - 2, cy + 10))]:
        c.line(a[0], a[1], b[0], b[1], hexc("#3ac8a8"), glow=True)
    # braços enormes
    arm = p["arm"]
    c.limb([(-14 + lean, top + 5), (-19 + lean, top + 16), (-17 + lean - arm * 3, top + 28)], [5.0, 4.4, 5.5], M_STONE, z=1.0)
    c.limb([(15 + lean, top + 6), (20 + lean, top + 17), (18 + lean + arm * 4, top + 29)], [5.0, 4.4, 5.8], M_STONE, z=3.0)
    # cabeça pequena afundada
    hx, hy = 3.0 + lean * 1.2, top - 5.0
    c.poly([(hx - 6, hy + 4), (hx - 5, hy - 4), (hx + 5, hy - 5), (hx + 7, hy + 3)], M_STONE, z=4.0, bevel=2.0)
    c.poly([(hx - 2, hy - 1), (hx + 6, hy - 1), (hx + 6, hy + 1.5), (hx - 2, hy + 1.5)], SOCK, z=4.3, no_outline=True, bevel=0.1)
    if not p["blink"]:
        c.dot(hx + 1, hy, CORE_GLOW, glow=True)
        c.dot(hx + 4, hy, CORE_GLOW, glow=True)
    return {"hand": [18 + lean + arm * 4, top + 29], "head": [hx, hy - 8], "core": [cx, cy]}


M_DEMON = Mat(["#07050a", "#110c16", "#1e1626", "#2e223a", "#403050"], rim=0.85, rim_color="#ff8a5a", outline="#030204")
M_DEMON_WING = Mat(["#100a12", "#1e1422", "#2e1e34"], rim=0.7, rim_color="#ff7040", outline="#050306", wrap=0.2)
M_DSKULL = Mat(["#5a5048", "#8a8070", "#bcb09a", "#e4dac4"], rim=0.6, rim_color="#ffd8b0", outline="#18120c")


def draw_archdemon(c, p, t):
    bob = p["bob"]
    cy = bob
    f = p["flap"]
    # asas grandes
    for k, s in enumerate([-1, 1]):
        z = 0.2 if s < 0 else 0.4
        up = f * 5.0
        root = (-2.0 + s * 3.0, cy - 12.0)
        pts = [root, (s * 12.0 - 4, cy - 26 - up), (s * 26.0 - 4, cy - 20 - up), (s * 22.0 - 4, cy - 10 - up * 0.6),
               (s * 26.0 - 4, cy - 4 - up * 0.4), (s * 16.0 - 4, cy - 2), (s * 18.0 - 4, cy + 6), (s * 6.0 - 3, cy - 2)]
        c.poly(pts, M_DEMON_WING, z=z, bevel=2.0)
        c.line(root[0], root[1], s * 26.0 - 4, cy - 20 - up, hexc("#6a2a1a"))
    # manto/corpo que termina em fumaça
    pts = [(-8, cy - 14)]
    for k in range(8):
        x = -10 + k * 2.8
        pts.append((x, cy + 18 + wave(t, 1, k * 0.3) * 2 + (3 if k % 2 else 0)))
    pts += [(11, cy - 14), (4, cy - 20), (-3, cy - 20)]
    c.poly(pts, M_DEMON, z=1.0, bevel=4.0, folds=(1.0, 0.9, t * 2, 0.2))
    # brasas no peito
    for k in range(5):
        c.dot(-2 + k * 1.6, cy - 6 + (k % 2) * 2, hexc("#ff7a3a"), glow=True)
    # cabeça: crânio com chifres enormes (ponto fraco)
    hx, hy = 1.0, cy - 25.0
    c.limb([(hx - 4, hy - 3), (hx - 12, hy - 8), (hx - 13, hy - 17)], [2.4, 1.6, 0.6], M_HORN, z=2.8)
    c.limb([(hx + 4, hy - 3), (hx + 11, hy - 9), (hx + 10, hy - 18)], [2.4, 1.6, 0.6], M_HORN, z=3.2)
    c.ellipse(hx, hy, 6.2, 6.6, M_DSKULL, z=3.0)
    c.poly([(hx - 3, hy + 4), (hx + 5, hy + 4), (hx + 4, hy + 9 + p["jaw"] * 2), (hx - 2, hy + 9 + p["jaw"] * 2)], M_DSKULL, z=3.1, bevel=1.4)
    for dx in (-1.0, 3.2):
        c.ellipse(hx + dx, hy + 0.5, 1.8, 2.0, SOCK, z=3.4, no_outline=True)
        if not p["blink"]:
            c.dot(hx + dx, hy + 0.5, hexc("#6af0ff"), glow=True)
            c.dot(hx + dx, hy - 0.4, hexc("#e8fbff"), glow=True)
    # braços com garras
    for k, s in enumerate([-1, 1]):
        z = 0.8 if s < 0 else 3.5
        c.limb([(s * 7, cy - 13), (s * 11, cy - 4), (s * 9 + p["arm"] * 3 * s, cy + 3)], [2.4, 2.0, 1.6], M_DEMON, z=z)
    return {"hand": [9 + p["arm"] * 3, cy + 3], "head": [hx, hy - 18]}


def colossus_pose(anim, t, i, n):
    """Colosso: "crouch" = ajoelhado depois do pisão (núcleo 12 unidades
    mais baixo, igual ao ponto fraco no jogo)."""
    p = base_pose("idle" if anim == "crouch" else anim, t, i, n)
    if anim == "crouch":
        p["lowered"] = True
        p["legs"] = [(-4.0, 0.0, 1.0), (4.0, 0.0, 1.0)]
        p["arm"] = 0.6
    return p


# ---------------------------------------------------------------------------
# registro: id -> (tamanho (w, h, ox, oy), animações, pose, desenho)
# animações: nome -> (quadros, fps, loop)
# ---------------------------------------------------------------------------

HUMANOID_ANIMS = {"idle": (4, 5, True), "move": (6, 10, True), "attack": (3, 10, False), "cast": (2, 6, True), "hurt": (1, 8, False)}
BEAST_ANIMS = {"idle": (4, 6, True), "move": (6, 12, True), "attack": (3, 10, False), "hurt": (1, 8, False), "jump": (3, 10, False)}
FLYER_ANIMS = {"idle": (6, 8, True), "move": (6, 10, True), "attack": (3, 10, False), "cast": (2, 6, True), "hurt": (1, 8, False)}

ENEMIES = {
    "skeleton": ((48, 44, 24, 40), HUMANOID_ANIMS, base_pose, draw_skeleton),
    "hound": ((60, 40, 30, 37), BEAST_ANIMS, quad_pose, draw_hound),
    "hellcat": ((60, 40, 30, 37), BEAST_ANIMS, quad_pose, draw_hellcat),
    "leaper": ((48, 40, 24, 37), dict(BEAST_ANIMS, fall=(1, 8, False)), quad_pose, draw_leaper),
    "ghost": ((44, 48, 22, 26), FLYER_ANIMS, float_pose, draw_ghost),
    "wraith": ((52, 48, 22, 26), FLYER_ANIMS, float_pose, draw_wraith),
    "fire_skull": ((36, 44, 18, 26), FLYER_ANIMS, float_pose, draw_fire_skull),
    "diver": ((44, 36, 22, 20), FLYER_ANIMS, bat_pose, draw_diver),
    "hell_beast": ((56, 52, 28, 48), HUMANOID_ANIMS, base_pose, draw_hell_beast),
    "nightmare": ((80, 60, 40, 56), BEAST_ANIMS, quad_pose, draw_nightmare),
    "gunner": ((52, 40, 24, 36), HUMANOID_ANIMS, base_pose, draw_gunner),
    "assassin": ((52, 44, 26, 40), HUMANOID_ANIMS, base_pose, draw_assassin),
    "shieldbearer": ((52, 48, 26, 44), HUMANOID_ANIMS, base_pose, draw_shieldbearer),
    "brood_mother": ((80, 60, 40, 56), BEAST_ANIMS, base_pose, draw_brood_mother),
    "colossus": ((100, 96, 50, 92), dict(HUMANOID_ANIMS, crouch=(2, 4, True)), colossus_pose, draw_colossus),
    "archdemon": ((100, 100, 50, 60), FLYER_ANIMS, float_pose, draw_archdemon),
}
