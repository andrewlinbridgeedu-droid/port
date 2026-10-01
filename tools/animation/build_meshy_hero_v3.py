"""Editable, skinned Meshy-based hero; three actual outfits, one cast library.

Blender -b --python tools/animation/build_meshy_hero_v3.py -- <repository>
Coordinates are centimetres, +Y is the back. The user's original is read only.
ImageGen supplies flat brocade albedos; every visible part is real 3D geometry.
"""
import bpy, bmesh, math, json, sys, hashlib, random, shutil, os
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
DOC=ROOT/'docs/development/hero-refinement-20261001/v3'
OUT=ROOT/'UnityBattleSource/Assets/Resources/CombatTempo/RefinedHeroV3'
SOURCE=ROOT/'docs/development/hero-refinement-20261001/meshy-source/original.glb'
DOC.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
base=next(o for o in bpy.context.scene.objects if o.type=='MESH')
transform=base.matrix_world.copy()
for v in base.data.vertices:v.co=(transform@v.co+Vector((0,0,1)))*87.5
base.matrix_world=Matrix.Identity(4)
source_mat=base.data.materials[0]
atlas=next(n.image for n in source_mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image.name=='base_color')
normal=next(n.image for n in source_mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image.name=='normal')
atlas.filepath_raw=str(OUT/'MeshySkin.png');atlas.file_format='PNG';atlas.save()

def mat(name,color,metal=0,rough=.6,texture=None):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    n=m.node_tree.nodes;l=m.node_tree.links;bs=n.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough
    bs.inputs['Metallic'].default_value=0
    bs.inputs['Roughness'].default_value=.94
    bs.inputs['Specular IOR Level'].default_value=0
    if texture:
        t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(texture),check_existing=True)
        l.new(t.outputs['Color'],bs.inputs['Base Color'])
        # Painted weave: coloured gold thread stays matte alongside dyed cloth.
        sep=n.new('ShaderNodeSeparateColor');l.new(t.outputs['Color'],sep.inputs[0])
        ramp=n.new('ShaderNodeMapRange');ramp.inputs['From Min'].default_value=.24;ramp.inputs['From Max'].default_value=.68
        ramp.inputs['To Min'].default_value=.02;ramp.inputs['To Max'].default_value=.60
        l.new(sep.outputs['Red'],ramp.inputs['Value'])
        # Gold remains coloured embroidery; no reflective thread layer in v3.
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.025;bump.inputs['Distance'].default_value=.025
        l.new(t.outputs['Color'],bump.inputs['Height']);l.new(bump.outputs['Normal'],bs.inputs['Normal'])
    if not metal:
        bs.inputs['Sheen Weight'].default_value=0
        bs.inputs['Specular IOR Level'].default_value=0
        noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=180
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.09;bump.inputs['Distance'].default_value=.012
        l.new(noise.outputs['Fac'],bump.inputs['Height'])
        if not texture:l.new(bump.outputs['Normal'],bs.inputs['Normal'])
    return m

skin=mat('V3 Common Skin',(1,1,1),rough=.72)
t=skin.node_tree.nodes.new('ShaderNodeTexImage');t.image=atlas
skin.node_tree.links.new(t.outputs['Color'],skin.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
source_leather=mat('V3 Common LeatherAtlas',(1,1,1),rough=.94,texture=OUT/'MeshySkin.png')
leather=mat('V3 Common Leather',(.004,.003,.007),rough=.53)
hair=mat('V3 Common Hair',(.019,.013,.027),rough=.57)
hair_soft=mat('V3 Common HairRidges',(.032,.022,.043),rough=.60)
for m in [hair,hair_soft,leather]:
    bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Specular IOR Level'].default_value=0;bs.inputs['Sheen Weight'].default_value=0
neck_skin=mat('V3 Common Neck',(.37,.24,.18),rough=.72)
gold=mat('V3 Gold',(.70,.43,.14),.76,.28)
ivory=mat('V3 Ivory',(.76,.68,.55),rough=.66)
styles={
 'night':dict(id='mistport-night',cloth=(.006,.003,.012),lining=(.13,.019,.26),sash=(.018,.25,.28),gem=(.29,.025,.52),length=72,flare=22,inner=.23),
 'starlight':dict(id='starlight-magician',cloth=(.78,.73,.60),lining=(.035,.072,.21),sash=(.025,.24,.31),gem=(.025,.27,.58),length=77,flare=18,inner=.20),
 'carnival':dict(id='midnight-carnival',cloth=(.007,.002,.006),lining=(.49,.025,.037),sash=(.44,.019,.027),gem=(.63,.031,.042),length=64,flare=26,inner=.29)
}
for key,s in styles.items():
    tex=DOC/'textures'/f'{key}-brocade.png';shutil.copy2(tex,OUT/f'{key}-brocade.png')
    s['clothmat']=mat(f'V3 {key} Cloth',s['cloth'],rough=.69)
    s['brocade']=mat(f'V3 {key} Brocade',s['cloth'],rough=.57,texture=tex)
    s['liningmat']=mat(f'V3 {key} Silk',s['lining'],rough=.42)
    s['sashmat']=mat(f'V3 {key} Ribbon',s['sash'],rough=.48)
    s['gemmat']=mat(f'V3 {key} Gem',s['gem'],.28,.18)

# UV-corner seams remain intact while geometric duplicates are welded.
bm=bmesh.new();bm.from_mesh(base.data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.012)
old_hair=[f for f in bm.faces if (f.calc_center_median().z>160 or
          (f.calc_center_median().z>148 and f.calc_center_median().y>7) or
          (f.calc_center_median().z>154 and abs(f.calc_center_median().x)>6.8))]
bmesh.ops.delete(bm,geom=old_hair,context='FACES')
loose=[v for v in bm.verts if not v.link_faces]
bmesh.ops.delete(bm,geom=loose,context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(base.data);bm.free()
base.data.normals_split_custom_set([(0,0,0)]*len(base.data.loops))
base.data.materials.clear()
for m in [skin,source_leather,styles['night']['clothmat']]:base.data.materials.append(m)
for p in base.data.polygons:
    c=sum((base.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
    exposed=(c.z>143) or (c.x>23 and 74<c.z<96) or (c.x<-25 and c.z>116)
    p.material_index=0 if exposed else 1 if c.z<95 else 2;p.use_smooth=True
base.name='Shared body source';base.select_set(True);bpy.context.view_layer.objects.active=base
sub=base.modifiers.new('Source sculpt smoothing','SUBSURF');sub.levels=1
bpy.ops.object.modifier_apply(modifier=sub.name)
base.data.normals_split_custom_set([(0,0,0)]*len(base.data.loops))

# One fitted armature, shared by skin, hair and all three costume constructions.
data=bpy.data.armatures.new('MeshyHeroV3 shared skeleton');rig=bpy.data.objects.new('MeshyHeroV3',data)
bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig
rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
spec={
 'Hips':((0,5,94),(0,5,105),None),
 'Spine02':((0,5,105),(0,6,118),'Hips'),
 'Spine01':((0,6,118),(0,7,130),'Spine02'),
 'Spine':((0,7,130),(0,8,141),'Spine01'),
 'neck':((0,8,141),(0,8,152),'Spine'),
 'Head':((0,8,152),(0,8,173),'neck')
}
for side,sign in [('Left',1),('Right',-1)]:
    shoulder=(sign*15,8,140);elbow=(25,9,115) if sign==1 else (-23,6,114)
    wrist=(25.5,2,90) if sign==1 else (-28,-14,127)
    hand=(26,1,80) if sign==1 else (-31,-18,137)
    spec[side+'Shoulder']=((sign*3,8,140),shoulder,'Spine')
    spec[side+'Arm']=(shoulder,elbow,side+'Shoulder')
    spec[side+'ForeArm']=(elbow,wrist,side+'Arm')
    spec[side+'Hand']=(wrist,hand,side+'ForeArm')
    spec[side+'UpLeg']=((sign*8,5,94),(sign*12,4,49),'Hips')
    spec[side+'Leg']=((sign*12,4,49),(sign*16,6,12),side+'UpLeg')
    spec[side+'Foot']=((sign*16,6,12),(sign*16,-6,3),side+'Leg')
    spec[side+'Toe']=((sign*16,-6,3),(sign*16,-14,3),side+'Foot')
for side,sign in [('L',1),('R',-1)]:
    spec['Coat.'+side]=((sign*10,18,102),(sign*23,23,63),'Hips')
    spec['CoatTip.'+side]=((sign*23,23,63),(sign*34,25,29),'Coat.'+side)
    spec['Ribbon.'+side]=((sign*14,18,104),(sign*20,23,65),'Hips')
for name,(a,b,parent) in spec.items():
    bone=data.edit_bones.new(name);bone.head=a;bone.tail=b
    if parent:bone.parent=data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
rig.matrix_world=Matrix.Scale(.01,4)

def spine_w(z):
    keys=[(94,'Hips'),(110,'Spine02'),(124,'Spine01'),(138,'Spine'),(148,'neck'),(158,'Head')]
    if z<=keys[0][0]:return {'Hips':1}
    for i in range(len(keys)-1):
        a,n=keys[i];b,k=keys[i+1]
        if z<=b:t=(z-a)/(b-a);return {n:1-t,k:t}
    return {'Head':1}
def capsule(p,a,b):
    a=Vector(a);b=Vector(b);t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared))
    return (p-a.lerp(b,t)).length
def source_w(p):
    if p.z>149:return {'Head':1}
    arm_region=(p.z>112 and abs(p.x)>18) or (p.x>21 and 78<p.z<112) or (p.x<-23 and p.z>111)
    if arm_region:
        side='Left' if p.x>0 else 'Right'
        names=[side+'Arm',side+'ForeArm',side+'Hand']
        ds=[capsule(p,*spec[n][:2]) for n in names]
        weights=[math.exp(-d*d/27) for d in ds]
        if sum(weights)<1e-10:return {names[ds.index(min(ds))]:1}
        total=sum(weights);return {n:w/total for n,w in zip(names,weights) if w/total>.001}
    if p.z<96 and abs(p.x)<24:
        side='Left' if p.x>0 else 'Right'
        if p.z<16:return {side+'Foot':1}
        if p.z<38:return {side+'Leg':1}
        if p.z<59:
            t=(p.z-38)/21;return {side+'Leg':1-t,side+'UpLeg':t}
        if p.z<85:return {side+'UpLeg':1}
        t=(p.z-85)/11;return {side+'UpLeg':1-t,'Hips':t}
    return spine_w(p.z)
parts=[]
def skin_object(o,weights):
    o.parent=rig;o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Identity(4)
    for name in set(n for w in weights for n in w):
        g=o.vertex_groups.new(name=name)
        for i,w in enumerate(weights):
            if w.get(name,0)>0:g.add([i],w[name],'REPLACE')
    mod=o.modifiers.new('Shared armature deformation','ARMATURE');mod.object=rig
    parts.append(o);return o
skin_object(base,[source_w(v.co) for v in base.data.vertices])

def mesh(name,vs,fs,material,weights,uvs=None):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update()
    bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(d);bm.free()
    if uvs:
        layer=d.uv_layers.new(name='UVMap')
        for p in d.polygons:
            for li in p.loop_indices:layer.data[li].uv=uvs[d.loops[li].vertex_index]
    for p in d.polygons:p.use_smooth=True
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(material)
    return skin_object(o,weights)
def tube(name,points,radius,material,weights=None,sides=8):
    vs=[];fs=[];ws=[]
    for i,p in enumerate(points):
        p=Vector(p);axis=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
        tangent=axis.cross(Vector((0,1,0)))
        if tangent.length<.001:tangent=axis.cross(Vector((1,0,0)))
        tangent.normalize();bi=axis.cross(tangent).normalized()
        r=radius(i/(len(points)-1)) if callable(radius) else radius
        for j in range(sides):
            a=j*math.tau/sides;vs.append(p+r*(math.cos(a)*tangent+math.sin(a)*bi));ws.append(weights[i] if weights else spine_w(p.z))
            if i:k=(i-1)*sides+j;fs.append((k,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j))
    fs.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,material,ws)
def gem(name,p,size,material,w):
    p=Vector(p);vs=[p+Vector((0,0,size)),p+Vector((size*.58,0,0)),p+Vector((0,0,-size)),p+Vector((-size*.58,0,0)),p+Vector((0,size*.46,0))]
    return mesh(name,vs,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,3,2,1)],material,[w]*5)
def closed_cloth(o,thickness=.20):
    mod=o.modifiers.new('Two sided cloth thickness','SOLIDIFY');mod.thickness=thickness
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def back_surface(x,z):
    hit,p,n,i=base.ray_cast(Vector((x,70,z)),Vector((0,-1,0)))
    return Vector((x,p.y+.55,z)) if hit else Vector((x,9,z))

# Sculpted, swept hair bundles: closed tapered sections with a curved ridge.
# Their silhouette is authored afresh rather than preserving AI triangular chips.
vs=[];fs=[]
for j in range(25):
    a=j/24*math.pi
    for i in range(41):
        b=i/40*math.tau
        vs.append((.2+8.55*math.sin(a)*math.cos(b),7.2+7.70*math.sin(a)*math.sin(b),162+10.75*math.cos(a)))
        if i and j:
            ix=(j-1)*41+i-1
            # Keep the supplied front face visible below the fringe.
            c=(Vector(vs[ix])+Vector(vs[ix+1])+Vector(vs[ix+42])+Vector(vs[ix+41]))/4
            if not (c.y<5 and c.z<160):fs.append((ix,ix+1,ix+42,ix+41))
mesh('Common closed scalp',vs,fs,hair,[{'Head':1}]*len(vs))
vs=[];fs=[];ws=[]
for j in range(9):
    z=141+j*1.75;r=3.8-.035*j
    for i in range(33):
        a=i/32*math.tau;vs.append((r*math.cos(a),7.5+r*.88*math.sin(a),z));ws.append(spine_w(z))
        if i and j:ix=(j-1)*33+i-1;fs.append((ix,ix+1,ix+34,ix+33))
mesh('Common closed neck',vs,fs,neck_skin,ws)
random.seed(17021)
for ring,count in [(0,11),(1,15),(2,16),(3,13),(4,13),(5,12)]:
    for k in range(count):
        a=k/count*math.tau+ring*.31+random.uniform(-.13,.13)
        if ring>=4 and math.sin(a)<.10:continue
        start=.04+ring*.30;length=.57+random.random()*.30
        width=(.95 if ring>=4 else 1.40)+random.random()*(.55 if ring>=4 else .82);vs=[];fs=[];rows=[]
        for i in range(19):
            t=i/18;polar=start+t*length
            angle=a+(.28+.29*math.sin(a*2+ring))*(t*t)
            radial=Vector((math.sin(polar)*math.cos(angle),math.sin(polar)*math.sin(angle),math.cos(polar)))
            # Ellipsoidal scalp, varied lift and flicked tips; back nape locks overlap.
            c=Vector((.2+9.0*radial.x,7.2+8.1*radial.y,162+11.2*radial.z))
            c+=radial*(.15+.55*math.sin(t*math.pi)+(1.9+1.3*math.sin(a*3+ring))*t**7)
            tangent=Vector((-math.sin(angle),math.cos(angle),0))
            normal=Vector((radial.x,radial.y,radial.z*.7)).normalized()
            w=width*math.sin((.08+.92*t)*math.pi)**.7+.02
            depth=.23*math.sin(t*math.pi)**.6+.025
            rows.append((c,tangent,normal,w,depth))
            for j in range(10):
                q=j/10*math.tau
                vs.append(c+tangent*(w*math.cos(q))+normal*(depth*math.sin(q)))
                if i:ix=(i-1)*10+j;fs.append((ix,(i-1)*10+(j+1)%10,i*10+(j+1)%10,i*10+j))
        fs.extend([tuple(range(9,-1,-1)),tuple(180+j for j in range(10))])
        mesh('Common swept hair',vs,fs,hair,[{'Head':1}]*len(vs))
        for u in [-.34,.22]:
            pts=[c+tg*w*u+n*(d*math.sqrt(1-u*u)+.012) for c,tg,n,w,d in rows]
            tube('Common hair ridges',pts,lambda t:.022*math.sin(t*math.pi)+.006,hair_soft,[{'Head':1}]*len(pts),4)

# Fine irregular flyaways break the smooth scalp silhouette without noisy grooves.
for k in range(24):
    a=k/24*math.tau+.19*math.sin(k*1.73);start=.55+(k%5)*.19
    pts=[]
    for j in range(19):
        t=j/18;polar=start+t*.64;angle=a+.28*t+.12*math.sin(t*math.pi)
        radial=Vector((math.sin(polar)*math.cos(angle),math.sin(polar)*math.sin(angle),math.cos(polar)))
        p=Vector((.2+9.1*radial.x,7.2+8.25*radial.y,162+11.3*radial.z))
        p+=radial*(.3+3.0*t**5);pts.append(p)
    tube('Common fine flyaways',pts,lambda t:.095*(1-t)**.7+.008,hair_soft,[{'Head':1}]*len(pts),5)

# Boot construction remains shared; small raised leather bands and metal rims
# retain detail in the rear view without reusing a painted silhouette.
for side,sign in [('Left',1),('Right',-1)]:
    for height in [15,21]:
        band=[v.co for v in base.data.vertices if v.co.x*sign>5 and abs(v.co.z-height)<3]
        center=sum(band,Vector())/len(band)
        vs=[];fs=[]
        for j in range(4):
            for i in range(41):
                a=i/40*math.tau;radial=Vector((math.cos(a),math.sin(a),0))
                origin=Vector((center.x,center.y,height+j*.60))+radial*13
                hit,p,n,index=base.ray_cast(origin,-radial)
                vs.append(p+radial*.16 if hit else Vector((center.x,center.y,height+j*.60))+radial*4)
                if i and j:ix=(j-1)*41+i-1;fs.append((ix,ix+1,ix+42,ix+41))
        closed_cloth(mesh('Common boot straps',vs,fs,leather,[source_w(Vector(v)) for v in vs]),.14)
        pts=[vs[3*41+i] for i in range(41)]
        tube('Common boot metal rims',pts,.10,gold,[source_w(Vector(p)) for p in pts])
        p=Vector(pts[10])+Vector((0,.25,-.6))
        gem('Common boot buckles',p,.65,gold,source_w(p))

def tail_w(side,t):
    b=min(1,t*3);c=max(0,(t-.38)/.62)*.8
    return {'Hips':1-b,'Coat.'+side:b*(1-c),'CoatTip.'+side:b*c}
def tail_pos(style,side,u,t):
    s=styles[style];sign=1 if side=='L' else -1
    flare=s['flare'];length=s['length']
    # A narrow waist unfolds into soft hanging pleats, with a rolled inner lapel.
    x=sign*(2.6+u*(11+flare*t*.82)+9*t+1.1*math.sin(t*math.pi))
    wave=math.sin(u*math.pi*3.1+.4+1.5*t)
    y=17.5+6.7*t+(1.2+4.6*t)*wave+1.2*t*t*u
    # Curl the centre edge toward the viewer to expose the continuous inner silk.
    y+=3.8*math.exp(-u*9)*(t**.8)
    z=102-length*t+9*math.sin(math.pi*u)*t-4*u*t*t
    if style=='carnival':z+=5*math.sin(u*math.pi*2)*t*t+(3 if side=='L' else 0)*t
    if style=='starlight':x+=sign*1.5*math.sin(u*math.pi)*t
    return Vector((x,y,z))

for key,s in styles.items():
    prefix='Outfit-'+key+'-'
    # Duplicate the fitted source jacket, retaining its sculpted folds; shared skin weights.
    jacket=base.copy();jacket.data=base.data.copy();bpy.context.collection.objects.link(jacket);jacket.name=prefix+'Tailored jacket'
    bm=bmesh.new();bm.from_mesh(jacket.data)
    delete=[]
    for f in bm.faces:
        c=f.calc_center_median()
        if c.z<97 or c.z>147 or (c.x>23 and c.z<96) or (c.x<-25 and c.z>118):delete.append(f)
    bmesh.ops.delete(bm,geom=delete,context='FACES');bm.to_mesh(jacket.data);bm.free()
    jacket.data.materials.clear();jacket.data.materials.append(s['brocade'] if key!='carnival' else s['clothmat'])
    for p in jacket.data.polygons:p.material_index=0
    if key!='carnival':
        layer=jacket.data.uv_layers.active
        for p in jacket.data.polygons:
            for li in p.loop_indices:
                v=jacket.data.vertices[jacket.data.loops[li].vertex_index].co
                layer.data[li].uv=(.03+(v.x/70+.5)*.38,.69+max(0,min(1,(v.z-97)/50))*.28)
    # The small expansion avoids coincident jacket surfaces on the preserved body.
    for v in jacket.data.vertices:
        v.co.x*=1.008;v.co.y*=1.018
    parts.append(jacket)
    # A collar that follows the actual neck, with embroidered upper lip.
    vs=[];fs=[];ws=[];uv=[]
    for j in range(9):
        h=j/8
        for i in range(49):
            a=i/48*math.tau;r=7.7+1.1*h
            vs.append((r*math.cos(a),7.5+r*math.sin(a),141.5+8*h+.45*math.cos(a*2)))
            ws.append({'neck':1});uv.append((i/48,1-h))
            if i and j:p=(j-1)*49+i-1;fs.append((p,p+1,p+50,p+49))
    closed_cloth(mesh(prefix+'Raised silk collar',vs,fs,s['liningmat'],ws,uv),.24)
    tube(prefix+'Gold collar lip',[vs[8*49+i] for i in range(49)],.16,gold,[{'neck':1}]*49)
    for side,sign in [('L',1),('R',-1)]:
        # One continuous closed outer surface and a silk roll, joined to waist.
        for name,u0,u1,offset,material in [('Brocade tails',s['inner'],1,.35,s['brocade']),('Silk inner roll',0,s['inner']+.045,.12,s['liningmat'])]:
            vs=[];fs=[];ws=[];uv=[]
            for j in range(55):
                t=j/54
                for i in range(29):
                    u=u0+(u1-u0)*i/28;p=tail_pos(key,side,u,t);p.y+=offset
                    vs.append(p);ws.append(tail_w(side,t));uv.append((i/28,1-t))
                    if i and j:ix=(j-1)*29+i-1;fs.append((ix,ix+1,ix+30,ix+29))
            closed_cloth(mesh(prefix+name+side,vs,fs,material,ws,uv),.22)
        for u in [0,s['inner'],1]:
            pts=[tail_pos(key,side,u,i/64)+Vector((0,.65,0)) for i in range(65)]
            tube(prefix+'Gold bound seams',pts,.15,gold,[tail_w(side,i/64) for i in range(65)])
        pts=[tail_pos(key,side,i/48,1)+Vector((0,.65,0)) for i in range(49)]
        tube(prefix+'Curved gold hem',pts,.16,gold,[tail_w(side,1)]*49)
        point=tail_pos(key,side,1,1)+Vector((0,.7,-1.7))
        gem(prefix+'Hem crystal',point,1.35,s['gemmat'],tail_w(side,1))
        tube(prefix+'Crystal bezel',[point+Vector((x,.2,z)) for x,z in [(0,1.7),(1.05,0),(0,-1.7),(-1.05,0),(0,1.7)]],.14,gold,[tail_w(side,1)]*5)
        # Yoke, curved princess seams, inset shoulder embroidery and metal waist clasps.
        pts=[back_surface(sign*(4.8+6.5*t-1.2*math.sin(t*math.pi)),104+33*t) for t in [i/48 for i in range(49)]]
        tube(prefix+'Princess seams',pts,.095,gold)
        pts=[back_surface(sign*(2+13*t),136.5-4.4*math.sin(t*math.pi*.72)) for t in [i/48 for i in range(49)]]
        tube(prefix+'Gold yoke',pts,.13,gold)
        # Small filled filigree leaves, with raised ridges and curved tips.
        for leaf in range(6):
            x0=sign*(3.7+leaf*1.7);z0=136.6-leaf*.30;vs=[];fs=[];ws=[]
            for j in range(19):
                t=j/18;x=x0+sign*(1.7*t+.5*math.sin(t*math.pi));z=z0+2.1*t
                width=.42*math.sin(t*math.pi)**.8
                for column in [-1,0,1]:
                    p=back_surface(x+column*width,z)+Vector((0,.35+(.14 if column==0 else 0),0))
                    vs.append(p);ws.append(spine_w(z))
                if j:ix=(j-1)*3;fs.extend([(ix,ix+1,ix+4,ix+3),(ix+1,ix+2,ix+5,ix+4)])
            closed_cloth(mesh(prefix+'Yoke filigree leaves',vs,fs,gold,ws),.06)
        # Delicate sewn acanthus scrolls, conforming to the jacket rather than large metal rods.
        for row in range(4):
            pts=[]
            for j in range(41):
                t=j/40;angle=t*math.pi*2.15;radius=1.8*(1-.74*t)
                x=sign*(7.3+radius*math.cos(angle));z=121.5+row*3.35+radius*.72*math.sin(angle)
                pts.append(back_surface(x,z)+Vector((0,.15,0)))
            tube(prefix+'Fine sewn scrolls',pts,.065,gold,sides=5)
        pts=[back_surface(sign*(4.2+.8*math.sin(t*math.pi*3)),115+20*t)+Vector((0,.12,0)) for t in [j/64 for j in range(65)]]
        tube(prefix+'Sewn vine stems',pts,.060,gold,sides=5)
        # Shaped brocade shoulder panels follow the back surface, never floating plates.
        vs=[];fs=[];ws=[];uv=[]
        for j in range(16):
            t=j/15
            for i in range(17):
                u=i/16;x=sign*(9+7*u);z=137-7*t+1.9*math.sin(u*math.pi)
                p=back_surface(x,z)+Vector((0,.19,0));vs.append(p);ws.append(spine_w(z));uv.append((u,.60+.4*t))
                if i and j:ix=(j-1)*17+i-1;fs.append((ix,ix+1,ix+18,ix+17))
        mesh(prefix+'Embroidered yoke',vs,fs,s['brocade'],ws,uv)
        for z in [104,107.5]:
            p=back_surface(sign*5.5,z)
            gem(prefix+'Waist clasp',p,1.35,gold,spine_w(z));gem(prefix+'Waist inset',p+Vector((0,.42,0)),.60,s['gemmat'],spine_w(z))
        # Alternate loops make a real linked chain, weighted along the skirt.
        for k in range(17):
            t=.025+k*.023;u=.73+.065*math.sin(k/17*math.pi)
            c=tail_pos(key,side,u,t)+Vector((0,1.2,0))
            pts=[]
            for i in range(17):
                a=i/16*math.tau
                pts.append(c+Vector((.53*math.cos(a),.40*math.sin(a)*(k%2),.77*math.sin(a))))
            tube(prefix+'Linked waist chain',pts,.095,gold,[tail_w(side,t)]*17,5)
        gem(prefix+'Chain pendant',c+Vector((0,.45,-1.9)),1.3,s['gemmat'],tail_w(side,t))
        # Flowing ribbon construction differs between all three garments.
        ribbon_count=2 if key=='carnival' else 0 if key=='night' and side=='R' else 1
        for ribbon in range(ribbon_count):
            vs=[];fs=[];ws=[];uv=[]
            for j in range(35):
                t=j/34;angle=t*(1.7 if key=='carnival' else 1.1)+ribbon*.8
                for i in range(7):
                    u=i/6;w=(2.3 if key=='night' else 3.4)*(u-.5)
                    vs.append((sign*(14+10*t+ribbon*3+w*math.cos(angle)),20+5*t+3.2*math.sin(t*math.pi*1.4)+w*math.sin(angle),104-(43 if key=='night' else 54)*t+w*.35))
                    ws.append({'Hips':1-t,'Ribbon.'+side:t});uv.append((u,1-t))
                    if i and j:ix=(j-1)*7+i-1;fs.append((ix,ix+1,ix+8,ix+7))
            closed_cloth(mesh(prefix+'Folded ribbon',vs,fs,s['sashmat'],ws,uv),.10)
        # Broad flared cuff and ivory pleat are aligned to this arm's rest pose.
        name=('Left' if sign==1 else 'Right')+'ForeArm';a=Vector(spec[name][0]);b=Vector(spec[name][1])
        axis=(b-a).normalized();u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized()
        # Continuous sleeve support closes the old Meshy cuff cut. Its shape is
        # fitted to the same rest joint and shares the forearm's deformation.
        vs=[];fs=[];ws=[];uv=[]
        for j in range(19):
            t=j/18*.76
            for i in range(41):
                ang=i/40*math.tau;r=4.8-.8*t+.14*math.sin(ang*7+t*14)
                vs.append(a.lerp(b,t)+r*(u*math.cos(ang)+v*math.sin(ang)))
                blend=max(0,1-t/.20)*.12
                ws.append({name:1-blend,('Left' if sign==1 else 'Right')+'Arm':blend})
                uv.append((.03+i/40*.20,.76+t*.22))
                if i and j:ix=(j-1)*41+i-1;fs.append((ix,ix+1,ix+42,ix+41))
        closed_cloth(mesh(prefix+'Fitted continuous sleeve',vs,fs,s['brocade'] if key!='carnival' else s['clothmat'],ws,uv),.16)
        center=a.lerp(b,.85)
        for title,off,height,material in [('Brocade gauntlet',-2,6.2,s['brocade']),('Ivory pleated cuff',3.9,2.2,ivory)]:
            vs=[];fs=[];ws=[];uv=[]
            for j in range(13):
                t=j/12
                for i in range(41):
                    ang=i/40*math.tau;r=4.1+1.8*t+.27*math.sin(ang*10)*(t if 'Ivory' in title else .3)
                    vs.append(center+axis*(off+height*t)+r*(u*math.cos(ang)+v*math.sin(ang)))
                    ws.append({name:1});uv.append((i/40,1-t))
                    if i and j:ix=(j-1)*41+i-1;fs.append((ix,ix+1,ix+42,ix+41))
            closed_cloth(mesh(prefix+title,vs,fs,material,ws,uv),.15)
            if 'Brocade' in title:tube(prefix+'Cuff piping',[vs[12*41+i] for i in range(41)],.15,gold,[{name:1}]*41)
        # Starlight has a separate short shoulder mantle; carnival has fringed epaulettes.
        if key=='starlight':
            vs=[];fs=[];ws=[];uv=[]
            for j in range(17):
                t=j/16
                for i in range(21):
                    q=i/20;x=sign*(5+16*q+2*t);z=141-9*t-3*q
                    p=back_surface(x,z);p.y+=.7+1.8*t
                    vs.append(p);ws.append(spine_w(z));uv.append((q,1-t))
                    if i and j:ix=(j-1)*21+i-1;fs.append((ix,ix+1,ix+22,ix+21))
            closed_cloth(mesh(prefix+'Short stellar mantle',vs,fs,s['brocade'],ws,uv),.20)
        if key=='carnival':
            for k in range(12):
                p=back_surface(sign*(10+k*.56),137-k*.24)
                pts=[p+Vector((sign*.18*math.sin(t*math.pi),.1+1.1*t,-4.2*t)) for t in [i/12 for i in range(13)]]
                tube(prefix+'Epaulette fringe',pts,lambda t:.13*(1-.6*t),gold,[{'Spine':1}]*13,5)
    p=back_surface(0,134)
    gem(prefix+'Back stone',p+Vector((0,.5,0)),1.50,s['gemmat'],{'Spine':1})
    tube(prefix+'Back bezel',[p+Vector((x,.7,z)) for x,z in [(0,2.1),(1.4,0),(0,-2.1),(-1.4,0),(0,2.1)]],.16,gold,[{'Spine':1}]*5)
    for k in range(9):
        pts=[p+Vector(((k-4)*.09,.5, -2-4*t)) for t in [i/12 for i in range(13)]]
        tube(prefix+'Back tassel',pts,.075,gold,[{'Spine':1}]*13,5)

# The selected jacket is the surface, rather than two coincident garments.
# This also prevents the night-coloured source cloth from showing through white sleeves.
bm=bmesh.new();bm.from_mesh(base.data)
covered=[]
for f in bm.faces:
    c=f.calc_center_median()
    garment=97<=c.z<=147 and not (c.x<-25 and c.z>118)
    if abs(c.x)>20 and c.z>90:
        side='Left' if c.x>0 else 'Right';a=Vector(spec[side+'ForeArm'][0]);b=Vector(spec[side+'ForeArm'][1])
        t=(c-a).dot(b-a)/(b-a).length_squared
        if 0<=t<=.76 and capsule(c,a,b)<6.2:garment=True
    if garment:covered.append(f)
bmesh.ops.delete(bm,geom=covered,context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(base.data);bm.free()

# Merge only within an outfit and material. Hidden outfits share the same bones,
# but do not render; no per-outfit Animator or duplicate character instance.
for group in ['Common','Outfit-night-','Outfit-starlight-','Outfit-carnival-']:
    materials=set(m for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(group) for m in o.data.materials)
    for material in materials:
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(group) and len(o.data.materials)==1 and o.data.materials[0]==material]
        if not objects:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        objects[0].name=group+material.name

# Shared natural gesture curves. Fast release at .58; anticipation and return have
# distinct phases. Wrists, torso and cloth lag are authored, not separate clocks.
def turn(name,pitch=0,yaw=0,roll=0):
    b=rig.pose.bones[name];basis=b.bone.matrix_local.to_quaternion()
    q=Quaternion(Vector((1,0,0)),math.radians(pitch))@Quaternion(Vector((0,0,1)),math.radians(yaw))@Quaternion(Vector((0,1,0)),math.radians(roll))
    b.rotation_mode='QUATERNION';b.rotation_quaternion=basis.inverted()@q@basis
def aim(name,target):
    b=rig.pose.bones[name];direction=Vector(target)-b.head
    q=(b.tail-b.head).normalized().rotation_difference(direction.normalized())
    m=(q@b.matrix.to_quaternion()).to_matrix().to_4x4();m.translation=b.head;b.matrix=m
    bpy.context.view_layer.update()
def arm(side,target):
    side='Left' if side=='L' else 'Right';a=rig.pose.bones[side+'Arm'];b=rig.pose.bones[side+'ForeArm']
    start=a.head.copy();d=Vector(target)-start;dist=max(1,min(d.length,a.bone.length+b.bone.length-.2));axis=d.normalized()
    along=(a.bone.length**2-b.bone.length**2+dist**2)/(2*dist);h=math.sqrt(max(0,a.bone.length**2-along**2))
    rest_elbow=Vector(spec[side+'Arm'][1])-Vector(spec[side+'Arm'][0])
    hint=rest_elbow-axis*rest_elbow.dot(axis)
    if hint.length<.01:hint=Vector((1 if side=='Left' else -1,0,-.65))
    bend=hint.normalized()
    aim(side+'Arm',start+axis*along+bend*h);aim(side+'ForeArm',start+axis*dist)
def curve(points,p):
    keys=[0,.20,.34,.58,.72,1]
    for i in range(5):
        if p<=keys[i+1]:
            u=max(0,(p-keys[i])/(keys[i+1]-keys[i]));a=Vector(points[i]);b=Vector(points[i+1]);prev=Vector(points[max(0,i-1)]);nxt=Vector(points[min(5,i+2)])
            m0=(b-prev)*.33 if i else Vector();m1=(nxt-a)*.33 if i<4 else Vector()
            return (2*u**3-3*u*u+1)*a+(u**3-2*u*u+u)*m0+(-2*u**3+3*u*u)*b+(u**3-u*u)*m1
    return Vector(points[-1])
R=(-28,-14,127);L=(25.5,2,90)
gestures={
 'CastMaskFlick':([R,(-18,-8,117),(-9,-16,132),(-22,-29,140),(-26,-19,132),R],[L,(20,0,106),(11,-9,123),(16,-21,132),(23,-9,113),L]),
 'CastMaskTurn':([R,(-25,-2,121),(-5,-15,137),(9,-24,141),(-11,-21,127),R],[L,(21,2,103),(20,-7,120),(25,-22,134),(24,-7,111),L]),
 'CastTwinSweep':([R,(-10,-12,128),(4,-14,142),(-30,-18,144),(-29,-5,131),R],[L,(9,-12,125),(-5,-16,139),(29,-19,139),(27,0,115),L]),
 'CastTwinCross':([R,(-25,-5,125),(-25,-17,145),(9,-27,137),(-5,-19,128),R],[L,(24,-2,114),(26,-17,141),(-9,-28,133),(5,-17,119),L]),
 'CastFinaleLift':([R,(-17,-8,122),(-11,-17,149),(-15,-6,165),(-24,-18,150),R],[L,(15,-7,112),(11,-14,142),(17,-7,157),(27,-13,137),L]),
 'CastFinaleThrow':([R,(-20,-5,122),(-22,1,155),(-6,-29,146),(-21,-23,130),R],[L,(22,-2,103),(21,-12,132),(27,-22,140),(22,-7,114),L]),
 'CastCardFan':([R,(-14,-7,120),(-11,-18,137),(-29,-20,140),(-27,-11,125),R],[L,(21,-1,106),(10,-14,125),(22,-21,129),(25,-3,110),L]),
 'BasicSlash':([R,(-23,2,122),(-27,-9,138),(20,-27,129),(9,-22,121),R],[L,L,(18,-3,112),(23,-5,110),L,L]),
 'Thrust':([R,(-18,2,123),(-16,-4,137),(-14,-31,138),(-20,-22,131),R],[L,L,(19,-4,110),(21,-8,109),L,L]),
 'Card':([R,(-19,-2,120),(-12,-15,131),(-25,-29,133),(-27,-16,125),R],[L,L,(16,-4,107),(22,-9,112),L,L]),
 'Parry':([R,(-14,-12,126),(-7,-25,134),(-9,-26,139),(-18,-15,131),R],[L,(16,-10,116),(10,-22,132),(11,-24,134),(20,-13,122),L])
}
clips=[('BattleIdle',2.4),('BasicSlash',.70),('Thrust',.70),('Card',.70),('Parry',.60),('Hit',.42),('CastPrepare',.70)]+[(n,.68 if 'Mask' in n or n=='CastCardFan' else .90 if 'Twin' in n else 1.12) for n in list(gestures)[:7]]
def pose(clip,p):
    for b in rig.pose.bones:b.matrix_basis.identity();b.rotation_mode='QUATERNION'
    idle=clip=='BattleIdle';wave=math.sin(p*math.tau);energy=math.sin(p*math.pi)**2 if not idle else 0
    twist=(17.5 if clip in ['BasicSlash','CastTwinSweep','CastMaskTurn'] else -12)*math.sin(p*math.tau)*energy
    rig.pose.bones['Hips'].location=Vector((.9*energy*math.sin(p*math.tau),0,-.38*energy))
    turn('Spine02',-1+2*energy,twist*.22);turn('Spine01',-1.6*energy,twist*.32)
    turn('Spine',(-2.5 if 'Finale' in clip else 3)*energy+(wave*.6 if idle else 0),twist*.46)
    turn('Head',-1+energy*1.5,-twist*.35);bpy.context.view_layer.update()
    pair=gestures.get(clip,gestures['CastCardFan'] if clip=='CastPrepare' else None)
    if pair:
        amplitude=1.10 if clip.startswith('Cast') else 1
        arm('R',Vector(R)+(curve(pair[0],p)-Vector(R))*amplitude)
        arm('L',Vector(L)+(curve(pair[1],p)-Vector(L))*amplitude)
    else:arm('R',Vector(R)+Vector((0,.3*wave,.45*wave)));arm('L',Vector(L)+Vector((0,.2*wave,.4*wave)))
    # A wrist unfurls at release, then settles; no stiff palm held through every cast.
    turn('RightHand',7.7*energy,-8.8*wave*energy,13.2*wave*energy)
    turn('LeftHand',-6.6*energy,8.8*wave*energy,-7.7*wave*energy)
    if clip=='Hit':turn('Spine',-8*math.sin(p*math.pi),0,3*math.sin(p*math.pi))
    for side,sign in [('L',1),('R',-1)]:
        follow=math.sin(max(0,p-.075)*math.tau)*energy
        turn('Coat.'+side,wave*.65 if idle else -8*follow,0,sign*(.6*wave if idle else 3*follow))
        turn('CoatTip.'+side,wave*1.2 if idle else -12*math.sin(max(0,p-.12)*math.tau)*energy,0,sign*1.4*wave)
        turn('Ribbon.'+side,1.5*wave if idle else -11*follow,sign*1.7*wave)
for name,duration in clips:
    act=bpy.data.actions.new(name);act.use_fake_user=True;rig.animation_data_create().action=act
    count=round(duration*60)
    for frame in range(count+1):
        bpy.context.scene.frame_set(frame);pose(name,frame/count)
        for b in rig.pose.bones:
            b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name);b.keyframe_insert('location',frame=frame,group=b.name)
rig.animation_data.action=bpy.data.actions['BattleIdle'];bpy.context.scene.frame_set(0)
scene=bpy.context.scene;scene.render.fps=60;scene.frame_start=0;scene.frame_end=144
for im in bpy.data.images:
    if im.source=='FILE':im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(DOC/'HeroMeshy-v3.blend'))
bpy.ops.export_scene.fbx(filepath=str(OUT/'HeroMeshyV3.fbx'),object_types={'MESH','ARMATURE'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,bake_anim_step=1,axis_forward='-Z',axis_up='Y',path_mode='AUTO')
stats={'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'sourceUnchanged':True,'bones':len(rig.data.bones),'verticesAllOutfits':sum(len(o.data.vertices) for o in scene.objects if o.type=='MESH'),'outfits':[s['id'] for s in styles.values()],'sharedSkeleton':True,'sharedClips':True,'clips':[{'name':n,'seconds':d,'contactNormalized':None if n=='BattleIdle' else .58} for n,d in clips],'userVisualApproval':False,'installed':False,'castTargetExcursionMultiplier':1.10,'releaseTimingUnchanged':True,'style':'illustrated diffuse, no reflective material lobes'}
(DOC/'manifest.json').write_text(json.dumps(stats,indent=2)+'\n')
print('MESHY_V3_EXPORTED',json.dumps(stats))
if os.environ.get('MISTPORT_HERO_SKIP_RENDER')=='1':sys.exit(0)

# Actual Blender model inspection; these are never labelled as runtime or phone shots.
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False
scene.render.resolution_x=960;scene.render.resolution_y=1280;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.11,.14,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02));ground=bpy.context.object;ground.name='Studio ground';ground.data.materials.append(mat('Studio ground',(.15,.17,.20),rough=.80))
def light(name,p,energy,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=p;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
light('Warm key',(-2,3,3),280,(1,.88,.75),2)
light('Cool edge',(2,-1,2.5),260,(.63,.78,1),1.5)
light('Soft rear fill',(1,3,1.5),100,(.84,.90,1),2)
d=bpy.data.cameras.new('Model inspection');cam=bpy.data.objects.new('Model inspection',d);scene.collection.objects.link(cam);scene.camera=cam
d.type='ORTHO';d.ortho_scale=2.04
for key in styles:
    for o in scene.objects:
        if o.name.startswith('Outfit-'):o.hide_render=not o.name.startswith('Outfit-'+key+'-')
    for name,loc in [('rear',(0,4.5,.98)),('quarter',(2.4,4.5,1.12))]:
        cam.location=loc;cam.rotation_euler=(Vector((0,0,.90))-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(DOC/f'{key}-blender-{name}.png');bpy.ops.render.render(write_still=True)
print('MESHY_V3_MODEL_RENDERS_DONE')
