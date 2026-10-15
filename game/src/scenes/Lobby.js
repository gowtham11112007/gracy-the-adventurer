import * as Phaser from 'phaser';
import { NAMES, FONT, UNLOCK_ALL_LEVELS } from '../config.js';
import { COOP_LEVELS } from '../levels.js';
import { writeSave } from '../save.js';
import { net } from '../net.js';
import { sfx } from '../sfx.js';
import { music } from '../music.js';

const GOLD = '#f5c542';
const TEXT = { fontFamily: FONT, fontSize: 22, color: '#ffffff', stroke: '#000000', strokeThickness: 4 };
const TWINS = [
    { key: 'janani', name: NAMES.hero, portrait: 'portrait_janani' },
    { key: 'janika', name: NAMES.twin, portrait: 'portrait_janika' },
];
const twin = (key) => TWINS.find((t) => t.key === key);
// maps the room's maker can pick: the plain test field, or the real first level
// what the room maker can pick: World 2's levels (the next opens when one is finished), and the test field
const MAPS = [
    ...COOP_LEVELS.map((l, i) => ({ level: i, name: `${l.id} ${l.name.toUpperCase()}` })),
    { level: 'test', name: 'TEST FIELD' },
];
let mapPick = 0; // kept while the app is open, so a finished round comes back to the same map

// Two-phone lobby: pick which twin this phone is, make or join a room with a 4-digit code,
// both press READY, and the room's maker starts the level for both.
export default class Lobby extends Phaser.Scene {
    constructor() {
        super('Lobby');
    }

    create(data) {
        const { width: w, height: h } = this.scale;
        this.save = this.registry.get('save');
        this.starting = false;
        this.add.tileSprite(0, 0, w, h, 'bg_meadow_wide').setOrigin(0).setTileScale(h / 720, h / 720);
        this.add.rectangle(0, 0, w, h, 0x140d1f, 0.55).setOrigin(0);
        this.add.text(w / 2, 60, 'PLAY TOGETHER', { ...TEXT, fontSize: 34, color: GOLD, stroke: '#2a1640', strokeThickness: 10 }).setOrigin(0.5);
        this.layer = this.add.container(0, 0);
        this.offs = [];
        this.events.once('shutdown', () => this.offs.forEach((off) => off()));
        this.input.keyboard.on('keydown', (e) => this.onKey(e.key));
        music.play('title');

        // coming back after a level: still in the room with her sister
        if (data?.room && net.channel) this.showRoom();
        else if (!this.save.me) this.showWho();
        else this.showMenu();
    }

    // ---------------------------------------------------------------- helpers ---
    clear() {
        this.layer.removeAll(true);
        this.offs.forEach((off) => off());
        this.offs = [];
        this.keyHandler = null;
    }

    button(x, y, label, onTap, size = 22) {
        const t = this.add.text(x, y, label, { ...TEXT, fontSize: size }).setOrigin(0.5).setPadding(24, 14, 24, 14)
            .setBackgroundColor('#2a1640').setInteractive({ useHandCursor: true });
        t.on('pointerover', () => t.setColor(GOLD)).on('pointerout', () => t.setColor('#ffffff'));
        t.on('pointerdown', () => { sfx.select(); onTap(t); });
        this.layer.add(t);
        return t;
    }

    label(x, y, text, size = 16, color = '#ffffff') {
        const t = this.add.text(x, y, text, { ...TEXT, fontSize: size, color, align: 'center' }).setOrigin(0.5);
        this.layer.add(t);
        return t;
    }

    onKey(key) {
        this.keyHandler?.(key);
    }

    // --------------------------------------------------------- 1. who are you ---
    showWho() {
        this.clear();
        const { width: w, height: h } = this.scale;
        this.label(w / 2, h * 0.24, 'WHO IS PLAYING ON THIS PHONE?', 18);
        TWINS.forEach((t, i) => {
            const x = w / 2 + (i ? 170 : -170);
            const pic = this.add.image(x, h * 0.5, t.portrait).setScale(1.3).setInteractive({ useHandCursor: true });
            const name = this.label(x, h * 0.5 + 115, t.name.toUpperCase(), 20, GOLD);
            pic.on('pointerdown', () => {
                sfx.select();
                this.save.me = t.key;
                writeSave(this.save);
                this.showMenu();
            });
            this.tweens.add({ targets: [pic], scale: 1.4, duration: 700, yoyo: true, repeat: -1, delay: i * 350, ease: 'Sine.inOut' });
            this.layer.add([pic, name]);
        });
        this.button(w / 2, h - 60, 'BACK', () => this.exit(), 16);
    }

    // ------------------------------------------------------ 2. make or join ---
    showMenu(message = '') {
        this.clear();
        net.close();
        const { width: w, height: h } = this.scale;
        const me = twin(this.save.me);
        this.layer.add(this.add.image(w / 2, h * 0.3, me.portrait));
        this.label(w / 2, h * 0.3 + 85, `PLAYING AS ${me.name.toUpperCase()}`, 14, GOLD);
        this.button(w / 2 + 240, h * 0.3 + 85, 'CHANGE', () => this.showWho(), 11);
        this.button(w / 2, h * 0.58, 'MAKE A ROOM', () => this.makeRoom());
        this.button(w / 2, h * 0.58 + 80, 'JOIN A ROOM', () => this.showKeypad());
        this.button(w / 2, h - 60, 'BACK', () => this.exit(), 16);
        if (message) this.label(w / 2, h * 0.58 + 150, message, 12, '#ff9a9a');
    }

    // a free 4-digit code nobody is using right now
    async makeRoom() {
        this.clear();
        const { width: w, height: h } = this.scale;
        this.label(w / 2, h / 2, 'MAKING A ROOM...', 18);
        try {
            for (let tries = 0; tries < 5; tries++) {
                const code = String(Phaser.Math.Between(1000, 9999));
                await net.open(code, this.save.me, true);
                await this.wait(700); // let presence arrive
                if (net.people().length <= 1) return this.showRoom();
            }
            this.showMenu('Could not make a room. Try again.');
        } catch {
            this.showMenu('No internet? Could not reach the game server.');
        }
    }

    // ------------------------------------------------------------ 3. keypad ---
    showKeypad() {
        this.clear();
        const { width: w, height: h } = this.scale;
        let code = '';
        this.label(w / 2, h * 0.2, 'TYPE THE ROOM NUMBER', 16);
        const shown = this.label(w / 2, h * 0.31, '_ _ _ _', 40, GOLD);
        const type = (k) => {
            if (k === 'Backspace' || k === '<') code = code.slice(0, -1);
            else if (/^[0-9]$/.test(k) && code.length < 4) code += k;
            else if ((k === 'Enter' || k === 'OK') && code.length === 4) return this.joinRoom(code);
            shown.setText((code + '____').slice(0, 4).split('').join(' '));
        };
        this.keyHandler = type;
        const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '<', '0', 'OK'];
        keys.forEach((k, i) => {
            const x = w / 2 + ((i % 3) - 1) * 110;
            const y = h * 0.43 + Math.floor(i / 3) * 76;
            this.button(x, y, k, () => type(k), 26).setFixedSize(92, 64).setAlign('center');
        });
        this.button(w / 2, h - 50, 'BACK', () => this.showMenu(), 16);
    }

    async joinRoom(code) {
        this.clear();
        const { width: w, height: h } = this.scale;
        this.label(w / 2, h / 2, `LOOKING FOR ROOM ${code}...`, 18);
        try {
            await net.open(code, this.save.me, false);
        } catch {
            return this.showMenu('No internet? Could not reach the game server.');
        }
        // wait for the room's maker to show up
        for (let i = 0; i < 8 && !net.people().some((p) => p.host); i++) await this.wait(400);
        const people = net.people();
        const other = net.partner();
        if (!people.some((p) => p.host)) return this.showMenu(`No room ${code}. Check the number.`);
        if (people.length > 2) return this.showMenu(`Room ${code} is already full.`);
        if (other && other.me === this.save.me) {
            return this.showMenu(`${twin(this.save.me).name} is already in that room. Tap CHANGE.`);
        }
        this.showRoom();
    }

    // -------------------------------------------------------------- 4. room ---
    showRoom() {
        this.clear();
        const { width: w, height: h } = this.scale;
        net.setReady(false);
        this.label(w / 2, h * 0.17, 'ROOM', 16);
        this.label(w / 2, h * 0.17 + 46, net.code.split('').join(' '), 44, GOLD);
        if (net.host) this.button(w / 2, h * 0.17 + 112, 'SEND CODE ON WHATSAPP', () => this.share(), 12);

        // one card per twin: her picture, and whether she's here and ready
        const cards = TWINS.map((t, i) => {
            const x = w / 2 + (i ? 200 : -200);
            const pic = this.add.image(x, h * 0.56, t.portrait);
            const state = this.label(x, h * 0.56 + 90, '', 13);
            this.layer.add(pic);
            return { t, pic, state };
        });
        const readyBtn = this.button(w / 2, h - 120, 'READY!', () => {
            net.setReady(!net.ready);
            readyBtn.setText(net.ready ? 'NOT READY' : 'READY!');
            refresh();
        }, 22);
        this.button(w / 2, h - 50, 'LEAVE ROOM', () => this.showMenu(), 14);
        // the room's maker picks the map; the other phone just sees which one
        const mapText = () => `MAP: ${MAPS[mapPick].name}`;
        const mapBtn = net.host
            ? this.button(w / 2, h - 190, mapText(), () => {
                // next map that's open: a World 2 level opens once the one before it is finished
                const cleared = this.save.coopCleared || [];
                const open = ({ level }) => UNLOCK_ALL_LEVELS || level === 'test' || level === 0 || cleared.includes(COOP_LEVELS[level - 1].id);
                do mapPick = (mapPick + 1) % MAPS.length; while (!open(MAPS[mapPick]));
                mapBtn.setText(mapText());
                net.send('map', { pick: mapPick });
            }, 12)
            : this.label(w / 2, h - 190, mapText(), 12, GOLD);
        if (!net.host) this.offs.push(net.on('map', ({ pick }) => { mapPick = pick; mapBtn.setText(mapText()); }));
        const refresh = () => {
            const people = net.people();
            for (const c of cards) {
                const p = people.find((x) => x.me === c.t.key);
                c.pic.setAlpha(p ? 1 : 0.3);
                c.state.setText(!p ? 'NOT HERE YET' : p.ready ? 'READY!' : 'HERE').setColor(p?.ready ? '#7dff8a' : '#ffffff');
            }
            // the room's maker starts the level once both twins are ready
            if (net.host) net.send('map', { pick: mapPick }); // tell a sister who just walked in
            if (net.host && people.length === 2 && people.every((p) => p.ready)) {
                const { level } = MAPS[mapPick];
                net.send('start', { level });
                this.startLevel(level);
            }
        };
        this.offs.push(net.on('presence', refresh));
        this.offs.push(net.on('start', ({ level }) => this.startLevel(level)));
        refresh();
    }

    share() {
        const text = `Let's play ${NAMES.game}! Open PLAY TOGETHER, tap JOIN A ROOM and type ${net.code}`;
        const url = `https://wa.me/?text=${encodeURIComponent(text)}`;
        // inside the app the link opens WhatsApp; in a browser it opens a new tab
        if (window.Capacitor?.isNativePlatform?.()) window.location.href = url;
        else window.open(url, '_blank');
    }

    startLevel(level) {
        if (this.starting) return;
        this.starting = true;
        net.setReady(false);
        this.cameras.main.fade(400, 0, 0, 0);
        this.time.delayedCall(450, () => {
            this.starting = false;
            this.scene.start('Level', { level, coop: true });
        });
    }

    exit() {
        net.close();
        this.scene.start('Title', { skipSplash: true });
    }

    wait(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }
}
