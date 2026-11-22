"""Pack the six authored images using Pillow to measure alpha and ImageMagick to resample RGBA."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/validation/hero-motion"
TARGET = ROOT / "assets/illustrated/motion"
# Hip X and sole Y in the full-size source. The raised running pose stays airborne.
PIVOTS = {
    "knight": [(204,369),(615,369),(1039,368),(203,784),(629,745),(1032,786),(160,1196),(623,1196),(1033,1196)],
    "mage": [(205,386),(588,382),(1026,384),(182,782),(603,737),(1018,785),(171,1207),(587,1208),(1043,1209)],
    "archer": [(203,382),(597,382),(1016,382),(199,780),(602,754),(997,781),(179,1198),(601,1198),(1027,1197)],
    "reactions": [(200,383),(598,383),(1030,370),(213,801),(607,801),(1040,773),(203,1218),(599,1218),(1036,1205)],
}
SCALE = {"knight": 151/314, "mage": 151/346, "archer": 151/338}
REACTION_SCALE = [151/339, 151/356, 151/358]
PNG = ["-strip", "-define", "png:exclude-chunk=all", "-define", "png:compression-level=9"]


def magick(*args):
    subprocess.run(["magick", *map(str, args)], check=True)


def pack(name, source, temp, out):
    with Image.open(source) as image:
        alpha = image.getchannel("A")
    width, height = alpha.size
    actor = name in PIVOTS
    cols = 4 if name == "effects" else 3
    cw, ch = (256,192) if actor else ((128,128) if name == "effects" else (160,160))
    strips = []
    for row in range(3):
        cuts = [round(i * width / cols) for i in range(cols + 1)]
        if name == "knight" and row == 2:
            cuts[1] = 445  # Gap after the extended blade.
        top, bottom = round(row*height/3), round((row+1)*height/3)
        pieces = []
        for col in range(cols):
            left, right = cuts[col:col+2]
            mask = alpha.crop((left,top,right,bottom)).point(lambda a: 255 if a >= 12 else 0)
            x0,y0,x1,y1 = mask.getbbox()
            x0,y0 = max(left,left+x0-3), max(top,top+y0-3)
            x1,y1 = min(right,left+x1+3), min(bottom,top+y1+3)
            index = row*cols+col
            if actor:
                scale = REACTION_SCALE[row] if name == "reactions" else SCALE[name]
                px,py = PIVOTS[name][index]
                dx = round(120+(x0-px)*scale)
                sole = 160 if name != "reactions" and index == 4 else 176
                dy = round(sole+(y0-py)*scale)
            else:
                scale = min((cw-8)/(right-left), (ch-8)/(bottom-top))
                dx,dy = round(4+(x0-left)*scale), round(4+(y0-top)*scale)
            sw,sh = round((x1-x0)*scale), round((y1-y0)*scale)
            if not (dx >= 1 and dy >= 1 and dx+sw < cw and dy+sh < ch):
                raise ValueError(f"{name} pose {index} would clip")
            piece = temp / f"{name}-{index}.png"
            magick("-size", f"{cw}x{ch}", "xc:none", "(", source, "-crop",
                   f"{x1-x0}x{y1-y0}+{x0}+{y0}", "+repage", "-filter", "Lanczos",
                   "-resize", f"{sw}x{sh}!", ")", "-geometry", f"+{dx}+{dy}",
                   "-composite", *PNG, "PNG32:"+str(piece))
            pieces.append(piece)
        strip = temp / f"{name}-row-{row}.png"
        magick(*pieces, "+append", *PNG, "PNG32:"+str(strip))
        strips.append(strip)
    magick(*strips, "-append", *PNG, "PNG32:"+str(out))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("masters", type=Path, nargs="?", default=EVIDENCE/"source")
    masters = parser.parse_args().masters
    sheets = json.loads((EVIDENCE/"art.json").read_text())["sheets"]
    TARGET.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=TARGET.parent) as staging:
        temp = Path(staging)
        for record in sheets:
            name = record["sheet"]
            source = masters / (name+".png")
            if hashlib.sha256(source.read_bytes()).hexdigest() != record["source"]["sha256"]:
                raise ValueError(f"Original image differs for {name}")
            out = temp / (name+".png")
            pack(name, source, temp, out)
            if hashlib.sha256(out.read_bytes()).hexdigest() != record["runtime"]["sha256"]:
                raise ValueError(f"Packed pixels or PNG encoding differ for {name}")
        for record in sheets:
            filename = record["sheet"]+".png"
            (temp/filename).replace(TARGET/filename)
