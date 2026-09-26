from pathlib import Path
from PIL import Image
import html, shutil
root=Path(__file__).resolve().parents[2]
out=root/'output/spell-sculpted-delivery'
out.mkdir(parents=True,exist_ok=True)
items=[
('主角 · 错影追猎','原角色衣装、面部与紫青轮廓光，双影穿透。','sculpted-hero-runtime/fool_skill_06','hero-06',8,67),
('主角 · 荒谬归结','独立高清牌面、金属厚边，保留重牌斩落。','sculpted-hero-runtime/fool_skill_07','hero-07',10,67),
('猎犬 · 裂地熔爆','主角脚下分叉地裂，缝底熔岩与向上喷发。','sculpted-enemy-runtime/Hound-1','Hound-1',27,67),
('猎犬 · 裂隙火潮','裂缝沿地面逐段推进，火浪随之压向目标。','sculpted-enemy-runtime/Hound-2','Hound-2',27,67),
('守卫 · 飞臂穿击','真实手臂裹机械碎刃推进，命中后归位。','sculpted-enemy-runtime/Archivist-1','Archivist-1',27,67),
('守卫 · 档案刃旋','异形机械刀片与空心螺旋，抵达目标后炸散。','sculpted-enemy-runtime/Archivist-2','Archivist-2',24,67),
('女主 · 绞幕旋涡','红线与撕裂绸带织成旋涡，收紧后断丝爆开。','sculpted-enemy-runtime/Matriarch-1','Matriarch-1',24,67),
('女主 · 千针织雨','银针弧形分层展开，带红白尾丝俯冲。','sculpted-enemy-runtime/Matriarch-2','Matriarch-2',24,67),
('亡灵 · 翠毒漫天','成功施毒后每3秒66伤害，共3次；铃后99×3。初次可被幻影承接。','sculpted-enemy-runtime/Emerald-1','Emerald-1',17,67),
('亡灵 · 返场毒爆','聚毒急收后爆发，198直接伤害；铃后297。','sculpted-enemy-runtime/Emerald-2','Emerald-2',18,67),
('亡灵 · 持续毒场','3D翻涌雾场。此段以测试消息展示剩余次数变化；实际3秒跳伤另由正式战斗时钟结算。','sculpted-enemy-runtime/Emerald-persistent','Emerald-persistent',12,133),
]
cards=[]
for title,description,folder,stem,key,interval in items:
 paths=sorted((root/'output'/folder).glob('frame-*.png'))
 if not paths: raise RuntimeError('Missing '+folder)
 target=out/(stem+'.gif')
 if not target.exists() or target.stat().st_mtime<max(p.stat().st_mtime for p in paths):
  frames=[]
  for p in paths:
   with Image.open(p) as im: frames.append(im.convert('RGB').resize((432,614),Image.Resampling.LANCZOS).quantize(colors=256,method=Image.Quantize.FASTOCTREE))
  frames[0].save(target,save_all=True,append_images=frames[1:],duration=interval,loop=0,optimize=False)
  for im in frames: im.close()
 keyfile=out/(stem+'-detail.png');shutil.copy2(paths[min(key,len(paths)-1)],keyfile)
 cards.append(f'<article><h2>{html.escape(title)}</h2><p>{html.escape(description)}</p><a href="{stem}.gif"><img src="{stem}.gif" loading="lazy" alt="{html.escape(title)}实际运行"></a><a class="detail" href="{stem}-detail.png">查看原尺寸实拍细节</a></article>')
(out/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>雾港 · 主体与动态精修</title><style>body{background:#17121d;color:#eee4d1;font:16px system-ui;margin:32px auto;padding:0 20px;max-width:1320px}h1{font-size:28px}p{color:#c5b9c8;line-height:1.6}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}article{background:#241d2b;border-radius:12px;overflow:hidden}h2{font-size:18px;margin:16px}article p{font-size:14px;margin:0 16px 16px;min-height:45px}img{width:100%;display:block}a{color:#efca89}.detail{display:block;padding:14px 16px}</style><h1>主角道具精修 · 四敌法术</h1><p>以下均为 Unity 实际运行逐帧录制，无后期叠画。持续伤害由正式原生战斗逻辑结算；此页用于演出检查，不代表新档连续通关或最终视觉验收。</p><div class="grid">'''+''.join(cards)+'</div></html>')
print(out/'index.html')

# Preserve the native evidence when repackaging this batch.
native_section = '<section style="margin-top:36px"><h2>正式第5关 · 原生战斗记录</h2><p>从正式关卡入口完成玛拉交付后，未选技能、只用普攻观察。录到每跳66持续伤害、198毒爆与剩余次数；此轮为伤害观察，战败后返回主城。未使用独立试演的手动假面。</p><video controls preload="metadata" playsinline style="width:min(100%,420px)" src="ios-q05-formal/battle.mp4"></video><p><a href="ios-q05-formal/frame-012.png">毒雾次数与伤害原图</a> · <a href="ios-q05-formal/after-exit-clean.png">退场清理原图</a></p></section>'
if (out/"ios-q05-formal/battle.mp4").exists():
 page=out/"index.html"
 page.write_text(page.read_text().replace("</html>",native_section+"</html>"))
