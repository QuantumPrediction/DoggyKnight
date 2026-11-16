"""Procedural 8-bit background music (CP6). Python 3 standard library only.

A tiny tracker: every song has a tempo, a bar length and four channels written as
note:duration tokens on a 16th-note grid (see parse()):

    lead     pulse wave (12.5 / 25 / 50 % duty), vibrato on long notes, soft echo
    harmony  pulse wave, quieter; usually arpeggios or off-beat chord stabs
    bass     NES-style 16-step triangle
    drums    k = kick, s = snare, h = closed hat, o = open hat, c = crash, t = tom, . = rest

Loops (title, field, boss, camp) are rendered seamlessly: note tails and the echo
wrap around from the end to the start, so the last sample flows into the first.
Their .import files set Godot's WAV importer to Forward loop over the whole file and
QOA compression. Jingles (victory, fail, chapter_clear) play once and end in silence.

Output: assets/music/<id>.wav (22 050 Hz, 16-bit mono). All melodies are original.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

from pixel import res_path

RATE = 22050
NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7,
              "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name: str) -> int:
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def freq(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def parse(text: str) -> list[tuple[int, int, int | str | None]]:
    """'C5:4 r:2 E5' -> [(start_step, length, midi or None)]. Default length 2 (an 8th). '|' is ignored."""
    out = []
    t = 0
    for tok in text.split():
        if tok == "|":
            continue
        if ":" in tok:
            name, ln = tok.split(":")
            length = int(ln)
        else:
            name, length = tok, 2
        if name in ("r", "."):
            out.append((t, length, None))
        else:
            out.append((t, length, midi(name)))
        t += length
    return out


def total_steps(events: list) -> int:
    return sum(e[1] for e in events)


# --------------------------------------------------------------------------
# Chord helpers (arpeggios, stabs and bass lines from a progression)
# --------------------------------------------------------------------------

CHORDS = {
    "": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11),
    "dim": (0, 3, 6), "sus4": (0, 5, 7), "add9": (0, 4, 7, 14),
}


def chord_notes(sym: str, octave: int) -> list[int]:
    root = sym[:2] if len(sym) > 1 and sym[1] in "#b" else sym[:1]
    kind = sym[len(root):]
    base = 12 * (octave + 1) + NOTE_INDEX[root]
    return [base + iv for iv in CHORDS[kind]]


def arp(progression: list[tuple[str, int]], octave: int, pattern: list[int], step: int = 2) -> str:
    """Arpeggiate chords: pattern indexes chord tones (3 = root an octave up, 4 = 3rd up...)."""
    toks = []
    for sym, steps in progression:
        notes = chord_notes(sym, octave)
        ext = notes + [n + 12 for n in notes]
        k = 0
        for _ in range(steps // step):
            m = ext[pattern[k % len(pattern)] % len(ext)]
            toks.append(_name(m) + ":%d" % step)
            k += 1
    return " ".join(toks)


def stabs(progression: list[tuple[str, int]], octave: int, rhythm: str) -> str:
    """Chord stabs on a rhythm like '.x.x' per 4 steps (x = play the chord's next tone)."""
    toks = []
    for sym, steps in progression:
        notes = chord_notes(sym, octave)
        k = 0
        for i in range(steps):
            ch = rhythm[i % len(rhythm)]
            if ch == "x":
                toks.append(_name(notes[k % len(notes)]) + ":1")
                k += 1
            else:
                toks.append("r:1")
    return " ".join(toks)


def bass_line(progression: list[tuple[str, int]], octave: int, pattern: list[tuple[int, int]]) -> str:
    """pattern: [(interval, steps), ...] repeated over each chord (interval 12 = octave, 7 = fifth)."""
    toks = []
    for sym, steps in progression:
        root = chord_notes(sym, octave)[0]
        left = steps
        i = 0
        while left > 0:
            iv, ln = pattern[i % len(pattern)]
            ln = min(ln, left)
            toks.append(("r" if iv is None else _name(root + iv)) + ":%d" % ln)
            left -= ln
            i += 1
    return " ".join(toks)


NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def _name(m: int) -> str:
    return "%s%d" % (NAMES[m % 12], m // 12 - 1)


# --------------------------------------------------------------------------
# Oscillators (with PolyBLEP to tame aliasing on the square waves)
# --------------------------------------------------------------------------

def _blep(t: float, dt: float) -> float:
    if t < dt:
        t /= dt
        return t + t - t * t - 1.0
    if t > 1.0 - dt:
        t = (t - 1.0) / dt
        return t * t + t + t + 1.0
    return 0.0


def render_note(kind: str, m: int, n: int, duty: float = 0.25, vib: float = 0.0, vib_delay: float = 0.18,
                attack: float = 0.004, decay: float = 0.0, sustain: float = 1.0, release: float = 0.04,
                slide_from: float | None = None, slide_time: float = 0.05) -> list[float]:
    """One note of n samples (plus release tail)."""
    f0 = freq(m)
    total = n + int(release * RATE)
    out = [0.0] * total
    phase = 0.0
    tri_steps = 16
    att_n = max(1, int(attack * RATE))
    rel_n = max(1, int(release * RATE))
    dec_k = math.exp(-decay / RATE) if decay > 0 else 1.0
    level = 1.0
    for i in range(total):
        t = i / RATE
        f = f0
        if slide_from is not None and t < slide_time:
            f = freq(slide_from + (m - slide_from) * (t / slide_time))
        if vib > 0 and t > vib_delay:
            f *= 1.0 + vib * math.sin(2 * math.pi * 5.5 * (t - vib_delay)) * min(1.0, (t - vib_delay) * 4)
        dt = f / RATE
        phase += dt
        if phase >= 1.0:
            phase -= 1.0
        if kind == "pulse":
            v = 1.0 if phase < duty else -1.0
            v += _blep(phase, dt)
            p2 = phase - duty
            if p2 < 0:
                p2 += 1.0
            v -= _blep(p2, dt)
            v -= (2 * duty - 1)          # remove DC
        elif kind == "tri":
            raw = 4 * abs(phase - 0.5) - 1
            v = round((raw + 1) * (tri_steps - 1) / 2) / ((tri_steps - 1) / 2) - 1
        else:
            v = math.sin(2 * math.pi * phase)
        # envelope
        if i < att_n:
            env = i / att_n
        else:
            level = max(sustain, level * dec_k) if decay > 0 else 1.0
            env = level
        if i >= n:
            env *= max(0.0, 1.0 - (i - n) / rel_n)
        out[i] = v * env
    return out


_noise_rng = random.Random(1234)
_NOISE = [_noise_rng.uniform(-1, 1) for _ in range(RATE)]


def drum(kind: str) -> list[float]:
    if kind == "k":
        n = int(0.16 * RATE)
        out = []
        ph = 0.0
        for i in range(n):
            t = i / RATE
            f = 45 + 110 * math.exp(-t * 32)
            ph += f / RATE
            out.append(math.sin(2 * math.pi * ph) * math.exp(-t * 18) * 1.1 + (_NOISE[i] * 0.3 if i < 60 else 0))
        return out
    if kind in ("s", "t"):
        n = int((0.16 if kind == "s" else 0.2) * RATE)
        out = []
        ph = 0.0
        lp = 0.0
        for i in range(n):
            t = i / RATE
            f = (190 if kind == "s" else 150) * (1 + 0.6 * math.exp(-t * 30))
            ph += f / RATE
            tone = math.sin(2 * math.pi * ph) * math.exp(-t * 26)
            lp += 0.45 * (_NOISE[i] - lp)
            nz = lp * math.exp(-t * (22 if kind == "s" else 40))
            out.append(tone * (0.55 if kind == "s" else 1.0) + nz * (0.8 if kind == "s" else 0.2))
        return out
    if kind in ("h", "o", "c"):
        dur = {"h": 0.05, "o": 0.18, "c": 0.9}[kind]
        dec = {"h": 90, "o": 16, "c": 4.5}[kind]
        n = int(dur * RATE)
        out = []
        lp = 0.0
        for i in range(n):
            x = _NOISE[(i * 7) % len(_NOISE)]
            lp += 0.35 * (x - lp)
            hp = x - lp
            out.append(hp * math.exp(-i / RATE * dec) * (0.5 if kind == "h" else 0.6))
        return out
    raise KeyError(kind)


# --------------------------------------------------------------------------
# Song rendering
# --------------------------------------------------------------------------

class Song:
    def __init__(self, bpm: float, bar_steps: int, bars: int, loop: bool, lead: str = "", harmony: str = "",
                 bass: str = "", drums: str = "", lead_duty: float = 0.25, harm_duty: float = 0.5,
                 lead_gain: float = 0.30, harm_gain: float = 0.13, bass_gain: float = 0.34,
                 drum_gain: float = 0.32, echo: float = 0.28, echo_steps: int = 3, lead_vib: float = 0.012,
                 lead_release: float = 0.05, harm_release: float = 0.03, lead2: str = "", lead2_gain: float = 0.12,
                 tail: float = 1.2, target_rms: float = 0.15, lead_kind: str = "pulse", harm_kind: str = "pulse",
                 harm_decay: float = 0.0) -> None:
        self.__dict__.update(locals())
        del self.__dict__["self"]


def render(song: Song) -> list[float]:
    step = 60.0 / song.bpm / 4
    steps = song.bar_steps * song.bars
    n = int(round(steps * step * RATE))
    tail = int(song.tail * RATE)
    size = n + tail

    def channel(text: str, kind: str, gain: float, duty: float, vib: float, release: float,
                decay: float = 0.0, sustain: float = 1.0) -> list[float]:
        buf = [0.0] * size
        if not text:
            return buf
        events = parse(text)
        assert total_steps(events) == steps, (kind, total_steps(events), steps)
        prev = None
        for (st, ln, m) in events:
            if m is None:
                prev = None
                continue
            start = int(round(st * step * RATE))
            dur = int(round(ln * step * RATE)) - int(0.008 * RATE)
            note = render_note(kind, m, max(1, dur), duty=duty, vib=vib if ln >= 4 else 0.0,
                               release=release, decay=decay, sustain=sustain)
            for i, v in enumerate(note):
                j = start + i
                if j < size:
                    buf[j] += v * gain
            prev = m
        return buf

    lead = channel(song.lead, song.lead_kind, song.lead_gain, song.lead_duty, song.lead_vib, song.lead_release)
    lead2 = channel(song.lead2, "pulse", song.lead2_gain, 0.125, song.lead_vib, song.lead_release)
    harm = channel(song.harmony, song.harm_kind, song.harm_gain, song.harm_duty, 0.0, song.harm_release,
                   decay=song.harm_decay, sustain=0.35 if song.harm_decay else 1.0)
    bass = channel(song.bass, "tri", song.bass_gain, 0.5, 0.0, 0.02)
    drums = [0.0] * size
    if song.drums:
        toks = [c for c in song.drums.replace("|", "").replace(" ", "")]
        assert len(toks) == steps, ("drums", len(toks), steps)
        for i, ch in enumerate(toks):
            if ch == ".":
                continue
            start = int(round(i * step * RATE))
            for k, v in enumerate(drum(ch)):
                j = start + k
                if j < size:
                    drums[j] += v * song.drum_gain
    # echo on the lead line (circular for loops so the start already carries the end's echo)
    delay = int(round(song.echo_steps * step * RATE))
    for k in range(size):
        lead[k] += lead2[k]
    if song.echo > 0:
        if song.loop:
            src = [lead[i] + (lead[i + n] if i + n < size else 0.0) for i in range(n)]
            out = src[:]
            for _ in range(3):
                for i in range(n):
                    out[i] = src[i] + song.echo * out[(i - delay) % n]
            lead = out + [0.0] * tail
        else:
            for i in range(delay, size):
                lead[i] += song.echo * lead[i - delay]
    mix = [lead[i] + harm[i] + bass[i] + drums[i] for i in range(size)]
    if song.loop:
        # wrap every tail (notes, cymbals) back onto the start: seamless loop
        for i in range(n, size):
            mix[i - n] += mix[i] if i < n * 2 else 0.0
        mix = mix[:n]
    return finish(mix, song.target_rms, loop=song.loop)


def finish(s: list[float], target_rms: float, loop: bool) -> list[float]:
    # gentle low-pass (soft 8-bit, not harsh); for loops run it twice around so it is seamless
    a = 1.0 - math.exp(-2 * math.pi * 8000 / RATE)
    y = 0.0
    if loop:
        for v in s[-2000:]:
            y += a * (v - y)
    out = []
    for v in s:
        y += a * (v - y)
        out.append(y)
    rms = math.sqrt(sum(v * v for v in out) / max(1, len(out))) or 1e-9
    pk = max(abs(v) for v in out) or 1e-9
    g = min(target_rms / rms, 0.92 / pk)
    out = [v * g for v in out]
    if not loop:
        fade = int(0.08 * RATE)
        for i in range(min(fade, len(out))):
            out[-1 - i] *= i / fade
    return out


# --------------------------------------------------------------------------
# The songs (all original)
# --------------------------------------------------------------------------

def title() -> Song:
    """Bright heroic theme, C major, 116 BPM. 16 bars."""
    prog = [("C", 16), ("G", 16), ("Am", 16), ("F", 16), ("C", 16), ("G", 16), ("F", 8), ("G", 8), ("C", 16),
            ("Am", 16), ("F", 16), ("C", 16), ("G", 16), ("Am", 16), ("F", 16), ("Dm", 8), ("G", 8), ("G", 16)]
    lead = """
    G4:2 C5:2 E5:2 G5:6 E5:2 C5:2 | D5:4 B4:2 G4:2 B4:2 D5:2 G5:4 | A4:2 C5:2 E5:2 A5:6 G5:2 E5:2 |
    F5:6 E5:2 D5:4 C5:4 | E5:2 G5:2 C6:6 B5:2 A5:2 G5:2 | B5:4 A5:2 G5:2 D5:4 G5:4 |
    A5:4 G5:2 F5:2 G5:4 F5:2 D5:2 | E5:8 C5:4 r:4 |
    E5:4 A5:4 C6:4 B5:2 A5:2 | A5:4 F5:4 C5:4 F5:4 | G5:6 E5:2 C5:4 E5:4 | D5:8 G4:4 B4:4 |
    C5:4 E5:4 A5:4 G5:2 A5:2 | C6:6 A5:2 F5:4 A5:4 | G5:4 F5:2 E5:2 D5:4 B4:4 | C5:2 D5:2 E5:2 F5:2 G5:4 B4:2 D5:2
    """
    harmony = arp(prog, 4, [0, 1, 2, 1], 2)
    bass = bass_line(prog, 2, [(0, 4), (12, 2), (7, 2), (0, 4), (12, 2), (7, 2)])
    bar_a = "k...h.h.s...h.h."
    bar_b = "k...h.k.s...h.ho"
    drums = (bar_a + bar_b) * 3 + bar_a + "k...h.h.s.s.ssss" + (bar_a + bar_b) * 3 + bar_a + "k.k.s.k.s.ss.sss"
    drums = "c" + drums[1:]
    return Song(116, 16, 16, True, lead, harmony, bass, drums, lead_duty=0.25, harm_duty=0.125,
                lead_gain=0.32, harm_gain=0.10, bass_gain=0.34, drum_gain=0.26, echo=0.25, echo_steps=3)


def field() -> Song:
    """Adventure march, G major, 132 BPM. 16 bars."""
    prog = [("G", 16), ("G", 16), ("C", 16), ("D", 16), ("Em", 16), ("C", 16), ("Am", 8), ("D", 8), ("G", 16),
            ("Em", 16), ("C", 16), ("G", 16), ("D", 16), ("C", 16), ("D", 16), ("Em", 8), ("C", 8), ("D", 16)]
    lead = """
    G4:3 B4:1 D5:4 G5:4 D5:4 | E5:2 D5:2 B4:4 G4:4 B4:4 | C5:3 E5:1 G5:4 E5:4 C5:4 | D5:3 F#5:1 A5:4 F#5:4 D5:4 |
    E5:3 G5:1 B5:4 A5:2 G5:2 E5:4 | G5:3 E5:1 C5:4 E5:4 G5:4 | A5:4 G5:2 F#5:2 E5:2 F#5:2 D5:4 | G5:8 r:4 D5:4 |
    B4:4 E5:4 G5:4 B5:4 | A5:3 G5:1 E5:4 C5:8 | D5:4 G5:4 B5:6 A5:2 | A5:8 F#5:4 D5:4 |
    E5:2 G5:2 C6:4 B5:2 A5:2 G5:4 | F#5:2 A5:2 D6:4 C6:2 B5:2 A5:4 | B5:4 G5:4 E5:4 G5:4 |
    A5:3 B5:1 A5:2 G5:2 F#5:4 D5:4
    """
    harmony = stabs(prog, 4, "..x...x.")
    bass = bass_line(prog, 2, [(0, 4), (7, 4), (12, 4), (7, 4)])
    bar = "k.h.s.h.k.h.s.h."
    roll = "k.h.s.h.k.s.ssss"
    drums = (bar * 3 + roll) * 4
    drums = "c" + drums[1:]
    return Song(132, 16, 16, True, lead, harmony, bass, drums, lead_duty=0.5, harm_duty=0.25,
                lead_gain=0.27, harm_gain=0.14, bass_gain=0.36, drum_gain=0.28, echo=0.22, echo_steps=3,
                lead2=_harmonise(lead, -3), lead2_gain=0.07)


def _harmonise(text: str, semis: int) -> str:
    """A quiet companion line a third or so below (simple diatonic-ish shift)."""
    toks = []
    for tok in text.split():
        if tok == "|":
            continue
        name, ln = tok.split(":") if ":" in tok else (tok, "2")
        if name == "r":
            toks.append(tok)
            continue
        toks.append(_name(midi(name) + semis) + ":" + ln)
    return " ".join(toks)


def boss() -> Song:
    """Tense minor battle theme, D minor, 152 BPM. 16 bars, driving 16th-note bass."""
    prog = [("Dm", 16), ("Dm", 16), ("Bb", 16), ("A", 16), ("Dm", 16), ("Gm", 16), ("Bb", 8), ("A", 8), ("Dm", 16),
            ("Gm", 16), ("Dm", 16), ("Bb", 16), ("A", 16), ("Gm", 16), ("Dm", 16), ("E7", 16), ("A", 16)]
    lead = """
    D5:4 F5:4 A5:4 G#5:2 A5:2 | Bb5:4 A5:2 G5:2 F5:4 E5:4 | D5:4 F5:2 Bb5:6 A5:2 G5:2 | A5:8 C#5:4 E5:4 |
    F5:4 E5:2 D5:2 A5:4 D6:4 | D6:4 C6:2 Bb5:2 G5:8 | Bb5:4 A5:2 G5:2 A5:2 G5:2 F5:2 E5:2 | D5:8 r:4 A4:4 |
    G5:6 F5:2 D5:4 Bb4:4 | A5:6 G5:2 F5:4 D5:4 | Bb5:4 C6:4 D6:6 C6:2 | C#6:8 A5:4 E5:4 |
    G5:2 A5:2 Bb5:4 D6:4 Bb5:4 | A5:2 G5:2 F5:4 A5:4 F5:4 | G#5:4 B5:4 D6:4 B5:4 | C#6:4 B5:2 A5:2 G5:2 F5:2 E5:2 C#5:2
    """
    harmony = arp(prog, 4, [0, 2, 1, 2], 1)
    bass = bass_line(prog, 2, [(0, 1), (0, 1), (12, 1), (0, 1)])
    bar = "k.hhs.hkk.hhs.hh"
    fill = "k.hhs.hkk.s.ssst"
    drums = (bar * 3 + fill) * 4
    drums = "c" + drums[1:]
    return Song(152, 16, 16, True, lead, harmony, bass, drums, lead_duty=0.25, harm_duty=0.125,
                lead_gain=0.30, harm_gain=0.07, bass_gain=0.30, drum_gain=0.30, echo=0.2, echo_steps=3,
                harm_decay=12.0)


def camp() -> Song:
    """Gentle lullaby, F major, 3/4 at 80 BPM, music-box arpeggios. 16 bars."""
    prog = [("F", 12), ("C", 12), ("Dm", 12), ("Bb", 12), ("F", 12), ("C", 12), ("Bb", 6), ("C", 6), ("F", 12),
            ("Dm", 12), ("Bb", 12), ("F", 12), ("C", 12), ("Dm", 12), ("Bb", 12), ("Gm", 6), ("C", 6), ("F", 12)]
    lead = """
    A4:4 C5:4 F5:4 | E5:6 D5:2 C5:4 | D5:4 F5:4 A5:4 | G5:8 F5:4 | F5:4 A5:4 C6:4 | C6:6 Bb5:2 G5:4 |
    A5:4 G5:4 E5:4 | F5:12 | A5:4 F5:4 D5:4 | D5:4 F5:4 Bb5:4 | A5:6 G5:2 F5:4 | E5:8 G5:4 |
    F5:4 A5:4 D6:4 | D6:6 C6:2 Bb5:4 | A5:4 G5:4 E5:4 | F5:8 C5:4
    """
    harmony = arp(prog, 4, [0, 1, 2, 4, 2, 1], 2)
    bass = bass_line(prog, 2, [(0, 6), (7, 6)])
    return Song(80, 12, 16, True, lead, harmony, bass, "", lead_duty=0.5, harm_duty=0.125,
                lead_gain=0.24, harm_gain=0.12, bass_gain=0.30, echo=0.35, echo_steps=3, lead_vib=0.015,
                lead_release=0.25, harm_release=0.3, lead_kind="tri", harm_decay=6.0, target_rms=0.13)


def victory() -> Song:
    """Level clear jingle (about 3 s)."""
    lead = "G4:1 C5:1 E5:1 G5:1 C6:6 G5:2 E5:2 G5:2 C6:16"
    harmony = "r:4 E5:6 D5:2 C5:2 D5:2 E5:16"
    bass = "C3:4 C3:6 G2:4 C3:18"
    drums = "kkss" + "c.....s.s.s." + "c" + "." * 15
    return Song(150, 32, 1, False, lead, harmony, bass, drums, lead_duty=0.25, harm_duty=0.5,
                lead_gain=0.32, harm_gain=0.16, bass_gain=0.36, drum_gain=0.3, echo=0.2, tail=0.9)


def fail() -> Song:
    """Sleepy, cute 'oh no' jingle (about 3 s): falling notes and a yawn."""
    lead = "G5:2 E5:2 C5:4 F5:2 D5:2 B4:4 E5:3 C5:1 A4:12"
    harmony = "r:4 C5:4 r:4 G4:4 r:4 E4:12"
    bass = "C3:8 G2:8 F2:16"
    return Song(96, 32, 1, False, lead, harmony, bass, "", lead_duty=0.5, harm_duty=0.25,
                lead_gain=0.28, harm_gain=0.10, bass_gain=0.30, echo=0.3, tail=1.0, lead_kind="tri",
                lead_vib=0.02, lead_release=0.2)


def chapter_clear() -> Song:
    """The big fanfare after beating the black knight (about 8 s)."""
    lead = """
    G4:2 C5:2 E5:2 G5:4 E5:2 G5:4 | A5:4 F5:2 A5:2 C6:8 | B5:2 G5:2 D5:2 G5:2 B5:4 D6:4 | C6:16
    """
    harmony = arp([("C", 16), ("F", 16), ("G", 16)], 4, [0, 1, 2, 1], 2) + " C5:16"
    bass = "C3:4 G2:4 C3:4 E3:4 F2:4 C3:4 F3:8 G2:4 D3:4 G2:4 B2:4 C3:16"
    drums = "c...h.h.s...h.h." + "k...h.h.s...h.h." + "k...h.k.s.s.ssss" + "c" + "." * 15
    return Song(120, 16, 4, False, lead, harmony, bass, drums, lead_duty=0.25, harm_duty=0.125,
                lead_gain=0.32, harm_gain=0.11, bass_gain=0.36, drum_gain=0.28, echo=0.25, tail=1.5,
                lead2=_harmonise(lead, -5), lead2_gain=0.10)


SONGS = {"title": title, "field": field, "boss": boss, "camp": camp,
         "victory": victory, "fail": fail, "chapter_clear": chapter_clear}
LOOPS = ("title", "field", "boss", "camp")


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


IMPORT_PARAMS = """[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={loop}
edit/loop_begin=0
edit/loop_end=-1
compress/mode=2
"""


def write_import(wav_res: str, loop: bool) -> None:
    """Make sure Godot imports the file as QOA, looping (Forward over the whole file) or not."""
    path = res_path(wav_res) + ".import"
    loop_mode = "2" if loop else "1"
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            text = f.read()
        lines = []
        for line in text.splitlines():
            if line.startswith("edit/loop_mode="):
                line = "edit/loop_mode=" + loop_mode
            elif line.startswith("compress/mode="):
                line = "compress/mode=2"
            lines.append(line)
        new = "\n".join(lines) + "\n"
        if new != text:
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(new)
        return
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write('[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n' + IMPORT_PARAMS.format(loop=loop_mode))


def write_all(only: list[str] | None = None) -> None:
    for name, fn in SONGS.items():
        if only and name not in only:
            continue
        res = "res://assets/music/%s.wav" % name
        write_wav(res_path(res), render(fn()))
        write_import(res, name in LOOPS)


if __name__ == "__main__":
    import sys
    sys.dont_write_bytecode = True
    write_all(sys.argv[1:] or None)
    print("music written")
