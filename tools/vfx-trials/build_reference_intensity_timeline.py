#!/usr/bin/env python3
"""Compact inspection sheets from the actual current whole-spell Unity videos."""
from __future__ import annotations

import io
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/all-spell-reference-20260923/whole"
FFMPEG = Path("/tmp/mistport-vfx-encode/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1")
ROWS = json.loads((OUT / "capture-plan.json").read_text())["rows"]
# Several attacks resolve well after their command cue, while support spells
# appear before it. Sample the visible action in the recorded clip rather than
# presenting empty frames as a contact review.
VISIBLE_MOMENTS = {
    "M01": (.1 + 1.0, 1.20, 1.30),
    "M02": (.25, .45, .65),
    "M10": (.44, 1.20, 2.60),
    "M13": (2.08, 2.28, 2.40),
    "M14": (2.08, 2.28, 2.40),
    "M15": (.70, 1.00, 1.20),
    "M19": (.28, .45, .70),
    "M20": (.28, .45, .70),
    "M22": (2.35, 2.43, 2.52),
    "T21": (2.65, 2.84, 3.04),
    "T31": (2.70, 3.16, 3.35),
    "T51": (2.55, 2.90, 3.20),
}


def get_frame(path: Path, moment: float) -> Image.Image:
    data = subprocess.check_output([
        str(FFMPEG), "-loglevel", "error", "-ss", f"{moment:.3f}", "-i", str(path),
        "-frames:v", "1", "-f", "image2pipe", "-vcodec", "mjpeg", "-",
    ])
    return Image.open(io.BytesIO(data)).convert("RGB")


def one(row: dict) -> tuple[str, list[tuple[str, Image.Image]]]:
    key = row["key"]
    duration = row["frames"] / 30
    if key in VISIBLE_MOMENTS:
        moments = list(zip(VISIBLE_MOMENTS[key], ("发", "触", "峰")))
    elif row["expected"] == 0:
        moments = [(.40, "起"), (min(duration - .13, 1.20), "持"),
                   (min(duration - .13, 2.60), "续")]
    else:
        action = max((cue["frame"] for cue in row["cues"]), default=6) / 30
        moments = [(max(.01, action + .30), "发"),
                   (min(duration - .13, action + .66), "触"),
                   (min(duration - .13, action + .75), "峰")]
    shots = []
    for moment, label in moments:
        shots.append((f"{label} {moment:.2f}s", get_frame(OUT / "after" / f"{key}.mp4", moment)))
    close_moment = moments[-1][0]
    shots.append((f"近 {close_moment:.2f}s", get_frame(OUT / "after" / f"{key}-close.mp4", close_moment)))
    return key, shots


def main() -> None:
    with ThreadPoolExecutor(max_workers=4) as pool:
        items = list(pool.map(one, ROWS))
    qa = OUT / "qa"
    qa.mkdir(exist_ok=True)
    manifest = []
    for start in range(0, len(items), 6):
        block = items[start:start + 6]
        image = Image.new("RGB", (1100, 1600), "#111b26")
        draw = ImageDraw.Draw(image)
        for row_index, (key, shots) in enumerate(block):
            y = row_index * 265
            draw.text((8, y + 5), key, fill="#ffe0a5")
            for column, (label, shot) in enumerate(shots):
                shot.thumbnail((260, 225))
                x = column * 275 + 5 + (260 - shot.width) // 2
                image.paste(shot, (x, y + 29))
                draw.text((column * 275 + 9, y + 237), label, fill="white")
        path = qa / f"sheet-{start // 6 + 1:02d}.jpg"
        image.save(path, quality=88)
        manifest.append({"path": str(path.relative_to(ROOT)), "keys": [item[0] for item in block]})
    (qa / "index.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(items)} Unity performances on {len(manifest)} contact review sheets")


if __name__ == "__main__":
    main()
