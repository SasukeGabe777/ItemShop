"""Generate placeholder chiptune-style WAV loops for every track in the music manifest.

Original procedural melodies (no copied tunes). Square/triangle voices with a
simple bass line, seeded per track so each one has its own mood.
Run: python tools/gen_placeholder_audio.py
"""
from __future__ import annotations

import json
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "music" / "default"
SR = 22050

# mood: (scale intervals, base midi note, bpm, bars, waveform)
MOODS = {
    "main_menu": ([0, 2, 4, 7, 9], 60, 96, 8, "square"),
    "crossroads_day": ([0, 2, 4, 5, 7, 9], 62, 110, 8, "square"),
    "crossroads_night": ([0, 3, 5, 7, 10], 57, 76, 8, "triangle"),
    "item_shop": ([0, 2, 4, 7, 9], 65, 120, 8, "square"),
    "negotiation": ([0, 2, 3, 7, 8], 60, 132, 4, "square"),
    "dungeon_kingdom_hearts": ([0, 3, 5, 7, 10], 55, 100, 8, "triangle"),
    "dungeon_mario": ([0, 2, 4, 5, 7, 9, 11], 64, 140, 8, "square"),
    "dungeon_final_fantasy": ([0, 2, 3, 5, 7, 8, 11], 57, 92, 8, "triangle"),
    "dungeon_zelda": ([0, 2, 3, 5, 7, 9, 10], 59, 104, 8, "square"),
    "dungeon_naruto": ([0, 1, 5, 7, 8], 58, 126, 8, "square"),
    "dungeon_dragon_ball": ([0, 3, 5, 6, 7, 10], 55, 138, 8, "square"),
    "dungeon_pokemon": ([0, 2, 4, 6, 7, 9, 11], 63, 128, 8, "square"),
    "boss_battle": ([0, 1, 4, 5, 8], 52, 150, 8, "square"),
    "final_dungeon": ([0, 1, 3, 6, 7], 50, 88, 8, "triangle"),
    "final_boss": ([0, 1, 4, 6, 7, 10], 48, 160, 8, "square"),
    "ending": ([0, 2, 4, 7, 9, 11], 60, 72, 8, "triangle"),
    "victory_stinger": ([0, 4, 7, 12], 64, 140, 1, "square"),
    "failure_stinger": ([12, 8, 5, 0], 52, 70, 1, "triangle"),
}


def osc(kind: str, phase: float) -> float:
    p = phase % 1.0
    if kind == "square":
        return 0.6 if p < 0.5 else -0.6
    # triangle
    return 4.0 * abs(p - 0.5) - 1.0


def midi_hz(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12.0)


def render(track: str) -> None:
    scale, base, bpm, bars, wf = MOODS[track]
    rng = random.Random(hash(track) & 0xFFFFFFFF)
    beat = 60.0 / bpm
    step = beat / 2  # eighth notes
    steps = bars * 8
    stinger = "stinger" in track

    melody: list[float | None] = []
    if stinger:
        melody = [base + s for s in scale] + [None] * 2
        step = beat
    else:
        cur = rng.randrange(len(scale))
        for i in range(steps):
            if rng.random() < 0.18:
                melody.append(None)  # rest
                continue
            cur = max(0, min(len(scale) - 1, cur + rng.choice([-2, -1, -1, 0, 1, 1, 2])))
            octave = 12 if (i // 8) % 4 == 2 and rng.random() < 0.4 else 0
            melody.append(base + scale[cur] + octave)

    total = len(melody) * step + 0.3
    n_samples = int(total * SR)
    data = [0.0] * n_samples
    # melody voice
    for i, note in enumerate(melody):
        if note is None:
            continue
        f = midi_hz(note)
        start = int(i * step * SR)
        dur = int(step * SR * 0.92)
        for j in range(dur):
            t = j / SR
            env = min(1.0, j / (SR * 0.01)) * (1.0 - j / dur) ** 0.35
            idx = start + j
            if idx < n_samples:
                data[idx] += 0.5 * env * osc(wf, f * t)
    # bass voice on beats
    if not stinger:
        for b in range(bars * 4):
            root = base - 24 + scale[(b // 4) % len(scale)]
            f = midi_hz(root)
            start = int(b * beat * SR)
            dur = int(beat * SR * 0.8)
            for j in range(dur):
                t = j / SR
                env = (1.0 - j / dur) ** 0.6
                idx = start + j
                if idx < n_samples:
                    data[idx] += 0.3 * env * osc("triangle", f * t)

    peak = max(1e-6, max(abs(s) for s in data))
    norm = 0.85 / peak
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{track}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * norm)) * 32767)) for s in data))
    print(f"  {track}.wav ({total:.1f}s)")


if __name__ == "__main__":
    manifest = json.loads((ROOT / "data" / "music_manifest.json").read_text(encoding="utf-8"))
    for track_id in manifest["tracks"]:
        render(track_id)
    print("done")
