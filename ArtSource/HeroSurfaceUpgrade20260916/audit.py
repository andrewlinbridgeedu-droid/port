import bpy,json,math
from pathlib import Path
R=Path('/Users/andrewlin/Downloads/DEV_Projects/mindstone-game')
src=R/'UnityBattleSource/Assets/Models/Fool/Meshy_AI_battle_magician_rig_biped_Animation_Combat_Stance_frame_rate_60.fbx'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(src))
report=[]
for o in bpy.data.objects:
 if o.type!='MESH':continue
 m=o.data;adj={};ln=[n.vector.copy() for n in m.corner_normals]
 for p in m.polygons:
  for li in p.loop_indices:
   loop=m.loops[li];adj.setdefault(loop.edge_index,[]).append(p.index)
 shallow=0;broken=0;angles=[]
 for ei,ps in adj.items():
  if len(ps)!=2:continue
  a,b=[m.polygons[x] for x in ps];ang=math.degrees(a.normal.angle(b.normal));
  if ang>35:continue
  shallow+=1
  na={m.loops[i].vertex_index:ln[i] for i in a.loop_indices};nb={m.loops[i].vertex_index:ln[i] for i in b.loop_indices}
  if any(math.degrees(na[v].angle(nb[v]))>8 for v in set(na)&set(nb)):broken+=1
 report.append(dict(name=o.name,vertices=len(m.vertices),faces=len(m.polygons),materials=[x.name for x in m.materials],custom=m.has_custom_normals,smooth=sum(p.use_smooth for p in m.polygons),shallow_edges=shallow,discontinuous_shallow_edges=broken))
(R/'ArtSource/HeroSurfaceUpgrade20260916/audit.json').write_text(json.dumps(report,indent=2));print(report)
