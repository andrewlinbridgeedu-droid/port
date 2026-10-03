import bpy,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(sys.argv[sys.argv.index('--')+1]);DOC=ROOT/'docs/development/hero-refinement-20261001'
def load(path):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path))
 obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
 verts=[obj.matrix_world@v.co for v in obj.data.vertices]
 lo=Vector(tuple(min(v[i] for v in verts) for i in range(3)));hi=Vector(tuple(max(v[i] for v in verts) for i in range(3)))
 center=(lo+hi)*.5;scale=175/(hi.z-lo.z)
 return [(v-center)*scale for v in verts],[list(p.vertices) for p in obj.data.polygons]
a,fa=load(DOC/'meshy-source/original.glb');b,fb=load(DOC/'meshy-untextured-source/original.glb')
tree=BVHTree.FromPolygons(a,fa);distances=sorted(tree.find_nearest(p)[3] for p in b)
result={'method':'Normalize both imported geometries to 175 cm high, compare new vertices to nearest old triangles','median_cm':distances[len(distances)//2],'p95_cm':distances[int(len(distances)*.95)],'maximum_cm':max(distances),'within_0_5_cm_fraction':sum(d<.5 for d in distances)/len(distances),'exact_mesh_identity_claimed':False}
(DOC/'meshy-shape-comparison.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
