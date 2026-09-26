# -*- coding: utf-8 -*-
import bpy,json,math,os,hashlib,datetime,struct
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
source=os.path.join(ROOT,'VeiledWanderer_Trial.glb')
source_sha=hashlib.sha256(open(source,'rb').read()).hexdigest()
source_bytes=os.path.getsize(source)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT,'VeiledWanderer_Trial.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
verts=[];tris=0;bad=[]
for ob in meshes:
 ob.data.calc_loop_triangles();tris+=len(ob.data.loop_triangles)
 for v in ob.data.vertices:
  q=ob.matrix_world@v.co
  if not all(math.isfinite(a) for a in q):bad.append(ob.name)
  verts.append(q)
lo=[min(v[i] for v in verts) for i in range(3)];hi=[max(v[i] for v in verts) for i in range(3)]
names=[o.name for o in meshes]
checks={'full_head':any('Sculpted head' in n for n in names),'pipe_curve_exported':any('Long slender sandalwood pipe' in n for n in names),'eyelids_exported':any('Upper eyelid and lashes' in n for n in names),'solid_garments':any('open brocade lapel' in n for n in names),'hat':any('Asymmetric torn brim' in n for n in names),'back_geometry':any('Back coat panel' in n for n in names),'gold_vines':any('gold vine' in n for n in names),'finite_vertices':not bad,'no_studio':not any('Studio' in n or 'plinth' in n for n in names)}
f=open(source,'rb');f.read(12);count,kind=struct.unpack('<II',f.read(8));document=json.loads(f.read(count))
material_colors={m['name']:m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1]) for m in document.get('materials',[])}
expected={'Black violet brocade':(.006,.004,.011),'Ink plum silk • woven':(.011,.007,.021),'Peacock teal lining':(.012,.123,.118),'Deep teal satin':(.008,.062,.072),'Aged talisman paper':(.53,.42,.23)}
checks['authored_PBR_colors_preserved']=all(name in material_colors and max(abs(material_colors[name][i]-rgb[i]) for i in range(3))<1e-5 for name,rgb in expected.items())
assert all(checks.values()),checks
r={'mesh_objects':len(meshes),'triangles':tris,'materials':len(bpy.data.materials),'bounds_min':lo,'bounds_max':hi,'dimensions':[hi[i]-lo[i] for i in range(3)],'validation':'GLB actually reimported in fresh Blender scene','checks':checks,'has_armature':any(o.type=='ARMATURE' for o in bpy.context.scene.objects)}
assert hashlib.sha256(open(source,'rb').read()).hexdigest()==source_sha, 'Source changed during import'
r.update(source_sha256=source_sha,source_bytes=source_bytes,validated_at=datetime.datetime.now().astimezone().isoformat(),material_base_colors=material_colors)
with open(os.path.join(ROOT,'glb_validation.json'),'w') as f:json.dump(r,f,indent=2)
print('GLB_VALIDATION_PASSED',json.dumps(r))
