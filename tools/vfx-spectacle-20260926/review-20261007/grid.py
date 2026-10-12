import sys, os, json
from PIL import Image, ImageDraw, ImageFont
# grid.py <framesdir> <peaks.txt> <out.jpg> [cols] [crop: top bottom]  keys in peaks order
fd, pk, out = sys.argv[1], sys.argv[2], sys.argv[3]
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 10
top = float(sys.argv[5]) if len(sys.argv) > 5 else 0.0
bot = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
names = [l.split()[0] for l in open(pk) if l.strip()]
f = ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc', 18)
cells = []
for n in names:
    p = os.path.join(fd, n + '.png')
    if not os.path.exists(p): continue
    im = Image.open(p).convert('RGB'); w, h = im.size
    im = im.crop((0, int(h * top), w, int(h * bot))).resize((200, int(200 * (h * (bot - top)) / w)))
    ImageDraw.Draw(im).text((4, 2), n, fill=(255, 255, 0), font=f)
    cells.append(im)
ch = cells[0].size[1]; rows = (len(cells) + cols - 1) // cols
sheet = Image.new('RGB', (200 * cols, ch * rows), (10, 10, 12))
for i, c in enumerate(cells): sheet.paste(c, ((i % cols) * 200, (i // cols) * ch))
sheet.save(out, quality=82); print(sheet.size, len(cells))
