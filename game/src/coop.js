// Two-phone co-op glue for a Level.
// Each phone runs its own twin and reports her to the other phone about 10 times a second.
// The room maker's phone (the host) runs the enemies and reports them too; the other phone just shows them.
// Gems taken, enemies stomped and blocks broken are told to the other phone so both worlds match.
import { net } from './net.js';
import { NAMES, FONT } from './config.js';
import Partner from './objects/Partner.js';

const SEND_MS = 100;

export default class Coop {
    constructor(level) {
        this.level = level;
        this.host = net.host;
        this.sendTimer = 0;
        this.lastSent = '';
        this.lastSentAt = 0;
        this.atGate = false;
        this.waiting = false;
        this.partnerName = net.me === 'janika' ? NAMES.hero : NAMES.twin;
        this.partner = new Partner(level, this.partnerName);
        this.partnerState = null;
        this.enemyTargets = new Map();

        // her sister's head is a step: an invisible ledge that follows her head (only landed on from above)
        this.head = level.add.zone(-999, -999, 44, 14);
        level.physics.add.existing(this.head);
        this.head.body.setAllowGravity(false).setImmovable(true);
        this.head.body.checkCollision = { none: false, up: true, down: false, left: false, right: false };
        level.physics.add.collider(level.player, this.head, () => { this.onHead = true; });
        this.lastPartnerX = null;

        // the same id on both phones for each gem and enemy (both build the level in the same order)
        level.items.getChildren().forEach((o) => o.setData('nid', `${Math.round(o.x)},${Math.round(o.y)}`));
        level.enemies.getChildren().forEach((e, i) => {
            e.nid = i;
            if (!this.host) {
                e.remote = true; // moved by the host's reports, not by its own brain
                e.body.setAllowGravity(false);
                e.body.setVelocity(0, 0);
            }
        });

        this.offs = [
            net.on('s', (s) => this.onState(s)),
            net.on('take', ({ id }) => this.removeItem(id)),
            net.on('kill', ({ id }) => this.enemy(id)?.defeat(true)),
            net.on('block', ({ cell }) => level.remoteBlock(cell)),
            net.on('presence', () => this.checkPartner()),
            // the team boss fight (the host's phone runs Yuva)
            net.on('bomb', ({ x, y, tx }) => level.throwBomb({ x, y }, tx, false)),
            net.on('bossStomp', () => this.host && level.stompBoss()),
            net.on('bossDown', () => {
                const boss = level.boss;
                if (this.host || !boss || boss.defeated) return;
                boss.defeated = true;
                boss.setFrame(4); // sitting, dizzy
                level.bossDefeated();
            }),
            net.on('status', () => this.checkPartner()),
        ];

        // "waiting for your sister" sign, shown whenever her phone isn't connected
        const { width: w, height: h } = level.scale;
        this.waitSign = level.add.text(w / 2, h * 0.4, '', {
            fontFamily: FONT, fontSize: 20, color: '#ffffff', stroke: '#3b2440', strokeThickness: 8, align: 'center',
        }).setOrigin(0.5).setScrollFactor(0).setDepth(900).setVisible(false);
        level.tweens.add({ targets: this.waitSign, alpha: 0.5, duration: 600, yoyo: true, repeat: -1 });
        level.events.once('shutdown', () => this.offs.forEach((off) => off()));
        this.checkPartner();
    }

    // ------------------------------------------------------------- partner ---
    get partnerHere() {
        return net.connected && !!net.partner();
    }

    // pause the level while her phone is away (closed app, lost signal); carry on when she's back
    checkPartner() {
        const L = this.level;
        const here = this.partnerHere;
        this.waitSign.setText(net.connected ? `WAITING FOR ${this.partnerName.toUpperCase()}...` : 'RECONNECTING...').setVisible(!here);
        if (!here) this.partner.hide();
        const waiting = !here && L.started && !L.ended;
        if (waiting === this.waiting) return;
        this.waiting = waiting;
        if (waiting) L.physics.pause();
        else L.physics.resume();
    }

    onState(s) {
        this.partnerState = s;
        this.partner.setState(s);
        // the host's report also says where every enemy is
        if (s.en) for (const [id, x, y, fl] of s.en) this.enemyTargets.set(id, { x, y, fl });
        if (s.g && this.atGate && !this.level.ended) this.level.finish();
        // the host's report also says where Yuva is and how he looks
        const boss = this.level.boss;
        if (s.bs && boss && boss.remote && !boss.defeated) {
            const [x, y, frame, flip, hits] = s.bs;
            this.bossTarget = { x, y };
            boss.setFrame(frame).setFlipX(!!flip);
            boss.hits = hits;
        }
    }

    enemy(id) {
        return this.level.enemies.getChildren().find((e) => e.nid === id);
    }

    removeItem(id) {
        const item = this.level.items.getChildren().find((o) => o.getData('nid') === id);
        if (!item) return;
        this.level.fx.sparkle.explode(6, item.x, item.y);
        item.destroy();
    }

    // ------------------------------------------------------------ each frame ---
    update(dt) {
        const L = this.level;
        this.checkPartner();
        this.partner.update(dt);
        // keep the head-step on her head, and carry this twin along when she stands on it
        const s = this.partnerState;
        const standing = s && s.o === 1 && this.partnerHere;
        this.head.body.reset(standing ? this.partner.x : -999, standing ? this.partner.y - 112 + 7 : -999);
        if (this.onHead && this.lastPartnerX !== null && L.player.body.touching.down) L.player.x += this.partner.x - this.lastPartnerX;
        this.lastPartnerX = standing ? this.partner.x : null;
        this.onHead = false;
        // Yuva on the other phone glides to where the host says he is
        if (L.boss?.remote && this.bossTarget) {
            L.boss.x += (this.bossTarget.x - L.boss.x) * Math.min(1, dt / 80);
            L.boss.y += (this.bossTarget.y - L.boss.y) * Math.min(1, dt / 80);
        }
        if (!this.host) {
            // glide the host's enemies to where it says they are
            for (const e of L.enemies.getChildren()) {
                const t = this.enemyTargets.get(e.nid);
                if (!t || e.dead) continue;
                e.x += (t.x - e.x) * Math.min(1, dt / 80);
                e.y += (t.y - e.y) * Math.min(1, dt / 80);
                e.setFlipX(!!t.fl);
            }
        }
        if ((this.sendTimer -= dt) > 0) return;
        this.sendTimer = SEND_MS;
        this.sendState();
    }

    // what this phone's twin looks like right now (only sent when something changed, or once a second)
    sendState() {
        const p = this.level.player;
        const look = p.look;
        const s = {
            x: Math.round(look.x), y: Math.round(look.y),
            vx: Math.round(p.body.velocity.x), vy: Math.round(p.body.velocity.y),
            k: look.texture.key, f: look.frame.name, fl: look.flipX ? 1 : 0, o: look.originY,
            r: Math.round(look.rotation * 100) / 100, a: Math.round(look.alpha * 10) / 10, g: this.atGate ? 1 : 0,
            pw: p.power || 0,
        };
        const boss = this.level.boss;
        if (this.host && boss && !boss.defeated) s.bs = [Math.round(boss.x), Math.round(boss.y), boss.frame.name, boss.flipX ? 1 : 0, boss.hits];
        if (this.host) {
            s.en = this.level.enemies.getChildren().filter((e) => !e.dead)
                .map((e) => [e.nid, Math.round(e.x), Math.round(e.y), e.flipX ? 1 : 0]);
        }
        const text = JSON.stringify(s);
        const now = this.level.time.now;
        if (text === this.lastSent && now - this.lastSentAt < 1000) return;
        this.lastSent = text;
        this.lastSentAt = now;
        net.send('s', s);
    }

    // ------------------------------------------------------------- the level ---
    // the finish needs both twins: the first one waits at the gate for her sister
    reachGate() {
        if (this.atGate) return;
        this.atGate = true;
        const L = this.level;
        const p = L.player;
        p.frozen = true;
        p.body.setVelocityX(0);
        p.pose(p.F.victory);
        this.sendState();
        if (this.partnerState?.g) L.finish();
        else L.hud()?.banner('YOU MADE IT!', `Wait for ${this.partnerName}`, 2500);
    }
}
