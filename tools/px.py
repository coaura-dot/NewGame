"""Pequena biblioteca de desenho em pixel art (usada por tools/pixel_art.py).

Tudo é desenhado em imagens RGBA minúsculas com primitivas inteiras e depois
recebe contorno automático — assim a arte fica limpa e consistente.
"""
from PIL import Image


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


CLEAR = (0, 0, 0, 0)


class Canvas:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.im = Image.new("RGBA", (w, h), CLEAR)
        self.px = self.im.load()

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def set(self, x, y, c):
        x = int(x)
        y = int(y)
        if self.inside(x, y) and c is not None:
            self.px[x, y] = c

    def get(self, x, y):
        if not self.inside(x, y):
            return CLEAR
        return self.px[x, y]

    def opaque(self, x, y):
        return self.get(x, y)[3] > 0

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.set(xx, yy, c)

    def hline(self, x0, x1, y, c):
        for xx in range(int(min(x0, x1)), int(max(x0, x1)) + 1):
            self.set(xx, y, c)

    def vline(self, x, y0, y1, c):
        for yy in range(int(min(y0, y1)), int(max(y0, y1)) + 1):
            self.set(x, yy, c)

    def rows(self, x, y, widths, c, align="center", offsets=None):
        """Preenche linhas com larguras dadas (forma arredondada)."""
        maxw = max(widths)
        for i, w in enumerate(widths):
            if align == "center":
                x0 = x + (maxw - w) // 2
            elif align == "left":
                x0 = x
            else:
                x0 = x + maxw - w
            if offsets:
                x0 += offsets[i]
            self.hline(x0, x0 + w - 1, y + i, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for yy in range(int(cy - ry - 1), int(cy + ry + 2)):
            for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx = (xx + 0.5 - cx) / max(rx, 0.01)
                dy = (yy + 0.5 - cy) / max(ry, 0.01)
                if dx * dx + dy * dy <= 1.0:
                    self.set(xx, yy, c)

    def line(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.set(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ascii(self, x, y, rows, pal):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in pal and pal[ch] is not None:
                    self.set(x + i, y + j, pal[ch])

    def replace(self, old, new):
        for yy in range(self.h):
            for xx in range(self.w):
                if self.px[xx, yy] == old:
                    self.px[xx, yy] = new

    def outline(self, c, diagonal=False, only_where=None):
        """Contorno de 1px em volta de tudo que é opaco."""
        add = []
        for yy in range(self.h):
            for xx in range(self.w):
                if self.opaque(xx, yy):
                    continue
                n = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                if diagonal:
                    n += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
                for dx, dy in n:
                    if self.opaque(xx + dx, yy + dy) and self.get(xx + dx, yy + dy) != c:
                        add.append((xx, yy))
                        break
        for xx, yy in add:
            self.set(xx, yy, c)

    def shade_bottom(self, base, shade, depth=1):
        """Escurece a borda de baixo das áreas com a cor base."""
        pts = []
        for yy in range(self.h):
            for xx in range(self.w):
                if self.get(xx, yy) == base:
                    for d in range(1, depth + 1):
                        if self.get(xx, yy + d) != base:
                            pts.append((xx, yy))
                            break
        for p in pts:
            self.set(p[0], p[1], shade)

    def shade_side(self, base, shade, side=-1):
        pts = []
        for yy in range(self.h):
            for xx in range(self.w):
                if self.get(xx, yy) == base and self.get(xx + side, yy) != base:
                    pts.append((xx, yy))
        for p in pts:
            self.set(p[0], p[1], shade)

    def flip(self):
        c = Canvas(self.w, self.h)
        c.im = self.im.transpose(Image.FLIP_LEFT_RIGHT)
        c.px = c.im.load()
        return c

    def paste(self, other, x, y):
        for yy in range(other.h):
            for xx in range(other.w):
                p = other.get(xx, yy)
                if p[3] > 0:
                    self.set(x + xx, y + yy, p)


def sheet(frames, cols=None):
    """Junta quadros do mesmo tamanho numa folha. Retorna (Image, cols)."""
    if not frames:
        return Image.new("RGBA", (1, 1)), 1
    w, h = frames[0].w, frames[0].h
    cols = cols or len(frames)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new("RGBA", (w * cols, h * rows), CLEAR)
    for i, f in enumerate(frames):
        im.paste(f.im, ((i % cols) * w, (i // cols) * h))
    return im, cols


def preview(img, scale=8, bg=(40, 44, 60, 255)):
    out = Image.new("RGBA", img.size, bg)
    out.alpha_composite(img)
    return out.resize((img.width * scale, img.height * scale), Image.NEAREST)
