"""v2.7 (C 世界, CW7): the eighteen chapter 4-6 backgrounds. Python 3 standard library only.

    chapter 4 沉沒之國   art_v27_sea.py    bright summer sea and the sunken kingdom
    chapter 5 紅龍與白龍 art_v27_snow.py   snow, ice, hot springs and fire
    chapter 6 卡姆蘭之戰 art_v27_dusk.py   autumn and dusk, the finale at Avalon

Every scene is a 304x512 palette image + a foreground layer + animated props, particles and light
sprites (art_v26_kit.Scene26, written with art_v26_kit.write_scene); the arena (image 64..240 x
160..384) is a calm, mid-toned, crafted floor (soft value shifts, material at the edges, props
framing it), as in the v2.6 chapter 3 polish.

    python3 tools/pixel/art_v27_world.py [names...] [--preview DIR]
"""

from __future__ import annotations

import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art_v26_kit as K  # noqa: E402
import art_v27_kit as K7  # noqa: E402
import art_v27_dusk as DUSK  # noqa: E402
import art_v27_sea as SEA  # noqa: E402
import art_v27_snow as SNOW  # noqa: E402

SCENES = {}
SCENES.update(SEA.SCENES)
SCENES.update(SNOW.SCENES)
SCENES.update(DUSK.SCENES)


def write_all(names: list[str] | None = None, preview_dir: str | None = None) -> None:
    K7.write_shared()
    for name, fn in SCENES.items():
        if names and name not in names:
            continue
        sc = fn()
        K.write_scene(name, sc)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            full = sc.img.copy()
            full.blit(sc.fg, 0, 0)
            full.scaled(2).save(os.path.join(preview_dir, "%s_full.png" % name))


if __name__ == "__main__":
    args = sys.argv[1:]
    pdir = None
    if "--preview" in args:
        i = args.index("--preview")
        pdir = args[i + 1]
        del args[i:i + 2]
    write_all(args or None, pdir)
    print("v2.7 world written")
