import * as Phaser from 'phaser';
import { HERO_FRAMES, TWIN_FRAMES, JANIKA_OUTFIT_FRAMES, MOVES, PHYSICS } from '../config.js';
import { sfx } from '../sfx.js';
import manifest from '../manifest.json';

// Janani (or Janika in two-phone play): running, jumping, getting hurt, and power-ups.
// `outfit` is one of Janani's outfit keys, or one of Janika's ('janika', 'janika_denim', ...).
// The physics sprite itself is invisible; a "look" sprite copies it every frame and adds
// squash, stretch and lean, so those effects never change her hitbox.
export default class Player extends Phaser.Physics.Arcade.Sprite {
    constructor(scene, x, y, outfit) {
        const janikaOutfit = outfit.startsWith('janika_');
        const tex = outfit === 'janika' ? 'twin' : janikaOutfit ? outfit : `hero_${outfit}`;
        super(scene, x, y, tex, 0);
        this.outfit = outfit;
        this.tex = tex;
        this.F = outfit === 'janika' ? TWIN_FRAMES : janikaOutfit ? JANIKA_OUTFIT_FRAMES : HERO_FRAMES; // which frame is which pose
        scene.add.existing(this);
        scene.physics.add.existing(this);
        this.setOrigin(0.5, 1).setDepth(6).setVisible(false);
        // frames are 104x150 with her feet on the bottom edge; the hitbox is her body only
        this.body.setSize(40, 112).setOffset(32, 38);
        this.body.setMaxVelocityY(1100);
        this.body.setCollideWorldBounds(true); // the level's left and right edges are walls

        this.look = scene.add.sprite(x, y, tex, 0).setOrigin(0.5, 1).setDepth(6);
        this.squash = { x: 1, y: 1 };
        this.shieldGlow = scene.add.graphics().setDepth(6.5);
        this.balloon = scene.add.image(x, y, 'balloon_pink').setOrigin(0.5, 0).setDepth(5.9).setVisible(false);
        this.ghostTimer = 0;
        this.moves = scene.textures.exists(`hero_${outfit}_moves`) ? `hero_${outfit}_moves` : null; // smooth extra frames
        this.ropeKey = scene.textures.exists(`hero_${outfit}_rope`) ? `hero_${outfit}_rope` : null;
        this.ropePose = null;   // where her hands are on the rope (set by the level while she hangs)
        this.leapTime = 0;      // ms of the "leaping off the rope" pose after letting go
        this.airTime = 0;       // ms since she left the ground
        this.landTime = 0;      // ms left to show the landing crouch
        scene.events.on('postupdate', this.syncLook, this);
        this.once('destroy', () => {
            scene.events.off('postupdate', this.syncLook, this);
            this.look.destroy();
            this.shieldGlow.destroy();
            this.balloon.destroy();
        });

        this.coyote = 0;        // ms left to still jump after walking off a ledge
        this.jumpBuffer = 0;    // ms left on a jump pressed just before landing
        this.prevJump = false;
        this.jumping = false;
        this.jumpHold = 0;      // ms a jump keeps rising even if the button is let go (so a tap is a real jump)
        this.wasOnGround = true;
        this.fallSpeed = 0;     // speed just before landing, for the dust puff
        this.hurtTime = 0;      // ms of knockback (no control)
        this.invulnTime = 0;    // ms of flashing after a hit
        this.starTime = 0;      // ms of star invincibility
        this.floatTime = 0;     // ms of balloon power: double jump and gliding
        this.magnetTime = 0;    // ms of gem magnet
        this.airJumps = 0;
        this.shield = false;    // cupcake: survives one extra hit
        this.power = null;      // World 2 pedestal power: 'jump' (double jump) or 'strong' (smash boulders)
        this.frozen = false;    // cutscenes, death, level end
        this.hanging = null;    // the rope she's holding (the level moves her along it)
        this.wantsRelease = false;
    }

    update(controls, dt, time) {
        const body = this.body;
        this.hurtTime -= dt;
        this.invulnTime -= dt;
        this.starTime -= dt;
        this.floatTime -= dt;
        this.magnetTime -= dt;
        this.leapTime -= dt;
        this.time = time;
        this.setAlpha(this.invulnTime > 0 && Math.floor(this.invulnTime / 90) % 2 ? 0.35 : 1); // flashing after a hit
        if (this.frozen) return;
        if (this.hanging) {
            // on a rope: the only control is letting go with the jump button
            if (controls.jumpTap || (controls.jump && !this.prevJump)) this.wantsRelease = true;
            this.prevJump = controls.jump;
            return;
        }

        const onGround = body.blocked.down || body.touching.down;
        if (onGround && !this.wasOnGround) {
            this.scene.events.emit('player-land', this, this.fallSpeed);
            const hard = Phaser.Math.Clamp(this.fallSpeed / 1100, 0.3, 1);
            this.squash = { x: 1 + 0.25 * hard, y: 1 - 0.22 * hard };
        }
        if (onGround && !this.wasOnGround && this.fallSpeed > 420 && Math.abs(body.velocity.x) < 160) this.landTime = 90;
        this.landTime -= dt;
        this.airTime = onGround ? 0 : this.airTime + dt;
        if (onGround) this.airJumps = 1;
        this.wasOnGround = onGround;
        this.fallSpeed = body.velocity.y;
        this.coyote = onGround ? 140 : this.coyote - dt;
        const pressed = controls.jumpTap || (controls.jump && !this.prevJump);
        this.jumpBuffer = pressed ? 180 : this.jumpBuffer - dt;
        this.prevJump = controls.jump;
        this.jumpHold -= dt;

        let dir = (controls.right ? 1 : 0) - (controls.left ? 1 : 0);
        if (this.hurtTime > 0) {
            dir = 0;
        } else {
            // ease toward the target speed so turning feels smooth, a little looser in the air
            const target = dir * PHYSICS.runSpeed;
            const grip = onGround ? 14 : 7;
            body.velocity.x += (target - body.velocity.x) * Math.min(1, (grip * dt) / 1000);

            if (this.jumpBuffer > 0 && this.coyote > 0) {
                this.jump(PHYSICS.jumpVelocity);
            } else if (pressed && !onGround && (this.floatTime > 0 || this.power === 'jump') && this.airJumps > 0) {
                // balloon or High Jump power: one extra jump in mid-air
                this.airJumps--;
                this.jump(PHYSICS.jumpVelocity * 0.85);
                this.scene.events.emit('player-airjump', this);
            }
            // a tap gives almost the full jump; holding the button adds a little more height
            if (this.jumping && !controls.jump && this.jumpHold <= 0 && body.velocity.y < -520) body.velocity.y = -520;
            if (body.velocity.y >= 0) this.jumping = false;
            // balloon power: hold jump while falling to drift down gently
            if (this.floatTime > 0 && controls.jump && body.velocity.y > 160) body.velocity.y = 160;
        }
        if (dir !== 0) this.setFlipX(dir < 0);

        this.animate(onGround);

        if (this.starTime > 0) {
            this.setTint(Phaser.Display.Color.HSVToRGB((time / 500) % 1, 0.45, 1).color);
        } else {
            this.clearTint();
        }
    }

    jump(speed) {
        this.body.velocity.y = -speed;
        this.jumpBuffer = this.coyote = 0;
        this.jumping = true;
        this.jumpHold = 300;
        this.airTime = 0;
        this.squash = { x: 0.82, y: 1.18 }; // stretch upward on take-off
        sfx.jump();
        this.scene.events.emit('player-jump', this);
    }

    // copy the physics sprite onto the visible one, adding squash/stretch, lean and power-up visuals
    syncLook() {
        const look = this.look;
        if (!look.active) return;
        this.squash.x += (1 - this.squash.x) * 0.2;
        this.squash.y += (1 - this.squash.y) * 0.2;
        const body = this.body;
        const running = body && body.blocked.down && !this.hanging && !this.frozen;
        const speed = body ? Math.abs(body.velocity.x) : 0;
        const lean = running ? Phaser.Math.Clamp(body.velocity.x / 300, -1, 1) * 4 : 0;
        // a light bounce in her step while running
        const bob = running && speed > 160 ? -Math.abs(Math.sin((this.time || 0) / 75)) * 3 : 0;
        if (this.hanging && this.ropePose && this.ropeKey) {
            const r = this.ropePose;
            look.setTexture(this.ropeKey, r.frame).setOrigin(0.5, 0).setPosition(r.x, r.y - 6)
                .setFlipX(this.flipX).setAlpha(this.alpha).setDepth(this.depth).setRotation(-r.angle).setScale(1);
            this.shieldGlow.clear();
            this.balloon.setVisible(false);
            return;
        }
        // just let go of a rope: her leap pose (frame 3 of the rope strip), feet where her feet are
        if (this.leapTime > 0 && this.ropeKey && body && !body.blocked.down && !this.frozen) {
            const feet = manifest[this.ropeKey].leapBottom / 200;
            look.setTexture(this.ropeKey, 3).setOrigin(0.5, feet).setPosition(this.x, this.y).setRotation(0)
                .setFlipX(this.flipX).setAlpha(this.alpha).setScale(1);
            return;
        }
        look.setOrigin(0.5, 1);
        look.setTexture(this.texture.key, this.frame.name)
            .setPosition(this.x, this.y + bob)
            .setFlipX(this.flipX)
            .setAlpha(this.alpha)
            .setDepth(this.depth)
            .setAngle(this.angle + lean)
            .setScale(this.squash.x, this.squash.y);
        if (this.isTinted) look.setTint(this.tintTopLeft);
        else look.clearTint();

        // afterimages: a fading trail during star power or a fast fall
        const fastFall = body && body.velocity.y > 900;
        if ((this.starTime > 0 || fastFall) && !this.frozen && (this.ghostTimer -= 16) <= 0) {
            this.ghostTimer = 55;
            const ghost = this.scene.add.image(look.x, look.y, this.texture.key, this.frame.name)
                .setOrigin(0.5, 1).setFlipX(look.flipX).setScale(look.scaleX, look.scaleY).setDepth(5.8).setAlpha(0.45);
            if (this.starTime > 0) ghost.setTint(Phaser.Display.Color.HSVToRGB(((this.time || 0) / 500) % 1, 0.6, 1).color);
            this.scene.tweens.add({ targets: ghost, alpha: 0, duration: 260, onComplete: () => ghost.destroy() });
        }

        // glowing pink bubble while the cupcake shield is up
        const g = this.shieldGlow.clear();
        if (this.shield && !this.frozen) {
            const pulse = 0.18 + Math.sin((this.time || 0) / 160) * 0.06;
            g.fillStyle(0xff9ad5, pulse).fillCircle(this.x, this.y - 64, 78);
            g.lineStyle(3, 0xffffff, 0.7).strokeCircle(this.x, this.y - 64, 78);
        }
        // the balloon she holds while it lasts (it blinks when about to run out)
        const holding = this.floatTime > 0 && !this.frozen;
        this.balloon.setVisible(holding && !(this.floatTime < 2000 && Math.floor(this.floatTime / 120) % 2));
        if (holding) {
            const side = this.flipX ? -1 : 1;
            this.balloon.setPosition(this.x + side * 26, this.y - 210 + Math.sin((this.time || 0) / 300) * 5).setAngle(side * -6);
        }
    }

    animate(onGround) {
        const vx = Math.abs(this.body.velocity.x);
        const vy = this.body.velocity.y;
        if (this.hurtTime > 0) return this.pose(this.F.hurt);
        if (!onGround) {
            if (!this.moves) return this.pose(vy < -220 ? this.F.rise : vy < 220 ? this.F.peak : this.F.fall);
            // take-off for the first moments of a jump, then rising, the tucked top, and falling
            const f = this.jumping && this.airTime < 110 ? MOVES.takeoff
                : vy < -260 ? MOVES.rise : vy < 260 ? MOVES.peak : MOVES.fall;
            return this.pose(f, this.moves);
        }
        if (this.landTime > 0 && this.moves) return this.pose(MOVES.land, this.moves);
        if (vx > 160) {
            this.anims.play(`${this.outfit}_run`, true);
            this.anims.timeScale = Phaser.Math.Clamp(vx / 260, 0.8, 1.3); // legs keep pace with her speed
            return;
        }
        this.anims.timeScale = 1;
        if (vx > 25) return this.anims.play(`${this.outfit}_walk`, true);
        this.anims.play(`${this.outfit}_idle`, true);
    }

    pose(frame, key = this.tex) {
        this.anims.stop();
        this.setTexture(key, frame);
    }

    // pushed away from whatever hit her, then a moment of flashing safety
    knockback(fromX) {
        this.hurtTime = 350;
        this.invulnTime = 2000;
        this.body.velocity.x = (this.x < fromX ? -1 : 1) * 260;
        this.body.velocity.y = -420;
    }

    get safe() {
        return this.invulnTime > 0 || this.starTime > 0;
    }
}
