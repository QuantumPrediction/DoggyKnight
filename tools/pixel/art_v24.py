"""v2.4 gameplay-depth art (DEV_PLAN 4.12, section 17 CV1, CV4, CV5).

Output (palette colours only; contract paths, replaced in place):
  assets/icons/tricks/<id>.png        16x16: pounce, roll, dig, sniff, play_dead, zoomies (basic tricks)
                                      and tornado_tail, lion_roar, high_five, meteor_pounce (evolutions,
                                      drawn inside a golden frame so they read as "special")
  assets/sprites/chest/chest.png      24x24 treasure chest: idle (2 frames, a glint runs over the lid),
     + chest_frames.tres              open (3 frames: lid pops, golden light spills out)
  assets/fx/snack/snack.png           8x8 bone-shaped dog biscuit: default (2 frames, a twinkle)
     + snack_frames.tres
  assets/ui/*.png                     evolution / Merlin / Morgana cards, golden ribbon, violet button,
                                      HUD snack and wave icons, evolution burst
Frame counts, loop flags and speeds of the chest and snack match the placeholders, so line A's
timings do not change.
"""

from __future__ import annotations

import math

import paint
from art_ui import L, framed
from pixel import Anim, Canvas, build_sheet, res_path

BASIC_IDS = ["pounce", "roll", "dig", "sniff", "play_dead", "zoomies"]
EVOLUTION_IDS = ["tornado_tail", "lion_roar", "high_five", "meteor_pounce"]


def _dots(c: Canvas, pts: list[tuple[int, int]], col: str) -> None:
    for (x, y) in pts:
        c.set(x, y, col)


def _fill(c: Canvas, shape: set, col: str) -> None:
    for (x, y) in shape:
        c.set(x, y, col)


# --------------------------------------------------------------------------
# Basic trick icons (16x16, same style as the v1 icons: bold shapes, 1 px ink outline)
# --------------------------------------------------------------------------

def paw(c: Canvas, cx: float, cy: float, base: str = "gold_l", shade: str = "gold", pad: str = "pink",
        small: bool = False) -> None:
    """A dog paw seen from below: a round foot with a pink pad and three toes above it."""
    r = 2.6 if small else 3.4
    foot = paint.ellipse(cx, cy, r, r * 0.9)
    _fill(c, foot, base)
    for (x, y) in foot:
        if (x + 0.5 - cx) + (y + 0.5 - cy) > r * 0.9:
            c.set(x, y, shade)
    _fill(c, paint.ellipse(cx, cy + 0.5, r * 0.62, r * 0.5), pad)
    tr = 1.1 if small else 1.35
    ty = cy - r * 0.9 - tr - (0.9 if small else 1.1)
    for dx in ((-r * 0.75, 0.0, r * 0.75)):
        toe = paint.ellipse(cx + dx, ty + (0.0 if dx == 0 else 0.7), tr, tr)
        _fill(c, toe, base)
    for dx in ((-r * 0.75, 0.0, r * 0.75)):
        c.set(int(cx + dx), int(ty + (0.0 if dx == 0 else 0.7)), pad)


def pounce_icon() -> Canvas:
    """撲擊: a paw diving down-right with speed streaks behind it and impact ticks under it."""
    c = Canvas(16, 16)
    paw(c, 9.6, 9.8)
    c.outline_all()
    c.line(1, 3, 4, 6, "sky")
    c.line(1, 7, 3, 9, "sky")
    c.line(4, 1, 6, 3, "sky")
    _dots(c, [(15, 13), (14, 15), (10, 15), (15, 10)], "orange")
    return c


def roll_icon() -> Canvas:
    """打滾: a golden furry ball rolling, a curl of motion around it, a dust puff at its feet."""
    c = Canvas(16, 16)
    ball = paint.ellipse(8.5, 7.5, 5.2, 5.2)
    paint.shade_shape(c, ball, ["cream", "gold_l", "gold", "gold_d"], sharp=3.0)
    # a spiral of darker fur that says "rolling"
    for i in range(22):
        a = i * 0.42
        rr = 0.6 + i * 0.17
        x = int(8.5 + math.cos(a) * rr)
        y = int(7.5 + math.sin(a) * rr)
        if (x, y) in ball:
            c.set(x, y, "gold_d")
    c.set(6, 5, "white")
    _fill(c, paint.ellipse(3.0, 13.5, 2.0, 1.3), "stone_l")
    _fill(c, paint.ellipse(12.5, 13.8, 1.5, 1.0), "stone_l")
    c.outline_all()
    return c


def dig_icon() -> Canvas:
    """挖寶: a bone poking out of a fresh dirt mound, dirt flying."""
    c = Canvas(16, 16)
    mound = paint.ellipse(8.0, 14.0, 7.0, 4.2)
    paint.shade_shape(c, {(x, y) for (x, y) in mound if y <= 14}, ["dirt", "brown", "brown_d"], sharp=3.0)
    # bone, diagonal
    bone = paint.thick_line(5.0, 4.0, 10.5, 10.0, 1.2)
    for (cx, cy) in ((4.4, 4.6), (5.6, 3.2), (10.0, 10.8), (11.4, 9.6)):
        bone |= paint.ellipse(cx, cy, 1.4, 1.4)
    bone = {(x, y) for (x, y) in bone if y <= 11}
    _fill(c, bone, "white")
    for (x, y) in bone:
        if (x - 5) - (y - 4) > 0:
            c.set(x, y, "stone_l")
    c.outline_all()
    _dots(c, [(1, 7), (14, 5), (13, 3), (2, 9)], "brown")
    return c


def sniff_icon() -> Canvas:
    """嗅嗅: a shiny dog nose with sniff waves and a sparkle (sharper senses: crits, pickups)."""
    c = Canvas(16, 16)
    nose = paint.ellipse(5.5, 9.0, 4.4, 3.4)
    _fill(c, nose, "brown_d")
    for (x, y) in nose:
        if y < 8:
            c.set(x, y, "brown")
    _fill(c, paint.ellipse(3.8, 9.6, 1.0, 1.2), "ink")
    _fill(c, paint.ellipse(7.2, 9.6, 1.0, 1.2), "ink")
    _dots(c, [(4, 7), (5, 7), (3, 8)], "brown")
    c.set(4, 7, "white")
    c.outline_all()
    # sniff waves to the right
    for k, y0 in enumerate((4, 8, 12)):
        for i in range(5):
            x = 10 + i
            y = y0 + (1 if (i + k) % 4 in (1, 2) else 0) - 1
            c.set(x, y, "sky")
    paint.star4(c, 13, 2, "yellow", arm=1, centre="white")
    return c


def play_dead_icon() -> Canvas:
    """裝死: a golden pup lying belly-up, paws in the air, eyes happily closed, tongue out (cute, not hurt)."""
    c = Canvas(16, 16)
    grid = [
        "..gg....gg....",
        "..gb....gb....",
        ".gccccccccgGG.",
        "gccccccccccGGb",
        "gccccccccccGob",
        ".gGGGGGGGGgGGb",
        "..bbbbbbbbb.pb",
        "............p.",
    ]
    c.stamp(grid, 1, 5, L)
    # little stars above the head (it's only acting!)
    paint.star4(c, 13, 2, "yellow", arm=1, centre="white")
    _dots(c, [(6, 2)], "yellow")
    return c


def zoomies_icon() -> Canvas:
    """暴衝: a lightning-quick paw-shaped bolt with wind lines."""
    c = Canvas(16, 16)
    grid = [
        "........YYYY..",
        ".......YYYO...",
        "......YYYO....",
        ".....YYYO.....",
        "....YYYYYYYO..",
        "......YYYYO...",
        ".....YYYO.....",
        "....YYYO......",
        "...YYO........",
        "..YO..........",
    ]
    c.stamp(grid, 1, 2, L)
    c.set(9, 3, "white")
    c.set(7, 7, "white")
    for (x0, y) in ((0, 6), (1, 9), (0, 12)):
        c.hline(x0, x0 + 2, y, "sky")
    return c


# --------------------------------------------------------------------------
# Evolution icons: golden frame + dark night inside + 10x10 picture
# --------------------------------------------------------------------------

def gold_frame() -> Canvas:
    c = framed(16, 16, "ink", "gold", "night_d", top=None, bottom=None, corner=2)
    # bevel: light on the top/left, dark on the bottom/right
    for i in range(2, 14):
        c.set(i, 1, "yellow")
        c.set(1, i, "yellow")
        c.set(i, 14, "gold_d")
        c.set(14, i, "gold_d")
    # corner gems
    for (x, y) in ((1, 1), (14, 1), (1, 14), (14, 14)):
        c.set(x, y, "white")
    # a few faint stars in the night inside
    _dots(c, [(3, 12), (12, 3)], "night")
    return c


def _framed_icon(draw) -> Canvas:
    c = gold_frame()
    pic = Canvas(16, 16)
    draw(pic)
    pic.outline_all()
    # keep the picture inside the frame
    for y in range(16):
        for x in range(16):
            if not (2 <= x <= 13 and 2 <= y <= 13):
                pic.set(x, y, None)
    c.blit(pic, 0, 0)
    return c


def tornado_tail_icon() -> Canvas:
    """旋風尾 (spin + wag): a whirlwind with a golden tail spiralling in it."""
    def draw(p: Canvas) -> None:
        rows = [(4, 3, 9), (5, 4, 8), (6, 5, 7), (7, 5, 6), (8, 6, 5), (9, 6, 4), (10, 7, 3), (11, 7, 2)]
        for (y, x0, w) in rows:
            for x in range(x0, x0 + w):
                p.set(x, y, "sky_l" if (x + y) % 3 else "white")
        for (x, y) in ((4, 4), (6, 5), (8, 6), (10, 6), (9, 8), (7, 9), (8, 10)):
            p.set(x, y, "sky")
        # golden tail curling around
        for (x, y) in ((10, 4), (11, 4), (11, 5), (12, 6), (12, 7), (11, 8), (10, 9)):
            p.set(x, y, "gold_l")
        p.set(12, 5, "gold")
        p.set(12, 3, "cream")
    return _framed_icon(draw)


def lion_roar_icon() -> Canvas:
    """獅王吼 (bark + sit): a golden pup with a fluffy lion mane, roaring a big wave."""
    def draw(p: Canvas) -> None:
        mane = paint.ellipse(6.5, 8.0, 4.0, 4.2)
        _fill(p, mane, "orange")
        for (x, y) in mane:
            if (x + y) % 3 == 0:
                p.set(x, y, "gold")
        face = paint.ellipse(6.6, 8.2, 2.5, 2.6)
        _fill(p, face, "gold_l")
        _dots(p, [(5, 7), (7, 7)], "ink")
        _dots(p, [(6, 9), (7, 9)], "red_d")
        p.set(6, 10, "pink")
        # roar waves
        for (x, y) in ((11, 6), (12, 7), (12, 8), (12, 9), (11, 10)):
            p.set(x, y, "white")
        for (x, y) in ((11, 8),):
            p.set(x, y, "yellow")
    return _framed_icon(draw)


def high_five_icon() -> Canvas:
    """擊掌連打 (shake + fetch): two paws meeting in a spark."""
    def draw(p: Canvas) -> None:
        paw(p, 4.6, 10.4, small=True)
        paw(p, 11.4, 10.4, small=True)
        paint.star4(p, 8, 4, "yellow", arm=2, centre="white")
    return _framed_icon(draw)


def meteor_pounce_icon() -> Canvas:
    """流星撲擊 (pounce + zoomies): a paw falling like a meteor with a fiery tail."""
    def draw(p: Canvas) -> None:
        for i in range(6):
            x, y = 3 + i, 3 + i
            p.set(x, y, "red" if i < 2 else ("orange" if i < 4 else "yellow"))
            p.set(x + 1, y, "orange" if i < 3 else "yellow")
            p.set(x, y + 1, "orange" if i < 3 else "yellow")
        paw(p, 9.8, 10.2, small=True)
    return _framed_icon(draw)


ICONS = {
    "pounce": pounce_icon, "roll": roll_icon, "dig": dig_icon, "sniff": sniff_icon,
    "play_dead": play_dead_icon, "zoomies": zoomies_icon,
    "tornado_tail": tornado_tail_icon, "lion_roar": lion_roar_icon, "high_five": high_five_icon,
    "meteor_pounce": meteor_pounce_icon,
}


# --------------------------------------------------------------------------
# Treasure chest 24x24 (assets/sprites/chest): idle 2 frames, open 3 frames
# --------------------------------------------------------------------------

def _chest_body(c: Canvas, inside: bool) -> None:
    """Front of the chest, y 11..20; with inside=True the top row shows the treasure inside."""
    for y in range(11, 21):
        for x in range(3, 21):
            col = "brown"
            if y in (14, 17):
                col = "brown_d"          # plank seams
            if y == 11 and not inside:
                col = "dirt"             # highlight under the lid
            if x in (6, 17):
                col = "gold" if y < 20 else "gold_d"
            if y == 20:
                col = "brown_d" if x not in (6, 17) else "gold_d"
            c.set(x, y, col)
    if inside:
        c.hline(4, 19, 11, "brown_d")
        _dots(c, [(7, 11), (9, 11), (12, 11), (15, 11), (8, 10), (13, 10), (11, 10)], "yellow")
        _dots(c, [(10, 11), (14, 11), (10, 10)], "gold_l")
    # lock plate and keyhole
    for y in range(12 if inside else 9, 15):
        for x in range(10, 14):
            c.set(x, y, "gold_l" if y < 13 else "gold")
    c.set(11, 13, "ink")
    c.set(11, 14, "ink")
    c.set(10, 12 if inside else 9, "cream")


def _chest_lid(c: Canvas, dy: int = 0) -> None:
    """Closed rounded lid, y 5..10 (+dy)."""
    rows = [(5, 5, 18), (6, 4, 19), (7, 3, 20), (8, 3, 20), (9, 3, 20), (10, 3, 20)]
    for (y, x0, x1) in rows:
        for x in range(x0, x1 + 1):
            col = "brown"
            if y == 5 or (y == 6 and x < 10):
                col = "dirt"
            if y == 10:
                col = "brown_d"
            if x in (6, 17):
                col = "gold_l" if y < 8 else "gold"
            c.set(x, y + dy, col)


def _chest_open_lid(c: Canvas, top: int) -> None:
    """Lid flipped open behind the chest: we see its dark inside, rows top..top+3."""
    for y in range(top, top + 4):
        x0 = 4 if y == top else 3
        x1 = 19 if y == top else 20
        for x in range(x0, x1 + 1):
            col = "brown_d" if y > top else "brown"
            if x in (6, 17):
                col = "gold"
            c.set(x, y, col)


def _shadow(c: Canvas) -> None:
    for x in range(3, 21):
        a = 110 if 5 <= x <= 18 else 60
        if c.get(x, 22) is None:
            c.set(x, 22, paint.P_ALPHA("ink", a))


def _beam(c: Canvas, height: int, spread: int, strong: bool) -> None:
    """Golden light pouring up out of the chest (soft, translucent, palette colours)."""
    base_y = 5
    for y in range(max(0, base_y - height), base_y + 1):
        k = (base_y - y) / max(1, height)
        half = 6 + spread * k
        for x in range(24):
            d = abs(x + 0.5 - 12.0)
            if d <= half and c.get(x, y) is None:
                core = d < half * 0.45
                a = int((240 if strong else 190) * (1 - k * 0.7) * (1.0 if core else 0.55))
                c.set(x, y, paint.P_ALPHA("yellow" if core else "gold_l", max(30, a)))


def chest() -> list[Anim]:
    idle = []
    for glint in (False, True):
        c = Canvas(24, 24)
        _chest_lid(c)
        _chest_body(c, inside=False)
        c.outline_all()
        if glint:
            paint.star4(c, 5, 5, "white", arm=1)
            c.set(8, 5, "cream")
            c.set(19, 13, "cream")
        _shadow(c)
        idle.append(c)
    opened = []
    # 1: the lid pops up a little, light leaks out of the gap
    c = Canvas(24, 24)
    _chest_lid(c, dy=-3)
    _chest_body(c, inside=False)
    c.outline_all()
    c.hline(4, 19, 8, "yellow")
    c.hline(5, 18, 9, "gold_l")
    _dots(c, [(2, 6), (21, 5), (12, 1)], "yellow")
    _shadow(c)
    opened.append(c)
    # 2 and 3: lid flung back, a column of golden light and sparkles
    for strong in (False, True):
        c = Canvas(24, 24)
        _chest_open_lid(c, 6)
        _chest_body(c, inside=True)
        c.outline_all()
        _beam(c, 5, 4 if strong else 2, strong)
        if strong:
            paint.star4(c, 4, 3, "white", arm=1, centre="yellow")
            paint.star4(c, 19, 1, "white", arm=1, centre="yellow")
            _dots(c, [(12, 0), (8, 2), (16, 4)], "white")
        else:
            _dots(c, [(9, 2), (15, 1)], "white")
        _shadow(c)
        opened.append(c)
    return [Anim("idle", idle, 3.0, True), Anim("open", opened, 10.0, False)]


# --------------------------------------------------------------------------
# Snack 8x8 (assets/fx/snack): a bone-shaped dog biscuit, default 2 frames (twinkle)
# --------------------------------------------------------------------------

SNACK = [
    "gg..gg",
    "cgbggG",
    ".gggG.",
    "gG..GG",
]


def snack() -> list[Anim]:
    frames = []
    for twinkle in (False, True):
        c = Canvas(8, 8)
        c.stamp(SNACK, 1, 2, {"g": "gold_l", "G": "gold", "b": "brown", "c": "cream"})
        c.set(1, 2, "cream")
        if twinkle:
            c.set(6, 1, "white")
            c.set(7, 0, "yellow")
            c.set(1, 2, "white")
        frames.append(c)
    return [Anim("default", frames, 4.0, True)]


# --------------------------------------------------------------------------
# Interface textures (9-slice styles registered in ui/theme/main_theme.tres by art_ui.theme_tres)
# --------------------------------------------------------------------------

def ribbon(body: str, edge: str, light: str) -> Canvas:
    """24x14 ribbon banner (same shape as art_ui's red ribbon)."""
    rib = Canvas(24, 14)
    for side in (0, 1):
        tail = Canvas(6, 10)
        tail.stamp(["rrrrr", "rrrrr", ".rrrr", "..rrr", ".rrrr", "rrrrr"], 0, 2, {"r": edge})
        if side:
            tail = tail.flipped()
        rib.blit(tail, 0 if side == 0 else 18, 2)
    rib.blit(framed(18, 10, "ink", edge, body, top=light, bottom=edge, corner=2), 3, 2)
    return rib


def card(outline: str, border: str, fill: str, top: str | None, bottom: str | None,
         sparkle: str | None = None) -> Canvas:
    c = framed(16, 16, outline, border, fill, top=top, bottom=bottom, corner=3)
    if sparkle:
        c.set(2, 2, sparkle)
        c.set(13, 2, sparkle)
    return c


HUD_ICONS_V24: dict[str, list[str]] = {
    "icon_snack": [         # the biscuit, HUD size
        "gg.gg..",
        "gggggg.",
        ".gbgbG.",
        ".gggG..",
        ".gggGG.",
        "gg..GG.",
        ".......",
    ],
    "icon_wave": [          # a little pennant: wave number in endless mode
        "zRR....",
        "zRRRR..",
        "zRRRRRR",
        "zRRRR..",
        "zRR....",
        "z......",
        "z......",
    ],
    "icon_trophy": [        # best record
        "YYYYYYY",
        "YgYYYGY",
        ".YgYYG.",
        "..YYG..",
        "...G...",
        "..GGG..",
        ".bbbbb.",
    ],
}


def ui_textures() -> dict[str, Canvas]:
    t: dict[str, Canvas] = {}
    # 「進化!」 trick card: rich gold with a yellow inner border and two corner sparkles
    t["card_evolve_normal"] = card("ink", "orange", "gold_l", "yellow", "gold", sparkle="white")
    t["card_evolve_pressed"] = card("ink", "orange", "gold", "gold_l", None, sparkle="white")
    # choice event cards: Merlin warm blue, Morgana mysterious purple (DEV_PLAN 17 CV3, docs/STORY.md)
    t["card_merlin_normal"] = card("ink", "water", "sky_l", "white", "sky", sparkle="yellow")
    t["card_merlin_pressed"] = card("ink", "water", "sky", "sky_l", None, sparkle="yellow")
    t["card_morgana_normal"] = card("ink", "violet", "plum", "dusk", "ink", sparkle="lilac")
    t["card_morgana_pressed"] = card("ink", "lilac", "dusk", "violet", None, sparkle="lilac")
    # golden ribbon for the 「進化!」 badge; violet button for 「無盡試煉」
    t["ribbon_gold"] = ribbon("orange", "gold_d", "yellow")
    t["button_violet_normal"] = framed(16, 16, "ink", "plum", "violet", top="lilac", bottom="dusk", corner=3)
    t["button_violet_pressed"] = framed(16, 16, "ink", "plum", "dusk", top="violet", bottom=None, corner=3)
    for name, grid in HUD_ICONS_V24.items():
        c = Canvas(9, 9)
        c.stamp(grid, 1, 1, L)
        t[name] = c
    return t


def write_all() -> None:
    for tid, fn in ICONS.items():
        fn().save(res_path("res://assets/icons/tricks/%s.png" % tid))
    build_sheet("res://assets/sprites/chest", "chest", chest(), (24, 24))
    build_sheet("res://assets/fx/snack", "snack", snack(), (8, 8))
    for name, img in ui_textures().items():
        img.save(res_path("res://assets/ui/%s.png" % name))
