"""v2.5 (CR5) combat effects, redrawn to match the larger characters.

No ordered dithering and no single-pixel speckles any more: trails fade by getting thinner, sparks
are chunky two-pixel rays with a coloured edge, puffs are shaded little clouds.

  slash          32x32  (unchanged cell: line A places it 10 px in front of Goldie)
  hit_spark      20x20  (was 16)
  dust           12x12  (was 8)
  dizzy_stars    20x12  (was 16x10)
  exp_orb        12x12  (v2.2 art kept)
  ultimate_slash 64x64  (dither-free fade)
"""

from __future__ import annotations

import math

import art_fx
from art_fx import crescent, smear
from pixel import Anim, Canvas
from rig import Fig, Mat, ellipse


def _outline_where_empty(c: Canvas, col: str) -> Canvas:
    out = c.copy()
    for y in range(c.h):
        for x in range(c.w):
            if c.opaque(x, y):
                continue
            if any(c.opaque(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.set(x, y, col)
    return out


def slash() -> list[Anim]:
    s = 32
    blue = ["white", "white", "sky_l", "azure", "sky"]
    f0 = smear(s, -85, -20, 14, 4, ["white", "sky_l", "azure"], tail=0.0)
    f1 = smear(s, -88, 72, 15, 8, blue, tail=0.0)
    f2 = smear(s, -40, 86, 15, 5, ["sky_l", "white", "azure", "sky"], tail=0.0)
    f3 = smear(s, 10, 88, 15, 2, ["azure", "sky"], tail=0.0)
    for c, pts in ((f2, ((27, 23), (23, 28))), (f3, ((28, 20), (22, 29)))):
        for (x, y) in pts:
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                c.set(x + dx, y + dy, "white" if (dx, dy) == (0, 0) else "sky_l")
    frames = [_outline_where_empty(f, "water@170") for f in (f0, f1, f2)] + [f3]
    return [Anim("default", frames, 22.0, False, [0.8, 1.2, 1.0, 1.0])]


def _rays(c: Canvas, cx: float, cy: float, n: int, r0: float, r1: float, rot: float, cols: tuple[str, str],
          width: float = 1.0) -> None:
    for k in range(n):
        ang = rot + 2 * math.pi * k / n
        ln = r1 if k % 2 == 0 else r0 + (r1 - r0) * 0.55
        d = r0
        while d <= ln:
            for w in ((0.0,) if width <= 1 else (-0.5, 0.5)):
                x = int(math.floor(cx + math.cos(ang) * d - math.sin(ang) * w))
                y = int(math.floor(cy + math.sin(ang) * d + math.cos(ang) * w))
                c.set(x, y, cols[0] if d < (r0 + ln) * 0.55 else cols[1])
            d += 0.5


def hit_spark() -> list[Anim]:
    s = 20
    f0 = Canvas(s, s)
    f0.ellipse(10, 10, 4.2, 4.2, "yellow")
    f0.ellipse(9.6, 9.6, 2.8, 2.8, "white")
    f0 = _outline_where_empty(f0, "orange")
    f1 = Canvas(s, s)
    _rays(f1, 10, 10, 8, 2, 9, 0.0, ("white", "yellow"), width=2)
    f1.ellipse(10, 10, 2.4, 2.4, "white")
    f1 = _outline_where_empty(f1, "orange@200")
    f2 = Canvas(s, s)
    _rays(f2, 10, 10, 8, 5, 9.5, 0.2, ("yellow", "orange"), width=2)
    f3 = Canvas(s, s)
    for (x, y) in ((2, 9), (17, 10), (10, 2), (9, 17), (4, 4), (15, 15), (15, 4)):
        f3.set(x, y, "yellow")
        f3.set(x + 1, y, "orange")
    return [Anim("default", [f0, f1, f2, f3], 20.0, False, [0.8, 1.0, 1.0, 1.0])]


PUFF = Mat(["fog", "white", "white"], outline="ash@220", lit="fog@220")


def _puff(blobs, size: int = 12, alpha: int = 255) -> Canvas:
    f = Fig(size, size, seed=3)
    for (x, y, r) in blobs:
        f.add(ellipse(x, y, r, r * 0.85), PUFF, bias=0.15, sep=False)
    c = f.render()
    if alpha < 255:
        for i, p in enumerate(c.px):
            if p is not None:
                c.px[i] = (p[0], p[1], p[2], min(p[3], alpha))
    return c


def dust() -> list[Anim]:
    f0 = _puff([(6, 8, 2.6)])
    f1 = _puff([(4, 7.5, 2.8), (7.6, 7, 2.6), (6, 5.5, 2.0)])
    f2 = _puff([(3.5, 6.5, 2.4), (8.4, 5.6, 2.2)], alpha=200)
    f3 = _puff([(3, 5, 1.4), (9, 4, 1.4)], alpha=140)
    return [Anim("default", [f0, f1, f2, f3], 14.0, False)]


STAR = ["..Y..", ".YYY.", "YYwYY", ".YYY.", "..Y.."]


def dizzy_stars() -> list[Anim]:
    frames = []
    for i in range(6):
        c = Canvas(20, 12)
        pts = []
        for k in range(3):
            ang = 2 * math.pi * (k / 3 + i / 18)
            x = 10 + math.cos(ang) * 7
            y = 6 + math.sin(ang) * 3
            pts.append((math.sin(ang), int(round(x)) - 2, int(round(y)) - 2))
        for depth, x, y in sorted(pts):
            front = depth > -0.2
            star = Canvas(5, 5)
            star.stamp(STAR, 0, 0, {"Y": "yellow" if front else "gold_l", "w": "white" if front else "yellow"},
                       outline=None)
            star = _outline_where_empty(star, "gold_d")
            big = Canvas(20, 12)
            big.blit(star, x, y)
            for yy in range(12):
                for xx in range(20):
                    p = big.get(xx, yy)
                    if p is not None:
                        c.set(xx, yy, p)
        frames.append(c)
    return [Anim("default", frames, 12.0, True)]


def ultimate_slash() -> list[Anim]:
    anims = art_fx.ultimate_slash_v2()
    frames = anims[0].frames
    gold = ["white", "yellow", "gold_l", "amber"]
    f = crescent(64, -180, 180, 31, 3, ["white", "yellow", "gold_l"], uniform=True)
    frames[4] = f
    frames[1] = smear(64, -180, -20, 29, 10, gold, tail=0.0)
    frames[2] = smear(64, -180, 130, 29, 11, gold, tail=0.0)
    return [Anim("default", frames, anims[0].fps, False, anims[0].durations)]


ALL = {
    "slash": (slash, (32, 32)),
    "hit_spark": (hit_spark, (20, 20)),
    "exp_orb": (art_fx.exp_orb_v2, (12, 12)),
    "ultimate_slash": (ultimate_slash, (64, 64)),
    "dizzy_stars": (dizzy_stars, (20, 12)),
    "dust": (dust, (12, 12)),
}
