import bpy, pathlib, json
from mathutils import Vector
root=pathlib.Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'base_basic_pbr.glb'))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.join();o=bpy.context.object
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
lo=Vector(tuple(min(v.co[i] for v in o.data.vertices) for i in range(3)));hi=Vector(tuple(max(v.co[i] for v in o.data.vertices) for i in range(3)));center=(lo+hi)/2;scale=2.2/max(hi-lo)
for v in o.data.vertices:v.co=(v.co-center)*scale
o.location=(0,0,0)
# Orient tapered end upward by comparing cross-section spread near extremes.
zs=[v.co.z for v in o.data.vertices]; low=min(zs); high=max(zs); span=high-low
a=[v.co for v in o.data.vertices if v.co.z<low+span*.15]; b=[v.co for v in o.data.vertices if v.co.z>high-span*.15]
if a and b and max(v.x*v.x+v.y*v.y for v in a)<max(v.x*v.x+v.y*v.y for v in b):
 for v in o.data.vertices:v.co.y=-v.co.y;v.co.z=-v.co.z
initial=sum(len(p.vertices)-2 for p in o.data.polygons)
mod=o.modifiers.new('Mobile detail preservation','DECIMATE');mod.ratio=min(1,5000/initial);bpy.ops.object.modifier_apply(modifier=mod.name)
for p in o.data.polygons:p.use_smooth=True
o.name='SaltSpike'
for image in bpy.data.images:
 if image.type=='IMAGE' and image.size[0]>0:
  image.filepath_raw=str(root/(image.name.replace('/','_')+'.png'));image.file_format='PNG';image.save()
bpy.ops.wm.save_as_mainfile(filepath=str(root/'SaltSpike.blend'))
bpy.ops.export_scene.fbx(filepath=str(root/'SaltSpike.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',path_mode='COPY',embed_textures=True)
(root/'manifest.json').write_text(json.dumps({'original_triangles':initial,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'dimensions':list(o.dimensions),'source':'https://hyper3d.ai/workspace/rodin/6ab5a1ba-2539-4b92-9958-7fb530810ae3'},indent=2))
