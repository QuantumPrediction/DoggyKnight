"""Effects (C7, DEV_PLAN 4.9): slash, hit_spark, exp_orb, ultimate_slash, dizzy_stars, dust.

All drawn procedurally from the palette. Every effect is centred in its frame so
line A can place it with a centred AnimatedSprite2D; the slash opens to the right
(rotate it toward the target; mirror for the left side).
"""

from __future__ import annotations

import math

from palette import rgba
from pixel import Anim, Canvas


def _polar(cx: float, cy: float, x: int, y: int) -> tuple[float, float]:
    dx = x + 0.5 - cx
    dy = y + 0.5 - cy
    return math.hypot(dx, dy), math.degrees(math.atan2(dy, dx))


def crescent(size: int, a0: float, a1: float, r_out: float, thick: float, colors: list[str],
             fade: float = 1.0, uniform: bool = False) -> Canvas:
    """Crescent from angle a0 to a1 (degrees, 0 = right, positive = down); thickest in the middle."""
    c = Canvas(size, size)
    cx = cy = size / 2
    for y in range(size):
        for x in range(size):
            r, a = _polar(cx, cy, x, y)
            if not (a0 <= a <= a1):
                continue
            t = (a - a0) / max(1e-6, (a1 - a0))
            w = thick * fade if uniform else thick * math.sin(math.pi * t) ** 0.6 * fade
            if r_out - w <= r <= r_out:
                depth = (r_out - r) / max(1e-6, w)
                idx = min(len(colors) - 1, int(depth * len(colors)))
                c.set(x, y, colors[idx])
    return c


def slash() -> list[Anim]:
    s = 32
    f0 = crescent(s, -80, -10, 14, 4, ["white", "sky_l"])
    f1 = crescent(s, -75, 75, 14, 6, ["white", "white", "sky_l", "sky"])
    f2 = crescent(s, 10, 80, 14, 3, ["sky_l", "sky"])
    for (x, y) in [(27, 22), (24, 27)]:
        f2.set(x, y, "white")
    return [Anim("default", [f0, f1, f2], 18.0, False)]


def _burst(size: int, rays: int, r0: float, r1: float, core: int, colors: tuple[str, str, str]) -> Canvas:
    c = Canvas(size, size)
    cx = cy = size // 2
    for k in range(rays):
        ang = 2 * math.pi * k / rays
        long_ray = k % 2 == 0
        rr = r1 if long_ray else r1 * 0.6
        steps = int(rr * 2) + 1
        for i in range(steps):
            d = r0 + (rr - r0) * i / max(1, steps - 1)
            x = int(round(cx + math.cos(ang) * d - 0.5))
            y = int(round(cy + math.sin(ang) * d - 0.5))
            c.set(x, y, colors[1] if d < rr * 0.7 else colors[2])
    for y in range(cy - core, cy + core):
        for x in range(cx - core, cx + core):
            if abs(x + 0.5 - cx) + abs(y + 0.5 - cy) <= core:
                c.set(x, y, colors[0])
    return c


def hit_spark() -> list[Anim]:
    f0 = _burst(16, 8, 1, 4, 2, ("white", "yellow", "yellow"))
    f1 = _burst(16, 8, 2, 7, 2, ("white", "yellow", "orange"))
    f2 = Canvas(16, 16)
    for (x, y) in [(2, 8), (13, 7), (8, 2), (7, 13), (4, 4), (11, 11), (11, 4), (4, 11)]:
        f2.set(x, y, "yellow")
    f2.set(8, 8, "white")
    return [Anim("default", [f0, f1, f2], 18.0, False)]


ORB = [
    "..ss..",
    ".slls.",
    "slwlls",
    "sllllS",
    ".sllS.",
    "..SS..",
]


def exp_orb() -> list[Anim]:
    legend = {"s": "sky", "l": "sky_l", "w": "white", "S": "water"}
    frames = []
    sparkles = [(6, 1), (7, 6), (1, 6), (0, 1)]
    for i in range(4):
        c = Canvas(8, 8)
        c.stamp(ORB, 1, 1 + (1 if i in (1, 2) else 0), legend, outline="water_d")
        sx, sy = sparkles[i]
        c.set(sx, sy, "white")
        frames.append(c)
    return [Anim("default", frames, 6.0, True)]


def ultimate_slash() -> list[Anim]:
    s = 64
    frames = []
    # 0: flash of light at the centre
    f = Canvas(s, s)
    f.ellipse(32, 32, 7, 7, "yellow")
    f.ellipse(32, 32, 4, 4, "white")
    for k in range(8):
        ang = math.pi * k / 4
        for d in range(8, 14):
            f.set(int(32 + math.cos(ang) * d), int(32 + math.sin(ang) * d), "white" if d < 11 else "yellow")
    frames.append(f)
    # 1-3: golden ring sweeping around (clockwise from the left)
    gold = ["white", "yellow", "gold_l", "orange"]
    for a1 in (-20, 130):
        f = Canvas(s, s)
        f.blit(crescent(s, -180, a1, 29, 10, gold), 0, 0)
        f.ellipse(32, 32, 3, 3, "yellow")
        frames.append(f)
    f = crescent(s, -180, 180, 29, 8, gold, uniform=True)
    frames.append(f)
    # 4: ring fades into sparkles
    f = crescent(s, -180, 180, 30, 3, ["yellow", "gold_l"])
    for k in range(12):
        ang = 2 * math.pi * k / 12 + 0.2
        x = int(32 + math.cos(ang) * 24)
        y = int(32 + math.sin(ang) * 24)
        f.set(x, y, "white")
        f.set(x + 1, y, "yellow")
        f.set(x - 1, y, "yellow")
        f.set(x, y + 1, "yellow")
        f.set(x, y - 1, "yellow")
    frames.append(f)
    return [Anim("default", frames, 14.0, False, [1.5, 1.0, 1.0, 1.5, 2.0])]


STAR5 = ["..Y..", ".YwY.", "..Y.."]


def dizzy_stars() -> list[Anim]:
    frames = []
    for i in range(4):
        c = Canvas(16, 10)
        pts = []
        for k in range(3):
            ang = 2 * math.pi * (k / 3 + i / 12)
            x = 8 + math.cos(ang) * 6
            y = 5 + math.sin(ang) * 2.5
            pts.append((math.sin(ang), int(round(x)) - 2, int(round(y)) - 1))
        for depth, x, y in sorted(pts):
            col = "yellow" if depth > -0.2 else "gold_l"
            c.stamp(STAR5, x, y, {"Y": col, "w": "white" if depth > -0.2 else "yellow"}, outline=None)
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


def dust() -> list[Anim]:
    f0 = Canvas(8, 8)
    f0.ellipse(4, 5, 2, 1.6, "white")
    f1 = Canvas(8, 8)
    f1.ellipse(3, 5, 2.4, 2, "stone_l")
    f1.ellipse(5.5, 4.5, 2, 1.8, "white")
    f2 = Canvas(8, 8)
    f2.ellipse(2.5, 4.5, 2, 1.8, "stone_l@170")
    f2.ellipse(6, 3.5, 1.6, 1.5, "stone_l@140")
    return [Anim("default", [f0, f1, f2], 12.0, False)]


# --------------------------------------------------------------------------
# v2.2 (CP3): richer versions with more frames, white-hot cores and dithered fades
# --------------------------------------------------------------------------

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def _bayer(x: int, y: int) -> float:
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def smear(size: int, a0: float, a1: float, r_out: float, thick: float, colors: list[str], tail: float = 0.4,
          fade: float = 0.0, head_round: bool = True) -> Canvas:
    """Sword-trail arc from a0 to a1 (degrees): thickest near the head (a1), dithered tail, optional overall fade."""
    c = Canvas(size, size)
    cx = cy = size / 2
    for y in range(size):
        for x in range(size):
            r, a = _polar(cx, cy, x, y)
            if a1 > 180 and a < a0:
                a += 360
            if not (a0 <= a <= a1):
                continue
            t = (a - a0) / max(1e-6, a1 - a0)
            k = min(1.0, t / 0.85) if head_round else t
            w = thick * (0.2 + 0.8 * math.sin(math.pi * 0.5 * k) ** 0.8)
            if head_round and t > 0.85:
                w *= math.sqrt(max(0.0, 1 - ((t - 0.85) / 0.15) ** 2))
            if not (r_out - w <= r <= r_out):
                continue
            if t < tail and _bayer(x, y) > (t / tail) ** 1.4:
                continue
            if fade > 0 and _bayer(x, y) < fade:
                continue
            depth = (r_out - r) / max(1e-6, w)
            idx = min(len(colors) - 1, int(depth * len(colors)))
            c.set(x, y, colors[idx])
    return c


def _plus(c: Canvas, x: int, y: int, core: str = "white", arm: str = "yellow", r: int = 1) -> None:
    c.set(x, y, core)
    for d in range(1, r + 1):
        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
            c.set(x + dx, y + dy, arm)


def slash_v2() -> list[Anim]:
    s = 32
    f0 = smear(s, -85, -25, 14, 3, ["white", "sky_l"], tail=0.5)
    f1 = smear(s, -85, 70, 14, 7, ["white", "white", "sky_l", "sky"], tail=0.45)
    f2 = smear(s, -40, 85, 14, 5, ["sky_l", "white", "sky_l", "sky"], tail=0.6, fade=0.25)
    for (x, y) in ((27, 23), (24, 28)):
        _plus(f2, x, y, "white", "sky_l")
    f3 = smear(s, 0, 88, 14, 3, ["sky_l", "sky"], tail=0.7, fade=0.6)
    for (x, y) in ((28, 20), (22, 29), (29, 26)):
        f3.set(x, y, "white")
    return [Anim("default", [f0, f1, f2, f3], 22.0, False, [0.8, 1.2, 1.0, 1.0])]


def hit_spark_v2() -> list[Anim]:
    s = 16
    f0 = Canvas(s, s)
    f0.ellipse(8, 8, 3.2, 3.2, "yellow")
    f0.ellipse(8, 8, 2.2, 2.2, "white")
    f1 = Canvas(s, s)
    for k in range(8):
        ang = math.pi * k / 4
        ln = 7 if k % 2 == 0 else 4
        for d in range(1, ln + 1):
            f1.set(int(round(8 + math.cos(ang) * d - 0.5)), int(round(8 + math.sin(ang) * d - 0.5)),
                   "white" if d < ln * 0.5 else "yellow")
    f1.ellipse(8, 8, 1.6, 1.6, "white")
    f2 = Canvas(s, s)
    for k in range(8):
        ang = math.pi * k / 4 + 0.2
        ln = 7 if k % 2 == 0 else 5
        for d in range(ln - 2, ln + 1):
            f2.set(int(round(8 + math.cos(ang) * d - 0.5)), int(round(8 + math.sin(ang) * d - 0.5)),
                   "yellow" if d < ln else "orange")
    f3 = Canvas(s, s)
    for (x, y) in ((1, 7), (14, 8), (8, 1), (7, 14), (3, 3), (12, 12)):
        f3.set(x, y, "orange" if (x + y) % 3 else "yellow")
    return [Anim("default", [f0, f1, f2, f3], 20.0, False, [0.8, 1.0, 1.0, 1.0])]


def exp_orb_v2() -> list[Anim]:
    """12x12: a glowing blue orb with a soft halo, a twinkle that circles it and a short trail."""
    frames = []
    orbit = [(9, 2), (10, 6), (8, 9), (3, 9), (1, 5), (3, 2)]
    for i in range(6):
        c = Canvas(12, 12)
        bob = [0, 0, 1, 1, 1, 0][i]
        cx, cy = 6, 5 + bob
        c.ellipse(cx, cy, 5, 5, "sky_l@70")
        c.ellipse(cx, cy, 4, 4, "sky_l@110")
        c.set(cx - 1, cy + 4, "sky@120")
        c.set(cx, cy + 5, "sky@80")
        c.set(cx, cy + 4, "sky_l@140")
        orb = Canvas(12, 12)
        orb.ellipse(cx, cy, 3, 3, "sky")
        orb.ellipse(cx - 0.4, cy - 0.4, 2, 2, "sky_l")
        orb.set(cx - 2, cy - 2, "white")
        orb.set(cx - 1, cy - 2, "white")
        orb.set(cx - 2, cy - 1, "white")
        orb.set(cx + 1, cy + 1, "water")
        orb.set(cx + 2, cy, "water")
        orb.outline_all("water_d")
        c.blit(orb, 0, 0)
        ox, oy = orbit[i]
        c.set(ox, oy + bob, "white")
        frames.append(c)
    return [Anim("default", frames, 9.0, True)]


def ultimate_slash_v2() -> list[Anim]:
    s = 64
    gold = ["white", "yellow", "gold_l", "orange"]
    frames = []
    f = Canvas(s, s)
    for k in range(8):
        ang = math.pi * k / 4
        for d in range(5, 13 if k % 2 == 0 else 9):
            f.set(int(32 + math.cos(ang) * d), int(32 + math.sin(ang) * d), "white" if d < 9 else "yellow")
    f.ellipse(32, 32, 6, 6, "yellow")
    f.ellipse(32, 32, 4, 4, "white")
    frames.append(f)
    f = smear(s, -180, -20, 29, 10, gold, tail=0.35)
    f.ellipse(32, 32, 3, 3, "yellow")
    frames.append(f)
    f = smear(s, -180, 130, 29, 11, gold, tail=0.25)
    frames.append(f)
    f = crescent(s, -180, 180, 29, 9, gold, uniform=True)
    for k in range(12):
        ang = 2 * math.pi * k / 12
        for d in range(30, 34 if k % 2 else 36):
            f.set(int(32 + math.cos(ang) * d), int(32 + math.sin(ang) * d), "yellow" if d < 33 else "gold_l")
    frames.append(f)
    f = crescent(s, -180, 180, 31, 5, ["white", "yellow", "gold_l"], uniform=True)
    for y in range(s):
        for x in range(s):
            if f.opaque(x, y) and _bayer(x, y) < 0.35:
                f.set(x, y, None)
    frames.append(f)
    f = Canvas(s, s)
    for k in range(12):
        ang = 2 * math.pi * k / 12 + 0.2
        _plus(f, int(32 + math.cos(ang) * 28), int(32 + math.sin(ang) * 28), "white", "yellow")
    frames.append(f)
    return [Anim("default", frames, 16.0, False, [1.5, 1.0, 1.0, 1.5, 1.5, 2.0])]


def dizzy_stars_v2() -> list[Anim]:
    frames = []
    for i in range(6):
        c = Canvas(16, 10)
        pts = []
        for k in range(3):
            ang = 2 * math.pi * (k / 3 + i / 18)
            x = 8 + math.cos(ang) * 6
            y = 5 + math.sin(ang) * 2.5
            pts.append((math.sin(ang), int(round(x)) - 2, int(round(y)) - 1))
        for depth, x, y in sorted(pts):
            col = "yellow" if depth > -0.2 else "gold_l"
            c.stamp(STAR5, x, y, {"Y": col, "w": "white" if depth > -0.2 else "yellow"}, outline=None)
        frames.append(c)
    return [Anim("default", frames, 12.0, True)]


def dust_v2() -> list[Anim]:
    f0 = Canvas(8, 8)
    f0.ellipse(4, 5.5, 2.2, 1.6, "white")
    f1 = Canvas(8, 8)
    f1.ellipse(2.8, 5, 2.4, 2, "stone_l")
    f1.ellipse(5.4, 4.6, 2.2, 1.9, "white")
    f1.set(4, 3, "white")
    f2 = Canvas(8, 8)
    f2.ellipse(2.4, 4.4, 2.2, 1.8, "stone_l@200")
    f2.ellipse(6, 3.5, 1.8, 1.6, "white@200")
    f3 = Canvas(8, 8)
    for (x, y) in ((1, 4), (3, 3), (6, 2), (2, 5)):
        f3.set(x, y, "stone_l@150")
    return [Anim("default", [f0, f1, f2, f3], 14.0, False)]


ALL = {
    "slash": (slash_v2, (32, 32)),
    "hit_spark": (hit_spark_v2, (16, 16)),
    "exp_orb": (exp_orb_v2, (12, 12)),
    "ultimate_slash": (ultimate_slash_v2, (64, 64)),
    "dizzy_stars": (dizzy_stars_v2, (16, 10)),
    "dust": (dust_v2, (8, 8)),
}

assert rgba("white")
