"""Build all Janani HD outfits directly from Claude's Beta Janani reference.
Strict adherence to all rules:
1. "dont change the face or anythign just change the dress" -> Face and hair 100% untouched Claude original.
2. "remove that key from the hand dotn forget it" -> Clean clenched fist, zero keys across all frames.
3. "and also dont need id card from upcomming dress not this you can cont this one" -> No lanyard on black, jacket, top25, maroon.
4. "thr opening kurti is thenerrormwhen creating fix it" -> Closed jump dress/kurti from rise to landing.
5. "the fixed one it not correct i am asking that when you are creating for new outfit fix the error not for this one" -> Beta untouched.
6. "dont want that 25 model del it and create it using clauds one" -> Top25 built from Claude base.
7. "doo all frames and all frames for every outfit and notify me before that dont stop" -> All 13 run, 25 jump, 25 hurt frames.
"""
import json
import os
import numpy as np
from PIL import Image

CELL = 210
OUT_DIR = "godot/assets/hd"
os.makedirs(OUT_DIR, exist_ok=True)

# Master Palettes
SKIN_BASE = np.array([195, 120, 92, 255], dtype=np.uint8)
SKIN_SHADOW = np.array([160, 85, 62, 255], dtype=np.uint8)
SKIN_OUTLINE = np.array([75, 38, 32, 255], dtype=np.uint8)

BLACK_BASE = np.array([36, 33, 40, 255], dtype=np.uint8)
BLACK_SHADOW = np.array([22, 20, 26, 255], dtype=np.uint8)
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
MAROON_SHADOW = np.array([72, 14, 28, 255], dtype=np.uint8)
MAROON_HIGHLIGHT = np.array([136, 34, 56, 255], dtype=np.uint8)
MAROON_PANTS = np.array([82, 18, 32, 255], dtype=np.uint8)
MAROON_PANTS_SHADOW = np.array([58, 12, 22, 255], dtype=np.uint8)


def clean_keys(arr, top_y, action, frame_idx):
    """Remove all keys and metallic dangling items strictly below the head."""
    h, w = arr.shape[:2]
    head_bottom = top_y + 46  # Face & hair are strictly above this line
    is_standing = (action in ["jump", "hurt"] and frame_idx <= 8) or (action == "jump" and frame_idx >= 23)

    for y in range(head_bottom + 1, h):
        for x in range(25, 108):
            r, g, b, a = arr[y, x]
            if a > 0:
                is_skin = (r > 115 and g > 55 and b > 40 and int(r) > int(g) + 15 and int(r) > int(b) + 20)
                is_hair = (r < 65 and g < 60 and b < 75 and y < head_bottom + 10)
                is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 22)
                is_jean = (int(b) > int(r) + 20 and b > 125 and y > head_bottom + 25)

                if not is_skin and not is_hair and not is_kurti and not is_jean:
                    # Metal key pixels
                    is_metal = (abs(int(r) - int(g)) <= 22 and int(b) >= int(r) - 10)
                    is_key_outline = (r < 75 and g < 75 and b < 95)
                    
                    if is_metal or is_key_outline:
                        if is_standing:
                            if x >= 96:
                                arr[y, x] = [238, 238, 244, 255] # kurti behind
                            elif y >= head_bottom + 35:
                                arr[y, x] = [132, 172, 211, 255] # jeans behind
                            else:
                                arr[y, x] = [0, 0, 0, 0]
                        else:
                            # In running or mid-air jumping
                            if action == "run" and frame_idx in [2, 3, 10]:
                                if y < head_bottom + 35 and x >= 86:
                                    arr[y, x] = [238, 238, 244, 255]
                                elif y >= head_bottom + 35 and x >= 78:
                                    arr[y, x] = [132, 172, 211, 255]
                                else:
                                    arr[y, x] = [0, 0, 0, 0]
                            else:
                                arr[y, x] = [0, 0, 0, 0]

    # Cap trailing fist with dark skin outline
    for y in range(head_bottom + 1, min(head_bottom + 45, h)):
        for x in range(35, 105):
            if arr[y, x, 3] > 100:
                is_skin = (arr[y, x, 0] > 115 and arr[y, x, 1] > 55 and arr[y, x, 2] > 40 and int(arr[y, x, 0]) > int(arr[y, x, 1]) + 15)
                if is_skin and y + 1 < h and arr[y + 1, x, 3] == 0:
                    arr[y + 1, x] = SKIN_OUTLINE

    return arr


def close_jump_garment(arr, top_y, outfit, frame_idx):
    """Close the gap in jumping frames using relative coordinates."""
    # Torso midriff region is relative to top_y
    y_start = top_y + 40
    y_end = top_y + 88
    
    for y in range(y_start, y_end):
        for x in range(80, 155):
            r, g, b, a = arr[y, x]
            if a > 0:
                is_crop_top = (r > 175 and g < 225 and b < 210 and int(r) > int(b) + 15)
                is_belly = (r > 135 and g < 170 and b < 145 and int(r) > int(g) + 18)
                is_belt = (r < 85 and g < 85 and b < 85 and y in range(y_start + 15, y_start + 30) and x < 130)
                is_gap_jeans = (int(b) > int(r) + 15 and b > 95 and y in range(y_start + 15, y_start + 35) and x in range(100, 130))
                
                if is_crop_top or is_belly or is_belt or is_gap_jeans:
                    # Close with kurti fabric
                    arr[y, x] = [238, 238, 244, 255] if y < y_start + 25 else [220, 220, 228, 255]

    # Top25: remove long flapping coat tails behind back
    if outfit == "top25":
        for y in range(top_y + 40, top_y + 115):
            for x in range(25, 85):
                r, g, b, a = arr[y, x]
                if a > 0:
                    is_tail = (r > 180 and g > 180 and b > 180 and abs(int(r)-int(g)) < 25)
                    if is_tail:
                        arr[y, x] = [0, 0, 0, 0]

    return arr


def remove_lanyard_and_badge(arr, top_y, outfit_fabric):
    """Cleanly remove the green lanyard and chest ID card."""
    h, w = arr.shape[:2]
    # 1. Green lanyard on neck (top_y + 25 to top_y + 48)
    for y in range(top_y + 25, top_y + 48):
        for x in range(90, 135):
            r, g, b, a = arr[y, x]
            if a > 40:
                is_green = (g > 50 and int(g) > int(r) + 15 and int(g) >= int(b) - 10)
                if is_green:
                    arr[y, x] = SKIN_BASE if y < top_y + 42 else outfit_fabric

    # 2. Chest lanyard & ID badge (top_y + 46 to top_y + 75)
    for y in range(top_y + 46, min(top_y + 75, h)):
        for x in range(104, 126):
            r, g, b, a = arr[y, x]
            if a > 40:
                is_green = (g > 50 and int(g) > int(r) + 15 and int(g) >= int(b) - 10)
                is_badge = (r > 210 and g > 210 and b > 210 and abs(int(r)-int(g)) < 15) or (r < 65 and g < 65 and b < 75)
                if is_green or is_badge:
                    arr[y, x] = outfit_fabric

    return arr


def process_frame(raw_arr, outfit, action, frame_idx):
    """Transform Claude's raw frame into the specified outfit with 100% precision."""
    arr = raw_arr.copy()
    h, w = arr.shape[:2]
    
    # 1. Find top of character
    ys, xs = np.where(arr[:, :, 3] > 50)
    if len(ys) == 0:
        return arr
    top_y = ys.min()
    head_bottom = top_y + 46

    # 2. Extract and preserve Claude's original head (face + hair)
    # The head is 100% untouched except for the neck lanyard when removed
    orig_head = raw_arr[top_y : head_bottom + 1, :].copy()

    # 3. ALWAYS remove keys
    arr = clean_keys(arr, top_y, action, frame_idx)

    # 4. ALWAYS close jump kurti
    if action == "jump" and 9 <= frame_idx <= 22:
        arr = close_jump_garment(arr, top_y, outfit, frame_idx)

    # 5. Remove lanyard/ID badge on upcoming outfits
    has_lanyard = (outfit in ["kurti", "print"])
    if not has_lanyard:
        outfit_fabric = (
            BLACK_BASE if outfit == "black" else
            BROWN_BASE if outfit == "jacket" else
            TOP25_WHITE if outfit == "top25" else
            MAROON_BASE
        )
        arr = remove_lanyard_and_badge(arr, top_y, outfit_fabric)

    # 6. Outfit-specific clothing transformation (strictly at y >= head_bottom - 2)
    collar_y = head_bottom - 2
    if outfit == "kurti":
        pass  # Clean White Kurti: keys removed, jump closed, lanyard kept

    elif outfit == "print":
        for y in range(collar_y, h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 190 and g > 190 and b > 190 and abs(int(r)-int(g)) < 22)
                    if is_kurti:
                        mx = x % 9
                        my = y % 9
                        if (mx in [4, 5] and my in [3, 4, 5]) or (mx in [3, 6] and my == 4):
                            arr[y, x] = [48, 44, 62, 255]

    elif outfit == "black":
        for y in range(collar_y, h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 180 and g > 180 and b > 180 and abs(int(r)-int(g)) < 25)
                    is_jean = (int(b) > int(r) + 20 and b > 120 and y > head_bottom + 25)
                    is_shoe = (y > top_y + 115 and ((r > 190 and g > 190 and b > 190) or (r > 140 and g < 70 and b < 70)))
                    
                    if is_kurti:
                        # Short sleeves: lower arms become bare skin
                        is_forearm = (y in range(top_y + 45, top_y + 80) and (x in range(65, 88) or x in range(125, 148)))
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
                        # Knee length dress: above top_y + 90 is dress, below is bare legs
                        if y <= top_y + 90:
                            arr[y, x] = BLACK_SHADOW if x < 100 else BLACK_BASE
                        else:
                            arr[y, x] = SKIN_BASE if b > 180 else SKIN_SHADOW
                    elif is_shoe:
                        arr[y, x] = BLACK_SHADOW if y > top_y + 130 else BLACK_BASE

    elif outfit == "jacket":
        for y in range(collar_y, h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 180 and g > 180 and b > 180 and abs(int(r)-int(g)) < 25)
                    is_jean = (int(b) > int(r) + 20 and b > 120 and y > head_bottom + 25)
                    is_shoe = (y > top_y + 115 and ((r > 190 and g > 190 and b > 190) or (r > 140 and g < 70 and b < 70)))

                    if is_kurti:
                        if r > 225:
                            arr[y, x] = BROWN_HIGHLIGHT
                        elif r > 195:
                            arr[y, x] = BROWN_BASE
                        else:
                            arr[y, x] = BROWN_SHADOW
                    elif is_jean:
                        if b > 180:
                            arr[y, x] = CREAM_HIGHLIGHT
                        elif b > 140:
                            arr[y, x] = CREAM_BASE
                        else:
                            arr[y, x] = CREAM_SHADOW
                    elif is_shoe:
                        arr[y, x] = BROWN_SHADOW if y > top_y + 130 else BROWN_BASE

    elif outfit == "top25":
        for y in range(collar_y, h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 180 and g > 180 and b > 180 and abs(int(r)-int(g)) < 25)
                    is_shoe = (y > top_y + 115 and ((r > 190 and g > 190 and b > 190) or (r > 140 and g < 70 and b < 70)))

                    if is_kurti:
                        midriff_start = top_y + 60
                        midriff_end = top_y + 72
                        if y in range(midriff_start, midriff_end) and 95 <= x <= 130:
                            # Bare midriff slice
                            arr[y, x] = SKIN_BASE if r > 215 else SKIN_SHADOW
                        elif y >= midriff_end:
                            # Below midriff is jeans
                            if x < 88 or x > 130:
                                arr[y, x] = [0, 0, 0, 0]
                            else:
                                arr[y, x] = JEANS_BASE if r > 215 else JEANS_SHADOW
                        else:
                            # Top with '25'
                            is_num_25 = False
                            num_top = top_y + 48
                            if y in range(num_top, num_top + 10) and x in range(108, 122):
                                dx2 = x - 109
                                dy = y - num_top
                                if 0 <= dx2 <= 4:
                                    if dy in [0, 4, 9] or (dy in [1, 2, 3] and dx2 >= 3) or (dy in [5, 6, 7, 8] and dx2 <= 1):
                                        is_num_25 = True
                                dx5 = x - 116
                                if 0 <= dx5 <= 4:
                                    if dy in [0, 4, 9] or (dy in [1, 2, 3] and dx5 <= 1) or (dy in [5, 6, 7, 8] and dx5 >= 3):
                                        is_num_25 = True
                            if is_num_25:
                                arr[y, x] = TOP25_NAVY
                            else:
                                arr[y, x] = TOP25_WHITE if r > 210 else [215, 212, 206, 255]
                    elif is_shoe:
                        arr[y, x] = [240, 240, 245, 255] if y > top_y + 130 else [30, 30, 36, 255]

    elif outfit == "maroon":
        for y in range(collar_y, h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 180 and g > 180 and b > 180 and abs(int(r)-int(g)) < 25)
                    is_jean = (int(b) > int(r) + 20 and b > 120 and y > head_bottom + 25)
                    is_shoe = (y > top_y + 115 and ((r > 190 and g > 190 and b > 190) or (r > 140 and g < 70 and b < 70)))

                    if is_kurti:
                        is_sleeve = (x in range(65, 88) or x in range(125, 150))
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
                        arr[y, x] = MAROON_PANTS if b > 180 else MAROON_PANTS_SHADOW
                    elif is_shoe:
                        arr[y, x] = MAROON_SHADOW if y > top_y + 130 else MAROON_BASE

    # 7. Strictly restore Claude's face & hair on top
    # For kurti & print: 100% of the original head region is restored
    if has_lanyard:
        arr[top_y : head_bottom + 1, :] = orig_head
    else:
        # Restore everything on head except the green lanyard strap that was removed
        for y in range(top_y, head_bottom + 1):
            for x in range(w):
                og_r, og_g, og_b, og_a = orig_head[y - top_y, x]
                if og_a > 40:
                    is_green_strap = (og_g > 50 and int(og_g) > int(og_r) + 15 and int(og_g) >= int(og_b) - 10)
                    if not is_green_strap:
                        arr[y, x] = orig_head[y - top_y, x]

    return arr


def build_all():
    actions = {
        "run": 13,
        "jump": 25,
        "hurt": 25
    }
    outfits = ["kurti", "print", "black", "jacket", "top25", "maroon"]

    for outfit in outfits:
        print(f"=== Generating Complete HD Action Sets: {outfit} ===")
        for action, frame_cnt in actions.items():
            src_path = f"godot/assets/hd/beta_{action}.png"
            src_im = Image.open(src_path)
            out_strip = Image.new("RGBA", (CELL * frame_cnt, CELL), (0, 0, 0, 0))
            
            for f_idx in range(frame_cnt):
                f_crop = src_im.crop((f_idx * CELL, 0, (f_idx + 1) * CELL, CELL))
                f_arr = np.array(f_crop)
                out_arr = process_frame(f_arr, outfit, action, f_idx)
                out_strip.paste(Image.fromarray(out_arr, "RGBA"), (f_idx * CELL, 0))
                
            save_path = f"{OUT_DIR}/{outfit}_{action}.png"
            out_strip.save(save_path)
            print(f"  Saved {save_path} ({frame_cnt} frames)")

    # Update data/hd.json
    hd_path = "godot/data/hd.json"
    data = json.load(open(hd_path)) if os.path.exists(hd_path) else {}
    for outfit in outfits:
        data[outfit] = {
            "cell": CELL,
            "base": "kurti",
            "actions": {
                "run": {"key": f"hd/{outfit}_run", "frames": 13, "fps": 12},
                "jump": {"key": f"hd/{outfit}_jump", "frames": 25, "fps": 24},
                "hurt": {"key": f"hd/{outfit}_hurt", "frames": 25, "fps": 24}
            }
        }
    json.dump(data, open(hd_path, "w"), indent=1)
    print(f"Updated {hd_path} with all 6 outfits!")


if __name__ == "__main__":
    build_all()
