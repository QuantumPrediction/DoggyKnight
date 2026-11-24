"""Compare two runs of capture_locomotion.gd and retain the original rendered pixels."""
import argparse
import csv
import hashlib
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ROLES = ("knight", "mage", "archer")
POSE = ("sheet", "column", "row", "mirror_x")
GEOMETRY = ("sole_x", "sole_y", "rotation", "skew")
FULL = (46, 238, 284, 318, 375, 482)
STRIP = (64, 184, 360, 364)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def rows(path):
    with path.open() as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def key(row, fields=POSE):
    return tuple(row[field] for field in fields)


def switches(sequence):
    return sum(key(a) != key(b) for a, b in zip(sequence, sequence[1:]))


def describe(game, drawings):
    def measure(start, end):
        return {
            "ticks": [start, end - 1],
            "distance": round(sum(math.hypot(float(row["dx"]), float(row["dy"])) for row in game[start:end]), 4),
            "paint_changes": switches(drawings[start:end]),
        }

    def stop(start, end, row):
        matching = [t for t in range(start, end)
                    if drawings[t]["sheet"].startswith("settle_") and int(drawings[t]["row"]) == row]
        standing = [t for t in matching if drawings[t]["column"] == "1"]
        return {"ticks": [start, end - 1], "facing_retained": len(matching), "first_standing": min(standing, default=None)}

    role = game[0]["role"]
    wrong_turn = []
    for tick in range(46, 53):
        if drawings[tick]["sheet"] != "stride_" + role or (float(game[tick]["dx"]) < 0) != (drawings[tick]["mirror_x"] == "1"):
            wrong_turn.append(tick)
    for tick in range(284, 291):
        if drawings[tick]["sheet"] != "vertical_" + role or (float(game[tick]["dy"]) < 0) != (drawings[tick]["row"] == "1"):
            wrong_turn.append(tick)
    soles = [float(r["sole_y"]) for r in drawings[202:256]]
    wall = measure(202, 256)
    wall["sole_y_range"] = round(max(soles) - min(soles), 6)
    return {
        "wrong_heading_ticks": wrong_turn,
        "equal_time": [measure(12, 42), measure(96, 126)],
        "equal_distance": [measure(12, 36), measure(96, 144)],
        "wall": wall,
        "front_stop": stop(314, 330, 0),
        "rear_stop": stop(466, 510, 1),
    }


def check_run(before, after, output):
    common = (before / "physics.tsv").read_bytes()
    if common != (after / "physics.tsv").read_bytes():
        raise ValueError("Gameplay traces differ")
    game = rows(before / "physics.tsv")
    old, new = (rows(folder / "paint.tsv") for folder in (before, after))
    expected = [(role, str(tick)) for role in ROLES for tick in range(552)]
    for seq in (game, old, new):
        if [(r["role"], r["tick"]) for r in seq] != expected:
            raise ValueError("Missing, reordered or unexpected samples")
    summary = {"physics_sha256": sha(common), "physics_ticks": len(game),
               "paint_sha256": [sha((d / "paint.tsv").read_bytes()) for d in (before, after)], "roles": {}}
    for role in ROLES:
        g, a, b = ([row for row in s if row["role"] == role] for s in (game, old, new))
        base, candidate = (describe(g, sequence) for sequence in (a, b))
        full, half = candidate["equal_time"]
        if not 8 <= full["paint_changes"] <= 10 or not 4 <= half["paint_changes"] <= 5:
            raise ValueError(f"{role}: full- or half-speed cadence is outside the registered window")
        if abs(full["distance"] - 2 * half["distance"]) > 0.001:
            raise ValueError(f"{role}: expected half-speed distance")
        short, long = candidate["equal_distance"]
        same_distance = abs(short["distance"] - long["distance"]) < 0.001
        turns = candidate["wrong_heading_ticks"]
        wall = candidate["wall"]
        if turns or not same_distance or abs(short["paint_changes"] - long["paint_changes"]) > 1:
            raise ValueError(f"{role}: turning or ground-distance cadence failed")
        if wall["distance"] or wall["paint_changes"] or wall["sole_y_range"] > 0.02:
            raise ValueError(f"{role}: wall still moves")
        for name, begin, end in (("front_stop", 314, 330), ("rear_stop", 466, 510)):
            stop = candidate[name]
            if stop["facing_retained"] != end - begin or stop["first_standing"] not in range(begin + 1, end):
                raise ValueError(f"{role}: {name} does not plant and settle")
        if not all(row["input_x"] == "0.500000" and row["touch"] == "0" for row in g[88:148]):
            raise ValueError(f"{role}: fractional action was not exercised")
        if not all(row["input_x"] == "-1.000000" and row["touch"] == "1" for row in g[330:370]):
            raise ValueError(f"{role}: touch joystick did not receive both drags")
        attacks = [i for i, row in enumerate(g) if row["animation"] == "attack"]
        rolls = [i for i, row in enumerate(g) if row["rolling"] == "1"]
        if not attacks or not rolls or not any(int(row["swings"]) for row in g):
            raise ValueError(f"{role}: action was not exercised")
        if any(key(a[i]) != key(b[i]) for i in attacks) or any(key(a[i], POSE + GEOMETRY) != key(b[i], POSE + GEOMETRY) for i in rolls):
            raise ValueError(f"{role}: combat action drawing changed")
        summary["roles"][role] = {"before": base, "after": candidate, "attack_pose_ticks": len(attacks),
                                  "roll_pose_and_transform_ticks": len(rolls), "swings": int(g[425]["swings"])}
    for src, name in ((before / "physics.tsv", "physics.tsv"), (before / "paint.tsv", "paint-before.tsv"),
                      (after / "paint.tsv", "paint-after.tsv")):
        shutil.copyfile(src, output / name)
    return summary, {(r["role"], int(r["tick"])): r for r in game}


def native_pairs(before, after, output, game):
    frames, records = [], []
    for role in ROLES:
        for tick in FULL:
            slug = f"{role}-{tick:03}-full.png"
            paths = [folder / slug for folder in (before, after)]
            a, b = (Image.open(path).convert("RGB") for path in paths)
            if a.size != (360, 640) or b.size != a.size:
                raise ValueError(f"{slug}: invalid native frame")
            # Fixed margin around the same physics anchor in the two source frames.
            row = game[(role, tick)]
            cx, cy = (round(2 * float(row[field])) for field in ("x", "y"))
            box = (max(0, cx - 48), max(0, cy - 56), min(360, cx + 48), min(640, cy + 56))
            red, green, blue = ImageChops.difference(a, b).split()
            mask = ImageChops.lighter(red, ImageChops.lighter(green, blue)).point(lambda v: 255 if v else 0)
            different = mask.histogram()[255]
            mask.paste(0, box)
            pair = Image.new("RGB", (720, 640))
            pair.paste(a)
            pair.paste(b, (360, 0))
            frames.append(pair)
            records.append({"role": role, "tick": tick, "png_sha256": [sha(path.read_bytes()) for path in paths],
                            "rgb_sha256": [sha(im.tobytes()) for im in (a, b)], "different_pixels": different,
                            "actor_box": box, "outside_actor_box": mask.histogram()[255], "outside_bbox": mask.getbbox()})
    path = output / "native-pairs.webp"
    frames[0].save(path, save_all=True, append_images=frames[1:], lossless=True, duration=650, loop=0, method=4)
    with Image.open(path) as stored:
        if stored.n_frames != len(frames):
            raise ValueError("Missing native pairs")
        for index, frame in enumerate(frames):
            stored.seek(index)
            if stored.convert("RGB").tobytes() != frame.tobytes():
                raise ValueError(f"Native pair {index} changed in archive")
    return records


def wall_pixels(before, after):
    records = {}
    for role in ROLES:
        counts = []
        for folder in (before, after):
            digests = []
            for tick in range(216, 256, 2):
                with Image.open(folder / f"{role}-{tick:03}.png") as strip:
                    # Same 74×78 patch of turf around the planted soles in both versions.
                    patch = strip.convert("RGB").crop((286 - STRIP[0], 282 - STRIP[1],
                                                       360 - STRIP[0], 360 - STRIP[1]))
                    digests.append(sha(patch.tobytes()))
            counts.append(len(set(digests)))
        if counts[1] != 1:
            raise ValueError(f"{role}: parked native render still changes")
        records[role] = {"ticks": [216, 254], "interval_ticks": 2, "distinct_patches": counts}
    return records


def preview(before, after, output):
    # Fixed 112×96 crops in the original 360×640 camera; no role tracking or synthesis.
    cases = [
        ("knight", 32, (135, 266), "騎士掉頭"),
        ("mage", 216, (248, 266), "法師貼牆"),
        ("archer", 458, (169, 192), "弓手收步"),
    ]
    title = ImageFont.truetype(str(ROOT / "assets/fonts/StorySerif.otf"), 22)
    label = ImageFont.truetype(str(ROOT / "assets/fonts/StorySans.otf"), 18)
    frames = []
    for step in range(18):
        board = Image.new("RGB", (758, 431), "#1e221f")
        draw = ImageDraw.Draw(board)
        for col, (role, start, (x, y), caption) in enumerate(cases):
            left = 58 + col * 232
            draw.text((left + 112, 8), caption, font=title, anchor="mt", fill="#f7db9d")
            for row, folder in enumerate((before, after)):
                source = folder / f"{role}-{start + 2 * step:03}.png"
                with Image.open(source) as strip:
                    if strip.size != (STRIP[2] - STRIP[0], STRIP[3] - STRIP[1]):
                        raise ValueError(f"{source}: wrong strip or cropped crown")
                    sx, sy = x - STRIP[0], y - STRIP[1]
                    sample = strip.crop((sx, sy, sx + 112, sy + 96)).resize((224, 192), Image.Resampling.NEAREST)
                board.paste(sample, (left, 34 + row * 198))
        draw.text((28, 130), "#31", font=label, anchor="mm", fill="#d0d5cb")
        draw.text((28, 328), "本輪", font=label, anchor="mm", fill="#f7db9d")
        frames.append(board)
    path = output / "movement.webp"
    frames[0].save(path, save_all=True, append_images=frames[1:], lossless=True, method=4,
                   duration=[33, 33, 34] * 6, loop=0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/validation/natural-motion")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    report, track = check_run(args.before, args.after, args.output)
    report["base_commit"] = "9b7ed6c449087ae8a89daea997fcecde707b085e"
    report["candidate_source_sha256"] = {
        path: sha((ROOT / path).read_bytes()) for path in (
            "game/actors/player/player.gd", "ui/illustrated/actor_skin.gd", "ui/illustrated/art_catalog.gd",
            "tools/capture_locomotion.gd",
        )
    }
    report["wall_pixels"] = wall_pixels(args.before, args.after)
    report["pairs"] = native_pairs(args.before, args.after, args.output, track)
    preview(args.before, args.after, args.output)
    (args.output / "checks.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Verified {report['physics_ticks']} physics ticks and {len(report['pairs'])} lossless full native pairs.")
