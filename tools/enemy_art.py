"""Inimigos: criaturinhas no mesmo estilo do herói (contorno escuro, 2-3 cores).

Cada função devolve {anim: [Canvas...]} e meta {size, feet (origem), fps}.
Todos olham para a DIREITA.
"""
import math
from px import Canvas, hexc

OUT = hexc("1b1528")


def _fin(c):
    c.outline(OUT)
    return c


# ---------------------------------------------------------------------------
# Esqueleto errante (bichinho de ossos com espada enferrujada) 16x16
# ---------------------------------------------------------------------------
BONE = hexc("e9dfcb")
BONE_SH = hexc("b3a58f")
RED_EYE = hexc("ff5a4a")
RUST = hexc("9a6a4a")


def skeleton_frame(bob=0, legs=0, lean=0, arm="down", rise=0):
    c = Canvas(16, 16)
    hy = 3 + bob + rise
    hx = 5 + lean
    # crânio redondo com mandíbula
    c.rows(hx, hy, [4, 6, 6, 6, 4], BONE)
    c.set(hx + 1, hy + 4, BONE_SH)
    c.set(hx + 3, hy + 4, BONE_SH)
    c.set(hx, hy - 1, BONE)
    c.set(hx - 1, hy - 2, BONE)
    c.set(hx + 5, hy - 1, BONE)
    c.set(hx + 6, hy - 2, BONE)
    # costelas / coluna
    by = hy + 5
    for i in range(3):
        if by + i < 16 - 3 + rise:
            c.hline(hx + 1, hx + 4, by + i, BONE if i % 2 == 0 else BONE_SH)
    c.vline(hx + 2, by, by + 3, BONE_SH)
    # pernas
    ly = by + 3
    if rise == 0:
        pts = {0: [(6, 0), (9, 0)], 1: [(5, 0), (10, 1)], 2: [(7, 0), (8, 0)], 3: [(10, 0), (5, 1)]}[legs]
        for lx, up in pts:
            c.vline(lx + lean, ly, 15 - up, BONE)
    # braço/espada
    if arm == "down":
        c.set(hx + 5, by + 1, BONE)
        c.line(hx + 6, by + 1, hx + 6, by + 4, RUST)
    elif arm == "up":
        c.set(hx + 5, by, BONE)
        c.line(hx + 5, by - 1, hx + 3, by - 5, RUST)
    elif arm == "swing":
        c.set(hx + 5, by + 1, BONE)
        c.line(hx + 6, by + 1, hx + 10, by + 1, RUST)
    _fin(c)
    # olhos acesos (depois do contorno para ficarem nítidos)
    c.set(hx + 2, hy + 2, RED_EYE)
    c.set(hx + 4, hy + 2, RED_EYE)
    return c


def skeleton():
    walk = [skeleton_frame(bob=b, legs=l) for b, l in ((0, 0), (-1, 1), (0, 2), (-1, 3))]
    idle = [skeleton_frame(0, 0), skeleton_frame(1, 0)]
    windup = [skeleton_frame(0, 0, lean=-1, arm="up")]
    attack = [skeleton_frame(0, 1, lean=1, arm="swing")]
    rise = [skeleton_frame(rise=r) for r in (9, 6, 3, 0)]
    return {"idle": idle, "walk": walk, "windup": windup, "attack": attack, "rise": rise}, {"size": [16, 16], "feet": [8, 16], "fps": {"walk": 8, "idle": 3, "rise": 8}}


# ---------------------------------------------------------------------------
# Cão infernal (raposinha de fogo) 18x12
# ---------------------------------------------------------------------------
FUR = hexc("c4462f")
FUR_SH = hexc("8e2c25")
FLAME = hexc("ffb347")
FLAME2 = hexc("ffe07a")


def hound_frame(phase=0, jump=False, crouch=False):
    c = Canvas(18, 12)
    y = 5 + (1 if crouch else 0)
    # corpo
    c.rows(4, y, [9, 10, 10], FUR)
    c.hline(5, 12, y + 2, FUR_SH)
    # cabeça
    c.rows(12, y - 3, [3, 5, 5, 4], FUR)
    c.set(16, y - 1, FUR_SH)  # focinho
    c.set(13, y - 4, FUR)  # orelha
    c.set(15, y - 4, FUR)
    # cauda flamejante
    c.set(3, y, FLAME)
    c.set(2, y - 1, FLAME)
    c.set(1, y - 2 + (phase % 2), FLAME2)
    # pernas
    legs = {0: [(5, 1), (7, 0), (11, 1), (13, 0)], 1: [(4, 0), (8, 1), (10, 0), (14, 1)],
            2: [(6, 0), (6, 1), (12, 0), (12, 1)], 3: [(5, 0), (7, 1), (11, 0), (13, 1)]}[phase % 4]
    if jump:
        legs = [(3, 0), (4, 0), (14, 0), (15, 0)]
        for lx, _ in legs:
            c.set(lx, y + 3, FUR_SH)
    else:
        for lx, up in legs:
            c.vline(lx, y + 3, 11 - up if not crouch else 11, FUR_SH)
    _fin(c)
    c.set(14, y - 2, FLAME2)  # olho
    # crina de fogo no dorso
    for i, fx in enumerate(range(6, 11, 2)):
        c.set(fx, y - 1 - ((i + phase) % 2), FLAME)
    return c


def hound():
    run = [hound_frame(i) for i in range(4)]
    idle = [hound_frame(0, crouch=False), hound_frame(2)]
    jump = [hound_frame(0, jump=True)]
    windup = [hound_frame(0, crouch=True)]
    return {"idle": idle, "run": run, "jump": jump, "windup": windup}, {"size": [18, 12], "feet": [9, 12], "fps": {"run": 12, "idle": 3}}


# ---------------------------------------------------------------------------
# Gato do abismo (gatinho sombrio de olhos amarelos) 14x10
# ---------------------------------------------------------------------------
CAT = hexc("3a2c55")
CAT_SH = hexc("261c3c")
CAT_EYE = hexc("ffd84a")


def cat_frame(phase=0, pounce=False, sit=False):
    c = Canvas(14, 10)
    y = 4
    if sit:
        c.rows(4, y, [4, 5, 6, 6], CAT)
        c.rows(7, y - 3, [1, 0, 4, 4], CAT, offsets=[0, 0, -1, -1]) if False else None
        c.rows(6, y - 3, [4, 5, 4], CAT)
        c.set(6, y - 4, CAT)
        c.set(9, y - 4, CAT)
        c.line(3, y + 3, 1, y + 1 - (phase % 2), CAT)
    else:
        c.rows(3, y + 1, [7, 8, 7], CAT)
        c.rows(9, y - 2, [4, 5, 4], CAT)
        c.set(9, y - 3, CAT)
        c.set(12, y - 3, CAT)
        c.line(3, y + 1, 1, y - 1 - (phase % 2), CAT)
        if pounce:
            c.set(2, y + 4, CAT_SH)
            c.set(12, y + 3, CAT_SH)
        else:
            legs = {0: [4, 6, 9, 11], 1: [3, 7, 8, 12], 2: [5, 5, 10, 10], 3: [4, 7, 9, 11]}[phase % 4]
            for i, lx in enumerate(legs):
                c.vline(lx, y + 4, 9 - ((i + phase) % 2 if phase % 2 else 0), CAT_SH)
    _fin(c)
    if sit:
        c.set(7, y - 2, CAT_EYE)
        c.set(9, y - 2, CAT_EYE)
    else:
        c.set(11, y - 1, CAT_EYE)
        c.set(12, y - 1, CAT_EYE)
    return c


def hellcat():
    run = [cat_frame(i) for i in range(4)]
    idle = [cat_frame(0, sit=True), cat_frame(1, sit=True)]
    return {"idle": idle, "run": run, "jump": [cat_frame(0, pounce=True)], "windup": [cat_frame(2)]}, {"size": [14, 10], "feet": [7, 10], "fps": {"run": 14, "idle": 2}}


# ---------------------------------------------------------------------------
# Espectro encapuzado (fantasminha de capuz) 14x16, voador (origem no centro)
# ---------------------------------------------------------------------------
GHOST = hexc("d7d2ef")
GHOST_SH = hexc("a79fd0")
HOOD = hexc("5b4b8f")
CYAN = hexc("7ff0ff")


def ghost_frame(t=0, cast=False):
    c = Canvas(14, 16)
    c.rows(3, 2, [4, 6, 8, 8, 8, 8, 8, 8, 8, 8], HOOD)
    c.rows(4, 4, [6, 6, 6, 6], GHOST_SH)
    # barra ondulada
    for i in range(8):
        h = 1 + ((i + t) % 3 == 0)
        c.vline(3 + i, 12, 12 + h, HOOD)
    if cast:
        c.set(1, 7, GHOST)
        c.set(12, 7, GHOST)
        c.set(0, 6, GHOST)
        c.set(13, 6, GHOST)
    else:
        c.set(2, 9, GHOST)
        c.set(11, 9, GHOST)
    _fin(c)
    c.set(6, 6, CYAN)
    c.set(8, 6, CYAN)
    if cast:
        c.set(7, 8, CYAN)
    return c


def ghost():
    idle = [ghost_frame(t) for t in range(3)]
    return {"idle": idle, "cast": [ghost_frame(0, True), ghost_frame(1, True)], "appear": [ghost_frame(0)], "vanish": [ghost_frame(1)]}, {"size": [14, 16], "feet": [7, 8], "fps": {"idle": 6, "cast": 8}}


# ---------------------------------------------------------------------------
# Lampadário (criatura com cabeça de lanterna) 12x16, voador
# ---------------------------------------------------------------------------
ROBE = hexc("2e3656")
ROBE_SH = hexc("1f2640")
BRASS = hexc("c79a4a")
GLOW = hexc("ffe29a")


def lamp_frame(t=0):
    c = Canvas(12, 16)
    # lanterna
    c.rect(4, 1, 4, 1, BRASS)
    c.rect(3, 2, 6, 5, BRASS)
    c.rect(4, 3, 4, 3, GLOW)
    # túnica
    c.rows(2, 7, [8, 8, 8, 8, 6, 4], ROBE)
    c.hline(3, 8, 10, ROBE_SH)
    for i in range(4):
        if (i + t) % 2 == 0:
            c.set(4 + i, 13, ROBE)
    _fin(c)
    c.set(5, 4, hexc("ff9a3a") if t % 2 else GLOW)
    c.set(6, 4, GLOW)
    return c


def wraith():
    return {"idle": [lamp_frame(t) for t in range(4)]}, {"size": [12, 16], "feet": [6, 8], "fps": {"idle": 6}}


# ---------------------------------------------------------------------------
# Crânio flamejante 12x12, voador
# ---------------------------------------------------------------------------
FIRE_A = hexc("ff7a2a")
FIRE_B = hexc("ffd34a")


def skull_frame(t=0):
    c = Canvas(12, 12)
    # chamas atrás
    for i in range(6):
        h = [3, 4, 3, 4, 2, 3][(i + t) % 6]
        c.vline(3 + i, 4 - h, 5, FIRE_A)
    c.rows(3, 4, [6, 6, 6, 4], BONE)
    c.rows(4, 8, [4], BONE_SH)
    _fin(c)
    c.set(4, 5, OUT)
    c.set(7, 5, OUT)
    c.set(4, 6, FIRE_B)
    c.set(7, 6, FIRE_B)
    for i in range(6):
        h = [3, 4, 3, 4, 2, 3][(i + t) % 6]
        if h >= 3:
            c.set(3 + i, 4 - h + 2, FIRE_B)
    return c


def fire_skull():
    return {"idle": [skull_frame(t) for t in range(4)]}, {"size": [12, 12], "feet": [6, 6], "fps": {"idle": 10}}


# ---------------------------------------------------------------------------
# Besta do inferno (torre viva que cospe fogo) 16x18
# ---------------------------------------------------------------------------
BEAST = hexc("7c3c30")
BEAST_SH = hexc("562820")
HORN = hexc("dccaa8")


def beast_frame(t=0, breath=False):
    c = Canvas(16, 18)
    c.rows(2, 6, [10, 12, 12, 12, 12, 12, 12, 12, 12, 10], BEAST)
    c.hline(3, 12, 15, BEAST_SH)
    # chifres
    c.line(3, 6, 1, 2 + (t % 2), HORN)
    c.line(12, 6, 14, 2 + (t % 2), HORN)
    # patas
    c.rect(3, 16, 3, 2, BEAST_SH)
    c.rect(10, 16, 3, 2, BEAST_SH)
    _fin(c)
    # boca e olhos
    c.set(9, 8, FIRE_B)
    c.set(12, 8, FIRE_B)
    if breath:
        c.rect(9, 11, 5, 2, FIRE_A)
        c.hline(10, 12, 11, FIRE_B)
    else:
        c.hline(9, 12, 12, OUT)
    return c


def hell_beast():
    return {"idle": [beast_frame(0), beast_frame(1)], "breath": [beast_frame(0, True), beast_frame(1, True)]}, {"size": [16, 18], "feet": [8, 18], "fps": {"idle": 3, "breath": 8}}


# ---------------------------------------------------------------------------
# Corcel do pesadelo (bicho grande, investida) 26x18
# ---------------------------------------------------------------------------
HORSE = hexc("26213a")
HORSE_SH = hexc("171428")
PURPLE = hexc("b46cff")
PURPLE2 = hexc("e0b8ff")


def horse_frame(phase=0, rear=False):
    c = Canvas(26, 18)
    y = 6
    c.rows(4, y, [14, 16, 16, 15, 13], HORSE)
    # pescoço + cabeça
    c.rows(17, y - 4, [3, 4, 4, 4, 3], HORSE)
    c.rows(19, y - 5, [4, 6, 6, 5], HORSE)
    c.set(20, y - 6, HORSE)
    c.hline(5, 17, y + 4, HORSE_SH)
    legs = {0: [5, 8, 15, 18], 1: [4, 9, 14, 19], 2: [6, 7, 16, 17], 3: [5, 9, 15, 18]}[phase % 4]
    for i, lx in enumerate(legs):
        lift = 1 if (i + phase) % 2 and phase % 2 else 0
        c.vline(lx, y + 5, 17 - lift, HORSE_SH)
    _fin(c)
    # crina e cauda de fogo roxo
    for i in range(6):
        c.set(16 - i, y - 1 - ((i + phase) % 2), PURPLE)
    c.set(3, y, PURPLE)
    c.set(2, y + 1 - (phase % 2), PURPLE)
    c.set(1, y + 2, PURPLE2)
    c.set(22, y - 3, PURPLE2)
    return c


def nightmare():
    return {"idle": [horse_frame(0), horse_frame(2)], "gallop": [horse_frame(i) for i in range(4)]}, {"size": [26, 18], "feet": [13, 18], "fps": {"gallop": 12, "idle": 3}}


# ---------------------------------------------------------------------------
# Arquidemônio de cinzas (chefe) 36x36, voador
# ---------------------------------------------------------------------------
DEMON = hexc("4a2638")
DEMON_SH = hexc("321828")
WING = hexc("6b2f3f")
EMBER = hexc("ff6a3a")


def demon_frame(t=0, attack=False):
    c = Canvas(36, 36)
    flap = [0, 2, 4, 2][t % 4]
    # asas
    for s in (-1, 1):
        cx = 18 + s * 6
        for i in range(11):
            x = cx + s * i
            top = 9 + flap - i // 2 + (0 if i < 8 else (i - 7) * 2)
            bottom = 17 - (i // 3) + (2 if i % 3 == 0 else 0)
            c.vline(x, top, bottom, WING)
    # corpo
    c.rows(11, 10, [8, 12, 14, 14, 14, 14, 12, 12, 10, 10, 8, 6, 4], DEMON)
    c.hline(12, 23, 19, DEMON_SH)
    # cabeça (ponto fraco: crânio)
    c.rows(13, 3, [6, 10, 10, 10, 8], BONE)
    c.rows(14, 7, [8], BONE_SH)
    # chifres
    c.line(13, 3, 10, 0, HORN)
    c.line(22, 3, 25, 0, HORN)
    # braços
    if attack:
        c.line(25, 13, 32, 10, DEMON)
        c.line(32, 10, 34, 6, HORN)
    else:
        c.line(25, 13, 28, 20, DEMON)
    c.line(10, 13, 7, 20, DEMON)
    _fin(c)
    c.set(15, 5, EMBER)
    c.set(16, 5, EMBER)
    c.set(19, 5, EMBER)
    c.set(20, 5, EMBER)
    for i in range(3):
        c.set(16 + i * 2, 15 + (t + i) % 2, EMBER)
    return c


def demon():
    return {"idle": [demon_frame(t) for t in range(4)], "attack": [demon_frame(1, True), demon_frame(2, True)]}, {"size": [36, 36], "feet": [18, 18], "fps": {"idle": 8, "attack": 10}}


# ---------------------------------------------------------------------------
# Mariposa de Cinza 16x12, voadora — atraída pela chama do Pavio
# ---------------------------------------------------------------------------
MOTH = hexc("9a8fa8")
MOTH_SH = hexc("6e6480")
MOTH_HI = hexc("c8bfd4")
MOTH_EYE = hexc("ffb04a")
FUZZ = hexc("d8cfc0")


def moth_frame(wing=0, dive=False):
    c = Canvas(16, 12)
    # asas (4 poses: aberta, meia, fechada, meia)
    up = [0, 2, 4, 2][wing]
    if dive:
        up = 4
    for side in (-1, 1):
        cx = 8 + side * 4
        top = 1 + up // 2
        h = 7 - up
        if h > 0:
            c.ellipse(cx + (0.5 if side > 0 else -0.5), top + h / 2.0, 3.6, h / 2.0 + 0.3, MOTH)
            c.set(cx + side, top + h // 2, MOTH_EYE)
            c.set(cx, top + 1, MOTH_HI)
    # corpo peludo
    c.rect(7, 3, 3, 7, MOTH_SH)
    c.rect(7, 3, 2, 2, FUZZ)
    c.vline(8, 5, 9, MOTH_SH)
    # antenas
    c.set(7, 2, MOTH_SH)
    c.set(6, 1, MOTH_SH)
    c.set(9, 2, MOTH_SH)
    c.set(10, 1, MOTH_SH)
    _fin(c)
    c.set(7, 4, OUT)
    c.set(9, 4, OUT)
    return c


def moth():
    fly = [moth_frame(w) for w in range(4)]
    return {"idle": fly, "windup": [moth_frame(0), moth_frame(1)], "attack": [moth_frame(0, True)]}, {"size": [16, 12], "feet": [8, 6], "fps": {"idle": 14, "windup": 20, "attack": 1}}


# ---------------------------------------------------------------------------
# Guarda de Cinzas 18x16 — armadura fria, escudo redondo sempre na frente
# ---------------------------------------------------------------------------
ASH = hexc("7a7688")
ASH_SH = hexc("56526a")
ASH_HI = hexc("a09cae")
VISOR = hexc("7ad8ff")
SHIELD = hexc("8a6a4a")
SHIELD_RIM = hexc("c8a86a")


def knight_frame(legs=0, shield="up", sword="down", lean=0):
    c = Canvas(18, 16)
    x = 5 + lean
    # elmo
    c.rows(x, 1, [4, 6, 6, 6], ASH)
    c.hline(x + 1, x + 4, 2, ASH_HI)
    c.hline(x + 2, x + 5, 3, OUT)
    # peito
    c.rows(x - 1, 5, [8, 8, 8, 7, 6], ASH)
    c.vline(x - 1, 6, 9, ASH_SH)
    c.hline(x, x + 5, 9, ASH_SH)
    # pernas
    pts = {0: [(x + 1, 0), (x + 4, 0)], 1: [(x, 1), (x + 5, 0)], 2: [(x + 2, 0), (x + 3, 0)], 3: [(x + 5, 1), (x, 0)]}[legs]
    for lx, upp in pts:
        c.vline(lx, 10, 15 - upp, ASH_SH)
    # espada (atrás) e escudo (na frente)
    if sword == "down":
        c.line(x - 2, 8, x - 2, 13, ASH_HI)
    elif sword == "up":
        c.line(x - 2, 7, x - 4, 2, ASH_HI)
    elif sword == "thrust":
        c.line(x + 6, 7, x + 12, 7, ASH_HI)
        c.set(x + 13, 7, hexc("e8f4ff"))
    if shield == "up":
        c.ellipse(x + 7.5, 7.5, 3.2, 4.4, SHIELD_RIM)
        c.ellipse(x + 7.5, 7.5, 2.2, 3.4, SHIELD)
        c.set(x + 7, 7, SHIELD_RIM)
    elif shield == "bash":
        c.ellipse(x + 9.5, 7.5, 3.2, 4.4, SHIELD_RIM)
        c.ellipse(x + 9.5, 7.5, 2.2, 3.4, SHIELD)
        c.set(x + 9, 7, SHIELD_RIM)
    elif shield == "down":
        c.ellipse(x + 6.5, 12.5, 3.0, 2.2, SHIELD_RIM)
        c.ellipse(x + 6.5, 12.5, 2.0, 1.3, SHIELD)
    _fin(c)
    c.set(x + 3, 3, VISOR)
    c.set(x + 4, 3, VISOR)
    return c


def ash_knight():
    walk = [knight_frame(l) for l in range(4)]
    idle = [knight_frame(0), knight_frame(0, lean=0)]
    return {"idle": idle, "walk": walk, "windup": [knight_frame(0, "up", "up", -1)], "bash": [knight_frame(1, "bash", "down", 1)],
            "attack": [knight_frame(1, "down", "thrust", 1)], "tired": [knight_frame(0, "down", "down")]}, \
        {"size": [18, 16], "feet": [8, 16], "fps": {"walk": 6, "idle": 2}}


# ---------------------------------------------------------------------------
# Sopro 16x14, voador — espírito do vento frio que apagou a Lareira
# ---------------------------------------------------------------------------
WIND = hexc("bfe6f2")
WIND_SH = hexc("7fb2cc")
WIND_HI = hexc("f0fcff")


def gust_frame(t=0, inhale=0, blow=False):
    c = Canvas(16, 14)
    r = 5.0 + inhale * 0.8
    c.ellipse(8, 7, r, r - 0.8, WIND_SH)
    c.ellipse(7.6, 6.6, r - 1.0, r - 1.8, WIND)
    # redemoinhos
    for i in range(3):
        ang = t * 1.3 + i * 2.1
        px = 8 + math.cos(ang) * (r - 1.5)
        py = 7 + math.sin(ang) * (r - 2.2)
        c.set(int(px), int(py), WIND_HI)
    # rabinho de vento
    c.line(2, 9 + (t % 2), 0, 11, WIND_SH)
    _fin(c)
    # olhos e boca "O"
    c.set(6, 6, OUT)
    c.set(9, 6, OUT)
    if blow:
        c.rect(10, 8, 3, 3, OUT)
        c.set(11, 9, WIND_SH)
    elif inhale:
        c.rect(8, 8, 2, 2, OUT)
    else:
        c.set(8, 9, OUT)
    return c


def gust():
    idle = [gust_frame(t) for t in range(4)]
    return {"idle": idle, "windup": [gust_frame(0, 1), gust_frame(1, 2), gust_frame(2, 3)], "attack": [gust_frame(0, 1, True)]}, \
        {"size": [16, 14], "feet": [8, 7], "fps": {"idle": 6, "windup": 5}}


ALL = {
    "skeleton": skeleton, "hound": hound, "hellcat": hellcat, "ghost": ghost, "wraith": wraith,
    "fire_skull": fire_skull, "hell_beast": hell_beast, "nightmare": nightmare, "demon": demon,
    "moth": moth, "ash_knight": ash_knight, "gust": gust,
}

# guardiões das Brasas-Mestras (chefes) ficam em guardian_art.py
from guardian_art import GUARDIANS  # noqa: E402
ALL.update(GUARDIANS)
