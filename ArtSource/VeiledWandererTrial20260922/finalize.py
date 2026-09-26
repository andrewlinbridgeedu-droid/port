import bpy,os,math
from math import sin,cos,pi
ROOT=os.path.dirname(os.path.abspath(__file__))
scene=bpy.context.scene
# Soften the small crossed front sash; avoid a flat rectangular patch.
def apron(u,v):
 x=-.085+.23*v+.013*sin(u*6+v*3)*u
 y=-.137+.014*sin(v*11+u*9)*u+.016*cos(v*4)*u-.008*v
 z=1.39-u*(.16+.20*v**1.6)+.02*sin(v*pi)
 return(x,y,z)
o=bpy.data.objects['Asymmetric opaque front waist fold']
for i in range(19):
 for j in range(21):o.data.vertices[i*21+j].co=apron(i/18,j/20)
c=bpy.data.objects['Waist diagonal folded hem']
for j,b in enumerate(c.data.splines[0].bezier_points):b.co=apron(.98,j/30)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'VeiledWanderer_Trial.blend'))
for o in bpy.context.scene.objects:o.select_set(False)
for collection in bpy.data.collections:
 if collection.name=='Studio':continue
 for o in collection.objects:o.select_set(True)
exec(compile(open(os.path.join(ROOT,'export_glb.py')).read(),os.path.join(ROOT,'export_glb.py'),'exec'))
print('FINAL_MODEL_EXPORTED',flush=True)
exec(compile(open(os.path.join(ROOT,'render_views.py')).read(),os.path.join(ROOT,'render_views.py'),'exec'))
