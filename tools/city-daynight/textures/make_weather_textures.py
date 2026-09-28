"""Cloud and rain textures for the home harbour (all procedural).

usage: make_weather_textures.py <out_dir> [<plates_dir> <skyline.txt>]

Clouds (tileable left-right, RGBA, 2048×640):
  CityCloudStorm   dense rain/storm cloud: ragged, billowing, dark bases,
                   lighter tops; nearly covers the band
  CityCloudNight   broken night cloud: dark blue-grey, undersides warmed by
                   the town's lamps; gaps show the sky and the moon
Rain (tileable both ways, RGBA, white streaks on transparent):
  CityRainFar      many fine short streaks
  CityRainMid      medium streaks
  CityRainNear     few long, thick, soft streaks
Every streak tapers from a faint tail to a brighter head, like a falling drop
caught by the camera, instead of a hard line of even width.
"""
import os
import sys

import cv2
import numpy as np

rng = np.random.default_rng(20260928)


def periodic_noise(h, w, beta, seed, stretch=1.0):
    """Tileable fractal noise (1/f^beta spectrum), normalised to 0..1.
    stretch > 1 makes features wider than tall (cloud banks)."""
    r = np.random.default_rng(seed)
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt((fx * stretch) ** 2 + fy ** 2)
    f[0, 0] = 1
    spec = (r.standard_normal((h, w)) + 1j * r.standard_normal((h, w))) / f ** (beta / 2)
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min())


def warp(field, dx, dy):
    h, w = field.shape
    xs, ys = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return cv2.remap(field.astype(np.float32), xs + dx.astype(np.float32), ys + dy.astype(np.float32),
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def shift_down(a, k):
    """a[y - k] without wrapping (edge rows repeat)."""
    return np.concatenate([np.repeat(a[:1], k, axis=0), a[:-k]], axis=0)


def clouds(h, w, seed, coverage, base_dark, top_light, under_light, profile):
    n = periodic_noise(h, w, 3.1, seed, 2.2)
    wx = (periodic_noise(h, w, 3.4, seed + 1, 1.5) - 0.5) * 140
    wy = (periodic_noise(h, w, 3.4, seed + 2, 1.5) - 0.5) * 50
    d = warp(n, wx, wy)
    d = 0.85 * d + 0.15 * periodic_noise(h, w, 2.4, seed + 3, 1.6)     # a little finer detail
    d = (d - d.min()) / (d.max() - d.min())
    y = np.arange(h, dtype=np.float32)[:, None] / h
    d = d * profile(y)
    alpha = smoothstep(1 - coverage - 0.16, 1 - coverage + 0.10, d)
    # Billows: lit where the cloud begins going down (tops), dark bases, and
    # undersides that pick up light from below. Measured on a smoothed
    # density so the shading is soft, not speckled.
    ds = cv2.GaussianBlur(d.astype(np.float32), (0, 0), 5)
    k = 14
    top = smoothstep(0.0, 0.10, ds - shift_down(ds, k))
    bottom = smoothstep(0.0, 0.10, ds - np.concatenate([ds[k:], np.repeat(ds[-1:], k, axis=0)], axis=0))
    thick = smoothstep(0.35, 0.95, ds)
    col = base_dark[None, None, :] * (0.55 + 0.45 * (1 - thick))[..., None]
    col = col + (top_light - base_dark)[None, None, :] * top[..., None]
    col = col + (under_light - base_dark)[None, None, :] * (bottom * (1 - top))[..., None] * 0.8
    col = cv2.GaussianBlur(col.astype(np.float32), (0, 0), 1.5)
    alpha = cv2.GaussianBlur(alpha.astype(np.float32), (0, 0), 2.0)
    rgba = np.dstack([np.clip(col[..., ::-1], 0, 1), alpha])
    return (rgba * 255 + 0.5).astype(np.uint8)


def rain(h, w, count, length, width, blur, alpha, seed):
    r = np.random.default_rng(seed)
    big = np.zeros((h * 3, w * 3), np.float32)
    for _ in range(count):
        x, y = r.uniform(0, w), r.uniform(0, h)
        L = length * r.uniform(0.55, 1.3)
        wd = max(1, int(round(width * r.uniform(0.7, 1.3))))
        a = alpha * r.uniform(0.45, 1.0)
        steps = max(4, int(L / 3))
        for i in range(steps):
            u0, u1 = i / steps, (i + 1) / steps
            # tail (top, u = 0) faint and thin, head (bottom) brighter
            c = a * (0.08 + 0.92 * u1 ** 1.6)
            for ox in (0, w, 2 * w):
                for oy in (0, h, 2 * h):
                    cv2.line(big, (int(x + ox), int(y + oy + L * u0)), (int(x + ox), int(y + oy + L * u1)),
                             float(c), wd, cv2.LINE_AA)
    if blur > 0:
        big = cv2.GaussianBlur(big, (0, 0), blur)
    tile = big[h:2 * h, w:2 * w]              # every streak was drawn in all nine copies
    tile = np.clip(tile, 0, 1)
    rgb = np.ones((h, w, 3), np.float32) * np.array([1.0, 0.98, 0.96], np.float32)   # BGR, faintly cool
    return (np.dstack([rgb, tile]) * 255 + 0.5).astype(np.uint8)


def sky_band(day_path, skyline_path, band_frac=0.30):
    """Sky pixels of a day painting above the (padded) skyline.

    Returns the band (BGR 0..1), a soft sky alpha, and the height H.
    Sky is blue or cloud-white; the bell tower's pale stone, the blossom
    branch and the mountains are neither, so they stay out.
    """
    import ast
    day = cv2.imread(day_path).astype(np.float32) / 255
    H, W = day.shape[:2]
    band = int(band_frac * H)
    sky = day[:band]
    hsv = cv2.cvtColor((sky * 255).astype(np.uint8), cv2.COLOR_BGR2HSV).astype(np.float32)
    hue, sat, val = hsv[..., 0], hsv[..., 1] / 255, hsv[..., 2] / 255
    blue = (hue > 95) & (hue < 128) & (sat > 0.20) & (val > 0.35)
    cloud = (sat < 0.16) & (val > 0.72)
    skyish = blue | cloud
    line = np.array(ast.literal_eval(open(skyline_path).read()))
    sky_y = np.interp(np.arange(W), (np.arange(len(line)) + 0.5) / len(line) * W, line * H)
    # a little below the traced line; beside the bell tower, where the trace
    # hugs the spire loosely, the sky colour alone decides
    k = int(0.02 * H)
    padded = sky_y.copy()
    for i in range(int(0.44 * H), int(0.58 * H)):
        padded[i] = sky_y[max(0, i - k):i + k + 1].max()
    rows = np.arange(band, dtype=np.float32)[:, None]
    above = rows < padded[None, :] + 0.005 * H
    # Above the traced skyline everything is sky (painted clouds included),
    # except where something solid stands in it: the bell tower and the
    # blossom branch in the top-left corner. Only there does colour decide.
    xs = np.arange(W, dtype=np.float32)[None, :] / H
    ys = rows / H
    tower_zone = (xs > 0.44) & (xs < 0.58)
    corner_zone = (xs < 0.46) & (ys < 0.17)
    # The tower is warm stone and gold with dark openings; the branch is dark
    # bark and pink blossom. Cloud edges are pale blue-grey: neither.
    tower_solid = (((hue < 40) | (hue > 160)) & (sat > 0.10)) | (val < 0.45)
    corner_solid = (val < 0.55) | ((hue > 140) & (hue < 178) & (sat > 0.12))
    notsky = (above & ((tower_zone & tower_solid) | (corner_zone & corner_solid))).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(notsky, 8)
    tiny = np.zeros(count, bool)
    tiny[1:] = stats[1:, cv2.CC_STAT_AREA] < (0.004 * H) ** 2
    notsky[tiny[labels]] = 0
    # Close the tower's own gaps (glazing highlights in the dome).
    notsky = cv2.morphologyEx(notsky, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
    mask = (above & (notsky == 0)).astype(np.uint8)
    alpha = cv2.GaussianBlur(mask.astype(np.float32), (0, 0), 1.2)
    return sky, alpha, H, W


def sky_mask(day_path, skyline_path, out, name):
    """Where the sky is (alpha), 2048 wide, for clipping drawn weather."""
    _, alpha, H, W = sky_band(day_path, skyline_path)
    small = cv2.resize(alpha, (2048, int(2048 * alpha.shape[0] / W)), interpolation=cv2.INTER_AREA)
    rgba = np.dstack([np.ones_like(small), np.ones_like(small), np.ones_like(small), small])
    cv2.imwrite(f"{out}/{name}.png", (rgba * 255 + 0.5).astype(np.uint8))


# Where distant land ends and the near town begins, traced by the user on
# the phone (2026-09-28): under cloud or rain the far mountains, islands
# and sea horizon above this line fade into the cloud; below it nothing is
# touched. Painting units (x across, y down).
FAR_LINE = [(0.0, 0.145), (0.183, 0.150), (0.272, 0.178), (0.371, 0.218), (0.470, 0.231), (0.569, 0.221),
            (0.733, 0.208), (0.782, 0.153), (0.866, 0.158), (0.945, 0.203), (1.054, 0.168), (1.178, 0.215),
            (1.371, 0.203), (1.480, 0.213), (1.534, 0.251), (1.569, 0.260), (1.592, 0.254), (1.604, 0.220),
            (1.622, 0.206), (1.667, 0.208), (1.725, 0.220), (1.777, 0.238)]


def far_mask(day_path, lights_path, skyline_path, out, name):
    """How much of the cloud reaches down over the distant land: 0.85 at the
    skyline fading smoothly to 0 at FAR_LINE. Warm stone (the bell tower,
    the castle, the lighthouse) and every lamp and lit window stay clear."""
    import ast
    day = cv2.imread(day_path)
    H, W = day.shape[:2]
    band = int(0.30 * H)
    line = np.array(ast.literal_eval(open(skyline_path).read()))
    sky_y = np.interp(np.arange(W), (np.arange(len(line)) + 0.5) / len(line) * W, line * H)
    far_y = np.interp(np.arange(W) / H, [p[0] for p in FAR_LINE], [p[1] for p in FAR_LINE]) * H
    rows = np.arange(band, dtype=np.float32)[:, None]
    depth = np.maximum(far_y - sky_y, 1)[None, :]
    t = np.clip((rows - sky_y[None, :]) / depth, 0, 1)
    alpha = 0.85 * (1 - smoothstep(0, 1, t))
    alpha[(rows < sky_y[None, :]) | (far_y[None, :] <= sky_y[None, :] + 2)] = 0
    hsv = cv2.cvtColor(day[:band], cv2.COLOR_BGR2HSV).astype(np.float32)
    hue, sat, val = hsv[..., 0], hsv[..., 1] / 255, hsv[..., 2] / 255
    stone = ((hue < 32) | (hue > 165)) & (sat > 0.08) & (val > 0.55)
    lights = cv2.imread(lights_path, cv2.IMREAD_GRAYSCALE)[:band].astype(np.float32) / 255
    keep = (stone | (lights > 0.06)).astype(np.uint8)
    keep = cv2.morphologyEx(keep, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    keep = cv2.dilate(keep, np.ones((5, 5), np.uint8))
    alpha *= 1 - cv2.GaussianBlur(keep.astype(np.float32), (0, 0), 2.0)
    alpha = cv2.GaussianBlur(alpha, (0, 0), 1.5)
    small = cv2.resize(alpha, (2048, int(2048 * band / W)), interpolation=cv2.INTER_AREA)
    rgba = np.dstack([np.ones_like(small), np.ones_like(small), np.ones_like(small), small])
    cv2.imwrite(f"{out}/{name}.png", (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8))


def storm_clouds(day_path, skyline_path, out):
    """The painting's own clouds as a grey storm deck (tileable left-right).

    Everything that is not sky (tower, mountains, branch) is filled in from
    the surrounding sky, blue becomes the dark body of the cloud and the
    painted white clouds its lighter billows, then the band is mirrored so it
    tiles seamlessly as it drifts.
    """
    sky, alpha, H, W = sky_band(day_path, skyline_path)
    # Only the clean open sky: above the mountains, right of the bell tower
    # and clear of the blossom branch. The few small holes (spires, the
    # castle dome) are filled in from around them.
    top = int(0.125 * H)
    x0 = int(0.60 * H)
    src = sky[:top, x0:]
    holes = (alpha[:top, x0:] < 0.5).astype(np.uint8) * 255
    filled = cv2.inpaint((src * 255).astype(np.uint8), holes, 9, cv2.INPAINT_TELEA).astype(np.float32) / 255
    hsv = cv2.cvtColor((filled * 255).astype(np.uint8), cv2.COLOR_BGR2HSV).astype(np.float32) / 255
    lum = 0.114 * filled[..., 0] + 0.587 * filled[..., 1] + 0.299 * filled[..., 2]
    white = smoothstep(0.30, 0.06, hsv[..., 1]) * smoothstep(0.50, 0.88, lum)
    white = cv2.GaussianBlur(white, (0, 0), 1.5)
    shade = cv2.GaussianBlur(lum, (0, 0), 1.0)
    dark = np.array([0.33, 0.30, 0.28], np.float32)        # BGR: slate
    light = np.array([0.70, 0.68, 0.66], np.float32)
    col = dark + (light - dark) * (0.30 * shade[..., None] + 0.70 * white[..., None])
    # Below the painted clouds the deck thins into rain haze toward the horizon.
    deck_h = int(0.30 * H)
    haze = col[-8:].mean(axis=(0, 1)) * 1.12
    deck = np.empty((deck_h, col.shape[1], 3), np.float32)
    deck[:top] = col
    deck[top:] = haze
    y = np.arange(deck_h, dtype=np.float32)[:, None] / H
    edge = np.concatenate([col, np.repeat(col[-1:], deck_h - top, axis=0)], axis=0)
    blend = smoothstep(0.085, 0.135, y)[..., None]
    deck = edge * (1 - blend) + haze * blend
    deck *= (0.82 + 0.26 * np.clip(y / 0.25, 0, 1))[..., None]
    # Seamless left-right: the last quarter fades into the first.
    n = deck.shape[1]
    q = n // 4
    ramp = np.linspace(0, 1, q, dtype=np.float32)[None, :, None]
    tile = deck[:, :n - q].copy()
    tile[:, :q] = deck[:, :q] * ramp + deck[:, n - q:] * (1 - ramp)
    width_px = int(round(4096 * tile.shape[1] / W))
    small = cv2.resize(np.clip(tile, 0, 1), (width_px, int(width_px * deck_h / tile.shape[1])), interpolation=cv2.INTER_AREA)
    cv2.imwrite(f"{out}/CityStormClouds.jpg", (small * 255 + 0.5).astype(np.uint8), [cv2.IMWRITE_JPEG_QUALITY, 90])


def main(out, plates_dir=None, skyline_path=None):
    """With a plates directory (CitySpringDay.jpg …): the sky masks per set and
    the storm clouds from spring; always the rain textures."""
    os.makedirs(out, exist_ok=True)
    if plates_dir:
        storm_clouds(f"{plates_dir}/CitySpringDay.jpg", skyline_path, out)
        for prefix in ["CitySpring", "CitySummer", "CityAutumn", "CityWinter", "CityWinterSnow"]:
            sky_mask(f"{plates_dir}/{prefix}Day.jpg", skyline_path, out, prefix + "SkyMask")
            far_mask(f"{plates_dir}/{prefix}Day.jpg", f"{plates_dir}/{prefix}Lights.jpg", skyline_path, out,
                     prefix + "FarMask")
    cv2.imwrite(f"{out}/CityRainFar.png", rain(512, 512, 700, 30, 1, 0.3, 0.55, 31))
    cv2.imwrite(f"{out}/CityRainMid.png", rain(512, 512, 260, 56, 1.6, 0.5, 0.65, 32))
    cv2.imwrite(f"{out}/CityRainNear.png", rain(512, 512, 60, 120, 3, 1.4, 0.55, 33))


if __name__ == "__main__":
    main(*sys.argv[1:4])
