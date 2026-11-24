"""Compare paired 360×640 Godot captures at their original playback speed."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {"knight": "騎士", "mage": "法師", "archer": "弓手"}
TICKS = range(25, 51)
CROP = (50, 265, 208, 339)
SCALE = 2


def digest(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def load_frame(directory, role, tick):
    path = directory / "frames" / f"{role}-{tick:02}.png"
    with Image.open(path) as image:
        if image.size != (360, 640):
            raise ValueError(f"Expected full 360×640 viewport at {path}")
        return image.convert("RGB"), digest(path)


def outside_comparison(before, after):
    r, g, b = ImageChops.difference(before, after).split()
    mask = ImageChops.lighter(r, ImageChops.lighter(g, b)).point(lambda v: 255 if v else 0)
    mask.paste(0, CROP)
    return {"count": mask.histogram()[255], "box": mask.getbbox()}


def distinct_paintings(directory, role):
    # The same Godot run also samples the live skin's selected drawing every four
    # ticks. Trim its transparent margin to discount the character's screen offset.
    drawings = set()
    for tick in range(16, 77, 4):
        with Image.open(directory / "data" / f"{role}-{tick // 4:02}.png") as painted:
            region = painted.crop(painted.getchannel("A").getbbox())
            drawings.add(hashlib.sha256(region.tobytes()).hexdigest())
    return sorted(drawings)


def make_preview(before, after, output):
    before_events, after_events = (digest(src / "data" / "events.tsv") for src in (before, after))
    if before_events != after_events:
        raise ValueError("Event tracks differ")
    output.mkdir(parents=True, exist_ok=True)
    thumb = ((CROP[2] - CROP[0]) * SCALE, (CROP[3] - CROP[1]) * SCALE)
    columns = (67, 67 + thumb[0] + 10)
    top = 49
    row_step = thumb[1] + 7
    page = Image.new("RGB", (columns[1] + thumb[0] + 12, top + row_step * 3 + 29), "#182320")
    ink = ImageDraw.Draw(page)
    serif = ImageFont.truetype(str(ROOT / "assets/fonts/StorySerif.otf"), 20)
    sans = ImageFont.truetype(str(ROOT / "assets/fonts/StorySans.otf"), 15)
    for x, heading in zip(columns, ("原版 · 4 格跑姿", "新版 · 8 格跑姿")):
        ink.text((x, 23), heading, font=serif, fill="#f8e5b8", anchor="lm")
    for row, title in enumerate(CLASSES.values()):
        ink.text((13, top + row * row_step + thumb[1] // 2), title, font=serif, fill="#f8e5b8", anchor="lm")
    ink.text((columns[0], page.height - 17), "Linux 遊戲畫面局部 2×  ·  同一場地與輸入  ·  60 Hz 原速重播", font=sans, fill="#d0d3bf", anchor="lm")

    record = {"viewport": [360, 640], "crop_left_top_right_bottom": CROP, "nearest_scale": SCALE,
              "rate_hz": 60, "tick_start": TICKS.start, "tick_end_inclusive": TICKS.stop - 1,
              "event_track_sha256": before_events, "frames": {role: [] for role in CLASSES},
              "live_drawing_hashes_ticks_16_to_76_every_4": {}}
    for role in CLASSES:
        hashes = {label: distinct_paintings(path, role) for label, path in (("base", before), ("candidate", after))}
        if (len(hashes["base"]), len(hashes["candidate"])) != (4, 8):
            raise ValueError(f"{role}: the capture did not exhibit all four/eight running poses")
        record["live_drawing_hashes_ticks_16_to_76_every_4"][role] = hashes
    pages = []
    for tick in TICKS:
        frame = page.copy()
        for row, role in enumerate(CLASSES):
            (old, old_sha), (new, new_sha) = (load_frame(src, role, tick) for src in (before, after))
            record["frames"][role].append({"tick": tick, "base_png": old_sha, "candidate_png": new_sha,
                                           "changed_pixels_outside_crop": outside_comparison(old, new)})
            for x, screenshot in zip(columns, (old, new)):
                enlarged = screenshot.crop(CROP).resize(thumb, Image.Resampling.NEAREST)
                frame.paste(enlarged, (x, top + row * row_step))
        pages.append(frame)

    path = output / "stride-preview.webp"
    durations = [round((i + 1) * 1000 / 60) - round(i * 1000 / 60) for i in range(len(pages))]
    pages[0].save(path, save_all=True, append_images=pages[1:], duration=durations, loop=0, lossless=True, method=6)
    record["preview_sha256"] = digest(path)
    with Image.open(path) as playback:
        if playback.n_frames != len(pages):
            raise ValueError(f"Expected {len(pages)} frames, encoded {playback.n_frames}")
        for i, expected in enumerate(pages):
            playback.seek(i)
            if ImageChops.difference(playback.convert("RGB"), expected).getbbox():
                raise ValueError(f"Preview frame {i} differs from source crops and labels")
    (output / "stride-native.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    make_preview(args.before, args.after, args.output)
