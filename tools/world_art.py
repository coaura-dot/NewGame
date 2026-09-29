"""Tilesets 8x8 e fundos parallax por bioma — ESTÉTICA ESCURA (Hollow Knight/Ori).

Regras da arte:
  * O mundo é escuro: a rocha escurece da borda para dentro até quase preto,
    então as salas ganham "moldura" e o herói (claro) salta aos olhos.
  * As bordas expostas têm um fio de luz (mais forte em cima), e o topo tem
    musgo/grama/neve com pontinhas.
  * Os fundos são NÉVOA: quanto mais longe, mais clara e menos contrastada a
    silhueta (perspectiva atmosférica). O perto é quase preto.
  * Pontos LINDOS e claros: cada bioma tem uma cor de brilho (bioluminescência,
    cristais, vitrais, velas, lua). Esses pixels também vão para uma imagem
    "_glow" que o jogo soma por cima com cor HDR => bloom.

Atlas do tileset (8 colunas x 8 linhas de 8x8) — <bioma>.png e <bioma>_glow.png:
  linhas 0-1: 16 tiles de borda pela máscara de vizinhos sólidos
              (bit 1=cima, 2=direita, 4=baixo, 8=esquerda) — índice = máscara
  linha 2:    4 preenchimentos | 4 cantos internos (sobreposição)
  linha 3:    plataforma E/M/D/única | espinhos | quebrável | piso rachado | parede de fundo
  linha 4:    3 variações de parede de fundo | 5 decorações de chão
  linha 5:    4 decorações de teto (penduradas) | 4 paredes de fundo especiais
              (janela acesa, runa, nicho, rachadura)
  linha 6:    2 rochas fundas | 2 rochas muito fundas | 4 decorações grandes que brilham
  linha 7:    livre
"""
import math
import random
from px import Canvas, hexc, CLEAR


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def dark(c, k=0.75):
    return (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)


def light(c, k=0.2):
    return mix(c, (255, 255, 255, 255), k)


def alpha(c, a):
    return (c[0], c[1], c[2], int(a))


# ---------------------------------------------------------------------------
# Paletas por bioma
# ---------------------------------------------------------------------------
# style: earth | brick | sand | marble | cave | wood
# top:   grass | moss | sand | snow | gold | none | crystal
# rock = cor da rocha perto da borda; deep = interior (quase preto);
# rim = fio de luz nas bordas; back = parede de fundo (salas fechadas);
# glow = cor do brilho do bioma; warm = luz quente (velas/janelas);
# sky = [topo, meio, horizonte]; haze = névoa; far/mid/near = silhuetas.
BIOMES = {
    "cemiterio": dict(style="earth", rock="2c2a3e", deep="0c0b14", rim="6c6a94", top="moss", top_c="3e5a5a", top_hi="7aa8a0",
                      back="1d1c2c", glow="8ad8ff", warm="ffb45a", deco="graves", hang="roots",
                      sky=["07070f", "161a33", "3b4470"], haze="4a5585",
                      far=("hills", "283056"), mid=("graves", "181c34"), near=("deadtrees", "0b0c18"),
                      moon=True, stars=True, wisps=True),
    "castelo": dict(style="brick", rock="2e3142", deep="0b0c12", rim="7a809e", top="none", back="1c1e2a",
                    glow="ffcf7a", glow2="8ac0ff", warm="ffb45a", deco="candles", hang="chains",
                    sky=["08090f", "141722", "252a3c"], haze="39405a",
                    far=("hall", "1f2333"), mid=("arches", "12141e"), near=("pillars", "07080d"), indoor=True, stained=True),
    "catacumbas": dict(style="brick", rock="2f2824", deep="0d0a09", rim="85735e", top="none", back="1e1917",
                       glow="ffb04a", glow2="6ae8c8", warm="ffb04a", deco="bones", hang="webs",
                       sky=["0a0807", "181311", "2a221e"], haze="40342c",
                       far=("niches", "211b18"), mid=("arches", "15110f"), near=("pillars", "090706"), indoor=True, candles=True),
    "cidade_gotica": dict(style="brick", rock="2a2b40", deep="0b0b14", rim="6e6f98", top="none", back="1b1c2c",
                          glow="ffd27a", warm="ffc46a", deco="lamps", hang="chains",
                          sky=["090a16", "1b1d38", "4a3f66"], haze="554a78",
                          far=("city", "2a2b4a"), mid=("towers", "171830"), near=("fence", "0a0a14"), moon=True, stars=True),
    "templo_dourado": dict(style="sand", rock="3a2c1e", deep="100b07", rim="b0884e", top="gold", top_c="8a6428", top_hi="ffd36a",
                           back="241b12", glow="ffe08a", warm="ffc050", deco="urns", hang="banners",
                           sky=["0e0a06", "22180e", "3e2e1a"], haze="5a4428",
                           far=("columns", "2a1f14"), mid=("arches", "1a130c"), near=("pillars", "0b0805"), indoor=True, shafts=True),
    "ruinas": dict(style="sand", rock="2a3036", deep="0b0d10", rim="7a8a90", top="moss", top_c="36503e", top_hi="8ac890",
                   back="1b2024", glow="ffc27a", glow2="8affd0", warm="ffb060", deco="rubble", hang="vines",
                   sky=["0b0f1c", "2a2e4e", "b0667a"], haze="6a5a7a",
                   far=("mountains", "3a3a5e"), mid=("ruins", "1c2034"), near=("deadtrees", "0a0b14"), sun=True, stars=True),
    "floresta": dict(style="earth", rock="1f2a2a", deep="070c0c", rim="5a8a84", top="grass", top_c="24503e", top_hi="6ad0a0",
                     back="142020", glow="7ae8ff", glow2="d0ff8a", warm="ffd08a", deco="flowers", hang="vines",
                     sky=["040a10", "0e2430", "1f5a66"], haze="2e7078",
                     far=("pines", "1c4a56"), mid=("canopy", "10303a"), near=("trunks", "061012"), spirit=True, shafts=True),
    "deserto": dict(style="sand", rock="3a2e30", deep="100b0c", rim="b08a78", top="sand", top_c="6a5048", top_hi="d8b090",
                    back="241c1e", glow="ffc070", glow2="9ad0ff", warm="ffb050", deco="cactus", hang="none",
                    sky=["06081a", "1c2250", "5a4a7a"], haze="6a5a86",
                    far=("dunes", "3a3462"), mid=("mesas", "221c3a"), near=("dunes_near", "0c0a16"), moon=True, stars=True, bigmoon=True),
    "pantano": dict(style="earth", rock="222a22", deep="080b08", rim="5a7a52", top="moss", top_c="2e4424", top_hi="a8e060",
                    back="161c16", glow="b8ff5a", warm="ffd070", deco="reeds", hang="roots",
                    sky=["060a08", "142018", "2e4430"], haze="3e5a40",
                    far=("hills", "22342a"), mid=("deadtrees", "131e16"), near=("reeds_near", "060a07"), fog=True, wisps=True),
    "cidade_ceu": dict(style="marble", rock="3a3e5a", deep="0e1020", rim="c0c8f0", top="gold", top_c="7a6a48", top_hi="ffe6a0",
                       back="262a44", glow="a8f0ff", glow2="ffe6a0", warm="ffe0a0", deco="urns", hang="banners",
                       sky=["05071a", "18224a", "3a5a8a"], haze="4a6a9a",
                       far=("clouds", "2a3e6a"), mid=("spires", "1a2446"), near=("clouds_near", "0e1430"), stars=True, aurora=True),
    "cidade_subterranea": dict(style="cave", rock="2a2440", deep="0a0812", rim="7a6aa8", top="crystal", top_c="3a3a6a", top_hi="7ae8ff",
                               back="1a1628", glow="7ae8ff", glow2="ff7ad8", warm="ffb86a", deco="mushrooms", hang="stalactites",
                               sky=["07060e", "141026", "241c3e"], haze="34285a",
                               far=("cave", "1e1834"), mid=("houses", "130f22"), near=("stalagmites", "08060e"), indoor=True, crystals=True),
    "cidade_magos": dict(style="brick", rock="2e2648", deep="0c0916", rim="8a74c8", top="none", back="1e1830",
                         glow="c08aff", glow2="7ae8ff", warm="ffb86a", deco="books", hang="banners",
                         sky=["08061a", "1e1640", "4a2e7a"], haze="4e3a86",
                         far=("magetowers", "2a2050"), mid=("magetowers2", "18123a"), near=("pillars", "0a0816"), stars=True, moon=True, runes=True),
    "fortaleza_orc": dict(style="wood", rock="30221c", deep="0e0806", rim="946048", top="none", back="1e1512",
                          glow="ff7a3a", warm="ff9a40", deco="spikes", hang="chains",
                          sky=["0c0506", "2a0e0e", "6a2a1a"], haze="6a3024",
                          far=("mountains", "3a1a18"), mid=("palisade", "1e0f0c"), near=("stakes", "0a0504"), embers=True),
    "acampamento_barbaro": dict(style="earth", rock="262a36", deep="0a0b10", rim="8a96b0", top="snow", top_c="a8b8d0", top_hi="eef4ff",
                                back="181b24", glow="ffa04a", glow2="bfe4ff", warm="ffa04a", deco="rocks", hang="icicles",
                                sky=["060810", "182238", "3e5270"], haze="566a8a",
                                far=("mountains", "2e3a56"), mid=("tents", "161c2c"), near=("pines", "080a12"), stars=True, moon=True, snowfall=True),
    "toca_goblin": dict(style="cave", rock="262a1c", deep="0a0b06", rim="6e7a48", top="moss", top_c="344020", top_hi="c8e060",
                        back="181a10", glow="d8ff6a", glow2="ffb04a", warm="ffb04a", deco="mushrooms", hang="roots",
                        sky=["070805", "12160c", "222a14"], haze="303a1e",
                        far=("cave", "1a2012"), mid=("cave2", "11150b"), near=("stalagmites", "070805"), indoor=True),
}


class Lit:
    """Duas telas: a arte e a camada de brilho (só os pixels que emitem luz)."""

    def __init__(self, w, h):
        self.c = Canvas(w, h)
        self.g = Canvas(w, h)

    def emit(self, x, y, col, k=255):
        self.c.set(x, y, col)
        self.g.set(x, y, alpha(col, k))

    def emit_soft(self, x, y, col, k=110):
        """Só brilho (sem mudar a arte) — halos de 1 px em volta de chamas."""
        self.g.set(x, y, alpha(col, k))


# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------

def _prep(P):
    Q = dict(P)
    for k in ("rock", "deep", "rim", "back", "glow", "warm", "haze"):
        Q[k] = hexc(P[k])
    Q["glow2"] = hexc(P.get("glow2", P["glow"]))
    Q["top_c"] = hexc(P.get("top_c", "000000"))
    Q["top_hi"] = hexc(P.get("top_hi", "ffffff"))
    return Q


def _shade(P, d):
    """Cor da rocha a d pixels da borda exposta (0 = na borda)."""
    rock, deep = P["rock"], P["deep"]
    if d <= 1:
        return rock
    if d <= 7:
        return mix(rock, deep, (d - 1) / 6.0 * 0.45)
    if d <= 15:
        return mix(rock, deep, 0.45 + (d - 7) / 8.0 * 0.3)
    return mix(rock, deep, min(1.0, 0.75 + (d - 15) / 10.0 * 0.25))


def _texture(c, ox, oy, P, variant, dist):
    """Textura por estilo, só nos pixels próximos da borda (dist <= 6)."""
    style = P["style"]
    pts = []
    if style == "brick":
        for y in range(8):
            if y % 4 == 3:
                pts += [(x, y) for x in range(8)]
        off = 0 if variant % 2 == 0 else 4
        for row in range(2):
            x = (off + row * 4) % 8
            pts += [(x, row * 4 + k) for k in range(3)]
    elif style == "sand":
        pts += [(x, 7) for x in range(8)] + [(7, y) for y in range(8)]
        if variant == 1:
            pts += [(2, 3), (3, 3)]
    elif style == "marble":
        pts += [(x, 7) for x in range(8)]
        if variant in (1, 3):
            pts += [(1, 2), (2, 3), (3, 3), (4, 4)]
    elif style == "earth":
        base = [(2, 2), (5, 5), (6, 1), (1, 6)][variant % 4]
        pts += [base, (base[0] + 1, base[1])] if variant % 2 else [base]
        pts += [((base[0] + 3) % 8, (base[1] + 4) % 8)]
    elif style == "cave":
        base = [(1, 2), (5, 4), (3, 6), (6, 1)][variant % 4]
        pts += [base, (base[0] + 1, base[1] + 1)]
    elif style == "wood":
        pts += [(x, 2) for x in range(8)] + [(x, 5) for x in range(8)]
        pts += [((2 + variant * 2) % 8, 3)]
    for (x, y) in pts:
        d = dist(x, y)
        if d <= 9:
            col = c.get(ox + x, oy + y)
            c.set(ox + x, oy + y, dark(col, 0.72))
    # pontinhos claros (mica) perto da borda
    if variant == 2:
        x, y = 5, 1
        if dist(x, y) <= 4:
            c.set(ox + x, oy + y, mix(c.get(ox + x, oy + y), P["rim"], 0.5))


def _tile(L, ox, oy, mask, P, variant=0, base_d=None):
    """Tile sólido. mask = vizinhos sólidos. As faces expostas recebem luz;
    o interior escurece com a distância da borda."""
    c = L.c
    up, right, down, left = mask & 1, mask & 2, mask & 4, mask & 8

    def dist(x, y):
        if base_d is not None:
            return base_d
        ds = [99]
        if not up:
            ds.append(y)
        if not down:
            ds.append(7 - y)
        if not left:
            ds.append(x)
        if not right:
            ds.append(7 - x)
        m = min(ds)
        return 10 if m == 99 else m

    for y in range(8):
        for x in range(8):
            c.set(ox + x, oy + y, _shade(P, dist(x, y)))
    _texture(c, ox, oy, P, variant, dist)
    rim = P["rim"]
    # fios de luz: laterais e baixo mais fracos, topo mais forte
    if not left:
        c.vline(ox, oy, oy + 7, mix(P["rock"], rim, 0.55))
    if not right:
        c.vline(ox + 7, oy, oy + 7, mix(P["rock"], rim, 0.55))
    if not down:
        c.hline(ox, ox + 7, oy + 7, mix(P["rock"], rim, 0.3))
    if not up:
        top = P["top"]
        if top in ("grass", "moss", "snow", "sand", "crystal", "gold"):
            tc, hi = P["top_c"], P["top_hi"]
            c.hline(ox, ox + 7, oy, hi if top in ("snow",) else mix(tc, hi, 0.55))
            c.hline(ox, ox + 7, oy + 1, tc)
            for x in range(8):
                if (x + variant) % 3 != 0:
                    c.set(ox + x, oy + 2, dark(tc, 0.8) if top != "snow" else tc)
                if top in ("grass", "moss") and (x * 5 + variant * 3) % 7 == 0:
                    c.set(ox + x, oy + 3, dark(tc, 0.7))
            if top == "snow":
                c.hline(ox, ox + 7, oy + 1, mix(tc, hi, 0.4))
            # pontas que brilham (musgo luminoso, cristal, ouro)
            if top in ("moss", "grass", "crystal", "gold"):
                gx = (variant * 3 + 1) % 8
                L.emit(ox + gx, oy, P["top_hi"], 170 if top != "gold" else 120)
                if top == "crystal":
                    L.emit(ox + (gx + 4) % 8, oy + 1, P["glow"], 200)
        else:
            c.hline(ox, ox + 7, oy, rim)
            c.hline(ox, ox + 7, oy + 1, mix(P["rock"], rim, 0.35))
        if not left:
            c.set(ox, oy, mix(P["rock"], rim, 0.7))
        if not right:
            c.set(ox + 7, oy, mix(P["rock"], rim, 0.7))


def _deco(L, ox, oy, kind, i, P):
    """Decoração de chão (no tile vazio acima do chão; base na linha 7)."""
    c = L.c
    g = P["top_c"] if P["top"] in ("grass", "moss") else mix(P["rock"], P["rim"], 0.4)
    glow, warm = P["glow"], P["warm"]
    if kind in ("flowers", "reeds", "graves", "rubble", "rocks", "cactus") and i == 0:
        for x, h in ((1, 2), (2, 3), (4, 2), (5, 3), (6, 1)):
            c.vline(ox + x, oy + 8 - h, oy + 7, g)
        L.emit(ox + 2, oy + 5, P["top_hi"], 120)
        return
    if kind == "flowers":
        x = 2 + i % 3
        c.vline(ox + x, oy + 4, oy + 7, g)
        c.vline(ox + x + 2, oy + 5, oy + 7, g)
        col = [glow, P["glow2"], glow, P["top_hi"]][i % 4]
        L.emit(ox + x, oy + 3, col)
        L.emit(ox + x - 1, oy + 3, dark(col, 0.7), 150)
        L.emit(ox + x + 1, oy + 3, dark(col, 0.7), 150)
        L.emit(ox + x + 2, oy + 4, col, 200)
    elif kind == "graves":
        st = mix(P["rock"], P["rim"], 0.45)
        c.rect(ox + 2, oy + 3, 4, 5, st)
        c.hline(ox + 3, ox + 4, oy + 2, st)
        c.vline(ox + 2, oy + 3, oy + 7, mix(st, P["rim"], 0.4))
        c.hline(ox + 3, ox + 4, oy + 5, dark(st, 0.6))
        if i % 2 == 1:
            L.emit(ox + 4, oy + 1, glow, 160)  # fogo-fátuo
    elif kind == "candles":
        wax = hexc("d8ccb0")
        sticks = [(2, 4), (5, 3)] if i % 2 else [(3, 4)]
        for (x, h) in sticks:
            c.rect(ox + x, oy + 8 - h, 1 if i % 2 else 2, h, wax)
            L.emit(ox + x, oy + 7 - h, warm)
            L.emit(ox + x, oy + 6 - h, light(warm, 0.5), 200)
    elif kind == "bones":
        b = hexc("b8ae98")
        c.hline(ox + 1, ox + 5, oy + 7, b)
        c.set(ox + 1, oy + 6, b)
        c.set(ox + 5, oy + 6, b)
        if i % 2:
            c.rect(ox + 5, oy + 4, 2, 2, b)
            c.set(ox + 5, oy + 5, P["deep"])
        if i == 3:
            L.emit(ox + 3, oy + 6, P["glow2"], 140)
    elif kind == "lamps":
        c.vline(ox + 4, oy + 2, oy + 7, hexc("141420"))
        c.hline(ox + 3, ox + 5, oy + 1, hexc("141420"))
        L.emit(ox + 4, oy + 2, glow)
        L.emit(ox + 3, oy + 2, dark(glow, 0.8), 180)
        L.emit(ox + 5, oy + 2, dark(glow, 0.8), 180)
    elif kind == "urns":
        col = mix(P["rock"], P["rim"], 0.6)
        c.rows(ox + 2, oy + 3, [2, 4, 4, 4, 2], col)
        c.vline(ox + 2, oy + 4, oy + 6, light(col, 0.2))
        if i % 2:
            L.emit(ox + 3, oy + 2, P["warm"], 220)
            L.emit(ox + 4, oy + 1, light(P["warm"], 0.4), 160)
    elif kind == "rubble":
        c.rect(ox + 1, oy + 6, 3, 2, P["rock"])
        c.rect(ox + 4, oy + 5, 3, 3, mix(P["rock"], P["rim"], 0.2))
        c.hline(ox + 4, ox + 6, oy + 5, mix(P["rock"], P["rim"], 0.5))
        if i == 2:
            L.emit(ox + 2, oy + 5, P["glow2"], 170)
    elif kind == "cactus":
        cg = hexc("2e4a3a")
        c.vline(ox + 4, oy + 2, oy + 7, cg)
        c.vline(ox + 2, oy + 4, oy + 5, cg)
        c.set(ox + 3, oy + 5, cg)
        L.emit(ox + 4, oy + 1, P["glow2"], 200)
    elif kind == "reeds":
        rc = hexc("2e3a1e")
        for x in (2, 4, 5):
            c.vline(ox + x, oy + 2 + x % 2, oy + 7, rc)
        L.emit(ox + 4, oy + 1, glow)
        if i % 2:
            L.emit(ox + 2, oy + 2, glow, 180)
    elif kind == "mushrooms":
        col = [glow, P["glow2"], glow][i % 3]
        c.vline(ox + 3, oy + 5, oy + 7, hexc("8a8478"))
        L.emit(ox + 2, oy + 4, dark(col, 0.8), 220)
        L.emit(ox + 3, oy + 4, col)
        L.emit(ox + 4, oy + 4, dark(col, 0.8), 220)
        L.emit(ox + 3, oy + 3, light(col, 0.3))
        if i % 2:
            c.vline(ox + 6, oy + 6, oy + 7, hexc("8a8478"))
            L.emit(ox + 6, oy + 5, col, 200)
    elif kind == "books":
        cols = [hexc("5a2a30"), hexc("2a3a5a"), hexc("5a4a24")]
        for k in range(3):
            c.rect(ox + 1 + k * 2, oy + 3 + k % 2, 2, 5 - k % 2, cols[(k + i) % 3])
        if i % 2:
            L.emit(ox + 6, oy + 2, glow, 200)
    elif kind == "spikes":
        for x in (1, 4):
            c.vline(ox + x, oy + 2, oy + 7, hexc("4a3024"))
            c.set(ox + x, oy + 1, hexc("a89a88"))
        if i % 2:
            L.emit(ox + 6, oy + 7, glow, 200)
            L.emit(ox + 6, oy + 6, dark(glow, 0.7), 150)
    elif kind == "rocks":
        rc = mix(P["rock"], P["rim"], 0.35)
        c.rows(ox + 2, oy + 5, [3, 4, 5], rc)
        c.hline(ox + 3, ox + 5, oy + 5, P["top_hi"])
    else:
        c.set(ox + 3, oy + 7, P["rim"])


def _hang(L, ox, oy, kind, i, P):
    """Decoração pendurada no teto (topo do tile)."""
    c = L.c
    glow = P["glow"]
    if kind == "roots":
        col = mix(P["rock"], P["rim"], 0.3)
        c.vline(ox + 2 + i, oy, oy + 3 + i % 3, col)
        c.set(ox + 3 + i, oy + 4 + i % 3, col)
        if i % 2:
            L.emit(ox + 3 + i, oy + 5 + i % 3, glow, 200)
    elif kind == "vines":
        col = P["top_c"] if P["top"] in ("grass", "moss") else hexc("24402e")
        for y in range(3 + i % 4):
            c.set(ox + 3 + (y % 2), oy + y, col)
        L.emit(ox + 5, oy + 2, P["glow2"] if i % 2 else glow, 210)
    elif kind == "chains":
        col = mix(P["rock"], P["rim"], 0.5)
        for y in range(0, 6 + i % 2, 2):
            c.set(ox + 4, oy + y, col)
            c.set(ox + 4, oy + y + 1, dark(col, 0.6))
        if i == 1:
            c.rect(ox + 3, oy + 6, 3, 2, hexc("141420"))
            L.emit(ox + 4, oy + 7, P["warm"])
    elif kind == "webs":
        col = (170, 170, 190, 110)
        c.line(ox, oy, ox + 5, oy + 5, col)
        c.line(ox, oy + 3, ox + 3, oy, col)
        if i % 2:
            L.emit(ox + 3, oy + 3, P["glow2"], 140)
    elif kind == "stalactites":
        col = mix(P["rock"], P["rim"], 0.25)
        c.rows(ox + 2, oy, [4, 3, 2, 1][: 3 + i % 2], col)
        L.emit(ox + 3, oy + 2 + i % 2, glow if i % 2 else P["glow2"], 230)
    elif kind == "icicles":
        ic = hexc("a8c0e0")
        c.rows(ox + 2, oy, [3, 2, 1], ic)
        c.rows(ox + 5, oy, [2, 1][: 1 + i % 2], ic)
        L.emit(ox + 3, oy + 2, P["glow2"], 140)
    elif kind == "banners":
        col = [hexc("5a1e2a"), hexc("1e2a5a"), hexc("5a4818"), hexc("1e4a3a")][i % 4]
        c.rect(ox + 2, oy, 4, 6, col)
        c.set(ox + 3, oy + 6, col)
        c.vline(ox + 2, oy, oy + 5, light(col, 0.15))
        L.emit(ox + 4, oy + 3, P["glow2"] if P.get("glow2") else glow, 190)


def _backwall(L, ox, oy, P, k):
    """Parede de fundo (salas fechadas): mais clara que a rocha funda, bem
    menos contrastada que o terreno. k = 0..3 comuns, 4..7 especiais."""
    c = L.c
    back = P["back"]
    jd = dark(back, 0.78)
    c.rect(ox, oy, 8, 8, back)
    if k == 0:
        return
    if k in (1, 2, 3):
        if P["style"] in ("brick", "sand", "marble", "wood"):
            c.hline(ox, ox + 7, oy + 7, jd)
            c.vline(ox + (2 if k % 2 else 6), oy + 4, oy + 6, jd)
            if k == 3:
                c.hline(ox, ox + 7, oy + 3, jd)
        else:
            c.set(ox + 2 + k, oy + 3, jd)
            c.set(ox + 5, oy + 6 - k % 2, jd)
        return
    if k == 4:
        # janelinha acesa em arco
        fr = dark(back, 0.55)
        c.rect(ox + 2, oy + 2, 4, 6, fr)
        warm = P["warm"] if not P.get("stained") else P["glow2"]
        for y in range(3, 7):
            for x in range(3, 5):
                L.emit(ox + x, oy + y, mix(warm, (255, 255, 255, 255), 0.15) if y > 3 else warm, 150)
        c.set(ox + 2, oy + 2, back)
        c.set(ox + 5, oy + 2, back)
        c.hline(ox + 2, ox + 5, oy + 7, light(back, 0.1))
    elif k == 5:
        # runa entalhada que brilha fraco
        rc = P["glow"] if not P.get("runes") else P["glow"]
        for (x, y) in [(3, 1), (4, 2), (3, 3), (4, 4), (3, 5), (2, 3), (5, 3)]:
            L.emit(ox + x, oy + y, dark(rc, 0.75), 120)
    elif k == 6:
        # nicho com vela
        c.rect(ox + 2, oy + 2, 4, 5, dark(back, 0.5))
        c.vline(ox + 4, oy + 5, oy + 6, hexc("c8bca0"))
        L.emit(ox + 4, oy + 4, P["warm"])
        L.emit_soft(ox + 3, oy + 4, P["warm"], 90)
        L.emit_soft(ox + 5, oy + 4, P["warm"], 90)
    elif k == 7:
        # rachadura com luz vazando
        for (x, y) in [(1, 0), (2, 1), (2, 2), (3, 3), (4, 4), (4, 5), (5, 6), (6, 7)]:
            c.set(ox + x, oy + y, jd)
        L.emit(ox + 3, oy + 3, dark(P["glow"], 0.7), 110)


def _big_glow(L, ox, oy, P, k):
    """Decorações de chão que iluminam (linha 6, colunas 4-7): lanterna,
    cristal, cogumelo grande e flor-lume. Usadas com parcimônia."""
    c = L.c
    glow, glow2, warm = P["glow"], P["glow2"], P["warm"]
    if k == 0:  # lanterna de pedra
        st = mix(P["rock"], P["rim"], 0.5)
        c.rect(ox + 2, oy + 5, 4, 3, st)
        c.rect(ox + 3, oy + 2, 2, 3, dark(st, 0.5))
        c.hline(ox + 2, ox + 5, oy + 1, st)
        L.emit(ox + 3, oy + 3, warm)
        L.emit(ox + 4, oy + 3, light(warm, 0.35))
        L.emit(ox + 3, oy + 4, dark(warm, 0.85), 220)
        L.emit(ox + 4, oy + 4, warm, 230)
    elif k == 1:  # cristal
        L.emit(ox + 3, oy + 2, light(glow, 0.4))
        for y in range(3, 8):
            L.emit(ox + 3, oy + y, glow, 230)
            L.emit(ox + 4, oy + y, dark(glow, 0.7), 200)
        L.emit(ox + 5, oy + 5, glow2, 220)
        L.emit(ox + 5, oy + 6, dark(glow2, 0.7), 200)
        L.emit(ox + 5, oy + 7, dark(glow2, 0.7), 200)
        L.emit(ox + 2, oy + 6, dark(glow, 0.6), 180)
        L.emit(ox + 2, oy + 7, dark(glow, 0.6), 180)
    elif k == 2:  # cogumelo grande
        c.vline(ox + 3, oy + 4, oy + 7, hexc("8a8478"))
        c.vline(ox + 4, oy + 4, oy + 7, hexc("5a564e"))
        for x in range(1, 7):
            L.emit(ox + x, oy + 3, dark(glow, 0.8), 230)
        for x in range(2, 6):
            L.emit(ox + x, oy + 2, glow)
        L.emit(ox + 3, oy + 1, light(glow, 0.4))
        L.emit(ox + 4, oy + 1, glow, 230)
    elif k == 3:  # flor-lume
        g = P["top_c"] if P["top"] in ("grass", "moss") else hexc("24402e")
        c.vline(ox + 4, oy + 3, oy + 7, g)
        c.set(ox + 3, oy + 6, g)
        c.set(ox + 5, oy + 5, g)
        L.emit(ox + 4, oy + 2, light(glow2, 0.5))
        L.emit(ox + 3, oy + 2, glow2, 220)
        L.emit(ox + 5, oy + 2, glow2, 220)
        L.emit(ox + 4, oy + 1, glow2, 220)
        L.emit(ox + 4, oy + 3, dark(glow2, 0.7), 200)


def tileset(biome_id):
    """Devolve Lit (arte + brilho) do atlas 64x64."""
    P = _prep(BIOMES[biome_id])
    L = Lit(64, 64)
    c = L.c
    for m in range(16):
        _tile(L, (m % 8) * 8, (m // 8) * 8, m, P, m % 4)
    for v in range(4):
        _tile(L, v * 8, 16, 15, P, v, base_d=9)
    # cantos internos (sobreposição): 2 px de luz na quina
    rim = mix(P["rock"], P["rim"], 0.55)
    for k, (cx, cy) in enumerate(((0, 0), (7, 0), (0, 7), (7, 7))):
        ox = 32 + k * 8
        c.set(ox + cx, 16 + cy, rim)
        c.set(ox + (1 if cx == 0 else 6), 16 + cy, dark(rim, 0.8))
        c.set(ox + cx, 16 + (1 if cy == 0 else 6), dark(rim, 0.8))
    # plataformas one-way: tábua/laje escura com topo claro
    plank = mix(P["rock"], P["rim"], 0.4)
    for k in range(4):
        ox = k * 8
        c.hline(ox, ox + 7, 24, light(P["rim"], 0.15))
        c.hline(ox, ox + 7, 25, plank)
        c.hline(ox, ox + 7, 26, dark(plank, 0.55))
        if k in (0, 3):
            c.vline(ox, 24, 26, dark(plank, 0.45))
            c.set(ox + 1, 27, dark(plank, 0.45))
        if k in (2, 3):
            c.vline(ox + 7, 24, 26, dark(plank, 0.45))
            c.set(ox + 6, 27, dark(plank, 0.45))
    # espinhos: CLAROS (perigo precisa ler bem no escuro), pontas com brilho fraco
    sp = hexc("d8d4e8")
    for x in (0, 4):
        L.emit(32 + x + 1, 27, sp, 120)
        c.set(32 + x + 2, 27, dark(sp, 0.7))
        c.hline(32 + x + 1, 32 + x + 2, 28, sp)
        c.set(32 + x + 2, 28, dark(sp, 0.75))
        c.hline(32 + x, 32 + x + 3, 29, dark(sp, 0.85))
        c.set(32 + x + 3, 29, dark(sp, 0.6))
    c.hline(32, 39, 30, dark(sp, 0.5))
    c.hline(32, 39, 31, dark(sp, 0.32))
    # quebrável: bloco com rachaduras que vazam luz quente
    _tile(L, 40, 24, 0, P, 1)
    for (x, y) in [(42, 25), (43, 26), (44, 27), (44, 28), (43, 29), (43, 30), (45, 28), (46, 27)]:
        L.emit(x, y, P["warm"], 170)
    # piso rachado (só quebra com queda esmagadora)
    _tile(L, 48, 24, 2 | 8, P, 2)
    for (x, y) in [(50, 26), (51, 27), (52, 28), (53, 29), (54, 28), (55, 27)]:
        L.emit(x, y, dark(P["warm"], 0.7), 130)
    # parede de fundo: 0 em (7,3); 1-3 em (0..2,4); especiais 4-7 em (4..7,5)
    _backwall(L, 56, 24, P, 0)
    for k in range(1, 4):
        _backwall(L, (k - 1) * 8, 32, P, k)
    for k in range(4, 8):
        _backwall(L, 32 + (k - 4) * 8, 40, P, k)
    for k in range(5):
        _deco(L, 24 + k * 8, 32, P["deco"], k, P)
    for k in range(4):
        _hang(L, k * 8, 40, P["hang"], k, P)
    # rocha funda (sem textura) e muito funda (quase preto)
    for k in range(2):
        _tile(L, k * 8, 48, 15, P, k, base_d=16)
        _tile(L, 16 + k * 8, 48, 15, P, k + 2, base_d=26)
    for k in range(4):
        _big_glow(L, 32 + k * 8, 48, P, k)
    return L


# ---------------------------------------------------------------------------
# Fundos parallax (320x180, repetem na horizontal) — névoa em camadas
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


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def _dither(x, y, t, steps=6):
    """Quantiza t (0..1) em degraus com dither ordenado 4x4."""
    q = t * steps
    base = int(q)
    frac = q - base
    th = (BAYER4[y % 4][x % 4] + 0.5) / 16.0
    return min(base + (1 if frac > th else 0), steps) / steps


def sky(P, L):
    c = L.c
    cols = [hexc(h) for h in P["sky"]]
    for y in range(BH):
        for x in range(BW):
            if y < 90:
                t = _dither(x, y, (y / 90.0) ** 1.3)
                col = mix(cols[0], cols[1], t)
            else:
                t = _dither(x, y, (y - 90) / 90.0)
                col = mix(cols[1], cols[2], t)
            c.set(x, y, col)
    r = random.Random(7)
    if P.get("stars"):
        for i in range(90):
            x, y = r.randrange(BW), r.randrange(110)
            k = r.random()
            col = mix(cols[1], hexc("ffffff"), 0.45 + k * 0.5)
            if k > 0.85:
                L.emit(x, y, col, 200)
            else:
                c.set(x, y, col)
    if P.get("aurora"):
        a1, a2 = hexc(P["glow"]), hexc(P.get("glow2", P["glow"]))
        for x in range(BW):
            yc = 40 + 14 * _periodic(x, [(1, 0.6), (3, 0.3), (5, 0.1)], "aur")
            for y in range(int(yc) - 14, int(yc) + 4):
                t = 1.0 - abs(y - yc + 5) / 10.0
                if t <= 0:
                    continue
                col = mix(a1, a2, 0.5 + 0.5 * math.sin(x * 0.05))
                k = int(t * 3) / 3.0
                if k > 0:
                    c.set(x, y, mix(c.get(x, y), col, 0.16 * k))
                    if k >= 0.99 and (x + y) % 2 == 0:
                        L.g.set(x, y, alpha(col, 22))
    if P.get("moon"):
        mx, my = 250, 36
        rr = 13 if P.get("bigmoon") else 9
        # halo em anéis nítidos (pixel art), cada anel um pouco mais fraco
        rings = [0.26, 0.16, 0.09, 0.04]
        for y in range(my - rr * 4, my + rr * 4):
            for x in range(mx - rr * 4, mx + rr * 4):
                d = math.hypot(x - mx, y - my)
                if d <= rr:
                    continue
                band = int((d - rr) / (rr * 0.55))
                if band < len(rings):
                    c.set(x, y, mix(c.get(x, y), hexc("b8c4ff"), rings[band]))
        moon = hexc("eeeadc")
        c.ellipse(mx, my, rr, rr, moon)
        for y in range(my - rr - 1, my + rr + 2):
            for x in range(mx - rr - 1, mx + rr + 2):
                if c.get(x, y) == moon:
                    L.g.set(x, y, alpha(moon, 55))
        # mares escuras
        for (dx, dy, rad) in [(-3, -2, 3), (3, 3, 2), (-1, 5, 2)]:
            c.ellipse(mx + dx * rr // 9, my + dy * rr // 9, rad * rr // 9, rad * rr // 9, hexc("c8c2b4"))
    if P.get("sun"):
        # sol poente atrás das montanhas: faixa quente no horizonte
        warm = hexc(P["warm"])
        for y in range(110, BH):
            for x in range(BW):
                t = ((y - 110) / 70.0) * (0.55 + 0.45 * math.cos((x - 200) / BW * math.tau))
                if _dither(x, y, t * 0.6, 6) > 0:
                    c.set(x, y, mix(c.get(x, y), warm, _dither(x, y, t * 0.6, 6)))
        sun = light(warm, 0.35)
        c.ellipse(200, 158, 10, 10, sun)
        for y in range(146, 170):
            for x in range(188, 213):
                if c.get(x, y) == sun:
                    L.g.set(x, y, alpha(sun, 110))
    if P.get("indoor"):
        # teto que some no escuro + manchas de luz
        for y in range(BH):
            for x in range(BW):
                if y < 30:
                    c.set(x, y, mix(c.get(x, y), hexc(P["sky"][0]), _dither(x, y, 1 - y / 30.0, 4)))
    return c


def _fog_band(c, y0, y1, col, strength):
    """Faixa de névoa com dither (mais densa embaixo)."""
    for y in range(max(0, y0), min(BH, y1)):
        t = (y - y0) / max(1, (y1 - y0)) * strength
        for x in range(BW):
            k = _dither(x, y, t, 5)
            if k > 0:
                cur = c.get(x, y)
                if cur[3] == 0:
                    continue
                c.set(x, y, mix(cur, col, k))


def _silhouette(L, kind, col, seed, base_y, height, P, depth):
    """depth: 0 longe, 1 meio, 2 perto. Luzes (janelas, cristais) vão pro brilho."""
    c = L.c
    r = random.Random(seed)
    lt = light(col, 0.1)
    rim = mix(col, hexc(P["rim"]), 0.25 if depth < 2 else 0.12)
    glow, glow2, warm = hexc(P["glow"]), hexc(P.get("glow2", P["glow"])), hexc(P["warm"])

    def rim_top(x, top):
        c.set(x, top, rim)

    if kind in ("mountains", "hills", "dunes", "dunes_near"):
        parts = {"mountains": [(2, 0.5), (5, 0.3), (11, 0.15), (23, 0.06)],
                 "hills": [(2, 0.5), (3, 0.3), (7, 0.12)], "dunes": [(1, 0.5), (3, 0.35), (4, 0.1)],
                 "dunes_near": [(2, 0.5), (5, 0.3)]}[kind]
        for x in range(BW):
            h = height * (0.55 + 0.45 * _periodic(x, parts, seed))
            top = int(base_y - h)
            c.vline(x, top, BH - 1, col)
            rim_top(x, top)
        if depth == 0 and kind == "mountains":
            for x in range(BW):
                h = height * (0.55 + 0.45 * _periodic(x, parts, seed))
                top = int(base_y - h)
                if top < base_y - height * 0.8:
                    c.set(x, top + 1, lt)
    elif kind in ("clouds", "clouds_near"):
        for i in range(10):
            cx = i * 32 + r.randrange(10)
            cy = base_y - r.randrange(int(height))
            for k in range(4):
                for dx in (0, BW, -BW):
                    c.ellipse(cx + k * 7 - 10 + dx, cy - (k % 2) * 4, 9, 6, col)
        c.rect(0, base_y, BW, BH - base_y, col)
        for x in range(BW):
            for y in range(BH):
                if c.get(x, y) == col and c.get(x, y - 1)[3] == 0:
                    c.set(x, y, rim)
    elif kind == "canopy":
        # árvores de copa redonda (Ori): tronco + 3-4 bolhas, borda de luz em cima
        c.rect(0, base_y, BW, BH - base_y, col)
        x = r.randrange(20)
        while x < BW + 20:
            h = int(height * (0.7 + 0.5 * r.random()))
            tw = 3 + r.randrange(3)
            for dx in (0, BW, -BW):
                xx = x + dx
                c.rect(xx, base_y - h, tw, h, col)
                for k in range(4):
                    ex = xx + tw // 2 + (k - 1.5) * 7 + r.randrange(-2, 3)
                    ey = base_y - h - 4 - (k % 2) * 5
                    c.ellipse(ex, ey, 9 + r.randrange(3), 7, col)
            x += 34 + r.randrange(26)
        for x in range(BW):
            for y in range(1, BH):
                if c.get(x, y) == col and c.get(x, y - 1)[3] == 0:
                    c.set(x, y, rim)
        for i in range(22):
            x, y = r.randrange(BW), base_y - r.randrange(int(height * 1.3))
            if c.get(x, y)[3]:
                L.emit(x, y, glow if i % 3 else glow2, 210)
    elif kind in ("trees", "deadtrees", "trunks", "pines", "reeds_near", "stakes"):
        if kind not in ("trunks",):
            c.rect(0, base_y, BW, BH - base_y, col)
        x = 0
        while x < BW:
            h = int(height * (0.6 + 0.4 * r.random()))
            for dx in (0, BW, -BW):
                xx = x + dx
                if kind == "trees":
                    for y in range(h):
                        w = int((y / h) * 8) + 1
                        c.hline(xx - w, xx + w, base_y - h + y, col)
                    c.vline(xx, base_y - h - 2, base_y - h, col)
                elif kind == "pines":
                    for y in range(h):
                        w = int((y / h) * 6) + (y % 4 == 0)
                        c.hline(xx - w, xx + w, base_y - h + y, col)
                elif kind == "trunks":
                    w = 6 + (x * 7) % 9
                    lean = ((x * 13) % 5) - 2
                    for y in range(BH):
                        ox2 = xx + int(lean * (1 - y / BH) * 3)
                        c.hline(ox2, ox2 + w, y, col)
                        c.set(ox2 + w, y, rim)
                    for k in range(4):
                        c.line(xx + w // 2, BH - 22 + k * 3, xx - 5 - k * 3, BH - 1, col)
                        c.line(xx + w // 2, BH - 22 + k * 3, xx + w + 5 + k * 3, BH - 1, col)
                    # galho com folhas e musgo luminoso
                    by = 30 + (x * 11) % 60
                    c.line(xx + w, by, xx + w + 14, by - 8, col)
                    c.ellipse(xx + w + 16, by - 10, 7, 4, col)
                    for k in range(3):
                        L.emit(xx + 1 + k * 2, by + 12 + k * 9, glow if k % 2 else glow2, 200)
                elif kind == "reeds_near":
                    for k in range(5):
                        c.line(xx + k * 2, base_y, xx + k * 2 + (k % 3) - 1, base_y - h + k * 3, col)
                    c.rect(xx + 2, base_y - h, 2, 4, col)
                elif kind == "stakes":
                    c.rect(xx, base_y - h, 3, h, col)
                    c.set(xx + 1, base_y - h - 1, col)
                else:
                    c.vline(xx, base_y - h, base_y, col)
                    c.vline(xx + 1, base_y - h // 2, base_y, col)
                    c.line(xx, base_y - h // 2, xx + 6, base_y - h // 2 - 6, col)
                    c.line(xx, base_y - h // 3 * 2, xx - 5, base_y - h + 2, col)
                    c.line(xx + 6, base_y - h // 2 - 6, xx + 9, base_y - h // 2 - 5, col)
            x += (9 if kind != "trunks" else 110) + r.randrange(10 if kind != "trunks" else 60)
        # espíritos da floresta (luzinhas penduradas nas copas)
        if P.get("spirit") and depth >= 1:
            for i in range(14):
                x, y = r.randrange(BW), base_y - r.randrange(int(height))
                if c.get(x, y)[3]:
                    L.emit(x, y, glow if i % 3 else glow2, 200)
    elif kind in ("city", "towers", "houses", "spires", "magetowers", "magetowers2", "ruins", "mesas", "tents",
                  "palisade", "graves", "fence"):
        c.rect(0, base_y, BW, BH - base_y, col)
        x = 0
        while x < BW:
            if kind == "graves":
                w = 5 + r.randrange(4)
                h = 6 + r.randrange(7)
                c.rect(x, base_y - h, w, h, col)
                c.hline(x, x + w - 1, base_y - h, rim)
                if r.random() < 0.4:
                    c.vline(x + w // 2, base_y - h - 5, base_y - h, col)
                    c.hline(x + w // 2 - 2, x + w // 2 + 2, base_y - h - 3, col)
                if r.random() < 0.25:
                    L.emit(x + w // 2, base_y - h - 7 - r.randrange(4), glow, 200)
                x += w + 4 + r.randrange(10)
                continue
            if kind == "fence":
                for k in range(0, BW, 4):
                    c.vline(k, base_y - 14, base_y, col)
                    c.set(k, base_y - 15, rim)
                c.hline(0, BW - 1, base_y - 10, col)
                c.hline(0, BW - 1, base_y - 4, col)
                for k in range(3):
                    lx = 40 + k * 110
                    c.vline(lx, base_y - 34, base_y, col)
                    c.rect(lx - 2, base_y - 38, 5, 4, col)
                    L.emit(lx, base_y - 36, warm)
                    L.emit(lx - 1, base_y - 36, dark(warm, 0.8), 200)
                    L.emit(lx + 1, base_y - 36, dark(warm, 0.8), 200)
                break
            if kind == "tents":
                w = 18 + r.randrange(10)
                h = 12 + r.randrange(8)
                for y in range(h):
                    ww = int(w * y / h / 2)
                    c.hline(x + w // 2 - ww, x + w // 2 + ww, base_y - h + y, col)
                c.vline(x + w // 2, base_y - h - 5, base_y - h, col)
                # porta iluminada
                for y in range(4):
                    L.emit(x + w // 2, base_y - 1 - y, warm, 220 - y * 30)
                if r.random() < 0.5:
                    L.emit(x + w + 3, base_y - 2, warm)
                    L.emit(x + w + 3, base_y - 3, light(warm, 0.4), 200)
                x += w + 6 + r.randrange(14)
                continue
            if kind == "palisade":
                for k in range(0, BW, 5):
                    h = height * 0.5 + (k * 7 % 5)
                    c.rect(k, int(base_y - h), 4, int(h), col)
                    c.set(k + 1, int(base_y - h) - 1, col)
                    c.set(k + 2, int(base_y - h) - 1, col)
                    c.set(k + 1, int(base_y - h), rim)
                for k in range(4):
                    bx = 30 + k * 80
                    for y in range(6):
                        L.emit(bx + (y % 2), int(base_y - height * 0.5) - 2 - y, glow if y < 3 else warm, 230 - y * 25)
                break
            if kind == "mesas":
                w = 30 + r.randrange(30)
                h = int(height * (0.4 + 0.6 * r.random()))
                c.rows(x, base_y - h, [w - 6, w - 4] + [w] * (h - 2), col)
                c.hline(x + 3, x + w - 4, base_y - h, rim)
                x += w + 10 + r.randrange(30)
                continue
            w = 8 + r.randrange(12)
            h = int(height * (0.35 + 0.65 * r.random()))
            if kind in ("spires", "magetowers", "magetowers2"):
                w = 6 + r.randrange(6)
                h = int(height * (0.5 + 0.5 * r.random()))
            c.rect(x, base_y - h, w, h, col)
            c.vline(x, base_y - h, base_y, rim)
            if kind in ("towers", "spires", "magetowers", "magetowers2"):
                for k in range(w // 2 + 3):
                    c.hline(x + k - 1, x + w - k, base_y - h - k, col)
                if kind.startswith("magetowers"):
                    L.emit(x + w // 2, base_y - h - w // 2 - 3, glow)
                    L.emit(x + w // 2, base_y - h - w // 2 - 4, light(glow, 0.4), 200)
                if kind == "spires":
                    L.emit(x + w // 2, base_y - h - w // 2 - 2, glow2, 220)
            elif kind == "ruins":
                for k in range(w):
                    if r.random() < 0.5:
                        c.set(x + k, base_y - h - 1, col)
                if r.random() < 0.5:
                    c.rect(x + 2, base_y - h + 3, max(w - 4, 2), 4, CLEAR)
                if r.random() < 0.3:
                    L.emit(x + w // 2, base_y - h - 3, glow2, 180)
            else:
                c.hline(x - 1, x + w, base_y - h, col)
            if kind in ("city", "houses", "towers", "magetowers", "magetowers2"):
                wc = warm if not kind.startswith("mage") else glow
                for k in range(1 + r.randrange(3 if depth else 2)):
                    wx = x + 2 + r.randrange(max(w - 4, 1))
                    wy = base_y - h + 4 + r.randrange(max(h - 8, 1))
                    L.emit(wx, wy, wc, 220 if depth else 150)
                    L.emit(wx, wy + 1, dark(wc, 0.8), 200 if depth else 130)
            x += w + r.randrange(6)
    elif kind in ("hall", "arches", "niches", "columns", "pillars"):
        if kind == "hall":
            c.rect(0, 0, BW, BH, col)
            # janelas altas: vitral (castelo) ou luar frio
            lead = dark(col, 0.6)
            panes = [hexc(P.get("glow2", P["glow"])), glow, hexc("c8506a"), hexc("5ac8a0")]
            for i in range(4):
                x = i * 80 + 30
                for y in range(28, 112):
                    for xx in range(x, x + 20):
                        inside = y >= 40 or math.hypot(xx - (x + 9.5), y - 40) <= 10.5
                        if not inside:
                            continue
                        lx, ly = (xx - x) % 5, (y - 28) % 7
                        if P.get("stained"):
                            if lx == 0 or ly == 0:
                                c.set(xx, y, lead)
                                continue
                            k = ((xx - x) // 5 * 3 + (y - 28) // 7 * 5 + i) % 7
                            pc = panes[k % 4]
                            fade = 1.0 - (y - 28) / 84.0 * 0.55
                            pc2 = mix(col, pc, 0.62 * fade)
                            c.set(xx, y, pc2)
                            if ly in (2, 3) and lx in (2, 3):
                                L.g.set(xx, y, alpha(pc, int(90 * fade)))
                        else:
                            wc = light(col, 0.3)
                            c.set(xx, y, mix(col, wc, 0.6 - (y - 28) / 84.0 * 0.4))
                c.vline(x + 10, 28, 112, col)
                c.hline(x, x + 19, 112, light(col, 0.12))
                c.rect(x - 2, 112, 24, 2, light(col, 0.08))
        elif kind == "arches":
            for i in range(5):
                x = i * 64
                c.rect(x, 0, 14, BH, col)
                c.vline(x + 13, 0, BH, rim)
                for k in range(26):
                    yy = int(24 * math.sqrt(max(0.0, 1 - ((k - 25) / 25) ** 2)))
                    c.vline(x + 14 + k, 0, 40 - yy, col)
                    c.vline(x + 64 - k - 1, 0, 40 - yy, col)
                if P.get("candles") or P.get("indoor"):
                    L.emit(x + 7, 100, warm)
                    L.emit(x + 7, 99, light(warm, 0.4), 200)
                    c.vline(x + 7, 101, 104, hexc("8a806a"))
            c.rect(0, 150, BW, 30, col)
            c.hline(0, BW - 1, 150, rim)
        elif kind == "niches":
            c.rect(0, 0, BW, BH, col)
            cut = dark(col, 0.55)
            for i in range(8):
                for j in range(3):
                    c.rect(i * 40 + 8, 30 + j * 40, 22, 14, cut)
                    c.rect(i * 40 + 12, 38 + j * 40, 6, 4, hexc("5a5244"))
                    if (i + j) % 3 == 0:
                        L.emit(i * 40 + 24, 38 + j * 40, warm, 200)
                        L.emit(i * 40 + 24, 37 + j * 40, light(warm, 0.4), 150)
        elif kind == "columns":
            c.rect(0, 0, BW, BH, col)
            for i in range(5):
                x = i * 64 + 10
                cc = light(col, 0.08)
                c.rect(x, 20, 12, 140, cc)
                c.vline(x, 20, 160, mix(cc, hexc(P["rim"]), 0.3))
                c.rect(x - 2, 18, 16, 4, light(col, 0.14))
                c.rect(x - 2, 156, 16, 4, light(col, 0.14))
                # braseiro dourado
                L.emit(x + 5, 16, warm)
                L.emit(x + 6, 15, light(warm, 0.4), 220)
                L.emit(x + 4, 15, dark(warm, 0.8), 200)
        elif kind == "pillars":
            x = 0
            while x < BW:
                w = 10 + r.randrange(8)
                c.rect(x, 0, w, BH, col)
                c.vline(x + w - 1, 0, BH, rim)
                c.rect(x - 2, BH - 10, w + 4, 10, col)
                c.rect(x - 2, 0, w + 4, 8, col)
                x += w + 50 + r.randrange(50)
    elif kind in ("cave", "cave2", "stalagmites"):
        for x in range(BW):
            top = int(18 + 14 * (0.5 + 0.5 * _periodic(x, [(3, 0.5), (8, 0.3), (17, 0.2)], seed)))
            bot = int(BH - 20 - 16 * (0.5 + 0.5 * _periodic(x, [(4, 0.5), (9, 0.3), (19, 0.2)], str(seed) + "b")))
            if kind == "cave2":
                top += 20
                bot -= 10
            if kind == "stalagmites":
                top = 6 + (top - 18) // 2
                bot = BH - 12 - (BH - bot) // 3
            c.vline(x, 0, top, col)
            c.vline(x, bot, BH - 1, col)
            c.set(x, bot, rim)
            c.set(x, top, dark(rim, 0.8))
        n = 10 if kind != "stalagmites" else 6
        for i in range(n):
            x = r.randrange(BW)
            if kind == "stalagmites":
                hh = 20 + r.randrange(30)
                for y in range(hh):
                    w = max(1, int((y / hh) * 5))
                    c.hline(x - w, x + w, BH - 12 - hh + y, col)
            else:
                c.rows(x, 30, [5, 4, 3, 2, 1], col)
        if P.get("crystals"):
            for i in range(12 if depth else 18):
                x = r.randrange(BW)
                y = r.randrange(40, BH - 20)
                if c.get(x, y)[3] == 0:
                    continue
                col_g = glow if i % 3 else glow2
                for k in range(2 + r.randrange(3)):
                    L.emit(x, y - k, col_g if k else light(col_g, 0.3), 220 if depth else 140)
    if P.get("wisps") and depth == 1:
        for i in range(6):
            x, y = r.randrange(BW), base_y - 10 - r.randrange(30)
            L.emit(x, y, glow, 220)
            L.emit_soft(x + 1, y, glow, 80)
            L.emit_soft(x - 1, y, glow, 80)
            L.emit_soft(x, y - 1, glow, 80)


def background(biome_id):
    """Camadas: 0_sky, 1_far, 2_mid, 3_near (+ _glow de cada uma).
    Devolve {nome: Canvas} incluindo os '<nome>_glow'."""
    P = BIOMES[biome_id]
    Q = dict(P)
    haze = hexc(P["haze"])
    out = {}
    S = Lit(BW, BH)
    sky(P, S)
    out["0_sky"], out["0_sky_glow"] = S.c, S.g
    fk, fcol = P["far"]
    F = Lit(BW, BH)
    _silhouette(F, fk, hexc(fcol), biome_id + "far", 150, 64, Q, 0)
    _fog_band(F.c, 118, 180, haze, 0.55)
    out["1_far"], out["1_far_glow"] = F.c, F.g
    mk, mcol = P["mid"]
    M = Lit(BW, BH)
    _silhouette(M, mk, hexc(mcol), biome_id + "mid", 166, 52, Q, 1)
    _fog_band(M.c, 150, 180, haze, 0.3)
    out["2_mid"], out["2_mid_glow"] = M.c, M.g
    nk, ncol = P["near"]
    N = Lit(BW, BH)
    _silhouette(N, nk, hexc(ncol), biome_id + "near", 178, 44, Q, 2)
    out["3_near"], out["3_near_glow"] = N.c, N.g
    return out
