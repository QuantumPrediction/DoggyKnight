"""Trick icons (C9) and interface textures (C8, C10, C11): 9-slice buttons/panels, HUD icons.

Output (all PNG, palette colours only):
  assets/icons/tricks/<id>.png    16x16, contract path (DEV_PLAN 4.9)
  assets/ui/*.png                 used by ui/theme/main_theme.tres and the UI scenes
"""

from __future__ import annotations

import math

from pixel import Canvas, res_path

L = {
    "o": "ink", "w": "white", "c": "cream", "g": "gold_l", "G": "gold", "b": "gold_d", "B": "brown",
    "n": "brown_d", "R": "red", "r": "red_d", "p": "pink", "Y": "yellow", "y": "gold_l", "O": "orange",
    "l": "leaf", "L": "leaf_d", "s": "sky", "S": "sky_l", "u": "water", "U": "water_d", "v": "violet",
    "V": "lilac", "P": "plum", "t": "stone", "T": "stone_d", "k": "stone_l", "z": "steel", "Z": "steel_l",
}

# --------------------------------------------------------------------------
# Trick icons 16x16 (content 14x14 + 1 px outline)
# --------------------------------------------------------------------------

TRICKS: dict[str, list[str]] = {
    "wag": [
        "..........gg..",
        ".........gGGg.",
        "..w.....gGGGb.",
        ".w.....gGGGb..",
        "w.....gGGGb...",
        "w....gGGGb....",
        "w...gGGGb.....",
        ".w..gGGb......",
        "..w.gGGb......",
        "....gGGb......",
        ".....gGGb.....",
        "......gGGbb...",
        ".......bbb....",
        "..............",
    ],
    "fetch": [
        "..........w...",
        ".........w.w..",
        "..........w...",
        "..........BB..",
        ".........BBn..",
        "......llBBn...",
        "......LlBn....",
        ".......BBn....",
        "......BBn.....",
        ".....BBn......",
        "....BBn.......",
        "...BBn........",
        "..BBn.........",
        "..nn..........",
    ],
    "shake": [
        "...gg....gg...",
        "..gppg..gppg..",
        "..gppg..gppg..",
        "gg.gg....gg.gg",
        "ppg........gpp",
        "ppg.gggggg.gpp",
        ".g.gggggggg.g.",
        "..gggppppggg..",
        ".ggppppppppgG.",
        ".ggppppppppGG.",
        ".gGppppppppGG.",
        "..GGppppppGGb.",
        "...GGGGGGGGb..",
        "....bbbbbbb...",
    ],
    "bark": [
        "......w.......",
        "..w..www..w...",
        "...wwwwwwww...",
        "..wwwwRRwwww..",
        "wwwwwwRRwwwwww",
        ".wwwwwRRwwwww.",
        "..wwwwRRwwww..",
        ".wwwwwwwwwwww.",
        "wwwwwwRRwwwwww",
        "..wwwwRRwwww..",
        "...wwwwwwww...",
        "..w..www..w...",
        "......w.......",
        "..............",
    ],
}


def spin_icon() -> Canvas:
    c = Canvas(16, 16)
    cx, cy = 8.0, 8.0
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            a = math.degrees(math.atan2(dy, dx))
            if 3.6 <= r <= 6.4 and not (-75 < a < -15):
                c.set(x, y, "white" if r > 5.2 else "yellow")
    # arrowhead at the end of the sweep (top right), pointing clockwise
    for (x, y) in [(11, 1), (12, 2), (13, 3), (12, 3), (11, 3), (10, 3), (11, 2), (12, 4), (13, 4), (13, 5)]:
        c.set(x, y, "yellow")
    c.set(12, 3, "white")
    c.ellipse(8, 8, 1.6, 1.6, "orange")
    c.outline_all()
    return c


PAW_PRINT = [
    "..cc.cc..",
    "..cc.cc..",
    "cc.....cc",
    "cc.ccc.cc",
    "..ccccc..",
    ".ccccccc.",
    ".ccccccc.",
    "..ccccc..",
]


def sit_icon() -> Canvas:
    """A plump red cushion with a paw print: 坐下."""
    c = Canvas(16, 16)
    c.stamp(["Y............Y", ".Y..........Y."], 1, 12, L, outline=None)
    cushion = framed(14, 12, "ink", None, "red", top="pink", bottom="red_d", corner=3)
    c.blit(cushion, 1, 2)
    c.stamp(PAW_PRINT, 3, 4, L, outline=None)
    return c


def trick_icon(trick_id: str) -> Canvas:
    if trick_id == "spin":
        return spin_icon()
    if trick_id == "sit":
        return sit_icon()
    c = Canvas(16, 16)
    c.stamp(TRICKS[trick_id], 1, 1, L)
    return c


TRICK_IDS = ["sit", "wag", "fetch", "shake", "spin", "bark"]

# --------------------------------------------------------------------------
# HUD icons 9x9 (content 7x7 + outline)
# --------------------------------------------------------------------------

HUD_ICONS: dict[str, list[str]] = {
    "icon_heart": [
        ".RR.RR.",
        "RwRRRRR",
        "RRRRRRR",
        "RRRRRRr",
        ".RRRRr.",
        "..RRr..",
        "...r...",
    ],
    "icon_exp": [
        "..sss..",
        ".sSSss.",
        "sSwSsss",
        "sSSssss",
        "ssssssu",
        ".sssuu.",
        "..uuu..",
    ],
    "icon_paw": [
        ".g...g.",
        "gGg.gGg",
        ".g.g.g.",
        "..ggg..",
        ".gGGGg.",
        ".GGGGG.",
        "..bbb..",
    ],
    "icon_sound_on": [
        "...g...",
        "..gg.w.",
        "gggg..w",
        "gggg.ww",
        "gggg..w",
        "..gg.w.",
        "...g...",
    ],
    "icon_sound_off": [
        "...t...",
        "..tt...",
        "tttt.R.",
        "tttt..R",
        "tttt.R.",
        "..tt...",
        "...t...",
    ],
    "icon_pause": [
        ".......",
        ".ww.ww.",
        ".ww.ww.",
        ".ww.ww.",
        ".ww.ww.",
        ".ww.ww.",
        ".......",
    ],
}


def hud_icon(name: str) -> Canvas:
    c = Canvas(9, 9)
    c.stamp(HUD_ICONS[name], 1, 1, L)
    return c


# --------------------------------------------------------------------------
# 9-slice textures (Godot StyleBoxTexture, margins noted in main_theme.tres)
# --------------------------------------------------------------------------

# v2.5 (CR3): coloured outlines matched to each face colour (not black), bevelled borders lit from the
# top-left, a lit left edge and a darker lip at the bottom, all 9-slice safe (stretch rows/columns stay uniform).
FRAME_OUTLINE = {
    "gold_l": "umber", "gold": "umber", "orange": "umber", "cream": "umber", "stone": "slate", "sky": "navy",
    "sky_l": "navy", "water": "navy", "red": "wine", "plum": "ink", "violet": "ink", "dusk": "ink",
    "night_d": "ink",
}
FRAME_DARKER = {
    "gold_d": "brown", "gold": "gold_d", "brown": "brown_d", "brown_d": "umber", "stone_d": "slate",
    "water_d": "night", "water": "water_d", "violet": "plum", "plum": "ink", "red_d": "wine", "orange": "gold_d",
    "lilac": "violet", "yellow": "gold", "sky": "water", "white": "fog",
}


def framed(w: int, h: int, outline: str, border: str | None, fill: str, top: str | None = None,
           bottom: str | None = None, corner: int = 2, inner_glint: str | None = None) -> Canvas:
    """Rounded pixel box: coloured outline, bevelled 1 px inner border (light top-left, dark bottom-right),
    fill with a top highlight row, a lit left column and a 2 px bottom lip (the button's depth)."""
    base_fill = fill.split("@")[0]
    if outline == "ink" and base_fill in FRAME_OUTLINE:
        outline = FRAME_OUTLINE[base_fill]
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            cx = min(x, w - 1 - x)
            cy = min(y, h - 1 - y)
            if cx + cy < corner - 1:
                continue
            edge = cx == 0 or cy == 0 or cx + cy == corner - 1
            if edge:
                c.set(x, y, outline)
            elif border and (cx == 1 or cy == 1 or cx + cy == corner):
                dark_side = (x > w // 2 and cx <= cy) or (y > h // 2 and cy <= cx)
                c.set(x, y, FRAME_DARKER.get(border, border) if dark_side else border)
            else:
                c.set(x, y, fill)
    inset = 2 if border else 1
    if top:
        for x in range(inset + 1, w - inset - 1):
            c.set(x, inset, top)
        if "@" not in fill:
            for y in range(inset + 1, h - inset - (3 if bottom and h > 12 else 2)):
                c.set(inset, y, top)
    if bottom:
        for x in range(inset, w - inset):
            c.set(x, h - inset - 1, bottom)
            if h > 12:
                c.set(x, h - inset - 2, FRAME_DARKER.get(bottom, bottom) if False else bottom)
        if h > 12 and "@" not in fill:
            for x in range(inset + 1, w - inset - 1):
                c.set(x, h - inset - 3, fill)
    glint = inner_glint or (("white" if top else None) if "@" not in fill else None)
    if glint and w >= 10 and h >= 10:
        c.set(inset + 1, inset + 1, glint)
        c.set(inset + 2, inset + 1, glint)
    return c


def ui_textures() -> dict[str, Canvas]:
    t: dict[str, Canvas] = {}
    # Buttons 16x16 (margins 4); pressed variant has the face shifted down (shadow gone).
    t["button_normal"] = framed(16, 16, "ink", "gold_d", "gold_l", top="cream", bottom="gold", corner=3)
    t["button_pressed"] = framed(16, 16, "ink", "gold_d", "gold", top="gold_l", bottom=None, corner=3)
    t["button_disabled"] = framed(16, 16, "ink", "stone_d", "stone", top="stone_l", bottom="stone_d", corner=3)
    t["button_alt_normal"] = framed(16, 16, "ink", "water_d", "sky", top="sky_l", bottom="water", corner=3)
    t["button_alt_pressed"] = framed(16, 16, "ink", "water_d", "water", top="sky", bottom=None, corner=3)
    # Panels 16x16 (margins 5)
    t["panel"] = framed(16, 16, "ink", "brown", "cream", top="white", bottom="gold_l", corner=3)
    t["panel_dark"] = framed(16, 16, "ink", "violet", "plum", top=None, bottom=None, corner=3)
    t["card_normal"] = framed(16, 16, "ink", "gold_d", "cream", top="white", bottom="gold_l", corner=3)
    t["card_pressed"] = framed(16, 16, "ink", "orange", "gold_l", top="cream", bottom=None, corner=3)
    t["chip"] = framed(8, 8, "ink", None, "plum@200", corner=2)
    # Ribbon banner 24x14 (margins left/right 8)
    rib = Canvas(24, 14)
    rib.stamp([
        "..........................",
    ][0:0], 0, 0)
    body = framed(18, 10, "ink", "red_d", "red", top="pink", bottom="red_d", corner=2)
    for side in (0, 1):
        tail = Canvas(6, 10)
        tail.stamp([
            "rrrrr",
            "rrrrr",
            ".rrrr",
            "..rrr",
            ".rrrr",
            "rrrrr",
        ], 0, 2, {"r": "red_d"})
        if side:
            tail = tail.flipped()
        rib.blit(tail, 0 if side == 0 else 18, 2)
    rib.blit(body, 3, 2)
    t["ribbon"] = rib
    # Bars: frame 6x8 (margins 2) + fills are drawn by code in ui/hud/pixel_bar.gd
    return t


def level_badge() -> Canvas:
    """Shield-shaped badge behind the hero level number (22x22)."""
    c = Canvas(22, 22)
    grid = [
        "..oooooooooooooooo..",
        ".obbbbbbbbbbbbbbbbo.",
        "obgggggggggggggggbbo",
        "obgcccggggggggggggbo",
        "obgcggggggggggggggbo",
        "obggggggggggggggggbo",
        "obggggggggggggggggbo",
        "obggggggggggggggggbo",
        "obggggggggggggggggbo",
        "obggggggggggggggggbo",
        "obggggggggggggggggbo",
        "obggggggggggggggggbo",
        ".obggggggggggggggbo.",
        ".obggggggggggggggbo.",
        "..obggggggggggggbo..",
        "...obggggggggggbo...",
        "....obbggggggbbo....",
        ".....oobbbbbboo.....",
        ".......oooooo.......",
    ]
    c.stamp(grid, 1, 1, {"o": "ink", "b": "gold_d", "g": "gold", "c": "gold_l"}, outline=None)
    return c


def ultimate_button(pressed: bool) -> Canvas:
    """Round 32x32 button with Excalibur on it (王者之劍)."""
    c = Canvas(32, 32)
    c.ellipse(16, 16, 15.5, 15.5, "ink")
    c.ellipse(16, 16, 14.5, 14.5, "gold_d" if not pressed else "orange")
    c.ellipse(16, 16, 13, 13, "red" if not pressed else "red_d")
    c.ellipse(15, 14, 10, 10, "red" if not pressed else "red_d")
    for (x, y) in [(8, 7), (7, 9), (9, 6)]:
        c.set(x, y, "pink")
    # sword pointing up-right
    s = Canvas(32, 32)
    hx, hy = 12, 20
    for i in range(1, 12):
        s.set(hx + i, hy - i, "white")
        if i < 11:
            s.set(hx + i + 1, hy - i, "steel_l")
    for k in (-2, -1, 1, 2):
        s.set(hx + k, hy + k, "yellow")
    s.set(hx, hy, "gold_d")
    s.set(hx - 1, hy + 1, "brown_d")
    s.set(hx - 2, hy + 2, "brown_d")
    s.set(hx - 3, hy + 3, "yellow")
    s.outline_all()
    c.blit(s, 0, 1 if pressed else 0)
    for (x, y) in [(24, 6), (25, 5), (23, 5), (24, 4)]:
        c.set(x, y, "yellow")
    c.set(24, 5, "white")
    return c


HUD_ICONS.update({
    "icon_boss": [          # the black knight's helm with its glowing visor
        "..iii..",
        ".iZZzi.",
        "iZzzzzi",
        "iOYOYOi",
        "izzzzzi",
        ".izzzi.",
        "..iii..",
    ],
    "icon_music_on": [
        "...www.",
        "...w.ww",
        "...w..w",
        "...w...",
        ".www...",
        "wwww...",
        ".ww....",
    ],
    "icon_music_off": [
        "...ttt.",
        "...t.tt",
        "R..t..R",
        ".R.t.R.",
        ".ttRt..",
        "ttRtR..",
        ".R...R.",
    ],
    "icon_vibrate_on": [
        "w.ttt.w",
        "w.tSt.w",
        ".wtSt w",
        "w.tSt.w",
        "w.tSt.w",
        "..ttt..",
        "...t...",
    ],
    "icon_vibrate_off": [
        "R.ttt..",
        ".RtSt..",
        "..RSt..",
        "..tRt..",
        "..tSR..",
        "..ttt R",
        "...t...",
    ],
})
L["i"] = "iron"


def star_icon(size: int, filled: bool) -> Canvas:
    """Five-pointed star for the results screen (filled gold or an empty socket)."""
    c = Canvas(size, size)
    cx, cy = size / 2, size / 2 + size * 0.04
    r_out, r_in = size * 0.47, size * 0.2
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = r_out if k % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))

    def inside(px: float, py: float) -> bool:
        n = len(pts)
        hit = False
        for i in range(n):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % n]
            if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / (y2 - y1) + x1:
                hit = not hit
        return hit

    for y in range(size):
        for x in range(size):
            if inside(x + 0.5, y + 0.5):
                if filled:
                    light = (x + 0.5 - cx) * -0.6 + (y + 0.5 - cy) * -0.8
                    col = "yellow" if light > size * 0.08 else ("gold_l" if light > -size * 0.12 else "gold")
                    c.set(x, y, col)
                else:
                    c.set(x, y, "plum")
    if filled:
        c.set(int(cx - size * 0.12), int(cy - size * 0.16), "white")
        c.set(int(cx - size * 0.12), int(cy - size * 0.16) + 1, "cream")
        c.outline_all("brown_d")
    else:
        c.outline_all("ink")
    return c


def finger_pointer(pressed: bool) -> Canvas:
    """A friendly white glove pointing up (tutorial). 16x20; pressed = squashed a bit."""
    grid = [
        "....ww......",
        "...wwww.....",
        "...wwww.....",
        "...wwww.....",
        "...wwwwww...",
        "...wwwwwwww.",
        ".w.wwwwwwwww",
        "wwwwwwwwwwww",
        "wwwwwwwwwwwk",
        ".wwwwwwwwwwk",
        "..wwwwwwwwk.",
        "...wwwwwwk..",
        "...wwwwwwk..",
        "...RRRRRRr..",
        "...RRRRRRr..",
    ]
    if pressed:
        grid = grid[:5] + grid[6:]
    c = Canvas(16, 20)
    c.stamp(grid, 2, 2 if not pressed else 3, {"w": "white", "k": "stone_l", "R": "red", "r": "red_d"})
    return c


def cutin_portrait() -> Canvas:
    """Goldie's determined face for the ultimate cut-in (64x64, from the app icon portrait)."""
    import art_brand
    face = art_brand.icon_character()
    # determined brows over both eyes
    for (x, y) in ((10, 10), (11, 10), (12, 10), (13, 11), (21, 10), (20, 10), (19, 10), (18, 11)):
        face.set(x, y, "brown_d")
    return face.scaled(2)


def hud_plate() -> Canvas:
    """Translucent dark plate behind the HUD bars (9-slice, margins 4)."""
    return framed(12, 12, "ink@200", None, "ink@120", corner=3)


def combo_burst() -> Canvas:
    """Spiky burst behind the combo number (32x24)."""
    c = Canvas(34, 26)
    cx, cy = 17, 13
    for y in range(26):
        for x in range(34):
            a = math.atan2(y + 0.5 - cy, (x + 0.5 - cx) * 0.75)
            r = math.hypot((x + 0.5 - cx) * 0.75, y + 0.5 - cy)
            spike = 9.5 + 2.6 * (1 if int((a + math.pi) / (2 * math.pi) * 14) % 2 == 0 else -0.4)
            if r < spike:
                c.set(x, y, "orange" if r > spike - 2.2 else "yellow")
    c.outline_all("red_d")
    return c


# --------------------------------------------------------------------------
# v2.3 dialogue box (CS1): ornate parchment panel, portrait frame, name plate, storybook page
# --------------------------------------------------------------------------

def dialogue_panel() -> Canvas:
    """24x24 9-slice (margins 8): ink outline, brown and gold double border, gold corner studs,
    cream parchment with a soft inner shade."""
    c = framed(24, 24, "ink", "brown_d", "cream", top="white", bottom=None, corner=3)
    for i in range(2, 22):
        c.set(i, 2, "gold")
        c.set(i, 21, "gold")
        c.set(2, i, "gold")
        c.set(21, i, "gold")
    for i in range(3, 21):
        c.set(i, 20, "gold_l")
        c.set(20, i, "gold_l")
        c.set(i, 3, "white")
        c.set(3, i, "white")
    for (x, y) in ((2, 2), (21, 2), (2, 21), (21, 21)):
        c.set(x, y, "brown_d")
    for (cx, cy) in ((4, 4), (19, 4), (4, 19), (19, 19)):
        for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            c.set(cx + dx, cy + dy, "gold_d")
        c.set(cx, cy, "yellow")
    return c


def portrait_frame() -> Canvas:
    """52x52 frame around a 48x48 portrait: ink, gold bevel, ink; rivets in the corners."""
    c = Canvas(52, 52)
    for y in range(52):
        for x in range(52):
            d = min(x, y, 51 - x, 51 - y)
            if d == 0:
                c.set(x, y, "ink")
            elif d == 1:
                c.set(x, y, "gold_l" if x < 51 - y else "gold_d")
    for (x, y) in ((1, 1), (50, 1), (1, 50), (50, 50)):
        c.set(x, y, "yellow")
    for (x, y) in ((0, 0), (51, 0), (0, 51), (51, 51)):
        c.set(x, y, None)
    return c


def name_plate() -> Canvas:
    """16x14 9-slice (margins 5): plum plate with a gold rim, for the speaker's name."""
    c = framed(16, 14, "ink", "gold", "plum", top="violet", bottom="night_d", corner=2)
    return c


def page_frame() -> Canvas:
    """168x128 ornate frame for a 160x120 storybook illustration (transparent centre)."""
    w, h = 168, 128
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            col = {0: "ink", 1: "gold_d", 2: "gold", 3: "ink"}.get(d)
            if col:
                c.set(x, y, col)
    for x in range(2, w - 2, 6):
        c.set(x, 2, "yellow")
        c.set(x, h - 3, "gold_l")
    for y in range(2, h - 2, 6):
        c.set(2, y, "yellow")
        c.set(w - 3, y, "gold_l")
    # corner flourishes
    for (cx, cy, sx, sy) in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)):
        for (dx, dy, col) in ((1, 1, "yellow"), (2, 2, "gold"), (3, 1, "gold"), (1, 3, "gold"), (4, 4, "gold_d"),
                              (5, 4, "gold"), (4, 5, "gold"), (5, 5, "yellow")):
            c.set(cx + sx * dx, cy + sy * dy, col)
    return c


def next_arrow() -> Canvas:
    c = Canvas(9, 7)
    c.stamp(["ggggg", ".ggg.", "..g.."], 2, 2, {"g": "gold_d"})
    c.set(4, 2, "yellow")
    c.set(5, 2, "yellow")
    return c


def hard_badge() -> Canvas:
    """16x14 9-slice (margins 5): the red 「困難」 badge on the results screen."""
    return framed(16, 14, "ink", "yellow", "red", top="pink", bottom="red_d", corner=2)


def write_dialogue_textures() -> None:
    hard_badge().save(res_path("res://assets/ui/badge_hard.png"))
    dialogue_panel().save(res_path("res://assets/ui/dialogue_panel.png"))
    portrait_frame().save(res_path("res://assets/ui/portrait_frame.png"))
    name_plate().save(res_path("res://assets/ui/name_plate.png"))
    page_frame().save(res_path("res://assets/ui/page_frame.png"))
    next_arrow().save(res_path("res://assets/ui/next_arrow.png"))


def write_all() -> list[str]:
    out = []
    write_dialogue_textures()
    star_icon(16, True).save(res_path("res://assets/ui/star_full.png"))
    star_icon(16, False).save(res_path("res://assets/ui/star_empty.png"))
    star_icon(26, True).save(res_path("res://assets/ui/star_big_full.png"))
    star_icon(26, False).save(res_path("res://assets/ui/star_big_empty.png"))
    star_icon(10, True).save(res_path("res://assets/ui/star_small_full.png"))
    star_icon(10, False).save(res_path("res://assets/ui/star_small_empty.png"))
    finger_pointer(False).save(res_path("res://assets/ui/finger.png"))
    finger_pointer(True).save(res_path("res://assets/ui/finger_pressed.png"))
    cutin_portrait().save(res_path("res://assets/ui/cutin_goldie.png"))
    hud_plate().save(res_path("res://assets/ui/hud_plate.png"))
    combo_burst().save(res_path("res://assets/ui/combo_burst.png"))
    for tid in TRICK_IDS:
        p = res_path("res://assets/icons/tricks/%s.png" % tid)
        trick_icon(tid).save(p)
        out.append(p)
    for name in HUD_ICONS:
        p = res_path("res://assets/ui/%s.png" % name)
        hud_icon(name).save(p)
        out.append(p)
    for name, img in ui_textures().items():
        p = res_path("res://assets/ui/%s.png" % name)
        img.save(p)
        out.append(p)
    level_badge().save(res_path("res://assets/ui/level_badge.png"))
    ultimate_button(False).save(res_path("res://assets/ui/ultimate_normal.png"))
    ultimate_button(True).save(res_path("res://assets/ui/ultimate_pressed.png"))
    return out


# --------------------------------------------------------------------------
# ui/theme/main_theme.tres (generated so its colours always match the palette)
# --------------------------------------------------------------------------

def _col(name: str, alpha: float = 1.0) -> str:
    from palette import rgba
    r, g, b, _ = rgba(name)
    return "Color(%.4f, %.4f, %.4f, %.2f)" % (r / 255, g / 255, b / 255, alpha)


def theme_tres() -> str:
    tex = [
        ("button_normal", 4, (6, 3, 6, 5)), ("button_pressed", 4, (6, 4, 6, 4)),
        ("button_disabled", 4, (6, 3, 6, 5)), ("button_alt_normal", 4, (6, 3, 6, 5)),
        ("button_alt_pressed", 4, (6, 4, 6, 4)), ("panel", 5, (8, 7, 8, 7)),
        ("panel_dark", 5, (6, 5, 6, 5)), ("card_normal", 5, (6, 5, 6, 5)), ("card_pressed", 5, (6, 6, 6, 4)),
        ("ribbon", 6, (10, 3, 10, 4)), ("ribbon_big", 6, (16, 6, 16, 8)),
        # v2.4 (art_v24.py): evolution card, choice-event cards, golden ribbon, violet button
        ("card_evolve_normal", 5, (6, 5, 6, 5)), ("card_evolve_pressed", 5, (6, 6, 6, 4)),
        ("card_merlin_normal", 5, (6, 5, 6, 5)), ("card_merlin_pressed", 5, (6, 6, 6, 4)),
        ("card_morgana_normal", 5, (6, 5, 6, 5)), ("card_morgana_pressed", 5, (6, 6, 6, 4)),
        ("ribbon_gold", 6, (10, 3, 10, 4)),
        ("button_violet_normal", 4, (6, 3, 6, 5)), ("button_violet_pressed", 4, (6, 4, 6, 4)),
    ]
    lines = ['[gd_resource type="Theme" format=3]', "",
             '[ext_resource type="FontFile" path="res://assets/fonts/Cubic_11.ttf" id="1_font"]']
    for i, (name, _, _) in enumerate(tex):
        png = "ribbon" if name == "ribbon_big" else name
        lines.append('[ext_resource type="Texture2D" path="res://assets/ui/%s.png" id="%d_%s"]' % (png, i + 2, name))
    for i, (name, m, (cl, ct, cr, cb)) in enumerate(tex):
        lines += ["", '[sub_resource type="StyleBoxTexture" id="Style_%s"]' % name,
                  'content_margin_left = %.1f' % cl, 'content_margin_top = %.1f' % ct,
                  'content_margin_right = %.1f' % cr, 'content_margin_bottom = %.1f' % cb,
                  'texture = ExtResource("%d_%s")' % (i + 2, name)]
        if name in ("ribbon", "ribbon_big", "ribbon_gold"):
            lines += ["texture_margin_left = 8.0", "texture_margin_top = 4.0",
                      "texture_margin_right = 8.0", "texture_margin_bottom = 5.0"]
        else:
            lines += ["texture_margin_left = %.1f" % m, "texture_margin_top = %.1f" % m,
                      "texture_margin_right = %.1f" % m, "texture_margin_bottom = %.1f" % m]
    lines += ["", '[sub_resource type="StyleBoxEmpty" id="Style_empty"]']
    lines += ["", '[sub_resource type="StyleBoxFlat" id="Style_scroll"]', "bg_color = %s" % _col("plum", 0.6),
              "content_margin_left = 2.0", "content_margin_right = 2.0", "anti_aliasing = false"]
    lines += ["", '[sub_resource type="StyleBoxFlat" id="Style_grabber"]', "bg_color = %s" % _col("gold"),
              "content_margin_left = 2.0", "content_margin_right = 2.0", "anti_aliasing = false"]
    ink = _col("ink")
    r = ["", "[resource]",
         'default_font = ExtResource("1_font")',
         "default_font_size = 12",
         # Buttons (gold): touch only, so hover looks the same as normal
         "Button/colors/font_color = %s" % ink,
         "Button/colors/font_hover_color = %s" % ink,
         "Button/colors/font_pressed_color = %s" % ink,
         "Button/colors/font_hover_pressed_color = %s" % ink,
         "Button/colors/font_focus_color = %s" % ink,
         "Button/colors/font_disabled_color = %s" % _col("stone_d"),
         "Button/constants/h_separation = 3",
         'Button/styles/normal = SubResource("Style_button_normal")',
         'Button/styles/hover = SubResource("Style_button_normal")',
         'Button/styles/pressed = SubResource("Style_button_pressed")',
         'Button/styles/hover_pressed = SubResource("Style_button_pressed")',
         'Button/styles/disabled = SubResource("Style_button_disabled")',
         'Button/styles/focus = SubResource("Style_empty")',
         # Blue secondary buttons
         'ButtonAlt/base_type = &"Button"',
         "ButtonAlt/colors/font_color = %s" % _col("white"),
         "ButtonAlt/colors/font_hover_color = %s" % _col("white"),
         "ButtonAlt/colors/font_pressed_color = %s" % _col("white"),
         "ButtonAlt/colors/font_hover_pressed_color = %s" % _col("white"),
         "ButtonAlt/colors/font_focus_color = %s" % _col("white"),
         "ButtonAlt/colors/font_shadow_color = %s" % _col("water_d"),
         "ButtonAlt/constants/shadow_offset_x = 1",
         "ButtonAlt/constants/shadow_offset_y = 1",
         'ButtonAlt/styles/normal = SubResource("Style_button_alt_normal")',
         'ButtonAlt/styles/hover = SubResource("Style_button_alt_normal")',
         'ButtonAlt/styles/pressed = SubResource("Style_button_alt_pressed")',
         'ButtonAlt/styles/hover_pressed = SubResource("Style_button_alt_pressed")',
         # Trick cards
         'CardButton/base_type = &"Button"',
         'CardButton/styles/normal = SubResource("Style_card_normal")',
         'CardButton/styles/hover = SubResource("Style_card_normal")',
         'CardButton/styles/pressed = SubResource("Style_card_pressed")',
         'CardButton/styles/hover_pressed = SubResource("Style_card_pressed")',
         'CardButton/styles/disabled = SubResource("Style_card_normal")',
         # v2.4: 「進化!」 card and the two choice-event cards (Merlin blue, Morgana purple)
         'CardEvolve/base_type = &"Button"',
         'CardEvolve/styles/normal = SubResource("Style_card_evolve_normal")',
         'CardEvolve/styles/hover = SubResource("Style_card_evolve_normal")',
         'CardEvolve/styles/pressed = SubResource("Style_card_evolve_pressed")',
         'CardEvolve/styles/hover_pressed = SubResource("Style_card_evolve_pressed")',
         'CardEvolve/styles/disabled = SubResource("Style_card_evolve_normal")',
         'CardMerlin/base_type = &"Button"',
         'CardMerlin/styles/normal = SubResource("Style_card_merlin_normal")',
         'CardMerlin/styles/hover = SubResource("Style_card_merlin_normal")',
         'CardMerlin/styles/pressed = SubResource("Style_card_merlin_pressed")',
         'CardMerlin/styles/hover_pressed = SubResource("Style_card_merlin_pressed")',
         'CardMerlin/styles/disabled = SubResource("Style_card_merlin_normal")',
         'CardMorgana/base_type = &"Button"',
         'CardMorgana/styles/normal = SubResource("Style_card_morgana_normal")',
         'CardMorgana/styles/hover = SubResource("Style_card_morgana_normal")',
         'CardMorgana/styles/pressed = SubResource("Style_card_morgana_pressed")',
         'CardMorgana/styles/hover_pressed = SubResource("Style_card_morgana_pressed")',
         'CardMorgana/styles/disabled = SubResource("Style_card_morgana_normal")',
         # v2.4: violet button (「無盡試煉」)
         'ButtonViolet/base_type = &"Button"',
         "ButtonViolet/colors/font_color = %s" % _col("white"),
         "ButtonViolet/colors/font_hover_color = %s" % _col("white"),
         "ButtonViolet/colors/font_pressed_color = %s" % _col("white"),
         "ButtonViolet/colors/font_hover_pressed_color = %s" % _col("white"),
         "ButtonViolet/colors/font_focus_color = %s" % _col("white"),
         "ButtonViolet/colors/font_shadow_color = %s" % ink,
         "ButtonViolet/constants/shadow_offset_x = 1",
         "ButtonViolet/constants/shadow_offset_y = 1",
         'ButtonViolet/styles/normal = SubResource("Style_button_violet_normal")',
         'ButtonViolet/styles/hover = SubResource("Style_button_violet_normal")',
         'ButtonViolet/styles/pressed = SubResource("Style_button_violet_pressed")',
         'ButtonViolet/styles/hover_pressed = SubResource("Style_button_violet_pressed")',
         # Labels: dark text on parchment by default
         "Label/colors/font_color = %s" % ink,
         "Label/constants/line_spacing = 1",
         # Light text with a pixel shadow, for text over the game or dark panels
         'LabelLight/base_type = &"Label"',
         "LabelLight/colors/font_color = %s" % _col("white"),
         "LabelLight/colors/font_shadow_color = %s" % ink,
         "LabelLight/constants/shadow_offset_x = 1",
         "LabelLight/constants/shadow_offset_y = 1",
         # Big title text: twice the font's native size, still pixel exact
         'LabelTitle/base_type = &"Label"',
         "LabelTitle/colors/font_color = %s" % _col("yellow"),
         "LabelTitle/colors/font_shadow_color = %s" % ink,
         "LabelTitle/colors/font_outline_color = %s" % ink,
         "LabelTitle/constants/outline_size = 4",
         "LabelTitle/constants/shadow_offset_x = 0",
         "LabelTitle/constants/shadow_offset_y = 2",
         "LabelTitle/font_sizes/font_size = 24",
         # Pop-up numbers and words over the game ("等級 3!"): yellow with a thick outline
         'LabelPop/base_type = &"Label"',
         "LabelPop/colors/font_color = %s" % _col("yellow"),
         "LabelPop/colors/font_outline_color = %s" % ink,
         "LabelPop/constants/outline_size = 4",
         # Big white title text with outline (celebration, cut-in)
         'LabelBig/base_type = &"Label"',
         "LabelBig/colors/font_color = %s" % _col("white"),
         "LabelBig/colors/font_outline_color = %s" % ink,
         "LabelBig/colors/font_shadow_color = %s" % ink,
         "LabelBig/constants/outline_size = 4",
         "LabelBig/constants/shadow_offset_x = 0",
         "LabelBig/constants/shadow_offset_y = 2",
         "LabelBig/font_sizes/font_size = 24",
         # Brown secondary text on parchment
         'LabelSoft/base_type = &"Label"',
         "LabelSoft/colors/font_color = %s" % _col("brown"),
         # Panels
         'PanelContainer/styles/panel = SubResource("Style_panel")',
         'Panel/styles/panel = SubResource("Style_panel")',
         'PanelDark/base_type = &"PanelContainer"',
         'PanelDark/styles/panel = SubResource("Style_panel_dark")',
         'Ribbon/base_type = &"PanelContainer"',
         'Ribbon/styles/panel = SubResource("Style_ribbon")',
         'RibbonBig/base_type = &"PanelContainer"',
         'RibbonBig/styles/panel = SubResource("Style_ribbon_big")',
         'RibbonGold/base_type = &"PanelContainer"',
         'RibbonGold/styles/panel = SubResource("Style_ribbon_gold")',
         # Thin pixel scroll bar
         "VScrollBar/styles/scroll = SubResource(\"Style_scroll\")",
         "VScrollBar/styles/grabber = SubResource(\"Style_grabber\")",
         "VScrollBar/styles/grabber_highlight = SubResource(\"Style_grabber\")",
         "VScrollBar/styles/grabber_pressed = SubResource(\"Style_grabber\")",
         'ScrollContainer/styles/panel = SubResource("Style_empty")',
         ""]
    return "\n".join(lines + r)


def write_theme() -> None:
    from pixel import write_text
    write_text(res_path("res://ui/theme/main_theme.tres"), theme_tres())
