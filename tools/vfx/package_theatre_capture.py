from pathlib import Path
from PIL import Image
import html
root=Path(__file__).resolve().parents[2]
out=root/'output/spell-character-delivery'
out.mkdir(parents=True,exist_ok=True)
items=[]
hero=[(1,'错步穿行'),(2,'假面谕令'),(4,'身份错置'),(5,'伪证烙印'),(6,'错影追猎'),(7,'荒谬归结'),(8,'反客为主'),(9,'后手改写'),(10,'无名宣告')]
for i,name in hero:items.append(('主角 · '+name,root/f'output/hero-identity-runtime/fool_skill_{i:02d}',f'hero-{i:02d}'))
for kind,name in [('Hound','猎犬'),('Emerald','翠焰亡灵'),('Archivist','档案守卫'),('Matriarch','织幕女主')]:
 for n in (1,2):items.append((f'{name} · 法术{n}',root/f'output/cinematic-enemy-runtime/{kind}-{n}',f'{kind}-{n}'))
cards=[]
for title,folder,stem in items:
 paths=sorted(folder.glob('frame-*.png'))
 if not paths: raise RuntimeError('Missing capture '+str(folder))
 target=out/(stem+'.gif')
 if not target.exists() or target.stat().st_mtime < max(p.stat().st_mtime for p in paths):
  frames=[Image.open(p).convert('RGB').resize((360,512),Image.Resampling.LANCZOS).quantize(colors=192,method=Image.Quantize.FASTOCTREE) for p in paths]
  frames[0].save(target,save_all=True,append_images=frames[1:],duration=67,loop=0,optimize=False)
 cards.append(f'<article><h2>{html.escape(title)}</h2><a href="{stem}.gif"><img loading="lazy" src="{stem}.gif" alt="{html.escape(title)}实际运行录帧"></a></article>')
(out/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>雾港 · 法术实际运行</title><style>body{background:#17121d;color:#eee4d1;font:16px system-ui;margin:32px auto;padding:0 20px;max-width:1200px}h1{font-size:28px}p{color:#c5b9c8;line-height:1.6}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:20px}article{background:#241d2b;border-radius:12px;overflow:hidden}h2{font-size:17px;margin:16px}img{width:100%;display:block}a{color:#efca89}</style><h1>主角与四怪 · 各招式实拍</h1><p>九个主角技能、四个敌人各两招。以下为Unity实际运行逐帧录制，未叠画法术。此页展示演出；不代表新档连续通关或用户最终视觉验收。</p><div class="grid">'''+''.join(cards)+'</div></html>')
print(out/'index.html')
