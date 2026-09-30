#!/usr/bin/env python3
"""Confere a largura das linhas de cada sala de um mapa (data/maps/<id>.txt):
linhas mais curtas/longas que a maioria costumam ser erro de desenho."""
import collections
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
for mid in sys.argv[1:]:
    lines = open(os.path.join(ROOT, "data", "maps", mid + ".txt"), encoding="utf-8").read().split("\n")
    i = 0
    while i < len(lines):
        l = lines[i]
        i += 1
        if l.startswith("@room"):
            name = l.split()[1]
            rows = []
            while i < len(lines) and not lines[i].startswith("@end"):
                s = lines[i]
                i += 1
                st = s.strip()
                if st.startswith("//") or (len(st) >= 2 and st[0].isdigit() and st[1:].strip().startswith("=")):
                    continue
                rows.append(s)
            if not rows:
                continue
            c = collections.Counter(len(r) for r in rows)
            w = c.most_common(1)[0][0]
            bad = [(k, len(r)) for k, r in enumerate(rows) if len(r) != w]
            print(f"{mid}/{name}: {w}x{len(rows)}" + (f"  LINHAS DIFERENTES: {bad}" if bad else ""))
