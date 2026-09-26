"""Contact sheets from recorder MP4s (decoded straight from the video).

usage: sheet.py out.jpg video.mp4 start end count [width]
Frames are sampled evenly between start and end seconds (inclusive) and
tiled with their timestamp burned in the corner.
"""
import subprocess
import sys

import imageio_ffmpeg
from PIL import Image, ImageDraw

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


def frame(video, t, width):
    cmd = [FFMPEG, "-v", "error", "-ss", f"{t:.4f}", "-i", video, "-frames:v", "1",
           "-vf", f"scale={width}:-2", "-f", "image2pipe", "-vcodec", "png", "-"]
    data = subprocess.run(cmd, capture_output=True, check=True).stdout
    from io import BytesIO
    return Image.open(BytesIO(data)).convert("RGB")


def main():
    out, video, start, end, count = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), int(sys.argv[5])
    width = int(sys.argv[6]) if len(sys.argv) > 6 else 270
    times = [start + (end - start) * i / max(1, count - 1) for i in range(count)]
    frames = [frame(video, t, width) for t in times]
    cols = min(count, 6)
    rows = (count + cols - 1) // cols
    w, h = frames[0].size
    sheet = Image.new("RGB", (cols * w, rows * h), (0, 0, 0))
    for i, (t, im) in enumerate(zip(times, frames)):
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 64, 16], fill=(0, 0, 0))
        d.text((3, 2), f"{t:.2f}s", fill=(255, 255, 0))
        sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    sheet.save(out, quality=88)


if __name__ == "__main__":
    main()
