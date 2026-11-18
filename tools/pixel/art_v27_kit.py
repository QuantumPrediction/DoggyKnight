"""v2.7 (C 世界, CW7) scenery kit for chapters 4-6: sea, underwater, snow, fire and autumn dusk.
Python 3 standard library only.

Builds on art_v26_kit (Scene26, sky bands, peaks, masonry, flagstones...) and the v2.6 crafted
floors of art_v26_world (textured_floor, blades, pebbles: large soft value shifts that calm down
towards the middle of the arena, material strokes at the edges, props framing the clearing).

New here:
- painters: sea surfaces with tidy wave crests, shorelines, cliffs, underwater water columns,
  snow fields and drifts, lava rivers, nests, autumn ground;
- props: palms, boats, corals, kelp, ruins, snowy pines, hot-spring pools, tents, pillars,
  apple trees in blossom, gates...;
- animated layers (assets/backgrounds/anim/<kind>_frames.tres) and particle textures (p_<kind>.png).
"""

from __future__ import annotations

import math
import random

import art_light as AL
import art_world as AW
import art_v26_kit as K
import art_v26_world as W
import paint as P
from art_world import AX0, AX1, AY0, AY1, IMG_H, IMG_W, fbm, hash01, in_arena, name_at, shade
from art_v26_kit import Scene26, dk, lt
from pixel import Anim, Canvas, build_sheet, res_path

MIDX = (AX0 + AX1) // 2     # 152
MIDY = (AY0 + AY1) // 2     # 272

__all__ = ["Scene26", "dk", "lt", "MIDX", "MIDY"]


# --------------------------------------------------------------------------
# generic
# --------------------------------------------------------------------------

def fill_rect(img: Canvas, rect: tuple[int, int, int, int], col: str, mask=None) -> None:
    x0, y0, x1, y1 = rect
    for y in range(max(0, y0), min(img.h, y1)):
        for x in range(max(0, x0), min(img.w, x1)):
            if mask is None or mask(x, y):
                img.set(x, y, col)


def recolor(img: Canvas, rect: tuple[int, int, int, int], table: dict[str, str], mask=None) -> None:
    x0, y0, x1, y1 = rect
    for y in range(max(0, y0), min(img.h, y1)):
        for x in range(max(0, x0), min(img.w, x1)):
            if mask is not None and not mask(x, y):
                continue
            n = name_at(img, x, y)
            if n in table:
                img.set(x, y, table[n])


def scatter_props(img: Canvas, rect: tuple[int, int, int, int], n: int, seed: int, make, calm: float = 0.9,
                  shadow=None, keep_out=None) -> None:
    """Place n small props (make(rng) -> Canvas) in rect, fewer towards the arena middle."""
    rng = random.Random(seed)
    x0, y0, x1, y1 = rect
    for _ in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        if rng.random() < W.calm_k(x, y) * calm:
            continue
        if keep_out is not None and keep_out(x, y):
            continue
        prop = make(rng)
        if shadow:
            AW.place(img, prop, x, y, shadow=shadow, shadow_dx=1)
        else:
            img.blit(prop, x, y)


def soft_disc(img: Canvas, cx: float, cy: float, rx: float, ry: float, col: str, seed: int = 0,
              wobble: float = 0.18, only=None) -> None:
    """A filled organic ellipse (wobbly clustered edge) of one colour."""
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            d += (fbm(x, y, seed, 6, 2) - 0.5) * wobble + AW._cluster(x, y, seed) * 0.05
            if d < 1.0 and (only is None or name_at(img, x, y) in only):
                img.set(x, y, col)


def shaded_blob(w: int, h: int, blobs, ramp, outline: str | None, seed: int, texture: float = 0.12) -> Canvas:
    return AW.blob_canvas(w, h, blobs, list(ramp), outline, seed, texture=texture)


def edge_line(img: Canvas, x0: int, x1: int, y_of, col: str, thick: int = 1) -> None:
    for x in range(x0, x1):
        y = int(y_of(x))
        for t in range(thick):
            img.set(x, y + t, col)


def voronoi_stones(img: Canvas, rect: tuple[int, int, int, int], cell: float, tones: tuple[str, ...], grout: str,
                   seed: int, lip: str | None = None, shade_col: str | None = None, mask=None, squash: float = 1.0,
                   jitter: float = 0.8, tone_of=None) -> None:
    """Irregular stones (crazy paving, cobbles, cracked ice, basalt): each pixel belongs to the nearest
    jittered seed point; a 1 px grout where two stones meet (only on the stone's lower/right side, so the
    light reads from the top-left); optional lit top edge (lip) and shaded lower edge per stone."""
    x0, y0, x1, y1 = rect

    def seed_pt(ix: int, iy: int) -> tuple[float, float]:
        return ((ix + 0.5 + (hash01(ix, iy, seed) - 0.5) * jitter) * cell,
                (iy + 0.5 + (hash01(ix, iy, seed + 7) - 0.5) * jitter) * cell * squash)

    cache: dict[tuple[int, int], tuple[float, float]] = {}

    def owner(x: float, y: float) -> tuple[tuple[int, int], float, float]:
        cx, cy = int(x // cell), int(y // (cell * squash))
        best, second, who = 1e9, 1e9, (0, 0)
        for iy in range(cy - 1, cy + 2):
            for ix in range(cx - 1, cx + 2):
                p = cache.get((ix, iy))
                if p is None:
                    p = cache[(ix, iy)] = seed_pt(ix, iy)
                d = (x - p[0]) ** 2 + ((y - p[1]) / squash) ** 2
                if d < best:
                    second, best, who = best, d, (ix, iy)
                elif d < second:
                    second = d
        return who, math.sqrt(best), math.sqrt(second)

    for y in range(max(0, y0), min(img.h, y1)):
        for x in range(max(0, x0), min(img.w, x1)):
            if mask is not None and not mask(x, y):
                continue
            who, d1, d2 = owner(x + 0.5, y + 0.5)
            if d2 - d1 < 1.1:
                img.set(x, y, grout)
                continue
            tone = tone_of(who) if tone_of else tones[int(hash01(who[0], who[1], seed + 3) * len(tones)) % len(tones)]
            col = tone
            if lip or shade_col:
                up, _, _ = owner(x + 0.5, y - 1.5)
                dn, _, _ = owner(x + 0.5, y + 2.5)
                if lip and up != who and hash01(who[0], who[1], seed + 5) < 0.6:
                    col = lip
                elif shade_col and dn != who:
                    col = shade_col
            img.set(x, y, col)


def sand_floor(img: Canvas, rect: tuple[int, int, int, int], seed: int, base: str = "sand", light: str = "cream",
               ripple: str = "dirt", mask=None, ripples: int = 160) -> None:
    """Sun-warm sand: one base tone with big soft sunlit patches (clustered edges, calm in the arena)
    and short wind-ripple arcs at the edges."""
    W.textured_floor(img, rect, (base, base, light), seed, scale=56, spread=0.16, mask=mask)
    rng = random.Random(seed + 11)
    x0, y0, x1, y1 = rect
    for _ in range(ripples):
        x, y = rng.randrange(x0, x1 - 6), rng.randrange(y0, y1)
        if rng.random() < W.calm_k(x, y) * 0.98 or (mask is not None and not mask(x, y)):
            continue
        b = name_at(img, x, y)
        if b not in (base, light):
            continue
        col = base if b == light else ripple
        ln = rng.randrange(3, 7)
        for k in range(ln):
            img.set(x + k, y + (1 if k in (0, ln - 1) else 0), col)


# --------------------------------------------------------------------------
# water: open sea, shorelines, underwater
# --------------------------------------------------------------------------

def sea(img: Canvas, rect: tuple[int, int, int, int], bands: list[tuple[str, float]], seed: int,
        crest: tuple[str, str] = ("white", "sky_l"), rows: int = 9, density: float = 0.5, mask=None,
        far_crest: str = "azure") -> None:
    """Open sea: wavy horizontal colour bands (W.water_bands) plus tidy wave crests in staggered rows
    whose size and spacing grow towards the viewer (perspective), never single-pixel noise."""
    x0, y0, x1, y1 = rect
    W.water_bands(img, rect, bands, seed, glints=(bands[-1][0],), n_glints=0, mask=mask)
    rng = random.Random(seed + 1)
    span = y1 - y0
    for r in range(rows):
        t = (r + 0.5) / rows
        y = int(y0 + span * (t ** 1.35))
        gap = int(10 + 30 * t)
        x = x0 - rng.randrange(0, gap)
        while x < x1:
            if rng.random() < density:
                ln = max(2, int(2 + 6 * t + rng.randrange(0, 3)))
                for k in range(ln):
                    xx = x + k
                    if mask is not None and not mask(xx, y):
                        continue
                    if t < 0.25:
                        img.set(xx, y, far_crest)
                    else:
                        img.set(xx, y, crest[0] if 0 < k < ln - 1 else crest[1])
                        if t > 0.55 and 0 < k < ln - 1:
                            b = name_at(img, xx, y + 1)
                            if b:
                                img.set(xx, y + 1, dk(b))
            x += gap + rng.randrange(-gap // 3, gap // 3 + 1)


def glitter_path(img: Canvas, cx: float, y0: int, y1: int, seed: int, cols=("white", "gold_l"), spread: float = 0.35,
                 rows_step: int = 2, mask=None) -> None:
    """The sun's (or moon's) path of light on water: short horizontal glints in a widening cone."""
    rng = random.Random(seed)
    for y in range(y0, y1, rows_step):
        half = 3 + (y - y0) * spread
        for _ in range(2 + int((y - y0) * 0.05)):
            x = int(cx + rng.uniform(-half, half))
            ln = rng.randrange(2, 6)
            for k in range(ln):
                if mask is None or mask(x + k, y):
                    img.set(x + k, y, cols[0] if k % 3 else cols[1])


def shoreline(img: Canvas, x0: int, x1: int, y_of, seed: int, wet: str = "dirt", foam=("white", "sky_l"),
              shallow: str = "azure", wet_depth: int = 5) -> None:
    """Where the sea meets the sand: a turquoise shallow film, a bright foam line with little foam
    bubbles, then a band of darker wet sand (soft lower edge)."""
    rng = random.Random(seed)
    for x in range(x0, x1):
        y = int(y_of(x))
        for k in range(1, 4):
            if name_at(img, x, y - k) is not None:
                img.set(x, y - k, shallow)
        img.set(x, y, foam[0])
        img.set(x, y - 1, foam[1] if (x // 3) % 3 else foam[0])
        d = wet_depth + (1 if AW._cluster(x, y, seed) > 0.15 else 0) + int(2 * math.sin(x / 11.0 + seed))
        for k in range(1, max(2, d)):
            img.set(x, y + k, wet)
    for _ in range((x1 - x0) // 6):
        x = rng.randrange(x0, x1)
        y = int(y_of(x)) - rng.randrange(2, 5)
        img.set(x, y, foam[0])
        img.set(x + 1, y, foam[1])


def water_column(img: Canvas, rect: tuple[int, int, int, int], bands: list[tuple[str, float]], seed: int) -> None:
    """Underwater 'sky': soft horizontal bands from the bright surface down into the blue."""
    K.sky_bands(img, rect[1], rect[3], bands, wave=2.4, seed=seed, x0=rect[0], x1=rect[2])


def surface_ripples(img: Canvas, y: int, seed: int, cols=("white", "sky_l", "azure")) -> None:
    """The wavy underside of the sea surface seen from below (top of an underwater scene)."""
    for x in range(IMG_W):
        yy = y + int(2.2 * math.sin(x / 9.0 + seed) + 1.2 * math.sin(x / 3.7 + seed * 2))
        for k in range(0, yy + 1):
            pass
        img.set(x, yy, cols[0])
        img.set(x, yy + 1, cols[1])
        if (x // 5) % 2:
            img.set(x, yy + 2, cols[2])


# --------------------------------------------------------------------------
# beach and coast props
# --------------------------------------------------------------------------

def shell(rng: random.Random) -> Canvas:
    c = Canvas(4, 3)
    col = rng.choice((("cream", "pink"), ("white", "peach"), ("sand", "coral"), ("cream", "lilac")))
    c.stamp(["ab", "bb"], 1, 0, {"a": col[0], "b": col[1]}, outline=None)
    c.set(0, 1, col[0])
    c.set(3, 1, col[1])
    c.hline(0, 3, 2, "dirt")
    return c


def starfish(rng: random.Random) -> Canvas:
    c = Canvas(5, 5)
    col = rng.choice((("orange", "coral"), ("coral", "red"), ("pink", "rose")))
    for (x, y) in ((2, 0), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (1, 3), (3, 3), (0, 4), (4, 4)):
        c.set(x, y, col[0])
    c.set(2, 2, col[1])
    c.set(1, 3, col[1])
    c.set(3, 3, col[1])
    return c


def pebble_prop(rng: random.Random, ramp=("stone_d", "stone", "stone_l")) -> Canvas:
    c = Canvas(4, 3)
    c.hline(1, 2, 0, ramp[2])
    c.hline(0, 3, 1, ramp[1])
    c.hline(1, 3, 2, ramp[0])
    return c


def palm(seed: int, h: int = 54, lean: float = 0.25, flip: bool = False) -> Canvas:
    """A palm tree: a curved ringed trunk and a crown of long drooping fronds (lit top-left), coconuts."""
    rng = random.Random(seed)
    w = 64
    c = Canvas(w, h + 4)
    bx = 24
    pts = []
    for k in range(h - 12):
        t = k / (h - 12)
        x = bx + lean * 30 * (t ** 1.6)
        y = h + 2 - k
        pts.append((x, y))
        half = 2.4 - t * 0.9
        for xx in range(int(x - half), int(x + half) + 1):
            u = (xx - (x - half)) / (2 * half)
            col = "sand" if u < 0.3 else ("dirt" if u < 0.7 else "gold_d")
            if k % 4 == 0:
                col = "gold_d" if u < 0.7 else "brown"
            c.set(xx, y, col)
    tx, ty = pts[-1]
    # fronds: arcs drooping out from the crown
    for i in range(7):
        a = -math.pi * 0.95 + i * math.pi * 0.95 / 6 + rng.uniform(-0.08, 0.08)
        ln = rng.uniform(16, 22)
        for s in range(int(ln)):
            f = s / ln
            x = tx + math.cos(a) * s
            y = ty - 3 + math.sin(a) * s * 0.6 + (f ** 2) * 10
            lit = math.cos(a) < 0.2
            core = "leaf" if lit else "leaf_d"
            c.set(int(x), int(y), core)
            for side in (-1, 1):
                for j in range(1, int(4 * (1 - f) + 1)):
                    yy = int(y + j * (0.9 if side > 0 else -0.4) + j * 0.5)
                    c.set(int(x) + (side if s % 2 else 0), yy, ("leaf_d" if side > 0 else ("leaf_l" if lit else "leaf")))
    for (dx, dy) in ((-2, 1), (1, 2), (-1, 3)):
        c.set(int(tx) + dx, int(ty) + dy, "brown")
        c.set(int(tx) + dx + 1, int(ty) + dy, "brown_d")
    c.outline_all("forest_d")
    return c.flipped() if flip else c


def rowboat(w: int = 30, cols=("brown_d", "brown", "gold_d"), stripe: str | None = "water") -> Canvas:
    c = Canvas(w + 2, 14)
    for y in range(3, 12):
        k = (y - 3) / 9
        inset = int(k * k * 6)
        for x in range(1 + inset, w + 1 - inset):
            col = cols[1] if y > 5 else cols[2]
            if y in (4, 5):
                col = cols[0]
            if stripe and y == 7:
                col = stripe
            c.set(x, y, col)
    for x in range(3, w - 1):
        c.set(x, 3, cols[2])
    c.hline(4, w - 3, 4, "umber")
    c.rect(w // 2 - 3, 4, 6, 1, cols[1])
    c.outline_all("umber")
    return c


def net_post(h: int = 26) -> Canvas:
    """Two posts with a drying fishing net sagging between them."""
    c = Canvas(30, h + 2)
    for x in (2, 26):
        c.vline(x, 2, h, "brown")
        c.vline(x + 1, 2, h, "brown_d")
        c.set(x, 2, "gold_d")
    for k in range(5):
        y0 = 5 + k * 3
        for x in range(4, 26):
            sag = int(3 * math.sin((x - 4) / 22 * math.pi))
            if (x + k) % 3 == 0:
                c.set(x, y0 + sag, "sand")
        for x in range(4, 26, 3):
            for y in range(5, 5 + 13):
                if (y + x) % 4 == 0:
                    c.set(x, y + int(3 * math.sin((x - 4) / 22 * math.pi)), "dirt")
    c.outline_all("umber")
    return c


def rope_coil() -> Canvas:
    c = Canvas(10, 7)
    for (x, y) in P.ellipse(5, 3.5, 4.5, 3):
        d = math.hypot(x + 0.5 - 5, (y + 0.5 - 3.5) * 1.5)
        c.set(x, y, "sand" if int(d) % 2 else "dirt")
    c.set(5, 3, "gold_d")
    c.outline_all("brown_d")
    return c


def cliff_band(img: Canvas, x0: int, x1: int, top_of, y1: int, ramp: tuple[str, str, str, str], seed: int,
               strata: int = 7, grass=("leaf_d", "leaf", "leaf_l"), lit_side: str = "left") -> None:
    """A vertical cliff face: wide vertical light bands (soft, wandering edges), horizontal strata cracks
    every few rows (broken, not stripes), a grassy lip on top with a few hanging tufts."""
    rng = random.Random(seed)
    for x in range(x0, x1):
        top = int(top_of(x))
        for y in range(top, y1):
            u = fbm(x * 0.6, y * 0.12, seed, 10, 2)
            col = ramp[2] if u > 0.6 else (ramp[1] if u > 0.38 else ramp[0])
            if (y - top) % strata == strata - 1 and fbm(x, y, seed + 3, 7, 2) > 0.45:
                col = ramp[0]
            if y - top < 2:
                col = ramp[3]
            img.set(x, y, col)
        if grass:
            for k in range(3):
                img.set(x, top - k, grass[1] if k else grass[2])
            img.set(x, top - 2, grass[2] if x % 3 else grass[1])
            if rng.random() < 0.18:
                for k in range(rng.randrange(2, 6)):
                    img.set(x, top + 1 + k, grass[0])


def lighthouse(h: int = 46) -> Canvas:
    """A small white-and-red striped lighthouse with a gallery and a warm lamp."""
    w = 12
    c = Canvas(w + 8, h + 12)
    cx = (w + 8) / 2
    for y in range(h):
        half = w / 2 * (0.7 + 0.3 * y / h)
        band = ((y // 8) % 2 == 0)
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x + 0.5 - (cx - half)) / (2 * half)
            if band:
                col = "white" if u < 0.3 else ("stone_l" if u < 0.7 else "stone")
            else:
                col = "coral" if u < 0.3 else ("red" if u < 0.7 else "red_d")
            c.set(x, y + 11, col)
    c.hline(int(cx - 6), int(cx + 6), 11, "iron")
    c.hline(int(cx - 6), int(cx + 6), 10, "steel")
    for y in range(4, 10):
        for x in range(int(cx - 3), int(cx + 3) + 1):
            c.set(x, y, "yellow" if x < cx else "gold_l")
    for x in range(int(cx - 4), int(cx + 4) + 1):
        c.set(x, 3, "red_d")
    c.set(int(cx), 2, "red_d")
    c.set(int(cx), 1, "iron")
    c.rect(int(cx) - 1, h + 3, 3, 4, "brown_d")
    c.outline_all("navy")
    return c


def flower_clump(rng: random.Random, cols=("pink", "rose"), leaf=("forest", "leaf_d")) -> Canvas:
    """Sea thrift: a low cushion of leaves with round flower heads (7x6)."""
    c = Canvas(8, 6)
    for (x, y) in P.ellipse(4, 4.5, 3.6, 1.8):
        c.set(x, y, leaf[1] if x < 4 else leaf[0])
    for k in range(rng.randrange(2, 4)):
        fx = rng.randrange(1, 7)
        fy = rng.randrange(0, 2)
        c.set(fx, fy + 1, leaf[0])
        c.set(fx, fy, cols[0])
        c.set(fx + 1, fy, cols[1])
    return c


# --------------------------------------------------------------------------
# ships
# --------------------------------------------------------------------------

def railing(w: int, h: int = 12, wood=("brown_d", "brown", "gold_d"), outline: str = "umber", step: int = 5) -> Canvas:
    """A ship's rail: a thick top rail over turned balusters."""
    c = Canvas(w, h)
    for x in range(w):
        c.set(x, 0, wood[2])
        c.set(x, 1, wood[1])
        c.set(x, 2, wood[0])
        c.set(x, h - 2, wood[1])
        c.set(x, h - 1, wood[0])
    for x in range(1, w, step):
        for y in range(3, h - 2):
            c.set(x, y, wood[1])
            c.set(x + 1, y, wood[0])
            if y == (h - 1) // 2:
                c.set(x - 1, y, wood[1])
                c.set(x + 2, y, wood[0])
    c.outline_all(outline)
    return c


def mast(h: int, w: int = 6) -> Canvas:
    c = Canvas(w + 2, h)
    for y in range(h):
        for x in range(w):
            u = x / (w - 1)
            col = "gold_d" if u < 0.3 else ("brown" if u < 0.75 else "brown_d")
            if y % 22 == 10:
                col = "iron" if u > 0.5 else "steel_d"
            c.set(x + 1, y, col)
    c.outline_all("umber")
    return c


def sail(w: int, h: int, seed: int, cloth=("sand", "cream", "white"), billow: float = 4.0,
         patch: bool = True) -> Canvas:
    """A square sail billowing towards the viewer: lit left, shaded right, a curved lower edge,
    seam lines (wide spacing), maybe a patch."""
    c = Canvas(w + 2, h + int(billow) + 3)
    for x in range(w):
        u = x / (w - 1)
        bottom = h + int(billow * math.sin(u * math.pi))
        for y in range(1, bottom):
            col = cloth[2] if u < 0.22 else (cloth[1] if u < 0.68 else cloth[0])
            if x % 9 == 4 and y > 2:
                col = dk(col) if col != cloth[0] else "dirt"
            c.set(x + 1, y, col)
    for x in range(w + 2):
        c.set(x, 0, "brown")
    if patch:
        rng = random.Random(seed)
        px, py = rng.randrange(4, max(5, w - 10)), rng.randrange(6, max(7, h - 10))
        for y in range(py, py + 6):
            for x in range(px, px + 7):
                if c.opaque(x, y):
                    c.set(x, y, "dirt" if (x == px or y == py + 5) else "sand")
    c.outline_all("umber")
    return c


def cannon(flip: bool = False) -> Canvas:
    c = Canvas(18, 11)
    for y in range(2, 7):
        for x in range(2, 15):
            c.set(x, y, "steel" if y < 4 else ("steel_d" if y < 6 else "iron"))
    c.rect(14, 1, 3, 7, "iron")
    c.set(14, 2, "steel_d")
    for x in (4, 10):
        for (dx, dy) in P.ellipse(x, 8, 2.5, 2.5):
            c.set(dx, dy, "brown" if dx < x else "brown_d")
    c.outline_all("ink")
    return c.flipped() if flip else c


def crate(w: int = 12, h: int = 10) -> Canvas:
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            col = "gold_d" if x < w // 3 else "brown"
            if y in (0, h - 1) or x in (0, w - 1):
                col = "brown_d"
            c.set(x, y, col)
    for k in range(1, min(w, h) - 1):
        c.set(1 + k * (w - 2) // (h - 2), k, "brown_d")
    c.hline(1, w - 2, 1, "gold")
    c.outline_all("umber")
    return c


# --------------------------------------------------------------------------
# underwater
# --------------------------------------------------------------------------

CORAL_RAMPS = {
    "coral": ("red_d", "coral", "pink", "peach"),
    "orange": ("brown", "orange", "amber", "gold_l"),
    "violet": ("plum", "violet", "lilac", "white"),
    "pink": ("rose", "pink", "peach", "cream"),
    "yellow": ("gold_d", "gold", "gold_l", "cream"),
    "teal": ("deep", "teal", "grass", "spring"),
}


def branch_coral(seed: int, h: int = 22, kind: str = "coral") -> Canvas:
    """Staghorn coral: a bushy clump of 2 px arms that fork and curve upwards, each ending in a round
    pale tip; arms on the left are lit, arms on the right in shade."""
    ramp = CORAL_RAMPS[kind]
    rng = random.Random(seed)
    w = int(h * 1.3) + 6
    c = Canvas(w, h + 2)
    tips = []
    cx = w / 2

    def arm(x: float, y: float, a: float, ln: float, depth: int) -> None:
        for s in range(int(ln)):
            a += (-math.pi / 2 - a) * 0.08
            x += math.cos(a)
            y += math.sin(a)
            lit = x < cx - 1
            c.set(int(x), int(y), ramp[2] if lit else ramp[1])
            c.set(int(x) + 1, int(y), ramp[1] if lit else ramp[0])
        if depth < 2 and ln > 3:
            n = 2 if depth else 3
            for k in range(n):
                da = (k - (n - 1) / 2) * 0.75 + rng.uniform(-0.15, 0.15)
                arm(x, y, a + da, ln * rng.uniform(0.6, 0.8), depth + 1)
        else:
            tips.append((int(x), int(y)))

    arm(cx, h + 1, -math.pi / 2, h * 0.42, 0)
    for (x, y) in tips:
        c.set(x, y, ramp[3])
        c.set(x + 1, y, ramp[2])
        c.set(x, y - 1, ramp[3])
    c.outline_all(dk(ramp[0]))
    return c


def coral_head(seed: int, w: int = 26, h: int = 18, kinds=("coral", "yellow", "violet")) -> Canvas:
    """A rounded coral head: a rock dome crowded with little round polyps of a few colours."""
    rng = random.Random(seed)
    c = Canvas(w, h)
    rock = AW.blob_canvas(w, h, [(w * 0.5, h * 0.62, h * 0.48), (w * 0.28, h * 0.7, h * 0.36), (w * 0.74, h * 0.7, h * 0.34)],
                          ["night", "water_d", "steel_d", "steel"], "night_d", seed, texture=0.1)
    c.blit(rock, 0, 0)
    for _ in range(w * h // 9):
        x, y = rng.randrange(1, w - 1), rng.randrange(1, h - 2)
        if name_at(c, x, y) in ("water_d", "steel_d", "steel") and name_at(c, x, y - 2) is not None:
            ramp = CORAL_RAMPS[rng.choice(kinds)]
            lit = x < w * 0.45 and y < h * 0.6
            c.set(x, y, ramp[2] if lit else ramp[1])
            c.set(x + 1, y, ramp[1] if lit else ramp[0])
            c.set(x, y - 1, ramp[3] if lit else ramp[2])
    return c


def reef_wall(img: Canvas, y_top_of, y1: int, seed: int, ramp=("night_d", "night", "water_d", "steel_d"),
              outline: str = "navy") -> None:
    """A wall of rounded reef boulders (overlapping lit blobs) along y_top_of(x) down to y1."""
    rng = random.Random(seed)
    for x in range(IMG_W):
        for y in range(int(y_top_of(x)) + 6, y1):
            img.set(x, y, ramp[0])
    for row in range(3):
        x = -12 + row * 7
        while x < IMG_W + 12:
            r = rng.uniform(7, 12) - row * 1.2
            top = y_top_of(x) + row * 8
            bl = AW.blob_canvas(int(r * 2.6) + 4, int(r * 2) + 4,
                                [(r * 1.3 + 2, r + 2, r), (r * 0.7 + 2, r * 1.2 + 2, r * 0.75),
                                 (r * 1.9 + 2, r * 1.2 + 2, r * 0.7)], list(ramp), outline, seed + int(x) + row * 97,
                                texture=0.1)
            img.blit(bl, int(x), int(top))
            x += r * 2.0


def sea_grass(rng: random.Random, ramp=("forest_d", "forest", "teal")) -> Canvas:
    """A tuft of sea grass (thin curving blades, 9x10)."""
    c = Canvas(9, 10)
    for k in range(4):
        x = 1 + k * 2
        top = rng.randrange(0, 5)
        lean = rng.choice((-1, 1))
        for y in range(top, 10):
            c.set(x + (lean if y < top + 3 else 0), y, ramp[2] if y < top + 2 else ramp[1])
        c.set(x + 1, 9, ramp[0])
    return c


def brain_coral(r: float, seed: int, kind: str = "yellow") -> Canvas:
    """A round brain coral dome with wandering grooves."""
    ramp = CORAL_RAMPS[kind]
    w = int(r * 2 + 3)
    c = Canvas(w, int(r * 1.4) + 3)
    cx, cy = w / 2, r + 1
    for y in range(c.h):
        for x in range(w):
            nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            if nx * nx + ny * ny > 1 or y > cy + r * 0.35:
                continue
            v = -0.6 * nx - 0.7 * ny
            col = ramp[2] if v > 0.35 else (ramp[1] if v > -0.25 else ramp[0])
            if math.sin(x * 0.9 + math.sin(y * 0.8 + seed) * 2.2) > 0.75:
                col = dk(col)
            c.set(x, y, col)
    c.outline_all(dk(ramp[0]))
    return c


def fan_coral(w: int, h: int, seed: int, kind: str = "violet") -> Canvas:
    """A sea fan: a flat lattice fanning out from a short stem."""
    ramp = CORAL_RAMPS[kind]
    rng = random.Random(seed)
    c = Canvas(w, h)
    bx, by = w / 2, h - 1
    for k in range(9):
        a = -math.pi * 0.92 + k * math.pi * 0.84 / 8
        ln = h * rng.uniform(0.75, 0.95)
        for s in range(int(ln)):
            x = bx + math.cos(a) * s * (w / h) * 0.55
            y = by + math.sin(a) * s
            c.set(int(x), int(y), ramp[1] if k < 5 else ramp[0])
    for y in range(2, h - 3, 3):
        for x in range(w):
            if c.opaque(x - 1, y) and c.opaque(x + 1, y) and not c.opaque(x, y):
                c.set(x, y, ramp[2])
    for x in range(w):
        for y in range(h):
            if c.opaque(x, y) and not c.opaque(x, y - 1) and y < h * 0.4:
                c.set(x, y, ramp[2])
    c.outline_all(dk(ramp[0]))
    return c


def tube_sponge(seed: int, kind: str = "orange") -> Canvas:
    ramp = CORAL_RAMPS[kind]
    rng = random.Random(seed)
    c = Canvas(14, 16)
    for k in range(3):
        x = 2 + k * 4
        top = rng.randrange(1, 7)
        for y in range(top, 15):
            c.set(x, y, ramp[2])
            c.set(x + 1, y, ramp[1])
            c.set(x + 2, y, ramp[0])
        c.set(x + 1, top, ramp[0])
        c.set(x, top, ramp[3])
    c.outline_all(dk(ramp[0]))
    return c


def seaweed_clump(seed: int, h: int = 12, ramp=("forest_d", "teal", "grass")) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(12, h + 1)
    for k in range(4):
        x = 2 + k * 2 + rng.randrange(0, 2)
        top = rng.randrange(0, h // 2)
        for y in range(top, h + 1):
            xx = x + int(1.3 * math.sin(y * 0.6 + k))
            c.set(xx, y, ramp[2] if k % 2 else ramp[1])
            if y > top + 1:
                c.set(xx + 1, y, ramp[0])
    return c


def column(h: int, w: int = 12, ramp=("stone_d", "stone", "stone_l", "white"), outline: str = "iron",
           broken: float = 0.0, seed: int = 0, cap: bool = True) -> Canvas:
    """A fluted column with a base and a capital; broken > 0 snaps the top off (jagged)."""
    rng = random.Random(seed)
    c = Canvas(w + 6, h + 2)
    cx = (w + 6) / 2
    top_cut = int(h * broken)
    for y in range(h):
        if y < top_cut:
            continue
        is_cap = cap and not broken and y < 4
        is_base = y > h - 5
        half = (w / 2 + 2) if (is_cap or is_base) else w / 2
        for x in range(int(cx - half), int(cx + half)):
            u = (x + 0.5 - (cx - half)) / (2 * half)
            col = ramp[3] if u < 0.18 else (ramp[2] if u < 0.45 else (ramp[1] if u < 0.8 else ramp[0]))
            if not (is_cap or is_base) and (x - int(cx - half)) % 3 == 2 and 0.15 < u < 0.9:
                col = dk(col)
            if (is_cap or is_base) and y in (0, h - 1):
                col = ramp[2] if u < 0.6 else ramp[1]
            c.set(x, y + 1, col)
    if broken:
        for x in range(c.w):
            for k in range(rng.randrange(0, 4)):
                c.set(x, top_cut + 1 + k, None)
        for x in range(c.w):
            for y in range(c.h):
                if c.opaque(x, y):
                    c.set(x, y, ramp[2])
                    break
    c.outline_all(outline)
    return c


def amphora(seed: int, cols=("brown", "gold_d", "dirt")) -> Canvas:
    c = Canvas(9, 13)
    for (x, y) in P.ellipse(4.5, 7.5, 3.6, 4.5):
        c.set(x, y, cols[2] if x < 4 else (cols[1] if x < 6 else cols[0]))
    c.rect(3, 1, 3, 3, cols[1])
    c.hline(2, 6, 1, cols[2])
    c.set(1, 4, cols[0])
    c.set(7, 4, cols[0])
    c.hline(2, 6, 7, cols[0])
    c.outline_all("umber")
    return c


def treasure_chest(open_: bool = False) -> Canvas:
    c = Canvas(16, 13)
    c.rect(1, 6, 14, 6, "brown")
    c.rect(1, 6, 4, 6, "gold_d")
    c.hline(1, 14, 9, "gold")
    if open_:
        c.rect(2, 3, 12, 3, "yellow")
        c.set(4, 2, "gold_l")
        c.set(9, 2, "white")
        c.set(11, 3, "gold_l")
        c.rect(1, 0, 14, 2, "brown_d")
    else:
        c.rect(1, 2, 14, 4, "brown_d")
        c.hline(1, 14, 2, "brown")
    c.rect(7, 7, 2, 3, "gold_l")
    c.outline_all("umber")
    return c


def scallop_throne() -> Canvas:
    """A huge scallop shell standing upright: the Kraken's throne (52x44)."""
    w, h = 56, 46
    c = Canvas(w, h)
    cx, cy = w / 2, h - 6
    for y in range(h - 4):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx / 1.15, dy)
            if r > 26 or dy > 0:
                continue
            a = math.atan2(dy, dx)
            rib = math.sin(a * 11)
            u = (x + 0.5) / w
            col = "peach" if rib > 0.35 else ("pink" if rib > -0.4 else "rose")
            if u > 0.7 and col == "peach":
                col = "pink"
            if r > 24:
                col = "rose" if rib > 0 else "dusk"
            c.set(x, y, col)
    for y in range(h - 6, h):
        for x in range(int(cx - 8), int(cx + 8)):
            c.set(x, y, "pink" if x < cx else "rose")
    c.outline_all("wine")
    return c


# --------------------------------------------------------------------------
# snow and ice
# --------------------------------------------------------------------------

SNOW = ("fog", "steel_l", "white")


def snow_pine(seed: int, h: int = 36, ramp=("deep", "forest_d", "forest"), snow=("steel_l", "white"),
              outline: str = "navy") -> Canvas:
    """A dark pine with snow resting on top of each tier (lit left)."""
    p = AW.pine(seed, h, ramp, outline)
    rng = random.Random(seed)
    for x in range(p.w):
        first = True
        for y in range(p.h - 4):
            n = name_at(p, x, y)
            if n is None or n == outline:
                first = True
                continue
            if first:
                above = name_at(p, x, y - 1)
                if above == outline or above is None:
                    p.set(x, y, snow[1] if x < p.w * 0.55 else snow[0])
                    if rng.random() < 0.55:
                        p.set(x, y + 1, snow[0])
                first = False
    return p


def snow_mound(w: int, h: int, seed: int, ramp=("steel", "steel_l", "white"), outline: str | None = "steel") -> Canvas:
    """A soft snow drift: a wide low dome, lit top-left, blue shade at the foot."""
    blobs = [(w * 0.3, h * 0.65, h * 0.55), (w * 0.62, h * 0.55, h * 0.62), (w * 0.82, h * 0.75, h * 0.42)]
    c = AW.blob_canvas(w, h + 2, blobs, list(ramp), outline, seed, texture=0.06)
    return c


def snow_cap(c: Canvas, depth: int = 2, seed: int = 0, snow=("steel_l", "white"), skip: tuple[str, ...] = ()) -> Canvas:
    """Lay snow on whatever a prop shows to the sky: the top `depth` pixels of every column (white on the
    left half, steel_l on the right), with a slightly ragged lower edge."""
    rng = random.Random(seed)
    for x in range(c.w):
        seen = 0
        for y in range(c.h):
            n = name_at(c, x, y)
            if n is None:
                if seen:
                    break
                continue
            if seen == 0 and name_at(c, x, y - 1) is None:
                pass
            if n in skip:
                continue
            d = depth + (1 if rng.random() < 0.3 else 0)
            if seen < d:
                c.set(x, y, snow[1] if x < c.w * 0.55 else snow[0])
                seen += 1
            else:
                break
    return c


def snow_rock(seed: int, w: int, h: int, ramp=("slate", "stone_d", "stone", "stone_l"), outline: str = "iron") -> Canvas:
    r = AW.rock(seed, w, h, ramp, outline, None)
    return snow_cap(r, 2, seed, skip=(outline,))


def icicles(img: Canvas, x0: int, x1: int, y: int, seed: int, cols=("azure", "sky_l", "white"), max_len: int = 9) -> None:
    rng = random.Random(seed)
    x = x0
    while x < x1:
        ln = rng.randrange(2, max_len)
        for k in range(ln):
            img.set(x, y + k, cols[1] if k < ln - 1 else cols[2])
            if k < ln // 2:
                img.set(x + 1, y + k, cols[0])
        x += rng.randrange(3, 7)


def ice_block(w: int, h: int, seed: int, ramp=("water", "sky", "azure", "sky_l"), outline: str = "water_d") -> Canvas:
    """A chunk of glacier ice: a faceted block with a lit left face, inner cracks and a white glint."""
    rng = random.Random(seed)
    c = Canvas(w, h)
    pts = [(rng.uniform(0, w * 0.2), h - 1), (rng.uniform(0, w * 0.25), rng.uniform(h * 0.2, h * 0.45)),
           (w * rng.uniform(0.3, 0.5), 0), (w * rng.uniform(0.7, 0.9), rng.uniform(0, h * 0.25)),
           (w - 1, rng.uniform(h * 0.35, h * 0.6)), (w - 1 - rng.uniform(0, w * 0.15), h - 1)]
    shape = P.poly(pts)
    split = w * 0.42
    for (x, y) in shape:
        u = (x + 0.5) / w
        col = ramp[3] if x < split - 3 else (ramp[2] if x < split + 4 else (ramp[1] if u < 0.85 else ramp[0]))
        c.set(x, y, col)
    for k in range(2):
        x, y = rng.uniform(w * 0.3, w * 0.7), rng.uniform(h * 0.3, h * 0.8)
        for s in range(rng.randrange(4, 9)):
            x += rng.uniform(-1, 1)
            y -= 1
            if c.opaque(int(x), int(y)):
                c.set(int(x), int(y), ramp[3])
    c.set(int(split - 4), int(h * 0.4), "white")
    c.outline_all(outline)
    return c


# --------------------------------------------------------------------------
# fire
# --------------------------------------------------------------------------

LAVA = ("red_d", "red", "orange", "amber", "yellow")


def lava_pool(img: Canvas, cx: float, cy: float, rx: float, ry: float, seed: int,
              crust=("ink", "slate", "stone_d")) -> None:
    """A lava pool: bright core, orange body, dark red rim, a crusted rock lip, a few dark crust islands."""
    for y in range(int(cy - ry) - 3, int(cy + ry) + 4):
        for x in range(int(cx - rx) - 3, int(cx + rx) + 4):
            d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry) + (fbm(x, y, seed, 7, 2) - 0.5) * 0.25
            if d < 1.0:
                col = "yellow" if d < 0.35 else ("amber" if d < 0.55 else ("orange" if d < 0.8 else "red"))
                if 0.4 < d < 0.9 and fbm(x, y, seed + 9, 5, 2) > 0.66:
                    col = "red_d"
                img.set(x, y, col)
            elif d < 1.12:
                img.set(x, y, crust[0] if y > cy else crust[1])


def lava_river(img: Canvas, pts: list[tuple[float, float]], width: float, seed: int) -> None:
    """A lava stream along a polyline: hot centre, orange body, dark red edges, crust lip."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bx0, bx1 = int(min(xs) - width - 3), int(max(xs) + width + 3)
    by0, by1 = int(min(ys) - width - 3), int(max(ys) + width + 3)

    def dist(px: float, py: float) -> float:
        best = 1e9
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            vx, vy = bx - ax, by - ay
            ll = vx * vx + vy * vy or 1e-9
            t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / ll))
            best = min(best, math.hypot(px - (ax + vx * t), py - (ay + vy * t)))
        return best

    half = width / 2
    for y in range(max(0, by0), min(img.h, by1)):
        for x in range(max(0, bx0), min(img.w, bx1)):
            d = dist(x + 0.5, y + 0.5) + (fbm(x, y, seed, 6, 2) - 0.5) * 2.5
            if d < half:
                k = d / half
                col = "yellow" if k < 0.22 else ("amber" if k < 0.45 else ("orange" if k < 0.75 else "red"))
                if 0.45 < k < 0.8 and fbm(x * 0.5, y * 2, seed + 4, 4, 2) > 0.62:
                    col = "red_d"
                img.set(x, y, col)
            elif d < half + 1.6:
                img.set(x, y, "ink" if y % 2 else "slate")


def glow_crack(img: Canvas, x: float, y: float, length: int, seed: int, cols=("red_d", "orange", "amber")) -> None:
    rng = random.Random(seed)
    ang = rng.uniform(0, 2 * math.pi)
    for i in range(length):
        ang += rng.uniform(-0.6, 0.6)
        x += math.cos(ang)
        y += math.sin(ang) * 0.7
        mid = length // 4 < i < 3 * length // 4
        img.set(int(x), int(y), cols[2] if mid and i % 3 == 0 else (cols[1] if mid else cols[0]))


def basalt(seed: int, w: int, h: int, ramp=("ink", "slate", "stone_d", "ash"), glow: bool = False) -> Canvas:
    """A dark volcanic boulder (faceted blob) with an optional glowing seam."""
    blobs = [(w * 0.5, h * 0.62, h * 0.55), (w * 0.3, h * 0.55, h * 0.45), (w * 0.72, h * 0.66, h * 0.42)]
    c = AW.blob_canvas(w + 2, h + 2, [(x + 1, y + 1, r) for x, y, r in blobs], list(ramp), "ink", seed, texture=0.1)
    if glow:
        rng = random.Random(seed)
        x = rng.randrange(3, w - 2)
        for y in range(h // 2, h):
            if c.opaque(x, y) and name_at(c, x, y) != "ink":
                c.set(x, y, "orange" if y % 3 else "amber")
            x += rng.choice((-1, 0, 1))
    return c


# --------------------------------------------------------------------------
# autumn and dusk
# --------------------------------------------------------------------------

AUTUMN = {
    "gold": ("brown", "gold_d", "gold", "gold_l"),
    "orange": ("red_d", "orange", "amber", "gold_l"),
    "red": ("wine", "red_d", "red", "coral"),
    "rust": ("brown_d", "brown", "gold_d", "gold"),
}


def autumn_tree(seed: int, size: int = 30, kind: str = "orange", outline: str = "umber") -> Canvas:
    return AW.tree(seed, size, AUTUMN[kind], outline, trunk=("brown_d", "brown"))


def leaf_litter(img: Canvas, rect: tuple[int, int, int, int], n: int, seed: int,
                cols=("orange", "red", "gold", "red_d", "gold_d"), calm: float = 0.92, mask=None) -> None:
    """Fallen leaves: 2-3 px leaves in warm colours, thinning towards the arena middle."""
    rng = random.Random(seed)
    x0, y0, x1, y1 = rect
    for _ in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        if rng.random() < W.calm_k(x, y) * calm:
            continue
        if mask is not None and not mask(x, y):
            continue
        col = rng.choice(cols)
        img.set(x, y, col)
        img.set(x + 1, y, col if rng.random() < 0.5 else dk(col))
        if rng.random() < 0.4:
            img.set(x, y + 1, dk(col))


def wolf_emblem(c: Canvas, x: int, y: int, col: str, eye: str | None = None) -> None:
    """A tiny wolf head (5x5): two ears, a long snout to the right."""
    for (dx, dy) in ((0, 0), (2, 0), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
                     (1, 3), (2, 3), (3, 3), (1, 4)):
        c.set(x + dx, y + dy, col)
    if eye:
        c.set(x + 2, y + 2, eye)


def tent(w: int, h: int, seed: int, cloth=("slate", "ash", "fog"), trim: str = "plum", emblem: bool = True,
         open_: bool = True) -> Canvas:
    """An army tent: a pointed canvas cone/ridge, lit left face, shaded right, a dark open flap, a pennant
    on the pole and the black wolf on the front."""
    c = Canvas(w + 4, h + 8)
    cx = (w + 4) / 2
    for y in range(h):
        half = (y + 1) / h * (w / 2)
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x + 0.5 - (cx - half)) / max(1.0, 2 * half)
            col = cloth[2] if u < 0.25 else (cloth[1] if u < 0.62 else cloth[0])
            if y == h - 1:
                col = trim
            c.set(x, y + 7, col)
    if open_:
        for y in range(h // 2, h - 1):
            half = (y - h // 2) / (h / 2) * (w / 7)
            for x in range(int(cx - half), int(cx + half) + 1):
                c.set(x, y + 7, "ink" if x > cx - half + 1 else "navy")
    elif emblem:
        wolf_emblem(c, int(cx) - 2, h // 2 + 7, "ink")
    c.vline(int(cx), 0, 8, "brown_d")
    c.set(int(cx) + 1, 1, "ink")
    c.set(int(cx) + 2, 1, "ink")
    c.set(int(cx) + 1, 2, "slate")
    c.outline_all("ink")
    return c


def palisade(w: int, h: int, seed: int, wood=("umber", "brown_d", "brown")) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(w, h + 4)
    x = 0
    while x < w:
        top = rng.randrange(0, 4)
        for y in range(top + 2, h + 4):
            c.set(x, y, wood[2])
            c.set(x + 1, y, wood[1])
            c.set(x + 2, y, wood[0])
        c.set(x + 1, top, wood[1])
        c.set(x, top + 1, wood[2])
        c.set(x + 1, top + 1, wood[1])
        c.set(x + 2, top + 1, wood[0])
        x += 4
    for y in (h // 3 + 3, h - h // 4 + 3):
        c.hline(0, w - 1, y, wood[0])
    c.outline_all("ink")
    return c


def spear_rack(seed: int) -> Canvas:
    c = Canvas(18, 22)
    c.hline(1, 16, 8, "brown")
    c.hline(1, 16, 9, "brown_d")
    c.vline(2, 8, 21, "brown_d")
    c.vline(15, 8, 21, "brown_d")
    for k in range(4):
        x = 4 + k * 3
        c.vline(x, 3, 20, "brown" if k % 2 else "gold_d")
        c.set(x, 2, "steel_l")
        c.set(x, 1, "steel")
    for k in range(2):
        for (x, y) in P.ellipse(6 + k * 6, 15, 3, 3.5):
            c.set(x, y, "slate" if x < 6 + k * 6 else "iron")
        c.set(6 + k * 6, 15, "plum")
    c.outline_all("ink")
    return c


def pillar(h: int, w: int = 14, ramp=("stone_d", "stone", "stone_l", "white"), outline: str = "iron") -> Canvas:
    return column(h, w, ramp, outline, cap=True)


def candelabra(seed: int = 0, metal=("gold_d", "gold", "gold_l")) -> Canvas:
    """A tall standing candelabrum (three arms); candles are animated sprites placed on top."""
    c = Canvas(19, 30)
    c.vline(9, 6, 27, metal[1])
    c.vline(10, 6, 27, metal[0])
    c.hline(2, 16, 6, metal[1])
    c.hline(2, 16, 7, metal[0])
    for x in (2, 16):
        c.vline(x, 3, 6, metal[1])
    c.vline(9, 3, 6, metal[1])
    c.hline(6, 13, 27, metal[1])
    c.hline(5, 14, 28, metal[0])
    c.set(9, 15, metal[2])
    c.outline_all("umber")
    return c


def throne(w: int = 30, h: int = 38, wood=("gold_d", "gold", "gold_l"), cushion=("plum", "violet", "lilac")) -> Canvas:
    c = Canvas(w, h)
    cx = w / 2
    for y in range(h):
        for x in range(w):
            back = 3 <= x < w - 3 and y < h * 0.65
            arm = (x < 6 or x >= w - 6) and h * 0.45 <= y < h * 0.75
            seat = 3 <= x < w - 3 and h * 0.6 <= y < h * 0.75
            leg = (x in (4, 5, w - 6, w - 5)) and y >= h * 0.75
            if back or arm or seat or leg:
                u = x / w
                col = wood[2] if u < 0.25 else (wood[1] if u < 0.7 else wood[0])
                if back and 7 <= x < w - 7 and 6 <= y < h * 0.6:
                    col = cushion[1] if x < cx else cushion[0]
                    if x < 10:
                        col = cushion[2]
                if seat and 6 <= x < w - 6:
                    col = cushion[1]
                c.set(x, y, col)
    for k in range(3):
        x = int(cx - 6 + k * 6)
        c.set(x, 0, wood[2])
        c.set(x, 1, wood[1])
    c.set(int(cx), 3, "red")
    c.outline_all("umber")
    return c


def apple_tree(seed: int, size: int = 32, bloom: float = 0.35, blossom=("pink", "white", "peach"),
               leaves=("forest", "leaf_d", "leaf", "spring"), outline: str = "forest_d", apples: int = 3) -> Canvas:
    """An apple tree of Avalon: a round green crown dotted with blossom clusters and a few red apples."""
    rng = random.Random(seed)
    t = AW.tree(seed, size, leaves, outline)
    pts = [(x, y) for y in range(t.h) for x in range(t.w)
           if name_at(t, x, y) in leaves[1:] and name_at(t, x, y - 1) is not None]
    for _ in range(int(len(pts) * bloom / 5)):
        x, y = rng.choice(pts)
        col = rng.choice(blossom)
        for (dx, dy) in ((0, 0), (1, 0), (0, 1)):
            if name_at(t, x + dx, y + dy) in leaves:
                t.set(x + dx, y + dy, col if (dx, dy) != (0, 1) else lt(col))
    for _ in range(apples):
        x, y = rng.choice(pts)
        if name_at(t, x, y + 1) in leaves:
            t.set(x, y, "red")
            t.set(x, y + 1, "red_d")
    return t


def stone_arch(w: int, h: int, seed: int, ramp=("stone_d", "stone", "stone_l"), outline: str = "iron",
               thick: int = 8, inner: str | None = None) -> Canvas:
    """A freestanding round-topped stone archway made of voussoirs (block seams radiate)."""
    c = Canvas(w, h)
    cx = w / 2
    r_out = w / 2 - 1
    r_in = r_out - thick
    spring = r_out
    for y in range(h):
        for x in range(w):
            dx = x + 0.5 - cx
            if y < spring:
                dy = spring - (y + 0.5)
                d = math.hypot(dx, dy)
                if r_in <= d <= r_out:
                    a = math.atan2(dy, dx)
                    seam = (a / math.pi * 13) % 1 < 0.12
                    u = (dx / r_out + 1) / 2
                    col = ramp[2] if u < 0.35 else (ramp[1] if u < 0.75 else ramp[0])
                    c.set(x, y, outline if seam else col)
                elif d < r_in and inner:
                    c.set(x, y, inner)
            else:
                if abs(dx) >= r_in and abs(dx) <= r_out:
                    u = (dx / r_out + 1) / 2
                    col = ramp[2] if u < 0.2 or (0.5 < u < 0.62) else (ramp[1] if u < 0.85 else ramp[0])
                    if (y - int(spring)) % 7 == 6:
                        col = outline
                    c.set(x, y, col)
                elif abs(dx) < r_in and inner:
                    c.set(x, y, inner)
    c.outline_all(outline)
    return c


# --------------------------------------------------------------------------
# animated layers
# --------------------------------------------------------------------------

def _anim_foam(w: int = 48, h: int = 9) -> list[Anim]:
    """The edge of a wave washing up the sand and sliding back (8 frames): a thin turquoise film,
    a bright foam front with bubbles; laid over a painted shoreline."""
    frames = []
    for f in range(8):
        c = Canvas(w, h)
        reach = 2.5 + 2.5 * math.sin(f / 8 * 2 * math.pi)
        for x in range(w):
            front = int(1 + reach + 1.2 * math.sin(x / 6.0 + f * 0.5) + 0.6 * math.sin(x / 2.3))
            for y in range(0, front):
                c.set(x, y, "azure" if y < front - 1 else "sky_l")
            c.set(x, front, "white")
            if (x + f) % 7 == 0:
                c.set(x, front + 1, "sky_l")
        frames.append(c)
    return [Anim("default", frames, 4.0, True)]


def _anim_crest() -> list[Anim]:
    """A small wave crest rising, curling white and settling (6 frames, 12x4)."""
    frames = []
    shapes = [[], [(4, 3), (5, 3), (6, 3)], [(3, 2), (4, 2), (5, 2), (6, 2), (7, 3)],
              [(2, 2), (3, 1), (4, 1), (5, 1), (6, 2), (7, 2), (8, 3)], [(3, 2), (4, 2), (5, 2), (8, 2), (9, 3)],
              [(6, 3), (9, 3)]]
    for i, pts in enumerate(shapes):
        c = Canvas(12, 4)
        for (x, y) in pts:
            c.set(x, y, "white" if i in (2, 3) else "sky_l")
            if i == 3 and y < 3:
                c.set(x, y + 1, "azure")
        frames.append(c)
    return [Anim("default", frames, 6.0, True, [3.0, 1, 1, 1.5, 1, 1])]


def _anim_gull() -> list[Anim]:
    """A seagull gliding in a lazy loop and flapping now and then (8 frames, 24x14)."""
    frames = []
    wings = [0, 0, 1, 2, 1, 0, 0, -1]
    for f in range(8):
        c = Canvas(24, 14)
        a = f / 8 * 2 * math.pi
        x = int(round(12 + math.cos(a) * 6))
        y = int(round(7 + math.sin(a) * 2))
        w = wings[f]
        c.set(x, y, "white")
        c.set(x + 1, y, "steel_l")
        c.set(x + 2, y, "orange")
        for s in (1, 2, 3, 4):
            yy = y - (w if s < 3 else w * 2) + (1 if s == 4 and w <= 0 else 0) - (1 if s == 2 and w == 0 else 0)
            c.set(x - s, yy if s < 4 else yy, "white" if s < 3 else "steel")
            c.set(x + s, yy, "white" if s < 3 else "steel")
        c.set(x - 4, y - w * 2 + (1 if w <= 0 else 0), "iron")
        c.set(x + 4, y - w * 2 + (1 if w <= 0 else 0), "iron")
        frames.append(c)
    return [Anim("default", frames, 5.0, True)]


def _anim_kelp(ramp=("forest_d", "teal", "grass", "spring"), h: int = 28) -> list[Anim]:
    """A frond of kelp swaying in the current (6 frames, 10 x h)."""
    frames = []
    for f in range(6):
        c = Canvas(10, h)
        ph = f / 6 * 2 * math.pi
        for y in range(h):
            t = (h - y) / h
            x = 4 + math.sin(ph + y * 0.25) * 2.2 * t
            xi = int(round(x))
            c.set(xi, y, ramp[1])
            c.set(xi + 1, y, ramp[0])
            if y % 4 == 1:
                side = 1 if (y // 4) % 2 else -1
                c.set(xi + (2 if side > 0 else -1), y, ramp[2])
                c.set(xi + (3 if side > 0 else -2), y + 1, ramp[2])
            if y % 6 == 3:
                c.set(xi, y, ramp[3] if t > 0.3 else ramp[2])
        frames.append(c)
    return [Anim("default", frames, 4.0, True)]


def _anim_anemone(ramp=("rose", "pink", "peach")) -> list[Anim]:
    frames = []
    for f in range(4):
        c = Canvas(11, 9)
        for k in range(5):
            bx = 2 + k * 1.6
            sway = math.sin(f / 4 * 2 * math.pi + k) * 1.2
            for j in range(5):
                x = bx + sway * j / 4 + (k - 2) * j * 0.3
                c.set(int(round(x)), 6 - j, ramp[1] if j < 4 else ramp[2])
        for x in range(2, 9):
            c.set(x, 7, ramp[0])
            c.set(x, 8, ramp[0] if x % 2 else "wine")
        frames.append(c)
    return [Anim("default", frames, 4.0, True)]


def _anim_bubbles() -> list[Anim]:
    """A thin column of bubbles rising and wobbling (8 frames, 7x26)."""
    frames = []
    for f in range(8):
        c = Canvas(7, 26)
        for k in range(4):
            t = ((f / 8) + k / 4) % 1.0
            y = int(24 - t * 24)
            x = int(3 + math.sin(t * 9 + k) * 1.5)
            big = k % 2 == 0
            if big:
                for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    c.set(x + dx, y + dy, "sky_l")
                c.set(x - 1, y - 1, "white")
            else:
                c.set(x, y, "white")
        frames.append(c)
    return [Anim("default", frames, 6.0, True)]


def _anim_fish(cols=("gold", "gold_l", "orange")) -> list[Anim]:
    """A little school of three fish swimming across and back (8 frames, 30x12)."""
    frames = []
    for f in range(8):
        c = Canvas(30, 12)
        a = f / 8 * 2 * math.pi
        dirx = 1 if math.cos(a) <= 0 else -1
        for k, (ox, oy) in enumerate(((0, 0), (-5, 3), (-4, -3))):
            x = int(round(15 + math.sin(a) * 9 + ox * dirx))
            y = int(round(6 + oy + math.sin(a * 2 + k) * 0.8))
            body = [(0, 0), (1, 0), (-1, 0), (0, -1), (0, 1) if k else (1, 1)]
            for (dx, dy) in body:
                c.set(x + dx * dirx, y + dy, cols[0])
            c.set(x + dirx, y, cols[1])
            c.set(x - 2 * dirx, y - 1, cols[2])
            c.set(x - 2 * dirx, y + 1, cols[2])
            c.set(x + dirx, y - 1 if k == 0 else y, "ink" if k == 0 else cols[1])
        frames.append(c)
    return [Anim("default", frames, 5.0, True)]


def _anim_caustic() -> list[Anim]:
    """A shimmering net of light on the sea floor (4 frames, 16x8)."""
    frames = []
    for f in range(4):
        c = Canvas(16, 8)
        for x in range(16):
            for y in range(8):
                v = math.sin(x * 0.8 + f * 1.5) + math.sin(y * 1.3 - f * 1.1 + x * 0.3)
                if v > 1.55:
                    c.set(x, y, "haze" if v > 1.8 else "sky_l")
        frames.append(c)
    return [Anim("default", frames, 4.0, True)]


def _anim_helm() -> list[Anim]:
    """The ship's wheel rocking a little (4 frames, 17x17)."""
    frames = []
    for f in range(4):
        c = Canvas(17, 17)
        a0 = [0.0, 0.18, 0.0, -0.18][f]
        cx = cy = 8
        for (x, y) in P.ellipse(8.5, 8.5, 5.6, 5.6):
            d = math.hypot(x + 0.5 - 8.5, y + 0.5 - 8.5)
            if d > 4.3:
                c.set(x, y, "gold_d" if x + y < 17 else "brown")
        for k in range(8):
            a = a0 + k * math.pi / 4
            for s in range(1, 9):
                x, y = int(round(cx + math.cos(a) * s)), int(round(cy + math.sin(a) * s))
                if s > 6 or s < 5:
                    c.set(x, y, "brown" if s < 7 else "gold")
        c.set(8, 8, "gold_l")
        c.outline_all("umber")
        frames.append(c)
    return [Anim("default", frames, 2.0, True)]


def _anim_flag_emblem(cloth: tuple[str, str, str], draw, outline: str = "ink", fps: float = 5.0) -> list[Anim]:
    """A long banner hanging from a bar, rippling (4 frames, 12x20), with draw(canvas, wave) for its emblem."""
    frames = []
    for f in range(4):
        c = Canvas(12, 20)
        c.hline(0, 11, 0, "brown_d")
        c.hline(0, 11, 1, "gold_d")
        waves = {}
        for y in range(2, 18):
            wave = int(round(math.sin(f / 4 * 2 * math.pi + y * 0.42) * 1.1)) if y > 4 else 0
            waves[y] = wave
            for x in range(2, 10):
                col = cloth[1]
                if x == 2:
                    col = cloth[2]
                elif x >= 8:
                    col = cloth[0]
                if y >= 15 and abs(x - 5.5) < (y - 14) * 1.3:
                    continue
                c.set(x + wave, y, col)
        draw(c, waves)
        c.outline_all(outline)
        frames.append(c)
    return [Anim("default", frames, fps, True)]


def _wolf_on_flag(col: str, eye: str | None):
    def draw(c: Canvas, waves: dict) -> None:
        for (dx, dy) in ((0, 0), (2, 0), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
                         (1, 3), (2, 3), (3, 3), (1, 4)):
            y = 6 + dy
            c.set(3 + dx + waves.get(y, 0), y, col)
        if eye:
            c.set(5 + waves.get(8, 0), 8, eye)
    return draw


def _fishbone_on_flag(c: Canvas, waves: dict) -> None:
    for x in range(3, 8):
        c.set(x + waves.get(8, 0), 8, "white")
    for (dx, dy) in ((4, 7), (4, 9), (6, 7), (6, 9), (8, 7), (8, 9), (2, 8)):
        y = dy
        c.set(dx + waves.get(y, 0) - (1 if dx == 8 else 0), y, "white" if dx != 2 else "steel_l")


def _anim_lantern(glass=("yellow", "gold_l", "orange")) -> list[Anim]:
    """A hanging lantern swinging gently with a flickering light (4 frames, 9x15)."""
    frames = []
    for f in range(4):
        c = Canvas(9, 15)
        sw = [0, 1, 0, -1][f]
        c.vline(4, 0, 3, "iron")
        x0 = 2 + sw
        c.hline(x0, x0 + 4, 4, "iron")
        c.rect(x0, 5, 5, 6, glass[2])
        c.rect(x0 + 1, 6, 2, 3, glass[0] if f % 2 == 0 else glass[1])
        c.set(x0 + 3, 6, glass[1])
        c.hline(x0, x0 + 4, 11, "iron")
        c.set(x0 + 2, 12, "iron")
        c.outline_all("ink")
        frames.append(c)
    return [Anim("default", frames, 4.0, True)]


def _anim_ripple(cols=("white", "sky_l")) -> list[Anim]:
    """Rings spreading on calm warm water (6 frames, 13x5)."""
    frames = []
    for f in range(6):
        c = Canvas(13, 5)
        r = 1 + f
        for x in range(13):
            for y in range(5):
                d = math.hypot((x + 0.5 - 6.5) / 1.0, (y + 0.5 - 2.5) * 2.4)
                if abs(d - r) < 0.55 and f < 5:
                    c.set(x, y, cols[0] if f < 3 else cols[1])
        frames.append(c)
    return [Anim("default", frames, 5.0, True, [1, 1, 1, 1, 1, 4])]


def _anim_lava_flow(w: int = 24, h: int = 6) -> list[Anim]:
    """Bright ripples drifting down a lava stream (6 frames): drawn over a painted lava river."""
    frames = []
    for f in range(6):
        c = Canvas(w, h)
        for x in range(w):
            for y in range(h):
                v = math.sin((x - f * 4) * 0.55 + y * 0.9) + 0.6 * math.sin((x - f * 4) * 0.21)
                if v > 1.2:
                    c.set(x, y, "yellow" if v > 1.45 else "amber")
        frames.append(c)
    return [Anim("default", frames, 6.0, True)]


def _anim_lava_bubble() -> list[Anim]:
    """A lava bubble swelling and popping (6 frames, 9x8)."""
    frames = []
    for f in range(6):
        c = Canvas(9, 8)
        if f < 4:
            r = 1 + f * 0.8
            for (x, y) in P.ellipse(4.5, 6, r + 0.3, r * 0.8 + 0.3):
                c.set(x, y, "amber" if (x < 4 and y < 6) else "orange")
            c.set(3, int(6 - r * 0.5), "yellow")
        elif f == 4:
            for (x, y) in ((2, 4), (6, 4), (1, 6), (7, 6), (4, 3)):
                c.set(x, y, "yellow")
        frames.append(c)
    return [Anim("default", frames, 6.0, True, [3, 1, 1, 1, 1, 3])]


def _anim_campfire() -> list[Anim]:
    """A campfire: crossed logs, a ring of stones and dancing flames (4 frames, 16x16)."""
    frames = []
    shapes = [
        ["...Y....", "..YwY...", ".YwwOY..", "YOwwOOY.", "OYOOYOO."],
        ["....Y...", "...YY...", "..YwwY..", ".YwwOOY.", "OYOOYOO."],
        ["..Y.....", "..YY....", ".YwwY...", "YOwwOY..", "OYOOYOO."],
        ["...Y....", "...Y.Y..", "..YwYY..", ".YwwOOY.", "OYOOYOO."],
    ]
    for s in shapes:
        c = Canvas(16, 16)
        c.stamp(s, 4, 4, {"Y": "yellow", "w": "white", "O": "orange"}, outline="red_d")
        for x in range(2, 14):
            c.set(x, 11 + (x % 3 == 0), "brown" if x % 2 else "brown_d")
        c.line(2, 13, 13, 10, "brown")
        c.line(2, 10, 13, 13, "brown_d")
        for (x, y) in ((1, 14), (4, 15), (8, 15), (12, 15), (14, 14)):
            c.set(x, y, "stone")
            c.set(x + 1, y, "stone_d")
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


def _anim_egg(shell=("red_d", "red", "coral", "peach"), spot: str = "amber") -> list[Anim]:
    """A round dragon egg in its straw that wobbles now and then (6 frames, 14x16)."""
    frames = []
    tilt = [0, 0, 1, 0, -1, 0]
    for f in range(6):
        c = Canvas(14, 16)
        t = tilt[f]
        for y in range(1, 14):
            for x in range(1, 13):
                dx = (x + 0.5 - 7 - t * (13 - y) / 12) / 5.2
                dy = (y + 0.5 - 8.5) / (6.8 if y < 8 else 5.6)
                if dx * dx + dy * dy <= 1:
                    v = -0.6 * dx - 0.7 * dy
                    col = shell[3] if v > 0.55 else (shell[2] if v > 0.05 else (shell[1] if v > -0.5 else shell[0]))
                    c.set(x, y, col)
        for (x, y) in ((6 + t, 6), (9 + t, 9), (5, 11)):
            if c.opaque(x, y):
                c.set(x, y, spot)
        c.outline_all("umber")
        for x in range(0, 14):
            if x % 2 == 0:
                c.set(x, 14, "gold_d")
            c.set(x, 15, "gold" if x % 3 else "brown")
        frames.append(c)
    return [Anim("default", frames, 4.0, True, [6, 1, 1, 1, 1, 6])]


def _anim_tuft(cols=("gold_d", "gold", "gold_l")) -> list[Anim]:
    """Dry grass blades bending in the wind (4 frames, 9x9)."""
    frames = []
    for f in range(4):
        c = Canvas(9, 9)
        lean = [0, 1, 2, 1][f]
        for k, (x, hgt) in enumerate(((1, 6), (3, 8), (5, 7), (7, 5))):
            for y in range(9 - hgt, 9):
                dx = lean if y < 9 - hgt + 3 else (lean // 2 if y < 9 - hgt + 5 else 0)
                c.set(x + dx, y, cols[2] if y < 9 - hgt + 2 else cols[1])
        c.outline_all(cols[0])
        frames.append(c)
    return [Anim("default", frames, 3.0, True)]


def _anim_steam() -> list[Anim]:
    """A wisp of steam curling up off warm water (8 frames, 12x20)."""
    frames = []
    for f in range(8):
        c = Canvas(12, 20)
        for k in range(3):
            t = ((f / 8) + k / 3) % 1.0
            y = 18 - t * 17
            x = 6 + math.sin(t * 6 + k * 2) * 2.5
            r = 1.2 + t * 2.2
            a = int(150 * (1 - t))
            for (px, py) in P.ellipse(x, y, r, r * 0.8):
                if 0 <= px < 12 and 0 <= py < 20:
                    c.set(px, py, P.alpha_px("white", max(30, a)))
        frames.append(c)
    return [Anim("default", frames, 6.0, True)]


def _anim_snow_glint() -> list[Anim]:
    """A tiny sparkle on snow (8 frames, 5x5)."""
    frames = []
    for f in range(8):
        c = Canvas(5, 5)
        if f == 1:
            c.set(2, 2, "white")
        elif f == 2:
            for d in (-1, 0, 1):
                c.set(2 + d, 2, "white")
                c.set(2, 2 + d, "white")
            c.set(2, 2, "sky_l")
        elif f == 3:
            c.set(2, 2, "sky_l")
        frames.append(c)
    return [Anim("default", frames, 9.0, True, [18, 1, 1, 1, 1, 1, 1, 1])]


ANIMS = {
    "foam": (_anim_foam, (48, 9)),
    "wave_crest": (_anim_crest, (12, 4)),
    "gull": (_anim_gull, (24, 14)),
    "kelp": (_anim_kelp, (10, 28)),
    "kelp_gold": (lambda: _anim_kelp(("brown", "gold_d", "gold", "gold_l"), 24), (10, 24)),
    "anemone": (_anim_anemone, (11, 9)),
    "anemone_violet": (lambda: _anim_anemone(("plum", "violet", "lilac")), (11, 9)),
    "bubbles": (_anim_bubbles, (7, 26)),
    "fish_gold": (_anim_fish, (30, 12)),
    "fish_blue": (lambda: _anim_fish(("sky", "sky_l", "water")), (30, 12)),
    "caustic": (_anim_caustic, (16, 8)),
    "helm": (_anim_helm, (17, 17)),
    "flag_pirate": (lambda: _anim_flag_emblem(("navy", "iron", "steel_d"), _fishbone_on_flag, "ink"), (12, 20)),
    "flag_wolf": (lambda: _anim_flag_emblem(("ink", "slate", "ash"), _wolf_on_flag("ink", "red"), "ink"), (12, 20)),
    "flag_wolf_violet": (lambda: _anim_flag_emblem(("plum", "dusk", "violet"), _wolf_on_flag("ink", "lilac"), "ink"),
                         (12, 20)),
    "lantern": (_anim_lantern, (9, 15)),
    "lantern_cyan": (lambda: _anim_lantern(("white", "sky_l", "sky")), (9, 15)),
    "ripple": (_anim_ripple, (13, 5)),
    "ripple_gold": (lambda: _anim_ripple(("gold_l", "peach")), (13, 5)),
    "lava_flow": (_anim_lava_flow, (24, 6)),
    "lava_bubble": (_anim_lava_bubble, (9, 8)),
    "campfire": (_anim_campfire, (16, 16)),
    "egg_red": (_anim_egg, (14, 16)),
    "egg_white": (lambda: _anim_egg(("steel", "steel_l", "white", "white"), "sky"), (14, 16)),
    "tuft_gold": (_anim_tuft, (9, 9)),
    "tuft_snow": (lambda: _anim_tuft(("steel", "steel_l", "white")), (9, 9)),
    "steam": (_anim_steam, (12, 20)),
    "snow_glint": (_anim_snow_glint, (5, 5)),
    "sun_glint": (lambda: AW._anim_water_glint(("white", "gold_l")), (5, 3)),
    "rune_gold": (lambda: K._anim_pulse([".#.", "#+#", ".#.", "#.#"], ("gold_d", "gold_l", "white")), (3, 4)),
    "glint_gold": (lambda: K._anim_glint(("white", "gold_l", "gold")), (9, 9)),
}


def particle_textures() -> dict[str, Canvas]:
    """assets/backgrounds/anim/p_<name>.png (semi-transparent ambient particles)."""
    t: dict[str, Canvas] = {}
    c = Canvas(2, 2)
    c.set(0, 0, "white")
    c.set(1, 0, P.alpha_px("white", 200))
    c.set(0, 1, P.alpha_px("steel_l", 200))
    c.set(1, 1, P.alpha_px("steel_l", 120))
    t["snow"] = c
    c = Canvas(3, 3)
    c.set(1, 1, "white")
    for (x, y) in ((0, 1), (2, 1), (1, 0), (1, 2)):
        c.set(x, y, P.alpha_px("white", 170))
    t["snow_big"] = c
    c = Canvas(4, 4)
    for (x, y) in ((1, 0), (2, 0), (0, 1), (3, 1), (0, 2), (3, 2), (1, 3), (2, 3)):
        c.set(x, y, P.alpha_px("sky_l", 200))
    c.set(1, 1, "white")
    t["bubble"] = c
    c = Canvas(7, 6)
    for (x, y) in P.ellipse(3.5, 3, 3.4, 2.9):
        d = math.hypot(x + 0.5 - 3.5, (y + 0.5 - 3) * 1.2)
        c.set(x, y, P.alpha_px("white", 70 if d > 2 else 110))
    t["steam"] = c
    c = Canvas(3, 2)
    c.set(0, 0, "red")
    c.set(1, 0, "coral")
    c.set(1, 1, "red_d")
    c.set(2, 1, "red")
    t["leaf_red"] = c
    c = Canvas(3, 2)
    c.set(0, 0, "gold_l")
    c.set(1, 0, "gold")
    c.set(1, 1, "gold_d")
    c.set(2, 1, "gold")
    t["leaf_gold"] = c
    c = Canvas(3, 3)
    c.set(1, 0, "white")
    c.set(0, 1, "pink")
    c.set(1, 1, "cream")
    c.set(2, 1, "pink")
    c.set(1, 2, P.alpha_px("pink", 180))
    t["blossom"] = c
    c = Canvas(2, 1)
    c.set(0, 0, P.alpha_px("white", 200))
    c.set(1, 0, P.alpha_px("sky_l", 140))
    t["spray"] = c
    c = Canvas(2, 2)
    c.set(0, 0, P.alpha_px("ash", 200))
    c.set(1, 1, P.alpha_px("fog", 150))
    c.set(1, 0, P.alpha_px("slate", 120))
    t["ash"] = c
    c = Canvas(3, 3)
    c.set(1, 1, "yellow")
    for (x, y) in ((0, 1), (2, 1), (1, 0), (1, 2)):
        c.set(x, y, P.alpha_px("gold_l", 150))
    t["spark_gold"] = c
    c = Canvas(5, 5)
    for (x, y) in P.ellipse(2.5, 2.5, 2.4, 2.4):
        c.set(x, y, P.alpha_px("slate", 110))
    c.set(1, 1, P.alpha_px("ash", 120))
    t["smoke_dark"] = c
    return t


def write_shared() -> None:
    for kind, (fn, size) in ANIMS.items():
        build_sheet("res://assets/backgrounds/anim", kind, fn(), size)
    for kind, tex in particle_textures().items():
        tex.save(res_path("res://assets/backgrounds/anim/p_%s.png" % kind))
