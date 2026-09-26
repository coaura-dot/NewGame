"""Objetos do cenário (baú, porta, fogueira de descanso, trampolim, mural,
altar, pedestal, tocha) e ícones pequenos de itens no mundo."""
from px import Canvas, hexc

OUT = hexc("1b1528")
WOOD = hexc("8a5a36")
WOOD_SH = hexc("5e3a24")
GOLD = hexc("f0c850")
IRON = hexc("8a8fa0")
STONE = hexc("7a7488")
STONE_SH = hexc("56506a")


def chest(opened=False, t=0):
    c = Canvas(12, 10)
    c.rect(1, 4, 10, 6, WOOD)
    c.hline(1, 10, 9, WOOD_SH)
    c.vline(1, 4, 9, GOLD)
    c.vline(10, 4, 9, GOLD)
    if opened:
        c.rect(1, 1 - t, 10, 2, WOOD_SH)
        c.hline(2, 9, 4, hexc("ffe07a"))
    else:
        c.rows(1, 1, [8, 10, 10], WOOD)
        c.hline(1, 10, 3, GOLD)
        c.rect(5, 3, 2, 2, GOLD)
    c.outline(OUT)
    return c


def door():
    c = Canvas(14, 20)
    c.rows(1, 0, [8, 10, 12] + [12] * 17, STONE)
    c.rows(3, 3, [4, 6, 8] + [8] * 14, hexc("2a2238"))
    c.vline(7, 5, 19, hexc("3a3048"))
    c.set(9, 12, GOLD)
    c.outline(OUT)
    return c


def bench(lit=False):
    """Ponto de descanso: um banquinho com lanterna."""
    c = Canvas(16, 16)
    c.rect(2, 11, 12, 2, WOOD)
    c.vline(3, 13, 15, WOOD_SH)
    c.vline(12, 13, 15, WOOD_SH)
    c.vline(14, 3, 15, hexc("4a4458"))
    c.rect(13, 2, 3, 3, IRON)
    c.outline(OUT)
    c.set(14, 3, hexc("ffe07a") if lit else hexc("4a4458"))
    return c


def spring(k=0):
    c = Canvas(12, 8)
    top = [4, 1, 2, 3][k]
    c.rect(1, 6, 10, 2, IRON)
    for y in range(top + 2, 6):
        c.set(3 + (y % 2) * 5, y, hexc("c0c4d0"))
        c.set(8 - (y % 2) * 5, y, hexc("c0c4d0"))
    c.rect(1, top, 10, 2, hexc("e05a4a"))
    c.hline(2, 9, top, hexc("ff8a7a"))
    c.outline(OUT)
    return c


def board():
    c = Canvas(14, 14)
    c.rect(1, 1, 12, 8, WOOD)
    c.rect(2, 2, 10, 6, hexc("b08a5a"))
    c.rect(3, 3, 3, 4, hexc("f0e8d0"))
    c.rect(7, 3, 4, 3, hexc("f0e8d0"))
    c.vline(3, 9, 13, WOOD_SH)
    c.vline(10, 9, 13, WOOD_SH)
    c.outline(OUT)
    return c


def altar():
    c = Canvas(14, 10)
    c.rect(2, 3, 10, 7, STONE)
    c.rect(1, 2, 12, 2, hexc("9a94a8"))
    c.hline(2, 11, 9, STONE_SH)
    c.rect(6, 5, 2, 2, hexc("ff6a3a"))
    c.outline(OUT)
    return c


def pedestal():
    c = Canvas(10, 8)
    c.rect(2, 2, 6, 6, STONE)
    c.rect(1, 1, 8, 2, hexc("9a94a8"))
    c.hline(2, 7, 7, STONE_SH)
    c.outline(OUT)
    return c


def torch():
    c = Canvas(6, 8)
    c.rect(2, 3, 2, 5, WOOD)
    c.rect(1, 2, 4, 2, IRON)
    c.outline(OUT)
    return c


def item_icon(kind, color):
    """Ícone 9x9 de item no mundo: forma pela categoria, cor pela raridade."""
    c = Canvas(9, 9)
    col = hexc(color)
    if kind == "weapon":
        c.line(2, 6, 6, 2, hexc("e8eaf0"))
        c.line(1, 5, 3, 7, col)
        c.set(1, 7, WOOD)
    elif kind == "spell" or kind == "sigil":
        c.rows(2, 2, [3, 5, 5, 5, 3], col)
        c.set(4, 4, hexc("ffffff"))
    elif kind == "armor":
        c.rows(2, 1, [5, 5, 5, 3, 1], col, offsets=[0, 0, 0, 0, 0])
        c.hline(2, 6, 1, hexc("ffffff"))
    elif kind == "buff":
        c.rows(3, 1, [1, 3, 5, 3, 1], col, offsets=[1, 0, -1, 0, 1]) if False else c.rows(2, 2, [1, 3, 5, 3, 1], col)
        c.set(4, 3, hexc("ffffff"))
    elif kind == "key":
        c.rect(1, 3, 3, 3, GOLD)
        c.hline(4, 7, 4, GOLD)
        c.set(6, 5, GOLD)
        c.set(7, 5, GOLD)
    elif kind == "potion":
        c.rows(2, 3, [3, 5, 5, 3], hexc("e04a6a"))
        c.rect(3, 1, 3, 2, hexc("c0c4d0"))
    else:
        c.rows(2, 2, [3, 5, 5, 5, 3], col)
    c.outline(OUT)
    return c
