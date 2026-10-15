"""Fix Claude HD sprites:
1. Remove all keys and keychains from Janani's hands across all animation frames.
2. Fix the opening kurti error in beta_jump (frames 9-19) so the kurti stays completely closed.
"""
import os
import numpy as np
from PIL import Image

CELL = 210


def remove_keys_from_frame(arr):
    """Remove metallic purple/grey keys from hand in a 210x210 frame."""
    h, w = arr.shape[:2]
    # Keys typically hang below the trailing wrist/hand
    for y in range(80, 160):
        for x in range(30, 95):
            r, g, b, a = arr[y, x]
            if a > 0:
                # Key body: metallic lavender/grey (b >= r - 15, b >= g, not bright white kurti, not skin)
                is_skin = (r > 130 and g > 65 and b > 40 and r > g + 25 and r > b + 35)
                is_white_kurti = (r > 190 and g > 190 and b > 200)
                is_key_color = (b >= r - 15) and (b >= g) and not is_white_kurti and not is_skin
                is_dark_key_outline = (r < 75 and g < 70 and b < 85 and a > 0)
                # Check proximity to known key areas
                if is_key_color or (is_dark_key_outline and not is_skin and y > 110):
                    arr[y, x] = [0, 0, 0, 0]
    return arr


def close_kurti_in_jump_frame(arr):
    """Close the open kurti gap in mid-air jump frames."""
    # The gap in beta_jump frames 9-19 is around x: [102, 128], y: [75, 120]
    for y in range(75, 120):
        for x in range(102, 128):
            r, g, b, a = arr[y, x]
            if a > 0:
                # Exposed crop top (beige/tan)
                is_crop_top = (r > 185 and g < 225 and b < 210 and r > b + 15)
                # Exposed stomach skin
                is_belly = (r > 140 and g < 160 and b < 135 and r > g + 25)
                # Dark belt
                is_belt = (y in range(97, 105) and r < 80 and g < 80 and b < 80 and x < 122)
                # Jeans in the front gap
                is_gap_jeans = (y in range(95, 118) and b > r + 15 and b > 100)
                
                if is_crop_top or is_belly or is_belt or is_gap_jeans:
                    # Fill with white kurti fabric with subtle vertical shading
                    shade = 238 if y < 105 else 222
                    arr[y, x] = [shade, shade, shade + 6, 255]

    # Add a clean bottom hemline definition to the closed kurti tunic
    for x in range(102, 126):
        if arr[118, x, 3] > 0 and arr[117, x, 3] > 0:
            arr[118, x] = [75, 75, 95, 255]

    return arr


def process_action(action_name, close_kurti=False):
    path = f"godot/assets/hd/beta_{action_name}.png"
    if not os.path.exists(path):
        print(f"Skipping {path} (not found)")
        return

    im = Image.open(path).convert("RGBA")
    count = im.width // CELL
    print(f"Processing {action_name}: {count} frames...")

    out_im = Image.new("RGBA", (im.width, im.height), (0, 0, 0, 0))
    for i in range(count):
        frame = im.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        arr = np.array(frame)
        
        # 1. Remove keys
        arr = remove_keys_from_frame(arr)
        
        # 2. Close kurti on jump frames 9-19
        if close_kurti and 9 <= i <= 19:
            arr = close_kurti_in_jump_frame(arr)
            
        fixed_frame = Image.fromarray(arr, "RGBA")
        out_im.paste(fixed_frame, (i * CELL, 0))

    # Backup original before saving
    backup_path = f"godot/assets/hd/beta_{action_name}_orig.png"
    if not os.path.exists(backup_path):
        im.save(backup_path)
        print(f"  Backed up original to {backup_path}")

    out_im.save(path)
    print(f"  Saved fixed {path}")


def main():
    print("--- Fixing Claude HD Sprites ---")
    process_action("run", close_kurti=False)
    process_action("jump", close_kurti=True)
    process_action("hurt", close_kurti=False)
    process_action("attack", close_kurti=False)
    print("All HD sprites successfully fixed!")


if __name__ == "__main__":
    main()
