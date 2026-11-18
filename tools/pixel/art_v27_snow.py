"""v2.7 (CW7) chapter 5「紅龍與白龍」: snow and fire, up the mountain that is half white, half red.

    snowfield       5-1  a bright snowy morning: snowy pines, Gawain's rescue hut, the twin mountain far away
    ice_cave        5-2  a blue ice cavern: icicles, a frozen waterfall, warm cracks where salamanders hide
    hot_springs     5-3  a steaming valley: turquoise pools in snowy rocks, a wooden spout, lanterns
    avalanche_pass  5-4  a narrow pass in a snowstorm: cliffs, a heavy cornice, marker poles with pennants
    volcano         5-5  the crater: lava falls and rivers, basalt paving with hot cracks, ash and embers
    dragon_nest     5-6  the summit nest: snow on the white dragon's side, fire on the red one's, eggs, gold
"""

from __future__ import annotations

import math
import random

import art_light as AL
import art_world as AW
import art_v26_kit as K
import art_v26_world as W
import art_v27_kit as K7
import paint as P
from art_world import AX0, AX1, AY0, AY1, IMG_H, IMG_W, fbm, in_arena, name_at
from art_v26_kit import Scene26, dk, lt
from art_v27_kit import MIDX, MIDY
from pixel import Canvas


def twin_mountain(img: Canvas, cx: int, base: int, h: int, half_w: int, seed: int, smoke: bool = True) -> None:
    """The mountain of the two dragons: its left flank under snow (lit, a few blue shadow folds), its right
    flank red rock with glowing lava seams; the boundary wanders down from the summit; smoke at the top."""
    top_y = base - h
    for x in range(cx - half_w, cx + half_w):
        k = abs(x + 0.5 - cx) / half_w
        top = int(base - h * (1 - k) ** 1.15 + (fbm(x, 0, seed, 6, 2) - 0.5) * 4)
        for y in range(top, base):
            depth = (y - top_y) / h
            split = cx + depth * 10 * math.sin(depth * 5 + seed) + (fbm(0, y, seed + 7, 8, 2) - 0.5) * 8
            if x < split:
                col = "white"
                fold = fbm(x * 0.5, y * 1.2, seed + 1, 10, 2)
                if fold > 0.64:
                    col = "steel_l"
                if fold > 0.72 and depth > 0.3:
                    col = "steel"
            else:
                col = "red_d" if x > split + 3 else "wine"
                seam = fbm(x * 0.4, y * 1.6, seed + 2, 7, 2)
                if seam > 0.68:
                    col = "orange" if seam > 0.73 else "red"
            img.set(x, y, col)
        img.set(x, top, "white" if x < cx else "coral")
    if smoke:
        for k in range(6):
            r = 4 + k * 2.2
            sx, sy = cx + k * 5, base - h - 6 - k * 7
            for (x, y) in P.ellipse(sx, sy, r, r * 0.7):
                img.set(x, y, "ash" if (x - sx) > r * 0.2 or y > sy + r * 0.3 else "fog")


def snow_ground(img: Canvas, rect, seed: int, ramp=("fog", "steel_l", "white"), mask=None, scale: float = 50.0) -> None:
    W.textured_floor(img, rect, ramp, seed, scale=scale, mask=mask)


def paw_trail(img: Canvas, pts: list[tuple[int, int]], col: str, only: tuple[str, ...]) -> None:
    for (x, y) in pts:
        for (dx, dy) in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, -1), (2, -1), (0, -2), (1, -2)):
            if name_at(img, x + dx, y + dy) in only:
                img.set(x + dx, y + dy, col)


# ==========================================================================
# 5-1 snowfield
# ==========================================================================

def rescue_hut(seed: int) -> Canvas:
    """Gawain's little mountain rescue hut: log walls, a snowy roof, a lit window, a red cross-less flag."""
    c = Canvas(46, 40)
    for y in range(18, 38):
        for x in range(4, 42):
            col = "brown" if (y - 18) % 4 else "brown_d"
            if x < 8:
                col = "gold_d" if (y - 18) % 4 else "brown"
            if x > 37:
                col = "brown_d"
            c.set(x, y, col)
    c.rect(26, 23, 8, 7, "night_d")
    c.rect(27, 24, 6, 5, "orange")
    c.rect(27, 24, 3, 2, "yellow")
    c.vline(30, 23, 29, "brown_d")
    c.rect(12, 26, 8, 12, "brown_d")
    c.rect(13, 27, 6, 11, "umber")
    c.set(17, 32, "gold_l")
    for k in range(20):
        y = 2 + k
        half = 6 + k * 1.15
        for x in range(int(23 - half), int(23 + half) + 1):
            col = "white" if x < 23 else "steel_l"
            if k > 16:
                col = "steel" if x > 23 else "steel_l"
            c.set(x, y, col)
    c.rect(32, 2, 4, 8, "stone_d")
    c.rect(32, 1, 4, 2, "white")
    c.outline_all("umber")
    return c


def scene_snowfield() -> Scene26:
    """5-1 雪原: a bright snowy morning in the mountains. Snow-laden pines, Gawain's rescue hut with smoke
    curling from its chimney, the twin mountain (white flank, red flank) on the horizon; a soft snow
    clearing with drifts, snowy rocks and paw prints."""
    sc = Scene26("steel_l", 0.4)
    img = sc.img
    K.sky_bands(img, 0, 78, [("sky", 0.0), ("azure", 0.35), ("sky_l", 0.65), ("haze", 0.88)], seed=5101, wave=1.6)
    K.peaks_layer(img, 78, [(30, 26, 50), (100, 18, 46), (260, 28, 54), (310, 20, 40)], "white", "steel_l",
                  rim="white", seed=5102, rough=1.0)
    twin_mountain(img, 176, 80, 58, 60, 5103)
    K.hills_layer(img, 86, 5, 27.0, "steel_l", rim="white", seed=5104, fill_to=100)
    K.treeline(img, 104, ("night", "deep", "forest_d", "teal"), 5105, size=(3.0, 5.0), step=5, pointy=True, jitter=3)
    for x in range(IMG_W):
        for y in range(96, 106):
            n = name_at(img, x, y)
            if n in ("forest_d", "teal") and name_at(img, x, y - 1) not in ("forest_d", "teal", "deep", "night"):
                img.set(x, y, "white")
    # mid: a row of big snowy pines, the rescue hut on the right
    snow_ground(img, (0, 100, IMG_W, IMG_H), 5106)
    rng = random.Random(5107)
    for i, x in enumerate(range(-12, IMG_W, 17)):
        if 200 < x < 250:
            continue
        p = K7.snow_pine(5110 + i, 40 + (i * 7) % 16)
        AW.place(img, p, x, 148 - p.h + (i * 5) % 8, shadow=(0.9, -2), shadow_dx=-5)
    hut = rescue_hut(5108)
    AW.place(img, hut, 206, 112, shadow=(1.0, -2), shadow_dx=-6)
    sc.particle(kind="smoke", amount=6, lifetime=5.0, rect=(176, 18, 180, 22), velocity=(0.3, -1), spread=15,
                speed=(4, 7), gravity=(0, 0), colour_fade=True)
    sc.anim("lantern", 202, 126, 0, 0.6)
    sc.light("lantern", 206, 134, 0.6)
    # the clearing: soft drifts and a few tracks round its edges
    for (x, y, w, h) in ((AX0 - 30, AY0 + 10, 40, 12), (AX1 - 6, AY0 + 60, 44, 12), (AX0 - 34, AY1 - 40, 44, 14),
                         (AX1 - 8, AY1 - 10, 40, 12), (MIDX - 60, AY0 - 6, 36, 9), (MIDX + 30, AY0 - 4, 30, 8)):
        AW.place(img, K7.snow_mound(w, h, x + y), x, y, shadow=(1.0, -1), shadow_dx=-4)
    for (x, y) in ((AX0 + 4, AY0 + 30), (AX1 - 22, AY0 + 6), (AX0 + 2, AY1 - 30), (AX1 - 18, AY1 - 36)):
        AW.place(img, K7.snow_rock(x + y, 14, 8), x, y, shadow=(1.0, -1), shadow_dx=-3)
    # a little frozen pond in the top-left corner of the clearing
    pcx, pcy = AX0 + 22, AY0 + 6
    for y in range(pcy - 9, pcy + 10):
        for x in range(pcx - 24, pcx + 25):
            d = math.hypot((x + 0.5 - pcx) / 22, (y + 0.5 - pcy) / 8) + (fbm(x, y, 5112, 5, 2) - 0.5) * 0.15
            if d < 0.86:
                img.set(x, y, "sky_l" if (x - pcx) + (y - pcy) * 2 < -6 else "azure")
            elif d < 1.0:
                img.set(x, y, "white" if y < pcy else "steel")
    for k in range(3):
        img.line(pcx - 14 + k * 9, pcy - 3 + k, pcx - 9 + k * 9, pcy - 5 + k, "white")
    sc.anim("snow_glint", pcx - 6, pcy - 4, 2, 0.6)
    paw_trail(img, [(AX1 - 10 - k * 8, AY1 + 30 - k * 9 + (k % 2) * 3) for k in range(9)], "steel", ("steel_l", "white"))
    paw_trail(img, [(AX0 - 30 + (k % 2) * 4, AY0 + 40 + k * 12) for k in range(10)], "steel", ("steel_l", "white"))
    K7.scatter_props(img, (AX0 - 40, AY0, AX1 + 40, AY1 + 30), 30, 5109,
                     lambda r: K7.snow_rock(r.randrange(999), r.randrange(4, 7), r.randrange(3, 5)), calm=0.97)
    # sides: young pines, a sledge, a signpost
    for (x, y, h) in ((6, 230, 34), (260, 210, 38), (18, 330, 30), (262, 320, 34), (40, 420, 30), (240, 430, 36)):
        AW.place(img, K7.snow_pine(x + y, h), x, y - h, shadow=(0.9, -2), shadow_dx=-5)
    sledge = Canvas(24, 10)
    for x in range(2, 22):
        sledge.set(x, 3, "brown")
        sledge.set(x, 4, "brown_d")
    for x in (4, 18):
        sledge.vline(x, 5, 7, "brown_d")
    sledge.hline(1, 22, 8, "steel")
    sledge.set(0, 7, "steel")
    sledge.outline_all("umber")
    AW.place(img, sledge, 22, 280, shadow=(1.0, -1), shadow_dx=-3)
    sign = K7.snow_cap(AW.signpost(), 1, 5)
    AW.place(img, sign, 270, 270, shadow=(0.8, -1))
    # bottom: a snowy rise with pines
    for i, x in enumerate(range(-14, IMG_W, 18)):
        p = K7.snow_pine(5120 + i, 36 + (i * 5) % 12)
        AW.place(img, p, x, 446 - p.h + 30 + (i * 7) % 10, shadow=None)
    # foreground: snowy pine boughs in the top corners, drifts at the bottom
    for side in (0, 1):
        br = AL.pine_branch(66, 40, 5130 + side, side == 1)
        K7.snow_cap(br, 1, 5131 + side, skip=("ink",))
        sc.put_fg(br, 30 if side == 0 else IMG_W - 96, 80)
    AL.clumps(sc.fg, 5132, ("steel", "steel_l", "white", "white"), "steel", gap=(16, 34))
    for i, (x, y) in enumerate(((AX0 - 8, AY0 + 20), (AX1 + 4, AY0 + 140), (AX0 - 10, AY1 - 10), (AX1 + 2, AY1 + 10))):
        sc.anim("tuft_snow", x, y, i % 4, 0.8)
    for i, (x, y) in enumerate(((AX0 + 20, AY0 + 40), (AX1 - 30, AY0 + 120), (AX0 + 40, AY1 - 20), (AX1 - 50, AY1 - 60),
                                (MIDX, AY0 + 10), (30, 300), (276, 360))):
        sc.anim("snow_glint", x, y, i, 0.6 + (i % 3) * 0.1)
    sc.light("sun", 40, 20, 1.0, tint=(1.0, 0.97, 0.9))
    sc.particle(kind="snow", amount=26, lifetime=7.0, rect=(-40, -80, 220, 320), velocity=(0.3, 1), spread=15,
                speed=(8, 14), gravity=(0, 1), colour_fade=True)
    sc.particle(kind="snow_big", amount=8, lifetime=6.0, rect=(-40, -80, 220, 320), velocity=(0.3, 1), spread=15,
                speed=(12, 18), gravity=(0, 1), colour_fade=True)
    sc.modulate = (0.97, 0.98, 1.0)
    return sc


# ==========================================================================
# 5-2 ice_cave
# ==========================================================================

def scene_ice_cave() -> Scene26:
    """5-2 冰之洞窟: a blue ice cavern. Walls of glacier ice and icicles, a frozen waterfall with glints,
    cracked ice plates for a floor (slippery and calm), little orange cracks glowing where the
    salamanders keep warm."""
    sc = Scene26("azure", 0.55)
    img = sc.img
    K7.fill_rect(img, (0, 0, IMG_W, 170), "night")
    AW.paint_ground(img, (0, 0, IMG_W, 90), ("night_d", "night", "water_d"), 5201, scale=26, tufts=0.0,
                    max_light=0.12, max_dark=0.2)
    # back wall: tiers of glacier ice blocks
    rng = random.Random(5202)
    for row, y0 in enumerate((40, 74, 108)):
        x = -12 + row * 10
        while x < IMG_W + 10:
            w = rng.randrange(22, 36) - row * 3
            h = rng.randrange(26, 38) - row * 4
            ramp = (("water_d", "water", "sky", "azure") if row < 2 else ("water", "sky", "azure", "sky_l"))
            blk = K7.ice_block(w, h, x + row * 77, ramp, "night")
            img.blit(blk, int(x), y0 + rng.randrange(0, 8))
            x += w - rng.randrange(2, 8)
    # the frozen waterfall (centre top) and its pool
    for y in range(20, 152):
        for x in range(MIDX - 16, MIDX + 16):
            u = (x + 0.5 - (MIDX - 16)) / 32
            wob = math.sin(y * 0.3 + x * 0.7) * 0.08
            col = "sky_l" if u + wob < 0.25 else ("azure" if u + wob < 0.6 else ("sky" if u + wob < 0.85 else "water"))
            if (x * 3 + y // 5) % 11 == 0:
                col = "white"
            img.set(x, y, col)
    for y in range(20, 152):
        img.set(MIDX - 17, y, "water_d")
        img.set(MIDX + 16, y, "water_d")
    K7.icicles(img, 0, IMG_W, 0, 5203, max_len=14)
    for x in range(0, IMG_W, 3):
        img.set(x, 0, "sky_l")
    # warm cracks in the walls: salamanders keeping warm
    for (x, y) in ((40, 120), (250, 100), (96, 136), (214, 130)):
        K7.glow_crack(img, x, y, 10, x + y)
        sc.light("lantern", x + 2, y + 2, 0.45, tint=(1.0, 0.6, 0.3))
    # floor: cracked ice plates, frost drifts round the edge
    K7.voronoi_stones(img, (0, 150, IMG_W, IMG_H), 27, ("azure", "azure"), "sky_l", 5204, squash=0.75)
    for (x, y) in ((AX0 + 8, AY0 + 70), (AX1 - 14, AY0 + 150), (AX0 + 14, AY1 - 30), (AX1 - 20, AY0 + 20)):
        K7.glow_crack(img, x, y, 9, x * 7 + y)
        sc.light("lantern", x + 2, y + 1, 0.4, tint=(1.0, 0.6, 0.3))
    rng = random.Random(5205)
    for _ in range(46):
        x, y = rng.randrange(0, IMG_W - 12), rng.randrange(156, IMG_H)
        if rng.random() < W.calm_k(x, y) * 0.9:
            continue
        ln = rng.randrange(4, 10)
        for k in range(ln):
            if name_at(img, x + k, y - k // 2) == "azure":
                img.set(x + k, y - k // 2, "sky_l" if k < ln - 2 else "white")
    for y in range(150, IMG_H):
        for x in range(IMG_W):
            k2 = W.calm_k(x, y, 34)
            n = fbm(x, y, 5206, 18, 3) + AW._cluster(x, y, 5206) * 0.06
            if n > 0.58 + k2 * 0.35:
                img.set(x, y, "white" if n > 0.66 + k2 * 0.35 else "steel_l")
    K.edge_shadow(img, 150, 6, 0, IMG_W)
    K.calm_vignette(img, 10)
    # ice crystals and blocks round the edges, a frozen chest, a stuck snowball pile
    for (x, y, h) in ((AX0 - 30, AY0 + 30, 26), (AX1 + 4, AY0 + 10, 30), (AX0 - 26, AY1 - 50, 22), (AX1 + 6, AY1 - 40, 28),
                      (AX0 + 2, AY0 - 6, 14), (AX1 - 16, AY1 - 8, 16)):
        for k in range(3):
            cr = K.crystal(h - k * 5, x + k, ("water", "sky", "azure", "sky_l"), "water_d", lean=(k - 1) * 0.2)
            AW.place(img, cr, x + k * 7, y - cr.h, shadow=(0.8, -1), shadow_dx=2)
    for (x, y) in ((14, 300), (262, 260), (24, 400), (250, 410)):
        AW.place(img, K7.ice_block(24, 20, x + y), x, y, shadow=(1.0, -1), shadow_dx=3)
    # bottom: more ice wall
    rng = random.Random(5207)
    x = -10
    while x < IMG_W:
        w = rng.randrange(24, 36)
        blk = K7.ice_block(w, rng.randrange(30, 44), x * 3, ("water_d", "water", "sky", "azure"), "night")
        img.blit(blk, x, 412 + rng.randrange(0, 10))
        x += w - 6
    # foreground: dark ice in the top corners, icicles, ice shards at the bottom
    for side in (0, 1):
        blk = K7.ice_block(46, 44, 5210 + side, ("night_d", "night", "water_d", "water"), "navy")
        sc.put_fg(blk.flipped() if side else blk, 44 if side == 0 else IMG_W - 90, 80)
    for k, x in enumerate((-2, 30, 230, 262)):
        cr = K.crystal(30 + k * 3, k, ("night", "water_d", "water", "sky"), "navy", lean=(k - 1.5) * 0.15)
        sc.put_fg(cr, x, 430 - cr.h + 20)
    for i, (x, y) in enumerate(((MIDX - 10, 40), (MIDX + 6, 90), (MIDX - 4, 130), (40, 70), (260, 60), (120, 100),
                                (190, 116))):
        sc.anim("glint_cyan", x, y, i * 2, 0.6 + (i % 3) * 0.1)
    for i, (x, y) in enumerate(((AX0 + 20, AY0 + 40), (AX1 - 30, AY0 + 120), (AX0 + 40, AY1 - 20), (AX1 - 50, AY1 - 60),
                                (MIDX, AY0 + 20))):
        sc.anim("snow_glint", x, y, i, 0.6)
    sc.light("magic", MIDX, 80, 0.8, tint=(0.5, 0.9, 1.0))
    for (x, y) in ((30, 60), (270, 50)):
        sc.light("magic", x, y, 0.5, tint=(0.5, 0.9, 1.0))
    sc.particle(kind="drip", amount=6, lifetime=1.2, rect=(-20, -86, 200, -80), velocity=(0, 1), spread=0,
                speed=(30, 40), gravity=(0, 60), colour_fade=True)
    sc.particle(glow=True, kind="spark_cyan", amount=10, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(1, 3), gravity=(0, 0), blink=True)
    sc.particle(kind="snow", amount=10, lifetime=6.0, rect=(-10, -40, 200, 380), velocity=(0.2, 1), spread=40,
                speed=(2, 5), gravity=(0, 0), colour_fade=True)
    sc.modulate = (0.88, 0.93, 1.0)
    return sc


# ==========================================================================
# 5-3 hot_springs
# ==========================================================================

def spring_pool(img: Canvas, cx: float, cy: float, rx: float, ry: float, seed: int) -> None:
    """A steaming pool: turquoise water (lighter towards the far edge), a rim of dark wet rocks with
    snow on their tops."""
    for y in range(int(cy - ry) - 4, int(cy + ry) + 5):
        for x in range(int(cx - rx) - 4, int(cx + rx) + 5):
            d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry) + (fbm(x, y, seed, 8, 2) - 0.5) * 0.16
            if d < 0.86:
                col = "azure" if y < cy - ry * 0.35 else ("sky" if y < cy + ry * 0.3 else "water")
                img.set(x, y, col)
            elif d < 1.0:
                img.set(x, y, "slate" if y > cy else "stone_d")
    rng = random.Random(seed)
    for k in range(int(rx * 0.7)):
        a = rng.uniform(0, 2 * math.pi)
        x = int(cx + math.cos(a) * rx * 0.98) - 4
        y = int(cy + math.sin(a) * ry * 0.98) - 3
        img.blit(K7.snow_rock(seed + k, rng.randrange(6, 11), rng.randrange(4, 7), ("slate", "stone_d", "stone", "stone_l")),
                 x, y)


def scene_hot_springs() -> Scene26:
    """5-3 溫泉谷: a warm valley between snowy slopes. Steaming turquoise pools in snow-capped rocks, a
    wooden spout pouring hot water, stone lanterns; the wet stone floor has melted clear of snow in the
    middle."""
    sc = Scene26("stone", 0.45)
    img = sc.img
    K.sky_bands(img, 0, 60, [("azure", 0.0), ("sky_l", 0.5), ("haze", 0.85)], seed=5301)
    K.peaks_layer(img, 70, [(40, 34, 60), (170, 40, 64), (280, 30, 50)], "white", "steel_l", rim="white", seed=5302)
    # the snowy slope above the valley, pines
    for x in range(IMG_W):
        top = int(70 + 6 * math.sin(x / 31.0) + 3 * math.sin(x / 9.0))
        for y in range(top, 150):
            img.set(x, y, "white" if y < top + 2 else ("steel_l" if fbm(x, y, 5303, 16, 2) > 0.45 else "fog"))
    for i, x in enumerate(range(-10, IMG_W, 23)):
        p = K7.snow_pine(5304 + i, 30 + (i * 7) % 14)
        img.blit(p, x, 100 - p.h + (i * 5) % 10)
    # the rocky terrace at the top with the spout and the upper pool
    K7.reef_wall(img, lambda x: 112 + 4 * math.sin(x / 13.0), 162, 5305, ("slate", "stone_d", "stone", "stone_l"), "iron")
    for x in range(IMG_W):
        for y in range(108, 130):
            if name_at(img, x, y) in ("stone_l",) and name_at(img, x, y - 1) in (None, "steel_l", "fog", "white"):
                img.set(x, y, "white")
    spring_pool(img, MIDX, 140, 42, 12, 5306)
    # wooden spout and its stream into the upper pool
    img.rect(MIDX + 10, 114, 26, 4, "brown")
    img.hline(MIDX + 10, MIDX + 35, 114, "gold_d")
    img.vline(MIDX + 34, 112, 126, "brown_d")
    sc.anim("waterfall", MIDX + 6, 116, 0, 1.0)
    # floor: wet stones, a bit of snow still lying at the edges
    K7.voronoi_stones(img, (0, 156, IMG_W, IMG_H), 17, ("stone", "stone"), "stone_d", 5307, squash=0.8,
                      mask=lambda x, y: y > 156 and name_at(img, x, y) not in ("azure", "sky", "water", "slate"))
    for y in range(156, IMG_H):
        for x in range(IMG_W):
            if name_at(img, x, y) not in ("stone", "stone_d"):
                continue
            k2 = W.calm_k(x, y, 40)
            n = fbm(x, y, 5308, 20, 3) + AW._cluster(x, y, 5308) * 0.06
            if n > 0.57 + k2 * 0.35:
                img.set(x, y, "white" if n > 0.65 + k2 * 0.35 else "steel_l")
    K.edge_shadow(img, 160, 6)
    K.calm_vignette(img, 10)
    # pools at the sides and the bottom
    for (cx, cy, rx, ry) in ((AX0 + 2, AY0 + 64, 24, 12), (AX1 - 2, AY1 - 76, 24, 12), (20, 350, 20, 10),
                             (MIDX, AY1 + 16, 50, 10)):
        spring_pool(img, cx, cy, rx, ry, int(cx * 3 + cy))
        for k in range(2):
            sc.anim("ripple", int(cx - rx * 0.4 + k * rx * 0.5), int(cy - 2 + k * 3), k * 3, 0.7)
        sc.anim("steam", int(cx - 8), int(cy - 24), int(cx) % 8, 0.6)
        sc.anim("steam", int(cx + 4), int(cy - 22), int(cx + 3) % 8, 0.5)
    # stone lanterns, a bucket, towels on a rail
    for (x, y) in ((AX0 + 2, AY0 + 2), (AX1 - 14, AY0 + 2), (AX0 + 2, AY1 - 26), (AX1 - 14, AY1 - 26)):
        lan = Canvas(12, 22)
        lan.rect(3, 14, 6, 7, "stone")
        lan.rect(1, 6, 10, 8, "stone_d")
        lan.rect(3, 8, 6, 4, "orange")
        lan.rect(3, 8, 3, 2, "yellow")
        lan.rect(0, 3, 12, 3, "stone_l")
        lan.rect(4, 0, 4, 3, "stone")
        K7.snow_cap(lan, 1, x)
        lan.outline_all("iron")
        AW.place(img, lan, x, y, shadow=(1.0, -1), shadow_dx=3)
        sc.light("lantern", x + 6, y + 10, 0.6)
    bucket = Canvas(10, 9)
    for yy in range(2, 9):
        for xx in range(1, 9):
            bucket.set(xx, yy, "gold_d" if xx < 4 else "brown")
    bucket.hline(1, 8, 4, "iron")
    bucket.hline(1, 8, 2, "gold")
    bucket.outline_all("umber")
    AW.place(img, bucket, AX0 + 18, AY1 - 14, shadow=(1.0, -1), shadow_dx=2)
    rail = Canvas(30, 16)
    rail.vline(2, 2, 15, "brown_d")
    rail.vline(27, 2, 15, "brown_d")
    rail.hline(1, 28, 3, "brown")
    for (x0, col) in ((5, "white"), (13, "sky"), (20, "pink")):
        rail.rect(x0, 4, 6, 7, col)
        rail.vline(x0 + 5, 4, 10, dk(col))
    rail.outline_all("umber")
    AW.place(img, rail, 256, 330, shadow=(1.0, -1), shadow_dx=3)
    for (x, y) in ((AX1 - 24, AY0 + 30), (AX0 + 4, AY0 + 130), (AX1 - 20, AY1 - 40)):
        AW.place(img, K7.snow_rock(x + y, 16, 9), x, y, shadow=(1.0, -1), shadow_dx=3)
    # foreground: snowy rocks and pines at the bottom, snowy boughs in the top corners
    for side in (0, 1):
        br = AL.pine_branch(66, 40, 5330 + side, side == 1)
        K7.snow_cap(br, 1, 5331 + side, skip=("ink",))
        sc.put_fg(br, 30 if side == 0 else IMG_W - 96, 80)
    for k, x in enumerate((-6, 28, 234, 268)):
        sc.put_fg(K7.snow_rock(5340 + k, 30, 18), x, 398 + (k % 2) * 6)
    sc.light("sun", 220, 20, 0.9, tint=(1.0, 0.95, 0.85))
    sc.particle(kind="steam", amount=16, lifetime=5.0, rect=(-40, 40, 220, 330), velocity=(0.2, -1), spread=20,
                speed=(4, 8), gravity=(0, -1), colour_fade=True, grow=True)
    sc.particle(kind="snow", amount=16, lifetime=7.0, rect=(-40, -80, 220, 320), velocity=(0.3, 1), spread=15,
                speed=(6, 10), gravity=(0, 1), colour_fade=True)
    sc.modulate = (1.0, 0.98, 0.96)
    return sc


# ==========================================================================
# 5-4 avalanche_pass
# ==========================================================================

def scene_avalanche_pass() -> Scene26:
    """5-4 雪崩山道: a narrow mountain pass in a snowstorm, late in a grey afternoon. Dark cliffs close in
    on both sides under heavy snow ledges; a great cornice hangs over the far end; red pennants on
    marker poles show the path; boulders that came down with the last avalanche."""
    sc = Scene26("fog", 0.5)
    img = sc.img
    K.sky_bands(img, 0, 70, [("ash", 0.0), ("fog", 0.4), ("steel_l", 0.8)], seed=5401, wave=2.0)
    K.peaks_layer(img, 80, [(MIDX - 30, 40, 40), (MIDX + 26, 34, 36)], "steel_l", "fog", rim="white", seed=5402)
    # cliffs converging on the pass: heaps of dark boulders with snow on their tops, narrowing upwards
    def cliff_l(y: float) -> float:
        return 70 + max(0.0, 170 - y) * 0.42 + 3 * math.sin(y / 9.0)

    def cliff_r(y: float) -> float:
        return 234 - max(0.0, 170 - y) * 0.42 + 3 * math.sin(y / 11.0 + 2)

    for y in range(40, 300):
        for x in range(IMG_W):
            if x < cliff_l(y) or x > cliff_r(y):
                img.set(x, y, "iron" if (x < cliff_l(y) - 10 or x > cliff_r(y) + 10) else "slate")
    rng0 = random.Random(5403)
    for y in range(40, 300, 9):
        for side in (0, 1):
            edge = cliff_l(y) if side == 0 else cliff_r(y)
            x = edge - rng0.randrange(14, 24) if side == 0 else edge - rng0.randrange(0, 8)
            while (x < edge + 6) if side == 0 else (x < IMG_W + 10):
                if side == 0 and x < -20:
                    x += 14
                    continue
                w = rng0.randrange(12, 30)
                h = rng0.randrange(8, 17)
                if side == 1 and x > IMG_W:
                    break
                rk = K7.snow_rock(int(x * 7 + y), w, h, ("ink", "iron", "slate", "ash"), "ink")
                img.blit(rk, int(x), y - h // 2)
                x += w - 3
                if side == 0 and x > edge:
                    break
            if side == 0:
                xx = -20
                while xx < cliff_l(y) - 18:
                    w = rng0.randrange(14, 24)
                    rk = K7.snow_rock(int(xx * 5 + y), w, rng0.randrange(9, 13), ("ink", "iron", "slate", "ash"), "ink")
                    img.blit(rk, int(xx), y - 6)
                    xx += w - 3
    # the cornice over the far end of the pass, icicles under its lip
    for x in range(30, 280):
        k = (x - 30) / 250
        bottom = 90 + 9 * math.sin(k * math.pi) + 3 * math.sin(x / 7.0) + 2 * math.sin(x / 2.7)
        top = 46 + 4 * math.sin(x / 13.0)
        for y in range(int(top), int(bottom)):
            img.set(x, y, "white" if y < bottom - 5 else ("steel_l" if y < bottom - 2 else "steel"))
        img.set(x, int(top), "steel_l")
    K7.icicles(img, 50, 260, 96, 5404, ("steel_l", "white", "white"), 7)
    # the path: packed snow, wind-swept, calm in the middle
    snow_ground(img, (0, 96, IMG_W, IMG_H), 5405, ("ash", "fog", "steel_l"),
                mask=lambda x, y: y >= 300 or cliff_l(y) <= x <= cliff_r(y))
    for x in range(IMG_W):
        for y in range(96, 150):
            if cliff_l(y) <= x <= cliff_r(y) and name_at(img, x, y) == "fog" and fbm(x, y, 5407, 14, 2) > 0.38 + (y - 96) / 140:
                img.set(x, y, "steel_l")
    rng = random.Random(5406)
    for _ in range(80):
        x, y = rng.randrange(0, IMG_W - 14), rng.randrange(150, IMG_H)
        if rng.random() < W.calm_k(x, y) * 0.95 or name_at(img, x, y) not in ("fog", "steel_l"):
            continue
        for k in range(rng.randrange(6, 14)):
            if name_at(img, x + k, y) in ("fog", "steel_l"):
                img.set(x + k, y, "steel_l" if name_at(img, x + k, y) == "fog" else "white")
    # boulders from the last avalanche, snow piles against the cliffs
    for (x, y, w, h) in ((AX0 - 26, AY0 + 30, 26, 16), (AX1 + 2, AY0 + 80, 24, 14), (AX0 - 20, AY1 - 50, 22, 14),
                         (AX1 - 2, AY1 - 20, 26, 15), (AX0 + 2, AY0 + 2, 16, 10), (AX1 - 20, AY0 - 2, 14, 9)):
        AW.place(img, K7.snow_rock(x + y, w, h, ("iron", "slate", "ash", "fog")), x, y, shadow=(1.0, -1), shadow_dx=4)
    for (x, y, w, h) in ((AX0 - 40, AY0 + 120, 46, 14), (AX1 - 8, AY0 + 170, 48, 14), (MIDX - 70, AY1 + 6, 50, 12)):
        AW.place(img, K7.snow_mound(w, h, x + y, ("fog", "steel_l", "white")), x, y, shadow=(1.0, -1), shadow_dx=4)
    # marker poles with red pennants along the path
    poles = ((AX0 + 20, AY0 - 22), (AX1 - 24, AY0 - 22), (AX0 + 4, AY0 + 100), (AX1 - 8, AY0 + 140),
             (AX0 + 4, AY1 - 6), (AX1 - 8, AY1 + 4))
    for i, (x, y) in enumerate(poles):
        for yy in range(y, y + 26):
            img.set(x, yy, "red" if (yy - y) // 4 % 2 else "white")
            img.set(x + 1, yy, "red_d" if (yy - y) // 4 % 2 else "steel_l")
        AW.place(img, Canvas(2, 1), x, y + 25, shadow=(2.0, 0), shadow_dx=1)
        sc.anim("pennant_red", x + 1, y - 2, i % 4, 1.4)
    # bottom: the pass falls away to a misty valley
    for y in range(AY1 + 34, IMG_H):
        for x in range(IMG_W):
            img.set(x, y, "steel_l" if y < AY1 + 40 else ("fog" if y < AY1 + 60 else "ash"))
    for i, x in enumerate(range(-14, IMG_W, 18)):
        p = K7.snow_pine(5410 + i, 34 + (i * 5) % 12, ("navy", "night_d", "night"), snow=("fog", "steel_l"))
        img.blit(p, x, AY1 + 92 - p.h + (i * 7) % 10)
    # foreground: dark rock and snow in the corners
    for side in (0, 1):
        rk = K7.snow_rock(5420 + side, 40, 30, ("ink", "iron", "slate", "ash"), "ink")
        sc.put_fg(rk.flipped() if side else rk, 40 if side == 0 else IMG_W - 80, 82)
    for k, x in enumerate((-6, 26, 236, 266)):
        sc.put_fg(K7.snow_mound(40, 16, 5430 + k, ("fog", "steel_l", "white"), "steel"), x, 400 + (k % 2) * 4)
    for i, (x, y) in enumerate(((AX0 - 8, AY0 + 50), (AX1 + 4, AY0 + 30), (AX0 - 10, AY1 - 30), (AX1 + 2, AY1 - 60))):
        sc.anim("tuft_snow", x, y, i % 4, 1.2)
    sc.light("sun", MIDX, 30, 0.5, tint=(0.85, 0.9, 1.0))
    sc.particle(kind="snow", amount=40, lifetime=4.0, rect=(-80, -90, 200, 330), velocity=(1, 0.8), spread=12,
                speed=(30, 44), gravity=(0, 4), colour_fade=True)
    sc.particle(kind="snow_big", amount=18, lifetime=4.0, rect=(-80, -90, 200, 330), velocity=(1, 0.9), spread=12,
                speed=(36, 50), gravity=(0, 4), colour_fade=True)
    sc.particle(kind="mist", amount=8, lifetime=6.0, rect=(-60, -40, 240, 340), velocity=(1, 0.1), spread=8,
                speed=(16, 24), gravity=(0, 0), colour_fade=True)
    sc.modulate = (0.94, 0.95, 1.0)
    return sc


# ==========================================================================
# 5-5 volcano
# ==========================================================================

def scene_volcano() -> Scene26:
    """5-5 火山口: the crater of the red dragon's mountain. Lava pours down the far wall into a glowing river,
    smoke rolls across a red sky; the floor is cracked basalt with hot seams at its edges; lava pools
    bubble at the sides; embers and ash drift."""
    sc = Scene26("stone_d", 0.55)
    img = sc.img
    K.sky_bands(img, 0, 80, [("wine", 0.0), ("red_d", 0.35), ("coral", 0.7), ("orange", 0.9)], seed=5501, wave=2.0)
    for k, (cx, cy, r) in enumerate(((60, 24, 18), (110, 14, 22), (180, 20, 20), (250, 26, 16))):
        for (x, y) in P.ellipse(cx, cy, r * 1.5, r * 0.7):
            img.set(x, y, "plum" if y > cy else "wine")
    # the crater wall with lava falls
    K7.reef_wall(img, lambda x: 66 + 8 * math.sin(x / 23.0) + 4 * math.sin(x / 7.0), 150, 5502,
                 ("ink", "slate", "stone_d", "ash"), "ink")
    for (x, w) in ((70, 7), (196, 9), (250, 6)):
        for y in range(70, 140):
            for xx in range(x, x + w):
                u = (xx - x) / (w - 1)
                img.set(xx, y, "yellow" if 0.3 < u < 0.6 else ("amber" if 0.15 < u < 0.85 else "orange"))
        sc.anim("lava_flow", x - 8, 100, (x // 7) % 6, 1.0)
    # the lava river across the top of the arena
    K7.lava_river(img, [(-10, 146), (60, 142), (130, 148), (200, 140), (320, 146)], 12, 5503)
    for (x, y) in ((40, 140), (110, 142), (180, 138), (250, 140)):
        sc.anim("lava_flow", x, y, (x // 9) % 6, 0.8)
    # a stone bridge over it in the middle
    for y in range(132, 158):
        for x in range(MIDX - 14, MIDX + 14):
            img.set(x, y, "stone" if x < MIDX - 8 else ("stone_d" if x < MIDX + 9 else "slate"))
            if y % 6 == 5:
                img.set(x, y, "slate")
        img.set(MIDX - 15, y, "ink")
        img.set(MIDX + 14, y, "ink")
    # floor: basalt paving with ash, hot seams near the edges
    K7.voronoi_stones(img, (0, 156, IMG_W, IMG_H), 16, ("stone_d", "stone_d"), "slate", 5504, squash=0.85,
                      mask=lambda x, y: y > 154 and name_at(img, x, y) not in LAVA_NAMES)
    for y in range(156, IMG_H):
        for x in range(IMG_W):
            if name_at(img, x, y) not in ("stone_d",):
                continue
            k2 = W.calm_k(x, y, 40)
            n = fbm(x, y, 5505, 20, 3) + AW._cluster(x, y, 5505) * 0.06
            if n > 0.57 + k2 * 0.35:
                img.set(x, y, "ash" if n > 0.65 + k2 * 0.35 else "stone")
    rng = random.Random(5506)
    for k in range(40):
        x, y = rng.randrange(AX0 - 20, AX1 + 20), rng.randrange(AY0, AY1 + 30)
        if W.calm_k(x, y) > 0.5:
            continue
        K7.glow_crack(img, x, y, rng.randrange(8, 18), 5507 + k)
    K.edge_shadow(img, 158, 5)
    K.calm_vignette(img, 10)
    # lava pools at the sides with bubbles, basalt boulders, obsidian, sulfur
    for (cx, cy, rx, ry) in ((AX0 + 2, AY0 + 80, 20, 10), (AX1 - 2, AY1 - 70, 20, 10), (30, 360, 18, 9)):
        K7.lava_pool(img, cx, cy, rx, ry, int(cx + cy))
        sc.anim("lava_bubble", int(cx - 6), int(cy - 6), int(cx) % 6, 0.8)
        sc.anim("lava_bubble", int(cx + 4), int(cy - 2), int(cy) % 6, 0.7)
        sc.light("torch", cx, cy, 0.8)
    for (x, y, w, h) in ((AX0 - 24, AY0 + 30, 22, 14), (AX1 + 2, AY0 + 70, 20, 13), (AX0 - 20, AY1 - 40, 20, 12),
                         (AX1 - 4, AY1 - 30, 22, 14), (AX0 + 2, AY0 + 4, 14, 9), (AX1 - 18, AY0 + 2, 14, 8)):
        AW.place(img, K7.basalt(x + y, w, h, glow=(x + y) % 2 == 0), x, y, shadow=(1.0, -1), shadow_dx=3)
    for (x, y) in ((AX0 - 30, AY0 + 160), (AX1 + 8, AY0 + 200), (250, 210)):
        for k in range(3):
            cr = K.crystal(14 + k * 4, x + k, ("ink", "plum", "violet", "lilac"), "ink", lean=(k - 1) * 0.2)
            AW.place(img, cr, x + k * 6, y - cr.h, shadow=(0.8, -1), shadow_dx=2)
    for (x, y) in ((AX0 + 10, AY1 - 10), (AX1 - 30, AY0 + 40), (24, 300)):
        for (dx, dy) in ((0, 0), (1, 0), (2, 1), (-1, 1), (0, 1), (1, 1), (3, 1)):
            img.set(x + dx, y + dy, "yellow" if dy == 0 else "gold")
    # bottom: another lava river and dark rocks
    K7.lava_river(img, [(-10, AY1 + 40), (80, AY1 + 46), (170, AY1 + 38), (320, AY1 + 44)], 14, 5508)
    for (x, y) in ((20, AY1 + 38), (120, AY1 + 42), (220, AY1 + 36)):
        sc.anim("lava_flow", x, y, (x // 9) % 6, 0.9)
    K7.reef_wall(img, lambda x: AY1 + 54 + 4 * math.sin(x / 11.0), IMG_H, 5509, ("ink", "slate", "stone_d", "ash"), "ink")
    # foreground: dark basalt in the corners and at the bottom
    for side in (0, 1):
        rk = K7.basalt(5510 + side, 40, 30, ("ink", "ink", "slate", "stone_d"), True)
        sc.put_fg(rk.flipped() if side else rk, 44 if side == 0 else IMG_W - 86, 84)
    for k, x in enumerate((-6, 26, 236, 266)):
        sc.put_fg(K7.basalt(5520 + k, 34, 22, ("ink", "ink", "slate", "stone_d"), k % 2 == 0), x, 398 + (k % 2) * 6)
    sc.light("torch", MIDX, 146, 1.4)
    for (x, y) in ((70, 120), (200, 120), (MIDX - 60, AY1 + 42), (MIDX + 60, AY1 + 40)):
        sc.light("torch", x, y, 1.0)
    sc.particle(kind="ember", amount=22, lifetime=3.0, rect=(-40, 40, 220, 340), velocity=(0.2, -1), spread=30,
                speed=(8, 16), gravity=(0, -3), colour_fade=True)
    sc.particle(kind="ash", amount=14, lifetime=6.0, rect=(-40, -80, 220, 320), velocity=(0.5, 1), spread=30,
                speed=(4, 8), gravity=(0, 1), colour_fade=True)
    sc.particle(kind="smoke_dark", amount=8, lifetime=6.0, rect=(-60, -80, 240, -30), velocity=(1, -0.2), spread=10,
                speed=(6, 10), gravity=(0, 0), colour_fade=True, grow=True)
    sc.modulate = (1.0, 0.93, 0.88)
    return sc


LAVA_NAMES = ("yellow", "amber", "orange", "red", "red_d", "ink", "slate")


# ==========================================================================
# 5-6 dragon_nest
# ==========================================================================

def scene_dragon_nest() -> Scene26:
    """5-6 雙龍之巢: the summit where the two dragons nest, half in the white dragon's snow, half in the
    red dragon's fire. A ring of huge twigs and rocks, snowy ice ridges on the left, a smoking lava
    ridge on the right, gold and gems in the straw, an egg on each side."""
    sc = Scene26("stone", 0.5)
    img = sc.img
    for y in range(0, 90):
        for x in range(IMG_W):
            t = y / 90 + 0.06 * math.sin(x / 13.0 + y * 0.07)
            u = (x - MIDX) / IMG_W + 0.08 * math.sin(y / 9.0)
            if u < 0:
                col = "sky" if t < 0.3 else ("azure" if t < 0.6 else "sky_l")
            else:
                col = "red_d" if t < 0.3 else ("coral" if t < 0.6 else "peach")
            img.set(x, y, col)
    for (cx, cy, r) in ((60, 30, 16), (100, 18, 12)):
        for (x, y) in P.ellipse(cx, cy, r * 1.6, r * 0.6):
            img.set(x, y, "white" if y < cy else "sky_l")
    for (cx, cy, r) in ((220, 24, 16), (270, 40, 14)):
        for (x, y) in P.ellipse(cx, cy, r * 1.6, r * 0.6):
            img.set(x, y, "plum" if y > cy else "wine")
    # the twin ridges: ice (left), lava (right)
    for x in range(IMG_W):
        top = int(62 + 10 * math.sin(x / 21.0) + 5 * math.sin(x / 7.0))
        for y in range(top, 160):
            if x < MIDX:
                n = fbm(x * 0.6, y * 0.3, 5601, 8, 2)
                col = "white" if n > 0.58 else ("steel_l" if n > 0.4 else "steel")
            else:
                n = fbm(x * 0.6, y * 0.3, 5602, 8, 2)
                col = "stone_d" if n > 0.58 else ("slate" if n > 0.4 else "iron")
                if n > 0.66 and y % 3 == 0:
                    col = "orange"
            img.set(x, y, col)
        img.set(x, top, "white" if x < MIDX else "coral")
    for (x, h) in ((30, 30), (60, 40), (100, 26)):
        for k in range(2):
            cr = K.crystal(h - k * 8, x + k, ("water", "sky", "azure", "sky_l"), "water_d", lean=(k - 0.5) * 0.3)
            img.blit(cr, x + k * 10, 120 - cr.h)
    K7.icicles(img, 0, MIDX - 10, 150, 5603, max_len=8)
    K7.lava_river(img, [(MIDX + 30, 70), (MIDX + 50, 110), (MIDX + 40, 150)], 8, 5604)
    K7.lava_river(img, [(270, 80), (262, 120), (275, 152)], 7, 5605)
    sc.anim("lava_flow", MIDX + 34, 110, 0, 1.0)
    # the nest: summit rock floor (snowy left, warm rock right) inside a ring of huge twigs
    def side_mix(x: int, y: int) -> float:
        return (x - MIDX) / 18.0 + (fbm(x, y, 5606, 30, 2) - 0.5) * 2.4

    for y in range(150, IMG_H):
        for x in range(IMG_W):
            s = side_mix(x, y)
            if s < 0:
                col = "steel_l"
                if fbm(x, y, 5607, 40, 2) > 0.62 and W.calm_k(x, y) < 0.6:
                    col = "white"
            else:
                col = "stone"
                if fbm(x, y, 5608, 40, 2) > 0.62 and W.calm_k(x, y) < 0.6:
                    col = "stone_d"
            img.set(x, y, col)
    for y in range(150, IMG_H):
        for x in range(IMG_W):
            if side_mix(x, y) < 0 <= side_mix(x + 1, y):
                img.set(x, y, "fog")
    # nest ring: woven branches round an ellipse
    ccx, ccy, rx, ry = MIDX, MIDY + 4, 106, 132
    rng = random.Random(5609)
    for k in range(260):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(1.0, 1.12)
        x0 = ccx + math.cos(a) * rx * r
        y0 = ccy + math.sin(a) * ry * r
        ta = a + math.pi / 2 + rng.uniform(-0.4, 0.4)
        ln = rng.randrange(10, 22)
        col = rng.choice(("brown", "brown_d", "gold_d", "umber"))
        for s in range(ln):
            x = int(x0 + math.cos(ta) * (s - ln / 2))
            y = int(y0 + math.sin(ta) * (s - ln / 2) * 0.8)
            img.set(x, y, col)
            img.set(x, y + 1, "umber")
    for k in range(70):
        a = rng.uniform(0, 2 * math.pi)
        x = int(ccx + math.cos(a) * rx * rng.uniform(0.95, 1.05))
        y = int(ccy + math.sin(a) * ry * rng.uniform(0.95, 1.05))
        img.set(x, y, "gold")
        img.set(x + 1, y, "gold_l")
    # gold, gems, eggs
    for (x, y) in ((AX0 - 4, AY0 + 70), (AX1 - 20, AY0 + 40), (20, 350), (AX1 - 22, AY1 - 30)):
        pile = Canvas(26, 12)
        for (px, py) in P.ellipse(13, 9, 12, 5):
            pile.set(px, py, "gold_l" if (px + py) % 3 == 0 else ("gold" if px < 14 else "gold_d"))
        for (gx, gy, col) in ((6, 7, "red"), (14, 5, "sky"), (19, 8, "leaf"), (10, 9, "violet")):
            pile.set(gx, gy, col)
            pile.set(gx + 1, gy, "white")
        pile.outline_all("brown")
        AW.place(img, pile, x, y, shadow=(1.0, -1), shadow_dx=3)
        sc.anim("glint_gold", x + 8, y - 2, (x + y) % 8, 0.7)
    sc.anim("egg_white", AX0 + 6, AY0 - 14, 0, 0.7)
    sc.anim("egg_white", AX0 + 20, AY0 - 8, 3, 0.6)
    sc.anim("egg_red", AX1 - 34, AY0 - 14, 1, 0.7)
    sc.anim("egg_red", AX1 - 20, AY0 - 6, 4, 0.6)
    for (x, y) in ((AX0 - 26, AY1 - 30), (AX0 + 2, AY0 + 120)):
        AW.place(img, K7.snow_rock(x + y, 18, 10), x, y, shadow=(1.0, -1), shadow_dx=3)
    for (x, y) in ((AX1 + 4, AY1 - 40), (AX1 - 16, AY0 + 90)):
        AW.place(img, K7.basalt(x + y, 16, 10, glow=True), x, y, shadow=(1.0, -1), shadow_dx=3)
    K.edge_shadow(img, 152, 4, 0, IMG_W)
    # bottom: the summit falls away: clouds below
    for y in range(AY1 + 44, IMG_H):
        for x in range(IMG_W):
            img.set(x, y, "sky_l" if x < MIDX else "peach")
    for k, y in enumerate((AY1 + 60, AY1 + 90, AY1 + 120)):
        W.cloud_bank(img, y, ("steel_l", "white", "white"), 5610 + k, x0=-10, x1=MIDX, size=(7.0, 11.0), step=12)
        W.cloud_bank(img, y, ("rose", "peach", "cream"), 5620 + k, x0=MIDX, x1=IMG_W + 10, size=(7.0, 11.0), step=12)
    # foreground: ice in the top-left corner, dark lava rock in the top-right, nest twigs at the bottom
    ice = K7.ice_block(46, 40, 5630, ("water", "sky", "azure", "sky_l"), "water_d")
    sc.put_fg(ice, 44, 84)
    rk = K7.basalt(5631, 40, 30, ("ink", "ink", "slate", "stone_d"), True)
    sc.put_fg(rk.flipped(), IMG_W - 86, 84)
    twigs = Canvas(IMG_W, 30)
    for k in range(80):
        x0 = rng.randrange(-10, IMG_W)
        y0 = rng.randrange(6, 26)
        ta = rng.uniform(-0.4, 0.4)
        ln = rng.randrange(14, 30)
        col = rng.choice(("brown", "brown_d", "gold_d"))
        for s in range(ln):
            twigs.set(int(x0 + math.cos(ta) * s), int(y0 + math.sin(ta) * s), col)
    twigs.outline_all("umber")
    sc.put_fg(twigs, 0, 396)
    sc.light("torch", MIDX + 40, 120, 1.0)
    sc.light("torch", 270, 120, 0.8)
    sc.light("magic", 60, 110, 0.6, tint=(0.5, 0.9, 1.0))
    sc.particle(kind="snow", amount=18, lifetime=6.0, rect=(-60, -80, 90, 320), velocity=(0.4, 1), spread=15,
                speed=(8, 14), gravity=(0, 1), colour_fade=True)
    sc.particle(kind="ember", amount=16, lifetime=3.0, rect=(90, -20, 242, 340), velocity=(0.1, -1), spread=30,
                speed=(8, 14), gravity=(0, -3), colour_fade=True)
    sc.particle(kind="spark_gold", amount=6, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -1), spread=180,
                speed=(1, 3), gravity=(0, 0), blink=True, glow=True)
    sc.modulate = (1.0, 0.98, 0.98)
    return sc


SCENES = {
    "snowfield": scene_snowfield,
    "ice_cave": scene_ice_cave,
    "hot_springs": scene_hot_springs,
    "avalanche_pass": scene_avalanche_pass,
    "volcano": scene_volcano,
    "dragon_nest": scene_dragon_nest,
}
