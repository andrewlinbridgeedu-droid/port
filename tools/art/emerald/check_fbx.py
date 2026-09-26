import bpy, sys, os
from mathutils import Vector
src, outdir = sys.argv[-2:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
actions = {a.name:a for a in bpy.data.actions}
target=Vector((0,0,.9)); cam_data=bpy.data.cameras.new('Camera'); cam=bpy.data.objects.new('Camera',cam_data); bpy.context.scene.collection.objects.link(cam); bpy.context.scene.camera=cam; cam.location=(0,-3.5,.95); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler(); cam_data.lens=58
ld=bpy.data.lights.new('Key','AREA'); ld.energy=950; ld.size=4; lo=bpy.data.objects.new('Key',ld); bpy.context.scene.collection.objects.link(lo); lo.location=(1.5,-2.6,2.7); lo.rotation_euler=(target-lo.location).to_track_quat('-Z','Y').to_euler(); world=bpy.context.scene.world or bpy.data.worlds.new('World'); bpy.context.scene.world=world; world.color=(.02,.02,.02)
bpy.context.scene.render.engine='BLENDER_EEVEE'; bpy.context.scene.render.resolution_x=512; bpy.context.scene.render.resolution_y=700; bpy.context.scene.render.resolution_percentage=100
for name, frame, output_name in [('Armature|Scene',96,'emerald-charge-fbx'),('Armature|Scene',150,'emerald-cast-fbx')]:
    action=next(iter(actions.values()),None)
    if action is None: print('MISSING_ACTION',name); continue
    arm.animation_data_create(); arm.animation_data.action=action; bpy.context.scene.frame_set(frame); bpy.context.view_layer.update(); bpy.context.scene.render.filepath=os.path.join(outdir,output_name+'.png'); bpy.ops.render.render(write_still=True)
