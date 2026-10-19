"""Draws Level 1's gem as pixel art to match the village packs (Cainos, 32 pixels a tile, dark outlines):
a faceted sky-blue crystal with a glint that sweeps across it and a little star that twinkles.

Run from the project folder:  .venv/bin/python tools/make_pixel_gem.py
Writes unity/Assets/Resources/Art/Props/gem_pixel.png: 8 frames of 32x36 (each art pixel drawn as 2x2, so the
game's 64 pixels a unit gives the village's 32), feet (the gem's bottom point) at x = 16.
"""
from PIL import Image

W, H, FRAMES, SCALE = 16, 18, 8, 2
OUT = "unity/Assets/Resources/Art/Props/gem_pixel.png"

# the gem's outline: for each row, its left and right edge (a brilliant cut: crown, girdle, pavilion to a point)
ROWS = [(5, 10), (3, 12), (2, 13), (1, 14), (1, 14)] + [(1 + i * 7 // 11 + (i > 0), 14 - i * 7 // 11 - (i > 0)) for i in range(11)]
OUTLINE = (24, 30, 64, 255)
SHADES = {  # facet -> colour (dark to light)
    "deep": (31, 84, 160), "mid": (52, 140, 214), "light": (110, 200, 244), "table": (168, 230, 252), "white": (240, 252, 255),
}


def facet(x, y):
    """Which facet a pixel is on (light comes from the top left)."""
    if y <= 1:
        return "table"
    if y <= 4:
        return "light" if x < 6 else ("table" if x < 10 else "mid")
    # the pavilion: four long facets meeting at the point
    centre = 7.5
    if x < centre - 3:
        return "mid"
    if x < centre:
        return "light"
    if x < centre + 3:
        return "mid"
    return "deep"


def frame(n):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    inside = set()
    for y, (a, b) in enumerate(ROWS):
        for x in range(a, b + 1):
            inside.add((x, y + 1))
    glint = n * 3 - 6  # a bright diagonal band sweeping left to right
    for (x, y) in inside:
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            px[x, y] = OUTLINE
            continue
        c = SHADES[facet(x, y - 1)]
        if 0 <= (x + y * 0.6) - glint < 2:
            c = SHADES["white"] if facet(x, y - 1) != "deep" else SHADES["light"]
        px[x, y] = c + (255,)
    # the girdle line and the facet lines
    for x in range(2, 14):
        if (x, 5) in inside and px[x, 5] != OUTLINE:
            px[x, 5] = SHADES["deep"] + (255,)
    # a twinkle on frames 5-6, at the crown's top left
    if n in (5, 6):
        sx, sy = 4, 2
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)) + (((2, 0), (-2, 0), (0, 2), (0, -2)) if n == 5 else ()):
            if 0 <= sx + dx < W and 0 <= sy + dy < H:
                px[sx + dx, sy + dy] = (255, 255, 255, 255)
    return img


strip = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
for n in range(FRAMES):
    strip.paste(frame(n), (n * W, 0))
strip.resize((W * FRAMES * SCALE, H * SCALE), Image.NEAREST).save(OUT)
strip.resize((W * FRAMES * 12, H * 12), Image.NEAREST).save("/tmp/gem_preview.png") if False else None
print("wrote", OUT)
