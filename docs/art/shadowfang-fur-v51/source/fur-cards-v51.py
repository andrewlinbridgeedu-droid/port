"""Shadowfang v51: finer hair cards, head top and tail covered, colour from the body.

User 2026-10-16 on v50: 可以，不错 … 再把毛做细、补头顶和尾巴，颜色最好和身体统一.
Built on v49/v50 (textured hair cards bent on the GPU, see fur-cards-v49.py):
- cards are 0.6 of v49's width and about twice as many; the atlas (fur-strands-v51.py)
  has more, thinner locks;
- the sculpted crest along the top of the head is lowered and a cap of short locks flows
  back from the forehead into the neck ruff; the tail is covered all round, flowing to
  its tip;
- every card is the body's own average charcoal at the lightness of the skin under its
  root, written to the body's AnatomyTone colour layer (the strand texture only carries
  lighter and darker strands around that colour).

Each card: 8 rings x 3 columns (centre lifted), root sunk into the body, pushed out
wherever the curve would dip under the surface. UV0: u across the card inside its atlas
column, v = 0 root, 1 tip. UV1 ('FurData'): (random phase, card length in Blender units).
Every card copies the skin weights of the body vertex nearest its root.
"""
import bpy, bmesh, math, json, random
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix, kdtree
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

P = Path("/Volumes/andrew's SSD/Downloads/mindstone-game/.build/character-polish-20261015/shadowfang")
OUT = P / 'fur-v51'
bpy.ops.wm.open_mainfile(filepath=str(P / 'shadowfang-structural-v20.blend'))
o = bpy.data.objects['Shadowfang_60000']
assert o.matrix_world == Matrix.Identity(4)
rng = random.Random(51)
WIDTH, MAIN, BETWEEN, RINGS, COLS = .6, 15, 8, 8, 3


def smooth(a, b, x):
    t = max(0, min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# v43's undercoat: flatten the old upper shoulder silhouette, recess cheek fringe and
# chest tips, protecting muzzle, eyes and legs.
for v in o.data.vertices:
    x, y, z = v.co
    w = smooth(-.88, -.67, y) * (1 - smooth(.18, .4, y)) * smooth(.18, .42, z) * smooth(.12, .25, abs(x))
    v.co.z -= max(0, z - .38) * w * .9
    v.co.x *= 1 - .055 * w
for v in o.data.vertices:
    x, y, z = v.co
    cheek = smooth(-1.10, -.98, y) * (1 - smooth(-.78, -.65, y)) * smooth(.13, .22, z) * (1 - smooth(.43, .51, z)) * smooth(.14, .24, abs(x))
    v.co.x *= 1 - .16 * cheek
    chest = smooth(-.96, -.82, y) * (1 - smooth(-.57, -.46, y)) * smooth(-.31, -.15, z) * (1 - smooth(.12, .24, z)) * (1 - smooth(.16, .27, abs(x)))
    v.co.y += .045 * chest
# v51: lower the sculpted crest on the top of the head (midline only; ears untouched).
for v in o.data.vertices:
    x, y, z = v.co
    crest = (1 - smooth(.06, .12, abs(x))) * smooth(-1.14, -1.04, y) * (1 - smooth(-.62, -.52, y))
    v.co.z -= max(0, z - .66) * .6 * crest
o.data.update()

# v43's 23 designed flows (root, control, tip, width).
left = [
    ((-.24, -.72, .36), (-.34, -.58, .40), (-.38, -.39, .23), .075),
    ((-.29, -.58, .30), (-.40, -.42, .29), (-.43, -.19, .10), .083),
    ((-.19, -.52, .39), (-.29, -.28, .45), (-.34, -.01, .30), .070),
    ((-.31, -.33, .24), (-.41, -.13, .22), (-.39, .12, .04), .077),
    ((-.20, -.18, .39), (-.28, .02, .42), (-.31, .25, .25), .065),
    ((-.30, .02, .27), (-.37, .20, .26), (-.31, .39, .11), .060)]
left += [
    ((-.18, -1.00, .39), (-.25, -.90, .34), (-.30, -.75, .20), .051),
    ((-.21, -.94, .30), (-.30, -.82, .25), (-.31, -.65, .08), .059),
    ((-.16, -.89, .23), (-.23, -.80, .13), (-.23, -.66, -.04), .054),
    ((-.10, -.77, .15), (-.15, -.81, .02), (-.13, -.72, -.19), .064),
    ((-.18, -.69, .12), (-.22, -.72, -.03), (-.19, -.59, -.23), .059)]
locks = list(left)
for i, (r, c, t, w) in enumerate(left):
    locks.append(((-r[0], r[1] + .015 * (i % 2), r[2]), (-c[0], c[1] - .025, c[2] - .012), (-t[0], t[1] - .015, t[2] + .012), w * .94))
locks += [((0, -.81, .14), (.018, -.86, -.04), (0, -.73, -.29), .070)]
for i, (r, c, t, w) in enumerate(locks):
    side = -1 if r[0] < 0 else 1
    if i in [6, 7, 8, 17, 18, 19]:
        j = [6, 7, 8, 17, 18, 19].index(i) % 3
        r = (side * (.20 + .015 * j), -1.00 + .045 * j, .36 - .095 * j)
        c = (side * (.30 + .01 * j), -1.015 + .045 * j, .24 - .10 * j)
        t = (side * (.33 - .015 * j), -.99 + .045 * j, .08 - .11 * j)
        w = .052 - .004 * j
    elif i in [9, 10, 20, 21, 22]:
        r = (r[0], -.88, r[2]); c = (c[0], -.94, c[2]); t = (t[0], -.93, t[2] - .025)
    locks[i] = (r, c, t, w)
guides = [(Vector(r) + Vector((0, 0, -.035)), Vector(c) + Vector((0, 0, -.025)), Vector(t), w) for r, c, t, w in locks]

# In-between guides: each guide with its two nearest neighbours on the same side.
extra, seen = [], set()
for i, (r, c, t, w) in enumerate(guides):
    near = sorted((j for j in range(len(guides)) if j != i and (guides[j][0].x * r.x >= 0 or abs(r.x) < .02)),
                  key=lambda j: (guides[j][0] - r).length)[:2]
    for j in near:
        key = tuple(sorted((i, j)))
        if key in seen or (guides[j][0] - r).length > .32:
            continue
        seen.add(key)
        g = guides[j]
        extra.append(((r + g[0]) / 2, (c + g[1]) / 2, (t + g[2]) / 2, (w + g[3]) / 2))

# Body surface queries (triangulated copy, so every hit has a triangle for its UV).
bm = bmesh.new(); bm.from_mesh(o.data)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.faces.ensure_lookup_table()
uvl = bm.loops.layers.uv[o.data.uv_layers[0].name]
bvh = BVHTree.FromBMesh(bm)
kd = kdtree.KDTree(len(o.data.vertices))
for v in o.data.vertices:
    kd.insert(v.co, v.index)
kd.balance()


def surface(pnt):
    loc, nrm, _, _ = bvh.find_nearest(pnt)
    return loc, nrm.normalized()


def rotate(vec, axis, deg):
    return Matrix.Rotation(math.radians(deg), 3, axis.normalized()) @ vec


# Head cap: short locks rooted on the skull, flowing back over the lowered crest and
# slightly outward, into the neck ruff. Roots are found by casting down onto the head.
cap = []
for row in range(7):
    y = -1.11 + row * .075
    for x in (-.09, -.045, 0, .045, .09):
        hit, nrm, _, _ = bvh.ray_cast(Vector((x, y, 2.0)), Vector((0, 0, -1)))
        if hit is None or hit.z < .45:
            continue
        back = Vector((x * .5, .17 + .02 * row, .02))
        cap.append((hit, hit + back * .55 + Vector((0, 0, .05)), hit + back + Vector((0, 0, .015)), .045))

# Tail: stations along the tail bones, locks all round flowing to the tip.
arm = o.parent
chain = [arm.data.bones[n] for n in ('Tail1', 'Tail2', 'Tail3')]
spine = [chain[0].head_local] + [b.tail_local for b in chain]
tail = []
for k in range(11):
    s = .04 + .9 * k / 10
    seg = min(int(s * 3), 2); f = s * 3 - seg
    centre = spine[seg].lerp(spine[seg + 1], f)
    along = (spine[seg + 1] - spine[seg]).normalized()
    side = along.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(along).normalized()
    for a in range(9):
        ang = a / 9 * math.tau + k * .35
        out = (side * math.cos(ang) + up * math.sin(ang)).normalized()
        hit, nrm, _, _ = bvh.ray_cast(centre + out * .4, -out, .45)
        if hit is None or (hit - centre).length > .2:   # the tail itself, not the hips behind it
            continue
        length = .26 - .08 * s
        cap_dir = (along * .85 + out * .35).normalized()
        tail.append((hit, hit + cap_dir * length * .5 + out * .03, hit + cap_dir * length + out * .02, .05))

all_guides = ([(g, MAIN, 1.35) for g in guides] + [(g, BETWEEN, 1.35) for g in extra]
              + [(g, 4, .8) for g in cap] + [(g, 3, .7) for g in tail])

cards = []
for (r, c, t, w), count, spread in all_guides:
    groot, gnrm = surface(r)
    for k in range(count):
        jitter = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * w * spread
        root, nrm = surface(groot + jitter)
        root = root - nrm * .01
        s = rng.uniform(.75, 1.12)
        yaw = rng.uniform(-14, 14)
        dc = rotate((c - r) * s, nrm, yaw)
        dt = rotate((t - r) * s * rng.uniform(.9, 1.08), nrm, yaw + rng.uniform(-6, 6))
        ctrl = root + dc + nrm * rng.uniform(.008, .03)
        tip = root + dt + nrm * rng.uniform(.0, .035)
        pts = []
        for i in range(RINGS):
            u = i / (RINGS - 1)
            q = (1 - u) ** 2 * root + 2 * (1 - u) * u * ctrl + u * u * tip
            if u > .08:
                loc, n2 = surface(q)
                margin = .005 + .025 * u
                if (q - loc).dot(n2) < margin:
                    q = loc + n2 * margin
            pts.append(q)
        cards.append(dict(pts=pts, width=w * WIDTH * rng.uniform(1.05, 1.55), nrm=nrm, twist=rng.uniform(-24, 24),
                          col=rng.randrange(4), phase=rng.random(), root=root))

# Body albedo under each root (Image_0.001 is the base colour; Gamma project, stored as is).
albedo = next(n.image for n in o.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE' and n.image and n.image.name == 'Image_0.001')
aw, ah = albedo.size
pix = np.asarray(albedo.pixels[:], dtype=np.float32).reshape(ah, aw, 4)


def body_colour(pnt):
    loc, _, fi, _ = bvh.find_nearest(pnt)
    face = bm.faces[fi]
    a, b, c = (l.vert.co for l in face.loops)
    ua, ub, uc = (Vector((*l[uvl].uv, 0)) for l in face.loops)
    uv = barycentric_transform(loc, a, b, c, ua, ub, uc)
    x = int(min(max(uv.x, 0), 1) * (aw - 1)); y = int(min(max(uv.y, 0), 1) * (ah - 1))
    patch = pix[max(0, y - 6):y + 7, max(0, x - 6):x + 7, :3].reshape(-1, 3)
    c = patch.mean(axis=0)
    # The pixels are the stored sRGB values; a colour attribute is linear in Blender and
    # the FBX export writes it back as sRGB, so convert once here.
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


# One hue for all the fur, the body's own average charcoal; each card keeps only the local
# lightness of the skin under its root (the chest's painted red-brown read as a pink beard).
samples = [body_colour(card['root'] + card['nrm'] * .01) for card in cards]
LUMA = np.array([.2126, .7152, .0722])
mean = np.mean(samples, axis=0)
verts, faces, uv0, uv1, owner, colour = [], [], [], [], [], []
for ci, card in enumerate(cards):
    pts = card['pts']
    length = sum((pts[i + 1] - pts[i]).length for i in range(RINGS - 1))
    ratio = float(np.clip(samples[ci] @ LUMA / max(mean @ LUMA, 1e-5), .6, 1.35))
    tone = mean * ratio
    card['tone'] = tone.tolist()
    start = len(verts)
    for i, q in enumerate(pts):
        u = i / (RINGS - 1)
        tan = (pts[min(i + 1, RINGS - 1)] - pts[max(i - 1, 0)]).normalized()
        _, n2 = surface(q)
        out = (card['nrm'] * (1 - u) + n2 * u).normalized()
        across = tan.cross(out).normalized()
        across = rotate(across, tan, card['twist'] * u)
        lift = across.cross(tan).normalized()
        if lift.dot(out) < 0:
            lift = -lift
        half = card['width'] * .5 * (1 - .3 * u)
        for j, a in enumerate((-1, 0, 1)):
            verts.append(q + across * a * half + lift * (half * .22 if a == 0 else 0))
            col0 = card['col'] / 4
            uv0.append((col0 + (.02 + .96 * (a + 1) / 2) / 4, .004 + .992 * u))
            uv1.append((card['phase'], length))
            owner.append(ci)
            colour.append((*tone, 1.0))
    for i in range(RINGS - 1):
        for j in range(COLS - 1):
            a = start + i * COLS + j
            faces.append((a, a + 1, a + 1 + COLS, a + COLS))

mesh = bpy.data.meshes.new('FurCards')
mesh.from_pydata([tuple(v) for v in verts], [], faces)
mesh.update()
l0 = mesh.uv_layers.new(name=o.data.uv_layers[0].name)
l1 = mesh.uv_layers.new(name='FurData')
for poly in mesh.polygons:
    poly.use_smooth = True
    for li in poly.loop_indices:
        vi = mesh.loops[li].vertex_index
        l0.data[li].uv = uv0[vi]
        l1.data[li].uv = uv1[vi]
tone_layer = mesh.color_attributes.new(o.data.color_attributes.active_color_name, 'FLOAT_COLOR', 'POINT')
for vi, c in enumerate(colour):
    tone_layer.data[vi].color = c
fur = bpy.data.objects.new('FurCards', mesh)
bpy.context.collection.objects.link(fur)
mat = bpy.data.materials.new('FurCards')
fur.data.materials.append(o.data.materials[0])
fur.data.materials.append(mat)
for poly in mesh.polygons:
    poly.material_index = 1
names = [g.name for g in o.vertex_groups]
for name in names:
    fur.vertex_groups.new(name=name)
for ci, card in enumerate(cards):
    _, idx, _ = kd.find(card['root'])
    card['weights'] = [(o.vertex_groups[g.group].name, g.weight) for g in o.data.vertices[idx].groups if g.weight > 0]
for vi, ci in enumerate(owner):
    for name, wgt in cards[ci]['weights']:
        fur.vertex_groups[name].add([vi], wgt, 'REPLACE')
fur.parent = o.parent
mod = fur.modifiers.new('Armature', 'ARMATURE'); mod.object = o.parent
o.data.uv_layers.new(name='FurData')
bpy.ops.object.select_all(action='DESELECT')
o.select_set(True); fur.select_set(True); bpy.context.view_layer.objects.active = o
bpy.ops.object.join()
bpy.ops.object.vertex_group_limit_total(limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
unweighted = sum(not any(g.weight > 0 for g in v.groups) for v in o.data.vertices)
OUT.mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'shadowfang-furcards-v51.blend'))
tones = np.array([c['tone'] for c in cards])
report = dict(guides=len(guides), between=len(extra), head_cap=len(cap), tail=len(tail), cards=len(cards),
              card_vertices=len(verts), card_triangles=2 * len(faces),
              body_triangles=sum(len(f.vertices) - 2 for f in o.data.polygons) - 2 * len(faces),
              unweighted=unweighted, blender_dimensions=list(o.dimensions),
              tone_mean=tones.mean(axis=0).round(4).tolist(), tone_min=tones.min(axis=0).round(4).tolist(),
              tone_max=tones.max(axis=0).round(4).tolist(),
              status='Hair-card prototype; not reviewed by the user')
(OUT / 'fur-cards-v51-report.json').write_text(json.dumps(report, indent=2))
print('FUR_CARDS_V51', json.dumps(report))
