import * as Phaser from 'phaser';
import { sfx } from '../sfx.js';

// Boss strip frames for each mood (see tools/prepare_sprites.py):
// confident at first, crying after the first stomp, dizzy after the second.
const FRAMES = [
    { idle: 0, windup: 2, throw: 5, jump: 3 },
    { idle: 6, windup: 8, throw: 9, jump: 10 },
    { idle: 7, windup: 8, throw: 9, jump: 10 },
];

// Yuva: throws bombs at Janani, leaps across the arena, and needs three stomps on the head.
export default class Boss extends Phaser.Physics.Arcade.Sprite {
    constructor(scene, x, y, arena) {
        super(scene, x, y, 'boss', 3);
        this.arena = arena; // { left, right } in pixels
        this.hits = 0;
        this.mode = 'enter';
        this.timer = 0;
        this.invuln = 0;
        this.defeated = false;
        scene.add.existing(this);
        scene.physics.add.existing(this);
        this.setOrigin(0.5, 1).setDepth(5);
        // frames are 210x190 with his feet on the bottom edge; the hitbox is his body
        this.body.setSize(72, 150).setOffset(69, 40);
        this.body.setCollideWorldBounds(true);
    }

    get frames() {
        return FRAMES[Math.min(this.hits, 2)];
    }

    update(dt) {
        if (this.defeated || this.remote) return; // remote: run by the other phone (two-phone play)
        const p = this.scene.bossTarget();
        const onGround = this.body.blocked.down;
        this.invuln -= dt;
        this.setAlpha(this.invuln > 0 && Math.floor(this.invuln / 80) % 2 ? 0.4 : 1);
        if (this.mode !== 'jump') this.setFlipX(p.x < this.x); // his art faces right
        this.timer -= dt;

        switch (this.mode) {
            case 'enter':       // dropping into the arena
                if (onGround) {
                    this.landed();
                    this.setMode('idle', 900);
                }
                break;
            case 'idle':
                this.setFrame(this.frames.idle);
                if (onGround) this.body.velocity.x = 0;
                if (this.timer <= 0) {
                    const leap = Math.random() < 0.28 + this.hits * 0.12;
                    this.setMode(leap ? 'jump' : 'windup', 650 - this.hits * 100);
                    if (leap) this.leap();
                }
                break;
            case 'stunned':     // Super Kitty pounced on him: dizzy, wide open for a stomp
                this.setFrame(7);
                if (onGround) this.body.velocity.x = 0;
                if (this.timer <= 0) this.setMode('idle', 900);
                break;
            case 'windup':
                this.setFrame(this.frames.windup);
                if (this.timer <= 0) {
                    this.setMode('throw', 380);
                    this.setFrame(this.frames.throw);
                    // more bombs, faster, the more upset he gets
                    for (let i = 0; i <= Math.min(this.hits, 1); i++) { // one bomb, then two once he's upset
                        this.scene.time.delayedCall(i * 170, () => !this.defeated && this.scene.throwBomb(this, p.x + (i - this.hits / 2) * 110));
                    }
                }
                break;
            case 'throw':
                if (this.timer <= 0) this.setMode('idle', 1800 - this.hits * 200);
                break;
            case 'jump':
                this.setFrame(this.frames.jump);
                if (onGround && this.body.velocity.y >= 0 && this.timer <= 0) {
                    this.landed();
                    this.setMode('idle', 700 - this.hits * 150);
                }
                break;
            case 'hurt':
                if (onGround && this.timer <= 0) this.setMode('idle', 600);
                break;
        }
    }

    setMode(mode, ms) {
        this.mode = mode;
        this.timer = ms;
    }

    // big leap to the far side of the arena
    leap() {
        const mid = (this.arena.left + this.arena.right) / 2;
        const target = this.x < mid ? this.arena.right - 160 : this.arena.left + 160;
        this.setFlipX(target < this.x);
        this.body.setVelocity((target - this.x) / 1.2, -1000);
        this.timer = 300;
        sfx.whoosh();
    }

    landed() {
        this.scene.cameras.main.shake(220, 0.01);
        this.scene.fx.dust.explode(18, this.x, this.y);
        sfx.bump();
    }

    // dizzy for a moment (not while he's dropping in or mid-leap); returns whether it worked
    stun(ms) {
        if (this.defeated || this.mode === 'enter' || this.mode === 'jump') return false;
        this.setMode('stunned', ms);
        this.body.velocity.x = 0;
        return true;
    }

    // stomped on the head: returns true when that was the last hit
    hit() {
        if (this.invuln > 0 || this.defeated) return false;
        this.hits++;
        this.invuln = 1500;
        sfx.stomp();
        if (this.hits >= 3) {
            this.defeated = true;
            this.body.setVelocity(0, 0);
            this.setFrame(4); // sitting, dizzy
            this.setAlpha(1);
            return true;
        }
        // bounce away from Janani, crying
        this.setFrame(FRAMES[this.hits].idle);
        const away = this.x < this.scene.player.x ? -1 : 1;
        this.body.setVelocity(away * 320, -620);
        this.setMode('hurt', 400);
        return false;
    }
}
