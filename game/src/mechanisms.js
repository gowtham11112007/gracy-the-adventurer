// World 2 teamwork pieces: pressure plates, crystal gates and bridges, twin crystal walls and power pedestals.
// Both phones run these from the same level data. A plate counts as pressed when either twin stands on it
// (this phone's twin from her physics, her sister from the reports in coop.js), so both phones agree.
import { TILE, FONT, NAMES } from './config.js';
import { sfx } from './sfx.js';
import { net } from './net.js';

export const POWERS = {
    jump: { name: 'HIGH JUMP', hint: 'Jump again in mid-air!', icon: 'balloon_pink' },
    strong: { name: 'STRENGTH', hint: 'Walk into boulders to smash them!', icon: 'boulder' },
};

export default class Mechanisms {
    constructor(level) {
        this.level = level;
        const def = level.def;
        this.me = level.coop ? net.me : 'janani';
        this.blocks = level.physics.add.staticGroup(); // gate, bridge and crystal-wall tiles

        this.plates = (def.plates || []).map(([col, row, id]) => {
            const x = col * TILE + TILE / 2;
            const y = row * TILE;
            const base = level.add.rectangle(x, y, 56, 8, 0x3a2a55).setOrigin(0.5, 1).setDepth(2.4);
            const top = level.add.rectangle(x, y - 6, 48, 10, 0xffd34d).setOrigin(0.5, 1).setDepth(2.5).setStrokeStyle(2, 0x7a5a10);
            return { x, y, id, top, pressed: false };
        });

        this.gates = (def.gates || []).map(([col, row, w, h, id, mode]) => {
            const tiles = [];
            for (let c = col; c < col + w; c++) {
                for (let r = row; r < row + h; r++) {
                    const key = mode === 'bridge' ? level.tx('tile_grass_float') : 'barrier_janika';
                    const t = this.blocks.create(c * TILE + TILE / 2, r * TILE + TILE / 2, key).setDepth(3);
                    if (mode !== 'bridge') t.setTint(0xffe27a); // golden crystal: a gate
                    tiles.push(t);
                }
            }
            const gate = { id, mode, tiles, latched: false, solid: true };
            this.setSolid(gate, mode !== 'bridge', true);
            return gate;
        });

        // twin crystal walls: solid for one twin, glowing see-through for the other
        for (const [col, row, h, who] of def.barriers || []) {
            for (let r = row; r < row + h; r++) {
                const t = this.blocks.create(col * TILE + TILE / 2, r * TILE + TILE / 2, `barrier_${who}`).setDepth(3);
                level.tweens.add({ targets: t, alpha: 0.7, duration: 900, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
                if (who === this.me) t.body.enable = false;
            }
        }

        this.pedestals = (def.pedestals || []).map(([col, row, power]) => {
            const x = col * TILE + TILE / 2;
            const y = row * TILE;
            level.add.image(x, y + 6, 'cave_deco_crystal_blue').setOrigin(0.5, 1).setScale(0.75).setDepth(1.9);
            const icon = level.add.image(x, y - 80, POWERS[power].icon).setDepth(4).setScale(power === 'jump' ? 0.6 : 0.8);
            level.tweens.add({ targets: icon, y: icon.y - 10, duration: 900, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
            level.add.text(x, y - 120, POWERS[power].name, { fontFamily: FONT, fontSize: 10, color: '#ffffff', stroke: '#2a1640', strokeThickness: 4 })
                .setOrigin(0.5).setDepth(4);
            return { x, y, power };
        });

        // the power each twin carries, shown over her head
        this.myIcon = level.add.image(0, 0, 'px').setDepth(9).setVisible(false);
        this.partnerIcon = level.add.image(0, 0, 'px').setDepth(9).setVisible(false);

        level.physics.add.collider(level.player, this.blocks);
        level.physics.add.collider(level.enemies, this.blocks);
        const off = net.on('latch', ({ id }) => this.latch(id));
        level.events.once('shutdown', off);
    }

    // where her sister's feet are (from her phone's reports), when she's standing up
    partnerFeet() {
        const s = this.level.coop?.partnerState;
        return s && this.level.coop.partnerHere && s.o === 1 ? s : null;
    }

    update() {
        const L = this.level;
        const p = L.player;
        const sis = this.partnerFeet();
        const on = (plate, x, y) => Math.abs(x - plate.x) < 30 && Math.abs(y - plate.y) < 10;
        for (const plate of this.plates) {
            const pressed = (p.body.blocked.down || p.body.touching.down) && on(plate, p.x, p.body.bottom) || (sis && on(plate, sis.x, sis.y));
            if (pressed !== plate.pressed) {
                plate.pressed = pressed;
                plate.top.setFillStyle(pressed ? 0x7dff8a : 0xffd34d).setScale(1, pressed ? 0.4 : 1);
                sfx.tick();
            }
        }
        for (const gate of this.gates) {
            const plates = this.plates.filter((pl) => pl.id === gate.id);
            if (gate.mode === 'hold') {
                const open = plates.some((pl) => pl.pressed);
                // never close a gate on top of her
                const inside = (t) => Math.abs(p.x - t.x) < 52 && p.body.top < t.y + 32 && p.body.bottom > t.y - 32;
                if (!open && !gate.solid && gate.tiles.some(inside)) continue;
                this.setSolid(gate, !open);
            } else if (!gate.latched && plates.length && plates.every((pl) => pl.pressed)) {
                this.latch(gate.id);
                net.send('latch', { id: gate.id });
            }
        }
        for (const ped of this.pedestals) {
            if (p.power !== ped.power && Math.abs(p.x - ped.x) < 34 && Math.abs(p.body.bottom - ped.y) < 12) {
                p.power = ped.power;
                sfx.power();
                L.fx.sparkle.explode(16, p.x, p.y - 60);
                L.hud()?.banner(POWERS[ped.power].name, POWERS[ped.power].hint, 1600);
            }
        }
        this.showIcon(this.myIcon, p.power, p.x, p.y - 150);
        const s = L.coop?.partnerState;
        this.showIcon(this.partnerIcon, L.coop?.partnerHere && s?.pw, L.coop?.partner.x, L.coop?.partner.y - 160);
    }

    showIcon(img, power, x, y) {
        img.setVisible(!!power);
        if (!power) return;
        img.setTexture(POWERS[power].icon).setScale(power === 'jump' ? 0.35 : 0.45).setPosition(x, y);
    }

    // 'once' gates open for good, 'bridge' gates appear for good
    latch(id) {
        for (const gate of this.gates) {
            if (gate.id !== id || gate.latched || gate.mode === 'hold') continue;
            gate.latched = true;
            this.setSolid(gate, gate.mode === 'bridge');
            sfx.checkpoint();
            this.level.hud()?.banner(gate.mode === 'bridge' ? 'A BRIDGE!' : 'IT OPENED!', `Great teamwork, ${NAMES.hero} & ${NAMES.twin}!`, 1600);
        }
    }

    setSolid(gate, solid, instant = false) {
        if (gate.solid === solid && !instant) return;
        gate.solid = solid;
        for (const t of gate.tiles) {
            t.body.enable = solid;
            this.level.tweens.killTweensOf(t);
            const alpha = solid ? 1 : gate.mode === 'bridge' ? 0 : 0.18;
            if (instant) t.setAlpha(alpha);
            else this.level.tweens.add({ targets: t, alpha, duration: 180 });
        }
        if (!instant) sfx.bump();
    }
}
