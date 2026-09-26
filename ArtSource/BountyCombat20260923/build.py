"""Build independent, mobile-sized bounty actors from archived GLB masters.

Run with Blender in background mode: blender -b -t 4 -P build.py -- b07
The source GLBs are only read; the editable rig, clips, FBX and textures are
written below this directory.  The Unity importer owns clip slicing.
"""
import bpy
import json
import math
import sys
from pathlib import Path

import numpy as np
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parent
ARCHIVE = ROOT.parent / "BountyIntake20260922" / "originals"
COPPER = ROOT.parent / "CopperbackBounty20260922" / "textured-v1" / "Copperback_Guardian_Textured_v1.glb"
SOURCES = {
    "b01": ARCHIVE / "Meshy_AI_The_Iron_Inquisitor_0923025334_texture.glb",
    "b02": ARCHIVE / "Meshy_AI_The_Clockwork_Butcher_0923025322_texture.glb",
    "b03": ARCHIVE / "Meshy_AI_Azure_Anchorlord_0923021052_texture.glb",
    "b05": ARCHIVE / "Meshy_AI_Crimson_Seamstress_0923021042_texture.glb",
    "b07": ARCHIVE / "Meshy_AI_Azure_Belltoad_0923021028_texture.glb",
    "b08": ARCHIVE / "Meshy_AI_The_Masquerade_Duelis_0923021104_texture.glb",
    "b09": COPPER,
    "b10": ARCHIVE / "Meshy_AI_Crimson_Moon_Empress_0923021014_texture.glb",
}
CLIPS = {"Idle": (1, 121), "Charge": (122, 166), "Cast": (167, 196),
         "Hit": (197, 208), "Death": (209, 244), "Charge2": (245, 289),
         "Cast2": (290, 319), "Retreat": (320, 359)}


def rig_layout(kind):
    beast = kind == "b09"
    frog = kind == "b07"
    d = {"Root": ((0, 0, 0), (0, 0, .12), None)}
    if beast:
        d.update({"Pelvis": ((0, .30, .76), (0, .1, .92), "Root"),
                  "Chest": ((0, .1, .92), (0, -.35, 1.16), "Pelvis"),
                  "Head": ((0, -.35, 1.16), (0, -.78, 1.42), "Chest"),
                  "Armor.L": ((.2, 0, 1.29), (.65, .05, 1.42), "Chest"),
                  "Armor.R": ((-.2, 0, 1.29), (-.65, .05, 1.42), "Chest")})
        arm = ((.42, -.34, 1.03), (.53, -.44, .69), (.60, -.52, .18), (.62, -.62, .06))
        leg = ((.43, .33, .82), (.51, .43, .52), (.56, .48, .16), (.58, .34, .05))
    elif frog:
        d.update({"Pelvis": ((0, .05, .49), (0, -.03, .77), "Root"),
                  "Chest": ((0, -.03, .77), (0, -.12, 1.15), "Pelvis"),
                  "Head": ((0, -.12, 1.15), (0, -.34, 1.53), "Chest"),
                  "Throat": ((0, -.34, 1.15), (0, -.51, 1.09), "Chest")})
        arm = ((.40, -.11, 1.01), (.59, -.16, .69), (.70, -.35, .23), (.72, -.57, .05))
        leg = ((.39, .18, .49), (.56, .29, .33), (.61, .44, .13), (.72, .3, .05))
    else:
        d.update({"Pelvis": ((0, .03, .85), (0, .02, 1.08), "Root"),
                  "Chest": ((0, .02, 1.08), (0, -.02, 1.52), "Pelvis"),
                  "Head": ((0, -.02, 1.52), (0, -.05, 1.83), "Chest")})
        arm = ((.23, -.02, 1.46), (.38, -.04, 1.18), (.49, -.07, .94), (.53, -.12, .76))
        leg = ((.18, .04, .83), (.22, -.01, .47), (.25, -.02, .14), (.29, -.19, .04))
        if kind == "b02":
            d["BackFrame"] = ((0, .17, 1.36), (0, .34, 1.62), "Chest")
        if kind in ("b03", "b05", "b08", "b10"):
            for side, sign in (("L", 1), ("R", -1)):
                d["Coat." + side] = ((sign * .19, .08, .9),
                                      (sign * .29, .17, .32), "Pelvis")
    for side, sign in (("L", 1), ("R", -1)):
        at = lambda p: (sign * p[0], p[1], p[2])
        d["UpperArm." + side] = (at(arm[0]), at(arm[1]), "Chest")
        d["Forearm." + side] = (at(arm[1]), at(arm[2]), "UpperArm." + side)
        d["Hand." + side] = (at(arm[2]), at(arm[3]), "Root" if beast or frog else "Forearm." + side)
        d["Thigh." + side] = (at(leg[0]), at(leg[1]), "Root" if beast or frog else "Pelvis")
        d["Shin." + side] = (at(leg[1]), at(leg[2]), "Thigh." + side)
        d["Foot." + side] = (at(leg[2]), at(leg[3]), "Root" if beast or frog else "Shin." + side)
    return d


def main(kind):
    source = SOURCES[kind]
    if not source.exists():
        raise FileNotFoundError(source)
    output = ROOT / kind
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError(f"Expected one authored mesh: {kind}, got {len(meshes)}")
    mesh = meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    coordinates = np.array([v.co[:] for v in mesh.data.vertices], dtype=np.float32)
    minimum, maximum = coordinates.min(0), coordinates.max(0)
    factor = 2 / (maximum[2] - minimum[2])
    coordinates -= np.array([(minimum[0] + maximum[0]) / 2,
                             (minimum[1] + maximum[1]) / 2, minimum[2]], dtype=np.float32)
    coordinates *= factor
    mesh.data.vertices.foreach_set("co", coordinates.ravel())
    mesh.data.update()
    tris_before = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    modifier = mesh.modifiers.new("MobileReduction", "DECIMATE")
    modifier.ratio = min(1.0, 50000 / tris_before)
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for face in mesh.data.polygons:
        face.use_smooth = True
    mesh.name = kind.upper() + "Body"
    print("PREPARED", kind, tris_before, len(mesh.data.polygons), flush=True)

    images = {}
    for mat in mesh.data.materials:
        if not mat or not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type != "TEX_IMAGE" or not node.image:
                continue
            old = node.image
            label = old.name.lower()
            role = "BaseColor" if "image_0" in label or "basecolor" in label else \
                "Normal" if "image_2" in label or "normal" in label else "MetalRough"
            if role in images:
                node.image = images[role]
                continue
            if max(old.size) > 2048:
                old.scale(2048, 2048)
            old.filepath_raw = str(output / f"{kind.upper()}_{role}_2k.png")
            old.file_format = "PNG"
            old.save()
            old.pack()
            images[role] = old
    if "BaseColor" not in images:
        raise RuntimeError(f"No base color texture: {kind}")
    if "Normal" not in images:
        flat = bpy.data.images.new(kind.upper() + "_flat_normal", width=4, height=4, alpha=True)
        flat.pixels = [.5, .5, 1, 1] * 16
        flat.filepath_raw = str(output / f"{kind.upper()}_Normal_2k.png")
        flat.file_format = "PNG"
        flat.save()
    if "MetalRough" in images:
        mr = images["MetalRough"]
        pixels = np.empty(len(mr.pixels), dtype=np.float32)
        mr.pixels.foreach_get(pixels)
        pixels = pixels.reshape(-1, 4)
        smooth = np.ones_like(pixels)
        smooth[:, :3] = pixels[:, 2, None]
        smooth[:, 3] = np.clip(1 - pixels[:, 1], 0, 1)
        image = bpy.data.images.new(kind.upper() + "_MetalSmooth", mr.size[0], mr.size[1], alpha=True)
        image.colorspace_settings.name = "Non-Color"
        image.pixels.foreach_set(smooth.ravel())
        image.filepath_raw = str(output / f"{kind.upper()}_MetalSmooth_2k.png")
        image.file_format = "PNG"
        image.save()
    else:
        image = bpy.data.images.new(kind.upper() + "_MetalSmooth", 4, 4, alpha=True)
        image.pixels = [0, 0, 0, .45] * 16
        image.filepath_raw = str(output / f"{kind.upper()}_MetalSmooth_2k.png")
        image.file_format = "PNG"
        image.save()

    layout = rig_layout(kind)
    arm_data = bpy.data.armatures.new(kind.upper() + "Skeleton")
    arm = bpy.data.objects.new(kind.upper() + "Rig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in layout.items():
        bone = arm_data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh.select_set(True)
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except RuntimeError as error:
        print("AUTOWEIGHT_FALLBACK", kind, error, flush=True)
        mesh.parent = arm
        mesh.modifiers.new("Skin", "ARMATURE").object = arm
    if not any(group.name == "Chest" for group in mesh.vertex_groups):
        mesh.vertex_groups.new(name="Chest")
    chest = mesh.vertex_groups["Chest"]
    for vertex in mesh.data.vertices:
        if not vertex.groups:
            chest.add([vertex.index], 1.0, "REPLACE")
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    for bone in arm.pose.bones:
        bone.rotation_mode = "QUATERNION"
    arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions.new(kind.upper() + "Combat")

    def rotate(name, degrees, axis=(1, 0, 0)):
        if name not in arm.pose.bones:
            return
        bone = arm.pose.bones[name]
        local_axis = arm.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(axis)
        bone.rotation_quaternion @= Quaternion(local_axis, math.radians(degrees))

    def authored(amount, second=False):
        if kind == "b01":
            rotate("Chest", -11 * amount if not second else -6 * amount)
            rotate("UpperArm.R", -67 * amount if not second else -18 * amount)
            rotate("Forearm.R", 32 * amount)
            rotate("Head", 8 * amount)
        elif kind == "b02":
            rotate("Chest", -9 * amount)
            rotate("BackFrame", 10 * amount if second else -8 * amount)
            rotate("UpperArm.R", -49 * amount)
            rotate("UpperArm.L", -37 * amount if second else 12 * amount)
            rotate("Forearm.R", -22 * amount)
        elif kind == "b03":
            rotate("Chest", -12 * amount if second else -4 * amount)
            rotate("UpperArm.L", -68 * amount if second else -35 * amount)
            rotate("UpperArm.R", -46 * amount if second else -18 * amount)
            rotate("Coat.L", 8 * amount, (0, 1, 0))
        elif kind == "b05":
            rotate("UpperArm.R", -40 * amount)
            rotate("UpperArm.L", -40 * amount if second else -18 * amount)
            rotate("Forearm.L", 29 * amount)
            rotate("Coat.R", 7 * amount, (0, 1, 0))
        elif kind == "b07":
            rotate("Head", -8 * amount)
            rotate("Chest", -6 * amount)
            rotate("UpperArm.L", 15 * amount if second else -4 * amount, (0, 1, 0))
            rotate("UpperArm.R", -15 * amount if second else 4 * amount, (0, 1, 0))
            arm.pose.bones["Throat"].scale = (1 + .18 * amount, ) * 3
        elif kind == "b08":
            rotate("Chest", 13 * amount if second else -4 * amount, (0, 0, 1))
            rotate("UpperArm.R", -58 * amount if second else -12 * amount)
            rotate("Forearm.R", -25 * amount)
            rotate("Head", 11 * amount, (0, 0, 1))
        elif kind == "b09":
            rotate("Chest", 7 * amount if second else -9 * amount)
            rotate("Head", -12 * amount)
            rotate("Armor.L", -17 * amount if second else 4 * amount, (0, 1, 0))
            rotate("Armor.R", 10 * amount if second else -4 * amount, (0, 1, 0))
        else:
            rotate("Chest", -8 * amount)
            rotate("UpperArm.R", -34 * amount)
            rotate("UpperArm.L", -57 * amount if second else -16 * amount)
            rotate("Coat.L", -8 * amount, (0, 1, 0))

    for frame in range(1, 360):
        for bone in arm.pose.bones:
            bone.rotation_quaternion = Quaternion()
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
        clip = next(name for name, (first, last) in CLIPS.items() if first <= frame <= last)
        first, last = CLIPS[clip]
        progress = (frame - first) / (last - first)
        if clip == "Idle":
            wave = math.sin(progress * math.pi * 2)
            rotate("Chest", 1.4 * wave)
            rotate("Head", 2 * math.sin(progress * math.pi * 4), (0, 0, 1))
            if kind == "b07":
                arm.pose.bones["Throat"].scale = (1 + .04 * wave,) * 3
            elif kind == "b09":
                rotate("Armor.L", 2 * wave, (0, 1, 0))
            else:
                rotate("UpperArm.L", 1.8 * wave)
                rotate("UpperArm.R", -1.4 * wave)
        elif clip.startswith("Charge"):
            authored(progress * progress * (3 - 2 * progress), clip == "Charge2")
        elif clip.startswith("Cast"):
            second = clip == "Cast2"
            release = max(0, min(1, (progress - .16) / .44))
            authored(1 - release * release * (3 - 2 * release), second)
            strike = math.sin(math.pi * max(0, min(1, (progress - .24) / .56))) ** 2
            rotate("Chest", (14 if kind not in ("b07", "b09") else 9) * strike)
            if kind in ("b07", "b09"):
                rotate("Head", 13 * strike)
            else:
                rotate("UpperArm.R", 52 * strike)
                if second:
                    rotate("UpperArm.L", 37 * strike)
        elif clip == "Hit":
            rotate("Chest", -8 * math.sin(math.pi * progress))
        elif clip == "Death":
            authored(.2 * progress)
            rotate("Chest", 25 * progress)
            rotate("Head", 20 * progress)
        elif clip == "Retreat":
            rotate("Head", 5 * math.sin(math.pi * progress), (0, 0, 1))
        for bone in arm.pose.bones:
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
            bone.keyframe_insert("location", frame=frame, group=bone.name)
            bone.keyframe_insert("scale", frame=frame, group=bone.name)

    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 359
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / (kind.upper() + "_Combat.blend")))
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(filepath=str(output / (kind.upper() + "_Combat.fbx")),
                             use_selection=True, object_types={"ARMATURE", "MESH"},
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False,
                             bake_anim=True, bake_anim_use_all_actions=False,
                             bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0,
                             path_mode="RELATIVE")
    manifest = {"id": kind, "source": str(source), "original_triangles": tris_before,
                "mobile_triangles": len(mesh.data.polygons), "bones": len(layout),
                "clips": CLIPS, "source_bytes": source.stat().st_size}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print("BOUNTY_COMBAT_EXPORTED", kind, manifest, flush=True)


if __name__ == "__main__":
    requested = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for case_id in requested or SOURCES:
        main(case_id)
