import bpy,math
from pathlib import Path
from mathutils import Vector,Quaternion
R=Path(__file__).resolve().parent
for name in ['VeilOracle','Moonfang']:
 r=R/name;bpy.ops.wm.open_mainfile(filepath=str(r/(name+'_Combat.blend')));sc=bpy.context.scene;arm=next(o for o in sc.objects if o.type=='ARMATURE');m=next(o for o in sc.objects if o.type=='MESH')
 def Q(n,a,axis):return Quaternion(arm.data.bones[n].matrix_local.to_3x3().inverted()@Vector(axis),math.radians(a))
 for f in range(290,320):
  sc.frame_set(f);u=(f-290)/29;t=max(0,min(1,(u-.18)/.32));q=1-t*t*(3-2*t);strike=math.sin(math.pi*max(0,min(1,(u-.32)/.36)))**2 if .32<u<.68 else 0
  if name=='VeilOracle':
   for side,sgn in [('L',1),('R',-1)]:
    n='UpperArm.'+side;arm.pose.bones[n].rotation_quaternion=Q(n,-46*q,(1,0,0))@Q(n,sgn*48*strike,(0,1,0));arm.pose.bones[n].keyframe_insert('rotation_quaternion',frame=f,group=n)
  else:
   n='Head';arm.pose.bones[n].rotation_quaternion=Q(n,-6*q-15*strike,(1,0,0));arm.pose.bones[n].keyframe_insert('rotation_quaternion',frame=f,group=n)
 sc.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(r/(name+'_Combat.blend')));bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);m.select_set(True);bpy.context.view_layer.objects.active=arm
 bpy.ops.export_scene.fbx(filepath=str(r/(name+'_Combat.fbx')),use_selection=True,object_types={'ARMATURE','MESH'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,path_mode='RELATIVE');print('SEAM_FIXED',name,flush=True)
