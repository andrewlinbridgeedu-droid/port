import bpy,math
from mathutils import Vector,Quaternion
from pathlib import Path
R=Path(__file__).resolve().parent;r=R/'GoldenThroat';bpy.ops.wm.open_mainfile(filepath=str(r/'GoldenThroat_Combat.blend'));sc=bpy.context.scene;arm=next(o for o in sc.objects if o.type=='ARMATURE');m=next(o for o in sc.objects if o.type=='MESH')
def Q(n,a,axis):return Quaternion(arm.data.bones[n].matrix_local.to_3x3().inverted()@Vector(axis),math.radians(a))
for f in range(290,320):
 sc.frame_set(f);u=(f-290)/29;t=max(0,min(1,(u-.18)/.32));q=1-t*t*(3-2*t);strike=math.sin(math.pi*max(0,min(1,(u-.32)/.36)))**2 if .32<u<.68 else 0
 for side,sgn in [('L',1),('R',-1)]:
  for n,ang,axis in [('UpperArm.'+side,sgn*(24*q-45*strike),(0,1,0)),('Forearm.'+side,-12*q-20*strike,(1,0,0))]:arm.pose.bones[n].rotation_quaternion=Q(n,ang,axis);arm.pose.bones[n].keyframe_insert('rotation_quaternion',frame=f,group=n)
 arm.pose.bones['Chest'].rotation_quaternion=Q('Chest',-5*q+8*strike,(1,0,0));arm.pose.bones['Chest'].keyframe_insert('rotation_quaternion',frame=f,group='Chest')
 arm.pose.bones['Throat'].scale=(1+.1*q-.07*strike,)*3;arm.pose.bones['Throat'].keyframe_insert('scale',frame=f,group='Throat')
sc.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(r/'GoldenThroat_Combat.blend'))
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);m.select_set(True);bpy.context.view_layer.objects.active=arm
bpy.ops.export_scene.fbx(filepath=str(r/'GoldenThroat_Combat.fbx'),use_selection=True,object_types={'ARMATURE','MESH'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,path_mode='RELATIVE')
sc.frame_set(305);sc.render.filepath=str(R.parents[1]/'output/church-minions-combat-20260921/GoldenThroat/cast2.png');bpy.ops.render.render(write_still=True)
print('REFINED_FROG',flush=True)
