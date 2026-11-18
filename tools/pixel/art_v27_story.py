"""v2.7 (C 繪本, CS4): the nineteen storybook pages of chapters 4 to 6 (docs/STORY.md section 16).

assets/story/<id>.png, 160x120, opaque, palette colours only - the same storybook look as art_v26_story (clean
colour bands, a soft printed-page rim, sprites at 1x or 2x). Every character is drawn with the game's own rigs, so
the pages match the sprites: Goldie, Bedivere and Merlin (art_v25_*), Lancelot, the Lady of the Lake, Morgana in her
true fox form and the Green Knight (art_v26_cast), and the chapter 4-6 cast (art_v27_cast): Tristan, Gawain, the
kraken, the red and white dragons, Mordred and his shadow knights. Poses are chosen per page through the rigs'
frame functions. Only knights hold weapons, and only where the scene wants them (Goldie hands the sword back to the
Lady of the Lake in c6_ending_2 and chases a stick in c6_ending_4); Merlin and Morgana keep their staffs. At the
feast (c6_ending_3) and on the last page the rigs draw no lance, hammer or stolen scabbard (`unarmed`); Mordred keeps
his sword at the table, ready for his first patrol. The finale pages (c6_ending_3, c6_ending_4) are lit warm: window
light over the round table, a low sun over the meadow.

    python3 tools/pixel/art_v27_story.py [ids...] [--preview DIR] [--sheet PNG]
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art_story as S  # noqa: E402
import art_v25_bulldog as BD  # noqa: E402
import art_v25_goldie as GD  # noqa: E402
import art_v25_knights as KN  # noqa: E402
import art_v26_cast as C6  # noqa: E402
import art_v26_kit as K  # noqa: E402
import art_v26_story as S6  # noqa: E402
import art_v26_title as T  # noqa: E402
import art_v26_world as WD  # noqa: E402
import art_v27_cast as C7  # noqa: E402
import art_world as AW  # noqa: E402
import paint as P  # noqa: E402
from pixel import Canvas, contact_sheet, res_path  # noqa: E402
from rig import Fig, capsule, poly  # noqa: E402

W, H = 160, 120
IDS = ["teaser_3",
       "c4_prologue_1", "c4_prologue_2", "c4_ending_1", "c4_ending_2", "c4_ending_3", "teaser_4",
       "c5_prologue_1", "c5_prologue_2", "c5_ending_1", "c5_ending_2", "c5_ending_3", "teaser_5",
       "c6_prologue_1", "c6_prologue_2", "c6_ending_1", "c6_ending_2", "c6_ending_3", "c6_ending_4"]

page = S6.page
name_at = AW.name_at


# ==========================================================================
# painting helpers
# ==========================================================================

def glow_bands(c: Canvas, cx: float, cy: float, radii, sy: float = 1.0, only=None, wob: float = 0.7,
               ramp: dict | None = None) -> None:
    """Clean painted light: each radius lightens one more step (concentric bands, no dither). `ramp` maps a colour
    to its lit colour (default: the palette's own LIGHTER steps); WARM keeps sunset and fire light warm."""
    big = max(radii)
    mask = {}
    for y in range(int(cy - big * sy) - 2, int(cy + big * sy) + 3):
        for x in range(int(cx - big) - 2, int(cx + big) + 3):
            if 0 <= x < W and 0 <= y < H and (only is None or name_at(c, x, y) in only):
                mask[(x, y)] = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) / sy) - wob * math.sin(x * 0.7 + y * 0.5)
    for (x, y), d in mask.items():
        n = sum(1 for r in radii if d < r)
        if not n:
            continue
        if ramp is None:
            P.darken(c, x, y, -n)
            continue
        col = name_at(c, x, y)
        for _ in range(n):
            col = ramp.get(col, col)
        c.set(x, y, col)


WARM = {"plum": "wine", "wine": "red_d", "red_d": "rose", "rose": "coral", "coral": "peach", "dusk": "rose",
        "umber": "brown_d", "brown_d": "brown", "brown": "gold_d", "gold_d": "gold", "gold": "gold_l",
        "gold_l": "cream", "peach": "cream", "night_d": "dusk", "night": "dusk", "navy": "plum", "ink": "umber",
        "iron": "slate", "slate": "dusk", "forest_d": "moss_d", "forest": "moss_d", "deep": "forest", "teal": "moss_d",
        "leaf_d": "moss", "grass": "moss", "leaf": "leaf_l", "moss_d": "moss", "moss": "leaf_l", "water_d": "dusk",
        "stone_d": "stone", "stone": "stone_l", "steel_d": "steel", "orange": "amber", "amber": "yellow",
        "sand": "cream", "dirt": "sand", "ash": "fog", "fog": "white", "red": "coral", "cream": "white"}


VIOLET = {"ink": "plum", "navy": "plum", "night_d": "dusk", "night": "dusk", "plum": "dusk", "dusk": "violet",
          "iron": "dusk", "slate": "violet", "stone_d": "violet", "stone": "lilac", "violet": "lilac", "wine": "dusk",
          "rose": "lilac", "steel_d": "violet", "ash": "lilac"}


def shade(c: Canvas, cx: float, cy: float, rx: float, ry: float, steps: int = 1, only=None) -> None:
    """A flat cast shadow: one palette step darker inside an ellipse."""
    for (x, y) in P.ellipse(cx, cy, rx, ry):
        if 0 <= x < W and 0 <= y < H and (only is None or name_at(c, x, y) in only):
            P.darken(c, x, y, steps)


def ray(c: Canvas, x0: float, y0: float, x1: float, y1: float, w0: float, w1: float, strength: float = 1.0) -> None:
    """A clean light shaft from (x0, y0) to (x1, y1), widening from w0 to w1 (one palette step lighter)."""
    S.light_beam(c, [(x0 - w0, y0), (x0 + w0, y0), (x1 + w1, y1), (x1 - w1, y1)], strength)


def reflection(c: Canvas, cx: float, y0: int, y1: int, w0: float, grow: float, cols=("yellow", "cream"),
               step: int = 2, seed: int = 0) -> None:
    """A broken path of light on water: short horizontal dashes, widening toward the viewer."""
    rng = random.Random(seed)
    for y in range(y0, y1, step):
        half = w0 + (y - y0) * grow
        x = int(cx - half)
        while x < cx + half:
            ln = rng.randrange(2, 6)
            if rng.random() < 0.62:
                for k in range(ln):
                    if x + k < cx + half:
                        c.set(x + k, y, cols[0] if abs(x + k - cx) < half * 0.45 else cols[1])
            x += ln + rng.randrange(1, 3)


def sparkle(c: Canvas, x: int, y: int, col: str = "yellow", centre: str = "white", arm: int = 1) -> None:
    P.star4(c, x, y, col, arm, centre)


def glitter(c: Canvas, cx: float, cy: float, n: int, seed: int, rx: float = 30, ry: float = 20,
            cols=("white", "yellow", "gold_l")) -> None:
    rng = random.Random(seed)
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.25, 1.0)
        x, y = int(cx + math.cos(a) * rx * d), int(cy + math.sin(a) * ry * d)
        if i % 5 == 0:
            sparkle(c, x, y, cols[1], cols[0])
        else:
            c.set(x, y, cols[i % len(cols)])


def dashes(c: Canvas, pts, col: str = "white") -> None:
    """Short motion / shake marks: (x, y, dx, dy, n)."""
    for (x, y, dx, dy, n) in pts:
        for k in range(n):
            c.set(x + dx * k, y + dy * k, col)


def rimmed(img: Canvas, side=(1, 0)) -> Canvas:
    """A thin backlit edge on the side facing the light."""
    return P.rim_light(img, side)


def moonlit(img: Canvas, side=(-1, -1), rim: str = "ash", ramp=("ink", "ink", "navy", "night_d", "night"),
            keep=("lilac", "violet", "white")) -> Canvas:
    """A sprite seen against a bright sky (moon or sunset): colours fall to a dark ramp by brightness, so the shapes
    still read, with a rim of light on `side`; glowing colours and translucent glow stay."""
    out = Canvas(img.w, img.h)
    for y in range(img.h):
        for x in range(img.w):
            p = img.get(x, y)
            if p is None or p[3] == 0:
                continue
            n = name_at(img, x, y)
            if p[3] < 255 or n in keep:
                out.set(x, y, p)
                continue
            lum = (p[0] * 0.3 + p[1] * 0.55 + p[2] * 0.15) / 255
            col = ramp[min(len(ramp) - 1, int(lum * 1.6 * len(ramp)))]
            if not img.opaque(x + side[0], y) or not img.opaque(x, y + side[1]):
                col = rim
            out.set(x, y, col)
    return out


def crop(img: Canvas, x0: int, y0: int, x1: int, y1: int) -> Canvas:
    out = Canvas(x1 - x0, y1 - y0)
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = img.get(x, y)
            if p is not None:
                out.set(x - x0, y - y0, p)
    return out


def wisps(c: Canvas, y: int, x0: int, x1: int, cols, seed: int, thick: int = 3, gap: int = 8) -> None:
    """Long flat evening clouds: a body colour and a lit (or shaded) underside, tapered ends."""
    rng = random.Random(seed)
    x = x0
    while x < x1:
        ln = rng.randrange(22, 50)
        th = rng.randrange(2, thick + 2)
        yy = y + rng.randrange(-5, 6)
        for k in range(th):
            inset = (th - 1 - k) * 3 if k < th - 1 else 2
            for xx in range(x + inset, x + ln - inset):
                if 0 <= xx < W:
                    c.set(xx, yy + k, cols[0] if k < th - 1 else cols[1])
        if len(cols) > 2:
            for xx in range(x + th * 3, x + ln - th * 3):
                if 0 <= xx < W and xx % 3:
                    c.set(xx, yy - 1, cols[2])
        x += ln + rng.randrange(-12, gap)


def fire(c: Canvas, cx: float, base: int, h: int, w: float, seed: int, lean: float = 0.0,
         cols=("red", "orange", "yellow", "white"), outline: str | None = "red_d") -> None:
    """A big storybook flame: several licking tongues, red edge, orange, yellow, a white-hot core."""
    shape = {}
    for y in range(base - h, base + 1):
        t = (base - y) / h
        for x in range(int(cx - w - h * abs(lean)) - 2, int(cx + w + h * abs(lean)) + 3):
            xc = cx + lean * h * t * t
            dx = (x + 0.5 - xc) / w
            tongue = 0.22 * math.sin(x * 0.8 + seed) + 0.14 * math.sin(x * 0.31 + seed * 2.3)
            width = max(0.0, (1 - t) ** 0.55 * (1 + tongue * t * 2.2))
            if abs(dx) < width and t < 0.98 + tongue * 0.4:
                v = (1 - abs(dx) / max(1e-6, width)) * (1 - t * 0.55)
                shape[(x, y)] = cols[0] if v < 0.22 else (cols[1] if v < 0.45 else (cols[2] if v < 0.7 else cols[3]))
    for (x, y), col in shape.items():
        c.set(x, y, col)
    if outline:
        for (x, y) in P.edge(set(shape)):
            if name_at(c, x, y) == cols[0] and y > base - h * 0.4:
                c.set(x, y, outline)


# ==========================================================================
# props
# ==========================================================================

def crown(c: Canvas, x: int, y: int) -> None:
    c.stamp(["y.y.y", "yyyyy", "ygrgy"], x, y, {"y": "yellow", "g": "gold", "r": "red"}, outline="brown_d")


def crowned(img: Canvas, lean: float = 0.0, bob: int = 0) -> Canvas:
    """Goldie's frame on a 32x36 canvas with the king's crown on the head (blit 4 px higher than the frame)."""
    out = Canvas(img.w, img.h + 4)
    out.blit(img, 0, 4)
    hx = int(15.0 + lean * 1.3)
    crown(out, hx - 5, 2 + bob)
    return out


def bone(c: Canvas, x: int, y: int, vertical: bool = False, col: str = "white", dark: str = "stone_l") -> None:
    rows = ["ww...ww", "wwwwwww", "dwwwwwd", "dd...dd"] if not vertical else \
        ["wwd", "wwd", ".w.", ".w.", ".w.", "wwd", "wdd"]
    c.stamp(rows, x, y, {"w": col, "d": dark}, outline="brown_d")


def sausage(c: Canvas, x: int, y: int) -> None:
    c.stamp([".rrrr.", "rcrrrr", ".dddd."], x, y, {"r": "red_d", "c": "coral", "d": "wine"}, outline="umber")


def bowl(c: Canvas, x: int, y: int, cols=("red_d", "red", "coral"), empty: bool = True) -> None:
    """A dog bowl tipped toward the viewer (8x5): the empty inside shows."""
    d, m, l_ = cols
    rows = [".dddddd.", "dmmmmmmd", "dmmllmmd", ".dmmmmd.", "..dddd.."] if empty else \
        [".bbbbbb.", "dmmmmmmd", "dmmllmmd", ".dmmmmd.", "..dddd.."]
    c.stamp(rows, x, y, {"d": d, "m": m, "l": l_, "b": "brown"}, outline="ink")


def golden_bowl(c: Canvas, cx: int, cy: int, rx: int = 16, full: bool = True, seed: int = 0) -> None:
    """The golden dog bowl: a wide gold dish on a little foot, heaped with bones and sausages, glittering."""
    ry = max(3.0, rx * 0.3)
    body = {(x, y) for (x, y) in P.ellipse(cx, cy, rx, rx * 0.62) if y >= cy}
    foot = P.rect(cx - rx // 2, int(cy + rx * 0.58), rx, 3)
    P.shade_shape(c, foot, ["brown", "gold_d", "gold", "yellow"], bias=0.0)
    P.shade_shape(c, body, ["gold_d", "gold", "yellow", "cream"], bias=0.12)
    for (x, y) in body:
        if y == cy + 2 or y == cy + 3:
            c.set(x, y, "gold_d" if (x + y) % 6 else "yellow")
    rim = P.ellipse(cx, cy, rx, ry)
    inner = P.ellipse(cx, cy + 0.4, rx - 1.6, ry - 1.1)
    for (x, y) in rim - inner:
        c.set(x, y, "cream" if y < cy and x < cx else ("yellow" if y < cy else "gold_l"))
    P.fill(c, inner, "gold_d" if not full else "cream")
    P.outline_shape(c, rim | body | foot, "brown_d")
    if full:
        # the heap: back row higher, front row on the rim
        heap = {(x, y) for (x, y) in P.ellipse(cx, cy, rx - 2, rx * 0.5) if y <= cy}
        P.shade_shape(c, heap, ["gold_l", "cream", "white"], bias=0.1)
        rng = random.Random(seed)
        rows = [(cy - int(rx * 0.42), 0.45), (cy - int(rx * 0.24), 0.75), (cy - 3, 0.95)]
        for (ry_, span) in rows:
            n = max(2, int(rx * 2 * span / 8))
            for k in range(n):
                bx = int(cx - rx * span + 2 + k * (2 * rx * span - 6) / max(1, n - 1))
                if (k + ry_) % 3 == 0:
                    sausage(c, bx - 2, ry_ + rng.randrange(0, 2))
                else:
                    bone(c, bx - 3, ry_ + rng.randrange(0, 2))
    for (x, y) in ((cx - rx + 4, cy + 3), (cx + rx - 5, cy + 2), (cx + 2, cy + 6)):
        sparkle(c, x, y, "yellow", "white")


def exclaim(c: Canvas, x: int, y: int, col: str = "yellow") -> None:
    c.stamp(["y", "y", "y", ".", "y"], x, y, {"y": col}, outline="ink")


def sweat(c: Canvas, x: int, y: int) -> None:
    c.stamp([".s", "ss", "ss"], x, y, {"s": "sky_l"}, outline="water")


def note(c: Canvas, x: int, y: int, col: str = "yellow") -> None:
    c.stamp(["..nn", "..n.", "..n.", "nnn.", "nn.."], x, y, {"n": col}, outline="ink")


def heart(c: Canvas, x: int, y: int, col: str = "pink") -> None:
    c.stamp(["hh.hh", "hhhhh", ".hhh.", "..h.."], x, y, {"h": col}, outline="red_d")


def fish(c: Canvas, x: int, y: int, col: str = "water_d", flip: bool = False) -> None:
    c.stamp([".ff..f", "fffff.", ".ff..f"], x, y, {"f": col}, outline=None, flip=flip)


def bubble(c: Canvas, x: int, y: int, r: int = 1) -> None:
    if r <= 1:
        c.stamp([".s.", "s.s", ".s."], x - 1, y - 1, {"s": "sky_l"}, outline=None)
        return
    for (px, py) in P.ellipse(x, y, r + 0.5, r + 0.5) - P.ellipse(x, y, r - 0.5, r - 0.5):
        c.set(px, py, "sky_l")
    c.set(x - r // 2, y - r // 2, "white")


def bubbles(c: Canvas, rect_, n: int, seed: int) -> None:
    rng = random.Random(seed)
    x0, y0, x1, y1 = rect_
    for i in range(n):
        bubble(c, rng.randrange(x0, x1), rng.randrange(y0, y1), 1 if i % 3 else 2)


def seaweed(c: Canvas, x: int, base: int, h: int, seed: int, cols=("teal", "grass", "forest")) -> None:
    for k in range(2):
        ph = seed * 1.7 + k * 2.1
        for j in range(h - k * 4):
            xx = x + k * 3 + int(round(math.sin(j / 3.2 + ph) * 1.5))
            c.set(xx, base - j, cols[0] if j % 5 else cols[1])
            c.set(xx + 1, base - j, cols[2])


def coral(c: Canvas, x: int, base: int, seed: int, cols=("red_d", "coral", "pink")) -> None:
    rng = random.Random(seed)
    for k in range(4):
        bx = x + rng.randrange(-4, 5)
        h = rng.randrange(5, 11)
        for j in range(h):
            xx = bx + int(round(math.sin(j * 0.6 + k) * 1.2))
            c.set(xx, base - j, cols[1] if j < h - 2 else cols[2])
            if j == h // 2:
                c.set(xx + 1, base - j - 1, cols[2])
                c.set(xx - 1, base - j - 1, cols[1])
        c.set(bx, base, cols[0])


def starfish(c: Canvas, x: int, y: int, col: str = "orange") -> None:
    c.stamp(["..o..", "ooooo", ".ooo.", "o...o"], x, y, {"o": col}, outline="red_d")


def shell(c: Canvas, x: int, y: int) -> None:
    c.stamp([".pp.", "pccp", "pppp"], x, y, {"p": "pink", "c": "cream"}, outline="rose")


def wolf_head(c: Canvas, x: int, y: int, col: str = "lilac", eye: str = "white", mirror: bool = False) -> None:
    """The black wolf of Mordred's banners (5x5, like art_v27_cast.wolf_sigil)."""
    rows = ["x.x..", "xxx..", "xxxxx", ".xxx.", "..x.."]
    for j, row in enumerate(rows):
        for i, ch in enumerate(row[::-1] if mirror else row):
            if ch == "x":
                c.set(x + i, y + j, col)
    c.set(x + (3 if mirror else 1), y + 2, eye)


def wolf_banner(c: Canvas, x: int, y: int, w: int = 12, h: int = 24, wave: float = 0.0, emblem: str = "lilac") -> None:
    """A hanging black banner with a silver wolf head and a swallow-tailed hem."""
    b = Canvas(w + 2, h + 2)
    for yy in range(h):
        for xx in range(w):
            if yy > h - 5 and abs(xx - (w - 1) / 2) < (yy - (h - 5)) * 1.2:
                continue
            col = "navy" if xx < w - 3 else "ink"
            if xx == 0:
                col = "iron"
            b.set(xx + 1, yy + 1 + int(round(math.sin(xx / 3 + wave) * 0.6)), col)
    for xx in range(w):
        b.set(xx + 1, 3, "steel_d")
    b.outline_all("ink")
    wolf_head(b, w // 2 - 1, h // 2 - 4, emblem, "white")
    c.blit(b, x, y)
    c.hline(x - 1, x + w + 2, y, "iron")


def wolf_flag(c: Canvas, x: int, y: int, pole: int = 16, w: int = 10, h: int = 7, flip: bool = False) -> None:
    """A black wolf flag flying from a pole whose foot is at (x, y)."""
    c.vline(x, y - pole, y, "iron")
    c.set(x, y - pole - 1, "steel")
    f = Canvas(w + 2, h + 2)
    for yy in range(h):
        for xx in range(w):
            if xx > w - 3 and abs(yy - (h - 1) / 2) < (xx - (w - 3)) * 1.2:
                continue
            f.set(xx + 1, yy + 1 + int(round(math.sin(xx / 2.5) * 0.7)), "navy" if yy < h - 2 else "ink")
    f.outline_all("ink")
    wolf_head(f, 2, 2, "lilac", "white")
    if flip:
        f = f.flipped()
        c.blit(f, x - w - 1, y - pole)
    else:
        c.blit(f, x + 1, y - pole)


def leaves(c: Canvas, pts, k0: int = 0) -> None:
    for i, (x, y) in enumerate(pts):
        C7.autumn_leaf(c, int(x), int(y), k0 + i)


def leaf_stream(c: Canvas, x0: float, y0: float, x1: float, y1: float, n: int, seed: int, spread: float = 8,
                curl: float = 0.0) -> None:
    rng = random.Random(seed)
    pts = []
    for _ in range(n):
        t = rng.random()
        x = x0 + (x1 - x0) * t + math.sin(t * 9 + curl) * spread * t
        y = y0 + (y1 - y0) * t + math.cos(t * 7 + curl) * spread * 0.6 * t + rng.uniform(-spread, spread) * 0.5
        pts.append((x, y))
    leaves(c, pts, seed)


def tree(c: Canvas, x: int, base: int, h: int, r: float, seed: int, ramp=("forest", "leaf_d", "leaf", "leaf_l"),
         outline: str = "forest_d", fruit: str | None = None, trunk=("brown_d", "brown")) -> None:
    """A round storybook tree: trunk and a crown of overlapping shaded blobs (apples or blossom dots)."""
    rng = random.Random(seed)
    for y in range(base - h, base + 1):
        for xx in range(x - 2, x + 2):
            c.set(xx, y, trunk[1] if xx < x else trunk[0])
    c.set(x - 3, base, trunk[0])
    c.set(x + 2, base, trunk[0])
    size = int(r * 2.6) + 6
    blobs = [(size / 2, size / 2, r), (size / 2 - r * 0.6, size / 2 + r * 0.25, r * 0.7),
             (size / 2 + r * 0.6, size / 2 + r * 0.2, r * 0.72), (size / 2 - r * 0.1, size / 2 - r * 0.45, r * 0.68)]
    crown_c = AW.blob_canvas(size, size, blobs, list(ramp), outline, seed, texture=0.18)
    if fruit:
        for _ in range(int(r * 1.2)):
            fx, fy = rng.randrange(3, size - 3), rng.randrange(3, size - 3)
            if crown_c.opaque(fx, fy) and crown_c.opaque(fx + 1, fy + 1) and name_at(crown_c, fx, fy) != outline:
                crown_c.set(fx, fy, fruit)
                crown_c.set(fx + 1, fy, fruit)
                crown_c.set(fx, fy + 1, K.dk(fruit))
                crown_c.set(fx + 1, fy + 1, fruit)
    c.blit(crown_c, x - size // 2, base - h - int(r * 1.4))


def crack(c: Canvas, x: float, y: float, ang: float, length: int, seed: int, cols=("umber", "brown_d")) -> None:
    """A zigzag crack in the ground with a lit lower lip."""
    rng = random.Random(seed)
    for k in range(length):
        ang += rng.uniform(-0.7, 0.7)
        x += math.cos(ang)
        y += math.sin(ang) * 0.55
        c.set(int(x), int(y), cols[0])
        if k < length * 0.6:
            c.set(int(x) + 1, int(y), cols[0])
        c.set(int(x), int(y) + 1, cols[1])
        if k % 9 == 4:
            crack(c, x, y, ang + rng.choice((-1.1, 1.1)), length // 3, seed + k, cols)


def dust_puff(c: Canvas, x: int, y: int, r: float = 2.5, cols=("stone_l", "white")) -> None:
    for (px, py) in P.ellipse(x, y, r, r * 0.8):
        c.set(px, py, cols[0])
    for (px, py) in P.ellipse(x - r * 0.3, y - r * 0.3, r * 0.55, r * 0.45):
        c.set(px, py, cols[1])


def boat(c: Canvas, x: int, y: int, w: int = 44, h: int = 12, sail: bool = False) -> None:
    """A small wooden rowboat seen side-on: (x, y) is the top-left of the gunwale."""
    lift = 5
    b = Canvas(w + 4, h + lift + 4)
    oy = lift + 1
    for px in range(w + 1):
        t = px / w
        top = -lift * max(0.0, (t - 0.72) / 0.28) ** 2            # the bow sweeps up at the front (right)
        bottom = h * (1 - max(0.0, (t - 0.55) / 0.45) ** 1.6 * 0.9) * (1 - max(0.0, (0.12 - t) / 0.12) * 0.35)
        for py in range(int(round(top)), int(round(bottom)) + 1):
            k = py - top
            col = "brown" if int(k // 3) % 2 == 0 else "gold_d"
            if k < 1.5:
                col = "gold"
            if py >= bottom - 1.5:
                col = "brown_d"
            if px < 2:
                col = "brown_d"
            b.set(px + 1, py + oy, col)
    b.outline_all("umber")
    if sail:
        b.vline(int(w * 0.45), 0, oy, "umber")
    c.blit(b, x - 1, y - oy)


def campfire(c: Canvas, x: int, base: int, seed: int = 0) -> None:
    for (dx, dy, ln) in ((-6, 0, 12), (-5, -1, 10)):
        for k in range(ln):
            c.set(x + dx + k, base + dy, "brown" if k % 3 else "brown_d")
            c.set(x + dx + k, base + dy + 1, "umber")
    for k in range(-5, 6, 2):
        c.set(x + k, base + 2, "stone_d")
    fire(c, x, base - 1, 13, 5, seed, lean=0.05)
    for (dx, dy) in ((-4, -16), (3, -19), (0, -23), (5, -14)):
        c.set(x + dx, base + dy, "amber")


def field_table(c: Canvas, cx: int, cy: int, rx: int, ry: int) -> None:
    """A rustic round table out in the fields: a wooden top with growth rings, a dark rim, two stout legs."""
    for lx in (cx - rx // 2, cx + rx // 2 - 3):
        c.rect(lx, cy + 2, 4, ry + 6, "brown_d")
        c.vline(lx, cy + 2, cy + ry + 7, "brown")
    top = P.ellipse(cx, cy, rx, ry)
    for (x, y) in top:
        d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
        c.set(x, y, "gold_d" if int(d * 6) % 2 else ("gold" if d < 0.3 else "brown"))
    rim = {(x, y) for (x, y) in P.ellipse(cx, cy + 3, rx, ry) - top if y > cy}
    P.fill(c, rim, "brown_d")
    P.outline_shape(c, top | rim, "umber")


def scabbard_broken(c: Canvas, x: int, y: int) -> None:
    """The stolen scabbard lying cracked in two in the grass, its violet glow fading."""
    f = Fig(32, 12, seed=6301)
    f.add(capsule(3, 7, 14, 6, 1.7), C7.SCAB, bias=-0.15)
    f.add(capsule(17, 6, 27, 3, 1.7), C7.SCAB, bias=-0.15)
    f.dots([(3, 7), (27, 3)], "steel_l")
    f.dots([(9, 6), (22, 4)], "lilac")
    img = f.render()
    c.blit(img, x, y)
    for (dx, dy) in ((15, 5), (16, 3), (15, 8), (17, 7)):
        c.set(x + dx, y + dy, "ink")
    for (dx, dy) in ((2, 2), (11, 0), (21, -1), (29, 1), (14, -3), (18, -6)):
        c.set(x + dx, y + dy, "lilac")
    sparkle(c, x + 16, y - 2, "violet", "lilac")


def mini_dragon(c: Canvas, x: int, y: int, kind: str, flap: int = 0, flip: bool = False) -> None:
    """A tiny far-away dragon flying (11x8): round body, wings up or down, head forward, tail streaming."""
    if kind == "red":
        leg = {"b": "red", "d": "red_d", "y": "gold_l", "h": "gold", "w": "rose"}
    else:
        leg = {"b": "white", "d": "fog", "y": "sky_l", "h": "sky", "w": "sky_l"}
    up = ["....w......", "...ww......", "..www...h..", "dd.bbbb.bb.", ".ddbbyybbbb", "....bbbb...", "....d..d..."]
    dn = ["...........", "...........", "........h..", "dd.bbbb.bb.", ".ddbbyybbbb", "...wwbb....", "...ww..d..."]
    c.stamp(up if flap == 0 else dn, x, y, leg, outline="ink" if kind == "red" else "slate", flip=flip)
    c.set(x + (8 if not flip else 2), y + 3, "ink")


# ==========================================================================
# characters (the game's own rigs)
# ==========================================================================

class unarmed:
    """`with unarmed():` the rigs leave out the knights' weapons (Lancelot's lance, Gawain's hammer, Mordred's sword
    and the stolen scabbard) - for the feast and the last page, where nobody needs one."""

    PAINTERS = ((C6, "lance"), (C7, "big_hammer"), (C7, "m_sword"), (C7, "scabbard"))

    def __init__(self, keep=()) -> None:
        self.keep = keep
        self.saved: list = []

    def __enter__(self) -> "unarmed":
        for (mod, name) in self.PAINTERS:
            if name not in self.keep:
                self.saved.append((mod, name, getattr(mod, name)))
                setattr(mod, name, lambda *a, **k: None)
        return self

    def __exit__(self, *exc) -> None:
        for (mod, name, fn) in self.saved:
            setattr(mod, name, fn)


def goldie(eyes: str = "happy", mouth: str = "smile", king: bool = True, sword: bool = False, **kw) -> Canvas:
    """Goldie (32x36 with room for the crown: blit 4 px higher than a plain 32x32 frame)."""
    kw.setdefault("sword_on", sword)
    img = GD.goldie_frame(eyes=eyes, mouth=mouth, **kw).render()
    if not king:
        out = Canvas(32, 36)
        out.blit(img, 0, 4)
        return out
    return crowned(img, kw.get("lean", 0.0), kw.get("bob", 0) + kw.get("head_dy", 0))


def goldie_run(k: int, eyes: str = "happy", mouth: str = "tongue", king: bool = True) -> Canvas:
    legs = [((0, -3.0), (0, 3.0)), ((1, -1.5), (0, 1.0)), ((3, 0.5), (0, -1.5)),
            ((0, 3.0), (0, -3.0)), ((0, 1.0), (1, -1.5)), ((0, -1.5), (3, 0.5))][k % 6]
    bob = [0, 1, -1, 0, 1, -1][k % 6]
    return goldie(eyes=eyes, mouth=mouth, king=king, lean=0.5, bob=bob, legs=legs, cape_lift=0.9, cape_wave=1.0,
                  tail_ang=140, ear_dy=-1)


def bedivere(eyes: str = "open", mouth: str = "frown", **kw) -> Canvas:
    return BD.bulldog_frame(eyes=eyes, mouth=mouth, **kw).render()


def bedivere_cheer() -> Canvas:
    return S.frame_of(S6.sprites()["bulldog"], "victory", 1)


def merlin(**kw) -> Canvas:
    return KN.merlin_frame(**kw).render()


def lancelot(**kw) -> Canvas:
    return C6.lancelot_frame(**kw).render()


def lady(**kw) -> Canvas:
    return C6.lady_frame(**kw).render()


def morgana(**kw) -> Canvas:
    return C6.morgana_frame(**kw).render()


def green_knight(face: str = "happy", **kw) -> Canvas:
    kw.setdefault("hat_tilt", 4)
    return C6.gk_frame(face=face, whip=None, **kw).render()


def tristan(**kw) -> Canvas:
    return C7.tristan_frame(**kw).render()


def tristan_play(k: int = 1, **kw) -> Canvas:
    return C7.tristan_frame(harp_at=(19.5, 24.0), paw=(23.0, 18.5 + k), strum=k + 1, eyes="happy", mouth="sing",
                            **kw).render()


def gawain(**kw) -> Canvas:
    return C7.gawain_frame(**kw).render()


def mordred(**kw) -> Canvas:
    return C7.mordred_frame(**kw).render()


def shadow_knight(**kw) -> Canvas:
    return C7.sk_frame(**kw).render()


def kraken(**kw) -> Canvas:
    return C7.kraken_frame(**kw).render()


def drop_parts(f: Fig, pids) -> Fig:
    """Removes whole parts (by part id) from a rig figure - e.g. a dragon's own tail."""
    for p in [p for p, o in f.owner.items() if o in pids]:
        del f.owner[p]
        f.col.pop(p, None)
    return f


def dragon(kind: str, tail: bool = True, **kw) -> Canvas:
    f = C7.dragon_frame(kind, **kw)
    if not tail:
        drop_parts(f, {1, 2})        # parts: far wing (0), tail (1), tail tip (2)
    return f.render()


def tube_pixels(pts, r0: float, r1: float, ramp) -> dict:
    """Pixels of a tapering tube along pts, shaded like a cylinder lit from above: light top edge, dark underside."""
    out: dict = {}
    best: dict = {}
    n = len(pts) - 1
    for i in range(n):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        dx, dy = bx - ax, by - ay
        ln = math.hypot(dx, dy) or 1.0
        ux, uy = dx / ln, dy / ln
        nx, ny = -uy, ux
        if ny < 0:
            nx, ny = -nx, -ny
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        for (x, y) in capsule(ax, ay, bx, by, max(ra, rb)):
            px, py = x + 0.5 - ax, y + 0.5 - ay
            t = max(0.0, min(1.0, (px * ux + py * uy) / ln))
            r = ra + (rb - ra) * t
            cx, cy = ax + dx * t, ay + dy * t
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d > r + 0.35:
                continue
            if (x, y) in best and best[(x, y)] <= d / r:
                continue
            best[(x, y)] = d / r
            s = ((x + 0.5 - cx) * nx + (y + 0.5 - cy) * ny) / max(0.5, r)
            k = len(ramp) - 1 if s < -0.4 else (len(ramp) - 2 if s < 0.2 else (1 if s < 0.65 else 0))
            out[(x, y)] = ramp[max(0, k)]
    return out


def dragon_tail(fig: Fig, kind: str, pts, r0: float = 3.8, r1: float = 1.2, stripes: bool = False) -> None:
    """A long custom dragon tail along pts (base first): a tapering tube in the dragon's skin, its own tip."""
    S_ = C7.DRAGONS[kind]
    skin = S_["skin"]
    pix = tube_pixels(pts, r0, r1, skin.ramp[:3] + [skin.ramp[-1]] if len(skin.ramp) > 3 else skin.ramp)
    if stripes:
        for (x, y) in list(pix):
            if (x, y + 1) not in pix and x % 4 == 0:
                pix[(x, y)] = S_["seg"]
    ex, ey = pts[-1]
    px, py = pts[-2]
    ln = math.hypot(ex - px, ey - py) or 1.0
    ux, uy = (ex - px) / ln, (ey - py) / ln
    nx, ny = -uy, ux
    tip = poly([(ex - ux + nx * 2.4, ey - uy + ny * 2.4), (ex + ux * 4.5, ey + uy * 4.5),
                (ex - ux - nx * 2.4, ey - uy - ny * 2.4)])
    fig.pix(pix, skin)
    fig.add(tip, skin if kind == "red" else S_["horn"], bias=0.15)


def braid(c: Canvas, a: tuple, b: tuple, amp: float, turns: int, seed: int) -> None:
    """Two dragon tails twisted together between the hips a (red) and b (white), tips curling up at the ends;
    at each crossing one strand clearly passes over the other (red, white, red...)."""
    def strand(kind: str, sign: int) -> Canvas:
        f = Fig(W, H, seed=seed + (1 if kind == "red" else 2))
        n = 18
        pts = []
        for i in range(n + 1):
            t = i / n
            x = a[0] + (b[0] - a[0]) * t
            y = a[1] + (b[1] - a[1]) * t + sign * amp * math.sin(t * math.pi * turns)
            pts.append((x, y))
        if kind == "white":
            pts = pts[::-1]
        ex, ey = pts[-1]
        d = 1 if kind == "red" else -1
        pts += [(ex + d * 4, ey - 2), (ex + d * 5, ey - 8)]
        dragon_tail(f, kind, pts, 3.0, 1.3)
        return f.render()

    red = strand("red", 1)
    wht = strand("white", -1)
    c.blit(red, 0, 0)
    c.blit(wht, 0, 0)
    span = b[0] - a[0]
    for j in range(1, turns):
        if j % 2 == 0:
            continue
        x0 = int(a[0] + span * (j - 0.5) / turns)
        x1 = int(a[0] + span * (j + 0.5) / turns)
        for y in range(H):
            for x in range(x0, x1):
                p = red.get(x, y)
                if p is not None and p[3] > 0:
                    c.set(x, y, p)


# ==========================================================================
# scenery
# ==========================================================================

def sky_day(c: Canvas, y1: int, seed: int) -> None:
    K.sky_bands(c, 0, y1, [("azure", 0.0), ("sky_l", 0.45), ("haze", 0.82)], seed=seed)


def avalon_sky(c: Canvas, hz: int, seed: int) -> None:
    K.sky_bands(c, 0, hz, [("dusk", 0.0), ("rose", 0.25), ("coral", 0.47), ("peach", 0.67), ("cream", 0.86)],
                seed=seed, wave=1.3)


def sea_cutaway(c: Canvas, y0: int, bands, seed: int) -> list[int]:
    """Water seen through a storybook cut: a wavy bright surface line at y0, deepening bands below."""
    tops = []
    for x in range(W):
        t = y0 + int(round(math.sin(x / 6.0 + seed) * 1.2))
        tops.append(t)
    span = H - y0
    for x in range(W):
        for y in range(tops[x] + 1, H):
            tt = (y - y0 + 1.5 * math.sin(x / 11.0 + y * 0.2 + seed)) / span
            col = bands[0][0]
            for n, t0 in bands:
                if tt >= t0:
                    col = n
            c.set(x, y, col)
        c.set(x, tops[x], "white" if x % 7 else "sky_l")
        c.set(x, tops[x] + 1, "sky_l" if (x // 3) % 2 else K.lt(bands[0][0]))
    return tops


def shoreline(c: Canvas, x0: int, x1: int, base, seed: int, wet: str = "dirt", foam=("white", "sky_l")) -> None:
    """Foam edge where waves meet the sand: base(x) is the waterline y."""
    for x in range(x0, x1):
        y = base(x)
        c.set(x, y, foam[0])
        c.set(x, y + 1, foam[1] if (x + seed) % 4 else foam[0])
        c.set(x, y + 2, wet)
        if (x + seed) % 5 < 3:
            c.set(x, y + 3, wet)


def underwater_hall(c: Canvas, seed: int, weeds=(0, 50, 98, 146)) -> None:
    """The sunken palace: blue-green stone arches and columns, light falling from above, a tiled floor."""
    K.sky_bands(c, 0, H, [("water", 0.0), ("water_d", 0.35), ("night", 0.75)], seed=seed, wave=1.2)
    wall = K.masonry(W, 70, ("water_d", "water", "sky"), seed + 1, course=8, brick=(10, 18), mortar="night", base_dark=0)
    c.blit(wall, 0, 0)
    for ax in (8, 56, 104):
        for y in range(10, 70):
            for x in range(ax, ax + 48):
                dxn = (x + 0.5 - ax - 24) / 18
                top = 26 - math.sqrt(max(0.0, 1 - dxn * dxn)) * 16
                if abs(x + 0.5 - ax - 24) < 18 and y >= top:
                    c.set(x, y, "night" if y < 40 else "water_d")
        for x in range(ax + 6, ax + 42):
            dxn = (x + 0.5 - ax - 24) / 18
            top = int(26 - math.sqrt(max(0.0, 1 - dxn * dxn)) * 16)
            c.set(x, top - 1, "sky_l")
            c.set(x, top - 2, "azure")
    for px in (0, 50, 98, 146):
        col = Canvas(14, 80)
        col.rect(0, 0, 14, 80, "sky")
        col.rect(0, 0, 3, 80, "azure")
        col.rect(10, 0, 4, 80, "water")
        col.rect(0, 0, 14, 4, "sky_l")
        col.rect(0, 74, 14, 6, "water_d")
        col.outline_all("night")
        c.blit(col, px - 2, -2)
        if px in weeds:
            seaweed(c, px + 1, 76, 24 + (px % 3) * 6, px + seed, ("teal", "grass", "forest"))
    for y in range(76, H):
        for x in range(W):
            c.set(x, y, "water_d" if (x // 12 + y // 6) % 2 else "night")
    for x in range(W):
        c.set(x, 76, "water")


def sunken_city(c: Canvas, cx: int, base: int, seed: int) -> None:
    """Lyonesse under the sea: pale blue towers, domes and spires with warm lit windows."""
    city = Canvas(W, 44)
    rng = random.Random(seed)
    parts = [(-34, 9, 9, "flat"), (-26, 10, 15, "dome"), (-16, 6, 21, "spire"), (-10, 12, 13, "dome"),
             (1, 8, 25, "spire"), (9, 12, 15, "dome"), (21, 6, 19, "spire"), (26, 10, 10, "dome"), (34, 8, 7, "flat")]
    lb = 43
    for (dx, w, h, kind) in parts:
        x0, top = cx + dx - w // 2, lb - h
        for y in range(top, lb + 1):
            for x in range(x0, x0 + w):
                city.set(x, y, "sky" if x < x0 + 2 else ("water_d" if x > x0 + w - 3 else "water"))
        if kind == "dome":
            for (x, y) in P.ellipse(x0 + w / 2, top + 0.5, w / 2, w / 2.6):
                if y <= top:
                    city.set(x, y, "sky_l" if x < x0 + w / 2 - 1 else "sky")
            city.set(int(x0 + w / 2), int(top - w / 2.6) - 1, "yellow")
        elif kind == "spire":
            sh = w + 5
            for k in range(sh):
                half = (k / sh) * (w / 2)
                for x in range(int(round(x0 + w / 2 - half)), int(round(x0 + w / 2 + half))):
                    city.set(x, top - sh + k, "sky_l" if x < x0 + w / 2 else "sky")
            city.set(int(x0 + w / 2), top - sh - 1, "yellow")
        for wy in range(top + 3, lb - 2, 4):
            for wx in range(x0 + 2, x0 + w - 2, 3):
                if rng.random() < 0.7:
                    city.set(wx, wy, "yellow" if rng.random() < 0.7 else "white")
                    city.set(wx, wy + 1, "amber")
    city.outline_all("night")
    c.blit(city, 0, base - lb)


def granary(c: Canvas, x0: int, base: int) -> None:
    """The royal granary: plank walls, a gable roof, both doors flung open on an empty inside."""
    w, wall_h = 76, 36
    g = Canvas(w + 12, wall_h + 30)
    roof_top = 2
    for k in range(28):
        half = (k / 27) * (w / 2 + 6)
        y = roof_top + k
        for x in range(int(w / 2 + 6 - half), int(w / 2 + 6 + half) + 1):
            g.set(x, y, "red_d" if x > w / 2 + 6 else "red")
        if k % 4 == 3:
            for x in range(int(w / 2 + 6 - half), int(w / 2 + 6 + half) + 1):
                g.set(x, y, "wine" if x > w / 2 + 6 else "red_d")
    wall_top = roof_top + 27
    for y in range(wall_top, wall_top + wall_h):
        for x in range(6, w + 6):
            g.set(x, y, "brown" if (x // 5) % 2 else "gold_d")
            if x % 5 == 0:
                g.set(x, y, "brown_d")
    # gable triangle in planks with a round sign (a bone)
    for k in range(10, 27):
        half = (k / 27) * (w / 2 + 6) - 6
        for x in range(int(w / 2 + 6 - half), int(w / 2 + 6 + half) + 1):
            g.set(x, roof_top + k, "brown" if (x // 4) % 2 else "gold_d")
    for (x, y) in P.ellipse(w / 2 + 6, roof_top + 20, 6, 5):
        g.set(x, y, "cream")
    bone(g, int(w / 2 + 3), roof_top + 18, col="white", dark="stone_l")
    # doorway: dark, empty, with bare shelves and empty hooks
    dx0, dx1, dy0 = 22, w - 10, wall_top + 6
    for y in range(dy0, wall_top + wall_h):
        for x in range(dx0, dx1):
            g.set(x, y, "umber" if y < dy0 + 14 else "brown_d")
    for sy in (dy0 + 8, dy0 + 17):
        g.hline(dx0, dx1 - 1, sy, "brown")
        g.hline(dx0, dx1 - 1, sy + 1, "ink")
    for hx in range(dx0 + 4, dx1 - 2, 7):
        g.set(hx, dy0 + 2, "steel_d")
        g.set(hx, dy0 + 3, "steel_d")
        g.set(hx + 1, dy0 + 4, "steel_d")
    sack = P.ellipse(dx1 - 9, wall_top + wall_h - 3, 6, 3)
    P.fill(g, sack, "sand")
    for (x, y) in sack:
        if y < wall_top + wall_h - 4:
            g.set(x, y, "cream")
    g.set(dx1 - 9, wall_top + wall_h - 6, "dirt")
    g.set(dx0 + 6, wall_top + wall_h - 1, "gold_l")
    # the open doors swung out to both sides
    for (side, xa) in ((-1, dx0), (1, dx1)):
        for k in range(10):
            xx = xa - 1 - k if side < 0 else xa + k
            sk = k // 3
            for y in range(dy0 - sk, wall_top + wall_h + sk // 2):
                g.set(xx, y, "gold_d" if k % 3 else "brown")
            g.set(xx, dy0 - sk + 6, "brown_d")
            g.set(xx, wall_top + wall_h - 6, "brown_d")
    g.outline_all("umber")
    c.blit(g, x0 - 6, base - wall_top - wall_h)


def villager(pal: dict, eyes: str = "open", mouth: str = "o", bowl_cols=("red_d", "red", "coral"), bob: int = 0,
             head_dy: int = 0) -> Canvas:
    """A Camelot dog holding out an empty bowl (a recoloured Goldie rig, no sword)."""
    img = GD.goldie_frame(eyes=eyes, mouth=mouth, sword_on=False, arm_to=(21.0, 19.0), bob=bob, head_dy=head_dy,
                          cape_wave=0.4).render()
    img = S.recolor(img, pal) if pal else img
    bowl(img, 19, 16 + bob, bowl_cols)
    return img


TOWN_DOGS = [
    {"gold_l": "white", "gold": "stone_l", "gold_d": "stone", "brown": "stone_d", "red": "sky", "red_d": "water",
     "wine": "water_d", "coral": "sky_l"},
    {"gold_l": "gold_d", "gold": "brown", "gold_d": "brown_d", "brown": "umber", "red": "leaf", "red_d": "leaf_d",
     "coral": "leaf_l", "wine": "forest"},
    {"gold_l": "steel_l", "gold": "steel", "gold_d": "steel_d", "brown": "iron", "red": "orange", "red_d": "gold_d",
     "coral": "amber", "wine": "brown"},
    {"gold_l": "cream", "gold": "sand", "gold_d": "dirt", "brown": "brown", "red": "violet", "red_d": "plum",
     "coral": "lilac", "wine": "plum"},
]


def two_face_mountain(c: Canvas, cx: float, peak: int, base: int, half: float, seed: int, fire_on: bool = True,
                      smoke: bool = True, far: bool = False) -> None:
    """The dragons' mountain: snow-white on the left, red rock with lava on the right (`far`: hazy colours)."""
    snow = ("sky_l", "azure", "fog") if far else ("white", "fog", "ash")
    rock = ("rose", "dusk") if far else ("red_d", "wine")
    for y in range(peak, base):
        dy = y - peak
        t = dy / max(1, base - peak)
        hl = 2 + t * half + math.sin(y / 3.7 + seed) * 1.2
        hr = 2 + t * half * 0.95 + math.sin(y / 3.1 + seed) * 1.2
        ridge = cx + dy * 0.08 + math.sin(y / 4.5) * 1.0
        for x in range(int(cx - hl), int(cx + hr) + 1):
            if not 0 <= x < W:
                continue
            if x < ridge:
                f = (ridge - x) / max(1.0, ridge - (cx - hl))
                col = snow[0] if f > 0.5 else (snow[1] if f > 0.18 else snow[2])
            else:
                f = (x - ridge) / max(1.0, cx + hr - ridge)
                col = rock[0] if f < 0.35 else rock[1]
            c.set(x, y, col)
    # a few rock ribs showing through the snow, lava running down the hot side
    for k, (fx, fy) in enumerate(((0.55, 0.35), (0.75, 0.6), (0.4, 0.7))):
        rx_ = int(cx - fx * half * fy)
        ry_ = int(peak + fy * (base - peak))
        for j in range(4 + k):
            c.set(rx_ - j // 2, ry_ + j, snow[2])
            c.set(rx_ - j // 2 + 1, ry_ + j, "slate" if not far else "ash")
    for k in range(3):
        x = cx + 2 + k * 3
        for y in range(peak + 4 + k * 6, base - 2):
            x += 0.25 + 0.35 * math.sin(y / 3.0 + k)
            if 0 <= int(x) < W and name_at(c, int(x), y) in rock:
                c.set(int(x), y, ("orange" if y % 4 else "yellow") if not far else ("coral" if y % 3 else "peach"))
    if smoke:
        for i in range(12):
            t = i / 11
            x, y = cx + 3 + t * 26, peak - 4 - t * 18 + math.sin(t * 5) * 2
            r = 2.0 + t * 4.5
            for (qx, qy) in P.ellipse(x, y, r, r * 0.8):
                if 0 <= qx < W and 0 <= qy < H:
                    c.set(qx, qy, "stone" if qy < y - r * 0.2 else "stone_d")
    if fire_on:
        fire(c, cx + 1, peak + 2, 10 if not far else 7, 4 if not far else 3, seed + 3, lean=0.3)


def dragon_nest(c: Canvas, seed: int, clear: bool = False) -> None:
    """The top of the dragons' mountain: a snowy peak on the left, a volcanic one on the right, the plateau's
    ground half snow, half dark rock."""
    if clear:
        K.sky_bands(c, 0, 76, [("sky", 0.0), ("azure", 0.35), ("sky_l", 0.65), ("haze", 0.88)], seed=seed)
    else:
        K.sky_bands(c, 0, 76, [("dusk", 0.0), ("rose", 0.35), ("peach", 0.7), ("cream", 0.9)], seed=seed)
    K.peaks_layer(c, 76, [(8, 34, 30), (44, 22, 26)], "white", "fog", rim="white", seed=seed + 1, x0=0, x1=80,
                  rough=1.0)
    K.peaks_layer(c, 76, [(120, 28, 30), (158, 36, 28)], "rose" if clear else "red_d", "dusk" if clear else "wine",
                  rim="coral", seed=seed + 2, x0=80, rough=1.0)
    if not clear:
        for i in range(8):
            t = i / 7
            x, y = 158 - t * 6, 40 - t * 30
            for (qx, qy) in P.ellipse(x, y, 2 + t * 4, 2 + t * 3):
                if 0 <= qx < W and 0 <= qy < H:
                    c.set(qx, qy, "stone_d" if qy > y else "stone")
    for y in range(74, H):
        edge = 80 + 5 * math.sin(y / 7.0)
        for x in range(W):
            t = (y - 74) / (H - 74)
            if x < edge:
                col = "white" if t < 0.35 else ("fog" if t < 0.75 else "ash")
            else:
                col = "stone_d" if t < 0.35 else ("slate" if t < 0.75 else "iron")
            c.set(x, y, col)
    for x in range(W):
        c.set(x, 74, "sky_l" if x < 80 else "stone")
    rng = random.Random(seed + 3)
    for _ in range(14):
        x, y = rng.randrange(4, W - 8), rng.randrange(80, H - 4)
        if x < 78:
            c.stamp([".ww.", "wwww"], x, y, {"w": "white"}, outline=None)
            c.hline(x, x + 3, y + 2, "ash")
        else:
            c.stamp([".s.", "sss"], x, y, {"s": "stone"}, outline="iron")


def army(c: Canvas, x0: int, x1: int, base: int, seed: int, rows: int = 2, flags: int = 4) -> None:
    """A far-off shadow army: rows of helmeted soldiers with tower shields and spears, glowing eyes, black wolf
    banners above them."""
    rng = random.Random(seed)
    man = ["..h..", ".hhh.", ".hlh.", "sbbb.", "sbbb.", "sb.b."]
    for i in range(flags):
        fx = int(x0 + (i + 0.5) * (x1 - x0) / flags) + rng.randrange(-4, 5)
        wolf_flag(c, fx, base - 6, pole=16, w=10, h=7)
    for r in range(rows):
        y = base - 6 - (rows - 1 - r) * 4
        x = x0 + (r % 2) * 3
        body = "ink" if r == rows - 1 else "navy"
        while x < x1:
            c.stamp(man, x, y, {"h": body, "b": body, "l": "lilac", "s": "iron" if r == rows - 1 else "night_d"},
                    outline=None)
            if rng.random() < 0.45:
                c.vline(x + 4, y - 5, y + 5, "iron")
                c.set(x + 4, y - 6, "steel")
            x += 5 + rng.randrange(0, 2)
    for y in range(base, base + 3):
        for x in range(x0 - 4, x1 + 4):
            if 0 <= x < W and (y < base + 2 or (x + y) % 2):
                c.set(x, y, "plum" if y > base else "ink")


def arch_window(c: Canvas, x: int, y: int, w: int, h: int, sky=("azure", "sky_l", "haze")) -> set:
    """A tall arched window opening onto a bright afternoon sky; returns its glass area."""
    glass = set()
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            dxn = (xx + 0.5 - x - w / 2) / (w / 2)
            if yy >= y + (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * (w / 2):
                glass.add((xx, yy))
    for (xx, yy) in glass:
        t = (yy - y) / h
        c.set(xx, yy, sky[0] if t < 0.35 else (sky[1] if t < 0.75 else sky[2]))
    for k in range(3):
        cx_, cy_ = x + 6 + k * 9, y + h - 10 - (k % 2) * 6
        for (px, py) in P.ellipse(cx_, cy_, 4, 2):
            if (px, py) in glass:
                c.set(px, py, "white")
    frame_ = {(xx + dx, yy + dy) for (xx, yy) in glass for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1))} - glass
    for (xx, yy) in frame_:
        c.set(xx, yy, "gold_d")
    outer = {(xx + dx, yy + dy) for (xx, yy) in frame_ for (dx, dy) in ((1, 0), (-1, 0), (0, -1))} - glass - frame_
    for (xx, yy) in outer:
        c.set(xx, yy, "umber")
    c.rect(x - 3, y + h, w + 6, 3, "gold")
    c.hline(x - 3, x + w + 2, y + h, "gold_l")
    c.hline(x - 3, x + w + 2, y + h + 3, "umber")
    return glass


def great_hall(c: Canvas) -> None:
    """Camelot's great hall on a sunny afternoon: warm stone, two tall windows, a crown banner, bunting."""
    K.sky_bands(c, 0, H, [("umber", 0.0), ("brown_d", 0.35), ("plum", 0.75)], seed=3, wave=1.0)
    wall = K.masonry(W, 78, ("brown_d", "brown", "gold_d"), 7, course=7, mortar="umber", base_dark=0)
    c.blit(wall, 0, 0)
    for px in (-4, 150):
        pil = Canvas(14, H)
        pil.rect(0, 0, 14, H, "brown")
        pil.rect(0, 0, 3, H, "gold_d")
        pil.rect(10, 0, 4, H, "brown_d")
        pil.outline_all("ink")
        c.blit(pil, px, 0)
    for y in range(78, H):
        for x in range(W):
            c.set(x, y, "brown_d" if (x // 10 + y // 6) % 2 else "umber")


# ==========================================================================
# chapter 4: the sunken kingdom
# ==========================================================================

def teaser_3() -> Canvas:
    """Chapter 4 teaser: the sea at sunset; far beneath the waves a sunken city glows."""
    c = page("navy")
    hz = 40
    K.sky_bands(c, 0, hz, [("dusk", 0.0), ("rose", 0.32), ("coral", 0.6), ("amber", 0.82), ("peach", 0.93)],
                seed=41, wave=1.0)
    for (x0, y, w, col) in ((6, 12, 44, "rose"), (92, 8, 56, "rose"), (24, 25, 30, "coral"), (100, 21, 40, "coral")):
        for x in range(x0, x0 + w):
            c.set(x, y, col)
            if x0 + 4 < x < x0 + w - 5:
                c.set(x, y - 1, K.lt(col))
    T.sun_glow(c, 112, hz, rings=((7, "white"), (10, "cream"), (16, "yellow")), only=("amber", "peach", "coral"))
    WD.water_bands(c, (0, hz, W, 60), [("peach", 0.0), ("coral", 0.18), ("rose", 0.5), ("dusk", 0.82)], 4101,
                   glints=("cream", "peach"), n_glints=26)
    reflection(c, 112, hz + 1, 60, 3, 0.5, seed=4105)
    # a tiny boat with a blue pennant on the far water
    c.stamp(["....b", "...bb", "...m.", "hhhhhh", ".hhhh."], 38, hz - 3, {"b": "sky", "m": "umber", "h": "dusk"},
            outline=None)
    water = ("water", "water_d", "night", "night_d", "navy")
    sea_cutaway(c, 60, [("water", 0.0), ("water_d", 0.16), ("night", 0.45), ("night_d", 0.78)], 4102)
    for (x0, w0) in ((148, 2), (124, 3), (40, 2), (18, 3)):
        ray(c, x0, 63, x0 - 30, 112, w0, w0 + 4)
    # the glow of the city rising through the water
    glow_bands(c, 80, 104, [50, 36, 24], sy=0.62, only=water)
    glow_bands(c, 80, 84, [9, 5], sy=2.6, only=water + ("sky",))
    sunken_city(c, 80, 112, 4103)
    for (x, y) in ((50, 86), (76, 76), (108, 84), (64, 96), (96, 92), (82, 66)):
        sparkle(c, x, y, "sky_l", "white")
    # sea floor, weed and coral at the sides
    for x in range(W):
        top = 112 + int(2 * math.sin(x / 9.0) + math.sin(x / 3.7))
        for y in range(top, H):
            c.set(x, y, "deep" if y > top else "teal")
    for (x, h) in ((6, 30), (16, 20), (140, 26), (150, 34)):
        seaweed(c, x, 116, h, x)
    coral(c, 30, 114, 1)
    coral(c, 128, 114, 2, ("dusk", "rose", "pink"))
    for (x, y, f) in ((24, 72, False), (132, 78, True), (120, 68, True), (36, 90, False)):
        fish(c, x, y, "night" if y > 80 else "water_d", f)
    for (x, y, r) in ((78, 64, 1), (84, 70, 2), (80, 78, 1), (86, 58, 1), (74, 88, 1)):
        bubble(c, x, y, r)
    S.vignette(c, density=0.5)
    return c


def c4_prologue_1() -> Canvas:
    """Camelot's dogs hold out empty bowls; the granary doors stand open on an empty inside."""
    c = page("sky")
    K.sky_bands(c, 0, 70, [("azure", 0.0), ("sky_l", 0.45), ("haze", 0.8)], seed=42)
    WD.cloud_bank(c, 18, ("sky_l", "white", "white"), 4201, size=(4.0, 7.0), step=18)
    T.castle(c, 104, 56, 0.9, wall=("stone", "stone_l", "white"), roof=("red_d", "red", "coral"))
    roofs = Canvas(W, 40)
    WD.house_row(roofs, 40, 70, W + 6, 4202, [("stone", "stone_l", "white"), ("dirt", "sand", "cream")],
                 [("red_d", "red", "coral"), ("brown_d", "brown", "gold_d")], heights=(16, 22), widths=(22, 28),
                 thorns=0.0, lit=0.0, timber=0.6, gables=0.5)
    c.blit(roofs, 0, 36)
    K.cobbles(c, (0, 80, W, H), ("dirt", "sand", "dirt"), "gold_d", 4203)
    granary(c, 4, 82)
    shade(c, 44, 83, 40, 3, only=("dirt", "sand", "gold_d"))
    # the townsfolk with their empty bowls, the king in the middle
    spots = [(0, 3, 84, False, 0), (1, 120, 78, True, 1), (2, 100, 86, True, 2), (3, 130, 94, True, 3)]
    for (i, x, y, fl, k) in spots:
        img = villager(TOWN_DOGS[i], eyes="open" if k % 2 else "squint", mouth="o",
                       bowl_cols=[("water_d", "water", "sky"), ("red_d", "red", "coral"), ("leaf_d", "leaf", "leaf_l"),
                                  ("brown_d", "brown", "gold_d")][k])
        shade(c, x + 15 if not fl else x + 16, y + 30, 9, 2, only=("dirt", "sand", "gold_d"))
        c.blit(img.flipped() if fl else img, x, y)
    bdv = bedivere(eyes="open", mouth="frown")
    shade(c, 62, 113, 10, 2, only=("dirt", "sand", "gold_d"))
    c.blit(bdv.flipped(), 46, 84)
    bowl(c, 46, 98, ("gold_d", "gold", "yellow"))
    gol = goldie(eyes="open", mouth="o", arm_to=(21.0, 18.5), cape_wave=0.6)
    shade(c, 83, 112, 10, 2, only=("dirt", "sand", "gold_d"))
    c.blit(gol.flipped(), 68, 78)
    bowl(c, 69, 95, ("water_d", "water", "sky"))
    sweat(c, 74, 82)
    sweat(c, 140, 80)
    exclaim(c, 106, 76)
    # a lone fly circling an empty bowl
    for (x, y) in ((10, 96), (12, 94), (15, 95)):
        c.set(x, y, "ink")
    c.set(11, 93, "white")
    S.vignette(c, density=0.35)
    return c


def c4_prologue_2() -> Canvas:
    """Dusk on the beach: a corgi with a harp on his back drifts ashore in a little boat."""
    c = page("peach")
    hz = 50
    K.sky_bands(c, 0, hz, [("dusk", 0.0), ("rose", 0.3), ("coral", 0.58), ("peach", 0.8), ("cream", 0.93)],
                seed=43, wave=1.2)
    WD.cloud_bank(c, 26, ("rose", "coral", "peach"), 4301, x0=-6, x1=64, size=(3.5, 6.0), step=12)
    WD.cloud_bank(c, 16, ("dusk", "rose", "coral"), 4306, x0=104, x1=W + 8, size=(3.0, 5.0), step=12)
    T.sun_glow(c, 30, hz, rings=((6, "white"), (9, "cream"), (14, "yellow")), only=("peach", "cream", "coral"))
    WD.water_bands(c, (0, hz, W, H), [("peach", 0.0), ("coral", 0.1), ("rose", 0.3), ("dusk", 0.62)], 4302,
                   glints=("peach", "pink"), n_glints=40)
    reflection(c, 30, hz + 1, 104, 2, 0.32, seed=4307)
    for (x, y) in ((112, 14), (122, 20), (54, 10)):
        c.stamp(["d...d", ".d.d.", "..d.."], x, y, {"d": "plum"}, outline=None)
    # the beach (bottom right) with its foam edge
    shore = lambda x: int(126 - (x - 30) * 0.27 + math.sin(x / 8.0) * 1.2)  # noqa: E731
    for x in range(W):
        for y in range(max(0, shore(x)), H):
            c.set(x, y, "sand")
    K.soft_patches(c, (0, 86, W, H), "peach", 4303, cover=0.3, only=("sand",))
    shoreline(c, 0, W, shore, 4304, wet="dirt", foam=("white", "cream"))
    for x in range(40, W, 2):
        c.set(x, shore(x) - 4, "pink" if x % 6 else "peach")
    # the boat with Tristan, harp on his back, reaching toward the shore
    tri = tristan(eyes="happy", mouth="sing", paw=(25.0, 16.5), feather=1.0, cape_wave=0.6, ear_dy=-1)
    c.blit(tri.scaled(2), 36, 36)
    boat(c, 30, 84, 70, 13)
    for y in range(99, 104):
        for x in range(36 + (y - 99) * 2, 94 - (y - 99) * 3):
            if (x + y) % 3:
                P.darken(c, x, y, 1)
    for (x0, y, n) in ((22, 96, 6), (98, 92, 5), (26, 101, 4), (102, 98, 6), (60, 104, 7)):
        dashes(c, [(x0, y, 1, 0, n)], "cream")
    shell(c, 112, 110)
    starfish(c, 140, 104)
    shell(c, 150, 96)
    S.vignette(c, density=0.35)
    return c


def c4_ending_1() -> Canvas:
    """The sunken palace: the kraken curls into a shy ball as the black sigil breaks into light; Goldie holds out
    a bone."""
    c = page("water_d")
    underwater_hall(c, 4401, weeds=(0, 50, 146))
    for (x0, w0) in ((100, 3), (124, 2), (72, 2)):
        ray(c, x0, 0, x0 - 24, 76, w0, w0 + 7)
    glow_bands(c, 106, 72, [34, 22], sy=0.8)
    kr = C7.kraken_down(1)
    shade(c, 104, 103, 24, 3)
    c.blit(kr, 72, 46)
    # the broken sigil: dark shards flying out, turning into points of light
    rng = random.Random(4402)
    for i in range(18):
        a = rng.uniform(-math.pi * 0.95, -0.1)
        d = rng.uniform(9, 28)
        x, y = int(105 + math.cos(a) * d), int(60 + math.sin(a) * d * 0.8)
        if d < 15:
            c.stamp(["k.", "kk"] if i % 2 else ["kk", ".k"], x, y, {"k": "ink"}, outline=None)
            c.set(x + 1, y, "violet")
        elif i % 3 == 0:
            sparkle(c, x, y, "lilac", "white")
        else:
            c.set(x, y, "white" if i % 2 else "lilac")
    gol = goldie(eyes="happy", mouth="smile", arm_to=(23.5, 17.5), lean=1.0, cape_wave=0.6)
    shade(c, 54, 107, 11, 2)
    c.blit(gol, 38, 75)
    bone(c, 59, 94)
    tri = tristan(eyes="open", mouth="smile")
    bdv = bedivere(eyes="open", mouth="frown")
    shade(c, 32, 102, 9, 2)
    shade(c, 16, 107, 9, 2)
    c.blit(tri, 18, 70)
    c.blit(bdv, 0, 76)
    bubbles(c, (8, 10, 150, 66), 14, 4403)
    for (x, y) in ((44, 72), (50, 66), (56, 70)):
        bubble(c, x, y, 1)
    S.vignette(c, density=0.45)
    return c


def c4_ending_2() -> Canvas:
    """A party on the beach around the shining golden dog bowl; the kraken waves from the sea."""
    c = page("sky")
    hz = 38
    K.sky_bands(c, 0, hz, [("azure", 0.0), ("sky_l", 0.5), ("haze", 0.85)], seed=44)
    WD.cloud_bank(c, 20, ("sky_l", "white", "white"), 4501, x0=-10, x1=90, size=(4.0, 7.0), step=20)
    WD.water_bands(c, (0, hz, W, 66), [("sky", 0.0), ("water", 0.3), ("sky", 0.75)], 4502,
                   glints=("white", "sky_l"), n_glints=36)

    def wave_arm(f: Fig) -> None:
        C7.draw_tentacle(f, [(44, 36), (51, 31), (55, 22), (56, 13), (53, 9), (51, 11)], C7.OCTO, 3.6, 1.3, bias=0.1)

    kr = kraken(eyes="open", mouth="smile", sigil=False, bob=0, curl=0.6, extra=wave_arm)
    c.blit(kr, 92, 6)
    WD.water_bands(c, (86, 52, 156, 66), [("water", 0.0), ("sky", 0.6)], 4503, glints=("white", "sky_l"),
                   n_glints=12)
    for x in range(96, 150):
        y = 52 + int(math.sin(x / 3.0) * 0.8)
        c.set(x, y, "white")
        c.set(x, y + 1, "sky_l")
    shore = lambda x: int(66 + math.sin(x / 10.0) * 1.5)  # noqa: E731
    for x in range(W):
        for y in range(shore(x), H):
            c.set(x, y, "sand")
    K.soft_patches(c, (0, 66, W, H), "cream", 4504, cover=0.25)
    shoreline(c, 0, W, shore, 4505)
    # bunting from a pole to a striped parasol
    c.vline(6, 18, 80, "brown")
    c.vline(7, 18, 80, "brown_d")
    c.vline(84, 30, 76, "brown_d")
    for k in range(-12, 13):
        y = 30 - int(5 * (1 - (k / 12) ** 2) ** 0.5 * 2)
        for yy in range(y, 31):
            c.set(84 + k, yy, "red" if ((k + 12) // 4) % 2 else "white")
    P.outline_shape(c, {(84 + k, y) for k in range(-12, 13) for y in range(20, 31)
                        if 30 - int(5 * (1 - (k / 12) ** 2) ** 0.5 * 2) <= y}, "red_d")
    cols = ["red", "yellow", "sky", "leaf", "pink", "orange"]
    for k in range(9):
        x = 11 + k * 8
        y = 19 + int(6 * math.sin(math.pi * (x - 7) / 66))
        c.stamp(["fff", ".f."], x, y, {"f": cols[k % len(cols)]}, outline="ink")
        c.set(x - 1, y - 1, "brown_d")
        c.set(x + 3, y - 1, "brown_d")
    # picnic blanket, the golden bowl, food
    for y in range(92, H):
        span = 56 + (y - 92) * 1.6
        for x in range(int(80 - span), int(80 + span)):
            if 0 <= x < W:
                c.set(x, y, "red" if ((x - 80) // 6 + (y - 92) // 4) % 2 else "white")
    glow_bands(c, 80, 84, [34, 22], sy=0.55, only=("sand", "cream", "dirt", "white", "red", "peach"))
    golden_bowl(c, 80, 84, 18, seed=4506)
    glitter(c, 80, 70, 16, 4507, 30, 12)
    for (x, y) in ((40, 106), (118, 106), (100, 112)):
        sausage(c, x, y)
    for (x, y) in ((58, 110), (128, 98)):
        bone(c, x, y)
    # the friends
    c.blit(merlin(glow=2), 0, 62)
    c.blit(bedivere_cheer(), 18, 78)
    gol = goldie(eyes="happy", mouth="open", arm_to=(20.5, 12.5), ear_dy=-1, cape_lift=0.3, tail_ang=100)
    c.blit(gol, 40, 64)
    tri = tristan_play(1)
    c.blit(tri.flipped(), 108, 70)
    note(c, 112, 62)
    note(c, 102, 54, "pink")
    heart(c, 30, 60)
    S.vignette(c, density=0.3)
    return c


def c4_ending_3() -> Canvas:
    """Moonlight on the cliffs: a cloaked Dobermann stands watching from the edge, far from the party."""
    c = page("navy")
    hz = 74
    K.sky_bands(c, 0, hz, [("navy", 0.0), ("night_d", 0.3), ("night", 0.72), ("water_d", 0.94)], seed=45, wave=1.0)
    S.stars(c, 30, 4601, (0, 0, W, 56))
    K.moon(c, 46, 30, 12, halo=("night", "water_d"))
    for (x0, y, w) in ((-4, 52, 60), (70, 60, 40), (16, 64, 50)):
        for x in range(x0, x0 + w):
            if 0 <= x < W:
                c.set(x, y, "water_d" if x < x0 + w * 0.7 else "night")
                if x0 + 4 < x < x0 + w - 8:
                    c.set(x, y - 1, "night")
    WD.water_bands(c, (0, hz, W, H), [("night", 0.0), ("night_d", 0.35), ("navy", 0.8)], 4603,
                   glints=("water_d", "night"), n_glints=40)
    reflection(c, 46, hz + 1, H, 2, 0.28, cols=("steel_l", "steel"), seed=4604)
    # a far spit of beach with the party's campfire
    for x in range(0, 40):
        top = hz - 1 - int(2 * math.sin(x / 13.0 * math.pi) if x < 26 else 0)
        for y in range(top, hz + 1):
            c.set(x, y, "slate" if y == top else "iron")
    for (x, y, col) in ((13, hz - 3, "orange"), (14, hz - 4, "yellow"), (15, hz - 3, "orange"), (14, hz - 3, "amber")):
        c.set(x, y, col)
    glow_bands(c, 14, hz - 3, [8, 4], sy=0.7, only=("navy", "night_d", "night", "slate", "iron", "water_d"))
    # the cliff on the right: moonlit edge, dark strata, grass on top
    edge = {}
    for y in range(54, H):
        t = (y - 54) / (H - 54)
        edge[y] = int(98 - 8 * math.sin(t * 2.6) + 3 * math.sin(y / 3.1) + t * 10)
    for y in range(54, H):
        x0 = edge[y]
        for x in range(x0, W):
            k = x - x0
            stratum = int(y + 3 * math.sin(x / 11.0)) % 10
            col = "ash" if k < 1 else ("slate" if k < 3 else ("iron" if stratum else "navy"))
            if k >= 3 and stratum == 1:
                col = "slate"
            c.set(x, y, col)
        c.set(x0 - 1, y, "ink")
    for (x, y0, ln) in ((112, 70, 9), (128, 86, 12), (146, 64, 8), (120, 104, 8)):
        for k in range(ln):
            c.set(x + (k % 3 == 2), y0 + k, "navy")
    for x in range(edge[54] - 1, W):
        c.set(x, 53, "teal")
        c.set(x, 52, "deep" if x % 3 else "teal")
        if x % 4 == 1:
            c.set(x, 51, "deep")
    mor = mordred(eyes="proud", mouth="smirk", cape_wave=1.0, cape_lift=0.6, scab_glow=190, hand=(28.0, 31.0),
                  sword_deg=-80, sword_len=9)
    c.blit(moonlit(mor.flipped(), side=(-1, -1), rim="steel_d"), 100, 8)
    # the wind
    for (x, y, n) in ((66, 22, 6), (78, 28, 4), (134, 8, 5), (150, 30, 4)):
        dashes(c, [(x, y, 1, 0, n)], "night")
    S.vignette(c, density=0.55)
    return c


def teaser_4() -> Canvas:
    """Chapter 5 teaser: a mountain half snow, half fire; the red and the white dragon peek out of the clouds."""
    c = page("navy")
    for y in range(H):
        for x in range(W):
            t = y / H
            cold = ["night_d", "night_d", "night", "water_d"][min(3, int(t * 4))]
            warm = ["plum", "wine", "red_d", "rose"][min(3, int(t * 4))]
            c.set(x, y, cold if x + 4 * math.sin(y / 9.0) < 80 else warm)
    S.stars(c, 18, 4706, (0, 0, 76, 50))
    glow_bands(c, 90, 26, [40, 22], sy=1.3, only=("plum", "wine", "red_d", "rose"), ramp=WARM, wob=2.0)
    # the mountain: a ragged peak, snow on the left, dark rock with lava on the right
    px_, py_ = 80, 34
    for y in range(py_, H):
        dy = y - py_
        half_l = dy * 1.15 + 3 + math.sin(y / 4.0) * 1.5
        half_r = dy * 1.05 + 3 + math.sin(y / 3.3 + 1) * 1.5
        ridge = px_ + 1 + dy * 0.1 + math.sin(y / 5.0) * 1.2
        for x in range(int(px_ - half_l), int(px_ + half_r) + 1):
            if not 0 <= x < W:
                continue
            if x < ridge:
                f = (ridge - x) / max(1.0, ridge - (px_ - half_l))
                col = "white" if f > 0.55 else ("fog" if f > 0.2 else "ash")
            else:
                f = (x - ridge) / max(1.0, px_ + half_r - ridge)
                col = "red_d" if f < 0.3 else ("wine" if f < 0.75 else "plum")
            c.set(x, y, col)
    for (rx_, ry_, s) in ((66, 58, 5), (54, 76, 6), (72, 84, 4)):
        for k in range(s):
            for j in range(-k, k + 1):
                c.set(rx_ + j, ry_ + k, "ash" if j < 0 else "slate")
        c.set(rx_, ry_ - 1, "white")
    for (x0, y0, k, ln) in ((83, 37, 0, 60), (92, 50, 1, 50), (104, 66, 2, 40)):
        x = float(x0)
        for y in range(y0, min(H, y0 + ln)):
            x += 0.3 + 0.45 * math.sin(y / 4.0 + k)
            c.set(int(x), y, "orange")
            c.set(int(x) + 1, y, "yellow" if y % 3 else "amber")
    # fire bursting from the summit
    fire(c, px_ + 1, py_ + 3, 22, 9, 4709, lean=0.3)
    fire(c, px_ + 7, py_ + 6, 12, 5, 4710, lean=0.5)
    # the dragons' heads peeking over the clouds, one big eye each
    wd = crop(dragon("white", eyes="sassy", mouth="smile"), 12, 2, 54, 34).scaled(2)
    rd = crop(dragon("red", eyes="open", mouth="smile"), 12, 2, 54, 34).scaled(2).flipped()
    c.blit(wd, -32, 30)
    c.blit(rd, 108, 30)

    def cloud_band(base: int, cols, x0: int, x1: int, seed: int) -> None:
        rng = random.Random(seed)
        x = x0
        while x < x1:
            r = rng.uniform(6.0, 10.0)
            blob = AW.blob_canvas(int(r * 2 + 4), int(r * 2 + 4), [(r + 2, r + 2, r)], list(cols), None, seed + int(x),
                                  light=(-0.3, -1.0, 0.6), texture=0.0)
            c.blit(blob, int(x - r), base - int(r * 1.5) + rng.randrange(0, 4))
            x += r * 1.3
        for y in range(base, H):
            for xx in range(x0, x1):
                if 0 <= xx < W:
                    c.set(xx, y, cols[1])

    cloud_band(90, ("ash", "fog", "white"), -6, 82, 4701)
    cloud_band(90, ("dusk", "rose", "peach"), 80, W + 8, 4702)
    cloud_band(108, ("slate", "ash", "fog"), -6, 82, 4703)
    cloud_band(108, ("wine", "dusk", "rose"), 80, W + 8, 4704)
    # snow falling on the left, embers rising on the right
    rng = random.Random(4705)
    for _ in range(70):
        x, y = rng.randrange(0, 78), rng.randrange(0, 86)
        if name_at(c, x, y) in ("night_d", "night", "water_d", "navy"):
            c.set(x, y, "white" if rng.random() < 0.6 else "sky_l")
    for _ in range(46):
        x, y = rng.randrange(86, W), rng.randrange(0, 86)
        if name_at(c, x, y) in ("plum", "wine", "red_d", "rose", "dusk"):
            c.set(x, y, "amber" if rng.random() < 0.5 else "yellow")
    S.vignette(c, density=0.5)
    return c


# ==========================================================================
# chapter 5: the red and the white dragon
# ==========================================================================

def c5_prologue_1() -> Canvas:
    """Camelot shakes: the square's cobbles crack, and the mountain in the north is smoking."""
    c = page("sky")
    sky_day(c, 70, 51)
    two_face_mountain(c, 44, 30, 60, 22, 5101, far=True)
    T.castle(c, 106, 58, 0.95, wall=("stone", "stone_l", "white"), roof=("red_d", "red", "coral"))
    roofs = Canvas(W, 40)
    WD.house_row(roofs, 40, -6, W + 6, 5102, [("stone", "stone_l", "white"), ("dirt", "sand", "cream")],
                 [("red_d", "red", "coral"), ("brown_d", "brown", "gold_d")], heights=(14, 20), widths=(22, 30),
                 thorns=0.0, lit=0.0, timber=0.6, gables=0.5)
    c.blit(roofs, 0, 40)
    cols = ["red", "yellow", "sky", "leaf", "pink"]
    for k in range(20):
        x = 2 + k * 8
        y = 50 + int(5 * math.sin(math.pi * x / 80.0) ** 2)
        c.stamp(["fff", ".f."], x, y, {"f": cols[k % len(cols)]}, outline="ink")
    K.cobbles(c, (0, 80, W, H), ("dirt", "sand", "dirt"), "gold_d", 5103)
    # the pedestal with the golden bowl, wobbling
    col_ = P.rect(76, 82, 10, 14)
    cap = P.rect(72, 79, 18, 3)
    foot = P.rect(73, 96, 16, 3)
    P.shade_shape(c, col_, ["stone_d", "stone", "stone_l"])
    P.shade_shape(c, cap | foot, ["stone_d", "stone", "stone_l", "white"])
    P.outline_shape(c, col_ | cap | foot, "iron")
    golden_bowl(c, 81, 72, 11, seed=5104)
    dashes(c, [(66, 64, 0, 1, 3), (96, 64, 0, 1, 3), (64, 70, 0, 1, 2), (98, 70, 0, 1, 2)], "white")
    # cracks spreading over the square, dust jumping up
    for (x, y, a, n, s) in ((78, 100, 3.0, 46, 1), (85, 100, 0.1, 50, 2), (80, 102, 1.9, 22, 3), (86, 101, 1.2, 22, 4)):
        crack(c, x, y, a, n, 5110 + s)
    for (x, y, r) in ((40, 100, 2.5), (124, 102, 3.0), (60, 112, 2.0), (108, 114, 2.2), (22, 110, 2.0)):
        dust_puff(c, x, y, r)
    for (x, y) in ((44, 94), (118, 96), (64, 106), (100, 108)):
        c.set(x, y, "stone_d")
        c.set(x + 1, y, "stone")
    # the startled dogs
    gol = goldie(eyes="open", mouth="o", bob=-1, ear_dy=-1, arm_to=(19.0, 15.0), cape_lift=0.6)
    c.blit(gol, 14, 76)
    exclaim(c, 26, 70)
    bdv = bedivere(eyes="open", mouth="frown", bob=-1)
    c.blit(bdv.flipped(), 100, 82)
    sweat(c, 110, 84)
    img = GD.goldie_frame(eyes="squint", mouth="o", sword_on=False, bob=-2, ear_dy=-1, cape_lift=0.6,
                          arm_to=(20.5, 13.0), legs=((2, 0.0), (2, 0.0))).render()
    c.blit(S.recolor(img, TOWN_DOGS[2]).flipped(), 128, 78)
    exclaim(c, 138, 72)
    img = GD.goldie_frame(eyes="squint", mouth="o", sword_on=False, bob=-2, ear_dy=-1, cape_lift=0.6,
                          arm_to=(20.5, 13.0), legs=((2, 0.0), (2, 0.0))).render()
    c.blit(S.recolor(img, TOWN_DOGS[3]), 40, 84)
    exclaim(c, 58, 78)
    for (x, y) in ((6, 62), (150, 64), (36, 60), (128, 58)):
        dashes(c, [(x, y, 0, 1, 4), (x + 2, y + 1, 0, 1, 3)], "white")
    S.vignette(c, density=0.35)
    return c


def c5_prologue_2() -> Canvas:
    """The far mountain - snow-white on the left, fire-red on the right; Goldie and Lancelot set off, Bedivere
    stays to guard the bowl and Merlin points the way."""
    c = page("sky")
    sky_day(c, 70, 52)
    WD.cloud_bank(c, 22, ("sky_l", "white", "white"), 5201, x0=-10, x1=60, size=(4.0, 7.0), step=16)
    K.peaks_layer(c, 66, [(14, 14, 30), (40, 10, 26), (150, 12, 30)], "fog", "ash", rim="white", seed=5202,
                  rough=0.8)
    two_face_mountain(c, 104, 10, 70, 52, 5203)
    for (x, y) in ((70, 22), (78, 34), (64, 40), (84, 16), (72, 50), (60, 28), (90, 26), (56, 46)):
        c.set(x, y, "white")
        c.set(x + 1, y + 1, "sky_l")
    for (x, y) in ((132, 22), (140, 36), (126, 12), (146, 26)):
        c.set(x, y, "amber")
    T.hill_band(c, 74, 4, 22, ("moss_d", "moss", "leaf_l"), 5204)
    T.hill_band(c, 88, 5, 28, ("leaf_d", "leaf", "leaf_l"), 5205)
    # the road winding toward the mountain
    for y in range(76, H):
        t = (y - 76) / (H - 76)
        cx = 112 - t * 70 + math.sin(t * 3.0) * 10
        half = 2 + t * 12
        for x in range(int(cx - half), int(cx + half) + 1):
            c.set(x, y, "sand" if abs(x - cx) < half - 1 else "dirt")
    AW.sprinkle_flowers(c, (0, 92, W, H), 26, 5206, ["white", "yellow", "pink"])
    # Goldie and Lancelot on their way; Bedivere and Merlin see them off
    shade(c, 124, 91, 7, 1.5)
    shade(c, 98, 99, 7, 1.5)
    c.blit(lancelot(eyes="happy", mouth="smirk", legs=((1, -1.0), (0, 1.0)), lance_deg=64), 108, 62)
    c.blit(goldie_run(2, mouth="smile"), 80, 66)
    golden_bowl(c, 30, 104, 9, seed=5207)
    bdv = BD.bulldog_frame(eyes="happy", mouth="smile", shield_at=(20.5, 9.0), bob=-1).render()
    c.blit(bdv, 2, 84)
    mer = merlin(staff_at=(23.0, 13.0), arm_up=3, glow=3)
    c.blit(mer, 40, 82)
    S.vignette(c, density=0.3)
    return c


def c5_ending_1() -> Canvas:
    """The two dragons, worn out, sit back to back; their tails are tangled together."""
    c = page("peach")
    dragon_nest(c, 5301)
    wisps(c, 12, -10, W + 10, ("dusk", "rose"), 5304, thick=3, gap=10)
    wisps(c, 30, 20, 140, ("rose", "peach"), 5305, thick=2, gap=14)
    rng = random.Random(5306)
    for _ in range(26):
        x, y = rng.randrange(2, 78), rng.randrange(2, 70)
        if name_at(c, x, y) in ("dusk", "rose", "peach", "cream"):
            c.set(x, y, "white")
    for _ in range(18):
        x, y = rng.randrange(84, W - 2), rng.randrange(2, 70)
        if name_at(c, x, y) in ("dusk", "rose", "peach", "cream", "red_d", "wine"):
            c.set(x, y, "amber" if rng.random() < 0.5 else "yellow")
    for (x, y, a) in ((100, 98, 0.2), (132, 112, -0.3), (150, 92, 2.6)):
        crack(c, x, y, a, 14, 5302 + x, cols=("orange", "red_d"))
    red = dragon("red", tail=False, sit=True, eyes="squint", mouth="o", arm="rest")
    wht = dragon("white", tail=False, sit=True, eyes="squint", mouth="o", arm="rest")
    rx0, wx0, y0 = 20, 76, 46
    shade(c, rx0 + 36, y0 + 57, 18, 3)
    shade(c, wx0 + 27, y0 + 57, 18, 3)
    c.blit(red.flipped(), rx0, y0)
    c.blit(wht, wx0, y0)
    braid(c, (rx0 + 42, y0 + 53), (wx0 + 21, y0 + 53), 4.5, 4, 5303)
    # worn out: sweat drops and little puffs of breath
    sweat(c, rx0 + 22, y0 + 8)
    sweat(c, wx0 + 40, y0 + 8)
    for (x, y, cols) in ((rx0 + 8, y0 + 26, ("stone", "stone_l")), (rx0 + 3, y0 + 21, ("stone", "stone_l")),
                         (wx0 + 56, y0 + 26, ("sky_l", "white")), (wx0 + 61, y0 + 21, ("sky_l", "white"))):
        dust_puff(c, x, y, 2.0, cols)
    S.vignette(c, density=0.4)
    return c


def c5_ending_2() -> Canvas:
    """Goldie lays a stick between the two tails - exactly the same length! - and the dragons roar with laughter."""
    c = page("sky")
    dragon_nest(c, 5401, clear=True)
    for (x0, w0) in ((150, 4), (126, 3), (100, 3)):
        ray(c, x0, 0, x0 - 30, 74, w0, w0 + 8)
    # friends watching from the snow
    c.blit(gawain(eyes="happy", mouth="open"), 2, 36)
    c.blit(lancelot(eyes="happy", mouth="open", lance_deg=80), 34, 44)
    # the dragons side by side, facing Goldie, laughing
    red = dragon("red", tail=False, sit=True, eyes="happy", mouth="roar", arm="wide", flap=0.6)
    wht = dragon("white", tail=False, sit=True, eyes="happy", mouth="roar", arm="wide", flap=0.6)
    c.blit(red.flipped(), 98, 36)
    c.blit(wht.flipped(), 66, 46)
    # both tails laid out straight along the ground, the stick between them: all three the same length
    tip = 40
    t1 = Fig(W, H, seed=5402)
    dragon_tail(t1, "red", [(132, 92), (126, 98), (112, 102), (90, 103), (64, 103), (tip + 4, 103), (tip, 102)],
                3.4, 1.6, stripes=True)
    c.blit(t1.render(), 0, 0)
    t2 = Fig(W, H, seed=5403)
    dragon_tail(t2, "white", [(104, 102), (100, 108), (88, 112), (66, 113), (tip + 4, 113), (tip, 112)], 3.4, 1.6,
                stripes=True)
    c.blit(t2.render(), 0, 0)
    for x in range(tip - 4, 104):
        c.set(x, 107, "gold_d" if x % 7 else "brown")
        c.set(x, 108, "brown_d")
    c.set(104, 106, "leaf")
    c.set(105, 106, "leaf_l")
    for y in range(96, 118, 2):
        c.set(tip - 5, y, "yellow")
    gol = goldie(eyes="happy", mouth="open", arm_to=(23.0, 21.0), lean=0.5, tail_ang=96)
    c.blit(gol, 4, 74)
    # ha ha!
    for (x, y) in ((70, 54), (64, 62), (102, 44), (96, 52)):
        dashes(c, [(x, y, -1, -1, 3), (x + 3, y - 2, 0, -1, 3)], "white")
    for (x, y) in ((58, 38), (124, 22), (150, 62)):
        sparkle(c, x, y)
    S.vignette(c, density=0.3)
    return c


def c5_ending_3() -> Canvas:
    """Sunset: coming home, Goldie, Lancelot and Gawain see a black wolf banner rise over Camelot's walls."""
    c = page("rose")
    K.sky_bands(c, 0, 96, [("plum", 0.0), ("dusk", 0.2), ("rose", 0.45), ("coral", 0.66), ("amber", 0.82),
                           ("peach", 0.92)], seed=55, wave=1.4)
    T.sun_glow(c, 132, 88, rings=((7, "white"), (11, "cream"), (18, "yellow")), only=("amber", "peach", "coral"))
    wisps(c, 14, 20, 120, ("ink", "plum", "plum"), 5501, thick=4)
    wisps(c, 28, -10, 80, ("plum", "dusk"), 5502, thick=3)
    wisps(c, 48, 100, W + 10, ("rose", "coral"), 5503, thick=2)
    # Camelot as a dark silhouette on its hill, a warm rim on the sun side (right)
    sil = Canvas(W, H)

    def block(x: int, w: int, top: int, roof: int = 0, cren: bool = False) -> None:
        for y in range(top, H):
            for xx in range(x, x + w):
                sil.set(xx, y, "plum")
        if roof:
            for k in range(roof):
                half = (k + 1) / roof * (w / 2 + 1.5)
                for xx in range(int(round(x + w / 2 - half)), int(round(x + w / 2 + half))):
                    sil.set(xx, top - roof + k, "plum")
        if cren:
            for xx in range(x, x + w, 3):
                sil.set(xx, top - 1, "plum")
                sil.set(xx, top - 2, "plum")

    for (x, w, top, roof, cren) in ((40, 70, 76, 0, True), (34, 10, 62, 10, False), (52, 12, 54, 12, False),
                                    (68, 16, 40, 0, True), (72, 8, 30, 14, False), (90, 12, 50, 12, False),
                                    (108, 10, 64, 10, False), (60, 30, 66, 0, True)):
        block(x, w, top, roof, cren)
    for x in range(W):
        top = int(92 - 10 * math.exp(-((x - 74) / 46.0) ** 2) + math.sin(x / 9.0))
        for y in range(top, H):
            sil.set(x, y, "plum")
    for y in range(H):
        for x in range(W):
            if sil.opaque(x, y):
                lit = not sil.opaque(x + 1, y) or not sil.opaque(x, y - 1)
                c.set(x, y, ("coral" if x > 60 else "rose") if lit and y < 90 else ("wine" if y < 84 else "plum"))
    for (x, y) in ((56, 60), (58, 66), (74, 46), (78, 52), (94, 58), (112, 70), (38, 68), (84, 72), (64, 74)):
        c.set(x, y, "yellow")
        c.set(x, y + 1, "orange")
    # shadow sentries on the curtain wall
    for x in (44, 56, 92, 104):
        c.stamp([".i.", "iii"], x, 72, {"i": "ink"}, outline=None)
        c.set(x + 1, 73, "lilac")
        c.vline(x + 3, 67, 74, "ink")
    # the black wolf flag climbing the pole of the tallest tower
    tx = 76
    c.vline(tx, 4, 16, "ink")
    c.set(tx, 3, "steel")
    fl = Canvas(26, 16)
    for yy in range(11):
        for xx in range(20):
            if xx > 16 and abs(yy - 5) < (xx - 16) * 2:
                continue
            fl.set(xx + 1, yy + 1 + int(round(math.sin(xx / 3.5) * 1.0)), "navy" if yy < 8 else "ink")
    fl.outline_all("ink")
    wolf_head(fl, 7, 3, "lilac", "white")
    c.blit(fl, tx + 1, 5)
    for (x, y) in ((tx + 4, 19), (tx + 10, 20), (tx + 16, 19)):
        dashes(c, [(x, y, 0, 1, 3)], "lilac")
    sparkle(c, tx - 4, 8, "violet", "lilac")
    for (x, y) in ((24, 34), (32, 28), (110, 30), (120, 36)):
        c.stamp(["k...k", ".k.k.", "..k.."], x, y, {"k": "ink"}, outline=None)
    # the foreground hill and our three heroes looking at it, dark against the sky
    for x in range(W):
        top = int(98 + (x / W) * 14 + math.sin(x / 11.0) * 1.5)
        for y in range(top, H):
            c.set(x, y, "ink" if y > top else "plum")
    for x in range(0, W, 3):
        c.set(x, int(98 + (x / W) * 14 + math.sin(x / 11.0) * 1.5) - 1, "plum")
    warm = ("ink", "ink", "ink", "plum", "plum")
    gw = moonlit(gawain(eyes="open", mouth="smile"), side=(1, -1), rim="coral", ramp=warm, keep=())
    gl = moonlit(goldie(eyes="open", mouth="o"), side=(1, -1), rim="coral", ramp=warm, keep=("yellow",))
    ln = moonlit(lancelot(eyes="open", mouth="o", lance_deg=80), side=(1, -1), rim="coral", ramp=warm, keep=())
    c.blit(gw, -4, 68)
    c.blit(ln, 30, 72)
    c.blit(gl, 58, 70)
    S.vignette(c, density=0.45)
    return c


def teaser_5() -> Canvas:
    """Final chapter teaser: an autumn plain; far away, a dark shadow army under black wolf banners."""
    c = page("peach")
    hz = 64
    K.sky_bands(c, 0, hz, [("slate", 0.0), ("dusk", 0.25), ("rose", 0.55), ("peach", 0.82), ("cream", 0.94)],
                seed=56, wave=1.3)
    wisps(c, 14, 50, W + 20, ("ink", "navy", "slate"), 5601, thick=4)
    wisps(c, 28, 80, W + 20, ("navy", "slate"), 5602, thick=3)
    wisps(c, 40, -10, 70, ("rose", "peach"), 5603, thick=2)
    K.hills_layer(c, hz - 2, 4, 16, "dusk", rim="rose", seed=5603, fill_to=hz + 6)
    army(c, 56, 158, hz + 2, 5604, rows=2, flags=4)
    T.hill_band(c, hz + 8, 3, 30, ("gold_d", "gold", "gold_l"), 5605)
    T.hill_band(c, hz + 22, 4, 26, ("brown", "gold_d", "gold"), 5606)
    for k in range(90):
        rng = random.Random(5607 + k)
        x, y = rng.randrange(0, W), rng.randrange(hz + 16, H)
        for j in range(3):
            c.set(x + j // 2, y - j, "gold_l" if j < 2 else "cream")
    tree(c, 18, 98, 26, 13, 5608, ramp=("brown", "orange", "amber", "yellow"), outline="brown_d")
    tree(c, 44, 92, 18, 8, 5609, ramp=("red_d", "orange", "amber", "gold_l"), outline="brown_d")
    leaf_stream(c, 10, 70, 150, 40, 30, 5610, spread=14)
    leaf_stream(c, 20, 100, 140, 80, 18, 5611, spread=10)
    S.vignette(c, density=0.45)
    return c


# ==========================================================================
# chapter 6: the battle of Camlann
# ==========================================================================

def c6_prologue_1() -> Canvas:
    """Occupied Camelot: black wolf banners on the gate, shadow knights on guard, Mordred on the wall raising the
    glowing scabbard."""
    c = page("night_d")
    K.sky_bands(c, 0, 60, [("night_d", 0.0), ("plum", 0.3), ("dusk", 0.62), ("rose", 0.9)], seed=61, wave=1.4)
    wisps(c, 10, -10, W + 10, ("ink", "night_d", "plum"), 6101, thick=4)
    wisps(c, 26, 20, W + 10, ("plum", "dusk"), 6102, thick=3)
    # the gatehouse: two towers, the wall walk, the arch with its portcullis
    wall = K.masonry(W, 70, ("iron", "slate", "stone_d"), 6103, course=7, mortar="navy", base_dark=0)
    c.blit(wall, 0, 53)
    for (tx, tw) in ((6, 38), (116, 38)):
        tw_ = K.masonry(tw, 90, ("iron", "slate", "stone_d"), 6104 + tx, course=7, mortar="navy", base_dark=0)
        c.blit(tw_, tx, 30)
        c.blit(K.crenels(tw, 5, 3, 5, ("iron", "slate", "stone_d"), "ink"), tx, 25)
        for k in range(tw):
            c.set(tx + k, 30, "ink")
        c.vline(tx, 25, 119, "ink")
        c.vline(tx + tw - 1, 25, 119, "ink")
    c.blit(K.crenels(72, 5, 3, 5, ("iron", "slate", "stone_d"), "ink"), 44, 48)
    for x in range(44, 116):
        c.set(x, 53, "ink")
    arch = set()
    for y in range(64, 112):
        for x in range(58, 102):
            dxn = (x + 0.5 - 80) / 22
            if y >= 78 - math.sqrt(max(0.0, 1 - dxn * dxn)) * 14:
                arch.add((x, y))
    P.fill(c, arch, "ink")
    for (x, y) in arch:
        if y > 92:
            c.set(x, y, "navy")
    P.outline_shape(c, arch, "stone_d")
    for x in range(60, 101, 5):
        for y in range(64, 88):
            if (x, y) in arch:
                c.set(x, y, "iron")
    for y in range(68, 88, 5):
        for x in range(58, 102):
            if (x, y) in arch:
                c.set(x, y, "iron")
    for x in range(60, 101, 5):
        c.set(x, 88, "steel_d")
    for (x, y) in ((66, 100), (74, 98), (88, 101), (94, 97)):
        c.set(x, y, "lilac")
        c.set(x + 2, y, "lilac")
    # cobbles in the gloom
    K.cobbles(c, (0, 108, W, H), ("slate", "iron", "slate"), "navy", 6105)
    # the hanging banners and a little lantern wisp
    wolf_banner(c, 18, 36, 14, 32)
    wolf_banner(c, 128, 36, 14, 32, wave=1.0)
    wisp = C7.wisp_frame(0.6, light=2)
    c.blit(wisp, 44, 60)
    c.blit(C7.wisp_frame(1.0, bob=-1, light=1).flipped(), 102, 56)
    # Mordred on the wall walk, raising the scabbard; shadows rising around him
    glow_bands(c, 80, 33, [30, 20, 11], sy=0.8, ramp=VIOLET)
    mor = C7.mordred_frame(bob=-1, hand=(27.0, 16.0), sword_deg=88, sword_len=11, eyes="proud", mouth="smirk",
                           tilt=1.4, scab=(29.5, 30.0, 33.5, 14.0), scab_glow=240,
                           extra=lambda f: C7._rising_shadows(f, 1)).render()
    c.blit(mor, 56, 8)
    # the guards at the gate
    for (x, fl) in ((30, False), (98, True)):
        g = shadow_knight(eyes="open")
        shade(c, x + (14 if not fl else 17), 112, 10, 2)
        c.blit(g.flipped() if fl else g, x, 82)
    for (x, y) in ((50, 22), (112, 16), (30, 18), (140, 20)):
        c.stamp(["k...k", ".k.k.", "..k.."], x, y, {"k": "ink"}, outline=None)
    S.vignette(c, density=0.5)
    return c


def c6_prologue_2() -> Canvas:
    """A campfire on a hilltop at night: all the companions gather round a round table in the open."""
    c = page("navy")
    K.sky_bands(c, 0, 72, [("navy", 0.0), ("night_d", 0.35), ("night", 0.75), ("dusk", 0.95)], seed=62, wave=1.2)
    S.stars(c, 34, 6201, (0, 0, W, 50))
    K.moon(c, 26, 18, 6, halo=("night_d",), crescent=0.55)
    # Camelot on the far horizon, black flags and a violet glow over it
    glow_bands(c, 132, 66, [22, 12], sy=0.6, ramp=VIOLET, only=("night", "dusk", "night_d"))
    T.castle(c, 112, 70, 0.75, wall=("navy", "night_d", "night"), roof=("navy", "night_d", "night"), flags=False)
    for (x, y) in ((116, 44), (134, 42), (146, 50)):
        wolf_flag(c, x, y, pole=6, w=6, h=4)
    K.hills_layer(c, 74, 3, 20, "night_d", rim="night", seed=6202, fill_to=84)
    for x in range(W):
        top = int(80 - 6 * math.exp(-((x - 80) / 60.0) ** 2) + math.sin(x / 8.0))
        for y in range(top, H):
            c.set(x, y, "deep" if y < 94 else "forest_d")
        c.set(x, top, "teal")
    # the fire's warm light over the hilltop
    fx, fy = 22, 106
    glow_bands(c, fx, fy - 4, [52, 28], sy=0.5, ramp=WARM, only=("deep", "forest_d", "teal"))
    # the friends round the table (feet behind it), lit by the fire from the left
    back = [(lambda: merlin(glow=2), 50, 66, False),
            (lambda: goldie(eyes="happy", mouth="smile", arm_to=(21.0, 18.5)), 70, 62, False),
            (lambda: bedivere_cheer(), 92, 66, True),
            (lambda: tristan(eyes="happy", mouth="smile", feather=0.6), 112, 67, True)]
    for (mk, x, y, fl) in back:
        img = mk()
        img = img.flipped() if fl else img
        c.blit(rimmed(img, (-1, 0)), x, y)
    field_table(c, 96, 98, 40, 8)
    # a map of Camelot and two cups on the table
    c.rect(87, 94, 18, 7, "cream")
    c.hline(87, 104, 100, "sand")
    for (x, y) in ((91, 97), (92, 96), (93, 97), (97, 98), (98, 97), (94, 98)):
        c.set(x, y, "brown")
    c.set(100, 96, "red")
    c.set(101, 97, "red")
    for (x, y) in ((70, 95), (122, 94)):
        c.rect(x, y, 3, 3, "steel")
        c.set(x, y, "steel_l")
    ln = lancelot(eyes="open", mouth="smirk", lance_deg=80)
    c.blit(rimmed(ln, (-1, 0)), 34, 78)
    gw = gawain(eyes="happy", mouth="smile").flipped()
    c.blit(rimmed(gw, (-1, 0)), 126, 72)
    campfire(c, fx, fy, 6203)
    for (x, y) in ((18, 82), (26, 78), (22, 72)):
        c.set(x, y, "amber")
    S.vignette(c, density=0.5)
    return c


def c6_ending_1() -> Canvas:
    """Avalon hill: the scabbard has cracked, the shadows fly off as autumn leaves; Mordred kneels and Goldie holds
    out a paw."""
    c = page("peach")
    hz = 62
    avalon_sky(c, hz, 63)
    T.sun_glow(c, 128, 34, rings=((6, "white"), (9, "cream"), (13, "yellow")), only=("peach", "coral", "cream", "rose"))
    wisps(c, 20, -10, 90, ("rose", "peach", "coral"), 6302, thick=2)
    for x in range(W):
        top = int(hz + 6 - 10 * math.exp(-((x - 84) / 50.0) ** 2) + math.sin(x / 7.0))
        for y in range(top, H):
            c.set(x, y, "moss")
        c.set(x, top, "leaf_l")
    AW.paint_ground(c, (0, hz - 6, W, H), ("moss_d", "moss", "leaf_l"), 6305, scale=18, tufts=0.4,
                    mask=lambda x, y: name_at(c, x, y) in ("moss", "leaf_l", "moss_d"))
    tree(c, 12, 86, 22, 12, 6306, fruit="red")
    tree(c, 150, 84, 24, 12, 6307, fruit="red")
    AW.sprinkle_flowers(c, (0, 86, W, H), 26, 6308, ["white", "pink", "yellow"])
    glow_bands(c, 128, 46, [76, 50], sy=0.6, ramp=WARM, only=("moss", "moss_d", "leaf_l", "leaf"))
    # Mordred kneeling, Goldie holding out a paw
    mor = C7.mordred_down(1)
    shade(c, 100, 101, 16, 2.5)
    c.blit(mor.flipped(), 76, 56)
    gol = goldie(eyes="happy", mouth="smile", arm_to=(24.5, 17.5), lean=1.0, cape_wave=0.8)
    shade(c, 52, 101, 10, 2)
    c.blit(gol, 36, 68)
    scabbard_broken(c, 56, 100)
    # the shadow army turning into leaves, swirling away into the sunset
    for (x, y, h) in ((66, 100, 10), (118, 98, 12), (132, 104, 8), (28, 102, 7), (100, 108, 6)):
        for j in range(h):
            xx = x + int(round(math.sin(j * 0.7 + x) * 1.2))
            col = "ink" if j < h * 0.4 else ("plum" if j < h * 0.75 else "dusk")
            c.set(xx, y - j, col)
            if j < h * 0.6:
                c.set(xx + 1, y - j, "plum")
        leaves(c, [(x + 1, y - h - 2), (x + 4, y - h - 6), (x - 2, y - h - 9)], x)
    leaf_stream(c, 60, 96, 150, 6, 44, 6309, spread=16, curl=1.0)
    leaf_stream(c, 110, 90, 156, 20, 16, 6310, spread=8)
    # friends watching from behind
    c.blit(bedivere(eyes="happy", mouth="smile"), 2, 68)
    c.blit(lancelot(eyes="happy", mouth="smirk", lance_deg=82), 16, 62)
    S.vignette(c, density=0.35)
    return c


def c6_ending_2() -> Canvas:
    """The lake of Avalon at golden hour: Goldie hands the sword in the stone back to the Lady of the Lake."""
    c = page("peach")
    hz = 54
    avalon_sky(c, hz, 64)
    T.sun_glow(c, 78, hz, rings=((8, "white"), (12, "cream"), (20, "yellow")), only=("peach", "cream", "coral"))
    wisps(c, 18, -10, W + 10, ("rose", "peach", "coral"), 6401, thick=2)
    WD.water_bands(c, (0, hz, W, H), [("peach", 0.0), ("coral", 0.15), ("rose", 0.4), ("dusk", 0.75)], 6402,
                   glints=("cream", "peach"), n_glints=40)
    reflection(c, 78, hz + 1, H, 3, 0.4, seed=6403)
    # the isle of Avalon: apple trees in blossom on a misty island
    for x in range(40, 120):
        top = int(hz - 6 * math.sin((x - 40) / 80 * math.pi))
        for y in range(top, hz + 1):
            c.set(x, y, "dusk" if y > top + 1 else "rose")
    for (x, h, r, s) in ((54, 10, 6, 1), (66, 12, 7, 2), (92, 12, 7, 3), (104, 9, 5, 4)):
        tree(c, x, hz - 3, h, r, 6404 + s, ramp=("dusk", "rose", "pink", "peach"), outline="plum", fruit="cream",
             trunk=("plum", "dusk"))
    for y in (hz - 1, hz + 1):
        for x in range(30, 130):
            if (x + y) % 5 < 3:
                c.set(x, y, "peach")
    # the shore on the left with reeds and flowers
    shore = lambda y: int(56 - (y - 82) * 0.9)  # noqa: E731
    for y in range(82, H):
        for x in range(0, max(0, shore(y)) + 30):
            if x < shore(y) + int((y - 82) * 0.7) + 6:
                c.set(x, y, "moss" if (x + y) % 9 else "leaf_l")
    for y in range(82, H):
        x = shore(y) + int((y - 82) * 0.7) + 6
        c.set(x, y, "cream")
        c.set(x + 1, y, "peach")
    AW.sprinkle_flowers(c, (0, 90, 70, H), 16, 6405, ["white", "pink", "yellow"],
                        mask=lambda x, y: name_at(c, x, y) in ("moss", "leaf_l"))
    for k, x in enumerate((2, 10)):
        c.blit(K.reeds(6406 + k, 18, ("moss_d", "forest", "brown")), x, 76)
    # the Lady rising on the water, a ring of light under her
    for r, col in ((30, "rose"), (22, "pink"), (14, "peach"), (7, "cream")):
        for (x, y) in P.ellipse(112, 102, r, r * 0.25):
            if name_at(c, x, y) not in ("moss", "leaf_l"):
                c.set(x, y, col)
    lady_ = lady(arms="open", eyes="open", drops=0.1, wave=1.0)
    c.blit(lady_.flipped().scaled(2), 76, 40)
    # Goldie offering the sword, hilt first, across his paw
    gol = GD.goldie_frame(eyes="happy", mouth="smile", sword_on=False, arm_to=(23.5, 18.0), lean=0.5, cape_wave=0.8,
                          extra=lambda f: GD.sword(f, 27.0, 17.5, 180, 12)).render()
    c.blit(crowned(gol, 0.5).scaled(2), 6, 42)
    glow_bands(c, 64, 77, [14, 8], sy=0.6, ramp=WARM, only=("peach", "coral", "rose", "dusk", "pink", "cream"))
    for (x, y) in ((70, 70), (82, 74), (76, 64), (60, 66), (88, 66)):
        sparkle(c, x, y, "yellow", "white")
    glitter(c, 72, 74, 14, 6407, 16, 9)
    S.vignette(c, density=0.35)
    return c


def c6_ending_3() -> Canvas:
    """From then on the round table has many more seats, and every one holds a friend: Morgana, Mordred, the Green
    Knight, everyone - and the two dragons look in through the windows."""
    c = page("umber")
    great_hall(c)
    # windows with the dragons peeking in, the crown banner between them
    lw = arch_window(c, 12, 2, 30, 34)
    rw = arch_window(c, 118, 2, 30, 34)
    red = crop(dragon("red", eyes="happy", mouth="grin"), 18, 4, 54, 34)
    wht = crop(dragon("white", eyes="happy", mouth="grin"), 18, 4, 54, 34).flipped()
    for (img, x0, y0, glass) in ((red, 10, 6, lw), (wht, 116, 6, rw)):
        for y in range(img.h):
            for x in range(img.w):
                p = img.get(x, y)
                if p is not None and p[3] > 0 and (x0 + x, y0 + y) in glass:
                    c.set(x0 + x, y0 + y, p)
    for y in range(2, 34):
        for x in range(68, 92):
            if y < 30 or abs(x - 79.5) > (y - 30) * 3:
                c.set(x, y, "red" if x > 69 else "coral")
    for x in range(68, 92):
        c.set(x, 2, "gold")
    crown(c, 77, 11)
    c.hline(75, 85, 18, "gold")
    # bunting in everyone's colours
    cols = ["red", "water", "sky", "violet", "leaf", "orange", "sky_l", "steel", "white", "yellow", "red_d"]
    for (xa, xb, k0) in ((44, 66, 0), (94, 116, 4)):
        for k in range(4):
            x = xa + 1 + k * 6
            y = 4 + int(4 * math.sin(math.pi * (x + 1 - xa) / (xb - xa)))
            c.stamp(["ff", "f."], x, y, {"f": cols[k + k0]}, outline="ink")
        for x in range(xa, xb):
            c.set(x, 3 + int(4 * math.sin(math.pi * (x - xa) / (xb - xa))), "brown_d")
    # warm light falling from the windows
    for (x0, x1) in ((27, 46), (133, 114)):
        ray(c, x0, 38, x1, 92, 7, 14, 0.5)
    # chairs and the throne behind the friends
    for x in (38, 52, 104, 118):
        c.blit(S.chair(16), x - 8, 58)
    c.blit(S.chair(22), 72, 46)
    cx, cy, rx, ry = 80, 98, 60, 14
    with unarmed():
        back = [
            (morgana(eyes="open", mouth="smile", staff_glow=2, staff=(46.0, 12.0, 62.0)), -8, 30, False),
            (green_knight("happy"), 112, 30, True),
            (merlin(glow=2), 22, 62, False),
            (lancelot(eyes="happy", mouth="smirk", lance_deg=86), 37, 63, False),
            (bedivere(eyes="happy", mouth="smile"), 50, 64, False),
            (goldie(eyes="happy", mouth="smile", arm_to=(21.0, 18.0)), 64, 56, False),
            (lady(eyes="smile", arms="hold"), 84, 62, True),
            (tristan(eyes="happy", mouth="sing", feather=0.6), 99, 63, True),
        ]
        gaw = gawain(eyes="happy", mouth="open").flipped()
    glow_bands(c, 80, 66, [22, 12], sy=0.8, ramp=WARM, only=("brown_d", "brown", "gold_d", "umber", "gold"))
    for (img, x, y, fl) in back:
        c.blit(img.flipped() if fl else img, x, y)
    S6.round_table(c, cx, cy, rx, ry)
    # a feast on the table: the golden bowl, plates of bones, cups, and Goldie's stick
    golden_bowl(c, cx, cy - 2, 10, seed=6501)
    for (x, y) in ((44, 96), (116, 96), (60, 106), (100, 106)):
        P.fill(c, P.ellipse(x, y, 5, 2), "white")
        P.outline_shape(c, P.ellipse(x, y, 5, 2), "stone")
        bone(c, x - 3, y - 2)
    for (x, y) in ((32, 100), (128, 100), (80, 110)):
        c.rect(x, y - 3, 3, 4, "steel")
        c.set(x, y - 3, "steel_l")
        c.set(x + 1, y - 3, "white")
    for k in range(14):
        c.set(66 + k, 88 + k // 7, "brown" if k % 4 else "gold_d")
        c.set(66 + k, 89 + k // 7, "brown_d")
    c.set(80, 88, "leaf")
    c.set(81, 88, "leaf_l")
    # Mordred at the near end of the table, ready for his patrol; Gawain at the other end
    with unarmed(keep=("m_sword",)):
        mor = mordred(eyes="closed", mouth="smirk", hand=(29.0, 33.0), sword_deg=-86, sword_len=9, cape_wave=0.4)
    c.blit(mor, -2, 74)
    c.blit(gaw, 122, 78)
    # sparkles and confetti of a happy day
    for (x, y) in ((58, 46), (102, 44), (8, 48), (152, 50)):
        sparkle(c, x, y)
    for k in range(34):
        rng = random.Random(6502 + k)
        x, y = rng.randrange(4, 156), rng.randrange(36, 56)
        if name_at(c, x, y) in ("brown_d", "brown", "gold_d", "umber"):
            c.set(x, y, ["red", "yellow", "sky", "pink", "leaf_l"][k % 5])
    S.vignette(c, density=0.4)
    return c


def c6_ending_4() -> Canvas:
    """The end. Sunset over the meadow: King Goldie runs after his stick toward the setting sun while all his
    friends cheer him on; two little dragons fly home side by side."""
    c = page("peach")
    hz = 78
    K.sky_bands(c, 0, hz, [("dusk", 0.0), ("rose", 0.18), ("coral", 0.4), ("amber", 0.62), ("yellow", 0.84),
                           ("cream", 0.95)], seed=66, wave=1.6)
    sx, sy = 132, hz - 2
    glow_bands(c, sx, sy, [76, 54, 36], sy=0.75, ramp=WARM, wob=1.4)
    for a_deg in (196, 222, 252, 284, 316):
        a = math.radians(a_deg)
        for r in range(24, 140):
            for w_ in range(-int(r * 0.04), int(r * 0.04) + 1):
                x = int(sx + math.cos(a) * r - math.sin(a) * w_)
                y = int(sy + math.sin(a) * r * 0.85 + math.cos(a) * w_)
                if 0 <= x < W and 0 <= y < hz:
                    col = name_at(c, x, y)
                    c.set(x, y, WARM.get(col, col))
    for (px, py) in P.ellipse(sx, sy, 15, 15):
        if py < hz:
            d = math.hypot(px + 0.5 - sx, py + 0.5 - sy)
            c.set(px, py, "white" if d < 10 else ("cream" if d < 13 else "yellow"))
    wisps(c, 14, -10, 80, ("rose", "coral", "peach"), 6601, thick=2, gap=4)
    wisps(c, 30, 70, W + 10, ("coral", "amber", "peach"), 6602, thick=2, gap=6)
    wisps(c, 46, -10, 50, ("coral", "amber"), 6603, thick=2)
    # two little dragons flying home together
    mini_dragon(c, 92, 16, "red", 0)
    mini_dragon(c, 106, 22, "white", 1)
    for (x, y) in ((88, 19), (102, 25)):
        dashes(c, [(x, y, -1, 0, 3)], "peach")
    # Camelot far away, distant hills in the haze
    K.hills_layer(c, hz - 1, 3, 20, "rose", rim="peach", seed=6604, fill_to=hz + 4)
    T.castle(c, 56, hz - 2, 0.6, wall=("dusk", "rose", "peach"), roof=("plum", "dusk", "rose"))
    # the meadow, gold where the sun touches it
    for x in range(W):
        top = int(hz + 2 + math.sin(x / 7.0) * 0.8)
        for y in range(top, H):
            c.set(x, y, "moss")
        c.set(x, top, "leaf_l")
    # the tall friends far back on the left, peeking over a near rise of the meadow
    with unarmed():
        gk_ = green_knight("laugh")
        crowd = [
            (mordred(eyes="closed", mouth="smirk", hand=(26.0, 30.0), cape_wave=0.8), -10, 50),
            (merlin(staff_at=(22.0, 13.0), arm_up=3, glow=3), 24, 68),
            (lady(arms="up", eyes="smile", drops=0.2), 46, 70),
            (bedivere_cheer(), 0, 88),
            (lancelot(eyes="happy", mouth="open", hand=(18.5, 13.0)), 18, 88),
            (tristan_play(2), 36, 88),
            (gawain(eyes="happy", mouth="open", hammer=((26.0, 14.0), 80.0, 7.0)), 56, 80),
        ]
    c.blit(rimmed(gk_, (1, 0)), -14, 30)
    c.blit(rimmed(morgana(eyes="open", mouth="smile", staff_glow=3, staff=(46.0, 10.0, 62.0)), (1, 0)), 14, 26)
    rise = lambda x: int(64 + x * 0.22 + math.sin(x / 9.0) * 1.2)  # noqa: E731
    for x in range(0, 110):
        for y in range(rise(x), H):
            c.set(x, y, "moss")
        c.set(x, rise(x), "leaf_l")
        if x % 3:
            c.set(x, rise(x) + 1, "leaf_l")
    AW.paint_ground(c, (0, 60, W, H), ("moss_d", "moss", "leaf_l"), 6605, scale=20, tufts=0.4,
                    mask=lambda x, y: name_at(c, x, y) in ("moss", "leaf_l", "moss_d"))
    glow_bands(c, sx, hz + 4, [80, 48, 24], sy=0.4, ramp=WARM, only=("moss", "moss_d", "leaf_l"))
    AW.sprinkle_flowers(c, (0, 70, W, H), 40, 6606, ["white", "pink", "yellow"],
                        mask=lambda x, y: name_at(c, x, y) in ("moss", "moss_d", "leaf_l", "leaf"))
    # the friends cheering, long shadows stretching away from the sun
    for (img, x, y) in crowd:
        bb = img.bbox()
        if bb:
            shade(c, x + bb[0] + (bb[2] - bb[0]) / 2 - 8, y + bb[3] - 1, (bb[2] - bb[0]) / 2 + 4, 1.6,
                  only=("moss", "moss_d", "leaf_l", "leaf", "white", "pink", "yellow"))
        c.blit(rimmed(img, (1, 0)), x, y)
    note(c, 64, 92)
    note(c, 72, 82, "pink")
    heart(c, 72, 62)
    heart(c, 30, 54, "red")
    # King Goldie running toward the sun, the stick spinning high ahead of him
    gol = goldie_run(1, mouth="tongue")
    shade(c, 104, 106, 12, 2, only=("moss", "moss_d", "leaf_l", "leaf", "white", "pink", "yellow"))
    c.blit(rimmed(gol, (1, 0)), 94, 66)
    for k in range(16):
        t = k / 15
        x = int(116 + t * 20)
        y = int(78 - math.sin(t * math.pi * 0.8) * 28)
        if k % 2 == 0:
            c.set(x, y, "white")
    sk = Canvas(16, 12)
    for k in range(12):
        sk.set(1 + k, 8 - k * 6 // 12, "brown" if k % 4 else "gold_d")
        sk.set(1 + k, 9 - k * 6 // 12, "brown_d")
    sk.set(9, 2, "leaf")
    sk.set(10, 1, "leaf_l")
    sk.outline_all("umber")
    c.blit(sk, 134, 42)
    for (x, y) in ((132, 40), (150, 46), (142, 38)):
        dashes(c, [(x, y, 1, 1, 2)], "white")
    # petals and sparkles drifting in the warm air
    rng = random.Random(6607)
    for i in range(24):
        x, y = rng.randrange(4, W - 4), rng.randrange(6, 104)
        if i % 4 == 0:
            sparkle(c, x, y, "yellow", "white")
        else:
            c.set(x, y, ["pink", "white", "yellow", "peach"][i % 4])
    S.vignette(c, density=0.3)
    return c


BUILDERS = {
    "teaser_3": teaser_3, "c4_prologue_1": c4_prologue_1, "c4_prologue_2": c4_prologue_2,
    "c4_ending_1": c4_ending_1, "c4_ending_2": c4_ending_2, "c4_ending_3": c4_ending_3, "teaser_4": teaser_4,
    "c5_prologue_1": c5_prologue_1, "c5_prologue_2": c5_prologue_2, "c5_ending_1": c5_ending_1,
    "c5_ending_2": c5_ending_2, "c5_ending_3": c5_ending_3, "teaser_5": teaser_5,
    "c6_prologue_1": c6_prologue_1, "c6_prologue_2": c6_prologue_2, "c6_ending_1": c6_ending_1,
    "c6_ending_2": c6_ending_2, "c6_ending_3": c6_ending_3, "c6_ending_4": c6_ending_4,
}


def build(sid: str) -> Canvas:
    return P.quantize(BUILDERS[sid]())


def write_all(ids: list[str] | None = None, preview_dir: str | None = None, sheet: str | None = None) -> None:
    done = []
    for sid in IDS:
        if ids and sid not in ids:
            continue
        if sid not in BUILDERS:
            continue
        img = build(sid)
        img.save(res_path("res://assets/story/%s.png" % sid), opaque=True)
        done.append(img)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            img.scaled(3).save(os.path.join(preview_dir, "%s.png" % sid))
    if sheet and done:
        rows = [done[i:i + 4] for i in range(0, len(done), 4)]
        contact_sheet(rows, 2).save(sheet)


if __name__ == "__main__":
    args = sys.argv[1:]
    opts: dict = {}
    for flag in ("--preview", "--sheet"):
        if flag in args:
            i = args.index(flag)
            opts[flag] = args[i + 1]
            del args[i:i + 2]
    write_all(args or None, opts.get("--preview"), opts.get("--sheet"))
    print("v2.7 story pages written")
