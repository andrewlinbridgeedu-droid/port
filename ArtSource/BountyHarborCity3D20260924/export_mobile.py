"""Combine the detailed scene by material for a low-draw-call GLB preview.

Keeps the editable, unjoined BountyHarborCity.blend untouched.
"""
import bpy
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent
meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH']
for obj in bpy.data.objects:
    obj.select_set(obj in meshes)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.convert(target='MESH')

groups = defaultdict(list)
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        key = '|'.join(mat.name for mat in obj.data.materials) or 'unpainted'
        groups[key].append(obj)

for key, objects in groups.items():
    if len(objects) == 1:
        objects[0].name = 'DISTRICT_' + key
        continue
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = 'DISTRICT_' + key

bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.objects:
    if obj.type == 'MESH' or obj.name.startswith('DOOR_'):
        obj.select_set(True)
print('MOBILE_MESH_COUNT', len([obj for obj in bpy.data.objects if obj.type == 'MESH']))
bpy.ops.export_scene.gltf(
    filepath=str(ROOT / 'BountyHarborCity-mobile.glb'),
    export_format='GLB',
    export_apply=True,
    export_yup=True,
)
