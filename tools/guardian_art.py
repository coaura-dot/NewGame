"""Guardiões das Brasas-Mestras (chefes): criaturas grandes no mesmo estilo
(contorno escuro, 2-3 cores, olhos claros). Cada uma guarda um dom:
  corvo  -> Asas de Cinza (pulo duplo)
  aranha -> Garras (escalar)
  lebre  -> Coração do Vendaval (2º dash)
  golem  -> Queda Esmagadora
  espelho-> Passo Etéreo
Todos olham para a DIREITA. Devolvem ({anim: [Canvas]}, meta).
"""
import math
from px import Canvas, hexc

OUT = hexc("1b1528")


def _fin(c):
    c.outline(OUT)
    return c


# ---------------------------------------------------------------------------
# Corvo das Cinzas 26x20 (voa)
# ---------------------------------------------------------------------------
RAV = hexc("5a5078")
RAV_SH = hexc("3e3758")
RAV_HI = hexc("9a92b8")
EMBER = hexc("ffb347")
BEAK = hexc("e8c170")


def raven_frame(wing=0, pose="fly"):
    c = Canvas(26, 20)
    cx, cy = 12, 10
    # corpo e cabeça
    if pose == "dive":
        c.ellipse(cx, cy, 6.5, 3.2, RAV)
        c.ellipse(cx + 6, cy - 1, 3.0, 2.6, RAV)
        c.rows(cx + 9, cy - 1, [3, 2, 1], BEAK)
        c.line(cx - 4, cy - 1, cx - 11, cy - 4, RAV_SH)
        c.line(cx - 4, cy + 1, cx - 11, cy + 3, RAV_SH)
        c.line(cx - 3, cy, cx - 10, cy, RAV_HI)
    else:
        c.ellipse(cx, cy + 1, 5.0, 4.2, RAV)
        c.ellipse(cx + 5, cy - 3, 3.2, 3.0, RAV)
        c.rows(cx + 8, cy - 3, [3, 2, 1], BEAK)
        # cauda
        c.rows(cx - 8, cy + 2, [4, 5, 4], RAV_SH)
        # asa (sobe/desce)
        up = [(-7, -8), (-4, -7), (1, -5)] if wing == 0 else ([(-8, -2), (-4, -2), (1, -1)] if wing == 1 else ([(-7, 5), (-3, 5), (1, 3)] if wing == 2 else [(-8, -2), (-4, -2), (1, -1)]))
        if pose == "spread":
            up = [(-11, -6), (-6, -8), (0, -6)]
        for (dx, dy) in up:
            c.line(cx, cy, cx + dx, cy + dy, RAV_HI)
        pts = [(cx, cy)] + [(cx + dx, cy + dy) for dx, dy in up]
        for i in range(len(pts) - 1):
            c.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], RAV)
        # penas da asa
        for (dx, dy) in up[:2]:
            c.set(cx + dx, cy + dy + 1, RAV_SH)
        # peito cinzento
        c.rows(cx + 1, cy + 2, [3, 3, 2], RAV_HI)
    _fin(c)
    # olho de brasa
    ex, ey = (cx + 7, cy - 2) if pose == "dive" else (cx + 6, cy - 4)
    c.set(ex, ey, EMBER)
    if pose == "spread":
        c.set(ex + 1, ey, EMBER)
    return c


def raven():
    fly = [raven_frame(w) for w in range(4)]
    return {"idle": fly, "windup": [raven_frame(0, "spread"), raven_frame(1, "spread")], "attack": [raven_frame(0, "dive")],
            "cast": [raven_frame(0, "spread")]}, {"size": [26, 20], "feet": [13, 10], "fps": {"idle": 10, "windup": 12}}


# ---------------------------------------------------------------------------
# Tecelã das Frestas 26x16 (aranha)
# ---------------------------------------------------------------------------
SPI = hexc("6d4488")
SPI_SH = hexc("4a2d5e")
SPI_HI = hexc("dcb8ec")
SPI_EYE = hexc("ffe98a")


def spider_frame(step=0, pose="walk"):
    c = Canvas(28, 18)
    rear = pose in ("windup", "attack")
    ax, ay = 9, 8 - (1 if rear else 0)
    hx, hy = (18, 8 - (3 if rear else 0)) if pose != "attack" else (20, 8)
    feet_y = 17
    # pernas finas saindo da junta entre abdômen e cabeça: duas para trás e
    # duas para a frente, joelhos altos para fora do corpo
    jx, jy = 15, ay + 2
    knees = [(4, ay - 7), (9, ay - 8), (21, ay - 7), (25, ay - 5)]
    feet = [(1, feet_y), (8, feet_y), (21, feet_y), (27, feet_y)]
    for i in range(4):
        phase = (step + i) % 2
        kx, ky = knees[i]
        fx, fy = feet[i]
        kx += (1 if phase else -1)
        fx += (1 if phase else 0)
        fy -= (1 if phase else 0)
        c.line(jx, jy, kx, ky, SPI_SH)
        c.line(kx, ky, fx, fy, SPI_SH)
    # abdômen com desenho
    c.ellipse(ax, ay, 6.5, 5.0, SPI)
    c.ellipse(ax - 1, ay - 1, 3.5, 2.5, SPI_SH)
    c.set(ax - 1, ay - 1, SPI_HI)
    c.set(ax - 3, ay, SPI_HI)
    c.set(ax + 1, ay + 1, SPI_HI)
    # cabeça
    c.ellipse(hx, hy, 3.6, 3.0, SPI)
    c.set(hx + 3, hy + 2, SPI_HI)
    _fin(c)
    # patas da frente (levantadas no preparo)
    if rear:
        c.line(hx + 2, hy, hx + 6, hy - 5, SPI_HI)
        c.line(hx + 1, hy + 1, hx + 5, hy - 3, SPI_HI)
    else:
        c.line(hx + 2, hy + 1, hx + 5, feet_y, SPI_HI)
    # olhos (vários)
    for (dx, dy) in [(1, -1), (2, -1), (2, 0), (1, 0)]:
        c.set(hx + dx, hy + dy, SPI_EYE)
    return c


def spider():
    walk = [spider_frame(s) for s in range(4)]
    return {"idle": [spider_frame(0), spider_frame(1)], "walk": walk, "windup": [spider_frame(0, "windup")],
            "attack": [spider_frame(0, "attack")], "cast": [spider_frame(1, "windup")]}, \
        {"size": [28, 18], "feet": [13, 18], "fps": {"walk": 10, "idle": 3}}


# ---------------------------------------------------------------------------
# Lebre do Vendaval 20x18
# ---------------------------------------------------------------------------
FUR = hexc("e6eef7")
FUR_SH = hexc("9fb1c8")
SCARF = hexc("3fb9b0")
HARE_EYE = hexc("ff5a6e")


def hare_frame(t=0, pose="idle"):
    c = Canvas(20, 18)
    crouch = 2 if pose == "windup" else 0
    stretch = pose in ("run", "attack")
    bx, by = 9, 12 + crouch
    if stretch:
        c.ellipse(bx, by, 6.0, 3.2, FUR)
        c.ellipse(bx + 5, by - 3, 3.0, 2.6, FUR)
        hx, hy = bx + 5, by - 3
    else:
        c.ellipse(bx, by, 4.6, 4.0, FUR)
        c.ellipse(bx + 3, by - 5, 3.0, 2.8, FUR)
        hx, hy = bx + 3, by - 5
    c.ellipse(bx - 1, by + 1, 2.5, 1.8, FUR_SH)
    # orelhas compridas (balançam)
    tilt = -2 if stretch else (1 if t % 2 else 0)
    c.line(hx - 1, hy - 2, hx - 3 + tilt, hy - 8 + (1 if pose == "windup" else 0), FUR)
    c.line(hx, hy - 2, hx + tilt, hy - 8, FUR)
    c.set(hx - 2 + tilt, hy - 6, FUR_SH)
    # cachecol de vento
    c.line(hx - 2, hy + 2, hx - 6 - (2 if stretch else 0), hy + 3 + (t % 2), SCARF)
    c.line(hx - 1, hy + 2, hx + 1, hy + 2, SCARF)
    # patas
    if pose == "attack":
        c.line(bx + 4, by + 2, bx + 9, by + 1, FUR)  # coice
        c.set(bx - 4, by + 3, FUR_SH)
    elif stretch:
        c.set(bx - 5 + (t % 2), by + 3, FUR_SH)
        c.set(bx + 4 - (t % 2), by + 3, FUR_SH)
    else:
        c.hline(bx - 3, bx - 1, 17, FUR_SH)
        c.hline(bx + 2, bx + 3, 17, FUR_SH)
    _fin(c)
    c.set(hx + 1, hy - 1, HARE_EYE)
    if pose == "tired":
        c.set(hx + 1, hy - 1, OUT)
        c.set(hx + 2, hy, OUT)
    c.set(hx + 3, hy + 1, hexc("f7a1b5"))  # focinho
    return c


def hare():
    return {"idle": [hare_frame(0), hare_frame(1)], "run": [hare_frame(i, "run") for i in range(4)],
            "windup": [hare_frame(0, "windup")], "attack": [hare_frame(0, "attack")], "tired": [hare_frame(0, "tired")]}, \
        {"size": [20, 18], "feet": [10, 18], "fps": {"run": 16, "idle": 3}}


# ---------------------------------------------------------------------------
# Golem de Pedra-Pomes 30x28
# ---------------------------------------------------------------------------
STONE = hexc("b5a898")
STONE_SH = hexc("7d7266")
STONE_HI = hexc("d8cdbf")
CORE = hexc("ff8a3a")


def golem_frame(t=0, pose="idle"):
    c = Canvas(30, 28)
    bob = (t % 2) if pose in ("idle", "walk") else 0
    by = 9 + bob + (2 if pose == "windup" else 0)
    # corpo (bloco arredondado)
    c.rows(8, by, [10, 14, 16, 16, 16, 16, 15, 14], STONE)
    # cabeça
    c.rows(13, by - 6, [6, 8, 10, 10, 10], STONE)
    c.hline(14, 20, by - 5, STONE_HI)
    # furos da pedra-pomes
    for (dx, dy) in [(2, 3), (6, 5), (11, 2), (4, 6), (13, 5), (9, 7)]:
        c.set(8 + dx, by + dy, STONE_SH)
    c.hline(10, 21, by + 1, STONE_HI)
    # rachadura com brasa nas COSTAS (ponto fraco)
    c.vline(9, by + 2, by + 6, CORE)
    c.set(10, by + 4, CORE)
    # pernas curtas com pés
    step = t % 2 if pose == "walk" else 0
    c.rect(11 + step, by + 8, 4, 27 - (by + 8) - 1, STONE_SH)
    c.rect(18 - step, by + 8, 4, 27 - (by + 8) - 1, STONE_SH)
    c.rect(10 + step, 26, 6, 1, STONE_SH)
    c.rect(17 - step, 26, 6, 1, STONE_SH)
    _fin(c)
    # braços separados do corpo (desenhados depois, com contorno próprio)
    arm = Canvas(30, 28)
    if pose == "windup":
        arm.rows(21, by - 9, [5, 6, 6, 5], STONE)
        arm.rows(3, by - 7, [4, 5, 5, 4], STONE_SH)
    elif pose == "attack":
        arm.rows(22, by + 7, [7, 8, 8, 7], STONE)
        arm.rows(1, by + 8, [5, 6, 5], STONE_SH)
    else:
        arm.rows(23, by + 2 + bob, [4, 5, 5, 5, 5, 4], STONE)
        arm.rows(3, by + 3, [4, 5, 5, 4], STONE_SH)
    arm.outline(OUT)
    c.im.alpha_composite(arm.im)
    c.px = c.im.load()
    # olhos de brasa
    eye = CORE if pose != "tired" else STONE_SH
    c.set(18, by - 3, eye)
    c.set(20, by - 3, eye)
    return c


def golem():
    return {"idle": [golem_frame(0), golem_frame(1)], "walk": [golem_frame(i, "walk") for i in range(2)],
            "windup": [golem_frame(0, "windup")], "attack": [golem_frame(0, "attack")], "tired": [golem_frame(0, "tired")]}, \
        {"size": [30, 28], "feet": [15, 28], "fps": {"walk": 4, "idle": 2}}


# ---------------------------------------------------------------------------
# Espelho Etéreo 20x22 (voa)
# ---------------------------------------------------------------------------
FRAME = hexc("cfd6e6")
FRAME_SH = hexc("8a93ab")
GLASS = hexc("8fb8e8")
GLASS_HI = hexc("e2f0ff")
MIR_EYE = hexc("ff7ae0")


def mirror_frame(t=0, pose="idle"):
    c = Canvas(20, 22)
    cx, cy = 10, 10 + round(math.sin(t * 1.6))
    thin = pose == "vanish"
    rx = 2.0 if thin else 5.5
    c.ellipse(cx, cy, rx + 1.0, 7.5, FRAME)
    c.ellipse(cx, cy, rx, 6.5, GLASS)
    if not thin:
        # reflexo diagonal
        c.line(cx - 3, cy - 2, cx - 1, cy - 5, GLASS_HI)
        c.line(cx - 2, cy + 1, cx + 1, cy - 3, GLASS_HI)
        # enfeites da moldura
        c.set(cx, cy - 8, FRAME_SH)
        c.set(cx, cy + 8, FRAME_SH)
    # fitas etéreas embaixo
    for i in range(2):
        fx = cx - 2 + i * 4
        c.line(fx, cy + 8, fx + round(math.sin(t + i) * 2), cy + 11, FRAME_SH)
    if pose == "attack":
        c.line(cx + 6, cy - 3, cx + 9, cy + 3, GLASS_HI)
    _fin(c)
    if not thin:
        c.set(cx + 1, cy - 1, MIR_EYE)
        c.set(cx + 2, cy - 1, MIR_EYE if pose in ("windup", "attack", "cast") else OUT)
    return c


def mirror():
    return {"idle": [mirror_frame(t) for t in range(4)], "windup": [mirror_frame(0, "windup")], "attack": [mirror_frame(0, "attack")],
            "cast": [mirror_frame(1, "cast")], "vanish": [mirror_frame(0, "vanish")]}, \
        {"size": [20, 22], "feet": [10, 11], "fps": {"idle": 6}}


GUARDIANS = {"raven": raven, "spider": spider, "hare": hare, "golem": golem, "mirror": mirror}
