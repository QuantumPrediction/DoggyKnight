"""v2.6 (CW3): the three title backdrops and the chapter lock icon. Python 3 standard library only.

    assets/ui/title_bg.png     chapter 1: morning hills, Camelot far away, the sword in the stone
    assets/ui/title_bg_2.png   chapter 2: Camelot itself in the warm late afternoon, flags and thorns
    assets/ui/title_bg_3.png   chapter 3: night over the misty lake and Morgana's tower on its island
    assets/ui/icon_lock.png    9x11 padlock for locked chapters on the title's chapter select

Each backdrop is 304x512 (palette colours only, opaque); its centre is the centre of the screen
(screen 180x320 = image x 62..242, y 96..416). The logo sits over image y ~140..190, the cast stands
around image y 240..310 and the buttons cover y ~320..410, so the detail lives in the sky band,
along the horizon and at the sides. The mountains use art_v26_kit.peaks_layer: one lit face and one
shaded face per peak (the old title shaded every column by the sign of the slope, which striped them).
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
import art_v26_world as W  # noqa: E402
import paint as P  # noqa: E402
from palette import rgba  # noqa: E402
from pixel import Canvas, res_path  # noqa: E402

TW, TH = 304, 512
HZ = 236           # horizon (image y): just under the subtitle


def sun_glow(c: Canvas, sx: float, sy: float, rings=((14, "white"), (24, "cream"), (38, "haze")),
             only=("sky_l", "azure", "haze", "sky")) -> None:
    for y in range(max(0, int(sy - 60)), min(c.h, int(sy + 40))):
        for x in range(c.w):
            d = math.hypot((x - sx) / 1.5, y - sy)
            for r, col in rings:
                if d < r:
                    if col != rings[-1][1] or AW.name_at(c, x, y) in only:
                        c.set(x, y, col)
                    break


def castle(c: Canvas, x0: int, base: int, scale: float = 1.0, wall=("lilac", "stone_l", "white"),
           roof=("rose", "coral", "peach"), outline: str | None = None, flags: bool = True) -> None:
    """Camelot as a far silhouette: curtain wall, keep and towers with pointed roofs and flags."""
    s = scale
    parts = [(0, 40, 12), (6, 7, 30), (-4, 7, 24), (30, 7, 22), (16, 9, 40), (40, 6, 18)]
    for (dx, w, h) in parts:
        x, ww, hh = x0 + int(dx * s), max(3, int(w * s)), int(h * s)
        for y in range(base - hh, base):
            for xx in range(x, x + ww):
                c.set(xx, y, wall[2] if xx == x else (wall[1] if xx < x + ww - 1 else wall[0]))
        if ww <= int(9 * s) + 1 and hh > 14 * s:
            ch = int(ww * 1.1) + 2
            for k in range(ch):
                half = (k + 1) / ch * (ww / 2 + 1)
                for xx in range(int(x + ww / 2 - half), int(x + ww / 2 + half) + 1):
                    c.set(xx, base - hh - ch + k, roof[2] if xx < x + ww / 2 else roof[0])
            if flags:
                fx, fy = int(x + ww / 2), base - hh - ch - 5
                c.vline(fx, fy, fy + 4, "plum")
                c.set(fx + 1, fy, "red")
                c.set(fx + 2, fy, "red")
                c.set(fx + 1, fy + 1, "red_d")
        else:
            for k in range(0, ww, 3):
                c.set(x + k, base - hh - 1, wall[1])
    for (wx, wy) in ((x0 + int(10 * s), base - int(8 * s)), (x0 + int(20 * s), base - int(28 * s)),
                     (x0 + int(33 * s), base - int(14 * s))):
        c.set(wx, wy, "yellow")
        c.set(wx, wy + 1, "orange")


def hill_band(c: Canvas, base: int, amp: float, period: float, ramp: tuple[str, str, str], seed: int,
              x0: int = 0, x1: int | None = None, rim: str | None = None) -> list[int]:
    """A rolling grassy hill band: rim highlight, soft ground patches below, darker under the next band."""
    x1 = c.w if x1 is None else x1
    tops = []
    for x in range(x0, x1):
        top = int(base - amp * math.sin(x / period + seed) - amp * 0.35 * math.sin(x / (period * 0.43) + seed * 2))
        tops.append(top)
        for y in range(top, c.h):
            c.set(x, y, ramp[1])
    AW.paint_ground(c, (x0, min(tops), x1, c.h), ramp, seed, scale=26, tufts=0.35, max_light=0.22, max_dark=0.18,
                    mask=lambda x, y: 0 <= x - x0 < len(tops) and y >= tops[x - x0])
    for i, t in enumerate(tops):
        c.set(x0 + i, t, rim or ramp[2])
        if (x0 + i) % 3:
            c.set(x0 + i, t + 1, rim or ramp[2])
    return tops


def title_bg_1() -> Canvas:
    """Chapter 1: a fresh morning. Two mountain ranges (pale far, violet near) with clean lit/shade faces,
    Camelot on the ridge, the forest line, rolling hills; the sword in the stone on the right rise."""
    c = Canvas(TW, TH, rgba("sky"))
    K.sky_bands(c, 0, HZ, [("water", 0.0), ("sky", 0.16), ("azure", 0.42), ("sky_l", 0.6), ("haze", 0.78),
                            ("cream", 0.92)], seed=4, wave=2.0)
    sun_glow(c, TW * 0.36, HZ - 8)
    K.peaks_layer(c, HZ - 4, [(20, 56, 56), (96, 74, 66), (176, 50, 54), (246, 66, 60), (310, 54, 50)],
                  "fog", "lilac", rim="white", snow=("white", "steel_l"), seed=41, rough=1.2)
    K.peaks_layer(c, HZ - 2, [(-10, 30, 50), (60, 40, 58), (140, 28, 50), (214, 44, 62), (290, 32, 50)],
                  "lilac", "violet", rim="fog", seed=42, rough=1.0)
    castle(c, int(TW * 0.58), HZ - 22, 1.0)
    for x in range(TW):
        for y in range(HZ - 12, HZ):
            if AW.name_at(c, x, y) in ("lilac", "violet", "fog") and y > HZ - 8:
                c.set(x, y, "violet" if AW.name_at(c, x, y) == "lilac" else AW.name_at(c, x, y))
    K.treeline(c, HZ + 2, ("forest", "leaf_d", "leaf_d", "leaf"), 4401, size=(4.0, 7.0), step=5, outline="forest_d",
               jitter=3)
    hill_band(c, HZ + 12, 4, 41.0, ("leaf_d", "leaf", "leaf_l"), 11)
    hill_band(c, HZ + 34, 6, 57.0, ("leaf_d", "leaf", "leaf_l"), 12, rim="spring")
    # the rise with the sword in the stone (right) and Goldie's hill (left)
    for x in range(150, TW):
        top = int(272 - 16 * math.exp(-((x - 214) / 34.0) ** 2))
        for y in range(top, 300):
            c.set(x, y, "leaf_l" if y < top + 2 else ("spring" if y < top + 5 else "leaf"))
        c.set(x, top - 1, "leaf_d")
    AW.soft_light(c, 214, 262, 40, 14, +1, 0.5)
    AW.place(c, AW.sword_in_stone(), 214 - 26, 256 - 36, shadow=(0.9, -4), shadow_dx=5)
    for x in range(0, 170):
        top = int(298 - 10 * math.exp(-((x - 100) / 40.0) ** 2))
        for y in range(top, 312):
            c.set(x, y, "leaf_l" if y < top + 2 else (AW.name_at(c, x, y) or "leaf"))
        c.set(x, top - 1, "leaf_d")
    AW.paint_path(c, [(150, 520), (140, 440), (120, 380), (110, 320), (108, 300)], 13, 930, pebbles=20)
    for i, (x, y) in enumerate(((14, 228), (40, 252), (248, 246), (228, 282))):
        AW.place(c, AW.tree(900 + i, 34), x, y)
    for i, (x, y) in enumerate(((40, 330), (222, 336), (20, 420), (248, 430), (130, 480))):
        AW.place(c, AW.bush(920 + i, 18, 11, AW.TREE_GREEN, flowers=["white", "pink"]), x, y)
    AW.sprinkle_flowers(c, (0, HZ + 20, TW, TH), 160, 4407, ["white", "yellow", "pink"])
    return c


def title_bg_2() -> Canvas:
    """Chapter 2: Camelot up close in the warm late afternoon. The castle fills the horizon (towers with
    red roofs, flags, a few purple thorns of the sleeping spell); the road leads up to its gate."""
    c = Canvas(TW, TH, rgba("sky"))
    K.sky_bands(c, 0, HZ, [("sky", 0.0), ("azure", 0.3), ("haze", 0.55), ("cream", 0.72), ("peach", 0.88)],
                seed=5, wave=2.0)
    sun_glow(c, TW * 0.7, HZ - 30, rings=((12, "white"), (20, "cream"), (32, "peach")),
             only=("haze", "cream", "azure"))
    K.peaks_layer(c, HZ - 6, [(30, 40, 60), (140, 30, 60), (260, 44, 60)], "peach", "rose", rim="cream", seed=51)
    # the castle: curtain wall, keep, round towers
    base = HZ + 20
    wall = K.masonry(TW, 34, ("stone", "stone_l", "white"), 5201, course=6, brick=(9, 15), mortar="stone_d",
                     base_dark=6)
    c.blit(wall, 0, base - 34)
    c.blit(K.crenels(TW, 7, 5, 6, ("stone", "stone_l", "white"), "stone_d"), 0, base - 41)
    keep = K.masonry(84, 64, ("stone", "stone_l", "white"), 5202, course=6, mortar="stone_d", base_dark=0)
    c.blit(keep, 110, base - 98)
    c.blit(K.crenels(84, 7, 5, 6, ("stone", "stone_l", "white"), "stone_d"), 110, base - 105)
    for (tx, w, h, cone) in ((30, 26, 96, 24), (96, 20, 112, 22), (208, 20, 116, 22), (274, 26, 98, 24),
                             (152, 22, 140, 26)):
        t = K.round_tower(w, h, ("stone_d", "stone", "stone_l", "white"), tx, cone=("red_d", "red", "coral"),
                          cone_h=cone, outline="umber", windows=2)
        c.blit(t, tx - t.w // 2, base - t.h + 2)
        fx, fy = tx, base - t.h - 6
        c.vline(fx, fy, fy + 6, "umber")
        for k in range(6):
            for j in range(3 - k // 2):
                c.set(fx + 1 + k, fy + j + (k % 2), "red" if j < 2 else "red_d")
    # the gate (open, warm light inside) and banners on the keep
    gx = 152
    for y in range(base - 30, base):
        for x in range(gx - 12, gx + 12):
            dxn = (x + 0.5 - gx) / 12
            if y >= base - 30 + (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * 10:
                c.set(x, y, "gold_l" if abs(x + 0.5 - gx) < 9 and y > base - 24 else "brown_d")
    for x in (124, 172):
        for y in range(base - 92, base - 60):
            for xx in range(x, x + 8):
                if y < base - 64 or abs(xx - x - 3.5) > (y - base + 64) * 1.2:
                    c.set(xx, y, "red" if xx > x else "coral")
        c.set(x + 3, base - 80, "gold_l")
        c.set(x + 4, base - 80, "gold_l")
    for k in range(7):
        K.thorn_vine(c, 20 + k * 44, base - 1, 22 + k % 3 * 6, 5210 + k)
    # town roofs in front of the wall, the road, hills and framing trees
    roofs = Canvas(TW, 40)
    W.house_row(roofs, 40, -8, TW + 8, 5220, [("stone", "stone_l", "white"), ("dirt", "sand", "cream")],
                [("red_d", "red", "coral"), ("brown_d", "brown", "gold_d")], heights=(10, 14), widths=(20, 30),
                thorns=0.3, lit=0.6, timber=0.5)
    c.blit(roofs, 0, base - 18)
    hill_band(c, base + 26, 4, 47.0, ("leaf_d", "leaf", "leaf_l"), 21)
    hill_band(c, base + 50, 6, 61.0, ("leaf_d", "leaf", "leaf_l"), 22, rim="spring")
    AW.paint_path(c, [(150, 520), (146, 440), (150, 360), (152, 300), (152, base + 24)], 16, 5230, pebbles=24)
    for i, (x, y) in enumerate(((6, 262), (34, 286), (252, 270), (232, 300))):
        AW.place(c, AW.tree(5240 + i, 34), x, y)
    for i, (x, y) in enumerate(((40, 340), (226, 344), (20, 420), (248, 430), (128, 482))):
        AW.place(c, AW.bush(5250 + i, 18, 11, AW.TREE_GREEN, flowers=["red", "pink", "white"]), x, y)
    AW.sprinkle_flowers(c, (0, base + 30, TW, TH), 140, 5260, ["white", "yellow", "pink", "red"])
    return c


def title_bg_3() -> Canvas:
    """Chapter 3: night over the misty lake. A big moon, stars, dark mountains; Morgana's tall tower on
    its island with a violet window; moonlight on the water; the shore with reeds and pines."""
    c = Canvas(TW, TH, rgba("navy"))
    K.sky_bands(c, 0, HZ, [("navy", 0.0), ("night_d", 0.25), ("night", 0.6), ("dusk", 0.86)], seed=6, wave=2.0)
    K.stars(c, (0, 0, TW, HZ - 60), 70, 6301, big=5)
    K.moon(c, TW * 0.3, 110, 22, halo=("night", "water_d"))
    K.peaks_layer(c, HZ, [(10, 50, 56), (90, 64, 64), (190, 46, 56), (280, 60, 60)], "night", "night_d",
                  rim="water_d", seed=61, rough=1.4)
    K.peaks_layer(c, HZ + 2, [(-20, 26, 50), (60, 30, 54), (150, 22, 50), (240, 34, 60), (320, 26, 50)],
                  "night_d", "navy", rim="night", seed=62)
    # the lake with the moon's path of light
    W.water_bands(c, (0, HZ, TW, HZ + 74), [("night_d", 0.0), ("night", 0.3), ("water_d", 0.65)], 6302,
                  glints=("steel", "steel_l"), n_glints=60)
    mx = int(TW * 0.3)
    rng = random.Random(6303)
    for y in range(HZ + 2, HZ + 72, 2):
        half = 3 + (y - HZ) * 0.18
        for _ in range(3):
            x = int(mx + rng.uniform(-half, half))
            ln = rng.randrange(2, 6)
            for k in range(ln):
                c.set(x + k, y, "fog" if y < HZ + 30 else "steel_l")
    # the island and Morgana's tower
    ix = int(TW * 0.66)
    for y in range(HZ - 4, HZ + 10):
        for x in range(ix - 34, ix + 34):
            if y - (HZ - 4) >= abs(x - ix) * 0.3 - 2:
                c.set(x, y, "navy" if x > ix - 10 else "night_d")
    for y in range(HZ - 128, HZ):
        half = 5 + (y - (HZ - 128)) * 0.05
        for x in range(int(ix - half), int(ix + half) + 1):
            u = (x - (ix - half)) / (2 * half)
            c.set(x, y, "slate" if u < 0.3 else ("night_d" if u < 0.75 else "navy"))
    for y in range(HZ - 150, HZ - 126):
        half = (y - (HZ - 150)) * 0.33 + 0.5
        for x in range(int(ix - half), int(ix + half) + 1):
            c.set(x, y, "dusk" if x < ix else "plum")
    for (wy, col) in ((HZ - 112, "lilac"), (HZ - 80, "violet"), (HZ - 46, "violet")):
        c.set(ix - 1, wy, col)
        c.set(ix, wy, col)
        c.set(ix - 1, wy + 1, "plum")
        c.set(ix, wy + 1, col)
    for k in range(4):
        y = HZ + 6 + k * 3
        for x in range(ix - 4, ix + 5):
            if (x + k) % 2 == 0:
                c.set(x, y, "plum")
    # mist bands on the water (palette fog in soft clusters)
    for k, (y0, x0, w) in enumerate(((HZ + 8, 20, 120), (HZ + 22, 150, 140), (HZ + 40, -10, 110))):
        for y in range(y0, y0 + 5):
            for x in range(x0, x0 + w):
                e = 1 - abs(y - y0 - 2) / 3
                if AW.fbm(x, y, 6310 + k, 9, 2) * e > 0.32:
                    c.set(x, y, "ash" if e < 0.7 else "fog")
    # near shore: cool grass, reeds, pines at the sides
    for x in range(TW):
        sy = HZ + 72 + int(3 * math.sin(x / 19.0))
        for y in range(sy, TH):
            c.set(x, y, "teal")
        for y in range(sy, sy + 3):
            c.set(x, y, "ash" if y == sy else "slate")
    AW.paint_ground(c, (0, HZ + 74, TW, TH), ("deep", "teal", "leaf_d"), 6311, scale=26, tufts=0.4,
                    max_light=0.2, max_dark=0.2, mask=lambda x, y: y > HZ + 75 + 3 * math.sin(x / 19.0))
    for k, x in enumerate(range(-4, TW, 16)):
        if 60 < x < 240:
            continue
        c.blit(K.reeds(6320 + k, 14 + k % 3 * 3), x, HZ + 58 + (k % 2) * 3)
    for i, (x, y) in enumerate(((-6, 250), (18, 262), (250, 254), (274, 270), (-4, 300), (264, 306))):
        AW.place(c, AW.pine(6330 + i, 54 + (i % 3) * 8, ("deep", "teal", "grass"), "navy"), x, y)
    for i, (x, y) in enumerate(((40, 352), (222, 356), (20, 430), (248, 436), (126, 486))):
        AW.place(c, AW.bush(6340 + i, 18, 11, ("deep", "teal", "grass", "leaf"), "navy", flowers=["lilac", "white"]),
                 x, y)
    AW.paint_path(c, [(150, 520), (146, 440), (140, 380), (132, HZ + 80)], 13, 6350, pebbles=14,
                  ramp=("slate", "ash", "fog"))
    return c


def lock_icon() -> Canvas:
    """A small gold padlock (9x11) with a steel shackle and an ink outline."""
    c = Canvas(9, 11)
    for x in range(3, 6):
        c.set(x, 1, "steel_l")
    for y in range(2, 5):
        c.set(2, y, "steel_l")
        c.set(6, y, "steel")
    for y in range(5, 10):
        for x in range(1, 8):
            c.set(x, y, "gold_l" if y == 5 else ("gold" if x < 5 else "gold_d"))
    c.set(4, 7, "umber")
    c.set(4, 8, "umber")
    c.outline_all("ink")
    return c


def write_all(preview_dir: str | None = None) -> None:
    for name, fn in (("title_bg", title_bg_1), ("title_bg_2", title_bg_2), ("title_bg_3", title_bg_3)):
        img = fn()
        img.save(res_path("res://assets/ui/%s.png" % name), opaque=True)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            img.scaled(2).save(os.path.join(preview_dir, "%s.png" % name))
    lock_icon().save(res_path("res://assets/ui/icon_lock.png"))


if __name__ == "__main__":
    pdir = None
    if "--preview" in sys.argv:
        pdir = sys.argv[sys.argv.index("--preview") + 1]
    write_all(pdir)
    print("title backdrops written")
