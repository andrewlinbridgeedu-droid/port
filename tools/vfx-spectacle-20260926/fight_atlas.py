"""Pack the Q30 angel-intro fight video (the user's image-to-video take, 2026-10-11, from
output/party-boss-20261010/fight-video/fight_start.png) into SpectacleFight.png: 2048x1024,
an 8x8 grid of 256x128 cells, 64 frames evenly over the clip, shown as a flipbook inside the
ball of light (SpellSpectacle20260926, PaintSprite cells 100+).

The video's flat gray background (#8E8A85 family) is keyed softly - alpha rises with the
distance from the gray, so the mist the video adds stays half see-through - and the colour
unmixed from it. Every frame fades out toward its borders (the giant is cut by the frame at
times), so the figures dissolve into the light instead of ending on a straight edge.

usage: <media-venv>/bin/python tools/vfx-spectacle-20260926/fight_atlas.py <frames-dir> <out.png>
       frames-dir: the clip extracted at its own rate (output/handdrawn-vfx-20261008/bin/extract_range ... 24)
"""
import glob, sys
import numpy as np
from PIL import Image

COLS = ROWS = 8
CW, CH = 256, 128
FRAMES = COLS * ROWS

def key(im):
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    edge = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
    bg = np.median(edge, axis=0)
    d = np.max(np.abs(a - bg), axis=2)
    alpha = np.clip((d - 9) / 30, 0, 1)
    h, w = alpha.shape
    u = np.minimum(np.arange(w) / w, 1 - np.arange(w) / w)[None, :]
    v = np.minimum(np.arange(h) / h, 1 - np.arange(h) / h)[:, None]
    s = lambda x, e: np.clip(x / e, 0, 1) ** 1.5
    alpha *= s(u, .1) * s(v, .12)
    rgb = (a - (1 - alpha[..., None]) * bg) / np.maximum(alpha[..., None], .2)
    out = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    out[alpha < .02] = 0
    return Image.fromarray(out, "RGBA")

def main(src, out):
    fs = sorted(glob.glob(f"{src}/*.png"))
    sheet = Image.new("RGBA", (COLS * CW, ROWS * CH), (0, 0, 0, 0))
    fw = round(CH * Image.open(fs[0]).width / Image.open(fs[0]).height)   # keep the clip's aspect
    for i in range(FRAMES):
        im = key(Image.open(fs[min(len(fs) - 1, round(i * len(fs) / FRAMES))])).resize((fw, CH), Image.LANCZOS)
        sheet.paste(im, ((i % COLS) * CW + (CW - fw) // 2, (i // COLS) * CH))
    sheet.save(out)
    print("packed", FRAMES, "of", len(fs), "frames; frame width", fw, "of", CW)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
