"""Cuts the red demon sheet (art/packs/new_from_yuva/attached/demon_boss_sheet.jpg) into one even strip.

Output: godot/assets/pack/yuva_demon.png (cells CELL_W x CELL_H, feet on the bottom middle)
        godot/data/extra_frames.json (frame sizes, read by game.gd next to manifest.json)
Run from the project root:  .venv/bin/python tools/prepare_demon.py
"""
import json
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "art/packs/new_from_yuva/attached/demon_boss_sheet.jpg"
OUT = "godot/assets/pack/yuva_demon.png"
DATA = "godot/data/extra_frames.json"
CELL_W, CELL_H = 224, 220

im = Image.open(SRC).convert("RGB")
a = np.array(im).astype(int)
bg = np.median(a[:8, :8].reshape(-1, 3), axis=0)
dist = np.abs(a - bg).sum(axis=2)
solid = ndimage.binary_closing(dist > 40, iterations=3)
lab, _ = ndimage.label(ndimage.binary_dilation(solid, iterations=6))
boxes = []
for s in ndimage.find_objects(lab):
	h, w = s[0].stop - s[0].start, s[1].stop - s[1].start
	if h > 60 and w > 60:
		boxes.append((s[0].start, s[1].start, s[0].stop, s[1].stop))
# reading order: rows (frames whose tops are within 40 px share a row), then left to right
boxes.sort()
rows, cur = [], [boxes[0]]
for b in boxes[1:]:
	if b[0] - cur[0][0] < 40:
		cur.append(b)
	else:
		rows.append(cur)
		cur = [b]
rows.append(cur)
ordered = [b for r in rows for b in sorted(r, key=lambda b: b[1])]

# soft key: grey -> transparent, with a little despill on the edge pixels
alpha = np.clip((dist - 24) / 40.0, 0, 1)
rgba = np.dstack([a, alpha * 255]).astype(np.uint8)
sheet = Image.fromarray(rgba, "RGBA")

strip = Image.new("RGBA", (CELL_W * len(ordered), CELL_H), (0, 0, 0, 0))
for i, (y0, x0, y1, x1) in enumerate(ordered):
	crop = sheet.crop((x0, y0, x1, y1))
	# feet line: lowest solid row of the body, so a swipe effect does not lift him
	cx = CELL_W * i + (CELL_W - crop.width) // 2
	strip.paste(crop, (cx, CELL_H - crop.height - 4), crop)
strip.save(OUT)
try:
	extra = json.load(open(DATA))
except FileNotFoundError:
	extra = {}
extra["yuva_demon"] = {"frameWidth": CELL_W, "frameHeight": CELL_H, "frames": len(ordered)}
json.dump(extra, open(DATA, "w"), indent="\t")
print(len(ordered), "frames ->", OUT)

# contact sheet with numbers, to pick frames by eye
from PIL import ImageDraw
cols = 8
rows_n = (len(ordered) + cols - 1) // cols
cs = Image.new("RGBA", (cols * CELL_W // 2, rows_n * CELL_H // 2), (40, 40, 60, 255))
d = ImageDraw.Draw(cs)
for i in range(len(ordered)):
	c = strip.crop((i * CELL_W, 0, (i + 1) * CELL_W, CELL_H)).resize((CELL_W // 2, CELL_H // 2), Image.NEAREST)
	x, y = (i % cols) * CELL_W // 2, (i // cols) * CELL_H // 2
	cs.paste(c, (x, y), c)
	d.text((x + 4, y + 4), str(i), fill=(255, 255, 0, 255))
cs.save("art/previews/yuva_demon_frames.png")
