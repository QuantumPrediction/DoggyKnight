"""v2.7 (CW9): the chapter 4-6 field and boss themes, written with the music_gen tracker.
Python 3 standard library only. All melodies are original.

    field_4  輕快海風      a breezy 6/8 sea jig in D major
    boss_4   海底、有點滑稽 a bouncy G minor polka with chromatic "bloop" runs (the hungry Kraken)
    field_5  雪山          cold, wide and bright: E minor, bell arpeggios, a soft triangle melody
    boss_5   雙龍、熱鬧     a busy A minor gallop with tom fills (two dragons squabbling)
    field_6  行軍、堅定     a steady D minor march with snare rolls
    boss_6   最終戰、壯闊而溫暖 the final battle: F major, soaring lead doubled an octave down, driving arps

All six are seamless loops (QOA, Forward loop over the whole file): assets/music/<id>.wav + .import.

    python3 tools/pixel/music_v27.py [ids...]
"""

from __future__ import annotations

import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import music_gen as M  # noqa: E402
from music_gen import Song, arp, bass_line, stabs, _harmonise  # noqa: E402
from pixel import res_path  # noqa: E402


def field_4() -> Song:
    """Chapter 4 field: a light sea jig in 6/8 (12 steps a bar), D major, 116 BPM; a skipping melody over a
    rocking bass and a lilting arpeggio. 16 bars."""
    prog = [("D", 12), ("G", 12), ("D", 12), ("A", 12), ("D", 12), ("G", 12), ("A", 12), ("D", 12),
            ("Bm", 12), ("G", 12), ("D", 12), ("A", 12), ("G", 12), ("A", 12), ("D", 12), ("D", 12)]
    lead = """
    A4:2 D5:2 F#5:2 A5:4 F#5:2 | G5:2 F#5:2 E5:2 D5:4 B4:2 | A4:2 D5:2 F#5:2 A5:2 B5:2 A5:2 | G5:4 E5:2 C#5:6 |
    F#5:2 A5:2 D6:2 C#6:2 B5:2 A5:2 | B5:4 G5:2 D5:4 G5:2 | A5:2 G5:2 F#5:2 E5:2 F#5:2 G5:2 | F#5:6 D5:6 |
    B4:2 D5:2 F#5:2 B5:4 A5:2 | G5:2 B5:2 D6:2 B5:4 G5:2 | A5:4 F#5:2 D5:4 F#5:2 | E5:2 F#5:2 G5:2 A5:6 |
    B5:2 A5:2 G5:2 D6:4 B5:2 | C#6:2 B5:2 A5:2 E5:4 C#5:2 | D5:2 F#5:2 A5:2 D6:4 C#6:2 | D6:6 A5:2 F#5:2 E5:2
    """
    harmony = arp(prog, 4, [0, 1, 2, 1, 2, 1], 2)
    bass = bass_line(prog, 2, [(0, 4), (7, 2), (12, 4), (7, 2)])
    bar = "k...h.s...h."
    fill = "k...h.s.s.ss"
    drums = (bar * 3 + fill) * 4
    drums = "c" + drums[1:]
    return Song(116, 12, 16, True, lead, harmony, bass, drums, lead_duty=0.25, harm_duty=0.125,
                lead_gain=0.28, harm_gain=0.11, bass_gain=0.32, drum_gain=0.22, echo=0.26, echo_steps=3,
                lead2=_harmonise(lead, -3), lead2_gain=0.06)


def boss_4() -> Song:
    """Chapter 4 boss (the Kraken): a bouncy, slightly silly G minor polka, 140 BPM - staccato leaps, chromatic
    slides, an oom-pah bass and off-beat stabs. 16 bars."""
    prog = [("Gm", 16), ("Gm", 16), ("D7", 16), ("D7", 16), ("Gm", 16), ("Gm", 16), ("Cm", 16), ("D7", 16),
            ("Eb", 16), ("Eb", 16), ("D", 16), ("D", 16), ("Cm", 16), ("Gm", 16), ("D7", 16), ("Gm", 16)]
    lead = """
    G4:2 r:2 Bb4:2 r:2 D5:3 C#5:1 D5:4 | G5:2 F#5:2 F5:2 E5:2 Eb5:4 D5:4 |
    A4:2 r:2 C5:2 r:2 F#5:3 E5:1 F#5:4 | A5:2 G5:2 F#5:2 E5:2 D5:4 r:4 |
    G4:2 Bb4:2 D5:2 G5:2 Bb5:4 A5:2 G5:2 | D5:2 r:2 D5:2 Eb5:2 D5:4 Bb4:4 |
    C5:2 Eb5:2 G5:2 C6:2 Bb5:2 A5:2 G5:2 F#5:2 | A5:4 F#5:2 D5:2 A4:8 |
    Eb5:2 r:2 G5:2 r:2 Bb5:3 A5:1 Bb5:4 | C6:2 Bb5:2 G5:2 Eb5:2 F5:4 G5:4 |
    F#5:2 r:2 A5:2 r:2 D6:3 C#6:1 D6:4 | C6:2 Bb5:2 A5:2 G5:2 F#5:4 D5:4 |
    Eb5:2 D5:2 C5:2 Eb5:2 G5:4 C6:4 | Bb5:2 A5:2 G5:2 D5:2 Bb4:4 G4:4 |
    A4:2 B4:2 C5:2 D5:2 Eb5:2 E5:2 F#5:2 A5:2 | G5:4 D5:2 Bb4:2 G4:4 r:4
    """
    harmony = stabs(prog, 4, ".x.x")
    bass = bass_line(prog, 2, [(0, 2), (12, 2), (7, 2), (12, 2)])
    bar = "k...s..kk...s.k."
    fill = "k...s..kk.s.s.ss"
    drums = (bar * 3 + fill) * 4
    drums = "c" + drums[1:]
    return Song(140, 16, 16, True, lead, harmony, bass, drums, lead_duty=0.125, harm_duty=0.25,
                lead_gain=0.30, harm_gain=0.10, bass_gain=0.34, drum_gain=0.26, echo=0.16, echo_steps=2,
                lead_release=0.03)


def field_5() -> Song:
    """Chapter 5 field (the snowy mountain): cold, wide and bright - E minor, 104 BPM, a soft triangle melody
    with vibrato over high bell-like arpeggios and a slow bass; light drums like wind. 16 bars."""
    prog = [("Em", 16), ("C", 16), ("G", 16), ("D", 16), ("Em", 16), ("C", 16), ("Am", 16), ("B7", 16),
            ("C", 16), ("G", 16), ("D", 16), ("Em", 16), ("C", 16), ("D", 16), ("B7", 16), ("Em", 16)]
    lead = """
    B4:4 E5:4 G5:6 F#5:2 | E5:4 G5:4 C6:8 | B5:4 A5:2 G5:2 D5:8 | F#5:4 A5:4 D6:6 C6:2 |
    B5:6 G5:2 E5:4 G5:4 | A5:4 G5:4 E5:4 C5:4 | E5:2 F#5:2 G5:4 A5:4 C6:4 | B5:8 D#5:4 F#5:4 |
    E5:4 G5:4 C6:6 B5:2 | D6:4 B5:4 G5:8 | A5:4 F#5:4 D5:4 F#5:4 | G5:6 F#5:2 E5:8 |
    G5:4 C6:4 E6:6 D6:2 | D6:4 C6:4 A5:8 | B5:4 A5:2 G5:2 F#5:4 D#5:4 | E5:12 r:4
    """
    harmony = arp(prog, 5, [0, 1, 2, 4, 2, 1, 2, 1], 2)
    bass = bass_line(prog, 2, [(0, 8), (7, 8)])
    bar = "k.......h......."
    drums = (bar * 3 + "k.......h...t.t.") * 4
    return Song(104, 16, 16, True, lead, harmony, bass, drums, lead_duty=0.5, harm_duty=0.125,
                lead_gain=0.26, harm_gain=0.09, bass_gain=0.28, drum_gain=0.14, echo=0.38, echo_steps=6,
                lead_vib=0.018, lead_release=0.25, harm_release=0.3, lead_kind="tri", harm_decay=7.0,
                target_rms=0.12)


def boss_5() -> Song:
    """Chapter 5 boss (the red and the white dragon): busy and festive, A minor, 160 BPM - a racing 16th
    arpeggio, a driving bass, a melody answered by its own echo a fourth below, tom fills. 16 bars."""
    prog = [("Am", 16), ("F", 16), ("G", 16), ("Am", 16), ("Am", 16), ("F", 16), ("G", 16), ("E", 16),
            ("Dm", 16), ("Am", 16), ("Dm", 16), ("E", 16), ("F", 16), ("G", 16), ("E7", 16), ("Am", 16)]
    lead = """
    A4:2 C5:2 E5:2 A5:2 G5:2 A5:2 E5:4 | F5:2 A5:2 C6:2 A5:2 G5:2 F5:2 C5:4 |
    D5:2 G5:2 B5:2 D6:2 C6:2 B5:2 G5:4 | A5:3 G5:1 E5:3 D5:1 C5:4 E5:4 |
    A4:2 C5:2 E5:2 A5:2 C6:2 B5:2 A5:4 | A5:2 C6:2 F6:2 E6:2 D6:2 C6:2 A5:4 |
    B5:2 D6:2 G6:2 F6:2 E6:2 D6:2 B5:4 | G#5:4 B5:4 E6:8 |
    D5:2 F5:2 A5:2 D6:2 C6:2 A5:2 F5:4 | E5:2 A5:2 C6:2 E6:2 D6:2 C6:2 A5:4 |
    F5:3 E5:1 D5:3 E5:1 F5:4 A5:4 | G#5:3 A5:1 B5:3 C6:1 B5:4 E5:4 |
    C6:2 A5:2 F5:2 A5:2 C6:4 F6:4 | D6:2 B5:2 G5:2 B5:2 D6:4 G6:4 |
    E6:2 D6:2 B5:2 G#5:2 E5:2 D5:2 B4:2 G#4:2 | A4:4 E5:4 A5:8
    """
    harmony = arp(prog, 4, [0, 2, 1, 2], 1)
    bass = bass_line(prog, 2, [(0, 1), (0, 1), (12, 1), (0, 1)])
    bar = "k.hhs.hhk.kks.hh"
    fill = "k.hhs.hhk.ttt.tt"
    drums = (bar * 3 + fill) * 4
    drums = "c" + drums[1:]
    return Song(160, 16, 16, True, lead, harmony, bass, drums, lead_duty=0.25, harm_duty=0.125,
                lead_gain=0.28, harm_gain=0.07, bass_gain=0.30, drum_gain=0.28, echo=0.2, echo_steps=3,
                harm_decay=12.0, lead2=_harmonise(lead, -5), lead2_gain=0.08)


def field_6() -> Song:
    """Chapter 6 field: a steady, determined march in D minor, 120 BPM - dotted rhythms, a snare-roll
    march beat and a walking bass. 16 bars."""
    prog = [("Dm", 16), ("Bb", 16), ("F", 16), ("C", 16), ("Dm", 16), ("Bb", 16), ("Gm", 16), ("A", 16),
            ("Bb", 16), ("F", 16), ("C", 16), ("Dm", 16), ("Gm", 16), ("C", 16), ("A", 16), ("Dm", 16)]
    lead = """
    D5:6 E5:2 F5:4 A5:4 | Bb5:6 A5:2 G5:4 F5:4 | A5:6 G5:2 F5:4 C5:4 | E5:4 G5:4 C6:8 |
    D6:6 C6:2 A5:4 F5:4 | F5:4 Bb5:4 D6:6 C6:2 | Bb5:4 A5:2 G5:2 D5:4 G5:4 | A5:8 C#5:4 E5:4 |
    F5:3 F5:1 Bb5:4 D6:4 Bb5:4 | C6:3 C6:1 A5:4 F5:4 A5:4 | G5:3 G5:1 C6:4 E6:4 C6:4 | D6:8 A5:4 F5:4 |
    G5:4 Bb5:4 D6:4 G6:4 | E6:4 D6:2 C6:2 G5:4 E5:4 | C#6:4 E6:4 A5:4 C#6:4 | D6:8 A5:4 D5:4
    """
    harmony = stabs(prog, 4, "..x...x.")
    bass = bass_line(prog, 2, [(0, 4), (7, 4), (12, 4), (7, 4)])
    bar = "k...s.s.k...s.ss"
    roll = "k...s.s.k.s.ssss"
    drums = (bar * 3 + roll) * 4
    drums = "c" + drums[1:]
    return Song(120, 16, 16, True, lead, harmony, bass, drums, lead_duty=0.25, harm_duty=0.25,
                lead_gain=0.28, harm_gain=0.12, bass_gain=0.34, drum_gain=0.26, echo=0.22, echo_steps=3,
                lead2=_harmonise(lead, -5), lead2_gain=0.07)


def boss_6() -> Song:
    """Chapter 6 boss (the final battle with Mordred at Avalon): epic but warm - F major with its relative
    minor, 132 BPM; a soaring lead doubled an octave below, driving 16th arpeggios, a pulsing bass,
    crashes every four bars. 16 bars."""
    prog = [("F", 16), ("C", 16), ("Dm", 16), ("Bb", 16), ("F", 16), ("C", 16), ("Bb", 16), ("C", 16),
            ("Dm", 16), ("Bb", 16), ("F", 16), ("C", 16), ("Gm", 16), ("Bb", 16), ("C", 16), ("F", 16)]
    lead = """
    C5:4 F5:4 A5:6 G5:2 | G5:4 E5:4 C6:8 | A5:4 D6:4 F6:6 E6:2 | D6:4 C6:2 Bb5:2 F5:8 |
    A5:4 C6:4 F6:6 E6:2 | G6:4 E6:4 C6:8 | D6:4 F6:4 Bb5:4 D6:4 | C6:4 Bb5:2 A5:2 G5:8 |
    F5:2 A5:2 D6:4 F6:4 E6:2 D6:2 | D6:4 F6:4 Bb5:4 C6:2 D6:2 | C6:6 A5:2 F5:4 A5:4 | G5:4 C6:4 E6:6 D6:2 |
    D6:4 Bb5:4 G5:4 Bb5:4 | F6:6 E6:2 D6:4 Bb5:4 | C6:4 D6:2 E6:2 G6:4 E6:4 | F6:8 C6:4 A5:4
    """
    harmony = arp(prog, 4, [0, 2, 1, 2], 1)
    bass = bass_line(prog, 2, [(0, 2), (0, 2), (12, 2), (0, 2), (7, 2), (0, 2), (12, 2), (7, 2)])
    bar = "k...s..kk.k.s..."
    fill = "k...s..kk.s.ssst"
    drums = ("c" + bar[1:] + bar + bar + fill) * 4
    return Song(132, 16, 16, True, lead, harmony, bass, drums, lead_duty=0.5, harm_duty=0.125,
                lead_gain=0.27, harm_gain=0.07, bass_gain=0.32, drum_gain=0.27, echo=0.26, echo_steps=3,
                harm_decay=10.0, lead_vib=0.016, lead2=_harmonise(lead, -12), lead2_gain=0.10)


SONGS = {"field_4": field_4, "boss_4": boss_4, "field_5": field_5, "boss_5": boss_5, "field_6": field_6,
         "boss_6": boss_6}


def write_all(only: list[str] | None = None) -> None:
    for name, fn in SONGS.items():
        if only and name not in only:
            continue
        res = "res://assets/music/%s.wav" % name
        M.write_wav(res_path(res), M.render(fn()))
        M.write_import(res, True)


if __name__ == "__main__":
    write_all(sys.argv[1:] or None)
    print("v2.7 music written")
