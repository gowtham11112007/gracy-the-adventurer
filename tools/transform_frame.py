"""Frame-by-frame transformation engine for Janani HD outfits.
Converts Claude's Beta frames into each outfit with:
1. Complete key removal from hands (clean closed fist).
2. Closed dress/kurti during jump (no flapping coat or exposed stomach).
3. Lanyard/ID card removal on upcoming outfits (black, jacket, top25, maroon).
4. Exact color palettes and style from gemini_refs master art.
"""
import numpy as np
from PIL import Image

CELL = 210

# Master Color Palettes
SKIN_BASE = np.array([195, 120, 92, 255], dtype=np.uint8)
SKIN_SHADOW = np.array([160, 85, 62, 255], dtype=np.uint8)
SKIN_OUTLINE = np.array([75, 38, 32, 255], dtype=np.uint8)

BLACK_DRESS_BASE = np.array([36, 33, 40, 255], dtype=np.uint8)
BLACK_DRESS_SHADOW = np.array([22, 20, 26, 255], dtype=np.uint8)
BLACK_DRESS_HIGHLIGHT = np.array([55, 50, 62, 255], dtype=np.uint8)
BLACK_DRESS_OUTLINE = np.array([14, 12, 18, 255], dtype=np.uint8)

JACKET_BROWN_BASE = np.array([105, 62, 34, 255], dtype=np.uint8)
JACKET_BROWN_SHADOW = np.array([75, 42, 22, 255], dtype=np.uint8)
JACKET_BROWN_HIGHLIGHT = np.array([138, 85, 48, 255], dtype=np.uint8)
JACKET_BROWN_OUTLINE = np.array([42, 22, 12, 255], dtype=np.uint8)

PANTS_CREAM_BASE = np.array([218, 208, 184, 255], dtype=np.uint8)
PANTS_CREAM_SHADOW = np.array([182, 168, 142, 255], dtype=np.uint8)
PANTS_CREAM_HIGHLIGHT = np.array([238, 230, 210, 255], dtype=np.uint8)
PANTS_CREAM_OUTLINE = np.array([72, 60, 48, 255], dtype=np.uint8)

TOP25_WHITE_BASE = np.array([235, 232, 226, 255], dtype=np.uint8)
TOP25_NAVY = np.array([28, 38, 68, 255], dtype=np.uint8)
TOP25_NAVY_HIGHLIGHT = np.array([42, 58, 102, 255], dtype=np.uint8)

MAROON_BASE = np.array([104, 22, 40, 255], dtype=np.uint8)
MAROON_SHADOW = np.array([72, 14, 28, 255], dtype=np.uint8)
MAROON_HIGHLIGHT = np.array([136, 34, 56, 255], dtype=np.uint8)
MAROON_OUTLINE = np.array([38, 6, 14, 255], dtype=np.uint8)
MAROON_PANTS = np.array([82, 18, 32, 255], dtype=np.uint8)
MAROON_PANTS_SHADOW = np.array([58, 12, 22, 255], dtype=np.uint8)


def remove_keys_and_clean_fist(arr, action_name, frame_idx):
    """Erase dangling metallic keys and ensure trailing fist is closed."""
    h, w = arr.shape[:2]
    # In run, jump, hurt, keys are in the trailing hand area
    for y in range(80, 165):
        for x in range(25, 95):
            r, g, b, a = arr[y, x]
            if a > 0:
                is_skin = (r > 105 and g > 30 and b > 20 and int(r) > int(g) + 12 and int(r) > int(b) + 18)
                is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25)
                is_jean = (b > r + 20 and b > 135 and y > 125)
                is_skin_outline = (r < 75 and g < 45 and b < 45 and y < 118 and x > 50)
                
                # Metal keys: lavender/purple hue or metallic grey
                is_metal = (int(b) >= int(r) - 15) and (int(b) >= int(g)) and not is_skin and not is_kurti and not is_jean
                is_metal_dark = (r < 75 and g < 70 and b < 90 and not is_skin and not is_kurti and not is_jean and y > 115)
                
                if (is_metal or is_metal_dark) and not is_skin and not is_kurti:
                    arr[y, x] = [0, 0, 0, 0]

    # Clean fist contour: add bottom outline to trailing hand so fingers are curled in a tight fist
    for y in range(105, 122):
        for x in range(45, 75):
            if arr[y, x, 3] > 100:
                # check if bottom neighbor was erased (part of key loop)
                if y + 1 < h and arr[y + 1, x, 3] == 0:
                    arr[y, x] = SKIN_OUTLINE

    return arr


def close_jump_kurti(arr):
    """Close the flapping coat gap in jump frames."""
    for y in range(75, 122):
        for x in range(100, 130):
            r, g, b, a = arr[y, x]
            if a > 0:
                is_crop_top = (r > 175 and g < 225 and b < 210 and int(r) > int(b) + 15)
                is_belly = (r > 135 and g < 165 and b < 140 and int(r) > int(g) + 20)
                is_belt = (y in range(96, 106) and r < 85 and g < 85 and b < 85 and x < 124)
                is_gap_jeans = (y in range(94, 120) and int(b) > int(r) + 15 and b > 95)
                if is_crop_top or is_belly or is_belt or is_gap_jeans:
                    # Shade naturally like the white kurti fabric
                    shade = 238 if y < 104 else 222
                    arr[y, x] = [shade, shade, shade + 6, 255]

    # Curved bottom hemline of closed tunic
    for x in range(100, 126):
        if arr[118, x, 3] > 0 and arr[117, x, 3] > 0:
            arr[118, x] = [75, 75, 95, 255]

    return arr


def remove_lanyard_and_id(arr):
    """Remove green lanyard and ID card, restoring natural neck and chest fabric."""
    # Neck strap: y in [80, 98], x in [110, 126]
    for y in range(80, 98):
        for x in range(110, 126):
            r, g, b, a = arr[y, x]
            if a > 0:
                is_lanyard = (g > 55 and g >= b and int(g) > int(r) + 12)
                is_clip = (r < 65 and g < 65 and b < 75 and y in range(92, 98))
                if is_lanyard or is_clip:
                    arr[y, x] = SKIN_BASE if y < 94 else SKIN_SHADOW

    # Chest badge & lower strap: y in [98, 126], x in [110, 126]
    for y in range(98, 126):
        for x in range(110, 126):
            r, g, b, a = arr[y, x]
            if a > 0:
                is_lanyard = (g > 55 and g >= b and int(g) > int(r) + 12)
                is_badge = (r > 220 and g > 220 and b > 220) or (r < 75 and g < 75 and b < 85)
                if is_lanyard or is_badge:
                    # mark for chest fabric replacement
                    arr[y, x] = [254, 254, 254, 255] # sentinel

    return arr


def transform_frame(source_arr, outfit, action_name, frame_idx):
    """Transform a single 210x210 frame into the specified outfit."""
    arr = source_arr.copy()
    h, w = arr.shape[:2]

    # 1. ALWAYS remove keys
    arr = remove_keys_and_clean_fist(arr, action_name, frame_idx)

    # 2. ALWAYS close jump kurti for kurti, print, black, jacket, maroon
    if action_name == "jump" and 9 <= frame_idx <= 19 and outfit != "top25":
        arr = close_jump_kurti(arr)

    # 3. Lanyard / ID card removal for upcoming outfits
    has_lanyard = (outfit in ["kurti", "print"])
    if not has_lanyard:
        arr = remove_lanyard_and_id(arr)

    # 4. Outfit-specific color and texture mapping
    if outfit == "kurti":
        # Clean White Kurti: keys removed, jump closed, lanyard kept
        return arr

    elif outfit == "print":
        # Printed Kurti: white kurti with repeating floral block prints
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 190 and g > 190 and b > 190 and abs(int(r)-int(g)) < 25)
                    if is_kurti:
                        # Floral motif grid spaced every 9 px
                        mx = x % 9
                        my = y % 9
                        if (mx in [4, 5] and my in [3, 4, 5]) or (mx in [3, 6] and my == 4):
                            arr[y, x] = [48, 44, 62, 255] # dark floral print
        return arr

    elif outfit == "black":
        # Black Dress: tailored knee-length black dress, bare lower arms, bare legs, black shoes
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25) or (r == 254 and g == 254 and b == 254)
                    is_jean = (int(b) > int(r) + 20 and b > 120 and y > 110)
                    is_shoe = (y > 155 and ((r > 190 and g > 190 and b > 190) or (r > 140 and g < 70 and b < 70)))
                    
                    if is_kurti:
                        # Sleeves from elbow down: convert to bare skin
                        is_forearm = (y in range(90, 115) and (x in range(65, 85) or x in range(125, 148)))
                        if is_forearm:
                            arr[y, x] = SKIN_BASE if r > 215 else SKIN_SHADOW
                        else:
                            # Black dress fabric with subtle lighting
                            if r > 225:
                                arr[y, x] = BLACK_DRESS_HIGHLIGHT
                            elif r > 195:
                                arr[y, x] = BLACK_DRESS_BASE
                            else:
                                arr[y, x] = BLACK_DRESS_SHADOW
                    elif is_jean:
                        # Knee length dress: above y=132 is dress, below y=132 is bare legs!
                        if y <= 132:
                            arr[y, x] = BLACK_DRESS_SHADOW if x < 100 else BLACK_DRESS_BASE
                        else:
                            # Bare legs!
                            arr[y, x] = SKIN_BASE if b > 180 else SKIN_SHADOW
                    elif is_shoe:
                        arr[y, x] = BLACK_DRESS_SHADOW if y > 165 else BLACK_DRESS_BASE
        return arr

    elif outfit == "jacket":
        # Brown Jacket: brown buttoned jacket, cream chinos, brown shoes
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25) or (r == 254 and g == 254 and b == 254)
                    is_jean = (int(b) > int(r) + 20 and b > 120 and y > 110)
                    is_shoe = (y > 155 and ((r > 190 and g > 190 and b > 190) or (r > 140 and g < 70 and b < 70)))

                    if is_kurti:
                        # Brown jacket fabric
                        if r > 225:
                            arr[y, x] = JACKET_BROWN_HIGHLIGHT
                        elif r > 195:
                            arr[y, x] = JACKET_BROWN_BASE
                        else:
                            arr[y, x] = JACKET_BROWN_SHADOW
                    elif is_jean:
                        # Cream / beige chinos
                        if b > 180:
                            arr[y, x] = PANTS_CREAM_HIGHLIGHT
                        elif b > 140:
                            arr[y, x] = PANTS_CREAM_BASE
                        else:
                            arr[y, x] = PANTS_CREAM_SHADOW
                    elif is_shoe:
                        arr[y, x] = JACKET_BROWN_SHADOW if y > 165 else JACKET_BROWN_BASE
        return arr

    elif outfit == "top25":
        # The '25' Top: sporty white/navy crop top with '25', bare midriff, ripped blue jeans, black sneakers
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25) or (r == 254 and g == 254 and b == 254)
                    is_jean = (int(b) > int(r) + 20 and b > 120 and y > 110)
                    is_shoe = (y > 155 and ((r > 190 and g > 190 and b > 190) or (r > 140 and g < 70 and b < 70)))

                    if is_kurti:
                        # Crop top is from shoulders down to y=105; from 105 to 118 is bare midriff!
                        if y > 105:
                            arr[y, x] = SKIN_BASE if r > 215 else SKIN_SHADOW
                        else:
                            # White varsity knit with navy '25' on chest
                            # Chest number area: y in [90, 102], x in [106, 122]
                            is_num_25 = False
                            if y in range(92, 102) and x in range(108, 122):
                                # Digit 2: x in [109, 114]
                                # Digit 5: x in [116, 121]
                                dx2 = x - 109
                                dy = y - 92
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
                                arr[y, x] = TOP25_WHITE_BASE if r > 210 else [215, 212, 206, 255]
                    elif is_shoe:
                        # Black sneakers with white rubber sole
                        arr[y, x] = [240, 240, 245, 255] if y > 165 else [30, 30, 36, 255]
        return arr

    elif outfit == "maroon":
        # Maroon Churidar: deep maroon tunic, sheer patterned sleeves, maroon churidar, maroon shoes
        for y in range(h):
            for x in range(w):
                r, g, b, a = arr[y, x]
                if a > 50:
                    is_kurti = (r > 185 and g > 185 and b > 185 and abs(int(r)-int(g)) < 25) or (r == 254 and g == 254 and b == 254)
                    is_jean = (int(b) > int(r) + 20 and b > 120 and y > 110)
                    is_shoe = (y > 155 and ((r > 190 and g > 190 and b > 190) or (r > 140 and g < 70 and b < 70)))

                    if is_kurti:
                        # Sleeves: sheer patterned maroon
                        is_sleeve = (x in range(65, 88) or x in range(125, 150))
                        if is_sleeve:
                            if (x + y) % 3 == 0:
                                arr[y, x] = MAROON_HIGHLIGHT
                            else:
                                arr[y, x] = [118, 28, 48, 255]
                        else:
                            # Rich maroon tunic
                            if r > 225:
                                arr[y, x] = MAROON_HIGHLIGHT
                            elif r > 195:
                                arr[y, x] = MAROON_BASE
                            else:
                                arr[y, x] = MAROON_SHADOW
                    elif is_jean:
                        # Maroon churidar leggings
                        if b > 180:
                            arr[y, x] = MAROON_PANTS
                        else:
                            arr[y, x] = MAROON_PANTS_SHADOW
                    elif is_shoe:
                        arr[y, x] = MAROON_SHADOW if y > 165 else MAROON_BASE
        return arr

    return arr
