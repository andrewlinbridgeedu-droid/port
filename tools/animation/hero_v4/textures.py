"""Painted coat and lining atlases for each outfit (see atlas.py for the layout)."""
import math, random
import numpy as np
from . import paint, filigree, atlas

PALETTES = {
    'night': dict(coat=(0.085, 0.075, 0.105), weave=1.55, lining=(0.42, 0.25, 0.68), damask=(0.53, 0.35, 0.80),
                  cuff=(0.40, 0.22, 0.64), gold=(0.93, 0.72, 0.36), trim_line=(0.93, 0.72, 0.36)),
    'starlight': dict(coat=(0.90, 0.87, 0.80), weave=0.93, lining=(0.13, 0.18, 0.42), damask=(0.20, 0.27, 0.55),
                      cuff=(0.14, 0.20, 0.46), gold=(0.92, 0.73, 0.38), trim_line=(0.92, 0.73, 0.38)),
    'carnival': dict(coat=(0.095, 0.05, 0.06), weave=1.6, lining=(0.62, 0.08, 0.12), damask=(0.74, 0.16, 0.18),
                     cuff=(0.58, 0.07, 0.11), gold=(0.95, 0.74, 0.34), trim_line=(0.95, 0.74, 0.34)),
}


def _weave(palette, seed):
    k = palette['weave']

    def fn(xs, ys, rgb):
        u = (xs + ys) / 2.4
        v = (xs - ys) / 2.4
        line = np.minimum(np.abs(u - np.round(u)), np.abs(v - np.round(v)))
        lat = np.clip(1 - line / 0.055, 0, 1)
        grain = paint.value_noise(xs * 9, ys * 1.3, 1.0, seed) - 0.5
        mottle = paint.value_noise(xs, ys, 6.0, seed + 1) - 0.5
        f = 1 + (k - 1) * lat * 0.55 + grain * 0.07 + mottle * 0.06
        return np.clip(rgb * f[..., None], 0, 1)
    return fn


def _harlequin(xs, ys, rgb):
    """Carnival: faint red diamonds woven into the black."""
    u = (xs + ys) / 6.0
    v = (xs - ys) / 6.0
    cell = (np.floor(u) + np.floor(v)) % 2
    tint = np.where(cell[..., None] > 0, np.array([1.45, 0.75, 0.75], np.float32), 1.0)
    return np.clip(rgb * tint, 0, 1)


def _stars(canvas, region, gold, rng, density=0.012, size=(0.18, 0.42)):
    x0, y0, w, h = atlas.REGIONS[region]
    count = int(w * h * density)
    for _ in range(count):
        x = x0 + rng.uniform(1, w - 1)
        y = y0 + rng.uniform(1, h - 1)
        r = rng.uniform(*size)
        for a in (0.0, math.pi / 2):
            pts = [(x - math.cos(a) * r * 2.2, y - math.sin(a) * r * 2.2), (x, y), (x + math.cos(a) * r * 2.2, y + math.sin(a) * r * 2.2)]
            canvas.stroke(pts, [0.01, r * 0.55, 0.01], gold, outline_w=0.03, stitch=0.08)


def _hem_y(hem, x):
    """Height of the hem polyline at canvas x."""
    for (x0, y0), (x1, y1) in zip(hem, hem[1:]):
        if x0 <= x <= x1 and x1 > x0:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return hem[-1][1]


def paint_hair(path, base=(0.075, 0.07, 0.13), tip=(0.17, 0.14, 0.30), shine=(0.46, 0.44, 0.68)):
    """Hair strip texture: u across a clump, v root (0) to tip (1). Root-to-tip
    gradient, fine strand lines and a jagged highlight band."""
    W, H = 256, 1024
    v = (np.arange(H, dtype=np.float32)[::-1] + 0.5)[:, None] / H
    u = (np.arange(W, dtype=np.float32) + 0.5)[None, :] / W
    g = np.clip(v ** 1.3, 0, 1)
    col = np.array(base, np.float32) * (1 - g[..., None]) + np.array(tip, np.float32) * g[..., None]
    strands = 0.88 + 0.12 * np.sin(u * 64 + np.sin(u * 9) * 2.0) ** 2
    col = col * strands[..., None]
    edge = 0.26 + 0.035 * np.sin(u * 37.0) + 0.02 * np.sin(u * 91.0 + 1.0)
    band = np.clip(1 - np.abs(v - edge) / 0.045, 0, 1) ** 1.6 * (0.55 + 0.45 * np.sin(u * 23.0) ** 2)
    col = col * (1 - band[..., None]) + np.array(shine, np.float32) * band[..., None]
    # Darker sides of each clump read as separation between locks.
    side = np.clip(1 - np.abs(u - 0.5) * 2, 0, 1) ** 0.35
    col *= (0.72 + 0.28 * side)[..., None]
    import bpy
    img = bpy.data.images.new('HeroV4-hair', W, H, alpha=False)
    rgba = np.ones((H, W, 4), np.float32)
    rgba[..., :3] = np.clip(col, 0, 1)
    img.pixels.foreach_set(rgba[::-1].ravel())
    img.filepath_raw = str(path)
    img.file_format = 'PNG'
    img.save()
    return img


def paint_coat(outfit, hem_uv, path, seed=11, cape_hem_uv=None):
    pal = PALETTES[outfit]
    rng = random.Random(seed)
    c = paint.Canvas(atlas.SIZE_CM, atlas.SIZE_CM, atlas.PX / atlas.SIZE_CM)
    c.fill(pal['coat'])
    c.pattern(0, 0, atlas.SIZE_CM, atlas.SIZE_CM, _weave(pal, seed))
    if outfit == 'carnival':
        for region in ('tail', 'torso', 'sleeve'):
            x0, y0, w, h = atlas.REGIONS[region]
            c.pattern(x0, y0, x0 + w, y0 + h, _harlequin)
    gold = pal['gold']
    # Cuffs are dyed silk (purple / navy / crimson) with a lighter damask.
    x0, y0, w, h = atlas.REGIONS['cuff']
    c.fill_rect(x0, y0, x0 + w, y0 + h, pal['cuff'])
    c.pattern(x0, y0, x0 + w, y0 + h, _weave(dict(weave=1.12), seed + 3))
    # ---- Tails: running scroll along the hem and a grand scroll above the point.
    hem = [tuple(p) for p in hem_uv]
    if hem[0][0] > hem[-1][0]:
        hem = hem[::-1]
    for pts, ws in filigree.rinceau(hem, 4.6, 7.6, 1.55, rng, stem_w=0.18, inward=1):
        c.stroke(pts, ws, gold)
    tip = min(hem, key=lambda p: p[1])
    tx0, ty0, tw, th = atlas.REGIONS['tail']
    # Lyre of two facing scrolls above the point, inside the visible back of the tail.
    big = 24.0 if outfit != 'carnival' else 20.0
    left_root = (max(tx0 + 4.0, tip[0] + 5.0), tip[1] + 8.5)
    right_root = (left_root[0] + 17.0, _hem_y(hem, left_root[0] + 17.0) + 8.0)
    for pts, ws in filigree.grand_scroll(left_root, math.radians(80), big, -1, rng):
        c.stroke(pts, ws, gold)
    for pts, ws in filigree.grand_scroll(right_root, math.radians(112), big * 0.78, 1, rng):
        c.stroke(pts, ws, gold)
    if outfit == 'starlight':
        _stars(c, 'tail', gold, rng)
    # ---- Torso: waist band and shoulder-blade scrolls.
    tx0, ty0, tw, th = atlas.REGIONS['torso']
    cx = tx0 + 48.0
    waist_y = ty0 + 2.0 + 7.6
    guide = [(cx - 19 + i * 0.5, waist_y) for i in range(77)]
    for pts, ws in filigree.rinceau(guide, 1.6, 4.4, 0.85, rng, stem_w=0.11, inward=1, edge_line=False):
        c.stroke(pts, ws, gold)
    for sgn in (1, -1):
        for pts, ws in filigree.grand_scroll((cx + sgn * 3.2, ty0 + 2.0 + 30.0), math.radians(90 - sgn * 38), 10.5,
                                             -sgn, rng):
            c.stroke(pts, ws, gold)
    if outfit == 'starlight':
        _stars(c, 'torso', gold, rng, density=0.008)
        _stars(c, 'sleeve', gold, rng, density=0.008)
    # ---- Collar: a small running scroll under the gold lip.
    kx0, ky0, kw, kh = atlas.REGIONS['collar']
    guide = [(kx0 + 1 + i * 0.5, ky0 + 1.0 + 5.4) for i in range(int((kw - 2) / 0.5))]
    for pts, ws in filigree.rinceau(guide, 1.8, 3.2, 0.6, rng, stem_w=0.08, inward=-1, edge_line=False):
        c.stroke(pts, ws, gold)
    # ---- Cuffs: border along the flared rim, a scroll rising on the rear point.
    guide = [(x0 + 0.5 + i * 0.5, y0 + 1.0 + 4.2 + 9.5 - 0.3) for i in range(int((w - 1) / 0.5))]
    for pts, ws in filigree.rinceau(guide, 2.4, 4.2, 0.95, rng, stem_w=0.12, inward=-1):
        c.stroke(pts, ws, gold)
    for sgn in (1, -1):
        for pts, ws in filigree.grand_scroll((x0 + 23.0 + sgn * 0.6, y0 + 1.6), math.radians(90 - sgn * 25), 6.0,
                                             -sgn, rng):
            c.stroke(pts, ws, gold)
    # ---- Starlight half cape: stars and a running scroll along its hem.
    if cape_hem_uv:
        hem = [tuple(p) for p in cape_hem_uv]
        if hem[0][0] > hem[-1][0]:
            hem = hem[::-1]
        for pts, ws in filigree.rinceau(hem, 3.6, 5.8, 1.2, rng, stem_w=0.15, inward=1):
            c.stroke(pts, ws, gold)
        _stars(c, 'cape', gold, rng, density=0.02, size=(0.2, 0.5))
    return c.save(path, f'HeroV4-{outfit}-coat')


def paint_lining(outfit, path, seed=23):
    pal = PALETTES[outfit]
    rng = random.Random(seed)
    c = paint.Canvas(atlas.SIZE_CM, atlas.SIZE_CM, 1024 / atlas.SIZE_CM)
    c.fill(pal['lining'])
    c.pattern(0, 0, atlas.SIZE_CM, atlas.SIZE_CM, _weave(dict(weave=1.08), seed))
    # Tone-on-tone damask: low relief, no dark outline.
    tone = pal['damask']
    step = 9.0
    for j in range(int(atlas.SIZE_CM / step) + 1):
        for i in range(int(atlas.SIZE_CM / step) + 1):
            cx = i * step + (step / 2 if j % 2 else 0)
            cy = j * step
            for pts, ws in filigree.damask_tile(cx, cy, 2.6, rng):
                c.stroke(pts, [w * 0.8 for w in ws], tone, outline=pal['lining'], outline_w=0.0,
                         stitch=0.5, shine=0.0, flat=True)
    # Facings: a gold line at the fold and a fine running scroll.
    fx0, fy0, fw, fh = atlas.REGIONS['facing']
    gold = pal['gold']
    fold = [(fx0 + 1.5, fy0 + 93.0 - k * 0.5) for k in range(int(91 / 0.5))]
    c.stroke(fold, [0.12] * len(fold), gold)
    vine = [(fx0 + 4.4, fy0 + 60.0 - k * 0.5) for k in range(int(58 / 0.5))]
    for pts, ws in filigree.rinceau(vine, 0.0, 3.6, 0.9, rng, stem_w=0.09, inward=1, edge_line=False):
        c.stroke(pts, ws, gold)
    return c.save(path, f'HeroV4-{outfit}-lining')
