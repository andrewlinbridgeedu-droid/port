"""Pack the painted spell props (ArtSource/SpellProps20261007, drawn by the user from the
prompts in docs/development/SPELL_PROPS_ART_REQUEST_20261007.md) into SpectaclePaint.png:
2048x2048, a 4x4 grid of 512 px cells, order = CELLS (mirrored by PropCell 100+).

Transparent art keeps its alpha. Black-background light (claw marks, sword qi, fire) is
turned into light with alpha: alpha = brightest channel, colour = colour / alpha, so in the
premultiplied prop shader it adds its light and only slightly darkens what is behind,
instead of drawing a black square. Each cell is trimmed to its content and fitted with a
margin so nothing bleeds into its neighbour.

usage: python3 paint_atlas.py <art-dir> <out.png>
"""
import os
import sys

from PIL import Image, ImageChops

CELLS = [
    ("sword", "alpha"), ("axe", "alpha"), ("hammer", "alpha"), ("chain_link", "alpha"),
    ("coin", "alpha"), ("petal", "alpha"), ("lotus", "alpha"), ("smoke_a", "alpha"),
    ("smoke_b2", "alpha"), ("smoke_c2", "alpha"), ("smoke_b", "alpha"), ("smoke_c", "alpha"),
    ("claw_marks", "light"), ("sword_qi", "light"), ("fire_a2", "light"),
    # Cell 15 was fire_b, never drawn; the boss's copper hand (2026-10-09, copper_hand.png).
    ("copper_hand", "alpha"),
]
# Second sheet SpectaclePaint2.png (2026-10-09, tower demons redone with painted art):
# PaintSprite cells 16+ (cell - 16 here).
CELLS2 = [
    ("rock_burst", "alpha"), ("salt_crystals", "alpha"), ("venom_glob", "alpha"), ("venom_splash", "alpha"),
    ("bone_claws", "alpha"), ("flame_fist", "alpha"), ("copper_horn", "alpha"), ("moon_tornado", "light"),
    ("crimson_veil", "alpha"), ("golden_bubbles", "alpha"),
    ("drowned_bell", "alpha"), ("ghost_wave", "alpha"), ("leather_straps", "alpha"), ("tailor_needles", "alpha"),
    ("crimson_threads", "alpha"), ("violet_ink_splash", "alpha"),
]
# Third sheet SpectaclePaint3.png (bounties): PaintSprite cells 32+.
CELLS3 = [
    ("iron_anchor", "alpha"), ("copper_quill", "alpha"), ("electric_shockwave", "light"), ("mirror_pane", "alpha"),
    ("crystal_rapier", "alpha"), ("flame_claws", "alpha"), ("crimson_wings", "alpha"),
    # 2026-10-10: the hound's hellfire breath and the emerald revenant's ghost fog and toxic burst.
    ("hellfire_breath", "light"), ("emerald_fog", "light"), ("emerald_burst", "light"),
    # Three bubbles cut from the user's emerald_burst painting: 翠毒漫天's floor of poison bubbles.
    ("poison_bubble_a", "light"), ("poison_bubble_b", "light"), ("poison_bubble_c", "light"),
    # 夺名代签 (2026-10-10): the project's painted blank name plate (RelicBlankCard) and gold contract ink.
    ("name_plate", "alpha"), ("gold_ink", "alpha"),
    # 镇钟重砸 (2026-10-10): the user's painted bronze clock-bell.
    ("bronze_bell", "alpha"),
]
CELL = 512
PAD = 10


def as_light(im):
    rgb = im.convert("RGB")
    r, g, b = rgb.split()
    m = ImageChops.lighter(ImageChops.lighter(r, g), b).point(lambda v: 0 if v < 6 else v)
    # colour / brightest channel, per pixel (Image.eval cannot see two bands, so walk the data).
    mv = m.tobytes()
    def unmul(c):
        cv = c.tobytes()
        return Image.frombytes("L", c.size, bytes(min(255, (x * 255) // y) if y else 0 for x, y in zip(cv, mv)))
    return Image.merge("RGBA", (unmul(r), unmul(g), unmul(b), m))


def fit(im):
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox() or (0, 0, im.width, im.height)
    im = im.crop(box)
    s = (CELL - 2 * PAD) / max(im.width, im.height)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.paste(im, ((CELL - im.width) // 2, (CELL - im.height) // 2))
    return cell


def main(src, out, cells=None):
    cells = cells or CELLS
    sheet = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    for i, (name, kind) in enumerate(cells):
        path = os.path.join(src, name + ".png")
        if not os.path.exists(path):
            print("missing", name, "(cell left empty)")
            continue
        im = Image.open(path)
        im = as_light(im) if kind == "light" else im.convert("RGBA")
        sheet.paste(fit(im), ((i % 4) * CELL, (i // 4) * CELL))
        print("packed", i, name)
    sheet.save(out)


if __name__ == "__main__":
    # usage: paint_atlas.py <art-dir> <out.png> [2|3]   (the second / third sheet)
    sheet = sys.argv[3] if len(sys.argv) > 3 else "1"
    main(sys.argv[1], sys.argv[2], {"2": CELLS2, "3": CELLS3}.get(sheet))
