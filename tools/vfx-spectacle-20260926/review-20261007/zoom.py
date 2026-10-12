import sys
from PIL import Image, ImageDraw, ImageFont
d, out = sys.argv[1], sys.argv[2]; keys = sys.argv[3:]
f = ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc', 22)
ims = []
for k in keys:
    im = Image.open(f'{d}/{k}.png').convert('RGB'); w, h = im.size
    im = im.crop((0, int(h * .1), w, int(h * .75))).resize((330, int(330 * h * .65 / w)))
    ImageDraw.Draw(im).text((4, 2), k, fill=(255, 255, 0), font=f); ims.append(im)
cols = 6; H = ims[0].size[1]; rows = (len(ims) + cols - 1) // cols
s = Image.new('RGB', (330 * cols, H * rows))
for i, im in enumerate(ims): s.paste(im, ((i % cols) * 330, (i // cols) * H))
s.save(out, quality=85)
