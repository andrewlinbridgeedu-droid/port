#!/usr/bin/env python3
"""Sample the current Unity bounty recordings at actual cue/contact moments."""
from __future__ import annotations

import io
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MOVIES = ROOT / "output/bounty-eight-20260923/after"
OUT = ROOT / "output/bounty-spell-overhaul-20260923"
FFMPEG = Path("/tmp/mistport-vfx-encode/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1")
ROWS = json.loads((ROOT / "output/bounty-eight-20260923/capture-plan.json").read_text())["rows"]


def frame(movie: Path, seconds: float) -> Image.Image:
    data = subprocess.check_output([
        str(FFMPEG), "-loglevel", "error", "-ss", f"{seconds:.3f}", "-i", str(movie),
        "-frames:v", "1", "-f", "image2pipe", "-vcodec", "mjpeg", "-",
    ])
    return Image.open(io.BytesIO(data)).convert("RGB")


def moments(row: dict) -> list[float]:
    if row["expected"] == 0:
        return [.40, 1.20, 2.60, min(row["frames"] / 30 - .13, 3.80)]
    action = max((cue["frame"] for cue in row["cues"]), default=6) / 30
    contact = action + .65
    return [max(0, action + .17), contact - .055, contact + .075, contact + .225]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for suffix in ("", "-close", "-impact"):
        for batch in range(3):
            page = Image.new("RGB", (1060, 1400), "#111924")
            draw = ImageDraw.Draw(page)
            for idx, row in enumerate(ROWS[batch * 5:batch * 5 + 5]):
                key = row["key"]
                video = MOVIES / f"{key}{suffix}.mp4"
                if not video.exists():
                    raise FileNotFoundError(video)
                draw.text((8, idx * 280 + 3), key + (suffix or "-full"), fill="white")
                for n, t in enumerate(moments(row)):
                    im = frame(video, t)
                    im.thumbnail((252, 245))
                    x, y = n * 265 + 4, idx * 280 + 28
                    page.paste(im, (x + (252 - im.width) // 2, y))
                    draw.text((x + 5, y + 3), f"{t:.2f}s", fill="white", stroke_width=1, stroke_fill="#14202b")
            path = OUT / f"qa-{suffix.lstrip('-') or 'full'}-{batch+1}.jpg"
            page.save(path, quality=88)
            print(path)


if __name__ == "__main__":
    main()
