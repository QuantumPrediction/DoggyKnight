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
    for y in range(horizon // 3):
        for x in range(w):
            c.set(x, y, "sky_l")
    for (cx, cy, r) in [(30 + seed_x, 14, 7), (40 + seed_x, 12, 9), (52 + seed_x, 15, 6),
                        (w - 60, 22, 6), (w - 50, 19, 8), (w - 40, 22, 6)]:
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


def feature_graphic(goldie_frame: Canvas, bulldog_frame: Canvas, sword_stone: Canvas) -> Canvas:
    c = scenic(256, 125, 70, seed_x=10)
    c.blit(sword_stone, 150, 72)
    c.blit(goldie_frame.scaled(2), 176, 66)
    c.blit(bulldog_frame.scaled(2), 206, 72)
    lg = logo(3)
    c.blit(lg, 14, 26)
    return c.scaled(4)


def splash_image(goldie_frame: Canvas) -> Canvas:
    c = scenic(180, 320, 200)
    lg = logo(2)
    c.blit(lg, (180 - lg.w) // 2, 110)
    c.blit(goldie_frame.scaled(2), 66, 210)
    return c.scaled(4)


def write_all(goldie_frame: Canvas, bulldog_frame: Canvas, sword_stone: Canvas) -> None:
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
    logo(1).save(res_path("res://assets/ui/logo.png"))
    logo(2).save(res_path("res://assets/ui/logo_2x.png"))
