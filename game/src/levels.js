// Level layouts. Each level is a grid of 64px tiles, 12 rows tall.
// Columns run left to right; rows run from the top (0) to the bottom (11).
// The ground is rows 10-11, so things standing on the ground go in row 9.
// Janani can jump about 4 tiles up and 4 tiles across.
//
// `things` entries are [column, row, 'letters']: each letter fills one tile, left to right
// (a space skips a tile).
//   # ground (pillars, stairs, floating islands)   = grass block
//   B brick (breaks when bumped)    C crate (breaks when bumped)
//   ? gift with a gem   + gift with a cupcake   * gift with a star   & gift with a heart
//   U gift with a balloon (double jump + glide)    G gift with a gem magnet
//   H secret block: invisible until bumped from below, gives an extra life
//   F fake brick wall, f fake dirt: they look solid but Janani walks (or falls) right through
//   . clears a tile (used to hollow out secret rooms inside hills)
//   ^ spikes    o gem    c birthday candle (one hidden per level)    X big crystal (three hidden per level)
//   m grumpy mushroom   M hopping mushroom   b bee   d diving bee   n spiky snail
//   ~ crumbling dirt block: falls a moment after Janani stands on it, comes back later
//
// `mood` sets the weather and light: day, windy, sky, golden, dusk. `music` picks the tune (default meadow).
// `movers` are moving grass platforms: [column, row, width, tiles right, tiles down, seconds per trip].
// `gaps` are columns with no ground (fall in and you lose a life).
// `ropes` hang from a peg and swing: [column, row of the peg, length in tiles, swing angle, seconds per swing].
//   Janani grabs one by jumping into it, and lets go with the jump button to fly off with its momentum.
// `boss` (last level only): the arena columns where Yuva waits instead of a finish gate.
// `doors` lead somewhere else: [column, row she stands on, label, column she comes out at].
//   Walk into one to go through. (The trick door just sends her back; only the sign tells the truth.)
// `signs` are notice boards: [column, row she stands on, text].
// `secrets` are hidden rooms: [column, row, width, height, 'dirt' or 'brick'] drawn over empty tiles so
//   they look solid; they turn see-through when Janani steps (or falls) inside.

const B = (n) => 'B'.repeat(n);
const ground = (n) => '#'.repeat(n);

// gems laid out as pictures (rows top to bottom, starting at col,row)
const shape = (col, row, lines) => lines.map((line, i) => [col, row + i, line]);
const HEART = [' oo oo ', 'ooooooo', 'ooooooo', ' ooooo ', '  ooo  ', '   o   '];
const TWENTY_ONE = ['ooo  o ', '  o oo ', 'ooo  o ', 'o    o ', 'ooo ooo'];
const ARROW = ['   o  ', '    o ', 'oooooo', '    o ', '   o  '];

// a staircase climbing to the right: [col, row, letters] rows for `height` steps
const stairsUp = (col, height, extraTop = 0) =>
    Array.from({ length: height }, (_, i) => [col + i, 9 - i, ground(height - i + extraTop)]);
// a staircase going down to the right
const stairsDown = (col, height) =>
    Array.from({ length: height }, (_, i) => [col, 9 - height + 1 + i, ground(i + 1)]);
// rolling hills: one column of ground per height, e.g. hill(20, [1, 2, 3, 3, 2, 1])
const hill = (col, heights) =>
    heights.flatMap((h, i) => Array.from({ length: h }, (_, k) => [col + i, 9 - k, '#']));
// a pillar of ground `height` tiles tall and `width` wide, standing on the ground
const pillar = (col, height, width = 2) =>
    Array.from({ length: height }, (_, i) => [col, 9 - i, ground(width)]);

export const LEVELS = [
    {
        id: '1-1',
        name: 'Sunny Meadow',
        width: 190, time: 260, start: 2, checkpoint: 92, finish: 182, mood: 'day',
        gaps: [[57, 59], [80, 86], [119, 120], [140, 146], [151, 152]],
        movers: [[80, 8, 3, 4, 0, 3]],
        ropes: [[143, 1, 5, 42, 2.4]],
        secrets: [[40, 6, 1, 2, 'dirt'], [39, 8, 2, 2, 'dirt']],
        things: [
            ...shape(6, 3, HEART),
            [13, 6, '?'],
            [17, 6, 'B+B?B'], [19, 2, '?'],
            [24, 9, 'm'], [26, 9, 'm'],
            ...hill(28, [1, 2, 2, 1]), [33, 9, 'M'], ...hill(36, [1, 2, 3, 4, 4, 3, 2, 1]), [40, 5, 'oo'], [40, 2, 'X'],
            [40, 6, '.'], [40, 7, '.'], [39, 8, 'oo'], [39, 9, 'oo'], // secret chamber (see secrets)
            [45, 9, 'm'],
            [50, 9, 'M'], [53, 9, 'm'],
            [57, 6, 'ooo'],
            [62, 6, 'BUB'], [66, 6, 'H'], [64, 2, '====='], [64, 1, 'ooooo'],
            [70, 9, 'm'], [72, 9, 'm'],
            [80, 6, 'oooooo'],
            [96, 6, `${B(4)}*${B(4)}`], [98, 2, 'BB?BB'], [100, 1, 'c'], [102, 1, 'X'],
            [99, 9, 'm'], [101, 9, 'm'], [103, 9, 'm'],
            ...shape(106, 3, TWENTY_ONE),
            ...stairsUp(114, 4, 1), ...stairsDown(121, 4).map(([c, r, s]) => [c, r, s + '#']),
            [130, 9, 'M'], [133, 9, 'm'], [136, 9, 'm'],
            [131, 6, '?G?'],
            [141, 5, 'oo'], [143, 6, 'X'], [145, 5, 'oo'], [149, 4, 'd'],
            [151, 7, 'oo'],
            [156, 6, 'B&B'],
            [160, 9, 'm'],
            ...stairsUp(166, 8, 1), [168, 6, 'o'], [170, 4, 'o'], [172, 2, 'o'],
        ],
    },
    {
        id: '1-2',
        name: 'Windy Hills',
        width: 200, time: 260, start: 2, checkpoint: 100, finish: 193, mood: 'windy',
        gaps: [[22, 24], [48, 53], [90, 95], [128, 131], [160, 166]],
        movers: [[90, 8, 2, 4, 0, 2.4], [160, 8, 2, 5, 0, 3]],
        ropes: [[50, 1, 5, 40, 2.4]],
        things: [
            [8, 6, 'BUB'],
            [12, 9, 'n'], [16, 9, '^^'], [19, 5, 'b'],
            [22, 7, 'ooo'], ...shape(25, 3, ARROW),
            [28, 9, 'M'], [31, 9, 'n'],
            ...hill(32, [1, 2, 3, 2, 1]), [37, 6, 'B*B'],
            [40, 9, '^^^'], [44, 4, 'd'],
            [47, 6, 'oo'], [50, 6, 'X'], [52, 6, 'oo'],
            [56, 9, 'M'], [58, 9, 'm'], [60, 9, 'm'],
            [62, 6, 'BGB'],
            ...hill(66, [1, 2, 3, 4, 4, 4, 4, 3, 2, 1]), [70, 5, 'm'], [71, 2, 'X'],
            [78, 9, 'n'], [81, 9, '^^'], [85, 4, 'd'],
            [90, 6, 'oooooo'],
            [104, 6, '?BUB?'], [106, 1, '===='], [106, 0, 'oooo'],
            [106, 9, 'M'], [108, 9, 'm'], [110, 9, 'n'],
            [114, 5, 'b'], [116, 9, '^^^^'], [118, 3, 'd'],
            [124, 6, 'H'],
            [127, 8, '~~~~~~'], [128, 6, 'oooo'],
            [134, 9, 'n'], [137, 9, 'm'],
            [140, 6, '==='], [144, 3, '==='], [145, 2, 'c'],
            [150, 9, 'M'], [152, 9, 'm'], [154, 9, 'n'], [156, 4, 'd'],
            [160, 6, 'oooooo'],
            [170, 6, 'B&B'], [175, 9, 'n'],
            ...stairsUp(180, 6, 1), [184, 1, 'X'],
        ],
    },
    {
        id: '1-3',
        name: 'Treetop Heights',
        width: 180, time: 220, start: 3, checkpoint: 103, finish: 172, mood: 'sky', music: 'sky',
        gaps: [[13, 40], [46, 70], [76, 100], [106, 140], [146, 164]],
        movers: [[47, 9, 2, 0, -4, 2.8], [61, 7, 2, 5, 0, 2.6], [92, 8, 2, 0, -3, 2.4], [146, 8, 2, 4, 0, 2.4]],
        ropes: [[111, 1, 5, 40, 2.4], [117, 1, 5, 40, 2.6]],
        things: [
            [8, 7, 'ooo'], [8, 5, '?U?'],
            [15, 8, '==='], [15, 7, 'ooo'],
            [20, 6, '~~~'], [25, 8, '==='], [27, 4, 'd'],
            [30, 5, '==='], [30, 4, 'ooo'],
            [35, 7, '==='],
            [43, 9, 'm'],
            [51, 5, '==='], [54, 2, '=='], [55, 1, 'c'], [54, 1, 'X'], [55, 3, 'b'],
            [57, 7, '~~~'], [61, 5, 'oooooo'], [64, 4, 'b'],
            [73, 7, 'H'],
            [77, 8, '~~'], [80, 6, '=='], [83, 4, '~~'], [85, 2, 'd'],
            [87, 6, '===='], [87, 5, 'oooo'], [94, 3, 'd'],
            [96, 5, '==='], [104, 6, 'G'],
            [107, 8, '=='], [114, 4, 'X'], [111, 7, 'oo'], [117, 7, 'oo'],
            [119, 6, '~~'], [122, 4, '=='], [122, 3, 'oo'],
            [125, 6, '=='],
            [128, 7, ground(5)], [128, 8, ground(5)], [130, 6, 'M'], [130, 3, 'X'],
            [135, 6, '==='], [139, 8, '=='],
            [143, 9, 'n'],
            [148, 6, 'oooo'],
            [153, 6, '~~~'], [157, 4, '==='], [157, 3, 'ooo'], [161, 6, '~~~'],
            [167, 9, 'oooo'],
        ],
    },
    {
        id: '1-4',
        name: 'Brick Fortress',
        width: 190, time: 260, start: 2, checkpoint: 90, finish: 180, mood: 'golden', music: 'fortress',
        tint: 0xffdcb0, // golden hour
        gaps: [[60, 62], [120, 123], [150, 152]],
        movers: [],
        secrets: [[84, 6, 4, 4, 'brick']],
        // the trick before the finish: HEAVEN up high is a trap, the HELL door down below is the real way
        signs: [[156, 10, "DON'T BELIEVE\nEVERYTHING..."]],
        doors: [[167, 6, 'HEAVEN', 150], [172, 10, 'HELL', 177]],
        things: [
            [8, 6, 'G&?'], [12, 7, 'BB'],
            [15, 5, `${B(5)}?${B(7)}+${B(12)}`], [17, 4, 'oooooooooo'], [30, 4, 'oooooooo'], [39, 4, 'X'],
            [20, 9, 'm'], [25, 9, 'M'], [30, 9, 'n'], [35, 9, 'M'], [38, 9, 'm'],
            [44, 7, 'CC'], [44, 8, 'CC'], [44, 9, 'CC'],
            [48, 9, '^^^'],
            [53, 6, 'BHB'],
            [59, 6, B(5)], [59, 5, 'ooooo'],
            [66, 9, 'M'], [68, 9, 'm'], [64, 3, 'd'],
            ...pillar(72, 4), [76, 4, B(8)], [78, 9, 'n'], [81, 9, 'm'], [77, 3, 'oooooo'],
            [84, 5, B(5)], [84, 6, '  & B'], [84, 7, ' oooB'], [84, 8, ' oooB'], [88, 9, 'B'], // treasure room (see secrets)
            [95, 7, 'BBB'], [99, 5, 'BBB'], [103, 3, 'BBB'], [107, 2, 'oooooo'], [104, 1, 'X'],
            [97, 9, 'M'], [101, 9, 'm'], [105, 9, 'n'], [114, 3, 'd'],
            [110, 9, '^^^^'], [110, 6, 'BUBB'],
            [120, 8, '~~~~'], [124, 7, 'oo'],
            [127, 6, '?*?'],
            [131, 9, 'm'], [133, 9, 'm'], [135, 9, 'n'], [137, 9, 'm'], [139, 9, 'm'],
            [142, 3, B(5)], [142, 4, 'BX  B'], [142, 5, 'B c B'], [142, 6, B(5)],
            [150, 7, 'ooo'],
            [156, 9, 'M'], [158, 9, 'n'], [160, 4, 'd'],
            [162, 9, 'CCCCCC'], [163, 8, 'CCCCC'], [164, 7, 'CCCC'], [165, 6, 'CCCCC'],
            ...Array.from({ length: 10 }, (_, r) => [175, r, 'B']), // the wall only a door gets through
        ],
    },
    {
        id: '1-5',
        name: "Yuva's Hill",
        width: 222, time: 400, start: 2, checkpoint: 105, mood: 'dusk', music: 'dusk',
        boss: [194, 220],
        tint: 0xe6c8ff, // dusk
        gaps: [[30, 33], [58, 64], [96, 99], [130, 137], [170, 174]],
        movers: [[130, 9, 2, 6, 0, 3], [170, 8, 2, 3, 0, 2]],
        ropes: [[61, 1, 5, 42, 2.4]],
        secrets: [[39, 6, 1, 2, 'dirt'], [39, 8, 2, 2, 'dirt']],
        things: [
            [8, 6, '?BU'],
            [12, 9, 'm'], [17, 9, 'm'],
            [20, 5, 'b'], [26, 9, '^^'],
            [30, 6, 'oooo'],
            ...hill(35, [1, 2, 3, 3, 4, 4, 3, 2, 1]), [38, 6, 'm'], [40, 2, 'X'],
            [39, 6, '.'], [39, 7, '.'], [39, 8, 'oo'], [39, 9, 'oo'], // secret chamber (see secrets)
            [45, 9, 'n'],
            [48, 5, 'B*B'],
            [53, 9, 'm'],
            [58, 6, 'oo'], [61, 6, 'X'], [63, 6, 'oo'],
            [67, 9, '^^^'],
            [72, 6, '===='], [73, 9, 'n'],
            [78, 4, '==='], [79, 3, 'oo'],
            [84, 9, 'm'],
            [90, 4, 'd'],
            [96, 8, '~~~~'], [96, 6, 'oooo'],
            [100, 6, 'BHB'],
            [109, 6, '?&G'],
            [112, 9, 'n'], [115, 9, '^^'], [119, 5, 'b'],
            ...pillar(122, 2, 3), ...pillar(126, 4, 3), [127, 5, 'm'],
            [130, 7, 'oooooooo'],
            [142, 9, 'm'], [146, 9, 'n'],
            [149, 9, '^^'], [150, 3, 'd'], [152, 6, '?&?'], // a heart before the last stretch
            [156, 6, '==='], [160, 3, '==='], [161, 2, 'c'], [162, 0, 'X'],
            [165, 9, 'm'],
            [170, 6, 'ooo'],
            [178, 6, 'B+B'], ...shape(181, 1, HEART),
            [184, 9, 'n'],
            ...stairsUp(186, 4, 1),
        ],
    },
];

// ---------------------------------------------------------------------------------------------
// World 2: the Crystal Cave, for two phones. Yuva has taken Kitty; Janani and Janika go together.
// Extra pieces (co-op only):
//   `plates`   pressure plates: [column, row she stands on, id]. Pressed while either twin stands on one.
//   `gates`    crystal gates: [column, top row, width, height, id, mode]. Modes:
//                'hold'   solid, but open while any plate with that id is pressed
//                'once'   solid until every plate with that id is pressed at the same time, then open for good
//                'bridge' not there until every plate with that id is pressed at the same time, then solid for good
//   `barriers` twin crystal walls: [column, top row, height, who]: only that twin ('janani' or 'janika') walks through
//   `pedestals` power pedestals: [column, row she stands on, 'jump' or 'strong']. Touch one to carry that power
//              (jump: a second jump in mid-air; strong: smash boulders R by walking into them)
// A wall taller than one jump (6 tiles) is meant to be climbed by standing on your sister's head.
const column = (col, top, bottom, ch = '#') => Array.from({ length: bottom - top + 1 }, (_, i) => [col, top + i, ch]);

export const COOP_LEVELS = [
    {
        id: '2-1',
        name: 'Crystal Cave',
        width: 122, time: 999, start: 2, checkpoint: 56, finish: 116, mood: 'cave', music: 'cave',
        gaps: [[80, 86]],
        movers: [],
        signs: [[9, 10, 'TOO HIGH?\nSTAND ON YOUR\nSISTER\'S HEAD!'], [27, 10, 'ONE HOLDS\nTHE PLATE,\nONE GOES'],
            [55, 10, 'PINK: JANANI\nBLUE: JANIKA'], [72, 10, 'BOTH PLATES\nAT ONCE!']],
        plates: [[15, 4, 1], [30, 10, 2], [38, 10, 2], [74, 10, 3], [77, 6, 3]],
        gates: [[14, 8, 1, 2, 1, 'hold'], [34, 8, 1, 2, 2, 'hold'], [80, 10, 7, 1, 3, 'bridge']],
        barriers: [[64, 5, 2, 'janani'], [64, 8, 2, 'janika']],
        things: [
            [5, 8, 'oooo'],
            // 1) the wall: one twin climbs on her sister's head to the plate; the plate opens the tunnel below
            [14, 4, '###'], [14, 5, '###'], [14, 6, '###'], [14, 7, '###'], [14, 3, ' o '],
            [20, 8, 'ooo'], [23, 9, 'm'],
            // 2) a pillar with a gate at the bottom; plates on both sides
            ...column(34, 0, 7), [31, 7, 'ooo'], [36, 7, 'ooo'],
            [42, 7, '==='], [43, 6, 'ooo'], [46, 9, 'M'], [49, 7, '~~~'], [50, 6, 'oo'],
            // 3) twin crystals: the pink way up high is Janani's, the blue way below is Janika's
            ...column(64, 0, 4), [64, 7, '#'], [60, 7, '===='], [65, 7, '==='], [61, 6, 'ooo'], [66, 9, 'ooo'],
            // 4) two plates at once make a bridge over the pit
            [76, 6, '==='], [80, 8, 'ooooooo'],
            [90, 9, 'm'], [94, 7, '===='], [95, 6, 'oo'], [100, 9, 'n'], [104, 8, 'oooo'], [109, 9, 'M'],
        ],
    },
    {
        id: '2-2',
        name: 'Echo Tunnels',
        width: 142, time: 999, start: 2, checkpoint: 66, finish: 136, mood: 'cave', music: 'cave',
        gaps: [[90, 96]],
        movers: [],
        signs: [[4, 10, 'TAKE ONE\nPOWER EACH'], [44, 10, 'SWAP POWERS\nHERE IF\nYOU NEED TO']],
        pedestals: [[7, 10, 'jump'], [10, 10, 'strong'], [47, 10, 'jump'], [50, 10, 'strong']],
        plates: [[31, 3, 1], [60, 10, 2], [74, 10, 2], [87, 10, 3], [99, 10, 3]],
        gates: [[30, 8, 1, 2, 1, 'hold'], [70, 8, 1, 2, 2, 'hold'], [90, 10, 7, 1, 3, 'bridge']],
        things: [
            [14, 8, 'oooo'], [17, 9, 'm'],
            // boulders: only the strong twin can smash through
            ...column(21, 0, 5), ...column(21, 6, 9, 'R'), [24, 8, 'ooo'],
            // a ledge too high even with a boost: the jumping twin double-jumps up to the plate
            [30, 3, '###'], [30, 4, '###'], [30, 5, '###'], [30, 6, '###'], [30, 7, '###'], [30, 2, ' o '],
            [36, 9, 'M'], [39, 7, '==='], [40, 6, 'oo'],
            // a plate buried in boulders opens the gate ahead
            [59, 9, 'R'], [61, 9, 'R'], [59, 8, 'RRR'],
            ...column(70, 0, 7), [72, 7, 'ooo'],
            [78, 9, 'n'], [82, 7, '~~~~'], [83, 6, 'ooo'],
            // two plates at once: the jumping twin crosses the pit, then both stand on plates
            [91, 8, 'ooooo'],
            [104, 9, 'm'], [108, 7, '==='], [109, 6, 'oo'], [112, 9, 'RR'], [113, 8, 'R'], [118, 9, 'M'], [124, 8, 'oooo'],
        ],
    },
    {
        id: '2-3',
        name: 'Crystal Falls',
        width: 152, time: 999, start: 2, checkpoint: 70, finish: 146, mood: 'cave', music: 'cave',
        gaps: [[18, 23], [100, 108]],
        movers: [[101, 8, 3, 4, 0, 3.2]],
        ropes: [[20, 1, 5, 40, 2.6]],
        signs: [[26, 10, 'HELP EACH\nOTHER ACROSS']],
        pedestals: [[5, 10, 'jump'], [8, 10, 'strong'], [74, 10, 'jump'], [77, 10, 'strong']],
        plates: [[40, 6, 1], [47, 10, 2], [116, 10, 3], [125, 5, 3]],
        gates: [[45, 7, 1, 3, 1, 'hold'], [48, 3, 1, 3, 2, 'hold'], [128, 6, 1, 4, 3, 'once']],
        barriers: [[30, 4, 2, 'janani'], [30, 8, 2, 'janika']],
        things: [
            [12, 8, 'oooo'], [20, 6, 'ooo'],
            // two lanes: Janani's up on the shelf, Janika's down below; each opens the other's gate
            [25, 6, '====='], // the step up to Janani's pink doorway
            ...column(30, 0, 3), [30, 6, '#'], [30, 7, '#'], [31, 6, '=================='], ...column(48, 0, 2),
            [33, 5, 'oooo'], [36, 9, 'ooo'], [42, 9, 'm'],
            [52, 9, 'M'], [56, 7, '==='], [57, 6, 'ooo'], [62, 9, 'n'], [66, 8, 'oooo'],
            [82, 9, 'RR'], [83, 8, 'R'], [88, 7, '###'], [88, 6, '###'], [88, 5, '###'], [89, 4, 'X'],
            [93, 9, 'm'], [96, 8, 'ooo'],
            [103, 6, 'ooooo'],
            [112, 9, 'M'], [124, 5, '==='], [124, 6, '   '], ...column(128, 0, 5),
            [131, 8, 'oooo'], [136, 9, 'n'], [140, 7, '==='], [141, 6, 'oo'],
        ],
    },
    {
        id: '2-4',
        name: "Yuva's Crystal Lair",
        width: 70, time: 999, start: 2, checkpoint: 10, mood: 'cave', music: 'cave',
        boss: [30, 66], coopBoss: true,
        gaps: [],
        movers: [],
        signs: [[20, 10, 'ONE HOLDS A PLATE\nTO BREAK HIS SHIELD,\nONE STOMPS!']],
        plates: [[33, 10, 9], [63, 10, 9]],
        things: [
            [6, 8, 'oooo'], [12, 9, 'm'], [16, 7, '==='], [17, 6, 'oo'], [24, 8, 'oooo'],
        ],
    },
];


// Turn a level's lists into a grid of letters: grid[row][col], ' ' for empty, '#' for ground.
// A short, plain map for testing two-phone play: flat ground with one of each thing that has to
// match on both phones (gems, a breakable block, a gift, two enemies, a moving platform, one small gap).
// Picked from the PLAY TOGETHER room; it never shows up on the world map or in progress.
export const TEST_LEVEL = {
    id: 'TEST',
    name: 'Test Field',
    width: 60, time: 999, start: 3, checkpoint: 30, finish: 54, mood: 'day',
    gaps: [[40, 42]],
    movers: [[40, 8, 2, 3, 0, 2.5]],
    things: [
        [8, 9, 'ooooo'],
        [14, 6, 'B?BUB'],
        [22, 9, 'm'],
        [26, 6, 'ooo'],
        [34, 9, 'M'],
        [44, 6, 'oooo'],
        [48, 9, 'n'],
    ],
};

export function buildGrid(level) {
    const rows = 12;
    const grid = Array.from({ length: rows }, () => Array(level.width).fill(' '));
    const inGap = (c) => level.gaps.some(([a, b]) => c >= a && c <= b);
    for (let c = 0; c < level.width; c++) {
        if (!inGap(c)) grid[10][c] = grid[11][c] = '#';
    }
    for (const [col, row, letters] of level.things) {
        [...letters].forEach((ch, i) => {
            if (ch !== ' ' && grid[row] && col + i < level.width) grid[row][col + i] = ch === '.' ? ' ' : ch;
        });
    }
    return grid;
}
