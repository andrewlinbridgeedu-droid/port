"""Package eight native model views without replacing the older profile atlases."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[2]
renders = root / "output/home-map-directions-v2-20260929"
assets = root / "mistport-ios/Mistport/Assets.xcassets"
names = json.loads((root / "mistport-ios/Mistport/WisteriaMap/home-atlas-metrics.json").read_text())
metrics = {}
for name in names:
    frames = [Image.open(renders / name / f"{direction}-{frame}.png").convert("RGBA")
              for direction in range(8) for frame in range(8)]
    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    assert all(boxes), name
    crop = (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))
    width, height = crop[2] - crop[0], crop[3] - crop[1]
    atlas = Image.new("RGBA", (width * 8, height * 8))
    bounds = []
    for direction in range(8):
        row_boxes = boxes[direction * 8:direction * 8 + 8]
        bounds.append([min(b[0] for b in row_boxes)-crop[0], min(b[1] for b in row_boxes)-crop[1],
                       max(b[2] for b in row_boxes)-crop[0], max(b[3] for b in row_boxes)-crop[1]])
        for frame in range(8):
            atlas.paste(frames[direction * 8 + frame].crop(crop), (frame * width, direction * height))
    asset_name = name + "Directions20260929"
    folder = assets / (asset_name + ".imageset")
    folder.mkdir(exist_ok=True)
    atlas.save(folder / "art.png", optimize=True)
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "art.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    metrics[name] = {"asset": asset_name, "cellWidth": width, "cellHeight": height, "bounds": bounds}
    print(name, atlas.size)
(root / "mistport-ios/Mistport/WisteriaMap/home-direction-atlas-metrics.json").write_text(
    json.dumps(metrics, indent=2) + "\n")
