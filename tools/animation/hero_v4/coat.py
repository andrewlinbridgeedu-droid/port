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
    (104.0, 13.0, 8.5, 5.7, 2.25),
    (112.0, 14.0, 9.2, 6.0, 2.25),
    (120.0, 16.1, 10.0, 6.4, 2.3),
    (128.0, 17.6, 10.5, 6.8, 2.3),
    (134.0, 17.5, 10.3, 7.2, 2.3),
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
    """Shoulder blades, a soft spine channel and the cloth's own folds on the back:
    diagonal drag folds from the armpits toward the blades and fine pull lines
    above the waist seam."""
    blades = 0.9 * math.exp(-((abs(x) - 8.0) / 5.0) ** 2 - ((z - 127.0) / 7.5) ** 2)
    spine = -0.45 * math.exp(-(x / 2.2) ** 2) * smoothstep(104, 112, z) * (1 - smoothstep(134, 140, z))
    waist = -0.35 * math.exp(-((z - 104.0) / 5.0) ** 2)
    ax = abs(x)
    armpit = 0.32 * math.sin((ax * 0.55 + z * 0.45) * 1.25) * math.exp(-((ax - 13.5) / 3.2) ** 2
                                                                        - ((z - 125.0) / 6.0) ** 2)
    pull = 0.14 * math.sin(z * 2.1 + ax * 0.35) * smoothstep(101.0, 104.0, z) * (1 - smoothstep(108.0, 113.0, z)) \
        * smoothstep(1.5, 4.0, ax)
    return blades + spine + waist + armpit + pull


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
SIDE_START = math.radians(86)
TOP_Z = 100.5


def out_phi(t, style):
    """Free outer edge of a back tail; it swings out a little as it falls."""
    return math.radians(style.get('out_deg', 101.0) + 9.0 * t)


def vent_phi(t, style):
    return VENT_TOP + (style['vent_open'] - VENT_TOP) * t ** 1.35


def hem_z(phi, style, outer=None):
    """Back-tail hem: the point sits at the outer edge (as in the character art)
    and the hem rises toward the vent."""
    outer = out_phi(1.0, style) if outer is None else outer
    k = (outer - phi) / max(1e-4, outer - style['vent_open'])
    z = style['tip_z'] + style['hem_rise'] * max(0.0, k) ** 0.8
    if 'second_phi' in style:
        # A second, shorter point (carnival): the hem dips to another V.
        d = math.degrees(phi)
        z = min(z, style['second_z'] + style['second_slope'] * abs(d - style['second_phi']))
    return z


def _radii(phi, t, style):
    tt = t ** 1.05
    ax = lerp(15.3, style['flare_x'], tt)
    by = lerp(9.6, style['flare_back'], tt)
    bf = lerp(9.6, style['flare_front'], tt)
    b = by if phi < math.pi / 2 else lerp(by, bf, smoothstep(math.pi / 2, FRONT, phi))
    return ax, b, 5.7 + 1.2 * t


def _bezier(p0, c, p1, q):
    return p0 * (1 - q) ** 2 + c * (2 * (1 - q) * q) + p1 * q * q


def back_section(u, t, style):
    """Horizontal section of a back tail (x >= 0, y back): at the waist it follows the
    waist ellipse from the back centre to the side seam; toward the hem it opens into a
    gentle arc behind the legs, facing back, like a hanging flag."""
    ph = lerp(VENT_TOP, math.radians(style.get('waist_out_deg', 96.0)), u)
    waist = Vector((15.3 * math.sin(ph), 5.7 + 9.6 * math.cos(ph)))
    vx, vy = style['hem_vent']
    ox, oy = style['hem_outer']
    v, o = Vector((vx * t ** 0.3 if t > 0 else 0.0, vy)), Vector((ox, oy))
    ctrl = Vector(((vx + ox) / 2 + 3.0, max(vy, oy) + style['hem_bulge']))
    hem = _bezier(v, ctrl, o, u)
    return waist.lerp(hem, t ** 0.8)


def back_point(side, u, t, style):
    """Back tail panel. u: 0 vent edge .. 1 outer free edge; t: 0 waist .. 1 hem."""
    sign = 1 if side == 'L' else -1
    p = back_section(u, t, style)
    # Outward normal of the section (away from the legs, mostly +y).
    a = back_section(max(0.0, u - 0.01), t, style)
    b = back_section(min(1.0, u + 0.01), t, style)
    tang = (b - a).normalized()
    nrm = Vector((tang.y, -tang.x))
    if nrm.y < 0:
        nrm = -nrm
    # Deep godets: about two and a half folds across the panel, round crests,
    # tighter valleys, deepening toward the hem.
    ph = 0.6 if sign > 0 else 1.9
    fold = 0.72 * math.cos(math.tau * 2.4 * u + ph) + 0.28 * math.cos(math.tau * 4.8 * u + 2 * ph)
    # The turned-back corner near the vent lies flatter than the free cloth.
    fold *= 0.3 + 0.7 * smoothstep(0.18, 0.55, u)
    p = p + nrm * style['fold'] * t ** 1.2 * fold
    # Cloth weight swings the hem back; the point flares outward.
    p.y += style['hang'] * t ** 1.6 * (1 - 0.5 * u)
    p.x += style['tip_swing'] * t ** 2.2 * u ** 3
    z = TOP_Z - (TOP_Z - hem_height(u, style)) * t
    phi = math.atan2(p.x, p.y - 5.7)
    return Vector((sign * p.x, p.y, z)), phi


def hem_height(u, style):
    """Point at the outer edge (u = 1), rising toward the vent."""
    z = style['tip_z'] + style['hem_rise'] * (1 - u) ** 0.8
    if 'second_u' in style:
        z = min(z, style['second_z'] + style['second_slope'] * abs(u - style['second_u']) * 60)
    return z


def side_z(phi, style):
    """Side/front skirt hem: shorter than the back tails, rising toward the front."""
    k = (phi - SIDE_START) / (FRONT - SIDE_START)
    return style['side_hem'] + 9.0 * max(0.0, k) ** 0.8


def side_point(side, u, t, style):
    """Side and front skirt, tucked 1.4 cm inside the back tail's outer edge."""
    sign = 1 if side == 'L' else -1
    phi = lerp(SIDE_START, FRONT, u)
    z = TOP_Z - (TOP_Z - side_z(phi, style)) * t
    ax, b, cy = _radii(phi, t, style)
    ax = lerp(15.0, style.get('side_flare', 34.0), t ** 1.05)
    fold = 0.6 * math.cos(9.0 * phi + 0.4 * sign) + 0.4 * math.cos(15.0 * phi + 1.1)
    inset = 1.4 * smoothstep(0.0, 0.25, 1 - u)
    r_extra = style['fold'] * 0.45 * t ** 1.2 * fold - inset
    x = sign * (ax + r_extra) * math.sin(phi)
    y = cy + (b + r_extra) * math.cos(phi)
    return Vector((x, y, z)), phi


def _panel(name, side, fn, style, material, region, rows, cols):
    verts = []
    for j in range(rows):
        t = j / (rows - 1)
        for i in range(cols):
            p, phi = fn(side, i / (cols - 1), t, style)
            verts.append(p)
    # Centimetre UVs: arc along each row from the first column, length down each column.
    raw = [None] * len(verts)
    col_len = [0.0] * cols
    for j in range(rows):
        acc = 0.0
        for i in range(cols):
            k = j * cols + i
            if i:
                acc += (verts[k] - verts[k - 1]).length
            if j:
                col_len[i] += (verts[k] - verts[k - cols]).length
            raw[k] = (acc, col_len[i])
    top = atlas.REGIONS[region][3] - 1.0
    uvs = [atlas.uv(region, 1.0 + a, top - b) for a, b in raw]
    canvas = [atlas.to_canvas(region, 1.0 + a, top - b) for a, b in raw]
    faces = grid_faces(rows, cols)
    if side == 'R':
        faces = [tuple(reversed(f)) for f in faces]
    ob = build_mesh(name + ' ' + side, verts, faces, uvs, material)
    edges = {
        'start': [verts[j * cols] for j in range(rows)],
        'end': [verts[j * cols + cols - 1] for j in range(rows)],
        'hem': [verts[(rows - 1) * cols + i] for i in range(cols)],
        'waist': [verts[i] for i in range(cols)],
    }
    edges_uv = {
        'end': [canvas[j * cols + cols - 1] for j in range(rows)],
        'hem': [canvas[(rows - 1) * cols + i] for i in range(cols)],
        'start': [canvas[j * cols] for j in range(rows)],
    }
    ob['hem_uv'] = [list(p) for p in edges_uv['hem']]
    ob['end_uv'] = [list(p) for p in edges_uv['end']]
    ob['start_uv'] = [list(p) for p in edges_uv['start']]
    return ob, edges


def build_tail(side, style, material, cols=30, rows=48):
    """Back tail panel: vent edge, free outer edge and pointed hem."""
    ob, e = _panel('Coat tail', side, back_point, style, material, 'tail', rows, cols)
    edges = {'vent': e['start'], 'outer': e['end'], 'hem': e['hem'], 'waist': e['waist']}
    return ob, edges, (rows, cols)


def build_side_skirt(side, style, material, cols=26, rows=34):
    ob, e = _panel('Coat skirt', side, side_point, style, material, 'side', rows, cols)
    edges = {'front': e['end'], 'hem': e['hem'], 'waist': e['waist']}
    return ob, edges


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
    r = 5.6 - 0.9 * smoothstep(0.0, 0.25, t) - 0.35 * smoothstep(0.45, 0.95, t)
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
    hole_ry, hole_rz = 5.7, 6.6
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
            # Elbow folds and soft stacking above the cuff.
            crease += 0.22 * math.sin(t * 46.0 + math.cos(ang * 2) * 1.4) * math.exp(-((t - 0.5) / 0.07) ** 2)
            crease += 0.2 * math.sin(t * 58.0 + ang * 1.3) * smoothstep(0.72, 0.8, t) * (1 - smoothstep(0.9, 0.97, t))
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


def build_facing(side, style, material, rows=40, cols=8):
    """Turned-back corner along the vent edge: the lining folds out in a widening
    triangle toward the point, raised just off the tail so it reads as cloth."""
    verts, uvs, outer = [], [], []
    run, t_prev = 0.0, 0.0
    for j in range(rows):
        t = 0.04 + 0.96 * j / (rows - 1)
        width = 1.2 + style.get('turnback', 15.0) * t ** 2.2
        prev, _ = back_point(side, 0.0, t, style)
        acc, u = 0.0, 0.0
        while acc < width and u < 0.75:
            u += 0.003
            p, _ = back_point(side, u, t, style)
            acc += (p - prev).length
            prev = p
        umax = u
        if j:
            run += (back_point(side, 0.0, t, style)[0] - back_point(side, 0.0, t_prev, style)[0]).length
        t_prev = t
        for i in range(cols):
            uu = umax * i / (cols - 1)
            p, phi = back_point(side, uu, t, style)
            # Lift along the tail's own surface normal (outside of the cloth).
            du = back_point(side, min(1.0, uu + 0.01), t, style)[0] - back_point(side, max(0.0, uu - 0.01), t, style)[0]
            dt = back_point(side, uu, min(1.0, t + 0.01), style)[0] - back_point(side, uu, max(0.0, t - 0.01), style)[0]
            out = du.cross(dt).normalized()
            if out.dot(Vector((p.x, p.y - 5.7, 0))) < 0:
                out = -out
            # Rolled fold at the vent edge, settling onto the tail toward the free edge.
            lift = 1.2 + 0.7 * (1 - i / (cols - 1)) ** 2
            verts.append(p + out * lift)
            uvs.append(atlas.uv('facing', 1.0 + width * i / (cols - 1), 93.0 - run))
        outer.append(verts[-1])
    faces = grid_faces(rows, cols)
    if side == 'R':
        faces = [tuple(reversed(f)) for f in faces]
    ob = build_mesh('Facing ' + side, verts, faces, uvs, material)
    # Lower third of the turnback in canvas coordinates (carnival harlequin panel).
    canvas = [(u * atlas.SIZE_CM, v * atlas.SIZE_CM) for u, v in uvs]
    lo = int(rows * 0.62)
    fold_side = [canvas[j * cols] for j in range(lo, rows)]
    outer_side = [canvas[j * cols + cols - 1] for j in range(lo, rows)]
    ob['lower_uv'] = [list(p) for p in fold_side + outer_side[::-1]]
    fold_line = [verts[j * cols] for j in range(rows)]
    bottom = verts[(rows - 1) * cols:]
    return ob, outer, fold_line, bottom


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
