#!/usr/bin/env python3
"""Index only recorded Unity clips for the September reference-intensity pass."""
from __future__ import annotations

import hashlib
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/all-spell-reference-20260923"
WHOLE = OUT / "whole"
BOUNTY = OUT / "bounty"
names = {s["id"]: (s["name"], s["group"], s.get("scope", ""))
         for s in json.loads((ROOT / "output/jev-spell-plan-20260921/review.json").read_text())["spells"]}
bounty_titles = {
    "B01": "缺齿处决斩", "B02": "金纹反锁", "B03A": "试探水锋", "B03B": "逆钟重浪",
    "B05A": "剪丝试探", "B05B": "赤丝勒束", "B07-knock": "喉铃三叩",
    "B07-spittle": "毒沫", "B08-mirror": "镜面伪身", "B08-true-stab": "真身刺",
    "B08-echo-strike": "伪影试探", "B09-armor": "铜甲", "B09-rend": "吞契撕裂",
    "B10-veil": "绯月长帷", "B10-transfer": "转息",
}
old_bounty = {"B01", "B02", "B03A", "B03B", "B05A", "B05B"}
rows = []
for row in json.loads((WHOLE / "capture-plan.json").read_text())["rows"]:
    sid, key = row["id"], row["key"]
    if sid.startswith(("X", "L")) or key in old_bounty:
        continue
    name, group, scope = names.get(sid, (key, "其他", ""))
    rows.append((sid, key, name, group, scope, "whole", ("", "-close")))
for row in json.loads((BOUNTY / "capture-plan.json").read_text())["rows"]:
    sid, key = row["id"], row["key"]
    rows.append((sid, key, bounty_titles.get(key, key), "通缉犯", "", "bounty", ("", "-close", "-impact")))
if len(rows) != 96:
    raise SystemExit(f"Expected 96 current formal presentation groups, got {len(rows)}")

manifest = []
for sid, key, name, group, scope, folder, suffixes in rows:
    clips = []
    for suffix in suffixes:
        path = OUT / folder / "after" / f"{key}{suffix}.mp4"
        if not path.is_file() or path.stat().st_size < 1024:
            raise SystemExit(f"Missing or incomplete current Unity recording: {path}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        clips.append({"path": f"{folder}/after/{key}{suffix}.mp4", "sha256": digest,
                      "bytes": path.stat().st_size})
    manifest.append({"id": sid, "key": key, "name": name, "group": group, "scope": scope,
                     "source": folder, "clips": clips})
(OUT / "review-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

groups = ["主角", "遗落物", "主线敌人", "教会塔", "新五恶魔", "通缉犯"]
def chapter(group: str, sid: str) -> str:
    if sid.startswith("H"): return "主角"
    if sid.startswith("R"): return "遗落物"
    if sid.startswith("M"): return "主线敌人"
    if sid.startswith("T"): return "教会塔"
    if sid.startswith("N"): return "新五恶魔"
    return "通缉犯"

style = """<style>
:root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif;background:#0a1220;color:#f8f3eb}
*{box-sizing:border-box}body{margin:0;background:linear-gradient(155deg,#162e39,#0a1220 38%)}
main{max-width:1540px;margin:auto;padding:32px clamp(16px,4vw,66px) 100px}
h1{font:600 clamp(34px,5vw,58px) Georgia,serif;margin:0 0 12px}h2{font:600 31px Georgia,serif;margin:48px 0 18px}
h3{font-size:20px;color:#f5ce90;margin:0 0 8px}p{color:#d3dee0;line-height:1.7}
.intro{padding:18px 22px;border:1px solid #618a8a;border-radius:14px;background:#15313b}
.reference{display:flex;align-items:center;gap:20px;flex-wrap:wrap;margin:16px 0 22px}.reference img{max-width:360px;width:100%;height:auto;border:1px solid #607e84;border-radius:10px}.reference p{max-width:660px}
.nav{display:flex;flex-wrap:wrap;gap:8px;margin:22px 0}.nav a{color:#f7d795;text-decoration:none;border:1px solid #617981;border-radius:8px;padding:7px 11px;background:#1b343e}
.search{width:100%;padding:13px 15px;border-radius:9px;background:#182a36;color:#fff;border:1px solid #637d85;font-size:16px}
article{margin:10px 0;padding:16px 20px;border:1px solid #405d65;border-radius:12px;background:#142632}
article summary{cursor:pointer;list-style:none}article summary::-webkit-details-marker{display:none}
article .key{color:#91c5cd;font-size:13px;letter-spacing:.1em}article .scope{font-size:13px;color:#a8bbc0}
.films{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:13px;margin-top:15px}
figure{margin:0}figcaption{font-size:13px;color:#c8d8d7;margin:0 0 7px}video{width:100%;height:auto;max-height:68vh;background:#060a10;border:1px solid #5d8186;border-radius:8px}
a{color:#f5cf96}.qa{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:14px}.qa img{width:100%;border-radius:8px;border:1px solid #607e84}
.hidden{display:none}
</style>"""
parts = ["<!doctype html><html lang='zh-CN'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
         "<title>雾港 · 全法术参考强度实录</title>", style,
         "<main><h1>全法术参考强度 · Unity 实录</h1>",
         "<p class='intro'>以新参考图的主体面积、亮芯、色彩层次和接触爆发为目标，同时保留每招独有的形状与运动。这里收录 96 组现行正式表现入口；录制及回调检查不等于视觉已获认可，也不代表未开放关卡已开放。通缉犯提供战场、施法者、受术者三机位；其余提供战场和近景。九项原生遗落物被动触发不属独立施法入口，尚无逐项实触发录像。</p>",
         "<p class='intro'>已恢复此前误删的 H00 大范围紫金命中层，以及 H04–H08、H10 原有的屏幕空间主体；身体动作、命中时刻和规则仍按现行版。<a href='../h00-fullscreen-repair-20260923/index.html'>查看 H00／H07 同帧前后对照及连续出手实录</a>。本页画面仍待你逐招复核。</p>",
         "<div class='reference'><img src='reference-example.png' alt='用户提供的法术力度参考'><p>力度目标取自你给的截图：宽主体、清晰分层、强亮芯和迅速扩张的命中拍点。造型按身份分开：金纹束缚、翻卷水弧、赤丝卷剪、横向铜铃声膜、铜甲翻裂与绯帷罩落。<br><a href='b02-special/binding-impact-timing.csv'>B02 逐帧停顿与展开数据</a></p></div>",
         "<input class='search' id='filter' type='search' placeholder='按编号或法术名筛选，例如 B03、毒息、月牙'>",
         "<nav class='nav'>" + "".join(f"<a href='#{html.escape(g)}'>{html.escape(g)}</a>" for g in groups) + "</nav>",
         "<details><summary>八名通缉犯准备、接触、峰值与回收时序拼图</summary><div class='qa'>"]
for kind in ("full", "close", "impact"):
    for idx in (1, 2, 3):
        path = f"bounty/qa/{kind}-{idx:02d}.jpg"
        if (OUT / path).is_file():
            parts.append(f"<a href='{path}'><img loading='lazy' src='{path}' alt='{kind} 第{idx}组'></a>")
parts.append("</div></details><details><summary>其余正式表现接触时序拼图</summary><div class='qa'>")
for idx in range(1, 15):
    path = f"whole/qa/sheet-{idx:02d}.jpg"
    if (OUT / path).is_file():
        parts.append(f"<a href='{path}'><img loading='lazy' src='{path}' alt='第{idx}组'></a>")
parts.append("</div></details>")
comparisons = [
    ("水锋试探／逆钟重浪", ("B03A", "B03B"), "bounty", "-impact"),
    ("剪丝试探／赤丝勒束", ("B05A", "B05B"), "bounty", "-impact"),
    ("铜铃震膜／毒沫液滴", ("B07-knock", "B07-spittle"), "bounty", "-impact"),
    ("真身主刺／伪影碎镜", ("B08-true-stab", "B08-echo-strike"), "bounty", "-impact"),
    ("贴身铜甲／碎甲撕裂", ("B09-armor", "B09-rend"), "bounty", "-impact"),
    ("赤丝收紧／绯帷罩落", ("B05B", "B10-veil"), "bounty", "-impact"),
    ("单敌双脸交换／多敌无名宣告", ("H04", "H10-four"), "whole", "-close"),
    ("实物飞臂／机械刃群", ("M13", "M14"), "whole", "-close"),
    ("铜甲震击／掀甲拱浪", ("N07A", "N07B"), "whole", "-close"),
    ("喉囊声弹／扁声压浪", ("N10A", "N10B"), "whole", "-close"),
]
parts.append("<details><summary>易混淆招式并排对照</summary>")
for title, pair, folder, suffix in comparisons:
    parts.append(f"<h3>{html.escape(title)}</h3><div class='films'>")
    for key in pair:
        path = f"{folder}/after/{key}{suffix}.mp4"
        parts.append(f"<figure><figcaption>{html.escape(key)}</figcaption><video controls playsinline preload='none' data-src='{path}'></video></figure>")
    parts.append("</div>")
parts.append("</details>")
for group in groups:
    parts.append(f"<section id='{html.escape(group)}'><h2>{html.escape(group)}</h2>")
    for item in manifest:
        if chapter(item["group"], item["id"]) != group:
            continue
        title = html.escape(item["name"])
        key = html.escape(item["key"])
        parts.append(f"<article data-search='{html.escape((item['key']+' '+item['name']).lower(),quote=True)}'><details><summary><span class='key'>{key}</span><h3>{title}</h3><span class='scope'>{html.escape(item['scope'])}</span></summary><div class='films'>")
        labels = ("战场全景", "施法者／状态近景", "受术者近景")
        for index, clip in enumerate(item["clips"]):
            src = html.escape(clip["path"], quote=True)
            parts.append(f"<figure><figcaption>{labels[index]}</figcaption><video controls playsinline preload='none' data-src='{src}'></video></figure>")
        parts.append("</div></details></article>")
    parts.append("</section>")
parts.append("<p>源文件及录像 SHA256 见 <a href='review-manifest.json'>review-manifest.json</a>。画面需逐招评审；安全回调、原生构建与真机表现分别记录。</p>")
parts.append("""<script>
const f=document.querySelector('#filter');
f.addEventListener('input',()=>{const s=f.value.trim().toLowerCase();document.querySelectorAll('article').forEach(a=>a.classList.toggle('hidden',!!s&&!a.dataset.search.includes(s)));});
// Keep the 227 video players unloaded until their review section opens.
document.querySelectorAll('details').forEach(d=>d.addEventListener('toggle',()=>{
  d.querySelectorAll('video').forEach(v=>{
    if(d.open && !v.src) v.src=v.dataset.src;
    if(!d.open && v.src){v.pause();v.removeAttribute('src');v.load();}
  });
}));
</script></main></html>""")
(OUT / "index.html").write_text("".join(parts))
print(f"{len(manifest)} current formal presentation groups, {sum(len(x['clips']) for x in manifest)} Unity videos: {OUT/'index.html'}")
