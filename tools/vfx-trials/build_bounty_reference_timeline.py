#!/usr/bin/env python3
"""Four real Unity frames per bounty spell and camera, including early transfer."""
from __future__ import annotations

import io
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/all-spell-reference-20260923/bounty"
FFMPEG = Path("/tmp/mistport-vfx-encode/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1")
ROWS = json.loads((OUT / "capture-plan.json").read_text())["rows"]


def frame(path: Path, moment: float) -> Image.Image:
    data = subprocess.check_output([
        str(FFMPEG), "-loglevel", "error", "-ss", f"{moment:.3f}",
        "-i", str(path), "-frames:v", "1", "-f", "image2pipe",
        "-vcodec", "mjpeg", "-",
    ])
    return Image.open(io.BytesIO(data)).convert("RGB")


def samples(row: dict) -> list[float]:
    key = row["key"]
    if key == "B10-transfer":
        return [.48, .67, .85, 1.05]
    if row["expected"] == 0:
        return [.40, 1.20, 2.60, 3.80]
    action = max(c["frame"] for c in row["cues"] if c["command"].startswith("enemy:")) / 30
    return [action + d for d in (.17, .59, .73, .88)]


def one(row: dict, view: str) -> tuple[str, list[Image.Image], list[float]]:
    key = row["key"]
    suffix = "" if view == "full" else f"-{view}"
    path = OUT / "after" / f"{key}{suffix}.mp4"
    times = samples(row)
    return key, [frame(path, moment) for moment in times], times


def main() -> None:
    qa = OUT / "qa"
    qa.mkdir(exist_ok=True)
    manifest = []
    for view in ("full", "close", "impact"):
        with ThreadPoolExecutor(max_workers=4) as pool:
            items = list(pool.map(lambda row: one(row, view), ROWS))
        for start in range(0, len(items), 5):
            block = items[start:start + 5]
            sheet = Image.new("RGB", (1100, 1500), "#111b26")
            draw = ImageDraw.Draw(sheet)
            for row_index, (key, shots, times) in enumerate(block):
                y = row_index * 300
                draw.text((7, y + 6), key, fill="#ffe0a5")
                for column, (shot, moment) in enumerate(zip(shots, times)):
                    shot.thumbnail((255, 260))
                    x = column * 275 + 7 + (255 - shot.width) // 2
                    sheet.paste(shot, (x, y + 28))
                    draw.text((column * 275 + 8, y + 279), f"{moment:.2f}s", fill="white")
            path = qa / f"{view}-{start // 5 + 1:02d}.jpg"
            sheet.save(path, quality=89)
            manifest.append({"path": str(path.relative_to(ROOT)), "view": view,
                             "keys": [item[0] for item in block]})
    (qa / "index.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(ROWS)} bounty entries, {len(manifest)} view sheets")


if __name__ == "__main__":
    main()
