"""Cut a 2D cutout-animation part sheet (one character's parts on a flat gray background,
drawn by the user from the FINAL_BOSS_PARTY_20261010 prompts) into separate RGBA parts.
The background is matted like prepare_sevian_video_body.py; parts are the connected
islands (slightly dilated so a hair strand or a tassel stays with its part). Writes
<out>/<index>.png per part (cropped, 6 px margin), <out>/parts.json with each part's box
in the sheet, and <out>/index.jpg, a labelled contact sheet to name them by.

usage: <media-venv>/bin/python tools/animation/cut_parts.py <sheet.png> <out-dir>
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "vfx-spectacle-20260926"))
from cast_atlas import matte

def main(sheet, out):
    os.makedirs(out, exist_ok=True)
    rgba = matte(Image.open(sheet).convert("RGB"))
    a = np.asarray(rgba)
    solid = a[..., 3] > 24
    labels, n = ndi.label(ndi.binary_dilation(solid, iterations=5))
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    parts = []
    for k in range(1, n + 1):
        if sizes[k] < 900: continue
        ys, xs = np.where((labels == k) & solid)
        if len(xs) == 0: continue
        x0, y0, x1, y1 = max(0, xs.min() - 6), max(0, ys.min() - 6), min(a.shape[1], xs.max() + 7), min(a.shape[0], ys.max() + 7)
        mask = (labels[y0:y1, x0:x1] == k)
        crop = a[y0:y1, x0:x1].copy(); crop[~mask] = 0
        parts.append({"box": [int(x0), int(y0), int(x1), int(y1)], "img": crop})
    parts.sort(key=lambda p: (p["box"][1] // 120, p["box"][0]))
    meta = []
    for i, p in enumerate(parts):
        Image.fromarray(p["img"]).save(os.path.join(out, f"{i:02d}.png"))
        meta.append({"index": i, "box": p["box"]})
    json.dump(meta, open(os.path.join(out, "parts.json"), "w"), indent=1)
    sheet_im = Image.new("RGB", rgba.size, (40, 44, 58)); sheet_im.paste(rgba, (0, 0), rgba)
    d = ImageDraw.Draw(sheet_im)
    for m in meta:
        x0, y0, x1, y1 = m["box"]; d.rectangle((x0, y0, x1, y1), outline=(255, 220, 0)); d.text((x0 + 4, y0 + 4), str(m["index"]), fill=(255, 60, 60))
    sheet_im.save(os.path.join(out, "index.jpg"), quality=85)
    print(len(meta), "parts")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
