"""Herói: criaturinha de máscara clara, orelhas pontudas, manto escuro.

Quadros 16x16, olhando para a direita, pés na linha 15, corpo centrado
entre as colunas 7 e 8 (espelha certinho). Os OLHOS não fazem parte do
quadro: o jogo desenha as expressões por cima usando a âncora "eye" de
cada quadro (x do olho de trás, y do topo dos olhos). O cachecol também é
procedural, preso na âncora "neck". "hand" é onde a arma aparece.
"""
from px import Canvas, hexc

OUT = hexc("1b1528")
MASK = hexc("f4efe6")
MASK_SH = hexc("c9bfb8")
CLOAK = hexc("3d4379")
CLOAK_SH = hexc("2a2d56")
CLOAK_HI = hexc("5a62a8")
LEG = OUT

W = 16
H = 16


def head(c, x, y, ears="up", squash=0):
    """Cabeça 8x5 (x = coluna esquerda). squash=1 achata 1px."""
    widths = [6, 8, 8, 8, 6] if squash == 0 else [6, 8, 8, 6]
    c.rows(x, y, widths, MASK)
    hy = y + len(widths) - 1
    # sombra embaixo da máscara
    c.hline(x + 1, x + 6, hy, MASK_SH)
    c.set(x, hy - 1, MASK_SH)
    # orelhas pontudas
    if ears == "up":
        for ex, dx in ((x + 1, -1), (x + 6, 1)):
            c.set(ex, y - 1, MASK)
            c.set(ex + dx, y - 2, MASK)
    elif ears == "back":  # vento / dash: orelhas deitadas para trás
        c.set(x + 1, y - 1, MASK)
        c.set(x, y - 1, MASK)
        c.set(x + 5, y - 1, MASK)
        c.set(x + 4, y - 2, MASK)
    elif ears == "droop":
        c.set(x, y + 1, MASK)
        c.set(x - 1, y + 2, MASK)
        c.set(x + 7, y + 1, MASK)
        c.set(x + 8, y + 2, MASK)


def cloak(c, x, y, widths, offsets=None):
    c.rows(x, y, widths, CLOAK, offsets=offsets)


def legs(c, pts):
    for p in pts:
        c.set(p[0], p[1], LEG)


def finish(c):
    c.shade_bottom(CLOAK, CLOAK_SH, 1)
    c.outline(OUT)
    return c


def frame(hx, hy, cloak_rows, cloak_x, leg_pts, ears="up", squash=0, cloak_off=None, cloak_y=None):
    """Cabeça em (hx, hy); manto começa na última linha da cabeça (ou cloak_y);
    pernas (1px, sem contorno) desenhadas depois do contorno."""
    c = Canvas(W, H)
    hrows = 4 if squash else 5
    cy = cloak_y if cloak_y is not None else hy + hrows - 1
    cloak(c, cloak_x, cy, cloak_rows, cloak_off)
    head(c, hx, hy, ears, squash)
    finish(c)
    legs(c, leg_pts)
    return c


def build():
    """Retorna (lista de (nome, Canvas, meta)), meta com âncoras."""
    F = []

    def add(name, c, eye, neck, hand=(11, 12)):
        F.append((name, c, {"eye": list(eye), "neck": list(neck), "hand": list(hand)}))

    # Layout base: orelhas 3-4, cabeça 5-9, manto até a linha 12, contorno
    # na 13 e pernas nas linhas 13-15 (total ~13 px de altura).
    def body(hy, hx=4, bottom=12, widths=(8, 8, 7, 6, 6, 6), x=4, off=None, ears="up", squash=0, legs=(), top=None):
        hrows = 4 if squash else 5
        cy = top if top is not None else hy + hrows - 1
        n = bottom - cy + 1
        rows = list(reversed(list(widths[:n])))
        o = list(reversed(list(off[:n]))) if off else None
        return frame(hx, hy, rows, x, list(legs), ears=ears, squash=squash, cloak_off=o, cloak_y=cy)

    STAND = [(6, 14), (6, 15), (9, 14), (9, 15)]
    # --- idle (respira) ---
    add("idle0", body(5, legs=STAND), (7, 7), (5, 10))
    add("idle1", body(6, widths=(8, 8, 8, 6), legs=STAND), (7, 8), (5, 11))
    # --- corrida (6 quadros): corpo inclinado, manto arrastando atrás ---
    run_legs = [
        [(6, 13), (5, 14), (4, 15), (9, 13), (10, 14), (11, 15)],
        [(6, 13), (6, 14), (9, 13), (9, 14), (9, 15)],
        [(7, 13), (7, 14), (7, 15), (8, 13), (9, 14)],
        [(6, 13), (5, 14), (4, 15), (9, 13), (10, 14), (11, 15)],
        [(9, 13), (9, 14), (6, 13), (6, 14), (6, 15)],
        [(8, 13), (8, 14), (8, 15), (7, 13), (6, 14)],
    ]
    bob = [0, -1, -1, 0, -1, -1]
    for i in range(6):
        hy = 5 + bob[i]
        add("run%d" % i, body(hy, hx=5, widths=(9, 8, 7, 6, 6, 6), off=(-2, -2, -1, 0, 0, 0) if i % 3 else (-2, -1, -1, 0, 0, 0), legs=run_legs[i]), (8, hy + 2), (5, hy + 5))
    # --- pulo / queda ---
    add("jump", body(4, widths=(4, 6, 6, 6, 6, 6), x=5, off=(0, -1, -1, -1, -1, -1), legs=[(7, 13), (7, 14), (8, 13), (8, 14)]), (8, 6), (5, 9))
    add("fall0", body(5, widths=(10, 10, 8, 6, 6), x=3, legs=[(6, 13), (6, 14), (6, 15), (9, 13), (9, 14)]), (8, 7), (5, 10))
    add("fall1", body(5, widths=(10, 10, 8, 6, 6), x=3, legs=[(6, 13), (6, 14), (9, 13), (9, 14), (9, 15)]), (8, 7), (5, 10))
    # --- dash: esticado na horizontal ---
    add("dash", frame(7, 8, [8, 9, 9], 0, [(2, 13), (1, 13), (3, 13)], ears="back", squash=1, cloak_off=[1, 0, 0], cloak_y=10), (11, 9), (7, 11))
    # --- parede (agarrado; a parede fica atrás, à esquerda do quadro) ---
    add("wall", body(5, hx=5, widths=(7, 7, 6, 6, 6), x=5, legs=[(11, 12), (12, 12), (7, 13), (7, 14), (7, 15)]), (8, 7), (6, 10))
    add("climb0", body(4, hx=5, bottom=11, widths=(6, 6, 6, 6, 6), x=5, legs=[(11, 11), (12, 11), (7, 12), (7, 13), (7, 14)]), (8, 6), (6, 9))
    add("climb1", body(5, hx=5, widths=(6, 6, 6, 6, 6), x=5, legs=[(11, 13), (12, 14), (7, 13)]), (8, 7), (6, 10))
    # --- agachado ---
    add("duck", body(8, widths=(10, 8, 8), x=3, squash=1, bottom=13, legs=[(6, 15), (9, 15)]), (7, 10), (5, 12))
    # --- ataques (a lâmina é desenhada pelo jogo na mão) ---
    add("slash0", body(5, hx=3, widths=(8, 8, 7, 6, 6), x=3, off=(1, 1, 1, 1, 1), legs=[(5, 13), (4, 14), (4, 15), (10, 13), (11, 14), (11, 15)]), (6, 7), (5, 10), (12, 10))
    add("slash1", body(6, hx=6, widths=(8, 8, 7, 6), x=5, off=(-1, -1, 0, 0), legs=[(6, 13), (5, 14), (5, 15), (11, 13), (12, 14), (12, 15)]), (9, 8), (7, 11), (13, 11))
    add("slash_up", body(6, widths=(8, 8, 7, 6), legs=STAND), (7, 7), (5, 11), (9, 4))
    add("slash_down", body(3, bottom=10, widths=(6, 6, 6, 6, 6), x=5, off=(-1, -1, -1, -1, -1), legs=[(7, 11), (7, 12), (8, 11), (8, 12)]), (7, 6), (5, 8), (8, 14))
    # --- conjurar / focar ---
    add("cast", body(5, widths=(9, 9, 8, 6, 6), legs=[(6, 13), (5, 14), (5, 15), (9, 13), (10, 14), (10, 15)]), (7, 7), (5, 10), (12, 10))
    add("focus", body(7, widths=(10, 10, 8), x=3, squash=1, bottom=12, ears="droop", legs=[(6, 13), (6, 14), (9, 13), (9, 14)]), (7, 9), (5, 12))
    # --- dano / morte / sentado ---
    add("hurt", body(5, hx=3, widths=(8, 8, 7, 6, 6), x=5, off=(1, 1, 1, 1, 1), ears="back", legs=[(6, 13), (5, 14), (5, 15), (11, 13), (12, 14), (12, 15)]), (6, 7), (6, 10))
    add("dead", frame(6, 11, [9, 10], 1, [], ears="droop", squash=1, cloak_y=13), (9, 12), (5, 14))
    add("sit", body(7, widths=(10, 10, 9, 7), x=3, bottom=13, legs=[(10, 15), (11, 15)]), (7, 9), (5, 12))
    return F


if __name__ == "__main__":
    import sys
    sys.path.insert(0, ".")
