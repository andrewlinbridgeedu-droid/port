import bpy, math, random, os, json, shutil
from mathutils import Vector
from math import sin,cos,pi
ROOT=os.path.dirname(os.path.abspath(__file__))
OUT=os.path.abspath(os.path.join(ROOT,'../../output/veiled-wanderer-trial-20260922'))
os.makedirs(OUT,exist_ok=True)
random.seed(220922)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in list(bpy.data.materials): bpy.data.materials.remove(d)
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1400; scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12)
scene.view_settings.view_transform='AgX'
# Coordinates: character faces -Y, all anatomy and garment parts are volumetric geometry.
COL={}
for name in ['01 Anatomy','02 Hair','03 Layered Garments','04 Ragged Hat','05 Jewelry and Talismans','06 Embroidery','07 Smoking Pipe','Studio']:
 c=bpy.data.collections.new(name); scene.collection.children.link(c); COL[name]=c
ACTIVE='01 Anatomy'
def collect(o,name=None):
 for c in list(o.users_collection):c.objects.unlink(o)
 COL[name or ACTIVE].objects.link(o); return o

def mat(name,color,metal=0,rough=.5,fabric=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if fabric:
  p.inputs['Specular IOR Level'].default_value=.18
  n=m.node_tree.nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=180;n.inputs['Detail'].default_value=3
  bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.10;bump.inputs['Distance'].default_value=.00045
  m.node_tree.links.new(n.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
  ramp=m.node_tree.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=(*(v*.55 for v in color),1);ramp.color_ramp.elements[1].position=.85;ramp.color_ramp.elements[1].color=(*(min(1,v*1.28) for v in color),1)
  m.node_tree.links.new(n.outputs['Fac'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],p.inputs['Base Color'])
 return m
skin=mat('Porcelain • warm pale skin',(.69,.50,.465),0,.52);skin.node_tree.nodes.get('Principled BSDF').inputs['Subsurface Weight'].default_value=.08
skinshade=mat('Warm skin shadows',(.41,.245,.225),0,.55)
lips=mat('Muted vermilion lips',(.32,.13,.13),0,.42)
robe=mat('Ink plum silk • woven',(.011,.007,.021),0,.56,True)
robe2=mat('Black violet brocade',(.006,.004,.011),0,.52,True)
teal=mat('Peacock teal lining',(.012,.123,.118),0,.48,True)
tealDark=mat('Deep teal satin',(.008,.062,.072),0,.45,True)
gold=mat('Antique brushed gold',(.53,.32,.104),.75,.3)
goldLight=mat('Worn gold high edges',(.8,.59,.27),.68,.27)
bronze=mat('Oxidised brass',(.19,.115,.046),.67,.39)
hair=mat('Ebony violet hair',(.005,.003,.009),.06,.32)
hairLight=mat('Hair edge ribbons',(.026,.015,.035),.1,.38)
black=mat('Ink and obsidian',(.008,.008,.014),0,.4)
white=mat('Ivory eyes',(.8,.69,.58),0,.39)
irismat=mat('Honey gold irises',(.42,.22,.085),.14,.34)
parchment=mat('Aged talisman paper',(.53,.42,.23),0,.83,True)
gem=mat('Clouded jade gemstone',(.04,.19,.205),.32,.22)
wood=mat('Dark sandalwood pipe',(.038,.022,.016),.1,.35)

def mesh(name,verts,faces,material,smooth=True):
 me=bpy.data.meshes.new(name+' geometry');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);COL[ACTIVE].objects.link(o)
 if material:me.materials.append(material)
 for f in me.polygons:f.use_smooth=smooth
 return o

def solid(o,t=.006,inner=None):
 if inner:o.data.materials.append(inner)
 s=o.modifiers.new('Real cloth thickness','SOLIDIFY');s.thickness=t;s.offset=0
 if inner:s.material_offset=1;s.material_offset_rim=1
 return o

def sub(o,n=1):
 m=o.modifiers.new('Soft tailored surface','SUBSURF');m.levels=n;m.render_levels=n;return o

def ell(name,loc,scale,material,segments=32,rings=16):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc);o=collect(bpy.context.object);o.name=name;o.scale=scale;o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
 return o

def ico(name,loc,scale,material,subd=2):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subd,radius=1,location=loc);o=collect(bpy.context.object);o.name=name;o.scale=scale;o.data.materials.append(material);return o

def curve(name,points,radius,material,res=3):
 cu=bpy.data.curves.new(name+' curve','CURVE');cu.dimensions='3D';cu.resolution_u=8;cu.bevel_depth=radius;cu.bevel_resolution=res
 sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for b,pt in zip(sp.bezier_points,points):b.co=pt;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,cu);COL[ACTIVE].objects.link(o);cu.materials.append(material);return o

def tube(name,pts,rads,material,n=12,subdiv=1,elliptic=1):
 verts=[]
 for i,p0 in enumerate(pts):
  p=Vector(p0); tangent=Vector(pts[min(i+1,len(pts)-1)])-Vector(pts[max(0,i-1)])
  tangent.normalize();ref=Vector((0,1,0))
  if abs(tangent.dot(ref))>.95:ref=Vector((1,0,0))
  u=tangent.cross(ref).normalized();v=tangent.cross(u).normalized()
  for j in range(n):
   a=2*pi*j/n;verts.append(p+rads[i]*(cos(a)*u+sin(a)*v*elliptic))
 faces=[]
 for i in range(len(pts)-1):
  for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
 faces.append(tuple(reversed(range(n))));faces.append(tuple((len(pts)-1)*n+j for j in range(n)))
 o=mesh(name,verts,faces,material)
 if subdiv:sub(o,subdiv)
 return o

def ring(name,center,radius,thickness,material,rot=(pi/2,0,0),scale=None):
 bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=center,major_radius=radius,minor_radius=thickness,rotation=rot)
 o=collect(bpy.context.object);o.name=name;o.data.materials.append(material)
 if scale:o.scale=scale
 for f in o.data.polygons:f.use_smooth=True
 return o

def loft(name,rows,material,n=48):
 vs=[]
 for z,rx,ry,cx,cy in rows:
  for j in range(n):
   a=j*2*pi/n;vs.append((cx+rx*cos(a),cy+ry*sin(a),z))
 fs=[]
 for i in range(len(rows)-1):
  for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
 fs+=[tuple(reversed(range(n))),tuple((len(rows)-1)*n+j for j in range(n))]
 return sub(mesh(name,vs,fs,material),1)

# Slender contrapposto anatomy; mostly hidden parts are still modeled.
body=loft('Continuous torso and neck',[(1.20,.145,.095,0,0),(1.27,.169,.11,0,0),(1.34,.145,.091,0,0),(1.43,.12,.078,0,0),(1.53,.137,.089,0,0),(1.66,.163,.101,0,0),(1.76,.186,.11,0,0),(1.82,.215,.088,0,0),(1.87,.147,.071,0,0),(1.89,.076,.066,0,0),(1.98,.058,.06,0,0),(2.005,.064,.06,0,0)],skin)
for side in [-1,1]:
 x=.085*side
 pts=[(x,0,1.27),(x*.94,-.005,1.21),(x*1.05,-.016,1.09),(x*1.04,-.025,.92),(x*1.11,-.033,.79),(x*1.10,-.023,.73),(x*1.14,-.008,.65),(x*1.16,-.008,.49),(x*1.16,-.018,.32),(x*1.17,-.038,.25)]
 if side==1:pts=[(a,b+.084,c+.01) for a,b,c in pts]
 if side<0:pts=[(a-.022*(1.27-c),b-.054*(1.27-c),c) for a,b,c in pts]
 tube(('Left' if side<0 else 'Right')+' long leg',pts,[.083,.089,.082,.064,.051,.050,.057,.048,.030,.028],skin,n=20,subdiv=2,elliptic=.94)
 # ankles and feet
 ay=-.089 if side<0 else .049
 ell('Instep',(.1*side,ay-.052,.18),(.040,.090,.040),skin)
 ell('Foot arch',(.1*side,ay-.020,.199),(.032,.048,.045),skin)
 for j in range(5):
  tx=.1*side+(j-2)*.015
  ell('Toe', (tx,ay-.135-(.01 if j<2 else 0),.151),(.009-.0006*j,.025-.001*j,.011),skin,20,10)
  ell('Obsidian toenail',(tx,ay-.15,.158),(.0063-.0004*j,.010,.0024),black,16,8)
 # faceted high platform sole
 rings=[(.025,.045,.104),(.041,.048,.108),(.107,.051,.113),(.126,.05,.111)]
 vs=[];N=24
 for z,rx,ry in rings:
  for j in range(N):
   a=2*pi*j/N;vs.append((side*.1+rx*cos(a),ay-.055+ry*sin(a),z))
 fs=[]
 for i in range(3):
  for j in range(N):fs.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
 fs+=[tuple(reversed(range(N))),tuple(3*N+j for j in range(N))]
 sole=mesh('Sculpted tall sandal platform',vs,fs,robe2);be=sole.modifiers.new('Rounded lacquer edges','BEVEL');be.width=.008;be.segments=3
 # sandal diagonal straps arch over foot
 for q in [-1,1]:
  curve('Cross sandal strap',[(.1*side-.044,ay-.09+q*.03,.134),(.1*side,ay-.084,.190),(.1*side+.044,ay-.09-q*.03,.137)],.009,robe2)
  curve('Gold strap edge',[(.1*side-.044,ay-.09+q*.03,.139),(.1*side,ay-.084,.195),(.1*side+.044,ay-.09-q*.03,.142)],.0017,gold)
 ring('Ankle circlet',(.1*side,ay,.262),.032,.005,gold,rot=(0,0,0),scale=(1,1.0,1))
 ico('Ankle jewel',(.1*side,ay-.034,.261),(.013,.008,.018),gem)
 curve('Ankle charm chain',[(.1*side-.023,ay-.029,.26),(.1*side-.036,ay-.034,.216),(.1*side-.022,ay-.038,.20)],.002,gold)
 ell('Ankle drop bell',(.1*side-.022,ay-.038,.193),(.011,.011,.014),gold)
# Arms, exposed distal parts; collar and sleeves cover smooth intersection.
arms={-1:[(-.195,0,1.83),(-.25,-.005,1.76),(-.295,-.022,1.65),(-.329,-.036,1.58),(-.382,-.075,1.595),(-.463,-.12,1.628),(-.51,-.151,1.644)],1:[(.195,0,1.83),(.256,.005,1.73),(.295,-.003,1.60),(.31,-.023,1.565),(.35,-.052,1.67),(.395,-.09,1.818),(.424,-.104,1.90)]}
for s,p in arms.items():tube(('Open hand' if s<0 else 'Pipe arm')+' anatomy',p,[.06,.058,.049,.044,.043,.031,.025],skin,20,2,.92)
# Left open hand, anatomically separated fingers in gently cupped pose.
tube('Offering palm',[(-.495,-.148,1.64),(-.531,-.174,1.649),(-.565,-.193,1.65),(-.60,-.207,1.65)],[.025,.038,.04,.029],skin,20,2,.46)
lf=[ [(-.55,-.195,1.675),(-.564,-.207,1.709),(-.59,-.21,1.72)], [(-.586,-.201,1.67),(-.627,-.216,1.683),(-.657,-.217,1.68)], [(-.603,-.203,1.652),(-.656,-.216,1.652),(-.682,-.214,1.661)], [(-.602,-.199,1.636),(-.650,-.212,1.622),(-.675,-.209,1.632)], [(-.589,-.190,1.620),(-.625,-.202,1.599),(-.650,-.20,1.61)] ]
for i,p in enumerate(lf):
 tube('Offering hand finger '+str(i+1),p,[.010 if i else .013,.008,.0056],skin,10,2)
 ell('Left dark fingernail',p[-1],(.008,.004,.0038),black,16,8)
# Raised pipe hand: elongated palm with five curling fingers.
tube('Pipe holding palm',[(.423,-.102,1.89),(.437,-.108,1.929),(.467,-.11,1.958),(.488,-.106,1.978)],[.025,.032,.035,.024],skin,20,2,.52)
rf=[[(.443,-.13,1.934),(.488,-.149,1.941),(.518,-.15,1.962)],[(.479,-.129,1.976),(.506,-.152,2.017),(.539,-.141,2.003),(.538,-.121,1.984)],[(.485,-.111,1.967),(.521,-.116,1.993),(.556,-.10,1.982)],[(.479,-.090,1.96),(.517,-.081,1.983),(.546,-.066,1.975)],[(.466,-.073,1.953),(.49,-.047,1.971),(.516,-.044,1.962)]]
for i,p in enumerate(rf):
 tube('Pipe hand finger '+str(i+1),p,[.010]+[.008]*(len(p)-2)+[.0054],skin,10,2)
 ell('Pipe hand dark fingernail',p[-1],(.007,.003,.003),black,16,8)
# Face with pointed jaw and a modeled nose.
head=loft('Sculpted head',[(1.987,.02,.018,0,-.015),(2.0,.040,.041,0,-.011),(2.031,.064,.052,0,-.004),(2.07,.082,.066,0,0),(2.115,.093,.075,0,.004),(2.158,.092,.076,0,.006),(2.195,.09,.078,0,.011),(2.245,.076,.069,0,.018),(2.278,.043,.038,0,.018),(2.285,.006,.006,0,.019)],skin,n=64)
for s in [-1,1]:
 ell('Ear',(.094*s,.008,2.12),(.021,.012,.036),skin,24,16)
 ell('Ear hollow',(.106*s,-.004,2.12),(.010,.005,.022),skinshade,20,12)
# Triangular bridge, narrow tip and small nostrils.
nose=mesh('Modeled nose bridge',[(-.011,-.071,2.158),(.011,-.071,2.158),(-.011,-.077,2.095),(.011,-.077,2.095),(0,-.114,2.104),(0,-.084,2.161),(-.015,-.087,2.093),(.015,-.087,2.093),(0,-.097,2.088)],[(0,1,5),(0,5,4,6,2),(5,1,3,7,4),(6,4,8),(4,7,8),(2,6,8,7,3)],skin);sub(nose,2)
for s in [-1,1]:ell('Nostril',(s*.010,-.092,2.093),(.004,.0025,.002),skinshade,16,8)
# Almond shaped eyes, inset irises, sculpted eyeliner and lids.
for s in [-1,1]:
 cx=s*.043;cz=2.142
 upper=[];lower=[]
 for j in range(15):
  t=j/14;xx=cx+(t-.5)*.062;tilt=s*(t-.5)*.008
  upper.append((xx,-.0785,cz+sin(pi*t)*.0085+tilt));lower.append((xx,-.0790,cz-sin(pi*t)*.0055+tilt))
 verts=[(cx,-.0808,cz)]+upper+list(reversed(lower))
 eye=mesh('Ivory almond eye',verts,[(0,j+1,(j+1)%(len(verts)-1)+1) for j in range(len(verts)-1)],white)
 ell('Golden iris',(cx,-.082,cz),(.0077,.0020,.0076),irismat,24,12)
 ell('Black pupil',(cx,-.084,cz),(.0030,.0010,.0057),black,20,10)
 ell('Eye catchlight',(cx-.002,-.085,cz+.0032),(.0017,.0005,.0017),white,12,8)
 curve('Upper eyelid and lashes',upper,.0019,black)
 curve('Lower warm eyelid',lower,.0010,skinshade)
 curve('Eyebrow',[(s*.016,-.074,2.167),(s*.041,-.078,2.173),(s*.068,-.066,2.170)],.0032,hair)
# Subtle half-smile.
curve('Upper lip bow',[(-.028,-.069,2.071),(-.011,-.081,2.074),(0,-.084,2.071),(.012,-.080,2.075),(.028,-.068,2.081)],.0023,lips)
curve('Lower lip',[(-.018,-.076,2.068),(0,-.083,2.066),(.019,-.074,2.073)],.0024,skinshade)
# Sternum / collar bones as fine shadowed lines (no generic muscular bulk).
for s in [-1,1]:
 curve('Collarbone',[(s*.030,-.067,1.883),(s*.081,-.074,1.855),(s*.145,-.076,1.850)],.0022,skinshade)
 curve('Torso definition',[(s*.038,-.093,1.723),(s*.037,-.096,1.643),(s*.024,-.087,1.565)],.0016,skinshade)
curve('Navel',[(0,-.083,1.486),(.004,-.085,1.478),(0,-.084,1.471)],.0021,skinshade)

# Garments: separate thick fabric panels, open front, fully inferred back.
ACTIVE='03 Layered Garments'
def panel(name,fun,nu=24,nv=20,material=robe,thick=.005,inner=teal,flip=False):
 v=[fun(i/nu,j/nv) for i in range(nu+1) for j in range(nv+1)]
 f=[]
 for i in range(nu):
  for j in range(nv):
   a=i*(nv+1)+j;face=(a,a+nv+1,a+nv+2,a+1);f.append(tuple(reversed(face)) if flip else face)
 o=mesh(name,v,f,material);solid(o,thick,inner);return o

def embroider(label,fun,seed,amount=5):
 global ACTIVE
 old=ACTIVE;ACTIVE='06 Embroidery';rng=random.Random(seed)
 for branch in range(amount):
  u0=rng.uniform(.1,.72);v0=rng.uniform(.13,.8);direction=rng.choice([-1,1]);length=rng.uniform(.12,.28)
  pts=[]
  for k in range(8):
   t=k/7;u=min(.96,max(.02,u0+length*t));v=min(.96,max(.03,v0+direction*.085*sin(t*pi*1.2)+.03*t))
   p=Vector(fun(u,v));p.y-=.004;pts.append(p)
  curve(label+' gold vine',pts,.0013,gold,res=2)
  for k in [1,3,5,6]:
   t=k/7;u=u0+length*t;v=v0+direction*.085*sin(t*pi*1.2)+.03*t
   for sg in [-1,1]:
    dv=sg*rng.uniform(.022,.06);du=rng.uniform(.024,.05)
    coords=[(u,v),(u+du*.1,v+dv*.7),(u+du,v+dv),(u+du*.73,v+dv*.22)]
    points=[]
    for a,b in coords:
     p=Vector(fun(min(.985,max(.01,a)),min(.985,max(.01,b))));p.y-=.005;points.append(p)
    o=mesh(label+' hammered leaf',points,[(0,1,2,3)],goldLight,False);solid(o,.0007)
 ACTIVE=old
# Main back robe, seven independent falling panels with irregular layered hems.
for k in range(7):
 a0=-pi/2+.49+k*(2*pi-.98)/7;a1=-pi/2+.49+(k+1)*(2*pi-.98)/7
 def backfun(u,v,a0=a0,a1=a1,k=k):
  # u descends, v wraps round body; lower corners curl in depth.
  phi=a0+(a1-a0)*v;top=1.87-.04*abs(cos(phi));bottom=[.44,.23,.37,.19,.52,.31,.61][k]+.025*sin(v*13+k)+.03*(v-.5)**2
  z=top*(1-u)+bottom*u
  clearance=math.exp(-((z-1.22)/.17)**2)
  r=.217-.067*sin(pi*min(1,u*1.45))+.10*u*u+.05*clearance
  fold=.011*sin(v*pi*5+u*4+k)+.006*sin(v*pi*11-u*3)
  x=(r+fold)*cos(phi);y=(r*.76+fold)*sin(phi)+.018+u*u*.045+.028*clearance*max(0,sin(phi))
  return (x,y,z)
 ob=panel('Back coat panel %02d'%k,backfun,30,16,robe if k%2 else robe2,.007,tealDark)
 if k in [0,1,3,5,6]:embroider('Back coat %02d'%k,backfun,200+k,8)
 # curled ragged hem edge
 curve('Coat hem seam',[backfun(.993,j/20) for j in range(21)],.0018,gold)
# Front lapel, cross collar, and long sculpted open robe panels.
for s in [-1,1]:
 def frontfun(u,v,s=s):
  z=1.884-u*((1.39 if s<0 else 1.50)+.025*sin(v*13+s))
  inner=.053+.10*sin(pi*u*.8)-.065*u
  outer=.24+.10*sin(pi*u*.75)+.055*u
  x=s*(inner+(outer-inner)*v)
  y=-.071-.025*sin(pi*u)+.028*v+.075*u*u+.018*sin(v*8+u*10)
  x+=s*.055*sin(u*5)*v*u
  return (x,y,z)
 panel(('Left' if s<0 else 'Right')+' open brocade lapel and hanging panel',frontfun,36,22,robe,.006,teal,flip=s<0)
 embroider('Front brocade '+str(s),frontfun,400+s,19)
 curve('Gold lapel piping',[frontfun(i/60,.025) for i in range(61)],.0023,gold)
 # separate long teal inner banner in front with wave and split/torn tail
 def tealfun(u,v,s=s):
  x=s*(.105+.095*v+.065*u+.023*sin(u*6+v*3));y=-.104+.025*u+.045*sin(u*4)*v
  z=1.405-u*((.88 if s<0 else .72)+.025*sin(v*10+s));return(x,y,z)
 panel('Long peacock silk lining '+str(s),tealfun,36,16,teal,.004,tealDark,flip=s<0)
# Dark wrapped hip sash drapes, leave front leg exposed.
for s in [-1,1]:
 def hipfun(u,v,s=s):
  x=s*(.02+.21*v+.05*u);y=-.115+.062*v+.025*sin(u*6+v*10);z=1.38-.28*u+.04*v-.08*sin(pi*v)*u
  return(x,y,z)
 panel('Folded waist wrap '+str(s),hipfun,18,20,robe2,.007,robe,flip=s<0)
# Raised asymmetric collar reduces the open neck gap and gives the original high-neck silhouette.
for sg in [-1,1]:
 def collarfun(u,v,sg=sg):
  x=sg*(.068+.077*v+.018*sin(u*pi));y=-.059-.026*u+.03*v
  z=1.988-.245*u-.058*v+.016*sin(v*pi)
  return(x,y,z)
 panel('Raised brocade collar '+str(sg),collarfun,18,12,robe2,.006,robe,flip=sg<0)
 curve('Collar antique gold piping',[collarfun(j/22,0) for j in range(23)],.0023,gold)
 embroider('Collar '+str(sg),collarfun,905+sg,5)
# Opaque oblique waist fold over pelvis. Left thigh slit starts beneath it.
def apronfun(u,v):
 x=-.085+.23*v+.013*sin(u*6+v*3)*u
 y=-.137+.014*sin(v*11+u*9)*u+.016*cos(v*4)*u-.008*v
 z=1.39-u*(.16+.20*v**1.6)+.02*sin(v*pi)
 return(x,y,z)
panel('Asymmetric opaque front waist fold',apronfun,18,20,robe2,.008,robe)
curve('Waist diagonal folded hem',[apronfun(.98,j/30) for j in range(31)],.0018,gold)
# Sleeves drop from arms with huge uneven bell hems and teal interiors.
for s in [-1,1]:
 points=arms[s]
 def sleevefun(u,v,s=s,points=points):
  p0=Vector(points[0]);p1=Vector(points[3]);p2=Vector(points[-1]);t=u
  c=(1-t)**2*p0+2*t*(1-t)*p1+t*t*p2
  axis=(p2-p0).normalized();side=Vector((0,1,0));down=axis.cross(side).normalized()
  if down.z<0:down=-down
  a=2*pi*v;r=.082+.065*t
  vert=sin(a);drop=max(0,-vert)*(.10+.43*t**1.1)
  rr=r+(.025*sin(v*27+u*4))*(t*.8+.1)
  p=c+side*cos(a)*rr+down*vert*rr-Vector((0,0,drop))
  p.x+=s*(.035*t*sin(v*9)+.04*t*t)
  p.y+=.015*sin(u*18+v*7)*t
  if u>.85:p.z-=((u-.85)/.15)*.04*(.5+.5*sin(v*41+s))
  return tuple(p)
 panel('Long split bell sleeve '+str(s),sleevefun,32,52,robe,.007,teal,flip=s>0)
 embroider('Sleeve flowers '+str(s),sleevefun,600+s,22)
 curve('Bell sleeve gold hem '+str(s),[sleevefun(1,j/72) for j in range(73)],.0020,gold)
 # long free edge strips create layers and torn cloth silhouette
 for j in range(3):
  anchor=Vector(sleevefun(.67+j*.12,.67))
  def strip(u,v,anchor=anchor,j=j,s=s):
   w=(.05+.016*j)*(1-u*.67);x=anchor.x+s*(.11*u+.04*sin(u*5+j))+(v-.5)*w
   y=anchor.y+.06*sin(u*4+j)+(v-.5)*.035;z=anchor.z-(.36+j*.10)*u+.025*sin(u*5+v*3)
   if u>.93:z-=.025*sin(v*15)
   return(x,y,z)
  panel('Torn hanging sleeve streamer '+str(s)+'-'+str(j),strip,25,8,teal if j==1 else robe,.004,tealDark)
# Waist belt volumes and diagonal straps.
for slope in [-.045,.05]:
 rows=[]
 vs=[];N=96
 for j in range(N):
  a=2*pi*j/N;x=.158*cos(a);y=.116*sin(a)
  for v in [0,1]:vs.append((x,y,1.414+(v-.5)*.06+slope*cos(a)))
 fs=[(2*j,2*((j+1)%N),2*((j+1)%N)+1,2*j+1) for j in range(N)]
 ob=mesh('Crossed leather waist belt',vs,fs,robe2);solid(ob,.012)
 for v in [-1,1]:curve('Waist belt gilded welt',[(.16*cos(a),.119*sin(a),1.414+v*.028+slope*cos(a)) for a in [j*2*pi/96 for j in range(97)]],.0024,gold)

# Long layered hair made from sculpted tapered locks, including inferred back mass.
ACTIVE='02 Hair'
# hair scalp cap from crown down to nape, open front below forehead.
for i in range(18):
 a=-.18+(2*pi+.36)*i/17
 if sin(a)<-.45:continue
 start=(.05*cos(a),.025+.05*sin(a),2.276)
 mid=(.095*cos(a),.018+.081*sin(a),2.20)
 end=(.10*cos(a)+.02*sin(i),.025+.09*sin(a),1.77-.10*(i%3))
 tube('Long back hair lock %02d'%i,[start,mid,(end[0]*.94,end[1]*1.05,2.02),end,(end[0]+.024*sin(i*2),end[1]-.006, end[2]-.095)],[.024,.029,.024,.015,.0015],hair if i%4 else hairLight,12,2,.5)
# hair framing the face, asymmetrical bangs.
bangs=[[(.006,-.04,2.284),(-.033,-.080,2.233),(-.055,-.089,2.18),(-.071,-.075,2.099)],[(.03,-.04,2.285),(.045,-.075,2.227),(.086,-.077,2.171),(.125,-.076,2.064)],[(.017,-.053,2.279),(.004,-.094,2.225),(.025,-.099,2.163),(.052,-.091,2.11)],[(-.025,-.03,2.278),(-.067,-.074,2.221),(-.091,-.059,2.122),(-.098,-.072,2.017)]]
for i,p in enumerate(bangs):tube('Ragged diagonal fringe '+str(i),p,[.025,.023,.014,.001],hair,12,2,.24)
for s in [-1,1]:
 for j in range(5):
  pts=[(s*(.075+j*.004),-.04+j*.012,2.196),(s*(.11+j*.011),-.046+j*.013,2.037),(s*(.105+j*.012),-.064+j*.012,1.88),(s*(.137+.01*j),-.105+j*.012,1.684-.035*j),(s*(.12+.017*j),-.098+j*.012,1.52-.025*j)]
  tube('Chest framing hair '+str(s)+'-'+str(j),pts,[.021,.022,.020,.014,.0012],hair,12,2,.48)
  curve('Thin hair glint',[(x,y-.008,z) for x,y,z in pts[1:]],.0011,hairLight)
 # small long braid with three woven cords
 for k in range(3):
  pts=[]
  for j in range(28):
   t=j/27;pts.append((s*.105+.009*sin(t*9*pi+k*2*pi/3),-.079+.007*cos(t*9*pi+k*2*pi/3),2.10-.48*t))
  tube('Braided side lock '+str(s)+'-'+str(k),pts,[.0065]*27+[.0025],hair,8,1)

# Large asymmetric broken hat: irregular real rim, sculpted crown, gold leaf wear.
ACTIVE='04 Ragged Hat'
def hatfun(u,v):
 a=v*2*pi;r=.125+(.43+.085*sin(a+.5)+.04*sin(3*a))*u
 tear=(.030*sin(v*137)+.022*sin(v*79+.4))*(u**9)
 if cos(a)<-.1:tear+=.035*sin(v*193)*u**7
 r+=tear
 x=r*cos(a);y=r*.66*sin(a)+.022
 z=2.303-.23*x+.050*sin(3*a-.7)*u+.035*sin(v*11+u*4)*u+.014*cos(v*103)*u**8
 return(x,y,z)
panel('Asymmetric torn brim',hatfun,25,160,robe,.011,robe2)
# Interrupted edge piping leaves some frayed raw areas.
for a,b in [(0,.15),(.18,.27),(.31,.42),(.46,.58),(.62,.76),(.79,.96)]:
 curve('Broken brass hat rim',[hatfun(.993,a+(b-a)*j/25) for j in range(26)],.0028,gold)
# radial tears are separate thin dark cloth shards with true thickness
for i in range(8):
 a=.34+i*.04
 p=Vector(hatfun(.91,a));q=Vector(hatfun(1,a+.012));tip=Vector(hatfun(1,a-.014));tip.x-=.055+random.random()*.045;tip.z-=.02
 shard=mesh('Frayed hat shard', [p,q,tip],[(0,1,2)],robe,False);solid(shard,.006,robe2)
# crooked crown, not a perfect cylinder
crown=loft('Crooked hat crown',[(2.306,.168,.128,.00,.025),(2.32,.17,.13,.0,.026),(2.37,.143,.115,.025,.03),(2.48,.13,.106,.057,.035),(2.50,.124,.1,.06,.036),(2.505,.11,.088,.06,.036)],robe2,64)
# Crown ornamentation with mapped flowers on front facing sector.
def crownfun(u,v):
 a=pi+v*pi;x=.016+.139*cos(a)+.023*(1-u);y=.030+.112*sin(a);z=2.35+.16*(1-u);return(x,y-.001,z)
embroider('Hat gilded creeper',crownfun,1222,14)
# band low on crown, thin crossed cords
for j in range(3):
 pts=[]
 for i in range(97):
  a=i*2*pi/96;pts.append((.004+.173*cos(a),.026+.134*sin(a),2.335+j*.009+.008*sin(a*2+j)))
 curve('Braided hat band',pts,.0035,gold if j==1 else black)

# Necklace, waist buckle, bells, ornamental chains, dangling talisman paper.
ACTIVE='05 Jewelry and Talismans'
for s in [-1,1]:
 curve('Fine necklace chain',[(s*.061,-.044,1.968),(s*.064,-.075,1.879),(s*.044,-.105,1.80),(0,-.119,1.762)],.0022,gold)
 ring('Earring hoop',(s*.101,-.007,2.073),.013,.0025,gold)
 ell('Earring jade drop',(s*.101,-.008,2.043),(.007,.006,.016),gem)
# ornamental diamond pendant
p=mesh('Hollow neck pendant',[(-.013,-.120,1.773),(0,-.126,1.799),(.013,-.120,1.773),(0,-.125,1.745)],[(0,1,2,3)],gold,False);solid(p,.006)
ico('Pendant jade',(0,-.129,1.771),(.006,.004,.012),gem)
# waist ring has a real cutout and inset stone
ring('Waist golden buckle',(-.016,-.137,1.405),.055,.009,gold,scale=(1,1,1))
ico('Eight faceted teal waist stone',(-.016,-.145,1.405),(.041,.014,.041),gem,2)
for j in range(8):
 a=j*pi/4;ico('Buckle gold petal',(-.016+.05*cos(a),-.147,1.405+.05*sin(a)),(.010,.006,.016),gold,1)
# Jewelry chains, each link is separate ring.
def chain(label,pts,n=15,r=.010):
 for i in range(n):
  t=i/(n-1);q=t*(len(pts)-1);k=min(len(pts)-2,int(q));u=q-k;p=Vector(pts[k]).lerp(Vector(pts[k+1]),u)
  ring(label+' link %02d'%i,p,r,.0018,gold,rot=(pi/2,(i%2)*pi/2,0),scale=(.78,1,1.3))
chain('Waist swag',[(-.04,-.151,1.371),(-.07,-.163,1.299),(-.115,-.148,1.328)],16,.01)
chain('Crossbody hanging chain',[(.145,-.05,1.42),(.20,-.036,1.31),(.22,-.018,1.19)],16,.009)

def bell(label,loc,scale=1):
 x,y,z=loc
 ell(label+' bronze body',(x,y,z),(.023*scale,.022*scale,.024*scale),gold)
 ring(label+' neck',(x,y,z+.022*scale),.008*scale,.0025*scale,gold,rot=(pi/2,0,0))
 curve(label+' cut slot',[(x-.021*scale,y-.007*scale,z-.004*scale),(x,y-.024*scale,z-.01*scale),(x+.021*scale,y-.007*scale,z-.004*scale)],.0018*scale,black)
 ell(label+' lip clapper',(x,y-.001,z-.026*scale),(.006*scale,.006*scale,.007*scale),bronze)
bell('Central fortune bell',(-.072,-.167,1.264),1.2)
bell('Hip brass bell',(.212,-.019,1.14),.8)
for side,z in [(-1,.92),(1,.63)]:
 curve('Hanging bell cord',[(side*.19,-.06,z+.21),(side*.204,-.07,z+.11),(side*.22,-.074,z+.025)],.0032,black)
 bell('Hem wandering bell',(side*.22,-.074,z),1)
# charms: thin curved paper, ink writing as authored branching glyphs.
def talisman(label,loc,w=.04,h=.21,angle=0):
 x,y,z=loc
 def f(u,v):
  xx=(v-.5)*w;zz=-u*h
  return(x+xx*cos(angle)-zz*sin(angle),y+.010*sin(u*4)+.004*sin(v*5),z+xx*sin(angle)+zz*cos(angle))
 panel(label,f,12,4,parchment,.0018,parchment)
 # invented marks; no claim to legible religious language.
 for i in range(7):
  u=.14+i*.105
  ink=[]
  for j in range(4):
   v=.5+(.18 if j%2 else -.16)*(1 if i%2 else -1);p=Vector(f(u+j*.025,v));p.y-=.0026;ink.append(p)
  curve(label+' ink glyph',ink,.0013,black,res=1)
  if i%2==0:
   p0=Vector(f(u+.04,.18));p1=Vector(f(u+.04,.8));p0.y-=.0028;p1.y-=.0028;curve(label+' ink cross',[p0,p1],.001,black,res=1)
 curve(label+' tie',[(x,y,z+.032),(x+.003,y-.008,z+.009),(x,y,z)],.0018,gold)
 ring(label+' punched eye',(x,y-.005,z-.010),.0032,.0011,bronze)
talisman('Waist prayer slip A',(-.1,-.18,1.325),.037,.195,-.17)
talisman('Waist prayer slip B',(.11,-.11,1.34),.042,.245,.10)
talisman('Back travel slip',(.17,.211,1.38),.045,.22,.06)
# long hat charms hanging off brim
for x,y,z,sc in [(-.49,-.018,2.37,1),(.315,-.10,2.236,.74)]:
 chain('Hat hanging chain',[(x,y,z),(x-.008,y,z-.06)],8,.006)
 ell('Hat jade bead',(x-.008,y,z-.089),(.015*sc,.013*sc,.018*sc),gem)
 talisman('Hat talisman', (x-.008,y-.005,z-.119),.034*sc,.158*sc,.045)
# Tiny gold buttons and braid rings
for s in [-1,1]:
 for z in [1.83,1.76,1.69]:ring('Hair tie brass',(.108*s,-.077,z),.009,.002,gold,rot=(0,0,0))
 ring('Wrist bracelet',(s*.42 if s>0 else -.486,-.10 if s>0 else -.134,1.886 if s>0 else 1.635),.029,.0035,gold,rot=(0,.35 if s>0 else pi/2,0))
# Tattoo follows the actual rounded leg and exposed upper sternum.
ACTIVE='06 Embroidery'
def tattoo_path(points):curve('Ink • thorn tattoo',points,.0023,robe2,res=2)
# Organic forked ink laid against the curved front leg, not floating rings.
leg_profile=[(.32,.030,-.06),(.49,.048,-.050),(.65,.057,-.041),(.73,.050,-.052),(.79,.051,-.059),(.92,.064,-.044),(1.09,.082,-.026),(1.21,.089,-.008)]
def leg_ink(z,off):
 for i in range(len(leg_profile)-1):
  a,b=leg_profile[i],leg_profile[i+1]
  if a[0]<=z<=b[0]:
   t=(z-a[0])/(b[0]-a[0]);r=a[1]*(1-t)+b[1]*t;cy=a[2]*(1-t)+b[2]*t;break
 else:r=.04;cy=-.055
 cx=-.092-.022*(1.27-z);off=max(-r*.85,min(r*.85,off));return(cx+off,cy-math.sqrt(max(.0001,r*r-off*off))-.003,z)
for top,bot,seed in [(1.205,.885,701),(.705,.36,702)]:
 rng=random.Random(seed)
 pts=[leg_ink(top+(bot-top)*j/20,.004*sin(j*.55)) for j in range(21)]
 tube('Organic ink central taper',pts,[.0024]*(len(pts)-1)+[.0003],robe2,6,1)
 for k in range(5):
  z=top-.035-k*(top-bot)*.16
  for sg in [-1,1]:
   w=sg*rng.uniform(.019,.041);rise=rng.uniform(.030,.066)
   pts=[leg_ink(z,0),leg_ink(z+.010,w*.55),leg_ink(z+rise*.55,w),leg_ink(z+rise,w*.83)]
   tube('Tapered thorn tattoo branch',pts,[.0028,.0024,.0015,.0002],robe2,6,1)
for s in [-1,1]:
 tattoo_path([(s*.025,-.081,1.91),(s*.03,-.088,1.864),(s*.057,-.092,1.835),(s*.069,-.095,1.802)])
 tattoo_path([(s*.03,-.087,1.866),(s*.065,-.088,1.872),(s*.088,-.081,1.906)])

# Physical smoking pipe: long dark shaft with cast brass bowl, real hanging tassel.
ACTIVE='07 Smoking Pipe'
pipe_start=(.31,-.14,2.060);pipe_end=(.82,-.108,1.966)
curve('Long slender sandalwood pipe',[pipe_start,(.50,-.126,2.025),pipe_end],.0054,wood)
curve('Pipe brass fillet',[pipe_start,(.44,-.133,2.040)],.0062,gold)
curve('Upturned cast pipe bowl',[(.812,-.108,1.966),(.852,-.102,1.972),(.863,-.102,2.013)],.011,gold)
ring('Pipe open bowl rim',(.863,-.102,2.017),.014,.003,goldLight,rot=(0,0,0))
ell('Pipe bowl dark hollow',(.863,-.102,2.016),(.010,.010,.002),black)
curve('Tassel suspension',[(.818,-.109,1.964),(.816,-.11,1.911),(.82,-.108,1.869)],.0020,gold)
for j in range(16):
 a=j*2*pi/16;curve('Individual teal tassel cord',[(.82+.006*cos(a),-.108+.006*sin(a),1.865),(.82+.014*cos(a),-.11+.011*sin(a),1.805),(.82+.020*cos(a)+.005*sin(j),-.107+.013*sin(a),1.727+.005*sin(j*2))],.0024,tealDark)
ring('Tassel knot',(.82,-.108,1.864),.008,.003,gold,rot=(0,0,0))

# Present on a gallery plinth, physically rendered, with multiple view cameras.
ACTIVE='Studio'
studiomat=mat('Warm grey studio',(.135,.145,.155),0,.75)
floor=mesh('Studio ground',[(-200,-200,-.026),(200,-200,-.026),(200,200,-.026),(-200,200,-.026)],[(0,1,2,3)],studiomat)
bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=.81,depth=.036,location=(0,0,-.02));platform=collect(bpy.context.object);platform.name='Slate display plinth';platform.data.materials.append(mat('Slate plinth',(.032,.04,.05),.15,.65));b=platform.modifiers.new('Soft plinth edge','BEVEL');b.width=.01;b.segments=3

def area(name,loc,power,size,color,target=(0,0,1.3)):
 bpy.ops.object.light_add(type='AREA',location=loc);o=collect(bpy.context.object);o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('Large softbox key',(-3,-4,5.6),650,4.0,(1,.88,.76))
area('Cool frontal fill',(3,-2,3),280,3,(.64,.82,1))
area('Rim on torn fabric',(1.5,2.0,4.0),850,2.5,(.66,.87,1))
area('Warm gold edge',(-3,1,2.7),300,2,(1,.65,.37))
world=scene.world;world.use_nodes=True;world.node_tree.nodes.get('Background').inputs[0].default_value=(.14,.165,.19,1);world.node_tree.nodes.get('Background').inputs[1].default_value=.35
bpy.ops.object.camera_add(location=(3,-7,3.0));cam=collect(bpy.context.object);cam.name='Gallery Camera';cam.data.type='ORTHO';cam.data.ortho_scale=3.12;scene.camera=cam

def view(loc,target=(0,0,1.30),scale=3.12):
 cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
view((2.8,-8,2.9));scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
# Export clean collection tree; stage is excluded. Keep the native Blender file fully editable.
for o in bpy.data.objects:o.select_set(False)
character=[o for c in COL.values() if c.name!='Studio' for o in c.objects]
for o in character:o.select_set(True)
bpy.context.view_layer.objects.active=body
# Store intent / provenance in blend.
scene['asset_status']='Authored Blender trial from one user image. Inferred back. No rig; not game-ready.'
scene['reference_file']='reference.png';scene['coordinate_system']='Z up, front -Y'
scene['build_script']='build_trial.py'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'VeiledWanderer_Trial.blend'))
# Export evaluates real meshes, including thickness modifiers and curves.
exec(compile(open(os.path.join(ROOT,'export_glb.py')).read(),os.path.join(ROOT,'export_glb.py'),'exec'))
stats={'objects':len(character),'mesh_objects':sum(o.type=='MESH' for o in character),'curve_objects':sum(o.type=='CURVE' for o in character),'has_armature':False,'reference':'reference.png','status':'Blender authored trial; back inferred; no game integration'}
dg=bpy.context.evaluated_depsgraph_get();tri=0
for o in character:
 if o.type not in {'MESH','CURVE'}:continue
 e=o.evaluated_get(dg);me=e.to_mesh();me.calc_loop_triangles();tri+=len(me.loop_triangles);e.to_mesh_clear()
stats['evaluated_triangles']=tri
with open(os.path.join(ROOT,'model_stats.json'),'w') as f:json.dump(stats,f,indent=2)
# Fast initial preview. Final views may be rendered using render_views.py.
scene.cycles.samples=24;scene.render.resolution_percentage=65
scene.render.filepath=os.path.join(OUT,'draft-three-quarter.png');bpy.ops.render.render(write_still=True)
print('TRIAL_BUILD_COMPLETE',json.dumps(stats))
