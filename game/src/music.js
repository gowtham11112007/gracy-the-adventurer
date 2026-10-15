// Background music: a tiny step sequencer playing original chiptune loops.
// Each voice is written as 16th-note steps: a note ("E5"), "-" to hold it, "." for silence.
// Drum steps use k (kick), s (snare), h (hi-hat).
import { audio, noteToMidi, midiToFreq, playNote, playNoise } from './audio.js';

const bars = (...b) => b.join(' ');
const repeat = (bar, n) => Array(n).fill(bar).join(' ');

const TRACKS = {
    // dreamy and adventurous: Am - F - C - G
    title: {
        bpm: 112,
        lead: bars(
            'A4 - - - C5 - E5 - D5 - C5 - B4 - G4 -', 'A4 - - - - - - - . . . . E4 - G4 -',
            'A4 - - - C5 - E5 - G5 - F5 - E5 - D5 -', 'E5 - - - - - - - . . . . . . . .',
            'F5 - - - E5 - D5 - C5 - - - A4 - C5 -', 'D5 - - - C5 - B4 - G4 - - - . . . .',
            'A4 - C5 - E5 - A5 - G5 - E5 - D5 - C5 -', 'A4 - - - - - - - - - - - . . . .'),
        bass: bars(
            'A2 . A3 . E3 . A3 . A2 . A3 . E3 . A3 .', 'F2 . F3 . C3 . F3 . F2 . F3 . C3 . F3 .',
            'C3 . C4 . G3 . C4 . C3 . C4 . G3 . C4 .', 'G2 . G3 . D3 . G3 . G2 . G3 . D3 . G3 .',
            'F2 . F3 . C3 . F3 . F2 . F3 . C3 . F3 .', 'G2 . G3 . D3 . G3 . G2 . G3 . D3 . G3 .',
            'A2 . A3 . E3 . A3 . A2 . A3 . E3 . A3 .', 'E2 . E3 . B2 . E3 . E2 . E3 . B2 . E3 .'),
        drums: repeat('k . . . h . . . s . . . h . . .', 8),
    },
    // bouncy level theme in C major
    meadow: {
        bpm: 152,
        lead: bars(
            'E5 - G5 . C6 - B5 . A5 - G5 . E5 - . .', 'F5 - A5 . D6 - C6 . B5 - G5 . . . . .',
            'E5 - G5 . C6 - E6 . D6 - C6 . A5 - G5 .', 'F5 - E5 . D5 - . . C5 - - - . . . .',
            'A5 - . A5 G5 - E5 . F5 - . F5 E5 - C5 .', 'D5 - . D5 E5 - F5 . G5 - - - . . . .',
            'A5 - . A5 G5 - E5 . F5 - . F5 E5 - C5 .', 'D5 - E5 . D5 - B4 . C5 - - - . . . .'),
        bass: bars(
            'C3 . G2 . C3 . G2 . C3 . G2 . C3 . E3 .', 'F2 . C3 . F2 . C3 . G2 . D3 . G2 . B2 .',
            'C3 . G2 . C3 . G2 . A2 . E3 . A2 . E3 .', 'F2 . C3 . G2 . D3 . C3 . G2 . C3 . . .',
            'F2 . C3 . F2 . C3 . F2 . C3 . F2 . C3 .', 'G2 . D3 . G2 . D3 . G2 . D3 . G2 . B2 .',
            'A2 . E3 . A2 . E3 . F2 . C3 . F2 . C3 .', 'G2 . D3 . G2 . B2 . C3 . G2 . C3 . . .'),
        drums: repeat('k . h . s . h . k . h k s . h .', 8),
    },
    // Treetop Heights: light and airy, F major
    sky: {
        bpm: 132,
        lead: bars(
            'C5 - F5 - A5 - C6 - - - A5 - G5 - F5 -', 'D5 - - - F5 - A5 - G5 - F5 - E5 - D5 -',
            'D5 - F5 - Bb5 - - - A5 - G5 - F5 - D5 -', 'E5 - - - G5 - - - C5 - - - . . . .',
            'A5 - . A5 C6 - A5 . G5 - F5 . G5 - A5 .', 'F5 - D5 - - - . . A4 - D5 - F5 - A5 -',
            'Bb5 - A5 - G5 - F5 - G5 - - - E5 - C5 -', 'F5 - - - - - - - . . . . C5 - E5 -'),
        bass: bars(
            'F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 .', 'D2 . A2 . D3 . A2 . D2 . A2 . D3 . A2 .',
            'Bb1 . F2 . Bb2 . F2 . Bb1 . F2 . Bb2 . F2 .', 'C2 . G2 . C3 . G2 . C2 . G2 . C3 . E3 .',
            'F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 .', 'D2 . A2 . D3 . A2 . D2 . A2 . D3 . A2 .',
            'Bb1 . F2 . Bb2 . F2 . C2 . G2 . C3 . G2 .', 'F2 . C3 . F3 . A3 . F3 . C3 . F2 . . .'),
        drums: repeat('k . . h . . s . . h k . s . h .', 8),
    },
    // Brick Fortress: a marching tune in D minor
    fortress: {
        bpm: 120,
        lead: bars(
            'D5 . D5 . A4 . D5 . F5 - E5 . D5 - . .', 'C5 . C5 . A4 . C5 . E5 - D5 . C5 - . .',
            'Bb4 . Bb4 . G4 . Bb4 . D5 - C5 . Bb4 - . .', 'A4 - - - C#5 - - - E5 - - - . . . .',
            'F5 . F5 . E5 . D5 . A5 - - - F5 - D5 .', 'D5 . D5 . F5 . Bb5 . A5 - G5 . F5 - . .',
            'G5 - F5 . E5 . D5 . C#5 - - - E5 - - -', 'D5 - - - - - - - . . . . A4 . . .'),
        bass: bars(
            'D2 . . . D2 . A2 . D2 . . . D2 . A2 .', 'D2 . . . D2 . A2 . D2 . . . D2 . A2 .',
            'G2 . . . G2 . D3 . G2 . . . G2 . D3 .', 'A2 . . . A2 . E2 . A2 . . . A2 . C#3 .',
            'D2 . . . D2 . A2 . D2 . . . D2 . A2 .', 'Bb1 . . . Bb1 . F2 . Bb1 . . . Bb1 . F2 .',
            'G2 . . . G2 . D3 . A2 . . . A2 . E3 .', 'D2 . . . D2 . A2 . D2 . A2 . D3 . . .'),
        drums: repeat('k . . . s . s . k . . . s . s s', 8),
    },
    // Yuva's Hill at dusk: slower and a little mysterious, A minor
    dusk: {
        bpm: 100,
        lead: bars(
            'E5 - - - A4 - - - C5 - B4 - A4 - - -', 'F5 - - - E5 - D5 - C5 - - - . . . .',
            'D5 - - - G4 - - - B4 - A4 - G4 - - -', 'G#4 - - - B4 - - - E5 - - - . . . .',
            'A5 - - - G5 - E5 - C5 - - - E5 - A5 -', 'F5 - - - E5 - C5 - A4 - - - . . . .',
            'D5 - F5 - A5 - - - G5 - F5 - E5 - D5 -', 'E5 - - - - - - - G#4 - - - B4 - - -'),
        bass: bars(
            'A2 . E3 . A3 . E3 . A2 . E3 . A3 . E3 .', 'F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 .',
            'G2 . D3 . G3 . D3 . G2 . D3 . G3 . D3 .', 'E2 . B2 . E3 . B2 . E2 . B2 . G#3 . B2 .',
            'A2 . E3 . A3 . E3 . A2 . E3 . A3 . E3 .', 'F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 .',
            'D2 . A2 . D3 . A2 . D2 . A2 . D3 . A2 .', 'E2 . B2 . E3 . B2 . E2 . B2 . G#3 . B2 .'),
        drums: repeat('k . . . h . . . s . . h h . . .', 8),
    },
    // World 2, the Crystal Cave: mysterious but bouncy, D minor with a bright dorian lift
    cave: {
        bpm: 116,
        lead: bars(
            'D5 - - - A4 - - - F5 - E5 - D5 - - -', 'E5 - - - G4 - - - C5 - D5 - E5 - - -',
            'F5 - - - D5 - - - Bb4 - C5 - D5 - - -', 'C#5 - - - - - - - E5 - - - A4 - - -',
            'A5 - - - G5 - F5 - E5 - D5 - F5 - A5 -', 'C6 - - - A5 - - - F5 - - - C5 - - -',
            'D5 - E5 - F5 - G5 - B5 - - - G5 - - -', 'A5 - - - - - - - C#5 - - - E5 - - -'),
        bass: bars(
            'D2 . A2 . D3 . A2 . D2 . A2 . D3 . A2 .', 'C2 . G2 . C3 . G2 . C2 . G2 . C3 . G2 .',
            'Bb1 . F2 . Bb2 . F2 . Bb1 . F2 . Bb2 . F2 .', 'A1 . E2 . A2 . E2 . A1 . E2 . C#3 . E2 .',
            'D2 . A2 . D3 . A2 . D2 . A2 . D3 . A2 .', 'F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 .',
            'G2 . D3 . G3 . D3 . G2 . D3 . B2 . D3 .', 'A1 . E2 . A2 . E2 . A1 . E2 . C#3 . E2 .'),
        drums: repeat('k . . h . . s . k . h . s . h .', 8),
    },
    // the party: Happy Birthday to You (a public-domain tune) as a bouncy 3/4 waltz in C
    birthday: {
        bpm: 104,
        lead: bars(
            '. . . . . . . . G4 - - G4', 'A4 - - - G4 - - - C5 - - -', 'B4 - - - - - - - G4 - - G4',
            'A4 - - - G4 - - - D5 - - -', 'C5 - - - - - - - G4 - - G4', 'G5 - - - E5 - - - C5 - - -',
            'B4 - - - A4 - - - - - - -', 'F5 - - F5 E5 - - - C5 - - -', 'D5 - - - C5 - - - - - - -'),
        bass: bars(
            'C3 - - - . . . . . . . .', 'C3 - - - E3 - - - G3 - - -', 'G2 - - - B2 - - - D3 - - -',
            'G2 - - - B2 - - - D3 - - -', 'C3 - - - E3 - - - G3 - - -', 'C3 - - - E3 - - - G3 - - -',
            'F2 - - - A2 - - - C3 - - -', 'C3 - - - E3 - - - G3 - - -', 'G2 - - - B2 - - - C3 - - -'),
        drums: repeat('k . . . h . . . h . . .', 9),
    },
    // the boss fight: fast and driving, E minor
    boss: {
        bpm: 150,
        lead: bars(
            'E5 - E5 . G5 - E5 . A5 - G5 . E5 - D5 .', 'E5 - E5 . G5 - E5 . B5 - A5 . G5 - F#5 .',
            'E5 - E5 . G5 - E5 . A5 - G5 . E5 - D5 .', 'C5 - D5 . E5 - - - B4 - - - . . . .'),
        bass: bars(repeat('E2 E3', 8), repeat('E2 E3', 8), repeat('A2 A3', 8), `${repeat('C2 C3', 4)} ${repeat('B1 B2', 4)}`),
        drums: repeat('k . h k s . h . k . h k s . h h', 4),
    },
    // Yuva's entrance: tense, minor key
    villain: {
        bpm: 100,
        lead: bars(
            'A4 - - - . . A4 . C5 - - - B4 - G#4 -', 'A4 - - - . . . . E4 - - - . . . .',
            'F4 - - - . . F4 . A4 - - - G#4 - E4 -', 'E4 - - - - - - - D#4 - - - E4 - - -'),
        bass: bars(
            repeat('A2 .', 8), repeat('A2 .', 8), repeat('F2 .', 8), repeat('E2 .', 8)),
        drums: repeat('k . . . s . . . k . k . s . . .', 4),
    },
};

const VOICES = {
    lead: { type: 'square', vol: 0.05 },
    bass: { type: 'triangle', vol: 0.17 },
};

// turn "E5 - G5 ." into [{midi, len}, null, ...] with each note's held length
function parseVoice(text) {
    const tokens = text.trim().split(/\s+/);
    return tokens.map((t, i) => {
        if (t === '-' || t === '.') return null;
        let len = 1;
        while (tokens[i + len] === '-') len++;
        return { midi: noteToMidi(t), len };
    });
}

let current = null;
let timer = null;
let step = 0;
let nextTime = 0;
let parsed = null;
let paused = false;

function schedule() {
    const { ctx, musicGain } = audio();
    if (paused) return;
    const stepDur = 60 / parsed.bpm / 4;
    if (nextTime < ctx.currentTime - 0.2) nextTime = ctx.currentTime + 0.05; // recover after a stall
    while (nextTime < ctx.currentTime + 0.15) {
        for (const name of ['lead', 'bass']) {
            const n = parsed[name][step % parsed[name].length];
            if (n) playNote({ freq: midiToFreq(n.midi), start: nextTime, dur: n.len * stepDur * 0.92, out: musicGain, ...VOICES[name] });
        }
        const d = parsed.drums[step % parsed.drums.length];
        if (d.includes('k')) playNote({ freq: 140, to: 45, start: nextTime, dur: 0.14, type: 'sine', vol: 0.4, out: musicGain });
        if (d.includes('s')) playNoise({ start: nextTime, dur: 0.12, vol: 0.12, filter: 'bandpass', freq: 1800, out: musicGain });
        if (d.includes('h')) playNoise({ start: nextTime, dur: 0.035, vol: 0.05, filter: 'highpass', freq: 7000, out: musicGain });
        step = (step + 1) % parsed.length;
        nextTime += stepDur;
    }
}

export const music = {
    play(name) {
        if (current === name) return;
        this.stop();
        const t = TRACKS[name];
        parsed = {
            bpm: t.bpm,
            lead: parseVoice(t.lead),
            bass: parseVoice(t.bass),
            drums: t.drums.trim().split(/\s+/),
        };
        parsed.length = Math.max(parsed.lead.length, parsed.bass.length, parsed.drums.length);
        current = name;
        step = 0;
        nextTime = audio().ctx.currentTime + 0.1;
        timer = setInterval(schedule, 25);
    },
    stop() {
        clearInterval(timer);
        timer = null;
        current = null;
    },
    // used when the app goes to the background
    pause() { paused = true; },
    resume() {
        paused = false;
        nextTime = audio().ctx.currentTime + 0.05;
    },
};
