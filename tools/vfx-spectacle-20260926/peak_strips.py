"""Find each clip's strongest visual change and tile a strip around it.

usage: peak_strips.py <after_dir> <out_dir> [keys...]
For every <key>.mp4 the whole clip is decoded at low resolution, the frame
furthest from the clip's opening frame is taken as the peak, and seven frames
from 0.12 s before to 0.62 s after it are tiled (full view). Four clips per
sheet. peaks.json records the peak time and all sampled times per clip.
This only chooses where to look; it does not judge the art.
"""
import json
import os
import subprocess
import sys
from io import BytesIO

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw

FF = imageio_ffmpeg.get_ffmpeg_exe()
OFFSETS = [-0.12, 0.0, 0.07, 0.15, 0.27, 0.42, 0.62]


def decode_small(path):
    cmd = [FF, "-v", "error", "-i", path, "-vf", "scale=54:96", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, 96, 54, 3).astype(np.float32)
    return frames


def frame_at(path, t, width=180):
    cmd = [FF, "-v", "error", "-ss", f"{max(0, t):.4f}", "-i", path, "-frames:v", "1", "-vf", f"scale={width}:-2",
           "-f", "image2pipe", "-vcodec", "png", "-"]
    data = subprocess.run(cmd, capture_output=True, check=True).stdout
    return Image.open(BytesIO(data)).convert("RGB")


def main():
    src, out = sys.argv[1], sys.argv[2]
    keys = sys.argv[3:] or sorted(f[:-4] for f in os.listdir(src) if f.endswith(".mp4") and not f.endswith("-close.mp4"))
    os.makedirs(out, exist_ok=True)
    peaks = {}
    strips = []
    for key in keys:
        path = os.path.join(src, key + ".mp4")
        frames = decode_small(path)
        base = frames[min(6, len(frames) - 1)]
        diff = np.abs(frames - base).mean(axis=(1, 2, 3))
        diff[:9] = 0
        peak = int(np.argmax(diff))
        t0 = peak / 30.0
        duration = len(frames) / 30.0
        times = [min(duration - 0.04, max(0.0, t0 + o)) for o in OFFSETS]
        peaks[key] = {"peak_seconds": round(t0, 3), "peak_diff": round(float(diff[peak]), 2), "times": [round(t, 3) for t in times], "frames": len(frames)}
        imgs = [frame_at(path, t) for t in times]
        w, h = imgs[0].size
        strip = Image.new("RGB", (w * len(imgs), h + 18), (0, 0, 0))
        d = ImageDraw.Draw(strip)
        d.text((4, 3), f"{key}  peak {t0:.2f}s", fill=(255, 255, 0))
        for i, (t, im) in enumerate(zip(times, imgs)):
            ImageDraw.Draw(im).text((3, 3), f"{t:.2f}", fill=(255, 255, 0))
            strip.paste(im, (i * w, 18))
        strips.append((key, strip))
    for i in range(0, len(strips), 4):
        group = strips[i:i + 4]
        W = max(s.size[0] for _, s in group)
        H = sum(s.size[1] for _, s in group)
        sheet = Image.new("RGB", (W, H), (0, 0, 0))
        y = 0
        for _, s in group:
            sheet.paste(s, (0, y)); y += s.size[1]
        sheet.save(os.path.join(out, f"strip-{i // 4:02d}-{group[0][0]}.jpg"), quality=86)
    with open(os.path.join(out, "peaks.json"), "w") as f:
        json.dump(peaks, f, indent=1)


if __name__ == "__main__":
    main()
