from pathlib import Path
import subprocess, sys, shutil, json
sys.path.insert(0,'/tmp/mistport-vfx-encode')
import imageio_ffmpeg
root=Path(__file__).resolve().parents[2]/'output/two-spells-extreme-20260921'
ff=imageio_ffmpeg.get_ffmpeg_exe()
rows=[('phoenix','虹翼天幕','连续虹翼卷起前冲，金色羽光在敌人身上爆开',35),('thunder','霜雷裁决','纵向落雷、冰晶外掀，蓝白电芒在落点炸散',30)]
for key,title,desc,poster in rows:
 frames=root/'frames'/key
 if len(list(frames.glob('frame-*.png')))!=96:raise RuntimeError(f'{key}: incomplete frames')
 subprocess.run([ff,'-y','-framerate','30','-i',str(frames/'frame-%03d.png'),'-c:v','libx264','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(root/(key+'.mp4'))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 subprocess.run([ff,'-y','-i',str(root/(key+'.mp4')),'-filter_complex','[0:v]fps=15,scale=432:-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',str(root/(key+'.gif'))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 shutil.copy2(frames/f'frame-{poster:03}.png',root/(key+'-poster.png'))
cards=''.join(f'''<article><div class="cap"><small>0{i+1}</small><h2>{name}</h2><p>{desc}</p></div><video controls autoplay muted loop playsinline preload="auto" poster="{k}-poster.png" src="{k}.mp4"></video><footer><button onclick="playOne(this)">重播这一招</button><button onclick="freeze(this)">定格命中</button><a href="{k}.mp4">放大视频</a><a href="{k}.gif">GIF</a><a href="{k}-poster.png">命中截图</a><a href="{k}-no-bloom.png">无辉光</a></footer></article>''' for i,(k,name,desc,_) in enumerate(rows))
html='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>虹翼与冰雷 · 强冲击试演</title><style>
*{box-sizing:border-box}body{margin:0;background:#111018;color:#efedf4;font:16px/1.6 -apple-system,BlinkMacSystemFont,sans-serif}main{max-width:1480px;margin:auto;padding:40px 28px}header{display:flex;justify-content:space-between;align-items:center;gap:20px;margin-bottom:28px}h1{font-size:32px;font-weight:550;margin:4px 0}p{color:#b0aabb;margin:8px 0}small{color:#d2b477;letter-spacing:3px}button,a{color:#f4dfb8;border:1px solid #68573f;border-radius:6px;padding:9px 14px;background:#292337;font:inherit;text-decoration:none;cursor:pointer}button:hover,a:hover{background:#3a3049}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}article{background:#1c1926;border:1px solid #393242;border-radius:12px;overflow:hidden}.cap{padding:18px 20px}h2{margin:2px 0;font-size:24px}.cap p{font-size:14px;min-height:44px}video{display:block;width:100%;aspect-ratio:9/16;background:#07060b}footer{display:flex;gap:8px;flex-wrap:wrap;padding:16px;font-size:13px}.note{margin-top:26px;font-size:14px;color:#aaa2b7}select{background:#292337;color:#fff;padding:10px;border:1px solid #655b73;border-radius:6px}@media(max-width:850px){.grid{grid-template-columns:1fr}header{display:block}.actions{margin-top:15px}}
</style><main><header><div><small>UNITY · REFERENCE SPELL STUDIES</small><h1>虹翼与冰雷 · 强冲击试演</h1><p>凤凰虹翼 / 冰雷晶簇</p></div><div class="actions"><button onclick="replay()">两招同步重播</button> <select aria-label="播放速度" onchange="document.querySelectorAll('video').forEach(v=>v.playbackRate=+this.value)"><option value="1">正常速度</option><option value="0.5">半速看细节</option></select></div></header><div class="grid">'''+cards+'''</div><p class="note">真实 Unity 战斗场景录制 · 独立视觉试演，命中拍点为模拟演出，尚未接正式技能或真机验收。MP4 保留更多渐变细节，GIF 用于快速预览。</p></main><script>function replay(){document.querySelectorAll('video').forEach(v=>{v.currentTime=0;v.play().catch(()=>{})})}function freeze(b){let a=b.closest('article'),v=a.querySelector('video');v.pause();v.currentTime=v.src.includes('phoenix')?1.17:v.src.includes('rift')?1.18:1.0}function playOne(b){let v=b.closest('article').querySelector('video');v.currentTime=0;v.play()} </script></html>'''
(root/'index.html').write_text(html)
print(root/'index.html')

for key,*_ in rows:
 subprocess.run([ff,'-v','error','-i',str(root/(key+'.mp4')),'-f','null','-'],check=True)
 for p in (root/'frames'/key).glob('frame-*.png'):
  if int(p.stem.split('-')[1]) not in {0,20,24,29,31,32,38,47,65,95}:p.unlink()
