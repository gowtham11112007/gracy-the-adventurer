import * as Phaser from 'phaser';

const DELAY = 12;   // frames Kitty lags behind Janani's path, so she copies her jumps a moment later
const GAP = 62;     // how far behind Janani she trots

// Kitty tags along behind Janani: walks when she walks, hops when she jumps, sits when she stops.
export default class Kitty extends Phaser.GameObjects.Sprite {
    constructor(scene, player) {
        super(scene, player.x - GAP, player.y, 'kitty', 0);
        this.player = player;
        this.trail = [];
        scene.add.existing(this);
        this.setOrigin(0.5, 1).setDepth(5.5).setScale(0.9);
        this.play('kitty_idle');
    }

    // jump straight to Janani (after a respawn)
    snap() {
        this.trail.length = 0;
        this.setPosition(this.player.x - GAP, this.player.y);
    }

    // Super Kitty (the Yuva fight): she turns shining silver-gray and helps Janani
    powerUp() {
        this.super = true;
        // shining silver-gray fur: her own art in grayscale, a little brighter, with a soft white glow
        this.enableFilters();
        if (this.filters) {
            this.filters.internal.addColorMatrix().colorMatrix.grayscale(1).brightness(1.25, true);
            this.filters.external.addGlow(0xffffff, 3, 0, 1, false, 10, 8);
        } else {
            this.setTint(0xb8bcc8); // no WebGL: a plain gray tint instead
        }
        this.aura = this.scene.add.graphics().setDepth(5.4);
        this.sparks = this.scene.add.particles(0, 0, 'px', {
            follow: this, followOffset: { y: -40 }, speed: { min: 20, max: 60 }, lifespan: 700, frequency: 90,
            scale: { start: 1, end: 0 }, tint: [0xffffff, 0xd8dcff],
        }).setDepth(5.6);
        this.once('destroy', () => { this.aura.destroy(); this.sparks.destroy(); });
    }

    // leap onto something (Yuva's head, a bomb), call `onHit` there, then trot back to Janani
    dash(x, y, ms, onHit) {
        this.busy = true;
        this.anims.stop();
        this.setFrame(8); // leaping
        this.setFlipX(x > this.x);
        const from = { x: this.x, y: this.y };
        const arc = { t: 0 };
        this.scene.tweens.add({
            targets: arc, t: 1, duration: ms, ease: 'Sine.inOut',
            onUpdate: () => this.setPosition(from.x + (x - from.x) * arc.t, from.y + (y - from.y) * arc.t - Math.sin(arc.t * Math.PI) * 120),
            onComplete: () => {
                onHit();
                this.scene.time.delayedCall(250, () => {
                    this.busy = false;
                    this.trail.length = 0;
                });
            },
        });
    }

    // happy wave at the end of a level
    celebrate() {
        this.happy = true;
        this.play('kitty_happy');
        this.scene.tweens.add({ targets: this, y: this.y - 40, duration: 220, yoyo: true, repeat: 2, ease: 'Quad.out' });
    }

    update() {
        if (this.aura) {
            const pulse = 0.22 + Math.sin(this.scene.time.now / 140) * 0.08;
            this.aura.clear().fillStyle(0xe8ecff, pulse).fillCircle(this.x, this.y - 34, 46);
        }
        if (this.happy || this.busy) return;
        const p = this.player;
        // while Janani swings on a rope, Kitty sits and waits, then catches up once she lands
        if (p.hanging) {
            this.waiting = true;
            this.anims.play('kitty_idle', true);
            return;
        }
        if (this.waiting) {
            if (!p.body.blocked.down) return;
            this.waiting = false;
            this.snap();
        }
        this.trail.push({ x: p.x, y: p.y, air: !p.body.blocked.down, side: p.flipX ? 1 : -1 });
        if (this.trail.length > DELAY) this.trail.shift();
        const t = this.trail[0];

        const prevX = this.x;
        const targetX = t.x + t.side * GAP;
        this.x += (targetX - this.x) * 0.18;
        this.y = t.y;

        const moving = Math.abs(this.x - prevX) > 0.8;
        if (this.wasAir && !t.air) {
            this.setScale(1.05, 0.75);
            this.scene.tweens.add({ targets: this, scaleX: 0.9, scaleY: 0.9, duration: 160, ease: 'Back.out' });
        }
        this.wasAir = t.air;
        if (t.air) {
            this.anims.stop();
            this.setFrame(8);                       // leaping
        } else if (moving) {
            // a gallop when keeping up with a running Janani, a trot when she walks
            this.anims.play(Math.abs(this.x - prevX) > 2.5 ? 'kitty_run' : 'kitty_walk', true);
        } else {
            this.anims.play('kitty_idle', true);
        }
        // Kitty's art faces left: flip when she moves right, or face Janani when sitting
        this.setFlipX(moving || t.air ? this.x > prevX : p.x > this.x);
    }
}
