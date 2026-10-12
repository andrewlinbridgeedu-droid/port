import subprocess, glob, os, sys
from PIL import Image, ImageDraw, ImageFont
S=os.environ['S']; O=sys.argv[1]; out=sys.argv[2]; keys=sys.argv[3:]
f=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',18)
peaks={l.split()[0]:float(l.split()[1]) for l in open(os.environ['PK'])}
rows=[]
for key in keys:
    d=f'{S}/sq-{key}'; subprocess.run(['rm','-rf',d]); os.makedirs(d)
    t0=max(0,peaks.get(key,1.0)-.5)
    subprocess.run([f'{S}/q12frames/extract_range', f'{O}/{key}.mp4', d, str(t0), str(t0+1.0),'10','0','0','10000','10000','0'],capture_output=True)
    ims=[]
    for k,p in enumerate(sorted(glob.glob(d+'/r*.png'))[:10]):
        im=Image.open(p).convert('RGB').resize((180,320)); ImageDraw.Draw(im).text((3,2),f'{key} {t0+k*.1:.1f}',fill=(255,255,0),font=f); ims.append(im)
    rows.append(ims)
s=Image.new('RGB',(1800,320*len(rows)))
for y,r in enumerate(rows):
    for x,im in enumerate(r): s.paste(im,(x*180,y*320))
s.save(out,quality=85)
