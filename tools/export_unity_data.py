"""Copies the game's art and room data from the Godot project into the Unity project.

Run from the project folder:  .venv/bin/python tools/export_unity_data.py
The Godot files are only read. Writes, under unity/Assets/Resources/ (Unity loads these by name at run time):
  Data/rooms.json   {"rooms": [ every room of godot/data/rooms.json ]}   (Unity's JSON reader wants a list)
  Data/janani.json  {"cell": 210, "clips": [{name, file, frames, fps, w, h, ax}]}  Janani's strips (one outfit)
  Art/Janani/*.png  her animation strips      Art/Skins/<area>/*.png  each area's tiles and backgrounds
  Art/Props/*.png   ladder, boulder, barrel, spikes, gem
"""
import json
import os
import shutil

SRC = "godot"
DST = "unity/Assets/Resources"
OUTFIT = "beta7"  # the "25" Janani: the set with the sword slash and the ladder climb
PROPS = ["ladder", "boulder", "barrel", "tile_spikes", "gem", "icon_fire"]


def copy(src, dst_dir):
    os.makedirs(dst_dir, exist_ok=True)
    shutil.copy2(src, os.path.join(dst_dir, os.path.basename(src)))


def main():
    # rooms: a list instead of a map
    rooms = json.load(open(f"{SRC}/data/rooms.json"))
    os.makedirs(f"{DST}/Data", exist_ok=True)
    json.dump({"rooms": list(rooms.values())}, open(f"{DST}/Data/rooms.json", "w"), indent=1)

    # Janani: her strips and how they are cut
    hd = json.load(open(f"{SRC}/data/hd.json"))[OUTFIT]
    clips = []
    for name, a in hd["actions"].items():
        file = a["key"].split("/")[-1]
        copy(f"{SRC}/assets/{a['key']}.png", f"{DST}/Art/Janani")
        clips.append({"name": name, "file": file, "frames": a["frames"], "fps": a["fps"],
                      "w": a.get("w", hd["cell"]), "h": a.get("h", hd["cell"]), "ax": a.get("ax", hd["cell"] // 2)})
    json.dump({"cell": hd["cell"], "clips": clips}, open(f"{DST}/Data/janani.json", "w"), indent=1)

    # each area's art pack, and the props
    for skin in sorted(os.listdir(f"{SRC}/assets/skins")):
        folder = f"{SRC}/assets/skins/{skin}"
        for f in sorted(os.listdir(folder)):
            if f.endswith(".png"):
                copy(f"{folder}/{f}", f"{DST}/Art/Skins/{skin}")
    for p in PROPS:
        src = f"{SRC}/assets/pack/{p}.png"
        copy(src if os.path.exists(src) else f"{SRC}/assets/{p}.png", f"{DST}/Art/Props")

    print(f"{len(rooms)} rooms, {len(clips)} Janani clips, art copied to {DST}")


main()
