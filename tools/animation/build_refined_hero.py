"""Blender-authored rear tailoring and shared seven-cast library. No external motion.

Blender -b --python tools/animation/build_refined_hero.py -- <repo>
The existing face, skin UVs and licensed base rig are preserved. New cloth,
embroidery, hair strands and ornaments are real weighted geometry.
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
DOC = ROOT / 'docs/development/hero-refinement-20261001'
OUT = ROOT / 'UnityBattleSource/Assets/Resources/CombatTempo/RefinedHero'
FPS = 60
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT / 'UnityBattleSource/Assets/Models/Fool/Meshy_AI_battle_magician_rig_biped_Animation_Combat_Stance_frame_rate_60.fbx'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.animation_data_clear()
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
for b in rig.pose.bones: b.matrix_basis.identity()
base = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
base.name = 'Preserved face hands boots and base cloth'

def material(name, color, metal=0, rough=.55):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    return m

cloth=material('Hero Coat Charcoal',(.016,.011,.025),0,.72)
silk=material('Hero Violet Silk',(.072,.018,.15),0,.55)
gold=material('Hero Embroidered Gold',(.65,.39,.10),.64,.31)
teal=material('Hero Teal Sash',(.018,.22,.25),.02,.40)
hair=material('Hero Hair Strands',(.003,.003,.006),0,.66)
jewel=material('Hero Violet Gem',(.24,.025,.39),.26,.20)
ivory=material('Hero Ivory Cuff',(.67,.61,.47),0,.66)
leather=material('Hero Leather',(.032,.025,.033),0,.39)
star_gold=material('Hero Starlight Motifs',(.67,.43,.17),.62,.35)
carnival_gold=material('Hero Carnival Motifs',(.67,.40,.12),.62,.35)
body=base.data.materials[0];body.name='Hero Original Skin Atlas'
for n in body.node_tree.nodes:
    if n.type=='TEX_IMAGE':
        if n.label=='': pass
        # The FBX references a removed output.fbm. Relink the original authored atlas.
        suffix='_normal' if '001' in n.name else '_roughness' if '002' in n.name else ''
        path=ROOT / ('UnityBattleSource/Assets/Resources/RuntimeModels/Fool/Meshy_AI_battle_magician_rig_biped_texture_0'+suffix+'.png')
        n.image=bpy.data.images.load(str(path),check_existing=True)
        if suffix: n.image.colorspace_settings.name='Non-Color'
base.data.materials.append(cloth);base.data.materials.append(leather);base.data.materials.append(hair)

# Remove the old flat coat tips, keeping leg skin and boot vertices intact.
bm=bmesh.new();bm.from_mesh(base.data);bm.verts.ensure_lookup_table()
mapping=rig.matrix_world.inverted() @ base.matrix_world
kill=[]
for v in bm.verts:
    source=base.data.vertices[v.index];p=mapping @ source.co
    hips=sum(g.weight for g in source.groups if base.vertex_groups[g.group].name=='Hips')
    legs=sum(g.weight for g in source.groups if any(t in base.vertex_groups[g.group].name for t in ('Leg','Foot','Toe')))
    if p.z < 104 and hips > .55 and legs < .1 and (p.y>10 or abs(p.x)>18):kill.append(v)
bmesh.ops.delete(bm,geom=kill,context='VERTS');bm.to_mesh(base.data);bm.free()
for poly in base.data.polygons:
    verts=[base.data.vertices[i] for i in poly.vertices]
    anatomy=set(base.vertex_groups[g.group].name for v in verts for g in v.groups if g.weight>.35)
    z=sum((mapping@v.co).z for v in verts)/len(verts)
    if not any(n in anatomy for n in ('Head','head_end','headfront','LeftHand','RightHand')):
        poly.material_index=2 if z<85 else 1
    elif any(n in anatomy for n in ('Head','head_end','headfront')):
        center=sum((mapping@v.co for v in verts),Vector())/len(verts)
        if center.z>155 or center.y>10:poly.material_index=3
    # Blended neck/head weights can all be below the material threshold. Classify
    # the rear hair shell spatially too, so outfit tint never turns it grey/white.
    center=sum((mapping@v.co for v in verts),Vector())/len(verts)
    if center.z>160 or (center.z>150 and center.y>5):
        poly.material_index=3
    poly.use_smooth=True
sub=base.modifiers.new('Sculpted cloth and boot smoothing','SUBSURF');sub.levels=1;sub.render_levels=1
bpy.context.view_layer.objects.active=base;bpy.ops.object.modifier_apply(modifier=sub.name)

bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for side,sign in [('L',1),('R',-1)]:
    b=rig.data.edit_bones.new('Coat.'+side);b.head=(sign*11,13,108);b.tail=(sign*24,20,65);b.parent=rig.data.edit_bones['Hips']
    c=rig.data.edit_bones.new('CoatTip.'+side);c.head=b.tail;c.tail=(sign*32,23,35);c.parent=b
    b=rig.data.edit_bones.new('Ribbon.'+side);b.head=(sign*12,14,106);b.tail=(sign*18,17,70);b.parent=rig.data.edit_bones['Hips']
bpy.ops.object.mode_set(mode='OBJECT')

parts=[]
def skin_object(obj,weights):
    obj.parent=rig;obj.matrix_parent_inverse.identity();obj.matrix_basis.identity()
    for name in set(n for w in weights for n in w):
        group=obj.vertex_groups.new(name=name)
        for i,w in enumerate(weights):
            if w.get(name,0)>0: group.add([i],w[name],'REPLACE')
    arm=obj.modifiers.new('Shared hero skin','ARMATURE');arm.object=rig
    for p in obj.data.polygons:p.use_smooth=True
    parts.append(obj);return obj

def mesh(name,verts,faces,mat,weights):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.data.materials.append(mat)
    return skin_object(obj,weights)

def thread(name,points,radius,mat,weights=None,sides=6):
    vs=[];fs=[];ws=[]
    for i,point in enumerate(points):
        point=Vector(point);tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.normalize();axis=tangent.cross(Vector((0,1,0)))
        if axis.length<.01:axis=tangent.cross(Vector((1,0,0)))
        axis.normalize();other=tangent.cross(axis).normalized()
        rad=radius(i/(len(points)-1)) if callable(radius) else radius
        for j in range(sides):
            angle=j*math.tau/sides;vs.append(point+rad*(math.cos(angle)*axis+math.sin(angle)*other))
            ws.append(weights[i] if weights else {'Spine':1})
        if i:
            for j in range(sides):a=(i-1)*sides+j;b=(i-1)*sides+(j+1)%sides;c=i*sides+(j+1)%sides;d=i*sides+j;fs.append((a,b,c,d))
    fs.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,mat,ws)

def torso_point(u,z):
    width=12.7+(z-108)/35*5.1
    return (u*width,13.9+3.9*(1-u*u)+.42*math.cos((z-108)*.14)+.22*math.sin(u*19)*math.sin((z-108)*.1),z)

# A sculpted back panel and yoke, not a painted flat world-space rectangle.
vs=[];fs=[];ws=[]
for j in range(22):
    z=108+j/21*34
    for i in range(25):
        u=-1+i/12;vs.append(torso_point(u,z));blend=min(1,max(0,(z-112)/18));ws.append({'Hips':1-blend,'Spine':blend})
        if i and j:a=(j-1)*25+i-1;fs.append((a,a+1,a+26,a+25))
torso=mesh('Tailored fitted back',vs,fs,cloth,ws)
solid=torso.modifiers.new('Real cloth thickness','SOLIDIFY');solid.thickness=.32

# Close the tailored waist/seat underneath the split tails. The source skirt
# never had a complete seat surface, so removing its old tips must not expose the arena.
vs=[];fs=[]
for j in range(9):
    t=j/8
    for i in range(41):
        a=i/40*math.tau
        vs.append((14.3*math.cos(a),5+(12.9-.6*t)*math.sin(a),108-14*t))
        if i and j:p=(j-1)*41+i-1;fs.append((p,p+41,p+42,p+1))
mesh('Closed tailored waist under tails',vs,fs,cloth,[{'Hips':1} for _ in vs])

def tail_weights(side,t):
    a=min(1,t*3);b=max(0,(t-.40)/.60)*.76
    return {'Hips':1-a,'Coat.'+side:a*(1-b),'CoatTip.'+side:a*b}

def tail_point(side,u,t,inner=False):
    sign=1 if side=='L' else -1
    x=sign*(3.2+u*(10+18*t)+7*t+2*math.sin(t*math.pi))
    y=14.5+7*t+2.1*math.sin(u*math.pi*3+t*1.8)+2.2*t*t*u+(1 if inner else 0)
    z=107-70*t+8*math.sin(math.pi*u)*t-6*u*t*t
    return (x,y,z)

for side in ['L','R']:
    vs=[];fs=[];ws=[]
    for j in range(33):
        t=j/32
        for i in range(19):
            u=i/18;vs.append(tail_point(side,u,t));ws.append(tail_weights(side,t))
            if i and j:a=(j-1)*19+i-1;fs.append((a,a+1,a+20,a+19))
    panel=mesh('Flowing coat tail '+side,vs,fs,silk,ws)
    solid=panel.modifiers.new('Silk lining thickness','SOLIDIFY');solid.thickness=.40
    # Separate sculpted dark outer cloth leaves a curved band of violet lining.
    vs=[];fs=[];ws=[]
    for j in range(33):
        t=j/32
        for i in range(15):
            u=.32+.68*i/14;point=Vector(tail_point(side,u,t,True));point.y+=.55
            vs.append(point);ws.append(tail_weights(side,t))
            if i and j:a=(j-1)*15+i-1;fs.append((a,a+1,a+16,a+15))
    mesh('Dark outer coat '+side,vs,fs,cloth,ws)
    for u in [.32,1]:
        pts=[];ww=[]
        for i in range(41):
            t=i/40;p=Vector(tail_point(side,u,t,True));p.y+=.80;pts.append(p);ww.append(tail_weights(side,t))
        thread('Outer gold piping '+side,pts,.20,gold,ww)
    for u in [0,1]:
        pts=[tail_point(side,u,i/40,True) for i in range(41)]
        thread('Gold tail piping '+side,pts,.27,gold,[tail_weights(side,i/40) for i in range(41)])
    # Fine organic branching stitches follow the curved cloth and deformation weights.
    for twig in range(7):
        t0=.30+twig*.091
        pts=[];ww=[]
        for i in range(23):
            f=i/22;t=t0+f*.084;u=.48+.27*f+.10*math.sin(f*math.pi)
            point=Vector(tail_point(side,u,t,True));point.y+=.82;pts.append(point);ww.append(tail_weights(side,t))
        thread('Vine embroidery '+side,pts,.115,gold,ww,5)
        for leaf in [0,1,2]:
            pts=[];ww=[]
            for i in range(24):
                angle=i/23*math.tau;u=.56+.09*leaf+.07*math.sin(angle)*(math.sin(angle*.5)**2);t=t0+.027*leaf+.032*math.cos(angle)
                point=Vector(tail_point(side,u,t,True));point.y+=.84;pts.append(point);ww.append(tail_weights(side,t))
            thread('Leaf stitch '+side,pts,.095,gold,ww,5)
    pts=[tail_point(side,.02+.77*(i/32),1,True) for i in range(33)]
    thread('Gold hem '+side,pts,.24,gold,[tail_weights(side,1) for _ in pts])

for sign,side in [(1,'L'),(-1,'R')]:
    # Shaped waist seams and a scroll yoke create a recognizable rear silhouette.
    pts=[torso_point(sign*(.43+.27*i/32),109+30*i/32) for i in range(33)]
    thread('Back princess seam '+side,pts,.23,gold,[{'Hips':max(0,1-i/17),'Spine':min(1,i/17)} for i in range(33)])
    for k in range(3):
        pts=[]
        for i in range(35):
            a=i/34*math.pi*1.72;u=sign*(.64+.15*math.cos(a)*(1-i/65));z=138-k*1.7+2.4*math.sin(a)
            p=Vector(torso_point(u,z));p.y+=.65;pts.append(p)
        thread('Shoulder scroll '+side,pts,.16,gold)
    for k in range(4):
        pts=[]
        for i in range(41):
            t=i/40;u=sign*(.18+.16*math.sin(t*math.pi*.74)+.045*k);z=117+k*3+7*t
            p=Vector(torso_point(u,z));p.y+=.55;pts.append(p)
        thread('Fine back branching brocade '+side,pts,.105,gold)
        for leaf in range(3):
            pts=[]
            for i in range(25):
                a=i/24*math.tau;u=sign*(.26+.055*k+.045*math.sin(a));z=120+k*3+leaf*.9+1.2*math.cos(a)
                p=Vector(torso_point(u,z));p.y+=.65;pts.append(p)
            thread('Back leaf embroidery '+side,pts,.075,gold)
    pts=[(sign*(3+i/24*14),18.6+i/24*.7,138.4-3.6*math.sin(i/24*math.pi*.5)) for i in range(25)]
    thread('Back yoke border '+side,pts,.33,gold)

# Collar follows the neck, with a violet inner shell and piping.
vs=[];fs=[]
for j in range(6):
    for i in range(41):
        a=(-.15+i/40*1.3)*math.pi;r=7.9+j/5*2.2
        vs.append((r*math.cos(a),7+r*math.sin(a),144+j*1.18))
        if i and j:p=(j-1)*41+i-1;fs.append((p,p+1,p+42,p+41))
collar=mesh('Lifted layered collar',vs,fs,silk,[{'neck':1} for _ in vs]);collar.modifiers.new('Collar cloth thickness','SOLIDIFY').thickness=.5
thread('Collar edge',[vs[5*41+i] for i in range(41)],.25,gold,[{'neck':1} for _ in range(41)])

def gem(name,point,size,bone):
    x,y,z=point;vs=[(x,y-size*.5,z+size),(x+size*.7,y,z),(x,y+size*.55,z),(x-size*.7,y,z),(x,y-size*.5,z-size)]
    return mesh(name,vs,[(0,1,2),(0,2,3),(4,2,1),(4,3,2),(0,3,1),(4,1,3)],jewel,[{bone:1} for _ in vs])
gem('Back violet jewel',(0,19.6,137),1.9,'Spine')
thread('Back jewel gold frame',[(0,20,141),(2,20,137),(0,20,133),(-2,20,137),(0,20,141)],.26,gold)
for z in [110,113]:
    thread('Waist closure',[(x,19.5,z) for x in range(-8,9)],.23,gold,[{'Hips':1} for _ in range(17)])

for side,sign in [('L',1),('R',-1)]:
    # Cuffs use the actual forearm orientation, so no hovering rigid sleeve rings.
    b=rig.data.bones[('Left' if side=='L' else 'Right')+'ForeArm'];bone=b.name
    center=b.head_local.lerp(b.tail_local,.79);axis=(b.tail_local-b.head_local).normalized()
    u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized()
    vs=[];fs=[]
    for j in range(5):
        for i in range(25):
            a=i/24*math.tau;r=4.2+(j/4)*1.4
            vs.append(center+axis*(j-2)*1.05+r*(u*math.cos(a)+v*math.sin(a)))
            if i and j:p=(j-1)*25+i-1;fs.append((p,p+1,p+26,p+25))
    mesh('Flared violet cuff '+side,vs,fs,silk,[{bone:1} for _ in vs])
    thread('Gold cuff hem '+side,[vs[4*25+i] for i in range(25)],.23,gold,[{bone:1} for _ in range(25)])
    gem('Cuff gem '+side,center+v*6.4,1.3,bone)
    pts=[]
    for i in range(33):
        t=i/32;pts.append((sign*(12+10*t),16+3*math.sin(t*math.pi),105-36*t))
    ribbon=thread('Teal ribbon '+side,pts,lambda t:.9*(1-.48*t),teal,[{'Hips':1-t,'Ribbon.'+side:t} for t in [i/32 for i in range(33)]],4)
    # Small chain loops, weighed into the coat rather than static stage props.
    for k in range(9):
        t=.1+k*.095;p=Vector(tail_point(side,.87,t,True));p.y+=.75
        pts=[p+Vector((math.sin(a)*.58,0,math.cos(a)*1)) for a in [i/16*math.tau for i in range(17)]]
        thread('Coat chain '+side,pts,.14,gold,[tail_weights(side,t) for _ in pts],5)

def star(point,size,bone):
    p=Vector(point);verts=[p+Vector((0,.30,0))]
    for i in range(16):
        a=i/16*math.tau;r=size if i%2==0 else size*.33
        verts.append(p+Vector((r*math.sin(a),0,r*math.cos(a))))
    mesh('Star embroidery',verts,[(0,i+1,(i+1)%16+1) for i in range(16)],star_gold,[{bone:1} for _ in verts])
star((0,20.5,126),3.8,'Spine')
for sign in [-1,1]:
    star((sign*8,19,133),1.7,'Spine')
    star((sign*28,26,53),2.8,'CoatTip.'+('L' if sign>0 else 'R'))
    p=Vector((sign*6,20,124))
    pts=[p+Vector((math.sin(a)*2,0,math.cos(a)*3)) for a in [i/32*math.tau for i in range(33)]]
    thread('Carnival back teardrop',pts,.24,carnival_gold)

# Tapered overlapping strands replace the flat rear hair silhouette with layers.
for ring in range(5):
    for k in range(22):
        if ring>2 and k>11:continue
        a=k/22*math.tau+ring*.16;vs=[];fs=[]
        for i in range(12):
            t=i/11;polar=.05+ring*.31+t*.55
            z=159+11.6*math.cos(polar)
            radius=10.4*math.sin(polar)+.45*math.sin(t*math.pi)
            center=Vector((2+radius*math.cos(a+t*.32),7+radius*math.sin(a+t*.32),z))
            width=1.4*math.sin((.12+.88*t)*math.pi)**.7+.015
            side=Vector((-math.sin(a+t*.38),math.cos(a+t*.38),0))
            normal=Vector((math.cos(a+t*.38),math.sin(a+t*.38),.25))
            for col in [-1,0,1]:vs.append(center+side*width*col+normal*(.48 if col==0 else 0))
            if i:
                p=(i-1)*3;fs.extend([(p,p+1,p+4,p+3),(p+1,p+2,p+5,p+4)])
        mesh('Swept tapered hair lock',vs,fs,hair,[{'Head':1} for _ in vs])

# Merge by material to keep runtime draw calls bounded, retaining all skin weights.
for mat in [cloth,silk,gold,teal,hair,jewel,ivory,leather,star_gold,carnival_gold]:
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o!=base and o.data.materials[0]==mat]
    if not objects:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    objects[0].name=mat.name

def turn(name,pitch=0,yaw=0,roll=0):
    b=rig.pose.bones.get(name)
    if not b:return
    basis=b.bone.matrix_local.to_quaternion()
    delta=Quaternion(Vector((1,0,0)),math.radians(pitch))@Quaternion(Vector((0,0,1)),math.radians(yaw))@Quaternion(Vector((0,1,0)),math.radians(roll))
    b.rotation_mode='QUATERNION';b.rotation_quaternion=basis.inverted()@delta@basis

def aim(name,target):
    b=rig.pose.bones[name];direction=Vector(target)-b.head
    q=(b.tail-b.head).normalized().rotation_difference(direction.normalized())
    mat=b.matrix.copy();rotation=q@mat.to_quaternion();mat=rotation.to_matrix().to_4x4();mat.translation=b.head;b.matrix=mat
    bpy.context.view_layer.update()

def arm(side,target):
    name=('Left' if side=='L' else 'Right')
    a=rig.pose.bones[name+'Arm'];b=rig.pose.bones[name+'ForeArm']
    start=a.head.copy();goal=Vector(target);d=goal-start;dist=min(d.length,a.bone.length+b.bone.length-.3);axis=d.normalized()
    along=(a.bone.length**2-b.bone.length**2+dist**2)/(2*dist)
    height=math.sqrt(max(0,a.bone.length**2-along**2))
    hint=Vector((1 if side=='L' else -1,1.4,-.8));bend=(hint-axis*hint.dot(axis)).normalized()
    elbow=start+axis*along+bend*height;aim(name+'Arm',elbow);aim(name+'ForeArm',start+axis*dist)

def lerp_seq(points,p):
    keys=[0,.20,.34,.58,.72,1]
    for i in range(len(keys)-1):
        if p<=keys[i+1]:
            u=max(0,(p-keys[i])/(keys[i+1]-keys[i]));a=Vector(points[i]);b=Vector(points[i+1])
            prev=Vector(points[max(0,i-1)]);nxt=Vector(points[min(len(points)-1,i+2)])
            m0=(b-prev)*.33 if i else Vector((0,0,0));m1=(nxt-a)*.33 if i<len(points)-2 else Vector((0,0,0))
            return (2*u**3-3*u**2+1)*a+(u**3-2*u**2+u)*m0+(-2*u**3+3*u**2)*b+(u**3-u**2)*m1
    return Vector(points[-1])

R=(-23,-4,118);L=(24,3,104)
gestures={
 'CastMaskFlick':([R,(-16,-8,113),(-7,-16,133),(-20,-27,143),(-25,-18,135),R],[L,(18,2,112),(9,-9,128),(14,-20,138),(21,-10,122),L]),
 'CastMaskTurn':([R,(-25,-1,121),(-5,-15,138),(8,-23,143),(-10,-22,127),R],[L,(20,4,109),(19,-7,123),(24,-21,139),(23,-7,117),L]),
 'CastTwinSweep':([R,(-8,-12,128),(4,-13,142),(-29,-14,145),(-28,-4,131),R],[L,(7,-12,128),(-5,-15,142),(28,-15,143),(27,0,121),L]),
 'CastTwinCross':([R,(-25,-4,124),(-24,-15,146),(8,-25,138),(-4,-18,130),R],[L,(24,-2,122),(26,-15,143),(-8,-26,138),(4,-16,122),L]),
 'CastFinaleLift':([R,(-15,-9,120),(-10,-16,149),(-14,-4,167),(-23,-17,152),R],[L,(13,-7,118),(10,-13,146),(16,-5,160),(26,-12,143),L]),
 'CastFinaleThrow':([R,(-18,-5,120),(-21,2,157),(-5,-26,150),(-20,-23,133),R],[L,(21,-2,110),(20,-12,137),(26,-21,145),(21,-7,119),L]),
 'CastCardFan':([R,(-12,-7,118),(-10,-18,139),(-28,-18,141),(-26,-10,126),R],[L,(20,-1,111),(8,-14,130),(21,-20,134),(25,-3,117),L]),
 'BasicSlash':([R,(-23,3,121),(-26,-8,138),(19,-25,130),(8,-22,122),R],[L,L,(17,-3,118),(22,-5,115),L,L]),
 'Thrust':([R,(-17,3,123),(-15,-3,137),(-13,-29,139),(-19,-22,133),R],[L,L,(18,-4,116),(20,-8,114),L,L]),
 'Card':([R,(-18,-2,117),(-11,-14,133),(-24,-27,135),(-26,-15,126),R],[L,L,(15,-4,113),(21,-9,119),L,L]),
 'Parry':([R,(-12,-12,125),(-6,-24,134),(-8,-25,140),(-17,-15,132),R],[L,(14,-10,122),(8,-21,137),(9,-23,139),(18,-13,127),L])
}
clips=[('BattleIdle',2.4),('BasicSlash',.70),('Thrust',.70),('Card',.70),('Parry',.60),('Hit',.42),('CastPrepare',.70)]+[(k,.68 if 'Mask' in k or k=='CastCardFan' else .90 if 'Twin' in k else 1.12) for k in list(gestures)[:7]]

def pose(clip,p):
    for b in rig.pose.bones:b.matrix_basis.identity();b.rotation_mode='QUATERNION'
    idle=clip=='BattleIdle';wave=math.sin(p*math.tau)
    action=math.sin(p*math.pi)**2 if not idle else 0
    twist=(18 if clip in ('BasicSlash','CastTwinSweep','CastMaskTurn') else -10)*math.sin(p*math.tau)*action
    turn('Spine02',-1.2+2.4*action,twist*.20)
    turn('Spine01',-2*action,twist*.35)
    turn('Spine',(-3*action if 'Finale' in clip else 4*action)+(wave*.75 if idle else 0),twist*.45)
    turn('Head',-1+action*2,-twist*.30)
    bpy.context.view_layer.update()
    pair=gestures.get(clip,gestures['CastCardFan'] if clip=='CastPrepare' else None)
    if pair:arm('R',lerp_seq(pair[0],p));arm('L',lerp_seq(pair[1],p))
    elif idle:arm('R',Vector(R)+Vector((0,.35*wave,.55*wave)));arm('L',Vector(L)+Vector((0,.25*wave,.45*wave)))
    if clip=='Hit':turn('Spine',-9*math.sin(p*math.pi),0,3*math.sin(p*math.pi))
    for side,sign in [('L',1),('R',-1)]:
        follow=math.sin(max(0,p-.075)*math.tau)*action
        turn('Coat.'+side,(wave*.8 if idle else -11*follow),0,sign*(.8*wave if idle else 4*follow))
        turn('CoatTip.'+side,(wave*1.5 if idle else -16*math.sin(max(0,p-.12)*math.tau)*action),0,sign*1.7*wave)
        turn('Ribbon.'+side,2*wave if idle else -13*follow,sign*2*wave)

for name,duration in clips:
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data_create().action=action
    count=round(duration*FPS)
    for f in range(count+1):
        bpy.context.scene.frame_set(f);pose(name,f/count)
        for bone in rig.pose.bones:
            bone.keyframe_insert('rotation_quaternion',frame=f,group=bone.name);bone.keyframe_insert('location',frame=f,group=bone.name)
rig.animation_data.action=bpy.data.actions['BattleIdle'];bpy.context.scene.frame_set(0)
bpy.context.scene.render.fps=FPS;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=144
DOC.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
for img in bpy.data.images:
    if img.source=='FILE':img.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(DOC/'HeroRefined-v1.blend'))
bpy.ops.export_scene.fbx(filepath=str(OUT/'HeroRefined.fbx'),object_types={'ARMATURE','MESH'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,bake_anim_step=1,path_mode='AUTO',axis_forward='-Z',axis_up='Y')
stats={'source':'existing licensed Meshy hero + original Blender tailoring','bones':len(rig.data.bones),'vertices':sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type=='MESH'),'removedOldCoatVertices':len(kill),'clips':[{'name':n,'seconds':d,'contactNormalized':None if n=='BattleIdle' else .58} for n,d in clips], 'outfits':['mistport-night','starlight-magician','midnight-carnival'],'sharedRig':True,'sharedAnimation':True,'userVisualApproval':False}
(DOC/'manifest.json').write_text(json.dumps(stats,indent=2)+'\n')
print('REFINED_HERO_COMPLETE',stats['vertices'],len(clips))
