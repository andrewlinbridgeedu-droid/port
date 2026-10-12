"""Rendered props for the spectacle layer (2026-10-07).

The user on the first solid pass: 这些都还不够精细 -- the props drawn with PIL were flat
clip-art next to the painted battlefield. These are modelled and rendered in Blender
(Cycles, studio HDRI plus three area lights, transparent film) so metal, crystal, stone
and petals have real shading, bevels and highlights. One 512 px PNG per prop; props.py
packs them into SpectacleProps.png.

usage:
  Blender -b --factory-startup -P blender_props.py -- <out-dir> [name ...]
"""
import glob
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/props-render"
ONLY = set(ARGS[1:])
os.makedirs(OUT, exist_ok=True)
HDRI = (glob.glob("/Applications/Blender.app/Contents/Resources/*/datafiles/studiolights/world/studio.exr") or [None])[0]


# ------------------------------------------------------------------ scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception as e:  # CPU is fine, only slower
        print("cycles device:", e)
    sc.cycles.samples = 96
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("W")
    sc.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    nt = w.node_tree
    bg = nt.nodes.get("Background") or nt.nodes.new("ShaderNodeBackground")
    out = nt.nodes.get("World Output") or nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(bg.outputs[0], out.inputs[0])
    if HDRI:
        env = nt.nodes.new("ShaderNodeTexEnvironment")
        env.image = bpy.data.images.load(HDRI)
        nt.links.new(env.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = .9
    return sc


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def look(ob, target):
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def camera(center=(0, 0, 0), scale=3.0, azim=0.0, elev=0.0, dist=12.0):
    cam = bpy.data.cameras.new("C")
    cam.type = "ORTHO"
    cam.ortho_scale = scale
    ob = link(bpy.data.objects.new("C", cam))
    a, e = math.radians(azim), math.radians(elev)
    ob.location = Vector(center) + Vector((dist * math.cos(e) * math.sin(a), -dist * math.cos(e) * math.cos(a), dist * math.sin(e)))
    look(ob, center)
    bpy.context.scene.camera = ob


def lights(key=900, rim=650, fill=220, warm=(1, .96, .9), cool=(.86, .9, 1)):
    def area(name, loc, energy, size, color):
        l = bpy.data.lights.new(name, "AREA")
        l.energy, l.size, l.color = energy, size, color
        o = link(bpy.data.objects.new(name, l))
        o.location = loc
        look(o, (0, 0, 0))
    area("key", (-4, -5, 5), key, 3, warm)
    area("rim", (4, 5, 3), rim, 2, cool)
    area("fill", (5, -4, -2), fill, 4, (1, 1, 1))


def material(name, base, metal=0., rough=.4, coat=0., trans=0., sss=0., emit=None, estr=0., ior=1.45):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    p = nt.nodes.get("Principled BSDF") or nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = nt.nodes.get("Material Output") or nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(p.outputs[0], out.inputs["Surface"])
    p.inputs["Base Color"].default_value = (*base, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    p.inputs["IOR"].default_value = ior
    if coat:
        p.inputs["Coat Weight"].default_value = coat
    if trans:
        p.inputs["Transmission Weight"].default_value = trans
    if sss:
        p.inputs["Subsurface Weight"].default_value = sss
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = estr
    return m


def bump(m, kind="noise", scale=20., strength=.15, detail=4.):
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    if kind == "wave":
        t = nt.nodes.new("ShaderNodeTexWave")
        t.inputs["Scale"].default_value = scale
        fac = t.outputs["Fac"]
    else:
        t = nt.nodes.new("ShaderNodeTexNoise")
        t.inputs["Scale"].default_value = scale
        t.inputs["Detail"].default_value = detail
        fac = t.outputs["Fac"]
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = strength
    nt.links.new(fac, b.inputs["Height"])
    nt.links.new(b.outputs["Normal"], p.inputs["Normal"])


def assign(ob, m):
    ob.data.materials.clear()
    ob.data.materials.append(m)


def mesh_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me))


def bevel(ob, width=.02, segments=2):
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width, mod.segments = width, segments
    mod.limit_method = "ANGLE"
    return mod


def smooth(ob):
    for poly in ob.data.polygons:
        poly.use_smooth = True


def prim(kind, **kw):
    getattr(bpy.ops.mesh, "primitive_" + kind + "_add")(**kw)
    return bpy.context.active_object


def extruded_outline(name, pts, depth, edge_thin=None):
    """A flat outline in the XZ plane (y = 0) extruded along Y, centred. edge_thin(x, z)
    returns a 0..1 factor that thins the slab toward a cutting edge."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, 0, z)) for x, z in pts]
    edges = [bm.edges.new((verts[i], verts[(i + 1) % len(verts)])) for i in range(len(verts))]
    bmesh.ops.triangle_fill(bm, edges=edges, use_beauty=True)
    faces = list(bm.faces)
    ret = bmesh.ops.extrude_face_region(bm, geom=faces)
    moved = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    for v in bm.verts:
        v.co.y = -depth / 2
    for v in moved:
        v.co.y = depth / 2
    if edge_thin:
        for v in bm.verts:
            v.co.y *= edge_thin(v.co.x, v.co.z)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return mesh_object(name, bm)


def render(name):
    path = os.path.join(OUT, name + ".png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDERED", path)


# ------------------------------------------------------------------ props

STEEL = material
GOLD = (1.0, .74, .32)


def sword():
    # Tip at the bottom of the cell (the game points the cell's bottom along the flight).
    L, W, T, tip = 3.0, .2, .045, .55
    bm = bmesh.new()
    rings = []
    n = 30
    for i in range(n + 1):
        t = i / n
        z = -t * L
        w, th = W * (1 - .12 * t), T
        if t > 1 - tip / L:
            k = max(.004, (1 - t) / (tip / L))
            w, th = w * k ** .85, T * k
        rings.append([bm.verts.new((-w, 0, z)), bm.verts.new((0, -th, z)), bm.verts.new((w, 0, z)), bm.verts.new((0, th, z))])
    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(rings[0][::-1])
    blade = mesh_object("blade", bm)
    steel = material("steel", (.82, .84, .88), metal=1, rough=.2)
    bump(steel, scale=60, strength=.04)
    assign(blade, steel)
    gold = material("gold", GOLD, metal=1, rough=.28)
    guard = prim("cube", size=1, location=(0, 0, .06))
    guard.scale = (1.1, .14, .12)
    bevel(guard, .03, 3)
    assign(guard, gold)
    for sx in (-1, 1):
        cap = prim("uv_sphere", radius=.09, location=(sx * .56, 0, .08))
        smooth(cap)
        assign(cap, gold)
    grip = prim("cylinder", vertices=24, radius=.05, depth=.72, location=(0, 0, .48))
    smooth(grip)
    leather = material("leather", (.16, .08, .05), rough=.65)
    bump(leather, kind="wave", scale=14, strength=.5)
    assign(grip, leather)
    pommel = prim("uv_sphere", radius=.11, location=(0, 0, .9))
    smooth(pommel)
    assign(pommel, gold)
    gem = prim("uv_sphere", radius=.055, location=(0, -.08, .06))
    smooth(gem)
    assign(gem, material("gem", (.6, .05, .12), rough=.05, coat=1, emit=(1, .15, .25), estr=2.5))
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.rotation_euler.z = math.radians(28)
    lights()
    camera(center=(0, 0, -1.05), scale=4.15, azim=0, elev=6)


def axe():
    # Haft up the middle, the head at the top on the right.
    haft = prim("cylinder", vertices=24, radius=.07, depth=3.3, location=(0, 0, -.1))
    smooth(haft)
    wood = material("wood", (.32, .19, .1), rough=.6)
    bump(wood, kind="wave", scale=3, strength=.35)
    assign(haft, wood)
    blade_pts = [(.05, 1.5), (.4, 1.58), (.74, 1.72), (.98, 1.52), (1.08, 1.18), (1.02, .86), (.86, .58), (.58, .74), (.32, .84), (.05, .88)]
    head = extruded_outline("head", blade_pts, .14, edge_thin=lambda x, z: 1 - .78 * max(0., (x - .7) / .4))
    bevel(head, .015, 2)
    steel = material("steel", (.78, .8, .84), metal=1, rough=.25)
    bump(steel, scale=40, strength=.05)
    assign(head, steel)
    iron = material("iron", (.18, .18, .2), metal=1, rough=.45)
    socket = prim("cube", size=1, location=(0, 0, 1.2))
    socket.scale = (.2, .22, .78)
    bevel(socket, .03, 2)
    assign(socket, iron)
    spike = prim("cone", vertices=8, radius1=.11, radius2=0, depth=.42, location=(-.28, 0, 1.22))
    spike.rotation_euler.y = math.radians(-90)
    assign(spike, iron)
    for z in (-.9, -.2):
        band = prim("cylinder", vertices=24, radius=.085, depth=.08, location=(0, 0, z))
        assign(band, material("brass", GOLD, metal=1, rough=.3))
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.rotation_euler.z += math.radians(22)
    lights()
    camera(center=(.25, 0, 0), scale=3.6, azim=0, elev=8)


def hammer():
    haft = prim("cylinder", vertices=24, radius=.08, depth=2.7, location=(0, 0, -.45))
    smooth(haft)
    wood = material("wood", (.3, .18, .09), rough=.6)
    bump(wood, kind="wave", scale=3, strength=.35)
    assign(haft, wood)
    iron = material("iron", (.22, .22, .24), metal=1, rough=.4)
    bump(iron, scale=25, strength=.12)
    head = prim("cube", size=1, location=(0, 0, 1.15))
    head.scale = (1.35, .62, .62)
    bevel(head, .06, 3)
    assign(head, iron)
    brass = material("brass", GOLD, metal=1, rough=.3)
    for x in (-.42, .42):
        band = prim("cube", size=1, location=(x, 0, 1.15))
        band.scale = (.1, .68, .68)
        bevel(band, .02, 2)
        assign(band, brass)
    for x in (-.71, .71):
        face = prim("cylinder", vertices=32, radius=.25, depth=.05, location=(x, 0, 1.15))
        face.rotation_euler.y = math.radians(90)
        assign(face, brass)
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.rotation_euler.z += math.radians(24)
    lights()
    camera(center=(0, 0, 0), scale=3.4, azim=0, elev=10)


def chain_link():
    link_ob = prim("torus", major_radius=.5, minor_radius=.14, major_segments=48, minor_segments=16)
    link_ob.scale = (1, 1, 1.6)
    smooth(link_ob)
    steel = material("steel", (.7, .72, .76), metal=1, rough=.3)
    bump(steel, scale=30, strength=.1)
    assign(link_ob, steel)
    link_ob.rotation_euler = (math.radians(90), math.radians(-24), math.radians(28))
    lights()
    camera(scale=2.4, elev=6)


def coin():
    c = prim("cylinder", vertices=96, radius=1, depth=.16)
    c.rotation_euler.x = math.radians(90)
    bevel(c, .04, 3)
    gold = material("gold", GOLD, metal=1, rough=.26)
    assign(c, gold)
    rim = prim("torus", major_radius=.86, minor_radius=.045, major_segments=96, minor_segments=12, location=(0, -.08, 0))
    rim.rotation_euler.x = math.radians(90)
    smooth(rim)
    assign(rim, gold)
    star = []
    for k in range(8):
        a = math.pi / 2 + k * math.pi / 4
        r = .66 if k % 2 == 0 else .16
        star.append((math.cos(a) * r, math.sin(a) * r))
    s = extruded_outline("star", star, .06)
    s.location.y = -.1
    bevel(s, .02, 2)
    assign(s, gold)
    gem = prim("uv_sphere", radius=.09, location=(0, -.14, 0))
    smooth(gem)
    assign(gem, material("gem", (.35, .1, .7), rough=.05, coat=1, emit=(.6, .3, 1), estr=1.5))
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.rotation_euler.z += math.radians(18)
    lights()
    camera(scale=2.25, elev=14)


def crystal_mesh(name, height, radius, tip, sides=6, twist=0.):
    bm = bmesh.new()
    bot = [bm.verts.new((math.cos(k / sides * 6.283 + twist) * radius, math.sin(k / sides * 6.283 + twist) * radius, 0)) for k in range(sides)]
    top = [bm.verts.new((math.cos(k / sides * 6.283 + twist) * radius * .92, math.sin(k / sides * 6.283 + twist) * radius * .92, height)) for k in range(sides)]
    apex = bm.verts.new((radius * .1, 0, height + tip))
    for k in range(sides):
        bm.faces.new((bot[k], bot[(k + 1) % sides], top[(k + 1) % sides], top[k]))
        bm.faces.new((top[k], top[(k + 1) % sides], apex))
    bm.faces.new(bot[::-1])
    return mesh_object(name, bm)


def crystal_material():
    m = material("crystal", (.86, .92, 1.0), rough=.06, coat=1, trans=.3, emit=(.7, .82, 1), estr=.35)
    return m


def crystals(seed):
    m = crystal_material()
    specs = [(1.9, .34, .55, 0, 0, 8), (1.25, .24, .38, -38, .35, -14), (1.05, .2, .32, 34, -.3, 20), (.7, .15, .25, -70, .5, 0)]
    if seed == 2:
        specs = [(2.2, .3, .7, 12, 0, 0), (1.0, .2, .3, -30, .25, 10), (.85, .18, .28, 48, -.2, -20)]
    for i, (h, r, tip, tilt, off, yaw) in enumerate(specs):
        c = crystal_mesh("c%d" % i, h, r, tip, twist=i * .4)
        c.location = (off, 0, -.9)
        c.rotation_euler = (math.radians(yaw), math.radians(tilt), math.radians(i * 23))
        assign(c, m)
    lights(key=1100, rim=900)
    camera(center=(0, 0, .1), scale=3.1, azim=15, elev=12)


def spike():
    c = crystal_mesh("spike", 2.4, .42, .9, sides=5)
    c.location = (0, 0, -1.6)
    assign(c, crystal_material())
    lights(key=1100, rim=900)
    camera(center=(0, 0, .05), scale=3.5, azim=20, elev=8)


def rock(seed, lava=False):
    r = prim("ico_sphere", subdivisions=2, radius=1)
    tex = bpy.data.textures.new("n%d" % seed, "CLOUDS")
    tex.noise_scale = .9
    d = r.modifiers.new("disp", "DISPLACE")
    d.texture, d.strength = tex, .55
    d.texture_coords = "LOCAL"
    r.location = (0, 0, 0)
    r.rotation_euler = (seed * .7, seed * 1.3, seed * .4)
    r.scale = (1, .9, .8 if seed % 2 else 1)
    if lava:
        m = material("lava-rock", (.09, .07, .06), rough=.9)
        nt = m.node_tree
        p = nt.nodes["Principled BSDF"]
        vor = nt.nodes.new("ShaderNodeTexVoronoi")
        vor.feature = "DISTANCE_TO_EDGE"
        vor.inputs["Scale"].default_value = 2.6
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.
        ramp.color_ramp.elements[0].color = (1, 1, 1, 1)
        ramp.color_ramp.elements[1].position = .06
        ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = 9.
        nt.links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], mul.inputs[0])
        nt.links.new(mul.outputs[0], p.inputs["Emission Strength"])
        p.inputs["Emission Color"].default_value = (1, .42, .08, 1)
        bump(m, scale=6, strength=.4)
    else:
        m = material("rock", (.52, .5, .48), rough=.85)
        bump(m, scale=8, strength=.45)
    assign(r, m)
    lights()
    camera(scale=2.9, elev=15, azim=20)


def petal():
    # A cupped petal pointing up, near white so the identity colour tints it.
    bm = bmesh.new()
    nu, nv = 12, 24
    grid = []
    for j in range(nv + 1):
        v = j / nv
        width = .62 * math.sin(math.pi * min(1., v * 1.04)) ** .62 * (1 - .18 * v)
        row = []
        for i in range(nu + 1):
            u = i / nu * 2 - 1
            x = u * width
            z = v * 2.2 - 1.1
            y = -(.42 * u * u * (width / .62) + .28 * math.sin(math.pi * v) - .25 * v * v)
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    ob = mesh_object("petal", bm)
    smooth(ob)
    sol = ob.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = .03
    m = material("petal", (.97, .95, .96), rough=.45, sss=.35)
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = .0
    ramp.color_ramp.elements[0].color = (.72, .68, .74, 1)
    ramp.color_ramp.elements[1].position = .55
    ramp.color_ramp.elements[1].color = (.98, .97, .98, 1)
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.1
    mr.inputs["From Max"].default_value = 1.1
    nt.links.new(coord.outputs["Object"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    bump(m, kind="wave", scale=9, strength=.12)
    assign(ob, m)
    ob.rotation_euler.x = math.radians(-18)
    lights(key=800, rim=900)
    camera(scale=2.6, elev=10)


def clock_hand():
    right = [(0, 1.62), (.22, 1.28), (.1, 1.12), (.055, 1.05), (.055, .5), (.18, .26), (.055, .02), (.05, -1.1)]
    pts = right + [(-x, z) for x, z in reversed(right[1:])]
    hand = extruded_outline("hand", pts, .06)
    bevel(hand, .015, 2)
    brass = material("brass", GOLD, metal=1, rough=.28)
    assign(hand, brass)
    hub = prim("cylinder", vertices=48, radius=.22, depth=.12, location=(0, 0, -1.2))
    hub.rotation_euler.x = math.radians(90)
    bevel(hub, .03, 3)
    assign(hub, brass)
    pin = prim("uv_sphere", radius=.08, location=(0, -.08, -1.2))
    smooth(pin)
    assign(pin, material("pin", (.12, .1, .1), metal=1, rough=.3))
    hole = prim("cylinder", vertices=24, radius=.07, depth=.08, location=(0, -.02, 1.22))
    hole.rotation_euler.x = math.radians(90)
    assign(hole, material("hole", (.05, .04, .04), rough=.5))
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.rotation_euler.z += math.radians(14)
    lights()
    camera(center=(0, 0, .2), scale=3.2, elev=10)


def needle():
    shaft = prim("cone", vertices=24, radius1=.006, radius2=.05, depth=2.6, location=(0, 0, -.25))
    smooth(shaft)
    assign(shaft, material("gold", GOLD, metal=1, rough=.25))
    pearl = prim("uv_sphere", radius=.2, location=(0, 0, 1.25))
    smooth(pearl)
    assign(pearl, material("pearl", (.95, .93, .9), rough=.18, coat=1, sss=.2))
    for z in (.95, 1.02):
        ring = prim("torus", major_radius=.06, minor_radius=.02, location=(0, 0, z))
        assign(ring, material("gold2", GOLD, metal=1, rough=.3))
    lights()
    camera(center=(0, 0, -.05), scale=3.2, azim=20, elev=6)


PROPS = {
    "sword": sword, "axe": axe, "hammer": hammer, "chain": chain_link, "coin": coin,
    "crystalA": lambda: crystals(1), "crystalB": lambda: crystals(2), "spike": spike,
    "meteor": lambda: rock(3, lava=True), "rockA": lambda: rock(1), "rockB": lambda: rock(2),
    "petal": petal, "clock": clock_hand, "needle": needle,
}

for name, build in PROPS.items():
    if ONLY and name not in ONLY:
        continue
    reset()
    build()
    render(name)
