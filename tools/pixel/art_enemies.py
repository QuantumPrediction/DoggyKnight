"""Scarecrow soldier (24x24), crow scout (16x16) and the black knight (48x48). C4, C5.

Enemies use cool purples / iron so they never get mistaken for the warm-coloured dogs.
All frames face right.
"""

from __future__ import annotations

from palette import rgba
from pixel import Anim, Canvas

_RGB = {n: rgba(n)[:3] for n in ("white", "lilac", "steel_d", "iron")}

L = {
    "o": "ink", "P": "plum", "v": "violet", "V": "lilac", "w": "white", "c": "cream",
    "y": "yellow", "g": "gold_l", "G": "gold", "b": "gold_d", "B": "brown", "n": "brown_d",
    "l": "stone_l", "t": "stone", "T": "stone_d", "S": "steel_l", "s": "steel", "z": "steel_d",
    "i": "iron", "O": "orange", "R": "red", "r": "red_d", "p": "pink",
}

STAR = ["..y..", ".ywy.", "..y.."]

# --------------------------------------------------------------------------
# Scarecrow soldier 稻草人兵
# --------------------------------------------------------------------------

S_HAT = [
    "....nBBBn....",
    "...nBBBBBn...",
    "...nvvvvvn...",
    ".nBBBBBBBBBn.",
    "nBBbBBBBBbBBn",
]

S_HEAD = [
    ".llllllll.",
    "llllllllll",
    "llllolllol",
    "llllolllol",
    "lllpllllpl",
    "tlllolllol",
    "ttlllooolt",
    ".tttttttt.",
]

S_HEAD_HURT = [
    ".llllllll.",
    "llllllllll",
    "llolollolo",
    "lllollloll",
    "llolollolo",
    "tlllllllll",
    "tlllooollt",
    ".tttttttt.",
]

S_BODY = [
    "gy.....yg",
    ".yvvvvvy.",
    ".vVvvgPv.",
    ".vVvvPPP.",
    ".bnbbnbb.",
    ".vvvvvPP.",
    "gvPvvPPPg",
    "y.y.y.y.y",
]

S_ARMS = [
    "gy.........yg",
    "ynnnnnnnnnnny",
    "gy.........yg",
]

S_POLE = ["nB", "nB", "nB", "gy"]


def spear_layer(x0: int, y0: int, length: int, tip_dx: int = 1) -> Canvas:
    """Horizontal-ish stick spear held at (x0, y0) pointing right."""
    s = Canvas(24, 24)
    for i in range(length):
        s.set(x0 + i * tip_dx, y0, "brown")
    tx = x0 + length * tip_dx
    s.set(tx, y0, "stone_l")
    s.set(tx + tip_dx, y0, "stone_l")
    s.set(tx, y0 - 1, "stone")
    s.set(tx, y0 + 1, "stone")
    s.set(x0 + 2, y0 - 1, "gold_l")   # straw binding
    s.outline_all()
    return s


def diag_spear_layer(x0: int, y0: int, length: int) -> Canvas:
    s = Canvas(24, 24)
    for i in range(length):
        s.set(x0 + i, y0 - i, "brown")
    tx, ty = x0 + length, y0 - length
    s.set(tx, ty, "stone_l")
    s.set(tx + 1, ty - 1, "stone_l")
    s.set(tx + 1, ty, "stone")
    s.set(tx, ty - 1, "stone")
    s.outline_all()
    return s


def scarecrow_pose(bob: int = 0, head=S_HEAD, lean: int = 0, spear=("diag", 15, 15, 6),
                   pole_dy: int = 0, tilt: int = 0, extras=()) -> Canvas:
    c = Canvas(24, 24)
    c.stamp(S_POLE, 11 + lean, 19 + pole_dy, L)
    c.stamp(S_ARMS, 5 + lean, 13 + bob, L)
    c.stamp(S_BODY, 7 + lean, 12 + bob, L)
    c.stamp(head, 7 + lean + tilt, 5 + bob, L)
    c.stamp(S_HAT, 5 + lean + tilt, 0 + bob, L)
    if spear is not None:
        kind, sx, sy, ln = spear
        if kind == "diag":
            c.blit(diag_spear_layer(sx + lean, sy + bob, ln), 0, 0)
        else:
            c.blit(spear_layer(sx + lean, sy + bob, ln), 0, 0)
        c.stamp(["yg"], 16 + lean, 14 + bob, L)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


def scarecrow() -> list[Anim]:
    idle = [scarecrow_pose(0), scarecrow_pose(1, pole_dy=0)]
    run = [  # hops on its single pole
        scarecrow_pose(0),
        scarecrow_pose(-1, pole_dy=-1),
        scarecrow_pose(-2, pole_dy=-2),
        scarecrow_pose(-1, pole_dy=-1),
    ]
    attack = [
        scarecrow_pose(0, lean=-1, spear=("flat", 12, 15, 6)),
        scarecrow_pose(0, lean=1, spear=("flat", 15, 15, 5)),
        scarecrow_pose(0, lean=0, spear=("flat", 14, 15, 5)),
    ]
    hurt = [scarecrow_pose(0, head=S_HEAD_HURT, lean=-1, tilt=-1,
                           extras=[(["y.g"], 3, 9), (["g.y"], 19, 8), (["y"], 20, 12), (STAR, 1, 1)])]
    return [
        Anim("idle", idle, 3.0, True),
        Anim("run", run, 8.0, True),
        Anim("attack", attack, 10.0, False, [1.5, 1.0, 1.0]),
        Anim("hurt", hurt, 1.0, False),
    ]


# --------------------------------------------------------------------------
# Crow scout 烏鴉斥候 (16x16)
# --------------------------------------------------------------------------

C_BODY = [
    "......Pv..",
    "....vvvP..",
    "..vvVVvvv.",
    ".vvVvvwwwv",
    "vvvvvvwoov",
    "vvvvvvvoov",
    "PvvVVVVvpv",
    ".PvVVVVvv.",
    "..PPPPPP..",
]

C_BODY_BLINK = [
    "......Pv..",
    "....vvvP..",
    "..vvVVvvv.",
    ".vvVvvvvvv",
    "vvvvvvvvvv",
    "vvvvvvoooo",
    "PvvVVVVvpv",
    ".PvVVVVvv.",
    "..PPPPPP..",
]

C_BODY_HURT = [
    "......Pv..",
    "....vvvP..",
    "..vvVVvvv.",
    ".vvVvvowov",
    "vvvvvvvovv",
    "vvvvvvowov",
    "PvvVVVVvpv",
    ".PvVVVVvv.",
    "..PPPPPP..",
]

C_BEAK = ["Oy", "O."]
C_WING_UP = [
    "...PV",
    "..PvV",
    ".PvvP",
    "PvvP.",
    "PPP..",
]
C_WING_MID = [
    "PPPPV",
    "PvvvV",
    ".PPP.",
]
C_WING_DOWN = [
    "PPP..",
    "PvvP.",
    ".PvvP",
    "..PvV",
    "...PV",
]
C_WING_BACK = [
    "VVvvP",
    ".PPP.",
]
C_TAIL = ["PP.", "vPP", "PP."]
C_SCARF = ["RR", "Rr"]
C_FEET = ["O.O"]


def crow_pose(body=C_BODY, wing=C_WING_MID, wing_at=(4, 6), bob: int = 0, dive: int = 0,
              feet: bool = False, extras=()) -> Canvas:
    c = Canvas(16, 16)
    c.stamp(C_TAIL, 1, 7 + bob, L)
    if feet:
        c.stamp(C_FEET, 6, 13 + bob, L)
    c.stamp(body, 3, 3 + bob + dive, L)
    c.stamp(C_BEAK, 13, 7 + bob + dive, L)
    c.stamp(C_SCARF, 9, 10 + bob + dive, L)
    c.stamp(wing, wing_at[0], wing_at[1] + bob + dive, L)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


def crow() -> list[Anim]:
    idle = [crow_pose(wing=C_WING_UP, wing_at=(3, 3)), crow_pose(wing=C_WING_DOWN, wing_at=(3, 8), bob=1)]
    run = [
        crow_pose(wing=C_WING_UP, wing_at=(3, 3)),
        crow_pose(wing=C_WING_MID, wing_at=(3, 8), bob=1),
        crow_pose(wing=C_WING_DOWN, wing_at=(3, 8), bob=1),
        crow_pose(wing=C_WING_MID, wing_at=(3, 8)),
    ]
    attack = [
        crow_pose(wing=C_WING_UP, wing_at=(3, 2), bob=-1),
        crow_pose(wing=C_WING_BACK, wing_at=(1, 8), dive=1),
        crow_pose(wing=C_WING_BACK, wing_at=(1, 8), dive=2),
    ]
    hurt = [crow_pose(body=C_BODY_HURT, wing=C_WING_UP, wing_at=(3, 3),
                      extras=[(["V.."], 0, 2), (["..V"], 13, 1), (["V"], 1, 13)])]
    return [
        Anim("idle", idle, 6.0, True),
        Anim("run", run, 12.0, True),
        Anim("attack", attack, 12.0, False, [1.0, 1.0, 2.0]),
        Anim("hurt", hurt, 1.0, False),
    ]


# --------------------------------------------------------------------------
# Black knight 黑騎士 (48x48): an enchanted, empty suit of armour.
# --------------------------------------------------------------------------

K = 48

K_HELM = [
    ".....iiiiiiii.....",
    "...iizzzzzzzzii...",
    "..izzsssszzzzzzi..",
    ".izzsszzzzzzzzzzi.",
    ".izszzzzzzzzzzzzi.",
    "izzzzzzzzzzzzzzzzi",
    "izzzzzzzziiiiiiiii",
    "izzzzzzzzioVwooVwo",
    "izzzzzzzziiiiiiiii",
    "izzzzzzzzzzzzzizii",
    "izzzzzzzzzzzzzizii",
    "iizzzzzzzzzzzzzzii",
    ".iizzzzzzzzzzzzii.",
    "..iiiiiiiiiiiiii..",
]

K_HELM_DIM = [row.replace("w", "V") for row in K_HELM]
K_HELM_HURT = [row.replace("w", "o").replace("V", "o") for row in K_HELM]


def visor_glow(c: Canvas, x0: int, y0: int, w: int, h: int) -> None:
    """v2.3 (CS5): the violet magic inside the empty helm lights the steel around the visor
    (painted glow: nearby dark steel turns violet / plum in a checker, so it reads as light)."""
    eyes = [(x, y) for y in range(y0, y0 + h) for x in range(x0, x0 + w)
            if c.get(x, y) is not None and c.get(x, y)[:3] in (_RGB["white"], _RGB["lilac"])]
    for (ex, ey) in eyes:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if abs(dx) + abs(dy) > 2 or (dx, dy) == (0, 0):
                    continue
                p = c.get(ex + dx, ey + dy)
                if p is None:
                    continue
                if p[:3] == _RGB["steel_d"] and (ex + dx + ey + dy) % 2 == 0:
                    c.set(ex + dx, ey + dy, "violet")
                elif p[:3] == _RGB["iron"] and abs(dy) == 1 and (ex + dx) % 2 == 0:
                    c.set(ex + dx, ey + dy, "plum")

K_CREST = [
    "..........vVV.",
    "......vvvVVVVv",
    "...vvVVVvvvvPv",
    ".vvVvvvPPPPPP.",
    "vVvvPPP.......",
    "vPPP..........",
    "P.............",
]

K_TORSO = [
    "....iiiiPvPiiiiiiii.....",
    "..iizzzzzPvzzzzzzzzii...",
    ".izzzsszzzzzzzzzzzzzzi..",
    "izzzsszzzzzzzzzzzzzzzii.",
    "izzzszzzzzzVVVzzzzzzzii.",
    "izzzzzzzzzVvlvVzzzzzziii",
    "izzzzzzzzzVvvvVzzzzzziii",
    "izzzzzzzzzzVvVzzzzzzziii",
    "iizzzzzzzzzzVzzzzzzziiii",
    ".iizzzzzzzzzzzzzzzziiii.",
    "..iiiizzzzzzzzzziiiiii..",
    "..nnnnnnnnnnnnnnnnnnnn..",
    "..nnnnnnnnnyynnnnnnnnn..",
    "..iiizzzziiiizzzziiiii..",
    "..izzzzziiizzzzziiizzi..",
    "..izzzzzi.izzzzzi.izzi..",
    "..izzzzi...izzzi...izi..",
    "...iiii.....iii.....i...",
]

K_PAULDRON = [
    "...iiiii...",
    ".iizzzzzii.",
    "izzsszzzzzi",
    "izszzzzzzzi",
    "izzzzzzzzii",
    "iizzzzzziii",
    ".iiiiiiiii.",
]

K_LEG = [
    ".iiiiii..",
    ".izzzzi..",
    ".izzzzi..",
    ".iszzzi..",
    "iizzzzii.",
    ".izzzzi..",
    ".izzzzi..",
    ".izzzzi..",
    ".izzzzii.",
    "izzzzzzzi",
    "iiiiiiiii",
]

K_CAPE = [
    "........PPPPPPP.",
    "......PPvvvvvvP.",
    ".....PvvvPvvvvP.",
    "....PvvvPvvvvvP.",
    "...PvvvPvvvvvvP.",
    "...PvvPvvvvvvvP.",
    "..PvvvPvvvvvvvP.",
    "..PvvPvvvvvvvvP.",
    "..PvvPvvvvvvvvP.",
    ".PvvvPvvvvvvvvP.",
    ".PvvPvvvvvvvvvP.",
    ".PvvPvvvvvvvvvP.",
    "PvvvPvvvvvvvvvP.",
    "PvvPvvvvvvvvvvP.",
    "PvvPvvvvvvvvvvP.",
    "PvvPvvvvvvvvvP..",
    "PvPvvvvvvvvvvP..",
    "PvPvvPvvPvvvP...",
    "PP.PvP.PvP.PP...",
    "P...P...P.......",
]

K_CAPE_WIND = [
    "..............PP",
    "...........PPvvP",
    "........PPPvvvvP",
    ".....PPPvvvvvvvP",
    "...PPvvvvPvvvvvP",
    ".PPvvvvvPvvvvvvP",
    "PvvvvvPPvvvvvvvP",
    ".PPvvvvvvvvvvvP.",
    "..PPPvvvvvvvvP..",
    "PPPvvvvvvvvPP...",
    "PvvvvPPPPPP.....",
    ".PPPP...........",
]

K_GAUNTLET = [".iiii", "izzzi", "izszi", "izzzi", ".iii."]


def greatsword(c: Canvas, hx: int, hy: int, d: tuple[int, int], length: int) -> None:
    """Wide dark greatsword with a violet rune; crossguard centred on (hx, hy)."""
    dx, dy = d
    px, py = -dy, dx
    side = [(-1, "steel"), (0, "steel_d"), (1, "iron"), (2, "iron")]
    for i in range(1, length + 1):
        x, y = hx + dx * i, hy + dy * i
        for off, col in side:
            if i >= length - 1 and off in (-1, 2):
                continue
            if i == length and off != 0:
                continue
            if off == 0 and 3 <= i <= length - 4 and i % 3 == 0:
                col = "lilac"
            if dx != 0 and dy != 0:
                c.set(x + off, y, col)
            else:
                c.set(x + px * off, y + py * off, col)
    for k in range(-3, 5):
        c.set(hx + px * k, hy + py * k, "iron" if -3 < k < 4 else "violet")
    c.set(hx + px // 2, hy + py // 2, "lilac")
    for k in (1, 2, 3):
        c.set(hx - dx * k, hy - dy * k, "brown_d")
        c.set(hx - dx * k + px, hy - dy * k + py, "brown")
    c.set(hx - dx * 4, hy - dy * 4, "violet")
    c.set(hx - dx * 4 + px, hy - dy * 4 + py, "violet")


def greatsword_layer(hx: int, hy: int, d: tuple[int, int], length: int) -> Canvas:
    s = Canvas(K, K)
    greatsword(s, hx, hy, d, length)
    s.outline_all()
    return s


def knight_pose(bob: int = 0, helm=K_HELM, lean: int = 0, legs=((14, 35), (25, 35)),
                sword=((38, 22), (0, 1), 22), sword_behind: bool = False, cape=None,
                hand=None, extras=(), crouch: int = 0) -> Canvas:
    c = Canvas(K, K)
    by = bob + crouch
    if cape == "wind":
        c.stamp(K_CAPE_WIND, 0 + lean, 17 + by, L)
    else:
        c.stamp(K_CAPE, 3 + lean, 16 + by, L)
    if sword is not None and sword_behind:
        c.blit(greatsword_layer(sword[0][0] + lean, sword[0][1] + by, sword[1], sword[2]), 0, 0)
    c.stamp(K_LEG, legs[0][0], legs[0][1], L)
    c.stamp(K_PAULDRON, 9 + lean, 15 + by, L)
    c.stamp(K_TORSO, 11 + lean, 18 + by, L)
    c.stamp(K_LEG, legs[1][0], legs[1][1], L)
    c.stamp(K_CREST, 11 + lean, 1 + by, L)
    c.stamp(helm, 16 + lean, 5 + by, L)
    visor_glow(c, 16 + lean, 5 + by, 19, 14)
    c.stamp(K_PAULDRON, 29 + lean, 16 + by, L)
    if sword is not None and not sword_behind:
        c.blit(greatsword_layer(sword[0][0] + lean, sword[0][1] + by, sword[1], sword[2]), 0, 0)
    if hand is None:
        hand = (sword[0][0] - 2 - sword[1][0] * 2, sword[0][1] - 2 - sword[1][1] * 2)
    c.stamp(K_GAUNTLET, hand[0] + lean, hand[1] + by, L)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


K_SPARK = ["..y..", ".yOy.", "yOwOy", ".yOy.", "..y.."]
K_DUST = ["..ll.l..", ".lllltl.", "lltllllt"]
K_WISP = [".V", "Vv", ".v"]


def knight_down() -> Canvas:
    """Armour collapsed on the ground: visibly empty (dark visor, no glow, magic wisps leaving)."""
    c = Canvas(K, K)
    c.stamp(K_CAPE_WIND[5:], 0, 38, L)
    c.blit(greatsword_layer(4, 43, (1, 0), 26), 0, 0)
    c.stamp([
        "...iiiiiiiiii...",
        ".iizzzzzzzzzzii.",
        "izzzzzzVVVzzzzzi",
        "izzsszVvvvVzzzzi",
        "izzzzzzVvVzzzzzi",
        ".iizzzzzzzzzzii.",
        "...iiiiiiiiii...",
    ], 2, 33, L)
    c.stamp(K_PAULDRON, 17, 36, L)
    c.stamp(K_LEG[5:], 37, 39, L)
    c.stamp(K_HELM_HURT, 24, 29, L)
    c.stamp(K_PAULDRON, 36, 30, L)
    c.stamp(K_GAUNTLET, 14, 42, L)
    c.stamp(K_WISP, 38, 22, L, outline=None)
    c.stamp(K_WISP, 33, 17, L, outline=None)
    c.stamp(K_WISP, 9, 26, L, outline=None)
    c.stamp(K_WISP, 28, 23, L, outline=None)
    return c


def black_knight() -> list[Anim]:
    idle = [knight_pose(0), knight_pose(1, helm=K_HELM_DIM)]
    run_sword = ((35, 30), (1, 1), 11)
    run = [
        knight_pose(0, legs=((12, 34), (27, 35)), sword=run_sword),
        knight_pose(-1, legs=((15, 35), (24, 34)), sword=run_sword),
        knight_pose(0, legs=((13, 35), (26, 34)), sword=run_sword),
        knight_pose(-1, legs=((16, 34), (23, 35)), sword=run_sword),
    ]
    attack = [
        knight_pose(0, lean=-2, sword=((22, 14), (-1, -1), 13), sword_behind=True, hand=(20, 13)),
        knight_pose(0, lean=2, sword=((33, 27), (1, 0), 12), hand=(30, 25)),
        knight_pose(1, lean=2, sword=((33, 29), (1, 1), 12), hand=(30, 26)),
    ]
    hurt = [knight_pose(0, helm=K_HELM_HURT, lean=-2, sword=((35, 30), (1, 1), 11),
                        extras=[(K_SPARK, 35, 6), (K_SPARK, 6, 12), (["y"], 42, 16)])]
    charge = [
        knight_pose(1, lean=3, cape="wind", legs=((13, 35), (28, 35)), sword=((34, 28), (1, 0), 11), hand=(31, 26)),
        knight_pose(2, lean=3, cape="wind", legs=((16, 35), (25, 35)), sword=((34, 28), (1, 0), 11), hand=(31, 26)),
    ]
    slam = [
        knight_pose(-1, lean=-1, sword=((31, 14), (0, -1), 13), hand=(29, 13)),
        knight_pose(0, lean=1, sword=((33, 20), (1, 0), 12), hand=(30, 18)),
        knight_pose(1, lean=1, crouch=1, sword=((39, 24), (0, 1), 21), hand=(37, 21),
                    extras=[(K_DUST, 30, 44), (K_DUST, 40, 44)]),
    ]
    return [
        Anim("idle", idle, 2.5, True),
        Anim("run", run, 7.0, True),
        Anim("attack", attack, 9.0, False, [1.5, 1.0, 1.5]),
        Anim("hurt", hurt, 1.0, False),
        Anim("charge", charge, 10.0, True),
        Anim("slam", slam, 8.0, False, [2.0, 1.0, 2.0]),
        Anim("down", [knight_down()], 1.0, False),
    ]


# --------------------------------------------------------------------------
# v2.2 (CP1): more frames for every enemy (cell sizes unchanged)
# --------------------------------------------------------------------------

STRAW = ["y"]


def scarecrow_v2() -> list[Anim]:
    idle = [scarecrow_pose(0), scarecrow_pose(0, tilt=1), scarecrow_pose(1), scarecrow_pose(1, tilt=-1)]
    hops = [0, -1, -3, -3, -2, 0]
    run = []
    for i, b in enumerate(hops):
        extras = [(STRAW, 9 + i % 3, 22)] if b == 0 else []
        run.append(scarecrow_pose(b, pole_dy=b, tilt=1 if b <= -3 else 0, extras=extras))
    attack = [
        scarecrow_pose(0, lean=-1, tilt=-1, spear=("flat", 10, 15, 6)),
        scarecrow_pose(0, lean=1, tilt=1, spear=("flat", 15, 15, 6)),
        scarecrow_pose(0, lean=1, spear=("flat", 15, 15, 5)),
        scarecrow_pose(0, lean=0, spear=("flat", 13, 15, 5)),
    ]
    hurt = [
        scarecrow_pose(0, head=S_HEAD_HURT, lean=-1, tilt=-1,
                       extras=[(["y.g"], 3, 9), (["g.y"], 19, 8), (["y"], 20, 12), (STAR, 1, 1)]),
        scarecrow_pose(1, head=S_HEAD_HURT, lean=-1, tilt=0,
                       extras=[(["y"], 2, 12), (["g"], 21, 14), (STAR, 0, 0), (STAR, 18, 1)]),
    ]
    return [
        Anim("idle", idle, 5.0, True),
        Anim("run", run, 12.0, True),
        Anim("attack", attack, 12.0, False, [1.5, 1.0, 1.0, 1.0]),
        Anim("hurt", hurt, 6.0, False, [1.0, 3.0]),
    ]


def crow_v2() -> list[Anim]:
    idle = [
        crow_pose(wing=C_WING_UP, wing_at=(3, 3)),
        crow_pose(wing=C_WING_MID, wing_at=(3, 8), bob=1),
        crow_pose(wing=C_WING_DOWN, wing_at=(3, 8), bob=1),
        crow_pose(body=C_BODY_BLINK, wing=C_WING_MID, wing_at=(3, 8)),
    ]
    run = [
        crow_pose(wing=C_WING_UP, wing_at=(3, 3)),
        crow_pose(wing=C_WING_UP, wing_at=(3, 4), bob=0),
        crow_pose(wing=C_WING_MID, wing_at=(3, 8), bob=1),
        crow_pose(wing=C_WING_DOWN, wing_at=(3, 8), bob=1),
        crow_pose(wing=C_WING_DOWN, wing_at=(3, 8), bob=0),
        crow_pose(wing=C_WING_MID, wing_at=(3, 8)),
    ]
    attack = [
        crow_pose(wing=C_WING_UP, wing_at=(3, 2), bob=-1),
        crow_pose(wing=C_WING_UP, wing_at=(2, 2), bob=-1),
        crow_pose(wing=C_WING_BACK, wing_at=(1, 8), dive=1),
        crow_pose(wing=C_WING_BACK, wing_at=(1, 8), dive=2),
    ]
    hurt = [
        crow_pose(body=C_BODY_HURT, wing=C_WING_UP, wing_at=(3, 3),
                  extras=[(["V.."], 0, 2), (["..V"], 13, 1), (["V"], 1, 13)]),
        crow_pose(body=C_BODY_HURT, wing=C_WING_DOWN, wing_at=(3, 8), bob=1,
                  extras=[(["V"], 0, 4), (["V"], 14, 3), (["..V"], 11, 13)]),
    ]
    return [
        Anim("idle", idle, 8.0, True, [1.0, 1.0, 1.0, 1.0]),
        Anim("run", run, 16.0, True),
        Anim("attack", attack, 12.0, False, [1.0, 0.5, 1.0, 2.0]),
        Anim("hurt", hurt, 6.0, False, [1.0, 3.0]),
    ]


K_SPARK_SMALL = [".y.", "yOy", ".y."]


def black_knight_v2() -> list[Anim]:
    idle = [knight_pose(0), knight_pose(0, helm=K_HELM_DIM), knight_pose(1, helm=K_HELM_DIM), knight_pose(1)]
    run_sword = ((35, 30), (1, 1), 11)
    legs = [((12, 34), (27, 35)), ((14, 35), (25, 34)), ((15, 35), (24, 35)),
            ((16, 34), (23, 35)), ((14, 35), (25, 35)), ((13, 35), (26, 34))]
    bobs = [0, -1, -1, 0, -1, -1]
    run = [knight_pose(bobs[i], legs=legs[i], sword=run_sword) for i in range(6)]
    attack = [
        knight_pose(0, lean=-2, sword=((22, 14), (-1, -1), 13), sword_behind=True, hand=(20, 13)),
        knight_pose(0, lean=1, sword=((31, 19), (1, -1), 11), hand=(28, 18)),
        knight_pose(0, lean=2, sword=((33, 27), (1, 0), 12), hand=(30, 25)),
        knight_pose(1, lean=2, sword=((33, 29), (1, 1), 12), hand=(30, 26)),
    ]
    hurt = [
        knight_pose(0, helm=K_HELM_HURT, lean=-2, sword=((35, 30), (1, 1), 11),
                    extras=[(K_SPARK, 35, 6), (K_SPARK, 6, 12), (["y"], 42, 16)]),
        knight_pose(1, helm=K_HELM_HURT, lean=-1, sword=((35, 30), (1, 1), 11),
                    extras=[(K_SPARK_SMALL, 37, 8), (K_SPARK_SMALL, 8, 14)]),
    ]
    charge = [
        knight_pose(1, lean=3, cape="wind", legs=((13, 35), (28, 35)), sword=((34, 28), (1, 0), 11), hand=(31, 26)),
        knight_pose(2, lean=3, cape="wind", legs=((16, 35), (25, 35)), sword=((34, 28), (1, 0), 11), hand=(31, 26)),
        knight_pose(1, lean=3, cape="wind", legs=((19, 35), (22, 35)), sword=((34, 28), (1, 0), 11), hand=(31, 26),
                    extras=[(K_DUST, 2, 44)]),
    ]
    slam = [
        knight_pose(-1, lean=-1, sword=((31, 14), (0, -1), 13), hand=(29, 13)),
        knight_pose(0, lean=1, sword=((33, 20), (1, 0), 12), hand=(30, 18)),
        knight_pose(1, lean=1, crouch=1, sword=((39, 24), (0, 1), 21), hand=(37, 21),
                    extras=[(K_DUST, 30, 44), (K_DUST, 40, 44)]),
        knight_pose(1, lean=1, crouch=1, sword=((39, 24), (0, 1), 21), hand=(37, 21),
                    extras=[(K_DUST, 28, 43), (K_DUST, 41, 43)]),
    ]
    kneel = knight_pose(3, helm=K_HELM_HURT, lean=-1, crouch=2, sword=((36, 32), (1, 1), 10),
                        extras=[(K_WISP, 30, 6), (K_WISP, 12, 10)])
    return [
        Anim("idle", idle, 4.0, True),
        Anim("run", run, 10.0, True),
        Anim("attack", attack, 10.0, False, [1.5, 0.6, 1.0, 1.5]),
        Anim("hurt", hurt, 6.0, False, [1.0, 3.0]),
        Anim("charge", charge, 12.0, True),
        Anim("slam", slam, 10.0, False, [2.0, 0.6, 2.0, 2.0]),
        Anim("down", [kneel, knight_down()], 3.0, False, [1.0, 1.0]),
    ]
