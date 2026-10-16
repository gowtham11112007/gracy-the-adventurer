"""Builds every playable room of the world (godot/data/rooms.json) from the world map (godot/data/world.json).

Run from the project folder:  .venv/bin/python tools/build_rooms.py
Each room is a side-view tile grid, 12 rows high (row 10 and 11 are ground), played with the Beta rules
(a low hop over one-tile obstacles; upper floors only by ladder):
  #  ground      =  floating platform    L  ladder     C crate   R boulder   O barrel   ^ spikes
  o  gem         X  big crystal          c  candle     m mushroom  b bee   n snail  M hopper  d diver
The world map says which rooms touch: a room beside it (left/right) is joined by walking off that edge; a room
above or below is joined by a glowing doorway (press Up in it). An "up" doorway stands on the room's upper floor,
so she climbs the ladder to reach it. `exits`:
  {"side": "left"/"right"/"up"/"down", "to": room id, "arrive": the side she comes in at, "gate": "" or what
   opens it ("dash", "double_jump", "wall_jump", "candles:3"), and for doorways "col" and "row" (where she stands)}
`benches` are columns where she rests (heal and save); `shrine` teaches a move; `boss` is Yuva's arena.
Each area has its own look (mood -> art pack in level.gd), obstacles and animals. The layouts are random but
fixed (seeded by the room id), and checked: nothing blocks a doorway, a ladder or the way in and out.
"""
import json
import random

ROWS = 12
TOP = 5  # the upper floor's row

MOOD = {"meadow": "day", "wood": "windy", "ruins": "sky", "shaft": "sky", "fortress": "golden", "hill": "dusk"}
OBSTACLES = {"meadow": "CCOR", "wood": "CRC^", "ruins": "R^R", "shaft": "^C", "fortress": "O^CO", "hill": "R^O"}
WALKERS = {"meadow": "mn", "wood": "nm", "ruins": "M", "shaft": "n", "fortress": "Mn", "hill": "Mm"}
FLYERS = {"meadow": "", "wood": "b", "ruins": "b", "shaft": "b", "fortress": "d", "hill": "bd"}
PITS = {"meadow": 0, "wood": 0, "ruins": 2, "shaft": 1, "fortress": 1, "hill": 1}
OPPOSITE = {"left": "right", "right": "left", "up": "down", "down": "up"}


def build(r, world):
    rid, area = r["id"], r["area"]
    rnd = random.Random(rid)
    has = r.get("has", [])
    boss = "boss" in has
    width = 34 if rid == "m1" or boss else rnd.randint(32, 44)
    g = [[" "] * width for _ in range(ROWS)]
    for row in (10, 11):
        g[row] = ["#"] * width
    keep = set(range(0, 6)) | set(range(width - 6, width))  # columns kept clear (ways in and out, doorways...)

    def clear(c, around):
        keep.update(range(c - around, c + around + 1))

    # who is next door, and in which direction
    exits = []
    sides = {}
    for e in world["edges"]:
        if rid not in (e["from"], e["to"]):
            continue
        other = e["to"] if e["from"] == rid else e["from"]
        o = next(x for x in world["rooms"] if x["id"] == other)
        dx, dy = o["x"] - r["x"], o["y"] - r["y"]
        assert abs(dx) + abs(dy) == 1, f"{rid} and {other} aren't side by side on the map"
        side = {(-1, 0): "left", (1, 0): "right", (0, -1): "up", (0, 1): "down"}[(dx, dy)]
        sides[side] = (other, e["gate"])

    benches = [8] if rid == "m1" else []
    shrine = None
    if "bench" in has and not benches:
        benches = [rnd.randint(9, 13)]
    for b in benches:
        clear(b, 3)
    for h in has:
        if h.startswith("ability:"):
            shrine = {"col": width // 2, "ability": h.split(":")[1]}
            clear(shrine["col"], 4)
    # the upper floor: needed for an "up" doorway or a candle, and in about half the other rooms
    platform = None
    if not boss and ("up" in sides or "candle" in has or rnd.random() < 0.5):
        length = rnd.randint(10, 13)
        spots = [a for a in range(9, width - 8 - length) if all(c not in keep for c in range(a - 2, a + 3))]
        if not spots: # (a narrow room with a bench or shrine: a shorter floor)
            length = 8
            spots = [a for a in range(7, width - 7 - length) if all(c not in keep for c in range(a - 1, a + 2))]
        a = rnd.choice(spots)
        platform = (a, a + length - 1)
        for c in range(a, a + length):
            g[TOP][c] = "="
        for row in range(TOP, 10):
            g[row][a] = "L"
        clear(a, 2)
    for side, (other, gate) in sides.items():
        ex = {"side": side, "to": other, "arrive": OPPOSITE[side], "gate": gate}
        if side == "up":
            ex["col"], ex["row"] = platform[1] - 1, TOP
        elif side == "down":
            ex["col"], ex["row"] = (3 if boss else None), 10
        exits.append(ex)
    if platform:
        keep.update(range(platform[0] - 1, platform[0] + 2))
    # the "down" doorway: on the ground, somewhere clear
    for ex in exits:
        if ex["side"] == "down" and ex["col"] is None:
            spots = [c for c in range(8, width - 8) if all(cc not in keep for cc in range(c - 2, c + 3))]
            ex["col"] = rnd.choice(spots)
        if ex["side"] in ("up", "down"):
            clear(ex["col"], 2)

    things = []
    if boss:
        arena = [5, width - 3]
    else:
        arena = None
        # obstacles to hop over, a few tiles apart
        c = rnd.randint(7, 9)
        while c < width - 7:
            if c not in keep and g[9][c] == " ":
                g[9][c] = rnd.choice(OBSTACLES[area])
                keep.update((c - 1, c + 1))  # never two side by side
            c += rnd.randint(5, 8)
        # gaps in the ground (two tiles wide, away from everything else)
        for _ in range(PITS[area]):
            spots = [c for c in range(8, width - 9)
                     if all(cc not in keep and g[9][cc] == " " for cc in range(c - 2, c + 4))
                     and not (platform and platform[0] - 2 <= c <= platform[1] + 1)]
            if spots:
                p = rnd.choice(spots)
                for cc in (p, p + 1):
                    g[10][cc] = g[11][cc] = " "
                keep.update(range(p - 2, p + 4))
        # animals on the ground, and some in the air
        free = lambda cc: cc not in keep and g[9][cc] == " " and g[10][cc] == "#" and g[9][cc - 1] == " " and g[9][cc + 1] == " "
        for _ in range(rnd.randint(2, 3)):
            spots = [cc for cc in range(9, width - 7) if free(cc)]
            if spots:
                cc = rnd.choice(spots)
                g[9][cc] = rnd.choice(WALKERS[area])
                keep.update(range(cc - 2, cc + 3))
        for _ in range(rnd.randint(0, 2) if FLYERS[area] else 0):
            cc = rnd.randint(10, width - 10)
            if g[7][cc] == " " and g[6][cc] == " ":
                g[7][cc] = rnd.choice(FLYERS[area])
        # gems: little rows above clear ground
        for _ in range(rnd.randint(2, 3)):
            c0 = rnd.randint(6, width - 10)
            for cc in range(c0, c0 + rnd.randint(3, 5)):
                if g[8][cc] == " " and g[9][cc] in " ^CRO" and g[10][cc] == "#":
                    g[8][cc] = "o"
        # on the upper floor: gems, and the candle (or a big crystal) at its far end
        if platform:
            for cc in range(platform[0] + 2, platform[1] - 2):
                g[TOP - 1][cc] = "o"
            if "candle" in has:
                g[TOP - 1][platform[1] - 3] = "c"
            elif rnd.random() < 0.5:
                g[TOP - 1][platform[1] - 3] = "X"
    room = {"id": rid, "name": r["name"], "area_name": world["areas"][area]["name"], "area": area, "room": True,
            "hop": True, "width": width, "start": 3, "mood": MOOD[area], "exits": exits, "benches": benches,
            "powers": [], "grid": ["".join(row) for row in g]}
    if shrine:
        room["shrine"] = shrine
    if arena:
        room["boss"] = arena
    return room


def check(room):
    """Nothing stands in a doorway, at a ladder's foot or top, or in the first and last columns."""
    g = room["grid"]
    for ex in room["exits"]:
        if "col" in ex:
            c, row = ex["col"], ex["row"]
            assert g[row][c] in "#=", f'{room["id"]}: the {ex["side"]} doorway has no floor'
            assert all(g[rr][c] in " o" for rr in range(row - 2, row)), f'{room["id"]}: the {ex["side"]} doorway is blocked'
    for c in range(room["width"]):
        if g[TOP][c] == "L":
            assert g[10][c] == "#" and g[9][c] == "L", f'{room["id"]}: ladder {c} has no foot'
    for c in list(range(0, 4)) + list(range(room["width"] - 4, room["width"])):
        assert g[9][c] == " " and g[10][c] == "#", f'{room["id"]}: the way in at column {c} is blocked'


world = json.load(open("godot/data/world.json"))
ROOMS = [build(r, world) for r in world["rooms"]]
for room in ROOMS:
    check(room)
json.dump({r["id"]: r for r in ROOMS}, open("godot/data/rooms.json", "w"), indent=1)
print(len(ROOMS), "rooms written to godot/data/rooms.json")
for r in ROOMS:
    ways = ", ".join(e["side"] + "->" + e["to"] + (f' ({e["gate"]})' if e["gate"] else "") for e in r["exits"])
    extra = (" bench" if r["benches"] else "") + (f' shrine:{r["shrine"]["ability"]}' if "shrine" in r else "") + (" BOSS" if "boss" in r else "")
    print(f'  {r["id"]:3} {r["name"]:20} {r["area_name"]:16} {r["width"]} cols  {ways}{extra}')
