"""Mesh construction helpers for the v4 hero. Units are centimetres, +Z up,
the hero faces -Y (the camera normally sits behind, on +Y)."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion


def smoothstep(a, b, x):
    if a == b:
        return 0.0 if x < a else 1.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def superellipse(a, b, theta, n=2.0):
    """Point on a superellipse; theta=0 is +X, theta=pi/2 is +Y (the back)."""
    c, s = math.cos(theta), math.sin(theta)
    e = 2.0 / n
    return (a * math.copysign(abs(c) ** e, c), b * math.copysign(abs(s) ** e, s))


def frame(direction, hint=Vector((0, 1, 0))):
    """Orthonormal (u, v) perpendicular to direction; u leans toward hint."""
    d = Vector(direction).normalized()
    h = Vector(hint)
    if abs(d.dot(h.normalized())) > 0.98:
        h = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 0, 1))
    u = (h - d * h.dot(d)).normalized()
    v = d.cross(u).normalized()
    return u, v


def grid_faces(rows, cols, closed=False):
    """Quads for a rows x cols vertex grid laid out row-major."""
    faces = []
    span = cols if closed else cols - 1
    for j in range(rows - 1):
        for i in range(span):
            a = j * cols + i
            b = j * cols + (i + 1) % cols
            faces.append((a, b, b + cols, a + cols))
    return faces


def build_mesh(name, verts, faces, uvs=None, material=None, smooth=True, collection=None, wrap=None):
    """uvs: per-vertex (u, v) list, copied to every loop. wrap=(cols, period): for
    row-major rings of `cols` vertices, faces closing the ring get column 0 shifted
    by `period` in u, so the seam does not smear the texture."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate(clean_customdata=False)
    if uvs is not None:
        layer = me.uv_layers.new(name='UVMap')
        for poly in me.polygons:
            shift = False
            if wrap is not None:
                colset = {me.loops[li].vertex_index % wrap[0] for li in poly.loop_indices}
                shift = 0 in colset and (wrap[0] - 1) in colset
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                u, v = uvs[vi]
                if shift and vi % wrap[0] == 0:
                    period = wrap[1]
                    u += period[vi // wrap[0]] if isinstance(period, (list, tuple)) else period
                layer.data[li].uv = (u, v)
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    if material is not None:
        me.materials.append(material)
    return ob


def recalc_normals(ob, inside=False):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if inside:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def apply_modifiers(ob):
    """Bake the modifier stack into the mesh (keeps UVs and material slots)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)
    return ob


def subdivide(ob, levels=1, crease_boundary=False):
    m = ob.modifiers.new('subdivide', 'SUBSURF')
    m.levels = levels
    m.render_levels = levels
    m.uv_smooth = 'PRESERVE_CORNERS'
    m.boundary_smooth = 'PRESERVE_CORNERS' if crease_boundary else 'ALL'
    return apply_modifiers(ob)


def solidify(ob, thickness, offset=-1.0, material_offset=0, rim_material_offset=0, even=True):
    m = ob.modifiers.new('cloth thickness', 'SOLIDIFY')
    m.thickness = thickness
    m.offset = offset
    m.use_even_offset = even
    m.use_quality_normals = True
    m.material_offset = material_offset
    m.material_offset_rim = rim_material_offset
    m.use_rim = True
    return apply_modifiers(ob)


def tube(name, points, radius, material=None, sides=8, hint=Vector((0, 1, 0)), caps=True,
         flat=1.0, uv_scale=1.0, collection=None):
    """Swept circle (or ellipse with `flat`) along points; radius may be callable(t).
    UV: u around, v along accumulated length * uv_scale."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    verts, uvs = [], []
    length = 0.0
    prev_u = None
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        if d.length < 1e-6:
            d = Vector((0, 0, 1))
        u, v = frame(d, hint if prev_u is None else prev_u)
        prev_u = u
        if i:
            length += (pts[i] - pts[i - 1]).length
        r = radius(i / (n - 1)) if callable(radius) else radius
        for k in range(sides):
            a = k / sides * math.tau
            verts.append(p + r * (math.cos(a) * u + flat * math.sin(a) * v))
            uvs.append((k / sides, length * uv_scale))
    faces = grid_faces(n, sides, closed=True)
    if caps:
        faces.append(tuple(range(sides - 1, -1, -1)))
        faces.append(tuple((n - 1) * sides + k for k in range(sides)))
    ob = build_mesh(name, verts, faces, uvs, material, collection=collection)
    return ob


def resample(points, count):
    """Evenly spaced points along a polyline."""
    pts = [Vector(p) for p in points]
    lengths = [0.0]
    for a, b in zip(pts, pts[1:]):
        lengths.append(lengths[-1] + (b - a).length)
    total = lengths[-1]
    out = []
    j = 0
    for i in range(count):
        s = total * i / (count - 1)
        while j < len(pts) - 2 and lengths[j + 1] < s:
            j += 1
        seg = lengths[j + 1] - lengths[j]
        t = 0 if seg == 0 else (s - lengths[j]) / seg
        out.append(pts[j].lerp(pts[j + 1], t))
    return out


def catmull(points, samples_per_span=8):
    """Catmull-Rom spline through points."""
    pts = [Vector(p) for p in points]
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(i - 1, 0)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(i + 2, len(pts) - 1)]
        for k in range(samples_per_span):
            t = k / samples_per_span
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def join(objects, name):
    objects = [o for o in objects if o is not None]
    if not objects:
        return None
    if len(objects) == 1:
        objects[0].name = name
        return objects[0]
    ctx = {'active_object': objects[0], 'selected_editable_objects': objects, 'selected_objects': objects}
    with bpy.context.temp_override(**ctx):
        bpy.ops.object.join()
    objects[0].name = name
    return objects[0]


def closest_on(ob, p, push=0.0):
    """Closest surface point on ob (world space == object space here), pushed along normal."""
    ok, loc, nor, idx = ob.closest_point_on_mesh(Vector(p))
    if not ok:
        return Vector(p), Vector((0, 1, 0))
    return loc + nor * push, nor
