"""Painting helpers for the v2.3 story art (portraits, storybook illustrations, new cast).

Everything works on pixel.Canvas with palette colour names. The look:
- ordered (Bayer 4x4) dithering only in a narrow band between two ramp colours, so flat
  areas stay clean and transitions read as soft storybook gradients;
- shapes are point sets (`Shape`), shaded like small spheres lit from the top-left;
- the figure is painted on its own layer and outlined once (selective dark edges inside).
"""

from __future__ import annotations

import math
import random

from palette import PALETTE, rgba
from pixel import Canvas

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
NAME_BY_RGB = {rgba(n)[:3]: n for n, _ in PALETTE}
LIGHT = (-0.52, -0.62, 0.59)

Shape = set   # set of (x, y)


def bayer(x: int, y: int) -> float:
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def pick(ramp: list[str] | tuple[str, ...], t: float, x: int, y: int, sharp: float = 2.4) -> str:
    """t in [0, 1] -> a ramp colour; between two steps an ordered dither whose width shrinks with `sharp`."""
    t = min(1.0, max(0.0, t))
    f = t * (len(ramp) - 1)
    i = int(f)
    if i >= len(ramp) - 1:
        return ramp[-1]
    frac = f - i
    frac = min(1.0, max(0.0, (frac - 0.5) * sharp + 0.5))
    return ramp[i + 1] if frac > bayer(x, y) else ramp[i]


def name_at(c: Canvas, x: int, y: int) -> str | None:
    p = c.get(x, y)
    if p is None or p[3] == 0:
        return None
    return NAME_BY_RGB.get(p[:3])


# --------------------------------------------------------------------------
# shapes
# --------------------------------------------------------------------------

def ellipse(cx: float, cy: float, rx: float, ry: float) -> Shape:
    pts = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                pts.add((x, y))
    return pts


def poly(points: list[tuple[float, float]]) -> Shape:
    """Scanline fill of a polygon (pixel centres)."""
    pts = set()
    ys = [p[1] for p in points]
    n = len(points)
    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        yc = y + 0.5
        xs = []
        for i in range(n):
            x0, y0 = points[i]
            x1, y1 = points[(i + 1) % n]
            if (y0 <= yc < y1) or (y1 <= yc < y0):
                xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
        xs.sort()
        for k in range(0, len(xs) - 1, 2):
            for x in range(int(math.ceil(xs[k] - 0.5)), int(math.floor(xs[k + 1] - 0.5)) + 1):
                pts.add((x, y))
    return pts


def rect(x: int, y: int, w: int, h: int) -> Shape:
    return {(xx, yy) for yy in range(y, y + h) for xx in range(x, x + w)}


def thick_line(x0: float, y0: float, x1: float, y1: float, r: float) -> Shape:
    pts = set()
    lo_x, hi_x = int(min(x0, x1) - r) - 1, int(max(x0, x1) + r) + 2
    lo_y, hi_y = int(min(y0, y1) - r) - 1, int(max(y0, y1) + r) + 2
    dx, dy = x1 - x0, y1 - y0
    ll = dx * dx + dy * dy or 1e-9
    for y in range(lo_y, hi_y):
        for x in range(lo_x, hi_x):
            px, py = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / ll))
            if math.hypot(px - (x0 + t * dx), py - (y0 + t * dy)) <= r:
                pts.add((x, y))
    return pts


def bbox(s: Shape) -> tuple[int, int, int, int]:
    xs = [p[0] for p in s]
    ys = [p[1] for p in s]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def edge(s: Shape, diagonal: bool = False) -> Shape:
    """Pixels of s that touch the outside."""
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        nb += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    return {(x, y) for (x, y) in s if any((x + dx, y + dy) not in s for dx, dy in nb)}


# --------------------------------------------------------------------------
# filling and shading
# --------------------------------------------------------------------------

def fill(c: Canvas, s: Shape, col: str) -> None:
    for (x, y) in s:
        c.set(x, y, col)


def shade_shape(c: Canvas, s: Shape, ramp, light=LIGHT, bias: float = 0.0, sharp: float = 2.4,
                bulge: float = 1.0, centre: tuple[float, float] | None = None,
                radius: tuple[float, float] | None = None) -> None:
    """Sphere-like shading of an arbitrary shape: the normal comes from the position inside the
    shape's bounding ellipse (or the given centre/radius)."""
    if not s:
        return
    x0, y0, x1, y1 = bbox(s)
    cx, cy = centre if centre else ((x0 + x1) / 2, (y0 + y1) / 2)
    rx, ry = radius if radius else (max(1.0, (x1 - x0) / 2), max(1.0, (y1 - y0) / 2))
    lx, ly, lz = light
    for (x, y) in s:
        nx = (x + 0.5 - cx) / rx
        ny = (y + 0.5 - cy) / ry
        nz = math.sqrt(max(0.0, 1.0 - min(1.0, nx * nx + ny * ny))) * bulge
        ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        d = (nx * lx + ny * ly + nz * lz) / ln
        t = d * 0.62 + 0.42 + bias
        c.set(x, y, pick(ramp, t, x, y, sharp))


def vgrad(c: Canvas, x0: int, y0: int, x1: int, y1: int, ramp, sharp: float = 1.6,
          t0: float = 0.0, t1: float = 1.0) -> None:
    """Vertical dithered gradient: ramp[0] at the top to ramp[-1] at the bottom."""
    h = max(1, y1 - y0 - 1)
    for y in range(y0, y1):
        t = t0 + (t1 - t0) * (y - y0) / h
        for x in range(x0, x1):
            c.set(x, y, pick(ramp, t, x, y, sharp))


def radial(c: Canvas, cx: float, cy: float, r: float, ramp, sharp: float = 1.6, rect_=None,
           squash: float = 1.0) -> None:
    """Radial dithered gradient: ramp[-1] at the centre to ramp[0] at radius r and beyond."""
    x0, y0, x1, y1 = rect_ or (0, 0, c.w, c.h)
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * squash) / r
            c.set(x, y, pick(ramp, 1.0 - d, x, y, sharp))


def darken(c: Canvas, x: int, y: int, steps: int = 1, ramps: dict | None = None) -> None:
    n = name_at(c, x, y)
    if n is None:
        return
    for _ in range(abs(steps)):
        n = (ramps or DARKER).get(n, n) if steps > 0 else LIGHTER.get(n, n)
    c.set(x, y, n)


# one step darker / lighter inside the palette (for painted shadows, rim light)
DARKER = {
    "white": "cream", "cream": "gold_l", "gold_l": "gold", "gold": "gold_d", "gold_d": "brown", "brown": "brown_d",
    "brown_d": "ink", "steel_l": "steel", "steel": "steel_d", "steel_d": "iron", "iron": "ink",
    "stone_l": "stone", "stone": "stone_d", "stone_d": "iron", "red": "red_d", "red_d": "plum", "pink": "rose",
    "rose": "red_d", "orange": "gold_d", "yellow": "gold_l", "leaf_l": "leaf", "leaf": "leaf_d",
    "leaf_d": "forest", "forest": "forest_d", "forest_d": "night_d", "sky_l": "sky", "sky": "water",
    "water": "water_d", "water_d": "night", "night": "night_d", "night_d": "ink", "lilac": "violet",
    "violet": "plum", "plum": "ink", "peach": "dirt", "dirt": "gold_d", "dusk": "plum", "moss": "moss_d",
    "moss_d": "forest",
}
LIGHTER = {
    "ink": "iron", "iron": "steel_d", "steel_d": "steel", "steel": "steel_l", "steel_l": "white",
    "brown_d": "brown", "brown": "gold_d", "gold_d": "gold", "gold": "gold_l", "gold_l": "cream",
    "cream": "white", "red_d": "red", "red": "pink", "plum": "violet", "violet": "lilac", "lilac": "white",
    "forest_d": "forest", "forest": "leaf_d", "leaf_d": "leaf", "leaf": "leaf_l", "night_d": "night",
    "night": "water_d", "water_d": "water", "water": "sky", "sky": "sky_l", "stone_d": "stone",
    "stone": "stone_l", "stone_l": "white", "dusk": "rose", "rose": "pink", "dirt": "peach", "moss_d": "moss",
    "moss": "leaf_l",
}


def outline_shape(c: Canvas, s: Shape, col: str = "ink", diagonal: bool = False) -> None:
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        nb += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    ring = set()
    for (x, y) in s:
        for dx, dy in nb:
            q = (x + dx, y + dy)
            if q not in s:
                ring.add(q)
    for (x, y) in ring:
        c.set(x, y, col)


def inner_line(c: Canvas, s: Shape, col: str, sides=("bottom", "right")) -> None:
    """A selective dark edge inside a shape on the given sides (separates overlapping parts)."""
    off = {"bottom": (0, 1), "top": (0, -1), "left": (-1, 0), "right": (1, 0)}
    for (x, y) in s:
        for side in sides:
            dx, dy = off[side]
            if (x + dx, y + dy) not in s:
                c.set(x, y, col)
                break


def rim(c: Canvas, s: Shape, col: str, side: tuple[int, int] = (-1, -1)) -> None:
    """Rim light: shape pixels whose neighbour toward `side` is outside get `col`."""
    dx, dy = side
    for (x, y) in s:
        if (dx and (x + dx, y) not in s) or (dy and (x, y + dy) not in s):
            c.set(x, y, col)


def stamp(c: Canvas, grid: list[str], ox: int, oy: int, legend: dict[str, str], flip: bool = False) -> None:
    """Draw a character grid without outline ('.' transparent, '_' erases)."""
    c.stamp(grid, ox, oy, legend, outline=None, flip=flip)


def layer_over(dst: Canvas, src: Canvas, ox: int = 0, oy: int = 0) -> None:
    dst.blit(src, ox, oy)


def scatter(rng: random.Random, n: int, x0: int, y0: int, x1: int, y1: int) -> list[tuple[int, int]]:
    return [(rng.randrange(x0, x1), rng.randrange(y0, y1)) for _ in range(n)]


def glow_dot(c: Canvas, x: int, y: int, core: str, halo: str, r: int = 1) -> None:
    """A small painted light: bright core and a softer cross/diamond halo."""
    for dy in range(-r - 1, r + 2):
        for dx in range(-r - 1, r + 2):
            d = abs(dx) + abs(dy)
            if d <= r:
                c.set(x + dx, y + dy, core)
            elif d == r + 1:
                c.set(x + dx, y + dy, halo)


def star4(c: Canvas, x: int, y: int, col: str, arm: int = 2, centre: str | None = None) -> None:
    for k in range(-arm, arm + 1):
        c.set(x + k, y, col)
        c.set(x, y + k, col)
    if centre:
        c.set(x, y, centre)


def alpha_px(name: str, a: int) -> tuple[int, int, int, int]:
    r, g, b, _ = rgba(name)
    return (r, g, b, a)
