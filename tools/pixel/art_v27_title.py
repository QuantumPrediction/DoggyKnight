"""v2.7 (CW8): the title backdrops for chapters 4-6. Python 3 standard library only.

    assets/ui/title_bg_4.png   chapter 4: a summer seaside - turquoise sea, the pirate ship, a lighthouse, palms
    assets/ui/title_bg_5.png   chapter 5: the twin-dragon mountain - snow on one flank, fire on the other,
                               the red and the white dragon circling its peak
    assets/ui/title_bg_6.png   chapter 6: Avalon at sunset - the sun on the lake, the isle with its orchard,
                               apple trees in blossom

Same frame as art_v26_title: 304x512, opaque palette art; screen 180x320 = image x 62..242, y 96..416.
The logo sits over image y ~140..190 (keep the sky calm there), the cast stands around y 240..310, the
buttons cover y ~320..410; detail lives along the horizon (HZ = 236) and at the sides.
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art_world as AW  # noqa: E402
import art_v26_kit as K  # noqa: E402
import art_v26_title as T  # noqa: E402
import art_v26_world as W  # noqa: E402
import art_v27_kit as K7  # noqa: E402
import art_v27_sea as SEA  # noqa: E402
import art_v27_snow as SNOW  # noqa: E402
import art_v27_dusk as DUSK  # noqa: E402
import paint as P  # noqa: E402
from palette import rgba  # noqa: E402
from pixel import Canvas, res_path  # noqa: E402

TW, TH = T.TW, T.TH
HZ = T.HZ


def dragon_silhouette(c: Canvas, x: int, y: int, body: tuple[str, str, str], flip: bool = False, s: float = 1.0) -> None:
    """A small chubby dragon flying in the title sky: round body, big head, curled tail, two bat wings
    raised (body = (shade, mid, light))."""
    d = Canvas(int(40 * s), int(30 * s))
    ox, oy = 18 * s, 18 * s
    wings = [P.poly([(ox - 2 * s, oy - 2 * s), (ox - 12 * s, oy - 16 * s), (ox - 4 * s, oy - 12 * s),
                     (ox + 2 * s, oy - 16 * s), (ox + 4 * s, oy - 3 * s)]),
             P.poly([(ox + 2 * s, oy - 3 * s), (ox + 12 * s, oy - 17 * s), (ox + 10 * s, oy - 8 * s),
                     (ox + 7 * s, oy - 2 * s)])]
    for k, wing in enumerate(wings):
        for (px, py) in wing:
            d.set(px, py, body[0] if k else body[1])
    for (px, py) in P.ellipse(ox, oy, 8 * s, 5.5 * s):
        d.set(px, py, body[2] if (px - ox) + (py - oy) < -3 * s else body[1])
    for (px, py) in P.ellipse(ox + 9 * s, oy - 5 * s, 4.5 * s, 4 * s):
        d.set(px, py, body[2] if px < ox + 9 * s else body[1])
    for k in range(int(12 * s)):
        tx = ox - 7 * s - k
        ty = oy + 2 * s + math.sin(k / (3 * s)) * 3 * s
        d.set(int(tx), int(ty), body[0])
        d.set(int(tx), int(ty) + 1, body[0])
    d.set(int(ox + 11 * s), int(oy - 6 * s), "ink")
    d.outline_all("ink")
    c.blit(d.flipped() if flip else d, int(x - 18 * s), int(y - 18 * s))


def title_bg_4() -> Canvas:
    """Chapter 4: a bright summer seaside. A turquoise sea under a high sun, the crab pirates' ship on the
    horizon, a lighthouse on its headland; palms frame a golden beach with a sandcastle and shells."""
    c = Canvas(TW, TH, rgba("sky"))
    K.sky_bands(c, 0, HZ, [("water", 0.0), ("sky", 0.18), ("azure", 0.45), ("sky_l", 0.66), ("haze", 0.86)], seed=4701,
                wave=2.0)
    T.sun_glow(c, TW * 0.72, 64, rings=((10, "white"), (16, "cream"), (26, "haze")), only=("sky", "azure", "sky_l"))
    W.cloud_bank(c, 100, ("sky_l", "haze", "white"), 4702, x0=-10, x1=110, size=(6.0, 10.0), step=14)
    W.cloud_bank(c, 212, ("sky_l", "haze", "white"), 4703, x0=180, x1=TW + 10, size=(5.0, 9.0), step=13)
    W.cloud_bank(c, 226, ("azure", "sky_l", "haze"), 4704, x0=-10, x1=TW + 10, size=(3.0, 5.0), step=9)
    # the sea and its shallows
    def shore(x: float) -> float:
        return HZ + 66 + 3 * math.sin(x / 23.0) + 1.5 * math.sin(x / 9.0)
    K7.sea(c, (0, HZ, TW, HZ + 72), [("water_d", 0.0), ("water", 0.08), ("sky", 0.45), ("azure", 0.82)], 4705,
           mask=lambda x, y: y < shore(x) - 1, rows=9, density=0.5)
    K7.glitter_path(c, TW * 0.72, HZ + 2, HZ + 56, 4706, cols=("white", "sky_l"), spread=0.35)
    # far headland with the lighthouse (right), the pirate ship (left), an island
    for x in range(196, TW):
        top = HZ - 16 + int(5 * math.sin((x - 196) / 30.0)) + max(0, 212 - x)
        for y in range(top, HZ + 3):
            c.set(x, y, "white" if x < 212 else ("stone_l" if y < top + 6 else "stone"))
        c.set(x, top, "leaf")
        c.set(x, top + 1, "leaf_d")
    lh = K7.lighthouse(34)
    c.blit(lh, 214, HZ - 16 - lh.h + 6)
    c.blit(SEA.tall_ship(36, 4), 72, HZ - 30)
    SEA._island(c, 160, HZ + 1, 16, 5, 4707, palms=2)
    # beach
    K7.sand_floor(c, (0, HZ + 50, TW, TH), 4708, mask=lambda x, y: y >= shore(x))
    K7.shoreline(c, 0, TW, shore, 4709, wet="dirt", shallow="azure", wet_depth=5)
    rng = random.Random(4710)
    for _ in range(60):
        x, y = rng.randrange(0, TW - 5), rng.randrange(HZ + 80, TH - 4)
        c.blit(K7.shell(rng) if rng.random() < 0.8 else K7.starfish(rng), x, y)
    castle = Canvas(34, 26)
    for (x0, w, h) in ((1, 8, 14), (24, 8, 15), (8, 17, 10), (12, 9, 20)):
        for y in range(26 - h, 26):
            for x in range(x0, x0 + w):
                castle.set(x, y, "cream" if x < x0 + 2 else ("sand" if x < x0 + w - 2 else "dirt"))
        for x in range(x0, x0 + w, 2):
            castle.set(x, 25 - h, "sand")
    castle.rect(14, 19, 5, 7, "gold_d")
    castle.outline_all("gold_d")
    AW.place(c, castle, 214, 300, shadow=(1.0, -1), shadow_dx=5)
    c.vline(229, 286, 300, "brown_d")
    for k in range(5):
        c.hline(230, 230 + 4 - k, 287 + k, "red")
    AW.place(c, K7.rowboat(32, ("brown_d", "red_d", "red"), stripe="cream"), 16, 318, shadow=(1.0, -1), shadow_dx=4)
    for (x, y, h, lean, flip) in ((-4, 190, 72, 0.3, False), (34, 226, 58, 0.2, False), (194, 194, 72, 0.25, True),
                                  (232, 230, 56, 0.3, True)):
        AW.place(c, K7.palm(x + y, h, lean, flip), x, y, shadow=(0.7, -2), shadow_dx=10)
    for x in range(TW):
        top = 420 + int(5 * math.sin(x / 23.0) + 2 * math.sin(x / 9.0))
        for y in range(top, TH):
            c.set(x, y, "cream" if y < top + 2 else ("sand" if AW.fbm(x, y, 4711, 24, 2) > 0.42 else "dirt"))
    for i, x in enumerate(range(-6, TW, 17)):
        tuft = AW.blob_canvas(16, 12, [(5, 7, 4), (10, 6, 5)], ["moss_d", "moss", "leaf_l", "spring"], "forest", 4712 + i)
        c.blit(tuft, x, 414 + (i * 5) % 10)
    AW.paint_path(c, [(150, 520), (146, 460), (140, 400), (136, 340)], 14, 4713, ramp=("dirt", "sand", "cream"),
                  pebbles=0, edge_dark=False)
    return c


def title_bg_5() -> Canvas:
    """Chapter 5: the twin-dragon mountain. The great peak fills the horizon - its left flank under snow,
    its right flank red rock with lava seams and smoke - while the white dragon and the red dragon circle
    it; snowy pines and a mountain path in front."""
    c = Canvas(TW, TH, rgba("sky"))
    for y in range(HZ):
        for x in range(TW):
            t = y / HZ + 0.03 * math.sin(x / 13.0 + y * 0.05)
            u = (x - TW / 2) / TW + 0.06 * math.sin(y / 11.0)
            if u < 0:
                col = "water" if t < 0.2 else ("sky" if t < 0.45 else ("azure" if t < 0.7 else "sky_l"))
            else:
                col = "wine" if t < 0.2 else ("red_d" if t < 0.45 else ("coral" if t < 0.7 else "peach"))
            c.set(x, y, col)
    K.stars(c, (0, 0, TW // 2, 60), 20, 4801, big=2)
    W.cloud_bank(c, 120, ("sky_l", "white", "white"), 4802, x0=-10, x1=90, size=(6.0, 9.0), step=12)
    W.cloud_bank(c, 112, ("rose", "peach", "cream"), 4803, x0=214, x1=TW + 10, size=(6.0, 9.0), step=12)
    SNOW.twin_mountain(c, TW // 2, HZ + 4, 118, 128, 4804)
    K.peaks_layer(c, HZ + 4, [(10, 40, 50), (70, 30, 40)], "steel_l", "steel", rim="white", seed=4805, x0=0, x1=110)
    K.peaks_layer(c, HZ + 4, [(240, 34, 46), (300, 42, 50)], "red_d", "wine", rim="coral", seed=4806, x0=196, x1=TW)
    dragon_silhouette(c, 84, 118, ("steel", "steel_l", "white"), flip=False, s=1.2)
    dragon_silhouette(c, 224, 132, ("red_d", "red", "coral"), flip=True, s=1.2)
    for x in range(TW):
        for y in range(HZ - 2, HZ + 6):
            if AW.name_at(c, x, y) is None:
                c.set(x, y, "steel_l")
    # foothills: snow on the left, warm rock on the right, pines
    T.hill_band(c, HZ + 14, 4, 41.0, ("steel_l", "steel_l", "white"), 4807, x1=TW // 2 + 20)
    T.hill_band(c, HZ + 16, 4, 37.0, ("stone_d", "stone_d", "stone"), 4808, x0=TW // 2 + 20)
    for i, x in enumerate(range(-10, TW, 15)):
        if 110 < x < 190:
            continue
        if x < TW // 2:
            p = K7.snow_pine(4810 + i, 34 + (i * 7) % 14)
        else:
            p = K7.autumn_tree(4810 + i, 26, ("red", "orange")[i % 2])
        AW.place(c, p, x, HZ + 40 - p.h + (i * 5) % 8, shadow=None)
    T.hill_band(c, HZ + 60, 6, 57.0, ("steel_l", "steel_l", "white"), 4811, rim="white")
    for x in range(TW):
        for y in range(HZ + 54, TH):
            if AW.name_at(c, x, y) in ("steel", "steel_l", "white") and x > TW // 2 + 30 + 12 * math.sin(y / 17.0):
                c.set(x, y, {"steel": "stone_d", "steel_l": "stone_d", "white": "stone"}[AW.name_at(c, x, y)])
    for x in range(TW):
        for y in range(HZ + 50, TH):
            n = AW.name_at(c, x, y)
            if n in ("steel", "steel_l", "white"):
                c.set(x, y, "white" if AW.fbm(x, y, 4813, 30, 3) > 0.58 else "steel_l")
            elif n in ("stone_d", "stone", "stone_l"):
                c.set(x, y, "stone" if AW.fbm(x, y, 4814, 30, 3) > 0.6 else "stone_d")
    rng = random.Random(4815)
    for k in range(14):
        x, y = rng.randrange(TW // 2 + 50, TW), rng.randrange(HZ + 70, TH)
        if AW.name_at(c, x, y) in ("stone", "stone_d"):
            K7.glow_crack(c, x, y, rng.randrange(8, 16), 4816 + k)
    AW.paint_path(c, [(150, 520), (146, 440), (140, 380), (138, HZ + 66)], 14, 4812, ramp=("steel", "fog", "steel_l"),
                  pebbles=0, edge_dark=False)
    for i, (x, y) in enumerate(((-6, 260), (16, 280), (250, 268), (274, 286), (-4, 360), (266, 370))):
        if x < TW // 2:
            AW.place(c, K7.snow_pine(4820 + i, 58 + (i % 3) * 8), x, y)
        else:
            AW.place(c, K7.basalt(4820 + i, 26, 16, glow=True), x, y + 40)
    for i, (x, y) in enumerate(((40, 350), (222, 356), (20, 430), (248, 436), (126, 486))):
        if x < TW // 2:
            AW.place(c, K7.snow_rock(4830 + i, 18, 11), x, y)
        else:
            AW.place(c, K7.basalt(4830 + i, 18, 11, glow=i % 2 == 0), x, y)
    return c


def title_bg_6() -> Canvas:
    """Chapter 6: Avalon at sunset. A great sun sinks into the lake and lays a road of gold towards the isle
    with its orchard and white tower; blossoming apple trees frame the green hill in front."""
    c = Canvas(TW, TH, rgba("peach"))
    DUSK.dusk_sky(c, HZ, 4901, [("plum", 0.0), ("dusk", 0.18), ("rose", 0.4), ("coral", 0.6), ("peach", 0.76),
                                ("gold_l", 0.9)])
    K.stars(c, (0, 0, TW, 50), 24, 4902, big=2)
    DUSK.long_clouds(c, [(70, -10, 120), (90, 170, 320), (120, 20, 150), (204, 200, 320), (214, -10, 90)],
                     ("rose", "peach"), 4903)
    DUSK.sun_disc(c, TW * 0.5, HZ - 2, 20, rings=((1.0, "cream"), (1.7, "gold_l"), (2.6, "peach")), horizon=HZ)
    # the isle of Avalon (right) and a far shore (left)
    for (cx, w, h, cols) in ((236, 64, 16, ("dusk", "plum")), (40, 50, 9, ("rose", "dusk"))):
        for x in range(cx - w, cx + w):
            top = HZ - int(h * max(0.0, 1 - ((x - cx) / w) ** 2))
            for y in range(top, HZ + 1):
                c.set(x, y, cols[0] if x < cx + w * 0.3 else cols[1])
        K.treeline(c, HZ - h + 4, ("plum", "dusk", "dusk", "rose"), cx, size=(2.5, 4.5), step=4, x0=cx - w + 10,
                   x1=cx + w - 10, jitter=2)
    c.rect(236, HZ - 46, 7, 30, "peach")
    c.vline(242, HZ - 46, HZ - 17, "rose")
    for k in range(7):
        c.hline(235 + k // 2, 243 - k // 2, HZ - 52 + k, "rose")
    c.set(239, HZ - 38, "gold_l")
    # the lake with the sun's road of gold
    W.water_bands(c, (0, HZ, TW, HZ + 74), [("peach", 0.0), ("rose", 0.22), ("dusk", 0.55), ("plum", 0.88)], 4904,
                  glints=("coral",), n_glints=50)
    K7.glitter_path(c, TW * 0.5, HZ + 1, HZ + 70, 4905, cols=("cream", "gold_l"), spread=0.5)
    # the green hill, flowers, the path, apple trees in blossom
    for x in range(TW):
        sy = HZ + 72 + int(3 * math.sin(x / 19.0))
        for y in range(sy, sy + 3):
            c.set(x, y, "peach" if y == sy else "stone_l")
    T.hill_band(c, HZ + 78, 5, 47.0, ("leaf_d", "leaf", "spring"), 4906, rim="leaf_l")
    T.hill_band(c, HZ + 110, 6, 61.0, ("leaf_d", "leaf", "spring"), 4907, rim="leaf_l")
    AW.sprinkle_flowers(c, (0, HZ + 90, TW, TH), 150, 4909, ["white", "pink", "yellow"])
    for i, (x, y) in enumerate(((10, 214), (38, 246), (214, 220), (238, 250), (-10, 330), (262, 338))):
        AW.place(c, K7.apple_tree(4910 + i, 48 + (i % 3) * 6, bloom=0.6, apples=1), x, y, shadow=(1.0, -2), shadow_dx=6)
    for i, (x, y) in enumerate(((40, 352), (222, 356), (20, 430), (248, 436), (126, 486))):
        AW.place(c, AW.bush(4920 + i, 18, 11, ("forest", "leaf_d", "leaf", "spring"), "forest_d",
                            flowers=["pink", "white"]), x, y)
    return c


def write_all(preview_dir: str | None = None) -> None:
    for name, fn in (("title_bg_4", title_bg_4), ("title_bg_5", title_bg_5), ("title_bg_6", title_bg_6)):
        img = fn()
        img.save(res_path("res://assets/ui/%s.png" % name), opaque=True)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            img.scaled(2).save(os.path.join(preview_dir, "%s.png" % name))


if __name__ == "__main__":
    pdir = None
    if "--preview" in sys.argv:
        pdir = sys.argv[sys.argv.index("--preview") + 1]
    write_all(pdir)
    print("v2.7 title backdrops written")
