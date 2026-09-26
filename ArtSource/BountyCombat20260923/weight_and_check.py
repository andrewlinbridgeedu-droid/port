"""Replace failed bone-heat weights with deterministic regional skin weights.

The high-poly GLBs contain many disconnected ornaments. Blender's bone-heat
solver silently leaves most vertices unweighted; this pass assigns every
mobile vertex to its intended body region before the FBX is imported.
"""
import bpy
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent


def point_segment_distance(vertices, start, end):
    start, end = np.asarray(start), np.asarray(end)
    direction = end - start
    progress = np.clip(((vertices - start) @ direction) / np.dot(direction, direction), 0, 1)
    return np.linalg.norm(vertices - (start + progress[:, None] * direction), axis=1)


def process(case_id):
    folder = ROOT / case_id
    bpy.ops.wm.open_mainfile(filepath=str(folder / (case_id.upper() + "_Combat.blend")))
    mesh = next(obj for obj in bpy.data.objects if obj.type == "MESH")
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    bones = arm.data.bones
    vertices = np.array([v.co[:] for v in mesh.data.vertices], dtype=np.float32)
    x, y, z = vertices[:, 0], vertices[:, 1], vertices[:, 2]
    group_indices = defaultdict(lambda: defaultdict(list))
    for group in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(group)
    for name in bones:
        mesh.vertex_groups.new(name=name.name)

    is_beast = case_id == "b09"
    is_frog = case_id == "b07"
    groups = defaultdict(list)
    for index in range(len(vertices)):
        side = "L" if x[index] >= 0 else "R"
        ax = abs(x[index])
        if is_beast or is_frog:
            if is_beast and z[index] > 1.20 and ax > .32 and y[index] > -.2:
                candidates = ["Armor." + side, "Chest"]
            elif is_frog and .83 < z[index] < 1.40 and y[index] < -.29 and ax < .43:
                candidates = ["Throat", "Chest", "Head"]
            elif z[index] > 1.12 and y[index] < -.13 and ax < .47:
                candidates = ["Head", "Chest"]
            elif ax > .36 and y[index] < -.08 and z[index] < 1.15:
                candidates = ["UpperArm." + side, "Forearm." + side, "Hand." + side, "Chest"]
            elif ax > .36 and y[index] >= -.08 and z[index] < .93:
                candidates = ["Thigh." + side, "Shin." + side, "Foot." + side, "Pelvis"]
            else:
                candidates = ["Pelvis", "Chest", "Head"]
        else:
            if z[index] > 1.52 and ax < .43:
                candidates = ["Head", "Chest"]
            elif ax > .30 and z[index] > 1.04:
                candidates = ["UpperArm." + side, "Forearm." + side, "Hand." + side, "Chest"]
            elif case_id == "b01" and ax > .45 and y[index] < -.10 and z[index] < 1.12:
                candidates = ["Hand." + side, "Forearm." + side]
            elif z[index] < .85 and ax < .31:
                candidates = ["Pelvis", "Thigh." + side, "Shin." + side, "Foot." + side]
            elif z[index] < 1.06 and ax >= .31 and "Coat." + side in bones:
                candidates = ["Coat." + side, "Pelvis"]
            elif z[index] > 1.06 and case_id == "b02" and y[index] > .19:
                candidates = ["BackFrame", "Chest"]
            else:
                candidates = ["Pelvis", "Chest", "Head"]
        groups[tuple(name for name in candidates if name in bones)].append(index)

    weights = np.zeros((len(vertices), len(bones)), dtype=np.float32)
    names = list(bones.keys())
    bone_column = {name: index for index, name in enumerate(names)}
    for candidates, indices in groups.items():
        subset = vertices[indices]
        distances = np.stack([point_segment_distance(subset, bones[name].head_local,
                                                      bones[name].tail_local) for name in candidates], axis=1)
        nearest = np.argsort(distances, axis=1)[:, :2]
        chosen_distance = np.take_along_axis(distances, nearest, axis=1)
        strength = 1 / np.maximum(chosen_distance + .09, .02) ** 4
        strength /= strength.sum(axis=1, keepdims=True)
        for row, vertex_id in enumerate(indices):
            for slot in range(nearest.shape[1]):
                name = candidates[int(nearest[row, slot])]
                weights[vertex_id, bone_column[name]] = strength[row, slot]

    rigid_weapon_vertices = 0
    if case_id == "b01":
        # Meshy merged the sword and body into one mesh. Distance-based skinning
        # split the blade between Hand.R, Forearm.R, Pelvis and Chest, so the
        # blade opened into separate fins even in the idle pose. All sword
        # islands must follow the grip as a rigid object.
        raw = ((x < -.32) & (y < -.14) & (z < 1.15))
        parent = list(range(len(vertices)))

        def find(vertex_id):
            while parent[vertex_id] != vertex_id:
                parent[vertex_id] = parent[parent[vertex_id]]
                vertex_id = parent[vertex_id]
            return vertex_id

        for edge in mesh.data.edges:
            first, last = edge.vertices
            first, last = find(first), find(last)
            if first != last:
                parent[last] = first
        components = defaultdict(list)
        for vertex_id in range(len(vertices)):
            components[find(vertex_id)].append(vertex_id)
        weapon = np.zeros(len(vertices), dtype=bool)
        for indices in components.values():
            subset = vertices[indices]
            selected = int(raw[indices].sum())
            if not selected:
                continue
            center = subset.mean(axis=0)
            if selected / len(indices) >= .60 or (
                center[0] < -.38 and center[1] < -.13 and center[2] < 1.14
            ):
                weapon[indices] = True
        rigid_weapon_vertices = int(weapon.sum())
        if rigid_weapon_vertices < 1600 or rigid_weapon_vertices > 2600:
            raise RuntimeError(f"Unexpected B01 sword mask: {rigid_weapon_vertices}")
        weights[weapon, :] = 0
        weights[weapon, bone_column["Hand.R"]] = 1

    # Quantize to 2% for a small number of Blender vertex-group API calls.
    for column, name in enumerate(names):
        active = np.flatnonzero(weights[:, column] > .005)
        if not len(active):
            continue
        quantized = np.clip(np.rint(weights[active, column] * 50).astype(int), 1, 50)
        group = mesh.vertex_groups[name]
        for level in np.unique(quantized):
            members = active[quantized == level].tolist()
            group.add(members, level / 50, "REPLACE")

    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    coverage = sum(bool(vertex.groups) for vertex in mesh.data.vertices)
    if coverage != len(mesh.data.vertices):
        raise RuntimeError(f"Unweighted vertices {case_id}: {len(mesh.data.vertices)-coverage}")
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(folder / (case_id.upper() + "_Combat.blend")))
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(filepath=str(folder / (case_id.upper() + "_Combat.fbx")),
                             use_selection=True, object_types={"ARMATURE", "MESH"},
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False,
                             bake_anim=True, bake_anim_use_all_actions=False,
                             bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0,
                             path_mode="RELATIVE")
    counts = {name: int(np.count_nonzero(weights[:, column] > .005))
              for column, name in enumerate(names)}
    report = {"case": case_id, "vertices": len(vertices), "weighted": coverage,
              "influences": counts, "rigid_weapon_vertices": rigid_weapon_vertices}
    (folder / "weights.json").write_text(json.dumps(report, indent=2))
    print("BOUNTY_WEIGHTS_OK", case_id, report, flush=True)


if __name__ == "__main__":
    requested = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for case in requested:
        process(case)
