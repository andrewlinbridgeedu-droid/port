# -*- coding: utf-8 -*-
import bpy,os
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
exec(compile(open(os.path.join(ROOT,'validate_glb.py'),encoding='utf8').read(),os.path.join(ROOT,'validate_glb.py'),'exec'))
# Append the same studio, but all character geometry/materials here come from
# the final GLB that was actually imported into the factory-empty scene.
with bpy.data.libraries.load(os.path.join(ROOT,'VeiledWanderer_Trial.blend'),link=False) as (frm,to):to.collections=['Studio']
for c in to.collections:
 if c and c.name not in bpy.context.scene.collection.children:bpy.context.scene.collection.children.link(c)
scene=bpy.context.scene
cam=next(o for o in scene.objects if o.type=='CAMERA');scene.camera=cam
cam.location=(0,-8,2.9);cam.rotation_euler=(Vector((0,0,1.31))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=3.05
world=bpy.data.worlds.new('GLB validation studio world');world.use_nodes=True
world.node_tree.nodes.get('Background').inputs[0].default_value=(.14,.165,.19,1);world.node_tree.nodes.get('Background').inputs[1].default_value=.35;scene.world=world
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.render.resolution_x=550;scene.render.resolution_y=750;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG';scene.render.filepath=os.path.abspath(os.path.join(ROOT,'../../output/veiled-wanderer-trial-20260922/glb-import-check.png'))
bpy.ops.render.render(write_still=True)
print('FINAL_GLB_VISUAL_PREVIEW_RENDERED',flush=True)
