"""Offline skin diagnostics; does not claim artistic acceptance or device fitness."""
import bpy, json, sys, numpy as np
from pathlib import Path
root=Path(sys.argv[sys.argv.index('--')+1]);doc=root/'docs/development/hero-refinement-20261001/v4'
bpy.ops.wm.open_mainfile(filepath=str(doc/'HeroSovereign-v4.blend'))
rig=bpy.data.objects['HeroSovereignV4'];scene=bpy.context.scene
assert len(rig.data.bones)==50
report={'bones':50,'maxWeights':4,'poses':[],'userVisualApproval':False}
for key in ['night','starlight','carnival']:
 obj=bpy.data.objects['Outfit-'+key+'-Sovereign']
 for v in obj.data.vertices:
  assert 1<=len(v.groups)<=4
  assert abs(sum(g.weight for g in v.groups)-1)<.0001
 edges=np.array([e.vertices[:] for e in obj.data.edges]);base=np.array([v.co[:] for v in obj.data.vertices])
 lengths=np.linalg.norm(base[edges[:,0]]-base[edges[:,1]],axis=1);valid=lengths>.25
 for clip in [entry['name'] for entry in json.loads((doc/'manifest.json').read_text())['clips']]:
  action=bpy.data.actions[clip];rig.animation_data.action=action
  for phase in [0,.2,.34,.58,.72,1]:
   scene.frame_set(round(action.frame_range[1]*phase));graph=bpy.context.evaluated_depsgraph_get();mesh=obj.evaluated_get(graph).to_mesh()
   deformed=np.array([v.co[:] for v in mesh.vertices]);assert np.isfinite(deformed).all()
   ratio=np.linalg.norm(deformed[edges[:,0]]-deformed[edges[:,1]],axis=1)[valid]/lengths[valid]
   i=np.argmax(ratio);edge=edges[valid][i];point=(base[edge[0]]+base[edge[1]])/2
   report['poses'].append({'outfit':key,'clip':clip,'phase':phase,'maxEdgeStretch':float(ratio.max()),'p99EdgeStretch':float(np.quantile(ratio,.99)),'worstSourcePositionCM':point.tolist(),'edgesOver3x':int((ratio>3).sum()),'maxUpperBodyEdgeStretch':float(ratio[((base[edges[valid,0]]+base[edges[valid,1]])/2)[:,2]>110].max()),'maxHandEdgeStretch':float(ratio[np.abs(((base[edges[valid,0]]+base[edges[valid,1]])/2)[:,0])>63].max())})
   obj.evaluated_get(graph).to_mesh_clear()
 print('SKIN_CHECKED',key,flush=True)
report['totalPoses']=len(report['poses'])
report['maxEdgeStretch']=max(p['maxEdgeStretch'] for p in report['poses'])
report['noNonFiniteVertices']=True;report['allWeightsNormalized']=True
(doc/'skin-diagnostics.json').write_text(json.dumps(report,indent=2)+'\n')
print('SKIN_REPORT',report['totalPoses'],report['maxEdgeStretch'],flush=True)
