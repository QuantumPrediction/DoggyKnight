"""v2.5 (CR1) Goldie 金毛, redrawn at 32x32 with the rig renderer. Faces right.

Design (docs/STORY.md 3): cream-gold golden retriever, floppy ears, big eyes, red cape, steel
breastplate, English longsword. Light from the top-left. Feet on row GROUND (outline one row below),
the same relative spot as the 24x24 sprite (bottom of the cell), so the shadow and line A's
positions do not move.
"""

from __future__ import annotations

import math

import art_heroes
from rig import Fig, Mat, blade, capsule, ellipse, frames_like, minus, poly, rect, union

W = 32
GROUND = 29          # last row of the paws (the outline is row 30)

FUR = Mat(["brown", "gold_d", "gold", "gold_l"], outline="brown_d", lit="brown", fur=0.12)
FUR_HI = Mat(["gold", "gold_l", "cream", "white"], outline="brown_d", lit="brown", fur=0.08)
EAR = Mat(["brown", "gold_d", "gold", "gold_l"], outline="brown_d", lit="brown", fur=0.1, sep="brown_d")
STEEL = Mat(["iron", "steel_d", "steel", "steel_l"], outline="navy", lit="iron", spec="white", spec_at=0.86)
CAPE = Mat(["wine", "red_d", "red", "coral"], outline="umber", lit="wine")
CAPE_IN = Mat(["plum", "wine", "red_d"], outline="umber", lit="wine")
LEATHER = Mat(["umber", "brown_d", "brown", "gold_d"], outline="umber")
TRIM = Mat(["gold_d", "gold", "yellow", "cream"], outline="brown_d", spec="white")
HILT = Mat(["brown_d", "brown", "gold_d"], outline="umber")
BLADE = Mat(["steel_d", "steel", "steel_l", "white"], outline="navy", lit="iron")


def head(f: Fig, hx: float, hy: float, eyes: str = "open", mouth: str = "none", ear_dy: int = 0,
         tilt: int = 0) -> None:
    """Head centre (hx, hy): skull, muzzle, floppy ear, face details."""
    skull = union(ellipse(hx, hy, 8.4, 6.8), ellipse(hx - 0.5, hy - 1.5, 7.6, 6.0))
    f.add(skull, FUR, centre=(hx - 1.0, hy - 1.0), radius=(9.0, 7.6), bias=0.12)
    muzzle = union(ellipse(hx + 6.2, hy + 2.6, 4.4, 3.1), ellipse(hx + 4.0, hy + 3.6, 3.0, 2.4))
    f.add(muzzle, FUR_HI, centre=(hx + 5.0, hy + 1.4), radius=(5.0, 3.8), sep=False, bias=0.04)
    hxi, hyi = int(round(hx)), int(round(hy))
    # painted fur: a forehead tuft and cheek strands (2-pixel strokes, never single specks)
    f.recolor({(hxi - 2, hyi - 6), (hxi - 1, hyi - 6), (hxi + 1, hyi - 6)}, "gold_l")
    f.recolor({(hxi - 3, hyi - 5), (hxi - 2, hyi - 5)}, "cream")
    f.recolor({(hxi + 1, hyi + 5), (hxi + 2, hyi + 4), (hxi + 2, hyi + 5)}, "gold_d")
    # floppy ear on the near side: a long rounded flap, darker gold, hanging past the jaw
    ex, ey = hx - 4.0, hy - 4.0 + ear_dy
    ear = union(poly([(ex - 1.6, ey + 0.5), (ex + 2.6, ey - 0.6), (ex + 3.0, ey + 5.0), (ex + 2.0, ey + 10.0),
                      (ex - 0.6, ey + 10.4), (ex - 2.2, ey + 6.0)]), ellipse(ex + 0.3, ey + 8.6, 2.2, 2.0))
    f.add(ear, EAR, centre=(ex + 0.2, ey + 2.0), radius=(3.6, 7.0), bias=0.02)
    ix, iy = int(round(ex)), int(round(ey))
    f.recolor({(ix - 1, iy + 3), (ix - 1, iy + 4), (ix, iy + 6), (ix, iy + 7)}, "gold_d")
    # face
    exx, eyy = int(round(hx + 3.0)), int(round(hy - 1))
    nx, ny = int(round(hx + 10.0)), int(round(hy + 1.0))
    f.dots([(nx - 1, ny), (nx, ny), (nx - 1, ny + 1), (nx, ny + 1), (nx - 2, ny)], "umber")
    f.dot(nx - 1, ny, "slate")
    f.dots([(nx - 1, ny + 2), (nx - 2, ny + 3)], "brown")
    if eyes in ("open", "focus"):
        f.dots([(exx, eyy), (exx + 1, eyy), (exx, eyy + 1), (exx + 1, eyy + 1), (exx, eyy + 2), (exx + 1, eyy + 2)],
               "umber")
        f.dot(exx, eyy, "white")
        f.dot(exx + 1, eyy + 2, "brown")
        f.dot(exx, eyy + 2, "brown_d")
        if eyes == "focus":
            f.dots([(exx - 1, eyy - 2), (exx, eyy - 2), (exx + 1, eyy - 1), (exx + 2, eyy - 1)], "brown_d")
        else:
            f.dots([(exx - 1, eyy - 2), (exx, eyy - 2)], "gold_d")
    elif eyes == "blink":
        f.dots([(exx - 1, eyy + 2), (exx, eyy + 2), (exx + 1, eyy + 2)], "umber")
    elif eyes == "happy":
        f.dots([(exx - 1, eyy + 1), (exx, eyy), (exx + 1, eyy), (exx + 2, eyy + 1)], "umber")
    elif eyes == "squint":
        f.dots([(exx - 1, eyy), (exx, eyy + 1), (exx + 1, eyy + 1), (exx, eyy + 2), (exx - 1, eyy + 3)], "umber")
    elif eyes == "sleep":
        f.dots([(exx - 1, eyy + 1), (exx, eyy + 2), (exx + 1, eyy + 2), (exx + 2, eyy + 1)], "brown_d")
    # blush
    f.dots([(exx + 1, eyy + 4), (exx + 2, eyy + 4)], "pink")
    mx, my = int(round(hx + 7.0)), int(round(hy + 4))
    if mouth == "open":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my), (mx - 1, my + 1), (mx, my + 1)], "wine")
        f.dots([(mx, my + 1), (mx - 1, my + 2), (mx, my + 2)], "pink")
    elif mouth == "smile":
        f.dots([(mx - 1, my), (mx, my + 1), (mx + 1, my + 1), (mx + 2, my)], "brown_d")
    elif mouth == "o":
        f.dots([(mx, my), (mx, my + 1)], "wine")
    elif mouth == "tongue":
        f.dots([(mx - 1, my), (mx, my), (mx + 1, my)], "brown_d")
        f.dots([(mx, my + 1), (mx, my + 2), (mx + 1, my + 1)], "pink")
        f.dot(mx + 1, my + 2, "rose")


def cape(f: Fig, sx: float, sy: float, wave: float = 0.0, lift: float = 0.0) -> None:
    """Cape from the shoulders (sx, sy), flowing back (left) and down; wave/lift animate the hem.
    lift 0 = hanging, 1 = streaming back while running."""
    hem_y = GROUND - 0.5 - lift * 6
    back = sx - 7.5 - lift * 6
    pts = [(sx + 2, sy - 1.2), (sx - 2.5, sy - 1.8), (sx - 5.5 - lift * 2, sy + 1.5 - lift),
           (back - wave * 0.8, hem_y - 4 - lift * 2), (back - 0.5 - wave, hem_y),
           (back + 2.5 - wave * 0.4, hem_y - 1.0), (back + 5.0, hem_y + 0.2 - lift * 0.5),
           (sx - 1, hem_y - 1.0 - lift * 2), (sx + 1.5, sy + 6)]
    body = poly(pts)
    f.add(body, CAPE, centre=(sx - 2, sy + 1), radius=(9, 10), bias=0.06, contrast=0.85)
    # folds: darker strokes from the shoulder to each hem scallop, a lit ridge beside each
    for k, (x_bot, y_bot) in enumerate(((back + 2.5 - wave * 0.4, hem_y - 1.0), (back + 5.6, hem_y - 0.5))):
        x_top, y_top = sx - 2.5 - k * 0.5, sy + 1
        fold = {p for p in capsule(x_top, y_top, x_bot, y_bot - 0.5, 0.45) if p in body}
        f.shade_toward(fold, CAPE, -1)
        ridge = {(x - 1, y) for (x, y) in fold if (x - 1, y) in body and (x - 1, y) not in fold and y > y_top + 2}
        f.shade_toward(ridge, CAPE, +1)
    # the lining shows on the turned-back corner of the hem
    lining = {(x, y) for (x, y) in body if y >= hem_y - 1.5 and x <= back + 1.5 - wave}
    f.recolor(lining, "plum")


def tail(f: Fig, bx: float, by: float, ang: float) -> None:
    """Feathery tail from its base (bx, by); ang in degrees (180 = straight back, 120 = up-back)."""
    a = math.radians(ang)
    tx, ty = bx + math.cos(a) * 5.0, by - math.sin(a) * 5.5
    mx, my = bx + math.cos(a) * 2.5, by - math.sin(a) * 2.5
    s = union(capsule(bx, by, mx, my, 1.3), capsule(mx, my, tx, ty, 1.7), ellipse(tx - 0.3, ty - 0.4, 1.7, 1.9))
    f.add(s, FUR, centre=(tx, ty - 1), radius=(4, 4), bias=0.1)
    f.recolor({(int(round(tx - 1)), int(round(ty - 1))), (int(round(tx)), int(round(ty - 1)))}, "gold_l")


def leg(f: Fig, x: float, top: float, lift: int = 0, dx: float = 0.0, far: bool = False) -> None:
    """A short chibi leg with a cream paw; the paw sits on GROUND unless lifted."""
    foot_y = GROUND - lift
    s = union(rect(int(round(x + dx * 0.5)) - 1, int(top), 3, int(foot_y - top) - 1),
              capsule(x, top, x + dx, foot_y - 1.5, 1.5))
    f.add(s, FUR, mode="cyl_v", centre=(x + dx, foot_y), radius=(2.0, 4), bias=-0.12 if far else 0.06)
    px_ = int(round(x + dx))
    paw = rect(px_ - 1, foot_y - 1, 4, 2)
    paw |= {(px_ - 1 + 4, foot_y)} if not far else set()
    f.add(paw, FUR_HI if not far else FUR, flat=1 if not far else 2, sep=True)
    f.recolor({(px_, foot_y - 1), (px_ + 1, foot_y - 1)}, "cream" if not far else "gold_l")


def torso(f: Fig, bx: float, by: float) -> None:
    """Steel breastplate with a gold rim and a gold emblem, brown belt with a buckle."""
    plate = union(ellipse(bx, by - 0.5, 5.8, 4.4), rect(int(bx - 5), int(by), 11, 4))
    f.add(plate, STEEL, centre=(bx - 1.0, by - 1.5), radius=(6.4, 5.4), bias=0.06)
    belt = {(x, y) for (x, y) in plate if int(by + 2) <= y <= int(by + 3)}
    f.recolor({p for p in belt if p[1] == int(by + 2)}, "brown")
    f.recolor({p for p in belt if p[1] == int(by + 3)}, "brown_d")
    bxi, byi = int(round(bx + 1)), int(by + 2)
    f.dots([(bxi, byi), (bxi + 1, byi), (bxi, byi + 1), (bxi + 1, byi + 1)], "yellow")
    f.dot(bxi + 1, byi + 1, "gold_d")
    # emblem: a small gold sword-cross on the chest
    cx, cy = int(round(bx + 0.5)), int(round(by - 2))
    f.dots([(cx, cy - 1), (cx, cy), (cx - 1, cy), (cx + 1, cy), (cx, cy + 1)], "gold")
    f.dots([(cx, cy - 1), (cx - 1, cy)], "yellow")
    # tunic skirt under the belt
    skirt = {(x, y) for x in range(int(bx - 4), int(bx + 5)) for y in (int(by + 4),)}
    f.add(skirt, CAPE, flat=1, sep=True)


def neck_ruff(f: Fig, bx: float, by: float) -> None:
    """Cream chest fur spilling over the breastplate (zig-zag lower edge)."""
    ruff = ellipse(bx + 1.5, by - 4.6, 4.2, 2.2)
    ruff |= {(int(bx) - 1, int(by - 2)), (int(bx) + 1, int(by - 2)), (int(bx) + 3, int(by - 2))}
    f.add(ruff, FUR_HI, centre=(bx, by - 5.5), radius=(4.5, 2.5), sep=True, bias=0.05)


def arm(f: Fig, sx: float, sy: float, hx: float, hy: float) -> None:
    s = union(capsule(sx, sy, hx, hy, 1.6), ellipse(hx, hy, 1.9, 1.8))
    f.add(s, FUR, mode="sphere", centre=(hx - 1, hy - 1), radius=(3, 3), bias=0.12)
    f.add(ellipse(hx + 0.3, hy + 0.3, 1.6, 1.5), FUR_HI, flat=1, sep=False)


def sword(f: Fig, hx: float, hy: float, deg: float, length: int = 11) -> None:
    """Longsword held at (hx, hy) (the grip), blade along `deg` (0 = right, 90 = up)."""
    a = -math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    grip = {}
    for i in range(0, 4):
        grip[(int(round(hx - dx * i)), int(round(hy - dy * i)))] = "brown" if i < 3 else "yellow"
    f.pix(grip, HILT)
    gx, gy = hx + dx * 1.6, hy + dy * 1.6
    guard = {}
    for k in (-2, -1, 0, 1, 2):
        guard[(int(round(gx - dy * k)), int(round(gy + dx * k)))] = "yellow" if k <= 0 else "gold"
    f.pix(guard, TRIM)
    f.pix(blade(gx + dx * 1.2, gy + dy * 1.2, a, length, 2), BLADE)


def goldie_frame(bob: int = 0, lean: float = 0.0, eyes: str = "open", mouth: str = "none", ear_dy: int = 0,
                 legs=((0, 0.0), (0, 0.0)), arm_to=None, sword_deg: float = 52.0, sword_len: int = 11,
                 cape_wave: float = 0.0, cape_lift: float = 0.0, tail_ang: float = 112.0, head_dy: int = 0,
                 sword_on: bool = True, sword_behind: bool = False, extra=None) -> Fig:
    f = Fig(W, W, seed=3)
    bx, by = 14.5 + lean, 21.5 + bob          # torso centre
    hx, hy = 15.0 + lean * 1.3, 10.0 + bob + head_dy
    if arm_to is None:
        arm_to = (bx + 6.0, by + 1.0)
    if sword_on and sword_behind:
        sword(f, arm_to[0] + 0.5, arm_to[1] - 0.5, sword_deg, sword_len)
    tail(f, bx - 5, by + 1, tail_ang)
    cape(f, bx - 1, by - 3, cape_wave, cape_lift)
    (fl, fdx), (nl, ndx) = legs
    leg(f, bx - 2.0, by + 2, fl, fdx, far=True)
    leg(f, bx + 2.5, by + 2, nl, ndx)
    torso(f, bx, by)
    neck_ruff(f, bx, by)
    head(f, hx, hy, eyes, mouth, ear_dy)
    if sword_on and not sword_behind:
        sword(f, arm_to[0] + 0.5, arm_to[1] - 0.5, sword_deg, sword_len)
    arm(f, bx + 3.5, by - 2.0, arm_to[0], arm_to[1])
    if extra:
        extra(f)
    return f


def _stars(f: Fig, x: int, y: int, phase: int) -> None:
    for (sx, sy) in ((x, y), (x + 9, y + 1 - phase)):
        f.dots([(sx, sy - 1), (sx - 1, sy), (sx + 1, sy), (sx, sy + 1)], "yellow")
        f.dot(sx, sy, "white")


def _smear(c, cx: float, cy: float, r0: float, r1: float, a0: float, a1: float, strong: bool):
    """Swing arc behind the blade (degrees, 0 = right, counter-clockwise), translucent palette pixels."""
    from paint import alpha_px
    for y in range(c.h):
        for x in range(c.w):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if not (r0 <= d <= r1):
                continue
            ang = math.degrees(math.atan2(-(y + 0.5 - cy), x + 0.5 - cx))
            lo, hi = min(a0, a1), max(a0, a1)
            if lo <= ang <= hi and c.get(x, y) is None:
                edge = d > r1 - 1.2
                k = (ang - lo) / max(1.0, hi - lo)
                if a1 < a0:
                    k = 1 - k
                a = int((150 if edge else 80) * (0.35 + 0.65 * k) * (1.0 if strong else 0.6))
                c.set(x, y, alpha_px("white" if edge else "sky_l", a))
    return c


def goldie_v25() -> list:
    old = art_heroes.goldie_v2()
    walk = [((0, 0.0), (0, 0.0))]
    fr: dict[str, list] = {}
    # idle: breathing (bob on 2 frames), cape and ear sway, a blink
    idle_specs = [
        dict(),
        dict(bob=0, cape_wave=0.6),
        dict(bob=1, cape_wave=1.0, tail_ang=118),
        dict(bob=1, cape_wave=0.6, eyes="blink", tail_ang=122),
        dict(bob=1, ear_dy=1, cape_wave=0.2, tail_ang=118),
        dict(bob=0, ear_dy=1, tail_ang=112),
    ]
    fr["idle"] = [goldie_frame(**s).render() for s in idle_specs]
    # run: 6-frame cycle, contact / passing poses, cape streaming back
    run_legs = [((0, -3.0), (0, 3.0)), ((1, -1.5), (0, 1.0)), ((3, 0.5), (0, -1.5)),
                ((0, 3.0), (0, -3.0)), ((0, 1.0), (1, -1.5)), ((0, -1.5), (3, 0.5))]
    run_bob = [0, 1, -1, 0, 1, -1]
    fr["run"] = [goldie_frame(bob=run_bob[i], lean=0.5, legs=run_legs[i], cape_lift=0.75 + 0.15 * (i % 3 == 1),
                              cape_wave=(i % 3) * 0.6, tail_ang=140 + (i % 2) * 10, sword_deg=40,
                              ear_dy=-1 if run_bob[i] < 0 else (1 if run_bob[i] > 0 else 0), mouth="tongue").render()
                 for i in range(6)]
    # attack: wind-up (blade back over the shoulder), swing, follow-through with smear, recover
    a0 = goldie_frame(lean=-0.5, arm_to=(19.0, 17.0), sword_deg=125, eyes="focus", cape_wave=0.4,
                      sword_behind=True).render()
    a1 = goldie_frame(lean=1.0, arm_to=(23.5, 19.5), sword_deg=8, sword_len=12, eyes="focus", mouth="open",
                      cape_lift=0.5).render()
    _smear(a1, 17, 19, 8, 14, 10, 105, True)
    a2 = goldie_frame(lean=1.5, arm_to=(22.5, 22.0), sword_deg=-40, sword_len=11, eyes="focus", mouth="open",
                      cape_lift=0.7, legs=((0, -0.5), (0, 1.0))).render()
    _smear(a2, 17, 19, 8, 14, -45, 60, False)
    a3 = goldie_frame(lean=0.5, arm_to=(21.5, 20.5), sword_deg=20, eyes="open", cape_wave=0.8).render()
    fr["attack"] = [a0, a1, a2, a3]
    # hurt: a cute flinch (squint, little stars), never injured
    h0 = goldie_frame(lean=-1.5, head_dy=1, eyes="squint", mouth="o", ear_dy=-1, sword_deg=70, cape_wave=1.2,
                      extra=lambda f: _stars(f, 9, 2, 0)).render()
    h1 = goldie_frame(lean=-1.0, eyes="squint", mouth="o", sword_deg=60, cape_wave=0.6,
                      extra=lambda f: _stars(f, 8, 3, 1)).render()
    fr["hurt"] = [h0, h1]
    fr["sleep"] = [goldie_sleep(0), goldie_sleep(1)]
    # victory: raise the sword high, happy face, sparkle on the blade
    def spark(x: int, y: int):
        return lambda f: (f.dots([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "yellow"), f.dot(x, y, "white"))
    fr["victory"] = [
        goldie_frame(eyes="happy", mouth="smile", arm_to=(21.0, 16.0), sword_deg=75, cape_wave=0.4).render(),
        goldie_frame(bob=-1, eyes="happy", mouth="open", arm_to=(20.5, 12.5), sword_deg=88, ear_dy=-1,
                     cape_lift=0.4, tail_ang=100, extra=spark(21, 2)).render(),
        goldie_frame(bob=-1, eyes="happy", mouth="open", arm_to=(20.5, 12.5), sword_deg=88, ear_dy=-1,
                     cape_lift=0.6, tail_ang=95, extra=spark(23, 4)).render(),
        goldie_frame(eyes="happy", mouth="smile", arm_to=(21.0, 16.0), sword_deg=75, cape_wave=0.8,
                     tail_ang=108).render(),
    ]
    return frames_like(old, fr)


def goldie_sleep(z: int):
    """Curled up asleep under the red cape, head on the front paws, little Z's floating."""
    f = Fig(W, W, seed=5)
    breathe = z
    tailp = union(capsule(4, 27.5, 10, 28.5, 1.8), ellipse(4.5, 27, 2.2, 1.9))
    f.add(tailp, FUR, centre=(4, 26), radius=(4, 3), bias=0.12)
    body = ellipse(12.5, 25.2 - breathe * 0.4, 8.6, 4.8 + breathe * 0.4)
    f.add(body, FUR, centre=(11, 20), radius=(9, 8), bias=0.22)
    drape = {(x, y) for (x, y) in ellipse(11.5, 23.8 - breathe * 0.4, 8.0, 4.0 + breathe * 0.4) if y <= 26}
    f.add(drape, CAPE, centre=(9, 21), radius=(9, 5), bias=0.08)
    f.recolor({(x, 26) for x in range(5, 19) if (x, 26) in drape and x % 4 == 1}, "wine")
    paws = rect(17, 27, 7, 2)
    f.add(paws, FUR_HI, flat=2)
    hx, hy = 21.0, 23.0
    f.add(union(ellipse(hx, hy, 5.4, 4.4), ellipse(hx - 0.5, hy - 1.0, 4.6, 3.8)), FUR,
          centre=(hx - 1.5, hy - 1.5), radius=(6, 5), bias=0.12)
    f.add(ellipse(hx + 4.4, hy + 1.8, 3.0, 2.2), FUR_HI, sep=False, bias=0.04)
    f.add(poly([(hx - 4.5, hy - 2.5), (hx - 1.5, hy - 3.0), (hx - 1.0, hy + 2.0), (hx - 2.0, hy + 4.4),
                (hx - 4.0, hy + 4.0), (hx - 5.0, hy + 1.0)]), EAR, centre=(hx - 3.5, hy - 2), radius=(3, 5))
    ex, ey = int(hx + 1), int(hy)
    f.dots([(ex - 1, ey), (ex, ey + 1), (ex + 1, ey + 1), (ex + 2, ey)], "brown_d")
    f.dots([(int(hx + 7), int(hy + 1)), (int(hx + 6), int(hy + 1))], "umber")
    f.dots([(ex + 1, ey + 3), (ex + 2, ey + 3)], "pink")
    f.dots([(18, 27), (20, 27), (22, 27)], "gold_l")
    c = f.render()
    zs = [(24, 13, 0), (27, 7, 1)] if z else [(24, 14, 0)]
    for (x, y, big) in zs:
        g = ["ooo", ".o.", "ooo"] if not big else ["oooo", "..o.", ".o..", "oooo"]
        for yy, row in enumerate(g):
            for xx, ch in enumerate(row):
                if ch == "o":
                    c.set(x + xx, y + yy, "white")
        for yy in range(-1, len(g) + 1):
            for xx in range(-1, len(g[0]) + 1):
                if c.get(x + xx, y + yy) is None and any(
                        0 <= yy + dy < len(g) and 0 <= xx + dx < len(g[0]) and g[yy + dy][xx + dx] == "o"
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    c.set(x + xx, y + yy, "night")
    _ = minus
    return c
