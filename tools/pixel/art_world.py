"""Chapter 1 scenery: tiles and the six arena backgrounds (C6, CP2).

Every background is one baked 304x512 PNG (palette colours only) plus a few light
animated layers, written as assets/backgrounds/<name>.tscn:

    Background (Node2D)
      Image        Sprite2D, the baked picture, placed at world (-62, -88)
      Anim/*       AnimatedSprite2D props (swaying wheat and flowers, banners, torches,
                   water glints, a windmill...) sharing small sprite sheets in
                   assets/backgrounds/anim/
      Ambient/*    CPUParticles2D (petals, fireflies, chaff, rain...) - few and small
      Lightning    (bridge only) a soft flash drawn behind every actor
      Mood         CanvasModulate for the time of day (only 1-4, 1-5, 1-6; mild, so
                   characters and red telegraphs stay readable)

The image covers world (-62,-88)-(242,424), wider than the contract minimum
(-10,-60)-(190,380). The arena (Layout.ARENA_RECT = 2,72,176,224) is image
x 64..240, y 160..384. Everything inside the arena is kept calm and mid-toned so
enemies, Goldie and telegraphs always read first; detail lives around it.

Lighting is done with palette ramps (DARKER / LIGHTER maps), never with blending,
so the baked images stay inside the 40-colour palette.
"""

from __future__ import annotations

import math
import random

from palette import PALETTE, rgba
from pixel import Anim, Canvas, build_sheet, res_path, write_text

T = 16
IMG_W, IMG_H = 304, 512
ORIGIN = (-62, -88)               # world position of the image's top-left pixel
AX0, AY0, AX1, AY1 = 64, 160, 240, 384   # arena in image pixels
ARENA_COLS = range(4, 15)          # kept for compatibility (11 columns)
ARENA_ROWS = range(10, 24)         # 14 rows

L = {
    "o": "ink", "w": "white", "c": "cream", "g": "gold_l", "G": "gold", "b": "gold_d", "B": "brown",
    "n": "brown_d", "R": "red", "r": "red_d", "p": "pink", "Y": "yellow", "l": "leaf_l", "e": "leaf",
    "d": "leaf_d", "f": "forest", "F": "forest_d", "k": "stone_l", "t": "stone", "T": "stone_d",
    "S": "steel_l", "s": "steel", "z": "steel_d", "v": "violet", "V": "lilac", "P": "plum",
    "q": "sky_l", "Q": "sky", "u": "water", "U": "water_d", "i": "iron", "O": "orange",
    "h": "peach", "x": "rose", "D": "dusk", "N": "night", "M": "night_d", "m": "moss", "a": "moss_d",
    "y": "dirt",
}

# --------------------------------------------------------------------------
# Palette ramps: one step darker / lighter (used for shadows and light pools)
# --------------------------------------------------------------------------

DARKER = {
    "leaf_l": "leaf", "leaf": "leaf_d", "leaf_d": "forest", "forest": "forest_d", "forest_d": "night_d",
    "moss": "moss_d", "moss_d": "forest", "gold_l": "gold", "gold": "gold_d", "gold_d": "brown",
    "cream": "gold_l", "dirt": "gold_d", "brown": "brown_d", "brown_d": "ink", "stone_l": "stone",
    "stone": "stone_d", "stone_d": "iron", "white": "stone_l", "sky_l": "sky", "sky": "water",
    "water": "water_d", "water_d": "night", "night": "night_d", "night_d": "ink", "steel_l": "steel",
    "steel": "steel_d", "steel_d": "iron", "iron": "ink", "peach": "rose", "rose": "dusk", "dusk": "plum",
    "pink": "rose", "red": "red_d", "red_d": "plum", "lilac": "violet", "violet": "plum", "plum": "ink",
    "yellow": "gold_l", "orange": "gold_d", "ink": "ink",
}
LIGHTER = {
    "night_d": "night", "night": "water_d", "water_d": "water", "water": "sky", "sky": "sky_l",
    "sky_l": "white", "forest_d": "forest", "forest": "leaf_d", "leaf_d": "leaf", "leaf": "leaf_l",
    "leaf_l": "leaf_l", "moss_d": "moss", "moss": "leaf_l", "brown_d": "brown", "brown": "gold_d",
    "gold_d": "gold", "gold": "gold_l", "gold_l": "cream", "cream": "white", "dirt": "gold_l",
    "stone_d": "stone", "stone": "stone_l", "stone_l": "white", "iron": "steel_d", "steel_d": "steel",
    "steel": "steel_l", "steel_l": "white", "dusk": "rose", "rose": "pink", "pink": "peach",
    "peach": "cream", "plum": "violet", "violet": "lilac", "lilac": "white", "red_d": "red",
    "red": "pink", "orange": "yellow", "yellow": "white", "white": "white", "ink": "plum",
}
_NAME_BY_RGB = {rgba(n)[:3]: n for n, _ in PALETTE}


def name_at(img: Canvas, x: int, y: int) -> str | None:
    p = img.get(x, y)
    if p is None or p[3] == 0:
        return None
    return _NAME_BY_RGB.get(p[:3])


def shade(img: Canvas, x: int, y: int, steps: int) -> None:
    n = name_at(img, x, y)
    if n is None:
        return
    for _ in range(abs(steps)):
        n = (LIGHTER if steps > 0 else DARKER).get(n, n)
    img.set(x, y, n)


def shade_ellipse(img: Canvas, cx: float, cy: float, rx: float, ry: float, steps: int = -1,
                  dither: bool = True) -> None:
    """Darken (or lighten) the pixels under an ellipse; a 1 px checker fringe softens the rim."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d <= 0.78 or (dither and d <= 1.0 and (x + y) % 2 == 0):
                shade(img, x, y, steps)


def shade_rect(img: Canvas, x0: int, y0: int, x1: int, y1: int, steps: int) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            shade(img, x, y, steps)


def soft_light(img: Canvas, cx: float, cy: float, rx: float, ry: float, steps: int = 1,
               density: float = 0.55, mask=None) -> None:
    """A soft radial light (or shadow) pool: ordered-dither density fades from the centre out."""
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            d = math.sqrt(((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2)
            if d < 1.0 and (mask is None or mask(x, y)) and (1.0 - d) ** 0.8 * density > bayer(x, y):
                shade(img, x, y, steps)


def blob_patch(img: Canvas, cx: float, cy: float, rx: float, ry: float, seed: int, colours: tuple[str, str, str],
               pebbles: int = 4) -> None:
    """An organic patch (bare earth, moss...) with a noisy outline and a dithered rim."""
    dark, mid, light = colours
    rng = random.Random(seed)
    for y in range(int(cy - ry) - 3, int(cy + ry) + 4):
        for x in range(int(cx - rx) - 3, int(cx + rx) + 4):
            d = math.sqrt(((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2)
            d += (fbm(x, y, seed, 6, 2) - 0.5) * 0.7
            if d < 0.8:
                n = fbm(x, y, seed + 3, 5, 2)
                img.set(x, y, light if n > 0.68 else (dark if n < 0.3 else mid))
            elif d < 1.0 and (x + y) % 2 == 0:
                img.set(x, y, mid)
    for _ in range(pebbles):
        x, y = int(cx + rng.uniform(-rx, rx) * 0.6), int(cy + rng.uniform(-ry, ry) * 0.6)
        img.set(x, y, "stone_l")
        img.set(x + 1, y, "stone")


# --------------------------------------------------------------------------
# Deterministic value noise
# --------------------------------------------------------------------------

def hash01(ix: int, iy: int, seed: int) -> float:
    h = (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(x: float, y: float, seed: int, scale: float) -> float:
    fx, fy = x / scale, y / scale
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    a = hash01(ix, iy, seed)
    b = hash01(ix + 1, iy, seed)
    c = hash01(ix, iy + 1, seed)
    d = hash01(ix + 1, iy + 1, seed)
    return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty


def fbm(x: float, y: float, seed: int, scale: float, octaves: int = 3) -> float:
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total += vnoise(x, y, seed + o * 31, scale) * amp
        norm += amp
        amp *= 0.5
        scale *= 0.5
    return total / norm


# --------------------------------------------------------------------------
# Ground painters
# --------------------------------------------------------------------------

TUFTS = [
    [(0, 0), (1, 1), (2, 0)],
    [(0, 0), (1, 1), (2, 0), (3, 1), (4, 0)],
    [(0, 1), (1, 0), (2, 1)],
    [(0, 0), (0, 1), (2, 0)],
    [(1, 0), (0, 1), (2, 1)],
]


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x: int, y: int) -> float:
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def paint_ground(img: Canvas, rect: tuple[int, int, int, int], ramp: tuple[str, str, str], seed: int,
                 scale: float = 30.0, lo: float = 0.36, hi: float = 0.6, tufts: float = 0.35,
                 sparkle: float = 0.04, mask=None, max_light: float = 0.3, max_dark: float = 0.3) -> None:
    """Grass-like ground: mid colour with soft ordered-dither dark/light zones, tufts and highlights.

    ramp = (dark, mid, light). Zones never exceed max_light / max_dark pixel density, so the
    ground stays calm (no camouflage blobs). mask(x, y) -> bool limits the area.
    """
    dark, mid, light = ramp
    x0, y0, x1, y1 = rect
    for y in range(y0, y1):
        for x in range(x0, x1):
            if mask is not None and not mask(x, y):
                continue
            n = fbm(x, y, seed, scale)
            b = bayer(x, y)
            col = mid
            if n > hi and min(1.0, (n - hi) / 0.12) * max_light > b:
                col = light
            elif n < lo and min(1.0, (lo - n) / 0.12) * max_dark > b:
                col = dark
            img.set(x, y, col)
    rng = random.Random(seed * 7 + 1)
    step = 5
    for gy in range(y0, y1, step):
        for gx in range(x0, x1, step):
            if rng.random() >= tufts:
                continue
            tx, ty = gx + rng.randrange(step), gy + rng.randrange(step)
            if mask is not None and not mask(tx, ty):
                continue
            base = name_at(img, tx, ty)
            if base is None:
                continue
            dcol = DARKER.get(base, base)
            for (dx, dy) in rng.choice(TUFTS):
                if (mask is None or mask(tx + dx, ty + dy)) and x0 <= tx + dx < x1 and y0 <= ty + dy < y1:
                    img.set(tx + dx, ty + dy, dcol)
            if rng.random() < 0.35 and (mask is None or mask(tx + 1, ty - 1)):
                img.set(tx + 1, ty - 1, LIGHTER.get(base, base))
    for _ in range(int((x1 - x0) * (y1 - y0) * sparkle / 25)):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        if mask is None or mask(x, y):
            shade(img, x, y, 1)


def paint_path(img: Canvas, points: list[tuple[float, float]], width: float, seed: int,
               ramp: tuple[str, str, str] = ("gold_d", "dirt", "gold_l"), pebbles: int = 30,
               edge_dark: bool = True) -> None:
    """A worn dirt path along a polyline (image coords) with a wobbly, dithered edge."""
    rng = random.Random(seed)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    bx0, bx1 = int(min(xs) - width - 4), int(max(xs) + width + 4)
    by0, by1 = int(min(ys) - width - 4), int(max(ys) + width + 4)

    def seg_dist(px: float, py: float) -> float:
        best = 1e9
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            vx, vy = bx - ax, by - ay
            ll = vx * vx + vy * vy or 1e-9
            t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / ll))
            best = min(best, math.hypot(px - (ax + vx * t), py - (ay + vy * t)))
        return best

    dark, mid, light = ramp
    for y in range(max(0, by0), min(img.h, by1)):
        for x in range(max(0, bx0), min(img.w, bx1)):
            d = seg_dist(x + 0.5, y + 0.5) - (fbm(x, y, seed, 9, 2) - 0.5) * 4.0
            half = width / 2
            if d < half - 1:
                n = fbm(x, y, seed + 5, 7, 2)
                img.set(x, y, light if n > 0.66 else (dark if n < 0.3 else mid))
            elif d < half or (d < half + 1 and (x + y) % 2 == 0):
                if edge_dark:
                    shade(img, x, y, -1)
                else:
                    img.set(x, y, mid)
    for _ in range(pebbles):
        t = rng.random()
        k = min(len(points) - 2, int(t * (len(points) - 1)))
        (ax, ay), (bx, by) = points[k], points[k + 1]
        f = t * (len(points) - 1) - k
        px = ax + (bx - ax) * f + rng.uniform(-width / 2 + 1, width / 2 - 1)
        py = ay + (by - ay) * f + rng.uniform(-width / 2 + 1, width / 2 - 1)
        img.set(int(px), int(py), rng.choice(["stone_l", "stone", "gold_l"]))
        if rng.random() < 0.4:
            img.set(int(px) + 1, int(py), "stone")


# --------------------------------------------------------------------------
# Props: sphere-shaded clusters (trees, bushes, rocks), with a coloured outline
# --------------------------------------------------------------------------

LIGHT = (-0.55, -0.7, 0.45)


def _norm(v: tuple[float, float, float]) -> tuple[float, float, float]:
    m = math.sqrt(sum(c * c for c in v))
    return (v[0] / m, v[1] / m, v[2] / m)


def blob_canvas(w: int, h: int, blobs: list[tuple[float, float, float]], ramp: list[str], outline: str | None,
                seed: int = 0, light=LIGHT, texture: float = 0.22, rim: str | None = None,
                rim_side: float = -1.0, bias: float = 0.0) -> Canvas:
    """Union of shaded circles. Later blobs are in front. ramp is dark -> light."""
    lx, ly, lz = _norm(light)
    c = Canvas(w, h)
    owner: dict[tuple[int, int], int] = {}
    for y in range(h):
        for x in range(w):
            for i in range(len(blobs) - 1, -1, -1):
                bx, by, br = blobs[i]
                nx, ny = (x + 0.5 - bx) / br, (y + 0.5 - by) / br
                if nx * nx + ny * ny <= 1.0:
                    owner[(x, y)] = i
                    break
    for (x, y), i in owner.items():
        bx, by, br = blobs[i]
        nx, ny = (x + 0.5 - bx) / br, (y + 0.5 - by) / br
        nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
        v = nx * lx + ny * ly + nz * lz + bias
        v += (hash01(x // 2, y // 2, seed) - 0.5) * texture * 2
        idx = int((v + 0.35) / 1.25 * len(ramp))
        idx = max(0, min(len(ramp) - 1, idx))
        col = ramp[idx]
        # separate a front blob from the one behind it with a dark seam
        for dx, dy in ((0, -1), (-1, 0), (1, 0)):
            j = owner.get((x + dx, y + dy))
            if j is not None and j < i and ((x + dx + 0.5 - bx) / br) ** 2 + ((y + dy + 0.5 - by) / br) ** 2 > 1.0:
                col = ramp[0]
                break
        if rim is not None and nx * rim_side > 0.62 and ny < 0.4:
            col = rim
        c.set(x, y, col)
    if outline:
        c.outline_all(outline)
    return c


def tree(seed: int, size: int = 26, ramp=("forest", "leaf_d", "leaf", "leaf_l"), outline="forest_d",
         trunk=("brown_d", "brown"), rim: str | None = None, rim_side: float = -1.0, bias: float = 0.0) -> Canvas:
    """A round broadleaf tree: clustered canopy over a short trunk. Canvas is size x (size+8)."""
    rng = random.Random(seed)
    w, h = size + 2, size + 9
    r = size * 0.36
    cx, cy = w / 2, size * 0.48
    blobs = [(cx + rng.uniform(-1, 1), cy - r * 0.35, r * 0.85)]
    for k in range(5):
        a = math.pi * (0.85 + k * 0.32) + rng.uniform(-0.15, 0.15)
        blobs.append((cx + math.cos(a) * r * 0.7, cy + math.sin(a) * r * 0.45 - r * 0.2, r * rng.uniform(0.5, 0.62)))
    blobs.append((cx - r * 0.45, cy + r * 0.35, r * 0.6))
    blobs.append((cx + r * 0.5, cy + r * 0.3, r * 0.58))
    blobs.append((cx + rng.uniform(-1.5, 1.5), cy + r * 0.45, r * 0.62))
    canopy = blob_canvas(w, h, blobs, list(ramp), outline, seed, rim=rim, rim_side=rim_side, bias=bias)
    c = Canvas(w, h)
    tx = int(cx) - 2
    ty = int(cy + r * 0.6)
    for y in range(ty, h - 2):
        for x in range(tx, tx + 4):
            c.set(x, y, trunk[1] if x < tx + 2 else trunk[0])
    c.set(tx - 1, h - 3, trunk[0])
    c.set(tx + 4, h - 3, trunk[0])
    c.outline_all(outline)
    c.blit(canopy, 0, 0)
    return c


def pine(seed: int, height: int = 34, ramp=("forest_d", "forest", "leaf_d"), outline="night_d",
         trunk=("brown_d", "brown"), rim: str | None = None) -> Canvas:
    w = int(height * 0.7) | 1
    c = Canvas(w + 2, height + 2)
    cx = w // 2 + 1
    for y in range(height - 4, height):
        c.set(cx - 1, y, trunk[1])
        c.set(cx, y, trunk[0])
    tiers = 4
    for t in range(tiers):
        top = int(t * (height - 6) / (tiers + 0.6))
        bottom = top + int((height - 4) / tiers * 1.5)
        for y in range(top, min(bottom, height - 3)):
            k = (y - top) / max(1, bottom - top)
            half = 1 + k * (w / 2 - 1) * (0.55 + 0.45 * (t + 1) / tiers)
            for x in range(int(cx - half), int(cx + half) + 1):
                rel = (x - cx) / max(1, half)
                col = ramp[1]
                if rel < -0.25 and k < 0.8:
                    col = ramp[2]
                if rel > 0.35 or k > 0.85:
                    col = ramp[0]
                if rim and rel < -0.55 and k < 0.75:
                    col = rim
                c.set(x, y, col)
            if y == bottom - 1:
                for x in range(int(cx - half), int(cx + half) + 1, 2):
                    c.set(x, y + 1, ramp[0])
    c.outline_all(outline)
    return c


def bush(seed: int, w: int = 14, h: int = 10, ramp=("forest", "leaf_d", "leaf", "leaf_l"), outline="forest_d",
         flowers: list[str] | None = None, rim: str | None = None, rim_side: float = -1.0) -> Canvas:
    rng = random.Random(seed)
    blobs = []
    for k in range(4):
        blobs.append((2 + (w - 4) * (k + 0.5) / 4 + rng.uniform(-1, 1), h * 0.5 + rng.uniform(-1, 0.5),
                      h * rng.uniform(0.32, 0.42)))
    blobs.append((w / 2, h * 0.6, h * 0.45))
    c = blob_canvas(w + 2, h + 2, [(x + 1, y + 1, r) for x, y, r in blobs], list(ramp), outline, seed,
                    rim=rim, rim_side=rim_side)
    if flowers:
        for _ in range(max(2, w // 4)):
            x, y = rng.randrange(2, w), rng.randrange(2, h - 1)
            if c.opaque(x, y) and name_at(c, x, y) != outline:
                c.set(x, y, rng.choice(flowers))
    return c


def rock(seed: int, w: int = 10, h: int = 7, ramp=("stone_d", "stone", "stone_l", "white"),
         outline="iron", moss: str | None = "leaf_d") -> Canvas:
    rng = random.Random(seed)
    blobs = [(w * 0.5, h * 0.62, h * 0.55), (w * 0.33, h * 0.55, h * 0.45), (w * 0.68, h * 0.66, h * 0.42)]
    c = blob_canvas(w + 2, h + 2, [(x + 1, y + 1, r) for x, y, r in blobs], list(ramp), outline, seed,
                    texture=0.1)
    if moss:
        for _ in range(2):
            x = rng.randrange(2, w)
            for y in range(h + 1):
                if c.opaque(x, y) and name_at(c, x, y) != outline:
                    c.set(x, y, moss)
                    c.set(x + 1, y, moss)
                    break
    return c


def place(img: Canvas, prop: Canvas, x: int, y: int, shadow: tuple[float, float] | None = (1.0, 0.0),
          shadow_dx: float = 3.0, shadow_steps: int = -1) -> None:
    """Blit a prop with its top-left at (x, y) and a soft oval shadow at its base."""
    if shadow is not None:
        sw, extra = shadow
        rx = prop.w * 0.42 * sw
        shade_ellipse(img, x + prop.w / 2 + shadow_dx, y + prop.h - 2 + extra, rx, max(2.0, rx * 0.33), shadow_steps)
    img.blit(prop, x, y)


def flower(col: str, centre: str = "yellow") -> list[tuple[int, int, str]]:
    return [(0, -1, col), (-1, 0, col), (1, 0, col), (0, 1, col), (0, 0, centre)]


def sprinkle_flowers(img: Canvas, rect: tuple[int, int, int, int], n: int, seed: int, colours: list[str],
                     mask=None) -> None:
    rng = random.Random(seed)
    x0, y0, x1, y1 = rect
    for _ in range(n):
        x, y = rng.randrange(x0 + 1, x1 - 1), rng.randrange(y0 + 1, y1 - 2)
        if mask is not None and not mask(x, y):
            continue
        col = rng.choice(colours)
        img.set(x, y + 2, DARKER.get(name_at(img, x, y + 2) or "leaf", "leaf_d"))
        img.set(x, y + 1, "leaf_d")
        for dx, dy, cc in flower(col, "yellow" if col != "yellow" else "orange"):
            img.set(x + dx, y + dy, cc)


# --------------------------------------------------------------------------
# Hand-drawn props
# --------------------------------------------------------------------------

def sword_in_stone() -> Canvas:
    """The sword in the stone for level 1-1 (52x48): a mossy boulder with a shining sword."""
    c = Canvas(52, 48)
    stone = blob_canvas(50, 26, [(25, 15, 12), (13, 16, 9), (37, 16, 9.5), (19, 19, 8), (31, 19.5, 8),
                                 (25, 10, 8)],
                        ["stone_d", "stone", "stone_l", "white"], "iron", 3, texture=0.12, bias=-0.3)
    rng = random.Random(4)
    for x in range(4, 46):
        for y in range(0, 26):
            if stone.opaque(x, y) and name_at(stone, x, y) != "iron":
                if rng.random() < 0.55 and (x < 14 or x > 36 or y < 6):
                    stone.set(x, y, "leaf_d")
                    if stone.opaque(x, y + 1) and rng.random() < 0.6:
                        stone.set(x, y + 1, "forest")
                    if rng.random() < 0.4:
                        stone.set(x, y - 1 if stone.opaque(x, y - 1) else y, "leaf")
                break
    stone.line(33, 13, 36, 18, "stone_d")
    stone.line(12, 16, 15, 20, "stone_d")
    stone.line(26, 20, 28, 23, "stone_d")
    c.blit(stone, 1, 22)
    sword = Canvas(52, 48)
    cx = 25
    for y in range(9, 31):
        sword.set(cx, y, "white" if y < 18 else "steel_l")
        sword.set(cx + 1, y, "steel_l" if y < 14 else "steel")
    sword.set(cx, 9, "white")
    for x in range(cx - 5, cx + 7):
        sword.set(x, 7, "yellow")
        sword.set(x, 8, "gold_d" if x in (cx - 5, cx + 6) else "gold")
    sword.set(cx - 6, 7, "gold_d")
    sword.set(cx + 7, 7, "gold_d")
    for y in range(3, 7):
        sword.set(cx, y, "brown")
        sword.set(cx + 1, y, "brown_d")
    sword.set(cx, 4, "gold_d")
    sword.set(cx + 1, 4, "gold_d")
    for (x, y, col) in ((cx, 0, "yellow"), (cx + 1, 0, "gold"), (cx - 1, 1, "yellow"), (cx, 1, "red"),
                        (cx + 1, 1, "red_d"), (cx + 2, 1, "gold"), (cx, 2, "gold"), (cx + 1, 2, "gold_d")):
        sword.set(x, y, col)
    sword.outline_all()
    c.blit(sword, 0, 0)
    return c


def hedge_strip(w: int, seed: int, ramp=("forest", "leaf_d", "leaf", "leaf_l"), outline="forest_d",
                flowers: list[str] | None = None, h: int = 14, flower_every: int = 7) -> Canvas:
    """A long bumpy hedge (top face lit, front face in shade)."""
    rng = random.Random(seed)
    blobs = []
    x = 2.0
    while x < w - 1:
        r = rng.uniform(4.2, 5.6)
        blobs.append((x, 6.5 + rng.uniform(-0.8, 0.8), r))
        x += r * 1.15
    body = blob_canvas(w, h, blobs, list(ramp), None, seed)
    for y in range(9, h - 1):
        for xx in range(w):
            if y >= 9:
                body.set(xx, y, ramp[0] if y < h - 2 else DARKER[ramp[0]])
    for xx in range(0, w, 3):
        body.set(xx + rng.randrange(2), 9 + rng.randrange(3), ramp[1])
    if flowers:
        for _ in range(w // flower_every):
            fx, fy = rng.randrange(2, w - 2), rng.randrange(3, 8)
            if body.opaque(fx, fy):
                col = rng.choice(flowers)
                body.set(fx, fy, col)
                if flower_every < 5:
                    body.set(fx + 1, fy, col)
                    body.set(fx, fy + 1, DARKER.get(col, col))
    body.outline_all(outline)
    return body


def fence_strip(w: int, post_gap: int = 12, ramp=("brown_d", "brown", "gold_d", "gold_l"),
                outline="ink") -> Canvas:
    """Wooden fence seen from the front: posts and two rails."""
    c = Canvas(w, 13)
    for y, thick in ((3, 2), (8, 2)):
        for x in range(w):
            c.set(x, y, ramp[2])
            c.set(x, y + 1, ramp[1])
    for x in range(2, w, post_gap):
        for y in range(0, 12):
            c.set(x, y, ramp[2])
            c.set(x + 1, y, ramp[1])
            c.set(x + 2, y, ramp[0])
        c.set(x, 0, ramp[3])
        c.set(x + 1, 0, ramp[2])
    c.outline_all(outline)
    return c


def wheat_clump(seed: int, frame: int = 0, frames: int = 1, h: int = 14) -> Canvas:
    """A clump of wheat stalks; the heads lean with the wind phase (frame / frames)."""
    rng = random.Random(seed)
    c = Canvas(10, h + 2)
    for k in range(4):
        x = 2 + k * 2 + rng.randrange(2) - 1
        top = 3 + rng.randrange(3)
        phase = frame / max(1, frames) * 2 * math.pi - x * 0.35
        lean = int(round(math.sin(phase) * 1.2))
        for y in range(top + 3, h + 1):
            c.set(x, y, "gold_d" if y > h - 3 else "gold")
        for y in range(top, top + 4):
            hx = x + (lean if y < top + 2 else 0)
            c.set(hx, y, "gold_l" if y < top + 3 else "gold")
            if y == top:
                c.set(hx, y, "cream")
        c.set(x + (lean if lean else 1), top + 1, "gold_l")
    c.outline_all("gold_d")
    return c


def barn() -> Canvas:
    """Red barn with a dark roof, white trim and a hay loft (54x46)."""
    c = Canvas(56, 48)
    # roof (side view gable): rows 0..18
    for y in range(0, 19):
        half = 6 + y * 1.25
        for x in range(int(28 - half), int(28 + half) + 1):
            col = "brown_d" if (y // 3) % 2 == 0 else "brown"
            if x < 28 - half + 2:
                col = "brown"
            c.set(x, y, col)
    for y in range(0, 19):
        half = 6 + y * 1.25
        c.set(int(28 - half), y, "gold_d")
    # walls
    for y in range(19, 46):
        for x in range(5, 51):
            plank = (x - 5) % 5 == 0
            c.set(x, y, "red_d" if plank or x > 44 else "red")
    for x in range(5, 51):
        c.set(x, 19, "white")
        c.set(x, 45, "red_d")
    for y in range(19, 46):
        c.set(5, y, "white")
        c.set(50, y, "white")
    # loft window
    c.rect(23, 6, 10, 9, "ink")
    c.rect(24, 7, 8, 8, "brown_d")
    for x in range(24, 32):
        c.set(x, 11, "gold")
        c.set(x, 12, "gold_l")
        c.set(x, 13, "gold")
        c.set(x, 14, "gold_d")
    # big door with X
    c.rect(17, 27, 22, 19, "white")
    c.rect(18, 28, 20, 17, "red_d")
    for k in range(20):
        c.set(18 + k, 28 + int(k * 17 / 20), "white")
        c.set(37 - k, 28 + int(k * 17 / 20), "white")
    c.vline(27, 28, 44, "white")
    c.outline_all("ink")
    return c


def haystack(seed: int) -> Canvas:
    return blob_canvas(16, 12, [(8, 8, 6.5), (5, 8, 4.5), (11, 8, 4.5), (8, 5, 4.5)],
                       ["gold_d", "gold", "gold_l", "cream"], "brown", seed, texture=0.35)


def pumpkin(seed: int) -> Canvas:
    c = blob_canvas(9, 8, [(4.5, 4.8, 3.6), (2.6, 4.8, 2.6), (6.4, 4.8, 2.6)],
                    ["red_d", "orange", "orange", "yellow"], "brown_d", seed, texture=0.1)
    c.set(4, 0, "leaf_d")
    c.set(5, 0, "leaf")
    c.set(4, 1, "forest")
    return c


def stump(seed: int) -> Canvas:
    c = Canvas(12, 9)
    c.ellipse(6, 3, 5, 2.4, "gold_d")
    c.ellipse(6, 3, 3.4, 1.4, "dirt")
    c.set(6, 3, "gold_d")
    for y in range(4, 8):
        for x in range(1, 11):
            c.set(x, y, "brown" if x < 6 else "brown_d")
    c.set(0, 7, "brown_d")
    c.set(11, 7, "brown_d")
    c.outline_all("ink")
    return c


def mushroom(cap: str = "red") -> Canvas:
    c = Canvas(7, 7)
    c.ellipse(3.5, 2.5, 3, 2.2, cap)
    c.set(2, 1, "white")
    c.set(4, 2, "white")
    c.set(3, 4, "cream")
    c.set(3, 5, "cream")
    c.outline_all("ink")
    return c


def fern(seed: int, ramp=("forest_d", "forest", "leaf_d")) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(11, 8)
    for k, (dx, dy) in enumerate(((-1, -1), (1, -1), (-1, 0), (1, 0), (0, -1))):
        x, y = 5, 7
        for i in range(4 + rng.randrange(2)):
            x += dx if i % 2 == 0 else 0
            y += dy if dy else (-1 if i % 2 else 0)
            c.set(x, y, ramp[2] if i > 2 else ramp[1])
    c.outline_all(ramp[0])
    return c


def signpost() -> Canvas:
    c = Canvas(14, 16)
    c.rect(6, 4, 2, 11, "brown")
    c.rect(1, 2, 12, 5, "dirt")
    c.hline(1, 12, 2, "gold_l")
    c.hline(1, 12, 6, "gold_d")
    c.hline(3, 9, 4, "brown_d")
    c.set(12, 4, "gold_d")
    c.outline_all("ink")
    return c


def well() -> Canvas:
    c = Canvas(18, 22)
    c.rect(2, 12, 14, 8, "stone")
    for x in range(2, 16, 4):
        c.vline(x, 12, 19, "stone_d")
    c.hline(2, 15, 12, "stone_l")
    c.rect(4, 13, 10, 2, "night_d")
    c.vline(3, 3, 11, "brown")
    c.vline(14, 3, 11, "brown")
    for x in range(1, 17):
        c.set(x, 2 + abs(x - 8) // 3, "red_d")
        c.set(x, 3 + abs(x - 8) // 3, "red")
    c.outline_all("ink")
    return c


def crate() -> Canvas:
    c = Canvas(10, 10)
    c.rect(0, 0, 10, 10, "dirt")
    c.rect(1, 1, 8, 8, "gold_d")
    for k in range(8):
        c.set(1 + k, 1 + k, "dirt")
    c.hline(0, 9, 0, "gold_l")
    c.outline_all("ink")
    return c


def cabbage(seed: int) -> Canvas:
    return blob_canvas(8, 7, [(4, 4, 3.2), (2.5, 4, 2.2), (5.5, 4, 2.2)],
                       ["leaf_d", "leaf", "leaf_l", "leaf_l"], "forest", seed, texture=0.35)


def castle_gate(w: int = 304, h: int = 92) -> Canvas:
    """The castle wall with the black knight's gate (open, dark) between two towers.

    The wall's foot is the bottom row; the gate arch is centred. Towers have warm lit windows.
    """
    c = Canvas(w, h)
    wall_top = 30
    for y in range(wall_top, h):
        for x in range(w):
            row = (y - wall_top) // 6
            off = 5 if row % 2 else 0
            col = "stone"
            if (y - wall_top) % 6 == 0:
                col = "stone_d"
            elif (x + off) % 11 == 0:
                col = "stone_d"
            elif (y - wall_top) % 6 == 1 and (x + off) % 11 in (1, 2, 3, 4):
                col = "stone_l"
            if y > h - 8 and bayer(x, y) < (y - (h - 8)) / 10:
                col = DARKER[col]
            c.set(x, y, col)
    for x in range(0, w, 12):
        c.rect(x, wall_top - 8, 7, 9, "stone")
        c.hline(x, x + 6, wall_top - 8, "stone_l")
        c.vline(x + 6, wall_top - 8, wall_top, "stone_d")
    cx = w // 2
    for tx in (cx - 74, cx + 42):
        for y in range(0, h):
            for x in range(tx, tx + 32):
                col = "stone_l" if x < tx + 3 else ("stone_d" if x > tx + 27 else "stone")
                if y % 6 == 0:
                    col = "stone_d"
                c.set(x, y, col)
        for x in range(tx - 2, tx + 34, 8):
            c.rect(x, 0, 5, 4, "stone")
            c.hline(x, x + 4, 0, "stone_l")
        # lit window
        c.rect(tx + 12, 14, 8, 13, "night_d")
        c.ellipse(tx + 16, 14, 4, 4, "night_d")
        c.rect(tx + 13, 15, 6, 11, "orange")
        c.rect(tx + 14, 16, 4, 9, "yellow")
        c.vline(tx + 16, 12, 26, "iron")
        c.hline(tx + 12, tx + 19, 20, "iron")
    # gate arch
    gx, gw = cx - 26, 52
    for y in range(wall_top + 4, h):
        for x in range(gx, gx + gw):
            dx = (x + 0.5 - (gx + gw / 2)) / (gw / 2)
            top = wall_top + 4 + (1 - math.sqrt(max(0.0, 1 - dx * dx))) * 24
            if y >= top:
                depth = y - top
                c.set(x, y, "night_d" if depth > 2 or (x + y) % 2 else "ink")
            elif y >= top - 4:
                c.set(x, y, "stone_d" if y >= top - 1 else ("stone_l" if (x // 4) % 2 else "stone"))
    for x in range(gx + 5, gx + gw - 4, 5):
        for y in range(wall_top + 14, wall_top + 21):
            c.set(x, y, "iron")
        c.set(x, wall_top + 21, "steel_d")
    c.hline(gx + 3, gx + gw - 4, wall_top + 14, "iron")
    c.outline_all("ink")
    return c


# --------------------------------------------------------------------------
# Animated layers (small sprite sheets shared by the background scenes)
# --------------------------------------------------------------------------

def _anim_wheat_row() -> list[Anim]:
    """A 48x18 strip of wheat clumps; 8 frames of a wind wave travelling to the right."""
    frames = []
    for f in range(8):
        c = Canvas(48, 18)
        for k in range(6):
            # phase per clump: shift the wave by clump position so it travels across the strip
            ph = (f + k * 8 / 6) % 8
            clump = wheat_clump(100 + k, frame=int(round(ph)) % 8, frames=8)
            c.blit(clump, k * 8, 1 if k % 2 else 0)
        frames.append(c)
    return [Anim("default", frames, 6.0, True)]


def _anim_grass_tuft() -> list[Anim]:
    frames = []
    for f in range(4):
        c = Canvas(9, 8)
        lean = [0, 1, 0, -1][f]
        for k, (x, hgt) in enumerate(((1, 5), (3, 7), (5, 6), (7, 4))):
            for y in range(8 - hgt, 8):
                dx = lean if y < 8 - hgt + 2 else 0
                c.set(x + dx, y, "leaf_l" if y < 8 - hgt + 2 else "leaf")
        c.outline_all("leaf_d")
        frames.append(c)
    return [Anim("default", frames, 3.0, True)]


def _anim_flower(col: str) -> list[Anim]:
    frames = []
    for f in range(4):
        c = Canvas(7, 9)
        lean = [0, 1, 0, -1][f]
        c.vline(3, 4, 8, "leaf_d")
        c.set(2, 6, "leaf")
        c.set(4, 7, "leaf")
        cx = 3 + lean
        for dx, dy, cc in flower(col, "yellow" if col != "yellow" else "orange"):
            c.set(cx + dx, 2 + dy, cc)
        frames.append(c)
    return [Anim("default", frames, 2.5, True)]


def _anim_water_glint(cols: tuple[str, str]) -> list[Anim]:
    frames = []
    shapes = [[], [(2, 1)], [(1, 1), (2, 1), (3, 1)], [(0, 1), (1, 0), (3, 0), (4, 1)], [(0, 2), (4, 2)], []]
    for i, pts in enumerate(shapes):
        c = Canvas(5, 3)
        for (x, y) in pts:
            c.set(x, y, cols[0] if i < 3 else cols[1])
        frames.append(c)
    return [Anim("default", frames, 7.0, True, [6.0, 1, 1, 1, 1, 6.0])]


def _anim_banner() -> list[Anim]:
    frames = []
    for f in range(4):
        c = Canvas(12, 18)
        c.hline(0, 11, 0, "brown_d")
        c.hline(0, 11, 1, "brown")
        for y in range(2, 16):
            wave = int(round(math.sin(f / 4 * 2 * math.pi + y * 0.45) * 1.1)) if y > 4 else 0
            for x in range(2, 10):
                col = "violet" if 3 <= x <= 8 else "plum"
                c.set(x + wave, y, col)
        for y in (6, 7, 8):
            for x in (5, 6):
                c.set(x + (int(round(math.sin(f / 4 * 2 * math.pi + y * 0.45) * 1.1))), y, "lilac")
        c.set(5, 16, "plum")
        c.set(8, 16, "plum")
        c.outline_all("ink")
        frames.append(c)
    return [Anim("default", frames, 5.0, True)]


def _anim_torch() -> list[Anim]:
    frames = []
    shapes = [
        [".Y.", "YwY", "OYO", ".O."],
        ["..Y", ".YY", "YwO", ".OO"],
        [".Y.", ".Y.", "YwY", "OOO"],
        ["Y..", "YY.", "OwY", "OO."],
    ]
    for s in shapes:
        c = Canvas(7, 11)
        c.stamp(s, 2, 1, {"Y": "yellow", "w": "white", "O": "orange"}, outline="red_d")
        c.rect(3, 6, 2, 1, "steel_d")
        c.rect(2, 5, 4, 1, "iron")
        c.vline(3, 7, 10, "brown")
        c.vline(4, 7, 10, "brown_d")
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


def _anim_windmill() -> list[Anim]:
    frames = []
    for f in range(8):
        c = Canvas(31, 31)
        cx = cy = 15
        a0 = f / 8 * math.pi / 2
        for k in range(4):
            a = a0 + k * math.pi / 2
            for d in range(2, 15):
                x = cx + math.cos(a) * d
                y = cy + math.sin(a) * d
                c.set(int(round(x)), int(round(y)), "brown")
                if d > 5:
                    px, py = -math.sin(a), math.cos(a)
                    for w in (1, 2, 3):
                        c.set(int(round(x + px * w)), int(round(y + py * w)), "cream" if w < 3 else "stone_l")
        c.outline_all("brown_d")
        c.set(cx, cy, "brown_d")
        c.set(cx + 1, cy, "gold_d")
        frames.append(c)
    return [Anim("default", frames, 6.0, True)]


def _anim_sword_glint() -> list[Anim]:
    frames = []
    for f in range(8):
        c = Canvas(9, 9)
        if f == 1:
            c.set(4, 4, "white")
        elif f in (2, 3):
            r = 2 if f == 2 else 3
            for d in range(-r, r + 1):
                c.set(4 + d, 4, "white" if abs(d) < 2 else "yellow")
                c.set(4, 4 + d, "white" if abs(d) < 2 else "yellow")
        elif f == 4:
            c.set(4, 4, "yellow")
            for d in (-1, 1):
                c.set(4 + d, 4, "gold_l")
                c.set(4, 4 + d, "gold_l")
        frames.append(c)
    return [Anim("default", frames, 10.0, True, [14, 1, 1, 1, 1, 1, 1, 1])]


def _anim_eyes() -> list[Anim]:
    """Glowing eyes deep in the dusk forest (blink now and then). Decoration only."""
    frames = []
    for f in range(3):
        c = Canvas(5, 2)
        if f == 0:
            for x in (0, 1, 3, 4):
                c.set(x, 0, "yellow")
        elif f == 1:
            for x in (0, 1, 3, 4):
                c.set(x, 1, "gold_d")
        frames.append(c)
    return [Anim("default", frames, 4.0, True, [14, 1, 3])]


ANIMS = {
    "wheat_row": (_anim_wheat_row, (48, 18)),
    "grass_tuft": (_anim_grass_tuft, (9, 8)),
    "flower_pink": (lambda: _anim_flower("pink"), (7, 9)),
    "flower_white": (lambda: _anim_flower("white"), (7, 9)),
    "flower_yellow": (lambda: _anim_flower("yellow"), (7, 9)),
    "flower_lilac": (lambda: _anim_flower("lilac"), (7, 9)),
    "water_glint": (lambda: _anim_water_glint(("sky_l", "sky")), (5, 3)),
    "night_glint": (lambda: _anim_water_glint(("steel_l", "steel")), (5, 3)),
    "banner": (_anim_banner, (12, 18)),
    "torch": (_anim_torch, (7, 11)),
    "windmill": (_anim_windmill, (31, 31)),
    "sword_glint": (_anim_sword_glint, (9, 9)),
    "eyes": (_anim_eyes, (5, 2)),
}

# particle textures (may use transparency): assets/backgrounds/anim/p_<name>.png
PARTICLE_TEX = {
    "petal": ["pink:.x.", "pink:xxx"],
}


def particle_textures() -> dict[str, Canvas]:
    t: dict[str, Canvas] = {}
    c = Canvas(3, 2)
    c.set(1, 0, "pink")
    c.set(0, 1, "pink")
    c.set(1, 1, "white")
    c.set(2, 1, "pink")
    t["petal"] = c
    c = Canvas(3, 3)
    c.set(1, 1, "yellow")
    for (x, y) in ((0, 1), (2, 1), (1, 0), (1, 2)):
        c.set(x, y, "gold_l@150")
    t["firefly"] = c
    c = Canvas(1, 4)
    for y in range(4):
        c.set(0, y, "sky_l@%d" % (90 + y * 40))
    t["rain"] = c
    c = Canvas(3, 1)
    c.set(0, 0, "steel_l@170")
    c.set(2, 0, "steel_l@170")
    t["ripple"] = c
    c = Canvas(2, 1)
    c.set(0, 0, "gold_l")
    c.set(1, 0, "cream")
    t["chaff"] = c
    c = Canvas(3, 2)
    c.set(0, 0, "orange")
    c.set(1, 0, "gold")
    c.set(1, 1, "orange")
    c.set(2, 1, "gold_d")
    t["leaf"] = c
    c = Canvas(1, 1)
    c.set(0, 0, "white")
    t["mote"] = c
    c = Canvas(3, 2)
    c.set(0, 0, "rose")
    c.set(1, 0, "orange")
    c.set(1, 1, "rose")
    c.set(2, 1, "dusk")
    t["leaf_dusk"] = c
    return t


# --------------------------------------------------------------------------
# Scenes
# --------------------------------------------------------------------------

class Scene:
    def __init__(self, base: str = "leaf_d") -> None:
        self.img = Canvas(IMG_W, IMG_H, rgba(base))
        self.anims: list[tuple[str, int, int, int, float, bool]] = []
        self.particles: list[dict] = []
        self.modulate: tuple[float, float, float] | None = None
        self.lightning = False
        self.light_shafts: list[tuple] = []   # (world x at top, width, alpha[, (r, g, b)])

    @staticmethod
    def w2i(wx: float, wy: float) -> tuple[int, int]:
        return int(wx - ORIGIN[0]), int(wy - ORIGIN[1])

    def anim(self, kind: str, ix: int, iy: int, frame: int = 0, speed: float = 1.0, flip: bool = False) -> None:
        """Add an animated prop with its top-left at image pixel (ix, iy)."""
        self.anims.append((kind, ix, iy, frame, speed, flip))

    def particle(self, **kw) -> None:
        self.particles.append(kw)


def in_arena(x: int, y: int) -> bool:
    return AX0 <= x < AX1 and AY0 <= y < AY1


GREEN = ("leaf_d", "leaf", "leaf_l")
# arena ground: very soft variation so actors and telegraphs always read first
CALM = {"max_light": 0.16, "max_dark": 0.16}
TREE_GREEN = ("forest", "leaf_d", "leaf", "leaf_l")


def arena_edge_shadow(img: Canvas, depth: int = 4, sides: bool = True) -> None:
    """Darken the arena just below the top border (the hedge casts a shadow) and a 1 px rim at the sides."""
    for y in range(AY0, AY0 + depth):
        for x in range(AX0, AX1):
            if y < AY0 + depth - 1 or (x + y) % 2 == 0:
                shade(img, x, y, -1)
    if sides:
        for y in range(AY0, AY1):
            shade(img, AX0, y, -1)
            shade(img, AX1 - 1, y, -1)


def arena_vignette(img: Canvas, depth: int = 14, density: float = 0.28) -> None:
    """Darken the arena's outer rim with a soft ordered dither so the eye rests on the middle."""
    for y in range(AY0, AY1):
        for x in range(AX0, AX1):
            d = min(x - AX0, AX1 - 1 - x, y - AY0, AY1 - 1 - y)
            if d < depth and (1 - d / depth) * density > bayer(x, y):
                shade(img, x, y, -1)


def hedge_row(sc: Scene, y_bottom: int, x0: int, x1: int, seed: int, ramp=TREE_GREEN, outline="forest_d",
              flowers=None, flower_every: int = 7) -> None:
    strip = hedge_strip(x1 - x0, seed, ramp, outline, flowers, flower_every=flower_every)
    sc.img.blit(strip, x0, y_bottom - strip.h)


def side_hedges(sc: Scene, seed: int, ramp=TREE_GREEN, outline="forest_d") -> None:
    """Vertical hedge columns just outside the arena's left and right edges (seen on wide phones)."""
    for side, x in ((0, AX0 - 12), (1, AX1)):
        rng = random.Random(seed + side)
        col = Canvas(12, AY1 - AY0 + 4)
        blobs = [(6 + rng.uniform(-1, 1), y + 3, rng.uniform(4.5, 5.5)) for y in range(0, AY1 - AY0 + 4, 7)]
        col = blob_canvas(12, AY1 - AY0 + 6, blobs, list(ramp), outline, seed + side)
        sc.img.blit(col, x, AY0 - 3)


def scene_sword_stone() -> Scene:
    """1-1 石中劍之丘: early morning. Fresh meadow, the sword in the stone on the hill above the arena."""
    sc = Scene("forest")
    img = sc.img
    paint_ground(img, (0, 0, IMG_W, IMG_H), GREEN, 11, tufts=0.45)
    # arena: calmer, slightly lighter grass
    paint_ground(img, (AX0, AY0, AX1, AY1), GREEN, 12, scale=34, lo=0.3, hi=0.66, tufts=0.22, sparkle=0.02,
                 **CALM)
    # a worn path from the bottom up to the stone
    paint_path(img, [(150, 520), (146, 440), (156, 400), (152, 384)], 14, 5)
    paint_path(img, [(152, 150), (152, 132), (152, 118)], 12, 6, pebbles=10)
    sprinkle_flowers(img, (AX0 + 6, AY0 + 10, AX1 - 6, AY1 - 6), 14, 3, ["white", "yellow", "pink"])
    arena_edge_shadow(img)
    arena_vignette(img)
    # top: a dark tree line behind the HUD, then the hill with the sword in the stone
    for i, x in enumerate(range(-14, IMG_W, 22)):
        place(img, tree(20 + i, 30), x, -2 + (i * 7) % 9, shadow=None)
    for i, x in enumerate(range(-4, IMG_W, 26)):
        place(img, tree(40 + i, 28), x, 22 + (i * 5) % 11, shadow=(1.0, 1))
    for i, x in enumerate((-6, 22, 226, 258, 286)):
        place(img, tree(60 + i, 26), x, 58 + (i * 9) % 13)
    for x, y, s in ((56, 112, 70), (234, 104, 71), (40, 140, 72), (244, 138, 73)):
        place(img, bush(s, 16, 10, TREE_GREEN, flowers=["white", "pink"]), x, y)
    stone = sword_in_stone()
    sx, sy = sc.w2i(90, 40)
    soft_light(img, sx, sy + 10, 52, 22, +1, 0.6)
    sprinkle_flowers(img, (sx - 50, sy - 6, sx + 50, sy + 24), 22, 14, ["white", "yellow"],
                     mask=lambda x, y: abs(x - sx) > 22 or y > sy + 22)
    place(img, stone, sx - 26, sy - 24, shadow=(0.9, -4), shadow_dx=5)
    sc.anim("sword_glint", sx - 4, sy - 25, 0, 1.0)
    for k, (rx, ry) in enumerate(((sx - 58, sy + 4), (sx + 46, sy + 2), (sx - 74, sy + 18), (sx + 64, sy + 16))):
        menhir = blob_canvas(9, 15, [(4.5, 5, 3.6), (4.5, 9, 4), (4.5, 12, 4)], ["stone_d", "stone", "stone_l"],
                             "iron", 30 + k, texture=0.1)
        place(img, menhir, rx, ry, shadow=(1.2, 0), shadow_dx=4)
    sc.light_shafts = [(30, 30, 0.06), (70, 16, 0.08), (-60, 22, 0.05), (160, 18, 0.04)]
    hedge_row(sc, AY0, AX0 - 12, AX1 + 12, 7, flowers=["white", "pink", "yellow"])
    hedge_row(sc, AY1 + 14, AX0 - 12, AX1 + 12, 8, flowers=["white", "yellow"])
    side_hedges(sc, 9)
    # bottom band: path out, flowers, bushes and trees
    for x, y, s in ((10, 410, 1), (220, 418, 2), (80, 430, 3), (250, 452, 4), (30, 470, 5), (190, 470, 6)):
        place(img, bush(s, 18, 11, TREE_GREEN, flowers=["white", "pink", "yellow"]), x, y)
    for i, x in enumerate((-10, 40, 210, 262)):
        place(img, tree(80 + i, 28), x, 478 + (i * 7) % 12)
    sprinkle_flowers(img, (0, 400, IMG_W, 470), 40, 4, ["white", "yellow", "pink", "lilac"])
    # animated
    for i, (x, y) in enumerate(((70, 146), (100, 150), (196, 148), (226, 150), (78, 392), (204, 394), (130, 396))):
        sc.anim("grass_tuft", x, y, i % 4, 0.8 + (i % 3) * 0.15)
    for i, (x, y, kind) in enumerate(((24, 428, "flower_white"), (118, 444, "flower_pink"), (176, 436, "flower_yellow"),
                                      (276, 420, "flower_pink"), (46, 120, "flower_yellow"), (262, 126, "flower_white"))):
        sc.anim(kind, x, y, i % 4, 0.9 + (i % 2) * 0.2)
    sc.particle(kind="mote", amount=10, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -4), spread=180,
                speed=(2, 5), gravity=(0, 0), colour_fade=True)
    return sc


def scene_wheat_field() -> Scene:
    """1-2 麥田小徑: bright day in golden wheat. A grassy clearing with cart tracks crosses the field."""
    sc = Scene("gold")
    img = sc.img
    # wheat everywhere outside the arena
    paint_ground(img, (0, 0, IMG_W, IMG_H), ("gold_d", "gold", "gold_l"), 21, scale=20, lo=0.4, hi=0.62,
                 tufts=0.9, sparkle=0.1)
    # arena: warm green clearing
    paint_ground(img, (AX0, AY0, AX1, AY1), GREEN, 22, scale=32, lo=0.3, hi=0.66,
                 tufts=0.25, sparkle=0.02, **CALM)
    arena_vignette(img)
    # cart tracks (two ruts) through the field and the clearing
    for off in (-7, 7):
        paint_path(img, [(118 + off, -10), (126 + off, 140), (150 + off, 260), (140 + off, 400), (150 + off, 520)],
                   4, 30 + off, pebbles=8, ramp=("gold_d", "dirt", "dirt"))
    arena_edge_shadow(img, 3)
    # wheat walls (static base rows) + animated wheat strips on top
    rng = random.Random(23)
    def track_x(y: float) -> float:
        pts = [(-10, 118), (140, 126), (260, 150), (400, 140), (520, 150)]
        for (ya, xa), (yb, xb) in zip(pts, pts[1:]):
            if ya <= y <= yb:
                return xa + (xb - xa) * (y - ya) / (yb - ya)
        return 140

    for y in range(-8, IMG_H, 6):
        for x in range(-6 + (y // 6 % 2) * 4, IMG_W, 7):
            if in_arena(x + 5, y + 14) or in_arena(x + 5, y + 4):
                continue
            if abs(x + 5 - track_x(y + 12)) < 15:
                continue
            img.blit(wheat_clump(rng.randrange(1000)), x + rng.randrange(2), y + rng.randrange(2))
    # a big oak, a signpost and a scarecrow-free farm cart corner
    place(img, tree(201, 34), 8, 20)
    place(img, tree(202, 30), 250, 42)
    place(img, signpost(), 160, 132)
    place(img, haystack(3), 30, 122)
    place(img, haystack(4), 244, 404)
    # animated wheat rows along the arena's top and bottom edges
    for i, x in enumerate(range(-4, IMG_W, 48)):
        if not (100 <= x <= 150):
            sc.anim("wheat_row", x, AY0 - 16, (i * 3) % 8, 1.0)
        sc.anim("wheat_row", x, AY0 - 34, (i * 3 + 2) % 8, 1.0)
        if not (110 <= x <= 160):
            sc.anim("wheat_row", x, AY1 - 6, (i * 3 + 4) % 8, 1.0)
        sc.anim("wheat_row", x, AY1 + 12, (i * 3 + 6) % 8, 1.0)
    for y in range(AY0, AY1 - 10, 18):
        sc.anim("wheat_row", AX0 - 46, y, (y // 18) % 8, 1.0)
        sc.anim("wheat_row", AX1 - 2, y, (y // 18 + 4) % 8, 1.0)
    sc.particle(kind="chaff", amount=8, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(1, 0), spread=25,
                speed=(8, 14), gravity=(0, 1), colour_fade=True)
    return sc


def scene_meadow() -> Scene:
    """1-3 老朋友: a flowery meadow at full day, blossom trees, a little pond, drifting petals."""
    sc = Scene("leaf_d")
    img = sc.img
    paint_ground(img, (0, 0, IMG_W, IMG_H), GREEN, 31, tufts=0.5)
    paint_ground(img, (AX0, AY0, AX1, AY1), GREEN, 32, scale=34, lo=0.28, hi=0.68, tufts=0.22, sparkle=0.02,
                 **CALM)
    sprinkle_flowers(img, (0, 0, IMG_W, IMG_H), 220, 33, ["white", "yellow", "pink", "lilac"],
                     mask=lambda x, y: not in_arena(x, y))
    sprinkle_flowers(img, (AX0 + 4, AY0 + 6, AX1 - 4, AY1 - 4), 22, 34, ["white", "yellow", "pink"])
    arena_vignette(img)
    # flower patches near the arena corners
    for (cx, cy) in ((AX0 + 14, AY0 + 14), (AX1 - 16, AY1 - 18)):
        sprinkle_flowers(img, (cx - 10, cy - 8, cx + 10, cy + 8), 10, cx, ["pink", "white"])
    arena_edge_shadow(img)
    # clover and flower clumps in the arena corners
    for (cx, cy, sd) in ((AX0 + 16, AY0 + 18, 1), (AX1 - 18, AY0 + 30, 2), (AX0 + 20, AY1 - 22, 3),
                         (AX1 - 22, AY1 - 16, 4)):
        soft_light(img, cx, cy, 12, 8, -1, 0.3)
        sprinkle_flowers(img, (cx - 10, cy - 7, cx + 10, cy + 7), 6, sd + 90, ["pink", "white", "yellow"])
    # the pond on the left of the top band, with lily pads and reeds
    pond = Canvas(78, 32)
    pond.ellipse(39, 16, 38, 15, "water")
    pond.ellipse(37, 14, 30, 10, "sky")
    pond.ellipse(33, 11, 16, 4, "sky_l")
    pond.outline_all("water_d")
    pond.outline_all("leaf_d")
    for x, y in ((10, 12), (16, 21), (60, 9), (64, 20), (44, 23)):
        pond.stamp([".e.", "eLe", ".e."], x, y, {"e": "leaf", "L": "leaf_l"}, outline="forest")
    pond.set(17, 21, "pink")
    pond.set(61, 9, "white")
    px0, py0 = 66, 100
    shade_ellipse(img, px0 + 40, py0 + 18, 42, 17, -1)
    img.blit(pond, px0, py0)
    for k in range(6):
        reed = Canvas(4, 9)
        for x in (0, 2):
            reed.vline(x, 2 + x, 8, "leaf_d")
            reed.set(x, 1 + x, "brown")
            reed.set(x, 2 + x, "brown_d")
        img.blit(reed, px0 + 2 + k * 3 if k < 3 else px0 + 66 + (k - 3) * 3, py0 + 16 - (k % 3) * 2)
    for x, y in ((px0 + 22, py0 + 12), (px0 + 46, py0 + 7), (px0 + 38, py0 + 19)):
        sc.anim("water_glint", x, y, (x + y) % 6, 0.8)
    # blossom trees and green trees above
    blossom = ("dusk", "rose", "pink", "white")
    for i, x in enumerate(range(-10, IMG_W, 22)):
        place(img, tree(300 + i, 30, TREE_GREEN), x, 34 + (i * 7) % 8, shadow=None)
    for i, (x, y) in enumerate(((176, 70), (214, 92), (250, 66), (14, 84), (-14, 110))):
        place(img, tree(320 + i, 32, blossom, "plum"), x, y, shadow_dx=4)
    for x, y, s2 in ((160, 136, 1), (236, 140, 3), (44, 138, 4)):
        place(img, bush(s2, 16, 10, TREE_GREEN, flowers=["pink", "white", "yellow"]), x, y)
    sprinkle_flowers(img, (40, 90, 270, 150), 60, 38, ["pink", "white", "yellow", "lilac"],
                     mask=lambda x, y: not (px0 - 2 <= x <= px0 + 80 and py0 - 2 <= y <= py0 + 34))
    hedge_row(sc, AY0, AX0 - 12, AX1 + 12, 35, flowers=["pink", "white", "lilac", "pink"], flower_every=3)
    hedge_row(sc, AY1 + 14, AX0 - 12, AX1 + 12, 36, flowers=["pink", "white", "yellow"], flower_every=3)
    side_hedges(sc, 37)
    for i, (x, y) in enumerate(((-6, 440), (60, 470), (150, 452), (236, 466), (276, 430))):
        place(img, tree(340 + i, 30, blossom if i % 2 else TREE_GREEN, "plum" if i % 2 else "forest_d"), x, y)
    for x, y, s in ((20, 404, 5), (110, 410, 6), (200, 404, 7), (260, 404, 8)):
        place(img, bush(s, 18, 11, TREE_GREEN, flowers=["pink", "white"]), x, y)
    for i, (x, y, kind) in enumerate(((14, 160, "flower_pink"), (36, 220, "flower_white"), (20, 300, "flower_lilac"),
                                      (250, 180, "flower_yellow"), (270, 250, "flower_pink"), (256, 340, "flower_white"),
                                      (96, 400, "flower_pink"), (176, 398, "flower_yellow"), (150, 132, "flower_white"),
                                      (196, 140, "flower_pink"), (58, 146, "flower_lilac"))):
        sc.anim(kind, x, y, i % 4, 0.85 + (i % 3) * 0.12)
    sc.particle(kind="petal", amount=12, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.6), spread=20,
                speed=(8, 14), gravity=(0, 2), colour_fade=True, spin=True)
    return sc


def scene_farm_fence() -> Scene:
    """1-4 稻草人包圍網: late afternoon on the farm. Fences all round, barn, windmill, long shadows."""
    sc = Scene("moss_d")
    img = sc.img
    paint_ground(img, (0, 0, IMG_W, IMG_H), ("moss_d", "moss", "leaf_l"), 41, scale=26, tufts=0.5)
    paint_ground(img, (AX0, AY0, AX1, AY1), ("moss_d", "moss", "leaf_l"), 42, scale=34, lo=0.3, hi=0.7,
                 tufts=0.25, sparkle=0.02, **CALM)
    arena_vignette(img)
    # dirt patches trampled by the scarecrows
    for (cx, cy, rx, ry, sd) in ((96, 206, 16, 9, 1), (206, 296, 14, 8, 2), (130, 356, 11, 6, 3),
                                 (216, 196, 8, 5, 4)):
        blob_patch(img, cx, cy, rx, ry, sd, ("gold_d", "dirt", "gold_l"))
    paint_path(img, [(-10, 120), (60, 128), (150, 140), (230, 126), (320, 132)], 10, 44, pebbles=12)
    paint_path(img, [(152, 384), (150, 450), (160, 530)], 12, 45)
    arena_edge_shadow(img, 3)
    # crop rows top-left, pumpkins top-right
    for row in range(3):
        for k in range(8):
            place(img, cabbage(k + row * 10), 4 + k * 11 + row % 2 * 5, 92 + row * 10, shadow=(0.8, 0))
    for k, (x, y) in enumerate(((236, 96), (254, 104), (270, 92), (284, 108), (246, 116))):
        place(img, pumpkin(k), x, y, shadow=(1.0, 0))
    # barn and windmill on the far side (under the HUD)
    for i, x in enumerate(range(-12, IMG_W, 24)):
        place(img, tree(400 + i, 28, ("brown", "gold_d", "gold", "gold_l"), "brown_d"), x, -6 + (i * 5) % 9,
              shadow=None)
    b = barn()
    place(img, b, 150, 30, shadow=(1.1, 0), shadow_dx=10)
    mill = Canvas(20, 40)
    for y in range(0, 40):
        half = 4 + y * 0.12
        for x in range(int(10 - half), int(10 + half) + 1):
            mill.set(x, y, "stone_l" if x < 9 else ("stone" if x < 12 else "stone_d"))
    mill.rect(8, 30, 4, 10, "brown_d")
    mill.rect(8, 12, 3, 4, "night_d")
    mill.outline_all("ink")
    for x in range(1, 19):
        mill.set(x, 0, "red_d")
        mill.set(x, 1, "red")
    place(img, mill, 82, 54, shadow=(1.2, 0), shadow_dx=8)
    sc.anim("windmill", 77, 42, 0, 1.0)
    for k, (x, y) in enumerate(((214, 68), (230, 72), (46, 66))):
        place(img, haystack(10 + k), x, y, shadow=(1.0, 0), shadow_dx=5)
    place(img, well(), 22, 130, shadow=(1.0, 0), shadow_dx=6)
    # fences around the arena (long shadows to the right: the sun is low in the west)
    top = fence_strip(AX1 - AX0 + 24)
    for x in range(AX0 - 12, AX1 + 12):
        for y in range(AY0 - 1, AY0 + 3):
            if (x - AX0) % 12 in (2, 3, 4, 5, 6, 7) or y == AY0 - 1:
                shade(img, x + 3, y + 1, -1)
    img.blit(top, AX0 - 12, AY0 - 12)
    bot = fence_strip(AX1 - AX0 + 24)
    img.blit(bot, AX0 - 12, AY1 + 1)
    for x in range(AX0 - 12, AX1 + 12):
        shade(img, x + 4, AY1 + 14, -1)
    for side_x in (AX0 - 8, AX1 + 4):
        for y in range(AY0 - 8, AY1 + 8, 12):
            post = Canvas(5, 12)
            post.rect(1, 0, 3, 11, "gold_d")
            post.vline(1, 0, 10, "gold_l")
            post.vline(3, 0, 10, "brown")
            post.outline_all("ink")
            img.blit(post, side_x, y)
            shade_ellipse(img, side_x + 9, y + 11, 6, 2, -1, dither=False)
    # bottom band
    for k, (x, y) in enumerate(((20, 404), (34, 412), (232, 420), (250, 410))):
        place(img, crate() if k % 2 else pumpkin(k + 7), x, y, shadow=(1.0, 0), shadow_dx=4)
    for i, (x, y) in enumerate(((-8, 440), (60, 470), (210, 460), (262, 438))):
        place(img, tree(420 + i, 30, ("brown", "gold_d", "gold", "gold_l"), "brown_d"), x, y, shadow_dx=8)
    for row in range(3):
        for k in range(7):
            place(img, cabbage(40 + k + row * 9), 180 + k * 11 + row % 2 * 5, 470 + row * 10, shadow=(0.8, 0))
    # warm low sunlight: lighten the top-left of everything a little
    for y in range(0, IMG_H):
        for x in range(0, IMG_W):
            if not in_arena(x, y) and (x * 2 + y) % 97 < 2 and hash01(x, y, 5) < 0.6:
                shade(img, x, y, 1)
    for i, (x, y) in enumerate(((60, 150), (100, 148), (200, 152), (230, 150), (80, 394), (200, 396))):
        sc.anim("grass_tuft", x, y, i % 4, 0.7)
    sc.particle(kind="leaf", amount=6, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.5), spread=20,
                speed=(8, 12), gravity=(0, 3), colour_fade=True, spin=True)
    sc.particle(kind="mote", amount=8, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -4), spread=180,
                speed=(2, 4), gravity=(0, 0), colour_fade=True)
    sc.modulate = (1.0, 0.95, 0.88)
    return sc


def scene_crow_forest() -> Scene:
    """1-5 烏鴉之林: dusk in a forest clearing; dark trees all round, warm last light, fireflies."""
    sc = Scene("forest_d")
    img = sc.img
    paint_ground(img, (0, 0, IMG_W, IMG_H), ("forest_d", "forest", "moss_d"), 51, scale=22, tufts=0.6)
    paint_ground(img, (AX0, AY0, AX1, AY1), ("forest", "leaf_d", "moss_d"), 52, scale=36, lo=0.3, hi=0.66,
                 tufts=0.25, sparkle=0.015, max_light=0.2, max_dark=0.16)
    arena_vignette(img, 24, 0.42)
    # fallen leaves
    rng = random.Random(53)
    for _ in range(90):
        x, y = rng.randrange(0, IMG_W), rng.randrange(0, IMG_H)
        if in_arena(x, y) and rng.random() < 0.6:
            continue
        img.set(x, y, rng.choice(["orange", "rose", "gold_d", "dusk"]))
        img.set(x + 1, y, rng.choice(["rose", "gold_d"]))
    paint_path(img, [(150, 384), (146, 440), (150, 530)], 12, 54, ramp=("brown", "gold_d", "dirt"))
    paint_path(img, [(160, 160), (150, 130), (140, 104)], 10, 55, ramp=("brown", "gold_d", "dirt"))
    arena_edge_shadow(img, 5)
    dusk_tree = ("night_d", "forest_d", "forest", "moss_d")
    # dense forest above the arena; sunset glow between the trunks at the very top
    sky = [("peach", 0), ("peach", 46), ("rose", 56), ("rose", 68), ("dusk", 80), ("plum", 92)]
    for y in range(0, 104):
        band = max(i for i, (_, y0) in enumerate(sky) if y >= y0)
        col = sky[band][0]
        nxt = sky[min(band + 1, len(sky) - 1)]
        for x in range(IMG_W):
            if band + 1 < len(sky) and y >= nxt[1] - 3 and (x + y) % 2 == 0:
                img.set(x, y, nxt[0])
            else:
                img.set(x, y, col)
    sun = (70, 52)
    for y in range(36, 70):
        for x in range(40, 100):
            d = math.hypot(x - sun[0], (y - sun[1]) * 1.2)
            if d < 9:
                img.set(x, y, "cream" if d < 7 else "yellow")
    for i, x in enumerate(range(-14, IMG_W, 15)):
        if 40 <= x <= 86 and i % 2:
            continue
        place(img, pine(500 + i, 46 + (i * 7) % 14, ("night_d", "forest_d", "forest"), "ink", rim="dusk"),
              x, 40 + (i * 5) % 12, shadow=None)
    for i, x in enumerate(range(-10, IMG_W, 22)):
        place(img, tree(520 + i, 30, dusk_tree, "ink", rim="rose", rim_side=-1.0), x, 84 + (i * 7) % 10,
              shadow=(1.0, 1))
    for i, x in enumerate((-8, 22, 228, 258, 284)):
        place(img, tree(540 + i, 30, dusk_tree, "ink", rim="peach"), x, 130 + (i * 9) % 14)
    sc.light_shafts = [(-10, 14, 0.07, (1.0, 0.75, 0.55)), (30, 22, 0.06, (1.0, 0.7, 0.6)),
                       (90, 12, 0.05, (1.0, 0.8, 0.6))]
    for x, y, s in ((60, 128, 1), (100, 136, 2), (190, 132, 3), (232, 136, 4)):
        place(img, bush(s, 16, 10, ("forest_d", "forest", "moss_d", "moss"), "night_d"), x, y)
    for k, (x, y) in enumerate(((78, 142), (214, 146), (48, 404), (230, 412))):
        place(img, stump(k), x, y)
    for k, (x, y) in enumerate(((92, 148), (96, 150), (226, 150), (40, 410), (240, 420), (250, 418))):
        img.blit(mushroom("red" if k % 3 else "orange"), x, y)
    for k, (x, y) in enumerate(((24, 160), (30, 250), (20, 330), (254, 190), (262, 280), (250, 360))):
        place(img, fern(k), x, y, shadow=None)
    hedge_row(sc, AY0, AX0 - 12, AX1 + 12, 56, ("forest_d", "forest", "moss_d", "moss"), "night_d")
    hedge_row(sc, AY1 + 14, AX0 - 12, AX1 + 12, 57, ("forest_d", "forest", "moss_d", "moss"), "night_d")
    side_hedges(sc, 58, ("night_d", "forest_d", "forest", "moss_d"), "ink")
    for i, x in enumerate(range(-12, IMG_W, 20)):
        place(img, tree(560 + i, 30, dusk_tree, "ink", rim="rose"), x, 430 + (i * 7) % 16)
    # eyes glinting in the dark woods (decoration)
    for k, (x, y) in enumerate(((36, 128), (252, 120), (12, 452), (270, 470))):
        sc.anim("eyes", x, y, k, 0.6 + k * 0.1)
    sc.particle(kind="firefly", amount=14, lifetime=5.0, rect=(-10, -40, 200, 400), velocity=(0, -1), spread=180,
                speed=(2, 6), gravity=(0, 0), blink=True)
    sc.particle(kind="leaf_dusk", amount=5, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.5), spread=20,
                speed=(6, 10), gravity=(0, 3), colour_fade=True, spin=True)
    sc.modulate = (0.96, 0.9, 0.96)
    return sc


def scene_bridge() -> Scene:
    """1-6 黑騎士之橋: a stormy night. Stone bridge platform over a dark river, torches, the castle gate."""
    sc = Scene("night")
    img = sc.img
    # river
    for y in range(IMG_H):
        for x in range(IMG_W):
            n = fbm(x, y * 2.2, 61, 30)
            col = "night" if n > 0.42 else "night_d"
            if n > 0.64 or (n > 0.61 and (x + y) % 2 == 0):
                col = "water_d"
            img.set(x, y, col)
    rng = random.Random(62)
    for _ in range(320):
        x, y = rng.randrange(IMG_W), rng.randrange(IMG_H)
        ln = rng.randrange(3, 9)
        col = rng.choice(["water_d", "water_d", "night", "water"])
        for k in range(ln):
            img.set(x + k, y + int(math.sin((x + k) / 5.0)), col)

    deck = (AX0, AY0, AX1, AY1)
    bridge_x0, bridge_x1 = 120, 184            # causeway from the gate, and down to the far bank

    def on_deck(x: int, y: int) -> bool:
        return (deck[0] <= x < deck[2] and deck[1] <= y < deck[3]) or (bridge_x0 <= x < bridge_x1 and 40 <= y < 470)

    # paving: flagstones of different sizes with bevelled edges and dark grout
    rng2 = random.Random(63)
    y = AY0 % 10 - 10
    while y < IMG_H:
        hgt = rng2.choice([9, 10, 10, 11])
        x = -rng2.randrange(0, 16)
        while x < IMG_W:
            wid = rng2.randrange(11, 22)
            tone = rng2.choice(["stone_l", "stone_l", "stone_l", "stone"])
            for yy in range(y, y + hgt):
                for xx in range(x, x + wid):
                    if not on_deck(xx, yy):
                        continue
                    if yy == y + hgt - 1 or xx == x + wid - 1:
                        col = "stone_d"
                    elif yy == y or xx == x:
                        col = LIGHTER[tone] if tone == "stone" else ("white" if hash01(xx, yy, 66) > 0.8 else tone)
                    elif yy == y + hgt - 2 or xx == x + wid - 2:
                        col = DARKER[tone] if bayer(xx, yy) < 0.5 else tone
                    else:
                        col = tone
                        if bayer(xx, yy) < 0.12 and hash01(xx // 3, yy // 3, 67) > 0.5:
                            col = DARKER[tone]
                    img.set(xx, yy, col)
            if rng2.random() < 0.18:
                cx0 = x + rng2.randrange(2, max(3, wid - 3))
                img.line(cx0, y + 1, cx0 + rng2.randrange(-3, 4), y + hgt - 3, "stone_d")
            x += wid
        y += hgt
    # an engraved duelling circle in the middle of the platform (faint violet runes)
    ecx, ecy = (AX0 + AX1) / 2, (AY0 + AY1) / 2 + 8
    for yy in range(int(ecy - 60), int(ecy + 60)):
        for xx in range(int(ecx - 60), int(ecx + 60)):
            d = math.hypot(xx + 0.5 - ecx, (yy + 0.5 - ecy) * 1.15)
            if 52 <= d < 54 or 44 <= d < 45:
                shade(img, xx, yy, -1)
            elif 45 <= d < 52:
                ang = math.atan2(yy - ecy, xx - ecx)
                k = int((ang + math.pi) / (2 * math.pi) * 24)
                local = (ang + math.pi) / (2 * math.pi) * 24 - k
                if 0.35 < local < 0.65 and 47 <= d < 50:
                    img.set(xx, yy, "dusk" if k % 2 else "stone_d")
    for k in range(4):
        ang = k * math.pi / 2 + math.pi / 4
        for r in range(8, 40):
            xx = int(ecx + math.cos(ang) * r)
            yy = int(ecy + math.sin(ang) * r / 1.15)
            if r % 6 < 4:
                shade(img, xx, yy, -1)
    # wet puddles reflecting the sky
    for (cx, cy, rx, ry) in ((96, 214, 10, 3), (214, 312, 12, 4), (120, 360, 8, 3), (222, 200, 7, 3)):
        for yy in range(int(cy - ry), int(cy + ry) + 1):
            for xx in range(int(cx - rx), int(cx + rx) + 1):
                if ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1:
                    img.set(xx, yy, "steel" if (xx * 3 + yy) % 7 else "steel_l")
        img.hline(int(cx - rx + 2), int(cx - 2), int(cy - 1), "white")
        sc.anim("night_glint", int(cx - 2), int(cy - 1), int(cx) % 6, 1.0)
    # moss in a few joints
    for _ in range(60):
        xx, yy = rng.randrange(AX0, AX1), rng.randrange(AY0, AY1)
        if name_at(img, xx, yy) == "stone_d" and (xx < AX0 + 20 or xx > AX1 - 20 or yy > AY1 - 20):
            img.set(xx, yy, "moss_d")
    # parapets around the platform and the causeway
    def parapet_h(x0: int, x1: int, y: int) -> None:
        for x in range(x0, x1):
            for yy in range(y, y + 10):
                col = "stone" if yy < y + 3 else ("stone_d" if yy < y + 8 else "iron")
                if yy == y:
                    col = "stone_l"
                if (x % 12) == 0 and y + 3 <= yy < y + 8:
                    col = "iron"
                img.set(x, yy, col)
        img.hline(x0, x1 - 1, y - 1, "ink")
        img.hline(x0, x1 - 1, y + 10, "ink")

    def parapet_v(x: int, y0: int, y1: int) -> None:
        for y in range(y0, y1):
            for xx in range(x, x + 8):
                col = "stone_l" if xx < x + 3 else ("stone" if xx < x + 6 else "stone_d")
                if (y % 12) == 0:
                    col = "stone_d"
                img.set(xx, y, col)
            img.set(x - 1, y, "ink")
            img.set(x + 8, y, "ink")

    parapet_h(AX0 - 8, bridge_x0, AY0 - 10)
    parapet_h(bridge_x1, AX1 + 8, AY0 - 10)
    parapet_h(AX0 - 8, bridge_x0, AY1)
    parapet_h(bridge_x1, AX1 + 8, AY1)
    parapet_v(AX0 - 8, AY0 - 10, AY1 + 10)
    parapet_v(AX1, AY0 - 10, AY1 + 10)
    parapet_v(bridge_x0 - 8, 40, AY0 - 10)
    parapet_v(bridge_x1, 40, AY0 - 10)
    parapet_v(bridge_x0 - 8, AY1 + 10, 470)
    parapet_v(bridge_x1, AY1 + 10, 470)
    # shadow under the parapets on the deck
    for x in range(AX0, AX1):
        shade(img, x, AY0, -1)
        if x % 2 == 0:
            shade(img, x, AY0 + 1, -1)
    # torches: warm light pools on the deck
    torches = [(AX0 - 6, AY0 - 20), (AX1 + 1, AY0 - 20), (AX0 - 6, AY1 - 2), (AX1 + 1, AY1 - 2),
               (AX0 - 6, (AY0 + AY1) // 2 - 10), (AX1 + 1, (AY0 + AY1) // 2 - 10)]
    for (tx, ty) in torches:
        cx, cy = tx + 3, ty + 14
        for y in range(int(cy - 26), int(cy + 26)):
            for x in range(int(cx - 30), int(cx + 30)):
                d = math.hypot((x - cx) / 30, (y - cy) / 24)
                if d < 1 and on_deck(x, y):
                    if d < 0.55 or (d < 0.75 and (x + y) % 2 == 0):
                        n = name_at(img, x, y)
                        if n in ("stone_l", "stone", "stone_d", "steel_l", "steel"):
                            img.set(x, y, {"stone_l": "cream", "stone": "stone_l", "stone_d": "dirt",
                                           "steel_l": "white", "steel": "stone_l"}[n])
        sc.anim("torch", tx, ty, (tx + ty) % 4, 0.9 + (tx % 3) * 0.1)
    # castle wall and gate at the top; banners
    # night sky with a few stars above the castle
    for y in range(0, 80):
        for x in range(IMG_W):
            img.set(x, y, "night_d" if y < 60 or (x + y) % 2 else "night")
    for _ in range(40):
        img.set(rng.randrange(IMG_W), rng.randrange(0, 60), rng.choice(["steel", "steel_l", "night"]))
    gate = castle_gate()
    img.blit(gate, 0, 150 - gate.h)
    for x in (122, 170):
        sc.anim("banner", x, 150 - gate.h + 32, (x // 10) % 4, 1.0)
    for x in (122, 176):
        sc.anim("torch", x - 9 if x < 150 else x + 2, 150 - 26, x % 4, 1.0)
    # far bank at the bottom: dark grass, reeds
    for y in range(470, IMG_H):
        for x in range(IMG_W):
            if y > 470 + 3 * math.sin(x / 13.0):
                n = fbm(x, y, 65, 14)
                img.set(x, y, "forest_d" if n < 0.5 else "forest")
    for x in range(bridge_x0, bridge_x1):
        for y in range(466, IMG_H):
            img.set(x, y, "stone" if (x + y // 8 * 6) % 12 else "stone_d")
    for x in range(IMG_W):
        if not (bridge_x0 <= x < bridge_x1):
            for y in range(468, 474):
                if y > 470 + 3 * math.sin(x / 13.0) - 1 and name_at(img, x, y) in ("forest_d", "forest"):
                    img.set(x, y, "night_d")
                    break
    for i, x in enumerate((-10, 30, 220, 262)):
        place(img, tree(600 + i, 28, ("night_d", "forest_d", "forest", "leaf_d"), "ink"), x, 474 + (i * 5) % 8)
    # river glints
    for k in range(18):
        x, y = rng.randrange(0, IMG_W - 6), rng.randrange(40, 470)
        if not on_deck(x, y) and not on_deck(x + 6, y) and not (AX0 - 10 <= x <= AX1 + 10 and AY0 - 12 <= y <= AY1 + 12):
            sc.anim("night_glint", x, y, k % 6, 0.7 + (k % 3) * 0.2)
    sc.particle(kind="rain", amount=70, lifetime=0.45, rect=(-20, -80, 230, 400), velocity=(-0.25, 1), spread=2,
                speed=(260, 300), gravity=(0, 0), colour_fade=False, rain=True)
    sc.particle(kind="ripple", amount=16, lifetime=0.35, rect=(0, 72, 180, 224), velocity=(0, 0), spread=0,
                speed=(0, 0), gravity=(0, 0), colour_fade=True, grow=True)
    sc.modulate = (0.84, 0.88, 1.0)
    sc.lightning = True
    return sc


SCENES = {
    "sword_stone": scene_sword_stone,
    "wheat_field": scene_wheat_field,
    "meadow": scene_meadow,
    "farm_fence": scene_farm_fence,
    "crow_forest": scene_crow_forest,
    "bridge": scene_bridge,
}
BACKGROUNDS = SCENES     # name kept for build_all and tests


# --------------------------------------------------------------------------
# Tiles (C6): the 16x16 building blocks, exported as one atlas for reference and reuse
# --------------------------------------------------------------------------

def tile_set() -> dict[str, Canvas]:
    tiles: dict[str, Canvas] = {}
    ramps = {
        "grass": GREEN, "farm": ("moss_d", "moss", "leaf_l"), "forest": ("leaf_d", "moss_d", "moss"),
        "wheat": ("gold_d", "gold", "gold_l"),
    }
    for i, (name, ramp) in enumerate(ramps.items()):
        for k in range(2):
            c = Canvas(T, T, rgba(ramp[1]))
            paint_ground(c, (0, 0, T, T), ramp, 700 + i * 2 + k, scale=8, tufts=0.6)
            tiles["%s_%d" % (name, k)] = c
    c = Canvas(T, T, rgba("leaf"))
    paint_path(c, [(-2, 8), (18, 8)], 10, 710)
    tiles["path"] = c
    for k in range(2):
        c = Canvas(T, T, rgba("stone_l"))
        for y in range(T):
            for x in range(T):
                off = (y // 8 % 2) * 6
                if y % 8 == 7 or (x + off) % 12 == 11:
                    c.set(x, y, "stone_d")
                elif hash01((x + off) // 12, y // 8, 720 + k) < 0.35:
                    c.set(x, y, "stone")
        tiles["stone_%d" % k] = c
    c = Canvas(T, T, rgba("night"))
    for y in range(T):
        for x in range(T):
            if fbm(x, y * 2, 730, 8) > 0.55:
                c.set(x, y, "water_d")
    tiles["river"] = c
    tiles["hedge"] = hedge_strip(T, 740)
    f = Canvas(T, T)
    f.blit(fence_strip(T), 0, 2)
    tiles["fence"] = f
    w = Canvas(T, T)
    w.blit(wheat_clump(1), 0, 0)
    w.blit(wheat_clump(2), 7, 1)
    tiles["wheat"] = w
    return tiles


# --------------------------------------------------------------------------
# Kept for art_brand (title screen, store graphics)
# --------------------------------------------------------------------------

def prop(grid_or_canvas, outline: bool = True) -> Canvas:
    if isinstance(grid_or_canvas, Canvas):
        return grid_or_canvas
    grid = grid_or_canvas
    w = max(len(r) for r in grid) + 2
    h = len(grid) + 2
    c = Canvas(w, h)
    c.stamp(grid, 1, 1, L, outline="ink" if outline else None)
    return c


SWORD_STONE = sword_in_stone()
TREE = tree(7, 26)
BUSH = bush(3, 14, 9, TREE_GREEN, flowers=["white", "pink"])


# --------------------------------------------------------------------------
# .tscn output
# --------------------------------------------------------------------------

def _particle_node(i: int, p: dict, tex_id: str) -> list[str]:
    kind = p["kind"]
    x0, y0, x1, y1 = p["rect"]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    lines = [
        "",
        '[node name="%s_%d" type="CPUParticles2D" parent="Ambient"]' % (kind, i),
        "position = Vector2(%g, %g)" % (cx, cy),
        "amount = %d" % p["amount"],
        "lifetime = %g" % p["lifetime"],
        "preprocess = %g" % p["lifetime"],
        "randomness = 0.5",
        "texture = ExtResource(\"%s\")" % tex_id,
        "emission_shape = 3",
        "emission_rect_extents = Vector2(%g, %g)" % ((x1 - x0) / 2, (y1 - y0) / 2),
        "direction = Vector2(%g, %g)" % p["velocity"],
        "spread = %g" % p["spread"],
        "gravity = Vector2(%g, %g)" % p["gravity"],
        "initial_velocity_min = %g" % p["speed"][0],
        "initial_velocity_max = %g" % p["speed"][1],
    ]
    if p.get("spin"):
        lines += ["angular_velocity_min = -90.0", "angular_velocity_max = 90.0",
                  "angle_min = -180.0", "angle_max = 180.0"]
    if p.get("rain"):
        lines += ["angle_min = 14.0", "angle_max = 14.0"]
    if p.get("grow"):
        lines += ["scale_amount_min = 1.0", "scale_amount_max = 2.0",
                  'scale_amount_curve = SubResource("Curve_grow")']
    if p.get("blink"):
        lines.append('color_ramp = SubResource("Gradient_blink")')
    elif p.get("colour_fade"):
        lines.append('color_ramp = SubResource("Gradient_fade")')
    return lines


LIGHTNING_SCRIPT = "res://assets/backgrounds/lightning.gd"


def background_tscn(name: str, sc: Scene) -> str:
    ext = ['[ext_resource type="Texture2D" path="res://assets/backgrounds/%s.png" id="1_bg"]' % name]
    used = sorted({a[0] for a in sc.anims})
    anim_ids = {}
    for i, kind in enumerate(used):
        anim_ids[kind] = "%d_anim_%s" % (i + 2, kind)
        ext.append('[ext_resource type="SpriteFrames" path="res://assets/backgrounds/anim/%s_frames.tres" id="%s"]'
                   % (kind, anim_ids[kind]))
    ptex = sorted({p["kind"] for p in sc.particles})
    ptex_ids = {}
    for i, kind in enumerate(ptex):
        ptex_ids[kind] = "%d_p_%s" % (i + 2 + len(used), kind)
        ext.append('[ext_resource type="Texture2D" path="res://assets/backgrounds/anim/p_%s.png" id="%s"]'
                   % (kind, ptex_ids[kind]))
    if sc.lightning:
        ext.append('[ext_resource type="Script" path="%s" id="90_lightning"]' % LIGHTNING_SCRIPT)
    subs = []
    if any(p.get("colour_fade") for p in sc.particles):
        subs += ["", '[sub_resource type="Gradient" id="Gradient_fade"]',
                 "offsets = PackedFloat32Array(0, 0.15, 0.8, 1)",
                 "colors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0)"]
    if any(p.get("blink") for p in sc.particles):
        subs += ["", '[sub_resource type="Gradient" id="Gradient_blink"]',
                 "offsets = PackedFloat32Array(0, 0.2, 0.35, 0.5, 0.65, 0.8, 1)",
                 "colors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0.2, 1, 1, 1, 1, 1, 1, 1, 0.3, 1, 1, 1, 1, 1, 1, 1, 0)"]
    if any(p.get("grow") for p in sc.particles):
        subs += ["", '[sub_resource type="Curve" id="Curve_grow"]',
                 "_data = [Vector2(0, 0.5), 0.0, 0.0, 0, 0, Vector2(1, 1), 0.0, 0.0, 0, 0]",
                 "point_count = 2"]
    lines = ['[gd_scene format=3]', ""] + ext + subs + [
        "",
        '[node name="Background" type="Node2D"]',
        "",
        '[node name="Image" type="Sprite2D" parent="."]',
        'texture = ExtResource("1_bg")',
        "centered = false",
        "position = Vector2(%d, %d)" % ORIGIN,
    ]
    if sc.lightning:
        lines += ["", '[node name="Lightning" type="Node2D" parent="."]', 'script = ExtResource("90_lightning")']
    if sc.anims:
        lines += ["", '[node name="Anim" type="Node2D" parent="."]']
        for i, (kind, ix, iy, frame, speed, flip) in enumerate(sc.anims):
            lines += ["", '[node name="%s_%d" type="AnimatedSprite2D" parent="Anim"]' % (kind, i),
                      "position = Vector2(%d, %d)" % (ix + ORIGIN[0], iy + ORIGIN[1]),
                      'sprite_frames = ExtResource("%s")' % anim_ids[kind],
                      'autoplay = "default"',
                      "frame = %d" % frame,
                      "speed_scale = %g" % speed,
                      "centered = false"]
            if flip:
                lines.append("flip_h = true")
    if sc.particles:
        lines += ["", '[node name="Ambient" type="Node2D" parent="."]']
        for i, p in enumerate(sc.particles):
            lines += _particle_node(i, p, ptex_ids[p["kind"]])
    if sc.light_shafts:
        lines += ["", '[node name="Light" type="Node2D" parent="."]']
        for i, shaft in enumerate(sc.light_shafts):
            x, w, a = shaft[:3]
            r, g, b = shaft[3] if len(shaft) > 3 else (1.0, 0.97, 0.82)
            run = 300
            lines += ["", '[node name="Shaft_%d" type="Polygon2D" parent="Light"]' % i,
                      "color = Color(%g, %g, %g, %g)" % (r, g, b, a),
                      "polygon = PackedVector2Array(%g, -90, %g, -90, %g, 430, %g, 430)"
                      % (x, x + w, x + w + run, x + run)]
    if sc.modulate is not None:
        lines += ["", '[node name="Mood" type="CanvasModulate" parent="."]',
                  "color = Color(%g, %g, %g, 1)" % sc.modulate]
    lines.append("")
    return "\n".join(lines)


def write_all(preview_dir: str | None = None) -> dict[str, Canvas]:
    tiles = tile_set()
    atlas = Canvas(8 * T, ((len(tiles) + 7) // 8) * T)
    for i, img in enumerate(tiles.values()):
        atlas.blit(img, (i % 8) * T, (i // 8) * T)
    atlas.save(res_path("res://assets/tiles/chapter1_tiles.png"))
    for kind, (fn, size) in ANIMS.items():
        build_sheet("res://assets/backgrounds/anim", kind, fn(), size)
    for kind, tex in particle_textures().items():
        tex.save(res_path("res://assets/backgrounds/anim/p_%s.png" % kind))
    out = {}
    for name, fn in SCENES.items():
        sc = fn()
        sc.img.save(res_path("res://assets/backgrounds/%s.png" % name))
        write_text(res_path("res://assets/backgrounds/%s.tscn" % name), background_tscn(name, sc))
        out[name] = sc.img
    return out
