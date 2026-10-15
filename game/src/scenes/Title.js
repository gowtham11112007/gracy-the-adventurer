import * as Phaser from 'phaser';
import { NAMES, FONT, OUTFITS, JANIKA_OUTFITS, UNLOCK_ALL_OUTFITS, TILE, HERO_FRAMES, VERSION, janikaLook } from '../config.js';
import { LEVELS, COOP_LEVELS } from '../levels.js';
import { writeSave, freshSave } from '../save.js';
import { updateStatus } from '../updater.js';
import { sfx } from '../sfx.js';
import { music } from '../music.js';
import { setMusicVolume, setSoundVolume } from '../audio.js';

const GOLD = '#f5c542';
const TEXT = { fontFamily: FONT, fontSize: 22, color: '#ffffff', stroke: '#000000', strokeThickness: 4 };

// Title screen: a living scene, "tap to start", then the main menu and its panels.
export default class Title extends Phaser.Scene {
    constructor() {
        super('Title');
    }

    create(data) {
        const { width: w, height: h } = this.scale;
        this.save = this.registry.get('save');
        this.input.enabled = true; // switched off while fading out last time
        this.menuOpen = false;
        this.panel = null;

        // living background: scrolling meadow, drifting clouds, falling petals
        this.bg = this.add.tileSprite(0, 0, w, h, 'bg_meadow_wide').setOrigin(0).setTileScale(h / 720, h / 720);
        for (let i = 0; i < 6; i++) {
            const c = this.add.image(Phaser.Math.Between(0, w), Phaser.Math.Between(40, h * 0.4), i % 2 ? 'cloud_big' : 'cloud_small')
                .setScale(Phaser.Math.FloatBetween(0.7, 1.3)).setAlpha(0.8);
            this.tweens.add({ targets: c, x: c.x + w + 300, duration: Phaser.Math.Between(50000, 90000), repeat: -1, onRepeat: () => (c.x = -200) });
        }
        const groundY = h - 64;
        for (let x = 0; x < w + TILE; x += TILE) this.add.image(x, groundY + TILE, 'ground_top', (x / TILE) % 2).setOrigin(0, 1);
        this.add.particles(0, 0, 'px', {
            x: { min: 0, max: w }, y: -10, speedX: { min: 10, max: 50 }, speedY: { min: 30, max: 70 }, lifespan: 12000,
            frequency: 260, tint: [0xffc4e1, 0xffffff], scale: { start: 1, end: 0.6 }, rotate: { min: 0, max: 360 },
        }).setDepth(9);

        // story teaser: Yuva flying off with Janika in his bubble (with Kitty, once Janika is rescued)
        const rescued = this.save.cleared.includes('1-5');
        const yuva = this.add.sprite(w * 0.9, h * 0.2, 'boss', 3).setScale(0.65).setFlipX(true);
        const janika = rescued
            ? this.add.sprite(w * 0.8, h * 0.25, 'kitty').setScale(0.6).play('kitty_talk')
            : this.add.sprite(w * 0.8, h * 0.25, janikaLook(this.save.janikaOutfit).tex, 0).setScale(0.6);
        const bubble = this.add.graphics().fillStyle(0xff9ad5, 0.22).fillCircle(0, 0, 58).lineStyle(4, 0xffffff, 0.85).strokeCircle(0, 0, 58);
        bubble.setPosition(janika.x, janika.y);
        this.tweens.add({ targets: [yuva, janika, bubble], y: '-=14', duration: 1400, yoyo: true, repeat: -1, ease: 'Sine.inOut' });

        // showcase: Janani on a floating grass island with a soft spotlight, Kitty beside her
        const sx = w * 0.72;
        const sy = h * 0.72;
        const glow = this.add.graphics();
        for (let i = 6; i > 0; i--) glow.fillStyle(0xfff3c4, 0.06).fillCircle(sx, sy - 110, 60 + i * 26);
        this.tweens.add({ targets: glow, alpha: 0.6, duration: 1600, yoyo: true, repeat: -1 });
        const island = this.add.container(sx, sy);
        // a single strip of grass and earth, floating
        for (let i = -2; i < 2; i++) island.add(this.add.image(i * TILE, TILE, 'ground_top', (i + 2) % 2).setOrigin(0, 1));
        this.hero = this.add.sprite(-30, 6, `hero_${this.save.outfit}`).setOrigin(0.5, 1).setScale(1.5).play(`${this.save.outfit}_idle`);
        // beside her: Kitty, or her sister once Kitty has been taken
        const buddy = rescued
            ? this.add.sprite(60, 6, janikaLook(this.save.janikaOutfit).tex).setOrigin(0.5, 1).setScale(1.5).setFlipX(true).play(janikaLook(this.save.janikaOutfit).idle)
            : this.add.sprite(85, 8, 'kitty').setOrigin(0.5, 1).setScale(0.95).setFlipX(true).play('kitty_idle');
        island.add([this.hero, buddy]);
        this.twinOnIsland = rescued ? buddy : null;
        this.tweens.add({ targets: island, y: sy - 12, duration: 1800, yoyo: true, repeat: -1, ease: 'Sine.inOut' });

        // logo
        this.logo = this.add.container(w / 2, h * 0.24);
        this.logo.add(this.add.text(0, 0, 'GRACY', {
            fontFamily: FONT, fontSize: 100, color: GOLD, stroke: '#2a1640', strokeThickness: 18,
            shadow: { offsetX: 7, offsetY: 9, color: '#2a1640', fill: true, stroke: true },
        }).setOrigin(0.5));
        this.logo.add(this.add.text(0, 84, 'THE ADVENTURER', { fontFamily: FONT, fontSize: 30, color: '#ffffff', stroke: '#2a1640', strokeThickness: 10 }).setOrigin(0.5));
        this.tweens.add({ targets: this.logo, angle: 1.5, duration: 2200, yoyo: true, repeat: -1, ease: 'Sine.inOut' });

        this.prompt = this.add.text(w / 2, h * 0.6, 'TAP TO START', { ...TEXT, fontSize: 26 }).setOrigin(0.5);
        this.tweens.add({ targets: this.prompt, alpha: 0.2, duration: 650, yoyo: true, repeat: -1 });
        this.input.once('pointerdown', () => this.openMenu());
        this.input.keyboard.once('keydown', () => this.openMenu());

        if (data?.message) {
            const t = this.add.text(w / 2, h - 22, data.message, { ...TEXT, fontSize: 13, color: GOLD }).setOrigin(0.5).setDepth(10);
            this.tweens.add({ targets: t, alpha: 0.4, duration: 700, yoyo: true, repeat: -1 });
        }
        if (data?.skipSplash) this.openMenu(true);

        setMusicVolume(this.save.music !== false);
        setSoundVolume(this.save.sound !== false);
        music.play('title');

        // rebuild the layout if the screen size changes (e.g. the phone rotates)
        const relayout = () => this.time.delayedCall(150, () => this.scene.restart({ ...data, skipSplash: this.menuOpen }));
        this.scale.once('resize', relayout);
        this.events.once('shutdown', () => this.scale.off('resize', relayout));
    }

    update() {
        this.bg.tilePositionX += 0.35;
    }

    // ------------------------------------------------------------- main menu ---
    openMenu(instant = false) {
        if (this.menuOpen) return;
        this.menuOpen = true;
        if (!instant) sfx.select();
        const { width: w, height: h } = this.scale;
        this.prompt?.destroy();
        // logo moves up to the top-left corner
        this.tweens.add({ targets: this.logo, x: 290, y: 92, scale: 0.62, duration: instant ? 0 : 450, ease: 'Back.out' });

        const items = [
            { label: 'PLAY', go: () => this.openWorlds() },
            { label: 'WARDROBE', go: () => this.openWardrobe() },
            { label: 'STORY', go: () => this.openStory() },
            { label: 'SETTINGS', go: () => this.openSettings() },
            { label: 'CREDITS', go: () => this.openCredits() },
        ];

        // the list: a highlight bar and a spinning gem point at the selected entry
        const x0 = 90;
        const y0 = h * 0.33;
        const gap = Math.min(64, (h * 0.5) / items.length);
        this.bar = this.add.rectangle(x0 - 30, y0, 430, gap - 8, 0x2a1640, 0.85).setOrigin(0, 0.5).setStrokeStyle(3, 0xf5c542);
        this.cursor = this.add.sprite(x0 - 6, y0, 'gem', 0).setScale(0.9).play('gem_spin');
        this.items = items.map((it, i) => {
            const t = this.add.text(x0 + 30, y0 + i * gap, it.label, { ...TEXT, fontSize: 22 }).setOrigin(0, 0.5)
                .setPadding(10, 10, 160, 10).setInteractive({ useHandCursor: true });
            t.on('pointerover', () => this.select(i));
            t.on('pointerdown', () => { this.select(i); this.activate(); });
            t.setAlpha(0).setX(t.x - 40);
            this.tweens.add({ targets: t, alpha: 1, x: x0 + 30, delay: instant ? 0 : 150 + i * 60, duration: instant ? 0 : 300 });
            return { ...it, text: t, y: y0 + i * gap };
        });
        this.selected = -1;
        this.select(0, true);

        // progress card
        const crystals = Object.values(this.save.crystals || {}).reduce((n, l) => n + l.length, 0);
        const together = (this.save.coopCleared || []).length;
        const pct = Math.round(((this.save.cleared.length + this.save.candles.length + crystals / 3 + together) /
            (LEVELS.length * 3 + COOP_LEVELS.length)) * 100);
        const card = this.add.container(x0 + 185, h - 70);
        card.add(this.add.rectangle(0, 0, 460, 70, 0x140d1f, 0.85).setStrokeStyle(3, 0xf5c542));
        card.add(this.add.text(-210, -16, `PROGRESS ${pct}%`, { ...TEXT, fontSize: 14, color: GOLD }).setOrigin(0, 0.5));
        card.add(this.add.text(-210, 14, `W1 ${this.save.cleared.length}/5   W2 ${together}/4   CANDLES ${this.save.candles.length}/5   CRYSTALS ${crystals}/15`, { ...TEXT, fontSize: 10 }).setOrigin(0, 0.5));

        this.input.keyboard.on('keydown-UP', () => !this.panel && this.select((this.selected + items.length - 1) % items.length));
        this.input.keyboard.on('keydown-DOWN', () => !this.panel && this.select((this.selected + 1) % items.length));
        this.input.keyboard.on('keydown-ENTER', () => !this.panel && this.activate());
    }

    select(i, quiet = false) {
        if (i === this.selected) return;
        this.selected = i;
        if (!quiet) sfx.tick();
        this.items.forEach((it, j) => it.text.setColor(j === i ? GOLD : '#ffffff').setScale(j === i ? 1.08 : 1));
        const y = this.items[i].y;
        this.tweens.add({ targets: [this.bar, this.cursor], y, duration: 120, ease: 'Quad.out' });
    }

    activate() {
        if (this.panel) return;
        sfx.select();
        const it = this.items[this.selected];
        this.tweens.add({ targets: it.text, scale: 0.95, duration: 70, yoyo: true, onComplete: it.go });
    }

    // ---------------------------------------------------------------- panels ---
    // a dark gold-framed window over the menu; returns its container
    openPanel(title, width = 900, height = 560) {
        const { width: w, height: h } = this.scale;
        const layer = this.add.container(0, 0).setDepth(30);
        layer.add(this.add.rectangle(0, 0, w, h, 0x000000, 0.7).setOrigin(0).setInteractive());
        const frame = this.add.container(w / 2, h / 2).setScale(0.9).setAlpha(0);
        frame.add(this.add.rectangle(0, 0, width, height, 0x140d1f, 0.97).setStrokeStyle(4, 0xf5c542));
        frame.add(this.add.text(0, -height / 2 + 42, title, { ...TEXT, fontSize: 28, color: GOLD }).setOrigin(0.5));
        layer.add(frame);
        this.tweens.add({ targets: frame, scale: 1, alpha: 1, duration: 200, ease: 'Back.out' });
        const close = this.add.text(0, height / 2 - 40, 'BACK', TEXT).setOrigin(0.5).setPadding(20, 10, 20, 10).setInteractive({ useHandCursor: true });
        close.on('pointerdown', () => { sfx.select(); this.closePanel(); });
        frame.add(close);
        this.panel = layer;
        this.frame = frame;
        return frame;
    }

    closePanel() {
        this.panel?.destroy();
        this.panel = null;
    }

    option(frame, y, label, onTap, size = 20) {
        const t = this.add.text(0, y, label, { ...TEXT, fontSize: size }).setOrigin(0.5).setPadding(20, 10, 20, 10).setInteractive({ useHandCursor: true });
        t.on('pointerover', () => t.setColor(GOLD)).on('pointerout', () => t.setColor('#ffffff'));
        t.on('pointerdown', () => { sfx.select(); onTap(t); });
        frame.add(t);
        return t;
    }

    // the two worlds, side by side: play either one, in any order
    openWorlds() {
        const f = this.openPanel('CHOOSE A WORLD', 980, 620);
        const save = this.save;
        const worlds = [
            {
                pic: 'world1_map', title: 'WORLD 1', name: 'SUNNY MEADOW', who: `${NAMES.hero.toUpperCase()}  -  1 PHONE`,
                done: `${save.cleared.length}/${LEVELS.length} LEVELS`,
                go: () => {
                    // first time: the intro story; after that the world map
                    if (save.cleared.length === 0 && !save.w1intro) {
                        save.w1intro = true;
                        writeSave(save);
                        this.go('Story', { script: 'intro' });
                    } else this.go('WorldMap');
                },
            },
            {
                pic: 'bg_cave', title: 'WORLD 2', name: 'CRYSTAL CAVE', who: `${NAMES.hero.toUpperCase()} & ${NAMES.twin.toUpperCase()}  -  2 PHONES`,
                done: `${(save.coopCleared || []).length}/${COOP_LEVELS.length} LEVELS`,
                go: () => {
                    // first time: how Yuva took Kitty; after that straight to the room
                    if (!save.w2intro) {
                        save.w2intro = true;
                        writeSave(save);
                        this.go('Story', { script: 'world2intro' });
                    } else this.go('Lobby');
                },
            },
        ];
        worlds.forEach((wd, i) => {
            const card = this.add.container(i ? 230 : -230, -5);
            const pic = this.add.image(0, -60, wd.pic).setDisplaySize(400, 224);
            card.add([
                this.add.rectangle(0, 10, 430, 400, 0x221632).setStrokeStyle(3, 0xf5c542),
                pic,
                this.add.text(0, 80, wd.title, { ...TEXT, fontSize: 24, color: GOLD }).setOrigin(0.5),
                this.add.text(0, 116, wd.name, { ...TEXT, fontSize: 14 }).setOrigin(0.5),
                this.add.text(0, 146, wd.who, { ...TEXT, fontSize: 10, color: '#c9b8ff' }).setOrigin(0.5),
                this.add.text(0, 176, wd.done, { ...TEXT, fontSize: 10, color: '#7dff8a' }).setOrigin(0.5),
            ]);
            card.setSize(430, 400).setInteractive({ useHandCursor: true });
            card.on('pointerover', () => this.tweens.add({ targets: card, scale: 1.04, duration: 120 }));
            card.on('pointerout', () => this.tweens.add({ targets: card, scale: 1, duration: 120 }));
            card.on('pointerdown', () => { sfx.select(); wd.go(); });
            f.add(card);
        });
    }

    openStory() {
        const f = this.openPanel('STORY', 680, 520);
        const scene = (y, label, script, open) => {
            const t = this.option(f, y, open ? label : `${label} (LOCKED)`, () => {
                if (open) this.go('Story', { script, replay: true });
            }, open ? 18 : 13);
            if (!open) t.setColor('#777777').disableInteractive();
        };
        scene(-140, 'WORLD 1 INTRO', 'intro', true);
        scene(-75, 'WORLD 1 ENDING', 'world1end', this.save.cleared.includes('1-5'));
        scene(-10, 'WORLD 2 INTRO', 'world2intro', true);
        scene(55, 'WORLD 2 ENDING', 'world2end', (this.save.coopCleared || []).includes('2-4'));
    }

    openSettings() {
        const f = this.openPanel('SETTINGS', 640, 530);
        const s = this.save;
        const flip = (key, t, label, apply) => {
            s[key] = s[key] === false ? true : !s[key];
            apply?.(s[key]);
            writeSave(s);
            t.setText(`${label}: ${s[key] ? 'ON' : 'OFF'}`);
        };
        this.option(f, -140, `MUSIC: ${s.music === false ? 'OFF' : 'ON'}`, (t) => flip('music', t, 'MUSIC', setMusicVolume));
        this.option(f, -80, `SOUND: ${s.sound === false ? 'OFF' : 'ON'}`, (t) => flip('sound', t, 'SOUND', setSoundVolume));
        this.option(f, -20, `VIBRATION: ${s.vibration === false ? 'OFF' : 'ON'}`, (t) => flip('vibration', t, 'VIBRATION'));
        this.option(f, 40, `BIG BUTTONS: ${s.bigButtons ? 'ON' : 'OFF'}`, (t) => {
            s.bigButtons = !s.bigButtons;
            writeSave(s);
            t.setText(`BIG BUTTONS: ${s.bigButtons ? 'ON' : 'OFF'}`);
        });
        const reset = this.option(f, 115, 'ERASE PROGRESS', (t) => {
            if (t.text !== 'TAP AGAIN TO ERASE') {
                t.setText('TAP AGAIN TO ERASE').setColor('#ff6b6b');
                return;
            }
            const fresh = freshSave();
            Object.keys(s).forEach((k) => delete s[k]);
            Object.assign(s, fresh);
            writeSave(s);
            this.scene.restart({ skipSplash: true });
        }, 14);
        reset.setColor('#ff9a9a');
    }

    openCredits() {
        const f = this.openPanel('CREDITS', 760, 580);
        const lines = [
            [`${NAMES.game.toUpperCase()}`, GOLD, 18],
            [`A birthday gift for ${NAMES.hero} & ${NAMES.twin}`, '#ffffff', 13],
            ['', '#ffffff', 10],
            ['Characters drawn with Gemini', '#cccccc', 12],
            ['Worlds and scenes made with Gemini & Canva', '#cccccc', 12],
            ['Music and sounds made in code', '#cccccc', 12],
            ['Built with Phaser', '#cccccc', 12],
            [`Version ${VERSION}`, '#888888', 10],
            [`Updates: ${updateStatus}`, '#888888', 9],
            ['', '#ffffff', 10],
            ['HAPPY BIRTHDAY!', GOLD, 22],
        ];
        lines.forEach(([t, color, size], i) => f.add(this.add.text(0, -170 + i * 36, t, { ...TEXT, fontSize: size, color }).setOrigin(0.5)));
    }

    // a card for every outfit; locked ones are dark silhouettes with how to unlock them
    // outfits for each twin: Janani earns hers in World 1, Janika hers in two-phone play
    openWardrobe(who = 'janani') {
        const f = this.openPanel('WARDROBE', 960, 600);
        const janika = who === 'janika';
        const list = janika ? JANIKA_OUTFITS : OUTFITS;
        const owned = janika ? this.save.janikaOutfits : this.save.outfits;
        const wearing = janika ? this.save.janikaOutfit : this.save.outfit;
        // tabs: whose clothes
        [['janani', NAMES.hero], ['janika', NAMES.twin]].forEach(([key, name], i) => {
            const tab = this.add.text(-120 + i * 240, -205, name.toUpperCase(), { ...TEXT, fontSize: 14, color: key === who ? GOLD : '#888888' })
                .setOrigin(0.5).setPadding(16, 8, 16, 8).setInteractive({ useHandCursor: true });
            tab.on('pointerdown', () => { sfx.select(); this.closePanel(); this.openWardrobe(key); });
            f.add(tab);
        });
        if (janika) {
            f.add(this.add.text(150, 200, `${NAMES.twin.toUpperCase()} PICKS HER OUTFIT\nON HER OWN PHONE`, { ...TEXT, fontSize: 9, color: '#c9b8ff' }).setOrigin(0.5));
        }
        list.forEach((o, i) => {
            const x = -300 + (i % 3) * 300;
            const y = -75 + Math.floor(i / 3) * 210;
            const has = UNLOCK_ALL_OUTFITS || owned.includes(o.key);
            const worn = wearing === o.key;
            const card = this.add.container(x, y);
            card.add(this.add.rectangle(0, 0, 260, 188, worn ? 0x3a2360 : 0x221632).setStrokeStyle(worn ? 5 : 2, worn ? 0xf5c542 : 0x6a5a80));
            const tex = !janika ? `hero_${o.key}` : o.key === 'janika' ? 'twin' : o.key;
            const fig = this.add.sprite(0, 52, tex, janika || has ? 0 : HERO_FRAMES.victory).setOrigin(0.5, 1).setScale(0.8);
            if (!has) fig.setTint(0x000000).setAlpha(0.55);
            card.add(fig);
            const locked = janika ? 'PLAY TOGETHER' : `CLEAR ${LEVELS[i - 1]?.id ?? ''}`;
            card.add(this.add.text(0, 72, has ? o.name : locked, { ...TEXT, fontSize: 12, color: has ? '#ffffff' : '#888888' }).setOrigin(0.5));
            if (worn) card.add(this.add.text(0, -80, 'WEARING', { ...TEXT, fontSize: 11, color: GOLD }).setOrigin(0.5));
            if (has) {
                card.setSize(260, 195).setInteractive({ useHandCursor: true }).on('pointerdown', () => {
                    sfx.select();
                    if (janika) {
                        this.save.janikaOutfit = o.key;
                        const look = janikaLook(o.key);
                        this.twinOnIsland?.setTexture(look.tex).play(look.idle);
                    }
                    else {
                        this.save.outfit = o.key;
                        this.hero.setTexture(`hero_${o.key}`).play(`${o.key}_idle`);
                    }
                    writeSave(this.save);
                    this.closePanel();
                    this.openWardrobe(who);
                });
            }
            f.add(card);
        });
    }

    go(scene, data) {
        this.input.enabled = false;
        this.cameras.main.fade(400, 0, 0, 0, true);
        this.time.delayedCall(450, () => {
            music.stop();
            this.scene.start(scene, data);
        });
    }
}
