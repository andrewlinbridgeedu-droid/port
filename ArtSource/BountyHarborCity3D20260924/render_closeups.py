"""Render actual Blender geometry from walkable map viewpoints."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'


def camera(name, position, target, scale):
    cam = bpy.data.cameras.new(name)
    obj = bpy.data.objects.new(name, cam)
    bpy.context.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    cam.type = 'ORTHO'
    cam.ortho_scale = scale
    return obj


for name, pos, target, scale, filename in [
    ('02 clock square', (29, -48, 43), (4, -13, 4), 49, 'render-clock-square.png'),
    ('03 west evidence street', (-17, -43, 34), (-30, -12, 3), 45, 'render-west-street.png'),
]:
    scene.camera = camera(name, pos, target, scale)
    scene.render.filepath = str(ROOT / filename)
    bpy.ops.render.render(write_still=True)

scene.camera = bpy.data.objects['01 whole harbor']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'BountyHarborCity.blend'))
