"""Rebuild the project's OFL story fonts from Noto CJK Traditional Chinese."""
import argparse
import csv
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTCollection, TTFont

ROOT = Path(__file__).resolve().parents[1]
NOTO = Path("/usr/share/fonts/opentype/noto")


def localized_ideographs(project):
    points = set()
    for source in (project / "i18n").glob("*.csv"):
        with source.open(encoding="utf-8-sig", newline="") as stream:
            for row in csv.reader(stream):
                for field in row[1:]:
                    points.update(ord(char) for char in field if 0x3400 <= ord(char) <= 0x9fff)
    return points


def rebuild(project, requested, translated_only):
    for family in ("Sans", "Serif"):
        destination = project / "assets/fonts" / f"Story{family}.otf"
        with TTFont(destination) as current:
            original = set(current.getBestCmap())
        missing = requested - original
        if translated_only and not missing:
            continue
        collection_path = NOTO / f"Noto{family}CJK-Regular.ttc"
        if not collection_path.is_file():
            raise SystemExit(f"Install fonts-noto-cjk to supply {collection_path}")
        with TTCollection(collection_path, lazy=True) as collection:
            family_name = f"Noto {family} CJK TC"
            font = next(face for face in collection.fonts if face["name"].getDebugName(1) == family_name)
            options = subset.Options()
            options.name_IDs = ["*"]
            options.name_legacy = True
            options.name_languages = ["*"]
            selection = subset.Subsetter(options=options)
            selection.populate(unicodes=original | requested)
            selection.subset(font)
            if translated_only and not (original | requested) <= set(font.getBestCmap()):
                raise ValueError(f"Incomplete Traditional Chinese coverage for {destination.name}")
            font.save(destination)
            print(f"{destination.name}: {len(font.getBestCmap())} code points"
                  + (f", added {''.join(map(chr, sorted(missing)))}" if translated_only else ""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-project", type=Path, help="extend only the staged browser fonts for translated Chinese")
    args = parser.parse_args()
    if args.web_project:
        rebuild(args.web_project, localized_ideographs(args.web_project), translated_only=True)
        return
    text = "".join(path.read_text(errors="ignore") for pattern in ("*.gd", "*.csv", "*.tres")
                   for path in ROOT.rglob(pattern) if ".godot" not in path.parts)
    rebuild(ROOT, set(map(ord, text)), translated_only=False)


if __name__ == "__main__":
    main()
