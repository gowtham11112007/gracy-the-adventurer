import * as Phaser from 'phaser';
import { LEVELS, COOP_LEVELS, TEST_LEVEL, buildGrid } from '../levels.js';
import Mechanisms from '../mechanisms.js';
import { TILE, FONT, OUTFITS, JANIKA_OUTFITS, janikaLook, PHYSICS, HERO_FRAMES, ROPE_FRAMES, SCORE, NAMES } from '../config.js';
import Player from '../objects/Player.js';
import Enemy from '../objects/Enemy.js';
import Kitty from '../objects/Kitty.js';
import Boss from '../objects/Boss.js';
import { sfx } from '../sfx.js';
import { music } from '../music.js';
import { writeSave } from '../save.js';
import { iris, buzz } from '../transitions.js';
import Coop from '../coop.js';
import { net } from '../net.js';

const BLOCK_TEXTURE = { R: 'boulder', '~': 'tile_dirt_block', B: 'tile_brick', C: 'tile_crate', '=': 'tile_grass_float', H: 'tile_gift_used', '?': 'tile_gift', '+': 'tile_gift', '*': 'tile_gift', '&': 'tile_gift', U: 'tile_gift', G: 'tile_gift' };
const GIFT_CONTENT = { '?': 'gem', '+': 'cupcake', '*': 'star', '&': 'heart', U: 'balloon', G: 'magnet' };
const POWERUP_TEXTURE = { cupcake: 'cupcake', star: 'star', heart: 'heart', balloon: 'balloon_pink', magnet: 'star_lucky' };
const FAKE_TEXTURE = { F: 'tile_brick', f: 'ground_dirt' }; // look solid, but you walk right through
const ENEMY_KIND = { m: 'mushroom', M: 'hopper', b: 'bee', d: 'diver', n: 'snail' };
const GROUND_Y = 10 * TILE; // top of the ground
const freshState = () => ({ maxHearts: 4, lives: 7, gems: 0, score: 0 }); // 7 lives and 4 hearts: friendly for new players

// One playable level: builds the world from levels.js and runs the gameplay.
export default class Level extends Phaser.Scene {
    constructor() {
        super('Level');
    }

    init(data) {
        this.levelIndex = data.level ?? 0;
        this.def = this.levelIndex === 'test' ? TEST_LEVEL : (data.coop ? COOP_LEVELS : LEVELS)[this.levelIndex]; // World 2 is two-phone only
        // lives, gems and score carry over from level to level in one play session
        this.state = data.state ?? freshState();
        Object.assign(this.state, { hearts: this.state.maxHearts, candle: false, time: this.def.time, world: this.def.id });
        this.respawn = data.respawn ?? null;   // set once the checkpoint is reached
        this.isCoop = !!data.coop;              // two-phone play with her twin
        this.started = false;
        this.ended = false;
        this.dying = false;
        this.lastBump = 0;
        this.boss = null;
        this.doorBusy = false;
        this.lastSafe = null;   // last steady ground she stood on
        this.crumbleCells = null;
        this.arena = null;        // only the boss level has one
        this.bossStarted = false; // the fight starts again after a respawn
        this.crystalsNow = [];   // crystals picked up this run
        this.combo = 0;          // enemies stomped in a row without touching the ground
    }

    create() {
        const def = this.def;
        this.grid = buildGrid(def);
        this.worldW = def.width * TILE;
        this.worldH = 12 * TILE;
        this.solidCells = new Set();
        this.save = this.registry.get('save');

        this.physics.world.gravity.y = PHYSICS.gravity;
        this.physics.world.setBounds(0, -600, this.worldW, this.worldH + 1000);
        this.physics.world.setBoundsCollision(true, true, false, false);

        this.cave = def.mood === 'cave'; // World 2: the Crystal Cave look
        this.bg = this.add.tileSprite(0, 0, this.scale.width, this.scale.height, this.tx('bg_meadow_wide'))
            .setOrigin(0).setScrollFactor(0).setDepth(-10);
        if (def.tint) this.bg.setTint(def.tint);
        this.fitBackground();
        this.scale.on('resize', this.fitBackground, this);
        this.events.once('shutdown', () => this.scale.off('resize', this.fitBackground, this));

        this.solids = this.physics.add.staticGroup();
        this.hazards = this.physics.add.staticGroup();
        this.items = this.physics.add.group({ allowGravity: false });
        this.powerups = this.physics.add.group();
        this.movers = this.physics.add.group({ allowGravity: false, immovable: true });
        this.enemies = this.add.group();
        this.bombs = this.physics.add.group();
        this.fakes = [];
        this.makeEffects();

        this.buildTerrain();
        this.buildThings();
        this.buildSecrets();
        this.buildMovers();
        this.buildRopes();
        this.buildDoors();
        this.decorate();
        this.buildCheckpoint();
        if (def.boss) this.buildArena();
        else this.buildFinish();
        this.buildAtmosphere(def.mood || 'day');

        const startX = this.respawn ? this.respawn.x : def.start * TILE + TILE / 2;
        // two-phone play: this phone is Janani or Janika; Kitty has been taken by Yuva
        const skin = this.isCoop && net.me === 'janika' ? this.save.janikaOutfit || 'janika' : this.save.outfit;
        this.player = new Player(this, startX, GROUND_Y, skin);
        this.kitty = this.isCoop ? null : new Kitty(this, this.player);
        this.coop = this.isCoop ? new Coop(this) : null;
        const d = this.def;
        this.mech = d.plates || d.gates || d.barriers || d.pedestals ? new Mechanisms(this) : null;
        // dust puffs when Janani jumps and lands
        const onJump = (p) => this.fx.dust.explode(8, p.x, p.y);
        const onLand = (p, speed) => {
            this.combo = 0;
            if (speed > 380) this.fx.dust.explode(speed > 800 ? 14 : 8, p.x, p.y);
        };
        this.events.on('player-jump', onJump);
        this.events.on('player-land', onLand);
        const onAirJump = (p) => this.fx.sparkle.explode(16, p.x, p.y - 20);
        this.events.on('player-airjump', onAirJump);
        this.events.once('shutdown', () => {
            this.events.off('player-jump', onJump);
            this.events.off('player-land', onLand);
            this.events.off('player-airjump', onAirJump);
        });
        this.hint = this.add.text(0, 0, '!', { fontFamily: FONT, fontSize: 26, color: '#ffe14d', stroke: '#3b2440', strokeThickness: 6 })
            .setOrigin(0.5, 1).setDepth(9).setVisible(false);
        this.tweens.add({ targets: this.hint, scale: 1.25, duration: 300, yoyo: true, repeat: -1 });
        this.dustTimer = 0;
        this.physics.add.collider(this.player, this.solids, this.onHeadBump, null, this);
        this.physics.add.collider(this.player, this.movers);
        this.physics.add.collider(this.enemies, this.solids);
        this.physics.add.collider([this.powerups], [this.solids, this.movers]);
        this.physics.add.overlap(this.player, this.items, this.collect, null, this);
        this.physics.add.overlap(this.player, this.powerups, this.collect, null, this);
        this.physics.add.overlap(this.player, this.enemies, this.onEnemy, null, this);
        this.physics.add.overlap(this.player, this.hazards, this.onHazard, null, this);
        this.physics.add.collider(this.bombs, this.solids, (bomb) => this.armBomb(bomb));
        this.physics.add.overlap(this.player, this.bombs, (pl, bomb) => this.explode(bomb));

        const cam = this.cameras.main;
        cam.setBounds(0, 0, this.worldW, this.worldH).setBackgroundColor('#54b9fd'); // same blue as the top of the sky picture
        cam.startFollow(this.player, true, 0.1, 0.12, -150, 0);
        this.following = true;

        this.keys = this.input.keyboard.addKeys('LEFT,RIGHT,UP,SPACE,A,D,W,ESC,P');
        if (!this.scene.isActive('Hud')) this.scene.launch('Hud');
        this.scene.bringToTop('Hud');

        // countdown clock, one tick per second while playing
        this.clock = this.time.addEvent({ delay: 1000, loop: true, callback: this.tickClock, callbackScope: this });

        this.showIntroCard();
    }

    // the cave theme has its own version of some textures (cave_ground_top...)
    tx(key) {
        return this.cave && this.textures.exists(`cave_${key}`) ? `cave_${key}` : key;
    }

    // which ground-top tile: meadow grass alternates; cave rock gets a crystal cluster now and then
    topFrame(c) {
        return this.cave ? ((c * 7) % 5 === 0 ? 1 : 0) : c % 2;
    }

    hud() {
        return this.scene.isActive('Hud') ? this.scene.get('Hud') : null;
    }

    fitBackground() {
        const { width, height } = this.scale;
        this.bg.setSize(width, height);
        // high in the treetops: push the meadow picture down so we mostly see sky
        this.bg.y = this.def.mood === 'sky' ? height * 0.42 : 0;
        const s = height / this.textures.get(this.tx('bg_meadow_wide')).getSourceImage().height;
        this.bg.setTileScale(s, s);
    }

    // "WORLD 1-1" card on black with Janani and her lives, like the classics
    showIntroCard() {
        this.physics.pause();
        const { width: w, height: h } = this.scale;
        const card = this.add.container(0, 0).setScrollFactor(0).setDepth(100);
        card.add(this.add.rectangle(0, 0, w, h, 0x000000).setOrigin(0));
        card.add(this.add.text(w / 2, h * 0.36, `WORLD ${this.def.id}`, { fontFamily: FONT, fontSize: 34, color: '#ffffff' }).setOrigin(0.5));
        card.add(this.add.text(w / 2, h * 0.36 + 50, this.def.name.toUpperCase(), { fontFamily: FONT, fontSize: 16, color: '#f5c542' }).setOrigin(0.5));
        card.add(this.add.sprite(w / 2 - 50, h * 0.66, this.player.tex, 0).setScale(0.6).setOrigin(0.5, 1));
        const who = this.coop ? `& ${this.coop.partnerName.toUpperCase()}` : `x  ${this.state.lives}`; // two phones: no lives
        card.add(this.add.text(w / 2 + 10, h * 0.6, who, { fontFamily: FONT, fontSize: 24, color: '#ffffff' }).setOrigin(0, 0.5));
        music.stop();
        this.time.delayedCall(1900, () => {
            card.destroy();
            const cam = this.cameras.main;
            iris(this, { x: this.player.x - cam.scrollX, y: this.player.y - 60 - cam.scrollY, open: true, ms: 700 });
            this.physics.resume();
            this.started = true;
            music.play(this.def.music || 'meadow');
        });
    }

    // ------------------------------------------------------------------ building ---
    buildTerrain() {
        const g = this.grid;
        for (let r = 0; r < g.length; r++) {
            let runStart = -1;
            for (let c = 0; c <= this.def.width; c++) {
                const ground = c < this.def.width && g[r][c] === '#';
                if (ground) {
                    this.solidCells.add(`${c},${r}`);
                    if (r === 0 || g[r - 1][c] !== '#') {
                        // grass strip: its tufts poke above the tile row, frames alternate for variety
                        this.add.image(c * TILE, (r + 1) * TILE, this.tx('ground_top'), this.topFrame(c)).setOrigin(0, 1).setDepth(2);
                    } else {
                        this.add.image(c * TILE, r * TILE, this.tx('ground_dirt')).setOrigin(0).setDepth(2);
                    }
                    if (runStart < 0) runStart = c;
                } else if (runStart >= 0) {
                    // one invisible physics body per stretch of ground
                    this.solids.add(this.add.zone(runStart * TILE, r * TILE, (c - runStart) * TILE, TILE).setOrigin(0));
                    runStart = -1;
                }
            }
        }
        // dark soil inside the pits (not up in the sky)
        for (const [a, b] of this.def.mood === 'sky' ? [] : this.def.gaps) {
            this.add.rectangle(a * TILE, GROUND_Y + 24, (b - a + 1) * TILE, 2 * TILE, 0x2b1d12).setOrigin(0).setDepth(1);
        }
    }

    buildThings() {
        this.grid.forEach((row, r) => row.forEach((ch, c) => {
            const x = c * TILE + TILE / 2;
            const y = r * TILE + TILE / 2;
            if (BLOCK_TEXTURE[ch]) {
                const block = this.solids.create(x, y, this.tx(BLOCK_TEXTURE[ch])).setDepth(3);
                const kind = 'BC'.includes(ch) ? 'break' : ch === 'R' ? 'boulder' : ch === 'H' ? 'hidden' : ch === '~' ? 'crumble' : GIFT_CONTENT[ch] ? 'gift' : 'solid';
                block.setData({ kind, content: GIFT_CONTENT[ch], cell: `${c},${r}` });
                if (kind === 'hidden') {
                    // invisible, and only solid when bumped from below
                    block.setAlpha(0);
                    Object.assign(block.body.checkCollision, { up: false, left: false, right: false });
                } else {
                    this.solidCells.add(`${c},${r}`);
                }
            } else if (FAKE_TEXTURE[ch]) {
                const img = this.add.image(c * TILE, r * TILE, this.tx(FAKE_TEXTURE[ch])).setOrigin(0).setDepth(6.6);
                this.fakes.push({ img, c, r, found: false });
            } else if (ch === '^') {
                const spike = this.hazards.create(x, y, 'tile_spikes').setDepth(3);
                spike.body.setSize(40, 26).setOffset(12, 38); // only the points hurt
            } else if (ch === 'X') {
                // big crystal: three hidden per level; ones found before show faded
                const key = `${c},${r}`;
                const found = (this.save.crystals[this.def.id] || []).includes(key);
                const item = this.items.create(x, y, 'gem_big').setDepth(4).setAlpha(found ? 0.35 : 1);
                item.setData({ kind: 'crystal', key });
                this.tweens.add({ targets: item, y: item.y - 8, angle: 6, duration: 900, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
            } else if (ch === 'o' || ch === 'c') {
                if (ch === 'c' && this.save.candles.includes(this.def.id)) return; // already found
                const item = this.items.create(x, y, ch === 'o' ? 'gem' : 'candle').setDepth(4);
                item.setData('kind', ch === 'o' ? 'gem' : 'candle');
                if (ch === 'o') item.play('gem_spin');
                this.tweens.add({ targets: item, y: item.y - 6, duration: 700, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
            } else if (ENEMY_KIND[ch]) {
                this.enemies.add(new Enemy(this, x, (r + 1) * TILE, ENEMY_KIND[ch]));
            }
        }));
    }

    // secret areas: covered with dirt or brick that looks solid until Janani steps inside
    buildSecrets() {
        for (const [col, row, w, h, look] of this.def.secrets || []) {
            for (let c = col; c < col + w; c++) {
                for (let r = row; r < row + h; r++) {
                    let img;
                    if (look === 'brick') {
                        img = this.add.image(c * TILE, r * TILE, 'tile_brick').setOrigin(0);
                    } else if (r === row && this.grid[r - 1]?.[c] === ' ') {
                        // top of a hill: grass on top so it blends in
                        img = this.add.image(c * TILE, (r + 1) * TILE, this.tx('ground_top'), this.topFrame(c)).setOrigin(0, 1);
                    } else {
                        img = this.add.image(c * TILE, r * TILE, this.tx('ground_dirt')).setOrigin(0);
                    }
                    this.fakes.push({ img: img.setDepth(6.6), c, r, found: false });
                }
            }
        }
    }

    // grass platforms that glide back and forth (or up and down); Janani rides along
    buildMovers() {
        this.moverList = (this.def.movers || []).map(([col, row, width, dx, dy, secs]) => {
            const plat = this.add.tileSprite(col * TILE, row * TILE, width * TILE, TILE, this.tx('tile_grass_float')).setOrigin(0).setDepth(3);
            this.movers.add(plat);
            plat.body.setFriction(1, 0);
            return { plat, x0: plat.x, y0: plat.y, dx: dx * TILE, dy: dy * TILE, period: secs * 2, t: 0 };
        });
    }

    updateMovers(dt) {
        for (const m of this.moverList) {
            m.t += dt / 1000;
            // eased back-and-forth: velocity follows the curve, with a nudge to stay exactly on it
            const w = (2 * Math.PI) / m.period;
            const s = (1 - Math.cos(w * m.t)) / 2;
            const vs = (w * Math.sin(w * m.t)) / 2;
            const body = m.plat.body;
            body.velocity.x = m.dx * vs + (m.x0 + m.dx * s - m.plat.x) * 8;
            body.velocity.y = m.dy * vs + (m.y0 + m.dy * s - m.plat.y) * 8;
        }
    }

    // Trees, bushes and flowers scattered on open grass (same layout every time for a level)
    decorate() {
        const rnd = new Phaser.Math.RandomDataGenerator([this.def.id]);
        const g = this.grid;
        const busy = new Set([this.def.start, this.def.checkpoint, this.def.checkpoint + 1]);
        const free = (c, top) => {
            for (let cc = c - 1; cc <= c + 1; cc++) {
                for (let r = top; r <= 9; r++) if (!g[r] || g[r][cc] !== ' ') return false;
                if (g[10][cc] !== '#') return false;
            }
            return true;
        };
        if (g[10][3] === '#') this.add.image(3 * TILE, GROUND_Y + 14, 'deco_sign').setOrigin(0.5, 1).setDepth(1.9);
        let lastTree = -10;
        let last = -10;
        for (let c = 5; c < this.def.width - 2; c++) {
            if (c - last < 2 || busy.has(c) || Math.abs(c - this.def.finish) < 6) continue;
            const roll = rnd.frac();
            const x = c * TILE + rnd.between(-12, 12);
            let key = null;
            let back = true;
            if (roll < 0.13 && c - lastTree > 6 && free(c, 4)) {
                key = rnd.pick(this.cave ? ['cave_deco_crystal_l', 'cave_deco_crystal_blue'] : ['deco_tree', 'deco_tree_round', 'deco_tree_small']);
                lastTree = c;
            } else if (roll < 0.3 && free(c, 8)) {
                key = rnd.pick(this.cave ? ['cave_deco_crystal_m', 'cave_deco_crystal_blue'] : ['deco_bush', 'deco_bush_tall', 'deco_bush_flowers']);
            } else if (roll < 0.48 && free(c, 9)) {
                key = rnd.pick(this.cave ? ['cave_deco_crystal_s'] : ['deco_flowers_yellow', 'deco_flowers_purple', 'deco_tuft', 'deco_tuft2']);
                back = false;
            } else if (roll < 0.53 && free(c, 9)) {
                key = this.cave ? 'boulder' : rnd.pick(['deco_rock', 'deco_rock2']);
            }
            if (!key) continue;
            last = c;
            // back items are planted behind the grass strip, small ones stand in front of it
            this.add.image(x, GROUND_Y + (back ? 18 : 10), key).setOrigin(0.5, 1).setDepth(back ? 1.9 : 2.1);
        }
    }

    // balloons tied to a signpost mark the checkpoint
    buildCheckpoint() {
        const x = this.def.checkpoint * TILE + TILE / 2;
        this.add.image(x, GROUND_Y + 14, 'deco_sign').setOrigin(0.5, 1).setDepth(1.9);
        this.checkpointBalloons = this.add.image(x - 6, GROUND_Y - 70, 'balloons').setOrigin(0.5, 1).setDepth(1.95);
        this.tweens.add({ targets: this.checkpointBalloons, y: '-=8', angle: 4, duration: 1200, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
        this.checkpointX = x;
    }

    buildFinish() {
        const x = this.def.finish * TILE + TILE / 2;
        this.gate = this.add.image(x, GROUND_Y + 14, 'finish_gate').setOrigin(0.5, 1).setDepth(1.95);
        this.add.text(x, this.gate.y - this.gate.height * 0.79, 'FINISH', { fontFamily: FONT, fontSize: 26, color: '#c2185b' })
            .setOrigin(0.5).setDepth(1.96);
    }

    makeEffects() {
        const burst = (tint, extra = {}) => this.add.particles(0, 0, 'px', {
            emitting: false, lifespan: 450, speed: { min: 80, max: 220 }, scale: { start: 1.2, end: 0 }, tint, ...extra,
        }).setDepth(8);
        this.fx = {
            sparkle: burst([0xd59cff, 0xffffff, 0xb36bff]),
            stars: burst([0xffe14d, 0xfff3a0], { speed: { min: 150, max: 320 }, lifespan: 380 }),
            bricks: burst([0xb5523b, 0x8e3b2a, 0x9c7a4f], { gravityY: 1200, speed: { min: 200, max: 420 }, lifespan: 800, scale: { start: 2, end: 1.2 } }),
            dust: burst([0xf3e6c8, 0xd9c7a0, 0xffffff], { speed: { min: 30, max: 110 }, angle: { min: 200, max: 340 }, gravityY: -40, lifespan: 420, scale: { start: 1.6, end: 0 } }),
            boom: burst([0xffb347, 0xff6b3d, 0xffe14d, 0x555555], { speed: { min: 120, max: 420 }, lifespan: 600, scale: { start: 3, end: 0 } }),
            confetti: burst([0xff5c8a, 0xffd23f, 0x4fc3f7, 0x7ee081, 0xb36bff], { gravityY: 500, speed: { min: 150, max: 380 }, lifespan: 1400, scale: { start: 1.6, end: 0.8 } }),
            shield: this.add.particles(0, 0, 'px', {
                lifespan: 500, speed: { min: 10, max: 40 }, scale: { start: 1, end: 0 }, frequency: 70,
                tint: [0xff8fc7, 0xffffff], emitZone: { source: new Phaser.Geom.Rectangle(-24, -120, 48, 110), type: 'random' },
            }).setDepth(7),
        };
        this.fx.shield.stop();
    }

    // a word that floats up from the action ("COMBO x3")
    popText(x, y, text) {
        const t = this.add.text(x, y, text, { fontFamily: FONT, fontSize: 16, color: '#ffe14d', stroke: '#3b2440', strokeThickness: 5 })
            .setOrigin(0.5).setDepth(20).setScale(0.6);
        this.tweens.add({ targets: t, scale: 1, y: y - 40, duration: 250, ease: 'Back.out' });
        this.tweens.add({ targets: t, alpha: 0, delay: 600, duration: 300, onComplete: () => t.destroy() });
    }

    // little "+200" that floats up from where points were earned
    popScore(x, y, points) {
        this.state.score += points;
        const t = this.add.text(x, y, String(points), { fontFamily: FONT, fontSize: 14, color: '#ffffff', stroke: '#000000', strokeThickness: 4 })
            .setOrigin(0.5).setDepth(20);
        this.tweens.add({ targets: t, y: y - 50, alpha: 0, duration: 700, onComplete: () => t.destroy() });
    }

    // -------------------------------------------------------------- game loop ---
    update(time, delta) {
        const p = this.player;
        if (Phaser.Input.Keyboard.JustDown(this.keys.ESC) || Phaser.Input.Keyboard.JustDown(this.keys.P)) this.hud()?.togglePause();
        const touch = this.registry.get('controls');
        const k = this.keys;
        const live = this.started && !this.ended;
        const controls = {
            left: live && (touch.left || k.LEFT.isDown || k.A.isDown),
            right: live && (touch.right || k.RIGHT.isDown || k.D.isDown),
            jump: live && (touch.jump || k.UP.isDown || k.SPACE.isDown || k.W.isDown),
            jumpTap: live && touch.jumpTap,   // a quick tap that started and ended between frames still counts
        };
        touch.jumpTap = false;
        p.update(controls, delta, time);
        if (p.body.blocked.down && Math.abs(p.body.velocity.x) > 220 && (this.dustTimer -= delta) <= 0) {
            this.fx.dust.explode(2, p.x - Math.sign(p.body.velocity.x) * 14, p.y);
            this.dustTimer = 110;
        }
        this.kitty?.update();
        this.coop?.update(delta);
        this.mech?.update();
        this.lookAhead();
        this.updateMagnet(p);
        this.updateSecrets(p);
        this.updateMovers(delta);
        this.updateRopes(delta);
        this.updateDoors(p);
        this.noteSafeGround(p);
        this.enemies.getChildren().forEach((e) => e.update(delta));
        this.boss?.update(delta);
        this.superKitty(delta);
        this.drawBossShield();

        this.bg.tilePositionX = (this.cameras.main.scrollX * 0.3) / this.bg.tileScaleX;
        this.fx.shield.setPosition(p.x, p.y);
        if (p.shield && !this.fx.shield.emitting) this.fx.shield.start();
        if (!p.shield && this.fx.shield.emitting) this.fx.shield.stop();

        if (this.ended || this.dying) return;
        if (!this.respawn && p.x >= this.checkpointX) this.reachCheckpoint();
        const sisterIn = !this.coop || this.coop.partner.x > (this.arena?.left ?? 0) + 96;
        if (this.arena && !this.bossStarted && p.x > this.arena.left + 96 && sisterIn) this.startBoss();
        if (p.y > this.worldH + 80) this.fellInPit();
        if (p.x >= this.gate.x) {
            if (this.coop) this.coop.reachGate(); // both twins have to get there
            else this.finish();
        }
    }

    tickClock() {
        if (!this.started || this.ended || this.dying || this.coop) return; // no clock in two-phone play
        this.state.time--;
        if (this.state.time === 60) this.hud()?.banner('HURRY UP!', '', 1500);
        if (this.state.time <= 0) {
            this.hud()?.banner("TIME'S UP!", '', 1500);
            this.die();
        }
    }

    reachCheckpoint() {
        this.respawn = { x: this.checkpointX, y: GROUND_Y };
        sfx.checkpoint();
        this.fx.confetti.explode(30, this.checkpointX, GROUND_Y - 160);
        this.tweens.add({ targets: this.checkpointBalloons, scale: 1.25, duration: 160, yoyo: true });
        this.hud()?.banner('CHECKPOINT', '', 1200);
    }

    // dirt block shakes for a moment after Janani steps on it, drops away, and comes back later
    crumble(block) {
        if (block.getData('falling')) return;
        block.setData('falling', true);
        const home = { x: block.x, y: block.y };
        this.tweens.add({ targets: block, x: home.x + 3, duration: 50, yoyo: true, repeat: 4 });
        this.time.delayedCall(450, () => {
            block.body.enable = false;
            this.solidCells.delete(block.getData('cell'));
            this.fx.dust.explode(10, block.x, block.y);
            this.tweens.add({ targets: block, y: home.y + 320, alpha: 0, angle: 20, duration: 600, ease: 'Quad.in' });
            this.time.delayedCall(4000, () => {
                block.setPosition(home.x, home.y).setAngle(0).setAlpha(0);
                block.body.enable = true;
                block.refreshBody();
                this.solidCells.add(block.getData('cell'));
                block.setData('falling', false);
                this.tweens.add({ targets: block, alpha: 1, duration: 300 });
            });
        });
    }

    // sky, light and weather for each level: drifting clouds, hazy distant trees, foreground grass, particles
    buildAtmosphere(mood) {
        const rnd = new Phaser.Math.RandomDataGenerator([`${this.def.id}-sky`]);
        const span = this.worldW * 0.4 + this.scale.width;
        if (mood === 'dusk') {
            this.add.image(this.scale.width * 0.78, 110, 'moon').setScrollFactor(0.05, 0).setDepth(-9).setAlpha(0.9);
        }
        if (mood === 'cave') return this.buildCaveAtmosphere(rnd);
        // clouds at a few distances, slowly drifting
        const clouds = mood === 'sky' ? 18 : 10;
        for (let i = 0; i < clouds; i++) {
            const far = rnd.frac();
            const c = this.add.image(rnd.between(0, span), rnd.between(30, mood === 'sky' ? 520 : 260), rnd.pick(['cloud_big', 'cloud_small']))
                .setScrollFactor(0.15 + far * 0.35, 0).setDepth(-8).setScale(0.7 + far * 0.6).setAlpha(0.55 + far * 0.3);
            if (this.def.tint) c.setTint(this.def.tint);
            this.tweens.add({ targets: c, x: c.x + (mood === 'windy' ? 900 : 300), duration: rnd.between(40000, 70000), repeat: -1, yoyo: true });
        }
        if (mood !== 'sky') {
            // a row of faded trees on the horizon, moving slower than the ground
            for (let x = 0; x < span; x += rnd.between(110, 260)) {
                const t = this.add.image(x, GROUND_Y + 20, rnd.pick(['deco_tree', 'deco_tree_round', 'deco_tree_small']))
                    .setOrigin(0.5, 1).setScrollFactor(0.5, 1).setDepth(-5).setScale(rnd.realInRange(1.1, 1.6)).setAlpha(0.55);
                t.setTint(this.def.tint ?? 0xb8d4e8);
            }
        } else {
            // up in the treetops: clouds drifting below the platforms too
            for (let x = 0; x < this.worldW; x += rnd.between(300, 600)) {
                this.add.image(x, this.worldH - rnd.between(20, 90), 'cloud_big').setScale(rnd.realInRange(2, 3)).setDepth(1).setAlpha(0.9);
            }
        }
        // foreground grass and flowers in front of Janani's feet, for depth
        for (let c = 4; c < this.def.width - 2; c += rnd.between(6, 14)) {
            if (this.grid[10][c] !== '#' || this.grid[9][c] !== ' ') continue;
            this.add.image(c * TILE + rnd.between(-20, 20), GROUND_Y + 30, rnd.pick(['deco_tuft', 'deco_tuft2', 'deco_flowers_yellow', 'deco_flowers_purple']))
                .setOrigin(0.5, 1).setDepth(7).setScale(1.25);
        }
        // weather
        const { width: w, height: h } = this.scale;
        const weather = {
            day: { tint: [0xffc4e1, 0xffffff], speedX: { min: 20, max: 60 }, speedY: { min: 20, max: 50 }, frequency: 220, lifespan: 9000, scale: 1 },
            windy: { tint: [0x7ec850, 0xa6dd6a, 0x5aa83a], speedX: { min: -420, max: -260 }, speedY: { min: -20, max: 40 }, frequency: 90, lifespan: 5000, scale: 1.2 },
            sky: { tint: [0xffffff, 0xd8f0ff], speedX: { min: -30, max: 30 }, speedY: { min: -10, max: 10 }, frequency: 300, lifespan: 6000, scale: 0.8 },
            golden: { tint: [0xffe08a, 0xfff3c4], speedX: { min: -15, max: 15 }, speedY: { min: -40, max: -10 }, frequency: 160, lifespan: 7000, scale: 0.7 },
            dusk: { tint: [0xd8ff7a, 0xfff38a], speedX: { min: -25, max: 25 }, speedY: { min: -25, max: 25 }, frequency: 140, lifespan: 5000, scale: 0.8 },
        }[mood];
        this.add.particles(0, 0, 'px', {
            x: { min: mood === 'windy' ? w : 0, max: mood === 'windy' ? w + 40 : w }, y: { min: -20, max: h * 0.8 },
            ...weather, scale: { start: weather.scale, end: weather.scale * 0.6 }, alpha: { start: 0.9, end: 0 }, rotate: { min: 0, max: 360 },
        }).setScrollFactor(0).setDepth(8);
    }

    // inside the Crystal Cave: stalactites overhead, glowing crystals in front, drifting sparkles
    buildCaveAtmosphere(rnd) {
        for (let x = rnd.between(0, 200); x < this.worldW; x += rnd.between(180, 420)) {
            this.add.image(x, -10, 'stalactite').setOrigin(0.5, 0).setDepth(-2).setScale(rnd.realInRange(0.6, 1.3)).setAlpha(0.85);
        }
        for (let c = 4; c < this.def.width - 2; c += rnd.between(7, 15)) {
            if (this.grid[10][c] !== '#' || this.grid[9][c] !== ' ') continue;
            this.add.image(c * TILE + rnd.between(-20, 20), GROUND_Y + 26, rnd.pick(['cave_deco_crystal_s', 'cave_deco_crystal_m']))
                .setOrigin(0.5, 1).setDepth(7).setAlpha(0.95);
        }
        const { width: w, height: h } = this.scale;
        this.add.particles(0, 0, 'px', {
            x: { min: 0, max: w }, y: { min: 0, max: h }, tint: [0xc78bff, 0x8ad8ff, 0xff9ad5],
            speedX: { min: -12, max: 12 }, speedY: { min: -20, max: -5 }, frequency: 180, lifespan: 6000,
            scale: { start: 0.9, end: 0.3 }, alpha: { start: 0, end: 0.9, ease: 'Sine.inOut' },
        }).setScrollFactor(0).setDepth(8);
    }

    // ------------------------------------------------------------- doors & signs ---
    buildDoors() {
        this.doors = (this.def.doors || []).map(([col, row, label, to]) => {
            const x = col * TILE + TILE / 2;
            const y = row * TILE;
            const key = `door_${label.toLowerCase()}`;
            const img = this.add.image(x, y, this.textures.exists(key) ? key : this.placeholderDoor(label)).setOrigin(0.5, 1).setDepth(1.95);
            this.add.text(x, y - img.height - 8, label, {
                fontFamily: FONT, fontSize: 13, color: label === 'HELL' ? '#ff7a59' : '#fff3b0', stroke: '#2a1640', strokeThickness: 5,
            }).setOrigin(0.5, 1).setDepth(1.96);
            return { x, y, to, label };
        });
        for (const [col, row, text] of this.def.signs || []) {
            // Gemini's blank notice board, with the words painted on in the game's font
            const x = col * TILE + TILE / 2;
            const board = this.add.image(x, row * TILE + 6, 'notice_board').setOrigin(0.5, 1).setDepth(1.9);
            this.add.text(x, board.y - board.height + 58, text, {
                fontFamily: FONT, fontSize: 11, color: '#4a2a12', align: 'center', lineSpacing: 6,
            }).setOrigin(0.5).setDepth(1.91);
        }
    }

    // stand-in door until Gemini's door art arrives: an arched door, golden-white or dark red
    placeholderDoor(label) {
        const key = `door_${label.toLowerCase()}_placeholder`;
        if (this.textures.exists(key)) return key;
        const heaven = label === 'HEAVEN';
        const g = this.make.graphics({ x: 0, y: 0 }, false);
        g.fillStyle(heaven ? 0xfff3b0 : 0x3a0a0a).fillRoundedRect(0, 0, 72, 112, { tl: 36, tr: 36, bl: 0, br: 0 });
        g.fillStyle(heaven ? 0xffffff : 0x8a1a12).fillRoundedRect(8, 8, 56, 104, { tl: 28, tr: 28, bl: 0, br: 0 });
        g.fillStyle(heaven ? 0xf5c542 : 0xff7a1a).fillCircle(54, 66, 5);
        g.generateTexture(key, 72, 112).destroy();
        return key;
    }

    // walking into a door takes her through it (the wrong one sends her back)
    updateDoors(p) {
        if (this.doorBusy || p.frozen || !p.body.blocked.down) return;
        const door = this.doors.find((d) => Math.abs(p.x - d.x) < 18 && Math.abs(p.y - d.y) < 10);
        if (!door) return;
        this.doorBusy = true;
        p.frozen = true;
        p.body.setVelocity(0, 0);
        sfx.whoosh();
        const cam = this.cameras.main;
        iris(this, {
            x: p.x - cam.scrollX, y: p.y - 60 - cam.scrollY, open: false, ms: 450,
            onDone: (curtain) => {
                p.body.reset(door.to * TILE + TILE / 2, GROUND_Y);
                this.kitty?.snap();
                cam.centerOn(p.x + 150, cam.midPoint.y);
                curtain.destroy();
                iris(this, { x: this.scale.width / 2, y: this.scale.height / 2, open: true, ms: 450 });
                p.frozen = false;
                this.doorBusy = false;
                const trap = door.to * TILE < door.x;
                if (trap) this.hud()?.banner('TOO GOOD TO BE TRUE!', 'The sign did warn you...', 2000);
                else this.hud()?.banner('THE SIGN WAS RIGHT!', '', 1500);
            },
        });
    }

    // ------------------------------------------------------------------ ropes ---
    buildRopes() {
        this.ropes = (this.def.ropes || []).map(([col, row, len, deg, secs]) => ({
            ax: col * TILE + TILE / 2, ay: row * TILE, len: len * TILE, amp: (deg * Math.PI) / 180,
            w: (2 * Math.PI) / secs, t: Math.random() * secs, cool: 0,
            // Gemini's rope art, stretched to this rope's length and hung from its top end
            img: this.add.image(col * TILE + TILE / 2, row * TILE - 8, 'rope').setOrigin(0.5, 0).setDepth(4.5)
                .setDisplaySize(30, len * TILE + 22),
        }));
    }

    updateRopes(dt) {
        const p = this.player;
        for (const r of this.ropes) {
            r.t += dt / 1000;
            r.cool -= dt;
            r.angle = r.amp * Math.sin(r.w * r.t);
            r.spin = r.amp * r.w * Math.cos(r.w * r.t); // how fast it is swinging (radians per second)
            r.ex = r.ax + Math.sin(r.angle) * r.len;
            r.ey = r.ay + Math.cos(r.angle) * r.len;
            r.img.setRotation(-r.angle);
        }
        if (p.frozen) return;

        if (p.body.blocked.down) p.lastRope = null; // back on the ground: every rope can be grabbed again
        if (!p.hanging && !p.body.blocked.down) {
            // grab: any part of Janani's upper body (hands to waist) comes near the lower part of a rope.
            // The reach is generous on purpose, like rope swings in classic platformers.
            for (const r of this.ropes) {
                if (r.cool > 0 || r === p.lastRope) continue; // not the rope she just let go of
                const dx = r.ex - r.ax;
                const dy = r.ey - r.ay;
                let best = null;
                for (const hy of [p.y - 104, p.y - 80, p.y - 56]) {
                    const t = Phaser.Math.Clamp(((p.x - r.ax) * dx + (hy - r.ay) * dy) / (dx * dx + dy * dy), 0.3, 1);
                    const d = Math.hypot(r.ax + dx * t - p.x, r.ay + dy * t - hy);
                    if (!best || d < best.d) best = { d, t };
                }
                if (best.d < 72) {
                    p.hanging = { rope: r, along: best.t * r.len };
                    p.wantsRelease = false;
                    p.body.setAllowGravity(false);
                    p.body.setVelocity(0, 0);
                    sfx.bump();
                    break;
                }
            }
        }
        if (p.hanging) {
            const { rope: r, along } = p.hanging;
            const hx = r.ax + Math.sin(r.angle) * along;
            const hy = r.ay + Math.cos(r.angle) * along;
            p.body.reset(hx, hy + 100);
            p.pose(p.F.rise);
            p.setFlipX(r.spin < 0);
            // legs: straight on the way back, trailing at the fast bottom, kicked out toward the far end
            const ahead = (r.angle / r.amp) * (r.spin < 0 ? -1 : 1);
            const frame = Math.abs(ahead) < 0.35 ? ROPE_FRAMES.trail : ahead > 0 ? ROPE_FRAMES.kick : ROPE_FRAMES.hang;
            p.ropePose = { x: hx, y: hy, angle: r.angle, frame };
            if (p.wantsRelease) {
                // let go with the rope's swing, plus a hop
                const vx = Phaser.Math.Clamp(Math.cos(r.angle) * r.spin * along * 1.15, -440, 440);
                const vy = Math.min(-Math.sin(r.angle) * r.spin * along, 0) - 640;
                p.hanging = null;
                p.wantsRelease = false;
                p.body.setAllowGravity(true);
                p.body.setVelocity(vx, vy);
                p.jumping = true;
                p.jumpHold = 0;
                p.leapTime = 320;
                r.cool = 450;
                p.lastRope = r;
                sfx.jump();
                this.fx.dust.explode(6, p.x, p.y - 100);
            }
        }
    }

    // ------------------------------------------------------------------- boss ---
    buildArena() {
        const [a, b] = this.def.boss;
        this.arena = { left: a * TILE, right: b * TILE };
        this.gate = { x: Infinity }; // no finish gate: the level ends when Yuva is beaten
        // Janika (or, in World 2, Kitty), trapped in a bubble above the arena
        const jx = this.arena.right - 230;
        this.captive = this.coop ? this.add.sprite(jx, 260, 'kitty').setScale(1.3).setDepth(4).play('kitty_talk')
            : this.add.sprite(jx, 250, janikaLook(this.save.janikaOutfit).tex, 0).setDepth(4);
        this.captiveBubble = this.add.graphics().setDepth(4.1);
        this.captiveBubble.fillStyle(0xff9ad5, 0.22).fillCircle(0, 0, 92).lineStyle(5, 0xffffff, 0.85).strokeCircle(0, 0, 92);
        this.captiveBubble.setPosition(jx, 250);
        this.tweens.add({ targets: [this.captive, this.captiveBubble], y: '-=14', duration: 1200, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
    }

    startBoss() {
        this.bossStarted = true;
        const { left, right } = this.arena;
        // close the arena behind Janani and hold the camera on it
        const wall = (x) => this.solids.add(this.add.zone(x - 32, -600, 32, this.worldH + 600).setOrigin(0));
        wall(left);
        wall(right + 32);
        this.cameras.main.stopFollow();
        this.following = false;
        this.cameras.main.setBounds(left, 0, right - left, this.worldH);
        this.cameras.main.pan((left + right) / 2, this.worldH / 2, 900, 'Sine.easeInOut');
        music.play('boss');
        this.boss = new Boss(this, right - 300, -200, this.arena);
        if (this.coop && !this.coop.host) {
            this.boss.remote = true; // the host's phone runs him; this one shows him
            this.boss.body.setAllowGravity(false);
        }
        if (this.def.coopBoss) this.bossShield = this.add.graphics().setDepth(5.5);
        this.physics.add.collider(this.boss, this.solids);
        this.physics.add.overlap(this.player, this.boss, this.onBoss, null, this);
        this.hud()?.banner(`${NAMES.boss.toUpperCase()}!`, 'Stomp on his head three times!', 2200);
        if (this.kitty) {
            this.kittyPounce = 6000;   // ms until Super Kitty's next pounce on Yuva
            this.kittyBat = 0;         // ms until she can bat away another bomb
            this.time.delayedCall(2600, () => {
                if (this.ended || this.dying) return;
                this.kitty.powerUp();
                this.cameras.main.flash(250, 230, 232, 255);
                sfx.meow();
                sfx.power();
                this.hud()?.banner('SUPER KITTY!', 'She pounces on Yuva and bats bombs away', 2200);
            });
        }
    }

    // Super Kitty's two powers in the Yuva fight
    superKitty(dt) {
        const k = this.kitty;
        const boss = this.boss;
        if (!k?.super || k.busy || !boss || boss.defeated || this.ended || this.dying) return;
        this.kittyBat -= dt;
        // every few seconds she leaps on his head and leaves him dizzy: the perfect moment to stomp
        if ((this.kittyPounce -= dt) <= 0 && boss.body.blocked.down && ['idle', 'windup', 'throw'].includes(boss.mode)) {
            this.kittyPounce = 7000;
            k.dash(boss.x, boss.body.top + 30, 520, () => {
                if (!boss.stun(2400)) return;
                sfx.meow();
                this.fx.stars.explode(16, boss.x, boss.body.top);
                this.cameras.main.shake(120, 0.006);
                this.popText(boss.x, boss.body.top - 40, 'DIZZY!');
            });
        }
    }

    onBoss(player, boss) {
        if (boss.defeated || this.ended || this.dying) return;
        const landing = player.body.velocity.y > 60 && player.body.bottom <= boss.body.top + 40;
        if (landing) {
            player.body.velocity.y = -820;
            if (this.shielded) {
                // World 2: bounced off his crystal shield; her sister has to hold a plate first
                sfx.bump();
                this.hud()?.banner('SHIELD!', 'Stand on a plate to break it', 1000);
                return;
            }
            this.fx.stars.explode(14, boss.x, boss.body.top);
            buzz(this, 60);
            if (boss.remote) return net.send('bossStomp'); // the host's phone counts the hit
            this.stompBoss();
            return;
        }
        if (boss.invuln <= 0) this.hurtPlayer(boss.x);
    }

    // who Yuva goes after: in two-phone play he switches between the twins every few seconds
    bossTarget() {
        if (!this.coop?.partnerHere) return this.player;
        if (this.time.now > (this.targetUntil ?? 0)) {
            this.targetUntil = this.time.now + 3500;
            this.targetSister = !this.targetSister;
        }
        return this.targetSister ? this.coop.partner : this.player;
    }

    // World 2: Yuva's crystal shield is up unless one twin holds a plate
    get shielded() {
        return !!this.def.coopBoss && !(this.mech?.plates.some((pl) => pl.pressed));
    }

    drawBossShield() {
        const g = this.bossShield?.clear();
        if (!g || !this.boss || this.boss.defeated || !this.shielded) return;
        const pulse = 0.25 + Math.sin(this.time.now / 150) * 0.08;
        g.fillStyle(0x8ad8ff, pulse).fillCircle(this.boss.x, this.boss.y - 95, 115);
        g.lineStyle(4, 0xffffff, 0.8).strokeCircle(this.boss.x, this.boss.y - 95, 115);
    }

    // a stomp on Yuva's head that counts (on the host's phone, which runs him)
    stompBoss() {
        const boss = this.boss;
        if (!boss || boss.defeated || this.shielded) return;
        this.popScore(boss.x, boss.body.top - 20, SCORE.boss);
        if (boss.hit()) {
            this.coop && net.send('bossDown');
            this.bossDefeated();
        }
    }

    throwBomb(boss, targetX, tell = true) {
        if (tell && this.coop) net.send('bomb', { x: Math.round(boss.x), y: Math.round(boss.y), tx: Math.round(targetX) });
        const dir = targetX < boss.x ? -1 : 1;
        const bomb = this.bombs.create(boss.x + dir * 60, boss.y - 130, 'bomb').setDepth(6);
        const flight = 1.0;
        bomb.body.setVelocity((targetX - bomb.x) / flight, -520).setAngularVelocity(dir * 360).setBounce(0.25);
        bomb.body.setCircle(22, 2, 2);
        bomb.setData('armed', false);
        sfx.whoosh();
    }

    // a bomb that hits the ground fizzes for a moment, then blows up
    armBomb(bomb) {
        if (bomb.getData('armed')) return;
        bomb.setData('armed', true);
        bomb.body.setDragX(400);
        this.tweens.add({ targets: bomb, scale: 1.25, duration: 120, yoyo: true, repeat: 2 });
        this.time.delayedCall(650, () => this.explode(bomb));
        const k = this.kitty;
        if (k?.super && !k.busy && this.kittyBat <= 0 && Math.abs(bomb.x - this.player.x) < 480) {
            this.kittyBat = 2500;
            bomb.setData('caught', true); // she's got it: it won't go off
            k.dash(bomb.x, bomb.y + 20, 380, () => {
                if (!bomb.active) return;
                this.fx.sparkle.explode(18, bomb.x, bomb.y);
                bomb.destroy();
                sfx.meow();
                this.popText(bomb.x, bomb.y - 40, 'MEOW!');
            });
        }
    }

    explode(bomb) {
        if (!bomb.active || bomb.getData('caught')) return;
        const { x, y } = bomb;
        bomb.destroy();
        this.fx.boom.explode(30, x, y);
        this.cameras.main.shake(200, 0.012);
        sfx.smash();
        buzz(this, 40);
        if (Phaser.Math.Distance.Between(x, y, this.player.x, this.player.y - 56) < 80) this.hurtPlayer(x);
    }

    bossDefeated() { // (also called when the host's phone says Yuva is beaten)
        this.bombs.clear(true, true);
        music.stop();
        sfx.win();
        this.cameras.main.flash(300, 255, 255, 255);
        this.hud()?.banner('YOU BEAT YUVA!', '', 2000);
        this.time.delayedCall(1800, () => this.finish());
    }

    // the camera leans ahead in the direction Janani is facing
    lookAhead() {
        const cam = this.cameras.main;
        if (!this.following) return;
        const target = this.player.flipX ? 150 : -150;
        cam.followOffset.x += (target - cam.followOffset.x) * 0.03;
    }

    // a tiny freeze on impact makes stomps feel punchy
    hitStop(ms) {
        this.physics.world.pause();
        this.time.delayedCall(ms, () => !this.dying && this.physics.world.resume());
    }

    // gem magnet: nearby gems drift toward Janani
    updateMagnet(p) {
        if (p.magnetTime <= 0) return;
        for (const gem of this.items.getChildren()) {
            if (gem.getData('kind') !== 'gem' || gem.getData('taken')) continue;
            const d = Phaser.Math.Distance.Between(gem.x, gem.y, p.x, p.y - 60);
            if (d > 280) continue;
            if (!gem.getData('pulled')) { gem.setData('pulled', true); this.tweens.killTweensOf(gem); }
            gem.x += (p.x - gem.x) * 0.16;
            gem.y += (p.y - 60 - gem.y) * 0.16;
        }
    }

    // fake walls turn see-through once Janani steps into them; Kitty points out secrets nearby
    updateSecrets(p) {
        for (const f of this.fakes) {
            const inside = Math.abs(p.x - (f.c * TILE + TILE / 2)) < 56 && p.y - 112 < (f.r + 1) * TILE && p.y > f.r * TILE;
            f.img.setAlpha(inside || f.found ? 0.35 : 1);
            if (inside && !f.found) {
                // reveal the whole hidden wall it belongs to
                this.fakes.filter((o) => Math.abs(o.c - f.c) <= 3 && Math.abs(o.r - f.r) <= 4).forEach((o) => (o.found = true));
                sfx.oneUp();
                this.hud()?.banner('SECRET ROOM!', '', 1300);
            }
        }
        const near = (x) => Math.abs(x - p.x) < 260;
        const secret = this.fakes.some((f) => !f.found && near(f.c * TILE)) ||
            this.solids.getChildren().some((b) => b.getData && b.getData('kind') === 'hidden' && near(b.x));
        const k = this.kitty;
        if (k) this.hint.setVisible(secret && !p.frozen).setPosition(k.x, k.y - 70);
    }

    isSolidAt(x, y) {
        return this.solidCells.has(`${Math.floor(x / TILE)},${Math.floor(y / TILE)}`);
    }

    // ------------------------------------------------------------ interactions ---
    onHeadBump(player, block) {
        if (!block.getData) return;
        // World 2: with Strength, walking into a boulder smashes it
        if (block.getData('kind') === 'boulder') {
            const side = player.body.touching.left || player.body.touching.right || player.body.blocked.left || player.body.blocked.right;
            if (player.power === 'strong' && (side || player.body.blocked.up)) this.smashBoulder(block, true);
            return;
        }
        if (block.getData('kind') === 'crumble' && player.body.blocked.down && block.body.top >= player.body.bottom - 6) {
            this.crumble(block);
            return;
        }
        if (!player.body.blocked.up) return;
        const kind = block.getData('kind');
        if (!kind || block.body.bottom > player.body.top + 10 || Math.abs(block.x - player.x) > 52) return;
        if (this.time.now - this.lastBump < 200) return; // one block per jump
        this.lastBump = this.time.now;

        this.coop && net.send('block', { cell: block.getData('cell') });
        if (kind === 'break') {
            sfx.smash();
            this.fx.bricks.explode(14, block.x, block.y);
            this.popScore(block.x, block.y, SCORE.brick);
            this.solidCells.delete(block.getData('cell'));
            block.destroy();
            return;
        }
        sfx.bump();
        this.tweens.add({ targets: block, y: block.y - 12, duration: 80, yoyo: true });
        if (kind === 'hidden') {
            // secret block: appears, becomes solid, gives an extra life
            block.setAlpha(1).setData('kind', 'used');
            Object.assign(block.body.checkCollision, { up: true, left: true, right: true });
            this.solidCells.add(block.getData('cell'));
            this.state.lives++;
            sfx.oneUp();
            this.hud()?.banner('SECRET!', '1 UP', 1500);
            return;
        }
        if (kind !== 'gift') return;
        block.setTexture('tile_gift_used').setData('kind', 'used');
        const content = block.getData('content');
        if (content === 'gem') {
            const gem = this.add.sprite(block.x, block.y - TILE, 'gem').play('gem_spin').setDepth(4);
            this.tweens.add({ targets: gem, y: gem.y - 70, alpha: 0, duration: 450, onComplete: () => gem.destroy() });
            this.addGems(1);
            this.popScore(block.x, block.y - TILE, SCORE.gem);
            sfx.gem();
        } else {
            const p = this.powerups.create(block.x, block.y - TILE, POWERUP_TEXTURE[content]).setDepth(4);
            p.setData('kind', content);
            if (content === 'balloon' || content === 'magnet') {
                // floats up out of the box and bobs there, a jump away
                p.body.setAllowGravity(false);
                this.tweens.add({ targets: p, y: block.y - TILE * 1.6, duration: 500, ease: 'Back.out',
                    onComplete: () => this.tweens.add({ targets: p, y: p.y - 10, duration: 800, yoyo: true, repeat: -1, ease: 'Sine.inOut' }) });
            } else {
                // hop off the block (away from Janani) and slide down to the ground where she can reach it
                const away = player.x <= block.x ? 1 : -1;
                p.body.setVelocity(170 * away, -420).setDragX(30).setBounceX(1).setCollideWorldBounds(true);
            }
            sfx.sprout();
        }
    }

    collect(player, item) {
        if (item.getData('taken')) return;
        item.setData('taken', true);
        item.body.enable = false;
        if (this.coop && item.getData('nid')) net.send('take', { id: item.getData('nid') }); // gone on her phone too
        const s = this.state;
        switch (item.getData('kind')) {
            case 'gem':
                this.addGems(1);
                s.score += SCORE.gem;
                sfx.gem();
                this.fx.sparkle.explode(8, item.x, item.y);
                this.hud()?.flyGem(item.x - this.cameras.main.scrollX, item.y - this.cameras.main.scrollY);
                break;
            case 'balloon':
                player.floatTime = 15000;
                this.popScore(item.x, item.y, SCORE.power);
                sfx.power();
                this.hud()?.banner('BALLOON!', 'Jump again in mid-air, hold jump to glide', 1800);
                break;
            case 'magnet':
                player.magnetTime = 15000;
                this.popScore(item.x, item.y, SCORE.power);
                sfx.power();
                this.hud()?.banner('GEM MAGNET!', 'Gems fly to you', 1600);
                break;
            case 'heart':
                s.hearts = Math.min(s.maxHearts, s.hearts + 1);
                this.popScore(item.x, item.y, SCORE.power);
                sfx.power();
                break;
            case 'cupcake':
                player.shield = true;
                this.popScore(item.x, item.y, SCORE.power);
                sfx.power();
                this.hud()?.banner('CUPCAKE SHIELD', 'Survives one hit', 1500);
                break;
            case 'star':
                player.starTime = 8000;
                this.popScore(item.x, item.y, SCORE.power);
                sfx.power();
                this.hud()?.banner('STAR POWER', '', 1200);
                break;
            case 'crystal': {
                const key = item.getData('key');
                const list = (this.save.crystals[this.def.id] ||= []);
                if (!list.includes(key)) list.push(key);
                writeSave(this.save);
                this.crystalsNow.push(key);
                this.popScore(item.x, item.y, SCORE.crystal);
                sfx.oneUp();
                this.fx.sparkle.explode(20, item.x, item.y);
                this.hud()?.banner('BIG CRYSTAL!', `${list.length} of 3 in this level`, 1400);
                break;
            }
            case 'candle':
                s.candle = true;
                if (!this.save.candles.includes(this.def.id)) this.save.candles.push(this.def.id);
                writeSave(this.save);
                this.popScore(item.x, item.y, SCORE.candle);
                sfx.oneUp();
                this.hud()?.banner('BIRTHDAY CANDLE!', `${this.save.candles.length} of 5 found`);
                break;
        }
        this.tweens.add({ targets: item, y: item.y - 40, alpha: 0, scale: 1.4, duration: 300, onComplete: () => item.destroy() });
    }

    addGems(n) {
        this.state.gems += n;
        if (this.state.gems >= 100) {
            this.state.gems -= 100;
            this.state.lives++;
            sfx.oneUp();
            this.hud()?.banner('1 UP', '100 gems');
        }
    }

    onEnemy(player, enemy) {
        if (enemy.dead || this.ended || this.dying) return;
        if (player.starTime > 0) {
            enemy.defeat();
            if (this.coop) net.send('kill', { id: enemy.nid });
            sfx.stomp();
            this.popScore(enemy.x, enemy.y - 60, SCORE.stomp);
            this.fx.stars.explode(10, enemy.x, enemy.y - 30);
            return;
        }
        const landing = player.body.velocity.y > 60 && player.body.bottom <= enemy.body.top + 34; // generous stomps
        if (landing && enemy.stompable) {
            enemy.defeat(true);
            if (this.coop) net.send('kill', { id: enemy.nid });
            this.hitStop(60);
            buzz(this, 25);
            player.body.velocity.y = -PHYSICS.stompBounce;
            // chain stomps without landing: 200, 400, 800... and an extra life at 6 in a row
            this.combo++;
            sfx.stomp(this.combo);
            this.popScore(enemy.x, enemy.y - 60, Math.min(SCORE.stomp * 2 ** (this.combo - 1), 3200));
            if (this.combo >= 2) this.popText(enemy.x, enemy.y - 100, `COMBO x${this.combo}`);
            if (this.combo === 6) { this.state.lives++; sfx.oneUp(); this.hud()?.banner('1 UP', 'Six in a row!', 1400); }
            this.fx.stars.explode(10, enemy.x, enemy.body.top);
            return;
        }
        this.hurtPlayer(enemy.x);
        if (landing) player.body.velocity.y = -PHYSICS.stompBounce; // bounced off the spiky snail
    }

    onHazard(player, spike) {
        this.hurtPlayer(spike.x);
        if (!this.dying) player.body.velocity.y = -650;
    }

    hurtPlayer(fromX) {
        const p = this.player;
        if (this.ended || this.dying || p.safe) return;
        sfx.hurt();
        p.knockback(fromX);
        if (p.shield) {
            p.shield = false; // the cupcake takes the hit
            return;
        }
        this.state.hearts--;
        buzz(this, 90);
        this.cameras.main.shake(150, 0.006);
        if (this.state.hearts <= 0) this.die();
    }

    die() {
        if (this.dying) return;
        this.dying = true;
        const p = this.player;
        p.frozen = true;
        p.pose(p.F.hurt);
        p.hanging = null;
        p.body.setAllowGravity(true);
        // classic: pop up, then fall straight through everything
        p.body.checkCollision.none = true;
        p.body.setVelocity(0, -720);
        p.setDepth(30);
        this.cameras.main.stopFollow();
        this.following = false;
        this.tweens.add({ targets: p, angle: 25, duration: 900 });
        music.stop();
        sfx.lose();
        if (!this.coop) this.state.lives--; // no lives to lose in two-phone play
        buzz(this, 250);
        const { width: w, height: h } = this.scale;
        const cam = this.cameras.main;
        const fx = Phaser.Math.Clamp(p.x - cam.scrollX, 80, w - 80);
        this.time.delayedCall(900, () => iris(this, {
            x: fx, y: h * 0.5, open: false, ms: 650,
            onDone: (curtain) => {
                // two-phone play: the level keeps going for her sister, so pop back in at the checkpoint
                if (this.coop) return this.respawnInPlace(curtain);
                if (this.state.lives < 0) {
                    this.gameOver();
                    return;
                }
                // back to the checkpoint (or the start), with a fresh clock and the intro card
                this.scene.restart({ level: this.levelIndex, state: this.state, respawn: this.respawn });
            },
        }));
    }

    // falling into a pit costs one heart and puts her back on the last safe ground (a whole life only on the last heart)
    fellInPit() {
        const p = this.player;
        if (this.state.hearts <= 1 || !this.lastSafe || this.dying) return this.die();
        this.state.hearts--;
        sfx.hurt();
        buzz(this, 90);
        p.hanging = null;
        p.body.setAllowGravity(true);
        p.body.reset(this.lastSafe.x, this.lastSafe.y);
        p.invulnTime = 1500;
        p.lastRope = null;
        this.kitty?.snap();
        this.cameras.main.flash(200, 255, 255, 255);
        this.hud()?.banner('OOPS!', 'Kitty pulled you back up', 1200);
    }

    // remember where she last stood on solid, steady ground (for pit rescues)
    noteSafeGround(p) {
        if (!p.body.blocked.down || p.hanging || p.frozen) return;
        const y = p.body.bottom + 8;
        const cell = (x) => `${Math.floor(x / TILE)},${Math.floor(y / TILE)}`;
        this.crumbleCells ??= new Set(this.solids.getChildren().filter((b) => b.getData?.('kind') === 'crumble').map((b) => b.getData('cell')));
        const safe = (x) => this.isSolidAt(x, y) && !this.crumbleCells.has(cell(x));
        if (safe(p.body.left - 56) && safe(p.body.right + 56)) this.lastSafe = { x: p.x, y: p.y }; // a tile of ground each side
    }

    // back to the checkpoint without restarting the level (two-phone play)
    respawnInPlace(curtain) {
        const p = this.player;
        this.tweens.killTweensOf(p);
        p.body.checkCollision.none = false;
        p.body.reset(this.respawn ? this.respawn.x : this.def.start * TILE + TILE / 2, GROUND_Y);
        p.setAngle(0).setDepth(6);
        p.frozen = false;
        p.invulnTime = 1500;
        this.state.hearts = this.state.maxHearts;
        this.dying = false;
        const cam = this.cameras.main;
        cam.startFollow(p, true, 0.1, 0.12, -150, 0);
        cam.centerOn(p.x, cam.midPoint.y);
        this.following = true;
        curtain.destroy();
        iris(this, { x: this.scale.width / 2, y: this.scale.height / 2, open: true, ms: 600 });
        music.play(this.def.music || 'meadow');
    }

    smashBoulder(block, mine) {
        if (mine && this.coop) net.send('block', { cell: block.getData('cell') });
        sfx.smash();
        this.cameras.main.shake(120, 0.006);
        this.fx.bricks.explode(16, block.x, block.y);
        this.solidCells.delete(block.getData('cell'));
        block.destroy();
        // boulders stacked on top tumble down too
        const [c, r] = block.getData('cell').split(',').map(Number);
        const above = this.solids.getChildren().find((b) => b.getData?.('cell') === `${c},${r - 1}` && b.getData('kind') === 'boulder');
        if (above) this.time.delayedCall(90, () => above.active && this.smashBoulder(above, mine));
    }

    // her phone broke a brick or opened a gift: do the same here (she gets what was inside)
    remoteBlock(cell) {
        const block = this.solids.getChildren().find((b) => b.getData && b.getData('cell') === cell);
        if (!block) return;
        const kind = block.getData('kind');
        if (kind === 'boulder') return this.smashBoulder(block, false);
        if (kind === 'break') {
            this.fx.bricks.explode(14, block.x, block.y);
            this.solidCells.delete(cell);
            block.destroy();
        } else if (kind === 'gift') {
            block.setTexture('tile_gift_used').setData('kind', 'used');
        } else if (kind === 'hidden') {
            block.setAlpha(1).setData('kind', 'used');
            Object.assign(block.body.checkCollision, { up: true, left: true, right: true });
            this.solidCells.add(cell);
        }
    }

    gameOver() {
        const { width: w, height: h } = this.scale;
        this.add.rectangle(0, 0, w, h, 0x000000).setOrigin(0).setScrollFactor(0).setDepth(1001);
        this.add.text(w / 2, h / 2, 'GAME OVER', { fontFamily: FONT, fontSize: 40, color: '#ffffff' }).setOrigin(0.5).setScrollFactor(0).setDepth(1002);
        this.time.delayedCall(2600, () => {
            this.scene.stop('Hud');
            this.scene.start('Title', { skipSplash: true });
        });
    }

    finish() {
        this.ended = true;
        const p = this.player;
        p.frozen = true;
        p.body.setVelocityX(0);
        p.hanging = null;
        p.body.setAllowGravity(true);
        p.setFlipX(false);
        p.pose(p.F.victory);
        // little hops of joy, and Kitty celebrates too
        this.time.delayedCall(250, () => p.body.setVelocityY(-420));
        this.time.delayedCall(900, () => p.body.setVelocityY(-420));
        this.kitty?.celebrate();
        music.stop();
        sfx.win();
        const cx = this.boss ? p.x : this.gate.x;
        const cy = this.boss ? p.y - 200 : this.gate.y - this.gate.height;
        this.fx.confetti.explode(60, cx, cy);
        this.time.delayedCall(700, () => this.fx.confetti.explode(60, cx, cy));

        // clearing a level for the first time unlocks the next outfit
        const save = this.save;
        let unlocked = null;
        if (!this.coop && !save.cleared.includes(this.def.id)) {
            save.cleared.push(this.def.id);
            unlocked = OUTFITS.find((o) => !save.outfits.includes(o.key));
            if (unlocked) save.outfits.push(unlocked.key);
        }
        // two-phone play: remember World 2 progress, and finishing a level gives Janika her next outfit
        if (this.coop && !(save.coopCleared ??= []).includes(this.def.id)) save.coopCleared.push(this.def.id);
        if (this.coop && net.me === 'janika') {
            unlocked = JANIKA_OUTFITS.find((o) => !save.janikaOutfits.includes(o.key));
            if (unlocked) save.janikaOutfits.push(unlocked.key);
        }
        writeSave(save);

        // count the leftover time into the score, then move on
        this.time.delayedCall(1300, () => {
            const tally = this.time.addEvent({
                delay: 25, repeat: Math.max(0, this.state.time - 1), callback: () => {
                    this.state.time--;
                    this.state.score += SCORE.timeBonus;
                    if (this.state.time % 3 === 0) sfx.tick();
                },
            });
            const timeLeft = this.state.time;
            const wait = 25 * timeLeft + 500;
            this.time.delayedCall(wait, () => {
                tally.remove();
                this.hud()?.showResults({
                    id: this.def.id, name: this.def.name, score: this.state.score, gems: this.state.gems,
                    timeBonus: timeLeft * SCORE.timeBonus,
                    crystals: (this.save.crystals[this.def.id] || []).length,
                    candle: this.save.candles.includes(this.def.id),
                    unlocked,
                    last: !!this.def.boss,
                }, () => this.leave(), () => this.leave('WorldMap'));
            });
        });
    }

    leave(to) {
        const next = this.levelIndex + 1;
        const cam = this.cameras.main;
        const p = this.player;
        iris(this, { x: p.x - cam.scrollX, y: p.y - 60 - cam.scrollY, open: false, ms: 600 });
        this.time.delayedCall(650, () => {
            if (this.coop && this.def.coopBoss) {
                // World 2 beaten: the ending, on both phones
                this.scene.stop('Hud');
                net.close();
                this.scene.start('Story', { script: 'world2end' });
            } else if (this.coop) {
                this.scene.stop('Hud');
                this.scene.start('Lobby', { room: true });
            } else if (to === 'WorldMap') {
                this.scene.stop('Hud');
                this.scene.start('WorldMap');
            } else if (this.def.boss) {
                this.scene.stop('Hud');
                this.scene.start('Story', { script: 'world1end' });
            } else if (LEVELS[next]) {
                this.scene.restart({ level: next, state: this.state });
            } else {
                this.scene.stop('Hud');
                this.scene.start('Title');
            }
        });
    }
}
