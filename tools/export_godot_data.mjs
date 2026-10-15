// Copies the game's data into the Godot project: every level as a ready-made tile grid (godot/data/levels.json).
// Run from the project folder:  node tools/export_godot_data.mjs
import { writeFileSync } from 'node:fs';
import { LEVELS, COOP_LEVELS, buildGrid } from '../game/src/levels.js';

const pack = (level, world) => {
    const { things, ...rest } = level; // `things` are baked into the grid
    return { ...rest, world, grid: buildGrid(level).map((row) => row.join('')) };
};
const data = { solo: LEVELS.map((l) => pack(l, 1)), together: COOP_LEVELS.map((l) => pack(l, 2)) };
writeFileSync('godot/data/levels.json', JSON.stringify(data, null, 1));
console.log(`wrote ${data.solo.length + data.together.length} levels to godot/data/levels.json`);
