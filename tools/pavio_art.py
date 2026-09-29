"""Pavio: velinha viva de cera, com uma chama na cabeça, poncho azul-petróleo
e cachecol (procedural). Quadros 16x16 olhando para a direita, pés na linha
15, corpo centrado entre as colunas 7 e 8 (espelha certinho).

Os OLHOS, as BOCHECHAS e a CHAMA não fazem parte do quadro: o jogo desenha
por cima usando as âncoras
  "eye"   x do olho de trás, y do topo dos olhos (o da frente fica em x+3);
  "flame" base da chama (logo acima do pavio);
  "neck"  onde o cachecol se prende;
  "hand"  onde a lâmina aparece;
  "cheeks" pixels das bochechas rosadas (só os que caem na cera);
  "collar" [x0, x1, y] da gola, onde o jogo desenha a volta do cachecol.

O corpo é uma vela de 8 px de largura com a borda de cima derretida (poça
clara e um pingo escorrendo na frente), o rosto na cera e um poncho curto
com barra costurada.
"""
from px import Canvas, hexc

OUT = hexc("1b1528")
WAX = hexc("f6e8c8")
WAX_SH = hexc("d9bd92")
WAX_DEEP = hexc("bf9f78")
WAX_HI = hexc("fffaf0")
PON = hexc("2f7f86")
PON_SH = hexc("215a61")
PON_HI = hexc("5cb8b2")
WICK = hexc("3a2a22")
FOOT = hexc("4a3128")

W = 16
H = 16


def pavio(x, top, wax, poncho, legs, lean=None, poff=None, drip=True, rim=6, w=8, wick_dx=0):
    """x = coluna esquerda do corpo; top = linha da borda derretida;
    wax = quantas linhas de cera (contando a borda);
    poncho = lista de larguras, começando na última linha de cera;
    lean = deslocamento x por linha de cera; poff = deslocamento x por linha do poncho.
    Retorna (Canvas, coluna do pavio, linha do pavio)."""
    c = Canvas(W, H)
    lean = lean or [0] * wax
    poff = poff or [0] * len(poncho)
    edges = []
    for i in range(wax):
        ww = rim if i == 0 else w
        x0 = x + (w - ww) // 2 + lean[i]
        c.hline(x0, x0 + ww - 1, top + i, WAX)
        edges.append((x0, x0 + ww - 1))
    # borda derretida (poça clara) e sombreado: lado de trás mais escuro,
    # parte de baixo da cera um tom abaixo (a luz vem da chama, em cima)
    x0, x1 = edges[0]
    c.hline(x0 + 1, x1 - 1, top, WAX_HI)
    for i in range(1, wax):
        x0, x1 = edges[i]
        c.set(x0, top + i, WAX_SH)
        if i >= wax - 1:
            c.hline(x0 + 1, x1, top + i, WAX_SH)
            c.set(x0, top + i, WAX_DEEP)
    # brilho vertical na frente
    if wax >= 3:
        x0, x1 = edges[1]
        c.set(x1 - 1, top + 1, WAX_HI)
    # pingo de cera escorrendo pela frente, a partir da borda
    if drip and wax >= 4:
        x0, x1 = edges[1]
        c.set(x1, top + 1, WAX_HI)
        c.set(x1, top + 2, WAX_HI)
    # poncho: começa na última linha de cera e desce
    ps = top + wax - 1
    rows = []
    for i, pw in enumerate(poncho):
        px0 = x + (w - pw) // 2 + poff[i]
        c.hline(px0, px0 + pw - 1, ps + i, PON)
        rows.append((px0, px0 + pw - 1))
    if poncho:
        # gola clara, costura pontilhada no meio, barra escura
        px0, px1 = rows[0]
        c.hline(px0 + 1, px1 - 1, ps, PON_HI)
        if len(rows) >= 3:
            px0, px1 = rows[len(rows) // 2]
            for xx in range(px0 + 1, px1, 2):
                c.set(xx, ps + len(rows) // 2, PON_HI)
        px0, px1 = rows[-1]
        c.hline(px0, px1, ps + len(rows) - 1, PON_SH)
        c.set(rows[0][0], ps, PON_SH)
    c.outline(OUT)
    for p in legs:
        c.set(p[0], p[1], FOOT if p[1] >= 15 else OUT)
    wx = edges[0][0] + (edges[0][1] - edges[0][0] + 1) // 2 + wick_dx
    c.set(wx, top - 1, WICK)
    # volta do cachecol na gola (o jogo pinta com a cor dos dashes)
    c.collar = [rows[0][0] + 1, rows[0][1] - 1, ps] if poncho else []
    return c, wx, top - 1


def build():
    F = []

    def add(name, cv, eye, neck, hand=(12, 11), flame=None):
        c, wx, wy = cv
        fl = list(flame) if flame else [wx, wy - 1]
        # bochechas: logo abaixo e por fora dos olhos, só onde houver cera
        cheeks = []
        for dy in (2, 1):
            cheeks = []
            for cx, cy in ((eye[0] - 1, eye[1] + dy), (eye[0] + 4, eye[1] + dy)):
                if c.get(cx, cy)[:3] in (WAX[:3], WAX_SH[:3], WAX_HI[:3]):
                    cheeks.append([cx, cy])
            if len(cheeks) == 2:
                break
        F.append((name, c, {"eye": list(eye), "neck": list(neck), "hand": list(hand), "flame": fl, "cheeks": cheeks, "collar": c.collar}))

    STAND = [(6, 14), (6, 15), (9, 14), (9, 15)]
    PON = [10, 10, 9]

    # Layout base: pavio na linha 5, borda derretida na 6, cera até a 11,
    # poncho 11-13 e pés 14-15. Olhos nas linhas 8-9, bochechas na 10.
    # --- idle (respira: afunda 1 px e o poncho alarga) ---
    add("idle0", pavio(4, 6, 6, PON, STAND), (7, 8), (5, 11))
    add("idle1", pavio(4, 7, 5, [10, 11, 10], STAND), (7, 8), (5, 11))
    # --- corrida: corpo inclinado para a frente, poncho voando para trás ---
    run_legs = [
        [(6, 14), (5, 15), (9, 14), (10, 15)],
        [(6, 14), (6, 15), (9, 14), (9, 15)],
        [(7, 14), (7, 15), (9, 14), (10, 14)],
        [(9, 14), (10, 15), (6, 14), (5, 15)],
        [(9, 14), (9, 15), (6, 14), (6, 15)],
        [(8, 14), (8, 15), (6, 14), (5, 14)],
    ]
    bob = [0, -1, -1, 0, -1, -1]
    for i in range(6):
        t = 6 + bob[i]
        poff = [-1, -2, -2] if i % 3 else [-1, -2, -3]
        add("run%d" % i, pavio(4, t, 6, [10, 11, 10], run_legs[i], lean=[1, 1, 1, 1, 1, 0], poff=poff),
            (8, t + 2), (4, t + 5))
    # --- pulo: esticado, pernas juntas ---
    add("jump", pavio(4, 4, 7, [8, 9, 8], [(7, 14), (7, 15), (8, 14)]), (7, 6), (5, 9))
    # --- queda: poncho abre como paraquedas ---
    add("fall0", pavio(4, 5, 6, [12, 13, 11], [(6, 14), (6, 15), (9, 14)]), (7, 7), (4, 10))
    add("fall1", pavio(4, 5, 6, [12, 13, 11], [(6, 14), (9, 14), (9, 15)]), (7, 7), (4, 10))
    # --- dash: achatado e comprido (a chama deita para trás no jogo) ---
    add("dash", pavio(3, 8, 5, [11, 11, 10], [(2, 14), (3, 14)], lean=[2, 1, 1, 0, 0], poff=[-1, -1, -2], w=10, rim=7, drip=False),
        (8, 9), (4, 12), (13, 12))
    # --- parede (a parede fica à esquerda do quadro) ---
    add("wall", pavio(5, 6, 6, [9, 9, 8], [(11, 13), (12, 13), (8, 14), (8, 15)]), (8, 8), (6, 11))
    add("climb0", pavio(5, 5, 6, [9, 9, 8], [(11, 12), (12, 12), (8, 14), (8, 15)]), (8, 7), (6, 10))
    add("climb1", pavio(5, 6, 6, [9, 9, 8], [(11, 14), (12, 15), (8, 14)]), (8, 8), (6, 11))
    # --- agachado: baixinho e largo ---
    add("duck", pavio(3, 9, 4, [12, 12, 11], [(6, 15), (9, 15)], w=10, rim=8), (7, 10), (4, 12))
    # --- golpes (a lâmina é desenhada pelo jogo) ---
    add("slash0", pavio(3, 6, 6, [10, 11, 10], [(5, 14), (4, 15), (10, 14), (11, 15)], lean=[1, 1, 1, 0, 0, 0]), (6, 8), (4, 11), (12, 10))
    add("slash1", pavio(5, 6, 6, [10, 11, 10], [(6, 14), (5, 15), (11, 14), (12, 15)], lean=[-1, -1, 0, 0, 0, 0]), (8, 8), (6, 11), (13, 11))
    add("slash_up", pavio(4, 5, 7, PON, STAND), (7, 7), (5, 11), (9, 3))
    add("slash_down", pavio(4, 4, 6, [9, 9, 8], [(7, 12), (8, 12)]), (7, 6), (5, 8), (8, 14))
    # --- conjurar / focar ---
    add("cast", pavio(4, 6, 6, [11, 12, 11], [(6, 14), (5, 15), (9, 14), (10, 15)]), (7, 8), (4, 11), (13, 10))
    add("focus", pavio(4, 8, 5, [11, 11, 10], [(6, 14), (9, 14)]), (7, 9), (4, 12))
    # --- dano / morte (derrete numa poça) / sentado ---
    add("hurt", pavio(5, 6, 6, [10, 10, 9], [(7, 14), (6, 15), (11, 14), (12, 15)], lean=[-1, -1, -1, 0, 0, 0]), (7, 8), (6, 11))
    add("dead", pavio(2, 12, 3, [], [], drip=False, w=12, rim=8), (6, 13), (4, 14))
    add("sit", pavio(4, 8, 5, [11, 11, 10], [(10, 15), (11, 15)]), (7, 9), (4, 12))
    return F


# ---------------------------------------------------------------------------
# Mapa-múndi (visão de cima 3/4): frente, costas e lado, 4 passos cada
# ---------------------------------------------------------------------------

def _front(top, feet, back=False):
    """Pavio de frente (ou de costas): vela de 8 px, poncho simétrico."""
    c = Canvas(W, H)
    x0 = 4
    # cera
    c.hline(x0 + 1, x0 + 6, top, WAX)
    for y in range(top + 1, top + 6):
        c.hline(x0, x0 + 7, y, WAX)
    c.hline(x0 + 2, x0 + 5, top, WAX_HI)
    for y in range(top + 2, top + 6):
        c.set(x0, y, WAX_SH)
        c.set(x0 + 7, y, WAX_SH)
    c.hline(x0 + 1, x0 + 6, top + 5, WAX_SH)
    if not back:
        c.set(x0 + 6, top + 1, WAX_HI)
        c.set(x0 + 6, top + 2, WAX_HI)
    # poncho (3 linhas) — de costas tem o capuz dobrado
    py = top + 5
    c.hline(x0 - 1, x0 + 8, py, PON)
    c.hline(x0 - 1, x0 + 8, py + 1, PON)
    c.hline(x0, x0 + 7, py + 2, PON_SH)
    c.hline(x0, x0 + 7, py, PON_HI)
    for xx in range(x0, x0 + 8, 2):
        c.set(xx, py + 1, PON_HI)
    if back:
        c.set(x0 + 3, py + 1, PON_SH)
        c.set(x0 + 4, py + 1, PON_SH)
        c.set(x0 + 3, py + 2, dark_pon())
        c.set(x0 + 4, py + 2, dark_pon())
    c.outline(OUT)
    for p in feet:
        c.set(p[0], p[1], FOOT if p[1] >= 15 else OUT)
    c.set(8, top - 1, WICK)
    collar = [x0, x0 + 7, py]
    return c, collar


def dark_pon():
    return (PON_SH[0] * 3 // 4, PON_SH[1] * 3 // 4, PON_SH[2] * 3 // 4, 255)


def build_overworld():
    """Quadros 16x16: down0-3, up0-3, side0-3. Âncoras como no herói de
    plataforma: olhos (só de frente/lado), bochechas, chama e gola."""
    F = []
    steps = [
        ([(6, 14), (6, 15), (9, 14), (9, 15)], 0),
        ([(6, 14), (9, 14), (9, 15)], -1),
        ([(6, 14), (6, 15), (9, 14), (9, 15)], 0),
        ([(6, 14), (6, 15), (9, 14)], -1),
    ]
    for i, (feet, bob) in enumerate(steps):
        top = 6 + bob
        c, collar = _front(top, feet)
        F.append(("down%d" % i, c, {"eye": [6, top + 2], "cheeks": [[5, top + 4], [10, top + 4]], "flame": [8, top - 2], "collar": [collar[0] + 1, collar[1] - 1, collar[2]]}))
    for i, (feet, bob) in enumerate(steps):
        top = 6 + bob
        c, collar = _front(top, feet, back=True)
        F.append(("up%d" % i, c, {"eye": None, "cheeks": [], "flame": [8, top - 2], "collar": [collar[0] + 1, collar[1] - 1, collar[2]]}))
    side_legs = [
        [(6, 14), (5, 15), (9, 14), (10, 15)],
        [(7, 14), (7, 15), (9, 14), (9, 15)],
        [(9, 14), (10, 15), (6, 14), (5, 15)],
        [(8, 14), (8, 15), (7, 14), (7, 15)],
    ]
    for i in range(4):
        bob = -1 if i % 2 else 0
        cv = pavio(4, 6 + bob, 6, [10, 10, 9], side_legs[i])
        c, wx, wy = cv
        F.append(("side%d" % i, c, {"eye": [8, 8 + bob], "cheeks": [[7, 10 + bob], [12, 10 + bob]], "flame": [wx, wy - 1], "collar": c.collar}))
    return F
