import * as Phaser from 'phaser';
import { NAMES, FONT, TILE, CAKE_TEXT, FINAL_MESSAGE, janikaLook } from '../config.js';
import { sfx } from '../sfx.js';
import { music } from '../music.js';
import { writeSave } from '../save.js';

const SPEAKERS = {
    janani: { name: NAMES.hero, portrait: 'portrait_janani' },
    janika: { name: NAMES.twin, portrait: 'portrait_janika' },
    yuva: { name: NAMES.boss, portrait: 'portrait_yuva' },
    kitty: { name: 'Kitty', portrait: 'portrait_kitty' },
};

// The cutscenes. Each script is a list of steps that run one after another.
const SCRIPTS = {
    intro: {
        next: ['Level', { level: 0 }],
        steps: (s) => {
            const { w, gy } = s;
            const janani = s.actor(`hero_${s.outfit}`, -140, gy);
            const janika = s.actor(s.twin.tex, -260, gy);
            const kitty = s.actor('kitty', -360, gy + 4).setScale(1.2);
            const yuva = s.actor('boss', w + 220, gy - 320).setFlipX(true);
            return [
                () => { music.play('title'); return Promise.all([
                    s.walk(janani, w * 0.44, 2600, `${s.outfit}_walk`, `${s.outfit}_idle`),
                    s.walk(janika, w * 0.32, 2600, s.twin.walk, s.twin.idle),
                    s.walk(kitty, w * 0.2, 2600, 'kitty_walk', 'kitty_idle', true),
                ]); },
                () => s.say('janika', `${NAMES.hero}, look at this sunny day! And our birthday is almost here!`),
                () => s.say('janani', 'I know! Nothing could ruin today.'),
                async () => {
                    music.play('villain');
                    sfx.thunder();
                    s.cameras.main.flash(300, 255, 255, 255).shake(500, 0.01);
                    await s.wait(600);
                    yuva.setFrame(3);
                    await s.tween({ targets: yuva, x: w * 0.74, y: gy, duration: 700, ease: 'Quad.in' });
                    s.cameras.main.shake(250, 0.012);
                    yuva.play('boss_idle');
                },
                () => s.say('yuva', 'Hahaha! Not so fast, birthday girls!'),
                () => s.say('yuva', `${NAMES.twin} is coming with me. Want her back, ${NAMES.hero}? Come and get her!`),
                async () => {
                    yuva.setFrame(3);
                    sfx.whoosh();
                    await s.tween({ targets: yuva, x: janika.x + 140, y: gy - 150, duration: 450, yoyo: false, ease: 'Sine.out' });
                    s.trap(janika);
                    await s.tween({ targets: [janika, s.bubble], y: '-=110', duration: 500, ease: 'Sine.out' });
                },
                () => s.say('janika', `${NAMES.hero}! Help me!`),
                async () => {
                    sfx.whoosh();
                    await s.tween({ targets: [yuva, janika, s.bubble], x: `+=${w}`, y: '-=260', duration: 1400, ease: 'Sine.in' });
                    music.play('title');
                },
                () => s.say('kitty', 'Meow! Meow meow!'),
                () => s.say('janani', `Hold on, ${NAMES.twin}! Kitty and I are coming for you!`),
            ];
        },
    },
    // Yuva is beaten: Janika is free, the twins hug... and Yuva grabs Kitty instead
    world1end: {
        tint: 0xe6c8ff,
        next: ['Title', { message: 'WORLD 2: SAVE KITTY TOGETHER!', skipSplash: true }],
        steps: (s) => {
            const { w, gy } = s;
            const yuva = s.actor('boss', w * 0.78, gy).setFlipX(true).setFrame(6);
            const janika = s.actor(s.twin.tex, w * 0.6, gy - 150);
            const bubble = s.trap(janika, s.twin.idle);
            s.tweens.add({ targets: [janika, bubble], y: '-=14', duration: 900, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
            const janani = s.actor(`hero_${s.outfit}`, -140, gy);
            const kitty = s.actor('kitty', -260, gy + 4).setScale(1.2);
            return [
                () => { music.play('villain'); return Promise.all([
                    s.walk(janani, w * 0.36, 2200, `${s.outfit}_run`, `${s.outfit}_idle`),
                    s.walk(kitty, w * 0.22, 2200, 'kitty_walk', 'kitty_idle', true),
                ]); },
                () => s.say('yuva', 'Ow, ow, OW! Okay, okay... you win!'),
                () => s.say('janani', `Let my sister go, ${NAMES.boss}!`),
                async () => {
                    // the bubble pops and Janika drops safely to the ground
                    s.tweens.killTweensOf([janika, bubble]);
                    sfx.smash();
                    s.sparkle(bubble.x, bubble.y);
                    bubble.destroy();
                    await s.tween({ targets: janika, y: gy, duration: 450, ease: 'Bounce.out' });
                    music.play('title');
                },
                () => s.say('janika', `${NAMES.hero}! I knew you'd come for me!`),
                async () => {
                    // they run to each other and hug
                    await Promise.all([
                        s.walk(janika, w * 0.47, 600, s.twin.walk, s.twin.idle),
                        s.walk(janani, w * 0.43, 500, `${s.outfit}_walk`, `${s.outfit}_idle`),
                    ]);
                    janani.setVisible(false);
                    janika.setVisible(false);
                    const hug = s.actor('hug', w * 0.45, gy);
                    s.time.addEvent({ delay: 650, loop: true, callback: () => hug.setFrame(hug.frame.name ? 0 : 1) });
                    s.heartFx = s.hearts(hug.x, gy - 170);
                    s.janani = janani;
                    s.janika = janika;
                    s.hug = hug;
                    await s.wait(1200);
                },
                () => s.say('janani', 'I missed you so much!'),
                () => s.say('kitty', 'Meow! Meow!'),
                async () => {
                    // ...but Yuva isn't done yet
                    music.play('villain');
                    yuva.setFrame(0);
                    s.cameras.main.shake(250, 0.008);
                    await s.wait(300);
                },
                () => s.say('yuva', "Hmph! If I can't keep your sister... I'll take your little kitty!"),
                async () => {
                    yuva.setFrame(3);
                    sfx.whoosh();
                    await s.tween({ targets: yuva, x: kitty.x + 150, y: gy - 170, duration: 600, ease: 'Sine.out' });
                    const kb = s.trap(kitty, 'kitty_talk');
                    await s.tween({ targets: [kitty, kb], y: '-=120', duration: 500, ease: 'Sine.out' });
                    s.hug.setVisible(false);
                    s.heartFx.stop();
                    s.janani.setVisible(true).setFlipX(false);
                    s.janika.setVisible(true).setFlipX(false);
                    sfx.meow();
                    await s.tween({ targets: [yuva, kitty, kb], x: `+=${w * 1.2}`, y: '-=260', duration: 1500, ease: 'Sine.in' });
                },
                () => s.say('janika', 'Kitty! No!'),
                () => s.say('janani', `We'll get her back, ${NAMES.twin}. Together this time!`),
                () => s.say('janika', 'Grab your phone, sister. Let\'s go save Kitty!'),
            ];
        },
    },
    // World 2 begins: the twins plan their birthday party... and Yuva snatches Kitty
    world2intro: {
        next: ['Lobby'],
        steps: (s) => {
            const { w, gy } = s;
            const janani = s.actor(`hero_${s.outfit}`, -140, gy);
            const janika = s.actor(s.twin.tex, -260, gy);
            const kitty = s.actor('kitty', -380, gy + 4).setScale(1.2);
            const yuva = s.actor('boss', w + 220, gy - 320).setFlipX(true);
            return [
                () => { music.play('title'); return Promise.all([
                    s.walk(janani, w * 0.46, 2600, `${s.outfit}_walk`, `${s.outfit}_idle`),
                    s.walk(janika, w * 0.34, 2600, s.twin.walk, s.twin.idle),
                    s.walk(kitty, w * 0.22, 2600, 'kitty_walk', 'kitty_idle', true),
                ]); },
                () => s.say('janika', `${NAMES.hero}! Balloons, the cake, the music... our party is going to be perfect!`),
                () => s.say('janani', 'And Kitty gets the first slice!'),
                () => s.say('kitty', 'Meow!'),
                async () => {
                    music.play('villain');
                    sfx.thunder();
                    s.cameras.main.flash(300, 255, 255, 255).shake(500, 0.01);
                    await s.wait(500);
                    yuva.setFrame(3);
                    await s.tween({ targets: yuva, x: w * 0.74, y: gy, duration: 700, ease: 'Quad.in' });
                    s.cameras.main.shake(250, 0.012);
                    yuva.play('boss_idle');
                },
                () => s.say('yuva', "A party? And nobody invited ME? Then I'm taking the guest of honour!"),
                async () => {
                    yuva.setFrame(3);
                    sfx.whoosh();
                    await s.tween({ targets: yuva, x: kitty.x + 150, y: gy - 170, duration: 600, ease: 'Sine.out' });
                    const kb = s.trap(kitty, 'kitty_talk');
                    await s.tween({ targets: [kitty, kb], y: '-=120', duration: 500, ease: 'Sine.out' });
                    sfx.meow();
                    await s.tween({ targets: [yuva, kitty, kb], x: `+=${w * 1.3}`, y: '-=240', duration: 1500, ease: 'Sine.in' });
                    music.play('title');
                },
                () => s.say('janika', 'Kitty! He flew off toward the Crystal Cave!'),
                () => s.say('janani', "That cave is full of tricks. We'll only get through it together."),
                () => s.say('janika', "Then grab your phone, sister. Let's go save Kitty!"),
            ];
        },
    },
    // World 2 beaten: Kitty is free, Yuva says sorry... and it's party time
    world2end: {
        cave: true,
        next: ['Title', { message: `HAPPY BIRTHDAY ${NAMES.hero.toUpperCase()} & ${NAMES.twin.toUpperCase()}!`, skipSplash: true }],
        steps: (s) => {
            const { w, gy } = s;
            const yuva = s.actor('boss', w * 0.78, gy).setFlipX(true).setFrame(4);
            const kitty = s.actor('kitty', w * 0.62, gy - 160).setScale(1.2).play('kitty_talk');
            const bubble = s.trap(kitty, 'kitty_talk');
            s.tweens.add({ targets: [kitty, bubble], y: '-=12', duration: 900, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
            const janani = s.actor(`hero_${s.outfit}`, -140, gy);
            const janika = s.actor(s.twin.tex, -260, gy);
            return [
                () => { music.play('villain'); return Promise.all([
                    s.walk(janani, w * 0.36, 2200, `${s.outfit}_run`, `${s.outfit}_idle`),
                    s.walk(janika, w * 0.25, 2200, s.twin.walk, s.twin.idle),
                ]); },
                () => s.say('yuva', 'Okay, okay! You two win! Together you are unstoppable...'),
                () => s.say('janika', `Then give us back our Kitty, ${NAMES.boss}!`),
                async () => {
                    s.tweens.killTweensOf([kitty, bubble]);
                    sfx.smash();
                    s.sparkle(bubble.x, bubble.y);
                    bubble.destroy();
                    await s.tween({ targets: kitty, y: gy + 4, duration: 450, ease: 'Bounce.out' });
                    music.play('title');
                    kitty.play('kitty_walk').setFlipX(false);
                    await s.tween({ targets: kitty, x: w * 0.3, duration: 900 });
                    kitty.play('kitty_happy');
                    s.hearts(w * 0.3, gy - 140);
                },
                () => s.say('kitty', 'Meow! Meow meow!'),
                () => s.say('yuva', "I... I only wanted to be part of your birthday. Nobody ever invites the villain."),
                () => s.say('janani', 'You could have just asked, silly!'),
                () => s.say('janika', "It's our birthday. Everyone's invited. Even you!"),
                () => s.say('yuva', 'Really?! Then... I have a surprise for you two!'),
                () => s.party(),
                () => s.say('yuva', 'I baked it myself. Happy birthday, twins!'),
                () => s.say('kitty', 'Meow!'),
                () => s.finalMessage(),
            ];
        },
    },
};

export default class Story extends Phaser.Scene {
    constructor() {
        super('Story');
    }

    create(data) {
        this.input.enabled = true;
        this.replay = !!data.replay; // watched from the menu: go back to the menu afterwards
        this.done = false;      // the scene object is reused, so reset last story's state
        this.advance = null;
        const { width: w, height: h } = this.scale;
        this.w = w;
        this.gy = h - 205; // ground line sits above the dialogue box
        this.outfit = this.registry.get('save').outfit;
        this.twin = janikaLook(this.registry.get('save').janikaOutfit); // Janika in the outfit she picked
        this.script = SCRIPTS[data.script];

        const cave = this.script.cave ? 'cave_' : ''; // World 2 scenes happen in the Crystal Cave
        const bg = this.add.tileSprite(0, 0, w, h, `${cave}bg_meadow_wide`).setOrigin(0).setTileScale(h / 720, h / 720);
        if (this.script.tint) bg.setTint(this.script.tint);
        for (let x = 0; x < w + TILE; x += TILE) {
            this.add.image(x, this.gy + TILE, `${cave}ground_top`, (x / TILE) % 2).setOrigin(0, 1);
            for (let y = this.gy + TILE; y < h; y += TILE) this.add.image(x, y, `${cave}ground_dirt`).setOrigin(0);
        }
        this.buildBox();

        const skip = this.add.text(w - 16, 16, 'SKIP >>', { fontFamily: FONT, fontSize: 14, color: '#ffffff', stroke: '#000000', strokeThickness: 4 })
            .setOrigin(1, 0).setPadding(12).setDepth(60).setInteractive({ useHandCursor: true });
        skip.on('pointerdown', (p, x, y, e) => { e.stopPropagation(); this.finish(); });
        this.input.on('pointerdown', () => this.advance?.());
        this.input.keyboard.on('keydown', () => this.advance?.());

        this.cameras.main.fadeIn(500);
        this.run(this.script.steps(this));
    }

    async run(steps) {
        for (const step of steps) {
            if (this.done) return;
            await step();
        }
        this.finish();
    }

    finish() {
        if (this.done) return;
        this.done = true;
        // forced fade (works even if the opening fade-in is still running), then switch scenes
        this.cameras.main.fade(500, 0, 0, 0, true);
        if (this.script === SCRIPTS.world1end) {
            const save = this.registry.get('save');
            save.w2intro = true;
            writeSave(save);
        }
        this.time.delayedCall(550, () => {
            music.stop();
            if (this.replay) this.scene.start('Title', { skipSplash: true });
            else this.scene.start(...this.script.next);
        });
    }

    // ------------------------------------------------------------ helpers ---
    actor(key, x, y) {
        return this.add.sprite(x, y, key, 0).setOrigin(0.5, 1).setDepth(5).setScale(1.35);
    }

    wait(ms) {
        return new Promise((r) => this.time.delayedCall(ms, r));
    }

    tween(config) {
        return new Promise((r) => this.tweens.add({ ...config, onComplete: r }));
    }

    // walk/run across, then stand idle. Kitty's art faces left, so she flips to face right.
    async walk(sprite, toX, ms, anim, idle, facesLeft = false) {
        sprite.play(anim).setFlipX(facesLeft ? toX > sprite.x : toX < sprite.x);
        await this.tween({ targets: sprite, x: toX, duration: ms });
        sprite.play(idle);
    }

    // the glowing bubble Yuva traps someone in (returns the bubble)
    trap(sprite, anim = this.twin.idle) {
        this.bubble = this.add.graphics().setDepth(6);
        const r = sprite.displayHeight * 0.62;
        this.bubble.fillStyle(0xff9ad5, 0.22).fillCircle(0, 0, r);
        this.bubble.lineStyle(5, 0xffffff, 0.85).strokeCircle(0, 0, r);
        this.bubble.lineStyle(6, 0xffffff, 0.6).beginPath().arc(0, 0, r * 0.8, Math.PI * 1.1, Math.PI * 1.4).strokePath();
        this.bubble.setPosition(sprite.x, sprite.y - sprite.displayHeight * 0.45).setScale(0);
        this.tweens.add({ targets: this.bubble, scale: 1, duration: 300, ease: 'Back.out' });
        sprite.play(anim);
        return this.bubble;
    }

    // the party: Gemini's party scene with the cake, everyone gathered in front of it
    async party() {
        const { width: w, height: h } = this.scale;
        this.cameras.main.fadeOut(500);
        await this.wait(550);
        this.add.rectangle(0, 0, w, h, 0x2e6b2a).setOrigin(0).setDepth(20);
        // the party picture covers the screen, its grass lined up with the ground everyone stands on
        const k = Math.max(w / 1024, h / 572);
        this.add.image(w / 2, this.gy - 500 * k, 'party').setOrigin(0.5, 0).setScale(k).setDepth(20.5);
        // the twins, Kitty and Yuva (holding the cake) in front of the table
        const at = (key, x, frame = 0) => this.add.sprite(x, this.gy, key, frame).setOrigin(0.5, 1).setScale(1.35).setDepth(21);
        at(`hero_${this.outfit}`, w * 0.3, 15);
        at(this.twin.tex, w * 0.39, this.twin.peace);
        this.add.sprite(w * 0.22, this.gy + 4, 'kitty').setOrigin(0.5, 1).setScale(1.2).setDepth(21).setFlipX(true).play('kitty_happy');
        at('boss', w * 0.7, 11).setFlipX(true);
        const sign = this.add.text(w / 2, 120, CAKE_TEXT.toUpperCase(), {
            fontFamily: FONT, fontSize: 24, color: '#ffe14d', stroke: '#2a1640', strokeThickness: 8, align: 'center',
            wordWrap: { width: w - 120 },
        }).setOrigin(0.5).setDepth(22).setScale(0);
        this.tweens.add({ targets: sign, scale: 1, duration: 600, ease: 'Back.out' });
        this.add.particles(0, -10, 'px', {
            x: { min: 0, max: w }, speedY: { min: 80, max: 160 }, speedX: { min: -30, max: 30 }, lifespan: 6000, frequency: 40,
            tint: [0xff6b9d, 0xffe14d, 0x7dff8a, 0x8ad8ff, 0xc78bff], scale: { start: 1.6, end: 1 }, rotate: { min: 0, max: 360 },
        }).setDepth(23);
        sfx.win();
        music.play('birthday');
        this.cameras.main.fadeIn(600);
        await this.wait(1800);
    }

    // the birthday message, big on the screen, until a tap
    finalMessage() {
        const { width: w, height: h } = this.scale;
        this.add.rectangle(0, 0, w, h, 0x140d1f, 0.82).setOrigin(0).setDepth(40);
        const t = this.add.text(w / 2, h * 0.45, FINAL_MESSAGE, {
            fontFamily: FONT, fontSize: 22, color: '#ffffff', align: 'center', lineSpacing: 18, wordWrap: { width: Math.min(900, w - 120) },
        }).setOrigin(0.5).setDepth(41).setAlpha(0);
        this.tweens.add({ targets: t, alpha: 1, duration: 1500 });
        this.hearts(w / 2, h * 0.85).setDepth(41);
        const end = this.add.text(w / 2, h - 50, 'THE END  -  TAP TO CONTINUE', { fontFamily: FONT, fontSize: 12, color: '#f5c542' })
            .setOrigin(0.5).setDepth(41).setAlpha(0);
        this.tweens.add({ targets: end, alpha: 1, delay: 3000, duration: 800 });
        return new Promise((resolve) => this.time.delayedCall(3000, () => { this.advance = resolve; }));
    }

    // a burst of sparkles (the bubble popping)
    sparkle(x, y) {
        this.add.particles(x, y, 'px', {
            speed: { min: 120, max: 320 }, lifespan: 600, scale: { start: 1.6, end: 0 }, tint: [0xffffff, 0xff9ad5],
            emitting: false,
        }).setDepth(7).explode(40);
    }

    // little hearts floating up around the twins' hug
    hearts(x, y) {
        return this.add.particles(x, y, 'heart', {
            x: { min: -90, max: 90 }, speedY: { min: -70, max: -40 }, lifespan: 1800, frequency: 260,
            scale: { start: 0.35, end: 0.15 }, alpha: { start: 1, end: 0 },
        }).setDepth(7);
    }

    buildBox() {
        const { width: w, height: h } = this.scale;
        const bw = Math.min(1100, w - 40);
        const bh = 160;
        this.box = this.add.container(w / 2, h - bh / 2 - 14).setDepth(50).setVisible(false);
        const left = -bw / 2;
        this.portrait = this.add.image(left + 84, 0, 'portrait_janani').setDisplaySize(124, 124);
        this.nameText = this.add.text(left + 170, -bh / 2 + 20, '', { fontFamily: FONT, fontSize: 18, color: '#f5c542' });
        this.bodyText = this.add.text(left + 170, -bh / 2 + 56, '', {
            fontFamily: FONT, fontSize: 17, color: '#ffffff', lineSpacing: 12, wordWrap: { width: bw - 200 },
        });
        const more = this.add.triangle(bw / 2 - 26, bh / 2 - 22, 0, 0, 16, 0, 8, 10, 0xf5c542);
        this.tweens.add({ targets: more, y: '+=5', duration: 400, yoyo: true, repeat: -1 });
        this.box.add([
            this.add.rectangle(0, 0, bw, bh, 0x140d1f, 0.94).setStrokeStyle(4, 0xf5c542),
            this.add.rectangle(left + 84, 0, 132, 132, 0x2a1d40).setStrokeStyle(3, 0xffffff),
            this.portrait, this.nameText, this.bodyText, more,
        ]);
    }

    // show a line of dialogue, typing it out; a tap finishes the typing, the next tap continues
    say(who, text) {
        const sp = SPEAKERS[who];
        this.box.setVisible(true);
        this.portrait.setTexture(sp.portrait).setDisplaySize(124, 124);
        this.nameText.setText(sp.name.toUpperCase());
        this.bodyText.setText('');
        if (who === 'kitty') sfx.meow();
        let shown = 0;
        const typer = this.time.addEvent({
            delay: 28, repeat: text.length - 1, callback: () => {
                shown++;
                this.bodyText.setText(text.slice(0, shown));
                if (shown % 3 === 0) sfx.tick();
            },
        });
        return new Promise((resolve) => {
            this.advance = () => {
                if (shown < text.length) {
                    typer.remove();
                    shown = text.length;
                    this.bodyText.setText(text);
                    return;
                }
                this.advance = null;
                this.box.setVisible(false);
                resolve();
            };
        });
    }
}
