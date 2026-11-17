"""v2.6 (C 世界) scenery kit: painters, props, animated layers and the .tscn writer shared by the
chapter 2-3 backgrounds (art_v26_world.py), the chapter 1 repaint (art_v26_ch1.py) and the title
backdrops (art_v26_title.py). Python 3 standard library only.

Rules of the look (DEV_PLAN 19, owner: 「再修一輪背景和標題」):
- three depth layers above the arena: far (hazy, pale, low contrast, palette "air" colours),
  mid (full colour silhouettes) and near (dark, saturated framing that also lives in the fg layer);
- shading comes from shapes (lit left faces, shaded right faces, rim lights) and wide bands,
  never from per-column slope flips (the old title mountains) or noisy dither;
- the arena floor is always mid-toned with two close tones and a darker grout, so actors,
  shadows and red telegraphs read first.

Scenes reuse art_world.Scene (304x512 image placed at world (-62, -88); the arena is image
64..240 x 160..384) and art_world.background_tscn().
"""

from __future__ import annotations

import math
import random

import art_light as AL
import art_world as AW
import paint as P
from art_world import AX0, AX1, AY0, AY1, IMG_H, IMG_W, DARKER, LIGHTER, fbm, hash01, name_at, shade
from pixel import Anim, Canvas, build_sheet, line_points, res_path, write_text

# image-space rectangles
GAME = AL.GAME                      # world (0,0)-(180,320)


def dk(c: str, n: int = 1) -> str:
    for _ in range(n):
        c = DARKER.get(c, c)
    return c


def lt(c: str, n: int = 1) -> str:
    for _ in range(n):
        c = LIGHTER.get(c, c)
    return c


# --------------------------------------------------------------------------
# sky, celestial bodies, distant land
# --------------------------------------------------------------------------

def sky_bands(img: Canvas, y0: int, y1: int, bands: list[tuple[str, float]], wave: float = 1.6,
              seed: int = 0, x0: int = 0, x1: int | None = None) -> None:
    """Horizontal colour bands (t from 0 at y0 to 1 at y1) whose edges wave gently - no dither."""
    x1 = img.w if x1 is None else x1
    span = max(1, y1 - y0)
    for y in range(y0, y1):
        for x in range(x0, x1):
            t = (y - y0 + wave * math.sin(x / 13.0 + seed + y * 0.07) + wave * 0.6 * math.sin(x / 5.3 + seed * 2)) / span
            col = bands[0][0]
            for n, t0 in bands:
                if t >= t0:
                    col = n
            img.set(x, y, col)


def stars(img: Canvas, rect: tuple[int, int, int, int], n: int, seed: int,
          cols=("white", "steel_l", "lilac", "sky_l"), big: int = 3) -> list[tuple[int, int]]:
    rng = random.Random(seed)
    x0, y0, x1, y1 = rect
    out = []
    for i in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        img.set(x, y, rng.choice(cols))
        out.append((x, y))
        if i < big:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img.set(x + dx, y + dy, "lilac")
            img.set(x, y, "white")
    return out


def moon(img: Canvas, cx: float, cy: float, r: float, halo: tuple[str, ...] = ("night", "water_d"),
         body=("fog", "steel_l", "white"), crescent: float = 0.0) -> None:
    """A soft full (or crescent) moon with one or two flat halo rings and gentle maria."""
    for k, col in enumerate(halo):
        rr = r + 6 + (len(halo) - 1 - k) * 5
        for y in range(int(cy - rr), int(cy + rr) + 1):
            for x in range(int(cx - rr), int(cx + rr) + 1):
                if math.hypot(x + 0.5 - cx, y + 0.5 - cy) < rr + 0.6 * math.sin(x * 0.7 + y * 0.4):
                    img.set(x, y, col)
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d > r:
                continue
            if crescent and math.hypot(x + 0.5 - cx - r * crescent, y + 0.5 - cy + r * 0.25) < r * 0.92:
                continue
            nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            v = -0.5 * nx - 0.45 * ny + 0.55
            col = body[2] if v > 0.62 else (body[1] if v > 0.18 else body[0])
            if not crescent and fbm(x, y, 9, 5, 2) > 0.62 and d < r - 1.5:
                col = dk(col)
            img.set(x, y, col)


def peaks_layer(img: Canvas, base: int, peaks: list[tuple[float, float, float]], lit: str, shade_col: str,
                rim: str | None = None, snow: tuple[str, str] | None = None, seed: int = 0,
                x0: int = 0, x1: int | None = None, rough: float = 1.5, fill_to: int | None = None) -> list[int]:
    """Mountains: each peak (x, height, half-width) is a slightly ragged triangle. The face left of the
    ridge line (which wanders down from the summit) is lit, the right face is in shade - one clean split
    per peak, so there are no stripes. Returns the top y per column."""
    x1 = img.w if x1 is None else x1
    fill_to = base if fill_to is None else fill_to
    tops = []
    for x in range(x0, x1):
        best, owner = 0.0, None
        for i, (px, ph, pw) in enumerate(peaks):
            h = ph * max(0.0, 1.0 - abs(x + 0.5 - px) / pw)
            if h > best:
                best, owner = h, i
        best += (fbm(x, 0, seed, 9, 2) - 0.5) * rough * 2
        top = int(base - best)
        tops.append(top)
        if owner is None:
            for y in range(top, fill_to):
                img.set(x, y, shade_col)
            continue
        px, ph, pw = peaks[owner]
        stop = int(base - ph)
        for y in range(top, fill_to):
            depth = y - stop
            split = px + depth * 0.35 + (fbm(0, y, seed + 7, 6, 2) - 0.5) * 6
            col = lit if x < split else shade_col
            if snow and y < top + 4 and best > ph * 0.55 and y < stop + ph * 0.4:
                col = snow[0] if x < split else snow[1]
            img.set(x, y, col)
        if rim:
            img.set(x, top, rim if x + 0.5 < px else lit)
    return tops


def hills_layer(img: Canvas, base: int, amp: float, period: float, col: str, rim: str | None = None,
                seed: int = 0, fill_to: int | None = None, x0: int = 0, x1: int | None = None,
                lumps: float = 0.4) -> list[int]:
    """Rolling hills silhouette (one colour) with a 1 px lit rim. Returns the top y per column."""
    x1 = img.w if x1 is None else x1
    fill_to = img.h if fill_to is None else fill_to
    tops = []
    for x in range(x0, x1):
        top = int(base - amp * (0.5 + 0.5 * math.sin(x / period + seed)) - amp * lumps * math.sin(x / (period * 0.37) + seed * 3))
        tops.append(top)
        for y in range(top, fill_to):
            img.set(x, y, col)
        if rim:
            img.set(x, top, rim)
    return tops


def treeline(img: Canvas, base: int, ramp: tuple[str, ...], seed: int, size=(5.0, 8.0), step: int = 6,
             outline: str | None = None, x0: int = -6, x1: int | None = None, jitter: int = 4,
             pointy: bool = False) -> None:
    """A row of round (or pointed) tree crowns: a distant forest silhouette with a lit top-left."""
    rng = random.Random(seed)
    x1 = img.w + 6 if x1 is None else x1
    x = x0
    while x < x1:
        r = rng.uniform(*size)
        if pointy:
            h = int(r * 3.2)
            w = int(r * 1.6) | 1
            c = Canvas(w + 2, h + 2)
            for yy in range(h):
                half = (yy / h) * w / 2
                for xx in range(int(w / 2 - half), int(w / 2 + half) + 1):
                    c.set(xx + 1, yy + 1, ramp[1] if xx < w / 2 - 0.5 else ramp[0])
                if yy % 4 == 3:
                    c.set(int(w / 2 - half), yy + 1, ramp[-1])
            if outline:
                c.outline_all(outline)
            img.blit(c, int(x - w / 2), base - h + rng.randrange(jitter + 1))
        else:
            blob = AW.blob_canvas(int(r * 2 + 3), int(r * 2 + 3), [(r + 1.5, r + 1.5, r)], list(ramp), outline,
                                  seed + int(x) * 3, texture=0.12)
            img.blit(blob, int(x - r), base - int(r * 1.6) + rng.randrange(jitter + 1))
        x += step + rng.randrange(-1, 3)


def fill_below(img: Canvas, tops: list[int], x0: int, y1: int, col: str) -> None:
    for i, t in enumerate(tops):
        for y in range(t, y1):
            img.set(x0 + i, y, col)


# --------------------------------------------------------------------------
# floors (arena-safe: two close tones, darker grout, no bright bevels)
# --------------------------------------------------------------------------

def flagstones(img: Canvas, rect: tuple[int, int, int, int], tones: tuple[str, str], grout: str, seed: int,
               mask=None, widths=(14, 24), heights=(10, 13), lip: str | None = None, worn: str | None = None,
               worn_rate: float = 0.0, crack_rate: float = 0.12) -> None:
    """Large irregular flagstones in rows. Each stone is one of two close tones; the joint is a 1 px
    `grout` line on its bottom and right edge only (light from the top-left); `lip` (optional) is a
    faint 1 px top highlight on some stones. `worn` paints a few soft 3x2 worn patches."""
    x0, y0, x1, y1 = rect
    rng = random.Random(seed)
    y = y0 - rng.randrange(0, heights[0])
    while y < y1:
        hgt = rng.randrange(heights[0], heights[1] + 1)
        x = x0 - rng.randrange(0, widths[0])
        while x < x1:
            wid = rng.randrange(widths[0], widths[1] + 1)
            tone = tones[0] if rng.random() < 0.55 else tones[1]
            has_lip = lip is not None and rng.random() < 0.35
            for yy in range(max(y, y0), min(y + hgt, y1)):
                for xx in range(max(x, x0), min(x + wid, x1)):
                    if mask is not None and not mask(xx, yy):
                        continue
                    if yy == y + hgt - 1 or xx == x + wid - 1:
                        col = grout
                    elif has_lip and yy == y and x < xx < x + wid - 2:
                        col = lip
                    else:
                        col = tone
                    img.set(xx, yy, col)
            if worn and rng.random() < worn_rate:
                wx, wy = x + rng.randrange(2, max(3, wid - 5)), y + rng.randrange(2, max(3, hgt - 4))
                for yy in range(wy, wy + 2):
                    for xx in range(wx, wx + 3 + (yy - wy)):
                        if (mask is None or mask(xx, yy)) and x0 <= xx < x1 and y0 <= yy < y1 \
                                and name_at(img, xx, yy) == tone:
                            img.set(xx, yy, worn)
            if rng.random() < crack_rate:
                cx0 = x + rng.randrange(3, max(4, wid - 3))
                pts = line_points(cx0, y + 2, cx0 + rng.randrange(-3, 4), y + hgt - 4)
                for (px, py) in pts:
                    if (mask is None or mask(px, py)) and x0 <= px < x1 and y0 <= py < y1:
                        img.set(px, py, grout)
            x += wid
        y += hgt


def cobbles(img: Canvas, rect: tuple[int, int, int, int], tones: tuple[str, ...], grout: str, seed: int,
            mask=None, cell=(7, 5)) -> None:
    """Rounded cobblestones on a staggered grid; each cobble has a lit top-left pixel row in its own
    tone family and the grout shows between them."""
    x0, y0, x1, y1 = rect
    cw, ch = cell
    for y in range(y0, y1):
        for x in range(x0, x1):
            if mask is not None and not mask(x, y):
                continue
            row = (y - y0) // ch
            off = (cw // 2) * (row % 2)
            cx = (x - x0 + off) // cw
            lx = (x - x0 + off) % cw
            ly = (y - y0) % ch
            corner = (lx in (0, cw - 1)) and (ly in (0, ch - 1))
            if lx == cw - 1 or ly == ch - 1 or corner:
                img.set(x, y, grout)
                continue
            tone = tones[int(hash01(cx, row, seed) * len(tones)) % len(tones)]
            img.set(x, y, tone)


def planks(img: Canvas, rect: tuple[int, int, int, int], tones: tuple[str, str], seam: str, seed: int,
           mask=None, h: int = 7, lengths=(26, 48)) -> None:
    """Wooden floor boards (horizontal), two close tones, dark seams, a few soft grain lines."""
    x0, y0, x1, y1 = rect
    rng = random.Random(seed)
    for row, y in enumerate(range(y0, y1, h)):
        x = x0 - rng.randrange(0, lengths[0])
        while x < x1:
            ln = rng.randrange(*lengths)
            tone = tones[rng.randrange(2)]
            gy = y + rng.randrange(2, h - 2) if rng.random() < 0.3 else -99
            for yy in range(y, min(y + h, y1)):
                for xx in range(max(x, x0), min(x + ln, x1)):
                    if mask is not None and not mask(xx, yy):
                        continue
                    col = tone
                    if yy == y + h - 1 or xx == x + ln - 1:
                        col = seam
                    elif yy == gy and (xx * 7 + row) % 11 < 5:
                        col = dk(tone)
                    img.set(xx, yy, col)
            x += ln


def soft_patches(img: Canvas, rect: tuple[int, int, int, int], col: str, seed: int, cover: float = 0.18,
                 scale: float = 18.0, mask=None, only: tuple[str, ...] | None = None) -> None:
    """Large soft-edged patches of one colour (moss, damp, sand drift) with clustered edges."""
    x0, y0, x1, y1 = rect
    thr = 1.0 - cover
    for y in range(y0, y1):
        for x in range(x0, x1):
            if mask is not None and not mask(x, y):
                continue
            if only is not None and name_at(img, x, y) not in only:
                continue
            n = fbm(x, y, seed, scale, 3) + AW._cluster(x, y, seed) * 0.06
            if n > thr * 0.62 + 0.2:
                img.set(x, y, col)


def edge_shadow(img: Canvas, y_top: int = AY0, depth: int = 5, x0: int = AX0, x1: int = AX1, steps: int = -1) -> None:
    """A clean shadow band cast by the wall/hedge above the arena (organic lower edge)."""
    for x in range(x0, x1):
        d = depth + (1 if AW._cluster(x, y_top, 5) > 0.1 else 0)
        for y in range(y_top, y_top + d):
            shade(img, x, y, steps)


def calm_vignette(img: Canvas, depth: int = 10) -> None:
    """Darken the outer rim of the arena by one step (clustered edge, no dither)."""
    for y in range(AY0, AY1):
        for x in range(AX0, AX1):
            d = min(x - AX0, AX1 - 1 - x, y - AY0, AY1 - 1 - y)
            if d < depth * 0.35 + (fbm(x, y, 77, 10, 2) - 0.5) * 5 + AW._cluster(x, y, 78) * 1.5:
                shade(img, x, y, -1)


# --------------------------------------------------------------------------
# architecture
# --------------------------------------------------------------------------

def masonry(w: int, h: int, ramp: tuple[str, str, str], seed: int, course: int = 6, brick=(9, 15),
            mortar: str | None = None, light_left: bool = True, moss: str | None = None, moss_rate: float = 0.0,
            base_dark: int = 6) -> Canvas:
    """A front-facing stone wall: brick courses in two close tones, 1 px mortar below / right, a lit
    top row on some bricks, a darker band at the foot (one step, clean edge)."""
    dark, mid, light = ramp
    mortar = mortar or dk(dark)
    rng = random.Random(seed)
    c = Canvas(w, h)
    for row, y in enumerate(range(0, h, course)):
        x = -rng.randrange(0, brick[1])
        while x < w:
            bw = rng.randrange(brick[0], brick[1] + 1)
            tone = mid if rng.random() < 0.6 else dark
            lip = rng.random() < 0.45
            for yy in range(y, min(y + course, h)):
                for xx in range(max(0, x), min(x + bw, w)):
                    if yy == y + course - 1 or xx == x + bw - 1:
                        col = mortar
                    elif lip and yy == y and xx < x + bw - 2:
                        col = light
                    else:
                        col = tone
                    if yy >= h - base_dark and col != mortar:
                        col = dk(col)
                    c.set(xx, yy, col)
            if moss and rng.random() < moss_rate:
                mx = x + rng.randrange(0, max(1, bw - 3))
                for k in range(rng.randrange(2, 5)):
                    c.set(mx + k, y + course - 1, moss)
                    if k % 2 == 0:
                        c.set(mx + k, y + course - 2, moss)
            x += bw
    return c


def crenels(w: int, merlon: int = 7, gap: int = 5, h: int = 6, ramp=("stone_d", "stone", "stone_l"),
            outline: str = "iron") -> Canvas:
    """Battlements: merlons with a lit top and left side, outlined."""
    c = Canvas(w, h + 1)
    x = 0
    while x < w:
        for yy in range(h):
            for xx in range(x, min(x + merlon, w)):
                col = ramp[1]
                if yy == 0:
                    col = ramp[2]
                elif xx == x:
                    col = ramp[2]
                elif xx >= x + merlon - 2:
                    col = ramp[0]
                c.set(xx, yy + 1, col)
        x += merlon + gap
    c.outline_all(outline)
    return c


def arch_window(w: int, h: int, lit: bool = True, frame=("stone_d", "stone_l"), glass=("orange", "yellow"),
                dark: str = "night_d", mullion: str = "iron") -> Canvas:
    """An arched window: dark frame, warm lit glass (or dark), a cross mullion."""
    c = Canvas(w + 2, h + 2)
    cx = (w + 2) / 2
    shape = set()
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - w / 2) / (w / 2)
            top = (1 - math.sqrt(max(0.0, 1 - dx * dx))) * (w / 2)
            if y >= top:
                shape.add((x + 1, y + 1))
    for (x, y) in shape:
        if lit:
            col = glass[1] if (x < cx and y > h * 0.35) else glass[0]
        else:
            col = dark
        c.set(x, y, col)
    for y in range(int(h * 0.15) + 1, h + 1):
        if (int(cx), y) in shape:
            c.set(int(cx), y, mullion)
    for x in range(1, w + 1):
        if (x, int(h * 0.55) + 1) in shape:
            c.set(x, int(h * 0.55) + 1, mullion)
    c.outline_all(frame[0])
    return c


def roof(w: int, h: int, ramp: tuple[str, str, str], outline: str, seed: int, overhang: int = 2,
         ridge: str | None = None, hip: bool = False) -> Canvas:
    """A pitched roof seen from the front at 3/4: tile rows getting lighter to the top, shaded right half."""
    c = Canvas(w + overhang * 2, h)
    dark, mid, light = ramp
    for y in range(h):
        inset = int((h - 1 - y) * 0.9) if hip else 0
        for x in range(inset, w + overhang * 2 - inset):
            row = y // 3
            col = mid if (y % 3) else dark
            if (x + row * 2) % 6 == 0 and y % 3:
                col = dark
            if x > (w + overhang * 2) * 0.62 and col == mid:
                col = dark if y % 3 == 1 else mid
            if y < 2:
                col = light
            c.set(x, y, col)
    if ridge:
        for x in range(0, w + overhang * 2):
            if c.opaque(x, 0):
                c.set(x, 0, ridge)
    c.outline_all(outline)
    return c


def house(w: int, wall_h: int, roof_h: int, seed: int, wall=("stone", "stone_l", "white"),
          roof_ramp=("red_d", "red", "coral"), roof_outline: str = "wine", timber: str | None = "brown",
          lit_windows: int = 1, door: bool = True, outline: str = "umber", thorns: bool = False) -> Canvas:
    """A small town house facing the viewer: plaster wall (optionally half-timbered), windows with
    shutters, a door, a tiled roof. Canvas w+4 x wall_h+roof_h+2."""
    rng = random.Random(seed)
    c = Canvas(w + 4, wall_h + roof_h + 1)
    ox, oy = 2, roof_h
    for y in range(wall_h):
        for x in range(w):
            col = wall[1]
            if x < 2:
                col = wall[2]
            elif x > w - 4:
                col = wall[0]
            if y > wall_h - 3:
                col = dk(col)
            c.set(ox + x, oy + y, col)
    if timber:
        for x in (0, w // 2, w - 1):
            c.vline(ox + x, oy, oy + wall_h - 1, timber)
        c.hline(ox, ox + w - 1, oy + wall_h // 2, timber)
        c.hline(ox, ox + w - 1, oy, dk(timber))
    nwin = max(1, w // 10)
    for k in range(nwin):
        wx = ox + 3 + k * ((w - 6) // nwin) + rng.randrange(0, 2)
        wy = oy + 3
        lit = k < lit_windows
        c.rect(wx, wy, 4, 5, "night_d")
        if lit:
            c.rect(wx, wy + 1, 4, 4, "orange")
            c.rect(wx, wy + 1, 2, 2, "yellow")
        c.hline(wx, wx + 3, wy + 2, "brown_d")
        c.vline(wx - 1, wy, wy + 4, "teal" if seed % 2 else "water_d")
        c.vline(wx + 4, wy, wy + 4, "teal" if seed % 2 else "water_d")
        c.hline(wx - 1, wx + 4, wy + 5, "brown")
    if door:
        dx = ox + w // 2 - 2 + rng.randrange(-2, 3)
        c.rect(dx, oy + wall_h - 8, 5, 8, "brown_d")
        c.rect(dx + 1, oy + wall_h - 7, 3, 7, "brown")
        c.set(dx + 3, oy + wall_h - 4, "gold_l")
    if thorns:
        for k in range(rng.randrange(2, 4)):
            tx = ox + rng.randrange(0, w)
            ty = oy + wall_h - 1
            for j in range(rng.randrange(6, wall_h)):
                tx += rng.choice((-1, 0, 1))
                c.set(tx, ty - j, "plum" if j % 3 else "violet")
                if j % 4 == 2:
                    c.set(tx + 1, ty - j, "wine")
    r = roof(w, roof_h, roof_ramp, roof_outline, seed)
    c.blit(r, 0, 0)
    out = Canvas(c.w, c.h)
    out.blit(c, 0, 0)
    for y in range(out.h):
        for x in range(out.w):
            if out.opaque(x, y) and not (out.opaque(x - 1, y) and out.opaque(x + 1, y) and out.opaque(x, y - 1)
                                        and out.opaque(x, y + 1)):
                if name_at(out, x, y) not in (roof_outline,):
                    out.set(x, y, outline)
    return out


def round_tower(w: int, h: int, ramp: tuple[str, str, str, str], seed: int, cone=("red_d", "red", "coral"),
                cone_h: int = 0, outline: str = "iron", windows: int = 2, lit: bool = True, crenel: bool = False,
                course: int = 5) -> Canvas:
    """A round tower seen from the front: 4 wide vertical light bands (lit left -> shade right) with
    brick courses, a conical roof (cone_h > 0) or battlements, small slit windows."""
    top = cone_h
    c = Canvas(w + 4, h + cone_h + 2)
    for y in range(h):
        for x in range(w):
            u = (x + 0.5) / w
            band = 3 if u < 0.18 else (2 if u < 0.5 else (1 if u < 0.8 else 0))
            col = ramp[band]
            if (y % course) == course - 1 and 0.08 < u < 0.95:
                col = ramp[max(0, band - 1)]
            elif (y % course) != course - 1 and ((x + (y // course) * 3) % 7 == 0) and 0.1 < u < 0.92:
                col = ramp[max(0, band - 1)]
            c.set(x + 2, top + y, col)
    if cone_h:
        for y in range(cone_h):
            half = (y + 1) / cone_h * (w / 2 + 2)
            for x in range(int(w / 2 + 2 - half), int(w / 2 + 2 + half) + 1):
                u = (x - (w / 2 + 2 - half)) / max(1, 2 * half)
                col = cone[2] if u < 0.3 else (cone[1] if u < 0.65 else cone[0])
                if y % 4 == 3:
                    col = dk(col)
                c.set(x, y, col)
        c.vline(int(w / 2 + 2), 0, 1, "gold")
    if crenel:
        cr = crenels(w + 2, 4, 3, 4, (ramp[0], ramp[2], ramp[3]), outline)
        c.blit(cr, 1, top - 3)
    for k in range(windows):
        wy = top + 6 + k * max(8, (h - 12) // max(1, windows))
        wx = 2 + int(w * 0.42)
        c.rect(wx, wy, 2, 5, "night_d")
        if lit and k == 0:
            c.rect(wx, wy + 1, 2, 3, "orange")
            c.set(wx, wy + 1, "yellow")
    c.outline_all(outline)
    return c


def thorn_vine(img: Canvas, x: int, y: int, length: int, seed: int, up: bool = True,
               cols=("plum", "violet", "wine"), mask=None) -> None:
    """Morgana's purple thorns creeping up (or along) a surface."""
    rng = random.Random(seed)
    for j in range(length):
        if up:
            y -= 1
            x += rng.choice((-1, 0, 0, 1))
        else:
            x += 1
            y += rng.choice((-1, 0, 0, 1))
        if mask is None or mask(x, y):
            img.set(x, y, cols[0] if j % 4 else cols[1])
            if j % 5 == 2:
                tx, ty = (x + rng.choice((-1, 1)), y) if up else (x, y - 1)
                if mask is None or mask(tx, ty):
                    img.set(tx, ty, cols[2])


# --------------------------------------------------------------------------
# small props
# --------------------------------------------------------------------------

def barrel(seed: int = 0) -> Canvas:
    c = Canvas(10, 12)
    for y in range(1, 11):
        for x in range(1, 9):
            u = (x - 1) / 7
            col = "gold_d" if u < 0.3 else ("brown" if u < 0.75 else "brown_d")
            if y in (3, 8):
                col = "iron" if u > 0.5 else "steel_d"
            c.set(x, y, col)
    c.hline(2, 7, 1, "gold")
    c.outline_all("umber")
    return c


def awning_stall(w: int, cols: tuple[str, str], seed: int) -> Canvas:
    """A market stall: striped awning, counter with goods."""
    rng = random.Random(seed)
    c = Canvas(w + 2, 24)
    for y in range(1, 8):
        for x in range(1, w + 1):
            stripe = cols[0] if ((x - 1) // 4) % 2 == 0 else cols[1]
            if y == 7 and (x % 4) in (0, 1):
                continue
            c.set(x, y, stripe if y > 1 else lt(stripe))
    for x in (2, w - 1):
        c.vline(x, 8, 22, "brown")
    for y in range(15, 23):
        for x in range(1, w + 1):
            c.set(x, y, "brown" if y > 15 else "gold_d")
    for k in range(w // 4):
        gx = 2 + k * 4 + rng.randrange(2)
        col = rng.choice(["red", "orange", "leaf", "yellow", "pink"])
        c.set(gx, 14, col)
        c.set(gx + 1, 14, col)
        c.set(gx, 13, lt(col))
    c.outline_all("umber")
    return c


def statue(seed: int, ramp=("stone_d", "stone", "stone_l"), outline="iron") -> Canvas:
    """A little stone knight-dog statue on a plinth (12x22)."""
    c = Canvas(14, 24)
    sh = P.ellipse(7, 7, 3.6, 3.3) | P.ellipse(5, 6, 2, 3) | P.rect(4, 9, 7, 7)
    sh |= P.ellipse(3.2, 6.5, 1.3, 2.5)
    for (x, y) in sh:
        u = (x - 3) / 8
        c.set(x, y, ramp[2] if u < 0.35 else (ramp[1] if u < 0.75 else ramp[0]))
    for y in range(16, 23):
        for x in range(2, 12):
            c.set(x, y, ramp[1] if x < 7 else ramp[0])
    c.hline(2, 11, 16, ramp[2])
    c.outline_all(outline)
    return c


def gargoyle_statue(flip: bool = False) -> Canvas:
    """A crouching stone gargoyle on a corner merlon (16x16): horns, tiny wings, violet eyes."""
    c = Canvas(16, 16)
    body = P.ellipse(8, 10, 5, 4.5) | P.ellipse(8, 5.5, 3.5, 3.2)
    wings = P.poly([(2, 4), (5, 7), (3, 11)]) | P.poly([(14, 4), (11, 7), (13, 11)])
    for (x, y) in wings:
        c.set(x, y, "slate")
    for (x, y) in body:
        u = (x - 3) / 10 + (y - 2) / 26
        c.set(x, y, "stone_l" if u < 0.42 else ("stone" if u < 0.75 else "stone_d"))
    c.set(6, 2, "stone_d")
    c.set(5, 1, "stone")
    c.set(10, 2, "stone_d")
    c.set(11, 1, "stone")
    c.set(7, 5, "violet")
    c.set(9, 5, "violet")
    c.outline_all("iron")
    return c.flipped() if flip else c


def bookshelf(w: int, h: int, seed: int, wood=("umber", "brown_d", "brown")) -> Canvas:
    """A tall bookshelf full of books with coloured spines (clean, 2 tones per spine)."""
    rng = random.Random(seed)
    c = Canvas(w, h)
    c.rect(0, 0, w, h, wood[1])
    c.vline(0, 0, h - 1, wood[2])
    c.vline(w - 1, 0, h - 1, wood[0])
    shelf_h = 13
    spines = [("red", "red_d"), ("water", "water_d"), ("leaf_d", "forest"), ("gold", "gold_d"), ("violet", "plum"),
              ("teal", "deep"), ("coral", "red_d"), ("cream", "dirt"), ("sky", "water")]
    for sy in range(2, h - 4, shelf_h):
        x = 2
        while x < w - 3:
            bw = rng.choice((2, 2, 3, 3, 4))
            bh = rng.randrange(7, 11)
            if rng.random() < 0.08:
                x += bw
                continue
            a, b = rng.choice(spines)
            top = sy + shelf_h - 3 - bh
            for yy in range(top, sy + shelf_h - 3):
                for xx in range(x, min(x + bw, w - 2)):
                    c.set(xx, yy, a if xx == x else b)
            if bh > 8:
                c.set(x + bw // 2, top + 2, "gold_l")
            x += bw
        c.rect(1, sy + shelf_h - 3, w - 2, 2, wood[2])
        c.hline(1, w - 2, sy + shelf_h - 1, wood[0])
    c.outline_all("ink")
    return c


def crystal(h: int, seed: int, ramp=("water_d", "water", "sky", "sky_l"), outline: str = "navy",
            lean: float = 0.0) -> Canvas:
    """A faceted crystal spike: lit left facet, mid front facet, dark right facet, white glint."""
    w = max(5, h // 2 + 1) | 1
    c = Canvas(w + 2 + int(abs(lean) * h), h + 2)
    cx = w / 2 + 1 + max(0.0, -lean * h)
    for y in range(h):
        k = y / h
        half = (0.2 + 0.8 * min(1.0, k * 2.2)) * w / 2
        mx = cx + lean * (h - y)
        for x in range(int(mx - half), int(mx + half) + 1):
            u = (x + 0.5 - (mx - half)) / max(1, 2 * half)
            col = ramp[3] if u < 0.22 else (ramp[2] if u < 0.55 else (ramp[1] if u < 0.8 else ramp[0]))
            c.set(x, y + 1, col)
    c.set(int(cx + lean * h) - 1, 3, "white")
    c.outline_all(outline)
    return c


def menhir(h: int, seed: int, ramp=("slate", "ash", "fog"), outline="navy", rune: str | None = None) -> Canvas:
    w = max(7, h // 2)
    c = Canvas(w + 2, h + 2)
    rng = random.Random(seed)
    for y in range(h):
        k = y / h
        half = w / 2 * (0.7 + 0.3 * min(1.0, k * 3)) - (0.8 if y < 3 else 0)
        cx = w / 2 + 1 + (1 if y < h * 0.3 and seed % 2 else 0)
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x - (cx - half)) / max(1, 2 * half)
            col = ramp[2] if u < 0.3 else (ramp[1] if u < 0.7 else ramp[0])
            if y > h - 3:
                col = dk(col)
            c.set(x, y + 1, col)
    for _ in range(2):
        mx = rng.randrange(2, w)
        c.set(mx, h - 2, "teal")
        c.set(mx + 1, h - 1, "teal")
    if rune:
        rx, ry = w // 2 + 1, h // 3
        for (dx, dy) in ((0, 0), (0, 1), (0, 2), (-1, 1), (1, 1), (0, 3)):
            c.set(rx + dx, ry + dy, rune)
    c.outline_all(outline)
    return c


def mushroom_glow(seed: int, cap=("teal", "grass", "spring"), stem="haze") -> Canvas:
    c = Canvas(7, 7)
    c.vline(3, 3, 6, stem)
    for (x, y) in P.ellipse(3.5, 2.5, 3.2, 2):
        c.set(x, y, cap[2] if x < 3 and y < 2 else (cap[1] if x < 5 else cap[0]))
    c.set(2, 1, "white")
    c.outline_all("deep")
    return c


def lily_pad(seed: int) -> Canvas:
    c = Canvas(7, 5)
    for (x, y) in P.ellipse(3.5, 2.5, 3.2, 2):
        c.set(x, y, "grass" if x < 4 else "teal")
    c.set(3, 2, None)
    c.set(4, 2, None)
    return c


def reeds(seed: int, h: int = 12, cols=("teal", "forest", "brown")) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(9, h + 1)
    for k in range(4):
        x = 1 + k * 2
        top = rng.randrange(0, 4)
        lean = rng.choice((-1, 0, 1))
        for y in range(top, h + 1):
            c.set(x + (lean if y < top + 3 else 0), y, cols[0] if k % 2 else cols[1])
        if k % 2 == 0:
            c.set(x, top, cols[2])
            c.set(x, top + 1, cols[2])
    return c


# --------------------------------------------------------------------------
# animated layers (assets/backgrounds/anim/<kind>_frames.tres)
# --------------------------------------------------------------------------

def _anim_flag(cloth: tuple[str, str, str], emblem: str | None, outline: str = "ink") -> list[Anim]:
    """A long banner hanging from a bar, rippling (4 frames)."""
    frames = []
    for f in range(4):
        c = Canvas(12, 20)
        c.hline(0, 11, 0, "brown_d")
        c.hline(0, 11, 1, "gold_d")
        for y in range(2, 18):
            wave = int(round(math.sin(f / 4 * 2 * math.pi + y * 0.42) * 1.1)) if y > 4 else 0
            for x in range(2, 10):
                col = cloth[1]
                if x == 2:
                    col = cloth[2]
                elif x >= 8:
                    col = cloth[0]
                if y >= 15 and abs(x - 5.5) < (y - 14) * 1.3:
                    continue
                c.set(x + wave, y, col)
            if emblem and 6 <= y <= 9:
                c.set(5 + wave, y, emblem)
                c.set(6 + wave, y, emblem)
                if y == 7:
                    c.set(4 + wave, y, emblem)
                    c.set(7 + wave, y, emblem)
        c.outline_all(outline)
        frames.append(c)
    return [Anim("default", frames, 5.0, True)]


def _anim_pennant(cols: tuple[str, str]) -> list[Anim]:
    """A pennant on a short pole flapping in the wind (4 frames, 14x12)."""
    frames = []
    for f in range(4):
        c = Canvas(14, 12)
        c.vline(1, 0, 11, "brown_d")
        c.set(1, 0, "gold_l")
        for x in range(2, 13):
            k = (x - 2) / 10
            half = 3 * (1 - k)
            cy = 3 + math.sin(f / 4 * 2 * math.pi - x * 0.6) * 1.2 * k
            for y in range(int(cy - half), int(cy + half) + 1):
                c.set(x, y, cols[0] if y < cy else cols[1])
        frames.append(c)
    return [Anim("default", frames, 7.0, True)]


def _anim_candle() -> list[Anim]:
    frames = []
    flames = [[".Y.", "YwY", ".O."], ["..Y", ".wY", ".O."], [".Y.", ".w.", ".O."], ["Y..", "Yw.", ".O."]]
    for s in flames:
        c = Canvas(5, 10)
        c.stamp(s, 1, 0, {"Y": "yellow", "w": "white", "O": "orange"}, outline=None)
        c.rect(1, 4, 3, 5, "cream")
        c.vline(1, 4, 8, "white")
        c.vline(3, 4, 8, "sand")
        c.set(2, 3, "umber")
        c.hline(0, 4, 9, "gold_d")
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


def _anim_book() -> list[Anim]:
    """A floating open spellbook: bobs and flaps its pages (6 frames, 14x14)."""
    frames = []
    for f in range(6):
        c = Canvas(14, 14)
        bob = int(round(math.sin(f / 6 * 2 * math.pi) * 1.5))
        flap = [0, 1, 2, 1, 0, -1][f]
        cy = 6 + bob
        for side in (-1, 1):
            for k in range(5):
                x = 7 + side * (k + 1)
                lift = int(round((flap if side > 0 else -flap) * k / 4.0))
                c.set(x, cy - 2 - lift + (k // 3), "white" if k < 4 else "fog")
                c.set(x, cy - 1 - lift + (k // 3), "cream")
                c.set(x, cy - lift + (k // 3), "sand")
                c.set(x, cy + 1 - lift + (k // 3), "red_d" if side < 0 else "wine")
        c.vline(7, cy - 2, cy + 1, "wine")
        c.outline_all("umber")
        if f in (1, 4):
            c.set(3, cy - 5, "lilac")
            c.set(11, cy - 4, "lilac")
        frames.append(c)
    return [Anim("default", frames, 6.0, True)]


def _anim_glint(cols: tuple[str, str, str]) -> list[Anim]:
    """A 4-point star glint that flashes now and then (crystals, stars, magic)."""
    frames = []
    for f in range(8):
        c = Canvas(9, 9)
        if f == 1:
            c.set(4, 4, cols[0])
        elif f in (2, 3):
            r = 2 if f == 2 else 3
            for d in range(-r, r + 1):
                col = cols[0] if abs(d) < 2 else cols[1]
                c.set(4 + d, 4, col)
                c.set(4, 4 + d, col)
        elif f == 4:
            c.set(4, 4, cols[1])
            for d in (-1, 1):
                c.set(4 + d, 4, cols[2])
                c.set(4, 4 + d, cols[2])
        frames.append(c)
    return [Anim("default", frames, 10.0, True, [16, 1, 1, 1, 1, 1, 1, 1])]


def _anim_pulse(shape: list[str], ramp: tuple[str, str, str], fps: float = 4.0) -> list[Anim]:
    """A small rune / glow that breathes through three tones."""
    frames = []
    seq = [0, 1, 2, 2, 1, 0]
    for f in seq:
        c = Canvas(len(shape[0]), len(shape))
        for y, row in enumerate(shape):
            for x, ch in enumerate(row):
                if ch == "#":
                    c.set(x, y, ramp[f])
                elif ch == "+" and f == 2:
                    c.set(x, y, ramp[1])
        frames.append(c)
    return [Anim("default", frames, fps, True)]


def _anim_fountain() -> list[Anim]:
    """A fountain spout: a rising jet and falling droplets (4 frames, 16x16)."""
    frames = []
    for f in range(4):
        c = Canvas(16, 16)
        top = 2 + (f % 2)
        for y in range(top, 13):
            c.set(7, y, "sky_l" if y < 6 else "azure")
            c.set(8, y, "white" if y < 5 else "sky_l")
        for k in range(4):
            t = ((f + k) % 4) / 4
            for side in (-1, 1):
                x = 8 + side * int(1 + t * 6)
                y = int(4 + t * t * 10 - 2 * t)
                c.set(x, y, "sky_l" if t < 0.6 else "azure")
        c.hline(4, 11, 13, "azure")
        c.hline(3, 12, 14, "sky")
        frames.append(c)
    return [Anim("default", frames, 7.0, True)]


def _anim_orb(cols: tuple[str, str, str]) -> list[Anim]:
    """A floating magic orb (bobbing, 6 frames, 7x11)."""
    frames = []
    for f in range(6):
        c = Canvas(7, 11)
        cy = 5 + int(round(math.sin(f / 6 * 2 * math.pi) * 2))
        for (x, y) in P.ellipse(3.5, cy + 0.5, 2.6, 2.6):
            c.set(x, y, cols[1])
        c.set(2, cy - 1, cols[0])
        c.set(3, cy - 1, cols[0])
        c.set(2, cy, cols[0])
        c.set(4, cy + 1, cols[2])
        frames.append(c)
    return [Anim("default", frames, 5.0, True)]


def _anim_wisp() -> list[Anim]:
    """A fairy wisp: a tiny glowing dot with a trailing tail that circles (6 frames, 11x11)."""
    frames = []
    for f in range(6):
        c = Canvas(11, 11)
        for k in range(4):
            a = (f - k * 0.6) / 6 * 2 * math.pi
            x = 5 + math.cos(a) * 3.2
            y = 5 + math.sin(a) * 2.2
            col = ("white", "haze", "spring", "grass")[k]
            c.set(int(round(x)), int(round(y)), col)
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


def _anim_mist_strip(w: int = 64, h: int = 10) -> list[Anim]:
    """A drifting band of mist (8 frames, semi-transparent: background decoration, not palette art)."""
    frames = []
    for f in range(8):
        c = Canvas(w, h)
        for y in range(h):
            for x in range(w):
                v = 0.5 + 0.5 * math.sin((x + f * w / 8) / w * 2 * math.pi) * 0.6 + \
                    0.5 * math.sin((x * 2 - f * w / 8) / w * 2 * math.pi + y * 0.5) * 0.4
                edge = 1.0 - abs(y - h / 2) / (h / 2)
                a = v * edge
                if a > 0.62 or (a > 0.45 and P.bayer(x, y) < 0.5):
                    c.set(x, y, P.alpha_px("fog", 70 if a < 0.62 else 110))
        frames.append(c)
    return [Anim("default", frames, 3.0, True)]


def _anim_flame_brazier() -> list[Anim]:
    """A brazier bowl on a stand with a dancing fire (4 frames, 11x16)."""
    frames = []
    shapes = [
        ["..Y..", ".YwY.", "YwwOY", "OYOYO"],
        ["...Y.", "..YY.", ".YwwY", "OYOYO"],
        [".Y...", ".YY..", "YwwY.", "OYOYO"],
        ["..Y..", "..Y..", ".YwY.", "OYOYO"],
    ]
    for s in shapes:
        c = Canvas(11, 16)
        c.stamp(s, 3, 1, {"Y": "yellow", "w": "white", "O": "orange"}, outline="red_d")
        c.hline(2, 8, 6, "iron")
        c.hline(3, 7, 7, "steel_d")
        c.hline(3, 7, 8, "iron")
        c.vline(5, 9, 14, "iron")
        c.hline(3, 7, 15, "iron")
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


def _anim_waterfall(w: int = 10, h: int = 24) -> list[Anim]:
    frames = []
    for f in range(4):
        c = Canvas(w, h)
        for y in range(h):
            for x in range(w):
                k = (y - f * 3 + x * 5) % 8
                col = "sky_l" if k == 0 else ("azure" if k < 3 else "sky")
                if x in (0, w - 1):
                    col = "water"
                c.set(x, y, col)
        frames.append(c)
    return [Anim("default", frames, 8.0, True)]


ANIMS = {
    "flag_camelot": (lambda: _anim_flag(("red_d", "red", "coral"), "gold_l", "wine"), (12, 20)),
    "flag_blue": (lambda: _anim_flag(("water_d", "water", "sky"), "gold_l", "navy"), (12, 20)),
    "flag_green": (lambda: _anim_flag(("forest", "leaf_d", "leaf"), "gold_l", "deep"), (12, 20)),
    "flag_morgana": (lambda: _anim_flag(("plum", "violet", "lilac"), "yellow", "ink"), (12, 20)),
    "pennant_red": (lambda: _anim_pennant(("red", "red_d")), (14, 12)),
    "pennant_gold": (lambda: _anim_pennant(("gold_l", "gold")), (14, 12)),
    "candle": (_anim_candle, (5, 10)),
    "book_float": (_anim_book, (14, 14)),
    "glint_cyan": (lambda: _anim_glint(("white", "sky_l", "azure")), (9, 9)),
    "glint_violet": (lambda: _anim_glint(("white", "lilac", "violet")), (9, 9)),
    "glint_star": (lambda: _anim_glint(("white", "steel_l", "lilac")), (9, 9)),
    "rune_violet": (lambda: _anim_pulse([".#.", "#+#", ".#.", ".#."], ("plum", "violet", "lilac")), (3, 4)),
    "rune_cyan": (lambda: _anim_pulse(["#.#", ".#.", "#+#", ".#."], ("teal", "sky", "sky_l")), (3, 4)),
    "mushroom_pulse": (lambda: _anim_pulse([".###.", "##+##", "..#.."], ("teal", "grass", "spring"), 3.0), (5, 3)),
    "fountain": (_anim_fountain, (16, 16)),
    "orb_violet": (lambda: _anim_orb(("lilac", "violet", "plum")), (7, 11)),
    "orb_cyan": (lambda: _anim_orb(("white", "sky_l", "sky")), (7, 11)),
    "wisp": (_anim_wisp, (11, 11)),
    "mist_strip": (_anim_mist_strip, (64, 10)),
    "brazier": (_anim_flame_brazier, (11, 16)),
    "waterfall": (_anim_waterfall, (10, 24)),
}


def particle_textures() -> dict[str, Canvas]:
    """assets/backgrounds/anim/p_<name>.png (semi-transparent, never palette-tested)."""
    t: dict[str, Canvas] = {}
    c = Canvas(14, 6)
    for y in range(6):
        for x in range(14):
            d = ((x + 0.5 - 7) / 7) ** 2 + ((y + 0.5 - 3) / 3) ** 2
            if d < 1:
                c.set(x, y, P.alpha_px("fog", 60 if d > 0.45 else 95))
    t["mist"] = c
    c = Canvas(3, 3)
    c.set(1, 1, "white")
    for (x, y) in ((0, 1), (2, 1), (1, 0), (1, 2)):
        c.set(x, y, P.alpha_px("sky_l", 150))
    t["spark_cyan"] = c
    c = Canvas(3, 3)
    c.set(1, 1, "lilac")
    for (x, y) in ((0, 1), (2, 1), (1, 0), (1, 2)):
        c.set(x, y, P.alpha_px("violet", 150))
    t["spark_violet"] = c
    c = Canvas(5, 5)
    for (x, y) in P.ellipse(2.5, 2.5, 2.4, 2.4):
        c.set(x, y, P.alpha_px("fog", 90))
    c.set(1, 1, P.alpha_px("white", 120))
    t["smoke"] = c
    c = Canvas(2, 2)
    c.set(0, 0, "yellow")
    c.set(1, 1, P.alpha_px("gold_l", 140))
    t["pollen"] = c
    c = Canvas(1, 3)
    c.set(0, 0, P.alpha_px("sky_l", 120))
    c.set(0, 1, "sky_l")
    c.set(0, 2, "white")
    t["drip"] = c
    c = Canvas(2, 2)
    c.set(0, 0, "yellow")
    c.set(1, 0, "orange")
    c.set(0, 1, "orange")
    t["ember"] = c
    c = Canvas(3, 3)
    c.set(1, 1, "spring")
    for (x, y) in ((0, 1), (2, 1), (1, 0), (1, 2)):
        c.set(x, y, P.alpha_px("grass", 150))
    t["firefly_green"] = c
    c = Canvas(3, 2)
    c.set(0, 0, "leaf")
    c.set(1, 0, "spring")
    c.set(1, 1, "leaf_d")
    c.set(2, 1, "leaf")
    t["leaf_green"] = c
    c = Canvas(3, 2)
    c.set(1, 0, "lilac")
    c.set(0, 1, "violet")
    c.set(1, 1, "white")
    c.set(2, 1, "lilac")
    t["petal_violet"] = c
    return t


# --------------------------------------------------------------------------
# scene finishing: lights, foreground, tints, .tscn
# --------------------------------------------------------------------------

class Scene26(AW.Scene):
    def __init__(self, base: str = "leaf_d", vignette: float = 0.45) -> None:
        super().__init__(base)
        self.fg = Canvas(IMG_W, IMG_H)
        AL.vignette(self.fg, vignette)
        self.lights: list[tuple] = []        # (kind, world x, world y, scale, alpha, seed)
        self.fg_lights: list[tuple] = []
        self.light_tints: dict[tuple[str, int], tuple[float, float, float]] = {}
        self.rain = False

    def light(self, kind: str, ix: float, iy: float, alpha: float = 1.0, tint: tuple[float, float, float] | None = None,
              front: bool = False, seed: float | None = None) -> None:
        """Add an additive light sprite at image pixel (ix, iy); optional colour tint."""
        wx, wy = ix + AW.ORIGIN[0], iy + AW.ORIGIN[1]
        target = self.fg_lights if front else self.lights
        target.append((kind, wx, wy, 1.0, alpha, (ix * 7 + iy) % 10 * 0.37 if seed is None else seed))
        if tint is not None:
            self.light_tints[("Foreground" if front else "Lights", len(target) - 1)] = tint

    def put_fg(self, src: Canvas, ox: int, oy: int) -> None:
        AL.put(self.fg, src, ox, oy)


def torch_lights(sc: Scene26) -> None:
    size = AW.ANIMS["torch"][1]
    for (kind, ix, iy, frame, speed, flip) in sc.anims:
        if kind in ("torch", "brazier"):
            cx = ix + (size[0] / 2 if kind == "torch" else 5.5)
            wx, wy = cx + AW.ORIGIN[0], iy + 2 + AW.ORIGIN[1]
            inside = 2 <= wx <= 178 and 72 <= wy <= 296
            (sc.lights if inside else sc.fg_lights).append(("torch", wx, wy, 1.0, 1.0 if kind == "torch" else 1.2,
                                                            (ix * 7 + iy) % 10 * 0.37))
        elif kind == "candle":
            sc.lights.append(("lantern", ix + 2.5 + AW.ORIGIN[0], iy + 2 + AW.ORIGIN[1], 1.0, 0.55,
                              (ix * 3 + iy) % 10 * 0.41))


def scene_tscn(name: str, sc: Scene26) -> str:
    text = AW.background_tscn(name, sc)
    if not sc.light_tints:
        return text
    lines = text.split("\n")
    out = []
    for line in lines:
        out.append(line)
        for (parent, i), rgb in sc.light_tints.items():
            src = sc.fg_lights if parent == "Foreground" else sc.lights
            kind = src[i][0]
            if line.startswith('[node name="%s_%d" parent="%s"' % (kind, i, parent)):
                out.append("modulate = Color(%g, %g, %g, 0.5)" % rgb)
    return "\n".join(out)


def write_shared() -> None:
    for kind, (fn, size) in ANIMS.items():
        build_sheet("res://assets/backgrounds/anim", kind, fn(), size)
    for kind, tex in particle_textures().items():
        tex.save(res_path("res://assets/backgrounds/anim/p_%s.png" % kind))


def write_scene(name: str, sc: Scene26) -> None:
    torch_lights(sc)
    sc.fg.save(res_path("res://assets/backgrounds/%s_fg.png" % name))
    sc.img.save(res_path("res://assets/backgrounds/%s.png" % name))
    write_text(res_path("res://assets/backgrounds/%s.tscn" % name), scene_tscn(name, sc))


def gable_house(w: int, wall_h: int, seed: int, wall=("stone", "stone_l", "white"),
                roof_ramp=("red_d", "red", "coral"), timber: str | None = "brown", lit: bool = True,
                outline: str = "umber", thorns: bool = False, chimney: bool = False) -> Canvas:
    """A taller town house with its gable facing the viewer: plaster front with a triangular gable,
    thick roof edges with an overhang, two floors of shuttered windows, a door and optional chimney."""
    rng = random.Random(seed)
    gh = w // 2 + 2
    c = Canvas(w + 6, wall_h + gh + 4)
    ox, oy = 3, gh + 3
    cx = ox + w / 2
    # plaster: front wall + gable triangle, lit left, shaded right quarter
    for y in range(oy - gh, oy + wall_h):
        for x in range(ox, ox + w):
            if y < oy and abs(x + 0.5 - cx) > (y - (oy - gh)) * (w / 2) / gh:
                continue
            col = wall[1]
            if x < ox + 2:
                col = wall[2]
            elif x >= ox + w - 3:
                col = wall[0]
            if y >= oy + wall_h - 2:
                col = dk(col)
            c.set(x, y, col)
    if timber:
        for x in (ox, ox + w - 1, int(cx)):
            c.vline(x, oy, oy + wall_h - 1, timber)
        c.hline(ox, ox + w - 1, oy, timber)
        c.hline(ox, ox + w - 1, oy + wall_h // 2, timber)
    # roof edges: two thick slopes with an overhang, lit on the left slope
    for k in range(gh + 3):
        y = oy - gh + k - 2
        for t in range(3):
            lx = int(cx - k * (w / 2 + 3) / (gh + 1)) - t + 1
            rx = int(cx + k * (w / 2 + 3) / (gh + 1)) + t - 1
            c.set(lx, y + t, roof_ramp[2] if t == 0 else roof_ramp[1])
            c.set(rx, y + t, roof_ramp[1] if t == 0 else roof_ramp[0])

    def win(x: int, y: int, on: bool) -> None:
        c.rect(x, y, 4, 5, "night_d")
        if on:
            c.rect(x, y + 1, 4, 4, "orange")
            c.rect(x, y + 1, 2, 2, "yellow")
        c.hline(x, x + 3, y + 2, "brown_d")
        c.vline(x - 1, y, y + 4, "teal" if seed % 2 else "water_d")
        c.vline(x + 4, y, y + 4, "teal" if seed % 2 else "water_d")
        c.hline(x - 1, x + 4, y + 5, "brown")

    win(int(cx) - 2, oy - gh // 2 - 1, lit and rng.random() < 0.5)
    for row, wy in enumerate((oy + 3, oy + wall_h // 2 + 3)):
        for col_x in (ox + 3, ox + w - 8):
            win(col_x, wy, lit and rng.random() < 0.35)
    dx = int(cx) - 2
    c.rect(dx, oy + wall_h - 9, 5, 9, "brown_d")
    c.rect(dx + 1, oy + wall_h - 8, 3, 8, "brown")
    c.set(dx + 3, oy + wall_h - 4, "gold_l")
    if chimney:
        chx = ox + w - 8
        for y in range(oy - gh + 2, oy - gh + 9):
            c.hline(chx, chx + 3, y, "stone_d" if y > oy - gh + 3 else "stone")
    if thorns:
        for k in range(rng.randrange(2, 4)):
            tx = ox + rng.randrange(0, w)
            ty = oy + wall_h - 1
            for j in range(rng.randrange(8, wall_h + 4)):
                tx += rng.choice((-1, 0, 1))
                if c.opaque(tx, ty - j):
                    c.set(tx, ty - j, "plum" if j % 3 else "violet")
                    if j % 4 == 2 and c.opaque(tx + 1, ty - j):
                        c.set(tx + 1, ty - j, "wine")
    c.outline_all(outline)
    return c
