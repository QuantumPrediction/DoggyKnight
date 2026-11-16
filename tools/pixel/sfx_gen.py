"""Procedural 8-bit sound effects (C12, CP7). Python standard library only.

Every id in DEV_PLAN 4.9 and 4.10 becomes assets/sfx/<id>.wav (22 050 Hz, 16-bit mono).
v2.2 added crit, combo, boss_roar, star, whoosh, heal, pet, perfect, countdown and made
hit, swing, pickup, level_up and ultimate fuller (thump and chime layers).
v2.3 added talk (the dialogue blip; Sfx.play's pitch argument gives each speaker a voice),
page_turn, arrow_shot, husk_clank, captain_shout and magic.
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
       "ultimate", "clear", "fail", "ui_tap", "scroll", "ink",
       # v2.2 (CP7)
       "crit", "combo", "boss_roar", "star", "whoosh", "heal", "pet", "perfect", "countdown",
       # v2.3 (CS8)
       "talk", "page_turn", "arrow_shot", "husk_clank", "captain_shout", "magic"]


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


def bell(seconds: float, f: float, decay: float = 9.0, partials=((1.0, 1.0), (2.0, 0.45), (3.01, 0.2)),
         attack: float = 0.002) -> list[float]:
    """Soft chime: a few sine partials with exponential decay."""
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        v = sum(a * math.sin(2 * math.pi * f * k * t) * math.exp(-t * decay * (0.7 + 0.5 * k))
                for k, a in partials)
        out.append(v * min(1.0, t / attack) * min(1.0, (n - i) / (0.01 * RATE)))
    return out


def thump(seconds: float, f0: float, f1: float, decay: float = 25.0) -> list[float]:
    n = int(seconds * RATE)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t * 40)
        ph += f / RATE
        out.append(math.sin(2 * math.pi * ph) * math.exp(-t * decay))
    return out


def highpass(samples: list[float], cutoff: float) -> list[float]:
    low = lowpass(samples, cutoff)
    return [a - b for a, b in zip(samples, low)]


# --------------------------------------------------------------------------

def make(sid: str) -> list[float]:
    if sid == "swing":   # airy swoosh with a faint blade ring
        n = noise(0.16, 1, attack=0.012, release=0.09)
        t = Track(0.2)
        t.add(0, lowpass(n, sweep(len(n), 700, 4200)))
        t.add(0.02, bell(0.14, 2350, decay=30, partials=((1.0, 1.0), (1.51, 0.4))), 0.06)
        return finish(t.buf, target_rms=0.12)
    if sid == "hit":     # punchy: low thump + crunchy click + square tick
        t = Track(0.16)
        t.add(0, thump(0.14, 210, 70, decay=28), 0.9)
        t.add(0, tone(0.06, 520, 160, "square", 0.5, release=0.03, decay=30), 0.45)
        t.add(0, lowpass(noise(0.05, 2, release=0.03, decay=45), 3200), 0.8)
        return finish(t.buf, target_rms=0.2, peak=0.9)
    if sid == "crit":    # extra-heavy hit with a bright metallic ting
        t = Track(0.42)
        t.add(0, thump(0.18, 240, 60, decay=20), 1.0)
        t.add(0, tone(0.07, 660, 180, "square", 0.5, release=0.03, decay=25), 0.5)
        t.add(0, lowpass(noise(0.07, 12, release=0.04, decay=35), 4200), 0.9)
        t.add(0.03, bell(0.38, 1760, decay=10, partials=((1.0, 1.0), (1.5, 0.6), (2.76, 0.3))), 0.35)
        return finish(t.buf, target_rms=0.2, peak=0.9)
    if sid == "combo":   # rising double chime
        t = Track(0.42)
        t.add(0, bell(0.2, note("E6"), decay=14), 0.8)
        t.add(0.09, bell(0.32, note("B6"), decay=10), 0.9)
        t.add(0, tone(0.18, note("E5"), note("B5"), "square", 0.125, release=0.08), 0.15)
        return finish(t.buf, target_rms=0.12, cutoff=8000)
    if sid == "boss_roar":   # hollow armour roar: growling saw, rumble and a metal clank
        t = Track(1.1)
        t.add(0, tone(1.0, 110, 70, "saw", attack=0.06, release=0.3, vibrato=0.06, vib_rate=11), 0.6)
        t.add(0, tone(1.0, 165, 104, "square", 0.3, attack=0.06, release=0.3, vibrato=0.05, vib_rate=7), 0.3)
        t.add(0, lowpass(noise(1.0, 13, attack=0.08, release=0.35), 900), 0.8)
        t.add(0, bell(0.6, 420, decay=8, partials=((1.0, 1.0), (2.41, 0.6), (3.9, 0.4))), 0.3)
        s = lowpass(t.buf, sweep(len(t.buf), 2400, 600))
        return finish(s, target_rms=0.19)
    if sid == "star":    # sparkly result star
        t = Track(0.55)
        t.add(0, bell(0.5, note("A6"), decay=7, partials=((1.0, 1.0), (2.0, 0.3), (2.99, 0.15))), 0.8)
        t.add(0.03, bell(0.4, note("E7"), decay=12), 0.25)
        t.add(0, lowpass(noise(0.04, 14, release=0.03), 6000), 0.2)
        return finish(t.buf, target_rms=0.12, cutoff=9000)
    if sid == "whoosh":  # screen transition / cut-in
        n = noise(0.36, 15, attack=0.12, release=0.2)
        half = len(n) // 2
        s = lowpass(n, sweep(half, 500, 3600) + sweep(len(n) - half, 3600, 900))
        return finish(highpass(s, 250), target_rms=0.1)
    if sid == "heal":    # gentle rising sparkle
        t = Track(0.62)
        for i, nm in enumerate(["C6", "E6", "G6", "C7"]):
            t.add(i * 0.07, bell(0.3, note(nm), decay=11), 0.7)
        t.add(0, tone(0.4, note("C5"), note("G5"), "triangle", attack=0.05, release=0.2), 0.3)
        return finish(t.buf, target_rms=0.11, cutoff=8000)
    if sid == "pet":     # happy little "boop" and a heart sparkle
        t = Track(0.42)
        t.add(0, tone(0.13, note("A5"), note("C#6"), "sine", attack=0.01, release=0.06, vibrato=0.02, vib_rate=18), 0.9)
        t.add(0.12, tone(0.2, note("E6"), note("A6"), "sine", attack=0.01, release=0.12, vibrato=0.02, vib_rate=18),
              0.8)
        t.add(0.2, bell(0.2, note("A7"), decay=16), 0.15)
        return finish(t.buf, target_rms=0.12, cutoff=7000)
    if sid == "perfect":  # bright chime chord with a sparkle run
        t = Track(0.85)
        for nm in ("C6", "E6", "G6"):
            t.add(0, bell(0.8, note(nm), decay=5), 0.5)
        for i, nm in enumerate(["G6", "C7", "E7", "G7"]):
            t.add(0.1 + i * 0.05, bell(0.25, note(nm), decay=14), 0.3)
        t.add(0, tone(0.12, note("C5"), note("C6"), "square", 0.25, release=0.05), 0.3)
        return finish(t.buf, target_rms=0.13, cutoff=9000)
    if sid == "countdown":  # 3, 2, 1 beep
        t = Track(0.16)
        t.add(0, tone(0.12, 880, wave_kind="square", duty=0.25, attack=0.002, release=0.05), 0.8)
        t.add(0, tone(0.12, 440, wave_kind="triangle", attack=0.002, release=0.05), 0.5)
        return finish(t.buf, target_rms=0.12, cutoff=6000)
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
        t = Track(0.2)
        t.add(0, tone(0.06, note("E6"), wave_kind="square", duty=0.125, release=0.02))
        t.add(0.05, tone(0.1, note("B6"), wave_kind="square", duty=0.125, release=0.07))
        t.add(0.05, bell(0.14, note("B7"), decay=20), 0.12)
        return finish(t.buf, target_rms=0.11, cutoff=7000)
    if sid == "level_up":   # fanfare arpeggio, a shimmering run and a held chord
        t = Track(1.1)
        for i, nm in enumerate(["C5", "E5", "G5", "C6"]):
            t.add(i * 0.07, tone(0.12 if i < 3 else 0.5, note(nm), wave_kind="square", duty=0.25, release=0.1,
                                 vibrato=0.008 if i == 3 else 0))
            t.add(i * 0.07, tone(0.12 if i < 3 else 0.5, note(nm) / 2, wave_kind="triangle", release=0.1), 0.6)
        for nm in ("E5", "G5"):
            t.add(0.28, tone(0.5, note(nm), wave_kind="square", duty=0.125, release=0.25), 0.35)
        for i, nm in enumerate(["G6", "C7", "E7", "G7", "C8"]):
            t.add(0.3 + i * 0.045, bell(0.35, note(nm), decay=10), 0.28)
        t.add(0.28, lowpass(noise(0.4, 16, attack=0.05, release=0.3), 7000), 0.08)
        return finish(t.buf, target_rms=0.14, cutoff=8000)
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
        t = Track(1.2)
        t.add(0, tone(0.45, 220, 1320, "square", 0.25, attack=0.02, release=0.05), 0.7)
        t.add(0, lowpass(noise(0.45, 6, attack=0.1, release=0.1), sweep(int(0.45 * RATE), 400, 5000)), 0.5)
        t.add(0.42, thump(0.4, 160, 40, decay=8), 0.9)
        for nm in ("C6", "E6", "G6"):
            t.add(0.42, tone(0.55, note(nm), wave_kind="triangle", release=0.4, vibrato=0.008))
        t.add(0.42, lowpass(noise(0.3, 7, release=0.25, decay=6), 3000), 0.5)
        for i, nm in enumerate(["C7", "G7", "C8"]):
            t.add(0.5 + i * 0.06, bell(0.4, note(nm), decay=9), 0.2)
        return finish(t.buf, target_rms=0.18)
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
    # ---- v2.3 (CS8) -----------------------------------------------------
    if sid == "talk":       # a soft rounded "bip" (pitched per speaker by the dialogue box)
        t = Track(0.07)
        t.add(0, tone(0.06, 620, 560, "square", 0.25, attack=0.003, release=0.03, decay=20))
        t.add(0, tone(0.06, 310, 280, "triangle", attack=0.003, release=0.03, decay=20), 0.6)
        return finish(t.buf, target_rms=0.09, cutoff=3200)
    if sid == "page_turn":  # paper swish and a soft flap
        n = noise(0.32, 41, attack=0.06, release=0.12, step=2)
        swish = lowpass(n, sweep(len(n), 900, 4200))
        t = Track(0.4)
        t.add(0, [v * (0.5 + 0.5 * math.sin(i / RATE * 2 * math.pi * 9)) for i, v in enumerate(swish)], 0.9)
        t.add(0.27, lowpass(noise(0.08, 42, release=0.06, decay=30), 1800), 0.7)
        t.add(0.28, thump(0.08, 180, 90, decay=40), 0.25)
        return finish(t.buf, target_rms=0.08, cutoff=5000)
    if sid == "arrow_shot":  # bowstring twang + a fast airy whoosh
        t = Track(0.3)
        t.add(0, tone(0.2, 210, 170, "triangle", attack=0.001, release=0.1, decay=14, vibrato=0.03, vib_rate=45))
        t.add(0, tone(0.08, 420, 340, "square", 0.25, attack=0.001, release=0.04, decay=30), 0.35)
        w = noise(0.18, 43, attack=0.01, release=0.1)
        t.add(0.02, lowpass(highpass(w, 1200), sweep(len(w), 6000, 2000)), 0.5)
        return finish(t.buf, target_rms=0.12, cutoff=6500)
    if sid == "husk_clank":  # hollow armour clank (empty inside!)
        t = Track(0.45)
        t.add(0, bell(0.4, 430, decay=11, partials=((1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.9, 0.15))), 0.8)
        t.add(0.03, bell(0.3, 610, decay=14, partials=((1.0, 0.7), (2.4, 0.4))), 0.5)
        t.add(0, lowpass(noise(0.03, 44, release=0.02), 5000), 0.6)
        t.add(0, thump(0.15, 140, 60, decay=30), 0.6)
        return finish(t.buf, target_rms=0.14, cutoff=7000)
    if sid == "captain_shout":   # a raspy straw "hrah!" (more silly than scary)
        t = Track(0.5)
        t.add(0, tone(0.36, 240, 170, "saw", attack=0.02, release=0.12, vibrato=0.05, vib_rate=11, curve="lin"))
        t.add(0, tone(0.36, 120, 90, "square", 0.5, attack=0.02, release=0.12, curve="lin"), 0.3)
        rustle = noise(0.42, 45, attack=0.02, release=0.15, step=3)
        t.add(0, lowpass([v * (0.6 + 0.4 * math.sin(i / RATE * 2 * math.pi * 26)) for i, v in enumerate(rustle)], 3500), 0.45)
        s = lowpass(t.buf, sweep(len(t.buf), 2600, 800))
        return finish(s, target_rms=0.15)
    if sid == "magic":       # sparkly rising chimes and a soft shimmer
        t = Track(0.9)
        for i, nm in enumerate(["C6", "E6", "G6", "B6", "D7", "G7"]):
            t.add(i * 0.045, bell(0.5, note(nm), decay=8), 0.32)
        t.add(0, lowpass(highpass(noise(0.6, 46, attack=0.1, release=0.35), 3000), 9000), 0.12)
        t.add(0.05, tone(0.5, note("G5"), note("G6"), "triangle", attack=0.05, release=0.3), 0.25)
        return finish(t.buf, target_rms=0.11, cutoff=9000)
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
