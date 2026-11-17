"""v2.5 (CR1) the scarecrow family and the crow, redrawn with the rig renderer. All face right.

  scarecrow          32  burlap sack head, floppy straw hat, purple patched coat, hops on a post, spear
  scarecrow_archer   32  pointed straw hat, quiver of lilac-fletched arrows, short bow
  scarecrow_captain  48  bicorne with a purple plume, big coat with gold buttons, pitchfork
  crow               24  blue-black crow with violet sheen, yellow beak, one glinting eye

Animation names, counts, loop flags and timings come from the previous generators (frames_like),
so line A's timing does not move. Feet (the post's foot) sit on the bottom rows like before.
"""

from __future__ import annotations

import math

import art_cast
import art_enemies
from paint import alpha_px
from rig import Fig, Mat, blade, capsule, ellipse, frames_like, poly, rect, union

SACK = Mat(["dirt", "sand", "cream", "white"], outline="brown_d", lit="brown", fur=0.08, sep="dirt", sep_lit="sand")
STRAW = Mat(["gold_d", "gold", "gold_l", "yellow"], outline="brown_d", lit="brown", fur=0.25)
HAT = Mat(["brown_d", "brown", "gold_d", "gold"], outline="umber", lit="brown_d", fur=0.1)
COAT = Mat(["plum", "dusk", "violet", "lilac"], outline="ink", lit="plum")
WOOD = Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber")
STEEL = Mat(["iron", "steel_d", "steel", "steel_l"], outline="navy", lit="iron", spec="white", spec_at=0.84)
ROPE = Mat(["gold_d", "gold", "gold_l"], outline="brown_d")
FEATHER = Mat(["plum", "violet", "lilac"], outline="ink", lit="plum")
ARCHER_COAT = Mat(["plum", "wine", "red_d", "rose"], outline="ink", lit="plum")
CROW = Mat(["navy", "night_d", "night", "violet"], outline="ink", lit="navy")
BEAK = Mat(["gold_d", "gold", "yellow"], outline="brown_d")


def stars(f: Fig, pts) -> None:
    for (x, y) in pts:
        f.dots([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "yellow")
        f.dot(x, y, "white")


def sack_face(f: Fig, hx: float, hy: float, mood: str = "grin", k: float = 1.0) -> None:
    """Stitched face on the sack: button eyes, zig-zag stitched mouth, a patch."""
    hxi, hyi = int(round(hx)), int(round(hy))
    e = int(round(2 * k))
    if mood == "hurt":
        for (x, y) in ((hxi + 1, hyi - 1), (hxi + 1 + e + 2, hyi - 1)):
            f.dots([(x - 1, y - 1), (x + 1, y + 1), (x + 1, y - 1), (x - 1, y + 1), (x, y)], "umber")
    else:
        for x in (hxi + 1, hxi + 1 + e + 2):
            f.dots([(x - 1, hyi - 1), (x, hyi - 1), (x - 1, hyi), (x, hyi)], "ink")
            f.dot(x - 1, hyi - 1, "violet")
        if mood == "angry":
            f.dots([(hxi - 1, hyi - 3), (hxi, hyi - 2), (hxi + 1 + e + 3, hyi - 3), (hxi + 1 + e + 2, hyi - 2)], "brown_d")
    my = hyi + int(round(3 * k))
    xs = range(hxi - 1, hxi + 2 + int(round(4 * k)))
    for i, x in enumerate(xs):
        f.dot(x, my, "brown_d")
        if i % 2 == 0:
            f.dot(x, my - 1 if mood != "hurt" else my + 1, "brown_d")
    # a stitched patch on the cheek
    f.dots([(hxi - 3, hyi + 1), (hxi - 3, hyi + 2)], "dirt")


def straw_tuft(f: Fig, x: float, y: float, dirx: float, n: int = 3, length: float = 3.0) -> None:
    """A fan of straw strands poking out (from a sleeve, the hat brim, the coat hem)."""
    pts = set()
    for i in range(n):
        a = math.atan2(1.0, dirx) + (i - (n - 1) / 2) * 0.45
        pts |= capsule(x, y, x + math.cos(a) * length * (1 if dirx >= 0 else -1) * abs(dirx or 1),
                       y + math.sin(a) * length, 0.6)
    f.add(pts, STRAW, bias=0.05, sep=True)


# --------------------------------------------------------------------------
# scarecrow (32)
# --------------------------------------------------------------------------

def spear(f: Fig, hx: float, hy: float, deg: float, length: int = 15) -> None:
    a = -math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    shaft = {}
    for i in range(-5, length):
        shaft[(int(round(hx + dx * i)), int(round(hy + dy * i)))] = "brown" if i % 5 else "brown_d"
    f.pix(shaft, WOOD)
    tx, ty = hx + dx * length, hy + dy * length
    f.pix(blade(tx, ty, a, 4, 2), STEEL)


def scarecrow_frame(bob: int = 0, lean: float = 0.0, mood: str = "grin", spear_at=(21.5, 18.5), spear_deg=60.0,
                    hop: int = 0, arm_lift: float = 0.0, extra=None, tilt: float = 0.0, w: int = 32) -> Fig:
    f = Fig(w, w, seed=21)
    ground = w - 2
    cx = w / 2 - 1 + lean
    by = ground - 9.5 + bob - hop
    # post (single leg) with a straw foot
    post = rect(int(round(cx - 0.5 - lean * 0.3)), int(by + 3), 2, int(ground - hop - by - 3))
    f.add(post, WOOD, mode="cyl_v", bias=0.05)
    straw_tuft(f, cx + 0.5 - lean * 0.3, ground - hop - 1, 0.0, 3, 1.6)
    # back arm (cross-bar) with straw hand
    f.add(capsule(cx - 2, by - 3, cx - 6.5, by - 1.5 - arm_lift, 1.3), COAT, bias=-0.15)
    straw_tuft(f, cx - 7.0, by - 1.0 - arm_lift, -1.0, 3, 2.0)
    # coat: a bell shape with a ragged hem
    coat = poly([(cx - 4.0, by - 5.5), (cx + 4.0, by - 5.5), (cx + 5.5, by + 2.5), (cx + 3.5, by + 3.8),
                 (cx + 1.5, by + 2.8), (cx - 0.5, by + 3.8), (cx - 2.5, by + 2.8), (cx - 5.0, by + 3.6)])
    f.add(coat, COAT, centre=(cx - 1.5, by - 3.0), radius=(6.5, 7.0), bias=0.06)
    # patch, rope belt, buttons
    f.recolor({(int(cx - 3), int(by)), (int(cx - 2), int(by)), (int(cx - 3), int(by + 1)), (int(cx - 2), int(by + 1))},
              "rose")
    f.recolor({(x, int(by - 1)) for x in range(int(cx - 5), int(cx + 6))}, "gold_d")
    f.recolor({(x, int(by - 1)) for x in range(int(cx - 5), int(cx + 6)) if x % 2 == 0}, "gold")
    f.dots([(int(cx + 1), int(by - 4)), (int(cx + 1), int(by + 1))], "gold_l")
    straw_tuft(f, cx + 1.0, by + 3.5, 0.3, 2, 1.6)
    # head: burlap sack tied at the neck
    hx, hy = cx + 1.0 + tilt, by - 10.5
    head = union(ellipse(hx, hy, 5.6, 5.0), ellipse(hx + 0.5, hy + 1.5, 5.0, 4.4))
    f.add(head, SACK, centre=(hx - 1.5, hy - 1.5), radius=(6.0, 5.8), bias=0.1)
    f.add({(x, int(hy + 5)) for x in range(int(hx - 2), int(hx + 3))}, ROPE, flat=1)
    sack_face(f, hx + 1.0, hy + 0.5, mood)
    # floppy hat
    brim = poly([(hx - 7.5, hy - 3.0), (hx + 7.0, hy - 4.5), (hx + 7.5, hy - 3.0), (hx - 7.0, hy - 1.2)])
    crown = poly([(hx - 4.0, hy - 3.0), (hx - 3.0, hy - 8.0), (hx + 2.0, hy - 9.0), (hx + 4.0, hy - 4.0)])
    f.add(crown, HAT, centre=(hx - 2, hy - 8), radius=(5, 4), bias=0.08)
    f.recolor({(x, y) for (x, y) in crown if y == int(hy - 5)}, "violet")
    f.add(brim, HAT, centre=(hx - 3, hy - 4), radius=(8, 2), bias=0.1)
    straw_tuft(f, hx - 6.0, hy - 1.0, -0.8, 2, 2.0)
    # front arm holding the spear
    if spear_at:
        spear(f, spear_at[0], spear_at[1] - hop + bob, spear_deg)
        f.add(capsule(cx + 2.5, by - 3.5, spear_at[0] - 0.5, spear_at[1] - hop + bob, 1.3), COAT, bias=0.08)
        straw_tuft(f, spear_at[0], spear_at[1] - hop + bob + 0.5, 1.0, 2, 1.4)
    if extra:
        extra(f)
    return f


def scarecrow_v25() -> list:
    old = art_enemies.scarecrow_v2()
    fr = {
        "idle": [scarecrow_frame().render(), scarecrow_frame(bob=1, tilt=0.5).render(),
                 scarecrow_frame(bob=1, tilt=1.0, arm_lift=0.5).render(), scarecrow_frame(tilt=0.5).render()],
        "run": [scarecrow_frame(hop=h, lean=0.5, bob=b, arm_lift=a).render()
                for (h, b, a) in ((0, 1, 0), (2, 0, 1), (4, 0, 1.5), (3, 0, 1), (1, 0, 0.5), (0, 1, 0))],
        "attack": [scarecrow_frame(lean=-1.0, mood="angry", spear_at=(17.5, 16.0), spear_deg=40).render(),
                   scarecrow_frame(lean=1.0, mood="angry", spear_at=(21.5, 19.0), spear_deg=5).render(),
                   scarecrow_frame(lean=1.5, mood="angry", spear_at=(22.5, 19.5), spear_deg=-5).render(),
                   scarecrow_frame(mood="grin", spear_at=(21.0, 19.0), spear_deg=40).render()],
        "hurt": [scarecrow_frame(lean=-1.5, mood="hurt", tilt=-1.0, extra=lambda f: stars(f, [(10, 2), (21, 3)])).render(),
                 scarecrow_frame(lean=-1.0, mood="hurt", tilt=-0.5).render()],
    }
    return frames_like(old, fr)


# --------------------------------------------------------------------------
# archer (32)
# --------------------------------------------------------------------------

def bow(f: Fig, x: float, y: float, drawn: int = 0, arrow: bool = False) -> None:
    pts = {}
    for dy in range(-7, 8):
        bend = 2.6 * (1 - (dy / 7.5) ** 2)
        pts[(int(round(x + bend)), y + dy)] = "brown" if abs(dy) < 6 else "brown_d"
    pts[(int(round(x + 2.6)), y - 1)] = "gold_l"
    pts[(int(round(x + 2.6)), y)] = "gold"
    f.pix(pts, WOOD)
    string = {}
    for dy in range(-6, 7):
        t = 1.0 - abs(dy) / 6.5
        string[(int(round(x + 0.5 - drawn * t)), y + dy)] = "stone_l"
    for p, c in string.items():
        f.dot(p[0], p[1], c)
    if arrow:
        ax = int(round(x + 0.5 - drawn))
        for i in range(0, 11):
            f.dot(ax + i, y, "brown" if i < 9 else "steel_l")
        f.dots([(ax + 10, y - 1), (ax + 10, y + 1), (ax + 11, y)], "steel")
        f.dots([(ax, y - 1), (ax + 1, y - 1), (ax, y + 1)], "lilac")


def archer_frame(bob: int = 0, lean: float = 0.0, mood: str = "grin", hop: int = 0, drawn: int = 0,
                 arrow: bool = False, bow_at=(22, 17), extra=None, tilt: float = 0.0) -> Fig:
    f = Fig(32, 32, seed=23)
    ground = 30
    cx = 15 + lean
    by = ground - 9.5 + bob - hop
    # quiver on the back
    q = poly([(cx - 6.5, by - 7.5), (cx - 4.0, by - 8.5), (cx - 1.5, by + 0.5), (cx - 4.0, by + 1.5)])
    f.add(q, HAT, centre=(cx - 5, by - 6), radius=(3, 5), bias=0.05)
    f.dots([(int(cx - 6), int(by - 10)), (int(cx - 5), int(by - 10)), (int(cx - 4), int(by - 11))], "lilac")
    f.dots([(int(cx - 6), int(by - 9)), (int(cx - 4), int(by - 10))], "violet")
    post = rect(int(round(cx - 0.5)), int(by + 3), 2, int(ground - hop - by - 3))
    f.add(post, WOOD, mode="cyl_v", bias=0.05)
    straw_tuft(f, cx + 0.5, ground - hop - 1, 0.0, 3, 1.6)
    coat = poly([(cx - 3.5, by - 5.5), (cx + 3.5, by - 5.5), (cx + 5.0, by + 2.5), (cx + 3.0, by + 3.6),
                 (cx + 1.0, by + 2.6), (cx - 1.0, by + 3.6), (cx - 3.0, by + 2.6), (cx - 4.6, by + 3.4)])
    f.add(coat, ARCHER_COAT,
          centre=(cx - 1.5, by - 3.0), radius=(6.5, 7.0), bias=0.06)
    f.recolor({(x, int(by - 1)) for x in range(int(cx - 5), int(cx + 6))}, "brown")
    # quiver strap across the chest
    f.recolor({(int(cx - 3 + i), int(by - 5 + i)) for i in range(6)}, "brown_d")
    straw_tuft(f, cx + 1.0, by + 3.4, 0.3, 2, 1.5)
    hx, hy = cx + 1.0 + tilt, by - 10.5
    head = union(ellipse(hx, hy, 5.2, 4.8), ellipse(hx + 0.5, hy + 1.4, 4.6, 4.2))
    f.add(head, SACK, centre=(hx - 1.5, hy - 1.5), radius=(6.0, 5.6), bias=0.1)
    f.add({(x, int(hy + 5)) for x in range(int(hx - 2), int(hx + 3))}, ROPE, flat=1)
    sack_face(f, hx + 1.0, hy + 0.5, mood)
    # pointed straw hat (conical)
    hat = poly([(hx - 7.0, hy - 2.0), (hx + 0.5, hy - 11.0), (hx + 7.0, hy - 2.5), (hx + 0.5, hy - 1.0)])
    f.add(hat, STRAW, centre=(hx - 2, hy - 7), radius=(6, 5), bias=0.05)
    f.recolor({(x, y) for (x, y) in hat if y == int(hy - 3)}, "gold_d")
    f.recolor({(x, y) for (x, y) in hat if y == int(hy - 4)}, "violet")
    bx, byy = bow_at
    bow(f, bx, int(byy - hop + bob), drawn, arrow)
    f.add(capsule(cx + 2.5, by - 3.5, bx + 0.5, byy - hop + bob, 1.2), ARCHER_COAT, bias=0.08)
    f.add(capsule(cx - 1.5, by - 3.5, bx - 1 - drawn, byy - hop + bob, 1.1), ARCHER_COAT, bias=-0.05)
    straw_tuft(f, bx + 1.0, byy - hop + bob + 0.5, 1.0, 2, 1.2)
    if extra:
        extra(f)
    return f


def archer_v25() -> list:
    old = art_cast.scarecrow_archer()
    fr = {
        "idle": [archer_frame().render(), archer_frame(bob=1, tilt=0.5).render(),
                 archer_frame(bob=1, tilt=0.5).render(), archer_frame().render()],
        "run": [archer_frame(hop=h, lean=0.5, bob=b).render()
                for (h, b) in ((0, 1), (2, 0), (4, 0), (3, 0), (1, 0), (0, 1))],
        "attack": [archer_frame(mood="angry", drawn=3, arrow=True).render(),
                   archer_frame(mood="angry", drawn=0, lean=-0.5,
                                extra=lambda f: f.dots([(27, 17), (28, 17), (29, 17), (30, 17)], "white")).render(),
                   archer_frame(mood="grin").render()],
        "hurt": [archer_frame(lean=-1.5, mood="hurt", tilt=-1.0, extra=lambda f: stars(f, [(9, 3), (21, 2)])).render()],
        "aim": [archer_frame(mood="angry", drawn=3, arrow=True).render(),
                archer_frame(mood="angry", drawn=4, arrow=True, bob=1).render()],
    }
    return frames_like(old, fr)


# --------------------------------------------------------------------------
# captain (48)
# --------------------------------------------------------------------------

def pitchfork(f: Fig, hx: float, hy: float, deg: float, length: int = 22) -> None:
    a = -math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    shaft = {}
    for i in range(-7, length):
        shaft[(int(round(hx + dx * i)), int(round(hy + dy * i)))] = "brown" if i % 6 else "brown_d"
    f.pix(shaft, WOOD)
    tx, ty = hx + dx * length, hy + dy * length
    tines = {}
    for k in (-2, 0, 2):
        for i in range(0, 6):
            x = int(round(tx + nx * k + dx * i))
            y = int(round(ty + ny * k + dy * i))
            tines[(x, y)] = "steel_l" if i > 0 and k <= 0 else "steel"
    for k in range(-2, 3):
        tines[(int(round(tx + nx * k)), int(round(ty + ny * k)))] = "steel_d"
    f.pix(tines, STEEL)


def captain_frame(bob: int = 0, lean: float = 0.0, mood: str = "angry", hop: int = 0, fork_at=(32, 26),
                  fork_deg: float = 80.0, fork: bool = True, arm_lift: float = 0.0, plume: int = 0,
                  extra=None, tilt: float = 0.0) -> Fig:
    f = Fig(48, 48, seed=27)
    ground = 46
    cx = 22 + lean
    by = ground - 14 + bob - hop
    post = rect(int(round(cx - 1)), int(by + 4), 3, int(ground - hop - by - 4))
    f.add(post, WOOD, mode="cyl_v", bias=0.05)
    straw_tuft(f, cx + 0.5, ground - hop - 1.5, 0.0, 4, 2.4)
    # back arm and straw hand
    f.add(capsule(cx - 3, by - 6, cx - 10.5, by - 3 - arm_lift, 2.0), COAT, bias=-0.15)
    straw_tuft(f, cx - 11.0, by - 2.5 - arm_lift, -1.0, 4, 2.6)
    # long coat with lapels, gold buttons and a ragged hem
    coat = poly([(cx - 6.5, by - 9.0), (cx + 6.5, by - 9.0), (cx + 8.5, by + 4.0), (cx + 6.0, by + 6.0),
                 (cx + 3.0, by + 4.5), (cx + 0.5, by + 6.0), (cx - 2.5, by + 4.5), (cx - 5.0, by + 6.0),
                 (cx - 8.0, by + 4.5)])
    f.add(coat, COAT, centre=(cx - 2.5, by - 5.0), radius=(10, 11), bias=0.06)
    lapel = poly([(cx - 1.0, by - 9.0), (cx + 4.0, by - 9.0), (cx + 1.5, by - 3.0)])
    f.add(lapel, Mat(["wine", "red_d", "red"], outline="ink", lit="plum"), flat=1)
    for yy in (-5, -1, 3):
        f.dots([(int(cx + 2), int(by + yy)), (int(cx + 3), int(by + yy))], "gold")
        f.dot(int(cx + 2), int(by + yy), "yellow")
    f.recolor({(x, int(by + 1)) for x in range(int(cx - 8), int(cx + 9))}, "brown_d")
    f.recolor({(x, int(by + 1)) for x in range(int(cx - 8), int(cx + 9)) if x % 3 == 0}, "brown")
    f.recolor({(int(cx - 5), int(by - 3)), (int(cx - 4), int(by - 3)), (int(cx - 5), int(by - 2)),
               (int(cx - 4), int(by - 2)), (int(cx - 5), int(by - 1))}, "rose")
    straw_tuft(f, cx + 2.0, by + 5.5, 0.3, 3, 2.0)
    straw_tuft(f, cx - 4.0, by + 5.5, -0.3, 2, 2.0)
    hx, hy = cx + 1.5 + tilt, by - 16.5
    head = union(ellipse(hx, hy, 7.6, 6.8), ellipse(hx + 0.5, hy + 2.0, 6.8, 6.0))
    f.add(head, SACK, centre=(hx - 2.0, hy - 2.0), radius=(8.5, 8.0), bias=0.1)
    f.add({(x, int(hy + 7)) for x in range(int(hx - 3), int(hx + 4))}, ROPE, flat=1)
    sack_face(f, hx + 1.0, hy + 0.5, mood, k=1.4)
    # bicorne hat with a gold trim and a purple plume
    hat = poly([(hx - 11.0, hy - 4.0), (hx - 6.0, hy - 9.0), (hx + 1.0, hy - 11.5), (hx + 8.0, hy - 9.0),
                (hx + 11.0, hy - 4.5), (hx + 6.0, hy - 5.5), (hx + 0.5, hy - 4.5), (hx - 6.0, hy - 5.0)])
    f.add(hat, Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber", lit="umber"),
          centre=(hx - 3, hy - 10), radius=(10, 5), bias=0.05)
    f.recolor({(x, y) for (x, y) in hat if (x, y + 1) not in hat}, "gold")
    f.dots([(int(hx), int(hy - 8)), (int(hx + 1), int(hy - 8)), (int(hx), int(hy - 7)), (int(hx + 1), int(hy - 7))],
           "yellow")
    px, py = hx - 1.0, hy - 10.0
    plume_pts = union(capsule(px, py, px - 3.5, py - 6.0 - plume, 1.6), capsule(px - 3.5, py - 6.0 - plume,
                                                                                  px - 7.0, py - 7.5 - plume * 0.5, 1.3))
    f.add(plume_pts, FEATHER, centre=(px - 4, py - 7), radius=(4, 3), bias=0.1)
    if fork:
        fx, fy = fork_at
        pitchfork(f, fx, fy - hop + bob, fork_deg)
        f.add(capsule(cx + 4.0, by - 6.0, fx - 0.5, fy - hop + bob, 2.0), COAT, bias=0.08)
        straw_tuft(f, fx + 0.5, fy - hop + bob + 0.5, 1.0, 3, 1.8)
    if extra:
        extra(f)
    return f


def captain_down() -> object:
    f = Fig(48, 48, seed=29)
    f.add(union(ellipse(16, 42, 10, 3.5), ellipse(26, 43, 9, 3)), STRAW, bias=0.1)
    for x0 in (6, 12, 19, 27, 33):
        f.add(capsule(x0, 44, x0 + 3, 39 + (x0 % 3), 0.6), STRAW, bias=0.05)
    f.add(poly([(18, 37), (24, 32), (31, 32), (37, 37), (30, 36), (24, 36)]),
          Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber"), bias=0.05)
    f.add(union(capsule(23, 32, 20, 26, 1.4), capsule(20, 26, 16, 24, 1.2)), FEATHER, bias=0.1)
    f.recolor({(x, 36) for x in range(19, 37)}, "gold")
    pitchfork(f, 6, 45, 8, length=24)
    return f.render()


def captain_v25() -> list:
    old = art_cast.scarecrow_captain()
    fr = {
        "idle": [captain_frame().render(), captain_frame(bob=1, plume=1, tilt=0.5).render(),
                 captain_frame(bob=1, plume=1, tilt=0.5).render(), captain_frame().render()],
        "run": [captain_frame(hop=h, lean=0.5, bob=b, plume=p).render()
                for (h, b, p) in ((0, 1, 0), (2, 0, 1), (5, 0, 2), (4, 0, 2), (1, 0, 1), (0, 1, 0))],
        "attack": [captain_frame(lean=-1.5, fork_at=(28, 22), fork_deg=125, arm_lift=1).render(),
                   captain_frame(lean=1.5, fork_at=(34, 28), fork_deg=10).render(),
                   captain_frame(lean=1.0, fork_at=(33, 30), fork_deg=-25).render()],
        "hurt": [captain_frame(lean=-2.0, mood="hurt", tilt=-1.5,
                               extra=lambda f: stars(f, [(12, 6), (32, 5)])).render()],
        "throw": [captain_frame(lean=-2.0, fork_at=(26, 18), fork_deg=160, arm_lift=2).render(),
                  captain_frame(lean=1.5, fork=False, arm_lift=1,
                                extra=lambda f: f.dots([(36, 20), (37, 20), (38, 21)], "white")).render(),
                  captain_frame(lean=0.5, fork=False).render()],
        "rally": [captain_frame(fork_at=(30, 18), fork_deg=88, bob=-1, plume=2, mood="angry").render(),
                  captain_frame(fork_at=(30, 16), fork_deg=92, bob=-2, plume=3, mood="grin").render()],
        "down": [captain_down()],
    }
    return frames_like(old, fr)


# --------------------------------------------------------------------------
# crow (24)
# --------------------------------------------------------------------------

def crow_frame(wing: str = "mid", bob: int = 0, dive: float = 0.0, mouth: bool = False, hurt: bool = False,
               extra=None) -> object:
    f = Fig(24, 24, seed=31)
    cx, cy = 11.0, 12.0 + bob
    a = -math.radians(dive)
    # far wing
    wings = {
        "up": [(cx - 1, cy - 1), (cx - 4, cy - 8), (cx - 9, cy - 9), (cx - 6, cy - 3)],
        "mid": [(cx - 1, cy - 1), (cx - 7, cy - 4), (cx - 11, cy - 2), (cx - 5, cy + 1)],
        "down": [(cx - 1, cy), (cx - 6, cy + 4), (cx - 9, cy + 7), (cx - 4, cy + 2)],
        "fold": [(cx - 1, cy - 1), (cx - 7, cy), (cx - 8, cy + 2), (cx - 2, cy + 2)],
    }
    far = [(x - 1, y - 1) for (x, y) in wings[wing]]
    f.add(poly(far), CROW, bias=-0.2)
    # tail feathers
    f.add(poly([(cx - 4, cy + 1), (cx - 10, cy + 3), (cx - 10, cy + 5), (cx - 3, cy + 3)]), CROW, bias=-0.05)
    body = ellipse(cx, cy + 0.5, 5.0, 3.6)
    f.add(body, CROW, centre=(cx - 1.5, cy - 1.5), radius=(5.5, 4.5), bias=0.08)
    hx, hy = cx + 4.5 + math.cos(a) * 0.5, cy - 2.5 - math.sin(a) * 2
    f.add(ellipse(hx, hy, 3.2, 3.0), CROW, centre=(hx - 1, hy - 1), radius=(3.5, 3.5), bias=0.12)
    # beak
    bx, by = int(round(hx + 2.5)), int(round(hy))
    beak = {(bx, by - 1): "yellow", (bx + 1, by - 1): "gold", (bx + 2, by): "gold", (bx, by): "gold",
            (bx + 1, by): "gold_d"}
    if mouth:
        beak = {(bx, by - 2): "yellow", (bx + 1, by - 2): "gold", (bx + 2, by - 2): "gold_d",
                (bx, by + 1): "gold", (bx + 1, by + 1): "gold_d"}
    f.pix(beak, BEAK)
    if hurt:
        f.dots([(bx - 3, by - 2), (bx - 1, by), (bx - 1, by - 2), (bx - 3, by)], "lilac")
        f.dot(bx - 2, by - 1, "lilac")
    else:
        f.dots([(bx - 2, by - 2), (bx - 1, by - 2), (bx - 2, by - 1)], "white")
        f.dot(bx - 1, by - 1, "ink")
    # near wing
    near = wings[wing]
    f.add(poly(near), CROW, centre=(cx - 5, cy - 4), radius=(6, 5), bias=0.0)
    wp = poly(near)
    f.recolor({(x, y) for (x, y) in wp if (x + y) % 3 == 0 and (x, y + 1) in wp and (x - 1, y) not in wp}, "violet")
    # feet
    f.dots([(int(cx), int(cy + 4)), (int(cx + 2), int(cy + 4)), (int(cx), int(cy + 5)), (int(cx + 2), int(cy + 5))],
           "gold_d")
    if extra:
        extra(f)
    return f.render()


def crow_v25() -> list:
    old = art_enemies.crow_v2()
    fr = {
        "idle": [crow_frame("mid"), crow_frame("up", bob=-1), crow_frame("mid"), crow_frame("down", bob=1)],
        "run": [crow_frame(w, bob=b) for (w, b) in (("up", -1), ("mid", 0), ("down", 1), ("down", 1), ("mid", 0),
                                                     ("up", -1))],
        "attack": [crow_frame("up", bob=-1, mouth=True), crow_frame("fold", bob=1, dive=-25, mouth=True),
                   crow_frame("fold", bob=2, dive=-35, mouth=True), crow_frame("mid", bob=0)],
        "hurt": [crow_frame("up", hurt=True, extra=lambda f: stars(f, [(5, 3)])), crow_frame("mid", hurt=True, bob=1)],
    }
    return frames_like(old, fr)


def _unused() -> None:
    _ = alpha_px
