"""Prepare the home-screen day/night plates for CityLivingScene.

usage: prepare_plates.py <originals_dir> <out_dir>

<originals_dir> holds the four 4096 paintings (same composition):
  day.png, sunset.png, night.png, deepnight.png
Writes to <out_dir>:
  CityLiveDay.jpg ... CityLiveDeepNight.jpg   2800px plates; the painted sun
                                              (sunset) and blood moon (night,
                                              deep night) are removed so the
                                              app can move them.
  CityBloodMoon.png                           moon sprite with alpha (from night)
  skyline.json                                y of the land/sky boundary for
                                              256 columns (normalized 0..1)
  check-*.jpg                                 previews of every edit
Coordinates below are normalized to the square painting.
"""
import json
import os
import sys

import cv2
import numpy as np

SIZE = 2800
SUN = (0.7400, 0.2246, 0.0082)      # centre x, y, radius of the painted sun (sunset)
MOON = (0.7649, 0.0928, 0.0462)     # painted blood moon (night and deep night)
HORIZON = 0.2425                    # sea horizon


def load(path):
    img = cv2.imread(path, cv2.IMREAD_COLOR)
    if img is None:
        raise SystemExit("cannot read " + path)
    return img


def px(v, n):
    return int(round(v * n))


def remove_sun(img):
    n = img.shape[0]
    cx, cy, r = px(SUN[0], n), px(SUN[1], n), px(SUN[2], n)
    mask = np.zeros(img.shape[:2], np.uint8)
    cv2.circle(mask, (cx, cy), int(r * 1.75), 255, -1)
    return cv2.inpaint(img, mask, 9, cv2.INPAINT_TELEA)


def remove_moon(img, source):
    """Replace the moon and its glow with clear starry sky from `source`
    (normalized centre of a cloud-free patch), Poisson-blended in place."""
    n = img.shape[0]
    cx, cy, r = px(MOON[0], n), px(MOON[1], n), px(MOON[2], n)
    rr = int(r * 1.55)
    sx, sy = px(source[0], n), max(px(source[1], n), rr + 2)
    patch = img[sy - rr - 2:sy + rr + 2, sx - rr - 2:sx + rr + 2].copy()
    mask = np.zeros(patch.shape[:2], np.uint8)
    cv2.circle(mask, (rr + 2, rr + 2), rr, 255, -1)
    # The target patch cannot leave the image; place it as low as needed.
    ty = max(cy, rr + 2)
    return cv2.seamlessClone(patch, img, mask, (cx, ty), cv2.NORMAL_CLONE)


def moon_sprite(img):
    n = img.shape[0]
    cx, cy, r = px(MOON[0], n), px(MOON[1], n), px(MOON[2], n)
    pad = int(r * 1.05)
    crop = img[cy - pad:cy + pad, cx - pad:cx + pad].astype(np.float32)
    yy, xx = np.mgrid[-pad:pad, -pad:pad].astype(np.float32)
    d = np.sqrt(xx * xx + yy * yy)
    alpha = np.clip((r * 0.995 - d) / (r * 0.012), 0, 1)
    bgra = np.dstack([crop, alpha * 255]).astype(np.uint8)
    return cv2.resize(bgra, (512, 512), interpolation=cv2.INTER_AREA)


def skyline(sunset_clean, day):
    """Top of land per column: first y (scanning up from below the horizon)
    where the sky begins. The sunset sky is bright and warm; land and
    mountains are darker and cooler."""
    n = sunset_clean.shape[0]
    small = cv2.resize(sunset_clean, (1024, 1024), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    b, g, r = small[..., 0], small[..., 1], small[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    warm = r - b
    sky = (lum > 0.50) & (warm > 0.18)
    sky = cv2.morphologyEx(sky.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)) > 0
    top = int(0.02 * 1024)
    ys = []
    for x in range(1024):
        col = sky[:, x]
        y = int(HORIZON * 1024) + 2
        # climb while not sky
        while y > top and not col[y]:
            y -= 1
        # y is now the first sky pixel above the land
        ys.append((y + 1) / 1024)
    ys = np.array(ys)
    ys = np.minimum(ys, HORIZON)
    # Hand-traced where colour alone fails: the sunlit sugarloaf peak the sun
    # sets beside and the moon rises behind, and the clock ornament far left.
    peak = [(0.690, .2425), (0.7007, .2400), (0.7058, .2386), (0.7212, .2356), (0.7358, .2344),
            (0.7505, .2307), (0.7603, .2246), (0.7651, .2185), (0.7700, .2104), (0.7749, .2136),
            (0.7847, .2209), (0.7945, .2270), (0.8042, .2300), (0.8115, .2275), (0.8250, .2262),
            (0.8400, .2250), (0.8550, .2245), (0.8700, .2240)]
    xs = (np.arange(1024) + .5) / 1024
    px_, py_ = zip(*peak)
    inside = (xs >= peak[0][0]) & (xs <= peak[-1][0])
    ys[inside] = np.minimum(ys[inside], np.interp(xs[inside], px_, py_))
    ys[xs < 0.09] = 0.14
    # median filter to drop single-column noise, then resample to 256
    k = 7
    padded = np.pad(ys, k // 2, mode="edge")
    ys = np.array([np.median(padded[i:i + k]) for i in range(1024)])
    return [round(float(v), 4) for v in ys.reshape(256, 4).max(axis=1)]


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    day = load(os.path.join(src, "day.png"))
    sunset = load(os.path.join(src, "sunset.png"))
    night = load(os.path.join(src, "night.png"))
    deep = load(os.path.join(src, "deepnight.png"))

    sunset_c = remove_sun(sunset)
    night_c = remove_moon(night, (0.50, 0.072))
    deep_c = remove_moon(deep, (0.50, 0.072))
    moon = moon_sprite(night)
    line = skyline(sunset_c, day)

    q = [cv2.IMWRITE_JPEG_QUALITY, 92]
    for name, img in (("CityLiveDay", day), ("CityLiveSunset", sunset_c), ("CityLiveNight", night_c), ("CityLiveDeepNight", deep_c)):
        cv2.imwrite(os.path.join(out, name + ".jpg"), cv2.resize(img, (SIZE, SIZE), interpolation=cv2.INTER_AREA), q)
    cv2.imwrite(os.path.join(out, "CityBloodMoon.png"), moon)
    with open(os.path.join(out, "skyline.json"), "w") as f:
        json.dump(line, f)

    # previews
    def region(img, cx, cy, half):
        n = img.shape[0]
        x0, y0 = max(0, px(cx - half, n)), max(0, px(cy - half, n))
        return img[y0:px(cy + half, n), x0:px(cx + half, n)]
    for name, a, b, c in (("sun", sunset, sunset_c, SUN), ("moon", night, night_c, MOON), ("deepmoon", deep, deep_c, MOON)):
        ra, rb = region(a, c[0], max(c[1], 0.1), 0.1), region(b, c[0], max(c[1], 0.1), 0.1)
        cv2.imwrite(os.path.join(out, f"check-{name}.jpg"), cv2.resize(np.hstack([ra, rb]), (1200, 600)))
    prev = cv2.resize(sunset_c, (1024, 1024))
    pts = np.array([[int((i + .5) * 4), int(v * 1024)] for i, v in enumerate(line)], np.int32)
    cv2.polylines(prev, [pts], False, (0, 255, 0), 1)
    cv2.imwrite(os.path.join(out, "check-skyline.jpg"), prev[0:400])
    print("ok", out)


if __name__ == "__main__":
    main()
