#!/usr/bin/env python3
"""Valida templates de sala: tamanho 40x24, saídas declaradas abertas e
conectadas entre si (flood fill ignorando gravidade)."""
import glob, sys
W, H = 40, 24
LR_ROWS = range(17, 21); UD_COLS = range(18, 22)
BLOCK = set("#^")

def parse(path):
    rooms = []; cur = None
    for line in open(path, encoding="utf-8").read().split("\n"):
        if line.startswith("#") and cur is None: continue
        if line.startswith("@room"):
            cur = {"id": line.split()[1], "rows": [], "meta": {}}; continue
        if line.startswith("@end"):
            rooms.append(cur); cur = None; continue
        if cur is None: continue
        if ":" in line and not cur["rows"] and not line.startswith(("#", ".")):
            k, v = line.split(":", 1); cur["meta"][k.strip()] = v.strip(); continue
        if line.strip() == "" and not cur["rows"]: continue
        cur["rows"].append(line)
    return rooms

def exit_cells(e):
    if e == "L": return [(0, y) for y in LR_ROWS]
    if e == "R": return [(W - 1, y) for y in LR_ROWS]
    if e == "U": return [(x, 0) for x in UD_COLS]
    if e == "D": return [(x, H - 1) for x in UD_COLS]

def check(room):
    errs = []
    rows = room["rows"]
    if len(rows) != H: errs.append(f"{len(rows)} linhas (esperado {H})")
    for i, r in enumerate(rows):
        if len(r) != W: errs.append(f"linha {i} com {len(r)} colunas")
    if errs: return errs
    exits = room["meta"].get("exits", "")
    for e in exits:
        for (x, y) in exit_cells(e):
            if rows[y][x] in BLOCK: errs.append(f"saída {e} bloqueada em {x},{y}")
    if errs or len(exits) < 2: return errs
    sx, sy = exit_cells(exits[0])[0]
    seen = {(sx, sy)}; st = [(sx, sy)]
    while st:
        x, y = st.pop()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen and rows[ny][nx] not in BLOCK:
                seen.add((nx, ny)); st.append((nx, ny))
    for e in exits[1:]:
        if not any(c in seen for c in exit_cells(e)): errs.append(f"saída {e} não conecta com {exits[0]}")
    return errs

ok = True
for f in sorted(glob.glob("data/rooms/*.txt")):
    for room in parse(f):
        errs = check(room)
        status = "OK" if not errs else "ERRO: " + "; ".join(errs)
        if errs: ok = False
        print(f"{room['id']:20s} {room['meta'].get('type',''):12s} {room['meta'].get('exits',''):5s} {status}")
sys.exit(0 if ok else 1)
