"""Pack the GPT Image action sheet using the midpoint between the painted boots."""
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/validation/scarecrow-swing-art/source.png"
TARGET = ROOT / "assets/illustrated/motion/scarecrow_swing.png"
SOLES = (
    ((153, 322), (507, 322), (848, 322), (1214, 321)),
    ((162, 681), (503, 681), (866, 681), (1227, 674)),
    ((167, 1048), (506, 1044), (850, 1050), (1223, 1048)),
)
SCALE = 0.53


def magick(*args):
    subprocess.run(["magick", *map(str, args)], check=True)


def pack():
    with Image.open(SOURCE) as source:
        assert source.mode == "RGBA" and source.size == (1448, 1086)
        mask = source.getchannel("A").point(lambda a: 255 if a >= 32 else 0)
    with TemporaryDirectory() as tmp:
        rows = []
        for row, pivots in enumerate(SOLES):
            frames = []
            for column, (px, py) in enumerate(pivots):
                left, top = column * 362, row * 362
                x0, y0, x1, y1 = mask.crop((left, top, left + 362, top + 362)).getbbox()
                x0, y0, x1, y1 = left + x0 - 2, top + y0 - 2, left + x1 + 2, top + y1 + 2
                width, height = round((x1 - x0) * SCALE), round((y1 - y0) * SCALE)
                # Leave space for the side-view fork, keep forward/rear torsos central.
                dx = round((76 if row == 0 else 96) + (x0 - px) * SCALE)
                dy = round(176 + (y0 - py) * SCALE)
                if min(dx, dy, 192 - dx - width, 192 - dy - height) < 0:
                    raise ValueError(f"Clipped pose {row}/{column}")
                frame = Path(tmp) / f"{row}-{column}.png"
                magick("-size", "192x192", "xc:none", "(", SOURCE, "-crop",
                       f"{x1-x0}x{y1-y0}+{x0}+{y0}", "+repage", "-channel", "A",
                       "-level", "3%,98%", "+channel", "-resize", f"{width}x{height}!",
                       ")", "-geometry", f"+{dx}+{dy}", "-composite", frame)
                frames.append(frame)
            strip = Path(tmp) / f"row-{row}.png"
            magick(*frames, "+append", "+repage", strip)
            rows.append(strip)
        magick(*rows, "-append", "+repage", "-strip", "-define", "png:exclude-chunk=all",
               "-define", "png:compression-level=9", "PNG32:" + str(TARGET))


if __name__ == "__main__":
    pack()
