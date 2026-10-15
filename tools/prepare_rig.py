"""Cut toon Gracy's body parts (art/3d/gracy_parts.png, drawn by Gemini) into the Godot rig.

Run from the project folder:  .venv/bin/python tools/prepare_rig.py
Writes godot/assets/rig/gracy_<part>.png and godot/data/rig_gracy.json:
for every part its picture, the pivot it turns around, its parent, and where it hangs on the parent.
All points below are pixel positions on the parts sheet.
"""
import json
import os
from PIL import Image
from sprites_lib import load, remove_white_bg

SCALE = 0.2  # the sheet is drawn big: this makes her about 145 px tall in the game
OUT = "godot/assets/rig"

# part: (box on the sheet, pivot on the sheet, extra stretch (x, y))
PARTS = {
    "backhair":  ((61, 62, 208, 306), (195, 95), (1.0, 1.0)),
    "head":      ((303, 62, 470, 305), (408, 226), (1.0, 1.0)),
    "torso":     ((107, 319, 205, 481), (156, 474), (1.0, 1.0)),
    "upper_arm": ((311, 338, 373, 466), (342, 352), (1.0, 1.0)),
    "forearm":   ((335, 516, 441, 641), (344, 523), (1.0, 1.0)),
    "skirt":     ((60, 502, 229, 659), (145, 512), (0.92, 1.35)),  # the kurti reaches her knees
    "upper_leg": ((123, 696, 202, 936), (163, 712), (1.0, 1.0)),
    "lower_leg": ((336, 699, 432, 946), (368, 712), (1.0, 1.0)),
}
# part: (parent, the joint on the parent where it hangs, drawing order: higher is in front)
JOINTS = {
    "torso":     (None, None, 0),
    "skirt":     ("torso", (152, 460), -1),
    "upper_leg": ("torso", (152, 474), -3),
    "lower_leg": ("upper_leg", (162, 900), -4),   # tucked a little under the thigh
    "head":      ("torso", (136, 332), 2),
    "backhair":  ("head", (396, 100), -5),        # behind everything on her back
    "upper_arm": ("torso", (142, 350), 3),
    "forearm":   ("upper_arm", (339, 456), 4),
}

os.makedirs(OUT, exist_ok=True)
sheet = remove_white_bg(load("art/3d/gracy_parts.png"), thresh=238)
rig = {"scale": SCALE, "parts": {}}
for name, (box, pivot, (sx, sy)) in PARTS.items():
    im = sheet.crop(box)
    w, h = round(im.width * SCALE * sx), round(im.height * SCALE * sy)
    im.resize((w, h), Image.LANCZOS).save(f"{OUT}/gracy_{name}.png")
    parent, joint, z = JOINTS[name]
    entry = {
        "pivot": [(pivot[0] - box[0]) * SCALE * sx, (pivot[1] - box[1]) * SCALE * sy],
        "parent": parent, "z": z,
    }
    if parent:
        pbox, ppivot, (psx, psy) = PARTS[parent]
        # where the joint sits, measured from the parent's pivot
        entry["at"] = [(joint[0] - ppivot[0]) * SCALE * psx, (joint[1] - ppivot[1]) * SCALE * psy]
    rig["parts"][name] = entry
with open("godot/data/rig_gracy.json", "w") as fh:
    json.dump(rig, fh, indent=1)
print("rig parts:", ", ".join(rig["parts"]))
