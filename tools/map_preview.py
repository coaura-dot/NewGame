#!/usr/bin/env python3
"""Prévia dos mapas feitos à mão (data/maps/<id>.txt) em PNG + checagem de
alcance (o mesmo modelo conservador de pulo do ReachMap: sobe 3 tiles, até
5 de distância; quedas; atravessar plataformas).

Uso: python3 tools/map_preview.py <id> [saida.png] [--abilities double_jump,...]
Mostra: rocha (bordas claras), ar (fundo de parede / céu), plataformas,
espinhos, água, entidades (quadradinhos coloridos), cenografia (pontos),
retângulo e nome de cada sala, e um X vermelho nas coisas importantes que
NÃO são alcançáveis a partir do ponto inicial (ou que não voltam a ele).
Salas com requires=<habilidade> só contam se a habilidade for passada.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ENTITY_CHARS = {
    "E": "enemy", "F": "flyer", "M": "boss", "C": "chest", "K": "key", "D": "dash_crystal",
    "J": "jump_pad", "S": "saw", "L": "torch", "W": "light_shaft", "P": "arrival", "X": "exit",
    "G": "gate", "T": "lever", "N": "npc", "H": "checkpoint", "O": "falling_platform",
    "R": "relic", "Q": "quest_board", "Y": "rift", "A": "altar", "V": "ability_gate",
    "I": "impeto_orb", "U": "sniper",
}
DECOR = set("lparcbmgshtkvefqnowdxuyzji")
COLORS = {
    "enemy": (230, 60, 60), "flyer": (240, 140, 60), "sniper": (200, 40, 120), "boss": (255, 0, 80),
    "checkpoint": (255, 220, 80), "npc": (90, 230, 120), "story_npc": (60, 255, 170), "chest": (255, 190, 40),
    "relic": (255, 240, 120), "gate": (240, 240, 240), "ability_gate": (150, 120, 255), "lever": (80, 220, 255),
    "arrival": (255, 80, 255), "inscription": (140, 200, 255), "sign": (200, 170, 120), "torch": (255, 150, 60),
    "impeto_orb": (255, 200, 90), "light_shaft": (255, 255, 200), "breakable": (160, 110, 80),
    "cracked_floor": (130, 90, 60), "trigger": (255, 255, 255), "start": (255, 255, 255), "lamp": (255, 210, 120),
}
ANCHORS = {"checkpoint", "chest", "relic", "npc", "story_npc", "lever", "arrival", "boss", "inscription", "sign", "start", "lamp"}

MAX_RISE, MAX_DX_FLAT, MAX_DX_RISE, MAX_DX_DOWN = 3, 5, 4, 7
AIR, SOLID, ONE, SPK = 0, 1, 2, 3


def tokens(s):
    out, cur, q, had = [], "", False, False
    for ch in s:
        if ch == '"':
            q = not q
            had = True
            continue
        if ch in " \t" and not q:
            if cur or had:
                out.append(cur)
            cur, had = "", False
            continue
        cur += ch
    if cur or had:
        out.append(cur)
    return out


def kvs(toks):
    d = {}
    for t in toks:
        if "=" in t:
            k, v = t.split("=", 1)
            d[k] = v
    return d


def parse(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    W = H = 0
    default = "#"
    default_bg = "wall"
    abil = []
    rooms = []
    i = 0
    while i < len(lines):
        line = lines[i].rstrip("\r")
        i += 1
        if line.startswith("//") or not line.strip() or not line.startswith("@"):
            continue
        t = tokens(line[1:])
        if not t:
            continue
        if t[0] == "size":
            W, H = int(t[1]), int(t[2])
        elif t[0] == "default":
            default = t[1][0]
        elif t[0] == "bg":
            default_bg = t[1]
        elif t[0] == "abilities":
            abil = t[1:]
        elif t[0] in ("fill", "ground", "ent"):
            rooms.append({"directive": t[0], "toks": t})
        elif t[0] == "room":
            kv = kvs(t)
            name = t[2] if len(t) > 2 and "=" not in t[2] else ""
            at = [int(v) for v in kv.get("at", "0,0").split(",")]
            ascii_, custom = [], {}
            while i < len(lines):
                l2 = lines[i].rstrip("\r")
                i += 1
                if l2.startswith("@end"):
                    break
                if l2.startswith("//"):
                    continue
                s2 = l2.strip()
                if len(s2) >= 2 and s2[0].isdigit() and s2[1:].strip().startswith("="):
                    custom[s2[0]] = tokens(s2[1:].strip()[1:])
                    continue
                ascii_.append(l2)
            rooms.append({"id": t[1], "name": name, "kv": kv, "at": at, "ascii": ascii_, "custom": custom,
                          "bg": kv.get("bg", default_bg), "flags": [x for x in t if "=" not in x]})
    if W <= 0 or H <= 0:
        for r in rooms:
            if "directive" in r:
                continue
            W = max(W, r["at"][0] + max((len(l) for l in r["ascii"]), default=0))
            H = max(H, r["at"][1] + len(r["ascii"]))
    grid = [[default] * W for _ in range(H)]
    bg = [[1] * W for _ in range(H)]
    ents, decor, out_rooms, errors = [], [], [], []
    late = []
    for r in rooms:
        if "directive" in r:
            t = r["toks"]
            if t[0] == "fill":
                x0, y0, x1, y1 = [int(v) for v in t[1].split(",")]
                c = t[2][0] if len(t) > 2 else "#"
                for y in range(max(y0, 0), min(y1 + 1, H)):
                    for x in range(max(x0, 0), min(x1 + 1, W)):
                        grid[y][x] = c
            elif t[0] == "ground":
                for span in t[1:]:
                    xs, gy = span.split(":")
                    xs = xs.split("-")
                    x0 = int(xs[0])
                    x1 = int(xs[1]) if len(xs) > 1 else x0
                    for x in range(max(x0, 0), min(x1 + 1, W)):
                        for y in range(max(int(gy), 0), H):
                            grid[y][x] = "#"
            else:
                late.append(t)
            continue
        hidden = "hidden" in r.get("flags", ())
        idx = len(out_rooms) if not hidden else -1
        aw = max((len(l) for l in r["ascii"]), default=0)
        rect = [r["at"][0], r["at"][1], aw, len(r["ascii"])]
        if "rect" in r["kv"]:
            rect = [int(v) for v in r["kv"]["rect"].split(",")]
        if not hidden:
            out_rooms.append({"id": r["id"], "name": r["name"], "rect": rect, "kv": r["kv"]})
        bgv = 0 if r["bg"] in ("open", "sky") else 1
        if not r["ascii"]:
            fc = r["kv"].get("fill", "")
            for y in range(max(rect[1], 0), min(rect[1] + rect[3], H)):
                for x in range(max(rect[0], 0), min(rect[0] + rect[2], W)):
                    if fc:
                        grid[y][x] = fc[0]
                    if "bg" in r["kv"]:
                        bg[y][x] = bgv
            continue
        for yy, line in enumerate(r["ascii"]):
            for xx, ch in enumerate(line):
                if ch == " ":
                    continue
                x, y = r["at"][0] + xx, r["at"][1] + yy
                if not (0 <= x < W and 0 <= y < H):
                    errors.append(f"{r['id']}: fora do mapa {x},{y}")
                    continue
                bg[y][x] = bgv
                if ch in "#.-^":
                    grid[y][x] = ch
                elif ch == "~":
                    grid[y][x] = "~"
                elif ch == "B":
                    grid[y][x] = "."
                    ents.append(("breakable", x, y, idx))
                elif ch == "Z":
                    grid[y][x] = "Z"
                    ents.append(("cracked_floor", x, y, idx))
                else:
                    grid[y][x] = "."
                    if ch in DECOR:
                        decor.append((ch, x, y, idx))
                    elif ch.isdigit():
                        c = r["custom"].get(ch)
                        if not c:
                            errors.append(f"{r['id']}: dígito {ch} sem definição")
                        else:
                            ty = c[0]
                            if ty == "npc":
                                ty = "story_npc"
                            ents.append((ty, x, y, idx))
                    elif ch in ENTITY_CHARS:
                        ty = ENTITY_CHARS[ch]
                        if ty == "npc" and r["kv"].get("npcs"):
                            ty = "story_npc"
                        ents.append((ty, x, y, idx))
                    else:
                        errors.append(f"{r['id']}: caractere desconhecido '{ch}' em {x},{y}")
    def owner(x, y):
        best, ba = -1, 1 << 30
        for i, r in enumerate(out_rooms):
            x0, y0, rw, rh = r["rect"]
            if x0 <= x < x0 + rw and y0 <= y < y0 + rh and rw * rh < ba:
                best, ba = i, rw * rh
        return best
    ents[:] = [(ty, x, y, owner(x, y) if owner(x, y) >= 0 else idx) for (ty, x, y, idx) in ents]
    decor[:] = [(ch, x, y, owner(x, y) if owner(x, y) >= 0 else idx) for (ch, x, y, idx) in decor]
    for t in late:
        x, y = [int(v) for v in t[1].split(",")]
        ty = t[2]
        if ty == "npc":
            ty = "story_npc"
        if ty == "decor":
            decor.append(("d", x, y, owner(x, y)))
        else:
            ents.append((ty, x, y, owner(x, y)))
    for y in range(H):
        for x in range(W):
            if grid[y][x] not in "#" and owner(x, y) < 0:
                bg[y][x] = 0
    return {"W": W, "H": H, "grid": grid, "bg": bg, "rooms": out_rooms, "ents": ents, "decor": decor, "errors": errors, "abilities": abil}


# ---------------------------------------------------------------------------
# Alcance (porta do scripts/level/region/reach_map.gd)
# ---------------------------------------------------------------------------

class Reach:
    def __init__(self, m, blocked_rooms=(), gates_closed=True):
        global MAX_RISE, MAX_DX_FLAT, MAX_DX_RISE, MAX_DX_DOWN
        if "double_jump" in m.get("abilities", []):
            MAX_RISE, MAX_DX_FLAT, MAX_DX_RISE, MAX_DX_DOWN = 6, 8, 6, 10
        self.w, self.h = m["W"], m["H"]
        code = {"#": SOLID, "Z": SOLID, "-": ONE, "^": SPK}
        self.c = [[code.get(ch, AIR) for ch in row] for row in m["grid"]]
        # portões de habilidade e paredes quebráveis bloqueiam; portões de
        # combate ficam abertos; salas que exigem habilidade viram rocha
        for (ty, x, y, idx) in m["ents"]:
            if ty == "ability_gate":
                for k in range(4):
                    if 0 <= y + k < self.h:
                        self.c[y + k][x] = SOLID
            # paredes quebráveis: o jogador quebra (passáveis)
        for idx in blocked_rooms:
            x0, y0, rw, rh = m["rooms"][idx]["rect"]
            for y in range(y0, y0 + rh):
                for x in range(x0, x0 + rw):
                    if 0 <= y < self.h and 0 <= x < self.w:
                        self.c[y][x] = SOLID
        self.build()

    def at(self, x, y):
        if x < 0 or x >= self.w or y >= self.h:
            return SOLID
        if y < 0:
            return AIR
        return self.c[y][x]

    def free(self, x, y):
        a, b = self.at(x, y), self.at(x, y - 1)
        return a in (AIR, ONE) and b in (AIR, ONE)

    def stand(self, x, y):
        return self.free(x, y) and self.at(x, y + 1) in (SOLID, ONE)

    def build(self):
        self.segs = []
        self.seg_of = {}
        for y in range(self.h):
            x = 0
            while x < self.w:
                if not self.stand(x, y):
                    x += 1
                    continue
                x0 = x
                while x < self.w and self.stand(x, y):
                    self.seg_of[(x, y)] = len(self.segs)
                    x += 1
                self.segs.append((x0, x - 1, y))
        self.out = [set() for _ in self.segs]
        self.inn = [set() for _ in self.segs]
        by_row = {}
        for i, s in enumerate(self.segs):
            by_row.setdefault(s[2], []).append(i)
        for i, s in enumerate(self.segs):
            for dy in range(-MAX_RISE, 14):
                for j in by_row.get(s[2] + dy, []):
                    if j != i and self.link(s, self.segs[j]):
                        self.add(i, j)
            for x in (s[0] - 1, s[1] + 1):
                land = self.fall(x, s[2])
                if land >= 0 and land != i:
                    self.add(i, land)
            if self.at(s[0], s[2] + 1) == ONE:
                for x in (s[0], (s[0] + s[1]) // 2, s[1]):
                    if self.at(x, s[2] + 1) == ONE:
                        land = self.fall(x, s[2] + 1)
                        if land >= 0 and land != i:
                            self.add(i, land)

    def add(self, a, b):
        self.out[a].add(b)
        self.inn[b].add(a)

    def fall(self, x, y):
        if x < 0 or x >= self.w or not self.free(x, y):
            return -1
        yy = y
        while yy < self.h - 1:
            b = self.at(x, yy + 1)
            if b in (SOLID, ONE):
                return self.seg_of.get((x, yy), -1)
            if b == SPK:
                return -1
            yy += 1
        return -1

    def link(self, a, b):
        ay, by = a[2], b[2]
        rise = ay - by
        if rise > MAX_RISE:
            return False
        mdx = MAX_DX_FLAT
        if rise >= 2:
            mdx = MAX_DX_RISE
        elif rise < 0:
            mdx = min(MAX_DX_DOWN, MAX_DX_FLAT + (-rise) // 2)
        gap = 0
        if b[0] > a[1]:
            gap = b[0] - a[1]
        elif a[0] > b[1]:
            gap = a[0] - b[1]
        if gap > mdx:
            return False
        c = []
        if gap > 0:
            if b[0] > a[1]:
                c += [(a[1], b[0]), (a[1], min(b[0] + 1, b[1])), (max(a[1] - 1, a[0]), b[0])]
            else:
                c += [(a[0], b[1]), (a[0], max(b[1] - 1, b[0])), (min(a[0] + 1, a[1]), b[1])]
        else:
            lo, hi = max(a[0], b[0]), min(a[1], b[1])
            c += [(lo, lo), (hi, hi), ((lo + hi) // 2, (lo + hi) // 2)]
            if lo - 1 >= a[0]:
                c.append((lo - 1, lo))
            if hi + 1 <= a[1]:
                c.append((hi + 1, hi))
        return any(self.arc(x0, ay, x1, by) for x0, x1 in c)

    def arc(self, x0, y0, x1, y1):
        top = min(y0, y1) - (1 if y0 != y1 else 2)
        if y1 < y0:
            top = y1 - 1
        for y in range(y0, top - 1, -1):
            if not self.free(x0, y):
                return False
        step = 1 if x1 >= x0 else -1
        x = x0
        while x != x1:
            x += step
            if not self.free(x, top):
                return False
        for y in range(top, y1 + 1):
            if not self.free(x1, y):
                return False
        return True

    def seg_near(self, x, y):
        for d in [(0, 0), (0, 1), (0, -1), (1, 0), (-1, 0), (0, 2), (1, 1), (-1, 1)]:
            s = self.seg_of.get((x + d[0], y + d[1]))
            if s is not None:
                return s
        return -1

    def bfs(self, start, rev=False):
        seen = {start}
        q = [start]
        edges = self.inn if rev else self.out
        while q:
            u = q.pop()
            for v in edges[u]:
                if v not in seen:
                    seen.add(v)
                    q.append(v)
        return seen


def check(m, abilities=()):
    blocked = [i for i, r in enumerate(m["rooms"]) if r["kv"].get("requires") and r["kv"]["requires"] not in abilities]
    R = Reach(m, blocked)
    root = None
    for (ty, x, y, idx) in m["ents"]:
        if ty == "start":
            root = (x, y)
    if root is None:
        for (ty, x, y, idx) in m["ents"]:
            if ty == "checkpoint":
                root = (x, y)
                break
    bad = []
    if root is None:
        return ["sem ponto inicial (H ou start)"], [], R
    rs = R.seg_near(*root)
    if rs < 0:
        return ["ponto inicial sem chão"], [], R
    fwd = R.bfs(rs)
    back = R.bfs(rs, True)
    for (ty, x, y, idx) in m["ents"]:
        if ty not in ANCHORS or idx in blocked:
            continue
        s = R.seg_near(x, y)
        if s < 0:
            bad.append((ty, x, y, "sem chão"))
        elif s not in fwd:
            bad.append((ty, x, y, "inalcançável"))
        elif s not in back:
            bad.append((ty, x, y, "sem volta"))
    return [], bad, R


def render(m, out, bad=(), scale=6):
    W, H = m["W"], m["H"]
    img = Image.new("RGB", (W * scale, H * scale), (0, 0, 0))
    d = ImageDraw.Draw(img)
    g = m["grid"]
    for y in range(H):
        for x in range(W):
            ch = g[y][x]
            if ch in "#Z":
                edge = any(0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] not in "#Z" for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)])
                col = (104, 104, 132) if edge else (40, 40, 54)
                if ch == "Z":
                    col = (130, 90, 60)
            elif ch == "-":
                col = (176, 136, 80)
            elif ch == "^":
                col = (224, 64, 64)
            elif ch == "~":
                col = (48, 96, 160)
            else:
                col = (18, 18, 28) if m["bg"][y][x] else (34, 52, 84)
            d.rectangle([x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1], fill=col)
    for (ch, x, y, idx) in m["decor"]:
        d.rectangle([x * scale + 2, y * scale + 2, x * scale + scale - 3, y * scale + scale - 3], fill=(120, 130, 110))
    for (ty, x, y, idx) in m["ents"]:
        col = COLORS.get(ty, (200, 200, 200))
        if ty in ("gate", "ability_gate"):
            d.rectangle([x * scale + 1, y * scale, x * scale + scale - 2, (y + 4) * scale - 1], fill=col)
        else:
            d.rectangle([x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1], fill=col)
    font = ImageFont.load_default()
    for r in m["rooms"]:
        x0, y0, rw, rh = r["rect"]
        d.rectangle([x0 * scale, y0 * scale, (x0 + rw) * scale - 1, (y0 + rh) * scale - 1], outline=(90, 160, 200))
        d.text((x0 * scale + 3, y0 * scale + 2), r["name"] or r["id"], fill=(220, 230, 255), font=font)
    for (ty, x, y, why) in bad:
        cx, cy = x * scale + scale // 2, y * scale + scale // 2
        d.line([cx - 8, cy - 8, cx + 8, cy + 8], fill=(255, 0, 0), width=3)
        d.line([cx - 8, cy + 8, cx + 8, cy - 8], fill=(255, 0, 0), width=3)
    img.save(out)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ab = []
    for a in sys.argv[1:]:
        if a.startswith("--abilities="):
            ab = a.split("=", 1)[1].split(",")
    mid = args[0]
    out = args[1] if len(args) > 1 else f"/tmp/map_{mid}.png"
    m = parse(os.path.join(ROOT, "data", "maps", mid + ".txt"))
    for e in m["errors"]:
        print("ERRO:", e)
    errs, bad, R = check(m, ab)
    for e in errs:
        print("ERRO:", e)
    for b in bad:
        print("ALCANCE:", b)
    render(m, out, bad)
    print(f"{mid}: {m['W']}x{m['H']} tiles, {len(m['rooms'])} salas, {len(m['ents'])} entidades, {len(m['decor'])} decorações -> {out}")


if __name__ == "__main__":
    main()
