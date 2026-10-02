"""Tailored long coat: fitted torso, stand collar, set-in sleeves with turned-back
cuffs, and a split skirt whose tails fall to pointed, weighted hems."""
import math
from mathutils import Vector
from .geom import (superellipse, smoothstep, lerp, grid_faces, build_mesh, frame, tube,
                   catmull, resample)
from . import skeleton as sk
from . import atlas

# Torso sections: z -> (half width, half depth, centre y, exponent). +Y is the back.
TORSO = [
    (95.0, 16.2, 10.0, 5.6, 2.25),
    (100.0, 14.9, 9.3, 5.6, 2.25),
    (104.0, 13.6, 8.7, 5.7, 2.25),
    (112.0, 14.4, 9.3, 6.0, 2.25),
    (120.0, 15.8, 10.0, 6.4, 2.3),
    (128.0, 17.0, 10.5, 6.8, 2.3),
    (134.0, 17.0, 10.3, 7.2, 2.3),
    (139.0, 15.6, 9.6, 7.6, 2.2),
]
NECK_RING = (6.7, 6.3, 8.2, 147.6)  # half width, half depth, centre y, z


def torso_section(z):
    for (z0, *a), (z1, *b) in zip(TORSO, TORSO[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return [lerp(x, y, t) for x, y in zip(a, b)]
    return list(TORSO[-1][1:])


def back_relief(x, z):
    """Shoulder blades and a soft spine channel, applied on the back half."""
    blades = 0.9 * math.exp(-((abs(x) - 8.0) / 5.0) ** 2 - ((z - 127.0) / 7.5) ** 2)
    spine = -0.45 * math.exp(-(x / 2.2) ** 2) * smoothstep(104, 112, z) * (1 - smoothstep(134, 140, z))
    waist = -0.35 * math.exp(-((z - 104.0) / 5.0) ** 2)
    return blades + spine + waist


def torso_rings(cols=64):
    rings = []
    zs = [95 + i * 1.5 for i in range(30)]  # up to 138.5
    zs.append(139.0)
    for z in zs:
        a, b, cy, n = torso_section(z)
        ring = []
        for i in range(cols):
            th = -math.pi / 2 + i / cols * math.tau  # column 0 at the front centre
            x, y = superellipse(a, b, th, n)
            if y > 0:
                y += back_relief(x, z) * (y / b)
            ring.append(Vector((x, cy + y, z)))
        rings.append(ring)
    # Shoulder dome: structured, slightly squared shoulders rising to the neckline.
    a0, b0, cy0, n0 = torso_section(139.0)
    na, nb, ncy, nz = NECK_RING
    steps = 14
    for k in range(1, steps + 1):
        s = k / steps
        a = na + (a0 - na) * (1 - s) ** 1.35
        b = nb + (b0 - nb) * (1 - s) ** 1.2
        cy = lerp(cy0, ncy, s)
        z = 139.0 + (nz - 139.0) * s ** 0.55
        n = lerp(n0, 2.0, s)
        ring = []
        for i in range(cols):
            th = -math.pi / 2 + i / cols * math.tau
            x, y = superellipse(a, b, th, n)
            # The trapezius slopes; front and back of the dome stay a touch lower.
            zz = z - 0.9 * (abs(y) / max(b, 1e-3)) ** 2 * (1 - s) * s * 4
            ring.append(Vector((x, cy + y, zz)))
        rings.append(ring)
    return rings


def build_torso(material, cols=64):
    rings = torso_rings(cols)
    verts = [p for r in rings for p in r]
    faces = grid_faces(len(rings), cols, closed=True)
    # Centimetre unwrap: arc length around each ring from the back centre (u) and
    # length up each column (v). The seam sits at the front centre.
    uvs, periods = [], []
    col_len = [0.0] * cols
    for j, r in enumerate(rings):
        arc = [0.0]
        for i in range(1, cols):
            arc.append(arc[-1] + (r[i] - r[i - 1]).length)
        perimeter = arc[-1] + (r[0] - r[-1]).length
        periods.append(perimeter)
        back = arc[cols // 2]
        for i, p in enumerate(r):
            if j:
                col_len[i] += (p - rings[j - 1][i]).length
            uvs.append(atlas.uv('torso', 48.0 + arc[i] - back, 2.0 + col_len[i]))
    periods = [pp / atlas.SIZE_CM for pp in periods]
    ob = build_mesh('Coat torso', verts, faces, uvs, material, wrap=(cols, periods))
    return ob, rings


def collar(material, cols=56):
    """Stand collar, open at the throat, slightly flared with raised side points."""
    na, nb, ncy, nz = NECK_RING
    verts, uvs = [], []
    rows = 9
    gap = math.radians(52)  # opening at the front (-Y)
    z_base = nz - 1.4
    for j in range(rows):
        h = j / (rows - 1)
        for i in range(cols):
            u = i / (cols - 1)
            # theta runs from front-left around the back to front-right.
            th = -math.pi / 2 + gap / 2 + u * (math.tau - gap)
            flare = 1.0 + 0.30 * h ** 1.6
            x = (na + 0.25) * flare * math.cos(th)
            y = ncy + (nb + 0.35) * flare * math.sin(th)
            back = max(0.0, math.sin(th))
            sidept = math.exp(-((abs(math.cos(th)) - 0.82) / 0.16) ** 2) * (1 - back)
            height = 5.0 + 1.1 * back + 1.8 * sidept
            z = nz - 1.4 + height * h
            verts.append(Vector((x, y, z)))
    for j in range(rows):
        row = verts[j * cols:(j + 1) * cols]
        arc = [0.0]
        for i in range(1, cols):
            arc.append(arc[-1] + (row[i] - row[i - 1]).length)
        for i, p in enumerate(row):
            uvs.append(atlas.uv('collar', 23.0 + arc[i] - arc[-1] / 2, 1.0 + (p.z - z_base)))
    faces = grid_faces(rows, cols, closed=False)
    ob = build_mesh('Stand collar', verts, faces, uvs, material)
    top = [verts[(rows - 1) * cols + i] for i in range(cols)]
    front_l = [verts[j * cols] for j in range(rows)]
    front_r = [verts[j * cols + cols - 1] for j in range(rows)]
    return ob, top, front_l, front_r


# ---------------------------------------------------------------- skirt / tails
VENT_TOP = math.radians(1.5)
FRONT = math.radians(168)
TIP_PHI = math.radians(47)


def hem_z(phi, style):
    """Hem height around one side; phi from the back centre (0) toward the front."""
    d = math.degrees(phi)
    tip, tz = math.degrees(TIP_PHI), style['tip_z']
    if d >= tip:
        k = (d - tip) / (168 - tip)
        z = tz + style['side_rise'] * k ** 0.72
    else:
        z = tz + style['vent_rise'] * ((tip - d) / tip) ** 0.9
    if 'second_phi' in style:
        # A second, shorter point (carnival): the hem dips to another V.
        z = min(z, style['second_z'] + style['second_slope'] * abs(d - style['second_phi']))
    return z


def vent_phi(t, style):
    return VENT_TOP + (style['vent_open'] - VENT_TOP) * t ** 1.35


def skirt_point(side, u, t, style):
    """u: 0 vent edge .. 1 front edge; t: 0 waist .. 1 hem."""
    sign = 1 if side == 'L' else -1
    phi = lerp(vent_phi(t, style), FRONT, u)
    top_z = 100.5
    z_end = hem_z(phi, style)
    z = top_z - (top_z - z_end) * t
    tt = t ** 1.05
    ax = lerp(15.3, style['flare_x'], tt)
    by = lerp(9.6, style['flare_back'], tt)
    bf = lerp(9.6, style['flare_front'], tt)
    cy = 5.7 + 1.2 * t
    b = by if phi < math.pi / 2 else lerp(by, bf, smoothstep(math.pi / 2, FRONT, phi))
    # Folds: a few broad godets that deepen toward the hem, more on the back.
    f = style['fold'] * t ** 1.25
    fold = (0.62 * math.sin(4.3 * phi + 0.9 + 0.4 * sign) + 0.28 * math.sin(8.1 * phi + 2.1)
            + 0.10 * math.sin(12.6 * phi + 0.4 * sign))
    r_extra = f * fold
    # The pointed tail swings out a little further than the rest of the hem.
    r_extra += style['tip_swing'] * t ** 2.2 * math.exp(-((phi - TIP_PHI) / math.radians(30)) ** 2)
    x = sign * (ax + r_extra) * math.sin(phi)
    y = cy + (b + r_extra) * math.cos(phi)
    # Cloth weight: the back tails hang slightly away from the calves.
    y += style['hang'] * t ** 1.6 * max(0.0, math.cos(phi))
    return Vector((x, y, z)), phi


def build_tail(side, style, material, cols=34, rows=46):
    verts, uvs, params = [], [], []
    for j in range(rows):
        t = j / (rows - 1)
        row = []
        for i in range(cols):
            u = i / (cols - 1)
            p, phi = skirt_point(side, u, t, style)
            row.append(p)
            params.append((u, t, phi))
        verts.extend(row)
    # Physical UVs: arc length along each row from the vent edge, length down the column.
    uvs = [None] * len(verts)
    col_len = [0.0] * cols
    for j in range(rows):
        acc = 0.0
        for i in range(cols):
            k = j * cols + i
            if i:
                acc += (verts[k] - verts[k - 1]).length
            if j:
                col_len[i] += (verts[k] - verts[k - cols]).length
            uvs[k] = (acc, col_len[i])
    hem_uv = [atlas.to_canvas('tail', 1.0 + uvs[(rows - 1) * cols + i][0], 99.0 - uvs[(rows - 1) * cols + i][1])
              for i in range(cols)]
    tip_uv = None
    uvs = [atlas.uv('tail', 1.0 + a, 99.0 - b) for a, b in uvs]
    if side == 'R':
        faces = [tuple(reversed(f)) for f in grid_faces(rows, cols)]
    else:
        faces = grid_faces(rows, cols)
    ob = build_mesh('Coat tail ' + side, verts, faces, uvs, material)
    ob['params'] = [list(p) for p in params]
    ob['hem_uv'] = [list(p) for p in hem_uv]
    edges = {
        'vent': [verts[j * cols] for j in range(rows)],
        'front': [verts[j * cols + cols - 1] for j in range(rows)],
        'hem': [verts[(rows - 1) * cols + i] for i in range(cols)],
        'waist': [verts[i] for i in range(cols)],
    }
    return ob, edges, (rows, cols)


# ---------------------------------------------------------------- sleeves
def arm_chain(sign):
    s = sk.side_name(sign)
    a, e = sk.head(s + 'Arm'), sk.tail(s + 'Arm')
    w = sk.tail(s + 'ForeArm')
    return a, e, w


def sleeve_path(sign, samples=40):
    a, e, w = arm_chain(sign)
    # Start a little inside the shoulder so the cap overlaps the torso armhole.
    start = a + (a - e).normalized() * 1.2 + Vector((-0.8 if sign > 0 else 0.8, 0, 0.9))
    pts = catmull([start, a.lerp(e, 0.5), e, e.lerp(w, 0.55), w.lerp(e, 0.12)], 10)
    return resample(pts, samples)


def sleeve_radius(t):
    # Puffed cap, slim upper arm, ease at the elbow, tapering to the cuff.
    r = 6.1 - 1.2 * smoothstep(0.0, 0.25, t) - 0.35 * smoothstep(0.45, 0.95, t)
    r += 0.25 * math.exp(-((t - 0.5) / 0.06) ** 2)
    return r


def build_sleeve(sign, material, sides=28):
    """Set-in sleeve: the first rings hug the armhole (a near-vertical ellipse at the
    shoulder seam) and turn to follow the arm, so the shoulder line stays round."""
    pts = sleeve_path(sign)
    n = len(pts)
    a, e, w = arm_chain(sign)
    hole_c = Vector((sign * 15.4, 7.9, 134.6))
    hole_n = Vector((sign * 1.0, 0.0, 0.42)).normalized()
    hole_ry, hole_rz = 6.0, 7.3
    blend_end = 0.2
    verts, uvs, periods = [], [], []
    acc = 0.0
    prev = None
    for i, p in enumerate(pts):
        t = i / (n - 1)
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        k = smoothstep(0.0, blend_end, t)
        axis = hole_n.lerp(d, k).normalized()
        centre = hole_c.lerp(p, smoothstep(0.0, blend_end * 1.2, t))
        # u: toward the back (+Y), v: completes the frame (roughly "up" at the hole).
        u, v = frame(axis, Vector((0, 1, 0)) if prev is None else prev)
        prev = u
        if i:
            acc += (pts[i] - pts[i - 1]).length
        r_arm = sleeve_radius(t)
        ry = lerp(hole_ry, r_arm, k)
        rz = lerp(hole_rz, r_arm, k)
        circ = math.tau * math.sqrt((ry * ry + rz * rz) / 2)
        periods.append(circ / atlas.SIZE_CM)
        for kk in range(sides):
            ang = math.pi + kk / sides * math.tau  # column 0 at the front of the arm
            fold = 0.18 * math.sin(ang * 3 + t * 9.0) * smoothstep(0.35, 0.9, t)
            crease = -0.35 * math.exp(-((t - 0.52) / 0.05) ** 2) * max(0, math.cos(ang - math.pi)) ** 2
            q = centre + (ry * (1 + fold * 0.12) + crease) * math.cos(ang) * u + (rz * (1 + fold * 0.12) + crease) * math.sin(ang) * v
            verts.append(q)
            uvs.append(atlas.uv('sleeve', 24.0 + (kk / sides - 0.5) * circ, 64.0 - acc))
    faces = grid_faces(n, sides, closed=True)
    if sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    ob = build_mesh('Sleeve ' + sk.side_name(sign), verts, faces, uvs, material, wrap=(sides, periods))
    end_ring = verts[(n - 1) * sides:]
    hole_ring = verts[:sides]
    return ob, pts, end_ring, hole_ring


def build_cuff(sign, material, sides=40):
    """Turned-back gauntlet cuff, flaring toward the hand, with a raised point
    at the back of the forearm."""
    a, e, w = arm_chain(sign)
    axis = (w - e).normalized()
    u, v = frame(axis, Vector((0, 1, 0)))  # u points toward the back (+Y)
    base = e.lerp(w, 0.60)
    length = 9.5
    rows = 12
    verts, uvs = [], []
    for j in range(rows):
        h = j / (rows - 1)
        for k in range(sides + 1):
            q = k / sides
            ang = math.pi + q * math.tau  # seam at the front; q = 0.5 is the back
            back = max(0.0, math.cos(ang))  # +u is the back of the forearm
            # The upper edge rises to a point at the back of the forearm.
            point = 4.2 * back ** 5
            r = 4.75 + 2.6 * h ** 1.3 + 0.35 * point / 4.2
            along = lerp(-point, length, h)
            p = base + axis * along + r * (math.cos(ang) * u + math.sin(ang) * v)
            verts.append(p)
            uvs.append(atlas.uv('cuff', 23.0 + (q - 0.5) * math.tau * r, 1.0 + along + 4.2))
    faces = grid_faces(rows, sides + 1)
    if sign < 0:
        faces = [tuple(reversed(f)) for f in faces]
    ob = build_mesh('Turned cuff ' + sk.side_name(sign), verts, faces, uvs, material)
    rim = verts[(rows - 1) * (sides + 1):]
    root = verts[:sides + 1]
    return ob, rim, root


def build_facing(side, style, material, rows=40, cols=7):
    """Lining turned back along the vent edge: a purple revers that widens toward
    the hem, raised just off the tail so it reads as folded cloth."""
    sign = 1 if side == 'L' else -1
    verts, uvs, outer = [], [], []
    run, t_prev = 0.0, 0.0
    for j in range(rows):
        t = 0.04 + 0.96 * j / (rows - 1)
        width = 1.0 + 7.5 * t ** 1.5
        # March along u until the arc length from the vent edge reaches `width`.
        us = [0.0]
        prev, _ = skirt_point(side, 0.0, t, style)
        acc, u = 0.0, 0.0
        while acc < width and u < 0.6:
            u += 0.004
            p, _ = skirt_point(side, u, t, style)
            acc += (p - prev).length
            prev = p
        umax = u
        if j:
            run += (skirt_point(side, 0.0, t, style)[0] - skirt_point(side, 0.0, t_prev, style)[0]).length
        t_prev = t
        for i in range(cols):
            uu = umax * i / (cols - 1)
            p, phi = skirt_point(side, uu, t, style)
            centre = Vector((0, 5.7 + 1.2 * t, p.z))
            out = (p - centre)
            out.z = 0
            out.normalize()
            # Roll: highest at the fold line (vent edge), settling onto the tail.
            lift = 0.55 + 0.35 * (1 - i / (cols - 1))
            verts.append(p + out * lift)
            uvs.append(atlas.uv('facing', 1.0 + width * i / (cols - 1), 93.0 - run))
        outer.append(verts[-1])
    faces = grid_faces(rows, cols)
    if side == 'R':
        faces = [tuple(reversed(f)) for f in faces]
    ob = build_mesh('Facing ' + side, verts, faces, uvs, material)
    fold_line = [verts[j * cols] for j in range(rows)]
    return ob, outer, fold_line


def build_capelet(material, rows=16, cols=44):
    """Half cape hung from the shoulder line across the back (starlight): it never
    wraps the arms, so raised casts do not cut through it."""
    verts = []
    span = math.radians(104)
    for j in range(rows):
        s = j / (rows - 1)
        for i in range(cols):
            u = i / (cols - 1)
            th = math.pi / 2 + (u - 0.5) * 2 * span  # pi/2 is the back centre
            side = abs(u - 0.5) * 2
            # Top edge follows the collar base and the shoulder seam.
            a_top, b_top = 7.8 + 11.2 * side ** 1.4, 7.3 + 3.4 * side
            z_top = 147.2 - 4.4 * side ** 1.6
            a_bot, b_bot = 22.8 + 1.5 * side, 15.4 - 1.0 * side
            z_bot = 117.5 + 9.5 * side ** 1.8
            a = lerp(a_top, a_bot, s ** 0.85)
            b = lerp(b_top, b_bot, s ** 0.85)
            z = lerp(z_top, z_bot, s)
            # Soft folds deepen toward the hem.
            fold = 0.7 * s ** 1.4 * math.sin(u * math.pi * 7 + 0.4)
            x = (a + fold) * math.cos(th)
            y = 7.8 + (b + fold) * math.sin(th)
            verts.append(Vector((x, y, z)))
    uvs = [None] * len(verts)
    col_len = [0.0] * cols
    for j in range(rows):
        acc = 0.0
        row = verts[j * cols:(j + 1) * cols]
        arcs = [0.0]
        for i in range(1, cols):
            arcs.append(arcs[-1] + (row[i] - row[i - 1]).length)
        for i in range(cols):
            k = j * cols + i
            if j:
                col_len[i] += (verts[k] - verts[k - cols]).length
            uvs[k] = atlas.uv('cape', 41.0 + arcs[i] - arcs[-1] / 2, 42.0 - col_len[i])
    # Outward-facing: the coat atlas outside, the lining (solidify shell) inside.
    faces = [tuple(reversed(f)) for f in grid_faces(rows, cols)]
    ob = build_mesh('Star capelet', verts, faces, uvs, material)
    hem = verts[(rows - 1) * cols:]
    ob['hem_uv'] = [[(uvs[(rows - 1) * cols + i][0]) * atlas.SIZE_CM, uvs[(rows - 1) * cols + i][1] * atlas.SIZE_CM]
                    for i in range(cols)]
    sides = [verts[j * cols] for j in range(rows)], [verts[j * cols + cols - 1] for j in range(rows)]
    return ob, hem, sides
