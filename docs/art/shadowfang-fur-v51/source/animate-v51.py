import bpy,math,json
from pathlib import Path
from mathutils import Vector, Matrix
O=Path("/Volumes/andrew's SSD/Downloads/mindstone-game/.build/character-polish-20261015/shadowfang")
F=O/'fur-v51'
bpy.ops.wm.open_mainfile(filepath=str(F/'shadowfang-furcards-v51.blend'))
s=bpy.context.scene;s.render.fps=30;s.render.resolution_x=800;s.render.resolution_y=720;s.render.resolution_percentage=100
arm=bpy.data.objects['Shadowfang_Rig_Test'];obj=bpy.data.objects['Shadowfang_60000']
bpy.context.view_layer.objects.active=arm
bpy.ops.object.mode_set(mode='EDIT')
root=arm.data.edit_bones.new('Root')
root.head=(0,0,-.83);root.tail=(0,0,-.63);root.use_deform=False
arm.data.edit_bones['Hips'].parent=root
bpy.ops.object.mode_set(mode='OBJECT')
arm.animation_data_clear()
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
# Foot targets remain in world space during breathing, biting and breath release.
targets={}
for side in ['L','R']:
 for part,end in [('Front','Foreleg'),('Back','Hock')]:
  b=arm.pose.bones[side+'_'+end]
  t=bpy.data.objects.new(side+part+'_IK',None);s.collection.objects.link(t);t.location=arm.matrix_world@b.tail
  con=b.constraints.new('IK');con.target=t;con.chain_count=2;con.use_tail=True
  targets[(side,part)]=(t,t.location.copy())
def reset():
 for p in arm.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0);p.scale=(1,1,1)
 for t,home in targets.values():t.location=home
def rot(name,x=0,y=0,z=0):
 arm.pose.bones[name].rotation_euler=tuple(math.radians(v) for v in (x,y,z))
def bump(u,a,b):
 return max(0,math.sin(math.pi*(u-a)/(b-a))) if a<=u<=b else 0
def key(u, points):
 for (a,x),(b,y) in zip(points,points[1:]):
  if u<=b:
   t=max(0,min(1,(u-a)/(b-a)));t=t*t*(3-2*t)
   return x+(y-x)*t
 return points[-1][1]
durations={'BattleIdle':90,'Walking':30,'Light':106,'HeavyPrepare':60,'HeavyRelease':121,'HeavyReleaseSecond':121,'Pounce':54,'Probe':40,'Opening':90,'HitAdditive':24}
actions=[]
for name,n in durations.items():
 reset()
 action=bpy.data.actions.new(name);arm.animation_data_create();arm.animation_data.action=action
 samples=[]
 for f in range(1,n+1):
  s.frame_set(f);reset();u=(f-1)/(n-1)
  wave=math.sin(u*math.tau)
  if name in ['BattleIdle','Opening']:
   rot('Neck',1.5*wave);rot('Head',-wave,z=1.3*wave);rot('Tail1',z=4*wave);rot('Tail2',z=5*math.sin(u*math.tau-.4))
  elif name=='Walking':
   for (side,part),(t,home) in targets.items():
    phase=u*math.tau+(0 if (side=='L')==(part=='Front') else math.pi)
    t.location.y+=.10*math.cos(phase);t.location.z+=.055*max(0,math.sin(phase))
   rot('Neck',2*wave);rot('Tail1',z=5*wave)
  elif name=='Light':
   # Anticipation, fast closure at the existing 58% contact, then recovery.
   rot('Neck',key(u,[(0,0),(.3,-8),(.48,5),(.58,10),(.7,6),(1,0)]))
   rot('Head',key(u,[(0,0),(.3,5),(.48,-4),(.58,-7),(.75,-3),(1,0)]))
   rot('Jaw',key(u,[(0,0),(.24,15),(.45,27),(.58,-12),(.66,-12),(.83,5),(1,0)]))
   rot('Tail1',x=key(u,[(0,0),(.3,-7),(.58,6),(1,0)]))
  elif name=='Probe':
   wind=bump(u,0,.45);strike=bump(u,.3,.85)
   rot('Neck',-9*wind+15*strike);rot('Head',8*wind-13*strike);rot('Jaw',-22*wind-10*strike)
  elif name=='HeavyPrepare':
   rot('Neck',-10*math.sin(u*math.pi/2));rot('Head',8*math.sin(u*math.pi/2));rot('Jaw',-15*math.sin(u*math.pi/2))
  elif name.startswith('HeavyRelease'):
   wind=bump(u,0,.5);release=bump(u,.25,.95)
   rot('Neck',-8*wind+12*release);rot('Head',6*wind-8*release);rot('Jaw',key(u,[(0,0),(.07,38),(.91,38),(.98,12),(1,0)]))
   sweep=math.sin((u-.07)*math.tau*1.7)*6*key(u,[(0,0),(.07,1),(.91,1),(1,0)])
   lift=key(u,[(0,0),(.12,1),(.88,1),(1,0)])
   rot('Head',-16*lift,z=sweep)
   rot('Neck',-12*lift,z=sweep*.35)
   rot('Tail1',z=(5 if name.endswith('Second') else -5)*release)
  elif name=='Pounce':
   lift=bump(u,.2,.8)
   # Small displacement test; gameplay movement remains outside the model.
   for (side,part),(t,home) in targets.items():
    t.location.y-=.18*lift;t.location.z+=.12*lift
   rot('Neck',12*lift);rot('Head',-8*lift);rot('Tail1',x=-10*lift)
  elif name=='HitAdditive':
   hit=bump(u,0,.7);rot('Chest',z=-5*hit);rot('Neck',-7*hit);rot('Head',z=9*hit)
  # Quiet, phase-offset fur-tip overlap. Roots retain parent-bone weights.
  for idx in range(23 if 'Fur_00' in arm.pose.bones else 0):
   drift=.65*math.sin(u*math.tau*2+idx*1.71)*math.sin(u*math.pi)**2
   lag=0
   if name=='Light':lag=key(u,[(0,0),(.50,0),(.60,-3),(.72,-1.5),(.80,1.5),(.91,-.5),(1,0)])
   elif name.startswith('HeavyRelease'):lag=.8*bump(u,.08,.95)
   rot('Fur_%02d'%idx,x=drift+lag,z=.45*math.sin(u*math.tau*1.5+idx)*math.sin(u*math.pi)**2)
  # Independent shoulder blades slide over the rib cage while feet solve below.
  for side in ['L','R']:
   blade=arm.pose.bones[side+'_Scapula']
   phase=u-(.035 if side=='R' else 0)
   if name=='Light':
    slide=key(phase,[(0,0),(.42,.025),(.52,.025),(.60,-.065),(.68,-.045),(.77,.035),(.86,-.012),(1,0)])
    rot(side+'_Scapula',key(phase,[(0,0),(.42,-6),(.52,-6),(.60,12),(.68,8),(.77,-9),(.88,2),(1,0)]))
    blade.location.y=slide
   elif name=='Walking':
    blade.location.y=.025*math.cos(u*math.tau+(0 if side=='L' else math.pi))
   elif name in ['BattleIdle','Opening']:
    blade.location.y=.003*wave
  # Ribcage compression and extension are distinct from the pelvic trajectory.
  if name=='Light':
   rot('Spine',key(u,[(0,0),(.42,-5),(.52,-5),(.59,7),(.68,3),(.77,-6),(.89,2),(1,0)]))
  # Restrained overlapping motion: ears trail the launch, tail settles after landing.
  if name=='Light':
   ear=key(u,[(0,0),(.40,-4),(.53,-15),(.63,-15),(.76,5),(.87,-2),(1,0)])
   rot('L_Ear',ear,z=-2*bump(u,.52,.78));rot('R_Ear',ear,z=2*bump(u,.52,.78))
   settle=key(u,[(0,0),(.65,0),(.77,5),(.86,-2),(1,0)])
   arm.pose.bones['Neck'].rotation_euler.x+=math.radians(settle)
   rot('Tail2',x=key(u,[(0,0),(.42,-3),(.57,-10),(.70,7),(.83,-4),(1,0)]))
   rot('Tail3',x=key(u,[(0,0),(.46,-2),(.61,-13),(.75,8),(.88,-3),(1,0)]))
  elif name.startswith('HeavyRelease'):
   fold=key(u,[(0,0),(.12,-8),(.88,-8),(.96,2),(1,0)])
   rot('L_Ear',fold);rot('R_Ear',fold)
   rot('Tail2',z=2.5*math.sin(u*math.tau)*math.sin(u*math.pi))
  elif name in ['BattleIdle','Opening']:
   rot('L_Ear',1.2*bump(u,.18,.46));rot('R_Ear',1.2*bump(u,.56,.84))
  bpy.context.view_layer.update()
  # Move the pelvis in armature space; world-space paw targets preserve stance.
  shift=Vector((0,0,0))
  if name=='Light':
   shift=Vector((0,key(u,[(0,0),(.42,.13),(.52,.13),(.58,-.45),(.72,-.32),(1,0)]),
                  key(u,[(0,0),(.42,-.28),(.52,-.28),(.58,.12),(.66,.025),(.76,-.10),(1,0)])))
   rot('Chest',key(u,[(0,0),(.42,-10),(.52,-10),(.58,12),(.76,-5),(1,0)]))
   for (side,part),(t,home) in targets.items():
    if part=='Front':
     phase=u-(.035 if side=='R' else 0)
     t.location.y+=key(phase,[(0,0),(.51,0),(.58,-.82),(.64,-.82),(.74,-.32),(.82,-.32),(1,0)])
     t.location.z+=key(phase,[(0,0),(.51,0),(.58,.58),(.64,.53),(.74,0),(.82,0),(1,0)])+.06*bump(phase,.82,1)
    else:
     t.location.z+=.065*bump(u,.55,.68)
   # Hind feet brace through the charge, then briefly release after push-off.
  elif name=='Probe':
   wind=bump(u,0,.45);strike=bump(u,.3,.85)
   shift=Vector((0,.045*wind-.13*strike,-.055*wind-.025*strike))
   rot('Chest',-3*wind+6*strike)
  elif name=='HeavyPrepare':
   shift.z=-.055*math.sin(u*math.pi/2)
  elif name.startswith('HeavyRelease'):
   shift=Vector((0,-.07*bump(u,.25,.95),-.035*bump(u,0,.5)))
  elif name=='Pounce':
   crouch=bump(u,0,.28);flight=bump(u,.22,.72);land=bump(u,.68,1)
   shift=Vector((0,-.26*flight,-.10*crouch+.19*flight-.075*land))
   for (side,part),(t,home) in targets.items():
    t.location=home+Vector((0,-.25*flight,.17*flight))
   rot('Chest',-7*crouch+9*flight-5*land)
   rot('Neck',-8*crouch+12*flight-7*land)
  elif name=='HitAdditive':
   shift=Vector((.03*bump(u,0,.7),.07*bump(u,0,.7),-.025*bump(u,0,.7)))
  if shift.length>0:
   hip=arm.pose.bones['Hips'];m=hip.matrix.copy();m.translation+=shift;hip.matrix=m
  bpy.context.view_layer.update()
  pose={p.name:p.matrix.copy() for p in arm.pose.bones}
  for side in ['L','R']:
   for part in ['Forepaw','Hindpaw']:
    namepaw=side+'_'+part
    planted=arm.data.bones[namepaw].matrix_local.copy()
    if name=='Light' and part=='Forepaw':
     phase=u-(.035 if side=='R' else 0)
     reach=key(phase,[(0,0),(.51,0),(.58,1),(.64,1),(.74,0),(1,0)])
     planted=Matrix.Rotation(math.radians(-28*reach),4,'X') @ planted
    planted.translation=pose[namepaw].translation
    pose[namepaw]=planted
  samples.append(pose)
 # Bake the IK results into independent deform-bone curves, no external targets.
 for p in arm.pose.bones:
  for c in p.constraints:c.mute=True
 for f,mats in enumerate(samples,1):
  s.frame_set(f)
  for p in arm.pose.bones:
   # Solve each local pose from captured parent matrices, not stale evaluated
   # parents while assigning the baked pose one bone at a time.
   if p.parent:
    p.matrix_basis=p.bone.matrix_local.inverted() @ p.parent.bone.matrix_local @ mats[p.parent.name].inverted() @ mats[p.name]
   else:
    p.matrix_basis=p.bone.matrix_local.inverted() @ mats[p.name]
   p.keyframe_insert('location',frame=f);p.keyframe_insert('rotation_euler',frame=f);p.keyframe_insert('scale',frame=f)
 for p in arm.pose.bones:
  for c in p.constraints:c.mute=False
 action.use_fake_user=True;actions.append(action)
for p in arm.pose.bones:
 for c in list(p.constraints):p.constraints.remove(c)
for t,home in targets.values():bpy.data.objects.remove(t,do_unlink=True)
# Export only model and armature, all 10 action takes.
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);obj.select_set(True);bpy.context.view_layer.objects.active=arm
arm.animation_data.action=actions[0];arm.animation_data.action_slot=actions[0].slots[0];s.frame_set(1)
bpy.ops.export_scene.fbx(filepath=str(F/'Shadowfang_FurCards_v51.fbx'),use_selection=True,object_types={'MESH','ARMATURE'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,axis_forward='-Z',axis_up='Y')
# Extract original material images as PNG for Unity material authoring.
for i in bpy.data.images:
 if i.type=='IMAGE' and i.size[0]>1000:
  pass
s.render.resolution_percentage=80
# Side-on ground contact review, same camera for every frame.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.835))
floor=bpy.context.object;floor.name='Review ground only'
mat=bpy.data.materials.new('Review neutral floor');mat.diffuse_color=(.13,.15,.17,1);floor.data.materials.append(mat)
s.camera.location=(5,0,1.1)
s.camera.rotation_euler=(Vector((0,0,0))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.camera.data.ortho_scale=3.6
for name in []:
 a=next(a for a in actions if a.name==name);arm.animation_data.action=a;arm.animation_data.action_slot=a.slots[0]
 folder=O/('charge-breath-v23-'+name);folder.mkdir(exist_ok=True)
 for f in range(1,durations[name]+1,6):
  s.frame_set(f);s.render.filepath=str(folder/('%03d.png'%f));bpy.ops.render.render(write_still=True)
arm.animation_data.action=actions[0];arm.animation_data.action_slot=actions[0].slots[0];s.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(F/'shadowfang-actions-v51.blend'))
(F/'actions-report-v51.json').write_text(json.dumps({'clips':durations,'status':'Authored motion prototypes; not visual acceptance or device integration'},indent=2))
