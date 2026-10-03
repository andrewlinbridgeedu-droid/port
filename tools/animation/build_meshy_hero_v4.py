"""Polish the three user-supplied Sovereign GLBs and bind the existing cast library.

Source files are immutable. Runtime meshes, painted-light atlases, one shared
T-pose rig and all fourteen existing gesture timings are versioned separately.
Blender --factory-startup -b --python this.py -- <repo> [--no-bake]
"""
import bpy, bmesh, math, json, sys, hashlib, os
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
DOC = ROOT / 'docs/development/hero-refinement-20261001/v4'
OUT = ROOT / 'UnityBattleSource/Assets/Resources/CombatTempo/RefinedHeroV4'
OUT.mkdir(parents=True, exist_ok=True)
NO_BAKE = '--no-bake' in sys.argv
TARGET_TRIANGLES = 180000
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.cycles.use_denoising = False
scene.render.bake.margin = 12
scene.view_settings.view_transform = 'Standard'
source_records = []
meshes = []

def log(*args):
    print('HERO_V4', *args, flush=True)

for key in ['night', 'starlight', 'carnival']:
    src = DOC / 'sources' / key / 'original.glb'
    digest = hashlib.sha256(src.read_bytes()).hexdigest()
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(src))
    obj = next(o for o in set(bpy.data.objects) - before if o.type == 'MESH')
    matrix = obj.matrix_world.copy()
    corners = [matrix @ Vector(c) for c in obj.bound_box]
    lo = Vector(tuple(min(p[i] for p in corners) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in corners) for i in range(3)))
    scale = 175 / (hi.z - lo.z)
    origin = Vector(((lo.x + hi.x) / 2, 0, lo.z))
    for v in obj.data.vertices:
        v.co = (matrix @ v.co - origin) * scale
    # Fit neutral arm proportions to one shared wrist/palm skeleton. The
    # Starlit source has shorter T-pose arms; correction ramps from the shoulder.
    tip_x={'night':79.8,'starlight':73.8,'carnival':78.2}[key]
    hand_dy={'night':0,'starlight':0,'carnival':3.2}[key]
    hand_dz={'night':0,'starlight':1.8,'carnival':-.3}[key]
    for v in obj.data.vertices:
        if abs(v.co.x)>15 and v.co.z>115:
            sign=1 if v.co.x>0 else -1
            v.co.x=sign*(15+(abs(v.co.x)-15)*(79.8-15)/(tip_x-15))
            t=max(0,min(1,(abs(v.co.x)-35)/29))
            v.co.y+=hand_dy*t;v.co.z+=hand_dz*t
    obj.matrix_world = Matrix.Identity(4)
    obj.name = 'Outfit-' + key + '-Sovereign'
    mat = obj.data.materials[0]
    mat.name = 'V4 ' + key + ' Painted'
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
    image_node = bsdf.inputs['Base Color'].links[0].from_node
    original_colour = image_node.image
    original_colour.filepath_raw = str(DOC / 'sources' / key / 'source-albedo.png')
    original_colour.file_format = 'PNG'
    original_colour.save()
    # The source's metallic/roughness reflection is intentionally not baked.
    # High-poly creases supply only shallow contact shading, like painted lines.
    output = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
    emit = nodes.new('ShaderNodeEmission')
    ao = nodes.new('ShaderNodeAmbientOcclusion')
    ao.inputs['Distance'].default_value = .65
    ao.samples = 16
    ao.only_local = True
    shade = nodes.new('ShaderNodeMixRGB')
    shade.blend_type = 'MULTIPLY'
    shade.inputs[0].default_value = .18
    links.new(image_node.outputs['Color'], shade.inputs[1])
    links.new(ao.outputs['Color'], shade.inputs[2])
    links.new(shade.outputs[0], emit.inputs['Color'])
    links.new(emit.outputs[0], output.inputs['Surface'])
    atlas_path = OUT / (key + '-painted-4k.png')
    if not NO_BAKE or not atlas_path.exists():
        atlas = bpy.data.images.new(key + ' painted 4K', width=4096, height=4096, alpha=False)
        atlas.generated_color = (.025, .022, .033, 1)
        target = nodes.new('ShaderNodeTexImage')
        target.image = atlas
        nodes.active = target
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        log('bake', key, len(obj.data.polygons), 'source faces')
        bpy.ops.object.bake(type='EMIT')
        atlas.filepath_raw = str(atlas_path)
        atlas.file_format = 'PNG'
        atlas.save()
        log('baked', key)
    else:
        atlas = bpy.data.images.load(str(atlas_path))
    # Keep final Blender shading as restrained as the Unity illustrated shader.
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    texture = nodes.new('ShaderNodeTexImage'); texture.image = atlas
    emit = nodes.new('ShaderNodeEmission'); emit.inputs['Strength'].default_value = .86
    diffuse = nodes.new('ShaderNodeBsdfDiffuse'); diffuse.inputs['Roughness'].default_value = 1
    # Neutralise green spill left on the source hair tips, confined by a
    # vertex region mask. Preserve the coloured fabrics and the source UVs.
    region=nodes.new('ShaderNodeVertexColor');region.layer_name='HeroRegions'
    channel=nodes.new('ShaderNodeSeparateColor');links.new(texture.outputs['Color'],channel.inputs[0])
    mask_channel=nodes.new('ShaderNodeSeparateColor');links.new(region.outputs['Color'],mask_channel.inputs[0])
    peak=nodes.new('ShaderNodeMath');peak.operation='MAXIMUM';links.new(channel.outputs[0],peak.inputs[0]);links.new(channel.outputs[2],peak.inputs[1])
    green=nodes.new('ShaderNodeMath');green.operation='SUBTRACT';links.new(channel.outputs[1],green.inputs[0]);links.new(peak.outputs[0],green.inputs[1])
    strength=nodes.new('ShaderNodeMath');strength.operation='MULTIPLY';strength.inputs[1].default_value=25;strength.use_clamp=True;links.new(green.outputs[0],strength.inputs[0])
    region_mask=nodes.new('ShaderNodeMath');region_mask.operation='MULTIPLY';links.new(strength.outputs[0],region_mask.inputs[0]);links.new(mask_channel.outputs[0],region_mask.inputs[1])
    grey=nodes.new('ShaderNodeRGBToBW');links.new(texture.outputs['Color'],grey.inputs[0])
    tint=nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1;tint.inputs[2].default_value=(1.03,.92,1.07,1);links.new(grey.outputs[0],tint.inputs[1])
    clean=nodes.new('ShaderNodeMixRGB');links.new(region_mask.outputs[0],clean.inputs[0]);links.new(texture.outputs[0],clean.inputs[1]);links.new(tint.outputs[0],clean.inputs[2])
    links.new(clean.outputs[0],emit.inputs['Color']);links.new(clean.outputs[0],diffuse.inputs['Color'])
    mix = nodes.new('ShaderNodeMixShader'); mix.inputs[0].default_value = .12
    links.new(emit.outputs[0], mix.inputs[1]); links.new(diffuse.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs[0])
    source_faces = sum(len(p.vertices)-2 for p in obj.data.polygons)
    # Weld only coincident geometric seams; loop UVs and original texture islands stay intact.
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.0001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data); bm.free()
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    decimate = obj.modifiers.new('Preserve dense source silhouette, runtime mesh only', 'DECIMATE')
    decimate.ratio = min(1, TARGET_TRIANGLES / source_faces)
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    for p in obj.data.polygons: p.use_smooth = True
    if obj.data.has_custom_normals:
        obj.data.normals_split_custom_set([(0,0,0)] * len(obj.data.loops))
    regions=obj.data.color_attributes.new(name='HeroRegions',type='FLOAT_COLOR',domain='CORNER')
    colours=[]
    for loop in obj.data.loops:
        z=obj.data.vertices[loop.vertex_index].co.z
        colours.extend((max(0,min(1,(z-151)/3)),0,0,1))
    regions.data.foreach_set('color',colours)
    source_records.append({'outfit':key,'sourceSha256':digest,'sourceTriangles':source_faces,
        'runtimeTriangles':sum(len(p.vertices)-2 for p in obj.data.polygons),
        'runtimeVertices':len(obj.data.vertices),'sourceTextureSize':list(original_colour.size),
        'runtimeColourSize':list(atlas.size),'atlasMethod':'source albedo plus high-poly shallow AO emission bake; no reflective lobe; not newly generated 4K painting'})
    meshes.append(obj)
    log('runtime mesh', key, len(obj.data.vertices), 'vertices')

# The supplied characters have neutral T-pose arms. Bind in that pose, instead
# of reusing v3's bent-arm bind matrices, which would twist the new sleeves.
data = bpy.data.armatures.new('Sovereign shared skeleton')
rig = bpy.data.objects.new('HeroSovereignV4', data)
scene.collection.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
spec = {
 'Hips':((0,0,94),(0,0,105),None),
 'Spine02':((0,0,105),(0,0,118),'Hips'),
 'Spine01':((0,0,118),(0,0,130),'Spine02'),
 'Spine':((0,0,130),(0,0,141),'Spine01'),
 'neck':((0,0,141),(0,0,153),'Spine'),
 'Head':((0,0,153),(0,0,173),'neck')}
for side, sign in [('Left',1),('Right',-1)]:
    shoulder=(sign*15,0,139);elbow=(sign*40,0,138);wrist=(sign*62,0,137)
    spec[side+'Shoulder']=((sign*3,0,140),shoulder,'Spine')
    spec[side+'Arm']=(shoulder,elbow,side+'Shoulder')
    spec[side+'ForeArm']=(elbow,wrist,side+'Arm')
    spec[side+'Hand']=(wrist,(sign*76,0,136),side+'ForeArm')
    spec[side+'UpLeg']=((sign*7.5,0,94),(sign*9,0,52),'Hips')
    spec[side+'Leg']=((sign*9,0,52),(sign*9,0,12),side+'UpLeg')
    spec[side+'Foot']=((sign*9,0,12),(sign*9,-9,3),side+'Leg')
    spec[side+'Toe']=((sign*9,-9,3),(sign*9,-17,3),side+'Foot')
finger_chains={
 'Thumb':[(64.5,-5,136),(68,-6.5,135),(72,-7.1,134.7)],
 'Index':[(69,-4.7,138.4),(74,-4.8,138.5),(79,-5,138.1)],
 'Middle':[(70,-2,138.5),(75.4,-1.7,138.6),(79.8,-1.5,138.6)],
 'Ring':[(69.5,0,137.7),(74,.6,137.6),(78,1,137.3)],
 'Pinky':[(69,1.9,136.4),(72.5,2.5,136.4),(75.4,2.9,136.2)]}
for side,sign in [('Left',1),('Right',-1)]:
    for digit,chain in finger_chains.items():
        for j in range(2):
            name=side+digit+str(j+1)
            a,b=chain[j:j+2]
            spec[name]=((a[0]*sign,a[1],a[2]),(b[0]*sign,b[1],b[2]),side+'Hand' if j==0 else side+digit+'1')
for side, sign in [('L',1),('R',-1)]:
    spec['Coat.'+side]=((sign*10,8,103),(sign*20,8,62),'Hips')
    spec['CoatTip.'+side]=((sign*20,8,62),(sign*28,8,22),'Coat.'+side)
    spec['Ribbon.'+side]=((sign*14,8,103),(sign*21,11,68),'Hips')
    spec['ArmRibbon.'+side]=((sign*29,4,134),(sign*40,5,114),('Left' if sign==1 else 'Right')+'Arm')
for name,(head,tail,parent) in spec.items():
    b=data.edit_bones.new(name);b.head=head;b.tail=tail
    if parent:b.parent=data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
rig.matrix_world = Matrix.Scale(.01, 4)

def blend(a,b,t):
    t=max(0,min(1,t));return {a:1-t,b:t}
def spine_weights(z):
    stops=[(94,'Hips'),(109,'Spine02'),(122,'Spine01'),(136,'Spine'),(148,'neck'),(155,'Head')]
    if z<=94:return {'Hips':1}
    for (a,n),(b,m) in zip(stops,stops[1:]):
        if z<=b:return blend(n,m,(z-a)/(b-a))
    return {'Head':1}
def base_weights(p):
    x,y,z=p;ax=abs(x);side='Left' if x>0 else 'Right';suffix='L' if x>0 else 'R'
    # Distinguish long hanging upper-arm ribbons from the actual skirt.
    if (ax>15 and z>126) or (ax>30 and z>108):
        if ax>63:
            pp=Vector((ax,y,z));candidates=[]
            for digit,chain in finger_chains.items():
                a,b,c=map(Vector,chain)
                ab=b-a;t=max(0,min(1,(pp-a).dot(ab)/ab.length_squared));q=a+ab*t
                bc=c-b;u=max(0,min(1,(pp-b).dot(bc)/bc.length_squared));r=b+bc*u
                distance=min((pp-q).length,(pp-r).length)
                candidates.append((distance,digit,a,b,c))
            distance,digit,a,b,c=min(candidates,key=lambda v:v[0])
            axis=(c-a).normalized();progress=(pp-a).dot(axis)
            influence=max(0,min(1,(progress+1.5)/3))
            t=max(0,min(1,(progress-(b-a).length+1.3)/2.6))
            return {side+'Hand':1-influence,side+digit+'1':influence*(1-t),side+digit+'2':influence*t}
        if ax>56:return blend(side+'ForeArm',side+'Hand',(ax-56)/7)
        if ax>44:return {side+'ForeArm':1}
        if ax>35:return blend(side+'Arm',side+'ForeArm',(ax-35)/9)
        if ax>30:return {side+'Arm':1}
        t=max(0,min(1,(ax-15)/15));t=t*t*(3-2*t)
        torso=spine_weights(z)
        return {**{n:w*(1-t) for n,w in torso.items()},side+'Arm':t}
    if z>149:return spine_weights(z)
    if z>=98:return spine_weights(z)
    # Leg cylinders stay separate from the outer coat. Coat edges and rear
    # panels follow the existing two-link cloth chain, not the nearest knee.
    leg_center=8.5
    is_leg=abs(ax-leg_center)<7 and -13<y<10
    if z<32 and ax<24 and y<12:is_leg=True
    if not is_leg:
        if z>86:return blend('Hips','Coat.'+suffix,(98-z)/12)
        if z>65:return {'Coat.'+suffix:1}
        if z>48:return blend('Coat.'+suffix,'CoatTip.'+suffix,(65-z)/17)
        return {'CoatTip.'+suffix:1}
    if z<11:return {side+'Foot':1}
    if z<20:return blend(side+'Foot',side+'Leg',(z-11)/9)
    if z<44:return {side+'Leg':1}
    if z<60:return blend(side+'Leg',side+'UpLeg',(z-44)/16)
    if z<84:return {side+'UpLeg':1}
    return blend(side+'UpLeg','Hips',(z-84)/14)

def weights(p,key):
    result=base_weights(p)
    x,y,z=p;ax=abs(x)
    def smooth(t):
        t=max(0,min(1,t));return t*t*(3-2*t)
    if key=='night' and 23<ax<46 and 99<z<132 and y>1:
        strength=smooth((132-z)/10)*smooth((ax-23)/5)*(1-smooth((ax-42)/4))*smooth((y-1)/2)
        result={name:value*(1-strength) for name,value in result.items()}
        result['ArmRibbon.'+('L' if x>0 else 'R')]=strength
    return result

for obj in meshes:
    obj.parent=rig;obj.matrix_parent_inverse=Matrix.Identity(4);obj.matrix_basis=Matrix.Identity(4)
    names=list(spec)
    indices={n:i for i,n in enumerate(names)}
    values=np.zeros((len(obj.data.vertices),len(names)),dtype=np.float32)
    for vertex in obj.data.vertices:
        for name,w in weights(vertex.co,obj.name.split('-')[1]).items():values[vertex.index,indices[name]]=w
    # Diffuse joint weights along actual surface edges. This keeps nearby but
    # disconnected jewellery/cloth from inheriting a leg or arm accidentally.
    edges=np.empty(len(obj.data.edges)*2,dtype=np.int32)
    obj.data.edges.foreach_get('vertices',edges);edges=edges.reshape(-1,2)
    row=np.concatenate((edges[:,0],edges[:,1]));col=np.concatenate((edges[:,1],edges[:,0]))
    coordinates=np.array([v.co[:] for v in obj.data.vertices])
    length=np.linalg.norm(coordinates[row]-coordinates[col],axis=1)
    edge_weight=1/np.maximum(length,.1)**2
    degree=np.bincount(row,weights=edge_weight,minlength=len(values)).clip(.00001)[:,None]
    for step in range(18):
        neighbour=np.zeros_like(values);np.add.at(neighbour,row,values[col]*edge_weight[:,None])
        values=values*.45+(neighbour/degree)*.55
    groups={name:obj.vertex_groups.new(name=name) for name in names}
    for i,value in enumerate(values):
        selected=np.argsort(value)[-4:];total=value[selected].sum()
        for index in selected:
            if value[index]>1e-5:groups[names[index]].add([i],float(value[index]/total),'REPLACE')
    modifier=obj.modifiers.new('Shared cast skeleton','ARMATURE');modifier.object=rig
    log('skinned',obj.name)

# Reuse the authored v3 gesture paths, wrist follow-through, coat delay and all
# release timings. A T-pose needs a stable elbow plane and shoulder roll reference. Shared palm clearance and sleeve-ribbon settling are added below;
# all clip lengths and release timings remain unchanged.
motion_source=ROOT/'tools/animation/build_meshy_hero_v3.py'
text=motion_source.read_text()
motion=text[text.index('def turn(name,'):text.index("rig.animation_data.action=bpy.data.actions['BattleIdle']")]
# Resolve shoulder roll from the torso-facing plane, then bend the forearm
# around the elbow hinge. Independent shortest-arc shoulder/forearm aims can
# select the opposite roll when a hand swings behind the body.
arm_start=motion.index('def arm(side,target):');arm_end=motion.index('def curve(',arm_start)
stable_arm="""def arm(side,target):
    side='Left' if side=='L' else 'Right';a=rig.pose.bones[side+'Arm'];b=rig.pose.bones[side+'ForeArm']
    start=a.head.copy();d=Vector(target)-start;dist=max(22,min(d.length,a.bone.length+b.bone.length-.2));axis=d.normalized()
    along=(a.bone.length**2-b.bone.length**2+dist**2)/(2*dist);h=math.sqrt(max(0,a.bone.length**2-along**2))
    pole=Vector((15 if side=='Left' else -15,10,-15))
    hint=pole-axis*pole.dot(axis)
    if hint.length<.01:hint=Vector((1 if side=='Left' else -1,0,-.65))
    elbow=start+axis*along+hint.normalized()*h
    upper=(elbow-start).normalized()
    spine=rig.pose.bones['Spine']
    torso=spine.matrix.to_quaternion()@spine.bone.matrix_local.to_quaternion().inverted()
    original=(a.bone.tail_local-a.bone.head_local).normalized()
    # Shoulder swing is measured from the torso's rest arm. Projecting the
    # back-facing vector onto the arm plane has a singularity when the arm
    # points forward; minimum swing has no such singularity in these poses.
    swing=(torso@original).rotation_difference(upper)
    rotation=(swing@torso@a.bone.matrix_local.to_quaternion()).to_matrix()
    matrix=rotation.to_4x4();matrix.translation=start;a.matrix=matrix
    bpy.context.view_layer.update()
    # Elbow flexion is a hinge swing of the established upper-arm frame; the
    # forearm cannot choose a new 180-degree axial roll on its own.
    aim(side+'ForeArm',start+axis*dist)
"""
motion=motion[:arm_start]+stable_arm+motion[arm_end:]
# Symmetric target smoothing keeps the clip duration and release phase while
# easing sharp changes in the inherited short key-point path.
motion=motion.replace('def curve(points,p):','def raw_curve(points,p):')
index=motion.index('R=(-28,-14,127)')
motion=motion[:index]+"""def curve(points,p):
    if p<=0:return Vector(points[0])
    if p>=1:return Vector(points[-1])
    result=Vector()
    for offset,weight in [(-.08,1),(-.04,4),(0,6),(.04,4),(.08,1)]:
        result+=raw_curve(points,max(0,min(1,p+offset)))*(weight/16)
    fade=math.sin(p*math.pi)**.5
    return raw_curve(points,p).lerp(result,fade)
"""+motion[index:]

motion=motion.replace("    start=a.head.copy();d=Vector(target)-start;", """    target=Vector(target)
    # Keep the expanded source palms clear of the fitted torso during the
    # backward preparation. This is a shared joint-space clearance correction,
    # with no timing/impact changes and no outfit-specific clip.
    def smooth(t):
        t=max(0,min(1,t));return t*t*(3-2*t)
    clearance=math.exp(-(abs(target.x)/25)**8)*smooth((target.z-101)/16)*smooth((170-target.z)/16)
    target.y-=clearance*max(0,target.y+21)
    start=a.head.copy();d=Vector(target)-start;""")
motion=motion.replace("rest_elbow=Vector(spec[side+'Arm'][1])-Vector(spec[side+'Arm'][0])", "rest_elbow=Vector((10 if side=='Left' else -10,0,-25))")
def settle_ribbons(clip,p):
    # The sleeve attachment follows the arm; the long pendant fabric keeps a
    # downward orientation, rather than rotating rigidly across the back.
    bpy.context.view_layer.update()
    for side,sign in [('L',1),('R',-1)]:
        bone=rig.pose.bones['ArmRibbon.'+side]
        head=bone.head.copy()
        basis=bone.bone.matrix_local.to_quaternion()
        flutter=math.sin(p*math.tau-.2)*(2 if clip=='BattleIdle' else 7)*math.sin(p*math.pi)
        rot=Quaternion(Vector((1,0,0)),math.radians(flutter))@basis
        matrix=rot.to_matrix().to_4x4();matrix.translation=head;bone.matrix=matrix
    bpy.context.view_layer.update()
def finger_pose(clip,p):
    idle=clip=='BattleIdle'
    # Slight relaxed curl, closing during anticipation and opening on release.
    hold=7 if idle else 7+15*math.exp(-((p-.25)/.16)**2)-4*math.exp(-((p-.58)/.12)**2)
    for side,sign in [('Left',1),('Right',-1)]:
        for index,digit in enumerate(finger_chains):
            amount=hold*(.65 if digit=='Thumb' else 1+(index-2)*.09)
            for j in [1,2]:turn(side+digit+str(j),roll=sign*amount*(1 if j==1 else .65))
motion=motion.replace("    if clip=='Hit':", "    finger_pose(clip,p)\n    settle_ribbons(clip,p)\n    if clip=='Hit':")
# Quaternion signs are equivalent at a key, but opposite signs between keys
# can interpolate through a flipped limb. Keep each clip in one hemisphere.
motion=motion.replace("    for frame in range(count+1):", "    previous_rotations={}\n    for frame in range(count+1):")
motion=motion.replace("            b.keyframe_insert('rotation_quaternion'", "            previous=previous_rotations.get(b.name)\n            if previous is not None and previous.dot(b.rotation_quaternion)<0:b.rotation_quaternion.negate()\n            previous_rotations[b.name]=b.rotation_quaternion.copy()\n            b.keyframe_insert('rotation_quaternion'")
exec(compile(motion,str(motion_source)+'#shared-v3-gestures','exec'))
rig.animation_data.action=bpy.data.actions['BattleIdle']
scene.frame_set(0);scene.render.fps=60;scene.frame_start=0;scene.frame_end=144
for obj in meshes:obj.hide_render=not obj.name.startswith('Outfit-night-')
for image in bpy.data.images:
    if image.source=='FILE':image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(DOC/'HeroSovereign-v4.blend'))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'HeroSovereignV4.fbx'),use_selection=True,object_types={'MESH','ARMATURE'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,bake_anim_step=1,axis_forward='-Z',axis_up='Y',path_mode='AUTO')
report={'sources':source_records,'bones':len(data.bones),'sharedSkeleton':True,'sharedClips':True,
    'motionSource':str(motion_source.relative_to(ROOT)),'motionSourceSha256':hashlib.sha256(motion_source.read_bytes()).hexdigest(),
    'ikCalibration':'minimum shoulder swing from torso rest frame, outward/rear/down elbow pole, hinged forearm, smooth torso clearance, eased target path, continuous quaternion hemisphere; v3 gesture identities and timings retained',
    'fingerBones':20,'sleeveRibbonBones':2,'weightSmoothing':'inverse-square edge-distance weighted, four influences maximum',
    'clips':[{'name':n,'seconds':d,'contactNormalized':None if n=='BattleIdle' else .58} for n,d in clips],
    'userVisualApproval':False,'installed':False}
(DOC/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
log('exported',len(clips),'clips')
