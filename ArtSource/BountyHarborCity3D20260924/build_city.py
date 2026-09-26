"""Build the walkable harbor quarter as real Blender geometry, not image cards.

Usage: Blender -b -t 8 --python build_city.py
The supplied panorama guides the composition; unseen facades are authored here.
"""
import bpy
import math
import random
import os
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
random.seed(24)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.materials, bpy.data.curves, bpy.data.meshes):
    pass


def rgba(hexcode):
    value = hexcode.lstrip('#')
    # Principled sockets are linear; feed them linear values so navy roofs do
    # not turn powder blue under color management and bright harbor daylight.
    def linear(byte):
        c = int(byte, 16) / 255
        return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
    return tuple(linear(value[i:i+2]) for i in (0, 2, 4)) + (1,)


def material(name, color, rough=0.74, metal=0, emission=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgba(color)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = rgba(color)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if emission:
        p.inputs['Emission Color'].default_value = rgba(emission)
        p.inputs['Emission Strength'].default_value = 1.7
    return m


STONE = material('warm ivory limestone', '#d5c8ad')
STONE_ALT = material('cool pearly limestone', '#abb8bb')
STONE_DARK = material('aged stone cut', '#7d8d91')
TRIM = material('carved pale trim', '#f0dfba')
PAVING = material('plaza pale stone', '#c8bca9')
PAVING_DARK = material('plaza joint', '#9e9c98')
ROOF = material('blue slate roof', '#223e60', rough=0.63)
ROOF_LIGHT = material('blue ceramic roof', '#2e6188', rough=0.48)
WOOD = material('walnut shopfront', '#675047')
GOLD = material('brushed harbor brass', '#b79754', rough=0.36, metal=0.68)
GLASS = material('window teal glass', '#78b5c4', rough=0.22, metal=0.18)
LAMP = material('warm lit window', '#eec486', rough=0.4, emission='#f5b963')
WATER = material('clear canal blue', '#086da9', rough=0.19, metal=0.22)
WATER_L = material('sunlit ripple', '#50c6e9', rough=0.14, metal=0.18)
WALL_BLUE = material('blue limewash', '#899fb6')
WALL_CREAM = material('cream plaster', '#e0d3bd')
WALL_PEACH = material('sandstone plaster', '#d1bbac')
GARDEN = material('garden moss', '#637e62')
LEAF = material('sunlit leaves', '#668e4d')
LEAF_DARK = material('deep garden leaves', '#295b46')
WISTERIA = material('wisteria blossom', '#8755ae')
WISTERIA_LIGHT = material('pale wisteria', '#ba80da')
MARBLE = material('fountain white marble', '#dbe5df', rough=0.28)
DOOR = material('painted navy doors', '#394f64')
IRON = material('painted iron', '#2f4450', rough=0.5, metal=0.5)


def setmat(obj, mat):
    obj.data.materials.append(mat)
    return obj


def box(name, center, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    setmat(o, mat)
    if bevel:
        mod = o.modifiers.new('soft carved edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        mod.affect = 'EDGES'
        o.modifiers.new('weighted facade normals', 'WEIGHTED_NORMAL')
    return o


def cylinder(name, center, radius, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    o = bpy.context.object
    o.name = name
    setmat(o, mat)
    return o


def cone(name, center, r1, r2, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=center)
    o = bpy.context.object
    o.name = name
    setmat(o, mat)
    return o


def uvball(name, center, scale, mat, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    setmat(o, mat)
    return o


def torus(name, center, major, minor, mat, rotate=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=8,
        location=center, rotation=rotate, major_radius=major, minor_radius=minor)
    o = bpy.context.object
    o.name = name
    setmat(o, mat)
    return o


def roof(name, x, y, z, w, d, rise, mat):
    ex, ey = w / 2 + .3, d / 2 + .3
    verts = [(-ex,-ey,z), (ex,-ey,z), (ex,ey,z), (-ex,ey,z),
             (-ex,0,z+rise), (ex,0,z+rise)]
    verts = [(a+x,b+y,c) for a,b,c in verts]
    faces = [(0,1,5,4), (4,5,2,3), (0,4,3), (1,2,5)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    # Raised slate rows catch the light as actual geometry from every angle.
    for side in (-1,1):
        for i in range(1,max(2,int(d/.58))):
            t=i/max(2,int(d/.58))
            yy=y+side*(d/2+.32)*t
            zz=z+rise*(1-t)+.045
            line=box(name+f' slate course {side} {i}',(x,yy,zz),
                     (w+.62,.055,.055),STONE_DARK)
    return obj


def window(name, x, y, z, width=.73, height=1.15, front=True, lit=False):
    if front:
        box(name+' stone frame',(x,y,z),(width+.17,.18,height+.17),TRIM,.035)
        box(name+' glass',(x,y-.11,z),(width,.05,height),LAMP if lit else GLASS)
        box(name+' mullion',(x,y-.17,z),(.065,.07,height),GOLD)
        box(name+' sill',(x,y-.18,z-height/2-.12),(width+.3,.26,.11),STONE)
    else:
        box(name+' frame',(x,y,z),(.18,width+.17,height+.17),TRIM,.035)
        box(name+' glass',(x+.11,y,z),(.05,width,height),LAMP if lit else GLASS)
        box(name+' mullion',(x+.17,y,z),(.07,.065,height),GOLD)


def house(name, x, y, w, d, h, variant=0, shop=False):
    wall = [WALL_CREAM, WALL_BLUE, STONE, WALL_PEACH][variant % 4]
    roofmat = ROOF_LIGHT if variant % 5 == 1 else ROOF
    box(name+' footing',(x,y,.23),(w+.35,d+.35,.46),STONE_DARK,.12)
    box(name+' masonry',(x,y,h/2+.35),(w,d,h),wall,.08)
    box(name+' raised cornice',(x,y,h+.31),(w+.36,d+.35,.19),TRIM,.055)
    roof(name+' gabled slate',x,y,h+.4,w,d,max(1.5,d*.32),roofmat)
    box(name+' front door',(x,y-d/2-.1,1.5),(.98,.18,2.48),DOOR,.045)
    box(name+' door lintel',(x,y-d/2-.23,2.86),(1.27,.34,.13),GOLD)
    if shop:
        box(name+' awning',(x,y-d/2-.74,3.1),(w*.72,1.2,.12),ROOF_LIGHT,.05)
        for stripe in range(7):
            sx=x+(stripe-3)*w*.085
            box(name+f' striped canopy {stripe}',(sx,y-d/2-1.34,3.02),
                (w*.042,.12,.19),TRIM if stripe%2 else GOLD)
        for k in range(2):
            window(name+f' shop window {k}',x+(-.30 if k==0 else .30)*w,y-d/2-.12,1.55,.8,1.5,lit=k==0)
    else:
        columns = max(1, int(w/2.15))
        for floor in range(max(1, int(h/2.8))):
            for i in range(columns):
                px=x + (i-(columns-1)/2) * min(2.0,w/(columns+.1))
                if floor == 0 and abs(px-x)<.65: continue
                window(name+f' front {floor}-{i}',px,y-d/2-.11,2.1+floor*2.55,
                       lit=(floor+i+variant)%4==0)
                if floor==0 and (i+variant)%2==0:
                    box(name+f' planter {i}',(px,y-d/2-.38,1.42),(.85,.33,.24),STONE,.04)
                    for flower in range(3):
                        uvball(name+f' flower {i}-{flower}',
                               (px+(flower-1)*.26,y-d/2-.41,1.69),
                               (.19,.18,.21),WISTERIA if flower%2 else LEAF)
    for k in range(2):
        window(name+f' side {k}',x+w/2+.1,y+(k-.5)*d*.42,2.6,front=False,lit=k==0)
    for side in (-1,1):
        box(name+f' roof-edge {side}',(x+side*(w/2+.25),y,h+.45),(0.12,d+.6,.18),GOLD,.02)
    # Small roof dormer and chimney break otherwise repeated silhouettes.
    if w>5.5:
        box(name+' dormer',(x-w*.18,y-d*.23,h+1.25),(1.25,.45,1.22),wall,.03)
        roof(name+' dormer cap',x-w*.18,y-d*.23,h+1.85,1.55,.65,.62,roofmat)
        window(name+' dormer glass',x-w*.18,y-d*.51,h+1.16,.63,.73,lit=True)
    box(name+' chimney',(x+w*.28,y+d*.20,h+1.15),(.6,.65,2.2),STONE_DARK,.05)
    box(name+' chimney rim',(x+w*.28,y+d*.20,h+2.28),(.8,.85,.2),TRIM,.04)


def tree(name,x,y,size=1,blossom=False):
    cylinder(name+' trunk',(x,y,1.05*size),.16*size,2.1*size,WOOD,8)
    canopy = WISTERIA if blossom else LEAF
    for i in range(8):
        angle=i*math.tau/8
        r=.68*size if i else 0
        uvball(name+f' bough {i}',(x+math.cos(angle)*r,y+math.sin(angle)*r,
               (2.15+(i%3)*.21)*size),(.83*size,.68*size,.72*size),
               canopy if i%3 else (WISTERIA_LIGHT if blossom else LEAF_DARK))


def lamp(name,x,y):
    cylinder(name+' post',(x,y,1.7),.075,3.4,IRON,10)
    cylinder(name+' base',(x,y,.18),.21,.34,GOLD,12)
    cone(name+' lantern cap',(x,y,3.65),.33,.08,.3,ROOF,8)
    box(name+' lantern',(x,y,3.44),(.42,.42,.5),LAMP,.05)


def rail_line(name,x1,y1,x2,y2,side=.65):
    start=Vector((x1,y1)); end=Vector((x2,y2)); d=end-start
    tangent=d.normalized(); normal=Vector((-tangent.y,tangent.x))*side
    for sign in (-1,1):
        a=start+normal*sign; b=end+normal*sign
        mid=(a+b)/2
        length=(b-a).length
        o=box(name+f' rail {sign}',(mid.x,mid.y,1.28),(length,.12,.13),STONE,.03)
        o.rotation_euler.z=math.atan2(d.y,d.x)
        for i in range(max(2,int(length/1.6))+1):
            t=i/max(2,int(length/1.6)); p=a.lerp(b,t)
            box(name+f' baluster {sign} {i}',(p.x,p.y,.77),(.15,.15,1.1),TRIM,.025)


def bridge(name,x1,y1,x2,y2,width=3.4):
    a=Vector((x1,y1)); b=Vector((x2,y2)); d=b-a
    mid=(a+b)/2
    o=box(name+' stone deck',(mid.x,mid.y,.46),(d.length,width,.48),PAVING,.18)
    o.rotation_euler.z=math.atan2(d.y,d.x)
    rail_line(name,x1,y1,x2,y2,width*.43)
    for t in (.14,.86):
        p=a.lerp(b,t)
        box(name+f' abutment {t}',(p.x,p.y,-.32),(1.1,width+.55,1.25),STONE_DARK,.12)
    for t in (.17,.5,.83):
        p=a.lerp(b,t)
        box(name+f' brass inlay {t}',(p.x,p.y,.73),(.10,width*.86,.04),GOLD)


def clock_tower(x,y):
    cylinder('plaza concentric inlay outer',(x,y,.31),9.3,.08,PAVING_DARK,96)
    for radius in (5.7,8.45): torus('plaza brass ring',(x,y,.4),radius,.055,GOLD)
    cylinder('tower circular steps',(x,y,.7),4.1,.55,STONE,16)
    cylinder('tower pedestal',(x,y,1.3),3.42,.73,TRIM,16)
    box('bell tower plinth',(x,y,2.3),(5.2,5.2,1.7),STONE,.2)
    box('bell tower shaft',(x,y,9.0),(4.4,4.4,12.0),STONE,.14)
    for z in (3.5,7.0,13.9):
        box(f'tower cornice {z}',(x,y,z),(5.1,5.1,.30),TRIM,.09)
    for side in (-1,1):
        for z in (5,8.8,12):
            box(f'tower arched glass {side} {z}',(x+side*2.25,y,z),(.08,.8,1.8),GLASS,.03)
            box(f'tower arch head {side} {z}',(x+side*2.34,y,z+1),(.11,1.0,.14),GOLD)
    box('clock belfry',(x,y,16.0),(5.2,5.2,3.7),WALL_BLUE,.1)
    for side in (-1,1):
        # Real clock faces, hands and rims on all visible walls.
        for along_x in (True,False):
            if along_x:
                pos=(x+side*2.68,y,16.15); rot=(0,math.pi/2,0)
            else:
                pos=(x,y+side*2.68,16.15); rot=(math.pi/2,0,0)
            o=cylinder('clock dial',pos,1.25,.08,MARBLE,48)
            o.rotation_euler=rot
            rim=torus('clock gilt bezel',pos,1.27,.08,GOLD,rot)
            if not along_x and side==-1:
                a=box('clock long hand',(x,y-2.78,16.62),(.10,.08,1.00),IRON)
                b=box('clock short hand',(x+.36,y-2.80,16.15),(.7,.08,.10),IRON)
    roof('bell tower blue cap',x,y,18.1,6.0,6.0,3.7,ROOF_LIGHT)
    cylinder('tower gilded spire',(x,y,22.15),.12,1.3,GOLD)
    uvball('spire star',(x,y,22.85),(.4,.4,.4),GOLD)
    for a in range(12):
        theta=a*math.tau/12
        px=x+6.8*math.cos(theta); py=y+6.8*math.sin(theta)
        lamp(f'clock square lamp {a}',px,py)


def church(x,y):
    box('church raised terrace',(x,y,.45),(29,15,.8),STONE,.3)
    house('church nave',x,y,18,9,9,0)
    box('church transept',(x,y+1,5.2),(24,5.6,8),STONE,.13)
    roof('church transept roof',x,y+1,9.3,24,5.8,3.7,ROOF)
    for sign in (-1,1):
        tx=x+sign*11
        box(f'church facade tower {sign}',(tx,y-2,9),(4.4,4.4,16),STONE,.12)
        box(f'church tower upper {sign}',(tx,y-2,18.2),(4.9,4.9,2.4),WALL_BLUE,.08)
        cone(f'church blue spire {sign}',(tx,y-2,22.1),3.0,0,5.7,ROOF_LIGHT,8)
        cylinder(f'church gold finial {sign}',(tx,y-2,25.2),.13,1.0,GOLD)
    for i in range(7):
        window(f'church long lancet {i}',x-7+i*2.3,y-4.65,6.4,.82,2.5,lit=i%2==0)
    box('church grand portal frame',(x,y-4.74,3.0),(2.6,.3,4.8),TRIM,.11)
    box('church grand portal doors',(x,y-4.94,2.7),(2.1,.12,3.9),DOOR,.04)
    torus('church rose window',(x,y-4.91,8.0),1.12,.15,GOLD,(math.pi/2,0,0))
    cylinder('church rose glazing',(x,y-4.95,8.0),1.04,.06,GLASS,32).rotation_euler.x=math.pi/2
    for side in (-1,1):
        for i in range(3):
            ox=x+side*(4+i*2.4)
            box(f'church flying buttress {side}-{i}',(ox,y+3.8,4.8),(.28,4.5,.45),STONE,.06)
    cylinder('church blue dome drum',(x,y+2,13.6),3.5,2.4,STONE,24)
    uvball('church glazed central dome',(x,y+2,16), (3.7,3.7,3.3),ROOF_LIGHT,24,12)
    cylinder('church dome lantern',(x,y+2,19.2),.55,1.1,GOLD)


# Water is a genuine lower surface; islands, canals and bridges remain separate meshes.
box('sea and canal basin',(0,6,-.68),(126,96,.20),WATER)
for i in range(75):
    x=random.uniform(-62,62); y=random.uniform(-7,47)
    o=box(f'water glint {i}',(x,y,-.54),(random.uniform(.5,2.5),.035,.01),WATER_L)
    o.rotation_euler.z=random.uniform(-.18,.18)

box('western merchant island',(-30,-14,-.08),(42,33,.78),PAVING,.8)
box('central clock island',(9,-14,-.08),(28,33,.78),PAVING,.8)
box('east quay island',(36,-9,-.08),(27,43,.78),PAVING,.7)
box('north garden island',(10,18,-.08),(31,16,.78),GARDEN,.8)
box('church headland',(38,25,.25),(31,23,1.35),STONE,.8)

# Gilded paving joints retain the image's pale, orderly city structure.
for x0,x1,y0,y1 in [(-49,-11,-30,1),(-4,22,-30,1),(24,48,-28,10)]:
    for xx in range(math.ceil(x0),math.floor(x1),2):
        box(f'paving meridian {xx} {y0}',(xx,(y0+y1)/2,.34),(.024,y1-y0,.012),PAVING_DARK)
    for yy in range(math.ceil(y0),math.floor(y1),2):
        box(f'paving latitude {yy} {x0}',((x0+x1)/2,yy,.34),(x1-x0,.024,.012),PAVING_DARK)

bridge('west clock bridge',-10,-13,-5,-13,4.4)
bridge('clock east bridge',23,-10,25,-10,4.3)
bridge('clock garden bridge',9,2,9,10,4.2)
bridge('garden church bridge',25,20,26,20,4.4)
bridge('southern canal bridge',-21,-31,-21,-29,3.0)

clock_tower(8,-14)
church(37,24)

western = [
    ('Post Office',-40,-23,8,6,6.6,1,True),
    ('Canal Cafe',-30,-23,7,6,6.0,3,True),
    ('Carpentry',-19,-23,7,6,5.6,2,True),
    ('Wisteria Boarding',-44,-12,8,6,7.8,1,False),
    ('Clinic',-33,-12,7,6,7.5,0,False),
    ('Navy Bookshop',-22,-12,7,6,6.7,3,True),
    ('Old Drain Office',-14,-12,5.7,6,5.0,2,False),
    ('Empty Third House',-43,-1,7,5,6.8,3,False),
    ('Blue Lodgings',-32,-1,7,5,7.5,1,False),
    ('Wisteria Guesthouse',-21,-1,8,5,7.0,0,False),
]
eastern = [
    ('Harbor Registry',29,-23,7,6,7.5,0,False),
    ('Photograph Studio',40,-23,7,6,6.7,1,True),
    ('Boat Guild',29,-12,7,6,7.0,2,False),
    ('Cobalt Dye House',40,-12,7,6,7.6,3,False),
    ('Ferry Ticket House',29,0,7,6,6.3,1,True),
    ('Watch Office',40,0,7,6,7.8,0,False),
]
for item in western+eastern:
    house(*item)

# Garden pavilions and blue-domed water kiosks echo the supplied panorama.
for i,(x,y) in enumerate([(-8,17),(7,23),(18,14),(26,12)]):
    cylinder(f'garden pavilion {i} base',(x,y,.9),3.0,.8,STONE,20)
    for j in range(8):
        a=j*math.tau/8
        cylinder(f'pavilion {i} col {j}',(x+2.35*math.cos(a),y+2.35*math.sin(a),2.7),.16,3.1,TRIM,10)
    cylinder(f'pavilion {i} roof rim',(x,y,4.4),3.2,.33,GOLD,20)
    cone(f'pavilion {i} blue dome',(x,y,5.75),3.0,0,2.7,ROOF_LIGHT,20)
    cylinder(f'pavilion {i} finial',(x,y,7.3),.13,.65,GOLD)

# Two fountain basins and one garden waterfall have real vertical volume.
for i,(x,y,r) in enumerate([(15,-14,2.25),(-4,18,2.8)]):
    cylinder(f'fountain {i} stone basin',(x,y,.55),r,.52,MARBLE,32)
    cylinder(f'fountain {i} pool',(x,y,.85),r-.26,.08,WATER,32)
    cylinder(f'fountain {i} brass stem',(x,y,1.52),.18,1.33,GOLD,12)
    uvball(f'fountain {i} spray',(x,y,2.32),(.36,.36,.67),WATER_L)
for j in range(12):
    x=-4+j*.75
    box(f'garden cascade {j}',(x,9.4,-.12),(1.0,.42,.08),WATER_L)

for i in range(86):
    if i<25:
        x,y=random.uniform(-49,-12),random.choice([-30,-5,2])+random.uniform(-1,1)
    elif i<48:
        x,y=random.uniform(0,23),random.choice([-30,2,10])+random.uniform(-1,1)
    elif i<68:
        x,y=random.uniform(24,48),random.choice([-30,10,14])+random.uniform(-1,1)
    else:
        x,y=random.uniform(-5,25),random.uniform(13,27)
    tree(f'harbor tree {i}',x,y,random.uniform(.65,1.1),blossom=(i%7==0))

for i in range(28):
    x=random.choice([-10,-6,-2,21,23,25,26]) + random.uniform(-.4,.4)
    y=random.uniform(-29,2)
    lamp(f'quay lamp {i}',x,y)

# Location empties travel with the GLB and identify actual door/approach geometry.
doors = {'B07_PostOffice':(-40,-27),'B07_Clinic':(-33,-16),'B07_Carpentry':(-19,-27),
         'B07_Drain':(-14,-16),'B07_EmptyHouse':(-43,-5),'Tavern':(-30,-27),
         'Church':(37,15),'ClockSquare':(8,-14)}
for name,(x,y) in doors.items():
    empty=bpy.data.objects.new('DOOR_'+name,None)
    bpy.context.collection.objects.link(empty)
    empty.location=(x,y,.5)
    empty.empty_display_type='SPHERE'
    empty.empty_display_size=.5

world=bpy.data.worlds.new('clear harbor daylight')
bpy.context.scene.world=world
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.58,.71,.82,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.5

def point_camera(name,loc,target,scale):
    cam=bpy.data.cameras.new(name)
    ob=bpy.data.objects.new(name,cam)
    bpy.context.collection.objects.link(ob)
    ob.location=loc
    direction=Vector(target)-ob.location
    ob.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
    cam.type='ORTHO'
    cam.ortho_scale=scale
    bpy.context.scene.camera=ob
    return ob

sun_data=bpy.data.lights.new('harbor afternoon sun','SUN')
sun=bpy.data.objects.new('harbor afternoon sun',sun_data)
bpy.context.collection.objects.link(sun)
sun.rotation_euler=(math.radians(31),math.radians(-23),math.radians(-32))
sun_data.energy=1.55
sun_data.angle=math.radians(12)

scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=16 if os.environ.get('CITY_PREVIEW') else 24
scene.render.resolution_x=1000 if os.environ.get('CITY_PREVIEW') else 1600
scene.render.resolution_y=625 if os.environ.get('CITY_PREVIEW') else 1000
scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
scene.view_settings.look='Medium High Contrast'
scene.render.image_settings.file_format='PNG'
scene.camera=point_camera('01 whole harbor', (82,-103,101), (0,0,0), 117)

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'BountyHarborCity.blend'))
if not os.environ.get('CITY_PREVIEW'):
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'BountyHarborCity.glb'),export_format='GLB',
                              export_apply=True, export_yup=True)
scene.render.filepath=str(ROOT/'render-overview.png')
bpy.ops.render.render(write_still=True)

if os.environ.get('CITY_PREVIEW'):
    raise SystemExit(0)

scene.camera=point_camera('02 clock square', (29,-48,43), (4,-13,4), 49)
scene.render.filepath=str(ROOT/'render-clock-square.png')
bpy.ops.render.render(write_still=True)
scene.camera=point_camera('03 west evidence street', (-17,-43,34), (-30,-12,3), 45)
scene.render.filepath=str(ROOT/'render-west-street.png')
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'BountyHarborCity.blend'))
