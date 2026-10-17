"""Package the second-pass home-street walkers (tools/harbor/render_home_walkers_v2.py).

Each look becomes seven strips of eight frames, one image set per strip, so the app decodes
only the strips a person on screen needs (a waiting task NPC needs only the standing ones):
  W0-W4  walking, directions 0 away .. 4 toward (5-7 are 3-1 mirrored in the app)
  I3, I4 standing, toward-right and toward
Every strip is cropped to the union of its frames and scaled to HEIGHT pixels; the app draws
each strip at the person's body height, as before.

  media-venv/bin/python -I tools/harbor/package_home_walkers_v2.py RENDER_DIR [HEIGHT]
Writes mistport-ios/Mistport/Assets.xcassets/HomeWalkers20261017/<Look><Strip>.imageset and
mistport-ios/Mistport/WisteriaMap/home-walkers-v2.json.
"""
import json
import shutil
import sys
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[2]
renders = Path(sys.argv[1])
height = int(sys.argv[2]) if len(sys.argv) > 2 else 180
table = json.loads((root / "tools/harbor/home_walkers_v2.json").read_text())
folder = root / "mistport-ios/Mistport/Assets.xcassets/HomeWalkers20261017"
if folder.exists():
    shutil.rmtree(folder)
folder.mkdir(parents=True)
(folder / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

strips = [("W%d" % d, "", d) for d in range(5)] + [("I3", "-idle", 3), ("I4", "-idle", 4)]
metrics = {}
total_pixels = 0
for look, spec in table["looks"].items():
    entry = {"citizens": spec["citizens"], "strips": {}}
    for strip, suffix, direction in strips:
        frames = [Image.open(renders / (look + suffix) / f"{direction}-{i}.png").convert("RGBA") for i in range(8)]
        boxes = [f.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox() for f in frames]
        assert all(boxes), (look, strip)
        box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
        scale = height / (box[3] - box[1])
        width = max(1, round((box[2] - box[0]) * scale))
        sheet = Image.new("RGBA", (width * 8, height))
        for i, frame in enumerate(frames):
            cell = frame.crop(box).resize((width, height), Image.LANCZOS)
            sheet.alpha_composite(cell, (i * width, 0))
        name = look.replace("20261017", "") + strip + "20261017"
        imageset = folder / (name + ".imageset")
        imageset.mkdir()
        sheet.save(imageset / "art.png", optimize=True)
        (imageset / "Contents.json").write_text(json.dumps({
            "images": [{"filename": "art.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
        entry["strips"][strip] = {"asset": name, "cellWidth": width, "cellHeight": height}
        total_pixels += sheet.width * sheet.height
    metrics[look] = entry
    print("PACKED", look)
(root / "mistport-ios/Mistport/WisteriaMap/home-walkers-v2.json").write_text(json.dumps(
    {"about": "Home-street walkers 2026-10-17: strips W0-W4 walk (5-7 mirror 3-1), I3/I4 stand. See tools/harbor/package_home_walkers_v2.py.",
     "looks": metrics}, ensure_ascii=False, indent=2) + "\n")
print("TOTAL", len(metrics), "looks", round(total_pixels * 4 / 1e6, 1), "MB decoded if all were loaded")
