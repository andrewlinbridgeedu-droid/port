"""Cloud and rain textures for the home harbour (all procedural).

usage: make_weather_textures.py <out_dir> [<day_plate.jpg> <skyline.txt>]

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


def storm_sky(day_path, skyline_path, out):
    """The painting's own clouds, turned into a storm sky.

    From the day painting's sky: blue sky becomes the dark body of the storm
    cloud, the painted white clouds become its lighter billows, so the storm
    keeps the painting's brushwork. Alpha covers the sky above the skyline
    (256-column trace), feathered, fading out a little below it.
    """
    import ast
    day = cv2.imread(day_path).astype(np.float32) / 255
    H, W = day.shape[:2]
    band = int(0.30 * H)
    sky = day[:band]
    hsv = cv2.cvtColor((sky * 255).astype(np.uint8), cv2.COLOR_BGR2HSV).astype(np.float32) / 255
    lum = 0.114 * sky[..., 0] + 0.587 * sky[..., 1] + 0.299 * sky[..., 2]
    white = smoothstep(0.35, 0.05, hsv[..., 1]) * smoothstep(0.45, 0.85, lum)
    white = cv2.GaussianBlur(white, (0, 0), 2)
    shade = cv2.GaussianBlur(lum, (0, 0), 1.2)
    dark = np.array([0.30, 0.27, 0.25], np.float32)        # BGR: slate
    light = np.array([0.66, 0.64, 0.62], np.float32)
    col = dark + (light - dark) * (0.25 * shade[..., None] + 0.75 * white[..., None])
    # darker toward the top of the sky, like the underside of a heavy deck
    y = np.arange(band, dtype=np.float32)[:, None] / H
    col *= (0.78 + 0.35 * np.clip(y / 0.25, 0, 1))[..., None]
    line = np.array(ast.literal_eval(open(skyline_path).read()))
    sky_y = np.interp(np.arange(W), (np.arange(len(line)) + 0.5) / len(line) * W, line * H)
    rows = np.arange(band, dtype=np.float32)[:, None]
    alpha = np.clip((sky_y[None, :] + 0.012 * H - rows) / (0.02 * H), 0, 1)
    # Leave out what is not sky or cloud (the blossom branch in the corner):
    # sky is blue, clouds are pale; branches and blossom are neither.
    hue, sat = hsv[..., 0] * 255, hsv[..., 1]          # OpenCV 8-bit hue runs 0..179
    skyish = ((hue > 88) & (hue < 128) & (sat > 0.18)) | ((sat < 0.22) & (lum > 0.55))
    keep = cv2.morphologyEx(skyish.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    keep = cv2.erode(keep, np.ones((5, 5), np.uint8))
    alpha *= cv2.GaussianBlur(keep.astype(np.float32), (0, 0), 2.5)
    rgba = np.dstack([np.clip(col, 0, 1), alpha])
    small = cv2.resize(rgba, (2048, int(2048 * band / W)), interpolation=cv2.INTER_AREA)
    cv2.imwrite(f"{out}/CityStormSky.png", (small * 255 + 0.5).astype(np.uint8))


def main(out, day_path=None, skyline_path=None):
    os.makedirs(out, exist_ok=True)
    if day_path:
        storm_sky(day_path, skyline_path, out)
    H, W = 640, 2048
    # Storm cloud: dense over the top of the band, ragged toward the bottom.
    storm = clouds(H, W, 11, 0.78, np.array([0.30, 0.32, 0.37]), np.array([0.62, 0.64, 0.70]),
                   np.array([0.40, 0.41, 0.46]), lambda y: 1.25 - 0.9 * y ** 1.5)
    cv2.imwrite(f"{out}/CityCloudStorm.png", storm)
    night = clouds(H, W, 23, 0.52, np.array([0.10, 0.11, 0.16]), np.array([0.21, 0.22, 0.29]),
                   np.array([0.27, 0.23, 0.25]), lambda y: 1.1 - 0.5 * y)
    cv2.imwrite(f"{out}/CityCloudNight.png", night)
    cv2.imwrite(f"{out}/CityRainFar.png", rain(512, 512, 900, 26, 1, 0.3, 0.55, 31))
    cv2.imwrite(f"{out}/CityRainMid.png", rain(512, 512, 320, 48, 1.6, 0.5, 0.65, 32))
    cv2.imwrite(f"{out}/CityRainNear.png", rain(512, 512, 70, 110, 3, 1.4, 0.55, 33))
    # previews on a dark sky
    for name in ["CityCloudStorm", "CityCloudNight", "CityRainFar", "CityRainMid", "CityRainNear"] + \
            (["CityStormSky"] if day_path else []):
        img = cv2.imread(f"{out}/{name}.png", cv2.IMREAD_UNCHANGED).astype(np.float32) / 255
        bg = np.ones_like(img[..., :3]) * np.array([0.55, 0.45, 0.35], np.float32)
        comp = bg * (1 - img[..., 3:]) + img[..., :3] * img[..., 3:]
        cv2.imwrite(f"{out}/preview-{name}.jpg", (comp * 255).astype(np.uint8))


if __name__ == "__main__":
    main(*sys.argv[1:4])
