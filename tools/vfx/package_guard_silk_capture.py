from pathlib import Path
import shutil, subprocess
root=Path(__file__).resolve().parents[2]
out=root/'output/guard-silk-refinement-delivery'
out.mkdir(parents=True,exist_ok=True)
items=[('Archivist-1','飞臂穿击','真实飞臂配分段护环与短机械翼。',28),('Archivist-2','档案刃阵','倒角钢刃绕轴旋转，推进后收束。',27),('Matriarch-1','绞幕旋涡','三条深红绸带舒展、旋转，抵达目标后绞紧散落。',20),('Matriarch-2','千针织雨','短银针分三批沿弧线俯冲，尾部带细红丝。',20)]
cards=[]
for stem,title,description,key in items:
 folder=root/'output/guard-silk-refinement-runtime'/stem
 subprocess.run(['/tmp/mistport-encode-frames',str(folder),str(out/(stem+'.mp4'))],check=True)
 shutil.copy2(folder/f'frame-{key:03}.png',out/(stem+'-detail.png'))
 cards.append(f'<article><h2>{title}</h2><p>{description}</p><video autoplay muted loop controls playsinline poster="{stem}-detail.png" src="{stem}.mp4"></video><p><a href="{stem}-detail.png">原尺寸截图</a></p></article>')
(out/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>守卫与织幕女主 · 演出精修</title><style>body{background:#17121d;color:#eee4d1;font:16px system-ui;margin:30px auto;padding:0 20px;max-width:1250px}p{line-height:1.6;color:#cbbfd0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}article{background:#261f2d;border-radius:14px;padding:16px}video{width:100%}a{color:#efca89}h2{font-size:20px}</style><h1>守卫与织幕女主 · 演出精修</h1><p>四招均为 Unity 实际运行录制。使用高码率视频展示完整过程；原尺寸 PNG 用于检查材质细节。此页为视觉复核，不代表新档连续通关。</p><div class="grid">'''+''.join(cards)+'</div></html>')
print(out/'index.html')
