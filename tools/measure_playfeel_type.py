"""Measure the actual warning / number layers from capture_playfeel_type.gd (Pillow, NumPy)."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

# Native pixels in the 360×640 view. The engine's trace crops exactly this rectangle.
TRACE = (50, 204, 158, 274)
PROOFS = ("title", "selection", "stage", "without-numbers", "without-warning-or-numbers",
          "impact", "impact-frame8", "player-hit")


def image(path):
    with Image.open(path) as source:
        return source.convert("RGB")


def hash_file(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def mask_near_perimeter(warning, geometry):
    """Pixels changed by the warning, within 2.2 physical pixels of its actual polygon."""
    x, y, logical_radius, half = geometry
    center = 2 * np.array([x, y])
    angles = -np.pi / 2 + np.linspace(-half, half, 11)
    arc = np.stack((np.cos(angles), np.sin(angles)), axis=1) * (2 * logical_radius)
    points = np.vstack((center, center + arc, center))
    rows, cols = np.indices(warning.shape)
    pixel = np.stack((cols + TRACE[0] + 0.5, rows + TRACE[1] + 0.5), axis=2)
    near = np.zeros_like(warning)
    for start, end in zip(points, points[1:]):
        delta = end - start
        along = np.clip(np.sum((pixel - start) * delta, axis=2) / (delta @ delta), 0, 1)
        distance = np.linalg.norm(pixel - start - along[:, :, None] * delta, axis=2)
        near |= distance <= 2.2
    return warning & near


def measure(directory):
    result = json.loads((directory / "metrics.json").read_text())
    if result["renderer"] != "X11":
        raise ValueError(f"Expected a native X11 capture in {directory}")
    clear = image(directory / "without-numbers.png")
    bg = np.array(clear.crop(TRACE))
    no_warning = np.array(image(directory / "without-warning-or-numbers.png").crop(TRACE))
    warning = np.any(bg != no_warning, axis=2)
    edge = mask_near_perimeter(warning, result["warning"])
    over_warning, over_band = [], []
    trace_fingerprint = hashlib.sha256()
    for tick in range(42):
        file = directory / "trace" / f"{tick:02}.png"
        trace_fingerprint.update(bytes.fromhex(hash_file(file)))
        ink = np.any(np.array(image(file)) != bg, axis=2)
        over_warning.append(int(np.sum(ink & warning)))
        over_band.append(int(np.sum(ink & edge)))
    result["warning_pixels"] = int(warning.sum())
    result["perimeter_band_pixels"] = int(edge.sum())
    result["ink_on_warning_per_frame"] = over_warning
    result["ink_on_perimeter_band_per_frame"] = over_band
    result["trace_png_sha256_chain"] = trace_fingerprint.hexdigest()
    result["png_sha256"] = {name: hash_file(directory / f"{name}.png") for name in PROOFS}
    result["ink_bounds_width_height_px"] = {}
    for name in ("impact", "impact-frame8"):
        diff = np.any(np.asarray(image(directory / f"{name}.png")) != np.asarray(clear), axis=2)
        bounds = []
        for hit in result["hits"]:
            x, y = (round(2 * v) for v in hit["anchor"])
            rows, cols = np.nonzero(diff[y - 82:y + 24, x - 50:x + 50])
            bounds.append([int(np.ptp(cols)) + 1, int(np.ptp(rows)) + 1])
        result["ink_bounds_width_height_px"][name] = bounds
    return result


def save_pairs(input_dir, output):
    # Native 1:1 detail, before on the left and after on the right.
    cuts = [("title", (0, 75, 360, 155)), ("selection", (0, 23, 360, 147)),
            ("stage", (0, 157, 360, 274)), ("impact", (0, 175, 360, 423)),
            ("player-hit", (0, 0, 360, 47))]
    height = sum(box[3] - box[1] for _, box in cuts) + 4 * (len(cuts) - 1)
    sheet = Image.new("RGB", (722, height), "#493d31")
    for i, label in enumerate(("base", "candidate")):
        y = 0
        for filename, box in cuts:
            piece = image(input_dir / label / f"{filename}.png").crop(box)
            sheet.paste(piece, (362 * i, y))
            y += piece.height + 4
    sheet.save(output / "comparison.webp", lossless=True, method=6)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("captures", type=Path, help="contains base, candidate and optionally rejected")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = {label: measure(args.captures / label) for label in ("base", "candidate")}
    if (args.captures / "rejected").exists():
        results["rejected"] = measure(args.captures / "rejected")
    base, candidate = results["base"], results["candidate"]
    if base["warning"] != candidate["warning"]:
        raise ValueError("The warning geometry differs")
    for key in ("class_cancel", "guard", "logo", "new_game", "pause", "ultimate"):
        if base["controls"][key] != candidate["controls"][key]:
            raise ValueError(f"The touch or logo geometry differs for {key}")
    # The pacing feature deliberately splits the departure row into two buttons.
    old, new = (result["controls"]["class_confirm"] for result in (base, candidate))
    if new[:2] != old[:2] or new[3] != old[3] or not 0 < new[2] <= old[2]:
        raise ValueError("The departure button left its row")
    for layer in ("without-numbers", "without-warning-or-numbers"):
        if base["png_sha256"][layer] != candidate["png_sha256"][layer]:
            raise ValueError(f"The {layer} controls differ")
    for before, after in zip(base["hits"], candidate["hits"], strict=True):
        for key in ("amount", "hp_lost", "popup_value", "lifetime", "style", "anchor"):
            if before[key] != after[key]:
                raise ValueError(f"Unpaired hit records: {key}")
    (args.output / "native.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    save_pairs(args.captures, args.output)
    image(args.captures / "candidate" / "selection.png").save(
        args.output / "selection.webp", lossless=True, method=6)



if __name__ == "__main__":
    main()
