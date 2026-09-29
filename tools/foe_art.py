"""Inimigos comuns que usam o motor de duelo (GuardianBrain): mesmo estilo
(contorno escuro, 2-3 cores). Todos olham para a DIREITA.
  lanceiro  (wax_spear)   — cera escura com lança comprida
  arqueira  (soot_archer) — capuz de fuligem com arco
  bruto     (coal_brute)  — carvão com rachaduras em brasa
"""
from px import Canvas, hexc

OUT = hexc("1b1528")


def _fin(c):
    c.outline(OUT)
    return c


# ---------------------------------------------------------------------------
# Lanceiro de Cera 24x16
# ---------------------------------------------------------------------------
DWAX = hexc("c9b48f")
DWAX_SH = hexc("8f7a5a")
SPEAR = hexc("d8dde8")
SHAFT = hexc("7a5a3a")
EYE_R = hexc("ff6a4a")


def spear_frame(t=0, pose="idle"):
    c = Canvas(24, 16)
    x = 6 + (1 if pose == "attack" else 0) - (1 if pose == "windup" else 0)
    bob = t % 2 if pose in ("idle", "walk") else 0
    # corpo de vela escura com capuz pontudo
    c.rows(x, 3 + bob, [2, 4, 6, 6, 6, 6, 6, 6, 5], DWAX)
    c.vline(x, 6 + bob, 10 + bob, DWAX_SH)
    # pernas
    step = t % 2 if pose == "walk" else 0
    c.vline(x + 1 + step, 12, 15, DWAX_SH)
    c.vline(x + 4 - step, 12, 15, DWAX_SH)
    _fin(c)
    # lança
    y = 8 + bob
    if pose == "windup":
        c.line(x - 5, y + 1, x + 9, y - 1, SHAFT)
        c.set(x + 10, y - 1, SPEAR)
        c.set(x + 11, y - 2, SPEAR)
    elif pose == "attack":
        c.line(x + 2, y, x + 17, y, SHAFT)
        c.hline(x + 18, x + 21, y, SPEAR)
        c.set(x + 20, y - 1, SPEAR)
        c.set(x + 20, y + 1, SPEAR)
    elif pose == "sweep":
        c.line(x - 2, y + 4, x + 14, y + 6, SHAFT)
        c.hline(x + 15, x + 17, y + 6, SPEAR)
    else:
        c.line(x + 6, y - 6, x + 6, y + 6, SHAFT)
        c.vline(x + 6, y - 9, y - 7, SPEAR)
    c.set(x + 4, 5 + bob, EYE_R)
    return c


def wax_spear():
    return {"idle": [spear_frame(0), spear_frame(1)], "walk": [spear_frame(i, "walk") for i in range(2)],
            "windup": [spear_frame(0, "windup")], "attack": [spear_frame(0, "attack")], "cast": [spear_frame(0, "sweep")],
            "tired": [spear_frame(0)]}, {"size": [24, 16], "feet": [9, 16], "fps": {"walk": 6, "idle": 2}}


# ---------------------------------------------------------------------------
# Arqueira de Fuligem 18x16
# ---------------------------------------------------------------------------
SOOT = hexc("4d4a5c")
SOOT_SH = hexc("343242")
SOOT_HI = hexc("7a7690")
BOW = hexc("a07a4a")
STRING = hexc("e8e2d4")
EMBER = hexc("ffb347")


def archer_frame(t=0, pose="idle"):
    c = Canvas(18, 16)
    x = 5
    bob = t % 2 if pose in ("idle", "walk") else 0
    # capuz e manto
    c.rows(x, 2 + bob, [3, 5, 6, 6, 6, 7, 7, 7, 6], SOOT)
    c.rows(x + 1, 3 + bob, [1, 3], SOOT_SH)
    c.hline(x, x + 6, 10 + bob, SOOT_HI)
    step = t % 2 if pose == "walk" else 0
    c.vline(x + 2 + step, 11, 15, SOOT_SH)
    c.vline(x + 4 - step, 11, 15, SOOT_SH)
    _fin(c)
    # arco
    bx = x + 8
    by = 6 + bob
    draw = pose in ("windup", "cast")
    c.line(bx, by - 4, bx + 2, by, BOW)
    c.line(bx + 2, by, bx, by + 4, BOW)
    c.line(bx - (3 if draw else 0), by, bx, by - 4, STRING)
    c.line(bx - (3 if draw else 0), by, bx, by + 4, STRING)
    if draw:
        c.hline(bx - 3, bx + 4, by, STRING)
        c.set(bx + 5, by, EMBER)
    c.set(x + 4, 4 + bob, EMBER)
    return c


def soot_archer():
    return {"idle": [archer_frame(0), archer_frame(1)], "walk": [archer_frame(i, "walk") for i in range(2)],
            "windup": [archer_frame(0, "windup")], "attack": [archer_frame(0, "idle")], "cast": [archer_frame(0, "cast")],
            "tired": [archer_frame(0)]}, {"size": [18, 16], "feet": [8, 16], "fps": {"walk": 7, "idle": 2}}


# ---------------------------------------------------------------------------
# Bruto de Carvão 22x20
# ---------------------------------------------------------------------------
COAL = hexc("46404e")
COAL_SH = hexc("2e2a36")
COAL_HI = hexc("6c6478")
CRACK = hexc("ff7a2a")


def brute_frame(t=0, pose="idle"):
    c = Canvas(22, 20)
    bob = t % 2 if pose in ("idle", "walk") else 0
    by = 4 + bob + (2 if pose == "windup" else 0)
    # tronco largo e cabeça enterrada nos ombros
    c.rows(4, by, [8, 12, 14, 14, 14, 13, 12, 10], COAL)
    c.rows(8, by - 3, [5, 7, 7], COAL)
    c.hline(6, 15, by + 1, COAL_HI)
    step = t % 2 if pose == "walk" else 0
    c.rect(6 + step, by + 8, 3, 19 - (by + 8), COAL_SH)
    c.rect(12 - step, by + 8, 3, 19 - (by + 8), COAL_SH)
    _fin(c)
    # braço-clava
    arm = Canvas(22, 20)
    if pose == "windup":
        arm.rows(14, by - 6, [4, 5, 5, 4], COAL)
    elif pose == "attack":
        arm.rows(15, by + 7, [5, 6, 6, 5], COAL)
    else:
        arm.rows(16, by + 2, [3, 4, 4, 5, 5], COAL)
    arm.outline(OUT)
    c.im.alpha_composite(arm.im)
    c.px = c.im.load()
    # rachaduras em brasa
    for (dx, dy) in [(6, 3), (7, 4), (10, 5), (11, 6), (8, 7)]:
        c.set(dx, by + dy, CRACK)
    c.set(11, by - 1, CRACK)
    c.set(13, by - 1, CRACK)
    return c


def coal_brute():
    return {"idle": [brute_frame(0), brute_frame(1)], "walk": [brute_frame(i, "walk") for i in range(2)],
            "windup": [brute_frame(0, "windup")], "attack": [brute_frame(0, "attack")], "cast": [brute_frame(0, "windup")],
            "tired": [brute_frame(0)]}, {"size": [22, 20], "feet": [10, 20], "fps": {"walk": 5, "idle": 2}}


FOES = {"wax_spear": wax_spear, "soot_archer": soot_archer, "coal_brute": coal_brute}
