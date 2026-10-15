"""Copy the menu-screen backgrounds from the art packs into the Godot game, layer by layer.

Run from the project folder:  .venv/bin/python tools/prepare_gui.py
Writes godot/assets/backdrops/<name>/<n>.png at 1280x720 (0 = the farthest layer). Used by scripts/ui.gd.
The fonts (godot/fonts/cinzel.ttf, nunito.ttf) come from Google Fonts (SIL Open Font License, fonts/OFL.txt).
"""
import os
import shutil
from PIL import Image

BACKS = "art/packs/backgrounds"
OUT = "godot/assets/backdrops"

# name: (folder, layer files from the back to the front)
SCREENS = {
    # the title screen: a deep teal forest with fireflies
    "teal_forest": ("cartoon-forest-backgrounds/PNG/Cartoon_Forest_BG_02/Layers",
                    ["Sky", "BG_Decor", "Middle_Decor", "Ground", "Foreground"]),
    # the wardrobe and results: a dusky forest with hanging lanterns
    "lantern_forest": ("cartoon-forest-backgrounds/PNG/Cartoon_Forest_BG_04/Layers",
                       ["Sky", "BG_Decor", "Middle_Decor", "Ground", "Foreground"]),
    # the candle shrine and the story: an enchanted purple wood with glowing lights
    "enchanted_wood": ("fairy-tale-game-backgrounds/_PNG/2", ["7", "6", "5", "4", "3", "2", "1"]),
}


def main():
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    for name, (folder, layers) in SCREENS.items():
        os.makedirs(f"{OUT}/{name}")
        for i, layer in enumerate(layers):
            im = Image.open(f"{BACKS}/{folder}/{layer}.png").convert("RGBA").resize((1280, 720), Image.LANCZOS)
            im.save(f"{OUT}/{name}/{i}.png")
    print(f"wrote {len(SCREENS)} backgrounds")


main()
