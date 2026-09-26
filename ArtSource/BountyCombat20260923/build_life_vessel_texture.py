"""Paint the transfer organ's compact five-band PBR atlas without source art."""
from pathlib import Path
from PIL import Image
import math
import random

root = Path(__file__).resolve().parent / "b10-vessel"
root.mkdir(parents=True, exist_ok=True)
size = 1024
base = Image.new("RGBA", (size, size))
metal = Image.new("RGBA", (size, size))
colors = [
    (128, 21, 50),   # uneven garnet sacs
    (239, 210, 183), # bone-white valve
    (197, 143, 58),  # stamped bronze restraint
    (68, 34, 58),    # violet-black conduits
    (221, 87, 105),  # torn red membranes
]
random.seed(1010)
bp = base.load()
mp = metal.load()
for y in range(size):
    fy = y / size
    for x in range(size):
        band = min(4, x * 5 // size)
        u = (x * 5 / size) % 1
        motif = math.sin(25 * u + 13 * fy + band) * 0.035 + math.sin(71 * fy - 19 * u) * 0.025
        shade = max(.62, min(1.23, .82 + .23 * math.sin(math.pi * u) + motif))
        if band == 0:
            shade += .10 * math.sin(10 * fy + 17 * u) ** 8
        if band == 1:
            shade -= .09 * math.sin(31 * u - 12 * fy) ** 18
        bp[x, y] = tuple(max(0, min(255, int(channel * shade))) for channel in colors[band]) + (255,)
        metallic, gloss = ((35, 110), (45, 125), (205, 175), (68, 105), (28, 92))[band]
        mp[x, y] = (metallic, metallic, metallic, gloss)
base.save(root / "B10Vessel_BaseColor_2k.png")
metal.save(root / "B10Vessel_MetalSmooth_2k.png")
normal = Image.new("RGBA", (16, 16), (128, 128, 255, 255))
normal.save(root / "B10Vessel_Normal_2k.png")
print("BOUNTY_VESSEL_ATLAS_OK", size)
