"""Render actual Blender geometry for review; no concept compositing."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
DOC=ROOT/'docs/development/hero-refinement-20261001/meshy-study'
bpy.ops.wm.open_mainfile(filepath=str(DOC/'HeroMeshy-study-v1.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48
scene.render.resolution_x=900;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new('Review studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.09,.11,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.01));ground=bpy.context.object
mat=bpy.data.materials.new('Review studio grey');mat.diffuse_color=(.15,.16,.18,1);ground.data.materials.append(mat)
def area(name,loc,energy,color,size):
 d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=size
 o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.95))-o.location).to_track_quat('-Z','Y').to_euler()
area('Warm broad key',(-2.2,3,3.2),200,(1,.87,.76),2.5)
area('Cool rim',(2,-1,2.3),220,(.71,.81,1),1.8)
area('Soft cloth fill',(1,3,1.5),85,(.86,.9,1),2)
d=bpy.data.cameras.new('Actual Blender review');cam=bpy.data.objects.new(d.name,d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO'
for name,yaw,z,scale in [('rear',0,.88,2.06),('rear-three-quarter',.55,.88,2.06),('hair-and-tailoring',.22,1.35,.90),('cloth-and-jewels',.15,.69,1.20)]:
 target=Vector((0,.04,z));cam.location=target+Vector((math.sin(yaw)*4,math.cos(yaw)*4,.12));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();d.ortho_scale=scale
 scene.render.filepath=str(DOC/(name+'.png'));bpy.ops.render.render(write_still=True)
print('MESHY_STUDY_RENDERED 4 actual Blender views')
