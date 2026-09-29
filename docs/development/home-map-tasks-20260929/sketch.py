# Draws the home harbour map annotation from home-map-layout.json onto the
# autumn home painting (design proposal, not art).
# Run from the repo root: python3 docs/development/home-map-tasks-20260929/sketch.py
# Needs Pillow, the LFS painting CityAutumnDay.jpg and a CJK font (WenQuanYi Zen Hei).
# Writes two images next to this script: -streets.jpg (streets and buildings)
# and -people.jpg (people, trade posts and world-event service areas).
import json, math, os
from PIL import Image, ImageDraw, ImageFont

HERE = "docs/development/home-map-tasks-20260929"
SRC = "mistport-ios/Mistport/Assets.xcassets/CityAutumnDay.imageset/CityAutumnDay.jpg"
FONT = os.environ.get("MISTPORT_MAP_FONT") or next((path for path in [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
] if os.path.isfile(path)), None)
if FONT is None:
    raise SystemExit("未找到中文字体；请设置 MISTPORT_MAP_FONT 为本机中文字体路径")
L = json.load(open(os.path.join(HERE, "home-map-layout.json")))

W = 2400
painting = Image.open(SRC).convert("RGB")
H = round(W * painting.size[1] / painting.size[0])
U = H
painting = painting.resize((W, H), Image.LANCZOS)
painting = Image.blend(painting, Image.new("RGB", painting.size, (20, 24, 32)), 0.30)

def f(size): return ImageFont.truetype(FONT, size)
def P(p): return (p[0] * U, p[1] * U)

def canvas(legend_rows):
    img = Image.new("RGB", (W, H + 70 + 46 * len(legend_rows)), (18, 21, 28))
    img.paste(painting, (0, 0))
    return img, Image.new("RGBA", img.size, (0, 0, 0, 0))

def label(d, p, text, fill, bg, size=24, anchor="mm", pad=7, outline=None):
    x, y = P(p)
    b = d.textbbox((x, y), text, font=f(size), anchor=anchor)
    d.rounded_rectangle((b[0] - pad, b[1] - pad // 2 - 2, b[2] + pad, b[3] + pad // 2 + 2), radius=8,
                        fill=bg, outline=outline, width=3 if outline else 0)
    d.text((x, y), text, font=f(size), fill=fill, anchor=anchor)

def dashed(d, pts, color, width=4, dash=16, gap=10, closed=False):
    pts = [P(p) for p in pts] + ([P(pts[0])] if closed else [])
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        n = math.hypot(x2 - x1, y2 - y1)
        t = 0.0
        while t < n:
            a, b = t / n, min(1, (t + dash) / n)
            d.line([(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a), (x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)], fill=color, width=width)
            t += dash + gap

def dot(d, p, r, fill, outline=(255, 255, 255, 255), text=None, size=20, tc=(255, 255, 255)):
    x, y = P(p)
    d.ellipse((x - r, y - r, x + r, y + r), fill=fill, outline=outline, width=3)
    if text: d.text((x, y), text, font=f(size), fill=tc, anchor="mm")

def finish(img, ov, title, rows, out):
    img = Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB")
    d = ImageDraw.Draw(img)
    y = H + 18
    d.text((28, y), title, font=f(32), fill=(255, 240, 200)); y += 52
    for k, v in rows:
        d.text((28, y), k, font=f(25), fill=(236, 200, 120)); d.text((300, y), v, font=f(25), fill=(230, 232, 236)); y += 46
    img.save(out, quality=82, optimize=True); print(out, img.size)

# 1. streets and buildings
rows = [("青色区＋白线", "三块街区和街道：人只在这些线上走。远处街巷只作背景，不可点。"),
        ("白圈箭头 / 黄圈", "出入口：人从这里走进走出画面 / 等候点 H1–H10：接了任务的人在这里等你。"),
        ("金色 / 蓝色名牌", "现有 9 个名牌（市政厅、警察厅改为可进入）/ 新增：邮局、诊所、港务处、旧街铺面、委托板。"),
        ("橙色小牌", "街边地点：旧排水口、封锁公告处，只在相关案件里出现。"),
        ("红圈", "通缉现场，比对定位后才出现（旁边写案件和地点）。")]
img, ov = canvas(rows); d = ImageDraw.Draw(ov)
for z in L["zones"]:
    d.polygon([P(p) for p in z["polygon"]], fill=(60, 200, 190, 60))
    dashed(d, z["polygon"], (90, 235, 220, 220), closed=True)
for s in L["streets"]:
    d.line([P(p) for p in s["points"]], fill=(255, 255, 255, 210), width=6, joint="curve")
zone_labels = {"boulevard": (0.25, 0.975), "plaza": (1.05, 0.735), "yard": (1.53, 0.985)}
for z in L["zones"]:
    label(d, zone_labels[z["id"]], z["name"], (230, 255, 250), (10, 70, 70, 225), size=28)
for e in L["entries"]:
    x, y = P(e["at"])
    dot(d, e["at"], 13, (255, 255, 255, 235), (30, 30, 30, 255))
    d.polygon([(x - 6, y - 7), (x + 8, y), (x - 6, y + 7)], fill=(30, 30, 30, 255))
for h in L["holdSpots"]:
    dot(d, h["at"], 17, (0, 0, 0, 0), (255, 214, 90, 255), h["id"], 16, (255, 214, 90))
for b in L["buildings"]:
    new = b["status"].startswith("新增")
    p = (b["at"][0], b["at"][1] - 0.03)
    if new: label(d, p, b["name"] + "（新）", (230, 240, 255), (40, 90, 170, 235), outline=(170, 210, 255, 255))
    else: label(d, p, b["name"], (40, 26, 6), (236, 200, 120, 235))
for s in L["streetSpots"]:
    label(d, s["at"], s["name"], (40, 20, 0), (255, 170, 80, 235), size=20, pad=5)
for s in L["bountySites"]:
    dot(d, s["at"], 16, (150, 20, 24, 215), (255, 120, 110, 255))
    label(d, (s["at"][0] + 0.02, s["at"][1]), s["case"].upper() + " " + s["name"], (255, 235, 230), (110, 20, 22, 215), size=19, anchor="lm", pad=5)
finish(img, ov, "首页港城标注 ①：街道与建筑（提案，待你在真机截图上复核）", rows, os.path.join(HERE, "home-map-streets.jpg"))

# 2. people, trade posts, world-event service areas
rows = [("灰色圆点", "23 名街坊平时在白线上走：点了只打招呼，没有选项。"),
        ("绿色（常驻可互动）", "买卖和赌牌的人：莫尔、码头老水手（牌局），商人（铜币买卖），咖啡馆店主（补给）。"),
        ("紫色（固定岗位）", "建筑里的人在门前站岗：奥黛尔、维拉、档案员、诺恩、港务员、伊莱。只有任务或事件时才有正事。"),
        ("彩色虚线区", "世界事件的服务区：事件进行时，区里写到的人亮起，交货、接事件战都在人身上。"),
        ("其余时候", "街坊只有接了任务（邮务、委托、余案、通缉）才亮起，才有真正的互动。")]
img, ov = canvas(rows); d = ImageDraw.Draw(ov)
for s in L["streets"]:
    d.line([P(p) for p in s["points"]], fill=(255, 255, 255, 120), width=4, joint="curve")
colors = {"plaza": (255, 120, 120), "yard": (120, 180, 255)}
zone = {z["id"]: z for z in L["zones"]}
for i, e in enumerate(L["eventAreas"]):
    c = [(255, 120, 120), (120, 200, 255), (255, 200, 90), (190, 150, 255)][i]
    poly = zone[e["area"]]["polygon"]
    shrink = 0.012 * i
    cx = sum(p[0] for p in poly) / len(poly); cy = sum(p[1] for p in poly) / len(poly)
    pts = [(cx + (p[0] - cx) * (1 - shrink * 4), cy + (p[1] - cy) * (1 - shrink * 4)) for p in poly]
    dashed(d, pts, c + (235,), width=5, closed=True)
ev_labels = [(0.93, 0.50), (1.30, 0.62), (1.50, 0.66), (1.46, 0.985)]
for i, e in enumerate(L["eventAreas"]):
    c = [(255, 120, 120), (120, 200, 255), (255, 200, 90), (190, 150, 255)][i]
    label(d, ev_labels[i], e["event"] + "：" + "、".join(e["people"]), (20, 20, 20), c + (230,), size=19, pad=5)
# ambient citizens scattered on the streets
import random
random.seed(7)
for s in L["streets"]:
    for k in range(2):
        a = random.randrange(len(s["points"]) - 1); t = random.random()
        p0, p1 = s["points"][a], s["points"][a + 1]
        dot(d, (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t), 9, (200, 200, 200, 230), (60, 60, 60, 255))
for a in L["alwaysInteractive"]:
    dot(d, a["post"], 16, (40, 170, 90, 240))
    label(d, (a["post"][0], a["post"][1] + 0.035), a["who"] + "·" + a["what"].split("（")[0].split("：")[0], (255, 255, 255), (25, 110, 60, 230), size=19, pad=5)
for n in L["namedPosts"]:
    dot(d, n["post"], 14, (140, 90, 210, 240))
    label(d, (n["post"][0], n["post"][1] - 0.032), n["who"], (255, 255, 255), (90, 55, 150, 230), size=19, pad=5)
finish(img, ov, "首页港城标注 ②：人物、常驻买卖与牌局、世界事件服务区（提案）", rows, os.path.join(HERE, "home-map-people.jpg"))
