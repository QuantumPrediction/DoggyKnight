"""v2.5 (CR1) Bedivere 貝德維爾, the bulldog companion, redrawn at 32x32 with the rig renderer.

White bulldog with brown patches, wide jowly head with an underbite and two little teeth, rose ears,
blue tunic, round steel-rimmed shield with a yellow cross. Faces right; paws on row GROUND.
"""

from __future__ import annotations

import art_heroes
from rig import Fig, Mat, capsule, ellipse, frames_like, poly, rect, union

W = 32
GROUND = 29

WFUR = Mat(["ash", "fog", "white", "white"], outline="slate", lit="ash", fur=0.1, sep="ash", sep_lit="fog")
PATCH = Mat(["brown_d", "brown", "gold_d"], outline="umber", lit="brown_d", fur=0.1)
EARM = Mat(["umber", "brown_d", "brown"], outline="umber")
TUNIC = Mat(["night", "water_d", "water", "sky"], outline="navy", lit="night")
STEEL = Mat(["iron", "steel_d", "steel", "steel_l"], outline="navy", lit="iron", spec="white", spec_at=0.84)
SHIELD = Mat(["water_d", "water", "sky", "sky_l"], outline="navy", lit="night")
GOLDM = Mat(["gold_d", "gold", "yellow"], outline="brown_d")
BELT = Mat(["umber", "brown_d", "brown"], outline="umber")


def head(f: Fig, hx: float, hy: float, eyes: str = "open", mouth: str = "frown") -> None:
    skull = union(ellipse(hx, hy - 1, 8.2, 6.0), ellipse(hx + 0.5, hy + 2.0, 8.8, 4.6))
    f.add(skull, WFUR, centre=(hx - 2.5, hy - 2.5), radius=(10.5, 8.5), bias=0.26)
    # brown patch over the back eye and ear side, and a small one on the crown
    patch = {(x, y) for (x, y) in ellipse(hx - 4.0, hy - 2.0, 4.2, 4.0) if (x, y) in skull}
    f.recolor(patch, "brown")
    f.recolor({(x, y) for (x, y) in patch if x + y > hx - 4 + hy - 2 + 2}, "brown_d")
    f.recolor({(x, y) for (x, y) in patch if x + y < hx - 4 + hy - 2 - 3}, "gold_d")
    # rose ears folded back
    for ex, ey, s in ((hx - 6.5, hy - 5.0, 1), (hx + 1.5, hy - 6.2, 0)):
        ear = poly([(ex - 0.5, ey - 1.2), (ex + 3.2, ey - 1.0), (ex + 1.5, ey + 1.6), (ex - 1.6, ey + 2.4)])
        f.add(ear, EARM if s else PATCH, centre=(ex, ey - 1), radius=(3, 3), bias=0.1)
    # muzzle: flat, wide, with jowls and a wrinkle over the nose
    muzzle = union(ellipse(hx + 5.6, hy + 2.2, 4.2, 3.0), ellipse(hx + 3.0, hy + 3.6, 3.8, 2.6))
    f.add(muzzle, WFUR, centre=(hx + 4.0, hy + 0.5), radius=(5.0, 4.2), sep=True, bias=0.2)
    hxi, hyi = int(round(hx)), int(round(hy))
    # nose wrinkle and big flat nose at the front
    f.dots([(hxi + 4, hyi - 1), (hxi + 5, hyi - 1), (hxi + 6, hyi - 2)], "fog")
    f.dots([(hxi + 7, hyi), (hxi + 8, hyi), (hxi + 9, hyi), (hxi + 8, hyi + 1), (hxi + 9, hyi + 1)], "umber")
    f.dot(hxi + 8, hyi, "slate")
    # jowls: shadow under the muzzle
    f.recolor({(x, y) for (x, y) in muzzle if y >= hyi + 5}, "fog")
    ex, ey = hxi + 3, hyi - 2
    if eyes == "open":
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1), (ex, ey + 2), (ex + 1, ey + 2)], "umber")
        f.dot(ex, ey, "white")
        f.dot(ex + 1, ey + 2, "brown_d")
        f.dots([(ex - 1, ey - 1), (ex, ey - 1), (ex + 1, ey - 2), (ex + 2, ey - 2)], "ash")
    elif eyes == "closed":
        f.dots([(ex - 1, ey + 1), (ex, ey + 1), (ex + 1, ey + 1)], "umber")
    elif eyes == "happy":
        f.dots([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1)], "umber")
    elif eyes == "x":
        f.dots([(ex - 1, ey - 1), (ex + 1, ey + 1), (ex + 1, ey - 1), (ex - 1, ey + 1), (ex, ey)], "umber")
    elif eyes == "wink":
        f.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], "umber")
        f.dot(ex, ey, "white")
        f.dots([(ex - 2, ey - 1), (ex - 1, ey - 1)], "ash")
    # blush
    f.dots([(ex + 1, ey + 4), (ex + 2, ey + 4)], "pink")
    # mouth with the underbite: lower lip juts out, two little teeth
    mx, my = hxi + 7, hyi + 4
    if mouth == "frown":
        f.dots([(mx - 4, my - 1), (mx - 3, my), (mx - 2, my), (mx - 1, my), (mx, my), (mx + 1, my - 1)], "slate")
        f.dots([(mx - 2, my - 1), (mx, my - 1)], "white")
        f.dots([(mx - 3, my - 1), (mx - 1, my - 1)], "ash")
    elif mouth == "open":
        f.dots([(mx - 2, my - 1), (mx - 1, my - 1), (mx, my - 1), (mx + 1, my - 1), (mx - 1, my), (mx, my)], "wine")
        f.dots([(mx - 1, my + 1), (mx, my + 1)], "pink")
        f.dots([(mx - 1, my - 2), (mx + 1, my - 2)], "white")
    elif mouth == "grit":
        f.dots([(mx - 3, my - 1), (mx - 2, my - 1), (mx - 1, my - 1), (mx, my - 1), (mx + 1, my - 1)], "slate")
        f.dots([(mx - 2, my - 2), (mx - 1, my - 2), (mx, my - 2), (mx + 1, my - 2)], "white")


def body(f: Fig, bx: float, by: float) -> None:
    torso = union(ellipse(bx, by, 7.0, 5.0), rect(int(bx - 6), int(by), 13, 4))
    f.add(torso, TUNIC, centre=(bx - 1.5, by - 2), radius=(7.5, 6.0), bias=0.06)
    # tabard cross and belt
    cx, cy = int(round(bx + 0.5)), int(round(by - 1))
    f.dots([(cx, cy - 2), (cx, cy - 1), (cx, cy), (cx, cy + 1), (cx - 1, cy - 1), (cx + 1, cy - 1)], "yellow")
    f.dots([(cx, cy + 1), (cx + 1, cy - 1)], "gold")
    belt = {(x, y) for (x, y) in torso if y == int(by + 2)}
    f.recolor(belt, "brown")
    f.recolor({(x, y) for (x, y) in torso if y == int(by + 3)}, "water_d")
    f.dots([(cx - 1, int(by + 2)), (cx, int(by + 2))], "yellow")
    # chest fur
    ruff = ellipse(bx + 1.5, by - 4.2, 4.0, 1.8)
    f.add(ruff, WFUR, centre=(bx, by - 5), radius=(4, 2), sep=True, bias=0.06)


def leg(f: Fig, x: float, top: float, lift: int = 0, dx: float = 0.0, far: bool = False) -> None:
    foot_y = GROUND - lift
    s = union(rect(int(round(x + dx * 0.5)) - 1, int(top), 4, int(foot_y - top) - 1),
              capsule(x + 0.5, top, x + dx + 0.5, foot_y - 1.5, 1.6))
    f.add(s, WFUR, mode="cyl_v", centre=(x + dx, foot_y), radius=(2.2, 4), bias=-0.15 if far else 0.0)
    px_ = int(round(x + dx))
    f.add(rect(px_ - 1, foot_y - 1, 5, 2), WFUR, flat=1 if far else 2)


def shield(f: Fig, sx: float, sy: float, face: bool = True) -> None:
    """Round shield centred at (sx, sy): steel rim, blue face, yellow cross, rivets."""
    rim = ellipse(sx, sy, 5.6, 6.0)
    f.add(rim, STEEL, centre=(sx - 1.5, sy - 2), radius=(6.5, 7), bias=0.05)
    inner = ellipse(sx, sy, 4.0, 4.4)
    f.add(inner, SHIELD, centre=(sx - 1.5, sy - 2), radius=(5, 5.5), sep=True, bias=0.04)
    cx, cy = int(round(sx - 0.5)), int(round(sy - 0.5))
    if face:
        cross = {(cx, y) for y in range(cy - 3, cy + 4)} | {(x, cy - 1) for x in range(cx - 2, cx + 3)}
        cross |= {(cx + 1, y) for y in range(cy - 2, cy + 4)} | {(x, cy) for x in range(cx - 1, cx + 4)}
        f.recolor(cross, "gold_d")
        f.recolor({(cx, y) for y in range(cy - 3, cy + 4)} | {(x, cy - 1) for x in range(cx - 2, cx + 3)}, "yellow")
        f.dot(cx, cy - 3, "cream")
    for (rx, ry) in ((cx - 4, cy), (cx + 5, cy), (cx, cy - 5), (cx + 1, cy + 5)):
        f.dot(rx, ry, "steel_l")


def arm(f: Fig, sx: float, sy: float, hx: float, hy: float) -> None:
    s = union(capsule(sx, sy, hx, hy, 1.7), ellipse(hx, hy, 2.0, 1.9))
    f.add(s, WFUR, centre=(hx - 1, hy - 1), radius=(3, 3), bias=0.1)


def bulldog_frame(bob: int = 0, lean: float = 0.0, eyes: str = "open", mouth: str = "frown",
                  legs=((0, 0.0), (0, 0.0)), shield_at=None, head_dy: int = 0, extra=None, tail_up: int = 0) -> Fig:
    f = Fig(W, W, seed=11)
    bx, by = 13.5 + lean, 22.0 + bob
    hx, hy = 13.5 + lean * 1.3, 11.5 + bob + head_dy
    # stubby tail
    f.add(ellipse(bx - 7.0, by - 1.0 - tail_up, 1.6, 1.6), WFUR, bias=0.1)
    (fl, fdx), (nl, ndx) = legs
    leg(f, bx - 3.5, by + 2, fl, fdx, far=True)
    leg(f, bx + 2.0, by + 2, nl, ndx)
    body(f, bx, by)
    head(f, hx, hy, eyes, mouth)
    if shield_at is None:
        shield_at = (bx + 8.0, by + 0.5)
    arm(f, bx + 3.0, by - 2.0, shield_at[0] - 2.0, shield_at[1] + 0.5)
    shield(f, shield_at[0], shield_at[1])
    if extra:
        extra(f)
    return f


def _stars(f: Fig, x: int, y: int) -> None:
    for (sx, sy) in ((x, y), (x + 10, y + 2)):
        f.dots([(sx, sy - 1), (sx - 1, sy), (sx + 1, sy), (sx, sy + 1)], "yellow")
        f.dot(sx, sy, "white")


def bulldog_v25() -> list:
    old = art_heroes.bulldog_v2()
    fr: dict[str, list] = {}
    fr["idle"] = [bulldog_frame().render(), bulldog_frame(bob=1).render(),
                  bulldog_frame(bob=1, tail_up=1).render(), bulldog_frame(eyes="closed").render()]
    run_legs = [((0, -2.5), (0, 2.5)), ((1, -1.0), (0, 1.0)), ((2, 1.0), (0, -1.0)),
                ((0, 2.5), (0, -2.5)), ((0, 1.0), (1, -1.0)), ((0, -1.0), (2, 1.0))]
    run_bob = [0, 1, -1, 0, 1, -1]
    fr["run"] = [bulldog_frame(bob=run_bob[i], lean=0.5, legs=run_legs[i], tail_up=i % 2,
                               shield_at=(22.5, 22.0 + run_bob[i])).render() for i in range(6)]
    fr["attack"] = [
        bulldog_frame(lean=-1.0, mouth="grit", shield_at=(19.5, 21.5)).render(),
        bulldog_frame(lean=1.5, mouth="grit", shield_at=(24.5, 21.0), legs=((0, -1.5), (0, 1.5))).render(),
        bulldog_frame(lean=2.0, mouth="open", shield_at=(25.0, 21.0), legs=((0, -2.0), (0, 2.0))).render(),
        bulldog_frame(lean=0.5, shield_at=(22.0, 22.0)).render(),
    ]
    fr["hurt"] = [bulldog_frame(lean=-1.5, head_dy=1, eyes="x", mouth="open", extra=lambda f: _stars(f, 7, 3)).render(),
                  bulldog_frame(lean=-1.0, eyes="x", extra=lambda f: _stars(f, 8, 4)).render()]
    fr["guard"] = [bulldog_frame(lean=-0.5, eyes="open", mouth="grit", shield_at=(22.0, 17.0), bob=1).render(),
                   bulldog_frame(lean=-0.5, eyes="open", mouth="grit", shield_at=(22.0, 17.0), bob=1,
                                 extra=lambda f: f.dots([(20, 11), (21, 11), (21, 12)], "white")).render()]
    fr["victory"] = [
        bulldog_frame(eyes="happy", mouth="open").render(),
        bulldog_frame(bob=-2, eyes="happy", mouth="open", shield_at=(22.0, 20.0), tail_up=1,
                      legs=((2, 0.0), (2, 0.0))).render(),
        bulldog_frame(bob=-3, eyes="wink", mouth="open", shield_at=(22.0, 19.0), tail_up=1,
                      legs=((3, 0.0), (3, 0.0))).render(),
        bulldog_frame(eyes="happy", mouth="frown").render(),
    ]
    return frames_like(old, fr)
