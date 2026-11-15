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

def framed(w: int, h: int, outline: str, border: str | None, fill: str, top: str | None = None,
           bottom: str | None = None, corner: int = 2, inner_glint: str | None = None) -> Canvas:
    """Rounded pixel box: outline, optional 1 px inner border, fill, top highlight and bottom shadow."""
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
                c.set(x, y, border)
            else:
                c.set(x, y, fill)
    inset = 2 if border else 1
    if top:
        for x in range(inset + 1, w - inset - 1):
            c.set(x, inset, top)
    if bottom:
        for x in range(inset, w - inset):
            c.set(x, h - inset - 1, bottom)
            if h > 12:
                c.set(x, h - inset - 2, bottom)
    if inner_glint:
        c.set(inset + 1, inset + 1, inner_glint)
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


def write_all() -> list[str]:
    out = []
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
