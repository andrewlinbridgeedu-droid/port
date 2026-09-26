# coding: utf-8
from pathlib import Path
import subprocess,sys,shutil
sys.path.insert(0,'/tmp/mistport-vfx-encode')
import imageio_ffmpeg
r=Path(__file__).resolve().parents[2]/'output/target-instances-20260921';ff=imageio_ffmpeg.get_ffmpeg_exe();cards=[]
for n in (1,2,3):
 for k,title in [('phoenix','凤凰虹翼'),('rift','裂界炎途'),('thunder','霜雷裁决')]:
  key=f'{k}-{n}';frames=r/'frames'/key
  if not frames.exists():continue
  assert len(list(frames.glob('frame-*.png')))==96,key
  subprocess.run([ff,'-y','-framerate','30','-i',str(frames/'frame-%03d.png'),'-c:v','libx264','-crf','17','-pix_fmt','yuv420p',str(r/(key+'.mp4'))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  subprocess.run([ff,'-v','error','-i',str(r/(key+'.mp4')),'-f','null','-'],check=True)
  cards.append(f'<article><h2>{title} · {n}目标</h2><video controls muted loop src="{key}.mp4"></video></article>')
(r/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>逐目标法术实例</title><style>body{background:#17121f;color:#eee;font:16px system-ui;margin:30px}main{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}video{width:100%}button{padding:12px;font:inherit}@media(max-width:800px){main{grid-template-columns:1fr}}</style><h1>逐目标独立实例</h1><p>场上保留三敌，用实际选中人数对比；未选中敌人不生成命中特效。仍为试演，不改变正式技能目标规则。</p><button onclick="document.querySelectorAll('video').forEach(v=>{v.currentTime=0;v.play()})">同步重播</button><main>'''+''.join(cards)+'</main>')
print(len(cards),'clips exported')
