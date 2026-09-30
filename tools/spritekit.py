#!/usr/bin/env python3
"""Kit de pixel art procedural (usado por tools/build_sprites.py).

Em vez de pintar pixel a pixel, cada personagem é montado com FORMAS COM
VOLUME (elipses, cápsulas, polígonos chanfrados, fitas) num pequeno
"renderizador" de pixels: cada forma sabe a sua normal (como um modelo 3D
achatado — é assim que o Dead Cells faz os seus sprites), então a luz é
consistente em todos os quadros da animação. Depois vêm os passos que
deixam a imagem com cara de pixel art feita à mão:

  * sombreamento em FAIXAS (3-6 tons por material, com desvio de matiz:
    sombra puxa para o azul/violeta, luz puxa para o amarelo);
  * luz de borda (rim light) vinda de trás — separa o personagem de fundos
    escuros, como no Hollow Knight;
  * brilho especular em metal;
  * sombra de contato onde uma peça fica na frente da outra;
  * contorno SELETIVO (escuro e colorido; mais claro no lado da luz) com
    limpeza de "cotovelos" (linhas de 1 px sem dentes);
  * camada de BRILHO separada (olhos, chamas, runas): o jogo a desenha por
    cima sem ser afetada pela escuridão do cenário, com bloom.

Coordenadas: origem nos pés (centro embaixo), x para a frente (o sprite
olha para a DIREITA), y para BAIXO (negativo = para cima), em pixels.
"""
import colorsys
import math

import numpy as np
from PIL import Image

# luz principal: de cima e um pouco da frente, saindo da tela
LIGHT = np.array([0.5, -0.76, 0.4])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
# luz de borda: de trás e de cima
RIM = np.array([-0.85, -0.35, 0.05])
RIM = RIM / np.linalg.norm(RIM)


# ---------------------------------------------------------------------------
# Cores e rampas
# ---------------------------------------------------------------------------

def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def _hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)


def _rgb(h, s, v, a=255):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(1.0, s)), max(0.0, min(1.0, v)))
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), a)


def ramp(base, n=5, spread=0.62, hue_shift=0.045, sat_shift=0.12, cool=True):
    """Rampa de n tons do escuro ao claro em torno de `base` (o tom do meio).
    Sombras giram a matiz para o frio (azul/violeta) e ganham saturação;
    luzes giram para o quente (amarelo) e perdem saturação."""
    if isinstance(base, str):
        base = hexc(base)
    h, s, v = _hsv(base)
    out = []
    mid = (n - 1) / 2.0
    for i in range(n):
        k = (i - mid) / max(mid, 1.0)  # -1 .. 1
        # matiz: para o frio (≈0.66) no escuro, para o quente (≈0.12) no claro
        target = 0.68 if k < 0 else 0.13
        dh = ((target - h + 0.5) % 1.0) - 0.5
        hh = h + dh * hue_shift * abs(k) * (1.0 if cool or k > 0 else 0.0) * 4.0
        ss = s + (sat_shift if k < 0 else -sat_shift * 1.2) * abs(k)
        if k < 0:
            vv = v * (1.0 + k * spread)
        else:
            vv = v + (1.0 - v) * k * spread * 0.9
        out.append(_rgb(hh, ss, vv))
    return out


def darker(c, t=0.35):
    h, s, v = _hsv(c)
    return _rgb(h + 0.02, s + 0.1, v * (1.0 - t), c[3] if len(c) > 3 else 255)


def lighter(c, t=0.3):
    h, s, v = _hsv(c)
    return _rgb(h - 0.01, s - 0.08, v + (1.0 - v) * t, c[3] if len(c) > 3 else 255)


class Mat:
    """Material: rampa de tons + como reage à luz."""

    def __init__(self, base, n=5, spread=0.62, spec=0.0, rim=0.55, rim_color=None, outline=None,
                 wrap=0.35, glow=None, hue_shift=0.045, flat=False, ambient=0.22):
        self.ramp = ramp(base, n, spread, hue_shift) if not isinstance(base, list) else [hexc(c) if isinstance(c, str) else c for c in base]
        self.spec = spec
        self.rim = rim
        self.rim_color = hexc(rim_color) if isinstance(rim_color, str) else (rim_color or lighter(self.ramp[-1], 0.25))
        self.outline = hexc(outline) if isinstance(outline, str) else (outline or darker(self.ramp[0], 0.55))
        self.wrap = wrap
        self.glow = glow  # None ou cor emissiva (o pixel vai também para a camada de brilho)
        self.flat = flat
        self.ambient = ambient


# ---------------------------------------------------------------------------
# Tela
# ---------------------------------------------------------------------------

# Densidade da arte em relação às coordenadas de DESENHO. Os personagens são
# descritos em coordenadas de desenho (a escala de 2 px por unidade do mundo
# em que foram criados); o jogo usa 3 px por unidade (LevelConst.ART = 3),
# então cada forma é amostrada numa grade 1,5x mais fina: mesma pose, mesmas
# proporções, 50% mais pixels (mais detalhe, contorno mais fino).
RES = 1.5


class Canvas:
    def __init__(self, w, h, ox, oy):
        """w, h, ox, oy em coordenadas de DESENHO; a imagem sai com
        round(w * RES) x round(h * RES) px e a origem cai num pixel inteiro
        (px_origin)."""
        self.dw, self.dh = w, h
        self.w, self.h = int(round(w * RES)), int(round(h * RES))
        self.ox, self.oy = int(round(ox * RES)), int(round(oy * RES))
        cols = (np.arange(self.w) + 0.5 - self.ox) / RES
        rows = (np.arange(self.h) + 0.5 - self.oy) / RES
        self.X, self.Y = np.meshgrid(cols, rows)
        self.z = np.full((self.h, self.w), -1e9)
        self.part = np.full((self.h, self.w), -1, dtype=np.int32)
        self.N = np.zeros((self.h, self.w, 3))
        self.N[..., 2] = 1.0
        self.mats = []  # índice de parte -> Mat
        self.shade_bias = np.zeros((self.h, self.w))
        # sobreposições planas (detalhes de 1 px): cor RGBA, sem luz
        self.over = np.zeros((self.h, self.w, 4), dtype=np.float64)
        self.over_glow = np.zeros((self.h, self.w, 4), dtype=np.float64)
        self.glow = np.zeros((self.h, self.w, 4), dtype=np.float64)
        self.no_outline = np.zeros((self.h, self.w), dtype=bool)

    # -- utilitários -------------------------------------------------------
    def _commit(self, mask, z, normal, mat, bias=None, no_outline=False):
        if not mask.any():
            return
        win = mask & (z >= self.z)
        idx = len(self.mats)
        self.mats.append(mat)
        self.z[win] = z if np.isscalar(z) else z[win]
        self.part[win] = idx
        self.N[win] = normal[win]
        if bias is not None:
            self.shade_bias[win] = bias[win] if not np.isscalar(bias) else bias
        else:
            self.shade_bias[win] = 0.0
        self.no_outline[win] = no_outline

    @staticmethod
    def _norm(n):
        l = np.linalg.norm(n, axis=-1, keepdims=True)
        l[l == 0] = 1.0
        return n / l

    # -- primitivas --------------------------------------------------------
    def ellipse(self, cx, cy, rx, ry, mat, z=0.0, ang=0.0, bulge=1.0, bias=None, no_outline=False, tilt=(0.0, 0.0)):
        ca, sa = math.cos(ang), math.sin(ang)
        dx, dy = self.X - cx, self.Y - cy
        u = dx * ca + dy * sa
        v = -dx * sa + dy * ca
        d2 = (u / rx) ** 2 + (v / ry) ** 2
        mask = d2 <= 1.0
        nu, nv = u / rx, v / ry
        nz = np.sqrt(np.clip(1.0 - d2, 0.0, 1.0)) * bulge + 0.05
        n = np.stack([nu * ca - nv * sa + tilt[0], nu * sa + nv * ca + tilt[1], nz], -1)
        self._commit(mask, z, self._norm(n), mat, bias, no_outline)
        return mask

    def circle(self, cx, cy, r, mat, z=0.0, **kw):
        return self.ellipse(cx, cy, r, r, mat, z, **kw)

    def capsule(self, x0, y0, x1, y1, r0, r1, mat, z=0.0, flat=0.0, bias=None, no_outline=False):
        px, py = self.X - x0, self.Y - y0
        vx, vy = x1 - x0, y1 - y0
        ll = vx * vx + vy * vy
        t = np.clip((px * vx + py * vy) / ll, 0.0, 1.0) if ll > 0 else np.zeros_like(px)
        cx, cy = x0 + vx * t, y0 + vy * t
        r = r0 + (r1 - r0) * t
        dx, dy = self.X - cx, self.Y - cy
        d = np.sqrt(dx * dx + dy * dy)
        mask = d <= r
        rr = np.maximum(r, 1e-3)
        nx, ny = dx / rr, dy / rr
        nz = np.sqrt(np.clip(1.0 - (d / rr) ** 2, 0.0, 1.0)) + flat
        n = np.stack([nx, ny, nz + 0.05], -1)
        self._commit(mask, z, self._norm(n), mat, bias, no_outline)
        return mask

    def limb(self, pts, radii, mat, z=0.0, flat=0.0):
        """Cadeia de cápsulas (braço/perna com juntas)."""
        m = None
        for i in range(len(pts) - 1):
            mm = self.capsule(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], radii[i], radii[i + 1], mat, z, flat)
            m = mm if m is None else (m | mm)
        return m

    def _inside_poly(self, pts):
        x, y = self.X, self.Y
        inside = np.zeros(x.shape, dtype=bool)
        n = len(pts)
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            cond = ((yi > y) != (yj > y))
            with np.errstate(divide="ignore", invalid="ignore"):
                xint = (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi
            inside ^= cond & (x < xint)
            j = i
        return inside

    def _edge_field(self, pts):
        """Distância até a borda do polígono e direção para fora."""
        best = np.full(self.X.shape, 1e9)
        ox = np.zeros(self.X.shape)
        oy = np.zeros(self.X.shape)
        n = len(pts)
        # orientação (para saber o lado de fora)
        area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
        sgn = 1.0 if area > 0 else -1.0
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            vx, vy = x1 - x0, y1 - y0
            ll = vx * vx + vy * vy
            if ll == 0:
                continue
            t = np.clip(((self.X - x0) * vx + (self.Y - y0) * vy) / ll, 0.0, 1.0)
            dx = self.X - (x0 + vx * t)
            dy = self.Y - (y0 + vy * t)
            d = np.sqrt(dx * dx + dy * dy)
            better = d < best
            best = np.where(better, d, best)
            # normal da aresta, para fora
            ln = math.sqrt(ll)
            enx, eny = vy / ln * sgn, -vx / ln * sgn
            ox = np.where(better, enx, ox)
            oy = np.where(better, eny, oy)
        return best, ox, oy

    def poly(self, pts, mat, z=0.0, bevel=2.5, tilt=(0.0, 0.0), folds=None, bias=None, no_outline=False, round_=0.8):
        """Polígono com borda chanfrada (volume) e dobras opcionais:
        folds = (direção_x, frequência, fase, força) — ondulação da normal
        (tecido)."""
        mask = self._inside_poly(pts)
        if not mask.any():
            return mask
        d, ex, ey = self._edge_field(pts)
        k = np.clip(1.0 - d / max(bevel, 1e-3), 0.0, 1.0) ** 1.5 * round_
        nx = ex * k + tilt[0]
        ny = ey * k + tilt[1]
        if folds is not None:
            fx, freq, phase, amp = folds
            s = np.sin((self.X * fx + self.Y * (1 - abs(fx))) * freq + phase)
            nx = nx + s * amp
        nz = np.sqrt(np.clip(1.0 - k * k, 0.05, 1.0))
        n = np.stack([nx, ny, nz], -1)
        self._commit(mask, z, self._norm(n), mat, bias, no_outline)
        return mask

    def ribbon(self, pts, widths, mat, z=0.0, twist=0.0, no_outline=False):
        """Fita (cachecol, cauda, capa fina): polígono ao longo da linha com
        largura variável; normal de tecido que alterna com a curvatura."""
        left, right = [], []
        n = len(pts)
        for i in range(n):
            if i == 0:
                tx, ty = pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]
            elif i == n - 1:
                tx, ty = pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1]
            else:
                tx, ty = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
            l = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / l, tx / l
            w = widths[i] * 0.5
            left.append((pts[i][0] + nx * w, pts[i][1] + ny * w))
            right.append((pts[i][0] - nx * w, pts[i][1] - ny * w))
        poly = left + right[::-1]
        return self.poly(poly, mat, z, bevel=1.6, tilt=(0.0, -0.1), folds=(1.0, 0.9, twist, 0.25), no_outline=no_outline)

    # -- detalhes planos (sem luz) ------------------------------------------
    def _px(self, r, c, col, glow):
        if 0 <= c < self.w and 0 <= r < self.h:
            self.over[r, c] = col
            if glow:
                self.over_glow[r, c] = col

    def dot(self, x, y, color, glow=False):
        """Pinta o "pixel de desenho" que contém (x, y): na grade fina isso
        cobre 1-2 px por eixo."""
        col = np.array(color if len(color) == 4 else tuple(color) + (255,), dtype=np.float64)
        cx, cy = math.floor(x), math.floor(y)
        c0 = math.ceil(cx * RES + self.ox - 0.5)
        c1 = math.ceil((cx + 1) * RES + self.ox - 0.5)
        r0 = math.ceil(cy * RES + self.oy - 0.5)
        r1 = math.ceil((cy + 1) * RES + self.oy - 0.5)
        for r in range(r0, max(r1, r0 + 1)):
            for c in range(c0, max(c1, c0 + 1)):
                self._px(r, c, col, glow)

    def line(self, x0, y0, x1, y1, color, glow=False):
        """Linha de 1 px na grade FINA (rachaduras e fios ficam finos)."""
        col = np.array(color if len(color) == 4 else tuple(color) + (255,), dtype=np.float64)
        ax, ay = (math.floor(x0) + 0.5) * RES + self.ox, (math.floor(y0) + 0.5) * RES + self.oy
        bx, by = (math.floor(x1) + 0.5) * RES + self.ox, (math.floor(y1) + 0.5) * RES + self.oy
        n = int(max(abs(bx - ax), abs(by - ay))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            self._px(int(math.floor(ay + (by - ay) * t)), int(math.floor(ax + (bx - ax) * t)), col, glow)

    def glow_shape(self, mask, colors_by_dist=None, color=None):
        """Pinta uma máscara como emissiva (camada de brilho + cor)."""
        col = np.array(color, dtype=np.float64)
        self.over[mask] = col
        self.over_glow[mask] = col

    def flame(self, cx, cy, w, h, lean=0.0, t=0.0, palette=None, z=10.0):
        """Chama em gota: base redonda que afina até uma ponta curva que
        tremula, com quatro camadas (borda, meio, claro, núcleo). Emissiva."""
        pal = palette or [hexc("#b8321e"), hexc("#f07a28"), hexc("#ffc850"), hexc("#fff4d0")]
        masks = []
        wob = math.sin(t * math.tau)
        wob2 = math.sin(t * math.tau * 2 + 1.3)
        for layer, scale in enumerate([1.0, 0.74, 0.5, 0.26]):
            ww = w * scale
            hh = h * (0.45 + 0.55 * scale)
            by = cy - (1.0 - scale) * 0.8  # núcleo um pouco mais alto
            base = ((self.X - cx) / (ww * 0.5)) ** 2 + ((self.Y - by) / (ww * 0.42)) ** 2 <= 1.0
            prog = np.clip((by - self.Y) / max(hh, 1e-3), 0.0, 1.0)
            center = cx + (lean * 0.6 + wob * 0.7) * prog * prog * hh * 0.35 + wob2 * 0.4 * prog
            half = (ww * 0.5) * np.cos(prog * math.pi * 0.5) ** 0.9
            body = (self.Y <= by) & (self.Y >= by - hh) & (np.abs(self.X - center) <= half)
            m = base | body
            masks.append(m)
        for i, m in enumerate(masks):
            col = np.array(pal[i], dtype=np.float64)
            self.over[m] = col
            self.over_glow[m] = col
        return masks[0]

    # -- render ---------------------------------------------------------------
    def render(self, outline=True, contact=True, despeckle=True):
        """Devolve (imagem RGBA, brilho RGBA) como arrays uint8."""
        h, w = self.h, self.w
        img = np.zeros((h, w, 4), dtype=np.float64)
        shade_idx = np.full((h, w), -1, dtype=np.int32)
        N = self.N
        ndl = np.clip(N @ LIGHT, -1.0, 1.0)
        rim = np.clip(N @ RIM, 0.0, 1.0)
        # sombra de contato: peça mais à frente (z maior) logo acima/à frente
        occl = np.zeros((h, w), dtype=bool)
        if contact:
            zs = self.z
            for dy, dx in [(-1, 1), (-1, 0), (-2, 1)]:
                sh = np.full_like(zs, -1e9)
                ys = slice(max(0, -dy), h - max(0, dy))
                yd = slice(max(0, dy), h - max(0, -dy))
                xs = slice(max(0, -dx), w - max(0, dx))
                xd = slice(max(0, dx), w - max(0, -dx))
                sh[yd, xd] = zs[ys, xs]
                ps = np.full_like(self.part, -1)
                ps[yd, xd] = self.part[ys, xs]
                occl |= (sh > zs + 0.5) & (ps >= 0) & (ps != self.part) & (self.part >= 0)
        for idx, mat in enumerate(self.mats):
            m = self.part == idx
            if not m.any():
                continue
            n = len(mat.ramp)
            if mat.flat:
                lum = np.full(m.sum(), 0.62)
            else:
                d = ndl[m]
                lum = (d + mat.wrap) / (1.0 + mat.wrap)
                lum = np.clip(lum, 0.0, 1.0) * (1.0 - mat.ambient) + mat.ambient
            lum = lum + self.shade_bias[m]
            if contact:
                lum = lum - occl[m] * (1.0 / n) * 1.3
            si = np.clip((lum * n).astype(np.int32), 0, n - 1)
            if mat.spec > 0:
                # especular (Blinn): meio vetor entre luz e olho
                hv = LIGHT + np.array([0.0, 0.0, 1.0])
                hv = hv / np.linalg.norm(hv)
                sp = np.clip(N[m] @ hv, 0.0, 1.0) ** 24 * mat.spec
                si = np.where(sp > 0.45, n - 1, si)
            shade_idx[m] = si
            cols = np.array(mat.ramp, dtype=np.float64)[si]
            if mat.rim > 0:
                r = rim[m] * mat.rim
                rc = np.array(mat.rim_color, dtype=np.float64)
                cols = np.where((r > 0.42)[:, None], rc, cols)
            img[m] = cols
            if mat.glow is not None:
                self.glow[m] = np.array(mat.glow, dtype=np.float64)
        # limpa pixels isolados de tom diferente dentro da mesma peça
        if despeckle:
            self._despeckle(img, shade_idx)
        # detalhes planos por cima
        om = self.over[..., 3] > 0
        img[om] = self.over[om]
        gm = self.over_glow[..., 3] > 0
        self.glow[gm] = self.over_glow[gm]
        if outline:
            img = self._outline(img)
        return np.clip(img, 0, 255).astype(np.uint8), np.clip(self.glow, 0, 255).astype(np.uint8)

    def _despeckle(self, img, si):
        h, w = si.shape
        part = self.part
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                p = part[y, x]
                if p < 0:
                    continue
                nb = [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]
                same = [q for q in nb if part[q] == p]
                if len(same) < 4:
                    continue
                vals = [si[q] for q in same]
                if all(v == vals[0] for v in vals) and si[y, x] != vals[0]:
                    si[y, x] = vals[0]
                    img[y, x] = img[nb[0]]

    def _outline(self, img):
        h, w = img.shape[:2]
        a = img[..., 3] > 0
        out = img.copy()
        # contorno externo: pixel vazio com vizinho (4) opaco
        pad = np.pad(a, 1)
        nb = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
        ring = nb & ~a
        # limpa cotovelos: pixel de contorno com vizinho de contorno em L e o
        # canto diagonal preenchido -> remove (linha mais limpa)
        ringp = np.pad(ring, 1)
        ap = np.pad(a, 1)
        for y in range(h):
            for x in range(w):
                if not ring[y, x]:
                    continue
                yy, xx = y + 1, x + 1
                # se o único vizinho opaco é diagonal, esse pixel não precisa
                o4 = ap[yy - 1, xx] or ap[yy + 1, xx] or ap[yy, xx - 1] or ap[yy, xx + 1]
                if not o4:
                    ring[y, x] = False
        for y in range(h):
            for x in range(w):
                if not ring[y, x]:
                    continue
                # vizinho opaco dominante -> cor de contorno do material dele
                best = None
                for dy, dx in [(0, -1), (0, 1), (1, 0), (-1, 0)]:
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and a[yy, xx]:
                        p = self.part[yy, xx]
                        if p >= 0 and not self.no_outline[yy, xx]:
                            best = (p, yy, xx)
                            break
                if best is None:
                    continue
                p, yy, xx = best
                mat = self.mats[p]
                col = np.array(mat.outline, dtype=np.float64)
                # contorno seletivo: do lado da luz, um pouco mais claro
                n = self.N[yy, xx]
                if float(n @ LIGHT) > 0.7 and mat.glow is None:
                    col = np.array(darker(mat.ramp[0], 0.35), dtype=np.float64)
                out[y, x] = col
        return out


# ---------------------------------------------------------------------------
# Folhas de sprite
# ---------------------------------------------------------------------------

def strip(frames):
    """Junta quadros (arrays HxWx4) lado a lado."""
    h = frames[0].shape[0]
    w = sum(f.shape[1] for f in frames)
    out = np.zeros((h, w, 4), dtype=np.uint8)
    x = 0
    for f in frames:
        out[:, x:x + f.shape[1]] = f
        x += f.shape[1]
    return out


def save(arr, path):
    Image.fromarray(arr, "RGBA").save(path)


def preview(sheets, path, scale=4, bg=(34, 30, 44)):
    """Prancha de conferência: cada linha uma animação, ampliada."""
    rows = []
    for name, frames in sheets:
        rows.append(strip(frames))
    wmax = max(r.shape[1] for r in rows)
    htot = sum(r.shape[0] + 2 for r in rows)
    img = Image.new("RGBA", (wmax, htot), bg + (255,))
    y = 0
    for r in rows:
        img.alpha_composite(Image.fromarray(r, "RGBA"), (0, y))
        y += r.shape[0] + 2
    img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)
