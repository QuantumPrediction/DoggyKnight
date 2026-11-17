"""v2.6 (C 角色, CC1 to CC4) the chapter 2-3 cast, drawn with the v2.5 rig renderer. All face right.

  gargoyle      32  grey stone imp: small bat wings, curled horns, glowing purple eyes; flies.
                    `stone` is the same body frozen into a crouched grey statue (no glow).
  spellbook     24  a floating purple grimoire that opens like a mouth, pages flapping; `cast` opens it
                    wide with glowing runes rising out of it.
  foxfire       16  a little violet-pink flame with fox-ear tips and cute eyes; `burst` is a sparkle pop.
  shadow_wolf   32  dark indigo wolf made of shadow, glowing eyes, wispy edges; `down` crumbles into leaves.
  green_knight  64  chapter 2 boss: a giant topiary knight with a round bush "leaf hat" pierced by a purple
                    thorn, holding a vine whip; `hat_off` is the hat tumbling off (cute, never hurt).
  morgana       64  final boss: elegant red-brown fox witch, purple cloak, crescent-moon staff; `teleport` is
                    a purple-smoke vanish; `down` sits on the floor, sad (never hurt).
  lancelot      32  shiba inu knight: silver light armour, blue-plumed helmet, lance; `dash` is a lance thrust.
  lady_lake     32  white samoyed in a flowing light-blue water dress with droplets floating around her.

Also: portraits (CC2), projectiles magic_orb / thorn / fox_flame / moon_orb (CC3), the one-shot particles
stone_chips and shadow_leaves (CC3), and the black knight sheet with its 8 px lift (CC4, art_v25_knights).

Animation names and loop flags are the contract of DEV_PLAN 4.13 (tests/core/test_v26_contract.gd).
One-shot animations keep about the length of the placeholders, so line A's timing does not move.
Ground-walking characters plant their feet on the same row in every frame (GROUND for 32 px cells,
GROUND64 for the bosses); flyers hover around the cell centre.

    python3 tools/pixel/art_v26_cast.py [preview_dir]   # write the v2.6 cast (and previews)
"""

from __future__ import annotations

import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art_particles  # noqa: E402
import art_v25_knights  # noqa: E402
import paint as P  # noqa: E402
from paint import alpha_px  # noqa: E402
from pixel import Anim, Canvas, build_sheet, contact_sheet, res_path, write_text  # noqa: E402
from rig import Fig, Mat, blade, capsule, ellipse, poly, rect, union  # noqa: E402

GROUND = 29          # 32 px cells: last row of the feet (outline on row 30), like goldie
GROUND64 = 62        # 64 px bosses: like the v2.5 black knight before its lift


# ---------------------------------------------------------------------------
# shared helpers
# ---------------------------------------------------------------------------

def stars(f: Fig, pts) -> None:
    """Cute dizzy stars (never injured)."""
    for (x, y) in pts:
        f.dots([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "yellow")
        f.dot(x, y, "white")


def glow(f: Fig, x: int, y: int, r: int, col: str, a0: int = 150, step: int = 35) -> None:
    """Soft diamond glow around (x, y) only where the frame is empty."""
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = abs(dx) + abs(dy)
            if d <= r:
                f.glow(x + dx, y + dy, alpha_px(col, max(25, a0 - d * step)))


def sparkle(f: Fig, x: int, y: int, col: str = "white", edge: str = "lilac", arm: int = 1) -> None:
    f.dot(x, y, col)
    for k in range(1, arm + 1):
        c = col if k < arm else edge
        f.dots([(x + k, y), (x - k, y), (x, y + k), (x, y - k)], c)


def fade(c: Canvas, a: int) -> Canvas:
    out = c.copy()
    for i, p in enumerate(out.px):
        if p is not None:
            out.px[i] = (p[0], p[1], p[2], min(p[3], a))
    return out


def recolor_canvas(c: Canvas, mapping: dict) -> Canvas:
    """Maps palette colours of a rendered frame to other palette colours (statue, ghost tints)."""
    out = c.copy()
    for y in range(c.h):
        for x in range(c.w):
            n = P.name_at(c, x, y)
            if n is not None and n in mapping:
                a = c.get(x, y)[3]
                out.set(x, y, alpha_px(mapping[n], a) if a < 255 else mapping[n])
    return out


def dissolve(c: Canvas, keep: float, seed: int = 0, from_top: bool = True) -> Canvas:
    """Removes pixels in clumps (2x2 cells), more toward the top: a body breaking up into bits."""
    out = c.copy()
    for y in range(c.h):
        for x in range(c.w):
            if not c.opaque(x, y):
                continue
            h = ((x // 2) * 73856093 ^ (y // 2) * 19349663 ^ seed * 83492791) & 0xFFFF
            t = h / 65535.0
            bias = (1 - y / c.h) * 0.35 if from_top else 0.0
            if t + bias > keep:
                out.set(x, y, None)
    return out


def anim(name: str, frames: list, fps: float, loop: bool, durations=None) -> Anim:
    return Anim(name, frames, fps, loop, durations)


# ---------------------------------------------------------------------------
# gargoyle 石像鬼 (32): flies, swoops, turns to stone
# ---------------------------------------------------------------------------

STONE = Mat(["slate", "stone_d", "stone", "stone_l"], outline="ink", lit="slate", sep="slate", sep_lit="stone_d")
STONE_DK = Mat(["iron", "slate", "stone_d", "stone"], outline="ink", lit="iron", sep="iron", sep_lit="slate")
MEMBRANE = Mat(["iron", "slate", "dusk", "ash"], outline="ink", lit="iron", sep="iron", sep_lit="slate")
HORN = Mat(["iron", "slate", "stone_d", "ash"], outline="ink", lit="iron")
STATUE = Mat(["slate", "stone_d", "stone", "stone_l"], outline="iron", lit="slate")
STATUE_DK = Mat(["iron", "slate", "stone_d", "stone"], outline="iron", lit="iron")

# bat wing poses: wrist and three finger tips relative to the shoulder (x back = negative)
WING_POSES = {
    "up": ((-4, -9), [(-9, -12), (-12, -8), (-10, -3)]),
    "mid": ((-6, -6), [(-13, -7), (-14, -2), (-10, 1)]),
    "down": ((-6, -2), [(-12, 2), (-11, 6), (-7, 6)]),
    "back": ((-7, -4), [(-15, -4), (-14, 0), (-9, 1)]),
    "fold": ((-3, -6), [(-6, -7), (-7, -3), (-5, 1)]),
}


def bat_wing(f: Fig, sx: float, sy: float, pose: str, mat: Mat, bone: str, far: bool = False) -> None:
    (wx, wy), tips = WING_POSES[pose]
    wx, wy = sx + wx, sy + wy
    pts = [(sx + 1, sy), (wx, wy - 0.5)]
    prev = (wx, wy)
    for i, (tx, ty) in enumerate(tips):
        tx, ty = sx + tx, sy + ty
        if i:
            # scallop between two finger tips, pulled toward the wrist
            mx, my = (prev[0] + tx) / 2, (prev[1] + ty) / 2
            pts.append((mx + (wx - mx) * 0.35, my + (wy - my) * 0.35))
        pts.append((tx, ty))
        prev = (tx, ty)
    pts.append((sx - 1, sy + 3))
    shape = poly(pts)
    f.add(shape, mat, centre=(wx, wy), radius=(7, 7), bias=-0.2 if far else 0.0, contrast=0.8)
    if far:
        return
    # bones: the arm to the wrist (lit stone) and the fingers (dark lines)
    from rig import line_px
    f.recolor({p for p in line_px(sx, sy, wx, wy)} & shape, "stone")
    for (tx, ty) in tips:
        f.recolor({p for p in line_px(wx, wy, sx + tx, sy + ty)} & shape, bone)


def gargoyle_frame(wing: str = "mid", bob: int = 0, lean: float = 0.0, eyes: str = "open", mouth: str = "smile",
                   claws: str = "rest", tail: float = 0.0, statue: bool = False, extra=None) -> Fig:
    """A chubby flying stone imp, body centre around (15, 19)."""
    f = Fig(32, 32, seed=61)
    cx, cy = 14.0 + lean, 19.0 + bob
    body_m = STATUE if statue else STONE
    dark_m = STATUE_DK if statue else STONE_DK
    wing_m = STATUE_DK if statue else MEMBRANE
    horn_m = STATUE_DK if statue else HORN
    sx, sy = cx - 1.5, cy - 4.0          # shoulder (wing root)
    bat_wing(f, sx - 2, sy - 1, wing, wing_m, "iron", far=True)
    # tail with an arrow tip, curling down-back
    tx, ty = cx - 5.5, cy + 4.0
    ex, ey = tx - 3.5, ty - 1.5 - tail * 2.5
    f.add(union(capsule(cx - 3, cy + 2, tx, ty, 1.1), capsule(tx, ty, ex, ey, 0.8)), dark_m, bias=0.0)
    f.add(poly([(ex + 0.5, ey - 1.6), (ex - 2.8, ey - 0.4), (ex + 0.5, ey + 1.6)]), dark_m, bias=0.1)
    # far leg
    fy = cy + 6 if claws != "tuck" else cy + 5
    f.add(union(capsule(cx - 1.5, cy + 2, cx - 1.5, fy - 1, 1.3), rect(int(cx - 3), int(fy) - 1, 3, 1)), dark_m,
          bias=-0.1)
    # body: a chubby round stone torso
    body = union(ellipse(cx, cy + 0.5, 5.0, 4.6), ellipse(cx + 0.5, cy - 2.0, 4.2, 3.6))
    f.add(body, body_m, centre=(cx - 1.5, cy - 2.0), radius=(6.0, 5.5), bias=-0.02)
    belly = {(x, y) for (x, y) in ellipse(cx + 1.6, cy + 1.2, 2.6, 2.8) if (x, y) in body}
    f.recolor(belly, "stone")
    f.recolor({(x, y) for (x, y) in belly if (y - int(cy)) % 2 == 0}, "stone_l" if not statue else "stone")
    # near leg with claws
    f.add(union(capsule(cx + 2, cy + 2.5, cx + 2.5, fy - 1, 1.4), rect(int(cx + 1), int(fy) - 1, 4, 1)), body_m,
          bias=0.0)
    f.dots([(int(cx + 4), int(fy) - 1), (int(cx + 2), int(fy) - 1)], "slate")
    # head: big round head, pointed ears swept back, curled horns
    hx, hy = cx + 2.5, cy - 8.5
    for (ox, oy, d) in ((-2.4, -3.2, -1), (1.2, -3.8, 1)):
        bx, by = hx + ox, hy + oy
        horn = union(capsule(bx, by, bx - 1.0, by - 2.6, 1.2), capsule(bx - 1.0, by - 2.6, bx - 2.8, by - 3.8, 0.8),
                     {(int(bx - 4), int(by - 4))})
        f.add(horn, horn_m, bias=0.15 if d > 0 else -0.15)
    ear = poly([(hx - 3.0, hy - 1.5), (hx - 8.5, hy - 2.5), (hx - 3.5, hy + 1.5)])
    f.add(ear, dark_m, bias=0.1)
    head = union(ellipse(hx, hy, 5.0, 4.4), ellipse(hx + 2.6, hy + 1.6, 2.8, 2.2))
    f.add(head, body_m, centre=(hx - 1.5, hy - 2.0), radius=(5.5, 5.0), bias=-0.03)
    hxi, hyi = int(round(hx)), int(round(hy))
    # heavy carved brow over the eyes
    f.recolor({(x, hyi - 2) for x in range(hxi, hxi + 6)} & head, "stone_d")
    f.dots([(hxi + 5, hyi + 1)], "slate")
    # eyes: big glowing purple (none when it is a statue)
    ex, ey = hxi + 1, hyi - 1
    if statue:
        f.dots([(ex, ey + 1), (ex + 1, ey + 1), (ex + 3, ey + 1), (ex + 4, ey + 1)], "stone_d")
    elif eyes in ("open", "angry"):
        for x0 in (ex, ex + 3):
            f.dots([(x0, ey), (x0 + 1, ey), (x0, ey + 1), (x0 + 1, ey + 1)], "violet")
            f.dot(x0, ey, "white")
            f.dot(x0 + 1, ey, "lilac")
        if eyes == "angry":
            f.dots([(ex - 1, ey - 1), (ex, ey - 1), (ex + 4, ey - 1), (ex + 5, ey - 1)], "iron")
        f.glow(ex + 6, ey, alpha_px("lilac", 120))
        f.glow(ex + 6, ey + 1, alpha_px("violet", 70))
    elif eyes == "squint":
        f.dots([(ex, ey), (ex + 1, ey + 1), (ex, ey + 2)], "violet")
        f.dots([(ex + 4, ey), (ex + 3, ey + 1), (ex + 4, ey + 2)], "violet")
    mx, my = hxi + 3, hyi + 2
    if statue:
        f.dots([(mx - 1, my + 1), (mx, my + 1), (mx + 1, my + 1)], "stone_d")
    elif mouth == "smile":
        f.dots([(mx - 1, my), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my)], "iron")
        f.dot(mx + 1, my + 2, "white")
    elif mouth == "open":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my), (mx, my + 1), (mx + 1, my + 1)], "plum")
        f.dots([(mx - 1, my), (mx + 2, my)], "white")
    elif mouth == "o":
        f.dots([(mx, my), (mx + 1, my), (mx, my + 1), (mx + 1, my + 1)], "plum")
    # carved crack on the shoulder
    f.recolor({(int(cx - 3), int(cy - 1)), (int(cx - 2), int(cy)), (int(cx - 2), int(cy + 1))}, "slate")
    # front arm with claws
    ax, ay = {"swipe": (cx + 8, cy - 3), "reach": (cx + 7, cy + 3), "tuck": (cx + 3, cy + 1)}.get(claws,
                                                                                                (cx + 5, cy + 2))
    f.add(capsule(cx + 2, cy - 1.5, ax, ay, 1.3), body_m, bias=0.05)
    f.dots([(int(ax) + 1, int(ay) - 1), (int(ax) + 1, int(ay) + 1)], "stone_l" if not statue else "stone")
    # near wing in front of the body
    bat_wing(f, sx, sy, wing, wing_m, "iron" if not statue else "slate")
    if extra:
        extra(f)
    return f


def gargoyle() -> list[Anim]:
    G = gargoyle_frame
    idle = [G("mid"), G("up", bob=-1), G("mid"), G("down", bob=1)]
    run = [G("up", bob=-1, lean=1), G("mid", lean=1), G("down", bob=1, lean=1, tail=0.5), G("mid", lean=1)]
    attack = [G("up", bob=-1, lean=-1, claws="tuck", eyes="angry", mouth="open"),
              G("back", lean=2, claws="swipe", eyes="angry", mouth="open",
                extra=lambda f: _claw_smear(f, 26, 13)),
              G("down", bob=1, lean=1, claws="reach", eyes="angry"),
              G("mid", lean=0)]
    hurt = [G("up", lean=-2, eyes="squint", mouth="o", extra=lambda f: stars(f, [(13, 3), (24, 5)])),
            G("mid", lean=-1, eyes="squint", mouth="o")]
    swoop = [G("back", bob=1, lean=2, claws="reach", eyes="angry", mouth="open", tail=0.8,
               extra=lambda f: _speed_lines(f, 0)),
             G("back", bob=2, lean=2, claws="reach", eyes="angry", mouth="open", tail=1.0,
               extra=lambda f: _speed_lines(f, 1))]
    stone = [gargoyle_stone(0), gargoyle_stone(1)]
    r = lambda fs: [x.render() if isinstance(x, Fig) else x for x in fs]  # noqa: E731
    return [anim("idle", r(idle), 8.0, True), anim("run", r(run), 12.0, True),
            anim("attack", r(attack), 14.0, False, [0.8, 1.0, 1.0, 0.8]),
            anim("hurt", r(hurt), 6.0, False, [1.0, 3.0]),
            anim("swoop", r(swoop), 12.0, True), anim("stone", stone, 3.0, True)]


def _claw_smear(f: Fig, x: int, y: int) -> None:
    for k in range(3):
        for i in range(4):
            f.glow(x - 1 + i, y - 4 + k * 3 + i, alpha_px("white" if i > 1 else "lilac", 200 - i * 20))


def _speed_lines(f: Fig, k: int) -> None:
    for (x, y, n) in ((2 + k, 10, 4), (1 + k, 15, 5), (3 + k, 21, 3)):
        for i in range(n):
            f.glow(x + i, y - (i // 2), alpha_px("white", 110 + i * 25))


def gargoyle_stone(k: int) -> Canvas:
    """Frozen into a crouched grey statue: wings folded, feet on a little plinth of stone."""
    f = gargoyle_frame("fold", bob=3, claws="tuck", statue=True)
    c = f.render()
    if k:
        # a cold glint sliding over the stone
        for (x, y) in ((19, 10), (20, 9), (11, 16)):
            if c.opaque(x, y):
                c.set(x, y, "white")
    return c


# ---------------------------------------------------------------------------
# spellbook 魔法書 (24): a floating grimoire that opens like a mouth
# ---------------------------------------------------------------------------

COVER = Mat(["plum", "dusk", "violet", "lilac"], outline="ink", lit="plum", sep="plum", sep_lit="dusk")
COVER_IN = Mat(["ink", "wine", "plum"], outline="ink", lit="plum")
PAGES = Mat(["sand", "cream", "white"], outline="umber", lit="brown_d", sep="dirt", sep_lit="sand")
GILT = Mat(["gold_d", "gold", "yellow"], outline="brown_d")
RUNES = ("lilac", "yellow", "sky_l")


def _rot(px: float, py: float, ox: float, oy: float, a: float, squash: float = 1.0) -> tuple[float, float]:
    """Rotates (px, py) about (ox, oy) by a radians (screen: positive = counter-clockwise, i.e. up)."""
    dx, dy = px - ox, py - oy
    return ox + dx * math.cos(a) + dy * math.sin(a), oy + (-dx * math.sin(a) + dy * math.cos(a)) * squash


def book_frame(open_deg: float = 8.0, bob: int = 0, flap: int = 0, eyes: str = "open", tilt: float = 0.0,
               runes: int = 0, glow_pages: bool = False, lean: float = 0.0, extra=None) -> Fig:
    f = Fig(24, 24, seed=71)
    by = 14.0 + bob
    bx = 3.0 + lean
    a = math.radians(open_deg)
    t = math.radians(tilt)
    hx, hy = bx + 1.0, by - 1.0                       # hinge (spine) of the top cover

    def R(x, y):                                      # whole-book tilt about the spine
        return _rot(x, y, hx, hy + 2, t)
    # bottom cover (thick slab) and the page block
    bottom = poly([R(bx, by + 1), R(bx + 15, by + 1), R(bx + 16, by + 4), R(bx + 1, by + 4)])
    f.add(bottom, COVER, bias=-0.1)
    block = poly([R(bx + 1.5, by - 1), R(bx + 15, by - 1), R(bx + 15.5, by + 1.5), R(bx + 2, by + 1.5)])
    f.add(block, PAGES, bias=0.05, sep=True)
    for k in (0, 1):
        y = int(round(R(bx + 8, by + k * 1.0 - 0.2)[1]))
        f.recolor({(x, y) for x in range(24) if (x, y) in block and x % 2 == k}, "sand")
    # loose pages fluttering between the block and the cover
    if open_deg > 12:
        for i in range(2):
            pa = a * (0.35 + 0.3 * i) + (0.18 if (flap + i) % 2 else -0.05)
            tip = _rot(hx + 13, hy, hx, hy, pa + t)
            mid = _rot(hx + 7, hy - (1.2 if (flap + i) % 2 else -0.3), hx, hy, pa + t)
            page = union(capsule(hx + 1, hy, mid[0], mid[1], 0.8), capsule(mid[0], mid[1], tip[0], tip[1], 0.7))
            f.add(page, PAGES, bias=0.2 - 0.1 * i, sep=True)
    if glow_pages:
        for (x, y) in block:
            if y <= int(by):
                f.recolor({(x, y)}, "white")
    # top cover, hinged at the spine; inside face shows when it is open wide
    corners = [(hx, hy - 0.5), (hx + 15, hy - 0.5), (hx + 15.5, hy - 4.8), (hx - 0.5, hy - 4.8)]
    rc = [_rot(x, y, hx, hy, a + t) for (x, y) in corners]
    cover = poly(rc)
    f.add(cover, COVER, centre=_rot(hx + 5, hy - 4, hx, hy, a + t), radius=(9, 5), bias=0.08)
    if open_deg > 35:
        inner = {p for p in cover if p not in poly([_rot(x, y, hx, hy, a + t) for (x, y) in
                                                     [(hx, hy - 2.0), (hx + 15, hy - 2.0), (hx + 15.5, hy - 4.8),
                                                      (hx - 0.5, hy - 4.8)]])}
        f.recolor(inner, "wine")
    # gilt corner, clasp and spine bands
    cx_, cy_ = _rot(hx + 14, hy - 3, hx, hy, a + t)
    f.pix({(int(cx_), int(cy_)): "yellow", (int(cx_) - 1, int(cy_)): "gold", (int(cx_), int(cy_) + 1): "gold_d"},
          GILT, sep=False)
    sx0, sy0 = R(bx, by - 1)
    spine = union(ellipse(sx0 + 0.5, sy0 + 1.5, 1.8, 3.4))
    f.add(spine, COVER, bias=0.1)
    f.recolor({(x, y) for (x, y) in spine if y in (int(sy0), int(sy0 + 3))}, "gold")
    # face on the cover: big eyes, a little blush
    ex, ey = _rot(hx + 8.5, hy - 2.6, hx, hy, a + t)
    ex, ey = int(round(ex)), int(round(ey))
    if eyes == "open":
        for x0 in (ex - 2, ex + 2):
            f.dots([(x0, ey - 1), (x0 + 1, ey - 1), (x0, ey), (x0 + 1, ey)], "ink")
            f.dot(x0, ey - 1, "white")
    elif eyes == "angry":
        for x0 in (ex - 2, ex + 2):
            f.dots([(x0, ey), (x0 + 1, ey), (x0, ey - 1), (x0 + 1, ey - 1)], "ink")
            f.dot(x0 + 1, ey - 1, "yellow")
        f.dots([(ex - 3, ey - 2), (ex - 2, ey - 2), (ex + 3, ey - 2), (ex + 4, ey - 2)], "plum")
    elif eyes == "squint":
        f.dots([(ex - 2, ey - 1), (ex - 1, ey), (ex - 2, ey + 1)], "ink")
        f.dots([(ex + 3, ey - 1), (ex + 2, ey), (ex + 3, ey + 1)], "ink")
    elif eyes == "closed":
        f.dots([(ex - 2, ey), (ex - 1, ey), (ex + 2, ey), (ex + 3, ey)], "ink")
    f.dots([(ex - 3, ey + 1), (ex + 4, ey + 1)], "pink")
    # glowing runes rising out of the pages
    for i in range(runes):
        rx = int(bx + 8 + i * 4)
        ry = int(by - 7 - ((i * 3 + runes) % 3) - runes)
        col = RUNES[i % 3]
        glyph = [(rx, ry), (rx + 1, ry), (rx + 2, ry), (rx + 1, ry + 1), (rx, ry + 2), (rx + 2, ry + 2)] if i % 2 \
            else [(rx + 1, ry), (rx, ry + 1), (rx + 1, ry + 1), (rx + 2, ry + 1), (rx + 1, ry + 2)]
        f.dots(glyph, col)
        for (gx, gy) in glyph:
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                f.glow(gx + dx, gy + dy, alpha_px("violet" if col != "yellow" else "amber", 90))
    if extra:
        extra(f)
    return f


def spellbook() -> list[Anim]:
    B = book_frame
    idle = [B(10, 0, 0), B(16, -1, 1), B(22, -1, 0), B(14, 0, 1)]
    run = [B(18, -1, 0, tilt=-6, lean=1), B(28, 0, 1, tilt=-6, lean=1), B(20, 1, 0, tilt=-6, lean=1),
           B(30, 0, 1, tilt=-6, lean=1)]
    attack = [B(45, -1, 0, eyes="angry"), B(4, 0, 0, eyes="angry", lean=2,
                                            extra=lambda f: f.dots([(21, 12), (22, 11), (22, 14)], "white")),
              B(20, 0, 1, eyes="open")]
    hurt = [B(0, 1, 0, eyes="squint", tilt=10, extra=lambda f: stars(f, [(6, 3), (17, 2)])),
            B(4, 1, 0, eyes="closed", tilt=6)]
    cast = [B(40, -1, 0, eyes="open", runes=1), B(70, -2, 1, eyes="angry", runes=2, glow_pages=True),
            B(75, -2, 0, eyes="angry", runes=3, glow_pages=True)]
    r = lambda fs: [x.render() for x in fs]  # noqa: E731
    return [anim("idle", r(idle), 8.0, True), anim("run", r(run), 12.0, True),
            anim("attack", r(attack), 12.0, False), anim("hurt", r(hurt), 6.0, False, [1.0, 3.0]),
            anim("cast", r(cast), 10.0, False)]


# ---------------------------------------------------------------------------
# foxfire 狐火 (16): a little violet-pink flame with fox-ear tips
# ---------------------------------------------------------------------------

FLAME_RAMP = ["violet", "rose", "pink", "white"]      # tips, rim, body, core


def flame_shape(cx: float, cy: float, r: float, tip: tuple[float, float], ears: bool = True) -> set:
    """A round flame body with a flicking tip (the tail) and two pointed fox ears on top."""
    body = ellipse(cx, cy, r, r * 0.95)
    tx, ty = tip
    tail = poly([(cx - r * 0.85, cy - r * 0.2), (cx - r * 0.1, cy - r * 0.9), (tx, ty)])
    lick = poly([(cx - r * 0.95, cy + r * 0.3), (cx - r * 0.7, cy - r * 0.5), (tx - 1.0, cy - r * 0.1 + (ty - cy) * 0.1)])
    shape = body | tail | lick
    if ears:
        for (ex, d) in ((cx - 0.6, -1), (cx + r * 0.75, 1)):
            shape |= poly([(ex - 1.6, cy - r * 0.55), (ex + 0.4 * d, cy - r - 2.2), (ex + 1.6, cy - r * 0.55)])
    return shape


def flame_paint(c: Canvas, shape: set, cx: float, cy: float, r: float, outline: str = "plum",
                ramp=FLAME_RAMP) -> None:
    """ramp: (cool tips, warm rim, body, core). Hot white core low in the body, pink body, a rose rim
    below and violet-lilac licks above (the tail and the ear tips)."""
    tips, rim, body, core = ramp
    body_px = ellipse(cx, cy, r, r * 0.95)
    edge = P.edge(shape)
    for (x, y) in shape:
        if (x, y) not in body_px:
            c.set(x, y, tips if (x, y) in edge else "lilac")
            continue
        if (x, y) in edge:
            c.set(x, y, rim if y + 0.5 > cy - r * 0.3 else tips)
        else:
            c.set(x, y, body)
    for (x, y) in ellipse(cx - 0.8, cy + r * 0.45, r * 0.42, r * 0.32):
        if (x, y) in shape and (x, y) not in edge:
            c.set(x, y, core)
    ring = set()
    for (x, y) in shape:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in shape:
                ring.add(q)
    for (x, y) in ring:
        c.set(x, y, outline)


def foxfire_frame(sway: float = 0.0, bob: int = 0, lean: float = 0.0, r: float = 4.6, eyes: str = "open",
                  mouth: str = "smile", sparks=(), stars_at=()) -> Canvas:
    c = Canvas(16, 16)
    cx, cy = 8.0 + lean, 9.0 + bob
    tip = (cx - 4.5 - lean * 1.5 + sway, cy - r - 4.0 + abs(sway) * 0.5)
    shape = flame_shape(cx, cy, r, tip)
    shape = {(x, y) for (x, y) in shape if 0 <= x < 16 and 0 <= y < 16}
    # soft glow halo first, so the outline sits on top of it
    for (x, y) in P.ellipse(cx, cy, r + 2.4, r + 2.2):
        c.set(x, y, alpha_px("lilac", 55))
    flame_paint(c, shape, cx, cy, r)
    # inner ear colour
    ex, ey = int(round(cx + r * 0.75)), int(round(cy - r - 0.6))
    c.set(ex, ey, "pink")
    # face (the flame looks right)
    fx, fy = int(round(cx + 1)), int(round(cy - 1))
    if eyes == "open":
        for x0 in (fx - 1, fx + 2):
            c.set(x0, fy - 1, "plum")
            c.set(x0, fy, "plum")
        c.set(fx - 1, fy - 1, "white")
        c.set(fx + 2, fy - 1, "white")
    elif eyes == "happy":
        c.set(fx - 2, fy, "plum"); c.set(fx - 1, fy - 1, "plum"); c.set(fx, fy, "plum")
        c.set(fx + 1, fy, "plum"); c.set(fx + 2, fy - 1, "plum"); c.set(fx + 3, fy, "plum")
    elif eyes == "squint":
        c.set(fx - 1, fy - 1, "plum"); c.set(fx, fy, "plum"); c.set(fx - 1, fy + 1, "plum")
        c.set(fx + 3, fy - 1, "plum"); c.set(fx + 2, fy, "plum"); c.set(fx + 3, fy + 1, "plum")
    if mouth == "smile":
        c.set(fx, fy + 2, "rose"); c.set(fx + 1, fy + 2, "rose")
    elif mouth == "open":
        c.set(fx, fy + 2, "plum"); c.set(fx + 1, fy + 2, "plum"); c.set(fx, fy + 3, "rose")
    elif mouth == "o":
        c.set(fx + 1, fy + 2, "plum")
    c.set(fx - 2, fy + 1, "rose")
    c.set(fx + 4, fy + 1, "rose")
    for (x, y) in sparks:
        c.set(x, y, "pink")
        if c.get(x, y - 1) is None:
            c.set(x, y - 1, alpha_px("lilac", 150))
    for (x, y) in stars_at:
        for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            c.set(x + dx, y + dy, "yellow")
        c.set(x, y, "white")
    return c


def foxfire_burst(k: int) -> Canvas:
    """A sparkle pop: the flame swells white, then becomes a ring of little stars that fade."""
    c = Canvas(16, 16)
    if k == 0:
        shape = ellipse(8, 9, 5.6, 5.4)
        for (x, y) in P.ellipse(8, 9, 7.6, 7.4):
            c.set(x, y, alpha_px("pink", 90))
        flame_paint(c, shape, 8, 9, 5.6, ramp=["pink", "pink", "white", "white"])
        c.set(7, 8, "rose"); c.set(10, 8, "rose")        # happy squeezed eyes
        return c
    if k == 1:
        for (x, y) in P.ellipse(8, 9, 7.2, 7.0) - P.ellipse(8, 9, 4.2, 4.0):
            c.set(x, y, alpha_px("pink", 150))
        for (x, y) in P.edge(P.ellipse(8, 9, 7.2, 7.0)):
            c.set(x, y, "white")
        for (x, y) in ((8, 9), (7, 9), (9, 9), (8, 8), (8, 10)):
            c.set(x, y, "white")
        return c
    pts = [(8 + round(math.cos(a) * (5 + k)), 9 + round(math.sin(a) * (5 + k))) for a in
           [i * math.pi / 3 + k * 0.3 for i in range(6)]]
    for i, (x, y) in enumerate(pts):
        col = "white" if k == 2 else ("pink" if i % 2 else "lilac")
        c.set(x, y, col)
        if k == 2 or i % 2 == 0:
            for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                c.set(x + dx, y + dy, alpha_px("pink" if k == 2 else "lilac", 200 if k == 2 else 120))
    return c


def foxfire() -> list[Anim]:
    F = foxfire_frame
    idle = [F(0.0), F(1.0, sparks=[(3, 4)]), F(1.6, bob=-1), F(0.6, sparks=[(13, 3)])]
    run = [F(-1.0, lean=1, eyes="happy"), F(-2.0, bob=-1, lean=1, eyes="happy", sparks=[(2, 9)]),
           F(-1.4, lean=1, eyes="happy"), F(-2.4, bob=-1, lean=1, eyes="happy", sparks=[(1, 11)])]
    attack = [F(1.0, r=4.2, eyes="squint", mouth="o"), F(-2.0, r=5.4, lean=1, mouth="open"),
              F(0.0, r=4.8, mouth="open")]
    hurt = [F(2.0, r=4.0, lean=-1, eyes="squint", mouth="o", stars_at=[(3, 4)]),
            F(1.0, r=4.2, eyes="squint", mouth="o")]
    burst = [foxfire_burst(k) for k in range(4)]
    return [anim("idle", idle, 10.0, True), anim("run", run, 12.0, True), anim("attack", attack, 12.0, False),
            anim("hurt", hurt, 6.0, False, [1.0, 3.0]), anim("burst", burst, 16.0, False)]


# ---------------------------------------------------------------------------
# shadow_wolf 影狼 (32): a wolf of dark indigo shadow with glowing eyes and wispy edges
# ---------------------------------------------------------------------------

SHADOW = Mat(["navy", "night_d", "night", "dusk"], outline="ink", lit="navy", fur=0.16, sep="navy",
             sep_lit="night_d")
SHADOW_FAR = Mat(["ink", "navy", "night_d", "night"], outline="ink", lit="ink", fur=0.1, sep="ink", sep_lit="navy")
LEAF_COLS = ("leaf_d", "moss", "leaf", "forest", "dusk", "moss_d")


def wolf_frame(legs=((0, 0), (0, 0), (0, 0), (0, 0)), bob: int = 0, lean: float = 0.0, head_dy: float = 0.0,
               mouth: str = "shut", eyes: str = "open", tail: float = 0.0, stretch: float = 0.0, wisp: int = 0,
               extra=None) -> Fig:
    """legs: (dx, lift) for back-far, front-far, back-near, front-near."""
    f = Fig(32, 32, seed=81)
    cx, cy = 14.5 + lean, 20.0 + bob
    L = stretch
    # tail: big bushy plume, sweeping up-back, ending in wisps
    ta = math.radians(200 - tail * 30)
    mx_, my_ = cx - 6.5 - L * 0.6 + math.cos(ta) * 3.2, cy - 2.5 - math.sin(ta) * 3.2
    tx, ty = mx_ + math.cos(ta + 0.45) * 3.4, my_ - math.sin(ta + 0.45) * 3.4
    tl = union(capsule(cx - 6.5 - L * 0.6, cy - 2.5, mx_, my_, 2.1), capsule(mx_, my_, tx, ty, 2.0),
               ellipse(tx, ty, 2.1, 2.0))
    f.add(tl, SHADOW, centre=(mx_, my_ - 2), radius=(5, 4), bias=0.02)
    # far legs (darker)
    def leg(x, top, dx, lift, mat, bias):
        foot = GROUND - lift
        s = union(capsule(x, top, x + dx * 0.5, (top + foot) / 2, 1.5), capsule(x + dx * 0.5, (top + foot) / 2,
                                                                               x + dx, foot - 0.5, 1.1))
        s |= {(int(round(x + dx)) + k, foot) for k in (0, 1)}
        f.add(s, mat, mode="cyl_v", bias=bias)
    (b0, b1), (f0, f1), (b2, b3), (f2, f3) = legs
    leg(cx - 4.5 - L * 0.6, cy + 1, b0, b1, SHADOW_FAR, -0.2)
    leg(cx + 5 + L * 0.5, cy + 1, f0, f1, SHADOW_FAR, -0.2)
    # body: long lean torso, deep chest
    body = union(ellipse(cx - 0.5 - L * 0.3, cy, 6.8 + L * 0.6, 4.0), ellipse(cx + 4 + L * 0.5, cy - 0.5, 4.4, 4.6))
    f.add(body, SHADOW, centre=(cx - 1, cy - 3), radius=(10, 6), bias=0.04)
    # shaggy ruff on the neck
    ruff = poly([(cx + 2 + L * 0.5, cy - 4), (cx + 6 + L * 0.5, cy - 6), (cx + 8 + L * 0.5, cy - 1),
                 (cx + 6 + L * 0.5, cy + 3), (cx + 4 + L * 0.5, cy + 1)])
    f.add(ruff, SHADOW, centre=(cx + 4, cy - 5), radius=(5, 5), bias=0.12)
    leg(cx - 3.5 - L * 0.6, cy + 1.5, b2, b3, SHADOW, -0.14)
    leg(cx + 6 + L * 0.5, cy + 1.5, f2, f3, SHADOW, -0.14)
    # head with a long snout and pointed ears
    hx, hy = cx + 8.5 + L * 0.7, cy - 6 + head_dy
    for (ex, ey, m) in ((hx - 3.0, hy - 3, SHADOW_FAR), (hx - 0.5, hy - 3.2, SHADOW)):
        f.add(poly([(ex - 2.0, ey + 1.5), (ex - 0.4, ey - 4.8), (ex + 2.0, ey + 1)]), m, bias=0.1)
    head = union(ellipse(hx, hy, 4.2, 3.6), poly([(hx + 1, hy - 2.0), (hx + 7.5, hy + 0.2), (hx + 7.5, hy + 1.8),
                                                  (hx + 1, hy + 3.0)]))
    if mouth == "open":
        head = union(ellipse(hx, hy, 4.2, 3.6), poly([(hx + 1, hy - 2.0), (hx + 8, hy - 0.8), (hx + 7.5, hy + 0.6),
                                                      (hx + 1, hy + 1.2)]),
                     poly([(hx + 1, hy + 1.6), (hx + 6.5, hy + 2.8), (hx + 6, hy + 3.8), (hx + 0.5, hy + 3.2)]))
    f.add(head, SHADOW, centre=(hx - 1, hy - 1.5), radius=(5, 4), bias=0.1)
    hxi, hyi = int(round(hx)), int(round(hy))
    f.dots([(hxi + 7, hyi), (hxi + 8, hyi)] if mouth != "open" else [(hxi + 8, hyi - 1)], "ink")
    if mouth == "open":
        f.dots([(hxi + 2, hyi + 1), (hxi + 3, hyi + 1), (hxi + 4, hyi + 2)], "plum")
        f.dots([(hxi + 4, hyi + 1), (hxi + 2, hyi + 2)], "white")
    # glowing eyes
    ex, ey = hxi + 1, hyi - 1
    if eyes == "open":
        f.dots([(ex, ey), (ex + 1, ey), (ex + 1, ey + 1)], "lilac")
        f.dot(ex + 1, ey, "white")
        for (gx, gy) in ((ex + 2, ey), (ex + 2, ey - 1), (ex - 1, ey)):
            f.glow(gx, gy, alpha_px("violet", 120))
    elif eyes == "squint":
        f.dots([(ex, ey - 1), (ex + 1, ey), (ex, ey + 1)], "lilac")
    elif eyes == "dizzy":
        f.dots([(ex - 1, ey - 1), (ex + 1, ey - 1), (ex, ey), (ex - 1, ey + 1), (ex + 1, ey + 1)], "lilac")
    # wispy edges: shadow smoke drifting up off the back and tail
    for i, (wx, wy) in enumerate(((cx - 3 - L, cy - 5), (cx - 7 - L, cy - 5), (tx - 1, ty - 3), (cx + 1, cy - 6))):
        k = (i + wisp) % 3
        x0, y0 = int(round(wx - k * 0.5)), int(round(wy - k))
        f.glow(x0, y0, alpha_px("dusk", 200 - k * 40))
        f.glow(x0 - 1, y0 - 1, alpha_px("violet", 150 - k * 30))
        f.glow(x0 - 1, y0 - 2, alpha_px("lilac", 80))
    # violet rim light on the back (the glow of the curse)
    f.recolor({(x, y) for (x, y) in body if (x, y - 1) not in body and (x, y - 1) not in ruff
               and (x + y + wisp) % 3 != 0}, "dusk")
    if extra:
        extra(f)
    return f


LEAF_SHAPES = ([(0, 0), (1, 0), (1, 1), (2, 1)], [(1, 0), (2, 0), (0, 1), (1, 1)], [(0, 0), (0, 1), (1, 1), (1, 2)],
               [(0, 0), (1, 0), (2, 0), (1, 1)])


def _leaf(c: Canvas, x: int, y: int, k: int, a: int = 255) -> None:
    """A chunky 3x2 leaf: a body colour and a lighter vein pixel."""
    col = LEAF_COLS[k % len(LEAF_COLS)]
    shape = LEAF_SHAPES[k % len(LEAF_SHAPES)]
    for i, (dx, dy) in enumerate(shape):
        cc = "leaf_l" if (i == 1 and col in ("leaf", "moss", "leaf_d")) else col
        c.set(x + dx, y + dy, cc if a == 255 else alpha_px(cc, a))


def wolf_down(k: int) -> Canvas:
    """Lies down dizzy, then the shadow crumbles into a little pile of forest leaves (not hurt)."""
    lie = wolf_frame(legs=((3, 0), (3, 0), (3, 0), (3, 0)), bob=5, head_dy=4, eyes="dizzy", tail=-0.3,
                     extra=lambda f: stars(f, [(22, 7), (28, 10)]) if k == 0 else None).render()
    if k == 0:
        return lie
    rng = __import__("random").Random(40 + k)
    if k == 1:
        c = dissolve(lie, 0.62, seed=k)
        spots = [(rng.randrange(6, 28), rng.randrange(16, 27)) for _ in range(9)]
    elif k == 2:
        c = Canvas(32, 32)
        spots = [(int(16 + math.cos(t) * rng.uniform(0, 8)), int(26 + math.sin(t) * rng.uniform(0, 2.0)) - 1)
                 for t in [rng.uniform(0, 2 * math.pi) for _ in range(22)]]
        spots += [(rng.randrange(9, 23), rng.randrange(20, 25)) for _ in range(8)]
    else:
        c = Canvas(32, 32)
        spots = [(rng.randrange(5, 27), rng.randrange(26, 29)) for _ in range(7)]
    for i, (x, y) in enumerate(spots):
        _leaf(c, x, y, rng.randrange(0, 24), 255 if k < 3 or i % 2 else 190)
    return c


def shadow_wolf() -> list[Anim]:
    W = wolf_frame
    idle = [W(), W(bob=1, wisp=1, tail=0.15), W(bob=1, wisp=2, tail=0.25), W(wisp=0, tail=0.1)]
    gallop = [((-3, 0), (3, 1), (-2, 0), (4, 2)), ((-1, 2), (1, 0), (0, 3), (2, 0)), ((2, 3), (-2, 0), (3, 2), (-1, 0)),
              ((3, 1), (-3, 0), (4, 0), (-3, 1)), ((1, 0), (-1, 2), (2, 0), (0, 3)), ((-2, 0), (2, 3), (-1, 0), (3, 2))]
    bobs = [0, -1, -1, 0, -1, -1]
    run = [W(legs=gallop[i], bob=bobs[i], lean=0.5, wisp=i, tail=-0.4, mouth="open" if i % 3 == 0 else "shut")
           for i in range(6)]
    attack = [W(legs=((-2, 0), (-1, 0), (-2, 0), (-1, 0)), lean=-1.5, bob=1, head_dy=1, mouth="shut", tail=0.3),
              W(legs=((-3, 0), (4, 2), (-2, 0), (5, 3)), lean=2.0, bob=-1, head_dy=-1, mouth="open", stretch=1.5),
              W(legs=((-2, 0), (3, 0), (-1, 0), (4, 0)), lean=2.0, head_dy=1, mouth="open", stretch=1.0),
              W(lean=0.5)]
    hurt = [W(lean=-2, head_dy=-1, eyes="squint", tail=0.6, extra=lambda f: stars(f, [(20, 3), (28, 5)])),
            W(lean=-1, eyes="squint", tail=0.4)]
    dash = [W(legs=((-4, 1), (5, 3), (-3, 2), (6, 4)), stretch=2.5, lean=-1, bob=-1, mouth="open", tail=-0.9,
              wisp=0, extra=lambda f: _speed_lines(f, 0)),
            W(legs=((-5, 2), (4, 4), (-4, 3), (5, 3)), stretch=2.5, lean=-1, bob=-2, mouth="open", tail=-1.0,
              wisp=1, extra=lambda f: _speed_lines(f, 1))]
    down = [wolf_down(k) for k in range(4)]
    r = lambda fs: [x.render() for x in fs]  # noqa: E731
    return [anim("idle", r(idle), 6.0, True), anim("run", r(run), 14.0, True),
            anim("attack", r(attack), 14.0, False, [1.2, 1.0, 1.0, 0.8]),
            anim("hurt", r(hurt), 6.0, False, [1.0, 3.0]), anim("dash", r(dash), 12.0, True),
            anim("down", down, 4.0, False, [1.2, 1.0, 1.0, 0.8])]


# ---------------------------------------------------------------------------
# lancelot 蘭斯洛特 (32): shiba inu knight, silver light armour, blue-plumed helmet, lance
# ---------------------------------------------------------------------------

SHIBA = Mat(["brown", "gold_d", "orange", "amber"], outline="umber", lit="brown_d", fur=0.1, sep="brown",
            sep_lit="gold_d")
URA = Mat(["sand", "cream", "white"], outline="brown_d", lit="brown", fur=0.06, sep="dirt", sep_lit="sand")
SILVER = Mat(["steel_d", "steel", "steel_l", "white"], outline="navy", lit="iron", spec="white", spec_at=0.84,
             sep="steel_d", sep_lit="steel")
PLUME_B = Mat(["water_d", "water", "sky", "sky_l"], outline="navy", lit="night")
LANCE_WOOD = Mat(["brown_d", "brown", "gold_d"], outline="umber")


def lance(f: Fig, hx: float, hy: float, deg: float, reach: float = 12.0, back: float = 6.0, pennant: int = 0) -> None:
    """A knight's lance gripped at (hx, hy): shaft behind the hand, a cone guard, a long tapering steel tip."""
    a = -math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    shaft = {}
    for i in range(int(-back), 3):
        shaft[(int(round(hx + dx * i)), int(round(hy + dy * i)))] = "brown" if i % 3 else "gold_d"
    f.pix(shaft, LANCE_WOOD)
    # pennant (small blue flag) hanging from the shaft behind the guard
    px0, py0 = hx + dx * 1, hy + dy * 1
    flag = {}
    for k in range(4):
        for j in range(3 - (k + 1) // 2):
            flag[(int(round(px0 - dx * k)), int(round(py0 - dy * k)) + 1 + j + (pennant if k >= 2 else 0))] = \
                "sky" if j == 0 else "water"
    f.pix(flag, PLUME_B)
    # vamplate: a cone guard in front of the hand
    gx, gy = hx + dx * 2.5, hy + dy * 2.5
    nx, ny = -dy, dx
    guard = {}
    for k in (-2, -1, 0, 1, 2):
        guard[(int(round(gx + nx * k)), int(round(gy + ny * k)))] = "steel_l" if k < 0 else "steel"
    for k in (-1, 0, 1):
        guard[(int(round(gx + dx + nx * k)), int(round(gy + dy + ny * k)))] = "steel" if k < 1 else "steel_d"
    f.pix(guard, SILVER)
    f.pix(blade(gx + dx * 2, gy + dy * 2, a, int(reach), 2, light="white", mid="steel_l", dark="steel"), SILVER)


def lancelot_head(f: Fig, hx: float, hy: float, eyes: str = "open", mouth: str = "smirk", plume: float = 0.0,
                  ear_dy: int = 0) -> None:
    skull = union(ellipse(hx, hy, 6.8, 5.6), ellipse(hx - 0.5, hy - 1.0, 6.2, 5.0))
    f.add(skull, SHIBA, centre=(hx - 1.0, hy - 1.5), radius=(7.5, 6.5), bias=0.08)
    # cream cheeks and muzzle (urajiro)
    muzzle = union(ellipse(hx + 5.0, hy + 2.2, 3.6, 2.6), ellipse(hx + 2.0, hy + 3.2, 3.4, 2.0))
    f.add(muzzle, URA, centre=(hx + 4, hy + 1), radius=(4.5, 3.5), sep=False, bias=0.05)
    hxi, hyi = int(round(hx)), int(round(hy))
    f.dots([(hxi + 2, hyi - 2), (hxi + 3, hyi - 2)], "cream")       # the shiba's little eyebrow dots
    nx, ny = hxi + 8, hyi + 1
    f.dots([(nx - 1, ny), (nx, ny), (nx - 1, ny + 1), (nx, ny + 1)], "umber")
    f.dot(nx - 1, ny, "slate")
    ex2, ey2 = hxi + 3, hyi
    if eyes == "open":
        f.dots([(ex2, ey2), (ex2 + 1, ey2), (ex2, ey2 + 1), (ex2 + 1, ey2 + 1)], "umber")
        f.dot(ex2, ey2, "white")
        f.dots([(ex2 - 1, ey2 - 1), (ex2 + 2, ey2 - 1)], "brown_d")
    elif eyes == "focus":
        f.dots([(ex2, ey2), (ex2 + 1, ey2), (ex2, ey2 + 1), (ex2 + 1, ey2 + 1)], "umber")
        f.dot(ex2 + 1, ey2, "white")
        f.dots([(ex2 - 1, ey2 - 2), (ex2, ey2 - 1), (ex2 + 1, ey2 - 1), (ex2 + 2, ey2 - 1)], "brown_d")
    elif eyes == "squint":
        f.dots([(ex2 - 1, ey2 - 1), (ex2, ey2), (ex2 + 1, ey2), (ex2, ey2 + 1), (ex2 - 1, ey2 + 2)], "umber")
    elif eyes == "happy":
        f.dots([(ex2 - 1, ey2 + 1), (ex2, ey2), (ex2 + 1, ey2), (ex2 + 2, ey2 + 1)], "umber")
    f.dots([(ex2 + 1, ey2 + 3), (ex2 + 2, ey2 + 3)], "pink")
    mx, my = hxi + 6, hyi + 4
    if mouth == "smirk":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my - 1)], "brown_d")
    elif mouth == "open":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my), (mx, my + 1)], "wine")
        f.dot(mx - 1, my + 1, "pink")
    elif mouth == "o":
        f.dots([(mx, my), (mx, my + 1)], "wine")
    # helmet: a silver dome over the crown with a brim and the blue plume
    helm = {(x, y) for (x, y) in union(ellipse(hx - 0.5, hy - 2.5, 6.6, 4.4), rect(int(hx - 7), int(hy - 3), 13, 2))
            if y <= hy - 1}
    f.add(helm, SILVER, centre=(hx - 3, hy - 5), radius=(7.5, 5), bias=0.04)
    f.recolor({(x, int(hy - 1)) for x in range(int(hx - 7), int(hx + 7))} & helm, "steel_d")
    px, py = hx - 3.5, hy - 6.5
    pl = union(capsule(px + 2, py + 0.5, px - 2, py - 2.5 - plume * 0.5, 1.7),
               capsule(px - 2, py - 2.5 - plume * 0.5, px - 6, py - 0.5 - plume, 1.5),
               capsule(px - 6, py - 0.5 - plume, px - 8, py + 2.5 - plume * 0.5, 1.1))
    f.add(pl, PLUME_B, centre=(px - 3, py - 3), radius=(6, 3), bias=0.12)
    # the near ear pokes up through a slot in the helmet, pointed and upright
    ex, ey = hx + 1.5, hy - 5.0 + ear_dy
    f.add(poly([(ex - 2.0, ey + 1.5), (ex - 0.2, ey - 4.2), (ex + 1.8, ey + 1.5)]), SHIBA, bias=0.12)
    f.recolor({(int(round(ex - 0.2)), int(round(ey - 1))), (int(round(ex - 0.2)), int(round(ey)))}, "cream")


def lancelot_frame(bob: int = 0, lean: float = 0.0, eyes: str = "open", mouth: str = "smirk",
                   legs=((0, 0.0), (0, 0.0)), hand=None, lance_deg: float = 28.0, reach: float = 11.0,
                   back: float = 6.0, pennant: int = 0, tail_up: int = 0, head_dy: int = 0, plume: float = 0.0,
                   ear_dy: int = 0, extra=None) -> Fig:
    f = Fig(32, 32, seed=91)
    bx, by = 12.5 + lean, 22.0 + bob
    hx, hy = 13.0 + lean * 1.3, 11.5 + bob + head_dy
    # curled tail: a ring on the back, cream underneath
    tx, ty = bx - 6.0, by - 4.5 - tail_up
    ring = ellipse(tx, ty, 3.0, 2.6)
    f.add(ring, SHIBA, centre=(tx - 1, ty - 1), radius=(3.5, 3), bias=0.1)
    f.recolor({(int(tx), int(ty)), (int(tx) + 1, int(ty))}, "brown")
    f.recolor({(x, y) for (x, y) in ring if y >= ty + 1.5}, "cream")
    # legs
    (fl, fdx), (nl, ndx) = legs
    for (x, lift, dx, far) in ((bx - 2.5, fl, fdx, True), (bx + 2.0, nl, ndx, False)):
        foot_y = GROUND - lift
        sh = union(rect(int(round(x + dx * 0.5)) - 1, int(by + 2), 3, int(foot_y - by - 3)),
                   capsule(x, by + 2, x + dx, foot_y - 1.5, 1.4))
        f.add(sh, SHIBA, mode="cyl_v", bias=-0.18 if far else -0.02)
        px_ = int(round(x + dx))
        f.add(rect(px_ - 1, foot_y - 1, 4, 2), URA if not far else SHIBA, flat=1)
    # body: silver breastplate over a blue tabard, cream chest fur at the neck
    torso = union(ellipse(bx, by - 0.5, 5.6, 4.4), rect(int(bx - 5), int(by), 11, 3))
    f.add(torso, SILVER, centre=(bx - 1.5, by - 2.5), radius=(6.0, 5.0), bias=0.0)
    f.recolor({(x, y) for (x, y) in torso if y >= int(by + 1)}, "water")
    f.recolor({(x, y) for (x, y) in torso if y == int(by + 2)}, "water_d")
    f.recolor({(x, int(by)) for x in range(int(bx - 5), int(bx + 6))} & torso, "night")
    f.dots([(int(bx + 1), int(by)), (int(bx + 2), int(by))], "yellow")
    f.add(ellipse(bx + 1.5, by - 4.4, 3.8, 1.8), URA, centre=(bx, by - 5), radius=(4, 2), sep=True, bias=0.05)
    lancelot_head(f, hx, hy, eyes, mouth, plume, ear_dy)
    if hand is None:
        hand = (bx + 6.0, by - 0.5)
    lance(f, hand[0], hand[1], lance_deg, reach, back, pennant)
    # arm and silver pauldron
    f.add(union(capsule(bx + 2.5, by - 2.5, hand[0], hand[1], 1.5), ellipse(hand[0], hand[1], 1.7, 1.6)), SHIBA,
          bias=0.1)
    f.add(ellipse(bx + 2.0, by - 3.0, 2.6, 2.0), SILVER, bias=0.12)
    if extra:
        extra(f)
    return f


def lancelot() -> list[Anim]:
    L = lancelot_frame
    up = dict(hand=(22.5, 21.0), lance_deg=86, reach=9, back=7)
    idle = [L(**up), L(bob=1, plume=0.6, pennant=1, **up),
            L(bob=1, plume=1.0, eyes="happy", pennant=1, tail_up=1, **up), L(plume=0.4, **up)]
    run_legs = [((0, -2.5), (0, 2.5)), ((1, -1.0), (0, 1.0)), ((3, 0.5), (0, -1.5)),
                ((0, 2.5), (0, -2.5)), ((0, 1.0), (1, -1.0)), ((0, -1.5), (3, 0.5))]
    run_bob = [0, 1, -1, 0, 1, -1]
    run = [L(bob=run_bob[i], lean=0.5, legs=run_legs[i], plume=1.5, lance_deg=18, pennant=i % 2,
             hand=(19.5, 21.5 + run_bob[i]), ear_dy=-1 if run_bob[i] < 0 else 0,
             mouth="open" if i % 3 == 0 else "smirk") for i in range(6)]
    attack = [L(lean=-1.5, eyes="focus", hand=(15.5, 20.5), lance_deg=6, reach=10, back=5),
              L(lean=2.0, eyes="focus", mouth="open", hand=(21.5, 20.0), lance_deg=2, reach=8, back=7,
                legs=((0, -2.0), (0, 2.5)), plume=2.0, extra=lambda f: _thrust_lines(f, 0)),
              L(lean=1.5, eyes="focus", hand=(20.5, 20.5), lance_deg=4, reach=8, back=7, plume=1.5),
              L(lean=0.5, hand=(18.5, 21.0), lance_deg=20)]
    hurt = [L(lean=-1.5, head_dy=1, eyes="squint", mouth="o", ear_dy=-1, lance_deg=60, reach=8,
              extra=lambda f: stars(f, [(7, 3), (17, 2)])),
            L(lean=-1.0, eyes="squint", mouth="o", lance_deg=50, reach=8)]
    dash = [L(lean=2.5, bob=-1, eyes="focus", mouth="open", hand=(21.5, 19.5), lance_deg=0, reach=8, back=8,
              legs=((0, -3.5), (1, 3.0)), plume=2.5, pennant=1, extra=lambda f: _thrust_lines(f, 0)),
            L(lean=2.5, bob=0, eyes="focus", mouth="open", hand=(21.5, 20.0), lance_deg=0, reach=8, back=8,
              legs=((1, -2.5), (0, 3.5)), plume=3.0, pennant=0, extra=lambda f: _thrust_lines(f, 1))]
    r = lambda fs: [x.render() for x in fs]  # noqa: E731
    return [anim("idle", r(idle), 6.0, True), anim("run", r(run), 14.0, True),
            anim("attack", r(attack), 16.0, False, [0.8, 1.0, 1.2, 1.0]),
            anim("hurt", r(hurt), 6.0, False, [1.0, 3.0]), anim("dash", r(dash), 12.0, True)]


def _thrust_lines(f: Fig, k: int) -> None:
    for (x, y, n) in ((1 + k, 14, 4), (0 + k, 19, 5), (2 + k, 24, 3)):
        for i in range(n):
            f.glow(x + i, y, alpha_px("white", 90 + i * 30))


# ---------------------------------------------------------------------------
# lady_lake 湖中仙女 (32): white samoyed in a flowing light-blue water dress, droplets floating around
# ---------------------------------------------------------------------------

SAMOYED = Mat(["ash", "fog", "white", "white"], outline="slate", lit="ash", fur=0.16, sep="ash", sep_lit="fog")
DRESS = Mat(["water", "sky", "azure", "sky_l"], outline="water_d", lit="water", sep="water", sep_lit="sky")
DRESS_IN = Mat(["water_d", "water", "sky"], outline="night", lit="water_d")
EAR_IN = Mat(["rose", "pink", "peach"], outline="slate")


def droplet(f: Fig, x: int, y: int, big: bool = True) -> None:
    """A floating water droplet: pointed top, white glint, soft blue glow."""
    if big:
        f.dots([(x, y - 1)], "sky")
        f.dots([(x - 1, y), (x, y), (x + 1, y), (x - 1, y + 1), (x, y + 1), (x + 1, y + 1)], "sky")
        f.dots([(x, y + 1), (x + 1, y + 1), (x + 1, y)], "water")
        f.dot(x - 1, y, "white")
        for (gx, gy) in ((x, y - 2), (x - 2, y), (x + 2, y), (x - 1, y + 2), (x + 1, y + 2), (x, y + 2)):
            f.glow(gx, gy, alpha_px("sky_l", 90))
    else:
        f.dots([(x, y), (x, y + 1)], "sky")
        f.dot(x, y, "white")
        f.glow(x, y - 1, alpha_px("sky_l", 80))


def lady_frame(bob: int = 0, lean: float = 0.0, wave: float = 0.0, trail: float = 0.0, eyes: str = "smile",
               arms: str = "hold", drops: float = 0.0, ear_dy: int = 0, ring: int = 0) -> Fig:
    f = Fig(32, 32, seed=101)
    cx, by = 14.0 + lean, 19.0 + bob
    # long fluffy tail peeking out behind the dress
    f.add(union(ellipse(cx - 6.5 - trail, by + 1, 2.6, 3.4), ellipse(cx - 7.5 - trail, by - 1.5, 2.0, 2.0)), SAMOYED,
          bias=0.1)
    # dress: a long bell that flows to the ground, the hem rippling like water
    hem = GROUND + 0.6
    pts = [(cx - 3.5, by - 3), (cx + 3.5, by - 3), (cx + 6.5, hem - 3), (cx + 7.5 - trail * 0.3, hem)]
    for i in range(8):
        x = cx + 7.5 - trail * 0.3 - i * (15.5 + trail) / 7
        y = hem - (1.2 if (i + int(wave * 2)) % 2 else 0)
        pts.append((x, y))
    pts += [(cx - 8.5 - trail, hem - 2), (cx - 5.5 - trail * 0.6, by + 3)]
    dress = poly(pts)
    f.add(dress, DRESS, centre=(cx - 2, by - 1), radius=(9, 11), bias=0.04, contrast=0.85)
    # water ripples: lighter wave lines across the skirt
    for k, yy in enumerate((by + 5, hem - 1)):
        f.recolor({(x, int(yy) + (1 if (x + k * 2 + int(wave * 2)) % 6 < 3 else 0)) for x in range(32)
                   if (x + k + int(wave * 2)) % 6 != 5} & dress, "sky_l" if k == 0 else "white")
    f.recolor({(x, y) for (x, y) in dress if x < cx - 4 - trail * 0.5 and y > by + 2}, "water")
    # bodice and a white fur ruff at the neck
    f.add(ellipse(cx + 0.5, by - 3.0, 4.2, 3.0), DRESS, bias=0.08)
    f.add(ellipse(cx + 1.0, by - 5.2, 4.0, 2.0), SAMOYED, bias=0.1)
    # arms (fluffy white sleeves)
    if arms == "up":
        hands = [(cx + 9.5, by - 8.5), (cx - 6.5, by - 8.5)]
    elif arms == "open":
        hands = [(cx + 7.0, by - 4.0), (cx - 5.0, by - 4.0)]
    else:
        hands = [(cx + 3.5, by - 1.0)]
    for (hx_, hy_) in hands[1:]:
        f.add(union(capsule(cx - 1.5, by - 4.0, hx_, hy_, 1.4), ellipse(hx_, hy_, 1.6, 1.5)), SAMOYED, bias=-0.1)
    # head: round, very fluffy, upright triangle ears, the samoyed smile
    hx, hy = cx + 1.5, by - 11.0
    for (ex, ey, back) in ((hx - 3.5, hy - 3.5 + ear_dy, True), (hx + 0.5, hy - 4.5 + ear_dy, False)):
        ear = poly([(ex - 2.0, ey + 2), (ex - 0.2, ey - 3.0), (ex + 2.0, ey + 2)])
        f.add(ear, SAMOYED, bias=-0.1 if back else 0.12)
        if not back:
            f.recolor({(int(round(ex - 0.2)), int(round(ey))), (int(round(ex - 0.2)), int(round(ey + 1)))}, "pink")
    head = union(ellipse(hx, hy, 6.0, 5.2), ellipse(hx - 0.5, hy + 1.5, 6.4, 4.4))
    f.add(head, SAMOYED, centre=(hx - 1.5, hy - 1.5), radius=(7, 6), bias=0.12)
    f.add(ellipse(hx + 4.5, hy + 1.6, 2.8, 2.0), SAMOYED, sep=True, bias=0.1)
    hxi, hyi = int(round(hx)), int(round(hy))
    f.dots([(hxi + 7, hyi + 1), (hxi + 6, hyi + 1), (hxi + 7, hyi + 2)], "ink")
    ex, ey = hxi + 2, hyi - 0
    if eyes == "smile":
        f.dots([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey + 1)], "ink")
    elif eyes == "open":
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], "ink")
        f.dot(ex, ey, "white")
    f.dots([(ex + 1, ey + 3), (ex + 2, ey + 3)], "pink")
    f.dots([(hxi + 4, hyi + 3), (hxi + 5, hyi + 4), (hxi + 6, hyi + 3)], "slate")
    # a little tiara of pearls and a water-lily flower behind the ear
    f.dots([(hxi - 2, hyi - 5), (hxi, hyi - 6), (hxi + 2, hyi - 5)], "sky_l")
    f.dot(hxi, hyi - 6, "white")
    f.dots([(hxi - 5, hyi - 2), (hxi - 4, hyi - 3), (hxi - 3, hyi - 2), (hxi - 4, hyi - 1)], "pink")
    f.dot(hxi - 4, hyi - 2, "yellow")
    # near arm
    hx_, hy_ = hands[0]
    f.add(union(capsule(cx + 2.0, by - 4.0, hx_, hy_, 1.5), ellipse(hx_, hy_, 1.7, 1.6)), SAMOYED, bias=0.1)
    # droplets circling around her
    for i in range(3):
        a = drops * 2 * math.pi + i * 2 * math.pi / 3
        r = 11.0 if ring == 0 else 11.0 - ring * 2.0
        x = int(round(cx + 1 + math.cos(a) * r))
        y = int(round(by - 4 + math.sin(a) * r * 0.55 - (ring * 2 if ring else 0)))
        droplet(f, x, y, big=(i != 2))
    if ring >= 2:
        # a ball of lake water gathering above her raised paw
        ox, oy, rr = cx + 10.0, by - 13.0, 1.6 + ring * 0.6
        orb = ellipse(ox, oy, rr, rr)
        f.add(orb, DRESS, centre=(ox - 1, oy - 1), radius=(rr + 0.5, rr + 0.5), bias=0.12, sep=False)
        f.dots([(int(ox) - 1, int(oy) - 1)], "white")
        for k in range(8):
            a = k * math.pi / 4 + ring
            f.glow(int(round(ox + math.cos(a) * (rr + 1.6))), int(round(oy + math.sin(a) * (rr + 1.6))),
                   alpha_px("white" if k % 2 else "sky_l", 160))
    return f


def lady_lake() -> list[Anim]:
    D = lady_frame
    idle = [D(wave=0, drops=0.00), D(bob=1, wave=1, drops=0.08), D(bob=1, wave=2, drops=0.16, eyes="open"),
            D(wave=3, drops=0.24)]
    run = [D(bob=b, lean=0.5, trail=2.0, wave=i, drops=0.06 * i, ear_dy=-1 if b < 0 else 0)
           for i, b in enumerate((0, -1, -1, 0, -1, -1))]
    cast = [D(arms="open", eyes="open", drops=0.0, ring=1), D(bob=-1, arms="up", eyes="smile", drops=0.1, ring=2),
            D(bob=-1, arms="up", eyes="smile", drops=0.2, ring=3)]
    r = lambda fs: [x.render() for x in fs]  # noqa: E731
    return [anim("idle", r(idle), 5.0, True), anim("run", r(run), 10.0, True),
            anim("cast", r(cast), 8.0, False, [1.0, 1.5, 1.5])]


# ---------------------------------------------------------------------------
# green_knight 綠騎士 (64): a giant topiary knight with a round bush "leaf hat" and a vine whip
# ---------------------------------------------------------------------------

HEDGE = Mat(["forest_d", "forest", "leaf_d", "grass"], outline="deep", lit="forest_d", fur=0.32, sep="forest_d",
            sep_lit="forest")
HEDGE_FAR = Mat(["deep", "forest_d", "forest", "leaf_d"], outline="deep", lit="deep", fur=0.3, sep="deep",
                sep_lit="forest_d")
BUSH = Mat(["leaf_d", "grass", "leaf", "spring", "leaf_l"], outline="forest_d", lit="forest", fur=0.34,
           sep="leaf_d", sep_lit="grass")
BARK = Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber", lit="umber", fur=0.1)
VINE = Mat(["forest_d", "forest", "leaf_d", "leaf"], outline="deep", lit="forest_d")
THORN = Mat(["plum", "dusk", "violet", "lilac"], outline="ink", lit="plum")
FLOWERS = ((0, "pink"), (1, "white"), (2, "yellow"))


def vine(f: Fig, pts: list, width: float = 1.3, leaves: bool = True) -> None:
    """A vine whip along a polyline: a dark-green stem with small leaves on alternate sides."""
    shape = set()
    for i in range(len(pts) - 1):
        shape |= capsule(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], width * (1 - 0.35 * i / len(pts)))
    f.add(shape, VINE, bias=0.08, sep=True)
    if not leaves:
        return
    lv = {}
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        px, py = pts[i - 1]
        nx, ny = -(y - py), (x - px)
        ln = math.hypot(nx, ny) or 1
        s = 1 if i % 2 else -1
        lx, ly = x + nx / ln * 2.2 * s, y + ny / ln * 2.2 * s
        lv[(int(round(lx)), int(round(ly)))] = "leaf"
        lv[(int(round((x + lx) / 2)), int(round((y + ly) / 2)))] = "leaf_d"
        lv[(int(round(lx)) + (1 if s > 0 else -1), int(round(ly)))] = "leaf_l"
    f.pix(lv, VINE, sep=False)


def whip_path(hx: float, hy: float, mode: str, k: float = 0.0) -> list:
    """Vine poses from the hand: hang (coils to the ground), raise (looped overhead), sweep (long, flat to the
    right), lash (short forward crack), up (straight up for the summon)."""
    if mode == "hang":
        return [(hx, hy), (hx + 3, hy + 5), (hx + 2 + k, hy + 10), (hx + 5 + k, hy + 14), (hx + 9, hy + 15),
                (hx + 11 - k, hy + 13)]
    if mode == "raise":
        return [(hx, hy), (hx - 3, hy - 6), (hx - 10, hy - 10), (hx - 17, hy - 8), (hx - 21, hy - 2),
                (hx - 22, hy + 4)]
    if mode == "sweep":
        return [(hx, hy), (hx + 5, hy - 1), (hx + 10, hy - 2 + k), (hx + 15, hy - 1 - k), (hx + 19, hy + 1 + k)]
    if mode == "lash":
        return [(hx, hy), (hx + 4, hy - 3), (hx + 9, hy - 3), (hx + 13, hy), (hx + 15, hy + 3)]
    if mode == "up":
        return [(hx, hy), (hx + 1, hy - 6), (hx - 1, hy - 11), (hx + 1, hy - 15), (hx + 3, hy - 18)]
    return [(hx, hy)]


def leaf_hat(f: Fig, hx: float, hy: float, tilt: float = 0.0, thorn: bool = True) -> None:
    """The round bush hat: a big ball of leaves with little flowers and Morgana's purple thorn."""
    hat = union(ellipse(hx, hy, 12.5, 8.5), ellipse(hx - 5.0, hy + 2.5, 8.0, 5.5), ellipse(hx + 5.5, hy + 2.5, 7.5, 5.5))
    f.add(hat, BUSH, centre=(hx - 4, hy - 4), radius=(13, 10), bias=0.0)
    # leafy scallops on the rim
    for i in range(-5, 6):
        f.recolor({(int(hx + i * 2.4), int(hy + 7.5 - abs(i) * 0.4))} & hat, "leaf_d")
    for i, (dx, dy) in enumerate(((-7, -2), (2, -5), (8, 1), (-3, 3), (4, 3), (-1, -1))):
        col = FLOWERS[i % 3][1]
        x, y = int(hx + dx), int(hy + dy)
        f.recolor({(x, y), (x + 1, y), (x, y + 1)} & hat, col)
        f.recolor({(x + 1, y + 1)} & hat, "yellow" if col != "yellow" else "amber")
    if thorn:
        a = math.radians(42 + tilt)
        bx, by = hx + 4.5, hy - 4.5
        tx, ty = bx + math.cos(a) * 10, by - math.sin(a) * 10
        f.add(poly([(bx - 2.0, by + 1.8), (tx, ty), (bx + 2.0, by + 1.4)]), THORN, bias=0.12)
        glow(f, int(round(tx)), int(round(ty)), 2, "violet", 120, 35)


def gk_frame(bob: int = 0, lean: float = 0.0, legs=((0, 0.0), (0, 0.0)), hand=(46.0, 38.0), whip: str = "hang",
             whip_k: float = 0.0, back_hand=None, face: str = "grin", hat: str = "on", hat_at=None,
             hat_tilt: float = 0.0, head_dy: int = 0, extra=None, sit: bool = False) -> Fig:
    f = Fig(64, 64, seed=111)
    ground = GROUND64
    cx = 28.0 + lean
    by = 41.0 + bob
    # back arm (a round bush shoulder with a hedge arm)
    bhx, bhy = back_hand if back_hand else (cx - 13, by + 4)
    f.add(union(capsule(cx - 9, by - 7, bhx, bhy, 3.6), ellipse(bhx, bhy, 3.6, 3.4)), HEDGE_FAR, bias=-0.05)
    f.add(ellipse(cx - 10, by - 9, 6.0, 5.4), HEDGE_FAR, bias=0.0)
    # legs: hedge pillars with wooden boots
    (fl, fdx), (nl, ndx) = legs
    for (x, lift, dx, far) in ((cx - 6, fl, fdx, True), (cx + 5, nl, ndx, False)):
        foot = ground - lift
        if sit:
            continue
        leg = union(rect(int(round(x + dx * 0.5)) - 4, int(by + 8), 8, int(foot - by - 11)),
                    capsule(x, by + 8, x + dx, foot - 5, 4.0))
        f.add(leg, HEDGE_FAR if far else HEDGE, mode="cyl_v", centre=(x + dx, foot), radius=(4.5, 8),
              bias=-0.08 if far else 0.0)
        boot = union(rect(int(round(x + dx)) - 4, foot - 4, 9, 5), ellipse(x + dx + 4.5, foot - 1.0, 2.6, 2.0))
        f.add(boot, BARK, centre=(x + dx, foot - 4), radius=(6, 4), bias=-0.05 if far else 0.05)
        f.recolor({(xx, foot - 4) for xx in range(int(x + dx) - 4, int(x + dx) + 6)} & boot, "gold_d")
    if sit:
        # sitting: legs folded forward on the ground
        f.add(union(ellipse(cx + 8, ground - 4, 9.0, 4.0), ellipse(cx - 2, ground - 4, 8.0, 4.4)), HEDGE, bias=0.05)
        f.add(union(rect(int(cx + 13), ground - 6, 7, 6), ellipse(cx + 20, ground - 3, 2.6, 2.6)), BARK, bias=0.05)
    # torso: a big trimmed hedge chest with a bark belt
    chest = union(ellipse(cx, by - 4, 12.5, 11.0), rect(int(cx - 11), int(by - 2), 23, 10))
    f.add(chest, HEDGE, centre=(cx - 4, by - 9), radius=(14, 13), bias=0.04)
    belt = {(x, y) for (x, y) in chest if int(by + 3) <= y <= int(by + 5)}
    f.recolor(belt, "brown")
    f.recolor({(x, y) for (x, y) in belt if y == int(by + 5)}, "brown_d")
    f.recolor({(x, int(by + 3)) for x in range(64)} & belt, "gold_d")
    bk = int(cx + 2)
    f.recolor({(bk, int(by + 3)), (bk + 1, int(by + 3)), (bk, int(by + 4)), (bk + 1, int(by + 4)), (bk + 2, int(by + 3)),
               (bk + 2, int(by + 4))}, "yellow")
    f.recolor({(bk + 1, int(by + 4))}, "gold")
    # a trimmed cross pattern on the chest (lighter clipped leaves)
    sx, sy = int(cx + 1), int(by - 7)
    f.recolor({(sx, y) for y in range(sy - 4, sy + 5)} | {(x, sy - 1) for x in range(sx - 3, sx + 4)}, "spring")
    f.recolor({(sx + 1, y) for y in range(sy - 3, sy + 5)} | {(x, sy) for x in range(sx - 2, sx + 4)}, "leaf_d")
    # head: a rounded hedge helm with a carved face (shadowed eyes that glow, a big grin)
    hx, hy = cx + 3.0, by - 20.0 + head_dy
    head = union(ellipse(hx, hy, 8.8, 7.8), rect(int(hx - 7), int(hy), 16, 7))
    f.add(head, HEDGE, centre=(hx - 3, hy - 3), radius=(9, 9), bias=0.08)
    hxi, hyi = int(round(hx)), int(round(hy))
    # face plate: a cut-in hollow in the hedge
    facep = {(x, y) for (x, y) in ellipse(hx + 4.0, hy + 1.5, 5.4, 4.6) if (x, y) in head}
    f.recolor(facep, "forest_d")
    f.recolor({(x, y) for (x, y) in facep if (x, y - 1) not in facep}, "deep")
    ex, ey = hxi + 2, hyi + 1
    if face in ("grin", "laugh", "focus"):
        for x0 in (ex, ex + 4):
            f.dots([(x0, ey - 1), (x0 + 1, ey - 1), (x0, ey), (x0 + 1, ey)], "leaf_l")
            f.dot(x0, ey - 1, "yellow")
            if face == "focus":
                f.dot(x0 + (1 if x0 == ex else 0), ey - 1, "forest_d")
        for (gx, gy) in ((ex - 1, ey), (ex + 6, ey)):
            f.glow(gx, gy, alpha_px("leaf_l", 100))
    elif face in ("surprised", "dizzy"):
        for x0 in (ex, ex + 4):
            f.dots([(x0, ey - 1), (x0 + 1, ey - 1), (x0, ey), (x0 + 1, ey)], "leaf_l")
            f.dot(x0, ey - 1, "white")
    elif face == "cheeky":
        f.dots([(ex - 1, ey), (ex, ey - 1), (ex + 1, ey - 1), (ex + 2, ey)], "leaf_l")
        f.dots([(ex + 4, ey - 1), (ex + 5, ey - 1), (ex + 4, ey), (ex + 5, ey)], "leaf_l")
        f.dot(ex + 4, ey - 1, "yellow")
        f.glow(ex + 6, ey, alpha_px("leaf_l", 100))
    elif face in ("happy", "squint"):
        for x0 in (ex, ex + 4):
            f.dots([(x0 - 1, ey), (x0, ey - 1), (x0 + 1, ey - 1), (x0 + 2, ey)], "yellow" if face == "happy"
                   else "leaf_l")
    if face in ("grin", "laugh", "happy"):
        f.dots([(ex, ey + 3), (ex + 1, ey + 4), (ex + 2, ey + 4), (ex + 3, ey + 4), (ex + 4, ey + 4), (ex + 5, ey + 3)],
               "leaf_l")
        if face == "laugh":
            f.dots([(ex + 1, ey + 3), (ex + 2, ey + 3), (ex + 3, ey + 3), (ex + 4, ey + 3)], "deep")
            f.dots([(ex + 2, ey + 3), (ex + 3, ey + 3)], "wine")
    elif face in ("surprised",):
        f.dots([(ex + 2, ey + 3), (ex + 3, ey + 3), (ex + 2, ey + 4), (ex + 3, ey + 4)], "deep")
        f.dots([(ex + 1, ey + 3), (ex + 4, ey + 3), (ex + 1, ey + 4), (ex + 4, ey + 4)], "leaf_l")
    elif face == "focus":
        f.dots([(ex + 1, ey + 3), (ex + 2, ey + 3), (ex + 3, ey + 3), (ex + 4, ey + 3)], "leaf_l")
    elif face == "cheeky":
        f.dots([(ex, ey + 3), (ex + 1, ey + 4), (ex + 2, ey + 4), (ex + 3, ey + 4), (ex + 4, ey + 3), (ex + 5, ey + 2)],
               "leaf_l")
        f.dots([(ex + 2, ey + 5), (ex + 3, ey + 5)], "pink")
    elif face == "squint":
        f.dots([(ex + 1, ey + 4), (ex + 2, ey + 3), (ex + 3, ey + 4), (ex + 4, ey + 3)], "leaf_l")
    # hat (or a little sprout once the hat is off)
    if hat == "on":
        leaf_hat(f, hx - 0.5, hy - 9.5, hat_tilt)
    elif hat == "off":
        # the bare hedge head: a small leaf sprout on top that sways as he moves
        sw = 1 if hat_tilt > 3 else (-1 if hat_tilt < -3 else 0)
        sx0, sy0 = hxi - 1, hyi - 8
        sp = {(sx0, sy0): "leaf_d", (sx0, sy0 - 1): "leaf_d", (sx0 + sw, sy0 - 2): "leaf",
              (sx0 + sw - 1, sy0 - 3): "leaf", (sx0 + sw - 2, sy0 - 3): "leaf_l", (sx0 + sw - 2, sy0 - 4): "leaf_l",
              (sx0 + sw + 1, sy0 - 3): "leaf", (sx0 + sw + 2, sy0 - 3): "spring", (sx0 + sw + 2, sy0 - 4): "leaf_l"}
        f.pix(sp, VINE)
    if hat_at is not None:
        leaf_hat(f, hat_at[0], hat_at[1], hat_tilt, thorn=hat_at[2] if len(hat_at) > 2 else True)
    # front shoulder (round bush pauldron) and arm with the vine whip
    f.add(ellipse(cx + 9, by - 8, 6.4, 5.6), HEDGE, centre=(cx + 7, by - 10), radius=(7, 6), bias=0.1)
    hx2, hy2 = hand
    if whip:
        vine(f, whip_path(hx2, hy2, whip, whip_k))
    f.add(union(capsule(cx + 10, by - 5, hx2, hy2, 3.4), ellipse(hx2, hy2, 3.4, 3.2)), HEDGE,
          centre=(hx2 - 2, hy2 - 2), radius=(4, 4), bias=0.1)
    if extra:
        extra(f)
    return f


def _leaf_bits(f: Fig, pts) -> None:
    for i, (x, y) in enumerate(pts):
        col = ("leaf", "spring", "leaf_d")[i % 3]
        f.glow(x, y, col)
        f.glow(x + 1, y + (1 if i % 2 else -1), col)
        f.glow(x + 1, y, "leaf_l" if i % 2 else col)


BARE_FACES = {"grin": "cheeky", "focus": "focus", "laugh": "laugh", "happy": "cheeky", "squint": "squint"}


def green_knight() -> list[Anim]:
    out = _gk_anims(False)
    bare = _gk_anims(True)
    # phase 2 (after hat_off): the same moves with the bare hedge head and its little sprout (`<anim>_bare`)
    for a in bare:
        if a.name in ("idle", "run", "attack", "hurt", "whip", "summon"):
            out.append(Anim(a.name + "_bare", a.frames, a.fps, a.loop, list(a.durations)))
    return out


def _gk_anims(bare: bool) -> list[Anim]:
    def G(**kw) -> Fig:
        if bare:
            kw["hat"] = "off"
            kw["face"] = BARE_FACES.get(kw.get("face", "grin"), kw.get("face", "grin"))
        return gk_frame(**kw)
    idle = [G(), G(bob=1, whip_k=0.5, hat_tilt=4), G(bob=1, whip_k=1.0, hat_tilt=6, face="happy"),
            G(whip_k=0.5, hat_tilt=2)]
    run_legs = [((0, -4.0), (0, 4.0)), ((3, -2.0), (0, 2.0)), ((5, 1.0), (0, -1.0)),
                ((0, 4.0), (0, -4.0)), ((0, 2.0), (3, -2.0)), ((0, -1.0), (5, 1.0))]
    run_bob = [0, 1, -1, 0, 1, -1]
    run = [G(bob=run_bob[i], lean=1, legs=run_legs[i], hand=(46, 38 + run_bob[i]), whip_k=i % 2,
             hat_tilt=-6 if run_bob[i] < 0 else 4) for i in range(6)]
    attack = [G(lean=-2, hand=(40, 30), whip="raise", face="focus", hat_tilt=8),
              G(lean=2, hand=(48, 34), whip="lash", face="grin", hat_tilt=-4,
                extra=lambda f: _whip_crack(f, 63, 37)),
              G(lean=1, hand=(47, 36), whip="lash", whip_k=1, face="grin"),
              G(lean=0, hand=(46, 38), whip="hang")]
    hurt = [G(lean=-3, head_dy=1, face="squint", hat_tilt=12,
              extra=lambda f: (stars(f, [(18, 8), (44, 5)]), _leaf_bits(f, [(12, 20), (50, 16), (8, 30)]))),
            G(lean=-2, face="squint", hat_tilt=8)]
    whip = [G(lean=-3, bob=-1, hand=(38, 26), whip="raise", face="focus", hat_tilt=10),
            G(lean=1, hand=(44, 33), whip="sweep", whip_k=-1, face="grin", hat_tilt=0,
              extra=lambda f: _sweep_smear(f, 34, 34, True)),
            G(lean=2, hand=(46, 36), whip="sweep", whip_k=1, face="laugh", hat_tilt=-6,
              extra=lambda f: _sweep_smear(f, 34, 37, False)),
            G(lean=1, hand=(46, 38), whip="hang", whip_k=1, face="grin")]
    summon = [G(bob=-1, hand=(44, 22), whip="up", face="focus",
                extra=lambda f: _summon_sparks(f, 0)),
              G(bob=-2, hand=(44, 20), whip="up", face="laugh", hat_tilt=6, extra=lambda f: _summon_sparks(f, 1)),
              G(bob=-1, hand=(44, 22), whip="up", face="grin", extra=lambda f: _summon_sparks(f, 2))]
    hat_off = [G(lean=-1, face="surprised", hat="none", hat_at=(30, 7, True), hat_tilt=10, head_dy=1,
                 extra=lambda f: _leaf_bits(f, [(18, 10), (42, 8)])),
               G(lean=-1, face="surprised", hat="off", hat_at=(14, 4, True), hat_tilt=40,
                 extra=lambda f: _leaf_bits(f, [(26, 3), (34, 6), (10, 14)])),
               G(face="squint", hat="off", hat_at=(9, 51, False), hat_tilt=0,
                 extra=lambda f: _thorn_pop(f, 9, 38)),
               G(face="laugh", hat="off", hat_at=(9, 52, False), extra=lambda f: _thorn_pop(f, 9, 32, fade=True))]
    r = lambda fs: [x.render() for x in fs]  # noqa: E731
    if bare:
        return [anim("idle", r(idle), 4.0, True), anim("run", r(run), 10.0, True),
                anim("attack", r(attack), 12.0, False, [1.2, 0.8, 1.0, 1.0]),
                anim("hurt", r(hurt), 6.0, False, [1.0, 3.0]),
                anim("whip", r(whip), 12.0, False, [1.5, 0.8, 1.0, 1.0]),
                anim("summon", r(summon), 8.0, False)]
    down = [gk_down(0), gk_down(1)]
    return [anim("idle", r(idle), 4.0, True), anim("run", r(run), 10.0, True),
            anim("attack", r(attack), 12.0, False, [1.2, 0.8, 1.0, 1.0]),
            anim("hurt", r(hurt), 6.0, False, [1.0, 3.0]),
            anim("whip", r(whip), 12.0, False, [1.5, 0.8, 1.0, 1.0]),
            anim("summon", r(summon), 8.0, False),
            anim("hat_off", r(hat_off), 8.0, False, [1.0, 1.0, 1.5, 1.5]),
            anim("down", down, 3.0, False)]


def _whip_crack(f: Fig, x: int, y: int) -> None:
    for (dx, dy) in ((0, 0), (-1, -2), (-1, 2), (-3, -3), (-3, 3)):
        f.glow(x + dx, y + dy, alpha_px("white", 200))


def _sweep_smear(f: Fig, cx: float, cy: float, strong: bool) -> None:
    for y in range(64):
        for x in range(64):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.8)
            ang = math.degrees(math.atan2(-(y + 0.5 - cy), x + 0.5 - cx))
            if 22 <= d <= 30 and -35 <= ang <= 40:
                edge = d > 28.5
                f.glow(x, y, alpha_px("leaf_l" if edge else "spring", (170 if edge else 80) if strong else
                                      (110 if edge else 50)))


def _summon_sparks(f: Fig, k: int) -> None:
    for i in range(6):
        a = i * math.pi / 3 + k * 0.5
        r = 10 + k * 3
        x, y = int(round(46 + math.cos(a) * r)), int(round(10 + math.sin(a) * r * 0.5))
        sparkle(f, x, y, "white" if i % 2 else "leaf_l", "leaf", 1)
    _leaf_bits(f, [(int(30 + k * 4), int(12 - k)), (int(56 - k * 2), int(20 + k))])


def _thorn_pop(f: Fig, x: int, y: int, fade: bool = False) -> None:
    """Morgana's purple thorn pops out of the fallen hat in a puff of sparkles (the spell breaks)."""
    if not fade:
        f.pix({(x, y): "lilac", (x, y + 1): "violet", (x, y + 2): "violet", (x, y + 3): "plum", (x + 1, y + 2): "dusk"},
              THORN)
    for (dx, dy) in ((-4, -2), (4, -1), (-2, 3), (3, 4)):
        sparkle(f, x + dx, y + dy, "white", "lilac" if not fade else "violet", 1)


def gk_down(k: int) -> Canvas:
    """Sits down on the grass, laughing and tired (never hurt); the hat rests beside him."""
    f = gk_frame(bob=12, sit=True, face="laugh" if k else "happy", hat="off", hat_at=(52, 54, False),
                 hand=(44, 50), whip="hang", back_hand=(16, 52), legs=((0, 0), (0, 0)))
    if k:
        f.glow(48, 22, "white")
        sparkle(f, 47, 18, "white", "leaf_l", 1)
    return f.render()


# ---------------------------------------------------------------------------
# morgana 摩根娜 (64): elegant red-brown fox witch, purple cloak, crescent-moon staff
# ---------------------------------------------------------------------------

FOX = Mat(["umber", "brown", "gold_d", "amber"], outline="umber", lit="brown_d", fur=0.12, sep="brown_d",
          sep_lit="brown")
FOX_FAR = Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber", lit="umber", fur=0.1, sep="umber",
              sep_lit="brown_d")
FOX_W = Mat(["sand", "cream", "white"], outline="brown_d", lit="brown", fur=0.08, sep="dirt", sep_lit="sand")
CLOAK = Mat(["ink", "plum", "dusk", "violet"], outline="ink", lit="ink", sep="ink", sep_lit="plum")
CLOAK_IN = Mat(["night_d", "wine", "plum"], outline="ink", lit="ink")
GOWN = Mat(["plum", "wine", "dusk", "rose"], outline="ink", lit="plum", sep="plum", sep_lit="wine")
TRIM = Mat(["violet", "lilac", "white"], outline="plum", lit="violet")
STAFF = Mat(["ink", "plum", "dusk"], outline="ink", lit="ink")
MOON = Mat(["gold_d", "gold", "yellow", "cream"], outline="brown_d", lit="gold_d", spec="white", spec_at=0.8)


def moon_staff(f: Fig, x: float, top: float, bottom: float, glow_r: int = 2, tilt: float = 0.0) -> None:
    """A tall dark staff topped with a gold crescent moon cradling a glowing lilac orb."""
    a = math.radians(tilt)
    pts = {}
    n = int(bottom - top)
    for i in range(n + 1):
        px_ = int(round(x + math.sin(a) * (n - i)))
        py_ = int(round(top + i * math.cos(a)))
        pts[(px_, py_)] = "plum" if i % 6 else "violet"
    f.pix(pts, STAFF)
    mx, my = x + math.sin(a) * n, top - 4
    crescent = ellipse(mx, my, 5.0, 5.0) - ellipse(mx + 2.2, my - 1.4, 4.0, 4.0)
    f.add(crescent, MOON, centre=(mx - 2, my - 2), radius=(5, 5), bias=0.1)
    orb = ellipse(mx + 0.8, my - 0.2, 1.8, 1.8)
    f.pix({p: "lilac" for p in orb} | {(int(mx), int(my) - 1): "white"}, TRIM)
    if glow_r:
        glow(f, int(mx + 1), int(my), glow_r + 2, "lilac", 140, 120 // (glow_r + 2))


def morgana_head(f: Fig, hx: float, hy: float, eyes: str = "sly", mouth: str = "smile", ear_dy: int = 0) -> None:
    for (ex, ey, m) in ((hx - 5.0, hy - 5 + ear_dy, FOX_FAR), (hx - 0.5, hy - 6 + ear_dy, FOX)):
        ear = poly([(ex - 3.0, ey + 3), (ex - 0.8, ey - 8.0 - ear_dy * 0.5), (ex + 3.0, ey + 2.5)])
        f.add(ear, m, bias=0.12)
        if m is FOX:
            f.recolor({(int(round(ex - 0.6)), int(round(ey + y))) for y in (-3, -2, -1, 0, 1)}, "umber")
            f.recolor({(int(round(ex - 0.8)), int(round(ey - 7.0 - ear_dy * 0.5)) + y) for y in (0, 1)}, "umber")
    head = union(ellipse(hx, hy, 6.6, 5.6), poly([(hx + 2, hy - 2.4), (hx + 11.5, hy + 1.6), (hx + 11.5, hy + 2.8),
                                                  (hx + 2, hy + 5.0)]))
    f.add(head, FOX, centre=(hx - 1.5, hy - 2), radius=(7, 6), bias=0.08)
    # white cheeks and muzzle underside
    cheek = {(x, y) for (x, y) in union(ellipse(hx + 1.5, hy + 3.2, 4.0, 2.0), ellipse(hx + 6.5, hy + 3.0, 3.6, 1.2))
             if (x, y) in head}
    f.recolor(cheek, "cream")
    f.recolor({(x, y) for (x, y) in cheek if y >= hy + 4}, "sand")
    hxi, hyi = int(round(hx)), int(round(hy))
    f.dots([(hxi + 11, hyi + 1), (hxi + 12, hyi + 1), (hxi + 11, hyi + 2), (hxi + 12, hyi + 2)], "ink")
    f.dot(hxi + 11, hyi + 1, "slate")
    ex, ey = hxi + 3, hyi - 1
    if eyes == "sly":
        f.dots([(ex - 1, ey), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1), (ex - 1, ey + 1)], "umber")
        f.dots([(ex, ey + 1), (ex + 1, ey + 1)], "yellow")
        f.dot(ex + 3, ey, "umber")                   # eyelash flick
    elif eyes == "open":
        f.dots([(ex, ey - 1), (ex + 1, ey - 1), (ex - 1, ey), (ex + 2, ey), (ex - 1, ey + 1), (ex + 2, ey + 1)], "umber")
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], "yellow")
        f.dot(ex, ey, "white")
        f.dot(ex + 3, ey - 1, "umber")
    elif eyes == "angry":
        f.dots([(ex - 1, ey - 1), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1), (ex - 1, ey + 1)], "umber")
        f.dots([(ex, ey + 1), (ex + 1, ey + 1)], "amber")
    elif eyes == "squint":
        f.dots([(ex - 1, ey - 1), (ex, ey), (ex + 1, ey + 1), (ex, ey + 2), (ex - 1, ey + 3)], "umber")
    elif eyes == "sad":
        f.dots([(ex - 1, ey + 1), (ex, ey + 1), (ex + 1, ey + 1), (ex + 2, ey)], "umber")
        f.dots([(ex - 1, ey - 1), (ex, ey - 2)], "brown_d")
        f.dot(ex + 1, ey + 3, "sky_l")
        f.dot(ex + 1, ey + 4, "sky")
    mx, my = hxi + 6, hyi + 4
    if mouth == "smile":
        f.dots([(mx - 1, my), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my)], "brown_d")
    elif mouth == "open":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my), (mx, my + 1), (mx + 1, my + 1)], "wine")
    elif mouth == "frown":
        f.dots([(mx - 1, my + 1), (mx, my), (mx + 1, my), (mx + 2, my + 1)], "brown_d")
    f.dots([(ex + 2, ey + 3), (ex + 3, ey + 3)], "rose")
    # a lock of hair (head fur) swept over the brow, and a small violet jewel
    f.recolor({(hxi - 2, hyi - 5), (hxi - 1, hyi - 5), (hxi, hyi - 4), (hxi + 1, hyi - 4)}, "amber")
    f.pix({(hxi - 1, hyi - 3): "lilac", (hxi, hyi - 3): "violet"}, TRIM, sep=False)


def morgana_frame(bob: int = 0, lean: float = 0.0, sway: float = 0.0, hover: int = 0, eyes: str = "sly",
                  mouth: str = "smile", staff=None, staff_glow: int = 2, arm: str = "staff", ear_dy: int = 0,
                  head_dy: int = 0, tail: float = 0.0, cloak_lift: float = 0.0, extra=None) -> Fig:
    f = Fig(64, 64, seed=121)
    ground = GROUND64 - hover
    cx = 27.0 + lean
    by = 39.0 + bob - hover
    # big fluffy tail sweeping out and up behind the cloak, white tip
    ta = math.radians(190 - tail * 25)
    tb = (cx - 8, by + 12)
    tm = (tb[0] + math.cos(ta) * 7, tb[1] - math.sin(ta) * 7)
    tt = (tm[0] + math.cos(ta - 1.1) * 8, tm[1] - math.sin(ta - 1.1) * 8)
    tail_s = union(capsule(tb[0], tb[1], tm[0], tm[1], 4.4), capsule(tm[0], tm[1], tt[0], tt[1], 4.2),
                   ellipse(tt[0], tt[1], 4.2, 3.8))
    f.add(tail_s, FOX, centre=(tm[0], tm[1] - 3), radius=(8, 7), bias=0.05)
    f.recolor({(x, y) for (x, y) in ellipse(tt[0], tt[1], 3.8, 3.6) if (x, y) in tail_s}, "cream")
    f.recolor({(x, y) for (x, y) in ellipse(tt[0] - 0.5, tt[1] - 1.0, 2.0, 1.6) if (x, y) in tail_s}, "white")
    # cloak (back layer): long, sweeping to the ground, lining visible at the hem
    hem = ground - 1 - cloak_lift * 6
    back = cx - 13 - cloak_lift * 6 - sway
    cl = poly([(cx + 3, by - 14), (cx - 7, by - 14), (cx - 11 - cloak_lift * 2, by - 4), (back, hem - 3),
               (back - 1, hem), (back + 4, hem - 1.5), (back + 8, hem + 0.5), (cx + 2, hem), (cx + 6, by)])
    f.add(cl, CLOAK, centre=(cx - 6, by - 8), radius=(13, 16), bias=0.06, contrast=0.85)
    lining = {(x, y) for (x, y) in cl if y >= hem - 2.5 and x < back + 6}
    f.recolor(lining, "wine")
    for k, xb in enumerate((back + 4, back + 9)):
        fold = {p for p in capsule(cx - 5 - k * 2, by - 8, xb, hem - 2, 0.5) if p in cl}
        f.shade_toward(fold, CLOAK, -1)
    # gown: a long elegant dress (red-violet) to the floor
    gown = poly([(cx - 5, by - 6), (cx + 5, by - 6), (cx + 8.5, ground), (cx - 7.5, ground)])
    f.add(gown, GOWN, centre=(cx - 2, by - 4), radius=(9, 13), bias=0.06)
    f.recolor({(x, y) for (x, y) in gown if y == ground}, "violet")
    f.recolor({(x, y) for (x, y) in gown if y == ground - 1 and x % 2 == 0}, "lilac")
    # fluffy white chest fur
    f.add(union(ellipse(cx + 1.5, by - 8.0, 4.4, 3.4), poly([(cx - 1, by - 7), (cx + 4, by - 7), (cx + 1.5, by - 2)])),
          FOX_W, bias=0.05)
    # high cloak collar and a gold moon clasp
    collar = poly([(cx - 8, by - 9), (cx - 5, by - 16), (cx - 2, by - 11), (cx + 4, by - 11), (cx + 7, by - 15),
                   (cx + 6, by - 8)])
    f.add(collar, CLOAK, centre=(cx - 3, by - 14), radius=(8, 5), bias=0.1)
    f.recolor({(x, y) for (x, y) in collar if (x, y - 1) not in collar}, "lilac")
    f.pix({(int(cx + 1), int(by - 10)): "yellow", (int(cx + 2), int(by - 10)): "gold",
           (int(cx + 1), int(by - 9)): "gold"}, MOON, sep=False)
    # head: a slender fox head, tall ears, long snout, elegant narrow eyes
    hx, hy = cx + 1.5, by - 21.0 + head_dy
    morgana_head(f, hx, hy, eyes, mouth, ear_dy)
    # staff and the front arm (a wide sleeve with lilac trim)
    if staff is None:
        staff = (cx + 16.0, by - 26.0, ground)
    sx_, stop, sbot = staff[0], staff[1], staff[2]
    stilt = staff[3] if len(staff) > 3 else 0.0
    moon_staff(f, sx_, stop, sbot, staff_glow, stilt)
    hy_hand = max(stop + 8, by - 10)
    hand = (sx_ - 0.5 + math.sin(math.radians(stilt)) * (sbot - hy_hand), hy_hand) if arm == "staff" else arm
    sleeve = union(capsule(cx + 3, by - 9, hand[0] - 1.5, hand[1] + 1, 2.6), poly([(hand[0] - 4, hand[1] - 1),
                                                                                     (hand[0] - 0.5, hand[1] + 1),
                                                                                     (hand[0] - 4, hand[1] + 5)]))
    f.add(sleeve, CLOAK, centre=(hand[0] - 3, hand[1] - 3), radius=(5, 5), bias=0.12)
    f.recolor({(x, y) for (x, y) in sleeve if x >= hand[0] - 4 and x <= hand[0] - 3}, "lilac")
    f.add(ellipse(hand[0], hand[1], 1.8, 1.7), FOX_W, flat=1)
    if extra:
        extra(f)
    return f


def _smoke(c: Canvas, blobs, a: int = 255) -> None:
    """Purple smoke puffs painted where the frame is empty or over it (the teleport)."""
    f = Fig(c.w, c.h, seed=7)
    for (x, y, r) in blobs:
        f.add(ellipse(x, y, r, r * 0.85), Mat(["dusk", "violet", "lilac", "fog"], outline="plum", lit="dusk"),
              bias=0.2, sep=False)
    s = f.render()
    if a < 255:
        s = fade(s, a)
    c.blit(s, 0, 0)


def morgana_teleport(k: int) -> Canvas:
    base = morgana_frame(eyes="sly", mouth="smile", staff_glow=4, cloak_lift=0.2).render()
    if k == 0:
        c = base
        _smoke(c, [(20, 60, 4), (30, 61, 5), (40, 60, 4), (14, 56, 2.5)])
        return c
    if k == 1:
        c = fade(dissolve(base, 0.55, seed=3), 170)
        _smoke(c, [(18, 56, 5), (29, 52, 7), (40, 55, 5), (25, 40, 5), (36, 34, 4), (30, 24, 4)])
        return c
    if k == 2:
        c = Canvas(64, 64)
        _smoke(c, [(22, 50, 6), (32, 44, 8), (40, 52, 5), (28, 30, 5), (36, 22, 4)], 220)
        return c
    c = Canvas(64, 64)
    _smoke(c, [(22, 40, 3.4), (40, 32, 2.8), (32, 50, 3.0)], 150)
    for (x, y) in ((26, 24), (46, 42), (16, 50), (38, 16), (30, 34)):
        c.set(x, y, "white")
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.set(x + dx, y + dy, alpha_px("lilac", 170))
    return c


def morgana_down(k: int) -> Canvas:
    """Sitting on the floor, cloak pooled around her, tail curled in front, ears drooping, a tear: sad, never hurt.
    Her staff lies on the floor beside her."""
    f = Fig(64, 64, seed=123)
    ground = GROUND64
    cx = 28.0
    # staff lying on the floor behind her tail
    f.pix({(x, ground - 1): ("plum" if x % 6 else "violet") for x in range(36, 57)}, STAFF)
    crescent = ellipse(58, ground - 4, 4.0, 4.0) - ellipse(59.8, ground - 5.2, 3.2, 3.2)
    f.add(crescent, MOON, bias=0.0)
    f.pix({(58, ground - 3): "lilac"}, TRIM, sep=False)
    # cloak pooled on the floor (a wide low mound) with the wine lining at the rim
    cl = union(ellipse(cx - 2, ground - 5, 15.0, 6.0), poly([(cx - 6, ground - 24), (cx + 6, ground - 24),
                                                            (cx + 11, ground - 6), (cx - 14, ground - 6)]))
    f.add(cl, CLOAK, centre=(cx - 6, ground - 18), radius=(16, 14), bias=0.08, contrast=0.85)
    f.recolor({(x, y) for (x, y) in cl if y >= ground - 2}, "wine")
    f.recolor({(x, y) for (x, y) in cl if y == ground - 3 and x % 3 == 0}, "plum")
    # collar and chest fur
    f.add(ellipse(cx + 1.5, ground - 22, 4.2, 3.2), FOX_W, bias=0.05)
    collar = poly([(cx - 7, ground - 22), (cx - 4, ground - 29), (cx - 1, ground - 24), (cx + 4, ground - 24),
                   (cx + 7, ground - 28), (cx + 6, ground - 21)])
    f.add(collar, CLOAK, bias=0.1)
    f.recolor({(x, y) for (x, y) in collar if (x, y - 1) not in collar}, "lilac")
    # paws in her lap, the tail curled round the front with its white tip
    f.add(ellipse(cx + 3, ground - 12, 2.4, 1.8), FOX_W, flat=1)
    tail_s = union(capsule(cx - 12, ground - 5, cx + 6, ground - 6, 3.8), ellipse(cx + 9, ground - 7, 4.0, 3.4))
    f.add(tail_s, FOX, centre=(cx - 2, ground - 9), radius=(12, 4), bias=0.08)
    f.recolor({(x, y) for (x, y) in ellipse(cx + 9.5, ground - 7, 4.2, 3.6) if (x, y) in tail_s}, "cream")
    f.recolor({(x, y) for (x, y) in ellipse(cx + 10, ground - 8, 2.0, 1.6) if (x, y) in tail_s}, "white")
    # head bowed a little, ears drooping, a tear
    morgana_head(f, cx + 1.5, ground - 32 + k, "sad", "frown", 3)
    if k:
        for (x, y) in ((46, 20), (47, 20), (48, 19), (49, 19), (48, 20), (50, 20)):
            f.glow(x, y, alpha_px("fog", 210))
    return f.render()


def morgana() -> list[Anim]:
    M = morgana_frame
    idle = [M(), M(bob=1, sway=0.6, tail=0.2, staff_glow=3), M(bob=1, sway=1.0, tail=0.35, staff_glow=3, eyes="open"),
            M(sway=0.5, tail=0.15, staff_glow=2)]
    run = [M(hover=2 + (i % 3 == 1), lean=1, sway=i % 3, cloak_lift=0.5 + 0.1 * (i % 2), tail=-0.4,
             staff=(44.0, 14.0 - (i % 3 == 1), 58.0 - (i % 3 == 1), 12.0)) for i in range(6)]
    attack = [M(lean=-1.5, eyes="open", staff=(50.0, 14.0, 58.0, -6.0), staff_glow=3),
              M(lean=2, eyes="angry", mouth="open", staff=(46.0, 16.0, 56.0, 32.0), staff_glow=4, cloak_lift=0.3,
                extra=lambda f: _moon_flash(f, 57, 12)),
              M(lean=1.5, eyes="sly", staff=(45.0, 15.0, 57.0, 22.0), staff_glow=3, cloak_lift=0.2),
              M(lean=0.5)]
    hurt = [M(lean=-2.5, head_dy=1, eyes="squint", mouth="open", ear_dy=1, staff_glow=1,
              extra=lambda f: stars(f, [(20, 8), (40, 6)])),
            M(lean=-1.5, eyes="squint", mouth="frown", ear_dy=1, staff_glow=1)]
    cast = [M(eyes="open", staff=(43.0, 9.0, 50.0), staff_glow=3, bob=-1),
            M(eyes="sly", mouth="open", staff=(43.0, 7.0, 46.0), staff_glow=5, bob=-2, cloak_lift=0.3,
              extra=lambda f: _cast_ring(f, 44, 2, 0)),
            M(eyes="sly", mouth="smile", staff=(43.0, 7.0, 46.0), staff_glow=5, bob=-2, cloak_lift=0.3,
              extra=lambda f: _cast_ring(f, 44, 2, 1)),
            M(eyes="sly", staff=(43.0, 9.0, 50.0), staff_glow=3, bob=-1)]
    teleport = [morgana_teleport(k) for k in range(4)]
    down = [morgana_down(0), morgana_down(1)]
    r = lambda fs: [x.render() for x in fs]  # noqa: E731
    return [anim("idle", r(idle), 5.0, True), anim("run", r(run), 10.0, True),
            anim("attack", r(attack), 12.0, False, [1.2, 0.8, 1.0, 1.0]),
            anim("hurt", r(hurt), 6.0, False, [1.0, 3.0]),
            anim("cast", r(cast), 12.0, False, [1.0, 1.0, 1.0, 1.0]),
            anim("teleport", teleport, 14.0, False),
            anim("down", down, 2.0, False)]


def _moon_flash(f: Fig, x: int, y: int) -> None:
    for k in range(8):
        a = k * math.pi / 4
        for d in (4, 5, 6):
            f.glow(int(round(x + math.cos(a) * d)), int(round(y + math.sin(a) * d)),
                   alpha_px("white" if d < 6 else "lilac", 200 - d * 15))


def _cast_ring(f: Fig, x: int, y: int, k: int) -> None:
    for i in range(10):
        a = i * math.pi / 5 + k * 0.3
        r = 9 + k * 2
        px_, py_ = int(round(x + math.cos(a) * r)), int(round(y + 4 + math.sin(a) * r * 0.4))
        sparkle(f, px_, py_, "white" if i % 2 else "lilac", "violet", 1 if i % 2 == k else 0)


# ===========================================================================
# CC2 portraits, 48x48, in the v2.3 storybook style (art_portraits.py): a painted bust on a small backdrop,
# one base per character plus an expression layer. Drawn facing right; all five speakers sit on the
# right of the dialogue box (dialogue_box.LEFT_SPEAKERS is goldie and bulldog only), so they are mirrored.
# ===========================================================================

PS = 48
PORTRAITS_V26: dict[str, list[str]] = {
    "lancelot": ["normal", "happy", "serious", "surprised"],
    "gargoyle": ["normal"],
    "green_knight": ["normal"],
    "lady_lake": ["normal", "smile", "worried"],
    "morgana_true": ["normal", "angry", "sad", "smile"],
}
EYE_L = {"o": "ink", "n": "brown_d", "w": "white", "b": "gold_d", "p": "pink", "r": "red", "R": "red_d",
         "s": "sky_l", "u": "sky", "y": "yellow", "a": "amber", "l": "lilac", "v": "violet", "c": "cream",
         "g": "leaf_l", "G": "leaf", "U": "umber", "W": "wine"}


def _px(c: Canvas, pts, col: str) -> None:
    for (x, y) in pts:
        c.set(x, y, col)


def _stamp(c: Canvas, rows: list[str], x: int, y: int) -> None:
    P.stamp(c, rows, x, y, EYE_L)


def p_backdrop(kind: str) -> Canvas:
    import random as _r
    c = Canvas(PS, PS, P.rgba("sky"))
    if kind == "lancelot":          # bright castle courtyard morning, a stone battlement behind
        P.radial(c, 34, 8, 54, ["water", "sky", "azure", "sky_l"], sharp=1.4)
        for x in range(PS):
            top = 36 if (x // 6) % 2 == 0 else 39
            for y in range(top, PS):
                c.set(x, y, "stone" if y < top + 2 else "stone_d")
            if x % 6 == 0:
                for y in range(top, PS):
                    c.set(x, y, "slate")
        for x in range(0, PS, 12):
            for y in range(42, PS):
                c.set(x + 3, y, "slate")
    elif kind == "gargoyle":        # castle wall at dusk
        P.vgrad(c, 0, 0, PS, PS, ["dusk", "rose", "peach", "gold_l"], sharp=1.3)
        for x in range(PS):
            top = 34 if (x // 5) % 2 == 0 else 37
            for y in range(top, PS):
                c.set(x, y, "plum" if y < top + 1 else "night")
        rng = _r.Random(5)
        for (x, y) in P.scatter(rng, 4, 0, 0, PS, 20):
            c.set(x, y, "cream")
    elif kind == "green_knight":    # the magic garden: pale sky, trimmed hedges, flowers
        P.vgrad(c, 0, 0, PS, PS, ["sky", "azure", "haze", "haze"], sharp=1.3)
        for x in range(PS):
            h = 36 + int(2.5 * math.sin(x / 4.0))
            for y in range(h, PS):
                c.set(x, y, P.pick(["leaf", "grass", "leaf_d"], (y - h) / 8, x, y))
        rng = _r.Random(8)
        for (x, y) in P.scatter(rng, 9, 0, 38, PS, PS):
            c.set(x, y, "pink" if rng.random() < 0.5 else "white")
    elif kind == "lady_lake":       # misty lake under a pale moon
        P.vgrad(c, 0, 0, PS, 30, ["night", "water_d", "water", "sky"], sharp=1.3)
        P.vgrad(c, 0, 30, PS, PS, ["sky", "water", "water_d"], sharp=1.3)
        for (x, y) in P.ellipse(38, 8, 4, 4):
            c.set(x, y, "haze")
        for y in (33, 37, 42, 46):
            for x in range((y * 7) % 5, PS, 9):
                c.set(x, y, "sky_l")
                c.set(x + 1, y, "sky_l")
                c.set(x + 2, y, "azure")
        for x in range(PS):
            c.set(x, 30, "azure")
    elif kind == "morgana_true":    # her tower at night, the full moon behind her (like the silhouette)
        import art_portraits
        c = art_portraits.morgana_backdrop()
    return c


# --------------------------------------------------------------------------- lancelot
P_SHIBA = ["brown", "gold_d", "orange", "amber"]
P_URA = ["sand", "cream", "white"]
P_STEEL = ["iron", "steel_d", "steel", "steel_l", "white"]
P_BLUE = ["night", "water_d", "water", "sky", "sky_l"]


def lancelot_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    # lance upright at the right with its blue pennant
    _px(f, [(43, y) for y in range(6, 48)], "brown")
    _px(f, [(44, y) for y in range(6, 48)], "brown_d")
    tip = P.poly([(43.5, 0), (46, 6), (41, 6)])
    P.shade_shape(f, tip, P_STEEL, bias=0.1)
    pen = P.poly([(42, 7), (34, 9), (37, 11), (33, 13), (42, 13)])
    P.shade_shape(f, pen, P_BLUE, bias=0.05)
    # blue plume flowing back from the helmet
    plume = P.poly([(18, 6), (12, 1), (4, 2), (0, 8), (2, 12), (6, 7), (11, 6), (8, 12), (14, 9), (20, 9)])
    P.shade_shape(f, plume, P_BLUE, bias=0.1)
    # body: silver breastplate, blue tabard, pauldron
    chest = P.poly([(6, 48), (9, 39), (17, 35), (33, 35), (40, 39), (42, 48)])
    P.shade_shape(f, chest, P_STEEL, centre=(22, 40), radius=(20, 11))
    tab = P.poly([(18, 37), (30, 37), (31, 48), (17, 48)])
    P.shade_shape(f, tab, P_BLUE, bias=0.0)
    _px(f, [(24, y) for y in range(39, 48)], "yellow")
    _px(f, [(x, 42) for x in range(21, 28)], "yellow")
    _px(f, [(25, y) for y in range(40, 48)], "gold")
    pauldron = P.ellipse(11, 40, 7, 5)
    P.outline_shape(f, pauldron, "steel_d")
    P.shade_shape(f, pauldron, P_STEEL, bias=0.08)
    # cream chest fur ruff
    ruff = P.ellipse(25, 34, 9, 3.5)
    P.shade_shape(f, ruff, P_URA, bias=0.05)
    # ears poking up through the helmet
    for (x0, flip) in ((13, -1), (29, 1)):
        ear = P.poly([(x0 - 4, 14), (x0 + 1 * flip, 2), (x0 + 5, 14)])
        P.shade_shape(f, ear, P_SHIBA, bias=0.1 if flip > 0 else -0.05)
        P.fill(f, P.poly([(x0 - 1.5, 13), (x0 + 0.6 * flip, 6), (x0 + 2.5, 13)]), "cream")
    # head
    head = P.ellipse(22, 22, 13, 11.5)
    P.shade_shape(f, head, P_SHIBA, centre=(22, 22), radius=(13, 12), bias=0.05)
    # urajiro: cream cheeks and muzzle
    cheeks = P.ellipse(18, 28, 9, 5) | P.ellipse(31, 27, 7.5, 5)
    P.shade_shape(f, cheeks & head | P.ellipse(31, 27, 7.5, 5), P_URA, bias=0.1)
    # nose
    P.stamp(f, [".oo.", "oooo", ".oo."], 36, 23, {"o": "ink"})
    f.set(37, 23, "steel_l")
    # helmet over the crown: dome, brim, centre ridge
    helm = P.ellipse(21, 13, 12.5, 8.5) - P.rect(0, 16, PS, 10)
    helm |= P.rect(7, 14, 29, 2)
    for ex in (13, 29):
        helm -= P.rect(ex - 1, 4, 3, 9)
    P.shade_shape(f, helm, P_STEEL, centre=(18, 9), radius=(14, 7), bias=0.05)
    _px(f, [(x, 15) for x in range(8, 35)], "steel_d")
    _px(f, [(21, y) for y in range(6, 14)], "steel_l")
    # little eyebrow dots
    _px(f, [(18, 17), (19, 17), (29, 17), (30, 17)], "cream")
    for (x, y) in ((14, 27), (15, 27), (31, 26), (32, 26)):
        f.set(x, y, "pink")
    f.outline_all("ink")
    ne, fe, m = (16, 19), (28, 19), (34, 29)
    if expr in ("normal", "serious"):
        _stamp(f, [".ooo.", "owwoo", "oooon", ".ooo."], ne[0], ne[1])
        _stamp(f, [".oo.", "owoo", "ooon", ".oo."], fe[0], fe[1])
    if expr == "normal":     # a proud little smirk
        _px(f, [(m[0] - 4, m[1]), (m[0] - 3, m[1] + 1), (m[0] - 2, m[1] + 1), (m[0] - 1, m[1] + 1), (m[0], m[1])], "ink")
        f.set(m[0] + 1, m[1] - 1, "ink")
    elif expr == "happy":
        _stamp(f, [".ooo.", "o...o"], ne[0], ne[1] + 1)
        _stamp(f, [".oo.", "o..o"], fe[0], fe[1] + 1)
        _stamp(f, ["oooooo", ".oRRo.", "..pp.."], m[0] - 6, m[1])
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
        _stamp(f, [".ooo.", "owwoo", "owooo", "ooooo", ".ooo."], ne[0], ne[1] - 1)
        _stamp(f, [".oo.", "owoo", "oooo", ".oo."], fe[0], fe[1] - 1)
        _stamp(f, [".oo.", "oRRo", ".oo."], m[0] - 3, m[1])
        _stamp(f, ["..o.", ".oso", "osso", ".oo."], 4, 18)
    return f


# --------------------------------------------------------------------------- gargoyle
P_STONE = ["slate", "stone_d", "stone", "stone_l"]
P_MEMB = ["iron", "slate", "dusk", "ash"]


def gargoyle_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    # folded wings behind the shoulders
    for (pts, b) in (([(4, 48), (0, 30), (3, 18), (10, 26), (14, 34), (16, 48)], -0.05),
                     ([(44, 48), (47, 28), (45, 16), (38, 25), (33, 34), (32, 48)], -0.1)):
        w = P.poly(pts)
        P.shade_shape(f, w, P_MEMB, bias=b)
    _px(f, [(3, y) for y in range(19, 30)] + [(45, y) for y in range(17, 28)], "stone")
    # stone body with a carved belly
    body = P.poly([(8, 48), (11, 38), (18, 35), (32, 35), (38, 38), (41, 48)])
    P.shade_shape(f, body, P_STONE, centre=(22, 40), radius=(18, 11), bias=-0.02)
    for y in (40, 43, 46):
        _px(f, [(x, y) for x in range(19, 30)], "stone_d")
    # horns curling back
    for (bx, d) in ((14, -1), (28, 1)):
        horn = P.thick_line(bx, 12, bx - 3 + d, 4, 2.0) | P.thick_line(bx - 3 + d, 4, bx - 8 + d * 2, 1, 1.3)
        P.shade_shape(f, horn, ["iron", "slate", "stone_d", "ash"], bias=0.05)
    # pointed ears
    for (pts, b) in (([(9, 18), (0, 12), (9, 24)], -0.05), ([(35, 18), (45, 11), (36, 24)], 0.05)):
        P.shade_shape(f, P.poly(pts), P_STONE, bias=b)
    head = P.ellipse(22, 22, 13, 12) | P.ellipse(26, 28, 9, 6)
    P.shade_shape(f, head, P_STONE, centre=(20, 20), radius=(14, 13), bias=0.0)
    # heavy carved brow and cracks
    _px(f, [(x, 17) for x in range(13, 34)], "stone_d")
    _px(f, [(x, 16) for x in range(14, 33) if x % 3 == 0], "stone_l")
    _px(f, [(10, 26), (11, 27), (11, 28), (12, 29)], "slate")
    # nostrils, fangs
    _px(f, [(28, 26), (31, 26)], "slate")
    f.outline_all("ink")
    # glowing purple eyes
    for ex in (15, 27):
        for (x, y) in P.ellipse(ex + 2.5, 21, 3.8, 2.8):
            if P.name_at(f, x, y) in ("stone", "stone_l", "stone_d", "slate"):
                f.set(x, y, "dusk" if P.name_at(f, x, y) != "stone_l" else "violet")
        _stamp(f, [".vvv.", "vwwlv", "vlllv", ".vvv."], ex, 19)
    _px(f, [(22, 32), (23, 33), (24, 33), (25, 33), (26, 33), (27, 33), (28, 32)], "ink")
    _stamp(f, ["w.", "w."], 23, 33)
    _stamp(f, [".w", ".w"], 26, 33)
    return f


# --------------------------------------------------------------------------- green knight
P_HEDGE = ["forest_d", "forest", "leaf_d", "grass", "leaf"]
P_BUSH = ["leaf_d", "grass", "leaf", "spring", "leaf_l"]


def green_knight_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    body = P.poly([(2, 48), (5, 38), (14, 33), (34, 33), (43, 38), (46, 48)])
    P.shade_shape(f, body, P_HEDGE, centre=(22, 38), radius=(22, 12))
    for (cx, cy) in ((9, 38), (39, 38)):
        sh = P.ellipse(cx, cy, 8, 6)
        P.shade_shape(f, sh, P_HEDGE, bias=0.06)
    strap = P.thick_line(10, 34, 34, 48, 1.4)
    P.fill(f, strap, "brown")
    _px(f, [(x, y) for (x, y) in strap if (x + y) % 4 == 0], "gold_d")
    # vine coiled on the shoulder
    for t in range(18):
        a = t * 0.7
        f.set(int(38 + math.cos(a) * 5), int(40 + math.sin(a) * 3 + t * 0.25), "leaf" if t % 3 else "leaf_l")
    head = P.ellipse(23, 26, 12, 10) | P.rect(12, 26, 23, 8)
    P.shade_shape(f, head, P_HEDGE, centre=(20, 23), radius=(13, 11), bias=0.04)
    face = P.ellipse(26, 27, 8.5, 6.5)
    P.fill(f, face, "forest_d")
    P.fill(f, {(x, y) for (x, y) in face if (x, y - 1) not in face}, "deep")
    # the round bush hat with flowers and Morgana's purple thorn
    hat = P.ellipse(22, 11, 19, 10) | P.ellipse(12, 15, 10, 6) | P.ellipse(33, 15, 10, 6)
    P.shade_shape(f, hat, P_BUSH, centre=(18, 8), radius=(20, 12), bias=0.0)
    rng = __import__("random").Random(11)
    for (x, y) in P.scatter(rng, 7, 6, 4, 40, 18):
        if (x, y) in hat:
            col = ("pink", "white", "yellow")[rng.randrange(3)]
            _px(f, [(x, y), (x + 1, y), (x, y + 1)], col)
            f.set(x + 1, y + 1, "yellow" if col != "yellow" else "amber")
    for x in range(4, 42, 3):
        f.set(x, 19 + (x % 2), "leaf_d")
    thorn = P.poly([(27, 6), (40, -2), (30, 9)])
    P.shade_shape(f, thorn, ["plum", "dusk", "violet", "lilac"], bias=0.1)
    f.outline_all("deep")
    # glowing eyes and the big grin
    for ex in (21, 29):
        _stamp(f, ["ggg", "gyg"], ex, 25)
    _px(f, [(19, 30), (20, 31), (21, 32), (22, 32), (23, 32), (24, 32), (25, 32), (26, 32), (27, 32), (28, 32),
            (29, 31), (30, 30)], "leaf_l")
    _px(f, [(21, 31), (22, 31), (23, 31), (24, 31), (25, 31), (26, 31), (27, 31), (28, 31)], "deep")
    _px(f, [(24, 31), (25, 31)], "wine")
    return f


# --------------------------------------------------------------------------- lady of the lake
P_SAMO = ["ash", "fog", "white", "white"]
P_DRESS = ["water", "sky", "azure", "sky_l"]


def lady_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    dress = P.poly([(3, 48), (7, 38), (16, 34), (32, 34), (41, 38), (45, 48)])
    P.shade_shape(f, dress, P_DRESS, centre=(22, 40), radius=(22, 11))
    for y in (41, 45):
        _px(f, [(x, y + (1 if (x // 3) % 2 else 0)) for x in range(4, 45) if x % 7 != 6], "sky_l")
    ruff = P.ellipse(24, 34, 13, 4.5)
    P.shade_shape(f, ruff, P_SAMO, bias=0.05)
    for (cx, flip) in ((12, -1), (32, 1)):
        ear = P.poly([(cx - 5, 15), (cx + 1 * flip, 2), (cx + 5, 15)])
        P.shade_shape(f, ear, P_SAMO, bias=0.08 if flip > 0 else -0.05)
        P.fill(f, P.poly([(cx - 2, 13), (cx + 0.5 * flip, 6), (cx + 2, 13)]), "pink")
    head = P.ellipse(23, 22, 14, 12) | P.ellipse(23, 28, 15, 7)
    P.shade_shape(f, head, P_SAMO, centre=(20, 19), radius=(15, 13), bias=0.12)
    # fluffy fur tufts on the cheeks
    for (x, y) in ((8, 27), (9, 30), (37, 27), (38, 30)):
        _px(f, [(x, y), (x - 1 if x < 20 else x + 1, y + 1)], "fog")
    muzzle = P.ellipse(31, 27, 6, 4)
    P.shade_shape(f, muzzle, P_SAMO, bias=0.15)
    P.stamp(f, [".oo.", "oooo", ".oo."], 34, 24, {"o": "ink"})
    f.set(35, 24, "steel_l")
    # pearl tiara and a water lily
    for (x, y) in ((15, 11), (19, 9), (23, 8), (27, 9), (31, 11)):
        _px(f, [(x, y)], "sky_l")
    f.set(23, 8, "white")
    _px(f, [(x, 10) for x in range(16, 31)], "azure")
    for (x, y, col) in ((8, 14, "pink"), (10, 13, "pink"), (9, 15, "pink"), (9, 14, "yellow"), (11, 15, "white")):
        f.set(x, y, col)
    for (x, y) in ((15, 28), (16, 28), (32, 26), (33, 26)):
        f.set(x, y, "pink")
    f.outline_all("slate")
    # floating droplets
    for (x, y) in ((4, 6), (42, 18), (40, 4)):
        _stamp(f, [".u.", "usu", "uuu", ".u."], x, y)
    ne, fe, m = (15, 19), (27, 19), (31, 31)
    if expr == "normal":
        _stamp(f, [".ooo.", "owwoo", "ooooo", ".ooo."], ne[0], ne[1])
        _stamp(f, [".oo.", "owoo", "oooo", ".oo."], fe[0], fe[1])
        _px(f, [(m[0] - 3, m[1]), (m[0] - 2, m[1] + 1), (m[0] - 1, m[1] + 1), (m[0], m[1] + 1), (m[0] + 1, m[1])], "ink")
        _px(f, [(ne[0], ne[1] - 2), (ne[0] + 1, ne[1] - 3), (ne[0] + 2, ne[1] - 3), (ne[0] + 3, ne[1] - 2)], "ash")
    elif expr == "smile":
        _stamp(f, [".ooo.", "o...o"], ne[0], ne[1] + 1)
        _stamp(f, [".oo.", "o..o"], fe[0], fe[1] + 1)
        _stamp(f, ["ooooo", ".oRRo", "..pp."], m[0] - 4, m[1])
    elif expr == "worried":
        _stamp(f, [".oo.", "owoo", "oooo", ".oo."], ne[0] + 1, ne[1] + 1)
        _stamp(f, [".oo.", "owoo", ".oo."], fe[0], fe[1] + 1)
        _px(f, [(ne[0] - 1, ne[1]), (ne[0], ne[1] - 1), (ne[0] + 1, ne[1] - 1), (ne[0] + 2, ne[1] - 2),
                (ne[0] + 3, ne[1] - 3)], "slate")
        _px(f, [(fe[0], fe[1] - 3), (fe[0] + 1, fe[1] - 2), (fe[0] + 2, fe[1] - 1), (fe[0] + 3, fe[1] - 1)], "slate")
        _px(f, [(m[0] - 2, m[1] + 1), (m[0] - 1, m[1]), (m[0], m[1]), (m[0] + 1, m[1] + 1)], "ink")
    return f


# --------------------------------------------------------------------------- morgana's true face
P_FOX = ["umber", "brown", "gold_d", "amber"]
P_CLOAK = ["ink", "plum", "dusk", "violet"]


def morgana_true_portrait(expr: str) -> Canvas:
    f = Canvas(PS, PS)
    # crescent staff at the right
    _px(f, [(43, y) for y in range(10, 48)], "plum")
    _px(f, [(44, y) for y in range(10, 48)], "ink")
    moon = P.ellipse(43, 6, 5.5, 5.5) - P.ellipse(45.5, 4.5, 4.5, 4.5)
    P.shade_shape(f, moon, ["gold_d", "gold", "yellow", "cream"], bias=0.1)
    # cloak with a high pointed collar, lilac trim, gold moon clasp
    cloak = P.poly([(0, 48), (3, 38), (10, 31), (16, 36), (32, 36), (38, 31), (45, 38), (48, 48)])
    P.shade_shape(f, cloak, P_CLOAK, centre=(22, 40), radius=(24, 12), bias=0.04)
    _px(f, [(x, y) for (x, y) in P.edge(cloak) if y < 40 and (x, y - 1) not in cloak], "lilac")
    fur = P.ellipse(24, 37, 7, 4)
    P.shade_shape(f, fur, P_URA, bias=0.05)
    _px(f, [(23, 41), (24, 41), (23, 42), (24, 42)], "yellow")
    f.set(24, 42, "gold")
    # tall ears with dark insides
    for (pts, inner, b) in (([(8, 22), (7, 2), (17, 14)], [(10, 18), (9, 7), (14, 14)], -0.05),
                            ([(25, 12), (32, 0), (34, 16)], [(28, 12), (32, 4), (32, 14)], 0.08)):
        P.shade_shape(f, P.poly(pts), P_FOX, bias=b)
        P.fill(f, P.poly(inner), "umber")
    head = P.ellipse(20, 23, 12, 11)
    P.shade_shape(f, head, P_FOX, centre=(18, 20), radius=(13, 12), bias=0.04)
    snout = P.poly([(24, 20), (40, 26), (40, 28), (26, 33)])
    P.shade_shape(f, snout, P_FOX, centre=(28, 24), radius=(10, 6), bias=0.1)
    cheek = P.ellipse(20, 30, 9, 4) | P.poly([(26, 29), (40, 27), (39, 29), (27, 33)])
    P.shade_shape(f, cheek & (head | snout), P_URA, bias=0.05)
    P.stamp(f, ["oo", "oo"], 39, 25, {"o": "ink"})
    # a swept lock of fur over the brow and a violet jewel
    _px(f, [(12, 12), (13, 12), (14, 13), (15, 13), (16, 14)], "amber")
    _px(f, [(17, 15), (18, 15)], "violet")
    f.set(17, 15, "lilac")
    f.outline_all("ink")
    ne, fe, m = (16, 21), (26, 21), (33, 31)
    if expr == "normal":      # composed, half-lidded and a little lonely
        _stamp(f, ["ooooo.", "oaaao.", ".ooo.."], ne[0], ne[1])
        _stamp(f, ["oooo", "oaao", ".oo."], fe[0], fe[1])
        _px(f, [(ne[0] + 5, ne[1] - 1), (fe[0] + 4, fe[1] - 1)], "ink")
        _px(f, [(m[0] - 3, m[1]), (m[0] - 2, m[1] + 1), (m[0] - 1, m[1] + 1), (m[0], m[1])], "brown_d")
    elif expr == "angry":
        _stamp(f, ["o....", "ooo..", "oaaoo", ".ooo."], ne[0], ne[1] - 1)
        _stamp(f, ["...o", ".ooo", "oaao", ".oo."], fe[0], fe[1] - 1)
        _stamp(f, ["oooooo", "owWWwo", ".oooo."], m[0] - 5, m[1] - 1)
    elif expr == "sad":
        _stamp(f, ["...o.", ".ooo.", "oaaao", ".ooo."], ne[0], ne[1])
        _stamp(f, [".o..", ".ooo", "oaao", ".oo."], fe[0], fe[1])
        _px(f, [(m[0] - 3, m[1] + 1), (m[0] - 2, m[1]), (m[0] - 1, m[1]), (m[0], m[1] + 1)], "brown_d")
        _stamp(f, [".s.", "sus", ".u."], ne[0] + 2, ne[1] + 4)
    elif expr == "smile":     # a rare, real smile
        _stamp(f, [".ooo.", "o...o"], ne[0], ne[1] + 1)
        _stamp(f, [".oo.", "o..o"], fe[0], fe[1] + 1)
        _px(f, [(m[0] - 4, m[1]), (m[0] - 3, m[1] + 1), (m[0] - 2, m[1] + 1), (m[0] - 1, m[1] + 1), (m[0], m[1])],
            "brown_d")
        _px(f, [(ne[0] + 1, ne[1] + 4), (ne[0] + 2, ne[1] + 4), (fe[0] + 1, fe[1] + 4)], "rose")
    if expr != "smile":
        _px(f, [(ne[0] + 1, ne[1] + 5), (ne[0] + 2, ne[1] + 5)], "rose")
    return f


PORTRAIT_BUILDERS = {
    "lancelot": lancelot_portrait,
    "gargoyle": gargoyle_portrait,
    "green_knight": green_knight_portrait,
    "lady_lake": lady_portrait,
    "morgana_true": morgana_true_portrait,
}


def portrait(speaker: str, expr: str) -> Canvas:
    c = p_backdrop(speaker)
    c.blit(PORTRAIT_BUILDERS[speaker](expr), 0, 0)
    P.quantize(c)
    return c.flipped()


def write_portraits() -> None:
    for speaker, exprs in PORTRAITS_V26.items():
        for expr in exprs:
            portrait(speaker, expr).save(res_path("res://assets/portraits/%s/%s.png" % (speaker, expr)), opaque=True)




# ===========================================================================
# CC3 projectiles (assets/fx/<name>/<name>_frames.tres, animation `default`, looping, drawn facing right:
# line A rotates them along their flight) and the one-shot particles stone_chips / shadow_leaves.
# ===========================================================================

def _halo(c: Canvas, cx: float, cy: float, r: float, col: str, a: int) -> None:
    for (x, y) in P.ellipse(cx, cy, r, r):
        if c.get(x, y) is None:
            c.set(x, y, alpha_px(col, a))


def magic_orb() -> list[Anim]:
    """12x12 violet magic orb from the spellbook: white core, lilac body, a little trailing spark."""
    frames = []
    for k in range(4):
        c = Canvas(12, 12)
        r = 3.4 + (0.4 if k % 2 else 0.0)
        body = P.ellipse(6.5, 6, r, r)
        for (x, y) in body:
            d = math.hypot(x + 0.5 - 5.8, y + 0.5 - 5.3) / r
            c.set(x, y, "white" if d < 0.38 else ("lilac" if d < 0.8 else "violet"))
        P.outline_shape(c, body, "plum")
        _halo(c, 6.5, 6, r + 2.2, "violet", 70)
        # trailing sparks behind (left), drifting with the frame
        for (x, y) in ((1, 5 + k % 2), (2, 8 - k % 2)):
            c.set(x, y, alpha_px("lilac", 200 - 40 * (k % 2)))
        sx, sy = [(6, 4), (8, 6), (6, 8), (4, 6)][k]
        c.set(sx, sy, "white")
        frames.append(c)
    return [Anim("default", frames, 12.0, True)]


def thorn() -> list[Anim]:
    """16x16 purple thorn from the green knight's thorn ring: a curved tapering spike with two barbs and a
    green stem end."""
    frames = []
    for k in range(2):
        c = Canvas(16, 16)
        spike = set()
        for x in range(2, 15):
            t = (x - 2) / 12.0
            hw = 2.1 * (1 - t) + 0.3
            yc = 8.0 + 0.9 * math.sin(t * math.pi) * -1
            for y in range(16):
                if abs(y + 0.5 - yc) <= hw:
                    spike.add((x, y))
        spike |= {(6, 5), (5, 5), (10, 10), (9, 10)}          # two little barbs
        for (x, y) in spike:
            t = (x - 2) / 12.0
            yc = 8.0 - 0.9 * math.sin(t * math.pi)
            c.set(x, y, "lilac" if y + 0.5 < yc - 0.6 else ("violet" if y + 0.5 < yc + 0.6 else "plum"))
        tipx = max(x for (x, _) in spike)
        c.set(tipx, min(y for (x, y) in spike if x == tipx), "white" if k == 0 else "lilac")
        if k:
            c.set(8, 6, "white")
        P.outline_shape(c, spike, "ink")
        for (x, y, col) in ((1, 7, "leaf_d"), (1, 8, "forest"), (1, 9, "leaf_d"), (0, 6, "leaf"), (0, 10, "leaf")):
            c.set(x, y, col)
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


def fox_flame() -> list[Anim]:
    """16x16 foxfire flame falling from Morgana's fox-fire rain: a violet-pink flame whose tail trails behind."""
    frames = []
    for k in range(4):
        c = Canvas(16, 16)
        cx, cy, r = 10.0, 8.0, 3.8
        sway = (-1, 0, 1, 0)[k]
        tail = P.poly([(cx - r * 0.3, cy - r * 0.9), (cx - 9.5, cy - 0.5 + sway), (cx - r * 0.3, cy + r * 0.9)])
        lick = P.poly([(cx - 1, cy - r * 0.6), (cx - 6.5, cy - 3.0 - sway * 0.5), (cx - 2, cy)])
        ears = P.poly([(cx + 0.5, cy - r * 0.6), (cx + 1.5, cy - r - 2.0), (cx + 2.8, cy - r * 0.5)])
        shape = {(x, y) for (x, y) in (ellipse(cx, cy, r, r) | tail | lick | ears) if 0 <= x < 16 and 0 <= y < 16}
        _halo(c, cx, cy, r + 2.0, "lilac", 60)
        flame_paint(c, shape, cx, cy, r)
        frames.append(c)
    return [Anim("default", frames, 14.0, True)]


def moon_orb() -> list[Anim]:
    """16x16 moonlight orb from Morgana's staff: a pale lilac sphere with a turning crescent and a soft halo."""
    frames = []
    for k in range(4):
        c = Canvas(16, 16)
        cx, cy, r = 9.0, 8.0, 4.4
        _halo(c, cx, cy, r + 2.6, "lilac", 55)
        _halo(c, cx, cy, r + 1.4, "violet", 90)
        body = P.ellipse(cx, cy, r, r)
        for (x, y) in body:
            c.set(x, y, "lilac")
        ang = k * math.pi / 2
        ox, oy = math.cos(ang) * 1.8, math.sin(ang) * 1.8
        crescent = body - P.ellipse(cx + ox, cy + oy, r * 0.85, r * 0.85)
        for (x, y) in crescent:
            c.set(x, y, "white")
        for (x, y) in P.ellipse(cx - 1.2, cy - 1.4, 1.2, 1.2):
            if (x, y) in body and (x, y) not in crescent:
                c.set(x, y, "fog")
        P.outline_shape(c, body, "dusk")
        for (x, y, a) in ((2, 8, 200), (1, 6 - k % 2, 140), (3, 11, 120)):
            c.set(x, y, alpha_px("white" if a > 150 else "lilac", a))
        frames.append(c)
    return [Anim("default", frames, 10.0, True)]


PROJECTILES = {
    "magic_orb": (magic_orb, (12, 12)),
    "thorn": (thorn, (16, 16)),
    "fox_flame": (fox_flame, (16, 16)),
    "moon_orb": (moon_orb, (16, 16)),
}

PARTICLE_TEXTURES = {
    "stone_chip": art_particles._tex([".sS", "sSd", "Sd."], {"s": "stone_l", "S": "stone", "d": "stone_d"}),
    "leaf": art_particles._tex([".lL", "lLd", "Ld."], {"l": "leaf_l", "L": "leaf", "d": "leaf_d"}),
}

PARTICLES = {
    # the gargoyle turning to stone (and back): a puff of little grey chips that bounce off
    "stone_chips": {
        "tex": "stone_chip", "z": 5, "props": {
            "amount": 10, "lifetime": 0.7, "explosiveness": 0.95, "direction": "Vector2(0, -1)", "spread": 80.0,
            "gravity": "Vector2(0, 260)", "initial_velocity_min": 45.0, "initial_velocity_max": 90.0,
            "angular_velocity_min": -480.0, "angular_velocity_max": 480.0, "angle_min": -180.0, "angle_max": 180.0,
            "damping_min": 10.0, "damping_max": 30.0, "scale_amount_min": 0.7, "scale_amount_max": 1.2,
        },
        "ramp": [(0, "white", 1), (0.75, "white", 1), (1, "white", 0)],
    },
    # the shadow wolf crumbling into forest leaves: they flutter up, then drift down and sideways
    "shadow_leaves": {
        "tex": "leaf", "z": 5, "props": {
            "amount": 12, "lifetime": 1.3, "explosiveness": 0.85, "direction": "Vector2(0, -1)", "spread": 70.0,
            "gravity": "Vector2(0, 45)", "initial_velocity_min": 25.0, "initial_velocity_max": 55.0,
            "damping_min": 30.0, "damping_max": 50.0, "angular_velocity_min": -260.0, "angular_velocity_max": 260.0,
            "angle_min": -180.0, "angle_max": 180.0, "tangential_accel_min": -25.0, "tangential_accel_max": 25.0,
            "scale_amount_min": 0.8, "scale_amount_max": 1.2,
        },
        # a few leaves are tinted with the shadow's violet, most keep their green
        "initial": [(0, "white", 1), (0.75, "lilac", 1)],
        "ramp": [(0, "white", 1), (0.7, "white", 1), (1, "white", 0)],
    },
}


def write_fx() -> None:
    for name, (fn, size) in PROJECTILES.items():
        build_sheet("res://assets/fx/%s" % name, name, fn(), size)
    for name, tex in PARTICLE_TEXTURES.items():
        tex.save(res_path("%s/%s.png" % (art_particles.TEX_DIR, name)))
    for name, fx in PARTICLES.items():
        write_text(res_path("res://assets/fx/particles/%s.tscn" % name), art_particles.effect_tscn(name, fx))


# ===========================================================================
# CC4 black knight: the v2.5 sheet, every frame 8 px higher (art_v25_knights.LIFT), with metadata for the
# ground shadow. build_all.py writes the same sheet; this keeps the metadata line when it is rerun.
# ===========================================================================

def write_black_knight() -> list:
    import build_all
    anims = build_all.with_rim("black_knight", art_v25_knights.black_knight_v25())
    build_sheet("res://assets/sprites/black_knight", "black_knight", anims, (64, 64))
    add_foot_lift("res://assets/sprites/black_knight/black_knight_frames.tres", art_v25_knights.LIFT)
    return anims


def add_foot_lift(tres: str, lift: int) -> None:
    """Writes `metadata/foot_lift = <lift>` on the SpriteFrames: how many pixels the feet stand above the cell's
    bottom row. assets/backgrounds/actor_shadows.gd can read it with get_meta(&"foot_lift", 0)."""
    path = res_path(tres)
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if "metadata/foot_lift" not in text:
        text = text.rstrip("\n") + "\nmetadata/foot_lift = %d\n" % lift
    write_text(path, text)


# ---------------------------------------------------------------------------
# preview / write
# ---------------------------------------------------------------------------

CHARACTERS = {
    "gargoyle": (gargoyle, (32, 32)),
    "spellbook": (spellbook, (24, 24)),
    "foxfire": (foxfire, (16, 16)),
    "shadow_wolf": (shadow_wolf, (32, 32)),
    "lancelot": (lancelot, (32, 32)),
    "lady_lake": (lady_lake, (32, 32)),
    "green_knight": (green_knight, (64, 64)),
    "morgana": (morgana, (64, 64)),
}


def write_sprites(only=None) -> dict:
    out = {}
    for code, (fn, size) in CHARACTERS.items():
        if only and code not in only:
            continue
        anims = fn()
        build_sheet("res://assets/sprites/%s" % code, code, anims, size)
        out[code] = anims
    return out


def write_all() -> None:
    """Everything C 角色 owns in v2.6 (build_all.py calls this after the v2.5 characters)."""
    write_sprites()
    write_black_knight()
    write_portraits()
    write_fx()


def preview(out_dir: str, only=None) -> None:
    os.makedirs(out_dir, exist_ok=True)
    for code, (fn, size) in CHARACTERS.items():
        if only and code not in only:
            continue
        anims = fn()
        scale = 3 if size[0] >= 64 else (8 if size[0] <= 24 else 6)
        contact_sheet([a.frames for a in anims], scale).save(os.path.join(out_dir, "%s.png" % code))
    if not only:
        contact_sheet([[portrait(s, e) for e in ex] for s, ex in PORTRAITS_V26.items()], 4).save(
            os.path.join(out_dir, "portraits_v26.png"))
        contact_sheet([fn()[0].frames for (fn, _) in PROJECTILES.values()], 8).save(
            os.path.join(out_dir, "projectiles_v26.png"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = [a[7:] for a in sys.argv[1:] if a.startswith("--only=")]
    only = only[0].split(",") if only else None
    if args:
        preview(args[0], only)
        print("previews in", args[0])
    else:
        write_all()
        print("v2.6 cast written")
