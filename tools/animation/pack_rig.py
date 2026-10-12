"""Pack a cutout rig (rig/<name>.json, assembled with rig_preview.py) for Unity: every part's
prepared image (fades, scale and length stretch baked in) is shelf-packed into one atlas,
and a runtime JSON gives each part its atlas rect, world size, pivot, parent, offset from
the parent's pivot, draw order and rest angle - Unity axes (y up, angles counter-clockwise).
The rig is sized so the standing figure is <height> world units tall, feet at the origin.

usage: python3 tools/animation/pack_rig.py <rig.json> <out-dir> <height>
"""
import json, math, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import rig_preview as rp

MAX = 2048

def main(rig_path, out_dir, height):
    rig, base = rp.load(rig_path); name = os.path.splitext(os.path.basename(rig_path))[0]
    parts = rig["parts"]
    imgs = {}
    for n, p in parts.items():
        sc, sy = p.get("scale", 1), p.get("sy", 1)
        im = p["img"]
        if sc != 1 or sy != 1: im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc * sy))), Image.LANCZOS)
        imgs[n] = im
    # Body extents in rest pose (body px, y down) from the rendered figure.
    org = (2000, 2000); canvas = rp.render(rig, {}, size=(4000, 4000), origin=org, bg=(0, 0, 0, 0))
    x0, y0, x1, y1 = canvas.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    feet = (org[0], y1); body_h = y1 - y0
    unit = height / body_h
    # Shelf packing, scaled down until it fits.
    k = 1.0
    while True:
        order = sorted(imgs, key=lambda n: -imgs[n].height)
        x = y = shelf = 0; rects = {}; ok = True
        for n in order:
            w, h = int(imgs[n].width * k) + 2, int(imgs[n].height * k) + 2
            if x + w > MAX: x = 0; y += shelf; shelf = 0
            if y + h > MAX: ok = False; break
            rects[n] = (x, y, w, h); x += w; shelf = max(shelf, h)
        if ok: break
        k *= .92
    atlas_h = 1 << math.ceil(math.log2(max(1, y + shelf)))
    atlas = Image.new("RGBA", (MAX, atlas_h))
    for n, (x, y, w, h) in rects.items():
        atlas.paste(imgs[n].resize((w - 2, h - 2), Image.LANCZOS), (x + 1, y + 1))
    os.makedirs(out_dir, exist_ok=True)
    atlas.save(os.path.join(out_dir, name + ".png"))
    out = []
    tf = rp.world(rig, {})
    for n, p in parts.items():
        x, y, w, h = rects[n]; im = imgs[n]
        sc, sy = p.get("scale", 1), p.get("sy", 1)
        pvx, pvy = p["pivot"][0] * sc, p["pivot"][1] * sc * sy
        entry = {"name": n, "parent": p.get("parent", ""), "z": p.get("z", 0), "rot": -p.get("rot", 0),
                 "uv": [(x + 1) / MAX, 1 - (y + 1 + h - 2) / atlas_h, (x + 1 + w - 2) / MAX, 1 - (y + 1) / atlas_h],
                 "size": [im.width * unit, im.height * unit],
                 "pivot": [pvx / im.width, 1 - pvy / im.height]}
        if p.get("parent"):
            par = parts[p["parent"]]
            ax = (p["attach"][0] - par["pivot"][0]) * par.get("scale", 1)
            ay = (p["attach"][1] - par["pivot"][1]) * par.get("scale", 1) * par.get("sy", 1)
            entry["offset"] = [ax * unit, -ay * unit]
        else:
            (px, py), _, _ = tf[n]
            entry["offset"] = [(org[0] + px - feet[0]) * unit, (feet[1] - (org[1] + py)) * unit]
        out.append(entry)
    json.dump({"name": name, "height": height, "unit": unit, "mirrorPose": bool(rig.get("mirrorPose")), "parts": out}, open(os.path.join(out_dir, name + ".json"), "w"), indent=1)
    print(name, "atlas", atlas.size, "scale", round(k, 3), "unit", round(unit, 5), "body_h", body_h)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]))
