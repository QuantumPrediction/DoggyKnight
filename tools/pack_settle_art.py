"""Register the two stopping drawings for each direction against the hero's existing feet."""

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "docs/validation/natural-motion/art"
RUNTIME = ROOT / "assets/illustrated/motion"
CELL = (256, 192)
HIP_X = 120
SOLE_Y = 176


def pack(role, sheet):
    source = ART / sheet["source"]
    if hashlib.sha256(source.read_bytes()).hexdigest() != sheet["webp_sha256"]:
        raise ValueError(f"{role} source fingerprint changed")
    with Image.open(source) as img:
        original = img.convert("RGBA")
    atlas = Image.new("RGBA", (CELL[0] * 2, CELL[1] * 2))
    for index, frame in enumerate(sheet["frames"]):
        left, top, right, bottom = frame["crop"]
        pose = original.crop((left, top, right, bottom))
        # Like the existing run paintings, lose only the low-opacity generator matte.
        pose.putalpha(pose.getchannel("A").point(lambda a: round(255 * max(0, min(1, (a - 12) / 239)))))
        ratio = frame["height"] / (frame["sole_y"] - frame["top_y"] + 1)
        pose = pose.resize((round(pose.width * ratio), round(pose.height * ratio)), Image.Resampling.LANCZOS)
        x = round(HIP_X - (frame["spine_x"] - left) * ratio)
        y = round(SOLE_Y - (frame["sole_y"] - top) * ratio)
        if x < 2 or y < 2 or x + pose.width >= CELL[0] - 2 or y + pose.height >= CELL[1] - 2:
            raise ValueError(f"{role}, frame {index}: painting extends beyond registered cell")
        atlas.alpha_composite(pose, (index % 2 * CELL[0] + x, index // 2 * CELL[1] + y))
    atlas.save(RUNTIME / f"settle_{role}.png", optimize=True)


if __name__ == "__main__":
    manifest = json.loads((ART / "paintings.json").read_text())
    for name, entry in manifest["sheets"].items():
        pack(name, entry)
