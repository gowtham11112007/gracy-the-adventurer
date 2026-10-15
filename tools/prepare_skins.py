"""Turn the CraftPix tile packs (art/packs/platformer) into level "skins" for the Godot game.

Run from the project folder:  .venv/bin/python tools/prepare_skins.py
Writes godot/assets/skins/<skin>/... and godot/data/skins.json.
Each skin: ground tiles 1-16 (the packs' standard numbering: 1-3 grass top left/middle/right,
4-6 dirt left/middle/right, 13-15 floating platform left/middle/right), background layers,
and decorations sorted by size (trees, bushes, small things, rocks).
"""
import json
import os
from PIL import Image, ImageDraw

PACKS = "art/packs/platformer"
OUT = "godot/assets/skins"
TILE = 64

SKY_P = "sky-ruins-2d-platformer-tileset/PNG/Platfromer/Sky_Ruins_2D_Platformer_Tileset_Platformer - "
SKY_ENV = "sky-ruins-2d-platformer-tileset/PNG/Environment/Sky_Ruins_2D_Platformer_Tileset_Environment - "

SKINS = {
    "meadow": {
        "tiles": "freetileset/png/Tiles/{}.png",
        "block": "freetileset/png/Object/Crate.png",
        # a painted sunlit forest in three layers (sky, far trees, near trees) instead of the flat pale hills
        "bg": ["../backgrounds/cartoon-forest-backgrounds/PNG/Cartoon_Forest_BG_03/Layers/Sky.png",
               "../backgrounds/cartoon-forest-backgrounds/PNG/Cartoon_Forest_BG_03/Layers/BG_Decor.png",
               "../backgrounds/cartoon-forest-backgrounds/PNG/Cartoon_Forest_BG_03/Layers/Middle_Decor.png"],
        "deco": {
            "tree": ["freetileset/png/Object/Tree_2.png", "freetileset/png/Object/Tree_3.png"],
            "bush": ["freetileset/png/Object/Bush (1).png", "freetileset/png/Object/Bush (2).png"],
            "small": ["freetileset/png/Object/Bush (3).png", "freetileset/png/Object/Bush (4).png",
                      "freetileset/png/Object/Mushroom_1.png", "freetileset/png/Object/Mushroom_2.png"],
            "rock": ["freetileset/png/Object/Stone.png"],
            "sign": ["freetileset/png/Object/Sign_2.png"],
        },
    },
    "sky": {
        "tiles": {
            1: f"{SKY_P}Ground 04.png",   # top-left edge
            2: f"{SKY_P}Ground 02.png",   # top-middle grass surface
            3: f"{SKY_P}Ground 08.png",   # top-right edge
            4: f"{SKY_P}Ground 09.png",   # middle-left cliff
            5: f"{SKY_P}Ground 06.png",   # middle solid stone
            6: f"{SKY_P}Ground 13.png",   # middle-right cliff
            7: f"{SKY_P}Ground 10.png",   # bottom-left rock
            8: f"{SKY_P}Ground 11.png",   # bottom-middle rock
            9: f"{SKY_P}Ground 12.png",   # bottom-right rock
            10: f"{SKY_P}Ground 05.png",  # inner corner left
            11: f"{SKY_P}Ground 07.png",  # inner corner right
            12: f"{SKY_P}Stone.png",      # stone block
            13: f"{SKY_P}Ground 10.png",  # floating platform left
            14: f"{SKY_P}Ground 11.png",  # floating platform middle
            15: f"{SKY_P}Ground 12.png",  # floating platform right
            16: f"{SKY_P}Ground 06.png",  # solid stone
        },
        "float": [13, 14, 15],
        "block": f"{SKY_P}Wooden Box.png",
        "bg": ["sky-ruins-2d-platformer-tileset/PNG/Background/Sky_Ruins_2D_Platformer_Tileset_Background - Layer 00.png",
               "sky-ruins-2d-platformer-tileset/PNG/Background/Sky_Ruins_2D_Platformer_Tileset_Background - Layer 01.png"],
        "deco": {
            "tree": [f"{SKY_ENV}Tree.png", f"{SKY_ENV}Column.png", f"{SKY_ENV}Abandoned columns.png"],
            "bush": [f"{SKY_ENV}Part wall.png", f"{SKY_ENV}Old brick wall.png", f"{SKY_ENV}Fence 01.png", f"{SKY_ENV}Fence 02.png"],
            "small": [f"{SKY_ENV}Grass.png", f"{SKY_ENV}Magic stone 01.png", f"{SKY_ENV}Magic stone 02.png", f"{SKY_ENV}Pad.png"],
            "rock": [f"{SKY_ENV}Rock 0{i}.png" for i in range(1, 7)] + [f"{SKY_ENV}Stone 01.png", f"{SKY_ENV}Stone 02.png", f"{SKY_ENV}Big stone.png"],
            "sign": [f"{SKY_ENV}Signpost 0{i}.png" for i in (1, 2, 3, 4, 5, 6)],
        },
    },
    "desert": {
        "tiles": "deserttileset/png/Tile/{}.png",
        "block": "deserttileset/png/Objects/StoneBlock.png",
        "bg": ["deserttileset/png/BG.png"],
        "deco": {
            "tree": ["deserttileset/png/Objects/Tree.png", "deserttileset/png/Objects/Cactus (1).png"],
            "bush": ["deserttileset/png/Objects/Bush (1).png", "deserttileset/png/Objects/Cactus (3).png"],
            "small": ["deserttileset/png/Objects/Grass (1).png", "deserttileset/png/Objects/Grass (2).png",
                      "deserttileset/png/Objects/Cactus (2).png"],
            "rock": ["deserttileset/png/Objects/Stone.png", "deserttileset/png/Objects/Skeleton.png"],
            "sign": ["deserttileset/png/Objects/SignArrow.png"],
        },
    },
    "graveyard": {
        "tiles": "graveyardtilesetnew/png/Tiles/Tile ({}).png",
        "block": "graveyardtilesetnew/png/Objects/Crate.png",
        "bg": ["graveyardtilesetnew/png/BG.png"],
        "deco": {
            "tree": ["graveyardtilesetnew/png/Objects/Tree.png"],
            "bush": ["graveyardtilesetnew/png/Objects/Bush (1).png", "graveyardtilesetnew/png/Objects/DeadBush.png"],
            "small": ["graveyardtilesetnew/png/Objects/TombStone (1).png", "graveyardtilesetnew/png/Objects/TombStone (2).png",
                      "graveyardtilesetnew/png/Objects/Bush (2).png"],
            "rock": ["graveyardtilesetnew/png/Objects/Skeleton.png"],
            "sign": ["graveyardtilesetnew/png/Objects/ArrowSign.png"],
        },
    },
}
# the packs are drawn for 128 px tiles; our tiles are 64, so everything is halved,
# except decorations, which are drawn a little bigger so they suit Janani's size
DECO_SCALE = {"tree": 0.8, "bush": 0.65, "small": 0.6, "rock": 0.6, "sign": 0.6}

data = {}
for name, skin in SKINS.items():
    out = f"{OUT}/{name}"
    os.makedirs(out, exist_ok=True)
    info = {"tiles": [], "bg": [], "deco": {}}
    tiles_spec = skin["tiles"]
    for n in range(1, 17):
        if isinstance(tiles_spec, dict):
            rel = tiles_spec.get(n)
            if not rel:
                continue
            path = f"{PACKS}/{rel}"
        else:
            path = f"{PACKS}/{tiles_spec.format(n)}"
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGBA")
        f = TILE / im.width
        im = im.resize((TILE, max(1, round(im.height * f))), Image.LANCZOS)
        im.save(f"{out}/tile_{n}.png")
        info["tiles"].append(n)
        box = im.getbbox()
        if (box and box[3] - box[1] < TILE - 4) or (n in skin.get("float", [])):
            info.setdefault("float", []).append(n)  # the short pieces: floating platform left/middle/right
    for i, path in enumerate(skin["bg"]):
        im = Image.open(f"{PACKS}/{path}").convert("RGBA")
        f = 720 / im.height
        im = im.resize((round(im.width * f), 720), Image.LANCZOS)
        im = im.crop((3, 0, im.width - 3, 720))  # the packs' edges are slightly see-through: a thin line at the join
        # the picture and its mirror image side by side: repeats forever with no visible seam
        wide = Image.new("RGBA", (im.width * 2, 720))
        wide.paste(im, (0, 0))
        wide.paste(im.transpose(Image.FLIP_LEFT_RIGHT), (im.width, 0))
        wide.save(f"{out}/bg_{i}.png")
        info["bg"].append(f"bg_{i}")
    # bricks and crates: the pack's crate (the desert's sand-stone block), one tile big
    Image.open(f"{PACKS}/{skin['block']}").convert("RGBA").resize((TILE, TILE), Image.LANCZOS).save(f"{out}/block.png")
    for group, paths in skin["deco"].items():
        info["deco"][group] = []
        for i, path in enumerate(paths):
            im = Image.open(f"{PACKS}/{path}").convert("RGBA")
            f = DECO_SCALE[group]
            im.resize((round(im.width * f), round(im.height * f)), Image.LANCZOS).save(f"{out}/{group}_{i}.png")
            info["deco"][group].append(f"{group}_{i}")
    data[name] = info
with open("godot/data/skins.json", "w") as fh:
    json.dump(data, fh, indent=1)
print({k: len(v["tiles"]) for k, v in data.items()})


# ---- Pieces shared by every level, in the packs' cartoon style ----
# Saved in godot/assets/pack/ under the same names as the old pixel-art pictures:
# Game.texture() uses these first, so the whole game changes over.
SHARED = "godot/assets/pack"
CAVES = f"{PACKS}/crystal-caves-2d-platformer-tileset/PNG"
INK = (43, 26, 16, 255)  # the packs' dark brown outline


def fit(im, w, h, bottom=False):
    """Trim the empty edges, shrink to fit w x h, and centre it (or stand it on the bottom edge)."""
    im = im.crop(im.getbbox())
    f = min(w / im.width, h / im.height)
    im = im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS)
    out = Image.new("RGBA", (w, h))
    out.paste(im, ((w - im.width) // 2, h - im.height if bottom else (h - im.height) // 2))
    return out


def hue_shift(im, degrees):
    """Turn the colours around the colour wheel (the blue mana crystal becomes a purple gem)."""
    hsv = im.convert("RGB").convert("HSV")
    h, s_, v = hsv.split()
    h = h.point(lambda x: (x + round(degrees * 255 / 360)) % 256)
    out = Image.merge("HSV", (h, s_, v)).convert("RGBA")
    out.putalpha(im.getchannel("A"))
    return out


os.makedirs(SHARED, exist_ok=True)
# the gem: three frames of a turning crystal (full, half turned, edge on)
gem = fit(hue_shift(Image.open(f"{CAVES}/Collectable Object/Crystal_Caves_Forest_2D_Platformer_Tileset_Collectable Object - Mana.png").convert("RGBA"), 75), 32, 42)
strip = Image.new("RGBA", (96, 42))
for i, squeeze in enumerate((1.0, 0.8, 0.6)):  # a gentle turn, never paper-thin
    w = max(2, round(32 * squeeze))
    strip.paste(gem.resize((w, 42), Image.LANCZOS), (i * 32 + (32 - w) // 2, 0))
strip.save(f"{SHARED}/gem.png")
fit(Image.open(f"{CAVES}/Collectable Object/Crystal_Caves_Forest_2D_Platformer_Tileset_Collectable Object - Crystal.png").convert("RGBA"), 64, 60).save(f"{SHARED}/gem_big.png")
fit(Image.open(f"{CAVES}/Collectable Object/Crystal_Caves_Forest_2D_Platformer_Tileset_Collectable Object - Life.png").convert("RGBA"), 44, 40).save(f"{SHARED}/heart.png")
fit(Image.open(f"{CAVES}/Collectable Object/Crystal_Caves_Forest_2D_Platformer_Tileset_Collectable Object - Star.png").convert("RGBA"), 50, 50).save(f"{SHARED}/star.png")
fit(Image.open(f"{CAVES}/Platfromer/Crystal_Caves_Forest_2D_Platformer_Tileset_Platformer - Stone.png").convert("RGBA"), 64, 64).save(f"{SHARED}/tile_dirt_block.png")
fit(Image.open(f"{PACKS}/freescifiplatform/png/Tiles/Spike.png").convert("RGBA"), 64, 64, bottom=True).save(f"{SHARED}/tile_spikes.png")


def gift(opened):
    """A birthday gift box drawn in the packs' style (4x size, then shrunk for smooth edges)."""
    im = Image.new("RGBA", (256, 256))
    d = ImageDraw.Draw(im)
    # a deep midnight-teal box with a gold ribbon: elegant rather than toy-like
    box, lid, shade = ((176, 140, 98), (196, 160, 116), (150, 116, 80)) if opened else ((30, 72, 92), (44, 96, 118), (20, 50, 66))
    ribbon, ribbon_dark = (232, 192, 110), (184, 140, 66)
    d.rounded_rectangle((34, 112, 222, 238), 14, fill=box, outline=INK, width=10)       # the box
    d.rectangle((44, 200, 212, 228), fill=shade)                                         # its shadowed lower edge
    d.rounded_rectangle((20, 80, 236, 126), 12, fill=lid, outline=INK, width=10)        # the lid
    if not opened:
        d.rectangle((110, 85, 146, 233), fill=ribbon)                                    # ribbon down the front
        d.rectangle((110, 200, 146, 228), fill=ribbon_dark)
        d.line((110, 85, 110, 233), fill=INK, width=8)
        d.line((146, 85, 146, 233), fill=INK, width=8)
        for loop in ((56, 22, 128, 86), (128, 22, 200, 86)):                             # the bow
            d.ellipse(loop, fill=ribbon, outline=INK, width=10)
        d.ellipse((76, 40, 108, 70), fill=ribbon_dark)
        d.ellipse((148, 40, 180, 70), fill=ribbon_dark)
        d.ellipse((108, 46, 148, 88), fill=ribbon, outline=INK, width=10)
    else:
        d.line((60, 160, 196, 160), fill=shade, width=8)                                 # an empty, plain box
    d.line((40, 90, 216, 90), fill=(255, 255, 255, 90), width=6)                         # a shine along the lid
    return im.resize((64, 64), Image.LANCZOS)


gift(False).save(f"{SHARED}/tile_gift.png")
gift(True).save(f"{SHARED}/tile_gift_used.png")

# the rope: twisted cord with a metal ring at the top and a knot at the end (same 30 x 321 size)
rope = Image.new("RGBA", (120, 1284))
d = ImageDraw.Draw(rope)
d.rounded_rectangle((40, 60, 80, 1210), 18, fill=(200, 150, 90), outline=INK, width=8)
for y in range(80, 1200, 34):
    d.line((44, y + 26, 76, y), fill=(150, 104, 56), width=9)                          # the twist
d.ellipse((18, 4, 102, 80), outline=(120, 128, 140), width=16)                           # the ring
d.ellipse((18, 4, 102, 80), outline=INK, width=4)
d.ellipse((26, 1180, 94, 1270), fill=(184, 134, 76), outline=INK, width=8)              # the knot
rope.resize((30, 321), Image.LANCZOS).save(f"{SHARED}/rope.png")


def balloon(d, x, y, r, colour):
    """One shiny balloon: outlined oval, a little knot, and a white shine."""
    d.ellipse((x - r, y - r * 1.15, x + r, y + r * 1.15), fill=colour, outline=INK, width=8)
    d.polygon([(x - 10, y + r * 1.15 + 14), (x + 10, y + r * 1.15 + 14), (x, y + r * 1.15 - 4)], fill=colour, outline=INK)
    d.ellipse((x - r * 0.55, y - r * 0.8, x - r * 0.15, y - r * 0.25), fill=(255, 255, 255, 170))


COLOURS = [(240, 72, 84), (255, 200, 40), (70, 150, 240), (90, 200, 90), (170, 100, 220), (255, 130, 190)]
# the checkpoint's bunch of balloons (same 135 x 120 size), strings meeting at the bottom
im = Image.new("RGBA", (540, 480))
d = ImageDraw.Draw(im)
spots = [(120, 190, 0), (420, 190, 4), (200, 120, 1), (340, 120, 3), (270, 70, 2), (190, 250, 5), (350, 250, 4), (270, 200, 0)]
for x, y, c in spots:
    d.line((x, y + 100, 270, 470), fill=INK, width=5)
for x, y, c in spots:
    balloon(d, x, y, 68, COLOURS[c])
im.resize((135, 120), Image.LANCZOS).save(f"{SHARED}/balloons.png")
# the floating power-up's single pink balloon (37 x 90) with a wavy string
im = Image.new("RGBA", (148, 360))
d = ImageDraw.Draw(im)
d.line([(74, 170), (60, 210), (88, 250), (60, 290), (80, 350)], fill=INK, width=5, joint="curve")
balloon(d, 74, 84, 62, COLOURS[5])
im.resize((37, 90), Image.LANCZOS).save(f"{SHARED}/balloon_pink.png")
# the boulder: the sky-ruins pack's round stone
fit(Image.open(f"{PACKS}/sky-ruins-2d-platformer-tileset/PNG/Environment/Sky_Ruins_2D_Platformer_Tileset_Environment - Stone 02.png").convert("RGBA"), 72, 52, bottom=True).save(f"{SHARED}/boulder.png")
# sky-ruins props & interactive objects
Image.open(f"{PACKS}/{SKY_P}Ladder.png").convert("RGBA").resize((TILE, TILE), Image.LANCZOS).save(f"{SHARED}/ladder.png")
fit(Image.open(f"{PACKS}/{SKY_P}Wooden Barrel.png").convert("RGBA"), 60, 60, bottom=True).save(f"{SHARED}/barrel.png")
fit(Image.open(f"{PACKS}/{SKY_ENV}Portal.png").convert("RGBA"), 188, 200, bottom=True).save(f"{SHARED}/portal.png")
fit(Image.open(f"{PACKS}/sky-ruins-2d-platformer-tileset/PNG/Collectable Object/Sky_Ruins_2D_Platformer_Tileset_Collectable Object - Golden Key.png").convert("RGBA"), 48, 28).save(f"{SHARED}/key_gold.png")
fit(Image.open(f"{PACKS}/sky-ruins-2d-platformer-tileset/PNG/Collectable Object/Sky_Ruins_2D_Platformer_Tileset_Collectable Object - Silver Key.png").convert("RGBA"), 48, 28).save(f"{SHARED}/key_silver.png")
fit(Image.open(f"{PACKS}/sky-ruins-2d-platformer-tileset/PNG/Collectable Object/Sky_Ruins_2D_Platformer_Tileset_Collectable Object - Locked Golden Treasure Box.png").convert("RGBA"), 64, 56, bottom=True).save(f"{SHARED}/chest_gold_locked.png")
fit(Image.open(f"{PACKS}/sky-ruins-2d-platformer-tileset/PNG/Collectable Object/Sky_Ruins_2D_Platformer_Tileset_Collectable Object - Unlocked Golden Treasure Box.png").convert("RGBA"), 64, 56, bottom=True).save(f"{SHARED}/chest_gold_open.png")

# spinning coin animation strip (6 frames, 40x40 each)
coin_strip = Image.new("RGBA", (40 * 6, 40))
for i in range(1, 7):
    c_im = fit(Image.open(f"{PACKS}/sky-ruins-2d-platformer-tileset/PNG/Collectable Object/Sky_Ruins_2D_Platformer_Tileset_Collectable Object - Coin 0{i}.png").convert("RGBA"), 40, 40)
    coin_strip.paste(c_im, ((i - 1) * 40, 0))
coin_strip.save(f"{SHARED}/coin.png")

print("shared pieces:", sorted(os.listdir(SHARED)))

