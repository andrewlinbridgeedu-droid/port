# -*- coding: utf-8 -*-
import bpy,os
ROOT=os.path.dirname(os.path.abspath(__file__))
for o in bpy.context.scene.objects:o.select_set(False)
for c in bpy.data.collections:
 if c.name=='Studio':continue
 for o in c.objects:o.select_set(True)
# glTF cannot encode procedural Noise/ColorRamp. Use the authored base PBR
# colors for interchange; the .blend keeps the complete procedural network.
saved=[]
for m in bpy.data.materials:
 if not m.use_nodes:continue
 p=m.node_tree.nodes.get('Principled BSDF')
 if not p:continue
 for name in ['Base Color','Normal']:
  for link in list(p.inputs[name].links):
   saved.append((m.node_tree,link.from_socket,link.to_socket));m.node_tree.links.remove(link)
 p.inputs['Base Color'].default_value=m.diffuse_color
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'VeiledWanderer_Trial.glb'),export_format='GLB',use_selection=True,export_apply=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
for tree,fr,to in saved:tree.links.new(fr,to)
print('PBR_BASE_COLORS_EXPORTED',flush=True)
