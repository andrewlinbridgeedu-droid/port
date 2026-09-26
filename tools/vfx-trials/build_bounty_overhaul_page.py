#!/usr/bin/env python3
"""Build the local, three-camera review page from the latest bounty recordings."""
from __future__ import annotations
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "bounty-spell-overhaul-20260923"
PLAN = json.loads((ROOT / "output" / "bounty-eight-20260923" / "capture-plan.json").read_text())["rows"]
TITLES = {
    "B01": "缺齿处决斩", "B02": "反锁束缚", "B03A": "试探水刃",
    "B03B": "逆钟重浪", "B05A": "剪丝试探", "B05B": "赤丝勒束",
    "B07-knock": "喉铃三叩", "B07-spittle": "有限毒沫",
    "B08-mirror": "镜面伪身", "B08-true-stab": "真身短刺",
    "B08-echo-strike": "伪影试探", "B09-armor": "可击破铜甲",
    "B09-rend": "吞契撕裂", "B10-veil": "绯月长帷",
    "B10-transfer": "收寿囊体转息",
}
NAMES = {
    "B01": "第七号空壳", "B02": "背架收尸人", "B03": "溺钟海盗",
    "B05": "赤丝裁衣人", "B07": "三声敲门客", "B08": "借脸人·弥伦",
    "B09": "铜背吞契兽", "B10": "换寿先知·绯欠",
}
SIZES = [
    ("B01", "2.42×", "1.11×"),
    ("B02", "1.43×", "1.09×"),
    ("B03", "2.10×", "1.11×"),
    ("B05", "2.69×", "1.12×"),
    ("B08", "2.91×", "1.09×"),
    ("B10", "1.60×", "1.11×"),
]
style = """<style>
:root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;background:#0b111b;color:#f4f0e9}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at top,#1b3040,#0b111b 55%)}
main{max-width:1560px;margin:auto;padding:30px clamp(16px,4vw,64px) 90px}
h1{font-family:serif;font-size:clamp(32px,5vw,58px);margin:0 0 12px}
h2{font-family:serif;font-size:28px;margin:0 0 18px}
h3{font-size:17px;color:#efcc92;margin:0 0 12px}
p{line-height:1.7;color:#c7ced3}a{color:#f2cb8a}
nav{display:flex;gap:8px;flex-wrap:wrap;margin:24px 0}
nav a{padding:8px 12px;border:1px solid #70817c;border-radius:8px;background:#173238;text-decoration:none}
.notice{padding:16px 20px;background:#16312f;border:1px solid #6b9f88;border-radius:12px}
table{border-collapse:collapse;min-width:390px;margin:18px 0 28px}
th,td{border-bottom:1px solid #42545d;padding:9px 17px;text-align:left}
article{padding:22px;margin:18px 0 34px;border:1px solid #536973;border-radius:15px;background:#14212d}
.clip{border-top:1px solid #3c4e56;padding:18px 0}
.films{display:grid;grid-template-columns:minmax(0,540px) repeat(2,minmax(0,512px));gap:15px;align-items:start}
figure{margin:0}figcaption{font-size:13px;color:#bcd3d0;margin:0 0 8px}
video{width:100%;max-height:70vh;background:#05080c;border:1px solid #6c8c8b;border-radius:9px}
details{margin-top:10px;color:#c7ced3}summary{cursor:pointer;color:#edc893}
.qa{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px;margin:18px 0 28px}
.qa a{display:block}.qa img{display:block;width:100%;border:1px solid #536973;border-radius:8px}
@media(max-width:1120px){.films{grid-template-columns:1fr 1fr}.films figure:first-child{grid-column:1/-1}}
@media(max-width:700px){.films{grid-template-columns:1fr}.films figure:first-child{grid-column:auto}}
</style>"""
parts = ['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>雾港 · 通缉犯尺寸与法术再制作</title>', style,
    '<main><h1>通缉犯尺寸与法术再制作</h1>',
    '<p class="notice">这是一轮新的 Unity 战斗实录，供你检查体型、施法动作和受击画面。每组按“正式战场全景 → 施法者近景 → 受击者近景”排列。画面仍待你的视觉评审。</p>',
    '<p>六名偏大的人形按实际蒙皮几何缩至主角身高约 1.1 倍；B07 铃蛙与 B09 铜背兽原本只有主角约 0.62／0.64 倍，保持原尺寸并修正过高的血条与法术锚点。B10 囊体仍是较小的辅助单位。角色站位、伤害、命中时刻、冷却、结算与存档规则未改。</p>',
    '<p><a href="scale-final.tsv">查看十五组实际蒙皮尺寸测量</a>。战场全景的敌人更远，因此占屏高度会比近处主角小。</p>',
    '<table><thead><tr><th>角色</th><th>修改前 / 主角</th><th>当前 / 主角</th></tr></thead><tbody>']
for key,before,after in SIZES:
    parts.append(f'<tr><td>{key} {html.escape(NAMES[key])}</td><td>{before}</td><td>{after}</td></tr>')
parts.append('</tbody></table>')
parts.append('<details><summary>查看按起手、接触与收势抽取的九张时序拼图</summary><div class="qa">')
for view in ('full','close','impact'):
    for batch in (1,2,3):
        name=f'qa-{view}-{batch}.jpg'
        parts.append(f'<a href="{name}"><img loading="lazy" src="{name}" alt="{view} 第 {batch} 组时序图"></a>')
parts.append('</div></details>')
parts.append('<nav>' + ''.join(f'<a href="#{key}">{key} {html.escape(name)}</a>' for key,name in NAMES.items()) + '</nav>')
current = None
for row in PLAN:
    key=row["key"]
    group = "B10" if key == "B10-transfer" else key[:3]
    if group != current:
        if current is not None: parts.append('</article>')
        current=group
        parts.append(f'<article id="{group}"><h2>{group} {html.escape(NAMES[group])}</h2>')
    title=TITLES[key]
    pfx="../bounty-eight-20260923/after/"
    old="../../backups/bounty-size-spell-overhaul-20260923/videos/"
    parts.append(f'<section class="clip" id="spell-{html.escape(key)}"><h3>{html.escape(title)}</h3><div class="films">')
    for suffix,label in [("","正式战场全景"),("-close","施法者／受益者近景"),("-impact","受击者近景")]:
        src=pfx+key+suffix+".mp4"
        parts.append(f'<figure><figcaption>{label}</figcaption><video controls playsinline preload="metadata" src="{src}"></video></figure>')
    parts.append('</div><details><summary>修改前的战场录像</summary>'
                 f'<video controls playsinline preload="metadata" src="{old}{key}.mp4"></video></details></section>')
if current is not None: parts.append('</article>')
parts.append('<p>本页是本地 Unity 实录与旧版对照；手机帧率、实机手感及最终视觉认可需另行核对。</p></main></html>')
OUT.mkdir(parents=True,exist_ok=True)
path=OUT/"index.html"
path.write_text("".join(parts))
print(path)
