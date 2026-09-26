import bpy, sys, math
from mathutils import Vector, Euler
src, dst = sys.argv[-2:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene=bpy.context.scene
scene.render.fps=24
arm=next(o for o in scene.objects if o.type=='ARMATURE')
for o in scene.objects: o.animation_data_clear()
for b in arm.pose.bones:
    b.rotation_mode='QUATERNION'
    b.matrix_basis.identity()
base={b.name:b.rotation_quaternion.copy() for b in arm.pose.bones}
scene.frame_start=1; scene.frame_end=198
# Independent object tracks, never share an action between armature and IK helpers.
def helper(name,loc):
    o=bpy.data.objects.new(name,None); scene.collection.objects.link(o); o.parent=arm; o.location=loc; return o
helpers=[]
for side,sign in [('Left',1),('Right',-1)]:
    hand=helper(side+'Target',(sign*.28,-.18,1.10))
    pole=helper(side+'Pole',(sign*.65,-.10,1.20))
    c=arm.pose.bones[side+'ForeArm'].constraints.new('IK'); c.target=hand; c.chain_count=2
    helpers.append(hand)
keys=[(1,.28,-.18,1.10,0),(24,.28,-.20,1.11,-1),(48,.28,-.18,1.10,0),
(49,.28,-.18,1.10,0),(72,.19,-.42,1.25,3),(96,.17,-.28,1.22,5),(120,.17,-.28,1.22,5),
(121,.17,-.28,1.22,5),(132,.22,-.52,1.32,2),(150,.25,-.60,1.30,-5),(160,.25,-.60,1.30,-5),(180,.27,-.42,1.15,-2),(198,.28,-.18,1.10,0)]
for f,x,y,z,lean in keys:
    scene.frame_set(f)
    for o,sign in zip(helpers,[1,-1]):
        o.location=(sign*x,y,z); o.keyframe_insert('location',frame=f)
    for name in ['Spine','Spine01','Spine02']:
        b=arm.pose.bones.get(name)
        if b:
            b.rotation_quaternion=Euler((math.radians(lean),0,0)).to_quaternion(); b.keyframe_insert('rotation_quaternion',frame=f)
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active=arm
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.nla.bake(frame_start=1,frame_end=198,step=1,only_selected=False,visual_keying=True,clear_constraints=True,use_current_action=False,bake_types={'POSE'})
bpy.ops.object.mode_set(mode='OBJECT')
arm.animation_data.action.name='EmeraldTimeline'
scene.frame_set(1)
for o in list(scene.objects):
    if o.type not in {'MESH','ARMATURE'}: bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=dst+'.blend')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.fbx(filepath=dst+'.fbx',use_selection=True,object_types={'ARMATURE','MESH'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y')
print('BAKED_TIMELINE',arm.animation_data.action.name)
