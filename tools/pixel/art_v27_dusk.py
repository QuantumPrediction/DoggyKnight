"""v2.7 (CW7) chapter 6「卡姆蘭之戰」: autumn and dusk, the last battles, then Avalon.

    camlann_field  6-1  the autumn plain at dusk: golden grass, red trees, the shadow army on the ridge
    shadow_camp    6-2  the enemy camp at night: tents, black wolf banners, campfires, a palisade
    occupied_town  6-3  Camelot's town at sunset under black flags: shuttered stalls, falling leaves
    throne_hall    6-4  the throne room by candlelight: stained glass, pillars, wolf banners, the dais
    avalon_gate    6-5  the apple orchard at twilight: a rune-lit stone gate, mist, blossom
    avalon_hill    6-6  the final hill: a sunset over Avalon's lake, apple blossom, a stone jetty
"""

from __future__ import annotations

import math
import random

import art_light as AL
import art_world as AW
import art_v26_kit as K
import art_v26_title as T
import art_v26_world as W
import art_v27_kit as K7
import paint as P
from art_world import AX0, AX1, AY0, AY1, IMG_H, IMG_W, fbm, in_arena, name_at
from art_v26_kit import Scene26, dk, lt
from art_v27_kit import MIDX, MIDY
from pixel import Canvas


def sun_disc(img: Canvas, cx: float, cy: float, r: float, rings=((1.0, "cream"), (1.6, "gold_l"), (2.4, "peach")),
             horizon: int | None = None, only=None) -> None:
    """A low sun: a pale disc with flat glow rings (no dither); clipped at the horizon."""
    for k in range(len(rings) - 1, -1, -1):
        rr = r * rings[k][0]
        col = rings[k][1]
        for y in range(int(cy - rr) - 1, int(cy + rr) + 2):
            if horizon is not None and y >= horizon:
                continue
            for x in range(int(cx - rr * 1.3) - 1, int(cx + rr * 1.3) + 2):
                d = math.hypot((x + 0.5 - cx) / 1.3 if k else (x + 0.5 - cx), y + 0.5 - cy)
                if d < rr and (k == 0 or only is None or name_at(img, x, y) in only):
                    img.set(x, y, "white" if k == 0 and d < rr * 0.55 else col)


def army_ridge(img: Canvas, base: int, x0: int, x1: int, seed: int, cols=("plum", "wine", "dusk")) -> list[int]:
    """The shadow army on a far ridge: rows of round helmets with spears (taller towards the viewer), here
    and there a banner pole. Returns the x of each banner pole."""
    rng = random.Random(seed)
    poles = []
    for row in range(3):
        y = base - 4 + row * 4
        x = x0 + row * 3
        size = 1 + row
        while x < x1:
            col = cols[row % len(cols)]
            for (dx, dy) in P.ellipse(x + size / 2, y, size * 0.8 + 0.5, size * 0.7 + 0.5):
                img.set(dx, dy, col)
            if rng.random() < 0.6:
                img.vline(x + size + 1, y - 5 - row * 3, y + 1, cols[0])
                img.set(x + size + 1, y - 6 - row * 3, "ash" if row else "rose")
            if rng.random() < 0.06 and row == 0:
                poles.append(x)
            x += size * 2 + rng.randrange(2, 4)
    return poles


def dusk_sky(img: Canvas, y1: int, seed: int, bands=None) -> None:
    K.sky_bands(img, 0, y1, bands or [("plum", 0.0), ("dusk", 0.22), ("rose", 0.45), ("coral", 0.65), ("peach", 0.82),
                                      ("gold_l", 0.94)], seed=seed, wave=2.0)


def long_clouds(img: Canvas, rows: list[tuple[int, int, int]], cols: tuple[str, str], seed: int) -> None:
    """Thin, long evening clouds: lit undersides (cols[1]) under a darker body (cols[0])."""
    rng = random.Random(seed)
    for (y, x0, x1) in rows:
        x = x0
        while x < x1:
            ln = rng.randrange(20, 60)
            th = rng.randrange(2, 4)
            for k in range(ln):
                yy = y + int(1.2 * math.sin((x + k) / 9.0))
                for t in range(th):
                    if 2 < k < ln - 3 or t == th - 1:
                        img.set(x + k, yy + t, cols[1] if t == th - 1 else cols[0])
            x += ln + rng.randrange(8, 30)


# ==========================================================================
# 6-1 camlann_field
# ==========================================================================

def scene_camlann_field() -> Scene26:
    """6-1 卡姆蘭平原: the autumn plain at dusk. The sun sinks behind the far ridge where the shadow army
    waits under black wolf banners; red and gold trees line the field; leaves blow across golden grass."""
    sc = Scene26("moss", 0.42)
    img = sc.img
    hz = 122
    dusk_sky(img, hz, 6101)
    long_clouds(img, [(30, -10, 140), (50, 150, 320), (76, 20, 200), (98, 180, 300)], ("dusk", "coral"), 6102)
    sun_disc(img, 226, hz - 10, 12, horizon=hz - 2)
    # far: Camelot on the left hills, the army on the right ridge
    K.hills_layer(img, hz, 8, 33.0, "dusk", rim="rose", seed=6103, fill_to=120)
    T.castle(img, 30, hz - 6, 0.8, wall=("dusk", "rose", "peach"), roof=("plum", "dusk", "rose"), flags=False)
    poles = army_ridge(img, hz + 6, 120, IMG_W, 6104)
    K.hills_layer(img, hz + 12, 4, 23.0, "wine", rim="dusk", seed=6105, fill_to=140)
    # mid: the golden field rising to a hedge of autumn trees at the sides
    W.textured_floor(img, (0, 134, IMG_W, IMG_H), ("moss_d", "moss", "gold_l"), 6106, scale=46,
                     mask=lambda x, y: y >= 138 or name_at(img, x, y) in ("wine",))
    W.blades(img, (0, 140, IMG_W, IMG_H), 6107, 0.05)
    rng = random.Random(6108)
    for i, x in enumerate(range(-12, IMG_W, 18)):
        if 76 < x < 214:
            continue
        t = K7.autumn_tree(6110 + i, 30 + (i * 7) % 10, rng.choice(("orange", "red", "gold", "rust")))
        AW.place(img, t, x, 160 - t.h + (i * 5) % 8, shadow=(1.0, -2), shadow_dx=-6)
    # an old milestone and a broken cart near the top of the clearing
    stone = K.menhir(20, 6111, ("stone_d", "stone", "stone_l"), "iron", rune=None)
    AW.place(img, stone, MIDX - 8, AY0 - 18, shadow=(1.0, -1), shadow_dx=-5)
    wheel = Canvas(15, 15)
    for (x, y) in P.ellipse(7.5, 7.5, 7, 7):
        d = math.hypot(x + 0.5 - 7.5, y + 0.5 - 7.5)
        if d > 5.2 or abs(x - 7) < 1 or abs(y - 7) < 1:
            wheel.set(x, y, "brown" if x + y < 15 else "brown_d")
    wheel.outline_all("umber")
    AW.place(img, wheel, AX1 - 30, AY0 - 8, shadow=(1.0, -1), shadow_dx=-3)
    # fallen leaves and dry tufts round the clearing, banners stuck in the ground
    K7.leaf_litter(img, (0, AY0 - 10, IMG_W, IMG_H), 420, 6112, calm=0.97)
    K.edge_shadow(img, AY0 - 2, 3, 0, IMG_W)
    for (x, y) in ((AX0 + 4, AY0 + 40), (AX1 - 10, AY0 + 110), (AX0 + 2, AY1 - 30)):
        img.vline(x, y - 22, y, "brown_d")
        img.set(x, y - 23, "steel_l")
    for (x, y) in ((AX0 - 26, AY0 + 30), (AX1 + 4, AY0 + 80), (AX0 - 22, AY1 - 40), (AX1 + 6, AY1 - 20),
                   (12, 400), (270, 410)):
        AW.place(img, AW.bush(x + y, 22, 12, K7.AUTUMN["orange"], "umber"), x, y, shadow=(1.0, -1), shadow_dx=-4)
    for (x, y) in ((AX0 + 10, AY1 - 12), (AX1 - 28, AY0 + 40)):
        AW.place(img, AW.rock(x + y, 12, 7, ("stone_d", "stone", "stone_l", "white"), "iron", "moss_d"), x, y,
                 shadow=(1.0, -1), shadow_dx=-3)
    # sides and bottom: more autumn trees
    for (x, y, kind) in ((-8, 200, "red"), (252, 230, "gold"), (-6, 320, "gold"), (256, 330, "orange")):
        t = K7.autumn_tree(x + y, 34, kind)
        AW.place(img, t, x, y, shadow=(1.0, -2), shadow_dx=-6)
    for i, x in enumerate(range(-14, IMG_W, 22)):
        t = K7.autumn_tree(6120 + i, 30, ("orange", "red", "gold", "rust")[i % 4])
        AW.place(img, t, x, 430 + (i * 7) % 12, shadow=None)
    # foreground: red leaves hanging into the top corners, golden grass at the bottom
    for side in (0, 1):
        br = AL.foliage(52, 36, 6130 + side, K7.AUTUMN["red"], "umber")
        sc.put_fg(br.flipped() if side else br, 36 if side == 0 else IMG_W - 88, 80)
    AL.clumps(sc.fg, 6131, ("brown", "gold_d", "gold", "gold_l"), "brown_d", gap=(16, 30))
    for i, x in enumerate(poles[:5] or [130, 170, 210, 250]):
        sc.anim("flag_wolf", x - 2, hz - 12 + (i % 2) * 2, i % 4, 0.9 + (i % 3) * 0.1)
    for i, (x, y) in enumerate(((AX0 - 4, AY0 + 30), (AX1 - 2, AY0 + 70), (AX0 + 2, AY1 - 50), (AX1 - 6, AY1 - 10),
                                (MIDX - 40, AY0 - 6), (MIDX + 36, AY0 - 4))):
        sc.anim("tuft_gold", x, y, i % 4, 0.8 + (i % 3) * 0.1)
    for i, (x, y) in enumerate(((AX0 + 4, AY0 + 18), (AX1 - 10, AY0 + 88))):
        sc.anim("pennant_red", x, y, i, 1.1)
    sc.light("sun", 226, hz - 10, 1.4, tint=(1.0, 0.6, 0.35))
    sc.particle(kind="leaf", amount=10, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.4), spread=20,
                speed=(12, 18), gravity=(0, 3), colour_fade=True, spin=True)
    sc.particle(kind="leaf_red", amount=8, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.5), spread=20,
                speed=(10, 16), gravity=(0, 3), colour_fade=True, spin=True)
    sc.particle(kind="mote", amount=8, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -2), spread=180,
                speed=(1, 3), gravity=(0, 0), colour_fade=True)
    sc.modulate = (1.0, 0.93, 0.87)
    return sc


# ==========================================================================
# 6-2 shadow_camp
# ==========================================================================

def scene_shadow_camp() -> Scene26:
    """6-2 影之營地: Mordred's camp at night. Behind a palisade with a gate and watchtowers, rows of tents
    under black wolf banners; campfires and lanterns light the trampled ground."""
    sc = Scene26("brown", 0.55)
    img = sc.img
    K.sky_bands(img, 0, 80, [("navy", 0.0), ("night_d", 0.4), ("night", 0.8)], seed=6201)
    K.stars(img, (0, 0, IMG_W, 60), 40, 6202, big=3)
    K.moon(img, 60, 30, 9, halo=("night_d", "night"), crescent=0.45)
    K.hills_layer(img, 80, 6, 27.0, "navy", rim="night", seed=6203, fill_to=100)
    K.treeline(img, 96, ("ink", "navy", "navy", "night_d"), 6204, size=(4.0, 6.0), step=6, pointy=True)
    # the palisade with a gate in the middle and two watchtowers
    for x in range(IMG_W):
        for y in range(96, 118):
            img.set(x, y, "navy")
    pal = K7.palisade(IMG_W, 26, 6205)
    img.blit(pal, 0, 94)
    gx = MIDX
    for y in range(98, 124):
        for x in range(gx - 16, gx + 16):
            img.set(x, y, "night_d" if abs(x - gx) < 13 else "brown_d")
    for x in range(gx - 18, gx + 18):
        img.set(x, 96, "brown")
        img.set(x, 97, "brown_d")
    for tx in (gx - 34, gx + 24):
        for y in range(70, 124):
            img.set(tx, y, "brown")
            img.set(tx + 9, y, "brown_d")
            if y % 9 == 0:
                img.hline(tx, tx + 9, y, "umber")
        img.rect(tx - 3, 66, 16, 8, "brown_d")
        img.hline(tx - 3, tx + 12, 66, "brown")
        for k in range(8):
            img.hline(tx - 2 + k // 2, tx + 11 - k // 2, 58 + k, "slate" if k > 1 else "ash")
        sc.anim("torch", tx + 2, 72, tx % 4, 1.0)
    # ground: trampled earth, calm in the middle
    W.textured_floor(img, (0, 118, IMG_W, IMG_H), ("brown_d", "brown", "gold_d"), 6206, scale=44)
    rng = random.Random(6207)
    for _ in range(120):
        x, y = rng.randrange(0, IMG_W - 4), rng.randrange(120, IMG_H)
        if rng.random() < W.calm_k(x, y) * 0.95:
            continue
        b = name_at(img, x, y)
        if b in ("brown", "gold_d"):
            for (dx, dy) in ((0, 0), (1, 0), (2, 1)):
                img.set(x + dx, y + dy, dk(b))
    # tents inside the palisade (top), more along the sides
    for (x, y, w, h, op) in ((60, 124, 36, 24, True), (100, 130, 30, 20, False), (196, 128, 32, 22, True),
                             (232, 122, 36, 24, False), (8, 132, 34, 22, False), (268, 136, 30, 20, True)):
        t = K7.tent(w, h, x + y, open_=op)
        AW.place(img, t, x, y - t.h + 24, shadow=(1.0, -1), shadow_dx=4)
    for (x, y, w, h) in ((AX0 - 16, 220, 34, 22), (AX1 - 18, 250, 34, 22), (6, 300, 34, 22), (258, 330, 36, 24)):
        t = K7.tent(w, h, x * 3 + y, open_=(x + y) % 2 == 0)
        AW.place(img, t, x, y, shadow=(1.0, -1), shadow_dx=4)
    # campfires, racks, barrels at the edges of the clearing
    fires = ((AX0 + 2, AY0 + 6), (AX1 - 18, AY0 + 90), (AX0 + 4, AY1 - 30), (MIDX - 8, AY1 + 6))
    for i, (x, y) in enumerate(fires):
        K7.soft_disc(img, x + 8, y + 12, 26, 15, "gold_d", seed=6210 + i, only=("brown", "brown_d"))
        K7.soft_disc(img, x + 8, y + 12, 14, 8, "dirt", seed=6215 + i, only=("gold_d",))
        for k in range(10):
            a = k / 10 * 2 * math.pi
            img.set(int(x + 8 + math.cos(a) * 9), int(y + 13 + math.sin(a) * 4), "stone_d")
        sc.anim("campfire", x, y, i % 4, 1.0)
        sc.light("campfire", x + 8, y + 8, 0.7)
    for (x, y) in ((AX0 - 24, AY0 + 60), (AX1 + 4, AY0 + 30), (AX1 + 6, AY1 - 40)):
        AW.place(img, K7.spear_rack(x), x, y, shadow=(1.0, -1), shadow_dx=3)
    for (x, y) in ((AX1 - 16, AY1 - 20), (AX0 - 18, AY1 + 6)):
        AW.place(img, K.barrel(x), x, y, shadow=(0.9, 0), shadow_dx=3)
        AW.place(img, K7.crate(12, 10), x + 10, y + 4, shadow=(1.0, -1), shadow_dx=3)
    # lantern posts and wolf banners
    for i, (x, y) in enumerate(((AX0 - 4, AY0 + 120), (AX1 - 6, AY0 + 160))):
        img.vline(x + 4, y - 4, y + 22, "brown_d")
        img.hline(x + 2, x + 6, y - 4, "brown_d")
        sc.anim("lantern", x, y - 3, i, 0.7)
        sc.light("lantern", x + 4, y + 6, 0.55)
    for i, x in enumerate((76, 116, 208, 248)):
        img.vline(x + 2, 100, 124, "umber")
        sc.anim("flag_wolf", x - 3, 100, i % 4, 0.9 + (i % 3) * 0.1)
    # bottom: the palisade again
    img.blit(K7.palisade(IMG_W, 22, 6208), 0, AY1 + 30)
    for x in range(IMG_W):
        for y in range(AY1 + 56, IMG_H):
            img.set(x, y, "navy" if y < AY1 + 62 else "night_d")
    K.treeline(img, IMG_H - 10, ("ink", "navy", "navy", "night_d"), 6209, size=(5.0, 8.0), step=7, pointy=True)
    # foreground: dark pine boughs in the top corners, stakes at the bottom
    for side in (0, 1):
        sc.put_fg(AL.pine_branch(66, 40, 6230 + side, side == 1), 30 if side == 0 else IMG_W - 96, 80)
    sc.put_fg(K7.palisade(IMG_W, 18, 6231, ("ink", "umber", "brown_d")), 0, 400)
    sc.particle(kind="ember", amount=14, lifetime=2.5, rect=(-10, 60, 190, 320), velocity=(0.1, -1), spread=30,
                speed=(8, 14), gravity=(0, -3), colour_fade=True)
    sc.particle(kind="smoke", amount=8, lifetime=5.0, rect=(-10, 60, 190, 320), velocity=(0.2, -1), spread=20,
                speed=(3, 6), gravity=(0, 0), colour_fade=True)
    sc.particle(glow=True, kind="spark_violet", amount=8, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(1, 3), gravity=(0, 0), blink=True)
    sc.modulate = (0.88, 0.88, 1.0)
    return sc


# ==========================================================================
# 6-3 occupied_town
# ==========================================================================

def scene_occupied_town() -> Scene26:
    """6-3 被佔領的城下町: Camelot's town at sunset, every house hung with Mordred's black wolf flags. The
    market stalls are shuttered, leaves blow along the cobbles, lanterns are being lit; the castle
    stands dark against the orange sky."""
    sc = Scene26("stone", 0.45)
    img = sc.img
    dusk_sky(img, 96, 6301, [("dusk", 0.0), ("rose", 0.3), ("coral", 0.55), ("peach", 0.78), ("gold_l", 0.92)])
    long_clouds(img, [(20, 0, 140), (34, 160, 320)], ("rose", "peach"), 6302)
    for (cx, w, h) in ((152, 22, 58), (126, 12, 44), (180, 12, 46), (104, 9, 32), (204, 9, 34)):
        t = K.round_tower(w, h, ("plum", "dusk", "dusk", "rose"), cx, cone=("plum", "dusk", "rose"), cone_h=w,
                          outline="plum", windows=1, lit=True)
        img.blit(t, cx - t.w // 2, 92 - t.h)
    for (cx, h) in ((152, 58), (126, 44), (180, 46)):
        sc.anim("flag_wolf", cx - 6, 92 - h - 12 - 18, cx % 4, 1.0)
    W.house_row(img, 112, -8, IMG_W + 8, 6303, walls=[("dusk", "rose", "peach")], roofs=[("plum", "dusk", "rose")],
                heights=(8, 12), widths=(18, 28), thorns=0.0, lit=0.5, timber=0.0, outline="plum")
    walls = [("stone", "stone_l", "white"), ("dirt", "sand", "cream"), ("gold_d", "dirt", "sand")]
    roofs = [("wine", "red_d", "red"), ("brown_d", "brown", "gold_d"), ("plum", "dusk", "rose")]
    houses = W.house_row(img, AY0 - 4, -6, IMG_W + 6, 6304, walls, roofs, heights=(22, 30), widths=(24, 34), gables=0.6,
                         thorns=0.0, lit=0.7)
    for i, (hx, top, w) in enumerate(houses):
        if 0 < hx < IMG_W - 20 and i % 2 == 0:
            sc.anim("flag_wolf", hx + w // 2 - 5, top + 14, i % 4, 0.9 + (i % 3) * 0.1)
    # the street: warm cobbles, the square of grey flags in the middle
    K7.voronoi_stones(img, (0, AY0 - 4, IMG_W, IMG_H), 9, ("stone", "stone"), "stone_d", 6305, squash=0.75,
                      mask=lambda x, y: not in_arena(x, y))
    K7.voronoi_stones(img, (AX0, AY0, AX1, AY1), 18, ("stone", "stone"), "stone_d", 6306, squash=0.8)
    K.edge_shadow(img, AY0 - 4, 7, 0, IMG_W)
    K7.leaf_litter(img, (0, AY0 - 6, IMG_W, IMG_H), 260, 6307, calm=0.97)
    # shuttered stalls, barrels, a crow on a sign, lantern posts
    for (x, y, cols, s) in ((4, 196, ("slate", "ash"), 1), (246, 240, ("plum", "dusk"), 2), (6, 300, ("slate", "ash"), 3)):
        st = K.awning_stall(40 if x < 100 else 50, cols, s)
        AW.place(img, st, x, y, shadow=(1.0, 0), shadow_dx=-6)
    for (x, y) in ((AX0 + 4, AY0 + 6), (AX1 - 18, AY0 + 4), (AX0 + 2, AY1 - 26), (250, 330), (40, 350)):
        AW.place(img, K.barrel(x), x, y, shadow=(0.9, 0), shadow_dx=-3)
    for i, (x, y) in enumerate(((AX0 - 4, AY0 + 80), (AX1 - 6, AY0 + 130), (AX0 - 4, AY1 - 70))):
        img.vline(x + 4, y - 4, y + 24, "iron")
        img.hline(x + 1, x + 7, y - 4, "iron")
        sc.anim("lantern", x, y - 3, i, 0.7)
        sc.light("lantern", x + 4, y + 6, 0.6)
    # bottom: house roofs below the street
    roofs_b = Canvas(IMG_W, 60)
    W.house_row(roofs_b, 60, -8, IMG_W + 8, 6308, walls, roofs, heights=(10, 16), widths=(26, 40), thorns=0.0, lit=0.6)
    img.blit(roofs_b, 0, IMG_H - 54)
    K.edge_shadow(img, AY1 + 2, 3)
    # foreground: near eaves in the top corners, flower pots gone autumn at the bottom
    for side in (0, 1):
        eave = K.roof(46, 16, ("plum", "dusk", "rose"), "ink", 6330 + side)
        sc.put_fg(eave.flipped() if side else eave, 40 if side == 0 else IMG_W - 90, 84)
    for k, x in enumerate((-4, 40, 214, 262)):
        pot = Canvas(30, 26)
        pot.rect(4, 14, 22, 11, "red_d")
        pot.rect(4, 14, 22, 2, "coral")
        blob = AW.blob_canvas(30, 18, [(9, 10, 6), (17, 8, 7), (24, 11, 5)], list(K7.AUTUMN["orange"]), "umber",
                              6340 + k)
        pot.blit(blob, 0, 0)
        pot.outline_all("umber")
        sc.put_fg(pot, x, 404 + (k % 2) * 4)
    sc.light("sun", 220, 60, 1.2, tint=(1.0, 0.6, 0.4))
    sc.particle(kind="leaf_dusk", amount=10, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.4), spread=20,
                speed=(12, 18), gravity=(0, 3), colour_fade=True, spin=True)
    sc.particle(kind="leaf", amount=8, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.5), spread=20,
                speed=(10, 16), gravity=(0, 3), colour_fade=True, spin=True)
    sc.particle(kind="smoke", amount=6, lifetime=5.0, rect=(-40, -70, 220, -20), velocity=(0.3, -1), spread=15,
                speed=(3, 6), gravity=(0, 0), colour_fade=True)
    sc.modulate = (1.0, 0.92, 0.88)
    return sc


# ==========================================================================
# 6-4 throne_hall
# ==========================================================================

def stained_window(w: int, h: int, seed: int) -> Canvas:
    """A tall stained-glass window: lead lines and panes in jewel colours, a gold dog emblem in the round."""
    rng = random.Random(seed)
    c = Canvas(w, h)
    cols = ["red", "water", "leaf_d", "gold", "violet", "sky", "red_d", "water_d"]
    for y in range(h):
        for x in range(w):
            dxn = (x + 0.5 - w / 2) / (w / 2)
            if y < (1 - math.sqrt(max(0.0, 1 - dxn * dxn))) * (w / 2):
                continue
            cell = (x // 4, (y + (x // 4) % 2 * 2) // 5)
            col = cols[int(AW.hash01(cell[0], cell[1], seed) * len(cols)) % len(cols)]
            if x % 4 == 0 or (y + (x // 4) % 2 * 2) % 5 == 0:
                col = "ink"
            c.set(x, y, col)
    for (x, y) in P.ellipse(w / 2, w / 2 + 2, w / 2 - 2, w / 2 - 2):
        if c.opaque(x, y):
            c.set(x, y, "gold_l" if (x + y) % 5 else "yellow")
    for (x, y) in P.ellipse(w / 2, w / 2 + 2, w / 2 - 2, w / 2 - 2):
        d = math.hypot(x + 0.5 - w / 2, y + 0.5 - (w / 2 + 2))
        if d > w / 2 - 3.2:
            c.set(x, y, "ink")
    c.outline_all("iron")
    return c


def scene_throne_hall() -> Scene26:
    """6-4 王座大廳: Camelot's throne room, taken by Mordred. Stained glass throws coloured light, black
    wolf banners hang where the red ones were, candelabras burn along the pillars; the carpet runs up
    to the dais; the marble floor carries the faint circle of the Round Table."""
    sc = Scene26("stone_l", 0.5)
    img = sc.img
    wall = K.masonry(IMG_W, 160, ("stone_d", "stone", "stone_l"), 6401, course=8, brick=(14, 22), mortar="iron",
                     base_dark=10)
    img.blit(wall, 0, 0)
    for i, x in enumerate((30, 82, 206, 258)):
        win = stained_window(20, 60, 6402 + i)
        img.blit(win, x - 10, 22)
    for x0 in (56, 108, 196, 248):
        col = K7.pillar(140, 14, ("stone_d", "stone", "stone_l", "white"), "iron")
        img.blit(col, x0 - col.w // 2, 18)
    # the dais with the throne under a wolf canopy
    for y in range(70, 136):
        for x in range(MIDX - 30, MIDX + 30):
            img.set(x, y, "plum" if x < MIDX - 26 or x >= MIDX + 26 else ("dusk" if x < MIDX else "plum"))
    for x in range(MIDX - 34, MIDX + 34):
        img.set(x, 68, "gold")
        img.set(x, 69, "gold_d")
        if x % 6 < 3:
            img.set(x, 70, "gold_d")
    K7.wolf_emblem(img, MIDX - 2, 76, "ink", "red")
    W.steps(img, MIDX - 46, MIDX + 46, 134, 4, ("stone", "stone_l", "white"), depth=5)
    thr = K7.throne(32, 40, ("iron", "slate", "ash"), ("wine", "red_d", "red"))
    AW.place(img, thr, MIDX - 16, 96, shadow=(1.0, -1), shadow_dx=4)
    # the floor: big marble slabs, the carpet up to the dais, the faint Round Table circle
    for y in range(154, IMG_H):
        for x in range(IMG_W):
            a, b = (x - MIDX + y) // 20, (x - MIDX - y) // 20
            img.set(x, y, "stone_l" if (a + b) % 2 == 0 else "fog")
            if (x - MIDX + y) % 20 == 0 or (x - MIDX - y) % 20 == 0:
                if fbm(x, y, 6403, 12, 2) > 0.6:
                    img.set(x, y, "white")
    for y in range(154, AY0 + 6):
        for x in range(MIDX - 22, MIDX + 22):
            img.set(x, y, "gold" if abs(x + 0.5 - MIDX) > 19 else ("plum" if (x + y) % 9 else "dusk"))
    W.rune_ring(img, MIDX, MIDY + 4, 82, "stone", "stone", ticks=12, width=1.0)
    K.calm_vignette(img, 12)
    K.edge_shadow(img, 154, 8, 0, IMG_W)
    # candelabras along the sides, banners on the pillars
    for (x, y) in ((AX0 - 4, AY0 + 10), (AX1 - 16, AY0 + 10), (AX0 - 4, AY1 - 50), (AX1 - 16, AY1 - 50),
                   (16, 250), (268, 250)):
        AW.place(img, K7.candelabra(x), x, y, shadow=(1.0, -1), shadow_dx=4)
        for dx in (0, 7, 14):
            sc.anim("candle", x + dx, y - 6, (x + dx) % 4, 0.9 + dx * 0.01)
    for i, x in enumerate((56, 108, 196, 248)):
        sc.anim("flag_wolf", x - 6, 34, i % 4, 0.8)
        sc.anim("flag_wolf_violet" if i % 2 else "flag_wolf", x - 6, 92, (i + 2) % 4, 0.9)
    # sides: suits of armour on stands, bottom: the doors and the lower hall
    for (x, y) in ((6, 180), (270, 180), (6, 320), (270, 320)):
        st = K.statue(x + y, ("iron", "steel_d", "steel"), "ink")
        AW.place(img, st, x, y, shadow=(1.0, -1), shadow_dx=4)
    lower = K.masonry(IMG_W, 30, ("stone_d", "stone", "stone_l"), 6404, course=8, mortar="iron", base_dark=0)
    img.blit(lower, 0, AY1 + 30)
    for y in range(AY1 + 30, AY1 + 60):
        for x in range(MIDX - 22, MIDX + 22):
            img.set(x, y, "brown_d" if abs(x - MIDX) > 1 else "umber")
    for y in range(AY1 + 60, IMG_H):
        for x in range(IMG_W):
            img.set(x, y, "iron" if y < AY1 + 64 else "ink")
    # foreground: dark pillars in the top corners, the carpet's end and the banister at the bottom
    for side in (0, 1):
        pil = K7.pillar(70, 18, ("ink", "iron", "steel_d", "steel"), "ink")
        sc.put_fg(pil.flipped() if side else pil, 58 if side == 0 else IMG_W - 82, 74)
    sc.put_fg(K7.railing(IMG_W, 14, ("ink", "iron", "steel_d"), "ink", step=8), 0, 398)
    sc.light_shafts = [(-40, 16, 0.06, (1.0, 0.75, 0.6)), (10, 14, 0.05, (0.7, 0.8, 1.0)),
                       (130, 16, 0.05, (1.0, 0.85, 0.6)), (180, 14, 0.06, (0.8, 0.7, 1.0))]
    sc.light("magic", MIDX, 100, 0.6, tint=(0.8, 0.5, 1.0))
    sc.particle(kind="mote", amount=14, lifetime=5.0, rect=(-10, -40, 200, 380), velocity=(0.2, -1), spread=180,
                speed=(1, 3), gravity=(0, 0), colour_fade=True)
    sc.particle(glow=True, kind="spark_violet", amount=8, lifetime=4.0, rect=(30, -60, 150, 60), velocity=(0, -1),
                spread=180, speed=(1, 3), gravity=(0, 0), blink=True)
    sc.modulate = (0.98, 0.94, 0.92)
    return sc


# ==========================================================================
# 6-5 avalon_gate
# ==========================================================================

def scene_avalon_gate() -> Scene26:
    """6-5 阿瓦隆之門: twilight in the apple orchard before Avalon. An old stone gate covered in ivy and
    blossom glows with golden runes; through it, the misty light of the isle; apple trees heavy with
    flowers and fruit line the grassy path; fireflies and petals drift."""
    sc = Scene26("grass", 0.45)
    img = sc.img
    K.sky_bands(img, 0, 100, [("night", 0.0), ("dusk", 0.3), ("rose", 0.6), ("peach", 0.85)], seed=6501, wave=2.0)
    K.stars(img, (0, 0, IMG_W, 40), 30, 6502, big=2)
    K.moon(img, 250, 26, 8, halo=("dusk",), crescent=0.5)
    K.hills_layer(img, 100, 8, 31.0, "dusk", rim="rose", seed=6503, fill_to=130)
    # the orchard behind the gate
    for i, x in enumerate(range(-14, IMG_W, 22)):
        t = K7.apple_tree(6510 + i, 30 + (i * 5) % 8, bloom=0.3)
        img.blit(t, x, 132 - t.h + (i * 5) % 6)
    # the gate: a big arch with the glowing isle seen through it
    gate = K7.stone_arch(76, 92, 6504, ("stone_d", "stone", "stone_l"), "iron", thick=12, inner="haze")
    gx, gy = MIDX - 38, 62
    img.blit(gate, gx, gy)
    # through the gate: Avalon's misty lake in a golden light, the isle with its orchard and white tower
    for y in range(gy, gy + 92):
        for x in range(gx, gx + 76):
            if name_at(img, x, y) != "haze":
                continue
            t = (y - gy) / 92
            col = "cream" if t < 0.3 else ("gold_l" if t < 0.42 else ("peach" if t < 0.5 else "haze"))
            if t >= 0.56:
                col = "sky_l" if (y + x // 7) % 5 else "white"
            isle = 0.5 + 0.07 * math.exp(-((x - MIDX - 6) / 12.0) ** 2) * 3
            if 0.48 < t < isle:
                col = "lilac" if x < MIDX + 6 else "violet"
            img.set(x, y, col)
    img.rect(MIDX + 4, gy + 30, 3, 14, "white")
    img.set(MIDX + 5, gy + 29, "lilac")
    for k in range(20):
        a = math.pi * (0.05 + 0.9 * k / 19)
        x = int(MIDX + math.cos(a) * 32)
        y = int(gy + 38 - math.sin(a) * 32)
        if k % 3 == 0:
            sc.anim("rune_gold", x - 1, y - 2, k % 6, 0.7)
    rng = random.Random(6505)
    for _ in range(90):
        x = rng.randrange(gx, gx + 76)
        y = rng.randrange(gy, gy + 92)
        if name_at(img, x, y) in ("stone", "stone_l", "stone_d"):
            img.set(x, y, rng.choice(("leaf_d", "forest", "leaf", "pink", "white")))
    sc.light("sun", MIDX, gy + 50, 0.9, tint=(1.0, 0.95, 0.8))
    # the path through the gate and the grass
    W.textured_floor(img, (0, 130, IMG_W, IMG_H), ("leaf_d", "grass", "leaf"), 6506, scale=44,
                     mask=lambda x, y: y >= 154 or name_at(img, x, y) in ("dusk", "rose", None))
    for y in range(140, 160):
        for x in range(MIDX - 28, MIDX + 28):
            if abs(x - MIDX) < 22 + (y - 140) * 0.3 and name_at(img, x, y) in ("leaf_d", "grass", "leaf", "dusk", "rose"):
                img.set(x, y, "stone_l" if (x // 6 + y // 4) % 2 else "fog")
    W.blades(img, (0, 154, IMG_W, IMG_H), 6507, 0.045)
    K7.voronoi_stones(img, (MIDX - 30, 154, MIDX + 30, AY0 + 30), 9, ("fog", "fog"), "ash", 6508, squash=0.8,
                      mask=lambda x, y: abs(x - MIDX) < 24 - (y - 154) * 0.5 + 3 * math.sin(y / 3.0))
    K.edge_shadow(img, 154, 3, 0, IMG_W)
    # petals on the grass, mossy stones, baskets of apples
    K7.leaf_litter(img, (0, 160, IMG_W, IMG_H), 220, 6509, cols=("pink", "white", "peach", "pink", "lilac"), calm=0.98)
    for (x, y) in ((AX0 + 4, AY0 + 30), (AX1 - 22, AY0 + 70), (AX0 + 2, AY1 - 30), (AX1 - 18, AY1 - 20)):
        AW.place(img, AW.rock(x + y, 14, 8, ("stone_d", "stone", "stone_l", "white"), "iron", "leaf_d"), x, y,
                 shadow=(1.0, -1), shadow_dx=3)
    for (x, y) in ((AX0 - 20, AY0 + 120), (AX1 + 4, AY0 + 40)):
        bask = Canvas(14, 10)
        for yy in range(4, 10):
            for xx in range(1, 13):
                bask.set(xx, yy, "gold_d" if (xx + yy) % 3 else "brown")
        for (ax, ay) in ((3, 3), (6, 2), (9, 3), (5, 4), (8, 4)):
            bask.set(ax, ay, "red")
            bask.set(ax + 1, ay, "red_d")
        bask.outline_all("umber")
        AW.place(img, bask, x, y, shadow=(1.0, -1), shadow_dx=3)
    # apple trees along the sides and at the bottom
    for (x, y) in ((-10, 180), (254, 196), (-6, 290), (258, 300), (-10, 390), (254, 400)):
        AW.place(img, K7.apple_tree(x + y, 36, bloom=0.45), x, y, shadow=(1.0, -2), shadow_dx=6)
    for i, x in enumerate(range(-14, IMG_W, 24)):
        AW.place(img, K7.apple_tree(6520 + i, 32, bloom=0.4), x, 420 + (i * 5) % 10, shadow=None)
    # foreground: blossom branches in the top corners, blossom bushes at the bottom
    for side in (0, 1):
        br = AL.foliage(54, 34, 6530 + side, ("forest", "leaf_d", "leaf", "spring"), "forest_d")
        rr = random.Random(6531 + side)
        for _ in range(26):
            fx, fy = rr.randrange(2, 52), rr.randrange(2, 30)
            if br.opaque(fx, fy) and name_at(br, fx, fy) != "forest_d":
                br.set(fx, fy, rr.choice(("pink", "white", "peach")))
        sc.put_fg(br.flipped() if side else br, 34 if side == 0 else IMG_W - 88, 80)
    AL.clumps(sc.fg, 6532, ("forest", "leaf_d", "leaf", "spring"), "forest_d", flowers=["pink", "white", "peach"])
    for i, (x, y) in enumerate(((AX0 - 10, 150), (AX1 - 30, 146), (60, 200), (230, 280))):
        sc.anim("mist_strip", x - 10, y, i % 8, 0.5 + i * 0.1)
    sc.particle(kind="blossom", amount=14, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.5), spread=25,
                speed=(8, 14), gravity=(0, 2), colour_fade=True, spin=True)
    sc.particle(glow=True, kind="firefly", amount=10, lifetime=5.0, rect=(-10, 0, 200, 380), velocity=(0, -1),
                spread=180, speed=(2, 5), gravity=(0, 0), blink=True)
    sc.particle(kind="mist", amount=8, lifetime=8.0, rect=(-40, 40, 260, 340), velocity=(1, 0), spread=10,
                speed=(2, 5), gravity=(0, 0), colour_fade=True)
    sc.modulate = (0.97, 0.94, 1.0)
    return sc


# ==========================================================================
# 6-6 avalon_hill
# ==========================================================================

def scene_avalon_hill() -> Scene26:
    """6-6 阿瓦隆之丘: the last battle, on the green hill of Avalon at sunset. The sun touches the lake and
    lays a road of gold across it towards a little stone jetty; islands with apple orchards float in the
    haze; blossoming apple trees crown the hill; a ring of white flowers marks the hilltop; petals fall."""
    sc = Scene26("leaf", 0.4)
    img = sc.img
    hz = 112
    dusk_sky(img, hz, 6601, [("dusk", 0.0), ("rose", 0.2), ("coral", 0.42), ("peach", 0.62), ("gold_l", 0.8),
                            ("cream", 0.92)])
    long_clouds(img, [(20, -10, 120), (34, 160, 320), (56, 30, 170), (74, 200, 300), (90, -10, 90)],
                ("rose", "peach"), 6602)
    sun_disc(img, MIDX, hz - 2, 15, rings=((1.0, "cream"), (1.7, "gold_l"), (2.6, "peach")), horizon=hz)
    # far islands of Avalon with orchards and a small white tower
    for (cx, w, h) in ((40, 34, 8), (262, 40, 10)):
        for x in range(cx - w, cx + w):
            top = hz - int(h * max(0.0, 1 - ((x - cx) / w) ** 2))
            for y in range(top, hz + 1):
                img.set(x, y, "dusk" if x < cx + w * 0.3 else "plum")
            img.set(x, top, "rose")
        K.treeline(img, hz - h + 3, ("plum", "dusk", "dusk", "rose"), cx, size=(2.5, 4.0), step=4, x0=cx - w + 8,
                   x1=cx + w - 8, jitter=2)
    img.rect(262, hz - 26, 5, 16, "peach")
    img.vline(266, hz - 26, hz - 11, "rose")
    for k in range(5):
        img.hline(261 + k // 2, 267 - k // 2, hz - 30 + k, "rose")
    # the lake: sunset bands with the sun's road of gold
    W.water_bands(img, (0, hz, IMG_W, 152), [("peach", 0.0), ("rose", 0.2), ("dusk", 0.55), ("plum", 0.9)], 6603,
                  glints=("coral",), n_glints=30)
    K7.glitter_path(img, MIDX, hz + 1, 150, 6604, cols=("cream", "gold_l"), spread=0.5)
    # a little stone jetty into the lake (top centre): pale slabs, posts, ripples round its end
    for y in range(126, 154):
        half = 9 + (y - 126) * 0.12
        for x in range(int(MIDX - half), int(MIDX + half) + 1):
            col = "stone_l" if x < MIDX - half + 3 else ("stone" if x < MIDX + half - 2 else "stone_d")
            if (y - 126) % 6 == 5:
                col = "stone_d"
            img.set(x, y, col)
        img.set(int(MIDX - half) - 1, y, "iron")
        img.set(int(MIDX + half) + 1, y, "iron")
    for x in range(int(MIDX) - 11, int(MIDX) + 12):
        img.set(x, 125, "stone_l")
        img.set(x, 154, "iron")
    for x in (MIDX - 12, MIDX + 11):
        img.rect(x, 128, 2, 6, "stone_d")
        img.hline(x - 1, x + 2, 134, "plum")
    # the shore: reeds and a pale pebble strand
    def shore(x: float) -> float:
        return 146 + 3 * math.sin(x / 19.0) + 1.5 * math.sin(x / 7.0)
    for x in range(IMG_W):
        y0 = int(shore(x))
        if abs(x - MIDX) < 10:
            continue
        for y in range(y0, y0 + 4):
            img.set(x, y, "peach" if y == y0 else ("stone_l" if y < y0 + 3 else "stone"))
    # the hilltop: warm green grass, calm; a ring of white flowers round it
    W.textured_floor(img, (0, 148, IMG_W, IMG_H), ("leaf_d", "leaf", "spring"), 6605, scale=46,
                     mask=lambda x, y: y > shore(x) + 3 and not (abs(x - MIDX) < 10 and y < 158))
    W.blades(img, (0, 150, IMG_W, IMG_H), 6606, 0.045, mask=lambda x, y: y > shore(x) + 4)
    for (cx, cy) in ((AX0 + 10, AY0 + 30), (AX1 - 12, AY0 + 30), (AX0 + 10, AY1 - 6), (AX1 - 12, AY1 - 6),
                     (AX0 - 20, MIDY), (AX1 + 16, MIDY)):
        AW.sprinkle_flowers(img, (cx - 10, cy - 6, cx + 10, cy + 6), 9, cx * 3 + cy, ["white", "pink", "white"])
    K7.leaf_litter(img, (0, 156, IMG_W, IMG_H), 220, 6607, cols=("pink", "white", "peach", "pink"), calm=0.98)
    K.edge_shadow(img, 152, 3, 0, IMG_W)
    # old standing stones at four points of the ring
    for (x, y, h) in ((AX0 + 2, AY0 + 6, 18), (AX1 - 14, AY0 + 6, 20), (AX0 + 2, AY1 - 28, 18), (AX1 - 14, AY1 - 28, 20)):
        AW.place(img, K.menhir(h, x, ("stone_d", "stone", "stone_l"), "iron", rune="gold_l"), x, y,
                 shadow=(1.1, -1), shadow_dx=5)
    # apple trees in blossom: the hill's crown and its sides
    for (x, y) in ((-16, 118), (40, 112), (222, 114), (272, 120)):
        t = K7.apple_tree(x + y, 42, bloom=0.55, apples=0)
        cx = x + t.w / 2
        for yy in range(y + t.h - 6, y + t.h + 70):
            k = (yy - (y + t.h - 6)) / 76
            half = t.w * 0.32 * (1 - k * 0.5)
            for xx in range(int(cx - half + k * 10), int(cx + half + k * 10)):
                if AW._cluster(xx, yy, 6640) * 0.8 + k < 0.95 and name_at(img, xx, yy) in ("leaf", "spring", "leaf_l"):
                    AW.shade(img, xx, yy, -1)
        AW.place(img, t, x, y, shadow=(1.0, -2), shadow_dx=6)
    for (x, y) in ((AX0 - 34, 214), (AX1 - 4, 250)):
        AW.place(img, K7.apple_tree(x * 7 + y, 38, bloom=0.5, apples=1), x, y, shadow=(1.0, -2), shadow_dx=6)
    for (x, y) in ((-10, 210), (254, 230), (-6, 320), (258, 330)):
        AW.place(img, K7.apple_tree(x * 3 + y, 38, bloom=0.5, apples=1), x, y, shadow=(1.0, -2), shadow_dx=6)
    for i, x in enumerate(range(-14, IMG_W, 24)):
        AW.place(img, K7.apple_tree(6620 + i, 34, bloom=0.5, apples=0), x, 418 + (i * 5) % 10, shadow=None)
    # foreground: blossom boughs in the top corners, blossom bushes at the bottom
    for side in (0, 1):
        br = AL.foliage(56, 36, 6630 + side, ("forest", "leaf_d", "leaf", "spring"), "forest_d")
        rr = random.Random(6631 + side)
        for _ in range(40):
            fx, fy = rr.randrange(2, 54), rr.randrange(2, 32)
            if br.opaque(fx, fy) and name_at(br, fx, fy) != "forest_d":
                br.set(fx, fy, rr.choice(("pink", "white", "pink", "peach")))
        sc.put_fg(br.flipped() if side else br, 34 if side == 0 else IMG_W - 90, 80)
    AL.clumps(sc.fg, 6632, ("forest", "leaf_d", "leaf", "spring"), "forest_d", flowers=["pink", "white", "peach"],
              gap=(12, 24))
    for i, (x, y) in enumerate(((MIDX - 22, 116), (MIDX + 18, 120), (MIDX - 30, 130), (MIDX + 26, 136), (MIDX - 36, 144),
                                (MIDX + 36, 146), (40, 124), (250, 128))):
        sc.anim("sun_glint", x, y, i % 6, 0.7 + (i % 3) * 0.1)
    for i, (x, y) in enumerate(((AX0 + 6, AY0 + 2), (AX1 - 10, AY0 + 2), (AX0 + 6, AY1 - 32), (AX1 - 10, AY1 - 32))):
        sc.anim("rune_gold", x + 2, y + 6, i % 6, 0.6)
    for i, (x, y, k) in enumerate(((AX0 - 8, AY0 + 60, "flower_white"), (AX1 + 2, AY0 + 100, "flower_pink"),
                                   (AX0 - 6, AY1 - 50, "flower_pink"), (AX1 + 4, AY1 - 20, "flower_white"))):
        sc.anim(k, x, y, i % 4, 0.9)
    sc.light("sun", MIDX, hz - 4, 1.5, tint=(1.0, 0.75, 0.5))
    sc.particle(kind="blossom", amount=20, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.5), spread=25,
                speed=(8, 14), gravity=(0, 2), colour_fade=True, spin=True)
    sc.particle(kind="petal", amount=8, lifetime=6.0, rect=(-20, -60, 220, 300), velocity=(1, 0.4), spread=25,
                speed=(10, 16), gravity=(0, 2), colour_fade=True, spin=True)
    sc.particle(glow=True, kind="spark_gold", amount=8, lifetime=4.0, rect=(-10, -40, 200, 380), velocity=(0, -1),
                spread=180, speed=(1, 3), gravity=(0, 0), blink=True)
    sc.modulate = (1.0, 0.95, 0.9)
    return sc


SCENES = {
    "camlann_field": scene_camlann_field,
    "shadow_camp": scene_shadow_camp,
    "occupied_town": scene_occupied_town,
    "throne_hall": scene_throne_hall,
    "avalon_gate": scene_avalon_gate,
    "avalon_hill": scene_avalon_hill,
}
