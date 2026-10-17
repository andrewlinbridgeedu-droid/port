"""Hair-card atlas for Shadowfang v51 (finer: more, thinner locks and strands; neutral
brightness around 0.5, because each card now carries the body colour under its root and
the shader multiplies the two). v49 notes follow.

Hair-card atlas for Shadowfang v49: four columns, each one card's worth of fur
(root at the bottom, v = 0; tip at the top, v = 1).

Each column is one clump in the style of ManePaint-v26: a solid charcoal root
that splits into several pointed locks, each lock carrying continuous fine
strands (lighter and darker), with loose hairs at the edges. Alpha is the
clump silhouette plus the loose hairs; RGB is dilated into the empty texels
so mipmaps do not pick up a dark fringe.

Usage: python fur-strands-v49.py <out.png> [preview.png]
"""
import sys
import numpy as np
from PIL import Image

SS = 2                       # supersampling
COLS, CW, CH = 4, 256, 1024  # final atlas 1024 x 1024
W, H = CW * SS, CH * SS


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def tint(v):
    # Neutral: the colour comes from the body under each card (0.5 = body colour).
    return np.stack([v, v, v], axis=-1)


def stroke(rgb, alpha, xs, ys, rs, vs, opacity):
    """One continuous stroke (capsule chain with varying radius and value),
    composited once with 'over', so overlapping segments never double up."""
    pad = float(np.max(rs)) + 2
    x0, x1 = int(max(0, np.min(xs) - pad)), int(min(W, np.max(xs) + pad + 1))
    y0, y1 = int(max(0, np.min(ys) - pad)), int(min(H, np.max(ys) + pad + 1))
    if x0 >= x1 or y0 >= y1:
        return
    cover = np.zeros((y1 - y0, x1 - x0))
    value = np.zeros((y1 - y0, x1 - x0, 3))
    vs = tint(np.asarray(vs, float))
    for i in range(len(xs) - 1):
        ax, ay, bx, by = xs[i], ys[i], xs[i + 1], ys[i + 1]
        ra, rb = rs[i], rs[i + 1]
        r = max(ra, rb) + 2
        sx0, sx1 = int(max(x0, min(ax, bx) - r)), int(min(x1, max(ax, bx) + r + 1))
        sy0, sy1 = int(max(y0, min(ay, by) - r)), int(min(y1, max(ay, by) + r + 1))
        if sx0 >= sx1 or sy0 >= sy1:
            continue
        gy, gx = np.mgrid[sy0:sy1, sx0:sx1] + .5
        dx, dy = bx - ax, by - ay
        l2 = max(dx * dx + dy * dy, 1e-6)
        s = np.clip(((gx - ax) * dx + (gy - ay) * dy) / l2, 0, 1)
        d = np.hypot(gx - (ax + s * dx), gy - (ay + s * dy))
        rad = ra + (rb - ra) * s
        c = np.clip(rad + .8 - d, 0, 1) * np.clip(rad / .6, 0, 1)
        sub = cover[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0]
        take = c > sub
        val = vs[i][None, None, :] * (1 - s[..., None]) + vs[i + 1][None, None, :] * s[..., None]
        value[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0][take] = val[take]
        sub[take] = c[take]
    a = cover * opacity
    region = rgb[y0:y1, x0:x1]
    rgb[y0:y1, x0:x1] = region * (1 - a[..., None]) + value * a[..., None]
    alpha[y0:y1, x0:x1] = alpha[y0:y1, x0:x1] * (1 - a) + a


def column(seed):
    r = np.random.default_rng(seed)
    rgb = np.zeros((H, W, 3))
    alpha = np.zeros((H, W))
    fingers = int(r.integers(5, 9))
    base = W * r.uniform(.78, .9)
    left = (W - base) / 2
    lean = W * r.uniform(-.2, .2)          # the whole clump leans a little
    n = 90
    locks = []
    for k in range(fingers):
        # Roots spread over the base and overlap, tips separate and point.
        x0 = left + base * (k + .5) / fingers + r.uniform(-.04, .04) * base
        tip_x = W / 2 + lean + (x0 - W / 2) * r.uniform(.55, 1.05) + r.uniform(-.06, .06) * W
        length = H * r.uniform(.70, .97)
        bend = W * r.uniform(-.12, .12)
        t = np.linspace(0, 1, n)
        cx = x0 + (tip_x - x0) * smooth(0, 1, t) ** .9 + bend * np.sin(t * np.pi * 1.25)
        cy = t * length
        root_r = base / fingers * .5 * r.uniform(1.25, 1.5)
        prof = (1 - t ** 1.7) ** .85 * (1 - t) ** .25
        locks.append(dict(cx=cx, cy=cy, r=root_r * prof, t=t, v=r.uniform(.42, .52), length=length, x0=x0,
                          tip_x=tip_x, bend=bend, root_r=root_r))
    # Back to front: a darker lock behind, lighter locks in front.
    order = list(r.permutation(fingers))
    for rank, k in enumerate(order):
        L = locks[k]
        front = rank / max(1, fingers - 1)
        v0 = L['v'] + .04 * front
        t = L['t']
        vals = v0 * (.6 + .4 * smooth(0, .5, t)) * (1 + .1 * smooth(.6, 1, t))
        stroke(rgb, alpha, L['cx'], L['cy'], L['r'], vals, .98)
        # Fine strands follow the lock and converge at its tip.
        for s in range(int(40 + 20 * r.random())):
            u = r.uniform(-.92, .92)
            a, b = r.uniform(0, .3), r.uniform(.6, 1.0)
            tt = np.linspace(a, b, 48)
            prof = (1 - tt ** 1.7) ** .85 * (1 - tt) ** .25
            cx = L['x0'] + (L['tip_x'] - L['x0']) * smooth(0, 1, tt) ** .9 + L['bend'] * np.sin(tt * np.pi * 1.25)
            sx = cx + u * L['root_r'] * prof * .92 + SS * r.uniform(-1.2, 1.2) * np.sin(tt * 7 + s)
            sy = tt * L['length']
            light = r.random() < .62
            sv = (v0 + r.uniform(.1, .26)) if light else v0 * r.uniform(.55, .75)
            vals = np.full_like(tt, sv) * (.6 + .4 * smooth(a, a + .3, tt))
            rad = SS * r.uniform(.35, .7) * (1 - .55 * (tt - a) / max(1e-3, b - a))
            fade = smooth(a, a + .1, tt) * (1 - smooth(.8, 1, (tt - a) / max(1e-3, b - a)))
            # Opacity varies along the stroke through the radius ramp; keep the
            # stroke's own opacity constant.
            stroke(rgb, alpha, sx, sy, rad * (.3 + .7 * fade), vals, r.uniform(.45, .8) if light else .5)
        # Loose hairs leaving the edges and running past the tip.
        for s in range(int(10 + 8 * r.random())):
            side = -1 if r.random() < .5 else 1
            a = r.uniform(.25, .6)
            tt = np.linspace(a, 1, 40)
            prof = (1 - tt ** 1.7) ** .85 * (1 - tt) ** .25
            cx = L['x0'] + (L['tip_x'] - L['x0']) * smooth(0, 1, tt) ** .9 + L['bend'] * np.sin(tt * np.pi * 1.25)
            spread = side * L['root_r'] * (prof * .95 + r.uniform(.15, .35) * (tt - a))
            sx = cx + spread
            sy = tt * L['length'] * r.uniform(1.0, 1.07)
            rad = SS * .5 * (1 - .6 * (tt - a) / (1 - a))
            stroke(rgb, alpha, sx, sy, rad * .8, np.full_like(tt, v0 + .12), .65)
    return rgb, alpha


def main():
    out = sys.argv[1]
    cols = [column(5100 + c) for c in range(COLS)]
    rgb = np.concatenate([c[0] for c in cols], axis=1)
    alpha = np.concatenate([c[1] for c in cols], axis=1)
    rgb = rgb.reshape(CH, SS, COLS * CW, SS, 3).mean(axis=(1, 3))
    alpha = alpha.reshape(CH, SS, COLS * CW, SS).mean(axis=(1, 3))
    # rgb is premultiplied by construction ('over' on black); unpremultiply.
    straight = np.where(alpha[..., None] > 1e-4, rgb / np.maximum(alpha[..., None], 1e-4), 0)
    filled = alpha > .02
    col = straight.copy()
    for _ in range(24):
        acc = np.zeros_like(col); cnt = np.zeros(alpha.shape)
        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            m = np.roll(filled, (dy, dx), (0, 1)); c = np.roll(col, (dy, dx), (0, 1))
            acc += c * m[..., None]; cnt += m
        grow = (~filled) & (cnt > 0)
        col[grow] = acc[grow] / cnt[grow][:, None]
        filled = filled | grow
    col[~filled] = straight[alpha > .5].mean(axis=0)
    # Image rows run top-down; the card root (v = 0) is the bottom row.
    img = np.dstack([np.clip(col, 0, 1), np.clip(alpha, 0, 1)])[::-1]
    Image.fromarray((img * 255 + .5).astype(np.uint8), 'RGBA').save(out)
    if len(sys.argv) > 2:
        bg = np.ones((CH, COLS * CW, 3)) * np.array([.55, .58, .62])
        a = img[..., 3:4]
        Image.fromarray(((img[..., :3] * a + bg * (1 - a)) * 255).astype(np.uint8)).save(sys.argv[2])
    print('FUR_STRANDS_WRITTEN', out, 'coverage=%.3f' % alpha.mean())


if __name__ == '__main__':
    main()
