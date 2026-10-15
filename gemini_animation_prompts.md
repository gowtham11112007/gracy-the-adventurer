# Gemini prompts: smooth animation sheets

How to use:
- Paste the **shared rules** first, then one sheet prompt, in each new Gemini message.
- Always attach the reference image named in the prompt.
- One sheet per message. If the character's size or face changes between frames, ask Gemini to redo it.
- Save each result with the file name shown, into `art/anim/`.

## Shared rules (paste before every prompt)

```
Pixel-art sprite sheet for a 2D side-scrolling platformer game. Match the attached reference character EXACTLY: same face, hair, skin tone, outfit, colours, outline thickness and pixel-art style. Pure flat white background (#FFFFFF), no shadows on the ground, no text, no labels, no numbers, no watermark, no border. Frames are laid out in ONE horizontal row, evenly spaced, with clear white gaps so frames never touch. The character is the SAME SIZE in every frame, faces RIGHT, and her feet sit on the SAME invisible baseline in every frame. Full body visible in every frame, nothing cropped.
```

---

## JANANI (attach gracy_main.png)

**J1 - Run cycle** → `janani_run.png`
```
8 frames: a smooth, energetic run cycle that loops seamlessly. Frame 1 contact (right foot forward touching ground), 2 down (body lowest, knee bent), 3 passing (legs crossing), 4 up (body highest, pushing off), 5 contact (left foot forward), 6 down, 7 passing, 8 up. Arms swing opposite to legs, hair bounces slightly with each step.
```

**J2 - Jump set** → `janani_jump.png`
```
6 frames in this order: 1 crouch before jumping (knees bent, arms back), 2 take-off (legs pushing, arms swinging up), 3 rising (body stretched, one knee up), 4 top of the jump (tucked, arms out), 5 falling (legs reaching down, hair floating up), 6 landing crouch (knees bent absorbing the landing).
```

**J3 - Rope swing** → `janani_rope.png`
```
4 frames of her holding a vertical rope with both hands above her head (draw ONLY her, NOT the rope): 1 hanging straight down, 2 swinging forward (legs kicked forward, body tilted), 3 swinging back (legs trailing behind), 4 letting go and leaping forward (arms reaching ahead).
```

**J4 - Idle** → `janani_idle.png`
```
6 frames standing still: gentle breathing loop (frames 1-4, shoulders rise and fall very slightly), frame 5 blinking, frame 6 looking around with a small smile.
```

**J5 - Hurt, victory, defeated** → `janani_emotes.png`
```
5 frames: 1 hurt (knocked back, eyes squeezed shut), 2 dizzy (stars implied by pose, wobbling), 3 victory jump with fist in the air, 4 victory peace sign with a big smile, 5 defeated sitting on the ground, sad.
```

**J6 - Teamwork poses** → `janani_coop.png`
```
6 frames for a co-op game: 1 crouching with hands cupped to boost someone up, 2 pushing a heavy box (leaning forward, arms out), 3 pressing down on a big floor button with her foot, 4 reaching up a hand to pull someone, 5 waving hello, 6 pointing forward excitedly.
```

---

## JANIKA (attach janika_twin.png)

Use the **same prompts J1–J6** with the reference image swapped to janika_twin.png. Save as `janika_run.png`, `janika_jump.png`, `janika_rope.png`, `janika_idle.png`, `janika_emotes.png`, `janika_coop.png`.

Add this line at the end of each Janika prompt:
```
She is the twin sister of the girl in the game: keep HER OWN outfit and hairstyle from the attached reference, same height and body size as a normal game hero (not chibi, not big-headed).
```

---

## KITTY (attach kitty.png)

**K1 - Run** → `kitty_run.png`
```
6 frames: a cute cat's smooth running gallop loop seen from the side: front paws reaching, gathered, back legs pushing, stretched out, gathered, landing. Tail streaming behind.
```

**K2 - Jump** → `kitty_jump.png`
```
4 frames: 1 crouch ready to pounce, 2 leaping up stretched out, 3 in the air with paws tucked, 4 landing on front paws.
```

**K3 - Idle** → `kitty_idle.png`
```
6 frames: sitting, tail swishing left (1), centre (2), right (3), blinking (4), licking a paw (5), ears perked looking up (6).
```

**K4 - Captured** → `kitty_cage.png`
```
4 frames: the cat sitting inside a small round golden birdcage, looking scared. 1 and 2 paws on the bars meowing (mouth open/closed), 3 sad sitting, 4 hopeful looking up. Draw the cage too, same cage in every frame.
```

**K5 - Happy** → `kitty_happy.png`
```
4 frames: 1 jumping for joy, 2 rolling on her back happily, 3 rubbing against something affectionately (lean), 4 sitting proudly with a big smile and hearts implied by pose (no drawn hearts).
```

---

## YUVA, the villain (attach the boss sheet)

**Y1 - Kidnap run** → `yuva_kidnap.png`
```
6 frames: the villain running to the right carrying the cat's golden birdcage under one arm, laughing mischievously. A smooth running loop.
```

**Y2 - Walk and taunt** → `yuva_walk.png`
```
6 frames: 1-4 confident walk loop, 5 pointing and laughing, 6 arms crossed smirking.
```

---

## ROPE (no reference)

**R1 - Rope** → `rope.png`
```
Pixel-art game asset on a pure white background: 1 vertical hanging jungle rope, braided, light brown with darker brown shading, 16 segments tall, with a small knotted loop at the bottom and a metal ring at the top. Same retro pixel-art style as a cute platformer. No text.
```

---

## Optional extra polish (after the above)

**E1 - Enemy walk cycles** (attach enemies.png) → `enemies_walk.png`
```
3 rows, 4 frames each: row 1 the mushroom enemy waddling, row 2 the bee flapping its wings, row 3 the snail crawling (shell bobbing). Same style as the reference.
```

The other 5 outfits for J1–J3 can come later: once the main outfit looks good, repeat J1–J3 attaching each outfit picture.

---

## THE OTHER 5 OUTFITS (run, jump, rope)

For each outfit, make 3 sheets. Paste the **shared rules**, then the **outfit line**, then the J1, J2 or J3 prompt from above.
Attach 2 pictures every time: **gracy_main.png** (for her face and size) and **the outfit's own picture**.

| Outfit | Attach | Outfit line | Save as |
|---|---|---|---|
| Printed Kurti | outfit_kurti_print.png | `She wears the printed kurti outfit from the second attached picture, exactly as drawn there.` | print_run.png, print_jump.png, print_rope.png |
| Black Dress | outfit_black_dress.png | `She wears the black dress outfit from the second attached picture, exactly as drawn there.` | black_run.png, black_jump.png, black_rope.png |
| Brown Jacket | outfit_brown_jacket.png | `She wears the brown jacket outfit from the second attached picture, exactly as drawn there.` | jacket_run.png, jacket_jump.png, jacket_rope.png |
| "25" Top | outfit_25_top.png | `She wears the "25" top outfit from the second attached picture, exactly as drawn there, with the number 25 on the top.` | top25_run.png, top25_jump.png, top25_rope.png |
| Maroon Churidar | outfit_maroon.png | `She wears the maroon churidar outfit from the second attached picture, exactly as drawn there.` | maroon_run.png, maroon_jump.png, maroon_rope.png |

---

## JANIKA, NEW DESIGN (attach art/janika_main.png, the sheet made from her photo)

Shared rules for Janika (paste before each prompt):
```
Pixel-art sprite sheet for a 2D side-scrolling platformer game. Match the girl in the attached picture EXACTLY: same face, shoulder-length dark wavy hair, skin tone, maroon long-sleeve top, light blue ripped jeans, dark sneakers, same outline thickness and pixel-art style, same height. Pure flat white background (#FFFFFF), no shadows on the ground, no text, no labels, no numbers, no watermark, no border. Frames are laid out in ONE horizontal row, evenly spaced, with clear white gaps so frames never touch. She is the SAME SIZE in every frame, faces RIGHT, and her feet sit on the SAME invisible baseline in every frame. Full body visible in every frame, nothing cropped.
```
Then use J1–J6 above. Save as janika_run.png, janika_jump.png, janika_rope.png, janika_idle.png, janika_emotes.png, janika_coop.png.

## JANIKA OUTFITS (like Janani's gracy_outfits.png)

Attach: art/janika_main.png + her outfit pictures + art/gracy_outfits.png (layout example only).
```
Pixel-art character sheet for a 2D platformer. The girl is the one in the FIRST attached picture: keep her face, hair, skin tone, height and pixel-art style EXACTLY. Draw her in the 5 outfits shown in the other attached outfit pictures, one outfit per COLUMN (5 columns). Use the layout of the attached example sheet ONLY for the grid (do NOT copy that girl or those clothes): 5 rows, row 1 standing facing right, rows 2-5 a 4-step walk cycle facing right. Same size in every cell, feet on the same baseline in each row, clear white gaps between cells. Pure flat white background (#FFFFFF), no text, no labels, no watermark.
```
Save as janika_outfits.png.

## JANIKA OUTFITS: run, jump, rope (3 outfits x 3 sheets)

Attach janika_main.png + the outfit's sheet (art/janika_outfits/denim.png, cargo.png or skirt.png).
Prompt = Janika outfit rules (below, with the outfit sentence) + J1, J2 or J3.
Save as denim_run.png, denim_jump.png, denim_rope.png (and the same for cargo and skirt) into art/janika_outfits/.

---

## JANANI'S 5 OUTFITS: ready-to-paste prompts (attach gracy_main.png + the outfit picture)

### Printed Kurti (attach gracy_main.png + outfit_kurti_print.png)

print_run.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a white kurti with a black floral print, a teal lanyard with an ID card, light blue jeans and white shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames: a smooth, energetic run cycle that loops seamlessly, feet on the same baseline in every frame, arms swinging opposite to the legs, hair bouncing a little with each step.
```

print_jump.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a white kurti with a black floral print, a teal lanyard with an ID card, light blue jeans and white shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames in this order: 1 crouching before the jump, 2 taking off with arms swinging up, 3 rising with one knee up, 4 at the top of the jump tucked with arms out, 5 falling with legs reaching down and hair floating up, 6 landing in a soft crouch.
```

print_rope.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a white kurti with a black floral print, a teal lanyard with an ID card, light blue jeans and white shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 4 frames: 1 holding a jungle vine above her head with both hands, hanging still; 2 swinging forward on the vine, clothes and hair flowing behind her; 3 swinging back, clothes and hair flowing forward; 4 letting go and leaping ahead with arms reaching forward. Draw only the girl, not the vine.
```

### Black Dress (attach gracy_main.png + outfit_black_dress.png)

black_run.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a simple black knee-length dress with short sleeves and black flat shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames: a smooth, energetic run cycle that loops seamlessly, feet on the same baseline in every frame, arms swinging opposite to the legs, hair bouncing a little with each step.
```

black_jump.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a simple black knee-length dress with short sleeves and black flat shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames in this order: 1 crouching before the jump, 2 taking off with arms swinging up, 3 rising with one knee up, 4 at the top of the jump tucked with arms out, 5 falling with legs reaching down and hair floating up, 6 landing in a soft crouch.
```

black_rope.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a simple black knee-length dress with short sleeves and black flat shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 4 frames: 1 holding a jungle vine above her head with both hands, hanging still; 2 swinging forward on the vine, clothes and hair flowing behind her; 3 swinging back, clothes and hair flowing forward; 4 letting go and leaping ahead with arms reaching forward. Draw only the girl, not the vine.
```

### Brown Jacket (attach gracy_main.png + outfit_brown_jacket.png)

jacket_run.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a brown jacket over a top, a teal lanyard with an ID card, beige trousers and brown shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames: a smooth, energetic run cycle that loops seamlessly, feet on the same baseline in every frame, arms swinging opposite to the legs, hair bouncing a little with each step.
```

jacket_jump.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a brown jacket over a top, a teal lanyard with an ID card, beige trousers and brown shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames in this order: 1 crouching before the jump, 2 taking off with arms swinging up, 3 rising with one knee up, 4 at the top of the jump tucked with arms out, 5 falling with legs reaching down and hair floating up, 6 landing in a soft crouch.
```

jacket_rope.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a brown jacket over a top, a teal lanyard with an ID card, beige trousers and brown shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 4 frames: 1 holding a jungle vine above her head with both hands, hanging still; 2 swinging forward on the vine, clothes and hair flowing behind her; 3 swinging back, clothes and hair flowing forward; 4 letting go and leaping ahead with arms reaching forward. Draw only the girl, not the vine.
```

### "25" Top (attach gracy_main.png + outfit_25_top.png)

top25_run.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a white crop top with a big navy number 25 on the front, light blue ripped jeans and black-and-white sneakers, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames: a smooth, energetic run cycle that loops seamlessly, feet on the same baseline in every frame, arms swinging opposite to the legs, hair bouncing a little with each step.
```

top25_jump.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a white crop top with a big navy number 25 on the front, light blue ripped jeans and black-and-white sneakers, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames in this order: 1 crouching before the jump, 2 taking off with arms swinging up, 3 rising with one knee up, 4 at the top of the jump tucked with arms out, 5 falling with legs reaching down and hair floating up, 6 landing in a soft crouch.
```

top25_rope.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a white crop top with a big navy number 25 on the front, light blue ripped jeans and black-and-white sneakers, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 4 frames: 1 holding a jungle vine above her head with both hands, hanging still; 2 swinging forward on the vine, clothes and hair flowing behind her; 3 swinging back, clothes and hair flowing forward; 4 letting go and leaping ahead with arms reaching forward. Draw only the girl, not the vine.
```

### Maroon Churidar (attach gracy_main.png + outfit_maroon.png)

maroon_run.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a long maroon churidar dress with sheer dotted maroon sleeves and maroon flat shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames: a smooth, energetic run cycle that loops seamlessly, feet on the same baseline in every frame, arms swinging opposite to the legs, hair bouncing a little with each step.
```

maroon_jump.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a long maroon churidar dress with sheer dotted maroon sleeves and maroon flat shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 6 frames in this order: 1 crouching before the jump, 2 taking off with arms swinging up, 3 rising with one knee up, 4 at the top of the jump tucked with arms out, 5 falling with legs reaching down and hair floating up, 6 landing in a soft crouch.
```

maroon_rope.png
```
Pixel-art sprite sheet for a cute 2D adventure game, like a classic platformer. The girl in the FIRST attached picture: keep her face, long dark wavy hair, skin tone, height and pixel-art style EXACTLY. She wears a long maroon churidar dress with sheer dotted maroon sleeves and maroon flat shoes, exactly as in the SECOND attached picture. Pure flat white background, no text, no labels, no watermark, no border. Frames in ONE horizontal row with clear white gaps, she is the SAME SIZE in every frame, faces RIGHT, full body visible. 4 frames: 1 holding a jungle vine above her head with both hands, hanging still; 2 swinging forward on the vine, clothes and hair flowing behind her; 3 swinging back, clothes and hair flowing forward; 4 letting go and leaping ahead with arms reaching forward. Draw only the girl, not the vine.
```

---

## NEW GEMINI ACCOUNT: first message (attach gracy_main.png)

```
Hi! I'm making a 2D pixel-art platformer game (like classic Mario) as a birthday gift. The hero is the girl in the attached picture. I'll ask you for sprite sheets of her in different outfits: running, jumping and swinging on a vine.

Rules for EVERY image I ask for:
1. Keep her EXACTLY like the attached picture: same face, long dark wavy hair, skin tone, height, outline thickness and pixel-art style.
2. Only the clothes change, to the outfit picture I attach.
3. ONE single horizontal row of frames. Exactly the number of frames I ask for, nothing more. No second row, no extra poses.
4. She is the SAME SIZE in every frame and faces RIGHT. Full body visible, nothing cropped.
5. Pure flat white background. No text, no numbers, no labels, no watermark, no border, no shadows.

Reply "ready" and wait for my first request.
```

---

## WORLD 1 MAP (save as art/world1_map.png)
```
A 16:9 pixel-art world map for a cute 2D platformer game, in the same pixel-art style as the attached picture, seen from a slightly raised side view like classic Mario world maps. A winding light dirt path runs from the bottom-left to the right side, with 5 clearly separated round empty clearings along it (one for each level). Along the path, left to right: 1 a sunny green meadow with flowers and a small cottage; 2 rolling windy hills with a windmill and grass blowing; 3 a tall treetop forest with wooden platforms and rope swings between the trees; 4 a golden-brick fortress castle at sunset; 5 a dark purple hill at dusk with a spooky little castle and a flag with devil horns on top. Soft blue sky with fluffy clouds at the top. No characters, no text, no numbers, no labels, no watermark.
```

## TRICK DOORS (save as art/doors.png)
```
Two pixel-art doors for a cute 2D platformer, same pixel-art style as the attached picture, side by side on a pure white background with a clear gap. 1 a heavenly door: glowing white and gold arched door with little fluffy clouds and a soft golden glow around it, looks very inviting. 2 a scary door: dark red arched wooden door with iron bands, small flames at the bottom edges and two little devil horns on top. Same size, each about twice as tall as wide, facing the viewer. No text, no letters, no watermark, no shadows.
```

## NOTICE BOARD (save as art/notice_board.png)
```
A pixel-art wooden notice board on two posts for a cute 2D platformer, same pixel-art style as the attached picture: a light wooden board with a darker frame, slightly weathered, completely BLANK so text can be added later. Pure white background, no text, no letters, no watermark.
```
