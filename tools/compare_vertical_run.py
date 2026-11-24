"""Verify the 24 native frame pairs and save their full decoded pixels and comparison loop."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def compare(baseline, candidate, output):
    trace = (baseline / "physics.tsv").read_bytes()
    if trace != (candidate / "physics.tsv").read_bytes():
        raise ValueError("Native movement traces differ")
    rows = list(csv.DictReader(trace.decode().splitlines(), delimiter="\t"))
    if len(rows) != 540:
        raise ValueError("Trace must contain five 36-tick moves for each of three roles")
    capture = {}
    for row in rows:
        if row["animation"] != "run" or row["leg"] not in ("0", "1"):
            continue
        quarter = int(4 * (int(row["frame"]) + float(row["progress"])) / 6)
        view = "front" if row["leg"] == "0" else "back"
        capture.setdefault((row["hero"], view, quarter), row)

    output.mkdir(exist_ok=True)
    (output / "physics.tsv").write_bytes(trace)
    names = {"knight": "騎士", "mage": "法師", "archer": "弓手"}
    headers = ["向下　舊版", "向下　新版", "向上　舊版", "向上　新版"]
    font = ImageFont.truetype(str(ROOT / "assets/fonts/StorySans.otf"), 20)
    frames, comparisons, pairs = [], [], []
    for beat in range(4):
        board = Image.new("RGB", (762, 600), "#262e30")
        labels = ImageDraw.Draw(board)
        for col, header in enumerate(headers):
            labels.text((146 + 174 * col, 19), header, fill="#f2d68d", font=font, anchor="mm")
        for role_no, (role, title) in enumerate(names.items()):
            y = 42 + 184 * role_no
            labels.text((26, y + 85), title, fill="#f1ead7", font=font, anchor="mm")
            for view_no, view in enumerate(("front", "back")):
                record = capture[(role, view, beat)]
                px, py = round(2 * float(record["x"])), round(2 * float(record["y"]))
                crop = (px - 42, py - 34, px + 42, py + 54)
                filename = f"{role}-{view}-{beat}.png"
                pair = {"frame": filename, "physics_leg_tick": int(record["tick"]), "screen_crop": crop}
                pixels = []
                for version, folder in enumerate((baseline, candidate)):
                    file = folder / filename
                    with Image.open(file) as im:
                        if im.size != (360, 640) or im.getchannel("A").getextrema() != (255, 255):
                            raise ValueError(f"Unexpected size or transparency in {file}")
                        rgb = im.convert("RGB")
                    pair[("base", "candidate")[version]] = {
                        "webp_frame": len(frames), "png_sha256": sha(file.read_bytes()),
                        "rgb_sha256": sha(rgb.tobytes())}
                    frames.append(rgb)
                    pixels.append(rgb)
                    tile = rgb.crop(crop).resize((168, 176), Image.Resampling.NEAREST)
                    board.paste(tile, (60 + 174 * (view_no * 2 + version), y))
                red, green, blue = ImageChops.difference(*pixels).split()
                mask = ImageChops.lighter(ImageChops.lighter(red, green), blue).point(lambda val: 255 if val else 0)
                total = mask.histogram()[255]
                mask.paste(0, crop)
                pair["different_pixels"] = total
                pair["outside_crop"] = mask.histogram()[255]
                pair["outside_crop_bbox"] = mask.getbbox()
                pairs.append(pair)
        comparisons.append(board)
    # Lossless WebP can retain a shared background and encode the moving pixels once per frame.
    archive = output / "native-pairs.webp"
    frames[0].save(archive, save_all=True, append_images=frames[1:], lossless=True,
                   minimize_size=True, method=5, duration=150, loop=0)
    with Image.open(archive) as checks:
        if checks.n_frames != len(frames):
            raise ValueError("The native archive did not retain every view")
        for index, raw in enumerate(frames):
            checks.seek(index)
            if checks.convert("RGB").tobytes() != raw.tobytes():
                raise ValueError(f"WebP archive altered native pixels at {index}")
    preview = output / "native-crops.webp"
    comparisons[0].save(preview, save_all=True, append_images=comparisons[1:],
                        lossless=True, method=5, duration=[107, 107, 107, 108], loop=0)
    summary = {"base_commit": "d2e9b2b3443cbe1ff1ca3d45f597fe3cdcd5ff98",
               "native_size": [360, 640], "trace_sha256": sha(trace), "ticks": len(rows),
               "native_pairs": len(pairs), "archive_sha256": sha(archive.read_bytes()),
               "crop_loop_sha256": sha(preview.read_bytes()), "pairs": pairs}
    (output / "native-checks.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Verified {len(pairs)} full frame pairs and {len(rows)} identical native physics records.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/validation/playfeel/direction")
    args = parser.parse_args()
    compare(args.baseline, args.candidate, args.output)
