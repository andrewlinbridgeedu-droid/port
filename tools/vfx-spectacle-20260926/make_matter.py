"""Matter atlas for SpellSpectacle20260926 (second design pass).

usage: /tmp/mistport-vfx-encode/venv/bin/python make_matter.py <out_dir>

SpectacleMatter.png is 1024x2048: eight rows of 1024x256, row 0 at the
image top. Every row tiles along x (the body's length axis). Channels share
one meaning so the shader treats every matter alike:
  R = bright line work (drawn in the identity's line colour)
  G = body density / facet shading (modulates the colour ramp)
  B = sparkle / glints
  A = coverage
Rows: 0 filigree, 1 flame, 2 water, 3 crystal, 4 silk, 5 ink, 6 electric, 7 smoke.
A world-isotropic feature has roughly the same cycle count along x and y,
because a strip is mapped about 3.4x wider in texels than it is tall.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
import make_textures  # noqa: E402  (row 0 reuses the approved first-pass filigree)

W, H = 1024, 256
ASPECT = 3.4


def pnoise(sx, sy, seed):
    """Periodic noise with about sx cycles along x and sy along y."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((H, W))
    fx = np.fft.fftfreq(W)[None, :] * W
    fy = np.fft.fftfreq(H)[:, None] * H
    filt = np.exp(-((fx / sx) ** 2 + (fy / sy) ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    out -= out.min()
    return out / (out.max() + 1e-9)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def blur(arr, radius):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    # wrap horizontally so the blur tiles
    wide = Image.new("L", (W * 3, H))
    for k in range(3):
        wide.paste(im, (k * W, 0))
    wide = wide.filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(wide.crop((W, 0, 2 * W, H)), np.float64) / 255


def dots(seed, count, rmin, rmax, value=1.0):
    rng = np.random.default_rng(seed)
    S = 3
    im = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(im)
    for _ in range(count):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(rmin, rmax)
        for shift in (-W, 0, W):
            d.ellipse([(x + shift - r * ASPECT) * S, (y - r) * S, (x + shift + r * ASPECT) * S, (y + r) * S], fill=int(255 * value))
    return np.asarray(im.resize((W, H), Image.LANCZOS), np.float64) / 255


def polyline(draw, pts, width, S, value=255):
    for shift in (-W, 0, W):
        for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
            draw.line([((x0 + shift) * S, y0 * S), ((x1 + shift) * S, y1 * S)], fill=value, width=max(1, int(width * S)))


def row_filigree():
    import tempfile
    tmp = tempfile.mkdtemp()
    make_textures.filigree(tmp)
    return np.asarray(Image.open(os.path.join(tmp, "SpectacleFiligree.png")), np.float64) / 255


def row_flame():
    # Licking tongues stretched along the body, hot inner streaks, embers.
    n1, n2, n3 = pnoise(5, 9, 11), pnoise(14, 26, 12), pnoise(3, 3, 13)
    y = np.arange(H)[:, None] / H
    tongues = n1 * .62 + n2 * .38
    g = smooth(.30, .72, tongues) * (.75 + .25 * n3)
    phase = y * 16 + (n1 - .5) * 5 + (n3 - .5) * 3
    r = np.clip(np.power(.5 + .5 * np.cos(2 * math.pi * phase), 8) * smooth(.35, .7, n2) * g * 1.8, 0, 1)
    b = dots(14, 90, .6, 1.6) * .9
    a = np.clip(np.maximum(g, r) + b * .5, 0, 1)
    return np.dstack([r, g, b, a])


def row_water():
    # Caustic web over a soft body, with foam bubbles.
    c1, c2, body = pnoise(9, 7, 21), pnoise(15, 11, 22), pnoise(4, 3, 23)
    web = np.exp(-((c1 - .5) / .032) ** 2) + .65 * np.exp(-((c2 - .5) / .026) ** 2)
    r = np.clip(web, 0, 1) * (.55 + .45 * body)
    g = .45 + .55 * smooth(.2, .8, body)
    ring = dots(24, 140, .8, 3.2) - dots(24, 140, .45, 2.0)
    b = np.clip(ring, 0, 1)
    a = np.clip(.72 + .28 * np.maximum(r, b), 0, 1)
    return np.dstack([r, g, b, a])


def row_crystal():
    # Faceted cells: flat per-cell shading, bright seams, glints at junctions.
    rng = np.random.default_rng(31)
    n = 34
    sx, sy = rng.uniform(0, W, n), rng.uniform(0, H, n)
    shade = rng.uniform(.3, 1.0, n)
    ang = rng.uniform(0, 2 * math.pi, n)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    dists = []
    for k in range(n):
        dx = np.abs(xx - sx[k])
        dx = np.minimum(dx, W - dx) / ASPECT
        dy = yy - sy[k]
        dists.append(np.sqrt(dx * dx + dy * dy))
    d = np.stack(dists, 0)
    order = np.argsort(d, 0)
    ds = np.take_along_axis(d, order, 0)
    d1, d2, d3 = ds[0], ds[1], ds[2]
    idx = order[0]
    r = np.exp(-((d2 - d1) / 1.6) ** 2)
    ex = xx - sx[idx]
    ex = (ex + W / 2) % W - W / 2
    facet = (np.cos(ang[idx]) * ex / ASPECT + np.sin(ang[idx]) * (yy - sy[idx])) / 40.0
    g = np.clip(shade[idx] + facet * .35, .15, 1)
    b = np.exp(-((d3 - d1) / 2.2) ** 2) * .9
    a = np.ones_like(g)
    return np.dstack([r, g, b, a])


def row_silk():
    # Curving fibres with uneven spacing, broad soft folds.
    y = np.arange(H)[:, None] / H
    w1, w2, w3 = pnoise(3, 2, 41), pnoise(8, 5, 42), pnoise(20, 8, 43)
    phase = y * 20 + (w1 - .5) * 6 + (w2 - .5) * 1.6
    r = np.power(.5 + .5 * np.cos(2 * math.pi * phase), 28) * (.35 + .65 * w3)
    folds = .5 + .5 * np.sin(2 * math.pi * (y * 2.6 + (w1 - .5) * 1.4))
    g = .38 + .62 * folds
    b = dots(44, 60, .4, 1.0) * .8
    a = np.clip(.8 + .2 * g, 0, 1)
    return np.dstack([r, g, b, a])


def row_ink():
    # Dry-brush strokes along the body with ragged gaps and splatter.
    streak, clump, fine = pnoise(3, 34, 51), pnoise(7, 5, 52), pnoise(26, 60, 53)
    body = smooth(.42, .53, streak * .55 + clump * .30 + fine * .15)
    upper = np.roll(body, 2, axis=0)
    r = np.clip(body - upper, 0, 1) * .9 + np.clip(fine - .78, 0, 1) * 2.2 * body
    splat = dots(54, 160, .3, 2.6)
    g = np.clip(body + splat * .9, 0, 1)
    b = dots(55, 40, .3, .8) * .7
    a = np.clip(np.maximum(g, r), 0, 1)
    return np.dstack([np.clip(r, 0, 1), g, b, a])


def row_electric():
    # Forked bolts crossing the strip; cores on R, glow on G, sparks on B.
    rng = np.random.default_rng(61)
    S = 3
    core = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(core)
    for bolt in range(6):
        y = rng.uniform(H * .2, H * .8)
        x = rng.uniform(0, W)
        pts = [(x, y)]
        for _ in range(70):
            x += rng.uniform(10, 20)
            y = np.clip(y + rng.normal(0, 9), H * .08, H * .92)
            pts.append((x, y))
            if rng.random() < .09:
                bx, by, bpts = x, y, [(x, y)]
                for _ in range(rng.integers(3, 8)):
                    bx += rng.uniform(8, 16)
                    by = np.clip(by + rng.normal(0, 12) + rng.choice([-6, 6]), 2, H - 2)
                    bpts.append((bx, by))
                polyline(d, bpts, 1.2, S)
        polyline(d, pts, 2.2, S)
    r = np.asarray(core.resize((W, H), Image.LANCZOS), np.float64) / 255
    g = np.clip(blur(r, 5) * 3.2 + blur(r, 14) * 2.0, 0, 1)
    b = dots(62, 120, .3, .9)
    a = np.clip(np.maximum(g * .9, r) + b * .5, 0, 1)
    return np.dstack([r, g, b, a])


def row_smoke():
    # Billowing clouds with lit rims.
    n1, n2, n3 = pnoise(5, 4, 71), pnoise(12, 9, 72), pnoise(26, 18, 73)
    cloud = n1 * .55 + n2 * .3 + n3 * .15
    g = smooth(.28, .75, cloud)
    gy, gx = np.gradient(g)
    r = np.clip(np.sqrt(gx * gx * ASPECT * ASPECT + gy * gy) * 9, 0, 1) * smooth(.3, .6, g)
    b = dots(74, 50, .3, .8) * .6
    a = np.clip(g * .95 + r * .3, 0, 1)
    return np.dstack([r, g, b, a])


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    rows = [row_filigree(), row_flame(), row_water(), row_crystal(), row_silk(), row_ink(), row_electric(), row_smoke()]
    atlas = np.concatenate([np.clip(r, 0, 1) for r in rows], axis=0)
    Image.fromarray((atlas * 255 + .5).astype(np.uint8)).save(os.path.join(out, "SpectacleMatter.png"))
    vis = np.concatenate([np.dstack([r[..., 0], r[..., 1], r[..., 2]]) for r in rows], axis=0)
    Image.fromarray((np.clip(vis, 0, 1) * 255).astype(np.uint8)).resize((512, 1024)).save(os.path.join(out, "SpectacleMatter_vis.png"))
    print("ok")


if __name__ == "__main__":
    main()
