"""NPCs: criaturinhas por cultura (espécie) + acessório por papel.

Quadros 16x16 olhando para a direita, pés na linha 15. Anims: idle (2), blink (1).
"""
from px import Canvas, hexc

OUT = hexc("1b1528")
EYE = hexc("1b1528")

SPECIES = {
    # cabeça (cor, sombra), corpo, orelhas
    "humano": dict(head="e8d8c0", body="7a6a9a", ears="round"),      # povo do vale (camundongos)
    "orc": dict(head="7a9a5a", body="6a4a3a", ears="tusk"),          # javalis
    "goblin": dict(head="8ab85a", body="5a4a6a", ears="long"),       # diabretes orelhudos
    "mago": dict(head="c8a878", body="4a4a8a", ears="hat"),          # corujas de chapéu
    "barbaro": dict(head="9a6a4a", body="8a5a3a", ears="horns"),     # ursinhos de elmo
    "celeste": dict(head="f0f4ff", body="8ab0e0", ears="wings"),     # passarinhos das nuvens
}

ROLE = {
    "ferreira": dict(cloak="8a5a3a", item="hammer"),
    "mercador": dict(cloak="b08a3a", item="pack"),
    "curandeira": dict(cloak="5a9a6a", item="leaf"),
    "sabio": dict(cloak="4a5aa0", item="book"),
    "capita": dict(cloak="8a8aa0", item="spear"),
    "receptador": dict(cloak="3a3444", item="mask"),
    "bardo": dict(cloak="a04a6a", item="lute"),
    "anciao": dict(cloak="7a7a7a", item="cane"),
    "crianca": dict(cloak="d08a4a", item="none"),
}


def npc_frame(species, role, bob=0, blink=False):
    S = SPECIES[species]
    R = ROLE[role]
    small = role == "crianca"
    c = Canvas(16, 16)
    head = hexc(S["head"])
    cloak = hexc(R["cloak"])
    hy = (7 if small else 4) + bob
    hw = [5, 7, 7, 7, 5] if not small else [5, 7, 7, 5]
    # corpo/manto
    by = hy + len(hw) - 1
    c.rows(4, by, [6, 7, 8, 8][: 13 - by + 1] if by <= 12 else [8], cloak)
    # cabeça
    c.rows(5, hy, hw, head)
    ears = S["ears"]
    if ears == "round":
        c.rect(4, hy - 1, 2, 2, head)
        c.rect(10, hy - 1, 2, 2, head)
    elif ears == "long":
        c.line(5, hy + 1, 2, hy - 1, head)
        c.line(11, hy + 1, 14, hy - 1, head)
    elif ears == "tusk":
        c.set(6, hy - 1, head)
        c.set(10, hy - 1, head)
        c.rect(11, hy + 2, 2, 2, head)  # focinho
    elif ears == "hat":
        c.rows(5, hy - 4, [1, 3, 5, 9], hexc("3a3a7a"), offsets=[1, 0, 0, -1])
    elif ears == "horns":
        c.rows(5, hy - 1, [7], hexc("9a9aa8"))
        c.set(4, hy - 2, hexc("e8dcc0"))
        c.set(12, hy - 2, hexc("e8dcc0"))
    elif ears == "wings":
        c.set(3, by + 1, head)
        c.set(2, by, head)
        c.set(12, by + 1, head)
        c.set(13, by, head)
        c.set(8, hy - 1, head)
    item = R["item"]
    if item == "hammer":
        c.vline(12, by, by + 3, hexc("7a5a3a"))
        c.rect(11, by - 1, 3, 2, hexc("8a8a9a"))
    elif item == "pack":
        c.rect(2, by, 3, 4, hexc("8a6a3a"))
    elif item == "leaf":
        c.set(12, by + 1, hexc("6ac86a"))
        c.set(13, by, hexc("6ac86a"))
    elif item == "book":
        c.rect(11, by + 1, 3, 3, hexc("a04a4a"))
    elif item == "spear":
        c.vline(13, hy - 2, 15, hexc("7a5a3a"))
        c.set(13, hy - 3, hexc("d8dce8"))
    elif item == "lute":
        c.rect(11, by + 1, 3, 3, hexc("c08a4a"))
        c.line(13, by, 14, by - 3, hexc("7a5a3a"))
    elif item == "cane":
        c.vline(12, by + 1, 15, hexc("7a5a3a"))
        c.set(11, by + 1, hexc("7a5a3a"))
    c.outline(OUT)
    # pernas
    c.vline(6, 14, 15, OUT)
    c.vline(9, 14, 15, OUT)
    # olhos / detalhes do rosto
    ey = hy + 2
    if species == "mago":
        c.rect(6, ey - 1, 2, 2, hexc("ffffff"))
        c.rect(9, ey - 1, 2, 2, hexc("ffffff"))
        if not blink:
            c.set(7, ey, EYE)
            c.set(10, ey, EYE)
        c.set(8, ey + 1, hexc("e8a040"))
    else:
        if blink:
            c.set(7, ey + 1, EYE)
            c.set(10, ey + 1, EYE)
        else:
            c.vline(7, ey, ey + 1, EYE)
            c.vline(10, ey, ey + 1, EYE)
    if item == "mask":
        c.hline(6, 11, ey, hexc("2a2434"))
        c.set(7, ey, hexc("e8e0c8"))
        c.set(10, ey, hexc("e8e0c8"))
    if role == "anciao" and species not in ("mago", "celeste"):
        c.rows(7, ey + 2, [3, 1], hexc("e8e8e8"))
    return c


def npc_sheet(species, role):
    return [npc_frame(species, role, 0), npc_frame(species, role, 1), npc_frame(species, role, 0, blink=True)]
