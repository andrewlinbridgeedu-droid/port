"""Draws the walking routes of CityLivingScene.swift on a hub painting.

usage: draw_routes.py <painting.jpg> <out.jpg> [x0 x1 y0 y1 zoom]
Each route point shows the feet (dot) and the person's height (tick).
With a crop (painting units) the view is zoomed with a 0.01 grid.
"""
import re
import sys

import cv2
import numpy as np

src = open("mistport-ios/Mistport/CityLivingScene.swift").read()
block = src[src.index("    static let routes: [[(Double, Double, Double)]] = ["):src.index("    static let slotsPerRoute")]
routes = [[tuple(map(float, p)) for p in re.findall(r"\(([\d.]+), ([\d.]+), ([\d.]+)\)", chunk)]
          for chunk in block.split("\n        //")[1:]]
img = cv2.imread(sys.argv[1])
H = img.shape[0]
cols = [(0, 0, 255), (0, 255, 255), (255, 0, 255), (0, 255, 0), (255, 128, 0), (255, 255, 255)]
for i, r in enumerate(routes):
    pts = np.int32([(x * H, y * H) for x, y, _ in r])
    cv2.polylines(img, [pts], False, cols[i % len(cols)], 4)
    for x, y, h in r:
        cv2.circle(img, (int(x * H), int(y * H)), 7, cols[i % len(cols)], -1)
        cv2.line(img, (int(x * H), int(y * H)), (int(x * H), int((y - h) * H)), cols[i % len(cols)], 3)
    cv2.putText(img, str(i), (int(r[0][0] * H) + 10, int(r[0][1] * H)), cv2.FONT_HERSHEY_SIMPLEX, 2, cols[i % len(cols)], 5)
if len(sys.argv) > 3:
    x0, x1, y0, y1, k = map(float, sys.argv[3:8])
    a = img[int(y0 * H):int(y1 * H), int(x0 * H):int(x1 * H)]
    a = cv2.resize(a, None, fx=k, fy=k, interpolation=cv2.INTER_AREA)
    for v in np.arange(np.ceil(x0 * 100) / 100, x1, 0.01):
        x = int((v - x0) * H * k); strong = abs(v * 20 - round(v * 20)) < 1e-6
        cv2.line(a, (x, 0), (x, a.shape[0]), (0, 200, 255) if strong else (0, 90, 120), 1)
        if strong: cv2.putText(a, f"{v:.2f}", (x + 2, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 255, 255), 1)
    for v in np.arange(np.ceil(y0 * 100) / 100, y1, 0.01):
        y = int((v - y0) * H * k); strong = abs(v * 20 - round(v * 20)) < 1e-6
        cv2.line(a, (0, y), (a.shape[1], y), (255, 0, 255) if strong else (110, 0, 110), 1)
        cv2.putText(a, f"{v:.2f}", (2, y - 2), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 0, 255), 1)
    img = a
else:
    img = cv2.resize(img, (2000, int(2000 * img.shape[0] / img.shape[1])), interpolation=cv2.INTER_AREA)
cv2.imwrite(sys.argv[2], img, [cv2.IMWRITE_JPEG_QUALITY, 86])
