"""The memory leech (Q8 不属于我的名字) as a pool of living crude oil, rendered in Blender
(2026-10-12, user on the flat grey blob with grey balls: 这个泡泡不好看，要更生动，如同石油一般冒泡
起伏，略微蠕动 / 用blender画逼真些).

A height field on a polar grid, rebuilt every frame so the loop closes exactly: a flat-topped
pool with a rounded rim whose outline writhes slowly (travelling waves round the edge), a slow
swell across the surface, and bubbles that rise as glossy domes, swell, pop and leave a fading
ripple. Black oil with a clear coat and a thin-film rainbow sheen, studio HDRI reflections, a
soft key from the upper left, a shadow catcher under it, transparent film.

Renders FRAMES frames of one seamless loop to <out-dir>/leech_####.png (W x H, RGBA).

usage:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P blender_leech.py -- <out-dir> [frames] [samples] [start]
"""
import glob
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/leech-render"
FRAMES = int(ARGS[1]) if len(ARGS) > 1 else 48
SAMPLES = int(ARGS[2]) if len(ARGS) > 2 else 64
START = int(ARGS[3]) if len(ARGS) > 3 else 0   # resume a loop part-way (Metal's kernel cache can crash a long run)
W, H = 512, 256
os.makedirs(OUT, exist_ok=True)
HDRI = (glob.glob("/Applications/Blender.app/Contents/Resources/*/datafiles/studiolights/world/studio.exr") or [None])[0]

NR, NS = 84, 220          # rings, segments of the polar grid
THICK = .15               # pool depth at the centre (the pool is ~2 units wide)
TAU = math.tau

# Bubbles: polar centre (rho, theta), max radius, cycles per loop (integer, so the loop closes),
# phase offset. Bigger ones rise slower.
BUBBLES = [
    (.15, .4, .24, 1, .00), (.58, 1.1, .15, 2, .35), (.50, 2.7, .19, 1, .55), (.66, 3.9, .12, 2, .12),
    (.40, 5.0, .17, 1, .80), (.70, 5.8, .10, 3, .48), (.36, 2.0, .09, 3, .88), (.72, .1, .11, 2, .68),
]


def smooth(x):
    x = min(1., max(0., x))
    return x * x * (3 - 2 * x)


def rim(theta, ph):
    """The pool's outline radius at angle theta and loop phase ph (0..TAU): slow travelling
    waves round the edge (the writhing) on a lumpy, slightly oval shape."""
    return (1. + .10 * math.sin(3 * theta + .6 + ph) + .06 * math.sin(5 * theta - 1.3 - 2 * ph)
            + .045 * math.sin(2 * theta + 2.1 + ph) + .03 * math.sin(7 * theta + .4 + 3 * ph))


def height(x, y, rho, ph):
    """Surface height at (x, y), rho = fraction of the way out to the rim."""
    base = THICK * (max(0., 1. - rho ** 4)) ** .55
    inner = max(0., 1. - rho * rho)
    # The whole mass heaves: slow swells crossing it and a breath of its depth.
    swell = .035 * inner * (math.sin(2.2 * x + 1.4 * y + ph) + .7 * math.sin(-1.6 * x + 2.5 * y - 2 * ph + .8))
    h = base * (1 + .12 * math.sin(ph + .5)) + swell
    for (br, bt, rmax, cyc, off) in BUBBLES:
        bx, by = br * math.cos(bt), br * math.sin(bt) * .78
        d = math.hypot(x - bx, y - by)
        if d > rmax * 2.2: continue
        p = (ph / TAU * cyc + off) % 1.
        if p < .78:   # rising and swelling: a soft dome pushing up out of the oil (not a marble on top,
                      # v1), taller and rounder just before it pops
            r = rmax * smooth(p / .78) ** .7
            if d < r * 1.25:
                u = min(1., d / (r * 1.25))
                h += r * (.42 + .38 * smooth((p - .45) / .33)) * (1 - u * u) ** .75   # round top, soft foot (v3 came to points)
        else:         # popped: a dimple, then one ripple running out and fading
            q = (p - .78) / .22
            h -= .03 * rmax / .2 * math.exp(-(d / (rmax * .5)) ** 2) * (1 - smooth(q * 2.5))
            rr = rmax * (.6 + 2.2 * q)
            h += .012 * (1 - q) * math.exp(-((d - rr) / (.04 + .05 * q)) ** 2)
    return h * inner ** .05 if rho < 1 else 0.


def build_mesh():
    me = bpy.data.meshes.new("leech")
    verts = [(0, 0, 0)]
    for i in range(1, NR + 1):
        for j in range(NS):
            verts.append((0, 0, 0))
    faces = []
    for j in range(NS):
        faces.append((0, 1 + j, 1 + (j + 1) % NS))
    for i in range(1, NR):
        for j in range(NS):
            a = 1 + (i - 1) * NS + j; b = 1 + (i - 1) * NS + (j + 1) % NS
            c = 1 + i * NS + (j + 1) % NS; d = 1 + i * NS + j
            faces.append((a, d, c, b))
    me.from_pydata(verts, [], faces)
    me.update()
    for p in me.polygons: p.use_smooth = True
    ob = bpy.data.objects.new("leech", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def shape(ob, ph):
    co = [0., 0., height(0, 0, 0, ph)]
    for i in range(1, NR + 1):
        rho = (i / NR) ** .8          # rings crowd toward the rim, where the meniscus curves
        for j in range(NS):
            th = TAU * j / NS
            R = rim(th, ph) * rho
            x, y = R * math.cos(th), R * math.sin(th) * .78
            co += [x, y, height(x, y, rho, ph)]
    ob.data.vertices.foreach_set("co", co)
    ob.data.update()


def oil_material():
    m = bpy.data.materials.new("crude oil"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    def inp(*names):
        for n in names:
            if n in b.inputs: return b.inputs[n]
    inp("Base Color").default_value = (.004, .0045, .006, 1)
    inp("Roughness").default_value = .05
    if inp("Specular IOR Level"): inp("Specular IOR Level").default_value = .5
    if inp("Coat Weight"): inp("Coat Weight").default_value = .25
    if inp("Coat Roughness"): inp("Coat Roughness").default_value = .02
    tf = inp("Thin Film Thickness")
    if tf:   # the rainbow sheen of oil, thicker and thinner in drifting patches
        noise = nt.nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 2.2
        noise.inputs["Detail"].default_value = 3.
        ramp = nt.nodes.new("ShaderNodeMapRange")
        ramp.inputs["To Min"].default_value = 220.; ramp.inputs["To Max"].default_value = 720.
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Value"]); nt.links.new(ramp.outputs["Result"], tf)
        if inp("Thin Film IOR"): inp("Thin Film IOR").default_value = 1.45
    return m


def scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"; prefs.get_devices()
        for d in prefs.devices: d.use = True
        sc.cycles.device = "GPU"
    except Exception as e:
        print("GPU setup failed", e)
    sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "AgX"   # highlights roll off instead of clipping white
    # World: a hand-set outdoor surround for the reflections - light sky overhead, the plaza's grey
    # buildings and marble round the horizon, dark below. At this grazing view the oil mostly mirrors
    # the horizon band, so it stays dark; bubble tops catch the sky. (A studio HDRI made it black
    # plastic, v2; a full sky made it pale blue, v3.)
    world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
    wn = world.node_tree; bg = wn.nodes["Background"]; bg.inputs["Strength"].default_value = 1.
    tc = wn.nodes.new("ShaderNodeTexCoord"); sep = wn.nodes.new("ShaderNodeSeparateXYZ")
    ramp = wn.nodes.new("ShaderNodeValToRGB"); cr = ramp.color_ramp
    wn.links.new(tc.outputs["Generated"], sep.inputs["Vector"]); wn.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    cr.elements[0].position = .0; cr.elements[0].color = (.012, .012, .014, 1)
    cr.elements[1].position = 1.; cr.elements[1].color = (.42, .52, .70, 1)
    e = cr.elements.new(.47); e.color = (.03, .028, .03, 1)        # the floor and the shadows
    e = cr.elements.new(.53); e.color = (.11, .10, .10, 1)         # grey buildings at the horizon
    e = cr.elements.new(.62); e.color = (.30, .34, .42, 1)         # hazy low sky
    wn.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    # Key light from the upper left (the battlefield's sun), a cool rim behind.
    key = bpy.data.lights.new("key", "AREA"); key.energy = 260; key.size = .8   # small: sharp glints on the bubbles
    ko = bpy.data.objects.new("key", key); sc.collection.objects.link(ko)
    ko.location = (-2.2, -2., 5.5);   # high, so the shadow stays a short contact shadow ko.rotation_euler = (Vector((0, 0, 0)) - ko.location).to_track_quat("-Z", "Y").to_euler()
    rim_l = bpy.data.lights.new("rim", "AREA"); rim_l.energy = 160; rim_l.size = 2.; rim_l.color = (.75, .82, 1.)
    ro = bpy.data.objects.new("rim", rim_l); sc.collection.objects.link(ro)
    ro.location = (2.5, 4., 2.5); ro.rotation_euler = (Vector((0, 0, 0)) - ro.location).to_track_quat("-Z", "Y").to_euler()
    # Shadow catcher floor: a soft contact shadow in the alpha.
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, -.001))
    floor = bpy.context.active_object; floor.is_shadow_catcher = True
    # Camera low over the pool, as the battle camera sees the plaza floor.
    cam = bpy.data.cameras.new("cam"); cam.lens = 60   # the pool fills the frame
    co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
    elev = math.radians(19); dist = 5.6
    co.location = (0, -dist * math.cos(elev), dist * math.sin(elev) + .05)
    co.rotation_euler = (Vector((0, 0, .08)) - co.location).to_track_quat("-Z", "Y").to_euler()
    return sc


def write_meta(sc):
    """Where the pool's centre on the ground lands in the frame and how many pixels one unit
    spans there, for placing the flipbook in the battle (leech.json next to the frames)."""
    import json
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()   # the camera's matrix is stale until the scene is evaluated
    def px(p):
        v = world_to_camera_view(sc, sc.camera, Vector(p))
        return v.x * W, (1 - v.y) * H
    ox, oy = px((0, 0, 0)); rx, _ = px((1, 0, 0)); lx, _ = px((-1, 0, 0))
    meta = {"frames": FRAMES, "width": W, "height": H, "originPx": [round(ox, 1), round(oy, 1)],
            "pxPerUnit": round((rx - lx) / 2, 2), "poolRadius": 1.0}
    with open(os.path.join(OUT, "leech.json"), "w") as f: json.dump(meta, f, indent=1)
    print("meta", meta)


def main():
    sc = scene()
    ob = build_mesh(); ob.data.materials.append(oil_material())
    write_meta(sc)
    for f in range(START, FRAMES):
        shape(ob, TAU * f / FRAMES)
        sc.render.filepath = os.path.join(OUT, f"leech_{f:04d}.png")
        bpy.ops.render.render(write_still=True)
        print("frame", f, flush=True)


main()
