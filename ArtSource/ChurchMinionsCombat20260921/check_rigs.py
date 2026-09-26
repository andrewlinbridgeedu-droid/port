import bpy,json,sys,numpy as np
from pathlib import Path
R=Path(__file__).resolve().parent
names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['Copperback','CrimsonBrute','VeilOracle','GoldenThroat','Moonfang']
for n in names:
 bpy.ops.wm.open_mainfile(filepath=str(R/n/(n+'_Combat.blend')))
 arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');m=next(o for o in bpy.context.scene.objects if o.type=='MESH');s=bpy.context.scene
 unweighted=sum(1 for v in m.data.vertices if not v.groups or sum(g.weight for g in v.groups)<.99)
 too_many=sum(1 for v in m.data.vertices if len([g for g in v.groups if g.weight>.00001])>4)
 result={'name':n,'vertices':len(m.data.vertices),'triangles':sum(len(p.vertices)-2 for p in m.data.polygons),'bones':len(arm.data.bones),'unweighted':unweighted,'over_four_weights':too_many,'frames':{}}
 for f in [1,31,61,91,121,166,167,182,196,203,244,289,290,305,319,359]:
  s.frame_set(f);dg=bpy.context.evaluated_depsgraph_get();ev=m.evaluated_get(dg);me=ev.to_mesh();v=np.array([x.co[:] for x in me.vertices]);result['frames'][f]={'finite':bool(np.isfinite(v).all()),'bounds':[v.min(0).tolist(),v.max(0).tolist()]};ev.to_mesh_clear()
 result['seams']={}
 for a,b in [(1,121),(121,122),(166,167),(289,290),(196,1),(319,1),(208,1),(359,1)]:
  s.frame_set(a);first={p.name:(p.rotation_quaternion.copy(),p.location.copy(),p.scale.copy()) for p in arm.pose.bones};s.frame_set(b)
  result['seams'][str((a,b))]={'max_radians':max(first[p.name][0].rotation_difference(p.rotation_quaternion).angle for p in arm.pose.bones),'max_location':max((first[p.name][1]-p.location).length for p in arm.pose.bones),'max_scale':max((first[p.name][2]-p.scale).length for p in arm.pose.bones)}
 (R/n/'rig-check.json').write_text(json.dumps(result,indent=2));print('RIG_CHECK',json.dumps({k:v for k,v in result.items() if k!='frames'}),flush=True)
