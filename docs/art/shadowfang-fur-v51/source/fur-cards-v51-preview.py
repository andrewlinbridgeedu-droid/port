"""Static Blender look at the v49 cards (front, three-quarter, side). Placement
check only: the review that counts is the Unity runtime recording."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector

OUT = Path("/Volumes/andrew's SSD/Downloads/mindstone-game/.build/character-polish-20261015/shadowfang/fur-v51")
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'shadowfang-furcards-v51.blend'))
s = bpy.context.scene
s.render.engine = 'BLENDER_EEVEE'
s.render.resolution_x = s.render.resolution_y = 900
s.render.film_transparent = False
s.world = s.world or bpy.data.worlds.new('World')
s.world.use_nodes = True
s.world.node_tree.nodes['Background'].inputs[0].default_value = (.12, .13, .16, 1)
s.world.node_tree.nodes['Background'].inputs[1].default_value = .6
mat = bpy.data.materials['FurCards']
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes.get('Principled BSDF') or nt.nodes.new('ShaderNodeBsdfPrincipled')
tex = nt.nodes.new('ShaderNodeTexImage')
tex.image = bpy.data.images.load(str(OUT / 'FurStrands.png'))
tone = nt.nodes.new('ShaderNodeVertexColor'); tone.layer_name = 'AnatomyTone'
mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = 1
gain = nt.nodes.new('ShaderNodeMix'); gain.data_type = 'RGBA'; gain.blend_type = 'MULTIPLY'; gain.inputs['Factor'].default_value = 1
gain.inputs[7].default_value = (2, 2, 2, 1)
nt.links.new(tone.outputs['Color'], mix.inputs[6]); nt.links.new(tex.outputs['Color'], mix.inputs[7])
nt.links.new(mix.outputs[2], gain.inputs[6]); nt.links.new(gain.outputs[2], bsdf.inputs['Base Color'])
nt.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
bsdf.inputs['Roughness'].default_value = .8
mat.surface_render_method = 'DITHERED'
mat.use_backface_culling = False
sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
s.collection.objects.link(sun); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
s.collection.objects.link(cam); s.camera = cam
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 2.4
target = Vector((0, -.6, .05))
views = [('front', 0, target, 2.4, .9), ('three-quarter', 40, target, 2.4, .9), ('side', 90, Vector((0, 0, .05)), 3.4, .9),
         ('head-top', 20, Vector((0, -.95, .6)), 1.0, 3.0), ('tail', 140, Vector((0, 1.15, .0)), 1.3, 1.2)]
for name, angle, target, scale, lift in views:
    a = math.radians(angle)
    cam.data.ortho_scale = scale
    cam.location = target + Vector((-math.sin(a) * 6, -math.cos(a) * 6, lift))
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    s.render.filepath = str(OUT / f'blender-{name}.png')
    bpy.ops.render.render(write_still=True)
print('FUR_PREVIEW_V51_DONE')
