"""Prepare UI elements and RPG page graphics for Godot.

Copies and organizes assets from art/packs into:
- godot/assets/ui/ (level select table, header, buttons, lock, stars)
- godot/assets/rpg/ (cottage interior, walls, furniture, details)

Run from project root: .venv/bin/python tools/prepare_ui_and_rpg.py
"""
import os
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path("/Users/gowthamyuvaraj/Desktop/developer/gracy the adventurer")
UI_OUT = ROOT / "godot" / "assets" / "ui"
RPG_OUT = ROOT / "godot" / "assets" / "rpg"

UI_OUT.mkdir(parents=True, exist_ok=True)
RPG_OUT.mkdir(parents=True, exist_ok=True)

# 1. Copy Jungle Cartoon UI level select pieces
jungle_ls = ROOT / "art" / "packs" / "gui" / "jungle-cartoon-ui" / "PNG" / "level_select"
for fname in ["table.png", "table2.png", "header.png", "lock.png", "close_2.png", "dot_a.png", "dot_d.png", "star_1.png", "star_2.png", "star_3.png", "star_4.png"]:
    src = jungle_ls / fname
    if src.exists():
        shutil.copy(src, UI_OUT / fname)

# 2. Copy Jungle Cartoon UI buttons
jungle_btn = ROOT / "art" / "packs" / "gui" / "jungle-cartoon-ui" / "PNG" / "btn"
btn_map = {
    "play.png": "btn_play.png",
    "menu.png": "btn_menu.png",
    "restart.png": "btn_restart.png",
    "settings.png": "btn_settings.png",
    "sound.png": "btn_sound.png",
    "sound_off.png": "btn_sound_off.png",
    "misic.png": "btn_music.png",
    "music_off.png": "btn_music_off.png",
    "shop.png": "btn_shop.png",
    "pause.png": "btn_pause.png",
    "close.png": "btn_close.png",
}
for src_name, dst_name in btn_map.items():
    src = jungle_btn / src_name
    if src.exists():
        shutil.copy(src, UI_OUT / dst_name)

# 3. Copy Top-Down Home assets (for RPG Cottage)
home_png = ROOT / "art" / "packs" / "top_down" / "main-characters-home-top-down" / "PNG"
for fname in ["Interior.png", "walls_floor.png", "house_details.png", "ground_grass_details.png", "exterior.png"]:
    src = home_png / fname
    if src.exists():
        shutil.copy(src, RPG_OUT / fname)

# Also assemble a full cozy room background for the Cottage RPG page
# Using walls_floor and Interior pieces to create a 1280x720 diorama
# or let Godot assemble it dynamically! We will provide individual textures + helper.

# 4. Copy Chapel / Sanctuary top-down assets
chapel_files = ROOT / "art" / "packs" / "top_down" / "chapel-top-down" / "Tiled_files"
for fname in ["Candles.png", "Candelabra.png", "Statues.png", "Decorative_cracks.png"]:
    src = chapel_files / fname
    if src.exists():
        shutil.copy(src, RPG_OUT / fname)

print(f"Prepared UI assets in: {UI_OUT}")
print(f"Prepared RPG assets in: {RPG_OUT}")
print("Files copied:")
for f in sorted(UI_OUT.glob("*.png")):
    print("  UI:", f.name)
for f in sorted(RPG_OUT.glob("*.png")):
    print("  RPG:", f.name)
