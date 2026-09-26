# -*- coding: utf-8 -*-
"""Encode real Unity 30fps captures and assemble a browsable spell audit."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess, html, json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/all-spells-tier-20260919'
hero={'01':'错步穿行','02':'假面谕令','04':'身份错置','05':'伪证烙印','06':'错影追猎','07':'荒谬归结','08':'反客为主','09':'后手改写','10':'无名宣告'}
actors={'archivist':'档案守卫','matriarch':'织幕女主','scribe':'书记员','rescue':'失令救援者','executor':'机械笔臂执行者','adjudicator':'裁决重卫','convoy':'护送重卫','chronarch':'总签官','fog-ghost':'幽灵','crimson-ghost':'赤红幽灵'}
church={'saltmaw':'D02 盐囊','shellback':'D03 背囊','ironclaw':'D04 剪肢','frilled-naga':'D05 蛇冠','boneclaw':'D06 骨爪','stonehide':'D01 盾颚'}
actions={'tower_poison':'腐蚀毒息','tower_salt_spike':'盐晶刺','tower_mend':'寄生治疗','tower_short_pounce':'短扑','tower_cut_first':'右剪','tower_cut_second':'左剪','tower_heavy_cut':'双剪重击','tower_empower':'冠冕强化','tower_sound_arrow':'声箭','tower_piercing_claw':'穿刺爪','tower_tail_sweep':'尾扫','tower_heavy_claw':'重爪','archive_slam':'地裂重击','guard':'防御','charge':'蓄力'}
other={'hero-01-dual':'错步穿行 · 双目标','manual-mask':'手动假面 · 展开','manual-mask-hit':'手动假面 · 承伤','manual-mask-break':'手动假面 · 耗尽碎裂','leech-charge':'记忆蛭 · 蓄力','enemy-leech':'记忆蛭 · 吞名','core-repair':'寄忆核心 · 修复动作','guard-heal':'守卫 · 实际回血泛绿','archive-shield':'档案守卫 · 悬浮旋转盾','early-hound':'早期地狱犬 · 火球','q4-charge':'第四关 · 双焰预警','q4-probe':'第四关 · 试探火球','q4-first':'第四关 · 第一颗追索焰','q4-second':'第四关 · 第二颗追索焰','armored-hound-1':'铠甲犬 · 脚下火Ⅰ','armored-hound-2':'铠甲犬 · 脚下火Ⅱ','emerald-poison-field':'亡灵 · 持续毒雾','emerald-charge':'亡灵 · 绿焰蓄力','emerald-burst':'亡灵 · 毒爆重击','bounty-bindings-state':'通缉 · 持续束缚','bounty-escort-state':'通缉 · 护航防御','bounty-escort-attack':'通缉 · 护航者攻击','tower-persistent-status':'教会 · 持续毒与强化冠'}
def label(n):
 if n in other:return other[n]
 if n.startswith('hero-'):return hero.get(n[5:],n)
 for k,v in actors.items():
  if n.startswith('enemy-'+k+'-'):return v+' · 第'+n.rsplit('-',1)[1]+'式'
 for k,v in church.items():
  if n.startswith(k+'-'):return v+' · '+actions.get(n[len(k)+1:],n[len(k)+1:])
 if n.startswith('bounty-b'):
  parts=n.split('-',2);return '通缉 '+parts[1].upper()+' · '+{'ambush':'伏击','bind':'皮索束缚','heavy_strike':'重击','overwrite':'覆写','silk_bind':'丝线束缚','guard':'防御'}.get(parts[2],parts[2])
 return n
def group(n):
 if n.startswith(('hero-','manual-mask')):return '主角与假面'
 if n.startswith('bounty-'):return '通缉'
 if n.startswith(tuple(church)+('tower-',)):return '教会六恶魔'
 return '主线敌人与辅助'
dirs=sorted(d for d in OUT.iterdir() if d.is_dir() and list(d.glob('frame-*.png')))
def encode(d):
 video=d/'clip.mp4';frames=sorted(d.glob('frame-*.png'))
 if not video.exists() or video.stat().st_mtime<max(f.stat().st_mtime for f in frames):subprocess.run(['/tmp/encode-saltmaw',str(d),str(video)],check=True,stdout=subprocess.DEVNULL)
 print('ENCODED',d.name,flush=True)
with ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(encode,dirs))
items=[]
for d in dirs:
 frames=sorted(d.glob('frame-*.png'));poster=frames[min(24,len(frames)-1)].name
 items.append(dict(id=d.name,name=label(d.name),group=group(d.name),frames=len(frames),fps=30))
(OUT/'manifest.json').write_text(json.dumps(items,ensure_ascii=False,indent=2))
cards=[]
for item in items:
 n=item['id'];frames=sorted((OUT/n).glob('frame-*.png'));poster=frames[min(24,len(frames)-1)].name
 cards.append(f'<article data-group="{item["group"]}"><h3>{html.escape(item["name"])}</h3><video controls loop playsinline preload="none" poster="{n}/{poster}" src="{n}/clip.mp4"></video><small>{item["frames"]/30:.1f}秒 · Unity 实录</small></article>')
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>雾港 · 全法术增强总览</title><style>body{margin:0;background:#14121a;color:#ece6db;font:16px system-ui}header{padding:32px 5vw 20px;border-bottom:1px solid #403543}h1{font-size:28px}p{color:#c5bacb;max-width:950px;line-height:1.7}nav{display:flex;gap:8px;flex-wrap:wrap;position:sticky;top:0;background:#14121aed;padding:16px 5vw;z-index:2}button{background:#2a2332;color:#eee0cd;border:1px solid #65516f;padding:9px 14px;border-radius:8px;cursor:pointer}button.active{background:#6a4a28;border-color:#d8b072}main{padding:20px 5vw;display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:24px}article{background:#201b27;border:1px solid #3e3346;border-radius:12px;overflow:hidden}h3{font-size:16px;margin:14px}video{display:block;width:100%;aspect-ratio:9/16;background:#08070b}small{display:block;padding:12px;color:#a99cba}article[hidden]{display:none}a{color:#e8c58e}</style><header><h1>雾港 · 全法术增强总览</h1><p>保留各招身份，增加主体内部细节、大片亮芯、命中裂开和覆盖范围；减少细碎散线。伤害、冷却、命中时序与存档未改。</p><p>CLIPCOUNT 段实际 Unity 运行画面，可逐招播放。内部画面检查与回调测试不等于用户视觉认可；本轮未安装手机，真机遮挡与性能待验证。无独立法术演出的被动遗落物不计入本次视频。</p></header><nav><button class="active" data-filter="全部">全部</button><button data-filter="主角与假面">主角与假面</button><button data-filter="主线敌人与辅助">主线敌人与辅助</button><button data-filter="教会六恶魔">教会六恶魔</button><button data-filter="通缉">通缉</button><button id="pause">暂停全部</button><button id="speed">切换半速</button></nav><main>CARDS</main><script>document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>{document.querySelectorAll('[data-filter]').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('article').forEach(a=>{a.hidden=b.dataset.filter!=='全部'&&a.dataset.group!==b.dataset.filter;if(a.hidden)a.querySelector('video').pause()})});document.querySelector('#pause').onclick=()=>document.querySelectorAll('video').forEach(v=>v.pause());let slow=false;document.querySelector('#speed').onclick=()=>{slow=!slow;document.querySelectorAll('video').forEach(v=>v.playbackRate=slow?.5:1);document.querySelector('#speed').textContent=slow?'恢复正常速度':'切换半速'};document.querySelectorAll('video').forEach(v=>v.addEventListener('play',()=>document.querySelectorAll('video').forEach(o=>{if(o!==v)o.pause()})));</script></html>'''
(OUT/'index.html').write_text(page.replace('CLIPCOUNT',str(len(items))).replace('CARDS',''.join(cards)))
print('DELIVERY',len(items),'clips',flush=True)
