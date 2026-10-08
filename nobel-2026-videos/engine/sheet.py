import sys
from PIL import Image
files=sys.argv[2:]; out=sys.argv[1]
cols=2; w,h=960,540
rows=(len(files)+cols-1)//cols
sheet=Image.new('RGB',(cols*w,rows*h))
for i,f in enumerate(files):
    im=Image.open(f).resize((w,h),Image.LANCZOS); sheet.paste(im,((i%cols)*w,(i//cols)*h))
sheet.save(out,quality=88)
