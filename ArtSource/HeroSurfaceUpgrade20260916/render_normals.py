import bpy
from pathlib import Path
from mathutils import Vector
R=Path('/Users/andrewlin/Downloads/DEV_Projects/mindstone-game');O=R/'output/character-art-upgrade-20260916/hero-normals';O.mkdir(exist_ok=True)
sources={'before':R/'UnityBattleSource/Assets/Models/Fool/Meshy_AI_battle_magician_rig_biped_Animation_Combat_Stance_frame_rate_60.fbx','after':R/'ArtSource/EarlyCharacterNormalRefinement20260916/hero-NormalsRefined.fbx'}
for stage,src in sources.items():
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(src));s=bpy.context.scene;s.frame_set(1)
 m=next(o for o in s.objects if o.type=='MESH');arm=m.find_armature();arm.data.pose_position='REST';bpy.context.view_layer.update()
 vs=[m.matrix_world@v.co for v in m.data.vertices];lo=Vector([min(v[i] for v in vs) for i in range(3)]);hi=Vector([max(v[i] for v in vs) for i in range(3)]);size=max(hi-lo);center=(lo+hi)/2
 up=max(range(3),key=lambda i:hi[i]-lo[i]);print('BOUNDS',stage,list(lo),list(hi),'UP',up)
 direction=Vector((.25,-1,.1)) if up==2 else Vector((.25,.1,1));bpy.ops.object.camera_add(location=center+direction*size*2.8);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.1;cam.data.clip_start=size*.001;cam.data.clip_end=size*20;s.camera=cam
 for off,power in [((2,-3,3),800),((-2,-1,1),300)]:
  bpy.ops.object.light_add(type='AREA',location=center+Vector(off)*size);l=bpy.context.object;l.data.energy=power*size*size;l.data.size=size*2;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler()
 mat=bpy.data.materials.new('ClayAudit');mat.use_nodes=True;bs=mat.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.27,.28,.32,1);bs.inputs['Roughness'].default_value=.65;m.data.materials.clear();m.data.materials.append(mat)
 s.world=bpy.data.worlds.new('Studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
 s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=800;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.filepath=str(O/(stage+'.png'));bpy.ops.render.render(write_still=True)
