"""Composite flipbook frames onto a battle still and lay them out for review.

usage: python3 preview.py <frames_dir> <still.png> <out.jpg> [cx cy width]
Defaults put the impact on the hero's chest in the 1320x2868 Q3 still at about
1.5x the hero's on-screen height. Also writes <out>_dark.jpg on a dark grey ground.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

fd, still, out = sys.argv[1], sys.argv[2], sys.argv[3]
cx, cy, width = (int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])) if len(sys.argv) > 6 else (650, 1730, 820)
frames = [Image.open(p).convert("RGBA") for p in sorted(glob.glob(os.path.join(fd, "f*.png")))]
bg = Image.open(still).convert("RGBA")
box = (cx - 520, cy - 700, cx + 520, cy + 560)


def lay(ground, name, cell_w=300):
    cells = []
    for i, fr in enumerate(frames):
        g = ground.copy()
        fx = fr.resize((width, width), Image.LANCZOS)
        g.alpha_composite(fx, (cx - width // 2, cy - width // 2))
        c = g.crop(box).convert("RGB")
        c = c.resize((cell_w, int(cell_w * c.height / c.width)))
        ImageDraw.Draw(c).text((6, 6), f"{i}", fill=(255, 255, 0))
        cells.append(c)
    cols = 7
    w, h = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    s = Image.new("RGB", (w * cols, h * rows))
    for i, c in enumerate(cells):
        s.paste(c, ((i % cols) * w, (i // cols) * h))
    s.save(name, quality=85)


lay(bg, out)
dark = Image.new("RGBA", bg.size, (46, 48, 54, 255))
lay(dark, out.replace(".jpg", "_dark.jpg"))
print("ok", len(frames))
