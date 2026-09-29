"""Zoomed crop of a hub painting with a painting-unit grid (for tracing).

usage: gridcrop.py <painting.png> <out.jpg> <x0> <x1> <y0> <y1> [zoom] [step]
Units are fractions of the painting height, x across, y down.
"""
import sys

import cv2
import numpy as np

src, out = sys.argv[1], sys.argv[2]
x0, x1, y0, y1 = map(float, sys.argv[3:7])
k = float(sys.argv[7]) if len(sys.argv) > 7 else 3
step = float(sys.argv[8]) if len(sys.argv) > 8 else 0.01
img = cv2.imread(src)
H = img.shape[0]
a = img[int(y0 * H):int(y1 * H), int(x0 * H):int(x1 * H)]
a = cv2.resize(a, None, fx=k, fy=k, interpolation=cv2.INTER_CUBIC)
major = step * 5
for v in np.arange(np.ceil(x0 / step) * step, x1, step):
    x = int((v - x0) * H * k)
    strong = abs(v / major - round(v / major)) < 1e-6
    cv2.line(a, (x, 0), (x, a.shape[0]), (0, 255, 255) if strong else (0, 110, 110), 1)
    if strong:
        cv2.putText(a, f"{v:.2f}", (x + 2, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 255, 255), 1)
for v in np.arange(np.ceil(y0 / step) * step, y1, step):
    y = int((v - y0) * H * k)
    strong = abs(v / major - round(v / major)) < 1e-6
    cv2.line(a, (0, y), (a.shape[1], y), (255, 0, 255) if strong else (110, 0, 110), 1)
    if strong:
        cv2.putText(a, f"{v:.2f}", (2, y - 2), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 0, 255), 1)
cv2.imwrite(out, a, [cv2.IMWRITE_JPEG_QUALITY, 88])
