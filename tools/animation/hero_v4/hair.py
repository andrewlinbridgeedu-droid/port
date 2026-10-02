"""Layered anime hair: tapered clumps laid over a shell around the skull, falling
past it with flicked, pointed tips. UV: u across a clump, v from root (0) to tip (1)."""
import math, random
from mathutils import Vector, Matrix
from .geom import build_mesh, grid_faces, smoothstep, lerp, solidify

C = Vector((0, 8.3, 162.8))
R = Vector((8.75, 9.7, 10.9))


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
        shape = (0.62 + 0.38 * math.sin(math.pi * min(1.0, s / 0.35) * 0.5)) * (1 - smoothstep(0.66, 1.0, s) ** 0.85)
        half = w * shape
        for i in range(cols):
            x = -1 + 2 * i / (cols - 1)
            # Thick at the root, thinning to a flat blade at the tip.
            q = p + acr * x * half + n * ridge * (1 - x * x) ** 0.7 * (1 - 0.8 * s ** 1.3)
            verts.append(q)
            uvs.append((i / (cols - 1), s))
    faces = grid_faces(len(spine), cols)
    return build_mesh('Hair clump', verts, faces, uvs, None)


def layout(seed=7):
    """Messy short hair as in the character art. Every layer runs from the crown to
    the nape, so no ring of tips forms around the skull; lengths vary from lock to
    lock so the lower edge is irregular, and tips settle inward instead of poking out."""
    rng = random.Random(seed)
    specs = []

    def j(a, b):
        return rng.uniform(a, b)

    # A: broad under-layer reaching the collar; lengths vary a lot.
    for az in [90, 72, 108, 54, 126, 36, 144, 18, 162]:
        specs.append(dict(az=az + j(-3, 3), pol0=20 + j(-4, 4), pol1=118, w=3.9 + j(-0.3, 0.4),
                          lift=(0.4, 1.1), hang=j(4.5, 9.5), hang_pol=104 + j(-3, 3),
                          flick=0.4 + j(-0.2, 0.3), side=j(-0.7, 0.7), ridge=1.05, curl=j(-6, 6), split=False))
    # B: middle layer, shorter on average, with occasional split tips.
    for az in [84, 96, 72, 108, 60, 120, 48, 132, 36, 144, 22, 158, 8, 172]:
        specs.append(dict(az=az + j(-4, 4), pol0=13 + j(-3, 4), pol1=112, w=2.8 + j(-0.3, 0.4),
                          lift=(1.1, 2.0), hang=j(2.5, 7.0), hang_pol=98 + j(-4, 6),
                          flick=0.6 + j(-0.2, 0.4), side=j(-1.0, 1.0), ridge=0.95, curl=j(-10, 10)))
    # C: top layer from the whorl, long enough to blend into the nape.
    for az in [90, 74, 106, 58, 122, 42, 138, 26, 154, 10, 170]:
        specs.append(dict(az=az + j(-6, 6), pol0=10 + j(0, 6), pol1=106 + j(-6, 6), w=2.5 + j(-0.3, 0.4),
                          lift=(2.2, 3.0), hang=j(2.0, 5.5), hang_pol=94 + j(-6, 6), follow=0.5,
                          flick=0.5 + j(0, 0.4), side=j(-1.0, 1.0), ridge=0.9, curl=j(-14, 14)))
    # E: sides over the ears.
    for az in [6, -14, 26, -34, 174, 194, 154, 214]:
        specs.append(dict(az=az + j(-4, 4), pol0=20 + j(-3, 3), pol1=112, w=3.5 + j(-0.3, 0.4),
                          lift=(1.0, 1.8), hang=j(4.0, 7.0), hang_pol=100,
                          flick=0.5 + j(0, 0.3), side=j(-0.7, 0.7), ridge=1.0, curl=j(-8, 8)))
    # F: fringe for the quarter view.
    for az in [212, 234, 256, 278, 300, 322]:
        specs.append(dict(az=az + j(-4, 4), pol0=14 + j(-3, 3), pol1=94, w=3.0 + j(-0.3, 0.4),
                          lift=(1.3, 1.8), hang=2.6 + j(0, 1.6), hang_pol=86,
                          flick=0.6 + j(0, 0.4), side=j(-1.2, 1.2), ridge=0.5, curl=j(-10, 10)))
    # G: nape under-layer so no skin shows above the collar.
    for az in [80, 100, 62, 118, 90]:
        specs.append(dict(az=az + j(-5, 5), pol0=94 + j(-4, 2), pol1=118, w=3.2 + j(-0.2, 0.3),
                          lift=(0.3, 0.6), hang=7.8 + j(-0.4, 1.0), hang_pol=108,
                          flick=0.3 + j(-0.1, 0.2), side=j(-0.6, 0.6), ridge=0.45, rows=14, split=False))
    return specs, rng


def build_hair(material, seed=7):
    specs, rng = layout(seed)
    obs = []
    for spec in specs:
        ob = clump(spec, rng)
        ob.data.materials.append(material)
        obs.append(ob)
        # Split tips: thinner strands along the lock's edges part from it near the end,
        # so the lock ends in two or three points instead of one.
        if spec.get('split', True) and spec.get('hang', 0) > 3.0 and spec['w'] > 2.6 and rng.random() < 0.5:
            for edge in (-1, 1):
                if rng.random() < 0.5:
                    continue
                child = dict(spec)
                child['az'] = spec['az'] + edge * spec['w'] * 2.0
                child['w'] = spec['w'] * 0.5
                child['lift'] = (spec['lift'][0] + 0.12, spec['lift'][1] + 0.2)
                child['hang'] = spec['hang'] * rng.uniform(0.88, 1.02)
                child['side'] = spec.get('side', 0.0) + edge * rng.uniform(0.2, 0.6)
                child['flick'] = spec.get('flick', 0.0) + rng.uniform(0.0, 0.3)
                child['ridge'] = spec.get('ridge', 0.5) * 0.7
                ob = clump(child, rng)
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
