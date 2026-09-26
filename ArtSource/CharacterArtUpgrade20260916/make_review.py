from pathlib import Path
from html import escape
root=Path(__file__).resolve().parents[2]
out=root/'output/character-art-upgrade-20260916'
cases=[('guard','空壳守卫','金属反光收敛，躯干呼吸与观察'),('ghost','雾中幽灵','衣摆硬面修复，肩臂放松与错相漂浮'),('red-ghosts','赤红幽灵','共享法线修复，保留红色变体与四人编队'),('early-hound','早期地狱犬','胸背法线连续，保留慢速四脚步态、耳尾动作'),('armored-hound','铠甲猎犬','毛皮与金属区分，颈部观察与耳尾动作'),('emerald','翠焰亡灵','骨骼、翠绿衣料与黄铜区分，衣摆滞后'),('core','寄忆核心','表层材质分区，局部双次收缩与间歇'),('leech','记忆蛭','湿润表皮，分段探伸'),('archivist','档案守卫','象牙甲片与机械关节区分，扫描与回稳'),('matriarch','织幕女主','皮肤与红衣区分，理线与腕旋，动作后停顿'),('scribe','书记员','修复单鞋误用金属，收笔停顿，持册稳定'),('rescue','失令救援者','恢复减面后的表面明暗，承重缓解与收势')]
html=['''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>雾港 · 角色精修实拍</title><style>body{margin:0;background:#14131b;color:#eae5dc;font:16px/1.7 system-ui;padding:32px;max-width:1300px;margin:auto}h1{font-size:32px}h2{font-size:23px;color:#dbc08d}p{color:#bbb6c7}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}img,video{width:100%;border-radius:8px;background:#222}section{padding:24px 0;border-top:1px solid #393341}figure{margin:0}figcaption{padding:8px 0;font-size:14px;color:#c5bccf}.note{background:#262130;padding:18px;border-radius:8px}a{color:#dcc292}@media(max-width:800px){.grid{grid-template-columns:1fr}}</style><h1>雾港 · 角色精修实拍</h1><p>2026-09-16 · 当前 Unity 实际模型、材质和动作</p><div class="note">左侧为上一轮已保存的战场基线，中间为本轮同一战场相机实拍，右侧为本轮20秒动态。两次运行的动作相位不同；未合成、未用概念图代替游戏画面。桌面运行证据不等同于 iPhone 视觉验收。</div>''']
for key,name,desc in cases:
 html += [f'<section><h2>{name}</h2><p>{desc}</p><div class="grid">',f'<figure><img loading="lazy" src="../model-optimization-20260916/after/{key}-after.png"><figcaption>上一轮战场基线</figcaption></figure>',f'<figure><img loading="lazy" src="final/{key}-after.png"><figcaption>本轮战场实拍</figcaption></figure>',f'<figure><video controls loop muted playsinline preload="none" poster="final/{key}-after.png" src="videos/{key}.mp4"></video><figcaption>20秒原始战场动作</figcaption></figure></div>']
 if (out/f'closeups/{key}-closeup.png').exists():html += [f'<details><summary>查看实际模型近景（检查相机）</summary><img style="max-width:480px" loading="lazy" src="closeups/{key}-closeup.png"></details>']
 html += ['</section>']
html+=['<section><h2>主角 · 正背面检查</h2><p>保留原衣装，修复浅面法线接缝、区分衣料和金线、保护浅色皮肤。衣带与躯干动作具有不同延迟。以下为检查相机，不改变正式战场镜头。</p><div class="grid">']
for key in ['hero-back-closeup','hero-front-closeup']:html += [f'<img loading="lazy" src="closeups/{key}.png">']
html += ['</div></section><p>主角八招接触/取消/重试、九类淡出、两新角色编队与接触检查通过；iOS构建成功。原始模型与代码备份保留。旧犬仍受原始3451面轮廓限制；本轮未新雕刻全部角色。手机当前不可连接，未安装。</p></html>']
(out/'index.html').write_text('\n'.join(html))
