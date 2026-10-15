# Gracy the Adventurer — briefing for AI coding agents

Read this whole file before changing anything. Last updated 15 Oct 2026.

## What this is

A birthday-gift Android platformer for twin sisters **Janani** and **Janika**, due **21 Nov 2026**.
"Gracy the Adventurer" is only the title; the hero is **Janani**. The full design (characters, levels,
power-ups, story) is in `game-plan.md`; read it.

- **Janani** (the hero, the only playable character in World 1)
- **Janika** (her twin; captured by the boss in World 1, rescued at the end)
- **Kitty** (a cat who follows Janani, gives hints, and becomes "Super Kitty" in the boss fight)
- **Yuva** (the playful boss, with devil horns; needs 3 stomps)

There are **two versions** of the game. Don't mix them up:

| Folder | Engine | Status |
|---|---|---|
| `game/` | Phaser 4 + Vite + Capacitor (JavaScript) | **The birthday backup. Finished and installed on the twins' phones.** Leave it alone unless asked. |
| `godot/` | **Godot 4.7.2**, GDScript, GL Compatibility renderer | **The active work.** A rebuild meant to look and feel like a real game. |

## Where things are

```
gracy the adventurer/
├── AGENTS.md                 this file
├── game-plan.md              the full game design (story, levels, items, enemies)
├── godot/                    ACTIVE: the Godot project (open this folder in Godot)
│   ├── project.godot         1280x720, landscape, autoload "Game" = scripts/game.gd
│   ├── export_presets.cfg    Android preset -> ../Gracy-Godot.apk (package com.jananijanika.gracy.godot)
│   ├── scenes/main.tscn      the only scene; scripts build everything in code
│   ├── scripts/
│   │   ├── game.gd           autoload: loads data/*.json, texture()/frame() helpers, controls, lives/hearts
│   │   ├── main.gd           opens a level; test args: level=N col=X power=fire autorun; keys 1-5 switch level
│   │   ├── level.gd          (1000 lines) builds a level from data: terrain, skins, decorations, HUD, magic, deaths
│   │   ├── player.gd         Janani: run/jump physics, ropes, power-ups, magic charges
│   │   ├── kitty.gd          follower + Super Kitty
│   │   ├── enemy.gd          mushroom, hopper, snail, bee, diver
│   │   ├── blocks.gd         gift / brick / hidden / crumble / boulder / barrel obstacle blocks
│   │   ├── ladders.gd        ladder climbing between floors with top one-way collision shelf
│   │   ├── boss.gd, boss_fight.gd, bomb.gd   Yuva's fight at the end of 1-5
│   │   ├── ropes.gd, movers.gd, doors.gd, secrets.gd, powerup.gd, shot.gd (fireball/arrow)
│   │   ├── touch_pad.gd      on-screen phone buttons (left, right, up, down, jump, shoot)
│   │   └── iris.gd/.gdshader, kitty_super.gdshader, shadow.gd, aura.gd, bubble.gd, shield_bubble.gd
│   ├── data/                 GENERATED, don't hand-edit (except powers.json, beta_level.json):
│   │   ├── levels.json       every level as a tile grid   <- tools/export_godot_data.mjs
│   │   ├── beta_level.json   spacious 120-col 3-floor Sky Ruins beta test map
│   │   ├── manifest.json     sprite-strip frame sizes     <- tools/prepare_sprites.py
│   │   ├── skins.json        per-level art-pack looks     <- tools/prepare_skins.py
│   │   ├── pack_frames.json  effect strips (fire etc.)    <- tools/prepare_effects.py
│   │   └── powers.json       which gift boxes give the arrow power (hand-edited)
│   ├── assets/               game pictures; assets/pack/ (from art packs) overrides same-named files in assets/
│   │   ├── skins/<meadow|sky|desert|graveyard>/   tiles 1-16, backgrounds, decorations
│   │   └── rig/              parked (see "Parked" below)
│   └── tests/
│       ├── beta_test.gd      verifies beta obstacles, jump hop height, floor heights, and ladder climbing
│       ├── world_map_test.gd verifies map nodes, wardrobe, cottage, chapel, story, results card
│       └── feature_test.gd   23 headless gameplay checks (all passing)
├── game/                     Phaser backup. src/levels.js is the SOURCE of all level layouts
├── tools/                    build scripts (run from the project root)
├── art/                      original art (Gemini-made characters, Canva backgrounds)
│   ├── packs/                CraftPix art packs, unpacked and sorted; see art/packs/README.md
│   │   ├── platformer/ backgrounds/ effects/ enemies/ gui/ top_down/
│   │   └── _zips/            the original zips (keep them)
│   ├── anim/, 3d/, unused/
└── .venv/                    Python env with Pillow + numpy (use .venv/bin/python)
```

Level **layouts** live in `game/src/levels.js` (shared with the Phaser game). To change a level, edit that file,
then run `node tools/export_godot_data.mjs` and `node tools/check_levels.mjs`.

## Commands (run from the project root unless noted)

Godot is NOT on the PATH. It is at `~/Downloads/Godot.app/Contents/MacOS/Godot`.

```bash
# all automated tests (must all pass)
cd godot && ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/beta_test.gd
cd godot && ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/world_map_test.gd
cd godot && ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/feature_test.gd

# run the new Beta test level (obstacles, ladders, multi-floor Sky Ruins)
cd godot && ~/Downloads/Godot.app/Contents/MacOS/Godot --path . -- level=beta

# run the game in a window, starting at level 3, column 40, with fire magic
cd godot && ~/Downloads/Godot.app/Contents/MacOS/Godot --path . -- level=3 col=40 power=fire

# record frames to look at (movie writer); add "autorun" so she runs and jumps by herself
cd godot && ~/Downloads/Godot.app/Contents/MacOS/Godot --path . --write-movie /tmp/shot.png --quit-after 300 -- level=1 autorun

# build the Android APK -> Gracy-Godot.apk in the project root (~65 MB)
cd godot && ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug "Android" ../Gracy-Godot.apk

# after editing levels in game/src/levels.js
node tools/export_godot_data.mjs && node tools/check_levels.mjs

# after changing art-pack choices
.venv/bin/python tools/prepare_skins.py
.venv/bin/python tools/prepare_effects.py
```

Android export needs: export templates 4.7.2 (installed), Java `/opt/homebrew/opt/openjdk@21`, Android SDK
`~/Library/Android/sdk`. These are set in Godot's editor settings. If the export fails with a Java error, the
Java path was probably cleared when the editor saved; set it again in Editor Settings → Export → Android.

## How the Godot code is built (follow these patterns)

- Everything is made in code from data; there is one scene. Levels are tile grids (64 px tiles, 12 rows).
- Each level part is its own script added by `level._part(name)`, and gets a `level` reference.
- Collision layers: 1 = ground, 2 = Janani, 4 = enemies/boss.
- Each level's look ("skin") comes from its mood: `SKIN_FOR_MOOD` in level.gd
  (1-1/1-2 meadow, 1-3 sky ruins, 1-4 desert, 1-5 graveyard).
- Pictures: `Game.texture("name")` loads `assets/pack/name.png` if it exists, else `assets/name.png`.
- Magic: defeating an animal gives one charge (max 3); the shoot button throws a fireball (or fire arrow after
  an arrow gift box). Logic in level.gd (`_charge`, shooting) + shot.gd.
- **The look is "magical & cinematic"** (the user's choice, 13 Oct: like Ori / Hollow Knight; the twins are
  turning 25, so nothing toy-like). Every screen uses `scripts/ui.gd` (`const UI := preload(...)`): dark glass
  panels with thin gold lines, Cinzel titles + Nunito text (`fonts/`, OFL), line-drawn icons, glows, fireflies,
  fog, god rays (`shaders/god_rays.gdshader`), vignette, layered forest backdrops (`assets/backdrops/`,
  made by `tools/prepare_gui.py`). Pop-ups (Settings, Pause): `scripts/popup.gd`. Each level's colour grade,
  rays, motes and Janani's light: `scripts/cinema.gd` (MOODS table). Never bring back bouncy/toy UI.
- Add-ons in `godot/addons/` (autoloads in project.godot): **Juice** (saltmire-juice, MIT: `Juice.shake`,
  `Juice.hitstop`, `Juice.flash`), **PhantomCameraManager** (Phantom Camera, MIT: installed, not used yet),
  **DialogueManager** (Nathan Hoad, MIT: installed, not used yet). `assets/fx/`: Kenney particle textures (CC0).
- Screens: main.gd swaps them through `_show(node)` with a fade to night blue. (The Universal Transition
  Shader's corner wipe was tried and removed: on phones it left 3/4 of the screen covered.)
  Test args: `screen=title|map|cottage|chapel|story|ending|results`, `goto=map` (title, then the map through
  the fade), `level=N col=X power=fire autorun pause`. The movie writer crops windows wider than 1280.
- Code style: short `##` doc comments in plain English, tabs, typed GDScript. Match the files around you.
- After every change: run the tests (`tests/feature_test.gd` and `tests/world_map_test.gd`). When adding a
  feature, add a check. Note: world_map_test writes the desktop save (sets the outfit to "jacket").

## Rules

1. **Don't touch `game/` (the Phaser birthday app) or `tools/release.mjs`** unless the user asks. `release.mjs`
   pushes live updates to the twins' phones.
2. **Never commit or print secrets.** `game/src/config.js` has Supabase keys; `export_presets.cfg` may have keystore settings.
3. **Art packs are CraftPix free license:** fine to use inside the game, never share the raw files on their own.
4. **CraftPix downloads need the user's login.** You can't sign in. Give the user direct links; they download to
   `~/Downloads` and tell you. Copy each zip into `art/packs/_zips/` at once, then unpack into the right folder
   and update `art/packs/README.md`.
5. **Files the user sends through WhatsApp** (paths under `~/Library/Containers/net.whatsapp.WhatsApp/...tmp`)
   disappear within minutes. Copy them into the project immediately, before doing anything else.
6. Art style: painterly, magical, grown-up (see above). Don't mix in pixel-art packs; avoid toy-like art.
7. The user is not a programmer. Explain in simple words, and show screenshots or recordings of changes
   (best ones go in `art/previews/`).
8. The user has the ECC plugin, whose **GateGuard** hook blocks the first edit of each file and any delete
   until you state: who uses the file, what changes, data written, and the user's words. Do a grep first.

## Done so far in Godot (as of 15 Oct)

- **Obstacle-Hop & Multi-Floor Ladder System (15 Oct):**
  - **Calibrated Obstacle Hop:** Janani's jump speed tuned to 540.0 px/s with immediate variable jump cut on release (tap = ~45 px low hop, hold = ~81-87 px full hop). Clears 1-tile 64 px obstacles cleanly.
  - **Floors Require Ladders:** Floor heights set to 4–5 tiles (256–320 px headroom). Janani cannot jump between floors and must climb ladders.
  - **Ladders with One-Way Top Shelves (`scripts/ladders.gd`):** Top rungs have one-way collision shelves so Janani steps firmly onto the upper floor and can walk left/right onto platforms. Pressing Down steps down past the shelf into climbing mode.
  - **Solid Resisting Obstacles:** Real `StaticBody2D` colliders for Crates (`C`), Boulders (`R`), Barrels (`O`), and Spikes (`^`). Ghost non-colliding ground decorations are suppressed on the walking path in Beta.
  - **Bug Fixes:** Removed `KEY_S` shortcut hijacking in `main.gd` (previously pressing `S` for ladder/crouch opened the Candle Shrine).
  - **Spacious Beta Map (`data/beta_level.json`):** 120-column multi-floor Sky Ruins map with 3 floors (Ground Row 10, Terrace Row 5, Celestial Sanctuary Row 1), 3 Giant Crystals, Arrow magic box, and Victory Portal.
  - **Automated Verification:** `tests/beta_test.gd` verifies jump heights, obstacle collisions, and ladder climbing.

- **Cinematic restyle of every screen (14 Oct):** title (night forest, god rays, fireflies, Hollow-Knight-style
  menu), world map (dusk), level HUD (glass) + **pause menu** (resume, restart, map, music/sound), level name
  card, results card (crystals, gems, candle, score, new outfit), wardrobe (6 outfits, one unlocked per cleared
  level, `Game.OUTFITS`), candle shrine (drawn candles, real flames), story scenes (glass dialogue, typewriter
  text, rewritten in a warmer, grown-up voice). Screen-to-screen wipes. Screen shake, hit-stop and hurt flash.
- Levels: per-mood light (1-1 golden hour, 1-2 cool, 1-3 bright, 1-4 sunset, 1-5 moonlight), glowing gems,
  crystals and candles, a light around Janani; 1-1/1-2 have a painted 3-layer forest background; gift boxes
  are midnight teal with a gold ribbon.
- Fixed: candles and crystals are now saved; finishing a level no longer marks the next one cleared; a new game
  no longer starts with 1-1 marked cleared.
- Title screen, world map, story scenes, results card, wardrobe, shrine and synthesized audio were first
  added by Antigravity (12 Oct), then restyled.

- All 5 World 1 levels playable, with the Phaser layouts: gift boxes, power-ups (cupcake shield, star, heart,
  balloon double-jump/glide, gem magnet), secret blocks and rooms, crumbling blocks, ropes, moving platforms,
  Heaven/Hell doors, checkpoints, Kitty, and the boss fight with Super Kitty.
- World 1 restyled with CraftPix packs: tiles, backgrounds, decorations, crates, gems, hearts, star, spikes, boulder.
- Fire magic (fireball and fire arrow), charged by defeating animals; on-screen shoot button.
- Phone touch controls; APK builds and installs as a separate app "Gracy (Godot)".

## What's next (in rough priority order)

1. **Music:** the current tracks (`assets/audio/`, synthesized chiptune) feel childish. Replace with calm
   orchestral/ambient loops: suggested free packs (the user downloads them): HZSMITH "Epic Fantasy Forest"
   (CC BY-SA, credit needed), forestfullofmagic "Magical Fantasy Forest". Sound effects: Sonniss GDC bundle.
2. **Still toy-like in the levels:** the cartoon enemies (smiling mushrooms, bees, snails), the cupcake power-up,
   the bright lime grass tiles, 1-3/1-4 backgrounds. Consider the predator-plant / monster packs.
3. **Characters:** Janani, Janika, Kitty and Yuva are small chibi Gemini sprites. Best fix: one painted
   (non-chibi) image of Janani, rigged with Skeleton2D bones for smooth animation (also fixes "the rope swing
   isn't smooth"). Ask the user before starting (see Parked).
4. **Use Phantom Camera** for the boss reveal and story camera moves; **use Dialogue Manager** for the story
   lines (they're hard-coded in story.gd now).
5. **Check the magic on screen** (`-- level=2 power=fire autorun`): earlier the fire button/fireballs didn't show.
6. **New story for World 2** (the user's request): after Janika is saved at the end of World 1, Yuva kidnaps
   **Kitty**. In World 2, Janani and Janika play together on **two phones** to rescue Kitty. The Phaser game
   has two-phone co-op through Supabase (`game/src/coop.js`, `net.js`, `scenes/Lobby.js`); the World 2 level
   layouts are `COOP_LEVELS` in levels.js and already exported as `levels.json` → `together`.

## Parked (don't start unless asked)

- A new Janani character (3D/rig): `art/3d/`, `tools/prepare_rig.py`, `godot/assets/rig/`. The user chose to keep
  the current cartoon Janani for now.

## SpriteForge (custom sprite generation)

A local CLI pipeline in `tools/spriteforge/` that converts character portraits into clean, game-ready animation
spritesheets on green screen, with soft-edge chroma keying, green despill, cycle loop detection, and direct Godot export.

### Commands
```bash
# 1. Anchor: creates side-view character on pure green screen
.venv/bin/python -m tools.spriteforge anchor --name janani --ref art/previews/janani_reference.png --describe "Indian girl hero wearing white kurti"

# 2. Animate: generates or imports action video, keys chroma, finds loop, packs strip & GIF
.venv/bin/python -m tools.spriteforge animate --name janani --action run

# 3. Variant: edits an existing anchor (e.g. outfit swap) keeping facial features
.venv/bin/python -m tools.spriteforge variant --name janani --outfit black --edit "replace the white kurti with a black dress"

# 4. Repick: re-cuts frames from existing raw frames without calling AI (100% Free)
.venv/bin/python -m tools.spriteforge repick --name janani --action run --frames 0-5 --fps 12

# 5. Export: copies strips into godot/assets/hero2/ and updates godot/data/hero2.json
.venv/bin/python -m tools.spriteforge export --name janani --outfit kurti
```

### Files & Cache
- `tools/spriteforge/`: `cli.py`, `provider.py`, `chroma.py`, `crop.py`, `cycle.py`, `pack.py`, `export.py`, `config.py`
- `spriteforge-runs/<character>/<action>/`: cache holding `anchor.png`, `frames_keyed/`, `strip.png`, `preview.gif`, `manifest.json`
- `spriteforge-runs/costs.csv`: running cost log
- `godot/assets/hero2/<outfit>_<action>.png`: exported strips (square 210x210 cells)
- `godot/data/hero2.json` / `godot/data/hd.json`: action keys, cell dimensions, frame counts, and fps

### Costs So Far
- Janani Anchor + Run Cycle: **$0.00** (Totally free)

