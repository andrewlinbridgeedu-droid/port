"""Painted coat and lining atlases for each outfit (see atlas.py for the layout).

Each design follows the outfit's 2D character art, translated to the back view:
- night: black damask coat; a gold-framed band down each tail's outer edge with a
  pointed gothic cartouche above the point; purple lining with a lilac leaf damask.
- starlight: ivory coat with gold-outlined stars; a night-sky band with gold
  constellation arcs; purple lining.
- carnival: black coat; crimson brocade band with gold scrolls; ivory damask lining
  and a harlequin panel in each turned-back corner."""
import math, random
import numpy as np
from . import paint, filigree, atlas

PALETTES = {
    'night': dict(coat=(0.085, 0.075, 0.105), damask=1.55, lining=(0.47, 0.30, 0.72),
                  lining_tone=(0.66, 0.50, 0.90), cuff=(0.42, 0.25, 0.68), band=None,
                  gold=(0.93, 0.72, 0.36)),
    'starlight': dict(coat=(0.93, 0.90, 0.84), damask=1.04, lining=(0.47, 0.32, 0.74),
                      lining_tone=(0.64, 0.50, 0.90), cuff=(0.12, 0.15, 0.38), band=(0.08, 0.10, 0.30),
                      gold=(0.92, 0.75, 0.42)),
    'carnival': dict(coat=(0.085, 0.06, 0.07), damask=1.6, lining=(0.88, 0.82, 0.70),
                     lining_tone=(0.76, 0.66, 0.52), cuff=(0.60, 0.08, 0.11), band=(0.58, 0.07, 0.10),
                     gold=(0.95, 0.75, 0.36)),
}
BAND_W = {'night': 8.5, 'starlight': 9.5, 'carnival': 9.0}


def _grain(seed, k=1.0):
    def fn(xs, ys, rgb):
        grain = paint.value_noise(xs * 9, ys * 1.3, 1.0, seed) - 0.5
        mottle = paint.value_noise(xs, ys, 6.0, seed + 1) - 0.5
        f = 1 + (grain * 0.07 + mottle * 0.07) * k
        return np.clip(rgb * f[..., None], 0, 1)
    return fn


def _damask(c, region_box, tone, rng, step=8.0, size=2.4, relief=True):
    """Tone-on-tone woven pattern: flat, low-relief motifs without outlines. On pale
    cloth the relief shading would read as grey spots, so it is drawn flat there."""
    x0, y0, x1, y1 = region_box
    j = 0
    y = y0
    while y < y1 + step:
        x = x0 + (step / 2 if j % 2 else 0)
        while x < x1 + step:
            for pts, ws in filigree.damask_tile(x, y, size, rng):
                c.stroke(pts, [w * 0.8 for w in ws], tone, outline=tone, outline_w=0.0, stitch=0.5, shine=0.0,
                         flat=True, light=(0, 0, 1) if not relief else (-0.55, 0.65, 0.52))
            x += step
        y += step
        j += 1


def _scale(col, k):
    return tuple(min(1.0, v * k) for v in col)


def _stars(c, box, gold, rng, count, size=(0.25, 0.55)):
    """Gold-outlined four-point stars."""
    x0, y0, x1, y1 = box
    for _ in range(count):
        x, y = rng.uniform(x0 + 1, x1 - 1), rng.uniform(y0 + 1, y1 - 1)
        r = rng.uniform(*size)
        pts = []
        for k in range(9):
            a = k / 8 * math.tau + math.pi / 2
            rr = r * (2.4 if k % 2 == 0 else 0.7)
            pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
        c.stroke(pts, [0.06] * len(pts), gold, outline_w=0.03, stitch=0.08)


def _sky(seed):
    """Night sky: deep navy with a soft glow and fine stars."""
    def fn(xs, ys, rgb):
        rng = np.random.default_rng(seed)
        glow = paint.value_noise(xs, ys, 9.0, seed) * 0.6 + paint.value_noise(xs, ys, 3.0, seed + 5) * 0.4
        base = np.array([0.06, 0.07, 0.24], np.float32) * (0.75 + 0.6 * glow[..., None])
        base += np.array([0.10, 0.06, 0.20], np.float32) * np.clip(glow - 0.55, 0, 1)[..., None] * 2
        star = paint.value_noise(xs * 7.0, ys * 7.0, 1.0, seed + 9)
        twinkle = np.clip((star - 0.93) / 0.05, 0, 1) ** 2
        return np.clip(base + twinkle[..., None] * np.array([0.9, 0.9, 1.0]), 0, 1)
    return fn


def _brocade(seed, base):
    """Crimson brocade: two red tones in a floral weave."""
    def fn(xs, ys, rgb):
        u = xs / 2.6
        v = ys / 2.6
        motif = np.sin(u * math.pi) * np.sin(v * math.pi) + 0.5 * np.sin((u + v) * math.pi * 0.5)
        tone = np.clip(0.82 + 0.25 * motif, 0.6, 1.15)
        col = np.array(base, np.float32)[None, None, :] * tone[..., None]
        grain = paint.value_noise(xs * 8, ys * 1.4, 1.0, seed) - 0.5
        return np.clip(col * (1 + grain[..., None] * 0.08), 0, 1)
    return fn


def gothic_cartouche(cx, cy, w, h):
    """Pointed ogee frame with mirrored inner volutes and a finial (night tails)."""
    strokes = []
    for s in (1, -1):
        outer = [(cx + s * (w / 2) * (1 - t ** 1.7) * (1 + 0.28 * math.sin(math.pi * t)), cy + h * t)
                 for t in [i / 60 for i in range(61)]]
        strokes.append((outer, [0.36] * len(outer)))
        inner = [(cx + s * (w / 2 - 1.0) * (1 - t ** 1.7) * (1 + 0.22 * math.sin(math.pi * t)), cy + 0.9 + (h - 2.6) * t)
                 for t in [i / 60 for i in range(61)]]
        strokes.append((inner, [0.16] * len(inner)))
        v, vw, _ = filigree.volute((cx + s * w * 0.30, cy + 1.4), math.pi / 2, h * 0.12, w * 0.15, 1.7, -s, 0.3, 0.09)
        strokes.append((v, vw))
        v, vw, _ = filigree.volute((cx + s * w * 0.12, cy + h * 0.42), math.pi / 2 - s * 0.3, h * 0.10, w * 0.12, 1.6,
                                   s, 0.22, 0.07)
        strokes.append((v, vw))
        v, vw, _ = filigree.volute((cx + s * w * 0.06, cy + h * 0.66), math.pi / 2 + s * 0.2, h * 0.07, w * 0.09, 1.5,
                                   -s, 0.16, 0.06)
        strokes.append((v, vw))
        strokes.extend(filigree.acanthus((cx + s * w * 0.18, cy + h * 0.30), math.pi / 2 + s * 0.6, h * 0.12,
                                         w * 0.05 + 0.06, -s))
    stem = [(cx, cy + 1.0 + k * 0.1) for k in range(int(h * 0.62 / 0.1))]
    strokes.append((stem, [0.18] * len(stem)))
    strokes.append(filigree.leaf((cx, cy + h * 0.98), math.pi / 2, h * 0.16, w * 0.09))
    base = [(cx - w / 2, cy), (cx + w / 2, cy)]
    strokes.append((base, [0.3, 0.3]))
    return strokes


def _place(strokes, origin, up):
    """Rotate strokes drawn upright around (0, 0) so +y follows `up`, then move to origin."""
    ux, uy = up
    l = math.hypot(ux, uy) or 1.0
    ux, uy = ux / l, uy / l
    rx, ry = uy, -ux  # right-hand side of `up`
    out = []
    for pts, ws in strokes:
        out.append(([(origin[0] + x * rx + y * ux, origin[1] + x * ry + y * uy) for x, y in pts], ws))
    return out


def _constellation(c, box, gold, rng):
    x0, y0, x1, y1 = box
    for _ in range(4):
        cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(5, 12)
        a0 = rng.uniform(0, math.tau)
        arc = [(cx + r * math.cos(a0 + k * 0.03), cy + r * math.sin(a0 + k * 0.03)) for k in range(70)]
        c.stroke(arc, [0.05] * len(arc), gold, outline_w=0.02, stitch=0.06, shine=0.3)
        for k in range(0, 70, 17):
            c.dot(arc[k][0], arc[k][1], 0.18, gold, outline_w=0.02)


def _band(c, outfit, start_uv, end_uv, gold, rng):
    """A framed stripe down the visible middle of each back tail (the art's tail band),
    narrow at the waist, widening and ending in a point above the hem."""
    W = BAND_W[outfit]
    n = min(len(start_uv), len(end_uv))
    f = 0.56
    left, right, centre = [], [], []
    for j in range(int(n * 0.9)):
        sx, sy = start_uv[j]
        ex, ey = end_uv[j]
        dx, dy = ex - sx, ey - sy
        l = math.hypot(dx, dy) or 1.0
        ux, uy = dx / l, dy / l
        w = W * (0.45 + 0.55 * (j / (n - 1)) ** 0.8)
        cx, cy = sx + dx * f, sy + dy * f
        left.append((cx - ux * w / 2, cy - uy * w / 2))
        right.append((cx + ux * w / 2, cy + uy * w / 2))
        centre.append((cx, cy))
    dx, dy = centre[-1][0] - centre[-2][0], centre[-1][1] - centre[-2][1]
    l = math.hypot(dx, dy) or 1.0
    tip = (centre[-1][0] + dx / l * W * 0.7, centre[-1][1] + dy / l * W * 0.7)
    poly = left + [tip] + right[::-1]
    pal = PALETTES[outfit]
    if outfit == 'starlight':
        c.fill_poly(poly, _sky(5))
    elif outfit == 'carnival':
        c.fill_poly(poly, _brocade(7, pal['band']))
    outline = left + [tip] + right[::-1]
    c.stroke(outline, [0.3] * len(outline), gold)
    inner_l = [(a[0] * 0.86 + b[0] * 0.14, a[1] * 0.86 + b[1] * 0.14) for a, b in zip(left, right)]
    inner_r = [(a[0] * 0.14 + b[0] * 0.86, a[1] * 0.14 + b[1] * 0.86) for a, b in zip(left, right)]
    c.stroke(inner_l, [0.12] * len(inner_l), gold)
    c.stroke(inner_r, [0.12] * len(inner_r), gold)
    k = max(1, len(centre) - 1 - int(len(centre) * 0.18))
    cx, cy = centre[k]
    up = (centre[k - 1][0] - centre[k + 1][0], centre[k - 1][1] - centre[k + 1][1])
    if outfit == 'night':
        for pts, ws in _place(gothic_cartouche(0.0, -14.0, W - 2.6, 26.0), (cx, cy), up):
            c.stroke(pts, ws, gold)
    elif outfit == 'carnival':
        motif = []
        for sgn in (1, -1):
            motif.extend(filigree.grand_scroll((sgn * 0.5, -10.0), math.radians(90 - sgn * 18), 13.0, -sgn, rng))
        for pts, ws in _place(motif, (cx, cy), up):
            c.stroke(pts, ws, gold)
    else:
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        _constellation(c, (min(xs), min(ys), max(xs), max(ys)), gold, rng)
        star = []
        for kk in range(9):
            a = kk / 8 * math.tau + math.pi / 2
            rr = (W * 0.38) if kk % 2 == 0 else W * 0.1
            star.append((math.cos(a) * rr, -6.0 + math.sin(a) * rr))
        for pts, ws in _place([(star, [0.2] * len(star))], (cx, cy), up):
            c.stroke(pts, ws, gold)


def paint_hair(path, base=(0.08, 0.08, 0.13), tip=(0.21, 0.21, 0.32), shine=(0.60, 0.62, 0.80)):
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
    band = np.clip(1 - np.abs(v - edge) / 0.06, 0, 1) ** 1.4 * (0.6 + 0.4 * np.sin(u * 23.0) ** 2)
    # A second, fainter sheen lower down each lock.
    band = np.maximum(band, 0.45 * np.clip(1 - np.abs(v - (edge + 0.3)) / 0.05, 0, 1) ** 1.6
                      * (0.5 + 0.5 * np.sin(u * 17.0 + 1.3) ** 2))
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


def paint_coat(outfit, tail_uv, path, seed=11, cape_hem_uv=None):
    """tail_uv: dict with 'hem' and 'end' canvas polylines of the left back tail."""
    pal = PALETTES[outfit]
    rng = random.Random(seed)
    c = paint.Canvas(atlas.SIZE_CM, atlas.SIZE_CM, atlas.PX / atlas.SIZE_CM)
    c.fill(pal['coat'])
    c.pattern(0, 0, atlas.SIZE_CM, atlas.SIZE_CM, _grain(seed))
    gold = pal['gold']
    tone = _scale(pal['coat'], pal['damask'])
    # The ivory coat in the art is plain cloth scattered with gold-outlined stars.
    if outfit != 'starlight':
        for region in ('tail', 'side', 'torso', 'sleeve', 'cape'):
            x0, y0, w, h = atlas.REGIONS[region]
            _damask(c, (x0, y0, x0 + w, y0 + h), tone, rng, step=7.0, size=2.1)
    else:
        for region, n in (('tail', 40), ('side', 20), ('torso', 34), ('sleeve', 22), ('cape', 30)):
            x0, y0, w, h = atlas.REGIONS[region]
            _stars(c, (x0, y0, x0 + w, y0 + h), gold, rng, n, size=(0.45, 0.85))
    # Cuffs: dyed silk with a lighter damask.
    x0, y0, w, h = atlas.REGIONS['cuff']
    c.fill_rect(x0, y0, x0 + w, y0 + h, pal['cuff'])
    if outfit == 'carnival':
        c.pattern(x0, y0, x0 + w, y0 + h, _brocade(3, pal['cuff']))
    else:
        c.pattern(x0, y0, x0 + w, y0 + h, _grain(seed + 3, 0.8))
        _damask(c, (x0, y0, x0 + w, y0 + h), _scale(pal['cuff'], 1.18), rng, step=5.0, size=1.5)
    # ---- Back tails: framed band with the outfit's motif, and a fine line along the hem.
    _band(c, outfit, tail_uv['start'], tail_uv['end'], gold, rng)
    hem = [tuple(p) for p in tail_uv['hem']]
    line = filigree.offset_poly(hem, 1.2 if hem[0][0] < hem[-1][0] else -1.2)
    c.stroke(line, [0.12] * len(line), gold)
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
    # ---- Starlight half cape: a running scroll along its hem.
    if cape_hem_uv:
        hem = [tuple(p) for p in cape_hem_uv]
        if hem[0][0] > hem[-1][0]:
            hem = hem[::-1]
        for pts, ws in filigree.rinceau(hem, 3.6, 5.8, 1.2, rng, stem_w=0.15, inward=1):
            c.stroke(pts, ws, gold)
    return c.save(path, f'HeroV4-{outfit}-coat')


def _harlequin_panel(c, poly, gold):
    """Red and black diamonds in a gold lattice (carnival turnbacks)."""
    def fn(xs, ys, rgb):
        u = (xs + ys * 0.62) / 3.2
        v = (xs - ys * 0.62) / 3.2
        cell = (np.floor(u) + np.floor(v)) % 2
        red = np.array([0.62, 0.07, 0.10], np.float32)
        black = np.array([0.07, 0.05, 0.06], np.float32)
        col = np.where(cell[..., None] > 0, red, black)
        line = np.minimum(np.abs(u - np.round(u)), np.abs(v - np.round(v)))
        g = np.clip(1 - line / 0.06, 0, 1)[..., None]
        return col * (1 - g) + np.array(gold, np.float32) * g
    c.fill_poly(poly, fn)


def paint_lining(outfit, path, seed=23, turnback=None):
    """turnback: canvas outline of the left turned-back corner (for the carnival panel)."""
    pal = PALETTES[outfit]
    rng = random.Random(seed)
    c = paint.Canvas(atlas.SIZE_CM, atlas.SIZE_CM, 1024 / atlas.SIZE_CM)
    c.fill(pal['lining'])
    c.pattern(0, 0, atlas.SIZE_CM, atlas.SIZE_CM, _grain(seed, 0.8))
    _damask(c, (0, 0, atlas.SIZE_CM, atlas.SIZE_CM), pal['lining_tone'], rng, step=9.0, size=2.6)

    def sheen(xs, ys, rgb):
        # Silk catches the light in broad soft streaks, as painted in the art.
        n = paint.value_noise(xs * 0.6, ys * 0.15, 4.0, seed + 7)
        return np.clip(rgb * (0.86 + 0.32 * n)[..., None], 0, 1)
    c.pattern(0, 0, atlas.SIZE_CM, atlas.SIZE_CM, sheen)
    gold = pal['gold']
    fx0, fy0, fw, fh = atlas.REGIONS['facing']
    fold = [(fx0 + 1.6, fy0 + 93.0 - k * 0.5) for k in range(int(91 / 0.5))]
    c.stroke(fold, [0.12] * len(fold), gold)
    if outfit == 'carnival' and turnback:
        _harlequin_panel(c, turnback, gold)
    return c.save(path, f'HeroV4-{outfit}-lining')
