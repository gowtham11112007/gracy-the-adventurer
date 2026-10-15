"""Synthesizes all chiptune SFX and music tracks from the original Phaser game into clean WAV files for Godot.

Run from project root:
    .venv/bin/python tools/synthesize_audio.py
"""
import os
import math
import wave
import numpy as np
from pathlib import Path

SAMPLE_RATE = 44100
ROOT = Path("/Users/gowthamyuvaraj/Desktop/developer/gracy the adventurer")
SFX_DIR = ROOT / "godot" / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "godot" / "assets" / "audio" / "music"

SFX_DIR.mkdir(parents=True, exist_ok=True)
MUSIC_DIR.mkdir(parents=True, exist_ok=True)


def write_wav(path: Path, samples: np.ndarray):
    """Write float32 numpy array (-1.0 to 1.0) as 16-bit PCM WAV."""
    samples = np.clip(samples, -1.0, 1.0)
    int_samples = (samples * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(int_samples.tobytes())


def synth_note(freq, to_freq=None, dur=0.1, wave_type="square", vol=0.5, attack=0.005, sustain=0.7):
    n_samples = int(dur * SAMPLE_RATE)
    if n_samples <= 0:
        return np.zeros(0, dtype=np.float32)
    t = np.linspace(0, dur, n_samples, endpoint=False)
    
    # Frequency trajectory
    if to_freq is not None and to_freq != freq:
        # Exponential chirp
        freqs = np.geomspace(freq, to_freq, n_samples)
        phase = 2 * np.pi * np.cumsum(freqs) / SAMPLE_RATE
    else:
        phase = 2 * np.pi * freq * t

    # Waveform
    if wave_type == "square":
        # Softened square wave to avoid aliasing harshness
        signal = np.sign(np.sin(phase)) * 0.7 + 0.3 * np.sin(phase)
    elif wave_type == "sawtooth":
        signal = 2.0 * (phase / (2 * np.pi) - np.floor(0.5 + phase / (2 * np.pi)))
    elif wave_type == "triangle":
        signal = 2.0 * np.abs(2.0 * (phase / (2 * np.pi) - np.floor(0.5 + phase / (2 * np.pi)))) - 1.0
    else:  # sine
        signal = np.sin(phase)

    # Envelope
    env = np.ones(n_samples, dtype=np.float32)
    att_samples = int(attack * SAMPLE_RATE)
    if att_samples > 0 and att_samples < n_samples:
        env[:att_samples] = np.linspace(0.01, 1.0, att_samples)
    
    decay_samples = int(min(dur * 0.4, 0.08) * SAMPLE_RATE)
    start_decay = att_samples
    end_decay = min(n_samples, start_decay + decay_samples)
    if end_decay > start_decay:
        env[start_decay:end_decay] = np.linspace(1.0, sustain, end_decay - start_decay)
        env[end_decay:] = sustain

    # Release at the end
    rel_samples = int(0.02 * SAMPLE_RATE)
    if rel_samples > 0 and n_samples > rel_samples:
        env[-rel_samples:] *= np.linspace(1.0, 0.0, rel_samples)

    return signal * env * vol


def synth_noise(dur=0.1, vol=0.5, filter_kind="lowpass", cutoff_freq=1000):
    n_samples = int(dur * SAMPLE_RATE)
    raw = (np.random.rand(n_samples) * 2.0 - 1.0).astype(np.float32)
    # Simple recursive 1-pole filter
    rc = 1.0 / (2 * np.pi * cutoff_freq)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    filtered = np.zeros_like(raw)
    last = 0.0
    for i in range(n_samples):
        if filter_kind == "lowpass":
            last += alpha * (raw[i] - last)
            filtered[i] = last
        elif filter_kind == "highpass":
            last += alpha * (raw[i] - last)
            filtered[i] = raw[i] - last
        else:  # bandpass approx
            last += alpha * (raw[i] - last)
            filtered[i] = last
    # Envelope
    env = np.linspace(1.0, 0.0, n_samples)
    return filtered * env * vol


def synth_sequence(notes, step, wave_type="square", dur=0.1, vol=0.5):
    total_dur = len(notes) * step + dur + 0.05
    n_total = int(total_dur * SAMPLE_RATE)
    out = np.zeros(n_total, dtype=np.float32)
    for i, f in enumerate(notes):
        idx = int(i * step * SAMPLE_RATE)
        sig = synth_note(f, dur=dur, wave_type=wave_type, vol=vol)
        end_idx = min(n_total, idx + len(sig))
        out[idx:end_idx] += sig[:end_idx - idx]
    return out


print("Generating Sound Effects...")

# 1. jump: 260 -> 720 Hz sweep
write_wav(SFX_DIR / "jump.wav", synth_note(260, to_freq=720, dur=0.16, wave_type="square", vol=0.45, sustain=0.5))

# 2. gem: 1319 Hz then 1976 Hz
g1 = synth_note(1319, dur=0.06, wave_type="sine", vol=0.45)
g2 = synth_note(1976, dur=0.22, wave_type="sine", vol=0.45)
gem_total = np.zeros(int(0.35 * SAMPLE_RATE), dtype=np.float32)
gem_total[:len(g1)] += g1
idx2 = int(0.06 * SAMPLE_RATE)
gem_total[idx2:idx2+len(g2)] += g2
write_wav(SFX_DIR / "gem.wav", gem_total)

# 3. stomp: 500 -> 120 sweep + crunch
st_sweep = synth_note(500, to_freq=120, dur=0.12, wave_type="square", vol=0.5)
st_noise = synth_noise(dur=0.09, vol=0.55, filter_kind="lowpass", cutoff_freq=900)
stomp_total = np.zeros(max(len(st_sweep), len(st_noise)), dtype=np.float32)
stomp_total[:len(st_sweep)] += st_sweep
stomp_total[:len(st_noise)] += st_noise
write_wav(SFX_DIR / "stomp.wav", stomp_total)

# 4. hurt: 660, 440, 330 sawtooth
write_wav(SFX_DIR / "hurt.wav", synth_sequence([660, 440, 330], 0.07, wave_type="sawtooth", dur=0.12, vol=0.45))

# 5. bump: 180 -> 90 triangle
write_wav(SFX_DIR / "bump.wav", synth_note(180, to_freq=90, dur=0.09, wave_type="triangle", vol=0.6))

# 6. smash: noise burst
write_wav(SFX_DIR / "smash.wav", synth_noise(dur=0.25, vol=0.6, filter_kind="lowpass", cutoff_freq=1400))

# 7. sprout: [392, 523, 659, 784, 1047]
write_wav(SFX_DIR / "sprout.wav", synth_sequence([392, 523, 659, 784, 1047], 0.04, wave_type="square", dur=0.08, vol=0.35))

# 8. power: [523, 659, 784, 1047, 784, 1047, 1319]
write_wav(SFX_DIR / "power.wav", synth_sequence([523, 659, 784, 1047, 784, 1047, 1319], 0.05, wave_type="square", dur=0.09, vol=0.4))

# 9. one_up: [659, 784, 1319, 1047, 1175, 1568]
write_wav(SFX_DIR / "one_up.wav", synth_sequence([659, 784, 1319, 1047, 1175, 1568], 0.08, wave_type="square", dur=0.1, vol=0.45))

# 10. checkpoint: [784, 988, 1175, 1568] triangle
write_wav(SFX_DIR / "checkpoint.wav", synth_sequence([784, 988, 1175, 1568], 0.07, wave_type="triangle", dur=0.14, vol=0.5))

# 11. meow: sine 700 -> 1050
write_wav(SFX_DIR / "meow.wav", synth_note(700, to_freq=1050, dur=0.18, wave_type="sine", vol=0.45))

# 12. select: 880 sine
write_wav(SFX_DIR / "select.wav", synth_note(880, dur=0.05, wave_type="sine", vol=0.35))

# 13. pause: [988, 659, 988, 659]
write_wav(SFX_DIR / "pause.wav", synth_sequence([988, 659, 988, 659], 0.06, wave_type="sine", dur=0.06, vol=0.35))

# 14. thunder: deep low noise
write_wav(SFX_DIR / "thunder.wav", synth_noise(dur=1.2, vol=0.8, filter_kind="lowpass", cutoff_freq=300))

# 15. whoosh: 1200 noise
write_wav(SFX_DIR / "whoosh.wav", synth_noise(dur=0.4, vol=0.45, filter_kind="bandpass", cutoff_freq=1200))

# 16. win: fanfare
write_wav(SFX_DIR / "win.wav", synth_sequence([523, 659, 784, 1047, 784, 1047, 1319, 1568], 0.11, wave_type="square", dur=0.18, vol=0.45))

# 17. lose
write_wav(SFX_DIR / "lose.wav", synth_sequence([494, 466, 440, 415, 392], 0.16, wave_type="square", dur=0.2, vol=0.4))

# 18. tick
write_wav(SFX_DIR / "tick.wav", synth_note(1568, dur=0.03, wave_type="triangle", vol=0.3))

print("Synthesizing music tracks from game/src/music.js...")

NOTE_MAP = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
def note_to_freq(name):
    if not name or name == "." or name == "-":
        return 0
    # e.g. A4, C#5, Bb3
    acc = 0
    p = 1
    if len(name) > 2:
        if name[1] == "#":
            acc = 1
            p = 2
        elif name[1] == "b":
            acc = -1
            p = 2
    octave = int(name[p:])
    midi = 12 * (octave + 1) + NOTE_MAP[name[0]] + acc
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


TRACKS = {
    "title": {
        "bpm": 112,
        "lead": (
            "A4 - - - C5 - E5 - D5 - C5 - B4 - G4 - A4 - - - - - - - . . . . E4 - G4 - "
            "A4 - - - C5 - E5 - G5 - F5 - E5 - D5 - E5 - - - - - - - . . . . . . . . "
            "F5 - - - E5 - D5 - C5 - - - A4 - C5 - D5 - - - C5 - B4 - G4 - - - . . . . "
            "A4 - C5 - E5 - A5 - G5 - E5 - D5 - C5 - A4 - - - - - - - - - - - . . . ."
        ),
        "bass": (
            "A2 . A3 . E3 . A3 . A2 . A3 . E3 . A3 . F2 . F3 . C3 . F3 . F2 . F3 . C3 . F3 . "
            "C3 . C4 . G3 . C4 . C3 . C4 . G3 . C4 . G2 . G3 . D3 . G3 . G2 . G3 . D3 . G3 . "
            "F2 . F3 . C3 . F3 . F2 . F3 . C3 . F3 . G2 . G3 . D3 . G3 . G2 . G3 . D3 . G3 . "
            "A2 . A3 . E3 . A3 . A2 . A3 . E3 . A3 . E2 . E3 . B2 . E3 . E2 . E3 . B2 . E3 ."
        ),
        "drums": ("k . . . h . . . s . . . h . . . " * 8).strip(),
    },
    "meadow": {
        "bpm": 152,
        "lead": (
            "E5 - G5 . C6 - B5 . A5 - G5 . E5 - . . F5 - A5 . D6 - C6 . B5 - G5 . . . . . "
            "E5 - G5 . C6 - E6 . D6 - C6 . A5 - G5 . F5 - E5 . D5 - . . C5 - - - . . . . "
            "A5 - . A5 G5 - E5 . F5 - . F5 E5 - C5 . D5 - . D5 E5 - F5 . G5 - - - . . . . "
            "A5 - . A5 G5 - E5 . F5 - . F5 E5 - C5 . D5 - E5 . D5 - B4 . C5 - - - . . . ."
        ),
        "bass": (
            "C3 . G2 . C3 . G2 . C3 . G2 . C3 . E3 . F2 . C3 . F2 . C3 . G2 . D3 . G2 . B2 . "
            "C3 . G2 . C3 . G2 . A2 . E3 . A2 . E3 . F2 . C3 . G2 . D3 . C3 . G2 . C3 . . . "
            "F2 . C3 . F2 . C3 . F2 . C3 . F2 . C3 . G2 . D3 . G2 . D3 . G2 . D3 . G2 . B2 . "
            "A2 . E3 . A2 . E3 . F2 . C3 . F2 . C3 . G2 . D3 . G2 . B2 . C3 . G2 . C3 . . ."
        ),
        "drums": ("k . h . s . h . k . h k s . h . " * 8).strip(),
    },
    "sky": {
        "bpm": 132,
        "lead": (
            "C5 - F5 - A5 - C6 - - - A5 - G5 - F5 - D5 - - - F5 - A5 - G5 - F5 - E5 - D5 - "
            "D5 - F5 - Bb5 - - - A5 - G5 - F5 - D5 - E5 - - - G5 - - - C5 - - - . . . . "
            "A5 - . A5 C6 - A5 . G5 - F5 . G5 - A5 . F5 - D5 - - - . . A4 - D5 - F5 - A5 - "
            "Bb5 - A5 - G5 - F5 - G5 - - - E5 - C5 - F5 - - - - - - - . . . . C5 - E5 -"
        ),
        "bass": (
            "F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 . D2 . A2 . D3 . A2 . D2 . A2 . D3 . A2 . "
            "Bb1 . F2 . Bb2 . F2 . Bb1 . F2 . Bb2 . F2 . C2 . G2 . C3 . G2 . C2 . G2 . C3 . E3 . "
            "F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 . D2 . A2 . D3 . A2 . D2 . A2 . D3 . A2 . "
            "Bb1 . F2 . Bb2 . F2 . C2 . G2 . C3 . G2 . F2 . C3 . F3 . A3 . F3 . C3 . F2 . . ."
        ),
        "drums": ("k . . h . . s . . h k . s . h . " * 8).strip(),
    },
    "fortress": {
        "bpm": 120,
        "lead": (
            "D5 . D5 . A4 . D5 . F5 - E5 . D5 - . . C5 . C5 . A4 . C5 . E5 - D5 . C5 - . . "
            "Bb4 . Bb4 . G4 . Bb4 . D5 - C5 . Bb4 - . . A4 - - - C#5 - - - E5 - - - . . . . "
            "F5 . F5 . E5 . D5 . A5 - - - F5 - D5 . D5 . D5 . F5 . Bb5 . A5 - G5 . F5 - . . "
            "G5 - F5 . E5 . D5 . C#5 - - - E5 - - - D5 - - - - - - - . . . . A4 . . ."
        ),
        "bass": (
            "D2 . . . D2 . A2 . D2 . . . D2 . A2 . D2 . . . D2 . A2 . D2 . . . D2 . A2 . "
            "G2 . . . G2 . D3 . G2 . . . G2 . D3 . A2 . . . A2 . E2 . A2 . . . A2 . C#3 . "
            "D2 . . . D2 . A2 . D2 . . . D2 . A2 . Bb1 . . . Bb1 . F2 . Bb1 . . . Bb1 . F2 . "
            "G2 . . . G2 . D3 . A2 . . . A2 . E3 . D2 . . . D2 . A2 . D2 . A2 . D3 . . ."
        ),
        "drums": ("k . . . s . s . k . . . s . s s " * 8).strip(),
    },
    "dusk": {
        "bpm": 100,
        "lead": (
            "E5 - - - A4 - - - C5 - B4 - A4 - - - F5 - - - E5 - D5 - C5 - - - . . . . "
            "D5 - - - G4 - - - B4 - A4 - G4 - - - G#4 - - - B4 - - - E5 - - - . . . . "
            "A5 - - - G5 - E5 - C5 - - - E5 - A5 - F5 - - - E5 - C5 - A4 - - - . . . . "
            "D5 - F5 - A5 - - - G5 - F5 - E5 - D5 - E5 - - - - - - - G#4 - - - B4 - - -"
        ),
        "bass": (
            "A2 . E3 . A3 . E3 . A2 . E3 . A3 . E3 . F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 . "
            "G2 . D3 . G3 . D3 . G2 . D3 . G3 . D3 . E2 . B2 . E3 . B2 . E2 . B2 . G#3 . B2 . "
            "A2 . E3 . A3 . E3 . A2 . E3 . A3 . E3 . F2 . C3 . F3 . C3 . F2 . C3 . F3 . C3 . "
            "D2 . A2 . D3 . A2 . D2 . A2 . D3 . A2 . E2 . B2 . E3 . B2 . E2 . B2 . G#3 . B2 ."
        ),
        "drums": ("k . . . h . . . s . . h h . . . " * 8).strip(),
    },
}


def render_track(track_name, track_data):
    bpm = track_data["bpm"]
    step_sec = (60.0 / bpm) / 4.0  # 16th note in seconds
    lead_tokens = track_data["lead"].split()
    bass_tokens = track_data["bass"].split()
    drum_tokens = track_data["drums"].split()
    n_steps = max(len(lead_tokens), len(bass_tokens), len(drum_tokens))
    total_sec = n_steps * step_sec
    n_samples = int(total_sec * SAMPLE_RATE)
    
    song = np.zeros(n_samples, dtype=np.float32)

    def process_voice(tokens, wave_type, vol):
        cur_note = None
        cur_start = 0
        cur_len = 0
        for i in range(len(tokens) + 1):
            tok = tokens[i] if i < len(tokens) else "."
            if tok == "-":
                cur_len += 1
            else:
                if cur_note and cur_note != ".":
                    freq = note_to_freq(cur_note)
                    if freq > 0:
                        dur = cur_len * step_sec
                        sig = synth_note(freq, dur=dur, wave_type=wave_type, vol=vol, sustain=0.85)
                        idx = int(cur_start * step_sec * SAMPLE_RATE)
                        end_idx = min(n_samples, idx + len(sig))
                        song[idx:end_idx] += sig[:end_idx - idx]
                cur_note = tok
                cur_start = i
                cur_len = 1

    process_voice(lead_tokens, "square", 0.22)
    process_voice(bass_tokens, "triangle", 0.35)

    # Process drums
    for i, d in enumerate(drum_tokens):
        idx = int(i * step_sec * SAMPLE_RATE)
        if d == "k":
            # Kick: sweep 140 -> 40
            sig = synth_note(140, to_freq=40, dur=0.08, wave_type="sine", vol=0.55)
        elif d == "s":
            # Snare: noise burst
            sig = synth_noise(dur=0.07, vol=0.35, filter_kind="lowpass", cutoff_freq=2200)
        elif d == "h":
            # Hi-hat: crisp noise
            sig = synth_noise(dur=0.03, vol=0.18, filter_kind="highpass", cutoff_freq=6500)
        else:
            sig = None
        if sig is not None:
            end_idx = min(n_samples, idx + len(sig))
            song[idx:end_idx] += sig[:end_idx - idx]

    out_path = MUSIC_DIR / f"{track_name}.wav"
    write_wav(out_path, song)
    print(f"  Rendered {track_name}.wav ({total_sec:.2f}s loop)")


for name, data in TRACKS.items():
    render_track(name, data)

print("Audio generation complete!")
