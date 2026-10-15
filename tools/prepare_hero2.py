"""Turn a Spriterrific run (spriterrific-runs/<name>-<id>/) into the game's sprite strips for the new Janani.

Run from the project folder:
    .venv/bin/python tools/prepare_hero2.py spriterrific-runs/gracy-w58g8ybh beta kurti
(the outfit id for the wardrobe, then the old outfit whose rope frames it borrows).
Writes godot/assets/hd/<outfit>_<action>.png (one row of square frames, facing right, feet on the bottom
edge, shrunk so she stands about as tall as the old sprite) and godot/data/hd.json, which the game uses
(Game.detailed_frames) instead of the old 104x150 strips for that outfit.
Spriterrific draws her facing left on green: the frames are flipped, and the green left on her edges is removed.
"""
import json
import os
import sys
from PIL import Image

CELL = 256
HEIGHT = 168  # how tall she should stand in the game, in pixels (the old sprite: about 150)


def frames(sheet_path, count, columns):
    sheet = Image.open(sheet_path).convert("RGBA")
    return [sheet.crop(((i % columns) * CELL, (i // columns) * CELL, (i % columns + 1) * CELL, (i // columns + 1) * CELL))
            for i in range(count)]


def despill(im):
    """Green left from the green screen (on hands, shoes, hair edges): pull green down to the other channels."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > max(r, b):
                px[x, y] = (r, max(r, b), b, a)
    return im


def main(run, outfit, base):
    out_dir = "godot/assets/hd"
    os.makedirs(out_dir, exist_ok=True)
    info = {}
    actions = [a for a in ("run", "jump", "hurt", "attack", "walk", "idle") if os.path.exists(f"{run}/{a}/manifest.json")]
    clips = {}
    for action in actions:
        m = json.load(open(f"{run}/{action}/manifest.json"))
        clips[action] = (m, [despill(f).transpose(Image.FLIP_LEFT_RIGHT) for f in frames(f"{run}/{action}/spritesheet.png", m["frames"], m["columns"])])
    # her standing height, from the first frame of the hurt (or jump) clip, where she stands still
    stand = clips.get("hurt", clips.get("jump"))[1][0]
    box = stand.getbbox()
    scale = HEIGHT / (box[3] - box[1])
    cell = round(CELL * scale)
    for action, (m, fs) in clips.items():
        # put her feet on the bottom edge: lift every frame of the clip by the same amount (no jitter)
        lowest = max(f.getbbox()[3] for f in fs if f.getbbox())
        strip = Image.new("RGBA", (cell * len(fs), cell))
        for i, f in enumerate(fs):
            lifted = Image.new("RGBA", (CELL, CELL))
            lifted.paste(f, (0, CELL - lowest))
            strip.paste(lifted.resize((cell, cell), Image.LANCZOS), (i * cell, 0))
        key = f"{outfit}_{action}"
        strip.save(f"{out_dir}/{key}.png")
        info[action] = {"key": f"hd/{key}", "frames": len(fs), "fps": m["fps"]}
        print(f"{key}: {len(fs)} frames at {m['fps']} fps")
    data_path = "godot/data/hd.json"
    data = json.load(open(data_path)) if os.path.exists(data_path) else {}
    data[outfit] = {"cell": cell, "base": base, "actions": info}
    json.dump(data, open(data_path, "w"), indent=1)
    print(f"{cell}x{cell} frames; wrote {data_path}")


main(sys.argv[1], sys.argv[2], sys.argv[3])
