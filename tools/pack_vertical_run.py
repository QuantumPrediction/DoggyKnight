"""Register the selected full-resolution GPT Image paintings for front and rear motion."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "docs/validation/playfeel/direction"
RUNTIME = ROOT / "assets/illustrated/motion"
TILE_W, TILE_H = 256, 192


def pack(sheet):
    with Image.open(ART / sheet["source"]) as source:
        master = source.convert("RGBA")
    atlas = Image.new("RGBA", (TILE_W * 4, TILE_H * 2))
    for index, frame in enumerate(sheet["frames"]):
        drawing = master.crop(tuple(frame["master_rect"]))
        alpha = drawing.getchannel("A")
        # Tiny nonzero matte values appear in the generator's transparent gutter.
        # Keep the anti-aliased brush edge and give opaque watercolor an opaque core.
        drawing.putalpha(alpha.point(lambda a: round(255 * max(0, min(1, (a - 12) / 239)))))
        w, h = drawing.size
        factor = frame["height"] / (frame["sole_y"] - frame["top_y"] + 1)
        size = round(w * factor), round(h * factor)
        # Pillow resamples RGBA with premultiplied alpha.
        drawing = drawing.resize(size, Image.Resampling.LANCZOS)
        x = round(120 - frame["spine_x"] * factor)
        y = round(176 - frame["sole_y"] * factor)
        if x < 2 or y < 2 or x + size[0] > TILE_W - 2 or y + size[1] > TILE_H - 2:
            raise ValueError(f'{sheet["role"]} frame {index} exceeds its registration')
        atlas.alpha_composite(drawing, (index % 4 * TILE_W + x, index // 4 * TILE_H + y))
    atlas.save(RUNTIME / f'vertical_{sheet["role"]}.png', optimize=True)


if __name__ == "__main__":
    for item in json.loads((ART / "paintings.json").read_text())["sheets"]:
        pack(item)
