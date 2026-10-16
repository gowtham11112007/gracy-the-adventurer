# Gracy: the new game design (decided 16 Oct 2026)

The owner wants to change the whole game from a Mario-style platformer into an **atmospheric action-adventure
with sword combat and a connected world (a "metroidvania")**, inspired by Hollow Knight, Hollow Knight: Silksong
and Divinum. It is a birthday gift for the twins Janani and Janika, due **21 Nov 2026**. Janani is the only
hero, and she carries a sword.

## Rules for this direction
- **Inspired by, never copied.** We study how those games feel and are built, then make our own world, art, music,
  story and level layouts. No code, art, audio or room layouts from them go into this project. The repo is private
  and must stay free of their files.
- The Phaser game in `game/` stays untouched as the **safe birthday gift** on the twins' phones. The Godot game
  is the new, ambitious one: if it isn't ready by 21 Nov, the Phaser one is still the gift.
- Janani is only the **Spriterrific "Beta" version** (see `godot/data/hd.json`, `tools/prepare_hero2.py`), now with
  a sword. Grown-up look, magical and cinematic (see AGENTS.md).

## The idea in one paragraph
Janani wakes in a glowing, lantern-lit forest after Yuva has taken her twin Janika and then Kitty. Sword in hand,
she explores a connected world of rooms, learns new moves (dash, double jump, wall jump), fights creatures and
bosses, rests at benches to save, and follows Kitty's trail to Yuva's castle. Birthday candles are hidden
across the world; lighting all five opens the true ending: a birthday party for both sisters.

## What we take from each inspiration (ideas only)
| From | The idea | Our version |
|---|---|---|
| Hollow Knight | A connected world of rooms; sword hits with a brief freeze, knockback and recoil; benches that save and heal; atmosphere through light and layered backgrounds | Same structure and feel; our forest, our creatures, our story |
| Silksong | Fast, fluid movement: wall slide, wall jump, dash, double jump | Janani's moves unlock one by one |
| Divinum | Parry, dash and knockback; artifacts that change how you fight; clear save slots, checkpoints, an area-name card | A small set of "birthday charms" Janani can equip; parry; the save slots we already built |

## Systems to build (in this order)
1. **Combat:** sword slash (forward, up, down), hit-freeze, knockback, enemy health, Janani's health ("hearts"),
   invincibility flash, death and respawn at the last bench. Camera shake and hit sparks (Juice is installed).
2. **Moves:** dash, double jump, wall slide and wall jump, each a flag the world can unlock (`can_dash` ...).
3. **Rooms:** hand-made rooms (tile grids like today's, from the level editor `tools/level_editor.html`) joined by
   doors, with a room-to-room camera, a map screen and area-name cards.
4. **Enemies:** 4 or 5 kinds with simple, readable patterns (walker, flyer, charger, shooter, shield-bearer).
5. **Benches and saves:** bench = heal + save (slot system exists), fast travel is optional later.
6. **Charms:** 3 to 5 equippable birthday charms (parry window, longer dash, more hearts, ...).
7. **Boss:** Yuva, in an arena, with phases and a parry moment.
8. **Story:** the existing intro and Kitty story, dialogue via Dialogue Manager (installed).

## What stays from today's game
Menus, save slots, settings, the cinematic look (`ui.gd`, `cinema.gd`), Kitty (follower, four coats), candles and
crystals as collectibles, the wardrobe idea (later: outfits), phone touch controls, the APK build.

## What goes
The Mario-style World 1 levels become **the first area of the new world**: the meadow and forest rooms are rebuilt
as connected rooms, not a left-to-right level with a finish gate; time limits, lives and the "course clear"
results card are retired.

## Art needed (the biggest blocker)
- **Janani with a sword:** idle, run, jump/fall, hurt, death, slash (3 variants), dash. From Spriterrific
  (account credits are low: 40). See the prompt file when written.
- Enemies and Yuva boss: from art packs first (`art/packs/enemies`), our own later.
- Sword slash effect and hit sparks: from the effects packs (`art/packs/effects`).

## The world map (built 16 Oct)
33 rooms in 6 areas spread in all four directions from the hub (Lantern Crossroads): Sunny Meadow (west), Sky Ruins
(north), Sunken Fortress (south), Yuva's Hill (east), and the Long Shaft (x=7) joining north, hub and south. 4 loops
and shortcuts, 6 benches, 5 candles, 3 moves (dash at the Dash Shrine, double jump at the Cloud Terrace, wall jump at
the Climbing Wall) and 7 doors that need a move or 3 lit candles (the gate to Yuva).
- Data: `godot/data/world.json`, made by `tools/design_world_map.py`, which also proves every room is reachable
  and draws `art/previews/10_world_map_plan.png`. Rules and solver: `godot/scripts/world.gd`.
- The map screen: `godot/scripts/map_screen.gd` (test: `-- screen=worldmap` or `screen=worldmap all`). Rooms fill in
  as she explores (`Game.discover_room`), moves are `Game.unlock_ability` / `Game.has_ability`; both are saved per slot.
- Tests: `godot/tests/world_test.gd` (14 checks).
- **Playable rooms (built 16 Oct):** 5 side-view rooms in a row: Birthday Glade (m1), Windmill Road (m2, ladder
  to a second floor), Old Fence (m3), Wood Gate (w1), Lantern Crossroads (w2, its east door is closed for now).
  Data: `godot/data/rooms.json`, made by `tools/build_rooms.py`. They use the Beta rules (`level.hop_physics()`):
  low hop over 1-tile obstacles (crate, boulder, barrel, spikes), upper floors only by ladder.
  Walking off a room's left or right edge fades into the next room (`Level.exited` -> `Main.open_room`), a closed
  door ("to": "") is a wall, benches (lantern posts; `def.benches` columns) heal and save (`Game.save.bench`),
  every room walked into is remembered for the map (`Game.discover_room`). New Game -> story -> Birthday Glade;
  Continue -> her last bench; pause menu has Map. Test flags: `-- room=m2 entry=left autorun`.
- **The whole world is built (16 Oct, evening):** all 33 rooms in 5 areas (+ the Long Shaft), generated by
  `tools/build_rooms.py` from `world.json` (layouts random but fixed per room id, self-checked). Each area has its
  own art pack (meadow / meadow-windy / sky / desert / graveyard), obstacles and animals; Sky Ruins and the
  fortress have gaps. Rooms above/below are joined by glowing doorways (`portal` art; stand in it, press Up); an
  "up" doorway is on the upper floor, so she climbs. Doors that need a move or 3 candles say so. Shrines (w6, s3,
  f3) grant dash / double jump / wall jump; double jump really works (one air jump), dash and wall jump only open
  their doors so far. Yuva's Arena (y4) is the boss fight; beating him plays the `world1end` story.
- **Sword (AutoSprite):** `art/autosprite/` holds the "25" Janani's slash (22 frames) and ladder climb (25 frames,
  its drawn ladder rubbed out) with their atlases; `tools/prepare_autosprite.py` -> `assets/hd/janani25_*.png`,
  added to Beta 4-7 in `hd.json`. Z / K or the touch sword button: `player.slash()`, `level._sword_swing()` knocks
  out animals within 200 px in front and hits Yuva (`boss_fight.sword_hit()`). New games wear Beta 7.
- Tests: `tests/playthrough_test.gd` runs a robot Janani across all 42 room crossings and checks every arrival
  spot. Recording tip: add `--always-on-top`, or macOS stops redrawing the window and the frames freeze.
- NOT built yet: dash and wall jump as moves; enemies that fight back; the old Mario-style levels are still in the
  code (keys 1-5, `open_level`) but not reachable from the menus.

## Plan to 21 Nov
| By | Milestone |
|---|---|
| 23 Oct | Combat prototype in one room (placeholder slash from the existing attack strip) |
| 30 Oct | Moves unlocked, 6 connected rooms, bench + save, map |
| 8 Nov | Enemies, charms, Yuva boss, story scenes |
| 15 Nov | Polish, sound, phone controls tuned, APK tested on a phone |
| 21 Nov | The gift (the Phaser game remains the fallback) |

## Open decisions (ask the owner)
- Game title (still "Gracy the Adventurer"?).
- Keep the five World 1 candles/crystals as the collection goal, or redesign?
- Music: the owner downloads calm orchestral loops (see AGENTS.md).
