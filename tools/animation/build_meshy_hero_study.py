"""Non-destructive Blender tailoring study from the user supplied textured GLB.

This is a geometry/material review stage, not a production rig or an App asset.
The input GLB is never modified. All ornament and cloth geometry is authored here.
Blender -b --python tools/animation/build_meshy_hero_study.py -- <repository>
"""
import bpy, bmesh, math, json, sys, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
DOC=ROOT/'docs/development/hero-refinement-20261001/meshy-study'
SOURCE=ROOT/'docs/development/hero-refinement-20261001/meshy-source/original.glb'
DOC.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
base=next(o for o in bpy.context.scene.objects if o.type=='MESH')
base.name='User Meshy base — preserved UV tailoring'
transform=base.matrix_world.copy()
for v in base.data.vertices:v.co=((transform@v.co)+Vector((0,0,1)))*87.5
base.matrix_world=Matrix.Scale(.01,4)
atlas=base.data.materials[0]
atlas.name='Meshy original skin atlas'
tex=next(n.image for n in atlas.node_tree.nodes if n.type=='TEX_IMAGE' and n.image.name=='base_color')
normal=next(n.image for n in atlas.node_tree.nodes if n.type=='TEX_IMAGE' and n.image.name=='normal')

def material(name,color,metal=0,rough=.6):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
 bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
 return m

def dyed_atlas(name,color,rough):
 m=material(name,color,0,rough);nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes['Principled BSDF']
 t=nodes.new('ShaderNodeTexImage');t.image=tex
 mul=nodes.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1;mul.inputs[2].default_value=(*color,1)
 links.new(t.outputs['Color'],mul.inputs[1]);links.new(mul.outputs[0],bs.inputs['Base Color'])
 n=nodes.new('ShaderNodeTexImage');n.image=normal;n.image.colorspace_settings.name='Non-Color'
 nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.08
 links.new(n.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
 return m

cloth=dyed_atlas('Tailored charcoal cloth',(.095,.08,.135),.78)
hair_base=dyed_atlas('Preserved layered hair base',(.10,.075,.12),.45)
leather=dyed_atlas('Boot and glove leather',(.095,.073,.106),.40)
silk=material('Violet woven lining',(.12,.025,.24),0,.44)
outer=material('Charcoal woven outer tails',(.022,.017,.03),0,.75)
gold=material('Raised antique gold thread',(.62,.34,.095),.66,.30)
polished=material('Polished gold clasps',(.71,.45,.16),.82,.24)
teal=material('Woven teal ribbons',(.024,.21,.23),0,.5)
hair=material('Sculpted black violet locks',(.017,.013,.021),0,.37)
hair_light=material('Fine strand highlights',(.022,.016,.028),0,.47)
jewel=material('Faceted amethyst',(.28,.017,.46),.22,.18)
ivory=material('Pleated ivory cuff',(.73,.66,.56),0,.67)
for m in [silk,outer,teal]:
 nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes['Principled BSDF']
 noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=220;noise.inputs['Detail'].default_value=2
 bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.16;bump.inputs['Distance'].default_value=.018
 links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])
 bs.inputs['Sheen Weight'].default_value=.22

bm=bmesh.new();bm.from_mesh(base.data)
# UV-seam duplicates must be welded before subdivision to avoid open cracks.
# BMesh retains the distinct UV values on face corners.
bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.015)
bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
bm.to_mesh(base.data);bm.free()
base.data.normals_split_custom_set([(0,0,0)]*len(base.data.loops))
base.data.materials.clear()
for m in [atlas,cloth,hair_base,leather]:base.data.materials.append(m)
for poly in base.data.polygons:
 p=sum((base.data.vertices[i].co for i in poly.vertices),Vector())/len(poly.vertices)
 # Preserve exposed face and fingers; torso, hair and boots receive different response.
 skin=(p.z>141 and p.z<161 and p.y<0) or (abs(p.x)>20 and p.z>81 and p.z<135)
 poly.material_index=2 if p.z>154 else 0 if skin else 3 if p.z<28 else 1
 poly.use_smooth=True
bpy.context.view_layer.objects.active=base;base.select_set(True)
sub=base.modifiers.new('Retain silhouette, soften polygon shading','SUBSURF');sub.levels=1;sub.render_levels=1
bpy.ops.object.modifier_apply(modifier=sub.name)
base.data.normals_split_custom_set([(0,0,0)]*len(base.data.loops))

def mesh(name,verts,faces,mat):
 d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
 bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(d);bm.free()
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.matrix_world=Matrix.Scale(.01,4);d.materials.append(mat)
 for p in d.polygons:p.use_smooth=True
 return o

def thread(name,points,radius,mat,sides=6):
 vs=[];fs=[]
 for i,p in enumerate(points):
  p=Vector(p);axis=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
  tangent=axis.cross(Vector((0,1,0)))
  if tangent.length<.001:tangent=axis.cross(Vector((1,0,0)))
  tangent.normalize();binormal=axis.cross(tangent).normalized()
  r=radius(i/(len(points)-1)) if callable(radius) else radius
  for j in range(sides):
   a=j/sides*math.tau;vs.append(p+r*(math.cos(a)*tangent+math.sin(a)*binormal))
   if i:k=(i-1)*sides+j;fs.append((k,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j))
 fs.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))])
 return mesh(name,vs,fs,mat)

def gem(name,p,size,mat=jewel):
 x,y,z=p
 vs=[(x,y+.5,z+size),(x+size*.57,y,z),(x,y+.5,z-size),(x-size*.57,y,z),(x,y+size*.36,z)]
 return mesh(name,vs,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,3,2,1)],mat)

def surface(x,z):
 # Conform raised stitching to the actual supplied back rather than a flat plate.
 hit,p,n,i=base.ray_cast(Vector((x,70,z)),Vector((0,-1,0)))
 return Vector((x,p.y+.28,z)) if hit else Vector((x,10,z))

for sign in [-1,1]:
 pts=[surface(sign*(4.2+6.5*t-1.5*math.sin(t*math.pi)),102+35*t) for t in [i/48 for i in range(49)]]
 thread('Fitted princess seam',pts,.14,gold)
 pts=[surface(sign*(2.0+13*t),136-4.4*math.sin(t*math.pi*.72)) for t in [i/40 for i in range(41)]]
 thread('Shoulder chain yoke',pts,.17,gold)
 for k in range(3):
  pts=[surface(sign*(10.5+1.9*math.cos(a)),135-k*.75+2*math.sin(a)) for a in [i/36*math.pi*1.6 for i in range(37)]]
  thread('Shoulder scrolling embroidery',pts,.09,gold,5)
 for z in [104,107]:
  p=surface(sign*4,z);gem('Waist jewelled fastener',p,1.0,polished)
  gem('Inset amethyst',p+Vector((0,.4,0)),.49)
 p=surface(sign*13,106)
 for k in range(14):
  c=p+Vector((sign*k*.23,.1+k*.025,-k*2.25))
  pts=[c+Vector((.55*math.sin(a),.12*math.cos(a),.95*math.cos(a))) for a in [i/20*math.tau for i in range(21)]]
  thread('Interlinked ornament chain',pts,.115,polished,5)
  if k in [3,7,11]:gem('Chain amethyst',c+Vector((0,.3,-.8)),.72)
gem('Upper back amethyst',surface(0,130),1.3)
thread('Pendant suspension',[surface(0,139),surface(0,132)],.13,polished)
gem('Collar star',surface(0,140),1.15,polished)
thread('Pendant tassel',[surface(0,128),surface(0,124)],lambda t:.19+.30*t,polished)

def tail(side,u,t,inner=False):
 sign=1 if side=='L' else -1
 # Cloth widens gradually, curves away from the calf and has several broad folds.
 x=sign*(2.5+u*(11+16*t)+10*t+1.5*math.sin(t*math.pi))
 y=12.5+9*t+(1.5+6.8*t)*math.sin(u*math.pi*3.3+t*.9)+4*t*t*u
 z=103-76*t+8.5*math.sin(math.pi*u)*t-5*u*t*t
 return Vector((x,y+(.45 if inner else 0),z))

for side in ['L','R']:
 for name,u0,mat,offset in [('Purple lining',0,silk,0),('Fitted dark outer cloth',.25,outer,.65)]:
  vs=[];fs=[]
  for j in range(49):
   t=j/48
   for i in range(25):
    u=u0+(1-u0)*i/24;p=tail(side,u,t);p.y+=offset;vs.append(p)
    if i and j:k=(j-1)*25+i-1;fs.append((k,k+1,k+26,k+25))
  o=mesh(name+' '+side,vs,fs,mat);s=o.modifiers.new('Tailored fabric thickness','SOLIDIFY');s.thickness=.18
 for u in [0,.25,1]:
  pts=[tail(side,u,i/64,True)+Vector((0,.35,0)) for i in range(65)]
  thread('Fine gold selvage '+side,pts,.14 if u==.25 else .18,gold)
 pts=[tail(side,i/40,1,True)+Vector((0,.35,0)) for i in range(41)]
 thread('Curved gold hem '+side,pts,.18,gold)
 # Organic leaf scrolls sewn onto the deformed outer surface, not floating decals.
 for k in range(8):
  t0=.29+k*.080
  pts=[tail(side,.57+.16*math.sin(f*math.pi*.78),t0+.077*f,True)+Vector((0,.47,0)) for f in [i/32 for i in range(33)]]
  thread('Raised scrolling stem '+side,pts,.085,gold,5)
  for branch in [-1,1]:
   pts=[]
   for i in range(29):
    a=i/28*math.tau;u=.64+branch*.062*math.sin(a)*math.sin(a*.5);t=t0+.035+.036*math.cos(a)
    pts.append(tail(side,u,t,True)+Vector((0,.49,0)))
   thread('Tapered gold leaf stitch '+side,pts,lambda t:.08+.055*math.sin(t*math.pi),gold,5)
 # Broad curled brocade motifs remain readable at a small combat camera scale.
 for k in range(5):
  t0=.51+k*.086;pts=[]
  for i in range(65):
   f=i/64;a=f*math.pi*2.6;radius=.015+.15*f
   u=.71+radius*math.cos(a);t=t0+radius*.47*math.sin(a)
   pts.append(tail(side,u,t,True)+Vector((0,.57,0)))
  thread('Large arabesque embroidery '+side,pts,lambda t:.09+.10*t,gold,6)
  for leaf in range(3):
   u0=.49+leaf*.14;vs=[];fs=[]
   for i in range(17):
    f=i/16;u=u0+.07*f;t=t0+.02+.037*f
    width=.023*math.sin(f*math.pi)**.7
    for s in [-1,0,1]:vs.append(tail(side,u+s*width,t,True)+Vector((0,.57+(.08 if s==0 else 0),0)))
    if i:p=(i-1)*3;fs.extend([(p,p+1,p+4,p+3),(p+1,p+2,p+5,p+4)])
   mesh('Filled gold embroidered leaf '+side,vs,fs,gold)
 for k in range(5):
  pts=[tail(side,.17+.058*math.sin(a),.46+k*.085+.030*math.cos(a),True)+Vector((0,.13,0)) for a in [i/30*math.tau for i in range(31)]]
  thread('Lining subtle violet brocade '+side,pts,.08,material('Violet brocade '+side+str(k),(.21,.072,.31),.05,.55),5)
 gem('Weighted hem jewel '+side,tail(side,1,1,True)+Vector((0,.15,-2)),1.6)
 # Woven cloth ribbon with a visible folded cross section.
 if side!='L':continue
 sign=1;vs=[];fs=[]
 for j in range(29):
  t=j/28
  for i in range(5):
   u=i/4;angle=t*math.pi*.7;vs.append((sign*(11+15*t+u*2*math.cos(angle)),15+7*t+3.3*math.sin(t*math.pi*1.3)+u*2*math.sin(angle),102-49*t+u*1.5))
   if i and j:k=(j-1)*5+i-1;fs.append((k,k+1,k+6,k+5))
 mesh('Teal woven sash '+side,vs,fs,teal)

# Individual curved hair locks, layered from the nape toward a swept crown.
# Each lock has a curved ridge and three narrow strand ridges, with restrained shine.
for ring in range(5):
 for k in range(24):
  a=k/24*math.tau+ring*.14
  if math.sin(a)<-.6 and ring>2:continue # preserve fringe and face silhouette
  vs=[];fs=[];rows=[]
  for i in range(16):
   t=i/15;polar=.06+ring*.27+t*.96
   angle=a+(.16+.32*math.sin(k*2.1))*t
   radial=Vector((math.sin(polar)*math.cos(angle),math.sin(polar)*math.sin(angle),math.cos(polar)))
   origin=Vector((0,0,162))+radial*28
   hit,p,n,idx=base.ray_cast(origin,-radial)
   if hit and p.z>150:center=p+radial*.18
   else:center=Vector((.4+9.2*math.sin(polar)*math.cos(angle),.2+8.4*math.sin(polar)*math.sin(angle),161+12.9*math.cos(polar)))
   side=Vector((-math.sin(angle),math.cos(angle),0));normal=Vector((math.cos(angle),math.sin(angle),.3)).normalized()
   width=(.40+.12*math.sin(k))*math.sin((.08+.92*t)*math.pi)**.8+.012
   rows.append((center,side,normal,width))
   for j in range(7):
    u=-1+j/3;vs.append(center+side*width*u+normal*(.055*math.cos(u*math.pi*.5)))
    if i and j:p=(i-1)*7+j-1;fs.append((p,p+1,p+8,p+7))
  mesh('Swept sculpted hair lock',vs,fs,hair)
  for u in [-.48,0,.48]:
   pts=[c+s*w*u+n*(.055*math.cos(u*math.pi*.5)+.009) for c,s,n,w in rows]
   thread('Fine engraved strand',pts,lambda t:.014*math.sin(t*math.pi)+.006,hair_light,4)

scene=bpy.context.scene;scene.render.fps=60
for img in bpy.data.images:
 if img.source=='FILE':img.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(DOC/'HeroMeshy-study-v1.blend'))
manifest={'stage':'Blender static tailoring review, not a production rig','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'source_unchanged':True,'textures_preserved':True,'source_armature':False,'animation_retargeted':False,'unity_connected':False,'installed':False,'user_visual_approval':False,'geometry_vertices':sum(len(o.data.vertices) for o in scene.objects if o.type=='MESH'),'source_original_triangles':9653,'details':['smooth source tailoring','cloth/skin/hair/leather response separation','curved long tails and violet lining','raised gold leaf stitches','waist jewels and interlinked chains','swept locks with fine strand ridges','cloth teal ribbons']}
(DOC/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('MESHY_TAILORING_STUDY_SAVED',manifest['geometry_vertices'])
