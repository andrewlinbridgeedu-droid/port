"""Render the editable Blender model, never substitute concept art for model evidence."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
DOC=ROOT/'docs/development/hero-refinement-20261001'
bpy.ops.wm.open_mainfile(filepath=str(DOC/'HeroRefined-v1.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=800;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.world=bpy.data.worlds.new('Soft studio world');scene.world.color=(.04,.04,.05)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015));ground=bpy.context.object
mat=bpy.data.materials.new('Studio ground');mat.diffuse_color=(.19,.20,.22,1);ground.data.materials.append(mat)
def area(name,loc,energy,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
area('Warm soft key',(-2.5,3,3.7),140,(1,.84,.69),3)
area('Cool silhouette',(2,-1,2.8),180,(.68,.79,1),2)
area('Back cloth fill',(1,3,1.8),35,(.87,.88,1),2)
d=bpy.data.cameras.new('Rear model evidence');cam=bpy.data.objects.new('Rear model evidence',d);scene.collection.objects.link(cam);scene.camera=cam
d.type='ORTHO';d.ortho_scale=2.1;d.lens=50
def camera(yaw):
    cam.location=(math.sin(yaw)*4,math.cos(yaw)*4,1.15);cam.rotation_euler=(Vector((0,.03,.86))-cam.location).to_track_quat('-Z','Y').to_euler()
def color(name,c):
    m=bpy.data.materials[name];m.diffuse_color=(*c,1);m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
palettes={
    'mistport-night':((.016,.011,.025),(.072,.018,.15),(.018,.22,.25)),
    'starlight-magician':((.62,.58,.47),(.035,.055,.19),(.025,.23,.28)),
    'midnight-carnival':((.055,.016,.024),(.35,.018,.032),(.36,.035,.028))}
for outfit,(coat,silk,sash) in palettes.items():
    color('Hero Coat Charcoal',coat);color('Hero Violet Silk',silk);color('Hero Teal Sash',sash)
    for obj in scene.objects:
        if obj.name=='Hero Starlight Motifs':obj.hide_render=outfit!='starlight-magician'
        if obj.name=='Hero Carnival Motifs':obj.hide_render=outfit!='midnight-carnival'
    for view,yaw in [('back',0),('three-quarter',.56)]:
        camera(yaw);scene.frame_set(0);scene.render.filepath=str(DOC/(outfit+'-'+view+'-blender.png'));bpy.ops.render.render(write_still=True)
print('HERO_MODEL_RENDERED six Blender views')
