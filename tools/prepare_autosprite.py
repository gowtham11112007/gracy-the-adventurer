"""Turn the AutoSprite sheets of the "25" Janani (art/autosprite/) into game strips: her ladder climb and her
sword slash. Run from the project folder:  .venv/bin/python tools/prepare_autosprite.py

Each sheet comes with its atlas (frame positions) from autosprite.io (the share link + "/atlas").
Writes godot/assets/hd/janani25_climb.png and janani25_slash.png (one row of frames, facing right) and adds
"climb" and "slash" to the "25" outfits in godot/data/hd.json. A strip whose frames aren't the outfit's square
cell says its own size: "w" x "h", with her feet at ("ax", "h") in each frame.
The climb sheet has a ladder drawn into it: the game draws its own ladders, so that one is rubbed out.
"""
import json
from PIL import Image

SRC = "art/autosprite"
OUT = "godot/assets/hd"
HEIGHT = 168            # how tall she stands in the game (same as tools/prepare_hero2.py)
OUTFITS = ["beta4", "beta5", "beta6", "beta7"]  # the sets in the "25" top and jeans


def frames(name):
    sheet = Image.open(f"{SRC}/janani25_{name}_sheet.png").convert("RGBA")
    atlas = json.load(open(f"{SRC}/janani25_{name}_atlas.json"))
    out = []
    for key in sorted(atlas["frames"], key=int):
        f = atlas["frames"][key]
        out.append(sheet.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])))
    return out, len(out) / atlas["meta"]["duration_s"]


def rub_out_ladder(im, x0, rail, x1):
    """The drawn ladder: grey-blue metal. Between x0 and `rail` (behind her) only the metal greys go (her
    black shoes, hair, skin and jeans stay); from `rail` to x1 (the near rail, in front of her hands)
    everything but skin goes."""
    px = im.load()
    for y in range(im.height):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            skin = r > b + 30
            grey = max(r, g, b) - min(r, g, b) < 30 and b >= r
            if (x >= rail and not skin) or (grey and 38 < max(r, g, b) < 200) or a < 40:
                px[x, y] = (0, 0, 0, 0)
    # the rivets left behind: lone specks with little of her around them
    specks = []
    for y in range(2, im.height - 2):
        for x in range(x0, x1):
            if px[x, y][3] and sum(px[x + dx, y + dy][3] > 0 for dx in range(-2, 3) for dy in range(-2, 3)) < 14:
                specks.append((x, y))
    for x, y in specks:
        px[x, y] = (0, 0, 0, 0)
    return im


def place(fs, scale, anchor, w, h, ax):
    """Scale every frame the same and put the anchor (her feet / her hands on the ladder) at (ax, h): no jitter."""
    strip = Image.new("RGBA", (w * len(fs), h))
    for i, f in enumerate(fs):
        big = f.resize((round(f.width * scale), round(f.height * scale)), Image.LANCZOS)
        cell = Image.new("RGBA", (w, h))
        cell.paste(big, (round(ax - anchor[0] * scale), round(h - anchor[1] * scale)), big)
        strip.paste(cell, (i * w, 0))
    return strip


def main():
    data = json.load(open("godot/data/hd.json"))
    actions = {}
    # climbing: she stands 188 px tall in the sheet; her hands are on the ladder at x 160 (put on the
    # game's ladder: the middle of the frame); feet at y 230
    climb, fps = frames("climb")
    climb = [rub_out_ladder(f, 146, 160, 172) for f in climb]
    cell = 210
    place(climb, HEIGHT / 188, (160, 230), cell, cell, cell // 2).save(f"{OUT}/janani25_climb.png")
    actions["climb"] = {"key": "hd/janani25_climb", "frames": len(climb), "fps": round(fps)}
    # the sword slash: she stands 185 px tall, feet at (245, 483); the blade reaches 240 px ahead and 250 up
    slash, fps = frames("sword")
    w, h, ax = 300, 250, 70
    place(slash, HEIGHT / 185, (245, 483), w, h, ax).save(f"{OUT}/janani25_slash.png")
    actions["slash"] = {"key": "hd/janani25_slash", "frames": len(slash), "fps": round(fps), "w": w, "h": h, "ax": ax}
    for o in OUTFITS:
        if o in data:
            data[o]["actions"].update(actions)
    json.dump(data, open("godot/data/hd.json", "w"), indent=1)
    for k, v in actions.items():
        print(f"{k}: {v['frames']} frames at {v['fps']} fps -> {v['key']}.png")
    print("added to", [o for o in OUTFITS if o in data])


main()
