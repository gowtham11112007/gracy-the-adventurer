import * as Phaser from 'phaser';

// Walkers turn at walls and ledges; hoppers also bounce; bees fly a wave; divers swoop at Janani.
const KINDS = {
    mushroom: { tex: 'mushroom', anim: 'mushroom_walk', size: [48, 54, 14, 18], speed: 70 },
    hopper: { tex: 'mushroom', anim: 'mushroom_walk', size: [48, 54, 14, 18], speed: 85, hops: true },
    snail: { tex: 'snail', anim: 'snail_crawl', size: [66, 42, 17, 22], speed: 42, facesRight: true, spiky: true },
    bee: { tex: 'bee', anim: 'bee_fly', size: [34, 28, 15, 19], flies: true, facesRight: true }, // small hitbox: only its body stings
    diver: { tex: 'bee', anim: 'bee_fly', size: [34, 28, 15, 19], flies: true, facesRight: true, dives: true },
};

export default class Enemy extends Phaser.Physics.Arcade.Sprite {
    constructor(scene, x, y, kind) {
        const info = KINDS[kind];
        super(scene, x, y, info.tex, 0);
        this.kind = kind;
        this.info = info;
        this.dead = false;
        this.dir = -1;
        scene.add.existing(this);
        scene.physics.add.existing(this);
        this.setOrigin(0.5, 1).setDepth(5);
        const [w, h, ox, oy] = info.size;
        this.body.setSize(w, h).setOffset(ox, oy);
        this.play(info.anim);
        this.hopTimer = 800 + Math.random() * 900;
        if (info.flies) {
            this.body.setAllowGravity(false);
            this.home = { x, y };
            this.t = Math.random() * 6;
            this.mode = 'hover';
        }
        if (info.dives) this.setScale(1.15); // the diving bee is a bit bigger
    }

    // the snail's spiky shell can't be stomped
    get stompable() {
        return !this.info.spiky;
    }

    update(dt) {
        if (this.dead || this.remote) return; // remote: moved by the other phone (two-phone play)
        const body = this.body;
        if (this.info.flies) return this.fly(dt);

        if (body.blocked.left) this.dir = 1;
        else if (body.blocked.right) this.dir = -1;
        else if (body.blocked.down && !this.scene.isSolidAt(this.x + this.dir * (body.halfWidth + 6), this.y + 10)) {
            this.dir *= -1; // don't walk off ledges
        }
        body.velocity.x = this.dir * this.info.speed;
        if (this.info.facesRight) this.setFlipX(this.dir < 0);

        if (this.info.hops && body.blocked.down) {
            this.hopTimer -= dt;
            if (this.hopTimer <= 0) {
                body.velocity.y = -560;
                this.hopTimer = 900 + Math.random() * 900;
            }
        }
    }

    fly(dt) {
        const body = this.body;
        const p = this.scene.player;
        this.t += dt / 1000;
        if (this.mode === 'hover') {
            const range = this.info.dives ? 60 : 100;
            const tx = this.home.x + Math.sin(this.t * 0.7) * range; // slow, lazy loops
            const ty = this.home.y + Math.sin(this.t * 2) * 18;
            body.velocity.set((tx - this.x) * 6, (ty - this.y) * 6);
            this.setFlipX(Math.cos(this.t * 0.7) < 0);
            this.rest = (this.rest || 0) - dt;
            // a diver that spots Janani below shakes for a moment, then swoops at where she was
            if (this.info.dives && this.rest <= 0 && Math.abs(p.x - this.x) < 240 && p.y > this.y + 40 && !p.frozen) {
                this.mode = 'aim';
                this.modeTime = 1000; // a long, clear warning shake before it dives
                this.target = { x: p.x, y: p.y - 40 };
            }
        } else if (this.mode === 'aim') {
            body.velocity.set(0, 0);
            this.x += Math.sin(this.t * 80) * 1.5;
            this.setFlipX(this.target.x < this.x);
            if ((this.modeTime -= dt) <= 0) {
                this.mode = 'dive';
                this.modeTime = 1100;
                this.scene.physics.moveTo(this, this.target.x, this.target.y, 340);
            }
        } else if (this.mode === 'dive') {
            if ((this.modeTime -= dt) <= 0 || Phaser.Math.Distance.Between(this.x, this.y, this.target.x, this.target.y) < 20) {
                this.mode = 'return';
            }
        } else if (this.mode === 'return') {
            this.scene.physics.moveTo(this, this.home.x, this.home.y, 230);
            this.setFlipX(this.home.x < this.x);
            if (Phaser.Math.Distance.Between(this.x, this.y, this.home.x, this.home.y) < 12) {
                this.mode = 'hover';
                this.rest = 3000; // a breather before it can dive again
            }
        }
    }

    // last frame of every enemy strip is its defeated pose
    defeat(stomped = false) {
        if (this.dead) return;
        this.dead = true;
        this.anims.stop();
        this.setFrame(5);
        this.body.enable = false;
        if (this.info.flies) {
            this.scene.tweens.add({ targets: this, y: this.y + 300, angle: 200, alpha: 0, duration: 800, onComplete: () => this.destroy() });
            return;
        }
        // squashed flat, then gone
        if (stomped) this.scene.tweens.add({ targets: this, scaleY: 0.55, scaleX: 1.2, duration: 90 });
        this.scene.tweens.add({ targets: this, alpha: 0, delay: 500, duration: 300, onComplete: () => this.destroy() });
    }
}
