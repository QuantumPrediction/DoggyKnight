"""Check the recorded 360×640 A/B captures against the production sprite bounds."""
import csv
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops

GALLERY = Path(__file__).resolve().parents[1] / "docs/validation/field-chests/native"
TICKS = {"field": 32}
for tier, contact in (("ordinary", 36), ("elite", 62), ("boss", 88)):
    for frame in range(3):
        TICKS[f"{tier}-{frame}"] = contact + frame * 6


def sprite_box(record):
    x, y = float(record["x"]), float(record["y"])
    sx, sy = (1.15, 0.9) if record["animation"] == "open" else (1.0, 1.0)
    # 24×24 centered sprite with offset (0,-8). Camera scale is two physical
    # pixels per world unit. Allow one border pixel for texture filtering.
    return (math.floor(2 * (x - 12 * sx)) - 1, math.floor(2 * (y - 20 * sy)) - 1,
            math.ceil(2 * (x + 12 * sx)) + 1, math.ceil(2 * (y + 4 * sy)) + 1)


def check():
    for line in (GALLERY / "sha256sums.txt").read_text().splitlines():
        expected, name = line.split()
        assert hashlib.sha256((GALLERY / name).read_bytes()).hexdigest() == expected, name
    trace = (GALLERY / "before/pickup.tsv").read_bytes()
    assert trace == (GALLERY / "after/pickup.tsv").read_bytes() == (GALLERY.parent / "pickup.tsv").read_bytes()
    records = list(csv.DictReader(trace.decode().splitlines(), delimiter="\t"))
    assert len(records) == 414
    summary = {}
    for name, tick in TICKS.items():
        with Image.open(GALLERY / "before" / (name + ".png")) as old, Image.open(GALLERY / "after" / (name + ".png")) as new:
            assert old.size == new.size == (360, 640), name
            r, g, b = ImageChops.difference(old.convert("RGB"), new.convert("RGB")).split()
        mask = ImageChops.lighter(ImageChops.lighter(r, g), b)
        changed = mask.width * mask.height - mask.histogram()[0]
        assert changed > 0, name
        for record in records:
            if int(record["tick"]) == tick and record["phase"] != "removed":
                mask.paste(0, sprite_box(record))
        assert mask.getbbox() is None, f"{name}: changed pixels outside a chest"
        summary[name] = {"tick": tick, "changed_rgb_pixels": changed, "outside_chests": 0}
    return summary


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
