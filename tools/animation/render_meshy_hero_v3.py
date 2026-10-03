"""Re-render the saved skinned model without re-authoring or changing its source."""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
DOC=ROOT/'docs/development/hero-refinement-20261001/v3'
bpy.ops.wm.open_mainfile(filepath=str(DOC/'HeroMeshy-v3.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48
scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=960;scene.render.resolution_y=1280;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.11,.14,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02));ground=bpy.context.object
m=bpy.data.materials.new('Studio ground');m.diffuse_color=(.15,.17,.20,1);m.use_nodes=True
m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.15,.17,.20,1)
m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8;ground.data.materials.append(m)
def light(name,p,energy,color,size):
 d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=size
 o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=p;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
light('Warm key',(-2,3,3),170,(1,.88,.75),2)
light('Cool edge',(2,-1,2.5),260,(.63,.78,1),1.5)
light('Soft rear fill',(1,3,1.5),210,(.84,.90,1),2)
d=bpy.data.cameras.new('Actual model review');cam=bpy.data.objects.new(d.name,d);scene.collection.objects.link(cam);scene.camera=cam
d.type='ORTHO';d.ortho_scale=2.04
for key in ['night','starlight','carnival']:
 for o in scene.objects:
  if o.name.startswith('Outfit-'):o.hide_render=not o.name.startswith('Outfit-'+key+'-')
 for name,loc in [('rear',(0,4.5,.98)),('quarter',(2.4,4.5,1.12))]:
  cam.location=loc;cam.rotation_euler=(Vector((0,0,.90))-cam.location).to_track_quat('-Z','Y').to_euler()
  scene.render.filepath=str(DOC/f'{key}-blender-{name}.png');bpy.ops.render.render(write_still=True)
  print('ACTUAL_MODEL_RENDER',key,name,flush=True)
