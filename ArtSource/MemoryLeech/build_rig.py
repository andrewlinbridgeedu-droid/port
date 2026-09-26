import bpy,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'source.glb'))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for o in meshes:
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.select_set(False)
rigdata=bpy.data.armatures.new('LeechSpine');rig=bpy.data.objects.new('MemoryLeechRig',rigdata);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
# Independent segment controls avoid accumulated rotations along the body.
for i in range(7):
 b=rigdata.edit_bones.new('segment_%02d'%i);b.head=(0,-.45+i*.15,0);b.tail=(0,-.35+i*.15,0)
b=rigdata.edit_bones.new('puddle');b.head=(0,0,-.275);b.tail=(0,0,-.175)
bpy.ops.object.mode_set(mode='OBJECT')
for obj in meshes:
 groups=[obj.vertex_groups.new(name='segment_%02d'%i) for i in range(7)]
 for v in obj.data.vertices:
  weights=[math.exp(-((v.co.y-(-.45+i*.15))/.14)**2) for i in range(7)];total=sum(weights)
  for g,w in zip(groups,weights):
   if w/total>.001:g.add([v.index],w/total,'REPLACE')
 mod=obj.modifiers.new('Creature skin','ARMATURE');mod.object=rig;obj.parent=rig
# A separate skinned, irregular wet pool is hidden in all living clips.
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=16,location=(0,0,-.27))
pool=bpy.context.object;pool.name='DeathPusPool';pool.scale=(.37,.52,.045)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for v in pool.data.vertices:
 angle=math.atan2(v.co.y,v.co.x);factor=1+.065*math.sin(angle*5)+.035*math.cos(angle*9)
 v.co.x*=factor;v.co.y*=factor
 if v.co.z>-.27:
  rim=max(0,1-(v.co.x/.40)**2-(v.co.y/.56)**2)
  v.co.z+=rim*(.012+.014*math.sin(v.co.x*29)*math.cos(v.co.y*23))
for face in pool.data.polygons:face.use_smooth=True
mat=bpy.data.materials.new('Grey violet wet residue');mat.diffuse_color=(.105,.075,.135,1);mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.105,.075,.135,1);bs.inputs['Roughness'].default_value=.22
pool.data.materials.append(mat);vg=pool.vertex_groups.new(name='puddle');vg.add(list(range(len(pool.data.vertices))),1,'REPLACE');pool.parent=rig;pool.modifiers.new('Pool expansion','ARMATURE').object=rig
# Raised viscous lobes share the pool bone, so they emerge only during death.
for j,(x,y,radius) in enumerate([(-.12,-.12,.075),(.10,.06,.09),(-.06,.22,.065),(.19,-.15,.048),(-.20,.12,.042),(.02,-.29,.05)]):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=(x,y,-.245))
 bubble=bpy.context.object;bubble.name='PusLobe_%02d'%j;bubble.scale=(radius,radius*.85,radius*.65)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 for face in bubble.data.polygons:face.use_smooth=True
 bubble.data.materials.append(mat)
 group=bubble.vertex_groups.new(name='puddle');group.add(list(range(len(bubble.data.vertices))),1,'REPLACE')
 bubble.parent=rig;bubble.modifiers.new('Pool emergence','ARMATURE').object=rig
rig.animation_data_create()
for name,frames,amp in [('Idle',49,.015),('Crawl',33,.06),('Cast',55,.09),('Hit',17,.07),('Death',73,.14)]:
 act=bpy.data.actions.new(name);rig.animation_data.action=act
 for f in range(1,frames+1):
  t=(f-1)/(frames-1)
  for i,b in enumerate(rig.pose.bones):
   b.scale=(1,1,1)
   b.rotation_mode='XYZ';phase=t*2*math.pi-i*.65
   env=1 if name in ('Idle','Crawl') else math.sin(math.pi*t)
   b.rotation_euler=(amp*math.sin(phase)*env,0,amp*.5*math.cos(phase)*env)
   b.location=(0,0,amp*.12*math.sin(phase)*env)
   if name=='Cast':
    front=max(0,1-i/6)
    lift=math.sin(math.pi*min(t/.48,1)/2) if t<.48 else max(0,1-(t-.48)/.20)
    thrust=math.sin(math.pi*max(0,min((t-.48)/.28,1)))
    b.rotation_euler.x=-.5*front*lift+.35*front*thrust
    b.location=(.018*math.sin(phase)*lift,.10*front*lift-.20*front*thrust,.23*front*lift)
   if name=='Death':
    collapse=max(0,min((t-.15)/.70,1));shrink=(1-collapse)**2
    b.scale=(max(.001,shrink),max(.001,shrink),max(.001,shrink))
    b.location=(0,-b.bone.head_local.y*(1-shrink),-.27*(1-shrink))
    b.rotation_euler=(.18*math.sin(i)*math.sin(math.pi*t),t*.25,0)
   if b.name=='puddle':
    spread=max(.001,min((t-.3)/.6,1)) if name=='Death' else .001
    b.scale=(spread,spread,spread);b.location=(0,0,0);b.rotation_euler=(0,0,0)
   b.keyframe_insert('scale',frame=f)
   b.keyframe_insert('rotation_euler',frame=f);b.keyframe_insert('location',frame=f)
 track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,act);track.mute=True
rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'MemoryLeech.blend'))
bpy.ops.export_scene.gltf(filepath=str(root/'MemoryLeech-rigged.glb'),export_animations=True,export_animation_mode='ACTIONS')
bpy.ops.export_scene.fbx(filepath=str(root/'MemoryLeech.fbx'),use_selection=False,add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,path_mode='COPY',embed_textures=True)
print('CREATURE_RIG_EXPORTED')
