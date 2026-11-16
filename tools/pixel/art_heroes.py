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
    ".SwSSSs.",
    "SwSSSSsz",
    "SSSYSSsz",
    "nnnYnnnn",
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


def _edit(grid: list[str], edits: list[tuple[int, int, str]]) -> list[str]:
    rows = [list(r) for r in grid]
    for x, y, ch in edits:
        rows[y][x] = ch
    return ["".join(r) for r in rows]


# eyes closed (blink): only the middle row of each eye stays dark
G_HEAD_BLINK = _edit(G_HEAD, [(6, 4, "g"), (7, 4, "g"), (11, 4, "g"), (6, 6, "g"), (7, 6, "g"), (11, 6, "g")])
# happy: closed smiling eyes and an open mouth with a little tongue
G_HEAD_HAPPY = _edit(G_HEAD_BLINK, [(6, 5, "o"), (7, 5, "o"), (5, 4, "g"), (12, 8, "o"), (13, 8, "o"),
                                    (12, 9, "o"), (13, 9, "p")])
# ears flopped up a little (run bounce): move the dark ear tips one row up
G_HEAD_EAR_UP = _edit(G_HEAD, [(0, 3, "b"), (2, 9, "."), (3, 9, ".")])

G_CAPE_RUN.append([
    "......R",
    "....rRR",
    "..rRRRR",
    ".rRRRRR",
    "rRRRRRr",
    "rRRRRr.",
    ".rRr...",
])

SPARK = ["..Y..", ".YwY.", "..Y.."]


def goldie_v2() -> list[Anim]:
    """More frames (CP1): idle 4 (breath, tail wag, blink), run 6, attack 4 (wind-up, swing,
    follow-through, recover), hurt 2, sleep 2 (Zzz drifting) and a victory cheer."""
    idle = [
        goldie_pose(0),
        goldie_pose(0, tail=G_TAIL_UP),
        goldie_pose(1),
        goldie_pose(1, tail=G_TAIL_UP, head=G_HEAD_BLINK),
    ]
    run_sword = ((17, 15), (1, -1), 7)
    legs = [((7, 18), (14, 19)), ((8, 19), (13, 18)), ((10, 19), (11, 19)),
            ((14, 19), (7, 18)), ((13, 18), (8, 19)), ((11, 19), (10, 19))]
    bobs = [0, -1, -1, 0, -1, -1]
    run = []
    for i in range(6):
        far, near = legs[i]
        run.append(goldie_pose(bobs[i], lean=1 if i % 3 == 1 else 0,
                               head=G_HEAD_EAR_UP if bobs[i] < 0 else G_HEAD,
                               legs=[(far, G_LEG_FAR), (near, G_LEG_NEAR)], cape=G_CAPE_RUN[i % 3],
                               tail=G_TAIL_UP if i % 2 else G_TAIL, sword=run_sword))
    attack = [
        goldie_pose(1, lean=-1, sword=((19, 12), (0, -1), 9), arm=(17, 12)),
        goldie_pose(0, lean=1, sword=((17, 14), (1, 0), 7), arm=(15, 13)),
        goldie_pose(0, lean=1, sword=((16, 16), (1, 1), 6), arm=(15, 15)),
        goldie_pose(0, lean=0, sword=((17, 15), (1, -1), 7), arm=(15, 14)),
    ]
    hurt = [
        goldie_pose(1, head=G_HEAD_HURT, lean=-1, extras=[(STAR, 0, 1)]),
        goldie_pose(0, head=G_HEAD_HURT, lean=-1, extras=[(STAR, 0, 0), (STAR, 17, 1)]),
    ]
    victory = [
        goldie_pose(1, head=G_HEAD_HAPPY, tail=G_TAIL_UP),
        goldie_pose(-2, head=G_HEAD_HAPPY, sword=((20, 10), (0, -1), 8), arm=(18, 10), tail=G_TAIL_UP,
                    legs=[((8, 18), G_LEG_FAR), ((13, 18), G_LEG_NEAR)], extras=[(SPARK, 18, 0)]),
        goldie_pose(-1, head=G_HEAD_HAPPY, sword=((20, 10), (0, -1), 8), arm=(18, 10), tail=G_TAIL,
                    extras=[(SPARK, 19, 1)]),
        goldie_pose(0, head=G_HEAD_HAPPY, tail=G_TAIL_UP),
    ]
    return [
        Anim("idle", idle, 8.0, True, [4.0, 4.0, 4.0, 1.0]),
        Anim("run", run, 14.0, True),
        Anim("attack", attack, 14.0, False, [0.5, 1.0, 1.0, 1.5]),
        Anim("hurt", hurt, 6.0, False, [1.0, 3.0]),
        Anim("sleep", [goldie_sleep(0), goldie_sleep(1)], 1.5, True),
        Anim("victory", victory, 8.0, True, [1.0, 1.5, 1.5, 1.0]),
    ]


# --------------------------------------------------------------------------
# Bulldog (貝德維爾的英國鬥牛犬)
# --------------------------------------------------------------------------

def _bulldog_head(eyes: str = "open", mouth: str = "w") -> list[str]:
    """A friendly, nearly frontal bulldog face (16x12): brown patch over one eye, round eyes with
    highlights, a button nose, a little 'w' mouth and pink cheeks; jowls shaded at the bottom."""
    w, h = 16, 12
    g = [["." for _ in range(w)] for _ in range(h)]
    for y in range(h):
        for x in range(w):
            cx, cy = (x + 0.5 - 7.5) / 7.6, (y + 0.5 - 6.3) / 5.9
            if cx * cx * 0.9 + cy * cy * 1.1 <= 1.0 or (1 <= y <= 9 and 0 <= x <= 14):
                g[y][x] = "w"
    for y in range(h):
        for x in range(w):
            if g[y][x] == "w" and ((x - 2.2) ** 2 / 9.0 + (y - 3.6) ** 2 / 7.0 <= 1.0):
                g[y][x] = "B"
            if g[y][x] == "w" and (y >= 10 or (y >= 8 and (x <= 1 or x >= 13))):
                g[y][x] = "l"
    for (x, y) in ((1, 0), (2, 0), (11, 0), (12, 0)):
        g[y][x] = "n"
    for (x, y) in ((0, 1), (1, 1), (2, 1), (3, 1), (11, 1), (12, 1), (13, 1), (12, 2), (13, 2), (14, 1)):
        g[y][x] = "B" if (x, y) not in ((0, 1), (3, 1), (14, 1)) else "n"
    g[0][0] = "."
    g[0][3] = "."
    if eyes == "open":
        for (x, y, ch) in ((2, 4, "w"), (3, 4, "o"), (2, 5, "o"), (3, 5, "o"),
                           (10, 4, "w"), (11, 4, "o"), (10, 5, "o"), (11, 5, "o")):
            g[y][x] = ch
    elif eyes == "closed":
        for (x, y) in ((2, 5), (3, 5), (10, 5), (11, 5)):
            g[y][x] = "o"
    elif eyes == "happy":
        for (x, y) in ((2, 5), (3, 4), (4, 5), (10, 5), (11, 4), (12, 5)):
            g[y][x] = "o"
    elif eyes == "dizzy":
        for (x, y) in ((2, 4), (4, 4), (3, 5), (2, 6), (4, 6), (10, 4), (12, 4), (11, 5), (10, 6), (12, 6)):
            g[y][x] = "o"
    for (x, y, ch) in ((6, 6, "i"), (7, 6, "o"), (8, 6, "o"), (7, 7, "o")):
        g[y][x] = ch
    if mouth == "w":
        g[8][6] = "o"
        g[8][8] = "o"
    elif mouth == "open":
        for (x, y, ch) in ((6, 8, "o"), (7, 8, "o"), (8, 8, "o"), (6, 9, "o"), (7, 9, "p"), (8, 9, "o")):
            g[y][x] = ch
    elif mouth == "oh":
        for (x, y) in ((7, 8), (6, 9), (8, 9), (7, 10)):
            g[y][x] = "o"
    for (x, y) in ((4, 7), (11, 7)):
        g[y][x] = "p"
    return ["".join(r) for r in g]


B_HEAD = _bulldog_head()
B_HEAD_HURT = _bulldog_head("dizzy", "oh")

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


B_HEAD_BLINK = _bulldog_head("closed")
B_HEAD_HAPPY = _bulldog_head("happy", "open")
BARK_BUBBLE = ["wwww", "wRRw", "wwww", ".w.."]


def bulldog_v2() -> list[Anim]:
    """More frames (CP1): idle 4 (breath, blink), run 6 (a bouncy waddle), attack 4 (shield bash),
    hurt 2, guard 2 and a victory hop with the shield held high."""
    idle = [bulldog_pose(0), bulldog_pose(0), bulldog_pose(1), bulldog_pose(1, head=B_HEAD_BLINK)]
    legs = [((5, 19), (12, 20)), ((6, 20), (11, 19)), ((8, 20), (9, 20)),
            ((12, 20), (5, 19)), ((11, 19), (6, 20)), ((9, 20), (8, 20))]
    bobs = [0, -1, -2, 0, -1, -2]
    run = [bulldog_pose(bobs[i], legs=[(legs[i][0], B_LEG_FAR), (legs[i][1], B_LEG_NEAR)],
                        shield=(13, 12 + (1 if bobs[i] == -2 else 0))) for i in range(6)]
    attack = [
        bulldog_pose(0, lean=-1, shield=(11, 13)),
        bulldog_pose(0, lean=1, shield=(14, 11)),
        bulldog_pose(0, lean=1, shield=(14, 12)),
        bulldog_pose(0, lean=0, shield=(13, 12)),
    ]
    hurt = [
        bulldog_pose(1, head=B_HEAD_HURT, lean=-1, extras=[(STAR, 0, 1)]),
        bulldog_pose(0, head=B_HEAD_HURT, lean=-1, extras=[(STAR, 0, 0), (STAR, 15, 0)]),
    ]
    guard = [
        bulldog_pose(0, crouch=1, shield=(13, 7), shield_grid=B_SHIELD),
        bulldog_pose(0, crouch=1, shield=(13, 7), shield_grid=B_SHIELD_SHINE),
    ]
    victory = [
        bulldog_pose(1, head=B_HEAD_HAPPY, shield=(13, 12)),
        bulldog_pose(-2, head=B_HEAD_HAPPY, shield=(13, 4), legs=[((6, 19), B_LEG_FAR), ((11, 19), B_LEG_NEAR)]),
        bulldog_pose(-1, head=B_HEAD_HAPPY, shield=(13, 5)),
        bulldog_pose(0, head=B_HEAD_HAPPY, shield=(13, 12)),
    ]
    return [
        Anim("idle", idle, 6.0, True, [3.0, 3.0, 3.0, 1.0]),
        Anim("run", run, 14.0, True),
        Anim("attack", attack, 12.0, False, [1.0, 1.0, 1.2, 1.0]),
        Anim("hurt", hurt, 6.0, False, [1.0, 3.0]),
        Anim("guard", guard, 4.0, True),
        Anim("victory", victory, 8.0, True, [1.0, 1.5, 1.5, 1.0]),
    ]
