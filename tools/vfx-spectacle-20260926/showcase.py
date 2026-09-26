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

FF = imageio_ffmpeg.get_ffmpeg_exe()
FONT = "/System/Library/Fonts/PingFang.ttc"
if not os.path.exists(FONT):
    FONT = "/System/Library/Fonts/Helvetica.ttc"


def esc(text):
    return text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’")


def segment(before, after, start, length, label, out, speed):
    pts = f"setpts={1 / speed:.4f}*(PTS-STARTPTS)"
    common = f"trim=start={start:.3f}:duration={length:.3f},{pts},scale=405:720,setsar=1"
    tag = "" if speed == 1 else "  0.4x"
    filt = (
        f"[0:v]{common},drawtext=fontfile={FONT}:text='{esc('改前')}':x=14:y=14:fontsize=30:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=8[a];"
        f"[1:v]{common},drawtext=fontfile={FONT}:text='{esc('改后')}':x=14:y=14:fontsize=30:fontcolor=yellow:box=1:boxcolor=black@0.55:boxborderw=8[b];"
        f"[a][b]hstack=inputs=2,drawtext=fontfile={FONT}:text='{esc(label + tag)}':x=(w-text_w)/2:y=h-58:fontsize=34:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=10,fps=30[v]"
    )
    subprocess.run([FF, "-v", "error", "-y", "-i", before, "-i", after, "-filter_complex", filt, "-map", "[v]",
                    "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", out], check=True)


def main():
    before_dir, after_dir, peaks_path, out = sys.argv[1:5]
    peaks = json.load(open(peaks_path))
    tmp = tempfile.mkdtemp()
    parts = []
    for i, item in enumerate(sys.argv[5:]):
        key, _, label = item.partition(":")
        label = label or key
        peak = peaks[key]["peak_seconds"]
        duration = peaks[key]["frames"] / 30.0
        start = max(0.0, peak - 0.7)
        length = min(1.8, duration - start - 0.05)
        for speed in (1.0, 0.4):
            p = os.path.join(tmp, f"{i:02d}-{speed}.mp4")
            segment(os.path.join(before_dir, key + ".mp4"), os.path.join(after_dir, key + ".mp4"), start, length, label, p, speed)
            parts.append(p)
    listing = os.path.join(tmp, "list.txt")
    with open(listing, "w") as f:
        for p in parts:
            f.write(f"file '{p}'\n")
    subprocess.run([FF, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", "-movflags", "+faststart", out], check=True)
    print(out)


if __name__ == "__main__":
    main()
