"""Encode only B02's latest Unity captures; preserve contact and sustained motion evidence."""
from pathlib import Path
import sys,subprocess
sys.path.insert(0,'/tmp/mistport-vfx-encode')
import imageio_ffmpeg
root=Path(__file__).resolve().parents[2]
out=root/'output/all-spells-polish-20260921'
ff=imageio_ffmpeg.get_ffmpeg_exe()
for name,keep in [('bounty-b02-bind',{0,10,18,20,21,22,23,24,25,26,27,28,30,35,59}),('bounty-bindings-state',{0,15,30,60,90,120,149})]:
 frames=sorted((out/name).glob('frame-*.png'))
 if len(frames)>10 and [int(p.stem.split("-")[1]) for p in frames]==list(range(len(frames))):
  subprocess.run([ff,'-y','-framerate','30','-i',str(out/name/'frame-%03d.png'),'-c:v','libx264','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(out/(name+'.mp4'))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 subprocess.run([ff,'-v','error','-i',str(out/(name+'.mp4')),'-f','null','-'],check=True)
 for p in frames:
  if int(p.stem.split('-')[1]) not in keep:p.unlink()
 print(name,'encoded and decoded')
