"""Measure 360×640 native A/B frames, including a paired warning-ink subtraction."""
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

EVIDENCE = Path(__file__).resolve().parents[1] / "docs/validation/scarecrow-swing-art"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def arc_band(points):
    """Pixel centres within 1.5 physical pixels of the real outer polyline."""
    y, x = np.ogrid[0.5:640:1.0, 0.5:360:1.0]
    mask = np.zeros((640, 360), dtype=bool)
    for a, b in zip(points, points[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        fraction = np.clip(((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy), 0, 1)
        mask |= (x - a[0] - dx * fraction) ** 2 + (y - a[1] - dy * fraction) ** 2 <= 1.5 ** 2
    return mask


def active_ink(on, off):
    return np.max(np.abs(on.astype(np.int16) - off.astype(np.int16)), axis=2) >= 8


def sprite_bounds_mask(corners):
    # Include one filtering pixel around the measured 32×32 logical draw quad.
    x, y = zip(*corners)
    mask = np.zeros((640, 360), dtype=bool)
    top, bottom = max(0, math.floor(min(y)) - 1), min(640, math.ceil(max(y)) + 1)
    left, right = max(0, math.floor(min(x)) - 1), min(360, math.ceil(max(x)) + 1)
    mask[top:bottom, left:right] = True
    return mask


def compare(frame, geometry):
    rows = {}
    assert len(geometry["before"]) == 24 and geometry["before"].keys() == geometry["after"].keys()
    for name, old in sorted(geometry["before"].items()):
        new = geometry["after"][name]
        assert old["tick"] == new["tick"] and old["outer_arc"] == new["outer_arc"], name
        base, candidate = (frame(v, "on", name) for v in ("before", "after"))
        assert base.shape == candidate.shape == (640, 360, 3)
        different = np.any(base != candidate, axis=2)
        outside = different & ~(sprite_bounds_mask(old["sprite_corners"]) | sprite_bounds_mask(new["sprite_corners"]))
        control = name.startswith("elite-") or name in {"cancel-interrupted", "right-idle", "right-rest"}
        row = {"tick": old["tick"], "different": int(different.sum()), "outside_sprite": int(outside.sum()), "control": control}
        ok = row["outside_sprite"] == 0 and ((row["different"] == 0) == control)
        if old["outer_arc"]:
            old_ink = active_ink(base, frame("before", "off", name))
            new_ink = active_ink(candidate, frame("after", "off", name))
            band = arc_band(old["outer_arc"])
            row.update(arc_old=int((old_ink & band).sum()), arc_new=int((new_ink & band).sum()),
                       arc_lost=int((old_ink & ~new_ink & band).sum()), arc_gained=int((new_ink & ~old_ink & band).sum()),
                       ink_lost=int((old_ink & ~new_ink).sum()), ink_gained=int((new_ink & ~old_ink).sum()))
            ok = ok and row["arc_old"] > 0 and row["arc_lost"] == 0
        row["passed"] = ok
        rows[name] = row
    return rows


def from_raw(root):
    trace = (EVIDENCE / "combat.tsv").read_bytes()
    geometry = {}
    for version in ("before", "after"):
        for ink in ("on", "off"):
            assert (root / version / ink / "combat.tsv").read_bytes() == trace
        geometry[version] = json.loads((root / version / "on/frames.json").read_text())
        assert geometry[version] == json.loads((root / version / "off/frames.json").read_text())

    def read(version, ink, name):
        with Image.open(root / version / ink / (name + ".png")) as im:
            return np.asarray(im.convert("RGB"))

    return compare(read, geometry)


def from_archive():
    index = json.loads((EVIDENCE / "native/index.json").read_text())
    assert len(index["pictures"]) == 70
    assert digest((EVIDENCE / "combat.tsv").read_bytes()) == index["combat_sha256"]

    def read(version, ink, name):
        ref = index["pictures"][f"{version}/{ink}/{name}.png"]
        with Image.open(EVIDENCE / "native" / ref["album"]) as im:
            im.seek(ref["page"])
            pixels = im.convert("RGB")
            assert digest(pixels.tobytes()) == ref["rgb_sha256"], name
            return np.asarray(pixels)

    return compare(read, index["geometry"])


if __name__ == "__main__":
    result = from_raw(Path(sys.argv[1])) if len(sys.argv) > 1 else from_archive()
    print(json.dumps(result, indent=2))
    sys.exit(0 if all(row["passed"] for row in result.values()) else 1)
