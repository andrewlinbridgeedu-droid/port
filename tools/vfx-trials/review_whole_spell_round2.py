#!/usr/bin/env python3
"""Decode existing VFX recordings into labeled chronological review sheets.

This is visual-review evidence, never a generated replacement for engine footage.
Original videos/frames are read only. Every selected timestamp is recorded.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/whole-spell-round2-20260922"
FFMPEG = Path("/tmp/mistport-vfx-encode/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1")
FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)


def make_sheet(item):
    path = ROOT / item["clip"]
    probe = subprocess.run([str(FFMPEG), "-hide_banner", "-i", str(path)], capture_output=True, text=True)
    match = re.search(r"Duration: (\d+):(\d+):(\d+(?:\.\d+)?)", probe.stderr)
    if not match:
        raise RuntimeError(f"Cannot probe {path}: {probe.stderr[-500:]}")
    h, m, s = map(float, match.groups())
    duration = h * 3600 + m * 60 + s
    # Even spacing across the full recording, with the final decodable frame.
    width, height, count = (220, 220, 48) if path.stem.endswith("-close") else (162, 288, 48)
    rate = count / duration
    decoded = subprocess.run([str(FFMPEG), "-v", "error", "-i", str(path), "-vf",
        f"fps={rate:.9f},scale={width}:{height}:force_original_aspect_ratio=decrease,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=black",
        "-frames:v", str(count), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    stride = width * height * 3
    actual = len(decoded) // stride
    if actual < 2:
        raise RuntimeError(f"No review sequence: {path}")
    sheet = Image.new("RGB", (width * 8, (height + 23) * 6 + 43), "#161823")
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), "/".join(item["ids"]) + " | " + path.name, font=FONT, fill="#ebd195")
    timestamps = []
    for n in range(actual):
        stamp = min(duration - 1 / 30, (n + .5) / rate)
        timestamps.append(round(stamp, 4))
        frame = Image.frombytes("RGB", (width, height), decoded[n*stride:(n+1)*stride])
        x, y = (n % 8) * width, 43 + (n // 8) * (height + 23)
        sheet.paste(frame, (x, y))
        draw.text((x+5, y+height+2), f"{n+1:02}  {stamp:.3f}s", font=FONT, fill="#e9e6df")
    dest = OUT / item.get("folder", "before") / (item["key"] + ".jpg")
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest, quality=90)
    return dict(item, duration=duration, sampled_frames=actual, timestamps=timestamps,
        sheet=str(dest.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        status="decoded; requires human/model visual inspection, not automatically reviewed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ids", help="Optional comma-separated plan IDs")
    parser.add_argument("--after", action="store_true", help="Review new round2 recordings without altering the before index")
    args = parser.parse_args()
    plan = json.loads((ROOT/"output/jev-spell-plan-20260921/review.json").read_text())
    selected = set(args.ids.split(",")) if args.ids else None
    if args.after:
        capture=json.loads((OUT/"capture-plan.json").read_text())
        clips=[]
        for row in capture["rows"]:
            if selected is not None and row["id"] not in selected:
                continue
            for suffix in ("", "-close"):
                path=OUT/"after"/(row["key"]+suffix+".mp4")
                if path.is_file():
                    clips.append(dict(clip=str(path.relative_to(ROOT)), key=row["key"]+suffix, ids=[row["id"]],folder="after-sheets"))
        with ThreadPoolExecutor(max_workers=3) as pool:
            results=list(pool.map(make_sheet,clips))
        index=OUT/"after-index.json"
        if selected and index.exists():
            merged={r["clip"]:r for r in json.loads(index.read_text())["clips"]}
            merged.update({r["clip"]:r for r in results})
            results=list(merged.values())
        index.write_text(json.dumps(dict(kind="actual Unity frame samples; still require explicit visual review",clips=results),ensure_ascii=False,indent=2)+"\n")
        print(json.dumps(dict(clips=len(results),sheets="after-sheets")))
        return
    rows = [r for r in plan["spells"] if selected is None or r["id"] in selected]
    clips = {}
    for row in rows:
        for path in row["clips"]:
            key = Path(path).parent.name + "--" + Path(path).stem
            clips.setdefault(path, dict(clip=path, key=key, ids=[]))["ids"].append(row["id"])
    minions = {
        "N07A":("copperback","tower_copperback_first"), "N07B":("copperback","tower_copperback_second"),
        "N08A":("crimson-brute","tower_brute_first"), "N08B":("crimson-brute","tower_brute_second"),
        "N09A":("veil-oracle","tower_veil_first"), "N09B":("veil-oracle","tower_veil_second"),
        "N10A":("golden-throat","tower_throat_first"), "N10B":("golden-throat","tower_throat_second"),
        "N11A":("moonfang","tower_moonfang_first"), "N11B":("moonfang","tower_moonfang_second"),
    }
    for sid,(species,spell) in minions.items():
        if selected is not None and sid not in selected:
            continue
        charge=spell.rsplit("_",1)[0]+("_charge2" if spell.endswith("second") else "_charge")
        for action in (charge,spell):
            for suffix in ("", "-close"):
                path = f"output/church-minions-20260921/{species}--{action}{suffix}.mp4"
                if (ROOT/path).is_file():
                    clips[path] = dict(clip=path, key="church-minions--"+Path(path).stem, ids=[sid])
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(make_sheet, clips.values()))
    index=OUT/"before-index.json"
    if selected and index.exists():
        existing=json.loads(index.read_text())["clips"]
        merged={r["clip"]:r for r in existing}
        merged.update({r["clip"]:r for r in results})
        results=list(merged.values())
    covered = {sid for result in results for sid in result["ids"]}
    report = dict(kind="chronological video sample evidence, not automatic visual acceptance", clips=results,
        rows_without_video=[dict(id=r["id"],name=r["name"],status="needs route/feedback check or new recording") for r in plan["spells"] if r["id"] not in covered])
    (OUT/"before-index.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(dict(clips=len(results),sheets="output/whole-spell-round2-20260922/before",missing=report["rows_without_video"]),ensure_ascii=False))


if __name__ == "__main__":
    main()
