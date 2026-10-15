"""Pack the oil-leech loop rendered by blender_leech.py into the runtime flipbook
Resources/EnemyFlipbook/OilLeech.png (+ .json) for OilLeechBody20261012 (2026-10-12).

Frames are 512x256 RGBA; 4 columns x 12 rows = 2048x3072 (48 frames). The json carries the grid,
the playback rate and the camera numbers from leech.json (where the pool's centre on the ground
lands in a frame, pixels per unit there, the pool's radius in units).

usage: <python with PIL> pack_leech.py <frames-dir> <leech.json> <out-dir> [fps]
"""
import glob
import json
import os
import sys

from PIL import Image

src, meta_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
fps = float(sys.argv[4]) if len(sys.argv) > 4 else 16.
COLS = 4
frames = sorted(glob.glob(os.path.join(src, "leech_*.png")))
meta = json.load(open(meta_path))
w, h = Image.open(frames[0]).size
rows = (len(frames) + COLS - 1) // COLS
sheet = Image.new("RGBA", (COLS * w, rows * h), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.paste(Image.open(f).convert("RGBA"), ((i % COLS) * w, (i // COLS) * h))
os.makedirs(out, exist_ok=True)
sheet.save(os.path.join(out, "OilLeech.png"), compress_level=6)
info = {"frames": len(frames), "columns": COLS, "rows": rows, "width": w, "height": h,
        "originPx": meta["originPx"], "pxPerUnit": meta["pxPerUnit"], "poolRadius": meta["poolRadius"], "fps": fps}
with open(os.path.join(out, "OilLeech.json"), "w") as f:
    json.dump(info, f, indent=1)
print("packed", len(frames), "frames", sheet.size, info)
