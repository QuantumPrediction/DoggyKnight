"""Small pixel-art toolkit (C 線, DEV_PLAN C1). Python 3 standard library only.

Images are `Canvas` objects: a grid of RGBA tuples (or None for transparent).
Art is written as character grids; each character maps to a palette colour name
(see palette.py). `Canvas.stamp()` draws a grid and can add a 1 px outline around
the shape it draws, so parts layered on top of each other get crisp separations.
"""

from __future__ import annotations

import math
import os
import struct
import zlib

from palette import COLORS, rgba

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUTLINE = "ink"

Pixel = tuple  # (r, g, b, a)


def res_path(res: str) -> str:
    """res://foo -> absolute path inside the project."""
    assert res.startswith("res://"), res
    return os.path.join(ROOT, res[len("res://"):])


class Canvas:
    def __init__(self, w: int, h: int, fill: Pixel | None = None) -> None:
        self.w = w
        self.h = h
        self.px: list[Pixel | None] = [fill] * (w * h)

    # --- basic access -------------------------------------------------
    def get(self, x: int, y: int) -> Pixel | None:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y * self.w + x]
        return None

    def set(self, x: int, y: int, c: Pixel | str | None) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = rgba(c) if isinstance(c, str) else c

    def opaque(self, x: int, y: int) -> bool:
        p = self.get(x, y)
        return p is not None and p[3] > 0

    def copy(self) -> "Canvas":
        c = Canvas(self.w, self.h)
        c.px = list(self.px)
        return c

    # --- drawing ------------------------------------------------------
    def rect(self, x: int, y: int, w: int, h: int, c: Pixel | str) -> None:
        col = rgba(c) if isinstance(c, str) else c
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, col)

    def hline(self, x0: int, x1: int, y: int, c: str) -> None:
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.set(x, y, c)

    def vline(self, x: int, y0: int, y1: int, c: str) -> None:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.set(x, y, c)

    def line(self, x0: int, y0: int, x1: int, y1: int, c: str) -> list[tuple[int, int]]:
        """Bresenham line; returns the points drawn."""
        pts = line_points(x0, y0, x1, y1)
        for (x, y) in pts:
            self.set(x, y, c)
        return pts

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, c: str) -> None:
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.set(x, y, c)

    def stamp(self, grid: list[str], ox: int, oy: int, legend: dict[str, str] | None = None,
              outline: str | None = OUTLINE, flip: bool = False, diagonal: bool = False) -> None:
        """Draw a character grid at (ox, oy). '.' and ' ' are transparent.

        outline: colour name for an automatic 1 px outline around the drawn shape
        (None for no outline). diagonal=True also outlines diagonal neighbours.
        """
        legend = legend or {}
        shape: dict[tuple[int, int], str] = {}
        for y, row in enumerate(grid):
            if flip:
                row = row[::-1]
            for x, ch in enumerate(row):
                if ch in ". ":
                    continue
                name = legend.get(ch, ch)
                shape[(ox + x, oy + y)] = name
        if outline:
            ring = set()
            nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
            if diagonal:
                nb += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
            for (x, y) in shape:
                for dx, dy in nb:
                    q = (x + dx, y + dy)
                    if q not in shape:
                        ring.add(q)
            for (x, y) in ring:
                self.set(x, y, outline)
        for (x, y), name in shape.items():
            if name == "_":       # explicit "erase" pixel
                self.set(x, y, None)
            else:
                self.set(x, y, name)

    def blit(self, src: "Canvas", ox: int, oy: int, flip: bool = False) -> None:
        for y in range(src.h):
            for x in range(src.w):
                p = src.px[y * src.w + (src.w - 1 - x if flip else x)]
                if p is not None and p[3] > 0:
                    if p[3] < 255:
                        self.set(ox + x, oy + y, blend(self.get(ox + x, oy + y), p))
                    else:
                        self.set(ox + x, oy + y, p)

    def outline_all(self, c: str = OUTLINE, diagonal: bool = False) -> None:
        """Add an outline around everything that is opaque."""
        col = rgba(c)
        add = []
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            nb += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        for y in range(self.h):
            for x in range(self.w):
                if self.opaque(x, y):
                    continue
                for dx, dy in nb:
                    if self.opaque(x + dx, y + dy):
                        add.append((x, y))
                        break
        for (x, y) in add:
            self.set(x, y, col)

    def replace(self, old: str, new: str | None) -> None:
        o = rgba(old)
        n = rgba(new) if new else None
        self.px = [n if p == o else p for p in self.px]

    def flipped(self) -> "Canvas":
        c = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                c.px[y * self.w + x] = self.px[y * self.w + (self.w - 1 - x)]
        return c

    def shifted(self, dx: int, dy: int) -> "Canvas":
        c = Canvas(self.w, self.h)
        c.blit(self, dx, dy)
        return c

    def scaled(self, k: int) -> "Canvas":
        c = Canvas(self.w * k, self.h * k)
        for y in range(self.h):
            row = self.px[y * self.w:(y + 1) * self.w]
            big = [p for p in row for _ in range(k)]
            for i in range(k):
                start = (y * k + i) * c.w
                c.px[start:start + c.w] = big
        return c

    def bbox(self) -> tuple[int, int, int, int] | None:
        xs = []
        ys = []
        for y in range(self.h):
            for x in range(self.w):
                if self.opaque(x, y):
                    xs.append(x)
                    ys.append(y)
        if not xs:
            return None
        return min(xs), min(ys), max(xs) + 1, max(ys) + 1

    # --- output -------------------------------------------------------
    def save(self, path: str, opaque: bool = False) -> None:
        write_png(path, self, opaque)


def blend(dst: Pixel | None, src: Pixel) -> Pixel:
    if dst is None or dst[3] == 0:
        return src
    a = src[3] / 255.0
    da = dst[3] / 255.0
    out_a = a + da * (1 - a)
    if out_a <= 0:
        return (0, 0, 0, 0)
    rgb = [int(round((src[i] * a + dst[i] * da * (1 - a)) / out_a)) for i in range(3)]
    return (rgb[0], rgb[1], rgb[2], int(round(out_a * 255)))


def line_points(x0: int, y0: int, x1: int, y1: int) -> list[tuple[int, int]]:
    pts = []
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return pts


# --- PNG ---------------------------------------------------------------------

def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: str, img: Canvas, opaque: bool = False) -> None:
    """Write RGBA (or RGB when opaque=True; transparent pixels become black)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rows = []
    for y in range(img.h):
        row = bytearray(b"\x00")
        for p in img.px[y * img.w:(y + 1) * img.w]:
            if p is None:
                p = (0, 0, 0, 0)
            if opaque:
                row += bytes((p[0], p[1], p[2]))
            else:
                row += bytes(p)
        rows.append(bytes(row))
    raw = b"".join(rows)
    color_type = 2 if opaque else 6
    header = struct.pack(">IIBBBBB", img.w, img.h, 8, color_type, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", header) + _chunk(b"IDAT", zlib.compress(raw, 9)) + _chunk(b"IEND", b"")
    if os.path.exists(path):
        with open(path, "rb") as f:
            if f.read() == data:
                return    # unchanged: keep mtime so Godot does not reimport
    with open(path, "wb") as f:
        f.write(data)


def write_text(path: str, text: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            if f.read() == text:
                return
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


# --- sprite sheets -----------------------------------------------------------

class Anim:
    """One animation: frames (Canvas list), fps, loop, optional per-frame durations."""

    def __init__(self, name: str, frames: list[Canvas], fps: float, loop: bool,
                 durations: list[float] | None = None) -> None:
        self.name = name
        self.frames = frames
        self.fps = fps
        self.loop = loop
        self.durations = durations or [1.0] * len(frames)
        assert len(self.durations) == len(frames)


def build_sheet(res_dir: str, code: str, anims: list[Anim], size: tuple[int, int]) -> None:
    """Writes <res_dir>/<code>.png (one row per animation) and <code>_frames.tres."""
    fw, fh = size
    cols = max(len(a.frames) for a in anims)
    sheet = Canvas(fw * cols, fh * len(anims))
    for row, anim in enumerate(anims):
        for i, fr in enumerate(anim.frames):
            assert fr.w == fw and fr.h == fh, (code, anim.name, fr.w, fr.h)
            sheet.blit(fr, i * fw, row * fh)
    png_res = "%s/%s.png" % (res_dir, code)
    sheet.save(res_path(png_res))
    write_text(res_path("%s/%s_frames.tres" % (res_dir, code)), sprite_frames_tres(png_res, anims, size))


def sprite_frames_tres(png_res: str, anims: list[Anim], size: tuple[int, int]) -> str:
    fw, fh = size
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="%s" id="1_sheet"]' % png_res]
    entries = []
    for row, anim in enumerate(anims):
        frame_entries = []
        for i in range(len(anim.frames)):
            sub = "AtlasTexture_%s_%d" % (anim.name, i)
            lines += ["", '[sub_resource type="AtlasTexture" id="%s"]' % sub,
                      'atlas = ExtResource("1_sheet")',
                      "region = Rect2(%d, %d, %d, %d)" % (i * fw, row * fh, fw, fh)]
            frame_entries.append('{\n"duration": %s,\n"texture": SubResource("%s")\n}' % (_num(anim.durations[i]), sub))
        entries.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (
            ", ".join(frame_entries), "true" if anim.loop else "false", anim.name, _num(anim.fps)))
    lines += ["", "[resource]", "animations = [%s]" % ", ".join(entries), ""]
    return "\n".join(lines)


def _num(v: float) -> str:
    s = ("%.3f" % v).rstrip("0")
    return s + "0" if s.endswith(".") else s


def contact_sheet(rows: list[list[Canvas]], scale: int, bg: str = "sheet_bg", pad: int = 2) -> Canvas:
    """Preview helper: lays frames out in rows on a background, scaled."""
    cw = max(sum(f.w + pad for f in r) for r in rows) + pad
    ch = sum(max(f.h for f in r) + pad for r in rows) + pad
    out = Canvas(cw, ch, rgba(bg))
    y = pad
    for r in rows:
        x = pad
        for f in r:
            out.blit(f, x, y)
            x += f.w + pad
        y += max(f.h for f in r) + pad
    return out.scaled(scale)


def dist(ax: float, ay: float, bx: float, by: float) -> float:
    return math.hypot(ax - bx, ay - by)
