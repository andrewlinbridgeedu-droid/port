import bpy,numpy as np,math,json,time,sys
from pathlib import Path
from mathutils import Vector,Quaternion
R=Path(__file__).resolve().parent
S=['Copperback','CrimsonBrute','VeilOracle','GoldenThroat','Moonfang']
if '--' in sys.argv:S=sys.argv[sys.argv.index('--')+1:]
def skeleton(name):
 D={'Root':((0,0,0),(0,0,.1),None)}
 if name=='Copperback':
  D.update({'Pelvis':((0,.65,.9),(0,.35,1.12),'Root'),'Chest':((0,.35,1.12),(0,-.65,1.30),'Pelvis'),'Head':((0,-.65,1.3),(0,-1.25,.95),'Chest')})
  arm=[(.64,-.58,1.15),(.85,-.73,.68),(.85,-.88,.16),(.85,-1.05,.06)]
  leg=[(.64,.8,1.05),(.8,.95,.55),(.83,1.0,.14),(.83,.8,.06)]
  for side,x in [('L',1),('R',-1)]:D['Armor.'+side]=((x*.2,.1,1.45),(x*.7,.1,1.65),'Chest')
 elif name=='CrimsonBrute':
  D.update({'Pelvis':((0,.05,.72),(0,.04,1.0),'Root'),'Chest':((0,.04,1.),(0,0,1.43),'Pelvis'),'Head':((0,0,1.43),(0,-.07,1.84),'Chest')})
  arm=[(.28,0,1.36),(.45,-.02,1.04),(.57,-.09,.71),(.59,-.14,.44)]
  leg=[(.2,.06,.74),(.26,.025,.42),(.28,.07,.15),(.3,-.18,.04)]
 elif name=='VeilOracle':
  D.update({'Pelvis':((0,.06,.81),(0,.05,1.08),'Root'),'Chest':((0,.05,1.08),(0,.025,1.39),'Pelvis'),'Head':((0,.025,1.39),(0,-.04,1.76),'Chest')})
  arm=[(.19,.025,1.3),(.3,-.025,1.08),(.43,-.07,.88),(.48,-.12,.62)]
  leg=[(.13,.075,.8),(.19,.11,.47),(.25,.08,.11),(.27,-.13,.035)]
  for side,x in [('L',1),('R',-1)]:D['Cloth.'+side]=((x*.20,.08,.92),(x*.34,.08,.28),'Pelvis')
 elif name=='GoldenThroat':
  D.update({'Pelvis':((0,.14,.67),(0,.1,.96),'Root'),'Chest':((0,.1,.96),(0,.04,1.42),'Pelvis'),'Head':((0,.04,1.42),(0,-.06,1.85),'Chest'),'Throat':((0,-.12,1.48),(0,-.30,1.43),'Chest')})
  arm=[(.25,.02,1.34),(.4,-.035,1.11),(.53,-.10,.89),(.60,-.12,.69)]
  leg=[(.21,.14,.67),(.23,.06,.44),(.27,.13,.18),(.31,-.19,.035)]
 else:
  D.update({'Pelvis':((0,.7,1.02),(0,.3,1.12),'Root'),'Chest':((0,.3,1.12),(0,-.60,1.22),'Pelvis'),'Head':((0,-.60,1.22),(0,-1.45,1.35),'Chest'),'TailBase':((0,.91,1.02),(-.16,1.43,.64),'Pelvis'),'Tail1':((-.16,1.43,.64),(-.49,1.77,.55),'TailBase'),'TailTip':((-.49,1.77,.55),(-.66,1.63,.91),'Tail1')})
  arm=[(.28,-.62,1.07),(.34,-.64,.55),(.39,-.91,.15),(.42,-1.10,.04)]
  leg=[(.28,.68,1.05),(.42,.52,.64),(.48,.96,.24),(.49,.78,.04)]
  for side,x in [('L',1),('R',-1)]:D['Ear.'+side]=((x*.30,-.91,1.47),(x*.49,-.81,1.87),'Head')
 for side,x in [('R',-1),('L',1)]:
  def v(q):return(q[0]*x,q[1],q[2])
  D['UpperArm.'+side]=(v(arm[0]),v(arm[1]),'Chest');D['Forearm.'+side]=(v(arm[1]),v(arm[2]),'UpperArm.'+side);D['Hand.'+side]=(v(arm[2]),v(arm[3]),'Root' if name in ['Copperback','Moonfang'] else 'Forearm.'+side)
  D['Thigh.'+side]=(v(leg[0]),v(leg[1]),'Root');D['Shin.'+side]=(v(leg[1]),v(leg[2]),'Thigh.'+side);D['Foot.'+side]=(v(leg[2]),v(leg[3]),'Root')
 return D
for name in S:
 r=R/name;out=R.parents[1]/'output/church-minions-combat-20260921'/name;out.mkdir(parents=True,exist_ok=True)
 while not (r/'vertices.npy').exists():time.sleep(5)
 bpy.ops.wm.open_mainfile(filepath=str(r/'Prepared.blend'));sc=bpy.context.scene;m=next(o for o in sc.objects if o.type=='MESH')
 if name=='Moonfang':
  coords=np.array([v.co[:] for v in m.data.vertices]);correction={}
  for side in [-1,1]:
   for front in [True,False]:
    mask=(coords[:,0]*side>.16)&(coords[:,1]<-.25 if front else coords[:,1]>.35)
    low=mask&(coords[:,2]<.4);dz=float(coords[low,2].min()) if low.any() else 0
    ids=np.where(mask)[0];fade=np.clip((.72-coords[ids,2])/.45,0,1);coords[ids,2]-=dz*fade
    correction[str((side,front))]=dz
  m.data.vertices.foreach_set('co',coords.ravel());m.data.update();(r/'paw-rest-correction.json').write_text(json.dumps(correction,indent=2))
 # Explicit external source maps avoid reopening packed original 4K data.
 for mat in m.data.materials:
  for node in mat.node_tree.nodes:
   if node.type=='TEX_IMAGE' and node.image:
    old=node.image;im=bpy.data.images.load(str(r/(old.name+'_2k.png')),check_existing=False);im.colorspace_settings.name=old.colorspace_settings.name;im.pack();node.image=im
 D=skeleton(name);sk=bpy.data.armatures.new(name+'Skeleton');arm=bpy.data.objects.new(name+'Rig',sk);bpy.context.collection.objects.link(arm)
 bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);bpy.context.view_layer.objects.active=arm;bpy.ops.object.mode_set(mode='EDIT')
 for n,(h,t,p) in D.items():
  b=sk.edit_bones.new(n);b.head=h;b.tail=t
  if p:b.parent=sk.edit_bones[p]
 bpy.ops.object.mode_set(mode='OBJECT');m.select_set(True);bpy.ops.object.parent_set(type='ARMATURE_AUTO')
 # Pin soles and isolate soft anatomy with smooth region blends.
 V=np.array([v.co[:] for v in m.data.vertices])
 for i,(x,y,z) in enumerate(V):
  bone=None;weight=1
  if z<.075:bone='Foot.'+('L' if x>0 else 'R') if y>0 or name not in ['Copperback','Moonfang'] else 'Hand.'+('L' if x>0 else 'R')
  if name=='GoldenThroat' and 1.23<z<1.68 and y<-.12 and abs(x)<.24:
   bone='Throat';weight=min(1,(z-1.23)/.09,(1.68-z)/.08,(-y-.12)/.08)
  elif name=='Moonfang' and z>1.38 and abs(x)>.23 and y<-.55:
   bone='Ear.'+('L' if x>0 else 'R');weight=min(1,(z-1.38)/.22)
  elif name=='VeilOracle' and .22<z<.88 and abs(x)>.28 and y>.015:
   bone='Cloth.'+('L' if x>0 else 'R');weight=min(.8,(.88-z)/.24)
  if bone and bone in m.vertex_groups:
   for g in list(m.vertex_groups):
    try:w=g.weight(i)
    except RuntimeError:continue
    g.add([i],w*(1-weight),'REPLACE')
   m.vertex_groups[bone].add([i],weight,'ADD')
 print('WEIGHTED',name,flush=True)
 bpy.context.view_layer.objects.active=m;arm.select_set(False);bpy.ops.object.vertex_group_limit_total(limit=4);bpy.ops.object.vertex_group_normalize_all(lock_active=False)
 for mat in m.data.materials:
  mat.name=name+'_SourcePBR'
  for node in mat.node_tree.nodes:
   if node.type=='TEX_IMAGE' and node.image:
    im=node.image;suffix='BaseColor' if 'Image_0' in im.name else 'Normal' if 'Image_2' in im.name else 'MetalRough';im.filepath_raw=str(r/f'{name}_{suffix}_2k.png');im.file_format='PNG';im.save()
 mr=next((node.image for mat in m.data.materials for node in mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image and 'Image_1' in node.image.name),None)
 if mr:
  pix=np.empty(len(mr.pixels),dtype=np.float32);mr.pixels.foreach_get(pix);pix=pix.reshape(-1,4);pixels=np.ones_like(pix);pixels[:,:3]=pix[:,2,None];pixels[:,3]=(1-pix[:,1])*.7
  im=bpy.data.images.new(name+'_MetalSmooth_2k',width=mr.size[0],height=mr.size[1],alpha=True);im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(pixels.ravel());im.filepath_raw=str(r/f'{name}_MetalSmooth_2k.png');im.file_format='PNG';im.save()
 for b in arm.pose.bones:b.rotation_mode='QUATERNION'
 arm.animation_data_create();arm.animation_data.action=bpy.data.actions.new(name+'Combat')
 clips={'Idle':[1,121],'Charge':[122,166],'Cast':[167,196],'Hit':[197,208],'Death':[209,244],'Charge2':[245,289],'Cast2':[290,319],'Retreat':[320,359]}
 def rot(n,a,axis=(1,0,0)):
  if n in arm.pose.bones:
   local=arm.data.bones[n].matrix_local.to_3x3().inverted()@Vector(axis)
   arm.pose.bones[n].rotation_quaternion=Quaternion(local,math.radians(a))
 def scale(n,s):
  if n in arm.pose.bones:arm.pose.bones[n].scale=(s,s,s)
 def pose(q,second=False):
  if name=='Copperback':
   rot('Chest',-5*q if not second else 7*q);rot('Head',9*q if not second else -8*q)
   rot('Armor.L',-15*q if second else 1.5*q,(0,1,0));rot('Armor.R',15*q if second else -1.5*q,(0,1,0))
   if second:arm.pose.bones['Chest'].rotation_quaternion @= Quaternion(arm.data.bones['Chest'].matrix_local.to_3x3().inverted()@Vector((0,0,1)),math.radians(-8*q))
   for side in ['L','R']:rot('UpperArm.'+side,-7*q);rot('Forearm.'+side,9*q)
  elif name=='CrimsonBrute':
   rot('Chest',-9*q);rot('Head',7*q)
   if second:
    for side,sgn in [('L',1),('R',-1)]:rot('UpperArm.'+side,-115*q);rot('Forearm.'+side,-32*q)
   else:rot('UpperArm.R',35*q);rot('Forearm.R',-65*q);rot('Chest',-13*q,(0,0,1));rot('UpperArm.L',-18*q)
  elif name=='VeilOracle':
   rot('Head',-7*q);rot('Chest',-4*q)
   for side,sgn in [('L',1),('R',-1)]:
    if second or side=='R':rot('UpperArm.'+side,-46*q);rot('Forearm.'+side,-32*q,(0,0,1));rot('Hand.'+side,sgn*19*q,(0,1,0))
    rot('Cloth.'+side,sgn*5*q,(0,1,0))
  elif name=='GoldenThroat':
   scale('Throat',1+.22*q if not second else 1+.1*q);rot('Head',-5*q);rot('Chest',-5*q)
   for side,sgn in [('L',1),('R',-1)]:rot('UpperArm.'+side,sgn*(24 if second else 8)*q,(0,1,0));rot('Forearm.'+side,-12*q)
  else:
   rot('Chest',7*q if not second else 0);rot('Head',9*q if not second else -6*q)
   if second:rot('Chest',-10*q,(0,0,1));rot('TailBase',22*q,(0,0,1));rot('Tail1',28*q,(0,0,1));rot('TailTip',25*q,(0,0,1))
   for side,sgn in [('L',1),('R',-1)]:rot('Ear.'+side,sgn*8*q,(0,1,0));rot('Forearm.'+side,-7*q)
 for f in range(1,360):
  for b in arm.pose.bones:b.rotation_quaternion=Quaternion();b.location=(0,0,0);b.scale=(1,1,1)
  clip=next(n for n,(a,b) in clips.items() if a<=f<=b);a,b=clips[clip];u=(f-a)/(b-a)
  if clip=='Idle':
   w=math.sin(u*math.pi*2);w2=math.sin(u*math.pi*4)
   rot('Chest',.65*w);rot('Head',1.5*w2,(0,0,1))
   if name=='Copperback':rot('Armor.L',.7*w,(0,1,0));rot('Armor.R',-.7*w,(0,1,0))
   elif name=='CrimsonBrute':rot('Forearm.L',2*w);rot('Forearm.R',-2*w);rot('Head',1.7*w2)
   elif name=='VeilOracle':rot('Cloth.L',2*w,(0,1,0));rot('Cloth.R',-2*w2,(0,1,0));rot('Hand.L',3*w);rot('Hand.R',-3*w)
   elif name=='GoldenThroat':scale('Throat',1+.035*w);rot('Forearm.L',1.5*w);rot('Forearm.R',-1.5*w)
   else:rot('Ear.L',3*w,(0,1,0));rot('Ear.R',-2*w2,(0,1,0));rot('Tail1',4*w,(0,0,1));rot('TailTip',7*w2,(0,0,1))
  elif clip.startswith('Charge'):pose(u*u*(3-2*u),clip.endswith('2'))
  elif clip.startswith('Cast'):
   second=clip.endswith('2');release=max(0,min(1,(u-.18)/.32));q=1-release*release*(3-2*release);pose(q,second)
   strike=math.sin(math.pi*max(0,min(1,(u-.32)/.36)))**2 if .32<u<.68 else 0
   if name=='CrimsonBrute':
    if second:
     for side in ['L','R']:rot('UpperArm.'+side,-115*q+110*strike);rot('Forearm.'+side,-32*q+20*strike)
     rot('Chest',-9*q+18*strike)
    else:rot('UpperArm.R',35*q-95*strike);rot('Forearm.R',-65*q+35*strike);rot('Chest',-13*q+15*strike,(0,0,1))
   elif name=='VeilOracle':
    for side,sgn in [('L',1),('R',-1)]:
     if second:
      rot('UpperArm.'+side,-46*q);arm.pose.bones['UpperArm.'+side].rotation_quaternion @= Quaternion(arm.data.bones['UpperArm.'+side].matrix_local.to_3x3().inverted()@Vector((0,1,0)),math.radians(sgn*48*strike));rot('Forearm.'+side,-32*q+sgn*22*strike,(0,0,1))
     elif side=='R':
      rot('UpperArm.R',-46*q-35*strike);rot('Hand.R',-19*q,(0,1,0));arm.pose.bones['Hand.R'].rotation_quaternion @= Quaternion(arm.data.bones['Hand.R'].matrix_local.to_3x3().inverted()@Vector((1,0,0)),math.radians(-30*strike))
   elif name=='GoldenThroat':
    scale('Throat',1+(.1 if second else .22)*q-.07*strike);rot('Head',-5*q+8*strike)
    if second:
     for side,sgn in [('L',1),('R',-1)]:rot('UpperArm.'+side,sgn*(24*q-45*strike),(0,1,0));rot('Forearm.'+side,-12*q-20*strike)
     rot('Chest',-5*q+8*strike)
   elif name=='Copperback':
    rot('Chest',(7 if second else -5)*q+(8 if second else 7)*strike);rot('Head',(-8 if second else 9)*q-9*strike)
    if second:
     arm.pose.bones['Chest'].rotation_quaternion @= Quaternion(arm.data.bones['Chest'].matrix_local.to_3x3().inverted()@Vector((0,0,1)),math.radians(-8*q+12*strike))
     rot('Armor.L',-15*q+5*strike,(0,1,0));rot('Armor.R',15*q-5*strike,(0,1,0))
   else:
    rot('Head',(-6 if second else 9)*q-15*strike)
    if second:rot('TailBase',22*q-28*strike,(0,0,1));rot('Tail1',28*q-30*strike,(0,0,1));rot('TailTip',25*q-35*strike,(0,0,1))
  elif clip=='Hit':rot('Chest',-4*math.sin(math.pi*u)**2);rot('Head',5*math.sin(math.pi*u)**2)
  elif clip=='Death':
   q=u*u*(3-2*u);rot('Chest',19*q);rot('Head',18*q);rot('Neck',10*q)
   for side in ['L','R']:rot('UpperArm.'+side,10*q)
  elif clip=='Retreat':rot('Head',6*math.sin(math.pi*u),(0,0,1))
  for b in arm.pose.bones:
   b.keyframe_insert('rotation_quaternion',frame=f,group=b.name);b.keyframe_insert('location',frame=f,group=b.name);b.keyframe_insert('scale',frame=f,group=b.name)
 sc.frame_start=1;sc.frame_end=359;sc.render.fps=30
 sc.render.engine='CYCLES';sc.cycles.samples=12;sc.cycles.use_denoising=True;sc.world=bpy.data.worlds.new('CreatureStudio');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.12,.16,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.55
 center=Vector((0,0,1))
 for off,power,color,size in [((2,-4,4),450,(1,.90,.78),3),((-3,-2,2),300,(.72,.80,1),3),((1,2,3),550,(.86,.91,1),2)]:
  bpy.ops.object.light_add(type='AREA',location=center+Vector(off));l=bpy.context.object;l.data.energy=power;l.data.color=color;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=center+Vector((.15,-5,.15)));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.6 if name=='Copperback' else 2.85;sc.camera=cam;sc.render.resolution_x=560;sc.render.resolution_y=700;sc.render.resolution_percentage=100;sc.view_settings.view_transform='AgX'
 sc.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(r/(name+'_Combat.blend')))
 bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);m.select_set(True);bpy.context.view_layer.objects.active=arm
 bpy.ops.export_scene.fbx(filepath=str(r/(name+'_Combat.fbx')),use_selection=True,object_types={'ARMATURE','MESH'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,path_mode='RELATIVE')
 # FBX is the production interchange; packed Blend preserves editable source.
 manifest=json.loads((r/'manifest.json').read_text());manifest.update({'bones':len(D),'clips':clips,'bone_coordinates':D,'fps':30});(r/'manifest.json').write_text(json.dumps(manifest,indent=2))
 for label,f in [('idle',1),('charge',166),('cast',182),('charge2',289),('cast2',305)]:sc.frame_set(f);sc.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
 print('COMBAT_EXPORTED',name,len(D),flush=True)
