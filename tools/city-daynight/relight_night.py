"""Make a night plate read as night: dark streets, light only near lamps.

usage: relight_night.py <plate_in> <glow_reference> <plate_out> <level> [preview]

Generated night paintings often keep the daytime brightness of the
foreground: pale stone stairs lit evenly, dappled "sun" patches under the
trees. This darkens the lower half of the picture (stairs, plaza,
balustrades, planters, near foliage) to <level> of its brightness, flattens
dapple highlights, and puts a warm pool of light around every lamp and lit
window. Lamps and lit windows are found in <glow_reference> (the fully lit
painting of the same moment: amber hue, saturated, bright, with a bright
core) and keep their own brightness. The distant city is darkened a little;
the sky not at all.
"""
import sys

import cv2
import numpy as np


def lum(im):
    return 0.114 * im[..., 0] + 0.587 * im[..., 1] + 0.299 * im[..., 2]


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# The lower staircase floor (same in every season: the paintings share one
# composition). No lamp stands here, so any bright patch is painted "sun"
# dapple and is flattened, never kept as a light.
FLOOR = [(0.14, 1.0), (0.27, 0.80), (0.45, 0.77), (0.47, 0.745), (0.70, 0.745), (0.73, 0.80), (0.86, 1.0)]


def floor_mask(N, soft):
    m = np.zeros((N, N), np.uint8)
    cv2.fillPoly(m, [np.array([[int(x * N), int(y * N)] for x, y in FLOOR], np.int32)], 1)
    return cv2.GaussianBlur(m.astype(np.float32), (0, 0), soft)


def glow_sources(ref, rows):
    """Lamp heads and lit windows: amber, saturated, bright, with a very bright core."""
    L = lum(ref)
    hsv = cv2.cvtColor((np.clip(ref, 0, 1) * 255).astype(np.uint8), cv2.COLOR_BGR2HSV_FULL).astype(np.float32)
    H, S = hsv[..., 0] * 360 / 256, hsv[..., 1] / 255
    glow = ((H > 18) & (H < 58) & (S > 0.45) & (L > 0.50) & (rows > 0.245)).astype(np.uint8)
    glow = cv2.morphologyEx(glow, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(glow)
    peak = np.zeros(n, np.float32)
    np.maximum.at(peak, lab.ravel(), L.ravel())
    keep = peak > 0.80
    keep[0] = False
    return keep[lab].astype(np.float32), L


def main():
    src, ref_path, dst, level = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
    preview = sys.argv[5] if len(sys.argv) > 5 else None
    img = cv2.imread(src).astype(np.float32) / 255
    N = img.shape[0]
    ref = cv2.imread(ref_path)
    ref = cv2.resize(ref, (N, N), interpolation=cv2.INTER_AREA if ref.shape[0] >= N else cv2.INTER_LANCZOS4).astype(np.float32) / 255
    s = N / 2048
    rows = (np.arange(N)[:, None] + 0.5) / N * np.ones((1, N))

    sources, ref_L = glow_sources(ref, rows)
    floor = floor_mask(N, 6 * s)
    sources = sources * (floor < 0.5)
    protect = np.clip(cv2.GaussianBlur(cv2.dilate(sources, np.ones((5, 5), np.uint8)), (0, 0), 1.5 * s) * 1.6, 0, 1)
    # Light thrown by each source: a wide soft pool plus a brighter near halo.
    emit = sources * ref_L
    wide = cv2.GaussianBlur(emit, (0, 0), 45 * s)
    close = cv2.GaussianBlur(emit, (0, 0), 14 * s)
    pool = np.clip(wide / max(np.percentile(wide, 99.5), 1e-6), 0, 1) * 0.65 \
        + np.clip(close / max(np.percentile(close, 99.7), 1e-6), 0, 1) * 0.6
    pool = np.clip(pool, 0, 1)

    # How dark: full strength in the foreground, a little in the far city.
    fg = smoothstep(0.40, 0.58, rows)
    city = smoothstep(0.245, 0.30, rows) * (1 - fg)
    target = 1 - (1 - level) * fg - (1 - level) * 0.30 * city
    factor = target + (1 - target) * pool * 0.9
    factor = factor + (1 - factor) * protect

    # Flatten dappled highlights toward the local average (not inside pools).
    L = lum(img)
    base = cv2.GaussianBlur(L, (0, 0), 22 * s)
    knee = base * 1.08
    over = np.clip(L - knee, 0, None)
    flat_w = np.maximum(fg * (1 - pool) * (1 - protect) * 0.7, floor)
    flat = L - over * flat_w
    ratio = (flat + 1e-4) / (L + 1e-4)

    out = img * (ratio * factor)[..., None]
    # Unlit stone takes on cool night air; pools stay warm.
    cool = (fg * (1 - pool) * (1 - protect) * 0.3)[..., None]
    out = out * (1 - cool) + out * np.array([1.14, 1.0, 0.84], np.float32) * cool
    warm = (fg * pool * (1 - protect) * 0.25)[..., None]
    out = out * (1 - warm) + out * np.array([0.82, 0.98, 1.16], np.float32) * warm
    out = np.clip(out, 0, 1)
    cv2.imwrite(dst, (out * 255).astype(np.uint8), [cv2.IMWRITE_JPEG_QUALITY, 92])
    if preview:
        y0 = int(0.40 * N)
        both = np.hstack([img[y0:], out[y0:]])
        cv2.imwrite(preview, cv2.resize((both * 255).astype(np.uint8), (1400, int(1400 * both.shape[0] / both.shape[1]))))
    print("sources %.4f of pixels -> %s" % (float(sources.mean()), dst))


if __name__ == "__main__":
    main()
