from pathlib import Path
import sys,subprocess,shutil
sys.path.insert(0,'/tmp/mistport-vfx-encode')
import imageio_ffmpeg
r=Path(__file__).resolve().parents[2]/'output/rift-depth-20260921';ff=imageio_ffmpeg.get_ffmpeg_exe()
assert len(list((r/'frames/rift').glob('frame-*.png')))==96
subprocess.run([ff,'-y','-framerate','30','-i',str(r/'frames/rift/frame-%03d.png'),'-c:v','libx264','-crf','17','-pix_fmt','yuv420p',str(r/'rift.mp4')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
subprocess.run([ff,'-v','error','-i',str(r/'rift.mp4'),'-f','null','-'],check=True)
shutil.copy2(r/'frames/rift/frame-038.png',r/'rift-poster.png')
(r/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>裂界炎途 · 裂口立体试演</title><style>body{background:#14111b;color:#eee;font:18px system-ui;max-width:800px;margin:30px auto}video{width:100%;max-height:80vh}button,a{font:inherit;color:#edcb89;margin:12px;background:#302637;padding:10px;border:1px solid #807052}p{color:#bab3c2}</style><h1>裂界炎途 · 裂口立体试演</h1><p>保留连续裂口，抬起金色内壁、加入侧面明暗与低位热浪卷动。Unity 独立试演，尚未接入正式技能。</p><video controls autoplay loop muted src="rift.mp4" poster="rift-poster.png"></video><button onclick="document.querySelector('video').currentTime=0;document.querySelector('video').play()">重播</button><a href="rift-poster.png">命中大图</a>''')
for p in (r/'frames/rift').glob('frame-*.png'):
 if int(p.stem.split('-')[1]) not in {0,20,29,32,34,38,65,95}:p.unlink()
print(r/'index.html')
