"""Jewellery, trims and hardware: gems in gold settings, the back yoke chain,
shoulder stars, waist clasps, sash, hip chain, tail pendants and boot straps.
Every object carries a `bind` hint for skinning (see rig.py)."""
import math
from mathutils import Vector
from .geom import (build_mesh, grid_faces, frame, tube, catmull, resample, closest_on, lerp, smoothstep,
                   recalc_normals)
from . import skeleton as sk


def tag(ob, bind):
    ob['bind'] = bind
    return ob


def diamond_gem(name, centre, up, out, size, material, bind):
    up = Vector(up).normalized()
    out = Vector(out).normalized()
    side = up.cross(out).normalized()
    c = Vector(centre)
    pts = [c + up * size * 1.35, c - up * size * 1.35,
           c + side * size * 0.78, c - side * size * 0.78,
           c + out * size * 0.55, c - out * size * 0.25,
           c + up * size * 0.45 + out * size * 0.42, c - up * size * 0.45 + out * size * 0.42]
    # Crown facets (front) and a flatter pavilion (back).
    faces = [(0, 6, 2), (0, 3, 6), (6, 4, 2), (6, 3, 4), (4, 7, 2), (4, 3, 7), (7, 1, 2), (7, 3, 1),
             (0, 2, 5), (0, 5, 3), (1, 5, 2), (1, 3, 5)]
    ob = build_mesh(name, pts, faces, [(0.5, 0.5)] * len(pts), material, smooth=False)
    recalc_normals(ob)
    return tag(ob, bind)


def star_gem(name, centre, normal, up, size, material, bind, points=4):
    n = Vector(normal).normalized()
    up = (Vector(up) - n * Vector(up).dot(n)).normalized()
    side = n.cross(up)
    c = Vector(centre)
    verts = [c + n * size * 0.42]
    ring = []
    for k in range(points * 2):
        a = k / (points * 2) * math.tau
        r = size if k % 2 == 0 else size * 0.36
        ring.append(c + (up * math.cos(a) + side * math.sin(a)) * r)
    verts += ring
    back = c - n * size * 0.12
    verts.append(back)
    m = len(ring)
    faces = [(0, 1 + k, 1 + (k + 1) % m) for k in range(m)]
    faces += [(m + 1, 1 + (k + 1) % m, 1 + k) for k in range(m)]
    ob = build_mesh(name, verts, faces, [(0.5, 0.5)] * len(verts), material, smooth=False)
    recalc_normals(ob)
    return tag(ob, bind), ring


def tassel(name, top, length, radius, material, bind, axis=Vector((0, 0, -1))):
    axis = Vector(axis).normalized()
    u, v = frame(axis, Vector((1, 0, 0)))
    rows, cols = 9, 18
    verts, uvs = [], []
    for j in range(rows):
        h = j / (rows - 1)
        # Bulb-shaped cap, a tied neck, then a flaring fringe.
        if h < 0.25:
            r = radius * (0.45 + 0.55 * math.sin(h / 0.25 * math.pi / 2))
        elif h < 0.33:
            r = radius * 0.62
        else:
            r = radius * (0.7 + 0.55 * (h - 0.33) / 0.67)
        for i in range(cols):
            a = i / cols * math.tau
            groove = 0.12 * radius * math.cos(a * 9) * smoothstep(0.33, 0.4, h)
            verts.append(Vector(top) + axis * length * h + (r + groove) * (math.cos(a) * u + math.sin(a) * v))
            uvs.append((i / cols, h))
    faces = grid_faces(rows, cols, closed=True)
    faces.append(tuple(range(cols - 1, -1, -1)))
    faces.append(tuple(range((rows - 1) * cols, rows * cols)))
    return tag(build_mesh(name, verts, faces, uvs, material), bind)


def chain(name, points, link, material, bind):
    """Alternating oval links along a path."""
    pts = resample(points, max(3, int(sum((Vector(b) - Vector(a)).length
                                         for a, b in zip(points, points[1:])) / (link * 1.55))))
    obs = []
    for k, p in enumerate(pts[:-1]):
        d = (pts[k + 1] - p)
        if d.length < 1e-4:
            continue
        u, v = frame(d, Vector((0, 1, 0)))
        w = u if k % 2 == 0 else v
        c = p + d * 0.5
        ring = [c + d.normalized() * math.cos(a) * link * 0.95 + w * math.sin(a) * link * 0.55
                for a in [i / 12 * math.tau for i in range(13)]]
        obs.append(tube(name, ring, link * 0.17, material, sides=5, caps=False))
    for o in obs:
        tag(o, bind)
    return obs


def ribbon(name, points, width, material, bind, twist=0.0, normal_hint=Vector((0, 1, 0))):
    pts = resample(catmull(points, 6), 28)
    n = len(pts)
    verts, uvs = [], []
    prev = None
    acc = 0.0
    for i, p in enumerate(pts):
        t = i / (n - 1)
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        u, v = frame(d, normal_hint if prev is None else prev)
        prev = u
        a = twist * t
        across = v * math.cos(a) + u * math.sin(a)
        w = width * (1.0 - 0.15 * t)
        if i:
            acc += (pts[i] - pts[i - 1]).length
        # A swallowtail notch at the end.
        for x in (-1.0, -0.5, 0.0, 0.5, 1.0):
            cut = (1 - abs(x)) * 2.2 * smoothstep(0.93, 1.0, t)
            verts.append(p + across * x * w - d * cut)
            uvs.append(((x + 1) / 2, acc / 60.0))
    faces = grid_faces(n, 5)
    return tag(build_mesh(name, verts, faces, uvs, material), bind)


def on_back(torso, x, z, push):
    # From behind: of the nearest surface points, keep the one closest to (x, z).
    best = None
    for y in [16.0, 15.0, 14.0, 13.0, 12.0]:
        q, nn = closest_on(torso, Vector((x, y, z)), 0)
        if best is None or abs(q.x - x) + abs(q.z - z) < best[2]:
            best = (q, nn, abs(q.x - x) + abs(q.z - z))
    q, nn, _ = best
    return q + nn * push, nn


def build_details(parts, mats, style, torso, tails, sleeves_hole, outfit):
    gold, gem = mats['gold'], mats['gem']
    obs = []
    # ---- Back yoke: a beaded V of gold across the shoulder blades, with a pendant.
    yoke = []
    for k in range(25):
        t = k / 24
        x = lerp(13.2, -13.2, t)
        z = 131.4 + 5.2 * (abs(x) / 13.2) ** 1.6
        q, n = on_back(torso, x, z, 0.32)
        yoke.append(q)
    obs.append(tag(tube('Yoke chain', yoke, lambda t: 0.27 + 0.10 * abs(math.sin(t * math.pi * 22)), gold,
                        sides=6), 'spine'))
    centre, n = on_back(torso, 0.0, 131.0, 0.55)
    frame_pts = [centre + Vector((0, 0, 2.2)), centre + Vector((1.5, 0, 0)), centre + Vector((0, 0, -2.2)),
                 centre + Vector((-1.5, 0, 0)), centre + Vector((0, 0, 2.2))]
    obs.append(tag(tube('Yoke bezel', frame_pts, 0.24, gold, sides=6), 'spine'))
    obs.append(diamond_gem('Yoke gem', centre + n * 0.25, (0, 0, 1), n, 1.25, gem, 'spine'))
    obs.append(tassel('Yoke tassel', centre - Vector((0, 0, 2.6)) + n * 0.2, 5.0, 0.62, gold, 'spine'))
    # ---- Princess seams in gold piping, waist to armhole.
    for sign in (1, -1):
        seam = []
        for k in range(30):
            t = k / 29
            x = sign * (5.2 + 8.2 * t ** 1.6)
            z = 101.6 + 31.0 * t
            q, n = on_back(torso, x, z, 0.12)
            seam.append(q)
        obs.append(tag(tube('Princess seam', seam, 0.17, gold, sides=6), 'spine'))
        # Waist clasps either side of the vent.
        q, n = on_back(torso, sign * 4.3, 103.3, 0.35)
        plate = [q + Vector((0, 0, 1.6)), q + Vector((sign * 1.3, 0, 0)), q + Vector((0, 0, -1.6)),
                 q + Vector((-sign * 1.3, 0, 0)), q + Vector((0, 0, 1.6))]
        obs.append(tag(tube('Waist clasp', plate, 0.3, gold, sides=6), 'hips'))
        obs.append(diamond_gem('Waist gem', q + n * 0.3, (0, 0, 1), n, 0.7, gem, 'hips'))
        # Shoulder star medallions on the sleeve heads.
        ring = sleeves_hole[sign]
        top = max(ring, key=lambda p: p.z + 0.35 * p.y)
        nrm = (top - Vector((sign * 15.4, 7.9, 134.6))).normalized()
        star, outline = star_gem('Shoulder star', top + nrm * 0.45, nrm, Vector((sign * 0.4, 0.3, 1)), 1.55, gem,
                                 'shoulder' + ('L' if sign > 0 else 'R'))
        obs.append(star)
        obs.append(tag(tube('Star setting', outline + [outline[0]], 0.18, gold, sides=5),
                       'shoulder' + ('L' if sign > 0 else 'R')))
        for k, (a0, a1) in enumerate([(0.0, 2.6), (3.2, 5.8)]):
            u, v = frame(nrm, Vector((0, 0, 1)))
            arc = [top + nrm * 0.3 + (u * math.cos(a) + v * math.sin(a)) * (2.3 + 0.35 * (a - a0))
                   for a in [lerp(a0, a1, i / 14) for i in range(15)]]
            obs.append(tag(tube('Shoulder scroll', arc, lambda t: 0.2 * (1 - 0.5 * t) + 0.04, gold, sides=5),
                           'shoulder' + ('L' if sign > 0 else 'R')))
    # ---- Pendants on every point of the hem (one per tail, two on the carnival cut).
    for side, (tail, edges) in tails.items():
        hem = edges['hem']
        tips = [hem[i] for i in range(1, len(hem) - 1) if hem[i].z < hem[i - 1].z and hem[i].z <= hem[i + 1].z]
        if hem[0].z < hem[1].z:
            tips.append(hem[0])
        bind = 'tip' + side
        for tip in tips:
            obs.append(tassel('Tip cap', tip + Vector((0, 0.3, 0.6)), 1.6, 0.55, gold, bind))
            obs.append(diamond_gem('Tip gem', tip + Vector((0, 0.3, -2.4)), (0, 0, 1), (0, 1, 0), 1.05, gem, bind))
    # ---- Sash on the left hip: a bow with two loops and two long, twisting tails.
    sash = mats['sash']
    knot, n = on_back(torso, 11.8, 101.2, 1.2)
    obs.append(tag(tube('Sash knot', [knot + Vector((-0.9, 0, 0.3)), knot + Vector((0, 0.5, 0)),
                                      knot + Vector((0.9, 0, -0.3))], 1.35, sash, sides=12, flat=0.7), 'ribbonL'))
    for sgn, (dx, dz) in ((1, (5.2, 2.6)), (-1, (-4.4, 3.2))):
        loop = [knot, knot + Vector((dx * 0.45, 1.6, dz * 1.1)), knot + Vector((dx, 2.0, dz * 0.6)),
                knot + Vector((dx * 0.95, 1.7, -dz * 0.2)), knot + Vector((dx * 0.4, 1.0, -0.6)), knot]
        obs.append(ribbon('Sash loop', loop, 1.35, sash, 'ribbonL', twist=0.4 * sgn))
    obs.append(ribbon('Sash tail', [knot, knot + Vector((2.2, 3.4, -9)), knot + Vector((5.0, 5.0, -20)),
                                    knot + Vector((6.8, 6.2, -34))], 2.1, sash, 'ribbonL', twist=1.3))
    obs.append(ribbon('Sash tail', [knot, knot + Vector((0.4, 2.8, -7)), knot + Vector((1.4, 4.2, -15)),
                                    knot + Vector((2.8, 5.2, -26))], 1.8, sash, 'ribbonL', twist=-1.0))
    obs.append(tassel('Sash tassel', knot + Vector((7.0, 6.4, -34.5)), 3.8, 0.6, gold, 'ribbonL'))
    # ---- Hip chain with amethyst drops on the right.
    start, n = on_back(torso, -11.4, 101.2, 0.9)
    path = [start, start + Vector((-1.2, 2.4, -8)), start + Vector((-2.4, 4.2, -18)), start + Vector((-3.4, 5.6, -30))]
    curve = catmull(path, 6)
    obs.extend(chain('Hip chain', curve, 0.55, gold, 'ribbonR'))
    for t, size in ((0.3, 0.75), (0.63, 0.85), (0.98, 1.0)):
        p = curve[int(t * (len(curve) - 1))]
        obs.append(diamond_gem('Chain drop', p + Vector((0, 0.6, -1.4)), (0, 0, 1), (0, 1, 0), size, gem, 'ribbonR'))
    obs.append(tassel('Chain tassel', path[-1] + Vector((0, 0.6, -2.4)), 3.8, 0.6, gold, 'ribbonR'))
    return obs


def boot_hardware(sign, mats, shaft_pts):
    from .lower import leg_radius
    leather, gold = mats['leather'], mats['gold']
    obs = []
    s = sk.side_name(sign)
    knee, ankle = sk.tail(s + 'UpLeg'), sk.tail(s + 'Leg')
    for z, width in ((16.0, 1.5), (22.5, 1.5)):
        t = (knee.z - z) / (knee.z - ankle.z)
        c = knee.lerp(ankle, t)
        d = (ankle - knee).normalized()
        u, v = frame(d, Vector((0, 1, 0)))
        rr = 4.95 if z > 20 else 4.75
        rows = []
        verts, uvs = [], []
        for j in range(3):
            h = (j / 2 - 0.5) * width
            for k in range(33):
                a = k / 32 * math.tau
                verts.append(c - d * h + (rr + 0.28) * (math.cos(a) * u + math.sin(a) * v))
                uvs.append((k / 32, j / 2))
        faces = grid_faces(3, 33)
        obs.append(tag(build_mesh('Boot strap', verts, faces, uvs, leather), 'leg' + ('L' if sign > 0 else 'R')))
        # Buckle on the outer side.
        out = Vector((sign, 0, 0))
        b = c + out * (rr + 0.55)
        sq = [b + Vector((0, 1.0, 0.9)), b + Vector((0, -1.0, 0.9)), b + Vector((0, -1.0, -0.9)),
              b + Vector((0, 1.0, -0.9)), b + Vector((0, 1.0, 0.9))]
        obs.append(tag(tube('Buckle', sq, 0.22, gold, sides=5), 'leg' + ('L' if sign > 0 else 'R')))
    # Rolled top edge.
    top = shaft_pts[0]
    d = (shaft_pts[1] - shaft_pts[0]).normalized()
    u, v = frame(d, Vector((0, 1, 0)))
    ring = [top + d * 0.3 + 5.55 * (math.cos(a) * u + math.sin(a) * v) for a in [k / 36 * math.tau for k in range(37)]]
    obs.append(tag(tube('Boot rim', ring, 0.55, leather, sides=8, caps=False), 'leg' + ('L' if sign > 0 else 'R')))
    return obs


def thigh_strap(sign, mats):
    from .lower import leg_points, leg_radius
    pts = leg_points(sign)
    p = min(pts, key=lambda q: abs(q.z - 73.0))
    i = pts.index(p)
    d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
    u, v = frame(d, Vector((0, 1, 0)))
    r = leg_radius(p.z) * 1.05 + 0.3
    ring = [p + r * (math.cos(a) * u + math.sin(a) * v) for a in [k / 36 * math.tau for k in range(37)]]
    s = 'L' if sign > 0 else 'R'
    obs = [tag(tube('Thigh strap', ring, 0.45, mats['leather'], sides=6, caps=False, flat=1.6), 'upleg' + s)]
    b = p + Vector((sign, -0.4, 0)).normalized() * (r + 0.4)
    sq = [b + Vector((0, 0.9, 0.8)), b + Vector((0, -0.9, 0.8)), b + Vector((0, -0.9, -0.8)), b + Vector((0, 0.9, -0.8)),
          b + Vector((0, 0.9, 0.8))]
    obs.append(tag(tube('Strap buckle', sq, 0.2, mats['gold'], sides=5), 'upleg' + s))
    return obs


def earrings(mats):
    obs = []
    for sign in (1, -1):
        c = Vector((sign * 8.7, 8.0, 156.2))
        obs.append(tag(tube('Ear hoop', [c + Vector((0, 0, 1.2)), c + Vector((sign * 0.3, 0, 0.4)), c], 0.12,
                            mats['gold'], sides=5), 'head'))
        obs.append(diamond_gem('Ear drop', c + Vector((0, 0, -1.3)), (0, 0, 1), (sign, 0.4, 0), 0.55, mats['gem'], 'head'))
    return obs


def epaulettes(mats, holes):
    """Carnival: domed gold shoulder boards with a hanging bullion fringe and a ruby."""
    gold, gem = mats['gold'], mats['gem']
    obs = []
    for sign in (1, -1):
        ring = holes[sign]
        top = max(ring, key=lambda p: p.z)
        n = Vector((sign * 0.38, 0.05, 1.0)).normalized()
        along = Vector((sign, 0, -0.38)).normalized()
        across = n.cross(along).normalized()
        c = top + n * 2.3 + along * 0.4
        rows, cols = 6, 28
        verts = []
        for j in range(rows):
            r = j / (rows - 1)
            for i in range(cols):
                a = i / cols * math.tau
                x = 4.3 * r * math.cos(a)
                y = 2.9 * r * math.sin(a)
                h = 1.1 * (1 - r * r)
                verts.append(c + along * x + across * y + n * h)
        faces = grid_faces(rows, cols, closed=True)
        faces.append(tuple(range(cols - 1, -1, -1)))
        b = 'shoulder' + ('L' if sign > 0 else 'R')
        plate = tag(build_mesh('Epaulette', verts, faces, [(0.5, 0.5)] * len(verts), gold), b)
        recalc_normals(plate)
        obs.append(plate)
        rim = [c + along * 4.3 * math.cos(a) + across * 2.9 * math.sin(a) for a in [k / 40 * math.tau for k in range(41)]]
        obs.append(tag(tube('Epaulette rim', rim, 0.32, gold, sides=6, caps=False), b))
        for k in range(15):
            a = -math.pi / 2 + k / 14 * math.pi
            root = c + along * 4.1 * math.cos(a) + across * 2.7 * math.sin(a)
            out = (along * math.cos(a) + across * math.sin(a)).normalized()
            pts = [root, root + out * 0.6 + Vector((0, 0, -1.6)), root + out * 0.9 + Vector((0, 0, -4.4))]
            obs.append(tag(tube('Epaulette fringe', catmull(pts, 3), lambda t: 0.2 * (1 - 0.35 * t), gold, sides=5), b))
        star, outline = star_gem('Epaulette gem', c + n * 1.1, n, across, 1.1, gem, b)
        obs.append(star)
    return obs
