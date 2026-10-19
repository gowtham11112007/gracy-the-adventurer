"""The Unity game's hand-made levels (unity/Assets/Resources/Data/levels.json), drawn with the Asset Store packs.

Run from the project folder:  python3 tools/build_unity_levels.py
Same grid as the rooms (12 rows, row 10 and 11 are ground, one character = one tile), plus scenery:
  #  ground       =  wooden platform    L  ladder      o  gem
  C  crate        O  barrel             R  stump       ^  spike plate        (solid: hop over them)
  scenery, standing on the ground, drawn behind Janani (no collision):
  w well   k scarecrow   p lamp post (glows)   c campfire (glows)   s sign   h hay   u sunflowers
  b bush   t tree   g grass   f fence   x wheelbarrow
  E  the Stone of Recall: touching it finishes the level
"""
import json

ROWS, WIDE = 12, 72


def level1():
    g = [[" "] * WIDE for _ in range(ROWS)]
    for r in (10, 11):
        g[r] = ["#"] * WIDE
    for c in (40, 41):  # a gap in the ground (under the platform)
        g[10][c] = g[11][c] = " "
    for c in range(34, 47):  # the upper floor, reached by the ladder
        g[5][c] = "="
    for r in range(5, 10):
        g[r][34] = "L"
    on_ground = {3: "s", 6: "p", 9: "w", 11: "g", 14: "C", 17: "h", 20: "O", 23: "t", 24: "g", 26: "k", 29: "R",
                 31: "u", 37: "c", 39: "g", 44: "^", 47: "p", 49: "C", 51: "f", 52: "f", 53: "f", 55: "g",
                 56: "O", 58: "b", 60: "x", 62: "g", 63: "u", 65: "p", 68: "E"}
    for c, ch in on_ground.items():
        g[9][c] = ch
    for cols, r in ((range(13, 16), 8), (range(19, 22), 8), (range(48, 51), 8), (range(36, 46), 4)):
        for c in cols:
            g[r][c] = "o"
    return {"id": "level1", "name": "Lantern Village", "area_name": "World 1 · Level 1", "area": "village", "mood": "village",
            "width": WIDE, "start": 2, "exits": [], "benches": [], "grid": ["".join(row) for row in g]}


levels = [level1()]
json.dump({"rooms": levels}, open("unity/Assets/Resources/Data/levels.json", "w"), indent=1)
for lv in levels:
    print(lv["id"], lv["name"])
    print("\n".join(lv["grid"]))
