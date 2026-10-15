// Checks that every level can be finished and that every crystal, candle and secret can be reached.
// Run from the project folder:  node tools/check_levels.mjs
//
// It walks the level grid like Janani would: walking, jumping (up to 4 tiles up, a few across),
// falling, riding moving platforms, swinging on ropes and going through doors. Rough on purpose, but it catches
// ledges and items placed too high or too far to ever get to.
import { LEVELS, COOP_LEVELS, buildGrid } from '../game/src/levels.js';

const SOLID = new Set(['#', 'B', 'C', '=', '?', '+', '*', '&', '~', 'U', 'G', 'R']);
const MAX_RISE = 4;        // rows she can jump up onto
// World 2 (two phones): standing on her sister's head adds about 2 rows, the High Jump power 3;
// gates and twin walls count as open (the sisters open them for each other), bridges as built,
// and boulders as smashable (one twin has Strength).
const REACH_UP = 6;        // rows above her feet her hands can touch at the top of a jump

function check(level, coop = false) {
    const g = buildGrid(level);
    if (coop) g.forEach((row) => row.forEach((ch, c) => { if (ch === 'R') row[c] = ' '; }));
    const maxRise = coop ? ((level.pedestals || []).some((p) => p[2] === 'jump') ? 7 : 6) : MAX_RISE;
    const W = level.width;
    const solid = (c, r) => r >= 0 && r < 12 && c >= 0 && c < W && SOLID.has(g[r][c]);
    const extra = new Set(); // standing spots on moving platforms, anywhere along their path
    for (const [col, row, w, , , mode] of level.gates || []) {
        if (mode === 'bridge') for (let i = 0; i < w; i++) extra.add(`${col + i},${row}`);
    }
    for (const [col, row, w, dx, dy] of level.movers || []) {
        const steps = Math.max(Math.abs(dx), Math.abs(dy));
        for (let s = 0; s <= steps; s++) {
            const r = row + Math.round((dy * s) / (steps || 1));
            const c0 = col + Math.round((dx * s) / (steps || 1));
            for (let i = 0; i < w; i++) extra.add(`${c0 + i},${r}`);
        }
    }
    const isSurface = (c, r) => (solid(c, r) || extra.has(`${c},${r}`)) && !solid(c, r - 1) && !solid(c, r - 2);

    const surfaces = [];
    for (let r = 0; r < 12; r++) for (let c = 0; c < W; c++) if (isSurface(c, r)) surfaces.push([c, r]);

    // how far across she can get when the landing spot is `rise` rows higher (negative = lower)
    const across = (rise) => (rise >= 4 ? 3 : rise >= 2 ? 4 : rise >= 0 ? 5 : 5 + Math.ceil(-rise / 2)) + (coop ? 2 : 0);

    const start = surfaces.find(([c, r]) => c === level.start && r === 10);
    const seen = new Set([`${start}`]);
    const queue = [start];
    while (queue.length) {
        const [c, r] = queue.shift();
        const next = [];
        for (const [c2, r2] of surfaces) {
            const rise = r - r2;
            if (rise <= maxRise && Math.abs(c2 - c) <= across(Math.min(rise, MAX_RISE))) next.push([c2, r2]);
        }
        // ropes: from near a rope she can swing to anything a few tiles either side of it
        for (const [col, row, len] of level.ropes || []) {
            const bottom = row + len;
            if (Math.abs(c - col) <= 4 && r - bottom <= REACH_UP && r >= bottom - 1) {
                for (const [c2, r2] of surfaces) if (Math.abs(c2 - col) <= 9 && r2 >= bottom - 3) next.push([c2, r2]);
            }
        }
        // doors: walking into one puts her down on the ground at another column
        for (const [col, row, , to] of level.doors || []) {
            if (Math.abs(c - col) <= 1 && r === row) next.push([to, 10]);
        }
        for (const s of next) {
            const k = `${s}`;
            if (!seen.has(k)) { seen.add(k); queue.push(s); }
        }
    }
    const reached = [...seen].map((k) => k.split(',').map(Number));

    // things she should be able to touch: crystals, candle, secret blocks
    const problems = [];
    // cells a rope sweeps through: she touches them while swinging, if she can get to that rope
    const swept = new Set();
    for (const [col, row, len, deg] of level.ropes || []) {
        const bottom = row + len;
        const usable = reached.some(([c, r]) => Math.abs(c - col) <= 4 && r - bottom <= REACH_UP && r >= bottom - 1);
        if (!usable) continue;
        const amp = (deg * Math.PI) / 180;
        for (let a = -amp; a <= amp; a += 0.05) {
            for (let d = len * 0.3; d <= len + 1; d += 0.5) {
                const x = col + Math.sin(a) * d;
                const y = row + Math.cos(a) * d;
                for (const [ox, oy] of [[0, 0], [0, 1], [1, 0], [-1, 0]]) swept.add(`${Math.round(x) + ox},${Math.round(y) + oy}`);
            }
        }
    }
    const canTouch = (c, r) => swept.has(`${c},${r}`) ||
        reached.some(([sc, sr]) => Math.abs(sc - c) <= 2 && sr - r >= 0 && sr - r <= REACH_UP);
    for (let r = 0; r < 12; r++) {
        for (let c = 0; c < W; c++) {
            const ch = g[r][c];
            const what = { X: 'crystal', c: 'candle', H: 'secret block', U: 'balloon gift', G: 'magnet gift' }[ch];
            if (what && !canTouch(c, r)) problems.push(`${what} at column ${c}, row ${r}`);
        }
    }
    const goal = level.boss ? level.boss[0] + 3 : level.finish;
    if (!reached.some(([c, r]) => r === 10 && Math.abs(c - goal) <= 1)) problems.push(`can't reach the ${level.boss ? 'boss arena' : 'finish'} (column ${goal})`);
    return problems;
}

let bad = 0;
for (const [level, coop] of [...LEVELS.map((l) => [l, false]), ...COOP_LEVELS.map((l) => [l, true])]) {
    const problems = check(level, coop);
    bad += problems.length;
    console.log(`${level.id} ${level.name}: ${problems.length ? problems.length + ' problem(s)' : 'all reachable'}`);
    problems.forEach((p) => console.log('   - ' + p));
}
process.exit(bad ? 1 : 0);
