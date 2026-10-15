"""Build all Janani HD outfits for Gracy the Adventurer.
Generates full animation sets (run, jump, hurt) for:
- kurti (White Kurti HD, closed jump, no keys)
- print (Printed Kurti, closed jump, no keys)
- black (Black Dress, no lanyard, no keys)
- jacket (Brown Jacket, no lanyard, no keys)
- top25 (The '25' Top, no lanyard, no keys)
- maroon (Maroon Churidar, no lanyard, no keys)

Keeps Claude's original 'beta' untouched in hd.json and assets/hd/.
"""
import json
import os
import numpy as np
from PIL import Image

CELL = 210
SCALE = 168.0 / 245.0
OUT_DIR = "godot/assets/hd"
os.makedirs(OUT_DIR, exist_ok=True)

# Master Color Palettes
SKIN_BASE = np.array([195, 120, 92, 255], dtype=np.uint8)
SKIN_SHADOW = np.array([155, 82, 60, 255], dtype=np.uint8)
SKIN_OUTLINE = np.array([75, 36, 30, 255], dtype=np.uint8)

BLACK_BASE = np.array([36, 33, 40, 255], dtype=np.uint8)
BLACK_SHADOW = np.array([20, 18, 24, 255], dtype=np.uint8)
BLACK_HIGHLIGHT = np.array([55, 50, 62, 255], dtype=np.uint8)

BROWN_BASE = np.array([105, 62, 34, 255], dtype=np.uint8)
BROWN_SHADOW = np.array([72, 40, 20, 255], dtype=np.uint8)
BROWN_HIGHLIGHT = np.array([138, 85, 48, 255], dtype=np.uint8)

CREAM_BASE = np.array([218, 208, 184, 255], dtype=np.uint8)
CREAM_SHADOW = np.array([182, 168, 142, 255], dtype=np.uint8)
CREAM_HIGHLIGHT = np.array([238, 230, 210, 255], dtype=np.uint8)

TOP25_WHITE = np.array([235, 232, 226, 255], dtype=np.uint8)
TOP25_NAVY = np.array([28, 38, 68, 255], dtype=np.uint8)
JEANS_BASE = np.array([132, 172, 211, 255], dtype=np.uint8)
JEANS_SHADOW = np.array([95, 135, 175, 255], dtype=np.uint8)

MAROON_BASE = np.array([104, 22, 40, 255], dtype=np.uint8)
MAROON_SHADOW = np.array([66, 12, 24, 255], dtype=np.uint8)
MAROON_HIGHLIGHT = np.array([136, 34, 56, 255], dtype=np.uint8)
MAROON_PANTS = np.array([76, 16, 28, 255], dtype=np.uint8)
MAROON_PANTS_SHADOW = np.array([50, 10, 18, 255], dtype=np.uint8)


def load_scaled_pose(path):
    im = Image.open(path).convert("RGBA")
    w = round(im.width * SCALE)
    h = round(im.height * SCALE)
    return im.resize((w, h), Image.LANCZOS)


# Load master pose references
POSE_RISE = load_scaled_pose("/tmp/pose_0.png")
POSE_PEAK = load_scaled_pose("/tmp/pose_1.png")
POSE_FALL = load_scaled_pose("/tmp/pose_2.png")
POSE_HURT = load_scaled_pose("/tmp/pose_3.png")
POSE_VICTORY = load_scaled_pose("/tmp/pose_4.png")


def create_pose_frame(scaled_pose, y_offset):
    """Place scaled pose into 210x210 frame."""
    frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    x = (CELL - scaled_pose.width) // 2
    y = CELL - scaled_pose.height - y_offset
    frame.paste(scaled_pose, (x, y), scaled_pose)
    return np.array(frame)


def clean_keys(arr):
    """Remove metallic keys completely and ensure trailing fist is clean and closed."""
    h, w = arr.shape[:2]
    # Trailing hand area
    for y in range(80, 165):
        for x in range(20, 95):
            r, g, b, a = arr[y, x]
            if a > 0:
                is_skin = (r > 105 and g > 30 and b > 20 and int(r) > int(g) + 12 and int(r) > int(b) + 18)
                is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25)
                is_jean = (int(b) > int(r) + 20 and b > 135 and y > 125 and x > 60)
                is_skin_outline = (r < 75 and g < 45 and b < 45 and y < 118 and x > 50)
                
                # Any metal key pixel
                is_metal = (int(b) >= int(r) - 15) and (int(b) >= int(g)) and not is_skin and not is_kurti and not is_jean
                is_metal_dark = (r < 75 and g < 70 and b < 90 and not is_skin and not is_kurti and not is_jean and y > 112)
                is_stray_key = (x < 62 and y >= 115 and not is_skin and not is_kurti)

                if is_metal or is_metal_dark or is_stray_key:
                    arr[y, x] = [0, 0, 0, 0]

    # Clean fist contour
    for y in range(105, 122):
        for x in range(45, 75):
            if arr[y, x, 3] > 100:
                if y + 1 < h and arr[y + 1, x, 3] == 0:
                    arr[y, x] = SKIN_OUTLINE

    return arr


def apply_outfit(arr, outfit):
    """Apply outfit-specific clothing colors, textures, and neckline."""
    h, w = arr.shape[:2]
    has_lanyard = (outfit in ["kurti", "print"])

    # 1. Clean Lanyard / ID badge on upcoming outfits
    if not has_lanyard:
        # A. Strap and strap outline in the neck/chest triangle
        for y in range(50, 115):
            for x in range(95, 125):
                r, g, b, a = arr[y, x]
                if a > 40:
                    is_hair = (r < 55 and g < 50 and b < 65 and y < 82)
                    if is_hair:
                        continue
                    is_skin = (r > 130 and g > 65 and b > 40 and int(r) > int(g) + 20 and int(r) > int(b) + 30)
                    is_white = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25)
                    is_lanyard = (g > 35 and int(g) > int(r) + 6 and int(g) >= int(b) - 8)
                    is_badge = (y in range(80, 115) and x in range(102, 122))
                    
                    if not is_skin and not is_white:
                        # Strap or outline
                        if y < 82:
                            arr[y, x] = SKIN_BASE # clean neck
                        else:
                            arr[y, x] = [254, 254, 254, 255] # sentinel for chest fabric
                    elif is_badge:
                        arr[y, x] = [254, 254, 254, 255]

    # 2. Outfit specific recoloring
    if outfit == "kurti":
        return arr

    elif outfit == "print":
        # White kurti with repeating floral block prints
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 190 and g > 190 and b > 190 and abs(int(r)-int(g)) < 25)
                    if is_kurti:
                        mx = x % 9
                        my = y % 9
                        if (mx in [4, 5] and my in [3, 4, 5]) or (mx in [3, 6] and my == 4):
                            arr[y, x] = [48, 44, 62, 255]
        return arr

    elif outfit == "black":
        # Black dress: bare arms, bare legs below knee, black shoes
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25) or (r == 254 and g == 254 and b == 254)
                    is_jean = (int(b) > int(r) + 15 and b > 115 and y > 110)
                    is_shoe = (y > 150 and ((r > 190 and g > 190 and b > 190) or (r > 130 and g < 70 and b < 70)))

                    if is_kurti:
                        is_forearm = (y in range(80, 115) and (x in range(65, 88) or x in range(125, 148)))
                        if is_forearm:
                            arr[y, x] = SKIN_BASE if r > 215 else SKIN_SHADOW
                        else:
                            if r > 225:
                                arr[y, x] = BLACK_HIGHLIGHT
                            elif r > 195:
                                arr[y, x] = BLACK_BASE
                            else:
                                arr[y, x] = BLACK_SHADOW
                    elif is_jean:
                        if y <= 132:
                            arr[y, x] = BLACK_SHADOW if x < 100 else BLACK_BASE
                        else:
                            arr[y, x] = SKIN_BASE if b > 175 else SKIN_SHADOW
                    elif is_shoe:
                        arr[y, x] = BLACK_SHADOW if y > 165 else BLACK_BASE
        return arr

    elif outfit == "jacket":
        # Brown jacket, cream chinos, brown shoes
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25) or (r == 254 and g == 254 and b == 254)
                    is_jean = (int(b) > int(r) + 15 and b > 115 and y > 110)
                    is_shoe = (y > 150 and ((r > 190 and g > 190 and b > 190) or (r > 130 and g < 70 and b < 70)))

                    if is_kurti:
                        if r > 225:
                            arr[y, x] = BROWN_HIGHLIGHT
                        elif r > 195:
                            arr[y, x] = BROWN_BASE
                        else:
                            arr[y, x] = BROWN_SHADOW
                    elif is_jean:
                        if b > 175:
                            arr[y, x] = CREAM_HIGHLIGHT
                        elif b > 135:
                            arr[y, x] = CREAM_BASE
                        else:
                            arr[y, x] = CREAM_SHADOW
                    elif is_shoe:
                        arr[y, x] = BROWN_SHADOW if y > 165 else BROWN_BASE
        return arr

    elif outfit == "top25":
        # Varsity crop top with '25', bare midriff, blue jeans, black sneakers
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25) or (r == 254 and g == 254 and b == 254)
                    is_shoe = (y > 150 and ((r > 190 and g > 190 and b > 190) or (r > 130 and g < 70 and b < 70)))

                    if is_kurti:
                        if 98 <= y <= 104 and 98 <= x <= 124:
                            arr[y, x] = SKIN_BASE if r > 210 else SKIN_SHADOW
                        elif y > 104:
                            if x < 90 or x > 124:
                                arr[y, x] = [0, 0, 0, 0]
                            else:
                                arr[y, x] = JEANS_BASE if r > 210 else JEANS_SHADOW
                        else:
                            is_num_25 = False
                            if y in range(88, 97) and x in range(104, 118):
                                dx2 = x - 105
                                dy = y - 88
                                if 0 <= dx2 <= 4:
                                    if dy in [0, 4, 8] or (dy in [1, 2, 3] and dx2 >= 3) or (dy in [5, 6, 7] and dx2 <= 1):
                                        is_num_25 = True
                                dx5 = x - 112
                                if 0 <= dx5 <= 4:
                                    if dy in [0, 4, 8] or (dy in [1, 2, 3] and dx5 <= 1) or (dy in [5, 6, 7] and dx5 >= 3):
                                        is_num_25 = True
                            if is_num_25:
                                arr[y, x] = TOP25_NAVY
                            else:
                                arr[y, x] = TOP25_WHITE if r > 210 else [215, 212, 206, 255]
                    elif is_shoe:
                        arr[y, x] = [240, 240, 245, 255] if y > 165 else [30, 30, 36, 255]
        return arr

    elif outfit == "maroon":
        # Maroon churidar: deep maroon tunic, sheer sleeves, maroon churidar, maroon shoes
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25) or (r == 254 and g == 254 and b == 254)
                    is_jean = (int(b) > int(r) + 15 and b > 115 and y > 110)
                    is_shoe = (y > 150 and ((r > 190 and g > 190 and b > 190) or (r > 130 and g < 70 and b < 70)))

                    if is_kurti:
                        is_sleeve = (y in range(75, 115) and (x in range(65, 88) or x in range(125, 148)))
                        if is_sleeve:
                            arr[y, x] = MAROON_HIGHLIGHT if (x + y) % 3 == 0 else [118, 28, 48, 255]
                        else:
                            if r > 225:
                                arr[y, x] = MAROON_HIGHLIGHT
                            elif r > 195:
                                arr[y, x] = MAROON_BASE
                            else:
                                arr[y, x] = MAROON_SHADOW
                    elif is_jean:
                        arr[y, x] = MAROON_PANTS if b > 160 else MAROON_PANTS_SHADOW
                    elif is_shoe:
                        arr[y, x] = MAROON_SHADOW
        return arr

    return arr


def build_outfit_strips(outfit):
    """Build run, jump, hurt strips for an outfit."""
    print(f"--- Building HD Outfit: {outfit} ---")
    run_im = Image.open("godot/assets/hd/beta_run.png").convert("RGBA")
    jump_im = Image.open("godot/assets/hd/beta_jump.png").convert("RGBA")
    hurt_im = Image.open("godot/assets/hd/beta_hurt.png").convert("RGBA")

    # 1. RUN STRIP (13 frames)
    out_run = Image.new("RGBA", (run_im.width, CELL), (0, 0, 0, 0))
    for i in range(13):
        f = run_im.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        arr = np.array(f)
        arr = clean_keys(arr)
        arr = apply_outfit(arr, outfit)
        out_run.paste(Image.fromarray(arr, "RGBA"), (i * CELL, 0))
    out_run.save(f"{OUT_DIR}/{outfit}_run.png")
    print(f"  Saved {OUT_DIR}/{outfit}_run.png (13 frames)")

    # 2. JUMP STRIP (25 frames)
    out_jump = Image.new("RGBA", (jump_im.width, CELL), (0, 0, 0, 0))
    for i in range(25):
        if i == 0:
            arr = create_pose_frame(POSE_VICTORY, 15)
        elif 9 <= i <= 13:
            arr = create_pose_frame(POSE_RISE, 25)
        elif 14 <= i <= 16:
            arr = create_pose_frame(POSE_PEAK, 40)
        elif 17 <= i <= 19:
            arr = create_pose_frame(POSE_FALL, 20)
        else:
            f = jump_im.crop((i * CELL, 0, (i + 1) * CELL, CELL))
            arr = np.array(f)
            arr = clean_keys(arr)

        arr = apply_outfit(arr, outfit)
        out_jump.paste(Image.fromarray(arr, "RGBA"), (i * CELL, 0))
    out_jump.save(f"{OUT_DIR}/{outfit}_jump.png")
    print(f"  Saved {OUT_DIR}/{outfit}_jump.png (25 frames)")

    # 3. HURT STRIP (25 frames)
    out_hurt = Image.new("RGBA", (hurt_im.width, CELL), (0, 0, 0, 0))
    for i in range(25):
        if 8 <= i <= 12:
            arr = create_pose_frame(POSE_HURT, 15)
        else:
            f = hurt_im.crop((i * CELL, 0, (i + 1) * CELL, CELL))
            arr = np.array(f)
            arr = clean_keys(arr)

        arr = apply_outfit(arr, outfit)
        out_hurt.paste(Image.fromarray(arr, "RGBA"), (i * CELL, 0))
    out_hurt.save(f"{OUT_DIR}/{outfit}_hurt.png")
    print(f"  Saved {OUT_DIR}/{outfit}_hurt.png (25 frames)")


def main():
    outfits = ["kurti", "print", "black", "jacket", "top25", "maroon"]
    for out in outfits:
        build_outfit_strips(out)

    # Register in godot/data/hd.json
    hd_path = "godot/data/hd.json"
    data = json.load(open(hd_path)) if os.path.exists(hd_path) else {}
    
    # Preserve beta exactly
    for out in outfits:
        data[out] = {
            "cell": 210,
            "base": "kurti",
            "actions": {
                "run": {"key": f"hd/{out}_run", "frames": 13, "fps": 12},
                "jump": {"key": f"hd/{out}_jump", "frames": 25, "fps": 24},
                "hurt": {"key": f"hd/{out}_hurt", "frames": 25, "fps": 24}
            }
        }
    
    json.dump(data, open(hd_path, "w"), indent=1)
    print(f"Successfully registered all {len(outfits)} outfits in {hd_path}!")


if __name__ == "__main__":
    main()
