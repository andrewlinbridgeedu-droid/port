"""Slice a generated sprite sheet (or a folder of single frames) into a Unity flipbook atlas
and check that the frames really change shape frame to frame.

usage:
  python3 -I pack_sheet.py <sheet.png> <cols> <rows> <out_dir> [--cell 512] [--nudge] [--black]
  python3 -I pack_sheet.py <frames_dir>  0      0     <out_dir> [--cell 512] [--nudge] [--black]

Writes <out_dir>/f00.png ... (square, transparent, one per frame, for preview.py),
<out_dir>/atlas.png (2048x2048, 4x4 cells of <cell> px, row-major, unused cells empty) and
<out_dir>/check.jpg (frames side by side with coverage / IoU / centroid drift), plus
<out_dir>/check.json. --nudge re-centres every frame on its alpha centroid (only for
sequences whose body is meant to stay put); --black treats a black background as light
(alpha = brightest channel, colour un-premultiplied), like paint_atlas.py.

Pass criteria printed at the end (from the 2026-10-08 review): adjacent-frame IoU < 0.6
for most pairs (the silhouette really changes), centroid drift <= 5% of the cell between
adjacent frames unless the motion is intended, last frame nearly empty.
"""
import sys, site; sys.path.append(site.getusersitepackages())
import glob, json, os
from PIL import Image, ImageChops, ImageDraw, ImageFont

args = [a for a in sys.argv[1:] if not a.startswith("--")]
flags = [a for a in sys.argv[1:] if a.startswith("--")]
src, cols, rows, out = args[0], int(args[1]), int(args[2]), args[3]
CELL = int(flags[flags.index("--cell") + 1]) if "--cell" in flags else 512
NUDGE = "--nudge" in flags
BLACK = "--black" in flags
os.makedirs(out, exist_ok=True)


def as_light(im):
    rgb = im.convert("RGB"); r, g, b = rgb.split()
    m = ImageChops.lighter(ImageChops.lighter(r, g), b).point(lambda v: 0 if v < 10 else v)
    mv = m.tobytes()
    def unmul(c):
        cv = c.tobytes()
        return Image.frombytes("L", c.size, bytes(min(255, (x * 255) // y) if y else 0 for x, y in zip(cv, mv)))
    return Image.merge("RGBA", (unmul(r), unmul(g), unmul(b), m))


def load_frames():
    if os.path.isdir(src):
        paths = sorted(glob.glob(os.path.join(src, "*.png")))
        ims = [Image.open(p) for p in paths]
    else:
        sheet = Image.open(src)
        w, h = sheet.size[0] / cols, sheet.size[1] / rows
        ims = [sheet.crop((int(c * w), int(r * h), int((c + 1) * w), int((r + 1) * h))) for r in range(rows) for c in range(cols)]
    return [as_light(im) if BLACK else im.convert("RGBA") for im in ims]


def mask(im, thr=24):
    return im.getchannel("A").point(lambda v: 255 if v > thr else 0)


def centroid(m):
    w, h = m.size; data = m.tobytes(); n = sx = sy = 0
    for y in range(h):
        row = data[y * w:(y + 1) * w]
        c = row.count(b"\xff"[0])
        if c: n += c; sy += c * y; sx += sum(i for i, v in enumerate(row) if v)
    return (sx / n, sy / n, n / (w * h)) if n else (w / 2, h / 2, 0.0)


frames = load_frames()
# One square box for the whole sequence: the union of all content bounding boxes, padded,
# so nothing is cut at a cell edge and every frame keeps the same scale and origin.
union = None
for im in frames:
    bb = mask(im).getbbox()
    if bb: union = bb if union is None else (min(union[0], bb[0]), min(union[1], bb[1]), max(union[2], bb[2]), max(union[3], bb[3]))
if union is None: sys.exit("no opaque pixels in any frame")
W, H = frames[0].size
cx, cy = (union[0] + union[2]) / 2, (union[1] + union[3]) / 2
side = max(union[2] - union[0], union[3] - union[1]) * 1.08
box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))

report = []; squares = []
for i, im in enumerate(frames):
    sq = Image.new("RGBA", (int(side), int(side)), (0, 0, 0, 0))
    sq.paste(im, (-box[0], -box[1]))
    sq = sq.resize((CELL, CELL), Image.LANCZOS)
    m = mask(sq); x, y, cov = centroid(m)
    if NUDGE and cov > 0:
        sq = ImageChops.offset(sq, int(CELL / 2 - x), int(CELL / 2 - y)); m = mask(sq); x, y, cov = centroid(m)
    squares.append(sq)
    sq.save(os.path.join(out, f"f{i:02d}.png"))
    report.append({"frame": i, "coverage": round(cov, 4), "cx": round(x / CELL, 3), "cy": round(y / CELL, 3)})

for i in range(1, len(squares)):
    a, b = mask(squares[i - 1]), mask(squares[i])
    inter = ImageChops.multiply(a, b).tobytes().count(255); uni = ImageChops.lighter(a, b).tobytes().count(255)
    report[i]["iou"] = round(inter / uni, 3) if uni else 0.0
    report[i]["drift"] = round(max(abs(report[i]["cx"] - report[i - 1]["cx"]), abs(report[i]["cy"] - report[i - 1]["cy"])), 3)

atlas = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
for i, sq in enumerate(squares[:16]): atlas.paste(sq, ((i % 4) * CELL, (i // 4) * CELL))
atlas.save(os.path.join(out, "atlas.png"))

f = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 16)
cw = 200; sheet = Image.new("RGB", (cw * min(len(squares), 6), (cw + 40) * ((len(squares) + 5) // 6)), (60, 60, 64))
d = ImageDraw.Draw(sheet)
for i, sq in enumerate(squares):
    x0, y0 = (i % 6) * cw, (i // 6) * (cw + 40)
    sheet.paste(sq.resize((cw, cw)), (x0, y0), sq.resize((cw, cw)))
    r = report[i]; d.text((x0 + 4, y0 + cw + 2), f"#{i} cov {r['coverage']:.3f}", fill=(255, 255, 0), font=f)
    if i: d.text((x0 + 4, y0 + cw + 20), f"IoU {r['iou']:.2f} drift {r['drift']:.3f}", fill=(255, 255, 255) if r["iou"] < .6 else (255, 90, 90), font=f)
sheet.save(os.path.join(out, "check.jpg"), quality=85)
json.dump({"box": box, "cell": CELL, "frames": report}, open(os.path.join(out, "check.json"), "w"), indent=1)

ious = [r["iou"] for r in report[1:]]
print(f"{len(frames)} frames, box {box}, cell {CELL}")
print("IoU per adjacent pair:", ious)
print("frames with IoU >= 0.6 (silhouette barely changed):", [r["frame"] for r in report[1:] if r["iou"] >= .6])
print("drift > 5% of cell:", [r["frame"] for r in report[1:] if r["drift"] > .05])
print("last frame coverage:", report[-1]["coverage"], "(should be near 0)")
