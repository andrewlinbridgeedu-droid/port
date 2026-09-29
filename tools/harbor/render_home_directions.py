"""Render existing walking models from eight street directions; preserve originals.

Run in Blender: --background --python tools/harbor/render_home_directions.py
-- ATLAS_NAME OUTPUT_DIRECTORY. The matching 8x8 atlas is packaged separately.
Rows: away, away-right, right, toward-right, toward, toward-left, left, away-left.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
name, destination = sys.argv[sys.argv.index("--") + 1:][:2]
destination = Path(destination) / name
destination.mkdir(parents=True, exist_ok=True)
resident = {
    "HarborResidentCafeKeeperWalkAtlas": "cafe_keeper",
    "HarborResidentStreetWardenWalkAtlas": "street_warden",
    "HarborResidentFloristWalkAtlas": "florist",
    "HarborResidentMusicianWalkAtlas": "musician",
    "HarborResidentBakerWalkAtlas": "baker",
    "HarborResidentScholarWalkAtlas": "scholar",
    "HarborResidentDockworkerWalkAtlas": "dockworker",
    "HarborResidentMerchantWalkAtlas": "merchant",
    "HarborResidentClockmakerWalkAtlas": "clockmaker",
    "HarborResidentVisitorWalkAtlas": "visitor",
}
extra = {
    "HarborLamplighterWalkAtlas": "harbor_lamplighter",
    "HarborFlowerSellerWalkAtlas": "harbor_flower_seller",
    "HarborSailorWalkAtlas": "harbor_sailor",
    "HarborArchiveApprenticeWalkAtlas": "harbor_archive_apprentice",
}
if name in resident:
    source = root / "ArtSource/HarborCityRoutes20260925/resident-walks" / (resident[name] + "-walk.glb")
elif name in extra:
    source = root / "ArtSource/HarborCitizens20260925" / (extra[name] + ".glb")
else:
    source = root / "mistport-ios/Mistport/WisteriaMap/characters" / ({
        "HarborPostmanWalkAtlas": "postman-user-walking.gltf",
        "HarborCourierWalkAtlas": "courier-walking.gltf",
    }[name])

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == "MESH"]
rig = next(o for o in scene.objects if o.type == "ARMATURE")
action = rig.animation_data.action
start, end = action.frame_range
frames = [round(start + (end - start) * i / 8) for i in range(8)]
points = []
for frame in frames:
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    points.extend(o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box)
low = Vector(tuple(min(p[a] for p in points) for a in range(3)))
high = Vector(tuple(max(p[a] for p in points) for a in range(3)))
center = (low + high) / 2
size = high - low
print("DIRECTION BOUNDS", name, tuple(low), tuple(high), tuple(size), flush=True)

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.world.color = (0.85, 0.88, 1)
scene.render.image_settings.compression = 50
camera_data = bpy.data.cameras.new("home street direction")
camera = bpy.data.objects.new("home street direction", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
camera_data.ortho_scale = max(size.z * 1.25, size.x * 1.8, size.y * 1.8)
light_data = bpy.data.lights.new("soft daylight", "AREA")
light = bpy.data.objects.new("soft daylight", light_data)
scene.collection.objects.link(light)
light_data.energy = 800
light_data.shape = "DISK"
light_data.size = 5
distance = max(size.length, 2) * 3
for direction in range(8):
    # Imported characters face -Y. Looking from +Y shows their back (away).
    angle = direction * math.pi / 4
    camera.location = center + Vector((-math.sin(angle) * distance, math.cos(angle) * distance, distance * 0.30))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    light.location = center + Vector((-3, -4, 6))
    for index, frame in enumerate(frames):
        output = destination / f"{direction}-{index}.png"
        if output.exists():
            continue
        scene.frame_set(frame)
        scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)
    print("DIRECTION COMPLETE", name, direction, flush=True)
