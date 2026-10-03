#!/usr/bin/env python3
"""Package completed Unity probes; these are not iPhone combat recordings."""
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "output/combat-tempo-20261001"
DEST = ROOT / "docs/development/combat-tempo-20261001/probes"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_sources(folder):
    for line in (folder / "record-all-source-sha256.txt").read_text().splitlines():
        digest, name = line.split("  ", 1)
        path = ROOT / "UnityBattleSource" / name
        if not path.is_file() or sha(path) != digest:
            raise SystemExit("Probe source is stale: " + name)


def pair(before, after, target):
    # Identical fixture frame counts: no cuts, speed changes or added frames.
    filters = (
        f"[0:v]pad=iw:ih+40:0:40:color=0x142129,drawtext=fontfile='{FONT}':"
        "text='BEFORE - Unity probe':x=16:y=10:fontsize=20:fontcolor=white[a];"
        f"[1:v]pad=iw:ih+40:0:40:color=0x142129,drawtext=fontfile='{FONT}':"
        "text='AFTER - Unity probe':x=16:y=10:fontsize=20:fontcolor=white[b];"
        "[a][b]hstack=inputs=2[v]"
    )
    subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(before), "-i", str(after), "-filter_complex", filters,
        "-map", "[v]", "-an", "-c:v", "libx264", "-crf", "21",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(target)], check=True)


DEST.mkdir(parents=True, exist_ok=True)
verify_sources(SOURCE / "after-probes")
verify_sources(SOURCE / "q3-body")
manifest = {"kind": "Unity presentation probes, not native iPhone battles",
    "userVisualApproval": False, "clips": []}
plan = json.loads((SOURCE / "after-probes/capture-plan.json").read_text())
rows = [(r["key"], SOURCE / "before-samples/after", SOURCE / "after-probes/after") for r in plan["rows"]]
rows.append(("M05", SOURCE / "before-probes/after", SOURCE / "q3-body/after"))
for key, old_dir, new_dir in rows:
    for suffix in ["", "-close"]:
        old = old_dir / (key + suffix + ".mp4")
        new = new_dir / (key + suffix + ".mp4")
        if not old.is_file() or not new.is_file():
            raise SystemExit("Missing source clip: " + key)
        for label, path in [("before", old), ("after", new)]:
            folder = DEST / label
            folder.mkdir(exist_ok=True)
            shutil.copy2(path, folder / path.name)
        target = DEST / (key + suffix + "-comparison.mp4")
        pair(old, new, target)
        manifest["clips"].append({"key": key + suffix, "beforeSHA256": sha(old),
            "afterSHA256": sha(new), "comparisonSHA256": sha(target)})
for name in ["capture-plan.json", "record-all-passed.txt", "record-all-source-sha256.txt",
             "safety-all-passed.txt", "safety-all-source-sha256.txt"]:
    shutil.copy2(SOURCE / "after-probes" / name, DEST / name)
for name in ["capture-plan.json", "record-all-passed.txt", "record-all-source-sha256.txt"]:
    shutil.copy2(SOURCE / "q3-body" / name, DEST / ("q3-" + name))
(DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("Packaged 12 full/close probe comparisons; no device evidence claimed")
