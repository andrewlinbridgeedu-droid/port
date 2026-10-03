"""Package actual Unity captures; never substitute source AI movies for runtime evidence."""
import argparse, json, shutil, subprocess
from pathlib import Path
import imageio_ffmpeg

p=argparse.ArgumentParser();p.add_argument('capture');args=p.parse_args()
capture=Path(args.capture)
if not (capture/'passed.txt').exists(): raise SystemExit('Runtime verification has not passed')
root=Path(__file__).resolve().parents[2]
out=root/'docs/development/hero-ai-animation-20261002/integration'
out.mkdir(exist_ok=True,parents=True)
outfits=[('mistport-night','雾港夜行'),('starlight-magician','星辉魔术师'),('midnight-carnival','午夜狂欢')]
actions=[('01-diagonal-cut','斜步切出'),('02-command-flick','抬手敕令'),('03-overarm-throw','过肩投掷'),('04-seal-press','落掌盖印'),('05-sidearm-cast','侧身甩投')]
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
media=[]
for outfit,title in outfits:
    shutil.copy2(capture/(outfit+'-production.png'),out/(outfit+'-production.png'))
    for action,label in actions:
        stem=outfit+'-'+action
        frames=sorted((capture/stem).glob('*.png'))
        if len(frames)!=48: raise SystemExit('Incomplete capture '+stem)
        subprocess.run([ffmpeg,'-y','-v','error','-framerate','30','-i',str(capture/stem/'%04d.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out/(stem+'.mp4'))],check=True)
        subprocess.run([ffmpeg,'-v','error','-i',str(out/(stem+'.mp4')),'-f','null','-'],check=True)
        shutil.copy2(frames[16],out/(stem+'.png'))
        media.append({'outfit':outfit,'action':action,'frames':len(frames),'fps':30,'width':720,'height':1080,'decoded':True,'source':'Unity Mac runtime capture'})
shutil.copy2(capture/'passed.txt',out/'runtime-verification.txt')
(out/'runtime-media.json').write_text(json.dumps(media,indent=2)+'\n')
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>主角动作 · 游戏内预览</title>
<style>body{margin:0;background:#151923;color:#e9e5dc;font:16px/1.6 system-ui}main{max-width:1120px;margin:auto;padding:28px}h1{font-size:30px}p{color:#bdc4cf}nav{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}button{color:inherit;background:#282f3e;border:1px solid #596074;border-radius:8px;padding:10px 16px;cursor:pointer}button[aria-pressed=true]{background:#755c39;border-color:#d9b97b}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}article{background:#202633;border-radius:10px;padding:14px}video,img{width:100%;border-radius:7px}h2{font-size:18px;margin:0 0 8px}.caption{font-size:13px}a{color:#e7c484}details{margin:24px 0}footer{padding:24px 0;border-top:1px solid #3a4253}@media(max-width:720px){.grid{grid-template-columns:1fr}}
</style><main><h1>主角动作 · 游戏内预览</h1><p>三套衣装各五个动作，已经接到 Q4、D01、B01 战斗样板。下面是实际 Unity 场景中的近景检查，保留游戏场景与透明人物，播放速度就是接入后的速度。</p><p class="caption">这是真实 Unity Mac 运行画面；近景使用检查机位，不是 iPhone 录像。正式战斗机位见下方。图稿认可与游戏内视觉认可分别记录。</p><nav id="actions"></nav><section class="grid" id="clips"></section><details><summary>正式战斗机位 · 三套衣装</summary><div class="grid" id="production"></div></details><footer><a href="runtime-verification.txt">运行检查记录</a> · <a href="../motion-library/full-body/review.html">原始 AI 全身动作</a><p class="caption">动作按既有命中时间加速，×2 随战斗时钟加速。最后短暂过渡回待机；部分原片末姿态差异较大，仍需你在游戏中判断回位观感。</p></footer></main><script>
const outfits=OUTFITS, actions=ACTIONS;
const nav=document.getElementById('actions'), clips=document.getElementById('clips');
function show(id){nav.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.id===id));clips.replaceChildren();for(const [outfit,title]of outfits){const item=document.createElement('article');item.innerHTML=`<h2>${title}</h2><video controls autoplay muted loop playsinline poster="${outfit}-${id}.png" src="${outfit}-${id}.mp4"></video>`;clips.append(item);}}
for(const[id,label]of actions){const b=document.createElement('button');b.textContent=label;b.dataset.id=id;b.onclick=()=>show(id);nav.append(b);}
for(const[id,title]of outfits){const a=document.createElement('article');a.innerHTML=`<h2>${title}</h2><img alt="${title} · 正式机位" src="${id}-production.png">`;document.getElementById('production').append(a);}
show('03-overarm-throw');
</script></html>'''.replace('OUTFITS',json.dumps(outfits,ensure_ascii=False)).replace('ACTIONS',json.dumps(actions,ensure_ascii=False))
(out/'review.html').write_text(html)
print('Packaged 15 Unity runtime clips; all decode successfully.')
