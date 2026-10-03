"""Four-point star glints for the SpellSpectacle20260926 particle atlas.

The reference battles (docs/reference-analysis/fotang-spells-20261002) sprinkle
white four-point glints over the caster and along a spell's course. The atlas
stars have five or six uneven rays; these two cells add the four-point glint:

  Glint   (Mote 8): x 0..256,   y 1536..1792  concave four-point body, long
                    vertical and shorter horizontal rays, hot core.
  Twinkle (Mote 9): x 256..512, y 1536..1792  the same tilted 15 degrees with
                    four faint diagonal rays between the main ones.

y is measured from the image top, matching SpellSpectacle20260926.MoteCell.
Pure PIL (no numpy), so it can patch the committed atlas in place:

  python3 glints.py <SpectacleAtlas.png>

make_textures.atlas() pastes the same cells when the whole atlas is rebuilt.
"""
import math
import sys

from PIL import Image

CELL = 256
ORIGINS = [(0, 1536), (256, 1536)]


def _ray(along, across, length, width):
    """A thin ray along one axis that tapers to nothing at 'length'."""
    if abs(along) >= length:
        return 0.0
    taper = 1 - abs(along) / length
    w = width * (0.25 + taper)
    return math.exp(-((across / w) ** 2)) * taper ** 1.25


def glint_alpha(x, y, variant):
    """Coverage at pixel centre (x, y) of a cell, in [0, 1]."""
    cx = cy = (CELL - 1) / 2
    dx, dy = (x - cx) / (CELL / 2), (y - cy) / (CELL / 2)
    if variant == 1:
        a = math.radians(15)
        dx, dy = dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a)
    r = math.hypot(dx, dy)
    # Concave four-point body (astroid): |x|^(2/3) + |y|^(2/3) <= size^(2/3).
    q = (abs(dx) ** (2 / 3) + abs(dy) ** (2 / 3)) ** 1.5
    size = 0.5 if variant == 0 else 0.4
    body = max(0.0, 1 - q / size) ** 1.4
    long_ray, short_ray = (0.97, 0.78) if variant == 0 else (0.9, 0.7)
    rays = max(_ray(dy, dx, long_ray, 0.022), _ray(dx, dy, short_ray, 0.02))
    if variant == 1:
        # Faint diagonals between the main rays.
        u, v = (dx + dy) / math.sqrt(2), (dx - dy) / math.sqrt(2)
        rays = max(rays, 0.45 * _ray(u, v, 0.36, 0.016), 0.45 * _ray(v, u, 0.36, 0.016))
    core = math.exp(-((r / 0.06) ** 2))
    halo = 0.3 * math.exp(-((r / 0.22) ** 2))
    return min(1.0, max(body, rays) + core + halo)


def glint_cell(variant):
    cell = Image.new("L", (CELL, CELL), 0)
    px = cell.load()
    for y in range(CELL):
        for x in range(CELL):
            px[x, y] = int(glint_alpha(x, y, variant) * 255 + 0.5)
    return cell


def paste_glints(sheet):
    """Write both glint cells into an RGBA atlas image (white, alpha = coverage)."""
    for variant, (ox, oy) in enumerate(ORIGINS):
        alpha = glint_cell(variant)
        white = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
        white.putalpha(alpha)
        sheet.paste(white, (ox, oy))
    return sheet


if __name__ == "__main__":
    path = sys.argv[1]
    sheet = Image.open(path).convert("RGBA")
    for ox, oy in ORIGINS:
        region = sheet.crop((ox, oy, ox + CELL, oy + CELL)).split()[3]
        if region.getbbox() is not None:
            sys.exit(f"cell at {ox},{oy} is not empty; refusing to overwrite")
    paste_glints(sheet).save(path)
    print("ok", path)
