"""Chapter 1 tiles (16x16) and the three arena backgrounds (C6).

Backgrounds are composed from the tile set plus a few larger props and baked into
one PNG each, shown by a Sprite2D in assets/backgrounds/<name>.tscn.

Image layout (same for every background): 304x512 px, placed at world (-62, -88),
so it covers world (-62,-88)-(242,424): wider than the contract minimum
(-10,-60)-(190,380). The tile grid lines up with Layout.ARENA_RECT (2,72,176,224):
the arena is tile columns 4..14 and rows 10..23 of the image.
"""

from __future__ import annotations

import random

from palette import rgba
from pixel import Canvas, res_path

T = 16
IMG_W, IMG_H = 304, 512
ORIGIN = (-62, -88)               # world position of the image's top-left pixel
ARENA_COLS = range(4, 15)          # 11 columns
ARENA_ROWS = range(10, 24)         # 14 rows

L = {
    "o": "ink", "w": "white", "c": "cream", "g": "gold_l", "G": "gold", "b": "gold_d", "B": "brown",
    "n": "brown_d", "R": "red", "r": "red_d", "p": "pink", "Y": "yellow", "l": "leaf_l", "e": "leaf",
    "d": "leaf_d", "f": "forest", "F": "forest_d", "k": "stone_l", "t": "stone", "T": "stone_d",
    "S": "steel_l", "s": "steel", "z": "steel_d", "v": "violet", "V": "lilac", "P": "plum",
    "q": "sky_l", "Q": "sky", "u": "water", "U": "water_d", "i": "iron",
}


# --------------------------------------------------------------------------
# 16x16 tiles
# --------------------------------------------------------------------------

def _tuft(c: Canvas, x: int, y: int, col: str) -> None:
    c.set(x, y, col)
    c.set(x - 1, y - 1, col)
    c.set(x + 1, y - 1, col)


def grass_tile(seed: int, base: str = "leaf", tuft: str = "leaf_d", speck: str = "leaf_l",
               tufts: int = 2, specks: int = 2, flowers: int = 0) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(T, T, rgba(base))
    for _ in range(tufts):
        _tuft(c, rng.randrange(2, 14), rng.randrange(3, 15), tuft)
    for _ in range(specks):
        c.set(rng.randrange(0, 16), rng.randrange(0, 16), speck)
    petals = ["white", "yellow", "pink"]
    for i in range(flowers):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        col = petals[(seed + i) % len(petals)]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.set(x + dx, y + dy, col)
        c.set(x, y, "orange" if col != "yellow" else "white")
    return c


def stone_floor_tile(seed: int) -> Canvas:
    """Bridge deck: large light paving stones (16x8, offset rows) with soft joints."""
    rng = random.Random(seed)
    c = Canvas(T, T, rgba("stone_l"))
    c.hline(0, 15, 7, "stone")
    c.hline(0, 15, 15, "stone")
    off = 4 if seed % 2 else 12
    c.vline(off, 0, 6, "stone")
    c.vline((off + 8) % 16, 8, 14, "stone")
    c.set(rng.randrange(1, 15), rng.randrange(1, 6), "white")
    return c


def parapet_tile() -> Canvas:
    c = Canvas(T, T, rgba("stone"))
    c.rect(0, 0, 16, 3, "stone_l")
    c.hline(0, 15, 12, "stone_d")
    c.rect(0, 13, 16, 3, "stone_d")
    c.vline(7, 3, 11, "stone_d")
    c.vline(15, 3, 11, "stone_d")
    c.hline(0, 15, 15, "ink")
    return c


def water_tile(seed: int) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(T, T, rgba("water"))
    for _ in range(2):
        x, y = rng.randrange(1, 12), rng.randrange(2, 15)
        c.hline(x, x + 3, y, "water_d")
    x, y = rng.randrange(1, 13), rng.randrange(1, 15)
    c.hline(x, x + 2, y, "sky")
    if seed % 3 == 0:
        c.set(rng.randrange(0, 16), rng.randrange(0, 16), "sky_l")
    return c


def castle_wall_tile(seed: int) -> Canvas:
    c = Canvas(T, T, rgba("stone"))
    for y in (0, 5, 10, 15):
        c.hline(0, 15, y, "stone_d")
    for i, y0 in enumerate((1, 6, 11)):
        off = 4 if (i + seed) % 2 else 0
        for x in (off, off + 8):
            c.vline(x % 16, y0, y0 + 3, "stone_d")
        c.hline((off + 1) % 16, (off + 3) % 16, y0, "stone_l")
    return c


def crenel_tile() -> Canvas:
    c = Canvas(T, T)
    c.rect(0, 6, 16, 10, "stone")
    c.rect(0, 0, 6, 6, "stone")
    c.rect(10, 0, 6, 6, "stone")
    c.hline(0, 5, 0, "stone_l")
    c.hline(10, 15, 0, "stone_l")
    c.hline(0, 15, 11, "stone_d")
    c.vline(8, 7, 10, "stone_d")
    c.outline_all()
    return c


def hedge_tile(seed: int) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(T, T, rgba("leaf_d"))
    for x in range(0, 16, 4):
        c.ellipse(x + 2, 6, 3, 3, "leaf")
    for _ in range(4):
        c.set(rng.randrange(0, 16), rng.randrange(2, 10), "leaf_l")
    c.rect(0, 12, 16, 4, "forest")
    c.hline(0, 15, 11, "forest")
    return c


def fence_tile() -> Canvas:
    c = Canvas(T, T)
    c.rect(0, 5, 16, 2, "brown")
    c.rect(0, 10, 16, 2, "brown")
    c.hline(0, 15, 5, "gold_d")
    c.hline(0, 15, 10, "gold_d")
    c.rect(2, 2, 3, 12, "gold_d")
    c.vline(2, 2, 13, "gold_l")
    c.rect(11, 2, 3, 12, "gold_d")
    c.vline(11, 2, 13, "gold_l")
    c.outline_all()
    return c


def tile_set() -> dict[str, Canvas]:
    tiles: dict[str, Canvas] = {}
    for i in range(4):
        tiles["grass_%d" % i] = grass_tile(10 + i, tufts=1 + i % 2, specks=1 + (i * 3) % 3)
    for i in range(2):
        tiles["grass_flower_%d" % i] = grass_tile(20 + i, tufts=1, specks=1, flowers=1 + i)
    for i in range(2):
        tiles["grass_dark_%d" % i] = grass_tile(30 + i, base="leaf_d", tuft="forest", speck="leaf", tufts=2, specks=2)
    tiles["hedge_0"] = hedge_tile(40)
    tiles["hedge_1"] = hedge_tile(41)
    tiles["fence"] = fence_tile()
    tiles["stone_0"] = stone_floor_tile(50)
    tiles["stone_1"] = stone_floor_tile(51)
    tiles["parapet"] = parapet_tile()
    for i in range(3):
        tiles["water_%d" % i] = water_tile(60 + i)
    tiles["wall_0"] = castle_wall_tile(70)
    tiles["wall_1"] = castle_wall_tile(71)
    tiles["crenel"] = crenel_tile()
    return tiles


# --------------------------------------------------------------------------
# Props (drawn on top of tiles; each with its own outline)
# --------------------------------------------------------------------------

TREE = [
    "..........ffff..........",
    "......ffffeeeeffff......",
    "....ffeeeeeeeelleeff....",
    "...feeeeeeeeeeellleef...",
    "..feeeeeeeeeeeeelleeef..",
    ".feeeeeeeeeeeeeeeeeeeef.",
    ".feeeeeeeeeeeeeeeeeeeef.",
    "fdeeeeeeeeeeeeeeeeeeeeef",
    "fdeeeeeeeeeeeeeeeeeeeeef",
    "fddeeeeeeeeeeeeeeeeeeedf",
    "fdddeeeeeeeeeeeeeeeeeddf",
    ".fdddeeeeeeeeeeeeeeeddf.",
    ".ffdddddeeeeeeeeeddddff.",
    "..ffdddddddddddddddddf..",
    "...fffddddddddddddfff...",
    ".....fffffBBnffffff.....",
    "..........BBn...........",
    "..........BBn...........",
    ".........BBBnn..........",
    "........fFFFFFF.........",
]

BUSH = [
    "...eeee...",
    ".eeelleee.",
    "eeeeleeeee",
    "deeeeeeeed",
    "ddeeeeeedd",
    ".dddddddd.",
]

ROCK = [
    "..kkkk..",
    ".kkkttt.",
    "kkttttTT",
    "tttttTTT",
    ".TTTTTT.",
]

SWORD_STONE = [
    ".........Y........",
    "........YwY.......",
    ".........S........",
    ".........Sz.......",
    ".........Sz.......",
    "......YYbYbYY.....",
    "........nn........",
    "........Sz........",
    "........Sz........",
    "....kkkkSzkkkk....",
    "..kkkkkkSzkkkttt..",
    ".kkkkkkkkkkktttTt.",
    "kkkkkkkktttttTTTTt",
    "kkktttttttttTTTTTT",
    "ktttttttttTTTTTTTT",
    ".TTTTTTTTTTTTTTTT.",
    "..dddddddddddddd..",
]

REEDS = [
    ".l..l.",
    ".e.le.",
    "le.ee.",
    "ee.edl",
    "ed.dde",
    "dd.ddd",
]

LILY = [
    ".eee.",
    "eelle",
    "eeep.",
    ".ee..",
]

BANNER = [
    "nnnnnn",
    "PvvvvP",
    "PvVVvP",
    "PvYYvP",
    "PvVVvP",
    "PvvvvP",
    "Pv..vP",
    "P....P",
]

def big_sword_stone() -> Canvas:
    """The sword in the stone for level 1-1 (34x34), a mossy boulder with a shining sword."""
    c = Canvas(34, 34)
    c.ellipse(17, 25, 15.5, 8, "stone")
    c.ellipse(14, 23, 11, 5.5, "stone_l")
    c.ellipse(20, 28, 12, 4, "stone")
    for x in range(3, 31):
        for y in range(27, 34):
            if c.opaque(x, y) and y >= 31 - abs(x - 17) // 6:
                c.set(x, y, "stone_d")
    for (x, y) in [(8, 21), (9, 20), (10, 20), (24, 21), (25, 22), (6, 24), (27, 25), (11, 19)]:
        c.set(x, y, "leaf")
    for (x, y) in [(9, 21), (25, 21), (7, 24), (26, 25)]:
        c.set(x, y, "leaf_d")
    c.line(22, 25, 24, 28, "stone_d")
    c.line(10, 27, 12, 29, "stone_d")
    sword = Canvas(34, 34)
    for y in range(6, 23):
        sword.set(16, y, "white" if y < 12 else "steel_l")
        sword.set(17, y, "steel")
    sword.hline(12, 21, 5, "yellow")
    sword.set(16, 5, "gold_d")
    sword.set(17, 5, "gold_d")
    for y in range(2, 5):
        sword.set(16, y, "brown")
        sword.set(17, y, "brown_d")
    sword.set(16, 1, "yellow")
    sword.set(17, 1, "yellow")
    sword.set(16, 0, "white")
    sword.outline_all()
    c.outline_all()
    c.blit(sword, 0, 0)
    for y in range(20, 23):
        c.set(15, y, "stone_d")
        c.set(18, y, "stone_d")
    return c


def prop(grid: list[str], outline: bool = True) -> Canvas:
    w = max(len(r) for r in grid) + 2
    h = len(grid) + 2
    c = Canvas(w, h)
    c.stamp(grid, 1, 1, L, outline="ink" if outline else None)
    return c


# --------------------------------------------------------------------------
# Background composition
# --------------------------------------------------------------------------

class Board:
    def __init__(self, tiles: dict[str, Canvas]) -> None:
        self.tiles = tiles
        self.img = Canvas(IMG_W, IMG_H, rgba("leaf_d"))

    def tile(self, col: int, row: int, name: str) -> None:
        self.img.blit(self.tiles[name], col * T, row * T)

    def put(self, grid_or_canvas, x: int, y: int) -> None:
        """Place a prop (grid or canvas) with its top-left corner at image pixel (x, y)."""
        c = grid_or_canvas if isinstance(grid_or_canvas, Canvas) else prop(grid_or_canvas)
        self.img.blit(c, x, y)

    def world_to_img(self, wx: int, wy: int) -> tuple[int, int]:
        return wx - ORIGIN[0], wy - ORIGIN[1]


def _in_arena(col: int, row: int) -> bool:
    return col in ARENA_COLS and row in ARENA_ROWS


def _hash(col: int, row: int, salt: int) -> int:
    return (col * 73856093 ^ row * 19349663 ^ salt * 83492791) & 0x7FFFFFFF


def grass_field(b: Board, salt: int, flower_rate: int = 9) -> None:
    for row in range(IMG_H // T):
        for col in range(IMG_W // T):
            h = _hash(col, row, salt)
            if _in_arena(col, row):
                name = "grass_flower_%d" % (h % 2) if h % flower_rate == 0 else "grass_%d" % (h % 4)
            else:
                name = "grass_dark_%d" % (h % 2)
            b.tile(col, row, name)


def arena_frame(b: Board) -> None:
    """Hedges just outside the arena's top and bottom edges, darker strips at the sides."""
    for col in range(IMG_W // T):
        if col in ARENA_COLS or col in (3, 15):
            b.tile(col, ARENA_ROWS.start - 1, "hedge_%d" % (col % 2))
            b.tile(col, ARENA_ROWS.stop, "fence")
    for row in ARENA_ROWS:
        for col in (3, 15):
            b.tile(col, row, "hedge_%d" % (row % 2))
    # 2 px soft edge inside the arena so the side borders read on a 180-wide screen
    x0, x1 = ARENA_COLS.start * T, ARENA_COLS.stop * T
    for y in range(ARENA_ROWS.start * T, ARENA_ROWS.stop * T):
        b.img.set(x0, y, "leaf_d")
        b.img.set(x1 - 1, y, "leaf_d")


def scatter(b: Board, items: list[tuple[list[str], int, int]]) -> None:
    for grid, x, y in items:
        b.put(grid, x, y)


def meadow(tiles: dict[str, Canvas]) -> Canvas:
    b = Board(tiles)
    grass_field(b, 1)
    arena_frame(b)
    # trees above the arena (behind the HUD) and along the bottom
    for x in (-6, 26, 60, 98, 134, 170, 204, 240, 276):
        b.put(TREE, x, 60 + (x * 7) % 23)
    for x in (10, 52, 96, 140, 186, 228, 270):
        b.put(TREE, x, 110 + (x * 5) % 17)
    for x in (-4, 40, 196, 244, 284):
        b.put(TREE, x, 420 + (x * 3) % 20)
    scatter(b, [(BUSH, 8, 200), (BUSH, 262, 240), (BUSH, 20, 330), (BUSH, 270, 352),
                (ROCK, 30, 270), (ROCK, 264, 300), (BUSH, 120, 404), (ROCK, 180, 410),
                (BUSH, 70, 470), (BUSH, 222, 476)])
    return b.img


def sword_stone(tiles: dict[str, Canvas]) -> Canvas:
    b = Board(tiles)
    grass_field(b, 2, flower_rate=6)
    arena_frame(b)
    for x in (-6, 30, 228, 266):
        b.put(TREE, x, 70 + (x * 7) % 19)
    for x in (4, 250):
        b.put(TREE, x, 120)
    for x, y in ((84, 128), (196, 126)):
        b.put(BUSH, x, y)
    # the sword in the stone: centred above the arena, just under where the HUD ends
    sx, sy = b.world_to_img(90, 56)
    b.put(big_sword_stone(), sx - 17, sy - 18)
    for (x, y) in ((sx - 16, sy - 14), (sx + 14, sy - 10), (sx - 12, sy + 4), (sx + 18, sy + 2)):
        b.img.set(x, y, "white")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            b.img.set(x + dx, y + dy, "yellow")
    scatter(b, [(BUSH, 10, 210), (BUSH, 266, 250), (ROCK, 24, 320), (ROCK, 268, 340),
                (BUSH, 100, 404), (ROCK, 196, 412), (BUSH, 40, 450), (BUSH, 240, 460)])
    for x in (-8, 60, 150, 216, 270):
        b.put(TREE, x, 432 + (x * 3) % 16)
    return b.img


def bridge(tiles: dict[str, Canvas]) -> Canvas:
    b = Board(tiles)
    cols = IMG_W // T
    rows = IMG_H // T
    bridge_cols = range(7, 12)            # the narrow bridge leading to the gate and the bank
    for row in range(rows):
        for col in range(cols):
            h = _hash(col, row, 3)
            if _in_arena(col, row) or (col in bridge_cols and 2 <= row < 30):
                b.tile(col, row, "stone_%d" % (h % 2))
            else:
                b.tile(col, row, "water_%d" % (h % 3))
    # parapets: around the wide platform (the arena) and along the narrow bridge
    for col in list(range(3, 16)):
        for row in (ARENA_ROWS.start - 1, ARENA_ROWS.stop):
            if col not in bridge_cols:
                b.tile(col, row, "parapet")
    for row in range(ARENA_ROWS.start - 1, ARENA_ROWS.stop + 1):
        b.tile(3, row, "parapet")
        b.tile(15, row, "parapet")
    for row in list(range(2, ARENA_ROWS.start - 1)) + list(range(ARENA_ROWS.stop + 1, 30)):
        b.tile(bridge_cols.start - 1, row, "parapet")
        b.tile(bridge_cols.stop, row, "parapet")
    # castle wall with the black knight's gate at the top
    for col in range(cols):
        b.tile(col, 0, "wall_%d" % (col % 2))
        b.tile(col, 1, "wall_%d" % ((col + 1) % 2))
    for col in range(cols):
        b.img.blit(tiles["crenel"], col * T, -6)
    gate = Canvas(5 * T, 2 * T)
    gate.ellipse(40, 32, 30, 30, "ink")
    gate.rect(10, 20, 60, 12, "ink")
    b.img.blit(gate, 7 * T, 0)
    for col in (4, 14):
        b.put(BANNER, col * T + 3, 2)
    # near bank at the bottom
    for row in range(30, rows):
        for col in range(cols):
            b.tile(col, row, "grass_%d" % (_hash(col, row, 4) % 4))
    for col in range(cols):
        b.img.hline(col * T, col * T + 15, 30 * T, "leaf_d")
    scatter(b, [(REEDS, 20, 452), (REEDS, 260, 456), (LILY, 30, 140), (LILY, 262, 330),
                (LILY, 16, 400), (REEDS, 274, 120), (LILY, 274, 230), (REEDS, 6, 260)])
    for x in (-6, 36, 230, 270):
        b.put(TREE, x, 470)
    return b.img


BACKGROUNDS = {"meadow": meadow, "sword_stone": sword_stone, "bridge": bridge}


def background_tscn(name: str) -> str:
    return "\n".join([
        '[gd_scene load_steps=2 format=3]',
        '',
        '[ext_resource type="Texture2D" path="res://assets/backgrounds/%s.png" id="1_bg"]' % name,
        '',
        '[node name="Background" type="Node2D"]',
        '',
        '[node name="Image" type="Sprite2D" parent="."]',
        'texture = ExtResource("1_bg")',
        'centered = false',
        'position = Vector2(%d, %d)' % ORIGIN,
        '',
    ])


def write_all() -> None:
    from pixel import write_text
    tiles = tile_set()
    atlas = Canvas(8 * T, ((len(tiles) + 7) // 8) * T)
    for i, img in enumerate(tiles.values()):
        atlas.blit(img, (i % 8) * T, (i // 8) * T)
    atlas.save(res_path("res://assets/tiles/chapter1_tiles.png"))
    for name, fn in BACKGROUNDS.items():
        fn(tiles).save(res_path("res://assets/backgrounds/%s.png" % name))
        write_text(res_path("res://assets/backgrounds/%s.tscn" % name), background_tscn(name))
