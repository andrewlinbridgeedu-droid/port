"""Build a standalone reader from the colocated Markdown plan. No external assets."""
from pathlib import Path
import re
from html import escape
folder=Path(__file__).parent
source=folder/'雾港世界战役与经济系统落地规划书.md'
lines=source.read_text().splitlines()

def inline(s):
    s=escape(s)
    return re.sub(r'\*\*(.+?)\*\*',r'<strong>\1</strong>',s)

parts=[];toc=[];i=0;section=0
while i<len(lines):
    line=lines[i].strip()
    if not line: i+=1;continue
    if line.startswith('# '):
        parts.append('<header><p class="eyebrow">MISTPORT · DEVELOPMENT PLAN</p><h1>'+inline(line[2:])+'</h1></header>');i+=1;continue
    if line.startswith('## '):
        section+=1;title=line[3:];anchor='section-'+str(section)
        parts.append(f'<h2 id="{anchor}">'+inline(title)+'</h2>')
        toc.append(f'<a href="#{anchor}">'+inline(title)+'</a>');i+=1;continue
    if line.startswith('### '):parts.append('<h3>'+inline(line[4:])+'</h3>');i+=1;continue
    if line.startswith('|'):
        rows=[]
        while i<len(lines) and lines[i].strip().startswith('|'):
            cells=lines[i].strip().strip('|').split('|')
            if not all(re.fullmatch(r'\s*:?-+:?\s*',c) for c in cells):rows.append(cells)
            i+=1
        widths=([19,14,28,39] if rows[0][0]=='里程碑' else [12,25,33,30]) if len(rows[0])==4 else [18,46,36]
        columns='<colgroup>'+''.join(f'<col style="width:{w}%">' for w in widths)+'</colgroup>'
        table='<div class="table-scroll"><table>'+columns+'<thead><tr>'+''.join('<th scope="col">'+inline(c)+'</th>' for c in rows[0])+'</tr></thead><tbody>'
        for row in rows[1:]:table+='<tr>'+''.join('<td>'+inline(c)+'</td>' for c in row)+'</tr>'
        parts.append(table+'</tbody></table></div>');continue
    if line.startswith('- ') or re.match(r'^\d+\. ',line):
        ordered=not line.startswith('- ');tag='ol' if ordered else 'ul';items=[]
        while i<len(lines):
            l=lines[i].strip()
            if ordered and re.match(r'^\d+\. ',l):items.append(re.sub(r'^\d+\. ','',l))
            elif not ordered and l.startswith('- '):items.append(l[2:])
            else:break
            i+=1
        parts.append('<'+tag+'>'+''.join('<li>'+inline(x)+'</li>' for x in items)+'</'+tag+'>');continue
    cls=' class="meta"' if line.startswith('版本 1.0') else ''
    parts.append('<p'+cls+'>'+inline(line)+'</p>');i+=1

css='''
:root{color-scheme:light;--ink:#18212b;--muted:#5b6672;--line:#d9dee3;--paper:#fff;--accent:#27597a}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:28px}body{margin:0;background:#f1f3f4;color:var(--ink);font:16px/1.9 -apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif}
a{color:var(--accent)}.layout{max-width:1380px;margin:auto;display:grid;grid-template-columns:240px minmax(0,1fr);gap:36px;padding:38px 28px 72px}nav{position:sticky;top:30px;align-self:start;max-height:90vh;overflow:auto;font-size:13px}nav .label{font-size:12px;letter-spacing:2px;color:var(--muted);margin-bottom:16px}nav a{display:block;text-decoration:none;color:#475563;padding:7px 0;line-height:1.65}nav a:hover{color:#111}nav .download{margin-top:20px;padding-top:15px;border-top:1px solid var(--line)}main{background:var(--paper);padding:48px 52px 64px;box-shadow:0 2px 20px #12233408;min-width:0}.eyebrow{color:var(--muted);font-size:11px;letter-spacing:2.5px;margin:0 0 15px}h1{color:#000;font-size:35px;line-height:1.45;font-weight:700;letter-spacing:.03em;margin:0 0 18px;max-width:720px}.meta{font-size:12px;color:var(--muted);margin-bottom:38px}h2{color:#000;font-size:24px;line-height:1.5;margin:48px 0 20px;break-after:avoid}h3{color:#000;font-size:18px;line-height:1.6;margin:30px 0 12px;break-after:avoid}p{margin:0 0 17px;text-align:justify;overflow-wrap:anywhere}strong{font-weight:650}ul,ol{padding-left:24px;margin:12px 0 24px}li{padding-left:5px;margin:9px 0}.table-scroll{overflow-x:auto;margin:24px 0 28px}table{width:100%;border-collapse:collapse;font-size:13px;line-height:1.75;table-layout:fixed}th,td{border:1px solid var(--line);padding:12px 13px;vertical-align:middle;text-align:left;overflow-wrap:anywhere}th{background:#e7eef3;color:#000;font-weight:650}tbody tr:nth-child(even){background:#f7f9fa}thead{display:table-header-group}footer{margin-top:48px;padding-top:16px;border-top:1px solid var(--line);font-size:12px;color:var(--muted)}
@media(max-width:1000px){.layout{grid-template-columns:1fr;padding:16px;gap:16px}nav{position:static;max-height:none;display:none}main{padding:30px 26px}h1{font-size:29px}table{min-width:640px}}
@media print{@page{size:A4;margin:18mm 17mm}body{background:#fff;font-size:10.5pt;line-height:1.7}.layout{display:block;padding:0;max-width:none}nav{display:none}main{padding:0;box-shadow:none}h1{font-size:25pt}h2{font-size:17pt;margin-top:25pt}h3{font-size:12pt}p{orphans:3;widows:3}.meta{margin-bottom:24pt}.table-scroll{overflow:visible}table{min-width:0;font-size:8.7pt;line-height:1.6}th,td{padding:7pt}tr{break-inside:avoid}a{color:inherit;text-decoration:none}footer{display:none}*{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
'''
html='<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>雾港世界战役与经济系统落地规划书</title><style>'+css+'</style></head><body><div class="layout"><nav aria-label="规划书目录"><div class="label">规划书目录</div>'+''.join(toc)+'<a class="download" href="'+source.name+'" download>下载同版正文 Markdown</a></nav><main>'+''.join(parts)+'<footer>雾港项目规划 · 版本1.0 · 2026年9月28日<br>同版正文与引用资料保存在项目目录，可使用浏览器打印功能导出阅读副本。</footer></main></div></body></html>'
(folder/'雾港世界战役与经济系统落地规划书.html').write_text(html)
assert len(toc)==13
assert '<tbody>' in html and html.count('<table>')==6, html.count('<table>')
print('Built reader:',len(toc),'sections,',html.count('<table>'),'tables')
