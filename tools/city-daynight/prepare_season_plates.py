"""Bring a season's four paintings up to plate resolution.

usage: prepare_season_plates.py <season> <seasons_dir> <originals_dir> <out_dir> [size]

The season paintings (e.g. summer-day.png, 1254px) share the composition of
the 4096px originals to within a pixel. Each is upscaled (Lanczos) and then
receives the originals' fine detail wherever the two images still show the
same thing (stone, roofs, windows, railings); where the season changed the
content (leaves, flowers, clouds) nothing is transferred. The strength of the
transfer follows the local correlation of the two images at the season
painting's own resolution.

Writes City<Season><Time>.jpg and check-detail-<time>.jpg.
"""
import os
import sys

import cv2
import numpy as np

TIMES = [("Day", "day"), ("Sunset", "sunset"), ("Night", "night"), ("DeepNight", "deepnight")]


def lum(img):
    return 0.114 * img[..., 0] + 0.587 * img[..., 1] + 0.299 * img[..., 2]


def local_corr(a, b, sigma):
    ma, mb = cv2.GaussianBlur(a, (0, 0), sigma), cv2.GaussianBlur(b, (0, 0), sigma)
    va = cv2.GaussianBlur(a * a, (0, 0), sigma) - ma * ma
    vb = cv2.GaussianBlur(b * b, (0, 0), sigma) - mb * mb
    cov = cv2.GaussianBlur(a * b, (0, 0), sigma) - ma * mb
    return cov / np.sqrt(np.maximum(va * vb, 1e-8)), np.sqrt(np.maximum(va, 0)), np.sqrt(np.maximum(vb, 0))


def main():
    season, sdir, odir, out = sys.argv[1:5]
    size = int(sys.argv[5]) if len(sys.argv) > 5 else 2048
    os.makedirs(out, exist_ok=True)
    for name, stem in TIMES:
        s_small = cv2.imread(os.path.join(sdir, f"{season}-{stem}.png")).astype(np.float32) / 255
        orig = cv2.imread(os.path.join(odir, f"{stem}.png")).astype(np.float32) / 255
        n = s_small.shape[0]
        o_small = cv2.resize(orig, (n, n), interpolation=cv2.INTER_AREA)
        # Where do the two paintings still agree? (at the season painting's resolution)
        corr, sd_s, sd_o = local_corr(lum(s_small), lum(o_small), 2.0)
        colour = np.linalg.norm(cv2.GaussianBlur(s_small - o_small, (0, 0), 2.0), axis=2)
        agree = np.clip((corr - 0.55) / 0.3, 0, 1) * np.clip(1 - (colour - 0.06) / 0.10, 0, 1)
        # Only where there is structure worth sharpening.
        agree *= np.clip((sd_o - 0.01) / 0.03, 0, 1)
        agree = cv2.GaussianBlur(agree, (0, 0), 1.0)

        up = cv2.resize(s_small, (size, size), interpolation=cv2.INTER_LANCZOS4)
        o_full = cv2.resize(orig, (size, size), interpolation=cv2.INTER_AREA)
        o_soft = cv2.resize(cv2.resize(orig, (n, n), interpolation=cv2.INTER_AREA), (size, size), interpolation=cv2.INTER_LANCZOS4)
        detail = o_full - o_soft
        # Match the detail's contrast to the season painting's local brightness.
        ratio = np.clip((cv2.GaussianBlur(lum(up), (0, 0), 3) + 0.03) / (cv2.GaussianBlur(lum(o_full), (0, 0), 3) + 0.03), 0.4, 2.0)
        w = cv2.resize(agree, (size, size), interpolation=cv2.INTER_LINEAR)
        result = up + detail * (w * ratio)[..., None]
        # Gentle sharpening everywhere else so changed areas are not visibly softer.
        blur = cv2.GaussianBlur(up, (0, 0), 1.2)
        result = result + (up - blur) * (0.45 * (1 - w))[..., None]
        result = np.clip(result, 0, 1)
        cv2.imwrite(os.path.join(out, f"City{season.capitalize()}{name}.jpg"), (result * 255).astype(np.uint8),
                    [cv2.IMWRITE_JPEG_QUALITY, 92])
        # Before/after crop: plain Lanczos | detail transfer | agreement mask
        y0, y1, x0, x1 = int(0.34 * size), int(0.52 * size), int(0.40 * size), int(0.76 * size)
        m = np.repeat(w[..., None], 3, 2)
        strip = np.hstack([up[y0:y1, x0:x1], result[y0:y1, x0:x1], m[y0:y1, x0:x1]])
        cv2.imwrite(os.path.join(out, f"check-detail-{stem}.jpg"), (strip * 255).astype(np.uint8))
        print(name, "agree %.2f" % float(agree.mean()))


if __name__ == "__main__":
    main()
