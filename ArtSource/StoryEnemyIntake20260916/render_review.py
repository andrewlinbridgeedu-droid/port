import bpy, math, json
from pathlib import Path
from mathutils import Vector
names=['Iron_Star_Sentinel_0916094930','Iron_Vanguard_0916102127','Ironclad_Sentinel_0916101320','The_Burdened_Brawler_0916102202','The_Marionette_Schola_0916102225']
out=Path('/Users/andrewlin/Downloads/DEV_Projects/mindstone-game/output/five-enemy-review-20260916')
stats=[]
for name in names:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(Path('/Users/andrewlin/Downloads')/('Meshy_AI_'+name+'_texture.glb')))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
 lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
 center=(lo+hi)/2;h=max(hi.z-lo.z,hi.x-lo.x)
 stats.append({'name':name,'vertices':sum(len(o.data.vertices) for o in meshes),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'meshes':len(meshes),'armatures':len([o for o in bpy.context.scene.objects if o.type=='ARMATURE']),'bounds':list(hi-lo)})
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
 scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.18,.22,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
 for pos,power,size in [((2,-4,5),1200,4),((-3,-2,2),750,3),((1,3,4),1000,3)]:
  bpy.ops.object.light_add(type='AREA',location=center+Vector(pos)*h/3);lamp=bpy.context.object;lamp.data.energy=power*(h/2)**2;lamp.data.shape='DISK';lamp.data.size=size*h/3;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=center+Vector((.2,-3,.35))*h);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=h*1.3;scene.camera=cam
 scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
 scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
 (out/'statistics.json').write_text(json.dumps(stats,indent=2))
