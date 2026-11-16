"""v2.3 cast (CS4): scarecrow archer, armored husk, scarecrow captain, Merlin, and the projectiles.

Contracts (DEV_PLAN 4.11): assets/sprites/<code>/<code>.png + <code>_frames.tres, all facing right.
  scarecrow_archer   24  idle, run, attack, hurt, aim
  armored_husk       24  idle, run, attack, hurt, dash, down
  scarecrow_captain  32  idle, run, attack, hurt, throw, rally, down
  merlin             24  idle, run, cast
  assets/fx/arrow (16), sword_wave (24), pitchfork (16): animation "default", pointing right.
Loop flags and total lengths match the integrator's placeholders, so line A's timing does not move.
Same look as the v2.2 enemies: chunky parts, 1 px ink outline per part, cool purples for foes.
Glows (husk visor, captain feather, Merlin's star) are painted with translucent palette pixels.
"""

from __future__ import annotations

from art_enemies import S_HEAD, S_HEAD_HURT, STAR
from paint import alpha_px
from pixel import Anim, Canvas

L = {
    "o": "ink", "P": "plum", "v": "violet", "V": "lilac", "w": "white", "c": "cream", "d": "dusk",
    "y": "yellow", "g": "gold_l", "G": "gold", "b": "gold_d", "B": "brown", "n": "brown_d",
    "l": "stone_l", "t": "stone", "T": "stone_d", "S": "steel_l", "s": "steel", "z": "steel_d",
    "i": "iron", "O": "orange", "R": "red", "r": "red_d", "p": "pink", "k": "sky_l", "K": "sky",
    "u": "water", "U": "water_d", "N": "night", "m": "night_d",
}


def _glow(c: Canvas, pts, col: str, alpha: int) -> None:
    """Painted light: translucent pixels where the canvas is still empty."""
    for (x, y) in pts:
        if c.get(x, y) is None:
            c.set(x, y, alpha_px(col, alpha))


def _ring(x: int, y: int, r: int) -> list[tuple[int, int]]:
    return [(x + dx, y + dy) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if abs(dx) + abs(dy) <= r]


# --------------------------------------------------------------------------
# Scarecrow archer 稻草人弓兵 (24): pointed straw hat, quiver, bow
# --------------------------------------------------------------------------

A_HAT = [
    ".....nB.....",
    "....nBBB....",
    "...nBBBBB...",
    "...vvvvvvv..",
    ".nBBBBBBBBBn",
    "nBBbBBBBBbBn",
]
A_BODY = [
    "gy.....yg",
    ".yPvvvvy.",
    ".vPvvgvv.",
    ".vPvvvvv.",
    ".bnbbnbb.",
    ".vvvvvPP.",
    "gvPvPvPPg",
    "y.y.y.y.y",
]
A_QUIVER = ["n..", "Bn.", "BBn", "BBn", "BBn", ".Bn"]
A_ARROWS = ["V.V", ".VV", "w.w"]
A_POLE = ["nB", "nB", "nB", "gy"]


def bow_layer(x: int, y: int, drawn: int = 0, arrow: bool = False) -> Canvas:
    """Bow held vertically at grip (x, y); `drawn` pulls the string back by n pixels."""
    s = Canvas(24, 24)
    curve = [(1, -5), (1, -4), (2, -3), (2, -2), (2, -1), (2, 0), (2, 1), (2, 2), (2, 3), (1, 4), (1, 5)]
    for (dx, dy) in curve:
        s.set(x + dx, y + dy, "brown")
    s.set(x + 2, y - 1, "gold_l")
    s.set(x + 1, y - 6, "brown_d")
    s.set(x + 1, y + 6, "brown_d")
    s.outline_all()
    for dy in range(-5, 6):
        t = 1.0 - abs(dy) / 5.0
        s.set(x + 1 - int(round(drawn * t)), y + dy, "stone_l" if drawn else "stone")
    if arrow:
        for i in range(-drawn, 5):
            s.set(x + i + 1, y, "brown")
        s.set(x + 6, y, "steel_l")
        s.set(x + 7, y, "white")
        s.set(x - drawn, y - 1, "lilac")
        s.set(x - drawn, y + 1, "lilac")
    return s


def archer_pose(bob: int = 0, head=S_HEAD, lean: int = 0, bow=(14, 13, 0, False), pole_dy: int = 0,
                tilt: int = 0, extras=()) -> Canvas:
    c = Canvas(24, 24)
    c.stamp(A_QUIVER, 4 + lean, 9 + bob, L)
    c.stamp(A_ARROWS, 3 + lean, 6 + bob, L, outline=None)
    c.stamp(A_POLE, 11 + lean, 19 + pole_dy, L)
    c.stamp(["gy.........yg", "ynnnnnnnnnnny", "gy.........yg"], 5 + lean, 13 + bob, L)
    c.stamp(A_BODY, 7 + lean, 12 + bob, L)
    c.stamp(head, 7 + lean + tilt, 5 + bob, L)
    c.stamp(A_HAT, 6 + lean + tilt, 0 + bob, L)
    if bow is not None:
        bx, by, drawn, arrow = bow
        c.blit(bow_layer(bx + lean, by + bob, drawn, arrow), 0, 0)
        c.stamp(["yg"], bx - 1 + lean, by + bob, L, outline=None)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


def scarecrow_archer() -> list[Anim]:
    idle = [archer_pose(0), archer_pose(1)]
    run = [archer_pose(0), archer_pose(-1, pole_dy=-1), archer_pose(-2, pole_dy=-2), archer_pose(-1, pole_dy=-1)]
    aim = [archer_pose(0, lean=-1, bow=(15, 12, 3, True)),
           archer_pose(0, lean=-1, bow=(15, 12, 4, True), extras=[(["w"], 23, 12)])]
    attack = [archer_pose(0, lean=-1, bow=(15, 12, 0, False), extras=[(["ww"], 21, 12)]),
              archer_pose(0, lean=0, bow=(15, 12, 0, False)),
              archer_pose(0, lean=0, bow=(14, 13, 0, False))]
    hurt = [archer_pose(0, head=S_HEAD_HURT, lean=-1, tilt=-1, bow=(14, 14, 0, False),
                        extras=[(["y.g"], 2, 10), (["g.y"], 19, 8), (STAR, 1, 1)])]
    return [
        Anim("idle", idle, 4.0, True),
        Anim("run", run, 8.0, True),
        Anim("attack", attack, 10.0, False, [1.0, 1.0, 1.0]),
        Anim("hurt", hurt, 1.0, False),
        Anim("aim", aim, 6.0, True),
    ]


# --------------------------------------------------------------------------
# Armored husk 空盔甲兵 (24): an empty suit of armour, blue magic light in the visor, tower shield
# --------------------------------------------------------------------------

H_HELM = [
    "..ziiiiz..",
    ".zsSSsiiz.",
    "zsSSssiiiz",
    "zsSsssiiiz",
    "oooooooooo",
    "zssssssiiz",
    "zsSsso.o.z",
    ".zsssiiiz.",
]
H_BODY = [
    ".zzzzzzzz.",
    "zsSSsssiiz",
    "zSSssssiiz",
    "zsssPPsiiz",
    "zssssssiiz",
    ".nnnnnnnn.",
    ".ziiiiiiz.",
]
H_PAULDRON = [".zzz.", "zSssz", "zsssz", ".zzz."]
H_LEG = ["zi", "zi", "ii"]
H_SHIELD = [
    "zzzzzz",
    "zSsssz",
    "zsPPsz",
    "zsPvsz",
    "zsPPsz",
    "zsssiz",
    ".zsiz.",
    "..zz..",
]


def husk_pose(bob: int = 0, lean: int = 0, shield=(15, 9), legs=((8, 19), (12, 19)), visor: int = 1,
              helm_dy: int = 0, extras=(), tilt_shield: bool = False) -> Canvas:
    c = Canvas(24, 24)
    for (lx, ly) in legs:
        c.stamp(H_LEG, lx + lean, ly, L)
    c.stamp(H_BODY, 6 + lean, 12 + bob, L)
    c.stamp(H_PAULDRON, 4 + lean, 11 + bob, L)
    c.stamp(H_HELM, 6 + lean, 3 + bob + helm_dy, L)
    # visor glow: blue magic light inside the empty helm
    vy = 7 + bob + helm_dy
    if visor > 0:
        for x in (9, 10, 13, 14):
            c.set(x + lean, vy, "sky_l")
        c.set(10 + lean, vy, "white")
        c.set(14 + lean, vy, "white")
        c.set(8 + lean, vy, "sky")
        c.set(15 + lean, vy, "sky")
        if visor > 1:
            _glow(c, [(x + lean, vy) for x in (4, 5, 17, 18)] + [(x + lean, vy - 1) for x in (16, 17)], "sky_l", 120)
    if shield is not None:
        sx, sy = shield
        grid = H_SHIELD if not tilt_shield else [r[1:] + "." for r in H_SHIELD]
        c.stamp(grid, sx + lean, sy + bob, L)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


def husk_down() -> Canvas:
    c = Canvas(24, 24)
    c.stamp(H_SHIELD, 1, 13, L)
    c.stamp(["..zzzzzz..", ".zsSsssiz.", "zsssPPsiiz", ".nnnnnnnn."], 8, 17, L)
    c.stamp(H_PAULDRON, 16, 18, L)
    c.stamp(["..ziiz..", ".zsSsiz.", "zsSssiiz", "oooooooo", ".zsssiz."], 10, 10, L)
    c.stamp(H_LEG, 4, 21, L)
    for (x, y) in ((14, 6), (15, 4), (13, 3)):
        c.set(x, y, "sky_l")
    _glow(c, _ring(14, 5, 2), "sky", 70)
    return c


def armored_husk() -> list[Anim]:
    idle = [husk_pose(0, visor=2), husk_pose(1, visor=1)]
    run = [husk_pose(0, legs=((7, 19), (13, 19))), husk_pose(-1, legs=((8, 18), (12, 19))),
           husk_pose(0, legs=((13, 19), (7, 19))), husk_pose(-1, legs=((12, 18), (8, 19)))]
    attack = [husk_pose(0, lean=-1, shield=(13, 10), visor=2),
              husk_pose(0, lean=1, shield=(17, 8), visor=2, extras=[(["w", "w", "w"], 23, 10)]),
              husk_pose(0, lean=0, shield=(16, 9))]
    dash = [husk_pose(0, lean=1, shield=(17, 9), visor=2, legs=((6, 19), (13, 19)),
                      extras=[(["ttt"], 0, 15), (["tt"], 1, 19)]),
            husk_pose(-1, lean=1, shield=(17, 9), visor=2, legs=((8, 19), (11, 18)),
                      extras=[(["tt"], 0, 13), (["ttt"], 0, 18)])]
    hurt = [husk_pose(0, lean=-1, visor=0, helm_dy=-2, tilt_shield=True, extras=[(STAR, 1, 0)])]
    return [
        Anim("idle", idle, 3.0, True),
        Anim("run", run, 8.0, True),
        Anim("attack", attack, 10.0, False, [1.2, 1.0, 0.8]),
        Anim("hurt", hurt, 1.0, False),
        Anim("dash", dash, 10.0, True),
        Anim("down", [husk_down()], 1.0, False),
    ]


# --------------------------------------------------------------------------
# Scarecrow captain 稻草人隊長 (32): bicorne with a purple feather, violet coat, pitchfork
# --------------------------------------------------------------------------

C_HAT = [
    "n.............n",
    "nB....nBn....Bn",
    ".nBBBBBBBBBBBn.",
    ".nBBBBBvBBBBBn.",
    "..nGGGGGGGGGn..",
]
C_FEATHER = ["...vV", ".vvV.", "vvV..", "Pv..."]
C_HEAD = [
    ".llllllllll.",
    "llllllllllll",
    "llolllllollll"[:12],
    "lloollllooll",
    "lloollllooll",
    "lpllllllllpl",
    "tlolololololt"[:12],
    "tllolololoNl".replace("N", "l"),
    ".tttttttttt.",
]
C_HEAD_HURT = [
    ".llllllllll.",
    "llllllllllll",
    "llollolloolo"[:12],
    "llloollloool"[:12],
    "llollolloolo"[:12],
    "lpllllllllpl",
    "tlllooooolll",
    "tlllllllllll",
    ".tttttttttt.",
]
C_COAT = [
    "gy.........yg",
    ".yGGvvvvvGGy.",
    ".vvvvvyvvvvP.",
    ".vVvvvvvvvPP.",
    ".vVvvvyvvvPP.",
    ".nbbbbnbbbbn.",
    ".vVvvvyvvvPP.",
    "gvvPvvvvPvPPg",
    "y.y.gy.y.y.gy",
]
C_ARMS = ["gy.............yg", "ynnnnnnnnnnnnnnny", "gy.............yg"]
C_POLE = ["nB", "nB", "nB", "nB", "gy"]


def fork_layer(x0: int, y0: int, d: tuple[int, int], length: int, size: int = 32) -> Canvas:
    """Pitchfork: handle from (x0, y0) along d, three prongs at the end."""
    s = Canvas(size, size)
    dx, dy = d
    for i in range(length):
        s.set(x0 + dx * i, y0 + dy * i, "brown")
    hx, hy = x0 + dx * length, y0 + dy * length
    px, py = -dy, dx
    diagonal = dx != 0 and dy != 0
    prongs = (-1, 1) if diagonal else (-2, 0, 2)
    for k in prongs:
        bx, by = hx + px * k, hy + py * k
        s.set(bx, by, "steel")
        for j in range(1, 3 if diagonal else 4):
            s.set(bx + dx * j, by + dy * j, "steel_l")
    for k in ((0,) if diagonal else (-1, 1)):
        s.set(hx + px * k, hy + py * k, "steel_d")
    s.outline_all()
    return s


def captain_pose(bob: int = 0, head=C_HEAD, lean: int = 0, fork=((22, 22), (0, -1), 13), pole_dy: int = 0,
                 tilt: int = 0, extras=(), fork_behind: bool = False) -> Canvas:
    c = Canvas(32, 32)
    if fork is not None and fork_behind:
        c.blit(fork_layer(fork[0][0] + lean, fork[0][1] + bob, fork[1], fork[2]), 0, 0)
    c.stamp(C_POLE, 15 + lean, 26 + pole_dy, L)
    c.stamp(C_ARMS, 7 + lean, 17 + bob, L)
    c.stamp(C_COAT, 9 + lean, 16 + bob, L)
    c.stamp(head, 10 + lean + tilt, 8 + bob, L)
    c.stamp(C_HAT, 8 + lean + tilt, 3 + bob, L)
    c.stamp(C_FEATHER, 15 + lean + tilt, 0 + bob, L, outline=None)
    c.set(17 + lean + tilt, 0 + bob, "lilac")
    if fork is not None and not fork_behind:
        c.blit(fork_layer(fork[0][0] + lean, fork[0][1] + bob, fork[1], fork[2]), 0, 0)
        c.stamp(["yg"], fork[0][0] - 1 + lean, fork[0][1] + bob - 4, L, outline=None)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


SHOUT = ["v...v", ".v.v.", "....."]


def captain_down() -> Canvas:
    c = Canvas(32, 32)
    c.stamp(["..g.y..g..y.g..", ".gyGgyGgyGyGgy.", "gyGgGyGgGgyGgyg", "nbbbbnbbbbnbbbn"], 6, 26, L)
    c.stamp(C_HAT, 8, 22, L)
    c.stamp(C_FEATHER, 20, 15, L, outline=None)
    c.blit(fork_layer(2, 29, (1, 0), 7), 0, 0)
    return c


def scarecrow_captain() -> list[Anim]:
    idle = [captain_pose(0), captain_pose(1)]
    run = [captain_pose(0), captain_pose(-1, pole_dy=-1), captain_pose(-2, pole_dy=-2), captain_pose(-1, pole_dy=-1)]
    attack = [captain_pose(0, lean=-2, fork=((20, 19), (-1, -1), 9)),
              captain_pose(0, lean=1, fork=((21, 20), (1, 0), 8)),
              captain_pose(1, lean=1, fork=((21, 21), (1, 1), 7))]
    throw = [captain_pose(0, lean=-2, fork=((18, 14), (-1, -1), 9), fork_behind=True),
             captain_pose(-1, lean=1, fork=((22, 13), (1, -1), 8)),
             captain_pose(0, lean=1, fork=None, extras=[(["yg"], 23, 17)])]
    rally = [captain_pose(-1, fork=((22, 20), (0, -1), 15), extras=[(SHOUT, 25, 2), (SHOUT, 2, 4)]),
             captain_pose(0, fork=((22, 21), (0, -1), 15), extras=[(["v...v", "....."], 26, 1)])]
    hurt = [captain_pose(0, head=C_HEAD_HURT, lean=-1, tilt=-1,
                         extras=[(["y.g"], 3, 14), (["g.y"], 26, 12), (STAR, 2, 4)])]
    return [
        Anim("idle", idle, 4.0, True),
        Anim("run", run, 8.0, True),
        Anim("attack", attack, 10.0, False, [1.4, 0.8, 0.8]),
        Anim("hurt", hurt, 1.0, False),
        Anim("throw", throw, 10.0, False, [1.2, 0.9, 0.9]),
        Anim("rally", rally, 6.0, True),
        Anim("down", [captain_down()], 1.0, False),
    ]


# --------------------------------------------------------------------------
# Merlin 梅林 (24): elderly Shih Tzu wizard, star hat, round glasses, long white beard, star staff
# --------------------------------------------------------------------------

M_HAT = [
    "......NN....",
    ".....NuuN...",
    "....NuyuN...",
    "...NuuuuuN..",
    "..NuuuuyuuN.",
    "NuuuGGGGGuuN",
    "NNNNNNNNNNNN",
]
M_HAT_TIP = ["mN", "Nm", ".y"]
M_FACE = [
    "gwwwwwwwg",
    "gwwwwwwwwg",
    "gwSoSwwSow",
    "gwwwwwwoow",
    "gtwwwwwwwg",
    "gtwwwwwwwg",
]
M_BEARD = [
    "lwwwwwl",
    ".lwwwl.",
    "..lwl..",
]
M_ROBE = [
    "...uuuuu...",
    "..uuyuuuU..",
    ".uuuyuuuuU.",
    ".uKuyuuuuU.",
    "uuuuyuuuuUU",
    "UyyyyyyyyyU",
]
M_ARM = ["uu", "Uc"]


def merlin_staff(c: Canvas, x: int, y: int, glow: int = 1) -> None:
    """Staff with its grip at (x, y); the star sits on top."""
    s = Canvas(24, 24)
    for i in range(1, 12):
        s.set(x, y - 5 + i, "brown")
    s.outline_all()
    c.blit(s, 0, 0)
    sx, sy = x, y - 7
    for (dx, dy) in ((0, -2), (0, -1), (-1, 0), (0, 0), (1, 0), (0, 1), (-2, 0), (2, 0), (-1, 1), (1, 1)):
        c.set(sx + dx, sy + dy, "yellow")
    c.set(sx, sy, "white")
    if glow:
        _glow(c, _ring(sx, sy, 3 + glow), "yellow", 50 + 25 * glow)


def merlin_pose(bob: int = 0, lean: int = 0, staff=(18, 12), glow: int = 1, blink: bool = False,
                legs=((8, 21), (12, 21)), extras=()) -> Canvas:
    c = Canvas(24, 24)
    for (lx, ly) in legs:
        c.stamp(["ww"], lx + lean, ly, L)
    c.stamp(M_ROBE, 5 + lean, 15 + bob, L)
    # long hanging ears (golden silk)
    c.stamp(["gG", "gG", "gG", "gb", "b."], 4 + lean, 9 + bob, L)
    face = M_FACE if not blink else [r.replace("o", "w") if i == 2 else r for i, r in enumerate(M_FACE)]
    if blink:
        face = list(face)
        face[3] = "gwwwwwwoow"
        face[2] = "gwSSSwwSSw"
    c.stamp(face, 6 + lean, 9 + bob, L)
    c.stamp(M_BEARD, 9 + lean, 15 + bob, L)
    c.stamp(M_HAT, 5 + lean, 2 + bob, L)
    if staff is not None:
        merlin_staff(c, staff[0] + lean, staff[1] + bob, glow)
        c.stamp(["cc"], staff[0] - 1 + lean, staff[1] + bob, L, outline=None)
    for grid, x, y in extras:
        c.stamp(grid, x, y, L, outline=None)
    return c


SPARK = ["..y..", ".ywy.", "..y.."]


def merlin() -> list[Anim]:
    idle = [merlin_pose(0, glow=1), merlin_pose(1, glow=2, blink=False)]
    run = [merlin_pose(0, legs=((7, 21), (13, 21))), merlin_pose(-1, legs=((9, 20), (11, 21))),
           merlin_pose(0, legs=((13, 21), (7, 21))), merlin_pose(-1, legs=((11, 20), (9, 21)))]
    cast = [merlin_pose(1, lean=-1, staff=(17, 13), glow=1),
            merlin_pose(-1, staff=(18, 9), glow=3, extras=[(SPARK, 19, 0), (SPARK, 13, 3)]),
            merlin_pose(0, staff=(18, 10), glow=2, extras=[(SPARK, 21, 3), (["y"], 15, 1)])]
    return [
        Anim("idle", idle, 3.0, True),
        Anim("run", run, 8.0, True),
        Anim("cast", cast, 8.0, False, [1.0, 1.5, 1.5]),
    ]


# --------------------------------------------------------------------------
# Projectiles (point right; line A rotates them along their flight)
# --------------------------------------------------------------------------

def arrow() -> list[Anim]:
    frames = []
    for k in range(2):
        c = Canvas(16, 16)
        for x in range(3, 13):
            c.set(x, 8, "brown")
        c.set(13, 8, "steel_l")
        c.set(14, 8, "white")
        c.set(13, 7, "steel")
        c.set(13, 9, "steel")
        c.set(2, 7 - k, "violet")
        c.set(3, 7, "lilac")
        c.set(2, 9 + k, "violet")
        c.set(3, 9, "lilac")
        c.outline_all()
        frames.append(c)
    return [Anim("default", frames, 12.0, True)]


def sword_wave() -> list[Anim]:
    frames = []
    for k in range(3):
        c = Canvas(24, 24)
        r_out, r_in = 10.5 + k * 0.5, 7.0 + k * 0.6
        for y in range(24):
            for x in range(24):
                dx, dy = x + 0.5 - 6, y + 0.5 - 12
                d = (dx * dx + dy * dy) ** 0.5
                if dx > 0 and r_in <= d <= r_out and abs(dy) < 10:
                    edge = r_out - d
                    c.set(x, y, "white" if edge < 1.2 else ("lilac" if edge < 2.4 else "violet"))
        for (x, y) in list((x, y) for y in range(24) for x in range(24)):
            if c.get(x, y) is None:
                n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if c.opaque(x + dx, y + dy) and c.get(x + dx, y + dy)[3] == 255)
                if n:
                    c.set(x, y, alpha_px("violet", 110))
        for (x, y) in ((4, 4 + k * 2), (3, 18 - k), (8, 21)):
            c.set(x, y, alpha_px("lilac", 160))
        frames.append(c)
    return [Anim("default", frames, 12.0, True)]


def pitchfork() -> list[Anim]:
    frames = []
    for d in ((1, 0), (1, 1), (0, 1), (-1, 1)):
        c = Canvas(16, 16)
        dx, dy = d
        hx, hy = 8 - dx * 6, 8 - dy * 6
        f = fork_layer(hx, hy, d, 8, 16)
        c.blit(f, 0, 0)
        frames.append(c)
    return [Anim("default", frames, 12.0, True)]


SPRITES = {
    "scarecrow_archer": (scarecrow_archer, (24, 24)),
    "armored_husk": (armored_husk, (24, 24)),
    "scarecrow_captain": (scarecrow_captain, (32, 32)),
    "merlin": (merlin, (24, 24)),
}
PROJECTILES = {
    "arrow": (arrow, (16, 16)),
    "sword_wave": (sword_wave, (24, 24)),
    "pitchfork": (pitchfork, (16, 16)),
}


if __name__ == "__main__":
    import sys
    from pixel import contact_sheet
    out = sys.argv[1]
    for code, (fn, size) in list(SPRITES.items()) + list(PROJECTILES.items()):
        anims = fn()
        contact_sheet([a.frames for a in anims], 6 if size[0] <= 24 else 5).save("%s/cast_%s.png" % (out, code))
    print("ok")
