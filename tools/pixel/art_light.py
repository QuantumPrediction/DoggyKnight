"""v2.3 graphics pass (CS5): light sprites, foreground depth, vignette and rain sheets.

Mobile-first: no Light2D. Lights are Sprite2D with an additive CanvasItemMaterial and one shared
pixel glow texture (stepped, dithered falloff). Outputs:

  assets/fx/lights/glow.png                  64x64 white glow (alpha steps), tinted by modulate
  assets/fx/lights/glow_<px>.png             the same glow at each light's own size, so every light is
                                             drawn at scale 1 and its dither stays on the pixel grid
  assets/fx/lights/<name>.tscn               ready-made light sprites any line can add as a child:
                                             torch, campfire, lantern, magic, eye_violet, visor_blue,
                                             sword, sun, ultimate (script light_flicker.gd)
  assets/backgrounds/anim/rain_sheet.png     tileable slanted rain streaks (bridge)
  assets/backgrounds/<name>_fg.png           per-scene foreground: silhouettes + vignette, painted ONLY
                                             outside the game area or in the strips of it no actor can
                                             reach (bottom strip, top corners) - never over the arena

`decorate(name, scene)` fills scene.lights / scene.fg / scene.rain for art_world.background_tscn().
"""

from __future__ import annotations

import math
import random

import art_world as AW
import paint as P
from pixel import Canvas, res_path, write_text

GLOW = 64
# image-space rectangles (the background image is 304x512 placed at world (-62, -88))
GAME = (62, 88, 242, 408)                     # world (0,0)-(180,320)
ARENA = (AW.AX0, AW.AY0, AW.AX1, AW.AY1)      # world (2,72)-(178,296)

LIGHTS = {
    # name: (rgb, size in px, base_alpha, flicker, flicker_speed, pulse)
    "torch": ((1.0, 0.62, 0.25), 44, 0.55, 0.3, 11.0, 0.0),
    "campfire": ((1.0, 0.55, 0.2), 96, 0.6, 0.25, 8.0, 0.1),
    "lantern": ((1.0, 0.78, 0.42), 52, 0.5, 0.12, 5.0, 0.0),
    "magic": ((0.75, 0.55, 1.0), 52, 0.5, 0.05, 6.0, 0.3),
    "eye_violet": ((0.8, 0.45, 1.0), 20, 0.7, 0.1, 7.0, 0.25),
    "visor_blue": ((0.45, 0.8, 1.0), 22, 0.6, 0.15, 9.0, 0.0),
    "sword": ((1.0, 0.95, 0.7), 56, 0.45, 0.0, 1.0, 0.3),
    "sun": ((1.0, 0.86, 0.6), 192, 0.22, 0.0, 1.0, 0.08),
    "ultimate": ((1.0, 0.9, 0.55), 128, 0.7, 0.0, 1.0, 0.2),
}


def glow_texture(size: int = GLOW) -> Canvas:
    """White glow: alpha falls off in a few steps with an ordered dither between them (pixel look)."""
    c = Canvas(size, size)
    r = size / 2
    levels = [0, 40, 80, 130, 190, 255]
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - r, y + 0.5 - r) / r
            if d >= 1:
                continue
            v = (1 - d) ** 1.7 * (len(levels) - 1)
            i = int(v)
            frac = v - i
            k = i + (1 if frac > P.bayer(x, y) and i < len(levels) - 1 else 0)
            if levels[k]:
                c.set(x, y, P.alpha_px("white", levels[k]))
    return c


def light_tscn(name: str) -> str:
    rgb, size, base, flicker, speed, pulse = LIGHTS[name]
    return "\n".join([
        '[gd_scene format=3]',
        '',
        '[ext_resource type="Texture2D" path="res://assets/fx/lights/glow_%d.png" id="1_glow"]' % size,
        '[ext_resource type="Script" path="res://assets/fx/lights/light_flicker.gd" id="2_flicker"]',
        '',
        '[sub_resource type="CanvasItemMaterial" id="Mat_add"]',
        'blend_mode = 1',
        '',
        '[node name="%s" type="Sprite2D"]' % "".join(p.capitalize() for p in name.split("_")),
        'modulate = Color(%g, %g, %g, %g)' % (rgb + (base,)),
        'material = SubResource("Mat_add")',
        'texture = ExtResource("1_glow")',
        'script = ExtResource("2_flicker")',
        'base_alpha = %g' % base,
        'flicker = %g' % flicker,
        'flicker_speed = %g' % speed,
        'pulse = %g' % pulse,
        '',
    ])


def rain_sheet_texture() -> Canvas:
    c = Canvas(64, 64)
    rng = random.Random(77)
    for _ in range(9):
        x, y = rng.randrange(64), rng.randrange(64)
        ln = rng.randrange(10, 22)
        col = rng.choice(["lilac", "steel_l", "white"])
        for k in range(ln):
            px, py = (x - k // 4) % 64, (y + k) % 64
            c.set(px, py, P.alpha_px(col, 110 if k % 3 else 160))
    return c


def write_shared() -> None:
    glow_texture().save(res_path("res://assets/fx/lights/glow.png"))
    for size in sorted({v[1] for v in LIGHTS.values()}):
        glow_texture(size).save(res_path("res://assets/fx/lights/glow_%d.png" % size))
    for name in LIGHTS:
        write_text(res_path("res://assets/fx/lights/%s.tscn" % name), light_tscn(name))
    rain_sheet_texture().save(res_path("res://assets/backgrounds/anim/rain_sheet.png"))


# --------------------------------------------------------------------------
# foreground painting
# --------------------------------------------------------------------------

def allowed(x: int, y: int) -> bool:
    """Foreground may only cover the extended area, the strip below the arena and the top corners."""
    gx0, gy0, gx1, gy1 = GAME
    if not (gx0 <= x < gx1 and gy0 <= y < gy1):
        return True
    wy = y + AW.ORIGIN[1]
    wx = x + AW.ORIGIN[0]
    if wy >= 306:
        return True
    if wy < 36 and (wx < 26 or wx > 154):
        return True
    return False


def vignette(fg: Canvas, strength: float = 0.5) -> None:
    """Stepped darkening outside the game area only (seen on taller or wider phones)."""
    gx0, gy0, gx1, gy1 = GAME
    for y in range(fg.h):
        for x in range(fg.w):
            dx = max(gx0 - x, 0, x - (gx1 - 1))
            dy = max(gy0 - y, 0, y - (gy1 - 1))
            d = math.hypot(dx, dy)
            if d <= 0:
                continue
            a = min(1.0, d / 70.0) * strength
            step = int(a * 6 + P.bayer(x, y) * 0.999) / 6
            if step > 0:
                fg.set(x, y, P.alpha_px("ink", int(255 * step)))


def put(fg: Canvas, src: Canvas, ox: int, oy: int) -> None:
    for y in range(src.h):
        for x in range(src.w):
            p = src.get(x, y)
            if p is not None and p[3] > 0 and allowed(ox + x, oy + y):
                fg.set(ox + x, oy + y, p)


def foliage(w: int, h: int, seed: int, ramp, outline: str, hang: bool = True) -> Canvas:
    rng = random.Random(seed)
    blobs = []
    for k in range(max(3, w // 7)):
        bx = rng.uniform(4, w - 4)
        by = rng.uniform(3, h * (0.55 if hang else 0.9))
        blobs.append((bx, by, rng.uniform(4.5, 7.5)))
    return AW.blob_canvas(w, h, blobs, list(ramp), outline, seed, texture=0.15)


def clumps(fg: Canvas, seed: int, ramp, outline: str, flowers=None, y_top: int = 398, gap=(14, 30)) -> None:
    """Near bushes / grass clumps along the bottom edge, with gaps so the ground still shows."""
    rng = random.Random(seed)
    x = -8 + rng.randrange(0, 10)
    while x < fg.w:
        w = rng.randrange(20, 40)
        h = rng.randrange(18, 30)
        bush = AW.blob_canvas(w, h, [(w * 0.3, h * 0.55, h * 0.42), (w * 0.62, h * 0.45, h * 0.5),
                                     (w * 0.5, h * 0.8, h * 0.45)], list(ramp), outline, seed + x, texture=0.18)
        if flowers:
            for _ in range(rng.randrange(1, 4)):
                fx, fy = rng.randrange(3, w - 3), rng.randrange(3, h // 2 + 2)
                if bush.opaque(fx, fy):
                    col = rng.choice(flowers)
                    for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if bush.opaque(fx + dx, fy + dy):
                            bush.set(fx + dx, fy + dy, col)
                    bush.set(fx, fy, "yellow")
        # a few grass blades sticking up out of the clump
        for _ in range(rng.randrange(2, 6)):
            bx = rng.randrange(2, w - 2)
            for k in range(rng.randrange(3, 7)):
                bush.set(bx + (k // 3) * rng.choice([-1, 1]), 2 - k + h // 5, ramp[1])
        put(fg, bush, x, y_top + rng.randrange(0, 12))
        x += w + rng.randrange(*gap)


def wheat_clumps(fg: Canvas, seed: int, y_top: int = 396) -> None:
    rng = random.Random(seed)
    x = -6
    while x < fg.w:
        n = rng.randrange(5, 10)
        base = y_top + 30 + rng.randrange(0, 10)
        for k in range(n):
            sx = x + k * 2 + rng.randrange(-1, 2)
            h = rng.randrange(18, 32)
            sway = rng.choice([-1, 0, 1])
            for j in range(h):
                xx, yy = sx + (sway * j) // 9, base - j
                if allowed(xx, yy):
                    fg.set(xx, yy, "brown_d" if j < h - 6 else "brown")
            for j in range(5):
                xx, yy = sx + (sway * (h + j)) // 9, base - h - j
                for dx in (0, 1):
                    if allowed(xx + dx, yy):
                        fg.set(xx + dx, yy, "gold_d" if (j + dx) % 2 else "brown")
        x += n * 2 + rng.randrange(10, 26)


def pine_branch(w: int, h: int, seed: int, flip: bool) -> Canvas:
    c = Canvas(w, h)
    rng = random.Random(seed)
    for k in range(5):
        y0 = rng.randrange(2, h - 4)
        ln = rng.randrange(w // 2, w)
        for i in range(ln):
            x = i
            y = y0 + i // 5
            c.set(x, y, "night_d")
            for j in range(1, 4):
                if (i + j) % 3 == 0:
                    c.set(x - j // 2, y + j, "forest_d")
                    c.set(x - j // 2, y - j, "forest_d")
    c.outline_all("ink")
    return c.flipped() if flip else c


def fern(seed: int, ramp=("night_d", "forest_d", "forest")) -> Canvas:
    c = Canvas(22, 20)
    rng = random.Random(seed)
    for k in range(5):
        ang = -math.pi / 2 + (k - 2) * 0.45
        for i in range(16):
            x = int(11 + math.cos(ang) * i * 0.8 + (i * i) * 0.02 * (k - 2))
            y = int(19 + math.sin(ang) * i)
            c.set(x, y, ramp[1])
            if i % 2 == 0:
                c.set(x - 1, y + 1, ramp[0])
                c.set(x + 1, y + 1, ramp[2] if rng.random() < 0.4 else ramp[0])
    return c


def sunflower(seed: int) -> Canvas:
    c = Canvas(12, 30)
    for y in range(8, 30):
        c.set(6, y, "forest" if y % 4 else "forest_d")
    c.stamp(["ff.", ".ff"], 7, 16, {"f": "leaf_d"}, outline=None)
    c.stamp([".ff", "ff."], 3, 21, {"f": "leaf_d"}, outline=None)
    for (x, y) in P.ellipse(6, 5, 5, 4.5):
        c.set(x, y, "orange" if (x + y) % 3 else "yellow")
    for (x, y) in P.ellipse(6, 5, 2.4, 2.2):
        c.set(x, y, "brown_d")
    c.outline_all("ink")
    return c


def parapet(w: int, h: int) -> Canvas:
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            brick = y % 7 == 6 or (x + (6 if (y // 7) % 2 else 0)) % 12 == 11
            c.set(x, y, "ink" if brick else ("night_d" if (x + y) % 5 else "night"))
    for x in range(w):
        c.set(x, 0, "steel_d")
    return c


# --------------------------------------------------------------------------
# per-scene decoration
# --------------------------------------------------------------------------

def _world(ix: float, iy: float) -> tuple[float, float]:
    return ix + AW.ORIGIN[0], iy + AW.ORIGIN[1]


def decorate(name: str, sc) -> None:
    fg = Canvas(AW.IMG_W, AW.IMG_H)
    sc.lights = []          # (light name, world x, world y, scale multiplier, alpha multiplier, seed)
    sc.fg_lights = []
    sc.rain = False
    vignette(fg, 0.55 if name in ("crow_forest", "bridge") else 0.4)
    torch_size = AW.ANIMS["torch"][1]
    for (kind, ix, iy, frame, speed, flip) in sc.anims:
        if kind == "torch":
            wx, wy = _world(ix + torch_size[0] / 2, iy + 2)
            target = sc.fg_lights if not (2 <= wx <= 178 and 72 <= wy <= 296) else sc.lights
            target.append(("torch", wx, wy, 1.0, 1.0, (ix * 7 + iy) % 10 * 0.37))
        elif kind == "sword_glint":
            wx, wy = _world(ix + 4, iy + 6)
            sc.lights.append(("sword", wx, wy, 1.0, 1.0, 0.0))
        elif kind == "eyes":
            wx, wy = _world(ix + 2, iy + 1)
            sc.lights.append(("eye_violet", wx, wy, 0.8, 0.8, ix * 0.13))
    if name == "sword_stone":
        sc.lights.append(("sun", -40, -70, 1.0, 1.0, 0.0))
        for side, x in ((0, -4), (1, 196)):
            br = foliage(64, 34, 300 + side, ("forest_d", "forest", "leaf_d", "leaf"), "forest_d")
            put(fg, br.flipped() if side else br, x, 70)
        clumps(fg, 5, ("forest_d", "forest", "leaf_d", "leaf"), "forest_d", flowers=["white", "pink"])
    elif name == "wheat_field":
        sc.lights.append(("sun", 210, -60, 1.0, 1.1, 0.0))
        wheat_clumps(fg, 6)
        for side, x in ((0, 0), (1, 252)):
            ears = Canvas(52, 40)
            rng = random.Random(40 + side)
            for k in range(7):
                bx = rng.randrange(4, 48)
                for j in range(rng.randrange(18, 38)):
                    ears.set(bx + j // 9, j, "brown_d" if j < 26 else "gold_d")
            put(fg, ears.flipped() if side else ears, x, 80)
    elif name == "meadow":
        sc.lights.append(("sun", -30, -60, 0.9, 0.9, 0.0))
        bloom = foliage(70, 36, 330, ("rose", "pink", "peach", "white"), "rose")
        put(fg, bloom, 230, 74)
        leaves = foliage(60, 32, 331, ("forest_d", "forest", "leaf_d", "leaf"), "forest_d")
        put(fg, leaves, -2, 76)
        clumps(fg, 7, ("forest_d", "forest", "leaf_d", "leaf"), "forest_d", flowers=["pink", "white", "lilac"])
    elif name == "farm_fence":
        sc.lights.append(("sun", 90, -110, 1.2, 1.2, 0.0))
        bx, by = _world(150 + 30, 30 + 34)   # barn door
        sc.lights.append(("lantern", bx, by, 1.0, 1.0, 0.0))
        clumps(fg, 9, ("forest", "moss_d", "moss", "leaf_l"), "forest_d", gap=(24, 44))
        for k, x in enumerate((8, 40, 236, 270)):
            put(fg, sunflower(k), x, 388 + (k % 2) * 6)
        for x in (0, 284):
            post = Canvas(10, 40)
            post.rect(2, 0, 6, 40, "brown_d")
            post.rect(2, 0, 2, 40, "brown")
            post.outline_all("ink")
            put(fg, post, x, 398)
    elif name == "crow_forest":
        for side, x in ((0, -6), (1, 248)):
            put(fg, pine_branch(66, 40, 500 + side, side == 1), x, 68)
        for k, x in enumerate((-2, 30, 64, 210, 246, 280)):
            put(fg, fern(k), x, 392 + (k % 3) * 3)
        clumps(fg, 11, ("night_d", "forest_d", "forest", "leaf_d"), "ink", gap=(26, 46))
    elif name == "bridge":
        sc.rain = True
        for x in (0, 248):
            put(fg, parapet(56, 110), x, 402)
        for x in (0, 258):
            for y in range(70, 140):
                if (y // 3) % 2 == 0:
                    for dx in (0, 1):
                        if allowed(x + 20 + dx + (y % 6 == 0), y):
                            fg.set(x + 20 + dx, y, "iron" if dx else "steel_d")
    # per-level grading (v2.3): the three daytime scenes get a whisper of colour too
    grading = {"sword_stone": (1.0, 0.985, 0.95), "wheat_field": (1.0, 0.97, 0.9), "meadow": (0.98, 1.0, 0.97)}
    if sc.modulate is None and name in grading:
        sc.modulate = grading[name]
    sc.fg = fg
