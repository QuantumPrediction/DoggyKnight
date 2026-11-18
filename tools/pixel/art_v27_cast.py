"""v2.7 (C 角色, CC6 to CC8) the chapter 4-6 cast, drawn with the v2.5 rig renderer like art_v26_cast. All face right.

  crab           24  red pirate crab with a tiny navy bandana; `guard` raises both claws in front of its face.
  jellyfish      24  translucent glowing violet bell, trailing tentacles; `zap` crackles yellow.
  kraken         64  chapter 4 boss: chubby coral-red octopus, seashell crown, black wolf-head sigil on the forehead.
                     `slam`, `ink` (puffs a cloud), `summon`, `down` (curls into a shy ball, the sigil breaks).
  snowman        24  snowman soldier: black wolf-head knit hat, twig arms, carrot nose; `throw` lobs overhand.
  salamander     24  orange lizard with a little flame on the tail tip; `dash` is a stretched sprint.
  red_dragon     64  chapter 5 boss pair: round, cute, small wings, big eyes. Red with a yellow belly;
  white_dragon   64  snow-white with ice-blue horns and mane. `breath` (fire / frost), `roar`, `sulk` (sits
                     down pouting, arms crossed).
  shadow_knight  32  dark indigo armoured shadow with a big tower shield and glowing eyes; `guard` holds the shield
                     forward; `down` crumbles into autumn leaves (never hurt).
  lantern_wisp   16  little teal ghost-flame carrying a lantern; `heal` makes the lantern pulse.
  mordred        48  final boss: Dobermann black knight, black-and-tan fur, silver-trimmed black armour, wolf-head
                     pauldron, dark grey cape, glowing purple scabbard. `dash`, `slash` (big purple arc), `guard`
                     (the scabbard's purple barrier), `summon`, `down` (kneels on one knee, not hurt).
  tristan        32  corgi bard knight: short legs, big ears, light-blue cape, feathered cap, wooden harp; `play`.
  gawain         40  Saint Bernard mountain knight: big and fluffy, barrel on the collar, iron hammer, orange cloak;
                     `slam` swings the hammer down.

Also: portraits (CC7), projectiles bubble / ink_blob / music_note / snowball / fireball / ice_shard / shadow_slash /
tentacle (CC8) and the one-shot particles snow_burst / bubble_pop.

Animation names and loop flags are the contract of DEV_PLAN 4.14 (tests/core/test_v27_contract.gd): the loop flags
are the placeholders'; one-shot animations stay about as long as the placeholders so line A's timing does not move.
Ground-walking characters plant their feet on one row in every frame: the row above the shadow line of
assets/backgrounds/actor_shadows.gd (cell height - 3). The three 64 px bosses stand 8 px higher (like the black
knight since v2.6) and carry `metadata/foot_lift = 8`, so they never touch the arena's lower edge.

    python3 tools/pixel/art_v27_cast.py [preview_dir] [--only=crab,kraken]   # write (or preview) the v2.7 cast
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art_particles  # noqa: E402
import art_v26_cast as V  # noqa: E402
import paint as P  # noqa: E402
from paint import alpha_px  # noqa: E402
from pixel import Anim, Canvas, build_sheet, contact_sheet, res_path, write_text  # noqa: E402
from rig import Fig, Mat, blade, capsule, ellipse, line_px, poly, rect, union  # noqa: E402

GROUND24 = 21        # 24 px cells: last row of the feet; the outline is row 22 (actor_shadows: h - 2)
GROUND32 = 29
GROUND40 = 37
GROUND48 = 45
LIFT64 = 8           # the 64 px bosses stand 8 px higher (foot_lift metadata), like the black knight
GROUND64 = 62 - LIFT64

stars = V.stars
sparkle = V.sparkle
dissolve = V.dissolve
anim = V.anim
add_foot_lift = V.add_foot_lift


def R(fs: list) -> list:
    """Renders the Figs of a frame list (Canvases pass through)."""
    return [x.render() if isinstance(x, Fig) else x for x in fs]


def translucent(c: Canvas, pts, a: int, keep=("ink", "plum", "white", "yellow", "navy", "deep")) -> Canvas:
    """Makes the given pixels semi-transparent (glass, jelly, ghost light), leaving outline and face colours solid."""
    for (x, y) in pts:
        p = c.get(x, y)
        if p is None or p[3] < 255:
            continue
        if P.name_at(c, x, y) in keep:
            continue
        c.set(x, y, (p[0], p[1], p[2], a))
    return c


def bolt(f: Fig, x0: float, y0: float, x1: float, y1: float, seed: int, col: str = "yellow", core: str = "white") -> None:
    """A little zig-zag electric bolt (drawn as glow pixels: only where the frame is empty)."""
    rng = random.Random(seed)
    n = 4
    pts = [(x0, y0)]
    for i in range(1, n):
        t = i / n
        nx, ny = -(y1 - y0), (x1 - x0)
        ln = math.hypot(nx, ny) or 1
        o = rng.uniform(-1.6, 1.6)
        pts.append((x0 + (x1 - x0) * t + nx / ln * o, y0 + (y1 - y0) * t + ny / ln * o))
    pts.append((x1, y1))
    for i in range(len(pts) - 1):
        for k, (x, y) in enumerate(line_px(*pts[i], *pts[i + 1])):
            f.dot(x, y, core if (i == 1 and k == 1) else col)


def autumn_leaf(c: Canvas, x: int, y: int, k: int, a: int = 255) -> None:
    """A chunky 3x2 autumn leaf (chapter 6: the shadows turn into fallen leaves)."""
    cols = ("orange", "gold", "red_d", "amber", "brown", "gold_d")
    col = cols[k % len(cols)]
    shape = V.LEAF_SHAPES[k % len(V.LEAF_SHAPES)]
    for i, (dx, dy) in enumerate(shape):
        cc = {"orange": "amber", "gold": "gold_l", "red_d": "red", "gold_d": "gold"}.get(col, col) if i == 1 else col
        c.set(x + dx, y + dy, cc if a == 255 else alpha_px(cc, a))


def speed_lines(f: Fig, rows, k: int, col: str = "white", n0: int = 3) -> None:
    for i, (x, y) in enumerate(rows):
        for j in range(n0 + (i % 2)):
            f.glow(x + k + j, y, alpha_px(col, 90 + j * 35))


# ===========================================================================
# CC6 characters
# ===========================================================================

# ---------------------------------------------------------------------------
# crab 螃蟹海盜 (24): front-ish view (it walks sideways), big claws, eye stalks, a tiny navy bandana
# ---------------------------------------------------------------------------

SHELL = Mat(["red_d", "red", "coral", "pink"], outline="wine", lit="red_d", sep="wine", sep_lit="red_d")
SHELL_FAR = Mat(["wine", "red_d", "red", "coral"], outline="wine", lit="wine", sep="wine", sep_lit="wine")
CLAW = Mat(["red_d", "red", "coral", "pink"], outline="wine", lit="red_d", sep="wine", sep_lit="red_d")
BANDANA = Mat(["night", "water_d", "water", "sky"], outline="navy", lit="night", sep="navy", sep_lit="night")
EYEBALL = Mat(["fog", "white", "white"], outline="wine", lit="red_d")


def crab_claw(f: Fig, x: float, y: float, ang: float, gap: float, mat: Mat, size: float = 1.0) -> None:
    """A big cartoon pincer at (x, y): a round palm with a long top finger and a shorter thumb pointing along
    `ang` (degrees, 0 = right, 90 = up), opened by `gap` degrees. The tips are pale."""
    a = math.radians(ang)
    palm = ellipse(x, y, 2.4 * size, 2.3 * size)
    fingers = set()
    tips = []
    for s, ln, w in ((1, 5.0, 1.2), (-1, 4.2, 0.95)):
        b = a + s * math.radians(gap) / 2
        tx, ty = x + math.cos(b) * ln * size, y - math.sin(b) * ln * size
        fingers |= capsule(x + math.cos(b) * 1.4, y - math.sin(b) * 1.4, tx, ty, w * size)
        tips.append((int(round(tx)), int(round(ty))))
    shape = union(palm, fingers)
    f.add(shape, mat, centre=(x - 1.2, y - 1.4), radius=(3.8 * size, 3.4 * size), bias=0.1)
    f.recolor(set(tips) & shape, "peach")


def crab_frame(bob: int = 0, lean: float = 0.0, claws: str = "rest", gap: float = 55.0, legs: int = 0,
               eyes: str = "open", mouth: str = "smile", knot: int = 0, squash: float = 0.0, extra=None) -> Fig:
    f = Fig(24, 24, seed=131)
    cx, cy = 11.5 + lean, 15.5 + bob + squash
    # legs: three a side, thin jointed lines (no outline), tips on the ground; alternate legs lift while running
    lp = {}
    for side in (-1, 1):
        for i in range(3):
            lift = 1 if (legs and (i + (side > 0) + legs) % 2 == 0) else 0
            root = (cx + side * (2.0 + i * 1.4), cy + 2.5)
            knee = (cx + side * (5.0 + i * 1.5), cy + 1.0 - lift - (i == 1) * 0.5)
            tip = (cx + side * (5.8 + i * 1.9), GROUND24 + 1 - lift)
            for p in line_px(*root, *knee):
                lp[p] = "red_d" if side < 0 else "red"
            for p in line_px(*knee, *tip):
                lp.setdefault(p, "wine" if side < 0 else "red_d")
            lp[(int(round(knee[0])), int(round(knee[1])))] = "red_d" if side < 0 else "coral"
    f.pix(lp, SHELL_FAR, sep=False, outline=False)
    near, far = {
        "rest": (((cx + 7.6, cy - 4.4), 78, gap), ((cx - 7.6, cy - 4.2), 102, gap)),
        "up": (((cx + 7.0, cy - 6.0), 70, gap), ((cx - 7.2, cy - 5.6), 110, gap)),
        "guard": (((cx + 3.0, cy - 5.2), 92, 14), ((cx - 2.8, cy - 5.6), 88, 14)),
        "snap": (((cx + 9.6, cy - 2.0), 8, gap), ((cx - 7.6, cy - 4.2), 110, 30)),
        "droop": (((cx + 7.8, cy - 0.5), 30, 10), ((cx - 7.8, cy - 0.5), 150, 10)),
    }[claws]
    raised = claws == "guard"
    (fx, fy), fa, fg = far
    (nx, ny), na, ng = near
    if not raised:
        f.add(capsule(cx - 4.0, cy - 0.5, fx, fy, 0.9), SHELL_FAR, bias=-0.1)
        crab_claw(f, fx, fy, fa, fg, SHELL_FAR, 0.9)
        f.add(capsule(cx + 4.0, cy - 0.5, nx, ny, 0.9), SHELL, bias=0.0)
    # shell: a round shell, a pale underside, a few bright bumps on the lit side
    shell = ellipse(cx, cy, 6.0, 4.4)
    f.add(shell, SHELL, centre=(cx - 1.8, cy - 2.4), radius=(7.0, 5.6), bias=0.06)
    f.recolor({(x, y) for (x, y) in shell if y >= cy + 2.0}, "peach")
    f.recolor({(x, y) for (x, y) in shell if y >= cy + 3.0}, "dirt")
    # tiny navy bandana with white dots over the top of the shell, knotted on the left, tails on the side
    band = {(x, y) for (x, y) in ellipse(cx - 0.8, cy - 2.6, 4.4, 2.5) if y <= cy - 2.8}
    f.add(band, BANDANA, centre=(cx - 2, cy - 4.5), radius=(5, 3), bias=0.15)
    f.recolor({(int(cx - 3), int(cy - 4)), (int(cx + 1), int(cy - 4)), (int(cx - 1), int(cy - 3))} & band, "white")
    kx, ky = cx - 5.0, cy - 2.8
    f.add(union(capsule(kx, ky, kx - 2.2, ky + 1.6 + knot * 0.5, 0.7), capsule(kx, ky, kx - 0.8 - knot * 0.6, ky + 3.0, 0.7)),
          BANDANA, bias=0.08)
    f.add(ellipse(kx, ky, 1.2, 1.1), BANDANA, flat=2)
    # eye stalks and big eyes (looking right)
    up = 1.6 if claws == "guard" else 0.0
    for (sx, top, big) in ((cx - 1.4, cy - 8.4 - up, False), (cx + 2.4, cy - 8.8 - up, True)):
        f.add(capsule(sx, cy - 3.5, sx + 0.3, top + 1.5, 0.55), SHELL, mode="cyl_v", bias=0.1)
        f.add(ellipse(sx + 0.4, top, 1.9 if big else 1.7, 2.0), EYEBALL, bias=0.1)
        ex, ey = int(round(sx + 0.4)), int(round(top - 0.5))
        if eyes == "open":
            f.dots([(ex + 1, ey), (ex + 1, ey + 1)] + ([(ex, ey + 1)] if big else []), "ink")
        elif eyes == "angry":
            f.dots([(ex + 1, ey), (ex + 1, ey + 1)], "ink")
            f.dots([(ex - 1, ey - 1), (ex, ey - 1)] if big else [(ex, ey - 1), (ex + 1, ey - 1)], "wine")
        elif eyes == "squint":
            f.dots([(ex - 1, ey - 1), (ex, ey), (ex - 1, ey + 1)] if big else [(ex + 1, ey - 1), (ex, ey), (ex + 1, ey + 1)],
                   "ink")
        elif eyes == "happy":
            f.dots([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey + 1)], "ink")
    # face on the shell front: a little mouth and blush
    mx, my = int(round(cx + 1)), int(round(cy + 0.4))
    if mouth == "smile":
        f.dots([(mx - 1, my), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my)], "wine")
    elif mouth == "open":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my), (mx, my + 1), (mx + 1, my + 1)], "wine")
        f.dot(mx + 1, my + 1, "pink")
    elif mouth == "o":
        f.dots([(mx, my), (mx + 1, my), (mx, my + 1), (mx + 1, my + 1)], "wine")
    elif mouth == "puff":
        f.dots([(mx - 1, my + 1), (mx, my), (mx + 1, my + 1), (mx + 2, my)], "wine")
    f.dots([(mx - 3, my + 1), (mx + 4, my + 1)], "pink")
    # near claw in front of the shell (or both claws raised in front of the face)
    if raised:
        f.add(capsule(cx - 3.5, cy - 0.5, fx, fy + 2.0, 0.9), SHELL_FAR, bias=-0.05)
        crab_claw(f, fx, fy, fa, fg, SHELL_FAR, 0.95)
        f.add(capsule(cx + 3.5, cy - 0.5, nx, ny + 2.0, 0.9), SHELL, bias=0.05)
    crab_claw(f, nx, ny, na, ng, CLAW, 1.05)
    if extra:
        extra(f)
    return f


def _snap_glint(f: Fig, x: int, y: int) -> None:
    for (dx, dy) in ((0, 0), (1, -1), (1, 1), (2, -2), (2, 2)):
        f.glow(x + dx, y + dy, alpha_px("white", 220 - dx * 40))


def _sweat(f: Fig, x: int, y: int) -> None:
    f.glow(x, y, "sky_l")
    f.glow(x, y + 1, "sky")


def crab() -> list[Anim]:
    C = crab_frame
    idle = [C(), C(gap=55, knot=1), C(squash=1, gap=45, knot=1, eyes="happy"), C(gap=35)]
    run = [C(legs=k + 1, bob=-(k % 2), lean=0.5, claws="up", knot=k % 2, gap=40 + 15 * (k % 2),
             mouth="open" if k % 2 else "smile") for k in range(4)]
    attack = [C(lean=-1, claws="rest", gap=70, eyes="angry", mouth="o"),
              C(lean=1, claws="snap", gap=60, eyes="angry", mouth="open"),
              C(lean=1, claws="snap", gap=4, eyes="angry", mouth="open", extra=lambda f: _snap_glint(f, 21, 11)),
              C(lean=0.5, claws="rest", gap=25)]
    hurt = [C(lean=-1, claws="droop", eyes="squint", mouth="o", extra=lambda f: stars(f, [(4, 3), (19, 2)])),
            C(lean=-0.5, claws="droop", eyes="squint", mouth="puff")]
    guard = [C(claws="guard", squash=1, eyes="angry", mouth="puff", knot=0),
             C(claws="guard", squash=1, eyes="angry", mouth="puff", knot=1, extra=lambda f: _sweat(f, 4, 9))]
    return [anim("idle", R(idle), 6.0, True), anim("run", R(run), 12.0, True),
            anim("attack", R(attack), 14.0, False, [0.8, 1.0, 1.0, 0.8]),
            anim("hurt", R(hurt), 6.0, False, [1.0, 3.0]), anim("guard", R(guard), 4.0, True)]


# ---------------------------------------------------------------------------
# jellyfish 電電水母 (24): a translucent glowing violet bell with trailing tentacles; floats
# ---------------------------------------------------------------------------

JELLY = Mat(["violet", "lilac", "lilac", "white"], outline="plum", lit="violet")
JELLY_ARM = Mat(["rose", "pink", "pink"], outline="plum", lit="rose")


def jelly_frame(pulse: float = 0.0, bob: int = 0, lean: float = 0.0, wave: float = 0.0, eyes: str = "open",
                mouth: str = "smile", zap: int = 0, trail: float = 0.0, reach: float = 0.0, extra=None) -> Canvas:
    f = Fig(24, 24, seed=141)
    cx, cy = 11.5 + lean, 8.5 + bob
    rx, ry = 7.0 - pulse * 0.9, 5.4 + pulse * 0.7
    # tentacles first (behind the bell): thin trailing lines, the two frilly oral arms in front of them
    tents = []
    for i, x0 in enumerate((cx - 4.5, cx - 1.8, cx + 1.4, cx + 4.2)):
        pts = []
        for k in range(8):
            t = k / 7.0
            x = x0 + math.sin(t * 3.0 + wave * 1.6 + i) * 1.1 - trail * t * 3.0 + reach * t * t * (3 + i)
            y = cy + 2.5 + pulse * 0.4 + t * (11.5 - pulse * 1.5 - abs(reach) * 1.5 * (i == 3))
            pts.append((x, y))
        tents.append(pts)
    tpx = set()
    for pts in tents:
        for i in range(len(pts) - 1):
            tpx |= set(line_px(*pts[i], *pts[i + 1]))
    f.pix({p: ("lilac" if (p[1] + int(wave * 2)) % 3 else "pink") for p in tpx}, JELLY, sep=False, outline=False)
    arms = set()
    for i, x0 in enumerate((cx - 1.0, cx + 1.8)):
        pts = [(x0 + math.sin(k * 0.9 + wave * 1.4 + i * 2) * 0.9 - trail * k * 0.35, cy + 3 + k * 1.3) for k in range(6)]
        for k in range(len(pts) - 1):
            arms |= capsule(*pts[k], *pts[k + 1], 0.9 - k * 0.08)
    f.add(arms, JELLY_ARM, bias=0.15, sep=False)
    # the bell: a dome with a scalloped rim
    bell = {(x, y) for (x, y) in ellipse(cx, cy + 1.0, rx, ry + 1.0) if y <= cy + 2.0}
    for i in range(-3, 4):
        bell |= ellipse(cx + i * rx / 3.3, cy + 2.3, 1.2, 1.0)
    bid = f.add(bell, JELLY, centre=(cx - 2, cy - 2), radius=(rx + 1, ry + 1), bias=0.04 + zap * 0.15)
    # four-leaf pattern on the crown (pink), a glowing core
    f.recolor({(int(cx - 2), int(cy - 2)), (int(cx - 1), int(cy - 3)), (int(cx + 1), int(cy - 3)), (int(cx + 2), int(cy - 2))},
              "pink")
    f.recolor({(x, y) for (x, y) in bell if (x, y - 1) not in bell and x < cx + 2} | {(int(cx - 4), int(cy - 2)),
              (int(cx - 5), int(cy - 1))}, "white")
    # face (looking right)
    ex, ey = int(round(cx + 1)), int(round(cy))
    if eyes == "open":
        f.dots([(ex, ey), (ex, ey + 1), (ex + 3, ey), (ex + 3, ey + 1)], "ink")
        f.dots([(ex, ey), (ex + 3, ey)], "white")
    elif eyes == "squint":
        f.dots([(ex - 1, ey), (ex, ey + 1), (ex - 1, ey + 2), (ex + 4, ey), (ex + 3, ey + 1), (ex + 4, ey + 2)], "plum")
    elif eyes == "zap":
        f.dots([(ex - 1, ey), (ex, ey + 1), (ex + 1, ey), (ex + 2, ey), (ex + 3, ey + 1), (ex + 4, ey)], "plum")
    elif eyes == "happy":
        f.dots([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey + 1), (ex + 2, ey + 1), (ex + 3, ey), (ex + 4, ey + 1)], "plum")
    if mouth == "smile":
        f.dots([(ex + 1, ey + 2), (ex + 2, ey + 2)], "plum")
    elif mouth == "o":
        f.dots([(ex + 1, ey + 2), (ex + 2, ey + 2), (ex + 1, ey + 3), (ex + 2, ey + 3)], "plum")
    elif mouth == "grin":
        f.dots([(ex, ey + 2), (ex + 1, ey + 3), (ex + 2, ey + 3), (ex + 3, ey + 2)], "plum")
    f.dots([(ex - 2, ey + 2), (ex + 5, ey + 2)], "pink")
    # soft glow around the bell
    for (x, y) in P.ellipse(cx, cy + 0.5, rx + 2.2, ry + 2.0):
        f.glow(x, y, alpha_px("lilac" if not zap else "yellow", 80 if not zap else 90))
    if zap:
        for i, (a0, ln) in enumerate(((200, 7), (330, 7), (20, 6), (150, 6), (270, 8))):
            if (i + zap) % 2 == 0 or zap == 2:
                a = math.radians(a0 + zap * 13)
                x0, y0 = cx + math.cos(a) * (rx - 1), cy + 1 - math.sin(a) * ry * 0.9
                bolt(f, x0, y0, x0 + math.cos(a) * ln, y0 - math.sin(a) * ln * 0.8, seed=i * 7 + zap)
    if extra:
        extra(f)
    c = f.render()
    # the bell and tentacles are see-through; the outline, face and sparks stay solid
    body = {p for p in bell if f.owner.get(p) == bid}
    translucent(c, body, 225 if not zap else 245, keep=("plum", "ink", "white", "pink", "yellow"))
    translucent(c, tpx, 200, keep=("yellow", "white"))
    return c


def jellyfish() -> list[Anim]:
    J = jelly_frame
    idle = [J(0.0, 0, wave=0), J(0.5, -1, wave=1), J(1.0, -1, wave=2, eyes="happy"), J(0.4, 0, wave=3)]
    run = [J(1.0, 0, lean=0.5, wave=0, trail=0.6), J(0.0, -2, lean=1, wave=1, trail=1.0), J(-0.4, -1, lean=1, wave=2, trail=0.8),
           J(0.6, 0, lean=0.5, wave=3, trail=0.5)]
    attack = [J(1.0, 0, lean=-1, eyes="squint", mouth="o", wave=1),
              J(-0.3, -1, lean=1, mouth="grin", wave=2, reach=1.0, extra=lambda f: _tip_sparks(f)),
              J(0.3, 0, lean=0.5, wave=3, reach=0.4)]
    hurt = [J(1.2, 1, lean=-1, eyes="squint", mouth="o", wave=0, extra=lambda f: stars(f, [(3, 2), (19, 1)])),
            J(0.8, 0, lean=-0.5, eyes="squint", mouth="o", wave=1)]
    zap = [J(1.0, 0, eyes="squint", mouth="o", wave=0, zap=1), J(-0.5, -1, eyes="zap", mouth="grin", wave=1, zap=2),
           J(0.2, 0, eyes="zap", mouth="grin", wave=2, zap=1)]
    return [anim("idle", idle, 6.0, True), anim("run", run, 8.0, True), anim("attack", attack, 12.0, False),
            anim("hurt", hurt, 6.0, False, [1.0, 3.0]), anim("zap", zap, 12.0, False)]


def _tip_sparks(f: Fig) -> None:
    for (x, y) in ((22, 18), (20, 21)):
        f.dots([(x, y)], "yellow")
        f.glow(x + 1, y, alpha_px("white", 200))
        f.glow(x, y - 1, alpha_px("yellow", 150))


# ---------------------------------------------------------------------------
# snowman 雪人兵 (24): two snowballs, a black wolf-head knit hat, twig arms, coal eyes, carrot nose
# ---------------------------------------------------------------------------

SNOW = Mat(["ash", "sky_l", "white", "white"], outline="night", lit="ash", sep="ash", sep_lit="sky_l")
KNIT = Mat(["ink", "navy", "iron", "slate"], outline="ink", lit="ink", sep="ink", sep_lit="navy")
TWIG = Mat(["umber", "brown_d", "brown"], outline="umber")
CARROT = Mat(["gold_d", "orange", "amber"], outline="brown_d")


def twig(f: Fig, x0: float, y0: float, x1: float, y1: float) -> None:
    """A thin twig arm with a forked hand (three little fingers), no outline."""
    px = {}
    for p in line_px(x0, y0, x1, y1):
        px[p] = "brown"
    a = math.atan2(y1 - y0, x1 - x0)
    for d in (-0.8, 0.0, 0.8):
        tx, ty = x1 + math.cos(a + d) * 1.9, y1 + math.sin(a + d) * 1.9
        for p in line_px(x1, y1, tx, ty):
            px.setdefault(p, "brown_d")
    mx, my = x0 + (x1 - x0) * 0.55, y0 + (y1 - y0) * 0.55
    px[(int(round(mx + math.cos(a - 1.3) * 1.2)), int(round(my + math.sin(a - 1.3) * 1.2)))] = "brown_d"
    f.pix(px, TWIG, outline=False)


def snowman_frame(bob: int = 0, lean: float = 0.0, squash: float = 0.0, arm="rest", eyes: str = "open",
                  mouth: str = "smile", hat_tilt: int = 0, ball=None, extra=None) -> Fig:
    f = Fig(24, 24, seed=151)
    cx = 11.0 + lean
    rb = 5.0
    by = GROUND24 + 0.6 - (rb - squash * 0.3)     # bottom ball centre: its lowest row is always GROUND24
    hx, hy = cx + 0.8 + lean * 0.4, by - 8.0 + bob + squash
    # far twig arm (behind)
    far = {"rest": (cx - 8.5, by - 6.5), "throw": (cx - 7.5, by - 4.0), "swat": (cx - 8.0, by - 5.0),
           "up": (cx - 8.0, by - 9.0), "down": (cx - 8.0, by - 2.0)}[arm if isinstance(arm, str) else "rest"]
    twig(f, cx - 3.0, by - 3.5, far[0], far[1])
    # bottom ball (sits on the ground, a little wider when squashed)
    ball_b = {(x, y) for (x, y) in ellipse(cx, by, rb + squash * 0.6, rb - squash * 0.3) if y <= GROUND24}
    f.add(ball_b, SNOW, centre=(cx - 2, by - 2.5), radius=(rb + 1, rb + 1), bias=0.06)
    # coal buttons
    f.dots([(int(cx + 2), int(by - 1)), (int(cx + 2), int(by + 2))], "iron")
    f.dots([(int(cx + 2), int(by - 1))], "slate")
    # navy scarf between the balls, one end hanging behind
    scarf = ellipse(hx - 0.4, hy + 4.4, 4.6, 1.4)
    f.add(scarf, BANDANA, centre=(hx - 2, hy + 4), radius=(5, 2), bias=0.12)
    # head ball
    head = ellipse(hx, hy, 4.6, 4.3)
    f.add(head, SNOW, centre=(hx - 1.6, hy - 1.6), radius=(5.2, 4.8), bias=0.1)
    f.add(capsule(hx - 3.2, hy + 4.6, hx - 4.6 - lean * 0.6, hy + 7.2, 0.8), BANDANA, bias=0.0)
    f.recolor({(int(hx - 5 - lean * 0.6), int(hy + 7))}, "water")
    # black wolf-head knit hat: a beanie with two pointed wolf ears, a ribbed brim and a lilac wolf face
    t = hat_tilt
    hat = {(x, y) for (x, y) in ellipse(hx - 0.3, hy - 1.8, 4.8, 3.6) if y <= hy - 2.0}
    for (ex, d) in ((hx - 2.8, -1), (hx + 1.8, 1)):
        hat |= poly([(ex - 1.7, hy - 4.2), (ex + 0.4 * d + t * 0.5, hy - 8.6), (ex + 1.7, hy - 4.4)])
    f.add(hat, KNIT, centre=(hx - 2, hy - 5), radius=(5, 4), bias=0.12)
    brim = int(hy - 2)
    f.recolor({(x, brim) for x in range(int(hx - 6), int(hx + 6)) if x % 2} & hat, "iron")
    f.recolor({(x, brim) for x in range(int(hx - 6), int(hx + 6)) if not x % 2} & hat, "slate")
    f.recolor({(int(round(hx + 1.9 + t * 0.5)), int(hy - 7)), (int(round(hx + 1.9 + t * 0.5)), int(hy - 6))} & hat, "plum")
    wx, wy = int(round(hx + 0.5)), int(round(hy - 4))
    f.dots([(wx, wy), (wx + 2, wy)], "lilac")
    f.dots([(wx + 1, wy + 1)], "violet")
    # face: coal eyes, a long carrot nose pointing right, a coal-dot mouth
    ex, ey = int(round(hx + 0.5)), int(round(hy - 1))
    if eyes == "open":
        f.dots([(ex, ey), (ex, ey + 1), (ex + 3, ey), (ex + 3, ey + 1)], "ink")
        f.dots([(ex, ey), (ex + 3, ey)], "iron")
    elif eyes == "angry":
        f.dots([(ex, ey + 1), (ex + 3, ey + 1), (ex - 1, ey), (ex, ey), (ex + 3, ey), (ex + 4, ey)], "ink")
    elif eyes == "squint":
        f.dots([(ex - 1, ey), (ex, ey + 1), (ex - 1, ey + 2), (ex + 4, ey), (ex + 3, ey + 1), (ex + 4, ey + 2)], "ink")
    elif eyes == "happy":
        f.dots([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey + 1), (ex + 3, ey + 1), (ex + 4, ey), (ex + 5, ey + 1)], "ink")
    nose = poly([(hx + 2.4, hy + 0.9), (hx + 8.2, hy + 1.6), (hx + 2.4, hy + 2.5)])
    f.add(nose, CARROT, bias=0.15, sep=False)
    mx, my = ex, ey + 4
    if mouth == "smile":
        f.dots([(mx - 1, my), (mx, my + 1), (mx + 1, my + 1)], "iron")
    elif mouth == "o":
        f.dots([(mx, my), (mx, my + 1)], "iron")
    elif mouth == "shout":
        f.dots([(mx - 1, my), (mx, my), (mx - 1, my + 1), (mx, my + 1)], "iron")
    f.dots([(ex - 2, ey + 2)], "pink")
    # near twig arm (and the snowball in its hand)
    if isinstance(arm, tuple):
        hand = arm
    else:
        hand = {"rest": (cx + 9.5, by - 7.0), "swat": (cx + 10.5, by - 2.5), "up": (cx + 4.0, by - 13.5),
                "down": (cx + 9.0, by - 1.0), "throw": (cx - 6.0, by - 11.5)}[arm]
    twig(f, cx + 3.0, by - 3.5, hand[0], hand[1])
    if ball is not None:
        bx, by_ = ball
        f.add(ellipse(bx, by_, 1.9, 1.9), SNOW, bias=0.15)
    if extra:
        extra(f)
    return f


def _snow_puff(f: Fig, pts) -> None:
    for (x, y) in pts:
        for (dx, dy) in ((0, 0), (1, 0), (0, -1)):
            f.glow(x + dx, y + dy, alpha_px("white", 200 if dx == 0 and dy == 0 else 130))


def snowman() -> list[Anim]:
    S = snowman_frame
    idle = [S(), S(squash=0.6, bob=0), S(squash=1.0, bob=1, eyes="happy"), S(squash=0.4)]
    run = [S(lean=0.5, squash=1.2, arm="down", hat_tilt=-1, extra=lambda f: _snow_puff(f, [(3, 20)])),
           S(lean=1, squash=-0.4, bob=-2, arm="rest", hat_tilt=-2, mouth="o"),
           S(lean=0.5, squash=1.2, arm="down", hat_tilt=-1, extra=lambda f: _snow_puff(f, [(2, 19), (4, 20)])),
           S(lean=1, squash=-0.4, bob=-2, arm="rest", hat_tilt=-2)]
    attack = [S(lean=-1, arm="up", eyes="angry", mouth="shout", hat_tilt=1),
              S(lean=1.5, arm="swat", eyes="angry", mouth="shout", extra=lambda f: _swat_smear(f)),
              S(lean=1, arm="down", eyes="angry"),
              S(lean=0.5, arm="rest")]
    hurt = [S(lean=-1, squash=1, eyes="squint", mouth="o", hat_tilt=2, arm="up",
              extra=lambda f: (stars(f, [(5, 2), (19, 3)]), _snow_puff(f, [(2, 10), (21, 13)]))),
            S(lean=-0.5, eyes="squint", mouth="o", hat_tilt=1)]
    throw = [S(lean=-1, squash=0.6, arm="throw", ball=(4.0, 4.0), eyes="angry", mouth="shout", hat_tilt=1),
             S(lean=0.5, bob=-1, arm=(16.5, 2.5), ball=(17.5, 1.5), eyes="angry", mouth="shout"),
             S(lean=1.5, squash=0.8, arm="swat", eyes="open", mouth="o",
               extra=lambda f: (f.add(ellipse(21.0, 4.5, 1.8, 1.8), SNOW, bias=0.15), _snow_puff(f, [(18, 6), (17, 3)])))]
    return [anim("idle", R(idle), 5.0, True), anim("run", R(run), 10.0, True),
            anim("attack", R(attack), 14.0, False, [0.8, 1.0, 1.0, 0.8]),
            anim("hurt", R(hurt), 6.0, False, [1.0, 3.0]), anim("throw", R(throw), 10.0, False, [1.4, 0.8, 1.2])]


def _swat_smear(f: Fig) -> None:
    for i in range(5):
        a = math.radians(70 - i * 25)
        for d in (8, 9):
            f.glow(int(round(13 + math.cos(a) * d)), int(round(13 - math.sin(a) * d)), alpha_px("white", 150 + d * 8))


# ---------------------------------------------------------------------------
# salamander 火蜥蜴 (24): a low orange lizard, yellow belly, a little flame on the tail tip
# ---------------------------------------------------------------------------

LIZARD = Mat(["red_d", "orange", "amber", "yellow"], outline="wine", lit="red_d", sep="red_d", sep_lit="orange")
LIZARD_FAR = Mat(["wine", "red_d", "orange", "amber"], outline="wine", lit="wine", sep="wine", sep_lit="red_d")
FIRE_RAMP = ["red", "orange", "yellow", "white"]


def small_flame(c: Canvas, x: float, y: float, r: float, k: int, ramp=FIRE_RAMP, outline: str = "red_d",
                lean: float = 0.0) -> None:
    """A little flame drawn straight onto a canvas: round base at (x, y), flickering tip above (k = frame)."""
    sway = (0, 1, 0, -1)[k % 4] + lean
    tip = (x + sway * 0.8 - 0.5, y - r * 2.4 - (k % 2) * 0.6)
    shape = ellipse(x, y, r, r * 0.95) | poly([(x - r * 0.9, y - r * 0.1), (tip[0], tip[1]), (x + r * 0.9, y - r * 0.2)])
    shape = {(px, py) for (px, py) in shape if 0 <= px < c.w and 0 <= py < c.h}
    tips, rim, body, core = ramp
    edge = P.edge(shape)
    for (px, py) in shape:
        if (px, py) in edge:
            c.set(px, py, rim if py >= y - r * 0.6 else tips)
        else:
            c.set(px, py, body)
    for (px, py) in ellipse(x - 0.2, y + r * 0.2, r * 0.5, r * 0.45):
        if (px, py) in shape and (px, py) not in edge:
            c.set(px, py, core)
    ring = set()
    for (px, py) in shape:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (px + dx, py + dy) not in shape:
                ring.add((px + dx, py + dy))
    for (px, py) in ring:
        if c.get(px, py) is None:
            c.set(px, py, outline)


def lizard_frame(legs=((0, 0), (0, 0), (0, 0), (0, 0)), bob: int = 0, lean: float = 0.0, stretch: float = 0.0,
                 head_dy: float = 0.0, eyes: str = "open", mouth: str = "smile", tail: float = 0.0, flame: int = 0,
                 flame_r: float = 1.9, extra=None, post=None) -> Canvas:
    """legs: (dx, lift) for back-far, front-far, back-near, front-near."""
    f = Fig(24, 24, seed=161)
    L = stretch
    cx, cy = 11.5 + lean, 17.6 + bob
    # tail: from the hips back along the ground, then curling up; the flame burns on its tip
    ta = math.radians(105 - tail * 35 + L * 25)
    bx0, by0 = cx - 3.6 - L * 0.3, cy
    mx, my = bx0 - 3.0, cy + 0.8
    tx, ty = mx + math.cos(ta) * 4.2 - 0.4, my - math.sin(ta) * 4.2
    f.add(union(capsule(bx0, by0, mx, my, 1.5), capsule(mx, my, tx, ty, 0.9)), LIZARD, centre=(mx, my - 2),
          radius=(4, 3), bias=0.05)

    def leg(x, dx, lift, mat, bias):
        foot = GROUND24 - lift
        s = union(capsule(x, cy + 1.5, x + dx * 0.6, foot - 0.8, 0.9), {(int(round(x + dx)) + k, foot) for k in (0, 1, 2)})
        f.add(s, mat, mode="cyl_v", bias=bias)
    (b0, b1), (f0, f1), (b2, b3), (f2, f3) = legs
    leg(cx - 2.2 - L * 0.5, b0, b1, LIZARD_FAR, -0.2)
    leg(cx + 3.0 + L * 0.5, f0, f1, LIZARD_FAR, -0.2)
    # body: a long low torso, a yellow belly underneath and red spots along the back
    body = union(ellipse(cx - L * 0.3, cy, 4.3 + L * 0.6, 2.7), ellipse(cx + 2.6 + L * 0.5, cy - 0.4, 2.6, 2.6))
    f.add(body, LIZARD, centre=(cx - 1, cy - 2.5), radius=(5.5 + L, 4), bias=0.08)
    f.recolor({(x, y) for (x, y) in body if y >= cy + 1.6}, "gold_l")
    for (sx, sy) in ((cx - 2.2 - L * 0.5, cy - 1), (cx + 1.2 + L * 0.3, cy - 1)):
        f.recolor({(int(round(sx)), int(round(sy))), (int(round(sx)) + 1, int(round(sy)))} & body, "red")
    leg(cx - 1.2 - L * 0.5, b2, b3, LIZARD, -0.05)
    leg(cx + 4.0 + L * 0.5, f2, f3, LIZARD, -0.05)
    # head: round with a wide smiling mouth; a big eye on top
    hx, hy = cx + 6.6 + L * 0.8, cy - 2.2 + head_dy
    head = union(ellipse(hx, hy, 3.6, 2.9), ellipse(hx + 2.2, hy + 0.8, 2.4, 1.9))
    f.add(head, LIZARD, centre=(hx - 1, hy - 1.5), radius=(4, 3.2), bias=0.12)
    f.recolor({(x, y) for (x, y) in head if y >= hy + 1.6}, "gold_l")
    hxi, hyi = int(round(hx)), int(round(hy))
    ex, ey = hxi, hyi - 2
    f.add(ellipse(ex + 0.5, ey + 0.5, 1.8, 1.7), LIZARD, bias=0.2)      # eye bump on the head
    if eyes == "open":
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], "umber")
        f.dot(ex, ey, "white")
    elif eyes == "focus":
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], "umber")
        f.dot(ex + 1, ey, "white")
        f.dots([(ex - 1, ey - 1), (ex, ey - 1)], "wine")
    elif eyes == "squint":
        f.dots([(ex - 1, ey), (ex, ey + 1), (ex + 1, ey + 1), (ex + 2, ey)], "umber")
    elif eyes == "happy":
        f.dots([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1)], "umber")
    f.dot(hxi + 4, hyi, "wine")                                          # nostril
    mx, my = hxi + 1, hyi + 1
    if mouth == "smile":
        f.dots([(mx, my), (mx + 1, my + 1), (mx + 2, my + 1), (mx + 3, my + 1)], "wine")
    elif mouth == "open":
        f.dots([(mx, my), (mx + 1, my + 1), (mx + 2, my + 1), (mx + 3, my + 1), (mx + 4, my + 1)], "wine")
        f.dots([(mx + 1, my + 2), (mx + 2, my + 2), (mx + 3, my + 2)], "wine")
        f.dots([(mx + 2, my + 2)], "pink")
    elif mouth == "o":
        f.dots([(mx + 2, my + 1), (mx + 3, my + 1)], "wine")
    f.dot(hxi - 1, hyi + 1, "pink")
    if extra:
        extra(f)
    c = f.render()
    small_flame(c, tx + 0.3, ty - 1.6, flame_r, flame, lean=-L * 0.8 - (1 if tail < 0 else 0))
    for (x, y) in P.ellipse(tx + 0.3, ty - 3.0, flame_r + 2.2, flame_r + 2.6):
        if c.get(x, y) is None:
            c.set(x, y, alpha_px("amber", 60))
    if post:
        post(c)
    return c


def _flame_bits(c: Canvas, pts) -> None:
    for i, (x, y) in enumerate(pts):
        c.set(x, y, alpha_px("orange" if i % 2 else "yellow", 220))
        c.set(x, y - 1, alpha_px("red", 140))


def salamander() -> list[Anim]:
    Z = lizard_frame
    idle = [Z(flame=0, flame_r=2.1), Z(flame=1, tail=0.15, flame_r=2.3), Z(flame=2, tail=0.25, eyes="happy", flame_r=2.1),
            Z(flame=3, tail=0.1, flame_r=2.3)]
    gait = [((-1, 0), (1, 1), (1, 1), (-1, 0)), ((0, 0), (0, 0), (0, 0), (0, 0)),
            ((1, 1), (-1, 0), (-1, 0), (1, 1)), ((0, 0), (0, 0), (0, 0), (0, 0))]
    run = [Z(legs=gait[i], bob=-(i % 2), lean=0.5, tail=-0.4 + 0.3 * (i % 2), flame=i, head_dy=-(i % 2) * 0.5,
             mouth="open" if i == 0 else "smile") for i in range(4)]
    attack = [Z(lean=-1.5, head_dy=0.5, eyes="focus", mouth="smile", tail=0.4, flame=0),
              Z(lean=2.0, stretch=1.0, head_dy=-0.5, eyes="focus", mouth="open", tail=-0.4, flame=1,
                legs=((-2, 0), (2, 1), (-2, 0), (2, 1))),
              Z(lean=1.5, stretch=0.5, eyes="open", mouth="open", flame=2),
              Z(lean=0.5, flame=3)]
    hurt = [Z(lean=-1.5, head_dy=-0.5, eyes="squint", mouth="o", tail=0.6, flame=0, flame_r=1.4,
              extra=lambda f: stars(f, [(13, 7), (21, 6)])),
            Z(lean=-1, eyes="squint", mouth="o", tail=0.4, flame=1, flame_r=1.5)]
    dash = [Z(legs=((-3, 1), (3, 1), (-3, 0), (3, 1)), stretch=1.6, lean=0.4, head_dy=0.5, eyes="focus", mouth="open",
              tail=0.3, flame=0, flame_r=2.0, extra=lambda f: speed_lines(f, [(0, 14), (1, 17), (0, 20)], 0),
              post=lambda c: _flame_bits(c, [(0, 13), (2, 15)])),
            Z(legs=((-3, 0), (3, 1), (-3, 1), (3, 0)), stretch=1.6, lean=0.4, bob=-1, head_dy=0.5, eyes="focus",
              mouth="open", tail=0.35, flame=1, flame_r=2.0, extra=lambda f: speed_lines(f, [(0, 13), (1, 16), (0, 19)], 1),
              post=lambda c: _flame_bits(c, [(1, 12), (0, 16)]))]
    return [anim("idle", idle, 6.0, True), anim("run", run, 12.0, True),
            anim("attack", attack, 14.0, False, [0.8, 1.0, 1.0, 0.8]),
            anim("hurt", hurt, 6.0, False, [1.0, 3.0]), anim("dash", dash, 12.0, True)]


# ---------------------------------------------------------------------------
# lantern_wisp 提燈鬼火 (16): a small teal ghost-flame carrying a lantern
# ---------------------------------------------------------------------------

WISP_RAMP = ["teal", "teal", "azure", "white"]


def wisp_frame(sway: float = 0.0, bob: int = 0, lean: float = 0.0, r: float = 4.2, eyes: str = "open",
               mouth: str = "smile", lamp=(0, 0), swing: int = 0, light: int = 1, stars_at=(), heal: int = 0) -> Canvas:
    c = Canvas(16, 16)
    cx, cy = 7.0 + lean, 8.0 + bob
    # lantern light glow (behind everything)
    lx, ly = int(round(cx + 4.5 + lamp[0] + swing)), int(round(cy + 4.5 + lamp[1]))
    glow_r = 2 + light
    for (x, y) in P.ellipse(lx + 0.5, ly + 1.5, glow_r + 1.5, glow_r + 1.2):
        c.set(x, y, alpha_px("amber" if heal < 2 else "yellow", 45 + 15 * light))
    for (x, y) in P.ellipse(cx, cy, r + 2.2, r + 2.0):
        if c.get(x, y) is None:
            c.set(x, y, alpha_px("haze", 50))
    # the ghost flame: a round body with three flame licks on top (the tallest flicks back) and a wispy
    # ghost tail trailing down-back
    body = ellipse(cx, cy, r, r * 0.95)
    tip = (cx - 1.8 - lean * 1.2 + sway, cy - r - 3.6 + abs(sway) * 0.3)
    licks = poly([(cx - r * 0.95, cy - r * 0.1), (cx - r * 0.2, cy - r * 0.85), tip])
    licks |= poly([(cx - r * 0.1, cy - r * 0.8), (cx + 0.9 + sway * 0.4, cy - r - 1.9), (cx + r * 0.6, cy - r * 0.6)])
    licks |= poly([(cx + r * 0.45, cy - r * 0.7), (cx + r * 0.8 + sway * 0.3, cy - r - 0.6), (cx + r * 0.9, cy - r * 0.2)])
    wisp = poly([(cx - r * 0.75, cy + r * 0.45), (cx - r - 2.2 - sway * 0.4, cy + r + 0.8 - abs(sway) * 0.3),
                 (cx + r * 0.1, cy + r * 0.9)])
    tail = licks | wisp
    shape = {(x, y) for (x, y) in body | tail if 0 <= x < 16 and 0 <= y < 16}
    tips, rim, mid, core = WISP_RAMP
    edge = P.edge(shape)
    for (x, y) in shape:
        if (x, y) not in body:
            c.set(x, y, tips if (x, y) in edge else "sky")
        elif (x, y) in edge:
            c.set(x, y, rim if y + 0.5 > cy - r * 0.3 else "sky")
        else:
            c.set(x, y, mid)
    for (x, y) in ellipse(cx - 0.6, cy + r * 0.2, r * 0.62, r * 0.5):
        if (x, y) in shape and (x, y) not in edge:
            c.set(x, y, "haze")
    for (x, y) in ellipse(cx - 1.0, cy + r * 0.3, r * 0.32, r * 0.26):
        if (x, y) in shape and (x, y) not in edge:
            c.set(x, y, core)
    ring = set()
    for (x, y) in shape:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in shape:
                ring.add((x + dx, y + dy))
    for (x, y) in ring:
        c.set(x, y, "deep")
    translucent(c, {p for p in shape if p not in body}, 215, keep=())
    # face
    fx, fy = int(round(cx + 1)), int(round(cy - 1))
    if eyes == "open":
        for x0 in (fx - 1, fx + 2):
            c.set(x0, fy, "deep")
            c.set(x0, fy + 1, "deep")
    elif eyes == "happy":
        for x0 in (fx - 1, fx + 2):
            c.set(x0 - 1, fy + 1, "deep"); c.set(x0, fy, "deep"); c.set(x0 + 1, fy + 1, "deep")
    elif eyes == "squint":
        c.set(fx - 1, fy, "deep"); c.set(fx, fy + 1, "deep"); c.set(fx - 1, fy + 2, "deep")
        c.set(fx + 3, fy, "deep"); c.set(fx + 2, fy + 1, "deep"); c.set(fx + 3, fy + 2, "deep")
    if mouth == "smile":
        c.set(fx, fy + 3, "teal"); c.set(fx + 1, fy + 3, "teal")
    elif mouth == "o":
        c.set(fx + 1, fy + 3, "deep")
    c.set(fx - 2, fy + 2, "pink")
    c.set(fx + 4, fy + 2, "pink")
    # a tiny arm holding the lantern's ring, and the lantern: gold cap, glowing glass, gold base
    ax, ay = int(round(cx + r * 0.6)), int(round(cy + 1))
    for p in line_px(ax, ay, lx, ly - 1):
        if c.get(*p) is None or p == (lx, ly - 1):
            c.set(p[0], p[1], "gold_d")
    lamp_px = {(lx - 1, ly): "gold", (lx, ly): "gold", (lx + 1, ly): "gold_d",
               (lx - 1, ly + 1): "yellow" if light else "amber", (lx, ly + 1): "white" if light else "yellow",
               (lx + 1, ly + 1): "amber",
               (lx - 1, ly + 2): "amber", (lx, ly + 2): "yellow" if light else "amber", (lx + 1, ly + 2): "orange",
               (lx - 1, ly + 3): "gold_d", (lx, ly + 3): "gold_d", (lx + 1, ly + 3): "brown_d"}
    for (x, y), col in lamp_px.items():
        c.set(x, y, col)
    for (x, y) in ((lx - 2, ly + 1), (lx - 2, ly + 2), (lx + 2, ly + 1), (lx + 2, ly + 2), (lx - 1, ly - 1),
                   (lx + 1, ly - 1), (lx, ly + 4), (lx - 1, ly + 4), (lx + 1, ly + 4)):
        if c.get(x, y) is None or c.get(x, y)[3] < 255:
            c.set(x, y, "umber")
    if heal:
        rr = 3 + heal * 2
        for i in range(12):
            a = i * math.pi / 6
            x, y = int(round(lx + math.cos(a) * rr)), int(round(ly + 1.5 + math.sin(a) * rr * 0.8))
            if 0 <= x < 16 and 0 <= y < 16 and (c.get(x, y) is None or c.get(x, y)[3] < 255):
                c.set(x, y, alpha_px("yellow" if heal == 1 else "leaf_l", 220 if i % 2 else 150))
        for (px_, py_) in ((2, 3), (13, 2)) if heal == 2 else ((3, 12),):
            for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                c.set(px_ + dx, py_ + dy, "leaf_l" if (dx, dy) != (0, 0) else "white")
    for (x, y) in stars_at:
        for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            c.set(x + dx, y + dy, "yellow")
        c.set(x, y, "white")
    return c


def lantern_wisp() -> list[Anim]:
    W = wisp_frame
    idle = [W(0.0, swing=0), W(1.0, bob=-1, swing=0, light=2), W(1.6, bob=-1, swing=-1, light=1, eyes="happy"),
            W(0.6, swing=-1, light=2)]
    run = [W(-1.0, lean=0.5, eyes="happy", swing=-1), W(-2.0, bob=-1, lean=1, eyes="happy", swing=-1, light=2),
           W(-1.4, lean=0.5, eyes="happy", swing=-1), W(-2.4, bob=-1, lean=1, eyes="happy", swing=-1, light=2)]
    attack = [W(1.0, lean=-1, eyes="squint", mouth="o", lamp=(-2, -2), light=1),
              W(-2.0, lean=1, mouth="o", lamp=(1, -3), light=3),
              W(0.0, lean=0.5, lamp=(0, -1), light=2)]
    hurt = [W(2.0, r=3.8, lean=-1, eyes="squint", mouth="o", light=0, swing=1, stars_at=[(3, 2)]),
            W(1.0, r=4.0, eyes="squint", mouth="o", light=0, swing=1)]
    heal = [W(0.5, bob=-1, lamp=(-1, -3), light=2, eyes="happy", heal=0),
            W(1.0, bob=-1, lamp=(-1, -3), light=3, eyes="happy", heal=1),
            W(0.5, bob=-1, lamp=(-1, -3), light=3, eyes="happy", heal=2)]
    return [anim("idle", idle, 8.0, True), anim("run", run, 10.0, True), anim("attack", attack, 12.0, False),
            anim("hurt", hurt, 6.0, False, [1.0, 3.0]), anim("heal", heal, 8.0, False, [1.0, 1.0, 1.0])]


# ---------------------------------------------------------------------------
# shadow_knight 影子騎士 (32): dark indigo armoured shadow, glowing eyes, a big tower shield
# ---------------------------------------------------------------------------

SHADE = Mat(["navy", "night_d", "night_d", "night"], outline="ink", lit="navy", sep="ink", sep_lit="navy")
SHADE_FAR = Mat(["ink", "navy", "navy", "night_d"], outline="ink", lit="ink", sep="ink", sep_lit="navy")
TOWER_RIM = Mat(["iron", "slate", "steel_d", "steel"], outline="ink", lit="navy", spec="steel_l", spec_at=0.86)
TOWER_FACE = Mat(["night_d", "night", "night", "dusk"], outline="ink", lit="navy", sep="ink", sep_lit="night_d")


def rim_lit(f: Fig, shape: set, col: str = "dusk", skip: int = 3, k: int = 0) -> None:
    """Violet rim on the top-left edge of a shadow part (the glow of the curse), every few pixels left dark."""
    f.recolor({(x, y) for (x, y) in shape if ((x, y - 1) not in shape or (x - 1, y) not in shape)
               and (x + y + k) % skip != 0}, col)
SHADE_BLADE = Mat(["steel_d", "steel", "steel_l", "white"], outline="navy", lit="iron")
LEATHER_D = Mat(["umber", "brown_d", "brown"], outline="ink")


def wolf_sigil(f: Fig, x: int, y: int, col: str = "lilac", eye: str = "white", mirror: bool = False) -> None:
    """The black wolf's head of Mordred's army, 5x5, facing right: two ears, a snout and an eye."""
    rows = ["x.x..", "xxx..", "xxxxx", ".xxx.", "..x.."]
    for j, row in enumerate(rows):
        if mirror:
            row = row[::-1]
        for i, ch in enumerate(row):
            if ch == "x":
                f.dot(x + i, y + j, col)
    f.dot(x + (3 if mirror else 1), y + 2, eye)


def tower_shield(f: Fig, x0: float, y0: float, w: int = 8, h: int = 15, sigil: bool = True) -> None:
    """A tall tower shield with a rounded top: dark steel rim, indigo face, a glowing wolf sigil."""
    xi, yi = int(round(x0)), int(round(y0))
    outer = union(rect(xi, yi + 2, w, h - 2), ellipse(xi + w / 2, yi + 2.5, w / 2, 2.5))
    inner = {(x, y) for (x, y) in outer if (x - 1, y) in outer and (x + 1, y) in outer and (x, y - 1) in outer
             and (x, y + 1) in outer}
    f.add(outer - inner, TOWER_RIM, centre=(xi + 1, yi + 2), radius=(w, h * 0.6), bias=0.05)
    f.add(inner, TOWER_FACE, centre=(xi + 2, yi + 3), radius=(w * 0.8, h * 0.7), bias=0.05, sep=False)
    f.recolor({(xi + w // 2, y) for y in range(yi + 3, yi + h - 1)} & inner, "navy")
    if sigil:
        wolf_sigil(f, xi + w // 2 - 2, yi + h // 2 - 3, "violet", "lilac")
    for (x, y) in ((xi + 1, yi + 3), (xi + w - 2, yi + 3), (xi + 1, yi + h - 2), (xi + w - 2, yi + h - 2)):
        f.dot(x, y, "steel")


def shadow_wisps(f: Fig, pts, k: int) -> None:
    for i, (wx, wy) in enumerate(pts):
        j = (i + k) % 3
        x0, y0 = int(round(wx - j * 0.5)), int(round(wy - j))
        f.glow(x0, y0, alpha_px("dusk", 200 - j * 40))
        f.glow(x0 - 1, y0 - 1, alpha_px("violet", 150 - j * 30))
        f.glow(x0 - 1, y0 - 2, alpha_px("lilac", 80))


def sk_frame(bob: int = 0, lean: float = 0.0, legs=((0, 0.0), (0, 0.0)), shield=None, hand=None,
             sword_deg: float = -28.0, eyes: str = "open", head_dy: int = 0, wisp: int = 0, crouch: int = 0,
             extra=None) -> Fig:
    f = Fig(32, 32, seed=171)
    cx, by = 12.5 + lean, 20.0 + bob + crouch
    hx, hy = cx + 1.5, by - 9.5 + head_dy
    # legs: armoured greaves with pointed sabatons
    (fl, fdx), (nl, ndx) = legs
    for (x, lift, dx, far) in ((cx - 2.5, fl, fdx, True), (cx + 2.0, nl, ndx, False)):
        foot = GROUND32 - lift
        s = union(rect(int(round(x + dx * 0.5)) - 1, int(by + 3), 3, int(foot - by - 4)),
                  capsule(x, by + 3, x + dx, foot - 1.5, 1.5))
        f.add(s, SHADE_FAR if far else SHADE, mode="cyl_v", bias=-0.1 if far else 0.0)
        px_ = int(round(x + dx))
        f.add(union(rect(px_ - 1, foot - 1, 4, 2), {(px_ + 3, foot)}), SHADE_FAR if far else SHADE, flat=1 if far else 2)
    # torso: plate over a tattered shadow skirt
    skirt = poly([(cx - 5, by), (cx + 5, by), (cx + 6, by + 5), (cx + 3, by + 4), (cx + 1, by + 6), (cx - 2, by + 4),
                  (cx - 4, by + 6), (cx - 6, by + 4)])
    f.add(skirt, SHADE_FAR, bias=0.05)
    torso = union(ellipse(cx, by - 1.5, 5.6, 4.6), rect(int(cx - 5), int(by - 1), 11, 3))
    f.add(torso, SHADE, centre=(cx - 1.5, by - 3.5), radius=(6.5, 5.5), bias=0.06)
    rim_lit(f, torso, "dusk", 3, wisp)
    f.recolor({(x, int(by + 1)) for x in range(int(cx - 6), int(cx + 6))} & torso, "ink")
    f.recolor({(int(cx), int(by + 1)), (int(cx + 1), int(by + 1))}, "violet")
    # helm: a rounded bucket helm with a glowing visor slit and a small crest
    helm = union(ellipse(hx, hy, 5.2, 5.0), rect(int(hx - 5), int(hy), 10, 4))
    f.add(helm, SHADE, centre=(hx - 2, hy - 2.5), radius=(6, 6), bias=0.1)
    rim_lit(f, helm, "dusk", 3, wisp)
    # a flickering shadow plume instead of a crest
    for i, (px_, py_) in enumerate(((hx - 3, hy - 5), (hx - 4, hy - 6), (hx - 5 - wisp % 2, hy - 7),
                                    (hx - 6 - wisp % 2, hy - 8), (hx - 2, hy - 6), (hx - 3, hy - 7 - wisp % 2))):
        f.glow(int(round(px_)), int(round(py_)), alpha_px("violet" if i % 2 else "dusk", 230 - i * 20))
    vy = int(round(hy))
    f.recolor({(x, vy) for x in range(int(hx - 1), int(hx + 6))} | {(x, vy + 1) for x in range(int(hx), int(hx + 6))}, "ink")
    exs = (int(hx + 1), int(hx + 4))
    if eyes == "open":
        f.dots([(exs[0], vy), (exs[1], vy), (exs[0], vy + 1), (exs[1], vy + 1)], "lilac")
        f.dots([(exs[0], vy), (exs[1], vy)], "white")
        for (gx, gy) in ((exs[1] + 2, vy), (exs[1] + 2, vy - 1), (exs[0] - 1, vy - 1)):
            f.glow(gx, gy, alpha_px("violet", 130))
    elif eyes == "squint":
        f.dots([(exs[0] - 1, vy), (exs[0], vy + 1), (exs[1], vy + 1), (exs[1] + 1, vy)], "lilac")
    elif eyes == "dizzy":
        f.dots([(exs[0], vy), (exs[1], vy + 1), (exs[0] + 1, vy + 1), (exs[1] + 1, vy)], "lilac")
    f.recolor({(x, int(hy - 2)) for x in range(int(hx - 1), int(hx + 5))} & helm, "night")
    # the tower shield (far arm, held in front of the body)
    sx, sy = shield if shield else (cx + 4.0, by - 9.0)
    tower_shield(f, sx, sy)
    # near arm with the sword
    if hand is None:
        hand = (cx + 2.0, by + 2.5)
    f.add(union(capsule(cx + 1.0, by - 3.5, hand[0], hand[1], 1.4), ellipse(hand[0], hand[1], 1.6, 1.5)), SHADE,
          bias=0.12)
    a = math.radians(sword_deg)
    gx, gy = hand[0] + math.cos(a) * 1.2, hand[1] - math.sin(a) * 1.2
    f.pix({(int(round(hand[0] - math.cos(a) * k)), int(round(hand[1] + math.sin(a) * k))): "brown_d" for k in (1, 2)},
          LEATHER_D)
    f.pix({(int(round(gx - math.sin(a) * k)), int(round(gy - math.cos(a) * k))): "steel" for k in (-1, 0, 1)}, TOWER_RIM)
    f.pix(blade(gx + math.cos(a) * 1.0, gy - math.sin(a) * 1.0, -a, 9, 2, light="steel_l", mid="steel", dark="steel_d"),
          SHADE_BLADE)
    f.add(ellipse(cx + 1.0, by - 4.0, 2.4, 2.0), SHADE, bias=0.15)
    shadow_wisps(f, ((cx - 4, by - 6), (hx - 4, hy - 7), (cx + 3, by - 7), (cx - 6, by + 3)), wisp)
    if extra:
        extra(f)
    return f


def sk_down(k: int) -> Canvas:
    """Kneels dizzy, then the shadow crumbles into a little pile of autumn leaves (never hurt)."""
    kneel = sk_frame(bob=3, lean=-1, legs=((0, 2.0), (0, -1.0)), shield=(17.0, 14.0), hand=(17.0, 24.0), sword_deg=-20,
                     eyes="dizzy", head_dy=2, wisp=k,
                     extra=lambda f: stars(f, [(10, 5), (22, 4)]) if k == 0 else None).render()
    if k == 0:
        return kneel
    rng = random.Random(70 + k)
    if k == 1:
        c = dissolve(kneel, 0.6, seed=k)
        spots = [(rng.randrange(6, 26), rng.randrange(12, 28)) for _ in range(10)]
    elif k == 2:
        c = Canvas(32, 32)
        spots = [(int(16 + math.cos(t) * rng.uniform(0, 9)), int(26 + math.sin(t) * rng.uniform(0, 2.2)) - 1)
                 for t in [rng.uniform(0, 2 * math.pi) for _ in range(20)]]
        spots += [(rng.randrange(8, 24), rng.randrange(14, 24)) for _ in range(8)]
    else:
        c = Canvas(32, 32)
        spots = [(rng.randrange(5, 27), rng.randrange(26, 29)) for _ in range(8)]
    for i, (x, y) in enumerate(spots):
        autumn_leaf(c, x, y, rng.randrange(0, 24), 255 if k < 3 or i % 2 else 190)
    return c


def shadow_knight() -> list[Anim]:
    K = sk_frame
    idle = [K(wisp=0), K(bob=1, wisp=1), K(bob=1, wisp=2), K(wisp=3)]
    run_legs = [((0, -2.5), (0, 2.5)), ((1, -1.0), (0, 1.0)), ((2, 0.5), (0, -1.5)),
                ((0, 2.5), (0, -2.5)), ((0, 1.0), (1, -1.0)), ((0, -1.5), (2, 0.5))]
    run_bob = [0, 1, -1, 0, 1, -1]
    run = [K(bob=run_bob[i], lean=0.5, legs=run_legs[i], wisp=i, hand=(15.5, 22.0 + run_bob[i]), sword_deg=-35)
           for i in range(6)]
    attack = [K(lean=-1.5, hand=(9.0, 17.0), sword_deg=10, shield=(16.0, 11.0)),
              K(lean=1.5, hand=(23.0, 17.5), sword_deg=0, shield=(14.0, 11.0), legs=((0, -2.0), (0, 2.5)),
                extra=lambda f: speed_lines(f, [(2, 14), (1, 18), (3, 22)], 0)),
              K(lean=1.0, hand=(21.0, 18.5), sword_deg=-10, shield=(15.0, 11.0)),
              K(lean=0.5)]
    hurt = [K(lean=-1.5, head_dy=1, eyes="squint", shield=(15.0, 12.0), extra=lambda f: stars(f, [(8, 3), (20, 2)])),
            K(lean=-1.0, eyes="squint", shield=(15.5, 11.5))]
    guard = [K(crouch=1, lean=-0.5, shield=(19.0, 9.0), hand=(13.0, 21.0), sword_deg=-155, head_dy=1, wisp=0,
               legs=((0, -1.0), (0, 2.0))),
             K(crouch=1, lean=-0.5, shield=(19.0, 9.0), hand=(13.0, 21.0), sword_deg=-155, head_dy=1, wisp=1,
               legs=((0, -1.0), (0, 2.0)), extra=lambda f: _shield_glint(f, 20, 10))]
    down = [sk_down(k) for k in range(4)]
    return [anim("idle", R(idle), 5.0, True), anim("run", R(run), 12.0, True),
            anim("attack", R(attack), 14.0, False, [0.8, 1.0, 1.0, 0.8]),
            anim("hurt", R(hurt), 6.0, False, [1.0, 3.0]), anim("guard", R(guard), 4.0, True),
            anim("down", down, 4.0, False, [1.2, 1.0, 1.0, 0.8])]


def _shield_glint(f: Fig, x: int, y: int) -> None:
    for (dx, dy) in ((0, 0), (1, 1), (2, 2)):
        f.dot(x + dx, y + dy + 2, "steel_l")


# ---------------------------------------------------------------------------
# tristan 崔斯坦 (32): corgi bard knight - short legs, huge ears, light-blue cape, feathered cap, wooden harp
# ---------------------------------------------------------------------------

CORGI = Mat(["brown", "gold_d", "orange", "amber"], outline="umber", lit="brown_d", fur=0.1, sep="brown",
            sep_lit="gold_d")
CORGI_W = Mat(["sand", "cream", "white"], outline="brown_d", lit="brown", fur=0.06, sep="dirt", sep_lit="sand")
SKY_CAPE = Mat(["water", "sky", "azure", "sky_l"], outline="water_d", lit="water", sep="water", sep_lit="sky")
CAP = Mat(["night", "water_d", "water", "sky"], outline="navy", lit="night")
FEATHER = Mat(["red_d", "red", "coral", "pink"], outline="wine", lit="red_d")
HARP = Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber", sep="umber", sep_lit="brown_d")
TUNIC_G = Mat(["forest", "leaf_d", "grass", "leaf"], outline="forest_d", lit="forest", sep="forest", sep_lit="leaf_d")


def harp(f: Fig, x: float, y: float, s: float = 1.0, strum: int = -1) -> None:
    """A small wooden lap harp; (x, y) is the foot of the pillar. The neck curls over the top to the right."""
    pillar = capsule(x, y, x - 0.5 * s, y - 9 * s, 0.8)
    neck = union(capsule(x - 0.5 * s, y - 9 * s, x + 3 * s, y - 7.5 * s, 0.9),
                 capsule(x + 3 * s, y - 7.5 * s, x + 5.5 * s, y - 9.5 * s, 0.9))
    box = capsule(x, y, x + 5.5 * s, y - 9.0 * s, 1.0)
    f.add(union(pillar, neck), HARP, bias=0.1)
    f.add(box, HARP, bias=0.15)
    strings = {}
    for i in range(1, 4):
        tx, ty = x + i * 1.4 * s - 0.3, y - 8.6 * s + i * 0.35
        bx, by = x + i * 1.4 * s - 0.3, y - (i * 1.4 * s) * (9.0 / 5.5) + 0.2
        for p in line_px(tx, ty + 1, bx, by - 1):
            strings[p] = "white" if i == strum else "cream"
    f.pix(strings, HARP, sep=False, outline=False)
    f.dots([(int(round(x + 5.5 * s)), int(round(y - 9.5 * s)))], "yellow")


def notes(f: Fig, pts, cols=("yellow", "sky_l", "pink")) -> None:
    for i, (x, y) in enumerate(pts):
        col = cols[i % len(cols)]
        f.dots([(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], col)
        f.dots([(x + 1, y - 1), (x + 1, y - 2), (x + 2, y - 2)], col)
        f.glow(x - 1, y + 1, alpha_px("white", 120))


def tristan_head(f: Fig, hx: float, hy: float, eyes: str = "open", mouth: str = "smile", ear_dy: int = 0,
                 feather: float = 0.0) -> None:
    # huge upright ears (the far one peeks behind), cream insides
    for (ex, ey, far) in ((hx - 4.0, hy - 4.5 + ear_dy, True), (hx + 0.5, hy - 5.0 + ear_dy, False)):
        ear = poly([(ex - 2.6, ey + 2.5), (ex - 0.6, ey - 6.5), (ex + 2.8, ey + 2.0)])
        f.add(ear, CORGI, bias=-0.15 if far else 0.12)
        if not far:
            f.recolor({(int(round(ex - 0.5)), int(round(ey + k))) for k in (-3, -2, -1, 0, 1)} |
                      {(int(round(ex + 0.5)), int(round(ey + k))) for k in (-1, 0, 1)}, "cream")
    skull = union(ellipse(hx, hy, 6.4, 5.4), ellipse(hx - 0.5, hy - 1.0, 5.8, 4.8))
    f.add(skull, CORGI, centre=(hx - 1.0, hy - 1.5), radius=(7, 6.5), bias=0.1)
    muzzle = union(ellipse(hx + 5.0, hy + 2.0, 3.8, 2.4), ellipse(hx + 2.0, hy + 3.0, 3.6, 2.2))
    f.add(muzzle, CORGI_W, centre=(hx + 4, hy + 1), radius=(4.5, 3.5), sep=False, bias=0.08)
    hxi, hyi = int(round(hx)), int(round(hy))
    # the white blaze up the middle of the face
    f.recolor({(hxi + 3, hyi - 3), (hxi + 3, hyi - 2), (hxi + 4, hyi - 2), (hxi + 4, hyi - 1), (hxi + 5, hyi - 1),
               (hxi + 5, hyi), (hxi + 2, hyi - 4)}, "white")
    nx, ny = hxi + 8, hyi + 1
    f.dots([(nx - 1, ny), (nx, ny), (nx - 1, ny + 1), (nx, ny + 1)], "umber")
    f.dot(nx - 1, ny, "slate")
    ex2, ey2 = hxi + 2, hyi
    if eyes == "open":
        f.dots([(ex2, ey2), (ex2 + 1, ey2), (ex2, ey2 + 1), (ex2 + 1, ey2 + 1)], "umber")
        f.dot(ex2, ey2, "white")
    elif eyes == "happy":
        f.dots([(ex2 - 1, ey2 + 1), (ex2, ey2), (ex2 + 1, ey2), (ex2 + 2, ey2 + 1)], "umber")
    elif eyes == "squint":
        f.dots([(ex2 - 1, ey2 - 1), (ex2, ey2), (ex2 + 1, ey2), (ex2, ey2 + 1), (ex2 - 1, ey2 + 2)], "umber")
    elif eyes == "focus":
        f.dots([(ex2, ey2), (ex2 + 1, ey2), (ex2, ey2 + 1), (ex2 + 1, ey2 + 1)], "umber")
        f.dot(ex2 + 1, ey2, "white")
        f.dots([(ex2 - 1, ey2 - 1), (ex2, ey2 - 1), (ex2 + 1, ey2 - 1)], "brown_d")
    f.dots([(ex2, ey2 + 3), (ex2 + 1, ey2 + 3)], "pink")
    mx, my = hxi + 6, hyi + 3
    if mouth == "smile":
        f.dots([(mx - 1, my), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my)], "brown_d")
    elif mouth == "sing":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my), (mx, my + 1), (mx + 1, my + 1)], "wine")
        f.dots([(mx, my + 1)], "pink")
    elif mouth == "o":
        f.dots([(mx, my), (mx + 1, my), (mx, my + 1), (mx + 1, my + 1)], "wine")
    # small feathered cap on the crown, tilted back, with a yellow feather sweeping back
    cap = union(ellipse(hx - 1.0, hy - 4.6, 4.2, 2.2), rect(int(hx - 5), int(hy - 4), 9, 1))
    f.add(cap, CAP, centre=(hx - 3, hy - 6), radius=(5, 3), bias=0.1)
    fx0, fy0 = hx - 3.5, hy - 5.0
    fea = union(capsule(fx0, fy0, fx0 - 2.6, fy0 - 2.6 - feather, 0.75),
                capsule(fx0 - 2.6, fy0 - 2.6 - feather, fx0 - 5.0, fy0 - 2.8 - feather * 1.2, 0.6))
    f.add(fea, FEATHER, bias=0.15)


def tristan_frame(bob: int = 0, lean: float = 0.0, eyes: str = "open", mouth: str = "smile", legs=((0, 0.0), (0, 0.0)),
                  harp_at=None, strum: int = -1, paw=None, cape_wave: float = 0.0, cape_lift: float = 0.0,
                  head_dy: int = 0, ear_dy: int = 0, feather: float = 0.0, extra=None) -> Fig:
    f = Fig(32, 32, seed=181)
    bx, by = 13.0 + lean, 23.0 + bob
    hx, hy = 15.5 + lean * 1.3, 12.5 + bob + head_dy
    # harp on the back (unless it is in his paws)
    if harp_at is None:
        harp(f, bx - 6.5, by + 0.5, 0.95)
    # light-blue cape from the shoulders
    hem = GROUND32 - 1 - cape_lift * 5
    back = bx - 10 - cape_lift * 4
    cape = poly([(bx + 2, by - 5), (bx - 3, by - 6), (bx - 7 - cape_lift * 2, by - 2.5), (back - cape_wave, hem - 3),
                 (back - 0.5 - cape_wave, hem), (back + 3, hem - 1.2), (back + 6, hem + 0.3), (bx - 1, hem - 1),
                 (bx + 1.5, by + 1)])
    f.add(cape, SKY_CAPE, centre=(bx - 2, by - 2), radius=(8, 8), bias=0.06, contrast=0.85)
    f.recolor({(x, y) for (x, y) in cape if y >= hem - 1.2 and x <= back + 1.5 - cape_wave}, "water")
    # fluffy white rump
    f.add(ellipse(bx - 5.0, by + 1.5, 2.6, 2.4), CORGI_W, bias=0.1)
    # short legs with white socks
    (fl, fdx), (nl, ndx) = legs
    for (x, lift, dx, far) in ((bx - 2.5, fl, fdx, True), (bx + 3.0, nl, ndx, False)):
        foot = GROUND32 - lift
        s = union(rect(int(round(x + dx * 0.5)) - 1, int(by + 2), 3, max(1, int(foot - by - 2))),
                  capsule(x, by + 2, x + dx, foot - 1, 1.5))
        f.add(s, CORGI if far else CORGI_W, mode="cyl_v", bias=-0.2 if far else 0.0)
        px_ = int(round(x + dx))
        f.add(rect(px_ - 1, foot - 1, 4, 2), CORGI_W, flat=1 if not far else 0)
    # body: a long low torso in a green tunic, white chest fur
    torso = union(ellipse(bx, by - 0.5, 6.0, 4.0), rect(int(bx - 5), int(by), 11, 3))
    f.add(torso, TUNIC_G, centre=(bx - 1.5, by - 2.5), radius=(6.5, 5.0), bias=0.04)
    f.recolor({(x, int(by + 1)) for x in range(int(bx - 6), int(bx + 7))} & torso, "brown_d")
    f.dots([(int(bx + 1), int(by + 1)), (int(bx + 2), int(by + 1))], "yellow")
    f.add(ellipse(bx + 2.5, by - 3.4, 3.4, 2.2), CORGI_W, centre=(bx + 1, by - 4.5), radius=(3.5, 2.5), bias=0.1)
    tristan_head(f, hx, hy, eyes, mouth, ear_dy, feather)
    # harp held in front (attack / play), the near paw strumming
    if harp_at is not None:
        harp(f, harp_at[0], harp_at[1], 0.95, strum)
    if paw is None:
        paw = (bx + 5.5, by + 0.5)
    f.add(union(capsule(bx + 2.0, by - 2.5, paw[0], paw[1], 1.4), ellipse(paw[0], paw[1], 1.6, 1.5)), CORGI, bias=0.1)
    f.add(ellipse(paw[0] + 0.3, paw[1] + 0.3, 1.3, 1.2), CORGI_W, flat=1, sep=False)
    if extra:
        extra(f)
    return f


def tristan() -> list[Anim]:
    T = tristan_frame
    idle = [T(), T(bob=1, cape_wave=0.6, feather=0.5), T(bob=1, cape_wave=1.0, eyes="happy", feather=1.0),
            T(cape_wave=0.4, feather=0.4)]
    run_legs = [((0, -2.0), (0, 2.0)), ((1, -1.0), (0, 1.0)), ((2, 0.5), (0, -1.0)),
                ((0, 2.0), (0, -2.0)), ((0, 1.0), (1, -1.0)), ((0, -1.0), (2, 0.5))]
    run_bob = [0, 1, -1, 0, 1, -1]
    run = [T(bob=run_bob[i], lean=0.5, legs=run_legs[i], cape_lift=0.8, cape_wave=i % 2, feather=1.5,
             ear_dy=-1 if run_bob[i] < 0 else 0, mouth="sing" if i % 3 == 0 else "smile") for i in range(6)]
    front = (19.5, 24.0)
    attack = [T(lean=-1, harp_at=front, paw=(21.5, 18.0), eyes="focus", mouth="smile"),
              T(lean=1, harp_at=(20.0, 24.0), paw=(24.0, 21.0), strum=2, eyes="happy", mouth="sing",
                extra=lambda f: notes(f, [(27, 14)])),
              T(lean=0.5, harp_at=(20.0, 24.0), paw=(23.5, 20.0), strum=1, eyes="happy", mouth="sing",
                extra=lambda f: notes(f, [(28, 10)])),
              T()]
    hurt = [T(lean=-1.5, head_dy=1, eyes="squint", mouth="o", ear_dy=1, extra=lambda f: stars(f, [(8, 3), (19, 1)])),
            T(lean=-1.0, eyes="squint", mouth="o", ear_dy=1)]
    play = [T(harp_at=front, paw=(23.0, 18.0), strum=1, eyes="happy", mouth="sing", extra=lambda f: notes(f, [(26, 8)])),
            T(bob=1, harp_at=(19.5, 25.0), paw=(23.5, 21.0), strum=3, eyes="happy", mouth="smile", feather=0.6,
              extra=lambda f: notes(f, [(27, 5), (24, 11)])),
            T(harp_at=front, paw=(23.0, 19.5), strum=2, eyes="happy", mouth="sing", feather=0.3,
              extra=lambda f: notes(f, [(28, 2), (25, 8)]))]
    return [anim("idle", R(idle), 6.0, True), anim("run", R(run), 14.0, True),
            anim("attack", R(attack), 16.0, False, [0.8, 1.0, 1.2, 1.0]),
            anim("hurt", R(hurt), 6.0, False, [1.0, 3.0]), anim("play", R(play), 8.0, True)]


# ---------------------------------------------------------------------------
# gawain 高文 (40): Saint Bernard mountain knight - big, fluffy, brown and white, barrel on the collar,
# a big iron hammer and an orange cloak
# ---------------------------------------------------------------------------

SB = Mat(["brown_d", "brown", "gold_d", "gold"], outline="umber", lit="brown_d", fur=0.14, sep="brown_d", sep_lit="brown")
SB_FAR = Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber", lit="umber", fur=0.1, sep="umber",
             sep_lit="brown_d")
SB_W = Mat(["ash", "fog", "white", "white"], outline="slate", lit="ash", fur=0.14, sep="ash", sep_lit="fog")
CLOAK_O = Mat(["gold_d", "orange", "amber", "gold_l"], outline="brown_d", lit="brown", sep="gold_d", sep_lit="orange")
HAMMER = Mat(["iron", "steel_d", "steel", "steel_l"], outline="navy", lit="iron", spec="white", spec_at=0.84)
HANDLE = Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber")
BARREL = Mat(["brown_d", "brown", "gold_d", "gold"], outline="umber", lit="brown_d")
STEEL = Mat(["iron", "steel_d", "steel", "steel_l"], outline="navy", lit="iron", spec="white", spec_at=0.86)


def big_hammer(f: Fig, hx: float, hy: float, deg: float, length: float = 12.0, head_w: float = 8.0) -> None:
    """A big iron hammer gripped at (hx, hy); the handle runs along `deg` (0 = right, 90 = up) to the head."""
    a = math.radians(deg)
    dx, dy = math.cos(a), -math.sin(a)
    tx, ty = hx + dx * length, hy + dy * length
    hp = {}
    for i in range(-3, int(length) + 1):
        hp[(int(round(hx + dx * i)), int(round(hy + dy * i)))] = "brown" if i % 4 else "gold_d"
    f.pix(hp, HANDLE)
    nx, ny = -dy, dx
    hw, hd = head_w / 2, 2.9
    corners = [(tx + nx * hw - dx * 0.6, ty + ny * hw - dy * 0.6), (tx + nx * hw + dx * hd * 1.6, ty + ny * hw + dy * hd * 1.6),
               (tx - nx * hw + dx * hd * 1.6, ty - ny * hw + dy * hd * 1.6), (tx - nx * hw - dx * 0.6, ty - ny * hw - dy * 0.6)]
    head = poly(corners)
    f.add(head, HAMMER, centre=(tx - 1.5, ty - 1.5), radius=(hw + 1, hw + 1), bias=0.08)
    # dark bands at both faces of the head
    for s in (1, -1):
        f.recolor({(int(round(tx + nx * s * (hw - 0.6) + dx * k)), int(round(ty + ny * s * (hw - 0.6) + dy * k)))
                   for k in (0, 1, 2, 3)} & head, "iron")


def gawain_head(f: Fig, hx: float, hy: float, eyes: str = "open", mouth: str = "smile", ear_dy: int = 0) -> None:
    skull = union(ellipse(hx, hy, 7.6, 6.4), ellipse(hx - 0.5, hy - 1.2, 7.0, 5.8))
    f.add(skull, SB, centre=(hx - 1.5, hy - 2.0), radius=(8.5, 7.5), bias=0.1)
    # white blaze and big white muzzle with droopy jowls
    blaze = poly([(hx + 0.5, hy - 6.5), (hx + 2.5, hy - 6.5), (hx + 4.0, hy + 0.5), (hx + 0.5, hy + 0.5)])
    f.recolor(blaze & skull, "fog")
    f.recolor({(x, y) for (x, y) in blaze & skull if x <= hx + 1.5}, "white")
    muzzle = union(ellipse(hx + 6.0, hy + 2.4, 4.4, 3.2), ellipse(hx + 2.6, hy + 3.8, 4.4, 2.8))
    f.add(muzzle, SB_W, centre=(hx + 4.5, hy + 1), radius=(5.5, 4.0), sep=False, bias=0.12)
    jowl = ellipse(hx + 6.4, hy + 5.0, 2.8, 1.8)
    f.add(jowl, SB_W, bias=-0.02, sep=True)
    hxi, hyi = int(round(hx)), int(round(hy))
    # dark brown mask around the eye
    ex, ey = hxi + 3, hyi - 1
    f.recolor({(ex - 1, ey - 1), (ex, ey - 1), (ex + 1, ey - 1), (ex + 2, ey - 1), (ex - 1, ey), (ex + 2, ey),
               (ex - 1, ey + 1), (ex + 2, ey + 1), (ex, ey + 2), (ex + 1, ey + 2)}, "brown_d")
    nx, ny = hxi + 10, hyi + 1
    f.dots([(nx - 1, ny), (nx, ny), (nx - 1, ny + 1), (nx, ny + 1), (nx - 2, ny)], "umber")
    f.dot(nx - 1, ny, "slate")
    if eyes == "open":
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], "umber")
        f.dot(ex, ey, "white")
    elif eyes == "happy":
        f.dots([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1)], "umber")
    elif eyes == "focus":
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], "umber")
        f.dot(ex + 1, ey, "white")
        f.dots([(ex - 1, ey - 2), (ex, ey - 2), (ex + 1, ey - 1), (ex + 2, ey - 1)], "umber")
    elif eyes == "squint":
        f.dots([(ex - 1, ey - 1), (ex, ey), (ex + 1, ey + 1), (ex, ey + 2), (ex - 1, ey + 3)], "umber")
    f.dots([(ex + 1, ey + 3), (ex + 2, ey + 3)], "pink")
    mx, my = hxi + 7, hyi + 4
    if mouth == "smile":
        f.dots([(mx - 1, my), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my)], "slate")
    elif mouth == "open":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my), (mx, my + 1), (mx + 1, my + 1)], "wine")
        f.dots([(mx, my + 1), (mx + 1, my + 2)], "pink")
    elif mouth == "shout":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my), (mx - 1, my + 1), (mx, my + 1), (mx + 1, my + 1),
                (mx + 2, my + 1), (mx, my + 2), (mx + 1, my + 2)], "wine")
        f.dots([(mx, my + 2), (mx + 1, my + 2)], "pink")
    elif mouth == "o":
        f.dots([(mx, my), (mx + 1, my), (mx, my + 1), (mx + 1, my + 1)], "wine")
    # big floppy ear on the near side
    ex0, ey0 = hx - 4.0, hy - 3.5 + ear_dy
    ear = union(poly([(ex0 - 2.0, ey0), (ex0 + 2.8, ey0 - 1.0), (ex0 + 3.2, ey0 + 5.0), (ex0 + 2.2, ey0 + 9.0),
                      (ex0 - 0.8, ey0 + 9.4), (ex0 - 2.6, ey0 + 5.0)]), ellipse(ex0 + 0.4, ey0 + 7.8, 2.6, 2.2))
    f.add(ear, SB_FAR, centre=(ex0, ey0 + 2), radius=(4, 7), bias=0.08)


def gawain_frame(bob: int = 0, lean: float = 0.0, eyes: str = "open", mouth: str = "smile", legs=((0, 0.0), (0, 0.0)),
                 hammer=None, cloak_wave: float = 0.0, cloak_lift: float = 0.0, head_dy: int = 0, ear_dy: int = 0,
                 tail: float = 0.0, front_hammer: bool = False, extra=None) -> Fig:
    f = Fig(40, 40, seed=191)
    bx, by = 17.0 + lean, 27.0 + bob
    hx, hy = 21.0 + lean * 1.3, 13.5 + bob + head_dy
    paw = hammer[0] if hammer else (bx + 8.5, by - 2.0)
    hdeg = hammer[1] if hammer else -72.0
    hlen = hammer[2] if hammer and len(hammer) > 2 else 7.5 - bob
    if not front_hammer and hdeg > 0:
        big_hammer(f, paw[0], paw[1], hdeg, hlen)
    # fluffy tail
    ta = math.radians(150 - tail * 30)
    tb = (bx - 7.5, by + 1)
    tt = (tb[0] + math.cos(ta) * 5.5, tb[1] - math.sin(ta) * 5.5)
    f.add(union(capsule(tb[0], tb[1], tt[0], tt[1], 2.2), ellipse(tt[0], tt[1], 2.6, 2.4)), SB, bias=0.08)
    f.recolor({(x, y) for (x, y) in ellipse(tt[0] - 0.5, tt[1] - 0.5, 1.8, 1.6)}, "white")
    # orange cloak from the shoulders
    hem = GROUND40 - 1 - cloak_lift * 6
    back = bx - 11 - cloak_lift * 6
    cl = poly([(bx + 3, by - 7.5), (bx - 4, by - 8), (bx - 8 - cloak_lift * 2, by - 3), (back - cloak_wave, hem - 3),
               (back - 0.5 - cloak_wave, hem), (back + 3.5, hem - 1.2), (back + 7, hem + 0.3), (bx - 1, hem - 1),
               (bx + 2, by + 2)])
    f.add(cl, CLOAK_O, centre=(bx - 3, by - 4), radius=(10, 11), bias=0.06, contrast=0.85)
    for k, xb in enumerate((back + 3.5, back + 7.5)):
        fold = {p for p in capsule(bx - 4 - k, by - 4, xb, hem - 1.5, 0.5) if p in cl}
        f.shade_toward(fold, CLOAK_O, -1)
    f.recolor({(x, y) for (x, y) in cl if y >= hem - 1.5 and x <= back + 1.5 - cloak_wave}, "gold_d")
    # legs: thick and fluffy, white socks
    (fl, fdx), (nl, ndx) = legs
    for (x, lift, dx, far) in ((bx - 3.5, fl, fdx, True), (bx + 3.5, nl, ndx, False)):
        foot = GROUND40 - lift
        s = union(rect(int(round(x + dx * 0.5)) - 2, int(by + 3), 5, int(foot - by - 4)),
                  capsule(x, by + 3, x + dx, foot - 2, 2.4))
        f.add(s, SB_FAR if far else SB, mode="cyl_v", bias=-0.1 if far else 0.02)
        px_ = int(round(x + dx))
        f.add(union(rect(px_ - 2, foot - 2, 6, 3), {(px_ + 4, foot)}), SB_W, flat=1 if not far else 0)
    # body: big round fluffy torso (brown back, white belly) with a steel breastplate and a belt
    torso = union(ellipse(bx, by - 1.0, 8.4, 6.6), rect(int(bx - 7), int(by), 15, 4))
    f.add(torso, SB, centre=(bx - 2, by - 4), radius=(9, 8), bias=0.05)
    plate = {(x, y) for (x, y) in ellipse(bx + 2.0, by - 0.5, 6.4, 5.4) if (x, y) in torso}
    f.add(plate, STEEL, centre=(bx, by - 3), radius=(6.5, 6), bias=0.05)
    f.recolor({(x, int(by + 3)) for x in range(40)} & torso, "brown_d")
    f.recolor({(x, int(by + 2)) for x in range(40)} & torso, "brown")
    f.dots([(int(bx + 2), int(by + 2)), (int(bx + 3), int(by + 2)), (int(bx + 2), int(by + 3)), (int(bx + 3), int(by + 3))],
           "yellow")
    # white chest ruff spilling over the plate, a red collar and the little barrel
    ruff = union(ellipse(bx + 3.0, by - 6.0, 5.4, 2.8), {(int(bx) + k, int(by - 3)) for k in (0, 2, 4, 6)})
    f.add(ruff, SB_W, centre=(bx + 1, by - 7), radius=(5.5, 3), bias=0.08)
    gawain_head(f, hx, hy, eyes, mouth, ear_dy)
    cx_, cy_ = hx + 1.5, hy + 7.4
    f.recolor({(x, int(round(cy_ - 1.5))) for x in range(int(cx_ - 4), int(cx_ + 5))}, "red_d")
    barrel = union(rect(int(round(cx_)) - 2, int(round(cy_)), 6, 4), ellipse(cx_ + 0.5, cy_ + 2.0, 3.4, 2.2))
    f.add(barrel, BARREL, centre=(cx_ - 1, cy_), radius=(4, 3), bias=0.08)
    bxi, byi = int(round(cx_)), int(round(cy_))
    f.recolor({(bxi - 2, byi + 1), (bxi - 2, byi + 2), (bxi + 3, byi + 1), (bxi + 3, byi + 2), (bxi + 4, byi + 1),
               (bxi + 4, byi + 2), (bxi - 3, byi + 1), (bxi - 3, byi + 2)} & barrel, "gold")
    f.dot(bxi + 1, byi - 1, "red_d")
    # the near arm gripping the hammer (or the hammer in front for the slam)
    if front_hammer or hdeg <= 0:
        big_hammer(f, paw[0], paw[1], hdeg, hlen)
    f.add(union(capsule(bx + 3.0, by - 4.0, paw[0], paw[1], 2.0), ellipse(paw[0], paw[1], 2.3, 2.2)), SB, bias=0.1)
    f.add(ellipse(paw[0] + 0.3, paw[1] + 0.4, 1.8, 1.6), SB_W, flat=1, sep=False)
    f.add(ellipse(bx + 2.8, by - 4.4, 3.2, 2.6), STEEL, bias=0.12)
    if extra:
        extra(f)
    return f


def _impact(f: Fig, x: int, y: int, k: int) -> None:
    """Hammer impact: a ring of dust puffs and little stars on the ground (cute, no debris)."""
    for i, (dx, dy) in enumerate(((-6, 0), (-3, -2), (3, -2), (6, 0), (0, -3))):
        r = 1 + (k + i) % 2
        for (px, py) in P.ellipse(x + dx * (1 + k * 0.3), y + dy, r, r * 0.8):
            f.glow(px, py, alpha_px("stone_l" if i % 2 else "white", 210 - k * 60))
    if k == 0:
        sparkle(f, x - 2, y - 6, "white", "yellow", 2)
        sparkle(f, x + 4, y - 5, "yellow", "amber", 1)


def gawain() -> list[Anim]:
    G = gawain_frame
    idle = [G(), G(bob=1, cloak_wave=0.6, tail=0.2), G(bob=1, cloak_wave=1.0, eyes="happy", tail=0.35),
            G(cloak_wave=0.4, tail=0.1)]
    run_legs = [((0, -3.0), (0, 3.0)), ((2, -1.0), (0, 1.5)), ((3, 1.0), (0, -1.5)),
                ((0, 3.0), (0, -3.0)), ((0, 1.5), (2, -1.0)), ((0, -1.5), (3, 1.0))]
    run_bob = [0, 1, -1, 0, 1, -1]
    run = [G(bob=run_bob[i], lean=0.5, legs=run_legs[i], cloak_lift=0.7, cloak_wave=i % 2, tail=-0.3,
             hammer=((26.0, 24.5 + run_bob[i]), 42.0, 8.0), ear_dy=-1 if run_bob[i] < 0 else 0, front_hammer=True,
             mouth="open" if i % 3 == 0 else "smile") for i in range(6)]
    attack = [G(lean=-1.5, hammer=((19.0, 19.0), 125.0, 9.0), eyes="focus", mouth="smile"),
              G(lean=2.0, hammer=((26.0, 23.0), 12.0, 7.5), eyes="focus", mouth="shout", front_hammer=True,
                extra=lambda f: _swing_smear(f, 29, 24)),
              G(lean=1.5, hammer=((26.0, 25.0), -30.0, 7.5), eyes="focus", mouth="open", front_hammer=True),
              G(lean=0.5)]
    hurt = [G(lean=-1.5, head_dy=1, eyes="squint", mouth="o", ear_dy=1, extra=lambda f: stars(f, [(12, 3), (27, 2)])),
            G(lean=-1.0, eyes="squint", mouth="o", ear_dy=1)]
    slam = [G(lean=-1.0, bob=-1, hammer=((20.0, 13.0), 98.0, 7.0), eyes="focus", mouth="shout", ear_dy=-1),
            G(lean=2.0, bob=1, hammer=((27.0, 26.0), -42.0, 7.0), eyes="focus", mouth="shout", front_hammer=True,
              extra=lambda f: _impact(f, 33, 36, 0)),
            G(lean=1.5, bob=1, hammer=((27.0, 26.0), -42.0, 7.0), eyes="happy", mouth="open", front_hammer=True,
              extra=lambda f: _impact(f, 33, 36, 1))]
    return [anim("idle", R(idle), 5.0, True), anim("run", R(run), 12.0, True),
            anim("attack", R(attack), 14.0, False, [1.0, 1.0, 1.0, 0.8]),
            anim("hurt", R(hurt), 6.0, False, [1.0, 3.0]), anim("slam", R(slam), 10.0, False, [1.6, 1.0, 1.4])]


def _swing_smear(f: Fig, cx: float, cy: float) -> None:
    for i in range(7):
        a = math.radians(120 - i * 22)
        for d in (11, 12):
            f.glow(int(round(cx - 6 + math.cos(a) * d)), int(round(cy - math.sin(a) * d)),
                   alpha_px("white", 120 + d * 6))


# ---------------------------------------------------------------------------
# mordred 莫德雷德 (48): Dobermann black knight - black-and-tan short fur, tall pointed ears, silver-trimmed black
# armour, a wolf-head pauldron, a dark grey cape, a glowing purple scabbard at the hip. Proud stance.
# ---------------------------------------------------------------------------

DOB = Mat(["ink", "navy", "iron", "slate"], outline="ink", lit="ink", fur=0.06, sep="ink", sep_lit="navy")
DOB_FAR = Mat(["ink", "ink", "navy", "iron"], outline="ink", lit="ink", sep="ink", sep_lit="ink")
TAN = Mat(["brown", "gold_d", "gold"], outline="umber", lit="brown", sep="brown", sep_lit="gold_d")
M_ARMOR = Mat(["ink", "navy", "iron", "slate", "steel_d"], outline="ink", lit="ink", spec="steel", spec_at=0.86,
              sep="ink", sep_lit="navy")
M_ARMOR_FAR = Mat(["ink", "navy", "navy", "iron"], outline="ink", lit="ink", sep="ink", sep_lit="navy")
M_CAPE = Mat(["iron", "slate", "stone_d", "ash"], outline="ink", lit="iron", sep="iron", sep_lit="slate")
SCAB = Mat(["plum", "violet", "lilac", "white"], outline="ink", lit="plum", sep="plum", sep_lit="violet")
M_BLADE = Mat(["steel_d", "steel", "steel_l", "white"], outline="navy", lit="iron")
SILVER_T = Mat(["steel_d", "steel", "steel_l", "white"], outline="ink", lit="navy")


def trim(f: Fig, shape: set, col: str = "steel_l", side: str = "top") -> None:
    """Silver trim along one edge of an armour part."""
    off = {"top": (0, -1), "bottom": (0, 1), "left": (-1, 0), "right": (1, 0)}[side]
    f.recolor({(x, y) for (x, y) in shape if (x + off[0], y + off[1]) not in shape}, col)


def mordred_head(f: Fig, hx: float, hy: float, eyes: str = "proud", mouth: str = "smirk", ear_dy: int = 0,
                 tilt: float = 0.0) -> None:
    """A Dobermann head facing right: tall pointed ears, a wedge snout, black fur with rust-tan markings."""
    for (ex, ey, m) in ((hx - 4.6, hy - 4.4 + ear_dy, DOB_FAR), (hx + 0.2, hy - 5.2 + ear_dy, DOB)):
        ear = poly([(ex - 2.9, ey + 2.8), (ex - 0.9 - ear_dy * 0.9, ey - 9.6 + abs(ear_dy) * 1.6), (ex + 2.9, ey + 2.0)])
        f.add(ear, m, bias=0.18)
        if m is DOB:
            f.recolor({(int(round(ex - 0.5)), int(round(ey + k))) for k in (-5, -4, -3, -2, -1, 0)} |
                      {(int(round(ex + 0.5)), int(round(ey + k))) for k in (-2, -1, 0)}, "navy")
    skull = union(ellipse(hx, hy, 7.4, 6.3), ellipse(hx - 0.4, hy - 1.0, 6.8, 5.7))
    f.add(skull, DOB, centre=(hx - 1.8, hy - 2.4), radius=(8.0, 7.5), bias=0.2)
    t = tilt
    snout = poly([(hx + 2.5, hy - 2.6 - t), (hx + 10.0, hy - 0.4 - t * 1.4), (hx + 10.8, hy + 1.4 - t * 1.4),
                  (hx + 10.0, hy + 3.2 - t), (hx + 3.0, hy + 5.2)])
    f.add(snout, DOB, centre=(hx + 4, hy - 2.0), radius=(7, 4.5), bias=0.2)
    hxi, hyi = int(round(hx)), int(round(hy))
    # rust-tan markings: muzzle sides and underside, a cheek spot, the eyebrow dot
    tan = {(x, y) for (x, y) in (snout | skull) if y >= hy + 1.4 - (x - hx) * 0.12 * t and x >= hx + 2.5}
    tan |= {(x, y) for (x, y) in ellipse(hx + 1.6, hy + 3.2, 2.4, 1.7) if (x, y) in skull}
    f.recolor(tan, "gold_d")
    f.recolor({(x, y) for (x, y) in tan if (x, y + 1) not in tan or (x, y + 1) not in (snout | skull)}, "brown")
    f.recolor({(x, y) for (x, y) in tan if (x, y - 1) not in tan and x > hx + 4}, "gold")
    f.dots([(hxi + 2, hyi - 4), (hxi + 3, hyi - 4)], "gold")
    # nose at the tip of the snout
    nx, ny = hxi + 11, int(round(hy - 0.3 - t * 1.4))
    f.dots([(nx - 1, ny), (nx, ny), (nx - 1, ny + 1), (nx, ny + 1)], "ink")
    f.dot(nx - 1, ny, "steel_d")
    # eyes: amber, narrow and proud
    ex, ey = hxi + 3, hyi - 1
    if eyes == "proud":                      # heavy lid, amber iris, a white glint
        f.dots([(ex - 1, ey), (ex, ey), (ex + 1, ey), (ex + 2, ey), (ex + 3, ey - 1)], "ink")
        f.dots([(ex, ey + 1), (ex + 1, ey + 1)], "yellow")
        f.dots([(ex + 2, ey + 1), (ex + 1, ey + 2), (ex + 2, ey + 2)], "ink")
        f.dots([(ex, ey + 2)], "amber")
        f.dot(ex, ey + 1, "white")
    elif eyes == "open":
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1), (ex, ey + 2), (ex + 1, ey + 2)], "yellow")
        f.dots([(ex + 1, ey + 1), (ex + 1, ey + 2)], "ink")
        f.dots([(ex, ey + 2)], "amber")
        f.dot(ex, ey, "white")
    elif eyes == "angry":
        f.dots([(ex - 1, ey - 1), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1), (ex + 3, ey + 1)], "ink")
        f.dots([(ex, ey + 1), (ex + 1, ey + 1), (ex, ey + 2), (ex + 1, ey + 2)], "yellow")
        f.dots([(ex + 1, ey + 2), (ex + 1, ey + 1)], "ink")
        f.dots([(ex - 1, ey - 2), (ex, ey - 2)], "gold")
    elif eyes == "squint":
        f.dots([(ex - 1, ey - 1), (ex, ey), (ex + 1, ey + 1), (ex, ey + 2), (ex - 1, ey + 3)], "yellow")
    elif eyes == "closed":
        f.dots([(ex - 1, ey + 1), (ex, ey + 2), (ex + 1, ey + 2), (ex + 2, ey + 1)], "gold")
    mx, my = hxi + 6, hyi + 4
    if mouth == "smirk":
        f.dots([(mx, my), (mx + 1, my), (mx + 2, my), (mx + 3, my - 1)], "ink")
    elif mouth == "shout":
        f.dots([(mx, my), (mx + 1, my), (mx + 2, my), (mx + 3, my), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my + 1)],
               "wine")
        f.dots([(mx + 1, my), (mx + 3, my)], "white")
    elif mouth == "frown":
        f.dots([(mx, my + 1), (mx + 1, my), (mx + 2, my), (mx + 3, my + 1)], "ink")
    elif mouth == "o":
        f.dots([(mx + 1, my), (mx + 2, my), (mx + 1, my + 1), (mx + 2, my + 1)], "wine")


def wolf_pauldron(f: Fig, x: float, y: float) -> None:
    """The wolf-head pauldron: a black wolf's head on the shoulder - pointed ear, snout forward, a lilac eye,
    silver trim along the jaw."""
    dome = union(ellipse(x, y, 4.6, 3.8), poly([(x + 1.0, y - 2.6), (x + 7.4, y - 0.2), (x + 7.0, y + 1.6),
                                                 (x + 1.5, y + 2.6)]))
    f.add(dome, M_ARMOR, centre=(x - 1.0, y - 2.0), radius=(5.5, 4.5), bias=0.22)
    ear = poly([(x - 2.0, y - 2.6), (x - 0.4, y - 7.4), (x + 1.8, y - 2.8)])
    f.add(ear, M_ARMOR, bias=0.22)
    f.recolor({(x_, y_) for (x_, y_) in dome if (x_, y_ + 1) not in dome}, "steel_l")
    xi, yi = int(round(x)), int(round(y))
    f.dots([(xi + 2, yi - 1), (xi + 3, yi - 1)], "lilac")
    f.dot(xi + 2, yi - 1, "white")
    f.glow(xi + 2, yi - 3, alpha_px("violet", 120))
    f.dots([(xi + 7, yi - 0)], "steel_l")
    f.recolor({(xi + 4, yi + 1), (xi + 5, yi + 1), (xi + 6, yi + 1)} & dome, "ink")


def m_sword(f: Fig, hx: float, hy: float, deg: float, length: int = 14) -> None:
    a = -math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    grip = {}
    for i in range(0, 3):
        grip[(int(round(hx - dx * i)), int(round(hy - dy * i)))] = "navy" if i < 2 else "violet"
    f.pix(grip, M_ARMOR)
    gx, gy = hx + dx * 1.5, hy + dy * 1.5
    guard = {}
    for k in (-2, -1, 0, 1, 2):
        guard[(int(round(gx - dy * k)), int(round(gy + dx * k)))] = "steel_l" if k <= 0 else "steel"
    f.pix(guard, SILVER_T)
    f.pix(blade(gx + dx * 1.2, gy + dy * 1.2, a, length, 2, light="white", mid="steel_l", dark="steel"), M_BLADE)


def scabbard(f: Fig, x0: float, y0: float, x1: float, y1: float, glow_a: int = 150) -> None:
    """The stolen scabbard: violet with a silver throat and chape, glowing."""
    body = capsule(x0, y0, x1, y1, 1.3)
    f.add(body, SCAB, bias=0.15)
    f.recolor({p for p in line_px(x0, y0, x1, y1)} & body, "lilac")
    f.dots([(int(round(x0)), int(round(y0))), (int(round(x1)), int(round(y1)))], "steel_l")
    mx, my = int(round((x0 + x1) / 2)), int(round((y0 + y1) / 2))
    f.dot(mx, my, "white")
    for (x, y) in body:
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, -1)):
            f.glow(x + dx, y + dy, alpha_px("violet" if abs(dx) + abs(dy) == 1 else "lilac",
                                            glow_a if abs(dx) + abs(dy) == 1 else glow_a // 2))


def mordred_frame(bob: int = 0, lean: float = 0.0, eyes: str = "proud", mouth: str = "smirk", legs=((0, 0.0), (0, 0.0)),
                  hand=None, sword_deg: float = -52.0, sword_len: int = 12, cape_wave: float = 0.0, cape_lift: float = 0.0,
                  head_dy: int = 0, ear_dy: int = 0, tilt: float = 0.6, scab=None, scab_glow: int = 150, kneel: bool = False,
                  extra=None) -> Fig:
    f = Fig(48, 48, seed=201)
    bx, by = 20.0 + lean, 29.5 + bob + (6 if kneel else 0)
    hx, hy = 22.0 + lean * 1.2, 13.5 + bob + head_dy + (6 if kneel else 0)
    # dark grey cape from the shoulders, plum lining at the turned hem
    hem = GROUND48 - 1 - cape_lift * 7
    back = bx - 13 - cape_lift * 7
    cape = poly([(bx + 3, by - 9), (bx - 5, by - 10), (bx - 10 - cape_lift * 3, by - 3), (back - cape_wave, hem - 4),
                 (back - 0.5 - cape_wave, hem), (back + 4, hem - 1.5), (back + 8, hem + 0.3), (bx - 2, hem - 1),
                 (bx + 2, by + 3)])
    if kneel:
        cape = poly([(bx + 3, by - 9), (bx - 5, by - 10), (bx - 11, by - 3), (bx - 16, GROUND48), (bx - 9, GROUND48 - 1),
                     (bx - 4, GROUND48), (bx + 2, by + 3)])
    f.add(cape, M_CAPE, centre=(bx - 4, by - 6), radius=(12, 14), bias=0.06, contrast=0.85)
    for k, xb in enumerate((back + 4, back + 9)):
        fold = {p for p in capsule(bx - 5 - k * 2, by - 5, xb, hem - 2, 0.5) if p in cape}
        f.shade_toward(fold, M_CAPE, -1)
    if not kneel:
        f.recolor({(x, y) for (x, y) in cape if y >= hem - 2 and x <= back + 2.5 - cape_wave}, "plum")
    # the glowing scabbard at the hip, hanging back (or raised in the far paw)
    if scab is None and kneel:
        scabbard(f, bx - 2.5, by + 3.0, bx - 12.0, by + 7.5, scab_glow)
    elif scab is None:
        scabbard(f, bx - 2.5, by + 4.0, bx - 12.5, by + 11.0, scab_glow)
    # legs: black greaves with silver knee cops
    (fl, fdx), (nl, ndx) = legs
    if kneel:
        # far knee on the ground (shin flat behind), near leg bent with the foot planted in front
        f.add(union(capsule(bx - 1, by + 4, bx - 2, GROUND48 - 1.5, 2.3), capsule(bx - 2, GROUND48 - 1.2, bx - 10, GROUND48 - 1.2, 1.6)),
              M_ARMOR_FAR, bias=-0.05)
        f.add(union(capsule(bx + 1, by + 4, bx + 7, by + 5, 2.4), capsule(bx + 7, by + 5, bx + 7.5, GROUND48 - 2, 2.1),
                    rect(int(bx + 6), GROUND48 - 1, 6, 2)), M_ARMOR, bias=0.04)
        f.add(ellipse(bx + 7.2, by + 4.6, 2.5, 2.0), M_ARMOR, bias=0.15)
        f.recolor({(int(bx + 6), int(by + 3)), (int(bx + 7), int(by + 3))}, "steel_l")
        f.recolor({(int(bx + 6) + k, GROUND48 - 1) for k in range(6)}, "steel")
    else:
        for (x, lift, dx, far) in ((bx - 3.0, fl, fdx, True), (bx + 2.5, nl, ndx, False)):
            foot = GROUND48 - lift
            s = union(rect(int(round(x + dx * 0.5)) - 2, int(by + 5), 4, int(foot - by - 6)),
                      capsule(x, by + 5, x + dx, foot - 2, 2.0))
            f.add(s, M_ARMOR_FAR if far else M_ARMOR, mode="cyl_v", bias=-0.1 if far else 0.06)
            kx, ky = int(round(x + dx * 0.55)), int(round((by + 5 + foot) / 2))
            f.add(ellipse(kx + 0.5, ky, 2.4, 1.8), M_ARMOR if not far else M_ARMOR_FAR, bias=0.12)
            if not far:
                f.recolor({(kx, ky - 1), (kx + 1, ky - 1)}, "steel_l")
            px_ = int(round(x + dx))
            sab = union(rect(px_ - 2, foot - 1, 6, 2), {(px_ + 4, foot)})
            f.add(sab, M_ARMOR_FAR if far else M_ARMOR, flat=1 if far else 2)
            if not far:
                f.recolor({(px_ - 2 + k, foot - 1) for k in range(6)}, "steel")
    # tassets
    tas = poly([(bx - 7, by + 2), (bx + 7, by + 2), (bx + 8.5, by + 8), (bx + 2, by + 8.5), (bx - 2, by + 8.5),
                (bx - 8, by + 8)])
    f.add(tas, M_ARMOR, centre=(bx - 2, by + 2), radius=(9, 7), bias=0.08)
    trim(f, tas, "steel", "bottom")
    f.recolor({(int(bx), y) for y in range(int(by + 4), int(by + 9))} & tas, "ink")
    # breastplate: black with silver trim, the black wolf sigil in silver, rust-tan chest fur at the collar
    chest = union(ellipse(bx, by - 2.0, 7.6, 6.6), rect(int(bx - 6), int(by), 13, 3))
    f.add(chest, M_ARMOR, centre=(bx - 2, by - 5), radius=(8, 7.5), bias=0.12)
    trim(f, chest, "steel_l", "top")
    trim(f, chest, "steel", "left")
    belt = {(x, y) for (x, y) in chest if y in (int(by + 1), int(by + 2))}
    f.recolor(belt, "umber")
    f.recolor({(x, y) for (x, y) in belt if y == int(by + 1)}, "brown_d")
    f.dots([(int(bx + 1), int(by + 1)), (int(bx + 2), int(by + 1)), (int(bx + 1), int(by + 2)), (int(bx + 2), int(by + 2))],
           "steel_l")
    f.dot(int(bx + 2), int(by + 2), "steel")
    f.add(ellipse(bx + 2.5, by - 7.8, 3.6, 1.9), TAN, bias=0.1)
    wolf_sigil(f, int(bx - 3), int(by - 5), "steel_l", "lilac")
    mordred_head(f, hx, hy, eyes, mouth, ear_dy, tilt)
    # the scabbard raised in the far paw (guard / summon)
    if scab is not None:
        sx0, sy0, sx1, sy1 = scab
        f.add(capsule(bx - 2, by - 5, (sx0 + sx1) / 2, (sy0 + sy1) / 2, 1.7), M_ARMOR_FAR, bias=0.05)
        scabbard(f, sx0, sy0, sx1, sy1, scab_glow)
    # near arm: gauntlet, the sword and the wolf-head pauldron on top
    if hand is None:
        hand = (bx + 7.5, by + 2.0)
    m_sword(f, hand[0], hand[1], sword_deg, sword_len)
    f.add(union(capsule(bx + 2.5, by - 4.5, hand[0], hand[1], 1.9), ellipse(hand[0], hand[1], 2.1, 2.0)), M_ARMOR,
          bias=0.16)
    f.dots([(int(round(hand[0])), int(round(hand[1] - 1)))], "steel_l")
    wolf_pauldron(f, bx + 1.5, by - 6.5)
    if extra:
        extra(f)
    return f


def _purple_arc(f: Fig, cx: float, cy: float, r0: float, r1: float, a0: float, a1: float, strong: int) -> None:
    """The big purple crescent of the slash: a thin white leading edge, lilac then violet and plum trailing off."""
    for y in range(48):
        for x in range(48):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            ang = math.degrees(math.atan2(-(y + 0.5 - cy), x + 0.5 - cx))
            if r0 <= d <= r1 and a0 <= ang <= a1:
                t = (d - r0) / (r1 - r0)
                fade_a = min(1.0, (a1 - ang) / 25.0)          # the tail of the swing fades out
                if t > 0.86:
                    col, a = "white", 250
                elif t > 0.6:
                    col, a = "lilac", 245
                elif t > 0.3:
                    col, a = "violet", 235
                else:
                    col, a = "plum", 200
                a = int(a * (0.45 + 0.55 * fade_a)) if strong == 2 else int(a * 0.55 * (0.4 + 0.6 * fade_a))
                f.glow(x, y, alpha_px(col, a))


def _barrier(f: Fig, k: int) -> None:
    """The scabbard's purple barrier: a tall shimmering dome in front of him with a hexagon pattern."""
    cx, cy = 29.0, 26.0
    for y in range(3, 46):
        for x in range(29, 48):
            d = math.hypot((x + 0.5 - cx) / 16.0, (y + 0.5 - cy) / 21.5)
            if 0.8 <= d <= 1.0:
                edge = d > 0.92
                hexl = ((x + (y // 3) * 2 + k) % 6 == 0) or (y % 6 == (k * 2) % 6 and (x + k) % 2 == 0)
                if edge:
                    f.glow(x, y, alpha_px("lilac" if (x + y + k) % 4 else "white", 235))
                elif hexl:
                    f.glow(x, y, alpha_px("lilac", 170))
                else:
                    f.glow(x, y, alpha_px("violet", 110))


def _rising_shadows(f: Fig, k: int) -> None:
    """Summon: shadows rise from the ground around him, autumn leaves swirling into them."""
    for i, x0 in enumerate((3, 9, 37, 43)):
        h = 6 + ((i + k) % 3) * 3 + k * 2
        for j in range(h):
            x = x0 + int(round(math.sin(j * 0.6 + i + k) * 1.2))
            y = GROUND48 - j
            f.glow(x, y, alpha_px("dusk" if j < h - 2 else "violet", 230 - j * 8))
            f.glow(x + 1, y, alpha_px("plum", 190 - j * 6))
        f.glow(x0, GROUND48 - h, alpha_px("lilac", 220))
    for i in range(5):
        a = i * 1.26 + k * 0.7
        x, y = int(round(24 + math.cos(a) * (18 - k))), int(round(22 + math.sin(a) * 9 - k * 3))
        col = ("orange", "gold", "red_d", "amber", "brown")[(i + k) % 5]
        f.glow(x, y, col)
        f.glow(x + 1, y + (1 if i % 2 else 0), col)
        f.glow(x - 1, y, alpha_px("violet", 170))


def mordred_down(k: int) -> Canvas:
    """Kneels on one knee, the sword planted point-down in front, head bowed - beaten, never hurt."""
    f = mordred_frame(kneel=True, eyes="closed", mouth="frown", head_dy=1, ear_dy=2, tilt=-0.8, hand=(30.5, 33.0),
                      sword_deg=-90, sword_len=8, scab_glow=90 if k == 0 else 40)
    return f.render()


def mordred() -> list[Anim]:
    M = mordred_frame
    idle = [M(), M(bob=1, cape_wave=0.6, scab_glow=130), M(bob=1, cape_wave=1.0, scab_glow=110, tilt=0.9),
            M(cape_wave=0.4, scab_glow=140)]
    run_legs = [((0, -3.0), (0, 3.0)), ((2, -1.0), (0, 1.5)), ((3, 1.0), (0, -1.5)),
                ((0, 3.0), (0, -3.0)), ((0, 1.5), (2, -1.0)), ((0, -1.5), (3, 1.0))]
    run_bob = [0, 1, -1, 0, 1, -1]
    run = [M(bob=run_bob[i], lean=1.0, legs=run_legs[i], cape_lift=0.7, cape_wave=i % 2, eyes="open", tilt=0.0,
             hand=(29.5, 31.0 + run_bob[i]), sword_deg=-28, ear_dy=1 if run_bob[i] < 0 else 0) for i in range(6)]
    attack = [M(lean=-1.5, hand=(21.0, 20.0), sword_deg=125, eyes="angry", mouth="smirk"),
              M(lean=2.0, hand=(32.0, 26.0), sword_deg=-12, eyes="angry", mouth="shout", legs=((0, -2.0), (0, 3.0)),
                extra=lambda f: _purple_arc(f, 25, 26, 14, 19, -45, 75, 1)),
              M(lean=1.5, hand=(30.5, 30.0), sword_deg=-45, eyes="angry", legs=((0, -2.0), (0, 3.0))),
              M(lean=0.5)]
    hurt = [M(lean=-2.0, head_dy=1, eyes="squint", mouth="o", ear_dy=2, tilt=-0.4,
              extra=lambda f: stars(f, [(16, 3), (32, 2)])),
            M(lean=-1.5, eyes="squint", mouth="frown", ear_dy=1, tilt=-0.2)]
    dash = [M(lean=3.0, bob=1, legs=((0, -3.0), (2, 4.0)), cape_lift=1.0, cape_wave=0, eyes="angry", mouth="smirk",
              hand=(33.0, 28.0), sword_deg=2, sword_len=12, tilt=-0.2, ear_dy=2,
              extra=lambda f: speed_lines(f, [(1, 15), (0, 21), (2, 27), (0, 33)], 0, "lilac", 4)),
            M(lean=3.0, bob=0, legs=((1, -4.0), (0, 3.0)), cape_lift=1.0, cape_wave=1, eyes="angry", mouth="smirk",
              hand=(33.0, 27.5), sword_deg=2, sword_len=12, tilt=-0.2, ear_dy=2,
              extra=lambda f: speed_lines(f, [(0, 16), (1, 22), (0, 28), (2, 34)], 1, "lilac", 4))]
    slash = [M(lean=-2.0, bob=-1, hand=(18.0, 16.0), sword_deg=110, sword_len=13, eyes="angry", mouth="smirk", ear_dy=1,
               scab_glow=200),
             M(lean=2.0, hand=(32.0, 25.0), sword_deg=8, eyes="angry", mouth="shout", legs=((0, -2.5), (0, 3.5)),
               scab_glow=220, extra=lambda f: _purple_arc(f, 21, 25, 15, 25, -60, 85, 2)),
             M(lean=2.0, hand=(31.0, 30.0), sword_deg=-50, eyes="proud", mouth="smirk", legs=((0, -2.5), (0, 3.5)),
               scab_glow=160, extra=lambda f: _purple_arc(f, 21, 25, 17, 25, -75, 15, 1)),
             M(lean=0.5)]
    guard_scab = (29.5, 30.0, 33.5, 14.0)
    guard = [M(lean=-1.0, hand=(24.0, 33.0), sword_deg=-120, sword_len=10, eyes="angry", mouth="smirk",
               scab=guard_scab, scab_glow=230, extra=lambda f: _barrier(f, 0)),
             M(lean=-1.0, hand=(24.0, 33.0), sword_deg=-120, sword_len=10, eyes="angry", mouth="smirk",
               scab=guard_scab, scab_glow=190, extra=lambda f: _barrier(f, 1))]
    summon = [M(bob=-1, hand=(27.0, 17.0), sword_deg=88, sword_len=11, eyes="proud", mouth="smirk", tilt=1.2,
                scab_glow=210, extra=lambda f: _rising_shadows(f, 0)),
              M(bob=-1, hand=(27.0, 16.0), sword_deg=88, sword_len=11, eyes="open", mouth="shout", tilt=1.4,
                scab_glow=250, extra=lambda f: (_rising_shadows(f, 1), sparkle(f, 28, 2, "white", "lilac", 2))),
              M(bob=-1, hand=(27.0, 17.0), sword_deg=88, sword_len=11, eyes="proud", mouth="smirk", tilt=1.2,
                scab_glow=210, extra=lambda f: _rising_shadows(f, 2))]
    down = [mordred_down(0), mordred_down(1)]
    return [anim("idle", R(idle), 5.0, True), anim("run", R(run), 12.0, True),
            anim("attack", R(attack), 14.0, False, [1.0, 1.0, 1.0, 0.8]),
            anim("hurt", R(hurt), 6.0, False, [1.0, 3.0]), anim("dash", R(dash), 12.0, True),
            anim("slash", R(slash), 12.0, False, [1.4, 1.0, 1.0, 0.8]), anim("guard", R(guard), 6.0, True),
            anim("summon", R(summon), 8.0, False, [1.0, 1.0, 1.0]), anim("down", down, 2.0, False)]


# ---------------------------------------------------------------------------
# kraken 章魚王 (64, stands 8 px higher): a chubby coral-red octopus with a seashell crown and the black wolf-head
# sigil on its forehead; it is really just hungry
# ---------------------------------------------------------------------------

OCTO = Mat(["red_d", "red", "coral", "peach"], outline="wine", lit="red_d", sep="wine", sep_lit="red_d")
OCTO_FAR = Mat(["wine", "red_d", "red", "coral"], outline="wine", lit="wine", sep="wine", sep_lit="wine")
OCTO_EYE = Mat(["fog", "white", "white"], outline="wine", lit="red_d")
SHELL_C = Mat(["rose", "pink", "peach", "cream"], outline="wine", lit="red_d")
GOLD_C = Mat(["gold_d", "gold", "yellow", "cream"], outline="brown_d", lit="brown", spec="white", spec_at=0.82)
INK_CLOUD = Mat(["ink", "navy", "night_d", "plum"], outline="ink", lit="ink")


def tentacle_path(x0: float, y0: float, d: int, reach: float, curl: float, lift: float = 0.0) -> list:
    """A tentacle from under the mantle (x0, y0) down to the ground and out sideways (d = +1 right, -1 left),
    its tip curling up into a little spiral; `lift` raises the outer part off the ground."""
    g = GROUND64 - 2.6
    pts = [(x0, y0), (x0 + d * reach * 0.3, y0 + (g - y0) * 0.7), (x0 + d * reach * 0.62, g - lift * 0.4),
           (x0 + d * reach * 0.9, g - lift)]
    tx, ty = pts[-1]
    for k in range(1, 5):
        a = math.radians(-90 + k * (60 + curl * 25)) if d > 0 else math.radians(270 - k * (60 + curl * 25))
        r = 2.6 - k * 0.35
        pts.append((tx + d * (1.2 + math.cos(a) * r * 0.6), ty - 1.6 - k * 0.6 + math.sin(a) * r * 0.5))
    return pts


def draw_tentacle(f: Fig, pts: list, mat: Mat, r0: float = 3.2, r1: float = 0.9, suckers: bool = True,
                  bias: float = 0.0) -> set:
    shape = set()
    n = len(pts) - 1
    for i in range(n):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        shape |= capsule(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], (ra + rb) / 2)
    f.add(shape, mat, bias=bias)
    if suckers:
        dots = set()
        for i in range(1, n):
            x, y = pts[i]
            dots.add((int(round(x)), int(round(y + (r0 + (r1 - r0) * i / n) * 0.6))))
        f.recolor({p for p in dots if p in shape and (p[0], p[1] + 1) in shape}, "peach")
    return shape


def shell_fan(f: Fig, x: float, y: float, r: float, mat: Mat = SHELL_C) -> None:
    """A scallop shell standing up (a fan with ridges)."""
    fan = {(px, py) for (px, py) in ellipse(x, y, r, r * 1.05) if py <= y + 0.4}
    fan |= rect(int(round(x - 1)), int(round(y)), 3, 2)
    f.add(fan, mat, centre=(x - 1, y - r * 0.7), radius=(r, r), bias=0.12)
    for k in (-2, 0, 2):
        f.recolor({p for p in line_px(x, y + 0.5, x + k * r * 0.4, y - r * 0.9)} & fan, "rose")


def kraken_frame(bob: int = 0, lean: float = 0.0, puff: float = 0.0, eyes: str = "open", mouth: str = "o",
                 curl: float = 0.0, reach=(1.0, 1.0, 1.0, 1.0, 1.0, 1.0), lifts=(0, 0, 0, 0, 0, 0), arms=None,
                 sigil: bool = True, crown_tilt: float = 0.0, extra_back=None, extra=None) -> Fig:
    """arms: optional list of (x, y) tip points for the two front tentacles when raised (slam / summon / attack)."""
    f = Fig(64, 64, seed=211)
    cx = 30.0 + lean
    my = 29.0 + bob
    rx, ry = 16.5 + puff * 1.5, 14.0 + puff * 0.6
    if extra_back:
        extra_back(f)
    # back tentacles (darker), then the mantle, then the front tentacles
    base_y = my + ry - 4.5
    specs = [(cx - 8, -1, 22, OCTO_FAR), (cx + 9, 1, 22, OCTO_FAR), (cx - 11, -1, 15, OCTO), (cx + 12, 1, 15, OCTO),
             (cx - 4, -1, 9, OCTO), (cx + 6, 1, 10, OCTO)]
    for i, (x0, d, reach_, mat) in enumerate(specs[:2]):
        draw_tentacle(f, tentacle_path(x0, base_y, d, reach_ * reach[i], curl + i * 0.3, lifts[i]), mat, 3.4, 1.0,
                      bias=-0.1)
    body = union(ellipse(cx, my, rx, ry), ellipse(cx, my + ry * 0.5, rx * 0.9, ry * 0.55))
    f.add(body, OCTO, centre=(cx - 4, my - 5), radius=(rx + 2, ry + 2), bias=0.06)
    # spots on the crown of the mantle, a pale underside
    for (sx, sy) in ((-9, -6), (-5, -10), (-12, -1), (6, -9), (-8, 3)):
        f.recolor({(int(cx + sx), int(my + sy)), (int(cx + sx) + 1, int(my + sy)), (int(cx + sx), int(my + sy) + 1)}
                  & body, "red_d")
    f.recolor({(x, y) for (x, y) in body if y >= my + ry * 0.62}, "coral")
    f.recolor({(x, y) for (x, y) in body if y >= my + ry * 0.8}, "peach")
    for i, (x0, d, reach_, mat) in enumerate(specs[2:]):
        if arms is not None and i >= 2:
            continue
        draw_tentacle(f, tentacle_path(x0, base_y, d, reach_ * reach[i + 2], curl + i * 0.4, lifts[i + 2]), mat, 4.2, 1.2,
                      bias=0.04)
    # face: two big round eyes, cheeks, a little mouth
    ex0, ey0 = cx + 1.0 + lean * 0.3, my + 3.0
    for k, (ex, er) in enumerate(((ex0, 3.9), (ex0 + 10.0, 3.5))):
        eye = ellipse(ex, ey0, er, er * 1.1)
        if eyes in ("open", "angry", "shy", "wide"):
            f.add(eye, OCTO_EYE, bias=0.12)
            px_, py_ = int(round(ex + 0.6)), int(round(ey0))
            pupil = [(px_, py_ - 1), (px_ + 1, py_ - 1), (px_, py_), (px_ + 1, py_), (px_, py_ + 1), (px_ + 1, py_ + 1),
                     (px_ + 2, py_), (px_ + 2, py_ + 1), (px_ - 1, py_), (px_ - 1, py_ + 1)]
            if eyes == "wide":
                pupil = [(px_, py_), (px_ + 1, py_)]
            if eyes == "shy":
                pupil = [(p[0] - 1, p[1] + 1) for p in pupil]
            f.dots(pupil, "ink")
            f.dot(pupil[0][0], pupil[0][1], "white")
            if eyes == "angry":
                f.dots([(px_ - 2 + j, py_ - 3 - (j if k == 0 else 3 - j) // 2) for j in range(5)], "wine")
        elif eyes == "squint":
            xi, yi = int(round(ex)), int(round(ey0))
            f.dots([(xi - 1, yi - 1), (xi, yi), (xi + 1, yi + 1), (xi, yi + 2), (xi - 1, yi + 3)] if k == 0 else
                   [(xi + 1, yi - 1), (xi, yi), (xi - 1, yi + 1), (xi, yi + 2), (xi + 1, yi + 3)], "wine")
        elif eyes == "closed":
            xi, yi = int(round(ex)), int(round(ey0))
            f.dots([(xi - 2, yi), (xi - 1, yi + 1), (xi, yi + 1), (xi + 1, yi + 1), (xi + 2, yi)], "wine")
        elif eyes == "happy":
            xi, yi = int(round(ex)), int(round(ey0))
            f.dots([(xi - 2, yi + 1), (xi - 1, yi), (xi, yi - 1), (xi + 1, yi), (xi + 2, yi + 1)], "wine")
    cxi, cyi = int(round(ex0 + 5.0)), int(round(ey0 + 5.0))
    f.dots([(int(round(ex0 - 4)), cyi - 1), (int(round(ex0 - 3)), cyi - 1), (int(round(ex0 + 13)), cyi - 1),
            (int(round(ex0 + 14)), cyi - 1)], "pink")
    if mouth == "o":
        f.dots([(cxi, cyi), (cxi + 1, cyi), (cxi, cyi + 1), (cxi + 1, cyi + 1)], "wine")
    elif mouth == "puff":
        f.dots([(cxi - 1, cyi), (cxi, cyi + 1), (cxi + 1, cyi + 1), (cxi + 2, cyi)], "wine")
    elif mouth == "open":
        f.dots([(cxi - 1, cyi), (cxi, cyi), (cxi + 1, cyi), (cxi + 2, cyi), (cxi - 1, cyi + 1), (cxi, cyi + 1),
                (cxi + 1, cyi + 1), (cxi + 2, cyi + 1), (cxi, cyi + 2), (cxi + 1, cyi + 2)], "wine")
        f.dots([(cxi, cyi + 2), (cxi + 1, cyi + 2)], "pink")
    elif mouth == "smile":
        f.dots([(cxi - 1, cyi), (cxi, cyi + 1), (cxi + 1, cyi + 1), (cxi + 2, cyi)], "wine")
    elif mouth == "wobble":
        f.dots([(cxi - 1, cyi + 1), (cxi, cyi), (cxi + 1, cyi + 1), (cxi + 2, cyi)], "wine")
    # the black wolf-head sigil on the forehead (glowing violet edge)
    if sigil:
        sx, sy = int(round(cx + 1 + lean * 0.3)), int(round(my - 8))
        rows = ["..x.x....", ".xx.xx...", ".xxxxxx..", "xxxxxxxxx", ".xxxxxxx.", "..xxxx...", "...xx...."]
        pts = [(sx + i, sy + j) for j, row in enumerate(rows) for i, ch in enumerate(row) if ch == "x"]
        f.recolor(set(pts), "ink")
        f.recolor({(sx + 4, sy + 2)}, "lilac")
        ring = {(x + dx, y + dy) for (x, y) in pts for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1))} - set(pts)
        f.recolor(ring & body, "violet")
    # the seashell crown: a gold band with three scallop shells and pearls
    t = crown_tilt
    kx, ky = cx - 1 + t * 2, my - ry + 3.0 + abs(t)
    for j, (dx, r) in enumerate(((-7.0, 3.4), (0.0, 4.6), (7.0, 3.4))):
        shell_fan(f, kx + dx + t * (1 if j else 0), ky - 0.5 - (1.5 if j == 1 else 0) + t * (j - 1) * 0.8, r)
    band = {(x, y) for (x, y) in ellipse(kx, ky + 1.0, 11.0, 3.0) if y >= ky}
    band |= {(x, y) for (x, y) in ellipse(kx, ky + 1.0, 11.0, 3.0) if y >= ky - 1 and abs(x - kx) > 8}
    f.add(band, GOLD_C, centre=(kx - 4, ky - 1), radius=(10, 4), bias=0.12)
    f.dots([(int(round(kx - 10)), int(round(ky + 1))), (int(round(kx - 3.5)), int(round(ky + 2))),
            (int(round(kx + 3.5)), int(round(ky + 2))), (int(round(kx + 10)), int(round(ky + 1)))], "white")
    f.dots([(int(round(kx - 3.5)), int(round(ky + 3))), (int(round(kx + 3.5)), int(round(ky + 3)))], "fog")
    # raised front tentacles (drawn over the body)
    if arms is not None:
        for i, (tx, ty) in enumerate(arms):
            x0 = cx - 7 if i == 0 else cx + 9
            mx_, my_ = (x0 + tx) / 2 + (-3 if i == 0 else 3), (base_y + ty) / 2
            pts = [(x0, base_y), (mx_, my_), (tx, ty)]
            # small curl at the tip
            dd = -1 if tx < x0 else 1
            pts += [(tx + dd * 1.5, ty - 1.2), (tx + dd * 1.0, ty - 2.6)]
            draw_tentacle(f, pts, OCTO, 4.0, 1.2, bias=0.08)
    if extra:
        extra(f)
    return f


def _bubbles(f: Fig, pts) -> None:
    for (x, y, r) in pts:
        for (px, py) in P.edge(P.ellipse(x, y, r, r)):
            f.glow(px, py, alpha_px("sky_l", 220))
        f.glow(int(x - r * 0.4), int(y - r * 0.4), "white")


def _ink_cloud(f: Fig, k: int) -> None:
    blobs = [((48, 36, 6), (55, 32, 5), (58, 40, 4.5)), ((50, 34, 7.5), (57, 30, 6), (60, 40, 5.5), (44, 40, 4)),
             ((52, 33, 8), (59, 29, 5.5), (60, 41, 6), (46, 41, 4.5))][k]
    shape = set()
    for (x, y, r) in blobs:
        shape |= ellipse(x, y, r, r * 0.85)
    f.add(shape, INK_CLOUD, centre=(50, 28), radius=(12, 10), bias=0.15, sep=False)
    for (x, y, r) in blobs:
        f.recolor({(int(x - r * 0.4), int(y - r * 0.45)), (int(x - r * 0.4) + 1, int(y - r * 0.45))}, "violet")
        f.recolor({(int(x - r * 0.4), int(y - r * 0.45))}, "lilac")


def _slam_dust(f: Fig, x: int, k: int) -> None:
    g = GROUND64
    for i, dx in enumerate((-8, -4, 0, 4, 8)):
        r = 2.2 - abs(dx) * 0.12 + (k * 0.6)
        for (px, py) in P.ellipse(x + dx * (1 + k * 0.4), g - 1 - (i % 2), r, r * 0.75):
            f.glow(px, py, alpha_px("sand" if i % 2 else "white", 220 - k * 70))
    if k == 0:
        sparkle(f, x - 3, g - 9, "white", "yellow", 2)
        sparkle(f, x + 5, g - 7, "yellow", "amber", 1)


def kraken_down(k: int) -> Canvas:
    """Curls into a shy ball: tentacles hugging the mantle, eyes peeking, crown askew; the sigil breaks into
    sparkles and is gone (never hurt)."""
    def front(f: Fig) -> None:
        # two tentacles wrapped around the front like a shy hug
        for (pts, b) in (([(16, 47), (24, 52), (38, 52), (46, 47), (45, 43)], 0.05),
                         ([(47, 50), (38, 48), (28, 46), (23, 42), (25, 39)], 0.1)):
            draw_tentacle(f, pts, OCTO, 3.8, 1.5, bias=b)
        if k:
            for (x, y) in ((30, 12), (37, 8), (25, 6), (42, 14)):
                sparkle(f, x, y, "white", "lilac", 1)
        else:
            for (x, y) in ((31, 19), (35, 18), (33, 16)):
                f.glow(x, y, alpha_px("lilac", 210))
    f = kraken_frame(bob=6, puff=-0.8, eyes="shy", mouth="wobble", curl=1.5, reach=(0.5, 0.5, 0.35, 0.35, 0.3, 0.3),
                     sigil=False, crown_tilt=-1.5, arms=[], extra=front)
    return f.render()


def kraken() -> list[Anim]:
    K = kraken_frame
    idle = [K(), K(bob=1, puff=0.2, curl=0.4), K(bob=1, puff=0.3, curl=0.8, eyes="happy", mouth="smile"),
            K(puff=0.1, curl=0.4)]
    run = [K(bob=-(i % 2), lean=1, curl=0.5 * (i % 3), reach=tuple(0.8 + 0.3 * ((i + j) % 2) for j in range(6)),
             lifts=tuple(2 * ((i + j) % 2) for j in range(6))) for i in range(6)]
    attack = [K(lean=-1.5, eyes="angry", mouth="o", arms=[(8, 40), (52, 22)]),
              K(lean=2.0, eyes="angry", mouth="open", arms=[(8, 44), (62, 42)],
                extra=lambda f: _whip_smear64(f, 46, 42)),
              K(lean=1.5, eyes="angry", mouth="o", arms=[(8, 46), (60, 50)]),
              K(lean=0.5)]
    hurt = [K(lean=-2, puff=-0.3, eyes="squint", mouth="wobble", curl=1.2, extra=lambda f: stars(f, [(16, 6), (46, 4)])),
            K(lean=-1, puff=-0.2, eyes="squint", mouth="wobble", curl=1.0)]
    slam = [K(bob=-2, eyes="angry", mouth="open", arms=[(6, 8), (56, 6)]),
            K(bob=1, lean=1, eyes="angry", mouth="open", arms=[(8, 50), (58, 51)],
              extra=lambda f: (_slam_dust(f, 57, 0), _slam_dust(f, 8, 0))),
            K(bob=1, lean=1, eyes="happy", mouth="smile", arms=[(8, 50), (58, 51)],
              extra=lambda f: (_slam_dust(f, 57, 1), _slam_dust(f, 8, 1)))]
    ink = [K(puff=1.0, eyes="closed", mouth="puff", curl=0.6),
           K(puff=-0.4, lean=-1, eyes="closed", mouth="o", extra=lambda f: _ink_cloud(f, 0)),
           K(puff=-0.2, lean=-0.5, eyes="happy", mouth="o", extra=lambda f: _ink_cloud(f, 1))]
    summon = [K(bob=-1, eyes="angry", mouth="open", arms=[(6, 18), (56, 16)],
                extra=lambda f: _bubbles(f, [(5, 40, 2), (59, 36, 2.5), (10, 28, 1.5)])),
              K(bob=-2, eyes="angry", mouth="open", arms=[(5, 14), (58, 12)],
                extra=lambda f: _bubbles(f, [(4, 32, 2.5), (60, 28, 3), (10, 20, 2), (54, 22, 1.5)])),
              K(bob=-1, eyes="happy", mouth="smile", arms=[(6, 18), (56, 16)],
                extra=lambda f: _bubbles(f, [(5, 24, 3), (59, 20, 2.5), (12, 10, 2), (52, 8, 2)]))]
    down = [kraken_down(0), kraken_down(1)]
    return [anim("idle", R(idle), 5.0, True), anim("run", R(run), 10.0, True),
            anim("attack", R(attack), 12.0, False, [1.2, 0.8, 1.0, 1.0]),
            anim("hurt", R(hurt), 6.0, False, [1.0, 3.0]), anim("slam", R(slam), 10.0, False, [1.4, 0.8, 1.2]),
            anim("ink", R(ink), 8.0, False), anim("summon", R(summon), 8.0, False), anim("down", down, 2.0, False)]


def _whip_smear64(f: Fig, cx: float, cy: float) -> None:
    for y in range(64):
        for x in range(64):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.6)
            ang = math.degrees(math.atan2(-(y + 0.5 - cy), x + 0.5 - cx))
            if 12 <= d <= 17 and -30 <= ang <= 60:
                f.glow(x, y, alpha_px("white" if d > 15.5 else "peach", 190 if d > 15.5 else 90))


# ---------------------------------------------------------------------------
# red_dragon 紅龍 / white_dragon 白龍 (64, stand 8 px higher): round, chubby and cute, small wings, big eyes
# ---------------------------------------------------------------------------

DRAGONS = {
    "red": {
        "skin": Mat(["wine", "red_d", "red", "coral"], outline="umber", lit="wine", sep="wine", sep_lit="red_d"),
        "skin_far": Mat(["umber", "wine", "red_d", "red"], outline="umber", lit="umber", sep="umber", sep_lit="wine"),
        "belly": Mat(["gold_d", "gold", "gold_l", "yellow"], outline="brown_d", lit="gold_d"),
        "horn": Mat(["gold_d", "gold", "gold_l", "cream"], outline="brown_d", lit="gold_d"),
        "wing": Mat(["wine", "red_d", "rose", "pink"], outline="umber", lit="wine", sep="wine", sep_lit="red_d"),
        "mane": None, "iris": "amber", "claw": "cream", "line": "wine", "seg": "gold_d",
        "breath": (["white", "yellow", "amber", "orange", "red"], "red_d"), "puff": "ash",
    },
    "white": {
        "skin": Mat(["ash", "fog", "white", "white"], outline="slate", lit="ash", sep="ash", sep_lit="fog"),
        "skin_far": Mat(["slate", "ash", "fog", "white"], outline="slate", lit="slate", sep="slate", sep_lit="ash"),
        "belly": Mat(["sky", "azure", "sky_l", "white"], outline="water_d", lit="water"),
        "horn": Mat(["water", "sky", "azure", "sky_l"], outline="water_d", lit="water"),
        "wing": Mat(["ash", "fog", "azure", "sky_l"], outline="slate", lit="ash", sep="ash", sep_lit="fog"),
        "mane": Mat(["water", "sky", "azure", "sky_l"], outline="water_d", lit="water", sep="water", sep_lit="sky"),
        "iris": "sky", "claw": "sky_l", "line": "slate", "seg": "sky",
        "breath": (["white", "sky_l", "azure", "sky", "water"], "water_d"), "puff": "sky_l",
    },
}


def dragon_wing(f: Fig, sx: float, sy: float, mat: Mat, bone: str, flap: float = 0.0, far: bool = False) -> None:
    """A small bat wing from the shoulder (sx, sy): wrist up-back, three finger tips, scalloped membrane."""
    lift = flap * 4
    wx, wy = sx - 5.5, sy - 9.0 - lift
    tips = [(sx - 12.5, sy - 13.0 - lift * 1.4), (sx - 15.0, sy - 6.5 - lift * 0.8), (sx - 12.0, sy - 1.0 - lift * 0.3)]
    if far:
        wx, wy = wx + 3, wy + 1
        tips = [(x + 3, y + 1) for (x, y) in tips]
    pts = [(sx + 1, sy), (wx, wy - 0.5)]
    prev = (wx, wy)
    for i, (tx, ty) in enumerate(tips):
        if i:
            mx, my = (prev[0] + tx) / 2, (prev[1] + ty) / 2
            pts.append((mx + (wx - mx) * 0.3, my + (wy - my) * 0.3))
        pts.append((tx, ty))
        prev = (tx, ty)
    pts.append((sx - 1, sy + 4))
    shape = poly(pts)
    f.add(shape, mat, centre=(wx, wy), radius=(8, 8), bias=-0.15 if far else 0.05, contrast=0.85)
    if not far:
        f.recolor({p for p in line_px(sx, sy, wx, wy)} & shape, bone)
        for (tx, ty) in tips:
            f.recolor({p for p in line_px(wx, wy, tx, ty)} & shape, bone)


def dragon_frame(kind: str, bob: int = 0, lean: float = 0.0, eyes: str = "open", mouth: str = "smile",
                 legs=((0, 0.0), (0, 0.0)), flap: float = 0.0, tail: float = 0.0, head_dy: float = 0.0,
                 head_dx: float = 0.0, arm: str = "rest", sit: bool = False, puff: float = 0.0, extra=None) -> Fig:
    S = DRAGONS[kind]
    skin, skin_far, belly, horn_m, wing = S["skin"], S["skin_far"], S["belly"], S["horn"], S["wing"]
    f = Fig(64, 64, seed=221 if kind == "red" else 231)
    g = GROUND64
    bx, by = 27.0 + lean, 41.0 + bob + (3 if sit else 0)
    hx, hy = bx + 8.0 + head_dx, by - 19.0 + head_dy
    # far wing, tail
    dragon_wing(f, bx - 3, by - 8, wing, S["line"], flap, far=True)
    ta = tail
    tp = [(bx - 8, by + 6), (bx - 15, by + 10 - ta), (bx - 21, by + 8 - ta * 2), (bx - 24, by + 2 - ta * 3)]
    if sit:
        tp = [(bx - 8, by + 7), (bx - 15, g - 2), (bx - 22, g - 2.5), (bx - 25, g - 6 - ta)]
    tshape = set()
    for i in range(len(tp) - 1):
        tshape |= capsule(tp[i][0], tp[i][1], tp[i + 1][0], tp[i + 1][1], 3.8 - i * 0.9)
    tshape = {(x, y) for (x, y) in tshape if y <= g}
    f.add(tshape, skin, centre=(bx - 14, by), radius=(10, 8), bias=0.02)
    ex_, ey_ = tp[-1]
    if kind == "red":
        tip = poly([(ex_ + 1.5, ey_ + 1.0), (ex_ - 2.5, ey_ - 3.5), (ex_ - 1.0, ey_ + 1.5), (ex_ - 3.5, ey_ + 3.5)])
        tip |= poly([(ex_ + 0.5, ey_ - 0.5), (ex_ - 0.5, ey_ - 5.0), (ex_ - 3.5, ey_ - 1.0)])
        f.add(tip, skin, bias=0.15)
    else:
        tip = poly([(ex_ + 1, ey_), (ex_ - 1.5, ey_ - 5), (ex_ - 2.5, ey_ + 0.5), (ex_ - 1.0, ey_ + 3)])
        f.add(tip, horn_m, bias=0.15)
    # legs: stubby with pale claws
    (fl, fdx), (nl, ndx) = legs
    if sit:
        # sitting on its bottom, both stubby legs sticking out forward, soles showing
        for (x, far) in ((bx + 2, True), (bx + 8, False)):
            leg = union(capsule(x - 4, g - 4, x + 5, g - 3.5, 3.4), ellipse(x + 6, g - 4.5, 2.4, 3.6))
            f.add(leg, skin_far if far else skin, bias=-0.1 if far else 0.08)
            f.recolor({(int(x + 7), g - 7 + k) for k in range(6)} & leg, belly.ramp[1])
            f.dots([(int(x + 8), g - 7), (int(x + 8), g - 4), (int(x + 8), g - 2)], S["claw"])
    else:
        for (x, lift, dx, far) in ((bx - 5.0, fl, fdx, True), (bx + 4.0, nl, ndx, False)):
            foot = g - lift
            thigh = ellipse(x + dx * 0.3, by + 6, 4.8, 4.6)
            shin = union(capsule(x + dx * 0.3, by + 7, x + dx, foot - 2, 3.0), rect(int(round(x + dx)) - 3, foot - 2, 8, 3))
            f.add(union(thigh, shin), skin_far if far else skin, centre=(x - 1, by + 4), radius=(5, 8),
                  bias=-0.12 if far else 0.04)
            px_ = int(round(x + dx))
            f.dots([(px_ + 4, foot), (px_ + 2, foot), (px_ + 4, foot - 1)], S["claw"])
    # body: a round pot belly
    body = union(ellipse(bx, by, 11.0, 10.0), ellipse(bx, by + 4.0, 12.0, 7.0))
    f.add(body, skin, centre=(bx - 4, by - 4), radius=(13, 12), bias=0.1)
    bel = {(x, y) for (x, y) in union(ellipse(bx + 4.5, by + 2.5, 6.8, 8.2)) if (x, y) in body}
    f.add(bel, belly, centre=(bx + 2, by - 1), radius=(7, 8), bias=0.08, sep=False)
    for yy in range(int(by - 3), int(by + 11), 3):
        f.recolor({(x, yy) for x in range(64)} & bel, S["seg"])
    # near wing on the back
    dragon_wing(f, bx - 2, by - 8, wing, S["line"], flap)
    # head: big and round with a snout, horns (and the white dragon's ice mane)
    if S["mane"] is not None:
        for i in range(5):
            mx_, my_ = hx - 7.5 - i * 0.6, hy - 5 + i * 3.4
            spike = poly([(mx_ + 2.5, my_ - 1.8), (mx_ - 4.5 - (i % 2), my_ - 0.5 + (i - 2) * 0.6), (mx_ + 2.0, my_ + 2.2)])
            f.add(spike, S["mane"], bias=0.1)
    for (ox, oy, far) in ((-4.5, -6.0, True), (0.5, -7.5, False)):
        b0x, b0y = hx + ox, hy + oy
        hshape = union(capsule(b0x, b0y, b0x - 2.0, b0y - 4.0, 1.6), capsule(b0x - 2.0, b0y - 4.0, b0x - 4.8, b0y - 6.2, 1.0))
        f.add(hshape, horn_m, bias=-0.1 if far else 0.12)
    head = union(ellipse(hx, hy, 10.0, 8.8), ellipse(hx - 0.5, hy + 2.0, 9.6, 7.6))
    f.add(head, skin, centre=(hx - 3, hy - 3), radius=(11, 10), bias=0.18)
    snout = union(ellipse(hx + 8.0, hy + 3.0 + puff * 0.3, 5.6 + puff * 0.6, 4.4 + puff * 0.8),
                  ellipse(hx + 5.5, hy + 4.5, 4.8, 3.8 + puff))
    f.add(snout, skin, centre=(hx + 6, hy + 0.5), radius=(6, 5), bias=0.24)
    # a pale chin / jaw like the belly
    f.recolor({(x, y) for (x, y) in snout if y >= hy + 6.6 + puff and x >= hx + 3}, belly.ramp[2])
    if S["mane"] is not None:
        # a soft ice-blue tuft on the brow
        tuft = poly([(hx - 3, hy - 7.5), (hx + 1, hy - 10.5), (hx + 0.5, hy - 7), (hx + 4, hy - 9.5), (hx + 3, hy - 6)])
        f.add(tuft, S["mane"], bias=0.15)
    hxi, hyi = int(round(hx)), int(round(hy))
    # nostrils and the jaw line
    f.dots([(hxi + 11, hyi + 1), (hxi + 12, hyi + 1)], S["line"])
    # cheek blush
    f.dots([(hxi + 2, hyi + 5), (hxi + 3, hyi + 5), (hxi + 4, hyi + 5)], "pink")
    # the big round eye
    ex, ey = hxi + 3, hyi - 1
    iris = S["iris"]
    if eyes in ("open", "angry", "sassy", "wide"):
        # a big round eye: ink rim, white, a large iris with a dark pupil and two glints
        rim = [(ex, ey - 2), (ex + 1, ey - 2), (ex + 2, ey - 2), (ex + 3, ey - 2), (ex - 1, ey - 1), (ex + 4, ey - 1),
               (ex - 1, ey), (ex + 4, ey), (ex - 1, ey + 1), (ex + 4, ey + 1), (ex - 1, ey + 2), (ex + 4, ey + 2),
               (ex, ey + 3), (ex + 1, ey + 3), (ex + 2, ey + 3), (ex + 3, ey + 3)]
        f.dots([(ex + i, ey + j) for i in range(4) for j in range(-1, 3)], "white")
        f.dots([(ex + 1, ey - 1), (ex + 2, ey - 1), (ex + 3, ey - 1), (ex + 1, ey), (ex + 2, ey), (ex + 3, ey),
                (ex + 1, ey + 1), (ex + 2, ey + 1), (ex + 3, ey + 1), (ex + 2, ey + 2), (ex + 3, ey + 2)], iris)
        f.dots([(ex + 2, ey), (ex + 3, ey), (ex + 2, ey + 1), (ex + 3, ey + 1)], "ink")
        f.dot(ex + 1, ey - 1, "white")
        f.dot(ex + 3, ey + 2, "white")
        f.dots(rim, "ink")
        if eyes == "angry":
            f.dots([(ex - 2, ey - 4), (ex - 1, ey - 4), (ex, ey - 3), (ex + 1, ey - 3), (ex + 2, ey - 3), (ex + 3, ey - 2),
                    (ex + 4, ey - 2)], S["line"])
            f.dots([(ex, ey - 2), (ex + 1, ey - 2), (ex + 2, ey - 2)], S["line"])
        if eyes == "sassy":         # a smug half-lidded look
            f.dots([(ex, ey - 2), (ex + 1, ey - 2), (ex + 2, ey - 2), (ex + 3, ey - 2), (ex, ey - 1), (ex + 1, ey - 1),
                    (ex + 2, ey - 1), (ex + 3, ey - 1)], S["skin"].ramp[1])
            f.dots([(ex - 1, ey), (ex, ey), (ex + 1, ey), (ex + 2, ey), (ex + 3, ey), (ex + 4, ey)], "ink")
            f.dots([(ex + 1, ey + 1)], "white")
        if eyes == "wide":
            f.dots([(ex + 1, ey), (ex + 1, ey + 1), (ex + 2, ey - 1), (ex + 3, ey - 1)], "white")
    elif eyes == "closed":
        f.dots([(ex - 1, ey + 1), (ex, ey + 2), (ex + 1, ey + 2), (ex + 2, ey + 2), (ex + 3, ey + 2), (ex + 4, ey + 1)],
               "ink")
    elif eyes == "happy":
        f.dots([(ex - 1, ey + 2), (ex, ey + 1), (ex + 1, ey), (ex + 2, ey), (ex + 3, ey + 1), (ex + 4, ey + 2)], "ink")
    elif eyes == "squint":
        f.dots([(ex, ey - 1), (ex + 1, ey), (ex + 2, ey + 1), (ex + 1, ey + 2), (ex, ey + 3)], "ink")
    elif eyes == "pout":
        f.dots([(ex - 1, ey + 1), (ex, ey + 1), (ex + 1, ey + 1), (ex + 2, ey + 1), (ex + 3, ey)], "ink")
        f.dots([(ex - 1, ey - 1), (ex, ey - 1), (ex + 1, ey - 2)], S["line"])
    mx, my = hxi + 8, hyi + 6
    if mouth == "smile":
        f.dots([(mx, my), (mx + 1, my + 1), (mx + 2, my + 1), (mx + 3, my + 1), (mx + 4, my)], S["line"])
        f.dot(mx + 2, my + 2, "white")
    elif mouth == "grin":
        f.dots([(mx, my), (mx + 1, my + 1), (mx + 2, my + 1), (mx + 3, my + 1), (mx + 4, my + 1), (mx + 5, my)], S["line"])
        f.dots([(mx + 1, my), (mx + 4, my)], "white")
    elif mouth in ("open", "roar"):
        h = 3 if mouth == "open" else 5
        f.dots([(mx + i, my + j) for i in range(6) for j in range(h)], "wine")
        f.dots([(mx + i, my + h - 1) for i in range(1, 5)], "pink")
        f.dots([(mx, my), (mx + 5, my)], "white")
        f.dots([(mx + i, my - 1) for i in range(6)], S["line"])
    elif mouth == "pout":
        f.dots([(mx + 1, my + 1), (mx + 2, my), (mx + 3, my), (mx + 4, my + 1)], S["line"])
    elif mouth == "puff":
        f.dots([(mx + 2, my + 1), (mx + 3, my + 1)], S["line"])
    elif mouth == "o":
        f.dots([(mx + 2, my), (mx + 3, my), (mx + 2, my + 1), (mx + 3, my + 1)], "wine")
    # arms: short, in front of the belly (crossed when sulking)
    if arm == "cross":
        # arms folded over the chest: the far forearm underneath, the near one on top, claws poking out
        f.add(union(capsule(bx + 2, by - 1.5, bx + 11, by - 3.0, 2.2), ellipse(bx + 11, by - 3, 2.2, 2.0)), skin_far,
              bias=0.05)
        f.add(union(capsule(bx + 10, by - 5.5, bx + 2, by - 4.5, 2.3), ellipse(bx + 2.5, by - 4.6, 2.4, 2.2)), skin,
              bias=0.15)
        f.dots([(int(bx + 13), int(by - 4)), (int(bx + 13), int(by - 2)), (int(bx), int(by - 6)), (int(bx), int(by - 4))],
               S["claw"])
    else:
        hand = {"rest": (bx + 9, by + 1), "up": (bx + 12, by - 8), "swipe": (bx + 16, by - 1), "wide": (bx + 13, by - 10),
                "back": (bx + 4, by - 6)}[arm]
        f.add(union(capsule(bx + 4, by - 5, hand[0], hand[1], 2.4), ellipse(hand[0], hand[1], 2.5, 2.3)), skin, bias=0.1)
        hx_, hy_ = int(round(hand[0])), int(round(hand[1]))
        f.dots([(hx_ + 2, hy_ - 1), (hx_ + 2, hy_ + 1), (hx_ + 1, hy_ + 2)], S["claw"])
    if extra:
        extra(f)
    return f


def _breath(f: Fig, kind: str, x0: float, y0: float, k: int, strong: bool = True) -> None:
    """Fire (red) or frost (white) breath: a widening cone from the mouth to the right edge."""
    ramp, edge = DRAGONS[kind]["breath"]
    rng = random.Random(17 + k)
    for x in range(int(x0), 64):
        t = (x - x0) / max(1.0, 64 - x0)
        h = 1.2 + (x - x0) * 0.42
        wob = math.sin(x * 0.7 + k * 2.0) * 1.0
        for y in range(int(y0 - h - 1), int(y0 + h + 2)):
            d = abs(y + 0.5 - (y0 + wob)) / h
            if d > 1.0:
                continue
            if d > 0.85:
                col, a = edge, 200
            else:
                idx = min(len(ramp) - 1, int(d * 3 + t * 2.2))
                col, a = ramp[idx], 245
            if not strong:
                a = int(a * 0.55)
            if rng.random() < 0.06 + t * 0.15:
                continue
            f.glow(x, y, alpha_px(col, a))
    if kind == "white":
        for i in range(4):
            sx = int(x0 + 6 + i * 6 + k)
            sy = int(y0 - 4 + ((i * 5 + k * 3) % 9))
            sparkle(f, sx, sy, "white", "sky", 1)


def _roar_lines(f: Fig, x: int, y: int, k: int) -> None:
    for i, r in enumerate((6 + k * 2, 10 + k * 2)):
        for a in range(-50, 55, 9):
            ar = math.radians(a)
            f.glow(int(round(x + math.cos(ar) * r)), int(round(y - math.sin(ar) * r * 1.1)),
                   alpha_px("white", 220 - i * 70))


def _sulk_puff(f: Fig, kind: str, x: int, y: int, k: int) -> None:
    col = DRAGONS[kind]["puff"]
    for (dx, dy, r) in ((0, 0, 1.6), (2 + k, -3 - k, 1.3), (4 + k, -6 - k * 2, 1.0)):
        for (px, py) in P.ellipse(x + dx, y + dy, r, r):
            f.glow(px, py, alpha_px(col, 210 - dy * -8))
    if kind == "red":
        # a little cross-popping anger mark
        ax, ay = 44 - k, 9 + k
        f.dots([(ax, ay), (ax + 2, ay), (ax + 1, ay - 1), (ax + 1, ay + 1), (ax, ay + 2), (ax + 2, ay + 2),
                (ax - 1, ay + 1), (ax + 3, ay + 1)], "red")
    else:
        sparkle(f, 46 - k, 8 + k, "white", "sky", 1)


def dragon(kind: str) -> list[Anim]:
    def D(**kw) -> Fig:
        return dragon_frame(kind, **kw)
    calm = "open" if kind == "red" else "sassy"
    idle = [D(eyes=calm), D(bob=1, flap=0.3, tail=0.4, eyes=calm), D(bob=1, flap=0.5, tail=0.7, eyes="happy", mouth="grin"),
            D(flap=0.2, tail=0.3, eyes=calm)]
    run_legs = [((0, -3.0), (0, 3.0)), ((2, -1.0), (0, 1.5)), ((3, 1.0), (0, -1.5)),
                ((0, 3.0), (0, -3.0)), ((0, 1.5), (2, -1.0)), ((0, -1.5), (3, 1.0))]
    run_bob = [0, 1, -1, 0, 1, -1]
    run = [D(bob=run_bob[i], lean=1, legs=run_legs[i], flap=0.8 * (i % 2), tail=-0.5 + 0.4 * (i % 2), eyes="open",
             mouth="grin" if i % 3 == 0 else "smile", head_dy=-0.5 * (i % 2)) for i in range(6)]
    attack = [D(lean=-1.5, arm="up", eyes="angry", mouth="o", flap=0.4),
              D(lean=2.0, arm="swipe", eyes="angry", mouth="open", flap=0.8, extra=lambda f: _claw_smear64(f, 48, 34)),
              D(lean=1.5, arm="rest", eyes="angry", mouth="smile"),
              D(lean=0.5, eyes=calm)]
    hurt = [D(lean=-2, head_dy=1, eyes="squint", mouth="o", tail=1.0, extra=lambda f: stars(f, [(26, 6), (44, 3)])),
            D(lean=-1, eyes="squint", mouth="pout", tail=0.6)]
    mouth_at = (45.0, 28.5)
    breath = [D(lean=-1.5, head_dy=-1.5, head_dx=-1, puff=1.0, eyes="closed", mouth="puff", arm="back", flap=0.5),
              D(lean=1.0, eyes="angry", mouth="open", arm="rest", flap=0.8,
                extra=lambda f: _breath(f, kind, mouth_at[0] + 1, mouth_at[1] + 1, 0)),
              D(lean=1.0, eyes="angry", mouth="open", arm="rest", flap=0.6,
                extra=lambda f: _breath(f, kind, mouth_at[0] + 1, mouth_at[1] + 1, 1)),
              D(lean=0.5, eyes="happy", mouth="smile", extra=lambda f: _breath(f, kind, mouth_at[0] + 4, mouth_at[1] + 1, 2,
                                                                              strong=False))]
    roar = [D(head_dy=-2, head_dx=-1, eyes="closed", mouth="o", arm="wide", flap=1.0),
            D(head_dy=-3, head_dx=-1, eyes="closed", mouth="roar", arm="wide", flap=1.2,
              extra=lambda f: _roar_lines(f, 49, 25, 0)),
            D(head_dy=-3, head_dx=-1, eyes="angry", mouth="roar", arm="wide", flap=1.0,
              extra=lambda f: _roar_lines(f, 49, 25, 1))]
    sulk = [D(sit=True, arm="cross", eyes="pout", mouth="pout", head_dx=-1, tail=0.0,
              extra=lambda f: _sulk_puff(f, kind, 50, 20, 0)),
            D(sit=True, arm="cross", eyes="pout", mouth="pout", head_dx=-1, head_dy=1, tail=1.0,
              extra=lambda f: _sulk_puff(f, kind, 50, 19, 1))]
    return [anim("idle", R(idle), 5.0, True), anim("run", R(run), 10.0, True),
            anim("attack", R(attack), 14.0, False, [1.0, 1.0, 1.0, 0.8]),
            anim("hurt", R(hurt), 6.0, False, [1.0, 3.0]), anim("breath", R(breath), 10.0, False, [1.2, 1.0, 1.0, 0.8]),
            anim("roar", R(roar), 8.0, False, [1.0, 1.4, 1.0]), anim("sulk", R(sulk), 3.0, True)]


def _claw_smear64(f: Fig, x: int, y: int) -> None:
    for k in range(3):
        for i in range(6):
            f.glow(x - 2 + i, y - 6 + k * 4 + i, alpha_px("white" if i > 2 else "peach", 220 - i * 18))


def red_dragon() -> list[Anim]:
    return dragon("red")


def white_dragon() -> list[Anim]:
    return dragon("white")


# ===========================================================================
# CC7 portraits, 48x48, in the storybook style of art_portraits / art_v26_cast: a painted bust on a small backdrop,
# one base per character plus an expression layer, drawn facing right and mirrored (all six speakers sit on the
# right of the dialogue box; dialogue_box.LEFT_SPEAKERS is goldie and bulldog only).
# ===========================================================================

PS = 48
PORTRAITS_V27: dict[str, list[str]] = {
    "tristan": ["normal", "happy", "serious", "surprised"],
    "gawain": ["normal", "happy", "serious"],
    "kraken": ["normal"],
    "red_dragon": ["normal"],
    "white_dragon": ["normal"],
    "mordred": ["normal", "smirk", "angry", "sad"],
}
_px = V._px
_stamp = V._stamp
P_URA = V.P_URA
P_STEEL = V.P_STEEL
P_CORGI = ["brown", "gold_d", "orange", "amber"]
P_SKYC = ["water", "sky", "azure", "sky_l"]
P_GREEN = ["forest", "leaf_d", "grass", "leaf"]
P_CAPB = ["navy", "night", "water_d", "water"]
P_REDF = ["red_d", "red", "coral", "pink"]
P_WOOD = ["umber", "brown_d", "brown", "gold_d"]
P_SB = ["brown_d", "brown", "gold_d", "gold"]
P_WHITE = ["ash", "fog", "white", "white"]
P_ORANGE = ["gold_d", "orange", "amber", "gold_l"]
P_IRON = ["navy", "iron", "steel_d", "steel"]
P_OCTO = ["red_d", "red", "coral", "peach"]
P_SHELL = ["rose", "pink", "peach", "cream"]
P_GOLD = ["gold_d", "gold", "yellow", "cream"]
P_RDRAG = ["wine", "red_d", "red", "coral"]
P_YBELLY = ["gold_d", "gold", "gold_l", "yellow"]
P_ICE = ["water", "sky", "azure", "sky_l"]
P_BLACK = ["ink", "navy", "iron", "slate"]
P_ARMOR = ["ink", "navy", "iron", "slate", "steel_d"]
P_GREY = ["iron", "slate", "stone_d", "ash"]
P_TAN = ["brown", "gold_d", "gold"]


def p_backdrop27(kind: str) -> Canvas:
    rng = random.Random(len(kind) * 7)
    c = Canvas(PS, PS, P.rgba("sky"))
    if kind == "tristan":            # a bright summer beach: sky, a sea line with waves, a little sun glint
        P.vgrad(c, 0, 0, PS, 30, ["sky", "azure", "sky_l"], sharp=1.3)
        P.vgrad(c, 0, 30, PS, PS, ["sky", "water", "water_d"], sharp=1.3)
        for y in (32, 36, 41, 45):
            for x in range((y * 5) % 7, PS, 8):
                _px(c, [(x, y), (x + 1, y), (x + 2, y)], "sky_l" if y < 40 else "sky")
        _px(c, [(x, 30) for x in range(PS)], "white")
        for (x, y) in P.ellipse(40, 7, 3.5, 3.5):
            c.set(x, y, "white")
    elif kind == "gawain":           # snowy mountains under a cold blue sky, falling snow
        P.vgrad(c, 0, 0, PS, PS, ["water", "sky", "azure", "sky_l"], sharp=1.3)
        peaks = P.poly([(-2, 40), (10, 18), (18, 28), (28, 12), (40, 26), (50, 20), (50, 48), (-2, 48)])
        P.shade_shape(c, peaks, ["ash", "fog", "white", "white"], bias=0.1)
        for (x, y) in P.scatter(rng, 14, 0, 0, PS, PS):
            c.set(x, y, "white")
    elif kind == "kraken":           # the sunken palace: deep water, light rays from above, bubbles
        P.vgrad(c, 0, 0, PS, PS, ["water", "water_d", "night", "night_d"], sharp=1.3)
        for (x0, w) in ((6, 3), (20, 4), (36, 3)):
            for y in range(0, 30):
                for x in range(x0 + y // 4, x0 + y // 4 + w):
                    if (x + y) % 3:
                        c.set(x, y, "water" if y > 14 else "sky")
        for (x, y, r) in ((5, 30, 2), (43, 12, 1.5), (40, 36, 2.5), (8, 8, 1.2)):
            for (px, py) in P.edge(P.ellipse(x, y, r, r)):
                c.set(px, py, "sky_l")
    elif kind == "red_dragon":       # the volcano: hot sky, a dark peak, glowing embers
        P.vgrad(c, 0, 0, PS, PS, ["wine", "red_d", "orange", "amber"], sharp=1.3)
        cone = P.poly([(-2, 48), (12, 22), (20, 20), (34, 48)])
        P.fill(c, cone, "umber")
        _px(c, [(x, 21) for x in range(13, 20)] + [(14, 22), (16, 23), (18, 22)], "orange")
        for (x, y) in P.scatter(rng, 10, 0, 0, PS, 30):
            c.set(x, y, "yellow")
    elif kind == "white_dragon":     # the ice peak: pale sky, icy slopes, snowflakes
        P.vgrad(c, 0, 0, PS, PS, ["sky", "azure", "sky_l", "white"], sharp=1.3)
        slope = P.poly([(20, 48), (36, 18), (44, 24), (52, 16), (52, 48)])
        P.shade_shape(c, slope, ["sky", "azure", "sky_l", "white"], bias=0.05)
        for (x, y) in P.scatter(rng, 9, 0, 0, PS, PS):
            P.star4(c, x, y, "white", 1)
    elif kind == "mordred":          # autumn dusk at the field of Camlann: a black wolf banner, drifting leaves
        P.vgrad(c, 0, 0, PS, PS, ["night_d", "plum", "wine", "rose", "peach"], sharp=1.3)
        _px(c, [(5, y) for y in range(0, PS)], "ink")
        flag = P.poly([(6, 2), (18, 3), (16, 9), (19, 15), (6, 14)])
        P.fill(c, flag, "ink")
        for (x, y) in ((10, 6), (11, 7), (12, 6), (10, 8), (11, 8), (12, 8), (13, 9), (11, 10)):
            c.set(x, y, "violet")
        for (x, y) in P.scatter(rng, 9, 0, 16, PS, PS):
            _px(c, [(x, y), (x + 1, y)], ("orange", "gold", "red_d")[rng.randrange(3)])
    return c


# --------------------------------------------------------------------------- tristan
def tristan_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    # the harp's neck over the far shoulder
    harp_neck = P.thick_line(5, 46, 7, 22, 1.4) | P.thick_line(7, 22, 15, 25, 1.4)
    P.shade_shape(f, harp_neck, P_WOOD, bias=0.1)
    _px(f, [(9, y) for y in range(26, 46)] + [(12, y) for y in range(27, 46)], "cream")
    f.set(7, 21, "yellow")
    # light-blue cape on the shoulders, green tunic, white chest fur
    cape = P.poly([(1, 48), (4, 38), (13, 33), (35, 33), (44, 38), (47, 48)])
    P.shade_shape(f, cape, P_SKYC, centre=(22, 38), radius=(23, 11))
    tunic = P.poly([(13, 48), (15, 38), (33, 38), (35, 48)])
    P.shade_shape(f, tunic, P_GREEN, bias=0.05)
    _px(f, [(x, 44) for x in range(14, 35)], "brown_d")
    _px(f, [(23, 44), (24, 44)], "yellow")
    ruff = P.ellipse(24, 36, 10, 3.5)
    P.shade_shape(f, ruff, P_URA, bias=0.08)
    # huge upright ears with cream insides
    for (pts, inner, b) in (([(6, 24), (8, 0), (19, 14)], [(9, 19), (9.5, 5), (16, 13)], -0.05),
                            ([(26, 13), (37, 0), (39, 22)], [(29, 13), (36, 5), (37, 18)], 0.08)):
        P.shade_shape(f, P.poly(pts), P_CORGI, bias=b)
        P.fill(f, P.poly(inner), "cream")
    head = P.ellipse(22, 24, 13, 11)
    P.shade_shape(f, head, P_CORGI, centre=(20, 21), radius=(14, 12), bias=0.06)
    # white blaze down the face, white cheeks and muzzle
    blaze = P.poly([(22, 10), (24, 10), (26, 21), (21, 21)])
    P.shade_shape(f, blaze & head, P_URA, bias=0.2)
    cheeks = P.ellipse(19, 31, 8, 4) | P.ellipse(31, 28.5, 7.5, 4.6)
    P.shade_shape(f, (cheeks & head) | P.ellipse(31, 28.5, 7.5, 4.6), P_URA, bias=0.12)
    P.stamp(f, [".oo.", "oooo", ".oo."], 37, 23, {"o": "ink"})
    f.set(38, 23, "steel_l")
    # small blue cap tilted on the crown with a red feather
    cap = P.ellipse(19, 10, 9, 4.5) | P.rect(9, 11, 19, 2)
    P.shade_shape(f, cap, P_CAPB, centre=(16, 8), radius=(10, 5), bias=0.1)
    _px(f, [(x, 12) for x in range(10, 28)], "navy")
    feather = P.thick_line(12, 9, 4, 3, 1.3) | P.thick_line(4, 3, 1, 4, 0.9)
    P.shade_shape(f, feather, P_REDF, bias=0.1)
    _px(f, [(x, y) for (x, y) in P.thick_line(12, 9, 4, 3, 0.4)], "pink")
    for (x, y) in ((14, 30), (15, 30), (32, 29), (33, 29)):
        f.set(x, y, "pink")
    f.outline_all("umber")
    ne, fe, m = (14, 19), (27, 19), (34, 31)
    if expr in ("normal", "serious"):
        _stamp(f, [".ooo.", "owwoo", "ooooo", "ooooo", ".ooo."], ne[0], ne[1])
        _stamp(f, [".oo.", "owoo", "oooo", "oooo", ".oo."], fe[0], fe[1])
    if expr == "normal":         # a cheerful smile
        _stamp(f, ["o....o", ".oRRo.", "..pp.."], m[0] - 5, m[1])
    elif expr == "happy":        # singing with joy
        _stamp(f, [".ooo.", "o...o"], ne[0], ne[1] + 1)
        _stamp(f, [".oo.", "o..o"], fe[0], fe[1] + 1)
        _stamp(f, ["oooooo", "oRRRRo", ".oppo."], m[0] - 5, m[1])
        _stamp(f, ["..y", ".yy", "yy.", "y.."], 42, 8)
        _stamp(f, ["yy", "y.", "y."], 43, 4)
    elif expr == "serious":
        for x in range(ne[0], ne[0] + 5):
            f.set(x, ne[1], "ink")
        for x in range(fe[0], fe[0] + 4):
            f.set(x, fe[1], "ink")
        _px(f, [(ne[0] - 1, ne[1] - 2), (ne[0], ne[1] - 2), (ne[0] + 1, ne[1] - 1), (ne[0] + 2, ne[1] - 1),
                (ne[0] + 3, ne[1] - 1)], "brown_d")
        _px(f, [(fe[0], fe[1] - 1), (fe[0] + 1, fe[1] - 1), (fe[0] + 2, fe[1] - 2), (fe[0] + 3, fe[1] - 2)], "brown_d")
        _px(f, [(m[0] - 4, m[1] + 1), (m[0] - 3, m[1] + 1), (m[0] - 2, m[1] + 1), (m[0] - 1, m[1] + 1)], "ink")
    elif expr == "surprised":
        _stamp(f, [".ooo.", "owwoo", "owooo", "ooooo", "ooooo", ".ooo."], ne[0], ne[1] - 1)
        _stamp(f, [".oo.", "owoo", "oooo", "oooo", ".oo."], fe[0], fe[1] - 1)
        _stamp(f, [".oo.", "oRRo", ".oo."], m[0] - 3, m[1])
        _stamp(f, ["..o.", ".oso", "osso", ".oo."], 42, 16)
    return f


# --------------------------------------------------------------------------- gawain
def gawain_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    # the iron hammer head over the far shoulder
    hammer = P.rect(0, 14, 9, 7)
    P.shade_shape(f, hammer, P_IRON, bias=0.1)
    _px(f, [(x, 14) for x in range(0, 9)], "steel_l")
    _px(f, [(x, y) for (x, y) in P.thick_line(5, 21, 10, 34, 1.0)], "brown")
    # orange cloak, white fluffy chest, red collar with the little barrel
    cloak = P.poly([(0, 48), (2, 36), (12, 31), (36, 31), (46, 36), (48, 48)])
    P.shade_shape(f, cloak, P_ORANGE, centre=(22, 38), radius=(24, 12))
    chest = P.ellipse(24, 42, 13, 9)
    P.shade_shape(f, chest, P_WHITE, bias=0.08)
    _px(f, [(x, y) for (x, y) in P.thick_line(13, 35, 35, 35, 0.8)], "red_d")
    barrel = P.ellipse(24, 41, 5, 4) | P.rect(20, 38, 9, 6)
    P.shade_shape(f, barrel, P_WOOD, bias=0.12)
    _px(f, [(20, y) for y in range(38, 44)] + [(28, y) for y in range(38, 44)], "gold")
    _px(f, [(23, 37), (24, 37), (25, 37)], "brown_d")
    # floppy brown ears, a big round head: brown with a white blaze, white muzzle, dark eye mask, droopy jowls
    for (pts, b) in (([(9, 14), (3, 20), (4, 33), (10, 34), (14, 22)], -0.05),
                     ([(33, 14), (39, 18), (42, 31), (36, 33), (31, 22)], 0.06)):
        P.shade_shape(f, P.poly(pts), P_SB, bias=b)
    head = P.ellipse(23, 22, 13.5, 12)
    P.shade_shape(f, head, P_SB, centre=(21, 19), radius=(14, 12), bias=0.1)
    blaze = P.poly([(20, 9), (26, 9), (28, 22), (19, 22)])
    P.shade_shape(f, blaze & head, P_WHITE, bias=0.2)
    muzzle = P.ellipse(24, 29, 11, 6.5) | P.ellipse(31, 26, 7, 5)
    P.shade_shape(f, muzzle, P_WHITE, centre=(24, 26), radius=(11, 7), bias=0.14)
    jowls = P.ellipse(17, 32, 4, 2.6) | P.ellipse(31, 32, 4, 2.6)
    P.shade_shape(f, jowls, P_WHITE, bias=0.0)
    for (cx, cy) in ((16, 20), (28, 20)):
        for (x, y) in P.ellipse(cx + 1.5, cy + 1.5, 4.2, 3.4):
            if P.name_at(f, x, y) in P_SB:
                f.set(x, y, "brown_d")
    P.stamp(f, [".ooo.", "ooooo", ".ooo."], 35, 23, {"o": "ink"})
    f.set(36, 23, "steel_l")
    for (x, y) in ((13, 27), (14, 27), (33, 27), (34, 27)):
        f.set(x, y, "pink")
    f.outline_all("umber")
    ne, fe, m = (15, 19), (27, 19), (31, 31)
    if expr == "normal":         # a big warm smile
        _stamp(f, [".ooo.", "owwoo", "ooooo", ".ooo."], ne[0], ne[1])
        _stamp(f, [".oo.", "owoo", "oooo", ".oo."], fe[0], fe[1])
        _stamp(f, ["o......o", ".oooooo."], m[0] - 7, m[1])
    elif expr == "happy":        # a hearty laugh
        _stamp(f, [".ooo.", "o...o"], ne[0], ne[1] + 1)
        _stamp(f, [".oo.", "o..o"], fe[0], fe[1] + 1)
        _stamp(f, ["oooooooo", "oRRRRRRo", ".oRppRo.", "..oooo.."], m[0] - 7, m[1])
    elif expr == "serious":
        _stamp(f, ["ooooo", "owwoo", ".ooo."], ne[0], ne[1] + 1)
        _stamp(f, ["oooo", "owoo", ".oo."], fe[0], fe[1] + 1)
        _px(f, [(ne[0] - 1, ne[1] - 1), (ne[0], ne[1] - 1), (ne[0] + 1, ne[1]), (ne[0] + 2, ne[1]), (ne[0] + 3, ne[1])],
            "umber")
        _px(f, [(fe[0], fe[1]), (fe[0] + 1, fe[1]), (fe[0] + 2, fe[1] - 1), (fe[0] + 3, fe[1] - 1)], "umber")
        _px(f, [(m[0] - 5, m[1] + 1), (m[0] - 4, m[1] + 1), (m[0] - 3, m[1] + 1), (m[0] - 2, m[1] + 1),
                (m[0] - 1, m[1] + 1)], "ink")
    return f


# --------------------------------------------------------------------------- kraken
def kraken_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    # a curling tentacle in front, the big round mantle, the seashell crown
    mantle = P.ellipse(24, 26, 21, 19)
    P.shade_shape(f, mantle, P_OCTO, centre=(20, 20), radius=(22, 20), bias=0.04)
    for (x, y) in ((10, 16), (14, 11), (8, 24), (31, 12), (13, 32)):
        _px(f, [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], "red_d")
    for (cx, cy, r) in ((11, 8, 4.5), (23, 4, 6), (35, 8, 4.5)):
        fan = {(x, y) for (x, y) in P.ellipse(cx, cy, r, r) if y <= cy + 1}
        P.shade_shape(f, fan, P_SHELL, bias=0.1)
        for k in (-2, 0, 2):
            _px(f, [p for p in line_px(cx, cy + 1, cx + k * r * 0.4, cy - r * 0.9) if p in fan], "rose")
    band = {(x, y) for (x, y) in P.ellipse(23, 10, 17, 3.5) if y >= 9}
    P.shade_shape(f, band, P_GOLD, bias=0.12)
    for x in (8, 16, 30, 38):
        f.set(x, 11, "white")
    tent = P.thick_line(2, 48, 6, 40, 4.0) | P.thick_line(6, 40, 13, 38, 3.2) | P.thick_line(13, 38, 15, 42, 2.4)
    tent2 = P.thick_line(46, 48, 42, 41, 4.0) | P.thick_line(42, 41, 36, 40, 3.0)
    P.shade_shape(f, tent | tent2, P_OCTO, bias=0.14)
    for (x, y) in ((4, 45), (8, 42), (12, 41), (43, 45), (40, 43)):
        f.set(x, y, "peach")
    # the black wolf sigil on the forehead
    rows = ["..x.x....", ".xx.xx...", ".xxxxxx..", "xxxxxxxxx", ".xxxxxxx.", "..xxxx...", "...xx...."]
    pts = [(20 + i, 13 + j) for j, row in enumerate(rows) for i, ch in enumerate(row) if ch == "x"]
    ring = {(x + dx, y + dy) for (x, y) in pts for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1))} - set(pts)
    _px(f, ring & mantle, "violet")
    _px(f, pts, "ink")
    f.set(24, 15, "lilac")
    f.outline_all("wine")
    # big round googly eyes and a small "o" mouth
    for (ex, ey, r) in ((16, 25, 5.2), (31, 25, 4.8)):
        eye = P.ellipse(ex, ey, r, r * 1.05)
        P.fill(f, eye, "white")
        P.outline_shape(f, eye, "wine")
        _stamp(f, [".oo.", "oooo", "oooo", ".oo."], int(ex - 0.5), int(ey - 1))
        f.set(int(ex - 0.5) + 1, int(ey - 1), "white")
    _px(f, [(9, 31), (10, 31), (37, 31), (38, 31)], "pink")
    _stamp(f, [".oo.", "oRRo", ".oo."], 22, 32)
    return f


# --------------------------------------------------------------------------- dragons
def dragon_portrait(kind: str) -> Canvas:
    f = Canvas(PS, PS)
    red = kind == "red_dragon"
    skin = P_RDRAG if red else P_WHITE
    bel = P_YBELLY if red else P_ICE
    horn = ["gold_d", "gold", "gold_l", "cream"] if red else P_ICE
    # body, belly plates, little wings
    wing = P.poly([(2, 30), (0, 14), (6, 20), (8, 12), (12, 22), (14, 30)])
    P.shade_shape(f, wing, ["wine", "red_d", "rose", "pink"] if red else ["ash", "fog", "azure", "sky_l"], bias=-0.05)
    body = P.poly([(4, 48), (8, 36), (18, 32), (34, 33), (42, 38), (44, 48)])
    P.shade_shape(f, body, skin, centre=(22, 38), radius=(22, 12), bias=0.06)
    belly = P.ellipse(27, 44, 10, 8)
    P.shade_shape(f, belly & body, bel, bias=0.1)
    for y in (40, 43, 46):
        _px(f, [(x, y) for x in range(18, 37) if (x, y) in belly], bel[0])
    # mane (white dragon) and horns
    if not red:
        for i in range(5):
            y0 = 8 + i * 5
            P.shade_shape(f, P.poly([(9, y0), (1, y0 + 2 + (i % 2)), (9, y0 + 5)]), P_ICE, bias=0.1)
    for (pts, b) in (([(12, 12), (6, 2), (9, 2), (16, 9)], -0.05), ([(22, 9), (19, 0), (22, 0), (27, 8)], 0.1)):
        P.shade_shape(f, P.poly(pts), horn, bias=b)
    head = P.ellipse(22, 22, 14, 12)
    P.shade_shape(f, head, skin, centre=(19, 18), radius=(15, 13), bias=0.12)
    snout = P.ellipse(35, 27, 10, 7.5)
    P.shade_shape(f, snout, skin, centre=(33, 24), radius=(10, 8), bias=0.18)
    chin = {(x, y) for (x, y) in snout if y >= 30}
    P.fill(f, chin, bel[2])
    if not red:
        tuft = P.poly([(14, 11), (20, 6), (19, 11), (25, 7), (24, 12)])
        P.shade_shape(f, tuft, P_ICE, bias=0.15)
    _px(f, [(41, 23), (42, 23), (42, 24)], skin[0])
    _px(f, [(38, 24), (39, 23)], skin[0])
    for (x, y) in ((24, 30), (25, 30), (26, 30)):
        f.set(x, y, "pink")
    f.outline_all("umber" if red else "slate")
    # big round eye(s): the near eye large, the far eye peeking
    iris = "amber" if red else "sky"
    P.stamp(f, ["..oooo..", ".owwwwo.", "owwiiiwo", "owiiooio", "owiiooio", "owwiiiwo", ".owwwwo.", "..oooo.."], 14, 15,
           {"o": "ink", "w": "white", "i": iris})
    f.set(17, 18, "white")
    f.set(19, 20, "white")
    P.stamp(f, [".ooo.", "owiio", "owioo", ".ooo."], 28, 16, {"o": "ink", "w": "white", "i": iris})
    if red:
        # hot-tempered: angry brows, a grumpy grin, smoke curling from the nostrils
        _px(f, [(12, 13), (13, 13), (14, 13), (15, 14), (16, 14), (17, 14), (18, 15), (19, 15)], "wine")
        _px(f, [(28, 14), (29, 14), (30, 13), (31, 13)], "wine")
        _px(f, [(31, 33), (32, 34), (33, 34), (34, 34), (35, 34), (36, 34), (37, 33)], "wine")
        _px(f, [(33, 34), (36, 34)], "white")
        for (x, y, r) in ((44, 18, 1.6), (46, 14, 1.3), (45, 10, 1.0)):
            for p in P.ellipse(x, y, r, r):
                f.set(p[0], p[1], "ash")
    else:
        # sassy: a smug half-lidded look and a little smirk
        _px(f, [(x, 15) for x in range(15, 21)] + [(x, 16) for x in range(15, 21)] + [(x, 17) for x in range(16, 20)],
            "fog")
        _px(f, [(x, 17) for x in range(14, 22)], "ink")
        _px(f, [(28, 16), (29, 16), (30, 16), (31, 16), (29, 17), (30, 17)], "fog")
        _px(f, [(28, 17), (31, 17)], "ink")
        _px(f, [(31, 34), (32, 34), (33, 34), (34, 34), (35, 33), (36, 32)], "slate")
        P.star4(f, 44, 12, "white", 1)
    return f


# --------------------------------------------------------------------------- mordred
def mordred_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    # dark grey cape, silver-trimmed black armour, the wolf-head pauldron, a hint of the scabbard's glow
    cape = P.poly([(0, 48), (1, 36), (10, 31), (38, 31), (47, 36), (48, 48)])
    P.shade_shape(f, cape, P_GREY, centre=(22, 38), radius=(24, 12), bias=0.05)
    chest = P.poly([(13, 48), (15, 37), (23, 34), (35, 35), (39, 41), (39, 48)])
    P.shade_shape(f, chest, P_ARMOR, centre=(24, 38), radius=(14, 11), bias=0.2)
    _px(f, [(x, y) for (x, y) in P.edge(chest) if y < 41 and (x, y - 1) not in chest], "steel_l")
    _px(f, [(26, y) for y in range(37, 48)], "iron")
    tan = P.ellipse(28, 35, 6, 2.4)
    P.shade_shape(f, tan, P_TAN, bias=0.1)
    pauld = P.ellipse(9, 39, 9, 7)
    P.shade_shape(f, pauld, P_ARMOR, bias=0.22)
    _px(f, [(x, y) for (x, y) in P.edge(pauld) if y > 38], "steel_l")
    # the black wolf's head embossed on the pauldron, in silver, looking outward
    rows = ["....x.x..", "...xx.xx.", "..xxxxxx.", "xxxxxxxxx", ".xxxxxxx.", "...xxxx..", "....xx..."]
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "x":
                f.set(4 + i, 35 + j, "steel_l" if (i + j) % 5 else "white")
    f.set(8, 37, "violet")
    for (x, y) in ((44, 45), (45, 44), (46, 43), (45, 46), (46, 45), (43, 46)):
        f.set(x, y, "violet")
    f.set(46, 44, "lilac")
    # tall pointed ears, a black head with rust-tan markings, a wedge snout (black on top, tan jaw)
    for (pts, inner, bias) in (([(8, 21), (7, 0), (17, 12)], [(10, 17), (9, 5), (15, 12)], -0.05),
                               ([(22, 11), (29, 0), (33, 16)], [(25, 12), (29, 4), (31, 14)], 0.12)):
        P.shade_shape(f, P.poly(pts), P_BLACK, bias=bias)
        P.fill(f, P.poly(inner), "navy")
    head = P.ellipse(20, 22, 12.5, 11.5)
    P.shade_shape(f, head, P_BLACK, centre=(17, 18), radius=(13, 12), bias=0.22)
    snout = P.poly([(25, 18), (39, 22), (41, 25), (39, 28), (27, 31)])
    P.shade_shape(f, snout, P_BLACK, centre=(31, 21), radius=(9, 6), bias=0.26)
    jaw = {(x, y) for (x, y) in snout if y >= 27} | {(x, y) for (x, y) in P.ellipse(20, 29, 5, 2.6) if (x, y) in head}
    P.shade_shape(f, jaw, P_TAN, bias=0.1)
    _px(f, [(14, 15), (15, 15), (25, 15), (26, 15)], "gold")
    P.stamp(f, [".oo", "ooo", ".oo"], 39, 22, {"o": "ink"})
    f.set(40, 22, "steel_d")
    f.outline_all("ink")
    ne, fe, m = (13, 18), (24, 18), (37, 28)
    eye_l = {"o": "ink", "a": "amber", "y": "yellow", "w": "white"}
    if expr in ("normal", "smirk"):
        # composed, half-lidded amber eyes
        P.stamp(f, ["ooooo.", "oywao.", ".ooo.."], ne[0], ne[1] + 1, eye_l)
        P.stamp(f, ["oooo", "ywao", ".oo."], fe[0], fe[1] + 1, eye_l)
        if expr == "normal":
            _px(f, [(m[0] - 9, m[1]), (m[0] - 8, m[1]), (m[0] - 7, m[1]), (m[0] - 6, m[1]), (m[0] - 5, m[1]),
                    (m[0] - 4, m[1])], "ink")
        else:                       # one corner of the mouth up, the brow raised
            _px(f, [(m[0] - 9, m[1]), (m[0] - 8, m[1]), (m[0] - 7, m[1]), (m[0] - 6, m[1]), (m[0] - 5, m[1] - 1),
                    (m[0] - 4, m[1] - 2)], "ink")
            _px(f, [(fe[0], fe[1] - 1), (fe[0] + 1, fe[1] - 2), (fe[0] + 2, fe[1] - 2), (fe[0] + 3, fe[1] - 2)], "gold")
    elif expr == "angry":
        P.stamp(f, ["o.....", "ooo...", "oywoo.", ".ooo.."], ne[0], ne[1], eye_l)
        P.stamp(f, ["...o", ".ooo", "ywao", ".oo."], fe[0], fe[1], eye_l)
        _stamp(f, ["ooooooo", "owwWWwo", ".ooooo."], m[0] - 10, m[1] - 1)
    elif expr == "sad":
        P.stamp(f, ["...o.", ".ooo.", "oywao", ".ooo."], ne[0], ne[1], eye_l)
        P.stamp(f, [".o..", ".ooo", "ywao", ".oo."], fe[0], fe[1], eye_l)
        _px(f, [(m[0] - 9, m[1] + 1), (m[0] - 8, m[1]), (m[0] - 7, m[1]), (m[0] - 6, m[1]), (m[0] - 5, m[1] + 1)], "ink")
        _stamp(f, [".s.", "sus", ".u."], ne[0] + 2, ne[1] + 4)
    return f


PORTRAIT_BUILDERS = {
    "tristan": tristan_portrait,
    "gawain": gawain_portrait,
    "kraken": kraken_portrait,
    "red_dragon": lambda e: dragon_portrait("red_dragon"),
    "white_dragon": lambda e: dragon_portrait("white_dragon"),
    "mordred": mordred_portrait,
}


def portrait(speaker: str, expr: str) -> Canvas:
    c = p_backdrop27(speaker)
    c.blit(PORTRAIT_BUILDERS[speaker](expr), 0, 0)
    P.quantize(c)
    return c.flipped()


def write_portraits() -> None:
    for speaker, exprs in PORTRAITS_V27.items():
        for expr in exprs:
            portrait(speaker, expr).save(res_path("res://assets/portraits/%s/%s.png" % (speaker, expr)), opaque=True)


# ===========================================================================
# CC8 projectiles (assets/fx/<name>/<name>_frames.tres, animation `default`, looping, drawn facing right: line A
# rotates them along their flight; the tentacle stands upright) and the one-shot particles snow_burst / bubble_pop.
# ===========================================================================

_halo = V._halo


def bubble() -> list[Anim]:
    """12x12 see-through bubble from the kraken: a thin pale rim, a white highlight, a faint blue inside."""
    frames = []
    for k in range(4):
        c = Canvas(12, 12)
        rx, ry = (4.6, 4.2, 4.4, 4.0)[k], (4.2, 4.6, 4.4, 4.8)[k]
        body = P.ellipse(6, 6, rx, ry)
        for (x, y) in body:
            c.set(x, y, alpha_px("sky", 70))
        edge = P.edge(body)
        for (x, y) in edge:
            lit = x + y < 11
            c.set(x, y, alpha_px("sky_l" if lit else "sky", 240 if lit else 210))
        for (x, y) in ((3, 4), (4, 3), (4, 4)):
            c.set(x, y, "white")
        c.set(8, 8, alpha_px("white", 200))
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


def ink_blob() -> list[Anim]:
    """16x16 blob of octopus ink: a glossy dark drop with a drippy trail behind (left) and a violet sheen."""
    frames = []
    for k in range(4):
        c = Canvas(16, 16)
        f = Fig(16, 16, seed=241)
        w = (0.0, 0.4, 0.0, -0.4)[k]
        blob = union(ellipse(10.0, 8.0, 4.4 + w, 4.0 - w * 0.5), ellipse(5.5, 8.5 + w, 2.3, 2.0),
                     ellipse(2.5, 7.5 - w, 1.3, 1.2))
        f.add(blob, INK_CLOUD, centre=(9, 6), radius=(5, 4.5), bias=0.1)
        f.dots([(8, 6), (9, 6), (8, 7)], "violet")
        f.dot(8, 6, "lilac")
        f.dot(12, 10, "plum")
        c = f.render()
        # a soft violet rim so it reads on dark water
        for (x, y) in P.edge(P.ellipse(10.0, 8.0, 5.6 + w, 5.2 - w * 0.5)):
            if c.get(x, y) is None:
                c.set(x, y, alpha_px("violet", 90))
        frames.append(c)
    return [Anim("default", frames, 10.0, True)]


def music_note() -> list[Anim]:
    """12x12 golden eighth note from Tristan's harp, with a twinkle."""
    frames = []
    for k in range(4):
        f = Fig(12, 12, seed=251)
        dy = (0, -1, 0, 1)[k]
        head = ellipse(4.2, 8.6 + dy, 2.6, 1.9)
        stem = rect(6, 2 + dy, 1, 7)
        flag = union(capsule(6.5, 2.5 + dy, 9.0, 4.5 + dy, 0.8), capsule(9.0, 4.5 + dy, 8.6, 6.4 + dy, 0.7))
        f.add(union(head, stem, flag), Mat(["gold_d", "gold", "yellow", "cream"], outline="brown_d", lit="gold_d"),
              centre=(4, 5 + dy), radius=(5, 5), bias=0.1)
        f.dot(3, 8 + dy, "white")
        sx, sy = [(10, 9), (1, 3), (10, 1), (2, 1)][k]
        f.glow(sx, sy, "white")
        for (ddx, ddy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            f.glow(sx + ddx, sy + ddy, alpha_px("yellow", 170))
        frames.append(f.render())
    return [Anim("default", frames, 8.0, True)]


def snowball() -> list[Anim]:
    """12x12 snowball from the snowman, spinning (the little dimple moves), with a puff of snow behind."""
    frames = []
    for k in range(4):
        f = Fig(12, 12, seed=261)
        ball = ellipse(7.0, 6.0, 3.8, 3.8)
        f.add(ball, SNOW, centre=(5.5, 4.5), radius=(4.5, 4.5), bias=0.1)
        a = k * math.pi / 2
        f.dots([(int(round(7 + math.cos(a) * 2)), int(round(6 + math.sin(a) * 2)))], "ash")
        for (x, y, al) in ((1, 5 + k % 2, 170), (2, 8 - k % 2, 130), (0, 7, 90)):
            f.glow(x, y, alpha_px("white", al))
        frames.append(f.render())
    return [Anim("default", frames, 10.0, True)]


def fireball() -> list[Anim]:
    """16x16 fireball from the red dragon and the salamanders: a hot white core, flames trailing behind."""
    frames = []
    for k in range(4):
        c = Canvas(16, 16)
        cx, cy, r = 10.5, 8.0, 3.8
        sway = (-1, 0, 1, 0)[k]
        tail = poly([(cx - r * 0.2, cy - r * 0.95), (1.0, cy - 0.5 + sway), (cx - r * 0.2, cy + r * 0.95)])
        lick = poly([(cx - 1, cy - r * 0.7), (cx - 6.5, cy - 3.5 - sway * 0.5), (cx - 2.5, cy)])
        lick2 = poly([(cx - 1, cy + r * 0.6), (cx - 6.0, cy + 3.2 + sway * 0.5), (cx - 2.5, cy)])
        shape = {(x, y) for (x, y) in (ellipse(cx, cy, r, r) | tail | lick | lick2) if 0 <= x < 16 and 0 <= y < 16}
        _halo(c, cx, cy, r + 2.2, "amber", 70)
        V.flame_paint(c, shape, cx, cy, r, outline="red_d", ramp=["red", "orange", "yellow", "white"])
        for (x, y) in shape:
            if P.name_at(c, x, y) == "lilac":       # the tail interior: flame orange instead of the foxfire lilac
                c.set(x, y, "orange")
        frames.append(c)
    return [Anim("default", frames, 14.0, True)]


def ice_shard() -> list[Anim]:
    """16x16 ice shard from the white dragon: a faceted crystal spike pointing right, a glint running along it."""
    frames = []
    for k in range(4):
        f = Fig(16, 16, seed=271)
        top = poly([(15.2, 8.0), (6.0, 4.6), (2.0, 6.8), (6.5, 7.6)])
        bot = poly([(15.2, 8.0), (6.5, 7.6), (2.0, 9.2), (6.0, 11.4)])
        mat = Mat(["water", "sky", "azure", "sky_l"], outline="water_d", lit="water")
        f.add(top, mat, flat=3)
        f.add(bot, mat, flat=1)
        f.recolor({(x, 7) for x in range(3, 15)} & top, "white")
        gx = [5, 8, 11, 13][k]
        f.dots([(gx, 7), (gx, 6)], "white")
        for (x, y, a) in ((1, 6, 150), (0, 9, 110), (1, 10, 90)):
            f.glow(x, y, alpha_px("white", a))
        frames.append(f.render())
    return [Anim("default", frames, 12.0, True)]


def shadow_slash() -> list[Anim]:
    """24x24 purple crescent wave from Mordred's slash: white leading edge, violet body, dark wisps trailing."""
    frames = []
    for k in range(4):
        c = Canvas(24, 24)
        t = (0.0, 0.5, 1.0, 0.5)[k]
        outer = P.ellipse(11.0, 12.0, 10.0, 11.0)
        inner = P.ellipse(7.5 - t * 0.5, 12.0, 9.5, 10.5)
        moon = {(x, y) for (x, y) in outer - inner if 0 <= x < 24 and 0 <= y < 24}
        for (x, y) in moon:
            d = (x + 0.5 - (7.5 - t * 0.5))
            if (x + 1, y) not in moon:
                c.set(x, y, "white")
            elif (x + 2, y) not in moon:
                c.set(x, y, "lilac")
            elif d < 8.5:
                c.set(x, y, "plum")
            else:
                c.set(x, y, "violet")
        P.outline_shape(c, moon, "plum")
        for i, (x, y) in enumerate(((5, 4), (3, 9), (4, 15), (6, 20), (2, 12))):
            j = (i + k) % 3
            c.set(x - j, y, alpha_px("dusk", 200 - j * 50))
            c.set(x - j - 1, y + (1 if i % 2 else -1), alpha_px("violet", 140 - j * 30))
        frames.append(c)
    return [Anim("default", frames, 12.0, True)]


def tentacle() -> list[Anim]:
    """24x56 kraken tentacle slamming down from the edge of the field: it rises with the tip curled, whips down,
    lands with a splash, wriggles. Drawn upright (base at the bottom)."""
    frames = []
    poses = [  # (lean of the tip in px, curl, splash)
        (-3.0, 1.0, 0), (4.0, 0.6, 0), (1.0, 0.2, 1), (-1.0, 0.5, 2)]
    for k, (lean, curl, splash) in enumerate(poses):
        f = Fig(24, 56, seed=281 + k)
        pts = []
        for i in range(8):
            t = i / 7.0
            y = 54.5 - t * 42.0
            x = 11.5 + lean * t * t + math.sin(t * 3.0 + k) * 1.0
            pts.append((x, y))
        # the tip rolls into a spiral to one side
        tx, ty = pts[-1]
        d = 1 if lean >= 0 else -1
        cxs, cys = tx + d * 3.0, ty - 1.0
        for j in range(1, 7):
            ang = math.pi + d * (-j * (0.75 + curl * 0.35))
            rr = 3.0 - j * 0.35
            pts.append((cxs + math.cos(ang) * rr * d, cys + math.sin(ang) * rr))
        shape = set()
        n = len(pts) - 1
        for i in range(n):
            ra = 5.6 + (1.1 - 5.6) * i / n
            rb = 5.6 + (1.1 - 5.6) * (i + 1) / n
            shape |= capsule(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], (ra + rb) / 2)
        shape = {(x, y) for (x, y) in shape if y <= 55}
        f.add(shape, OCTO, mode="cyl_v", centre=(11, 30), radius=(6, 28), bias=-0.06)
        # suckers along the left side, a darker stripe on the right
        suck = set()
        for i in range(1, 8):
            x, y = pts[i]
            r = 5.6 + (1.1 - 5.6) * i / n
            sx = int(round(x - r * 0.5))
            suck |= {(sx, int(round(y))), (sx, int(round(y)) + 1)}
        f.recolor(suck & shape, "peach")
        f.recolor({(x - 1, y) for (x, y) in suck} & shape, "pink")
        if k == 1:
            for (x, y) in ((2, 18), (1, 24), (3, 30)):
                for i in range(4):
                    f.glow(x, y + i, alpha_px("white", 120 + i * 30))
        if splash:
            for i, (x, y) in enumerate(((3, 50), (20, 49), (1, 44), (22, 42), (5, 54), (19, 54))):
                if splash == 1 or i % 2:
                    f.glow(x, y, "sky_l")
                    f.glow(x, y - 1, alpha_px("white", 220))
                    f.glow(x + (1 if x < 12 else -1), y + 1, alpha_px("sky", 200))
        frames.append(f.render())
    return [Anim("default", frames, 10.0, True, [1.0, 0.8, 1.4, 1.0])]


PROJECTILES = {
    "bubble": (bubble, (12, 12)),
    "ink_blob": (ink_blob, (16, 16)),
    "music_note": (music_note, (12, 12)),
    "snowball": (snowball, (12, 12)),
    "fireball": (fireball, (16, 16)),
    "ice_shard": (ice_shard, (16, 16)),
    "shadow_slash": (shadow_slash, (24, 24)),
    "tentacle": (tentacle, (24, 56)),
}

PARTICLE_TEXTURES = {
    "snow_chunk": art_particles._tex([".ws", "wsS", "sS."], {"w": "white", "s": "sky_l", "S": "ash"}),
    "bubble_ring": art_particles._tex([".ss.", "sw.s", "s..s", ".ss."], {"s": "sky_l", "w": "white"}),
}

PARTICLES = {
    # the snowman knocked apart: a puff of snow chunks that fly up and tumble down
    "snow_burst": {
        "tex": "snow_chunk", "z": 5, "props": {
            "amount": 14, "lifetime": 0.8, "explosiveness": 0.95, "direction": "Vector2(0, -1)", "spread": 85.0,
            "gravity": "Vector2(0, 240)", "initial_velocity_min": 40.0, "initial_velocity_max": 90.0,
            "angular_velocity_min": -420.0, "angular_velocity_max": 420.0, "angle_min": -180.0, "angle_max": 180.0,
            "damping_min": 10.0, "damping_max": 30.0, "scale_amount_min": 0.8, "scale_amount_max": 1.4,
        },
        "ramp": [(0, "white", 1), (0.75, "white", 1), (1, "white", 0)],
    },
    # a bubble popping: little rings spray out, drift up and vanish
    "bubble_pop": {
        "tex": "bubble_ring", "z": 5, "props": {
            "amount": 8, "lifetime": 0.6, "explosiveness": 1.0, "spread": 180.0, "gravity": "Vector2(0, -35)",
            "initial_velocity_min": 22.0, "initial_velocity_max": 48.0, "damping_min": 40.0, "damping_max": 70.0,
            "scale_amount_min": 0.6, "scale_amount_max": 1.1,
        },
        "ramp": [(0, "white", 1), (0.7, "white", 1), (1, "white", 0)],
        "scale": [(0, 0.7), (0.7, 1.15), (1, 0.4)],
    },
}


def write_fx() -> None:
    for name, (fn, size) in PROJECTILES.items():
        build_sheet("res://assets/fx/%s" % name, name, fn(), size)
    for name, tex in PARTICLE_TEXTURES.items():
        tex.save(res_path("%s/%s.png" % (art_particles.TEX_DIR, name)))
    for name, fx in PARTICLES.items():
        write_text(res_path("res://assets/fx/particles/%s.tscn" % name), art_particles.effect_tscn(name, fx))


# ---------------------------------------------------------------------------
# preview / write
# ---------------------------------------------------------------------------

CHARACTERS = {
    "crab": (crab, (24, 24)),
    "jellyfish": (jellyfish, (24, 24)),
    "kraken": (kraken, (64, 64)),
    "snowman": (snowman, (24, 24)),
    "salamander": (salamander, (24, 24)),
    "red_dragon": (red_dragon, (64, 64)),
    "white_dragon": (white_dragon, (64, 64)),
    "shadow_knight": (shadow_knight, (32, 32)),
    "lantern_wisp": (lantern_wisp, (16, 16)),
    "mordred": (mordred, (48, 48)),
    "tristan": (tristan, (32, 32)),
    "gawain": (gawain, (40, 40)),
}
LIFTED = ("kraken", "red_dragon", "white_dragon")      # feet 8 px above the cell's ground row (foot_lift metadata)


def write_sprites(only=None) -> dict:
    out = {}
    for code, (fn, size) in CHARACTERS.items():
        if only and code not in only:
            continue
        anims = fn()
        build_sheet("res://assets/sprites/%s" % code, code, anims, size)
        if code in LIFTED:
            add_foot_lift("res://assets/sprites/%s/%s_frames.tres" % (code, code), LIFT64)
        out[code] = anims
    return out


def write_all() -> None:
    """Everything C 角色 owns in v2.7 (build_all.py calls this after the v2.6 cast)."""
    write_sprites()
    write_portraits()
    write_fx()


def preview(out_dir: str, only=None) -> None:
    os.makedirs(out_dir, exist_ok=True)
    for code, (fn, size) in CHARACTERS.items():
        if only and code not in only:
            continue
        anims = fn()
        scale = 3 if size[0] >= 64 else (4 if size[0] >= 40 else (6 if size[0] >= 32 else 8))
        contact_sheet([a.frames for a in anims], scale).save(os.path.join(out_dir, "%s.png" % code))
    if not only:
        contact_sheet([[portrait(s, e) for e in ex] for s, ex in PORTRAITS_V27.items()], 4).save(
            os.path.join(out_dir, "portraits_v27.png"))
        contact_sheet([fn()[0].frames for (fn, _) in PROJECTILES.values()], 6).save(
            os.path.join(out_dir, "projectiles_v27.png"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = [a[7:] for a in sys.argv[1:] if a.startswith("--only=")]
    only = only[0].split(",") if only else None
    if args:
        preview(args[0], only)
        print("previews in", args[0])
    else:
        write_all()
        print("v2.7 cast written")
