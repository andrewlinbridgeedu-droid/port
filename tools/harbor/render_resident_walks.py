"""Animate each existing resident model with the matching courier walk rig.

The ten original GLTF residents and textures remain unchanged.  Their shared
26-bone rig accepts the courier walk action; Blender saves editable copies and
renders eight transparent profile frames for the harbor map.
"""

import bpy
import sys
from pathlib import Path
from mathutils import Vector


stem = sys.argv[sys.argv.index("--") + 1]
root = Path(__file__).resolve().parents[2]
models = root / "mistport-ios/Mistport/WisteriaMap/characters"
source = root / "ArtSource/HarborCityRoutes20260925/resident-walks"
renders = root / "output/harbor-user-roads-20260925/render"
source.mkdir(parents=True, exist_ok=True)
renders.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(models / "courier-walking.gltf"))
walk_rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
walk_action = walk_rig.animation_data.action
walk_action.use_fake_user = True
walking_bones = set(walk_rig.pose.bones.keys())
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(models / f"{stem}-idle.gltf"))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == "ARMATURE")
assert set(rig.pose.bones.keys()) == walking_bones, stem
rig.animation_data_create()
rig.animation_data.action = walk_action
meshes = [o for o in scene.objects if o.type == "MESH"]
assert meshes
start, end = walk_action.frame_range

scene.frame_set(round(start))
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(source / f"{stem}-walk.blend"))
bpy.ops.export_scene.gltf(filepath=str(source / f"{stem}-walk.glb"),
                          export_format="GLB", export_animations=True)

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.world.color = (0.85, 0.88, 1)

camera_data = bpy.data.cameras.new("resident profile")
camera = bpy.data.objects.new("resident profile", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
light_data = bpy.data.lights.new("soft key", "AREA")
light = bpy.data.objects.new("soft key", light_data)
scene.collection.objects.link(light)
light_data.energy = 800
light_data.shape = "DISK"
light_data.size = 5

for index in range(8):
    scene.frame_set(round(start + (end - start) * index / 8))
    bpy.context.view_layer.update()
    points = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    low = Vector(tuple(min(p[axis] for p in points) for axis in range(3)))
    high = Vector(tuple(max(p[axis] for p in points) for axis in range(3)))
    center = (low + high) / 2
    size = high - low
    radius = max(size.length, 2)
    camera.location = center + Vector((radius * 3, -radius * 0.30, radius * 0.55))
    target = center + Vector((0, 0, size.z * 0.12))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = max(size.z * 0.76, size.x * 1.30, size.y * 1.30)
    light.location = center + Vector((3, -4, 6))
    scene.render.filepath = str(renders / f"{stem}-{index:02d}.png")
    bpy.ops.render.render(write_still=True)

print(f"Resident {stem}: 26-bone walk model and eight rendered frames")
