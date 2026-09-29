"""Traces the land/sky line of the 2026-09-27 hub paintings.

usage: skyline.py <sunset.png> <day.png> <out_dir> [prior.json]

A hand-traced prior (painting units: y down from the top, x across, both in
fractions of the painting height) is snapped to the strongest darkening edge
within ±0.012 units in the sunset painting (sky bright, land dark), helped by
the day painting's edges. Writes skyline.txt (256 samples across the width)
and skyline-check.jpg.
"""
import json
import sys

import cv2
import numpy as np

PRIOR = [(0.0, 0.115), (0.035, 0.103), (0.05, 0.12), (0.06, 0.135), (0.07, 0.14), (0.10, 0.125), (0.12, 0.115),
         (0.145, 0.112), (0.17, 0.115), (0.19, 0.12), (0.21, 0.13), (0.235, 0.135), (0.25, 0.145), (0.27, 0.155),
         (0.28, 0.165), (0.30, 0.175), (0.34, 0.18), (0.37, 0.185), (0.40, 0.19), (0.55, 0.19), (0.58, 0.18),
         (0.595, 0.172), (0.62, 0.165), (0.645, 0.178), (0.66, 0.18), (0.69, 0.172), (0.70, 0.175), (0.73, 0.165),
         (0.745, 0.155), (0.765, 0.13), (0.79, 0.113), (0.805, 0.108), (0.82, 0.115), (0.835, 0.125), (0.86, 0.14),
         (0.875, 0.15), (0.90, 0.155), (0.95, 0.165), (0.98, 0.155), (1.02, 0.15), (1.04, 0.14), (1.075, 0.132),
         (1.10, 0.15), (1.11, 0.157), (1.18, 0.157), (1.19, 0.145), (1.205, 0.135), (1.22, 0.145), (1.235, 0.16),
         (1.24, 0.14), (1.255, 0.125), (1.265, 0.125), (1.28, 0.135), (1.29, 0.155), (1.30, 0.16), (1.32, 0.165),
         (1.35, 0.155), (1.385, 0.143), (1.42, 0.152), (1.45, 0.16), (1.48, 0.18), (1.50, 0.195), (1.535, 0.188),
         (1.56, 0.205), (1.58, 0.225), (1.60, 0.235), (1.62, 0.245), (1.63, 0.247), (1.635, 0.21), (1.67, 0.20),
         (1.70, 0.20), (1.73, 0.205), (1.76, 0.21), (1.777, 0.212)]


def median(a, k):
    pad = np.pad(a, k // 2, mode="edge")
    return np.array([np.median(pad[i:i + k]) for i in range(len(a))])


def main(sunset_path, day_path, out, prior_path=None):
    prior = json.load(open(prior_path)) if prior_path else PRIOR
    img = cv2.imread(sunset_path)
    day = cv2.imread(day_path)
    H, W = img.shape[:2]
    px = np.array([p[0] for p in prior]) * H
    py = np.array([p[1] for p in prior]) * H
    xs = np.arange(W)
    base = np.interp(xs, px, py)
    lum = lambda im: cv2.GaussianBlur(cv2.cvtColor(im, cv2.COLOR_BGR2LAB)[:, :, 0].astype(np.float32), (3, 3), 0)
    g, gd = lum(img), lum(day)
    darker = -(np.roll(g, -2, 0) - np.roll(g, 2, 0))
    edge_day = np.abs(np.roll(gd, -2, 0) - np.roll(gd, 2, 0))
    r = int(0.012 * H)
    line = np.zeros(W)
    for x in xs:
        lo, hi = max(0, int(base[x]) - r), min(H - 1, int(base[x]) + r)
        rows = np.arange(lo, hi)
        score = darker[lo:hi, x] + 0.5 * edge_day[lo:hi, x] - 0.6 * np.abs(rows - base[x])
        line[x] = lo + np.argmax(score)
    line = median(line, 7)
    vis, v2 = img.copy(), day.copy()
    for x in xs:
        cv2.circle(vis, (x, int(line[x])), 1, (0, 255, 0), -1)
        cv2.circle(v2, (x, int(line[x])), 1, (0, 0, 255), -1)
    band = slice(int(0.08 * H), int(0.28 * H))
    cv2.imwrite(f"{out}/skyline-check.jpg", np.vstack([vis[band], v2[band]]), [cv2.IMWRITE_JPEG_QUALITY, 90])
    samples = [round(float(np.interp((i + 0.5) / 256 * W, xs, line)) / H, 4) for i in range(256)]
    open(f"{out}/skyline.txt", "w").write(repr(samples))


if __name__ == "__main__":
    main(*sys.argv[1:5])
