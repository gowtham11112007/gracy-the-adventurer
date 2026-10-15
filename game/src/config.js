// Everything personal lives here, so names and messages are easy to change in one place.
export const NAMES = {
    game: 'Gracy the Adventurer',
    hero: 'Janani',
    twin: 'Janika',
    boss: 'Yuva',
};

export const CAKE_TEXT = 'Happy Birthday Janani & Janika';
export const FINAL_MESSAGE =
    'Happy Birthday, Janani! Thank you for your endless encouragement and for always lifting me up when things got hard.';

// Game size (it stretches sideways to fill wider phones) and level grid
export const WIDTH = 1280;
export const HEIGHT = 720;
export const TILE = 64;
export const FONT = '"Press Start 2P", monospace';

// Outfits in unlock order: one more unlocks each time a level is cleared
// TESTING ONLY: every outfit for both twins can be worn without unlocking it. Set to false before the birthday build!
export const UNLOCK_ALL_OUTFITS = true;
// TESTING ONLY: every World 2 level can be picked in the lobby. Set to false before the birthday build!
export const UNLOCK_ALL_LEVELS = true;

export const OUTFITS = [
    { key: 'kurti', name: 'White Kurti' },
    { key: 'print', name: 'Printed Kurti' },
    { key: 'black', name: 'Black Dress' },
    { key: 'jacket', name: 'Brown Jacket' },
    { key: 'top25', name: '"25" Top' },
    { key: 'maroon', name: 'Maroon Churidar' },
];

// Janika's clothes (two-phone play): her everyday maroon top, then one more for each co-op level she finishes
export const JANIKA_OUTFITS = [
    { key: 'janika', name: 'Maroon Top' },
    { key: 'janika_denim', name: 'Denim Shirt' },
    { key: 'janika_cargo', name: 'Black & Cargo' },
    { key: 'janika_skirt', name: 'Festive Skirt' },
];
// her outfit strips (janika_<key>): 0 standing, 1-5 walking; run, jump and rope are in hero_janika_<key>_moves / _rope
// how to draw Janika in the outfit she picked (cutscenes, title, map): texture, animations and pose frames
export function janikaLook(outfit = 'janika') {
    if (outfit === 'janika') return { tex: 'twin', idle: 'twin_idle', walk: 'twin_walk', stand: 0, peace: 9 };
    return { tex: outfit, idle: `${outfit}_idle`, walk: `${outfit}_walk`, stand: 0, peace: 0 };
}
export const JANIKA_OUTFIT_FRAMES = { idle: [0], walk: [1, 2, 3, 4, 5], hurt: 0, victory: 0, rise: 0, peak: 0, fall: 0 };

// Frame order inside every art strip hero_*.png (made by tools/prepare_sprites.py)
// extra frames in hero_<outfit>_moves (only outfits Gemini has drawn them for) and hero_<outfit>_rope
export const MOVES = { run: [0, 1, 2, 3, 4, 5], takeoff: 7, rise: 8, peak: 9, fall: 10, land: 11 };
export const ROPE_FRAMES = { hang: 0, kick: 1, trail: 2 };
export const HERO_FRAMES = {
    idle: [0, 0, 0, 0, 1, 0, 0, 2],
    run: [3, 4, 5, 6],
    walk: [7, 8, 9, 10],
    rise: 11, peak: 12, fall: 13, hurt: 14, victory: 15,
};

// Player feel
export const PHYSICS = {
    gravity: 1800,
    runSpeed: 300,
    jumpVelocity: 1040,    // about 4.7 tiles high (a quick tap reaches about 4.5)
    stompBounce: 620,
};

// Points, Mario style
export const SCORE = { gem: 100, stomp: 200, brick: 50, power: 1000, candle: 5000, crystal: 2000, boss: 5000, timeBonus: 50 };

// Two-phone play (Supabase Realtime). The anon key is public by design: it only allows the live room channels.
export const SUPABASE = {
    url: 'https://jcmbdybsirnlasqydqjf.supabase.co',
    key: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjbWJkeWJzaXJubGFzcXlkcWpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyNDg5MjAsImV4cCI6MjEwNjgyNDkyMH0.dYY_2Ueq5nw7ib2Y1JokWHDeh0FXvgj_9I4OjOVrTXQ',
};

// Janika's strip ("twin"): 0 front, 1-2 breathing, 3 blink, 4 smile, 5 side view, 6 hurt, 7 dizzy,
// 8 jump for joy, 9 peace sign, 10 sad sitting. Her run, jump and rope frames are in hero_janika_moves / _rope.
export const TWIN_FRAMES = { idle: [0, 1, 2, 1, 0, 0, 3, 0, 1, 2, 1, 4], hurt: 6, victory: 9, rise: 8, peak: 8, fall: 8 };

// This build's version, and where the online updater looks for newer ones (see updater.js, tools/release.mjs)
export const VERSION = __GAME_VERSION__;
export const UPDATE_URL = 'https://raw.githubusercontent.com/gowtham11112007/gracy-the-adventurer-updates/main/birthday/latest.json';
