"""Generate the authored textures used by SpellSpectacle20260926.

All textures are procedural and original. Run with the vfx venv:
  /tmp/mistport-vfx-encode/venv/bin/python make_textures.py <out_dir>

Outputs (RGBA PNG, straight alpha):
  SpectacleFiligree.png  1024x256  ribbon ornament, tiles along U.
                         R = bright calligraphic strokes, G = scale / cloud body,
                         B = fine sparkle, A = union coverage.
  SpectacleStar.png      1024x1024 2x2 atlas of asymmetric star flares.
  SpectacleSplash.png    1024x1024 2x2 atlas of torn radial splashes (never rings).
  SpectacleMotes.png     1024x512  4x2 atlas of particle sprites.
  SpectacleNoise.png     256x256   tileable fbm (R,G,B = three octaves mixes).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RNG = np.random.default_rng(20260926)


def tile_noise(size, scale, seed):
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((size, size))
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    radius = np.sqrt(fx * fx + fy * fy) + 1e-6
    spectrum = np.fft.fft2(white) * np.exp(-(radius * size / scale) ** 2)
    out = np.real(np.fft.ifft2(spectrum))
    out -= out.min()
    out /= out.max() + 1e-9
    return out


def fbm(size, seed):
    total = np.zeros((size, size))
    amp = 1.0
    norm = 0.0
    for octave, scale in enumerate((4, 9, 20, 44)):
        total += amp * tile_noise(size, scale, seed + octave)
        norm += amp
        amp *= 0.55
    total /= norm
    total -= total.min()
    return total / (total.max() + 1e-9)


def save(arr, path):
    arr = np.clip(arr, 0, 1)
    Image.fromarray((arr * 255 + 0.5).astype(np.uint8)).save(path)


# ---------------------------------------------------------------- filigree
def filigree(out):
    W, H, S = 1024, 256, 4
    big_w, big_h = W * S, H * S
    strokes = Image.new("L", (big_w, big_h), 0)
    body = Image.new("L", (big_w, big_h), 0)
    ds = ImageDraw.Draw(strokes)
    db = ImageDraw.Draw(body)

    def polyline(draw, pts, w0, w1, value=255):
        n = len(pts)
        for i in range(n - 1):
            t = i / max(1, n - 2)
            width = max(1, int((w0 + (w1 - w0) * t) * S))
            for shift in (-big_w, 0, big_w):
                (x0, y0), (x1, y1) = pts[i], pts[i + 1]
                draw.line([(x0 * S + shift, y0 * S), (x1 * S + shift, y1 * S)], fill=value, width=width)
                r = width / 2
                draw.ellipse([x1 * S + shift - r, y1 * S - r, x1 * S + shift + r, y1 * S + r], fill=value)

    # Cloud-scroll spirals (xiangyun) with long calligraphic tails.
    for k in range(14):
        cx = RNG.uniform(0, W)
        cy = RNG.uniform(H * 0.22, H * 0.78)
        a = RNG.uniform(5, 9)
        b = RNG.uniform(0.17, 0.24)
        turns = RNG.uniform(2.2, 3.1) * math.pi
        direction = RNG.choice([-1, 1])
        phase = RNG.uniform(0, 2 * math.pi)
        spiral = []
        for i in range(160):
            th = turns * i / 159
            r = a * math.exp(b * th)
            spiral.append((cx + direction * r * math.cos(th + phase), cy + r * math.sin(th + phase) * 0.8))
        spiral = spiral[::-1]  # thick outside -> thin inside
        polyline(ds, spiral, RNG.uniform(7, 11), 1.6)
        # tail leaves the outer end of the spiral and sweeps along U
        ex, ey = spiral[0]
        length = RNG.uniform(120, 260)
        amp = RNG.uniform(12, 30)
        tail = []
        tail_freq = RNG.uniform(1.0, 1.6)
        for i in range(120):
            t = i / 119
            tail.append((ex - direction * length * t, ey + amp * math.sin(t * math.pi * tail_freq) * (1 - t * 0.4)))
        polyline(ds, tail, RNG.uniform(6, 9), 0.8)
        # filled cloud lobe behind the spiral
        lobe_r = a * math.exp(b * turns) * 1.05
        for shift in (-big_w, 0, big_w):
            db.ellipse([(cx - lobe_r) * S + shift, (cy - lobe_r * 0.8) * S, (cx + lobe_r) * S + shift, (cy + lobe_r * 0.8) * S], fill=150)

    # Long flowing strands (the gold calligraphy swirls of the reference).
    for k in range(9):
        y0 = RNG.uniform(H * 0.1, H * 0.9)
        amp = RNG.uniform(10, 40)
        freq = RNG.uniform(1, 3)  # integer-ish periods keep tiling seamless enough with wrap draw
        phase = RNG.uniform(0, 2 * math.pi)
        start = RNG.uniform(0, W)
        length = RNG.uniform(260, 520)
        pts = []
        for i in range(220):
            t = i / 219
            x = start + length * t
            y = y0 + amp * math.sin(phase + t * freq * math.pi * 2) + 7 * math.sin(t * 4.3 + phase * 1.7)
            pts.append((x % W if False else x, y))
        polyline(ds, pts, RNG.uniform(2, 5), RNG.uniform(0.6, 2))

    # Irregular dragon scales in the middle band (jittered, not equidistant).
    for i in range(170):
        x = RNG.uniform(0, W)
        y = RNG.normal(H * 0.5, H * 0.16)
        r = RNG.uniform(9, 22)
        start = RNG.uniform(180, 220)
        for shift in (-big_w, 0, big_w):
            box = [(x - r) * S + shift, (y - r) * S, (x + r) * S + shift, (y + r) * S]
            db.pieslice(box, start, start + RNG.uniform(130, 170), fill=int(RNG.uniform(60, 120)))
            ds.arc(box, start, start + RNG.uniform(120, 170), fill=int(RNG.uniform(120, 200)), width=int(RNG.uniform(1.2, 2.6) * S))

    strokes = strokes.resize((W, H), Image.LANCZOS)
    body = body.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(2.5))
    r = np.asarray(strokes, np.float64) / 255
    g = np.asarray(body, np.float64) / 255
    g = np.clip(g * 1.25, 0, 1)
    sparkle = RNG.random((H, W))
    sparkle = (sparkle > 0.996).astype(np.float64)
    sparkle = np.asarray(Image.fromarray((sparkle * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1)), np.float64) / 255
    sparkle = np.clip(sparkle * 6, 0, 1)
    a = np.clip(np.maximum(r, g * 0.8) + sparkle * 0.5, 0, 1)
    save(np.dstack([r, g, sparkle, a]), os.path.join(out, "SpectacleFiligree.png"))


# ---------------------------------------------------------------- stars
def star_cell(size, seed):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    dx, dy = (x - cx) / (size / 2), (y - cy) / (size / 2)
    rr = np.sqrt(dx * dx + dy * dy) + 1e-6
    ang = np.arctan2(dy, dx)
    img = np.zeros((size, size))
    arms = rng.integers(4, 7)
    base = rng.uniform(0, math.pi)
    for i in range(arms):
        a0 = base + i * 2 * math.pi / arms + rng.uniform(-0.28, 0.28)
        length = rng.uniform(0.45, 0.98) if i % 2 else rng.uniform(0.75, 0.99)
        width = rng.uniform(0.035, 0.08)
        d = np.angle(np.exp(1j * (ang - a0)))
        taper = np.clip(1 - rr / length, 0, 1)
        ray = np.exp(-(d / (width * (0.25 + taper))) ** 2) * taper ** 1.4
        img = np.maximum(img, ray)
    # minor glints between arms
    for i in range(arms * 2):
        a0 = rng.uniform(0, 2 * math.pi)
        length = rng.uniform(0.18, 0.4)
        d = np.angle(np.exp(1j * (ang - a0)))
        taper = np.clip(1 - rr / length, 0, 1)
        img = np.maximum(img, 0.55 * np.exp(-(d / 0.03) ** 2) * taper ** 2)
    core = np.exp(-(rr / 0.09) ** 2)
    halo = np.exp(-(rr / 0.34) ** 2) * 0.45
    img = np.clip(img + core + halo, 0, 1)
    return img


def stars(out):
    size = 512
    atlas = np.zeros((1024, 1024))
    for i in range(4):
        cell = star_cell(size, 100 + i)
        yy, xx = divmod(i, 2)
        atlas[yy * size:(yy + 1) * size, xx * size:(xx + 1) * size] = cell
    white = np.ones_like(atlas)
    save(np.dstack([white, white, white, atlas]), os.path.join(out, "SpectacleStar.png"))


# ---------------------------------------------------------------- splash
def splash_cell(size, seed):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    dx, dy = (x - cx) / (size / 2), (y - cy) / (size / 2)
    rr = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    # radial reach varies with angle: several irregular petals + ragged tips
    reach = np.full_like(rr, 0.35)
    petals = rng.integers(6, 11)
    for i in range(petals):
        a0 = rng.uniform(0, 2 * math.pi)
        length = rng.uniform(0.5, 0.97)
        width = rng.uniform(0.12, 0.32)
        d = np.angle(np.exp(1j * (ang - a0)))
        reach = np.maximum(reach, 0.3 + (length - 0.3) * np.exp(-(d / width) ** 2))
    n = tile_noise(size, 30, seed + 7)
    reach *= 0.86 + 0.28 * n
    body = np.clip((reach - rr) / 0.06, 0, 1)
    # hollow, uneven interior: a torn shock, not a ring
    inner = 0.18 + 0.2 * tile_noise(size, 12, seed + 3)
    hollow = np.clip((rr - inner) / 0.16, 0, 1)
    # streak texture within petals
    streak = 0.55 + 0.45 * np.cos(ang * rng.integers(17, 29) + 6 * n)
    img = body * (0.25 + 0.75 * hollow) * (0.6 + 0.4 * streak)
    edge = np.exp(-((reach - rr) / 0.05) ** 2) * body
    img = np.clip(img + edge * 0.6, 0, 1)
    return img


def splashes(out):
    size = 512
    atlas = np.zeros((1024, 1024))
    for i in range(4):
        yy, xx = divmod(i, 2)
        atlas[yy * size:(yy + 1) * size, xx * size:(xx + 1) * size] = splash_cell(size, 300 + i * 11)
    white = np.ones_like(atlas)
    save(np.dstack([white, white, white, atlas]), os.path.join(out, "SpectacleSplash.png"))


# ---------------------------------------------------------------- motes
def motes(out):
    cw = 256
    atlas = np.zeros((512, 1024))
    y, x = np.mgrid[0:cw, 0:cw]
    u, v = (x - cw / 2 + 0.5) / (cw / 2), (y - cw / 2 + 0.5) / (cw / 2)
    rr = np.sqrt(u * u + v * v)
    cells = []
    # 0 spark streak (stretched along u)
    cells.append(np.exp(-(v / 0.07) ** 2) * np.clip(1 - np.abs(u), 0, 1) ** 1.5 + np.exp(-(rr / 0.12) ** 2))
    # 1 ember blob with flicker lobes
    ang = np.arctan2(v, u)
    lobes = 0.55 + 0.12 * np.sin(ang * 5 + 1) + 0.08 * np.sin(ang * 9)
    cells.append(np.clip((lobes - rr) / 0.25, 0, 1) ** 1.3)
    # 2 angular shard
    shard = Image.new("L", (cw * 4, cw * 4), 0)
    d = ImageDraw.Draw(shard)
    d.polygon([(cw * 2, 40), (cw * 2.9, cw * 1.7), (cw * 2.3, cw * 3.9), (cw * 1.35, cw * 2.3)], fill=255)
    shard = np.asarray(shard.resize((cw, cw), Image.LANCZOS), np.float64) / 255
    shard = shard * (0.55 + 0.45 * np.clip((u + 0.2) * 1.5, 0, 1))
    cells.append(shard)
    # 3 ink droplet with tail
    drop = np.clip((0.42 - np.sqrt(u * u + ((v - 0.25) / 1.0) ** 2)) / 0.06, 0, 1)
    tail = np.exp(-(u / (0.05 + 0.18 * np.clip(v + 0.9, 0, 1))) ** 2) * np.clip((v + 0.95) / 1.1, 0, 1) * (v < 0.3)
    cells.append(np.clip(drop + tail * 0.9, 0, 1))
    # 4 petal
    petal = np.clip((0.9 - np.sqrt((u / 0.42) ** 2 + (v / 0.9) ** 2) - 0.1 * np.abs(u) * 0) / 0.12, 0, 1)
    vein = 1 - 0.35 * np.exp(-(u / 0.03) ** 2)
    cells.append(petal * vein * (0.7 + 0.3 * (1 - np.abs(v))))
    # 5 card sliver (tarot fragment, slight tear)
    card = ((np.abs(u) < 0.36) & (np.abs(v) < 0.62)).astype(np.float64)
    card *= 0.6 + 0.4 * ((np.abs(u) > 0.28) | (np.abs(v) > 0.54))
    tear = tile_noise(cw, 10, 91)
    card *= (tear > 0.28)
    cells.append(np.asarray(Image.fromarray((card * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.4)), np.float64) / 255)
    # 6 feather / wisp
    wisp = np.exp(-((v - 0.35 * np.sin(u * 2.5)) / (0.06 + 0.12 * (1 - np.abs(u)))) ** 2) * np.clip(1 - np.abs(u), 0, 1)
    cells.append(wisp)
    # 7 soft smoke puff
    puff = np.clip(1 - rr, 0, 1) ** 2 * (0.6 + 0.4 * tile_noise(cw, 8, 57))
    cells.append(puff)
    for i, cell in enumerate(cells):
        yy, xx = divmod(i, 4)
        atlas[yy * cw:(yy + 1) * cw, xx * cw:(xx + 1) * cw] = np.clip(cell, 0, 1)
    white = np.ones_like(atlas)
    save(np.dstack([white, white, white, atlas]), os.path.join(out, "SpectacleMotes.png"))


def noise(out):
    a = fbm(256, 11)
    b = fbm(256, 23)
    c = tile_noise(256, 60, 37)
    save(np.dstack([a, b, c, np.ones_like(a)]), os.path.join(out, "SpectacleNoise.png"))


def atlas(out):
    """Pack stars, splashes and motes into one 2048 atlas so every billboard
    in a hit cluster draws with one material.
      stars   : x 0..1024,    y 0..1024    (2x2 cells of 512)
      splashes: x 1024..2048, y 0..1024    (2x2 cells of 512)
      motes   : x 0..1024,    y 1024..1536 (4x2 cells of 256)
      glints  : x 0..512,     y 1536..1792 (motes 8 and 9, see glints.py)
    y is measured from the image top."""
    from glints import paste_glints
    sheet = Image.new("RGBA", (2048, 2048), (255, 255, 255, 0))
    sheet.paste(Image.open(os.path.join(out, "SpectacleStar.png")), (0, 0))
    sheet.paste(Image.open(os.path.join(out, "SpectacleSplash.png")), (1024, 0))
    sheet.paste(Image.open(os.path.join(out, "SpectacleMotes.png")), (0, 1024))
    paste_glints(sheet)
    sheet.save(os.path.join(out, "SpectacleAtlas.png"))


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    filigree(out)
    stars(out)
    splashes(out)
    motes(out)
    noise(out)
    atlas(out)
    print("ok", out)
