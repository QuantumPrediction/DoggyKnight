"""v2.5 (CR1) puppet renderer for the full art redraw. Python 3 standard library only.

A frame is built as a `Fig`: body parts (point sets from paint.ellipse / poly / thick_line / rect)
are added back to front, each with a `Mat` (a hue-shifted ramp from dark to light plus its own
coloured outline). `Fig.render()` then does what a pixel artist does by hand:

1. shading: every part is lit from the top-left like a soft solid (sphere, or a cylinder for limbs);
   the ramp is chosen per pixel with hard thresholds (no dithering on characters). Fur materials get
   2-pixel "tuft" clusters along the band edges, armour gets a small specular highlight;
2. clean-up: lone pixels inside a part take the colour of their neighbours (no single-pixel noise);
3. separation: where a part sits in front of another, the back part gets a dark line in its own
   shadow colour (softer on the lit top-left side) - selective inner outlines, not black lines;
4. outline: a 1 px coloured outline around the silhouette, the material's darkest colour, one step
   lighter on the top-left (light) side ("selout");
5. details: hand-placed pixels (eyes, nose, glints) drawn last.

Feet are planted on a fixed ground row per sprite size so every frame lines up.
"""

from __future__ import annotations

import math

from paint import ellipse, poly, rect, thick_line  # noqa: F401  (re-exported for the art modules)
from pixel import Canvas

LIGHT = (-0.55, -0.68, 0.48)
_ln = math.sqrt(sum(v * v for v in LIGHT))
LIGHT = tuple(v / _ln for v in LIGHT)


class Mat:
    """ramp: dark -> light colour names. outline: exterior outline; lit: outline on the lit side;
    spec: tiny specular colour above the top of the ramp; fur: tuft strength; sep: inner line colour."""

    def __init__(self, ramp: list[str], outline: str, lit: str | None = None, spec: str | None = None,
                 fur: float = 0.0, sep: str | None = None, sep_lit: str | None = None,
                 spec_at: float = 0.93) -> None:
        self.ramp = ramp
        self.outline = outline
        self.lit = lit or outline
        self.spec = spec
        self.fur = fur
        self.sep = sep or ramp[0]
        self.sep_lit = sep_lit or (ramp[1] if len(ramp) > 2 else ramp[0])
        self.spec_at = spec_at


def _hash(x: int, y: int, seed: int = 0) -> float:
    h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def tuft(x: int, y: int, seed: int = 0) -> float:
    """Clustered noise in [-0.5, 0.5]: 2x2 cells, staggered every other row pair (fur clumps)."""
    cy = y // 2
    cx = (x + (cy % 2)) // 2
    return _hash(cx, cy, seed) - 0.5


class Part:
    __slots__ = ("pid", "mat", "sep", "outline", "clean", "explicit")

    def __init__(self, pid: int, mat: Mat, sep: bool, outline: bool, clean: bool, explicit: bool) -> None:
        self.pid = pid
        self.mat = mat
        self.sep = sep
        self.outline = outline
        self.clean = clean
        self.explicit = explicit


class Fig:
    def __init__(self, w: int, h: int, seed: int = 0) -> None:
        self.w = w
        self.h = h
        self.seed = seed
        self.owner: dict[tuple[int, int], int] = {}
        self.col: dict[tuple[int, int], str] = {}
        self.parts: list[Part] = []
        self.details: list[tuple[int, int, object]] = []
        self.glows: list[tuple[int, int, object]] = []

    # ------------------------------------------------------------------ parts
    def add(self, shape, mat: Mat, mode: str = "sphere", bias: float = 0.0, centre=None, radius=None,
            sep: bool = True, outline: bool = True, clean: bool = True, flat: int | None = None,
            light=LIGHT, bulge: float = 1.0, contrast: float = 1.0) -> int:
        """Adds a shaded part. mode: sphere | cyl_v (limbs) | cyl_h | flat (ramp index `flat`)."""
        pid = len(self.parts)
        self.parts.append(Part(pid, mat, sep, outline, clean, False))
        pts = [p for p in shape if 0 <= p[0] < self.w and 0 <= p[1] < self.h]
        if not pts:
            return pid
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
        cx, cy = centre if centre else ((x0 + x1) / 2, (y0 + y1) / 2)
        rx, ry = radius if radius else (max(1.0, (x1 - x0) / 2), max(1.0, (y1 - y0) / 2))
        n = len(mat.ramp)
        lx, ly, lz = light
        for (x, y) in pts:
            if flat is not None:
                self.owner[(x, y)] = pid
                self.col[(x, y)] = mat.ramp[max(0, min(n - 1, flat))]
                continue
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - cy) / ry
            if mode == "cyl_v":
                ny = -0.35
            elif mode == "cyl_h":
                nx = -0.3
            nz = math.sqrt(max(0.0, 1.0 - min(1.0, nx * nx + ny * ny))) * bulge
            ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
            d = (nx * lx + ny * ly + nz * lz) / ln
            t = (d * 0.62 + 0.40) * contrast + (1 - contrast) * 0.5 + bias
            if mat.fur:
                t += mat.fur * tuft(x, y, self.seed + pid)
            if mat.spec and t > mat.spec_at + 0.12:
                c = mat.spec
            else:
                k = int(max(0.0, min(0.999, t)) * n)
                c = mat.ramp[k]
            self.owner[(x, y)] = pid
            self.col[(x, y)] = c
        return pid

    def pix(self, pixels: dict, mat: Mat, sep: bool = True, outline: bool = True) -> int:
        """Adds an explicitly coloured part ({(x, y): colour}); takes part in outline and separation."""
        pid = len(self.parts)
        self.parts.append(Part(pid, mat, sep, outline, False, True))
        for (x, y), c in pixels.items():
            if 0 <= x < self.w and 0 <= y < self.h:
                self.owner[(x, y)] = pid
                self.col[(x, y)] = c
        return pid

    def erase(self, shape) -> None:
        for p in shape:
            self.owner.pop(p, None)
            self.col.pop(p, None)

    def recolor(self, shape, col: str, only_pid: int | None = None) -> None:
        """Paints over existing part pixels (keeps ownership): folds, markings, patches."""
        for p in shape:
            if p in self.col and (only_pid is None or self.owner[p] == only_pid):
                self.col[p] = col

    def shade_toward(self, shape, mat: Mat, steps: int = -1, only_pid: int | None = None) -> None:
        """Moves existing pixels `steps` along mat.ramp (negative = darker): painted cast shadows."""
        for p in shape:
            c = self.col.get(p)
            if c is None or (only_pid is not None and self.owner[p] != only_pid):
                continue
            if c in mat.ramp:
                i = max(0, min(len(mat.ramp) - 1, mat.ramp.index(c) + steps))
                self.col[p] = mat.ramp[i]

    # --------------------------------------------------------------- details
    def dot(self, x: int, y: int, c) -> None:
        self.details.append((x, y, c))

    def dots(self, pts, c) -> None:
        for (x, y) in pts:
            self.details.append((x, y, c))

    def grid(self, rows: list[str], ox: int, oy: int, legend: dict, flip: bool = False) -> None:
        for y, row in enumerate(rows):
            if flip:
                row = row[::-1]
            for x, ch in enumerate(row):
                if ch in ". ":
                    continue
                self.details.append((ox + x, oy + y, legend[ch]))

    def glow(self, x: int, y: int, c) -> None:
        """Pixels drawn last only where the frame is still empty (soft light around a source)."""
        self.glows.append((x, y, c))

    # ---------------------------------------------------------------- render
    def render(self) -> Canvas:
        owner = self.owner
        col = dict(self.col)
        parts = self.parts
        nb4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
        # 2. clean-up: lone pixels inside a shaded part follow their neighbours
        for _ in range(2):
            changes = []
            for p, pid in owner.items():
                if not parts[pid].clean:
                    continue
                c = col[p]
                same = 0
                votes: dict[str, int] = {}
                inside = 0
                for dx, dy in nb4:
                    q = (p[0] + dx, p[1] + dy)
                    if owner.get(q) == pid:
                        inside += 1
                        if col[q] == c:
                            same += 1
                        else:
                            votes[col[q]] = votes.get(col[q], 0) + 1
                if same == 0 and inside >= 3 and votes:
                    best = max(votes.items(), key=lambda kv: kv[1])
                    if best[1] >= 2:
                        changes.append((p, best[0]))
            for p, c in changes:
                col[p] = c
            if not changes:
                break
        # 3. separation lines on the back part where a front part touches it
        sep = {}
        for p, pid in owner.items():
            part = parts[pid]
            if not part.sep:
                continue
            for dx, dy in nb4:
                q = (p[0] + dx, p[1] + dy)
                qid = owner.get(q)
                if qid is None or qid <= pid or not parts[qid].sep:
                    continue
                if parts[qid].mat is part.mat and not parts[qid].explicit and not part.explicit:
                    # same material: only a soft line, so one-material bodies stay one mass
                    c = part.mat.sep_lit if (dx > 0 or dy > 0) else part.mat.sep
                else:
                    c = part.mat.sep_lit if (dx > 0 or dy > 0) else part.mat.sep
                prev = sep.get(p)
                if prev is None or (prev == part.mat.sep_lit and c == part.mat.sep):
                    sep[p] = c
        col.update(sep)
        # 4. outline
        out = Canvas(self.w, self.h)
        for p, c in col.items():
            out.set(p[0], p[1], c)
        ring: dict[tuple[int, int], tuple[int, str]] = {}
        for p, pid in owner.items():
            part = parts[pid]
            if not part.outline:
                continue
            for dx, dy in nb4:
                q = (p[0] + dx, p[1] + dy)
                if q in owner or not (0 <= q[0] < self.w and 0 <= q[1] < self.h):
                    continue
                lit = dx < 0 or dy < 0          # the outline pixel is above / left of the shape
                c = part.mat.lit if lit else part.mat.outline
                prev = ring.get(q)
                # the front-most part wins; on ties the darker (shadow side) outline wins
                if prev is None or pid > prev[0] or (pid == prev[0] and not lit):
                    ring[q] = (pid, c)
        for q, (_, c) in ring.items():
            out.set(q[0], q[1], c)
        # 5. details and glows
        for (x, y, c) in self.details:
            out.set(x, y, c)
        for (x, y, c) in self.glows:
            if out.get(x, y) is None:
                out.set(x, y, c)
        return out


# ---------------------------------------------------------------------------
# small shape helpers
# ---------------------------------------------------------------------------

def capsule(x0: float, y0: float, x1: float, y1: float, r: float) -> set:
    return thick_line(x0, y0, x1, y1, r)


def union(*shapes) -> set:
    out = set()
    for s in shapes:
        out |= s
    return out


def minus(a: set, *bs) -> set:
    out = set(a)
    for b in bs:
        out -= b
    return out


def shift(s: set, dx: int, dy: int) -> set:
    return {(x + dx, y + dy) for (x, y) in s}


def mirror(s: set, w: int) -> set:
    return {(w - 1 - x, y) for (x, y) in s}


def line_px(x0: int, y0: int, x1: int, y1: int) -> list[tuple[int, int]]:
    from pixel import line_points
    return line_points(int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1)))


def blade(x0: float, y0: float, ang: float, length: int, width: int = 2, light: str = "white",
          mid: str = "steel_l", dark: str = "steel", tip_taper: bool = True) -> dict:
    """A straight blade from (x0, y0) along angle `ang` (radians, 0 = right, -pi/2 = up).
    Two- or three-pixel wide with a bright edge on the lit side and a darker edge on the other."""
    px: dict = {}
    dx, dy = math.cos(ang), math.sin(ang)
    nx, ny = -dy, dx               # normal; the side facing up-left is lit
    lit_sign = -1 if (nx * LIGHT[0] + ny * LIGHT[1]) < 0 else 1
    for i in range(length * 3):
        s = i / 3.0
        cx, cy = x0 + dx * s, y0 + dy * s
        w = width
        if tip_taper and s > length - 2:
            w = 1
        for k in range(w):
            off = (k - (w - 1) / 2.0)
            x = int(math.floor(cx + nx * off + 0.5))
            y = int(math.floor(cy + ny * off + 0.5))
            if w == 1:
                c = light if s > length - 1 else mid
            else:
                side = off * lit_sign
                c = light if side > 0.1 else (dark if side < -0.1 else mid)
            px.setdefault((x, y), c)
    return px


def frames_like(old_anims, new_frames: dict) -> list:
    """Builds Anim objects with the old names / speeds / loop flags / durations and new frames.
    When the new frame count differs, the speed is scaled so a loop keeps its length (loops only)."""
    from pixel import Anim
    out = []
    for a in old_anims:
        frames = new_frames[a.name]
        if len(frames) == len(a.frames):
            out.append(Anim(a.name, frames, a.fps, a.loop, list(a.durations)))
        else:
            assert a.loop, "only loops may change frame count (%s)" % a.name
            total = sum(a.durations) / a.fps
            out.append(Anim(a.name, frames, round(len(frames) / total, 3), True))
    return out
