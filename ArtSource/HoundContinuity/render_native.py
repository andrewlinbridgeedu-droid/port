import bpy,math,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2];src=root/'UnityBattleSource/Assets/Models/HellHound/Meshy_AI_Emberwolf_quadruped'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(next(src.glob('*.fbx'))))
meshes=[o for o in bpy.data.objects if o.type=='MESH'];rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
mat=bpy.data.materials.new('Emberwolf');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');im=mat.node_tree.nodes.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(src/'Meshy_AI_Emberwolf_quadruped_texture_0.png'));mat.node_tree.links.new(im.outputs['Color'],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=.45
for o in meshes:o.data.materials.clear();o.data.materials.append(mat)
s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update();pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)));center=(lo+hi)/2;size=max(hi-lo);print('BOUNDS',lo,hi)
s.render.engine='CYCLES';s.cycles.samples=12;s.render.resolution_x=384;s.render.resolution_y=384;s.render.resolution_percentage=100;s.render.film_transparent=True
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.28,.33,1)
bpy.ops.object.camera_add();cam=bpy.context.object;cam.location=center+Vector((.3,-2,.8)).normalized()*size*3;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.clip_start=size*.001;cam.data.clip_end=size*100;cam.data.type='ORTHO';cam.data.ortho_scale=size*1.3;s.camera=cam
for d in [(-1,-2,3),(2,1,2)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(d)*size);bpy.context.object.data.energy=100*size*size;bpy.context.object.data.size=size*3
rotation=rig.rotation_euler.copy();base=rig.scale.copy(); print("RIG",rig.name, list(rig.location),list(base),list(rig.rotation_euler),flush=True)
for clip,n in [('Idle',4),('Attack',6),('Death',6)]:
 for i in range(n):
  s.frame_set(1+i*4);rig.scale=base.copy();rig.rotation_euler=rotation.copy()
  if clip=='Attack':rig.rotation_euler.x=rotation.x+.12*math.sin(i/(n-1)*math.pi*2)
  if clip=='Death':rig.scale.z=base.z*(1-.8*i/(n-1))
  name=f'PursuitHound{clip}{i+1:02d}';folder=root/'mistport-ios/Mistport/Assets.xcassets'/f'{name}.imageset';folder.mkdir(exist_ok=True);s.render.filepath=str(folder/'art.png');bpy.ops.render.render(write_still=True);(folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'art.png','idiom':'universal'}],'info':{'author':'xcode','version':1}}))
