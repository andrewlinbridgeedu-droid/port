"""Material and architectural finish for the editable harbor scene.

Run after build_city.py with:
  Blender -b BountyHarborCity.blend -t 8 --python polish_city.py
The stage is deterministic and keeps the hand-authored district geometry intact.
"""
import bpy
import math
import os
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
TEXTURES = ROOT / 'textures'
random.seed(2409)


def image_material(name, filename):
    mat = bpy.data.materials[name]
    nodes = mat.node_tree.nodes
    principled = nodes.get('Principled BSDF')
    image = bpy.data.images.load(str(TEXTURES / filename), check_existing=True)
    image.pack()
    tex = nodes.new('ShaderNodeTexImage')
    tex.name = 'authored_albedo'
    tex.image = image
    tex.extension = 'REPEAT'
    mat.node_tree.links.new(tex.outputs['Color'], principled.inputs['Base Color'])
    return mat


textured = {
    'blue slate roof': ('cobalt-slate.png', 3.5),
    'warm ivory limestone': ('ivory-limestone.png', 3.4),
    'cream plaster': ('ivory-limestone.png', 3.4),
    'plaza pale stone': ('plaza-paving.png', 6.0),
    'clear canal blue': ('canal-water-calm.png', 8.0),
}
for mat_name, (filename, _) in textured.items():
    image_material(mat_name, filename)


def map_uv_world(obj, scale):
    """Repeat albedo in metre-scale world coordinates, retaining glTF UVs."""
    if obj.type != 'MESH':
        return
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='HarborUV')
    normal_matrix = obj.matrix_world.to_3x3()
    for face in obj.data.polygons:
        n = normal_matrix @ face.normal
        n.normalize()
        for index in face.loop_indices:
            v = obj.data.vertices[obj.data.loops[index].vertex_index]
            p = obj.matrix_world @ v.co
            if abs(n.z) >= .55:
                coord = (p.x, p.y)
            elif abs(n.x) > abs(n.y):
                coord = (p.y, p.z)
            else:
                coord = (p.x, p.z)
            uv.data[index].uv = (coord[0] / scale, coord[1] / scale)


for obj in bpy.data.objects:
    if obj.type != 'MESH' or not obj.data.materials:
        continue
    name = obj.data.materials[0].name
    if name in textured:
        map_uv_world(obj, textured[name][1])


def mat(name):
    return bpy.data.materials[name]


def setmat(obj, material):
    obj.data.materials.append(material)
    return obj


def box(name, loc, dimensions, material, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    setmat(o, material)
    if bevel:
        mod = o.modifiers.new('hand finished edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        o.modifiers.new('facade normals', 'WEIGHTED_NORMAL')
    return o


def cylinder(name, loc, radius, depth, material, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    return setmat(o, material)


def sphere(name, loc, scale, material, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return setmat(o, material)


def rod(name, a, b, width, material):
    va, vb = Vector(a), Vector(b)
    midpoint = (va + vb) / 2
    o = box(name, midpoint, (width, width, (vb-va).length), material, width*.2)
    o.rotation_euler = (vb-va).to_track_quat('Z','Y').to_euler()
    return o


# Water continues to the frame edge, rather than ending as a visible rectangle.
basin = bpy.data.objects['sea and canal basin']
basin.dimensions = (500, 430, .20)
bpy.context.view_layer.objects.active = basin
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
map_uv_world(basin, 8.0)

# Shop balconies, shutters, gilt sign arms and hanging wisteria make the
# investigation street readable at close camera distance.
house_sites = [
    ('Post Office',-40,-23,8,6,6.6), ('Canal Cafe',-30,-23,7,6,6.0),
    ('Carpentry',-19,-23,7,6,5.6), ('Wisteria Boarding',-44,-12,8,6,7.8),
    ('Clinic',-33,-12,7,6,7.5), ('Navy Bookshop',-22,-12,7,6,6.7),
    ('Old Drain Office',-14,-12,5.7,6,5.0), ('Empty Third House',-43,-1,7,5,6.8),
    ('Blue Lodgings',-32,-1,7,5,7.5), ('Wisteria Guesthouse',-21,-1,8,5,7.0),
    ('Harbor Registry',29,-23,7,6,7.5), ('Photograph Studio',40,-23,7,6,6.7),
    ('Boat Guild',29,-12,7,6,7.0), ('Cobalt Dye House',40,-12,7,6,7.6),
    ('Ferry Ticket House',29,0,7,6,6.3), ('Watch Office',40,0,7,6,7.8),
]
for k, (name,x,y,w,d,h) in enumerate(house_sites):
    front = y-d/2-.24
    # Upper storey balcony and iron pickets give each facade real depth.
    if k % 3 != 2 and h > 6:
        box(name+' upper balcony slab',(x,front-.43,4.45),(min(w*.64,4.4),.92,.16),mat('carved pale trim'),.07)
        bw=min(w*.64,4.4)
        for i in range(9):
            px=x-bw/2+i*bw/8
            rod(name+f' balcony picket {i}',(px,front-.84,4.53),(px,front-.84,5.28),.048,mat('painted iron'))
        box(name+' balcony gilt handrail',(x,front-.84,5.32),(bw+.2,.07,.08),mat('brushed harbor brass'),.015)
    for side in (-1,1):
        wx=x+side*w*.26
        for level in range(1, max(2,int(h/2.8))):
            z=2.1+level*2.55
            if z > h-.35: continue
            shutter = box(name+f' louvred shutter {side} {level}',
                          (wx+side*.52,front-.06,z),(.28,.10,1.21),
                          mat('painted navy doors'),.026)
            for j in range(4):
                box(name+f' shutter gold slat {side} {level} {j}',
                    (wx+side*.52,front-.124,z-.41+j*.26),(.23,.015,.035),
                    mat('brushed harbor brass'))
    # Every door has physical jambs, warm wall lanterns and a projecting sign.
    for side in (-1,1):
        box(name+f' portal jamb {side}',(x+side*.59,front,1.54),(.14,.24,2.68),mat('carved pale trim'),.03)
        sphere(name+f' porch lantern {side}',(x+side*.83,front-.28,2.35),
               (.13,.13,.24),mat('warm lit window'))
    sphere(name+' gilt door knob',(x+.32,front-.28,1.55),(.09,.08,.09),mat('brushed harbor brass'))
    if k in (0,1,4,6,10,13):
        rod(name+' sign iron arm',(x+w*.3,front-.3,3.38),(x+w*.3,front-1.1,3.38),.055,mat('painted iron'))
        box(name+' hanging guild sign',(x+w*.3,front-1.05,2.92),(.68,.10,.78),mat('painted navy doors'),.05)
        sphere(name+' sign gold crest',(x+w*.3,front-1.12,2.95),(.17,.035,.17),mat('brushed harbor brass'))
    if k in (3,7,9,13):
        for i in range(9):
            px=x-w*.4+i*w*.1
            zz=4.4-(i%3)*.16
            sphere(name+f' balcony wisteria {i}',(px,front-.8,zz),(.16,.22,.27),
                   mat('wisteria blossom' if i%2 else 'pale wisteria'))

# Ivory balustrades and mooring posts provide readable shore edges.
for shoreline, y, x0, x1 in [('west',-30.1,-49,-11),('clock',-30.1,-3,22),('east',-30.1,25,48)]:
    box(shoreline+' quay curb',((x0+x1)/2,y,.43),(x1-x0,.55,.31),mat('carved pale trim'),.08)
    for i in range(int((x1-x0)/2.3)+1):
        x=x0+i*2.3
        cylinder(shoreline+f' mooring cap {i}',(x,y-.18,.77),.18,.38,mat('brushed harbor brass'),12)

# A handful of small moored skiffs and sails keep the ocean physically inhabited.
for i,(x,y,angle) in enumerate([(-56,-27,.2),(-5,-41,-.25),(54,-15,.32),(39,43,-.4),(-30,30,.5)]):
    hull=box(f'skiff {i} curved hull',(x,y,-.28),(3.0,.88,.54),mat('walnut shopfront'),.28)
    hull.rotation_euler.z=angle
    rim=box(f'skiff {i} brass gunwale',(x,y,.04),(3.05,.93,.08),mat('brushed harbor brass'),.06)
    rim.rotation_euler.z=angle
    rod(f'skiff {i} mast',(x,y,.1),(x,y,4.05),.09,mat('walnut shopfront'))
    # Triangular ivory cloth is genuine two-sided mesh, not an image plane.
    verts=[(0,0,3.78),(1.52,0,1.12),(0,0,1.12)]
    mesh=bpy.data.meshes.new(f'skiff {i} sail mesh')
    mesh.from_pydata(verts,[],[(0,1,2)])
    mesh.materials.append(mat('carved pale trim'))
    sail=bpy.data.objects.new(f'skiff {i} ivory sail',mesh)
    bpy.context.collection.objects.link(sail)
    sail.location=(x,y,0)
    sail.rotation_euler.z=angle

# Stone and glazed-water materials use exportable image textures; no rendered
# panorama is used as a fake surface. The original illustration remains a guide.
scene=bpy.context.scene
scene.camera=bpy.data.objects['01 whole harbor']
scene.render.engine='CYCLES'
scene.cycles.samples=24 if os.environ.get('CITY_PREVIEW') else 32
scene.render.resolution_x=1000 if os.environ.get('CITY_PREVIEW') else 1600
scene.render.resolution_y=625 if os.environ.get('CITY_PREVIEW') else 1000
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.image_settings.file_format='PNG'

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'BountyHarborCity.blend'))
if not os.environ.get('CITY_PREVIEW'):
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'BountyHarborCity.glb'),export_format='GLB',
                              export_apply=True,export_yup=True)

scene.render.filepath=str(ROOT/'render-overview.png')
bpy.ops.render.render(write_still=True)
# The two closer viewpoints are created by render_closeups.py after this pass.
# Keeping them separate lets this script run from the base scene on its own.
