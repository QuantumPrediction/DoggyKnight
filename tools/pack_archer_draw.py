"""Register the GPT Image archer poses by their boot midpoint, with one scale per view."""
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image

from pack_scarecrow_swing import magick

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/validation/archer-draw-motion"


def pack():
    spec = json.loads((EVIDENCE / "art.json").read_text())
    side = spec["tile_px"]
    with TemporaryDirectory() as tmp:
        strips = []
        for row in spec["rows"]:
            record = spec["sources"][row["source"]]
            source = EVIDENCE / record["file"]
            assert hashlib.sha256(source.read_bytes()).hexdigest() == record["sha256"]
            with Image.open(source) as original:
                assert list(original.size) == record["size"] and original.mode == "RGBA"
                mask = original.getchannel("A").point(lambda alpha: 255 if alpha >= 32 else 0)
            row_top, row_bottom = row["source_y"]
            frames = []
            for c, (px, py) in enumerate(zip(row["boot_x"], row["boot_y"])):
                left = round(mask.width * c / 4)
                right = round(mask.width * (c + 1) / 4)
                bounds = mask.crop((left, row_top, right, row_bottom)).getbbox()
                x0, y0 = max(left, left + bounds[0] - 2), max(row_top, row_top + bounds[1] - 2)
                x1, y1 = min(right, left + bounds[2] + 2), min(row_bottom, row_top + bounds[3] + 2)
                scale = row["scale"]
                width, height = round((x1 - x0) * scale), round((y1 - y0) * scale)
                dx = round(row["pivot_x"] + (x0 - px) * scale)
                dy = round(spec["sole_y"] + (y0 - py) * scale)
                if min(dx, dy, side - dx - width, side - dy - height) < 0:
                    raise ValueError(f"Pose clipped in {row['view']} column {c}")
                cell = Path(tmp) / f"{row['view']}-{c}.png"
                magick("-size", f"{side}x{side}", "xc:none", "(", source, "-crop",
                       f"{x1-x0}x{y1-y0}+{x0}+{y0}", "+repage", "-channel", "A",
                       "-level", "3%,98%", "+channel", "-resize", f"{width}x{height}!",
                       ")", "-geometry", f"+{dx}+{dy}", "-composite", cell)
                frames.append(cell)
            strip = Path(tmp) / (row["view"] + ".png")
            magick(*frames, "+append", "+repage", strip)
            strips.append(strip)
        magick(*strips, "-append", "+repage", "-strip", "-define", "png:exclude-chunk=all",
               "-define", "png:compression-level=9", "PNG32:" + str(ROOT / spec["target"]))


if __name__ == "__main__":
    pack()
