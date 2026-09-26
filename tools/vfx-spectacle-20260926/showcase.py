"""Before/after showcase reel from recorder MP4s.

usage: showcase.py <before_dir> <after_dir> <peaks.json> <out.mp4> KEY[:label] ...
Each segment trims both clips to the same window around the after clip's
peak (0.7 s before to 1.1 s after), plays it at normal speed and then again
at 0.4x, side by side (before left, after right) with labels.
"""
import json
import os
import subprocess
import sys
import tempfile

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

FF = imageio_ffmpeg.get_ffmpeg_exe()
FONTS = [
    os.environ.get("SHOWCASE_FONT", ""),
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
]
FONT = next((f for f in FONTS if f and os.path.exists(f)), None)
if FONT is None:
    sys.exit("showcase.py: no CJK font found; set SHOWCASE_FONT to a .ttc/.ttf path")


def label(text, size, color, path):
    # imageio-ffmpeg's bundled ffmpeg has no drawtext, so labels are drawn here and overlaid.
    font = ImageFont.truetype(FONT, size)
    box = ImageDraw.Draw(Image.new("RGBA", (1, 1))).textbbox((0, 0), text, font=font)
    pad = size // 3
    im = Image.new("RGBA", (box[2] - box[0] + 2 * pad, box[3] - box[1] + 2 * pad), (0, 0, 0, 150))
    ImageDraw.Draw(im).text((pad - box[0], pad - box[1]), text, font=font, fill=color)
    im.save(path)
    return path


def segment(before, after, start, length, caption, out, speed):
    pts = f"setpts={1 / speed:.4f}*(PTS-STARTPTS)"
    common = f"trim=start={start:.3f}:duration={length:.3f},{pts},scale=405:720,setsar=1"
    tag = "" if speed == 1 else "  0.4x"
    base = out[:-4]
    labels = [label("改前", 30, (255, 255, 255, 255), base + "-l.png"),
              label("改后", 30, (255, 230, 0, 255), base + "-r.png"),
              label(caption + tag, 34, (255, 255, 255, 255), base + "-c.png")]
    filt = (
        f"[0:v]{common}[a0];[a0][2:v]overlay=14:14[a];"
        f"[1:v]{common}[b0];[b0][3:v]overlay=14:14[b];"
        f"[a][b]hstack=inputs=2[s];[s][4:v]overlay=(W-w)/2:H-h-24,fps=30[v]"
    )
    inputs = ["-i", before, "-i", after] + [a for p in labels for a in ("-i", p)]
    subprocess.run([FF, "-v", "error", "-y", *inputs, "-filter_complex", filt, "-map", "[v]",
                    "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", out], check=True)


def main():
    before_dir, after_dir, peaks_path, out = sys.argv[1:5]
    peaks = json.load(open(peaks_path))
    keys = [item.partition(":")[0] for item in sys.argv[5:]]
    missing = [os.path.join(d, k + ".mp4") for k in keys for d in (before_dir, after_dir) if not os.path.exists(os.path.join(d, k + ".mp4"))]
    missing += [f"{k} (not in {peaks_path})" for k in keys if k not in peaks]
    if missing:
        sys.exit("showcase.py: missing\n  " + "\n  ".join(missing))
    tmp = tempfile.mkdtemp()
    parts = []
    for i, item in enumerate(sys.argv[5:]):
        key, _, caption = item.partition(":")
        caption = caption or key
        peak = peaks[key]["peak_seconds"]
        duration = peaks[key]["frames"] / 30.0
        start = max(0.0, peak - 0.7)
        length = min(1.8, duration - start - 0.05)
        for speed in (1.0, 0.4):
            p = os.path.join(tmp, f"{i:02d}-{speed}.mp4")
            segment(os.path.join(before_dir, key + ".mp4"), os.path.join(after_dir, key + ".mp4"), start, length, caption, p, speed)
            parts.append(p)
    listing = os.path.join(tmp, "list.txt")
    with open(listing, "w") as f:
        for p in parts:
            f.write(f"file '{p}'\n")
    subprocess.run([FF, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", "-movflags", "+faststart", out], check=True)
    print(out)


if __name__ == "__main__":
    main()
