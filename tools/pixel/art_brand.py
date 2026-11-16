"""Title logo, app icons, store graphics and the boot splash (C13), all from one master design.

Master: a 32x32 pixel portrait of Goldie (ICON_HALF is the left half; it is mirrored),
over a sky background with sun rays. Everything is scaled by whole numbers, nearest
neighbour, never smoothed.

The logo glyphs below are the four characters 金毛騎士 as rendered by the Cubic 11 font
at its native 12 px size (SIL OFL 1.1, see docs/licenses.md); they are stored here as
pixel data so the generator needs no font library.
"""

from __future__ import annotations

import math

from palette import rgba
from pixel import Canvas, res_path

LOGO_GLYPHS = [
    [
        ".....###...",
        "....#...#..",
        "...#.....#.",
        "..#.#####.#",
        ".#....#....",
        "......#....",
        "..#########",
        "......#....",
        "..#...#...#",
        "...#..#..#.",
        ".##########",
    ],
    [
        ".......###.",
        "..#####....",
        ".....#...##",
        ".....####..",
        "..####.....",
        ".....#....#",
        ".....#####.",
        ".#####.....",
        ".....#.....",
        ".....#.....",
        "......#####",
    ],
    [
        ".####...#..",
        ".#.#.######",
        ".####..#.#.",
        ".#.#..#...#",
        ".#####.....",
        ".#.#.######",
        ".####......",
        "....#.###..",
        ".##.#.#.#..",
        "....#.###..",
        "..##......#",
    ],
    [
        "......#....",
        "......#....",
        "......#....",
        ".##########",
        "......#....",
        "......#....",
        "......#....",
        "......#....",
        "......#....",
        "......#....",
        "..#########",
    ],
]


def _fix_glyphs() -> list[list[str]]:
    """The raw font rows above were trimmed to 11 columns; re-pad them from the font dump."""
    return LOGO_GLYPHS


def logo(scale: int = 2) -> Canvas:
    """金毛騎士 in chunky gold letters with a dark outline and a soft shadow."""
    glyphs = _fix_glyphs()
    gw = 11 * scale
    gap = 2 * scale
    w = len(glyphs) * gw + (len(glyphs) - 1) * gap
    h = 11 * scale
    pad = 3
    fill = Canvas(w + pad * 2, h + pad * 2)
    rows_cols = ["yellow", "yellow", "yellow", "yellow", "gold_l", "gold_l", "gold_l", "gold", "gold", "gold", "gold"]
    for gi, g in enumerate(glyphs):
        for y, row in enumerate(g):
            for x, ch in enumerate(row):
                if ch != "#":
                    continue
                col = rows_cols[min(len(rows_cols) - 1, y)]
                for yy in range(scale):
                    for xx in range(scale):
                        fill.set(pad + gi * (gw + gap) + x * scale + xx, pad + y * scale + yy, col)
    out = Canvas(fill.w, fill.h + 1)
    inner = fill.copy()
    inner.outline_all("ink")
    outer = inner.copy()
    outer.outline_all("white", diagonal=True)
    shadow = Canvas(out.w, out.h)
    for y in range(outer.h):
        for x in range(outer.w):
            if outer.opaque(x, y):
                shadow.set(x, y + 1, "plum")
    out.blit(shadow, 0, 0)
    out.blit(outer, 0, 0)
    return out


# --------------------------------------------------------------------------
# App icon master (32x32)
# --------------------------------------------------------------------------

ICON_HALF = [
    "................",
    "................",
    "..........oooooo",
    "........oogggggg",
    ".......ogggccggg",
    "......ogggcggggg",
    "....ooogggcggggg",
    "...obbbogggggggg",
    "..obBBbbgggggggg",
    "..obBBbbgggggggg",
    ".obBBBbbgggggggg",
    ".obBBBbggggooggg",
    ".obBBBbgggowwogg",
    ".obBBBbgggowoogg",
    ".obBBBbgggoooogg",
    "..obBBbggggoogcc",
    "..obBbggppgggcoo",
    "...obbgggggcccco",
    "...obbgggcccccco",
    "....obggccccocco",
    "....obggcccccooc",
    ".....obgcccccccp",
    "......oocccccccc",
    "...ooo.ooocccccc",
    "..oRRRo..ooooooo",
    ".oRRRRRoozSSSSSS",
    ".oRRRRRRozSSSSSS",
    "oRRRRRRRozSSsSSS",
    "oRRrRRRRozsSSSSY",
    "oRRrRRRRRozSSSYY",
    "oRRrRRRRRozsSSSY",
    "oRRrRRRRRozzsSSS",
]

ICON_LEGEND = {
    "o": "ink", "g": "gold_l", "G": "gold", "b": "gold_d", "B": "brown", "c": "cream", "w": "white",
    "p": "pink", "R": "red", "r": "red_d", "S": "steel_l", "s": "steel", "z": "steel_d", "Y": "yellow",
}


def icon_character() -> Canvas:
    """Goldie's portrait on a transparent 32x32 canvas (the foreground layer)."""
    rows = [half + half[::-1] for half in ICON_HALF]
    c = Canvas(32, 32)
    c.stamp(rows, 0, 0, ICON_LEGEND, outline=None)
    # mirrored right eye: move its highlight to the top-left like the left eye
    c.set(20, 13, "ink")
    c.set(19, 13, "white")
    return c


def icon_background(size: int = 32) -> Canvas:
    """Sky with soft sun rays and a meadow hill (opaque)."""
    c = Canvas(size, size, rgba("sky"))
    cx, cy = size / 2, size * 0.42
    for y in range(size):
        for x in range(size):
            a = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
            if int((a + math.pi) / (2 * math.pi) * 16) % 2 == 0:
                c.set(x, y, "sky_l")
    c.ellipse(cx, cy, size * 0.22, size * 0.22, "sky_l")
    for y in range(size):
        for x in range(size):
            if y > size * 0.84 + 2 * math.sin(x / size * math.pi * 2):
                c.set(x, y, "leaf" if y < size * 0.92 else "leaf_d")
    return c


def icon_master() -> Canvas:
    c = icon_background(32)
    c.blit(icon_character(), 0, 0)
    return c


def adaptive_layer(fg: Canvas, size: int = 432, safe: float = 0.66) -> Canvas:
    """Largest whole-number scale of fg whose opaque pixels stay inside the centred safe circle."""
    best = 1
    radius = size * safe / 2
    for k in range(1, 64):
        w = fg.w * k
        off = (size - w) // 2
        ok = w <= size
        if ok:
            for y in range(fg.h):
                for x in range(fg.w):
                    if not fg.opaque(x, y):
                        continue
                    for (px, py) in ((x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)):
                        if math.hypot(off + px * k - size / 2, off + py * k - size / 2) > radius:
                            ok = False
                            break
                    if not ok:
                        break
                if not ok:
                    break
        if not ok:
            break
        best = k
    big = fg.scaled(best)
    out = Canvas(size, size)
    off = (size - big.w) // 2
    out.blit(big, off, off)
    return out


def fill_scaled(src: Canvas, size: int) -> Canvas:
    """Scale up by the smallest whole number that covers size x size, then crop the centre."""
    k = -(-size // src.w)
    big = src.scaled(k)
    off = (big.w - size) // 2
    out = Canvas(size, size)
    for y in range(size):
        out.px[y * size:(y + 1) * size] = big.px[(y + off) * big.w + off:(y + off) * big.w + off + size]
    return out


def monochrome(fg: Canvas) -> Canvas:
    out = Canvas(fg.w, fg.h)
    for i, p in enumerate(fg.px):
        if p is not None and p[3] > 0:
            out.px[i] = (255, 255, 255, 255)
    # keep the eyes and nose readable as holes
    for i, p in enumerate(fg.px):
        if p is not None and p[:3] == rgba("ink")[:3]:
            out.px[i] = None
    out2 = Canvas(fg.w, fg.h)
    for i, p in enumerate(fg.px):
        out2.px[i] = out.px[i]
    return out2


# --------------------------------------------------------------------------
# Feature graphic (1024x500 = 256x125 x4) and splash (720x1280 = 180x320 x4)
# --------------------------------------------------------------------------

def scenic(w: int, h: int, horizon: int, seed_x: int = 0) -> Canvas:
    """Sky, clouds, a distant castle and a meadow (opaque)."""
    c = Canvas(w, h, rgba("sky"))
    for y in range(horizon):
        t = y / horizon
        for x in range(w):
            if t < 0.3 or (t < 0.45 and (x + y) % 2 == 0) or (t < 0.55 and (x + y) % 4 == 0):
                c.set(x, y, "sky_l")
    clouds = [(0.12, 0.10, 7), (0.2, 0.08, 9), (0.28, 0.11, 6), (0.7, 0.2, 6), (0.78, 0.17, 8),
              (0.86, 0.2, 6), (0.45, 0.42, 5), (0.52, 0.4, 7)]
    for (fx, fy, r) in clouds:
        cx, cy = int(fx * w) + seed_x % 7, int(fy * horizon)
        c.ellipse(cx, cy + 1, r * 1.4, r * 0.8, "sky_l")
        c.ellipse(cx, cy, r * 1.4, r * 0.8, "white")
    # distant castle silhouette (Camelot)
    base = horizon - 2
    cx0 = int(w * 0.62)
    c.rect(cx0, base - 16, 34, 16, "lilac")
    for tx, th in ((cx0 - 4, 26), (cx0 + 14, 32), (cx0 + 32, 24)):
        c.rect(tx, base - th, 8, th, "lilac")
        c.rect(tx - 1, base - th - 2, 10, 2, "lilac")
        for k in range(0, 10, 3):
            c.rect(tx - 1 + k, base - th - 4, 2, 2, "lilac")
        c.rect(tx + 3, base - th - 9, 1, 5, "violet")
        c.rect(tx + 4, base - th - 9, 3, 2, "red")
    c.rect(cx0 + 15, base - 8, 4, 8, "violet")
    # hills
    for y in range(horizon - 6, h):
        for x in range(w):
            hy = horizon - 4 + 3 * math.sin((x + seed_x) / 23.0) + 2 * math.sin(x / 9.0)
            if y >= hy:
                c.set(x, y, "leaf_l" if y < hy + 2 else "leaf")
    for y in range(horizon + 8, h):
        for x in range(w):
            if (x * 7 + y * 13) % 29 == 0:
                c.set(x, y, "leaf_d")
            elif (x * 11 + y * 5) % 53 == 0:
                c.set(x, y, "white" if x % 2 else "yellow")
    return c


# --------------------------------------------------------------------------
# v2.2 (CP5, CP9): one storybook landscape for the title, the splash and the store art
# --------------------------------------------------------------------------

def landscape(w: int, h: int, horizon: int, seed: int = 0, castle_x: float = 0.3, sun_x: float = 0.5,
              clouds: bool = False) -> Canvas:
    """Morning sky with a soft sunrise glow, lilac mountains with Camelot, a forest line and
    rolling meadow hills (opaque). Clouds are animated separately on the title screen."""
    import art_world as aw
    c = Canvas(w, h, rgba("sky"))
    # sky: deep blue at the top, pale near the horizon, short dithered steps between bands
    bands = [("water", 0.0), ("sky", 0.22), ("sky_l", 0.62), ("cream", 0.9)]
    for y in range(horizon):
        t = y / max(1, horizon)
        for x in range(w):
            col = bands[0][0]
            for i in range(len(bands) - 1):
                n0, t0 = bands[i]
                n1, t1 = bands[i + 1]
                if t >= t1:
                    col = n1
                elif t >= t0:
                    edge = (t - (t1 - 0.06)) / 0.06
                    col = n1 if edge > 0 and aw.bayer(x, y) < edge else n0
                    break
            c.set(x, y, col)
    # sunrise glow
    sx, sy = w * sun_x, horizon - 6
    for y in range(max(0, int(sy - 60)), horizon):
        for x in range(w):
            d = math.hypot((x - sx) / 1.6, y - sy)
            if d < 18:
                c.set(x, y, "white")
            elif d < 30 and aw.bayer(x, y) < (30 - d) / 12:
                c.set(x, y, "white")
            elif d < 52 and aw.bayer(x, y) < (52 - d) / 30 and aw.name_at(c, x, y) in ("sky_l", "sky"):
                c.set(x, y, "cream" if aw.name_at(c, x, y) == "sky_l" else "sky_l")
    if clouds:
        for (fx, fy, r) in ((0.15, 0.25, 7), (0.72, 0.18, 9), (0.5, 0.45, 6)):
            cl = cloud(int(r * 4), int(r * 1.8), seed + int(fx * 10))
            c.blit(cl, int(fx * w), int(fy * horizon))
    # two mountain ranges: far (pale, snowy peaks) and near (deeper violet), lit from the left
    def ridge(x: float, k: float, base_h: float) -> float:
        return base_h + 12 * math.sin(x / (29.0 * k) + seed) + 7 * math.sin(x / (11.0 * k) + seed * 2) \
            + 3 * math.sin(x / (5.0 * k))

    for layer, (k, base_h, lit, shade_col, snow) in enumerate(((1.3, 34, "white", "lilac", True),
                                                              (1.0, 18, "lilac", "violet", False))):
        for x in range(w):
            mh = ridge(x, k, base_h)
            top = int(horizon - 6 - mh)
            slope = ridge(x + 1, k, base_h) - mh
            for y in range(top, horizon):
                col = lit if slope >= 0 else shade_col
                if layer == 0:
                    col = "lilac" if slope >= 0 else "violet"
                    if snow and y < top + 3 and mh > base_h + 6:
                        col = "white" if slope >= 0 else "steel_l"
                else:
                    col = "lilac" if slope >= 0.3 else "violet"
                if y > horizon - 10 and aw.bayer(x, y) < (y - (horizon - 10)) / 10:
                    col = "violet" if layer == 0 else "plum"
                c.set(x, y, col)
    # Camelot on the mountains
    cx0 = int(w * castle_x)
    base = horizon - 10
    walls = [(cx0, 30, 14), (cx0 + 6, 6, 30), (cx0 - 3, 6, 24), (cx0 + 26, 6, 22), (cx0 + 14, 5, 38)]
    for (x0, ww, hh) in walls:
        for y in range(base - hh, base):
            for x in range(x0, x0 + ww):
                c.set(x, y, "white" if x == x0 else ("stone_l" if x < x0 + ww - 1 else "lilac"))
        if ww <= 6:
            for k in range(0, ww + 1, 2):
                c.set(x0 - 1 + k, base - hh - 1, "stone_l")
            for yy in range(base - hh - 6, base - hh - 1):
                c.set(x0 + ww // 2, yy, "violet")
            c.set(x0 + ww // 2 + 1, base - hh - 6, "red")
            c.set(x0 + ww // 2 + 2, base - hh - 6, "red")
            c.set(x0 + ww // 2 + 1, base - hh - 5, "red_d")
    for (wx, wy) in ((cx0 + 8, base - 20), (cx0 + 16, base - 28), (cx0 + 28, base - 14)):
        c.set(wx, wy, "yellow")
    # forest line on the horizon
    rng = __import__("random").Random(seed)
    for x in range(-6, w + 6, 5):
        r = rng.uniform(4, 7)
        blob = aw.blob_canvas(int(r * 2 + 3), int(r * 2 + 3), [(r + 1.5, r + 1.5, r)],
                              ["forest", "leaf_d", "leaf_d", "leaf"], "forest_d", seed + x, texture=0.2)
        c.blit(blob, x, horizon - int(r) - 4 + rng.randrange(3))
    # rolling hills
    for y in range(horizon, h):
        for x in range(w):
            c.set(x, y, "leaf")
    aw.paint_ground(c, (0, horizon, w, h), ("leaf_d", "leaf", "leaf_l"), seed + 3, scale=24, tufts=0.5,
                    max_light=0.3, max_dark=0.25)
    for k, (amp, per, off, col) in enumerate(((5, 41.0, 0, "leaf_l"), (7, 57.0, 1.3, "leaf_l"))):
        y0 = horizon + 8 + k * 22
        for x in range(w):
            top = int(y0 + amp * math.sin(x / per + off + seed))
            c.set(x, top, col)
            if aw.bayer(x, top + 1) < 0.5:
                c.set(x, top + 1, col)
            for y in range(top - 1, top - 4, -1):
                if aw.bayer(x, y) < 0.25:
                    aw.shade(c, x, y, -1)
    aw.sprinkle_flowers(c, (0, horizon + 6, w, h), int(w * (h - horizon) / 120), seed + 7,
                        ["white", "yellow", "pink"])
    return c


def cloud(w: int, h: int, seed: int) -> Canvas:
    """A soft pixel cloud (white top, sky_l underside) for the animated title sky."""
    import art_world as aw
    rng = __import__("random").Random(seed)
    blobs = [(w * 0.5, h * 0.62, h * 0.5)]
    for k in range(4):
        blobs.append((w * (0.2 + 0.2 * k) + rng.uniform(-2, 2), h * 0.62 + rng.uniform(-1, 1),
                      h * rng.uniform(0.32, 0.45)))
    blobs.append((w * 0.42, h * 0.42, h * 0.42))
    return aw.blob_canvas(w + 2, h + 2, blobs, ["sky_l", "white", "white", "white"], None, seed,
                          light=(-0.3, -1.0, 0.6), texture=0.0)


def title_background(sword_stone: Canvas, tree: Canvas, bush: Canvas) -> Canvas:
    """304x512 title illustration; its centre lines up with the centre of the screen.

    Screen (180x320) = image x 62..242, y 96..416. Horizon at screen y ~140 (below the logo);
    Goldie stands on the near hill at the left, the sword in the stone on a rise at the right.
    """
    import art_world as aw
    hz = 236
    c = landscape(304, 512, hz, seed=4, castle_x=0.58, sun_x=0.36)
    # the rise with the sword in the stone (right) and the hill Goldie stands on (left)
    for x in range(150, 304):
        top = int(272 - 16 * math.exp(-((x - 214) / 34.0) ** 2))
        for y in range(top, 300):
            c.set(x, y, "leaf_l" if y < top + 2 else ("leaf" if aw.bayer(x, y) > 0.2 else "leaf_l"))
        c.set(x, top - 1, "leaf_d")
    stone = aw.sword_in_stone()
    aw.soft_light(c, 214, 262, 40, 14, +1, 0.5)
    aw.place(c, stone, 214 - 26, 256 - 36, shadow=(0.9, -4), shadow_dx=5)
    for x in range(0, 170):
        top = int(298 - 10 * math.exp(-((x - 100) / 40.0) ** 2))
        for y in range(top, 312):
            c.set(x, y, "leaf_l" if y < top + 2 else c.get(x, y) and aw.name_at(c, x, y) or "leaf")
        c.set(x, top - 1, "leaf_d")
    # framing trees and bushes at the sides
    for i, (x, y) in enumerate(((22, 236), (44, 258), (244, 250), (226, 286))):
        aw.place(c, aw.tree(900 + i, 34), x, y)
    for i, (x, y) in enumerate(((40, 330), (222, 336), (20, 420), (248, 430), (130, 480))):
        aw.place(c, aw.bush(920 + i, 18, 11, aw.TREE_GREEN, flowers=["white", "pink"]), x, y)
    aw.paint_path(c, [(150, 520), (140, 440), (120, 380), (110, 320), (108, 300)], 13, 930, pebbles=20)
    return c


def feature_graphic(goldie_frame: Canvas, bulldog_frame: Canvas, sword_stone: Canvas) -> Canvas:
    """Google Play feature graphic 1024x500 (256x125 x4)."""
    import art_world as aw
    c = landscape(256, 125, 74, seed=10, castle_x=0.06, sun_x=0.25, clouds=True)
    stone = aw.sword_in_stone()
    aw.place(c, stone, 140, 62, shadow=(0.9, -4))
    c.blit(goldie_frame.scaled(2), 178, 64)
    c.blit(bulldog_frame.scaled(2), 210, 72)
    lg = logo(3)
    c.blit(lg, 10, 18)
    return c.scaled(4)


def splash_image(goldie_frame: Canvas) -> Canvas:
    """Boot splash 720x1280 (180x320 x4)."""
    c = landscape(180, 320, 196, seed=2, castle_x=0.62, sun_x=0.5, clouds=True)
    lg = logo(2)
    c.blit(lg, (180 - lg.w) // 2, 100)
    c.blit(goldie_frame.scaled(2), 66, 212)
    return c.scaled(4)


def write_clouds() -> None:
    for i, (w, h) in enumerate(((30, 12), (42, 15), (22, 9))):
        cloud(w, h, 50 + i).save(res_path("res://assets/ui/cloud_%d.png" % i))


def write_all(goldie_frame: Canvas, bulldog_frame: Canvas, sword_stone: Canvas,
              tree: Canvas | None = None, bush: Canvas | None = None) -> None:
    master = icon_master()
    master.save(res_path("res://assets/app_icon/icon_master_32.png"), opaque=True)
    master.scaled(8).save(res_path("res://assets/app_icon/icon.png"), opaque=True)
    master.scaled(32).save(res_path("res://assets/app_icon/icon_1024.png"), opaque=True)
    master.scaled(16).save(res_path("res://assets/app_icon/play_icon_512.png"), opaque=True)
    fg = icon_character()
    adaptive_layer(fg).save(res_path("res://assets/app_icon/android_foreground.png"))
    fill_scaled(icon_background(32), 432).save(res_path("res://assets/app_icon/android_background.png"), opaque=True)
    adaptive_layer(monochrome(fg)).save(res_path("res://assets/app_icon/android_monochrome.png"))
    feature_graphic(goldie_frame, bulldog_frame, sword_stone).save(
        res_path("res://assets/app_icon/feature_graphic_1024x500.png"), opaque=True)
    splash_image(goldie_frame).save(res_path("res://assets/app_icon/splash.png"), opaque=True)
    if tree is not None and bush is not None:
        title_background(sword_stone, tree, bush).save(res_path("res://assets/ui/title_bg.png"), opaque=True)
    logo(1).save(res_path("res://assets/ui/logo.png"))
    logo(2).save(res_path("res://assets/ui/logo_2x.png"))
    write_clouds()
