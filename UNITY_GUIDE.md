# Gracy (Unity): guide for any AI agent (Manus, Claude Code, …)

Read this before changing anything in `unity/`. The owner is not a programmer: explain simply, show screenshots.
Last updated 19 Oct 2026 (commit 44a7ebf, branch `metroidvania-world`).

## The game today
- 2D side-scrolling platformer for Android. Heroine **Janani**. **No sword** (the owner removed it; she defeats
  creatures by landing on their heads). Health **bar**, not hearts.
- Look: magical, warm evening light, **pixel-art** village/forest (Cainos, 32 px per tile). Grown-up, never childish.
  Gems are **blue pixel diamonds** (`Resources/Art/Props/gem_pixel.png`, made by `tools/make_pixel_gem.py`).
- Screens: title → World Map (World 1 is an island rendered in Blender) → level → "Level Complete" → map.
- Done: World 1 · Level 1 "Lantern Village" (72 columns, ladder to an upper floor, mushrooms and a wolf to stomp,
  a golden chest, finish at the glowing Stone of Recall). Levels 2-5 show "coming soon" on the map.
- Older Godot/Phaser plans (benches, dash, connected rooms, sword) do NOT apply to this Unity game.

## Where things are
- Unity 6.6 project: `unity/` (Unity at `/Applications/Unity/Hub/Editor/6000.6.6f1/Unity.app/Contents/MacOS/Unity`).
- One scene, `Assets/Scenes/Room.unity`. **Everything is built in code from data** (no hand-placed scene objects).
- `unity/Assets/Scripts/` (assembly `Gracy.asmdef`):
  - `Room.cs`: builds a level from its text grid (ground, ladders, obstacles, gems, chest, creatures), plus `Gem`,
    `Chest`, `Puff`, `Fireflies`, `NearSound`, `Hazard`.
  - `Village.cs`: Level 1's look (Cainos props by name, scenery letters, lamps, campfire, the Stone of Recall goal).
  - `Janani.cs`: movement, hop (full hop near obstacles/gaps even on a tap), ladders, health, sounds.
  - `Creatures.cs`: `Creature` (mushroom `m`, wolf `W`; stomp to defeat), `Sparkle`, `Fader`.
  - `MapUI.cs`: the world map (trail of dots, Janani walks between levels, unlock animation, crows, level card).
  - `MenuUI.cs`, `TitleFx.cs`: title, pause, options, level complete. `HealthBar.cs`, `TouchPad.cs`, `LevelUI.cs`.
  - `Flow.cs`: which screen, saving progress (PlayerPrefs `done_<id>`, `gems_<id>`, `map_at`, `map_shown`).
  - `Autopilot.cs`: test runs from the command line (see below).
- Pictures and sounds load from `unity/Assets/Resources/` (`Art/…`, `Audio/…`, `Data/…`, `Fonts/…`).
  To use an Asset Store picture, move it **with its .meta file** into `Resources/Art/...` (keeps its slicing).
- Levels: `tools/build_unity_levels.py` writes `unity/Assets/Resources/Data/levels.json`.
- World map: `tools/blender/world_map.py` (Blender 5.2 at `/Applications/Blender.app`) writes the island picture and
  `Resources/Data/worldmap.json` (level ids, names, positions).

## Level grids (tools/build_unity_levels.py)
12 rows; every row the same width; rows 10-11 are ground; 1 character = 1 tile (1 Unity unit). Scenery stands on row 9.
```
#  ground        =  wooden platform     L  ladder         o  gem          T  golden chest (5 gems)
C  crate  O  barrel  R  stump  ^  spikes   (solid, hop over; spikes hurt)
m  mushroom (slow)   W  wolf (fast)        (land on their heads to defeat them; touching them hurts)
w well  k scarecrow  p lamp  c campfire  s sign  h hay  u sunflowers  b bush  t tree  g grass  f fence  x wheelbarrow
E  Stone of Recall: the end of the level
```
Her full hop is about 1.8 tiles high and clears a 2-tile gap; floors 5 rows apart need a ladder.
A new level needs: its function in `build_unity_levels.py`, its id in `worldmap.json` (level2 … level5), and
a mood/look (Level 1's look is `mood: "village"`).

## Build and test (from the project root)
The owner may have Unity open on `unity/`, so build from a copy:
```bash
rsync -a --delete --exclude Temp --exclude Logs --exclude Builds --exclude UserSettings unity/ /tmp/unity_copy/
/Applications/Unity/Hub/Editor/6000.6.6f1/Unity.app/Contents/MacOS/Unity -batchmode -quit -projectPath /tmp/unity_copy -executeMethod ProjectSetup.BuildMac -logFile /tmp/mac.log
/Applications/Unity/Hub/Editor/6000.6.6f1/Unity.app/Contents/MacOS/Unity -batchmode -quit -projectPath /tmp/unity_copy -executeMethod ProjectSetup.BuildAndroid -logFile /tmp/android.log
```
- Mac build: `/tmp/unity_copy/Builds/Gracy.app`; APK: `/tmp/unity_copy/Builds/Gracy-Unity.apk` (copy it to `Gracy-Unity.apk` in the root).
- Compile errors: `grep "error CS" /tmp/mac.log`.
- Test run with a screenshot (window 1280x720):
  `Gracy.app/Contents/MacOS/Gracy -screen-fullscreen 0 -screen-width 1280 -screen-height 720 -autorun -shot /tmp/s.png -shotAt 30`
  Options: `-autorun` (runs right, hopping), `-tap` (only taps jump), `-at N` (start at column N), `-high`
  (on the upper floor), `-room level1`, `-map`, `-pause`, `-trace`. On quitting it logs
  `Autopilot: column …, gems …, hits …` in the Player.log. A full Level 1 autorun must reach column ~68.
- Clear saved progress: `defaults delete "unity.Janani & Janika.Gracy"`.

## Rules
1. **Work in a git worktree / separate branch**, never on top of someone else's unsaved changes. Commit small steps.
2. Don't touch `game/` (the twins' Phaser birthday app) or `tools/release.mjs`.
3. Never print, upload or commit secrets: `.env`, `game/src/config.js`, keystore settings.
4. Art-pack files (CraftPix, Asset Store) must never be shared or uploaded on their own; use them only inside the game.
5. Don't bring back the sword, hearts, or toy-like/bright cartoon art. Keep pixel art at the village's size.
6. After a change: build for Mac, run the autorun test, look at a screenshot, then build the APK.
