"""Home-street walkers, second pass (2026-10-17, user: 街上走来走去那些人物还是不够精细).

The first pass rendered each model at 256 px, so a near walker (60-80 points tall on an
iPhone, 200+ pixels) was a 130-pixel frame stretched about two times. This pass renders the
same eight street directions at a larger size for downsampling (tools/harbor/package_home_walkers_v2.py),
lights the figures like the harbour painting (warm key from the upper left, cool fill, a rim
from behind), looks down a little more, and lowers the arms that the shared courier walk held
away from the bodies of the resident models.

Run in Blender:
  Blender --background --factory-startup --python tools/harbor/render_home_walkers_v2.py -- \
      MODEL.glb OUTPUT_DIR [--size 768] [--arms 0.6] [--swing 0.55] [--only DIRECTION:FRAME]
      [--tint R,G,B] [--hue SHIFT,SAT,VALUE]
Writes OUTPUT_DIR/<direction>-<frame>.png; rows (directions) are away, away-right, right,
toward-right, toward, toward-left, left, away-left, as in the first pass.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Quaternion, Vector

args = sys.argv[sys.argv.index("--") + 1:]
model, destination = Path(args[0]), Path(args[1])
def option(name, default):
    return args[args.index(name) + 1] if name in args else default
size_px = int(option("--size", "768"))
arm_drop = float(option("--arms", "0.6"))       # radians the upper arms come down towards the body
swing = float(option("--swing", "0.55"))        # share of the walk's arm swing that is kept
hue = option("--hue", None)                      # "shift,saturation,value": recolour clothes, keep skin and hair
only = option("--only", None)
rows = [int(r) for r in option("--rows", "0,1,2,3,4,5,6,7").split(",")]   # the app mirrors 5-7 from 3-1
tint = option("--tint", None)
destination.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(model))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == "ARMATURE")
meshes = [o for o in scene.objects if o.type == "MESH" and o.visible_get() and len(o.data.polygons) > 200]
for o in scene.objects:
    if o.type == "MESH" and o not in meshes:
        o.hide_render = True   # helper spheres and markers that came with some exports
action = rig.animation_data.action
start, end = action.frame_range

# Lower the upper arms in every key of the walk (the courier walk was keyed for a body whose
# arms rest further from the torso). The rotation is about each arm's own forward axis, found
# from the rest pose so the same value works for left and right.
if arm_drop or swing != 1:
    for side in ("Left", "Right"):
        bone = rig.data.bones.get(side + "Arm")
        if not bone:
            continue
        # Rest-space: rotate around the axis perpendicular to the bone and to world up.
        along = (bone.matrix_local.to_3x3() @ Vector((0, 1, 0))).normalized()
        axis_world = along.cross(Vector((0, 0, 1))).normalized()
        axis_local = (bone.matrix_local.to_3x3().inverted() @ axis_world).normalized()
        offset = Quaternion(axis_local, -arm_drop)
        path = f'pose.bones["{side}Arm"].rotation_quaternion'
        curves = [c for c in action.fcurves if c.data_path == path] if hasattr(action, "fcurves") else []
        if not curves:   # Blender 5 layered actions keep curves in channel bags
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        curves += [c for c in bag.fcurves if c.data_path == path]
        curves = sorted(curves, key=lambda c: c.array_index)
        if len(curves) != 4:
            continue
        for i in range(len(curves[0].keyframe_points)):
            q = Quaternion([curves[k].keyframe_points[i].co[1] for k in range(4)])
            # The courier swing lifts the trailing arm almost level; keep part of it.
            q = Quaternion().slerp(q, swing) @ offset
            for k in range(4):
                curves[k].keyframe_points[i].co[1] = q[k]
                curves[k].keyframe_points[i].handle_left[1] = q[k]
                curves[k].keyframe_points[i].handle_right[1] = q[k]
        for c in curves:
            c.update()

if tint:
    # An overall cloth tint for a citizen who shares a base model (multiplies base colour).
    r, g, b = (float(v) for v in tint.split(","))
    for o in meshes:
        for slot in o.material_slots:
            mat = slot.material
            if not mat or not mat.use_nodes:
                continue
            bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if not bsdf or not bsdf.inputs["Base Color"].is_linked:
                continue
            link = bsdf.inputs["Base Color"].links[0]
            mix = mat.node_tree.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"; mix.inputs["Factor"].default_value = 1.0
            mix.inputs[7].default_value = (r, g, b, 1)
            mat.node_tree.links.new(link.from_socket, mix.inputs[6])
            mat.node_tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])

if hue:
    # A citizen who shares a base model gets other clothes: the base-colour texture's hue turns
    # by SHIFT (0-1) with SAT/VALUE scaling, except where it looks like skin or fair hair (warm
    # hues, moderate saturation, not dark), which stays as painted. Done on the texture pixels
    # (sRGB), where those ranges are predictable.
    import numpy as np
    shift, sat, val = (float(v) for v in hue.split(","))
    images = set()
    for o in meshes:
        for slot in o.material_slots:
            mat = slot.material
            if not mat or not mat.use_nodes:
                continue
            bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            # glTF imports may put a factor node between the texture and the shader.
            stack = [bsdf.inputs["Base Color"]] if bsdf else []
            while stack:
                socket = stack.pop()
                for link in socket.links:
                    node = link.from_node
                    if node.type == "TEX_IMAGE" and node.image:
                        images.add(node.image)
                    else:
                        stack.extend(i for i in node.inputs if i.is_linked)
    for image in images:
        px = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
        rgb = px[:, :3]
        mx, mn = rgb.max(1), rgb.min(1)
        delta = mx - mn
        h = np.zeros_like(mx)
        nz = delta > 1e-6
        r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
        rmax = nz & (mx == r); gmax = nz & (mx == g) & ~rmax; bmax = nz & ~rmax & ~gmax
        h[rmax] = ((g - b)[rmax] / delta[rmax]) % 6
        h[gmax] = (b - r)[gmax] / delta[gmax] + 2
        h[bmax] = (r - g)[bmax] / delta[bmax] + 4
        h = h / 6
        sv = np.where(mx > 1e-6, delta / np.maximum(mx, 1e-6), 0)
        v = mx
        skin = ((h < 0.115) | (h > 0.97)) & (sv > 0.12) & (sv < 0.7) & (v > 0.3)
        h2 = np.where(skin, h, (h + shift) % 1)
        s2 = np.where(skin, sv, np.clip(sv * sat, 0, 1))
        v2 = np.where(skin, v, np.clip(v * val, 0, 1))
        i = np.floor(h2 * 6).astype(int) % 6
        f = h2 * 6 - np.floor(h2 * 6)
        p_ = v2 * (1 - s2); q_ = v2 * (1 - f * s2); t_ = v2 * (1 - (1 - f) * s2)
        out = np.stack([np.choose(i, [v2, q_, p_, p_, t_, v2]),
                        np.choose(i, [t_, v2, v2, q_, p_, p_]),
                        np.choose(i, [p_, p_, t_, v2, v2, q_])], 1)
        px[:, :3] = out
        image.pixels[:] = px.ravel()
        image.update()
        print("RECOLOURED", image.name, round(float(skin.mean()), 3), "kept as skin/hair", flush=True)

frames = [round(start + (end - start) * i / 8) for i in range(8)]
points = []
for frame in frames:
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    points.extend(o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box)
low = Vector(tuple(min(p[a] for p in points) for a in range(3)))
high = Vector(tuple(max(p[a] for p in points) for a in range(3)))
center = (low + high) / 2
extent = high - low

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = size_px
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.filter_size = 1.2
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.compression = 40
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
if scene.world is None:
    scene.world = bpy.data.worlds.new("street")
scene.world.use_nodes = True
background = scene.world.node_tree.nodes.get("Background")
background.inputs["Color"].default_value = (0.42, 0.47, 0.58, 1)   # sky bounce, cool
background.inputs["Strength"].default_value = 0.55

camera_data = bpy.data.cameras.new("home street walker")
camera = bpy.data.objects.new("home street walker", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
camera_data.ortho_scale = max(extent.z * 1.18, extent.x * 1.7, extent.y * 1.7)

def light(name, kind, energy, color, size):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy; data.color = color
    if kind == "AREA": data.shape = "DISK"; data.size = size
    if kind == "SUN": data.angle = size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return obj

key = light("warm key", "SUN", 4.2, (1.0, 0.93, 0.82), math.radians(8))
fill = light("cool fill", "AREA", 260, (0.70, 0.80, 1.0), 6)
rim = light("rim", "AREA", 520, (1.0, 0.90, 0.78), 3)

distance = max(extent.length, 2) * 3
elevation = math.radians(24)
for direction in rows:
    angle = direction * math.pi / 4
    view = Vector((-math.sin(angle), math.cos(angle), 0))
    camera.location = center + view * distance * math.cos(elevation) + Vector((0, 0, distance * math.sin(elevation)))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    # The painting is lit from the upper left of the screen: keep the key on the camera's left.
    right = view.cross(Vector((0, 0, 1))).normalized()
    key.rotation_euler = (-(right * -0.8 + view * 0.6 + Vector((0, 0, 1.4)))).to_track_quat("-Z", "Y").to_euler()
    fill.location = center + right * distance * 0.6 + view * distance * 0.5 + Vector((0, 0, extent.z * 0.4))
    fill.rotation_euler = (center - fill.location).to_track_quat("-Z", "Y").to_euler()
    rim.location = center - view * distance * 0.7 + Vector((0, 0, extent.z * 1.2))
    rim.rotation_euler = (center - rim.location).to_track_quat("-Z", "Y").to_euler()
    for index, frame in enumerate(frames):
        if only and only != f"{direction}:{index}":
            continue
        if (destination / f"{direction}-{index}.png").exists() and not only:
            continue
        scene.frame_set(frame)
        scene.render.filepath = str(destination / f"{direction}-{index}.png")
        bpy.ops.render.render(write_still=True)
    print("WALKER DIRECTION", model.stem, direction, flush=True)
print("WALKER DONE", model.stem, tuple(round(v, 3) for v in extent), flush=True)
