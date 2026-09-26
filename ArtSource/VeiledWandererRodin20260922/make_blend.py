import os

import bpy


root = os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=os.path.join(root, "base_basic_pbr.glb"))
bpy.ops.file.pack_all()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "VeiledWanderer_Rodin.blend"))
