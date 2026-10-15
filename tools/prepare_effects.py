"""Cut the magic and explosion effects (art/packs/effects) into sprite strips for the Godot game.

Run from the project folder:  .venv/bin/python tools/prepare_effects.py
Writes godot/assets/pack/<name>.png (one row of equal frames) and godot/data/pack_frames.json
(each strip's frame width, merged into Game.manifest so Game.frame() can cut them).
"""
import glob
import json
import re
from PIL import Image

FX = "art/packs/effects"
OUT = "godot/assets/pack"


def frames(folder):
    """The folder's frames in number order (Frame_2 before Frame_10)."""
    return sorted(glob.glob(f"{FX}/{folder}/*.png"), key=lambda f: int(re.findall(r"(\d+)\D*$", f)[0]))


def strip(name, files, height):
    """All frames cropped to the area any of them uses, shrunk to `height`, side by side."""
    ims = [Image.open(f).convert("RGBA") for f in files]
    boxes = [im.getbbox() for im in ims]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    w = round((box[2] - box[0]) * height / (box[3] - box[1]))
    out = Image.new("RGBA", (w * len(ims), height))
    for i, im in enumerate(ims):
        out.paste(im.crop(box).resize((w, height), Image.LANCZOS), (i * w, 0))
    out.save(f"{OUT}/{name}.png")
    return {"frameWidth": w, "frames": len(ims)}


def icon(name, path, height):
    im = Image.open(f"{FX}/{path}").convert("RGBA")
    im = im.crop(im.getbbox())
    im.resize((round(im.width * height / im.height), height), Image.LANCZOS).save(f"{OUT}/{name}.png")


info = {
    "fireball": strip("fireball", frames("water-and-fire-magic/Fire Ball/PNG"), 40),    # round and swirling
    "fire_arrow": strip("fire_arrow", frames("water-and-fire-magic/Fire Arrow/PNG"), 44),  # points left
    "explosion": strip("explosion", frames("animated-explosions/PNG/Explosion_1"), 150),
}
icon("icon_fire", "water-and-fire-magic/Icons/PNG/Icons_Fire Spell.png", 48)
icon("icon_arrow", "water-and-fire-magic/Icons/PNG/Icons_Fire Arrow.png", 52)
with open("godot/data/pack_frames.json", "w") as fh:
    json.dump(info, fh, indent=1)
print(info)
