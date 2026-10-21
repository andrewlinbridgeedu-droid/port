"""Review sheets for downloaded Veo takes: per take, frames 0-4 s every 1/6 s (full body) and a head row
(0.33-2.5 s every 1/8 s) to catch face turns, conjured props and smoke.
usage: <media-venv>/bin/python review.py <takes dir> <out dir>"""
import sys, os, glob, imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
font = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', 18)
for path in sorted(glob.glob(os.path.join(src, '*.mp4'))):
    name = os.path.basename(path)[:-4]
    r = imageio_ffmpeg.read_frames(path, pix_fmt='rgb24'); m = next(r); w, h = m['size']; fps = m['fps']
    body, heads = [], []
    for i, b in enumerate(r):
        t = i / fps
        if t > 4.01: break
        if i % 4 == 0:
            im = Image.frombytes('RGB', (w, h), b)
            s = im.resize((150, 266)); d = ImageDraw.Draw(s); d.rectangle((0, 0, 48, 18), fill=(0, 0, 0)); d.text((2, 0), '%.2f' % t, font=font, fill=(255, 220, 90)); body.append(s)
            if 0.3 <= t <= 2.6:
                hd = im.crop((int(w * .3), int(h * .03), int(w * .7), int(h * .25))).resize((150, 150)); heads.append(hd)
    cols = 13; rows = (len(body) + cols - 1) // cols
    sheet = Image.new('RGB', (150 * cols, 266 * rows + 150 * ((len(heads) + cols - 1) // cols) + 26), (20, 20, 20))
    ImageDraw.Draw(sheet).text((4, 2), name, font=font, fill=(255, 255, 255))
    for k, s in enumerate(body): sheet.paste(s, ((k % cols) * 150, 26 + (k // cols) * 266))
    y0 = 26 + rows * 266
    for k, s in enumerate(heads): sheet.paste(s, ((k % cols) * 150, y0 + (k // cols) * 150))
    sheet.save(os.path.join(out, name + '.jpg'), quality=82)
    print(name, flush=True)
