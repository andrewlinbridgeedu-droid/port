import sys, glob
from PIL import Image, ImageDraw
files = sys.argv[2:]; out = sys.argv[1]
cols = 2; w, h = 960, 540
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGB', (cols * w, rows * h), 'black')
for i, f in enumerate(files):
    im = Image.open(f).convert('RGB').resize((w, h), Image.LANCZOS)
    d = ImageDraw.Draw(im); d.text((10, 10), f.split('_')[-1], fill=(255, 255, 0))
    sheet.paste(im, ((i % cols) * w, (i // cols) * h))
sheet.save(out, quality=88)
