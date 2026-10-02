"""Gloved hands with five fingers in a relaxed curl, and the lace ruffles that
spill from under the cuffs."""
import math
from mathutils import Vector, Matrix, Quaternion
from .geom import build_mesh, grid_faces, frame, superellipse, smoothstep, lerp
from . import skeleton as sk


def capsule(name, points, radius, material, sides=10):
    """Tube with rounded ends; radius(t) along the polyline."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    rings, uvs = [], []
    verts = []
    caps = 4
    d0 = (pts[1] - pts[0]).normalized()
    d1 = (pts[-1] - pts[-2]).normalized()
    prev = None
    centres, frames, radii = [], [], []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        u, v = frame(d, Vector((0, 0, 1)) if prev is None else prev)
        prev = u
        centres.append(p)
        frames.append((u, v, d))
        radii.append(radius(i / (n - 1)))
    # Hemispherical end rings.
    seq = []
    u, v, d = frames[0]
    for k in range(caps, 0, -1):
        a = k / caps * math.pi / 2
        seq.append((centres[0] - d * radii[0] * math.sin(a), u, v, radii[0] * math.cos(a)))
    for c, (u, v, d), r in zip(centres, frames, radii):
        seq.append((c, u, v, r))
    u, v, d = frames[-1]
    for k in range(1, caps + 1):
        a = k / caps * math.pi / 2
        seq.append((centres[-1] + d * radii[-1] * math.sin(a), u, v, radii[-1] * math.cos(a)))
    for j, (c, u, v, r) in enumerate(seq):
        for k in range(sides):
            ang = k / sides * math.tau
            verts.append(c + max(r, 0.001) * (math.cos(ang) * u + math.sin(ang) * v))
            uvs.append((k / sides, j / (len(seq) - 1)))
    faces = grid_faces(len(seq), sides, closed=True)
    return build_mesh(name, verts, faces, uvs, material)


def build_hand(sign, material):
    s = sk.side_name(sign)
    wrist = sk.head(s + 'Hand')
    L = (sk.tail(s + 'Hand') - wrist).normalized()
    # Palm faces the thigh (toward the body), the thumb points forward (-Y).
    P = Vector((-sign, 0, 0))
    P = (P - L * P.dot(L)).normalized()
    W = L.cross(P).normalized()
    if W.y > 0:
        W = -W
    obs = []
    # Palm: rounded block from the wrist to the knuckles.
    rows, cols = 8, 20
    verts, uvs = [], []
    for j in range(rows):
        t = j / (rows - 1)
        width = lerp(2.9, 4.1, smoothstep(0, 0.8, t))
        thick = lerp(1.75, 1.35, t)
        c = wrist + L * (t * 8.4) - P * 0.15
        for i in range(cols):
            th = i / cols * math.tau
            x, y = superellipse(width, thick, th, 2.6)
            verts.append(c + W * x + P * y)
            uvs.append((i / cols, t))
    faces = grid_faces(rows, cols, closed=True)
    faces.append(tuple(range(cols - 1, -1, -1)))
    faces.append(tuple(range((rows - 1) * cols, rows * cols)))
    if sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    obs.append(build_mesh('Glove palm', verts, faces, uvs, material))
    # Fingers: index (thumb side) to little finger.
    knuckle = wrist + L * 8.2
    fingers = [(2.75, 7.4, 0.95, 7), (0.92, 8.1, 0.98, 9), (-0.92, 7.6, 0.93, 12), (-2.65, 6.1, 0.83, 16)]
    for off, length, rad, curl in fingers:
        base = knuckle + W * off - P * 0.1
        segs = [0.46, 0.30, 0.24]
        bends = [curl, curl + 9, curl + 4]
        spread = W * off * 0.035
        pts = [base]
        p = base
        theta = 0.0
        # Each joint curls further toward the palm side.
        for seg, bend in zip(segs, bends):
            theta += math.radians(bend)
            d = (L * math.cos(theta) + P * math.sin(theta) + spread).normalized()
            for k in range(1, 4):
                pts.append(p + d * length * seg * k / 3)
            p = pts[-1]
        obs.append(capsule('Glove finger', pts, lambda t, r=rad: r * (1 - 0.22 * t), material, sides=10))
    # Thumb from the base of the palm, toward the palm side.
    base = wrist + L * 2.4 + W * 2.9 + P * 0.35
    d = (L * 0.55 + W * 0.62 + P * 0.55).normalized()
    pts = [base]
    p = base
    for seg in (4.2, 3.4):
        d = (d + P * 0.18 + L * 0.12).normalized()
        for k in range(1, 4):
            pts.append(p + d * seg * k / 3)
        p = pts[-1]
    obs.append(capsule('Glove thumb', pts, lambda t: 1.18 * (1 - 0.25 * t), material, sides=10))
    return obs, (wrist, L, P, W)


def build_ruffle(sign, material, sides=48):
    """White lace jabot cuff: a short flared ring with a lively scalloped edge."""
    s = sk.side_name(sign)
    e, w = sk.tail(s + 'Arm'), sk.tail(s + 'ForeArm')
    axis = (w - e).normalized()
    u, v = frame(axis, Vector((0, 1, 0)))
    base = e.lerp(w, 0.86)
    rows = 6
    verts, uvs = [], []
    for j in range(rows):
        h = j / (rows - 1)
        for k in range(sides + 1):
            q = k / sides
            ang = q * math.tau
            wave = math.sin(ang * 13) * 0.55 * h ** 1.4
            r = 4.3 + 1.9 * h ** 1.2 + wave
            along = h * 4.2 + 0.45 * math.cos(ang * 13 + 0.6) * h ** 2
            verts.append(base + axis * along + r * (math.cos(ang) * u + math.sin(ang) * v))
            uvs.append((q * 6.0, h))
    faces = grid_faces(rows, sides + 1)
    if sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    return build_mesh('Lace ruffle ' + s, verts, faces, uvs, material)
