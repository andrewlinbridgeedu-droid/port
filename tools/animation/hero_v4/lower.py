"""Head, neck, ears, trousers and boots."""
import math
from mathutils import Vector
from .geom import (superellipse, smoothstep, lerp, grid_faces, build_mesh, frame, tube,
                   catmull, resample)
from . import skeleton as sk

HEAD_C = Vector((0, 8.4, 161.6))
HEAD_R = Vector((8.3, 9.3, 10.9))


def build_head(material, cols=40, rows=28):
    verts, uvs = [], []
    for j in range(rows + 1):
        pol = j / rows * math.pi
        for i in range(cols):
            az = i / cols * math.tau
            x = math.sin(pol) * math.cos(az)
            y = math.sin(pol) * math.sin(az)
            z = math.cos(pol)
            p = Vector((x * HEAD_R.x, y * HEAD_R.y, z * HEAD_R.z))
            # Fuller occiput, narrower jaw and chin toward the (hidden) face.
            if y > 0:
                p.y *= 1.0 + 0.06 * math.exp(-((z - 0.1) / 0.45) ** 2)
            else:
                jaw = smoothstep(0.1, -0.75, z)
                p.x *= 1.0 - 0.28 * jaw
                p.y *= 1.0 - 0.10 * jaw
            if z < -0.55:
                p.z = -0.55 * HEAD_R.z + (z + 0.55) * HEAD_R.z * 0.8
            verts.append(HEAD_C + p)
            uvs.append((i / cols, j / rows))
    faces = grid_faces(rows + 1, cols, closed=True)
    # Poles collapse to points; drop degenerate quads at both ends.
    faces = faces[cols:-cols]
    ob = build_mesh('Head', verts, faces, uvs, material)
    return ob


def build_neck(material):
    pts = [Vector((0, 8.7, 139.0)), Vector((0, 8.6, 146.0)), Vector((0, 8.3, 153.0)), Vector((0, 8.0, 157.5))]
    return tube('Neck', catmull(pts, 4), lambda t: lerp(4.35, 3.75, t), material, sides=20,
                hint=Vector((0, 1, 0)), caps=False, flat=1.04)


def build_ears(material):
    obs = []
    for sign in (1, -1):
        c = Vector((sign * 8.05, 8.3, 160.2))
        verts, uvs = [], []
        rows, cols = 8, 12
        for j in range(rows + 1):
            pol = j / rows * math.pi
            for i in range(cols):
                az = i / cols * math.tau
                x = 0.9 * math.sin(pol) * math.cos(az)
                y = 2.1 * math.sin(pol) * math.sin(az)
                z = 3.1 * math.cos(pol)
                # Slight backward tilt.
                y2 = y + 0.25 * z
                verts.append(c + Vector((sign * abs(x) * 0.8 + sign * 0.2, y2, z)))
                uvs.append((i / cols, j / rows))
        faces = grid_faces(rows + 1, cols, closed=True)[cols:-cols]
        obs.append(build_mesh('Ear', verts, faces, uvs, material))
    return obs


# ------------------------------------------------------------- trousers
def leg_points(sign, samples=36):
    s = sk.side_name(sign)
    hip = sk.head(s + 'UpLeg') + Vector((0, 0.5, 2.0))
    knee = sk.tail(s + 'UpLeg')
    ankle = sk.tail(s + 'Leg')
    pts = catmull([hip, hip.lerp(knee, 0.5) + Vector((0, -0.4, 0)), knee + Vector((0, -0.6, 0)),
                   knee.lerp(ankle, 0.45) + Vector((0, 0.3, 0)), ankle.lerp(knee, 0.4)], 10)
    return resample(pts, samples)


def leg_radius(z):
    keys = [(96, 8.6), (86, 8.1), (75, 7.3), (64, 6.5), (54, 5.7), (49, 5.4), (44, 5.3), (38, 4.95), (30, 4.4)]
    for (z0, r0), (z1, r1) in zip(keys, keys[1:]):
        if z >= z1:
            t = (z0 - z) / (z0 - z1)
            return lerp(r0, r1, smoothstep(0, 1, t))
    return keys[-1][1]


def build_trouser_leg(sign, material, sides=26):
    pts = leg_points(sign)
    verts, uvs = [], []
    n = len(pts)
    prev = None
    acc = 0.0
    for i, p in enumerate(pts):
        d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        u, v = frame(d, Vector((0, 1, 0)) if prev is None else prev)
        prev = u
        if i:
            acc += (pts[i] - pts[i - 1]).length
        r = leg_radius(p.z)
        for k in range(sides):
            ang = k / sides * math.tau
            # Gentle knee folds at the back of the knee and a crease line in front.
            knee = math.exp(-((p.z - 50) / 3.0) ** 2)
            fold = 0.22 * knee * math.sin(ang * 4 + 0.6)
            rr = r * (1 + 0.05 * math.cos(ang) ** 2) + fold
            verts.append(p + rr * (math.cos(ang) * u + math.sin(ang) * v))
            uvs.append((k / sides, acc / 120.0))
    faces = grid_faces(n, sides, closed=True)
    if sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    return build_mesh('Trouser leg ' + sk.side_name(sign), verts, faces, uvs, material)


def build_pelvis(material, cols=48):
    # Kept well inside the coat's waist so it never shows through the tailoring.
    keys = [(104.0, 12.4, 7.6, 5.6), (100.0, 13.2, 8.0, 5.5), (93.0, 14.8, 9.2, 5.3), (87.0, 14.6, 9.1, 5.2),
            (83.5, 11.0, 7.0, 5.0)]
    rings = []
    for z, a, b, cy in keys:
        rings.append([Vector((*(lambda q: (q[0], cy + q[1]))(superellipse(a, b, i / cols * math.tau, 2.3)), z))
                      for i in range(cols)])
    verts = [p for r in rings for p in r]
    faces = grid_faces(len(rings), cols, closed=True)
    faces.append(tuple(range(len(verts) - cols, len(verts))))
    uvs = [(0.5 + p.x / 100, (p.z - 60) / 100) for p in verts]
    return build_mesh('Trouser seat', verts, faces, uvs, material)


# ------------------------------------------------------------- boots
FOOT = [  # y, half width, sole top z, top z
    (7.4, 0.9, 3.9, 9.5),
    (6.6, 3.3, 3.7, 12.3),
    (5.0, 4.3, 3.5, 13.4),
    (2.0, 4.55, 3.0, 13.0),
    (-1.5, 4.6, 2.2, 11.3),
    (-5.0, 4.8, 1.35, 9.0),
    (-8.5, 4.95, 0.95, 7.1),
    (-11.5, 4.75, 0.9, 6.2),
    (-14.0, 4.1, 0.95, 5.5),
    (-16.0, 3.0, 1.15, 4.8),
    (-17.3, 1.6, 1.4, 4.0),
    (-17.9, 0.4, 1.8, 3.2),
]


def build_boot_foot(sign, material, cols=28):
    s = sk.side_name(sign)
    ankle = sk.tail(s + 'Leg')
    rings = []
    for y, w, zb, zt in FOOT:
        cx = ankle.x - sign * 0.04 * (min(0.0, y)) ** 1.0 * 0.6
        cz = (zb + zt) / 2
        hh = (zt - zb) / 2
        ring = []
        for i in range(cols):
            th = i / cols * math.tau
            x, z = superellipse(w, hh, th, 2.6)
            # Flatten the sole side so the boot sits on its sole.
            if z < 0:
                z *= 0.82
            ring.append(Vector((cx + sign * x, y, cz + z)))
        rings.append(ring)
    verts = [p for r in rings for p in r]
    faces = grid_faces(len(rings), cols, closed=True)
    faces.append(tuple(range(cols - 1, -1, -1)))
    faces.append(tuple(range(len(verts) - cols, len(verts))))
    if sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    uvs = [(0.5 + (p.y) / 60, p.z / 60) for p in verts]
    return build_mesh('Boot foot ' + s, verts, faces, uvs, material)


def build_boot_shaft(sign, material, sides=30):
    s = sk.side_name(sign)
    knee, ankle = sk.tail(s + 'UpLeg'), sk.tail(s + 'Leg')
    top_t = (knee.z - 31.5) / (knee.z - ankle.z)
    top = knee.lerp(ankle, top_t)
    pts = resample([top, top.lerp(ankle, 0.5) + Vector((0, 0.2, 0)), ankle + Vector((0, 0.4, 0.5))], 22)
    verts, uvs = [], []
    n = len(pts)
    prev = None
    for i, p in enumerate(pts):
        t = i / (n - 1)
        d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        u, v = frame(d, Vector((0, 1, 0)) if prev is None else prev)
        prev = u
        # Calf curve under the leather, slimming to the ankle; a rolled top edge.
        r = lerp(5.15, 4.35, smoothstep(0.0, 1.0, t)) + 0.25 * math.sin(math.pi * min(1, t / 0.55)) * (1 - t)
        r += 0.3 * math.exp(-(t / 0.04) ** 2)
        for k in range(sides):
            ang = k / sides * math.tau
            # Leather slouch: a few soft rings of compression above the ankle.
            slouch = 0.16 * math.sin(t * 22.0 + ang * 0.0) * smoothstep(0.45, 0.9, t)
            verts.append(p + (r + slouch) * (math.cos(ang) * u + math.sin(ang) * v))
            uvs.append((k / sides, t * 0.3))
    faces = grid_faces(n, sides, closed=True)
    if sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    return build_mesh('Boot shaft ' + s, verts, faces, uvs, material), pts


def build_sole(sign, material):
    """Separate sole and stacked heel give the boot a crisp, manufactured edge."""
    s = sk.side_name(sign)
    ankle = sk.tail(s + 'Leg')
    outline = []
    for y, w, zb, zt in FOOT:
        outline.append((y, w + 0.35, zb))
    verts, faces = [], []
    cols = len(outline)
    # Two rails (outer, inner) x two levels; a simple closed slab.
    top_outer, top_inner, bot_outer, bot_inner = [], [], [], []
    for y, w, zb in outline:
        cy = y
        heel = y > 1.6
        bottom = 0.0
        top = zb if not heel else zb
        zbot = bottom if heel else max(0.0, zb - 0.95)
        top_outer.append(Vector((ankle.x + sign * w, cy, top)))
        top_inner.append(Vector((ankle.x - sign * w, cy, top)))
        bot_outer.append(Vector((ankle.x + sign * w, cy, zbot)))
        bot_inner.append(Vector((ankle.x - sign * w, cy, zbot)))
    verts = top_outer + top_inner + bot_outer + bot_inner
    n = cols
    TO, TI, BO, BI = 0, n, 2 * n, 3 * n
    for i in range(n - 1):
        faces.append((TO + i, TO + i + 1, TI + i + 1, TI + i))
        faces.append((BI + i, BI + i + 1, BO + i + 1, BO + i))
        faces.append((BO + i, BO + i + 1, TO + i + 1, TO + i))
        faces.append((TI + i, TI + i + 1, BI + i + 1, BI + i))
    faces.append((TO, TI, BI, BO))
    faces.append((TO + n - 1, BO + n - 1, BI + n - 1, TI + n - 1))
    if sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    uvs = [(0.5, 0.5)] * len(verts)
    return build_mesh('Boot sole ' + s, verts, faces, uvs, material, smooth=False)
