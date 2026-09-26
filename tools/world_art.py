"""Tilesets 8x8 e fundos parallax por bioma — visual limpo, poucas cores.

Atlas do tileset (8 colunas x 6 linhas de 8x8):
  linhas 0-1: 16 tiles de borda pela máscara de vizinhos sólidos
              (bit 1=cima, 2=direita, 4=baixo, 8=esquerda) — índice = máscara
  linha 2:    4 variações de preenchimento | 4 cantos internos (sobreposição)
  linha 3:    plataforma E/M/D/única | espinhos | quebrável | piso rachado | parede de fundo
  linha 4:    3 variações de parede de fundo | 5 decorações de chão
  linha 5:    4 decorações de teto (penduradas) | 4 livres
"""
import math
import random
from px import Canvas, hexc, CLEAR


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dark(c, k=0.75):
    return (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)


def light(c, k=0.2):
    return mix(c, (255, 255, 255, 255), k)


# ---------------------------------------------------------------------------
# Paletas por bioma
# ---------------------------------------------------------------------------
# style: earth | brick | sand | marble | cave | wood
# top: grass | moss | sand | snow | gold | none | crystal
BIOMES = {
    "cemiterio": dict(style="earth", fill="4a4459", top="6e8a5a", top2="4f6b47", back="3a3548", deco="graves", hang="roots",
                      sky=["2c3558", "4d5b87", "8d8fb8"], far=("hills", "5b6390"), mid=("graves", "404668"), moon=True, stars=True),
    "castelo": dict(style="brick", fill="5a5f73", top="none", top2="", back="3d4052", deco="candles", hang="chains",
                    sky=["3a3e55", "4a4f68", "5a6080"], far=("hall", "40445a"), mid=("arches", "2a2d3d"), indoor=True),
    "catacumbas": dict(style="brick", fill="5b5046", top="none", top2="", back="3b342e", deco="bones", hang="webs",
                       sky=["3a322c", "4a403a", "5a4e46"], far=("hall", "463c36"), mid=("niches", "3a322c"), indoor=True),
    "cidade_gotica": dict(style="brick", fill="4d5068", top="none", top2="", back="36384c", deco="lamps", hang="chains",
                          sky=["2d3150", "54587e", "a08aa0"], far=("city", "4a4d70"), mid=("towers", "33354f"), moon=True, stars=True),
    "templo_dourado": dict(style="sand", fill="b8905a", top="gold", top2="e8c46a", back="8a6a44", deco="urns", hang="banners",
                           sky=["7a6044", "9a7c56", "b89a6e"], far=("columns", "967650"), mid=("arches", "7a5f40"), indoor=True),
    "ruinas": dict(style="sand", fill="8a8a7a", top="moss", top2="5f7a4a", back="5e5e52", deco="rubble", hang="vines",
                   sky=["6f8fb0", "a7bfd0", "e0e4d8"], far=("mountains", "8fa4b8"), mid=("ruins", "6c7a80"), sun=True),
    "floresta": dict(style="earth", fill="5a4638", top="grass", top2="4c8a3e", back="3c3028", deco="flowers", hang="vines",
                     sky=["6aa0c8", "a8d0e0", "e4f0e0"], far=("hills", "8ab8a0"), mid=("trees", "4f7a58"), sun=True),
    "deserto": dict(style="sand", fill="c49a62", top="sand", top2="e2c088", back="9a7650", deco="cactus", hang="none",
                    sky=["e0a870", "f0c890", "f8e4b8"], far=("dunes", "e0b884"), mid=("mesas", "c08858"), sun=True),
    "pantano": dict(style="earth", fill="3e4a3a", top="moss", top2="5a7a3a", back="2c3528", deco="reeds", hang="roots",
                    sky=["3a4a40", "5a6e58", "8a9a78"], far=("hills", "56685a"), mid=("deadtrees", "3a4a3c"), fog=True),
    "cidade_ceu": dict(style="marble", fill="d8d6e8", top="gold", top2="f0d27a", back="aeb0cc", deco="urns", hang="banners",
                       sky=["7ab0f0", "b0d4f8", "eef6ff"], far=("clouds", "ffffff"), mid=("spires", "c8cce8"), sun=True),
    "cidade_subterranea": dict(style="cave", fill="4a4260", top="crystal", top2="7ad8e8", back="2e2840", deco="mushrooms", hang="stalactites",
                               sky=["2a2440", "3a3258", "4a4068"], far=("cave", "3a3256"), mid=("houses", "2e2846"), indoor=True),
    "cidade_magos": dict(style="brick", fill="5a4d7a", top="none", top2="", back="3d3456", deco="books", hang="banners",
                         sky=["2a2350", "4a3a7a", "8a6ab0"], far=("magetowers", "4d3f78"), mid=("magetowers2", "362c58"), stars=True, moon=True),
    "fortaleza_orc": dict(style="wood", fill="6b4a32", top="none", top2="", back="4a3424", deco="spikes", hang="chains",
                          sky=["8a5040", "c07a50", "e8b070"], far=("mountains", "a0604a"), mid=("palisade", "5a3a28"), sun=True),
    "acampamento_barbaro": dict(style="earth", fill="6a5040", top="snow", top2="e8eef4", back="4a382c", deco="rocks", hang="none",
                                sky=["8aa4c0", "c0d0dc", "eef2f4"], far=("mountains", "a8b8c8"), mid=("tents", "6a5a58"), sun=True),
    "toca_goblin": dict(style="cave", fill="4a5238", top="moss", top2="6a8a3a", back="2e3424", deco="mushrooms", hang="roots",
                        sky=["2a3322", "38442c", "485838"], far=("cave", "3a4630"), mid=("cave2", "2e3826"), indoor=True),
}


# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------

def _texture(c, ox, oy, style, base, rng, variant):
    d = dark(base, 0.82)
    lt = light(base, 0.12)
    if style == "brick":
        # tijolos 4 de altura, juntas escuras, deslocados
        for y in range(8):
            if y % 4 == 3:
                c.hline(ox, ox + 7, oy + y, d)
        off = 0 if (variant % 2 == 0) else 4
        for row in range(2):
            x = (off + row * 4) % 8
            c.vline(ox + x, oy + row * 4, oy + row * 4 + 2, d)
        if variant == 2:
            c.set(ox + 5, oy + 1, lt)
    elif style == "sand":
        # blocos grandes 8x8 com junta
        c.hline(ox, ox + 7, oy + 7, d)
        c.vline(ox + 7, oy, oy + 7, d)
        if variant == 1:
            c.set(ox + 2, oy + 3, d)
            c.set(ox + 3, oy + 3, d)
        if variant == 3:
            c.set(ox + 5, oy + 2, lt)
    elif style == "marble":
        c.hline(ox, ox + 7, oy + 7, d)
        if variant in (1, 3):
            c.line(ox + 1, oy + 2, ox + 4, oy + 4, dark(base, 0.9))
    elif style == "earth":
        pts = [(2, 2), (5, 5), (6, 1), (1, 6)]
        px, py = pts[variant % 4]
        c.set(ox + px, oy + py, d)
        if variant % 2:
            c.set(ox + px + 1, oy + py, d)
    elif style == "cave":
        pts = [(1, 2), (5, 4), (3, 6), (6, 1)]
        px, py = pts[variant % 4]
        c.set(ox + px, oy + py, d)
        c.set(ox + px + 1, oy + py + 1, d)
    elif style == "wood":
        for y in (2, 5):
            c.hline(ox, ox + 7, oy + y, d)
        c.set(ox + (2 + variant * 2) % 8, oy + 3, d)


def _tile(c, ox, oy, mask, P, rng, variant=0):
    """Desenha um tile sólido com bordas conforme a máscara de vizinhos."""
    base = P["fill"]
    edge = dark(base, 0.55)
    c.rect(ox, oy, 8, 8, base)
    _texture(c, ox, oy, P["style"], base, rng, variant)
    up = mask & 1
    right = mask & 2
    down = mask & 4
    left = mask & 8
    # bordas expostas: contorno escuro de 1px + realce
    if not left:
        c.vline(ox, oy, oy + 7, edge)
        c.vline(ox + 1, oy, oy + 7, light(base, 0.1))
    if not right:
        c.vline(ox + 7, oy, oy + 7, edge)
    if not down:
        c.hline(ox, ox + 7, oy + 7, edge)
        c.hline(ox + 1, ox + 6, oy + 6, dark(base, 0.85))
    if not up:
        top = P["top"]
        if top in ("grass", "moss", "snow", "sand", "crystal"):
            tc = P["top_c"]
            tc2 = P["top2_c"]
            c.hline(ox, ox + 7, oy, tc)
            c.hline(ox, ox + 7, oy + 1, tc)
            # borda irregular embaixo da camada
            for x in range(8):
                if (x + variant) % 3 != 0:
                    c.set(ox + x, oy + 2, tc2 if top != "snow" else tc)
            c.hline(ox, ox + 7, oy, light(tc, 0.25))
            if top == "crystal":
                c.hline(ox, ox + 7, oy + 1, P["fill"])
                c.set(ox + 2 + variant % 3, oy + 1, tc)
        elif top == "gold":
            c.hline(ox, ox + 7, oy, light(base, 0.35))
            c.hline(ox, ox + 7, oy + 1, P["top2_c"])
        else:
            c.hline(ox, ox + 7, oy, light(base, 0.3))
            c.hline(ox, ox + 7, oy + 1, light(base, 0.12))
        if not left:
            c.set(ox, oy, edge)
        if not right:
            c.set(ox + 7, oy, edge)


def _deco(c, ox, oy, kind, i, P):
    """Decoração de chão (no tile vazio acima do chão; base na linha 7)."""
    g = P.get("top_c", hexc("6e8a5a"))
    d = dark(P["fill"], 0.5)
    if kind in ("flowers", "reeds", "graves", "rubble", "rocks", "cactus") and i == 0:
        # tufo de grama genérico
        for x, h in ((1, 2), (2, 3), (4, 2), (5, 3), (6, 1)):
            c.vline(ox + x, oy + 8 - h, oy + 7, g if P["top"] in ("grass", "moss") else dark(P["fill"], 0.9))
        return
    if kind == "flowers":
        cols = [hexc("f2d25a"), hexc("f07a8a"), hexc("ffffff"), hexc("8ac8f0")]
        x = 2 + i
        c.vline(ox + x, oy + 5, oy + 7, g)
        c.set(ox + x, oy + 4, cols[i % 4])
        c.set(ox + x + 2, oy + 6, cols[(i + 1) % 4])
    elif kind == "graves":
        c.rect(ox + 2, oy + 3, 4, 5, hexc("8a8aa0"))
        c.hline(ox + 3, ox + 4, oy + 2, hexc("8a8aa0"))
        c.hline(ox + 3, ox + 4, oy + 4, hexc("5a5a70"))
        c.outline(d) if False else None
    elif kind == "candles":
        c.rect(ox + 3, oy + 4, 2, 4, hexc("e8e0c8"))
        c.set(ox + 3, oy + 3, hexc("ffc850"))
        c.set(ox + 3, oy + 2, hexc("fff0b0"))
    elif kind == "bones":
        c.hline(ox + 1, ox + 5, oy + 7, hexc("d8ceb8"))
        c.set(ox + 1, oy + 6, hexc("d8ceb8"))
        c.set(ox + 5, oy + 6, hexc("d8ceb8"))
        if i % 2:
            c.rect(ox + 5, oy + 4, 2, 2, hexc("d8ceb8"))
    elif kind == "lamps":
        c.vline(ox + 4, oy + 1, oy + 7, hexc("2a2a38"))
        c.rect(ox + 3, oy, 3, 2, hexc("ffd88a"))
    elif kind == "urns":
        c.rows(ox + 2, oy + 3, [2, 4, 4, 4, 2], hexc("c07a4a") if P["style"] != "marble" else hexc("d8b060"))
    elif kind == "rubble":
        c.rect(ox + 1, oy + 6, 3, 2, dark(P["fill"], 0.85))
        c.rect(ox + 4, oy + 5, 3, 3, P["fill"])
    elif kind == "cactus":
        c.vline(ox + 4, oy + 2, oy + 7, hexc("5a8a4a"))
        c.vline(ox + 2, oy + 4, oy + 5, hexc("5a8a4a"))
        c.set(ox + 3, oy + 5, hexc("5a8a4a"))
    elif kind == "reeds":
        for x in (2, 4, 5):
            c.vline(ox + x, oy + 2 + x % 2, oy + 7, hexc("6a7a3a"))
        c.set(ox + 4, oy + 1, hexc("8a5a3a"))
    elif kind == "mushrooms":
        col = [hexc("7ad8e8"), hexc("e87a9a"), hexc("c8e87a")][i % 3]
        c.vline(ox + 3, oy + 5, oy + 7, hexc("d8d0c0"))
        c.hline(ox + 2, ox + 4, oy + 4, col)
        c.set(ox + 3, oy + 3, col)
    elif kind == "books":
        cols = [hexc("a04a4a"), hexc("4a6aa0"), hexc("c0a04a")]
        for k in range(3):
            c.rect(ox + 1 + k * 2, oy + 3 + k % 2, 2, 5 - k % 2, cols[(k + i) % 3])
    elif kind == "spikes":
        for x in (1, 4):
            c.vline(ox + x, oy + 2, oy + 7, hexc("8a6a4a"))
            c.set(ox + x, oy + 1, hexc("d8ceb8"))
    elif kind == "rocks":
        c.rows(ox + 2, oy + 5, [3, 4, 5], hexc("8a8a90"))
    else:
        c.set(ox + 3, oy + 7, d)


def _hang(c, ox, oy, kind, i, P):
    """Decoração pendurada no teto (topo do tile)."""
    if kind == "roots":
        col = dark(P["fill"], 0.7)
        c.vline(ox + 2 + i, oy, oy + 3 + i % 3, col)
        c.set(ox + 3 + i, oy + 4 + i % 3, col)
    elif kind == "vines":
        col = hexc("4c7a3e")
        for y in range(3 + i % 4):
            c.set(ox + 3 + (y % 2), oy + y, col)
        c.set(ox + 5, oy + 2, hexc("6aa04a"))
    elif kind == "chains":
        col = hexc("5a5a6a")
        for y in range(0, 6 + i % 2, 2):
            c.set(ox + 4, oy + y, col)
            c.set(ox + 4, oy + y + 1, dark(col, 0.7))
    elif kind == "webs":
        col = (200, 200, 210, 140)
        c.line(ox, oy, ox + 5, oy + 5, col)
        c.line(ox, oy + 3, ox + 3, oy, col)
    elif kind == "stalactites":
        col = dark(P["fill"], 0.85)
        c.rows(ox + 2, oy, [4, 3, 2, 1][: 3 + i % 2], col)
        if i == 2:
            c.set(ox + 3, oy + 3, P["top2_c"])
    elif kind == "banners":
        col = [hexc("a04a5a"), hexc("4a5aa0"), hexc("c09a3a"), hexc("4a8a6a")][i % 4]
        c.rect(ox + 2, oy, 4, 6, col)
        c.set(ox + 3, oy + 6, col)
        c.set(ox + 4, oy + 3, light(col, 0.4))


def tileset(biome_id):
    P = dict(BIOMES[biome_id])
    P["fill"] = hexc(P["fill"])
    P["top_c"] = hexc(P["top2"]) if P["top"] == "snow" else hexc(P.get("top2") or "ffffff") if False else None
    # cores da camada de topo
    tops = {"grass": ("6aa04a", "4c7a3e"), "moss": ("6a8a4a", "4f6b3a"), "snow": ("f0f4f8", "d0dce8"),
            "sand": ("e2c088", "c49a62"), "crystal": ("7ad8e8", "4aa8c8"), "gold": ("f0d27a", "c8a04a"), "none": ("ffffff", "ffffff")}
    t1, t2 = tops.get(P["top"], ("ffffff", "ffffff"))
    if P["top"] in ("grass", "moss", "sand") and P.get("top2"):
        t1 = P["top2"]
        t2 = hexc(P["top2"])
        t2 = "%02x%02x%02x" % dark(t2, 0.8)[:3]
    P["top_c"] = hexc(t1)
    P["top2_c"] = hexc(t2)
    back = hexc(P["back"])
    rng = random.Random(biome_id)
    c = Canvas(64, 48)
    for m in range(16):
        _tile(c, (m % 8) * 8, (m // 8) * 8, m, P, rng, m % 4)
    for v in range(4):
        _tile(c, v * 8, 16, 15, P, rng, v)
    # cantos internos: pixel escuro no canto
    edge = dark(P["fill"], 0.55)
    for k, (cx, cy) in enumerate(((0, 0), (7, 0), (0, 7), (7, 7))):
        c.set(32 + k * 8 + cx, 16 + cy, edge)
    # plataformas one-way (3px)
    plank = light(P["fill"], 0.1)
    for k in range(4):
        ox = k * 8
        c.hline(ox, ox + 7, 24, light(plank, 0.25))
        c.hline(ox, ox + 7, 25, plank)
        c.hline(ox, ox + 7, 26, dark(plank, 0.6))
        if k in (0, 3):
            c.vline(ox, 24, 26, dark(plank, 0.5))
            c.set(ox + 1, 27, dark(plank, 0.5))
        if k in (2, 3):
            c.vline(ox + 7, 24, 26, dark(plank, 0.5))
            c.set(ox + 6, 27, dark(plank, 0.5))
    # espinhos (apontando para cima, base na linha 7)
    sp = hexc("d8dce8")
    for x in (0, 4):
        c.rows(32 + x, 24 + 3, [0, 0, 0, 0], sp) if False else None
        c.set(32 + x + 1, 24 + 3, sp)
        c.hline(32 + x + 1, 32 + x + 2, 24 + 4, sp)
        c.hline(32 + x, 32 + x + 3, 24 + 5, sp)
        c.set(32 + x + 2, 24 + 3, dark(sp, 0.7))
    c.hline(32, 39, 24 + 6, dark(sp, 0.6))
    c.hline(32, 39, 24 + 7, dark(sp, 0.45))
    # quebrável: bloco rachado
    _tile(c, 40, 24, 0, P, rng, 1)
    cr = dark(P["fill"], 0.45)
    c.line(42, 25, 44, 28, cr)
    c.line(44, 28, 43, 31, cr)
    c.line(44, 28, 46, 27, cr)
    # piso rachado (só quebra com queda esmagadora)
    _tile(c, 48, 24, 2 | 8, P, rng, 2)
    c.line(50, 26, 53, 29, cr)
    c.line(53, 29, 55, 27, cr)
    # parede de fundo (4 variações): tijolo baixo contraste
    for k in range(4):
        ox = 56 if k == 0 else (k - 1) * 8
        oy = 24 if k == 0 else 32
        c.rect(ox, oy, 8, 8, back)
        jd = dark(back, 0.9)
        # variação 0 (a mais usada) é lisa: fundo limpo; as outras têm detalhes
        if k == 0:
            pass
        elif P["style"] in ("brick", "sand", "marble", "wood"):
            c.hline(ox, ox + 7, oy + 7, jd)
            c.vline(ox + (2 if k % 2 else 6), oy + 4, oy + 6, jd)
        else:
            c.set(ox + 2 + k, oy + 3, jd)
            c.set(ox + 5, oy + 6 - k % 2, jd)
    # decorações de chão (5) e de teto (4)
    for k in range(5):
        _deco(c, 24 + k * 8, 32, P["deco"], k, P)
    for k in range(4):
        _hang(c, k * 8, 40, P["hang"], k, P)
    return c


# ---------------------------------------------------------------------------
# Fundos parallax (320x180, repetem na horizontal)
# ---------------------------------------------------------------------------
BW, BH = 320, 180


def _periodic(x, parts, seed):
    """Soma de senos com períodos que dividem 320 (emenda perfeita)."""
    r = random.Random(seed)
    v = 0.0
    for n, amp in parts:
        ph = r.random() * math.tau
        v += amp * math.sin(x / BW * math.tau * n + ph)
    return v


def sky(P):
    c = Canvas(BW, BH)
    cols = [hexc(h) for h in P["sky"]]
    # 3 faixas com transição em dither (limpo, sem ruído)
    bands = [0, 70, 130, BH]
    for y in range(BH):
        if y < bands[1]:
            t = y / bands[1]
            a, b = cols[0], cols[1]
        else:
            t = (y - bands[1]) / (BH - bands[1])
            a, b = cols[1], cols[2]
        # quantiza em 4 degraus com dither ordenado 2x2
        q = t * 4
        base = int(q)
        frac = q - base
        for x in range(BW):
            th = [[0.2, 0.7], [0.95, 0.45]][y % 2][x % 2]
            k = min(base + (1 if frac > th else 0), 4) / 4
            c.set(x, y, mix(a, b, k))
    if P.get("stars"):
        r = random.Random(7)
        for i in range(60):
            x, y = r.randrange(BW), r.randrange(100)
            c.set(x, y, mix(cols[0], hexc("ffffff"), 0.5 + r.random() * 0.4))
    if P.get("moon"):
        c.ellipse(250, 34, 9, 9, hexc("f0ecd8"))
        c.ellipse(253, 32, 8, 8, mix(cols[0], cols[1], 0.2))
    if P.get("sun"):
        c.ellipse(240, 40, 12, 12, mix(cols[2], hexc("ffffff"), 0.6))
        c.ellipse(240, 40, 9, 9, mix(cols[2], hexc("ffffff"), 0.85))
    return c


def _silhouette(c, kind, col, seed, base_y, height):
    r = random.Random(seed)
    lt = light(col, 0.12)
    if kind in ("mountains", "hills", "dunes"):
        parts = {"mountains": [(2, 0.5), (5, 0.3), (11, 0.15), (23, 0.06)],
                 "hills": [(2, 0.5), (3, 0.3), (7, 0.12)], "dunes": [(1, 0.5), (3, 0.35), (4, 0.1)]}[kind]
        for x in range(BW):
            h = height * (0.55 + 0.45 * _periodic(x, parts, seed))
            top = int(base_y - h)
            c.vline(x, top, BH - 1, col)
            if kind == "mountains" and top < base_y - height * 0.75:
                c.set(x, top, lt)
                c.set(x, top + 1, lt)
    elif kind == "clouds":
        for i in range(9):
            cx = i * 36 + r.randrange(10)
            cy = base_y - r.randrange(int(height))
            for k in range(4):
                c.ellipse(cx + k * 7 - 10, cy - (k % 2) * 4, 9, 6, col)
            c.ellipse(cx + 320 if cx < 30 else cx - 320, cy, 1, 1, col)
        c.rect(0, base_y, BW, BH - base_y, col)
    elif kind in ("trees", "deadtrees"):
        c.rect(0, base_y, BW, BH - base_y, col)
        x = 0
        while x < BW:
            h = int(height * (0.6 + 0.4 * r.random()))
            if kind == "trees":
                for y in range(h):
                    w = int((y / h) * 7) + 1
                    c.hline(x - w, x + w, base_y - h + y, col)
                    c.hline(x - w + BW, x + w + BW, base_y - h + y, col)
                    c.hline(x - w - BW, x + w - BW, base_y - h + y, col)
            else:
                c.vline(x, base_y - h, base_y, col)
                c.line(x, base_y - h // 2, x + 5, base_y - h // 2 - 5, col)
                c.line(x, base_y - h // 3 * 2, x - 4, base_y - h + 2, col)
            x += 9 + r.randrange(10)
    elif kind in ("city", "towers", "houses", "spires", "magetowers", "magetowers2", "ruins", "mesas", "tents", "palisade", "graves"):
        c.rect(0, base_y, BW, BH - base_y, col)
        x = 0
        win = mix(col, hexc("ffd88a"), 0.55)
        while x < BW:
            if kind == "graves":
                w = 5 + r.randrange(4)
                h = 6 + r.randrange(6)
                c.rect(x, base_y - h, w, h, col)
                if r.random() < 0.4:
                    c.vline(x + w // 2, base_y - h - 4, base_y - h, col)
                    c.hline(x + w // 2 - 2, x + w // 2 + 2, base_y - h - 2, col)
                x += w + 4 + r.randrange(10)
                continue
            if kind == "tents":
                w = 18 + r.randrange(10)
                h = 12 + r.randrange(8)
                for y in range(h):
                    ww = int(w * y / h / 2)
                    c.hline(x + w // 2 - ww, x + w // 2 + ww, base_y - h + y, col)
                c.vline(x + w // 2, base_y - h - 5, base_y - h, col)
                x += w + 6 + r.randrange(14)
                continue
            if kind == "palisade":
                for k in range(0, BW, 5):
                    h = height * 0.5 + (k * 7 % 5)
                    c.rect(k, int(base_y - h), 4, int(h), col)
                    c.set(k + 1, int(base_y - h) - 1, col)
                    c.set(k + 2, int(base_y - h) - 1, col)
                break
            if kind == "mesas":
                w = 30 + r.randrange(30)
                h = int(height * (0.4 + 0.6 * r.random()))
                c.rows(x, base_y - h, [w - 6, w - 4] + [w] * (h - 2), col)
                x += w + 10 + r.randrange(30)
                continue
            w = 8 + r.randrange(12)
            h = int(height * (0.35 + 0.65 * r.random()))
            if kind in ("spires", "magetowers", "magetowers2"):
                w = 6 + r.randrange(6)
                h = int(height * (0.5 + 0.5 * r.random()))
            c.rect(x, base_y - h, w, h, col)
            # telhados / pontas
            if kind in ("towers", "spires", "magetowers", "magetowers2"):
                for k in range(w // 2 + 3):
                    c.hline(x + k - 1, x + w - k, base_y - h - k, col)
                if kind.startswith("magetowers"):
                    c.set(x + w // 2, base_y - h - w // 2 - 3, hexc("c08aff"))
            elif kind == "ruins":
                for k in range(w):
                    if r.random() < 0.5:
                        c.set(x + k, base_y - h - 1, col)
                if r.random() < 0.5:
                    c.rect(x + 2, base_y - h + 3, max(w - 4, 2), 4, CLEAR)
            else:
                c.hline(x - 1, x + w, base_y - h, col)
            # janelinhas acesas (poucas)
            if kind in ("city", "houses", "towers", "magetowers", "magetowers2"):
                for k in range(r.randrange(3)):
                    wx = x + 2 + r.randrange(max(w - 4, 1))
                    wy = base_y - h + 4 + r.randrange(max(h - 8, 1))
                    c.rect(wx, wy, 1, 2, win)
            x += w + r.randrange(6)
    elif kind in ("hall", "arches", "niches", "columns"):
        c.rect(0, 0, BW, BH, col)
        cut = mix(col, hexc("000000"), 0.25)
        if kind == "hall":
            # janelas altas com arco (luz fria saindo)
            for i in range(4):
                x = i * 80 + 30
                c.rect(x, 40, 20, 70, light(col, 0.18))
                c.ellipse(x + 10, 40, 10, 10, light(col, 0.18))
                c.vline(x + 10, 32, 110, col)
                c.hline(x, x + 19, 75, col)
        elif kind == "arches":
            c.rect(0, 0, BW, BH, CLEAR)
            for i in range(5):
                x = i * 64
                c.rect(x, 0, 14, BH, col)
                for k in range(26):
                    yy = int(24 * math.sqrt(max(0.0, 1 - ((k - 25) / 25) ** 2)))
                    c.vline(x + 14 + k, 0, 40 - yy, col)
                    c.vline(x + 64 - k - 1, 0, 40 - yy, col)
            c.rect(0, 150, BW, 30, col)
        elif kind == "niches":
            for i in range(8):
                for j in range(3):
                    c.rect(i * 40 + 8, 30 + j * 40, 22, 14, cut)
                    c.rect(i * 40 + 12, 36 + j * 40, 6, 4, hexc("8a8070"))
        elif kind == "columns":
            for i in range(5):
                x = i * 64 + 10
                c.rect(x, 20, 12, 140, light(col, 0.1))
                c.rect(x - 2, 18, 16, 4, light(col, 0.18))
                c.rect(x - 2, 156, 16, 4, light(col, 0.18))
    elif kind in ("cave", "cave2"):
        for x in range(BW):
            top = int(18 + 14 * (0.5 + 0.5 * _periodic(x, [(3, 0.5), (8, 0.3), (17, 0.2)], seed)))
            bot = int(BH - 20 - 16 * (0.5 + 0.5 * _periodic(x, [(4, 0.5), (9, 0.3), (19, 0.2)], str(seed) + "b")))
            if kind == "cave2":
                top += 20
                bot -= 10
            c.vline(x, 0, top, col)
            c.vline(x, bot, BH - 1, col)
        for i in range(10):
            x = r.randrange(BW)
            c.rows(x, 30, [5, 4, 3, 2, 1], col)


def background(biome_id):
    P = BIOMES[biome_id]
    s = sky(P)
    far = Canvas(BW, BH)
    fk, fcol = P["far"]
    _silhouette(far, fk, hexc(fcol), biome_id + "far", 150, 60)
    mid = Canvas(BW, BH)
    mk, mcol = P["mid"]
    _silhouette(mid, mk, hexc(mcol), biome_id + "mid", 168, 50)
    return {"0_sky": s, "1_far": far, "2_mid": mid}
