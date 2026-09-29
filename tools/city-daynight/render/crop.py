"""Crops painting-unit regions from HarborRender frames (height 744 pt at 2x).
usage: crop.py <frame.png> <out.jpg> <x0> <x1> <y0> <y1> [zoom]"""
import sys
import cv2
img = cv2.imread(sys.argv[1]); H = img.shape[0]
x0, x1, y0, y1 = map(float, sys.argv[3:7]); k = float(sys.argv[7]) if len(sys.argv) > 7 else 1
a = img[int(y0 * H):int(y1 * H), int(x0 * H):int(x1 * H)]
cv2.imwrite(sys.argv[2], cv2.resize(a, None, fx=k, fy=k, interpolation=cv2.INTER_CUBIC), [cv2.IMWRITE_JPEG_QUALITY, 90])
