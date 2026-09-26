import bpy, math, random
from pathlib import Path
root=Path('/Users/andrewlin/Downloads/DEV_Projects/mindstone-game')
out=root/'UnityBattleSource/Assets/Resources/Mindstone/VFXV1/Spells/storm-fool-arcana-v1'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
random.seed(73013)
def strip(name,phase,turns,width):
    vs=[]; fs=[]; uv=[]
    for j in range(161):
        t=j/160; h=t*5.8; r=.22+2.15*t**.8
        for k in range(5):
            s=k/4-.5; a=phase+t*math.tau*turns+s*width
            rr=r*(1+.065*math.sin(t*33+phase)+.035*math.sin(t*71+s*9))
            vs.append((rr*math.cos(a),rr*math.sin(a),h+s*.18*math.sin(t*22+phase)))
            uv.append((k/4,t))
        if j:
            for k in range(4):
                a=(j-1)*5+k; fs.append((a,a+1,a+6,a+5))
    m=bpy.data.meshes.new(name); m.from_pydata(vs,[],fs); m.update()
    ob=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(ob)
    u=m.uv_layers.new(name='UVMap')
    for poly in m.polygons:
        poly.use_smooth=True
        for li in poly.loop_indices:u.data[li].uv=uv[m.loops[li].vertex_index]
for i in range(8):strip('WindRibbon_%02d'%i,i*math.tau/8,1.65+(i%3)*.13,.48+(i%2)*.24)
for i in range(3):strip('InnerVortex_%02d'%i,i*math.tau/3,-1.4,.9)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'ArtSource/FoolArcanaTempest/FoolArcanaTempest.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.fbx(filepath=str(out/'ArcanaTornado.fbx'),use_selection=True,axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False)
print('EXPORTED',out/'ArcanaTornado.fbx')
