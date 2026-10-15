// Retro sound effects, synthesized (see audio.js).
import { audio, playNote, playNoise } from './audio.js';

const now = () => audio().ctx.currentTime;
const out = () => audio().sfxGain;
const note = (freq, opts = {}) => playNote({ freq, start: now() + (opts.delay || 0), dur: 0.1, out: out(), ...opts });
const seq = (freqs, step, opts = {}) => freqs.forEach((f, i) => note(f, { delay: i * step, ...opts }));

export const sfx = {
    jump: () => note(260, { to: 720, dur: 0.16, vol: 0.07, type: 'square', sustain: 0.5 }),
    gem: () => { note(1319, { dur: 0.06, vol: 0.08 }); note(1976, { delay: 0.06, dur: 0.22, vol: 0.08 }); },
    // each stomp in a combo sounds a little higher
    stomp: (combo = 1) => {
        const up = 1 + 0.12 * Math.min(combo - 1, 6);
        note(500 * up, { to: 120 * up, dur: 0.12, vol: 0.16, type: 'square' });
        playNoise({ start: now(), dur: 0.08, vol: 0.12, filter: 'lowpass', freq: 900, out: out() });
    },
    hurt: () => seq([660, 440, 330], 0.07, { dur: 0.12, vol: 0.09, type: 'sawtooth' }),
    bump: () => note(180, { to: 90, dur: 0.09, vol: 0.14, type: 'triangle' }),
    smash: () => playNoise({ start: now(), dur: 0.25, vol: 0.22, filter: 'lowpass', freq: 1400, out: out() }),
    sprout: () => seq([392, 523, 659, 784, 1047], 0.04, { dur: 0.08, vol: 0.07 }),
    power: () => seq([523, 659, 784, 1047, 784, 1047, 1319], 0.05, { dur: 0.09, vol: 0.08 }),
    oneUp: () => seq([659, 784, 1319, 1047, 1175, 1568], 0.08, { dur: 0.1, vol: 0.09 }),
    checkpoint: () => seq([784, 988, 1175, 1568], 0.07, { dur: 0.14, vol: 0.08, type: 'triangle' }),
    meow: () => note(700, { to: 1050, dur: 0.18, type: 'sine', vol: 0.1 }),
    select: () => note(880, { dur: 0.05, vol: 0.06 }),
    pause: () => seq([988, 659, 988, 659], 0.06, { dur: 0.06, vol: 0.06 }),
    thunder: () => playNoise({ start: now(), dur: 1.2, vol: 0.35, filter: 'lowpass', freq: 300, out: out() }),
    whoosh: () => playNoise({ start: now(), dur: 0.4, vol: 0.12, filter: 'bandpass', freq: 1200, out: out() }),
    win: () => seq([523, 659, 784, 1047, 784, 1047, 1319, 1568], 0.11, { dur: 0.18, vol: 0.09, type: 'square' }),
    lose: () => seq([494, 466, 440, 415, 392], 0.16, { dur: 0.2, vol: 0.08, type: 'square' }),
    tick: () => note(1568, { dur: 0.03, vol: 0.04 }),
};
