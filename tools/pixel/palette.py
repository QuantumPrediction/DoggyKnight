"""The single 55-colour palette of 金毛騎士 (DEV_PLAN 第 10 節「美術方向」).

v1 had 32 colours; v2.2 (M3 polish) added 8 mood colours (peach, rose, dusk, night,
night_d, moss, moss_d, dirt) for the late-afternoon farm, the dusk forest and the
stormy night bridge. v2.5 (full art redraw) added 15 colours: darker/lighter ends for the hue-shifted ramps (wine, coral,
fog, ash, umber, navy), coloured outline darks, calmer arena greens (spring, grass, teal, deep), sky haze
(azure, haze), warm light (amber), stone (slate) and path sand. Every sprite, tile, icon and UI texture uses only these colours (FX may use them
with transparency). tests/line_c/test_line_c_art.gd checks this.
Order matters: it is the order of the swatches in assets/palette.png and of the
constants in ui/theme/palette_colors.gd.
"""

from __future__ import annotations

PALETTE: list[tuple[str, str]] = [
    # outline and purples (enemies, magic)
    ("ink", "2a1b2d"),
    ("plum", "4b2f57"),
    ("violet", "7a5a99"),
    ("lilac", "b7a1d9"),
    # whites and steel
    ("white", "fffaf0"),
    ("steel_l", "d5dbe8"),
    ("steel", "95a1bd"),
    ("steel_d", "5d6888"),
    ("iron", "3b3f5c"),
    # fur, straw and wood
    ("cream", "fff1c9"),
    ("gold_l", "f7d488"),
    ("gold", "e6ae5c"),
    ("gold_d", "c07f3e"),
    ("brown", "8a5232"),
    ("brown_d", "5a3426"),
    # warm accents
    ("red", "e8434f"),
    ("red_d", "a8304a"),
    ("pink", "ff99aa"),
    ("orange", "ff8a3d"),
    ("yellow", "ffe066"),
    # greens
    ("leaf_l", "bfe36d"),
    ("leaf", "7ec850"),
    ("leaf_d", "4f9a48"),
    ("forest", "2f6b45"),
    ("forest_d", "1f4a3c"),
    # sky and water
    ("sky_l", "c4f1ff"),
    ("sky", "6fc8f0"),
    ("water", "3d8ad1"),
    ("water_d", "2c5aa0"),
    # stone
    ("stone_l", "dcd3c6"),
    ("stone", "aaa09a"),
    ("stone_d", "7a6f72"),
    # v2.2 (M3) mood colours: late afternoon, dusk and stormy night scenes
    ("peach", "ffc79a"),
    ("rose", "d9748e"),
    ("dusk", "7d4a78"),
    ("night", "3b4a80"),
    ("night_d", "232a50"),
    ("moss", "a8b850"),
    ("moss_d", "6d8a3c"),
    ("dirt", "c9a06e"),
    # v2.5 (CR1-CR3) full redraw: hue-shifted ramp extensions, coloured outlines, calmer grass, haze
    ("wine", "6e2248"),
    ("coral", "ff7b6b"),
    ("fog", "cdc6d9"),
    ("ash", "958ca8"),
    ("spring", "a6d85c"),
    ("grass", "62ad4e"),
    ("teal", "2f7a68"),
    ("deep", "173a3a"),
    ("azure", "a2e0f5"),
    ("haze", "e6f4e4"),
    ("amber", "ffb347"),
    ("slate", "524a5e"),
    ("umber", "3e2421"),
    ("navy", "1c1d3a"),
    ("sand", "e8d3a2"),
]

COLORS: dict[str, str] = dict(PALETTE)

# Preview-only colours (never written into game assets).
PREVIEW = {"sheet_bg": "7d9a6a"}


def rgba(name: str) -> tuple[int, int, int, int]:
    """'gold' -> (r, g, b, 255); 'white@128' -> alpha 128; '#rrggbb' also accepted."""
    alpha = 255
    if "@" in name:
        name, a = name.split("@")
        alpha = int(a)
    hexv = COLORS.get(name) or PREVIEW.get(name)
    if hexv is None:
        assert name.startswith("#"), "unknown colour %r" % name
        hexv = name[1:]
    return (int(hexv[0:2], 16), int(hexv[2:4], 16), int(hexv[4:6], 16), alpha)


def rgb_set() -> set[tuple[int, int, int]]:
    return {rgba(n)[:3] for n, _ in PALETTE}
