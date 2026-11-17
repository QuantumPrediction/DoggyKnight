"""v2.6 (CW1): chapter 1 backgrounds repainted with more depth (owner: 「再修一輪背景」).

The six v2.5 scenes (art_world.SCENES) stay the base for the arena and the near props. On top:
- far layer: a real horizon above the top tree rows - sky bands, mountain ranges with one lit and one
  shaded face per peak, Camelot far away, hazy hills (pale, low contrast = far away);
- mid layer: a row of trees / crops along the seam in lighter, hazier colours than the near trees;
- the stone bridge (1-6) is calmed: the bright stone_l paving becomes two close mid tones (stone, ash),
  light pools and puddles are toned down, so the knight and the telegraphs read first;
- the near layer (foreground) still comes from art_light.decorate.

    python3 tools/pixel/art_v26_ch1.py [names...] [--preview DIR]
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art_light as AL  # noqa: E402
import art_world as AW  # noqa: E402
import art_v26_kit as K  # noqa: E402
import art_v26_title as T  # noqa: E402
from art_world import AX0, AX1, AY0, AY1, IMG_H, IMG_W, name_at  # noqa: E402
from pixel import Canvas, res_path, write_text  # noqa: E402


def _vista(img: Canvas, cut: int, sky, far: tuple[str, str, str, str | None], hills: tuple[str, str], seed: int,
           castle: tuple[int, tuple[str, str, str]] | None = None, peaks=None) -> None:
    """Repaint everything above `cut` as a distant view: sky, a mountain range, rolling hazy hills."""
    v = Canvas(IMG_W, cut + 1)
    K.sky_bands(v, 0, cut, sky, seed=seed, wave=1.8)
    lit, shade_col, rim, snow = far
    peaks = peaks or [(30, 26, 50), (110, 34, 60), (196, 24, 50), (270, 30, 56)]
    base = cut - 10
    K.peaks_layer(v, base, peaks, lit, shade_col, rim=rim, snow=(snow, lit) if snow else None, seed=seed + 1,
                  rough=1.0, fill_to=cut + 1)
    if castle:
        T.castle(v, castle[0], base - 2, 0.7, wall=castle[1], roof=("rose", "coral", "peach"))
    K.hills_layer(v, cut - 4, 4, 29.0, hills[0], rim=hills[1], seed=seed + 2, fill_to=cut + 1)
    for y in range(cut + 1):
        for x in range(IMG_W):
            img.set(x, y, name_at(v, x, y))


def _mid_trees(img: Canvas, base: int, ramp, outline: str, seed: int, size: int = 24, step: int = 18,
               skip=None) -> None:
    for i, x in enumerate(range(-10, IMG_W, step)):
        if skip and skip(x):
            continue
        t = AW.tree(seed + i, size, ramp, outline)
        img.blit(t, x, base - t.h + (i * 5) % 6)


def post_sword_stone(sc) -> None:
    img = sc.img
    _vista(img, 46, [("sky", 0.0), ("azure", 0.35), ("sky_l", 0.6), ("haze", 0.85)],
           ("fog", "lilac", "white", "white"), ("spring", "leaf_l"), 1101, castle=(96, ("lilac", "fog", "white")))
    _mid_trees(img, 64, ("leaf_d", "leaf", "spring", "leaf_l"), "leaf_d", 1110, 22, 16)


def post_wheat_field(sc) -> None:
    img = sc.img
    _vista(img, 34, [("sky", 0.0), ("azure", 0.4), ("sky_l", 0.7), ("haze", 0.9)],
           ("haze", "fog", "white", None), ("gold_l", "cream"), 1201,
           peaks=[(60, 14, 60), (180, 18, 70), (290, 12, 50)])
    # a far farmhouse and windmill on the golden hills
    for (x, w) in ((40, 14), (226, 12)):
        for y in range(18, 28):
            for xx in range(x, x + w):
                img.set(xx, y, "cream" if xx < x + w - 3 else "sand")
        for k in range(5):
            img.hline(x - 1 + k, x + w - k, 17 - k, "coral" if k < 4 else "red")
    img.vline(250, 6, 20, "sand")
    for d in range(-5, 6):
        img.set(250 + d, 8 + d, "cream")
        img.set(250 + d, 8 - d, "cream")
    _mid_trees(img, 46, ("gold_d", "moss", "leaf_l", "spring"), "moss_d", 1210, 18, 26, skip=lambda x: 100 < x < 170)


def post_meadow(sc) -> None:
    img = sc.img
    _vista(img, 38, [("sky", 0.0), ("azure", 0.35), ("sky_l", 0.65), ("haze", 0.88)],
           ("fog", "lilac", "white", "white"), ("leaf_l", "spring"), 1301,
           peaks=[(10, 22, 50), (90, 28, 56), (170, 20, 50), (250, 30, 60)])
    _mid_trees(img, 54, ("rose", "pink", "peach", "white"), "rose", 1310, 20, 24)


def post_farm_fence(sc) -> None:
    img = sc.img
    _vista(img, 24, [("rose", 0.0), ("coral", 0.35), ("peach", 0.65), ("cream", 0.9)],
           ("peach", "rose", "cream", None), ("dirt", "sand"), 1401,
           peaks=[(50, 10, 60), (170, 14, 70), (280, 10, 50)])
    _mid_trees(img, 36, ("gold_d", "gold", "gold_l", "cream"), "brown", 1410, 16, 20, skip=lambda x: 140 < x < 210)


def post_crow_forest(sc) -> None:
    img = sc.img
    sky = ("peach", "rose", "dusk", "plum")
    v = Canvas(IMG_W, 104)
    K.peaks_layer(v, 92, [(30, 34, 50), (120, 40, 60), (200, 30, 50), (280, 38, 56)], "dusk", "plum", rim="rose",
                  seed=1501, rough=1.2, fill_to=104)
    K.treeline(v, 98, ("plum", "dusk", "dusk", "rose"), 1502, size=(3.0, 5.0), step=4, pointy=True)
    for y in range(104):
        for x in range(IMG_W):
            n = name_at(v, x, y)
            if n and name_at(img, x, y) in sky + ("cream", "yellow"):
                img.set(x, y, n)


def post_bridge(sc) -> None:
    img = sc.img
    deck = lambda x, y: (AX0 <= x < AX1 and AY0 <= y < AY1) or (120 <= x < 184 and 40 <= y < 470)  # noqa: E731
    calm = {"stone_l": "stone", "stone": "ash", "cream": "stone_l", "dirt": "stone", "white": "steel_l",
            "steel_l": "steel"}
    for y in range(IMG_H):
        for x in range(IMG_W):
            if deck(x, y) and y >= 150:
                n = name_at(img, x, y)
                if n in calm:
                    img.set(x, y, calm[n])
    # far layer: a moon in torn cloud and dark mountains behind the castle
    v = Canvas(IMG_W, 60)
    K.sky_bands(v, 0, 60, [("navy", 0.0), ("night_d", 0.4)], seed=1601)
    K.stars(v, (0, 0, IMG_W, 40), 30, 1602, big=2)
    K.moon(v, 236, 22, 10, halo=("night_d", "night"))
    T_cloud = __import__("art_v26_world").cloud_bank
    T_cloud(v, 30, ("night_d", "night", "water_d"), 1603, x0=170, size=(4.0, 7.0), step=10)
    K.peaks_layer(v, 60, [(20, 22, 50), (110, 30, 60), (200, 18, 46), (290, 26, 50)], "night", "night_d",
                  rim="water_d", seed=1604, fill_to=60)
    for y in range(60):
        for x in range(IMG_W):
            if name_at(img, x, y) in ("night_d", "night", "steel", "steel_l"):
                img.set(x, y, name_at(v, x, y))


POST = {
    "sword_stone": post_sword_stone,
    "wheat_field": post_wheat_field,
    "meadow": post_meadow,
    "farm_fence": post_farm_fence,
    "crow_forest": post_crow_forest,
    "bridge": post_bridge,
}


def write_all(names: list[str] | None = None, preview_dir: str | None = None) -> None:
    for name, fn in AW.SCENES.items():
        if names and name not in names:
            continue
        sc = fn()
        POST[name](sc)
        AL.decorate(name, sc)
        sc.fg.save(res_path("res://assets/backgrounds/%s_fg.png" % name))
        sc.img.save(res_path("res://assets/backgrounds/%s.png" % name))
        write_text(res_path("res://assets/backgrounds/%s.tscn" % name), AW.background_tscn(name, sc))
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            full = sc.img.copy()
            full.blit(sc.fg, 0, 0)
            full.scaled(2).save(os.path.join(preview_dir, "%s_full.png" % name))


if __name__ == "__main__":
    args = sys.argv[1:]
    pdir = None
    if "--preview" in args:
        i = args.index("--preview")
        pdir = args[i + 1]
        del args[i:i + 2]
    write_all(args or None, pdir)
    print("chapter 1 repaint written")
