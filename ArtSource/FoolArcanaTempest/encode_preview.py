import bpy
from pathlib import Path
root=Path('/Users/andrewlin/Downloads/DEV_Projects/mindstone-game/artifacts/fool-arcana-tempest')
s=bpy.context.scene
s.sequence_editor_create()
strip=s.sequence_editor.strips.new_image('Actual Unity renders',str(root/'frame-000.png'),channel=1,frame_start=1)
for i in range(1,120):strip.elements.append('frame-%03d.png'%i)
s.frame_start=1;s.frame_end=120;s.render.resolution_x=720;s.render.resolution_y=1080;s.render.resolution_percentage=100;s.render.fps=20
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.filepath=str(root/'Fool-Arcana-Tempest.mp4')
bpy.ops.render.render(animation=True)
