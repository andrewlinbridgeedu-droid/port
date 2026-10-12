import sys, glob, os, subprocess
from PIL import Image, ImageDraw, ImageFont
# usage: sheet5.py <dir-with-after> <out.jpg> <t0> <t1> <step> KEY...
S=os.environ['S']; src=sys.argv[1]; out=sys.argv[2]; t0=float(sys.argv[3]); t1=float(sys.argv[4]); step=float(sys.argv[5]); keys=sys.argv[6:]
f=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',22)
rows=[]
for key in keys:
    d=f"{S}/fr-{os.path.basename(os.path.dirname(src.rstrip('/')))}-{key}"
    subprocess.run(['rm','-rf',d]); os.makedirs(d)
    subprocess.run([f"{S}/q12frames/extract_range", f"{src}/{key}.mp4", d, str(t0), str(t1), str(1/step), '0','0','10000','10000','0'], capture_output=True)
    fs=sorted(glob.glob(d+'/r*.png'))
    ims=[]
    for k,p in enumerate(fs):
        im=Image.open(p).convert('RGB').resize((180,320))
        ImageDraw.Draw(im).text((4,2),f'{key} {t0+k*step:.1f}',fill=(255,255,0),font=f); ims.append(im)
    rows.append(ims)
n=max(len(r) for r in rows)
sheet=Image.new('RGB',(180*n,320*len(rows)))
for y,r in enumerate(rows):
    for x,im in enumerate(r): sheet.paste(im,(x*180,y*320))
sheet.save(out,quality=85); print(sheet.size)
