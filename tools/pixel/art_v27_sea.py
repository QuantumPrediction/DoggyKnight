"""v2.7 (CW7) chapter 4「沉沒之國」: a bright summer sea, then down to the sunken kingdom.

    golden_beach   4-1  morning on the golden beach: turquoise shallows, foam, a pier, a sandcastle
    sea_cliffs     4-2  noon on the chalk cliffs: a cove with a lighthouse and the pirate ship sailing in
    pirate_ship    4-3  afternoon on the crab pirates' deck: the big sail, rigging, cannons, the helm
    coral_reef     4-4  a sunlit reef: coral heads, kelp, fish, light rays and caustics on pale sand
    sunken_city    4-5  the drowned city of Lyonesse: seaweed-wrapped domes, cyan lamps, old paving
    sunken_palace  4-6  the Kraken's palace: pearl marble, coral pillars, the scallop throne

Arena = image 64..240 x 160..384 (art_world); only image y 88..408 shows on a 180x320 phone, so
the top strip (y 88..160) carries each scene's vista and the bottom strip its foreground.
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


def _sky(img: Canvas, y1: int, seed: int, bands=None, clouds: bool = True) -> None:
    K.sky_bands(img, 0, y1, bands or [("sky", 0.0), ("azure", 0.4), ("sky_l", 0.72), ("haze", 0.9)], seed=seed,
                wave=1.6)
    if clouds:
        W.cloud_bank(img, int(y1 * 0.55), ("sky_l", "haze", "white"), seed + 1, x0=-10, x1=110, size=(4.0, 7.0),
                     step=12)
        W.cloud_bank(img, int(y1 * 0.4), ("sky_l", "haze", "white"), seed + 2, x0=190, x1=IMG_W + 10, size=(3.0, 6.0),
                     step=11)


def _island(img: Canvas, cx: int, base: int, w: int, h: int, seed: int, palms: int = 2) -> None:
    for x in range(cx - w, cx + w):
        top = base - int(h * max(0.0, 1 - ((x - cx) / w) ** 2))
        for y in range(top, base + 1):
            img.set(x, y, "teal" if x < cx else "forest_d")
        img.set(x, top, "grass")
    for k in range(palms):
        px = cx - w // 3 + k * (w // 2)
        img.vline(px, base - h - 7, base - h, "brown_d")
        for d in range(-3, 4):
            img.set(px + d, base - h - 7 + abs(d) // 2, "forest")
    for x in range(cx - w - 2, cx + w + 2):
        img.set(x, base + 1, "white" if (x // 2) % 2 else "sky_l")


def palm_fronds(w: int, h: int, seed: int, flip: bool = False) -> Canvas:
    """Palm fronds drooping in from a crown just outside the top-left corner (foreground framing)."""
    rng = random.Random(seed)
    c = Canvas(w, h)
    for i in range(6):
        a = 0.05 + i * 0.26 + rng.uniform(-0.05, 0.05)
        ln = rng.uniform(w * 0.7, w * 1.0)
        for s in range(int(ln)):
            f = s / ln
            x = math.cos(a) * s
            y = math.sin(a) * s * 0.7 + (f ** 2) * h * 0.35
            c.set(int(x), int(y), "forest")
            for j in range(1, int(5 * (1 - f) + 2)):
                c.set(int(x) - (j // 3), int(y) + j, "forest_d" if j > 2 else "forest")
                c.set(int(x) + (j // 3), int(y) - j // 2, "teal" if s % 2 else "forest")
    c.outline_all("deep")
    return c.flipped() if flip else c


def tall_ship(w: int = 44, seed: int = 0) -> Canvas:
    """The crab pirates' ship seen side-on at sea: a dark hull, cream sails, a black fish-bone flag."""
    h = int(w * 0.95)
    c = Canvas(w + 4, h + 4)
    base = h - 2
    for y in range(base - 8, base):
        k = (y - (base - 8)) / 8
        inset = int(k * k * 6)
        for x in range(2 + inset, w + 2 - inset):
            col = "brown_d" if y > base - 4 else "brown"
            if y == base - 6:
                col = "gold_d"
            c.set(x, y, col)
    for (mx, top, sw) in ((w * 0.35, 6, 10), (w * 0.65, 2, 12)):
        c.vline(int(mx), top, base - 8, "umber")
        for k, (sy, sh) in enumerate(((top + 3, 8), (top + 13, 10))):
            ww = sw + k * 2
            for y in range(sy, sy + sh):
                for x in range(int(mx - ww / 2), int(mx + ww / 2)):
                    u = (x - (mx - ww / 2)) / ww
                    c.set(x, y + int(1.5 * math.sin(u * math.pi)), "white" if u < 0.4 else "cream")
        c.set(int(mx), top - 1, "ink")
    for x in range(int(w * 0.65) + 1, int(w * 0.65) + 6):
        c.set(x, 0, "ink")
        c.set(x, 1, "ink")
    c.set(int(w * 0.65) + 3, 0, "white")
    c.line(2, base - 9, int(w * 0.35), 6, "umber")
    c.line(w + 2, base - 9, int(w * 0.65), 2, "umber")
    c.outline_all("navy")
    for x in range(0, w + 4):
        c.set(x, base + 1, "white" if x % 3 else "sky_l")
    return c


# ==========================================================================
# 4-1 golden_beach
# ==========================================================================

def scene_golden_beach() -> Scene26:
    """4-1 金色沙灘: a bright summer morning. Turquoise shallows wash onto golden sand; a wooden pier reaches
    into the sea with a boat tied to it, a rowing boat is pulled up on the beach, a sandcastle flies a
    flag; tide pools, shells and palms frame the clearing, beach grass on the dune behind."""
    sc = Scene26("sand", 0.36)
    img = sc.img
    hz = 48
    _sky(img, hz, 4101)
    _island(img, 250, hz + 2, 22, 7, 4102)
    img.blit(tall_ship(22, 1), 60, hz - 20)

    def shore_y(x: float) -> float:
        return 146 + 2.0 * math.sin(x / 37.0 + 1.0) + 1.0 * math.sin(x / 13.0)

    K7.sea(img, (0, hz, IMG_W, 152), [("water_d", 0.0), ("water", 0.06), ("sky", 0.42), ("azure", 0.8)], 4103,
           mask=lambda x, y: y < shore_y(x) - 1, rows=10, density=0.5)
    K7.glitter_path(img, 36, hz + 2, 118, 4104, cols=("white", "sky_l"), spread=0.28,
                    mask=lambda x, y: y < shore_y(x) - 5)
    # the sand: one warm tone with soft sunlit patches, ripples only near the edges
    K7.sand_floor(img, (0, 130, IMG_W, IMG_H), 4105, mask=lambda x, y: y >= shore_y(x))
    K7.shoreline(img, 0, IMG_W, shore_y, 4106, wet="dirt", shallow="azure", wet_depth=5)
    # washed-up kelp along the tide line
    rng = random.Random(4107)
    for _ in range(18):
        x = rng.randrange(0, IMG_W - 10)
        y = int(shore_y(x)) + rng.randrange(6, 10)
        for k in range(rng.randrange(4, 9)):
            img.set(x + k, y + int(math.sin(k * 0.9) * 1.2), "moss_d" if k % 3 else "forest")
    # the pier: cross planks on two beams, posts standing in the water
    px0, px1 = 212, 226
    for y in range(64, int(shore_y(219)) + 4):
        for x in range(px0, px1):
            row = (y - 64) % 4
            col = "gold_d" if row == 0 else ("brown" if row < 3 else "umber")
            if x in (px0, px1 - 1):
                col = "brown_d"
            img.set(x, y, col)
        img.set(px1, y, "umber")
        img.set(px1 + 1, y, "water_d" if y < shore_y(px1 + 1) - 2 else name_at(img, px1 + 1, y))
    for y in range(68, 146, 12):
        for x in (px0 - 2, px1):
            img.rect(x, y, 2, 6, "brown_d")
            img.set(x, y, "gold_d")
            if y < shore_y(x) - 6:
                img.hline(x - 1, x + 2, y + 6, "water_d")
                img.hline(x - 2, x + 3, y + 7, "sky")
    boat = K7.rowboat(26)
    img.blit(boat, px1 + 6, 96)
    img.hline(px1 + 5, px1 + 33, 110, "water")
    img.line(px1 + 5, 100, px1 + 1, 94, "sand")
    # a rowing boat pulled up on the sand (top left), oars inside
    boat2 = K7.rowboat(30, ("brown_d", "red_d", "red"), stripe="cream")
    AW.place(img, boat2, AX0 + 4, 140, shadow=(1.0, -1), shadow_dx=4)
    img.line(AX0 + 10, 146, AX0 + 28, 144, "gold_d")
    # rocks in the surf (left) with foam rings
    for (x, y, w, h) in ((0, 120, 18, 10), (18, 128, 12, 7), (150, 116, 10, 6)):
        rk = AW.rock(x + y, w, h, ("slate", "stone_d", "stone", "stone_l"), "iron", "teal")
        img.blit(rk, x, y)
        for xx in range(x - 1, x + w + 3):
            img.set(xx, y + h + 1, "white" if (xx + y) % 3 else "sky_l")
    # the sandcastle at the top of the clearing: three towers, battlements, a gate and a flag
    castle = Canvas(34, 26)
    for (x0, w, h, crown) in ((1, 8, 14, True), (24, 8, 15, True), (8, 17, 10, True), (12, 9, 20, True)):
        for y in range(26 - h, 26):
            for x in range(x0, x0 + w):
                castle.set(x, y, "cream" if x < x0 + 2 else ("sand" if x < x0 + w - 2 else "dirt"))
        if crown:
            for x in range(x0, x0 + w, 2):
                castle.set(x, 25 - h, "cream" if x < x0 + 3 else "sand")
    castle.rect(14, 19, 5, 7, "gold_d")
    castle.rect(15, 20, 3, 6, "brown")
    for (x, y) in ((4, 15), (27, 14), (16, 10)):
        castle.set(x, y, "gold_d")
        castle.set(x, y + 1, "gold_d")
    castle.set(6, 24, "pink")
    castle.set(28, 25, "white")
    castle.outline_all("gold_d")
    cx0, cy0 = AX1 - 76, AY0 - 12
    AW.place(img, castle, cx0, cy0, shadow=(1.0, -1), shadow_dx=5)
    sc.anim("pennant_red", cx0 + 15, cy0 + 6 - 11, 0, 1.1)
    # tide pools at the sides
    for (cx, cy, rx, ry) in ((26, 236, 16, 7), (276, 300, 14, 6), (20, 360, 11, 5)):
        for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
            for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
                d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry) + (fbm(x, y, 4108, 5, 2) - 0.5) * 0.2
                if d < 0.8:
                    img.set(x, y, "sky" if y < cy - ry * 0.2 else "water")
                elif d < 1.0:
                    img.set(x, y, "slate" if y > cy else "stone_d")
        img.hline(int(cx - rx * 0.5), int(cx - rx * 0.1), int(cy - ry * 0.4), "sky_l")
        sc.anim("water_glint", int(cx - 3), int(cy - 1), int(cx) % 6, 0.8)
    # shells, starfish and pebbles round the edges of the clearing
    edge = (AX0 - 46, AY0 - 6, AX1 + 46, AY1 + 30)
    K7.scatter_props(img, edge, 90, 4109, K7.shell, calm=0.975)
    K7.scatter_props(img, edge, 18, 4110, K7.starfish, calm=0.99)
    K7.scatter_props(img, edge, 30, 4111, lambda r: K7.pebble_prop(r, ("dirt", "stone", "stone_l")), calm=0.98)
    # paw prints wandering in from the bottom left
    for k in range(10):
        x, y = 70 + k * 7, 470 - k * 10 + (k % 2) * 3
        for (dx, dy) in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, -1), (2, -1), (0, -2), (1, -2)):
            if name_at(img, x + dx, y + dy) in ("sand", "cream"):
                img.set(x + dx, y + dy, "dirt")
    # driftwood, a barrel, a net drying on posts, rope
    log = Canvas(30, 6)
    for x in range(1, 29):
        for y in range(1, 5):
            log.set(x, y, "stone_l" if y == 1 else ("stone" if y < 4 else "stone_d"))
    log.set(8, 0, "stone")
    log.set(20, 5, "stone_d")
    log.outline_all("iron")
    AW.place(img, log, AX1 - 40, AY1 - 4, shadow=(1.0, -1), shadow_dx=3)
    AW.place(img, K.barrel(1), 14, 290, shadow=(0.9, 0), shadow_dx=3)
    AW.place(img, K7.net_post(), 252, 206, shadow=(1.0, -1), shadow_dx=4)
    img.blit(K7.rope_coil(), 262, 238)
    # palms on the sides (wide phones), a dune with beach grass at the bottom
    for (x, y, h, lean, flip) in ((-30, 150, 60, 0.3, False), (240, 170, 58, 0.25, True), (-26, 300, 54, 0.2, False),
                                  (246, 330, 56, 0.3, True)):
        AW.place(img, K7.palm(x + y, h, lean, flip), x, y, shadow=(0.7, -2), shadow_dx=10)
    for x in range(IMG_W):
        top = 412 + int(4 * math.sin(x / 23.0) + 2 * math.sin(x / 9.0))
        for y in range(top, IMG_H):
            img.set(x, y, "cream" if y < top + 2 else ("sand" if fbm(x, y, 4112, 24, 2) > 0.42 else "dirt"))
    for i, x in enumerate(range(-6, IMG_W, 19)):
        tuft = AW.blob_canvas(16, 12, [(5, 7, 4), (10, 6, 5)], ["moss_d", "moss", "leaf_l", "spring"], "forest", 4113 + i)
        img.blit(tuft, x, 408 + (i * 5) % 8)
    # foreground: palm fronds in the top corners, dune grass at the bottom
    for side in (0, 1):
        sc.put_fg(palm_fronds(60, 44, 4120 + side, side == 1), 40 if side == 0 else IMG_W - 100, 80)
    AL.clumps(sc.fg, 4121, ("moss_d", "moss", "leaf_l", "spring"), "forest", flowers=["white", "pink"], gap=(18, 36))
    # animation: foam all along the shore, crests, gulls, glints, swaying beach grass
    for k, x in enumerate(range(-8, IMG_W, 46)):
        sc.anim("foam", x, int(shore_y(x + 24)) - 4, k % 8, 0.9 + (k % 3) * 0.08)
    for i, (x, y) in enumerate(((30, 72), (120, 82), (180, 66), (96, 104), (250, 94), (160, 120), (44, 108))):
        sc.anim("wave_crest", x, y, i % 6, 0.7 + (i % 3) * 0.15)
    for i, (x, y) in enumerate(((60, 14), (150, 30), (230, 8))):
        sc.anim("gull", x, y, i * 3, 0.8 + i * 0.1)
    for i, (x, y) in enumerate(((30, 62), (44, 80), (38, 98), (130, 64), (186, 90))):
        sc.anim("water_glint", x, y, i, 0.8)
    for i, (x, y) in enumerate(((20, 402), (100, 410), (200, 406), (270, 402))):
        sc.anim("tuft_gold", x, y, i % 4, 0.8 + i * 0.07)
    sc.light("sun", 20, 10, 1.1)
    sc.particle(kind="spray", amount=10, lifetime=1.6, rect=(-62, 50, 242, 60), velocity=(0.3, -1), spread=30,
                speed=(6, 12), gravity=(0, 12), colour_fade=True)
    sc.particle(kind="mote", amount=10, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -3), spread=180,
                speed=(2, 4), gravity=(0, 0), colour_fade=True)
    sc.modulate = (1.0, 0.99, 0.95)
    return sc


# ==========================================================================
# 4-2 sea_cliffs
# ==========================================================================

def chalk_stack(w: int, h: int, seed: int) -> Canvas:
    """A chalk sea stack: a tapering white pillar, lit left, strata, a grassy cap."""
    c = Canvas(w + 4, h + 2)
    for y in range(h):
        k = y / h
        half = w / 2 * (0.65 + 0.35 * k)
        cx = (w + 4) / 2 + (1 if y < h * 0.3 else 0)
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x + 0.5 - (cx - half)) / (2 * half)
            col = "white" if u < 0.3 else ("stone_l" if u < 0.72 else "stone")
            if y % 7 == 6 and u > 0.35 and fbm(x, y, seed, 4, 2) > 0.4:
                col = "stone_d"
            if y < 3:
                col = "leaf" if u < 0.5 else "leaf_d"
            c.set(x, y + 1, col)
    c.outline_all("steel_d")
    return c


def scene_sea_cliffs() -> Scene26:
    """4-2 海邊懸崖: noon on the chalk cliffs. Below the clifftop path a blue cove opens to the horizon:
    white sea stacks, a headland with a red-and-white lighthouse, and the crab pirates' ship sailing in.
    On top, short sea grass with pink thrift and yellow gorse, a rope fence along the edge."""
    sc = Scene26("grass", 0.38)
    img = sc.img
    hz = 36
    _sky(img, hz, 4201, [("water", 0.0), ("sky", 0.25), ("azure", 0.6), ("sky_l", 0.88)])
    K7.sea(img, (0, hz, IMG_W, 156), [("water_d", 0.0), ("water", 0.12), ("sky", 0.6), ("azure", 0.92)], 4202,
           rows=10, density=0.45)
    K7.glitter_path(img, 110, hz + 2, 96, 4203, spread=0.25)

    # the far headland across the cove (right): chalk face, grass top, the lighthouse
    def head_top(x: float) -> float:
        return 96 - 8 * math.exp(-((x - 250) / 40.0) ** 2) + 2 * math.sin(x / 7.0)
    K7.cliff_band(img, 196, IMG_W, lambda x: head_top(x) + max(0, (214 - x)) * 1.2, 124,
                  ("stone", "stone_l", "white", "white"), 4204, strata=6)
    for x in range(196, IMG_W):
        for y in range(120, 126):
            if name_at(img, x, y) in ("stone", "stone_l", "white"):
                img.set(x, y, "stone_d")
        img.set(x, 126, "white" if (x // 2) % 3 else "sky_l")
        img.set(x, 127, "sky_l")
    lh = K7.lighthouse(36)
    img.blit(lh, 224, int(head_top(234)) - lh.h + 4)
    # the left headland (near, ours): its chalk face drops into the cove
    def left_top(x: float) -> float:
        return 92 + (x / 70.0) ** 2 * 40 + 2 * math.sin(x / 6.0)
    K7.cliff_band(img, 0, 70, left_top, 150, ("stone", "stone_l", "white", "white"), 4205, strata=6)
    for x in range(0, 70):
        img.set(x, 150, "white")
    # sea stacks in the cove and the pirate ship sailing in
    for (x, w, h) in ((168, 9, 24), (184, 6, 14), (74, 8, 18)):
        st = chalk_stack(w, h, x)
        img.blit(st, x, 140 - h)
        for xx in range(x - 2, x + w + 6):
            img.set(xx, 141, "white" if xx % 3 else "sky_l")
            img.set(xx, 142, "sky_l")
    img.blit(tall_ship(40, 2), 108, 96)
    # our clifftop: the grass lip at the top with a rope fence; a chalk path along it
    def lip(x: float) -> float:
        return 150 + 2 * math.sin(x / 17.0) + 1.5 * math.sin(x / 6.3) if x >= 70 else 152

    for x in range(70, IMG_W):
        y0 = int(lip(x))
        for y in range(y0 - 3, y0 + 1):
            img.set(x, y, "white" if y > y0 - 2 else "stone_l")
    W.textured_floor(img, (0, 140, IMG_W, IMG_H), ("leaf_d", "grass", "leaf"), 4206, scale=44,
                     mask=lambda x, y: y > lip(x))
    W.blades(img, (0, 150, IMG_W, IMG_H), 4207, 0.045, mask=lambda x, y: y > lip(x) + 1)
    for x in range(0, IMG_W):
        y0 = int(lip(x)) + 1
        img.set(x, y0, "spring")
        img.set(x, y0 + 1, "leaf" if x % 3 else "spring")
    AW.paint_path(img, [(-10, 166), (60, 164), (130, 166), (210, 163), (320, 166)], 9, 4208,
                  ramp=("stone", "stone_l", "white"), pebbles=12)
    K.edge_shadow(img, AY0 - 4, 3, 0, IMG_W)
    for k, x in enumerate(range(8, IMG_W, 30)):
        y = int(lip(x)) + 2
        img.rect(x, y - 11, 3, 12, "brown")
        img.vline(x + 2, y - 11, y, "brown_d")
        img.set(x, y - 11, "gold_d")
        img.set(x + 1, y - 11, "gold_d")
        img.hline(x - 1, x + 3, y + 1, "forest")
        if x + 30 < IMG_W:
            ny = int(lip(x + 30)) + 2
            for t in range(2, 30):
                yy = int(y - 8 + (ny - y) * t / 30 + 2.6 * math.sin(t / 30 * math.pi))
                img.set(x + 1 + t, yy, "sand")
                img.set(x + 1 + t, yy + 1, "dirt")
    # thrift, gorse, chalk stones round the clearing
    K7.scatter_props(img, (AX0 - 50, AY0 + 4, AX1 + 50, AY1 + 40), 40, 4209, K7.flower_clump, calm=0.97)
    for (x, y) in ((AX0 - 20, AY0 + 30), (AX1 + 2, AY0 + 70), (AX0 - 22, AY0 + 170), (AX1 + 4, AY1 - 30),
                   (14, 330), (262, 380), (6, 420)):
        g = AW.bush(x * 3 + y, 20, 12, ("forest", "leaf_d", "leaf", "leaf_l"), "forest_d",
                    flowers=["yellow", "gold_l", "yellow"])
        AW.place(img, g, x, y, shadow=(1.0, -1), shadow_dx=4)
    for (x, y) in ((AX0 + 8, AY1 - 18), (AX1 - 26, AY0 + 14), (AX0 + 4, AY0 + 96)):
        AW.place(img, AW.rock(x + y, 14, 7, ("stone", "stone_l", "white", "white"), "stone_d", "moss"), x, y,
                 shadow=(1.0, -1), shadow_dx=3)
    for (x, y, flip) in ((-6, 190, False), (256, 250, True)):
        t = AW.tree(x + y, 34, ("forest", "leaf_d", "leaf", "spring"), "forest_d")
        AW.place(img, t.flipped() if flip else t, x, y, shadow=(1.0, -2), shadow_dx=6)
    AW.place(img, AW.signpost(), 30, 268, shadow=(0.8, -1))
    # bottom: the path down to the beach between gorse bushes
    AW.paint_path(img, [(150, 520), (146, 470), (152, 420), (150, AY1 + 6)], 14, 4210, ramp=("stone", "stone_l", "white"),
                  pebbles=10)
    for i, x in enumerate(range(-12, IMG_W, 26)):
        if 120 < x < 170:
            continue
        AW.place(img, AW.bush(4211 + i, 22, 13, ("forest", "leaf_d", "leaf", "leaf_l"), "forest_d",
                              flowers=["yellow", "pink"]), x, 428 + (i * 7) % 12)
    AL.clumps(sc.fg, 4223, ("forest_d", "forest", "leaf_d", "leaf"), "forest_d", flowers=["pink", "yellow", "white"])
    for i, (x, y) in enumerate(((20, 60), (90, 40), (190, 70), (230, 22), (60, 100))):
        sc.anim("gull", x, y, i * 2, 0.7 + i * 0.1)
    for i, (x, y) in enumerate(((120, 110), (40, 76), (180, 96), (200, 60), (140, 50))):
        sc.anim("wave_crest", x, y, i % 6, 0.8)
    sc.anim("glint_gold", 230, int(head_top(234)) - 36, 0, 0.6)
    for i, (x, y, k) in enumerate(((AX0 - 10, AY0 + 50, "flower_pink"), (AX1 + 2, AY0 + 120, "flower_yellow"),
                                   (AX0 - 8, AY1 - 10, "flower_white"), (AX1 + 4, AY1 + 6, "flower_pink"),
                                   (AX0 + 2, AY0 + 6, "flower_yellow"), (AX1 - 12, AY0 + 6, "flower_pink"))):
        sc.anim(k, x, y, i % 4, 0.9 + (i % 3) * 0.1)
    sc.light("sun", MIDX, 0, 1.0)
    sc.particle(kind="petal", amount=8, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.3), spread=20,
                speed=(12, 18), gravity=(0, 2), colour_fade=True, spin=True)
    sc.particle(kind="pollen", amount=8, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(1, -0.5), spread=60,
                speed=(3, 6), gravity=(0, 0), colour_fade=True)
    sc.modulate = (1.0, 1.0, 0.97)
    return sc


# ==========================================================================
# 4-3 pirate_ship
# ==========================================================================

def _deck(img: Canvas, rect: tuple[int, int, int, int], seed: int, tone: str = "brown", seam: str = "brown_d",
          w: int = 8, mask=None) -> None:
    """Deck planks running bow to stern: one tone, a dark seam on the right edge, staggered butt
    joints, a few soft grain streaks near the edges."""
    x0, y0, x1, y1 = rect
    rng = random.Random(seed)
    for x in range(x0, x1, w):
        y = y0 - rng.randrange(0, 60)
        while y < y1:
            ln = rng.randrange(44, 96)
            for yy in range(max(y, y0), min(y + ln, y1)):
                for xx in range(x, min(x + w, x1)):
                    if mask is not None and not mask(xx, yy):
                        continue
                    img.set(xx, yy, seam if (xx == x + w - 1 or yy == y + ln - 1) else tone)
            y += ln
    for _ in range(90):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        if rng.random() < W.calm_k(x, y) * 0.95 or (mask is not None and not mask(x, y)):
            continue
        if name_at(img, x, y) == tone:
            for k in range(rng.randrange(3, 7)):
                if name_at(img, x, y + k) == tone:
                    img.set(x, y + k, seam if k % 3 else dk(seam))


def scene_pirate_ship() -> Scene26:
    """4-3 海盜船: a sunny afternoon at sea on the crab pirates' ship. The great patched mainsail fills
    the top above the mast step, shrouds and ratlines run down to the rails, the bow points into a
    glittering sea; cannons, barrels, rope and lanterns along the sides, the helm at the stern."""
    sc = Scene26("brown", 0.4)
    img = sc.img
    hz = 28
    _sky(img, hz, 4301, [("sky", 0.0), ("azure", 0.45), ("sky_l", 0.8)])
    K7.sea(img, (0, hz, IMG_W, IMG_H), [("water_d", 0.0), ("water", 0.05), ("sky", 0.25), ("water", 0.5)], 4302,
           rows=18, density=0.45)
    _island(img, 240, hz + 2, 18, 6, 4303, palms=1)
    hull_l, hull_r = AX0 - 2, AX1 + 2
    bow_tip, bow_full = 72, 166

    def on_ship(x: int, y: int) -> bool:
        if y < bow_tip:
            return False
        if y < bow_full:
            k = (bow_full - y) / (bow_full - bow_tip)
            half = (hull_r - hull_l) / 2 * math.sqrt(max(0.0, 1 - k ** 1.6))
            return abs(x + 0.5 - MIDX) < half
        return hull_l <= x < hull_r

    # hull: dark planked sides with a gold stripe, foam where it cuts the water
    for y in range(bow_tip - 8, IMG_H):
        for x in range(IMG_W):
            if on_ship(x, y):
                continue
            near = on_ship(x - 7, y) or on_ship(x + 7, y) or on_ship(x, y + 7)
            if near:
                img.set(x, y, "gold_d" if (y // 3) % 9 == 4 else ("brown_d" if (y // 3) % 3 else "umber"))
            elif on_ship(x - 9, y) or on_ship(x + 9, y) or on_ship(x, y + 9):
                img.set(x, y, "white" if (x + y) % 4 else "sky_l")
    _deck(img, (hull_l, bow_tip, hull_r, IMG_H), 4304, mask=on_ship)
    # bulwark rail round the deck: lit top, balusters in shade
    for y in range(bow_tip, IMG_H):
        for x in range(IMG_W):
            if on_ship(x, y) and not (on_ship(x - 3, y) and on_ship(x + 3, y) and on_ship(x, y - 3)):
                img.set(x, y, "gold" if not on_ship(x, y - 3) or not on_ship(x - 3, y) else "gold_d")
    for y in range(bow_full, IMG_H, 10):
        for x in (hull_l + 3, hull_r - 4):
            img.set(x, y, "brown_d")
            img.set(x, y + 1, "brown_d")
    # the main mast and the great sail (top centre), shrouds with ratlines to the rails
    mx = MIDX
    yard_y, sail_h, sail_w = 80, 62, 112
    img.blit(K7.mast(170, 8), mx - 5, 0)
    s = K7.sail(sail_w, sail_h, 4310, billow=7.0)
    img.blit(s, mx - sail_w // 2 - 1, yard_y)
    small = K7.sail(70, 30, 4311, billow=4.0, patch=False)
    img.blit(small, mx - 36, yard_y - 40)
    for (yy, ww) in ((yard_y, sail_w + 10), (yard_y - 40, 80)):
        img.rect(mx - ww // 2, yy - 2, ww, 3, "brown")
        img.hline(mx - ww // 2, mx + ww // 2 - 1, yy - 2, "gold_d")
    # a crab emblem painted on the sail
    for (x, y) in P.ellipse(mx, yard_y + 30, 9, 6):
        img.set(x, y, "red" if x < mx + 3 else "red_d")
    for side in (-1, 1):
        for k in range(3):
            img.set(mx + side * (10 + k), yard_y + 30 + k, "red_d")
        img.set(mx + side * 12, yard_y + 22, "red")
        img.set(mx + side * 13, yard_y + 21, "red")
        img.set(mx + side * 11, yard_y + 23, "red_d")
    img.set(mx - 3, yard_y + 27, "white")
    img.set(mx + 2, yard_y + 27, "white")
    for side in (-1, 1):
        top = (mx + side * 4, yard_y - 36)
        for k in range(2):
            bot = (mx + side * (78 + k * 10), 160 + k * 6)
            img.line(top[0] + side * k * 2, top[1], bot[0], bot[1], "umber")
        for t in range(6, 30):
            f = t / 30
            ya = int(top[1] + (160 - top[1]) * f)
            xa = int(top[0] + (mx + side * 78 - top[0]) * f)
            xb = int(top[0] + side * 2 + (mx + side * 88 - top[0] - side * 2) * f)
            if t % 3 == 0:
                img.line(xa, ya, xb, ya + int(6 * f), "brown_d")
    img.rect(mx - 9, 150, 19, 8, "brown_d")
    img.hline(mx - 9, mx + 9, 150, "gold_d")
    img.hline(mx - 10, mx + 10, 158, "umber")
    sc.anim("flag_pirate", mx + 5, 0, 0, 1.2)
    sc.anim("pennant_red", mx + 4, yard_y - 56, 1, 1.2)
    # deck furniture: capstan, coiled ropes, cannons, barrels, crates, a grating
    cap = Canvas(16, 12)
    for (x, y) in P.ellipse(8, 6, 7, 5):
        cap.set(x, y, "gold_d" if x < 7 else "brown")
    for k in range(4):
        cap.set(2 + k * 4, 3, "brown_d")
    cap.outline_all("umber")
    AW.place(img, cap, MIDX - 44, AY0 - 6, shadow=(1.0, -1), shadow_dx=3)
    img.blit(K7.rope_coil(), MIDX + 32, AY0 - 2)
    for y in (AY0 + 40, AY0 + 130):
        AW.place(img, K7.cannon(True), hull_l + 4, y, shadow=(1.0, -1), shadow_dx=2)
        AW.place(img, K7.cannon(False), hull_r - 22, y + 30, shadow=(1.0, -1), shadow_dx=2)
    for (x, y) in ((AX0 + 3, AY1 - 34), (AX1 - 17, AY0 + 6), (AX0 + 3, AY0 + 4)):
        AW.place(img, K.barrel(x), x, y, shadow=(0.9, 0), shadow_dx=3)
        AW.place(img, K.barrel(x + 1), x + 4, y + 10, shadow=(0.9, 0), shadow_dx=3)
    for (x, y) in ((AX1 - 18, AY1 - 24), (AX0 + 3, AY0 + 90)):
        AW.place(img, K7.crate(14, 11), x, y, shadow=(1.0, -1), shadow_dx=3)
    # the stern: steps up to the quarterdeck, its rail, the helm
    W.steps(img, hull_l + 10, hull_r - 10, AY1 + 6, 2, ("brown_d", "brown", "gold_d"), depth=4)
    _deck(img, (hull_l, AY1 + 14, hull_r, IMG_H), 4305, tone="gold_d", seam="brown", mask=on_ship)
    img.blit(K7.railing(hull_r - hull_l - 20, 10), hull_l + 10, AY1 + 4)
    sc.anim("helm", MIDX - 8, AY1 + 20, 0, 0.6)
    img.rect(MIDX - 2, AY1 + 35, 5, 8, "brown_d")
    grate = Canvas(30, 16)
    for y in range(16):
        for x in range(30):
            grate.set(x, y, "brown_d" if (x % 4 == 0 or y % 4 == 0) else "umber")
    grate.outline_all("umber")
    img.blit(grate, hull_l + 12, AY1 + 30)
    for i, (x, y) in enumerate(((hull_l + 2, AY0 + 10), (hull_r - 10, AY0 + 70), (hull_l + 2, AY1 - 50),
                                (hull_r - 10, AY1 + 16))):
        img.vline(x + 4, y - 4, y + 22, "brown_d")
        img.hline(x + 2, x + 6, y - 4, "brown_d")
        sc.anim("lantern", x, y - 3, i % 4, 0.7)
        sc.light("lantern", x + 4, y + 6, 0.5)
    # foreground: the stern rail at the bottom
    sc.put_fg(K7.railing(IMG_W, 14, ("umber", "brown_d", "brown"), "ink"), 0, 398)
    for i, (x, y) in enumerate(((20, 60), (40, 110), (250, 70), (270, 130), (10, 200), (280, 260), (30, 400),
                                (276, 440))):
        sc.anim("wave_crest", x, y, i % 6, 0.8 + (i % 3) * 0.1)
    for i, (x, y) in enumerate(((40, 10), (250, 30))):
        sc.anim("gull", x, y, i * 4, 0.9)
    sc.light("sun", 250, 10, 1.1, tint=(1.0, 0.92, 0.75))
    sc.particle(kind="spray", amount=12, lifetime=1.4, rect=(-62, 0, -40, 330), velocity=(1, -1), spread=30,
                speed=(8, 16), gravity=(0, 18), colour_fade=True)
    sc.particle(kind="spray", amount=12, lifetime=1.4, rect=(220, 0, 242, 330), velocity=(-1, -1), spread=30,
                speed=(8, 16), gravity=(0, 18), colour_fade=True)
    sc.particle(kind="mote", amount=8, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -3), spread=180,
                speed=(2, 4), gravity=(0, 0), colour_fade=True)
    sc.modulate = (1.0, 0.97, 0.92)
    return sc


# ==========================================================================
# 4-4 coral_reef
# ==========================================================================

def _coral_mix(rng: random.Random, big: bool = False) -> Canvas:
    k = rng.random()
    if k < 0.34:
        return K7.branch_coral(rng.randrange(9999), rng.randrange(16, 26) if big else rng.randrange(10, 16),
                               rng.choice(("coral", "orange", "pink", "yellow")))
    if k < 0.55:
        return K7.fan_coral(rng.randrange(14, 24), rng.randrange(14, 22), rng.randrange(999),
                            rng.choice(("violet", "pink", "coral")))
    if k < 0.75:
        return K7.coral_head(rng.randrange(999), rng.randrange(18, 28) if big else rng.randrange(12, 18),
                             rng.randrange(12, 18) if big else rng.randrange(8, 12))
    return K7.tube_sponge(rng.randrange(999), rng.choice(("orange", "yellow", "violet")))


def scene_coral_reef() -> Scene26:
    """4-4 海底珊瑚礁: a sunlit reef under clear water. Light rays slant down through the blue; behind the
    pale sandy clearing a wall of reef rock crowded with staghorn, fans, sponges and coral heads; kelp
    sways, fish dart, bubbles rise, caustics shimmer on the sand."""
    sc = Scene26("sand", 0.42)
    img = sc.img
    K7.water_column(img, (0, 0, IMG_W, 170), [("sky_l", 0.0), ("azure", 0.07), ("sky", 0.28), ("water", 0.66)], 4401)
    K7.surface_ripples(img, 6, 4402)
    # far: hazy reef mounds
    K.hills_layer(img, 96, 7, 23.0, "water", rim="sky", seed=4403, fill_to=170, lumps=0.5)
    K.hills_layer(img, 110, 6, 17.0, "water_d", rim="water", seed=4404, fill_to=170, lumps=0.6)
    # the near reef wall and its corals
    K7.reef_wall(img, lambda x: 120 + 5 * math.sin(x / 19.0) + 3 * math.sin(x / 7.0), 166, 4405)
    rng = random.Random(4406)
    for row, base in enumerate((134, 150, 162)):
        x = -10 + row * 9
        while x < IMG_W:
            c = _coral_mix(rng, big=row < 2)
            img.blit(c, x, base - c.h + rng.randrange(-3, 4))
            x += c.w - rng.randrange(3, 7) + (8 if row == 2 else 0)
    # the sand clearing
    K7.sand_floor(img, (0, 160, IMG_W, IMG_H), 4407, ripples=120,
                  mask=lambda x, y: y > 168 or name_at(img, x, y) in ("sand", None))
    rr = random.Random(4412)
    x = -6
    while x < IMG_W:
        r = rr.uniform(4, 7)
        bl = AW.blob_canvas(int(r * 2.6) + 4, int(r * 2) + 4, [(r * 1.3 + 2, r + 2, r), (r * 0.7 + 2, r * 1.2 + 2, r * 0.7)],
                            ["night", "water_d", "steel_d", "steel"], "navy", 4413 + int(x), texture=0.1)
        AW.place(img, bl, int(x), 160 + rr.randrange(-2, 4), shadow=(1.0, -1), shadow_dx=3)
        if rr.random() < 0.5:
            c = _coral_mix(rr)
            img.blit(c, int(x) + 2, 166 - c.h + rr.randrange(0, 4))
        x += r * 2.2 + rr.randrange(0, 14)
    K.edge_shadow(img, AY0 + 10, 4)
    K7.scatter_props(img, (AX0 - 50, AY0 + 6, AX1 + 50, AY1 + 40), 40, 4408, K7.sea_grass, calm=0.98)
    K7.scatter_props(img, (AX0 - 40, AY0 + 6, AX1 + 40, AY1 + 30), 50, 4409, K7.shell, calm=0.975)
    K7.scatter_props(img, (AX0 - 40, AY0 + 6, AX1 + 40, AY1 + 30), 8, 4410, K7.starfish, calm=0.99)
    for (x, y) in ((AX0 + 2, AY0 + 10), (AX1 - 26, AY0 + 40), (AX0 + 4, AY1 - 24), (AX1 - 22, AY1 - 14)):
        c = K7.coral_head(x + y, 22, 13)
        AW.place(img, c, x, y, shadow=(1.0, -1), shadow_dx=3)
    # sides: big coral heads, fans and staghorn
    rng = random.Random(4411)
    for (x, y) in ((4, 230), (250, 200), (8, 330), (252, 320), (20, 280), (262, 270), (2, 400), (270, 380)):
        c = _coral_mix(rng, big=True)
        AW.place(img, c, x, y - c.h, shadow=(0.9, -1), shadow_dx=3)
    # bottom: the reef again
    K7.reef_wall(img, lambda x: 410 + 5 * math.sin(x / 15.0) + 3 * math.sin(x / 5.0), IMG_H, 4412)
    for row, base in enumerate((424, 444)):
        x = -8 + row * 11
        while x < IMG_W:
            c = _coral_mix(rng, big=True)
            img.blit(c, x, base - c.h + rng.randrange(0, 6))
            x += c.w - rng.randrange(2, 6)
    # foreground: dark staghorn silhouettes in the bottom corners, kelp tops in the top corners
    for k, x in enumerate((-6, 24, 236, 264)):
        c = K7.branch_coral(4420 + k, 32, "teal")
        c.replace("teal", "deep")
        c.replace("grass", "teal")
        c.replace("spring", "teal")
        sc.put_fg(c, x, 398 + (k % 2) * 4)
    for side in (0, 1):
        fol = AL.foliage(40, 40, 4430 + side, ("deep", "teal", "grass", "spring"), "navy")
        sc.put_fg(fol.flipped() if side else fol, 48 if side == 0 else IMG_W - 88, 84)
    # animation
    for i, (x, y) in enumerate(((24, 104), (58, 98), (100, 104), (196, 100), (232, 106), (270, 102), (10, 220),
                                (276, 300), (6, 380), (280, 400))):
        sc.anim("kelp" if i % 3 else "kelp_gold", x, y, i % 6, 0.6 + (i % 3) * 0.12)
    for i, (x, y) in enumerate(((80, 140), (204, 144), (40, 250), (262, 236), (130, 152))):
        sc.anim("anemone" if i % 2 == 0 else "anemone_violet", x, y, i % 4, 0.8)
    for i, (x, y) in enumerate(((40, 56), (180, 76), (110, 40), (250, 50), (150, 104))):
        sc.anim("fish_gold" if i % 2 else "fish_blue", x, y, i * 2, 0.6 + i * 0.1)
    for i, (x, y) in enumerate(((AX0 - 12, AY0 + 40), (AX1 + 4, AY0 + 140), (170, 112))):
        sc.anim("bubbles", x, y, i * 3, 0.7)
    for i, (x, y) in enumerate(((AX0 + 2, AY0 + 34), (AX1 - 18, AY0 + 100), (AX0 + 4, AY1 - 50), (AX1 - 18, AY1 - 34),
                                (AX0 - 30, AY0 + 150), (AX1 + 14, AY0 + 60))):
        sc.anim("caustic", x, y, i % 4, 0.6)
    sc.light_shafts = [(-20, 22, 0.07, (0.8, 1.0, 1.0)), (40, 14, 0.06, (0.8, 1.0, 1.0)),
                       (110, 18, 0.05, (0.8, 1.0, 1.0))]
    sc.light("sun", MIDX - 30, 0, 0.8, tint=(0.7, 1.0, 1.0))
    sc.particle(kind="bubble", amount=14, lifetime=5.0, rect=(-10, 0, 190, 380), velocity=(0, -1), spread=10,
                speed=(8, 14), gravity=(0, -2), colour_fade=True)
    sc.particle(kind="mote", amount=12, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(1, 0), spread=180,
                speed=(1, 3), gravity=(0, 0), colour_fade=True)
    sc.modulate = (0.88, 0.97, 1.0)
    return sc


# ==========================================================================
# 4-5 sunken_city
# ==========================================================================

def _dome_house(w: int, h: int, seed: int, ramp=("steel_d", "steel", "steel_l"), roof=("teal", "grass", "spring"),
                outline: str = "night_d", weed: int = 3, lamp: bool = True) -> Canvas:
    """A drowned house of Lyonesse: plastered walls, an onion dome, a round door, arched windows (some lit
    cyan by the sea-folk's lamps), seaweed hanging from the eaves."""
    rng = random.Random(seed)
    dome = w // 2 + 2
    c = Canvas(w + 2, h + dome + 3)
    oy = dome + 1
    for y in range(h):
        for x in range(w):
            u = x / (w - 1)
            col = ramp[2] if u < 0.22 else (ramp[1] if u < 0.78 else ramp[0])
            if y < 2:
                col = ramp[0]
            c.set(x + 1, oy + y, col)
    for y in range(dome):
        t = (dome - y) / dome
        half = math.sqrt(max(0.0, 1 - t * t)) * (w / 2 - 1) * (1.0 + 0.15 * math.sin(t * math.pi))
        for x in range(int(w / 2 + 1 - half), int(w / 2 + 1 + half) + 1):
            u = (x - (w / 2 + 1 - half)) / max(1, 2 * half)
            c.set(x, y + 1, roof[2] if u < 0.3 else (roof[1] if u < 0.72 else roof[0]))
    c.set(w // 2 + 1, 0, "gold")
    dx = w // 2 - 1
    for y in range(oy + h - 9, oy + h):
        for x in range(dx, dx + 5):
            if y > oy + h - 9 or x in (dx + 1, dx + 2, dx + 3):
                c.set(x, y, "night_d" if x > dx else "night")
    for k in range(2):
        wx = 3 if k == 0 else w - 6
        wy = oy + 4
        lit = lamp and rng.random() < 0.6
        for y in range(wy, wy + 6):
            for x in range(wx, wx + 4):
                if y > wy or x in (wx + 1, wx + 2):
                    c.set(x, y, ("sky" if x < wx + 2 else "azure") if lit else "night_d")
    c.outline_all(outline)
    for _ in range(weed):
        sx = rng.randrange(1, w)
        ln = rng.randrange(4, h)
        for y in range(oy - 1, oy - 1 + ln):
            xx = sx + int(math.sin(y * 0.7 + sx) * 0.8)
            if c.opaque(xx, y):
                c.set(xx, y, "grass" if y % 3 else "teal")
    return c


def scene_sunken_city() -> Scene26:
    """4-5 沉沒之城: the drowned city of Lyonesse in deep blue water. Seaweed-wrapped domed houses on a
    terrace, a colonnade and steps, the palace's towers far above; cyan lamps glow along the old
    plaza, where silt and sand drift over irregular paving."""
    sc = Scene26("steel", 0.5)
    img = sc.img
    K7.water_column(img, (0, 0, IMG_W, 170), [("sky", 0.0), ("water", 0.1), ("water_d", 0.45), ("night", 0.88)], 4501)
    K7.surface_ripples(img, 4, 4502, ("sky_l", "sky", "water"))
    # far: the palace on its hill (towers, faint cyan windows) and the hazy skyline
    K.hills_layer(img, 70, 10, 30.0, "water_d", rim="water", seed=4503, fill_to=100)
    for (x, w, h) in ((MIDX - 30, 10, 40), (MIDX + 22, 10, 36), (MIDX - 8, 16, 52)):
        t = K.round_tower(w, h, ("night", "water_d", "water_d", "water"), x, cone=("water_d", "water", "sky"),
                          cone_h=w, outline="night", windows=1, lit=False)
        img.blit(t, x, 72 - t.h + 6)
        img.set(x + w // 2 + 2, 72 - h + 12, "sky")
    rng = random.Random(4504)
    x = -10
    while x < IMG_W:
        w = rng.randrange(14, 24)
        d = _dome_house(w, rng.randrange(8, 16), x, ("water_d", "water_d", "water"), ("water_d", "water", "water"),
                        "night", weed=0, lamp=False)
        img.blit(d, x, 100 - d.h + rng.randrange(0, 5))
        x += w + rng.randrange(1, 6)
    for x in range(IMG_W):
        for y in range(98, 104):
            img.set(x, y, "water_d" if y < 101 else "night")
    # mid: the terrace wall, domed houses and the colonnade with steps in the middle
    wall = K.masonry(IMG_W, 26, ("night", "water_d", "water"), 4505, course=6, mortar="night_d", base_dark=6)
    img.blit(wall, 0, 134)
    x = -6
    k = 0
    while x < IMG_W:
        if 112 < x + 26 and x < 192:
            img.rect(114, 98, 76, 4, "water")
            img.hline(114, 189, 98, "sky")
            img.hline(114, 189, 102, "night_d")
            for cx in range(116, 190, 14):
                col = K7.column(32, 8, ("night", "water_d", "water", "sky"), "night_d",
                                broken=0.35 if cx == 144 else 0.0, seed=cx)
                img.blit(col, cx, 136 - col.h)
            x = 196
            continue
        w = rng.randrange(22, 30)
        d = _dome_house(w, rng.randrange(16, 22), x + k, ("water_d", "water", "sky"), ("teal", "grass", "spring"))
        img.blit(d, x, 136 - d.h)
        x += w + 3
        k += 1
    W.steps(img, MIDX - 30, MIDX + 30, 136, 5, ("water_d", "water", "sky"), depth=5)
    # the plaza: irregular old paving, sand drifting in from the edges, weed in the cracks
    K7.voronoi_stones(img, (0, 160, IMG_W, IMG_H), 15, ("steel", "steel"), "steel_d", 4506, squash=0.8,
                      mask=lambda x, y: not (abs(x - MIDX) < 45 and y < 162))
    for y in range(160, IMG_H):
        for x in range(IMG_W):
            k2 = W.calm_k(x, y, 40)
            n = fbm(x, y, 4507, 22, 3) + AW._cluster(x, y, 4507) * 0.06
            if n > 0.56 + k2 * 0.3:
                img.set(x, y, "sand" if n > 0.64 + k2 * 0.3 else "stone_l")
    K.edge_shadow(img, 160, 6, 0, IMG_W)
    K.calm_vignette(img, 10)
    # ruins round the plaza: columns, a fallen dog-knight statue, amphorae, a chest, seaweed
    for (x, y, h, b) in ((AX0 - 30, AY0 + 20, 54, 0.0), (AX1 + 6, AY0 + 10, 54, 0.35), (AX0 - 28, AY1 - 70, 44, 0.45),
                         (AX1 + 8, AY1 - 64, 50, 0.0)):
        col = K7.column(h, 12, ("steel_d", "steel", "steel_l", "white"), "night_d", broken=b, seed=x + y)
        AW.place(img, col, x, y, shadow=(1.0, -2), shadow_dx=6)
    drum = Canvas(16, 10)
    for yy in range(10):
        for xx in range(16):
            drum.set(xx, yy, "steel_l" if yy < 3 else ("steel" if yy < 8 else "steel_d"))
    drum.outline_all("night_d")
    AW.place(img, drum, AX0 + 4, AY1 - 16, shadow=(1.0, -1), shadow_dx=3)
    st = K.statue(4508, ("steel_d", "steel", "steel_l"), "night_d")
    AW.place(img, st, AX1 - 24, AY0 + 4, shadow=(1.0, -1), shadow_dx=4)
    for (x, y) in ((AX0 - 10, AY0 + 120), (AX1 + 2, AY0 + 150), (20, 360)):
        AW.place(img, K7.amphora(x), x, y, shadow=(0.9, -1), shadow_dx=2)
    AW.place(img, K7.treasure_chest(False), 254, 300, shadow=(1.0, -1), shadow_dx=3)
    K7.scatter_props(img, (AX0 - 40, AY0 + 4, AX1 + 40, AY1 + 30), 46, 4509,
                     lambda r: K7.sea_grass(r, ("deep", "teal", "grass")), calm=0.985)
    K7.scatter_props(img, (AX0 - 40, AY0 + 4, AX1 + 40, AY1 + 30), 30, 4510, K7.shell, calm=0.98)
    # bottom: the terrace edge and the roofs of the lower town
    wall2 = K.masonry(IMG_W, 16, ("night", "water_d", "water"), 4511, course=6, mortar="night_d", base_dark=0)
    img.blit(wall2, 0, AY1 + 26)
    for x in range(IMG_W):
        for y in range(AY1 + 42, IMG_H):
            img.set(x, y, "night" if y < AY1 + 60 else "night_d")
    x = -8
    while x < IMG_W:
        w = rng.randrange(20, 30)
        d = _dome_house(w, 18, x * 7, ("night", "water_d", "water"), ("teal", "grass", "spring"))
        img.blit(d, x, IMG_H - d.h + 12)
        x += w + 2
    # foreground: arch fragments in the top corners, kelp at the bottom
    for side in (0, 1):
        arch = Canvas(60, 46)
        for yy in range(46):
            for xx in range(60):
                d = math.hypot(xx - 60, yy - 46)
                if 30 < d < 40:
                    arch.set(xx, yy, "night" if d > 36 else "water_d")
        arch.outline_all("night_d")
        sc.put_fg(arch.flipped() if side else arch, 30 if side == 0 else IMG_W - 90, 78)
    for k, x in enumerate((-4, 22, 48, 230, 256, 282)):
        kelp = K7.seaweed_clump(4520 + k, 30, ("night_d", "deep", "teal"))
        sc.put_fg(kelp, x, 386 + (k % 3) * 4)
    for i, (x, y) in enumerate(((10, 104), (96, 102), (206, 106), (282, 100), (20, 300), (274, 220))):
        sc.anim("kelp", x, y, i % 6, 0.5 + (i % 3) * 0.1)
    for i, (x, y) in enumerate(((60, 96), (240, 94), (AX0 - 10, AY0 + 70), (AX1 + 6, AY1 - 20))):
        sc.anim("bubbles", x, y, i * 2, 0.6)
    for i, (x, y, k) in enumerate(((30, 40, "fish_blue"), (200, 60, "fish_blue"), (130, 20, "fish_gold"))):
        sc.anim(k, x, y, i * 3, 0.5)
    for i, (x, y) in enumerate(((104, 118), (196, 118), (AX0 - 16, AY0 + 6), (AX1 + 10, AY0 + 6), (AX0 - 16, AY1 - 6),
                                (AX1 + 10, AY1 - 6))):
        img.vline(x + 3, y + 10, y + 24, "night_d")
        img.hline(x + 1, x + 5, y + 24, "night_d")
        sc.anim("orb_cyan", x, y, i % 6, 0.7)
        sc.light("magic", x + 3, y + 5, 0.55, tint=(0.4, 0.95, 1.0))
    sc.light_shafts = [(-10, 16, 0.045, (0.7, 0.95, 1.0)), (70, 12, 0.04, (0.7, 0.95, 1.0))]
    sc.particle(kind="bubble", amount=12, lifetime=5.0, rect=(-10, 0, 190, 380), velocity=(0, -1), spread=10,
                speed=(6, 12), gravity=(0, -2), colour_fade=True)
    sc.particle(kind="mote", amount=12, lifetime=6.0, rect=(-10, -40, 200, 380), velocity=(1, 0.2), spread=180,
                speed=(1, 3), gravity=(0, 0), colour_fade=True)
    sc.particle(glow=True, kind="spark_cyan", amount=6, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(1, 3), gravity=(0, 0), blink=True)
    sc.modulate = (0.86, 0.94, 1.0)
    return sc


# ==========================================================================
# 4-6 sunken_palace
# ==========================================================================

def _clam(seed: int) -> Canvas:
    clam = Canvas(28, 18)
    for (cx, cy) in P.ellipse(14, 12, 13, 6):
        clam.set(cx, cy, "violet" if cy > 12 else "lilac")
    for (cx, cy) in P.ellipse(14, 6, 12, 6):
        if cy < 7:
            clam.set(cx, cy, "lilac" if cx < 14 else "violet")
    for k in range(5):
        x = 6 + k * 4
        clam.vline(x, 1 + abs(k - 2), 5, "violet")
    for (cx, cy) in P.ellipse(14, 9, 3.5, 3.5):
        clam.set(cx, cy, "white" if cx < 14 and cy < 9 else "steel_l")
    clam.outline_all("plum")
    return clam


def scene_sunken_palace() -> Scene26:
    """4-6 海底宮殿: the Kraken's throne hall. A pearl-marble wall with a gold frieze and arches open on the
    deep, coral-pink pillars, the great scallop throne on its dais; giant clams with pearls and open
    chests along the sides; a calm pearl floor with a faint turquoise ring."""
    sc = Scene26("steel_l", 0.5)
    img = sc.img
    K7.water_column(img, (0, 0, IMG_W, 60), [("water", 0.0), ("water_d", 0.5), ("night", 0.9)], 4601)
    # the back wall: pale stone, gold frieze, arches on the deep
    wall = K.masonry(IMG_W, 108, ("steel", "steel_l", "white"), 4602, course=8, brick=(14, 22), mortar="steel",
                     base_dark=8)
    img.blit(wall, 0, 48)
    for x in range(IMG_W):
        for (y, col) in ((48, "gold_d"), (49, "gold_l"), (50, "gold"), (51, "gold_d")):
            img.set(x, y, col)
        if x % 8 < 4:
            img.set(x, 50, "sky")
    for (cx, w) in ((34, 30), (270, 30), (MIDX, 72)):
        top = 58
        for y in range(top, 148):
            for x in range(cx - w // 2, cx + w // 2):
                dxn = (x + 0.5 - cx) / (w / 2)
                ay = top + (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * (w / 2)
                if y >= ay:
                    img.set(x, y, "night_d" if y < 96 else ("night" if y < 130 else "water_d"))
                elif y >= ay - 3:
                    img.set(x, y, "gold" if x < cx else "gold_d")
    K.stars(img, (MIDX - 30, 64, MIDX + 30, 104), 10, 4603, cols=("sky", "sky_l", "water"), big=0)
    for cx in (34, 270):
        K.stars(img, (cx - 10, 70, cx + 10, 120), 5, cx, cols=("sky", "water"), big=0)
    for x0 in (66, 96, 208, 238):
        col = K7.column(100, 12, ("red_d", "coral", "pink", "peach"), "wine", seed=x0)
        img.blit(col, x0 - col.w // 2, 54)
    throne = K7.scallop_throne()
    W.steps(img, MIDX - 44, MIDX + 44, AY0 - 14, 3, ("steel", "steel_l", "white"), depth=5)
    AW.place(img, throne, MIDX - throne.w // 2, AY0 - throne.h - 10, shadow=(1.0, -1), shadow_dx=4)
    for (x, y) in P.ellipse(MIDX, AY0 - throne.h - 10, 4, 4):
        img.set(x, y, "white" if x < MIDX and y < AY0 - throne.h - 10 else "steel_l")
    # the floor: big pearl-marble slabs, calm; a faint turquoise ring; gold border strips
    for y in range(AY0, IMG_H):
        for x in range(IMG_W):
            a, b = (x - MIDX + y) % 28, (x - MIDX - y) % 28
            col = "steel" if (a == 0 or b == 0) else ("white" if (a == 1 or b == 1) and fbm(x, y, 4604, 9, 2) > 0.55
                                                      else "steel_l")
            img.set(x, y, col)
            if a == 0 and b == 0 and not in_arena(x, y):
                img.set(x, y, "gold")
    W.rune_ring(img, MIDX, MIDY + 4, 80, "sky", "azure", ticks=16, width=1.0)
    for side in (0, 1):
        for x in range(AX0 - 6 if side == 0 else AX1 + 2, AX0 - 2 if side == 0 else AX1 + 6):
            for y in range(AY0, IMG_H):
                img.set(x, y, "gold_d" if x in (AX0 - 6, AX1 + 5) else ("gold" if (y // 6) % 2 else "gold_l"))
    for x in range(0, IMG_W):
        for y in range(AY0, IMG_H):
            if not (AX0 - 6 <= x < AX1 + 6) and name_at(img, x, y) == "steel_l":
                img.set(x, y, "azure" if ((x // 6) + (y // 6)) % 2 else "steel_l")
    K.edge_shadow(img, AY0, 6)
    K.calm_vignette(img, 10)
    # sides: giant clams with pearls, open chests, short coral pillars
    for (x, y) in ((8, 220), (256, 260), (14, 340)):
        AW.place(img, _clam(x), x, y, shadow=(1.0, -1), shadow_dx=3)
        sc.anim("glint_cyan", x + 9, y + 3, (x // 7) % 8, 0.7)
    for (x, y) in ((254, 340), (20, 280), (258, 200)):
        AW.place(img, K7.treasure_chest(True), x, y, shadow=(1.0, -1), shadow_dx=3)
        sc.anim("glint_gold", x + 3, y - 4, (x + y) % 8, 0.7)
    for (x, y) in ((AX0 - 30, AY1 - 10), (AX1 + 10, AY1 + 20)):
        col = K7.column(40, 10, ("red_d", "coral", "pink", "peach"), "wine", seed=x)
        AW.place(img, col, x, y - 40, shadow=(1.0, -1), shadow_dx=5)
    # bottom: a balustrade and the dark deep beyond, corals below
    for y in range(AY1 + 20, IMG_H):
        for x in range(IMG_W):
            img.set(x, y, "water_d" if y < AY1 + 40 else ("night" if y < AY1 + 70 else "night_d"))
    img.blit(K7.railing(IMG_W, 12, ("steel", "steel_l", "white"), "steel_d", step=7), 0, AY1 + 10)
    rng = random.Random(4610)
    x = -6
    while x < IMG_W:
        c = _coral_mix(rng, True)
        img.blit(c, x, AY1 + 80 - c.h + rng.randrange(0, 6))
        x += c.w - 3
    # foreground: dark coral pillars in the top corners, corals at the bottom
    for side in (0, 1):
        pil = K7.column(70, 18, ("wine", "red_d", "coral", "pink"), "ink")
        sc.put_fg(pil.flipped() if side else pil, 58 if side == 0 else IMG_W - 82, 70)
    for k, x in enumerate((-6, 24, 236, 264)):
        c = K7.branch_coral(4630 + k, 30, "coral")
        c.replace("coral", "red_d")
        c.replace("pink", "rose")
        c.replace("peach", "rose")
        sc.put_fg(c, x, 398 + (k % 2) * 4)
    for i, (x, y) in enumerate(((54, 100), (240, 96), (130, 70))):
        sc.anim("bubbles", x, y, i * 3, 0.7)
    for i, (x, y, k) in enumerate(((MIDX - 30, 66, "fish_gold"), (20, 70, "fish_blue"), (256, 80, "fish_blue"))):
        sc.anim(k, x, y, i * 2, 0.5)
    for i, (x, y) in enumerate(((AX0 - 18, AY0 + 2), (AX1 + 10, AY0 + 2), (AX0 - 18, AY1 - 30), (AX1 + 10, AY1 - 30),
                                (MIDX - 48, AY0 - 46), (MIDX + 42, AY0 - 46))):
        sc.anim("orb_cyan", x, y, i % 6, 0.7)
        sc.light("magic", x + 3, y + 5, 0.55, tint=(0.4, 0.95, 1.0))
    sc.anim("glint_cyan", MIDX - 4, AY0 - throne.h - 14, 0, 0.6)
    sc.light("magic", MIDX, AY0 - 34, 0.7, tint=(1.0, 0.8, 0.9))
    sc.light_shafts = [(MIDX - 80, 20, 0.05, (0.7, 0.95, 1.0)), (MIDX - 40, 14, 0.04, (0.7, 0.95, 1.0))]
    sc.particle(kind="bubble", amount=14, lifetime=5.0, rect=(-10, 0, 190, 380), velocity=(0, -1), spread=10,
                speed=(6, 12), gravity=(0, -2), colour_fade=True)
    sc.particle(glow=True, kind="spark_cyan", amount=8, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(1, 3), gravity=(0, 0), blink=True)
    sc.modulate = (0.9, 0.96, 1.0)
    return sc


SCENES = {
    "golden_beach": scene_golden_beach,
    "sea_cliffs": scene_sea_cliffs,
    "pirate_ship": scene_pirate_ship,
    "coral_reef": scene_coral_reef,
    "sunken_city": scene_sunken_city,
    "sunken_palace": scene_sunken_palace,
}
