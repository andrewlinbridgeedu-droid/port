"""Check axial arm orientation and quaternion interpolation, not only hand positions."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
root=Path(sys.argv[sys.argv.index('--')+1]);doc=root/'docs/development/hero-refinement-20261001/v4'
bpy.ops.wm.open_mainfile(filepath=str(doc/'HeroSovereign-v4.blend'))
rig=bpy.data.objects['HeroSovereignV4'];scene=bpy.context.scene
for o in scene.objects:
 if o.type=='MESH':o.hide_viewport=True
clips=[];failures=[]
for entry in json.loads((doc/'manifest.json').read_text())['clips']:
 action=bpy.data.actions[entry['name']];rig.animation_data.action=action
 last={};min_dot=1;max_step=0;min_rear=1;max_twist=0;max_shoulder_twist=0;worst=None
 for frame in range(round(action.frame_range[1])+1):
  scene.frame_set(frame)
  for b in rig.pose.bones:
   q=b.rotation_quaternion.copy()
   if b.name in last:
    signed=q.dot(last[b.name]);min_dot=min(min_dot,signed)
    step=math.degrees(2*math.acos(max(-1,min(1,abs(signed)))))
    if step>max_step:max_step=step;worst=[frame,b.name]
   last[b.name]=q
  spine=rig.pose.bones['Spine'];body=spine.matrix.to_quaternion()@spine.bone.matrix_local.to_quaternion().inverted()
  for side in ['Left','Right']:
   a=rig.pose.bones[side+'Arm'];b=rig.pose.bones[side+'ForeArm']
   deform=a.matrix.to_quaternion()@a.bone.matrix_local.to_quaternion().inverted()
   base=(a.bone.tail_local-a.bone.head_local).normalized();direction=(a.tail-a.head).normalized()
   expected_upper=(body@base).rotation_difference(direction)@body@a.bone.matrix_local.to_quaternion()
   max_shoulder_twist=max(max_shoulder_twist,math.degrees(2*math.acos(min(1,abs(expected_upper.normalized().dot(a.matrix.to_quaternion().normalized()))))))
   min_rear=min(min_rear,(deform@Vector((0,1,0))).dot(body@Vector((0,1,0))))
   source=(b.bone.tail_local-b.bone.head_local).normalized();now=(b.tail-b.head).normalized()
   swing=(deform@source).rotation_difference(now)
   expected=swing@deform@b.bone.matrix_local.to_quaternion()
   max_twist=max(max_twist,math.degrees(2*math.acos(min(1,abs(expected.normalized().dot(b.matrix.to_quaternion().normalized()))))))
 clips.append({'clip':entry['name'],'frames':round(action.frame_range[1])+1,'minimumAdjacentQuaternionDot':min_dot,'maxBoneStepDegrees':max_step,'worstStep':worst,'minimumUpperArmRearFacingDot':min_rear,'maxUpperArmAxialDeviationDegrees':max_shoulder_twist,'maxForearmAxialDeviationDegrees':max_twist})
 if min_dot<=0:failures.append([entry['name'],'antipodal key',min_dot])
 if max_shoulder_twist>=1:failures.append([entry['name'],'shoulder axial twist',max_shoulder_twist])
 if max_twist>=1:failures.append([entry['name'],'independent forearm roll',max_twist])
 if max_step>=35:failures.append([entry['name'],'angular jump',max_step])
r={'checkedFrames':sum(c['frames'] for c in clips),'all14ClipsPassed':not failures,'failures':failures,'check':'minimum shoulder swing from torso rest frame, elbow hinge swing, no antipodal quaternion keys','clips':clips,'userVisualApproval':False}
(doc/'arm-orientation.json').write_text(json.dumps(r,indent=2)+'\n')
print('ARM_ORIENTATION_RESULT',r['checkedFrames'],failures,flush=True)
assert not failures,failures
