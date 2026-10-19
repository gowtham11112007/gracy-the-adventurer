"""Soft bell sounds for picking things up in the Unity game (no sound pack had one).

Run from the project folder:  .venv/bin/python tools/make_pickup_sounds.py
Writes unity/Assets/Resources/Audio/GemChime.wav (two quick bell notes) and ChestSparkle.wav (a rising run).
"""
import wave
import numpy as np

RATE = 44100


def bell(freq, length, start, out):
    t = np.arange(int(length * RATE)) / RATE
    tone = sum(a * np.sin(2 * np.pi * freq * m * t) for m, a in ((1, 1), (2.76, 0.35), (5.4, 0.12)))
    tone *= np.exp(-t * 7) * np.minimum(1, t * 400)  # quick strike, gentle ring
    i = int(start * RATE)
    out[i:i + len(tone)] += tone[: len(out) - i]


def save(name, notes, length):
    out = np.zeros(int(length * RATE))
    for freq, start in notes:
        bell(freq, length - start, start, out)
    out = out / np.abs(out).max() * 0.5
    with wave.open(f"unity/Assets/Resources/Audio/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((out * 32767).astype(np.int16).tobytes())
    print("wrote", name)


save("GemChime", [(1318.5, 0), (1975.5, 0.06)], 0.6)  # E6 then B6
save("ChestSparkle", [(f, i * 0.07) for i, f in enumerate((783.99, 987.77, 1174.66, 1567.98, 1975.53))], 1.2)  # G major run
