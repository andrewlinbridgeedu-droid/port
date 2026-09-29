# Layout sketch for the home harbour map (design proposal, not art).
# Run from the repo root: python3 docs/development/home-map-tasks-20260929/sketch.py
# Needs Pillow, the LFS painting CityAutumnDay.jpg and a CJK font (WenQuanYi Zen Hei).
# Positions are in painting units (x across, y down, both in painting heights),
# the same units as CityHubView.cityHotspots.
from PIL import Image, ImageDraw, ImageFont
import math

SRC = "mistport-ios/Mistport/Assets.xcassets/CityAutumnDay.imageset/CityAutumnDay.jpg"
OUT = "docs/development/home-map-tasks-20260929/home-map-layout-sketch.jpg"
FONT = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"

W = 2400
base = Image.open(SRC).convert("RGB")
H = round(W * base.size[1] / base.size[0])
U = H                      # one painting unit = painting height
base = base.resize((W, H), Image.LANCZOS)
# dim the painting so the overlay reads
base = Image.blend(base, Image.new("RGB", base.size, (20, 24, 32)), 0.28)

LEG = 430                 # legend strip below the painting
img = Image.new("RGB", (W, H + LEG), (18, 21, 28))
img.paste(base, (0, 0))
ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
d = ImageDraw.Draw(ov)

def f(size): return ImageFont.truetype(FONT, size)
def P(x, y): return (x * U, y * U)

def label(x, y, text, fill, bg, size=26, anchor="mm", pad=8, outline=None, dash=False):
    fo = f(size)
    tx, ty = P(x, y)
    b = d.textbbox((tx, ty), text, font=fo, anchor=anchor)
    box = (b[0] - pad, b[1] - pad // 2 - 2, b[2] + pad, b[3] + pad // 2 + 2)
    d.rounded_rectangle(box, radius=8, fill=bg, outline=outline, width=3 if outline else 0)
    d.text((tx, ty), text, font=fo, fill=fill, anchor=anchor)
    return box

def dashed_poly(points, color, width=4, dash=18, gap=12):
    pts = [P(*p) for p in points] + [P(*points[0])]
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        L = math.hypot(x2 - x1, y2 - y1); n = max(1, int(L // (dash + gap)))
        for i in range(n + 1):
            a = i * (dash + gap) / L; b = min(1, (i * (dash + gap) + dash) / L)
            if a >= 1: break
            d.line([(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a), (x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)], fill=color, width=width)

# 1. walk zones
zones = {
    "A 台阶大道（近景，人最大最好点）": [(0.0, 1.0), (0.0, 0.933), (0.122, 0.80), (0.256, 0.678), (0.389, 0.578), (0.478, 0.506), (0.578, 0.506), (0.622, 0.622), (0.711, 0.778), (0.778, 0.878), (0.867, 1.0)],
    "B 喷泉广场": [(0.922, 0.622), (0.978, 0.556), (1.067, 0.533), (1.156, 0.556), (1.178, 0.622), (1.111, 0.678), (1.0, 0.683)],
    "C 工坊货场": [(1.256, 0.711), (1.644, 0.711), (1.733, 0.844), (1.667, 0.956), (1.389, 0.956), (1.267, 0.844)],
}
zone_label_at = {"A 台阶大道（近景，人最大最好点）": (0.25, 0.975), "B 喷泉广场": (1.05, 0.715), "C 工坊货场": (1.50, 0.985)}
for name, poly in zones.items():
    d.polygon([P(*p) for p in poly], fill=(60, 200, 190, 70))
    dashed_poly(poly, (90, 235, 220, 230), width=4)
    label(*zone_label_at[name], name, (230, 255, 250), (10, 70, 70, 215), size=28)
# far streets: background only
far = [(0.60, 0.455), (1.24, 0.455), (1.24, 0.52), (0.60, 0.52)]
dashed_poly(far, (200, 200, 200, 170), width=3, dash=10, gap=10)
label(0.92, 0.487, "远景街巷：只走人作背景，不可点、不放任务", (235, 235, 235), (40, 40, 40, 190), size=22)

# 2. entries (where citizens walk in and out of view)
entries = [(0.44, 0.99, "出入口"), (0.53, 0.495, "出入口 · 通钟楼"), (0.12, 0.79, "出入口 · 拱廊"),
           (1.07, 0.54, "出入口 · 拱门"), (1.00, 0.69, "出入口 · 台阶"), (1.30, 0.705, "出入口 · 北巷"), (1.71, 0.86, "出入口 · 通码头")]
for x, y, t in entries:
    cx, cy = P(x, y); r = 13
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 230), outline=(30, 30, 30, 255), width=3)
    d.polygon([(cx - 6, cy - 7), (cx + 8, cy), (cx - 6, cy + 7)], fill=(30, 30, 30, 255))
    label(x + 0.012, y - 0.028, t, (20, 20, 20), (255, 255, 255, 205), size=19, anchor="lm", pad=5)

# 3. hold spots (task people wait here)
holds = [(0.38, 0.86), (0.47, 0.70), (0.52, 0.575), (0.62, 0.80), (0.21, 0.72), (0.98, 0.605), (1.12, 0.605), (1.40, 0.80), (1.58, 0.82), (1.31, 0.905)]
for i, (x, y) in enumerate(holds, 1):
    cx, cy = P(x, y); r = 17
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 214, 90, 255), width=4)
    d.text((cx, cy), f"H{i}", font=f(17), fill=(255, 214, 90), anchor="mm")

# 4. plaques: existing (gold) and proposed (blue)
existing = [(1.180, 0.223, "皇宫"), (0.509, 0.311, "教会"), (0.374, 0.390, "银行"), (0.140, 0.444, "科学委员会"), (0.584, 0.430, "报社"),
            (1.180, 0.464, "市政厅（改为可进入）"), (1.256, 0.647, "工业委员会＝百工坊·维拉"), (0.825, 0.595, "酒馆"), (0.680, 0.735, "咖啡馆")]
for x, y, t in existing:
    label(x, y - 0.03, t, (40, 26, 6), (236, 200, 120, 235), size=24)
proposed = [(0.17, 0.53, "邮局（新）"), (0.86, 0.455, "诊所·奥黛尔（新）"), (1.52, 0.44, "港务处（新）"), (1.46, 0.67, "旧街铺面（新）")]
for x, y, t in proposed:
    label(x, y - 0.03, t, (230, 240, 255), (40, 90, 170, 230), size=24, outline=(170, 210, 255, 255))

# 5. bounty sites (appear only after the cross-match ring)
sites = [(0.05, 0.585, "①"), (1.40, 0.45, "②"), (0.66, 0.465, "③"), (0.30, 0.46, "④"), (1.62, 0.905, "⑤"),
         (1.67, 0.575, "⑥"), (1.35, 0.345, "⑦"), (1.64, 0.415, "⑧"), (0.44, 0.35, "⑨"), (1.30, 0.83, "⑩")]
for x, y, t in sites:
    cx, cy = P(x, y); r = 22
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(150, 20, 24, 200), outline=(255, 120, 110, 255), width=3)
    d.text((cx, cy), t, font=f(24), fill=(255, 235, 230), anchor="mm")

# 6. phone viewport (one screen on an iPhone, painting fills the height above the bottom bar)
vx0, vx1 = 0.12, 0.12 + 390 / 740
x0, x1 = P(vx0, 0)[0], P(vx1, 0)[0]
for k in range(4):
    d.rectangle((x0 - k, 2 - k, x1 + k, H - 2 + k), outline=(255, 255, 255, 235 - 40 * k))
label(vx0 + 0.01, 0.045, "手机一屏（左右拖动看其余部分）", (15, 15, 15), (255, 255, 255, 230), size=24, anchor="lm")
# task tracker mock under the HUD
tb = label(vx0 + 0.02, 0.105, "当前任务【邮务】把信交给东岸提灯人 ＞", (255, 250, 235), (25, 30, 40, 235), size=24, anchor="lm", pad=12, outline=(236, 200, 120, 255))
# off-screen arrow at the right edge pointing to the activated person
ay = P(0, 0.60)[1]
d.polygon([(x1 - 8, ay - 34), (x1 + 34, ay), (x1 - 8, ay + 34)], fill=(236, 200, 120, 245))
label(vx1 + 0.03, 0.545, "屏外箭头：东岸提灯人在右边", (40, 26, 6), (236, 200, 120, 235), size=21, anchor="lm", pad=6)

# 7. example people: ambient vs activated
def person(x, y, h, name, active=None, tint=(210, 210, 210)):
    cx, cy = P(x, y); ph = h * U; pw = ph * 0.36
    d.ellipse((cx - pw * 0.28, cy - ph, cx + pw * 0.28, cy - ph + pw * 0.56), fill=tint + (240,))
    d.rounded_rectangle((cx - pw / 2, cy - ph + pw * 0.5, cx + pw / 2, cy), radius=int(pw / 3), fill=tint + (240,))
    if active:
        icon, color = active
        r = max(18, int(ph * 0.22))
        mx, my = cx, cy - ph - r - 10
        d.ellipse((mx - r, my - r, mx + r, my + r), fill=color + (250,), outline=(255, 255, 255, 255), width=3)
        d.text((mx, my), icon, font=f(int(r * 1.1)), fill=(255, 255, 255), anchor="mm")
        label(x, y + 0.03, name, (255, 250, 235), (25, 30, 40, 230), size=20, pad=6)
    else:
        label(x, y + 0.025, name, (230, 230, 230), (40, 40, 40, 160), size=17, pad=5)

person(0.60, 0.95, 0.11, "面包师·平时", None, (205, 190, 170))
person(0.56, 0.78, 0.085, "花商·平时", None, (190, 205, 180))
person(0.47, 0.70, 0.075, "邮差·接了通缉B07后亮起", ("印", (170, 30, 30)), (215, 205, 185))
person(0.98, 0.605, 0.05, "东岸提灯人·邮务收件人", ("信", (40, 110, 190)), (200, 200, 215))
person(1.40, 0.80, 0.07, "码头工人·委托", ("铃", (190, 130, 20)), (190, 185, 175))
person(1.12, 0.605, 0.05, "巡街人·平时", None, (185, 195, 210))

img = Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB")

# 8. legend strip
d2 = ImageDraw.Draw(img)
y = H + 26
d2.text((30, y), "首页港城布局示意（设计提案，不是美术稿；名牌和路的最终位置请你在画上标定）", font=f(34), fill=(255, 240, 200))
y += 62
rows = [
    ("青色虚线区", "三块能走、能点的街区：A 台阶大道、B 喷泉广场、C 工坊货场。远处街巷只作背景。"),
    ("白圈箭头", "出入口：街坊从这里走进走出画面。画面里同时约 6–10 人，其余“在城里别处”。"),
    ("黄圈 H1–H10", "等候点：接了任务、被点名的人会走到其中一处停下，头顶挂标记，一直等你。"),
    ("金色名牌 / 蓝色名牌", "现有 9 处入口（市政厅改为可进入）/ 建议新增：邮局、诊所、港务处、旧街铺面。"),
    ("红圈①–⑩", "通缉现场，比对定位后才出现：①第三间空屋 ②废岗亭 ③旧照相馆 ④废浴场 ⑤地下纸窖 ⑥废印厂 ⑦钟沉船 ⑧封舱台 ⑨封闭施济厅 ⑩染坊后院"),
    ("头顶标记", "信＝邮务收件人　铃＝街坊委托　印＝通缉（红）　灰印＝余案。没接任务的人没有标记，点了只打个招呼。"),
]
for k, v in rows:
    d2.text((30, y), k, font=f(26), fill=(236, 200, 120))
    d2.text((330, y), v, font=f(26), fill=(230, 232, 236))
    y += 48
img.save(OUT, quality=82, optimize=True)
print(OUT, img.size)
