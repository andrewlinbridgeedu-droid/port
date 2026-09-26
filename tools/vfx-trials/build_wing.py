import bpy, math, os
base='/Users/andrewlin/Downloads/DEV_Projects/mindstone-game'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
v=[];f=[];uv=[]
for j in range(17):
 for i in range(49):
  u=i/48; t=j/16
  v.append((u-.5,-math.sin(u*math.pi)*.35 - .1*math.sin(t*math.pi)*u,t));uv.append((u,t))
for j in range(16):
 for i in range(48):
  a=j*49+i;f.append((a,a+1,a+50,a+49))
m=bpy.data.meshes.new('Phoenix shallow curved membrane');m.from_pydata(v,[],f);m.update()
o=bpy.data.objects.new('PhoenixWingShell',m);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True)
layer=m.uv_layers.new(name='PhoenixArtworkUV')
for p in m.polygons:
 for li in p.loop_indices: layer.data[li].uv=uv[m.loops[li].vertex_index]
os.makedirs(base+'/ArtSource/ReferenceSpells20260921',exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=base+'/ArtSource/ReferenceSpells20260921/PhoenixWing.blend')
bpy.ops.export_scene.fbx(filepath=base+'/UnityBattleSource/Assets/VFX_Trials/Meshes/PhoenixWing.fbx',use_selection=True,axis_forward='-Z',axis_up='Y',bake_space_transform=True)
