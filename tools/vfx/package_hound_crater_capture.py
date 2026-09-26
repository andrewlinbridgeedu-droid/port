from pathlib import Path
from PIL import Image
import shutil
root=Path(__file__).resolve().parents[2]
out=root/'output/hound-crater-fault-delivery'
out.mkdir(parents=True,exist_ok=True)
cards=[]
for stem,title,description,key in [('Hound-1','裂地熔爆','脚下裂口扩开成破裂坑，火焰向上喷发。',30),('Hound-2','裂隙火潮','一条曲折裂缝从猎犬延伸向主角，低矮火舌随前沿推进。',29)]:
 paths=sorted((root/'output/hound-crater-fault-runtime'/stem).glob('frame-*.png'))
 frames=[]
 for p in paths:
  with Image.open(p) as im: frames.append(im.convert('RGB').resize((432,614),Image.Resampling.LANCZOS).quantize(colors=256,method=Image.Quantize.FASTOCTREE))
 frames[0].save(out/(stem+'.gif'),save_all=True,append_images=frames[1:],duration=67,loop=0,optimize=False)
 shutil.copy2(paths[key],out/(stem+'-detail.png'))
 cards.append(f'<article><h2>{title}</h2><p>{description}</p><img src="{stem}.gif"><p><a href="{stem}-detail.png">查看原尺寸战斗截图</a></p></article>')
(out/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>猎犬 · 坑裂与火潮</title><style>body{background:#17121d;color:#eee4d1;font:16px system-ui;margin:30px auto;padding:0 20px;max-width:1050px}p{line-height:1.6;color:#cbbfd0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:22px}article{background:#261f2d;border-radius:14px;padding:16px}img{width:100%}a{color:#efca89}h2{font-size:20px}</style><h1>猎犬 · 坑裂与火潮</h1><p>Unity 实际战斗演出逐帧录制。地面使用两张独立透明原画；第一招脚下爆发，第二招连续推进。每招一次命中和中途取消清理已检查。此页供视觉复核，不代表整关通关验收。</p><div class="grid">'''+''.join(cards)+'</div><p><a href="../spell-sculpted-delivery/index.html">前一批主角与其他敌人演出</a></p></html>')
print(out/'index.html')
