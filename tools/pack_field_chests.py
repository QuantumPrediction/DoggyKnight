"""Register the twelve GPT Image drawings at their feet, preserving lid motion."""
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/validation/field-chests/source.png"
TARGET = ROOT / "assets/illustrated/motion/field_chests.png"
CELL = 128
BASE = 110  # Bottom edge of the previous story_cast drawing, in a 128 px cell.
WIDTHS = (105, 109, 113)
HEIGHT_SCALES = (0.35, 0.35, 0.30)


def magick(*args):
    subprocess.run(["magick", *map(str, args)], check=True)


def pack(source, target):
    with Image.open(source) as original:
        if original.mode != "RGBA" or original.size != (1448, 1086):
            raise ValueError("Expected the 1448×1086 RGBA field-chest source")
        mask = original.getchannel("A").point(lambda value: 255 if value >= 32 else 0)
    with TemporaryDirectory() as directory:
        rows = []
        for row in range(3):
            frames = []
            for column in range(4):
                left, top = column * 362, row * 362
                box = mask.crop((left, top, left + 362, top + 362)).getbbox()
                x0, y0, x1, y1 = box
                width, height = WIDTHS[row], round((y1 - y0) * HEIGHT_SCALES[row])
                # Two extra source pixels preserve the antialiased edge. Remove
                # the nearly transparent background grain outside the painted body.
                crop = f"{x1-x0+4}x{y1-y0+4}+{left+x0-2}+{top+y0-2}"
                frame = Path(directory) / f"{row}-{column}.png"
                magick("-size", f"{CELL}x{CELL}", "xc:none", "(", source, "-crop", crop,
                       "+repage", "-channel", "A", "-level", "3%,98%", "+channel",
                       "-resize", f"{width}x{height}!", ")", "-geometry",
                       f"+{(CELL-width)//2}+{BASE-height}", "-composite", frame)
                frames.append(frame)
            strip = Path(directory) / f"row-{row}.png"
            magick(*frames, "+append", strip)
            rows.append(strip)
        magick(*rows, "-append", "-strip", "-define", "png:exclude-chunk=all",
               "-define", "png:compression-level=9", "PNG32:" + str(target))


if __name__ == "__main__":
    pack(Path(sys.argv[1]) if len(sys.argv) > 1 else SOURCE, TARGET)
