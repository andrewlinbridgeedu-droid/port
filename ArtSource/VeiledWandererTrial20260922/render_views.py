import bpy,os,math,json,sys
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
OUT=os.path.abspath(os.path.join(ROOT,'../../output/veiled-wanderer-trial-20260922'))
scene=bpy.context.scene;cam=scene.camera
scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
views=[('front',(0,-8,2.9),(0,0,1.31),3.05),('three-quarter',(3.7,-8,3.0),(0,0,1.31),3.05),('side',(8,0,2.65),(0,0,1.31),3.05),('back',(0,8,2.9),(0,0,1.31),3.05),('portrait',(2.5,-8,2.8),(0,0,2.02),1.23)]
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if args:views=[v for v in views if v[0] in args]
for name,loc,target,scale in views:
 cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 scene.render.filepath=os.path.join(OUT,name+'.png');bpy.ops.render.render(write_still=True)
 print('RENDERED',name,flush=True)
