#!/usr/bin/env python3
"""Refaz as letras minúsculas acentuadas das fontes pixel da Kenney.

Nas fontes kenney_pixel e kenney_mini as minúsculas são "versaletes"
(menores), mas os acentuados minúsculos (á, ç, õ...) vieram como cópias dos
MAIÚSCULOS — "Candelária" aparecia "CandelÁria". Este script monta cada
minúscula acentuada como: letra minúscula base + o acento tirado do
maiúsculo correspondente, baixado para a altura das minúsculas (a cedilha
fica onde está). Precisa de fontTools (pip install fonttools).

    python3 tools/fix_font_accents.py
"""
import os
import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import DecomposingRecordingPen, RecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FONTS = ["kenney_pixel.ttf", "kenney_mini.ttf"]

# minúscula acentuada -> (base minúscula, maiúsculo acentuado, base maiúscula)
ACCENTED = {
    "á": ("a", "Á", "A"), "à": ("a", "À", "A"), "â": ("a", "Â", "A"), "ã": ("a", "Ã", "A"), "ä": ("a", "Ä", "A"),
    "é": ("e", "É", "E"), "è": ("e", "È", "E"), "ê": ("e", "Ê", "E"), "ë": ("e", "Ë", "E"),
    "í": ("i", "Í", "I"), "ì": ("i", "Ì", "I"), "î": ("i", "Î", "I"), "ï": ("i", "Ï", "I"),
    "ó": ("o", "Ó", "O"), "ò": ("o", "Ò", "O"), "ô": ("o", "Ô", "O"), "õ": ("o", "Õ", "O"), "ö": ("o", "Ö", "O"),
    "ú": ("u", "Ú", "U"), "ù": ("u", "Ù", "U"), "û": ("u", "Û", "U"), "ü": ("u", "Ü", "U"),
    "ñ": ("n", "Ñ", "N"), "ç": ("c", "Ç", "C"), "ý": ("y", "Ý", "Y"),
}


def contours(glyphset, name):
    """Lista de contornos (cada um: lista de operações do RecordingPen)."""
    rec = DecomposingRecordingPen(glyphset)
    glyphset[name].draw(rec)
    out, cur = [], []
    for op, args in rec.value:
        cur.append((op, args))
        if op in ("closePath", "endPath"):
            out.append(cur)
            cur = []
    if cur:
        out.append(cur)
    return out


def bounds_of(glyphset, ops):
    bp = BoundsPen(glyphset)
    rp = RecordingPen()
    rp.value = ops
    rp.replay(bp)
    return bp.bounds


def glyph_bounds(glyphset, name):
    bp = BoundsPen(glyphset)
    glyphset[name].draw(bp)
    return bp.bounds


def fix(path):
    font = TTFont(path)
    cmap = font.getBestCmap()
    gs = font.getGlyphSet()
    glyf = font["glyf"]
    hmtx = font["hmtx"]
    changed = 0
    for ch, (low, up_acc, up) in ACCENTED.items():
        if ord(ch) not in cmap or ord(low) not in cmap or ord(up_acc) not in cmap or ord(up) not in cmap:
            continue
        g_target = cmap[ord(ch)]
        g_low = cmap[ord(low)]
        g_up_acc = cmap[ord(up_acc)]
        g_up = cmap[ord(up)]
        up_b = glyph_bounds(gs, g_up)
        low_b = glyph_bounds(gs, g_low)
        if up_b is None or low_b is None:
            continue
        cap_top, low_top = up_b[3], low_b[3]
        # contornos do acento: acima do topo do maiúsculo, ou abaixo da linha de base (cedilha)
        accent = []
        for c in contours(gs, g_up_acc):
            b = bounds_of(gs, c)
            if b is None:
                continue
            if b[1] >= cap_top - 1 or b[3] <= 1:
                accent.append((c, b[1] >= cap_top - 1))
        if not accent:
            continue
        base = contours(gs, g_low)
        if low == "i" and len(base) >= 2:
            # tira o pingo do i (o contorno mais alto): o acento toma o lugar dele
            base.sort(key=lambda c: bounds_of(gs, c)[3])
            base = base[:-1]
            low_top = max(bounds_of(gs, c)[3] for c in base)
        dy = cap_top - low_top
        # centraliza o acento sobre a letra minúscula
        ux = (up_b[0] + up_b[2]) / 2.0
        lx = (low_b[0] + low_b[2]) / 2.0
        dx = round(lx - ux)
        pen = TTGlyphPen(gs)
        for c in base:
            rp = RecordingPen()
            rp.value = c
            rp.replay(pen)
        for c, above in accent:
            rp = RecordingPen()
            rp.value = c
            rp.replay(TransformPen(pen, (1, 0, 0, 1, dx, -dy if above else 0)))
        glyf[g_target] = pen.glyph()
        hmtx[g_target] = hmtx[g_low]
        changed += 1
    font.save(path)
    return changed


def main():
    for f in FONTS:
        p = os.path.join(ROOT, "assets", "fonts", f)
        n = fix(p)
        print("%s: %d letras acentuadas refeitas" % (f, n))


if __name__ == "__main__":
    sys.exit(main())
