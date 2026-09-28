"""Draws walkers along every route of CityLivingScene.swift, hidden by the
occluder outlines the way the app hides them, for reviewing the routes.

usage: check_routes.py <painting.jpg> <out_prefix>
Writes <out_prefix>-all.jpg and zoomed <out_prefix>-<area>.jpg crops.
Figures are simple silhouettes (head, body) every ~0.9 m along each route;
occluder outlines are drawn in cyan, standing spots in yellow.
"""
import re
import sys

import cv2
import numpy as np

src = open("mistport-ios/Mistport/CityLivingScene.swift").read()


def block(start, end):
    return src[src.index(start):src.index(end, src.index(start))]


def triples(text):
    return [tuple(map(float, p)) for p in re.findall(r"\(([\d.]+), ([\d.]+), ([\d.]+)\)", text)]


routes = [triples(c) for c in block("    static let routes:", "    static let slotsPerRoute").split("\n        //")[1:]]
occl = []
for base, body in re.findall(r"\(([\d.]+), \[(.*?)\]\)", block("    static let occluders:", "    /// People standing"), re.S):
    occl.append((float(base), [tuple(map(float, p)) for p in re.findall(r"\(([\d.]+), ([\d.]+)\)", body)]))
spots = [triples(g) for g in re.findall(r"\[([^\[\]]*)\]", block("    static let spots:", "    /// The outlines hiding"))]

img = cv2.imread(sys.argv[1])
H = img.shape[0]
out = img.copy()
P = lambda x, y: (int(round(x * H)), int(round(y * H)))


def figure(x, y, h, colour):
    """Silhouette in its own layer, then cut by occluders with a nearer base."""
    layer = np.zeros(img.shape[:2], np.uint8)
    w = h * 0.34
    cv2.ellipse(layer, P(x, y - h * 0.45), (int(w * H / 2), int(h * 0.42 * H)), 0, 0, 360, 255, -1)
    cv2.circle(layer, P(x, y - h * 0.9), max(1, int(h * 0.1 * H)), 255, -1)
    for base, outline in occl:
        if base > y + 0.001:
            cv2.fillPoly(layer, [np.int32([P(*p) for p in outline])], 0)
    out[layer > 0] = (0.35 * out[layer > 0] + 0.65 * np.array(colour)).astype(np.uint8)


def meters(a, b):
    return np.hypot(b[0] - a[0], b[1] - a[1]) / ((a[2] + b[2]) / 2) * 1.7


cols = [(0, 0, 255), (255, 0, 255), (0, 200, 0), (255, 128, 0), (0, 140, 255)]
for i, r in enumerate(routes):
    for a, b in zip(r, r[1:]):
        n = max(1, int(meters(a, b) / 0.9))
        for k in range(n):
            u = k / n
            figure(*(a[j] + (b[j] - a[j]) * u for j in range(3)), cols[i % len(cols)])
    cv2.polylines(out, [np.int32([P(x, y) for x, y, _ in r])], False, cols[i % len(cols)], 2)
for g in spots:
    for x, y, h in g:
        figure(x, y, h, (0, 255, 255))
for base, outline in occl:
    cv2.polylines(out, [np.int32([P(*p) for p in outline])], True, (255, 255, 0), 2)
pre = sys.argv[2]
cv2.imwrite(pre + "-all.jpg", cv2.resize(out, (2000, int(2000 * H / img.shape[1])), interpolation=cv2.INTER_AREA))
for name, (x0, x1, y0, y1) in {"walk": (0.34, 0.62, 0.39, 0.67), "court": (0.90, 1.26, 0.52, 0.84),
                               "market": (1.33, 1.777, 0.62, 0.93)}.items():
    crop = out[int(y0 * H):int(y1 * H), int(x0 * H):int(x1 * H)]
    k = 1400 / crop.shape[1]
    cv2.imwrite(f"{pre}-{name}.jpg", cv2.resize(crop, None, fx=k, fy=k, interpolation=cv2.INTER_AREA),
                [cv2.IMWRITE_JPEG_QUALITY, 88])
