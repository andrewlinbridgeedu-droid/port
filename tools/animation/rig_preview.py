"""Assemble a cutout rig (rig/<name>.json: parts cut by cut_parts.py, each with a pivot in its
own crop, a parent and the point on the parent it hangs from, draw order and rest angle) and
render it next to the full-body painting, optionally in a test pose, to line the joints up.

usage: python3 tools/animation/rig_preview.py <rig.json> <out.jpg> [pose.json]
"""
import json, math, os, sys
from PIL import Image

def prepared(im, p):
    """Per-part touch-ups: fadeBottom [y0, y1] ramps alpha to 0 between those rows (a neck
    end that slips into a collar), fadeTop likewise from the top."""
    if "fadeBottom" in p or "fadeTop" in p:
        a = im.getchannel("A"); px = a.load()
        for y in range(im.height):
            k = 1.0
            if "fadeBottom" in p:
                y0, y1 = p["fadeBottom"]; k *= 1.0 if y <= y0 else 0.0 if y >= y1 else (y1 - y) / (y1 - y0)
            if "fadeTop" in p:
                y0, y1 = p["fadeTop"]; k *= 0.0 if y <= y0 else 1.0 if y >= y1 else (y - y0) / (y1 - y0)
            if k < 1.0:
                for x in range(im.width): px[x, y] = int(px[x, y] * k)
        im.putalpha(a)
    return im

def load(rig_path):
    rig = json.load(open(rig_path)); base = os.path.dirname(os.path.abspath(rig_path))
    cut = os.path.join(base, "..", "cut", rig["cut"])
    for n, p in rig["parts"].items():
        p["img"] = prepared(Image.open(os.path.join(cut, f'{p["index"]:02d}.png')).convert("RGBA"), p)
    return rig, base

def world(rig, pose):
    """Each part's transform: position of its pivot in body space and its total angle (deg)."""
    out = {}
    def solve(n):
        if n in out: return out[n]
        p = rig["parts"][n]; ang = p.get("rot", 0) + pose.get(n, 0)
        if not p.get("parent"):
            out[n] = (tuple(p.get("at", (0, 0))), ang, p.get("scale", 1)); return out[n]
        (px, py), pang, ps = solve(p["parent"])
        par = rig["parts"][p["parent"]]
        ax, ay = p["attach"][0] - par["pivot"][0], (p["attach"][1] - par["pivot"][1]) * par.get("sy", 1)
        c, s = math.cos(math.radians(pang)), math.sin(math.radians(pang))
        out[n] = ((px + (ax * c - ay * s) * ps, py + (ax * s + ay * c) * ps), pang + ang, p.get("scale", 1))
        return out[n]
    for n in rig["parts"]: solve(n)
    return out

def render(rig, pose, size=(900, 1750), origin=(450, 430), bg=(40, 44, 58, 255)):
    canvas = Image.new("RGBA", size, bg)
    tf = world(rig, pose)
    for n in sorted(rig["parts"], key=lambda k: rig["parts"][k].get("z", 0)):
        p = rig["parts"][n]; (x, y), ang, sc = tf[n]
        im = p["img"]
        sy = p.get("sy", 1)   # stretch along the part's own length only (legs drawn too short)
        if sc != 1 or sy != 1: im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc * sy))), Image.LANCZOS)
        pvx, pvy = p["pivot"][0] * sc, p["pivot"][1] * sc * sy
        # rotate round the pivot: pad so the pivot is the centre, rotate, paste centred at (x, y)
        r = int(math.hypot(max(pvx, im.width - pvx), max(pvy, im.height - pvy))) + 2
        pad = Image.new("RGBA", (2 * r, 2 * r)); pad.paste(im, (int(r - pvx), int(r - pvy)))
        rot = pad.rotate(-ang, resample=Image.BICUBIC)
        canvas.alpha_composite(rot, (int(origin[0] + x - r), int(origin[1] + y - r)))
    return canvas

if __name__ == "__main__":
    rig, base = load(sys.argv[1])
    pose = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else {}
    org = tuple(rig.get("origin", (450, 430)))
    img = render(rig, {}, origin=org)
    panels = [img]
    if pose: panels.append(render(rig, pose, origin=org))
    full = Image.open(os.path.join(base, "..", rig["full"])).convert("RGBA")
    full = full.resize((int(full.width * img.height / full.height), img.height))
    panels.insert(0, full)
    W = sum(p.width for p in panels); sheet = Image.new("RGB", (W, img.height), (40, 44, 58)); x = 0
    for p in panels: sheet.paste(p.convert("RGB"), (x, 0)); x += p.width
    sheet.save(sys.argv[2], quality=85); print(sheet.size)
