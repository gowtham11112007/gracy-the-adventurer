import * as Phaser from 'phaser';
import manifest from '../manifest.json';
import { OUTFITS, JANIKA_OUTFITS, HERO_FRAMES, TWIN_FRAMES, JANIKA_OUTFIT_FRAMES, MOVES, FONT, TILE } from '../config.js';
import { loadSave } from '../save.js';

// Loads every sprite, creates the shared animations, then opens the title screen.
export default class Boot extends Phaser.Scene {
    constructor() {
        super('Boot');
    }

    preload() {
        const { width, height } = this.scale;
        const label = this.add.text(width / 2, height / 2, 'Loading...', { fontFamily: FONT, fontSize: 24, color: '#ffffff' })
            .setOrigin(0.5);
        this.load.on('progress', (p) => {
            label.setText(`Loading... ${Math.round(p * 100)}%`).setPosition(this.scale.width / 2, this.scale.height / 2);
        });

        for (const [key, info] of Object.entries(manifest)) {
            const url = `assets/${key}.png`;
            if (key === 'ground_top' || key === 'cave_ground_top') {
                // two tiles side by side, so the grass pattern alternates
                this.load.spritesheet(key, url, { frameWidth: TILE, frameHeight: info.height });
            } else if (info.frameWidth) {
                this.load.spritesheet(key, url, { frameWidth: info.frameWidth, frameHeight: info.frameHeight });
            } else {
                this.load.image(key, url);
            }
        }
    }

    create() {
        const anim = (key, sheet, frames, frameRate, repeat = -1) =>
            this.anims.create({ key, frames: this.anims.generateFrameNumbers(sheet, { frames }), frameRate, repeat });

        for (const { key } of OUTFITS) {
            anim(`${key}_idle`, `hero_${key}`, HERO_FRAMES.idle, 4);
            // outfits with Gemini's smooth 6-frame run use it; the others keep their 4-frame run
            if (this.textures.exists(`hero_${key}_moves`)) {
                const count = manifest[`hero_${key}_moves`].run ?? 6; // some outfits have a 5-frame run
                anim(`${key}_run`, `hero_${key}_moves`, MOVES.run.slice(0, count), 15 * count / 6);
            }
            else anim(`${key}_run`, `hero_${key}`, HERO_FRAMES.run, 11);
            anim(`${key}_walk`, `hero_${key}`, HERO_FRAMES.walk, 7);
        }
        anim('gem_spin', 'gem', [0, 1, 2, 1], 6);
        anim('mushroom_walk', 'mushroom', [0, 1, 2, 3, 4], 8);
        anim('bee_fly', 'bee', [0, 1, 2, 3, 4], 14);
        anim('snail_crawl', 'snail', [0, 1, 2, 3, 4], 5);
        // kitty strip: 0-3 sitting, 4 sit, 5 talk, 6 wave, 7 smile, 8 jump, 9-11 walk
        anim('kitty_idle', 'kitty', [0, 1, 2, 1, 0, 0], 3);
        anim('kitty_talk', 'kitty', [5, 4, 3, 4], 6);
        anim('kitty_happy', 'kitty', [6, 7], 3);
        anim('kitty_walk', 'kitty', [9, 10, 11, 10], 10);
        anim('kitty_run', 'kitty_run', [0, 1, 2, 3, 4, 5], 16);
        // Yuva: 0-1 idle, 2 wind-up, 3 jump, 4 sitting.  Janika: 0-1 idle, 2-4 and 7-8 walk, 5 and 9 run, 6 peace sign
        anim('boss_idle', 'boss', [0, 1], 2);
        anim('twin_idle', 'twin', TWIN_FRAMES.idle, 4);
        anim('twin_walk', 'hero_janika_moves', MOVES.run, 10); // her run, a bit slower, for cutscene walks
        // Janika as a playable twin (two-phone play)
        anim('janika_idle', 'twin', TWIN_FRAMES.idle, 4);
        anim('janika_run', 'hero_janika_moves', MOVES.run, 15);
        anim('janika_walk', 'hero_janika_moves', MOVES.run, 10);
        for (const { key } of JANIKA_OUTFITS.slice(1)) {
            anim(`${key}_idle`, key, JANIKA_OUTFIT_FRAMES.idle, 1);
            anim(`${key}_walk`, key, JANIKA_OUTFIT_FRAMES.walk, 8);
            anim(`${key}_run`, `hero_${key}_moves`, MOVES.run, 15);
        }

        // a 6px white square used for confetti, sparkles and dust
        const g = this.make.graphics({ x: 0, y: 0 }, false);
        g.fillStyle(0xffffff).fillRect(0, 0, 6, 6).generateTexture('px', 6, 6).destroy();

        this.makeMirroredBackground('bg_meadow');
        this.makeMirroredBackground('bg_cave', 'cave_bg_meadow_wide'); // the cave theme's backdrop

        this.registry.set('save', loadSave());
        this.registry.set('controls', { left: false, right: false, jump: false });
        this.scene.start('Title');
    }

    // Background + its mirror image side by side: repeats forever with no visible seam.
    makeMirroredBackground(key, name = `${key}_wide`) {
        const src = this.textures.get(key).getSourceImage();
        const tex = this.textures.createCanvas(name, src.width * 2, src.height);
        const ctx = tex.getContext();
        ctx.drawImage(src, 0, 0);
        ctx.save();
        ctx.scale(-1, 1);
        ctx.drawImage(src, -src.width * 2, 0);
        ctx.restore();
        tex.refresh();
    }
}
