"""Build the independent, non-patient B10 transfer organ actor."""
import bpy
import math
from pathlib import Path

from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parent / "b10-vessel"
ROOT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def sphere(name, where, size):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, location=where)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def tube(name, points, radius):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, location in zip(spline.bezier_points, points):
        point.co = location
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    for index, point in enumerate(spline.bezier_points):
        point.radius = max(.18, 1 - index / max(1, len(points) - 1) * .65)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def attach_uv(obj, band):
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
    coords = [vertex.co for vertex in obj.data.vertices]
    low_x, high_x = min(v.x for v in coords), max(v.x for v in coords)
    low_z, high_z = min(v.z for v in coords), max(v.z for v in coords)
    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex = coords[obj.data.loops[loop_index].vertex_index]
            u = (vertex.x - low_x) / max(.001, high_x - low_x)
            v = (vertex.z - low_z) / max(.001, high_z - low_z)
            uv.data[loop_index].uv = ((band + .04 + .92 * u) / 5, .03 + .94 * v)
    return obj


pieces = []
def add(obj, band):
    pieces.append(attach_uv(obj, band))


for index, (where, size) in enumerate([
    ((0, 0, 1.16), (.32, .24, .42)),
    ((-.21, .04, 1.08), (.23, .22, .34)),
    ((.22, .02, 1.11), (.20, .23, .37)),
]):
    lobe = sphere("Garnet_sac_" + str(index), where, size)
    for vertex in lobe.data.vertices:
        vertex.co.x += .018 * math.sin(vertex.co.z * 17 + index * 2)
        vertex.co.y += .02 * math.sin(vertex.co.x * 19 + vertex.co.z * 11)
    add(lobe, 0)
add(sphere("Carved_osteal_valve", (0, -.22, 1.48), (.16, .12, .25)), 1)
add(sphere("Bronze_contract_seal", (0, -.35, 1.48), (.11, .047, .13)), 2)
for sign in (-1, 1):
    add(tube("Curved_black_siphon_" + str(sign),
        [(sign * .24, .10, 1.42), (sign * .47, .16, 1.24),
         (sign * .38, .16, .94), (sign * .54, .03, .73),
         (sign * .61, -.10, .65)], .059), 3)
    add(tube("Trailing_membrane_" + str(sign),
        [(sign * .19, -.10, .89), (sign * .33, -.25, .72),
         (sign * .25, -.39, .57), (sign * .4, -.49, .53)], .033), 4)
    add(tube("Front_bronze_rib_" + str(sign),
        [(sign * .05, -.36, 1.51), (sign * .24, -.30, 1.40),
         (sign * .38, -.22, 1.12), (sign * .21, -.31, .89),
         (sign * .06, -.32, .79)], .020), 2)
    add(tube("Bent_suture_" + str(sign),
        [(0, -.38, 1.26 + sign * .05), (sign * .15, -.37, 1.15),
         (0, -.39, 1.05 - sign * .03)], .014), 2)
    for level in range(3):
        add(sphere("Bronze_pin_%s_%s" % (sign, level),
                   (sign * (.29 + level * .035), -.29 + level * .03, 1.31 - level * .15),
                   (.027, .026, .028)), 2)
for level in range(4):
    add(tube("Irregular_vein_" + str(level),
        [(-.21 + level * .12, -.23, 1.37),
         (-.24 + level * .13, -.35, 1.22),
         (-.14 + level * .07, -.33, 1.04)], .012), 4)
bpy.ops.object.select_all(action="DESELECT")
for obj in pieces:
    obj.select_set(True)
bpy.context.view_layer.objects.active = pieces[0]
bpy.ops.object.join()
mesh = bpy.context.object
mesh.name = "B10VesselBody"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for polygon in mesh.data.polygons:
    polygon.use_smooth = True

base = bpy.data.images.load(str(ROOT / "B10Vessel_BaseColor_2k.png"))
material = bpy.data.materials.new("B10Vessel_PBR")
material.use_nodes = True
nodes, links = material.node_tree.nodes, material.node_tree.links
texture = nodes.new("ShaderNodeTexImage")
texture.image = base
links.new(texture.outputs["Color"], nodes.get("Principled BSDF").inputs["Base Color"])
mesh.data.materials.append(material)

arm_data = bpy.data.armatures.new("B10VesselSkeleton")
arm = bpy.data.objects.new("B10VesselRig", arm_data)
bpy.context.collection.objects.link(arm)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
layout = {"Root": ((0, 0, .5), (0, 0, .6), None),
          "Belly": ((0, 0, .75), (0, 0, 1.30), "Root"),
          "Valve": ((0, -.15, 1.30), (0, -.34, 1.63), "Belly"),
          "Tendril.L": ((.21, .05, 1.36), (.46, .22, .71), "Belly"),
          "Tendril.R": ((-.21, .05, 1.36), (-.46, .22, .71), "Belly")}
for name, (head, tail, parent) in layout.items():
    bone = arm_data.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    if parent:
        bone.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
mesh.parent = arm
mesh.modifiers.new("Skin", "ARMATURE").object = arm
for name in layout:
    mesh.vertex_groups.new(name=name)
for vertex in mesh.data.vertices:
    x, y, z = vertex.co
    group = "Valve" if z > 1.45 and y < -.12 else \
        "Tendril.L" if x > .24 and z < 1.38 else \
        "Tendril.R" if x < -.24 and z < 1.38 else "Belly"
    mesh.vertex_groups[group].add([vertex.index], 1, "REPLACE")
for bone in arm.pose.bones:
    bone.rotation_mode = "QUATERNION"
arm.animation_data_create()
arm.animation_data.action = bpy.data.actions.new("B10VesselCombat")
clips = {"Idle": (1, 121), "Charge": (122, 166), "Cast": (167, 196),
         "Hit": (197, 208), "Death": (209, 244), "Charge2": (245, 289),
         "Cast2": (290, 319), "Retreat": (320, 359)}
for frame in range(1, 360):
    for bone in arm.pose.bones:
        bone.rotation_quaternion = Quaternion()
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)
    clip = next(name for name, (a, b) in clips.items() if a <= frame <= b)
    start, end = clips[clip]
    t = (frame - start) / (end - start)
    pulse = math.sin(t * math.pi * 2)
    if clip == "Idle":
        arm.pose.bones["Belly"].scale = (1 + .025 * pulse,) * 3
        arm.pose.bones["Valve"].rotation_quaternion = Quaternion(Vector((0, 0, 1)), math.radians(3 * pulse))
    elif clip.startswith("Charge"):
        arm.pose.bones["Belly"].scale = (1 + .10 * t,) * 3
        arm.pose.bones["Valve"].rotation_quaternion = Quaternion(Vector((1, 0, 0)), math.radians(-14 * t))
    elif clip.startswith("Cast"):
        arm.pose.bones["Valve"].rotation_quaternion = Quaternion(Vector((1, 0, 0)), math.radians(-14 + 26 * math.sin(math.pi * t)))
        arm.pose.bones["Belly"].scale = (1 + .1 * (1 - t),) * 3
    elif clip == "Hit":
        arm.pose.bones["Belly"].scale = (1 - .06 * math.sin(math.pi * t),) * 3
    elif clip == "Death":
        arm.pose.bones["Belly"].scale = (1 - .22 * t,) * 3
    for bone in arm.pose.bones:
        bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
        bone.keyframe_insert("location", frame=frame, group=bone.name)
        bone.keyframe_insert("scale", frame=frame, group=bone.name)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 359
bpy.context.scene.render.fps = 30
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "B10Vessel_Combat.blend"))
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.fbx(filepath=str(ROOT / "B10Vessel_Combat.fbx"), use_selection=True,
                         object_types={"ARMATURE", "MESH"}, axis_forward="-Z", axis_up="Y",
                         add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=False,
                         bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0,
                         path_mode="RELATIVE")
print("BOUNTY_VESSEL_EXPORTED", len(mesh.data.polygons), len(arm_data.bones), flush=True)
