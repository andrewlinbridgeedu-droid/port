import bpy,numpy as np,json,sys
from pathlib import Path
R=Path(__file__).resolve().parent
S={'Copperback':'Copperback_Behemoth_0921062650','CrimsonBrute':'Crimson_Brute_0921062707','VeilOracle':'Crimson_Veil_Oracle_0921065936','GoldenThroat':'Golden_Throated_Tree__0921062700','Moonfang':'Moonfang_Mouse_0921063524'}
for name,source in S.items():
 r=R/name;r.mkdir(exist_ok=True)
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(R.parent/'ChurchMinions20260921'/('Meshy_AI_'+source+'_texture.glb')))
 m=next(o for o in bpy.context.scene.objects if o.type=='MESH');bpy.context.view_layer.objects.active=m;m.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 v=np.array([v.co[:] for v in m.data.vertices]);lo=v.min(0);hi=v.max(0);v-=[(lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]];v*=2/(hi[2]-lo[2]);m.data.vertices.foreach_set('co',v.ravel());m.data.update()
 print('BOUNDS',name,v.min(0),v.max(0),flush=True)
 for im in list(bpy.data.images):
  if im.size[0]>0:
   if max(im.size)>2048:im.scale(2048,2048)
   im.filepath_raw=str(r/(im.name+'_2k.png'));im.file_format='PNG';im.save()
 w=m.modifiers.new('CoincidentWeld','WELD');w.merge_threshold=.000002;bpy.ops.object.modifier_apply(modifier=w.name)
 count=sum(len(p.vertices)-2 for p in m.data.polygons)
 d=m.modifiers.new('MobileReduction','DECIMATE');d.ratio=min(1,50000/count);d.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=d.name)
 for p in m.data.polygons:p.use_smooth=True
 m.name=name+'Body';bpy.ops.wm.save_as_mainfile(filepath=str(r/'Prepared.blend'))
 np.save(r/'vertices.npy',np.array([v.co[:] for v in m.data.vertices]));(r/'manifest.json').write_text(json.dumps({'source':source,'source_triangles':count,'triangles':len(m.data.polygons),'bounds':[v.min(0).tolist(),v.max(0).tolist()]}))
 print('PREPARED',name,len(m.data.polygons),flush=True)
