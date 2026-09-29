#!/usr/bin/env python3
"""Corrige as minúsculas acentuadas das fontes Kenney (CC0).

As fontes Kenney Pixel/High/Mini desenham "ã", "ç", "é"... com o glifo da
MAIÚSCULA ("ReputaÇÃo"). Este script reconstrói cada minúscula acentuada
como: contornos da minúscula base + contornos do acento tirados da
maiúscula acentuada, descidos da altura das maiúsculas para a altura-x.
Para í/ì/î/ï usa a haste do "i" sem o pingo.

Uso: python3 tools/fix_font_accents.py   (edita assets/fonts/*.ttf no lugar)
Requer: pip install fonttools
"""
import os
import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FONTS = ["kenney_pixel.ttf", "kenney_high.ttf", "kenney_mini.ttf"]
# minúscula acentuada -> (base minúscula, maiúscula acentuada)
PAIRS = {}
for acc in ["grave", "acute", "circumflex", "tilde", "dieresis"]:
    for v in "aeiou":
        PAIRS[v + acc] = (v, v.upper() + acc)
PAIRS["ccedilla"] = ("c", "Ccedilla")
PAIRS["ntilde"] = ("n", "Ntilde")


def contours(glyphset, name):
    """Lista de (operações, bbox) por contorno do glifo."""
    rec = RecordingPen()
    glyphset[name].draw(rec)
    out, cur = [], []
    for op, args in rec.value:
        cur.append((op, args))
        if op in ("closePath", "endPath"):
            pts = [p for _, a in cur for p in a]
            xs = [p[0] for p in pts] or [0]
            ys = [p[1] for p in pts] or [0]
            out.append((cur, (min(xs), min(ys), max(xs), max(ys))))
            cur = []
    return out


def replay(pen, ops):
    for op, args in ops:
        getattr(pen, op)(*args)


def bounds(glyphset, name):
    bp = BoundsPen(glyphset)
    glyphset[name].draw(bp)
    return bp.bounds


def fix(path):
    font = TTFont(path)
    gs = font.getGlyphSet()
    glyf = font["glyf"]
    hmtx = font["hmtx"]
    cmap = font.getBestCmap()
    names = set(font.getGlyphOrder())
    cap_h = bounds(gs, "H")[3]
    x_h = bounds(gs, "x")[3]
    drop = cap_h - x_h
    fixed = 0
    for target, (base, upper) in PAIRS.items():
        if target not in names or base not in names or upper not in names:
            continue
        # só mexe se o glifo atual for igual ao da maiúscula (o defeito)
        if bounds(gs, target) != bounds(gs, upper):
            continue
        base_cs = contours(gs, base)
        if base == "i":
            # haste sem o pingo: descarta contornos acima de 2/3 da altura-x
            base_cs = [c for c in base_cs if c[1][1] < x_h * 0.66]
        acc = []
        for ops, bb in contours(gs, upper):
            if bb[1] >= cap_h:  # acento acima
                acc.append((ops, 0, -drop))
            elif bb[3] <= 0:  # cedilha abaixo
                acc.append((ops, 0, 0))
        if not acc:
            continue
        base_w = hmtx[base][0]
        upper_w = hmtx[upper][0]
        # centraliza o acento sobre a letra base
        bb_b = bounds(gs, base)
        bb_u = bounds(gs, upper)
        dx = ((bb_b[0] + bb_b[2]) - (bb_u[0] + bb_u[2])) / 2.0
        grid = 64 if font["head"].unitsPerEm == 1024 else 1
        dx = round(dx / grid) * grid
        pen = TTGlyphPen(gs)
        for ops, _ in base_cs:
            replay(pen, ops)
        min_x = bb_b[0]
        max_x = bb_b[2]
        for ops, ax, ay in acc:
            replay(TransformPen(pen, (1, 0, 0, 1, dx + ax, ay)), ops)
        g = pen.glyph()
        glyf[target] = g
        g.recalcBounds(glyf)
        min_x = min(min_x, g.xMin)
        max_x = max(max_x, g.xMax)
        width = max(base_w, int(max_x + (base_w - bb_b[2])))
        if min_x < 0:
            # acento mais largo que a letra (í): desloca tudo para a direita
            shift = -min_x
            pen2 = TTGlyphPen(gs)
            for ops, _ in base_cs:
                replay(TransformPen(pen2, (1, 0, 0, 1, shift, 0)), ops)
            for ops, ax, ay in acc:
                replay(TransformPen(pen2, (1, 0, 0, 1, dx + ax + shift, ay)), ops)
            g = pen2.glyph()
            glyf[target] = g
            g.recalcBounds(glyf)
            width = int(g.xMax + (base_w - bb_b[2]))
        hmtx[target] = (width, g.xMin)
        fixed += 1
    font.save(path)
    return fixed


def main():
    for f in FONTS:
        p = os.path.join(ROOT, "assets", "fonts", f)
        if os.path.exists(p):
            print(f, "glifos corrigidos:", fix(p))
    return 0


if __name__ == "__main__":
    sys.exit(main())
