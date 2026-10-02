"""Read-only GLB inspection and three actual Blender studio renders.

Blender -b --python tools/animation/inspect_meshy_hero.py -- <input.glb> <output>
This does not change or save the imported source model.
"""
import bpy, sys, json, math, hashlib
from pathlib import Path
from mathutils import Vector
src=Path(sys.argv[sys.argv.index('--')+1]); out=Path(sys.argv[sys.argv.index('--')+2]); out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector(tuple(min(p[i] for p in corners) for i in range(3))); hi=Vector(tuple(max(p[i] for p in corners) for i in range(3)))
center=(lo+hi)*.5; height=hi.z-lo.z
info={'source':str(src),'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'bounds_min':list(lo),'bounds_max':list(hi),'meshes':[{'name':o.name,'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'uv_layers':[u.name for u in o.data.uv_layers],'vertex_groups':len(o.vertex_groups),'modifiers':[m.type for m in o.modifiers]} for o in meshes], 'images':[{'name':i.name,'size':list(i.size)} for i in bpy.data.images], 'armatures':len([o for o in bpy.context.scene.objects if o.type=='ARMATURE']), 'animations':len(bpy.data.actions)}
(out/'inspection.json').write_text(json.dumps(info,indent=2))
scene=bpy.context.scene; scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=900;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new('Neutral inspection world');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.09,.1,.12,1);world.node_tree.nodes['Background'].inputs[1].default_value=.5;scene.world=world
bpy.ops.mesh.primitive_plane_add(size=height*200,location=(center.x,center.y,lo.z-.005*height));ground=bpy.context.object
mat=bpy.data.materials.new('Inspection ground');mat.diffuse_color=(.12,.14,.17,1);ground.data.materials.append(mat)
def area(name,offset,energy,color,size):
 d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=size*height
 o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=center+Vector(offset)*height;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
area('Soft key',(-1.5,-2,2),250*height**2,(1,.89,.78),2)
area('Cool rim',(1.4,1.1,1.5),200*height**2,(.65,.8,1),1.6)
area('Rear fill',(-1,2,.5),120*height**2,(.86,.9,1),2)
d=bpy.data.cameras.new('Inspection camera');cam=bpy.data.objects.new('Inspection camera',d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO';d.ortho_scale=height*1.22
for name,yaw in [('front',math.pi),('rear',0),('rear-three-quarter',.6)]:
 cam.location=center+Vector((math.sin(yaw)*3,math.cos(yaw)*3,.06))*height;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
print('MESHY_INSPECTION_DONE '+json.dumps(info))
