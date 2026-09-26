"""Render existing Wisteria GLTF citizens as small transparent map sprites.

Run with Blender's --background --python, passing a model stem and output folder
after ``--``. The scene is rebuilt for each character to avoid inherited rigs.
"""

import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector


args = sys.argv[sys.argv.index("--") + 1 :]
stem, output_dir = args[0], Path(args[1])
output_dir.mkdir(parents=True, exist_ok=True)
root = Path(__file__).resolve().parents[2] / "mistport-ios/Mistport/WisteriaMap/characters"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root / f"{stem}.gltf"))
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.render.image_settings.compression = 80
scene.world.color = (0.85, 0.88, 1.0)

meshes = [o for o in scene.objects if o.type == "MESH"]
if not meshes:
    raise RuntimeError(f"No mesh in {stem}")

action = next(iter(bpy.data.actions), None)
start, end = action.frame_range if action else (1, 1)
frame_count = 8 if "walking" in stem else 1

camera_data = bpy.data.cameras.new("Map sprite orthographic")
camera = bpy.data.objects.new("Map sprite orthographic", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"

for index in range(frame_count):
    scene.frame_set(round(start + (end - start) * index / frame_count))
    bpy.context.view_layer.update()
    points = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    low = Vector(tuple(min(p[axis] for p in points) for axis in range(3)))
    high = Vector(tuple(max(p[axis] for p in points) for axis in range(3)))
    center = (low + high) / 2
    size = high - low
    if index == 0:
        print(f"Bounds {stem}: low={tuple(low)}, high={tuple(high)}, size={tuple(size)}")
    # A near-profile view makes direction legible when the street route flips.
    camera.location = center + Vector((max(size.length, 2.0) * 3.0,
                                       -max(size.length, 2.0) * 0.30,
                                       max(size.length, 2.0) * 0.55))
    target = center + Vector((0, 0, size.z * 0.12))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = max(size.z * 0.72, size.x * 1.25, size.y * 1.25)

    key_data = bpy.data.lights.new("Key", "AREA")
    key = bpy.data.objects.new("Key", key_data)
    scene.collection.objects.link(key)
    key.location = center + Vector((3, -4, 6))
    key_data.energy = 800
    key_data.shape = "DISK"
    key_data.size = 5
    scene.render.filepath = str(output_dir / f"{stem}-{index:02d}.png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(key, do_unlink=True)
    bpy.data.lights.remove(key_data)

print(f"Rendered {frame_count} sprite frames for {stem}")
