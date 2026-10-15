# Prompt for Antigravity: build "SpriteForge", our own Spriterrific-style sprite generator

Copy everything below the line into Antigravity, with this project folder open.

---

You are building **SpriteForge**: a small command-line tool inside this project that turns a picture of a game
character into smooth, game-ready animation spritesheets, the way the paid service Spriterrific does, so we
pay the AI providers directly instead of buying credits. It is for my Godot game "Gracy the Adventurer".

## Read first
1. `AGENTS.md` (project rules, folders, how the Godot game is built, the art style). Follow its rules.
2. `.claude/skills/spriterrific-api/SKILL.md`: how Spriterrific works. Copy its *ideas* (pipeline, green-screen
   background, dense frames at 24 fps, finding a clean loop, character variants), not its API calls.
3. `godot/data/manifest.json`, `godot/scripts/player.gd`, `godot/scripts/game.gd` (`frame()`,
   `sprite_frames()`): how the game reads sprite strips today.

## What it must do (the pipeline)
Input: one reference picture of a character (e.g. `art/previews/janani_reference.png`) + a short description.

1. **Anchor image.** Ask an AI image model to redraw the character as ONE full-body figure, side view facing
   right, standing, centred, feet near the bottom, on a flat pure green background (#00FF00). Keep the face,
   hair, skin tone and clothes from the reference. Style: detailed, painterly, grown-up (not chibi, not
   pixel art). Save it and show it to me before going on.
2. **Animation video.** Send the anchor to an AI image-to-video model with a prompt per action, e.g.
   "run": "side view, she runs to the right on the spot, steady camera, flat green background, full body
   always in frame, no camera motion, no zoom". Actions: idle, walk, run, jump, hurt, victory, rope-swing.
3. **Frames.** Extract every frame with ffmpeg (24 fps).
4. **Remove the green** (chroma key) with soft edges and no green fringe (despill), then crop every frame
   with the SAME box so the character doesn't jitter. Keep the feet on the bottom edge, horizontally centred.
5. **Find one clean loop** for walk/run/idle: compare frames (small greyscale thumbnails, mean pixel difference),
   find the first step, then the full two-step cycle (see "Smooth Animation" in the Spriterrific skill, with
   the `find_cycle` example). One-shots (jump, hurt, victory): keep start to settled end, drop smeared or
   duplicate frames.
6. **Pack** the frames into a single-row PNG strip (one frame after another, left to right), and write a
   preview GIF and a `manifest.json` (frame width, height, count, fps, which frames make the loop).
7. **Variants:** the same character in a new outfit, by EDITING the anchor ("replace the white kurti with a
   black dress"), never by generating from scratch (that changes her face).

## Tech choices
- Python, in `tools/spriteforge/` (a package with a `cli.py`). Use the existing `.venv`
  (Pillow and numpy are installed). Add what you need to `tools/spriteforge/requirements.txt`.
- ffmpeg is NOT installed. Prefer `pip install imageio-ffmpeg` (ships its own ffmpeg) so nothing system-wide
  changes; or ask me before running `brew install ffmpeg`.
- AI models: use the **Google Gemini API** (one key covers both): the Gemini image model for steps 1 and 7,
  and **Veo** for step 2. Look up the CURRENT model names and prices in Google's docs, don't guess them.
  Make the provider swappable (a small interface) so fal.ai or others can be added later.
- Key: read `GEMINI_API_KEY` from the project's `.env` (it already holds other keys: don't print, log or
  commit any of them). If the key is missing, stop and ask me for it.
- Upload pictures to the AI provider's own API only. NEVER put my sisters' pictures on a public file host.

## Money rules (important)
- Before any paid call, print what it will do and the estimated cost, and ask me "Spend about $X? (yes/no)".
- `--dry-run` shows the plan and the cost without calling anything.
- Cache everything in `spriteforge-runs/<character>/<action>/` (anchor, raw video, frames, strip). Re-runs
  reuse the cache; re-picking frames or re-cutting a loop must never call the AI again.
- Keep a running cost log in `spriteforge-runs/costs.csv`.

## Commands I want
```
.venv/bin/python -m tools.spriteforge anchor  --name janani --ref art/previews/janani_reference.png --describe "..."
.venv/bin/python -m tools.spriteforge animate --name janani --action run
.venv/bin/python -m tools.spriteforge variant --name janani --outfit black --edit "replace the white kurti with a black dress"
.venv/bin/python -m tools.spriteforge repick  --name janani --action run --frames 4-27 --fps 24   (free)
.venv/bin/python -m tools.spriteforge export  --name janani --outfit kurti   (into the Godot game)
```

## Getting it into the Godot game (`export`)
- Today the hero uses strips `godot/assets/hero_<outfit>.png` (16 frames: idle 0-2, run 3-6, walk 7-10,
  rise/peak/fall 11-13, hurt 14, victory 15), `hero_<outfit>_moves.png` (run 0-5, jump 7-11) and
  `hero_<outfit>_rope.png`, all 104x150 cells with feet on the bottom edge, listed in
  `godot/data/manifest.json`. `player.gd` builds the animations from those frame numbers.
- New sprites are bigger and have more frames. Export them as NEW files (e.g. `hero2_<outfit>_<action>.png`
  + entries in a NEW `godot/data/hero2.json` with frame size, count, fps and a display scale), and teach
  `player.gd` (and the menu screens using `UI.actor` in `scripts/ui.gd`) to use them when they exist, and fall
  back to the old strips when they don't. Her on-screen height must stay about the same (~150-170 px), and the
  collision box must not change.
- Play loops at the manifest's fps; tie the run's playback speed to her running speed so feet don't slide.

## How to work
1. First show me a plan and the cost of a first test: anchor + RUN only for Janani. Wait for my yes.
2. Build step by step; after each step show me the result (the anchor, a few frames, the preview GIF).
3. Then export into the game, record a short clip of her running in level 1-1 with
   `cd godot && ~/Downloads/Godot.app/Contents/MacOS/Godot --path . --write-movie /tmp/run.png --fixed-fps 30 --quit-after 150 -- level=1 autorun`,
   and show me old vs new side by side.
4. Run the game tests (see AGENTS.md); they must still pass.
5. Only after I approve the look: more actions, then the other outfits, then Janika, Kitty and Yuva.
6. Explain everything in simple words: I'm not a programmer.
7. Finally add a short "SpriteForge" section to AGENTS.md (commands, files, costs so far).
