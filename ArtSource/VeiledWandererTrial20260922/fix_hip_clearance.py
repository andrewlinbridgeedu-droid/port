# -*- coding: utf-8 -*-
import bpy,math,os
from math import sin,cos,pi
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
for k in range(7):
 ob=bpy.data.objects['Back coat panel %02d'%k]
 a0=-pi/2+.49+k*(2*pi-.98)/7;a1=-pi/2+.49+(k+1)*(2*pi-.98)/7
 for i in range(31):
  for j in range(17):
   u=i/30;v=j/16;phi=a0+(a1-a0)*v
   top=1.87-.04*abs(cos(phi));bottom=[.44,.23,.37,.19,.52,.31,.61][k]+.025*sin(v*13+k)+.03*(v-.5)**2
   z=top*(1-u)+bottom*u;clearance=math.exp(-((z-1.22)/.17)**2)
   r=.217-.067*sin(pi*min(1,u*1.45))+.10*u*u+.05*clearance
   fold=.011*sin(v*pi*5+u*4+k)+.006*sin(v*pi*11-u*3)
   x=(r+fold)*cos(phi);y=(r*.76+fold)*sin(phi)+.018+u*u*.045+.028*clearance*max(0,sin(phi))
   ob.data.vertices[i*17+j].co=(x,y,z)
# Embroidery that is on the adjusted back panels follows the same radial relief.
def deform(p):
 x,y,z=p;g=math.exp(-((z-1.22)/.17)**2);phi=math.atan2((y-.03)/.76,x)
 return(x+.05*g*cos(phi),y+.05*g*.76*sin(phi)+.028*g*max(0,sin(phi)),z)
for ob in bpy.context.scene.objects:
 if not ob.name.startswith('Back coat '):continue
 if ob.name.startswith('Back coat panel'):continue
 if ob.type=='MESH':
  for v in ob.data.vertices:v.co=deform(v.co)
 elif ob.type=='CURVE':
  for spline in ob.data.splines:
   for b in spline.bezier_points:b.co=deform(b.co)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'VeiledWanderer_Trial.blend'))
exec(compile(open(os.path.join(ROOT,'export_glb.py'),encoding='utf8').read(),os.path.join(ROOT,'export_glb.py'),'exec'))
scene=bpy.context.scene;scene.cycles.samples=12;scene.cycles.use_denoising=True;scene.render.resolution_x=440;scene.render.resolution_y=600;scene.render.resolution_percentage=100
cam=scene.camera
for name,loc in [('side-clearance',(8,0,2.65)),('back-clearance',(0,8,2.9))]:
 cam.location=loc;cam.rotation_euler=(Vector((0,0,1.31))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=3.05
 scene.render.filepath=os.path.abspath(os.path.join(ROOT,'../../output/veiled-wanderer-trial-20260922',name+'.png'));bpy.ops.render.render(write_still=True)
print('HIP_CLEARANCE_PATCH_COMPLETE',flush=True)
