import bpy,numpy as np,pathlib,json
from mathutils import Vector
r=pathlib.Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(r/'SaltSpike.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
a=np.array([list(v.co) for v in o.data.vertices]);a-=a.mean(axis=0)
w,axes=np.linalg.eigh(a.T@a);z=axes[:,-1];q=Vector(z).rotation_difference(Vector((0,0,1)))
for v,p in zip(o.data.vertices,a):v.co=q@Vector(p)
zv=[v.co.z for v in o.data.vertices];lo=min(zv);hi=max(zv);span=hi-lo
ends=[[v.co for v in o.data.vertices if (v.co.z<lo+span*.18 if k==0 else v.co.z>hi-span*.18)] for k in range(2)]
if np.mean([v.x*v.x+v.y*v.y for v in ends[0]])<np.mean([v.x*v.x+v.y*v.y for v in ends[1]]):
 for v in o.data.vertices:v.co.y=-v.co.y;v.co.z=-v.co.z
for v in o.data.vertices:v.co*=2.2/span
bpy.context.view_layer.objects.active=o;o.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(r/'SaltSpike.blend'))
bpy.ops.export_scene.fbx(filepath=str(r/'SaltSpike.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',path_mode='COPY',embed_textures=True)
# Independent turntable still for checking mesh/material, not combat acceptance.
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new("PreviewWorld");scene.world.color=(.12,.12,.12)
bpy.ops.object.camera_add(location=(3,-5,2.5));cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3;scene.camera=cam
for pos,power,size in [((2,-3,4),650,4),((-3,-1,2),450,3),((0,3,3),750,3)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(-l.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(r/'preview.png');bpy.ops.render.render(write_still=True)
