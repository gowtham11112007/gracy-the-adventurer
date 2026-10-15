# Art packs (received 2026-10-12)

17 free packs, mostly from CraftPix (license: https://craftpix.net/file-licenses/ — fine to use inside
our game, but the raw files must not be shared on their own). Unpacked and sorted by how they can be used.
The zips received after 12 Oct are kept in _zips/ (WhatsApp deletes its copies).

## platformer/ — side view, fits our game

| Pack | What's inside | Possible use |
|---|---|---|
| crystal-caves-2d-platformer-tileset | cave background, platforms, crystals, collectables | World 2 (Crystal Cave) |
| sky-ruins-2d-platformer-tileset | sky background, floating ruin platforms | 1-3 Treetop Heights / a sky world |
| freetileset | green hills background, grass tiles, objects | extra meadow scenery |
| wintertileset | snowy mountains and forest, snow tiles | a winter world (World 3) |
| deserttileset | dunes and pyramids, sand tiles | a desert world |
| graveyardtilesetnew | full moon, graves, dark tiles | a spooky night level |
| plague-town-2d-platformer-vector-tileset | dark old town, houses | a spooky town level |
| freescifiplatform | metal tiles, saws, sci-fi objects | traps (spinning saws) |
| pixel-dungeon-props-and-objects | dungeon props (chests, torches…) | decorations, treasure |
| world-tree-roots-2d-platformer-tileset | giant tree roots, forest ground, collectables | a forest world |
| green-zone-tileset-pixel-art | urban park / alley, tiles, trees, swing, benches, skateboard | park / town / bonus level |

## effects/ — magic for Janani's powers

| Pack | What's inside | Possible use |
|---|---|---|
| water-and-fire-magic | Fire Arrow, Fire Ball, Fire Spell, Water Arrow/Ball/Spell (animated frames) + icons | fire / magic-arrow power-ups |
| magic-slash-effects | wind, fire, lightning, poison, water and "ultimate" slashes + icons | hit sparks, boss attacks |
| animated-explosions | 10 cartoon explosions | **in the game**: fireball hits, Yuva's bombs |
| slash-cartoon-effects | 10 slash / dust swooshes | stomp sparks, dust |
| game-coins | spinning gold / silver / bronze coins | bonus coins |

Water-and-fire-magic is **in the game**: Fire Ball and Fire Arrow (tools/prepare_effects.py).

## backgrounds/

| Pack | What's inside | Possible use |
|---|---|---|
| fairy-tale-game-backgrounds | 4 storybook scenes in layers | story scenes, party ending |
| cartoon-parallax-backgrounds | candy-cake land, night sky castle, hills, castle | **birthday party level**, story |
| cartoon-forest-backgrounds | 4 deep forests (day, misty, sunny, night) | a forest world |
| winter-holiday-backgrounds | snowy forest, village, mountains, Christmas trees | a winter world |
| beach-backgrounds | 3 sunny beaches and a sunset | a beach world |

More tilesets in platformer/: autumn-tileset, xmas-candy-tileset (candy ground for the party level).

## gui/ — menus and buttons

kids-fantasy-gui, jungle-cartoon-ui (sliced buttons, level select, pause), gems-games-gui, buttons (shiny/simple).

## enemies/ (more)

monster-enemy-sprites: 10 cartoon monsters, each with idle/walk/run/jump/attack/hurt/die frames.

## enemies/ — creature animations

| Pack | Notes |
|---|---|
| predator-plant-mobs-pack | 3 biting plants with animations |
| slime-mobs-top-down-sprite-pack | 3 slimes (drawn top-down, may still work side-on) |

## top_down/ — seen from above, doesn't match a side-scrolling game

chapel, ruined temple, ruins, seabed objects, bridges, main character's home.
Kept for reference; only small props (plants, stones) might be reused.

## In the Godot game now (made by tools/prepare_skins.py)

- Level looks: meadow (freetileset), sky (sky-ruins), desert, graveyard — ground, background, decorations, crates.
- Shared pieces in godot/assets/pack/ replace the old pixel art everywhere: gems and big crystal, hearts and star
  (crystal-caves), spikes (freescifiplatform), cracked stone blocks, the boulder; the gift boxes, rope and balloons
  are drawn by the script in the same cartoon style.
