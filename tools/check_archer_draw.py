"""Archive and measure the native 360×640 before/after archer recordings."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

from check_scarecrow_swing import active_ink, digest, sprite_bounds_mask

EVIDENCE = Path(__file__).resolve().parents[1] / "docs/validation/archer-draw-motion"
VERSIONS = ("before", "after")
CASES = ("right", "left", "front", "back", "sidestep", "interrupt")
STAGES = ("tracking", "locked", "hot", "loose", "lower")
CONTROLS = {"right-idle", "right-move", "right-hit", "interrupt-cancelled"}
ORIGINALS = {"field-locked": "right-locked", "field-release": "right-loose",
             "field-sidestep": "sidestep-late-step"}
EXPECTED = {f"{case}-{stage}" for case in CASES[:-1] for stage in STAGES} | CONTROLS | {
    "sidestep-track-turn", "sidestep-late-step", "interrupt-tracking", "interrupt-locked"
}


def read_rgb(path, page=0):
    with Image.open(path) as image:
        image.seek(page)
        assert image.size == (360, 640), path
        return image.convert("RGB")


def raw_geometry(root):
    trace = (EVIDENCE / "combat.tsv").read_bytes()
    geometry = {}
    for version in VERSIONS:
        captured = []
        for ink in ("on", "off"):
            directory = root / version / ink
            assert (directory / "combat.tsv").read_bytes() == trace, directory
            captured.append(json.loads((directory / "frames.json").read_text()))
        assert captured[0] == captured[1], version
        geometry[version] = captured[0]
    return geometry


def bands(lane):
    x0, y0, x1, y1, length, width, _ = lane
    dx, dy = x1 - x0, y1 - y0
    factor = length / (dx * dx + dy * dy)
    y, x = np.ogrid[0.5:640:1.0, 0.5:360:1.0]
    along = ((x - x0) * dx + (y - y0) * dy) * factor
    across = ((y - y0) * dx - (x - x0) * dy) * factor
    return along > 24.0, (abs(along - (length - 2.0)) <= 2.5) & (abs(across) <= width / 2 + 4)


def compare(geometry, read):
    for version in VERSIONS:
        assert set(geometry[version]) == EXPECTED
    result = {}
    for name in sorted(EXPECTED):
        old, new = (geometry[v][name] for v in VERSIONS)
        assert old["tick"] == new["tick"] and old["lane"] == new["lane"], name
        before, after = (np.asarray(read(v, "on", name)) for v in VERSIONS)
        different = np.any(before != after, axis=2)
        bounds = sprite_bounds_mask(old["corners"])
        assert np.array_equal(bounds, sprite_bounds_mask(new["corners"])), name
        row = {"tick": old["tick"], "different": int(different.sum()),
               "outside_sprite": int((different & ~bounds).sum()), "control": name in CONTROLS}
        ok = row["outside_sprite"] == 0 and ((row["different"] == 0) == row["control"])
        if old["lane"]:
            far, bracket = bands(old["lane"])
            old_ink = active_ink(before, np.asarray(read("before", "off", name)))
            new_ink = active_ink(after, np.asarray(read("after", "off", name)))
            lost, gained = old_ink & ~new_ink, new_ink & ~old_ink
            row.update(far_old=int((old_ink & far).sum()), far_new=int((new_ink & far).sum()),
                       far_lost=int((lost & far).sum()), far_gained=int((gained & far).sum()),
                       near_lost=int((lost & ~far).sum()), near_gained=int((gained & ~far).sum()))
            ok = ok and row["far_old"] > 0 and row["far_lost"] == 0
            if old["lane"][-1]:
                row.update(end_old=int((old_ink & bracket).sum()), end_lost=int((lost & bracket).sum()))
                ok = ok and row["end_old"] > 0 and row["end_lost"] == 0
        row["passed"] = ok
        result[name] = row
    return result


def pack(root, geometry):
    album_dir = EVIDENCE / "native"
    album_dir.mkdir(exist_ok=True)
    for file, key in ORIGINALS.items():
        (EVIDENCE / (file + ".png")).write_bytes((root / "after/on" / (key + ".png")).read_bytes())
    pictures = {}
    for case in CASES:
        pages, by_hash = [], {}
        paths = sorted(root.glob(f"*/*/{case}-*.png"),
                       key=lambda p: (geometry["before"][p.stem]["tick"], p.parent.name, p.parent.parent.name))
        for path in paths:
            image = read_rgb(path)
            sha = digest(image.tobytes())
            if sha not in by_hash:
                by_hash[sha] = len(pages)
                pages.append(image)
            pictures[path.relative_to(root).as_posix()] = {
                "album": case + ".webp", "page": by_hash[sha], "rgb_sha256": sha,
                "source_png_sha256": digest(path.read_bytes())}
        pages[0].save(album_dir / (case + ".webp"), save_all=True, append_images=pages[1:],
                      duration=400, loop=0, lossless=True, method=4, quality=100, minimize_size=True)
    index = {"combat_sha256": digest((EVIDENCE / "combat.tsv").read_bytes()),
             "geometry": geometry, "pictures": pictures}
    (album_dir / "index.json").write_text(json.dumps(index, indent=2) + "\n")


def archived():
    directory = EVIDENCE / "native"
    index = json.loads((directory / "index.json").read_text())
    assert index["combat_sha256"] == digest((EVIDENCE / "combat.tsv").read_bytes())

    def read(version, ink, name):
        record = index["pictures"][f"{version}/{ink}/{name}.png"]
        im = read_rgb(directory / record["album"], record["page"])
        assert digest(im.tobytes()) == record["rgb_sha256"], name
        return im

    geometry = index["geometry"]
    expected_images = sum(1 + bool(s["lane"]) for g in geometry.values() for s in g.values())
    assert len(index["pictures"]) == expected_images
    for file, key in ORIGINALS.items():
        path = EVIDENCE / (file + ".png")
        assert digest(path.read_bytes()) == index["pictures"][f"after/on/{key}.png"]["source_png_sha256"], path
    return compare(geometry, read)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", type=Path, nargs="?", help="Directory with before/after and on/off runs")
    parser.add_argument("--pack", action="store_true", help="Save the raw captures as lossless, verifiable albums")
    args = parser.parse_args()
    if args.raw is None:
        if args.pack:
            parser.error("--pack needs the raw captures directory")
        results = archived()
    else:
        geo = raw_geometry(args.raw)
        results = compare(geo, lambda v, ink, n: read_rgb(args.raw / v / ink / (n + ".png")))
        if args.pack:
            pack(args.raw, geo)
            assert archived() == results
    print(json.dumps(results, indent=2))
    raise SystemExit(0 if all(r["passed"] for r in results.values()) else 1)
