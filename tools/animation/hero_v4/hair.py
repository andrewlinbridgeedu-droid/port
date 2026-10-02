"""Layered anime hair: tapered clumps laid over a shell around the skull, falling
past it with flicked, pointed tips. UV: u across a clump, v from root (0) to tip (1)."""
import math, random
from mathutils import Vector, Matrix
from .geom import build_mesh, grid_faces, smoothstep, lerp, solidify

C = Vector((0, 8.4, 161.8))
R = Vector((10.1, 11.1, 12.4))


def shell(pol, az, lift=0.0):
    d = Vector((math.sin(pol) * math.cos(az), math.sin(pol) * math.sin(az), math.cos(pol)))
    n = Vector((d.x / R.x, d.y / R.y, d.z / R.z)).normalized()
    p = C + Vector((R.x * d.x, R.y * d.y, R.z * d.z))
    return p + n * lift, n


def clump(spec, rng):
    """spec: az, pol0, pol1 (deg), w (half width, cm), lift (root, end), hang (cm past
    the shell), hang_pol, flick (outward tip kick), side (sideways tip kick), ridge."""
    az = math.radians(spec['az'])
    pol0, pol1 = math.radians(spec['pol0']), math.radians(spec['pol1'])
    hang = spec.get('hang', 0.0)
    hang_pol = math.radians(spec.get('hang_pol', 102))
    rows = spec.get('rows', 20)
    cols = 7
    lift0, lift1 = spec['lift']
    curl = math.radians(spec.get('curl', 0.0))
    end_pol = min(pol1, hang_pol) if hang > 0 else pol1
    # Arc length on the shell vs hanging length decides where the spine leaves the head.
    arc = abs(end_pol - pol0) * 10.5
    shell_frac = arc / (arc + hang) if hang > 0 else 1.0
    spine, across, normal = [], [], []
    for k in range(rows):
        s = k / (rows - 1)
        if s <= shell_frac:
            q = s / shell_frac
            pol = lerp(pol0, end_pol, q)
            a = az + curl * q * q
            lift = lerp(lift0, lift1, q ** 0.7)
            p, n = shell(pol, a, lift)
            pa, _ = shell(pol, a + 0.01, lift)
            spine.append(p)
            across.append((pa - p).normalized())
            normal.append(n)
        else:
            q = (s - shell_frac) / (1 - shell_frac)
            base, n0 = shell(end_pol, az + curl, lift1)
            pa, _ = shell(end_pol, az + curl + 0.01, lift1)
            a0 = (pa - base).normalized()
            prev, _ = shell(end_pol - 0.06 * (1 if pol1 >= pol0 else -1), az + curl, lift1)
            t0 = (base - prev).normalized()
            down = Vector((0, 0, -1))
            direction = (t0 * spec.get('follow', 0.35) + down * 0.65 + n0 * 0.18).normalized()
            p = base + direction * hang * q
            p += n0 * spec.get('flick', 0.0) * q ** 2.4
            p += a0 * spec.get('side', 0.0) * q ** 2.0
            spine.append(p)
            across.append(a0)
            normal.append(n0)
    verts, uvs = [], []
    ridge = spec.get('ridge', 0.5)
    w = spec['w']
    for k, (p, acr, n) in enumerate(zip(spine, across, normal)):
        s = k / (len(spine) - 1)
        # Full lock: wide from the root, keeping its width down past the skull,
        # then narrowing into a long sharp point.
        shape = (0.62 + 0.38 * math.sin(math.pi * min(1.0, s / 0.35) * 0.5)) * (1 - smoothstep(0.58, 1.0, s) ** 0.9)
        half = w * shape
        for i in range(cols):
            x = -1 + 2 * i / (cols - 1)
            q = p + acr * x * half + n * ridge * (1 - x * x) ** 0.7 * (1 - 0.35 * s)
            verts.append(q)
            uvs.append((i / (cols - 1), s))
    faces = grid_faces(len(spine), cols)
    return build_mesh('Hair clump', verts, faces, uvs, None)


def layout(seed=7):
    """Messy, voluminous short hair as in the character art: locks fan out from the
    crown, the nape and sides flick outward in points, a few strands lift on top."""
    rng = random.Random(seed)
    specs = []

    def j(a, b):
        return rng.uniform(a, b)

    # A: broad back layer, crown to nape, falling past the skull to the collar.
    for az in [90, 72, 108, 54, 126, 36, 144, 18, 162]:
        specs.append(dict(az=az + j(-3, 3), pol0=20 + j(-4, 4), pol1=118, w=4.4 + j(-0.3, 0.5),
                          lift=(0.5, 1.3), hang=5.2 + j(-1.0, 1.6), hang_pol=104 + j(-3, 3),
                          flick=1.8 + j(-0.4, 1.0), side=j(-1.8, 1.8), ridge=1.25, curl=j(-6, 6)))
    # B: second layer with more lift and livelier, spikier tips.
    for az in [81, 99, 63, 117, 45, 135, 27, 153, 9, 171]:
        specs.append(dict(az=az + j(-4, 4), pol0=13 + j(-3, 4), pol1=112, w=3.9 + j(-0.3, 0.5),
                          lift=(1.3, 2.4), hang=3.6 + j(-0.6, 1.6), hang_pol=98 + j(-4, 4),
                          flick=2.4 + j(-0.5, 1.2), side=j(-2.2, 2.2), ridge=1.15, curl=j(-10, 10)))
    # C: crown tufts fanning from the whorl, tips lifting off the back of the head.
    for az in [90, 66, 114, 42, 138, 18, 162]:
        specs.append(dict(az=az + j(-6, 6), pol0=10 + j(0, 6), pol1=78 + j(-6, 8), w=4.0 + j(-0.3, 0.5),
                          lift=(2.3, 3.2), hang=2.4 + j(0, 1.4), hang_pol=72 + j(-5, 6), follow=0.75,
                          flick=2.0 + j(0, 1.0), side=j(-1.6, 1.6), ridge=1.1, curl=j(-14, 14)))
    # E: sides over the ears, flaring out at the tips.
    for az in [6, -14, 26, -34, 174, 194, 154, 214]:
        specs.append(dict(az=az + j(-4, 4), pol0=20 + j(-3, 3), pol1=112, w=4.0 + j(-0.3, 0.4),
                          lift=(1.2, 2.2), hang=4.6 + j(-0.6, 1.4), hang_pol=100,
                          flick=2.2 + j(0, 1.0), side=j(-1.4, 1.4), ridge=1.0, curl=j(-8, 8)))
    # F: fringe for the quarter view.
    for az in [212, 234, 256, 278, 300, 322]:
        specs.append(dict(az=az + j(-4, 4), pol0=14 + j(-3, 3), pol1=94, w=3.4 + j(-0.3, 0.4),
                          lift=(1.3, 1.8), hang=2.6 + j(0, 1.2), hang_pol=86,
                          flick=0.8 + j(0, 0.6), side=j(-1.4, 1.4), ridge=0.5, curl=j(-10, 10)))
    # G: fine nape wisps under the first layer.
    for az in [80, 100, 62, 118]:
        specs.append(dict(az=az + j(-5, 5), pol0=94 + j(-4, 2), pol1=118, w=2.4 + j(-0.2, 0.3),
                          lift=(0.3, 0.6), hang=4.6 + j(-0.4, 1.2), hang_pol=108,
                          flick=1.4 + j(-0.3, 0.8), side=j(-1.6, 1.6), ridge=0.35, rows=14))
    return specs, rng


def build_hair(material, seed=7):
    specs, rng = layout(seed)
    obs = []
    for spec in specs:
        ob = clump(spec, rng)
        ob.data.materials.append(material)
        obs.append(ob)
    # Closed scalp under the clumps so no skin shows between them.
    verts, uvs = [], []
    rows, cols = 18, 40
    for j in range(rows + 1):
        pol = j / rows * math.radians(118)
        for i in range(cols):
            az = i / cols * math.tau
            p, n = shell(pol, az, -0.25)
            # Leave the face open in front of the ears.
            verts.append(p)
            uvs.append((i / cols, 0.02))
    faces = grid_faces(rows + 1, cols, closed=True)[cols:]
    keep = []
    for f in faces:
        c = sum((verts[i] for i in f), Vector()) / 4
        front = c.y < C.y - 3.0 and c.z < C.z + 3.0
        if not front:
            keep.append(f)
    scalp = build_mesh('Hair scalp', verts, keep, uvs, material)
    return obs, scalp
