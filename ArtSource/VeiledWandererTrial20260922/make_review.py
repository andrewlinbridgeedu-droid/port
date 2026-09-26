# -*- coding: utf-8 -*-
from pathlib import Path
import json,hashlib,os
root=Path(__file__).resolve().parent
out=root.parents[1]/'output'/'veiled-wanderer-trial-20260922'
for fn in ['VeiledWanderer_Trial.blend','VeiledWanderer_Trial.glb','reference.png']:
 p=out/fn
 if p.is_symlink():p.unlink()
 if not p.exists():p.symlink_to(Path('../../ArtSource/VeiledWandererTrial20260922')/fn)
stats=json.loads((root/'model_stats.json').read_text())
checks=json.loads((root/'glb_validation.json').read_text())
views=[('three-quarter','四分之三视角','层叠衣片、悬挂饰件与帽檐厚度'),('front','正面','黑金外袍、青绿内衬、双手姿态'),('side','侧面','真实立体厚度，非图像平面'),('back','背面','根据正面设计推断的背部结构'),('portrait','脸部与上身','五官、鬓发、项链及烟杆'),('glb-import-check','GLB 重导入实拍 · 低清','独立导入后的几何和基础 PBR 呈色核对')]
cards=''.join(f'<figure><a href="{file}.png" target="_blank"><img loading="lazy" src="{file}.png" alt="{title} · Blender 实际渲染"></a><figcaption><b>{title}</b><span>{description}</span></figcaption></figure>' for file,title,description in views)
html='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>黑金旅人 · Blender 结构试作</title><style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#15191d;color:#eee9df;font:16px/1.7 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}main{max-width:1400px;margin:auto;padding:56px 30px}header{display:grid;grid-template-columns:1fr 260px;gap:50px;align-items:start;border-bottom:1px solid #42413c;padding-bottom:40px}h1{font-size:42px;line-height:1.15;margin:12px 0 20px;font-weight:550;letter-spacing:.05em}.eyebrow{color:#c4a36c;font-size:12px;letter-spacing:.2em}p{max-width:820px;color:#bcbfc0}a{color:#e8d4ac}.pill{display:inline-block;padding:5px 12px;border:1px solid #605341;border-radius:30px;color:#d7b986;font-size:12px;margin-right:8px}.downloads{display:flex;gap:12px;margin:25px 0;flex-wrap:wrap}.downloads a{border:1px solid #70614a;padding:10px 20px;text-decoration:none;border-radius:5px}.reference{margin:0}.reference img{display:block;width:100%;max-height:290px;object-fit:contain;background:#2a2c2e}.reference figcaption{font-size:12px;color:#969b9d;margin-top:7px}.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:28px;margin-top:40px}.grid figure{margin:0;background:#1e252b;border:1px solid #383e41;border-radius:8px;overflow:hidden}.grid img{width:100%;display:block}.grid figcaption{padding:18px 22px;display:flex;justify-content:space-between;gap:20px}.grid figcaption span{color:#9ba4a8;font-size:13px}.note{margin:40px 0 0;padding:25px 28px;border-left:3px solid #94794d;background:#1e2428;font-size:14px;color:#b5bdc0}footer{color:#808c91;font-size:12px;padding-top:30px}@media(max-width:800px){main{padding:28px 18px}header{grid-template-columns:1fr;gap:15px}h1{font-size:32px}.reference{display:none}.grid{grid-template-columns:1fr}.grid figcaption{display:block}.grid figcaption span{display:block}}
</style></head><body><main><header><section><div class="eyebrow">BLENDER AUTHORING TRIAL / 2026.09.22</div><h1>黑金旅人 · 立体结构试作</h1><span class="pill">完整三维几何</span><span class="pill">背面为推断设计</span><span class="pill">静态 · 未绑定</span><p>依据用户提供的单张角色图，在 Blender 中搭建身体、五官、长发、破檐帽、多层衣袍、饰件与烟杆。以下图片均从同一个可旋转模型实际渲染。点击图片可看原尺寸。</p><div class="downloads"><a href="VeiledWanderer_Trial.blend" download>下载 Blender 工程</a><a href="VeiledWanderer_Trial.glb" download>下载 GLB 模型</a></div><p style="font-size:13px">几何：TRIANGLES 三角面 · MESHES 个导出网格。GLB 已重新导入空白 Blender 场景核对几何、材质、尺寸和饰件。</p></section><figure class="reference"><a href="reference.png" target="_blank"><img src="reference.png" alt="用户提供的正面参考"></a><figcaption>用户提供的原始参考</figcaption></figure></header><section class="grid">CARDS</section><aside class="note"><strong>本次试作的边界</strong><br>这是对轮廓与服饰结构的制作验证，脸、发丝、衣褶、金纹与纹身尚未达到原画精度。背面由正面设计补全；符牌仅为装饰笔画。当前没有骨骼、蒙皮、动作、游戏面数优化或手机性能验收，未替换正式游戏角色。GLB 使用基础 PBR 材质，完整布料程序材质以 Blender 工程为准。</aside><footer>REFERENCE → AUTHORED GEOMETRY → MULTI-VIEW RENDER · 保留源图片与可重复执行的建模脚本</footer></main></body></html>'''
html=html.replace('TRIANGLES',f"{checks['triangles']:,}").replace('MESHES',str(checks['mesh_objects'])).replace('CARDS',cards)
(out/'index.html').write_text(html)
receipt={}
for fn in ['reference.png','VeiledWanderer_Trial.blend','VeiledWanderer_Trial.glb','build_trial.py']:
 p=root/fn;receipt[fn]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
(root/'SHA256.json').write_text(json.dumps(receipt,indent=2))
print(out/'index.html')
