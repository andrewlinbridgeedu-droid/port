"""Register five imagegen-painted light washes; never paint light procedurally."""
from pathlib import Path
from collections import deque
import json
from PIL import Image

HERE = Path(__file__).resolve().parent

def components(im):
    alpha = im.getchannel('A').load()
    seen, groups = set(), []
    for y in range(512):
        for x in range(512):
            if alpha[x,y] < 64 or (x,y) in seen:
                continue
            queue, points = deque([(x,y)]), []
            seen.add((x,y))
            while queue:
                u,v = queue.popleft(); points.append((u,v))
                for a,b in [(u-1,v),(u+1,v),(u,v-1),(u,v+1)]:
                    if 0<=a<512 and 0<=b<512 and (a,b) not in seen and alpha[a,b]>=64:
                        seen.add((a,b));queue.append((a,b))
            if len(points)>100:
                box = (min(x for x,y in points),min(y for x,y in points),max(x for x,y in points)+1,max(y for x,y in points)+1)
                groups.append({'area':len(points),'box':box,'center':[sum(x for x,y in points)/len(points),sum(y for x,y in points)/len(points)]})
    groups = sorted(groups,key=lambda c:c['area'],reverse=True)[:5]
    assert len(groups)==5, groups
    return sorted(groups,key=lambda c:c['center'][1])

def main():
    config = json.loads((HERE/'ground-lighting.json').read_text())
    records=[]
    for file in ['CommissionBoulevardGroundLights.png','CommissionBoulevardSnowGroundLights.png']:
        source=Image.open(HERE/'generated'/file).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS)
        groups=components(source)
        result=Image.new('RGBA',(512,512))
        placed=[]
        for index,(group,center,size) in enumerate(zip(groups,config['poolCenters'],config['poolSizes'])):
            x0,y0,x1,y1=group['box'];box=(max(0,x0-12),max(0,y0-12),min(512,x1+12),min(512,y1+12))
            crop=source.crop(box)
            # Separate the faint bridge between neighboring painted washes.
            # Pixel colors/opacity inside each selected cutout remain original.
            pixels=crop.load()
            for y in range(crop.height):
                for x in range(crop.width):
                    gx,gy=x+box[0],y+box[1]
                    owner=min(range(5),key=lambda k:(gx-groups[k]['center'][0])**2+(gy-groups[k]['center'][1])**2)
                    if owner!=index:
                        pixels[x,y]=(0,0,0,0)
            fitted=crop.resize(tuple(size),Image.Resampling.LANCZOS)
            at=(round(center[0]-size[0]/2),round(center[1]-size[1]/2))
            result.alpha_composite(fitted,at)
            placed.append({'sourceBounds':box,'targetCenter':center,'targetSize':size,'lampIndex':index})
        result.save(HERE/'assets'/file)
        records.append({'file':file,'pools':placed})
    (HERE/'ground-registration.json').write_text(json.dumps({'imagegenPainted':True,'proceduralPainting':False,'frame':config['rect'],'assets':records},indent=2)+'\n')

if __name__=='__main__':
    main()
