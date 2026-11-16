#!/usr/bin/env python3
"""Regenerates every C 線 asset from code (DEV_PLAN C1). Python 3 standard library only.

    python3 tools/pixel/build_all.py                  # write all assets into assets/
    python3 tools/pixel/build_all.py --preview /tmp/p # also write enlarged preview sheets there
    python3 tools/pixel/build_all.py --no-music       # skip the (slower) music rendering

Then let Godot pick up new or changed files:

    godot --headless --path . --import

What it writes (paths are the contracts of DEV_PLAN 4.6 / 4.9 — never rename them):
  assets/palette.png                              the 40-colour palette
  assets/sprites/<code>/<code>.png + _frames.tres  goldie, bulldog, scarecrow, crow, black_knight,
                                                  scarecrow_archer, armored_husk, scarecrow_captain, merlin (v2.3)
  assets/fx/{arrow,sword_wave,pitchfork}/*        v2.3 projectiles
  assets/portraits/<speaker>/<expression>.png     v2.3 dialogue portraits, 48x48
  assets/story/<id>.png                           v2.3 storybook illustrations, 160x120
  assets/fx/<name>/<name>.png + _frames.tres       slash, hit_spark, exp_orb, ultimate_slash, dizzy_stars, dust
  assets/fx/particles/<name>.tscn + tex/*.png     11 one-shot CPUParticles2D effects (DEV_PLAN 4.10)
  assets/icons/tricks/<id>.png                    sit, wag, fetch, shake, spin, bark (16x16)
  assets/tiles/chapter1_tiles.png                 16x16 tile set
  assets/backgrounds/<name>.png + .tscn           sword_stone, wheat_field, meadow, farm_fence, crow_forest, bridge
  assets/backgrounds/anim/*                       animated layers and ambient particle textures
  assets/ui/*.png                                 buttons, panels, HUD icons, logo
  assets/app_icon/*.png                           app icons, store graphics, boot splash
  assets/sfx/<id>.wav                             the 23 sound effects
  assets/music/<id>.wav (+ .import)               7 music tracks (4 seamless loops, 3 jingles; QOA import)
  ui/theme/palette_colors.gd                      the palette as GDScript constants
  ui/theme/main_theme.tres                        the UI theme (font, buttons, panels)
  ui/screens/ofl_text.gd                          the font licence text for the credits screen

Files whose content did not change are left untouched, so re-running is cheap and
produces no git noise.
"""

from __future__ import annotations

import os
import sys

sys.dont_write_bytecode = True   # keep tools/pixel free of __pycache__
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art_brand  # noqa: E402
import art_cast  # noqa: E402
import art_enemies  # noqa: E402
import art_fx  # noqa: E402
import art_heroes  # noqa: E402
import art_particles  # noqa: E402
import art_portraits  # noqa: E402
import art_story  # noqa: E402
import art_ui  # noqa: E402
import art_world  # noqa: E402
import music_gen  # noqa: E402
import sfx_gen  # noqa: E402
from palette import PALETTE, rgba  # noqa: E402
from pixel import Canvas, build_sheet, contact_sheet, res_path, write_text  # noqa: E402

CHARACTERS = {
    "goldie": (art_heroes.goldie_v2, (24, 24)),
    "bulldog": (art_heroes.bulldog_v2, (24, 24)),
    "scarecrow": (art_enemies.scarecrow_v2, (24, 24)),
    "crow": (art_enemies.crow_v2, (16, 16)),
    "black_knight": (art_enemies.black_knight_v2, (48, 48)),
}


def write_palette() -> None:
    img = Canvas(len(PALETTE) * 8, 8)
    for i, (name, _) in enumerate(PALETTE):
        img.rect(i * 8, 0, 8, 8, name)
    img.save(res_path("res://assets/palette.png"), opaque=True)
    lines = [
        "class_name PaletteColors",
        "extends RefCounted",
        "## 全遊戲共用的 40 色調色盤(由 tools/pixel/build_all.py 自動產生,請勿手改)。",
        "## 介面程式用這些常數,讓顏色與像素圖一致。",
        "",
    ]
    for name, hexv in PALETTE:
        lines.append('const %s: Color = Color("%s")' % (name.upper(), hexv))
    write_text(res_path("res://ui/theme/palette_colors.gd"), "\n".join(lines) + "\n")


def write_ofl_text() -> None:
    """Copies assets/fonts/OFL.txt into a GDScript constant for the credits screen
    (plain .txt files are not exported with the game, scripts always are)."""
    path = res_path("res://assets/fonts/OFL.txt")
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        text = f.read().replace("\r\n", "\n").strip()
    esc = text.replace("\\", "\\\\").replace('"', '\\"')
    lines = [
        "extends RefCounted",
        "## 俐方體11號(Cubic 11)的授權全文,由 tools/pixel/build_all.py 從 assets/fonts/OFL.txt 複製。",
        "## 製作名單畫面顯示這段文字(SIL OFL 要求隨字型附上授權)。請勿手改。",
        "",
        'const TEXT: String = "%s"' % esc.replace("\n", "\\n"),
        "",
    ]
    write_text(res_path("res://ui/screens/ofl_text.gd"), "\n".join(lines))


def main() -> None:
    preview_dir = None
    if "--preview" in sys.argv:
        preview_dir = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(preview_dir, exist_ok=True)

    write_palette()
    sheets = {}
    for code, (fn, size) in CHARACTERS.items():
        anims = fn()
        build_sheet("res://assets/sprites/%s" % code, code, anims, size)
        sheets[code] = anims
    for code, (fn, size) in art_cast.SPRITES.items():          # v2.3 cast (CS4)
        anims = fn()
        build_sheet("res://assets/sprites/%s" % code, code, anims, size)
        sheets[code] = anims
    for name, (fn, size) in art_cast.PROJECTILES.items():
        anims = fn()
        build_sheet("res://assets/fx/%s" % name, name, anims, size)
        sheets["fx_" + name] = anims
    art_portraits.write_all()                                    # v2.3 portraits (CS2)
    art_story.write_all()                                        # v2.3 storybook pages (CS3)
    for name, (fn, size) in art_fx.ALL.items():
        anims = fn()
        build_sheet("res://assets/fx/%s" % name, name, anims, size)
        sheets["fx_" + name] = anims
    art_particles.write_all()
    art_ui.write_all()
    art_ui.write_theme()
    art_world.write_all()
    goldie_idle = sheets["goldie"][0].frames[0]
    bulldog_idle = sheets["bulldog"][0].frames[0]
    art_brand.write_all(goldie_idle, bulldog_idle, art_world.prop(art_world.SWORD_STONE),
                        art_world.prop(art_world.TREE), art_world.prop(art_world.BUSH))
    sfx_gen.write_all()
    if "--no-music" not in sys.argv:
        music_gen.write_all()
    write_ofl_text()

    if preview_dir:
        for code, anims in sheets.items():
            scale = 8 if code in ("crow", "fx_arrow", "fx_pitchfork") else (3 if code == "black_knight" else 6)
            contact_sheet([a.frames for a in anims], scale).save(os.path.join(preview_dir, "%s.png" % code))
        print("previews in", preview_dir)
    assert rgba("ink")
    print("C 線 assets regenerated.")


if __name__ == "__main__":
    main()
