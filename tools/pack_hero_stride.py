"""Register the eight painted poses for each job to the combat actor's existing pivot."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/validation/playfeel/stride-source"
TARGET = ROOT / "assets/illustrated/motion"
TILE = (256, 192)

# One scale per sheet preserves the size of heads and equipment throughout the loop.
# The horizontal anchors are the tip of the muzzle of each source painting, in its
# 384-pixel-wide source cell. The two flight poses retain their own foot clearance.
ROLES = {
    "knight": (0.455, 171, [317, 309, 308, 305, 322, 314, 308, 309], [162, 168]),
    "mage": (0.495, 168, [278, 280, 277, 279, 281, 282, 280, 280], [163, 166]),
    "archer": (0.44, 173, [305, 300, 287, 291, 306, 307, 301, 297], [161, 161]),
}


def pack(role):
    scale, target_muzzle, muzzles, flight_soles = ROLES[role]
    with Image.open(SOURCE / (role + ".webp")) as source:
        source = source.convert("RGBA")
    if source.size != (1536, 1024):
        raise ValueError(f"{role}: unexpected source dimensions {source.size}")
    atlas = Image.new("RGBA", (4 * TILE[0], 2 * TILE[1]))
    for i, muzzle in enumerate(muzzles):
        col, row = i % 4, i // 4
        x, y = col * 384, row * 512
        cell = source.crop((x, y, x + 384, y + 512))
        alpha = cell.getchannel("A")
        left, top, right, bottom = alpha.point(lambda v: 255 if v >= 12 else 0).getbbox()
        sole = alpha.point(lambda v: 255 if v >= 100 else 0).getbbox()[3] - 1
        if left < 4 or top < 4 or right > 380 or bottom > 508:
            raise ValueError(f"{role} frame {i} reaches a source edge")
        bounds = (left - 3, top - 3, right + 3, bottom + 3)
        painting = cell.crop(bounds)
        painting = painting.resize(tuple(round(v * scale) for v in painting.size), Image.Resampling.LANCZOS)
        target_sole = flight_soles[row] if col == 3 else 176
        dx = round(target_muzzle + (0, 1, 2, 1)[col] + (bounds[0] - muzzle) * scale)
        dy = round(target_sole + (bounds[1] - sole) * scale)
        if dx < 0 or dy < 0 or dx + painting.width > TILE[0] or dy + painting.height > TILE[1]:
            raise ValueError(f"{role} frame {i} would clip the drawing")
        atlas.alpha_composite(painting, (col * TILE[0] + dx, row * TILE[1] + dy))
    atlas.save(TARGET / ("stride_" + role + ".png"), optimize=True)


if __name__ == "__main__":
    for hero in ROLES:
        pack(hero)
