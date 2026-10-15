import * as Phaser from 'phaser';
import { FONT } from '../config.js';

// The other twin, as seen on this phone: copies what her phone reports about 10 times a second
// and glides between those reports so she moves smoothly.
export default class Partner extends Phaser.GameObjects.Sprite {
    constructor(scene, name) {
        super(scene, -500, -500, 'twin', 0);
        scene.add.existing(this);
        this.setOrigin(0.5, 1).setDepth(5.9).setVisible(false);
        this.label = scene.add.text(0, 0, name.toUpperCase(), { fontFamily: FONT, fontSize: 10, color: '#ffffff', stroke: '#3b2440', strokeThickness: 4 })
            .setOrigin(0.5, 1).setDepth(9).setVisible(false);
        this.target = null;
        this.once('destroy', () => this.label.destroy());
    }

    // a report from her phone: position, speed and exactly which picture she shows
    setState(s) {
        if (!this.target) this.setPosition(s.x, s.y); // first report: appear right there
        this.target = s;
        this.gotAt = this.scene.time.now;
    }

    update(dt) {
        const s = this.target;
        if (!s) return;
        // guess where she is now from her last speed (up to 150 ms ahead), then ease toward it
        const ahead = Math.min(this.scene.time.now - this.gotAt, 150) / 1000;
        const k = Math.min(1, dt / 70);
        this.x += (s.x + s.vx * ahead - this.x) * k;
        this.y += (s.y + s.vy * ahead - this.y) * k;
        if (this.scene.textures.exists(s.k)) this.setTexture(s.k, s.f);
        this.setFlipX(!!s.fl).setOrigin(0.5, s.o).setRotation(s.r || 0).setAlpha(s.a ?? 1).setVisible(true);
        this.label.setPosition(this.x, s.o === 0 ? this.y - 24 : this.y - 140).setVisible(true);
    }

    hide() {
        this.setVisible(false);
        this.label.setVisible(false);
    }
}
