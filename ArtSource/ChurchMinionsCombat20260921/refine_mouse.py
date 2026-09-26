import bpy,math
from mathutils import Vector
from pathlib import Path
R=Path(__file__).resolve().parent;r=R/'Moonfang';bpy.ops.wm.open_mainfile(filepath=str(r/'Moonfang_Combat.blend'));sc=bpy.context.scene;arm=next(o for o in sc.objects if o.type=='ARMATURE');m=next(o for o in sc.objects if o.type=='MESH');count=0
for v in m.data.vertices:
 if v.co.y<-.55:continue
 modified=False
 for n in ['Ear.L','Ear.R']:
  g=m.vertex_groups[n]
  try:w=g.weight(v.index)
  except RuntimeError:continue
  if w>.0001:g.remove([v.index]);modified=True
 if modified:
  weights=[(g.group,g.weight) for g in v.groups if g.weight>.00001];total=sum(w for _,w in weights)
  if total>.001:
   for i,w in weights:m.vertex_groups[i].add([v.index],w/total,'REPLACE')
  else:m.vertex_groups['Chest' if v.co.y<.25 else 'Pelvis'].add([v.index],1,'REPLACE')
  count+=1
sc.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(r/'Moonfang_Combat.blend'));bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);m.select_set(True);bpy.context.view_layer.objects.active=arm
bpy.ops.export_scene.fbx(filepath=str(r/'Moonfang_Combat.fbx'),use_selection=True,object_types={'ARMATURE','MESH'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,path_mode='RELATIVE');print('FINAL_MOUSE_EXPORTED',count,flush=True)
out=R.parents[1]/'output/church-minions-combat-20260921/Moonfang'
for label,f in [('charge',166),('cast2',305)]:sc.frame_set(f);sc.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.mesh.primitive_plane_add(size=20,location=(0,0,-.01));p=bpy.context.object;mat=bpy.data.materials.new('Ground');mat.diffuse_color=(.045,.055,.07,1);p.data.materials.append(mat)
cam=sc.camera;center=Vector((0,0,1));cam.location=center+Vector((5,-.05,.05));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=4.5;sc.render.resolution_x=960;sc.render.resolution_y=540
sc.frame_set(1);sc.render.filepath=str(out/'side-ground.png');bpy.ops.render.render(write_still=True)
