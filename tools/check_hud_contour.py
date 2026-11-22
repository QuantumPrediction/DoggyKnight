#!/usr/bin/env python3
"""Compare source-locked normal/selected-warning knockout native captures against PR #22."""
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "docs/validation/guard-success-toast"
BASE = "d9188279e0b4720dd35b7b7532f42a9dbb6f4b8e"
FROZEN = {"frame-hashes.csv": "59d43af1087c7b05423ffcbb51734016618ca25d9fcc61fb6c068d4018ffd116",
          "render.json": "0866d8332a4c426dac38da97dd468c08c833cf7d7ac629769911bae9915f3e66"}
CASES = {"marksman": ("20980.1", 4959, (4989, 4990), "readout_px", [[8, 516], [164, 600]]),
         "outrider": ("17197.2", 364, (374, 375), "guard_button_px", [[192, 452], [260, 520]])}
EXPOSED = {"marksman": ((142, 464), (145, 465), (149, 466)),
           "outrider": ((182, 473), (184, 472), (186, 470), (183, 541))}
ALLOWED = {"ui/hud/combat_readout.gd", "ui/hud/companion_guard_control.gd"}
FRAME_FIELDS = {"tick", "process_frame", "file", "image_size", "selected_ink_muted",
                "warning_eligible", "progress", "selected_sector_px", "nearby_sectors_px",
                "player_px", "player_world", "production_overlap", "coach_hud", "sha256"}
HUD_FIELDS = {"success_drawn", "coach_slot", "success_nearby_warning", "lesson_completed",
              "persisted_completion_flag", "lesson_completion_signals", "coach_px",
              "coach_close_active", "foreground", "guard_button_px", "guard_button_visible",
              "ultimate_button_px", "ultimate_button_visible", "pause_button_px", "readout_px",
              "readout_warning"}
FOREGROUND_FIELDS = {"guard_state", "guard_disabled", "guard_tint", "icon_path", "guard_label",
                     "charge_label", "charge_visible", "action", "detail", "dodge", "meter",
                     "accent", "action_ink", "safe_px", "guard_blocks_touch",
                     "guard_mouse_filter", "readout_mouse_filter"}


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def frozen():
    for name, digest in FROZEN.items():
        require(hashlib.sha256((ARCHIVE / name).read_bytes()).hexdigest() == digest, f"archive changed: {name}")
    with (ARCHIVE / "frame-hashes.csv").open() as stream:
        rows = list(csv.DictReader(stream))
    images = {(r["route"], int(r["tick"])): r["candidate_png_sha256"] for r in rows}
    anchors = {r["route"]: r for r in json.loads((ARCHIVE / "render.json").read_text())["comparison"]}
    required = {(route, i) for route, (_, first, *_) in CASES.items() for i in range(first, first + 35)}
    require(len(rows) == 70 and images.keys() == required, "incomplete or duplicate #22 references")
    return images, anchors


def sample_points(polygon, rect):
    """Unique raster positions; each has a center and flanks across its own segment."""
    (left, top), (right, bottom) = rect
    samples = {}
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy)
        for step in range(3, math.floor(length - 3) + 1):
            x, y = a[0] + dx * step / length, a[1] + dy * step / length
            points = tuple((math.floor(x - side * dy / length), math.floor(y + side * dx / length))
                           for side in (0, -3, 3))
            if all(left <= px < right and top <= py < bottom for px, py in points):
                samples.setdefault(points[0], points)
    return list(samples.values())


def contour_count(normal, muted, samples):
    # Signed RGB contributions cancel static decoration and constant fill.
    signal = normal.astype(np.int16) - muted.astype(np.int16)
    count = 0
    for (x, y), (ax, ay), (bx, by) in samples:
        a, b = signal[y, x] - signal[ay, ax], signal[y, x] - signal[by, bx]
        if np.any((np.sign(a) == np.sign(b)) & (np.minimum(abs(a), abs(b)) >= 16)):
            count += 1
    return count


def knockout_valid(normal, muted, polygon, exposed=()):
    changed = np.any(normal != muted, axis=2)
    if not polygon:
        return not changed.any()
    mask = Image.new("L", (normal.shape[1], normal.shape[0]))
    ImageDraw.Draw(mask).polygon([tuple(point) for point in polygon], fill=255)
    # Two screen pixels for the 1 logical-pixel outline, one for raster rounding.
    allowed = np.asarray(mask.filter(ImageFilter.MaxFilter(7))) != 0
    if np.any(changed & ~allowed):
        return False
    return not exposed or any(np.max(abs(normal[y, x].astype(int) - muted[y, x])) >= 16 for x, y in exposed)


def same_frame(frame):
    return {k: v for k, v in frame.items() if k not in {"selected_ink_muted", "sha256", "process_frame", "file"}}


def validate_frame_schema(frame):
    require(FRAME_FIELDS <= frame.keys() and all(frame[key] is not None for key in FRAME_FIELDS),
            "incomplete frame manifest")
    hud = frame["coach_hud"]
    require(isinstance(hud, dict) and HUD_FIELDS <= hud.keys()
            and all(hud[key] is not None for key in HUD_FIELDS), "incomplete HUD manifest")
    foreground = hud["foreground"]
    require(isinstance(foreground, dict) and FOREGROUND_FIELDS <= foreground.keys()
            and all(foreground[key] is not None for key in FOREGROUND_FIELDS),
            "incomplete foreground manifest")


def archived_metadata(anchor):
    return {row["tick"]: row for row in anchor["selected_candidate_metadata"]}


def require_archived_state(frame, archived):
    reference = archived.get(frame["tick"])
    if reference is None:
        return
    require(frame["production_overlap"] == reference["production_overlap"],
            f"t{frame['tick']}: production overlap differs from #22")
    hud = frame["coach_hud"]
    require(all(hud.get(key) == value for key, value in reference["coach_hud"].items()),
            f"t{frame['tick']}: HUD, controls or persistence differs from #22")


def load_frame(folder, route, frame):
    path = folder / route / frame["file"]
    blob = path.read_bytes()
    require(hashlib.sha256(blob).hexdigest() == frame["sha256"], f"PNG hash mismatch: {path}")
    with Image.open(io.BytesIO(blob)) as image:
        require(image.format == "PNG" and image.size == (360, 640), f"invalid image: {path}")
        return np.asarray(image.convert("RGB"))


def compare(folders):
    hashes, anchors = frozen()
    runs = [json.loads((path / "validation.json").read_text()) for path in folders]
    for i, run in enumerate(runs):
        require(run["engine"] == "4.7.2.stable.official.ed1daf0bf" and run["source_unchanged"]
                and run["source_sha256"] == run["source_sha256_after"], "engine or source changed")
        require(run["without_selected_ink"] is bool(i % 2), "expected baseline normal/muted, candidate normal/muted")
        inputs = run["hud_comparison_inputs"]
        require(inputs["base"] == BASE and inputs["observer_sha256"] == runs[0]["hud_comparison_inputs"]["observer_sha256"],
                "unmatched #22 source or observation tools")
        require(set(inputs["production_paths_changed"]) <= (ALLOWED if i >= 2 else set()), "unexpected production changes")
        require(run["source_sha256"] == runs[i - i % 2]["source_sha256"], "normal/knockout source mismatch")
        require(len(run["cases"]) == 2 and {c["case"] for c in run["cases"]} == CASES.keys(), "missing or duplicate route")
    results, failures = [], []
    for route, (target, first, critical, key, rect) in CASES.items():
        cases = [next(c for c in r["cases"] if c["case"] == route) for r in runs]
        ref = anchors[route]
        archived = archived_metadata(ref)
        require(len(archived) == 5, f"{route}: incomplete #22 metadata anchors")
        for folder, case in zip(folders, cases):
            require(case["target"] == target and case["accepted"] and case["engine_exit"] == 1
                    and case["display"].lower() == "x11" and case["render_device"] == "opengl3"
                    and case["adapter"] == ref["adapter"], f"{route}: incompatible native replay")
            for keyname, filename in [("trace", "report.json.windows.jsonl"), ("report", "report.json")]:
                digest = hashlib.sha256((folder / route / filename).read_bytes()).hexdigest()
                require(case[f"{keyname}_sha256"] == digest == ref[f"matching_{keyname}_sha256"],
                        f"{route}: {keyname} differs from #22")
            require([f["tick"] for f in case["frames"]] == list(range(first, first + 35)), f"{route}: tick mismatch")
        for frames in zip(*(c["frames"] for c in cases)):
            f = frames[0]
            tick = f["tick"]
            label = f"{route} t{tick}"
            for frame in frames:
                validate_frame_schema(frame)
            require(f["sha256"] == hashes[route, tick], f"{label}: normal baseline differs from #22")
            require(all(same_frame(other) == same_frame(f) for other in frames), f"{label}: geometry, controls or state differ")
            require_archived_state(f, archived)
            hud = f["coach_hud"]
            require((tick not in critical or hud[key] == rect) and "foreground" in hud, f"{label}: missing foreground or displaced target")
            require(all(other["selected_ink_muted"] is (bool(i % 2) and f["warning_eligible"])
                        for i, other in enumerate(frames)), f"{label}: wrong knockout state")
            images = [load_frame(p, route, x) for p, x in zip(folders, frames)]
            allowed = np.zeros((640, 360), dtype=bool)
            for name in ("guard_button_px", "readout_px"):
                (x, y), (r, b) = hud[name]
                allowed[int(y):int(b), int(x):int(r)] = True
            for a, b in ((0, 2), (1, 3)):
                if np.any(np.any(images[a] != images[b], axis=2) & ~allowed):
                    failures.append(f"{label}: changed pixels outside fixed backplates")
            witness = EXPOSED[route] if tick == first + 2 else ()
            for i in (0, 2):
                if not knockout_valid(images[i], images[i + 1], f["selected_sector_px"], witness):
                    failures.append(f"{label}: knockout changed other pixels or missed an exposed witness")
            samples = sample_points(f["selected_sector_px"], hud[key])
            before, after = (contour_count(images[i], images[i + 1], samples) for i in (0, 2))
            results.append(dict(route=route, tick=tick, samples=len(samples), baseline=before, candidate=after,
                                net=after - before, critical=tick in critical))
            if tick in critical and (not samples or after - before < 3):
                failures.append(f"{label}: contour gain below three samples")
    return {"pixel_gate_passed": not failures, "foreground_visual_review": "pending", "frames": results, "failures": failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-archive", action="store_true")
    parser.add_argument("captures", type=Path, nargs="*", help="baseline normal/muted, then candidate normal/muted")
    args = parser.parse_args()
    if args.check_archive and not args.captures:
        images, anchors = frozen()
        print(f"{len(images)} frozen PNG digests, {len(anchors)} reference pairs; no candidate evaluated")
        return
    if len(args.captures) != 4 or args.check_archive:
        parser.error("supply four capture folders, or --check-archive alone")
    try:
        verdict = compare(args.captures)
    except (OSError, ValueError, KeyError, TypeError, StopIteration) as error:
        parser.exit(2, f"Non-comparable captures: {error}\n")
    print(json.dumps(verdict, indent=2))
    raise SystemExit(0 if verdict["pixel_gate_passed"] else 1)


if __name__ == "__main__":
    main()
