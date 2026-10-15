import * as Phaser from 'phaser';
import { FONT, janikaLook } from '../config.js';
import { writeSave } from '../save.js';
import { LEVELS } from '../levels.js';
import { sfx } from '../sfx.js';
import { music } from '../music.js';

const GOLD = '#f5c542';
const TEXT = { fontFamily: FONT, fontSize: 18, color: '#ffffff', stroke: '#000000', strokeThickness: 4 };

// World map: level spots along a winding trail; Janani walks to a spot, tap PLAY to enter.
export default class WorldMap extends Phaser.Scene {
    constructor() {
        super('WorldMap');
    }

    create() {
        const { width: w, height: h } = this.scale;
        this.save = this.registry.get('save');
        this.input.enabled = true;
        // Gemini's World 1 map, always shown whole; any space left at the sides gets a dimmed copy of it
        const fill = this.add.image(w / 2, h / 2, 'world1_map').setTint(0x666677);
        fill.setScale(Math.max(w / fill.width, h / fill.height));
        const map = this.add.image(w / 2, h / 2, 'world1_map');
        const k = Math.min(w / map.width, h / map.height);
        map.setScale(k);
        const ox = (w - map.width * k) / 2;
        const oy = (h - map.height * k) / 2;
        const at = (x, y) => ({ x: ox + x * k, y: oy + y * k }); // map picture pixels to screen

        this.add.rectangle(0, 0, w, 86, 0x140d1f, 0.85).setOrigin(0);
        this.add.text(w / 2, 30, 'WORLD 1', { ...TEXT, fontSize: 26, color: GOLD }).setOrigin(0.5);
        this.add.text(w / 2, 62, 'SUNNY MEADOW', { ...TEXT, fontSize: 13 }).setOrigin(0.5);
        const back = this.add.text(16, 24, '< BACK', { ...TEXT, fontSize: 16 }).setPadding(10).setInteractive({ useHandCursor: true });
        back.on('pointerdown', () => { sfx.select(); this.leave('Title', { skipSplash: true }); });

        // the 5 clearings on the map's path, in map picture pixels: meadow, hills, treetops, fortress, Yuva's hill
        const CLEARINGS = [[155, 497], [326, 454], [520, 495], [724, 449], [920, 474]];
        this.spots = LEVELS.map((lvl, i) => ({ lvl, i, ...at(...CLEARINGS[i]) }));
        this.spots.forEach((s) => this.drawSpot(s));
        this.save.mapSeen = this.spots.filter((s) => this.unlocked(s.i)).length;
        writeSave(this.save);

        // Yuva waits on his dark hill with Janika in his bubble (or, once World 1 is beaten, with Kitty)
        const rescued = this.save.cleared.includes('1-5');
        const hill = at(860, 380);
        const yuva = this.add.sprite(hill.x, hill.y, 'boss', 0).setScale(0.55).setFlipX(true).play('boss_idle');
        const janika = rescued
            ? this.add.sprite(hill.x + 60, hill.y - 70, 'kitty').setScale(0.5).play('kitty_talk')
            : this.add.sprite(hill.x + 60, hill.y - 80, janikaLook(this.save.janikaOutfit).tex, 0).setScale(0.5);
        const bubble = this.add.graphics().fillStyle(0xff9ad5, 0.22).fillCircle(0, 0, 46).lineStyle(3, 0xffffff, 0.85).strokeCircle(0, 0, 46);
        bubble.setPosition(janika.x, janika.y - 32);
        this.tweens.add({ targets: [janika, bubble], y: '-=10', duration: 1100, yoyo: true, repeat: -1, ease: 'Sine.inOut' });

        // start on the first level not cleared yet
        const next = LEVELS.findIndex((l) => !this.save.cleared.includes(l.id));
        this.current = next < 0 ? LEVELS.length - 1 : next;
        const s = this.spots[this.current];
        this.hero = this.add.sprite(s.x, s.y - 38, `hero_${this.save.outfit}`).setOrigin(0.5, 1).setScale(0.75).play(`${this.save.outfit}_idle`);
        // her companion on the map: Kitty, or her sister once she's been rescued
        this.buddy = rescued
            ? { ...janikaLook(this.save.janikaOutfit), facesLeft: false, scale: 0.75 }
            : { walk: 'kitty_walk', idle: 'kitty_idle', facesLeft: true, scale: 0.55 };
        this.kitty = this.add.sprite(s.x - 50, s.y - 30, rescued ? this.buddy.tex : 'kitty').setOrigin(0.5, 1)
            .setScale(this.buddy.scale).setFlipX(this.buddy.facesLeft).play(this.buddy.idle);

        // bottom panel: selected level and the play button
        this.panel = this.add.container(w / 2, 86 + 62); // in the sky, clear of the path below
        this.panel.add(this.add.rectangle(0, 0, 620, 90, 0x140d1f, 0.92).setStrokeStyle(4, 0xf5c542));
        this.nameText = this.add.text(-280, 0, '', { ...TEXT, fontSize: 16 }).setOrigin(0, 0.5);
        const play = this.add.text(230, 0, 'PLAY', { ...TEXT, fontSize: 26, color: GOLD }).setOrigin(0.5).setPadding(16, 10, 16, 10)
            .setInteractive({ useHandCursor: true });
        play.on('pointerdown', () => this.enter());
        this.tweens.add({ targets: play, scale: 1.1, duration: 500, yoyo: true, repeat: -1 });
        this.panel.add([this.nameText, play]);
        this.showName();

        this.input.keyboard.on('keydown-RIGHT', () => this.walkTo(this.current + 1));
        this.input.keyboard.on('keydown-LEFT', () => this.walkTo(this.current - 1));
        this.input.keyboard.on('keydown-ENTER', () => this.enter());
        this.input.keyboard.on('keydown-SPACE', () => this.enter());

        this.cameras.main.fadeIn(400);
        music.play('title');
    }

    unlocked(i) {
        return i === 0 || this.save.cleared.includes(LEVELS[i - 1].id);
    }

    drawSpot(s) {
        const open = this.unlocked(s.i);
        const done = this.save.cleared.includes(s.lvl.id);
        const c = this.add.container(s.x, s.y);
        c.add(this.add.circle(0, 6, 40, 0x000000, 0.35));
        c.add(this.add.circle(0, 0, 40, done ? 0xf5c542 : open ? 0x2a1640 : 0x444444).setStrokeStyle(5, open ? 0xffffff : 0x777777));
        c.add(this.add.text(0, 0, s.lvl.id, { ...TEXT, fontSize: 16, color: done ? '#2a1640' : open ? '#ffffff' : '#999999', strokeThickness: done ? 0 : 4 }).setOrigin(0.5));
        if (this.save.candles.includes(s.lvl.id)) c.add(this.add.image(30, -34, 'candle').setScale(0.5));
        if (!open) c.add(this.add.text(0, 54, 'LOCKED', { ...TEXT, fontSize: 9, color: '#bbbbbb' }).setOrigin(0.5));
        // the level's 3 big crystals: bright when found
        const found = (this.save.crystals[s.lvl.id] || []).length;
        if (open) for (let j = 0; j < 3; j++) c.add(this.add.image(-26 + j * 26, 54, 'gem_big').setScale(0.38).setAlpha(j < found ? 1 : 0.3));
        // a level that just opened pops in with sparkles (once)
        const pulse = () => open && !done && this.tweens.add({ targets: c, scale: 1.08, duration: 600, yoyo: true, repeat: -1 });
        if (open && s.i >= (this.save.mapSeen ?? 1)) {
            c.setScale(0);
            this.tweens.add({ targets: c, scale: 1, delay: 500, duration: 500, ease: 'Back.out', onStart: () => sfx.sprout(), onComplete: pulse });
            this.time.delayedCall(600, () => this.add.particles(s.x, s.y, 'px', {
                speed: { min: 80, max: 220 }, lifespan: 700, scale: { start: 1.4, end: 0 }, tint: [0xf5c542, 0xffffff], emitting: false,
            }).explode(30));
        }
        c.setSize(90, 90).setInteractive({ useHandCursor: true }).on('pointerdown', () => {
            if (s.i === this.current) this.enter();
            else this.walkTo(s.i);
        });
        if (c.scale > 0) pulse();
    }

    showName() {
        const lvl = LEVELS[this.current];
        const candle = this.save.candles.includes(lvl.id) ? '  (candle found)' : '';
        this.nameText.setText(`${lvl.id}  ${lvl.name.toUpperCase()}${candle}`);
    }

    // walk along the trail, spot by spot, to a level (only unlocked ones)
    async walkTo(target) {
        if (this.walking || target < 0 || target >= this.spots.length) return;
        if (!this.unlocked(target)) { sfx.bump(); return; }
        this.walking = true;
        const step = target > this.current ? 1 : -1;
        this.hero.play(`${this.save.outfit}_walk`).setFlipX(step < 0);
        this.kitty.play(this.buddy.walk).setFlipX(this.buddy.facesLeft ? step > 0 : step < 0);
        while (this.current !== target) {
            const s = this.spots[this.current + step];
            await new Promise((r) => {
                this.tweens.add({ targets: this.hero, x: s.x, y: s.y - 38, duration: 520, onComplete: r });
                this.tweens.add({ targets: this.kitty, x: s.x - 50 * step, y: s.y - 30, duration: 560 });
            });
            this.current += step;
            sfx.tick();
        }
        this.hero.play(`${this.save.outfit}_idle`).setFlipX(false);
        this.kitty.play(this.buddy.idle).setFlipX(this.buddy.facesLeft);
        this.showName();
        this.walking = false;
    }

    enter() {
        if (this.walking) return;
        sfx.select();
        const firstTime = this.current === 0 && this.save.cleared.length === 0;
        if (firstTime) this.leave('Story', { script: 'intro' });
        else this.leave('Level', { level: this.current });
    }

    leave(scene, data) {
        this.input.enabled = false;
        this.cameras.main.fade(400, 0, 0, 0, true);
        this.time.delayedCall(450, () => {
            music.stop();
            this.scene.start(scene, data);
        });
    }
}
