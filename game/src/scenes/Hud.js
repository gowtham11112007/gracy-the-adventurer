import * as Phaser from 'phaser';
import { FONT, NAMES } from '../config.js';
import { sfx } from '../sfx.js';
import { music } from '../music.js';
import { setMusicVolume, setSoundVolume } from '../audio.js';
import { writeSave } from '../save.js';

const LABEL = { fontFamily: FONT, fontSize: 16, color: '#ffffff', stroke: '#000000', strokeThickness: 4 };
const VALUE = { ...LABEL, fontSize: 20 };
const GOLD = '#f5c542';

// Drawn on top of the level: the score bar, boss bar, banners, pause menu, results and touch buttons.
export default class Hud extends Phaser.Scene {
    constructor() {
        super('Hud');
    }

    create() {
        this.pausePanel = null; // fresh state each time the HUD starts
        this.results = null;
        this.shownScore = null; // the score on screen rolls up to the real one
        this.shownGems = null;
        this.save = this.registry.get('save');
        this.radius = this.save.bigButtons ? 92 : 70;

        this.nameLabel = this.add.text(0, 18, NAMES.hero.toUpperCase(), LABEL);
        this.scoreText = this.add.text(0, 42, '000000', VALUE);
        this.hearts = [0, 1, 2, 3].map(() => this.add.image(0, 0, 'heart').setScale(0.55));
        this.shieldIcon = this.add.image(0, 0, 'cupcake').setScale(0.45).setVisible(false);
        this.gemIcon = this.add.image(0, 52, 'gem', 0).setScale(0.75);
        this.gemText = this.add.text(0, 54, 'x00', VALUE).setOrigin(0, 0.5);
        this.livesText = this.add.text(0, 72, '', { ...LABEL, fontSize: 14 });
        this.crystalIcons = [0, 1, 2].map(() => this.add.image(0, 52, 'gem_big').setScale(0.42));
        this.candleIcon = this.add.image(0, 52, 'candle').setScale(0.55);
        this.worldLabel = this.add.text(0, 18, 'WORLD', LABEL).setOrigin(0.5, 0);
        this.worldText = this.add.text(0, 42, '1-1', VALUE).setOrigin(0.5, 0);
        this.timeLabel = this.add.text(0, 18, 'TIME', LABEL).setOrigin(0.5, 0);
        this.timeText = this.add.text(0, 42, '300', VALUE).setOrigin(0.5, 0);

        // active power-ups with a bar showing how long they last
        this.buffBars = this.add.graphics();
        this.buffs = [
            { key: 'starTime', total: 8000, icon: this.add.image(0, 0, 'star').setScale(0.42) },
            { key: 'floatTime', total: 15000, icon: this.add.image(0, 0, 'balloon_pink').setScale(0.3) },
            { key: 'magnetTime', total: 15000, icon: this.add.image(0, 0, 'star_lucky').setScale(0.55) },
        ];

        // Yuva's health, shown during the boss fight
        this.bossBar = this.add.container(0, 0).setVisible(false);
        this.bossBar.add(this.add.text(0, 0, NAMES.boss.toUpperCase(), { ...LABEL, color: '#ff8a8a' }).setOrigin(1, 0.5));
        this.bossPips = [0, 1, 2].map((i) => this.add.rectangle(20 + i * 44, 0, 38, 16, 0xff3b5c).setStrokeStyle(3, 0xffffff));
        this.bossBar.add(this.bossPips);

        this.pauseButton = this.add.text(0, 16, 'II', { ...VALUE, fontSize: 22 }).setOrigin(1, 0).setPadding(14, 10, 14, 10)
            .setInteractive({ useHandCursor: true }).on('pointerdown', () => this.togglePause());

        this.bannerTitle = this.add.text(0, 0, '', { ...VALUE, fontSize: 34, strokeThickness: 8 }).setOrigin(0.5).setAlpha(0);
        this.bannerSub = this.add.text(0, 0, '', { ...LABEL, color: GOLD }).setOrigin(0.5).setAlpha(0);

        this.pad = this.add.graphics();
        this.pressed = {};
        // remember a jump tap even if the finger lifts before the next frame
        this.input.on('pointerdown', (p) => {
            const b = this.buttons.jump;
            if (!this.pausePanel && !this.results && Phaser.Math.Distance.Between(p.x, p.y, b.x, b.y) < this.radius * 1.3) {
                this.registry.get('controls').jumpTap = true;
            }
        });
        this.layout();
        this.scale.on('resize', this.layout, this);
        this.events.once('shutdown', () => this.scale.off('resize', this.layout, this));
    }

    layout() {
        const { width: w, height: h } = this.scale;
        // four columns across the top, like the classics
        const col = (i) => 40 + i * ((w - 80) / 4);
        this.nameLabel.setX(col(0));
        this.scoreText.setX(col(0));
        this.hearts.forEach((hrt, i) => hrt.setPosition(col(0) + 14 + i * 28, 84));
        this.shieldIcon.setPosition(col(0) + 14 + 4 * 28 + 4, 84);
        this.gemIcon.setX(col(1) + 12);
        this.gemText.setX(col(1) + 32);
        this.livesText.setX(col(1));
        this.crystalIcons.forEach((c, i) => c.setPosition(col(1) + 160 + i * 30, 52));
        this.candleIcon.setX(col(1) + 260);
        this.worldLabel.setX(col(2) + 60);
        this.worldText.setX(col(2) + 60);
        this.timeLabel.setX(col(3) + 40);
        this.timeText.setX(col(3) + 40);
        this.pauseButton.setX(w - 10);
        this.bossBar.setPosition(w / 2 - 40, 118);
        const r = this.radius;
        this.buttons = {
            left: { x: r + 40, y: h - r - 35 },
            right: { x: r * 3 + 60, y: h - r - 35 },
            jump: { x: w - r - 55, y: h - r - 35 },
        };
        this.bannerTitle.setPosition(w / 2, h * 0.32);
        this.bannerSub.setPosition(w / 2, h * 0.32 + 46);
        this.pausePanel?.destroy();
        this.pausePanel = null;
        this.drawPad();
    }

    drawPad() {
        const g = this.pad.clear();
        if (this.results) return;
        for (const [name, b] of Object.entries(this.buttons)) {
            const on = this.pressed[name];
            g.fillStyle(0x000000, on ? 0.35 : 0.18).fillCircle(b.x, b.y, this.radius);
            g.lineStyle(3, 0xffffff, on ? 0.6 : 0.3).strokeCircle(b.x, b.y, this.radius);
            g.fillStyle(0xffffff, on ? 0.9 : 0.6);
            const s = this.radius * 0.32;
            if (name === 'left') g.fillTriangle(b.x - s, b.y, b.x + s * 0.7, b.y - s, b.x + s * 0.7, b.y + s);
            if (name === 'right') g.fillTriangle(b.x + s, b.y, b.x - s * 0.7, b.y - s, b.x - s * 0.7, b.y + s);
            if (name === 'jump') g.fillTriangle(b.x, b.y - s, b.x - s, b.y + s * 0.7, b.x + s, b.y + s * 0.7);
        }
    }

    update() {
        // which buttons are held: check every finger (and the mouse) that is down
        const controls = this.registry.get('controls');
        const now = { left: false, right: false, jump: false };
        if (!this.pausePanel && !this.results) {
            for (const p of this.input.manager.pointers) {
                if (!p.isDown) continue;
                for (const [name, b] of Object.entries(this.buttons)) {
                    if (Phaser.Math.Distance.Between(p.x, p.y, b.x, b.y) < this.radius * 1.3) now[name] = true;
                }
            }
        }
        if (now.left !== this.pressed.left || now.right !== this.pressed.right || now.jump !== this.pressed.jump) {
            this.pressed = now;
            this.drawPad();
        }
        controls.left = now.left;
        controls.right = now.right;
        controls.jump = now.jump;

        const level = this.scene.get('Level');
        const s = level.state;
        if (!s || !level.player) return;
        // the score counts up a little at a time, like an arcade machine
        if (this.shownScore === null || this.shownScore > s.score) this.shownScore = s.score;
        if (this.shownScore < s.score) this.shownScore = Math.min(s.score, this.shownScore + Math.max(10, Math.ceil((s.score - this.shownScore) * 0.12)));
        this.scoreText.setText(String(this.shownScore).padStart(6, '0'));
        // the gem counter gives a little bounce when it goes up
        if (this.shownGems !== null && s.gems !== this.shownGems) {
            this.tweens.killTweensOf(this.gemText);
            this.gemText.setScale(1.35);
            this.tweens.add({ targets: this.gemText, scale: 1, duration: 180, ease: 'Back.out' });
        }
        this.shownGems = s.gems;
        this.hearts.forEach((h, i) => h.setAlpha(i < s.hearts ? 1 : 0.2));
        this.shieldIcon.setVisible(level.player.shield);
        this.gemText.setText(`x${String(s.gems).padStart(2, '0')}`);
        // two-phone play has no lives and no clock: show who's playing instead
        const together = !!level.coop;
        this.livesText.setText(together ? `WITH ${level.coop.partnerName.toUpperCase()}` : `LIVES x${Math.max(0, s.lives)}`);
        this.timeLabel.setVisible(!together);
        this.timeText.setVisible(!together);
        const found = (this.save.crystals[s.world] || []).length;
        this.crystalIcons.forEach((c, i) => c.setAlpha(i < found ? 1 : 0.25));
        this.candleIcon.setAlpha(this.save.candles.includes(s.world) ? 1 : 0.25);
        this.worldText.setText(s.world);
        this.timeText.setText(String(Math.max(0, s.time))).setColor(s.time <= 60 ? '#ff6b6b' : '#ffffff');
        // power-up timers under the hearts
        const g = this.buffBars.clear();
        let bx = this.hearts[0].x - 4;
        for (const b of this.buffs) {
            const left = level.player[b.key];
            b.icon.setVisible(left > 0);
            if (left <= 0) continue;
            b.icon.setPosition(bx + 18, 124);
            g.fillStyle(0x000000, 0.5).fillRect(bx, 146, 40, 7);
            g.fillStyle(left < 2000 ? 0xff6b6b : 0xffe14d).fillRect(bx, 146, 40 * Math.min(1, left / b.total), 7);
            bx += 54;
        }
        const boss = level.boss;
        this.bossBar.setVisible(!!boss && !boss.defeated);
        if (boss) this.bossPips.forEach((p, i) => p.setFillStyle(i < 3 - boss.hits ? 0xff3b5c : 0x333333));
    }

    // a collected gem flies up into the gem counter
    flyGem(x, y) {
        const gem = this.add.sprite(x, y, 'gem', 0).setDepth(5);
        this.tweens.add({
            targets: gem, x: this.gemIcon.x, y: this.gemIcon.y, scale: 0.7, duration: 420, ease: 'Cubic.in',
            onComplete: () => {
                gem.destroy();
                this.tweens.killTweensOf(this.gemIcon);
                this.gemIcon.setScale(0.75);
                this.tweens.add({ targets: this.gemIcon, scale: 1.05, duration: 70, yoyo: true });
            },
        });
    }

    banner(title, sub = '', ms = 2000) {
        this.tweens.killTweensOf([this.bannerTitle, this.bannerSub]);
        this.bannerTitle.setText(title).setAlpha(0).setScale(0.8);
        this.bannerSub.setText(sub).setAlpha(0);
        this.tweens.add({ targets: this.bannerTitle, alpha: 1, scale: 1, duration: 220, ease: 'Back.out' });
        this.tweens.add({ targets: this.bannerSub, alpha: 1, duration: 220, delay: 100 });
        this.tweens.add({ targets: [this.bannerTitle, this.bannerSub], alpha: 0, duration: 350, delay: ms });
    }

    // a menu entry: white text that turns gold, with a tap sound
    item(container, x, y, label, onTap, size = 20) {
        const t = this.add.text(x, y, label, { ...VALUE, fontSize: size }).setOrigin(0.5).setPadding(18, 10, 18, 10)
            .setInteractive({ useHandCursor: true });
        t.on('pointerover', () => t.setColor(GOLD)).on('pointerout', () => t.setColor('#ffffff'));
        t.on('pointerdown', () => { sfx.select(); onTap(t); });
        container.add(t);
        return t;
    }

    // ------------------------------------------------------------------ pause ---
    togglePause() {
        const level = this.scene.get('Level');
        if (this.pausePanel) {
            this.pausePanel.destroy();
            this.pausePanel = null;
            this.scene.resume('Level');
            music.resume();
            return;
        }
        if (this.results || !this.scene.isActive('Level') || level.ended || level.dying) return;
        sfx.pause();
        this.scene.pause('Level');
        music.pause();
        const { width: w, height: h } = this.scale;
        const save = this.save;
        const panel = this.add.container(w / 2, h / 2);
        panel.add(this.add.rectangle(0, 0, w, h, 0x000000, 0.6).setInteractive());
        panel.add(this.add.rectangle(0, 0, 520, 470, 0x140d1f, 0.96).setStrokeStyle(4, 0xf5c542));
        panel.add(this.add.text(0, -190, 'PAUSED', { ...VALUE, fontSize: 30, color: GOLD }).setOrigin(0.5));
        this.item(panel, 0, -120, 'RESUME', () => this.togglePause());
        this.item(panel, 0, -65, 'RESTART LEVEL', () => {
            this.closePause();
            level.state.lives = Math.max(level.state.lives, 0);
            level.scene.restart({ level: level.levelIndex, state: level.state });
        });
        this.item(panel, 0, -10, `MUSIC: ${save.music === false ? 'OFF' : 'ON'}`, (t) => {
            save.music = save.music === false;
            setMusicVolume(save.music);
            writeSave(save);
            t.setText(`MUSIC: ${save.music ? 'ON' : 'OFF'}`);
        });
        this.item(panel, 0, 45, `SOUND: ${save.sound === false ? 'OFF' : 'ON'}`, (t) => {
            save.sound = save.sound === false;
            setSoundVolume(save.sound);
            writeSave(save);
            t.setText(`SOUND: ${save.sound ? 'ON' : 'OFF'}`);
        });
        this.item(panel, 0, 100, 'WORLD MAP', () => this.exitTo('WorldMap'));
        this.item(panel, 0, 155, 'QUIT TO TITLE', () => this.exitTo('Title', { skipSplash: true }));
        this.pausePanel = panel;
    }

    closePause() {
        this.pausePanel?.destroy();
        this.pausePanel = null;
        music.resume();
    }

    exitTo(scene, data) {
        this.closePause();
        this.scene.stop('Level');
        this.scene.start(scene, data);
    }

    // ---------------------------------------------------------------- results ---
    // the "course clear" card: score, gems, crystals, candle, time bonus and any new outfit
    showResults(r, onNext, onMap) {
        const { width: w, height: h } = this.scale;
        this.results = this.add.container(w / 2, h / 2).setAlpha(0);
        this.drawPad();
        const c = this.results;
        c.add(this.add.rectangle(0, 0, w, h, 0x000000, 0.55).setInteractive());
        c.add(this.add.rectangle(0, 0, 640, 500, 0x140d1f, 0.97).setStrokeStyle(5, 0xf5c542));
        c.add(this.add.text(0, -205, `${r.id} CLEAR!`, { ...VALUE, fontSize: 32, color: GOLD }).setOrigin(0.5));
        c.add(this.add.text(0, -165, r.name.toUpperCase(), { ...LABEL, fontSize: 13 }).setOrigin(0.5));
        const row = (y, label, value) => {
            c.add(this.add.text(-250, y, label, { ...LABEL, fontSize: 16 }).setOrigin(0, 0.5));
            c.add(this.add.text(250, y, value, { ...VALUE, fontSize: 18 }).setOrigin(1, 0.5));
        };
        row(-115, 'SCORE', String(r.score).padStart(6, '0'));
        row(-75, 'TIME BONUS', `+${r.timeBonus}`);
        row(-35, 'GEMS', `x${r.gems}`);
        c.add(this.add.text(-250, 5, 'CRYSTALS', { ...LABEL, fontSize: 16 }).setOrigin(0, 0.5));
        [0, 1, 2].forEach((i) => c.add(this.add.image(170 + i * 40, 5, 'gem_big').setScale(0.5).setAlpha(i < r.crystals ? 1 : 0.2)));
        c.add(this.add.text(-250, 45, 'CANDLE', { ...LABEL, fontSize: 16 }).setOrigin(0, 0.5));
        c.add(this.add.image(240, 45, 'candle').setScale(0.6).setAlpha(r.candle ? 1 : 0.2));
        if (r.unlocked) {
            c.add(this.add.text(-250, 100, 'NEW OUTFIT!', { ...LABEL, fontSize: 16, color: GOLD }).setOrigin(0, 0.5));
            c.add(this.add.text(-250, 126, r.unlocked.name, { ...LABEL, fontSize: 12 }).setOrigin(0, 0.5));
            const janika = r.unlocked.key.startsWith('janika_');
            c.add(this.add.sprite(220, 150, janika ? r.unlocked.key : `hero_${r.unlocked.key}`, janika ? 0 : 15).setScale(0.62).setOrigin(0.5, 1));
        }
        this.item(c, -150, 205, 'WORLD MAP', () => { this.results.destroy(); this.results = null; onMap(); }, 16);
        const next = this.item(c, 150, 205, r.last ? 'CONTINUE' : 'NEXT LEVEL', () => { this.results.destroy(); this.results = null; onNext(); }, 18);
        next.setColor(GOLD);
        this.tweens.add({ targets: next, scale: 1.08, duration: 500, yoyo: true, repeat: -1 });
        this.tweens.add({ targets: c, alpha: 1, duration: 300 });
    }
}
