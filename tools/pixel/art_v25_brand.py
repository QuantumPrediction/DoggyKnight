"""v2.5 (CR4) app icon portrait, redrawn with the rig renderer.

Goldie's head and shoulders in 3/4 view facing right (big glossy eye, floppy ear, cream muzzle, smiling
with her tongue out), red cape collar and steel pauldron. Painted directly at 64x64 for the large icons
(store icons, adaptive foreground) and again at 32x32 for icon_master_32 - never downscaled.
"""

from __future__ import annotations

from art_v25_goldie import CAPE, EAR, FUR, FUR_HI, STEEL, TRIM
from rig import Fig, capsule, ellipse, poly, union


def icon_portrait(size: int = 64):
    k = size / 64.0
    f = Fig(size, size, seed=9)

    def P(x: float, y: float) -> tuple[float, float]:
        return x * k, y * k

    def E(x: float, y: float, rx: float, ry: float):
        return ellipse(x * k, y * k, rx * k, ry * k)

    # shoulders: red cape collar, steel pauldron, cream chest fur, gold clasp
    cape_s = poly([P(4, 64), P(10, 50), P(24, 45), P(44, 45), P(58, 52), P(62, 64)])
    f.add(cape_s, CAPE, centre=P(22, 46), radius=(30 * k, 18 * k), bias=0.05)
    f.add(E(47, 56, 11, 7.5), STEEL, centre=P(43, 52), radius=(12 * k, 9 * k), bias=0.05)
    f.add(E(31, 51, 9, 5), FUR_HI, centre=P(29, 48), radius=(9 * k, 5 * k), bias=0.05)
    f.add(E(21, 55, 3, 3), TRIM, bias=0.1)
    # far ear peeking behind the crown
    f.add(poly([P(38, 9), P(47, 7), P(50, 15), P(44, 19)]), EAR, centre=P(42, 9), radius=(6 * k, 6 * k), bias=0.05)
    skull = union(E(30, 29, 19, 16.5), E(29, 24, 17, 14))
    f.add(skull, FUR, centre=P(24, 20), radius=(22 * k, 20 * k), bias=0.14)
    muzzle = union(E(44, 37, 11, 8), E(38, 40, 8, 6))
    f.add(muzzle, FUR_HI, centre=P(40, 33), radius=(12 * k, 9 * k), sep=False, bias=0.06)
    ear = union(poly([P(8, 20), P(18, 15), P(22, 26), P(20, 44), P(13, 49), P(7, 42), P(5, 30)]), E(12, 44, 5.5, 5))
    f.add(ear, EAR, centre=P(12, 20), radius=(10 * k, 18 * k), bias=0.08)
    w = 0.5 * max(1.0, k)
    for (x0, y0, x1, y1, c) in ((24, 14, 27, 18, "gold_l"), (29, 13, 31, 17, "gold_l"), (12, 28, 14, 36, "gold_d"),
                                (15, 32, 16, 40, "gold_d")):
        f.recolor(capsule(x0 * k, y0 * k, x1 * k, y1 * k, w), c)
    f.recolor(capsule(21 * k, 12 * k, 26 * k, 11 * k, w), "cream")
    r = max(1, round(2 * k))
    # eyes: a big glossy near eye and a smaller far eye
    ex, ey = round(34 * k), round(24 * k)
    f.dots({(ex + dx, ey + dy) for dx in range(3 * r) for dy in range(4 * r + 1)}, "umber")
    f.dots({(ex + dx, ey + dy) for dx in range(3 * r) for dy in range(3 * r + 1, 4 * r + 1)}, "brown")
    f.dots({(ex + dx, ey + dy) for dx in range(r) for dy in range(r)}, "white")
    if r > 1:
        f.dot(ex + 2 * r, ey + 2 * r + 1, "white")
    fx, fy = round(46 * k), round(23 * k)
    f.dots({(fx + dx, fy + dy) for dx in range(2 * r) for dy in range(3 * r + 1)}, "umber")
    f.dot(fx, fy, "white")
    f.dots({(ex - r + i, ey - 2 * r) for i in range(3 * r)}, "gold_d")
    f.dots({(ex + i, ey + 6 * r) for i in range(2 * r + 1)}, "pink")
    # nose, smile and tongue
    nx, ny = round(52 * k), round(31 * k)
    f.dots({(nx + dx, ny + dy) for dx in range(-2 * r, 2 * r) for dy in range(2 * r + 1)}, "umber")
    f.dot(nx - r, ny, "slate")
    mx, my = round(46 * k), round(40 * k)
    f.dots({(mx - 3 * r + i, my) for i in range(6 * r)}, "brown_d")
    f.dots({(mx - r + dx, my + 1 + dy) for dx in range(2 * r + 1) for dy in range(2 * r)}, "pink")
    f.dot(mx + r, my + 2 * r, "rose")
    return f.render()
