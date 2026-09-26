"""Reimport the downloaded Rodin GLB and render four verification views."""

import hashlib
import json
import math
import os
import sys

import bpy
from mathutils import Vector


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    source, out_dir = map(os.path.abspath, argv[:2])
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=source)
    imported = list(bpy.context.scene.objects)
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("GLB contains no mesh")

    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (low + high) / 2
    height = max((high - low).z, 0.01)
    width = max((high - low).x, (high - low).y, 0.01)

    mesh_stats = []
    for obj in meshes:
        obj.data.calc_loop_triangles()
        mesh_stats.append(
            {
                "name": obj.name,
                "vertices": len(obj.data.vertices),
                "polygons": len(obj.data.polygons),
                "triangles": len(obj.data.loop_triangles),
                "uv_layers": len(obj.data.uv_layers),
                "materials": [mat.name if mat else None for mat in obj.data.materials],
            }
        )
    packed_images = []
    for img in bpy.data.images:
        if img.source == "FILE":
            packed_images.append(
                {
                    "name": img.name,
                    "width": img.size[0],
                    "height": img.size[1],
                    "packed": bool(img.packed_file),
                }
            )
    with open(source, "rb") as f:
        digest = hashlib.file_digest(f, "sha256").hexdigest()
    stats = {
        "source": source,
        "bytes": os.path.getsize(source),
        "sha256": digest,
        "meshes": mesh_stats,
        "total_triangles": sum(m["triangles"] for m in mesh_stats),
        "armatures": [obj.name for obj in imported if obj.type == "ARMATURE"],
        "animations": list(bpy.data.actions.keys()),
        "images": packed_images,
        "bounds": {"min": list(low), "max": list(high)},
    }
    with open(os.path.join(out_dir, "inspection.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 600
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("Rodin inspection backdrop")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.18, 0.2, 0.23, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    scene.world = world

    def area_light(name, loc, power, size):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = center + Vector(loc) * height
        obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()

    area_light("softbox-left", (-1.2, -1.0, 1.4), 700, height * 1.2)
    area_light("softbox-right", (1.3, 0.8, 0.5), 550, height * 1.0)
    cam_data = bpy.data.cameras.new("inspection camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(height * 1.15, width * 1.65)
    cam = bpy.data.objects.new("inspection camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    distance = height * 2.4
    for name, azimuth in [
        ("front", 0),
        ("three-quarter", 45),
        ("side", 90),
        ("back", 180),
    ]:
        a = math.radians(azimuth)
        cam.location = center + Vector((math.sin(a) * distance, -math.cos(a) * distance, height * 0.1))
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
    print("RODIN_INSPECTION", json.dumps(stats, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
