"""Dialogue portraits (v2.3 CS2): assets/portraits/<speaker>/<expression>.png, 48x48, opaque.

Every portrait is a bust on a small storybook backdrop. Heroes (goldie, bulldog) face right and
sit on the left of the dialogue box; everyone else faces left (drawn facing right, then mirrored).
Each character is one painted base plus an expression layer (eyes, brows, mouth, extras), so all
expressions of a character line up exactly and the box can swap them without a jump.

Designs are original (docs/STORY.md section 3): Merlin is an elderly Shih Tzu wizard with a blue
star hat, round glasses and a star-topped staff (no owl); Morgana is only a purple fox silhouette.
"""

from __future__ import annotations

import math
import random

import paint as P
from pixel import Canvas, res_path

S = 48

PORTRAITS: dict[str, list[str]] = {
    "goldie": ["normal", "happy", "surprised", "serious", "tired"],
    "bulldog": ["normal", "happy", "serious"],
    "merlin": ["normal", "surprised", "proud", "worried"],
    "black_knight": ["normal"],
    "morgana": ["smirk"],
    "scarecrow_captain": ["angry"],
    "crow": ["normal"],
}
FACES_LEFT = {"merlin", "black_knight", "morgana", "scarecrow_captain", "crow"}


def _layer() -> Canvas:
    return Canvas(S, S)


# --------------------------------------------------------------------------
# backdrops
# --------------------------------------------------------------------------

def backdrop(kind: str) -> Canvas:
    c = Canvas(S, S, P.rgba("sky"))
    if kind == "goldie":     # bright morning sky
        P.radial(c, 34, 10, 52, ["water", "sky", "sky", "sky_l"], sharp=1.4)
        _clouds(c, [(4, 40, 9), (40, 44, 7)], "white", "sky_l")
    elif kind == "bulldog":  # warm meadow afternoon
        P.radial(c, 34, 10, 54, ["dirt", "peach", "gold_l", "cream"], sharp=1.4)
        for x in range(S):
            h = 41 + int(2 * math.sin(x / 7.0))
            for y in range(h, S):
                c.set(x, y, P.pick(["leaf", "leaf_d"], (y - h) / 5, x, y))
    elif kind == "merlin":   # starry dusk
        P.radial(c, 16, 12, 56, ["night_d", "night", "dusk", "violet"], sharp=1.3)
        rng = random.Random(4)
        for (x, y) in P.scatter(rng, 14, 0, 0, S, S):
            c.set(x, y, "lilac" if rng.random() < 0.5 else "white")
        P.star4(c, 38, 8, "gold_l", 1, "white")
        P.star4(c, 7, 30, "lilac", 1, "white")
    elif kind == "black_knight":   # storm
        P.vgrad(c, 0, 0, S, S, ["night", "night_d", "night_d", "plum"], sharp=1.3)
        bolt = [(44, 0), (40, 9), (43, 10), (38, 22)]
        for i in range(len(bolt) - 1):
            for (x, y) in P.thick_line(*bolt[i], *bolt[i + 1], 0.5):
                c.set(x, y, "lilac")
                c.set(x + 1, y, "violet")
        rng = random.Random(3)
        for k in range(26):
            x, y = rng.randrange(0, S), rng.randrange(0, S - 6)
            for j in range(3):
                c.set(x - j, y + j * 2, "night")
    elif kind == "morgana":  # deep night, a full moon right behind her
        c = morgana_backdrop()
    elif kind == "scarecrow_captain":   # dusk farm
        P.vgrad(c, 0, 0, S, S, ["dusk", "rose", "orange", "peach"], sharp=1.3)
        for x in range(S):
            h = 38 + int(3 * math.sin(x / 9.0 + 1))
            for y in range(h, S):
                c.set(x, y, "plum" if y > h + 1 else "dusk")
    elif kind == "crow":
        P.vgrad(c, 0, 0, S, S, ["dusk", "rose", "peach"], sharp=1.3)
        for x in range(S):
            h = 34 + int(4 * abs(math.sin(x / 5.0)))
            for y in range(h, S):
                c.set(x, y, "forest_d" if y > h + 2 else "night")
    return c


def _clouds(c: Canvas, puffs, col: str, shade: str) -> None:
    for (x, y, r) in puffs:
        for (dx, rr) in ((-r * 0.6, r * 0.7), (0, r), (r * 0.7, r * 0.75)):
            s = P.ellipse(x + dx, y, rr, rr * 0.7)
            P.fill(c, s, col)
        P.fill(c, {(px, py) for (px, py) in P.ellipse(x, y + 1, r * 1.4, r * 0.5)}, shade)


# --------------------------------------------------------------------------
# Goldie 金毛 (faces right)
# --------------------------------------------------------------------------

FUR = ["brown", "gold_d", "gold", "gold_l", "cream"]
MUZZLE = ["gold", "gold_l", "cream", "white"]
EAR = ["brown", "gold_d", "gold", "gold_l"]
STEEL = ["iron", "steel_d", "steel", "steel_l", "white"]
CAPE = ["plum", "red_d", "red", "pink"]


def goldie_base() -> tuple[Canvas, dict]:
    f = _layer()
    # cape behind the left shoulder
    cape = P.poly([(2, 33), (14, 30), (20, 48), (0, 48)])
    P.shade_shape(f, cape, CAPE, bias=-0.05)
    # far ear peeking behind the head (top right)
    far_ear = P.ellipse(33, 15, 4, 7)
    P.shade_shape(f, far_ear, EAR, bias=-0.15)
    # body: breastplate and pauldrons
    chest = P.poly([(8, 48), (11, 38), (18, 34), (32, 34), (40, 38), (44, 48)])
    P.shade_shape(f, chest, STEEL, centre=(24, 40), radius=(20, 12))
    for x in range(14, 40):
        f.set(x, 44, "steel_d")
    P.fill(f, P.rect(24, 40, 3, 8) & chest, "steel_l")
    pauldron = P.ellipse(13, 41, 7, 5.5)
    P.outline_shape(f, pauldron, "steel_d")
    P.shade_shape(f, pauldron, STEEL, bias=0.05)
    f.set(11, 38, "white")
    # neck fur (cream ruff) and the gold clasp of the cape
    ruff = P.ellipse(27, 33, 10, 4.5)
    P.shade_shape(f, ruff, MUZZLE, bias=0.0)
    for (x, y) in ((17, 35), (18, 35), (17, 36), (18, 36)):
        f.set(x, y, "yellow")
    f.set(17, 35, "white")
    # head
    head = P.ellipse(22, 20, 13.5, 12.8)
    tuft = P.poly([(17, 9), (20, 5), (21, 8), (24, 4), (25, 8), (28, 7), (27, 10)])
    head |= tuft
    P.shade_shape(f, head, FUR, centre=(22, 20), radius=(13.5, 13), bias=0.02)
    # soft lighter forehead blaze
    for (x, y) in P.ellipse(24, 12, 4, 3):
        if P.name_at(f, x, y) in ("gold", "gold_l"):
            f.set(x, y, "gold_l" if (x + y) % 2 or y < 11 else "cream")
    # muzzle
    muzzle = P.ellipse(32, 27, 8.5, 5.8)
    P.outline_shape(f, muzzle - head, "gold_d")
    P.shade_shape(f, muzzle, MUZZLE, bias=0.08)
    # near ear (left), long and floppy with a wavy fringe
    ear = P.poly([(11, 10), (7, 15), (5, 24), (5, 31), (8, 35), (11, 33), (13, 36), (16, 32), (17, 24), (17, 13)])
    P.outline_shape(f, ear, "brown")
    P.shade_shape(f, ear, EAR, centre=(11, 20), radius=(7, 14), bias=0.05)
    for (x, y) in ((7, 33), (10, 32), (14, 34)):
        f.set(x, y, "brown_d")
    # nose
    P.stamp(f, [".oo.", "oooo", ".oi."], 37, 22, NOSE_L)
    f.set(37, 22, "iron")
    f.set(38, 22, "steel_l")
    # cheek blush
    for (x, y) in ((17, 26), (18, 26), (19, 26), (30, 24), (31, 24)):
        f.set(x, y, "pink")
    f.outline_all("ink")
    return f, {"eye_l": (19, 17), "eye_r": (30, 17), "mouth": (38, 26)}


NOSE_L = {"o": "ink", "i": "iron", "w": "white"}
EYE_L = {"o": "ink", "n": "brown_d", "w": "white", "b": "gold_d", "B": "brown", "p": "pink", "s": "sky_l",
         "r": "red", "R": "red_d", "c": "cream", "g": "gold_l", "G": "gold", "u": "sky", "l": "stone_l",
         "t": "stone", "T": "stone_d", "y": "yellow"}

# big glossy eyes (near eye 5x6, far eye 4x5)
EYE_NEAR = ["wwo..", "wwoo.", "ooooo", "ooono", "onnno", ".ooo."]
EYE_NEAR = [".ooo.", "owwoo", "owwoo", "ooooo", "onnwo", ".ooo."]
EYE_FAR = [".oo.", "owoo", "oooo", "onwo", ".oo."]


def goldie(expr: str) -> Canvas:
    f, a = goldie_base()
    ex, ey = a["eye_l"]
    fx, fy = a["eye_r"]
    mx, my = a["mouth"]
    if expr in ("normal", "serious"):
        P.stamp(f, EYE_NEAR, ex, ey, EYE_L)
        P.stamp(f, EYE_FAR, fx, fy + 1, EYE_L)
    if expr == "normal":
        for (x, y) in ((mx, my - 1), (mx, my), (mx - 1, my + 1), (mx - 2, my + 1), (mx - 3, my + 1), (mx - 4, my)):
            f.set(x, y, "ink")
        f.set(mx - 2, my + 2, "pink")
        _brows(f, [(ex, ey - 2), (ex + 1, ey - 3), (ex + 2, ey - 3)], [(fx + 1, fy - 2), (fx + 2, fy - 2)], "gold_d")
    elif expr == "happy":
        P.stamp(f, [".ooo.", "o...o"], ex, ey + 2, EYE_L)
        P.stamp(f, [".oo.", "o..o"], fx, fy + 2, EYE_L)
        P.stamp(f, ["ooooo", ".orro", ".oppo", "..oo."], mx - 5, my, EYE_L)
        _brows(f, [(ex, ey - 1), (ex + 1, ey - 2), (ex + 2, ey - 2), (ex + 3, ey - 1)], [(fx + 1, fy - 1), (fx + 2, fy - 1)], "gold_d")
    elif expr == "surprised":
        P.stamp(f, [".ooo.", "owwoo", "owooo", "ooooo", "ooowo", ".ooo."], ex, ey - 1, EYE_L)
        P.stamp(f, [".oo.", "owoo", "oooo", "oowo", ".oo."], fx, fy, EYE_L)
        P.stamp(f, [".oo.", "orro", "orro", ".oo."], mx - 4, my + 1, EYE_L)
        _brows(f, [(ex, ey - 4), (ex + 1, ey - 5), (ex + 2, ey - 5), (ex + 3, ey - 4)], [(fx, fy - 3), (fx + 1, fy - 4), (fx + 2, fy - 4)], "gold_d")
    elif expr == "serious":
        P.stamp(f, ["oo", "...", ], mx - 4, my + 1, EYE_L)
        P.stamp(f, ["ooo"], mx - 4, my + 1, EYE_L)
        # determined brows slanting down toward the nose
        for i, (x, y) in enumerate([(ex - 1, ey - 3), (ex, ey - 3), (ex + 1, ey - 2), (ex + 2, ey - 2), (ex + 3, ey - 1), (ex + 4, ey - 1)]):
            f.set(x, y, "brown")
        for (x, y) in [(fx, fy - 1), (fx + 1, fy - 2), (fx + 2, fy - 2), (fx + 3, fy - 3)]:
            f.set(x, y, "brown")
        # upper lids cover the top of the eyes
        for x in range(ex, ex + 5):
            f.set(x, ey, "ink")
            if x > ex + 1:
                f.set(x, ey + 1, "ink")
        for x in range(fx, fx + 4):
            f.set(x, fy + 1, "ink")
    elif expr == "tired":
        P.stamp(f, ["ooooo", "onnno", ".ooo."], ex, ey + 3, EYE_L)
        P.stamp(f, ["oooo", "onno", ".oo."], fx, fy + 3, EYE_L)
        P.stamp(f, ["oooo", "oppo", ".po."], mx - 4, my + 1, EYE_L)
        _brows(f, [(ex, ey), (ex + 1, ey - 1), (ex + 2, ey - 1), (ex + 3, ey - 1)], [(fx, fy + 1), (fx + 1, fy), (fx + 2, fy)], "gold_d")
        # sweat drop
        P.stamp(f, ["..o.", ".oso", "osso", "owso", ".oo."], 5, 4, EYE_L)
    return f


def _brows(f: Canvas, near: list, far: list, col: str) -> None:
    for (x, y) in near + far:
        f.set(x, y, col)


def _px(f: Canvas, pts, col: str) -> None:
    for (x, y) in pts:
        f.set(x, y, col)


# --------------------------------------------------------------------------
# Bulldog 貝德維爾 (faces right): wide face, jowls, underbite, brown eye patch, blue tunic
# --------------------------------------------------------------------------

WFUR = ["stone_d", "stone", "stone_l", "white", "white"]
PATCH = ["brown_d", "brown", "gold_d", "gold"]
BLUE = ["night_d", "night", "water_d", "water", "sky"]


def bulldog_base() -> Canvas:
    f = _layer()
    # tunic with the yellow cross, chainmail collar
    body = P.poly([(4, 48), (7, 39), (16, 35), (34, 35), (42, 39), (46, 48)])
    P.shade_shape(f, body, BLUE, centre=(24, 41), radius=(22, 10))
    _px(f, [(x, 42) for x in range(18, 31)] + [(24, y) for y in range(37, 48)], "yellow")
    _px(f, [(x, 43) for x in range(18, 31)] + [(25, y) for y in range(37, 48)], "gold")
    mail = P.ellipse(24, 35, 13, 3.5)
    for (x, y) in mail:
        f.set(x, y, "steel_l" if (x + y) % 2 else "steel")
    P.inner_line(f, mail, "steel_d", ("bottom",))
    # round shield rim with the blue cross (bottom right)
    shield = P.ellipse(45, 46, 10, 10)
    P.fill(f, shield, "steel")
    P.fill(f, P.ellipse(45, 46, 8, 8), "white")
    P.fill(f, P.rect(36, 44, 12, 3) & P.ellipse(45, 46, 8, 8), "water")
    P.fill(f, P.rect(43, 36, 3, 12) & P.ellipse(45, 46, 8, 8), "water")
    P.fill(f, P.edge(P.ellipse(45, 46, 10, 10)), "steel_d")
    # ears (small rose ears folded back)
    for (cx, cy) in ((8, 9), (38, 9)):
        ear = P.ellipse(cx, cy, 5, 3.5)
        P.shade_shape(f, ear, PATCH, bias=0.0)
    # skull: wide and flat
    head = P.ellipse(23, 17, 16, 10.5) | P.rect(8, 15, 31, 8)
    P.shade_shape(f, head, WFUR, centre=(23, 17), radius=(17, 12))
    # brown patch over the near eye
    patch = P.ellipse(14, 14, 7, 6.5) & head
    P.shade_shape(f, patch, PATCH, centre=(14, 14), radius=(8, 7), bias=0.1)
    # big droopy jowls and the protruding lower jaw (underbite)
    jowls = P.ellipse(23, 26, 15, 7) | P.ellipse(13, 30, 7, 5) | P.ellipse(33, 30, 7, 5)
    P.outline_shape(f, jowls - head, "stone")
    P.shade_shape(f, jowls, WFUR, centre=(23, 25), radius=(16, 9), bias=0.08)
    jaw = P.ellipse(23, 33, 6, 3)
    P.outline_shape(f, jaw - jowls, "stone_d")
    P.shade_shape(f, jaw, ["stone", "stone_l", "white"], bias=0.0)
    # forehead wrinkles and the nose rope
    _px(f, [(20, 9), (21, 8), (22, 8), (23, 8), (24, 8), (25, 8), (26, 9)], "stone")
    _px(f, [(19, 18), (20, 17), (21, 17), (25, 17), (26, 17), (27, 18)], "stone")
    # big flat nose
    P.stamp(f, [".oooooo.", "oooooooo", ".oiooio.", "..oooo.."], 19, 19, NOSE_L)
    _px(f, [(21, 19), (22, 19)], "steel_l")
    # upper lip line curving down over the jowls
    _px(f, [(23, 23), (23, 24), (22, 25), (21, 26), (20, 27), (19, 27), (18, 28), (17, 28),
            (24, 25), (25, 26), (26, 27), (27, 27), (28, 28), (29, 28)], "stone_d")
    # cheeks
    _px(f, [(9, 24), (10, 24), (36, 24), (37, 24)], "pink")
    f.outline_all("ink")
    return f


TOOTH = ["o.", "wo", "wo"]


def bulldog(expr: str) -> Canvas:
    f = bulldog_base()
    near, far = (12, 13), (29, 13)
    if expr in ("normal", "serious"):
        P.stamp(f, [".ooo.", "owwoo", "owooo", "ooono", ".ooo."], near[0], near[1], EYE_L)
        P.stamp(f, [".ooo.", "owwoo", "owooo", "ooono", ".ooo."], far[0], far[1], EYE_L)
    if expr == "normal":
        # a stubborn little frown; two teeth of the underbite poke up over the lip
        _px(f, [(near[0] - 1, near[1] - 1), (near[0], near[1] - 2), (near[0] + 1, near[1] - 2), (near[0] + 2, near[1] - 2), (near[0] + 3, near[1] - 1)], "brown_d")
        _px(f, [(far[0] + 1, far[1] - 1), (far[0] + 2, far[1] - 2), (far[0] + 3, far[1] - 2), (far[0] + 4, far[1] - 2), (far[0] + 5, far[1] - 1)], "stone_d")
        _px(f, [(x, 31) for x in range(19, 28)], "ink")
        P.stamp(f, [".o", "ow", "ow"], 19, 29, EYE_L)
        P.stamp(f, ["o.", "wo", "wo"], 26, 29, EYE_L)
    elif expr == "happy":
        for (x, y) in (near, far):
            P.stamp(f, [".ooo.", "o...o"], x, y + 2, EYE_L)
        P.stamp(f, [".ooooooooooo.", "ow.........wo", "ow.........wo", ".orrrrrrrrro.", "..orrpppprro.", "...ooooooo..."], 17, 27, EYE_L)
        _px(f, [(x, 28) for x in range(19, 28)] + [(x, 29) for x in range(19, 28)], "red_d")
        _px(f, [(near[0], near[1] - 1), (near[0] + 1, near[1] - 2), (near[0] + 2, near[1] - 2), (near[0] + 3, near[1] - 1)], "brown_d")
        _px(f, [(far[0] + 1, far[1] - 1), (far[0] + 2, far[1] - 2), (far[0] + 3, far[1] - 2), (far[0] + 4, far[1] - 1)], "stone_d")
    elif expr == "serious":
        # heavy brows, lids pressed down, the whole row of teeth bared
        for x in range(near[0], near[0] + 5):
            f.set(x, near[1], "ink")
            f.set(x, near[1] + 1, "ink")
        for x in range(far[0], far[0] + 5):
            f.set(x, far[1], "ink")
            f.set(x, far[1] + 1, "ink")
        _px(f, [(near[0] - 1, near[1] - 3), (near[0], near[1] - 2), (near[0] + 1, near[1] - 2), (near[0] + 2, near[1] - 1),
                (near[0] + 3, near[1] - 1), (near[0] + 4, near[1])], "brown_d")
        _px(f, [(far[0], far[1]), (far[0] + 1, far[1] - 1), (far[0] + 2, far[1] - 1), (far[0] + 3, far[1] - 2),
                (far[0] + 4, far[1] - 2), (far[0] + 5, far[1] - 3)], "stone_d")
        P.stamp(f, ["ooooooooooo", "owowowowowo", "ooooooooooo"], 18, 29, EYE_L)
    return f


# --------------------------------------------------------------------------
# Merlin 梅林 (drawn facing right, shown facing left): elderly Shih Tzu wizard
# --------------------------------------------------------------------------

SILK = ["stone_d", "stone", "stone_l", "white", "white"]
GOLDSILK = ["gold_d", "gold", "gold_l", "cream"]
HAT = ["night_d", "night", "water_d", "water", "sky"]


def merlin_base() -> tuple[Canvas, dict]:
    f = _layer()
    # robe
    robe = P.poly([(2, 48), (6, 39), (16, 35), (34, 35), (42, 39), (46, 48)])
    P.shade_shape(f, robe, HAT, centre=(24, 41), radius=(22, 10))
    for (x, y) in ((9, 44), (38, 42), (15, 47)):
        P.star4(f, x, y, "gold_l", 1, "yellow")
    # staff in front (right) with the glowing star
    _px(f, [(41, y) for y in range(14, 48)], "brown")
    _px(f, [(42, y) for y in range(14, 48)], "brown_d")
    _px(f, [(41, y) for y in range(16, 48, 5)], "gold_d")
    # long hanging ears (golden silk)
    for (cx, flip) in ((10, False), (35, True)):
        ear = P.poly([(cx - 4, 16), (cx + 3, 15), (cx + 5, 30), (cx + 3, 40), (cx - 1, 41), (cx - 5, 36), (cx - 6, 26)])
        P.shade_shape(f, ear, GOLDSILK, bias=0.02)
        for y in range(20, 40, 3):
            f.set(cx - 1 + (y % 2), y, "gold_d")
    # face
    head = P.ellipse(23, 24, 12, 10.5)
    P.shade_shape(f, head, SILK, bias=0.04)
    # long beard / mustache flowing down
    beard = P.poly([(13, 27), (20, 27), (24, 29), (29, 27), (34, 27), (33, 35), (29, 42), (25, 46), (22, 44),
                    (18, 40), (14, 34)])
    P.outline_shape(f, beard - head, "stone")
    P.shade_shape(f, beard, SILK, centre=(24, 32), radius=(11, 12), bias=0.06)
    for (x0, y0, x1, y1) in ((19, 31, 21, 40), (24, 32, 24, 43), (29, 31, 27, 39)):
        for (x, y) in P.thick_line(x0, y0, x1, y1, 0.4):
            if P.name_at(f, x, y) in ("white", "stone_l"):
                f.set(x, y, "stone_l" if P.name_at(f, x, y) == "white" else "stone")
    # little black nose on the flat muzzle
    P.stamp(f, [".oo.", "oooo", ".oo."], 22, 25, NOSE_L)
    f.set(23, 25, "steel_l")
    # hat: wide brim and a tall cone whose tip flops back
    cone = P.poly([(13, 15), (19, 6), (22, 2), (17, 1), (11, 3), (8, 1), (9, 5), (14, 3), (17, 4), (15, 9), (12, 14)])
    cone = P.poly([(12, 15), (16, 8), (19, 3), (13, 1), (6, 3), (4, 1), (4, 6), (9, 5), (14, 4), (13, 9), (9, 15)])
    cone = P.poly([(10, 15), (15, 6), (21, 1), (25, 2), (30, 9), (34, 15)])
    tip = P.poly([(21, 1), (16, 0), (10, 2), (6, 6), (8, 7), (12, 4), (17, 3), (22, 4)])
    P.shade_shape(f, cone | tip, HAT, centre=(22, 9), radius=(12, 9), bias=0.05)
    brim = P.ellipse(22, 15.5, 16, 3.2)
    P.outline_shape(f, brim, "night_d")
    P.shade_shape(f, brim, HAT, bias=0.1)
    _px(f, [(x, 13) for x in range(12, 33)], "gold")
    for (x, y) in ((22, 8), (16, 11), (28, 11)):
        P.star4(f, x, y, "yellow", 1, "white")
    P.glow_dot(f, 7, 5, "yellow", "gold_l", 0)
    f.outline_all("ink")
    # the staff's star glows (painted light outside the outline)
    for (x, y) in P.ellipse(41.5, 10.5, 6, 6):
        if f.get(x, y) is None:
            f.set(x, y, P.alpha_px("yellow", 70))
    star = P.poly([(41.5, 4), (43, 8.5), (47.5, 9), (44, 12), (45, 16.5), (41.5, 14), (38, 16.5), (39, 12),
                   (35.5, 9), (40, 8.5)])
    P.outline_shape(f, star, "gold_d")
    P.fill(f, star, "yellow")
    P.fill(f, P.ellipse(41.5, 10.5, 2, 2), "white")
    return f, {"eye_l": (15, 19), "eye_r": (27, 19), "mouth": (23, 29)}


GLASS = ["..ooo..", ".o...o.", "o.....o", "o.....o", "o.....o", ".o...o.", "..ooo.."]


def _glasses(f: Canvas, a: dict, dy: int = 0, tilt: int = 0) -> None:
    (lx, ly), (rx, ry) = a["eye_l"], a["eye_r"]
    for i, (x, y) in enumerate(((lx - 1, ly - 2 + dy), (rx - 1, ry - 2 + dy + tilt))):
        for gy, row in enumerate(GLASS):
            for gx, ch in enumerate(row):
                if ch == "o":
                    f.set(x + gx, y + gy, "gold_d")
        f.set(x + 1, y + 1, "white")
    _px(f, [(lx + 6, ly + 1 + dy), (lx + 7, ly + 1 + dy), (lx + 8, ly + 1 + dy + (1 if tilt else 0))], "gold_d")


def merlin(expr: str) -> Canvas:
    f, a = merlin_base()
    (lx, ly), (rx, ry) = a["eye_l"], a["eye_r"]
    mx, my = a["mouth"]
    brow = "white"
    if expr == "normal":
        for (x, y) in ((lx, ly), (rx, ry)):
            P.stamp(f, [".oo.", "owoo", "oooo", ".oo."], x + 1, y + 1, EYE_L)
        _glasses(f, a)
        _px(f, [(lx - 1, ly - 2), (lx, ly - 3), (lx + 1, ly - 3), (lx + 2, ly - 3), (lx + 3, ly - 3), (lx + 4, ly - 2)], brow)
        _px(f, [(rx, ry - 2), (rx + 1, ry - 3), (rx + 2, ry - 3), (rx + 3, ry - 3), (rx + 4, ry - 3), (rx + 5, ry - 2)], brow)
        _px(f, [(mx - 2, my), (mx - 1, my + 1), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my)], "stone_d")
    elif expr == "surprised":
        for (x, y) in ((lx, ly), (rx, ry)):
            P.stamp(f, [".ooo.", "owwoo", "owooo", "ooooo", ".ooo."], x, y, EYE_L)
        _glasses(f, a, dy=1, tilt=1)
        _px(f, [(lx - 1, ly - 4), (lx, ly - 5), (lx + 1, ly - 5), (lx + 2, ly - 5), (lx + 3, ly - 4)], brow)
        _px(f, [(rx + 1, ry - 4), (rx + 2, ry - 5), (rx + 3, ry - 5), (rx + 4, ry - 5), (rx + 5, ry - 4)], brow)
        P.stamp(f, [".oo.", "orro", "orro", ".oo."], mx - 2, my, EYE_L)
        P.stamp(f, ["..o.", ".oso", "osso", ".oo."], 37, 22, EYE_L)
    elif expr == "proud":
        for (x, y) in ((lx, ly), (rx, ry)):
            P.stamp(f, ["oooo", "....", ], x + 1, y + 2, EYE_L)
            P.stamp(f, [".oo."], x + 1, y + 1, EYE_L)
        _glasses(f, a)
        _px(f, [(lx - 1, ly - 3), (lx, ly - 4), (lx + 1, ly - 4), (lx + 2, ly - 4), (lx + 3, ly - 3), (lx + 4, ly - 3)], brow)
        _px(f, [(rx, ry - 3), (rx + 1, ry - 3), (rx + 2, ry - 4), (rx + 3, ry - 4), (rx + 4, ry - 4), (rx + 5, ry - 3)], brow)
        _px(f, [(mx - 3, my), (mx - 2, my + 1), (mx - 1, my + 2), (mx, my + 2), (mx + 1, my + 2), (mx + 2, my + 1), (mx + 3, my)], "stone_d")
        P.star4(f, 37, 24, "yellow", 2, "white")
    elif expr == "worried":
        for (x, y) in ((lx, ly), (rx, ry)):
            P.stamp(f, [".oo.", "owoo", ".oo."], x + 1, y + 2, EYE_L)
        _glasses(f, a)
        # brows rise toward the middle
        _px(f, [(lx - 1, ly - 1), (lx, ly - 1), (lx + 1, ly - 2), (lx + 2, ly - 2), (lx + 3, ly - 3), (lx + 4, ly - 4)], brow)
        _px(f, [(rx, ry - 4), (rx + 1, ry - 3), (rx + 2, ry - 2), (rx + 3, ry - 2), (rx + 4, ry - 1), (rx + 5, ry - 1)], brow)
        _px(f, [(mx - 3, my + 1), (mx - 2, my), (mx - 1, my + 1), (mx, my), (mx + 1, my + 1), (mx + 2, my), (mx + 3, my + 1)], "stone_d")
        P.stamp(f, ["..o.", ".oso", "osso", "owso", ".oo."], 36, 21, EYE_L)
    return f


# --------------------------------------------------------------------------
# Black Knight 黑騎士 (shown facing left): an empty great helm, violet light in the visor
# --------------------------------------------------------------------------

ARMOR = ["ink", "night_d", "iron", "steel_d", "steel"]
PLUME = ["plum", "dusk", "violet", "lilac"]


def black_knight(expr: str) -> Canvas:
    f = _layer()
    # plume flowing back (left)
    plume = P.poly([(22, 7), (14, 3), (6, 5), (1, 12), (3, 15), (8, 10), (14, 9), (11, 15), (18, 11), (24, 10)])
    P.shade_shape(f, plume, PLUME, bias=0.05)
    # shoulders
    for (cx, cy) in ((9, 44), (39, 44)):
        pad = P.ellipse(cx, cy, 11, 7)
        P.outline_shape(f, pad, "ink")
        P.shade_shape(f, pad, ARMOR, bias=-0.02)
    gorget = P.rect(14, 36, 20, 12)
    P.shade_shape(f, gorget, ARMOR, centre=(24, 40), radius=(12, 8), bias=-0.05)
    _px(f, [(x, 41) for x in range(15, 34)], "ink")
    # great helm
    helm = P.poly([(12, 38), (11, 16), (15, 9), (24, 6), (33, 9), (37, 16), (36, 38)])
    P.shade_shape(f, helm, ARMOR, centre=(21, 18), radius=(15, 19), bias=0.0)
    _px(f, [(24, y) for y in range(7, 37)], "steel_d")
    _px(f, [(23, y) for y in range(7, 37)], "steel")
    for (x, y) in ((14, 33), (34, 33), (14, 15), (34, 15)):
        f.set(x, y, "steel")
    for y in (28, 31, 34):
        for x in (28, 30, 32):
            f.set(x, y, "ink")
    f.outline_all("ink")
    # visor slit and the violet light of the magic inside (painted glow)
    for (x, y) in P.ellipse(24, 21.5, 14, 6):
        n = P.name_at(f, x, y)
        if n in ("iron", "steel_d", "night_d") and (x + y) % 2 == 0:
            f.set(x, y, {"iron": "dusk", "steel_d": "violet", "night_d": "plum"}[n])
    _px(f, [(x, 21) for x in range(12, 37)] + [(x, 22) for x in range(12, 37)], "ink")
    for (ex, ey) in ((18, 21), (29, 21)):
        _px(f, [(ex - 2, ey), (ex - 1, ey), (ex, ey), (ex + 1, ey), (ex + 2, ey), (ex - 1, ey + 1), (ex, ey + 1), (ex + 1, ey + 1)], "lilac")
        _px(f, [(ex - 1, ey), (ex, ey), (ex, ey + 1)], "white")
        _px(f, [(ex - 3, ey), (ex + 3, ey), (ex - 2, ey + 1), (ex + 2, ey + 1)], "violet")
    # magic wisps drifting off the plume
    for (x, y) in ((5, 19), (3, 24), (9, 22), (42, 6)):
        P.glow_dot(f, x, y, "lilac", "violet", 0)
    return f


# --------------------------------------------------------------------------
# Morgana 摩根娜 (shown facing left): only a purple fox silhouette against the moon,
# glowing eyes and a crescent staff
# --------------------------------------------------------------------------

def morgana_backdrop() -> Canvas:
    c = Canvas(S, S, P.rgba("night_d"))
    P.radial(c, 22, 18, 40, ["ink", "night_d", "plum", "dusk"], sharp=1.3)
    moon = P.ellipse(28, 20, 18, 18)
    for (x, y) in moon:
        d = math.hypot(x + 0.5 - 25, y + 0.5 - 16) / 21
        c.set(x, y, P.pick(["violet", "lilac", "lilac", "white"], 1.0 - d, x, y, 1.6))
    for (x, y) in P.edge(moon):
        c.set(x, y, "violet")
    rng = random.Random(9)
    for (x, y) in P.scatter(rng, 10, 0, 0, S, S):
        if (x, y) not in moon:
            c.set(x, y, "lilac")
    return c


def morgana(expr: str) -> Canvas:
    f = _layer()
    sil = set()
    # cloak with a high pointed collar
    sil |= P.poly([(0, 48), (4, 38), (11, 30), (15, 37), (24, 35), (33, 37), (37, 30), (44, 38), (48, 48)])
    # fox head: rounded skull, long pointed snout to the right, tall ears
    sil |= P.ellipse(22, 24, 9, 8)
    sil |= P.poly([(25, 20), (41, 27), (41, 28), (27, 31)])
    sil |= P.poly([(15, 20), (12, 5), (16, 8), (21, 17)])
    sil |= P.poly([(23, 17), (27, 4), (30, 8), (30, 19)])
    sil |= P.poly([(14, 25), (9, 31), (15, 30), (12, 35), (19, 31), (22, 34)])
    P.fill(f, sil, "plum")
    for (x, y) in sil:
        if y > 37 and (x + y) % 2 == 0:
            f.set(x, y, "night_d")
    # rim light from the moon behind (up-left)
    P.rim(f, sil, "dusk", (-1, -1))
    P.rim(f, sil, "violet", (-1, 0))
    # crescent staff
    _px(f, [(42, y) for y in range(15, 48)], "plum")
    _px(f, [(43, y) for y in range(15, 48)], "night_d")
    moon = P.ellipse(42, 10, 5, 5) - P.ellipse(44, 8, 4.2, 4.2)
    P.fill(f, moon, "lilac")
    P.rim(f, moon, "white", (-1, 0))
    f.outline_all("ink")
    # glowing narrowed eyes and the thin curve of a smile
    for (ex, ey) in ((20, 22), (28, 23)):
        _px(f, [(ex - 1, ey + 1), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1)], "white")
        _px(f, [(ex - 2, ey + 1), (ex - 1, ey), (ex + 2, ey), (ex + 3, ey + 1), (ex, ey - 1), (ex + 1, ey - 1)], "pink")
    _px(f, [(30, 29), (31, 30), (32, 30), (33, 30), (34, 29)], "violet")
    for (x, y) in ((46, 4), (46, 15), (37, 3)):
        P.glow_dot(f, x, y, "lilac", "violet", 0)
    return f


# --------------------------------------------------------------------------
# Scarecrow Captain 稻草人隊長 (shown facing left): sack face, captain hat with a purple feather
# --------------------------------------------------------------------------

SACK = ["stone_d", "stone", "stone_l", "white"]
STRAW = ["gold_d", "gold", "gold_l", "yellow"]
COAT = ["plum", "dusk", "violet", "lilac"]
HATB = ["brown_d", "brown", "gold_d"]


def scarecrow_captain(expr: str) -> Canvas:
    f = _layer()
    # pitchfork behind (right)
    _px(f, [(41, y) for y in range(10, 48)], "brown")
    _px(f, [(42, y) for y in range(10, 48)], "brown_d")
    for x in (37, 41, 45):
        _px(f, [(x, y) for y in range(2, 10)], "steel_l")
        _px(f, [(x + 1, y) for y in range(3, 10)], "steel")
    _px(f, [(x, 9) for x in range(37, 47)], "steel_d")
    # coat with gold buttons and an epaulette
    coat = P.poly([(3, 48), (7, 38), (16, 34), (32, 34), (40, 38), (44, 48)])
    P.shade_shape(f, coat, COAT, centre=(23, 40), radius=(21, 10))
    for y in (39, 43, 47):
        _px(f, [(24, y)], "yellow")
    epaulette = P.ellipse(10, 38, 6, 3)
    P.fill(f, epaulette, "gold")
    _px(f, [(x, 40) for x in range(5, 16, 2)], "gold_l")
    # straw poking out of the collar and sleeves
    for (x0, y0, x1, y1) in ((15, 35, 12, 31), (18, 34, 17, 30), (29, 34, 31, 30), (33, 35, 36, 31)):
        for (x, y) in P.thick_line(x0, y0, x1, y1, 0.5):
            f.set(x, y, "gold_l")
    # sack head
    head = P.ellipse(24, 23, 12, 11)
    P.shade_shape(f, head, SACK, bias=0.02)
    for (x, y) in head:   # burlap weave
        if (x * 3 + y * 5) % 11 == 0 and P.name_at(f, x, y) in ("stone_l", "white"):
            f.set(x, y, "stone")
    # stitched neck
    _px(f, [(x, 33) for x in range(17, 31) if x % 2 == 0], "brown_d")
    # straw sticking out at the sides of the head
    for (x0, y0, x1, y1) in ((13, 18, 8, 16), (13, 21, 7, 21), (35, 18, 40, 16), (35, 21, 41, 21), (14, 15, 10, 12)):
        for (px, py) in P.thick_line(x0, y0, x1, y1, 0.5):
            f.set(px, py, "gold_l" if (px + py) % 3 else "gold")
    # captain's bicorne seen from the front: raised horns at both ends, gold piping on top
    hat = P.poly([(3, 6), (10, 9), (16, 5), (24, 3), (32, 5), (38, 9), (45, 6), (42, 13), (24, 15), (6, 13)])
    P.shade_shape(f, hat, ["ink", "brown_d", "brown", "gold_d"], centre=(24, 8), radius=(20, 6), bias=0.0)
    _px(f, [(x, y) for (x, y) in P.edge(hat) if y <= 10], "gold")
    _px(f, [(x, y + 1) for (x, y) in P.edge(hat) if y <= 9 and (x, y + 1) in hat and x % 2 == 0], "gold_d")
    cockade = P.ellipse(24, 9, 2.6, 2.6)
    P.fill(f, cockade, "violet")
    P.fill(f, P.edge(cockade), "plum")
    f.set(24, 9, "yellow")
    # the purple feather (Morgana's mark), tall and curling back
    feather = P.poly([(23, 9), (24, 4), (28, 0), (37, 0), (41, 2), (35, 3), (30, 5), (27, 9)])
    P.outline_shape(f, feather, "plum")
    P.shade_shape(f, feather, COAT, bias=0.15)
    _px(f, [(25, 8), (26, 5), (28, 3), (31, 2), (34, 1), (37, 1)], "plum")
    _px(f, [(29, 4), (32, 3), (35, 2)], "violet")
    f.outline_all("ink")
    # angry face: slanted stitched brows, button eyes, zig-zag stitched mouth
    _px(f, [(15, 18), (16, 18), (17, 19), (18, 19), (19, 20), (20, 20)], "ink")
    _px(f, [(27, 20), (28, 20), (29, 19), (30, 19), (31, 18), (32, 18)], "ink")
    P.stamp(f, [".oo.", "oooo", "oooo", ".oo."], 16, 21, EYE_L)
    P.stamp(f, [".oo.", "oooo", "oooo", ".oo."], 28, 21, EYE_L)
    _px(f, [(17, 22), (29, 22)], "violet")
    _px(f, [(16, 28), (17, 29), (18, 28), (19, 29), (20, 28), (21, 29), (22, 28), (23, 29), (24, 28), (25, 29),
            (26, 28), (27, 29), (28, 28), (29, 29), (30, 28), (31, 29)], "ink")
    _px(f, [(18, 30), (22, 30), (26, 30), (30, 30), (20, 27), (24, 27), (28, 27)], "brown_d")
    _px(f, [(14, 26), (33, 26)], "rose")
    # angry puff marks
    P.stamp(f, ["r.r", ".r.", "r.r"], 4, 18, {"r": "red"})
    return f


# --------------------------------------------------------------------------
# Crow 烏鴉 (shown facing left): a noisy little spy, beak wide open
# --------------------------------------------------------------------------

FEATHER = ["ink", "plum", "dusk", "violet", "lilac"]


def crow(expr: str) -> Canvas:
    f = _layer()
    body = P.ellipse(18, 40, 15, 10)
    head = P.ellipse(24, 23, 10, 9.5)
    crest = P.poly([(15, 20), (9, 16), (15, 17), (12, 12), (18, 15)])
    P.shade_shape(f, body, FEATHER, bias=-0.08)
    P.shade_shape(f, head | crest, FEATHER, centre=(24, 23), radius=(10, 11), bias=0.0)
    wing = P.poly([(2, 36), (14, 31), (26, 36), (22, 44), (14, 48), (4, 48)])
    P.outline_shape(f, wing, "plum")
    P.shade_shape(f, wing, FEATHER, bias=-0.12)
    for (x0, y0, x1, y1) in ((5, 41, 20, 37), (7, 45, 20, 41)):
        for (x, y) in P.thick_line(x0, y0, x1, y1, 0.4):
            f.set(x, y, "plum")
    # sharp beak, wide open ("嘎——!")
    upper = P.poly([(30, 18), (37, 18), (42, 20), (46, 24), (41, 23), (30, 25)])
    lower = P.poly([(30, 27), (37, 28), (42, 31), (36, 31), (30, 30)])
    P.shade_shape(f, upper, ["iron", "steel_d", "steel"], bias=0.1)
    P.fill(f, lower, "iron")
    P.fill(f, P.poly([(30, 25), (41, 24), (40, 26), (30, 27)]), "red")
    _px(f, [(32, 19), (34, 19), (36, 19)], "steel_l")
    f.outline_all("ink")
    # big beady eye with a mischievous brow
    P.stamp(f, [".ooo.", "owwoo", "owooo", "ooooo", ".ooo."], 22, 19, EYE_L)
    _px(f, [(21, 17), (22, 17), (23, 17), (24, 16), (25, 16), (26, 16), (27, 17)], "ink")
    # motion lines of the caw
    for (x0, y0, x1, y1) in ((41, 13, 45, 10), (44, 18, 47, 17), (42, 35, 46, 38)):
        for (x, y) in P.thick_line(x0, y0, x1, y1, 0.4):
            f.set(x, y, "white")
    return f


# --------------------------------------------------------------------------
# assembly
# --------------------------------------------------------------------------

BUILDERS = {
    "goldie": goldie,
    "bulldog": bulldog,
    "merlin": merlin,
    "black_knight": black_knight,
    "morgana": morgana,
    "scarecrow_captain": scarecrow_captain,
    "crow": crow,
}


def portrait(speaker: str, expr: str) -> Canvas:
    c = backdrop(speaker)
    fig = BUILDERS[speaker](expr)
    c.blit(fig, 0, 0)
    P.quantize(c)
    return c.flipped() if speaker in FACES_LEFT else c


def write_all() -> list[str]:
    out = []
    for speaker, exprs in PORTRAITS.items():
        if speaker not in BUILDERS:
            continue
        for expr in exprs:
            p = res_path("res://assets/portraits/%s/%s.png" % (speaker, expr))
            portrait(speaker, expr).save(p, opaque=True)
            out.append(p)
    return out


if __name__ == "__main__":
    import sys
    from pixel import contact_sheet
    out_dir = sys.argv[1]
    rows = []
    for speaker, exprs in PORTRAITS.items():
        if speaker in BUILDERS:
            rows.append([portrait(speaker, e) for e in exprs])
    contact_sheet(rows, 5).save(out_dir + "/portraits.png")
    print("ok")
