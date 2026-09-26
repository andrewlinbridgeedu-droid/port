from pathlib import Path
import shutil,subprocess,sys
root=Path(__file__).resolve().parents[2]
prefix=sys.argv[1] if len(sys.argv)>1 else 'hound-foot-fire'
out=root/'output'/(prefix+'-delivery');out.mkdir(parents=True,exist_ok=True)
cards=[]
for stem,title in [('Hound-1','裂地起火'),('Hound-2','脚下旋焰')]:
 folder=root/'output'/(prefix+'-runtime')/stem
 subprocess.run(['/tmp/mistport-encode-frames',str(folder),str(out/(stem+'.mp4'))],check=True)
 for frame in [30,36,40]:shutil.copy2(folder/f'frame-{frame:03}.png',out/f'{stem}-{frame}.png')
 cards.append(f'<article><h2>{title}</h2><video autoplay loop muted controls playsinline src="{stem}.mp4"></video><p><a href="{stem}-30.png">起火</a> · <a href="{stem}-36.png">旋转收缩</a> · <a href="{stem}-40.png">地面焦痕</a></p></article>')
(out/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>猎犬 · 脚下旋焰</title><style>body{background:#17121d;color:#eee4d1;font:16px system-ui;margin:30px auto;padding:0 20px;max-width:1050px}p{line-height:1.6;color:#cbbfd0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:20px}article{background:#261f2d;border-radius:14px;padding:16px}video{width:100%}a{color:#efca89}</style><h1>脚下起火 · 旋转收缩 · 留下焦痕</h1><p>Unity 实际运行视频。火焰固定从主角脚下窜起，旋转着向内收缩，地面随之烧黑。此页供视觉复核，非整关通关记录。</p><div class="grid">'''+''.join(cards)+'</div></html>')
