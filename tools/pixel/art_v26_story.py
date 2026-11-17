"""v2.6 (CW4): the eleven storybook pages of chapters 2 and 3 (docs/STORY.md section 11).

assets/story/<id>.png, 160x120, opaque, palette colours only. Same storybook framing as v2.3 (soft
printed-page rim), but the v2.6 look: clean colour bands instead of noisy dither, the v2.5 sprites for
Goldie, Bedivere and Merlin, and recoloured Goldie sprites for the new dogs (Lancelot the shiba,
the white samoyed Lady of the Lake, Morgana the red fox in her violet cloak). The Green Knight is
painted here as a big friendly hedge with a round leafy hat.

    python3 tools/pixel/art_v26_story.py [ids...] [--preview DIR]
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art_story as S  # noqa: E402
import art_v25_bulldog  # noqa: E402
import art_v25_goldie  # noqa: E402
import art_v25_knights  # noqa: E402
import art_v26_kit as K  # noqa: E402
import art_v26_title as T  # noqa: E402
import art_v26_world as WD  # noqa: E402
import art_world as AW  # noqa: E402
import paint as P  # noqa: E402
from palette import rgba  # noqa: E402
from pixel import Canvas, res_path  # noqa: E402

W, H = 160, 120
IDS = ["c2_prologue_1", "c2_prologue_2", "c2_ending_1", "c2_ending_2", "c2_ending_3", "teaser_2",
       "c3_prologue_1", "c3_prologue_2", "c3_ending_1", "c3_ending_2", "c3_ending_3"]

_CACHE: dict = {}


def sprites() -> dict:
    if not _CACHE:
        _CACHE["goldie"] = art_v25_goldie.goldie_v25()
        _CACHE["bulldog"] = art_v25_bulldog.bulldog_v25()
        _CACHE["merlin"] = art_v25_knights.merlin_v25()
    return _CACHE


def frame(code: str, anim: str, i: int = 0) -> Canvas:
    return S.frame_of(sprites()[code], anim, i)


LANCELOT = {"gold_l": "peach", "gold": "orange", "gold_d": "brown", "brown": "brown_d", "wine": "navy",
            "red_d": "water_d", "red": "water", "coral": "sky"}
LADY = {"gold_l": "white", "gold": "fog", "gold_d": "ash", "brown": "slate", "brown_d": "ash", "cream": "white",
        "wine": "water_d", "red_d": "water", "red": "sky", "coral": "sky_l", "steel_l": "sky_l", "steel": "azure",
        "steel_d": "sky", "iron": "water", "navy": "water_d"}
MORGANA = {"gold_l": "orange", "gold": "gold_d", "gold_d": "brown", "brown": "brown_d", "wine": "plum",
           "red_d": "plum", "red": "violet", "coral": "lilac", "steel_l": "lilac", "steel": "violet",
           "steel_d": "dusk", "iron": "plum", "navy": "ink"}


def dog(kind: str, anim: str = "idle", i: int = 0, flip: bool = False) -> Canvas:
    if kind in ("goldie", "bulldog", "merlin"):
        img = frame(kind, anim, i)
    else:
        img = S.recolor(frame("goldie", anim, i), {"lancelot": LANCELOT, "lady": LADY, "morgana": MORGANA}[kind])
    return img.flipped() if flip else img


def page(base: str) -> Canvas:
    return Canvas(W, H, rgba(base))


def zzz(c: Canvas, x: int, y: int, col: str = "white") -> None:
    for k, (dx, dy, s) in enumerate(((0, 0, 3), (4, -5, 2), (7, -9, 2))):
        for i in range(s):
            c.set(x + dx + i, y + dy, col)
            c.set(x + dx + i, y + dy + s, col)
            c.set(x + dx + s - 1 - i, y + dy + i, col)


def green_knight(sad_thorns: bool = False) -> Canvas:
    """A big friendly hedge knight (44x62): round leafy hat, clipped body, twig arms, a vine whip."""
    c = Canvas(48, 64)
    body = AW.blob_canvas(40, 40, [(20, 22, 15), (13, 30, 10), (27, 30, 10), (20, 12, 11)],
                          ["forest", "leaf_d", "leaf", "leaf_l"], "forest_d", 61, texture=0.25)
    c.blit(body, 4, 22)
    for x in (14, 30):
        c.rect(x, 58, 5, 5, "brown_d")
        c.hline(x, x + 4, 58, "brown")
    hat = AW.blob_canvas(36, 24, [(18, 13, 11), (9, 15, 7), (27, 15, 7)], ["forest", "leaf_d", "leaf", "spring"],
                         "forest_d", 62, texture=0.25)
    c.blit(hat, 6, 0)
    for (x, y) in ((17, 34), (27, 34)):
        c.rect(x, y, 2, 3, "ink")
        c.set(x, y, "white")
    c.hline(19, 26, 40, "ink")
    c.set(18, 39, "ink")
    c.set(27, 39, "ink")
    for k in range(10):
        c.set(2 + k // 3, 36 + k, "brown")
        c.set(44 - k // 3, 36 + k, "brown")
    if sad_thorns:
        for k in range(5):
            K.thorn_vine(c, 10 + k * 6, 6, 6, 6300 + k)
    return c


def sparkle_burst(c: Canvas, cx: int, cy: int, n: int, seed: int, r: int = 30,
                  cols=("white", "lilac", "yellow")) -> None:
    rng = random.Random(seed)
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(4, r)
        x, y = int(cx + math.cos(a) * d), int(cy + math.sin(a) * d * 0.7)
        if i % 4 == 0:
            P.star4(c, x, y, cols[1], 1, cols[0])
        else:
            c.set(x, y, cols[i % len(cols)])


def round_table(c: Canvas, cx: int, cy: int, rx: int = 56, ry: int = 18) -> None:
    top = P.ellipse(cx, cy, rx, ry)
    for (x, y) in top:
        d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
        ring = int(d * 7) % 2
        c.set(x, y, "gold" if ring else ("gold_l" if d < 0.4 else "gold_d"))
    rim = {(x, y) for (x, y) in P.ellipse(cx, cy + 4, rx, ry) - top if y > cy}
    P.fill(c, rim, "brown_d")
    P.outline_shape(c, top | rim, "ink")


def hall(c: Canvas, base=("plum", "dusk"), warm: bool = True) -> None:
    """The round-table hall: a stone back wall, two pillars, banners."""
    K.sky_bands(c, 0, H, [("umber", 0.0), ("brown_d", 0.35), ("plum", 0.75)], seed=3, wave=1.0)
    wall = K.masonry(W, 64, ("brown_d", "brown", "gold_d") if warm else ("night_d", "night", "slate"), 7, course=7,
                     mortar="umber" if warm else "navy", base_dark=0)
    c.blit(wall, 0, 0)
    for px in (6, 140):
        pil = Canvas(14, H)
        pil.rect(0, 0, 14, H, "brown")
        pil.rect(0, 0, 3, H, "gold_d")
        pil.rect(10, 0, 4, H, "brown_d")
        pil.outline_all("ink")
        c.blit(pil, px, 0)
    for bx in (36, 112):
        for y in range(4, 34):
            for x in range(bx, bx + 12):
                if y < 30 or abs(x - bx - 5.5) > (y - 30) * 1.5:
                    c.set(x, y, "red" if x > bx + 1 else "coral")
        c.set(bx + 5, 14, "gold_l")
        c.set(bx + 6, 14, "gold_l")
        c.set(bx + 5, 15, "gold")
    for y in range(64, H):
        for x in range(W):
            c.set(x, y, "brown_d" if (x // 10 + y // 6) % 2 else "umber")


# --------------------------------------------------------------------------
# chapter 2
# --------------------------------------------------------------------------

def c2_prologue_1() -> Canvas:
    """Early morning in Camelot: purple thorns over the walls, dogs asleep in a heap in the street."""
    c = page("sky")
    K.sky_bands(c, 0, 60, [("azure", 0.0), ("sky_l", 0.4), ("haze", 0.7), ("peach", 0.92)], seed=21)
    T.castle(c, 54, 52, 1.1, wall=("stone", "stone_l", "white"), roof=("red_d", "red", "coral"))
    roofs = Canvas(W, 44)
    WD.house_row(roofs, 44, -6, W + 6, 2101, [("stone", "stone_l", "white"), ("dirt", "sand", "cream")],
                 [("red_d", "red", "coral"), ("brown_d", "brown", "gold_d")], heights=(18, 24), widths=(22, 30),
                 thorns=1.0, lit=0.0, timber=0.6, gables=0.5)
    c.blit(roofs, 0, 34)
    K.cobbles(c, (0, 78, W, H), ("dirt", "sand", "dirt"), "gold_d", 2102)
    for k in range(9):
        K.thorn_vine(c, 4 + k * 18, 79, 26 + (k % 3) * 8, 2103 + k)
    furs = [("gold_d", "gold", "gold_l"), ("stone", "stone_l", "white"), ("brown", "gold_d", "dirt"),
            ("ash", "fog", "white"), ("brown_d", "brown", "gold_d")]
    spots = [(36, 92), (54, 96), (46, 86), (90, 98), (108, 92), (124, 100), (70, 104)]
    for i, (x, y) in enumerate(spots):
        c.blit(WD.sleeping_dog(i, furs[i % len(furs)]), x, y)
    zzz(c, 66, 86)
    zzz(c, 118, 88)
    S.vignette(c, density=0.35)
    return c


def c2_prologue_2() -> Canvas:
    """The round table: the knights asleep with their heads on the table, Zzz rising."""
    c = page("umber")
    hall(c)
    round_table(c, 80, 84)
    rng = random.Random(22)
    for i, ang in enumerate((200, 228, 256, 284, 312, 340)):
        a = math.radians(ang)
        x, y = int(80 + math.cos(a) * 52), int(84 + math.sin(a) * 18)
        ch = S.chair(20)
        c.blit(ch, x - 8, y - ch.h + 4)
    for i, ang in enumerate((210, 240, 270, 300, 330)):
        a = math.radians(ang)
        x, y = int(80 + math.cos(a) * 40), int(80 + math.sin(a) * 12)
        grid, (fur, dark) = S.DOG_HEADS[i % len(S.DOG_HEADS)]
        c.stamp(grid, x - 3, y, {"o": fur}, outline="ink")
        c.hline(x - 2, x - 1, y + 2, "ink")
        c.hline(x + 1, x + 2, y + 2, "ink")
        c.set(x, y + 3, dark)
        c.stamp(["pp", "pp"], x - 6 + (i % 2) * 10, y + 3, {"p": fur}, outline="ink")
        zzz(c, x + 4, y - 4)
    for k, ang in enumerate((30, 80, 130, 160)):
        a = math.radians(ang)
        x, y = int(80 + math.cos(a) * 66), int(92 + math.sin(a) * 22)
        c.blit(S.chair(24, front=True), x - 8, y - 14)
    sparkle_burst(c, 80, 30, 10, 2201, 50, cols=("lilac", "violet", "plum"))
    S.vignette(c, density=0.5)
    return c


def c2_ending_1() -> Canvas:
    """The Green Knight's purple thorns burst into points of light; the garden blooms."""
    c = page("sky")
    K.sky_bands(c, 0, 50, [("azure", 0.0), ("haze", 0.5), ("cream", 0.85)], seed=23)
    K.hills_layer(c, 52, 5, 19.0, "moss", rim="leaf_l", seed=2, fill_to=60)
    for y in range(50, H):
        for x in range(W):
            c.set(x, y, "leaf" if ((x + int(3 * math.sin(y / 9))) // 14) % 2 else "grass")
    hedge = AW.hedge_strip(W, 2301, flowers=["red", "pink", "white", "yellow", "lilac"], flower_every=2, h=16)
    c.blit(hedge, 0, 44)
    AW.sprinkle_flowers(c, (0, 62, W, H), 70, 2302, ["red", "pink", "white", "yellow", "lilac"])
    gk = green_knight()
    c.blit(gk, 56, 40)
    sparkle_burst(c, 78, 50, 46, 2303, 44, cols=("white", "lilac", "yellow"))
    for (x, y) in ((34, 30), (122, 26), (100, 54), (52, 60)):
        P.star4(c, x, y, "lilac", 2, "white")
    c.blit(dog("goldie", "victory", 1), 18, 82)
    c.blit(dog("bulldog", "idle", 0), 110, 84)
    S.vignette(c, density=0.35)
    return c


def c2_ending_2() -> Canvas:
    """The knights stretch and wake up; the round table is full again, Goldie in the middle."""
    c = page("umber")
    hall(c)
    round_table(c, 80, 88, 60, 16)
    furs = [{}, LANCELOT, {"gold_l": "white", "gold": "stone_l", "gold_d": "stone", "brown": "stone_d"},
            {"gold_l": "gold_d", "gold": "brown", "gold_d": "brown_d", "brown": "umber", "red": "leaf", "red_d": "leaf_d",
             "coral": "leaf_l", "wine": "forest"},
            {"gold_l": "steel_l", "gold": "steel", "gold_d": "steel_d", "brown": "iron", "red": "violet",
             "red_d": "plum", "coral": "lilac", "wine": "plum"}]
    xs = [8, 34, 100, 126]
    for i, x in enumerate(xs):
        img = S.recolor(frame("goldie", "victory", 1 + i % 2), furs[(i + 1) % len(furs)])
        c.blit(img.flipped() if x > 80 else img, x, 48 + (i % 2) * 3)
    c.blit(dog("bulldog", "victory", 1), 40, 58)
    c.blit(dog("lancelot", "victory", 2, True), 90, 58)
    c.blit(dog("goldie", "victory", 1), 64, 52)
    for k in range(40):
        rng = random.Random(2400 + k)
        x, y = rng.randrange(0, W), rng.randrange(0, 50)
        c.set(x, y, ["red", "yellow", "sky", "pink", "leaf_l"][k % 5])
    S.vignette(c, density=0.45)
    return c


def c2_ending_3() -> Canvas:
    """Night: violet mist drifts through the window into Merlin's room; only his hat shows above the
    blanket."""
    c = page("navy")
    K.sky_bands(c, 0, H, [("night_d", 0.0), ("navy", 0.6)], seed=25)
    wall = K.masonry(W, 84, ("navy", "night_d", "night"), 2501, course=7, mortar="ink", base_dark=0)
    c.blit(wall, 0, 0)
    win = Canvas(40, 52)
    for y in range(52):
        for x in range(40):
            dxn = (x + 0.5 - 20) / 20
            if y >= (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * 16:
                win.set(x, y, "night" if y < 34 else "water_d")
    S.stars(win, 8, 2502, (2, 4, 38, 30))
    K.moon(win, 28, 14, 5, halo=(), crescent=0.5)
    win.vline(20, 2, 51, "ink")
    win.hline(0, 39, 30, "ink")
    win.outline_all("slate")
    c.blit(win, 14, 8)
    for y in range(84, H):
        for x in range(W):
            c.set(x, y, "umber" if (x // 12 + y // 5) % 2 else "brown_d")
    # bed with Merlin's hat on the pillow
    bed = Canvas(70, 36)
    bed.rect(2, 10, 66, 22, "water_d")
    bed.rect(2, 10, 66, 4, "water")
    bed.rect(4, 4, 18, 10, "white")
    bed.rect(0, 0, 4, 34, "brown")
    bed.rect(66, 8, 4, 26, "brown")
    bed.outline_all("ink")
    c.blit(bed, 76, 70)
    hat = Canvas(20, 18)
    for y in range(16):
        half = (y + 1) * 0.45
        for x in range(int(10 - half), int(10 + half) + 1):
            hat.set(x, y, "water" if x < 10 else "water_d")
    hat.hline(1, 18, 16, "water_d")
    hat.set(9, 6, "yellow")
    hat.set(12, 11, "yellow")
    hat.outline_all("ink")
    c.blit(hat, 80, 58)
    zzz(c, 102, 60, "lilac")
    # the violet mist pouring in from the window
    for k in range(9):
        t = k / 8
        cx, cy = 34 + t * 66, 44 + t * 30 + math.sin(t * 7) * 5
        r = 7 - t * 3
        for (x, y) in P.ellipse(cx, cy, r * 1.6, r * 0.8):
            if AW.name_at(c, x, y) not in ("white",):
                c.set(x, y, "dusk")
        for (x, y) in P.ellipse(cx - 1, cy - 1, r * 1.1, r * 0.5):
            c.set(x, y, "violet")
        c.set(int(cx - r * 0.6), int(cy - 1), "lilac")
    S.vignette(c, density=0.5)
    return c


def lake_view(c: Canvas, tower_x: int, hz: int, sky, moon=None, mist: bool = True, tower_h: int = 54) -> None:
    K.sky_bands(c, 0, hz, sky, seed=tower_x, wave=1.2)
    if moon:
        K.moon(c, moon[0], moon[1], moon[2], halo=moon[3])
    K.peaks_layer(c, hz, [(10, 18, 40), (60, 24, 46), (120, 16, 40), (170, 22, 44)], "ash", "slate", rim="fog",
                  seed=31, rough=1.0)
    WD.water_bands(c, (0, hz, W, H), [("slate", 0.0), ("night", 0.25), ("water_d", 0.6)], 3101,
                   glints=("fog", "steel_l"), n_glints=40)
    for y in range(hz - 3, hz + 4):
        for x in range(tower_x - 18, tower_x + 18):
            if y - (hz - 3) >= abs(x - tower_x) * 0.3 - 1:
                c.set(x, y, "navy")
    for y in range(hz - tower_h, hz):
        half = 3 + (y - (hz - tower_h)) * 0.04
        for x in range(int(tower_x - half), int(tower_x + half) + 1):
            c.set(x, y, "slate" if x < tower_x - half + 2 else "navy")
    for y in range(hz - tower_h - 12, hz - tower_h + 1):
        half = (y - (hz - tower_h - 12)) * 0.35
        for x in range(int(tower_x - half), int(tower_x + half) + 1):
            c.set(x, y, "plum")
    c.set(tower_x, hz - tower_h + 10, "lilac")
    if mist:
        for k, (y0, x0, w) in enumerate(((hz + 3, 0, 70), (hz + 10, 60, 100), (hz + 20, 10, 80))):
            for y in range(y0, y0 + 4):
                for x in range(x0, x0 + w):
                    e = 1 - abs(y - y0 - 1.5) / 2.5
                    if AW.fbm(x, y, 3110 + k, 8, 2) * e > 0.3:
                        c.set(x, y, "fog" if e > 0.7 else "ash")


def teaser_2() -> Canvas:
    """Chapter 3 teaser: the misty lake at dusk and the tower on its island."""
    c = page("navy")
    lake_view(c, 108, 62, [("navy", 0.0), ("night", 0.4), ("dusk", 0.75), ("rose", 0.92)],
              moon=(34, 22, 8, ("night",)), tower_h=50)
    S.stars(c, 20, 2601, (0, 0, W, 30))
    for y in range(96, H):
        for x in range(W):
            if y > 98 + 3 * math.sin(x / 11):
                c.set(x, y, "deep")
    S.tufts(c, (0, 100, W, H), 30, 2603, cols=("teal", "navy"))
    for k, x in enumerate((2, 12, 24, 134, 146)):
        c.blit(K.reeds(2602 + k, 16), x, 84)
    S.vignette(c, density=0.55)
    return c


def c3_prologue_1() -> Canvas:
    """Early morning on the misty lake; a spire stands on the far island."""
    c = page("fog")
    lake_view(c, 112, 56, [("ash", 0.0), ("fog", 0.4), ("haze", 0.7), ("peach", 0.92)], tower_h=40)
    T.sun_glow(c, 40, 54, rings=((6, "white"), (10, "cream"), (16, "peach")), only=("haze", "fog", "peach", "ash"))
    for y in range(98, H):
        for x in range(W):
            if y > 100 + 2 * math.sin(x / 13):
                c.set(x, y, "teal")
    S.tufts(c, (0, 102, W, H), 30, 2703, cols=("leaf_d", "deep"))
    for k, x in enumerate((4, 16, 28, 128, 140, 150)):
        c.blit(K.reeds(2701 + k, 18), x, 86)
    boat = Canvas(28, 10)
    for (x, y) in P.ellipse(14, 3, 13, 6):
        if y >= 3:
            boat.set(x, y, "brown" if y < 6 else "brown_d")
    boat.outline_all("umber")
    c.blit(boat, 56, 92)
    S.vignette(c, density=0.35)
    return c


def c3_prologue_2() -> Canvas:
    """The lake glows and the white samoyed Lady of the Lake rises from the water."""
    c = page("night")
    K.sky_bands(c, 0, 50, [("navy", 0.0), ("night_d", 0.4), ("night", 0.8)], seed=28)
    S.stars(c, 24, 2801, (0, 0, W, 40))
    WD.water_bands(c, (0, 50, W, H), [("night", 0.0), ("water_d", 0.4), ("night", 0.85)], 2802,
                   glints=("sky", "sky_l"), n_glints=40)
    for r, col in ((40, "water_d"), (30, "water"), (20, "sky"), (11, "sky_l")):
        for (x, y) in P.ellipse(80, 92, r, r * 0.32):
            c.set(x, y, col)
    for k in range(5):
        y = 60 + k * 7
        for x in range(80 - 16 + k * 2, 80 + 16 - k * 2):
            if (x + k) % 3 == 0:
                c.set(x, y, "sky_l")
    lady = dog("lady", "victory", 1)
    c.blit(lady.scaled(2), 48, 26)
    for (x, y) in ((40, 40), (118, 36), (60, 22), (104, 20), (34, 70), (126, 66)):
        P.star4(c, x, y, "sky_l", 1, "white")
    rng = random.Random(2803)
    for _ in range(30):
        a = rng.uniform(0, 2 * math.pi)
        x, y = int(80 + math.cos(a) * rng.uniform(26, 40)), int(54 + math.sin(a) * rng.uniform(20, 32))
        c.set(x, y, "sky_l")
    S.vignette(c, density=0.5)
    return c


# --------------------------------------------------------------------------
# chapter 3 endings
# --------------------------------------------------------------------------

def c3_ending_1() -> Canvas:
    """The top of the tower at dawn after the storm: Morgana sits on the floor, her staff dropped;
    Goldie offers her a stick."""
    c = page("navy")
    K.sky_bands(c, 0, 70, [("night", 0.0), ("dusk", 0.35), ("rose", 0.65), ("peach", 0.88)], seed=29)
    WD.cloud_bank(c, 60, ("dusk", "rose", "peach"), 2901, size=(5.0, 9.0), step=12)
    K.flagstones(c, (0, 72, W, H), ("ash", "ash"), "slate", 2902, widths=(12, 20), heights=(7, 9))
    c.blit(K.crenels(W, 9, 6, 9, ("slate", "ash", "fog"), "navy"), 0, 62)
    for x in range(W):
        c.set(x, 72, "slate")
    mor = dog("morgana", "hurt", 1, True)
    c.blit(mor.scaled(2), 92, 52)
    # the dropped crescent staff
    for k in range(26):
        c.set(70 + k, 106 - k // 6, "brown")
    for (x, y) in P.ellipse(98, 101, 4, 4) - P.ellipse(100, 100, 3.5, 3.5):
        c.set(x, y, "yellow")
    gol = dog("goldie", "idle", 0)
    c.blit(gol.scaled(2), 22, 54)
    # the stick in Goldie's mouth
    for k in range(14):
        c.set(66 + k, 76 + k // 7, "brown" if k % 4 else "brown_d")
    c.set(80, 78, "leaf")
    T.sun_glow(c, 132, 58, rings=((5, "white"), (9, "cream")), only=("peach", "rose", "cream"))
    S.vignette(c, density=0.4)
    return c


def c3_ending_2() -> Canvas:
    """The coronation: Goldie wears the crown, the round table is full; Morgana has a seat too."""
    c = page("umber")
    hall(c)
    for y in range(0, 50):
        for x in range(58, 102):
            if abs(x - 80) < 8 + y * 0.4 and AW.name_at(c, x, y) in ("brown", "brown_d", "gold_d"):
                c.set(x, y, K.lt(AW.name_at(c, x, y)))
    round_table(c, 80, 92, 64, 16)
    xs = [(6, {}), (30, LANCELOT), (104, MORGANA), (128, LADY)]
    for i, (x, pal) in enumerate(xs):
        img = S.recolor(frame("goldie", "idle", i % 2), pal) if pal else frame("bulldog", "victory", 1)
        c.blit(img.flipped() if x > 80 else img, x, 56)
    c.blit(dog("merlin", "cast", 1, True), 104, 40)
    gol = dog("goldie", "victory", 1)
    c.blit(gol, 64, 48)
    crown = ["y.y.y", "yyyyy", "ygrgy"]
    c.stamp(crown, 74, 46, {"y": "yellow", "g": "gold", "r": "red"}, outline="brown_d")
    for (x, y) in ((70, 42), (90, 40), (80, 36)):
        P.star4(c, x, y, "yellow", 1, "white")
    S.vignette(c, density=0.45)
    return c


def c3_ending_3() -> Canvas:
    """Sunset in the meadow: everyone, Morgana too, playing fetch."""
    c = page("peach")
    K.sky_bands(c, 0, 58, [("dusk", 0.0), ("rose", 0.3), ("coral", 0.55), ("peach", 0.75), ("cream", 0.9)], seed=31)
    for (x, y, r) in ((118, 52, 9),):
        for (px, py) in P.ellipse(x, y, r, r):
            c.set(px, py, "yellow" if py < y + 2 else "orange")
    K.peaks_layer(c, 58, [(20, 12, 40), (80, 16, 46), (150, 12, 40)], "rose", "dusk", rim="peach", seed=32)
    T.castle(c, 14, 56, 0.6, wall=("rose", "peach", "cream"), roof=("dusk", "rose", "peach"))
    for y in range(58, H):
        for x in range(W):
            c.set(x, y, "moss" if (x // 12 + y // 9) % 3 else "leaf_l")
    AW.paint_ground(c, (0, 58, W, H), ("moss_d", "moss", "leaf_l"), 3103, scale=18, tufts=0.4)
    AW.sprinkle_flowers(c, (0, 64, W, H), 40, 3104, ["white", "yellow", "pink"])
    # the stick flying through the air
    for k in range(10):
        c.set(70 + k, 30 - k // 3, "brown_d" if k % 3 else "brown")
    for k in range(6):
        c.set(56 + k * 2, 40 - k * 2, "cream")
    cast = [("goldie", "run", 2, False, 54, 64), ("bulldog", "run", 1, False, 22, 72), ("lancelot", "run", 3, False, 86, 76),
            ("morgana", "run", 0, True, 112, 70), ("lady", "idle", 1, True, 130, 82), ("merlin", "cast", 1, True, 2, 84)]
    for (kind, anim, i, flip, x, y) in cast:
        c.blit(dog(kind, anim, i, flip), x, y)
    S.vignette(c, density=0.35)
    return c


BUILDERS = {
    "c2_prologue_1": c2_prologue_1, "c2_prologue_2": c2_prologue_2, "c2_ending_1": c2_ending_1,
    "c2_ending_2": c2_ending_2, "c2_ending_3": c2_ending_3, "teaser_2": teaser_2,
    "c3_prologue_1": c3_prologue_1, "c3_prologue_2": c3_prologue_2, "c3_ending_1": c3_ending_1,
    "c3_ending_2": c3_ending_2, "c3_ending_3": c3_ending_3,
}


def write_all(ids: list[str] | None = None, preview_dir: str | None = None) -> None:
    for sid in IDS:
        if ids and sid not in ids:
            continue
        img = P.quantize(BUILDERS[sid]())
        img.save(res_path("res://assets/story/%s.png" % sid), opaque=True)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            img.scaled(3).save(os.path.join(preview_dir, "%s.png" % sid))


if __name__ == "__main__":
    args = sys.argv[1:]
    pdir = None
    if "--preview" in args:
        i = args.index("--preview")
        pdir = args[i + 1]
        del args[i:i + 2]
    write_all(args or None, pdir)
    print("story pages written")
