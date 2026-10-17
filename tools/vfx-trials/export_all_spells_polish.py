from pathlib import Path
import sys,subprocess,html
sys.path.insert(0,"/tmp/mistport-vfx-encode")
import imageio_ffmpeg
r=Path(__file__).resolve().parents[2]/"output/all-spells-polish-20260921"
f=imageio_ffmpeg.get_ffmpeg_exe(); cards=[]
names={"hero-01":"错步穿行","hero-02":"假面谕令","hero-04":"身份错置","hero-05":"伪证烙印","hero-06":"双影追猎","hero-07":"荒谬归结","hero-08":"反客为主","hero-09":"后手改写","hero-10":"无名宣告","hero-basic":"普通攻击","hero-01-dual":"错步·双目标","hero-10-all-four":"无名·四目标全体","manual-mask":"手动假面","manual-mask-hit":"假面承接","manual-mask-break":"假面破裂","ghost-wisp-secondary":"幽雾追魂·第二目标施法","q4-charge":"双焰蓄势","q4-probe":"试探火球","q4-first":"第一追索火球","q4-second":"第二追索火球","emerald-poison-field":"翠焰·持续毒雾","emerald-charge":"翠焰·全身蓄焰","emerald-burst":"翠焰·重击","encore-bell":"铃·三层声纹","enemy-leech":"记忆蛭·吞名","leech-charge":"记忆蛭·蓄势","tower-persistent-status":"塔·持续状态","bounty-bindings-state":"通缉·束缚状态","bounty-escort-state":"通缉·护送状态","bounty-escort-attack":"通缉·护送者攻击"}
labels={"stonehide":"盾颚","saltmaw":"盐囊","shellback":"背囊","ironclaw":"剪肢","frilled-naga":"蛇冠","boneclaw":"骨爪","enemy-archivist":"档案守卫","enemy-matriarch":"织幕女主","enemy-chronarch":"总签官","enemy-executor":"执行者","enemy-adjudicator":"裁定锤卫","enemy-convoy":"押运锤卫","enemy-scribe":"抄录傀儡","enemy-rescue":"负契者","enemy-default":"空壳守卫","core-memory-strike":"核心记忆冲击","enemy-fog-ghost":"雾幽灵","enemy-crimson-ghost":"赤红幽灵","armored-hound":"铠甲犬","early-hound":"早期猎犬","core-repair":"核心定向修复","guard-heal":"恢复确认","archive-shield":"封存装甲","bounty-b01":"通缉01","bounty-b02":"通缉02","bounty-b03":"通缉03","bounty-b04":"通缉04","bounty-b05":"通缉05","bounty-b06":"通缉06"}
suffixes={"tower_poison":"有限毒息","tower_salt_spike":"盐晶刺","tower_mend":"定向治疗","tower_short_pounce":"短扑压碎","tower_cut_first":"第一快切","tower_cut_second":"第二反切","tower_heavy_cut":"双刃重切","tower_empower":"定向强化","tower_sound_arrow":"声矢","tower_piercing_claw":"斜向穿刺","tower_tail_sweep":"弧面尾扫","tower_heavy_claw":"过顶重爪","archive_slam":"重砸","charge":"蓄势","guard":"锁甲","heavy_strike":"重击","ambush":"伏击","bind":"束缚","overwrite":"覆写","silk_bind":"丝缚"}
def title(key):
 if key in names:return names[key]
 for a,b in labels.items():
  if key.startswith(a):
   result=key.replace(a,b,1)
   for old,new in suffixes.items():result=result.replace(old,new)
   return result
 return key
for d in sorted(r.iterdir()):
 if not d.is_dir() or not list(d.glob("frame-*.png")):continue
 out=r/(d.name+".mp4")
 if len(list(d.glob("frame-*.png")))>5:
  subprocess.run([f,"-y","-framerate","30","-i",str(d/"frame-%03d.png"),"-c:v","libx264","-crf","18","-pix_fmt","yuv420p",str(out)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 subprocess.run([f,"-v","error","-i",str(out),"-f","null","-"],check=True)
 cards.append(f'<article><h2>{html.escape(title(d.name))}</h2><video controls muted loop preload="none" src="{out.name}"></video></article>')
 frames=sorted(d.glob("frame-*.png")); keep={0,len(frames)//4,len(frames)//2,3*len(frames)//4,len(frames)-1}
 if len(frames)>5:
  for i,p in enumerate(frames):
   if i not in keep:p.unlink()
(r/"index.html").write_text('<!doctype html><meta charset="utf-8"><title>全游戏法术优化实录</title><style>body{background:#18131f;color:#eee;font:16px system-ui;margin:28px}main{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}video{width:100%}article{background:#262030;padding:16px}h2{font-size:18px}@media(max-width:800px){main{grid-template-columns:1fr}}</style><h1>全游戏法术优化 · Unity实录</h1><p>正式源码演出逐项录制；不等于手机验收。目标数量与技能机制保留。</p><input placeholder="筛选技能或敌人" oninput="document.querySelectorAll(&quot;article&quot;).forEach(a=>a.hidden=!a.textContent.includes(this.value))"><main>'+''.join(cards)+'</main>')
print(len(cards),"clips exported and decoded")
