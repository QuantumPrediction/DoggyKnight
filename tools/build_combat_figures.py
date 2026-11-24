"""Build the original, compact wedge-serif figures used for combat feedback.

The outlines are drawn in a 56 × 76 design grid (x right, y down).
Godot loads only the checked-in font. Rebuild with Python and fontTools.
"""

from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path

DEST = Path(__file__).resolve().parents[1] / "assets/fonts/QuillFigures.ttf"

# Advance widths and closed pen outlines. Reversed inner contours form the counters.
FIGURES = {
    "0": (55, """
        M30 0 Q49 0 51 26 Q54 51 42 68 Q36 77 24 77 Q5 77 3 52 Q0 28 13 10 Q20 0 30 0 Z
        M29 11 Q21 11 16 33 Q12 52 17 62 Q19 66 24 66 Q34 66 38 44 Q42 21 36 14 Q33 11 29 11 Z
    """),
    "1": (39, """
        M5 18 Q15 13 23 3 L31 1 L26 64 L36 69 L35 75 L2 75 L3 69 L12 65 L17 22 L8 26 Z
    """),
    "2": (52, """
        M5 19 Q11 1 29 1 Q46 1 49 15 Q52 30 40 42 Q33 50 16 62
        L36 62 Q42 62 46 55 L50 57 L46 75 L1 75 L2 66 Q16 51 29 38
        Q39 28 36 20 Q34 13 27 13 Q18 13 11 25 Z
    """),
    "3": (51, """
        M5 14 Q17 0 31 1 Q46 2 47 17 Q48 29 34 37 Q49 40 48 54 Q47 69 33 75
        Q16 82 2 69 L6 58 Q18 69 27 64 Q35 61 35 53 Q35 44 20 44 L17 44 L19 35
        Q35 28 34 20 Q34 13 26 13 Q17 13 9 21 Z
    """),
    "4": (57, """
        M33 1 L49 1 L43 49 L53 49 L52 60 L42 60 L41 66 L47 70 L46 75 L20 75
        L21 69 L28 65 L29 60 L1 60 L2 50 Z
        M11 49 L30 49 L34 18 Z
    """),
    "5": (51, """
        M11 2 L49 2 L45 15 L20 15 L17 31 Q23 28 30 29 Q48 31 48 50 Q48 68 33 75
        Q15 82 2 69 L5 58 Q18 69 28 64 Q36 60 35 51 Q34 41 24 41 Q16 40 9 45 L4 42 Z
    """),
    "6": (53, """
        M43 2 L45 10 Q23 18 17 35 Q26 29 34 31 Q50 32 50 50 Q50 70 35 75
        Q18 81 8 70 Q-2 58 5 36 Q14 8 43 2 Z
        M26 42 Q20 42 15 47 Q12 61 20 65 Q31 71 37 56 Q41 43 31 42 Z
    """),
    "7": (51, """
        M5 2 L50 2 L49 11 Q32 36 24 71 L10 77 Q16 44 34 16 L17 16 Q10 16 5 23 L1 21 Z
    """),
    "8": (53, """
        M29 0 Q47 0 49 15 Q50 27 38 36 Q51 43 50 55 Q49 75 27 77
        Q5 79 3 61 Q1 47 15 38 Q4 31 6 20 Q9 1 29 0 Z
        M29 11 Q21 11 19 19 Q18 26 29 32 Q37 26 37 19 Q37 11 29 11 Z
        M24 44 Q16 51 16 58 Q17 67 26 66 Q35 66 37 57 Q38 50 25 44 Z
    """),
    "9": (54, """
        M30 0 Q49 0 51 22 Q54 44 40 61 Q28 75 9 78 L8 69 Q28 59 35 44
        Q26 48 19 46 Q2 44 3 27 Q4 7 21 2 Q26 0 30 0 Z
        M29 11 Q20 11 17 22 Q12 35 23 36 Q30 38 38 31 Q41 12 29 11 Z
    """),
    "!": (24, """
        M10 3 L23 0 L16 51 L7 54 Z
        M12 59 L20 67 L10 77 L2 69 Z
    """),
    "−": (40, "M3 35 L38 32 L36 42 L1 44 Z"),
    "✦": (34, "M17 14 Q20 31 33 38 Q20 43 16 62 Q13 44 1 39 Q13 33 17 14 Z"),
}
NAMES = dict(zip("0123456789!−✦", ("zero", "one", "two", "three", "four", "five",
                                  "six", "seven", "eight", "nine", "exclam", "minus", "star")))


def main():
    font = FontBuilder(1000, isTTF=True)
    glyphs = {".notdef": TTGlyphPen(None).glyph(), "space": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (360, 0), "space": (180, 0)}
    mapping = {32: "space"}
    for char, (width, outline) in FIGURES.items():
        name = NAMES[char]
        pen = TTGlyphPen(None)
        transformed = TransformPen(pen, (10, 0, 0, -10, 10, 760))
        parse_path(outline, transformed)
        glyph = pen.glyph()
        glyph.recalcBounds(None)
        glyphs[name] = glyph
        metrics[name] = (width * 10 + 20, glyph.xMin)
        mapping[ord(char)] = name
    font.setupGlyphOrder(list(glyphs))
    font.setupCharacterMap(mapping)
    font.setupGlyf(glyphs)
    font.setupHorizontalMetrics(metrics)
    font.setupHorizontalHeader(ascent=800, descent=-200, lineGap=0)
    font.setupNameTable({"familyName": "Golden Knight Quill", "styleName": "Regular",
                         "psName": "GoldenKnightQuill-Regular", "fullName": "Golden Knight Quill Regular",
                         "uniqueFontIdentifier": "DoggyKnight-Quill-1.0", "version": "Version 1.0"})
    font.setupOS2(sTypoAscender=800, sTypoDescender=-200, sTypoLineGap=0,
                  usWinAscent=800, usWinDescent=200, sCapHeight=760, usWeightClass=650)
    font.setupPost()
    font.font.recalcTimestamp = False
    font.font["head"].created = font.font["head"].modified = 3867782400
    font.save(DEST)


if __name__ == "__main__":
    main()
