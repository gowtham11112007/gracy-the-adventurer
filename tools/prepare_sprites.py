"""Cut the art/ sheets into game-ready sprites in game/public/assets/.

Run from the project folder:  .venv/bin/python tools/prepare_sprites.py
Writes PNG spritesheets plus assets/manifest.json (frame sizes the game reads at load time).
"""
import json
import os
import numpy as np
from PIL import Image
from sprites_lib import (load, remove_white_bg, find_items, crop, scale_by, scale_to_height,
                         body_center_x, pack_strip)

ART = "art"
OUT = "game/public/assets"
TILE = 64            # one level tile, in game pixels
HERO_H = 128         # Janani's standing height
manifest = {}


def sheet_items(name, min_area=3000, merge=6):
    rgba = remove_white_bg(load(f"{ART}/{name}.png"))
    return rgba, find_items(rgba, merge=merge, min_area=min_area)


def save_strip(key, frames, cell_w, cell_h, center=None):
    pack_strip(frames, cell_w, cell_h, center=center).save(f"{OUT}/{key}.png")
    manifest[key] = {"frameWidth": cell_w, "frameHeight": cell_h, "frames": len(frames)}


def save_image(key, im):
    im.save(f"{OUT}/{key}.png")
    manifest[key] = {"width": im.width, "height": im.height}


# ---------------------------------------------------------------- hero (Janani) -----
# Every outfit strip uses the same frame order so the game can share one set of animations:
#   0 idle, 1 blink, 2 smile, 3-6 run, 7-10 walk, 11 jump rise, 12 jump peak, 13 jump fall, 14 hurt, 15 victory
HERO_CELL = (104, 150)


def hero_frames(rgba, boxes, picks, row_ref):
    """picks: list of box indices; row_ref: {box index: index of a standing frame drawn at the same scale}."""
    out = []
    for i in picks:
        ref = boxes[row_ref[i]]
        f = HERO_H / (ref[3] - ref[1])
        out.append(scale_by(crop(rgba, boxes[i]), f))
    return out


def main_outfit():
    rgba, b = sheet_items("gracy_main")
    assert len(b) == 25, len(b)
    # Gemini drew each row at a slightly different size; scale every row by one of its standing frames
    row_ref = {i: [0, 5, 10, 15, 24][i // 5] for i in range(25)}
    picks = [0, 1, 4, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 20, 23, 24]
    return hero_frames(rgba, b, picks, row_ref)


def alt_outfit(sheet, col):
    """Idle and walk come from gracy_outfits.png (column `col`); run/jump/hurt/victory from the outfit's own sheet."""
    rgba_o, bo = sheet_items("gracy_outfits")
    assert len(bo) == 25, len(bo)
    # gracy_outfits rows: 0 idle, 1-4 walk; columns are the 5 outfits
    idle = scale_to_height(crop(rgba_o, bo[col]), HERO_H)
    walks = []
    for r in range(1, 5):
        row = bo[r * 5:(r + 1) * 5]
        ref = sorted(x[3] - x[1] for x in row)[2]          # row median = standing height at that row's scale
        walks.append(scale_by(crop(rgba_o, row[col]), HERO_H / ref))
    rgba, b = sheet_items(sheet)
    assert len(b) == 10, (sheet, len(b))
    row_ref = {i: (0 if i < 5 else 9) for i in range(10)}  # top row: standing start; bottom row: victory pose
    act = hero_frames(rgba, b, [1, 2, 3, 4, 5, 6, 7, 8, 9], row_ref)
    return [idle, idle, idle] + act[0:4] + walks + act[4:9]


def heroes():
    outfits = {"kurti": main_outfit()}
    for col, (key, sheet) in enumerate([("print", "outfit_kurti_print"), ("black", "outfit_black_dress"),
                                        ("jacket", "outfit_brown_jacket"), ("top25", "outfit_25_top"),
                                        ("maroon", "outfit_maroon")]):
        outfits[key] = alt_outfit(sheet, col)
    for key, frames in outfits.items():
        assert len(frames) == 16
        save_strip(f"hero_{key}", frames, *HERO_CELL, center=body_center_x)


# ------------------------------------------------------- smooth animation sheets ----
# Extra frames Gemini drew in art/anim/ (white kurti only for now). Each sheet is drawn at its own size,
# so each gets a scale that makes her head match the main sheet.
def anim_sheet(name, f, merge=6):
    rgba = remove_white_bg(load(f"{ART}/anim/{name}.png"))
    return [scale_by(crop(rgba, x), f) for x in find_items(rgba, merge=merge, min_area=2000)]


def hands_x(im):
    """x of her fists: the middle of the topmost 6% of the drawing (she holds the rope above her head)."""
    a = np.asarray(im)[..., 3] > 0
    band = a[:max(2, int(a.shape[0] * 0.06))]
    return np.where(band)[1].mean()


def smooth_anims():
    run = anim_sheet("janani_run", 0.506)
    jump = anim_sheet("janani_jump", 0.42)
    assert len(run) == 6 and len(jump) == 6, (len(run), len(jump))
    # 0-5 run cycle; 6 crouch, 7 take-off, 8 rising, 9 top, 10 falling, 11 landing
    # same cell size as the main strip, so swapping sheets never moves her hitbox
    save_strip("hero_kurti_moves", run + jump, *HERO_CELL, center=body_center_x)

    # rope: 0 hanging, 1 legs kicked forward, 2 legs trailing, 3 letting go.
    # Packed with her fists at the top-middle of each cell, so the game can hang the sprite from the rope.
    rope = anim_sheet("janani_rope", 0.43)
    assert len(rope) == 4, len(rope)
    cw, ch = 150, 200
    sheet = Image.new("RGBA", (cw * 4, ch), (0, 0, 0, 0))
    for i, im in enumerate(rope):
        sheet.alpha_composite(im, (max(i * cw, i * cw + round(cw / 2 - hands_x(im))), 2))
    sheet.save(f"{OUT}/hero_kurti_rope.png")
    manifest["hero_kurti_rope"] = {"frameWidth": cw, "frameHeight": ch, "frames": 4, "leapBottom": 2 + rope[3].height}

    # the rope itself, sized for one tile across; the game stretches it to each rope's length
    rgba = remove_white_bg(load(f"{ART}/anim/rope.png"))
    save_image("rope", scale_by(crop(rgba, find_items(rgba, min_area=2000)[0]), 0.33))

    # the twins hugging (World 1 ending): Janani is full height in it, so she matches her normal size
    hug = remove_white_bg(load(f"{ART}/reunion_hug_new.png"))
    boxes = find_items(hug, merge=6, min_area=20000)  # the hearts and sparkles around them are left out
    assert len(boxes) == 2, len(boxes)
    save_strip("hug", [scale_by(crop(hug, x), HERO_H / (x[3] - x[1])) for x in boxes], *HERO_CELL)

    # Kitty's gallop (drawn facing right; the old kitty art faces left, so flip to match)
    kitty_run = [x.transpose(Image.FLIP_LEFT_RIGHT) for x in anim_sheet("kitty_run", 0.55, merge=1)]
    assert len(kitty_run) == 6, len(kitty_run)
    save_strip("kitty_run", kitty_run, 112, 84)


# Janika's extra outfits (art/janika_outfits/<key>*.png). Gemini drew one rope sheet with 5 frames:
# pick hang, legs forward, legs trailing, let go.
JANIKA_OUTFITS = ["denim", "cargo", "skirt"]
JANIKA_ROPE_PICKS = {"denim": [0, 3, 1, 4]}


def save_rope_strip(key, frames):
    """Rope frames packed with her fists at the top middle of each cell, so the game can hang her from the rope."""
    cw, ch = 150, 200
    sheet = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        sheet.alpha_composite(im, (max(i * cw, i * cw + round(cw / 2 - hands_x(im))), 2))
    sheet.save(f"{OUT}/{key}.png")
    manifest[key] = {"frameWidth": cw, "frameHeight": ch, "frames": len(frames)}
    # frame 3 is her leaping off; the game needs to know where her feet are in it
    if len(frames) > 3:
        manifest[key]["leapBottom"] = 2 + frames[3].height


# ------------------------------------------------------------ Janika (new design) ----
# Drawn by Gemini from her photo (art/anim/janika_*.png). Each sheet has its own drawing size,
# so each gets the scale that makes her as tall as Janani.
def janika():
    idle = anim_sheet("janika_idle", HERO_H / 398)
    emotes = anim_sheet("janika_emotes", HERO_H / 398)
    coop = anim_sheet("janika_coop", HERO_H / 333)
    run = anim_sheet("janika_run", 125 / 269)
    assert (len(idle), len(emotes), len(coop), len(run)) == (6, 5, 6, 6)
    # "twin" strip: 0 front, 1-2 breathing, 3 blink, 4 smile looking aside, 5 side view,
    #               6 hurt, 7 dizzy, 8 jump for joy, 9 peace sign, 10 sad sitting
    save_strip("twin", [idle[i] for i in (1, 2, 3, 4, 5, 0)] + emotes, *HERO_CELL, center=body_center_x)
    # moves: 0-5 run; 6-11 jump (crouch, take-off, rising, top, falling, landing), like Janani's
    jump = anim_sheet("janika_jump", 104 / 285)  # her crouch matches Janani's crouch height
    assert len(jump) == 6, len(jump)
    save_strip("hero_janika_moves", run + jump, *HERO_CELL, center=body_center_x)
    # rope: fists at the top middle of each cell, like Janani's
    save_rope_strip("hero_janika_rope", anim_sheet("janika_rope", 182 / 328))
    # her outfit collection, art/janika_outfits/: <key>.png (0 standing, 1-5 walking), <key>_run, _jump, _rope
    for key in JANIKA_OUTFITS:
        sheet = lambda part: [crop(r, x) for r in [remove_white_bg(load(f"{ART}/janika_outfits/{key}{part}.png"))]
                              for x in find_items(r, merge=1, min_area=3000)]
        look = sheet("")
        save_strip(f"janika_{key}", [scale_by(x, HERO_H / x.height) for x in look], *HERO_CELL, center=body_center_x)
        # each sheet is scaled so she's the same size as in her main clothes
        run = sheet("_run")
        f_run = 125 / sorted(x.height for x in run)[len(run) // 2]
        jump = sheet("_jump")
        f_jump = 104 / jump[0].height
        save_strip(f"hero_janika_{key}_moves", [scale_by(x, f_run) for x in run] + [scale_by(x, f_jump) for x in jump],
                   *HERO_CELL, center=body_center_x)
        if os.path.exists(f"{ART}/janika_outfits/{key}_rope.png"):
            rope = sheet("_rope")
            picks = JANIKA_ROPE_PICKS.get(key, [0, 1, 2, 3])
            rope = [scale_by(rope[i], 182 / rope[0].height) for i in picks]
        else:
            # no rope sheet (Gemini refused this one): hang from the arms-up jump frames for now
            rope = [scale_by(jump[i], f_jump) for i in (1, 2, 1, 2)]
        save_rope_strip(f"hero_janika_{key}_rope", rope)
    # teamwork poses for two-phone play: 0 boost, 1 push, 2 press button, 3 reach up, 4 wave, 5 point
    save_strip("janika_coop", coop, *HERO_CELL, center=body_center_x)


# ------------------------------------------------- Janani's other outfits, smooth ----
# art/janani_outfits/<key>_run.png, _jump.png, _rope.png. Gemini sometimes adds extra filler poses,
# so PICKS says which drawings to use (in reading order); without an entry, all of them in order.
JANANI_PICKS = {
    "print_run": [2, 3, 4, 7, 8, 9],
    "print_jump": [0, 1, 2, 3, 4, 9],
    "print_rope": [0, 1, 2, 3],
    "jacket_run": [0, 1, 2, 5],         # the others switched to blue jeans by mistake
    "jacket_jump": [0, 2, 3, 5, 6, 7],
    "jacket_rope": [0, 2, 2, 4],        # frame 3 lets go with one hand too early
    "top25_run": [0, 2, 3, 4, 6, 7],    # frame 5 was drawn smaller
    "top25_jump": [0, 1, 2, 4, 5, 6],
    "top25_rope": [0, 2, 2, 4],
    "maroon_jump": [0, 1, 2, 4, 5, 6],
    "maroon_rope": [0, 1, 1, 3],        # in frame 3 one hand has already let go
}


def trim_vine(im):
    """Gemini sometimes draws the vine above her fists anyway: cut off the thin line on top."""
    a = np.asarray(im)[..., 3] > 0
    top = next((y for y, row in enumerate(a) if row.sum() > 9), 0)  # the vine is under 10px wide, her fists wider
    return im.crop((0, top, im.width, im.height))


def janani_outfit_anims():
    for key in ["print", "black", "jacket", "top25", "maroon"]:
        path = lambda part: f"{ART}/janani_outfits/{key}_{part}.png"
        if not os.path.exists(path("run")):
            continue

        def sheet(part):
            r = remove_white_bg(load(path(part)))
            items = [crop(r, x) for x in find_items(r, merge=1, min_area=3000)]
            picks = JANANI_PICKS.get(f"{key}_{part}")
            return [items[i] for i in picks] if picks else items

        run = sheet("run")
        f_run = 125 / sorted(x.height for x in run)[len(run) // 2]
        run = [scale_by(x, f_run) for x in run]
        if os.path.exists(path("jump")):
            jump = sheet("jump")
            jump = [scale_by(x, 104 / jump[0].height) for x in jump]
        else:
            # no jump sheet yet: her old rise / top / fall poses from the outfit's main strip
            old = Image.open(f"{OUT}/hero_{key}.png")
            cell = lambda i: old.crop((i * HERO_CELL[0], 0, (i + 1) * HERO_CELL[0], HERO_CELL[1]))
            jump = [cell(i) for i in (0, 11, 11, 12, 13, 0)]
            jump = [im.crop(im.getbbox()) for im in jump]
        # the run is padded to 6 cells so the jump always starts at cell 6; "run" says how many are real
        assert len(run) <= 6 and len(jump) == 6, (key, len(run), len(jump))
        cells = run + [run[-1]] * (6 - len(run)) + jump
        save_strip(f"hero_{key}_moves", cells, *HERO_CELL, center=body_center_x)
        manifest[f"hero_{key}_moves"]["run"] = len(run)
        if os.path.exists(path("rope")):
            rope = [trim_vine(x) for x in sheet("rope")]
            save_rope_strip(f"hero_{key}_rope", [scale_by(x, 182 / rope[0].height) for x in rope])


# ------------------------------------------------------- map, trick doors, board ----
def world_props():
    # the World 1 map is used whole (the game knows where its 5 clearings are)
    save_image("world1_map", load(f"{ART}/world1_map.png").convert("RGB"))
    rgba, b = sheet_items("doors")
    assert len(b) == 2, len(b)
    save_image("door_heaven", scale_to_height(crop(rgba, b[0]), 124))
    save_image("door_hell", scale_to_height(crop(rgba, b[1]), 124))
    rgba, b = sheet_items("notice_board")
    assert len(b) == 1, len(b)
    board = crop(rgba, b[0])
    save_image("notice_board", scale_by(board, 190 / board.width))


# ---------------------------------------------------------------- tiles & ground ----
def tiles():
    rgba, b = sheet_items("tiles")
    names = ["grass_block", "dirt_block", "grass_left", "grass_right", "grass_float",
             "brick", "gift", "gift_used", "crate", "spikes", "lava"]
    for n, box in zip(names, b):
        im = crop(rgba, box).resize((TILE, TILE), Image.LANCZOS)
        save_image(f"tile_{n}", im)
    # ground: the grass strip is 5 repeats of one ~254px segment; cut one clean repeat between the seams
    rgba, b = sheet_items("ground")
    strip = crop(rgba, b[0])
    s = np.asarray(strip).astype(int)
    band = s[int(s.shape[0] * 0.55):int(s.shape[0] * 0.85), :, :3].mean(2)
    seams = np.where((band < 70).mean(0) > 0.8)[0]          # Gemini's dark divider lines
    left, right = seams[seams < s.shape[1] / 2].max() + 1, seams[seams > s.shape[1] / 2].min()
    seg = strip.crop((left, 0, right, strip.height))
    top = seg.resize((TILE * 2, round(seg.height * TILE * 2 / seg.width)), Image.LANCZOS)
    save_image("ground_top", top)       # 2 tiles wide; grass pokes above the tile row
    x0, y0, x1, y1 = b[1]
    inset = 8                                   # trim the light border so the dirt tiles join without a grid
    dirt = rgba.crop((x0 + inset, y0 + inset, x1 - inset, y1 - inset)).resize((TILE, TILE), Image.LANCZOS)
    save_image("ground_dirt", dirt)


# --------------------------------------------------------- World 2: Crystal Cave ----
def cave():
    rgba, b = sheet_items("tiles_cave")
    assert len(b) == 6, len(b)
    # 0 rock block with crystals on top, 1 rock fill, 2 bevelled block with a crystal, 3 fill, 4 bevelled block, 5 island
    top = crop(rgba, b[0])
    a = np.asarray(top)[..., 3] > 0
    rim = next(y for y, row in enumerate(a) if row.mean() > 0.95)  # where the crystals end and the block begins
    f = TILE / top.width
    crystals = top.crop((0, 0, top.width, rim)).resize((TILE, max(1, round(rim * f))), Image.LANCZOS)
    block = top.crop((0, rim, top.width, top.height)).resize((TILE, TILE), Image.LANCZOS)
    h = TILE + crystals.height
    # like ground_top: two frames side by side, plain rock top and crystal-topped, block part on the bottom 64px
    strip = Image.new("RGBA", (TILE * 2, h), (0, 0, 0, 0))
    strip.alpha_composite(block, (0, h - TILE))
    strip.alpha_composite(block, (TILE, h - TILE))
    strip.alpha_composite(crystals, (TILE, 0))
    save_image("cave_ground_top", strip)
    x0, y0, x1, y1 = b[1]
    save_image("cave_ground_dirt", rgba.crop((x0 + 6, y0 + 6, x1 - 6, y1 - 6)).resize((TILE, TILE), Image.LANCZOS))
    save_image("cave_tile_grass_float", crop(rgba, b[2]).resize((TILE, TILE), Image.LANCZOS))
    save_image("bg_cave", load(f"{ART}/bg_cave.png").convert("RGB"))
    save_image("party", load(f"{ART}/party_scene.png").convert("RGB"))  # the birthday party finale

    rgba, b = sheet_items("deco_cave", min_area=1500)
    assert len(b) == 9, len(b)
    # 0-2 purple crystals small/medium/large, 3 blue crystal, 4 glowing blue, 5 glowing pink, 6 boulders, 7 stalactite, 8 sign
    for i, (name, height) in enumerate([("crystal_s", 40), ("crystal_m", 58), ("crystal_l", 90), ("crystal_blue", 60)]):
        save_image(f"cave_deco_{name}", scale_to_height(crop(rgba, b[i]), height))
    # twin crystal walls: glowing pink (only Janani passes) and blue (only Janika), one tile each
    save_image("barrier_janani", crop(rgba, b[5]).resize((TILE, TILE), Image.LANCZOS))
    save_image("barrier_janika", crop(rgba, b[4]).resize((TILE, TILE), Image.LANCZOS))
    save_image("boulder", crop(rgba, b[6]).resize((TILE + 8, 52), Image.LANCZOS))
    save_image("stalactite", scale_to_height(crop(rgba, b[7]), 120))


# ---------------------------------------------------------------- characters -------
def enemies():
    rgba, b = sheet_items("enemies")
    assert len(b) == 18, len(b)
    # rows of (mushroom, bee, snail); rows 0-4 walking, row 5 defeated
    for col, key, h, cell in [(0, "mushroom", 64, (76, 72)), (1, "bee", 52, (64, 60)), (2, "snail", 58, (100, 64))]:
        frames = [crop(rgba, b[r * 3 + col]) for r in range(6)]
        f = h / (frames[0].height)
        frames = [scale_by(x, f) for x in frames]
        save_strip(key, frames, *cell)


def kitty():
    rgba, b = sheet_items("kitty")
    assert len(b) == 13, len(b)
    # 0-3 sitting (idle, tail swish, idle, mouth open), 4 sit, 5 talk, 6 wave, 7 sit smile, 8 jump, 9-12 walk
    f = 76 / (b[0][3] - b[0][1])
    frames = [scale_by(crop(rgba, x), f) for x in b]
    frames[8] = frames[8].transpose(Image.FLIP_LEFT_RIGHT)    # jump faces the other way
    frames[10] = frames[10].transpose(Image.FLIP_LEFT_RIGHT)  # so does walk frame 2
    save_strip("kitty", frames[:12], 112, 84)                  # walk frame 4 skipped (watermark)


def collectibles():
    rgba, b = sheet_items("collectibles")
    assert len(b) == 8, len(b)
    gem = [scale_to_height(crop(rgba, x), 40) for x in b[1:4]]  # single crystals spin
    save_strip("gem", gem, 32, 42)
    save_image("gem_big", scale_to_height(crop(rgba, b[0]), 60))  # the crystal cluster: 3 hidden per level
    for key, i, h in [("cupcake", 4, 46), ("star", 5, 50), ("heart", 6, 40), ("candle", 7, 50)]:
        save_image(key, scale_to_height(crop(rgba, b[i]), h))


def decorations():
    rgba, b = sheet_items("deco_meadow", min_area=1500)
    names = ["bush", "bush_tall", "bush_flowers", "flowers_yellow", "flowers_purple", "tree_small",
             "tree", "tree_round", "rock", "rock2", "fence", "sign", "tuft", "tuft2"]
    assert len(b) == len(names), len(b)
    for n, box in zip(names, b):
        save_image(f"deco_{n}", scale_by(crop(rgba, box), 0.62))


def scenery():
    rgba, b = sheet_items("finish_gate")
    save_image("finish_gate", scale_to_height(crop(rgba, b[0]), 270))
    bg = load(f"{ART}/bg_meadow.png")
    save_image("bg_meadow", bg.resize((round(bg.width * 720 / bg.height), 720), Image.LANCZOS))


def story_characters():
    """Yuva (boss), Janika (twin) and the square face portraits for dialogue boxes."""
    rgba, b = sheet_items("boss_confident")
    assert len(b) == 9, len(b)
    # 0-1 idle, 2 throw wind-up, 3 throw (with bomb), 4 jump, 5 sitting defeated, 6 tongue close-up, 7 cake, 8 dizzy close-up
    f = 176 / (b[0][3] - b[0][1])

    def without_bomb(r, box):
        """The throw frame with the bomb cut away; returns (thrower, bomb)."""
        sub = crop(r, box)
        parts = find_items(sub, merge=1, min_area=200)
        body = max(parts, key=lambda p: (p[2] - p[0]) * (p[3] - p[1]))
        bomb = min(parts, key=lambda p: (p[2] - p[0]) * (p[3] - p[1]))
        return sub.crop(body), sub.crop(bomb)

    thrower, bomb = without_bomb(rgba, b[3])
    pan, pb = sheet_items("boss_panicked")
    assert len(pb) == 10, len(pb)
    # panicked sheet: 0 crying idle, 1 idle, 2 dizzy sway, 3 crying wind-up, 4 dizzy throw (with bomb), 5 crying jump, 6 sitting
    dizzy_thrower, _ = without_bomb(pan, pb[4])
    # strip order (frames 0-4 are used by the cutscenes, the rest by the boss fight):
    #   0 idle, 1 idle, 2 wind-up, 3 jump, 4 sitting, 5 throw, 6 crying idle, 7 dizzy sway,
    #   8 crying wind-up, 9 dizzy throw, 10 crying jump, 11 holding the cake
    boss = [crop(rgba, b[i]) for i in (0, 1, 2, 4, 5)] + [thrower] + \
           [crop(pan, pb[i]) for i in (0, 2, 3)] + [dizzy_thrower, crop(pan, pb[5]), crop(rgba, b[7])]
    save_strip("boss", [scale_by(x, f) for x in boss], 210, 190, center=body_center_x)
    save_image("bomb", scale_by(bomb, f))
    save_image("portrait_yuva", scale_to_height(crop(rgba, b[6]), 128))

    janika()
    # Janika's dialogue portrait: Gemini's new one made from her photo (same style as Janani's app icon)
    save_image("portrait_janika", load(f"{ART}/janika_portrait.png").convert("RGBA").resize((128, 128), Image.LANCZOS))

    icon = load(f"{ART}/app_icon.png").convert("RGBA")
    save_image("portrait_janani", icon.resize((128, 128), Image.LANCZOS))
    rgba, b = sheet_items("kitty")
    save_image("portrait_kitty", scale_to_height(crop(rgba, b[0]), 128))

    rgba, b = sheet_items("deco_night")
    # 0-2 balloon bunches, 3 single balloon, 4 moon, 5-6 stars, 7-8 clouds
    save_image("balloons", scale_to_height(crop(rgba, b[1]), 120))
    save_image("balloon_pink", scale_to_height(crop(rgba, b[3]), 90))
    save_image("moon", scale_to_height(crop(rgba, b[4]), 120))
    save_image("star_lucky", scale_to_height(crop(rgba, b[6]), 46))   # twinkle star: the gem magnet power-up
    save_image("cloud_small", scale_to_height(crop(rgba, b[7]), 70))
    save_image("cloud_big", scale_to_height(crop(rgba, b[8]), 90))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    heroes(); smooth_anims(); janani_outfit_anims(); world_props(); cave(); tiles(); enemies(); kitty(); collectibles(); decorations(); scenery(); story_characters()
    # the game imports this to know every sprite's frame size
    with open("game/src/manifest.json", "w") as fh:
        json.dump(manifest, fh, indent=1)
    print(f"wrote {len(manifest)} assets to {OUT}")
