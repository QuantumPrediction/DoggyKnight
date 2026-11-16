"""Storybook illustrations (v2.3 CS3): assets/story/<id>.png, 160x120, opaque.

One storybook style for all eight pages (docs/STORY.md section 4): limited palette, ordered-dither
gradients for skies and light, ink outlines on the subjects, a soft darkened rim like a printed page.
The characters are the game's own sprites (1x) so the pictures and the game feel like one world;
the queue of proud dog knights is made by recolouring Goldie's and the bulldog's sprites.
"""

from __future__ import annotations

import math
import random

import art_cast
import art_enemies
import art_heroes
import art_world as AW
import paint as P
from palette import rgba
from pixel import Canvas, res_path

W, H = 160, 120
IDS = ["prologue_1", "prologue_2", "prologue_3", "prologue_4", "ending_1", "ending_2", "ending_3", "teaser_1"]


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def page(base: str = "sky") -> Canvas:
    return Canvas(W, H, rgba(base))


def stars(c: Canvas, n: int, seed: int, rect=(0, 0, W, 60), cols=("white", "lilac", "sky_l")) -> None:
    rng = random.Random(seed)
    x0, y0, x1, y1 = rect
    for i in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        if i % 7 == 0:
            P.star4(c, x, y, cols[1], 1, cols[0])
        else:
            c.set(x, y, cols[i % len(cols)])


def full_moon(c: Canvas, cx: float, cy: float, r: float) -> set:
    moon = P.ellipse(cx, cy, r, r)
    for (x, y) in moon:
        d = math.hypot(x + 0.5 - (cx - r * 0.25), y + 0.5 - (cy - r * 0.25)) / (r * 1.3)
        c.set(x, y, P.pick(["lilac", "white", "white"], 1.0 - d, x, y, 1.8))
    for (x, y, rr) in ((cx + r * 0.3, cy + r * 0.2, r * 0.22), (cx - r * 0.35, cy + r * 0.35, r * 0.14),
                       (cx + r * 0.1, cy - r * 0.4, r * 0.12)):
        for (px, py) in P.ellipse(x, y, rr, rr) & moon:
            c.set(px, py, "lilac")
    # halo
    for (x, y) in P.ellipse(cx, cy, r + 4, r + 4) - moon:
        if (x + y) % 2 == 0:
            P.darken(c, x, y, -1)
    return moon


def vignette(c: Canvas, depth: int = 10, density: float = 0.55) -> None:
    """Soft darkened rim, like the edge of a printed page."""
    for y in range(H):
        for x in range(W):
            d = min(x, W - 1 - x, y, H - 1 - y)
            if d < depth and (1 - d / depth) ** 1.5 * density > P.bayer(x, y):
                P.darken(c, x, y, 1)


def light_beam(c: Canvas, pts: list[tuple[float, float]], strength: float = 0.5) -> None:
    for (x, y) in P.poly(pts):
        if 0 <= x < W and 0 <= y < H and strength > P.bayer(x, y):
            P.darken(c, x, y, -1)


def recolor(src: Canvas, mapping: dict[str, str]) -> Canvas:
    out = src.copy()
    for y in range(out.h):
        for x in range(out.w):
            n = P.name_at(out, x, y)
            if n in mapping:
                out.set(x, y, mapping[n])
    return out


def sweat(c: Canvas, x: int, y: int) -> None:
    c.stamp(["..o.", ".oso", "osso", ".oo."], x, y, {"o": "ink", "s": "sky_l"}, outline=None)


def glow(c: Canvas, cx: float, cy: float, r: float, col: str = "yellow", strength: float = 0.7) -> None:
    """Painted light: lighten pixels around a point with a dithered falloff."""
    for (x, y) in P.ellipse(cx, cy, r, r):
        d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
        if (1 - d) * strength > P.bayer(x, y):
            P.darken(c, x, y, -1)


def ground(c: Canvas, y0: int, ramp, seed: int, wave: float = 2.0, freq: float = 0.05) -> None:
    for x in range(W):
        top = y0 + int(wave * math.sin(x * freq + seed))
        for y in range(top, H):
            c.set(x, y, P.pick(ramp, (y - top) / max(1, H - top), x, y, 1.5))
        c.set(x, top, ramp[0] if len(ramp) > 3 else ramp[-1])


def tufts(c: Canvas, rect, n: int, seed: int, cols=("leaf_l", "leaf_d")) -> None:
    rng = random.Random(seed)
    x0, y0, x1, y1 = rect
    for _ in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        c.set(x, y, cols[0])
        c.set(x + 1, y - 1, cols[0])
        c.set(x - 1, y - 1, cols[1])


def flowers(c: Canvas, rect, n: int, seed: int, cols=("white", "pink", "yellow", "lilac")) -> None:
    rng = random.Random(seed)
    x0, y0, x1, y1 = rect
    for i in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        col = cols[i % len(cols)]
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.set(x + dx, y + dy, col)
        c.set(x, y, "yellow" if col != "yellow" else "orange")


def frame_of(anims, name: str, i: int = 0) -> Canvas:
    for a in anims:
        if a.name == name:
            return a.frames[i]
    raise KeyError(name)


def big_sword(c: Canvas, x: int, y: int, blade: int, glow_on: bool = True, horizontal: bool = False) -> None:
    """A detailed longsword with its pommel at (x, y), blade pointing down (or right)."""
    s = Canvas(W, H)
    def put(px, py, col):
        if horizontal:
            s.set(x + py, y + px, col)
        else:
            s.set(x + px, y + py, col)
    for (dx, dy, col) in ((0, 0, "yellow"), (1, 0, "gold"), (-1, 1, "gold"), (0, 1, "red"), (1, 1, "red_d"),
                          (2, 1, "gold_d"), (0, 2, "gold"), (1, 2, "gold_d")):
        put(dx, dy, col)
    for k in range(3, 8):
        put(0, k, "brown" if k % 2 else "brown_d")
        put(1, k, "brown_d")
    for k in range(-5, 7):
        put(k, 8, "yellow" if k < 3 else "gold")
        put(k, 9, "gold_d")
    for k in range(10, 10 + blade):
        put(0, k, "white" if k < 10 + blade * 0.5 else "steel_l")
        put(1, k, "steel_l" if k < 10 + blade * 0.3 else "steel")
    put(0, 10 + blade, "steel_l")
    s.outline_all()
    c.blit(s, 0, 0)


# --------------------------------------------------------------------------
# 1. prologue_1: Camelot at night, the empty throne, the crown on a velvet cushion
# --------------------------------------------------------------------------

def prologue_1() -> Canvas:
    c = page("night_d")
    # stone wall with bricks
    P.vgrad(c, 0, 0, W, 84, ["night_d", "night_d", "night", "night"], sharp=1.2)
    for y in range(84):
        for x in range(W):
            off = 6 if (y // 7) % 2 else 0
            if y % 7 == 6 or (x + off) % 12 == 11:
                P.darken(c, x, y, 1)
    # arched window with the night sky and a crescent moon
    win = P.rect(62, 22, 36, 44) | P.ellipse(80, 22, 18, 16)
    for (x, y) in win:
        c.set(x, y, P.pick(["night_d", "night", "water_d"], (y - 6) / 60, x, y, 1.5))
    stars(c, 16, 3, (63, 8, 97, 50))
    moon = P.ellipse(90, 18, 5, 5) - P.ellipse(92, 16, 4.5, 4.5)
    P.fill(c, moon, "white")
    frame = set()
    for (x, y) in win:
        if any((x + dx, y + dy) not in win for dx, dy in ((2, 0), (-2, 0), (0, -2))):
            frame.add((x, y))
    frame |= P.rect(79, 6, 2, 60) | P.rect(62, 36, 36, 2)
    P.fill(c, frame & win, "stone_d")
    P.fill(c, {(x, y) for (x, y) in frame & win if (x + y) % 3 == 0}, "stone")
    P.outline_shape(c, win, "ink")
    sill = P.rect(58, 66, 44, 4)
    P.shade_shape(c, sill, ["stone_d", "stone", "stone_l"])
    P.outline_shape(c, sill, "ink")
    # banners
    for bx in (16, 128):
        cloth = P.poly([(bx, 10), (bx + 16, 10), (bx + 16, 50), (bx + 8, 44), (bx, 50)])
        P.shade_shape(c, cloth, ["night", "water_d", "water", "sky"], bias=-0.1)
        P.fill(c, P.edge(cloth) - P.rect(bx, 10, 17, 1), "gold")
        for (dx, dy) in ((8, 22), (6, 20), (10, 20), (5, 24), (11, 24), (7, 26), (8, 26), (9, 26), (8, 25), (7, 25), (9, 25)):
            c.set(bx + dx, dy, "yellow")
        for x in range(bx - 2, bx + 19):
            c.set(x, 9, "brown")
        P.outline_shape(c, cloth, "ink")
    # floor: checkered tiles in perspective
    for y in range(84, H):
        t = (y - 84) / (H - 84)
        for x in range(W):
            u = (x - 80) / (0.6 + t * 1.6)
            v = int(math.log(1 + (y - 83) * 0.35) * 4)
            dark = (int(math.floor(u / 10)) + v) % 2 == 0
            c.set(x, y, ("iron" if dark else "steel_d") if t > 0.08 or (x + y) % 2 else "iron")
    for x in range(W):
        c.set(x, 84, "ink")
    # red carpet up to the throne
    carpet = P.poly([(68, 84), (92, 84), (122, H), (38, H)])
    for (x, y) in carpet:
        c.set(x, y, P.pick(["red_d", "red"], 0.3 + (y - 84) / 80, x, y, 1.3))
    for (x, y) in P.edge(carpet):
        if y > 84:
            c.set(x, y, "gold")
    # moonbeam from the window across the floor and the throne
    light_beam(c, [(64, 66), (96, 66), (126, H), (58, H)], 0.45)
    # the throne
    back = P.poly([(66, 86), (66, 42), (72, 34), (80, 28), (88, 34), (94, 42), (94, 86)])
    P.shade_shape(c, back, ["brown_d", "gold_d", "gold", "gold_l"], bias=-0.05)
    velvet = P.poly([(70, 78), (70, 44), (80, 35), (90, 44), (90, 78)])
    P.shade_shape(c, velvet, ["plum", "red_d", "red", "pink"], bias=-0.05)
    for (x, y) in ((80, 24), (80, 25), (79, 26), (81, 26), (80, 27)):
        c.set(x, y, "yellow")
    P.outline_shape(c, back, "ink")
    seat = P.rect(62, 76, 36, 6)
    P.shade_shape(c, seat, ["brown_d", "gold_d", "gold", "gold_l"])
    P.outline_shape(c, seat, "ink")
    for ax in (58, 96):
        arm = P.rect(ax, 66, 6, 22)
        P.shade_shape(c, arm, ["brown_d", "gold_d", "gold", "yellow"])
        P.outline_shape(c, arm, "ink")
    legs = P.rect(64, 82, 4, 8) | P.rect(92, 82, 4, 8)
    P.fill(c, legs, "brown_d")
    # velvet cushion with tassels, and the crown
    cushion = P.ellipse(80, 73, 12, 4.5)
    P.shade_shape(c, cushion, ["plum", "red_d", "red", "pink"], bias=0.05)
    P.outline_shape(c, cushion, "ink")
    for tx in (68, 92):
        c.set(tx, 76, "yellow")
        c.set(tx, 77, "gold")
    crown = P.poly([(71, 70), (71, 61), (74, 65), (77, 59), (80, 64), (83, 59), (86, 65), (89, 61), (89, 70)])
    P.shade_shape(c, crown, ["gold_d", "gold", "yellow", "white"], bias=0.1)
    P.outline_shape(c, crown, "ink")
    for (x, y, col) in ((75, 67, "red"), (80, 67, "water"), (85, 67, "red"), (77, 59, "white"), (83, 59, "white")):
        c.set(x, y, col)
    P.star4(c, 88, 58, "white", 2, "white")
    # candles with warm light
    for cx in (40, 120):
        P.fill(c, P.rect(cx - 1, 62, 3, 22), "gold_d")
        P.fill(c, P.rect(cx - 3, 82, 7, 2), "gold_d")
        P.fill(c, P.rect(cx - 1, 56, 3, 6), "cream")
        glow(c, cx, 52, 14, strength=0.6)
        c.set(cx, 53, "yellow")
        c.set(cx, 52, "orange")
        c.set(cx, 54, "white")
    vignette(c)
    return c


# --------------------------------------------------------------------------
# 2. prologue_2: morning light, the great stone on the hill, the sword glowing
# --------------------------------------------------------------------------

def prologue_2() -> Canvas:
    c = page("sky")
    P.vgrad(c, 0, 0, W, 80, ["sky", "sky", "sky_l", "cream", "peach"], sharp=1.3)
    # the sun rising behind the hill, with soft rays
    for y in range(80):
        for x in range(W):
            a = math.atan2(y - 74, x - 80)
            if int((a + math.pi) / (2 * math.pi) * 22) % 2 == 0 and (x + y) % 2 == 0:
                P.darken(c, x, y, -1)
    glow(c, 80, 64, 34, "yellow", 0.8)
    for (x, y) in P.ellipse(80, 64, 14, 14):
        d = math.hypot(x + 0.5 - 80, y + 0.5 - 64) / 14
        c.set(x, y, P.pick(["yellow", "cream", "white"], 1.1 - d, x, y, 1.8))
    # distant hills
    for x in range(W):
        top = 70 + int(4 * math.sin(x * 0.07 + 1.5) + 2 * math.sin(x * 0.19))
        for y in range(top, H):
            c.set(x, y, P.pick(["moss", "leaf_d"], (y - top) / 12, x, y))
    # the big hill
    for x in range(W):
        top = 72 + int(0.0025 * (x - 80) ** 2 * 3.2)
        for y in range(top, H):
            t = (y - top) / 30 + abs(x - 80) / 220
            c.set(x, y, P.pick(["leaf_l", "leaf", "leaf_d", "forest"], t, x, y, 1.6))
    tufts(c, (0, 84, W, H), 60, 3)
    flowers(c, (6, 92, 154, 116), 18, 4)
    # the stone and the sword (from the 1-1 background, at the same scale)
    stone = AW.sword_in_stone()
    c.blit(stone, 54, 30)
    # the sword's glow
    glow(c, 80, 40, 14, "yellow", 0.8)
    for (x, y) in ((70, 32), (90, 30), (86, 42), (73, 44), (80, 26)):
        P.star4(c, x, y, "yellow", 1, "white")
    c.blit(stone, 54, 30)
    for (x, y) in ((66, 28), (94, 36), (60, 40)):
        P.star4(c, x, y, "white", 1, "white")
    # morning mist
    for y in range(86, 98):
        for x in range(W):
            if (0.28 - abs(y - 92) / 18) > P.bayer(x, y) and math.sin(x * 0.08 + y * 0.3) > 0.0:
                c.set(x, y, "white" if (x + y) % 3 else "sky_l")
    # birds
    for (bx, by) in ((24, 18), (32, 24), (128, 14)):
        for (dx, dy) in ((-2, -1), (-1, 0), (1, 0), (2, -1)):
            c.set(bx + dx, by + dy, "night")
        c.set(bx, by + 1, "night")
    vignette(c)
    return c


# --------------------------------------------------------------------------
# 3. prologue_3: proud dog knights queue to pull the sword, all of them sweating
# --------------------------------------------------------------------------

KNIGHT_COLOURS = {
    "dalmatian": {"gold_l": "white", "gold": "stone_l", "gold_d": "stone", "cream": "white", "red": "water",
                  "red_d": "water_d", "pink": "pink"},
    "chocolate": {"gold_l": "gold_d", "gold": "brown", "gold_d": "brown_d", "cream": "dirt", "red": "leaf",
                  "red_d": "leaf_d"},
    "schnauzer": {"gold_l": "steel_l", "gold": "steel", "gold_d": "steel_d", "cream": "white", "red": "violet",
                  "red_d": "plum", "steel_l": "gold_l", "steel": "gold", "steel_d": "gold_d"},
    "sable": {"gold_l": "peach", "gold": "orange", "gold_d": "brown", "cream": "cream", "red": "night",
              "red_d": "night_d"},
}


def spotted(src: Canvas, seed: int) -> Canvas:
    out = src.copy()
    rng = random.Random(seed)
    for y in range(out.h):
        for x in range(out.w):
            if P.name_at(out, x, y) in ("white", "stone_l") and rng.random() < 0.12:
                out.set(x, y, "ink")
    return out


def prologue_3() -> Canvas:
    c = page("sky")
    P.vgrad(c, 0, 0, W, 70, ["sky", "sky", "sky_l"], sharp=1.3)
    for (x, y, w) in ((20, 14, 26), (112, 22, 34)):
        cl = __import__("art_brand").cloud(w, 10, x)
        c.blit(cl, x, y)
    # pennant string across the top
    for x in range(W):
        y = 6 + int(5 * math.sin(x / W * math.pi))
        c.set(x, y, "brown_d")
        if x % 12 == 4:
            col = ["red", "yellow", "water", "leaf"][(x // 12) % 4]
            c.stamp(["ccc", "cc", "c"], x, y + 1, {"c": col}, outline=None)
    ground(c, 72, ["leaf", "leaf", "leaf_d", "forest"], 1, wave=1.5)
    tufts(c, (0, 76, W, H), 50, 5)
    flowers(c, (0, 100, W, 118), 10, 6)
    # the stone (left)
    stone = AW.sword_in_stone()
    c.blit(stone, 2, 44)
    # the one pulling: a proud dalmatian in golden armour, leaning back, both paws on the hilt
    pull = art_heroes.goldie_pose(0, lean=-1, sword=None, arm=(16, 12),
                                  legs=[((7, 19), art_heroes.G_LEG_FAR), ((13, 19), art_heroes.G_LEG_NEAR)],
                                  head=art_heroes.G_HEAD_HURT)
    pull = spotted(recolor(pull, KNIGHT_COLOURS["dalmatian"] | {"steel_l": "gold_l", "steel": "gold", "steel_d": "gold_d"}), 3)
    c.blit(pull.flipped(), 30, 52)
    for (x, y) in ((30, 52), (52, 50)):
        sweat(c, x, y)
    for (x0, y0, x1, y1) in ((26, 44, 22, 41), (28, 41, 26, 37), (31, 40, 31, 36)):
        c.line(x0, y0, x1, y1, "ink")
    # the queue of knights, waiting and sweating
    gold = art_heroes.goldie_v2()
    bull = art_heroes.bulldog_v2()
    queue = [
        (recolor(frame_of(gold, "idle", 0), KNIGHT_COLOURS["chocolate"]), 62, 70),
        (recolor(frame_of(bull, "idle", 2), {"white": "peach", "stone_l": "dirt", "sky": "red", "water": "red_d",
                                             "water_d": "plum"}), 84, 72),
        (recolor(frame_of(gold, "hurt", 0), KNIGHT_COLOURS["schnauzer"]), 104, 70),
        (recolor(frame_of(gold, "idle", 2), KNIGHT_COLOURS["sable"]), 124, 71),
        (spotted(recolor(frame_of(gold, "idle", 3), KNIGHT_COLOURS["dalmatian"]), 9), 142, 70),
    ]
    for img, x, y in queue:
        c.blit(img.flipped(), x, y)
    for (x, y) in ((70, 66), (108, 64), (128, 67)):
        sweat(c, x, y)
    # a tired knight sitting in the grass, mopping his brow
    sit = recolor(frame_of(gold, "sleep", 0), KNIGHT_COLOURS["chocolate"])
    c.blit(sit.flipped(), 56, 94)
    sweat(c, 58, 96)
    vignette(c)
    return c


# --------------------------------------------------------------------------
# 4. prologue_4: a stick sails across the sky; far away a golden retriever comes running
# --------------------------------------------------------------------------

def prologue_4() -> Canvas:
    c = page("sky")
    P.vgrad(c, 0, 0, W, 86, ["water", "sky", "sky", "sky_l"], sharp=1.3)
    import art_brand
    for (x, y, w) in ((8, 30, 30), (96, 8, 40), (124, 46, 26)):
        c.blit(art_brand.cloud(w, 11, x + y), x, y)
    # rolling meadow
    for x in range(W):
        top = 84 - int(10 * math.exp(-((x - 132) / 26) ** 2)) + int(1.5 * math.sin(x * 0.11))
        for y in range(top, H):
            c.set(x, y, P.pick(["leaf_l", "leaf", "leaf_d", "forest"], (y - top) / 34, x, y, 1.5))
    tufts(c, (0, 86, W, H), 50, 7)
    flowers(c, (0, 96, W, 118), 16, 8)
    # the stone far away on the knoll (small)
    stone = AW.sword_in_stone()
    small = Canvas(26, 24)
    for y in range(24):
        for x in range(26):
            small.set(x, y, stone.get(x * 2, y * 2))
    c.blit(small, 120, 51)
    # the stick's path: a dotted arc from the left edge
    pts = [(t, 0.0) for t in range(0, 101, 4)]
    for (t, _) in pts:
        u = t / 100
        x = int(-4 + u * 104)
        y = int(60 - 52 * math.sin(u * math.pi * 0.9))
        if t % 8 == 0 and u < 0.86:
            c.set(x, y, "white")
            c.set(x + 1, y, "sky_l")
    # the stick itself, spinning (with motion lines)
    stick = Canvas(30, 30)
    for (x, y) in P.thick_line(4, 22, 25, 7, 1.2):
        stick.set(x, y, "brown")
    for (x, y) in P.thick_line(5, 21, 24, 7, 0.5):
        stick.set(x, y, "gold_d")
    for (x, y) in P.thick_line(15, 15, 18, 22, 0.8):
        stick.set(x, y, "brown")
    for (x, y) in P.ellipse(19, 24, 3, 2):
        stick.set(x, y, "leaf")
    stick.set(18, 23, "leaf_l")
    stick.outline_all()
    c.blit(stick, 86, 4)
    for (x0, y0, x1, y1) in ((80, 16, 70, 20), (82, 24, 74, 28), (88, 32, 80, 36)):
        c.line(x0, y0, x1, y1, "white")
    # Goldie running in from far away, tongue out
    gold = art_heroes.goldie_v2()
    run = frame_of(gold, "run", 1)
    c.blit(run, 18, 88)
    c.stamp([".o.", "ooo", ".o."][0:0], 0, 0, {})
    for (x, y) in ((14, 104), (10, 106), (12, 101)):
        c.set(x, y, "stone_l")
        c.set(x - 1, y, "white")
    c.stamp(["oo", "oo", "oo", "..", "oo"], 36, 80, {"o": "red"}, outline="ink")
    vignette(c)
    return c


# --------------------------------------------------------------------------
# 5. ending_1: the black armour scattered on the bridge; a purple flame drifts from the helmet
# --------------------------------------------------------------------------

def ending_1() -> Canvas:
    c = page("night_d")
    P.vgrad(c, 0, 0, W, 50, ["ink", "night_d", "night", "dusk"], sharp=1.3)
    stars(c, 24, 11, (0, 0, W, 30))
    # castle silhouette at the far end of the bridge
    castle = P.rect(54, 22, 52, 28) | P.rect(48, 12, 12, 38) | P.rect(100, 12, 12, 38) | P.rect(74, 6, 12, 44)
    for bx in range(48, 112, 4):
        castle -= {(bx, 12), (bx + 1, 12)}
    P.fill(c, castle, "night_d")
    for (x, y) in ((52, 20), (104, 20), (79, 14), (64, 32), (94, 32)):
        P.fill(c, P.rect(x, y, 2, 3), "yellow")
        glow(c, x + 1, y + 1, 4, strength=0.5)
    gate = P.rect(72, 34, 16, 16) | P.ellipse(80, 34, 8, 6)
    P.fill(c, gate, "ink")
    # the bridge deck in perspective
    deck = P.poly([(60, 50), (100, 50), (176, H), (-16, H)])
    for (x, y) in deck:
        t = (y - 50) / 70
        row = int(math.log(1 + (y - 49) * 0.4) * 6)
        off = (row % 2) * 0.5
        u = (x - 80) / (1 + t * 7)
        brick = (int(math.floor(u / 2.2 + off)) + row) % 3
        col = ["stone_d", "stone", "stone_d"][brick]
        if math.log(1 + (y - 48) * 0.4) * 6 % 1 < 0.18:
            col = "iron"
        c.set(x, y, col)
    # parapets
    for side in (-1, 1):
        wall = P.poly([(80 + side * 20, 46), (80 + side * 22, 46), (80 + side * 104, H), (80 + side * 86, H)])
        P.shade_shape(c, wall, ["iron", "stone_d", "stone"], bias=-0.1 * side)
        P.outline_shape(c, wall, "ink")
    # puddles reflecting the violet light
    for (px, py, rx, ry) in ((38, 104, 14, 3), (124, 98, 10, 2.5), (98, 112, 12, 3)):
        for (x, y) in P.ellipse(px, py, rx, ry):
            c.set(x, y, "night" if (x + y) % 2 else "water_d")
        P.fill(c, P.rect(px - 4, py, 6, 1) & P.ellipse(px, py, rx, ry), "lilac")
    # torches on the parapets
    for (tx, ty) in ((22, 74), (138, 74)):
        P.fill(c, P.rect(tx, ty, 2, 8), "brown_d")
        glow(c, tx + 1, ty - 2, 12, strength=0.65)
        c.set(tx, ty - 2, "yellow")
        c.set(tx + 1, ty - 2, "orange")
        c.set(tx, ty - 3, "orange")
        c.set(tx + 1, ty - 1, "white")
    # the scattered armour (the black knight's 'down' frame plus loose pieces)
    knight = art_enemies.black_knight_v2()
    down = frame_of(knight, "down", 1)
    c.blit(down, 52, 62)
    helm = Canvas(20, 18)
    hs = P.poly([(3, 16), (2, 6), (6, 2), (10, 1), (14, 2), (18, 6), (17, 16)])
    P.shade_shape(helm, hs, ["ink", "night_d", "iron", "steel_d"], bias=-0.05)
    for x in range(3, 18):
        helm.set(x, 8, "ink")
    for x in (6, 7, 12, 13):
        helm.set(x, 8, "violet")
    for y in range(2, 16):
        helm.set(10, y, "steel_d")
    helm.outline_all()
    c.blit(helm, 96, 88)
    gaunt = Canvas(12, 8)
    P.shade_shape(gaunt, P.ellipse(6, 4, 5, 3), ["ink", "iron", "steel_d", "steel"])
    gaunt.outline_all()
    c.blit(gaunt, 30, 90)
    big_sword(c, 112, 104, 26, horizontal=True)
    # the purple flame leaving the helmet, curling up into the sky
    path = [(106, 86), (108, 78), (104, 70), (110, 62), (118, 56), (124, 46), (132, 40), (138, 30)]
    for i, (x, y) in enumerate(path):
        r = max(1.0, 4.5 - i * 0.5)
        glow(c, x, y, r + 5, strength=0.55)
        blob = P.ellipse(x, y, r, r * 1.2)
        for (px, py) in blob:
            c.set(px, py, P.pick(["violet", "lilac", "white"], 1 - math.hypot(px - x, py - y) / (r + 0.5), px, py, 2))
    for (x, y) in ((116, 64), (100, 74), (128, 50), (142, 24), (134, 34)):
        P.star4(c, x, y, "lilac", 1, "white")
    vignette(c)
    return c


# --------------------------------------------------------------------------
# 6. ending_2: a fox silhouette on the castle wall under the moon, purple eyes glowing
# --------------------------------------------------------------------------

def ending_2() -> Canvas:
    c = page("night_d")
    P.vgrad(c, 0, 0, W, H, ["ink", "night_d", "night", "dusk"], sharp=1.2)
    stars(c, 40, 21, (0, 0, W, 80))
    moon = full_moon(c, 98, 44, 30)
    # thin clouds crossing the moon
    for (y0, x0, x1) in ((54, 64, 140), (30, 82, 150), (64, 40, 104)):
        for x in range(x0, x1):
            y = y0 + int(1.5 * math.sin(x * 0.2))
            for yy in (y, y + 1):
                c.set(x, yy, "dusk" if (x, yy) not in moon else "lilac")
            if (x + y0) % 3 == 0:
                c.set(x, y + 2, "plum" if (x, y + 2) not in moon else "violet")
    # castle wall with battlements, a tower with a warm window on the left
    wall = P.rect(0, 92, W, 28)
    for bx in range(0, W, 12):
        wall |= P.rect(bx, 86, 7, 6)
    tower = P.rect(4, 40, 30, 80) | P.poly([(2, 40), (19, 20), (36, 40)])
    sil = wall | tower
    for (x, y) in sil:
        brick = y % 6 == 5 or (x + (6 if (y // 6) % 2 else 0)) % 12 == 11
        c.set(x, y, "ink" if brick else "night_d")
    for (x, y) in P.edge(sil):
        if (x + 1, y) not in sil or (x, y - 1) not in sil:
            c.set(x, y, "night")
    P.fill(c, P.rect(16, 58, 6, 9) | P.ellipse(19, 58, 3, 3), "yellow")
    P.fill(c, P.rect(19, 56, 1, 11), "gold_d")
    glow(c, 19, 62, 12, strength=0.45)
    # the fox: sitting on the wall in front of the moon, cape flowing, tail curled round its paws
    fox = set()
    fox |= P.poly([(92, 62), (104, 62), (108, 86), (86, 86)])                 # body / chest
    fox |= P.ellipse(99, 56, 5.5, 5)                                           # head
    fox |= P.poly([(102, 54), (113, 58), (112, 60), (102, 60)])                # long snout
    fox |= P.poly([(95, 53), (93, 41), (100, 51)])                             # ears
    fox |= P.poly([(100, 52), (103, 40), (105, 53)])
    fox |= P.poly([(92, 62), (78, 70), (70, 86), (90, 86)])                    # cape flowing back
    fox |= P.poly([(104, 84), (118, 82), (124, 77), (126, 83), (118, 88), (100, 88)])  # tail round the paws
    fox |= P.ellipse(124, 80, 4, 4)
    for (x, y) in fox:
        c.set(x, y, "ink")
    P.rim(c, fox, "plum", (1, -1))
    P.rim(c, fox, "dusk", (0, -1))
    for (x, y) in ((124, 77), (125, 78), (126, 79)):
        c.set(x, y, "violet")
    staff = P.rect(84, 50, 2, 38)
    P.fill(c, staff, "ink")
    cres = P.ellipse(85, 45, 5, 5) - P.ellipse(87, 43, 4.2, 4.2)
    P.fill(c, cres, "lilac")
    P.rim(c, cres, "white", (-1, 0))
    glow(c, 102.5, 55, 7, "lilac", 0.7)
    for (x, y) in ((100, 55), (101, 54), (102, 54), (103, 54), (104, 55), (101, 56), (102, 56), (103, 56)):
        c.set(x, y, "pink")
    for (x, y) in ((101, 55), (102, 55), (103, 55)):
        c.set(x, y, "white")
    for (x, y) in ((118, 40), (122, 54), (90, 40)):
        P.star4(c, x, y, "lilac", 1, "white")
    vignette(c, density=0.7)
    return c


# --------------------------------------------------------------------------
# 7. ending_3: Camelot's gate opens; the dogs cheer; Goldie, Bedivere and Merlin in front
# --------------------------------------------------------------------------

DOG_HEADS = [
    ([".o..o.", "oooooo", "oooooo", ".oooo."], ("gold", "gold_d")),
    (["o....o", "oo..oo", "oooooo", ".oooo."], ("white", "stone")),
    ([".oooo.", "oooooo", "oooooo", ".oooo."], ("brown", "brown_d")),
    (["oo..oo", "oooooo", "oooooo", ".oooo."], ("steel", "steel_d")),
    ([".o..o.", "oooooo", "oooooo", ".oooo."], ("peach", "dirt")),
]


def ending_3() -> Canvas:
    c = page("sky")
    P.vgrad(c, 0, 0, W, 60, ["sky", "sky_l", "cream"], sharp=1.3)
    # castle walls and towers
    wall = P.rect(0, 30, W, 50)
    for bx in range(0, W, 10):
        wall |= P.rect(bx, 25, 6, 5)
    P.shade_shape(c, wall, ["stone_d", "stone", "stone_l"], centre=(80, 20), radius=(120, 60))
    for y in range(30, 80, 6):
        for x in range(W):
            if y % 12 == 6 and (x + (y // 6) * 5) % 14 == 0:
                c.set(x, y + 2, "stone_d")
            c.set(x, y, "stone_d" if (x + y) % 3 else "stone")
    for tx in (14, 128):
        tw = P.rect(tx, 8, 18, 72)
        P.shade_shape(c, tw, ["stone_d", "stone", "stone_l", "white"], bias=0.05)
        roof = P.poly([(tx - 3, 9), (tx + 9, -8), (tx + 21, 9)])
        P.shade_shape(c, roof, ["water_d", "water", "sky"], bias=0.05)
        P.outline_shape(c, tw | roof, "ink")
        P.fill(c, P.rect(tx + 7, 24, 4, 7), "night")
        # pennant
        c.vline(tx + 9, -8, -1, "brown_d")
    for fx, col in ((23, "red"), (137, "red")):
        c.stamp(["rrrrr", "rrrr", "rrr"], fx, 0, {"r": col}, outline=None)
    # the open gate pouring light
    arch = P.rect(58, 34, 44, 46) | P.ellipse(80, 34, 22, 18)
    for (x, y) in arch:
        c.set(x, y, P.pick(["gold_l", "cream", "white"], 1 - abs(x - 80) / 30, x, y, 1.6))
    P.outline_shape(c, arch, "ink")
    stones = P.edge(P.rect(56, 32, 48, 50) | P.ellipse(80, 32, 24, 20)) - arch
    P.fill(c, stones, "stone_d")
    for side in (-1, 1):
        door = P.poly([(80 + side * 22, 36), (80 + side * 34, 30), (80 + side * 34, 84), (80 + side * 22, 80)])
        P.shade_shape(c, door, ["brown_d", "brown", "gold_d"], bias=-0.05)
        for k in range(3):
            c.line(80 + side * (24 + k * 4), 36, 80 + side * (24 + k * 4), 82, "brown_d")
        P.outline_shape(c, door, "ink")
    light_beam(c, [(62, 80), (98, 80), (124, H), (36, H)], 0.4)
    # road
    for y in range(80, H):
        for x in range(W):
            road = abs(x - 80) < 18 + (y - 80) * 0.9
            c.set(x, y, P.pick(["dirt", "peach"], 0.3 + (y - 80) / 60, x, y) if road else
                  P.pick(["leaf", "leaf_d"], (y - 80) / 40, x, y))
    light_beam(c, [(62, 80), (98, 80), (124, H), (36, H)], 0.3)
    # the crowd cheering on both sides: a back row of waving heads, then dog knights (recoloured sprites)
    rng = random.Random(5)
    for (xa, xb) in ((0, 54), (106, 160)):
        for x in range(xa, xb, 8):
            grid, (fur, dark) = DOG_HEADS[rng.randrange(len(DOG_HEADS))]
            y = 70 + rng.randrange(-2, 2)
            c.stamp(grid, x, y, {"o": fur}, outline="ink")
            c.set(x + 2, y + 2, "ink")
            c.set(x + 4, y + 2, "ink")
            c.set(x + 3, y + 3, dark)
            if rng.random() < 0.45:
                c.vline(x + 7, y - 6, y + 3, "brown_d")
                c.stamp(["fff", "ff"], x + 8, y - 6, {"f": ["yellow", "pink", "sky", "red"][rng.randrange(4)]},
                        outline=None)
    gold = art_heroes.goldie_v2()
    bull = art_heroes.bulldog_v2()
    palettes = list(KNIGHT_COLOURS.values()) + [{}]
    spots = [(-4, 74), (14, 76), (30, 80), (-6, 92), (12, 96), (118, 80), (134, 76), (150, 74), (124, 96), (142, 92)]
    for i, (x, y) in enumerate(spots):
        if i % 3 == 1:
            img = recolor(frame_of(bull, "victory", (i // 3) % 2 + 1),
                          {"white": ["peach", "white", "stone_l"][i % 3], "sky": ["red", "leaf", "orange"][i % 3],
                           "water": ["red_d", "leaf_d", "gold_d"][i % 3]})
        else:
            img = recolor(frame_of(gold, "victory", 1 + i % 2), palettes[i % len(palettes)])
            if i % 5 == 0:
                img = spotted(img, i)
        c.blit(img.flipped() if x > 80 else img, x, y)
    # confetti
    for i in range(70):
        x, y = rng.randrange(0, W), rng.randrange(0, 70)
        col = ["red", "yellow", "sky", "pink", "leaf_l", "lilac"][i % 6]
        c.set(x, y, col)
        if i % 2:
            c.set(x + 1, y, col)
    # the three heroes in front
    gold = art_heroes.goldie_v2()
    bull = art_heroes.bulldog_v2()
    mer = art_cast.merlin()
    c.blit(frame_of(bull, "victory", 1), 54, 92)
    c.blit(frame_of(gold, "victory", 1), 70, 90)
    c.blit(frame_of(mer, "cast", 1).flipped(), 88, 92)
    vignette(c, density=0.45)
    return c


# --------------------------------------------------------------------------
# 8. teaser_1: the round table, a ring of empty chairs, the sword on the table (chapter 2)
# --------------------------------------------------------------------------

def chair(back_h: int, front: bool = False) -> Canvas:
    """A tall knight's chair seen from the front (or from behind when `front`): pointed arch top,
    carved wooden frame, red velvet back."""
    ch = Canvas(16, back_h + 8)
    back = P.rect(2, 4, 12, back_h) | P.poly([(2, 5), (8, 0), (14, 5)])
    P.shade_shape(ch, back, ["brown_d", "brown", "gold_d", "gold"], bias=-0.05)
    pad = P.rect(4, 6, 8, back_h - 6) | P.poly([(4, 7), (8, 3), (12, 7)])
    P.shade_shape(ch, pad, ["plum", "red_d", "red"] if not front else ["plum", "red_d"], bias=-0.1)
    ch.set(8, 1, "yellow")
    seat_y = back_h + 3
    P.fill(ch, P.rect(1, seat_y, 14, 2), "gold_d")
    P.fill(ch, P.rect(2, seat_y + 2, 2, 3) | P.rect(12, seat_y + 2, 2, 3), "brown_d")
    ch.outline_all()
    return ch


def teaser_1() -> Canvas:
    c = page("ink")
    P.radial(c, 80, 60, 110, ["ink", "night_d", "plum", "dusk"], sharp=1.2)
    # stone pillars in the dark
    for px in (8, 140):
        pil = P.rect(px, 0, 12, H)
        P.shade_shape(c, pil, ["ink", "night_d", "plum"], bias=-0.05)
    # the light from above
    light_beam(c, [(62, 0), (98, 0), (142, 96), (18, 96)], 0.35)
    # chairs behind the table
    for i, ang in enumerate([200, 225, 250, 275, 300, 325, 350]):
        a = math.radians(ang)
        x = 80 + math.cos(a) * 60
        y = 72 + math.sin(a) * 22
        ch = chair(24 if 230 < ang < 320 else 20)
        c.blit(ch, int(x - 8), int(y - ch.h + 6))
    # the table: wooden top in perspective with grain rings
    top = P.ellipse(80, 76, 60, 20)
    for (x, y) in top:
        d = math.hypot((x + 0.5 - 80) / 60, (y + 0.5 - 76) / 20)
        ring = int(d * 9) % 2
        c.set(x, y, P.pick(["brown", "gold_d", "gold", "gold_l"], 0.85 - d * 0.6 - ring * 0.08, x, y, 1.6))
    rim = P.ellipse(80, 80, 60, 20) - top
    rim = {(x, y) for (x, y) in rim if y > 76}
    P.fill(c, rim, "brown_d")
    P.outline_shape(c, top | rim, "ink")
    # the sword lying on the table, shining
    glow(c, 80, 74, 20, "yellow", 0.6)
    big_sword(c, 58, 72, 36, horizontal=True)
    for (x, y) in ((104, 70), (72, 68), (92, 79), (60, 76)):
        P.star4(c, x, y, "white", 1, "white")
    P.star4(c, 108, 72, "yellow", 2, "white")
    # chairs in front (backs toward us)
    for ang in (20, 62, 118, 160):
        a = math.radians(ang)
        x = 80 + math.cos(a) * 70
        y = 84 + math.sin(a) * 26
        ch = chair(26, front=True)
        c.blit(ch, int(x - 8), int(y - 16))
    # dust motes in the light
    rng = random.Random(12)
    for _ in range(18):
        x, y = rng.randrange(40, 120), rng.randrange(4, 56)
        c.set(x, y, "gold_l" if rng.random() < 0.5 else "cream")
    vignette(c, density=0.7)
    return c


BUILDERS = {
    "prologue_1": prologue_1, "prologue_2": prologue_2, "prologue_3": prologue_3, "prologue_4": prologue_4,
    "ending_1": ending_1, "ending_2": ending_2, "ending_3": ending_3, "teaser_1": teaser_1,
}


def write_all() -> list[str]:
    out = []
    for sid in IDS:
        p = res_path("res://assets/story/%s.png" % sid)
        BUILDERS[sid]().save(p, opaque=True)
        out.append(p)
    return out


if __name__ == "__main__":
    import sys
    out_dir = sys.argv[1]
    which = sys.argv[2:] or IDS
    for sid in which:
        BUILDERS[sid]().scaled(4).save("%s/story_%s.png" % (out_dir, sid))
    print("ok")
