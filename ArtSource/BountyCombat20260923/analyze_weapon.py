"""Print connected-component bounds and skin assignments for one bounty mesh.

Usage: blender -b -t 4 -P analyze_weapon.py -- b01
"""
import bpy
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
case = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / case / f"{case.upper()}_Combat.blend"))
mesh = next(obj for obj in bpy.data.objects if obj.type == "MESH")
n = len(mesh.data.vertices)
parent = list(range(n))


def find(i):
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i


for edge in mesh.data.edges:
    a, b = edge.vertices
    ra, rb = find(a), find(b)
    if ra != rb:
        parent[rb] = ra

parts = defaultdict(list)
for i in range(n):
    parts[find(i)].append(i)
names = {group.index: group.name for group in mesh.vertex_groups}
rows = []
for indices in parts.values():
    vertices = [mesh.data.vertices[i] for i in indices]
    coords = [vertex.co for vertex in vertices]
    minimum = [min(co[axis] for co in coords) for axis in range(3)]
    maximum = [max(co[axis] for co in coords) for axis in range(3)]
    groups = Counter()
    for vertex in vertices:
        for group in vertex.groups:
            groups[names[group.group]] += group.weight
    rows.append({"size": len(indices), "min": [round(v, 3) for v in minimum],
                 "max": [round(v, 3) for v in maximum],
                 "mean": [round(sum(co[axis] for co in coords) / len(coords), 3)
                          for axis in range(3)],
                 "groups": groups.most_common(6), "representative": indices[0]})
rows.sort(key=lambda item: item["size"], reverse=True)
result = {"case": case, "vertices": n, "components": len(rows), "rows": rows}
(ROOT / case / "components.json").write_text(json.dumps(result, indent=2))
for row in rows[:50]:
    print("COMPONENT", row, flush=True)
if case == "b01":
    for label, predicate in {
        "blade-narrow": lambda co: co.x < -.40 and co.y < -.17 and co.z < 1.10,
        "blade-broad": lambda co: co.x < -.34 and co.y < -.12 and co.z < 1.15,
    }.items():
        selected = [vertex for vertex in mesh.data.vertices if predicate(vertex.co)]
        distribution = Counter()
        for vertex in selected:
            for group in vertex.groups:
                distribution[names[group.group]] += group.weight
        print("REGION", label, len(selected), distribution.most_common(), flush=True)
    width, height = 620, 620
    pixels = [1.0] * (width * height * 4)
    def paint(vertex, color):
        x = int((vertex.co.x + 1) / 2 * (width - 1))
        y = int(vertex.co.z / 2 * (height - 1))
        if 0 <= x < width and 0 <= y < height:
            for ox in (0, 1):
                for oy in (0, 1):
                    index = ((y + oy) * width + x + ox) * 4
                    if index + 3 < len(pixels):
                        pixels[index:index + 4] = [*color, 1.0]
    for vertex in mesh.data.vertices:
        paint(vertex, (.65, .65, .65))
    for vertex in mesh.data.vertices:
        if vertex.co.x < -.32 and vertex.co.y < -.08 and vertex.co.z < 1.08:
            paint(vertex, (.0, .8, .25))
    for vertex in mesh.data.vertices:
        if vertex.co.x < -.32 and vertex.co.y < -.14 and vertex.co.z < 1.15:
            paint(vertex, (.05, .3, 1.0))
    for vertex in mesh.data.vertices:
        if vertex.co.x < -.40 and vertex.co.y < -.17 and vertex.co.z < 1.10:
            paint(vertex, (1.0, .05, .02))
    image = bpy.data.images.new("B01 weapon region", width, height, alpha=True)
    image.pixels[:] = pixels
    image.filepath_raw = str(ROOT / case / "weapon-mask-front.png")
    image.file_format = "PNG"
    image.save()
