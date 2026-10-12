"""Pack the final-boss cast art (ArtSource/FinalBossParty20261010) into SpectacleCast.png:
2048x2048, a 2x2 grid of 1024 px cells, for the Q30 angel intro (2026-10-10). Cell order
= CELLS (PaintSprite cells 48+). Gray-background paintings (#8E8A85 family) are matted
with the same edge-connected flood as prepare_sevian_video_body.py; transparent art keeps
its alpha. A missing spread-wing painting falls back to the plain full-body one.

usage: <media-venv>/bin/python tools/vfx-spectacle-20260926/cast_atlas.py <art-dir> <out.png>
       (media-venv = /Volumes/andrew's SSD/Mistport-hero-v2/media-venv)
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

# Cell 48 was the plain standing Elaia, unused once the spread-wing paintings came; since
# 2026-10-10 it is the user's angel feather (ArtSource/SpellProps20261007/angel_feather.png),
# centred in its cell (it spins about the middle) instead of standing on the bottom edge.
CELLS = [("../SpellProps20261007/angel_feather", None), ("shadow_pursuer", None),
         ("elaia_spread_descend", "elaia_full"), ("elaia_spread_seal", "elaia_full")]
CENTRED = {"../SpellProps20261007/angel_feather"}
CELL, PAD = 1024, 12

def matte(rgb):
    a = np.asarray(rgb).astype(np.float32)
    edge = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    bg = np.median(edge, axis=0)
    distance = np.max(np.abs(a - bg), axis=2)
    near = distance < 20
    seeds = np.zeros(near.shape, bool); seeds[0, :] = near[0, :]; seeds[-1, :] = near[-1, :]; seeds[:, 0] = near[:, 0]; seeds[:, -1] = near[:, -1]
    connected = ndi.binary_propagation(seeds, mask=near)
    islands, n = ndi.label((distance < 6) & ~connected)
    counts = np.bincount(islands.ravel()); counts[0] = 0
    enclosed = np.isin(islands, np.where(counts > 400)[0])
    connected |= ndi.binary_propagation(enclosed, mask=distance < 12)
    solid = ~connected
    labels, count = ndi.label(solid)
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    solid = np.isin(labels, np.where(sizes > 300)[0])
    alpha = ndi.gaussian_filter(solid.astype(np.float32), .8)
    alpha[solid & (ndi.distance_transform_edt(solid) > 1.5)] = 1
    unmix = (a - (1 - alpha[..., None]) * bg) / np.maximum(alpha[..., None], .15)
    rgba = np.dstack([np.clip(unmix, 0, 255), alpha * 255]).astype(np.uint8)
    rgba[alpha < .015] = 0
    return Image.fromarray(rgba)

def load(path):
    im = Image.open(path)
    if im.mode == "RGBA" and np.asarray(im)[..., 3].min() < 250:
        return im.convert("RGBA")
    return matte(im.convert("RGB"))

def fit(im, centred=False):
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox() or (0, 0, im.width, im.height)
    im = im.crop(box)
    s = (CELL - 2 * PAD) / max(im.width, im.height)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    # Figures stand on the cell's bottom edge so a pose swap keeps the feet in place.
    cell.paste(im, ((CELL - im.width) // 2, (CELL - im.height) // 2 if centred else CELL - PAD - im.height))
    return cell

def main(src, out):
    sheet = Image.new("RGBA", (CELL * 2, CELL * 2), (0, 0, 0, 0))
    for i, (name, fallback) in enumerate(CELLS):
        path = os.path.join(src, name + ".png")
        if not os.path.exists(path) and fallback:
            path = os.path.join(src, fallback + ".png"); print("fallback", name, "->", fallback)
        if not os.path.exists(path):
            print("missing", name); continue
        sheet.paste(fit(load(path), name in CENTRED), ((i % 2) * CELL, (i // 2) * CELL))
        print("packed", 48 + i, name)
    sheet.save(out)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
