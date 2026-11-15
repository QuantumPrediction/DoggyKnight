"""Procedural 8-bit sound effects (C12). Python standard library only.

Every id in DEV_PLAN 4.9 becomes assets/sfx/<id>.wav (22 050 Hz, 16-bit mono).
Soft waveforms, short attacks/releases (no clicks), a gentle low-pass and loudness
normalisation keep them cute rather than harsh.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

from pixel import res_path

RATE = 22050
IDS = ["swing", "hit", "hurt", "enemy_down", "pickup", "level_up", "bark", "boss_warning",
       "ultimate", "clear", "fail", "ui_tap", "scroll", "ink"]


def note(name: str) -> float:
    """'C5' -> Hz."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1,
             "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + (octave - 4) * 12) / 12)


class Track:
    def __init__(self, seconds: float) -> None:
        self.buf = [0.0] * int(seconds * RATE)

    def add(self, start: float, samples: list[float], gain: float = 1.0) -> None:
        i0 = int(start * RATE)
        for i, v in enumerate(samples):
            j = i0 + i
            if j < len(self.buf):
                self.buf[j] += v * gain


def tone(seconds: float, f0: float, f1: float | None = None, wave_kind: str = "square", duty: float = 0.5,
         attack: float = 0.004, release: float = 0.05, decay: float = 0.0, vibrato: float = 0.0,
         vib_rate: float = 12.0, curve: str = "exp") -> list[float]:
    n = int(seconds * RATE)
    f1 = f0 if f1 is None else f1
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        k = i / max(1, n - 1)
        if curve == "exp" and f0 > 0 and f1 > 0:
            f = f0 * (f1 / f0) ** k
        else:
            f = f0 + (f1 - f0) * k
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * vib_rate * t)
        phase = (phase + f / RATE) % 1.0
        if wave_kind == "square":
            v = 1.0 if phase < duty else -1.0
        elif wave_kind == "triangle":
            v = 4 * abs(phase - 0.5) - 1
        elif wave_kind == "saw":
            v = 2 * phase - 1
        else:
            v = math.sin(2 * math.pi * phase)
        out.append(v * _env(i, n, attack, release, decay))
    return out


def noise(seconds: float, seed: int, attack: float = 0.002, release: float = 0.05, decay: float = 0.0,
          step: int = 1) -> list[float]:
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = []
    v = 0.0
    for i in range(n):
        if i % step == 0:
            v = rng.uniform(-1, 1)
        out.append(v * _env(i, n, attack, release, decay))
    return out


def _env(i: int, n: int, attack: float, release: float, decay: float) -> float:
    t = i / RATE
    rest = (n - i) / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, rest / release) if release > 0 else 1.0
    d = math.exp(-t * decay) if decay > 0 else 1.0
    return a * r * d


def lowpass(samples: list[float], cutoff: float | list[float]) -> list[float]:
    out = []
    y = 0.0
    for i, x in enumerate(samples):
        c = cutoff[i] if isinstance(cutoff, list) else cutoff
        a = 1.0 - math.exp(-2 * math.pi * c / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def sweep(n: int, c0: float, c1: float) -> list[float]:
    return [c0 * (c1 / c0) ** (i / max(1, n - 1)) for i in range(n)]


def finish(samples: list[float], target_rms: float = 0.16, peak: float = 0.85, cutoff: float = 7000) -> list[float]:
    s = lowpass(samples, cutoff)
    rms = math.sqrt(sum(v * v for v in s) / max(1, len(s))) or 1e-9
    pk = max(abs(v) for v in s) or 1e-9
    g = min(target_rms / rms, peak / pk)
    s = [v * g for v in s]
    fade = int(0.004 * RATE)
    for i in range(min(fade, len(s))):
        s[-1 - i] *= i / fade
    return s


# --------------------------------------------------------------------------

def make(sid: str) -> list[float]:
    if sid == "swing":
        n = noise(0.14, 1, attack=0.01, release=0.08)
        return finish(lowpass(n, sweep(len(n), 600, 3500)), target_rms=0.12)
    if sid == "hit":
        t = Track(0.12)
        t.add(0, tone(0.08, 330, 110, "square", 0.5, release=0.04, decay=20))
        t.add(0, lowpass(noise(0.05, 2, release=0.03, decay=40), 2500), 0.7)
        return finish(t.buf, target_rms=0.18)
    if sid == "hurt":   # cute little "kyan!"
        t = Track(0.2)
        t.add(0, tone(0.17, 1100, 620, "square", 0.25, attack=0.005, release=0.06, vibrato=0.03, vib_rate=30))
        return finish(t.buf, target_rms=0.13, cutoff=5000)
    if sid == "enemy_down":  # soft "poof"
        t = Track(0.32)
        t.add(0, lowpass(noise(0.25, 3, release=0.15, decay=8), sweep(int(0.25 * RATE), 2500, 300)), 0.9)
        t.add(0.02, tone(0.25, 700, 220, "triangle", release=0.12), 0.6)
        return finish(t.buf, target_rms=0.15)
    if sid == "pickup":
        t = Track(0.16)
        t.add(0, tone(0.06, note("E6"), wave_kind="square", duty=0.125, release=0.02))
        t.add(0.05, tone(0.1, note("B6"), wave_kind="square", duty=0.125, release=0.07))
        return finish(t.buf, target_rms=0.11, cutoff=6000)
    if sid == "level_up":
        t = Track(0.62)
        for i, nm in enumerate(["C5", "E5", "G5", "C6"]):
            t.add(i * 0.08, tone(0.14 if i < 3 else 0.3, note(nm), wave_kind="square", duty=0.25, release=0.08))
            t.add(i * 0.08, tone(0.14 if i < 3 else 0.3, note(nm) / 2, wave_kind="triangle", release=0.08), 0.6)
        t.add(0.32, tone(0.28, note("G6"), wave_kind="triangle", release=0.2, vibrato=0.01), 0.4)
        return finish(t.buf, target_rms=0.14, cutoff=6000)
    if sid == "bark":   # small friendly "arf!"
        t = Track(0.2)
        t.add(0, tone(0.15, 420, 300, "saw", attack=0.006, release=0.05, vibrato=0.04, vib_rate=40, curve="lin"))
        t.add(0, lowpass(noise(0.06, 5, release=0.04), 1800), 0.4)
        s = lowpass(t.buf, sweep(len(t.buf), 2600, 900))
        return finish(s, target_rms=0.17)
    if sid == "boss_warning":
        t = Track(0.85)
        for i in range(2):
            t.add(i * 0.4, tone(0.18, 196, wave_kind="square", duty=0.5, release=0.05))
            t.add(i * 0.4 + 0.18, tone(0.18, 147, wave_kind="square", duty=0.5, release=0.08))
        return finish(lowpass(t.buf, 1800), target_rms=0.16)
    if sid == "ultimate":
        t = Track(1.0)
        t.add(0, tone(0.45, 220, 1320, "square", 0.25, attack=0.02, release=0.05), 0.7)
        t.add(0, lowpass(noise(0.45, 6, attack=0.1, release=0.1), sweep(int(0.45 * RATE), 400, 5000)), 0.5)
        for nm in ("C6", "E6", "G6"):
            t.add(0.42, tone(0.55, note(nm), wave_kind="triangle", release=0.4, vibrato=0.008))
        t.add(0.42, lowpass(noise(0.3, 7, release=0.25, decay=6), 3000), 0.5)
        return finish(t.buf, target_rms=0.17)
    if sid == "clear":
        t = Track(1.25)
        seq = [("G4", 0.0, 0.12), ("C5", 0.12, 0.12), ("E5", 0.24, 0.12), ("G5", 0.36, 0.2), ("E5", 0.56, 0.1),
               ("G5", 0.66, 0.55)]
        for nm, st, ln in seq:
            t.add(st, tone(ln, note(nm), wave_kind="square", duty=0.25, release=0.06, vibrato=0.006 if ln > 0.3 else 0))
        for nm in ("C4", "E4", "G4"):
            t.add(0.66, tone(0.55, note(nm), wave_kind="triangle", release=0.3), 0.35)
        return finish(t.buf, target_rms=0.14, cutoff=6000)
    if sid == "fail":   # sleepy, not sad: three soft falling notes
        t = Track(1.0)
        for i, nm in enumerate(["E5", "D#5", "D5"]):
            ln = 0.22 if i < 2 else 0.5
            t.add(i * 0.24, tone(ln, note(nm), note(nm) * (0.94 if i == 2 else 1.0), "triangle",
                                 release=0.1 if i < 2 else 0.35, vibrato=0.015 if i == 2 else 0))
        return finish(t.buf, target_rms=0.15, cutoff=4500)
    if sid == "ui_tap":
        t = Track(0.05)
        t.add(0, tone(0.04, 1400, 1000, "square", 0.25, attack=0.001, release=0.02, decay=40))
        return finish(t.buf, target_rms=0.08, cutoff=5000)
    if sid == "scroll":   # paper rustle
        n = noise(0.18, 8, attack=0.02, release=0.08, step=2)
        wob = [v * (0.6 + 0.4 * math.sin(i / RATE * 2 * math.pi * 30)) for i, v in enumerate(n)]
        return finish(lowpass(wob, 3200), target_rms=0.09)
    if sid == "ink":      # "bloop"
        t = Track(0.24)
        t.add(0, tone(0.2, 380, 110, "sine", attack=0.005, release=0.08))
        t.add(0, lowpass(noise(0.05, 9, release=0.04), 1200), 0.3)
        return finish(t.buf, target_rms=0.17)
    raise KeyError(sid)


def write_wav(path: str, samples: list[float]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = b"".join(struct.pack("<h", max(-32767, min(32767, int(round(v * 32767))))) for v in samples)
    if os.path.exists(path):
        with wave.open(path, "rb") as old:
            if old.readframes(old.getnframes()) == data:
                return
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def write_all() -> None:
    for sid in IDS:
        write_wav(res_path("res://assets/sfx/%s.wav" % sid), make(sid))
