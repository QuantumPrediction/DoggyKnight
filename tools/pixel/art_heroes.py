"""Goldie (金毛) and the bulldog companion (C2, C3). All frames face right.

Each character is assembled from small hand-drawn part grids (head, body, legs,
cape...) stamped in back-to-front order; every part gets its own 1 px outline so
overlapping parts stay readable at 1x. Body centre stays at about (12, 13).
"""

from __future__ import annotations

from pixel import Anim, Canvas

W = 24

# Grid letters -> palette names (shared by both dogs).
L = {
    "o": "ink", "G": "gold", "g": "gold_l", "c": "cream", "b": "gold_d", "B": "brown",
    "n": "brown_d", "w": "white", "p": "pink", "R": "red", "r": "red_d", "S": "steel_l",
    "s": "steel", "z": "steel_d", "Y": "yellow", "u": "sky", "U": "water", "D": "water_d",
    "i": "iron", "l": "stone_l",
}

# --------------------------------------------------------------------------
# Goldie
# --------------------------------------------------------------------------

G_HEAD = [
    ".....gggggg......",
    "...ggcggggggg....",
    "..gcggggggggggg..",
    ".bgggggggggggggg.",
    "bBbgggwogggwgggg.",
    "bBbgggoogggogccc.",
    "bBbbggoogggocccoo",
    ".bBbGpggggcccccoo",
    ".bBbGGgggccccocc.",
    "..bb.GGgcccccpc..",
    "......GGgccccc...",
]

G_HEAD_HURT = [
    ".....gggggg......",
    "...ggcggggggg....",
    "..gcggggggggggg..",
    ".bgggggggggggggg.",
    "bBbggoggggogggggg",
    "bBbgggogggogcccc.",
    "bBbbggoggggocccoo",
    ".bBbGpggggcccccoo",
    ".bBbGGgggcccooc..",
    "..bb.GGgcccoooc..",
    "......GGgccccc...",
]

G_HEAD_SLEEP = [
    ".....gggggg......",
    "...ggcggggggg....",
    "..gcggggggggggg..",
    ".bgggggggggggggg.",
    "bBbggggggggggggg.",
    "bBbggooggggooccc.",
    "bBbbggggggggcccoo",
    ".bBbGpggggcccccoo",
    ".bBbGGgggccccocc.",
    "..bb.GGgcccccccc.",
    "......GGgccccc...",
]

G_BODY = [
    "..cccc..",
    ".SSSSSs.",
    "SSSSSSsz",
    "SSSYSSsz",
    "sSSSSszz",
    ".zzzzzz.",
]

G_CAPE = [
    "....rR",
    "...rRR",
    "..rRRR",
    ".rRRRR",
    "rRRRRR",
    "rRRRRr",
    "rRRRR.",
    "rRRRr.",
    ".rRr..",
]

G_CAPE_RUN = [
    [
        ".....rR",
        "...rRRR",
        ".rRRRRR",
        "rRRRRRR",
        "rRRRRRr",
        ".rRRRr.",
        "..rRr..",
    ],
    [
        ".....rR",
        "....rRR",
        "..rRRRR",
        "rRRRRRR",
        "rRRRRRr",
        "rRRRr..",
        ".rr....",
    ],
]

G_LEG_NEAR = ["gG", "GG", "cc"]
G_LEG_FAR = ["Gb", "bb", "cG"]
G_TAIL = ["..gg", ".gGG", "gGG."]
G_TAIL_UP = ["...g", "..gG", ".gG.", "gG.."]
G_ARM = ["gG", "Gb"]

G_SLEEP_BODY = [
    "....rRRRRRR..",
    "..rRRRRRRRRR.",
    ".rRRRRRRRRRRr",
    "GGgggggggggGG",
    "GGGGgggggGGGb",
    ".cc......cc..",
]

STAR = ["..Y..", ".YwY.", "..Y.."]
Z_SMALL = ["ooo", ".o.", "ooo"]
Z_BIG = ["oooo", "..o.", ".o..", "oooo"]


def draw_sword(c: Canvas, hx: int, hy: int, d: tuple[int, int], length: int) -> None:
    """Longsword with its crossguard at (hx, hy), blade pointing along d (8 directions)."""
    dx, dy = d
    px, py = -dy, dx
    for i in range(1, length + 1):
        x, y = hx + dx * i, hy + dy * i
        c.set(x, y, "steel_l")
        if i < length:
            if dx != 0 and dy != 0:
                c.set(x + dx, y, "steel")
            elif dx == 0:
                c.set(x + 1, y, "steel")
            else:
                c.set(x, y + 1, "steel")
    c.set(hx, hy, "gold_d")
    c.set(hx + px, hy + py, "yellow")
    c.set(hx - px, hy - py, "yellow")
    c.set(hx - dx, hy - dy, "brown_d")
    c.set(hx - 2 * dx, hy - 2 * dy, "yellow")


def sword_layer(hx: int, hy: int, d: tuple[int, int], length: int) -> Canvas:
    s = Canvas(W, W)
    draw_sword(s, hx, hy, d, length)
    s.outline_all()
    return s


def goldie_pose(bob: int = 0, head: list[str] = G_HEAD, sword=((17, 14), (1, -1), 8), arm=(15, 14),
                lean: int = 0, legs=None, cape=None, tail=None, sword_behind: bool = False,
                extras=()) -> Canvas:
    c = Canvas(W, W)
    if cape is None:
        c.stamp(G_CAPE, 2 + lean, 11 + bob, L)
    else:
        c.stamp(cape, 1 + lean, 12 + bob, L)
    c.stamp(tail or G_TAIL, 2 + lean, 16 + bob, L)
    if legs is None:
        legs = [((8, 19), G_LEG_FAR), ((13, 19), G_LEG_NEAR)]
    for (lx, ly), leg in legs:
        c.stamp(leg, lx, ly, L)
    if sword is not None and sword_behind:
        c.blit(sword_layer(sword[0][0] + lean, sword[0][1] + bob, sword[1], sword[2]), 0, 0)
    c.stamp(G_BODY, 7 + lean, 12 + bob, L)
    c.stamp(head, 3 + lean, 1 + bob, L)
    if sword is not None and not sword_behind:
        c.blit(sword_layer(sword[0][0] + lean, sword[0][1] + bob, sword[1], sword[2]), 0, 0)
    c.stamp(G_ARM, arm[0] + lean, arm[1] + bob, L)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


def goldie_sleep(z: int) -> Canvas:
    c = Canvas(W, W)
    c.stamp(G_TAIL, 1, 15, L)
    c.stamp(G_SLEEP_BODY, 2, 16, L)
    c.stamp(G_HEAD_SLEEP, 7, 11, L)
    c.stamp(["cc", "cc"], 19, 20, L)
    if z == 0:
        c.stamp(Z_SMALL, 19, 6, L, outline=None)
    else:
        c.stamp(Z_BIG, 19, 2, L, outline=None)
        c.stamp(Z_SMALL, 15, 6, L, outline=None)
    return c


def goldie() -> list[Anim]:
    run_sword = ((17, 15), (1, -1), 7)
    run = [
        goldie_pose(0, legs=[((7, 18), G_LEG_FAR), ((14, 19), G_LEG_NEAR)], cape=G_CAPE_RUN[0], sword=run_sword),
        goldie_pose(-1, legs=[((9, 19), G_LEG_FAR), ((11, 18), G_LEG_NEAR)], cape=G_CAPE_RUN[1], sword=run_sword),
        goldie_pose(0, legs=[((14, 19), G_LEG_FAR), ((7, 18), G_LEG_NEAR)], cape=G_CAPE_RUN[0], sword=run_sword),
        goldie_pose(-1, legs=[((11, 18), G_LEG_FAR), ((9, 19), G_LEG_NEAR)], cape=G_CAPE_RUN[1], sword=run_sword),
    ]
    attack = [
        goldie_pose(0, lean=-1, sword=((19, 13), (0, -1), 8), arm=(17, 13)),
        goldie_pose(0, lean=1, sword=((16, 15), (1, 0), 6), arm=(15, 14)),
        goldie_pose(1, lean=1, sword=((16, 16), (1, 1), 5), arm=(15, 15)),
    ]
    return [
        Anim("idle", [goldie_pose(0), goldie_pose(1, tail=G_TAIL_UP)], 3.0, True),
        Anim("run", run, 10.0, True),
        Anim("attack", attack, 12.0, False, [1.0, 1.0, 1.5]),
        Anim("hurt", [goldie_pose(0, head=G_HEAD_HURT, lean=-1, extras=[(STAR, 0, 0), (STAR, 17, 1)])], 1.0, False),
        Anim("sleep", [goldie_sleep(0), goldie_sleep(1)], 1.5, True),
    ]


# --------------------------------------------------------------------------
# Bulldog (貝德維爾的英國鬥牛犬)
# --------------------------------------------------------------------------

B_HEAD = [
    ".nn........nn...",
    "nBBnwwwwwwwnBBn.",
    "nBBBwwwwwwwwwBn.",
    "BBBBwwwwwwwwwwww",
    "BBwoBwwwwwwowwww",
    "BBooBwwwwwoowwww",
    "wBBBwwwwwwwwoool",
    "lwwwwwwwwwwwoool",
    "lwwwwwwooowwwwwl",
    "llwwwwowwwowwwl.",
    ".llwwwwwwwwwwll.",
    "...llllllllll...",
]

B_HEAD_HURT = [
    ".nn........nn...",
    "nBBnwwwwwwwnBBn.",
    "nBBBwwwwwwwwwBn.",
    "BBBBwwwwwwwwwwww",
    "BoBoBwwwwowowwww",
    "BBoBBwwwwwowwwww",
    "BoBoBwwwwowooool",
    "lwwwwwwwwwwwoool",
    "lwwwwwwwoowwwwwl",
    "llwwwwwwoowwwwl.",
    ".llwwwwwwwwwwll.",
    "...llllllllll...",
]

B_BODY = [
    "..wwwwwww.",
    ".UuuuuuuUD",
    "UuuuYuuuUD",
    "UuuYYYuuUD",
    "UUuuYuuUDD",
    "nnnnYnnnnn",
    ".DDDDDDDD.",
]

B_SHIELD = [
    "..zzzzz..",
    ".zSSSSSz.",
    "zSsUUUsSz",
    "zSUUYUUsz",
    "zSUYYYUsz",
    "zSUUYUUsz",
    "zSsUUUssz",
    ".zssssiz.",
    "..zzzzz..",
]

B_SHIELD_SHINE = [
    "..zzzzz..",
    ".zSSwSSz.",
    "zSsUwUsSz",
    "zSUUYUUsz",
    "zSUYYYUsz",
    "zSUUYUUsz",
    "zSsUUUssz",
    ".zssssiz.",
    "..zzzzz..",
]

B_LEG_NEAR = ["ww", "ww", "ll"]
B_LEG_FAR = ["Bl", "ll", "lB"]
B_TAIL = ["ww", "lw"]
B_ARM = ["ww", "wl"]


def bulldog_pose(bob: int = 0, head: list[str] = B_HEAD, shield=(13, 12), shield_grid=None,
                 lean: int = 0, legs=None, extras=(), crouch: int = 0) -> Canvas:
    c = Canvas(W, W)
    c.stamp(B_TAIL, 2 + lean, 15 + bob + crouch, L)
    if legs is None:
        legs = [((6, 20), B_LEG_FAR), ((11, 20), B_LEG_NEAR)]
    for (lx, ly), leg in legs:
        c.stamp(leg, lx, ly, L)
    c.stamp(B_BODY, 3 + lean, 13 + bob + crouch, L)
    c.stamp(head, 1 + lean, 2 + bob + crouch, L)
    if shield is not None:
        c.stamp(shield_grid or B_SHIELD, shield[0] + lean, shield[1] + bob + crouch, L)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


def bulldog() -> list[Anim]:
    run = [
        bulldog_pose(0, legs=[((5, 19), B_LEG_FAR), ((12, 20), B_LEG_NEAR)]),
        bulldog_pose(-1, legs=[((7, 20), B_LEG_FAR), ((10, 19), B_LEG_NEAR)]),
        bulldog_pose(0, legs=[((12, 20), B_LEG_FAR), ((5, 19), B_LEG_NEAR)]),
        bulldog_pose(-1, legs=[((10, 19), B_LEG_FAR), ((7, 20), B_LEG_NEAR)]),
    ]
    attack = [
        bulldog_pose(0, lean=-1, shield=(12, 13)),
        bulldog_pose(0, lean=1, shield=(13, 11)),
        bulldog_pose(0, lean=0, shield=(13, 12)),
    ]
    guard = [
        bulldog_pose(0, crouch=1, shield=(13, 7), shield_grid=B_SHIELD),
        bulldog_pose(0, crouch=1, shield=(13, 7), shield_grid=B_SHIELD_SHINE),
    ]
    return [
        Anim("idle", [bulldog_pose(0), bulldog_pose(1)], 3.0, True),
        Anim("run", run, 9.0, True),
        Anim("attack", attack, 10.0, False, [1.0, 1.5, 1.0]),
        Anim("hurt", [bulldog_pose(0, head=B_HEAD_HURT, lean=-1, extras=[(STAR, 0, 0), (STAR, 15, 0)])], 1.0, False),
        Anim("guard", guard, 4.0, True),
    ]
