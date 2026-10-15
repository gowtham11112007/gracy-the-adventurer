// One shared Web Audio setup for music and sound effects (no audio files needed).
let ctx = null;
let musicGain = null;
let sfxGain = null;
let noise = null;

export function audio() {
    if (!ctx) {
        ctx = new (window.AudioContext || window.webkitAudioContext)();
        const master = ctx.createGain();
        master.gain.value = 0.9;
        master.connect(ctx.destination);
        musicGain = ctx.createGain();
        musicGain.gain.value = 0.55;
        musicGain.connect(master);
        sfxGain = ctx.createGain();
        sfxGain.connect(master);
        // one second of white noise, reused for drums and crunchy effects
        noise = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
        const data = noise.getChannelData(0);
        for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    }
    if (ctx.state === 'suspended') ctx.resume();
    return { ctx, musicGain, sfxGain, noise };
}

// phones only allow sound after a tap, so wake audio up on the first touch
export function unlockAudioOnTouch() {
    const wake = () => audio();
    window.addEventListener('pointerdown', wake);
    window.addEventListener('keydown', wake);
}

export function setMusicVolume(on) {
    audio().musicGain.gain.value = on ? 0.55 : 0;
}

export function setSoundVolume(on) {
    audio().sfxGain.gain.value = on ? 1 : 0;
}

export const midiToFreq = (m) => 440 * Math.pow(2, (m - 69) / 12);

const NOTE = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
// "C5", "F#4", "Bb3" -> MIDI number
export function noteToMidi(name) {
    const m = /^([A-G])([#b]?)(-?\d)$/.exec(name);
    const acc = m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0;
    return 12 * (Number(m[3]) + 1) + NOTE[m[1]] + acc;
}

// a single synth note: oscillator through a quick attack/decay envelope
export function playNote({ freq, to, start, dur, type = 'square', vol = 0.1, out, attack = 0.005, sustain = 0.7 }) {
    const { ctx: c } = audio();
    const osc = c.createOscillator();
    const g = c.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, start);
    if (to) osc.frequency.exponentialRampToValueAtTime(to, start + dur);
    g.gain.setValueAtTime(0.0001, start);
    g.gain.exponentialRampToValueAtTime(vol, start + attack);
    g.gain.exponentialRampToValueAtTime(vol * sustain, start + Math.min(dur * 0.4, 0.08) + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, start + dur);
    osc.connect(g).connect(out);
    osc.start(start);
    osc.stop(start + dur + 0.02);
}

// a burst of filtered noise (drums, crunches, whooshes)
export function playNoise({ start, dur, vol = 0.1, filter = 'highpass', freq = 6000, out }) {
    const { ctx: c, noise: buf } = audio();
    const src = c.createBufferSource();
    src.buffer = buf;
    const f = c.createBiquadFilter();
    f.type = filter;
    f.frequency.value = freq;
    const g = c.createGain();
    g.gain.setValueAtTime(vol, start);
    g.gain.exponentialRampToValueAtTime(0.0001, start + dur);
    src.connect(f).connect(g).connect(out);
    src.start(start, Math.random() * 0.5);
    src.stop(start + dur + 0.02);
}
