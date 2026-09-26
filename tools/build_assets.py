#!/usr/bin/env python3
"""
Monta os assets placeholder (todos CC0) usados pelo protótipo.

Uso:
    python3 tools/build_assets.py <SRC_ROOT>

<SRC_ROOT> precisa conter:
    jra/    -> clone de https://github.com/series-ai/jam-ready-assets (com os PNG do LFS)
    extra/  -> mesmos caminhos do repo acima (fontes, sons, ícones) baixados avulsos

O script:
  * reempacota cada personagem numa sheet de células uniformes (pés alinhados
    embaixo, corpo centralizado) e gera o SpriteFrames .tres correspondente;
  * compõe um atlas de tiles 16x16 por bioma com layout de "papéis" fixo
    (topo, sub-superfície, preenchimento, bordas, plataformas, espinhos, deco,
    parede de fundo) que o TileSetBuilder.gd entende;
  * copia fundos parallax, props, efeitos, ícones, fontes e sons.

Tudo que sai daqui vai em assets/ e é versionado; o script só é necessário
para regenerar/editar os placeholders.
"""
import json
import os
import random
import shutil
import sys

from PIL import Image, ImageDraw, ImageEnhance

SRC = sys.argv[1] if len(sys.argv) > 1 else "/opt/assets-src"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets")

GV = os.path.join(SRC, "jra/ansimuz-gothicvania-collection/2D/fantasy")
CEM = os.path.join(SRC, "jra/ansimuz-gothicvania-cemetery/2D/seasonal-holiday/PNG")
PA = os.path.join(SRC, "jra/pixel-adventure/2D/platformer")
TH = os.path.join(SRC, "jra/treasure-hunters/2D/platformer/Merchant Ship/Sprites")
FZ = os.path.join(SRC, "jra/foozle-lucifer-effects/2D/misc/Effects")
EX = os.path.join(SRC, "extra")


def ensure(path):
    os.makedirs(path, exist_ok=True)
    return path


def res_path(abs_path):
    return "res://" + os.path.relpath(abs_path, ROOT).replace(os.sep, "/")


def load(path):
    return Image.open(path).convert("RGBA")


def split_sheet(path, count):
    im = load(path)
    w = im.width // count
    return [im.crop((i * w, 0, (i + 1) * w, im.height)) for i in range(count)]


def frames_from_files(folder, prefix):
    files = sorted(
        (f for f in os.listdir(folder) if f.startswith(prefix) and f.endswith(".png")),
        key=lambda f: int("".join(c for c in f[len(prefix):] if c.isdigit()) or 0),
    )
    return [load(os.path.join(folder, f)) for f in files]


# ---------------------------------------------------------------------------
# Personagens
# ---------------------------------------------------------------------------

def opaque_bbox(frames):
    box = None
    for f in frames:
        b = f.getchannel("A").getbbox()
        if not b:
            continue
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box or (0, 0, frames[0].width, frames[0].height)


def build_character(name, anims, faces="right", flying=False, pad=4):
    """anims: lista de dicts {name, frames:[Image], fps, loop, anchor_x (opcional)}.

    Cada animação é recortada pelo bbox opaco e colada numa célula uniforme,
    com o 'anchor_x' (centro do corpo) no centro da célula e o fundo do bbox
    na base da célula (ou centro vertical para voadores).
    """
    prepared = []
    cell_w = cell_h = 0
    for a in anims:
        frames = a["frames"]
        bb = opaque_bbox(frames)
        ax = a.get("anchor_x", (bb[0] + bb[2]) / 2.0)
        left = ax - bb[0]
        right = bb[2] - ax
        half_w = int(max(left, right) + 0.999)
        h = bb[3] - bb[1]
        cell_w = max(cell_w, half_w * 2)
        cell_h = max(cell_h, h)
        prepared.append((a, bb, ax))
    cell_w += pad * 2
    cell_h += pad * 2
    cols = max(len(a["frames"]) for a in anims)
    sheet = Image.new("RGBA", (cell_w * cols, cell_h * len(anims)), (0, 0, 0, 0))
    meta_anims = []
    for row, (a, bb, ax) in enumerate(prepared):
        for i, f in enumerate(a["frames"]):
            crop = f.crop(bb)
            x = int(round(i * cell_w + cell_w / 2.0 - (ax - bb[0])))
            if flying:
                y = row * cell_h + (cell_h - crop.height) // 2
            else:
                y = row * cell_h + cell_h - pad - crop.height
            sheet.alpha_composite(crop, (x, y))
        meta_anims.append({"name": a["name"], "row": row, "count": len(a["frames"]),
                           "fps": a["fps"], "loop": a["loop"]})
    folder = ensure(os.path.join(OUT, "art/characters", name))
    sheet_path = os.path.join(folder, name + "_sheet.png")
    sheet.save(sheet_path)
    write_sprite_frames(os.path.join(folder, name + "_frames.tres"), sheet_path, cell_w, cell_h, meta_anims)
    meta = {
        "name": name,
        "cell": [cell_w, cell_h],
        "faces": faces,
        "flying": flying,
        # deslocamento sugerido para o AnimatedSprite2D (centered=true) deixar os
        # pés na origem do nó (ou o centro, para voadores)
        "sprite_offset": [0, 0 if flying else -(cell_h / 2.0 - pad)],
        "animations": meta_anims,
    }
    with open(os.path.join(folder, name + "_meta.json"), "w") as fp:
        json.dump(meta, fp, indent=2)
    return meta


def write_sprite_frames(path, sheet_path, cw, ch, anims):
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="%s" id="1_sheet"]' % res_path(sheet_path), ""]
    sub_ids = {}
    n = 0
    for a in anims:
        for i in range(a["count"]):
            n += 1
            sid = "AtlasTexture_%d" % n
            sub_ids[(a["name"], i)] = sid
            lines += ['[sub_resource type="AtlasTexture" id="%s"]' % sid,
                      'atlas = ExtResource("1_sheet")',
                      "region = Rect2(%d, %d, %d, %d)" % (i * cw, a["row"] * ch, cw, ch), ""]
    lines.append("[resource]")
    anim_strs = []
    for a in anims:
        frames = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sub_ids[(a["name"], i)]
                            for i in range(a["count"]))
        anim_strs.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                         % (frames, "true" if a["loop"] else "false", a["name"], a["fps"]))
    lines.append("animations = [%s]" % ", ".join(anim_strs))
    lines.append("")
    with open(path, "w") as fp:
        fp.write("\n".join(lines))


def build_characters():
    hero = os.path.join(CEM, "Sprites/hero")
    build_character("hero", [
        {"name": "idle", "frames": frames_from_files(hero + "/hero-idle", "hero-idle-"), "fps": 6, "loop": True, "anchor_x": 52},
        {"name": "run", "frames": frames_from_files(hero + "/hero-run", "hero-run-"), "fps": 12, "loop": True, "anchor_x": 52},
        {"name": "jump", "frames": frames_from_files(hero + "/hero-jump", "hero-jump-")[:2], "fps": 10, "loop": False, "anchor_x": 54},
        {"name": "fall", "frames": frames_from_files(hero + "/hero-jump", "hero-jump-")[2:], "fps": 10, "loop": True, "anchor_x": 54},
        {"name": "attack", "frames": frames_from_files(hero + "/hero-attack", "hero-attack-"), "fps": 20, "loop": False, "anchor_x": 50},
        {"name": "crouch", "frames": frames_from_files(hero + "/hero-crouch", "hero-crouch"), "fps": 1, "loop": False, "anchor_x": 50},
        {"name": "hurt", "frames": frames_from_files(hero + "/hero-hurt", "hero-hurt"), "fps": 1, "loop": False, "anchor_x": 40},
    ], faces="right")

    sk = os.path.join(CEM, "Sprites")
    build_character("skeleton", [
        {"name": "walk", "frames": frames_from_files(sk + "/skeleton-clothed", "skeleton-clothed-"), "fps": 9, "loop": True},
        {"name": "rise", "frames": frames_from_files(sk + "/skeleton-rise-clothed", "skeleton-rise-clothed-"), "fps": 10, "loop": False},
    ], faces="left")
    build_character("wraith", [
        {"name": "idle", "frames": frames_from_files(sk + "/ghost-halo", "ghost-halo-"), "fps": 6, "loop": True},
    ], faces="right", flying=True)
    build_character("hellcat", [
        {"name": "run", "frames": frames_from_files(sk + "/hell-gato", "hell-gato-"), "fps": 10, "loop": True},
    ], faces="left")

    hh = os.path.join(GV, "Hell-Hound-Files/PNG")
    build_character("hound", [
        {"name": "idle", "frames": split_sheet(hh + "/hell-hound-idle.png", 6), "fps": 8, "loop": True},
        {"name": "walk", "frames": split_sheet(hh + "/hell-hound-walk.png", 12), "fps": 12, "loop": True},
        {"name": "run", "frames": split_sheet(hh + "/hell-hound-run.png", 5), "fps": 12, "loop": True},
        {"name": "jump", "frames": split_sheet(hh + "/hell-hound-jump.png", 6), "fps": 10, "loop": False},
    ], faces="left")

    build_character("fire_skull", [
        {"name": "idle", "frames": split_sheet(os.path.join(GV, "Fire-Skull-Files/PNG/fire-skull.png"), 8), "fps": 10, "loop": True},
    ], faces="left", flying=True)

    gh = os.path.join(GV, "Ghost-Files/PNG")
    build_character("ghost", [
        {"name": "idle", "frames": split_sheet(gh + "/ghost-idle.png", 7), "fps": 8, "loop": True},
        {"name": "shriek", "frames": split_sheet(gh + "/ghost-shriek.png", 4), "fps": 8, "loop": False},
        {"name": "appear", "frames": split_sheet(gh + "/ghost-appears.png", 6), "fps": 10, "loop": False},
        {"name": "vanish", "frames": split_sheet(gh + "/ghost-vanish.png", 7), "fps": 10, "loop": False},
    ], faces="left", flying=True)

    dm = os.path.join(GV, "demon-Files/PNG")
    build_character("demon", [
        {"name": "idle", "frames": split_sheet(dm + "/demon-idle.png", 6), "fps": 8, "loop": True},
        {"name": "attack", "frames": split_sheet(dm + "/demon-attack.png", 11), "fps": 10, "loop": False},
    ], faces="left", flying=True)

    hb = os.path.join(GV, "Hell-Beast-Files/PNG/without-stroke")
    build_character("hell_beast", [
        {"name": "idle", "frames": split_sheet(hb + "/hell-beast-idle.png", 6), "fps": 8, "loop": True},
        {"name": "breath", "frames": split_sheet(hb + "/hell-beast-breath.png", 4), "fps": 8, "loop": False},
    ], faces="left")

    nm = os.path.join(GV, "Nightmare-Files/PNG")
    build_character("nightmare", [
        {"name": "idle", "frames": split_sheet(nm + "/nightmare-idle.png", 4), "fps": 6, "loop": True},
        {"name": "gallop", "frames": split_sheet(nm + "/nightmare-galloping.png", 4), "fps": 10, "loop": True},
    ], faces="left")


# ---------------------------------------------------------------------------
# Tilesets por bioma
# ---------------------------------------------------------------------------
# Layout do atlas (colunas x linhas de 16 px), igual para todos os biomas:
#   linha 0: TOP 0-3 (sólido)        | 4 TOP_L | 5 TOP_R | 6 TOP_SINGLE | 7 BREAKABLE
#   linha 1: SUB 0-3 (sólido)        | 4 PLAT_L | 5 PLAT_M | 6 PLAT_R | 7 SPIKES
#   linha 2: FILL 0-3 (sólido)       | 4 EDGE_L | 5 EDGE_R | 6 CEIL | 7 CORNER_DOT
#   linha 3: DECO_TOP 0-3 (sem col.) | 4-7 BG_WALL (sem colisão)
T = 16


def tile(img, tx, ty, w=1, h=1):
    return img.crop((tx * T, ty * T, (tx + w) * T, (ty + h) * T))


def darken(im, f):
    return ImageEnhance.Brightness(im).enhance(f)


def edge_overlay(side, dark=(8, 6, 16, 255), rim=(255, 240, 200, 60)):
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if side == "L":
        d.rectangle([0, 0, 1, T - 1], fill=dark)
        d.line([2, 0, 2, T - 1], fill=rim)
    elif side == "R":
        d.rectangle([T - 2, 0, T - 1, T - 1], fill=dark)
        d.line([T - 3, 0, T - 3, T - 1], fill=rim)
    elif side == "B":
        d.rectangle([0, T - 3, T - 1, T - 1], fill=dark)
        for x in range(0, T, 4):
            d.line([x + 1, T - 4, x + 1, T - 6], fill=dark)
    elif side == "DOT":
        d.rectangle([0, 0, 2, 2], fill=dark)
    return im


def cracked(im):
    im = im.copy()
    d = ImageDraw.Draw(im)
    c = (10, 8, 14, 255)
    d.line([3, 1, 7, 6, 5, 10, 9, 15], fill=c)
    d.line([7, 6, 12, 4, 14, 8], fill=c)
    d.line([5, 10, 2, 13], fill=c)
    return im


def plain_fill(color, seed):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (T, T), color)
    px = im.load()
    for _ in range(10):
        x, y = rnd.randrange(T), rnd.randrange(T)
        r, g, b, a = color
        k = rnd.choice([-6, 6, 10])
        px[x, y] = (max(0, min(255, r + k)), max(0, min(255, g + k)), max(0, min(255, b + k)), a)
    return im


def compose_biome(name, parts):
    atlas = Image.new("RGBA", (8 * T, 4 * T), (0, 0, 0, 0))

    def put(im, cx, cy):
        atlas.alpha_composite(im.convert("RGBA").resize((T, T), Image.NEAREST) if im.size != (T, T) else im, (cx * T, cy * T))

    for i, im in enumerate(parts["top"][:4]):
        put(im, i, 0)
    put(parts.get("top_l", parts["top"][0]), 4, 0)
    put(parts.get("top_r", parts["top"][1]), 5, 0)
    put(parts.get("top_single", parts["top"][2]), 6, 0)
    put(cracked(parts["fill"][0]), 7, 0)
    for i, im in enumerate(parts["sub"][:4]):
        put(im, i, 1)
    put(parts["plat"][0], 4, 1)
    put(parts["plat"][1], 5, 1)
    put(parts["plat"][2], 6, 1)
    put(parts["spikes"], 7, 1)
    for i, im in enumerate(parts["fill"][:4]):
        put(im, i, 2)
    put(edge_overlay("L"), 4, 2)
    put(edge_overlay("R"), 5, 2)
    put(edge_overlay("B"), 6, 2)
    put(edge_overlay("DOT"), 7, 2)
    for i, im in enumerate(parts["deco"][:4]):
        put(im, i, 3)
    for i, im in enumerate(parts["bg"][:4]):
        put(im, 4 + i, 3)
    folder = ensure(os.path.join(OUT, "art/tilesets"))
    atlas.save(os.path.join(folder, name + ".png"))


def build_tilesets():
    spikes = load(os.path.join(PA, "Traps/Spikes/Idle.png"))

    # Cemitério / floresta morta
    cem = load(os.path.join(CEM, "Environment/tileset.png"))
    compose_biome("cemetery", {
        "top": [tile(cem, 4, 4), tile(cem, 5, 4), tile(cem, 6, 4), tile(cem, 7, 4)],
        "top_l": tile(cem, 1, 4), "top_r": tile(cem, 7, 4), "top_single": tile(cem, 11, 4),
        "sub": [tile(cem, 4, 5), tile(cem, 5, 5), tile(cem, 6, 5), tile(cem, 1, 5)],
        "fill": [tile(cem, 2, 6), tile(cem, 11, 6), tile(cem, 1, 6), tile(cem, 12, 6)],
        "plat": [tile(cem, 14, 3), tile(cem, 15, 3), tile(cem, 15, 3)],
        "spikes": tile(cem, 8, 4),
        "deco": [tile(cem, 4, 3), tile(cem, 5, 3), tile(cem, 6, 3), tile(cem, 7, 3)],
        "bg": [darken(tile(cem, 2, 5), 0.35), darken(tile(cem, 5, 5), 0.35), darken(tile(cem, 6, 5), 0.35), darken(tile(cem, 4, 5), 0.35)],
    })

    # Castelo sombrio (interior)
    odc = load(os.path.join(GV, "Old-dark-Castle-tileset-Files/PNG/old-dark-castle-interior-tileset.png"))
    compose_biome("castle", {
        "top": [tile(odc, 20, 10), tile(odc, 21, 10), tile(odc, 23, 10), tile(odc, 24, 10)],
        "top_l": tile(odc, 38, 10), "top_r": tile(odc, 39, 10), "top_single": tile(odc, 29, 10),
        "sub": [tile(odc, 17, 11), tile(odc, 18, 11), tile(odc, 20, 11), tile(odc, 21, 11)],
        "fill": [tile(odc, 17, 13), tile(odc, 18, 13), tile(odc, 20, 13), tile(odc, 23, 13)],
        "plat": [tile(odc, 26, 9), tile(odc, 27, 9), tile(odc, 29, 9)],
        "spikes": spikes,
        "deco": [tile(odc, 20, 9), tile(odc, 21, 9), tile(odc, 23, 9), tile(odc, 24, 9)],
        "bg": [darken(tile(odc, 17, 12), 0.45), darken(tile(odc, 18, 12), 0.45), darken(tile(odc, 20, 12), 0.45), darken(tile(odc, 21, 12), 0.45)],
    })

    # Cidade gótica / ruínas de tijolo
    gh = load(os.path.join(GV, "Gothic-Horror-Files/PNG/layers/tiles.png"))
    compose_biome("town", {
        "top": [tile(gh, 3, 1), tile(gh, 4, 1), tile(gh, 5, 1), tile(gh, 2, 4)],
        "top_l": tile(gh, 2, 1), "top_r": tile(gh, 6, 1), "top_single": tile(gh, 12, 4),
        "sub": [tile(gh, 26, 0), tile(gh, 26, 2), tile(gh, 24, 6), tile(gh, 25, 6)],
        "fill": [tile(gh, 0, 0), tile(gh, 0, 2), tile(gh, 0, 4), tile(gh, 0, 8)],
        "plat": [tile(gh, 2, 1), tile(gh, 4, 1), tile(gh, 6, 1)],
        "spikes": spikes,
        "deco": [tile(gh, 3, 4), tile(gh, 4, 4), tile(gh, 21, 7), tile(gh, 22, 7)],
        "bg": [darken(tile(gh, 24, 6), 0.4), darken(tile(gh, 25, 6), 0.4), darken(tile(gh, 26, 6), 0.4), darken(tile(gh, 21, 4), 0.4)],
    })

    # Templo dourado / catacumbas (lajes 32x32 quebradas em quartos)
    gc = load(os.path.join(GV, "Gothic-Castle-Files/PNG/layers/gothic-castle-tileset.png"))
    slab = tile(gc, 12, 6, 2, 2)
    slab2 = tile(gc, 15, 12, 2, 2)
    q = lambda im, x, y: im.crop((x * T, y * T, (x + 1) * T, (y + 1) * T))
    compose_biome("temple", {
        "top": [tile(gc, 2, 2), tile(gc, 3, 2), tile(gc, 2, 2), tile(gc, 3, 2)],
        "top_l": tile(gc, 2, 2), "top_r": tile(gc, 3, 2), "top_single": tile(gc, 5, 2),
        "sub": [tile(gc, 2, 3), tile(gc, 3, 3), tile(gc, 2, 3), tile(gc, 3, 3)],
        "fill": [q(slab, 0, 0), q(slab, 1, 0), q(slab2, 0, 1), q(slab2, 1, 1)],
        "plat": [tile(gc, 5, 2), tile(gc, 5, 2), tile(gc, 5, 2)],
        "spikes": spikes,
        "deco": [Image.new("RGBA", (T, T))] * 4,
        "bg": [darken(tile(gc, 2, 3), 0.35), darken(tile(gc, 3, 3), 0.35), darken(q(slab, 0, 1), 0.3), darken(q(slab, 1, 1), 0.3)],
    })


# ---------------------------------------------------------------------------
# Fundos, props, efeitos, ícones, fontes e sons
# ---------------------------------------------------------------------------

def copy(src, dst):
    ensure(os.path.dirname(dst))
    shutil.copyfile(src, dst)


def build_backgrounds():
    bg = os.path.join(OUT, "art/backgrounds")
    nt = os.path.join(GV, "night-town-background-files/layers")
    for i, n in enumerate(["sky", "mountains", "mountains-lights", "clouds", "far-buildings", "forest", "town"]):
        copy(os.path.join(nt, "night-town-background-%s.png" % n), os.path.join(bg, "town/%d_%s.png" % (i, n)))
    copy(os.path.join(CEM, "Environment/background.png"), os.path.join(bg, "cemetery/0_sky.png"))
    copy(os.path.join(CEM, "Environment/mountains.png"), os.path.join(bg, "cemetery/1_mountains.png"))
    copy(os.path.join(CEM, "Environment/graveyard.png"), os.path.join(bg, "cemetery/2_graveyard.png"))
    copy(os.path.join(GV, "Old-dark-Castle-tileset-Files/PNG/old-dark-castle-interior-background.png"), os.path.join(bg, "castle/0_hall.png"))
    copy(os.path.join(GV, "Gothic-Castle-Files/PNG/layers/gothic-castle-background.png"), os.path.join(bg, "temple/0_hall.png"))
    copy(os.path.join(GV, "Gothic-Horror-Files/PNG/layers/clouds.png"), os.path.join(bg, "temple/1_clouds.png"))
    copy(os.path.join(GV, "Gothic-Horror-Files/PNG/layers/town.png"), os.path.join(bg, "town/8_houses.png"))


def build_props():
    pr = os.path.join(OUT, "art/props")
    for f in os.listdir(os.path.join(CEM, "Environment/sliced-objects")):
        copy(os.path.join(CEM, "Environment/sliced-objects", f), os.path.join(pr, "cemetery", f))
    copy(os.path.join(PA, "Traps/Saw/On (38x38).png"), os.path.join(pr, "traps/saw_on.png"))
    copy(os.path.join(PA, "Traps/Saw/Chain.png"), os.path.join(pr, "traps/chain.png"))
    copy(os.path.join(PA, "Traps/Trampoline/Idle.png"), os.path.join(pr, "traps/trampoline_idle.png"))
    copy(os.path.join(PA, "Traps/Trampoline/Jump (28x28).png"), os.path.join(pr, "traps/trampoline_jump.png"))
    copy(os.path.join(PA, "Traps/Falling Platforms/On (32x10).png"), os.path.join(pr, "traps/falling_platform.png"))
    copy(os.path.join(PA, "Traps/Fire/On (16x32).png"), os.path.join(pr, "traps/fire_on.png"))
    copy(os.path.join(PA, "Traps/Spike Head/Idle.png"), os.path.join(pr, "traps/spike_head.png"))
    copy(os.path.join(PA, "Items/Checkpoints/Checkpoint/Checkpoint (Flag Idle)(64x64).png"), os.path.join(pr, "checkpoint_idle.png"))
    copy(os.path.join(PA, "Items/Boxes/Box2/Idle.png"), os.path.join(pr, "crate.png"))
    copy(os.path.join(PA, "Items/Boxes/Box2/Break.png"), os.path.join(pr, "crate_break.png"))
    copy(os.path.join(PA, "Other/Dust Particle.png"), os.path.join(OUT, "art/fx/dust.png"))
    # Baú (Treasure Hunters)
    chest = [load(os.path.join(TH, "Chest/Unlocked/%d.png" % i)) for i in range(1, 9)]
    sheet = Image.new("RGBA", (32 * len(chest), 32))
    for i, c in enumerate(chest):
        sheet.alpha_composite(c, (i * 32, 0))
    sheet.save(os.path.join(ensure(pr), "chest_open.png"))
    copy(os.path.join(TH, "Chest/Idle/1.png"), os.path.join(pr, "chest_idle.png"))
    copy(os.path.join(TH, "Chest/Padlock/1.png"), os.path.join(pr, "chest_padlock.png"))
    # Objetos do cemitério (atlas grande) e tiles decorativos da cidade (lanternas)
    copy(os.path.join(CEM, "Environment/objects.png"), os.path.join(pr, "cemetery/objects_atlas.png"))
    gh = load(os.path.join(GV, "Gothic-Horror-Files/PNG/layers/tiles.png"))
    tile(gh, 17, 7, 2, 3).save(os.path.join(ensure(pr), "lantern_arch.png"))
    odc = load(os.path.join(GV, "Old-dark-Castle-tileset-Files/PNG/old-dark-castle-interior-tileset.png"))
    odc.crop((656, 64, 704, 112)).save(os.path.join(pr, "door.png"))


def build_fx():
    fx = ensure(os.path.join(OUT, "art/fx"))
    copy(os.path.join(GV, "Hell-Beast-Files/PNG/fire-ball.png"), os.path.join(fx, "fireball.png"))
    copy(os.path.join(GV, "demon-Files/PNG/breath-fire.png"), os.path.join(fx, "breath_fire.png"))
    copy(os.path.join(GV, "demon-Files/PNG/breath.png"), os.path.join(fx, "breath.png"))
    ed = [load(os.path.join(CEM, "Sprites/enemy-death/enemy-death-%d.png" % i)) for i in range(1, 6)]
    sheet = Image.new("RGBA", (44 * 5, 52))
    for i, im in enumerate(ed):
        sheet.alpha_composite(im, (i * 44, 0))
    sheet.save(os.path.join(fx, "enemy_death.png"))
    copy(os.path.join(FZ, "VFX/Destroy Effect.png"), os.path.join(fx, "destroy.png"))
    copy(os.path.join(FZ, "Wave/Big/Right/WaveBigRight.png"), os.path.join(fx, "wave_right.png"))
    copy(os.path.join(FZ, "Wave/Big/Up/WaveBigUp.png"), os.path.join(fx, "wave_up.png"))
    copy(os.path.join(FZ, "Wave/Big/Down/WaveBigDown.png"), os.path.join(fx, "wave_down.png"))
    for f in os.listdir(os.path.join(FZ, "Pickup effects/Png")):
        copy(os.path.join(FZ, "Pickup effects/Png", f), os.path.join(fx, "pickup", f.replace(" Pickup effect", "").replace(" ", "_").lower()))
    for f in os.listdir(os.path.join(FZ, "Rarity Effects/Png")):
        copy(os.path.join(FZ, "Rarity Effects/Png", f), os.path.join(fx, "rarity", f.replace(" effect", "").replace(" ", "_").lower()))


def build_icons_fonts_audio():
    items = os.path.join(EX, "16x16-rpg-item-pack/2D/top-down-rpg")
    ic = ensure(os.path.join(OUT, "art/icons/items"))
    for f in sorted(os.listdir(items)):
        if f.startswith("Item__") and f.endswith(".png"):
            copy(os.path.join(items, f), os.path.join(ic, f.lower()))
    fonts = os.path.join(EX, "kenney-fonts/fonts")
    for f, n in [("Kenney Pixel.ttf", "kenney_pixel.ttf"), ("Kenney Mini.ttf", "kenney_mini.ttf"), ("Kenney High.ttf", "kenney_high.ttf")]:
        copy(os.path.join(fonts, f), os.path.join(OUT, "fonts", n))
    sfx = ensure(os.path.join(OUT, "audio/sfx"))
    for pack in ["kenney-foley-sounds", "kenney-retro-sounds-1", "kenney-sci-fi-sounds", "kenney-impact-sounds",
                 "kenney-rpg-audio", "kenney-interface-sounds"]:
        base = os.path.join(EX, pack)
        for d, _, files in os.walk(base):
            for f in files:
                if f.endswith(".ogg"):
                    copy(os.path.join(d, f), os.path.join(sfx, f))


LICENSES = [
    ("Gothicvania Patreon Collection / Cemetery — Luis Zuno (ansimuz)", "CC0 1.0", "https://opengameart.org/content/gothicvania-patreons-collection"),
    ("Pixel Adventure / Treasure Hunters — Pixel Frog", "CC0 1.0", "https://pixelfrog-assets.itch.io"),
    ("Lucifer Effects — Foozle (Baldur)", "CC0 1.0", "https://foozlecc.itch.io/lucifer-effects"),
    ("16x16 RPG Item Pack — Alex's Assets", "CC0 1.0", "https://alexs-assets.itch.io/16x16-rpg-item-pack"),
    ("Kenney Fonts / Foley / Impact / RPG / Interface / Retro / Sci-fi sounds — Kenney", "CC0 1.0", "https://kenney.nl"),
]


def write_credits():
    lines = ["# Créditos dos placeholders", "",
             "Todos os assets de arte/áudio deste protótipo são **placeholders CC0** (domínio público).",
             "Obtidos via https://github.com/series-ai/jam-ready-assets e remontados por `tools/build_assets.py`.",
             "Crédito não é obrigatório, mas fica registrado:", ""]
    for name, lic, url in LICENSES:
        lines.append("- **%s** — %s — %s" % (name, lic, url))
    lines.append("")
    with open(os.path.join(OUT, "CREDITS.md"), "w") as fp:
        fp.write("\n".join(lines))


if __name__ == "__main__":
    ensure(OUT)
    build_characters()
    build_tilesets()
    build_backgrounds()
    build_props()
    build_fx()
    build_icons_fonts_audio()
    write_credits()
    print("assets gerados em", OUT)
