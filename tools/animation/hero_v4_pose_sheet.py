"""Pose review sheet: tiles the frames written by
`build_hero_v4.py --pose-frames CLIP,... --pose-dir DIR` into one PNG per clip,
one row per view (game, rear, side, front) and one column per phase.

    python3 tools/animation/hero_v4_pose_sheet.py DIR CLIP OUT.png [views]
"""
import sys, glob, os
from PIL import Image, ImageDraw
d, clip, out = sys.argv[1], sys.argv[2], sys.argv[3]
views = sys.argv[4].split(',') if len(sys.argv) > 4 else ['game', 'rear', 'side', 'front']
phases = sorted({os.path.basename(f).rsplit('-', 1)[1][:3] for f in glob.glob(f'{d}/{clip}-game-*.png')})
s = 0.4; w, h = int(600 * s), int(900 * s)
sheet = Image.new('RGB', (w * len(phases), (h + 18) * len(views)), (30, 30, 30))
dr = ImageDraw.Draw(sheet)
for r, v in enumerate(views):
    for c, ph in enumerate(phases):
        im = Image.open(f'{d}/{clip}-{v}-{ph}.png').convert('RGB').resize((w, h), Image.LANCZOS)
        sheet.paste(im, (c * w, r * (h + 18) + 18))
        dr.text((c * w + 4, r * (h + 18) + 3), f'{clip} {v} p={int(ph)/100:.2f}', fill=(255, 220, 120))
sheet.save(out); print(out, sheet.size)
