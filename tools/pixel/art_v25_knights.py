"""v2.5 (CR1) armoured cast and Merlin, redrawn with the rig renderer. All face right.

  black_knight   64  the boss: great helm with a violet-glowing visor slit and plume, huge pauldrons,
                     tattered violet cape, greatsword. Dark blued steel with cold specular highlights.
  armored_husk   32  an empty suit of light steel, blue visor glow, big shield with a violet sigil
  merlin         32  old shih tzu wizard: long white fur beard, gold ears, round glasses, star hat and
                     robe, staff topped with a glowing star

The rim light (build_all.with_rim) still runs on the two armours afterwards.
"""

from __future__ import annotations

import math

import art_cast
import art_enemies
from paint import alpha_px
from rig import Fig, Mat, blade, capsule, ellipse, frames_like, poly, rect, union

DARK = Mat(["navy", "night_d", "iron", "slate", "steel_d"], outline="ink", lit="navy", spec="steel", spec_at=0.9)
DARK_TRIM = Mat(["plum", "dusk", "violet"], outline="ink", lit="plum")
CAPE = Mat(["ink", "plum", "dusk", "violet"], outline="ink", lit="ink")
PLUME = Mat(["plum", "dusk", "violet", "lilac"], outline="ink", lit="plum")
LEATHER = Mat(["umber", "brown_d", "brown"], outline="ink")
LIGHT = Mat(["iron", "steel_d", "steel", "steel_l", "white"], outline="navy", lit="iron", spec="white",
            spec_at=0.88)
SIGIL = Mat(["plum", "violet", "lilac"], outline="ink")
WOOD = Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber")


def stars(f: Fig, pts) -> None:
    for (x, y) in pts:
        f.dots([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "yellow")
        f.dot(x, y, "white")


def glow_ring(f: Fig, x: int, y: int, r: int, col: str, a: int) -> None:
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if abs(dx) + abs(dy) <= r:
                f.glow(x + dx, y + dy, alpha_px(col, a))


# --------------------------------------------------------------------------
# black knight (64)
# --------------------------------------------------------------------------

def greatsword(f: Fig, hx: float, hy: float, deg: float, length: int = 26) -> None:
    a = -math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    grip = {}
    for i in range(0, 6):
        grip[(int(round(hx - dx * i)), int(round(hy - dy * i)))] = "brown_d" if i < 5 else "violet"
    grip[(int(round(hx - dx * 6)), int(round(hy - dy * 6)))] = "lilac"
    f.pix(grip, LEATHER)
    gx, gy = hx + dx * 1.5, hy + dy * 1.5
    guard = {}
    for k in range(-4, 5):
        for t in (0, 1):
            guard[(int(round(gx + nx * k + dx * t)), int(round(gy + ny * k + dy * t)))] = \
                "slate" if k < 0 else "iron"
    guard[(int(round(gx + nx * -4)), int(round(gy + ny * -4)))] = "violet"
    guard[(int(round(gx + nx * 4)), int(round(gy + ny * 4)))] = "plum"
    f.pix(guard, DARK)
    px = blade(gx + dx * 2.5, gy + dy * 2.5, a, length, 4, light="steel_l", mid="steel_d", dark="iron")
    # violet fuller down the middle
    for i in range(2, length - 4):
        x = int(math.floor(gx + dx * (2.5 + i) + 0.5))
        y = int(math.floor(gy + dy * (2.5 + i) + 0.5))
        if (x, y) in px:
            px[(x, y)] = "dusk"
    f.pix(px, DARK)


def knight_frame(bob: int = 0, lean: float = 0.0, legs=((0, 0.0), (0, 0.0)), sword_at=(43, 44),
                 sword_deg: float = -70.0, sword_len: int = 24, sword_front: bool = True, cape_wave: float = 0.0,
                 cape_lift: float = 0.0, visor: int = 2, plume: float = 0.0, head_dy: int = 0, extra=None) -> Fig:
    f = Fig(64, 64, seed=41)
    ground = 62
    cx = 29.0 + lean
    by = 38.0 + bob
    # tattered cape
    hem = ground - 2 - cape_lift * 8
    back = cx - 17 - cape_lift * 6
    pts = [(cx + 4, by - 9), (cx - 8, by - 10), (cx - 13 - cape_lift * 3, by - 2), (back - cape_wave, hem - 8),
           (back - 1 - cape_wave, hem), (back + 3, hem - 3), (back + 6 - cape_wave * 0.5, hem + 1),
           (back + 9, hem - 2), (back + 12, hem + 1), (cx - 1, hem - 3), (cx + 2, by + 6)]
    cape = poly(pts)
    f.add(cape, CAPE, centre=(cx - 6, by - 4), radius=(14, 16), bias=0.04, contrast=0.85)
    for k, xb in enumerate((back + 3, back + 9)):
        fold = {p for p in capsule(cx - 6 - 2 * k, by - 5, xb, hem - 3, 0.5) if p in cape}
        f.shade_toward(fold, CAPE, -1)
    # back pauldron and arm
    f.add(ellipse(cx - 10, by - 7, 5.6, 5.2), DARK, centre=(cx - 12, by - 9), radius=(6, 6), bias=-0.1)
    if not sword_front:
        greatsword(f, sword_at[0], sword_at[1], sword_deg, sword_len)
    # legs: greaves and sabatons
    (fl, fdx), (nl, ndx) = legs
    for (x, lift, dx, far) in ((cx - 6, fl, fdx, True), (cx + 4, nl, ndx, False)):
        foot = ground - lift
        leg = union(rect(int(round(x + dx * 0.5)) - 3, int(by + 8), 6, int(foot - by - 9)),
                    capsule(x, by + 8, x + dx, foot - 3, 2.8))
        f.add(leg, DARK, mode="cyl_v", centre=(x + dx, foot), radius=(3.5, 6), bias=-0.12 if far else 0.04)
        kx, ky = int(round(x + dx * 0.6)), int(round((by + 8 + foot) / 2))
        f.add(ellipse(kx, ky, 3.2, 2.4), DARK, bias=0.05 if not far else -0.08)
        sab = union(rect(int(round(x + dx)) - 3, foot - 2, 8, 3), ellipse(x + dx + 4, foot - 0.5, 2.4, 1.6))
        f.add(sab, DARK, centre=(x + dx, foot - 3), radius=(5, 3), bias=-0.05 if far else 0.05)
    # tassets (skirt plates)
    tas = poly([(cx - 10, by + 3), (cx + 10, by + 3), (cx + 12, by + 11), (cx + 4, by + 12), (cx - 4, by + 12),
                (cx - 12, by + 11)])
    f.add(tas, DARK, centre=(cx - 3, by + 2), radius=(12, 8), bias=0.02)
    f.recolor({(x, y) for (x, y) in tas if y == int(by + 7) or (x - int(cx)) % 7 == 0 and y > by + 7}, "navy")
    # breastplate
    chest = union(ellipse(cx, by - 3, 11.0, 9.0), rect(int(cx - 9), int(by), 19, 5))
    f.add(chest, DARK, centre=(cx - 3, by - 7), radius=(12, 11), bias=0.06)
    f.recolor({(x, y) for (x, y) in chest if abs(x - (cx + 1)) < 0.6 and y < by + 3}, "slate")
    belt = {(x, y) for (x, y) in chest if y in (int(by + 3), int(by + 4))}
    f.recolor(belt, "umber")
    f.recolor({(x, y) for (x, y) in belt if y == int(by + 3)}, "brown_d")
    f.dots([(int(cx + 1), int(by + 3)), (int(cx + 2), int(by + 3)), (int(cx + 1), int(by + 4)),
            (int(cx + 2), int(by + 4))], "violet")
    # violet heart sigil on the chest
    sx, sy = int(round(cx - 1)), int(round(by - 3))
    heart = [(sx - 2, sy - 1), (sx - 1, sy - 2), (sx, sy - 1), (sx + 1, sy - 2), (sx + 2, sy - 1), (sx - 2, sy),
             (sx - 1, sy), (sx, sy), (sx + 1, sy), (sx + 2, sy), (sx - 1, sy + 1), (sx, sy + 1), (sx + 1, sy + 1),
             (sx, sy + 2)]
    f.recolor(set(heart), "violet")
    f.recolor({(sx - 1, sy - 2), (sx - 2, sy - 1), (sx - 1, sy)}, "lilac")
    f.recolor({(sx + 1, sy + 1), (sx, sy + 2)}, "plum")
    # helm
    hx, hy = cx + 2.0, by - 19.0 + head_dy
    helm = union(rect(int(hx - 7), int(hy - 6), 15, 14), ellipse(hx + 0.5, hy - 5, 7.5, 4.0),
                 ellipse(hx + 0.5, hy + 6, 7.0, 3.0))
    f.add(helm, DARK, centre=(hx - 3, hy - 5), radius=(9, 10), bias=0.08)
    # visor: a dark slit with violet light, breathing holes, a ridge
    vy = int(hy - 1)
    slit = {(x, y) for x in range(int(hx - 1), int(hx + 8)) for y in (vy, vy + 1)}
    f.recolor(slit, "ink")
    if visor:
        f.recolor({(x, vy) for x in range(int(hx + 1), int(hx + 7))}, "violet" if visor == 1 else "lilac")
        f.recolor({(int(hx + 3), vy), (int(hx + 4), vy)}, "white" if visor == 2 else "lilac")
        f.recolor({(x, vy + 1) for x in range(int(hx + 1), int(hx + 7))}, "violet" if visor == 2 else "dusk")
        f.recolor({(int(hx + 3), vy + 1)}, "lilac")
        for x in range(int(hx), int(hx + 10)):
            f.glow(x, vy - 1, alpha_px("lilac", 70))
            f.glow(x, vy + 2, alpha_px("violet", 50))
        f.glow(int(hx + 9), vy, alpha_px("lilac", 120))
    f.recolor({(x, y) for x in range(int(hx), int(hx + 8)) for y in (vy - 2,)}, "iron")
    for (x, y) in ((hx + 4, hy + 4), (hx + 6, hy + 4), (hx + 5, hy + 6)):
        f.recolor({(int(x), int(y))}, "navy")
    f.recolor({(int(hx - 2), y) for y in range(int(hy - 8), int(hy - 2))}, "steel_d")
    # plume
    px, py = hx - 1, hy - 9
    pl = union(capsule(px, py, px - 5, py - 4 - plume, 2.2), capsule(px - 5, py - 4 - plume, px - 11, py - 2 - plume,
                                                                     1.8),
               capsule(px - 11, py - 2 - plume, px - 14, py + 2 - plume * 0.5, 1.3))
    f.add(pl, PLUME, centre=(px - 6, py - 5), radius=(7, 4), bias=0.1)
    # front pauldron (layered plates)
    sxp, syp = cx + 9, by - 8
    f.add(ellipse(sxp, syp, 6.6, 5.6), DARK, centre=(sxp - 2, syp - 3), radius=(7, 6), bias=0.1)
    f.recolor({(x, y) for (x, y) in ellipse(sxp, syp, 6.6, 5.6) if y == int(syp + 2)}, "navy")
    f.recolor({(x, y) for (x, y) in ellipse(sxp, syp, 6.6, 5.6) if y == int(syp - 4) and x < sxp}, "violet")
    # front arm and gauntlet
    if sword_front:
        greatsword(f, sword_at[0], sword_at[1], sword_deg, sword_len)
    ax, ay = sword_at
    f.add(capsule(sxp, syp + 3, ax - 1, ay - 1, 2.6), DARK, centre=(ax - 2, ay - 3), radius=(5, 5), bias=0.08)
    f.add(ellipse(ax, ay, 3.0, 2.8), DARK, centre=(ax - 1, ay - 1), radius=(3, 3), bias=0.12)
    if extra:
        extra(f)
    return f


def dust(f: Fig, pts) -> None:
    for (x, y, r) in pts:
        f.add(ellipse(x, y, r, r * 0.7), Mat(["stone_d", "stone", "stone_l"], outline="slate", lit="stone_d"),
              bias=0.1, sep=False)


def knight_down(k: int):
    f = Fig(64, 64, seed=43)
    if k == 0:
        # kneeling: one knee down, sword planted
        return knight_frame(bob=8, lean=-1, legs=((0, -2.0), (3, 4.0)), sword_at=(42, 52), sword_deg=-88,
                            sword_len=12, visor=1, head_dy=2, cape_lift=0).render()
    # empty armour pieces scattered, a violet wisp rising from the helm
    f.add(poly([(6, 60), (14, 54), (28, 54), (34, 60)]), CAPE, bias=0.05)
    f.add(union(ellipse(20, 56, 9, 4.5), rect(12, 56, 17, 4)), DARK, centre=(17, 52), radius=(10, 6), bias=0.1)
    f.add(ellipse(37, 58, 5, 3.4), DARK, bias=0.1)
    f.add(ellipse(9, 58, 4, 2.8), DARK, bias=0.05)
    helm = union(rect(42, 50, 12, 10), ellipse(48, 50, 6, 3))
    f.add(helm, DARK, centre=(45, 48), radius=(8, 8), bias=0.1)
    f.recolor({(x, 54) for x in range(44, 52)}, "ink")
    f.recolor({(x, 54) for x in range(46, 50)}, "plum")
    greatsword(f, 4, 61, 6, 26)
    for i, (x, y) in enumerate(((49, 46), (50, 43), (49, 40), (51, 37), (50, 34))):
        f.dot(x, y, "lilac" if i < 2 else "violet")
        f.glow(x - 1, y, alpha_px("violet", 90 - i * 12))
        f.glow(x + 1, y, alpha_px("violet", 90 - i * 12))
    return f.render()


def black_knight_v25() -> list:
    old = art_enemies.black_knight_v2()
    fr = {}
    fr["idle"] = [knight_frame().render(), knight_frame(bob=1, cape_wave=0.6, plume=0.5).render(),
                  knight_frame(bob=1, cape_wave=1.0, plume=1.0, visor=1).render(),
                  knight_frame(cape_wave=0.5, plume=0.5).render()]
    run_legs = [((0, -4.0), (0, 4.0)), ((2, -2.0), (0, 2.0)), ((4, 1.0), (0, -1.0)),
                ((0, 4.0), (0, -4.0)), ((0, 2.0), (2, -2.0)), ((0, -1.0), (4, 1.0))]
    run_bob = [0, 1, -1, 0, 1, -1]
    fr["run"] = [knight_frame(bob=run_bob[i], lean=1, legs=run_legs[i], cape_lift=0.35, cape_wave=i % 3,
                              plume=1.5, sword_at=(44, 46 + run_bob[i]), sword_deg=-35).render() for i in range(6)]
    fr["attack"] = [
        knight_frame(lean=-2, sword_at=(36, 26), sword_deg=110, sword_front=False, plume=1).render(),
        knight_frame(lean=1, sword_at=(45, 34), sword_deg=20, plume=2, cape_lift=0.2,
                     extra=lambda f: _arc(f, 31, 36, 16, 26, 20, 100)).render(),
        knight_frame(lean=2, sword_at=(46, 44), sword_deg=-40, plume=1, cape_lift=0.15,
                     extra=lambda f: _arc(f, 31, 36, 16, 26, -45, 30)).render(),
        knight_frame(lean=1, sword_at=(44, 46), sword_deg=-60).render(),
    ]
    fr["hurt"] = [knight_frame(lean=-3, head_dy=1, visor=1, extra=lambda f: stars(f, [(18, 8), (44, 6)])).render(),
                  knight_frame(lean=-2, visor=1).render()]
    fr["charge"] = [knight_frame(lean=3, bob=b, legs=lg, sword_at=(46, 40 + b), sword_deg=-8, sword_len=22,
                                 cape_lift=0.6, cape_wave=i, plume=2.5,
                                 extra=(lambda f, i=i: dust(f, [(8 - i, 60, 2.5), (14 + i, 61, 1.8)]))).render()
                    for i, (b, lg) in enumerate(((0, ((0, -4.0), (0, 4.0))), (1, ((2, -1.0), (0, 1.0))),
                                                 (-1, ((0, 4.0), (0, -4.0)))))]
    fr["slam"] = [
        knight_frame(lean=-2, bob=-1, sword_at=(34, 22), sword_deg=95, sword_front=False, plume=2).render(),
        knight_frame(lean=1, sword_at=(44, 30), sword_deg=40, plume=2, visor=2).render(),
        knight_frame(lean=2, bob=2, sword_at=(45, 46), sword_deg=-80, sword_len=16, plume=0,
                     extra=lambda f: dust(f, [(41, 61, 3.5), (52, 61, 3.0), (35, 62, 2.2)])).render(),
        knight_frame(lean=2, bob=2, sword_at=(45, 46), sword_deg=-80, sword_len=16, plume=0,
                     extra=lambda f: dust(f, [(38, 61, 2.4), (55, 60, 2.2)])).render(),
    ]
    fr["down"] = [knight_down(0), knight_down(1)]
    return frames_like(old, fr)


def _arc(f: Fig, cx: float, cy: float, r0: float, r1: float, a0: float, a1: float) -> None:
    """Swing smear: translucent violet-white arc where the frame is empty."""
    for y in range(64):
        for x in range(64):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if not (r0 <= d <= r1):
                continue
            ang = math.degrees(math.atan2(-(y + 0.5 - cy), x + 0.5 - cx))
            if a0 <= ang <= a1:
                edge = d > r1 - 1.5
                f.glow(x, y, alpha_px("lilac" if edge else "violet", 150 if edge else 70))


# --------------------------------------------------------------------------
# armored husk (32)
# --------------------------------------------------------------------------

def husk_frame(bob: int = 0, lean: float = 0.0, legs=((0, 0.0), (0, 0.0)), shield_at=(21.5, 19.5), visor: int = 1,
               spear: bool = False, head_dy: int = 0, extra=None) -> Fig:
    f = Fig(32, 32, seed=47)
    ground = 29
    cx = 14.0 + lean
    by = 20.0 + bob
    (fl, fdx), (nl, ndx) = legs
    for (x, lift, dx, far) in ((cx - 3, fl, fdx, True), (cx + 2.5, nl, ndx, False)):
        foot = ground - lift
        leg = union(rect(int(round(x + dx * 0.5)) - 1, int(by + 4), 3, int(foot - by - 4)),
                    capsule(x, by + 4, x + dx, foot - 1.5, 1.5))
        f.add(leg, LIGHT, mode="cyl_v", centre=(x + dx, foot), radius=(2, 4), bias=-0.15 if far else 0.0)
        f.add(rect(int(round(x + dx)) - 1, foot - 1, 5, 2), LIGHT, flat=1 if far else 2)
    # back arm
    f.add(capsule(cx - 4, by - 3, cx - 6, by + 2, 1.5), LIGHT, bias=-0.15)
    chest = union(ellipse(cx, by - 1, 5.8, 5.0), rect(int(cx - 5), int(by + 1), 11, 3))
    f.add(chest, LIGHT, centre=(cx - 2, by - 3), radius=(6.5, 6.0), bias=0.04)
    f.recolor({(x, int(by + 2)) for x in range(int(cx - 6), int(cx + 7))}, "steel_d")
    # tabard strip with the violet sigil
    f.recolor({(x, y) for (x, y) in chest if abs(x - cx) <= 1 and y >= by - 4}, "plum")
    f.recolor({(int(cx), int(by - 2)), (int(cx), int(by - 1))}, "violet")
    # helm: bucket helm, blue glow in the eye slit
    hx, hy = cx + 1.0, by - 9.5 + head_dy
    helm = union(rect(int(hx - 5), int(hy - 4), 11, 9), ellipse(hx + 0.5, hy - 4, 5.5, 2.8))
    f.add(helm, LIGHT, centre=(hx - 2, hy - 4), radius=(7, 7), bias=0.05)
    vy = int(hy - 1)
    f.recolor({(x, vy) for x in range(int(hx - 1), int(hx + 6))}, "navy")
    if visor:
        f.recolor({(x, vy) for x in range(int(hx + 1), int(hx + 5))}, "sky_l" if visor else "sky")
        f.recolor({(int(hx + 2), vy)}, "white")
        for x in range(int(hx), int(hx + 7)):
            f.glow(x, vy - 1, alpha_px("sky", 60))
            f.glow(x, vy + 1, alpha_px("sky", 40))
    f.recolor({(int(hx - 1), y) for y in range(int(hy - 6), int(hy + 4))}, "steel_d")
    f.add(capsule(hx - 1, hy - 6, hx - 5, hy - 8, 0.9), PLUME, bias=0.1)
    # shield in front: kite-shaped, steel rim, violet field with a sigil
    sx, sy = shield_at
    sh = poly([(sx - 4.5, sy - 6), (sx + 4.5, sy - 6), (sx + 4.5, sy + 1), (sx, sy + 7), (sx - 4.5, sy + 1)])
    f.add(sh, LIGHT, centre=(sx - 2, sy - 3), radius=(5, 7), bias=0.08)
    inner = poly([(sx - 3, sy - 4.5), (sx + 3, sy - 4.5), (sx + 3, sy + 0.5), (sx, sy + 5), (sx - 3, sy + 0.5)])
    f.add(inner, SIGIL, centre=(sx - 2, sy - 3), radius=(4, 6), bias=0.0, sep=True)
    six, siy = int(round(sx - 0.5)), int(round(sy - 1))
    f.dots([(six, siy - 2), (six, siy - 1), (six - 1, siy), (six, siy), (six + 1, siy), (six, siy + 1), (six, siy + 2)],
           "lilac")
    if extra:
        extra(f)
    return f


def husk_down():
    f = Fig(32, 32, seed=49)
    f.add(ellipse(12, 27, 7, 3), LIGHT, bias=0.1)
    f.add(poly([(19, 21), (27, 21), (27, 26), (23, 29), (19, 26)]), LIGHT, bias=0.1)
    f.add(poly([(20.5, 22.5), (25.5, 22.5), (25.5, 25.5), (23, 27.5), (20.5, 25.5)]), SIGIL, sep=True)
    helm = union(rect(3, 21, 8, 6), ellipse(7, 21, 4, 2))
    f.add(helm, LIGHT, bias=0.1)
    f.recolor({(x, 23) for x in range(5, 10)}, "navy")
    for i, (x, y) in enumerate(((8, 18), (9, 15), (8, 12), (9, 9))):
        f.dot(x, y, "sky_l" if i < 2 else "sky")
        f.glow(x - 1, y, alpha_px("sky", 80 - i * 15))
        f.glow(x + 1, y, alpha_px("sky", 80 - i * 15))
    return f.render()


def husk_v25() -> list:
    old = art_cast.armored_husk()
    fr = {
        "idle": [husk_frame().render(), husk_frame(bob=1).render(), husk_frame(bob=1, visor=1).render(),
                 husk_frame().render()],
        "run": [husk_frame(bob=b, lean=0.5, legs=lg, shield_at=(22.0, 19.5 + b)).render()
                for (b, lg) in ((0, ((0, -2.5), (0, 2.5))), (1, ((1, -1.0), (0, 1.0))), (-1, ((2, 1.0), (0, -1.0))),
                                (0, ((0, 2.5), (0, -2.5))), (1, ((0, 1.0), (1, -1.0))), (-1, ((0, -1.0), (2, 1.0))))],
        "attack": [husk_frame(lean=-1, shield_at=(19.5, 19.0)).render(),
                   husk_frame(lean=2, shield_at=(24.5, 19.0), legs=((0, -2.0), (0, 2.0))).render(),
                   husk_frame(lean=1, shield_at=(23.0, 19.5)).render()],
        "hurt": [husk_frame(lean=-2, head_dy=-1, visor=1, extra=lambda f: stars(f, [(8, 3), (21, 2)])).render()],
        "dash": [husk_frame(lean=2, bob=0, shield_at=(25.0, 19.0), legs=((0, -3.0), (0, 3.0)),
                            extra=lambda f: f.dots([(2, 18), (3, 18), (4, 18), (1, 22), (2, 22)], "white")).render(),
                 husk_frame(lean=2, bob=1, shield_at=(25.0, 20.0), legs=((1, -1.0), (0, 1.0)),
                            extra=lambda f: f.dots([(1, 19), (2, 19), (3, 19), (2, 23), (3, 23)], "white")).render()],
        "down": [husk_down()],
    }
    return frames_like(old, fr)


# --------------------------------------------------------------------------
# Merlin (32)
# --------------------------------------------------------------------------

WHITE = Mat(["ash", "fog", "white", "white"], outline="slate", lit="ash", fur=0.14, sep="ash", sep_lit="fog")
EARS = Mat(["brown", "gold_d", "gold", "gold_l"], outline="brown_d", lit="brown", fur=0.16)
ROBE = Mat(["navy", "night", "water_d", "water"], outline="navy", lit="night")
HATM = Mat(["night_d", "night", "water_d", "water"], outline="navy", lit="night_d")


def merlin_frame(bob: int = 0, lean: float = 0.0, staff_at=(23.0, 19.0), glow: int = 1, blink: bool = False,
                 hop: int = 0, arm_up: float = 0.0, extra=None) -> Fig:
    f = Fig(32, 32, seed=53)
    ground = 29
    cx = 14.0 + lean
    by = 21.0 + bob - hop
    # robe: long bell reaching the ground, star pattern, little paws peeking out
    robe = poly([(cx - 4, by - 5), (cx + 4, by - 5), (cx + 7, ground - hop), (cx - 7, ground - hop)])
    f.add(robe, ROBE, centre=(cx - 3, by - 4), radius=(9, 11), bias=0.18)
    f.recolor({(x, ground - hop) for x in range(int(cx - 7), int(cx + 8))}, "gold_d")
    f.recolor({(x, ground - hop - 1) for x in range(int(cx - 7), int(cx + 8)) if x % 2 == 0}, "gold")
    for (qx, qy) in ((cx - 3, by), (cx + 3, by + 3), (cx - 1, by + 5)):
        f.recolor({(int(qx), int(qy))}, "yellow")
    f.add(rect(int(cx + 2), ground - hop, 3, 1), WHITE, flat=2)
    sx, sy = staff_at
    # arm (sleeve) holding the staff, behind the beard
    f.add(capsule(cx + 2, by - 2 - arm_up, sx - 0.5, sy - arm_up * 0.5, 1.7), ROBE, bias=0.16)
    f.add(ellipse(sx, sy - arm_up * 0.5, 1.6, 1.5), WHITE, flat=2)
    # long white fur: beard flowing over the robe
    hx, hy = cx + 1.0, by - 10.0
    beard = poly([(hx - 2, hy + 2), (hx + 6, hy + 2), (hx + 5, hy + 9), (hx + 2, hy + 12), (hx, hy + 9)])
    f.add(beard, WHITE, centre=(hx + 1, hy + 3), radius=(5, 7), bias=0.12)
    f.recolor({(int(hx + 2), int(hy + 7)), (int(hx + 3), int(hy + 8)), (int(hx + 2), int(hy + 10))}, "fog")
    # head with gold ear fur hanging long
    f.add(union(ellipse(hx, hy, 6.0, 5.0), ellipse(hx + 3, hy + 1.5, 4.0, 3.2)), WHITE,
          centre=(hx - 2, hy - 2), radius=(7, 6), bias=0.14)
    ear = poly([(hx - 5, hy - 2), (hx - 2, hy - 2.5), (hx - 1.5, hy + 4), (hx - 2.5, hy + 8), (hx - 5, hy + 6.5)])
    f.add(ear, EARS, centre=(hx - 3.5, hy - 2), radius=(3, 7), bias=0.12)
    hxi, hyi = int(round(hx)), int(round(hy))
    # round glasses and eyes
    for gx in (hxi + 2, hxi + 6):
        f.dots([(gx - 1, hyi - 1), (gx, hyi - 2), (gx + 1, hyi - 1), (gx, hyi)], "gold")
        f.dot(gx, hyi - 1, "umber" if not blink else "fog")
    f.dot(hxi + 4, hyi - 1, "gold_d")
    f.dot(hxi + 2, hyi - 2, "yellow")
    # nose
    f.dots([(hxi + 7, hyi + 1), (hxi + 8, hyi + 1)], "umber")
    f.dots([(hxi + 4, hyi + 2), (hxi + 5, hyi + 2)], "pink")
    # pointy star hat, tip flopping back
    hat = poly([(hx - 7, hy - 2.5), (hx + 7, hy - 3.5), (hx + 3, hy - 5.5), (hx - 1, hy - 12), (hx - 6, hy - 14),
                (hx - 3, hy - 9), (hx - 4, hy - 5)])
    f.add(hat, HATM, centre=(hx - 3, hy - 9), radius=(6, 7), bias=0.1)
    f.recolor({(x, y) for (x, y) in hat if y >= hy - 3.5}, "gold_d")
    f.recolor({(x, y) for (x, y) in hat if y >= hy - 3.5 and x % 3 == 0}, "gold")
    for (qx, qy) in ((hx - 2, hy - 8), (hx + 1, hy - 6)):
        f.recolor({(int(qx), int(qy))}, "yellow")
    f.dots([(int(hx - 6), int(hy - 14)), (int(hx - 7), int(hy - 14))], "yellow")
    # staff with the star
    shaft = {(int(round(sx)), y): ("brown" if y % 4 else "brown_d") for y in range(int(sy - 8), ground - hop + 1)}
    f.pix(shaft, WOOD)
    tx, ty = int(round(sx)), int(sy - 10)
    star = {(tx, ty - 2): "yellow", (tx - 1, ty): "yellow", (tx + 1, ty): "yellow", (tx, ty + 1): "gold",
            (tx, ty - 1): "white", (tx, ty): "white", (tx - 2, ty - 1): "gold", (tx + 2, ty - 1): "gold",
            (tx - 1, ty + 1): "gold", (tx + 1, ty + 1): "gold", (tx - 1, ty - 1): "yellow", (tx + 1, ty - 1): "yellow"}
    f.pix(star, Mat(["gold_d", "gold", "yellow"], outline="brown_d"))
    if glow:
        r = 2 + glow
        for dy in range(-r - 1, r + 2):
            for dx in range(-r - 1, r + 2):
                d = abs(dx) + abs(dy)
                if d <= r + 1:
                    f.glow(tx + dx, ty - 1 + dy, alpha_px("yellow", max(30, 140 - d * 28)))
    if extra:
        extra(f)
    return f


def merlin_v25() -> list:
    old = art_cast.merlin()
    fr = {
        "idle": [merlin_frame().render(), merlin_frame(bob=1, glow=2).render(), merlin_frame(bob=1, blink=True).render(),
                 merlin_frame(glow=2).render()],
        "run": [merlin_frame(hop=h, lean=0.5, staff_at=(23.5, 19.0 - h)).render() for h in (0, 1, 2, 1, 0, 0)],
        "cast": [merlin_frame(staff_at=(22.0, 15.0), arm_up=2, glow=2).render(),
                 merlin_frame(staff_at=(22.0, 13.0), arm_up=3, glow=3, bob=-1).render(),
                 merlin_frame(staff_at=(22.0, 14.0), arm_up=2, glow=3).render()],
    }
    return frames_like(old, fr)
