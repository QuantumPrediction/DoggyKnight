"""v2.6 (CW2): the twelve chapter 2-3 backgrounds. Python 3 standard library only.

Chapter 2 (圓桌騎士) is warm stone: Camelot in the morning, at noon, by candlelight, at sunset,
in the golden afternoon garden and the overcast green chapel. Chapter 3 (湖中仙女) is cool moonlight
and mist: the lake before dawn, the fairy forest at night, the stone circle under the full moon, the
crystal cave, Morgana's tower and its stormy top.

Every scene is a 304x512 palette image + a foreground layer + animated props, particles and light
sprites (see art_v26_kit). The arena (image 64..240 x 160..384) is always a calm, mid-toned floor.

    python3 tools/pixel/art_v26_world.py [names...] [--preview DIR]
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
import paint as P  # noqa: E402
from art_world import AX0, AX1, AY0, AY1, IMG_H, IMG_W, fbm, hash01, in_arena, name_at, shade  # noqa: E402
from art_v26_kit import Scene26, dk, lt  # noqa: E402
from pixel import Canvas, line_points  # noqa: E402

MIDX = (AX0 + AX1) // 2


def sleeping_dog(seed: int, fur=("gold_d", "gold", "gold_l"), outline: str = "brown_d") -> Canvas:
    """A dog curled up asleep (the 百年午睡咒): a round body, a floppy ear, the tail curled over the
    nose, closed eye (22x14)."""
    c = Canvas(22, 14)
    body = P.ellipse(12, 8.5, 8.5, 5) | P.ellipse(6, 7, 5, 4.2)
    for (x, y) in body:
        u = (x - 2) / 18 + (y - 3) / 22
        c.set(x, y, fur[2] if u < 0.32 else (fur[1] if u < 0.72 else fur[0]))
    for (x, y) in P.ellipse(8, 5, 2.2, 3):
        c.set(x, y, fur[0])
    for x in range(9, 20):
        c.set(x, 11 - int(abs(x - 15) * 0.35), fur[0])
    c.set(2, 8, "umber")
    c.set(3, 8, "umber")
    c.set(4, 6, "umber")
    c.set(5, 6, "umber")
    c.set(3, 9, "pink")
    c.outline_all(outline)
    return c


def _zzz_anim():
    from pixel import Anim
    frames = []
    for f in range(4):
        c = Canvas(9, 12)
        for k in range(3):
            t = (f + k * 4 / 3) % 4 / 4
            y = int(10 - t * 9)
            x = int(1 + k * 2 + t * 2)
            col = "white" if t < 0.6 else "fog"
            if t < 0.9:
                for (dx, dy) in ((0, 0), (1, 0), (1, 1), (0, 2), (1, 2)):
                    c.set(x + dx, y + dy - 2, col)
        frames.append(c)
    return [Anim("default", frames, 2.5, True)]


K.ANIMS["zzz"] = (_zzz_anim, (9, 12))


def house_row(img: Canvas, base: int, x0: int, x1: int, seed: int, walls, roofs, heights=(18, 26), widths=(22, 34),
              thorns: float = 0.4, lit: float = 0.5, timber: float = 0.5, outline: str = "umber",
              gables: float = 0.0) -> list[tuple[int, int, int]]:
    """A row of town houses whose wall feet sit on y=base (gables: share of tall gable-front houses).
    Returns (x, top_y, w) per house."""
    rng = random.Random(seed)
    x = x0
    out = []
    while x < x1:
        if rng.random() < gables:
            w = rng.randrange(widths[0] + 2, widths[1] + 2)
            h = K.gable_house(w, rng.randrange(heights[0] + 4, heights[1] + 6), seed + x, wall=rng.choice(walls),
                              roof_ramp=rng.choice(roofs), timber=("brown" if rng.random() < timber else None),
                              lit=rng.random() < lit, outline=outline, thorns=rng.random() < thorns,
                              chimney=rng.random() < 0.5)
            img.blit(h, x - 3, base - h.h + 1)
        else:
            w = rng.randrange(*widths)
            wall_h = rng.randrange(*heights)
            roof_h = rng.randrange(8, 13)
            h = K.house(w, wall_h, roof_h, seed + x, wall=rng.choice(walls), roof_ramp=rng.choice(roofs),
                        roof_outline=outline, timber=("brown" if rng.random() < timber else None),
                        lit_windows=1 if rng.random() < lit else 0, thorns=rng.random() < thorns, outline=outline)
            img.blit(h, x - 2, base - h.h)
        out.append((x, base - h.h, w))
        x += w + rng.randrange(-1, 2)
    return out


def rune_ring(img: Canvas, cx: float, cy: float, r: float, col: str, tick: str, ticks: int = 24,
              squash: float = 1.15, width: float = 1.4, mask=None) -> None:
    """A faint inlaid ring (two thin circles with short marks between them) on a floor."""
    for y in range(int(cy - r / squash) - 3, int(cy + r / squash) + 4):
        for x in range(int(cx - r) - 3, int(cx + r) + 4):
            if mask is not None and not mask(x, y):
                continue
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * squash)
            if r - width <= d < r or r - 8 - width <= d < r - 8:
                img.set(x, y, col)
            elif r - 7 <= d < r - 1:
                a = (math.atan2(y - cy, x - cx) + math.pi) / (2 * math.pi) * ticks
                if 0.4 < a - int(a) < 0.6:
                    img.set(x, y, tick)


CALM_GROUND = {"max_light": 0.05, "max_dark": 0.05}


def calm_ground(img: Canvas, ramp: tuple[str, str, str], seed: int, rect=(AX0, AY0, AX1, AY1), tufts: float = 0.15) -> None:
    """The arena floor for grass scenes: almost one tone, a few big soft patches, sparse tufts."""
    AW.paint_ground(img, rect, ramp, seed, scale=44, tufts=tufts, lo=0.3, hi=0.7, **CALM_GROUND)


def giant_tree(w: int, h: int, seed: int, bark=("navy", "deep", "teal", "grass"), outline: str = "ink",
               roots: bool = True) -> Canvas:
    """A huge old trunk: bark bands whose edges wander (no straight stripes), knots, a root flare."""
    c = Canvas(w + 24, h)
    cx = (w + 24) / 2
    for y in range(h):
        flare = (max(0, y - h + 22) / 22) ** 2 * 12 if roots else 0
        half = w / 2 + flare
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x + 0.5 - (cx - half)) / (2 * half) + (fbm(x * 2, y * 0.35, seed, 6, 2) - 0.5) * 0.28
            col = bark[3] if u < 0.14 else (bark[2] if u < 0.4 else (bark[1] if u < 0.78 else bark[0]))
            c.set(x, y, col)
    rng = random.Random(seed)
    for _ in range(3):
        kx, ky = int(cx + rng.uniform(-w / 4, w / 4)), rng.randrange(10, h - 30)
        for (x, y) in P.ellipse(kx, ky, 2.5, 3.5):
            c.set(x, y, bark[0])
        c.set(kx - 1, ky - 2, bark[2])
    c.outline_all(outline)
    return c


def tower_crown(r: int, ramp=("stone_d", "stone", "stone_l"), floor="stone", outline: str = "slate") -> Canvas:
    """A round tower top seen from above at 3/4: a ring of merlons round a paved disc."""
    c = Canvas(r * 2 + 4, int(r * 1.6) + 10)
    cx, cy = r + 2, r * 0.8 + 6
    for y in range(c.h):
        for x in range(c.w):
            d = math.hypot((x + 0.5 - cx) / r, (y + 0.5 - cy) / (r * 0.8))
            if d < 1:
                c.set(x, y, ramp[1] if d > 0.78 else (floor if (x + y // 4) % 9 else K.dk(floor)))
    for k in range(14):
        a = k / 14 * 2 * math.pi
        mx, my = cx + math.cos(a) * (r - 2), cy + math.sin(a) * (r * 0.8 - 2)
        for yy in range(int(my) - 4, int(my) + 1):
            for xx in range(int(mx) - 2, int(mx) + 2):
                c.set(xx, yy, ramp[2] if yy == int(my) - 4 else (ramp[1] if xx < mx else ramp[0]))
    for y in range(c.h):
        for x in range(c.w):
            d = math.hypot((x + 0.5 - cx) / r, (y + 0.5 - cy) / (r * 0.8))
            if 1 <= d < 1.0 + 6 / r and y > cy:
                c.set(x, y, ramp[0] if x > cx else ramp[1])
    c.outline_all(outline)
    return c


def frame_arena(img: Canvas, seed: int, ramp: tuple[str, str, str, str], outline: str, rocks: bool = False) -> None:
    """Low bushes (or rocks) along the arena's left and right edges, just outside it, so a calm
    floor reads as a clearing rather than a pasted rectangle; a one-step shade inside the edge."""
    rng = random.Random(seed)
    for x0 in (AX0 - 12, AX1 - 2):
        y = AY0 - 4
        while y < AY1:
            if rocks and rng.random() < 0.4:
                r = AW.rock(seed + y, 10, 7, ("navy", "slate", "ash", "fog"), "ink", "teal")
            else:
                w = rng.randrange(12, 16)
                r = AW.bush(seed + y + x0, w, rng.randrange(8, 11), ramp, outline)
            img.blit(r, x0 + rng.randrange(-1, 2), y)
            y += rng.randrange(9, 15)
    K.calm_vignette(img, 8)


def steps(img: Canvas, x0: int, x1: int, y: int, n: int, ramp: tuple[str, str, str], depth: int = 4) -> None:
    """Stairs going down towards the viewer: each step a lit tread and a shaded riser."""
    for k in range(n):
        yy = y + k * depth
        for x in range(x0 - k * 3, x1 + k * 3):
            img.set(x, yy, ramp[2])
            for d in range(1, depth - 1):
                img.set(x, yy + d, ramp[1])
            img.set(x, yy + depth - 1, ramp[0])


def topiary(seed: int, kind: str = "ball", ramp=("forest", "leaf_d", "leaf", "leaf_l"), outline="forest_d") -> Canvas:
    """A clipped shrub in a stone pot: ball, cone or double ball."""
    c = Canvas(16, 30)
    if kind == "cone":
        blobs = [(8, 16, 6), (8, 11, 5), (8, 7, 3.6), (8, 4, 2.4)]
    elif kind == "double":
        blobs = [(8, 17, 6), (8, 7, 4.5)]
    else:
        blobs = [(8, 12, 7)]
    leaf = AW.blob_canvas(16, 24, blobs, list(ramp), outline, seed, texture=0.18)
    c.blit(leaf, 0, 0)
    for y in range(22, 29):
        for x in range(4, 12):
            c.set(x, y, "stone_l" if x < 6 else ("stone" if x < 10 else "stone_d"))
    c.hline(3, 12, 22, "stone_l")
    c.outline_all("iron")
    return c


def yew(seed: int, h: int = 46, ramp=("deep", "forest_d", "forest", "leaf_d"), outline="navy") -> Canvas:
    """A tall dark yew / cypress (column of blobs)."""
    rng = random.Random(seed)
    blobs = []
    for k in range(7):
        t = k / 6
        blobs.append((9 + rng.uniform(-1, 1), h - 8 - t * (h - 14), 7.5 - t * 3.5))
    c = Canvas(18, h)
    c.rect(8, h - 6, 3, 6, "brown_d")
    c.blit(AW.blob_canvas(18, h - 3, blobs, list(ramp), outline, seed, texture=0.2), 0, 0)
    return c


def rocky(img: Canvas, rect: tuple[int, int, int, int], ramp: tuple[str, str, str], seed: int, mask=None,
          scale: float = 14.0) -> None:
    """Cave rock: clustered facets in three tones, lit top-left edges on the light tone."""
    AW.paint_ground(img, rect, ramp, seed, scale=scale, lo=0.4, hi=0.6, tufts=0.0, mask=mask,
                    max_light=0.22, max_dark=0.3)


def water_bands(img: Canvas, rect: tuple[int, int, int, int], bands: list[tuple[str, float]], seed: int,
                glints: tuple[str, ...] = ("sky_l",), n_glints: int = 40, mask=None) -> None:
    """Calm lake water: horizontal colour bands (wavy edges) and short horizontal glint lines."""
    x0, y0, x1, y1 = rect
    span = max(1, y1 - y0)
    for y in range(y0, y1):
        for x in range(x0, x1):
            if mask is not None and not mask(x, y):
                continue
            t = (y - y0 + 1.4 * math.sin(x / 9.0 + y * 0.3 + seed)) / span
            col = bands[0][0]
            for n, t0 in bands:
                if t >= t0:
                    col = n
            img.set(x, y, col)
    rng = random.Random(seed)
    for _ in range(n_glints):
        x, y = rng.randrange(x0, x1 - 6), rng.randrange(y0, y1)
        if mask is not None and not mask(x, y):
            continue
        ln = rng.randrange(2, 7)
        for k in range(ln):
            img.set(x + k, y, rng.choice(glints))


def cloud_bank(img: Canvas, y: int, cols: tuple[str, str, str], seed: int, x0: int = -10, x1: int = IMG_W + 10,
               size=(6.0, 11.0), step: int = 10, flat: bool = True) -> None:
    """A row of puffy clouds (lit tops) whose flat bottoms sit on y."""
    rng = random.Random(seed)
    x = x0
    while x < x1:
        r = rng.uniform(*size)
        blob = AW.blob_canvas(int(r * 2 + 4), int(r * 2 + 4), [(r + 2, r + 2, r), (r * 0.6 + 2, r * 1.3 + 2, r * 0.7),
                                                               (r * 1.5 + 2, r * 1.3 + 2, r * 0.7)],
                              [cols[0], cols[1], cols[1], cols[2]], None, seed + x, light=(-0.3, -1.0, 0.6),
                              texture=0.0)
        img.blit(blob, int(x - r), y - int(r * 2))
        if flat:
            for xx in range(int(x - r), int(x + r + 4)):
                for yy in range(y - 2, y + 2):
                    if 0 <= xx < img.w:
                        img.set(xx, yy, cols[0])
        x += step + rng.randrange(0, step)


# ==========================================================================
# Chapter 2: warm stone
# ==========================================================================

def scene_castle_town() -> Scene26:
    """2-1 城下町: a bright, sleepy morning in Camelot's market square. Purple thorns creep up the
    walls, dogs sleep where they fell, flags and laundry stir in the breeze; the castle rises far behind."""
    sc = Scene26("sand", 0.38)
    img = sc.img
    # far: morning sky, hazy castle, far roofs
    K.sky_bands(img, 0, 96, [("sky", 0.0), ("azure", 0.3), ("sky_l", 0.55), ("haze", 0.8)], seed=1)
    for (cx, w, h) in ((152, 22, 58), (126, 12, 44), (180, 12, 46), (104, 9, 32), (204, 9, 34)):
        t = K.round_tower(w, h, ("ash", "fog", "fog", "haze"), cx, cone=("ash", "fog", "haze"), cone_h=w,
                          outline="ash", windows=1, lit=False)
        img.blit(t, cx - t.w // 2, 92 - t.h)
    far_wall = K.masonry(120, 18, ("ash", "fog", "haze"), 2100, course=5, mortar="ash", base_dark=0)
    img.blit(far_wall, 94, 74)
    img.blit(K.crenels(120, 5, 4, 4, ("ash", "fog", "haze"), "ash"), 94, 69)
    sc.anim("pennant_red", 152, 92 - 58 - 22 - 10, 0, 1.0)
    sc.anim("pennant_gold", 126, 92 - 44 - 12 - 10, 1, 0.9)
    sc.anim("pennant_red", 180, 92 - 46 - 12 - 10, 2, 1.1)
    # mid-far roofs (hazy, rose roofs, fog walls)
    house_row(img, 112, -8, IMG_W + 8, 21, walls=[("ash", "fog", "haze")], roofs=[("dusk", "rose", "peach")],
              heights=(8, 12), widths=(18, 28), thorns=0.0, lit=0.0, timber=0.0, outline="ash")
    # mid: the street's house fronts (full colour) with flags and thorns
    walls = [("stone", "stone_l", "white"), ("dirt", "sand", "cream"), ("gold_d", "dirt", "sand")]
    roofs = [("red_d", "red", "coral"), ("wine", "red_d", "red"), ("brown_d", "brown", "gold_d")]
    houses = house_row(img, AY0 - 4, -6, IMG_W + 6, 22, walls, roofs, heights=(22, 30), widths=(24, 34), gables=0.6)
    for i, (hx, top, w) in enumerate(houses):
        if i % 2 == 0 and 0 < hx < IMG_W - 20:
            sc.anim("flag_camelot" if i % 4 == 0 else "flag_blue", hx + w // 2 - 5, top + 14, i % 4, 0.9 + (i % 3) * 0.1)
    # street: warm cobbles everywhere, a calm flagstone square in the arena
    def street(x: int, y: int) -> bool:
        return y >= AY0 - 4 and not in_arena(x, y)
    K.cobbles(img, (0, AY0 - 4, IMG_W, IMG_H), ("gold_d", "gold_d", "dirt"), "brown", 2101, mask=street)
    K.flagstones(img, (AX0, AY0, AX1, AY1), ("dirt", "dirt"), "gold_d", 2102, worn="sand", worn_rate=0.08,
                 crack_rate=0.05)
    rune_ring(img, MIDX, (AY0 + AY1) // 2 + 6, 58, "gold_d", "gold_d", ticks=16)
    # a kerb of darker stones round the square
    for x in range(AX0 - 3, AX1 + 3):
        for y in (AY0 - 3, AY0 - 2, AY1, AY1 + 1):
            img.set(x, y, "brown" if y in (AY0 - 2, AY1 + 1) else "gold_d")
    for y in range(AY0 - 3, AY1 + 2):
        for x in (AX0 - 3, AX0 - 2, AX1, AX1 + 1):
            img.set(x, y, "brown" if x in (AX0 - 2, AX1 + 1) else "gold_d")
    K.edge_shadow(img, AY0, 7)
    # thorns from the house fronts into the street
    for k, x in enumerate(range(8, IMG_W, 37)):
        K.thorn_vine(img, x, AY0 - 6, 14, 2110 + k, up=False)
    # side streets: stalls, barrels, sleeping dogs
    for (x, y, cols, s) in ((4, 196, ("red", "cream"), 1), (246, 240, ("water", "white"), 2), (6, 300, ("leaf_d", "cream"), 3)):
        st = K.awning_stall(40 if x < 100 else 50, cols, s)
        AW.place(img, st, x, y, shadow=(1.0, 0), shadow_dx=6)
    for (x, y) in ((50, 236), (244, 206), (250, 330), (40, 350), (230, 300)):
        AW.place(img, K.barrel(x), x, y, shadow=(0.9, 0), shadow_dx=3)
    furs = [("gold_d", "gold", "gold_l"), ("stone", "stone_l", "white"), ("brown", "gold_d", "dirt")]
    dogs = [(20, 268), (256, 278), (30, 410), (238, 416), (110, 446)]
    for i, (x, y) in enumerate(dogs):
        AW.place(img, sleeping_dog(i, furs[i % 3]), x, y, shadow=(1.0, -1), shadow_dx=1)
        sc.anim("zzz", x + 4, y - 11, i % 4, 0.8 + (i % 3) * 0.15)
    # bottom: more house fronts seen from above (roofs), flower boxes
    K.edge_shadow(img, AY1 + 2, 3)
    roofs_b = Canvas(IMG_W, 60)
    house_row(roofs_b, 60, -8, IMG_W + 8, 23, walls, roofs, heights=(10, 16), widths=(26, 40), thorns=0.5)
    img.blit(roofs_b, 0, IMG_H - 52)
    # foreground: near eaves in the top corners, a lantern post and flower pots at the bottom
    for side in (0, 1):
        eave = K.roof(46, 16, ("brown_d", "brown", "gold_d"), "umber", 2130 + side)
        sc.put_fg(eave.flipped() if side else eave, -6 if side == 0 else IMG_W - 46, 82)
    for k, x in enumerate((-4, 40, 214, 262)):
        pot = Canvas(30, 26)
        pot.rect(4, 14, 22, 11, "red_d")
        pot.rect(4, 14, 22, 2, "coral")
        blob = AW.blob_canvas(30, 18, [(9, 10, 6), (17, 8, 7), (24, 11, 5)], ["forest", "leaf_d", "leaf", "leaf_l"],
                              "forest_d", 2140 + k)
        pot.blit(blob, 0, 0)
        for (fx, fy) in ((8, 6), (16, 4), (22, 8)):
            for dx, dy, cc in AW.flower(("pink", "white", "yellow")[k % 3]):
                pot.set(fx + dx, fy + dy, cc)
        pot.outline_all("umber")
        sc.put_fg(pot, x, 404 + (k % 2) * 4)
    sc.light("sun", 20, 10, 1.0)
    sc.particle(kind="smoke", amount=8, lifetime=5.0, rect=(-40, -70, 220, -20), velocity=(0.3, -1), spread=15,
                speed=(3, 6), gravity=(0, 0), colour_fade=True)
    sc.particle(kind="mote", amount=10, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -4), spread=180,
                speed=(2, 5), gravity=(0, 0), colour_fade=True)
    sc.particle(kind="petal_violet", amount=5, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.6),
                spread=20, speed=(6, 10), gravity=(0, 2), colour_fade=True, spin=True)
    sc.modulate = (1.0, 0.98, 0.94)
    return sc


def scene_castle_courtyard() -> Scene26:
    """2-2 城堡中庭: high noon in the keep's courtyard. A warm stone keep with a great door, red-roofed
    towers and banners; clipped topiaries, statues and a fountain round a sunny paved court."""
    sc = Scene26("stone", 0.38)
    img = sc.img
    K.sky_bands(img, 0, 60, [("sky", 0.0), ("azure", 0.45), ("sky_l", 0.8)], seed=3)
    # far: the inner keep's upper towers (hazy)
    for (cx, w, h, cone) in ((60, 14, 70, 14), (246, 14, 74, 14), (152, 20, 86, 20)):
        t = K.round_tower(w, h, ("ash", "fog", "fog", "haze"), cx, cone=("rose", "peach", "cream"), cone_h=cone,
                          outline="ash", windows=1, lit=False)
        img.blit(t, cx - t.w // 2, 64 - t.h + 26)
    sc.anim("pennant_red", 152, 64 + 26 - 86 - 20 - 11, 0, 1.0)
    # mid: the keep facade
    wall = K.masonry(IMG_W, 74, ("stone", "stone_l", "white"), 2201, course=7, brick=(10, 18), mortar="stone_d",
                     base_dark=8)
    img.blit(wall, 0, 66)
    img.blit(K.crenels(IMG_W, 8, 5, 7, ("stone", "stone_l", "white"), "stone_d"), 0, 58)
    for x in range(IMG_W):
        img.set(x, 66, "stone_d")
    # great door
    dx0, dw = MIDX - 22, 44
    for y in range(78, 140):
        for x in range(dx0 - 4, dx0 + dw + 4):
            dxn = (x + 0.5 - MIDX) / (dw / 2 + 4)
            top = 78 + (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * 22
            if y >= top:
                img.set(x, y, "stone_d" if abs(x + 0.5 - MIDX) > dw / 2 else ("brown" if x < MIDX else "brown_d"))
    for x in range(dx0, dx0 + dw, 6):
        img.vline(x, 96, 139, "umber")
    for y in (104, 124):
        img.hline(dx0, dx0 + dw - 1, y, "iron")
    img.vline(MIDX, 84, 139, "umber")
    for x in (MIDX - 4, MIDX + 3):
        img.set(x, 114, "gold_l")
    # flanking towers on the facade
    for side, tx in ((0, 34), (1, 236)):
        t = K.round_tower(30, 82, ("stone_d", "stone", "stone_l", "white"), 2210 + side, cone=("red_d", "red", "coral"),
                          cone_h=26, outline="umber", windows=2)
        img.blit(t, tx - t.w // 2, 142 - t.h)
        sc.anim("pennant_red" if side else "pennant_gold", tx, 142 - t.h - 10, side, 1.0)
    for i, x in enumerate((74, 100, 190, 216)):
        win = K.arch_window(8, 14, lit=False, frame=("stone_d", "stone_l"), dark="night")
        img.blit(win, x, 84)
        sc.anim("flag_camelot", x - 2, 104, i % 4, 0.9 + i * 0.07)
    # near: steps down into the court, statues and topiaries either side
    steps(img, MIDX - 34, MIDX + 34, 140, 4, ("stone_d", "stone", "stone_l"), depth=5)
    for x in range(0, IMG_W):
        for y in range(140, AY0):
            if name_at(img, x, y) is None or abs(x - MIDX) > 34 + (y - 140) // 5 * 3:
                img.set(x, y, "stone_d" if y < 146 else "stone")
    # the court: calm warm paving with a sun-bleached ring
    K.flagstones(img, (0, AY0 - 4, IMG_W, IMG_H), ("stone", "stone"), "stone_d", 2202, lip="stone_l",
                 mask=lambda x, y: not (abs(x - MIDX) < 34 + 12 and y < 160))
    rune_ring(img, MIDX, (AY0 + AY1) // 2 + 4, 62, "stone_d", "dirt", ticks=12)
    K.edge_shadow(img, AY0 - 4, 9)
    for x in (MIDX - 120, MIDX + 104):
        AW.place(img, K.statue(x), x, 150, shadow=(1.0, -1), shadow_dx=5)
    for (x, y, kind) in ((44, 186, "cone"), (246, 186, "cone"), (44, 262, "ball"), (246, 262, "ball"),
                         (44, 338, "double"), (246, 338, "double")):
        AW.place(img, topiary(x + y, kind), x - 4, y, shadow=(0.9, -1), shadow_dx=5)
    # bottom: fountain with a stone basin, flower beds
    fx, fy = MIDX, 440
    for y in range(fy - 20, fy + 20):
        for x in range(fx - 40, fx + 40):
            d = math.hypot((x + 0.5 - fx) / 38, (y + 0.5 - fy) / 18)
            if d < 1:
                img.set(x, y, "stone_l" if d > 0.86 else ("water" if d > 0.7 else ("sky" if (y - fy) < -2 else "water")))
                if 0.86 < d < 0.92 and y > fy:
                    img.set(x, y, "stone")
    for x in range(fx - 40, fx + 40):
        for y in range(fy + 10, fy + 24):
            if name_at(img, x, y) in ("stone", "stone_d", "stone_l") and \
                    math.hypot((x + 0.5 - fx) / 38, (y + 0.5 - fy) / 18) > 1 and y < fy + 22:
                pass
    sc.anim("fountain", fx - 8, fy - 14, 0, 1.0)
    for k in range(6):
        sc.anim("water_glint", fx - 30 + k * 11, fy - 4 + (k % 2) * 6, k, 0.8)
    for side in (0, 1):
        bx = 6 if side == 0 else IMG_W - 66
        bed = AW.hedge_strip(60, 2220 + side, flowers=["red", "pink", "white", "yellow"], flower_every=3, h=16)
        img.blit(bed, bx, 410)
    # foreground: rose bushes in the bottom corners, a hanging banner edge top left/right
    AL.clumps(sc.fg, 2230, ("forest_d", "forest", "leaf_d", "leaf"), "forest_d", flowers=["red", "pink", "white"],
              gap=(40, 70))
    sc.light("sun", 30, 20, 1.1)
    sc.particle(kind="petal", amount=8, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.6), spread=20,
                speed=(8, 12), gravity=(0, 2), colour_fade=True, spin=True)
    sc.particle(kind="mote", amount=8, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -4), spread=180,
                speed=(2, 4), gravity=(0, 0), colour_fade=True)
    sc.modulate = (1.0, 0.985, 0.95)
    return sc


def scene_royal_library() -> Scene26:
    """2-3 王家書庫: the royal library by candlelight. Two storeys of shelves, a gallery rail, a tall
    moonlit window; spellbooks float and flap above the shelves, candles flicker along the reading desks."""
    sc = Scene26("brown_d", 0.5)
    img = sc.img
    # far: the upper gallery (darker, smaller shelves) under the ceiling beams
    img.rect(0, 0, IMG_W, 60, "umber")
    for x in range(-4, IMG_W, 26):
        sh = K.bookshelf(24, 44, 2300 + x, wood=("ink", "umber", "brown_d"))
        img.blit(sh, x, 12)
    for x in range(0, IMG_W, 38):
        img.rect(x, 0, 6, 12, "brown_d")
        img.vline(x, 0, 11, "brown")
    img.rect(0, 0, IMG_W, 4, "ink")
    # gallery rail
    for x in range(IMG_W):
        img.set(x, 56, "gold_d")
        img.set(x, 57, "brown")
        img.set(x, 64, "brown_d")
    for x in range(0, IMG_W, 6):
        img.vline(x, 58, 63, "brown")
        img.vline(x + 1, 58, 63, "umber")
    # mid: the tall window in the middle, big shelves either side
    img.rect(0, 65, IMG_W, AY0 - 65, "brown_d")
    for x in list(range(-6, MIDX - 34, 30)) + list(range(MIDX + 36, IMG_W, 30)):
        sh = K.bookshelf(29, 84, 2310 + x)
        img.blit(sh, x, 70)
    wx0, ww = MIDX - 28, 56
    for y in range(66, 152):
        for x in range(wx0, wx0 + ww):
            dxn = (x + 0.5 - MIDX) / (ww / 2)
            top = 66 + (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * 26
            if y >= top:
                img.set(x, y, "night" if y < 110 else "night_d")
    K.stars(img, (wx0 + 4, 76, wx0 + ww - 4, 120), 12, 2311)
    K.moon(img, MIDX + 12, 96, 7, halo=("water_d",), crescent=0.45)
    for x in range(wx0, wx0 + ww):
        for y in range(66, 152):
            if name_at(img, x, y) in ("night", "night_d", "water_d", "white", "steel_l", "lilac", "sky_l", "fog") \
                    and ((x - wx0) % 14 == 0 or (y - 66) % 18 == 0):
                img.set(x, y, "iron")
    win_outline = []
    for y in range(64, 154):
        for x in range(wx0 - 3, wx0 + ww + 3):
            n = name_at(img, x, y)
            if n in ("night", "night_d", "iron", "water_d", "white", "steel_l", "lilac", "sky_l", "fog"):
                continue
            if any(name_at(img, x + dx, y + dy) in ("night", "night_d", "iron") for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                win_outline.append((x, y))
    for (x, y) in win_outline:
        img.set(x, y, "gold_d" if x < MIDX else "brown")
    sc.light_shafts = [(MIDX - 70, 26, 0.05, (0.7, 0.8, 1.0)), (MIDX - 40, 14, 0.04, (0.7, 0.8, 1.0))]
    # floor: warm boards, a dark rug runner border round the arena
    K.planks(img, (0, 152, IMG_W, IMG_H), ("gold_d", "gold_d"), "brown", 2302, h=8)
    for x in range(AX0 - 6, AX1 + 6):
        for y in range(AY0 - 6, AY1 + 6):
            if not (AX0 - 1 <= x < AX1 + 1 and AY0 - 1 <= y < AY1 + 1):
                edge = x in (AX0 - 6, AX1 + 5) or y in (AY0 - 6, AY1 + 5)
                img.set(x, y, "gold" if edge else ("red_d" if (x + y) % 6 else "wine"))
    K.edge_shadow(img, 152, 4, 0, IMG_W)
    K.edge_shadow(img, AY0, 4)
    # sides: reading desks with candles and book piles
    for (x, y) in ((6, 196), (6, 292), (246, 214), (246, 312)):
        desk = Canvas(46, 24)
        desk.rect(1, 2, 44, 10, "brown")
        desk.hline(1, 44, 2, "gold_d")
        desk.rect(3, 12, 3, 10, "brown_d")
        desk.rect(40, 12, 3, 10, "brown_d")
        for k in range(3):
            px = 10 + k * 10
            desk.rect(px, 0, 7, 3, ("red_d", "water_d", "forest")[k])
            desk.hline(px, px + 6, 0, ("red", "water", "leaf_d")[k])
        desk.outline_all("ink")
        AW.place(img, desk, x, y, shadow=(1.0, -1), shadow_dx=4)
        sc.anim("candle", x + 4, y - 9, (x + y) % 4, 1.0)
        sc.anim("candle", x + 36, y - 9, (x + y + 2) % 4, 1.1)
    # globe on a stand
    gx, gy = 22, 370
    globe = Canvas(16, 24)
    for (x, y) in P.ellipse(8, 7, 6.5, 6.5):
        globe.set(x, y, "water" if fbm(x, y, 3, 4, 2) < 0.55 else "leaf_d")
    globe.set(5, 4, "sky_l")
    globe.vline(8, 14, 21, "gold_d")
    globe.hline(4, 12, 22, "gold_d")
    globe.outline_all("ink")
    AW.place(img, globe, gx, gy, shadow=(1.0, -1))
    # bottom: shelves back to back and a reading nook
    for x in range(-6, IMG_W, 30):
        sh = K.bookshelf(29, 50, 2330 + x)
        img.blit(sh, x, 420)
    K.edge_shadow(img, 414, 6, 0, IMG_W)
    # floating books above the shelves and in the side aisles
    for i, (x, y) in enumerate(((30, 112), (90, 128), (196, 116), (256, 132), (14, 240), (270, 260), (40, 400), (240, 396))):
        sc.anim("book_float", x, y, i % 6, 0.8 + (i % 3) * 0.12)
    for i, (x, y) in enumerate(((60, 70), (230, 80), (150, 30))):
        sc.anim("glint_violet", x, y, i * 3, 0.7)
    for (x, y) in ((44, 110), (258, 126)):
        sc.light("magic", x, y, 0.6)
    sc.light("sun", MIDX - 10, 80, 0.5, tint=(0.65, 0.78, 1.0))
    # foreground: dark shelf ends in the top corners, book piles at the bottom
    for side in (0, 1):
        end = Canvas(40, 80)
        end.rect(0, 0, 40, 80, "umber")
        end.rect(0, 0, 4, 80, "brown_d")
        for y in range(6, 80, 13):
            end.hline(0, 39, y, "brown_d")
        sc.put_fg(end.flipped() if side else end, -14 if side == 0 else IMG_W - 26, 80)
    for k, x in enumerate((0, 36, 236, 272)):
        pile = Canvas(28, 22)
        for j in range(4):
            col = ("red_d", "water_d", "forest", "violet")[(j + k) % 4]
            pile.rect(2 + (j % 2) * 2, 18 - j * 5, 22 - (j % 2) * 3, 4, col)
            pile.hline(2 + (j % 2) * 2, 22, 18 - j * 5, "cream")
        pile.outline_all("ink")
        sc.put_fg(pile, x, 404 + (k % 2) * 6)
    sc.particle(kind="mote", amount=14, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(0.2, -1), spread=180,
                speed=(1, 3), gravity=(0, 0), colour_fade=True)
    sc.particle(glow=True, kind="spark_violet", amount=6, lifetime=3.0, rect=(-40, -60, 220, 30), velocity=(0, -1),
                spread=180, speed=(2, 5), gravity=(0, 0), blink=True)
    sc.modulate = (1.0, 0.95, 0.88)
    return sc


def scene_castle_wall() -> Scene26:
    """2-4 城牆之上: sunset on the wall walk. Beyond the battlements the land glows orange and violet;
    towers with banners stand at the corners, gargoyles crouch on the merlons, torches are being lit."""
    sc = Scene26("stone", 0.45)
    img = sc.img
    K.sky_bands(img, 0, 132, [("dusk", 0.0), ("rose", 0.3), ("coral", 0.55), ("peach", 0.72), ("cream", 0.86)],
                seed=4, wave=2.0)
    for y in range(80, 124):
        for x in range(30, 110):
            d = math.hypot(x + 0.5 - 70, (y + 0.5 - 112) * 1.1)
            if d < 13:
                img.set(x, y, "white" if d < 9 else "yellow")
    # far hills and a tiny far town (atmospheric: pale rose / dusk)
    K.peaks_layer(img, 132, [(40, 26, 60), (150, 34, 70), (260, 28, 60)], "rose", "dusk", seed=41)
    K.hills_layer(img, 132, 8, 23.0, "dusk", rim="rose", seed=2, fill_to=150)
    K.treeline(img, 146, ("plum", "dusk", "dusk", "rose"), 2401, size=(3.0, 5.0), step=5, jitter=2)
    # mid: the outer battlement (its shadowed inner face towards us)
    wall = K.masonry(IMG_W, 16, ("stone_d", "stone", "stone_l"), 2402, course=5, mortar="slate", base_dark=4)
    img.blit(wall, 0, AY0 - 16)
    img.blit(K.crenels(IMG_W, 9, 6, 8, ("stone_d", "stone", "peach"), "slate"), 0, AY0 - 26)
    # floor: the wall walk
    K.flagstones(img, (0, AY0, IMG_W, IMG_H), ("stone", "stone"), "stone_d", 2403, worn="ash", worn_rate=0.12,
                 crack_rate=0.06)
    K.edge_shadow(img, AY0, 8, 0, IMG_W)
    # corner towers: round crowns at the four corners of the walk
    for side, tx in ((0, 26), (1, 278)):
        for ty in (AY0 - 34, AY1 - 30):
            crown = tower_crown(26, ("stone_d", "stone", "peach" if ty < AY0 else "stone_l"), "stone_d")
            AW.place(img, crown, tx - crown.w // 2, ty, shadow=(1.0, -2), shadow_dx=6)
        sc.anim("flag_camelot", tx - 6, AY0 - 36, side * 2, 1.1)
        sc.anim("torch", tx + (22 if side == 0 else -28), AY0 + 60, side, 1.0)
        sc.anim("torch", tx + (22 if side == 0 else -28), AY0 + 170, side + 2, 0.9)
    for side_x in (AX0 - 10, AX1 + 2):
        for y in range(AY0 + 10, AY1 - 30):
            for x in range(side_x, side_x + 8):
                img.set(x, y, "stone_l" if x == side_x else ("stone" if (y // 6) % 2 else "stone_d"))
    # gargoyles on the corner merlons
    img.blit(K.gargoyle_statue(), AX0 + 2, AY0 - 40)
    img.blit(K.gargoyle_statue(True), AX1 - 18, AY0 - 40)
    # bottom: inner parapet, the courtyard far below
    par = K.masonry(IMG_W, 10, ("stone_d", "stone", "stone_l"), 2405, course=5, mortar="slate", base_dark=0)
    img.blit(par, 0, AY1 + 6)
    img.blit(K.crenels(IMG_W, 9, 6, 6, ("stone_d", "stone", "stone_l"), "slate"), 0, AY1)
    for y in range(AY1 + 16, IMG_H):
        for x in range(IMG_W):
            img.set(x, y, "slate" if y < AY1 + 20 else ("navy" if y < AY1 + 34 else "night_d"))
    rr = Canvas(IMG_W, 80)
    house_row(rr, 70, -6, IMG_W + 6, 2406, [("slate", "ash", "fog")], [("wine", "dusk", "rose")],
              heights=(10, 16), widths=(18, 30), thorns=0.2, lit=0.7, timber=0.0, outline="navy")
    img.blit(rr, 0, AY1 + 40)
    for i, x in enumerate((96, 150, 204)):
        sc.anim("brazier", x, AY1 - 2, i, 1.0)
    # foreground: the tower crowns poke into the top corners; dark merlons at the bottom
    for side in (0, 1):
        pass
    bottom = K.crenels(IMG_W, 14, 10, 18, ("navy", "slate", "stone_d"), "ink")
    sc.put_fg(bottom, 0, 404)
    sc.light("sun", 8, 112, 1.3, tint=(1.0, 0.6, 0.35))
    sc.particle(kind="ember", amount=6, lifetime=3.0, rect=(30, 280, 140, 300), velocity=(0.2, -1), spread=30,
                speed=(6, 12), gravity=(0, -2), colour_fade=True)
    sc.particle(kind="leaf_dusk", amount=6, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.4), spread=20,
                speed=(10, 16), gravity=(0, 2), colour_fade=True, spin=True)
    sc.modulate = (1.0, 0.94, 0.9)
    return sc


def scene_magic_garden() -> Scene26:
    """2-5 魔法花園: a golden afternoon in the enchanted garden. Clipped hedge walls and topiaries,
    a rose arch strangled by purple thorns, glowing flowers; the lawn is mown in wide soft stripes."""
    sc = Scene26("grass", 0.4)
    img = sc.img
    K.sky_bands(img, 0, 70, [("azure", 0.0), ("haze", 0.4), ("cream", 0.7), ("peach", 0.9)], seed=5)
    K.hills_layer(img, 72, 10, 31.0, "moss", rim="leaf_l", seed=3, fill_to=96)
    K.treeline(img, 92, ("moss_d", "moss", "moss", "leaf_l"), 2501, size=(5.0, 8.0), step=8)
    # mid: the hedge maze walls (tall, flat-topped) with topiary towers
    for row, (y, h) in enumerate(((96, 22), (118, 26))):
        hedge = Canvas(IMG_W, h + 4)
        for x in range(IMG_W):
            for yy in range(h):
                col = "leaf" if yy < 4 else ("leaf_d" if yy < h - 3 else "forest")
                if yy < 4 and (x * 3 + yy * 5) % 11 == 0:
                    col = "leaf_l"
                if yy >= 4 and (x * 5 + yy * 3) % 13 == 0:
                    col = "forest"
                hedge.set(x, yy, col)
        if row == 0:
            for gx in range(20, IMG_W, 64):
                for yy in range(4, h):
                    for x in range(gx, gx + 12):
                        hedge.set(x, yy, "forest_d")
        hedge.outline_all("forest_d")
        img.blit(hedge, 0, y)
    # the rose arch over the garden gate, choked with thorns
    ax = MIDX
    for y in range(100, AY0):
        for x in range(ax - 30, ax + 30):
            d = math.hypot((x + 0.5 - ax) / 26, (y + 0.5 - 132) / 34)
            if 0.82 < d < 1.0 and y < 140 or (abs(abs(x + 0.5 - ax) - 24) < 3 and y >= 132):
                img.set(x, y, "forest" if (x + y) % 3 else "leaf_d")
            elif d <= 0.82 and y > 106:
                img.set(x, y, "sand" if y > 140 else "dirt")
    rng = random.Random(2502)
    for _ in range(26):
        a = rng.uniform(math.pi, 2 * math.pi)
        x, y = int(ax + math.cos(a) * 25), int(132 + math.sin(a) * 31)
        for dx, dy, cc in AW.flower(rng.choice(["red", "pink", "white"])):
            img.set(x + dx, y + dy, cc)
    for k in range(5):
        K.thorn_vine(img, ax - 26 + k * 13, AY0 - 2, 34, 2503 + k)
    for (x, kind) in ((40, "cone"), (86, "double"), (200, "double"), (248, "cone")):
        AW.place(img, topiary(x, kind), x - 8, 120, shadow=(0.9, -1), shadow_dx=4)
    # lawn: wide soft mowing stripes, calm
    for y in range(AY0 - 6, IMG_H):
        for x in range(IMG_W):
            band = ((x + int(3 * math.sin(y / 30.0))) // 22) % 2
            img.set(x, y, "leaf" if band else "grass")
    AW.paint_ground(img, (0, AY0 - 6, IMG_W, IMG_H), ("grass", "leaf", "spring"), 2504, scale=40, tufts=0.15,
                    max_light=0.06, max_dark=0.06, mask=lambda x, y: not in_arena(x, y))
    K.edge_shadow(img, AY0 - 6, 6, 0, IMG_W)
    AW.side_hedges(sc, 2505)
    # sides: flower beds in stone kerbs, purple thorn patches, glowing magic flowers
    for (x, y, w, h) in ((4, 180, 52, 40), (248, 200, 52, 40), (4, 300, 52, 44), (248, 316, 52, 40)):
        bed = AW.blob_canvas(w, h, [(w * (k + 0.5) / 4, h * 0.5 + (k % 2) * 3 - 1.5, h * 0.42) for k in range(4)],
                             ["forest", "leaf_d", "leaf", "leaf_l"], "forest_d", x + y, texture=0.2)
        brng = random.Random(x * 7 + y)
        for _ in range(16):
            fx, fy = brng.randrange(3, w - 3), brng.randrange(3, h - 6)
            if bed.opaque(fx, fy) and name_at(bed, fx, fy) != "forest_d":
                for dx, dy, cc in AW.flower(brng.choice(["red", "pink", "yellow", "white", "lilac"])):
                    if bed.opaque(fx + dx, fy + dy):
                        bed.set(fx + dx, fy + dy, cc)
        AW.place(img, bed, x, y, shadow=(1.0, -2), shadow_dx=4)
        K.thorn_vine(img, x + 4, y + h - 6, 40, x * y, up=False)
    for i, (x, y, kind) in enumerate(((20, 236, "flower_lilac"), (276, 252, "flower_pink"), (24, 350, "flower_white"),
                                      (270, 360, "flower_yellow"), (90, 150, "flower_pink"), (210, 152, "flower_lilac"))):
        sc.anim(kind, x, y, i % 4, 0.9 + (i % 3) * 0.1)
    # bottom: a lily pond with a little fountain, more beds
    px, py = MIDX, 448
    for y in range(py - 22, py + 22):
        for x in range(px - 56, px + 56):
            d = math.hypot((x + 0.5 - px) / 54, (y + 0.5 - py) / 20)
            if d < 1:
                img.set(x, y, "stone_l" if d > 0.9 else ("water_d" if d > 0.84 else ("sky" if y < py - 6 else "water")))
    for (x, y) in ((px - 30, py - 4), (px + 22, py + 2), (px - 6, py + 8)):
        img.blit(K.lily_pad(x), x, y)
    sc.anim("fountain", px - 8, py - 16, 1, 1.0)
    for k in range(5):
        sc.anim("water_glint", px - 40 + k * 18, py - 2 + (k % 2) * 6, k, 0.8)
    # foreground: rose bushes in the corners, hedge corners at the top
    for side in (0, 1):
        br = AL.foliage(64, 34, 2510 + side, ("forest_d", "forest", "leaf_d", "leaf"), "forest_d")
        for _ in range(6):
            fx, fy = rng.randrange(4, 60), rng.randrange(2, 20)
            if br.opaque(fx, fy):
                for dx, dy, cc in AW.flower(rng.choice(["red", "pink"])):
                    if br.opaque(fx + dx, fy + dy):
                        br.set(fx + dx, fy + dy, cc)
        sc.put_fg(br.flipped() if side else br, -4 if side == 0 else IMG_W - 60, 72)
    AL.clumps(sc.fg, 2520, ("forest_d", "forest", "leaf_d", "leaf"), "forest_d", flowers=["red", "pink", "lilac"])
    sc.light("sun", 220, 30, 1.2, tint=(1.0, 0.85, 0.55))
    sc.light("magic", ax, 128, 0.5)
    sc.particle(kind="pollen", amount=12, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(0.4, -1), spread=180,
                speed=(2, 5), gravity=(0, 0), colour_fade=True)
    sc.particle(kind="petal_violet", amount=6, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.6),
                spread=20, speed=(6, 10), gravity=(0, 2), colour_fade=True, spin=True)
    sc.modulate = (1.0, 0.97, 0.9)
    return sc


def scene_green_chapel() -> Scene26:
    """2-6 綠色禮拜堂: the Green Knight's chapel on an overcast afternoon. An ancient grassy barrow
    with a stone arch and a glowing round window, dark yews and purple thorns; mossy flagstones round
    the duelling ground; leaves drift down."""
    sc = Scene26("grass", 0.45)
    img = sc.img
    K.sky_bands(img, 0, 80, [("ash", 0.0), ("fog", 0.4), ("haze", 0.75)], seed=6, wave=2.2)
    cloud_bank(img, 40, ("fog", "haze", "white"), 2601, size=(5.0, 9.0), step=14)
    K.hills_layer(img, 84, 12, 27.0, "moss_d", rim="moss", seed=5, fill_to=110)
    K.treeline(img, 104, ("forest", "moss_d", "moss_d", "moss"), 2602, size=(4.0, 7.0), step=7)
    # the barrow chapel: a big grass mound with a stone arch and a round window
    cx, cy = MIDX, 152
    for y in range(76, AY0):
        for x in range(cx - 92, cx + 92):
            d = math.hypot((x + 0.5 - cx) / 92, (y + 0.5 - cy) / 70)
            if d < 1:
                lit = (x - cx) / 92 - (y - cy) / 110 < -0.15
                col = "leaf" if lit else ("grass" if (x - cx) < 40 else "leaf_d")
                if d > 0.95:
                    col = "forest"
                if fbm(x, y, 2603, 8, 2) > 0.68:
                    col = K.dk(col)
                img.set(x, y, col)
    for x in range(cx - 92, cx + 92):
        for y in range(76, AY0):
            if name_at(img, x, y) in ("leaf", "grass", "leaf_d", "forest", "leaf_l") and \
                    name_at(img, x, y - 1) not in ("leaf", "grass", "leaf_d", "forest", "leaf_l", "moss", "forest_d"):
                img.set(x, y, "leaf_l")
                break
    for y in range(110, AY0):
        for x in range(cx - 22, cx + 22):
            dxn = (x + 0.5 - cx) / 22
            top = 110 + (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * 16
            if y >= top:
                inner = abs(x + 0.5 - cx) < 15 and y >= top + 6
                img.set(x, y, "deep" if inner else ("stone_l" if x < cx - 8 else ("stone" if x < cx + 10 else "stone_d")))
    for y in range(90, 104):
        for x in range(cx - 8, cx + 8):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - 97)
            if d < 7:
                img.set(x, y, "stone_d" if d > 5.5 else ("spring" if (x + y) % 3 else "leaf_l"))
    for k in range(6):
        K.thorn_vine(img, cx - 70 + k * 28, AY0 - 1, 40, 2604 + k)
    for (x, y) in ((cx - 18, 124), (cx + 15, 126), (cx - 2, 112)):
        sc.anim("rune_cyan", x, y, (x + y) % 6, 0.7)
    sc.light("magic", cx, 97, 0.8, tint=(0.5, 1.0, 0.6))
    for (x, h) in ((14, 60), (40, 50), (250, 56), (276, 62)):
        img.blit(yew(x, h), x - 9, AY0 + 4 - h)
    # floor: an ancient ring of mossy flagstones in the grass
    AW.paint_ground(img, (0, AY0 - 2, IMG_W, IMG_H), ("grass", "leaf", "spring"), 2605, scale=30, tufts=0.4)
    ring_c = (MIDX, (AY0 + AY1) // 2 + 4)
    calm_ground(img, ("leaf_d", "grass", "leaf"), 2606)
    AW.side_hedges(sc, 2609, ("deep", "forest", "leaf_d", "grass"), "navy")

    def on_path(x: int, y: int) -> bool:
        d = math.hypot((x + 0.5 - ring_c[0]) / 74, (y + 0.5 - ring_c[1]) / 92)
        return 0.86 < d < 1.0
    K.flagstones(img, (AX0, AY0, AX1, AY1), ("stone", "stone"), "stone_d", 2607, mask=on_path, widths=(6, 9),
                 heights=(5, 7), crack_rate=0.0)
    K.soft_patches(img, (AX0, AY0, AX1, AY1), "moss", 2608, cover=0.2, scale=12, only=("stone",))
    K.edge_shadow(img, AY0 - 2, 5, 0, IMG_W)
    # sides: standing stones with runes, ferns, toadstools
    for (x, y, h) in ((8, 200, 30), (262, 220, 28), (16, 320, 26), (258, 336, 32)):
        AW.place(img, K.menhir(h, x, ("stone_d", "stone", "stone_l"), "iron", rune="spring"), x, y,
                 shadow=(1.1, -1), shadow_dx=5)
    for k, (x, y) in enumerate(((44, 250), (240, 270), (40, 380), (250, 390))):
        AW.place(img, AW.fern(k), x, y, shadow=None)
        img.blit(AW.mushroom("red" if k % 2 else "orange"), x + 10, y + 8)
    for i, x in enumerate(range(-12, IMG_W, 22)):
        AW.place(img, AW.tree(2610 + i, 30, ("forest_d", "forest", "leaf_d", "moss"), "deep"), x, 440 + (i * 7) % 14)
    # foreground: yew boughs at the top corners, ferns at the bottom
    for side in (0, 1):
        br = AL.foliage(64, 34, 2620 + side, ("deep", "forest_d", "forest", "leaf_d"), "navy")
        sc.put_fg(br.flipped() if side else br, -4 if side == 0 else IMG_W - 60, 70)
    for k, x in enumerate((-2, 30, 64, 210, 246, 280)):
        sc.put_fg(AL.fern(k, ("forest_d", "forest", "leaf_d")), x, 392 + (k % 3) * 3)
    sc.light("sun", MIDX, 10, 0.6, tint=(0.8, 1.0, 0.8))
    sc.particle(kind="leaf_green", amount=8, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.5), spread=20,
                speed=(8, 12), gravity=(0, 3), colour_fade=True, spin=True)
    sc.particle(glow=True, kind="firefly_green", amount=8, lifetime=5.0, rect=(-10, -40, 200, 400), velocity=(0, -1),
                spread=180, speed=(2, 5), gravity=(0, 0), blink=True)
    sc.modulate = (0.95, 1.0, 0.95)
    return sc


# ==========================================================================
# Chapter 3: cool moonlight and mist
# ==========================================================================

def scene_misty_lake() -> Scene26:
    """3-1 迷霧湖畔: the lake just before dawn. Pale mist lies on still water, the far island carries
    Morgana's spire; reeds, a little jetty and a moored boat on the cool grassy shore."""
    sc = Scene26("grass", 0.45)
    img = sc.img
    K.sky_bands(img, 0, 70, [("night", 0.0), ("ash", 0.35), ("fog", 0.62), ("rose", 0.86)], seed=7, wave=1.2)
    K.stars(img, (0, 0, IMG_W, 22), 18, 3101, big=1)
    K.peaks_layer(img, 70, [(50, 22, 60), (130, 16, 46), (250, 26, 62)], "fog", "ash", seed=31, rough=1.0)
    # the far island and the spire (cool silhouette, one lit window)
    ix = 186
    for y in range(52, 74):
        for x in range(ix - 30, ix + 30):
            if (y - 66) > -abs(x - ix) * 0.35 + 0 and y >= 64:
                img.set(x, y, "slate")
    for y in range(18, 66):
        half = 3 + (y - 18) * 0.06
        for x in range(int(ix - half), int(ix + half) + 1):
            img.set(x, y, "slate" if x > ix - half + 2 else "ash")
    for y in range(10, 20):
        half = (y - 10) * 0.5 + 0.5
        for x in range(int(ix - half), int(ix + half) + 1):
            img.set(x, y, "plum")
    img.set(ix, 30, "lilac")
    img.set(ix, 31, "violet")
    # the lake: calm cool bands with long glints; mist lies in strips
    water_bands(img, (0, 72, IMG_W, AY0 - 10), [("ash", 0.0), ("night", 0.12), ("water_d", 0.45), ("night", 0.8)],
                3102, glints=("fog", "steel_l"), n_glints=40)
    for y in range(72, 90):
        for x in range(ix - 6, ix + 6):
            if (x + y) % 3 == 0 and name_at(img, x, y) in ("night", "ash", "water_d"):
                img.set(x, y, "slate")
    for i, (x, y) in enumerate(((10, 80), (80, 92), (150, 100), (210, 84), (250, 110), (40, 118), (180, 126))):
        sc.anim("mist_strip", x - 20, y, i % 8, 0.6 + (i % 3) * 0.15)
    for k in range(10):
        sc.anim("night_glint", 8 + k * 29, 96 + (k * 13) % 40, k % 6, 0.6 + (k % 3) * 0.2)
    # shore line: wet sand then cool grass
    for x in range(IMG_W):
        sy = AY0 - 10 + int(2 * math.sin(x / 17.0))
        for y in range(sy, sy + 8):
            img.set(x, y, "stone" if y < sy + 2 else "stone_l" if y < sy + 3 else "dirt")
    AW.paint_ground(img, (0, AY0 - 2, IMG_W, IMG_H), ("deep", "teal", "leaf_d"), 3103, scale=26, tufts=0.45,
                    max_light=0.2, max_dark=0.16)
    calm_ground(img, ("teal", "leaf_d", "grass"), 3104)
    frame_arena(img, 3105, ("deep", "teal", "leaf_d", "grass"), "navy")
    K.calm_vignette(img, 10)
    # the jetty and a rowing boat on the right, reeds and rocks along the shore
    for y in range(86, AY0 - 2):
        for x in range(232, 248):
            img.set(x, y, "umber" if y % 4 == 3 else ("brown" if x < 240 else "brown_d"))
            if x in (232, 247):
                img.set(x, y, "umber")
    for y in range(86, AY0 - 2, 12):
        img.rect(230, y, 2, 6, "umber")
        img.rect(248, y, 2, 6, "umber")
    boat = Canvas(28, 12)
    for (x, y) in P.ellipse(14, 4, 13, 7):
        if y >= 4:
            boat.set(x, y, "brown" if y < 7 else "brown_d")
    boat.hline(2, 25, 4, "gold_d")
    boat.outline_all("umber")
    img.blit(boat, 200, 108)
    for k, x in enumerate(range(-4, IMG_W, 18)):
        if 228 < x < 252:
            continue
        img.blit(K.reeds(3110 + k, 12 + k % 3 * 3), x, AY0 - 22 + (k % 2) * 3)
    for (x, y) in ((40, 150), (110, 148), (270, 152)):
        AW.place(img, AW.rock(x, 12, 7, ("slate", "ash", "fog", "white"), "navy", "teal"), x, y, shadow=None)
    # sides and bottom: pines of the lake wood
    for i, x in enumerate((-8, 16, 252, 276)):
        AW.place(img, AW.pine(3120 + i, 46, ("deep", "teal", "grass"), "navy"), x, 190 + (i % 2) * 40)
    for i, x in enumerate(range(-14, IMG_W, 16)):
        AW.place(img, AW.pine(3130 + i, 44 + (i * 7) % 12, ("deep", "teal", "grass"), "navy"), x,
                 410 + (i * 5) % 14)
    for (x, y) in ((24, 300), (262, 320), (30, 380), (250, 386)):
        AW.place(img, AW.bush(x, 16, 10, ("deep", "teal", "grass", "leaf"), "navy", flowers=["lilac", "white"]), x, y)
    # foreground: reeds in the bottom corners, pine boughs top corners
    for k, x in enumerate((-2, 20, 44, 236, 258, 282)):
        r = K.reeds(3140 + k, 30)
        sc.put_fg(r.scaled(1), x, 380 + (k % 2) * 8)
    for side in (0, 1):
        sc.put_fg(AL.pine_branch(66, 40, 3150 + side, side == 1), -6 if side == 0 else 248, 68)
    sc.light("sun", MIDX, 40, 0.7, tint=(1.0, 0.7, 0.75))
    sc.particle(kind="mist", amount=14, lifetime=8.0, rect=(-40, -80, 260, 120), velocity=(1, 0), spread=10,
                speed=(2, 5), gravity=(0, 0), colour_fade=True)
    sc.particle(kind="mist", amount=6, lifetime=8.0, rect=(-40, 60, 260, 300), velocity=(1, 0), spread=10,
                speed=(2, 4), gravity=(0, 0), colour_fade=True)
    sc.particle(glow=True, kind="firefly", amount=6, lifetime=5.0, rect=(-10, 0, 200, 380), velocity=(0, -1),
                spread=180, speed=(2, 5), gravity=(0, 0), blink=True)
    sc.modulate = (0.92, 0.95, 1.0)
    return sc


def scene_fairy_forest() -> Scene26:
    """3-2 妖精森林: night in the fairy wood. Giant trees, moonbeams, rings of glowing mushrooms and
    wisps; the clearing is soft moss."""
    sc = Scene26("teal", 0.55)
    img = sc.img
    img.rect(0, 0, IMG_W, AY0, "navy")
    K.sky_bands(img, 0, 40, [("night_d", 0.0), ("night", 0.6)], seed=8)
    # far: distant tree crowns (flat, cool), mid: a few great trunks under a dark canopy
    K.treeline(img, 60, ("navy", "night_d", "night_d", "night"), 3201, size=(8.0, 12.0), step=12)
    for y in range(54, AY0):
        for x in range(IMG_W):
            img.set(x, y, "night_d" if y < 120 else "navy")
    for i, (x, w) in enumerate(((70, 8), (118, 10), (182, 9), (226, 8))):
        t = giant_tree(w, AY0 - 40, 3202 + i, bark=("ink", "navy", "night_d", "night"), outline="ink", roots=False)
        img.blit(t, x - t.w // 2, 40)
    for i, (x, w) in enumerate(((30, 26), (274, 28))):
        t = giant_tree(w, AY0 - 6, 3205 + i, bark=("navy", "deep", "teal", "grass"))
        img.blit(t, x - t.w // 2, 0)
    for k, (x, y, w, h) in enumerate(((-10, 0, 120, 46), (90, -6, 130, 40), (196, 0, 120, 48), (40, 24, 70, 26),
                                       (190, 26, 74, 24))):
        fol = AL.foliage(w, h, 3240 + k, ("navy", "deep", "teal", "grass"), "ink", hang=False)
        img.blit(fol, x, y)
    for k in range(9):
        x, y = 12 + k * 33, 120 + (k * 17) % 30
        img.blit(K.mushroom_glow(k), x, y)
        sc.anim("mushroom_pulse", x + 1, y + 1, k % 6, 0.6 + (k % 3) * 0.1)
        sc.light("magic", x + 3, y + 3, 0.45, tint=(0.4, 1.0, 0.8))
    # side trunks (only on wide phones): roots with mushroom shelves
    for side, tx in ((0, 22), (1, 282)):
        t = giant_tree(30, IMG_H - AY0 + 40, 3210 + side, bark=("navy", "deep", "teal", "grass"))
        img.blit(t, tx - t.w // 2, AY0 - 20)
        for k in range(3):
            y = AY0 + 30 + k * 70 + side * 20
            img.blit(K.mushroom_glow(k, cap=("plum", "violet", "lilac")), tx + (12 if side == 0 else -18), y)
    # clearing: moss, a fairy ring of mushrooms round the edge
    AW.paint_ground(img, (AX0 - 30, AY0 - 6, AX1 + 30, IMG_H), ("deep", "teal", "leaf_d"), 3205, scale=24, tufts=0.4,
                    max_light=0.16, max_dark=0.2)
    calm_ground(img, ("forest", "teal", "leaf_d"), 3206)
    crng = random.Random(3208)
    for _ in range(14):
        cx, cy = crng.randrange(AX0 + 6, AX1 - 6), crng.randrange(AY0 + 6, AY1 - 6)
        if AX0 + 30 < cx < AX1 - 30 and AY0 + 30 < cy < AY1 - 30:
            continue
        for _ in range(5):
            fx, fy = cx + crng.randrange(-5, 6), cy + crng.randrange(-4, 5)
            img.set(fx, fy, crng.choice(("lilac", "sky_l", "spring")))
            img.set(fx, fy + 1, "deep")
    frame_arena(img, 3207, ("navy", "deep", "teal", "leaf_d"), "ink")
    K.calm_vignette(img, 12)
    K.edge_shadow(img, AY0, 6)
    rng = random.Random(3205)
    for k in range(34):
        a = k / 34 * 2 * math.pi
        x = int(MIDX + math.cos(a) * 94)
        y = int((AY0 + AY1) / 2 + math.sin(a) * 122)
        if in_arena(x, y) or in_arena(x + 6, y + 6):
            continue
        img.blit(K.mushroom_glow(k, cap=("teal", "sky", "sky_l") if k % 3 else ("plum", "violet", "lilac")), x, y)
    for (x, y) in ((AX0 - 6, AY0 - 6), (AX1 - 2, AY0 + 30), (AX0 - 4, AY1 - 30), (AX1 - 2, AY1 - 4)):
        img.blit(K.mushroom_glow(x, cap=("plum", "violet", "lilac")), x, y)
    # moonbeams
    sc.light_shafts = [(30, 18, 0.06, (0.6, 0.8, 1.0)), (100, 12, 0.05, (0.6, 0.8, 1.0)), (-40, 14, 0.05, (0.6, 0.8, 1.0))]
    # bottom: roots and ferns, more trunks
    for i, x in enumerate(range(-14, IMG_W, 24)):
        AW.place(img, AW.tree(3210 + i, 30, ("navy", "deep", "teal", "grass"), "navy"), x, 432 + (i * 7) % 12)
    for k, (x, y) in enumerate(((70, 396), (110, 400), (196, 398), (230, 394))):
        AW.place(img, AW.fern(k, ("deep", "teal", "grass")), x, y, shadow=None)
    for i, (x, y) in enumerate(((70, 120), (130, 100), (190, 126), (240, 140), (90, 410), (210, 420), (20, 200), (276, 300))):
        sc.anim("wisp", x, y, i % 6, 0.6 + (i % 3) * 0.15)
    # foreground: dark leaves top corners, glowing ferns at the bottom
    for side in (0, 1):
        br = AL.foliage(70, 36, 3220 + side, ("navy", "deep", "teal", "grass"), "ink")
        sc.put_fg(br.flipped() if side else br, -6 if side == 0 else IMG_W - 64, 70)
    for k, x in enumerate((-2, 30, 64, 210, 246, 280)):
        sc.put_fg(AL.fern(k, ("navy", "deep", "teal")), x, 392 + (k % 3) * 3)
    sc.particle(glow=True, kind="firefly_green", amount=16, lifetime=5.0, rect=(-10, -40, 200, 400), velocity=(0, -1),
                spread=180, speed=(2, 6), gravity=(0, 0), blink=True)
    sc.particle(glow=True, kind="spark_cyan", amount=8, lifetime=4.0, rect=(-30, -60, 240, 120), velocity=(0, 1),
                spread=40, speed=(2, 5), gravity=(0, 0), blink=True)
    sc.modulate = (0.9, 0.94, 1.0)
    return sc


def scene_stone_circle() -> Scene26:
    """3-3 月光石陣: midnight under a huge full moon. Rolling dark hills, the great trilithons behind the
    grassy plateau, smaller standing stones round it with glowing runes."""
    sc = Scene26("grass", 0.5)
    img = sc.img
    K.sky_bands(img, 0, 120, [("navy", 0.0), ("night_d", 0.3), ("night", 0.7)], seed=9)
    K.stars(img, (0, 0, IMG_W, 100), 60, 3301, big=4)
    K.moon(img, 210, 46, 20, halo=("night", "water_d"))
    K.peaks_layer(img, 118, [(40, 30, 70), (150, 22, 60), (270, 36, 70)], "night", "night_d", rim="water_d", seed=33)
    K.hills_layer(img, 132, 10, 29.0, "deep", rim="teal", seed=7, fill_to=150)
    # mid: trilithons behind the plateau
    for (x, h) in ((70, 46), (130, 52), (190, 50), (240, 44)):
        for k in (0, 1):
            st = K.menhir(h, x + k, ("navy", "slate", "ash"), "ink", rune="teal" if k == 0 and x % 60 == 10 else None)
            img.blit(st, x + k * 22 - 8, AY0 - 2 - st.h)
        for y in range(AY0 - 2 - h - 6, AY0 - 2 - h + 1):
            for xx in range(x - 10, x + 34):
                img.set(xx, y, "ash" if y == AY0 - 2 - h - 6 else ("slate" if xx < x + 20 else "navy"))
        for xx in range(x - 11, x + 35):
            img.set(xx, AY0 - 2 - h - 7, "ink")
            img.set(xx, AY0 - 2 - h + 1, "ink")
        img.vline(x - 11, AY0 - 2 - h - 7, AY0 - 2 - h + 1, "ink")
        img.vline(x + 34, AY0 - 2 - h - 7, AY0 - 2 - h + 1, "ink")
    # plateau grass, a pale ring path
    AW.paint_ground(img, (0, AY0 - 6, IMG_W, IMG_H), ("deep", "teal", "leaf_d"), 3302, scale=26, tufts=0.4,
                    max_light=0.16, max_dark=0.2)
    calm_ground(img, ("forest", "teal", "leaf_d"), 3303)
    frame_arena(img, 3304, ("navy", "deep", "teal", "leaf_d"), "ink", rocks=True)
    rune_ring(img, MIDX, (AY0 + AY1) // 2 + 6, 70, "teal", "grass", ticks=20, width=1.6)
    K.calm_vignette(img, 12)
    K.edge_shadow(img, AY0 - 6, 5, 0, IMG_W)
    # small standing stones round the plateau with glowing runes
    spots = [(20, 190), (262, 200), (14, 280), (268, 290), (24, 360), (258, 372), (90, 398), (190, 400)]
    for i, (x, y) in enumerate(spots):
        h = 24 + (i * 5) % 10
        AW.place(img, K.menhir(h, i, ("slate", "ash", "fog"), "navy", rune="sky"), x, y - h, shadow=(1.1, -1),
                 shadow_dx=-5)
        sc.anim("rune_cyan", x + h // 4 + 1, y - h + h // 3 + 1, i % 6, 0.6 + (i % 3) * 0.1)
        sc.light("magic", x + 6, y - h // 2, 0.45, tint=(0.4, 0.8, 1.0))
    for i, x in enumerate(range(-14, IMG_W, 22)):
        AW.place(img, AW.bush(3310 + i, 22, 12, ("navy", "deep", "teal", "grass"), "navy"), x, 440 + (i * 7) % 16)
    for i, (x, y) in enumerate(((40, 20), (90, 60), (150, 14), (270, 80), (20, 90))):
        sc.anim("glint_star", x, y, i * 2, 0.6 + i * 0.1)
    for side in (0, 1):
        crown = K.menhir(70, 3320 + side, ("navy", "slate", "ash"), "ink")
        sc.put_fg(crown, -20 if side == 0 else IMG_W - 26, 78)
    AL.clumps(sc.fg, 3330, ("navy", "deep", "teal", "grass"), "ink", gap=(26, 46))
    sc.light("sun", 210 + AW.ORIGIN[0] - AW.ORIGIN[0], 46, 1.2, tint=(0.6, 0.75, 1.0))
    sc.particle(glow=True, kind="spark_cyan", amount=12, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=20, speed=(3, 6), gravity=(0, 0), blink=True)
    sc.particle(kind="mist", amount=8, lifetime=8.0, rect=(-40, 200, 260, 380), velocity=(1, 0), spread=10,
                speed=(2, 4), gravity=(0, 0), colour_fade=True)
    sc.modulate = (0.88, 0.92, 1.0)
    return sc


def scene_crystal_cave() -> Scene26:
    """3-4 水晶洞窟: a cavern lit by cyan and violet crystal clusters; stalactites above, a still pool,
    the floor worn smooth in the middle."""
    sc = Scene26("ash", 0.55)
    img = sc.img
    # far: the dark depth of the cave with faint far crystals
    img.rect(0, 0, IMG_W, AY0, "navy")
    AW.paint_ground(img, (0, 0, IMG_W, 70), ("ink", "navy", "night_d"), 3401, scale=24, tufts=0.0,
                    max_light=0.1, max_dark=0.2)
    for i, x in enumerate(range(10, IMG_W, 30)):
        cr = K.crystal(10 + (i * 7) % 8, i, ("night_d", "night", "water_d", "water"), "navy")
        img.blit(cr, x, 60 - cr.h + (i * 5) % 8)
    # mid: the back wall (rock with lit ledges) and big clusters
    for y in range(66, AY0):
        for x in range(IMG_W):
            img.set(x, y, "navy")
    brng = random.Random(3409)
    for row, y0 in enumerate((70, 96, 122)):
        x = -10 + row * 9
        while x < IMG_W + 10:
            r = brng.uniform(11, 17) - row
            bl = AW.blob_canvas(int(r * 2.6) + 4, int(r * 2) + 4, [(r * 1.3 + 2, r + 2, r), (r * 0.7 + 2, r * 1.2 + 2, r * 0.7),
                                                                (r * 1.9 + 2, r * 1.2 + 2, r * 0.75)],
                                ["navy", "slate", "slate", "ash"], "ink", 3409 + int(x) + row * 50, texture=0.12)
            img.blit(bl, int(x), y0 + brng.randrange(0, 6))
            x += r * 2.1
    for x in range(IMG_W):
        for y in range(66, 70):
            img.set(x, y, "navy")
    for (cx, base, n, cols) in ((40, AY0 - 2, 5, "cyan"), (MIDX + 10, 140, 4, "violet"), (250, AY0 - 2, 5, "cyan"),
                                (100, 120, 3, "cyan"), (200, 116, 3, "violet")):
        ramp = ("water_d", "water", "sky", "sky_l") if cols == "cyan" else ("plum", "violet", "lilac", "white")
        for k in range(n):
            h = 18 + ((k * 7 + cx) % 12) + (12 if k == n // 2 else 0)
            cr = K.crystal(h, cx + k, ramp, "navy", lean=(k - n / 2) * 0.12)
            img.blit(cr, cx - 12 + k * 6, base - cr.h)
        sc.anim("glint_cyan" if cols == "cyan" else "glint_violet", cx - 4, base - 24, (cx // 7) % 8, 0.7)
        sc.light("magic", cx, base - 10, 0.75, tint=(0.4, 0.9, 1.0) if cols == "cyan" else None)
    # stalactites
    rng = random.Random(3403)
    for x in range(0, IMG_W, 9):
        ln = rng.randrange(4, 18)
        for k in range(ln):
            w = max(1, int((ln - k) / ln * 3))
            for dx in range(w):
                img.set(x + dx, 66 + k, "slate" if dx == 0 else "navy")
    # floor
    AW.paint_ground(img, (0, AY0 - 4, IMG_W, IMG_H), ("navy", "slate", "ash"), 3404, scale=30, tufts=0.0,
                    max_light=0.12, max_dark=0.14)
    calm_ground(img, ("slate", "ash", "fog"), 3405, tufts=0.0)
    K.soft_patches(img, (AX0, AY0, AX1, AY1), "slate", 3407, cover=0.08, scale=22, only=("ash",))
    K.calm_vignette(img, 12)
    K.edge_shadow(img, AY0 - 4, 7, 0, IMG_W)
    # side clusters and stalagmites, a pool at the bottom
    for (x, y, cols) in ((8, 220, "cyan"), (262, 250, "violet"), (12, 330, "violet"), (256, 350, "cyan")):
        ramp = ("water_d", "water", "sky", "sky_l") if cols == "cyan" else ("plum", "violet", "lilac", "white")
        for k in range(3):
            cr = K.crystal(12 + k * 5, x + k, ramp, "navy", lean=(k - 1) * 0.2)
            AW.place(img, cr, x + k * 7, y - cr.h, shadow=(0.8, -1), shadow_dx=2)
        sc.anim("glint_cyan" if cols == "cyan" else "glint_violet", x + 6, y - 20, (x // 3) % 8, 0.8)
        sc.light("magic", x + 12, y - 10, 0.6, tint=(0.4, 0.9, 1.0) if cols == "cyan" else None)
    px, py = MIDX, 452
    for y in range(py - 20, py + 20):
        for x in range(px - 70, px + 70):
            d = math.hypot((x + 0.5 - px) / 68, (y + 0.5 - py) / 18) + (fbm(x, y, 3406, 8, 2) - 0.5) * 0.3
            if d < 1:
                img.set(x, y, "navy" if d > 0.88 else ("water_d" if y > py - 4 else "night"))
    for k in range(6):
        sc.anim("night_glint", px - 50 + k * 18, py - 6 + (k % 2) * 8, k, 0.8)
    # foreground: big dark crystals and rock in the corners
    for side in (0, 1):
        rock = Canvas(60, 40)
        AW.paint_ground(rock, (0, 0, 60, 40), ("ink", "navy", "slate"), 3410 + side, scale=16, tufts=0.0,
                        max_light=0.1, max_dark=0.3)
        for y in range(40):
            for x in range(60):
                if math.hypot((x - (0 if side == 0 else 60)) / 60, (y - 0) / 40) > 1:
                    rock.set(x, y, None)
        sc.put_fg(rock, -4 if side == 0 else IMG_W - 56, 78)
    for k, x in enumerate((0, 40, 228, 268)):
        cr = K.crystal(26 + k * 3, k, ("night_d", "water_d", "water", "sky"), "ink", lean=(k - 1.5) * 0.15)
        sc.put_fg(cr, x, 430 - cr.h + 20)
    sc.particle(kind="drip", amount=6, lifetime=1.2, rect=(-20, -20, 220, -10), velocity=(0, 1), spread=0,
                speed=(30, 40), gravity=(0, 60), colour_fade=True)
    sc.particle(glow=True, kind="spark_cyan", amount=10, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(2, 4), gravity=(0, 0), blink=True)
    sc.particle(glow=True, kind="spark_violet", amount=6, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(2, 4), gravity=(0, 0), blink=True)
    sc.modulate = (0.92, 0.95, 1.0)
    return sc


def scene_morgana_tower() -> Scene26:
    """3-5 摩根娜之塔: inside the witch's tower at night. Violet stone, tall windows on the moon,
    shelves of potions, floating candles and orbs, a faint magic circle on the floor."""
    sc = Scene26("ash", 0.55)
    img = sc.img
    img.rect(0, 0, IMG_W, AY0, "plum")
    # far: the upper wall fading into the dark tower above
    wall_hi = K.masonry(IMG_W, 60, ("navy", "night_d", "slate"), 3501, course=6, mortar="ink", base_dark=0)
    img.blit(wall_hi, 0, 0)
    # mid: the curved wall with three moonlit windows, banners and shelves
    wall = K.masonry(IMG_W, AY0 - 60, ("plum", "dusk", "violet"), 3502, course=7, mortar="ink", base_dark=8)
    img.blit(wall, 0, 60)
    for x in range(IMG_W):
        img.set(x, 60, "ink")
        img.set(x, 61, "slate")
    for i, wx in enumerate((MIDX - 60, MIDX - 6, MIDX + 48)):
        win = Canvas(16, 46)
        for y in range(46):
            for x in range(16):
                dxn = (x + 0.5 - 8) / 8
                if y >= (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * 8:
                    win.set(x, y, "night" if y < 30 else "night_d")
        if i == 1:
            K.moon(win, 9, 14, 5, halo=(), crescent=0.0)
        else:
            K.stars(win, (2, 6, 14, 30), 4, 3503 + i, big=0)
        win.vline(8, 4, 45, "ink")
        win.hline(0, 15, 24, "ink")
        win.outline_all("slate")
        win.outline_all("ink")
        img.blit(win, wx - 2, 74)
    sc.light_shafts = [(MIDX - 76, 14, 0.05, (0.7, 0.75, 1.0)), (MIDX - 22, 16, 0.06, (0.7, 0.75, 1.0)),
                       (MIDX + 32, 14, 0.05, (0.7, 0.75, 1.0))]
    for i, x in enumerate((MIDX - 86, MIDX + 22, MIDX + 74)):
        sc.anim("flag_morgana", x, 70, i, 0.8 + i * 0.1)
    for side, x in ((0, 4), (1, IMG_W - 56)):
        shelf = Canvas(52, 60)
        shelf.rect(0, 0, 52, 60, "umber")
        for sy in range(8, 60, 16):
            shelf.rect(2, sy, 48, 2, "brown")
            for k in range(6):
                bx = 4 + k * 8
                col = ("violet", "sky", "leaf", "red", "yellow", "lilac")[(k + sy) % 6]
                shelf.rect(bx, sy - 6, 4, 6, col)
                shelf.set(bx, sy - 6, "white")
                shelf.rect(bx + 1, sy - 8, 2, 2, "brown_d")
        shelf.outline_all("ink")
        img.blit(shelf, x, AY0 - 62)
    # floor: cool violet-grey flags and a faint circle
    K.flagstones(img, (0, AY0 - 4, IMG_W, IMG_H), ("ash", "ash"), "slate", 3504, worn="stone", worn_rate=0.08,
                 crack_rate=0.05)
    rune_ring(img, MIDX, (AY0 + AY1) // 2 + 4, 76, "dusk", "ash", ticks=12, width=1.0)
    K.calm_vignette(img, 12)
    K.edge_shadow(img, AY0 - 4, 8, 0, IMG_W)
    # sides: a cauldron, a crystal ball, potion crates
    caul = Canvas(26, 20)
    for (x, y) in P.ellipse(13, 12, 11, 7):
        caul.set(x, y, "iron" if x > 14 else "steel_d")
    for x in range(4, 23):
        caul.set(x, 6, "leaf")
        caul.set(x, 5, "spring")
    caul.outline_all("ink")
    AW.place(img, caul, 14, 230, shadow=(1.0, -1))
    sc.anim("orb_cyan", 22, 214, 0, 0.8)
    ball = Canvas(14, 18)
    for (x, y) in P.ellipse(7, 6, 5.5, 5.5):
        ball.set(x, y, "lilac" if x < 6 and y < 5 else "violet")
    ball.rect(3, 12, 8, 4, "gold_d")
    ball.hline(3, 10, 12, "gold")
    ball.outline_all("ink")
    AW.place(img, ball, 264, 260, shadow=(1.0, -1))
    sc.light("magic", 271, 266, 0.6)
    for (x, y) in ((10, 320), (256, 330), (24, 390), (250, 400)):
        AW.place(img, K.barrel(x), x, y, shadow=(0.9, 0), shadow_dx=3)
    # bottom: the stairwell going down
    sx, sy = MIDX, AY1 + 64
    for y in range(AY1 + 18, IMG_H):
        for x in range(MIDX - 46, MIDX + 46):
            d = math.hypot((x + 0.5 - sx) / 44, (y + 0.5 - sy) / 40)
            if d < 1:
                a = (math.atan2(y - sy, x - sx) + math.pi) / (2 * math.pi) * 12
                step = int(a)
                col = "slate" if d > 0.92 else ("ash" if step % 2 else "stone_d")
                if d < 0.35:
                    col = "ink"
                elif d < 0.45:
                    col = "navy"
                elif a - step < 0.12:
                    col = "navy"
                img.set(x, y, col)
    wall_lo = K.masonry(IMG_W, 30, ("plum", "dusk", "violet"), 3505, course=7, mortar="ink")
    for y in range(30):
        for x in range(IMG_W):
            if abs(x - MIDX) >= 42:
                img.set(x, IMG_H - 30 + y, name_at(wall_lo, x, y))
    # floating candles and orbs above and to the sides of the arena
    for i, (x, y) in enumerate(((50, 110), (90, 130), (200, 126), (246, 108), (20, 180), (272, 200), (30, 300),
                                (268, 316), (70, 404), (226, 410))):
        sc.anim("candle", x, y, i % 4, 0.9 + (i % 3) * 0.1)
    for i, (x, y) in enumerate(((120, 50), (180, 40), (12, 140), (280, 150))):
        sc.anim("orb_violet", x, y, i % 6, 0.8)
        sc.light("magic", x + 3, y + 5, 0.5)
    sc.anim("book_float", 34, 140, 2, 0.8)
    sc.anim("book_float", 254, 150, 4, 0.9)
    for side in (0, 1):
        col = Canvas(36, 90)
        col.rect(0, 0, 36, 90, "ink")
        col.rect(0, 0, 36, 90, "navy")
        col.rect(0, 0, 4, 90, "slate")
        for y in range(0, 90, 7):
            col.hline(0, 35, y, "ink")
        sc.put_fg(col.flipped() if side else col, -12 if side == 0 else IMG_W - 24, 70)
    for k, x in enumerate((0, 40, 230, 268)):
        sc.put_fg(K.barrel(k).scaled(2), x, 404 + (k % 2) * 6)
    sc.particle(glow=True, kind="spark_violet", amount=14, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(2, 5), gravity=(0, 0), blink=True)
    sc.particle(kind="mote", amount=8, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -2), spread=180,
                speed=(1, 3), gravity=(0, 0), colour_fade=True)
    sc.modulate = (0.96, 0.92, 1.0)
    return sc


def scene_tower_top() -> Scene26:
    """3-6 塔頂: the top of Morgana's tower in a night storm. A round platform with battlements over a
    sea of cloud, the lake far below, the moon in torn clouds, lightning, braziers and violet banners."""
    sc = Scene26("ash", 0.55)
    img = sc.img
    K.sky_bands(img, 0, 150, [("ink", 0.0), ("navy", 0.15), ("night_d", 0.45), ("night", 0.8)], seed=10)
    K.stars(img, (0, 0, IMG_W, 60), 30, 3601, big=2)
    K.moon(img, 80, 44, 14, halo=("night_d", "night"))
    cloud_bank(img, 40, ("night", "water_d", "ash"), 3602, x0=110, size=(6.0, 10.0), step=12)
    cloud_bank(img, 72, ("night_d", "night", "water_d"), 3603, size=(7.0, 12.0), step=14)
    # far below: the lake and its mountains, seen past the battlements
    K.peaks_layer(img, 120, [(40, 20, 50), (160, 26, 60), (270, 18, 50)], "night", "night_d", rim="water_d", seed=36)
    water_bands(img, (0, 120, IMG_W, 150), [("night_d", 0.0), ("night", 0.4), ("water_d", 0.75)], 3604,
                glints=("steel", "steel_l"), n_glints=24)
    cloud_bank(img, 152, ("night_d", "night", "ash"), 3605, size=(6.0, 9.0), step=10)
    # the platform: cool violet-grey flags with a sigil
    def platform(x: int, y: int) -> bool:
        return AX0 - 26 <= x < AX1 + 26 and AY0 - 22 <= y < AY1 + 22
    for y in range(150, IMG_H):
        for x in range(IMG_W):
            if not platform(x, y):
                img.set(x, y, "night_d" if y < 200 else "navy")
    for k, y in enumerate(range(186, IMG_H, 34)):
        cloud_bank(img, y, ("navy", "night_d", "night"), 3620 + k, size=(7.0, 12.0), step=12)
    cloud_bank(img, 300, ("navy", "night_d", "night"), 3607, x0=-10, x1=AX0 - 30, size=(8.0, 12.0), step=8)
    cloud_bank(img, 330, ("navy", "night_d", "night"), 3608, x0=AX1 + 30, size=(8.0, 12.0), step=8)
    K.flagstones(img, (AX0 - 26, AY0 - 22, AX1 + 26, AY1 + 22), ("ash", "ash"), "slate", 3609, worn="stone",
                 worn_rate=0.08, crack_rate=0.05)
    rune_ring(img, MIDX, (AY0 + AY1) // 2 + 4, 80, "dusk", "ash", ticks=12, width=1.2)
    K.calm_vignette(img, 12)
    # battlements round the platform (top row in front of the sky, low walls at the sides)
    img.blit(K.crenels(AX1 - AX0 + 52, 9, 6, 10, ("slate", "ash", "fog"), "navy"), AX0 - 26, AY0 - 34)
    wall = K.masonry(AX1 - AX0 + 52, 10, ("slate", "ash", "fog"), 3610, course=5, mortar="navy", base_dark=0)
    img.blit(wall, AX0 - 26, AY0 - 24)
    K.edge_shadow(img, AY0 - 14, 6, AX0 - 26, AX1 + 26)
    for side_x in (AX0 - 26, AX1 + 18):
        for y in range(AY0 - 24, AY1 + 22):
            for x in range(side_x, side_x + 8):
                img.set(x, y, "fog" if x == side_x and side_x < MIDX else ("ash" if (y // 6) % 2 else "slate"))
            img.set(side_x - 1, y, "navy")
            img.set(side_x + 8, y, "navy")
    img.blit(K.crenels(AX1 - AX0 + 52, 9, 6, 8, ("slate", "ash", "fog"), "navy"), AX0 - 26, AY1 + 14)
    for x in range(AX0 - 26, AX1 + 26):
        for y in range(AY1 + 24, AY1 + 40):
            img.set(x, y, "slate" if y < AY1 + 30 else "navy")
    for i, (x, y) in enumerate(((AX0 - 24, AY0 - 18), (AX1 + 14, AY0 - 18), (AX0 - 24, AY1 + 2), (AX1 + 14, AY1 + 2))):
        sc.anim("brazier", x, y, i, 1.0)
    for i, x in enumerate((AX0 + 20, AX1 - 32)):
        sc.anim("flag_morgana", x, AY0 - 36, i, 1.2)
    for i, (x, y) in enumerate(((150, 20), (240, 30), (30, 90))):
        sc.anim("glint_star", x, y, i * 3, 0.5)
    fgc = Canvas(IMG_W, 110)
    for k, y in enumerate((40, 70, 100)):
        cloud_bank(fgc, y, ("navy", "night_d", "night"), 3630 + k, size=(9.0, 14.0), step=14)
    sc.put_fg(fgc, 0, 402)
    sc.lightning = True
    sc.light("sun", 18, 44, 1.0, tint=(0.6, 0.65, 1.0))
    sc.particle(kind="mist", amount=16, lifetime=6.0, rect=(-60, -80, 280, 400), velocity=(1, 0.1), spread=8,
                speed=(14, 22), gravity=(0, 0), colour_fade=True)
    sc.particle(glow=True, kind="spark_violet", amount=10, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(2, 5), gravity=(0, 0), blink=True)
    sc.particle(kind="ember", amount=6, lifetime=2.0, rect=(0, 50, 180, 260), velocity=(0.3, -1), spread=40,
                speed=(8, 14), gravity=(0, -2), colour_fade=True)
    sc.modulate = (0.92, 0.92, 1.0)
    return sc


SCENES = {
    "castle_town": scene_castle_town,
    "castle_courtyard": scene_castle_courtyard,
    "royal_library": scene_royal_library,
    "castle_wall": scene_castle_wall,
    "magic_garden": scene_magic_garden,
    "green_chapel": scene_green_chapel,
    "misty_lake": scene_misty_lake,
    "fairy_forest": scene_fairy_forest,
    "stone_circle": scene_stone_circle,
    "crystal_cave": scene_crystal_cave,
    "morgana_tower": scene_morgana_tower,
    "tower_top": scene_tower_top,
}


def write_all(names: list[str] | None = None, preview_dir: str | None = None) -> None:
    K.write_shared()
    for name, fn in SCENES.items():
        if names and name not in names:
            continue
        sc = fn()
        K.write_scene(name, sc)
        if preview_dir:
            preview(name, sc, preview_dir)


def preview(name: str, sc: Scene26, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    full = sc.img.copy()
    full.blit(sc.fg, 0, 0)
    full.scaled(2).save(os.path.join(out_dir, "%s_full.png" % name))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:]]
    pdir = None
    if "--preview" in args:
        i = args.index("--preview")
        pdir = args[i + 1]
        del args[i:i + 2]
    write_all(args or None, pdir)
    print("v2.6 world written")
