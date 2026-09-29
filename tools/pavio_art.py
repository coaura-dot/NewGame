"""Pavio: velinha viva de cera, com uma chama na cabeça, poncho azul-petróleo
e cachecol (procedural). Quadros 16x16 olhando para a direita, pés na linha
15. Os OLHOS e a CHAMA não fazem parte do quadro: o jogo desenha por cima
usando as âncoras "eye" (x do olho de trás, y do topo dos olhos) e "flame"
(base da chama, em cima do pavio). "neck" prende o cachecol e "hand" é onde
a lâmina aparece.
"""
from px import Canvas, hexc

OUT = hexc("1b1528")
WAX = hexc("f7ecd2")
WAX_SH = hexc("dcc39a")
WAX_HI = hexc("fffbf2")
PON = hexc("2f7f86")
PON_SH = hexc("225b62")
PON_HI = hexc("4aa7ab")
WICK = hexc("3a2a22")
FOOT = hexc("5a3b2e")

W = 16
H = 16


def candle(x, hy, body, poncho, legs, lean=None, poncho_off=None, drip=True, pstart=None):
    """x = coluna esquerda do corpo de 8; hy = linha do topo.
    body = larguras das linhas de cera (centradas em x+4, com 'lean' por linha);
    poncho = larguras das linhas do poncho (começa em pstart)."""
    c = Canvas(W, H)
    lean = lean or [0] * len(body)
    for i, w in enumerate(body):
        x0 = x + (8 - w) // 2 + lean[i]
        c.hline(x0, x0 + w - 1, hy + i, WAX)
    # sombra da cera no lado de trás (esquerda) e brilho no topo da frente
    for i, w in enumerate(body):
        x0 = x + (8 - w) // 2 + lean[i]
        if i >= 2:
            c.set(x0, hy + i, WAX_SH)
    top_w = body[0]
    tx0 = x + (8 - top_w) // 2 + lean[0]
    c.set(tx0 + top_w - 1, hy, WAX_HI)
    if len(body) > 1:
        x1 = x + (8 - body[1]) // 2 + lean[1]
        c.set(x1 + body[1] - 2, hy + 1, WAX_HI)
    # pingo de cera escorrendo na frente
    if drip and len(body) > 3:
        x2 = x + (8 - body[2]) // 2 + lean[2]
        c.set(x2 + body[2] - 1, hy + 2, WAX)
        c.set(x2 + body[2] - 1, hy + 3, WAX_HI)
    ps = pstart if pstart is not None else hy + len(body) - len(poncho) + 1
    poff = poncho_off or [0] * len(poncho)
    for i, w in enumerate(poncho):
        x0 = x + (8 - w) // 2 + poff[i]
        c.hline(x0, x0 + w - 1, ps + i, PON)
    # barra do poncho mais escura + dobra clara
    if poncho:
        last = len(poncho) - 1
        x0 = x + (8 - poncho[last]) // 2 + poff[last]
        c.hline(x0, x0 + poncho[last] - 1, ps + last, PON_SH)
        x0 = x + (8 - poncho[0]) // 2 + poff[0]
        c.set(x0 + poncho[0] - 2, ps, PON_HI)
    c.outline(OUT)
    for p in legs:
        c.set(p[0], p[1], FOOT if p[1] >= 15 else OUT)
    # pavio (sem contorno)
    c.set(tx0 + top_w // 2, hy - 1, WICK)
    return c, tx0 + top_w // 2, ps


def build():
    F = []

    def add(name, cv, eye, neck, hand=(12, 11), flame=None):
        c, fx, _ps = cv
        F.append((name, c, {"eye": list(eye), "neck": list(neck), "hand": list(hand), "flame": list(flame) if flame else [fx, eye[1] - 5]}))

    BODY = [4, 6, 8, 8, 8, 8, 8, 8]
    PONCHO = [8, 9, 9, 8]
    STAND = [(6, 14), (6, 15), (9, 14), (9, 15)]

    def std(hy, x=4, body=BODY, poncho=PONCHO, legs=STAND, lean=None, poff=None, pstart=None):
        return candle(x, hy, body, poncho, legs, lean, poff, pstart=pstart)

    # idle (respira: afunda 1 px e alarga)
    cv = std(6)
    add("idle0", cv, (7, 9), (5, 10), flame=(cv[1], 5))
    cv = std(7, body=[4, 6, 8, 8, 8, 8, 8], poncho=[9, 9, 9, 8])
    add("idle1", cv, (7, 10), (5, 11), flame=(cv[1], 6))
    # corrida: inclinado para a frente, poncho esvoaçando para trás
    run_legs = [
        [(6, 14), (5, 15), (9, 14), (10, 15)],
        [(6, 14), (6, 15), (9, 14), (9, 15)],
        [(7, 14), (7, 15), (9, 14), (10, 14)],
        [(6, 14), (5, 15), (9, 14), (10, 15)],
        [(9, 14), (9, 15), (6, 14), (6, 15)],
        [(8, 14), (8, 15), (6, 14), (5, 14)],
    ]
    bob = [0, -1, -1, 0, -1, -1]
    for i in range(6):
        hy = 6 + bob[i]
        lean = [1, 1, 1, 0, 0, 0, 0, 0]
        poff = [-1, -1, -2, -2] if i % 3 else [-1, -2, -2, -2]
        cv = std(hy, lean=lean, poncho=[8, 9, 10, 9], poff=poff, legs=run_legs[i])
        add("run%d" % i, cv, (8, hy + 3), (4, hy + 5), flame=(cv[1], hy - 1))
    # pulo: esticado
    cv = std(4, body=[4, 6, 6, 6, 6, 6, 6, 6, 6], poncho=[7, 7, 7], legs=[(7, 14), (7, 15), (8, 14)], pstart=10)
    add("jump", cv, (7, 7), (5, 10), flame=(cv[1], 3))
    # queda: poncho abre como paraquedas
    for i in range(2):
        legs = [(6, 14), (6, 15), (9, 14)] if i == 0 else [(6, 14), (9, 14), (9, 15)]
        cv = std(5, body=[4, 6, 8, 8, 8, 8, 8, 8], poncho=[10, 11, 11, 9], legs=legs)
        add("fall%d" % i, cv, (7, 8), (4, 10), flame=(cv[1], 4))
    # dash: achatado e comprido, inclinado
    cv = candle(3, 8, [5, 8, 10, 10, 10], [10, 10], [(2, 14), (3, 14)], lean=[2, 1, 0, 0, 0], poncho_off=[-1, -1], drip=False, pstart=12)
    add("dash", cv, (9, 10), (4, 12), (13, 12), flame=(cv[1] - 1, 7))
    # parede (a parede fica à esquerda do quadro)
    cv = std(6, x=5, legs=[(11, 13), (12, 13), (8, 14), (8, 15)], poncho=[8, 8, 8, 7])
    add("wall", cv, (8, 9), (6, 10), flame=(cv[1], 5))
    cv = std(5, x=5, legs=[(11, 12), (12, 12), (8, 14), (8, 15)], poncho=[8, 8, 8, 7])
    add("climb0", cv, (8, 8), (6, 9), flame=(cv[1], 4))
    cv = std(6, x=5, legs=[(11, 14), (12, 15), (8, 14)], poncho=[8, 8, 8, 7])
    add("climb1", cv, (8, 9), (6, 10), flame=(cv[1], 5))
    # agachado: baixinho e largo
    cv = candle(4, 9, [6, 8, 8, 10, 10], [10, 10], [(6, 15), (9, 15)], pstart=12)
    add("duck", cv, (7, 11), (4, 12), flame=(cv[1], 8))
    # golpes (a lâmina é desenhada pelo jogo)
    cv = std(6, x=3, lean=[1, 1, 1, 1, 1, 0, 0, 0], poncho=[8, 9, 9, 8], legs=[(5, 14), (4, 15), (10, 14), (11, 15)])
    add("slash0", cv, (7, 9), (4, 10), (12, 10), flame=(cv[1], 5))
    cv = std(6, x=5, lean=[-1, -1, 0, 0, 0, 0, 0, 0], poncho=[8, 9, 9, 8], legs=[(6, 14), (5, 15), (11, 14), (12, 15)])
    add("slash1", cv, (8, 9), (6, 10), (13, 11), flame=(cv[1], 5))
    cv = std(5, body=[4, 6, 6, 8, 8, 8, 8, 8, 8], legs=STAND)
    add("slash_up", cv, (7, 8), (5, 10), (9, 3), flame=(cv[1], 4))
    cv = candle(4, 4, [4, 6, 8, 8, 8, 8], [8, 8, 7], [(7, 13), (8, 13)], pstart=8)
    add("slash_down", cv, (7, 7), (5, 8), (8, 14), flame=(cv[1], 3))
    # conjurar / focar
    cv = std(6, poncho=[10, 11, 11, 10], legs=[(6, 14), (5, 15), (9, 14), (10, 15)])
    add("cast", cv, (7, 9), (4, 10), (13, 10), flame=(cv[1], 5))
    cv = candle(4, 8, [4, 6, 8, 8, 8, 8], [10, 10, 10], [(6, 14), (9, 14)], pstart=11)
    add("focus", cv, (7, 10), (4, 11), flame=(cv[1], 7))
    # dano / morte (derrete numa poça) / sentado
    cv = std(6, x=5, lean=[-1, -1, -1, 0, 0, 0, 0, 0], legs=[(7, 14), (6, 15), (11, 14), (12, 15)])
    add("hurt", cv, (7, 9), (6, 10), flame=(cv[1], 5))
    cv = candle(2, 12, [6, 10, 12], [], [], drip=False)
    add("dead", cv, (6, 12), (4, 14), flame=(cv[1], 11))
    cv = candle(4, 8, [4, 6, 8, 8, 8, 8], [9, 9, 9], [(10, 15), (11, 15)], pstart=11)
    add("sit", cv, (7, 10), (4, 11), flame=(cv[1], 7))
    return F
