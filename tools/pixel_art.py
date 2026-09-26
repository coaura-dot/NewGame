#!/usr/bin/env python3
"""Gera TODA a arte do jogo (320x180, tiles de 8 px) a partir de código.

    python3 tools/pixel_art.py            # gera em assets/art/
    python3 tools/pixel_art.py --preview DIR   # também salva prévias ampliadas

Saídas:
  assets/art/hero/hero.png + hero.json        quadros do herói + âncoras (olhos, pescoço, mão)
  assets/art/enemies/<id>.png + <id>.json     folhas dos inimigos + animações
  assets/art/npcs/<espécie>.png + npcs.json   9 papéis x 3 quadros por espécie
  assets/art/tiles/<bioma>.png                atlas 8x8 (ver tools/world_art.py)
  assets/art/bg/<bioma>/0_sky.png 1_far.png 2_mid.png
  assets/art/props/*.png                      baú, porta, banco, mola, mural, altar...
  assets/art/items/items.png                  ícones 9x9 (categoria x raridade)

Para trocar a arte: edite os módulos hero_art/enemy_art/npc_art/prop_art/world_art
(tudo são primitivas simples + contorno automático) e rode de novo.
"""
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from px import Canvas, sheet, preview  # noqa: E402
import hero_art  # noqa: E402
import enemy_art  # noqa: E402
import npc_art  # noqa: E402
import prop_art  # noqa: E402
import world_art  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ART = os.path.join(ROOT, "assets", "art")


def ensure(p):
    os.makedirs(p, exist_ok=True)
    return p


def save(im, path):
    ensure(os.path.dirname(path))
    im.save(path)


def hero():
    F = hero_art.build()
    im, cols = sheet([f[1] for f in F], 8)
    save(im, os.path.join(ART, "hero", "hero.png"))
    meta = {"size": [16, 16], "cols": cols, "frames": {}}
    for i, (name, _c, m) in enumerate(F):
        meta["frames"][name] = dict(index=i, **m)
    with open(os.path.join(ART, "hero", "hero.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return im


def enemies():
    out = []
    for eid, fn in enemy_art.ALL.items():
        anims, meta = fn()
        frames = []
        info = {}
        for a, fl in anims.items():
            info[a] = {"start": len(frames), "count": len(fl), "fps": meta.get("fps", {}).get(a, 8)}
            frames += fl
        im, cols = sheet(frames)
        save(im, os.path.join(ART, "enemies", eid + ".png"))
        with open(os.path.join(ART, "enemies", eid + ".json"), "w") as f:
            json.dump({"size": meta["size"], "feet": meta["feet"], "cols": cols, "anims": info}, f, indent=1)
        out.append(im)
    return out


def npcs():
    roles = list(npc_art.ROLE)
    for sp in npc_art.SPECIES:
        frames = []
        for r in roles:
            frames += npc_art.npc_sheet(sp, r)
        im, cols = sheet(frames, 3)
        save(im, os.path.join(ART, "npcs", sp + ".png"))
    with open(os.path.join(ART, "npcs", "npcs.json"), "w") as f:
        json.dump({"size": [16, 16], "roles": roles, "species": list(npc_art.SPECIES)}, f, indent=1)


def props():
    d = os.path.join(ART, "props")
    save(sheet([prop_art.chest(False), prop_art.chest(True, 0), prop_art.chest(True, 1)])[0], os.path.join(d, "chest.png"))
    save(prop_art.door().im, os.path.join(d, "door.png"))
    save(sheet([prop_art.bench(False), prop_art.bench(True)])[0], os.path.join(d, "bench.png"))
    save(sheet([prop_art.spring(k) for k in range(4)])[0], os.path.join(d, "spring.png"))
    save(prop_art.board().im, os.path.join(d, "board.png"))
    save(prop_art.altar().im, os.path.join(d, "altar.png"))
    save(prop_art.pedestal().im, os.path.join(d, "pedestal.png"))
    save(prop_art.torch().im, os.path.join(d, "torch.png"))


RARITIES = ["common", "rare", "epic", "legendary", "set"]
RCOL = {"common": "d8d8d8", "rare": "73b3ff", "epic": "cc73ff", "legendary": "ffb840", "set": "80ff99"}
KINDS = ["weapon", "spell", "armor", "buff", "item", "key", "potion"]


def items():
    frames = []
    for k in KINDS:
        for r in RARITIES:
            frames.append(prop_art.item_icon(k, RCOL[r]))
    im, cols = sheet(frames, len(RARITIES))
    save(im, os.path.join(ART, "items", "items.png"))
    with open(os.path.join(ART, "items", "items.json"), "w") as f:
        json.dump({"size": [9, 9], "kinds": KINDS, "rarities": RARITIES}, f)


def world():
    for b in world_art.BIOMES:
        save(world_art.tileset(b).im, os.path.join(ART, "tiles", b + ".png"))
        for name, c in world_art.background(b).items():
            save(c.im, os.path.join(ART, "bg", b, name + ".png"))


def main():
    for old in ("characters", "tilesets", "backgrounds", "fx"):
        p = os.path.join(ART, old)
        if os.path.isdir(p):
            shutil.rmtree(p)
    for sub in ("props",):
        p = os.path.join(ART, sub)
        if os.path.isdir(p):
            shutil.rmtree(p)
    h = hero()
    en = enemies()
    npcs()
    props()
    items()
    world()
    if "--preview" in sys.argv:
        pd = ensure(sys.argv[sys.argv.index("--preview") + 1])
        preview(h, 6).save(os.path.join(pd, "hero.png"))
    print("arte gerada em", ART)


if __name__ == "__main__":
    main()
