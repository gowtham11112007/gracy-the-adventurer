# Gracy the Adventurer — Game Plan

5 Oct 2026 · Gowtham Yuvaraj

## Overview

Gracy the Adventurer is a 2D pixel-art side-scrolling platformer, built as an Android APK birthday gift for the twins Janani and Janika on November 21. "Gracy" is only the game's title; in the game the hero is Janani. The boss has captured her twin Janika, and Janani runs, jumps, stomps enemies and collects amethyst gems across 3 worlds to rescue her, beat the boss, and unlock a birthday party ending for both of them.

### Names (decided 5 Oct)

- Game title: "Gracy the Adventurer"
- Hero (only playable character): Janani, drawn with the gracy_main sheet
- Twin: Janika, drawn with the janika_twin sheet; captured by the boss, rescued at the end
- Guide: a kitty who warns about hazards and cheers Janani on in every level
- Cake and final message: both twins' names, "Happy Birthday Janani & Janika" (drawn in code, since the cake art says "Gracy")
- Keep all names in one config constant so they are easy to change

- Platform: Android APK, sent directly or downloaded from a website
- Style: detailed pixel art, made in Gemini (characters) and Canva (backgrounds)
- Builder: Claude Code on a laptop, using the art files from this plan

## Characters

Four characters carry the game. Only Janani is playable; no other friends appear.

| Character | Role | Look | Frames available | Art file |
|---|---|---|---|---|
| Janani (hero) | Player | Long dark hair, white kurti, light jeans, white sneakers, lanyard | Idle, run, walk, jump, hurt, peace-sign victory | gracy_main.png |
| Janika (twin) | Captured by the boss; freed after the fight; joins the party | Patterned black top, jeans | Idle, walk, run, wave | janika_twin.png |
| Kitty (guide) | Appears in each level to warn about hazards and encourage Janani | To be generated | None yet | — |
| Boss (Yuva) | Playful "villain" who captured Janika and guards the party | Curly hair, glasses, devil-horn headband, black outfit, smiley belt | Idle, throw, jump, hurt, dizzy, defeated, holding cake | boss_confident.png, boss_panicked.png |

Janani also has 5 alternate outfits in gracy_outfits.png (printed white kurti, black dress, brown jacket, "25" crop top, maroon churidar). They are fully playable: one unlocks each time she clears a level, and she can switch outfits from the title screen. Each outfit gets its own action sheet (outfit_*.png) with run, jump, hurt and victory frames. The twin is never playable, so she needs no jump frames. Janika's captured look (cage or bubble) can be drawn in code around her idle frame.

Not used: art/unused/ holds an extra girl Gemini added by mistake and the outfit sheet with the bag. The friends and party scene on the extras collage are not used either.

## Worlds and levels

World 1 has 5 different levels (decided 5 Oct); clearing each one unlocks one of the 5 outfits. Worlds 2 and 3 are still to be designed.

| Level | Name | Idea |
|---|---|---|
| 1-1 | Sunny Meadow | Gift blocks, rolling hills, a moving platform over a pit, a rope swing over a chasm, a secret block, two staircases |
| 1-2 | Windy Hills | Real hills, bees and diving bees, spiky snails, spike pits, a rope swing, a crumbling bridge |
| 1-3 | Treetop Heights | Up in the sky: floating blocks, crumbling blocks, lifts, and two ropes to swing across in a row |
| 1-4 | Brick Fortress | Brick ceilings to smash, crate towers, a sealed brick room hiding the candle (golden-hour light) |
| 1-5 | Yuva's Hill | A dusk gauntlet with hills and a rope, ending in a boss fight with Yuva (3 stomps; bombs; he gets more panicked each hit), then he escapes with Janika |

Each level hides one birthday candle and three big crystals, plus secret rooms (covered by dirt or brick that looks solid; Kitty shows a "!" when one is near).

Power-ups: cupcake shield (a glowing bubble that takes one hit), golden star (invincible for 8 s), heart (+1 heart), balloon (double jump and glide for 15 s), gem magnet (15 s). Timed ones show a bar in the HUD.

Reachability is checked with `node tools/check_levels.mjs` after any level change. A results card after each level shows score, time bonus, gems, crystals, candle and any new outfit.

Story: an opening cutscene (Yuva kidnaps Janika in a bubble) before 1-1, and a scene after the 1-5 boss where Yuva escapes to the Crystal Cave. Both can be rewatched from STORY in the menu.

Feel (decided 5 Oct): Mario-style. Kitty runs along behind Janani as a companion; checkpoints are balloon posts; score, time limit, "WORLD 1-1" card, original chiptune music, and a full menu (continue, world map, wardrobe, story, settings, credits).

## Gameplay

On-screen touch buttons: left, right, and jump. Stomping an enemy defeats it; touching one from the side costs a heart.

| Item | Effect |
|---|---|
| Amethyst gem | Main collectible; 100 gems = extra life |
| Gift-box block | Hit from below to release a gem or power-up |
| Cupcake | Sparkly glow; survive one extra hit |
| Golden star | A few seconds of invincibility |
| Heart | Restores health |
| Birthday candle | One hidden per level; collect all to unlock a bonus surprise |

| Enemy | Behavior | Defeated frame |
|---|---|---|
| Grumpy mushroom | Walks back and forth | Sleepy, flattened |
| Bee | Flies in a wave pattern | Dizzy |
| Spiky snail | Slow; cannot be stomped from above | Hides in shell with a poof |

Hazards: spikes and lava. Crates and brick blocks can be broken. Secret invisible blocks give an extra life. One alternate outfit unlocks after each World 1 level (5 levels, 5 outfits).

## Boss fight and ending

The boss takes 3 stomps and gets more panicked after each hit, then reveals the birthday cake.

1. Hit 0: smug idle, confident bomb throws, happy jumps (first boss sheet).
2. After hit 1: hurt frame flashes, then attacks continue with crying throw and jump frames (second boss sheet).
3. After hit 2: dizzy swaying frame between faster attacks.
4. After hit 3: defeated sitting frame; dialogue box with a close-up portrait: "Okay, okay, you win!"
5. Janika is freed, runs over, and the twins hug (reunion_hug.png).
6. The boss stands up holding the birthday cake; the cake's text is covered and redrawn in code to read "Happy Birthday Janani & Janika".
7. Party scene in the night sky: both twins, the kitty and the boss, balloons and confetti, final birthday message.

The bomb is cut out of the throw frame and animated separately so its text never appears mirrored.

Final birthday message (shown on the last screen of the party scene):

> Happy Birthday, Janani! Thank you for your endless encouragement and for always lifting me up when things got hard.

## Asset checklist

All art is done as of 5 Oct. Every file is in art/. Gemini watermarks were removed from the backgrounds, the party scene and the app icon, and a seam strip was trimmed off the left of bg_night.png.

- [x] Janani main sheet (gracy_main.png, white kurti): idle, run, walk, jump, hurt, victory. Skip bottom-row frames 2–3 (wrong shoes)
- [x] Janani alternate outfits (gracy_outfits.png): 4 extra outfits, walk frames
- [x] Janika twin sheet (janika_twin.png): idle, walk, run, wave. Skip the run frame with a stray extra head
- [x] Kitty guide sheet (kitty.png): 4 sitting idle frames (tail swish, mouth open), talk, wave, happy jump, 4 walk frames. Most frames face left; the jump and walk frame 2 face right, so flip them in code. Skip walk frame 4 (Gemini watermark on its body)
- [x] Boss sheets (boss_confident.png, boss_panicked.png)
- [x] Enemies (enemies.png): mushroom, bee, snail
- [x] Meadow tiles (tiles.png): grass blocks, dirt, brick, gift-box block, used block, crate, spikes, lava
- [x] Grass ground strip and dirt blocks (ground.png). Use one segment of the strip; it has black seam lines between segments
- [x] Crystal cave tiles (tiles_cave.png): crystal top, cracked fill, left and right edges, floating ledge. A second version is in art/unused/tiles_cave_alt.png
- [x] Night sky cloud platforms (tiles_cloud.png): stretchable left/middle/right pieces, a small cloud, a cloud with a star
- [x] Collectibles (collectibles.png): amethyst gem, cupcake, star, heart, candle. Gem frame 1 is a cluster unlike frames 2–4, so the spin uses 2–4
- [x] Backgrounds: bg_meadow.png, bg_cave.png, bg_night.png (bottom fifth of meadow and cave is plain, for the ground tiles to cover)
- [x] Decorations: deco_meadow.png, deco_cave.png, deco_night.png
- [x] Birthday finish gate (finish_gate.png), with a blank yellow banner for text drawn in code
- [x] Party scene (party_scene.png): night sky, bunting, balloons, confetti, three-tier cake on a table, no characters, open space on both sides of the cake
- [x] App icon (app_icon.png): Janani's face on purple with sparkles
- [x] Outfit action sheets (5): outfit_kurti_print.png, outfit_black_dress.png, outfit_brown_jacket.png, outfit_25_top.png, outfit_maroon.png. Each is 2 rows of 5: run frames on top; jump rise, jump peak, jump fall, hurt, victory below. Use top-row frames 2–5 as the run loop (frame 1 is a walk or standing start). Gemini watermarks removed from the victory frames
- [x] Twins reunion hug (reunion_hug.png): 2 frames, a hug and a happy hug with Janika kicking one leg up
- [ ] Made in code (no art needed): the "Gracy the Adventurer" logo, banner and cake text, effects (dust puff, sparkle, poof, stomp stars), Janika's captive bubble or cage

extras_collage.png (page 7 of the art PDF) is no longer needed; everything on it has a full-size replacement or is made in code.

## Gemini prompts

Send these one at a time in the same Gemini chat as the characters, so it keeps the style. If it drifts, remind it: "Keep the rules from my first message and the same art style." Download each result with Gemini's download button and save it in art/ under the file name shown.

| # | Asset | Save as |
|---|---|---|
| 1 | Meadow background | bg_meadow.png |
| 2 | Crystal cave background | bg_cave.png |
| 3 | Night sky background | bg_night.png |
| 4 | Crystal cave ground tiles | tiles_cave.png |
| 5 | Night sky cloud platforms | tiles_cloud.png |
| 6 | Birthday finish gate | finish_gate.png |
| 7 | Party scene | party_scene.png |
| 8 | App icon | app_icon.png |
| 9 | Meadow decorations | deco_meadow.png |
| 10 | Crystal cave decorations | deco_cave.png |
| 11 | Night sky decorations | deco_night.png |
| 12–16 | Outfit action sheets (10 poses each, from gemini_refs/) | outfit_*.png |
| 17 | Twins reunion hug | reunion_hug.png |

Full prompt text, numbered to match the table:

1. Next: a wide side-scrolling game background in the same pixel-art style, 16:9 landscape. A sunny meadow: bright blue sky, soft white clouds, distant green hills and mountains, a few small trees far away. No characters, no text, no foreground objects. Keep the bottom fifth plain green grass, because the game's ground tiles will cover it. Make the left and right edges match so the image can repeat side by side.
2. Next: a wide side-scrolling game background in the same pixel-art style, 16:9 landscape. A crystal cave: dark purple rock walls, glowing purple and blue crystals in the distance, stalactites hanging from the top, a soft purple glow. No characters, no text, no foreground objects. Keep the bottom fifth plain dark rock, because the game's ground tiles will cover it. Make the left and right edges match so the image can repeat side by side.
3. Next: a wide side-scrolling game background in the same pixel-art style, 16:9 landscape. A night sky high above the clouds: deep navy sky, lots of twinkling stars, a crescent moon, soft clouds along the bottom, and a few colorful balloon bunches floating far away. No characters, no text. Make the left and right edges match so the image can repeat side by side.
4. Next: crystal cave ground tiles in the same pixel-art style, the same size as the grass and dirt tiles from before. A top tile of dark purple rock with small purple crystals on top, a plain dark purple rock fill tile, a left edge tile, a right edge tile, and a floating rock ledge. Square tiles, straight side view, evenly spaced on a plain white background, no text.
5. Next: floating cloud platforms for a night sky level in the same pixel-art style, straight side view. A fluffy white cloud platform with a flat walkable top in three pieces (left end, middle, right end) so it can be stretched to any length, plus a small single cloud platform and a cloud platform with a little star on it. Evenly spaced on a plain white background, no text.
6. Next: a birthday finish-line gate in the same pixel-art style, straight side view. Two posts wrapped in ribbon, a big banner across the top, and a bunch of colorful balloons tied to each post. Leave the banner completely blank with no letters, because the text will be added later. Plain white background, no shadow, nothing else in the image.
7. Next: a wide pixel-art birthday party scene at night in the same style, 16:9 landscape. Starry night sky, balloon bunches on both sides, colorful bunting and streamers across the top, falling confetti, and a giant three-tier birthday cake with lit candles on a table in the center. Leave the front of the cake plain with no writing, and leave open floor space on both sides of the cake for characters to stand. No characters and no text anywhere.
8. Next: a square 1:1 app icon in the same pixel-art style: a close-up of the hero's smiling face (the girl with long dark wavy hair, white kurti and green lanyard), facing forward, on a bright purple background with a few small sparkles. Her face fills most of the square. No text, no border.
9. Next: meadow decorations in the same pixel-art style, straight side view: 2 green bushes, a flowering bush, a patch of yellow flowers, a patch of purple flowers, 2 small trees, 1 round tree, 2 rocks, a short wooden fence section, a wooden signpost with an arrow pointing right, and 2 grass tufts. Every item separate with clear gaps between them, plain white background, no shadows, no text.
10. Next: crystal cave decorations in the same pixel-art style, straight side view: 3 purple crystal clusters in different sizes, a blue crystal cluster, a tall glowing crystal stalagmite, a pink glowing crystal, a pile of dark rocks, a hanging stalactite, and a blank wooden signpost. Every item separate with clear gaps between them, plain white background, no shadows, no text.
11. Next: night sky decorations in the same pixel-art style: 3 different balloon bunches in mixed colors (red, blue, yellow, green, purple), a single floating pink balloon, a crescent moon, 3 small twinkling stars in different sizes, and 2 small puffy night clouds. Every item separate with clear gaps between them, plain white background, no text.
When Gemini is used in a new chat or account, first send the rules message (0) once. Reference images are in gemini_refs/. Prompts 12–16 each take two images: gemini_refs/pose_reference.png first, then that outfit's gemini_refs/outfit_*.png.

0. (rules, send once) I'm making a 2D pixel-art side-scrolling platformer game and need sprite sheets for my character. Rules for every image in this chat: match the pixel-art style, face, skin tone, long dark wavy hair and body proportions of the girl in my reference images exactly. Full body, side view facing right, nothing cropped. Every frame the same size, evenly spaced in a neat grid. Plain pure white background. No text, no labels, no shadows, no ground, no borders. Reply "ready" and wait for my first request.
12. (outfit_kurti_print.png; attach pose_reference.png, then outfit_1_printed_kurti.png) Image 1 is my character doing 10 game poses: the top row is 5 running frames; the bottom row is jump rising, jump peak with knees tucked, jump falling, hurt with eyes squeezed shut, and victory with a big smile and peace sign. Image 2 is the same girl wearing a different outfit: a white kurti with a black floral print, light blue jeans, white shoes and a green lanyard. Redraw image 1 with exactly the same 10 poses, in the same 2 rows of 5, but dressed in the outfit from image 2. Keep her face and hair the same.
13. (outfit_black_dress.png; attach pose_reference.png, then outfit_2_black_dress.png) Image 1 is my character doing 10 game poses: the top row is 5 running frames; the bottom row is jump rising, jump peak with knees tucked, jump falling, hurt with eyes squeezed shut, and victory with a big smile and peace sign. Image 2 is the same girl wearing a different outfit: a fitted black knee-length dress with short sleeves and black flats, with no lanyard. Redraw image 1 with exactly the same 10 poses, in the same 2 rows of 5, but dressed in the outfit from image 2. Keep her face and hair the same.
14. (outfit_brown_jacket.png; attach pose_reference.png, then outfit_3_brown_jacket.png) Image 1 is my character doing 10 game poses: the top row is 5 running frames; the bottom row is jump rising, jump peak with knees tucked, jump falling, hurt with eyes squeezed shut, and victory with a big smile and peace sign. Image 2 is the same girl wearing a different outfit: a brown jacket, beige pants, brown shoes and a green lanyard. Redraw image 1 with exactly the same 10 poses, in the same 2 rows of 5, but dressed in the outfit from image 2. Keep her face and hair the same.
15. (outfit_25_top.png; attach pose_reference.png, then outfit_4_25_crop_top.png) Image 1 is my character doing 10 game poses: the top row is 5 running frames; the bottom row is jump rising, jump peak with knees tucked, jump falling, hurt with eyes squeezed shut, and victory with a big smile and peace sign. Image 2 is the same girl wearing a different outfit: a cream crop top with a big navy "25" on the front, light blue ripped jeans and black-and-white sneakers, with no lanyard. Redraw image 1 with exactly the same 10 poses, in the same 2 rows of 5, but dressed in the outfit from image 2. Keep her face and hair the same.
16. (outfit_maroon.png; attach pose_reference.png, then outfit_5_maroon_churidar.png) Image 1 is my character doing 10 game poses: the top row is 5 running frames; the bottom row is jump rising, jump peak with knees tucked, jump falling, hurt with eyes squeezed shut, and victory with a big smile and peace sign. Image 2 is the same girl wearing a different outfit: a long maroon churidar dress with sheer dotted sleeves and maroon flats, with no lanyard. Redraw image 1 with exactly the same 10 poses, in the same 2 rows of 5, but dressed in the outfit from image 2. Keep her face and hair the same.
17. (reunion_hug.png; attach twins_reference.png) This image shows my character on the left (white kurti) and her twin sister on the right (black top with small white flowers, jeans). Draw the two of them hugging happily, side view, both smiling with eyes closed, with a few small hearts and sparkles around them. Same pixel-art style and size, plain white background, no text.
18. (rope.png; optional, replaces the placeholder rope drawn in code) Next: a single hanging jungle rope / vine for a side-scrolling game, in the same pixel-art style: a thick twisted brown rope with a few green leaves, hanging straight down from a small wooden peg at the top, about 6 times taller than it is wide. Plain white background, no text.

## Build plan

Claude Code builds the game and the APK on your laptop from the art files and this doc.

1. Install Claude Code on your laptop.
2. Create a folder named gracy-game with a subfolder art, and put every image file inside art with clear names (for example gracy_main.png, boss_confident.png, boss_panicked.png, enemies.png, tiles.png, ground.png).
3. Download this doc as Markdown or PDF and put it in the gracy-game folder as game-plan.md.
4. Open Claude Code in that folder and paste the prompt below.
5. Approve its steps when it asks, then test the APK on your own phone before sending it to her.

### Prompt for Claude Code

> Read game-plan.md in this folder. It describes "Gracy the Adventurer", a 2D pixel-art side-scrolling platformer I'm making as a birthday gift. All art is in the art/ folder as AI-generated sprite sheets on white backgrounds.
>
> Please:
> 1. Look at each image, remove the white backgrounds, and slice the sprite sheets into individual frames. Skip frames that are inconsistent (wrong shoes, cropped bodies). Flip enemies and the boss to face the correct direction in code.
> 2. Build the game as an HTML5 game using Phaser, with touch controls (left, right, jump) for Android phones in landscape.
> 3. Implement everything in game-plan.md: 5 levels across 3 worlds, gems, power-ups, enemies, the kitty guide, the 3-hit boss fight with the panic stages, rescuing the twin, and the birthday party ending.
> 4. Package it as an Android APK using Capacitor, with the app icon from art/ and the app name "Gracy the Adventurer".
> 5. Keep the code minimal and well commented, and tell me exactly where the final APK file is.
>
> Ask me before making big design changes. Test each level as you go.

## Timeline to November 21

Finish all art by mid-October so the build has 4 weeks, with the last week kept for testing.

- [x] By Oct 15: all remaining art generated and saved as full-size files (done 5 Oct)
- [x] By Oct 25: Claude Code builds World 1 (meadow), playable on your phone (done 5 Oct: game/ folder, levels 1-1 and 1-2)
- [ ] By Nov 5: Worlds 2 and 3, boss fight, and party ending done
- [ ] By Nov 14: APK tested on your phone; final message and polish added
- [ ] Nov 21: send the APK or website link at midnight
